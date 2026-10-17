class_name SaveList
extends Control
## The saved games (docs/save-design.md §4.3), newest first: name, Autosave
## or Saved, wave, map, difficulty, villages, play time and date; the
## selected one with its map's preview. Load (Use in the lobby), Delete
## (after a confirmation), Cancel / Esc. Saves that can't be loaded are
## listed greyed out with the reason (they can still be deleted). Used by the
## Singleplayer menu (single-player saves), the settings dialog in a game and
## the lobby (co-op saves).

signal closed

var _title: Label
var _list: VBoxContainer
var _preview: MapPreview
var _info: Label
var _problems: Label
var _ok: Button
var _delete: Button
var _panes: BoxContainer
var _panel: PanelContainer
const MAX_SIZE := Vector2(1400, 900)
var _confirm: PanelContainer
var _confirm_text: Label
var _confirm_yes: Button
var _entries: Array[Dictionary] = []
var _selected := -1
var _coop := false
## Called with the path when one is chosen; `_on_cancel` if it closes without.
var _callback := Callable()
var _on_cancel := Callable()
## Asked before a choice counts (Leave this game?); empty: no question.
var _confirm_choice := ""


func _init() -> void:
	name = "SaveList"
	theme = UiTheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14"), UiTheme.GOLD, 4, 14, 16))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_title = _label("Saved games", 28, UiTheme.GOLD)
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
	_ok = _button("Load", buttons)
	UiTheme.style_good(_ok)
	_ok.pressed.connect(_choose)
	_delete = _button("Delete", buttons)
	UiTheme.style_danger(_delete)
	_delete.pressed.connect(_ask_delete)
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


## Shows the saves (`coop`: the co-op ones, else the single-player ones);
## `cb` gets the chosen file's path, `cancelled` runs if it closes without;
## `confirm` (if not empty) is asked first.
func choose(coop: bool, cb: Callable, cancelled: Callable = Callable(), title: String = "Load a game", ok_text: String = "Load", confirm: String = "") -> void:
	_coop = coop
	_confirm_choice = confirm
	_callback = cb
	_on_cancel = cancelled
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


## Lists the saves again (the first one selected).
func refresh() -> void:
	_entries = SaveGame.list(_coop)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if _entries.is_empty():
		_list.add_child(_label("No saved co-op games yet. The host saves between waves; every game also saves itself after each wave." if _coop
			else "No saved games yet. Save between waves (Settings: Save...); every game also saves itself after each wave.", 17, UiTheme.MUTED))
	for i in _entries.size():
		var e := _entries[i]
		var h: Dictionary = e["header"]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 17)
		if e["error"] != "":
			b.text = "%s   (%s)" % [str(e["path"]).get_file().get_basename(), str(e["error"]).to_lower()]
			b.modulate = Color(1, 1, 1, 0.55)
		else:
			b.text = "%s   %s" % [str(h.get("name", "?")), SaveGame.summary(h)]
		b.set_meta("i", i)
		b.pressed.connect(func() -> void: select(i))
		_list.add_child(b)
	select(0 if not _entries.is_empty() else -1)


## Shows entry `i`: what it is, and its map.
func select(i: int) -> void:
	_selected = i
	for b in _list.get_children():
		if b is Button:
			UiTheme.style_selected(b, int(b.get_meta("i", -1)) == i)
	_problems.text = ""
	if i < 0 or i >= _entries.size():
		_preview.show_map(null)
		_info.text = ""
		_ok.disabled = true
		_delete.visible = false
		return
	var e := _entries[i]
	_delete.visible = true
	if e["error"] != "":
		_preview.show_map(null)
		_info.text = str(e["path"]).get_file()
		_problems.text = "It can't be loaded: %s." % str(e["error"]).to_lower()
		_ok.disabled = true
		return
	var r := SaveGame.read(str(e["path"]))
	if r["error"] != "":
		_preview.show_map(null)
		_problems.text = "It can't be loaded: %s." % str(r["error"]).to_lower()
		_ok.disabled = true
		return
	var h: Dictionary = r["header"]
	_preview.show_map(SaveGame.saved_map(r["body"]))
	_preview.labels.clear()
	var names := PackedStringArray()
	var vs: Array = h.get("villages", [])
	for k in vs.size():
		_preview.labels[k] = str(vs[k]["name"])
		names.append(str(vs[k]["name"]))
	_preview.queue_redraw()
	_info.text = "%s\n%s · %s\n%s\nPlayed %s · saved %s" % [str(h.get("name", "")), "Autosave" if h.get("auto", false) else "Saved",
		SaveGame.summary(h), ", ".join(names), _duration(float(h.get("play_time", 0.0))),
		Time.get_datetime_string_from_unix_time(int(h.get("saved_at", 0)) + _tz_bias(), true)]
	_ok.disabled = false


static func _duration(seconds: float) -> String:
	var m := int(seconds) / 60
	return "%d h %02d min" % [m / 60, m % 60] if m >= 60 else "%d min" % m


static func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func selected_path() -> String:
	return str(_entries[_selected]["path"]) if _selected >= 0 and _selected < _entries.size() else ""


func _choose() -> void:
	var p := selected_path()
	if p == "":
		return
	if _confirm_choice != "":
		_ask(_confirm_choice, _ok.text, func() -> void: _emit(p))
		return
	_emit(p)


func _emit(p: String) -> void:
	visible = false
	var cb := _callback
	_callback = Callable()
	_on_cancel = Callable()
	if cb.is_valid():
		cb.call(p)


func _ask_delete() -> void:
	var p := selected_path()
	if p == "":
		return
	var h: Dictionary = _entries[_selected]["header"]
	_ask("Delete \"%s\"? This can't be undone." % str(h.get("name", p.get_file())), "Delete", func() -> void:
		SaveGame.delete(p)
		refresh())


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
	UiTheme.style_danger(_confirm_yes)
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
