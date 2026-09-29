class_name SummonerBehavior
extends MilitaryBehavior
## Summons elementals (earth or fire, Config.SUMMONS; the unit's "summon")
## next to its post while enemies are within the post's range or sight: a tower,
## or the summoner itself standing outside its barracks. Level-ups speed up
## summoning, raise the cap and make *newly* summoned elementals stronger
## (existing ones keep their stats). The summoner has no attack of its own.

const ELEMENTAL_SCRIPT := preload("res://scripts/units/earth_elemental.gd")

var summons: Array[EarthElemental] = []
var _timer := 1.0


func tick(post: Node, unit: MilitaryUnit, delta: float) -> void:
	_prune()
	_timer -= delta
	if _timer > 0.0:
		return
	if summons.size() >= roundi(unit.stat("max_summons")):
		return
	var sight := maxf(post.act_range(), post.sight_radius())
	var threats := enemies_near(post, sight)
	if threats.is_empty():
		return
	_timer = unit.stat("interval")
	post.face(threats[0].grid_pos)
	var kind: String = unit.spec().get("summon", "earth")
	var sm: Dictionary = Config.SUMMONS[kind]
	var e: EarthElemental = ELEMENTAL_SCRIPT.new()
	e.village = post.village
	var home := Vector2i(Vector2(post.act_center()).round())
	e.setup(post.game, home, post.outer_tile(), unit.stat("summon_hp") * sm["hp"], unit.stat("summon_damage") * sm["damage"], kind)
	e.uid = post.game.next_id("elemental")
	e.nid = post.game.register(e)
	post.village.events.debug("summoned %s by %s on %s" % [e.label(), unit.label(), post.label()])
	post.game.world.objects.add_child(e)
	summons.append(e)
	post.recoil()
	Sfx.play("recruit", 0.2)


## Drops dead or freed elementals. The lambda parameter is deliberately
## untyped: a freed object can't be passed as an EarthElemental, which would
## make filter() fail (this happened when summons died while the tower was
## bewitched and not ticking).
func _prune() -> void:
	summons = summons.filter(func(s) -> bool: return is_instance_valid(s) and not s.dead)


func on_leave(post: Node, unit: MilitaryUnit) -> void:
	# Without their summoner the elementals crumble back into the earth.
	for s in summons:
		if is_instance_valid(s) and not s.dead:
			if post and is_instance_valid(post):
				post.village.events.debug("%s crumbles: %s left %s" % [s.label(), unit.label(), post.label()])
			s.crumble()
	summons.clear()
	_timer = 1.0


func info_lines(unit: MilitaryUnit) -> Array[String]:
	_prune()
	var sm: Dictionary = Config.SUMMONS[unit.spec().get("summon", "earth")]
	return [
		"Summons every %.1f s, up to %d at once (%d active)" % [unit.stat("interval"), roundi(unit.stat("max_summons")), summons.size()],
		"New %ss: %.0f hp, %.0f damage" % [str(sm["name"]).to_lower(), unit.stat("summon_hp") * sm["hp"], unit.stat("summon_damage") * sm["damage"]],
	]
