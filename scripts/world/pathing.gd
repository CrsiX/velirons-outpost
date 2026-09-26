class_name Pathing
extends RefCounted
## Navigation for both sides.
## Civilians: AStarGrid2D over everything that isn't a solid building (forest is slow).
## Goblins: a flow field over road tiles pointing to the nearest gate.

const FOREST_WEIGHT := 2.0
const UNREACHABLE := 1 << 30

var map: MapData
var astar := AStarGrid2D.new()
var enemy_dist := PackedInt32Array()


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
			if map.is_forest(t):
				astar.set_point_weight_scale(t, FOREST_WEIGHT)
	build_enemy_field()


func set_solid(t: Vector2i, solid: bool) -> void:
	astar.set_point_solid(t, solid)


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
	enemy_dist.resize(map.size * map.size)
	enemy_dist.fill(UNREACHABLE)
	var queue: Array[Vector2i] = []
	for g in map.gates:
		enemy_dist[map.index(g)] = 0
		queue.append(g)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for n in MapData.neighbors4(t):
			if map.is_road(n) and enemy_dist[map.index(n)] == UNREACHABLE:
				enemy_dist[map.index(n)] = enemy_dist[map.index(t)] + 1
				queue.append(n)


func enemy_distance(t: Vector2i) -> int:
	return enemy_dist[map.index(t)] if map.in_bounds(t) else UNREACHABLE


## Road route from a spawn to the nearest gate, following the flow field.
## Ties between equally short branches are broken randomly.
func enemy_route(from: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var route: Array[Vector2i] = [from]
	var t := from
	var guard := 0
	while enemy_distance(t) > 0 and guard < map.size * map.size:
		guard += 1
		var best: Array[Vector2i] = []
		var best_d := enemy_distance(t)
		for n in MapData.neighbors4(t):
			var d := enemy_distance(n)
			if d < best_d:
				best_d = d
				best = [n]
			elif d == best_d and d < enemy_distance(t):
				best.append(n)
		if best.is_empty():
			break
		t = best[rng.randi() % best.size()]
		route.append(t)
	return route
