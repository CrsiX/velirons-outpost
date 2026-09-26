class_name Hud
extends CanvasLayer
## All screen UI, built in code: resource bar, wave controls, sidebar
## (Build / Village / Army), info panel, trade dialog, toasts and overlays.
## Big touch targets throughout; works the same with mouse or fingers.

const SIDEBAR_W := 300.0
const TOPBAR_H := 64.0
const DRAG_THRESHOLD := 12.0

var game: Game

var _root: Control
var _topbar: PanelContainer
var _gold_label: Label
var _food_label: Label
var _materials_button: Button
var _pop_label: Label
var _wave_label: Label
var _enemies_label: Label
var _call_button: Button
var _fullscreen_button: Button
var _speed_button: Button
var _pause_button: Button

var _sidebar: PanelContainer
var _sidebar_toggle: Button
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}
var _build_buttons: Dictionary = {}
var _recruit_rows: Dictionary = {}  # role -> {button, title}
var _archer_button: Button
var _reserve_grid: GridContainer
var _reserve_label: Label
var _upgrade_reserve_button: Button
var _selected_unit: MilitaryUnit = null
var _reserve_signature := ""

var _info_panel: PanelContainer
var _info_title: Label
var _info_lines: VBoxContainer
var _info_actions: HFlowContainer
var _info_signature := ""

var _mode_panel: PanelContainer
var _mode_label: Label
var _toasts: VBoxContainer
var _trade_panel: PanelContainer
var _trade_buttons: Array[Button] = []
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_sub: Label
var _overlay_button: Button

var _press_unit: MilitaryUnit = null
var _press_pos := Vector2.ZERO
var _dragging_unit := false
var _drag_ghost: TextureRect
var _refresh_queued := false
var _fast := false
var _tick := 0.0


func setup(p_game: Game) -> void:
	game = p_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)
	_build_topbar()
	_build_sidebar()
	_build_info_panel()
	_build_mode_panel()
	_build_toasts()
	_build_trade_dialog()
	_build_overlay()
	_drag_ghost = _icon(Art.tex("unit_archer"), 56)
	_drag_ghost.visible = false
	_drag_ghost.modulate.a = 0.85
	_root.add_child(_drag_ghost)

	for sig in [game.economy.changed, game.population.changed, game.army.changed, game.construction.changed, game.waves.changed, game.corpses.changed]:
		sig.connect(_queue_refresh)
	_select_tab("build")
	_refresh()
	show_title()


# --- small builders -----------------------------------------------------------------

func _icon(tex: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _label(text: String, size: int = 18, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, min_size: Vector2 = Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b


func _chip(icon_name: String, tooltip: String) -> Array:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.tooltip_text = tooltip
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_icon(Art.tex(icon_name), 34))
	var l := _label("0", 20)
	box.add_child(l)
	return [box, l]


# --- top bar ------------------------------------------------------------------------

func _build_topbar() -> void:
	_topbar = PanelContainer.new()
	_root.add_child(_topbar)
	_topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_topbar.custom_minimum_size.y = TOPBAR_H
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_topbar.add_child(row)

	var gold := _chip("icon_gold", "Gold coins: buy and upgrade military units")
	_gold_label = gold[1]
	_gold_label.custom_minimum_size.x = 56
	row.add_child(gold[0])
	var food := _chip("icon_food", "Food: recruits and feeds civilians. Farms produce it.")
	_food_label = food[1]
	_food_label.custom_minimum_size.x = 110
	row.add_child(food[0])

	_materials_button = _button("0", Vector2(0, 44))
	_materials_button.icon = Art.tex("icon_materials")
	_materials_button.expand_icon = false
	_materials_button.add_theme_constant_override("icon_max_width", 32)
	_materials_button.add_theme_font_size_override("font_size", 20)
	_materials_button.tooltip_text = "Building material: tap to buy more with gold"
	_materials_button.pressed.connect(func() -> void: _trade_panel.visible = not _trade_panel.visible)
	row.add_child(_materials_button)

	var pop := _chip("icon_population", "Civilians / huts")
	_pop_label = pop[1]
	row.add_child(pop[0])

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var enemies := _chip("icon_enemies", "Enemies on the map and still to come this wave")
	_enemies_label = enemies[1]
	_enemies_label.custom_minimum_size.x = 34
	row.add_child(enemies[0])
	_wave_label = _label("", 18)
	row.add_child(_wave_label)
	_call_button = _button("Call wave", Vector2(150, 44))
	UiTheme.style_primary(_call_button)
	_call_button.pressed.connect(func() -> void: game.waves.call_next())
	row.add_child(_call_button)

	_speed_button = _icon_button("icon_play", "Game speed x1 / x2")
	_speed_button.pressed.connect(_toggle_speed)
	row.add_child(_speed_button)
	_pause_button = _icon_button("icon_pause", "Pause")
	_pause_button.pressed.connect(func() -> void: set_paused(not get_tree().paused))
	row.add_child(_pause_button)
	_fullscreen_button = _icon_button("icon_fullscreen", "Fullscreen (F11)")
	_fullscreen_button.pressed.connect(toggle_fullscreen)
	row.add_child(_fullscreen_button)


func _icon_button(icon_name: String, tooltip: String) -> Button:
	var b := _button("", Vector2(48, 44))
	b.icon = Art.tex(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tooltip
	return b


func _toggle_speed() -> void:
	_fast = not _fast
	Engine.time_scale = 2.0 if _fast else 1.0
	_speed_button.icon = Art.tex("icon_fast" if _fast else "icon_play")


func toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F11:
		toggle_fullscreen()


func set_paused(p: bool) -> void:
	get_tree().paused = p
	_pause_button.icon = Art.tex("icon_play" if p else "icon_pause")
	if p:
		toast("Paused", UiTheme.GOLD)


# --- sidebar --------------------------------------------------------------------------

func _build_sidebar() -> void:
	_sidebar = PanelContainer.new()
	_root.add_child(_sidebar)
	_sidebar.anchor_left = 1.0
	_sidebar.anchor_right = 1.0
	_sidebar.anchor_top = 0.0
	_sidebar.anchor_bottom = 1.0
	_sidebar.offset_left = -SIDEBAR_W
	_sidebar.offset_right = 0
	_sidebar.offset_top = TOPBAR_H + 6
	_sidebar.offset_bottom = 0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_sidebar.add_child(v)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for tab in [["build", "Build", "icon_build"], ["village", "Village", "icon_village"], ["army", "Army", "icon_army"]]:
		var b := _button(tab[1], Vector2(0, 48))
		b.icon = Art.tex(tab[2])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(tab[0]))
		tabs.add_child(b)
		_tab_buttons[tab[0]] = b

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	_tab_pages["build"] = _build_page_build()
	_tab_pages["village"] = _build_page_village()
	_tab_pages["army"] = _build_page_army()
	for p in _tab_pages.values():
		pages.add_child(p)

	_sidebar_toggle = _button("", Vector2(40, 64))
	_sidebar_toggle.icon = Art.tex("icon_collapse")
	_sidebar_toggle.expand_icon = true
	_sidebar_toggle.tooltip_text = "Hide / show the sidebar"
	_root.add_child(_sidebar_toggle)
	_sidebar_toggle.anchor_left = 1.0
	_sidebar_toggle.anchor_right = 1.0
	_sidebar_toggle.pressed.connect(_toggle_sidebar)
	_place_sidebar_toggle()


func _toggle_sidebar() -> void:
	_sidebar.visible = not _sidebar.visible
	_sidebar_toggle.icon = Art.tex("icon_collapse" if _sidebar.visible else "icon_expand")
	_place_sidebar_toggle()


func _place_sidebar_toggle() -> void:
	var right := -SIDEBAR_W - 4.0 if _sidebar.visible else -4.0
	_sidebar_toggle.offset_left = right - 40.0
	_sidebar_toggle.offset_right = right
	_sidebar_toggle.offset_top = TOPBAR_H + 12.0
	_sidebar_toggle.offset_bottom = TOPBAR_H + 76.0


func _select_tab(tab: String) -> void:
	for k in _tab_pages:
		_tab_pages[k].visible = k == tab
		UiTheme.style_selected(_tab_buttons[k], k == tab)


## Sidebar entry: icon, title, description and an action button.
func _entry(icon_tex: Texture2D, title: String, desc: String, action_text: String, action: Callable) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.04), Color("3a3024"), 1, 6, 6))
	var v := VBoxContainer.new()
	panel.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	h.add_child(_icon(icon_tex, 52))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	var t := _label(title, 19, UiTheme.GOLD)
	tv.add_child(t)
	var d := _label(desc, 14, UiTheme.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 150
	tv.add_child(d)
	var b := _button(action_text, Vector2(0, 48))
	b.pressed.connect(action)
	v.add_child(b)
	return {"panel": panel, "title": t, "button": b, "desc": d}


func _build_page_build() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	for kind in ["tower", "farm"]:
		var spec: Dictionary = Config.BUILDINGS[kind]
		var icon := Art.tex("watchtower" if kind == "tower" else "farm_field")
		var e := _entry(icon, spec["name"], spec["desc"], "Place  (%s)" % Config.cost_text(spec["cost"]), game.begin_build.bind(kind))
		v.add_child(e["panel"])
		_build_buttons[kind] = e["button"]
	var hint := _label("Village huts can only be rebuilt: tap a ruined hut inside the walls.", 14, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v


func _build_page_village() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	for role in Config.CIVILIAN_ORDER:
		var spec: Dictionary = Config.CIVILIANS[role]
		var e := _entry(Art.tex("unit_" + role), spec["name"], spec["desc"], "Recruit  (%s)" % Config.cost_text(spec["cost"]), _recruit.bind(role))
		v.add_child(e["panel"])
		_recruit_rows[role] = e
	return v


func _recruit(role: String) -> void:
	var err := game.population.recruit_error(role)
	if err != "":
		toast(err, UiTheme.BAD)
		return
	game.population.recruit(role)


func _build_page_army() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var spec: Dictionary = Config.MILITARY["archer"]
	var e := _entry(Art.tex("unit_archer"), spec["name"], spec["desc"], "Recruit  (%s)" % Config.cost_text(spec["cost"]), func() -> void:
		if game.army.recruit("archer") == null:
			toast("Not enough gold", UiTheme.BAD))
	v.add_child(e["panel"])
	_archer_button = e["button"]
	_reserve_label = _label("", 16)
	_reserve_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_reserve_label)
	_reserve_grid = GridContainer.new()
	_reserve_grid.columns = 4
	_reserve_grid.add_theme_constant_override("h_separation", 6)
	_reserve_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_reserve_grid)
	_upgrade_reserve_button = _button("Upgrade selected", Vector2(0, 48))
	_upgrade_reserve_button.pressed.connect(func() -> void:
		if _selected_unit and not game.army.upgrade(_selected_unit):
			toast("Not enough gold", UiTheme.BAD))
	v.add_child(_upgrade_reserve_button)
	return v


func _rebuild_reserve() -> void:
	var reserve := game.army.reserve()
	if _selected_unit and not reserve.has(_selected_unit):
		_selected_unit = null
	_refresh_reserve_texts(reserve)
	# Only rebuild the cards when the reserve really changed, and never while a
	# card is being pressed or dragged (that would free the card under the finger).
	var sig := ",".join(reserve.map(func(u: MilitaryUnit) -> String: return "%d:%d" % [u.id, u.level])) + "|%s" % (_selected_unit.id if _selected_unit else -1)
	if sig == _reserve_signature or _press_unit != null:
		return
	_reserve_signature = sig
	for c in _reserve_grid.get_children():
		_reserve_grid.remove_child(c)
		c.queue_free()
	for u in reserve:
		var card := _button("Lv %d" % (u.level + 1), Vector2(62, 76))
		card.icon = Art.tex("unit_" + u.kind)
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.expand_icon = true
		card.add_theme_font_size_override("font_size", 14)
		card.tooltip_text = "Drag onto a tower, or tap and then tap a tower"
		UiTheme.style_selected(card, u == _selected_unit)
		card.button_down.connect(_on_card_down.bind(u))
		_reserve_grid.add_child(card)


func _refresh_reserve_texts(reserve: Array[MilitaryUnit]) -> void:
	_reserve_label.text = "Reserve: %d   Walking: %d   On duty: %d\nDrag an archer onto a tower, or tap it and then tap a tower. Soldiers walk there, and walk back when withdrawn." % [reserve.size(), game.army.walking().size(), game.army.stationed().size()]
	_upgrade_reserve_button.visible = _selected_unit != null
	if _selected_unit:
		_upgrade_reserve_button.disabled = not _selected_unit.can_upgrade() or not game.economy.can_afford(_selected_unit.upgrade_cost())
		_upgrade_reserve_button.text = ("Upgrade selected  (%s)" % Config.cost_text(_selected_unit.upgrade_cost())) if _selected_unit.can_upgrade() else "Selected archer is max level"


# --- reserve card press / drag ----------------------------------------------------------

func _on_card_down(unit: MilitaryUnit) -> void:
	_press_unit = unit
	_dragging_unit = false
	_press_pos = _root.get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	if _press_unit == null:
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		if not _dragging_unit and pos.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging_unit = true
			_drag_ghost.visible = true
		if _dragging_unit:
			_drag_ghost.position = pos - _drag_ghost.size / 2.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var unit := _press_unit
		_press_unit = null
		_drag_ghost.visible = false
		_queue_refresh()  # catch up on any reserve change deferred during the press
		# The release is left unhandled on purpose so the card button resets.
		if _dragging_unit:
			_dragging_unit = false
			if not is_over_ui(event.position):
				game.drop_unit(unit, event.position)
		else:
			_selected_unit = unit
			_queue_refresh()
			game.begin_station(unit)


func is_over_ui(screen_pos: Vector2) -> bool:
	for c: Control in [_topbar, _sidebar, _sidebar_toggle, _info_panel, _mode_panel, _trade_panel, _overlay]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(screen_pos):
			return true
	return false


# --- info panel ----------------------------------------------------------------------

func _build_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_root.add_child(_info_panel)
	_info_panel.anchor_top = 1.0
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = 10
	_info_panel.offset_right = 370
	_info_panel.offset_bottom = -10
	_info_panel.custom_minimum_size = Vector2(360, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_info_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_info_title = _label("", 22, UiTheme.GOLD)
	_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_info_title)
	var close := _button("X", Vector2(44, 40))
	close.pressed.connect(func() -> void: game.deselect())
	head.add_child(close)
	_info_lines = VBoxContainer.new()
	v.add_child(_info_lines)
	_info_actions = HFlowContainer.new()
	_info_actions.add_theme_constant_override("h_separation", 6)
	_info_actions.add_theme_constant_override("v_separation", 6)
	v.add_child(_info_actions)
	_info_panel.visible = false


func show_info(data: Dictionary) -> void:
	var sig := str(data["title"]) + "|" + "|".join(data["lines"])
	for a in data["actions"]:
		sig += "|%s:%s" % [a["label"], a.get("disabled", false)]
	_info_panel.visible = true
	if sig == _info_signature:
		return  # unchanged: keep buttons alive so presses aren't interrupted
	_info_signature = sig
	_info_title.text = data["title"]
	for c in _info_lines.get_children():
		_info_lines.remove_child(c)
		c.queue_free()
	for line in data["lines"]:
		var l := _label(line, 16)
		_info_lines.add_child(l)
	for c in _info_actions.get_children():
		_info_actions.remove_child(c)
		c.queue_free()
	for a in data["actions"]:
		var b := _button(a["label"], Vector2(0, 50))
		b.disabled = a.get("disabled", false)
		var cb: Callable = a["action"]
		b.pressed.connect(func() -> void:
			cb.call()
			_info_signature = ""
			if game.selected:
				show_info(game.selected.info()))
		_info_actions.add_child(b)
	_place_info_panel.call_deferred()


## Anchor the panel's bottom edge 10px above the screen bottom, growing upwards.
func _place_info_panel() -> void:
	var h := _info_panel.get_combined_minimum_size().y
	_info_panel.offset_top = -10.0 - h
	_info_panel.offset_bottom = -10.0


func hide_info() -> void:
	_info_panel.visible = false
	_info_signature = ""


# --- mode hint, toasts, trade -----------------------------------------------------------

func _build_mode_panel() -> void:
	_mode_panel = PanelContainer.new()
	_root.add_child(_mode_panel)
	_mode_panel.anchor_left = 0.5
	_mode_panel.anchor_right = 0.5
	_mode_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mode_panel.offset_top = TOPBAR_H + 10
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_mode_panel.add_child(h)
	_mode_label = _label("", 18)
	_mode_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_mode_label)
	var cancel := _button("Done", Vector2(96, 44))
	cancel.pressed.connect(func() -> void: game.cancel_mode())
	h.add_child(cancel)
	_mode_panel.visible = false


func set_mode_hint(text: String) -> void:
	_mode_panel.visible = text != ""
	_mode_label.text = text
	_mode_panel.reset_size()
	_mode_panel.offset_left = -_mode_panel.size.x / 2.0 - SIDEBAR_W / 2.0
	_mode_panel.offset_right = _mode_panel.size.x / 2.0 - SIDEBAR_W / 2.0


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toasts)
	_toasts.anchor_left = 0.0
	_toasts.anchor_right = 1.0
	_toasts.offset_right = -SIDEBAR_W
	_toasts.offset_top = TOPBAR_H + 70


func toast(text: String, color: Color = UiTheme.TEXT) -> void:
	var l := _label(text, 22, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	if _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _build_trade_dialog() -> void:
	_trade_panel = PanelContainer.new()
	_root.add_child(_trade_panel)
	_trade_panel.offset_left = 330
	_trade_panel.offset_top = TOPBAR_H + 6
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_trade_panel.add_child(v)
	var title := _label("Buy building material", 20, UiTheme.GOLD)
	v.add_child(title)
	var rate := _label("%d material for %d gold" % [Config.MATERIALS_TRADE["materials"], Config.MATERIALS_TRADE["gold"]], 16, UiTheme.MUTED)
	v.add_child(rate)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	for bundles in [1, 5]:
		var b := _button("+%d  (%d gold)" % [Config.MATERIALS_TRADE["materials"] * bundles, Config.MATERIALS_TRADE["gold"] * bundles], Vector2(0, 50))
		b.pressed.connect(func() -> void:
			if not game.economy.buy_materials(bundles):
				toast("Not enough gold", UiTheme.BAD))
		h.add_child(b)
		_trade_buttons.append(b)
	var close := _button("Close", Vector2(0, 44))
	close.pressed.connect(func() -> void: _trade_panel.visible = false)
	v.add_child(close)
	_trade_panel.visible = false


# --- overlays -------------------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(480, 0)
	panel.add_child(v)
	_overlay_title = _label("", 40, UiTheme.GOLD)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_overlay_title)
	_overlay_sub = _label("", 18)
	_overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_overlay_sub)
	_overlay_button = _button("", Vector2(0, 64))
	_overlay_button.add_theme_font_size_override("font_size", 24)
	UiTheme.style_primary(_overlay_button)
	v.add_child(_overlay_button)


func show_title() -> void:
	_overlay_title.text = "Veliron's Outpost"
	_overlay_sub.text = ("The goblins are coming for the last outpost of Veliron.\n\n"
		+ "Place watchtowers and farms in the Build tab. Your builder walks out and builds them. "
		+ "Buy archers in the Army tab and put them on towers. Assign farmers to farms so the village doesn't starve. "
		+ "Your explorer clears the fog on their own; land is only watched near villagers and manned towers.\n\n"
		+ "Drag to move the map, pinch or scroll to zoom.")
	_overlay_button.text = "Defend the outpost"
	_overlay.visible = true
	get_tree().paused = true  # the first-wave timer waits for the player
	_connect_overlay(func() -> void:
		_overlay.visible = false
		get_tree().paused = false)


func show_game_over(title: String, subtitle: String) -> void:
	_overlay_title.text = title
	_overlay_title.add_theme_color_override("font_color", UiTheme.BAD)
	_overlay_sub.text = subtitle
	_overlay_button.text = "Try again"
	_overlay.visible = true
	_info_panel.visible = false
	_connect_overlay(func() -> void: game.restart())


func _connect_overlay(cb: Callable) -> void:
	for c in _overlay_button.pressed.get_connections():
		_overlay_button.pressed.disconnect(c["callable"])
	_overlay_button.pressed.connect(cb)


func is_title_visible() -> bool:
	return _overlay.visible


# --- refresh ---------------------------------------------------------------------------------

func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_refresh_wave()
		_refresh_resources()


func _refresh() -> void:
	_refresh_queued = false
	_refresh_resources()
	_refresh_wave()
	for kind in _build_buttons:
		(_build_buttons[kind] as Button).disabled = not game.economy.can_afford(Config.BUILDINGS[kind]["cost"])
	for role in _recruit_rows:
		var e: Dictionary = _recruit_rows[role]
		(e["title"] as Label).text = "%s  ×%d" % [Config.CIVILIANS[role]["name"], game.population.count(role)]
		(e["button"] as Button).disabled = game.population.recruit_error(role) != ""
		if role == "farmer":
			(e["desc"] as Label).text = "%s\nWithout a farm: %d" % [Config.CIVILIANS[role]["desc"], game.population.free_farmers().size()]
		elif role == "gatherer":
			(e["desc"] as Label).text = "%s\nCorpses lying around: %d" % [Config.CIVILIANS[role]["desc"], game.corpses.count()]
	_archer_button.disabled = not game.economy.can_afford(Config.MILITARY["archer"]["cost"])
	for b in _trade_buttons:
		b.disabled = false
	_rebuild_reserve()


func _refresh_resources() -> void:
	var e := game.economy
	var p := game.population
	_gold_label.text = str(int(e.amount("gold")))
	var rate := p.food_per_second() * 60.0
	_food_label.text = "%d  (%+d/min)" % [int(e.amount("food")), roundi(rate)]
	_food_label.add_theme_color_override("font_color", UiTheme.BAD if p.starving else UiTheme.TEXT)
	_materials_button.text = str(int(e.amount("materials")))
	_pop_label.text = "%d / %d" % [p.count(), p.cap()]


func _refresh_wave() -> void:
	var w := game.waves
	_enemies_label.text = str(w.enemies_left())
	if w.in_progress():
		_wave_label.text = "Wave %d attacking" % w.wave
		_call_button.text = "Fighting..."
		_call_button.disabled = true
	else:
		var s := int(ceil(maxf(w.countdown, 0.0)))
		_wave_label.text = "Wave %d in %d:%02d" % [w.wave + 1, s / 60, s % 60]
		_call_button.text = "Call now +%dg" % w.early_call_bonus()
		_call_button.disabled = false
