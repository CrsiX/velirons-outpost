class_name WorldOverlay
extends Node2D
## Ground markings: selection footprint, tower range, the placement ghost, and
## the drag & drop preview for military units (possible targets, the one under
## the pointer, and an arrow from where the unit is to where it would go).

const OK_COLOR := Color(0.55, 1.0, 0.55)
const BAD_COLOR := Color(1.0, 0.4, 0.35)

var _footprint: Array[Vector2i] = []
var _footprint_color := Color.WHITE
var _range_center := Vector2.ZERO
var _range := 0.0
var _ghost: Sprite2D
var _targets: Array[Vector2i] = []
var _hover: Array[Vector2i] = []
var _arrow_from := Vector2.ZERO
var _arrow_to := Vector2.ZERO
var _arrow_ok := false
var _arrow := false


func _ready() -> void:
	_ghost = Sprite2D.new()
	_ghost.z_index = 10
	_ghost.visible = false
	add_child(_ghost)


func _process(_delta: float) -> void:
	if not _targets.is_empty() or _arrow:
		queue_redraw()  # keep the drag preview pulsing


func clear() -> void:
	_footprint.clear()
	_range = 0.0
	_ghost.visible = false
	clear_drag()


func clear_drag() -> void:
	_targets.clear()
	_hover.clear()
	_arrow = false
	queue_redraw()


## Drag preview: `targets` are the footprints of every post the unit could go
## to, `hover` the one under the pointer (empty if none). With `from` set, an
## arrow runs from the unit to the pointer (world positions).
func show_drag(targets: Array[Vector2i], hover: Array[Vector2i], from: Vector2, to: Vector2, with_arrow: bool) -> void:
	_targets = targets
	_hover = hover
	_arrow_from = from
	_arrow_to = to
	_arrow_ok = not hover.is_empty()
	_arrow = with_arrow
	queue_redraw()


func show_selection(tiles: Array[Vector2i], range_center: Vector2 = Vector2.ZERO, range_tiles: float = 0.0) -> void:
	_footprint = tiles
	_footprint_color = Color(1, 0.9, 0.6)
	_range_center = range_center
	_range = range_tiles
	_ghost.visible = false
	queue_redraw()


## Placement preview for `art_name` anchored on `anchor_world`.
func show_ghost(art_name: String, anchor_world: Vector2, tiles: Array[Vector2i], ok: bool, range_center: Vector2 = Vector2.ZERO, range_tiles: float = 0.0) -> void:
	_footprint = tiles
	_footprint_color = OK_COLOR if ok else BAD_COLOR
	_range_center = range_center
	_range = range_tiles
	Art.apply(_ghost, art_name)
	_ghost.position = anchor_world
	_ghost.modulate = Color(OK_COLOR, 0.7) if ok else Color(BAD_COLOR, 0.6)
	_ghost.visible = true
	queue_redraw()


func _draw() -> void:
	if _range > 0.0:
		var pts := Iso.ellipse(_range_center, _range, 64)
		draw_colored_polygon(pts, Color(1, 1, 1, 0.10))
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.75), 3.0, true)
	for t in _footprint:
		var d := Iso.diamond(t, 1, 0.94)
		draw_colored_polygon(d, Color(_footprint_color, 0.25))
		d.append(d[0])
		draw_polyline(d, Color(_footprint_color, 0.9), 2.5, true)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for t in _targets:
		var d := Iso.diamond(t, 1, 0.94)
		draw_colored_polygon(d, Color(1, 0.9, 0.6, 0.12 + 0.08 * pulse))
		d.append(d[0])
		draw_polyline(d, Color(1, 0.9, 0.6, 0.6), 2.0, true)
	for t in _hover:
		var d := Iso.diamond(t, 1, 0.94)
		draw_colored_polygon(d, Color(OK_COLOR, 0.35))
		d.append(d[0])
		draw_polyline(d, OK_COLOR, 3.5, true)
	if _arrow and _arrow_from.distance_to(_arrow_to) > 20.0:
		var col := OK_COLOR if _arrow_ok else Color(1, 1, 1, 0.7)
		var dir := (_arrow_to - _arrow_from).normalized()
		var end := _arrow_to - dir * 18.0
		var dash := 14.0
		var n := int(_arrow_from.distance_to(end) / dash)
		for i in range(0, n, 2):  # dashed shaft
			draw_line(_arrow_from + dir * dash * i, _arrow_from + dir * dash * mini(i + 1, n), col, 4.0, true)
		var side := Vector2(-dir.y, dir.x) * 11.0
		draw_colored_polygon(PackedVector2Array([_arrow_to - dir * 4.0, end - side, end + side]), col)

