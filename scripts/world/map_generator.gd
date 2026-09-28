class_name MapGenerator
extends RefCounted
## Seeded level generation, in this order:
## 1. walled village(s) (gate tiles are road so the dirt runs through):
##    single player one in the centre; co-op P villages spread over a bigger map
##    (Config.map_size), each with a "home edge" nearer to it than to any other,
## 2. roads: single player winding roads with branches out to the map edge;
##    co-op a home road from each village to its home edge, winding roads
##    linking every village to at least min(2, P - 1) others, and a road from
##    every gate that has none,
## 3. mountain ranges near the border, kept clear of roads and villages,
## 4. desert patches (capped share, never next to a village),
## 5. dense forest everywhere else, with a clear ring around every village and
##    one guaranteed farm plot per village.
## Only the RandomNumberGenerator seeded from `seed_value` is used, so a seed
## always gives the same map (the co-op host generates, clients receive it).

const TREE_ARTS: Array[String] = ["tree_pine_0", "tree_pine_1", "tree_pine_0", "tree_pine_1", "tree_oak", "tree_dead"]
const PEAK_ARTS: Array[String] = ["mountain_0", "mountain_1", "mountain_2"]


static func generate(seed_value: int, players: int = 1) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := clampi(players, 1, Config.MAX_PLAYERS)
	var m := MapData.new(Config.map_size(n))
	if n == 1:
		_add_village(m, Config.VILLAGE_CENTER)
		_carve_roads(m, rng)
		_collect_spawns(m)
		m.villages[0]["home_spawns"] = m.edge_spawns.duplicate()
	else:
		_place_villages(m, rng, n)
		_carve_coop_roads(m, rng, seed_value)
		_collect_spawns(m)
		_assign_home_spawns(m)
	var road_dist := _terrain_distance(m, MapData.Terrain.ROAD)
	_raise_mountains(m, rng, road_dist)
	_lay_deserts(m, seed_value)
	_plant_forest(m, rng, seed_value, _terrain_distance(m, MapData.Terrain.DESERT))
	for v in m.villages:
		_clear_farm_plot(m, rng, v)
	m.farm_plot = m.villages[0]["farm_plot"]
	return m


# --- villages -------------------------------------------------------------------------

## Lays out a 5x5 walled village around `center` (Config.VILLAGE_LAYOUT).
static func _add_village(m: MapData, center: Vector2i) -> void:
	var id := m.villages.size()
	var o := center - Vector2i(2, 2)
	var rect := Rect2i(o, Vector2i(5, 5))
	var v := {"center": center, "rect": rect, "gates": [] as Array[Vector2i], "home_spawns": [] as Array[Vector2i], "farm_plot": Vector2i(-1, -1)}
	m.villages.append(v)
	if id == 0:
		m.village_rect = rect
	for row in 5:
		for col in 5:
			var t := o + Vector2i(col, row)
			var kind: String = {"T": "wall_tower", "W": "wall", "G": "gate", "V": "hut"}[Config.VILLAGE_LAYOUT[row][col]]
			# Walls on the left/right edges run along the grid's y axis: mirror them.
			var flip := col == 0 or col == 4
			m.village_layout.append({"kind": kind, "tile": t, "flip": flip, "owner": id})
			if kind == "gate":
				m.gates.append(t)
				(v["gates"] as Array[Vector2i]).append(t)
				m.set_terrain(t, MapData.Terrain.ROAD)


## Distance to the nearest village centre.
static func _village_dist(m: MapData, t: Vector2i) -> float:
	var best := INF
	for v in m.villages:
		best = minf(best, Vector2(t).distance_to(Vector2(v["center"])))
	return best


## Chebyshev distance to the nearest village centre (for the clearing ring).
static func _village_ring(m: MapData, t: Vector2i) -> int:
	var best := 1 << 20
	for v in m.villages:
		var c: Vector2i = v["center"]
		best = mini(best, maxi(absi(t.x - c.x), absi(t.y - c.y)))
	return best


static func _near_village(m: MapData, t: Vector2i) -> bool:
	for v in m.villages:
		if (v["rect"] as Rect2i).grow(1).has_point(t):
			return true
	return false


# --- co-op: village placement ------------------------------------------------------------

## Best-candidate sampling: each new village takes the candidate farthest from
## those placed so far. A layout is kept only if villages are far enough apart
## and each has a stretch of map edge closer to it than to any other village
## (its home edge, where its own wave spawns).
static func _place_villages(m: MapData, rng: RandomNumberGenerator, n: int) -> void:
	var margin := Config.VILLAGE_EDGE_MARGIN
	var hi := m.size - 1 - margin
	var min_d := 0.8 * m.size / ceilf(sqrt(n))
	var chosen: Array[Vector2i] = []
	for attempt in 60:
		var centers: Array[Vector2i] = []
		for i in n:
			var best := Vector2i(-1, -1)
			var best_score := -1.0
			for k in 50:
				var c := Vector2i(rng.randi_range(margin, hi), rng.randi_range(margin, hi))
				var score := rng.randf()
				if not centers.is_empty():
					score = INF
					for o in centers:
						score = minf(score, Vector2(c).distance_to(Vector2(o)))
				if score > best_score:
					best_score = score
					best = c
			centers.append(best)
		chosen = centers
		if _layout_ok(m, centers, min_d * (1.0 - attempt * 0.005)):
			break
	for c in chosen:
		_add_village(m, c)


static func _layout_ok(m: MapData, centers: Array[Vector2i], min_d: float) -> bool:
	for i in centers.size():
		for j in range(i + 1, centers.size()):
			if Vector2(centers[i]).distance_to(Vector2(centers[j])) < min_d:
				return false
	var owned := PackedInt32Array()
	owned.resize(centers.size())
	for t in _border_tiles(m):
		owned[_nearest(centers, t)] += 1
	for c in owned:
		if c < 8:
			return false
	return true


static func _nearest(centers: Array[Vector2i], t: Vector2i) -> int:
	var best := 0
	var best_d := INF
	for i in centers.size():
		var d := Vector2(t).distance_squared_to(Vector2(centers[i]))
		if d < best_d:
			best_d = d
			best = i
	return best


static func _border_tiles(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in m.size:
		out.append(Vector2i(i, 0))
		out.append(Vector2i(i, m.size - 1))
		if i > 0 and i < m.size - 1:
			out.append(Vector2i(0, i))
			out.append(Vector2i(m.size - 1, i))
	return out


# --- co-op: roads ------------------------------------------------------------------------

## Roads are found by A* over a noisy cost map (meandering, not straight),
## 4-connected like enemy movement, around every village's walls. Tiles that
## already are road get cheap, so later roads tend to join earlier ones.
static func _carve_coop_roads(m: MapData, rng: RandomNumberGenerator, seed_value: int) -> void:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, m.size, m.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 707
	noise.frequency = 0.05
	var centers: Array[Vector2i] = []
	for v in m.villages:
		centers.append(v["center"])
	var owner := PackedInt32Array()
	owner.resize(m.size * m.size)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			owner[m.index(t)] = _nearest(centers, t)
			var n01 := noise.get_noise_2dv(Vector2(t)) * 0.5 + 0.5
			astar.set_point_weight_scale(t, 1.0 + 9.0 * pow(n01, 1.6) + rng.randf() * 0.6)
	for v in m.villages:
		for t in _rect_tiles((v["rect"] as Rect2i).grow(1)):
			if m.in_bounds(t):
				astar.set_point_solid(t, true)
	var used := {}  # gate -> true once a road leaves it
	# 1. Home roads: from the gate facing the home edge out to that edge,
	# staying on land nearer to this village than to any other, so its wave
	# comes straight at it and never along someone else's road.
	var border := _border_tiles(m)
	for i in m.villages.size():
		var v := m.villages[i]
		var home := Vector2i(-1, -1)
		var best_d := INF
		for t in border:
			if _nearest(centers, t) == i:
				var d := Vector2(t).distance_to(Vector2(v["center"]))
				if d < best_d:
					best_d = d
					home = t
		var g := _gate_towards(v, home, used)
		_road_in_region(m, astar, owner, i, _gate_exit(m, v, g), home)
		used[g] = true
	# 2. Links: each village to its nearest neighbours, then join any separate groups.
	var need := mini(2, m.villages.size() - 1)
	var links := {}
	for i in m.villages.size():
		var others := range(m.villages.size())
		others.erase(i)
		others.sort_custom(func(a: int, b: int) -> bool: return Vector2(centers[a]).distance_to(Vector2(centers[i])) < Vector2(centers[b]).distance_to(Vector2(centers[i])))
		for j in others.slice(0, need):
			links[Vector2i(mini(i, j), maxi(i, j))] = true
	_connect_groups(centers, links)
	var pairs: Array = links.keys()
	if m.villages.size() == 2:
		pairs.append(Vector2i(0, 1))  # two villages: two separate roads between them
	for pair in pairs:
		var a := m.villages[pair.x]
		var b := m.villages[pair.y]
		var ga := _gate_towards(a, b["center"], used)
		var gb := _gate_towards(b, a["center"], used)
		_road(m, astar, _gate_exit(m, a, ga), _gate_exit(m, b, gb))
		used[ga] = true
		used[gb] = true
		m.village_links.append(pair)
	# 3. A ring road just outside the walls joins all four gates, so roads run on
	#    past a village (enemies whose target fell walk on to the next one).
	#    A gate still without a road also goes out to the map edge if that edge
	#    is this village's own; otherwise the ring is what it connects to.
	for i in m.villages.size():
		var v := m.villages[i]
		var ring := (v["rect"] as Rect2i).grow(1)
		for t in _rect_tiles(ring):
			if not (v["rect"] as Rect2i).has_point(t):
				m.set_terrain(t, MapData.Terrain.ROAD)
		for g in v["gates"]:
			if used.has(g):
				continue
			var gate: Vector2i = g
			var dir: Vector2i = (gate - (v["center"] as Vector2i)).sign()
			var to: Vector2i = gate
			while m.in_bounds(to + dir):
				to += dir
			if owner[m.index(to)] == i:
				_road_in_region(m, astar, owner, i, _gate_exit(m, v, g), to)
			used[g] = true


## Marks the tile just outside gate `g` as road and returns the first tile past
## the walls' ring, where the road proper starts.
static func _gate_exit(m: MapData, v: Dictionary, g: Vector2i) -> Vector2i:
	var dir := (g - (v["center"] as Vector2i)).sign()
	m.set_terrain(g + dir, MapData.Terrain.ROAD)
	return g + dir * 2


## The village's gate pointing most towards `target`, preferring unused gates.
static func _gate_towards(v: Dictionary, target: Vector2i, used: Dictionary) -> Vector2i:
	var to := (Vector2(target) - Vector2(v["center"])).normalized()
	var best: Vector2i = v["gates"][0]
	var best_s := -INF
	for g in v["gates"]:
		var s := Vector2(g - (v["center"] as Vector2i)).normalized().dot(to) - (1.5 if used.has(g) else 0.0)
		if s > best_s:
			best_s = s
			best = g
	return best


## A road that stays on land nearer to village `i` than to any other.
static func _road_in_region(m: MapData, astar: AStarGrid2D, owner: PackedInt32Array, i: int, from: Vector2i, to: Vector2i) -> void:
	var foreign: Array[Vector2i] = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if owner[m.index(t)] != i and not astar.is_point_solid(t):
				astar.set_point_solid(t, true)
				foreign.append(t)
	_road(m, astar, from, to)
	for t in foreign:
		astar.set_point_solid(t, false)


static func _road(m: MapData, astar: AStarGrid2D, from: Vector2i, to: Vector2i) -> void:
	if not m.in_bounds(from) or not m.in_bounds(to):
		return
	for t in astar.get_id_path(from, to):
		m.set_terrain(t, MapData.Terrain.ROAD)
		astar.set_point_weight_scale(t, 0.35)


## Adds the shortest links between separate groups until all villages connect.
static func _connect_groups(centers: Array[Vector2i], links: Dictionary) -> void:
	var n := centers.size()
	while true:
		var group := range(n)
		var changed := true
		while changed:
			changed = false
			for l in links:
				var ga: int = group[l.x]
				var gb: int = group[l.y]
				if ga != gb:
					var lo := mini(ga, gb)
					for k in n:
						if group[k] == ga or group[k] == gb:
							group[k] = lo
					changed = true
		var best := Vector2i(-1, -1)
		var best_d := INF
		for i in n:
			for j in range(i + 1, n):
				if group[i] != group[j]:
					var d := Vector2(centers[i]).distance_to(Vector2(centers[j]))
					if d < best_d:
						best_d = d
						best = Vector2i(i, j)
		if best.x < 0:
			return
		links[best] = true


static func _rect_tiles(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


## Every edge road tile spawns for the village nearest to it.
static func _assign_home_spawns(m: MapData) -> void:
	var centers: Array[Vector2i] = []
	for v in m.villages:
		centers.append(v["center"])
	for t in m.edge_spawns:
		(m.villages[_nearest(centers, t)]["home_spawns"] as Array[Vector2i]).append(t)


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
## so they shape the land without cutting enemy or villager routes.
static func _raise_mountains(m: MapData, rng: RandomNumberGenerator, road_dist: PackedInt32Array) -> void:
	var ranges := rng.randi_range(Config.MOUNTAIN_RANGES.x, Config.MOUNTAIN_RANGES.y)
	if m.size > Config.MAP_SIZE:  # bigger co-op maps get more ranges (by border length)
		ranges = roundi(ranges * float(m.size) / Config.MAP_SIZE)
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
			if road_dist[m.index(t)] <= Config.MOUNTAIN_ROAD_MARGIN or _village_dist(m, t) < Config.MOUNTAIN_MIN_VILLAGE_DIST:
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
			if m.get_terrain(t) != MapData.Terrain.GRASS or _village_dist(m, t) < Config.DESERT_MIN_VILLAGE_DIST:
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
			var ring := _village_ring(m, t)
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


## Guarantees one 3x3 farm plot touching the village's clear ring, inside its
## starting view; stored as the village's "farm_plot".
static func _clear_farm_plot(m: MapData, rng: RandomNumberGenerator, v: Dictionary) -> void:
	var c: Vector2i = v["center"]
	var corners: Array[Vector2i] = [Vector2i(4, 4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-4, -4)]
	# Seeded shuffle (Array.shuffle() would use the global RNG, so the same map
	# seed could give a different farm plot).
	for i in range(corners.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := corners[i]
		corners[i] = corners[j]
		corners[j] = tmp
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
		v["farm_plot"] = center
		return
