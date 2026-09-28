class_name SummonerBehavior
extends MilitaryBehavior
## Summons earth elementals next to its tower while enemies are within the
## tower's range or sight. Level-ups speed up summoning, raise the cap and make
## *newly* summoned elementals stronger (existing ones keep their stats).

const ELEMENTAL_SCRIPT := preload("res://scripts/units/earth_elemental.gd")

var summons: Array[EarthElemental] = []
var _timer := 1.0


func tick(tower: Tower, unit: MilitaryUnit, delta: float) -> void:
	_prune()
	_timer -= delta
	if _timer > 0.0:
		return
	if summons.size() >= int(unit.stat("max_summons")):
		return
	var sight := maxf(tower.range_tiles(), tower.sight_radius())
	var threats := enemies_near(tower, sight)
	if threats.is_empty():
		return
	_timer = unit.stat("interval")
	tower.face(threats[0].grid_pos)
	var e: EarthElemental = ELEMENTAL_SCRIPT.new()
	e.setup(tower.game, tower.tile, tower.outer_tile(), unit.stat("summon_hp"), unit.stat("summon_damage"))
	e.uid = tower.game.next_id("elemental")
	tower.game.events.debug("summoned %s by %s on %s" % [e.label(), unit.label(), tower.label()])
	tower.game.world.objects.add_child(e)
	summons.append(e)
	tower.recoil()
	Sfx.play("recruit", 0.2)


## Drops dead or freed elementals. The lambda parameter is deliberately
## untyped: a freed object can't be passed as an EarthElemental, which would
## make filter() fail (this happened when summons died while the tower was
## bewitched and not ticking).
func _prune() -> void:
	summons = summons.filter(func(s) -> bool: return is_instance_valid(s) and not s.dead)


func on_leave(tower: Tower, unit: MilitaryUnit) -> void:
	# Without their summoner the elementals crumble back into the earth.
	for s in summons:
		if is_instance_valid(s) and not s.dead:
			tower.game.events.debug("%s crumbles: %s left %s" % [s.label(), unit.label(), tower.label()])
			s.crumble()
	summons.clear()
	_timer = 1.0


func info_lines(unit: MilitaryUnit) -> Array[String]:
	_prune()
	var alive := summons.size()
	return [
		"Summons every %.1f s, up to %d at once (%d active)" % [unit.stat("interval"), int(unit.stat("max_summons")), alive],
		"New elementals: %.0f hp, %.0f damage" % [unit.stat("summon_hp"), unit.stat("summon_damage")],
	]
