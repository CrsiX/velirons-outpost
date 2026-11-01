class_name VultureBehavior
extends MeleeBehavior
## A vulture (docs/enemies-design.md §15d; Config.VULTURES): flies its own
## way (Pathing.sky_path) to its pack's corpse (VulturePack), lands and eats
## it for eat_time s (a ground target meanwhile), and each finished meal makes
## it stronger (grow, at most max_meals) and may finish the corpse
## (vanish_chance). It fights only for itself and its corpse: on the corpse it
## fights whoever comes into reach, hurt by one of ours in the field it flies
## at that one (no farther than `chase` from its corpse), hurt by a tower it
## flees out of its range for flee_time s. Leaving, it is gone once out of
## every village's sight (or at the map's edge) for hidden_time s. It never
## goes for a gate. Moves itself: tick always holds the enemy.

enum State { FLY, EAT, CHASE, FLEE }

## Its pack (set by Waves when it spawns; a raised or debug one makes its own).
var pack: VulturePack = null
var state := State.FLY
var _base_hp := 0.0
var _base_power := 1.0
var _meal := 0.0
var _meal_on: Corpse = null
var _foe_hit: Node = null
var _chase_from := Vector2.ZERO
var _flee_until := -INF
var _flee_to := Vector2.INF
var _goal := Vector2.INF
var _replan := 0.0
var _search_to := Vector2.INF
var _hidden := 0.0


func tick(enemy: Enemy, delta: float) -> bool:
	enemy.self_moved = true
	if pack == null:
		pack = VulturePack.new(enemy.game, null)
		pack.members.append(enemy)
	if _base_hp <= 0.0:
		_base_hp = enemy.max_hp
		_base_power = enemy.power
	pack.think(delta)
	var vc: Dictionary = Config.VULTURES
	var clock := enemy.game.clock
	if clock < _flee_until:
		if state != State.FLEE:
			_take_off(enemy, State.FLEE)
		if _fly_to(enemy, _flee_to, delta):
			enemy._set_moving(false)
		return true
	if state == State.FLEE:
		state = State.FLY
	if state == State.CHASE:
		if _chasing(enemy, float(vc["chase"])):
			if super.tick(enemy, delta):
				return true
			if _fly_to(enemy, _foe_hit.grid_pos, delta):
				enemy._set_moving(false)
			return true
		state = State.FLY
		note(enemy, "%s stops chasing %s" % [enemy.label(), enemy.game.who(_foe_hit)])
		_foe_hit = null
	if state == State.EAT:
		_eat(enemy, delta)
		return true
	match pack.mode:
		VulturePack.Mode.SEEK:
			var c := pack.target
			var spot := c.grid_pos + _spread(enemy, 0.6)
			if _fly_to(enemy, spot, delta):
				_land(enemy, c)
		VulturePack.Mode.SEARCH:
			if _search_to == Vector2.INF or enemy.grid_pos.distance_to(_search_to) < 0.3:
				_search_to = _search_point(enemy, float(vc["search_spread"]))
			if _fly_to(enemy, _search_to, delta):
				enemy._set_moving(false)
		VulturePack.Mode.LEAVE:
			_leave(enemy, delta, float(vc["hidden_time"]))
	return true


## Out of the air onto corpse `c`: eating from now.
func _land(enemy: Enemy, c: Corpse) -> void:
	state = State.EAT
	_meal = 0.0
	_meal_on = c
	enemy._set_moving(false)
	enemy.set_landed(true)
	enemy.face(c.grid_pos)
	enemy.target_village.events.debug("%s lands on %s" % [enemy.label(), c.label()])


## Back into the air (to `next`), leaving any meal.
func _take_off(enemy: Enemy, next: State) -> void:
	if state == State.EAT:
		_meal_on = null
		_meal = 0.0
	state = next
	_goal = Vector2.INF
	enemy.set_landed(false)


func _eat(enemy: Enemy, delta: float) -> void:
	if not VulturePack.edible(_meal_on):
		_take_off(enemy, State.FLY)  # (gone before the meal was done: nothing for it)
		return
	if super.tick(enemy, delta):
		return  # (it defends its corpse; the meal waits)
	_meal += delta
	if _meal >= float(Config.VULTURES["eat_time"]):
		_meal = 0.0
		finish_meal(enemy, randf())


## A meal done on its corpse: its share (stronger, while under max_meals),
## then the corpse is gone if `roll` < vanish_chance. It goes on eating
## what's left.
func finish_meal(enemy: Enemy, roll: float) -> void:
	var vc: Dictionary = Config.VULTURES
	var c := _meal_on
	if not VulturePack.edible(c):
		return
	if enemy.fed < int(vc["max_meals"]):
		var gain := _base_hp * float(vc["grow"])
		enemy.max_hp += gain
		enemy.hp += gain
		enemy.set_fed(enemy.fed + 1)
		enemy.power = _base_power * (1.0 + float(vc["grow"]) * enemy.fed)
		enemy.queue_redraw()
	var v := enemy.target_village
	if roll < float(vc["vanish_chance"]):
		if c.fallen:
			v.events.important("A vulture has eaten one of the fallen")
		else:
			v.events.debug("%s ate %s" % [enemy.label(), c.label()])
		enemy.game.corpses.remove(c)
	else:
		v.events.debug("%s feeds on %s" % [enemy.label(), c.label()])


## Still going for the one of ours that hurt it?
func _chasing(enemy: Enemy, chase: float) -> bool:
	if not is_instance_valid(_foe_hit) or _foe_hit.dead or _sheltered(_foe_hit):
		return false
	var anchor := pack.target.grid_pos if VulturePack.edible(pack.target) else _chase_from
	return enemy.grid_pos.distance_to(anchor) <= chase + 2.0 and (_foe_hit.grid_pos as Vector2).distance_to(anchor) <= chase


func _leave(enemy: Enemy, delta: float, hidden_time: float) -> void:
	var at_edge := pack.exit == Vector2i(-1, -1) or _fly_to(enemy, Vector2(pack.exit), delta)
	if at_edge:
		enemy._set_moving(false)
	var seen := false
	for v in enemy.game.villages:
		seen = seen or enemy.game.fog.is_watched_by(v.id, enemy.current_tile())
	_hidden = _hidden + delta if at_edge or not seen else 0.0
	if _hidden >= hidden_time:
		enemy.target_village.events.debug("%s flies off" % enemy.label())
		enemy.vanish()


## Flies towards `to` (grid) by the sky, the way planned again now and then.
## True once there.
func _fly_to(enemy: Enemy, to: Vector2, delta: float) -> bool:
	if enemy.grid_pos.distance_to(to) < 0.1:
		return true
	_replan -= delta
	if _goal == Vector2.INF or _goal.distance_to(to) > 0.6 or _replan <= 0.0:
		_goal = to
		_replan = 1.5
		var pts := enemy.game.world.pathing.sky_path(enemy.current_tile(), Vector2i(to.round()))
		if pts.size() > 1:
			pts.remove_at(0)  # (the tile it is on)
		else:
			pts.clear()
		if not pts.is_empty():
			pts.remove_at(pts.size() - 1)
		pts.append(to)
		enemy.follow(pts)
	return enemy.walk_own(delta)


## Its own place round the pack's corpse (so the birds don't stand in one).
func _spread(enemy: Enemy, r: float) -> Vector2:
	var a := 0.8 + pack.index_of(enemy) * TAU / 3.0
	return Vector2(cos(a), sin(a)) * r


## An open tile near the pack's middle to circle over while it searches.
func _search_point(enemy: Enemy, spread: float) -> Vector2:
	var mid := pack.middle()
	for i in 8:
		var p := mid + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		if enemy.game.world.pathing.sky_open(Vector2i(p.round())):
			return p
	return enemy.grid_pos


func on_damaged(enemy: Enemy, source: Node) -> void:
	if not is_instance_valid(source):
		return
	var vc: Dictionary = Config.VULTURES
	if source is Building:  # (a tower: it can't get at it, so it flees)
		var b := source as Building
		var c := (b as Tower).act_center() if b is Tower else Vector2(b.tile)
		var reach := ((b as Tower).range_tiles() if b is Tower else 4.0) + float(vc["flee_margin"])
		var away := enemy.grid_pos - c
		away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
		_flee_to = _open_near(enemy, c + away * reach)
		_flee_until = enemy.game.clock + float(vc["flee_time"])
		if state != State.FLEE:
			enemy.target_village.events.debug("%s flees from %s" % [enemy.label(), b.label()])
		return
	if source.is_in_group("melee_defenders") and state != State.CHASE:
		_foe_hit = source
		_chase_from = enemy.grid_pos
		_take_off(enemy, State.CHASE)
		enemy.target_village.events.debug("%s turns on %s" % [enemy.label(), enemy.game.who(source)])


## The open sky tile nearest `p` (looking a few tiles round), else where it is.
func _open_near(enemy: Enemy, p: Vector2) -> Vector2:
	var pathing := enemy.game.world.pathing
	var t := Vector2i(p.round())
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if pathing.sky_open(t + Vector2i(dx, dy)):
					return Vector2(t + Vector2i(dx, dy))
	return enemy.grid_pos
