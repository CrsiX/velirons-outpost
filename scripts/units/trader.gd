class_name Trader
extends Civilian
## The trader (docs/market-design.md §3): one per village, lives in a hut and
## works at the marketplace (Config.CIVILIANS "trader", works_at "market").
## He walks there and stays by it, packing what the village put up for sale
## into loads for the trade caravans (Market._pack: only while he tends it).
## Without a market he idles at home; like anyone outside he runs home from
## enemies, and goes back once he has rested.

enum State { IDLE, TO_MARKET, TENDING, RETURNING }

var state := State.IDLE
var market: Market = null


func workplace() -> Building:
	return market


func assign(b: Building) -> void:
	market = b as Market
	if at_home and state == State.IDLE:
		rest_timer = 0.5


func unassign() -> void:
	market = null
	if state == State.TO_MARKET or state == State.TENDING:
		_go_home()


## At his market, packing.
func tending() -> bool:
	return state == State.TENDING and not evading


func _tick(delta: float) -> void:
	match state:
		State.IDLE:
			rest_timer -= delta
			if rest_timer > 0.0 or not is_instance_valid(market) or not market.working():
				return
			rest_timer = 1.0
			if head_out(market.work_tile()):
				state = State.TO_MARKET
		State.TO_MARKET:
			if not is_instance_valid(market):
				_go_home()
				return
			if step_path(delta):
				state = State.TENDING
				_set_moving(false)
				village.events.debug("%s opens %s" % [label(), market.label()])
		State.TENDING:
			if not is_instance_valid(market) or not market.working():
				_go_home()
		State.RETURNING:
			if step_path(delta):
				arrive_home()
				state = State.IDLE
				rest_timer = Config.EVADE_REST


func _go_home() -> void:
	state = State.RETURNING
	head_home()


## After a load (or anything else that stopped him): home first, then the market.
func resume_work() -> void:
	_go_home()


func _on_evade() -> void:
	state = State.RETURNING


func _after_evade() -> void:
	state = State.IDLE


func _release_jobs() -> void:
	if is_instance_valid(market) and market.worker == self:
		market.worker = null
		market.refresh()
	market = null


func status() -> String:
	if evading:
		return "fleeing from enemies"
	match state:
		State.TO_MARKET: return "walking to the marketplace"
		State.TENDING: return "packing goods at the marketplace"
		State.RETURNING: return "walking home"
	return "resting" if is_instance_valid(market) else "no marketplace to work at"
