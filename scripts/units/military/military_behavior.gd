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
	return out


## Enemies within `radius` tiles of the post, closest to their gate first.
static func enemies_near(post: Node, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var c: Vector2 = post.act_center()
	for node in post.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.dead and e.grid_pos.distance_to(c) <= radius:
			out.append(e)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.remaining() < b.remaining())
	return out
