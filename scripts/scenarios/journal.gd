class_name Journal
extends CenterContainer
## A page found in a scenario (docs/scenarios-design.md §7): a journal
## fragment, a letter, a logbook, shown over the game on parchment. Single
## player pauses meanwhile and goes on at the speed before; Close or Esc
## closes it (it is one of the HUD's popups).

signal closed

var game: Game
var _title: Label
var _text: Label
## The game's speed when it opened (Game.SPEEDS index), -1 while closed.
var _speed_before := -1


func setup(p_game: Game) -> void:
	game = p_game
	name = "Journal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color("e8dcb8"), Color("6a4a2a"), 4, 10, 26))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(minf(560.0, game.get_viewport().get_visible_rect().size.x - 64.0), 0)
	panel.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color("4a2a14"))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 18)
	_text.add_theme_color_override("font_color", Color("2a1a10"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 48)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_page)
	v.add_child(close)
	visible = false
	game.hud.add_layer(self, true)
	game.hud.register_popup(self, close_page)


func open(title: String, text: String) -> void:
	_title.text = title
	_text.text = text
	if not visible and not game.networked:
		_speed_before = game.speed_index
		game.apply_speed(Game.SPEEDS.find(0.0))
	visible = true
	var flat := " ".join(Array(text.split("\n", false)).map(func(l: String) -> String: return l.strip_edges()))  # (one line in the log)
	game.events.info("%s: %s" % [title, flat.left(60) + ("..." if flat.length() > 60 else "")])


func close_page() -> void:
	if not visible:
		return
	visible = false
	if _speed_before >= 0:
		game.apply_speed(_speed_before)
		_speed_before = -1
	closed.emit()


func title() -> String:
	return _title.text


func text() -> String:
	return _text.text
