class_name RangedBehavior
extends MilitaryBehavior
## Archers, crossbowmen, swiftbowmen and the damage-dealing mages: shoots the
## enemy in range that is closest to reaching its gate, with the unit's attack
## (Config.ATTACKS: arrows, bolts, orbs, fireballs, frost, warp).

var _cooldown := 0.3


func tick(post: Node, unit: MilitaryUnit, delta: float) -> void:
	_cooldown -= delta
	var targets := enemies_near(post, post.act_range())
	if targets.is_empty():
		return
	var target := targets[0]
	post.face(target.grid_pos)
	if _cooldown <= 0.0:
		_cooldown = unit.stat("cooldown")
		Combat.attack(post.game, unit, post.muzzle_position(), target, post)
		post.recoil()


func info_lines(unit: MilitaryUnit) -> Array[String]:
	var out := super.info_lines(unit)
	if unit.has_stat("splash"):
		out.append("Explodes: %d%% damage to others within %.1f tiles" % [roundi(100.0 * Config.ATTACKS[unit.spec()["attack"]]["splash_share"]), unit.stat("splash")])
	if unit.has_stat("slow"):
		out.append("Slows the enemy hit to %d%% speed for %.1f s" % [roundi(100.0 * unit.stat("slow")), unit.stat("slow_time")])
	if unit.has_stat("push"):
		out.append("Throws the enemy hit %.1f tiles back" % unit.stat("push"))
	out.append("Own range (outside): %.1f tiles" % unit.field_range())
	return out
