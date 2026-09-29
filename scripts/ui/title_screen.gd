class_name TitleScreen
extends Control
## Title screen: backdrop, game name and a menu in pages:
##   main         - Singleplayer, Multiplayer, Exit;
##   Singleplayer - Play, Difficulty, Levels, Back;
##   Multiplayer  - village name and colour, host / join, lobby (MultiplayerMenu).

const LEVEL_SCENE := "res://scenes/main.tscn"
## Levels offered on the Levels panel. Only the first exists so far.
const LEVELS: Array[Dictionary] = [
	{"name": "The Last Outpost", "available": true},
	{"name": "Coming soon", "available": false},
	{"name": "Coming soon", "available": false},
]

var singleplayer_button: Button
var multiplayer_button: Button
var exit_button: Button
var mp_menu: MultiplayerMenu
var play_button: Button
var difficulty_button: Button
var map_button: Button
var seed_edit: LineEdit
var levels_button: Button
var back_button: Button
var levels_panel: PanelContainer
var _menu: VBoxContainer
var _main_page: VBoxContainer
var _sp_page: VBoxContainer
var _title: Label


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0

	var bg := TextureRect.new()
	bg.texture = Art.tex("title_bg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	_title = title
	title.text = "Veliron's Outpost"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_color_override("font_outline_color", UiTheme.INK)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	_menu.custom_minimum_size = Vector2(320, 0)
	add_child(_menu)

	_main_page = _page()
	singleplayer_button = _menu_button(_main_page, "Singleplayer", func() -> void: show_page(_sp_page))
	UiTheme.style_primary(singleplayer_button)
	multiplayer_button = _menu_button(_main_page, "Multiplayer", func() -> void: show_page(mp_menu))
	exit_button = _menu_button(_main_page, "Exit", func() -> void: get_tree().quit())
	exit_button.visible = not OS.has_feature("web")  # browsers can't close the tab
	_sp_page = _page()
	play_button = _menu_button(_sp_page, "Play", _play)
	UiTheme.style_primary(play_button)
	difficulty_button = _menu_button(_sp_page, "", _cycle_difficulty)
	map_button = _menu_button(_sp_page, "", func() -> void:
		Settings.cycle_map_type()
		_update_difficulty())
	map_button.tooltip_text = "The kind of land: Temperate, Highlands, Coast, Desert, Volcanic or Random"
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "Map seed (empty: random)"
	seed_edit.custom_minimum_size = Vector2(0, 48)
	seed_edit.add_theme_font_size_override("font_size", 18)
	seed_edit.text = str(Settings.map_seed) if Settings.map_seed != 0 else ""
	seed_edit.text_changed.connect(func(t: String) -> void: Settings.map_seed = Settings.parse_seed(t))
	_sp_page.add_child(seed_edit)
	_sp_page.move_child(seed_edit, map_button.get_index() + 1)
	levels_button = _menu_button(_sp_page, "Levels", func() -> void: levels_panel.visible = true)
	back_button = _menu_button(_sp_page, "Back", func() -> void: show_page(_main_page))
	mp_menu = MultiplayerMenu.new()
	_menu.add_child(mp_menu)
	mp_menu.back_pressed.connect(func() -> void: show_page(_main_page))
	# Back from a game (or a lobby left open): straight to the multiplayer pages.
	show_page(mp_menu if Net.is_online() and not Net.in_game else _main_page)
	_update_difficulty()
	_build_levels_panel()
	get_viewport().size_changed.connect(_layout)
	_layout()


## Landscape: title on top, menu on the left over the backdrop.
## Portrait: smaller title, menu centred lower down.
func _layout() -> void:
	var portrait := Layout.portrait
	_title.add_theme_font_size_override("font_size", 64 if portrait else 84)
	_title.anchor_top = 0.1 if portrait else 0.08
	_title.anchor_bottom = _title.anchor_top
	_title.offset_left = 16.0
	_title.offset_right = -16.0
	var mp := mp_menu != null and mp_menu.visible
	var half := 200.0 if mp else 160.0
	var x := 0.5 if portrait else 0.07
	_menu.anchor_left = x
	_menu.anchor_right = x
	_menu.offset_left = -half if portrait else 0.0
	_menu.offset_right = half if portrait else 0.0
	# The multiplayer pages are taller: they start higher up.
	_menu.anchor_top = (0.28 if mp else 0.5) if portrait else (0.22 if mp else 0.42)
	_menu.anchor_bottom = _menu.anchor_top


func _page() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 14)
	_menu.add_child(p)
	return p


## Shows one menu page (the main page or the Singleplayer page).
func show_page(page: VBoxContainer) -> void:
	_main_page.visible = page == _main_page
	_sp_page.visible = page == _sp_page
	if mp_menu:
		mp_menu.visible = page == mp_menu
		_layout()
	if levels_panel:
		levels_panel.visible = false


func in_singleplayer_page() -> bool:
	return _sp_page.visible


func _menu_button(page: VBoxContainer, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	page.add_child(b)
	return b


func _build_levels_panel() -> void:
	levels_panel = PanelContainer.new()
	add_child(levels_panel)
	levels_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	levels_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	levels_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(420, 0)
	levels_panel.add_child(v)
	var head := Label.new()
	head.text = "Levels"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 36)
	head.add_theme_color_override("font_color", UiTheme.GOLD)
	v.add_child(head)
	for i in LEVELS.size():
		var lv: Dictionary = LEVELS[i]
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, lv["name"]]
		b.custom_minimum_size = Vector2(0, 58)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = not lv["available"]
		b.pressed.connect(func() -> void:
			Settings.level = i + 1
			_play())
		v.add_child(b)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 52)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: levels_panel.visible = false)
	v.add_child(back)
	levels_panel.visible = false


func _cycle_difficulty() -> void:
	Settings.cycle_difficulty()
	_update_difficulty()


func _update_difficulty() -> void:
	difficulty_button.text = "Difficulty: %s" % Settings.difficulty_name()
	map_button.text = "Map: %s" % Settings.map_type_name()


func _play() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if mp_menu.visible:
					return
				if in_singleplayer_page():
					_play()
				else:
					show_page(_sp_page)
			KEY_ESCAPE:
				if levels_panel.visible:
					levels_panel.visible = false
				elif mp_menu.visible and Net.is_online():
					Net.leave()
				else:
					show_page(_main_page)
