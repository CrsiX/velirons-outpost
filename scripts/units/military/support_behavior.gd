class_name SupportBehavior
extends MilitaryBehavior
## High Priest (docs/acolyte-design.md §6): no attack of its own. Its aura
## (Combat.holy_auras) blesses allies around it: on a tower as far as the
## tower reaches, out of the barracks on a sortie within its own range. When
## hit in melee it strikes back (Soldier.take_damage).


## How far its aura reaches from `post`: a tower's range, else its own range.
static func aura_radius(post: Node, unit: MilitaryUnit) -> float:
	return (post as Tower).act_range() if post is Tower else unit.field_range()


func info_lines(unit: MilitaryUnit) -> Array[String]:
	var where := " (the tower's range)" if unit.post is Tower else " (out of the barracks)"
	return [
		"Allies within %.1f tiles%s deal +%d%% damage" % [aura_radius(unit.post, unit), where, roundi(100.0 * unit.stat("aura"))],
		"Necromancers raise %s x slower near it" % str(unit.spec()["necro_slow"]),
		"Counter-strike when hit: %.0f damage" % unit.stat("damage"),
	]
