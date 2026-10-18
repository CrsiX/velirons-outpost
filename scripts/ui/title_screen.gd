class_name TitleScreen
extends Control

const EDITOR_SCENE := "res://scenes/map_editor.tscn"
## Title screen: a game playing itself behind (TitleBackdrop), game name and a menu in pages:
##   main         - Campaign, Singleplayer, Multiplayer, Tutorial, Library, Map Editor, Exit;
##   Campaign     - the campaign's scenarios (Campaign), each with a line about it, Back;
##   Singleplayer - Continue (the newest single-player save, when there is one),
##                  Play, Load..., Difficulty, Map (a type, or a map file: Custom...),
##                  the village (a map file with several), seed, Back;
##   Multiplayer  - village name and colour, host / join, lobby (MultiplayerMenu).

var campaign_button: Button
## The campaign page's button per scenario (index 0: scenario 1).
var scenario_buttons: Array[Button] = []
var singleplayer_button: Button
var multiplayer_button: Button
var exit_button: Button
var mp_menu: MultiplayerMenu
var play_button: Button
## The newest single-player save (docs/save-design.md §4.1), and what it is.
var continue_button: Button
var continue_label: Label
var load_button: Button
var save_list: SaveList
var _continue_path := ""
var tutorial_button: Button
var difficulty_button: Button
var map_button: Button
var seed_edit: LineEdit
var library_button: Button
var editor_button: Button
var village_button: Button
var back_button: Button
## Picks a map file for Singleplayer (docs/map-editor-design.md §8).
var picker: MapPicker
var library: Library
## The game playing behind the menu (Config.TITLE_BACKDROP).
var backdrop: TitleBackdrop
var _menu: VBoxContainer
var _main_page: VBoxContainer
var _sp_page: VBoxContainer
var _campaign_page: VBoxContainer
var _title: Label


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Engine.time_scale = 1.0
	if Settings.editor_play:  # (back from a game the map editor started: its map isn't the menu's)
		Settings.editor_play = false
		Settings.custom_map = null

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	backdrop = TitleBackdrop.new()  # (a game playing itself; fades in once it's made)
	backdrop.name = "Backdrop"
	add_child(backdrop)

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
	campaign_button = _menu_button(_main_page, "Campaign", func() -> void: show_page(_campaign_page), "icon_campaign")
	campaign_button.tooltip_text = "The story of Veliron's last outpost, scenario by scenario"
	singleplayer_button = _menu_button(_main_page, "Singleplayer", func() -> void: show_page(_sp_page), "icon_singleplayer")
	multiplayer_button = _menu_button(_main_page, "Multiplayer", func() -> void: show_page(mp_menu), "icon_multiplayer")
	tutorial_button = _menu_button(_main_page, "Tutorial", play_tutorial, "icon_tutorial")
	tutorial_button.tooltip_text = "A guided first game: learn the basics step by step"
	library_button = _menu_button(_main_page, "Library", func() -> void: library.open(), "icon_book")
	library_button.tooltip_text = "Enemies, units, buildings, villagers, hero, places"
	editor_button = _menu_button(_main_page, "Map Editor", func() -> void: get_tree().change_scene_to_file(EDITOR_SCENE), "icon_map_editor")
	editor_button.tooltip_text = "Make, look into and change maps"
	exit_button = _menu_button(_main_page, "Exit", func() -> void: get_tree().quit(), "icon_exit")
	exit_button.visible = not OS.has_feature("web")  # browsers can't close the tab
	_sp_page = _page()
	continue_button = _menu_button(_sp_page, "Continue", continue_game)
	UiTheme.style_primary(continue_button)
	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 16)
	continue_label.add_theme_color_override("font_color", UiTheme.MUTED)
	_sp_page.add_child(continue_label)
	play_button = _menu_button(_sp_page, "Play", _play)
	load_button = _menu_button(_sp_page, "Load...", func() -> void:
		save_list.choose(false, func(path: String) -> void: _start_save(path)))
	load_button.tooltip_text = "Your saved games (also each game's autosave after every wave)"
	difficulty_button = _menu_button(_sp_page, "", _cycle_difficulty)
	map_button = _menu_button(_sp_page, "", _cycle_map)
	map_button.tooltip_text = "The kind of land: Temperate, Highlands, Coast, Desert, Volcanic or Random; or Custom: a map file"
	village_button = _menu_button(_sp_page, "", func() -> void:
		Settings.custom_village = (Settings.custom_village + 1) % Settings.custom_map.villages.size()
		_update_sp_buttons())
	village_button.tooltip_text = "Which of the map's villages you play (the others stand empty)"
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "Map seed (empty: random)"
	seed_edit.custom_minimum_size = Vector2(0, 48)
	seed_edit.add_theme_font_size_override("font_size", 18)
	seed_edit.text = str(Settings.map_seed) if Settings.map_seed != 0 else ""
	seed_edit.text_changed.connect(func(t: String) -> void: Settings.map_seed = Settings.parse_seed(t))
	_sp_page.add_child(seed_edit)
	_sp_page.move_child(seed_edit, map_button.get_index() + 1)
	back_button = _menu_button(_sp_page, "Back", func() -> void: show_page(_main_page))
	_build_campaign_page()
	mp_menu = MultiplayerMenu.new()
	_menu.add_child(mp_menu)
	mp_menu.back_pressed.connect(func() -> void: show_page(_main_page))

	if Net.is_online() and not Net.in_game:
		show_page(mp_menu)
	else:
		show_page(_main_page)

	_update_sp_buttons()
	library = Library.new()
	add_child(library)
	picker = MapPicker.new()
	add_child(picker)
	mp_menu.picker = picker
	save_list = SaveList.new()
	add_child(save_list)
	save_list.closed.connect(_update_sp_buttons)
	mp_menu.save_list = save_list
	get_viewport().size_changed.connect(_layout)
	# Pages change height (Singleplayer, the multiplayer join page and lobby): fit again.
	_menu.minimum_size_changed.connect(func() -> void: _layout.call_deferred())
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
	var wide := mp and mp_menu.lobby.visible and not portrait  # (the lobby's two panes)
	var vp := get_viewport_rect().size
	var half := minf(vp.x / 2.0 - 16.0, 420.0 if wide else (200.0 if mp else 160.0))
	var x := 0.5 if portrait or wide else 0.07
	_menu.anchor_left = x
	_menu.anchor_right = x
	_menu.offset_left = -half if portrait or wide else 0.0
	_menu.offset_right = half if portrait or wide else 0.0
	# Where the menu would like to start; then moved up so its bottom stays on
	# screen (never over the title). The multiplayer pages are taller.
	var want := ((0.28 if mp else 0.5) if portrait else (0.22 if mp else 0.42)) * vp.y
	var title_bottom := _title.anchor_top * vp.y + (64.0 if portrait else 84.0) * 1.35
	# Short screens: the main and Singleplayer pages' buttons get lower, so they fit under the title.
	for page in [_main_page, _sp_page, _campaign_page]:
		var tall: bool = page.get_child_count() * (64.0 + 14.0) + title_bottom + 20.0 <= vp.y
		page.add_theme_constant_override("separation", 14 if tall else 8)
		for c in page.get_children():
			if c is Button:
				(c as Button).custom_minimum_size.y = 64.0 if tall else 52.0
	var h := _menu.get_combined_minimum_size().y
	var top := clampf(want, title_bottom, maxf(title_bottom, vp.y - h - 20.0))
	_menu.anchor_top = 0.0
	_menu.anchor_bottom = 0.0
	_menu.offset_top = top
	_menu.offset_bottom = top


func _page() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 14)
	_menu.add_child(p)
	return p


## Shows one menu page (the main page or the Singleplayer page).
func show_page(page: VBoxContainer) -> void:
	_main_page.visible = page == _main_page
	_sp_page.visible = page == _sp_page
	_campaign_page.visible = page == _campaign_page
	if mp_menu:
		mp_menu.visible = page == mp_menu
	_layout.call_deferred()


func in_singleplayer_page() -> bool:
	return _sp_page.visible


func _menu_button(page: VBoxContainer, text: String, action: Callable, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = Art.tex(icon)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)
	b.custom_minimum_size = Vector2(320, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	page.add_child(b)
	return b


func _cycle_difficulty() -> void:
	Settings.cycle_difficulty()
	_update_sp_buttons()


## Map: the types in turn, then Random, then Custom... (a map file), then the first type again.
func _cycle_map() -> void:
	if Settings.custom_map:
		Settings.custom_map = null
		Settings.map_type = Config.MAP_TYPE_ORDER[0]
	elif Settings.map_type == "random":
		picker.choose(func(m: MapData, _p: String) -> void:
			Settings.custom_map = m
			Settings.custom_village = 0
			_update_sp_buttons(),
		func() -> void:
			Settings.map_type = Config.MAP_TYPE_ORDER[0]
			_update_sp_buttons())
	else:
		Settings.cycle_map_type()
	_update_sp_buttons()


func _update_sp_buttons() -> void:
	_continue_path = SaveGame.newest_single()
	continue_button.visible = _continue_path != ""
	continue_label.visible = continue_button.visible
	if continue_button.visible:
		continue_label.text = SaveGame.summary(SaveGame.read(_continue_path, false)["header"])
		play_button.remove_theme_stylebox_override("normal")
		play_button.remove_theme_stylebox_override("hover")
		play_button.remove_theme_stylebox_override("pressed")
	else:
		UiTheme.style_primary(play_button)
	difficulty_button.text = "Difficulty: %s" % Settings.difficulty_name()
	var custom := Settings.custom_map
	map_button.text = "Map: %s" % (MapJson.map_name(custom) if custom else Settings.map_type_name())
	village_button.visible = custom != null and custom.villages.size() > 1
	if village_button.visible:
		village_button.text = "Your village: %d of %d" % [Settings.custom_village + 1, custom.villages.size()]
	seed_edit.visible = custom == null


func _play() -> void:
	get_tree().change_scene_to_file(Net.GAME_SCENE)


## The newest single-player save, autosave or manual (never a co-op save).
func continue_game() -> void:
	if _continue_path != "":
		_start_save(_continue_path)


func _start_save(path: String) -> void:
	var err := SaveGame.start(path, get_tree())
	if err != "":
		continue_label.visible = true
		continue_label.text = err
		continue_label.add_theme_color_override("font_color", UiTheme.BAD)


## The campaign page: one button per scenario, with its line, and how many are still to come.
func _build_campaign_page() -> void:
	_campaign_page = _page()
	for n in range(1, Campaign.count() + 1):
		var spec := Campaign.scenario(n)
		var b := _menu_button(_campaign_page, "%d. %s" % [n, spec.title], play_scenario.bind(n))
		b.tooltip_text = spec.blurb
		if n == 1:
			UiTheme.style_primary(b)
		scenario_buttons.append(b)
		var l := Label.new()
		l.text = spec.blurb
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(320, 0)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", UiTheme.MUTED)
		_campaign_page.add_child(l)
	var more := Label.new()
	more.text = "Scenarios %d to %d are still to come." % [Campaign.count() + 1, Campaign.PLANNED]
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.add_theme_font_size_override("font_size", 16)
	more.add_theme_color_override("font_color", UiTheme.MUTED)
	_campaign_page.add_child(more)
	_menu_button(_campaign_page, "Back", func() -> void: show_page(_main_page))


## Scenario `n` of the campaign (docs/scenarios-design.md): its own map, village and story.
func play_scenario(n: int) -> void:
	Settings.scenario_next = n
	_play()


## The guided tutorial (docs/tutorial-design.md): its own map and village.
func play_tutorial() -> void:
	Settings.tutorial_next = true
	_play()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if mp_menu.visible or picker.visible or save_list.visible:
					return
				if in_singleplayer_page():
					if _continue_path != "":
						continue_game()
					else:
						_play()
				else:
					show_page(_sp_page)
			KEY_ESCAPE:
				if picker.visible or save_list.visible:
					return
				if mp_menu.visible and Net.is_online():
					Net.leave()
				else:
					show_page(_main_page)
