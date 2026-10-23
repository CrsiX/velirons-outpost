class_name Pathing
extends RefCounted
## Navigation for both sides.
## Ground units (civilians, soldiers): AStarGrid2D; forest, mountains, deep
## water, lava and solid buildings block; shallow water and swamp cost more. Enemies: flow fields over road tiles: one to the nearest
## gate of any village, and one per village to that village's own gates (each
## village's wave goes for that village; see Waves). Amphibians (crabs,
## sirens) have the same over road and water tiles; water-bound monsters
## move within one body of deep water (water_body, water_path;
## docs/aquatic-design.md §3).

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
## Per tile: the body of deep water it belongs to (index into `bodies`; -1:
## not deep water). Bodies are 4-connected; bridges split them.
var water_body := PackedInt32Array()
## Per body: {"deep": tile count, "width": its widest point in tiles (a
## one-tile river is 1), "tiles": Array[Vector2i] (its deep tiles)}.
var bodies: Array[Dictionary] = []
## Amphibians: steps over road and water tiles to the nearest gate of any
## village, and per village to its own gates.
var amphibian_dist := PackedInt32Array()
var amphibian_fields: Array[PackedInt32Array] = []
## Deep water only (water-bound monsters).
var water_astar := AStarGrid2D.new()
## Walkable ground and forest (wrathwoods; docs/enemies-design.md §15c):
## made the first time one asks (wood_path), then kept in step by set_solid.
var _wood: AStarGrid2D = null
## The vultures' sky (sky_path): built on first use, kept up by set_solid.
var _sky: AStarGrid2D = null


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
	_build_water()


## Buildings toggle solidity; impassable terrain always stays solid.
func set_solid(t: Vector2i, solid: bool) -> void:
	var blocked := solid or not map.is_passable(t)
	astar.set_point_solid(t, blocked)
	if _wood and map.in_bounds(t):
		_wood.set_point_solid(t, blocked and not map.is_forest(t))
	if _sky and map.in_bounds(t):
		_sky.set_point_solid(t, not sky_open(t))
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


## Like find_path, but forest can be walked too (a wrathwood's way). From
## where it stands (nearest such tile) to `to`, or to the nearest such tile
## next to it when `to` is solid (a building it means to smash).
func wood_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if _wood == null:
		_wood = AStarGrid2D.new()
		_wood.region = Rect2i(0, 0, map.size, map.size)
		_wood.cell_size = Vector2.ONE
		_wood.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_wood.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_wood.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_wood.update()
		for y in map.size:
			for x in map.size:
				var t := Vector2i(x, y)
				_wood.set_point_solid(t, astar.is_point_solid(t) and not map.is_forest(t))
	if not map.in_bounds(from) or not map.in_bounds(to):
		return PackedVector2Array()
	from = _wood_open_near(from, from)
	to = _wood_open_near(to, Vector2(from))
	if from == Vector2i(-1, -1) or to == Vector2i(-1, -1):
		return PackedVector2Array()
	return _wood.get_point_path(from, to, true)


## `t` if a wrathwood can stand there, else its neighbour nearest `near`
## that it can, else (-1, -1).
func _wood_open_near(t: Vector2i, near: Vector2) -> Vector2i:
	if not _wood.is_point_solid(t):
		return t
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := t + Vector2i(dx, dy)
			if map.in_bounds(n) and not _wood.is_point_solid(n) and Vector2(n).distance_squared_to(near) < best_d:
				best_d = Vector2(n).distance_squared_to(near)
				best = n
	return best


## Can a vulture fly over `t` (docs/enemies-design.md §15d)? Any tile a
## ground unit can walk on, deep water and forest; never mountains, lava,
## buildings or solid map objects.
func sky_open(t: Vector2i) -> bool:
	return map.in_bounds(t) and (not astar.is_point_solid(t) or ((map.is_deep(t) or map.is_forest(t)) and map.building_at(t) == null))


func _sky_grid() -> AStarGrid2D:
	if _sky == null:
		_sky = AStarGrid2D.new()
		_sky.region = Rect2i(0, 0, map.size, map.size)
		_sky.cell_size = Vector2.ONE
		_sky.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_sky.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_sky.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_sky.update()
		for y in map.size:
			for x in map.size:
				_sky.set_point_solid(Vector2i(x, y), not sky_open(Vector2i(x, y)))
	return _sky


## A vulture's flight from `from` to `to` (near-straight, no roads; from and
## to moved to the nearest open tile next to them). Empty when there's no way.
func sky_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var g := _sky_grid()
	from = _sky_open_near(from, Vector2(to))
	to = _sky_open_near(to, Vector2(from))
	if from == Vector2i(-1, -1) or to == Vector2i(-1, -1):
		return PackedVector2Array()
	return g.get_point_path(from, to, false)


## `t` if open sky, else its open neighbour nearest `near`, else (-1, -1).
func _sky_open_near(t: Vector2i, near: Vector2) -> Vector2i:
	if sky_open(t):
		return t
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := t + Vector2i(dx, dy)
			if sky_open(n) and Vector2(n).distance_squared_to(near) < best_d:
				best_d = Vector2(n).distance_squared_to(near)
				best = n
	return best


## The map-edge tile nearest `from` by flight (a flood fill over the open sky,
## 8 neighbours), or (-1, -1): where vultures come from and leave to.
func sky_edge(from: Vector2i) -> Vector2i:
	var start := _sky_open_near(from, Vector2(from))
	if start == Vector2i(-1, -1):
		return start
	var n := map.size
	var seen := PackedByteArray()
	seen.resize(n * n)
	var queue: Array[Vector2i] = [start]
	seen[start.y * n + start.x] = 1
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		if t.x == 0 or t.y == 0 or t.x == n - 1 or t.y == n - 1:
			return t
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := t + Vector2i(dx, dy)
				if (dx != 0 or dy != 0) and map.in_bounds(c) and seen[c.y * n + c.x] == 0 and sky_open(c):
					seen[c.y * n + c.x] = 1
					queue.append(c)
	return Vector2i(-1, -1)


## Can a wrathwood stand on `t` (walkable ground or forest)?
func wood_open(t: Vector2i) -> bool:
	return map.in_bounds(t) and (is_walkable(t) or (map.is_forest(t) and map.building_at(t) == null))


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


## Road steps to the nearest gate (of village `village`, or of any village
## with -1); `amphibian`: over road and water tiles.
func enemy_distance(t: Vector2i, village: int = -1, amphibian := false) -> int:
	if not map.in_bounds(t):
		return UNREACHABLE
	var field: PackedInt32Array
	if amphibian:
		field = amphibian_dist if village < 0 or village >= amphibian_fields.size() else amphibian_fields[village]
	else:
		field = enemy_dist if village < 0 or village >= village_fields.size() else village_fields[village]
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
## broken randomly. `amphibian`: over road and water tiles.
func enemy_route(from: Vector2i, rng: RandomNumberGenerator, village: int = -1, amphibian := false) -> Array[Vector2i]:
	var route: Array[Vector2i] = [from]
	var t := from
	var guard := 0
	while enemy_distance(t, village, amphibian) > 0 and guard < map.size * map.size:
		guard += 1
		var best: Array[Vector2i] = []
		var here := enemy_distance(t, village, amphibian)
		var best_d := here
		for n in MapData.neighbors4(t):
			var d := enemy_distance(n, village, amphibian)
			if d < best_d:
				best_d = d
				best = [n]
			elif d == best_d and d < here:
				best.append(n)
		if best.is_empty():
			break
		t = best[rng.randi() % best.size()]
		route.append(t)
	return route


# --- water (docs/aquatic-design.md §3) ----------------------------------------------------

func _build_water() -> void:
	var n := map.size
	var lab := label_water(map)
	water_body = lab["of"]
	bodies.assign(lab["bodies"])
	water_astar.region = Rect2i(0, 0, n, n)
	water_astar.cell_size = Vector2.ONE
	water_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	water_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	water_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	water_astar.update()
	for y in n:
		for x in n:
			water_astar.set_point_solid(Vector2i(x, y), not map.is_deep_water(Vector2i(x, y)))
	amphibian_dist = _amphibian_field(map.gates)
	amphibian_fields.clear()
	for v in map.villages:
		amphibian_fields.append(_amphibian_field(v["gates"]))


## The map's bodies of deep water (4-connected; a bridge over deep water
## joins the water on either side, Mapdata.is_deep_water):
## {"of": PackedInt32Array (per tile: its body, -1: not deep water),
## "bodies": [{"deep": count of its deep tiles (bridges not counted), "width": its widest point in tiles (2 x
## the most Chebyshev steps from a tile that isn't deep water, minus 1: a
## one-tile river is 1), "tiles": Array[Vector2i]}]}. Beyond the map's edge
## counts as water (the sea goes on there). The map editor uses it too.
static func label_water(map: MapData) -> Dictionary:
	var n := map.size
	var of := PackedInt32Array()
	of.resize(n * n)
	of.fill(-1)
	var out: Array[Dictionary] = []
	var depth := PackedInt32Array()
	depth.resize(n * n)
	depth.fill(0)
	var queue: Array[Vector2i] = []
	for y in n:
		for x in n:
			var t := Vector2i(x, y)
			if not map.is_deep_water(t):
				continue
			for k in 8:
				var nb := t + Vector2i([-1, 1, 0, 0, -1, 1, -1, 1][k], [0, 0, -1, 1, -1, -1, 1, 1][k])
				if map.in_bounds(nb) and not map.is_deep_water(nb):
					depth[y * n + x] = 1
					queue.append(t)
					break
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var d := depth[map.index(t)] + 1
		for k in 8:
			var nb := t + Vector2i([-1, 1, 0, 0, -1, 1, -1, 1][k], [0, 0, -1, 1, -1, -1, 1, 1][k])
			if map.in_bounds(nb) and map.is_deep_water(nb) and depth[map.index(nb)] == 0:
				depth[map.index(nb)] = d
				queue.append(nb)
	for y in n:
		for x in n:
			var start := Vector2i(x, y)
			if not map.is_deep_water(start) or of[map.index(start)] >= 0:
				continue
			var id := out.size()
			var tiles: Array[Vector2i] = [start]
			of[map.index(start)] = id
			var deepest := 0
			var h := 0
			while h < tiles.size():
				var t := tiles[h]
				h += 1
				var dt := depth[map.index(t)]
				deepest = maxi(deepest, dt if dt > 0 else n)
				for nb in MapData.neighbors4(t):
					if map.is_deep_water(nb) and of[map.index(nb)] < 0:
						of[map.index(nb)] = id
						tiles.append(nb)
			var deep := tiles.filter(func(t: Vector2i) -> bool: return map.is_deep(t)).size()
			out.append({"deep": deep, "width": 2 * mini(deepest, n) - 1, "tiles": tiles})
	return {"of": of, "bodies": out}


## The water monsters (WAVE_MIX "needs": "water") that can live in `body`
## (a label_water entry).
static func kinds_fitting(body: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for kind: String in Config.WAVE_MIX:
		if Config.WAVE_MIX[kind].get("needs", "") != "water":
			continue
		var e: Dictionary = Config.ENEMIES[kind]
		if int(body["deep"]) >= int(e.get("min_deep_tiles", 1)) and int(body["width"]) >= int(e.get("min_width", 1)):
			out.append(kind)
	return out


## Steps over road and water tiles from every such tile to the nearest of `gates`.
func _amphibian_field(gates: Array) -> PackedInt32Array:
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
		for nb in MapData.neighbors4(t):
			if map.in_bounds(nb) and dist[map.index(nb)] == UNREACHABLE and (map.is_road(nb) or map.is_wet(nb)):
				dist[map.index(nb)] = dist[map.index(t)] + 1
				queue.append(nb)
	return dist


## The deep-water body of `t` (-1: not deep water).
func body_of(t: Vector2i) -> int:
	return water_body[map.index(t)] if map.in_bounds(t) else -1


## Whether a kind (Config.ENEMIES) can live in body `b`.
func body_fits(b: int, kind: String) -> bool:
	if b < 0 or b >= bodies.size():
		return false
	var e: Dictionary = Config.ENEMIES[kind]
	return int(bodies[b]["deep"]) >= int(e.get("min_deep_tiles", 1)) and int(bodies[b]["width"]) >= int(e.get("min_width", 1))


## Grid waypoints over deep water from `from` to `to` (same body; empty if none).
func water_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if not map.is_deep_water(from) or not map.is_deep_water(to) or body_of(from) != body_of(to):
		return PackedVector2Array()
	return water_astar.get_point_path(from, to)


## The deep tile of body `b` nearest to `p` (grid; not a bridge), or (-1, -1).
func nearest_deep(b: int, p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	if b < 0 or b >= bodies.size():
		return best
	for t: Vector2i in bodies[b]["tiles"]:
		if not map.is_deep(t):
			continue
		var d := Vector2(t).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = t
	return best


## A walkable tile to stand on to reach `t` in close combat: `t` itself, or
## its nearest walkable neighbour (deep water: from the shore), else (-1, -1).
func stand_near(t: Vector2i, from: Vector2) -> Vector2i:
	if is_walkable(t):
		return t
	var best := Vector2i(-1, -1)
	var best_d := INF
	for k in 8:
		var nb := t + Vector2i([-1, 1, 0, 0, -1, 1, -1, 1][k], [0, 0, -1, 1, -1, -1, 1, 1][k])
		if is_walkable(nb):
			var d := Vector2(nb).distance_squared_to(from)
			if d < best_d:
				best_d = d
				best = nb
	return best
