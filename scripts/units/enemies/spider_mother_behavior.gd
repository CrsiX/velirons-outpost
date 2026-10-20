class_name SpiderMotherBehavior
extends MeleeBehavior
## Spider mothers (Config.ENEMIES["spider_mother"]): fight like an ork
## (MeleeBehavior) and lay clutches of eggs (Waves.lay_eggs) as she walks,
## without stopping: the first first_lay s after she comes onto the map, then
## one every lay_every s. Alarmed (a fighter of ours
## within alarm_range or a manned tower with her in range, or she is hurt)
## while fewer than guard_count of her young (spiderlings and eggs) are within
## guard_radius, she stops, lays a clutch and waits until it has hatched or is
## gone, still fighting whoever comes close; then she isn't alarmed again for
## alarm_cooldown s. Raised by a necromancer she lays a clutch at once (then
## every lay_every s). Laying takes no time.

## The clutch she waits for (empty: none).
var clutch: Array[Enemy] = []
var _lay := -1.0
var _alarm_cd := 0.0
var _alarm_scan := 0.0
var _hurt := false


func tick(enemy: Enemy, delta: float) -> bool:
	var spec := enemy.spec()
	if _lay < 0.0:
		_lay = 0.0 if enemy.raised else float(spec["first_lay"])
	_lay -= delta
	_alarm_cd -= delta
	_alarm_scan -= delta
	var fighting := super.tick(enemy, delta)
	if waiting():
		return true  # (by her clutch, fighting or not)
	clutch.clear()
	if _alarm_scan <= 0.0 or _hurt:
		_alarm_scan = 0.3
		var alarmed := _hurt or _fighter_near(enemy, float(spec["alarm_range"]))
		_hurt = false
		if alarmed and _alarm_cd <= 0.0 and guards(enemy) < int(spec["guard_count"]):
			_alarm_cd = float(spec["alarm_cooldown"])
			_lay = float(spec["lay_every"])
			clutch = enemy.game.waves.lay_eggs(enemy)
			enemy.target_village.events.debug("%s stops to lay eggs and guard them" % enemy.label())
			return true
	if _lay <= 0.0:
		_lay = float(spec["lay_every"])
		enemy.game.waves.lay_eggs(enemy)
	return fighting


## Still waiting for her clutch: one of its eggs is there and hasn't hatched.
func waiting() -> bool:
	return clutch.any(func(e: Enemy) -> bool: return is_instance_valid(e) and not e.dead)


func on_damaged(_enemy: Enemy, _source: Node) -> void:
	_hurt = true


func on_death(_enemy: Enemy) -> void:
	clutch.clear()


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
