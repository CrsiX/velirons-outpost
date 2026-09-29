class_name Pathing
extends RefCounted
## Navigation for both sides.
## Ground units (civilians, soldiers): AStarGrid2D; forest, mountains, deep
## water, lava and solid buildings block; shallow water and swamp cost more. Enemies: flow fields over road tiles: one to the nearest
## gate of any village, and one per village to that village's own gates (each
## village's wave goes for that village; see Waves).

const UNREACHABLE := 1 << 30

var map: MapData
var astar := AStarGrid2D.new()
var enemy_dist := PackedInt32Array()
## Per village id: road steps to that village's nearest gate.
var village_fields: Array[PackedInt32Array] = []


func _init(p_map: MapData) -> void:
	map = p_map
	astar.region = Rect2i(0, 0, map.size, map.size)
	astar.cell_size = Vector2.ONE
	astar.offset = Vector2.ZERO
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if not map.is_passable(t):
				astar.set_point_solid(t, true)
			else:
				var f := map.walk_factor(t)
				if f < 1.0:
					astar.set_point_weight_scale(t, 1.0 / f)  # (slow ground: go round if it's not far)
	build_enemy_field()


## Buildings toggle solidity; impassable terrain always stays solid.
func set_solid(t: Vector2i, solid: bool) -> void:
	astar.set_point_solid(t, solid or not map.is_passable(t))


func is_walkable(t: Vector2i) -> bool:
	return map.in_bounds(t) and not astar.is_point_solid(t)


func nearest_walkable(t: Vector2i) -> Vector2i:
	if is_walkable(t):
		return t
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := t + Vector2i(dx, dy)
				if is_walkable(c):
					return c
	return t


## Grid-space waypoints from one tile to another (empty if unreachable).
func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	from = nearest_walkable(from)
	if not map.in_bounds(to) or not is_walkable(to):
		return PackedVector2Array()
	return astar.get_point_path(from, to)


## Breadth-first step counts from `from` over walkable tiles (8-neighbourhood).
func distance_field(from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(map.size * map.size)
	dist.fill(UNREACHABLE)
	from = nearest_walkable(from)
	dist[map.index(from)] = 0
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var d := dist[map.index(t)] + 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n := t + Vector2i(dx, dy)
				if not is_walkable(n) or dist[map.index(n)] != UNREACHABLE:
					continue
				if dx != 0 and dy != 0 and (not is_walkable(t + Vector2i(dx, 0)) or not is_walkable(t + Vector2i(0, dy))):
					continue
				dist[map.index(n)] = d
				queue.append(n)
	return dist


# --- enemies ---------------------------------------------------------------------

func build_enemy_field() -> void:
	enemy_dist = _road_field(map.gates)
	village_fields.clear()
	for v in map.villages:
		village_fields.append(_road_field(v["gates"]))


## Road steps from every road tile to the nearest of `gates`.
func _road_field(gates: Array) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(map.size * map.size)
	dist.fill(UNREACHABLE)
	var queue: Array[Vector2i] = []
	for g in gates:
		dist[map.index(g)] = 0
		queue.append(g)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for n in MapData.neighbors4(t):
			if map.is_road(n) and dist[map.index(n)] == UNREACHABLE:
				dist[map.index(n)] = dist[map.index(t)] + 1
				queue.append(n)
	return dist


## Road steps to the nearest gate (of village `village`, or of any village with -1).
func enemy_distance(t: Vector2i, village: int = -1) -> int:
	if not map.in_bounds(t):
		return UNREACHABLE
	var field := enemy_dist if village < 0 or village >= village_fields.size() else village_fields[village]
	return field[map.index(t)]


## The road tile nearest to `t` (for enemies that have to change course).
func nearest_road(t: Vector2i) -> Vector2i:
	if map.is_road(t):
		return t
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if map.is_road(t + Vector2i(dx, dy)):
					return t + Vector2i(dx, dy)
	return t


## Road route from a spawn to the nearest gate (of `village`, or of any village
## with -1), following the flow field. Ties between equally short branches are
## broken randomly.
func enemy_route(from: Vector2i, rng: RandomNumberGenerator, village: int = -1) -> Array[Vector2i]:
	var route: Array[Vector2i] = [from]
	var t := from
	var guard := 0
	while enemy_distance(t, village) > 0 and guard < map.size * map.size:
		guard += 1
		var best: Array[Vector2i] = []
		var best_d := enemy_distance(t, village)
		for n in MapData.neighbors4(t):
			var d := enemy_distance(n, village)
			if d < best_d:
				best_d = d
				best = [n]
			elif d == best_d and d < enemy_distance(t, village):
				best.append(n)
		if best.is_empty():
			break
		t = best[rng.randi() % best.size()]
		route.append(t)
	return route
