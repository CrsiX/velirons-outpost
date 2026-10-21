extends RefCounted
## Scenario 5's map, the old fort in the pass (docs/scenarios-design.md §7.9),
## laid out here rather than generated (make_scenario_map.gd, "citadel"): a
## mountain range across the middle from west to east, the only pass straight
## through it north to south, and the fort filling the pass: two walls across
## it from mountain to mountain, a road bending a little from gate to gate, 4
## huts inside in two rows of two, a dried-up well and one dead tree (the
## scenario puts two barracks and training grounds beside the road). North of
## the range oak woods and pine (the wilderness: the camps), south of it
## meadow and steppe. Roads from the north and south edges to the gates, and
## from the west and east edges on both sides, joining them before the pass.

const SIZE := 75
## The walls stand this many rows north and south of the centre.
const WALL_AT := 4
## Half the pass's width inside the fort (7 tiles); it widens beyond the walls.
const HALF := 3
## Half the range's depth at least, and how ragged its edges are (tiles).
const RANGE_HALF := 6
const RAGGED := 3.0
## The fort's inside, as offsets from the centre: the gates (north, south;
## the north one a tile west, so the road bends), the road between them, the
## huts (two rows of two, a tile apart, a tile clear of the mountains), the
## dried-up well and the one tree (a dead one: the zone's).
const NORTH_GATE := Vector2i(-1, -WALL_AT)
const SOUTH_GATE := Vector2i(0, WALL_AT)
const ROAD: Array[Vector2i] = [Vector2i(-1, -3), Vector2i(-1, -2), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0),
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
const HUTS: Array[Vector2i] = [Vector2i(0, -3), Vector2i(2, -3), Vector2i(0, -1), Vector2i(2, -1)]
const WELL := Vector2i(-2, -1)
const TREE := Vector2i(-3, 0)

var m: MapData
var c: Vector2i
var rng := RandomNumberGenerator.new()
var _edge_noise := FastNoiseLite.new()
var _zone_noise := FastNoiseLite.new()
var _wood_noise := FastNoiseLite.new()
## Per column: the range's first and last mountain row.
var _top := PackedInt32Array()
var _bottom := PackedInt32Array()
## The edge road tiles (the village's spawns).
var _spawns: Array[Vector2i] = []


## The map, and where Sigmund's tent goes: {"map": MapData, "tent": Vector2i}.
static func make(seed_value: int) -> Dictionary:
	var b := new()
	return b._make(seed_value)


func _make(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	for n: FastNoiseLite in [_edge_noise, _zone_noise, _wood_noise]:
		n.seed = rng.randi()
	_edge_noise.frequency = 0.09
	_zone_noise.frequency = 0.05
	_wood_noise.frequency = 0.11
	m = MapData.new(SIZE)
	m.map_type = "highlands"
	m.seed_value = seed_value
	c = Vector2i(SIZE / 2, SIZE / 2)
	_land()
	_fort()
	m.villages = [{"center": c, "home_spawns": _spawns}]
	m.derive()
	_roads()
	_open_mouths()
	var objects := _objects()
	m.villages[0]["home_spawns"] = _spawns
	m.derive()
	MapTidy.tidy_all(m)
	_decor()
	m.decor[c + WELL] = "well_dry"
	return {"map": m, "tent": objects["tent"]}


# --- the land ----------------------------------------------------------------------------------

func _land() -> void:
	_top.resize(SIZE)
	_bottom.resize(SIZE)
	for x in SIZE:
		var up := roundi(RAGGED * (1.0 + 2.0 * _edge_noise.get_noise_1d(x)))
		var down := roundi(RAGGED * (1.0 + 2.0 * _edge_noise.get_noise_1d(x + 500.0)))
		_top[x] = clampi(c.y - RANGE_HALF - up, c.y - RANGE_HALF - 3 * int(RAGGED), c.y - WALL_AT - 2)
		_bottom[x] = clampi(c.y + RANGE_HALF + down, c.y + WALL_AT + 2, c.y + RANGE_HALF + 3 * int(RAGGED))
	for y in SIZE:
		for x in SIZE:
			var t := Vector2i(x, y)
			if y >= _top[x] and y <= _bottom[x]:
				m.set_zone(t, "heath")
				m.set_terrain(t, MapData.Terrain.GRASS if _in_pass(t) else MapData.Terrain.MOUNTAIN)
			elif y < _top[x]:
				_north(t)
			else:
				_south(t)
			# Foothills: rocks just outside the range.
			var off := _top[x] - y if y < _top[x] else y - _bottom[x]
			if off > 0 and off <= 3 and _edge_noise.get_noise_2d(x * 3.0, y * 3.0) > 0.25 + 0.1 * off and absi(x - c.x) > HALF + 6:
				m.set_terrain(t, MapData.Terrain.MOUNTAIN)


## Open ground in the pass: 7 tiles wide by the fort, wider beyond the walls.
func _in_pass(t: Vector2i) -> bool:
	var dy := absi(t.y - c.y)
	var half := HALF if dy <= WALL_AT + 1 else mini(HALF + int((dy - WALL_AT) * 0.8), HALF + 6)
	var shift := 0 if dy <= WALL_AT + 2 else roundi(1.5 * _edge_noise.get_noise_1d(t.y * 2.0 + 900.0))
	return absi(t.x - c.x - shift) <= half


## The wilderness: oak woods with pine stands, forest with clearings.
func _north(t: Vector2i) -> void:
	var pine := _zone_noise.get_noise_2d(t.x, t.y) > 0.15
	m.set_zone(t, "pine" if pine else "oak")
	var wood := _wood_noise.get_noise_2d(t.x, t.y)
	m.set_terrain(t, MapData.Terrain.FOREST if wood > (-0.3 if pine else -0.05) else MapData.Terrain.GRASS)


## The kingdom's side: meadow with steppe spots and a few trees.
func _south(t: Vector2i) -> void:
	var steppe := _zone_noise.get_noise_2d(t.x + 300.0, t.y) > 0.3
	m.set_zone(t, "steppe" if steppe else "meadow")
	var tree := rng.randf() < (0.03 if steppe else 0.07)
	m.set_terrain(t, MapData.Terrain.FOREST if tree else (MapData.Terrain.DESERT if steppe else MapData.Terrain.GRASS))


# --- the fort ----------------------------------------------------------------------------------

func _fort() -> void:
	for y in range(c.y - WALL_AT, c.y + WALL_AT + 1):
		for x in range(c.x - HALF - 1, c.x + HALF + 2):
			var t := Vector2i(x, y)
			m.set_zone(t, "heath")
			m.set_terrain(t, MapData.Terrain.MOUNTAIN if absi(x - c.x) > HALF else MapData.Terrain.GRASS)
	for gate: Vector2i in [NORTH_GATE, SOUTH_GATE]:
		for x in range(-HALF, HALF + 1):
			var kind := "wall_tower" if absi(x) == HALF else ("gate" if x == gate.x else "wall")
			m.village_layout.append({"kind": kind, "tile": c + Vector2i(x, gate.y), "flip": false, "owner": 0})
	for h in HUTS:
		m.village_layout.append({"kind": "hut", "tile": c + h, "flip": false, "owner": 0})
	m.set_terrain(c + TREE, MapData.Terrain.FOREST)


# --- the roads ---------------------------------------------------------------------------------

func _roads() -> void:
	var inside: Array[Vector2i] = [c + NORTH_GATE, c + SOUTH_GATE]
	for t in ROAD:
		inside.append(c + t)
	EditorTools.paint_road(m, inside, false)
	var north_out := c + NORTH_GATE + Vector2i.UP
	var south_out := c + SOUTH_GATE + Vector2i.DOWN
	var north := _lay([north_out, Vector2i(c.x, _top[c.x] - 2), Vector2i(c.x + rng.randi_range(-8, 8), 0)])
	var south := _lay([south_out, Vector2i(c.x, _bottom[c.x] + 2), Vector2i(c.x + rng.randi_range(-8, 8), SIZE - 1)])
	_spawns.append(north[-1])
	_spawns.append(south[-1])
	# Side roads from the west and east edges, joining the main road before the pass.
	var nj := _road_tile_at(north, _top[c.x] - 7)
	var sj := _road_tile_at(south, _bottom[c.x] + 7)
	for side in [-1, 1]:
		var ny := rng.randi_range(8, _top[0 if side < 0 else SIZE - 1] - 8)
		var sy := rng.randi_range(_bottom[0 if side < 0 else SIZE - 1] + 8, SIZE - 9)
		var ex := 0 if side < 0 else SIZE - 1
		var nr := _lay([Vector2i(ex, ny), Vector2i(c.x + side * 18, ny + rng.randi_range(-3, 3)), nj])
		var sr := _lay([Vector2i(ex, sy), Vector2i(c.x + side * 18, sy + rng.randi_range(-3, 3)), sj])
		_spawns.append(nr[0])
		_spawns.append(sr[0])
	_prune()


## Road doubled where two routes run side by side (a 2x2 block of road): such
## tiles go back to ground, one at a time, as long as every road tile left is
## still joined to the rest; and stubs (a road tile with one road neighbour,
## not at the map edge) too.
func _prune() -> void:
	var keep := {}
	for t in _spawns:
		keep[t] = true
	var again := true
	while again:
		again = false
		for y in SIZE:
			for x in SIZE:
				var t := Vector2i(x, y)
				if not m.is_road(t) or keep.has(t) or m.in_village(t):
					continue
				var ends := MapData.neighbors4(t).filter(func(n: Vector2i) -> bool: return m.is_road(n)).size() <= 1
				if ends:  # (a stub sticking out of the road, going nowhere)
					m.set_terrain(t, MapTidy.ground(m, t))
					again = true
					continue
				if not _in_block(t):
					continue
				m.set_terrain(t, MapTidy.ground(m, t))
				if _joined():
					again = true
				else:
					m.set_terrain(t, MapData.Terrain.ROAD)


## Road tile `t` is one corner of a 2x2 block of road.
func _in_block(t: Vector2i) -> bool:
	for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var o: Vector2i = t + d
		if m.is_road(o) and m.is_road(o + Vector2i.RIGHT) and m.is_road(o + Vector2i.DOWN) and m.is_road(o + Vector2i.ONE):
			return true
	return false


## Every road tile is joined to every other (4-connected).
func _joined() -> bool:
	var all := 0
	var start := Vector2i(-1, -1)
	for y in SIZE:
		for x in SIZE:
			if m.is_road(Vector2i(x, y)):
				all += 1
				start = Vector2i(x, y)
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var i := 0
	while i < q.size():
		for n in MapData.neighbors4(q[i]):
			if m.in_bounds(n) and m.is_road(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
		i += 1
	return seen.size() == all


## A road through `points` in order (each stretch the cheapest way, a little
## wiggle between them): its tiles, first to last.
func _lay(points: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var mid := (a + b) / 2 + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		mid = mid.clamp(Vector2i(1, 1), Vector2i(SIZE - 2, SIZE - 2))
		var legs: Array[Vector2i] = [a, b]
		if a.distance_to(Vector2(b)) >= 10.0 and not m.is_mountain(mid):
			legs.insert(1, mid)
		for k in range(1, legs.size()):
			var p := EditorTools.road_path(m, legs[k - 1], legs[k])
			for t in p:
				if out.is_empty() or out[-1] != t:
					out.append(t)
	EditorTools.paint_road(m, out, false)
	return out


## The tile of `road` nearest row `y`.
func _road_tile_at(road: Array[Vector2i], y: int) -> Vector2i:
	var best := road[0]
	for t in road:
		if absi(t.y - y) < absi(best.y - y):
			best = t
	return best


## Open land in front of both ends of the pass, for towers and farms.
func _open_mouths() -> void:
	for mouth in [Vector2i(c.x, _top[c.x] - 1), Vector2i(c.x, _bottom[c.x] + 1)]:
		for dy in range(-6, 7):
			for dx in range(-7, 8):
				var t: Vector2i = mouth + Vector2i(dx, dy)
				if m.in_bounds(t) and m.is_forest(t) and Vector2(dx, dy * 1.3).length() <= 6.5:
					m.set_terrain(t, MapTidy.ground(m, t))


# --- the objects -------------------------------------------------------------------------------

## The treasures (the evidence: two guarded ones in the north (tier 3), one
## in the south (tier 2); a small chest a side (tier 1)) and Sigmund's tent: {"tent": tile}.
func _objects() -> Dictionary:
	var guarded := [
		[Vector2i(c.x - 22, 11), ["goblin", "goblin", "ork"]],
		[Vector2i(c.x + 21, 8), ["goblin", "ork", "ork"]],
	]
	for g in guarded:
		var ti := _treasure(g[0], "ruins", 3, {"gold": 120, "materials": 40})
		_camp(ti, g[1])
	_treasure(Vector2i(c.x + 9, _top[c.x + 9] - 9), "chest", 1, {"gold": 50})
	_treasure(Vector2i(c.x + 21, SIZE - 11), "shrine", 2, {"hero_xp": 100})
	_treasure(Vector2i(c.x - 23, SIZE - 15), "chest", 1, {"gold": 60})
	var tent := _spot(Vector2i(c.x - 13, _bottom[c.x - 13] + 9))
	_trail(tent)
	return {"tent": tent}


## A treasure near `near`: its index in m.objects.
func _treasure(near: Vector2i, kind: String, tier: int, reward: Dictionary) -> int:
	var t := _spot(near)
	_trail(t)
	var o := {"kind": "treasure", "tile": t, "size": 1, "treasure": kind, "tier": tier, "guard": -1, "reward": reward}
	o["art"] = MapJson.object_art(o)
	m.objects.append(o)
	return m.objects.size() - 1


## A camp with `monsters` beside treasure `ti`.
func _camp(ti: int, monsters: Array) -> void:
	var t0: Vector2i = m.objects[ti]["tile"]
	for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2)]:
		var t: Vector2i = t0 + d
		if _free(t):
			_clear(t, 1)
			var o := {"kind": "camp", "tile": t, "size": 1, "tier": 3, "guards": ti, "monsters": monsters.duplicate()}
			o["art"] = MapJson.object_art(o)
			m.objects.append(o)
			m.objects[ti]["guard"] = m.objects.size() - 1
			return
	push_error("no room for a camp by %s" % t0)


## The open tile nearest `near` (a clearing made round it), off the roads and
## not beside one, on the same side of the range.
func _spot(near: Vector2i) -> Vector2i:
	near = near.clamp(Vector2i(3, 3), Vector2i(SIZE - 4, SIZE - 4))
	_clear(near, 2)
	for r in 8:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := near + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and _free(t):
					return t
	return near


func _free(t: Vector2i) -> bool:
	if not m.in_bounds(t) or m.is_edge(t) or m.is_road(t) or m.in_village(t) or m.is_mountain(t) or m.is_forest(t):
		return false
	if MapData.neighbors4(t).any(func(n: Vector2i) -> bool: return m.is_road(n)):
		return false
	return not m.objects.any(func(o: Dictionary) -> bool: return (o["tile"] as Vector2i).distance_to(t) < 1.5)


## Forest within `r` of `t` cleared (never mountains or roads).
func _clear(t: Vector2i, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := t + Vector2i(dx, dy)
			if m.in_bounds(p) and m.is_forest(p):
				m.set_terrain(p, MapTidy.ground(m, p))


## A footpath (trees felled) from `t` to the nearest road, so it can be walked to.
func _trail(t: Vector2i) -> void:
	var best := Vector2i(-1, -1)
	for y in SIZE:
		for x in SIZE:
			var r := Vector2i(x, y)
			if m.is_road(r) and not m.in_village(r) and (best == Vector2i(-1, -1) or r.distance_to(t) < best.distance_to(t)):
				best = r
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, SIZE, SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in SIZE:
		for x in SIZE:
			var p := Vector2i(x, y)
			if m.is_mountain(p) or m.in_village(p):
				astar.set_point_solid(p, true)
			elif m.is_forest(p):
				astar.set_point_weight_scale(p, 3.0)
	for p in astar.get_id_path(t, best):
		if m.is_forest(p):
			m.set_terrain(p, MapTidy.ground(m, p))


## A few boulders and cacti on open land, off roads and objects.
func _decor() -> void:
	var objects := MapTidy.object_tiles(m)
	for y in SIZE:
		for x in SIZE:
			var t := Vector2i(x, y)
			var v := m.get_terrain(t)
			if (v == MapData.Terrain.GRASS or v == MapData.Terrain.DESERT) and not m.in_village(t) and not objects.has(t) and rng.randf() < float(Config.ZONES[m.zone(t)]["decor"]):
				m.decor[t] = MapTidy.decor_for(m, t)
