class_name GenWater
extends RefCounted
## Stage 3 (docs/world-design.md §6): sea along one or two neighbouring map
## edges (Coast type), lakes in the lowest hollows, rivers running downhill
## into a lake, the sea or off the map. Deep water in the middle, shallow
## water at the rims. Every slice keeps some land edge for its spawns.


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
	var n := c.count_in(Config.RIVER_COUNT, float(c.type.get("rivers", 1.0)))
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


## A river from `src` downhill to the nearest water or map edge: A* over the
## height field, kept off the slice centres (where villages go).
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
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, m.size, m.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var w := 1.0 + 7.0 * clampf(c.h(t), 0.0, 1.2) + (c.detail[c.i(t)] + 1.0) * 0.8
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
