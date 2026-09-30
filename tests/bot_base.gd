extends Node
## Shared harness of the headless test bots (tests/*_bot.gd): each one runs
## `_run()`, calls check() for every expectation and finishes with the
## CHECKS / FAILURES line and exit code 0 when everything passed.

var failures: Array[String] = []
var checks := 0
var game: Game


func _ready() -> void:
	call_deferred("_run")


func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures.append(msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout:
			return false
	return true


func find_spot(kind: String, near: Vector2i) -> Vector2i:
	var cands: Array = []
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			if game.construction.placement_error(kind, t) == "":
				cands.append([Vector2(t).distance_to(Vector2(near)), t])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in cands:
		var t: Vector2i = c[1]
		for nb in [t, t + Vector2i(1, 0), t + Vector2i(-1, 0), t + Vector2i(0, 1), t + Vector2i(0, -1)]:
			if game.world.pathing.is_walkable(nb) and not game.world.pathing.find_path(game.player_village.center, nb).is_empty():
				return t
	return Vector2i(-1, -1)


func _bench_hero(on: bool) -> void:
	var h := game.hero
	h.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		h.remove_from_group("melee_defenders")
	else:
		h.add_to_group("melee_defenders")


func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			e.take_damage(1e9)
	await frames(3)
