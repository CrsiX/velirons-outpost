class_name TutorialHighlight
extends Control
## The tutorial's pointer (docs/tutorial-design.md §3.2): a pulsing gold
## outline around a HUD control and / or a pulsing diamond on map tiles or
## an outline around units' figures on their posts, with a bobbing arrow at it. A tile off the map's part of the screen (off screen,
## or under the top bar or the open dock: Hud.map_rect) gets only an arrow at
## that area's edge, pointing its way. Draws over the HUD, takes no input.

const GOLD := Color("ffd76a")
const ARROW := 22.0  # px, arrow head length
const EDGE := 40.0  # px: tiles this close to the map area's edge count as out of view

var game: Game
## The HUD control to outline (null: none) and the rect to clip it to (the
## dock's scroll area, for entries in the dock; empty: no clipping).
var target: Control = null
var clip := Rect2()
## Map tiles to mark (a building's footprint), empty: none.
var tiles: Array[Vector2i] = []
## Stationed units whose figures (on a tower, a bench...) to outline, empty: none.
var units: Array[MilitaryUnit] = []
var _t := 0.0
## The tile marks draw here: the map's part of the screen, clipped, so they
## never spill over the top bar or the dock.
var _map_layer := Control.new()


func _init(p_game: Game) -> void:
	game = p_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_layer.clip_contents = true
	_map_layer.draw.connect(_draw_tiles)
	add_child(_map_layer)


func point_at(control: Control, p_clip: Rect2, p_tiles: Array[Vector2i], p_units: Array[MilitaryUnit] = []) -> void:
	target = control
	clip = p_clip
	tiles = p_tiles
	units = p_units


func clear() -> void:
	target = null
	tiles = []
	units = []


## The outlined units' figures on screen (global; the ones not shown are left out).
func unit_screen_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for u in units:
		if not is_instance_valid(u.post):
			continue
		var r := u.post.unit_rect(u)
		if not r.has_area():
			continue
		var xf := u.post.get_global_transform_with_canvas()
		var a := xf * r.position
		var b := xf * r.end
		out.append(Rect2(a.min(b), (b - a).abs()))
	return out


func _process(delta: float) -> void:
	_t += delta
	var area := game.hud.map_rect()
	_map_layer.position = area.position - get_global_rect().position
	_map_layer.size = area.size
	queue_redraw()
	_map_layer.queue_redraw()


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


## Where the marked tiles' middle is on screen.
func tiles_screen_pos() -> Vector2:
	var lo := tiles[0]
	var hi := tiles[0]
	for t in tiles:
		lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	return get_viewport().get_canvas_transform() * Iso.to_world((Vector2(lo) + Vector2(hi)) / 2.0)


## True when the marked tiles show on the map (not off screen, not under the
## top bar or the open dock): they get the diamond; else only the edge arrow.
func tiles_in_view() -> bool:
	return not tiles.is_empty() and game.hud.map_rect().grow(-EDGE).has_point(tiles_screen_pos())


## On _map_layer (its own coordinates: the map area's top left is 0, 0).
func _draw_tiles() -> void:
	_draw_units()
	if tiles.is_empty():
		return
	var col := GOLD
	col.a = 0.55 + 0.45 * _pulse()
	var bob := 6.0 * sin(_t * 5.0)
	var lo := tiles[0]
	var hi := tiles[0]
	for t in tiles:
		lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	var area := Rect2(Vector2.ZERO, _map_layer.size)
	var xf := Transform2D(0.0, -_map_layer.get_global_rect().position) * get_viewport().get_canvas_transform()
	var g := 0.5 + 0.08 * _pulse()
	var c := (Vector2(lo) + Vector2(hi)) / 2.0
	var margin := area.grow(-EDGE)
	var mid := xf * Iso.to_world(c)
	if not tiles_in_view():
		# Out of view: an arrow at the edge of the map area, pointing the way.
		var centre := area.get_center()
		var dir := (mid - centre).normalized()
		_arrow(centre + dir * _edge_distance(margin, centre, dir), dir, col, _map_layer)
		return
	var half := (Vector2(hi - lo) + Vector2.ONE) / 2.0 * (g / 0.5)
	var pts := PackedVector2Array()
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(xf * Iso.to_world(c + d * half))
	var fill := col
	fill.a = 0.18 + 0.12 * _pulse()
	_map_layer.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	_map_layer.draw_polyline(pts, col, 4.0, true)
	# The arrow above its north corner, kept below the top bar.
	var tip := pts[0] - Vector2(0, 10.0 + bob)
	tip.y = maxf(tip.y, area.position.y + ARROW * 1.9)
	_arrow(tip, Vector2.DOWN, col, _map_layer)


## On _map_layer: an outline around every outlined unit's figure in view, an
## arrow over each; none in view: an arrow at the map area's edge towards the first.
func _draw_units() -> void:
	var rects := unit_screen_rects()
	if rects.is_empty():
		return
	var col := GOLD
	col.a = 0.55 + 0.45 * _pulse()
	var bob := 6.0 * sin(_t * 5.0)
	var off := _map_layer.get_global_rect().position
	var area := Rect2(Vector2.ZERO, _map_layer.size)
	var margin := area.grow(-EDGE)
	var shown := false
	for g in rects:
		var r := Rect2(g.position - off, g.size).grow(3.0 + 2.0 * _pulse())
		if not margin.has_point(r.get_center()):
			continue
		shown = true
		_map_layer.draw_rect(r, col, false, 3.0)
		var tip := Vector2(r.get_center().x, maxf(r.position.y - 8.0 - bob, ARROW * 1.9))
		_arrow(tip, Vector2.DOWN, col, _map_layer)
	if not shown:
		var centre := area.get_center()
		var dir := (rects[0].get_center() - off - centre).normalized()
		_arrow(centre + dir * _edge_distance(margin, centre, dir), dir, col, _map_layer)


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
func _arrow(tip: Vector2, dir: Vector2, col: Color, on: CanvasItem = self) -> void:
	var back := tip - dir * ARROW
	var side := Vector2(-dir.y, dir.x) * ARROW * 0.6
	var head := PackedVector2Array([tip, back + side, back - side])
	on.draw_colored_polygon(head, col)
	on.draw_polyline(PackedVector2Array([tip, back + side, back - side, tip]), UiTheme.INK, 2.0, true)
	on.draw_line(back, back - dir * ARROW * 0.9, col, 6.0, true)
