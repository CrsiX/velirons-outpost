class_name Siege
extends Node
## Enemies at the village (docs/siege-design.md §5). Per village a small
## Dijkstra field over its pieces and the band of Config.SIEGE["approach"]
## tiles around them, towards its intact huts. Costs are in tenths of a step:
## ground STEP, slow ground SIEGE.slow_cost, an intact gate / wall / wall
## tower STEP plus STEP per SIEGE.hp_per_step of its HP. So enemies take the
## cheapest way in: the weakest barrier, or round to a broken one. Moving is
## 4-connected, so a broken corner tower leads nowhere while both walls next
## to it stand. Flyers have a field of their own in which nothing blocks.
## Also tracks which villages have an enemy inside their walls (breached),
## and counts the damage done to buildings.

const STEP := 10
const BLOCKED := Pathing.UNREACHABLE
## The village's pieces enemies have to get through.
const BARRIERS: Array[String] = ["gate", "wall", "wall_tower"]

var game: Game
## Per village id: {"area": Rect2i, "enter": [ground, air] PackedInt32Array,
## "value": [ground, air] PackedInt32Array, "stale": bool, "urgent": bool,
## "at": game clock when built, "version": the pathing's version then}.
var _fields: Dictionary = {}
## Village ids with an enemy inside their walls now.
var _inside: Dictionary = {}
var _scan := 0.0
## Village ids whose pieces were hit in the current wave (one toast each).
var _warned: Dictionary = {}


func setup(p_game: Game) -> void:
	game = p_game


func _process(delta: float) -> void:
	if game == null or game.is_client:
		return
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.25
	_inside.clear()
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e.dead:
			continue
		var vid := game.map.village_at(e.current_tile())
		if vid >= 0:
			_inside[vid] = true


## An enemy is inside village `vid`'s walls: villagers walking in there are exposed.
func breached(vid: int) -> bool:
	return _inside.has(vid)


## A new wave: one "under attack" toast per village again.
func on_wave_started() -> void:
	_warned.clear()


# --- the field ------------------------------------------------------------------------------

func mark_stale(v: Village, urgent: bool = false) -> void:
	if v == null or not _fields.has(v.id):
		return
	var f: Dictionary = _fields[v.id]
	f["stale"] = true
	f["urgent"] = f["urgent"] or urgent


## Tiles where something changed (a building came or went, or changed state).
func tiles_changed(tiles: Array[Vector2i]) -> void:
	for vid in _fields:
		var area: Rect2i = _fields[vid]["area"]
		for t in tiles:
			if area.has_point(t):
				mark_stale(game.villages[vid], true)
				break


## The band around village `v` in which its enemies leave their road.
func in_zone(v: Village, t: Vector2i) -> bool:
	return v != null and v.rect.grow(int(Config.SIEGE["approach"])).has_point(t)


## Cost from `t` to the nearest intact hut (BLOCKED: no way, or outside the field).
func value(v: Village, t: Vector2i, air: bool) -> int:
	var f := _field(v)
	var area: Rect2i = f["area"]
	if not area.has_point(t):
		return BLOCKED
	return (f["value"][1 if air else 0] as PackedInt32Array)[_idx(area, t)]


## Cost of stepping onto `t`.
func enter_cost(v: Village, t: Vector2i, air: bool) -> int:
	var f := _field(v)
	var area: Rect2i = f["area"]
	if not area.has_point(t):
		return BLOCKED
	return (f["enter"][1 if air else 0] as PackedInt32Array)[_idx(area, t)]


## What going on from `from` through `n` costs (BLOCKED: no way).
func way_cost(v: Village, n: Vector2i, air: bool) -> int:
	var e := enter_cost(v, n, air)
	var val := value(v, n, air)
	if e >= BLOCKED or val >= BLOCKED:
		return BLOCKED
	return e + val


## The best neighbour to step to from `from` (`from` itself: none).
## `passing`: a barrier this enemy goes through as if it were open.
func next_step(v: Village, from: Vector2i, air: bool, passing: Building = null) -> Vector2i:
	var best := from
	var best_c := BLOCKED
	for n in MapData.neighbors4(from):
		var c := way_cost(v, n, air)
		if passing != null and barrier_at(v, n) == passing:
			c = STEP + value(v, n, air)
		if c < best_c:
			best_c = c
			best = n
	return best


## The best way on from `from` (BLOCKED: none).
func best_way(v: Village, from: Vector2i, air: bool) -> int:
	var best := BLOCKED
	for n in MapData.neighbors4(from):
		best = mini(best, way_cost(v, n, air))
	return best


## The intact gate, wall or wall tower of `v` on `t`, or null.
func barrier_at(v: Village, t: Vector2i) -> Building:
	var b = game.map.building_at(t)
	if b is Building and b.village == v and BARRIERS.has(b.kind) and b.complete and not b.devastated:
		return b
	return null


## An intact hut of `v` on `t`, or null.
func hut_at(v: Village, t: Vector2i) -> Hut:
	var b = game.map.building_at(t)
	if b is Hut and b.village == v and (b as Hut).is_intact():
		return b
	return null


func _idx(area: Rect2i, t: Vector2i) -> int:
	return (t.y - area.position.y) * area.size.x + (t.x - area.position.x)


func _field(v: Village) -> Dictionary:
	var f: Dictionary = _fields.get(v.id, {})
	if f.is_empty():
		f = {"stale": true, "urgent": true, "at": -INF, "version": -1}
		_fields[v.id] = f
	if f["version"] != game.world.pathing.version:
		f["stale"] = true
	if f["stale"] and (f["urgent"] or game.clock - float(f["at"]) >= float(Config.SIEGE["rebuild_interval"]) or not f.has("value")):
		_build(v, f)
	return f


func _build(v: Village, f: Dictionary) -> void:
	var map := game.map
	var area := v.rect.grow(int(Config.SIEGE["approach"]) + 1).intersection(Rect2i(0, 0, map.size, map.size))
	f["area"] = area
	f["stale"] = false
	f["urgent"] = false
	f["at"] = game.clock
	f["version"] = game.world.pathing.version
	var n := area.size.x * area.size.y
	var huts: Array[int] = []
	var ground := PackedInt32Array()
	var air := PackedInt32Array()
	ground.resize(n)
	air.resize(n)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var t := Vector2i(x, y)
			var i := _idx(area, t)
			air[i] = STEP
			ground[i] = _ground_cost(v, t)
			if hut_at(v, t) != null:
				huts.append(i)
	f["enter"] = [ground, air]
	f["value"] = [_dijkstra(area, ground, huts), _dijkstra(area, air, huts)]


func _ground_cost(v: Village, t: Vector2i) -> int:
	var b = game.map.building_at(t)
	if b is Building and b.village == v and BARRIERS.has(b.kind):
		if b.devastated or not b.complete:
			return STEP
		return STEP + ceili(b.hp / float(Config.SIEGE["hp_per_step"]) * STEP)
	if b is Hut and b.village == v:
		return STEP
	if not game.world.pathing.is_walkable(t):
		return BLOCKED
	if game.map.walk_factor(t) < 1.0:
		return int(Config.SIEGE["slow_cost"])
	return STEP


## Lowest cost from every tile to one of `targets` (indices), where stepping
## onto a tile costs its `enter` (BLOCKED tiles never get a value).
func _dijkstra(area: Rect2i, enter: PackedInt32Array, targets: Array[int]) -> PackedInt32Array:
	var n := enter.size()
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(BLOCKED)
	var w := area.size.x
	var h := area.size.y
	# A binary heap of [cost, index] pairs, kept in two arrays.
	var hk := PackedInt32Array()
	var hv := PackedInt32Array()
	for i in targets:
		dist[i] = 0
		_push(hk, hv, 0, i)
	while not hk.is_empty():
		var c := hk[0]
		var i := hv[0]
		_pop(hk, hv)
		if c > dist[i]:
			continue
		var step := enter[i]
		if step >= BLOCKED:
			continue
		var x := i % w
		var y := i / w
		for d in 4:
			var nx := x + (1 if d == 0 else (-1 if d == 1 else 0))
			var ny := y + (1 if d == 2 else (-1 if d == 3 else 0))
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var j := ny * w + nx
			if enter[j] >= BLOCKED:
				continue  # (nobody stands there)
			var cand := c + step
			if cand < dist[j]:
				dist[j] = cand
				_push(hk, hv, cand, j)
	return dist


static func _push(hk: PackedInt32Array, hv: PackedInt32Array, k: int, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if hk[p] <= hk[i]:
			break
		var tk := hk[p]
		hk[p] = hk[i]
		hk[i] = tk
		var tv := hv[p]
		hv[p] = hv[i]
		hv[i] = tv
		i = p


static func _pop(hk: PackedInt32Array, hv: PackedInt32Array) -> void:
	var last := hk.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and hk[l] < hk[m]:
			m = l
		if r < last and hk[r] < hk[m]:
			m = r
		if m == i:
			break
		var tk := hk[m]
		hk[m] = hk[i]
		hk[i] = tk
		var tv := hv[m]
		hv[m] = hv[i]
		hv[i] = tv
		i = m


# --- buildings hit ----------------------------------------------------------------------------

## A building of ours lost `lost` HP (Building.take_damage).
func on_damaged(b: Building, source: Node, lost: float) -> void:
	var v := b.village
	game.stats.count(v, "building_damage", lost)
	if BARRIERS.has(b.kind):
		mark_stale(v)
		if not _warned.has(v.id):
			_warned[v.id] = true
			v.toast("The %s is under attack!" % ("gate" if b.kind == "gate" else "wall"), Color("ff9a6a"))
			v.events.info("%s is under attack by %s" % [b.label().capitalize(), game.who(source) if source else "enemies"])


func on_devastated(b: Building) -> void:
	mark_stale(b.village, true)


func on_repaired(b: Building) -> void:
	mark_stale(b.village, true)
