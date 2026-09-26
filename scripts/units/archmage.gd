class_name Archmage
extends Civilian
## Decoration for now: strolls around the village walls, glowing faintly.
## A later iteration will let the archmage end the game.

var _wait := 0.0


func _tick(delta: float) -> void:
	if at_home:
		_wander()
		return
	if step_path(delta):
		_wait -= delta
		if _wait <= 0.0:
			_wander()
	sprite.modulate = Color(1, 1, 1).lerp(Color(0.85, 0.75, 1.2), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 400.0))


## Picks a random walkable tile on the ring just outside the walls.
func _wander() -> void:
	_wait = randf_range(2.0, 5.0)
	var r := game.map.village_rect.grow(1)
	for _i in 12:
		var t := Vector2i(randi_range(r.position.x, r.end.x - 1), randi_range(r.position.y, r.end.y - 1))
		if not game.map.in_village(t) and game.world.pathing.is_walkable(t):
			head_out(t)
			return


func status() -> String:
	return "pondering the siege (coming soon)"
