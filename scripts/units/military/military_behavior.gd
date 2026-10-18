class_name MilitaryBehavior
extends RefCounted
## What a military unit does at its post. One instance per unit, so a behavior
## can keep its own state (cooldowns, summons, ...).
##
## The "post" is whatever the unit acts from: a Tower (tower range, can't be
## hurt) or, out on a barracks sortie, the unit's own body (Soldier; own
## range). Both offer: game, village, act_center() (grid), act_range(),
## sight_radius(), face(grid), recoil(), muzzle_position(), outer_tile(), label().
## Melee units (barracks only) use this base: their fighting is the Soldier's.


## Called every frame while the unit is at work.
func tick(_post: Node, _unit: MilitaryUnit, _delta: float) -> void:
	pass


## Called when the unit stops (withdrawn, back on its bench, downed, its tower lost).
func on_leave(_post: Node, _unit: MilitaryUnit) -> void:
	pass


## Stat lines for panels and the army tab.
func info_lines(unit: MilitaryUnit) -> Array[String]:
	var out: Array[String] = []
	if unit.has_stat("damage"):
		out.append("Damage %.0f, every %.2f s" % [unit.stat("damage"), unit.stat("cooldown")])
	if unit.has_stat("cry"):
		out.append("War cry every %.0f s: allies within %.1f tiles +%d%% attack speed for %.1f s" % [unit.spec()["cry_interval"], unit.spec()["cry_radius"], roundi(100.0 * unit.stat("cry")), unit.stat("cry_time")])
	if unit.has_stat("rage"):
		out.append("Rage: up to %.1fx as fast near 0 HP" % (1.0 / maxf(1.0 - unit.stat("rage"), 0.05)))
		out.append("Below %d%% HP it heals %d%% of the damage it deals" % [roundi(100.0 * float(unit.spec()["lifesteal_below"])), roundi(100.0 * unit.stat("lifesteal"))])
	if unit.role() == "melee" and unit.hits_flyers():
		out.append("Reaches flyers (reach %.1f tiles)" % unit.field_range())
	return out


## Enemies within `radius` tiles of the post that can be hit (not under
## water), closest to their gate first; low-priority ones (spider eggs) last.
static func enemies_near(post: Node, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var c: Vector2 = post.act_center()
	for node in post.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.targetable() and e.grid_pos.distance_to(c) <= radius:
			out.append(e)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		if a.low_priority() != b.low_priority():
			return b.low_priority()
		return a.remaining() < b.remaining())
	return out
