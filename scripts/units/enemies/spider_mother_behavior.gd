class_name SpiderMotherBehavior
extends MeleeBehavior
## Spider mothers (Config.ENEMIES["spider_mother"]): fight like an orc
## (MeleeBehavior) and lay clutches of eggs (Waves.lay_eggs) as she walks,
## without stopping: the first once she is within lay_near of a manned tower or
## barracks whose units fight (or when she is first alarmed), then one every
## lay_every s. Alarmed (a fighter of ours
## within alarm_range or a manned tower with her in range, or she is hurt)
## while fewer than guard_count of her young (spiderlings and eggs) are within
## guard_radius, she stops, lays a clutch and waits until it has hatched or is
## gone, still fighting whoever comes close; then she isn't alarmed again for
## alarm_cooldown s. Raised by a necromancer she lays a clutch at once (then
## every lay_every s). Laying takes no time. She lays at most max_clutches
## clutches (timed and alarmed together; a raised mother counts afresh); then
## she fights on like an orc and no longer stops to guard.

## The clutch she waits for (empty: none).
var clutch: Array[Enemy] = []
## Her first clutch is laid: from then on one every lay_every s (_lay).
var started := false
## Clutches laid so far (at most max_clutches).
var clutches := 0
var _lay := 0.0
var _alarm_cd := 0.0
var _alarm_scan := 0.0
var _hurt := false


func tick(enemy: Enemy, delta: float) -> bool:
	var spec := enemy.spec()
	if enemy.raised:
		started = true  # (raised, she lays at once: _lay starts at 0)
	if started:
		_lay -= delta
	_alarm_cd -= delta
	_alarm_scan -= delta
	var fighting := super.tick(enemy, delta)
	if waiting():
		return true  # (by her clutch, fighting or not)
	clutch.clear()
	if clutches >= int(spec["max_clutches"]):
		return fighting  # (laid out)
	if _alarm_scan <= 0.0 or _hurt:
		_alarm_scan = 0.3
		var alarmed := _hurt or _fighter_near(enemy, float(spec["alarm_range"]))
		_hurt = false
		if alarmed and _alarm_cd <= 0.0 and guards(enemy) < int(spec["guard_count"]):
			started = true
			_alarm_cd = float(spec["alarm_cooldown"])
			_lay = float(spec["lay_every"])
			clutches += 1
			clutch = enemy.game.waves.lay_eggs(enemy)
			enemy.target_village.events.debug("%s stops to lay eggs and guard them" % enemy.label())
			return true
		if not started and post_near(enemy, float(spec["lay_near"])):
			started = true
	if started and _lay <= 0.0:
		_lay = float(spec["lay_every"])
		clutches += 1
		enemy.game.waves.lay_eggs(enemy)
	return fighting


## Still waiting for her clutch: one of its eggs is there and hasn't hatched.
func waiting() -> bool:
	return clutch.any(func(e) -> bool: return is_instance_valid(e) and not (e as Enemy).dead)  # (untyped: an egg may be freed)


func on_damaged(_enemy: Enemy, _source: Node) -> void:
	_hurt = true


func on_death(_enemy: Enemy) -> void:
	clutch.clear()


## A manned tower or barracks of any village within r tiles whose units fight
## (not a Healing Mage's or a High Priest's; training grounds don't count).
static func post_near(enemy: Enemy, r: float) -> bool:
	for b in enemy.game.world.military_posts():
		if not (b is Tower or b is Barracks) or not b.working():
			continue
		var post := b as MilitaryPost
		var c := (b as Tower).act_center() if b is Tower else (b as Barracks).act_center()
		if c.distance_to(enemy.grid_pos) > r:
			continue
		for u in post.units():
			if u.state == MilitaryUnit.State.STATIONED and u.fights():
				return true
	return false


## Her young within guard_radius: living spiderlings and unhatched eggs.
static func guards(enemy: Enemy) -> int:
	var spec := enemy.spec()
	var egg := str(spec["lays"])
	var young := [egg, str(Config.ENEMIES[egg]["hatch_into"])]
	var r := float(spec["guard_radius"])
	var n := 0
	for node in enemy.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.dead and young.has(e.kind) and e.grid_pos.distance_to(enemy.grid_pos) <= r:
			n += 1
	return n
