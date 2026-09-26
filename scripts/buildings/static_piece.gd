class_name StaticPiece
extends Building
## Village walls and gates: pure scenery with an info blurb.

var flip := false


func _build_visuals() -> void:
	sprite = Art.sprite(kind)
	sprite.flip_h = flip
	sprite.show_behind_parent = true
	add_child(sprite)


func is_solid() -> bool:
	return kind == "wall"


func is_solid_when_complete() -> bool:
	return is_solid()


func display_name() -> String:
	return "Village Gate" if kind == "gate" else "Village Wall"


func info() -> Dictionary:
	var lines: Array[String] = []
	if kind == "gate":
		lines.append("Goblins that reach a gate tear down huts")
		lines.append("and kill villagers.")
	else:
		lines.append("Stone wall around the village of Veliron.")
	return {"title": display_name(), "lines": lines, "actions": []}


func pick_rect() -> Rect2:
	return Rect2(-50, -60, 100, 76)
