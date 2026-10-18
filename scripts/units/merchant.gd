class_name Merchant
extends Civilian
## The merchant (Pell, docs/scenarios-design.md §7.4): lives in a hut like any
## villager and works the trade stall. He walks there and stays by it,
## tending it (the stall is open for trade only then); like anyone outside he
## runs home from enemies, and goes back once he has rested.

enum State { IDLE, TO_STALL, TENDING, RETURNING }

var state := State.IDLE
var stall: Stall = null


func workplace() -> Building:
	return stall


func assign(b: Building) -> void:
	stall = b as Stall
	if at_home and state == State.IDLE:
		rest_timer = 0.5


func unassign() -> void:
	stall = null
	if state == State.TO_STALL or state == State.TENDING:
		_go_home()


## At his stall, open for trade.
func tending() -> bool:
	return state == State.TENDING and not evading


func _tick(delta: float) -> void:
	match state:
		State.IDLE:
			rest_timer -= delta
			if rest_timer > 0.0 or not is_instance_valid(stall) or not stall.working():
				return
			rest_timer = 1.0
			if head_out(stall.work_tile()):
				state = State.TO_STALL
		State.TO_STALL:
			if not is_instance_valid(stall):
				_go_home()
				return
			if step_path(delta):
				state = State.TENDING
				_set_moving(false)
				village.events.debug("%s opens %s" % [label(), stall.label()])
				stall.refresh()
		State.TENDING:
			if not is_instance_valid(stall) or not stall.working():
				_go_home()
		State.RETURNING:
			if step_path(delta):
				arrive_home()
				state = State.IDLE
				rest_timer = Config.EVADE_REST


func _go_home() -> void:
	state = State.RETURNING
	head_home()


## After a load (or anything else that stopped him): home first, then the stall.
func resume_work() -> void:
	_go_home()


func _on_evade() -> void:
	state = State.RETURNING
	if is_instance_valid(stall):
		stall.refresh()


func _after_evade() -> void:
	state = State.IDLE


func _release_jobs() -> void:
	if is_instance_valid(stall) and stall.worker == self:
		stall.worker = null
		stall.refresh()
	stall = null


func status() -> String:
	if evading:
		return "fleeing from enemies"
	match state:
		State.TO_STALL: return "walking to the stall"
		State.TENDING: return "trading at the stall"
		State.RETURNING: return "walking home"
	return "resting" if is_instance_valid(stall) else "no stall to tend"
