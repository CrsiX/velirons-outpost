class_name FogLayer
extends Node2D
## Fog of war with three states per tile:
##   unexplored          -> black (terrain unknown)
##   explored            -> darkened; terrain known, enemies hidden
##   under surveillance  -> clear; enemies visible
## Explorers explore; units outside the village and manned towers ("observers")
## put explored tiles under surveillance.
##
## Drawn as one tiny texture (one pixel per tile) through a grid->iso transform,
## so linear filtering gives soft edges for free and redraws stay cheap.

signal revealed(tiles: Array[Vector2i])

const FOG_LUMA := 8  # 0..255, the fog's grey level
const UNEXPLORED_ALPHA := 255
const UNWATCHED_ALPHA := 120
const WATCH_INTERVAL := 0.2

var map: MapData
## No fog at all: every tile is explored and under surveillance (Config.DISABLE_FOG).
var disabled := false
var _image: Image
var _texture: ImageTexture
var _pixels := PackedByteArray()
var _watch_timer := 0.0
var _explored_dirty := true


func setup(p_map: MapData) -> void:
	map = p_map
	# Grid space -> iso world: x axis goes down-right, y axis down-left.
	transform = Transform2D(Vector2(Iso.HALF_W, Iso.HALF_H), Vector2(-Iso.HALF_W, Iso.HALF_H), Vector2.ZERO)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var side := map.size + 2  # one dark pixel of padding around the map
	_pixels.resize(side * side * 2)
	_image = Image.create_from_data(side, side, false, Image.FORMAT_LA8, _pixels)
	_texture = ImageTexture.create_from_image(_image)
	_rebuild()


## Marks tiles within `radius` (grid units) of `center` as explored.
func reveal(center: Vector2, radius: float) -> void:
	var fresh: Array[Vector2i] = []
	var r := int(ceil(radius))
	var c := Vector2i(center.round())
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := c + Vector2i(dx, dy)
			if not map.in_bounds(t) or map.explored[map.index(t)] == 1:
				continue
			if Vector2(t).distance_to(center) <= radius:
				map.explored[map.index(t)] = 1
				fresh.append(t)
	if not fresh.is_empty():
		_explored_dirty = true
		revealed.emit(fresh)


## Marks the whole map explored (Config.REVEAL_MAP). Surveillance still applies.
func reveal_all() -> void:
	var fresh: Array[Vector2i] = []
	for i in map.explored.size():
		if map.explored[i] == 0:
			map.explored[i] = 1
			fresh.append(Vector2i(i % map.size, i / map.size))
	if not fresh.is_empty():
		_explored_dirty = true
		revealed.emit(fresh)


func set_disabled(v: bool) -> void:
	disabled = v
	if disabled:
		reveal_all()
	update_surveillance()


func explored_count() -> int:
	return map.explored.count(1)


func watched_count() -> int:
	return map.watched.count(1)


func is_watched(t: Vector2i) -> bool:
	return map.is_explored(t) and map.is_watched(t)


func _process(delta: float) -> void:
	_watch_timer -= delta
	if _watch_timer <= 0.0 or _explored_dirty:
		_watch_timer = WATCH_INTERVAL
		update_surveillance()


## Recomputes which tiles are watched by the current observers.
func update_surveillance() -> void:
	if disabled:
		map.watched.fill(1)
		_rebuild()
		return
	map.watched.fill(0)
	for node in get_tree().get_nodes_in_group("observers"):
		var radius: float = node.sight_radius()
		if radius <= 0.0:
			continue
		var c: Vector2 = node.sight_center()
		var r := int(ceil(radius))
		var ct := Vector2i(c.round())
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := ct + Vector2i(dx, dy)
				if map.in_bounds(t) and Vector2(t).distance_to(c) <= radius:
					map.watched[map.index(t)] = 1
	_rebuild()


func _rebuild() -> void:
	_explored_dirty = false
	var side := map.size + 2
	var px := PackedByteArray()
	px.resize(side * side * 2)
	for i in side * side:
		px[i * 2] = FOG_LUMA
		px[i * 2 + 1] = UNEXPLORED_ALPHA
	for y in map.size:
		for x in map.size:
			var i := y * map.size + x
			var alpha := UNEXPLORED_ALPHA
			if map.explored[i] == 1:
				alpha = 0 if map.watched[i] == 1 else UNWATCHED_ALPHA
			px[((y + 1) * side + x + 1) * 2 + 1] = alpha
	if px == _pixels:
		return
	_pixels = px
	_image.set_data(side, side, false, Image.FORMAT_LA8, _pixels)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	# Pixel (i, j) covers grid tile (i - 1, j - 1), i.e. [i - 1.5, i - 0.5].
	var side := float(map.size + 2)
	draw_texture_rect(_texture, Rect2(-1.5, -1.5, side, side), false)
