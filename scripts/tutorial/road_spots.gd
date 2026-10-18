class_name RoadSpots
extends RefCounted
## Spots the guided cards point at (the tutorial's, a scenario's): a stretch
## of road the first enemies take, places to build by it or by the village,
## and, once a spot is built on, the nearest free one instead.

## How far (tiles) a taken spot looks for a free one.
const SEARCH := 6

var game: Game
## The last road tiles before the gate, from the edge spawn nearest by road.
var route: Array[Vector2i] = []
## Where that stretch starts (a road tile).
var spawn_tile := Vector2i(-1, -1)
## kind + picked spot -> the spot shown now, when the picked one got taken (see spot).
var _moved := {}


func _init(p_game: Game) -> void:
	game = p_game


## The road from the edge spawn nearest to the village (by road; `which` 1:
## the next nearest, ...): its last `length` + 1 tiles before the gate. False
## if the map has no such edge spawn.
func pick_route(length: int, seed_value: int, which: int = 0) -> bool:
	var pathing := game.world.pathing
	var order: Array = []  # [distance, index in edge_spawns]: ties keep the map's order
	for i in game.map.edge_spawns.size():
		var d := pathing.enemy_distance(game.map.edge_spawns[i])
		if d < Pathing.UNREACHABLE:
			order.append([d, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	if which >= order.size():
		return false
	var best: Vector2i = game.map.edge_spawns[int(order[which][1])]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var full := pathing.enemy_route(best, rng)
	var keep := mini(full.size(), length + 1)
	route = full.slice(full.size() - keep)
	spawn_tile = route[0]
	return true


## A free spot for `kind` right next to the route, `lo` to `hi` road tiles
## before the gate (nearest to the middle of that stretch), clear of `taken`;
## else the nearest free one by the village.
func by_road(kind: String, lo: int, hi: int, taken: Array[Vector2i]) -> Vector2i:
	var size: int = Config.BUILDINGS[kind]["size"]
	var best := Vector2i(-1, -1)
	var best_score := INF
	var n := route.size()
	for i in n:
		var before_gate := n - 1 - i
		if before_gate < lo or before_gate > hi:
			continue
		var r := route[i]
		for dy in range(-size, size + 1):
			for dx in range(-size, size + 1):
				var t := r + Vector2i(dx, dy)
				if not fits(kind, t, taken) or not _touches_road(t, size):
					continue
				var score := absf(before_gate - (lo + hi) / 2.0) + 0.1 * Vector2(t).distance_to(Vector2(game.player_village.center))
				if score < best_score:
					best_score = score
					best = t
	return best if best != Vector2i(-1, -1) else near_village(kind, taken)


## The free spot for `kind` nearest the village centre (within 9 tiles), clear of `taken`.
func near_village(kind: String, taken: Array[Vector2i]) -> Vector2i:
	var c := game.player_village.center
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var t := c + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(c))
			if d < best_d and fits(kind, t, taken):
				best_d = d
				best = t
	return best


## The spot to mark for `kind`: `picked` while it's still free, else the
## nearest free spot to it (kept while it stays free, so the mark doesn't
## wander), else `picked` all the same.
func spot(kind: String, picked: Vector2i) -> Vector2i:
	var key := "%s %s" % [kind, picked]
	if picked == Vector2i(-1, -1) or game.construction.placement_error(kind, picked, true) == "":
		_moved.erase(key)
		return picked
	var last: Vector2i = _moved.get(key, Vector2i(-1, -1))
	if last != Vector2i(-1, -1) and game.construction.placement_error(kind, last, true) == "":
		return last
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-SEARCH, SEARCH + 1):
		for dx in range(-SEARCH, SEARCH + 1):
			var t := picked + Vector2i(dx, dy)
			var d := Vector2(dx, dy).length()
			if d < best_d and game.map.in_bounds(t) and game.construction.placement_error(kind, t, true) == "":
				best_d = d
				best = t
	if best == Vector2i(-1, -1):
		_moved.erase(key)
		return picked
	_moved[key] = best
	game.events.debug("%s spot %s is taken, marking %s" % [kind, picked, best])
	return best


## Free for `kind` (ignoring fog and cost), not on or right next to `taken`.
func fits(kind: String, t: Vector2i, taken: Array[Vector2i]) -> bool:
	if game.construction.placement_error(kind, t, true) != "":
		return false
	for f in Building.footprint(t, Config.BUILDINGS[kind]["size"]):
		for k in taken:
			if maxi(absi(f.x - k.x), absi(f.y - k.y)) <= 1:
				return false
	return true


func _touches_road(t: Vector2i, size: int) -> bool:
	for f in Building.footprint(t, size):
		for n in MapData.neighbors4(f):
			if route.has(n):
				return true
	return false
