class_name Iso
extends RefCounted
## 2:1 isometric projection. Grid space: tile (x, y) has its centre at integer
## coordinates; +x runs down-right on screen, +y runs down-left.

const HALF_W := 64.0
const HALF_H := 32.0


static func to_world(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * HALF_W, (g.x + g.y) * HALF_H)


static func tile_to_world(t: Vector2i) -> Vector2:
	return to_world(Vector2(t))


static func to_grid(w: Vector2) -> Vector2:
	var a := w.x / HALF_W
	var b := w.y / HALF_H
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


static func to_tile(w: Vector2) -> Vector2i:
	return Vector2i(to_grid(w).round())


## Diamond outline of a tile (or a size x size block centred on `center`).
static func diamond(center: Vector2i, size: int = 1, grow: float = 1.0) -> PackedVector2Array:
	var c := tile_to_world(center)
	var hw := HALF_W * size * grow
	var hh := HALF_H * size * grow
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])


## A circle of `radius` tiles in grid space, projected to an ellipse.
static func ellipse(center: Vector2, radius: float, segments: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(to_world(center + Vector2(cos(a), sin(a)) * radius))
	return pts
