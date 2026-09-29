class_name LightStone
extends Building
## A rune-carved pillar that lights up its surroundings. Works entirely on its
## own: it gives vision (surveillance) and nobody can be stationed in it.

var _glow: Sprite2D
var _halo: Sprite2D
var _site_sprite: Sprite2D
var _t := 0.0


func _build_visuals() -> void:
	# The halo is flat light on the ground, so it goes on the decal layer.
	_halo = Art.sprite("light_halo")
	_halo.position = position
	game.world.decals.add_child(_halo)
	sprite = Art.sprite("light_stone")
	sprite.show_behind_parent = true
	add_child(sprite)
	_glow = Art.sprite("light_stone_glow")
	_glow.show_behind_parent = true
	add_child(_glow)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	add_child(_site_sprite)
	_t = randf() * TAU


func _exit_tree() -> void:
	if is_instance_valid(_halo):
		_halo.queue_free()


func refresh() -> void:
	sprite.visible = complete
	_glow.visible = working()
	_halo.visible = working()
	_site_sprite.visible = not complete
	queue_redraw()


func _process(delta: float) -> void:
	if not working():
		return
	_t += delta * 1.6
	var pulse := 0.65 + 0.35 * sin(_t)
	_glow.modulate.a = pulse
	_halo.modulate.a = 0.6 + 0.4 * pulse


func is_solid() -> bool:
	return complete


func is_solid_when_complete() -> bool:
	return true


func sight_radius() -> float:
	if tearing_down:
		return super.sight_radius()
	return Config.LIGHTSTONE_SIGHT if complete else 0.0


func info() -> Dictionary:
	var d := super.info()
	if working():
		var lines: Array[String] = d["lines"]
		lines.append("Lights up the land within %.1f tiles." % Config.LIGHTSTONE_SIGHT)
		lines.append("Works on its own; no one can be stationed here.")
	return d


func pick_rect() -> Rect2:
	return Rect2(-32, -104, 64, 120)
