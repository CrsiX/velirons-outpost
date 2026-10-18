class_name GenWater
extends RefCounted
## Stage 3 (docs/world-design.md §6): sea along one or two neighbouring map
## edges (Coast type), lakes in the lowest hollows, rivers running downhill
## into a lake, the sea or off the map. Deep water in the middle, shallow
## water at the rims. Every slice keeps some land edge for its spawns.
## After the villages (§9.8, docs/aquatic-design.md): water near them for the
## water monsters (near_villages: an inlet from the sea on Coast maps, else
## maybe a lagoon), a landing road to it (landings), and the water spawns.


static func place(c: GenContext) -> void:
	_coast(c)
	_lakes(c)
	_rivers(c)


# --- coast --------------------------------------------------------------------------------

static func _coast(c: GenContext) -> void:
	var m := c.m
	var edges_range: Array = c.type.get("coast_edges", [0, 0])
	var k := c.rng.randi_range(int(edges_range[0]), int(edges_range[1]))
	if c.players >= 5:
		k = mini(k, 1)  # narrow slices: keep more land edge
	if k <= 0:
		return
	var e0 := c.rng.randi() % 4
	var edges: Array[int] = [e0]
	if k > 1:
		edges.append((e0 + 1) % 4)
	var share := c.rng.randf_range(Config.COAST_SHARE.x, Config.COAST_SHARE.y)
	var scored: Array[Vector2] = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var d := INF
			for e in edges:
				d = minf(d, _edge_dist(m, t, e))
			var s := d / m.size + (c.h(t) - 0.5) * 0.3 + c.detail[c.i(t)] * 0.04
			scored.append(Vector2(s, c.i(t)))
	scored.sort()
	var candidate := {}
	for r in int(share * scored.size()):
		candidate[int(scored[r].y)] = true
	# Only what's connected to the chosen edges becomes sea.
	var queue: Array[Vector2i] = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if candidate.has(c.i(t)) and edges.any(func(e: int) -> bool: return _edge_dist(m, t, e) == 0):
				queue.append(t)
				c.sea[t] = true
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for nb in MapData.neighbors4(t):
			if m.in_bounds(nb) and candidate.has(c.i(nb)) and not c.sea.has(nb):
				c.sea[nb] = true
				queue.append(nb)
	for t: Vector2i in c.sea:
		m.set_terrain(t, MapData.Terrain.WATER)
	_keep_land_edges(c)
	for t: Vector2i in c.sea:
		if m.get_terrain(t) != MapData.Terrain.WATER:
			continue
		for nb in MapData.neighbors4(t):
			if m.in_bounds(nb) and not c.sea.has(nb):
				m.set_terrain(t, MapData.Terrain.SHALLOW)
				break
	for t: Vector2i in c.sea:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nb := t + Vector2i(dx, dy)
				if m.in_bounds(nb) and not c.sea.has(nb):
					c.beaches[nb] = true


static func _edge_dist(m: MapData, t: Vector2i, e: int) -> float:
	match e:
		0: return float(t.y)
		1: return float(m.size - 1 - t.x)
		2: return float(m.size - 1 - t.y)
	return float(t.x)


## A slice whose whole stretch of map edge went under water gets a land
## strip from the middle of its stretch inwards.
static func _keep_land_edges(c: GenContext) -> void:
	var m := c.m
	for s in c.players:
		var land := 0
		var stretch: Array[Vector2i] = []
		for t in _edge_tiles(m):
			if m.slice_of[c.i(t)] == s:
				stretch.append(t)
				if not c.sea.has(t):
					land += 1
		if land >= 6 or stretch.is_empty():
			continue
		var mid_t: Vector2i = stretch[stretch.size() / 2]
		var target := Vector2(c.m.slices[s]["center"])
		var p := Vector2(mid_t)
		var dir := (target - p).normalized()
		var dry := 0
		for step in m.size:
			var any_sea := false
			for off in [Vector2(0, 0), Vector2(-dir.y, dir.x), Vector2(dir.y, -dir.x), Vector2(-dir.y, dir.x) * 2.0, Vector2(dir.y, -dir.x) * 2.0]:
				var t := Vector2i((p + off).round())
				if c.sea.has(t):
					c.sea.erase(t)
					m.set_terrain(t, MapData.Terrain.GRASS)
					any_sea = true
			dry = 0 if any_sea else dry + 1
			if dry >= 3:
				break
			p += dir


static func _edge_tiles(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in m.size:
		out.append(Vector2i(k, 0))
	for k in range(1, m.size):
		out.append(Vector2i(m.size - 1, k))
	for k in range(m.size - 2, -1, -1):
		out.append(Vector2i(k, m.size - 1))
	for k in range(m.size - 2, 0, -1):
		out.append(Vector2i(0, k))
	return out


# --- lakes ---------------------------------------------------------------------------------

static func _lakes(c: GenContext) -> void:
	var m := c.m
	var area_scale := float(m.size * m.size) / (75.0 * 75.0)
	var n := c.count_in(Config.LAKE_COUNT, area_scale * float(c.type.get("lakes", 1.0)))
	var keep_off := Config.LAKE_VILLAGE_DIST + Config.VILLAGE_CENTER_RADIUS + 3.0
	for lake in n:
		var best := Vector2i(-1, -1)
		var best_h := INF
		for k in 60:
			var t := Vector2i(c.rng.randi_range(4, m.size - 5), c.rng.randi_range(4, m.size - 5))
			if not c.is_land(t) or c.near_slice_centre(t, keep_off) or _water_within(c, t, 8):
				continue
			if c.h(t) < best_h:
				best_h = c.h(t)
				best = t
		if best.x < 0:
			continue
		var target := c.rng.randi_range(Config.LAKE_SIZE.x, Config.LAKE_SIZE.y)
		var tiles := {best: true}
		var frontier: Array[Vector2i] = [best]
		while tiles.size() < target and not frontier.is_empty():
			# Grow into the lowest neighbouring tile (a little noise for ragged shores).
			var pick_i := 0
			var pick_s := INF
			for fi in frontier.size():
				var f := frontier[fi]
				var s := c.h(f) + c.detail[c.i(f)] * 0.08
				if s < pick_s:
					pick_s = s
					pick_i = fi
			var t: Vector2i = frontier[pick_i]
			frontier.remove_at(pick_i)
			tiles[t] = true
			for nb in MapData.neighbors4(t):
				if not tiles.has(nb) and not frontier.has(nb) and c.is_land(nb) and nb.x > 1 and nb.y > 1 and nb.x < m.size - 2 and nb.y < m.size - 2 and not c.near_slice_centre(nb, keep_off - 2.0):
					frontier.append(nb)
		for t: Vector2i in tiles:
			m.set_terrain(t, MapData.Terrain.WATER)
		for t: Vector2i in tiles:
			for nb in MapData.neighbors4(t):
				if not tiles.has(nb):
					m.set_terrain(t, MapData.Terrain.SHALLOW)
					break


static func _water_within(c: GenContext, t: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if c.m.is_water(t + Vector2i(dx, dy)):
				return true
	return false


# --- rivers --------------------------------------------------------------------------------

static func _rivers(c: GenContext) -> void:
	var m := c.m
	var n := c.count_in(Config.RIVER_COUNT, float(c.type.get("rivers", 1.0)) * c.length_scale)
	if n <= 0:
		return
	for r in n:
		var src := Vector2i(-1, -1)
		for k in 80:
			var t := Vector2i(c.rng.randi_range(3, m.size - 4), c.rng.randi_range(3, m.size - 4))
			if c.is_land(t) and c.h(t) > 0.8 and not c.near_slice_centre(t, 16.0) and not _water_within(c, t, 6):
				src = t
				break
		if src.x < 0:
			continue
		route_river(c, src, false)


## A river from `src` downhill to water or the map edge (lava: the nearest;
## water: one of the near ones), A* over the height field, kept off the slice
## centres (where villages go); water winds (Config.RIVER_MEANDER).
static func route_river(c: GenContext, src: Vector2i, lava: bool, max_len: int = 1 << 20) -> void:
	var m := c.m
	var goal := Vector2i(-1, -1)
	var best_d := INF
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var ok := m.is_water(t) and not c.rivers.has(t) if not lava else false
			if not ok and (x == 0 or y == 0 or x == m.size - 1 or y == m.size - 1):
				ok = true
			if ok:
				var d := Vector2(t).distance_to(Vector2(src))
				if d < best_d:
					best_d = d
					goal = t
	if goal.x < 0:
		return
	# Water: not always the nearest goal (Config.RIVER_GOAL_SLACK), so it needn't run straight.
	if not lava and Config.RIVER_GOAL_SLACK > 1.0:
		var pick := RandomNumberGenerator.new()
		pick.seed = hash([c.seed_value, src, "goal"])
		var cands: Array[Vector2i] = []
		for y in m.size:
			for x in m.size:
				var t := Vector2i(x, y)
				var ok := (m.is_water(t) and not c.rivers.has(t)) or x == 0 or y == 0 or x == m.size - 1 or y == m.size - 1
				if ok and Vector2(t).distance_to(Vector2(src)) <= best_d * Config.RIVER_GOAL_SLACK:
					cands.append(t)
		goal = cands[pick.randi() % cands.size()]
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, m.size, m.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	# Water winds (Config.RIVER_MEANDER); its own noise and random numbers,
	# so the rest of the map's seeded rolls stay as they were.
	var meander := FastNoiseLite.new()
	meander.seed = c.seed_value * 31 + 4241
	meander.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	meander.frequency = Config.RIVER_MEANDER_FREQ
	meander.fractal_octaves = 1
	var jitter := RandomNumberGenerator.new()
	jitter.seed = hash([c.seed_value, src])
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var w := 1.0 + 7.0 * clampf(c.h(t), 0.0, 1.2) + (c.detail[c.i(t)] + 1.0) * 0.8
			if not lava:
				w += Config.RIVER_MEANDER * absf(meander.get_noise_2d(x, y)) + Config.RIVER_JITTER * jitter.randf()
			if c.near_slice_centre(t, Config.VILLAGE_CENTER_RADIUS - 2.0):
				w += 40.0
			if m.is_mountain(t):
				w += 12.0
			astar.set_point_weight_scale(t, w)
	var path := astar.get_id_path(src, goal)
	var steps := 0
	for t in path:
		if m.is_water(t) and not c.rivers.has(t):
			break  # reached a lake or the sea
		if m.is_mountain(t) or steps >= max_len:
			if lava:
				break
			continue
		m.set_terrain(t, MapData.Terrain.LAVA if lava else MapData.Terrain.WATER)
		m.props.erase(t)
		c.rivers[t] = true
		steps += 1
		if lava:
			c.ash[t] = true
	if lava:
		return
	# Shallow banks here and there (the river is 1-2 tiles wide).
	for t: Vector2i in c.rivers:
		if m.get_terrain(t) != MapData.Terrain.WATER:
			continue
		for nb in MapData.neighbors4(t):
			if c.is_land(nb) and not c.rivers.has(nb) and c.rng.randf() < 0.3:
				m.set_terrain(nb, MapData.Terrain.SHALLOW)


# --- water for the water monsters (docs/world-design.md §9.8) -------------------------------

## After the villages: on Coast maps every village gets an inlet from the
## sea; on the other map types a village gets a lagoon with the type's
## "lagoon" chance. Their own random numbers, so the rest of a map's seeded
## rolls stay as they were.
static func near_villages(c: GenContext) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.seed_value, "aqua"])
	for vi in c.m.villages.size():
		if not c.sea.is_empty():
			_inlet(c, vi)
		elif rng.randf() < float(c.type.get("lagoon", 0.0)):
			_lagoon(c, vi, rng)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Can water go on `t` (for village `vi`'s inlet or lagoon, keeping `keep`
## Chebyshev steps from its centre)? Not on mountains, lava or by a crater,
## not too near any village, nor on the map's outer ring.
static func _water_ok(c: GenContext, t: Vector2i, vi: int, keep: int) -> bool:
	var m := c.m
	if not m.in_bounds(t) or t.x < 1 or t.y < 1 or t.x > m.size - 2 or t.y > m.size - 2:
		return false
	var v := m.get_terrain(t)
	if v == MapData.Terrain.MOUNTAIN or v == MapData.Terrain.LAVA or m.near_crater(t):
		return false
	for i in m.villages.size():
		var d := _cheb(t, m.villages[i]["center"])
		if d < (keep if i == vi else keep + 4):
			return false
	return true


## An inlet: the shortest channel from the sea's deep water to a tip
## COAST_INLET_DIST from village `vi`'s walls, COAST_INLET_WIDTH wide (a deep
## core, a shallow rim), dead-ending there.
static func _inlet(c: GenContext, vi: int) -> void:
	var m := c.m
	var centre: Vector2i = m.villages[vi]["center"]
	var half := Config.COAST_INLET_WIDTH / 2
	var tip_d := 2 + int(Config.COAST_INLET_DIST) + half  # (the rim comes within COAST_INLET_DIST of the walls)
	for t: Vector2i in c.sea:
		if m.get_terrain(t) == MapData.Terrain.WATER and _cheb(t, centre) <= tip_d + 1:
			c.aqua_sites.append({"village": vi, "tip": t})
			return  # (the sea is close enough already)
	# The sea's deep water nearest the village, and the tip on the ring
	# tip_d round it nearest to that.
	var sea_t := Vector2i(-1, -1)
	var sea_d := INF
	for t: Vector2i in c.sea:
		var d := Vector2(t).distance_squared_to(Vector2(centre))
		if m.get_terrain(t) == MapData.Terrain.WATER and d < sea_d:
			sea_d = d
			sea_t = t
	var tip := Vector2i(-1, -1)
	var tip_best := INF
	for k in range(-tip_d, tip_d + 1):
		for t in [centre + Vector2i(k, -tip_d), centre + Vector2i(k, tip_d), centre + Vector2i(-tip_d, k), centre + Vector2i(tip_d, k)]:
			var d := Vector2(t).distance_squared_to(Vector2(sea_t))
			if d < tip_best and _water_ok(c, t, vi, tip_d) and c.is_land(t):
				tip_best = d
				tip = t
	if sea_t.x < 0 or tip.x < 0:
		c.warn("village %d gets no inlet from the sea" % vi)
		return
	# A winding channel from the tip to the sea (A* over a noisy cost).
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, m.size, m.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	var noise := FastNoiseLite.new()
	noise.seed = c.seed_value * 37 + vi
	noise.frequency = 0.08
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if c.sea.has(t):
				astar.set_point_weight_scale(t, 0.5)
			elif not _water_ok(c, t, vi, tip_d):
				astar.set_point_solid(t, true)
			else:
				astar.set_point_weight_scale(t, 1.0 + 6.0 * absf(noise.get_noise_2d(x, y)) + 3.0 * clampf(c.h(t), 0.0, 1.0))
	var route := astar.get_id_path(tip, sea_t)
	if route.is_empty() or route.size() > int(m.size * 0.7):
		c.warn("village %d gets no inlet from the sea" % vi)
		return
	var path: Array[Vector2i] = []
	for t in route:
		if c.sea.has(t):
			break
		path.append(t)
	_carve_channel(c, path, half, vi)
	c.aqua_sites.append({"village": vi, "tip": tip})


## Water along `path`: deep within `half` - 1 of it, shallow at `half`.
static func _carve_channel(c: GenContext, path: Array[Vector2i], half: int, vi: int) -> void:
	var m := c.m
	var deep := {}
	var rim := {}
	for t in path:
		for dy in range(-half, half + 1):
			for dx in range(-half, half + 1):
				var q := t + Vector2i(dx, dy)
				if not _water_ok(c, q, vi, 2 + int(Config.COAST_INLET_DIST)):
					continue
				if maxi(absi(dx), absi(dy)) < half:
					deep[q] = true
				else:
					rim[q] = true
	for q: Vector2i in rim:
		if not deep.has(q) and c.is_land(q):
			_make_water(c, q, MapData.Terrain.SHALLOW)
	for q: Vector2i in deep:
		_make_water(c, q, MapData.Terrain.WATER)


static func _make_water(c: GenContext, t: Vector2i, terrain: int) -> void:
	var m := c.m
	m.set_terrain(t, terrain)
	m.props.erase(t)
	m.decor.erase(t)
	c.rivers.erase(t)
	c.sea[t] = true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nb := t + Vector2i(dx, dy)
			if m.in_bounds(nb):
				c.beaches[nb] = true


## A lagoon: a lake of LAGOON_SIZE tiles on the side of village `vi` with the
## most open land, its shore LAGOON_DIST from the walls, a deep core at least
## LAGOON_MIN_WIDTH wide and a shallow rim.
static func _lagoon(c: GenContext, vi: int, rng: RandomNumberGenerator) -> void:
	var m := c.m
	var centre: Vector2i = m.villages[vi]["center"]
	var size := rng.randi_range(Config.LAGOON_SIZE.x, Config.LAGOON_SIZE.y)
	var r := sqrt(size / PI)
	var keep := 2 + int(Config.LAGOON_DIST)
	var best := Vector2i(-1, -1)
	var best_s := -1
	for k in 16:
		var a := TAU * k / 16.0 + rng.randf() * 0.2
		var mid := Vector2i((Vector2(centre) + Vector2.from_angle(a) * (keep + r + 1.0)).round())
		var open := 0
		for dy in range(-ceili(r), ceili(r) + 1):
			for dx in range(-ceili(r), ceili(r) + 1):
				var t := mid + Vector2i(dx, dy)
				if Vector2(dx, dy).length() <= r and _water_ok(c, t, vi, keep) and c.is_land(t):
					open += 1
		if open > best_s:
			best_s = open
			best = mid
	if best.x < 0 or best_s < size * 0.6:
		return
	var noise := FastNoiseLite.new()
	noise.seed = c.seed_value * 13 + vi
	noise.frequency = 0.25
	var tiles := {}
	var ri := ceili(r) + 2
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var t := best + Vector2i(dx, dy)
			if Vector2(dx, dy).length() <= r + 1.2 * noise.get_noise_2d(t.x, t.y) and _water_ok(c, t, vi, keep):
				tiles[t] = true
	var tip := Vector2i(-1, -1)
	var tip_d := INF
	for t: Vector2i in tiles:
		var edge := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not tiles.has(t + Vector2i(dx, dy)):
					edge = true
		_make_water(c, t, MapData.Terrain.SHALLOW if edge else MapData.Terrain.WATER)
		if not edge and Vector2(t).distance_to(Vector2(centre)) < tip_d:
			tip_d = Vector2(t).distance_to(Vector2(centre))
			tip = t
	if tip.x >= 0:
		c.aqua_sites.append({"village": vi, "tip": tip})


## After the roads: a short road from the shore nearest each inlet's or
## lagoon's tip to the network, so crabs and sirens can climb out there.
static func landings(c: GenContext) -> void:
	if c.aqua_sites.is_empty():
		return
	var m := c.m
	var router := GenRoads.router(c)
	for site in c.aqua_sites:
		var tip: Vector2i = site["tip"]
		# The land tile next to this water nearest the tip.
		var shore := Vector2i(-1, -1)
		var shore_d := INF
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var t := tip + Vector2i(dx, dy)
				if not c.is_land(t) or m.in_village(t):
					continue
				var wet := false
				for nb in MapData.neighbors4(t):
					wet = wet or m.is_water(nb)
				if not wet:
					continue
				var d := Vector2(t).distance_to(Vector2(tip))
				if d < shore_d:
					shore_d = d
					shore = t
		if shore.x < 0:
			continue
		var touches := m.is_road(shore)
		for nb in MapData.neighbors4(shore):
			touches = touches or m.is_road(nb)
		if not touches:
			router.spur_from(shore)


## The water monsters' spawns: WATER_SPAWNS deep tiles in every body of water
## some water monster fits that comes near a village: at the map's edge if it
## reaches it (the open sea), else as far out in the open water as can be,
## and away from the shore (AQUA spawn_shore) where possible.
static func water_spawns(c: GenContext) -> void:
	var m := c.m
	m.water_spawns.clear()
	var lab := Pathing.label_water(m)
	var bodies: Array = lab["bodies"]
	var near := float(Config.AQUA["threat_radius"]) + 6.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([c.seed_value, "water_spawns"])
	var land_dist := c.distance_to(func(t: Vector2i) -> bool: return not m.is_deep(t), true)
	for b in bodies.size():
		var body: Dictionary = bodies[b]
		if Pathing.kinds_fitting(body).is_empty():
			continue
		var close := false
		for t: Vector2i in body["tiles"]:
			for v in m.villages:
				if Vector2(t).distance_to(Vector2(v["center"])) <= near:
					close = true
					break
			if close:
				break
		if not close:
			continue
		var n := rng.randi_range(Config.WATER_SPAWNS.x, Config.WATER_SPAWNS.y)
		var picked: Array[Vector2i] = []
		for k in n:
			var best := Vector2i(-1, -1)
			var best_s := -INF
			for t: Vector2i in body["tiles"]:
				var s := float(land_dist[m.index(t)]) + (20.0 if m.is_edge(t) else 0.0) + rng.randf() * 0.5
				var far_ok := true
				for v in m.villages:
					if Vector2(t).distance_to(Vector2(v["center"])) < float(Config.AQUA["spawn_shore"]) + 2.0:
						far_ok = false
				if not far_ok:
					s -= 50.0
				for p in picked:
					if Vector2(t).distance_to(Vector2(p)) < 10.0:
						s -= 40.0
				if s > best_s:
					best_s = s
					best = t
			if best.x >= 0 and not picked.has(best):
				picked.append(best)
		m.water_spawns.append_array(picked)
	m.water_spawns.sort_custom(MapData.row_order)
