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
## Network id (Game.register); co-op clients get their units by it.
var nid := 0

var _bob := 0.0
var _net_to := Vector2.ZERO
var _net_has := false


func _init_sprite(art_name: String) -> void:
	sprite = Art.sprite(art_name)
	sprite.show_behind_parent = true
	add_child(sprite)


## Turns the sprite to look towards `grid_target`.
func face(grid_target: Vector2) -> void:
	sprite.flip_h = Iso.to_world(grid_target - grid_pos).x < 0.0


## A small HP bar over the unit (call from _draw): `w` wide and `h` high, its
## top at `y`, filled to `share`.
func _draw_hp_bar(w: float, y: float, h: float, share: float, back: Color, fill: Color) -> void:
	var r := Rect2(-w / 2.0, y, w, h)
	draw_rect(r.grow(1.5), Color("15110d"))
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(w * clampf(share, 0.0, 1.0), r.size.y)), fill)


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
	var budget := speed * delta * _walk_factor()
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


## Shallow water and fords x0.5, swamp off the road x0.7 (MapData.walk_factor).
func _walk_factor() -> float:
	if game == null or game.world == null or game.world.map == null:
		return 1.0
	return game.world.map.walk_factor(current_tile())


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


## Co-op client: the host says the unit is at `p` now; glide there.
func net_move(p: Vector2, snap: bool = false) -> void:
	_net_to = p
	_net_has = true
	if snap or p.distance_to(grid_pos) > 3.0:
		set_grid_pos(p)


## Co-op client: one frame of gliding towards the last position the host sent.
func net_follow(delta: float) -> void:
	if not _net_has:
		return
	var d := _net_to - grid_pos
	var dist := d.length()
	if dist < 0.01:
		_set_moving(false)
		return
	grid_pos = grid_pos.move_toward(_net_to, maxf(speed, dist * 8.0) * delta)
	position = Iso.to_world(grid_pos)
	_set_moving(true)
	_animate(delta)


func float_text(text: String, color: Color) -> void:
	game.world.float_text(text, position + Vector2(0, -50), color)
