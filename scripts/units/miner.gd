class_name Miner
extends Civilian
## Works a mine for gold (docs/world-design.md §9.6). Lives in a hut like any
## villager (and dies if it's destroyed), but works entirely at the mine: he
## walks there once and stays inside, safe, producing MINE_GOLD_RATE gold per
## second, and only comes back when he's unassigned. Only one miner works a
## mine: if another village's miner got there first, he's turned away and
## walks home unassigned. Walking there and back he's at risk like anyone.

enum State { IDLE, TO_MINE, WORKING, RETURNING }

var state := State.IDLE
var mine: Mine = null
var _gold := 0.0


func workplace() -> Building:
	return mine


func assign(m: Building) -> void:
	mine = m as Mine
	state = State.TO_MINE
	if not head_out(mine.visit_tile()):
		village.events.info("%s can't find a way to the mine" % label().capitalize())
		mine = null
		state = State.IDLE


func unassign() -> void:
	if mine and mine.worker == self:
		mine.worker = null
	mine = null
	if state == State.WORKING or state == State.TO_MINE:
		_go_home()


func _tick(delta: float) -> void:
	match state:
		State.TO_MINE:
			if not is_instance_valid(mine):
				_go_home()
				return
			if step_path(delta):
				if mine.is_free():
					mine.worker = self
					state = State.WORKING
					visible = false
					_set_moving(false)
					village.events.debug("%s starts work at %s" % [label(), mine.label()])
					village.population.changed.emit()
				else:
					var other: Village = mine.worker.village
					village.events.info("%s found the mine taken by %s and walks home" % [label().capitalize(), "a miner of ours" if other == village else other.village_name])
					village.toast("That mine is taken", UiTheme.BAD)
					mine = null
					_go_home()
		State.WORKING:
			_gold += Config.MINE_GOLD_RATE * delta
			if _gold >= 1.0:
				var n := int(_gold)
				_gold -= n
				village.economy.add("gold", n, "mines")
		State.RETURNING:
			if step_path(delta):
				arrive_home()
				state = State.IDLE
				village.population.changed.emit()


func _go_home() -> void:
	state = State.RETURNING
	visible = true
	head_home()


## Safe inside the mine.
func wants_to_evade() -> bool:
	return state != State.WORKING and state != State.IDLE


func sight_radius() -> float:
	return 0.0 if state == State.WORKING else super.sight_radius()


func _after_evade() -> void:
	# Back home safe: set off for the mine again if he still has one.
	if is_instance_valid(mine) and state == State.TO_MINE:
		assign(mine)
	elif state != State.WORKING:
		state = State.IDLE


func _release_jobs() -> void:
	if mine and mine.worker == self:
		mine.worker = null
	mine = null


func status() -> String:
	if evading:
		return "fleeing from enemies"
	match state:
		State.TO_MINE: return "walking to the mine"
		State.WORKING: return "working the mine"
		State.RETURNING: return "walking home"
	return "idle: send him to a mine"
