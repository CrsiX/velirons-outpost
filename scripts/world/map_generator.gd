class_name MapGenerator
extends RefCounted
## Seeded level generation: walled village in the centre, winding roads with
## branches out to the map edge, and a dark forest that avoids the village.

const TREE_ARTS: Array[String] = ["tree_pine_0", "tree_pine_1", "tree_pine_0", "tree_oak", "tree_dead"]


static func generate(seed_value: int) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var m := MapData.new(Config.MAP_SIZE)
	_layout_village(m)
	_carve_roads(m, rng)
	_collect_spawns(m)
	_plant_forest(m, rng, seed_value)
	return m


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


static func _outward(m: MapData, gate: Vector2i) -> Vector2i:
	var c := Config.VILLAGE_CENTER
	var d := gate - c
	return Vector2i(signi(d.x), signi(d.y))


## Too close to the village for a road (except the start of a gate road).
static func _near_village(m: MapData, t: Vector2i) -> bool:
	return m.village_rect.grow(1).has_point(t)


static func _carve_roads(m: MapData, rng: RandomNumberGenerator) -> void:
	var mains: Array[Dictionary] = []
	for gate in m.gates:
		var dir := _outward(m, gate)
		var start := gate + dir
		var road := _walk(m, rng, start, dir, false)
		mains.append({"tiles": road, "dir": dir})
	# Branches: split off an existing road and head for another edge, or merge.
	var branches := rng.randi_range(3, 5)
	var attempts := 0
	while branches > 0 and attempts < 40:
		attempts += 1
		var main: Dictionary = mains[rng.randi() % mains.size()]
		var tiles: Array = main["tiles"]
		if tiles.size() < 12:
			continue
		var from: Vector2i = tiles[rng.randi_range(6, tiles.size() - 5)]
		var d: Vector2i = main["dir"]
		var perp := Vector2i(d.y, d.x) * (1 if rng.randf() < 0.5 else -1)
		var branch := _walk(m, rng, from + perp, perp, true)
		if branch.size() >= 4:
			mains.append({"tiles": branch, "dir": perp})
			branches -= 1


## Random walk that alternates runs along `primary` with sideways runs, giving
## curvy roads. Stops at the map edge (or at another road when `merge`).
static func _walk(m: MapData, rng: RandomNumberGenerator, start: Vector2i, primary: Vector2i, merge: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p := start
	var side := Vector2i(primary.y, primary.x) * (1 if rng.randf() < 0.5 else -1)
	var run := rng.randi_range(2, 5)
	var lateral := false
	var guard := 0
	while guard < 400:
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
				run = rng.randi_range(1, 4)
				if rng.randf() < 0.4:
					side = -side
			else:
				run = rng.randi_range(3, 7)
		var dir := side if lateral else primary
		var nxt := p + dir
		# Keep sideways runs away from the side edges and the village.
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


static func _plant_forest(m: MapData, rng: RandomNumberGenerator, seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.09
	var c := Vector2(Config.VILLAGE_CENTER)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.get_terrain(t) != MapData.Terrain.GRASS or m.in_village(t):
				continue
			var dist := Vector2(t).distance_to(c)
			if dist < 7.5:
				continue  # keep the starting clearing open for towers and farms
			var n := noise.get_noise_2dv(Vector2(t))
			var threshold := 0.18
			for nb in MapData.neighbors4(t):
				if m.is_road(nb):
					threshold += 0.25  # thinner next to roads
					break
			threshold -= clampf((dist - 7.5) * 0.02, 0.0, 0.2)  # denser further out
			if n > threshold or (dist > 10.0 and rng.randf() < 0.03):
				m.set_terrain(t, MapData.Terrain.FOREST)
				m.trees[t] = TREE_ARTS[rng.randi() % TREE_ARTS.size()]
