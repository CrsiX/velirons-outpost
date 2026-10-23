class_name Resident
extends Civilian
## A campaign villager who stays in their hut and never goes out ("stays_home"
## in Config.CIVILIANS: what they do there): Wenna the guild master, Anselm the
## priest, Fiona (docs/scenarios-design.md §7.7, §7.10). Safe while the hut
## stands; they die with it. None can be recruited.
##
## A scenario may give one rounds instead (Anselm, scenario 6): stops out in
## the field, walked one after the other, home between them; like anyone
## outside they run home from enemies, and go on once they have rested.

enum State { HOME, OUT, STAYING, RETURNING }

## The rounds: [{"tile": Vector2i, "doing": "praying at the chapel"}]; none: stays home.
var rounds: Array[Dictionary] = []
## Seconds spent at each stop, and at home between rounds.
var stay := 8.0
## Where they go in and come out ((-1, -1): the village centre, as everyone;
## scenario 9's priests: their church's door).
var home_tile := Vector2i(-1, -1)
var state := State.HOME
var _stop := 0
var _left := 0.0


func _tick(delta: float) -> void:
	if rounds.is_empty():
		return
	match state:
		State.HOME:
			rest_timer -= delta
			if rest_timer > 0.0:
				return
			rest_timer = 1.0
			_go_on(0)
		State.OUT:
			if step_path(delta):
				state = State.STAYING
				_set_moving(false)
				_left = stay
		State.STAYING:
			_left -= delta
			if _left <= 0.0:
				_go_on(_stop + 1)
		State.RETURNING:
			if step_path(delta):
				arrive_home()
				state = State.HOME
				rest_timer = stay


func home_spot() -> Vector2i:
	return home_tile if home_tile.x >= 0 else village.center


## New rounds (`list`), begun at once from wherever they are (at home, out,
## between stops), with `stay` seconds at each stop.
func start_rounds(list: Array[Dictionary], p_stay: float) -> void:
	rounds = list
	stay = p_stay
	rest_timer = 0.0
	if not evading:
		_go_on(0)


## On to stop `i`; past the last one, home.
func _go_on(i: int) -> void:
	_stop = i
	if i >= rounds.size():
		state = State.RETURNING
		head_home()
		return
	if head_out(rounds[i]["tile"]):
		state = State.OUT
	else:
		_go_on(i + 1)


func resume_work() -> void:
	if rounds.is_empty():
		return
	state = State.RETURNING
	head_home()


func _on_evade() -> void:
	state = State.RETURNING


func _after_evade() -> void:
	state = State.HOME


func status() -> String:
	if evading:
		return "fleeing from enemies"
	if not rounds.is_empty() and _stop < rounds.size():
		match state:
			State.OUT: return "walking to %s" % rounds[_stop].get("to", "pray")
			State.STAYING: return str(rounds[_stop].get("doing", "praying"))
	if state == State.RETURNING:
		return "walking home"
	return str(Config.CIVILIANS[role].get("stays_home", "at home"))
