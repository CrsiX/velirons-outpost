class_name MapPicker
extends Control
## Choosing a map file (docs/map-editor-design.md §7, §8): your maps and the
## built-in ones, with a preview, the file's problems, and Import. For playing
## (`for_play`) a map with errors can't be chosen. On the web, a map of
## Config.EDITOR["web_large_size"] or more asks first.

signal picked(map: MapData, path: String)
signal closed

var for_play := true
var _title: Label
var _list: VBoxContainer
var _preview: MapPreview
var _info: Label
var _problems: Label
var _ok: Button
var _delete: Button
var _panes: BoxContainer
var _panel: PanelContainer
## The picker's size at most (centred on bigger screens).
const MAX_SIZE := Vector2(1400, 900)
var _confirm: PanelContainer
var _confirm_text: Label
var _confirm_yes: Button
var _entries: Array[Dictionary] = []
var _selected := -1
var _map: MapData = null
## Called with (map, path) when one is chosen (see choose); besides `picked`.
var _callback := Callable()
var _on_cancel := Callable()


func _init() -> void:
	name = "MapPicker"
	theme = UiTheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14"), UiTheme.GOLD, 4, 14, 16))
	add_child(panel)
	_panel = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_title = _label("Choose a map", 28, UiTheme.GOLD)
	v.add_child(_title)
	_panes = BoxContainer.new()
	_panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panes.add_theme_constant_override("separation", 16)
	v.add_child(_panes)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panes.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	_panes.add_child(right)
	_preview = MapPreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(160, 160)
	right.add_child(_preview)
	_info = _label("", 17)
	right.add_child(_info)
	_problems = _label("", 15, UiTheme.BAD)
	right.add_child(_problems)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	right.add_child(buttons)
	_ok = _button("Use this map", buttons)
	UiTheme.style_good(_ok)
	_ok.pressed.connect(_choose)
	_delete = _button("Delete", buttons)
	UiTheme.style_danger(_delete)
	_delete.pressed.connect(_ask_delete)
	_button("Import...", buttons).pressed.connect(_import)
	_button("Cancel", buttons).pressed.connect(close)
	_build_confirm()
	visible = false
	Layout.changed.connect(func(_p: bool) -> void: _fit())
	resized.connect(_fit)
	_fit()


func _label(text: String, px: int, col: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	parent.add_child(b)
	return b


func _fit() -> void:
	_panes.vertical = Layout.portrait
	var s := (size - Vector2(32, 32)).min(MAX_SIZE)
	_panel.position = ((size - s) / 2.0).floor()
	_panel.size = s


## Shows the maps for `cb` (map, path): the title screen's Singleplayer and
## the lobby. `cancelled` is called if the picker closes without a choice.
func choose(cb: Callable, cancelled: Callable = Callable(), title: String = "Play a map", ok_text: String = "Play this map") -> void:
	open(true, title, ok_text)
	_callback = cb
	_on_cancel = cancelled


## Shows the maps. `play`: only maps without errors can be chosen.
func open(play: bool = true, title: String = "Choose a map", ok_text: String = "Use this map") -> void:
	_callback = Callable()
	_on_cancel = Callable()
	for_play = play
	_title.text = title
	_ok.text = ok_text
	visible = true
	_confirm.visible = false
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	var cb := _on_cancel
	_on_cancel = Callable()
	_callback = Callable()
	if cb.is_valid():
		cb.call()
	closed.emit()


## Lists the map files again (keeps the selection by path).
func refresh(select_path: String = "") -> void:
	var keep := select_path if select_path != "" else (str(_entries[_selected]["path"]) if _selected >= 0 and _selected < _entries.size() else "")
	_entries = MapLibrary.list()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if _entries.is_empty():
		_list.add_child(_label("No maps yet. Make one in the Map Editor, or Import a file.", 17, UiTheme.MUTED))
	var heading := ""
	_selected = -1
	for i in _entries.size():
		var e := _entries[i]
		var h := "Built-in maps" if e["builtin"] else "Your maps"
		if h != heading:
			heading = h
			_list.add_child(_label(h, 18, UiTheme.GOLD))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 17)
		b.text = str(e["name"]) + ("   (not a map file)" if e["error"] != "" else "   %dx%d · %d %s" % [e["size"], e["size"], e["villages"], "village" if e["villages"] == 1 else "villages"])
		b.set_meta("path", e["path"])
		b.pressed.connect(func() -> void: select(i))
		_list.add_child(b)
		if e["path"] == keep:
			_selected = i
	if _selected < 0 and not _entries.is_empty():
		_selected = 0
	select(_selected)


## Shows entry `i`: its preview, what it is and its problems.
func select(i: int) -> void:
	_selected = i
	_map = null
	for b in _list.get_children():
		if b is Button:
			UiTheme.style_selected(b, i >= 0 and b.get_meta("path", "") == _entries[i]["path"])
	if i < 0 or i >= _entries.size():
		_preview.show_map(null)
		_info.text = ""
		_problems.text = ""
		_ok.disabled = true
		_delete.visible = false
		return
	var e := _entries[i]
	_delete.visible = not e["builtin"]
	var r := MapLibrary.load_file(e["path"])
	_map = r["map"]
	_preview.show_map(_map)
	if _map == null:
		_info.text = str(e["name"])
		var errs: Array = r["errors"]
		_problems.text = "This file can't be read:\n" + "\n".join(errs.slice(0, 6)) + ("\n..." if errs.size() > 6 else "")
		_ok.disabled = true
		return
	var meta := _map.meta
	_info.text = "%s\n%dx%d · %d %s · %s%s%s" % [MapJson.map_name(_map), _map.size, _map.size, _map.villages.size(),
		"village" if _map.villages.size() == 1 else "villages", Settings.map_type_name(_map.map_type),
		("\nby " + str(meta["author"])) if str(meta.get("author", "")) != "" else "",
		("\n" + str(meta["description"])) if str(meta.get("description", "")) != "" else ""]
	_problems.text = ""
	_ok.disabled = false
	if for_play:
		var errs := MapChecks.errors(MapChecks.run(_map))
		if not errs.is_empty():
			_problems.text = "It can't be played yet:\n" + "\n".join(errs.slice(0, 5).map(func(p: Dictionary) -> String: return str(p["text"]))) + ("\n..." if errs.size() > 5 else "")
			_ok.disabled = true


func selected_path() -> String:
	return str(_entries[_selected]["path"]) if _selected >= 0 and _selected < _entries.size() else ""


func _choose() -> void:
	if _map == null:
		return
	var m := _map
	var p := selected_path()
	if MapPicker.warns_large(m.size):
		_ask(MapPicker.large_text(m.size), "Continue", func() -> void: _emit(m, p))
		return
	_emit(m, p)


func _emit(m: MapData, p: String) -> void:
	visible = false
	var cb := _callback
	_callback = Callable()
	_on_cancel = Callable()
	if cb.is_valid():
		cb.call(m, p)
	picked.emit(m, p)


## Tests: behave as the web build does.
static var pretend_web := false


## The web build warns before opening a map of web_large_size or more (§3).
static func warns_large(map_size: int) -> bool:
	return (OS.has_feature("web") or pretend_web) and map_size >= int(Config.EDITOR["web_large_size"])


static func large_text(map_size: int) -> String:
	return "This map is %dx%d. Maps this big may run slowly in the browser." % [map_size, map_size]


func _ask_delete() -> void:
	var p := selected_path()
	if p == "" or MapLibrary.is_builtin(p):
		return
	_ask("Delete \"%s\"? This can't be undone." % _entries[_selected]["name"], "Delete", func() -> void:
		MapLibrary.delete(p)
		refresh())


func _import() -> void:
	MapLibrary.import_text(self, func(file_name: String, text: String) -> void:
		if file_name == "":
			return
		var r := MapJson.read(text)
		if r["map"] == null:
			var errs: Array = r["errors"]
			_problems.text = "%s can't be read:\n%s%s" % [file_name, "\n".join(errs.slice(0, 6)), "\n..." if errs.size() > 6 else ""]
			return
		var m: MapData = r["map"]
		var p := MapLibrary.save(m, MapLibrary.free_path(MapJson.map_name(m)))
		refresh(p))


func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	_confirm.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14"), UiTheme.GOLD, 4, 14, 16))
	add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_confirm.add_child(v)
	_confirm_text = _label("", 18)
	_confirm_text.custom_minimum_size = Vector2(320, 0)
	v.add_child(_confirm_text)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	_confirm_yes = _button("OK", h)
	UiTheme.style_good(_confirm_yes)
	_button("Cancel", h).pressed.connect(func() -> void: _confirm.visible = false)
	_confirm.visible = false


func _ask(text: String, yes: String, cb: Callable) -> void:
	_confirm_text.text = text
	_confirm_yes.text = yes
	for c in _confirm_yes.pressed.get_connections():
		_confirm_yes.pressed.disconnect(c["callable"])
	_confirm_yes.pressed.connect(func() -> void:
		_confirm.visible = false
		cb.call())
	_confirm.visible = true
	_confirm.reset_size()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if (event as InputEventKey).keycode == KEY_ESCAPE:
		if _confirm.visible:
			_confirm.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()
