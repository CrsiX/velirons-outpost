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
## The unexplored tile it's after, and the walkable tile it goes to for it
## (the same, or the edge of forest / rock it can only look into).
var target := Vector2i(-1, -1)
var stand := Vector2i(-1, -1)
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
				if w.game.fog.reveal(w.grid_pos, reveal, w.village.id) > 0:
					w.on_action("explore")
			var arrived := w.step_path(delta)
			_think_timer -= delta
			# Target already revealed (we see further than we walk): pick the next one.
			if arrived or (w.game.fog.is_explored_by(w.village.id, target) and _think_timer <= 0.0):
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
	var chosen := choose_target(w.current_tile() if not w.at_home else w.village.center)
	if chosen == Vector2i(-1, -1):
		return false
	if not w.head_out(stand):
		return false
	if chosen != target:
		w.village.events.debug("%s heads for the fog at %s" % [w.label(), str(chosen)])
	target = chosen
	return true


func choose_target(from: Vector2i) -> Vector2i:
	var pathing := w.game.world.pathing
	var map := w.game.map
	var explored := w.game.fog.explored_of[w.village.id]
	var from_village := w.game.world.village_distance(w.village)
	var claims: Array[Vector2i] = []
	for other in w.village.workers():
		if other != w and other.exploring_target() != Vector2i(-1, -1):
			claims.append(other.exploring_target())
	# The nearest fog from here (a breadth-first search that stops early).
	var local := pathing.nearest_frontier(from, explored, claims, Config.EXPLORER_CLAIM_RADIUS, Config.EXPLORER_CLAIM_PENALTY)
	if local.is_empty():
		return Vector2i(-1, -1)
	var best_local: Vector2i = local[0]
	var best_local_stand: Vector2i = local[1]
	# The nearest fog from the village (its walking distances are cached).
	var best_home := Vector2i(-1, -1)
	var best_home_stand := Vector2i(-1, -1)
	var best_home_score := Pathing.UNREACHABLE
	for i in explored.size():
		if explored[i] == 1:
			continue
		var t := Vector2i(i % map.size, i / map.size)
		var d := from_village[i]
		var at := t
		if d >= Pathing.UNREACHABLE:
			# Can't walk there: seen from the nearest walkable tile next to it.
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := t.x + dx
					var ny := t.y + dy
					if nx < 0 or ny < 0 or nx >= map.size or ny >= map.size:
						continue
					var nd := from_village[ny * map.size + nx]
					if nd < Pathing.UNREACHABLE and nd + 1 < d:
						d = nd + 1
						at = Vector2i(nx, ny)
		if d >= best_home_score:
			continue
		var penalty := 0
		for c in claims:
			if Vector2(c).distance_to(Vector2(t)) < Config.EXPLORER_CLAIM_RADIUS:
				penalty = Config.EXPLORER_CLAIM_PENALTY
				break
		if d + penalty < best_home_score:
			best_home_score = d + penalty
			best_home = t
			best_home_stand = at
	# Don't wander off while much closer unexplored ground is still waiting.
	var local_from_village := from_village[map.index(best_local_stand)]
	if best_home != Vector2i(-1, -1) and local_from_village > best_home_score * Config.EXPLORER_WANDER_FACTOR + Config.EXPLORER_WANDER_SLACK:
		stand = best_home_stand
		return best_home
	stand = best_local_stand
	return best_local


func status() -> String:
	match state:
		State.EXPLORING: return "exploring"
		State.RETURNING: return "returning home"
	return "resting"
