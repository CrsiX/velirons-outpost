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
## 1 per walkable tile (a copy of the A* solidity, for fast searches).
var _walk := PackedByteArray()
var enemy_dist := PackedInt32Array()
## Per village id: road steps to that village's nearest gate.
var village_fields: Array[PackedInt32Array] = []
## Goes up whenever a tile's walkability changes (keys the reach cache).
var version := 0
var _reach_cache := {}  # from tile -> [version, distance field]


func _init(p_map: MapData) -> void:
	map = p_map
	astar.region = Rect2i(0, 0, map.size, map.size)
	astar.cell_size = Vector2.ONE
	astar.offset = Vector2.ZERO
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	_walk.resize(map.size * map.size)
	_walk.fill(1)
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if not map.is_passable(t):
				astar.set_point_solid(t, true)
				_walk[y * map.size + x] = 0
			else:
				var f := map.walk_factor(t)
				if f < 1.0:
					astar.set_point_weight_scale(t, 1.0 / f)  # (slow ground: go round if it's not far)
	build_enemy_field()


## Buildings toggle solidity; impassable terrain always stays solid.
func set_solid(t: Vector2i, solid: bool) -> void:
	var blocked := solid or not map.is_passable(t)
	astar.set_point_solid(t, blocked)
	if map.in_bounds(t) and _walk[map.index(t)] != (0 if blocked else 1):
		_walk[map.index(t)] = 0 if blocked else 1
		version += 1


## Steps from `from` to every tile (distance_field), kept until the map's
## walkability changes: for "can anyone get there from the village?".
func reach_from(from: Vector2i) -> PackedInt32Array:
	var c: Array = _reach_cache.get(from, [])
	if c.is_empty() or c[0] != version:
		c = [version, distance_field(from)]
		_reach_cache[from] = c
	return c[1]


func can_reach(from: Vector2i, t: Vector2i) -> bool:
	return map.in_bounds(t) and reach_from(from)[map.index(t)] < UNREACHABLE


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


## Breadth-first step counts from `from` over walkable tiles (8-neighbourhood;
## diagonal steps only when both side tiles are walkable). Works on tile
## indices and the cached walkability: it runs often (explorers, villagers).
func distance_field(from: Vector2i) -> PackedInt32Array:
	var n := map.size
	var dist := PackedInt32Array()
	dist.resize(n * n)
	dist.fill(UNREACHABLE)
	from = nearest_walkable(from)
	if not map.in_bounds(from):
		return dist
	var queue := PackedInt32Array()
	queue.resize(n * n)
	var start := from.y * n + from.x
	dist[start] = 0
	queue[0] = start
	var head := 0
	var tail := 1
	var walk := _walk
	while head < tail:
		var i := queue[head]
		head += 1
		var x := i % n
		var y := i / n
		var d := dist[i] + 1
		var left := x > 0
		var right := x < n - 1
		var up := y > 0
		var down := y < n - 1
		# Straight steps.
		if left and walk[i - 1] == 1 and dist[i - 1] == UNREACHABLE:
			dist[i - 1] = d
			queue[tail] = i - 1
			tail += 1
		if right and walk[i + 1] == 1 and dist[i + 1] == UNREACHABLE:
			dist[i + 1] = d
			queue[tail] = i + 1
			tail += 1
		if up and walk[i - n] == 1 and dist[i - n] == UNREACHABLE:
			dist[i - n] = d
			queue[tail] = i - n
			tail += 1
		if down and walk[i + n] == 1 and dist[i + n] == UNREACHABLE:
			dist[i + n] = d
			queue[tail] = i + n
			tail += 1
		# Diagonal steps, never cutting a corner.
		if up and left and walk[i - n - 1] == 1 and dist[i - n - 1] == UNREACHABLE and walk[i - 1] == 1 and walk[i - n] == 1:
			dist[i - n - 1] = d
			queue[tail] = i - n - 1
			tail += 1
		if up and right and walk[i - n + 1] == 1 and dist[i - n + 1] == UNREACHABLE and walk[i + 1] == 1 and walk[i - n] == 1:
			dist[i - n + 1] = d
			queue[tail] = i - n + 1
			tail += 1
		if down and left and walk[i + n - 1] == 1 and dist[i + n - 1] == UNREACHABLE and walk[i - 1] == 1 and walk[i + n] == 1:
			dist[i + n - 1] = d
			queue[tail] = i + n - 1
			tail += 1
		if down and right and walk[i + n + 1] == 1 and dist[i + n + 1] == UNREACHABLE and walk[i + 1] == 1 and walk[i + n] == 1:
			dist[i + n + 1] = d
			queue[tail] = i + n + 1
			tail += 1
	return dist


## The nearest fog to explore from `from`: [the unexplored tile, where to
## stand for it], or [] if none. A walkable unexplored tile is walked onto;
## unexplored forest, rock or water is looked into from the walkable tile
## next to it (explorers see into it; they can't walk there).
func nearest_frontier(from: Vector2i, explored: PackedByteArray, claims: Array[Vector2i], claim_radius: float, penalty: int, danger := PackedByteArray()) -> Array[Vector2i]:
	var stand := nearest_unexplored(from, explored, claims, claim_radius, penalty, danger)
	if stand == Vector2i(-1, -1):
		return []
	var i := map.index(stand)
	if explored[i] == 0:
		return [stand, stand]
	for k in 8:
		var t := stand + Vector2i([-1, 1, 0, 0, -1, 1, -1, 1][k], [0, 0, -1, 1, -1, -1, 1, 1][k])
		if map.in_bounds(t) and explored[map.index(t)] == 0:
			return [t, stand]
	return []


## Walkable tile from which the nearest fog is explored (see nearest_frontier):
## an unexplored walkable tile, or one next to unexplored ground nobody can
## walk on. Breadth first from `from`; fog near `claims` costs `penalty` extra.
## Tiles marked in `danger` (if given) are neither explored from nor walked through.
func nearest_unexplored(from: Vector2i, explored: PackedByteArray, claims: Array[Vector2i], claim_radius: float, penalty: int, danger := PackedByteArray()) -> Vector2i:
	var n := map.size
	from = nearest_walkable(from)
	if not map.in_bounds(from):
		return Vector2i(-1, -1)
	var dist := PackedInt32Array()
	dist.resize(n * n)
	dist.fill(UNREACHABLE)
	var queue := PackedInt32Array()
	queue.resize(n * n)
	var start := from.y * n + from.x
	dist[start] = 0
	queue[0] = start
	var head := 0
	var tail := 1
	var walk := _walk
	var best := -1
	var best_score := UNREACHABLE
	var steps := PackedInt32Array([-1, 1, -n, n, -n - 1, -n + 1, n - 1, n + 1])
	var avoid := not danger.is_empty()
	while head < tail:
		var i := queue[head]
		head += 1
		var d := dist[i]
		if d >= best_score:
			break  # (breadth first: nothing nearer is left)
		if avoid and danger[i] == 1 and i != start:
			continue
		var x := i % n
		var y := i / n
		# Fog here, or fog next to it that can't be walked on (seen from here).
		var fog := explored[i] == 0
		if not fog:
			for k in 8:
				var ddx := -1 if k in [0, 4, 6] else (1 if k in [1, 5, 7] else 0)
				var ddy := -1 if k in [2, 4, 5] else (1 if k in [3, 6, 7] else 0)
				if x + ddx < 0 or x + ddx >= n or y + ddy < 0 or y + ddy >= n:
					continue
				var jj := i + steps[k]
				if walk[jj] == 0 and explored[jj] == 0:
					fog = true
					break
		if fog:
			var score := d if explored[i] == 0 else d + 1
			if not claims.is_empty():
				var t := Vector2(x, y)
				for c in claims:
					if Vector2(c).distance_to(t) < claim_radius:
						score += penalty
						break
			if score < best_score:
				best_score = score
				best = i
		for k in 8:
			var dx := -1 if k in [0, 4, 6] else (1 if k in [1, 5, 7] else 0)
			var dy := -1 if k in [2, 4, 5] else (1 if k in [3, 6, 7] else 0)
			if x + dx < 0 or x + dx >= n or y + dy < 0 or y + dy >= n:
				continue
			var j := i + steps[k]
			if walk[j] == 0 or dist[j] != UNREACHABLE:
				continue
			if dx != 0 and dy != 0 and (walk[i + dx] == 0 or walk[i + dy * n] == 0):
				continue
			dist[j] = d + 1
			queue[tail] = j
			tail += 1
	return Vector2i(best % n, best / n) if best >= 0 else Vector2i(-1, -1)


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
