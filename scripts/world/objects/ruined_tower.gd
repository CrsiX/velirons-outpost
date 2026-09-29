class_name RuinedTower
extends MapObject
## A ruined watchtower (docs/world-design.md §9.5). The explorer (or anyone)
## can find it; only a hero can claim it (Explore mode goes for it before new
## land), first come first served, in any slice. The claiming village then
## owns the ruin; restoring it is an explicit order ("Restore (half cost)")
## that a builder carries out like any building site. Then it's a watchtower.

## The hero on his way to claim it.
var claimed_by: Node = null


func art() -> String:
	return "watchtower_ruin"


func display_name() -> String:
	return "Ruined watchtower"


func claimable() -> bool:
	return village == null and (claimed_by == null or not is_instance_valid(claimed_by))


## Half a watchtower's price (rounded up).
static func restore_cost() -> Dictionary:
	var out := {}
	var full: Dictionary = Config.BUILDINGS["tower"]["cost"]
	for k in full:
		out[k] = ceili(full[k] * Config.RUIN_RESTORE_SHARE)
	return out


func claim(v: Village) -> void:
	village = v
	claimed_by = null
	modulate = Color.WHITE.lerp(v.color, 0.25)
	refresh()


func found_message(_v: Village) -> String:
	if village != null:
		return ""
	return "Found a ruined watchtower. The hero can claim it (Explore mode)."


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	if village == null:
		lines.append("Nobody's. The hero can claim it (Explore mode).")
	elif village == game.player_village:
		lines.append("Yours. A builder can restore it into a watchtower.")
		var cost := restore_cost()
		actions.append({
			"label": "Restore (%s)" % Config.cost_icons(cost),
			"disabled": not village.economy.can_afford(cost),
			"action": func() -> void: game.command("restore_ruin", {"ruin": nid}),
		})
	else:
		lines.append("Claimed by %s." % village.village_name)
	return d


func net_state() -> Array:
	return [village.id if village else -1]


func apply_net_state(s: Array) -> void:
	var vid := int(s[0]) if s.size() > 0 else -1
	var v: Village = game.villages[vid] if vid >= 0 and vid < game.villages.size() else null
	if v != village:
		if v:
			claim(v)
		else:
			village = null
