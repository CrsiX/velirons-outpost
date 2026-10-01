class_name Forester
extends Civilian
## Works from one worker camp (assigned by the player). The cycle is:
## camp -> nearest tree -> chop for a while -> back to camp (drops off building
## material) -> rest -> same tree again, until it falls and the tile turns to
## meadow; then the next tree nearby.

enum State { IDLE, TO_CAMP, AT_CAMP, TO_TREE, CHOPPING, BACK_TO_CAMP, GOING_HOME }

var state := State.IDLE
var camp: WorkerCamp = null
var tree := Vector2i(-1, -1)
var carrying := 0
var _timer := 0.0


func workplace() -> Building:
	return camp


func assign(p_camp: WorkerCamp) -> void:
	camp = p_camp


func unassign() -> void:
	_release_tree()
	camp = null


func _tick(delta: float) -> void:
	if state != State.IDLE and state != State.GOING_HOME and not _camp_ok():
		_go_village()
	match state:
		State.IDLE:
			rest_timer -= delta
			if rest_timer > 0.0 or not _camp_ok():
				return
			rest_timer = 1.0
			if head_out(camp.tile):
				state = State.TO_CAMP
		State.TO_CAMP, State.BACK_TO_CAMP:
			if step_path(delta):
				_arrive_camp()
		State.AT_CAMP:
			_timer -= delta
			if _timer > 0.0:
				return
			_timer = 3.0  # re-check for trees every few seconds
			_head_to_tree()
		State.TO_TREE:
			if not game.world.is_tree(tree):
				_head_to_tree()
				return
			if step_path(delta):
				state = State.CHOPPING
				_timer = Config.FORESTER_CHOP_SESSION
				var dx := Iso.to_world(Vector2(tree) - grid_pos).x
				sprite.flip_h = dx < 0.0
		State.CHOPPING:
			_timer -= delta
			_bob += delta * 10.0
			sprite.rotation = sin(_bob) * 0.25
			var felled := game.world.chop_tree(tree, delta)
			if felled:
				village.events.debug("%s cut down %s" % [label(), game.world.tree_label(tree)])
			if felled or _timer <= 0.0:
				carrying = Config.FORESTER_MATERIAL_PER_TRIP
				if felled:
					tree = Vector2i(-1, -1)
				sprite.rotation = 0.0
				if head_out(camp.tile):
					state = State.BACK_TO_CAMP
				else:
					_go_village()
		State.GOING_HOME:
			if step_path(delta):
				arrive_home()
				state = State.IDLE


func _camp_ok() -> bool:
	return is_instance_valid(camp) and camp.complete and camp.forester == self


func _arrive_camp() -> void:
	if carrying > 0:
		village.economy.add("materials", carrying)
		village.events.debug("%s delivers %d building material at %s" % [label(), carrying, camp.label() if is_instance_valid(camp) else "camp"])
		float_text("+%d {materials}" % carrying, Color("c9b98f"))
		carrying = 0
	state = State.AT_CAMP
	_timer = Config.FORESTER_REST
	visible = false  # resting in the tent


## Keeps working the current tree until it falls, then picks the next one.
func _head_to_tree() -> void:
	if not game.world.is_tree(tree):
		_release_tree()
		var found := game.world.find_tree(camp.tile, Config.FORESTER_SEARCH_RADIUS, self)
		if found.is_empty():
			state = State.AT_CAMP
			return
		tree = found["tree"]
		game.world.claim_tree(tree, self)
	var stand := _stand_tile()
	visible = true
	if stand != Vector2i(-1, -1) and head_out(stand):
		state = State.TO_TREE
	else:
		_release_tree()
		tree = Vector2i(-1, -1)
		state = State.AT_CAMP


func _stand_tile() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for ny in range(-1, 2):
		for nx in range(-1, 2):
			var st := tree + Vector2i(nx, ny)
			if st != tree and game.world.pathing.is_walkable(st):
				var d := Vector2(st).distance_to(Vector2(camp.tile))
				if d < best_d:
					best_d = d
					best = st
	return best


func _release_tree() -> void:
	if tree != Vector2i(-1, -1):
		game.world.release_tree(tree, self)


func _go_village() -> void:
	_release_tree()
	tree = Vector2i(-1, -1)
	visible = true
	sprite.rotation = 0.0
	state = State.GOING_HOME
	head_home()


func _on_evade() -> void:
	visible = true
	sprite.rotation = 0.0
	state = State.GOING_HOME


func _after_evade() -> void:
	carrying = 0
	state = State.IDLE  # heads back out to the camp after resting


func status() -> String:
	if evading:
		return "fleeing from enemies"
	match state:
		State.TO_CAMP: return "walking to the camp"
		State.AT_CAMP: return "resting at the camp" if tree != Vector2i(-1, -1) else "resting (looking for trees)"
		State.TO_TREE: return "walking to a tree"
		State.CHOPPING: return "chopping (%d%%)" % int(100.0 * game.world.tree_progress(tree))
		State.BACK_TO_CAMP: return "carrying wood to the camp"
		State.GOING_HOME: return "returning to the village"
	return "no camp assigned" if camp == null else "resting"


func _release_jobs() -> void:
	_release_tree()
	if is_instance_valid(camp) and camp.forester == self:
		camp.forester = null
	camp = null
