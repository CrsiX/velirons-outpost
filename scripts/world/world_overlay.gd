class_name WorldOverlay
extends Node2D
## Ground markings: selection footprint, tower range, the placement ghost, and
## the drag & drop preview for military units (possible targets, the one under
## the pointer, and an arrow from where the unit is to where it would go, or two
## curved arrows back and forth when it would swap posts with another unit).

const OK_COLOR := Color(0.55, 1.0, 0.55)
const BAD_COLOR := Color(1.0, 0.4, 0.35)
const SHADE := Color(0.05, 0.08, 0.04, 0.55)

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
var _swap := false
## The arrows, drawn over the buildings (the rest of the overlay is on the ground).
var _arrows: Node2D


func _ready() -> void:
	_ghost = Sprite2D.new()
	_ghost.z_index = 10
	_ghost.visible = false
	add_child(_ghost)
	_arrows = Node2D.new()
	_arrows.z_index = 10
	_arrows.draw.connect(_draw_arrows)
	add_child(_arrows)


func _process(_delta: float) -> void:
	if not _targets.is_empty() or _arrow:
		queue_redraw()  # keep the drag preview pulsing
		_arrows.queue_redraw()


func clear() -> void:
	_footprint.clear()
	_range = 0.0
	_ghost.visible = false
	clear_drag()


func clear_drag() -> void:
	_targets.clear()
	_hover.clear()
	_arrow = false
	_swap = false
	queue_redraw()
	_arrows.queue_redraw()


## Drag preview: `targets` are the footprints of every post the unit could go
## to, `hover` the one under the pointer (empty if none). With `from` set, an
## arrow runs from the unit to the pointer (world positions); with `swap`,
## two curved arrows run between `from` and `to` (the other unit), one each way.
func show_drag(targets: Array[Vector2i], hover: Array[Vector2i], from: Vector2, to: Vector2, with_arrow: bool, swap: bool = false) -> void:
	_targets = targets
	_hover = hover
	_arrow_from = from
	_arrow_to = to
	_arrow_ok = not hover.is_empty()
	_arrow = with_arrow
	_swap = swap
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


func _draw_arrows() -> void:
	if _arrow and _swap:
		_curved_arrow(_arrow_from, _arrow_to, OK_COLOR)
		_curved_arrow(_arrow_to, _arrow_from, OK_COLOR)
	elif _arrow and _arrow_from.distance_to(_arrow_to) > 20.0:
		var col := OK_COLOR if _arrow_ok else Color(1, 1, 1, 0.7)
		var dir := (_arrow_to - _arrow_from).normalized()
		var end := _arrow_to - dir * 18.0
		var dash := 14.0
		var n := int(_arrow_from.distance_to(end) / dash)
		for i in range(0, n, 2):  # dashed shaft
			_arrows.draw_line(_arrow_from + dir * dash * i, _arrow_from + dir * dash * mini(i + 1, n), col, 4.0, true)
		var side := Vector2(-dir.y, dir.x) * 11.0
		_arrows.draw_colored_polygon(PackedVector2Array([_arrow_to - dir * 4.0, end - side, end + side]), col)


## An arrow from `a` to `b` bowed to its left (seen along it), so the arrows
## a -> b and b -> a bow apart like a recycling sign. Both ends stay a little
## short of the units' figures.
func _curved_arrow(a: Vector2, b: Vector2, col: Color) -> void:
	var d := b - a
	var length := d.length()
	if length < 20.0:
		return
	var ctrl := (a + b) / 2.0 + Vector2(d.y, -d.x) / length * clampf(length * 0.25, 18.0, 90.0)
	var t0 := clampf(14.0 / length, 0.0, 0.3)
	var t1 := 1.0 - t0
	var pts := PackedVector2Array()
	for i in 25:
		var t := lerpf(t0, t1, i / 24.0)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	var tip := pts[pts.size() - 1]
	var dir := (2.0 * (1.0 - t1) * (ctrl - a) + 2.0 * t1 * (b - ctrl)).normalized()
	var base := tip - dir * 18.0
	while pts.size() > 2 and pts[pts.size() - 1].distance_to(tip) < 14.0:
		pts.remove_at(pts.size() - 1)
	pts.append(base)  # the shaft ends under the head
	var side := Vector2(-dir.y, dir.x) * 11.0
	var arrow_head := PackedVector2Array([tip, base - side, base + side, tip])
	_arrows.draw_polyline(pts, SHADE, 7.0, true)  # a dark rim, readable over stone and grass
	_arrows.draw_polyline(arrow_head, SHADE, 3.0, true)
	_arrows.draw_polyline(pts, col, 4.0, true)
	_arrows.draw_colored_polygon(arrow_head.slice(0, 3), col)
