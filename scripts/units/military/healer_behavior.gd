class_name HealerBehavior
extends MilitaryBehavior
## Healing mage: no damage. Every `cooldown` seconds, if anyone around needs
## it, heals every allied unit outside (of any village) and every hero within
## `radius` tiles by `heal` HP (summons are not healed).

var _cooldown := 0.5


func tick(post: Node, unit: MilitaryUnit, delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if Combat.heal_around(post.game, post.act_center(), unit.stat("radius"), unit.stat("heal")) > 0:
		_cooldown = unit.stat("cooldown")
		post.recoil()
	else:
		_cooldown = 0.3  # nobody hurt: look again soon


func info_lines(unit: MilitaryUnit) -> Array[String]:
	return ["Heals %.0f HP to allies within %.1f tiles, every %.1f s" % [unit.stat("heal"), unit.stat("radius"), unit.stat("cooldown")]]
