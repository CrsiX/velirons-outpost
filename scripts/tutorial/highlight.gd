class_name TutorialHighlight
extends Control
## The tutorial's pointer (docs/tutorial-design.md §3.2): a pulsing gold
## outline around a HUD control and / or a pulsing diamond on map tiles, with
## a bobbing arrow at it. A tile off screen gets the arrow at the screen edge,
## pointing its way. Draws over the HUD, takes no input.

const GOLD := Color("ffd76a")
const ARROW := 22.0  # px, arrow head length

var game: Game
## The HUD control to outline (null: none) and the rect to clip it to (the
## dock's scroll area, for entries in the dock; empty: no clipping).
var target: Control = null
var clip := Rect2()
## Map tiles to mark (a building's footprint), empty: none.
var tiles: Array[Vector2i] = []
var _t := 0.0


func _init(p_game: Game) -> void:
	game = p_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func point_at(control: Control, p_clip: Rect2, p_tiles: Array[Vector2i]) -> void:
	target = control
	clip = p_clip
	tiles = p_tiles


func clear() -> void:
	target = null
	tiles = []


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _pulse() -> float:
	return 0.5 + 0.5 * sin(_t * 5.0)


func _draw() -> void:
	var col := GOLD
	col.a = 0.55 + 0.45 * _pulse()
	var bob := 6.0 * sin(_t * 5.0)
	if is_instance_valid(target) and target.is_visible_in_tree():
		var r := target.get_global_rect().grow(4.0 + 2.0 * _pulse())
		if clip.has_area():
			r = r.intersection(clip.grow(4.0))
		if r.has_area():
			draw_rect(r, col, false, 4.0)
			# The arrow from the side with the most room (left of the sidebar,
			# above the bottom sheet, else below).
			var vp := get_viewport_rect().size
			if r.position.x > vp.x * 0.5 and r.position.y > 80.0 and r.size.y < vp.y * 0.5:
				_arrow(Vector2(r.position.x - 8.0 - bob, r.get_center().y), Vector2.RIGHT, col)
			elif r.position.y > vp.y * 0.5:
				_arrow(Vector2(r.get_center().x, r.position.y - 8.0 - bob), Vector2.DOWN, col)
			else:
				_arrow(Vector2(r.get_center().x, r.end.y + 8.0 + bob), Vector2.UP, col)
	if not tiles.is_empty():
		_draw_tiles(col, bob)


func _draw_tiles(col: Color, bob: float) -> void:
	var lo := tiles[0]
	var hi := tiles[0]
	for t in tiles:
		lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	var xf := get_viewport().get_canvas_transform()
	var g := 0.5 + 0.08 * _pulse()
	var c := (Vector2(lo) + Vector2(hi)) / 2.0
	var half := (Vector2(hi - lo) + Vector2.ONE) / 2.0 * (g / 0.5)
	var pts := PackedVector2Array()
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(xf * Iso.to_world(c + d * half))
	var fill := col
	fill.a = 0.18 + 0.12 * _pulse()
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, col, 4.0, true)
	var top := pts[0]  # (the north corner)
	var vp := get_viewport_rect()
	var margin := vp.grow(-40.0)
	if margin.has_point(top):
		_arrow(top - Vector2(0, 10.0 + bob), Vector2.DOWN, col)
	else:
		# Off screen: an arrow at the edge, pointing the way.
		var mid := xf * Iso.to_world(c)
		var centre := vp.get_center()
		var dir := (mid - centre).normalized()
		var at := centre + dir * _edge_distance(margin, centre, dir)
		_arrow(at, dir, col)


## How far from `from` along `dir` the edge of `r` is.
func _edge_distance(r: Rect2, from: Vector2, dir: Vector2) -> float:
	var d := INF
	if dir.x > 0.001:
		d = minf(d, (r.end.x - from.x) / dir.x)
	elif dir.x < -0.001:
		d = minf(d, (r.position.x - from.x) / dir.x)
	if dir.y > 0.001:
		d = minf(d, (r.end.y - from.y) / dir.y)
	elif dir.y < -0.001:
		d = minf(d, (r.position.y - from.y) / dir.y)
	return d if d < INF else 0.0


## An arrow whose tip is at `tip`, pointing along `dir`.
func _arrow(tip: Vector2, dir: Vector2, col: Color) -> void:
	var back := tip - dir * ARROW
	var side := Vector2(-dir.y, dir.x) * ARROW * 0.6
	var head := PackedVector2Array([tip, back + side, back - side])
	draw_colored_polygon(head, col)
	draw_polyline(PackedVector2Array([tip, back + side, back - side, tip]), UiTheme.INK, 2.0, true)
	draw_line(back, back - dir * ARROW * 0.9, col, 6.0, true)
