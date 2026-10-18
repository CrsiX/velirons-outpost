class_name ScenarioCard
extends PanelContainer
## A scenario's card (top left, under the top bar): the teaching card's title
## and text (a tick when it is done), a hint that comes up once when something
## goes wrong, and the scenario's objectives with a tick each. The heading
## folds it to a single line.

var hud: Hud
var folded := false
var _head: Button
var _body: VBoxContainer
var _lesson: VBoxContainer
var _tick: TextureRect
var _title: Label
var _text: Label
var _hint: Label
var _goals: VBoxContainer
## objective id -> {"tick": TextureRect, "dot": Label, "text": Label}
var _rows := {}


func build(p_hud: Hud, heading: String) -> void:
	hud = p_hud
	name = "ScenarioCard"
	add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14ee"), UiTheme.GOLD, 3, 12, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_head = hud._button(heading, Vector2(0, 34))
	_head.flat = true
	_head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_head.add_theme_font_size_override("font_size", 15)
	_head.add_theme_color_override("font_color", UiTheme.MUTED)
	_head.tooltip_text = "Fold or unfold"
	_head.pressed.connect(func() -> void: set_folded(not folded))
	v.add_child(_head)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	v.add_child(_body)
	_lesson = VBoxContainer.new()
	_lesson.add_theme_constant_override("separation", 4)
	_body.add_child(_lesson)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_lesson.add_child(head)
	_tick = hud._icon(Art.tex("icon_check"), 26)
	_tick.visible = false
	head.add_child(_tick)
	_title = hud._label("", 21, UiTheme.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	_text = hud._label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson.add_child(_text)
	_hint = hud._label("", 16, Color("ffb07a"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.visible = false
	_body.add_child(_hint)
	_body.add_child(HSeparator.new())
	_body.add_child(hud._label("Objectives", 17, UiTheme.GOLD))
	_goals = VBoxContainer.new()
	_goals.add_theme_constant_override("separation", 2)
	_body.add_child(_goals)
	visible = false


func set_folded(on: bool) -> void:
	folded = on
	_body.visible = not on
	_head.text = _head.text.trim_suffix("  ▸").trim_suffix("  ▾") + ("  ▸" if on else "  ▾")


## The teaching card shown now; an empty title hides it (no card).
func show_lesson(title: String, text: String) -> void:
	_lesson.visible = title != ""
	_title.text = title
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_text.text = text
	_tick.visible = false


func lesson_done() -> void:
	_tick.visible = true
	_title.add_theme_color_override("font_color", UiTheme.GOOD)


func lesson_title() -> String:
	return _title.text if _lesson.visible else ""


func lesson_text() -> String:
	return _text.text


func set_lesson_text(t: String) -> void:
	_text.text = t


## A hint ("" hides it); unfolds the card so it is seen.
func show_hint(t: String) -> void:
	_hint.text = t
	_hint.visible = t != ""
	if t != "":
		set_folded(false)


func hint() -> String:
	return _hint.text if _hint.visible else ""


## The objectives: [{"id", "text"}], in order.
func set_objectives(list: Array[Dictionary]) -> void:
	for c in _goals.get_children():
		c.queue_free()
	_rows.clear()
	for o in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var tick := hud._icon(Art.tex("icon_check"), 18)
		tick.visible = false
		row.add_child(tick)
		var dot := hud._label("•", 16, UiTheme.MUTED)
		dot.custom_minimum_size.x = 18
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(dot)
		var t := hud._label(str(o["text"]), 15)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		_goals.add_child(row)
		_rows[o["id"]] = {"tick": tick, "dot": dot, "text": t, "base": str(o["text"])}


## One objective's state: done (ticked, green) and its progress ("3 / 9").
func set_objective(id: String, done: bool, detail: String) -> void:
	if not _rows.has(id):
		return
	var r: Dictionary = _rows[id]
	(r["tick"] as Control).visible = done
	(r["dot"] as Control).visible = not done
	var t: Label = r["text"]
	t.text = str(r["base"]) + ("  (%s)" % detail if detail != "" and not done else "")
	t.add_theme_color_override("font_color", UiTheme.GOOD if done else UiTheme.TEXT)


## Top left under the top bar; beside a panel open in that corner (portrait:
## under it), and under the placing hint in portrait.
func place() -> void:
	var vp := hud.ui_size()
	var portrait := hud.is_portrait()
	var w := minf(vp.x - 20.0, 520.0) if portrait else 360.0
	var pos := Vector2(10.0, hud.top_height() + 6.0)
	var corner := hud.corner_panel_rect()
	corner.position = hud.to_ui(corner.position)
	if corner.has_area():
		if portrait:
			pos.y = corner.end.y + 6.0
		else:
			pos.x = corner.end.x + 10.0
	if portrait and hud._mode_panel.visible:
		pos.y = maxf(pos.y, hud.to_ui(hud._mode_panel.get_global_rect().end).y + 6.0)
	custom_minimum_size.x = w
	size = Vector2(w, 0.0)
	position = pos
