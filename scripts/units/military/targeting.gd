class_name Targeting
extends RefCounted
## Which enemy a unit goes for first (docs/advancements-design.md §5). The
## default for everyone is the one nearest the village centre
## (Enemy.remaining). A village with Better targeting gives every tower's unit
## (and its elementals) the rule of its kind (Config.TARGETING_BETTER); with
## Manual targeting every tower has a switch (Tower.targeting) its unit and its
## elementals follow. Barracks sorties keep the default. Scenario overrides (an
## octopus's arm holding one of ours) and spider eggs last stay above any rule
## (MilitaryBehavior.enemies_near).


## The rule for a unit or summon of `kind` acting from `post` (a Tower, or a
## Soldier out of its barracks; null: none).
static func rule(v: Village, post: Node, kind: String) -> String:
	if v == null or not (post is Tower):
		return "default"
	match v.targeting():
		"manual":
			return (post as Tower).targeting
		"better":
			return str(Config.TARGETING_BETTER.get(kind, "default"))
	return "default"


## Sort keys of `foes` by `rule` (lower goes first; ties: nearest the centre):
## enemy instance id -> key.
static func keys(rule: String, foes: Array) -> Dictionary:
	var out := {}
	if rule == "default":
		return out
	var r := float(Config.TARGETING_GROUP_RADIUS)
	for node in foes:
		var e := node as Enemy
		var k := 0.0
		match rule:
			"weakest":
				k = e.hp + e.mount_hp
			"strongest":
				k = -(e.hp + e.mount_hp)
			"fastest":
				k = -e.speed
			"group":
				for other in foes:
					if other != e and (other as Enemy).grid_pos.distance_to(e.grid_pos) <= r:
						k -= 1.0
			"pushable":
				k = 0.0 if e.can_be_pushed() else 1.0
			"unholy":
				k = 0.0 if e.is_unholy() else 1.0
			"support":
				k = 0.0 if e.spec().get("support", false) else 1.0
		out[e.get_instance_id()] = k
	return out
