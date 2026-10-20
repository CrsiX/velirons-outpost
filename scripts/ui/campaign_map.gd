class_name CampaignMap
extends Control
## The campaign on the title screen (docs/ui-design.md): a parchment map of
## Veliron over the darkened backdrop, the scenarios' places on it as pins
## (Campaign.PLACES, Scenario.place) joined by Brenna's route, and a card for
## the chosen place with its scenarios and Play. Places not yet open aren't
## shown (release builds); completed places carry a wax seal; the next one to
## play pulses. The whole map always fits the screen: in landscape beside the
## card's column on the right, in portrait above the card's sheet. Arrow keys step through the open scenarios, Enter
## plays, Esc closes the card, then the map.

signal closed
## Play scenario `n` (the title screen starts it).
signal play(n: int)

## A pin's size on screen (never smaller: a finger), the card's width, the top bar's height.
const PIN := 48.0
const CARD_W := 330.0
const BAR_H := 60.0
const INK := Color("4a3220")

## Every scenario open, also the locked ones (debug builds; tests may change it).
var show_all := OS.is_debug_build()
## The scenario on the card (0: no card).
var selected := 0
var play_button: Button
var back_button: Button
## Scenario number -> its row on the card (the open place's only).
var rows := {}

var _specs: Array[Scenario] = []
var _done: Array[String] = []
var _next := 0
## Where the map picture is drawn now (in this control).
var _rect := Rect2()
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
var _pulse := 0.0


func _ready() -> void:
	name = "CampaignMap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.82)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_map = TextureRect.new()
	_map.texture = Art.tex("campaign_map")
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			show_card(0))  # (a tap on the map itself: the card goes)
	add_child(_map)
	for r: Array in Campaign.REGIONS:
		var l := Label.new()
		l.text = str(r[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(INK, 0.75))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_regions.append(l)
	_route = Control.new()
	_route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_route.draw.connect(_draw_route)
	add_child(_route)
	for id: String in Campaign.PLACES:
		var pin := TextureButton.new()
		pin.texture_normal = Art.tex("pin_" + str(Campaign.PLACES[id]["pin"]))
		pin.ignore_texture_size = true
		pin.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		pin.custom_minimum_size = Vector2(PIN, PIN)
		pin.size = Vector2(PIN, PIN)
		pin.pivot_offset = Vector2(PIN, PIN) / 2.0
		pin.tooltip_text = str(Campaign.PLACES[id]["name"])
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
		l.add_theme_color_override("font_outline_color", Color("e8dcb8"))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_pin_labels[id] = l
	_build_bar()
	_build_card()
	resized.connect(_fit)


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


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.box(Color("e8dcb8"), Color("6a4a2a"), 4, 10, 16))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	add_child(_card)
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

## Shows the map with the progress as it is now, the card on the next scenario to play.
func open() -> void:
	_specs.clear()
	for n in range(1, Campaign.count() + 1):
		_specs.append(Campaign.scenario(n))
	_done = Campaign.completed()
	_next = Campaign.next_to_play(_done)
	_note.text = "Scenarios %d to %d are still to come." % [Campaign.count() + 1, Campaign.PLANNED] if Campaign.count() < Campaign.PLANNED else ""
	for id: String in Campaign.PLACES:
		var list := scenarios_at(id)
		var open_here := list.any(func(n: int) -> bool: return is_open(n))
		(_pins[id] as Control).visible = open_here
		(_pin_labels[id] as Control).visible = open_here
		(_seals[id] as Control).visible = open_here and list.all(func(n: int) -> bool: return Campaign.is_completed(n, _done))
		var nums: Array = list.filter(func(n: int) -> bool: return is_open(n)).map(func(n: int) -> String: return str(n))
		(_pin_labels[id] as Label).text = "%s\n%s" % [Campaign.PLACES[id]["name"], " · ".join(nums)]
	visible = true
	_fit()
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


## Where place `id`'s pin stands (its centre, in this control).
func place_point(id: String) -> Vector2:
	return _rect.position + (Campaign.PLACES[id]["at"] as Vector2) * _rect.size


func pin(id: String) -> TextureButton:
	return _pins[id]


## Place `id` isn't open yet: not shown (no pin, no name, no route to it).
func unknown(id: String) -> bool:
	return not (_pins[id] as Control).visible


func sealed(id: String) -> bool:
	return (_seals[id] as Control).visible


func card_open() -> bool:
	return _card.visible


# --- the card -----------------------------------------------------------------------------------

func _on_pin(id: String) -> void:
	var list := scenarios_at(id)
	var pick := 0
	for n in list:
		if is_open(n) and (pick == 0 or n == _next):
			pick = n
	show_card(pick if pick > 0 else list[0])


## The card for scenario `n` (and its place's other scenarios); 0 hides it.
func show_card(n: int) -> void:
	selected = n
	_card.visible = n > 0
	if n <= 0:
		_fit.call_deferred()
		return
	var spec := _specs[n - 1]
	_card_title.text = str(Campaign.PLACES[spec.place]["name"])
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
	_fit.call_deferred()


func _place_card() -> void:
	if not _card.visible or selected <= 0:
		return
	_card.reset_size()
	var vp := size
	var sz := _card.get_combined_minimum_size()
	if Layout.portrait:
		_card.size = Vector2(vp.x - 16.0, sz.y)
		_card.position = Vector2(8, vp.y - sz.y - 8.0)
		return
	_card.size = Vector2(CARD_W, sz.y)
	var y := clampf(_rect.get_center().y - sz.y / 2.0, BAR_H, maxf(BAR_H, vp.y - sz.y - 8.0))
	_card.position = Vector2(vp.x - CARD_W - 12.0, y)


# --- layout -------------------------------------------------------------------------------------

## The whole map in the space under the bar (portrait: at the top, the card's sheet under it).
func _fit() -> void:
	if not visible:
		return
	var vp := size
	back_button.position = Vector2(vp.x - back_button.custom_minimum_size.x - 12.0, 8.0)
	# Landscape: beside the card's column; portrait: above the card's sheet.
	var sheet := _card.get_combined_minimum_size().y + 16.0 if Layout.portrait and _card.visible else 0.0
	var area := Rect2(12.0, BAR_H, vp.x - 24.0 - (0.0 if Layout.portrait else CARD_W + 12.0), vp.y - BAR_H - 12.0 - sheet)
	var s := minf(area.size.x / Campaign.MAP_SIZE.x, area.size.y / Campaign.MAP_SIZE.y)
	var msize := Campaign.MAP_SIZE * s
	var top := area.position.y + (area.size.y - msize.y) / 2.0
	_rect = Rect2(Vector2(area.position.x + (area.size.x - msize.x) / 2.0, top), msize)
	_map.position = _rect.position
	_map.size = _rect.size
	for i in _regions.size():
		var r: Array = Campaign.REGIONS[i]
		var l := _regions[i]
		l.add_theme_font_size_override("font_size", maxi(10, roundi(float(r[2]) * s)))
		l.reset_size()
		l.position = _rect.position + (r[1] as Vector2) * _rect.size - l.size / 2.0
	for id: String in Campaign.PLACES:
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


## Brenna's route: from each scenario's place to the next one's (where both are open):
## ink where the later scenario is completed, dashes where it is still ahead.
func _draw_route() -> void:
	for n in range(2, _specs.size() + 1):
		var a := _specs[n - 2].place
		var b := _specs[n - 1].place
		if a == b or unknown(a) or unknown(b):
			continue
		var p := place_point(a)
		var q := place_point(b)
		var d := (q - p).normalized() * PIN * 0.55
		if Campaign.is_completed(n, _done):
			_route.draw_line(p + d, q - d, Color(INK, 0.85), 3.0, true)
		else:
			_route.draw_dashed_line(p + d, q - d, Color(INK, 0.75), 2.5, 9.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	for id: String in _pins:
		var on := _next > 0 and _specs[_next - 1].place == id
		(_pins[id] as Control).scale = Vector2.ONE * (1.0 + 0.1 * sin(_pulse * 4.0)) if on else Vector2.ONE


# --- keys ---------------------------------------------------------------------------------------

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


## The card on the open scenario `dir` steps from the chosen one (in the campaign's order).
func step(dir: int) -> void:
	var n := selected if selected > 0 else (_next if _next > 0 else 1)
	var k := n + dir
	while k >= 1 and k <= _specs.size():
		if is_open(k):
			show_card(k)
			return
		k += dir
