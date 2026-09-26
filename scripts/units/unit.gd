class_name Unit
extends Node2D
## Anything that walks: position lives in grid space, movement follows a list
## of grid waypoints, and a little bob/sway sells the walk cycle.

var game: Game
var grid_pos := Vector2.ZERO
var speed := 1.5  # tiles per second
var path := PackedVector2Array()
var path_index := 0
var moving := false
var sprite: Sprite2D

var _bob := 0.0


func _init_sprite(art_name: String) -> void:
	sprite = Art.sprite(art_name)
	sprite.show_behind_parent = true
	add_child(sprite)


func set_grid_pos(p: Vector2) -> void:
	grid_pos = p
	position = Iso.to_world(p)


func current_tile() -> Vector2i:
	return Vector2i(grid_pos.round())


func follow(p_path: PackedVector2Array) -> void:
	path = p_path
	path_index = 0
	# Skip the first waypoint if we're already standing on it.
	if path.size() > 0 and path[0].distance_to(grid_pos) < 0.05:
		path_index = 1


## Advance along the path; returns true when the end is reached.
func step_path(delta: float) -> bool:
	if path_index >= path.size():
		_set_moving(false)
		return true
	var budget := speed * delta
	while budget > 0.0 and path_index < path.size():
		var target := path[path_index]
		var d := target - grid_pos
		var dist := d.length()
		if dist <= budget:
			grid_pos = target
			path_index += 1
			budget -= dist
		else:
			grid_pos += d / dist * budget
			budget = 0.0
		if dist > 0.001:
			var screen_dx := Iso.to_world(d).x
			if absf(screen_dx) > 0.5:
				sprite.flip_h = screen_dx < 0.0
	position = Iso.to_world(grid_pos)
	_set_moving(true)
	_animate(delta)
	return path_index >= path.size()


func _set_moving(v: bool) -> void:
	if moving == v:
		return
	moving = v
	if not moving:
		sprite.position.y = 0.0
		sprite.rotation = 0.0


func _animate(delta: float) -> void:
	_bob += delta * 11.0
	sprite.position.y = -absf(sin(_bob)) * 2.5
	sprite.rotation = sin(_bob) * 0.06


func float_text(text: String, color: Color) -> void:
	game.world.float_text(text, position + Vector2(0, -50), color)
