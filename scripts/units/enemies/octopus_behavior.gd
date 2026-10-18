class_name OctopusBehavior
extends AquaBehavior
## The gigantic octopus (docs/aquatic-design.md §8): never leaves deep water;
## it moves (slowly, up or under) towards a deep tile from which someone of
## ours is in reach of its arms, else to the one nearest the village. Each of
## its arms reaches for one of ours within arm_range (never two arms on one):
## villagers outside, the hero, units out of their barracks, elementals. A
## hooked one is pulled towards it (Unit.force_move, into deep water too:
## there it drowns; the hero is downed; flyers don't drown), takes
## spell_damage per second and fights the arm (Unit.held_by). While reaching
## or holding, an arm is a target of its own (an "octopus_arm" Enemy, not a
## wave member): at 0 HP it lets go and is gone for arm_respawn s; its HP is
## kept between grapples (no healing). It dives (every arm lets go) for
## dive_time s after losing dive_loss of its max HP within dive_window s, and
## can't dive again for dive_lockout s.

enum Arm { IDLE, REACH, HOLD, GONE }

## One per arm: {"state", "hp", "cd", "node" (the arm Enemy while out),
## "target", "tip" (grid), "respawn"}.
var arms: Array[Dictionary] = []
var _started := false
var _clock := 0.0
var _plan := 0.0
var _hp_log: Array = []
var _sample := 0.0
var _dive_left := 0.0
var _lockout := 0.0


func tick(enemy: Enemy, delta: float) -> bool:
	enemy.self_moved = true
	_clock += delta
	if not _started:
		_start(enemy)
	_sample -= delta
	if _sample <= 0.0:
		_sample = 0.2
		_hp_log.append([_clock, enemy.hp])
	_lockout -= delta
	if _dive_left > 0.0:
		_dive_left -= delta
		if _dive_left <= 0.0:
			enemy.surface()
	_plan -= delta
	if _plan <= 0.0 or _goal.x < 0:
		_plan = 2.0
		_goal = _spot(enemy, enemy.stat("arm_range") - 0.5)
	if _swim(enemy, delta):
		enemy._set_moving(false)
	_tick_arms(enemy, delta)
	return true


func _start(enemy: Enemy) -> void:
	_started = true
	var hp := Config.enemy_stat("octopus_arm", "hp") * enemy.hp_scale
	for i in int(enemy.spec()["arms"]):
		arms.append({"state": Arm.IDLE, "hp": hp, "cd": i * enemy.stat("arm_stagger"), "node": null, "target": null, "tip": enemy.grid_pos, "respawn": 0.0})


func _tick_arms(enemy: Enemy, delta: float) -> void:
	var up := enemy.dive == Enemy.Dive.UP
	var folk: Array[Node] = []
	if up:
		folk = people(enemy.game, true)
	var taken := {}
	for a in arms:
		if a["state"] == Arm.REACH or a["state"] == Arm.HOLD:
			taken[a["target"]] = true
	for p in folk:
		if is_instance_valid(p.held_by):
			taken[p] = true  # (another octopus holds it already)
	var tips: Array = []
	for a in arms:
		match a["state"]:
			Arm.GONE:
				a["respawn"] -= delta
				if a["respawn"] <= 0.0:
					a["state"] = Arm.IDLE
					a["hp"] = Config.enemy_stat("octopus_arm", "hp") * enemy.hp_scale
					a["cd"] = 0.0
					home_village(enemy).events.debug("%s grows its arm back" % enemy.label())
			Arm.IDLE:
				a["cd"] -= delta
				if up and a["cd"] <= 0.0:
					var t := nearest_within(enemy, folk, enemy.stat("arm_range"), taken)
					if t != null:
						taken[t] = true
						_reach(enemy, a, t)
			Arm.REACH:
				var t = a["target"]
				if not up or not reachable(t) or (t.grid_pos as Vector2).distance_to(enemy.grid_pos) > enemy.stat("arm_range") + 1.0:
					_retract(a, enemy.stat("arm_cooldown") * 0.5)
					continue
				var tip: Vector2 = (a["tip"] as Vector2).move_toward(t.grid_pos, enemy.stat("arm_reach_speed") * delta)
				_set_tip(a, tip)
				if tip.distance_to(t.grid_pos) < 0.15:
					a["state"] = Arm.HOLD
					t.held_by = a["node"]
					enemy.game.log_for(t, EventLog.Level.DEBUG, "%s grabs %s" % [enemy.label(), enemy.game.who(t)])
			Arm.HOLD:
				_hold(enemy, a, delta)
		if a["state"] == Arm.REACH or a["state"] == Arm.HOLD:
			tips.append(a["tip"])
	if tips.is_empty():
		enemy.fx.erase("arms")
	else:
		enemy.fx["arms"] = tips


func _reach(enemy: Enemy, a: Dictionary, t: Node) -> void:
	var node: Enemy = load("res://scripts/units/enemy.gd").new()
	node.setup(enemy.game, [enemy.current_tile()] as Array[Vector2i], enemy.hp_scale, "octopus_arm")
	node.max_hp = Config.enemy_stat("octopus_arm", "hp") * enemy.hp_scale
	node.hp = a["hp"]
	node.wave = enemy.wave
	node.target_village = enemy.target_village
	node.set_grid_pos(enemy.grid_pos)
	(node.behavior as ArmBehavior).octopus = enemy
	node.uid = enemy.game.next_id("octopus_arm")
	node.nid = enemy.game.register(node)
	enemy.game.world.objects.add_child(node)
	a["node"] = node
	a["target"] = t
	a["tip"] = enemy.grid_pos
	a["state"] = Arm.REACH


func _set_tip(a: Dictionary, tip: Vector2) -> void:
	a["tip"] = tip
	var node = a["node"]
	if is_instance_valid(node) and not node.dead:
		node.set_grid_pos(tip)


## Holding: the arm's tip stays on its catch, pulls it in, hurts it, and
## drowns it once it is dragged into deep water.
func _hold(enemy: Enemy, a: Dictionary, delta: float) -> void:
	var t = a["target"]
	if not reachable(t):
		_retract(a, enemy.stat("arm_cooldown"))
		return
	var u := t as Unit
	_set_tip(a, u.grid_pos)
	var to := enemy.grid_pos - u.grid_pos
	if to.length() > 0.05:  # (all the way in: under its body is deep water)
		u.force_move(to.normalized() * minf(enemy.stat("arm_pull") * delta, to.length()), enemy, true)
	_set_tip(a, u.grid_pos)
	u.take_damage(enemy.stat("spell_damage") * delta, enemy, "melee")
	if not reachable(t):
		_retract(a, enemy.stat("arm_cooldown"))
		return
	var flies: bool = u.has_method("flies") and u.flies()
	if enemy.game.map.is_deep(u.current_tile()) and not flies:
		_drown(enemy, u)
		_retract(a, enemy.stat("arm_cooldown"))


## Pulled under: a villager or a unit dies (is downed), the hero is downed,
## an elemental crumbles.
func _drown(enemy: Enemy, u: Unit) -> void:
	u.held_by = null
	if u is Hero:
		(u as Hero).take_damage((u as Hero).hp + 1.0, enemy, "pure")
	elif u is Civilian:
		var c := u as Civilian
		c.village.population.kill(c, "drowned, dragged under by %s" % enemy.label(), "enemies")
	elif u is Soldier:
		(u as Soldier).take_damage((u as Soldier).unit.hp + 1.0, enemy, "pure")
	elif u is EarthElemental:
		(u as EarthElemental).crumble()


## The arm lets go and goes back to the body; `cooldown` s before it reaches again.
func _retract(a: Dictionary, cooldown: float) -> void:
	var t = a["target"]
	if is_instance_valid(t) and t.held_by == a["node"]:
		t.held_by = null
	var node = a["node"]
	if is_instance_valid(node):
		if not node.dead:
			a["hp"] = node.hp
		node.dead = true
		node.remove_from_group("enemies")
		node.queue_free()
	a["node"] = null
	a["target"] = null
	a["state"] = Arm.IDLE
	a["cd"] = cooldown


## An arm's HP ran out (ArmBehavior): it lets go and is gone for a while.
func arm_cut(enemy: Enemy, node: Enemy) -> void:
	for a in arms:
		if a["node"] != node:
			continue
		var t = a["target"]
		if is_instance_valid(t) and t.held_by == node:
			t.held_by = null
		a["node"] = null
		a["target"] = null
		a["hp"] = 0.0
		a["state"] = Arm.GONE
		a["respawn"] = enemy.stat("arm_respawn")
		home_village(enemy).events.debug("%s loses an arm" % enemy.label())


func on_hurt(enemy: Enemy) -> void:
	if _lockout > 0.0 or _dive_left > 0.0 or enemy.dive != Enemy.Dive.UP:
		return
	if recent_loss(_hp_log, _clock, enemy.stat("dive_window"), enemy.hp) >= enemy.stat("dive_loss") * enemy.max_hp and enemy.dive_down():
		for a in arms:
			if a["state"] == Arm.REACH or a["state"] == Arm.HOLD:
				_retract(a, enemy.stat("arm_cooldown") * 0.5)
		enemy.fx.erase("arms")
		_dive_left = enemy.stat("dive_time")
		_lockout = _dive_left + enemy.stat("dive_lockout")
		_hp_log.clear()
		home_village(enemy).events.debug("%s dives, letting go of everything" % enemy.label())


func on_death(enemy: Enemy) -> void:
	for a in arms:
		if a["state"] == Arm.REACH or a["state"] == Arm.HOLD:
			_retract(a, 0.0)
	enemy.fx.erase("arms")
