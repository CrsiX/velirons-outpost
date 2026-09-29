class_name Tower
extends MilitaryPost
## A tower that holds one military unit of any kind. Used for both the four
## pre-built village wall towers ("wall_tower") and player-built watchtowers
## ("tower"). The tower never acts itself: its unit's behavior does, using the
## tower's range. Towers level up (for building material and a builder's
## time) to extend that range; they keep working while being upgraded.

var level := 1
var _spell_glow: Sprite2D
## Seconds the stationed unit stays enchanted by a witch (does nothing meanwhile).
var enchanted := 0.0
var _glow_t := 0.0
var _front: Sprite2D
var _site_sprite: Sprite2D


func _art() -> String:
	var base := "wall_tower" if kind == "wall_tower" else "watchtower"
	return base if level == 1 else "%s_%d" % [base, level]


func _front_art() -> String:
	var base := "wall_tower_front" if kind == "wall_tower" else "watchtower_front"
	return base if level == 1 else "%s_%d" % [base, level]


func display_name() -> String:
	return "Wall Tower" if kind == "wall_tower" else "Watchtower"


func max_level() -> int:
	return Config.TOWER_LEVELS.size()


## Range of the stationed unit: tower base range plus the level bonus.
func range_tiles() -> float:
	return Config.TOWER_RANGE[kind] + Config.TOWER_LEVELS[level - 1]["range_bonus"]


func can_upgrade() -> bool:
	return complete and not upgrading and level < max_level()


func upgrade_cost() -> Dictionary:
	return Config.TOWER_LEVELS[level]["cost"] if level < max_level() else {}


func start_upgrade() -> void:
	upgrading = true
	upgrade_progress = 0.0
	upgrade_time = Config.TOWER_LEVELS[level]["work_time"]
	queue_redraw()


func pending_upgrade_cost() -> Dictionary:
	return upgrade_cost() if upgrading else {}


func finish_upgrade() -> void:
	super.finish_upgrade()
	level += 1
	refresh()
	var tw := create_tween()
	scale = Vector2(1.06, 0.94)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	add_child(sprite)
	_unit_sprite = Sprite2D.new()
	_unit_sprite.show_behind_parent = true
	add_child(_unit_sprite)
	_spell_glow = Art.sprite("spell_glow")
	_spell_glow.show_behind_parent = true
	_spell_glow.visible = false
	add_child(_spell_glow)
	_front = Sprite2D.new()
	_front.show_behind_parent = true
	add_child(_front)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	add_child(_site_sprite)


func refresh() -> void:
	Art.apply(sprite, _art())
	Art.apply(_front, _front_art())
	sprite.visible = complete
	_front.visible = complete
	_site_sprite.visible = not complete
	_unit_sprite.visible = complete and garrison != null
	if garrison:
		Art.apply(_unit_sprite, "unit_" + garrison.kind)
		_unit_sprite.position = Vector2(0, -Art.info(_art())["platform"] + 2.0)
	queue_redraw()


func is_solid() -> bool:
	return complete


func is_solid_when_complete() -> bool:
	return true


## Every finished tower watches like a building; manned ones watch their range.
func sight_radius() -> float:
	var r := super.sight_radius()
	if complete and garrison != null:
		r = maxf(r, range_tiles() + Config.TOWER_SIGHT_BONUS)
	return r


func set_slot(i: int, unit: MilitaryUnit) -> void:
	if garrison != null and unit != garrison:
		garrison.behavior.on_leave(self, garrison)
	enchanted = 0.0
	_spell_glow.visible = false
	super.set_slot(i, unit)


func post_kind() -> String:
	return "tower"


## Behaviors act from here (see MilitaryBehavior): the tower's tile and range.
func act_center() -> Vector2:
	return Vector2(tile)


func act_range() -> float:
	return range_tiles()


func _exit_tree() -> void:
	if garrison:
		garrison.behavior.on_leave(self, garrison)


func _process(delta: float) -> void:
	if game.is_client:  # the host runs the unit; we only show the witch's glow
		_glow_t += delta
		_spell_glow.visible = enchanted > 0.0 and garrison != null
		_spell_glow.modulate.a = 0.6 + 0.3 * sin(_glow_t * 10.0)
		return
	if enchanted > 0.0:
		enchanted -= delta
		_glow_t += delta
		_spell_glow.modulate.a = 0.6 + 0.3 * sin(_glow_t * 10.0)
		_spell_glow.visible = enchanted > 0.0 and garrison != null
		return  # an enchanted unit neither shoots nor summons
	if complete and garrison != null:
		garrison.behavior.tick(self, garrison, delta)


## A witch's spell: the unit on this tower stops acting for `seconds`
## (existing summons are not affected; the unit takes no damage).
func enchant(seconds: float) -> void:
	if garrison == null:
		return
	enchanted = maxf(enchanted, seconds)
	_spell_glow.position = _unit_sprite.position + Vector2(0, -36)
	_spell_glow.visible = true


func is_enchanted() -> bool:
	return enchanted > 0.0 and garrison != null


# --- helpers for behaviors -------------------------------------------------------

func face(grid_target: Vector2) -> void:
	_unit_sprite.flip_h = Iso.to_world(grid_target).x < position.x


## Walkable tile next to the tower, outside the village walls if possible
## (where summons appear).
func outer_tile() -> Vector2i:
	var best := work_tile()
	var best_d := -1.0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := tile + Vector2i(dx, dy)
			if t == tile or game.map.in_village(t) or not game.world.pathing.is_walkable(t):
				continue
			var d := Vector2(t).distance_to(Vector2(village.center))
			if d > best_d:
				best_d = d
				best = t
	return best


func muzzle_position() -> Vector2:
	return to_global(_unit_sprite.position + Vector2(0, -24))


func recoil() -> void:
	var tw := create_tween()
	var base := Vector2(0, -Art.info(_art())["platform"] + 2.0)
	tw.tween_property(_unit_sprite, "position", base + Vector2(3.0 if _unit_sprite.flip_h else -3.0, 0), 0.05)
	tw.tween_property(_unit_sprite, "position", base, 0.12)


# --- UI ---------------------------------------------------------------------------

func info() -> Dictionary:
	var d := super.info()
	if not complete:
		return d
	d["title"] = "%s  ·  Level %d/%d" % [display_name(), level, max_level()]
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	lines.append("Tower level %d of %d: range %.1f tiles" % [level, max_level(), range_tiles()])
	if upgrading:
		lines.append("Upgrading to level %d: %d%% (%s)" % [level + 1, int(100.0 * work_fraction()), "builder at work" if builder != null else "waiting for a builder"])
		actions.append({"label": "Cancel upgrade (refund)", "action": func() -> void: game.command("cancel_site", {"building": nid})})
	elif level < max_level():
		var bonus: float = Config.TOWER_LEVELS[level]["range_bonus"] - Config.TOWER_LEVELS[level - 1]["range_bonus"]
		actions.append({
			"label": "Upgrade tower (%s)" % Config.cost_text(upgrade_cost()),
			"disabled": not village.economy.can_afford(upgrade_cost()),
			"action": func() -> void: game.command("upgrade_tower", {"building": nid}),
		})
		lines.append("Next level: +%.1f range" % bonus)
	if garrison:
		lines.append("%s, level %d%s" % [garrison.display_name(), garrison.level + 1, "  (bewitched!)" if is_enchanted() else ""])
		lines.append_array(garrison.behavior.info_lines(garrison))
		var g := garrison
		if not g.upgrade_options().is_empty():
			actions.append({"label": "Upgrade %s..." % g.display_name().to_lower(), "action": func() -> void: game.hud.open_upgrade(g)})
		actions.append({"label": "Withdraw", "action": func() -> void: game.command("withdraw_unit", {"unit": g.nid})})
	elif incoming:
		lines.append("%s marching here." % incoming.display_name())
		actions.append({"label": "Withdraw", "action": func() -> void: game.command("withdraw_unit", {"unit": incoming.nid})})
	else:
		lines.append("Unmanned. Drag a unit from the Army tab onto this tower.")
	return d


func pick_rect() -> Rect2:
	return Rect2(-40, -Art.info(_art())["platform"] - 40, 80, Art.info(_art())["platform"] + 60)


func _bar_y() -> float:
	return -Art.info(_art())["platform"] - 50.0
