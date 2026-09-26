class_name WorldOverlay
extends Node2D
## Ground markings: selection footprint, tower range, and the placement ghost.

const OK_COLOR := Color(0.55, 1.0, 0.55)
const BAD_COLOR := Color(1.0, 0.4, 0.35)

var _footprint: Array[Vector2i] = []
var _footprint_color := Color.WHITE
var _range_center := Vector2.ZERO
var _range := 0.0
var _ghost: Sprite2D


func _ready() -> void:
	_ghost = Sprite2D.new()
	_ghost.z_index = 10
	_ghost.visible = false
	add_child(_ghost)


func clear() -> void:
	_footprint.clear()
	_range = 0.0
	_ghost.visible = false
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
