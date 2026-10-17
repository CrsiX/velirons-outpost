class_name MapPreview
extends Control
## A small top-down picture of a map (MapPlan.preview) with every village's
## number on it, and optionally a label per village ("1: Rivermoor"): the map
## picker, the co-op lobby and the save list. A saved game's map is shown
## through its fog (only explored land), so a save can't give the map away.

var map: MapData
## Village index -> text drawn by it (e.g. the player who has it).
var labels: Dictionary = {}
var _tex: ImageTexture


func _init() -> void:
	custom_minimum_size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## `explored`: only these tiles are shown (MapPlan.preview); empty: all of it.
func show_map(m: MapData, explored: PackedByteArray = PackedByteArray()) -> void:
	map = m
	_tex = ImageTexture.create_from_image(MapPlan.preview(m, 1, explored)) if m else null
	queue_redraw()


func _draw() -> void:
	if map == null or _tex == null:
		return
	var side := minf(size.x, size.y)
	var origin := ((size - Vector2(side, side)) / 2.0).floor()
	draw_texture_rect(_tex, Rect2(origin, Vector2(side, side)), false)
	draw_rect(Rect2(origin, Vector2(side, side)), UiTheme.GOLD, false, 2.0)
	var px := side / map.size
	var font := ThemeDB.fallback_font
	for i in map.villages.size():
		var c := origin + (Vector2(map.villages[i]["center"]) + Vector2(0.5, 0.5)) * px
		var col: Color = Config.VILLAGE_COLORS[i % Config.VILLAGE_COLORS.size()]
		draw_circle(c, 11.0, Color(0, 0, 0, 0.75))
		draw_circle(c, 11.0, col, false, 2.0)
		draw_string(font, c + Vector2(-5, 6), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 10, 16, Color.WHITE)
		if labels.has(i):
			draw_string_outline(font, c + Vector2(14, 6), str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
			draw_string(font, c + Vector2(14, 6), str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
