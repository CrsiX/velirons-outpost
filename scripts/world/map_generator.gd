class_name MapGenerator
extends RefCounted
## Seeded level generation, in this order:
## 1. walled village in the centre (gate tiles are road so the dirt runs through),
## 2. winding roads with branches out to the map edge,
## 3. mountain ranges near the border, kept clear of roads and the village,
## 4. desert patches (capped share, never next to the village),
## 5. dense forest everywhere else, with a clear ring around the walls and one
##    guaranteed farm plot inside the starting view.

const TREE_ARTS: Array[String] = ["tree_pine_0", "tree_pine_1", "tree_pine_0", "tree_pine_1", "tree_oak", "tree_dead"]
const PEAK_ARTS: Array[String] = ["mountain_0", "mountain_1", "mountain_2"]


static func generate(seed_value: int) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var m := MapData.new(Config.MAP_SIZE)
	_layout_village(m)
	_carve_roads(m, rng)
	_collect_spawns(m)
	var road_dist := _terrain_distance(m, MapData.Terrain.ROAD)
	_raise_mountains(m, rng, road_dist)
	_lay_deserts(m, seed_value)
	_plant_forest(m, rng, seed_value, _terrain_distance(m, MapData.Terrain.DESERT))
	_clear_farm_plot(m, rng)
	return m


# --- village -------------------------------------------------------------------------

static func _layout_village(m: MapData) -> void:
	var o := Config.VILLAGE_ORIGIN
	m.village_rect = Rect2i(o, Vector2i(5, 5))
	for row in 5:
		for col in 5:
			var t := o + Vector2i(col, row)
			var kind: String = {"T": "wall_tower", "W": "wall", "G": "gate", "V": "hut"}[Config.VILLAGE_LAYOUT[row][col]]
			# Walls on the left/right edges run along the grid's y axis: mirror them.
			var flip := col == 0 or col == 4
			m.village_layout.append({"kind": kind, "tile": t, "flip": flip})
			if kind == "gate":
				m.gates.append(t)
				m.set_terrain(t, MapData.Terrain.ROAD)


static func _village_dist(t: Vector2i) -> float:
	return Vector2(t).distance_to(Vector2(Config.VILLAGE_CENTER))


static func _near_village(m: MapData, t: Vector2i) -> bool:
	return m.village_rect.grow(1).has_point(t)


# --- roads ----------------------------------------------------------------------------

static func _carve_roads(m: MapData, rng: RandomNumberGenerator) -> void:
	var mains: Array[Dictionary] = []
	for gate in m.gates:
		var dir := (gate - Config.VILLAGE_CENTER).sign()
		mains.append({"tiles": _walk(m, rng, gate + dir, dir, false), "dir": dir})
	# Branches split off and head for another edge, or merge into another road.
	var branches := rng.randi_range(5, 8)
	var attempts := 0
	while branches > 0 and attempts < 60:
		attempts += 1
		var main: Dictionary = mains[rng.randi() % mains.size()]
		var tiles: Array = main["tiles"]
		if tiles.size() < 14:
			continue
		var from: Vector2i = tiles[rng.randi_range(8, tiles.size() - 5)]
		var d: Vector2i = main["dir"]
		var perp := Vector2i(d.y, d.x) * (1 if rng.randf() < 0.5 else -1)
		var branch := _walk(m, rng, from + perp, perp, true)
		if branch.size() >= 4:
			mains.append({"tiles": branch, "dir": perp})
			branches -= 1


## Random walk alternating runs along `primary` with sideways runs: curvy roads.
## Stops at the map edge (or at another road when `merge`).
static func _walk(m: MapData, rng: RandomNumberGenerator, start: Vector2i, primary: Vector2i, merge: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p := start
	var side := Vector2i(primary.y, primary.x) * (1 if rng.randf() < 0.5 else -1)
	var run := rng.randi_range(2, 5)
	var lateral := false
	var guard := 0
	while guard < 600:
		guard += 1
		if not m.in_bounds(p):
			break
		if merge and out.size() >= 3 and m.is_road(p):
			break  # joined another road: an intersection
		if _near_village(m, p) and out.size() > 0:
			break
		m.set_terrain(p, MapData.Terrain.ROAD)
		out.append(p)
		if m.is_edge(p) and out.size() > 1:
			break
		run -= 1
		if run <= 0:
			lateral = not lateral and rng.randf() < 0.55
			if lateral:
				run = rng.randi_range(1, 5)
				if rng.randf() < 0.4:
					side = -side
			else:
				run = rng.randi_range(3, 8)
		var dir := side if lateral else primary
		var nxt := p + dir
		if lateral:
			var ahead := p + dir * 3
			if not m.in_bounds(ahead) or _near_village(m, nxt):
				side = -side
				dir = primary
				nxt = p + dir
				lateral = false
		if _near_village(m, nxt):
			dir = side
			nxt = p + dir
		p = nxt
	return out


static func _collect_spawns(m: MapData) -> void:
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.is_road(t) and m.is_edge(t):
				m.edge_spawns.append(t)


## Chebyshev distance of every tile to the nearest tile of `terrain`.
static func _terrain_distance(m: MapData, terrain: int) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(m.size * m.size)
	dist.fill(1 << 20)
	var queue: Array[Vector2i] = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.get_terrain(t) == terrain:
				dist[m.index(t)] = 0
				queue.append(t)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := t + Vector2i(dx, dy)
				if m.in_bounds(n) and dist[m.index(n)] > dist[m.index(t)] + 1:
					dist[m.index(n)] = dist[m.index(t)] + 1
					queue.append(n)
	return dist


# --- mountains ---------------------------------------------------------------------------

## Ranges start near a random edge and snake roughly parallel to it.
## They never touch roads (plus a margin) or the area around the village,
## so they shape the land without cutting goblin or villager routes.
static func _raise_mountains(m: MapData, rng: RandomNumberGenerator, road_dist: PackedInt32Array) -> void:
	var ranges := rng.randi_range(Config.MOUNTAIN_RANGES.x, Config.MOUNTAIN_RANGES.y)
	var band := Config.MOUNTAIN_BORDER_BAND
	for r in ranges:
		var edge := rng.randi() % 4
		var along := rng.randi_range(4, m.size - 5)
		var inset := rng.randi_range(1, band - 3)
		var p: Vector2
		var dir: Vector2
		match edge:
			0: p = Vector2(along, inset); dir = Vector2.RIGHT
			1: p = Vector2(along, m.size - 1 - inset); dir = Vector2.RIGHT
			2: p = Vector2(inset, along); dir = Vector2.DOWN
			_: p = Vector2(m.size - 1 - inset, along); dir = Vector2.DOWN
		if rng.randf() < 0.5:
			dir = -dir
		var length := rng.randi_range(12, 28)
		var heading := dir.angle()
		for i in length:
			var thickness := rng.randf_range(1.0, 2.5)
			_stamp_mountain(m, p, thickness, road_dist)
			heading += rng.randf_range(-0.45, 0.45)
			# Pull back towards the edge direction so ranges hug the border.
			heading = lerp_angle(heading, dir.angle(), 0.25)
			p += Vector2.from_angle(heading)
			if not Rect2(1, 1, m.size - 2, m.size - 2).has_point(p):
				break


static func _stamp_mountain(m: MapData, c: Vector2, radius: float, road_dist: PackedInt32Array) -> void:
	var r := int(ceil(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := Vector2i(c.round()) + Vector2i(dx, dy)
			if not m.in_bounds(t) or Vector2(t).distance_to(c) > radius:
				continue
			if road_dist[m.index(t)] <= Config.MOUNTAIN_ROAD_MARGIN or _village_dist(t) < Config.MOUNTAIN_MIN_VILLAGE_DIST:
				continue
			m.set_terrain(t, MapData.Terrain.MOUNTAIN)


# --- desert --------------------------------------------------------------------------------

## Low-frequency noise picks blobs of desert; the threshold is raised until the
## desert stays under its share of the map.
static func _lay_deserts(m: MapData, seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 101
	noise.frequency = 0.045
	var candidates: Array[Vector2] = []  # (noise, index)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.get_terrain(t) != MapData.Terrain.GRASS or _village_dist(t) < Config.DESERT_MIN_VILLAGE_DIST:
				continue
			var n := noise.get_noise_2dv(Vector2(t))
			if n > 0.2:
				candidates.append(Vector2(n, m.index(t)))
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
	var max_tiles := int(Config.DESERT_MAX_SHARE * m.size * m.size)
	for i in mini(candidates.size(), max_tiles):
		m.terrain[int(candidates[i].y)] = MapData.Terrain.DESERT


# --- forest --------------------------------------------------------------------------------

static func _plant_forest(m: MapData, rng: RandomNumberGenerator, seed_value: int, desert_dist: PackedInt32Array) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.is_mountain(t):
				m.props[t] = PEAK_ARTS[rng.randi() % PEAK_ARTS.size()]
				continue
			if m.get_terrain(t) != MapData.Terrain.GRASS or m.in_village(t):
				continue
			var ring := maxi(absi(t.x - Config.VILLAGE_CENTER.x), absi(t.y - Config.VILLAGE_CENTER.y))
			if ring <= Config.FOREST_CLEARING_RING:
				continue  # walkable ring around the walls
			if desert_dist[m.index(t)] <= Config.DESERT_FOREST_GAP and rng.randf() < Config.DESERT_FOREST_GAP_CHANCE:
				continue  # usually a strip of meadow between desert and forest
			# Mostly forest: only the lowest noise values become meadows.
			var threshold := -0.42
			for nb in MapData.neighbors4(t):
				if m.is_road(nb):
					threshold += 0.3  # glades along the roads leave room for towers
					break
			if ring <= Config.FOREST_CLEARING_RING + 3:
				threshold += 0.15  # a little more room right outside the clearing
			if noise.get_noise_2dv(Vector2(t)) > threshold or rng.randf() < 0.05:
				m.set_terrain(t, MapData.Terrain.FOREST)
				m.props[t] = TREE_ARTS[rng.randi() % TREE_ARTS.size()]


## Guarantees one 3x3 farm plot touching the clear ring, inside the starting view.
static func _clear_farm_plot(m: MapData, rng: RandomNumberGenerator) -> void:
	var c := Config.VILLAGE_CENTER
	var corners: Array[Vector2i] = [Vector2i(4, 4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-4, -4)]
	corners.shuffle()
	# Fallbacks one step further out, used only if roads cover every near corner.
	for off in [Vector2i(5, 5), Vector2i(-5, 5), Vector2i(5, -5), Vector2i(-5, -5)]:
		corners.append(off)
	for off in corners:
		var center := c + off
		var ok := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if m.is_road(center + Vector2i(dx, dy)):
					ok = false
		if not ok:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var t := center + Vector2i(dx, dy)
				m.set_terrain(t, MapData.Terrain.GRASS)
				m.props.erase(t)
		# Clear a diagonal walkway from the plot to the ring around the walls.
		var step := -off.sign()
		var p := center
		while maxi(absi(p.x - c.x), absi(p.y - c.y)) > Config.FOREST_CLEARING_RING:
			p += step
			for t in [p, p - Vector2i(step.x, 0)]:
				if not m.is_road(t) and not m.in_village(t):
					m.set_terrain(t, MapData.Terrain.GRASS)
					m.props.erase(t)
		m.farm_plot = center
		return
