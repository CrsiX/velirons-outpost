class_name MapEditor
extends Node2D
## The map editor (docs/map-editor-design.md): the root of scenes/map_editor.tscn.
## Holds the map being edited, its file, the tool and its options, the layer
## switches, the selection, undo / redo and the checks; shows the map in the
## isometric view (IsoView) or the top-down one (PlanView), with overlays;
## routes the pointer to the tools (EditorTools); the panels are EditorUi.

signal changed
signal selection_changed

## The tools, in the order of the tool panel. "file" (the File tab) edits
## nothing: a click selects, a drag pans.
const TOOLS: Array[String] = ["file", "terrain", "zone", "props", "decor", "beach", "road", "volcano", "village", "piece", "spawn", "water", "slice", "object"]
## Tools that paint along a drag.
const STROKE_TOOLS: Array[String] = ["terrain", "zone", "props", "decor", "beach", "slice", "road"]
const NO_TILE := Vector2i(-1, -1)
const NO_POS := Vector2(-1e9, -1e9)

var map: MapData
## The file it came from / is saved to ("" = not saved yet; a built-in map: saved as a copy).
var path := ""
var dirty := false
var tool := "file"
var opts := {
	"terrain": MapData.Terrain.FOREST, "zone": "meadow", "brush": 3, "round": true, "fill": false,
	"prop": "auto", "decor": "auto", "beach": true, "road": "free", "volcano": "add", "ash": true,
	"piece": "wall", "material": "stone", "slice": 0, "object": "treasure", "object_size": 1, "paint": false,
}
## Layer switches (EditorOverlay); "flow": the village whose road steps show (-1: none).
var layers := {
	"zones": false, "slices": false, "grid": false, "passable": false, "buildable": false, "flow": -1,
	"spawns": true, "water_spawns": true, "villages": true, "objects": true, "rings": false, "problems": true,
}
## {"type": "tile" | "object" | "village", "tile" / "index"}; empty: nothing.
var selected: Dictionary = {}
var problems: Array[Dictionary] = []
## The road a Path click would lay (from the first click to the pointer).
var path_preview: Array[Vector2i] = []
var plan_mode := false
## The next click picks a tile for the inspector: {"what": "guards" | "front" |
## "center", "index"} (a camp's treasure, a lair's or mine's front, a village's centre).
var pick_mode: Dictionary = {}
var hover := NO_TILE
var camera: CameraController
var iso: IsoView
var plan: PlanView
var ui: EditorUi
var _overlays: Array[EditorOverlay] = []
var _undo: Array[PackedByteArray] = []
var _redo: Array[PackedByteArray] = []
## A drag in progress: {"kind": "stroke" | "village" | "object", "before" (bytes), "last" (tile), "index", "changed"}.
var _drag: Dictionary = {}
var _road_start := NO_TILE
var _checks_in := -1.0
var _middle_pan := false
## A right press on the map (screen position; NO_POS: none): let go where it
## was, it erases; dragged, it pans.
var _right_from := NO_POS
var _right_panned := false
## The zoom the layers were last drawn at (their labels keep their size on screen).
var _drawn_zoom := 1.0
var _pan_last := Vector2.ZERO


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	camera = CameraController.new()
	camera.name = "Camera"
	add_child(camera)
	camera.make_current()
	camera.set_view_zoom(1.0)
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.press_filter = func(pos: Vector2) -> bool: return _claims(pos)
	camera.wheel_filter = func(pos: Vector2) -> bool: return ui != null and ui.is_over_panel(pos)
	camera.tapped.connect(_on_tapped)
	camera.hovered.connect(_on_hovered)
	iso = IsoView.new()
	iso.name = "Iso"
	add_child(iso)
	plan = PlanView.new()
	plan.name = "Plan"
	add_child(plan)
	ui = EditorUi.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(self)
	var s := Settings.editor_session
	if not s.is_empty() and s.get("map") is MapData:
		_restore(s)
	else:
		set_map(MapGenerator.generate(randi() % 100000, 1, "temperate"), "", false)
		map.meta = {"name": "", "origin": {"generator_seed": map.seed_value, "edited": false, "game_version": MapJson.game_version()}}
	Settings.editor_session = {}


func _restore(s: Dictionary) -> void:
	set_map(s["map"], str(s.get("path", "")), bool(s.get("dirty", false)))
	_undo.assign(s.get("undo", []))
	_redo.assign(s.get("redo", []))
	if bool(s.get("plan", false)) != plan_mode:
		toggle_view()
	camera.position = _to_world(s.get("view", Vector2(map.size, map.size) / 2.0))
	camera.zoom = s.get("zoom", camera.zoom)
	tool = str(s.get("tool", tool))
	ui.set_panel_state(s.get("panels", {}))
	ui.set_tool(tool)


## What Play leaves behind for coming back (Settings.editor_session).
func session() -> Dictionary:
	return {"map": map, "path": path, "dirty": dirty, "undo": _undo, "redo": _redo, "plan": plan_mode,
		"view": _to_grid(camera.position), "zoom": camera.zoom, "tool": tool, "panels": ui.panel_state()}


# --- the map ---------------------------------------------------------------------------------

## Shows `m` (a new map: the views are made again, undo starts over).
func set_map(m: MapData, p_path: String, p_dirty: bool) -> void:
	map = m
	if not map.meta.has("origin"):
		map.meta["origin"] = {"generator_seed": map.seed_value if map.seed_value != 0 else null, "edited": false, "game_version": MapJson.game_version()}
	map.derive()
	MapJson.derive_object_slices(map)
	path = p_path
	dirty = p_dirty
	_undo.clear()
	_redo.clear()
	selected = {}
	_drag = {}
	_road_start = NO_TILE
	path_preview.clear()
	layers["flow"] = mini(int(layers["flow"]), map.villages.size() - 1)
	_overlays.clear()
	for p in [false, true]:
		for d in [false, true]:
			_overlays.append(EditorOverlay.new(self, p, d))
	iso.setup(map, [_overlays[0], _overlays[1]])
	plan.setup(map, [_overlays[2], _overlays[3]])
	_set_view_bounds()
	camera.focus(_to_world(Vector2(map.villages[0]["center"]) if not map.villages.is_empty() else Vector2(map.size, map.size) / 2.0))
	_run_checks()
	changed.emit()
	selection_changed.emit()


## The map's view changed (layers, problems): the layer overlays again.
func redraw_layers() -> void:
	for o in _overlays:
		if not o.dynamic:
			o.queue_redraw()


func _redraw_pointer() -> void:
	for o in _overlays:
		if o.dynamic:
			o.queue_redraw()


## Switches between the isometric and the top-down view, keeping the tile in the middle.
func toggle_view() -> void:
	var g := _to_grid(camera.position)
	var z := camera.zoom.x
	var tile_w := Iso.HALF_W * 2.0
	plan_mode = not plan_mode
	_set_view_bounds()
	var px := float(Config.EDITOR["plan_tile_px"])
	z = z * tile_w / px if plan_mode else z * px / tile_w
	var lim := camera.zoom_limits()
	z = clampf(z, lim.x, lim.y)
	camera.zoom = Vector2(z, z)
	camera.focus(_to_world(g))
	_redraw_pointer()
	ui.refresh()


func _set_view_bounds() -> void:
	iso.visible = not plan_mode
	plan.visible = plan_mode
	if plan_mode:
		var px := float(Config.EDITOR["plan_tile_px"])
		camera.bounds = Rect2(Vector2.ZERO, Vector2(map.size, map.size) * px)
		camera.min_zoom = float(Config.EDITOR["plan_min_zoom"])
		camera.max_zoom = float(Config.EDITOR["plan_max_zoom"])
	else:
		var s := float(map.size) - 0.5
		var r := Rect2(Iso.to_world(Vector2(-0.5, -0.5)), Vector2.ZERO)
		for p in [Vector2(s, -0.5), Vector2(-0.5, s), Vector2(s, s)]:
			r = r.expand(Iso.to_world(p))
		camera.bounds = r
		camera.min_zoom = float(Config.EDITOR["min_zoom"])
		camera.max_zoom = float(Config.EDITOR["max_zoom"])


func _to_world(g: Vector2) -> Vector2:
	return (g + Vector2(0.5, 0.5)) * float(Config.EDITOR["plan_tile_px"]) if plan_mode else Iso.to_world(g)


func _to_grid(w: Vector2) -> Vector2:
	return w / float(Config.EDITOR["plan_tile_px"]) - Vector2(0.5, 0.5) if plan_mode else Iso.to_grid(w)


## The tile under world position `w` (in the current view).
func tile_at(w: Vector2) -> Vector2i:
	return Vector2i(_to_grid(w).round())


## Centres the view on tile `t`.
func view_tile(t: Vector2i) -> void:
	camera.focus(_to_world(Vector2(t)))


# --- input -----------------------------------------------------------------------------------

## A left press on the map at `screen_pos` belongs to the tool (not panning):
## with a mouse for every tool (not the File tab); with a finger only with
## "Paint" on.
func _claims(screen_pos: Vector2) -> bool:
	if ui.is_over_panel(screen_pos) or ui.has_popup():
		return false
	if tool == "file":
		return false
	return not Layout.touch or bool(opts["paint"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_pan = mb.pressed
			_pan_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var free := not ui.is_over_panel(mb.position) and not ui.has_popup()
				_right_from = mb.position if free else NO_POS
				_right_panned = false
				_pan_last = mb.position
			elif _right_from != NO_POS:
				if not _right_panned:
					_erase(tile_at(camera.screen_to_world(mb.position)))
				_right_from = NO_POS
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _claims(mb.position):
				_press(tile_at(camera.screen_to_world(mb.position)))
			elif not mb.pressed and not _drag.is_empty():
				_release(tile_at(camera.screen_to_world(mb.position)))
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _right_from != NO_POS and not _right_panned and mm.position.distance_to(_right_from) > CameraController.DRAG_THRESHOLD:
			_right_panned = true
		if _middle_pan or (_right_from != NO_POS and _right_panned):
			camera.focus(camera.position - (mm.position - _pan_last) / camera.zoom)
			_pan_last = mm.position
		elif not _drag.is_empty():
			_drag_to(tile_at(camera.screen_to_world(mm.position)))
	elif event is InputEventKey and event.pressed and not event.is_echo():
		_key(event as InputEventKey)


func _key(k: InputEventKey) -> void:
	var cmd := k.ctrl_pressed or k.meta_pressed
	match k.keycode:
		KEY_Z:
			if cmd and k.shift_pressed:
				redo()
			elif cmd:
				undo()
		KEY_Y:
			if cmd:
				redo()
		KEY_S:
			if cmd:
				ui.save()
		KEY_TAB:
			toggle_view()
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
		KEY_ESCAPE:
			if ui.has_popup():
				ui.ask_leave()  # (closes the dialog)
			elif not pick_mode.is_empty():
				pick_mode = {}
				ui.status("")
			elif _road_start != NO_TILE or not _drag.is_empty():
				_road_start = NO_TILE
				path_preview.clear()
				_drag = {}
				_redraw_pointer()
			elif not selected.is_empty():
				select({})
			else:
				ui.ask_leave()
		_:
			return
	get_viewport().set_input_as_handled()


func _on_hovered(w: Vector2) -> void:
	var t := tile_at(w)
	if t == hover:
		return
	hover = t
	if tool == "road" and opts["road"] == "path" and _road_start != NO_TILE:
		path_preview = EditorTools.road_path(map, _road_start, t)
	_redraw_pointer()
	ui.show_hover(t)


## A tap the camera didn't treat as a pan: with the File tab open it selects;
## with a finger (Paint off) every tool acts once where it was tapped.
func _on_tapped(w: Vector2) -> void:
	if ui.has_popup():
		return  # (a dialog is open: the map waits)
	var t := tile_at(w)
	if Layout.touch:
		hover = t  # (no hover with a finger: the inspector shows the tile tapped)
		ui.show_hover(t)
	if not pick_mode.is_empty():
		_picked(t)
		return
	if tool == "file":
		_pick(t)
		return
	_press(t)
	if not _drag.is_empty():
		_release(t)


## The tiles the brush covers under the pointer (for the pointer overlay).
func brush_tiles() -> Array[Vector2i]:
	if hover == NO_TILE or not map.in_bounds(hover) or tool in ["file", "village", "object", "spawn", "water"]:
		return [] as Array[Vector2i]
	if tool in ["piece", "volcano"] or (tool == "road" and opts["road"] == "path") or (tool == "terrain" and opts["fill"]):
		return [hover] as Array[Vector2i]
	return EditorTools.brush(hover, int(opts["brush"]), bool(opts["round"]))


func _press(t: Vector2i) -> void:
	if not map.in_bounds(t):
		return
	if not pick_mode.is_empty():
		_picked(t)
		return
	match tool:
		"file":
			_pick(t)
		"terrain":
			if opts["fill"]:
				edit(func() -> Variant: return EditorTools.fill_terrain(map, t, int(opts["terrain"])))
			else:
				_begin_stroke(t)
		"zone", "props", "decor", "beach", "slice":
			_begin_stroke(t)
		"road":
			if opts["road"] == "path":
				if _road_start == NO_TILE:
					_road_start = t
					path_preview = [t] as Array[Vector2i]
					ui.status("Now click where the road goes")
				else:
					var tiles := EditorTools.road_path(map, _road_start, t)
					_road_start = NO_TILE
					path_preview.clear()
					if tiles.is_empty():
						ui.status("No way for a road there", true)
					else:
						edit(func() -> Variant: return EditorTools.paint_road(map, tiles, false))
				_redraw_pointer()
			else:
				_begin_stroke(t)
		"volcano":
			if opts["volcano"] == "add":
				edit(func() -> Variant: return EditorTools.add_volcano(map, t, bool(opts["ash"])), true)
			else:
				edit(func() -> Variant: return EditorTools.remove_volcano(map, t), true)
		"village":
			var vi := village_at(t)
			if vi >= 0:
				select({"type": "village", "index": vi})
				_drag = {"kind": "village", "index": vi, "from": t, "last": t}
			else:
				var r := []  # (a lambda can't assign the caller's locals; it can fill this)
				if edit(func() -> Variant:
						r.append(EditorTools.add_village(map, t, str(opts["material"])))
						return r[0] if r[0] is String else MapChecks.standard_pieces(t).map(func(p: Dictionary) -> Vector2i: return p["tile"]), true):
					select({"type": "village", "index": int(r[0])})
		"piece":
			var owner := village_at(t)
			if owner < 0:
				owner = int(selected["index"]) if selected.get("type") == "village" else _nearest_village(t)
			edit(func() -> Variant: return EditorTools.set_piece(map, t, str(opts["piece"]), owner, str(opts["material"])), true)
		"spawn":
			var owner := int(selected["index"]) if selected.get("type") == "village" else -1
			edit(func() -> Variant: return EditorTools.toggle_spawn(map, t, owner))
		"water":
			edit(func() -> Variant: return EditorTools.toggle_water_spawn(map, t))
		"object":
			var oi := object_at(t)
			if oi >= 0:
				select({"type": "object", "index": oi})
				_drag = {"kind": "object", "index": oi, "from": t, "last": t}
			else:
				var r := []
				if edit(func() -> Variant:
						r.append(EditorTools.add_object(map, str(opts["object"]), t, int(opts["object_size"])))
						return r[0] if r[0] is String else Building.footprint(t, int(opts["object_size"])), true):
					select({"type": "object", "index": int(r[0])})


## A right-click (no drag) at `t`: the tool's opposite there, once: erase
## what it puts (terrain: back to grass); Zone and Slice take the tile's (they
## have no "nothing"), Trees / peaks does nothing. First it cancels a pick or
## a road being laid, as Esc does.
func _erase(t: Vector2i) -> void:
	if not pick_mode.is_empty():
		pick_mode = {}
		ui.status("")
		return
	if _road_start != NO_TILE:
		_road_start = NO_TILE
		path_preview.clear()
		_redraw_pointer()
		return
	if not map.in_bounds(t) or not _drag.is_empty():
		return
	match tool:
		"terrain":
			if opts["fill"]:
				edit(func() -> Variant: return EditorTools.fill_terrain(map, t, MapData.Terrain.GRASS))
			else:
				_stamp(t)
		"decor", "beach":
			_stamp(t)
		"road":
			if opts["road"] == "path":
				edit(func() -> Variant: return EditorTools.paint_road(map, [t], true))
			else:
				_stamp(t)
		"zone":
			ui.set_option("zone", map.zone(t))
			ui.status("Zone: %s" % Config.ZONES[map.zone(t)]["name"])
		"slice":
			ui.set_option("slice", int(map.slice_of[map.index(t)]))
			ui.status("Slice %d" % (map.slice_of[map.index(t)] + 1))
		"volcano":
			if MapTidy.in_volcano(map, t):
				edit(func() -> Variant: return EditorTools.remove_volcano(map, t), true)
			else:
				ui.status("No volcano there", true)
		"piece":
			edit(func() -> Variant: return EditorTools.set_piece(map, t, "erase", -1), true)
		"spawn":
			if map.villages.any(func(v: Dictionary) -> bool: return (v["home_spawns"] as Array).has(t)):
				edit(func() -> Variant: return EditorTools.toggle_spawn(map, t, -1))
			else:
				ui.status("No spawn there", true)
		"water":
			if map.water_spawns.has(t):
				edit(func() -> Variant: return EditorTools.toggle_water_spawn(map, t))
			else:
				ui.status("No water spawn there", true)
		"village":
			var vi := village_at(t)
			if vi >= 0:
				select({"type": "village", "index": vi})
				delete_selected()
		"object":
			var oi := object_at(t)
			if oi >= 0:
				select({"type": "object", "index": oi})
				delete_selected()


## One brush stamp of the tool's erase at `t` (one undo step).
func _stamp(t: Vector2i) -> void:
	_begin_stroke(t, true)
	_release(t)


func _drag_to(t: Vector2i) -> void:
	if t == _drag.get("last", NO_TILE):
		return
	if _drag["kind"] == "stroke":
		var from: Vector2i = _drag["last"]
		var line := _line(from, t)
		_drag["last"] = t
		var tiles: Array[Vector2i] = []
		for p in line:
			tiles.append_array(EditorTools.brush(p, int(opts["brush"]), bool(opts["round"])))
		_stroke_apply(tiles)
	else:
		_drag["last"] = t
		hover = t
		_redraw_pointer()


func _release(t: Vector2i) -> void:
	var d := _drag
	_drag = {}
	match str(d.get("kind", "")):
		"stroke":
			if not (d["changed"] as Dictionary).is_empty():
				_push_undo(d["before"])
				_after_edit(d["changed"].keys(), false)
		"village":
			if t != d["from"]:
				var i := int(d["index"])
				var c: Vector2i = map.villages[i]["center"] + (t - (d["from"] as Vector2i))
				edit(func() -> Variant: return EditorTools.move_village(map, i, c), true)
		"object":
			if t != d["from"]:
				var i := int(d["index"])
				edit(func() -> Variant: return EditorTools.move_object(map, i, t), true)


## `erase`: the tool's erase (a right-click) instead of its paint.
func _begin_stroke(t: Vector2i, erase: bool = false) -> void:
	_drag = {"kind": "stroke", "before": map.to_bytes(), "last": t, "changed": {}, "erase": erase}
	_stroke_apply(EditorTools.brush(t, int(opts["brush"]), bool(opts["round"])))


## One step of a stroke: the tool on `tiles`, shown at once (undo comes at its end).
func _stroke_apply(tiles: Array[Vector2i]) -> void:
	var done: Array[Vector2i] = []
	var erase := bool(_drag.get("erase", false))
	match tool:
		"terrain":
			done = EditorTools.paint_terrain(map, tiles, MapData.Terrain.GRASS if erase else int(opts["terrain"]))
		"zone":
			done = EditorTools.paint_zone(map, tiles, str(opts["zone"]))
		"props":
			done = EditorTools.paint_prop(map, tiles, str(opts["prop"]))
		"decor":
			done = EditorTools.paint_decor(map, tiles, "" if erase else str(opts["decor"]))
		"beach":
			done = EditorTools.paint_beach(map, tiles, bool(opts["beach"]) and not erase)
		"slice":
			done = EditorTools.paint_slice(map, tiles, int(opts["slice"]))
		"road":
			done = EditorTools.paint_road(map, tiles, erase or opts["road"] == "erase")
	if done.is_empty():
		return
	for t in done:
		(_drag["changed"] as Dictionary)[t] = true
	MapTidy.tidy(map, done)
	_refresh(done, false)


## Tiles on the straight line from `a` to `b` (both included).
static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in range(1, n + 1):
		out.append(Vector2i((Vector2(a).lerp(Vector2(b), float(k) / n)).round()))
	if out.is_empty():
		out.append(b)
	return out


# --- edits, undo -----------------------------------------------------------------------------

## Runs an edit (`fn` returns the changed tiles, or an error text): undo,
## tidy-up, derived data, views and checks follow. `things`: village pieces
## or objects changed too. Returns whether anything changed.
func edit(fn: Callable, things: bool = false) -> bool:
	var before := map.to_bytes()
	var r = fn.call()
	if r is String:
		ui.status(r, true)
		return false
	var tiles: Array = r
	if tiles.is_empty() and not things:
		return false
	_push_undo(before)
	_after_edit(tiles, things)
	return true


func _after_edit(tiles: Array, things: bool) -> void:
	MapTidy.tidy(map, tiles)
	map.derive()
	MapJson.derive_object_slices(map)
	(map.meta["origin"] as Dictionary)["edited"] = true
	dirty = true
	_refresh(tiles, things)
	_checks_in = 0.3
	changed.emit()


func _refresh(tiles: Array, things: bool) -> void:
	iso.refresh_tiles(tiles)
	plan.refresh_tiles(tiles)
	if things:
		iso.refresh_things()
		plan.refresh_things()
	redraw_layers()
	_redraw_pointer()


func _push_undo(before: PackedByteArray) -> void:
	_undo.append(before)
	if _undo.size() > int(Config.EDITOR["undo_steps"]):
		_undo.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(map.to_bytes())
	_swap_in(MapData.from_bytes(_undo.pop_back()))


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(map.to_bytes())
	_swap_in(MapData.from_bytes(_redo.pop_back()))


## Another state of the same map (undo / redo): only what differs is drawn again.
func _swap_in(m: MapData) -> void:
	var diff: Array[Vector2i] = []
	for i in m.terrain.size():
		if m.terrain[i] != map.terrain[i] or m.zones[i] != map.zones[i] or m.slice_of[i] != map.slice_of[i]:
			diff.append(Vector2i(i % m.size, i / m.size))
	for f in ["props", "decor", "crossings", "beaches"]:
		var a: Dictionary = map.get(f)
		var b: Dictionary = m.get(f)
		for k in a:
			if not b.has(k) or str(a[k]) != str(b[k]):
				diff.append(k)
		for k in b:
			if not a.has(k):
				diff.append(k)
	map = m
	map.derive()
	MapJson.derive_object_slices(map)
	dirty = true
	if selected.get("type") == "object" and int(selected["index"]) >= map.objects.size():
		selected = {}
	if selected.get("type") == "village" and int(selected["index"]) >= map.villages.size():
		selected = {}
	iso.set_map(map, diff)
	plan.set_map(map)
	redraw_layers()
	_redraw_pointer()
	_run_checks()
	changed.emit()
	selection_changed.emit()


func _process(delta: float) -> void:
	if camera and absf(camera.zoom.x / _drawn_zoom - 1.0) > 0.12:
		_drawn_zoom = camera.zoom.x
		redraw_layers()
		_redraw_pointer()
	if _checks_in >= 0.0:
		_checks_in -= delta
		if _checks_in < 0.0:
			_run_checks()


func _run_checks() -> void:
	problems = MapChecks.run(map)
	redraw_layers()
	ui.show_problems()


# --- selection -------------------------------------------------------------------------------

func select(sel: Dictionary) -> void:
	selected = sel
	_redraw_pointer()
	selection_changed.emit()


## The File tab's click: the object, village or tile at `t`.
func _pick(t: Vector2i) -> void:
	if not map.in_bounds(t):
		select({})
		return
	var oi := object_at(t)
	if oi >= 0:
		select({"type": "object", "index": oi})
		return
	var vi := village_at(t)
	if vi >= 0:
		select({"type": "village", "index": vi})
		return
	select({"type": "tile", "tile": t})


## Waits for a click on the map to pick `what` for object / village `index`.
func start_pick(what: String, index: int) -> void:
	pick_mode = {"what": what, "index": index}
	ui.status({"guards": "Click the treasure this camp guards", "front": "Click the road tile in front of it", "center": "Click the village's new centre"}[what])


func _picked(t: Vector2i) -> void:
	var p := pick_mode
	pick_mode = {}
	var i := int(p["index"])
	match str(p["what"]):
		"guards":
			var g := object_at(t)
			if g < 0 or map.objects[g]["kind"] != "treasure":
				ui.status("That isn't a treasure", true)
			elif g != int(map.objects[i].get("guards", -1)) and int(map.objects[g].get("guard", -1)) >= 0:
				ui.status("Another camp guards that treasure", true)
			else:
				set_object_field("guards", g)
		"front":
			set_object_field("front", t)
		"center":
			set_village_center(i, t)


func object_at(t: Vector2i) -> int:
	for i in map.objects.size():
		if Building.footprint(map.objects[i]["tile"], int(map.objects[i].get("size", 1))).has(t):
			return i
	return -1


## The village whose pieces' box holds `t` (-1: none).
func village_at(t: Vector2i) -> int:
	for i in map.villages.size():
		if (map.villages[i]["rect"] as Rect2i).has_point(t):
			return i
	return -1


func _nearest_village(t: Vector2i) -> int:
	var best := -1
	var best_d := INF
	for i in map.villages.size():
		var d := Vector2(map.villages[i]["center"]).distance_to(Vector2(t))
		if d < best_d:
			best_d = d
			best = i
	return best


func delete_selected() -> void:
	match str(selected.get("type", "")):
		"object":
			var i := int(selected["index"])
			select({})
			edit(func() -> Variant: return EditorTools.delete_object(map, i), true)
		"village":
			var i := int(selected["index"])
			select({})
			edit(func() -> Variant: return EditorTools.delete_village(map, i), true)


## A field of the selected object changed in the inspector.
func set_object_field(key: String, value: Variant) -> void:
	if selected.get("type") != "object":
		return
	var i := int(selected["index"])
	edit(func() -> Variant:
		EditorTools.set_object_field(map, i, key, value)
		return Building.footprint(map.objects[i]["tile"], int(map.objects[i].get("size", 1))), true)
	selection_changed.emit()


## Village `i` and the one before / after it swap numbers.
func move_village_number(i: int, by: int) -> void:
	var j := i + by
	if j < 0 or j >= map.villages.size():
		return
	edit(func() -> Variant:
		EditorTools.swap_villages(map, i, j)
		return [] as Array[Vector2i], true)
	select({"type": "village", "index": j})


## Every piece of village `i` becomes `material`.
func set_village_material(i: int, material: String) -> void:
	edit(func() -> Variant:
		for p in map.village_layout:
			if int(p.get("owner", 0)) == i:
				p["material"] = material
		return [] as Array[Vector2i], true)
	select({"type": "village", "index": i})


func set_village_center(i: int, t: Vector2i) -> void:
	edit(func() -> Variant:
		map.villages[i]["center"] = t
		return [t] as Array[Vector2i], true)


## Every tile to its nearest village (the Slice tool's button).
func recompute_slices() -> void:
	edit(func() -> Variant: return EditorTools.recompute_slices(map))


## The meta fields (name, author, description) and the map type.
func set_properties(p_name: String, author: String, description: String, map_type: String) -> void:
	var before := map.to_bytes()
	map.meta["name"] = p_name
	map.meta["author"] = author
	map.meta["description"] = description
	map.map_type = map_type
	_push_undo(before)
	dirty = true
	changed.emit()


## Land a player could build on: open, passable, not road, water or near a
## crater, with no piece or object on it.
static func buildable(m: MapData, t: Vector2i, pieces: Dictionary, objects: Dictionary) -> bool:
	if not m.in_bounds(t) or pieces.has(t) or objects.has(t) or m.near_crater(t):
		return false
	var v := m.get_terrain(t)
	return v == MapData.Terrain.GRASS or v == MapData.Terrain.DESERT


# --- files and play --------------------------------------------------------------------------

## Writes the map to its file (a new one under your maps if it has none, or
## if it's a built-in map). Returns the path or "".
func save_file() -> String:
	var p := path if path != "" and not MapLibrary.is_builtin(path) else ""
	var written := MapLibrary.save(map, p)
	if written != "":
		path = written
		dirty = false
		changed.emit()
	return written


## Plays the map (single player, village `village`): the editor's state waits
## in Settings.editor_session; the game offers Back to editor.
func play(village: int) -> void:
	Settings.custom_map = map.copy()
	Settings.custom_village = village
	Settings.editor_session = session()
	Settings.editor_play = true
	get_tree().change_scene_to_file(Net.GAME_SCENE)


func leave() -> void:
	Settings.editor_session = {}
	get_tree().change_scene_to_file(Net.TITLE_SCENE)
