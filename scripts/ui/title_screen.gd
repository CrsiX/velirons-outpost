class_name TitleScreen
extends Control
## Title screen: backdrop, game name, and Play / Difficulty / Levels / Exit.

const LEVEL_SCENE := "res://scenes/main.tscn"
## Levels offered on the Levels panel. Only the first exists so far.
const LEVELS: Array[Dictionary] = [
	{"name": "The Last Outpost", "available": true},
	{"name": "Coming soon", "available": false},
	{"name": "Coming soon", "available": false},
]

var play_button: Button
var difficulty_button: Button
var levels_button: Button
var exit_button: Button
var levels_panel: PanelContainer
var _menu: VBoxContainer


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
	title.text = "Veliron's Outpost"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_color_override("font_outline_color", UiTheme.INK)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.08
	title.anchor_bottom = 0.08
	add_child(title)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	_menu.custom_minimum_size = Vector2(320, 0)
	add_child(_menu)
	_menu.anchor_left = 0.07
	_menu.anchor_right = 0.07
	_menu.anchor_top = 0.42
	_menu.anchor_bottom = 0.42

	play_button = _menu_button("Play", _play)
	UiTheme.style_primary(play_button)
	difficulty_button = _menu_button("", _cycle_difficulty)
	levels_button = _menu_button("Levels", func() -> void: levels_panel.visible = true)
	exit_button = _menu_button("Exit", func() -> void: get_tree().quit())
	exit_button.visible = not OS.has_feature("web")  # browsers can't close the tab
	_update_difficulty()
	_build_levels_panel()


func _menu_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	_menu.add_child(b)
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


func _play() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		match (event as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_play()
			KEY_ESCAPE:
				levels_panel.visible = false
