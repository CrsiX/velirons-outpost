class_name Farmer
extends Civilian
## Works exactly one farm (assigned by the player): walk out, harvest the
## stored food, carry it home, rest, repeat.

enum State { RESTING, TO_FARM, HARVESTING, RETURNING }

var state := State.RESTING
var farm: Farm = null
var carrying := 0
var _sack: Sprite2D
var _timer := 0.0


func setup(p_game: Game, p_role: String) -> void:
	super.setup(p_game, p_role)
	_sack = Art.sprite("sack")
	_sack.position = Vector2(-8, -30)
	_sack.visible = false
	add_child(_sack)


func assign(p_farm: Farm) -> void:
	farm = p_farm


func unassign() -> void:
	farm = null


func _tick(delta: float) -> void:
	match state:
		State.RESTING:
			rest_timer -= delta
			if rest_timer > 0.0 or farm == null:
				return
			rest_timer = 1.0
			if head_out(farm.work_tile()):
				state = State.TO_FARM
		State.TO_FARM:
			if not is_instance_valid(farm):
				_go_home()
				return
			if step_path(delta):
				state = State.HARVESTING
				_timer = Config.HARVEST_TIME
		State.HARVESTING:
			if not is_instance_valid(farm):
				_go_home()
				return
			_timer -= delta
			_bob += delta * 8.0
			sprite.rotation = sin(_bob) * 0.12
			if _timer <= 0.0:
				carrying = farm.take_food()
				_go_home()
		State.RETURNING:
			if step_path(delta):
				_deliver()
				arrive_home()
				state = State.RESTING
				rest_timer = Config.FARMER_REST
	_sack.visible = carrying > 0 and not at_home


func _on_evade() -> void:
	state = State.RETURNING  # keeps whatever food is being carried


func _after_evade() -> void:
	_deliver()
	state = State.RESTING


func _deliver() -> void:
	if carrying > 0:
		game.economy.add("food", carrying)
		float_text("+%d food" % carrying, Color("e0b070"))
	carrying = 0
	_sack.visible = false


func _go_home() -> void:
	state = State.RETURNING
	sprite.rotation = 0.0
	head_home()


func status() -> String:
	if farm == null:
		return "no farm assigned"
	match state:
		State.TO_FARM: return "walking to the farm"
		State.HARVESTING: return "harvesting"
		State.RETURNING: return "carrying food home"
	return "resting"


func _release_jobs() -> void:
	if is_instance_valid(farm) and farm.farmer == self:
		farm.farmer = null
		farm.refresh()
	farm = null
