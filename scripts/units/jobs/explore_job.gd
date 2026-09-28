class_name ExploreJob
extends CivilianJob
## Scouts the fog:
## - heads for the nearest unexplored tile and keeps pushing into the unknown
##   from wherever it is (a greedy depth-first sweep);
## - switches to fog closer to the village when its local frontier is much
##   farther out than the village's nearest frontier;
## - avoids fog another explorer is already heading for.
## `reveal` is the sight radius used for exploring.

enum State { RESTING, EXPLORING, RETURNING }

var state := State.RESTING
var target := Vector2i(-1, -1)
var reveal := Config.EXPLORER_REVEAL
var _reveal_timer := 0.0
var _think_timer := 0.0


func _init(p_reveal: float = Config.EXPLORER_REVEAL) -> void:
	reveal = p_reveal


func tick(delta: float) -> void:
	match state:
		State.RESTING:
			w.rest_timer -= delta
			if w.rest_timer > 0.0:
				return
			w.rest_timer = 3.0  # idle re-check when nothing is left to explore
			if _pick_target():
				state = State.EXPLORING
		State.EXPLORING:
			_reveal_timer -= delta
			if _reveal_timer <= 0.0:
				_reveal_timer = 0.15
				if w.game.fog.reveal(w.grid_pos, reveal) > 0:
					w.on_action("explore")
			var arrived := w.step_path(delta)
			_think_timer -= delta
			# Target already revealed (we see further than we walk): pick the next one.
			if arrived or (w.game.map.is_explored(target) and _think_timer <= 0.0):
				_think_timer = 0.4
				if not _pick_target():
					_go_home_idle()
		State.RETURNING:
			if w.step_path(delta):
				w.arrive_home()
				state = State.RESTING
				w.rest_timer = 5.0


func on_evade() -> void:
	state = State.RESTING
	target = Vector2i(-1, -1)


func release() -> void:
	target = Vector2i(-1, -1)


func exploring_target() -> Vector2i:
	return target


func _go_home_idle() -> void:
	target = Vector2i(-1, -1)
	state = State.RETURNING
	w.head_home()


## Chooses the next unexplored tile and starts walking. False if none is reachable.
func _pick_target() -> bool:
	var chosen := choose_target(w.current_tile() if not w.at_home else Config.VILLAGE_CENTER)
	if chosen == Vector2i(-1, -1):
		return false
	if not w.head_out(chosen):
		return false
	target = chosen
	return true


func choose_target(from: Vector2i) -> Vector2i:
	var pathing := w.game.world.pathing
	var map := w.game.map
	var from_me := pathing.distance_field(from)
	var from_village := w.game.world.village_distance()
	var claims: Array[Vector2i] = []
	for other in w.game.workers():
		if other != w and other.exploring_target() != Vector2i(-1, -1):
			claims.append(other.exploring_target())
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
	match state:
		State.EXPLORING: return "exploring"
		State.RETURNING: return "returning home"
	return "resting"
