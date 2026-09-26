class_name FogLayer
extends Node2D
## Fog of war. Sits below the object layer; objects on unexplored tiles are
## hidden by World instead, so tall sprites never get cut by the fog.

signal revealed(tiles: Array[Vector2i])

const FOG := Color(0.035, 0.045, 0.04)

var map: MapData
var _dirty := true
var _redraw_timer := 0.0


func setup(p_map: MapData) -> void:
	map = p_map
	_dirty = true


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
		_dirty = true
		revealed.emit(fresh)


func explored_count() -> int:
	return map.explored.count(1)


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _dirty and _redraw_timer <= 0.0:
		_dirty = false
		_redraw_timer = 0.2
		queue_redraw()


func _draw() -> void:
	if map == null:
		return
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if map.explored[map.index(t)] == 1:
				continue
			# Soft edge: fog next to explored land is thinner.
			var near := 0
			for n in MapData.neighbors4(t):
				if map.is_explored(n):
					near += 1
			var alpha := 1.0 if near == 0 else 0.93 - 0.04 * near
			draw_colored_polygon(Iso.diamond(t, 1, 1.04), Color(FOG, alpha))
	# Frame the map so the world visibly ends.
	var s := map.size - 1
	var outline := PackedVector2Array([
		Iso.to_world(Vector2(-0.5, -0.5)), Iso.to_world(Vector2(s + 0.5, -0.5)),
		Iso.to_world(Vector2(s + 0.5, s + 0.5)), Iso.to_world(Vector2(-0.5, s + 0.5)), Iso.to_world(Vector2(-0.5, -0.5)),
	])
	draw_polyline(outline, Color(0, 0, 0, 0.8), 6.0)
