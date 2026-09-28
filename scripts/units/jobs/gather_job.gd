class_name GatherJob
extends CivilianJob
## Stays in the village until enemies have been killed, then walks out to
## collect "safe" corpses (no living enemy nearby), up to `capacity` per trip,
## and brings them home for gold and a little food.

enum State { RESTING, TO_CORPSE, LOOTING, RETURNING }

var state := State.RESTING
var target: Corpse = null
var carried: Array[String] = []  # enemy kinds
var capacity := Config.GATHERER_CAPACITY
var _timer := 0.0
var _sack: Sprite2D


func _init(p_capacity: int = Config.GATHERER_CAPACITY) -> void:
	capacity = p_capacity


func bind(worker: Civilian) -> void:
	super.bind(worker)
	_sack = Art.sprite("sack")
	_sack.position = Vector2(-9, -28)
	_sack.visible = false
	w.add_child(_sack)


func tick(delta: float) -> void:
	match state:
		State.RESTING:
			w.rest_timer -= delta
			if w.rest_timer > 0.0:
				return
			w.rest_timer = 1.0  # peace-time check once a second
			if _pick_next():
				state = State.TO_CORPSE
		State.TO_CORPSE:
			if not _target_ok():
				_next_or_home()
				return
			if w.step_path(delta):
				state = State.LOOTING
				_timer = Config.GATHERER_LOOT_TIME
		State.LOOTING:
			if not _target_ok():
				_next_or_home()
				return
			_timer -= delta
			w._bob += delta * 12.0
			w.sprite.rotation = sin(w._bob) * 0.15
			if _timer <= 0.0:
				carried.append(target.kind)
				w.game.corpses.remove(target)
				target = null
				w.sprite.rotation = 0.0
				w.on_action("corpse")
				if carried.size() >= capacity:
					_go_home()
				else:
					_next_or_home()
		State.RETURNING:
			if w.step_path(delta):
				_deliver()
				w.arrive_home()
				state = State.RESTING
				w.rest_timer = Config.GATHERER_REST
	_sack.visible = not carried.is_empty() and not w.at_home
	_sack.scale = Vector2.ONE * (0.5 + 0.08 * mini(carried.size(), 6))


## Claims the closest reachable safe corpse and walks there.
func _pick_next() -> bool:
	var options := w.game.corpses.available()
	if options.is_empty():
		return false
	var from := w.current_tile() if not w.at_home else Config.VILLAGE_CENTER
	var dist := w.game.world.pathing.distance_field(from)
	var map := w.game.map
	options.sort_custom(func(a: Corpse, b: Corpse) -> bool:
		return dist[map.index(a.tile())] < dist[map.index(b.tile())])
	for c in options:
		if dist[map.index(c.tile())] >= Pathing.UNREACHABLE:
			continue
		if w.head_out(c.tile()):
			target = c
			c.claimed_by = w
			return true
	return false


func _target_ok() -> bool:
	return is_instance_valid(target) and target.claimed_by == w and w.game.corpses.is_safe(target)


func _release_target() -> void:
	if is_instance_valid(target) and target.claimed_by == w:
		target.claimed_by = null
	target = null


func _next_or_home() -> void:
	_release_target()
	if carried.size() < capacity and _pick_next():
		state = State.TO_CORPSE
	else:
		_go_home()


func _go_home() -> void:
	_release_target()
	state = State.RETURNING
	w.sprite.rotation = 0.0
	w.head_home()


func _deliver() -> void:
	if carried.is_empty():
		return
	var gold := 0
	var food := 0
	for k in carried:
		gold += Config.enemy_stat_int(k, "gold_on_collect")
		food += Config.enemy_stat_int(k, "food_on_collect")
	w.game.economy.add("gold", gold)
	w.game.economy.add("food", food)
	w.float_text("+%d gold  +%d food" % [gold, food], Color("c9a24a"))
	Sfx.play("coin")
	carried.clear()
	_sack.visible = false


func on_evade() -> void:
	_release_target()
	state = State.RETURNING  # keeps what is already in the sack


func after_evade() -> void:
	_deliver()
	state = State.RESTING


func release() -> void:
	_release_target()
	carried.clear()
	_sack.visible = false


func status() -> String:
	match state:
		State.TO_CORPSE: return "fetching a corpse"
		State.LOOTING: return "collecting"
		State.RETURNING: return "carrying %d corpses home" % carried.size()
	return "resting"
