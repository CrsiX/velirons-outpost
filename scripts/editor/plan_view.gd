class_name PlanView
extends Node2D
## The map editor's top-down 2D view: one square per tile (MapPlan colours,
## Config.EDITOR["plan_tile_px"] wide), from a one-pixel-per-tile texture drawn
## without smoothing. Edits change single pixels. Objects, spawns and the
## other marks are drawn by the overlay on top.

var map: MapData
var px := 16.0
var _img: Image
var _tex: ImageTexture


func setup(m: MapData, overlays: Array) -> void:
	map = m
	px = float(Config.EDITOR["plan_tile_px"])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_img = MapPlan.image(map)
	_tex = ImageTexture.create_from_image(_img)
	for c in get_children():
		remove_child(c)
		if not overlays.has(c):
			c.queue_free()
	for o in overlays:
		add_child(o)
	queue_redraw()


func refresh_tiles(tiles: Array) -> void:
	var pieces := MapTidy.piece_tiles(map)
	for t: Vector2i in tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := t + Vector2i(dx, dy)
				if map.in_bounds(p):
					_img.set_pixelv(p, MapPlan.tile_color(map, p, pieces))
	_tex.update(_img)


## Another map of the same size (undo / redo).
func set_map(m: MapData) -> void:
	map = m
	refresh_things()


## Village pieces changed: their tiles' colours again.
func refresh_things() -> void:
	_img = MapPlan.image(map)
	_tex.update(_img)


func _draw() -> void:
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(map.size, map.size) * px), false)
