class_name TownHall
extends Tower
## The village's town hall (docs/village-design.md §3a): one per village, 2x2
## in its back quarter, placed by the map; never built, moved or torn down.
## It levels up like a tower (Config.TOWN_HALL "levels"); from level
## "post_from" it holds a tower post on its centre (a Tower in all but its
## look and range). Devastated, the village's last stand starts
## (Village.last_stand, §3b): it must be repaired to full HP in time. It
## follows the village's piece material like the walls.


func setup(p_game: Game, p_kind: String, p_tile: Vector2i, p_complete: bool) -> void:
	size = int(Config.TOWN_HALL["size"])
	super.setup(p_game, p_kind, p_tile, p_complete)


func display_name() -> String:
	return "Town Hall"


func _art() -> String:
	return material_art("town_hall" if level == 1 else "town_hall_%d" % level)


func _look() -> String:
	return material_art("town_hall_ruin") if devastated else _art()


func _front_art() -> String:
	return material_art("town_hall_front_%d" % level)


func refresh() -> void:
	Art.apply(sprite, _look())
	var post := has_post()
	_front.visible = post and not devastated
	if post:
		Art.apply(_front, _front_art())
	_site_sprite.visible = false
	_unit_sprite.visible = post and garrison != null and not devastated
	if garrison and post:
		UnitFx.show_unit(_unit_sprite, garrison.kind)
		_unit_sprite.position = _unit_spot()
	queue_redraw()


func max_level() -> int:
	return (Config.TOWN_HALL["levels"] as Array).size()


## The tower post on its centre (from level "post_from").
func has_post() -> bool:
	return level >= int(Config.TOWN_HALL["post_from"])


func can_garrison() -> bool:
	return working() and has_post()


## A watchtower's range at level "post_range_level"; no upgrades of its own.
func range_tiles() -> float:
	var r: float = Config.TOWER_RANGE["tower"] + Config.TOWER_LEVELS[int(Config.TOWN_HALL["post_range_level"]) - 1]["range_bonus"]
	return r * (1.0 + village.relic_bonus("tower_range")) if village else r


## Never in the way, like a hut: villagers go in and out, and the corner
## tower behind it is reached across it (trees may close in outside).
func is_solid() -> bool:
	return false


func is_solid_when_complete() -> bool:
	return false


func act_center() -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func sight_center() -> Vector2:
	return act_center()


func can_upgrade() -> bool:
	return village != null and free_for_work() and level < max_level()


func upgrade_cost() -> Dictionary:
	return Config.material_cost(Config.TOWN_HALL["levels"][level]["cost"], made_of) if level < max_level() else {}


func start_upgrade() -> void:
	upgrading = true
	upgrade_progress = 0.0
	upgrade_time = float(Config.TOWN_HALL["levels"][level]["work_time"]) * material_factor()
	queue_redraw()


## Its price (Config.PIECE_PRICES) plus the upgrades paid for: what repairs count.
func materials_spent() -> int:
	var n := int(Config.material_cost(Building.price(kind).get("cost", {}), made_of).get("materials", 0))
	for i in range(1, level):
		n += int(Config.material_cost(Config.TOWN_HALL["levels"][i]["cost"], made_of).get("materials", 0))
	return n


func info() -> Dictionary:
	var lines: Array[String] = []
	var actions: Array[Dictionary] = []
	var d := {"title": "%s  ·  Level %d/%d" % [display_name(), level, max_level()], "lines": lines, "actions": actions}
	if village == null:
		d["title"] = "Ruined Town Hall"
		lines.append("Nobody lives here.")
		return d
	var stand := village.last_stand_left()
	if devastated:
		d["title"] = "Devastated Town Hall"
	if stand >= 0.0:
		lines.append("Last stand: repair it to full {hp} within %d s, or %s falls." % [ceili(stand), village.village_name])
	elif devastated and village.hall_lost:
		lines.append("Fallen. Repair it to full {hp} to stand again.")
	else:
		lines.append("The heart of the village. Devastated, it must be repaired in time or the village falls.")
	if upgrading:
		lines.append("Upgrading to level %d: %d%% (%s)" % [level + 1, int(100.0 * work_fraction()), _builder_crew_text().to_lower()])
		add_cancel_action(lines, actions, "Cancel upgrade")
	elif level < max_level() and not devastated and not repairing:
		lines.append("Next level: {hp} %d%s" % [roundi(hp_at(level + 1)), ", a tower post on its roof" if level + 1 == int(Config.TOWN_HALL["post_from"]) else ""])
		actions.append({
			"label": "Upgrade town hall (%s)" % Config.cost_icons(upgrade_cost()),
			"disabled": not can_upgrade() or not village.economy.can_afford(upgrade_cost()),
			"action": func() -> void: game.command("upgrade_tower", {"building": nid}),
		})
	if not has_post() or devastated:
		return d
	lines.append("Tower post: range %.1f tiles" % range_tiles())
	if garrison:
		lines.append("%s, level %d%s" % [garrison.display_name(), garrison.level + 1, "  (bewitched!)" if is_enchanted() else ""])
		lines.append_array(garrison.behavior.info_lines(garrison))
		lines.append_array(garrison.food_lines())
		var g := garrison
		if not g.upgrade_options().is_empty():
			actions.append({"label": "Upgrade %s..." % g.display_name().to_lower(), "action": func() -> void: game.hud.open_upgrade(g)})
		actions.append({"label": "Withdraw", "action": func() -> void: game.command("withdraw_unit", {"unit": g.nid})})
	elif incoming:
		lines.append("%s marching here." % incoming.display_name())
		actions.append({"label": "Withdraw", "action": func() -> void: game.command("withdraw_unit", {"unit": incoming.nid})})
	else:
		lines.append("Unmanned. Drag a unit from the Army tab onto the town hall.")
	return d


## Its HP line and repair; devastated, it says what that costs the village,
## and the last stand's repair can't be called off (it would be ordered again
## at once: Village._order_hall_repair).
func add_hp_info(lines: Array[String], actions: Array[Dictionary]) -> void:
	super.add_hp_info(lines, actions)
	if not devastated:
		return
	var i := lines.find("Devastated: it does nothing until it is repaired.")
	if i >= 0:
		lines[i] = "Devastated: the hero can't rest inside and its post is empty until it is repaired."
	if village != null and village.last_stand_left() >= 0.0:
		for k in range(actions.size() - 1, -1, -1):
			if str(actions[k]["label"]).begins_with("Cancel repair"):
				actions.remove_at(k)
		for k in range(lines.size() - 1, -1, -1):
			if lines[k].ends_with("back if you cancel now") or lines[k] == "Too far along to get anything back":
				lines.remove_at(k)


func _bar_y() -> float:
	return -float(Art.info(_art()).get("roof", 120.0)) - 20.0
