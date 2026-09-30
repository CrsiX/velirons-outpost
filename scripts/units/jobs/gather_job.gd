class_name GatherJob
extends CivilianJob
## Stays in the village until enemies have been killed, then walks out to
## collect "safe" corpses (no living enemy nearby) on land its village has
## explored, up to `capacity` per trip,
## and brings them home for gold and a little food. Loot a downed hero dropped
## (a sack) is picked up first, and paid out at home like his loot.

enum State { RESTING, TO_CORPSE, LOOTING, RETURNING }

var state := State.RESTING
var target: Corpse = null
var carried: Array[String] = []  # enemy kinds
## Stolen gold found on thieves' corpses, carried with them.
var carried_gold := 0
## A dropped-loot sack on the way to / being picked up, and loot carried.
var sack: Treasure = null
var loot: Dictionary = {}
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
			if sack != null:
				if not _sack_ok():
					_next_or_home()
					return
				if w.step_path(delta):
					state = State.LOOTING
					_timer = sack.loot_time()
				return
			if not _target_ok():
				_next_or_home()
				return
			if w.step_path(delta):
				state = State.LOOTING
				_timer = Config.GATHERER_LOOT_TIME
		State.LOOTING:
			if sack != null:
				if not _sack_ok():
					_next_or_home()
					return
				_timer -= delta
				if _timer <= 0.0:
					for k in sack.reward():
						loot[k] = sack.reward()[k] if k == "relic" else int(loot.get(k, 0)) + int(sack.reward()[k])
					w.village.events.info("%s picked up the dropped loot" % w.label().capitalize())
					sack.mark_looted()
					sack = null
					_go_home()
				return
			if not _target_ok():
				_next_or_home()
				return
			_timer -= delta
			w._bob += delta * 12.0
			w.sprite.rotation = sin(w._bob) * 0.15
			if _timer <= 0.0:
				carried.append(target.kind)
				carried_gold += target.extra_gold
				w.village.events.debug("%s collected %s" % [w.label(), target.label()])
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
	_sack.visible = (not carried.is_empty() or not loot.is_empty()) and not w.at_home
	_sack.scale = Vector2.ONE * (0.5 + 0.08 * mini(carried.size(), 6))


## Claims the closest reachable safe corpse and walks there. Dropped loot
## (sacks) first.
func _pick_next() -> bool:
	if _pick_sack():
		return true
	# (only corpses on land its village has explored: none in the black fog)
	var vid := w.village.id
	var options := w.game.corpses.available().filter(func(c: Corpse) -> bool: return w.game.fog.is_explored_by(vid, c.tile()))
	if options.is_empty():
		return false
	var from := w.current_tile() if not w.at_home else w.village.center
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


func _pick_sack() -> bool:
	if not loot.is_empty():
		return false  # (one sack per trip)
	for o in w.game.world.map_objects:
		var t := o as Treasure
		if t == null or not t.data.get("sack", false) or not t.lootable() or not t.is_found_by(w.village):
			continue
		if not _safe_at(t.tile):
			continue
		if w.head_out(t.visit_tile()):
			sack = t
			t.claimed_by = w
			return true
	return false


func _sack_ok() -> bool:
	return is_instance_valid(sack) and not sack.looted and sack.claimed_by == w and _safe_at(sack.tile)


func _safe_at(t: Vector2i) -> bool:
	for node in w.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.dead and e.grid_pos.distance_to(Vector2(t)) < Config.CORPSE_SAFE_RADIUS:
			return false
	return true


func _target_ok() -> bool:
	return is_instance_valid(target) and target.claimed_by == w and w.game.corpses.is_safe(target)


func _release_target() -> void:
	if is_instance_valid(target) and target.claimed_by == w:
		target.claimed_by = null
	target = null
	if is_instance_valid(sack) and sack.claimed_by == w:
		sack.claimed_by = null
	sack = null


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
	if not loot.is_empty():
		var what := Treasure.pay(w.village, loot)
		loot = {}
		if what != "":
			w.float_text(what, UiTheme.GOLD)
	if carried.is_empty():
		return
	var gold := carried_gold
	var food := 0
	carried_gold = 0
	for k in carried:
		gold += Config.enemy_stat_int(k, "gold_on_collect")
		food += Config.enemy_stat_int(k, "food_on_collect")
	w.village.economy.add("gold", gold)
	w.village.economy.add("food", food)
	w.village.events.debug("%s brings %d corpse%s home: +%d gold, +%d food" % [w.label(), carried.size(), "" if carried.size() == 1 else "s", gold, food])
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
	carried_gold = 0
	loot = {}
	_sack.visible = false


func status() -> String:
	match state:
		State.TO_CORPSE: return "fetching dropped loot" if sack != null else "fetching a corpse"
		State.LOOTING: return "collecting"
		State.RETURNING: return "carrying %d corpses home" % carried.size()
	return "resting"
