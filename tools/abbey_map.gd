extends RefCounted
## Scenario 9's map, the drowned abbey's shore (docs/scenarios-design.md §9a)
## (make_scenario_map.gd, "abbey"): a generated temperate map for the land
## (its zones, woods, rivers, ponds and hills), its roads, village and objects
## taken out, and the scenario's features laid over it:
## - the sea along the south edge, its shore wandering, straight in front of
##   the harbour; a quay below the south gate;
## - a broad river (3 to 5 tiles of water) meandering from the north edge down
##   to the sea east of the village; nothing crosses it;
## - the village west of it, a walled 9x7 block (not the standard 5x5) with
##   four gates, 9 huts and room in its north-east corner for the new church
##   (the scenario builds it there: CHURCH); a quay below the south gate;
## - the abbey's island in the river north-east of the village, water round it
##   on every side; the only way onto it a road from the east gate along the
##   bank and over one straight bridge (from the village's side, bank to
##   bank: no ford at its ends); the abbey,
##   a vampire camp, two ruined watchtowers and a ruined barracks on it;
## - roads from the north edge (the Legion's) and the west edge to the
##   village; water spawns in the sea and up the river.
## Roads only turn on land: a water tile where a road turns becomes land, so
## every bridge and ford runs straight. The generated treasures, camps and
## mines that still fit (on the village's side of the river) stay, with a
## footpath to the nearest road.

const SIZE := 75
const C := Vector2i(32, 46)
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
## The abbey's island in the river: its centre, its land's half width and
## half length (an oval along the river, its shore wobbling by ISLAND_WOBBLE),
## and the river's arms round it (tiles past its land, both ways: deep in the
## middle, shallow at both edges).
const ISLAND := Vector2i(47, 37)
const LAND := Vector2(4.2, 6.5)
const ISLAND_WOBBLE := 0.12
const ARM := Vector2(3.0, 4.0)
## The river's course: its middle at RIVER_X by the island, swinging
## RIVER_SWING tiles to each side over RIVER_WAVE rows a radian; its deep
## middle's half width (RIVER_HALF, varying by RIVER_HALF_VAR), a shallow
## tile on each side of it: 3 to 5 tiles of water in all.
const RIVER_X := 47.0
const RIVER_SWING := 3.5
const RIVER_WAVE := 9.0
const RIVER_HALF := 1.2
const RIVER_HALF_VAR := 0.6
## The bank road to the island's bridge: along this column, from the east gate.
const BANK_X := 38
## The sea's shore (the first deep row; it wanders, straight in front of the
## harbour) and about where the quay below the south gate is (its road runs on to the water).
const SHORE := 59
const SHORE_RAGGED := 3.0
const QUAY := 56
## Ruins on the island (offsets from ISLAND): two watchtowers either side of
## its bridge and a barracks, abandoned: the hero claims them, builders
## restore them, so the abbey can be held.
const ISLAND_RUINS: Array = [["tower", Vector2i(-2, -2)], ["tower", Vector2i(-2, 2)], ["barracks", Vector2i(0, -5)]]
## The east road: from the east edge in the north-east corner, round the
## mountains there (by these points, each stretch the cheapest way), over
## the river on a straight bridge along row EAST_BRIDGE_Y (from EAST_BRIDGE_REACH
## tiles either side of the river's middle) and on to the north road.
const EAST_ROAD: Array[Vector2i] = [Vector2i(74, 3), Vector2i(66, 5), Vector2i(64, 12), Vector2i(58, 17)]
const EAST_BRIDGE_Y := 20
const EAST_BRIDGE_REACH := 4
## The beach: land up to BEACH_DEPTH tiles from the sea (BEACH_RAGGED more
## or less along the shore), its trees felled; sand behind the water's edge.
const BEACH_DEPTH := 3.0
const BEACH_RAGGED := 1.0
## Sandbanks off the shore, reached through shallow water: [column, tiles out
## from the shore, half width, half depth] each, a rim of shallow water round
## it and a shallow ford (two tiles wide) from it to the beach.
const SANDBANKS: Array = [[9, 6, 3.2, 1.7], [21, 5, 2.4, 1.3], [64, 6, 3.4, 1.8]]
## The beacon (the scenario puts it on the bank nearest this offset from the
## quay): the trees round it felled, a footpath to the nearest road.
const BEACON_OFFSET: Vector2i = preload("res://scripts/scenarios/scenario_9.gd").BEACON_OFFSET
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
	_river()
	_island()
	_water()
	_sandbanks()
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
	_beacon_way()
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


## The river's middle (a column) on row `y`, and its deep middle's half width there.
static func river_x(y: int) -> float:
	return RIVER_X + RIVER_SWING * sin((y - ISLAND.y) / RIVER_WAVE)


static func river_half(y: int) -> float:
	return RIVER_HALF + RIVER_HALF_VAR * sin(y / 6.0 + 1.3)


## The river from the north edge to the sea: its deep middle (the shallow
## edges come with _water), parting round the island.
func _river() -> void:
	for y in SIZE:
		var cx := river_x(y)
		var half := river_half(y)
		for x in range(floori(cx - half), ceili(cx + half) + 1):
			var t := Vector2i(x, y)
			if m.in_bounds(t) and absf(x - cx) <= half + 0.01 and island_reach(t, LAND + Vector2.ONE) > 1.0:
				_deep[t] = true


## How far `t` is out from the island's middle, in shares of the oval of
## half axes `axes` (wobbling; 1 on its rim, `phase` turns the wobble).
static func island_reach(t: Vector2i, axes: Vector2, phase := 0.0) -> float:
	var d := Vector2(t - ISLAND)
	var wobble := 1.0 + ISLAND_WOBBLE * sin(3.0 * d.angle() + phase) + ISLAND_WOBBLE * 0.5 * sin(5.0 * d.angle() + 2.0 * phase)
	return Vector2(d.x / axes.x, d.y / axes.y).length() / wobble


## The island's land.
static func on_island(t: Vector2i) -> bool:
	return island_reach(t, LAND) <= 1.0


## The river's arms round the island: deep between its shallow rims, at
## least a tile of it everywhere (so there is no way over but the bridge).
func _island() -> void:
	var outer := LAND + ARM
	for dy in range(-ceili(outer.y) - 2, ceili(outer.y) + 3):
		for dx in range(-ceili(outer.x) - 2, ceili(outer.x) + 3):
			var t := ISLAND + Vector2i(dx, dy)
			var inside := island_reach(t, outer - Vector2.ONE, 1.7) <= 1.0 or island_reach(t, LAND + Vector2(2.2, 2.2)) <= 1.0
			if inside and island_reach(t, LAND + Vector2.ONE) > 1.0:
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
			if on_island(t):
				m.set_zone(t, "meadow")
				var edge := island_reach(t, LAND) > 0.8
				m.set_terrain(t, MapData.Terrain.FOREST if edge and rng.randf() < 0.1 else MapData.Terrain.GRASS)
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


## The sandbanks off the shore (SANDBANKS), and the shallow ways to them.
func _sandbanks() -> void:
	for sb: Array in SANDBANKS:
		var x := int(sb[0])
		var shore := SIZE
		for y in SIZE:
			if _sea_tiles.has(Vector2i(x, y)):
				shore = y
				break
		var c := Vector2i(x, shore + int(sb[1]))
		var half := Vector2(float(sb[2]), float(sb[3]))
		var r := ceili(half.x) + 2
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := c + Vector2i(dx, dy)
				if not m.in_bounds(t):
					continue
				var d := Vector2(dx / half.x, dy / half.y).length()
				var rim := Vector2(dx / (half.x + 1.2), dy / (half.y + 1.2)).length()
				if d <= 1.0:
					_deep.erase(t)
					_sea_tiles.erase(t)
					m.set_zone(t, "meadow")
					m.set_terrain(t, MapData.Terrain.GRASS)
				elif rim <= 1.0:
					_shallow(t)
		for y in range(shore, c.y):
			_shallow(Vector2i(x, y))
			_shallow(Vector2i(x + 1, y))


## Sea turned shallow (still the sea's, for the beaches).
func _shallow(t: Vector2i) -> void:
	if m.in_bounds(t) and _sea_tiles.has(t):
		_deep.erase(t)
		m.set_terrain(t, MapData.Terrain.SHALLOW)


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
	# North: straight up a little, then on to the edge (the Legion's road; west of the river).
	var north: Array[Vector2i] = []
	for y in range(C.y - HY - 1, C.y - HY - 7, -1):
		north.append(Vector2i(C.x, y))
	_open(north)
	EditorTools.paint_road(m, north, false)
	var up := _lay([north[-1], Vector2i(C.x + rng.randi_range(-6, 4), 0)])
	_spawns.append(up[-1])
	# West to the edge.
	var west: Array[Vector2i] = []
	for x in range(C.x - HX - 1, -1, -1):
		west.append(Vector2i(x, C.y))
	_open(west)
	EditorTools.paint_road(m, west, false)
	_spawns.append(west[-1])
	# East: from the north-east corner round its mountains, over the river, to the north road.
	var bridge: Array[Vector2i] = []
	var bx := roundi(river_x(EAST_BRIDGE_Y))
	for x in range(bx + EAST_BRIDGE_REACH, bx - EAST_BRIDGE_REACH - 1, -1):
		bridge.append(Vector2i(x, EAST_BRIDGE_Y))
	_open(bridge)
	EditorTools.paint_road(m, bridge, false)
	var way: Array[Vector2i] = []
	way.assign(EAST_ROAD)
	way.append(bridge[0])
	var east := _lay(way)
	_spawns.append(east[0])
	var join := up[0]
	for t in up:
		if t.distance_to(bridge[-1]) < join.distance_to(bridge[-1]):
			join = t
	_lay([bridge[-1], join])
	# East: to the bank, up it, and over the one bridge onto the island.
	var ey := C.y + GATES[3].y
	var bank: Array[Vector2i] = []
	for x in range(C.x + HX + 1, BANK_X + 1):
		bank.append(Vector2i(x, ey))
	for y in range(ey - 1, ISLAND.y - 1, -1):
		bank.append(Vector2i(BANK_X, y))
	for x in range(BANK_X + 1, ISLAND.x):
		bank.append(Vector2i(x, ISLAND.y))
	_open(bank)
	EditorTools.paint_road(m, bank, false)
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
## for their direction; a ford running on from a bridge becomes part of it.
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
	# A crossing over deep water is a bridge from bank to bank (no ford at its ends).
	var under := {}
	for t: Vector2i in m.crossings.keys():
		under[t] = int(m.crossings[t][1])
	for t: Vector2i in under:
		if under[t] != MapData.Terrain.WATER:
			continue
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = t + d
			while under.has(q) and m.is_road(q):
				under[q] = MapData.Terrain.WATER
				q += d
	for t: Vector2i in under:
		MapTidy.set_crossing(m, t, int(under[t]))


## Open land along the roads, by the water (open banks), round the island and the quay.
func _clearings() -> void:
	for y in SIZE:
		for x in SIZE:
			var t := Vector2i(x, y)
			if not m.is_forest(t):
				continue
			var by_road := MapData.neighbors4(t).any(func(n: Vector2i) -> bool: return m.in_bounds(n) and m.is_road(n))
			var by_water := MapData.neighbors4(t).any(func(n: Vector2i) -> bool: return m.in_bounds(n) and m.is_water(n))
			if by_road or by_water or island_reach(t, LAND + ARM + Vector2(1.5, 1.5)) <= 1.0:
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
	var abbey := _treasure_at(ISLAND + Vector2i(1, 1), 2, "abbey", 3, {})
	_camp_at(abbey, ISLAND + Vector2i(1, -1), ["vampire", "vampire", "skeleton"])
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
	if island_reach(t, LAND + ARM + Vector2(2.0, 2.0)) <= 1.0 or absf(t.x - river_x(t.y)) <= 4.0:
		return false  # (round the island, or by the river)
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


## A footpath (trees felled) from `t` to the nearest road it can get to, so it can be walked to.
func _trail(t: Vector2i) -> void:
	if m.is_forest(t):
		m.set_terrain(t, MapTidy.ground(m, t))
	var roads: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			var r := Vector2i(x, y)
			if m.is_road(r) and not m.in_village(r) and not m.crossings.has(r):
				roads.append(r)
	roads.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(t) < b.distance_squared_to(t))
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
	for r in roads:  # (the nearest road it can get to: not across the river)
		var way := astar.get_id_path(t, r)
		if way.is_empty():
			continue
		for p in way:
			if m.is_forest(p):
				m.set_terrain(p, MapTidy.ground(m, p))
		return


## Two in the sea (west and east of the harbour), one up the river.
func _water_spawns() -> void:
	m.water_spawns = [Vector2i(14, SIZE - 4), Vector2i(SIZE - 12, SIZE - 4), Vector2i(roundi(river_x(8)), 8)]


# --- the finish --------------------------------------------------------------------------------

## Beaches: open land up to BEACH_DEPTH (more or less) from the sea, its
## trees felled: a beach by the water (the map's beaches are only ever there),
## sand behind it (steppe, drawn as sand); the sandbanks too (the river's banks stay green).
func _beaches() -> void:
	m.beaches.clear()
	var dist := {}
	var todo: Array[Vector2i] = []
	for t: Vector2i in _sea_tiles:
		dist[t] = 0
		todo.append(t)
	var i := 0
	while i < todo.size():
		var t := todo[i]
		i += 1
		var reach := BEACH_DEPTH + BEACH_RAGGED * _shore_noise.get_noise_1d(t.x * 1.7 + 40.0)
		if dist[t] >= roundi(reach):
			continue
		for n in MapData.neighbors4(t):
			if not m.in_bounds(n) or dist.has(n) or m.is_water(n) or m.is_mountain(n) or m.in_village(n):
				continue
			dist[n] = int(dist[t]) + 1
			todo.append(n)
			if m.is_road(n) or m.crossings.has(n):
				continue
			m.props.erase(n)
			m.decor.erase(n)  # (no cactus on a beach)
			if dist[n] == 1:
				m.beaches[n] = true
				if m.is_forest(n):
					m.set_terrain(n, MapTidy.ground(m, n))
			else:
				m.set_zone(n, "steppe")
				m.set_terrain(n, MapTidy.ground(m, n))


## The beacon's spot: the trees round it felled, a footpath to the nearest road.
func _beacon_way() -> void:
	var t := _quay + BEACON_OFFSET
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := t + Vector2i(dx, dy)
			if m.in_bounds(q) and m.is_forest(q):
				m.set_terrain(q, MapTidy.ground(m, q))
	_trail(t)
