class_name StaticPiece
extends Building
## Village walls and gates. They hold enemies back until devastated
## (docs/siege-design.md) and level up to 3 for more HP (Config.PIECE_LEVELS).

var flip := false


func _build_visuals() -> void:
	sprite = Art.sprite(_look())
	sprite.flip_h = flip
	sprite.show_behind_parent = true
	add_child(sprite)


func _look() -> String:
	if devastated:
		return "%s_ruin" % kind
	return kind if level == 1 else "%s_%d" % [kind, level]


func has_ruin_art() -> bool:
	return true


func refresh() -> void:
	if sprite:
		Art.apply(sprite, _look())
		sprite.flip_h = flip
	queue_redraw()


func is_solid() -> bool:
	return kind == "wall" and not devastated


func is_solid_when_complete() -> bool:
	return kind == "wall"


## Gates always keep watch, even though nobody mans them (until devastated).
func sight_radius() -> float:
	if devastated:
		return 0.0
	return Config.GATE_SIGHT if kind == "gate" else super.sight_radius()


func display_name() -> String:
	return "Village Gate" if kind == "gate" else "Village Wall"


func max_level() -> int:
	return (Config.PIECE_LEVELS[kind] as Array).size()


func can_upgrade() -> bool:
	return village != null and free_for_work() and level < max_level()


func upgrade_cost() -> Dictionary:
	return Config.PIECE_LEVELS[kind][level]["cost"] if level < max_level() else {}


func start_upgrade() -> void:
	upgrading = true
	upgrade_progress = 0.0
	upgrade_time = Config.PIECE_LEVELS[kind][level]["work_time"]
	queue_redraw()


func pending_upgrade_cost() -> Dictionary:
	return upgrade_cost() if upgrading else {}


func finish_upgrade() -> void:
	super.finish_upgrade()
	gain_level()
	refresh()


## Its price (Config.PIECE_PRICES) plus the upgrades paid for: what repairs count.
func materials_spent() -> int:
	var n := super.materials_spent()
	for i in range(1, level):
		n += int(Config.PIECE_LEVELS[kind][i]["cost"].get("materials", 0))
	return n


func info() -> Dictionary:
	var lines: Array[String] = []
	var actions: Array[Dictionary] = []
	var title := "%s  ·  Level %d/%d" % [display_name(), level, max_level()]
	if devastated:
		title = "Devastated %s" % display_name().to_lower().trim_prefix("village ")
		lines.append("Broken: enemies walk straight through.")
	elif kind == "gate":
		lines.append("Holds enemies back until they break it.")
	else:
		lines.append("Holds enemies back; they break it where it's weakest.")
	if upgrading:
		lines.append("Upgrading to level %d: %d%% (%s)" % [level + 1, int(100.0 * work_fraction()), "builder at work" if builder != null else "waiting for a builder"])
		add_cancel_action(lines, actions, "Cancel upgrade")
	elif level < max_level() and village != null and not devastated and not repairing:
		lines.append("Next level: {hp} %d" % roundi(Config.BUILDING_HP[kind][level]))
		actions.append({
			"label": "Upgrade %s (%s)" % ["gate" if kind == "gate" else "wall", Config.cost_icons(upgrade_cost())],
			"disabled": not can_upgrade() or not village.economy.can_afford(upgrade_cost()),
			"action": func() -> void: game.command("upgrade_tower", {"building": nid}),
		})
	return {"title": title, "lines": lines, "actions": actions}


func pick_rect() -> Rect2:
	return Rect2(-50, -60, 100, 76)
