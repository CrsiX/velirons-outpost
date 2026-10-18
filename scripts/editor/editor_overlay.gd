class_name EditorOverlay
extends Node2D
## The map editor's marks over a view (isometric or top-down; `plan`). Two of
## them per view: the layers (zones, slices, grid, passability, buildable
## land, a village's road steps, spawns, villages, objects and their rings,
## problems), drawn again only when the map or the layer switches change; and
## the pointer's marks (`dynamic`: the brush under the pointer, the
## selection, a road being drawn), drawn again as the pointer moves.

var editor: MapEditor
var plan := false
var dynamic := false


func _init(p_editor: MapEditor, p_plan: bool, p_dynamic: bool) -> void:
	editor = p_editor
	plan = p_plan
	dynamic = p_dynamic
	z_index = 2 if dynamic else 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # (the 2D view under it draws its tiles unsmoothed; text mustn't be)


## Screen-space (view) position of grid point `g` (a tile's centre for whole numbers).
func pt(g: Vector2) -> Vector2:
	return (g + Vector2(0.5, 0.5)) * _px() if plan else Iso.to_world(g)


## `screen_px` on the screen, in the view's own units (labels keep their size at any zoom).
func _sz(screen_px: float) -> float:
	return screen_px / maxf(editor.camera.zoom.x, 0.01) if editor.camera else screen_px


func _px() -> float:
	return float(Config.EDITOR["plan_tile_px"])


func tile_poly(t: Vector2i, grow: float = 1.0) -> PackedVector2Array:
	var h := 0.5 * grow
	var c := Vector2(t)
	return PackedVector2Array([pt(c + Vector2(-h, -h)), pt(c + Vector2(h, -h)), pt(c + Vector2(h, h)), pt(c + Vector2(-h, h))])


func _draw() -> void:
	var m := editor.map
	if m == null:
		return
	if dynamic:
		_draw_pointer(m)
		return
	var layers := editor.layers
	if layers.get("zones", false) and not plan:
		_draw_zones(m)
	if layers.get("passable", false):
		_draw_passable(m)
	if layers.get("buildable", false):
		_draw_buildable(m)
	if layers.get("grid", false):
		_draw_grid(m)
	if layers.get("slices", false):
		_draw_slices(m)
	if int(layers.get("flow", -1)) >= 0:
		_draw_flow(m, int(layers["flow"]))
	if plan or layers.get("objects", true):
		_draw_objects(m, layers.get("rings", false))
	if layers.get("villages", true):
		_draw_villages(m)
	if layers.get("spawns", true):
		_draw_spawns(m)
	if layers.get("water_spawns", true):
		_draw_water_spawns(m)
	if layers.get("problems", true):
		_draw_problems()


func _draw_zones(m: MapData) -> void:
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			draw_colored_polygon(tile_poly(t), Color(MapPlan.ZONE_COLORS[m.zone(t)], 0.45))


func _draw_passable(m: MapData) -> void:
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if not m.is_passable(t):
				draw_colored_polygon(tile_poly(t), Color(1.0, 0.2, 0.15, 0.35))
			elif m.get_terrain(t) == MapData.Terrain.SHALLOW:
				draw_colored_polygon(tile_poly(t), Color(0.3, 0.6, 1.0, 0.35))


func _draw_buildable(m: MapData) -> void:
	var pieces := MapTidy.piece_tiles(m)
	var objects := MapTidy.object_tiles(m)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if MapEditor.buildable(m, t, pieces, objects):
				draw_colored_polygon(tile_poly(t, 0.8), Color(0.4, 1.0, 0.4, 0.3))


func _draw_grid(m: MapData) -> void:
	var col := Color(0, 0, 0, 0.35)
	for k in m.size + 1:
		var a := float(k) - 0.5
		draw_line(pt(Vector2(-0.5, a)), pt(Vector2(m.size - 0.5, a)), col, 1.0)
		draw_line(pt(Vector2(a, -0.5)), pt(Vector2(a, m.size - 0.5)), col, 1.0)


## Every slice tinted in its colour (the lobby's village colours, as the
## Slice tool's buttons), white lines between them, their numbers (1-8).
func _draw_slices(m: MapData) -> void:
	var w := 3.0
	for y in m.size:
		for x in m.size:
			draw_colored_polygon(tile_poly(Vector2i(x, y)), Color(EditorUi.slice_color(m.slice_of[y * m.size + x]), 0.28))
	for y in m.size:
		for x in m.size:
			var s := m.slice_of[y * m.size + x]
			if x + 1 < m.size and m.slice_of[y * m.size + x + 1] != s:
				draw_line(pt(Vector2(x + 0.5, y - 0.5)), pt(Vector2(x + 0.5, y + 0.5)), Color.WHITE, w)
			if y + 1 < m.size and m.slice_of[(y + 1) * m.size + x] != s:
				draw_line(pt(Vector2(x - 0.5, y + 0.5)), pt(Vector2(x + 0.5, y + 0.5)), Color.WHITE, w)
	# (a slice with a village is named in the village's label, see _draw_villages)
	for i in m.slices.size():
		if m.villages.any(func(v: Dictionary) -> bool: return int(v.get("slice", -1)) == i) and editor.layers.get("villages", true):
			continue
		var c: Vector2 = m.slices[i]["center"]
		_label(pt(c), "Slice %d" % (i + 1), EditorUi.slice_color(i), 17)


func _draw_flow(m: MapData, vi: int) -> void:
	if vi >= m.villages.size() or (m.villages[vi]["gates"] as Array).is_empty():
		return
	var field := GenChecks.road_field(m, m.villages[vi]["gates"])
	for y in m.size:
		for x in m.size:
			var d := field[y * m.size + x]
			if d < 1 << 29:
				_label(pt(Vector2(x, y)), str(d), Color(1, 1, 0.6), 11)


func _draw_objects(m: MapData, rings: bool) -> void:
	for i in m.objects.size():
		var o := m.objects[i]
		var t: Vector2i = o["tile"]
		var sz := int(o.get("size", 1))
		var col: Color = MapPlan.OBJECT_COLORS.get(o["kind"], Color.MAGENTA)
		var centre := Vector2(t) + (Vector2(0.5, 0.5) if sz % 2 == 0 else Vector2.ZERO)
		if plan:
			for p in Building.footprint(t, sz):
				draw_colored_polygon(tile_poly(p, 0.9), col)
			var art := str(o.get("art", ""))
			if ArtManifest.SPRITES.has(art):
				var r := _px() * 1.6
				draw_texture_rect(Art.tex(art), Rect2(pt(centre) - Vector2(r, r) / 2.0, Vector2(r, r)), false)
		if rings:
			if o["kind"] == "camp":
				_ring(centre, Config.CAMP_AGGRO, col)
				var g := int(o.get("guards", -1))
				if g >= 0 and g < m.objects.size():
					draw_line(pt(centre), pt(Vector2(m.objects[g]["tile"])), col, 2.0)
			if o.has("front"):
				draw_line(pt(centre), pt(Vector2(o["front"])), col, 3.0)
				draw_colored_polygon(tile_poly(o["front"], 0.5), col)


func _ring(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 49:
		pts.append(pt(c + Vector2.from_angle(TAU * k / 48.0) * r))
	draw_polyline(pts, col, 2.0)


func _draw_villages(m: MapData) -> void:
	for i in m.villages.size():
		var v: Dictionary = m.villages[i]
		var col: Color = Config.VILLAGE_COLORS[i % Config.VILLAGE_COLORS.size()]
		var r: Rect2i = v["rect"]
		if r.size != Vector2i.ZERO:
			var a := Vector2(r.position) - Vector2(0.5, 0.5)
			var b := Vector2(r.end) - Vector2(0.5, 0.5)
			draw_polyline(PackedVector2Array([pt(a), pt(Vector2(b.x, a.y)), pt(b), pt(Vector2(a.x, b.y)), pt(a)]), col, 3.0)
		var c := pt(Vector2(v["center"]))
		draw_circle(c, _sz(7), Color(0, 0, 0, 0.7))
		draw_circle(c, _sz(7), col, false, _sz(2))
		var text := "Village %d" % (i + 1)
		if editor.layers.get("slices", false):
			text += " · slice %d" % (int(v.get("slice", 0)) + 1)
		_label(c - Vector2(0, _sz(22)), text, col, 18)


func _draw_spawns(m: MapData) -> void:
	for i in m.villages.size():
		var col: Color = Config.VILLAGE_COLORS[i % Config.VILLAGE_COLORS.size()]
		for s: Vector2i in m.villages[i]["home_spawns"]:
			draw_colored_polygon(tile_poly(s, 0.9), Color(MapPlan.SPAWN, 0.8))
			draw_polyline(_closed(tile_poly(s, 0.9)), col, 3.0)
			_label(pt(Vector2(s)), str(i + 1), Color.WHITE, 13)


func _draw_water_spawns(m: MapData) -> void:
	for s: Vector2i in m.water_spawns:
		draw_colored_polygon(tile_poly(s, 0.9), Color(0.25, 0.55, 0.95, 0.8))
		draw_polyline(_closed(tile_poly(s, 0.9)), Color.WHITE, 2.0)
		_label(pt(Vector2(s)), "~", Color.WHITE, 15)


func _draw_problems() -> void:
	for p in editor.problems:
		var t: Vector2i = p["tile"]
		if t.x < 0:
			continue
		var col := UiTheme.BAD if p["level"] == "error" else Color("f2c230")
		var c := pt(Vector2(t))
		var r := _sz(10)
		draw_line(c - Vector2(r, r), c + Vector2(r, r), col, _sz(3))
		draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, _sz(3))


func _draw_pointer(m: MapData) -> void:
	# The selection.
	var sel := editor.selected
	match str(sel.get("type", "")):
		"object":
			var i := int(sel["index"])
			if i < m.objects.size():
				for t in Building.footprint(m.objects[i]["tile"], int(m.objects[i].get("size", 1))):
					draw_polyline(_closed(tile_poly(t, 1.15)), UiTheme.GOLD, 3.0)
		"village":
			var i := int(sel["index"])
			if i < m.villages.size():
				for p in m.village_pieces(i):
					draw_polyline(_closed(tile_poly(p["tile"])), UiTheme.GOLD, 2.0)
		"tile":
			draw_polyline(_closed(tile_poly(sel["tile"])), UiTheme.GOLD, 3.0)
	# A road being drawn (Path mode).
	for t in editor.path_preview:
		draw_colored_polygon(tile_poly(t, 0.7), Color(1, 0.9, 0.5, 0.6))
	# The brush under the pointer.
	for t in editor.brush_tiles():
		if m.in_bounds(t):
			draw_polyline(_closed(tile_poly(t)), Color(1, 1, 1, 0.8), 2.0)


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out


## Text of `screen_px` on the screen, centred on `at`. Drawn at its screen
## size under an inverse-zoom transform, so the glyphs are made at full
## resolution (text made small and blown up by the camera would be blocky).
func _label(at: Vector2, text: String, col: Color, screen_px: int) -> void:
	var font := ThemeDB.fallback_font
	var z := maxf(editor.camera.zoom.x, 0.01) if editor.camera else 1.0
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, screen_px).x
	var p := Vector2(-w / 2.0, screen_px * 0.35)
	draw_set_transform(at, 0.0, Vector2.ONE / z)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, screen_px, maxi(3, screen_px / 4), Color(0, 0, 0, 0.85))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, screen_px, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
