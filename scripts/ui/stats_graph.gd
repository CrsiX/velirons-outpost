class_name StatsGraph
extends Control
## The Timeline's line graph (StatsScreen): time along the bottom, a faint
## line at each wave start with its number, one line per village in its
## colour. Hovering or tapping shows the values at that time.

const PAD_LEFT := 56.0
const PAD_RIGHT := 12.0
const PAD_TOP := 22.0
const PAD_BOTTOM := 26.0

## {"name", "times", "marks", "lines": [{"name", "color", "values"}]} (StatsScreen._timeline_data).
var data: Dictionary = {}
## The sample under the pointer (-1: none).
var hover := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


func set_data(d: Dictionary) -> void:
	data = d
	hover = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event is InputEventScreenDrag:
		hover_at(event.position.x)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover >= 0:
		hover = -1
		queue_redraw()


## Picks the sample nearest to x (local).
func hover_at(x: float) -> void:
	var times: PackedFloat32Array = data.get("times", PackedFloat32Array())
	if times.is_empty():
		return
	var t := _time_at(x)
	var best := 0
	for i in times.size():
		if absf(times[i] - t) < absf(times[best] - t):
			best = i
	if best != hover:
		hover = best
		queue_redraw()


func _span() -> float:
	var times: PackedFloat32Array = data.get("times", PackedFloat32Array())
	return maxf(times[times.size() - 1] if not times.is_empty() else 0.0, 1.0)


func _top_value() -> float:
	var top := 0.0
	for l in data.get("lines", []):
		for v in (l["values"] as PackedFloat32Array):
			top = maxf(top, v)
	return nice_ceiling(top)


## A round number >= v for the top of the axis (1, 2, 5 × 10^n).
static func nice_ceiling(v: float) -> float:
	if v <= 0.0:
		return 1.0
	var mag := pow(10.0, floorf(log(v) / log(10.0)))
	for f in [1.0, 2.0, 5.0, 10.0]:
		if f * mag >= v:
			return f * mag
	return 10.0 * mag


func _plot() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, maxf(size.x - PAD_LEFT - PAD_RIGHT, 1.0), maxf(size.y - PAD_TOP - PAD_BOTTOM, 1.0))


func _time_at(x: float) -> float:
	var r := _plot()
	return clampf((x - r.position.x) / r.size.x, 0.0, 1.0) * _span()


func _point(t: float, v: float, top: float) -> Vector2:
	var r := _plot()
	return Vector2(r.position.x + t / _span() * r.size.x, r.end.y - clampf(v / top, 0.0, 1.0) * r.size.y)


func _draw() -> void:
	var font := get_theme_default_font()
	var r := _plot()
	draw_rect(r, Color(0, 0, 0, 0.25))
	var times: PackedFloat32Array = data.get("times", PackedFloat32Array())
	if times.size() < 1:
		return
	var top := _top_value()
	# Grid: 0, half and top.
	for f in [0.0, 0.5, 1.0]:
		var y: float = r.end.y - f * r.size.y
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.12))
		draw_string(font, Vector2(2, y + 5), StatsScreen.format_number(top * f), HORIZONTAL_ALIGNMENT_RIGHT, PAD_LEFT - 8, 13, UiTheme.MUTED)
	# Waves.
	var marks: Array = data.get("marks", [])
	var step := maxi(1, ceili(marks.size() / maxf(r.size.x / 34.0, 1.0)))
	for i in marks.size():
		var x := _point(float(marks[i][0]), 0.0, top).x
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(UiTheme.GOLD, 0.22))
		if i % step == 0:
			draw_string(font, Vector2(x - 20, r.position.y - 5), str(int(marks[i][1])), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(UiTheme.GOLD, 0.8))
	# Time along the bottom.
	draw_string(font, Vector2(r.position.x, r.end.y + 18), "0:00", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.MUTED)
	draw_string(font, Vector2(r.end.x - 80, r.end.y + 18), StatsScreen.format_time(_span()), HORIZONTAL_ALIGNMENT_RIGHT, 80, 13, UiTheme.MUTED)
	# The lines.
	for l in data.get("lines", []):
		var vals: PackedFloat32Array = l["values"]
		var pts := PackedVector2Array()
		for i in mini(vals.size(), times.size()):
			pts.append(_point(times[i], vals[i], top))
		if pts.size() >= 2:
			draw_polyline(pts, l["color"], 2.5, true)
		elif pts.size() == 1:
			draw_circle(pts[0], 3.0, l["color"])
	# The values under the pointer.
	if hover >= 0 and hover < times.size():
		var x := _point(times[hover], 0.0, top).x
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(1, 1, 1, 0.5))
		var lines: Array = ["%s at %s" % [data.get("name", ""), StatsScreen.format_time(times[hover])]]
		var cols: Array = [UiTheme.TEXT]
		for l in data.get("lines", []):
			var vals: PackedFloat32Array = l["values"]
			if hover < vals.size():
				draw_circle(_point(times[hover], vals[hover], top), 4.0, l["color"])
				var prefix := (str(l["name"]) + ": ") if data["lines"].size() > 1 else ""
				lines.append(prefix + StatsScreen.format_number(vals[hover]))
				cols.append(l["color"])
		var w := 0.0
		for s: String in lines:
			w = maxf(w, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
		var box := Rect2(x + 8, r.position.y + 6, w + 16, lines.size() * 18 + 8)
		if box.end.x > r.end.x:
			box.position.x = x - 8 - box.size.x
		draw_rect(box, Color(0.08, 0.06, 0.05, 0.92))
		for i in lines.size():
			draw_string(font, box.position + Vector2(8, 19 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cols[i])
