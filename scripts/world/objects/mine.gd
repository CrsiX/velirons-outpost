class_name Mine
extends MapObject
## A gold mine at the outer edge of a mountain range, with a road to it
## (docs/world-design.md §9.6). Nobody owns it: one miner at a time works it,
## whoever's miner gets there first. A second miner is turned away and walks
## home unassigned. Anyone walking up to a mine the first time unlocks the
## miner for every village (World._process).

## The miner working it (from any village), or null.
var worker: Node = null


func display_name() -> String:
	return "Mine"


## The walkable tile in front of the mine (where the miner goes in).
func visit_tile() -> Vector2i:
	return data.get("front", tile)


func is_free() -> bool:
	return worker == null or not is_instance_valid(worker)


func found_message(_v: Village) -> String:
	if not game.is_unlocked("miner"):
		return "Found a mine in the mountains. Walk up to it to learn how to work it."
	return "Found a mine in the mountains. A miner can work it for gold."


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	lines.append("Gold: %.1f per second while a miner works it (one at a time)." % Config.MINE_GOLD_RATE)
	if not is_free():
		var v: Village = worker.village
		lines.append("Worked by %s." % ("your miner" if v == game.player_village else "a miner from %s" % v.village_name))
		if v == game.player_village:
			actions.append({"label": "Call the miner home", "action": func() -> void: game.command("unassign_miner", {"mine": nid})})
		return d
	if not game.is_unlocked("miner"):
		lines.append("Nobody knows how to work it yet: walk up to a mine first.")
		return d
	lines.append("Free.")
	var idle := game.player_village.population.free_workers("miner")
	actions.append({
		"label": "Send a miner" if not idle.is_empty() else "No idle miner (recruit one in the Village tab)",
		"disabled": idle.is_empty() or not is_found_by(game.player_village),
		"action": func() -> void: game.command("assign_miner", {"mine": nid}),
	})
	return d


func net_state() -> Array:
	return [game.id_of(worker) if not is_free() else 0]


func apply_net_state(s: Array) -> void:
	var id := int(s[0]) if s.size() > 0 else 0
	worker = game.entity(id) if id > 0 else null
