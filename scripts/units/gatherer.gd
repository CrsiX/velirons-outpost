class_name Gatherer
extends Civilian
## Stays in the village until enemies have been killed, then walks out to
## collect "safe" corpses (no living enemy nearby), up to GATHERER_CAPACITY per
## trip, and brings them home for gold and a little food.

enum State { RESTING, TO_CORPSE, LOOTING, RETURNING }

var state := State.RESTING
var target: Corpse = null
var carried: Array[String] = []  # enemy kinds
var _timer := 0.0
var _sack: Sprite2D


func setup(p_game: Game, p_role: String) -> void:
	super.setup(p_game, p_role)
	_sack = Art.sprite("sack")
	_sack.position = Vector2(-9, -28)
	_sack.visible = false
	add_child(_sack)


func _tick(delta: float) -> void:
	match state:
		State.RESTING:
			rest_timer -= delta
			if rest_timer > 0.0:
				return
			rest_timer = 1.0  # peace-time check once a second
			if _pick_next():
				state = State.TO_CORPSE
		State.TO_CORPSE:
			if not _target_ok():
				_next_or_home()
				return
			if step_path(delta):
				state = State.LOOTING
				_timer = Config.GATHERER_LOOT_TIME
		State.LOOTING:
			if not _target_ok():
				_next_or_home()
				return
			_timer -= delta
			_bob += delta * 12.0
			sprite.rotation = sin(_bob) * 0.15
			if _timer <= 0.0:
				carried.append(target.kind)
				game.corpses.remove(target)
				target = null
				sprite.rotation = 0.0
				if carried.size() >= Config.GATHERER_CAPACITY:
					_go_home()
				else:
					_next_or_home()
		State.RETURNING:
			if step_path(delta):
				_deliver()
				arrive_home()
				state = State.RESTING
				rest_timer = Config.GATHERER_REST
	_sack.visible = not carried.is_empty() and not at_home
	_sack.scale = Vector2.ONE * (0.5 + 0.08 * mini(carried.size(), 6))


## Claims the closest reachable safe corpse and walks there.
func _pick_next() -> bool:
	var options := game.corpses.available()
	if options.is_empty():
		return false
	var from := current_tile() if not at_home else Config.VILLAGE_CENTER
	var dist := game.world.pathing.distance_field(from)
	options.sort_custom(func(a: Corpse, b: Corpse) -> bool:
		return dist[game.map.index(a.tile())] < dist[game.map.index(b.tile())])
	for c in options:
		if dist[game.map.index(c.tile())] >= Pathing.UNREACHABLE:
			continue
		if head_out(c.tile()):
			target = c
			c.claimed_by = self
			return true
	return false


func _target_ok() -> bool:
	return is_instance_valid(target) and target.claimed_by == self and game.corpses.is_safe(target)


func _release_target() -> void:
	if is_instance_valid(target) and target.claimed_by == self:
		target.claimed_by = null
	target = null


func _next_or_home() -> void:
	_release_target()
	if carried.size() < Config.GATHERER_CAPACITY and _pick_next():
		state = State.TO_CORPSE
	else:
		_go_home()


func _go_home() -> void:
	_release_target()
	state = State.RETURNING
	sprite.rotation = 0.0
	head_home()


func _deliver() -> void:
	if carried.is_empty():
		return
	var gold := 0
	var food := 0
	for k in carried:
		gold += Config.enemy_stat_int(k, "gold_on_collect")
		food += Config.enemy_stat_int(k, "food_on_collect")
	game.economy.add("gold", gold)
	game.economy.add("food", food)
	float_text("+%d gold  +%d food" % [gold, food], Color("c9a24a"))
	Sfx.play("coin")
	carried.clear()
	_sack.visible = false


func _on_evade() -> void:
	_release_target()
	state = State.RETURNING  # keeps what is already in the sack


func _after_evade() -> void:
	_deliver()
	state = State.RESTING


func status() -> String:
	if evading:
		return "fleeing from goblins"
	match state:
		State.TO_CORPSE: return "fetching a corpse"
		State.LOOTING: return "collecting"
		State.RETURNING: return "carrying %d corpses home" % carried.size()
	return "resting"


func _release_jobs() -> void:
	_release_target()
	carried.clear()
