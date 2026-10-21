class_name CampaignMap
extends Control
## The campaign on the title screen (docs/ui-design.md): an old fantasy map of
## Veliron filling the screen (art "campaign_map", its layout in
## Campaign.MAP_FILE), the scenarios' places on it as pins (Scenario.place)
## and Brenna's route along the roads, and a parchment scroll for the chosen
## place with its scenarios and Play. Choosing a place glides the map to it
## (and a little closer); the map can be dragged. Places not yet open aren't
## shown (release builds); completed places carry a wax seal; the next one to
## play pulses, and the stretch of road to it draws itself in when the map
## opens. Landscape: the scroll stands on the right; portrait: a sheet along
## the bottom. Arrow keys step through the open scenarios, Enter plays, Esc
## rolls the scroll up, then closes the map.

signal closed
## Play scenario `n` (the title screen starts it).
signal play(n: int)

## A pin's size on screen (never smaller: a finger), the scroll's width, the top bar's height.
const PIN := 48.0
const CARD_W := 330.0
const BAR_H := 60.0
const INK := Color("4a3220")
## The travelled route (a red dotted trail) and the way ahead (red dashes).
const TRAIL := Color("8a2a1c")
## How much closer the map comes to a chosen place, and how long it takes (s).
const FOCUS_ZOOM := 1.15
const GLIDE := 0.45
## Seconds the stretch to the next scenario takes to draw itself in.
const DRAW_IN := 1.6
## A press that moves less than this (px) is a tap, not a drag.
const TAP := 8.0

## Every scenario open, also the locked ones (debug builds; tests may change it).
var show_all := OS.is_debug_build()
## The scenario on the scroll (0: none).
var selected := 0
var play_button: Button
var back_button: Button
## Scenario number -> its row on the scroll (the chosen place's only).
var rows := {}
## The map's view: the map point in the middle of the screen, and pixels per map unit.
var center := Vector2.ZERO
var zoom := 1.0

var _specs: Array[Scenario] = []
var _done: Array[String] = []
var _next := 0
var _places := {}
## Per scenario n (from 2): the road from scenario n - 1's place, in map units.
var _routes := {}
## 0..1: how much of the stretch to the next scenario is drawn.
var _draw_in := 1.0
var _map: TextureRect
var _route: Control
var _pins := {}  # place id -> TextureButton
var _pin_labels := {}  # place id -> Label
var _seals := {}  # place id -> TextureRect
var _regions: Array[Label] = []
var _note: Label
var _card: PanelContainer
var _card_title: Label
var _card_rows: VBoxContainer
var _portrait: TextureRect
var _blurb: Label
var _rods: Array[ColorRect] = []
var _glide: Tween
var _pulse := 0.0
## A press on the map: where it started and was last, and whether it became a drag.
var _press := Vector2.ZERO
var _last := Vector2.ZERO
var _pressed := false
var _dragging := false


func _ready() -> void:
	name = "CampaignMap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	visible = false
	_places = Campaign.places()
	var bg := ColorRect.new()
	bg.color = Color("1a120c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_map = TextureRect.new()
	_map.texture = Art.tex("campaign_map")
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.gui_input.connect(_on_map_input)
	add_child(_map)
	for r: Array in Campaign.REGIONS:
		var l := Label.new()
		l.text = str(r[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(INK, 0.8))
		l.add_theme_color_override("font_outline_color", Color("e4d3a8", 0.7))
		l.add_theme_constant_override("outline_size", 5)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_regions.append(l)
	_route = Control.new()
	_route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_route.draw.connect(_draw_route)
	add_child(_route)
	for id: String in _places:
		var pin := TextureButton.new()
		pin.texture_normal = Art.tex("pin_" + str(_places[id]["pin"]))
		pin.ignore_texture_size = true
		pin.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		pin.custom_minimum_size = Vector2(PIN, PIN)
		pin.size = Vector2(PIN, PIN)
		pin.pivot_offset = Vector2(PIN, PIN) / 2.0
		pin.tooltip_text = str(_places[id]["name"])
		pin.pressed.connect(_on_pin.bind(id))
		add_child(pin)
		_pins[id] = pin
		var seal := TextureRect.new()
		seal.texture = Art.tex("map_seal")
		seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		seal.size = Vector2(26, 26)
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(seal)
		_seals[id] = seal
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", INK)
		l.add_theme_color_override("font_outline_color", Color("ecdcb4"))
		l.add_theme_constant_override("outline_size", 7)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_pin_labels[id] = l
	_build_bar()
	_build_card()
	resized.connect(func() -> void:
		_layout(false)
		if selected > 0 and visible:
			glide_to(_specs[selected - 1].place))  # (a turned or resized screen: the place stays in view)


func _build_bar() -> void:
	var title := Label.new()
	title.text = "Campaign"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_color_override("font_outline_color", UiTheme.INK)
	title.add_theme_constant_override("outline_size", 8)
	title.position = Vector2(20, 8)
	add_child(title)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", UiTheme.MUTED)
	_note.position = Vector2(200, 20)
	add_child(_note)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(120, 44)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.pressed.connect(close)
	add_child(back_button)


## The scroll: parchment between two wooden rods.
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.box(Color("ead9b0"), Color("8a6a40"), 2, 6, 16))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)
	for i in 2:
		var rod := ColorRect.new()
		rod.color = Color("5a3a22")
		rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rod.visible = false
		add_child(rod)
		_rods.append(rod)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_card.add_child(v)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 24)
	_card_title.add_theme_color_override("font_color", Color("4a2a14"))
	_card_title.add_theme_constant_override("outline_size", 0)
	v.add_child(_card_title)
	_card_rows = VBoxContainer.new()
	_card_rows.add_theme_constant_override("separation", 4)
	v.add_child(_card_rows)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(72, 72)
	h.add_child(_portrait)
	_blurb = Label.new()
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blurb.custom_minimum_size = Vector2(180, 0)
	_blurb.add_theme_font_size_override("font_size", 15)
	_blurb.add_theme_color_override("font_color", Color("2a1a10"))
	_blurb.add_theme_constant_override("outline_size", 0)
	h.add_child(_blurb)
	play_button = Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(0, 52)
	play_button.focus_mode = Control.FOCUS_NONE
	play_button.add_theme_font_size_override("font_size", 24)
	UiTheme.style_primary(play_button)
	play_button.pressed.connect(func() -> void:
		if selected > 0 and is_open(selected):
			play.emit(selected))
	v.add_child(play_button)


# --- opening, progress --------------------------------------------------------------------------

## Shows the map with the progress as it is now, the scroll on the next scenario to play.
func open() -> void:
	_specs.clear()
	for n in range(1, Campaign.count() + 1):
		_specs.append(Campaign.scenario(n))
	_routes.clear()
	for n in range(2, _specs.size() + 1):
		if _specs[n - 2].place != _specs[n - 1].place:
			_routes[n] = Campaign.route(_specs[n - 2].place, _specs[n - 1].place)
	_done = Campaign.completed()
	_next = Campaign.next_to_play(_done)
	_note.text = "Scenarios %d to %d are still to come." % [Campaign.count() + 1, Campaign.PLANNED] if Campaign.count() < Campaign.PLANNED else ""
	for id: String in _places:
		var list := scenarios_at(id)
		var open_here := list.any(func(n: int) -> bool: return is_open(n))
		(_pins[id] as Control).visible = open_here
		(_pin_labels[id] as Control).visible = open_here
		(_seals[id] as Control).visible = open_here and list.all(func(n: int) -> bool: return Campaign.is_completed(n, _done))
		var nums: Array = list.filter(func(n: int) -> bool: return is_open(n)).map(func(n: int) -> String: return str(n))
		(_pin_labels[id] as Label).text = "%s\n%s" % [_places[id]["name"], " · ".join(nums)]
	visible = true
	zoom = _cover()
	center = Campaign.map_size() / 2.0
	_draw_in = 0.0 if _routes.has(_next) else 1.0
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(self, "_draw_in", 1.0, DRAW_IN)
	show_card(_next if _next > 0 else 1)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Scenario `n` can be played now (unlocked; every one with show_all).
func is_open(n: int) -> bool:
	return Campaign.unlocked(n, _done, show_all)


## The scenarios at place `id`, in order.
func scenarios_at(id: String) -> Array[int]:
	var out: Array[int] = []
	for i in _specs.size():
		if _specs[i].place == id:
			out.append(i + 1)
	return out


## Map units -> this control's pixels (and back).
func to_screen(p: Vector2) -> Vector2:
	return (p - center) * zoom + size / 2.0


func to_map(p: Vector2) -> Vector2:
	return (p - size / 2.0) / zoom + center


## Where place `id`'s pin stands (its centre, in this control).
func place_point(id: String) -> Vector2:
	return to_screen(_places[id]["at"])


func pin(id: String) -> TextureButton:
	return _pins[id]


## Place `id` isn't open yet: not shown (no pin, no name, no route to it).
func unknown(id: String) -> bool:
	return not (_pins[id] as Control).visible


func sealed(id: String) -> bool:
	return (_seals[id] as Control).visible


func card_open() -> bool:
	return _card.visible


## The route to scenario `n` (from the one before), in map units ([] if both are at one place).
func route_to(n: int) -> PackedVector2Array:
	return _routes.get(n, PackedVector2Array())


# --- the scroll ---------------------------------------------------------------------------------

func _on_pin(id: String) -> void:
	var list := scenarios_at(id)
	var pick := 0
	for n in list:
		if is_open(n) and (pick == 0 or n == _next):
			pick = n
	show_card(pick if pick > 0 else list[0])


## The scroll for scenario `n` (and its place's other scenarios), the map
## gliding to its place; 0 rolls it up.
func show_card(n: int) -> void:
	selected = n
	_card.visible = n > 0
	for rod in _rods:
		rod.visible = n > 0
	if n <= 0:
		return
	var spec := _specs[n - 1]
	_card_title.text = str(_places[spec.place]["name"])
	for c in _card_rows.get_children():
		c.queue_free()
	rows.clear()
	for k in scenarios_at(spec.place):
		var b := Button.new()
		var open_k := is_open(k)
		b.text = "%d. %s" % [k, _specs[k - 1].title] if open_k else "%d. Locked" % k
		b.disabled = not open_k
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 18)
		if Campaign.is_completed(k, _done):
			b.icon = Art.tex("icon_check")
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 22)
		if k == n:
			UiTheme.style_primary(b)
		b.pressed.connect(show_card.bind(k))
		_card_rows.add_child(b)
		rows[k] = b
	_portrait.texture = Art.tex(spec.portrait)
	_blurb.text = spec.blurb if is_open(n) else "Complete the scenario before it to open this one."
	play_button.disabled = not is_open(n)
	play_button.text = "Play again" if Campaign.is_completed(n, _done) else "Play"
	_unroll.call_deferred()


## The scroll unrolls (its height grows from the rods), the map glides to its place.
func _unroll() -> void:
	if selected <= 0:
		return
	_card.reset_size()
	_place_card()
	_card.pivot_offset = Vector2(_card.size.x / 2.0, 0)
	_card.scale = Vector2(1, 0.05)
	var tw := _card.create_tween()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	glide_to(_specs[selected - 1].place)


## The map glides so place `id` sits in the middle of the free part of the
## screen (beside or above the scroll), a little closer.
func glide_to(id: String) -> void:
	var z := _cover() * FOCUS_ZOOM
	var free := _free_rect()
	var want: Vector2 = _places[id]["at"] - (free.get_center() - size / 2.0) / z
	if _glide:
		_glide.kill()
	_glide = create_tween().set_parallel()
	_glide.tween_property(self, "zoom", z, GLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glide.tween_method(func(c: Vector2) -> void:
		center = c
		_layout(false), center, _clamped(want, z), GLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The screen part the scroll leaves free.
func _free_rect() -> Rect2:
	var top := BAR_H
	if Layout.portrait:
		var sheet := _card.get_combined_minimum_size().y + 16.0 if _card.visible else 0.0
		return Rect2(0, top, size.x, size.y - top - sheet)
	return Rect2(0, top, size.x - (CARD_W + 24.0 if _card.visible else 0.0), size.y - top)


func _place_card() -> void:
	if not _card.visible:
		return
	var vp := size
	var sz := _card.get_combined_minimum_size()
	if Layout.portrait:
		_card.size = Vector2(vp.x - 16.0, sz.y)
		_card.position = Vector2(8, vp.y - sz.y - 8.0)
	else:
		_card.size = Vector2(CARD_W, sz.y)
		_card.position = Vector2(vp.x - CARD_W - 12.0, clampf((vp.y + BAR_H - sz.y) / 2.0, BAR_H + 10.0, maxf(BAR_H + 10.0, vp.y - sz.y - 14.0)))
	for i in 2:
		var rod := _rods[i]
		rod.size = Vector2(_card.size.x + 14.0, 10.0)
		rod.position = _card.position + Vector2(-7.0, -6.0 if i == 0 else _card.size.y - 4.0)


# --- the view -----------------------------------------------------------------------------------

## The zoom at which the map just covers the screen.
func _cover() -> float:
	var ms := Campaign.map_size()
	return maxf(size.x / ms.x, size.y / ms.y) if size.x > 0.0 else 1.0


## `c` moved so the map still covers the screen at zoom `z`.
func _clamped(c: Vector2, z: float) -> Vector2:
	var half := size / (2.0 * z)
	var ms := Campaign.map_size()
	return Vector2(clampf(c.x, half.x, maxf(half.x, ms.x - half.x)), clampf(c.y, half.y, maxf(half.y, ms.y - half.y)))


## Everything on the map placed for the view (`snap`: back to covering the screen first).
func _layout(snap := true) -> void:
	if not visible:
		return
	if snap or zoom < _cover():
		zoom = maxf(zoom, _cover())
	center = _clamped(center, zoom)
	back_button.position = Vector2(size.x - back_button.custom_minimum_size.x - 12.0, 8.0)
	_map.position = to_screen(Vector2.ZERO)
	_map.size = Campaign.map_size() * zoom
	for i in _regions.size():
		var r: Array = Campaign.REGIONS[i]
		var l := _regions[i]
		l.add_theme_font_size_override("font_size", maxi(10, roundi(float(r[2]) * zoom)))
		l.reset_size()
		l.position = to_screen((r[1] as Vector2) * Campaign.map_size()) - l.size / 2.0
	for id: String in _places:
		var at := place_point(id)
		var p: TextureButton = _pins[id]
		p.position = at - p.size / 2.0
		var seal: TextureRect = _seals[id]
		seal.position = at + Vector2(PIN * 0.2, -PIN * 0.62)
		var l: Label = _pin_labels[id]
		l.reset_size()
		l.position = at + Vector2(-l.size.x / 2.0, PIN / 2.0 - 2.0)
	_route.queue_redraw()
	_place_card()


## Brenna's route along the roads, from each scenario's place to the next one's
## (where both are shown): a red dotted trail where the later scenario is
## completed, red dashes ahead (fainter beyond the next); the stretch to the
## next one draws itself in.
func _draw_route() -> void:
	for n: int in _routes:
		var a := _specs[n - 2].place
		var b := _specs[n - 1].place
		if unknown(a) or unknown(b):
			continue
		var pts := PackedVector2Array()
		for p in route_to(n):
			pts.append(to_screen(p))
		if pts.size() < 2:
			continue
		var share := _draw_in if n == _next else 1.0
		pts = _cut(_trim(pts, PIN * 0.5), share)
		if pts.size() < 2:
			continue
		if Campaign.is_completed(n, _done):
			_dots(pts, 9.0, 2.6, TRAIL)
		else:
			_dots(pts, 13.0, 2.6, Color(TRAIL, 0.8 if n == _next else 0.45), 7.0)


## Dots (or short dashes, `dash` > 0) every `step` px along `pts`.
func _dots(pts: PackedVector2Array, step: float, r: float, col: Color, dash := 0.0) -> void:
	var left := 0.0
	for k in pts.size() - 1:
		var p0 := pts[k]
		var p1 := pts[k + 1]
		var ln := p0.distance_to(p1)
		var dir := (p1 - p0) / maxf(ln, 0.001)
		var t := left
		while t < ln:
			var c := p0 + dir * t
			if dash > 0.0:
				_route.draw_line(c - dir * dash / 2.0, c + dir * dash / 2.0, col, r, true)
			else:
				_route.draw_circle(c, r, col)
			t += step
		left = t - ln


## `pts` without its first and last `gap` px (the pins stand there).
func _trim(pts: PackedVector2Array, gap: float) -> PackedVector2Array:
	var out := pts
	for _end in 2:
		out.reverse()
		var cut := gap
		while out.size() > 1 and out[0].distance_to(out[1]) <= cut:
			cut -= out[0].distance_to(out[1])
			out.remove_at(0)
		if out.size() > 1:
			out[0] = out[0].move_toward(out[1], cut)
	return out


## The first `share` (0..1) of `pts`, by length.
func _cut(pts: PackedVector2Array, share: float) -> PackedVector2Array:
	if share >= 1.0:
		return pts
	var total := 0.0
	for k in pts.size() - 1:
		total += pts[k].distance_to(pts[k + 1])
	var want := total * share
	var out := PackedVector2Array([pts[0]])
	for k in pts.size() - 1:
		var ln := pts[k].distance_to(pts[k + 1])
		if ln >= want:
			out.append(pts[k].move_toward(pts[k + 1], want))
			return out
		want -= ln
		out.append(pts[k + 1])
	return out


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	for id: String in _pins:
		var on := _next > 0 and _specs[_next - 1].place == id
		(_pins[id] as Control).scale = Vector2.ONE * (1.0 + 0.1 * sin(_pulse * 4.0)) if on else Vector2.ONE
	if _draw_in < 1.0:
		_route.queue_redraw()


# --- input --------------------------------------------------------------------------------------

## Dragging the map pans it (by position differences: see camera_controller.gd);
## a tap on it rolls the scroll up.
func _on_map_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_pressed = true
			_dragging = false
			_press = mb.global_position
			_last = mb.global_position
		elif _pressed:
			_pressed = false
			if not _dragging:
				show_card(0)
	elif e is InputEventMouseMotion and _pressed:
		var pos := (e as InputEventMouseMotion).global_position
		if not _dragging and pos.distance_to(_press) > TAP:
			_dragging = true
			if _glide:
				_glide.kill()
		if _dragging:
			center = _clamped(center - (pos - _last) / zoom, zoom)
			_layout(false)
		_last = pos


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			if _card.visible:
				show_card(0)
			else:
				close()
		KEY_ENTER, KEY_KP_ENTER:
			if selected > 0 and is_open(selected):
				play.emit(selected)
		KEY_LEFT, KEY_UP:
			step(-1)
		KEY_RIGHT, KEY_DOWN:
			step(1)
		_:
			return
	get_viewport().set_input_as_handled()


## The scroll on the open scenario `dir` steps from the chosen one (in the campaign's order).
func step(dir: int) -> void:
	var n := selected if selected > 0 else (_next if _next > 0 else 1)
	var k := n + dir
	while k >= 1 and k <= _specs.size():
		if is_open(k):
			show_card(k)
			return
		k += dir
