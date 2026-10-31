class_name EditorUi
extends CanvasLayer
## The map editor's panels (docs/map-editor-design.md §4.1): the tools (left:
## undo / redo and the view under the heading, the File tab (files, the map's
## properties, Play, Exit) and the tools, then the current one's options), the
## inspector (right: the selection, the tile under the pointer, layer switches
## and problems), a status line, and the dialogs (New, properties, Play,
## confirm, messages; the map picker). In landscape each side panel folds to
## its edge (its heading stays, at the top); in portrait the two share a bottom
## sheet with two tabs that slides up and down as the game's dock does.

const TOOL_NAMES := {
	"file": "File", "terrain": "Terrain", "zone": "Zone", "props": "Trees, peaks", "decor": "Decor",
	"beach": "Beach", "road": "Road", "volcano": "Volcano", "village": "Village", "piece": "Pieces",
	"spawn": "Spawn", "water": "Water spawn", "slice": "Slice", "object": "Objects",
}
const TOOL_HINTS := {
	"file": "While this tab is open the map isn't edited: click a tile, object or village to see it in the inspector, drag to pan.",
	"village": "Click open land: a new village (the standard layout). Drag a village to move it. Delete removes the selected one.",
	"piece": "Click a tile: the piece below goes there (for the selected or nearest village), of the material below. Flip turns a wall; Paint material gives a piece the material below; Erase removes a piece.",
	"spawn": "Click a road tile at the map's edge: a spawn (for the selected village, or the one of its slice). Click one again to remove it.",
	"water": "Click deep water: a water spawn, where water monsters come from (crabs, sirens, leviathans, octopuses). Its body of water must fit one of them. Click one again to remove it.",
	"object": "Click open land: a new object. Click one to select it, drag it to move it. Delete removes it.",
	"volcano": "Click: a volcano (3x3) there, or remove the one there.",
}
## What a right-click does with each tool (with a mouse; a right drag pans).
const RIGHT_HINTS := {
	"terrain": "Right-click: grass.", "zone": "Right-click: take the tile's zone.", "props": "", "decor": "Right-click: erase decor.",
	"beach": "Right-click: erase beach.", "road": "Right-click: erase road.", "volcano": "Right-click: remove a volcano.",
	"village": "Right-click: delete a village.", "piece": "Right-click: remove a piece.", "spawn": "Right-click: remove a spawn.", "water": "Right-click: remove a water spawn.",
	"slice": "Right-click: take the tile's slice.", "object": "Right-click: delete an object.",
}
const TERRAIN_NAMES := ["Grass", "Road", "Forest", "Desert", "Mountain", "Deep water", "Shallow water", "Lava"]
const LEFT_W := 330.0
const RIGHT_W := 310.0
## Narrower than this (or in portrait) the side panels share the bottom sheet.
const NARROW := 760.0
const STATUS_H := 26.0
## A grid's cells in the wide bottom sheet are at least this wide (more columns fit).
const SHEET_CELL := 150.0
const NO_POS := Vector2(-1e9, -1e9)

var editor: MapEditor
var root: Control
var _left: PanelContainer
var _right: PanelContainer
var _left_head: Button
var _right_head: Button
var _left_scroll: ScrollContainer
var _right_scroll: ScrollContainer
var _left_open := true
var _right_open := true
var _tools_box: VBoxContainer
var _options: VBoxContainer
var _inspect: VBoxContainer
var _tile_box: VBoxContainer
var _layers_box: GridContainer
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
## The road steps from every tile to each village's gates (built when needed, dropped on a change).
var _road_fields: Array[PackedInt32Array] = []
## The map's bodies of deep water (Pathing.label_water), made when needed.
var _water: Dictionary = {}
var _portrait := false
## The content width the grids were last built for (their columns follow it).
var _built_w := -1.0
# The portrait bottom sheet: a handle and the two tabs; the open tab's panel under them.
var _sheet: PanelContainer
var _handle: Control
var _tabs: HBoxContainer
var _tab := "tools"
var _sheet_open := false
var _sheet_h := 0.0
var _sheet_dragging := false
var _drag_from_y := 0.0
var _drag_start_h := 0.0
var _drag_last := Vector2.ZERO  # (y, time in s) of the last move, for the speed
var _drag_speed := 0.0  # px/s, + downwards
var _slide: Tween
var _refit_queued := false
## A press in a panel's list that turned into a scroll fires no button.
var _scroll_from := NO_POS
var _scrolled := false
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
	_left = _panel()
	var lv := _side(_left)
	_left_head = _heading("Tools", true)
	lv.add_child(_left_head)
	_left_scroll = _scroll(lv)
	_tools_box = VBoxContainer.new()
	_tools_box.add_theme_constant_override("separation", 6)
	_tools_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_scroll.add_child(_tools_box)
	_right = _panel()
	var rside := _side(_right)
	_right_head = _heading("Inspector", false)
	rside.add_child(_right_head)
	_right_scroll = _scroll(rside)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_scroll.add_child(rv)
	_inspect = VBoxContainer.new()
	_inspect.add_theme_constant_override("separation", 4)
	rv.add_child(_inspect)
	_tile_box = VBoxContainer.new()
	_tile_box.add_theme_constant_override("separation", 2)
	rv.add_child(_tile_box)
	rv.add_child(_label("Layers", 18, UiTheme.GOLD))
	_layers_box = GridContainer.new()
	_layers_box.add_theme_constant_override("h_separation", 6)
	rv.add_child(_layers_box)
	_problems_title = _label("Problems", 18, UiTheme.GOLD)
	rv.add_child(_problems_title)
	_problems_box = VBoxContainer.new()
	_problems_box.add_theme_constant_override("separation", 2)
	rv.add_child(_problems_box)
	_build_sheet()
	for content in [_tools_box, rv]:
		(content as Control).minimum_size_changed.connect(_queue_refit)
	# A finger scrolls a panel from anywhere on it (as in the game's dock):
	# its boxes let the touch through, its buttons pass it on.
	root.get_tree().node_added.connect(func(n: Node) -> void:
		if n is Control and (_left_scroll.is_ancestor_of(n) or _right_scroll.is_ancestor_of(n)):
			_touch_scrollable.call_deferred(n))
	_build_tools()
	_build_layers()
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
	editor.changed.connect(func() -> void:
		_road_fields.clear()  # (before refresh: it may show road steps)
		_water = {})
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


func _side(p: PanelContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


## A side panel's heading: its name and a chevron towards the map; a tap
## folds the panel to its edge (`left`: the tools) or opens it again.
func _heading(text: String, left: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, UiTheme.GOLD)
	b.add_theme_color_override("font_hover_color", UiTheme.TEXT)
	b.pressed.connect(func() -> void: set_panel_open(left, not (_left_open if left else _right_open)))
	return b


func _scroll(parent: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
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


func _icon_button(icon: String, tip: String, cb: Callable) -> Button:
	var b := _button("", Vector2(48, 36))
	b.icon = Art.tex(icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 24)
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b


## How many columns a grid of `n` cells gets: `base` in the side panels; in
## the wide bottom sheet as many as fit at `cell` px each (at most `n`).
func _cols(base: int, n: int, cell: float = SHEET_CELL) -> int:
	if not _portrait:
		return base
	return clampi(floori(_content_width() / cell), base, maxi(base, n))


## The width a panel's entries get.
func _content_width() -> float:
	var w := (root.size.x - 12.0) if _portrait else LEFT_W
	return w - 30.0  # (the panel's padding and its scroll bar)


func _grid(parent: Control, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g


## A row of choice buttons; `current` is framed. `pick` gets the chosen value.
func _choices(parent: Control, items: Array, current: Variant, pick: Callable, columns: int = 2) -> GridContainer:
	var g := _grid(parent, _cols(columns, items.size()))
	for it in items:
		var value = it[0]
		var b := _button(str(it[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		UiTheme.style_selected(b, value == current)
		b.pressed.connect(func() -> void: pick.call(value))
		g.add_child(b)
	return g


## The materials of walls, gates and wall towers (Config.PIECE_MATERIALS) as choices for option "material".
func _material_choices(o: Dictionary) -> void:
	var items := []
	for k in Config.PIECE_MATERIAL_ORDER:
		items.append([k, Config.PIECE_MATERIALS[k]["name"]])
	_choices(_options, items, o["material"], func(v: Variant) -> void: set_option("material", v))


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


# --- tools -----------------------------------------------------------------------------------

func _build_tools() -> void:
	_clear(_tools_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_tools_box.add_child(row)
	_undo_button = _icon_button("icon_undo", "Undo (Ctrl+Z)", func() -> void: editor.undo())
	row.add_child(_undo_button)
	_redo_button = _icon_button("icon_redo", "Redo (Ctrl+Y)", func() -> void: editor.redo())
	row.add_child(_redo_button)
	_view_button = _button("2D")
	_view_button.tooltip_text = "Isometric or top-down view (Tab)"
	_view_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_button.pressed.connect(func() -> void: editor.toggle_view())
	row.add_child(_view_button)
	var g := _grid(_tools_box, _cols(2, MapEditor.TOOLS.size()))
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


## Sets option `key` of the tools (a choice, or a right-click's pick) and shows it.
func set_option(key: String, value: Variant) -> void:
	editor.opts[key] = value
	_build_options()
	editor._redraw_pointer()


func _build_options() -> void:
	_clear(_options)
	_save_button = null
	var t := editor.tool
	for k in _tool_buttons:
		UiTheme.style_selected(_tool_buttons[k], k == t)
	_options.add_child(_label(TOOL_NAMES[t], 17, UiTheme.GOLD))
	if TOOL_HINTS.has(t):
		_options.add_child(_label(TOOL_HINTS[t], 14, UiTheme.MUTED))
	if not Layout.touch and t != "file":
		_options.add_child(_label((str(RIGHT_HINTS[t]) + " A right drag pans.").strip_edges(), 14, UiTheme.MUTED))
	var o := editor.opts
	match t:
		"file":
			_file_actions()
		"terrain":
			var items := []
			for k in TERRAIN_NAMES.size():
				items.append([k, TERRAIN_NAMES[k]])
			_choices(_options, items, int(o["terrain"]), func(v: Variant) -> void: set_option("terrain", v))
			_toggle(_options, "Fill an area", bool(o["fill"]), func(on: bool) -> void: set_option("fill", on))
		"zone":
			var items := []
			for z in Config.ZONE_ORDER:
				items.append([z, Config.ZONES[z]["name"]])
			_choices(_options, items, o["zone"], func(v: Variant) -> void: set_option("zone", v))
		"props":
			var items := [["auto", "Auto (the zone's)"]]
			for a in _tree_arts() + MapTidy.all_peaks():
				items.append([a, a.replace("_", " ").capitalize()])
			_choices(_options, items, o["prop"], func(v: Variant) -> void: set_option("prop", v), 1)
			_options.add_child(_label("Trees grow on forest, peaks on mountains (houses on a city's).", 14, UiTheme.MUTED))
		"decor":
			var items := [["auto", "Auto (the zone's)"], ["", "Erase"]]
			for a in _decor_arts():
				items.append([a, a.replace("_", " ").capitalize()])
			_choices(_options, items, o["decor"], func(v: Variant) -> void: set_option("decor", v), 1)
		"beach":
			_choices(_options, [[true, "Beach"], [false, "Erase"]], o["beach"], func(v: Variant) -> void: set_option("beach", v))
		"road":
			_choices(_options, [["free", "Paint"], ["path", "Path (2 clicks)"], ["erase", "Erase"]], o["road"], func(v: Variant) -> void: set_option("road", v), 1)
		"volcano":
			_choices(_options, [["add", "Add"], ["remove", "Remove"]], o["volcano"], func(v: Variant) -> void: set_option("volcano", v))
			_toggle(_options, "Ash land around it", bool(o["ash"]), func(on: bool) -> void: set_option("ash", on))
		"piece":
			_choices(_options, [["wall", "Wall"], ["gate", "Gate"], ["wall_tower", "Wall tower"], ["hut", "Hut"], ["flip", "Flip"], ["material", "Paint material"], ["erase", "Erase"]], o["piece"], func(v: Variant) -> void: set_option("piece", v))
			_material_choices(o)
		"village":
			_options.add_child(_label("A new village is made of:", 14, UiTheme.MUTED))
			_material_choices(o)
		"slice":
			_slice_choices(int(o["slice"]))
			var b := _button("Recompute from the villages")
			b.pressed.connect(func() -> void: editor.recompute_slices())
			_options.add_child(b)
		"object":
			var items := []
			for k in MapJson.OBJECT_KINDS:
				items.append([k, k.capitalize()])
			_choices(_options, items, o["object"], func(v: Variant) -> void: set_option("object", v))
			_choices(_options, [[1, "1x1"], [2, "2x2"]], int(o["object_size"]), func(v: Variant) -> void: set_option("object_size", v))
	if t in MapEditor.STROKE_TOOLS and not (t == "road" and o["road"] == "path") and not (t == "terrain" and o["fill"]):
		_options.add_child(_label("Brush", 15, UiTheme.MUTED))
		var sizes := []
		for n in Config.EDITOR["brush_sizes"]:
			sizes.append([n, str(n)])
		_choices(_options, sizes, int(o["brush"]), func(v: Variant) -> void: set_option("brush", v), 4)
		_toggle(_options, "Round", bool(o["round"]), func(on: bool) -> void: set_option("round", on))
	if Layout.touch and t != "file":
		_toggle(_options, "Paint by dragging (else a drag pans)", bool(o["paint"]), func(on: bool) -> void: set_option("paint", on))


## The File tab: the map's files, its properties, Play and Exit.
func _file_actions() -> void:
	var acts := [
		["New", show_new, "Generate a map, or start a blank one"],
		["Open", func() -> void: picker.open(false, "Open a map", "Open"), "Your maps and the built-in ones"],
		["Save", save, "Save to your maps (Ctrl+S)"],
		["Save as", func() -> void: show_properties(true), "Save under another name"],
		["Import", import_file, "Read a map file from anywhere"],
		["Export", export_file, "Write the map as a file anywhere (a download in the browser)"],
		["Properties", func() -> void: show_properties(false), "Name, author, description, map type"],
		["Play", show_play, "Try the map in a game"],
		["Exit", ask_leave, "Leave the map editor, back to the title screen"],
	]
	var g := _grid(_options, _cols(2, acts.size()))
	for a in acts:
		var b := _button(a[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.tooltip_text = a[2]
		b.pressed.connect(a[1])
		g.add_child(b)
		match str(a[0]):
			"Save":
				_save_button = b
				b.text = "Save*" if editor.dirty else "Save"
			"Play":
				UiTheme.style_good(b)
			"Exit":
				UiTheme.style_danger(b)


## The Slice tool's slices, 1-8 (stored 0-7), each in its colour (the lobby's
## village colours, as the Slices layer draws them).
func _slice_choices(current: int) -> void:
	var g := _grid(_options, _cols(4, Config.MAX_PLAYERS, 100.0))
	var font := root.get_theme_font("font", "Button")
	var cell := (_content_width() - 4.0 * (g.columns - 1)) / g.columns
	var long := font.get_string_size("Slice 8", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0 <= cell
	for s in Config.MAX_PLAYERS:
		var b := _button(("Slice %d" if long else "S%d") % (s + 1))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var vi := -1
		for i in editor.map.villages.size():
			if int(editor.map.villages[i].get("slice", -1)) == s:
				vi = i
		b.tooltip_text = "Slice %d%s" % [s + 1, (": village %d's area" % (vi + 1)) if vi >= 0 else ""]
		var col := slice_color(s)
		var on := s == current
		b.add_theme_stylebox_override("normal", UiTheme.box(col.darkened(0.35 if on else 0.62), UiTheme.GOLD if on else col.darkened(0.15), 3 if on else 2, 8, 8))
		b.add_theme_stylebox_override("hover", UiTheme.box(col.darkened(0.45), col, 2, 8, 8))
		b.add_theme_color_override("font_color", Color.WHITE if on else col.lightened(0.45))
		b.pressed.connect(func() -> void: set_option("slice", s))
		g.add_child(b)


## Slice `s`'s colour (the village colours of the co-op lobby).
static func slice_color(s: int) -> Color:
	return Config.VILLAGE_COLORS[s % Config.VILLAGE_COLORS.size()]


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
	out.append_array(Config.EXTRA_DECOR)
	return out


# --- layers, problems, inspector -------------------------------------------------------------

func _build_layers() -> void:
	_clear(_layers_box)
	var names := [["zones", "Zones (isometric)"], ["slices", "Slices"], ["grid", "Grid"], ["passable", "Blocked / shallow"],
		["buildable", "Buildable land"], ["spawns", "Spawns"], ["water_spawns", "Water spawns"], ["villages", "Villages"], ["objects", "Objects"],
		["rings", "Camp rings, fronts"], ["problems", "Problem marks"]]
	_layers_box.columns = _cols(1, names.size() + 1, 210.0)
	for n in names:
		var key: String = n[0]
		var c := _toggle(_layers_box, n[1], bool(editor.layers.get(key, false)), func(on: bool) -> void:
			editor.layers[key] = on
			editor.redraw_layers())
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var flow := int(editor.layers["flow"])
	var b := _button("Road steps: %s" % ("off" if flow < 0 else "village %d" % (flow + 1)))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			_inspect.add_child(_label("Nothing selected: open the File tab and click a tile, object or village.", 14, UiTheme.MUTED))


func _tile_info(t: Vector2i) -> void:
	_tile_details(_inspect, t)


## Tile `t` in words, and its road steps to each village's gates, into `box`.
func _tile_details(box: Control, t: Vector2i) -> void:
	box.add_child(_label(tile_text(t), 14))
	var m := editor.map
	if _road_fields.size() != m.villages.size():
		_road_fields.clear()
		for v in m.villages:
			_road_fields.append(GenChecks.road_field(m, v["gates"]) if not (v["gates"] as Array).is_empty() else PackedInt32Array())
	for i in m.villages.size():
		if _road_fields[i].is_empty():
			continue
		var d := _road_fields[i][m.index(t)]
		if d < 1 << 29:
			box.add_child(_label("Road steps to village %d: %d" % [i + 1, d], 14, UiTheme.MUTED))
	var w := water_text(t)
	if w != "":
		box.add_child(_label(w, 14, UiTheme.MUTED))


## The body of deep water under `t` in words ("" if none): its size, its
## width and which water monsters fit in it.
func water_text(t: Vector2i) -> String:
	var m := editor.map
	if not m.is_deep(t):
		return ""
	if _water.is_empty() or (_water["of"] as PackedInt32Array).size() != m.size * m.size:
		_water = Pathing.label_water(m)
	var b := int(_water["of"][m.index(t)])
	if b < 0:
		return ""
	var body: Dictionary = _water["bodies"][b]
	var fits := Pathing.kinds_fitting(body)
	var names := PackedStringArray()
	for k in fits:
		names.append(str(Config.ENEMIES[k]["name"]).to_lower())
	return "Water body: %d deep tiles, %d wide · %s" % [int(body["deep"]), int(body["width"]), "fits " + ", ".join(names) if not names.is_empty() else "too small for water monsters"]


## The inspector's tile under the pointer (with a finger: the last one tapped).
func _show_tile(t: Vector2i) -> void:
	_clear(_tile_box)
	if editor.map == null or not editor.map.in_bounds(t):
		return
	_tile_box.add_child(_label("Last tapped" if Layout.touch else "Under the pointer", 15, UiTheme.GOLD))
	_tile_details(_tile_box, t)


## What tile `t` is, in words (the inspector, the status line).
func tile_text(t: Vector2i) -> String:
	var m := editor.map
	if not m.in_bounds(t):
		return ""
	var parts := ["Tile %d, %d" % [t.x, t.y], TERRAIN_NAMES[m.get_terrain(t)], Config.ZONES[m.zone(t)]["name"], "slice %d" % (m.slice_of[m.index(t)] + 1)]
	if m.props.has(t):
		parts.append(str(m.props[t]))
	if m.decor.has(t):
		parts.append(str(m.decor[t]))
	if m.crossings.has(t):
		parts.append(str(m.crossings[t][0]))
	if m.beaches.has(t):
		parts.append("beach")
	for p in m.village_layout:
		if p["tile"] == t:
			parts.append("%s (%s)" % [str(p["kind"]).replace("_", " "), str(Config.PIECE_MATERIALS[p["material"]]["name"]).to_lower()])
	return " · ".join(parts)


func _object_info(i: int) -> void:
	var m := editor.map
	if i >= m.objects.size():
		return
	var o := m.objects[i]
	var t: Vector2i = o["tile"]
	_inspect.add_child(_label("%s %d at %d, %d (%dx%d, slice %d)" % [str(o["kind"]).capitalize(), i + 1, t.x, t.y, int(o.get("size", 1)), int(o.get("size", 1)), int(o.get("slice", 0)) + 1], 15))
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
		"ruin":
			var bk := str(o.get("building", "tower"))
			_inspect.add_child(_label("A ruined %s: restored, it becomes one again (placed as 1x1: a watchtower, 2x2: barracks)" % str(Config.BUILDINGS[bk]["name"]).to_lower(), 14))
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
		(v["home_spawns"] as Array).size(), int(v.get("slice", 0)) + 1, "" if MapChecks.standard_layout(m, i) else "\nNot the standard layout"], 14))
	var row := HBoxContainer.new()
	_inspect.add_child(row)
	for d in [[-1, "Number -1"], [1, "Number +1"]]:
		var b := _button(d[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var by: int = d[0]
		b.pressed.connect(func() -> void: editor.move_village_number(i, by))
		row.add_child(b)
	var mats := {}
	for p in pieces:
		mats[p["material"]] = true
	var names := []
	for k in Config.PIECE_MATERIAL_ORDER:
		if mats.has(k):
			names.append(str(Config.PIECE_MATERIALS[k]["name"]).to_lower())
	_inspect.add_child(_label("Made of %s. Make it all:" % (", ".join(names) if not names.is_empty() else "nothing"), 14))
	var mrow := _grid(_inspect, _cols(2, Config.PIECE_MATERIAL_ORDER.size()))
	for k in Config.PIECE_MATERIAL_ORDER:
		var mb := _button(str(Config.PIECE_MATERIALS[k]["name"]))
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.style_selected(mb, names.size() == 1 and mats.has(k))
		var mk: String = k
		mb.pressed.connect(func() -> void: editor.set_village_material(i, mk))
		mrow.add_child(mb)
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
	_show_tile(t)


# --- status ----------------------------------------------------------------------------------

func refresh() -> void:
	if _undo_button == null or editor.map == null:
		return
	_undo_button.disabled = not editor.can_undo()
	_redo_button.disabled = not editor.can_redo()
	_view_button.text = "Isometric" if editor.plan_mode else "2D"
	if _save_button:
		_save_button.text = "Save*" if editor.dirty else "Save"
	_build_layers()
	_show_inspector()
	_show_tile(editor.hover)
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
	_portrait = Layout.portrait or vp.x < NARROW
	if not is_equal_approx(_content_width(), _built_w):
		# (the grids' columns follow the width)
		_built_w = _content_width()
		_build_tools()
		_build_layers()
		_show_inspector()
		refresh()
	if _slide:
		_slide.kill()
		_slide = null
	_left_head.visible = not _portrait
	_right_head.visible = not _portrait
	_sheet.visible = _portrait
	if _portrait:
		_left_scroll.visible = true
		_right_scroll.visible = true
		for b in _tabs.get_children():
			UiTheme.style_selected(b, _sheet_open and b.get_meta("tab") == _tab)
		if not _sheet_dragging:
			_place_sheet(_open_h() if _sheet_open else _folded_h())
	else:
		var h := vp.y - STATUS_H - 12.0
		_left.visible = true
		_right.visible = true
		_left_scroll.visible = _left_open
		_right_scroll.visible = _right_open
		_left_head.icon = Art.tex("icon_expand" if _left_open else "icon_collapse")
		_right_head.icon = Art.tex("icon_collapse" if _right_open else "icon_expand")
		_left_head.tooltip_text = "Fold the tools away" if _left_open else "Show the tools"
		_right_head.tooltip_text = "Fold the inspector away" if _right_open else "Show the inspector"
		_left.size = Vector2(LEFT_W, h) if _left_open else _folded_size(_left, _left_head)
		_left.position = Vector2(6, 6)
		_right.size = Vector2(RIGHT_W, h) if _right_open else _folded_size(_right, _right_head)
		_right.position = Vector2(vp.x - _right.size.x - 6.0, 6)
	_status.position = Vector2(10, vp.y - STATUS_H)
	_status.size = Vector2(vp.x - 20, STATUS_H)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.clip_text = true
	_place_dialog()


## A folded side panel: just its heading.
func _folded_size(p: PanelContainer, head: Button) -> Vector2:
	return head.get_combined_minimum_size() + p.get_theme_stylebox("panel").get_minimum_size()


## Opens or folds a side panel (landscape; `left`: the tools, else the inspector).
func set_panel_open(left: bool, open: bool) -> void:
	if left:
		_left_open = open
	else:
		_right_open = open
	_fit()


## What Play keeps of the panels for coming back (the editor's session).
func panel_state() -> Dictionary:
	return {"left": _left_open, "right": _right_open, "tab": _tab, "sheet": _sheet_open}


func set_panel_state(st: Dictionary) -> void:
	_left_open = bool(st.get("left", true))
	_right_open = bool(st.get("right", true))
	_tab = str(st.get("tab", "tools"))
	_sheet_open = bool(st.get("sheet", false))
	_fit()


func _queue_refit() -> void:
	if not _refit_queued:
		_refit_queued = true
		_refit.call_deferred()


## A page's content changed size: the open sheet fits it again.
func _refit() -> void:
	_refit_queued = false
	if _portrait and _sheet_open and not _sheet_dragging and _slide == null:
		_place_sheet(_open_h())


# --- the portrait bottom sheet ---------------------------------------------------------------

func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UiTheme.box(Color(0.12, 0.08, 0.06, 0.92), UiTheme.GOLD, 2, 8, 6))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_sheet.add_child(v)
	# The grab handle over the tabs: tap it, or drag it up / down.
	_handle = Control.new()
	_handle.custom_minimum_size = Vector2(0, 24)  # (room for a finger)
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_handle.tooltip_text = "Drag up to open, down to close"
	_handle.draw.connect(func() -> void:
		var w := 72.0
		var r := Rect2((_handle.size.x - w) / 2.0, (_handle.size.y - 7.0) / 2.0, w, 7.0)
		_handle.draw_style_box(UiTheme.box(UiTheme.MUTED, UiTheme.MUTED, 0, 4, 0), r))
	_handle.gui_input.connect(_on_sheet_drag.bind(_handle))
	v.add_child(_handle)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.mouse_filter = Control.MOUSE_FILTER_STOP  # (the gap between the tabs drags the sheet too)
	_tabs.gui_input.connect(_on_sheet_drag.bind(_tabs))
	v.add_child(_tabs)
	for t in [["tools", "Tools"], ["info", "Inspector"]]:
		var b := _button(t[1], Vector2(0, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("tab", t[0])
		b.pressed.connect(_on_tab_pressed.bind(t[0]))
		b.gui_input.connect(_on_sheet_drag.bind(b))  # (a tap switches the tab, a drag moves the sheet)
		_tabs.add_child(b)


## A tab: opens the sheet on it; the open tab folds the sheet.
func _on_tab_pressed(tab: String) -> void:
	if _sheet_open and tab == _tab:
		_sheet_open = false
	else:
		_sheet_open = true
		_tab = tab
	_fit()


## The sheet's top at `h` above the status line: the handle and tabs there,
## the open tab's panel under them (hidden while folded).
func _place_sheet(h: float) -> void:
	_sheet_h = h
	var vp := root.size
	var top := vp.y - STATUS_H - h
	var folded := _folded_h()
	_sheet.position = Vector2(6, top)
	_sheet.size = Vector2(vp.x - 12, folded)
	var page := _left if _tab == "tools" else _right
	(_right if _tab == "tools" else _left).visible = false
	page.visible = h - folded > 4.0
	page.position = Vector2(6, top + folded)
	page.size = Vector2(vp.x - 12, maxf(h - folded, 0.0))


func _folded_h() -> float:
	return _sheet.get_combined_minimum_size().y


## The open sheet's height: its page's entries, at most Hud.SHEET_MAX of the
## screen (but at least Hud.SHEET_MIN_CONTENT px of entries); the rest scrolls.
func _open_h() -> float:
	var page := _left if _tab == "tools" else _right
	var scroll := _left_scroll if _tab == "tools" else _right_scroll
	var content: float = (scroll.get_child(0) as Control).get_combined_minimum_size().y + page.get_theme_stylebox("panel").get_minimum_size().y + 4.0
	var folded := _folded_h()
	return folded + minf(content, maxf(root.size.y * Hud.SHEET_MAX - folded, Hud.SHEET_MIN_CONTENT))


## Dragging the sheet by its handle, a tab or the gap between them: it follows
## the finger, and on letting go a flick (Hud.SHEET_FLICK) or else the nearer
## end decides. A tap does what it always did (the handle opens / folds, a tab
## switches).
func _on_sheet_drag(event: InputEvent, source: Control) -> void:
	if not _portrait:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var y: float = event.global_position.y
		if event.pressed:
			_drag_from_y = y
			_drag_start_h = _sheet_h
			_sheet_dragging = false
			_drag_speed = 0.0
			_drag_last = Vector2(y, now)
		elif _sheet_dragging:
			_sheet_dragging = false
			var open := _sheet_h > (_folded_h() + _open_h()) / 2.0
			if absf(_drag_speed) > Hud.SHEET_FLICK:
				open = _drag_speed < 0.0
			var from := _sheet_h
			_sheet_open = open
			_fit()
			_slide_sheet(from)
			source.accept_event()  # (a drag is no tap)
		elif source == _handle:
			_sheet_open = not _sheet_open
			_fit()
		if source == _handle:
			source.accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var y: float = event.global_position.y
		if not _sheet_dragging and absf(y - _drag_from_y) > CameraController.DRAG_THRESHOLD:
			_sheet_dragging = true
			if source is BaseButton:
				source.disabled = true  # (drops its press: letting go won't tap it)
				source.disabled = false
		if _sheet_dragging:
			var dt := now - _drag_last.y
			if dt > 0.0:
				_drag_speed = lerpf(_drag_speed, (y - _drag_last.x) / dt, 0.6)
			_drag_last = Vector2(y, now)
			_place_sheet(clampf(_drag_start_h - (y - _drag_from_y), _folded_h(), _open_h()))
			source.accept_event()


## After a drag: the sheet glides from height `from` to where it settled.
func _slide_sheet(from: float) -> void:
	var to := _sheet_h
	if is_equal_approx(from, to):
		return
	_place_sheet(from)
	_slide = create_tween()
	_slide.tween_method(_place_sheet, from, to, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slide.finished.connect(func() -> void: _slide = null)


func _touch_scrollable(n: Variant) -> void:  # Variant: a deferred call may get a freed node
	if not is_instance_valid(n) or not n is Control:
		return
	var c := n as Control
	if c is Range or c is LineEdit or c is TextEdit or c is ScrollContainer:
		pass  # (they need the drag themselves)
	elif c is BaseButton or c.tooltip_text != "":
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in c.get_children():
		_touch_scrollable(k)


## A press in a panel's entries that turns into a scroll is no tap: its
## button doesn't fire on release.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var inside := [_left_scroll, _right_scroll].any(func(s: ScrollContainer) -> bool: return s.is_visible_in_tree() and s.get_global_rect().has_point(event.position))
			_scroll_from = event.position if inside else NO_POS
			_scrolled = false
		else:
			if _scrolled:
				_cancel_presses(_left_scroll)
				_cancel_presses(_right_scroll)
			_scroll_from = NO_POS
			_scrolled = false
	elif event is InputEventMouseMotion and _scroll_from != NO_POS and not _scrolled:
		if absf(event.position.y - _scroll_from.y) > CameraController.DRAG_THRESHOLD:
			_scrolled = true


func _cancel_presses(n: Node) -> void:
	for k in n.get_children():
		if k is BaseButton and not k.toggle_mode and k.is_pressed() and not k.disabled:
			k.disabled = true  # (resets the press)
			k.disabled = false
		_cancel_presses(k)


func _place_dialog() -> void:
	if not _dialog.visible:
		return
	var vp := root.size
	_dialog.size = _dialog.get_combined_minimum_size()
	_dialog.position = ((vp - _dialog.size) / 2.0).max(Vector2(8, 8))


## Whether the pointer at `pos` is over a panel (the map doesn't get it).
func is_over_panel(pos: Vector2) -> bool:
	for c in [_left, _right, _sheet, _dialog]:
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
