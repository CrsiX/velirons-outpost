class_name MapEdgeFade
extends Node2D
## The map's soft dark rim: the ground fades into the background over its
## edge tiles. Drawn over the ground but under the objects, so tall things on
## the edge (trees, peaks, lairs) stand in front of it. Like FogLayer: a tiny
## texture (one pixel per tile, plus a dark pixel of padding) through a
## grid->iso transform, linear filtering giving the soft edge.

var _texture: ImageTexture
var _size := 0


func setup(map: MapData) -> void:
	_size = map.size
	transform = Transform2D(Vector2(Iso.HALF_W, Iso.HALF_H), Vector2(-Iso.HALF_W, Iso.HALF_H), Vector2.ZERO)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var side := _size + 2
	var px := PackedByteArray()
	px.resize(side * side * 2)
	for y in side:
		for x in side:
			var rim := x == 0 or y == 0 or x == side - 1 or y == side - 1
			px[(y * side + x) * 2] = FogLayer.FOG_LUMA
			px[(y * side + x) * 2 + 1] = FogLayer.UNEXPLORED_ALPHA if rim else 0
	_texture = ImageTexture.create_from_image(Image.create_from_data(side, side, false, Image.FORMAT_LA8, px))
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	# Pixel (i, j) covers grid tile (i - 1, j - 1), as in FogLayer._draw.
	var side := float(_size + 2)
	draw_texture_rect(_texture, Rect2(-1.5, -1.5, side, side), false)
