class_name GenRoads
extends RefCounted
## Stages 7-8 (docs/world-design.md §5): which places get linked by road, and
## where each road goes. Routing is A* in 4 directions over a cost map by
## zone, with a little noise so roads curve; existing road is cheap so roads
## merge, and tiles right next to a road cost extra so they don't run side
## by side. Deep lakes and the sea, mountains and other villages' walls are
## impassable; rivers get a bridge and shallow water a ford. When mountains
## are in the way, a second try may cut a pass through them.
##   Single player: 3-5 edge spawns around the map, each routed to a gate.
##   Co-op: a ring road round every village; village links (2 players: 1;
##   3: a triangle; more: a ring of neighbouring slices plus chords), every
##   village with at least VILLAGE_MIN_LINKS; 2-3 edge spawns per village on
##   its slice's stretch of the map edge.

var c: GenContext
var m: MapData
var astar := AStarGrid2D.new()
var base_cost := PackedFloat32Array()
var used := {}  # gate -> true once a road leaves it
var _beside := {}  # tiles next to a road that got the extra cost


static func build(p_c: GenContext) -> void:
	var r := router(p_c)
	if r.c.players == 1:
		r._single()
	else:
		r._coop()
	r._collect_spawns()


func _setup() -> void:
	astar.region = Rect2i(0, 0, m.size, m.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	var noise := FastNoiseLite.new()
	noise.seed = c.seed_value * 29 + 707
	noise.frequency = 0.06
	base_cost.resize(m.size * m.size)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var k := c.i(t)
			var cost := float(Config.ROAD_COSTS.get(m.zone(t), 1.0))
			var v := m.get_terrain(t)
			if v == MapData.Terrain.SHALLOW or c.rivers.has(t):
				cost = float(Config.ROAD_COSTS["crossing"])
			cost *= 1.0 + Config.ROAD_COST_NOISE * noise.get_noise_2d(x, y)
			base_cost[k] = cost
			astar.set_point_weight_scale(t, cost)
			var solid := false
			if v == MapData.Terrain.MOUNTAIN:
				solid = true
			elif (v == MapData.Terrain.WATER or v == MapData.Terrain.LAVA) and not c.rivers.has(t):
				solid = true
			elif x == 0 or y == 0 or x == m.size - 1 or y == m.size - 1:
				solid = true  # the edge only where a spawn is (opened per route)
			astar.set_point_solid(t, solid)
	for v in m.villages:
		for t in MapData.rect_tiles((v["rect"] as Rect2i).grow(1)):
			if m.in_bounds(t):
				astar.set_point_solid(t, true)
		# (later roads, like mine spurs, keep off the farm plot)
		var fp: Vector2i = v.get("farm_plot", Vector2i(-1, -1))
		if fp.x >= 0:
			for t in Building.footprint(fp, 3):
				astar.set_point_solid(t, true)


## A router on the current map (for mine spurs).
static func router(p_c: GenContext) -> GenRoads:
	var r := GenRoads.new()
	r.c = p_c
	r.m = p_c.m
	r._setup()
	return r


## A short road from `from` (a mine's front tile) to the nearest road.
func spur_from(from: Vector2i) -> void:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	var goal := Vector2i(-1, -1)
	while head < queue.size() and goal.x < 0:
		var t := queue[head]
		head += 1
		for nb in MapData.neighbors4(t):
			if not m.in_bounds(nb) or seen.has(nb) or m.in_village(nb):
				continue
			seen[nb] = true
			if m.is_road(nb):
				goal = nb
				break
			if not astar.is_point_solid(nb):
				queue.append(nb)
	if goal.x >= 0:
		_route_and_carve(from, goal, false)


# --- single player ------------------------------------------------------------------------------

func _single() -> void:
	var v := m.villages[0]
	var spawns := _pick_edge_spawns(c.count_in(Config.SP_SPAWNS), -1, Vector2(v["center"]))
	for s in spawns:
		_spawn_road(v, s)
	# At least two approaches.
	var guard := 0
	while _approaches(v) < 2 and guard < 4:
		guard += 1
		var free: Array = (v["gates"] as Array).filter(func(g: Vector2i) -> bool: return not used.has(g))
		if free.is_empty():
			break
		var g: Vector2i = free[c.rng.randi() % free.size()]
		var dir: Vector2i = (g - (v["center"] as Vector2i)).sign()
		var edge := _edge_towards(Vector2(v["center"]), Vector2(dir))
		if edge.x >= 0 and _route_and_carve(_gate_exit(v, g), edge, true):
			used[g] = true


# --- co-op ------------------------------------------------------------------------------------

func _coop() -> void:
	var n := m.villages.size()
	# Ring roads just outside the walls join every village's gates, so roads run
	# on past a village (enemies whose target fell walk on to the next one).
	for v in m.villages:
		var ring := (v["rect"] as Rect2i).grow(1)
		for t in MapData.rect_tiles(ring):
			if not (v["rect"] as Rect2i).has_point(t):
				_set_road(t)
	var pairs: Array[Vector2i] = []
	if n == 2:
		pairs.append(Vector2i(0, 1))
	elif n == 3:
		pairs.append_array([Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 2)])
	else:
		var order := _by_slice_angle()
		for k in n:
			var a: int = order[k]
			var b: int = order[(k + 1) % n]
			pairs.append(Vector2i(mini(a, b), maxi(a, b)))
		if n >= 5:
			for chord in c.rng.randi_range(1, 2):
				var a: int = order[c.rng.randi() % n]
				var b: int = order[(order.find(a) + n / 2) % n]
				var p := Vector2i(mini(a, b), maxi(a, b))
				if not pairs.has(p):
					pairs.append(p)
	var degree: Array[int] = []
	degree.resize(n)
	degree.fill(0)
	for p in pairs:
		if _link(p.x, p.y):
			degree[p.x] += 1
			degree[p.y] += 1
	var need := 1 if n == 2 else Config.VILLAGE_MIN_LINKS
	for a in n:
		if degree[a] >= need:
			continue
		var others: Array = range(n)
		others.erase(a)
		var ca := Vector2(m.villages[a]["center"])
		others.sort_custom(func(x: int, y: int) -> bool: return ca.distance_to(Vector2(m.villages[x]["center"])) < ca.distance_to(Vector2(m.villages[y]["center"])))
		for b in others:
			if degree[a] >= need:
				break
			var p := Vector2i(mini(a, b), maxi(a, b))
			if m.village_links.has(p):
				continue
			if _link(p.x, p.y):
				degree[a] += 1
				degree[b] += 1
	for a in n:
		if degree[a] < need:
			c.fail("village %d has only %d road links" % [a, degree[a]])
	# Each village's own spawns, on its slice's stretch of the map edge.
	for i in n:
		var v := m.villages[i]
		for s in _pick_edge_spawns(c.count_in(Config.COOP_SPAWNS), i, Vector2(v["center"])):
			_spawn_road(v, s)


## Village ids ordered by their slice's angle around the map centre.
func _by_slice_angle() -> Array:
	var mid := Vector2(m.size - 1, m.size - 1) / 2.0
	var ids: Array = range(m.villages.size())
	ids.sort_custom(func(a: int, b: int) -> bool: return (Vector2(m.villages[a]["center"]) - mid).angle() < (Vector2(m.villages[b]["center"]) - mid).angle())
	return ids


func _link(a: int, b: int) -> bool:
	var va := m.villages[a]
	var vb := m.villages[b]
	var ga := _gate_towards(va, vb["center"])
	var gb := _gate_towards(vb, va["center"])
	var from := _gate_exit(va, ga)
	var to := _gate_exit(vb, gb)
	var straight := absi(from.x - to.x) + absi(from.y - to.y)
	var path := _route(from, to, false)
	if path.is_empty() or path.size() > Config.ROAD_DETOUR_MAX * straight:
		var cut := _route(from, to, true)
		if not cut.is_empty() and cut.size() <= Config.ROAD_DETOUR_MAX * straight:
			path = cut
		elif path.size() > Config.ROAD_DETOUR_MAX * straight:
			path = []
	if path.is_empty():
		return false
	_carve(path)
	used[ga] = true
	used[gb] = true
	m.village_links.append(Vector2i(a, b))
	return true


# --- spawns -----------------------------------------------------------------------------------

## `k` land tiles on the map edge, spread out: around the whole map (slice
## -1) or along slice `s`'s stretch of the edge.
func _pick_edge_spawns(k: int, s: int, from: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if k <= 0:
		return out
	if s < 0:
		var base := c.rng.randf() * TAU
		for j in k:
			var a := base + j * TAU / k + c.rng.randf_range(-0.3, 0.3)
			var e := _edge_towards(from, Vector2.from_angle(a))
			if e.x >= 0 and out.all(func(o: Vector2i) -> bool: return Vector2(o).distance_to(Vector2(e)) >= 10.0):
				out.append(e)
		return out
	var mid := Vector2(m.size - 1, m.size - 1) / 2.0
	var facing := (Vector2(m.slices[s]["center"]) - mid).angle()
	var stretch: Array[Vector2i] = []
	for t in _edge_tiles():
		if m.slice_of[c.i(t)] == s and c.is_land(t):
			stretch.append(t)
	stretch.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return wrapf((Vector2(a) - mid).angle() - facing, -PI, PI) < wrapf((Vector2(b) - mid).angle() - facing, -PI, PI))
	if stretch.is_empty():
		return out
	for j in k:
		var q := (j + 1.0) / (k + 1.0)
		var t := stretch[clampi(int(q * stretch.size()), 0, stretch.size() - 1)]
		if out.all(func(o: Vector2i) -> bool: return Vector2(o).distance_to(Vector2(t)) >= 8.0):
			out.append(t)
	return out


## The land edge tile in direction `dir` from `from`, or the nearest land edge tile to it.
func _edge_towards(from: Vector2, dir: Vector2) -> Vector2i:
	var p := from
	var last := Vector2i(from.round())
	for step in m.size * 2:
		p += dir.normalized()
		var t := Vector2i(p.round())
		if not m.in_bounds(t):
			break
		last = t
	var best := Vector2i(-1, -1)
	var best_d := INF
	for t in _edge_tiles():
		if not c.is_land(t):
			continue
		var d := Vector2(t).distance_to(Vector2(last))
		if d < best_d:
			best_d = d
			best = t
	return best


func _spawn_road(v: Dictionary, s: Vector2i) -> void:
	var g := _gate_towards(v, s)
	if _route_and_carve(_gate_exit(v, g), s, true):
		used[g] = true


func _collect_spawns() -> void:
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.is_road(t) and m.is_edge(t):
				m.edge_spawns.append(t)
	if m.villages.size() == 1:
		m.villages[0]["home_spawns"] = m.edge_spawns.duplicate()
		return
	for t in m.edge_spawns:
		var s := m.slice_of[c.i(t)]
		var owner := 0
		for i in m.villages.size():
			if int(m.villages[i]["slice"]) == s:
				owner = i
		(m.villages[owner]["home_spawns"] as Array[Vector2i]).append(t)


# --- routing ----------------------------------------------------------------------------------

## Routes and carves a road; `pass_ok`: may cut through mountains if needed.
func _route_and_carve(from: Vector2i, to: Vector2i, pass_ok: bool) -> bool:
	var path := _route(from, to, false)
	if path.is_empty() and pass_ok:
		path = _route(from, to, true)
	if path.is_empty():
		return false
	_carve(path)
	return true


func _route(from: Vector2i, to: Vector2i, allow_pass: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not m.in_bounds(from) or not m.in_bounds(to):
		return out
	var opened: Array[Vector2i] = []
	for t in [from, to]:
		if astar.is_point_solid(t) and not m.in_village(t):
			astar.set_point_solid(t, false)
			opened.append(t)
	var cut: Array[Vector2i] = []
	if allow_pass:
		for y in range(1, m.size - 1):
			for x in range(1, m.size - 1):
				var t := Vector2i(x, y)
				if m.is_mountain(t) and not GenRelief._volcano_tile(c, t):
					astar.set_point_solid(t, false)
					astar.set_point_weight_scale(t, Config.ROAD_COSTS["pass"])
					cut.append(t)
	for t in astar.get_id_path(from, to):
		out.append(t)
	for t in cut:
		astar.set_point_solid(t, true)
	for t in opened:
		if not m.is_road(t) or m.is_edge(t):
			astar.set_point_solid(t, true)
	return out



## Makes `path` road: bridges over rivers, fords through shallow water,
## passes through mountains.
func _carve(path: Array[Vector2i]) -> void:
	for k in path.size():
		var t := path[k]
		var v := m.get_terrain(t)
		if v == MapData.Terrain.ROAD:
			continue
		var along := path[mini(k + 1, path.size() - 1)] - path[maxi(k - 1, 0)]
		if v == MapData.Terrain.WATER or v == MapData.Terrain.LAVA:
			var style: String = Config.BRIDGE_STYLES.get(m.zone(t), "timber")
			if v == MapData.Terrain.LAVA:
				style = "charred"
			m.crossings[t] = ["bridge_%s_%s" % [style, "x" if absi(along.x) >= absi(along.y) else "y"], v]
		elif v == MapData.Terrain.SHALLOW:
			m.crossings[t] = ["tile_ford", v]
		_set_road(t)


func _set_road(t: Vector2i) -> void:
	if not m.in_bounds(t):
		return
	m.set_terrain(t, MapData.Terrain.ROAD)
	m.props.erase(t)
	m.decor.erase(t)
	if not m.in_village(t):
		astar.set_point_solid(t, m.is_edge(t))
	astar.set_point_weight_scale(t, Config.ROAD_COSTS["road"])
	for nb in MapData.neighbors4(t):
		if m.in_bounds(nb) and not m.is_road(nb) and not _beside.has(nb):
			_beside[nb] = true
			astar.set_point_weight_scale(nb, base_cost[c.i(nb)] + Config.ROAD_BESIDE_COST)


# --- gates ------------------------------------------------------------------------------------

## Marks the tile just outside gate `g` as road and returns the first tile past
## the walls' ring, where the road proper starts.
func _gate_exit(v: Dictionary, g: Vector2i) -> Vector2i:
	var dir := (g - (v["center"] as Vector2i)).sign()
	_set_road(g + dir)
	return g + dir * 2


## The village's gate pointing most towards `target`, preferring unused gates.
func _gate_towards(v: Dictionary, target: Vector2i) -> Vector2i:
	var to := (Vector2(target) - Vector2(v["center"])).normalized()
	var best: Vector2i = v["gates"][0]
	var best_s := -INF
	for g in v["gates"]:
		var s := Vector2(g - (v["center"] as Vector2i)).normalized().dot(to) - (1.5 if used.has(g) else 0.0)
		if s > best_s:
			best_s = s
			best = g
	return best


## Gates with a road leading away from the village.
func _approaches(v: Dictionary) -> int:
	return approaches(m, v)


static func approaches(map: MapData, v: Dictionary) -> int:
	var n := 0
	for g in v["gates"]:
		var dir: Vector2i = (g - (v["center"] as Vector2i)).sign()
		if map.is_road(g + dir * 2):
			n += 1
	return n


func _edge_tiles() -> Array[Vector2i]:
	return GenWater._edge_tiles(m)
