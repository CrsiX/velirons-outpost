class_name Church
extends Building
## The harbour village's church (3x3; docs/scenarios-design.md §9a), only in
## the campaign: scenario 9 prebuilds it inside the walls. The priests keep
## the First King's Hand here once it is home (holds_relic): a glow over the
## door shows it. It can't be torn down.

## The relic is kept here.
var holds_relic := false
var _site_spr: Sprite2D
var _glow: Sprite2D


func _build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	add_child(sprite)
	_site_spr = Art.sprite("site")
	_site_spr.show_behind_parent = true
	_site_spr.scale *= 1.8
	add_child(_site_spr)
	_glow = Art.sprite("relic_sword")
	_glow.position = Vector2(0, -20)
	_glow.visible = false
	add_child(_glow)


func refresh() -> void:
	Art.apply(sprite, "church")
	sprite.visible = complete
	_site_spr.visible = not complete
	_glow.visible = complete and holds_relic
	queue_redraw()


func can_tear_down() -> bool:
	return false


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if complete:
		lines.append("The priests keep the First King's Hand here." if holds_relic else "The priests' church.")
	return d


func pick_rect() -> Rect2:
	return Rect2(-140, -230, 280, 280)


func _bar_y() -> float:
	return -226.0
