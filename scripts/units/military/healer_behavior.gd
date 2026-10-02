class_name HealerBehavior
extends MilitaryBehavior
## Healing mage: no damage. Every `cooldown` seconds, if anyone around needs
## it, heals every allied unit outside (of any village) and every hero within
## reach by `heal` HP (summons are not healed). Reach: in a tower, the tower's
## range (so tower upgrades widen it); elsewhere its own `radius`.

var _cooldown := 0.5


func tick(post: Node, unit: MilitaryUnit, delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if Combat.heal_around(post.game, post.act_center(), heal_radius(post, unit), unit.stat("heal")) > 0:
		_cooldown = unit.stat("cooldown")
		post.recoil()
	else:
		_cooldown = 0.3  # nobody hurt: look again soon


## How far it heals from `post`: a tower's range, else its own radius.
static func heal_radius(post: Node, unit: MilitaryUnit) -> float:
	return (post as Tower).act_range() if post is Tower else unit.stat("radius")


func info_lines(unit: MilitaryUnit) -> Array[String]:
	var where := " (the tower's range)" if unit.post is Tower else ""
	return ["Heals %.0f HP to allies within %.1f tiles%s, every %.1f s" % [unit.stat("heal"), heal_radius(unit.post, unit), where, unit.stat("cooldown")]]
