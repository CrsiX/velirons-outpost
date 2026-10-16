class_name EditorUi
extends CanvasLayer
## The map editor's panels (docs/map-editor-design.md §4.1): the top bar
## (files, undo / redo, the view, properties, Play, Back), the tools with the
## current tool's options (left), the inspector, layer switches and problems
## (right), a status line, and the dialogs (New, properties, Play, confirm,
## messages; the map picker). In portrait the side panels share one bottom
## panel with two tabs.

const TOOL_NAMES := {
	"look": "Look", "terrain": "Terrain", "zone": "Zone", "props": "Trees, peaks", "decor": "Decor",
	"beach": "Beach", "road": "Road", "volcano": "Volcano", "village": "Village", "piece": "Pieces",
	"spawn": "Spawn", "slice": "Slice", "object": "Objects",
}
const TOOL_HINTS := {
	"look": "Click a tile, object or village to see it (and edit it here).",
	"village": "Click open land: a new village (the standard layout). Drag a village to move it. Delete removes the selected one.",
	"piece": "Click a tile: the piece below goes there (for the selected or nearest village). Flip turns a wall; Erase removes a piece.",
	"spawn": "Click a road tile at the map's edge: a spawn (for the selected village, or the one of its slice). Click one again to remove it.",
	"object": "Click open land: a new object. Click one to select it, drag it to move it. Delete removes it.",
	"volcano": "Click: a volcano (3x3) there, or remove the one there.",
}
const TERRAIN_NAMES := ["Grass", "Road", "Forest", "Desert", "Mountain", "Deep water", "Shallow water", "Lava"]

var editor: MapEditor
var root: Control
var _top: PanelContainer
var _top_flow: HFlowContainer
var _left: PanelContainer
var _right: PanelContainer
var _tools_box: VBoxContainer
var _options: VBoxContainer
var _inspect: VBoxContainer
var _layers_box: VBoxContainer
var _problems_box: VBoxContainer
var _problems_title: Label
var _status: Label
var _status_until := 0.0
var _hover_text := ""
var _tool_buttons := {}
var _undo_button: Button
var _redo_button: Button
var _view_button: Button
var _save_button: Button
var _tabs: HBoxContainer
var _tab := "tools"
var _dialog: PanelContainer
var _dialog_box: VBoxContainer
var picker: MapPicker


func setup(p_editor: MapEditor) -> void:
	editor = p_editor
	root = Control.new()
	root.theme = UiTheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Layout.inset(root)  # (clear of a phone's camera cutout)
	_build_top()
	_left = _panel()
	var ls := _scroll(_left)
	_tools_box = VBoxContainer.new()
	_tools_box.add_theme_constant_override("separation", 6)
	_tools_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_tools_box)
	_build_tools()
	_right = _panel()
	var rs := _scroll(_right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(rv)
	rv.add_child(_label("Inspector", 18, UiTheme.GOLD))
	_inspect = VBoxContainer.new()
	_inspect.add_theme_constant_override("separation", 4)
	rv.add_child(_inspect)
	rv.add_child(_label("Layers", 18, UiTheme.GOLD))
	_layers_box = VBoxContainer.new()
	rv.add_child(_layers_box)
	_problems_title = _label("Problems", 18, UiTheme.GOLD)
	rv.add_child(_problems_title)
	_problems_box = VBoxContainer.new()
	_problems_box.add_theme_constant_override("separation", 2)
	rv.add_child(_problems_box)
	_build_layers()
	_tabs = HBoxContainer.new()
	root.add_child(_tabs)
	for t in [["tools", "Tools"], ["info", "Inspector"]]:
		var b := _button(t[1], Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		b.pressed.connect(func() -> void:
			_tab = key
			_fit())
		b.set_meta("tab", key)
		_tabs.add_child(b)
	_status = _label("", 15, UiTheme.TEXT)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 6)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status)
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14"), UiTheme.GOLD, 4, 14, 16))
	root.add_child(_dialog)
	_dialog_box = VBoxContainer.new()
	_dialog_box.add_theme_constant_override("separation", 8)
	_dialog.add_child(_dialog_box)
	_dialog.visible = false
	_dialog.minimum_size_changed.connect(_place_dialog)  # (shrinks too, e.g. after a taller dialog)
	picker = MapPicker.new()
	root.add_child(picker)
	picker.picked.connect(_on_opened)
	editor.changed.connect(refresh)
	editor.selection_changed.connect(_show_inspector)
	root.get_viewport().size_changed.connect(_fit, CONNECT_DEFERRED)  # (once the root has its new size)
	Layout.changed.connect(func(_p: bool) -> void: _fit(), CONNECT_DEFERRED)
	Layout.safe_area_changed.connect(_fit)
	_fit()
	refresh()


# --- building blocks -------------------------------------------------------------------------

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.12, 0.08, 0.06, 0.92), UiTheme.GOLD, 2, 8, 8))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(p)
	return p


func _scroll(parent: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	return s


func _label(text: String, px: int = 15, col: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, min_size: Vector2 = Vector2(0, 36)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	return b


## A row of choice buttons; `current` is framed. `pick` gets the chosen value.
func _choices(parent: Control, items: Array, current: Variant, pick: Callable, columns: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	for it in items:
		var value = it[0]
		var b := _button(str(it[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		UiTheme.style_selected(b, value == current)
		b.pressed.connect(func() -> void: pick.call(value))
		g.add_child(b)
	return g


func _toggle(parent: Control, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 15)
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# --- top bar ---------------------------------------------------------------------------------

func _build_top() -> void:
	_top = _panel()
	_top_flow = HFlowContainer.new()
	_top_flow.add_theme_constant_override("h_separation", 4)
	_top_flow.add_theme_constant_override("v_separation", 4)
	_top.add_child(_top_flow)
	var add := func(text: String, cb: Callable, tip: String = "") -> Button:
		var b := _button(text, Vector2(0, 36))
		b.tooltip_text = tip
		b.pressed.connect(cb)
		_top_flow.add_child(b)
		return b
	add.call("New", show_new, "Generate a map, or start a blank one")
	add.call("Open", func() -> void: picker.open(false, "Open a map", "Open"), "Your maps and the built-in ones")
	_save_button = add.call("Save", save, "Save to your maps (Ctrl+S)")
	add.call("Save as", func() -> void: show_properties(true), "Save under another name")
	add.call("Import", import_file, "Read a map file from anywhere")
	add.call("Export", export_file, "Write the map as a file anywhere (a download in the browser)")
	_undo_button = add.call("Undo", func() -> void: editor.undo(), "Ctrl+Z")
	_redo_button = add.call("Redo", func() -> void: editor.redo(), "Ctrl+Y")
	_view_button = add.call("2D", func() -> void: editor.toggle_view(), "Isometric or top-down view (Tab)")
	add.call("Properties", func() -> void: show_properties(false), "Name, author, description, map type")
	var play: Button = add.call("Play", show_play, "Try the map in a game")
	UiTheme.style_good(play)
	var back: Button = add.call("Back", ask_leave, "Back to the title screen")
	UiTheme.style_danger(back)


# --- tools -----------------------------------------------------------------------------------

func _build_tools() -> void:
	_clear(_tools_box)
	_tools_box.add_child(_label("Tools", 18, UiTheme.GOLD))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	_tools_box.add_child(g)
	_tool_buttons.clear()
	for t in MapEditor.TOOLS:
		var b := _button(TOOL_NAMES[t])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(func() -> void: set_tool(t))
		g.add_child(b)
		_tool_buttons[t] = b
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools_box.add_child(_options)
	_build_options()


func set_tool(t: String) -> void:
	editor.tool = t
	editor.pick_mode = {}
	editor.path_preview.clear()
	_build_options()
	refresh()


func _opt(key: String, value: Variant) -> void:
	editor.opts[key] = value
	_build_options()
	editor._redraw_pointer()


func _build_options() -> void:
	_clear(_options)
	var t := editor.tool
	for k in _tool_buttons:
		UiTheme.style_selected(_tool_buttons[k], k == t)
	_options.add_child(_label(TOOL_NAMES[t], 17, UiTheme.GOLD))
	if TOOL_HINTS.has(t):
		_options.add_child(_label(TOOL_HINTS[t], 14, UiTheme.MUTED))
	var o := editor.opts
	match t:
		"terrain":
			var items := []
			for k in TERRAIN_NAMES.size():
				items.append([k, TERRAIN_NAMES[k]])
			_choices(_options, items, int(o["terrain"]), func(v: Variant) -> void: _opt("terrain", v))
			_toggle(_options, "Fill an area", bool(o["fill"]), func(on: bool) -> void: _opt("fill", on))
		"zone":
			var items := []
			for z in Config.ZONE_ORDER:
				items.append([z, Config.ZONES[z]["name"]])
			_choices(_options, items, o["zone"], func(v: Variant) -> void: _opt("zone", v))
		"props":
			var items := [["auto", "Auto (the zone's)"]]
			for a in _tree_arts() + MapTidy.PEAK_ARTS:
				items.append([a, a.replace("_", " ").capitalize()])
			_choices(_options, items, o["prop"], func(v: Variant) -> void: _opt("prop", v), 1)
			_options.add_child(_label("Trees grow on forest, peaks on mountains.", 14, UiTheme.MUTED))
		"decor":
			var items := [["auto", "Auto (the zone's)"], ["", "Erase"]]
			for a in _decor_arts():
				items.append([a, a.replace("_", " ").capitalize()])
			_choices(_options, items, o["decor"], func(v: Variant) -> void: _opt("decor", v), 1)
		"beach":
			_choices(_options, [[true, "Beach"], [false, "Erase"]], o["beach"], func(v: Variant) -> void: _opt("beach", v))
		"road":
			_choices(_options, [["free", "Paint"], ["path", "Path (2 clicks)"], ["erase", "Erase"]], o["road"], func(v: Variant) -> void: _opt("road", v), 1)
		"volcano":
			_choices(_options, [["add", "Add"], ["remove", "Remove"]], o["volcano"], func(v: Variant) -> void: _opt("volcano", v))
			_toggle(_options, "Ash land around it", bool(o["ash"]), func(on: bool) -> void: _opt("ash", on))
		"piece":
			_choices(_options, [["wall", "Wall"], ["gate", "Gate"], ["wall_tower", "Wall tower"], ["hut", "Hut"], ["flip", "Flip"], ["erase", "Erase"]], o["piece"], func(v: Variant) -> void: _opt("piece", v))
		"slice":
			var items := []
			for s in Config.MAX_PLAYERS:
				items.append([s, "Slice %d" % s])
			_choices(_options, items, int(o["slice"]), func(v: Variant) -> void: _opt("slice", v), 4)
			var b := _button("Recompute from the villages")
			b.pressed.connect(func() -> void: editor.recompute_slices())
			_options.add_child(b)
		"object":
			var items := []
			for k in MapJson.OBJECT_KINDS:
				items.append([k, k.capitalize()])
			_choices(_options, items, o["object"], func(v: Variant) -> void: _opt("object", v))
			_choices(_options, [[1, "1x1"], [2, "2x2"]], int(o["object_size"]), func(v: Variant) -> void: _opt("object_size", v))
	if t in MapEditor.STROKE_TOOLS and not (t == "road" and o["road"] == "path") and not (t == "terrain" and o["fill"]):
		_options.add_child(_label("Brush", 15, UiTheme.MUTED))
		var sizes := []
		for n in Config.EDITOR["brush_sizes"]:
			sizes.append([n, str(n)])
		_choices(_options, sizes, int(o["brush"]), func(v: Variant) -> void: _opt("brush", v), 4)
		_toggle(_options, "Round", bool(o["round"]), func(on: bool) -> void: _opt("round", on))
	if Layout.touch and t != "look":
		_toggle(_options, "Paint by dragging (else a drag pans)", bool(o["paint"]), func(on: bool) -> void: _opt("paint", on))


func _tree_arts() -> Array:
	var out := []
	for z in Config.ZONE_ORDER:
		for a in Config.ZONES[z]["mix"]:
			if not out.has(a):
				out.append(a)
	return out


func _decor_arts() -> Array:
	var out := []
	for z in Config.ZONE_ORDER:
		for a in Config.ZONES[z].get("decor_mix", {}):
			if not out.has(a):
				out.append(a)
	return out


# --- layers, problems, inspector -------------------------------------------------------------

func _build_layers() -> void:
	_clear(_layers_box)
	var names := [["zones", "Zones (isometric)"], ["slices", "Slices"], ["grid", "Grid"], ["passable", "Blocked / shallow"],
		["buildable", "Buildable land"], ["spawns", "Spawns"], ["villages", "Villages"], ["objects", "Objects"],
		["rings", "Camp rings, fronts"], ["problems", "Problem marks"]]
	for n in names:
		var key: String = n[0]
		_toggle(_layers_box, n[1], bool(editor.layers.get(key, false)), func(on: bool) -> void:
			editor.layers[key] = on
			editor.redraw_layers())
	var flow := int(editor.layers["flow"])
	var b := _button("Road steps: %s" % ("off" if flow < 0 else "village %d" % (flow + 1)))
	b.tooltip_text = "How many road tiles from each road tile to a village's gates"
	b.pressed.connect(func() -> void:
		var n := editor.map.villages.size()
		editor.layers["flow"] = -1 if flow + 1 >= n else flow + 1
		editor.redraw_layers()
		_build_layers())
	_layers_box.add_child(b)


func show_problems() -> void:
	if _problems_box == null or editor.map == null:
		return
	_clear(_problems_box)
	var errors := MapChecks.errors(editor.problems).size()
	var warnings := editor.problems.size() - errors
	_problems_title.text = "Problems (%d %s, %d %s)" % [errors, "error" if errors == 1 else "errors", warnings, "warning" if warnings == 1 else "warnings"]
	if editor.problems.is_empty():
		_problems_box.add_child(_label("None: the map can be played.", 14, UiTheme.GOOD))
	for p in editor.problems:
		var b := _button(("Error: " if p["level"] == "error" else "Warning: ") + str(p["text"]), Vector2(0, 30))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", UiTheme.BAD if p["level"] == "error" else Color("f2c230"))
		var t: Vector2i = p["tile"]
		b.disabled = t.x < 0
		b.pressed.connect(func() -> void:
			editor.view_tile(t)
			editor.select({"type": "tile", "tile": t}))
		_problems_box.add_child(b)


func _show_inspector() -> void:
	_clear(_inspect)
	if editor.map == null:
		return
	var m := editor.map
	var sel := editor.selected
	match str(sel.get("type", "")):
		"tile":
			_tile_info(sel["tile"])
		"object":
			_object_info(int(sel["index"]))
		"village":
			_village_info(int(sel["index"]))
		_:
			_inspect.add_child(_label("%s\n%dx%d · %s · %d %s · %d objects" % [MapJson.map_name(m), m.size, m.size, Settings.map_type_name(m.map_type),
				m.villages.size(), "village" if m.villages.size() == 1 else "villages", m.objects.size()], 14))
			_inspect.add_child(_label("Look: click something to see it here.", 14, UiTheme.MUTED))


func _tile_info(t: Vector2i) -> void:
	_inspect.add_child(_label(tile_text(t), 14))
	var m := editor.map
	for i in m.villages.size():
		if (m.villages[i]["gates"] as Array).is_empty():
			continue
		var d := GenChecks.road_field(m, m.villages[i]["gates"])[m.index(t)]
		if d < 1 << 29:
			_inspect.add_child(_label("Road steps to village %d: %d" % [i + 1, d], 14, UiTheme.MUTED))


## What tile `t` is, in words (the inspector, the status line).
func tile_text(t: Vector2i) -> String:
	var m := editor.map
	if not m.in_bounds(t):
		return ""
	var parts := ["Tile %d, %d" % [t.x, t.y], TERRAIN_NAMES[m.get_terrain(t)], Config.ZONES[m.zone(t)]["name"], "slice %d" % m.slice_of[m.index(t)]]
	if m.props.has(t):
		parts.append(str(m.props[t]))
	if m.decor.has(t):
		parts.append(str(m.decor[t]))
	if m.crossings.has(t):
		parts.append(str(m.crossings[t][0]))
	if m.beaches.has(t):
		parts.append("beach")
	var pieces := MapTidy.piece_tiles(m)
	if pieces.has(t):
		parts.append(str(pieces[t]).replace("_", " "))
	return " · ".join(parts)


func _object_info(i: int) -> void:
	var m := editor.map
	if i >= m.objects.size():
		return
	var o := m.objects[i]
	var t: Vector2i = o["tile"]
	_inspect.add_child(_label("%s %d at %d, %d (%dx%d, slice %d)" % [str(o["kind"]).capitalize(), i + 1, t.x, t.y, int(o.get("size", 1)), int(o.get("size", 1)), int(o.get("slice", 0))], 15))
	var set_field := func(key: String, value: Variant) -> void: editor.set_object_field(key, value)
	match str(o["kind"]):
		"treasure":
			_inspect.add_child(_label("Kind", 14, UiTheme.MUTED))
			var kinds := []
			for k in Config.TREASURES:
				kinds.append([k, Config.TREASURES[k]["name"]])
			_choices(_inspect, kinds, o["treasure"], func(v: Variant) -> void: set_field.call("treasure", v))
			_tier_row(o, set_field)
			_inspect.add_child(_label("Reward", 14, UiTheme.MUTED))
			var reward: Dictionary = (o.get("reward", {}) as Dictionary).duplicate()
			for k in ["gold", "food", "materials", "hero_xp", "heal_units"]:
				var row := HBoxContainer.new()
				row.add_child(_label(k.replace("_", " ").capitalize(), 14))
				(row.get_child(0) as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var sb := SpinBox.new()
				sb.max_value = 9999
				sb.value = int(reward.get(k, 0))
				var key: String = k
				sb.value_changed.connect(func(v: float) -> void:
					var r: Dictionary = (editor.map.objects[i].get("reward", {}) as Dictionary).duplicate()
					if int(v) > 0:
						r[key] = int(v)
					else:
						r.erase(key)
					set_field.call("reward", r))
				row.add_child(sb)
				_inspect.add_child(row)
			var relics := [["", "No relic"]]
			for r in Config.RELICS:
				relics.append([r, str(Config.RELICS[r].get("name", r))])
			_choices(_inspect, relics, str(reward.get("relic", "")), func(v: Variant) -> void:
				var r: Dictionary = (editor.map.objects[i].get("reward", {}) as Dictionary).duplicate()
				if str(v) == "":
					r.erase("relic")
				else:
					r = {"relic": v}
				set_field.call("reward", r), 1)
		"camp":
			_tier_row(o, set_field)
			var g := int(o.get("guards", -1))
			_inspect.add_child(_label("Guards treasure %d" % (g + 1) if g >= 0 else "Guards nothing", 14))
			var pick := _button("Pick its treasure")
			pick.pressed.connect(func() -> void: editor.start_pick("guards", i))
			_inspect.add_child(pick)
			_inspect.add_child(_label("Monsters (comma-separated enemy kinds)", 14, UiTheme.MUTED))
			var le := LineEdit.new()
			le.text = ", ".join(o.get("monsters", []))
			le.text_submitted.connect(func(text: String) -> void: _set_monsters(text, set_field))
			le.focus_exited.connect(func() -> void: _set_monsters(le.text, set_field))
			_inspect.add_child(le)
		"unlock":
			var sites := []
			for k in Config.UNLOCK_SITES:
				sites.append([k, Config.UNLOCK_SITES[k]["name"]])
			_choices(_inspect, sites, o["site"], func(v: Variant) -> void: set_field.call("site", v), 1)
			var row := HBoxContainer.new()
			row.add_child(_label("Awakens at wave", 14))
			var sb := SpinBox.new()
			sb.min_value = 1
			sb.max_value = 200
			sb.value = int(o.get("wave", 1))
			sb.value_changed.connect(func(v: float) -> void: set_field.call("wave", int(v)))
			row.add_child(sb)
			_inspect.add_child(row)
		"lair":
			var arts := []
			for a in ArtManifest.SPRITES:
				if str(a).begins_with("lair_"):
					arts.append([a, str(a).trim_prefix("lair_").replace("_", " ")])
			_choices(_inspect, arts, o["art"], func(v: Variant) -> void: set_field.call("art", v))
	if o.has("front"):
		var f: Vector2i = o["front"]
		_inspect.add_child(_label("Front: %d, %d" % [f.x, f.y], 14))
		var pick := _button("Pick its front tile")
		pick.pressed.connect(func() -> void: editor.start_pick("front", i))
		_inspect.add_child(pick)
	var del := _button("Delete")
	UiTheme.style_danger(del)
	del.pressed.connect(func() -> void: editor.delete_selected())
	_inspect.add_child(del)


func _tier_row(o: Dictionary, set_field: Callable) -> void:
	_inspect.add_child(_label("Tier", 14, UiTheme.MUTED))
	_choices(_inspect, [[1, "1 (near)"], [2, "2"], [3, "3 (far)"]], int(o.get("tier", 1)), func(v: Variant) -> void: set_field.call("tier", v), 3)


func _set_monsters(text: String, set_field: Callable) -> void:
	var list: Array = []
	for part in text.split(","):
		var k := part.strip_edges().to_lower()
		if k == "":
			continue
		if not Config.ENEMIES.has(k):
			status("Unknown enemy \"%s\"" % k, true)
			return
		list.append(k)
	set_field.call("monsters", list)


func _village_info(i: int) -> void:
	var m := editor.map
	if i >= m.villages.size():
		return
	var v: Dictionary = m.villages[i]
	var c: Vector2i = v["center"]
	_inspect.add_child(_label("Village %d, centre %d, %d" % [i + 1, c.x, c.y], 15, Config.VILLAGE_COLORS[i % Config.VILLAGE_COLORS.size()]))
	var pieces := m.village_pieces(i)
	var huts := pieces.filter(func(p: Dictionary) -> bool: return p["kind"] == "hut").size()
	_inspect.add_child(_label("%d pieces (%d huts), %d gates, %d spawns, slice\u00a0%d%s" % [pieces.size(), huts, (v["gates"] as Array).size(),
		(v["home_spawns"] as Array).size(), int(v.get("slice", 0)), "" if MapChecks.standard_layout(m, i) else "\nNot the standard layout"], 14))
	var row := HBoxContainer.new()
	_inspect.add_child(row)
	for d in [[-1, "Number -1"], [1, "Number +1"]]:
		var b := _button(d[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var by: int = d[0]
		b.pressed.connect(func() -> void: editor.move_village_number(i, by))
		row.add_child(b)
	var centre := _button("Pick its centre")
	centre.pressed.connect(func() -> void: editor.start_pick("center", i))
	_inspect.add_child(centre)
	var del := _button("Delete village")
	UiTheme.style_danger(del)
	del.pressed.connect(func() -> void: editor.delete_selected())
	_inspect.add_child(del)


func show_hover(t: Vector2i) -> void:
	_hover_text = tile_text(t)
	_refresh_status()


# --- status ----------------------------------------------------------------------------------

func refresh() -> void:
	if _undo_button == null or editor.map == null:
		return
	_undo_button.disabled = not editor.can_undo()
	_redo_button.disabled = not editor.can_redo()
	_view_button.text = "Isometric" if editor.plan_mode else "2D"
	_save_button.text = "Save*" if editor.dirty else "Save"
	_build_layers()
	_show_inspector()
	_refresh_status()


func _refresh_status() -> void:
	if _status == null or Time.get_ticks_msec() < _status_until:
		return
	var m := editor.map
	if m == null:
		return
	var origin: Dictionary = m.meta.get("origin", {})
	_status.add_theme_color_override("font_color", UiTheme.TEXT)
	_status.text = "%s · %dx%d · %s%s · %d %s · %s%s" % [MapJson.map_name(m), m.size, m.size, Settings.map_type_name(m.map_type),
		(" (seed %d)" % int(origin["generator_seed"])) if origin.get("generator_seed") != null else "", m.villages.size(),
		"village" if m.villages.size() == 1 else "villages", "unsaved changes" if editor.dirty else ("saved" if editor.path != "" else "not saved yet"),
		("   |   " + _hover_text) if _hover_text != "" else ""]


## A message on the status line for a few seconds (red with `bad`).
func status(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.BAD if bad else UiTheme.GOLD)
	_status_until = Time.get_ticks_msec() + 3500


func _process(_delta: float) -> void:
	if _status_until > 0 and Time.get_ticks_msec() >= _status_until:
		_status_until = 0
		_refresh_status()


# --- layout ----------------------------------------------------------------------------------

func _fit() -> void:
	if root == null:
		return
	var vp := root.size
	var portrait := Layout.portrait or vp.x < 760.0
	_top.position = Vector2(6, 6)
	_top.size = Vector2(vp.x - 12, 0)
	# (the top bar's buttons wrap with its width: its height is known after a layout)
	await root.get_tree().process_frame
	_top.reset_size()
	_top.size.x = vp.x - 12
	var top_h := _top.size.y + 12.0
	var status_h := 26.0
	_tabs.visible = portrait
	if portrait:
		var h := floorf(vp.y * 0.38)
		var tabs_h := 42.0
		_tabs.position = Vector2(6, vp.y - h - tabs_h - status_h)
		_tabs.size = Vector2(vp.x - 12, tabs_h - 4)
		for p in [_left, _right]:
			p.position = Vector2(6, vp.y - h - status_h)
			p.size = Vector2(vp.x - 12, h - 6)
		_left.visible = _tab == "tools"
		_right.visible = _tab == "info"
		for b in _tabs.get_children():
			UiTheme.style_selected(b, b.get_meta("tab") == _tab)
	else:
		var w := 270.0
		var rw := 300.0
		_left.visible = true
		_right.visible = true
		_left.position = Vector2(6, top_h)
		_left.size = Vector2(w, vp.y - top_h - status_h - 6)
		_right.position = Vector2(vp.x - rw - 6, top_h)
		_right.size = Vector2(rw, vp.y - top_h - status_h - 6)
	_status.position = Vector2(10, vp.y - status_h)
	_status.size = Vector2(vp.x - 20, status_h)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.clip_text = true
	_place_dialog()


func _place_dialog() -> void:
	if not _dialog.visible:
		return
	var vp := root.size
	_dialog.size = _dialog.get_combined_minimum_size()
	_dialog.position = ((vp - _dialog.size) / 2.0).max(Vector2(8, 8))


## Whether the pointer at `pos` is over a panel (the map doesn't get it).
func is_over_panel(pos: Vector2) -> bool:
	for c in [_top, _left, _right, _tabs, _dialog]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return picker.visible


func has_popup() -> bool:
	return _dialog.visible or picker.visible


# --- dialogs ---------------------------------------------------------------------------------

func _open_dialog(title: String) -> VBoxContainer:
	_clear(_dialog_box)
	_dialog_box.add_child(_label(title, 22, UiTheme.GOLD))
	_dialog.visible = true
	var vp := root.size
	_dialog_box.custom_minimum_size = Vector2(minf(420.0, vp.x - 60.0), 0)
	_place_dialog.call_deferred()
	return _dialog_box


func close_dialog() -> void:
	_dialog.visible = false


func _dialog_buttons(ok: String, cb: Callable, cancel: String = "Cancel") -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_dialog_box.add_child(row)
	var b := _button(ok, Vector2(0, 44))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_good(b)
	b.pressed.connect(cb)
	row.add_child(b)
	if cancel != "":
		var c := _button(cancel, Vector2(0, 44))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.pressed.connect(close_dialog)
		row.add_child(c)
	return b


func message(title: String, text: String) -> void:
	var box := _open_dialog(title)
	box.add_child(_label(text, 15))
	_dialog_buttons("OK", close_dialog, "")


func confirm(title: String, text: String, yes: String, cb: Callable) -> void:
	var box := _open_dialog(title)
	box.add_child(_label(text, 15))
	_dialog_buttons(yes, func() -> void:
		close_dialog()
		cb.call())


## New: generate a map (size, type, seed, villages) or start a blank one.
func show_new() -> void:
	var st := {"size": 75, "type": "temperate", "seed": "", "villages": 1, "blank": false}
	var box := _open_dialog("New map")
	var body := VBoxContainer.new()
	box.add_child(body)
	var build := func(again: Callable) -> void:
		_clear(body)
		body.add_child(_label("Size", 14, UiTheme.MUTED))
		var sizes := []
		for n in Config.MAP_SIZES:
			sizes.append([n, "%d" % n])
		_choices(body, sizes, st["size"], func(v: Variant) -> void:
			st["size"] = v
			st["villages"] = mini(st["villages"], int(Config.MAP_SIZE_SLOTS[v]))
			again.call(again), 4)
		_toggle(body, "Blank (all meadow, nothing on it)", st["blank"], func(on: bool) -> void:
			st["blank"] = on
			again.call(again))
		if not st["blank"]:
			body.add_child(_label("Map type", 14, UiTheme.MUTED))
			var types := []
			for k in Config.MAP_TYPE_ORDER + ["random"]:
				types.append([k, Settings.map_type_name(k)])
			_choices(body, types, st["type"], func(v: Variant) -> void:
				st["type"] = v
				again.call(again), 3)
			body.add_child(_label("Villages", 14, UiTheme.MUTED))
			var vs := []
			for n in range(1, int(Config.MAP_SIZE_SLOTS[st["size"]]) + 1):
				vs.append([n, str(n)])
			_choices(body, vs, st["villages"], func(v: Variant) -> void:
				st["villages"] = v
				again.call(again), 4)
			var le := LineEdit.new()
			le.placeholder_text = "Seed (empty: random)"
			le.text = st["seed"]
			le.text_changed.connect(func(text: String) -> void: st["seed"] = text)
			body.add_child(le)
		_place_dialog.call_deferred()
	build.call(build)
	_dialog_buttons("Make it", func() -> void:
		var go := func() -> void: _generate(st)
		if MapPicker.warns_large(int(st["size"])):
			confirm("A big map", MapPicker.large_text(int(st["size"])), "Continue", go)
		elif editor.dirty:
			confirm("Unsaved changes", "Throw away the changes to this map?", "Make a new one", go)
		else:
			go.call())


func _generate(st: Dictionary) -> void:
	close_dialog()
	status("Making the map...")
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var m: MapData
	var seed_value := Settings.parse_seed(str(st["seed"]))
	if seed_value == 0:
		seed_value = randi() % 1000000 + 1
	if st["blank"]:
		m = MapData.new(int(st["size"]))
		m.map_type = "temperate"
		m.meta = {"name": "", "origin": {"generator_seed": null, "edited": true, "game_version": MapJson.game_version()}}
		m.derive()
	else:
		var type := Settings.resolve_map_type(str(st["type"]), seed_value)
		m = MapGenerator.generate(seed_value, int(st["villages"]), type, int(st["size"]))
		m.meta = {"name": "", "origin": {"generator_seed": seed_value, "edited": false, "game_version": MapJson.game_version()}}
	editor.set_map(m, "", true)
	status("A new %dx%d map" % [m.size, m.size])


## The map's name, author, description and type; with `save_after`, saves to a new file then.
func show_properties(save_after: bool) -> void:
	var m := editor.map
	var box := _open_dialog("Save as" if save_after else "Map properties")
	var name_edit := _field(box, "Name", str(m.meta.get("name", "")), int(Config.EDITOR["name_max"]))
	var author_edit := _field(box, "Author", str(m.meta.get("author", "")), int(Config.EDITOR["author_max"]))
	box.add_child(_label("Description", 14, UiTheme.MUTED))
	var desc := TextEdit.new()
	desc.text = str(m.meta.get("description", ""))
	desc.custom_minimum_size = Vector2(0, 90)
	desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(desc)
	var type_edit := _field(box, "Map type (any name: letters, digits, space, _ and -)", m.map_type, int(Config.EDITOR["map_type_max"]))
	_dialog_buttons("Save" if save_after else "OK", func() -> void:
		var n := name_edit.text.strip_edges()
		var mt := type_edit.text.strip_edges()
		if n == "":
			status("The map needs a name", true)
			return
		if mt == "" or RegEx.create_from_string("^[A-Za-z0-9 _\\-]+$").search(mt) == null:
			status("The map type: letters, digits, spaces, _ and - only", true)
			return
		if desc.text.length() > int(Config.EDITOR["description_max"]):
			status("The description is too long", true)
			return
		editor.set_properties(n, author_edit.text.strip_edges(), desc.text, mt)
		close_dialog()
		if save_after:
			editor.path = ""
			_save_now()
		refresh())


func _field(box: Control, title: String, value: String, max_len: int) -> LineEdit:
	box.add_child(_label(title, 14, UiTheme.MUTED))
	var le := LineEdit.new()
	le.text = value
	le.max_length = max_len
	box.add_child(le)
	return le


func save() -> void:
	if str(editor.map.meta.get("name", "")).strip_edges() == "":
		show_properties(true)
		return
	_save_now()


func _save_now() -> void:
	var p := editor.save_file()
	if p == "":
		status("Couldn't write the file", true)
	else:
		status("Saved as %s" % p.get_file())
	refresh()


func _on_opened(m: MapData, p: String) -> void:
	var go := func() -> void:
		editor.set_map(m, "" if MapLibrary.is_builtin(p) else p, false)
		status("Opened %s" % MapJson.map_name(m))
	if editor.dirty:
		confirm("Unsaved changes", "Throw away the changes to this map?", "Open it", go)
	else:
		go.call()


func import_file() -> void:
	MapLibrary.import_text(root, func(file_name: String, text: String) -> void:
		if file_name == "":
			return
		var r := MapJson.read(text)
		if r["map"] == null:
			var errs: Array = r["errors"]
			message("%s can't be read" % file_name, "\n".join(errs.slice(0, 12)) + ("\n... (%d problems)" % errs.size() if errs.size() > 12 else ""))
			return
		var m: MapData = r["map"]
		var go := func() -> void:
			editor.set_map(m, "", true)
			status("Imported %s" % file_name)
		if MapPicker.warns_large(m.size):
			confirm("A big map", MapPicker.large_text(m.size), "Continue", go)
		elif editor.dirty:
			confirm("Unsaved changes", "Throw away the changes to this map?", "Import it", go)
		else:
			go.call())


func export_file() -> void:
	MapLibrary.export_map(editor.map, root, func(p: String) -> void:
		if p != "":
			status("Exported %s" % p.get_file()))


## Play: the map's errors, or which village and difficulty.
func show_play() -> void:
	var errs := MapChecks.errors(editor.problems)
	if not errs.is_empty():
		message("It can't be played yet", "\n".join(errs.slice(0, 10).map(func(p: Dictionary) -> String: return "Error: " + str(p["text"]))))
		return
	var st := {"village": 0}
	var box := _open_dialog("Play this map")
	var body := VBoxContainer.new()
	box.add_child(body)
	var build := func(again: Callable) -> void:
		_clear(body)
		if editor.map.villages.size() > 1:
			body.add_child(_label("Your village (the others stand empty)", 14, UiTheme.MUTED))
			var vs := []
			for n in editor.map.villages.size():
				vs.append([n, "Village %d" % (n + 1)])
			_choices(body, vs, st["village"], func(v: Variant) -> void:
				st["village"] = v
				again.call(again), 4)
		var d := _button("Difficulty: %s" % Settings.difficulty_name())
		d.pressed.connect(func() -> void:
			Settings.cycle_difficulty()
			again.call(again))
		body.add_child(d)
	build.call(build)
	_dialog_buttons("Play", func() -> void:
		close_dialog()
		editor.play(int(st["village"])))


func ask_leave() -> void:
	if has_popup():
		if picker.visible:
			picker.close()
		close_dialog()
		return
	if editor.dirty:
		confirm("Leave the editor?", "The changes to this map aren't saved.", "Leave", func() -> void: editor.leave())
	else:
		editor.leave()
