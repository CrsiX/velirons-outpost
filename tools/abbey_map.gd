extends RefCounted
## Scenario 9's map, the drowned abbey's shore (docs/scenarios-design.md §9a)
## (make_scenario_map.gd, "abbey"): a generated temperate map for the land
## (its zones, woods, rivers, ponds and hills), its roads, village and objects
## taken out, and the scenario's features laid over it:
## - the sea along the south edge, its shore wandering, straight in front of
##   the harbour; a quay below the south gate;
## - the village a few tiles above it, a walled 9x7 block (not the standard
##   5x5) with four gates, 9 huts and room in its north-east corner for the
##   new church (the scenario builds it there: CHURCH);
## - straight north of the north gate the abbey's island in a lake, the road
##   crossing it on two straight bridges and going on to the north edge (the
##   Legion's road); a vampire camp beside the abbey; two ruined watchtowers
##   and a ruined barracks on it (ISLAND_RUINS);
## - a deep channel winding from the lake down the east side to the sea, so
##   water monsters move between them;
## - roads to the west, north and east edges; water spawns in the sea and the lake.
## Roads only turn on land: a water tile where a road turns becomes land, so
## every bridge and ford runs straight. The generated treasures, camps and
## mines that still fit stay, with a footpath to the nearest road.

const SIZE := 75
const C := Vector2i(37, 46)
## The walls' half sizes (the ring runs dx -HX..HX, dy -HY..HY).
const HX := 4
const HY := 3
## The gates (offsets from C): north, south, west, east.
const GATES: Array[Vector2i] = [Vector2i(0, -HY), Vector2i(0, HY), Vector2i(-HX, 0), Vector2i(HX, 1)]
## The huts, and the new church's 3x3 (its centre: the scenario's prebuilt tile).
const HUTS: Array[Vector2i] = [Vector2i(-3, -2), Vector2i(-2, -2), Vector2i(-1, -2),
	Vector2i(-3, 2), Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
const CHURCH := Vector2i(2, -1)
## The road inside the walls, gate to gate.
const INSIDE: Array[Vector2i] = [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2),
	Vector2i(-3, 0), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
## Open land kept round the walls (tiles), and how far from the village centre objects keep.
const VILLAGE_MARGIN := 3
const OBJECTS_FROM_VILLAGE := 16.0
## Open meadow round the quay, nothing on it (tiles).
const QUAY_CLEAR := 8.0
## The lake and its island (centre; radii in tiles), straight north of the
## north gate: the island's land, the lake's mean radius and how much its
## shore wanders.
const ISLAND := Vector2i(37, 28)
const LAND := 5.5
const LAKE := 10.5
const LAKE_RAGGED := 1.6
## The channel's course from the lake to the sea (it meanders between these),
## and its half width in deep water.
const CHANNEL: Array[Vector2i] = [Vector2i(46, 29), Vector2i(51, 33), Vector2i(52, 40), Vector2i(51, 47), Vector2i(53, 54), Vector2i(55, 61)]
const CHANNEL_HALF := 1.1
## The sea's shore (the first deep row; it wanders, straight in front of the
## harbour) and about where the quay below the south gate is (its road runs on to the water).
const SHORE := 59
const SHORE_RAGGED := 3.0
const QUAY := 56
## Ruins on the island (offsets from ISLAND): two watchtowers by its bridges
## and a barracks, abandoned: the hero claims them, builders restore them,
## so the abbey can be held.
const ISLAND_RUINS: Array = [["tower", Vector2i(-3, -3)], ["tower", Vector2i(-2, 4)], ["barracks", Vector2i(3, 2)]]
## Generated objects of these kinds stay (if their tile still fits).
const KEEP := ["treasure", "camp", "mine"]

var m: MapData
var rng := RandomNumberGenerator.new()
var _shore_noise := FastNoiseLite.new()
var _spawns: Array[Vector2i] = []
## The quay: the harbour road's end at the water.
var _quay := Vector2i(C.x, QUAY)
## Deep water tiles, and those of the sea (for its beaches).
var _deep := {}
var _sea_tiles := {}


## The map: {"map": MapData, "church": its centre tile, "quay": the quay's end by the water}.
static func make(seed_value: int) -> Dictionary:
	var b := new()
	return b._make(seed_value)


func _make(seed_value: int) -> Dictionary:
	rng.seed = seed_value
	_shore_noise.seed = rng.randi()
	_shore_noise.frequency = 0.08
	m = MapGenerator.generate(seed_value, 1, "temperate")
	m.seed_value = seed_value
	var kept := _strip()
	_sea()
	_lake()
	_channel()
	_water()
	_village()
	m.villages = [{"center": C, "home_spawns": _spawns}]
	m.derive()
	_roads()
	_straight_crossings()
	_clearings()
	_objects(kept)
	_water_spawns()
	m.villages[0]["home_spawns"] = _spawns
	m.derive()
	_beaches()
	MapTidy.tidy_all(m)
	return {"map": m, "church": C + CHURCH, "quay": _quay}


# --- the generated map, emptied ----------------------------------------------------------------

## Its roads (bridges and fords back to water), village, water spawns and
## objects taken out: its objects returned (as numbered there: camps point at
## their treasure by that number).
func _strip() -> Array[Dictionary]:
	for y in SIZE:
		for x in SIZE:
			var t := Vector2i(x, y)
			if not m.is_road(t):
				continue
			if m.crossings.has(t):
				m.set_terrain(t, int(m.crossings[t][1]))
				m.crossings.erase(t)
			else:
				m.set_terrain(t, MapTidy.ground(m, t))
	m.village_layout.clear()
	m.villages.clear()
	m.village_links.clear()
	m.water_spawns.clear()
	var kept: Array[Dictionary] = []
	kept.assign(m.objects.duplicate())
	m.objects.clear()
	return kept


# --- the water ---------------------------------------------------------------------------------

## The sea along the south edge: deep from the shore line down.
func _sea() -> void:
	for x in SIZE:
		var off := absi(x - C.x)
		var ragged := SHORE_RAGGED * _shore_noise.get_noise_1d(x * 1.0) * clampf((off - 5) / 5.0, 0.0, 1.0)
		for y in range(SHORE + roundi(ragged), SIZE):
			_sea_tiles[Vector2i(x, y)] = true
			_deep[Vector2i(x, y)] = true


## The lake round the island: deep between the island and its wandering shore.
func _lake() -> void:
	var r := ceili(LAKE + LAKE_RAGGED)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := Vector2(dx, dy).length()
			var shore := LAKE + LAKE_RAGGED * _shore_noise.get_noise_1d(Vector2(dx, dy).angle() * 6.0 + 500.0)
			if d > LAND + 1.0 and d <= shore:
				_deep[ISLAND + Vector2i(dx, dy)] = true


## The channel from the lake to the sea, along CHANNEL's course.
func _channel() -> void:
	for i in range(1, CHANNEL.size()):
		var a := Vector2(CHANNEL[i - 1])
		var b := Vector2(CHANNEL[i])
		var steps := ceili(a.distance_to(b) * 3.0)
		for k in steps + 1:
			var p := a.lerp(b, float(k) / steps)
			var r := ceili(CHANNEL_HALF)
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var t := Vector2i(p.round()) + Vector2i(dx, dy)
					if Vector2(t).distance_to(p) <= CHANNEL_HALF and Vector2(t).distance_to(Vector2(ISLAND)) > LAND + 1.0:
						_deep[t] = true


## Deep water where it was marked, a rim of shallow water round it, the
## island open meadow with a few trees; the rest of the land as generated.
func _water() -> void:
	for y in SIZE:
		for x in SIZE:
			var t := Vector2i(x, y)
			if _deep.has(t):
				m.set_zone(t, "meadow")
				m.set_terrain(t, MapData.Terrain.WATER)
				continue
			var di := Vector2(t).distance_to(Vector2(ISLAND))
			if di <= LAND:
				m.set_zone(t, "meadow")
				m.set_terrain(t, MapData.Terrain.FOREST if di > 3.5 and rng.randf() < 0.08 else MapData.Terrain.GRASS)
				continue
			var by_deep := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if _deep.has(t + Vector2i(dx, dy)):
						by_deep = true
			if by_deep:
				if m.get_terrain(t) != MapData.Terrain.WATER:
					m.set_terrain(t, MapData.Terrain.SHALLOW)
				if _sea_tiles.has(t + Vector2i.DOWN) or _sea_tiles.has(t + Vector2i(0, 2)):
					_sea_tiles[t] = true


# --- the village -------------------------------------------------------------------------------

## The 9x7 ring, its huts, open meadow inside and round it (mountains,
## water and trees cleared).
func _village() -> void:
	for dy in range(-HY - VILLAGE_MARGIN, HY + VILLAGE_MARGIN + 1):
		for dx in range(-HX - VILLAGE_MARGIN, HX + VILLAGE_MARGIN + 1):
			var t := C + Vector2i(dx, dy)
			if _deep.has(t):
				continue
			m.set_zone(t, "meadow")
			m.set_terrain(t, MapData.Terrain.GRASS)
			m.props.erase(t)
			m.decor.erase(t)
	for dy in range(-HY, HY + 1):
		for dx in range(-HX, HX + 1):
			var side := absi(dx) == HX
			var top := absi(dy) == HY
			if not side and not top:
				continue
			var kind := "wall_tower" if side and top else ("gate" if GATES.has(Vector2i(dx, dy)) else "wall")
			m.village_layout.append({"kind": kind, "tile": C + Vector2i(dx, dy), "flip": side, "owner": 0})
	for h in HUTS:
		m.village_layout.append({"kind": "hut", "tile": C + h, "flip": false, "owner": 0})


# --- the roads ---------------------------------------------------------------------------------

func _roads() -> void:
	var inside: Array[Vector2i] = []
	for g in GATES:
		inside.append(C + g)
	for t in INSIDE:
		inside.append(C + t)
	EditorTools.paint_road(m, inside, false)
	# North: straight over the lake and the island, then on to the edge.
	var north: Array[Vector2i] = []
	for y in range(C.y - HY - 1, ISLAND.y - ceili(LAKE + LAKE_RAGGED) - 3, -1):
		north.append(Vector2i(C.x, y))
	_open(north)
	EditorTools.paint_road(m, north, false)
	var up := _lay([north[-1], Vector2i(C.x + rng.randi_range(-8, 8), 0)])
	_spawns.append(up[-1])
	# West to the edge.
	var west := _lay([C + GATES[2] + Vector2i.LEFT, Vector2i(C.x - 18, C.y + rng.randi_range(-6, 3)), Vector2i(0, C.y + rng.randi_range(-12, 4))])
	_spawns.append(west[-1])
	# East: straight over the channel, then on to the edge.
	var ey := C.y + GATES[3].y
	var straight: Array[Vector2i] = []
	for x in range(C.x + HX + 1, 58):  # (past the channel)
		straight.append(Vector2i(x, ey))
	_open(straight)
	EditorTools.paint_road(m, straight, false)
	var east := _lay([straight[-1], Vector2i(SIZE - 1, ey + rng.randi_range(-14, 2))])
	_spawns.append(east[-1])
	# The harbour: from the south gate down to the quay at the water's edge.
	var down: Array[Vector2i] = []
	var y := C.y + HY + 1
	while y < SIZE - 1 and not _deep.has(Vector2i(C.x, y + 1)) and m.get_terrain(Vector2i(C.x, y + 1)) != MapData.Terrain.SHALLOW:
		down.append(Vector2i(C.x, y))
		y += 1
	down.append(Vector2i(C.x, y))
	_quay = down[-1]
	_open(down)
	EditorTools.paint_road(m, down, false)


## Mountains and trees on `tiles` gone (a road laid straight through them).
func _open(tiles: Array[Vector2i]) -> void:
	for t in tiles:
		if m.is_mountain(t) or m.is_forest(t):
			m.set_terrain(t, MapTidy.ground(m, t))
			m.props.erase(t)


## A road through `points` in order (each stretch the cheapest way): its tiles, first to last.
func _lay(points: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(1, points.size()):
		for t in EditorTools.road_path(m, points[i - 1], points[i]):
			if out.is_empty() or out[-1] != t:
				out.append(t)
	EditorTools.paint_road(m, out, false)
	return out


## Roads only turn on land: a crossing (bridge or ford) whose road doesn't
## go straight on in both directions becomes land; the others are set again
## for their direction.
func _straight_crossings() -> void:
	var again := true
	while again:
		again = false
		for t: Vector2i in m.crossings.keys():
			var dirs: Array[Vector2i] = []
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if m.is_road(t + d):
					dirs.append(d)
			if dirs.size() == 2 and dirs[0] == -dirs[1]:
				continue
			m.crossings.erase(t)
			m.set_zone(t, "meadow")
			m.set_terrain(t, MapData.Terrain.ROAD)
			_deep.erase(t)
			again = true
	for t: Vector2i in m.crossings.keys():
		MapTidy.set_crossing(m, t, int(m.crossings[t][1]))


## Open land along the roads, round the lake (open banks) and the quay.
func _clearings() -> void:
	for y in SIZE:
		for x in SIZE:
			var t := Vector2i(x, y)
			if not m.is_forest(t):
				continue
			var by_road := MapData.neighbors4(t).any(func(n: Vector2i) -> bool: return m.in_bounds(n) and m.is_road(n))
			var by_lake := Vector2(t).distance_to(Vector2(ISLAND)) <= LAKE + LAKE_RAGGED + 1.5
			if by_road or by_lake:
				m.set_terrain(t, MapTidy.ground(m, t))
	# The harbour: open meadow, nothing on it.
	var r := ceili(QUAY_CLEAR)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := Vector2i(C.x + dx, QUAY + dy)
			if not m.in_bounds(t) or Vector2(dx, dy).length() > QUAY_CLEAR or m.is_water(t):
				continue
			m.set_zone(t, "meadow")
			m.decor.erase(t)
			if m.is_forest(t) or m.is_mountain(t) or m.get_terrain(t) == MapData.Terrain.DESERT:
				m.set_terrain(t, MapData.Terrain.GRASS)


# --- the objects -------------------------------------------------------------------------------

## The abbey on the island, its vampires across the road; the generated
## treasures, camps and mines that still fit (a camp only with its treasure,
## moved next to it if its own tile no longer fits), each with a footpath to
## the road.
func _objects(kept: Array[Dictionary]) -> void:
	var abbey := _treasure_at(ISLAND + Vector2i(2, -1), 2, "abbey", 3, {})
	_camp_at(abbey, ISLAND + Vector2i(-3, 1), ["vampire", "vampire", "skeleton"])
	for ru: Array in ISLAND_RUINS:
		var size := 2 if ru[0] == "barracks" else 1
		var t: Vector2i = ISLAND + (ru[1] as Vector2i)
		for q in Building.footprint(t, size):
			m.set_terrain(q, MapTidy.ground(m, q))
		var o := {"kind": "ruin", "tile": t, "size": size, "building": str(ru[0])}
		o["art"] = MapJson.object_art(o)
		m.objects.append(o)
	var index := {}
	for i in kept.size():
		var o := kept[i]
		if o["kind"] == "camp" or not KEEP.has(o["kind"]):
			continue
		if not Building.footprint(o["tile"], int(o.get("size", 1))).all(_fits):
			continue
		o.erase("slice")
		if o["kind"] == "treasure":
			o["guard"] = -1
		index[i] = m.objects.size()
		m.objects.append(o)
		_trail(o["tile"])
	for o in kept:
		if o["kind"] != "camp" or not index.has(int(o["guards"])):
			continue
		if not _fits(o["tile"]):  # (moved next to its treasure)
			var by: Vector2i = m.objects[int(index[int(o["guards"])])]["tile"]
			var spot := Vector2i(-1, -1)
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2)]:
				if spot.x < 0 and _fits(by + d):
					spot = by + d
			if spot.x < 0:
				continue
			o["tile"] = spot
		o.erase("slice")
		o["guards"] = index[int(o["guards"])]
		m.objects.append(o)
		m.objects[int(o["guards"])]["guard"] = m.objects.size() - 1
		_trail(o["tile"])


## An object can stay on `t`: land, off the roads, away from the village, the lake and the other objects.
func _fits(t: Vector2i) -> bool:
	if not m.in_bounds(t) or m.is_edge(t) or m.is_water(t) or m.is_road(t) or m.is_mountain(t):
		return false
	if Vector2(t).distance_to(Vector2(C)) <= OBJECTS_FROM_VILLAGE:
		return false
	if Vector2(t).distance_to(Vector2(ISLAND)) <= LAKE + LAKE_RAGGED + 2.0:
		return false
	return not m.objects.any(func(o: Dictionary) -> bool: return (o["tile"] as Vector2i).distance_to(t) < 2.0)


func _treasure_at(t: Vector2i, size: int, kind: String, tier: int, reward: Dictionary) -> int:
	for q in Building.footprint(t, size):
		m.set_terrain(q, MapTidy.ground(m, q))
	var o := {"kind": "treasure", "tile": t, "size": size, "treasure": kind, "tier": tier, "guard": -1, "reward": reward}
	o["art"] = MapJson.object_art(o)
	m.objects.append(o)
	return m.objects.size() - 1


func _camp_at(ti: int, t: Vector2i, monsters: Array) -> void:
	m.set_terrain(t, MapTidy.ground(m, t))
	var o := {"kind": "camp", "tile": t, "size": 1, "tier": 3, "guards": ti, "monsters": monsters.duplicate()}
	o["art"] = MapJson.object_art(o)
	m.objects.append(o)
	m.objects[ti]["guard"] = m.objects.size() - 1


## A footpath (trees felled) from `t` to the nearest road, so it can be walked to.
func _trail(t: Vector2i) -> void:
	if m.is_forest(t):
		m.set_terrain(t, MapTidy.ground(m, t))
	var best := Vector2i(-1, -1)
	for y in SIZE:
		for x in SIZE:
			var r := Vector2i(x, y)
			if m.is_road(r) and not m.in_village(r) and not m.crossings.has(r) and (best.x < 0 or r.distance_to(t) < best.distance_to(t)):
				best = r
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, SIZE, SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in SIZE:
		for x in SIZE:
			var p := Vector2i(x, y)
			if m.is_mountain(p) or m.in_village(p) or m.is_water(p):
				astar.set_point_solid(p, true)
			elif m.is_forest(p):
				astar.set_point_weight_scale(p, 3.0)
	astar.set_point_solid(t, false)
	for p in astar.get_id_path(t, best):
		if m.is_forest(p):
			m.set_terrain(p, MapTidy.ground(m, p))


## Two in the sea (west and east of the harbour), one in the lake (its west side).
func _water_spawns() -> void:
	m.water_spawns = [Vector2i(14, SIZE - 4), Vector2i(SIZE - 12, SIZE - 4), ISLAND + Vector2i(-8, 0)]


# --- the finish --------------------------------------------------------------------------------

## Beaches: open land by the sea (the lake's and the channel's banks stay green).
func _beaches() -> void:
	m.beaches.clear()
	for y in SIZE:
		for x in SIZE:
			var t := Vector2i(x, y)
			if m.is_water(t) or m.is_road(t) or m.in_village(t) or not m.is_passable(t):
				continue
			if MapData.neighbors4(t).any(func(n: Vector2i) -> bool: return _sea_tiles.has(n)):
				m.beaches[t] = true
