class_name Explorer
extends Civilian
## Scouts the fog on their own:
## - heads for the nearest unexplored tile and keeps pushing into the unknown
##   from wherever they are (a greedy depth-first sweep);
## - switches to fog closer to the village when their local frontier is much
##   farther out than the village's nearest frontier;
## - avoids fog another explorer is already heading for;
## - runs home when an enemy comes close (shared Civilian evasion), rests,
##   then heads out again.

enum State { RESTING, EXPLORING, RETURNING }

var state := State.RESTING
var target := Vector2i(-1, -1)
var _reveal_timer := 0.0
var _think_timer := 0.0


func _tick(delta: float) -> void:
	match state:
		State.RESTING:
			rest_timer -= delta
			if rest_timer > 0.0:
				return
			rest_timer = 3.0  # idle re-check when nothing is left to explore
			if _pick_target():
				state = State.EXPLORING
		State.EXPLORING:
			_reveal_timer -= delta
			if _reveal_timer <= 0.0:
				_reveal_timer = 0.15
				game.fog.reveal(grid_pos, Config.EXPLORER_REVEAL)
			var arrived := step_path(delta)
			_think_timer -= delta
			# Target already revealed (we see further than we walk): pick the next one.
			if arrived or (game.map.is_explored(target) and _think_timer <= 0.0):
				_think_timer = 0.4
				if not _pick_target():
					_go_home_idle()
		State.RETURNING:
			if step_path(delta):
				arrive_home()
				state = State.RESTING
				rest_timer = 5.0


func _on_evade() -> void:
	state = State.RESTING
	target = Vector2i(-1, -1)


func _go_home_idle() -> void:
	target = Vector2i(-1, -1)
	state = State.RETURNING
	head_home()


## Chooses the next unexplored tile and starts walking. False if none is reachable.
func _pick_target() -> bool:
	var chosen := choose_target(current_tile() if not at_home else Config.VILLAGE_CENTER)
	if chosen == Vector2i(-1, -1):
		return false
	if not head_out(chosen):
		return false
	target = chosen
	return true


func choose_target(from: Vector2i) -> Vector2i:
	var pathing := game.world.pathing
	var map := game.map
	var from_me := pathing.distance_field(from)
	var from_village := game.world.village_distance()
	var claims: Array[Vector2i] = []
	for civ in game.population.civilians:
		if civ != self and civ is Explorer and civ.target != Vector2i(-1, -1):
			claims.append(civ.target)
	var best_local := Vector2i(-1, -1)
	var best_local_score := Pathing.UNREACHABLE
	var best_home := Vector2i(-1, -1)
	var best_home_score := Pathing.UNREACHABLE
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			var i := map.index(t)
			if map.explored[i] == 1 or from_me[i] == Pathing.UNREACHABLE:
				continue
			var penalty := 0
			for c in claims:
				if Vector2(c).distance_to(Vector2(t)) < Config.EXPLORER_CLAIM_RADIUS:
					penalty = Config.EXPLORER_CLAIM_PENALTY
					break
			if from_me[i] + penalty < best_local_score:
				best_local_score = from_me[i] + penalty
				best_local = t
			if from_village[i] + penalty < best_home_score:
				best_home_score = from_village[i] + penalty
				best_home = t
	if best_local == Vector2i(-1, -1):
		return best_local
	# Don't wander off while much closer unexplored ground is still waiting.
	var local_from_village := from_village[map.index(best_local)]
	if local_from_village > best_home_score * Config.EXPLORER_WANDER_FACTOR + Config.EXPLORER_WANDER_SLACK:
		return best_home
	return best_local


func status() -> String:
	if evading:
		return "fleeing from enemies"
	match state:
		State.EXPLORING: return "exploring"
		State.RETURNING: return "returning home"
	return "resting"


func _release_jobs() -> void:
	target = Vector2i(-1, -1)
