class_name Hud
extends CanvasLayer
## All screen UI, built in code: resource bar, wave controls, the dock
## (Build / Village / Army), info panel, trade dialog, toasts and overlays.
## Big touch targets throughout; works the same with mouse or fingers.
##
## Two layouts, picked by `Layout.portrait` whenever the screen turns or resizes:
##   landscape - one-row top bar; the dock is a sidebar on the right that
##               collapses to the right edge;
##   portrait  - two-row top bar; the dock is a bottom sheet: tabs always
##               visible, pages slide up above them (tap or swipe the handle,
##               or tap a tab). It gets out of the way while you place a
##               building, station or drag a unit, or look at a selection.

const SIDEBAR_W := 320.0
## Game speed button cycles through these; 0 = paused.
const SPEED_ICONS: Array[String] = ["icon_play", "icon_fast", "icon_fastest", "icon_pause"]
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
var _settings_button: Button
var _village_button: Button
var _upgrade_panel: PanelContainer
var _upgrade_title: Label
var _upgrade_options: VBoxContainer
var _upgrade_hint: Label
var _upgrade_unit: MilitaryUnit
var _confirm_panel: PanelContainer
var _confirm_text: Label
var _confirm_yes: Button
var _gray: ColorRect
var _settings_note: Label
var _paused_banner: Label
## Co-op: greys out everything below the top bar while the game is paused.
var _pause_gray: ColorRect
var _host_paused := false
# co-op help
var _send_panel: PanelContainer
var _send_labels: Dictionary = {}  # resource -> Label
var _send_amounts := {"gold": 0, "food": 0, "materials": 0}
var _send_target := -1  # village id
var _send_target_button: Button
var _send_tax_label: Label
var _send_button: Button
var _send_entry: Dictionary = {}
var _send_unit_panel: PanelContainer
var _send_unit_title: Label
var _send_unit_target := -1
var _send_unit_target_button: Button
var _send_unit_go: Button
var _send_reserve_button: Button
var _hero_support_button: Button
## The village whose systems the HUD shows (the local player's).
var _bound: Village
var _settings: Control  # grayscale backdrop + dialog, shown while paused
var _settings_continue: Button
var _settings_log_button: Button
var _settings_lang_button: Button
var _settings_title_button: Button
var _speed_before := 0
var _log_box: VBoxContainer
var _log_dirty := true
var _dock_hint: Label
var _hero_button: Button
var _hero_panel: PanelContainer
var _hero_stats: Label
var _hero_status: Label
var _hero_mode_button: Button
var _hero_mode_hint: Label
var _hero_train_label: Label
var _hero_train_bar: ProgressBar
var _hero_goto_button: Button

const HERO_MODE_HINTS: Array[String] = [
	"Waits in the village centre and fights enemies that come near a gate.",
	"Builds like a builder, at half speed.",
	"Explores like an explorer, with a shorter sight range.",
	"Gathers corpses like a gatherer, 2 at a time.",
	"Passes his XP on to the unit at the Training Grounds (free level-ups). Only useful with Training Grounds and a unit stationed there; otherwise he defends.",
	"Walks back to the village centre and rests there, fighting nobody, until his HP is back.",
	"Walks to another village and defends it like at home: its gates, its centre. He keeps his XP and heals there. That village can't give him orders.",
]
var _speed_button: Button
var _speed_index := 0

var _sidebar: PanelContainer  # the dock: right sidebar or bottom sheet
var _sidebar_toggle: Button
var _sheet_handle: Control
var _sheet_scroll: ScrollContainer
var _tabs_row: HBoxContainer
var _entry_grids: Array[GridContainer] = []
var _current_tab := "build"
var _side_open := true  # landscape sidebar shown
var _sheet_open := false  # portrait sheet expanded
var _sheet_h := 0.0
var _auto_closed := false  # sheet folded away for a placement / drag, reopen after
var _handle_press_y := 0.0

var _portrait := false
var _top_h := TOPBAR_H
var _topbar_box: BoxContainer
var _top_left: HBoxContainer
var _top_right: HBoxContainer
var _spacer_land: Control
var _spacer_port: Control
var _relayout_queued := false
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}
var _build_buttons: Dictionary = {}
var _recruit_rows: Dictionary = {}  # role -> {button, title}
var _military_buttons: Dictionary = {}  # kind -> recruit Button
var _selected_info: Label
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
var _overlay_menu_button: Button

var _press_unit: MilitaryUnit = null
var _press_pos := Vector2.ZERO
var _dragging_unit := false
var _drag_ghost: TextureRect
var _refresh_queued := false
var _tick := 0.0


func setup(p_game: Game) -> void:
	game = p_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)
	_build_topbar()
	_build_hero_panel()
	_build_sidebar()
	_build_info_panel()
	_build_mode_panel()
	_build_toasts()
	_build_trade_dialog()
	_build_send_dialog()
	_build_upgrade_dialogs()
	_build_log()
	_build_overlay()
	_dock_hint = _label("Release to withdraw", 22, UiTheme.GOOD)
	_dock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_hint.visible = false
	_root.add_child(_dock_hint)
	_drag_ghost = _icon(null, 56)
	_drag_ghost.visible = false
	_drag_ghost.modulate.a = 0.85
	_root.add_child(_drag_ghost)
	_build_settings()


	for sig in [game.waves.changed, game.corpses.changed]:
		sig.connect(_queue_refresh)
	bind_village(game.player_village)
	_select_tab("build")
	get_viewport().size_changed.connect(_queue_relayout)
	Layout.changed.connect(func(_p: bool) -> void: _queue_relayout())
	_relayout()
	_refresh()


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
	# Resources and the hero on the left, wave controls on the right: side by
	# side in landscape, stacked in two rows in portrait.
	_topbar_box = BoxContainer.new()
	_topbar_box.add_theme_constant_override("separation", 6)
	_topbar.add_child(_topbar_box)
	_top_left = HBoxContainer.new()
	_topbar_box.add_child(_top_left)
	_top_right = HBoxContainer.new()
	_top_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topbar_box.add_child(_top_right)
	var row := _top_left

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
	_materials_button.pressed.connect(func() -> void:
		_trade_panel.visible = not _trade_panel.visible
		_hero_panel.visible = _hero_panel.visible and not _trade_panel.visible)
	row.add_child(_materials_button)

	var pop := _chip("icon_population", "Civilians / huts")
	_pop_label = pop[1]
	row.add_child(pop[0])

	_hero_button = _button("XP 0", Vector2(0, 44))
	_hero_button.icon = Art.tex("icon_hero")
	_hero_button.expand_icon = false
	_hero_button.add_theme_constant_override("icon_max_width", 30)
	_hero_button.add_theme_font_size_override("font_size", 18)
	_hero_button.tooltip_text = "The hero: tap for orders"
	_hero_button.pressed.connect(func() -> void:
		_hero_panel.visible = not _hero_panel.visible
		_trade_panel.visible = _trade_panel.visible and not _hero_panel.visible
		_refresh_hero())
	row.add_child(_hero_button)

	row = _top_right
	_spacer_land = _spacer()
	row.add_child(_spacer_land)
	var enemies := _chip("icon_enemies", "Enemies on the map and still to come this wave")
	_enemies_label = enemies[1]
	_enemies_label.custom_minimum_size.x = 34
	row.add_child(enemies[0])
	_wave_label = _label("", 18)
	row.add_child(_wave_label)
	_spacer_port = _spacer()
	row.add_child(_spacer_port)
	_call_button = _button("Call wave", Vector2(150, 44))
	UiTheme.style_primary(_call_button)
	_call_button.pressed.connect(func() -> void: _do("call_wave"))
	row.add_child(_call_button)

	_speed_button = _icon_button("icon_play", "")
	_speed_button.pressed.connect(func() -> void: set_speed_index((_speed_index + 1) % Game.SPEEDS.size()))
	game.speed_changed.connect(_on_speed_changed)
	row.add_child(_speed_button)
	if game.is_host_player():
		set_speed_index(0)
	else:
		_on_speed_changed(game.speed_index)  # (co-op client: shows the host's speed)
	_village_button = _button("", Vector2(0, 44))
	_village_button.tooltip_text = "Hot-seat: switch to the next village (Tab)"
	_village_button.add_theme_font_size_override("font_size", 16)
	_village_button.visible = game.villages.size() > 1
	_village_button.disabled = game.networked  # networked: just shows whose village this is
	_village_button.pressed.connect(func() -> void:
		if not game.networked:
			game.switch_village())
	row.add_child(_village_button)
	_settings_button = _icon_button("icon_settings", "Settings (pauses the game)")
	_settings_button.pressed.connect(open_settings)
	row.add_child(_settings_button)


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Keeps the top bar inside the screen on narrow windows by dropping spacing
## and then the (redundant) wave text, rather than running off the edge.
func _fit_topbar() -> void:
	var width := _root.get_viewport_rect().size.x
	for r in [_top_left, _top_right]:
		r.add_theme_constant_override("separation", 16)
	_wave_label.visible = true
	if _topbar.get_combined_minimum_size().x > width:
		for r in [_top_left, _top_right]:
			r.add_theme_constant_override("separation", 6)
	if _topbar.get_combined_minimum_size().x > width:
		_wave_label.visible = false


func _icon_button(icon_name: String, tooltip: String) -> Button:
	var b := _button("", Vector2(48, 44))
	b.icon = Art.tex(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tooltip
	return b


## 1x, 2x, 4x or paused (0x), shown by the single speed button.
func set_speed_index(i: int) -> void:
	var r := game.command("set_speed", {"index": i})
	if not r["ok"]:
		toast(r["error"], UiTheme.BAD)


## The button follows the game speed, whoever set it.
func _on_speed_changed(i: int) -> void:
	_speed_index = i
	_speed_button.disabled = not game.is_host_player()
	var speed := Game.SPEEDS[i]
	_speed_button.icon = Art.tex(SPEED_ICONS[i])
	var next := Game.SPEEDS[(i + 1) % Game.SPEEDS.size()]
	_speed_button.tooltip_text = "Speed: %s  (click for %s)" % [_speed_name(speed), _speed_name(next)]
	if game.events:
		game.events.debug("game speed: %s" % _speed_name(speed))
	if speed == 0.0:
		toast("Paused", UiTheme.GOLD)


func _speed_name(speed: float) -> String:
	return "paused" if speed == 0.0 else "%dx" % int(speed)


func current_speed() -> float:
	return Game.SPEEDS[_speed_index]


func toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F11:
			toggle_fullscreen()
		KEY_ESCAPE:
			if _settings.visible:
				close_settings()
		KEY_TAB:
			if game.villages.size() > 1:
				game.switch_village()


# --- the village shown ----------------------------------------------------------------

## Shows `v`'s economy, villagers, army, hero and log (the local player's
## village; hot-seat switches it).
func bind_village(v: Village) -> void:
	if _bound:
		for sig in [_bound.economy.changed, _bound.population.changed, _bound.army.changed, _bound.construction.changed]:
			sig.disconnect(_queue_refresh)
		_bound.hero.changed.disconnect(_refresh_hero)
		_bound.events.changed.disconnect(_on_log_changed)
	_bound = v
	for sig in [v.economy.changed, v.population.changed, v.army.changed, v.construction.changed]:
		sig.connect(_queue_refresh)
	v.hero.changed.connect(_refresh_hero)
	v.events.changed.connect(_on_log_changed)
	_selected_unit = null
	_reserve_signature = ""
	_log_dirty = true
	if _send_panel:
		_send_panel.visible = false
		_send_unit_panel.visible = false
		_send_target = -1
		_send_unit_target = -1
	if _village_button:
		_village_button.text = v.village_name
		_village_button.add_theme_color_override("font_color", v.color)
	if _info_panel:
		hide_info()
	_queue_refresh()


func _on_log_changed() -> void:
	_log_dirty = true


# --- hero ----------------------------------------------------------------------------

func _build_hero_panel() -> void:
	_hero_panel = PanelContainer.new()
	_root.add_child(_hero_panel)
	_hero_panel.offset_left = 10
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(340, 0)
	_hero_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_icon(Art.tex("icon_hero"), 34))
	var title := _label("Hero", 22, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("X", Vector2(44, 40))
	close.pressed.connect(func() -> void: _hero_panel.visible = false)
	head.add_child(close)
	_hero_stats = _label("", 17)
	v.add_child(_hero_stats)
	_hero_status = _label("", 15, UiTheme.MUTED)
	_hero_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hero_status)
	_hero_mode_button = _button("", Vector2(0, 50))
	_hero_mode_button.tooltip_text = "Tap to change what the hero does"
	_hero_mode_button.pressed.connect(func() -> void:
		var next := (game.hero.mode + 1) % Hero.MODE_NAMES.size()
		if next == Hero.Mode.SUPPORT and game.villages.size() < 2:
			next = (next + 1) % Hero.MODE_NAMES.size()  # single player: nobody to support
		_do("hero_mode", {"mode": next})
		_refresh_hero())
	v.add_child(_hero_mode_button)
	_hero_support_button = _button("", Vector2(0, 48))
	_hero_support_button.tooltip_text = "Tap to pick the village he supports"
	_hero_support_button.pressed.connect(func() -> void:
		var cur: Village = game.hero.support_target
		_do("hero_support", {"target": _next_other(cur.id if cur else -1)})
		_refresh_hero())
	v.add_child(_hero_support_button)
	_hero_mode_hint = _label("", 14, UiTheme.MUTED)
	_hero_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hero_mode_hint)
	_hero_train_label = _label("", 15)
	_hero_train_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hero_train_label)
	_hero_train_bar = ProgressBar.new()
	_hero_train_bar.custom_minimum_size = Vector2(0, 14)
	_hero_train_bar.show_percentage = false
	_hero_train_bar.add_theme_stylebox_override("background", UiTheme.box(Color("2a1e3a"), Color("15110d"), 1, 4, 0))
	_hero_train_bar.add_theme_stylebox_override("fill", UiTheme.box(Color("b07cff"), Color("b07cff"), 0, 4, 0))
	v.add_child(_hero_train_bar)
	_hero_goto_button = _button("Go to hero", Vector2(0, 48))
	_hero_goto_button.pressed.connect(func() -> void:
		var h: Hero = game.hero
		game.events.debug("camera: go to the hero")
		game.camera.focus(Iso.tile_to_world(h.village.center) if h.dead else h.position))
	v.add_child(_hero_goto_button)
	_hero_panel.visible = false



func _refresh_hero() -> void:
	var h: Hero = game.hero
	_hero_button.text = "XP %d" % h.xp
	_hero_button.modulate = Color(1, 0.55, 0.5) if h.dead else Color.WHITE
	_place_log()
	if not _hero_panel.visible:
		return
	_hero_stats.text = "HP %d / %d     XP %d" % [int(h.hp), int(h.max_hp), h.xp]
	var st := h.status_text()
	_hero_status.text = "Now: " + st
	_hero_mode_button.text = "Mode: %s   (tap to change)" % h.mode_name()
	_hero_mode_hint.text = HERO_MODE_HINTS[h.mode]
	_hero_support_button.visible = h.mode == Hero.Mode.SUPPORT
	if h.support_target:
		_hero_support_button.text = "Support: %s   (tap to change)" % _village_text(h.support_target.id)
	var g := h.ready_grounds()
	var u: MilitaryUnit = g.trainable_unit() if g else null
	_hero_train_label.visible = h.mode == Hero.Mode.TRAIN
	_hero_train_bar.visible = h.mode == Hero.Mode.TRAIN and u != null
	if h.mode == Hero.Mode.TRAIN:
		if u == null:
			_hero_train_label.text = "No unit ready at any Training Grounds: defending instead."
		else:
			_hero_train_label.text = "%s level %d -> %d: %d / %d XP needed. Hero has %d XP to give." % [u.display_name(), u.level + 1, u.level + 2, int(u.train_xp), int(u.train_xp_needed()), h.xp]
			_hero_train_bar.max_value = u.train_xp_needed()
			_hero_train_bar.value = u.train_xp


# --- dock: sidebar (landscape) / bottom sheet (portrait) -----------------------------

func _build_sidebar() -> void:
	_sidebar = PanelContainer.new()
	_root.add_child(_sidebar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_sidebar.add_child(v)

	# Grab handle on top of the bottom sheet: tap it, or swipe up / down.
	_sheet_handle = Control.new()
	_sheet_handle.custom_minimum_size = Vector2(0, 22)
	_sheet_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_handle.tooltip_text = "Swipe up to open, down to close"
	_sheet_handle.draw.connect(func() -> void:
		var w := 72.0
		var r := Rect2((_sheet_handle.size.x - w) / 2.0, 6.0, w, 7.0)
		_sheet_handle.draw_style_box(UiTheme.box(UiTheme.MUTED, UiTheme.MUTED, 0, 4, 0), r))
	_sheet_handle.gui_input.connect(_on_handle_input)
	v.add_child(_sheet_handle)

	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 6)
	v.add_child(_tabs_row)
	for tab in [["build", "Build", "icon_build"], ["village", "Village", "icon_village"], ["army", "Army", "icon_army"]]:
		var b := _button(tab[1], Vector2(0, 48))
		b.icon = Art.tex(tab[2])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 22)
		b.add_theme_font_size_override("font_size", 16)
		b.clip_text = true  # may shrink instead of pushing the panel wider
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab_pressed.bind(tab[0]))
		_tabs_row.add_child(b)
		_tab_buttons[tab[0]] = b

	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_sheet_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_scroll.add_child(pages)
	_tab_pages["build"] = _build_page_build()
	_tab_pages["village"] = _build_page_village()
	_tab_pages["army"] = _build_page_army()
	for p in _tab_pages.values():
		pages.add_child(p)
	pages.minimum_size_changed.connect(func() -> void: _fit_sheet.call_deferred())

	_sidebar_toggle = _button("", Vector2(40, 64))
	_sidebar_toggle.expand_icon = true
	_sidebar_toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_sidebar_toggle)
	_sidebar_toggle.pressed.connect(_toggle_sidebar)
	_sidebar.resized.connect(_place_sidebar_toggle)


## The collapse button: beside the sidebar in landscape, in the sheet's tab row in portrait.
func _toggle_sidebar() -> void:
	if _portrait:
		set_sheet_open(not _sheet_open)
	else:
		_side_open = not _side_open
		_relayout()


func set_sheet_open(open: bool, manual: bool = true) -> void:
	if manual:
		_auto_closed = false
	if open == _sheet_open:
		return
	_sheet_open = open
	if open and _portrait and game.selected:
		game.deselect()  # the sheet and the info panel share the bottom of the screen
	_relayout()


func _on_handle_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_handle_press_y = event.position.y
	else:
		var dy: float = event.position.y - _handle_press_y
		set_sheet_open(not _sheet_open if absf(dy) < DRAG_THRESHOLD else dy < 0.0)
	_sheet_handle.accept_event()


func _on_tab_pressed(tab: String) -> void:
	if _portrait:
		if not _sheet_open:
			set_sheet_open(true)
		elif tab == _current_tab:
			set_sheet_open(false)  # tapping the open tab folds the sheet
	_select_tab(tab)
	if _portrait:
		_relayout()  # the sheet fits the new page's height


## Folds the sheet away while the player needs the map (placing, stationing,
## dragging a unit); `_auto_restore` brings it back afterwards.
func _auto_collapse() -> void:
	if _portrait and _sheet_open:
		set_sheet_open(false, false)
		_auto_closed = true


func _auto_restore() -> void:
	if _auto_closed:
		_auto_closed = false
		set_sheet_open(true, false)


func _place_sidebar_toggle() -> void:
	if _portrait:
		return
	var right := -maxf(_sidebar.size.x, SIDEBAR_W) - 4.0 if _sidebar.visible else -4.0
	_sidebar_toggle.anchor_left = 1.0
	_sidebar_toggle.anchor_right = 1.0
	_sidebar_toggle.anchor_top = 0.0
	_sidebar_toggle.anchor_bottom = 0.0
	_sidebar_toggle.offset_left = right - 40.0
	_sidebar_toggle.offset_right = right
	_sidebar_toggle.offset_top = _top_h + 12.0
	_sidebar_toggle.offset_bottom = _top_h + 76.0


# --- layout ------------------------------------------------------------------------------

## Portrait sheet height. Open: as tall as the page needs, at most about half
## the screen (it scrolls). Re-run when the page's size settles, because
## wrapped text only knows its height once it has been laid out.
func _fit_sheet() -> void:
	if not _portrait:
		return
	var vp := _root.get_viewport_rect().size
	var folded := _handle_and_tabs_height()
	var content: float = _sheet_scroll.get_child(0).get_combined_minimum_size().y + 8.0
	var most := clampf(vp.y * 0.5, 320.0, vp.y - _top_h - 140.0)
	_sheet_h = folded + minf(content, most) if _sheet_open else folded
	_sidebar.offset_top = -_sheet_h
	_place_info_panel()


func _handle_and_tabs_height() -> float:
	var style := _sidebar.get_theme_stylebox("panel")
	var sep := float(_sheet_handle.get_parent().get_theme_constant("separation"))
	return _sheet_handle.get_combined_minimum_size().y + sep + _tabs_row.get_combined_minimum_size().y + style.get_minimum_size().y

func _queue_relayout() -> void:
	if not _relayout_queued:
		_relayout_queued = true
		_relayout.call_deferred()


## Arranges everything for the current orientation and screen size.
func _relayout() -> void:
	_relayout_queued = false
	_portrait = Layout.portrait
	var vp := _root.get_viewport_rect().size

	_topbar_box.vertical = _portrait
	_spacer_land.visible = not _portrait
	_spacer_port.visible = _portrait
	_fit_topbar()
	_top_h = maxf(TOPBAR_H, _topbar.get_combined_minimum_size().y)

	var cols := 2 if _portrait and vp.x >= 640.0 else 1
	for g in _entry_grids:
		g.columns = cols
	_reserve_grid.columns = maxi(4, int((vp.x - 40.0) / 68.0)) if _portrait else 4

	_sheet_handle.visible = _portrait
	if _portrait:
		_sidebar.visible = true
		_sidebar.anchor_left = 0.0
		_sidebar.anchor_right = 1.0
		_sidebar.anchor_top = 1.0
		_sidebar.anchor_bottom = 1.0
		_sidebar.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_sidebar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_sheet_scroll.visible = _sheet_open
		_sidebar.offset_left = 0.0
		_sidebar.offset_right = 0.0
		_sidebar.offset_bottom = 0.0
		_fit_sheet()
		if _sidebar_toggle.get_parent() != _tabs_row:
			_sidebar_toggle.reparent(_tabs_row, false)
		_sidebar_toggle.custom_minimum_size = Vector2(56, 48)
		_sidebar_toggle.icon = Art.tex("icon_sheet_down" if _sheet_open else "icon_sheet_up")
		_sidebar_toggle.tooltip_text = "Close the panel" if _sheet_open else "Open the panel"
	else:
		_sidebar.visible = _side_open
		_sheet_scroll.visible = true
		_sidebar.anchor_left = 1.0
		_sidebar.anchor_right = 1.0
		_sidebar.anchor_top = 0.0
		_sidebar.anchor_bottom = 1.0
		# Grow towards the left so the panel always hugs the right screen edge,
		# even if its content ever wants more than SIDEBAR_W.
		_sidebar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_sidebar.grow_vertical = Control.GROW_DIRECTION_END
		_sidebar.offset_left = -SIDEBAR_W
		_sidebar.offset_right = 0.0
		_sidebar.offset_top = _top_h + 6.0
		_sidebar.offset_bottom = 0.0
		_sheet_h = 0.0
		if _sidebar_toggle.get_parent() != _root:
			_sidebar_toggle.reparent(_root, false)
		_sidebar_toggle.custom_minimum_size = Vector2(40, 64)
		_sidebar_toggle.icon = Art.tex("icon_collapse" if _side_open else "icon_expand")
		_sidebar_toggle.tooltip_text = "Hide / show the sidebar"
		_place_sidebar_toggle()

	_hero_panel.offset_top = _top_h + 6.0
	_trade_panel.offset_top = _top_h + 6.0
	_trade_panel.offset_left = 10.0 if _portrait else 330.0
	for p in [_send_panel, _send_unit_panel]:
		p.offset_top = _top_h + 6.0
		p.offset_left = 10.0 if _portrait else 330.0
	_toasts.offset_top = _top_h + 70.0
	_toasts.offset_right = -SIDEBAR_W if not _portrait and _side_open else 0.0
	_mode_panel.offset_top = _top_h + 10.0
	_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _portrait else TextServer.AUTOWRAP_OFF
	_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _portrait else Control.SIZE_FILL
	_place_mode_panel()
	if _portrait:
		_info_panel.anchor_right = 1.0
		_info_panel.offset_right = -10.0
		_info_panel.custom_minimum_size = Vector2.ZERO
	else:
		_info_panel.anchor_right = 0.0
		_info_panel.offset_right = 370.0
		_info_panel.custom_minimum_size = Vector2(360, 0)
	_place_info_panel()
	_place_log()


func _select_tab(tab: String) -> void:
	_current_tab = tab
	for k in _tab_pages:
		_tab_pages[k].visible = k == tab
		UiTheme.style_selected(_tab_buttons[k], k == tab)


## Grid for a page's entries: one column, two on a wide enough portrait screen.
func _entry_grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 1
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	_entry_grids.append(g)
	return g


## Dock entry: icon, title, description and an action button.
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
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := _button(action_text, Vector2(0, 48))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long costs wrap instead of widening the sidebar
	b.pressed.connect(action)
	v.add_child(b)
	return {"panel": panel, "title": t, "button": b, "desc": d}


func _build_page_build() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var grid := _entry_grid(v)
	for kind in ["tower", "barracks", "farm", "camp", "lightstone", "training"]:
		var spec: Dictionary = Config.BUILDINGS[kind]
		var icon := Art.tex(spec["art"])
		var e := _entry(icon, spec["name"], spec["desc"], "Place  (%s)" % Config.cost_text(spec["cost"]), game.begin_build.bind(kind))
		grid.add_child(e["panel"])
		_build_buttons[kind] = e["button"]
	var hint := _label("Village huts can only be rebuilt: tap a ruined hut inside the walls.", 14, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v


func _build_page_village() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var grid := _entry_grid(v)
	for role in Config.CIVILIAN_ORDER:
		var spec: Dictionary = Config.CIVILIANS[role]
		var action := "Recruit  (%s)" % Config.cost_text(spec["cost"]) if spec.get("recruit", true) else "From a level %d spatial mage (Army)" % Config.ARCHMAGE_LEVEL
		var e := _entry(Art.tex("unit_" + role), spec["name"], spec["desc"], action, _recruit.bind(role))
		grid.add_child(e["panel"])
		_recruit_rows[role] = e
	# Co-op: help another village.
	_send_entry = _entry(Art.tex("unit_caravan"), "Send resources", "Gold, food or material by caravan to another village, minus a tax that grows with the number of players.", "Send resources...", func() -> void: open_send_dialog())
	grid.add_child(_send_entry["panel"])
	_send_entry["panel"].visible = game.villages.size() > 1
	return v


func _recruit(role: String) -> void:
	_do("recruit_villager", {"role": role})


## Runs a command for the player's village; a refusal shows as a toast.
func _do(type: String, args: Dictionary = {}) -> Dictionary:
	var r := game.command(type, args)
	if not r["ok"]:
		toast(r["error"], UiTheme.BAD)
	return r


func _build_page_army() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var grid := _entry_grid(v)
	for kind in Config.MILITARY_ORDER:
		var spec: Dictionary = Config.MILITARY[kind]
		var e := _entry(Art.tex("unit_" + kind), spec["name"], spec["desc"], "Recruit  (%s)" % Config.cost_text(spec["cost"]), func() -> void:
			_do("recruit_unit", {"kind": kind}))
		grid.add_child(e["panel"])
		_military_buttons[kind] = e["button"]
	_reserve_label = _label("", 16)
	_reserve_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_reserve_label)
	_reserve_grid = GridContainer.new()
	_reserve_grid.columns = 4
	_reserve_grid.add_theme_constant_override("h_separation", 6)
	_reserve_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_reserve_grid)
	_selected_info = _label("", 15, UiTheme.MUTED)
	_selected_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_selected_info)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 6)
	v.add_child(rrow)
	_upgrade_reserve_button = _button("Upgrade selected", Vector2(0, 48))
	_upgrade_reserve_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_reserve_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_reserve_button.pressed.connect(func() -> void:
		if _selected_unit:
			open_upgrade(_selected_unit))
	rrow.add_child(_upgrade_reserve_button)
	_send_reserve_button = _button("Send...", Vector2(96, 48))
	_send_reserve_button.tooltip_text = "Send the selected unit to another village"
	_send_reserve_button.pressed.connect(open_send_unit_dialog)
	rrow.add_child(_send_reserve_button)
	return v


func _rebuild_reserve() -> void:
	var reserve := game.army.reserve()
	if _selected_unit and not reserve.has(_selected_unit):
		_selected_unit = null
	_refresh_reserve_texts(reserve)
	# Units downed away from barracks come back here: shown greyed, with a countdown.
	var cards: Array[MilitaryUnit] = reserve.duplicate()
	for u in game.army.downed():
		if not u.revive_at_post:
			cards.append(u)
	# Only rebuild the cards when the reserve really changed, and never while a
	# card is being pressed or dragged (that would free the card under the finger).
	var sig := ",".join(cards.map(func(u: MilitaryUnit) -> String: return "%d:%s:%d:%d:%d" % [u.id, u.kind, u.level, ceili(u.hp), ceili(u.revive_left)])) + "|%s" % (_selected_unit.id if _selected_unit else -1)
	if sig == _reserve_signature or _press_unit != null:
		return
	_reserve_signature = sig
	for c in _reserve_grid.get_children():
		_reserve_grid.remove_child(c)
		c.queue_free()
	for u in cards:
		var card := _button("Lv %d" % (u.level + 1), Vector2(62, 76))
		if u.is_downed():
			card.text = "%d s" % ceili(u.revive_left)
			card.disabled = true
			card.modulate = Color(1, 1, 1, 0.5)
			card.tooltip_text = "Downed: back in %d s" % ceili(u.revive_left)
		elif u.hp < u.max_hp() - 0.5:
			card.text = "Lv %d\n%d HP" % [u.level + 1, ceili(u.hp)]
		card.icon = Art.tex("unit_" + u.kind)
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.expand_icon = true
		card.add_theme_font_size_override("font_size", 14)
		if not u.is_downed():
			card.tooltip_text = "%s: drag onto a tower or barracks, or tap and then tap one" % u.display_name()
		UiTheme.style_selected(card, u == _selected_unit)
		if not u.is_downed():
			card.button_down.connect(_on_card_down.bind(u))
		_reserve_grid.add_child(card)


func _refresh_reserve_texts(reserve: Array[MilitaryUnit]) -> void:
	_reserve_label.text = "Reserve: %d   Walking: %d   On duty: %d\nDrag a unit onto a tower or the training grounds, or tap it and then tap the building. Units walk there, and walk back when withdrawn." % [reserve.size(), game.army.walking().size(), game.army.stationed().size()]
	_upgrade_reserve_button.visible = _selected_unit != null
	_send_reserve_button.visible = _selected_unit != null and game.villages.size() > 1
	_selected_info.visible = _selected_unit != null
	if _selected_unit:
		var lines: Array[String] = ["%s, level %d" % [_selected_unit.display_name(), _selected_unit.level + 1]]
		lines.append_array(_selected_unit.behavior.info_lines(_selected_unit))
		_selected_info.text = "\n".join(lines)
	if _selected_unit:
		var opts := _selected_unit.upgrade_options()
		_upgrade_reserve_button.disabled = opts.is_empty()
		_upgrade_reserve_button.text = "Selected %s is max level" % _selected_unit.display_name().to_lower() if opts.is_empty() else ("Upgrade selected..." if opts.size() > 1 else "Upgrade selected  (%s)" % Config.cost_text(opts[0]["cost"]))
		var info: Array[String] = ["%s, level %d: %d / %d HP" % [_selected_unit.display_name(), _selected_unit.level + 1, ceili(_selected_unit.hp), ceili(_selected_unit.max_hp())]]
		info.append_array(_selected_unit.behavior.info_lines(_selected_unit))
		_selected_info.text = "\n".join(info)


# --- reserve card press / drag ----------------------------------------------------------

func _on_card_down(unit: MilitaryUnit) -> void:
	_press_unit = unit
	_drag_ghost.texture = Art.tex("unit_" + unit.kind)
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
			_auto_collapse()  # uncover the map to drop onto
		if _dragging_unit:
			game.preview_drag(_press_unit, pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var unit := _press_unit
		_press_unit = null
		game.end_drag_preview()
		_queue_refresh()  # catch up on any reserve change deferred during the press
		# The release is left unhandled on purpose so the card button resets.
		if _dragging_unit:
			_dragging_unit = false
			if not is_over_ui(event.position):
				game.drop_unit(unit, event.position)
			_auto_restore()
		else:
			_selected_unit = unit
			_queue_refresh()
			game.begin_station(unit)


func is_over_ui(screen_pos: Vector2) -> bool:
	for c: Control in [_topbar, _sidebar, _sidebar_toggle, _info_panel, _mode_panel, _trade_panel, _overlay, _hero_panel, _settings, _send_panel, _send_unit_panel, _upgrade_panel, _confirm_panel]:
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
	if not _info_panel.visible:
		_auto_collapse()  # a new selection: fold the sheet so the panel has room
		_auto_closed = false  # ...and leave it folded afterwards
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
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			if game.selected_unit:
				show_info(game.unit_info(game.selected_unit))
			elif game.selected:
				show_info(game.building_info(game.selected)))
		_info_actions.add_child(b)
	_place_info_panel.call_deferred()


## Anchor the panel's bottom edge 10px above the screen bottom (portrait: above
## the bottom sheet), growing upwards.
func _place_info_panel() -> void:
	var bottom := -10.0 - (_sheet_h if _portrait else 0.0)
	var h := _info_panel.get_combined_minimum_size().y
	_info_panel.offset_top = bottom - h
	_info_panel.offset_bottom = bottom
	_place_log()


func hide_info() -> void:
	_info_panel.visible = false
	_info_signature = ""
	_place_log()


# --- mode hint, toasts, trade -----------------------------------------------------------

func _build_mode_panel() -> void:
	_mode_panel = PanelContainer.new()
	_root.add_child(_mode_panel)
	_mode_panel.anchor_left = 0.5
	_mode_panel.anchor_right = 0.5
	_mode_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
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


## Shows the hint for placing / stationing (or hides it with ""). In portrait
## the bottom sheet folds away meanwhile and comes back when it's done.
func set_mode_hint(text: String) -> void:
	var was := _mode_panel.visible
	_mode_label.text = text
	_mode_panel.visible = text != ""
	_place_mode_panel()
	if text != "" and not was:
		_auto_collapse()
	elif text == "" and was:
		_auto_restore()


## Centred over the map in landscape; full width under the top bar in portrait.
func _place_mode_panel() -> void:
	if _portrait:
		_mode_panel.anchor_left = 0.0
		_mode_panel.anchor_right = 1.0
		_mode_panel.offset_left = 10.0
		_mode_panel.offset_right = -10.0
		return
	_mode_panel.anchor_left = 0.5
	_mode_panel.anchor_right = 0.5
	_mode_panel.reset_size()
	var shift := SIDEBAR_W / 2.0 if _side_open else 0.0
	_mode_panel.offset_left = -_mode_panel.size.x / 2.0 - shift
	_mode_panel.offset_right = _mode_panel.size.x / 2.0 - shift


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(_toasts)
	_toasts.anchor_left = 0.0
	_toasts.anchor_right = 1.0


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
			_do("buy_materials", {"bundles": bundles}))
		h.add_child(b)
		_trade_buttons.append(b)
	var close := _button("Close", Vector2(0, 44))
	close.pressed.connect(func() -> void: _trade_panel.visible = false)
	v.add_child(close)
	_trade_panel.visible = false


# --- co-op help: send resources, send units ---------------------------------------------

## Other villages, for the "to" toggles.
func _other_villages() -> Array[Village]:
	var out: Array[Village] = []
	for v in game.villages:
		if v != game.player_village:
			out.append(v)
	return out


## Next village after `id` among the others (wraps round); -1 if there are none.
func _next_other(id: int) -> int:
	var others := _other_villages()
	if others.is_empty():
		return -1
	for i in others.size():
		if others[i].id == id:
			return others[(i + 1) % others.size()].id
	return others[0].id


func _village_text(id: int) -> String:
	if id < 0:
		return "-"
	var v := game.villages[id]
	return v.village_name + ("  (fallen)" if v.fallen else "")


func _build_send_dialog() -> void:
	_send_panel = PanelContainer.new()
	_root.add_child(_send_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(380, 0)
	_send_panel.add_child(v)
	v.add_child(_label("Send resources", 20, UiTheme.GOLD))
	v.add_child(_label("A caravan takes them to the other village's centre.", 14, UiTheme.MUTED))
	for res in Economy.RESOURCES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		v.add_child(row)
		row.add_child(_icon(Art.tex("icon_" + res), 30))
		var l := _label("0", 18)
		l.custom_minimum_size.x = 64
		row.add_child(l)
		_send_labels[res] = l
		for step in [-50, -10, 10, 50]:
			var b := _button("%+d" % step, Vector2(50, 44))
			b.add_theme_font_size_override("font_size", 15)
			b.pressed.connect(func() -> void: _step_send(res, step))
			row.add_child(b)
		var all := _button("All", Vector2(50, 44))
		all.add_theme_font_size_override("font_size", 15)
		all.pressed.connect(func() -> void: _step_send(res, 1 << 30))
		row.add_child(all)
	_send_target_button = _button("", Vector2(0, 48))
	_send_target_button.tooltip_text = "Tap to pick the receiving village"
	_send_target_button.pressed.connect(func() -> void:
		_send_target = _next_other(_send_target)
		_refresh_send())
	v.add_child(_send_target_button)
	_send_tax_label = _label("", 15)
	_send_tax_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_send_tax_label)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	_send_button = _button("Send caravan", Vector2(0, 50))
	_send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_good(_send_button)
	_send_button.pressed.connect(func() -> void:
		var args := {"target": _send_target}
		args.merge(_send_amounts)
		if _do("send_caravan", args)["ok"]:
			toast("The caravan sets off for %s" % game.villages[_send_target].village_name, UiTheme.GOLD)
			for res in _send_amounts:
				_send_amounts[res] = 0
			_send_panel.visible = false
		_refresh_send())
	h.add_child(_send_button)
	var close := _button("Close", Vector2(0, 50))
	close.pressed.connect(func() -> void: _send_panel.visible = false)
	h.add_child(close)
	_send_panel.visible = false

	# Sending a reserve unit.
	_send_unit_panel = PanelContainer.new()
	_root.add_child(_send_unit_panel)
	var u := VBoxContainer.new()
	u.add_theme_constant_override("separation", 8)
	u.custom_minimum_size = Vector2(340, 0)
	_send_unit_panel.add_child(u)
	_send_unit_title = _label("", 20, UiTheme.GOLD)
	u.add_child(_send_unit_title)
	u.add_child(_label("It walks there and joins that village's army. It can't be called back.", 14, UiTheme.MUTED))
	(u.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_send_unit_target_button = _button("", Vector2(0, 48))
	_send_unit_target_button.pressed.connect(func() -> void:
		_send_unit_target = _next_other(_send_unit_target)
		_refresh_send())
	u.add_child(_send_unit_target_button)
	var hu := HBoxContainer.new()
	hu.add_theme_constant_override("separation", 6)
	u.add_child(hu)
	_send_unit_go = _button("Send", Vector2(0, 50))
	_send_unit_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_good(_send_unit_go)
	_send_unit_go.pressed.connect(func() -> void:
		if _selected_unit and _do("send_unit", {"unit": _selected_unit.nid, "target": _send_unit_target})["ok"]:
			toast("The %s sets off for %s" % [_selected_unit.display_name().to_lower(), game.villages[_send_unit_target].village_name], UiTheme.GOLD)
			_selected_unit = null
			_send_unit_panel.visible = false
			_queue_refresh())
	hu.add_child(_send_unit_go)
	var close_u := _button("Close", Vector2(0, 50))
	close_u.pressed.connect(func() -> void: _send_unit_panel.visible = false)
	hu.add_child(close_u)
	_send_unit_panel.visible = false


func open_send_dialog() -> void:
	if _send_target < 0 or game.villages[_send_target] == game.player_village:
		_send_target = _next_other(-1)
	_trade_panel.visible = false
	_hero_panel.visible = false
	_send_unit_panel.visible = false
	_send_panel.visible = true
	_refresh_send()


func open_send_unit_dialog() -> void:
	if _selected_unit == null:
		return
	if _send_unit_target < 0 or game.villages[_send_unit_target] == game.player_village:
		_send_unit_target = _next_other(-1)
	_send_panel.visible = false
	_send_unit_panel.visible = true
	_refresh_send()


func _step_send(res: String, step: int) -> void:
	var have := int(game.economy.amount(res))
	_send_amounts[res] = clampi(_send_amounts[res] + step, 0, have)
	_refresh_send()


func _refresh_send() -> void:
	if _send_panel == null:
		return
	var tax := Config.help_tax(game.villages.size())
	var any := false
	var got: Array[String] = []
	for res in Economy.RESOURCES:
		_send_amounts[res] = mini(_send_amounts[res], int(game.economy.amount(res)))
		(_send_labels[res] as Label).text = str(_send_amounts[res])
		if _send_amounts[res] > 0:
			any = true
			got.append("%d %s" % [floori(_send_amounts[res] * (1.0 - tax)), "material" if res == "materials" else res])
	_send_target_button.text = "To: %s   (tap to change)" % _village_text(_send_target)
	var to_name := game.villages[_send_target].village_name if _send_target >= 0 else "-"
	_send_tax_label.text = "Tax %d %%: %s receives %s" % [roundi(tax * 100.0), to_name, ", ".join(got) if any else "nothing yet"]
	_send_button.disabled = not any or _send_target < 0
	if _selected_unit:
		_send_unit_title.text = "Send %s (level %d)" % [_selected_unit.display_name(), _selected_unit.level + 1]
	_send_unit_target_button.text = "To: %s   (tap to change)" % _village_text(_send_unit_target)
	_send_unit_go.disabled = _selected_unit == null or _send_unit_target < 0


# --- unit upgrades: next level, specialisations, the Spatial Archmage ----------------------

## The upgrade dialog for `unit`: one button per option (MilitaryUnit.upgrade_options).
func open_upgrade(unit: MilitaryUnit) -> void:
	_upgrade_unit = unit
	_confirm_panel.visible = false
	_upgrade_title.text = "Upgrade %s (level %d)" % [unit.display_name(), unit.level + 1]
	for c in _upgrade_options.get_children():
		_upgrade_options.remove_child(c)
		c.queue_free()
	for opt in unit.upgrade_options():
		# (a wrapping button needs a width to wrap in, or it measures one word per line)
		var b := _button("%s   (%s)" % [MilitaryUnit.option_text(opt), Config.cost_text(opt["cost"])], Vector2(_upgrade_width(), 52))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = not game.economy.can_afford(opt["cost"]) or not unit.is_available()
		if opt["archmage"]:
			b.add_theme_color_override("font_color", Color("d8c0ff"))
			b.pressed.connect(func() -> void: _ask_archmage(unit))
		elif opt["to"] != unit.kind:
			UiTheme.style_primary(b)
			var to: String = opt["to"]
			b.pressed.connect(func() -> void: _pick_upgrade(unit, to))
		else:
			b.pressed.connect(func() -> void: _pick_upgrade(unit, ""))
		_upgrade_options.add_child(b)
	_upgrade_hint.text = "From level %d on, a unit can also specialise (it starts again at level 1)." % Config.BRANCH_MIN_LEVEL if not unit.spec().get("branches", []).is_empty() else ""
	_upgrade_hint.visible = _upgrade_hint.text != ""
	_upgrade_hint.custom_minimum_size.x = _upgrade_width()
	_upgrade_title.custom_minimum_size.x = _upgrade_width()
	_upgrade_panel.visible = true
	_fit_dialog(_upgrade_panel)
	_fit_dialog.call_deferred(_upgrade_panel)  # (again once the wrapped texts are laid out)


## Width of the upgrade dialog's content: 420 px, less on narrow screens.
func _upgrade_width() -> float:
	return minf(420.0, get_viewport().get_visible_rect().size.x - 64.0)


## Shrinks a centred dialog to its content and keeps it on screen.
func _fit_dialog(p: Control) -> void:
	p.reset_size()
	var vp := get_viewport().get_visible_rect().size
	p.position = ((vp - p.size) / 2.0).max(Vector2(8, 8))


func _pick_upgrade(unit: MilitaryUnit, to: String) -> void:
	if _do("upgrade_unit", {"unit": unit.nid, "to": to})["ok"]:
		_upgrade_panel.visible = false
		_queue_refresh()


## The Spatial Archmage leaves the army for good: ask first.
func _ask_archmage(unit: MilitaryUnit) -> void:
	_confirm_text.custom_minimum_size.x = _upgrade_width()
	_confirm_text.text = "This %s will leave your army for good and move into a hut as the Spatial Archmage, a civilian. Continue?" % unit.display_name().to_lower()
	_confirm_yes.text = "Become the Spatial Archmage  (%s)" % Config.cost_text(Config.ARCHMAGE_COST)
	for c in _confirm_yes.pressed.get_connections():
		_confirm_yes.pressed.disconnect(c["callable"])
	_confirm_yes.pressed.connect(func() -> void:
		if _do("promote_archmage", {"unit": unit.nid})["ok"]:
			toast("The Spatial Archmage moves into a hut", Color("d8c0ff"))
			_confirm_panel.visible = false
			_upgrade_panel.visible = false
			_selected_unit = null
			_queue_refresh())
	_confirm_panel.visible = true
	_fit_dialog(_confirm_panel)
	_fit_dialog.call_deferred(_confirm_panel)


func _build_upgrade_dialogs() -> void:
	_upgrade_panel = PanelContainer.new()
	_root.add_child(_upgrade_panel)
	_upgrade_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_upgrade_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_upgrade_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_upgrade_panel.add_child(v)
	_upgrade_title = _label("", 21, UiTheme.GOLD)
	v.add_child(_upgrade_title)
	_upgrade_options = VBoxContainer.new()
	_upgrade_options.add_theme_constant_override("separation", 6)
	v.add_child(_upgrade_options)
	_upgrade_hint = _label("", 14, UiTheme.MUTED)
	_upgrade_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_upgrade_hint)
	var close := _button("Close", Vector2(0, 44))
	close.pressed.connect(func() -> void: _upgrade_panel.visible = false)
	v.add_child(close)
	_upgrade_panel.visible = false
	_confirm_panel = PanelContainer.new()
	_root.add_child(_confirm_panel)
	_confirm_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm_panel.add_theme_stylebox_override("panel", UiTheme.box(Color("241838"), Color("b08ae0"), 3, 12, 16))
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 10)
	c.custom_minimum_size = Vector2(400, 0)
	_confirm_panel.add_child(c)
	c.add_child(_label("Spatial Archmage", 24, Color("d8c0ff")))
	_confirm_text = _label("", 16)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_confirm_text)
	_confirm_yes = _button("", Vector2(0, 54))
	UiTheme.style_good(_confirm_yes)
	c.add_child(_confirm_yes)
	var no := _button("Cancel", Vector2(0, 46))
	no.pressed.connect(func() -> void: _confirm_panel.visible = false)
	c.add_child(no)
	_confirm_panel.visible = false


# --- event log field -------------------------------------------------------------------

const LOG_COLORS := [Color("b8ab90"), Color("efe3c8"), Color("ff9a86")]  # debug, info, important
const LOG_LINE_H := 23.0  # a 15 px line with its outline


## Recent game events as plain, slightly see-through text (no box): bottom
## left in landscape, across the bottom in portrait. Never catches taps.
func _build_log() -> void:
	_log_box = VBoxContainer.new()
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.alignment = BoxContainer.ALIGNMENT_END  # newest at the bottom
	_log_box.add_theme_constant_override("separation", 0)
	_log_box.anchor_top = 1.0
	_log_box.anchor_bottom = 1.0
	_log_box.clip_contents = true  # never spills past its capped height
	_root.add_child(_log_box)


## Above the info panel if one is open, else above the bottom sheet (portrait)
## or the screen edge; at most MAX_SHOWN lines high.
func _place_log() -> void:
	if _log_box == null:
		return
	var vp := _root.get_viewport_rect().size
	var bottom := -10.0 - (_sheet_h if _portrait else 0.0)
	if _info_panel.visible:
		bottom = _info_panel.offset_top - 6.0
	var right := vp.x - 10.0 if _portrait else minf(560.0, vp.x - SIDEBAR_W - 60.0)
	_log_box.offset_left = 10.0
	_log_box.offset_right = right
	_log_box.offset_bottom = bottom
	var top := bottom - LOG_LINE_H * EventLog.MAX_SHOWN
	if _hero_panel.visible:  # stay below the hero panel (it opens top left)
		top = maxf(top, _hero_panel.get_global_rect().end.y + 6.0 - vp.y)
	_log_box.offset_top = minf(top, bottom)


func _refresh_log() -> void:
	_log_dirty = false
	var shown := game.events.visible_entries()
	while _log_box.get_child_count() < shown.size():
		var nl := _label("", 15)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size.y = LOG_LINE_H
		nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
		nl.add_theme_constant_override("outline_size", 3)
		_log_box.add_child(nl)
	var now := game.events.now()
	for i in _log_box.get_child_count():
		var l := _log_box.get_child(i) as Label
		l.visible = i < shown.size()
		if not l.visible:
			continue
		var e: Dictionary = shown[i]
		l.text = e["text"]
		var age: float = now - e["time"]
		var fade := clampf((EventLog.LIFETIME - age) / 3.0, 0.0, 1.0)  # fades out in its last 3 s
		l.add_theme_color_override("font_color", Color(LOG_COLORS[e["level"]], 0.78 * fade))


## Log lines currently displayed.
func log_lines() -> Array[String]:
	var out: Array[String] = []
	for l in _log_box.get_children():
		if (l as Label).visible:
			out.append((l as Label).text)
	return out


# --- settings dialog -----------------------------------------------------------------------

const GRAYSCALE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g) * 0.85, 1.0);
}
"""


func _build_settings() -> void:
	# Co-op pause: the map and HUD below the top bar turn grey (the top bar stays in colour).
	_pause_gray = ColorRect.new()
	var pmat := ShaderMaterial.new()
	var psh := Shader.new()
	psh.code = GRAYSCALE_SHADER
	pmat.shader = psh
	_pause_gray.material = pmat
	_pause_gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pause_gray)
	_pause_gray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_gray.visible = false
	_settings = Control.new()
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Everything drawn before this (the map and the rest of the HUD) turns grey.
	var gray := ColorRect.new()
	_gray = gray
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRAYSCALE_SHADER
	mat.shader = sh
	gray.material = mat
	gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings.add_child(gray)
	gray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14"), UiTheme.GOLD, 4, 14, 22))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(380, 0)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_icon(Art.tex("icon_settings"), 40))
	head.add_child(_label("Settings", 34, UiTheme.GOLD))
	_settings_continue = _button("Continue", Vector2(0, 60))
	_settings_continue.add_theme_font_size_override("font_size", 24)
	UiTheme.style_good(_settings_continue)
	_settings_continue.pressed.connect(close_settings)
	v.add_child(_settings_continue)
	_settings_log_button = _button("", Vector2(0, 56))
	_settings_log_button.tooltip_text = "Which game events the log shows"
	_settings_log_button.pressed.connect(func() -> void:
		game.events.cycle_level()
		game.events.debug("log level: %s" % game.events.level_name())
		_refresh_settings())
	v.add_child(_settings_log_button)
	_settings_lang_button = _button("", Vector2(0, 64))
	_settings_lang_button.expand_icon = true
	_settings_lang_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_lang_button.pressed.connect(func() -> void:
		Settings.cycle_language()
		game.events.debug("language: %s" % Settings.language_name())
		_refresh_settings())
	v.add_child(_settings_lang_button)
	_settings_note = _label("The game keeps running.", 15, UiTheme.MUTED)
	_settings_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_note.visible = false
	v.add_child(_settings_note)
	_settings_title_button = _button("Back to title", Vector2(0, 56))
	UiTheme.style_danger(_settings_title_button)
	_settings_title_button.pressed.connect(func() -> void: game.go_to_title())
	v.add_child(_settings_title_button)
	_settings.visible = false


## Pauses the game (remembering its speed), greys it out and shows the dialog.
func open_settings() -> void:
	if _settings.visible:
		return
	_speed_before = _speed_index
	# Only the host pauses; for everyone else the game keeps running.
	var pauses := game.is_host_player()
	if pauses:
		get_tree().paused = true
	_gray.visible = pauses and not game.networked  # (co-op: _pause_gray, which spares the top bar)
	_settings_note.visible = not pauses
	_settings_title_button.text = "Leave game" if game.networked else "Back to title"
	_trade_panel.visible = false
	_refresh_settings()
	_settings.visible = true
	game.events.debug("open settings (game paused)" if pauses else "open settings")


## Back to the game at the speed it was running at before.
func close_settings() -> void:
	if not _settings.visible:
		return
	_settings.visible = false
	game.events.debug("close settings")
	if game.is_host_player():
		set_speed_index(_speed_before)


func _refresh_settings() -> void:
	_settings_log_button.text = "Log level: %s" % game.events.level_name()
	_settings_lang_button.icon = Art.tex(Settings.language_flag())
	_settings_lang_button.tooltip_text = "Language: %s" % Settings.language_name()


# --- drag feedback -------------------------------------------------------------------------

func is_over_dock(screen_pos: Vector2) -> bool:
	return _sidebar.is_visible_in_tree() and _sidebar.get_global_rect().has_point(screen_pos)


## The unit's image under the pointer while it is dragged. `state`: "move" (over
## a free post), "withdraw" (over the dock), "none" (nothing would happen here).
func show_drag_feedback(tex: Texture2D, screen_pos: Vector2, state: String) -> void:
	_drag_ghost.texture = tex
	_drag_ghost.visible = true
	_drag_ghost.position = screen_pos - _drag_ghost.size / 2.0 - Vector2(0, 30)
	match state:
		"move":
			_drag_ghost.modulate = Color(0.75, 1.25, 0.75, 0.95)
		"withdraw":
			_drag_ghost.modulate = Color(1, 1, 1, 0.95)
		_:
			_drag_ghost.modulate = Color(1, 1, 1, 0.55)
	var withdraw := state == "withdraw"
	_sidebar.modulate = Color(0.8, 1.2, 0.8) if withdraw else Color.WHITE
	_dock_hint.visible = withdraw
	if withdraw:
		var r := _sidebar.get_global_rect()
		_dock_hint.size = Vector2(r.size.x, 30)
		_dock_hint.position = Vector2(r.position.x, r.position.y - 36 if _portrait else r.position.y + 60)


func hide_drag_feedback() -> void:
	_drag_ghost.visible = false
	_sidebar.modulate = Color.WHITE
	_dock_hint.visible = false


# --- overlays -------------------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)
	# Anchors AND offsets: anchors alone left a zero-size box in the top-left corner.
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_overlay_menu_button = _button("Main menu", Vector2(0, 56))
	_overlay_menu_button.pressed.connect(func() -> void: game.go_to_title())
	v.add_child(_overlay_menu_button)
	_overlay.visible = false


## Co-op client: the host paused the game (or opened its settings).
func set_host_paused(v: bool) -> void:
	if _paused_banner == null:
		_paused_banner = _label("Paused by the host", 26, UiTheme.GOLD)
		_paused_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_paused_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_paused_banner)
		_paused_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_paused_banner.offset_top = _top_h + 60.0
		_paused_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_paused_banner.visible = v
	_host_paused = v
	_update_pause_gray()


func _paused_banner_off() -> void:
	_host_paused = false
	if _paused_banner:
		_paused_banner.visible = false


## Co-op only: grey below the top bar while the game is paused (by the host:
## settings open or speed 0; for clients, as the host's snapshots say).
func _update_pause_gray() -> void:
	var on := game.networked and not _overlay.visible and (_host_paused if game.is_client else get_tree().paused)
	_pause_gray.visible = on
	if on:
		_pause_gray.offset_top = _topbar.get_global_rect().end.y
		# What's drawn after the veil keeps its colour: it sits over the map, the
		# sidebar and the panels, under toasts, dialogs and the paused banner.
		var at := _toasts.get_index()
		if _pause_gray.get_index() != at - 1:
			_root.move_child(_pause_gray, at - 1 if _pause_gray.get_index() < at else at)


## Co-op: the session is over (the host left, connection lost).
func show_session_ended(reason: String) -> void:
	_overlay_title.text = reason
	_overlay_title.add_theme_color_override("font_color", UiTheme.BAD)
	_overlay_sub.text = "The game can't go on without the host."
	_overlay_button.text = "Main menu"
	_overlay_menu_button.visible = false  # (the main button already goes there)
	_overlay.visible = true
	_info_panel.visible = false
	_paused_banner_off()
	_update_pause_gray()
	_connect_overlay(func() -> void: game.go_to_title())


func show_game_over(title: String, subtitle: String) -> void:
	_overlay_title.text = title
	_overlay_title.add_theme_color_override("font_color", UiTheme.BAD)
	_overlay_sub.text = subtitle
	_overlay_button.text = "Main menu" if game.networked else "Try again"
	_overlay_menu_button.visible = not game.networked  # (networked: the main button is the way out)
	_overlay.visible = true
	_info_panel.visible = false
	_connect_overlay(func() -> void: game.go_to_title() if game.networked else game.restart())


func _connect_overlay(cb: Callable) -> void:
	for c in _overlay_button.pressed.get_connections():
		_overlay_button.pressed.disconnect(c["callable"])
	_overlay_button.pressed.connect(cb)


# --- refresh ---------------------------------------------------------------------------------

func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _process(delta: float) -> void:
	if game.networked:
		_update_pause_gray()
	if _log_dirty or not game.events.entries.is_empty():
		_refresh_log()  # (every frame while messages fade)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_refresh_wave()
		_refresh_resources()
		_refresh_hero()
		if not game.army.downed().is_empty():
			_rebuild_reserve()  # (downed countdowns)


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
		elif role == "forester":
			(e["desc"] as Label).text = "%s\nWithout a camp: %d" % [Config.CIVILIANS[role]["desc"], game.population.free_foresters().size()]
		elif role == "gatherer":
			(e["desc"] as Label).text = "%s\nCorpses lying around: %d" % [Config.CIVILIANS[role]["desc"], game.corpses.count()]
	for kind in _military_buttons:
		(_military_buttons[kind] as Button).disabled = not game.economy.can_afford(Config.MILITARY[kind]["cost"])
	for b in _trade_buttons:
		b.disabled = false
	_rebuild_reserve()
	_refresh_send()


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
