class_name Cutscene
extends CanvasLayer
## An in-engine cutscene (docs/scenarios-design.md §1): the game's own map
## behind, the camera moving between spots, people speaking in a box at the
## bottom (portrait, name, line), black bars above and below. A tap, a click,
## Space or Enter shows the whole line, then the next one; Skip (top right) or
## Esc ends the cutscene at once. The game runs on at 1x meanwhile (people
## walk), with the HUD hidden and the map's input off.
##
## Steps (Dictionaries), played in order:
##   {"say": speaker id ("" the narrator), "text": "..."}   waits for a tap
##   {"camera": world position, "zoom": z, "time": s}         moves the camera (and
##                                                            waits, unless "wait": false);
##                                                            a Callable -> Vector2 gives the
##                                                            position when the step plays
##   {"wait": s}
##   {"fade": "in" | "out", "time": s}                       to and from black
##   {"title": "...", "sub": "...", "time": s}               a title card (a tap goes on)
##   {"do": Callable}                                         a scripted action, at once
##   {"until": Callable -> bool, "max": s}                    waits until it holds
##   {"say": ..., "text": ..., "choices": [{"text", "do": Callable}]}
##                                     a line with buttons instead of a tap: the
##                                     picked one's "do" runs, then the cutscene
##                                     goes on (Scenario 4's offer)
## Times are real seconds (whatever the game speed). Skip, before a choice
## still to come, jumps to it (only "do" steps run on the way): the player
## always makes the choice. After it, Skip ends the cutscene.

signal finished(skipped: bool)
## A tap went through to the step waiting for it (advance()).
signal tapped

## Seconds per character as a line appears.
const TYPE_SPEED := 0.022
const BAR := 0.09  # the black bars' share of the screen height

var game: Game
var steps: Array[Dictionary] = []
## Speaker id -> {"name", "portrait", "color"} (Scenario.speakers).
var speakers := {}
var running := false
## The step being played (index into steps).
var index := -1
## The line shown now: "" while none ("say" steps only).
var line := ""
var _skipped := false
## Skipping towards the choice at this step (-1: not skipping).
var _skip_to := -1
## The choice made at each choice step so far (step index -> choice index).
var chosen := {}
var _tap_wait := false
var _typing: Tween
var _cam_tween: Tween

var _root: Control
var _bars: Array[ColorRect] = []
var _fader: ColorRect
var _box: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _more: Label
var _choices: HBoxContainer
var _title: Label
var _sub: Label
var skip_button: Button



## Plays `p_steps` over `p_game` (call once; it frees itself when done).
func play(p_game: Game, p_steps: Array[Dictionary], p_speakers: Dictionary) -> void:
	game = p_game
	steps = p_steps
	speakers = p_speakers
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	game.add_child(self)
	running = true
	_hold_game(true)
	_run()


func _build() -> void:
	_root = Control.new()
	_root.theme = UiTheme.build()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # (the map gets no taps meanwhile)
	_root.gui_input.connect(_on_gui_input)
	add_child(_root)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0 - BAR
		bar.anchor_bottom = BAR if top else 1.0
		_root.add_child(bar)
		_bars.append(bar)
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_fader)
	var safe := Control.new()  # (clear of a phone's camera cutout)
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(safe)
	Layout.inset(safe)
	_title = _label("", 64, UiTheme.GOLD)
	_title.add_theme_color_override("font_outline_color", UiTheme.INK)
	_title.add_theme_constant_override("outline_size", 12)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	safe.add_child(_title)
	_sub = _label("", 26, UiTheme.TEXT)
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub.offset_top = 56.0
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate.a = 0.0
	safe.add_child(_sub)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiTheme.box(Color("1c1410ee"), UiTheme.GOLD, 3, 12, 16))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.visible = false
	safe.add_child(_box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(h)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(112, 112)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_name = _label("", 24, UiTheme.GOLD)
	v.add_child(_name)
	_text = _label("", 21, UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_more = _label("Tap to go on", 14, UiTheme.MUTED)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_more)
	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 12)
	_choices.visible = false
	v.add_child(_choices)
	skip_button = Button.new()
	skip_button.text = "Skip"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.custom_minimum_size = Vector2(110, 46)
	skip_button.add_theme_font_size_override("font_size", 20)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_button.offset_right = -14.0
	skip_button.offset_top = 10.0
	skip_button.pressed.connect(skip)
	safe.add_child(skip_button)
	_layout()
	_root.resized.connect(_layout)


func _label(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The box: at most 900 px wide, above the bottom bar.
func _layout() -> void:
	var vp := _root.size
	var w := minf(vp.x - 24.0, 900.0)
	_box.custom_minimum_size = Vector2(w, 150.0)
	_box.offset_left = -w / 2.0
	_box.offset_right = w / 2.0
	_box.offset_bottom = -maxf(vp.y * BAR - 40.0, 10.0)
	var narrow := vp.x < 640.0
	_portrait.custom_minimum_size = Vector2(80, 80) if narrow else Vector2(112, 112)
	_title.add_theme_font_size_override("font_size", 44 if narrow else 64)


# --- playing ----------------------------------------------------------------------------

## Plays the steps; once over (or skipped, when the step under way has
## noticed), it frees itself.
func _run() -> void:
	await _play_steps()
	_end(false)  # (nothing if skipped)
	queue_free()


func _play_steps() -> void:
	for i in steps.size():
		if _skipped:
			return
		index = i
		var s: Dictionary = steps[i]
		if _skip_to >= 0:
			if i < _skip_to:
				if s.has("do"):
					(s["do"] as Callable).call()
				continue
			_skip_to = -1
			_fader.color.a = 0.0  # (skipped past a fade in)
		if s.has("choices"):
			await _choose(str(s.get("say", "")), str(s.get("text", "")), s["choices"])
		elif s.has("say"):
			await _say(str(s["say"]), str(s["text"]))
		elif s.has("camera"):
			var t := float(s.get("time", 1.5))
			var to: Vector2 = (s["camera"] as Callable).call() if s["camera"] is Callable else s["camera"]
			_move_camera(to, float(s.get("zoom", game.camera.zoom.x)), t)
			if s.get("wait", true):
				await _sleep(t)
		elif s.has("wait"):
			await _sleep(float(s["wait"]))
		elif s.has("fade"):
			var t := float(s.get("time", 0.8))
			_tween(_fader, "color:a", 1.0 if s["fade"] == "out" else 0.0, t)
			await _sleep(t)
		elif s.has("title"):
			await _title_card(str(s["title"]), str(s.get("sub", "")), float(s.get("time", 3.0)))
		elif s.has("do"):
			(s["do"] as Callable).call()
		elif s.has("until"):
			var left := float(s.get("max", 10.0))
			while left > 0.0 and not _skipped and _skip_to < 0 and not (s["until"] as Callable).call():
				await _sleep(0.1)
				left -= 0.1


func _say(who: String, t: String) -> void:
	_show_line(who, t)
	_tap_wait = true
	await tapped
	_tap_wait = false
	line = ""


## The box with `who`'s portrait and name and line `t`, typing out.
func _show_line(who: String, t: String) -> void:
	var sp: Dictionary = speakers.get(who, {})
	_box.visible = true
	var narrator := sp.is_empty()
	_portrait.visible = not narrator and sp.has("portrait")
	if _portrait.visible:
		_portrait.texture = Art.tex(str(sp["portrait"]))
	_name.visible = not narrator
	_name.text = str(sp.get("name", ""))
	_name.add_theme_color_override("font_color", sp.get("color", UiTheme.GOLD))
	_text.text = t
	_text.add_theme_color_override("font_color", UiTheme.MUTED if narrator else UiTheme.TEXT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narrator else HORIZONTAL_ALIGNMENT_LEFT
	line = t
	_text.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.2, t.length() * TYPE_SPEED))
	_more.modulate.a = 0.0
	_typing.tween_property(_more, "modulate:a", 1.0, 0.3)


## A line with a button per choice; waits for one (Skip doesn't pass it).
func _choose(who: String, t: String, list: Array) -> void:
	_show_line(who, t)
	_typing = null
	_text.visible_ratio = 1.0
	_more.visible = false
	for c in _choices.get_children():
		c.queue_free()
	var picked := [-1]
	for k in list.size():
		var b := Button.new()
		b.text = str(list[k]["text"])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func() -> void:
			picked[0] = k
			tapped.emit())
		_choices.add_child(b)
	_choices.visible = true
	_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_choices.mouse_filter = Control.MOUSE_FILTER_PASS
	while picked[0] < 0 and running:
		await tapped
	_choices.visible = false
	_more.visible = true
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line = ""
	if picked[0] < 0:
		return  # (the game ended meanwhile)
	chosen[index] = picked[0]
	var c: Dictionary = list[picked[0]]
	if c.has("do"):
		(c["do"] as Callable).call()


## Picks choice `k` of the choice shown now (tests; as its button).
func choose(k: int) -> void:
	var bs := _choices.get_children()
	if _choices.visible and k >= 0 and k < bs.size():
		(bs[k] as Button).pressed.emit()


## Whether a choice is waiting for the player now.
func choosing() -> bool:
	return running and _choices.visible


func _title_card(t: String, sub: String, time: float) -> void:
	_box.visible = false
	_title.text = t
	_sub.text = sub
	_tween(_title, "modulate:a", 1.0, 0.6)
	_tween(_sub, "modulate:a", 1.0, 0.9)
	_tap_wait = true
	var left := time
	var taps := [false]
	var on_tap := func() -> void: taps[0] = true
	tapped.connect(on_tap)
	while left > 0.0 and not taps[0] and not _skipped and _skip_to < 0:
		await _sleep(0.1)
		left -= 0.1
	tapped.disconnect(on_tap)
	_tap_wait = false
	_tween(_title, "modulate:a", 0.0, 0.5)
	_tween(_sub, "modulate:a", 0.0, 0.5)
	await _sleep(0.5)


func _move_camera(to: Vector2, z: float, time: float) -> void:
	var cam := game.camera
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(cam, "position", to, maxf(time, 0.01))
	_cam_tween.tween_property(cam, "zoom", Vector2(z, z), maxf(time, 0.01))


func _tween(o: Object, prop: String, to: float, time: float) -> void:
	create_tween().tween_property(o, prop, to, maxf(time, 0.01))


## Waits `t` real seconds (process always, whatever the game speed).
func _sleep(t: float) -> void:
	await get_tree().create_timer(maxf(t, 0.0), true, false, true).timeout


## A tap: the whole line if it is still appearing, else the next step.
func advance() -> void:
	if not running or not _tap_wait:
		return
	if _typing and _typing.is_running() and _text.visible_ratio < 1.0:
		_typing.kill()
		_text.visible_ratio = 1.0
		_more.modulate.a = 1.0
		return
	tapped.emit()


func skip() -> void:
	if not running or choosing():
		return
	for k in range(index + 1, steps.size()):
		if steps[k].has("choices"):
			_skip_to = k  # (on to the choice: the player makes it)
			if _cam_tween:
				_cam_tween.kill()
			tapped.emit()
			return
	_skipped = true
	tapped.emit()
	_end(true)


## Ends it now, a choice waiting or not (the scenario is lost meanwhile).
func stop() -> void:
	if not running:
		return
	_skipped = true
	_end(true)
	tapped.emit()


## Over: the game as it was, the cutscene hidden (it frees itself once its
## step under way is done, see _run).
func _end(skipped: bool) -> void:
	if not running:
		return
	running = false
	visible = false
	if _cam_tween:
		_cam_tween.kill()  # (skipped mid-move: the camera stays where it is)
	_hold_game(false)
	finished.emit(skipped)


## While it plays: the HUD hidden, the map's input off, the game at 1x.
func _hold_game(on: bool) -> void:
	var cam := game.camera
	cam.set_process_unhandled_input(not on)
	cam.set_process_input(not on)
	cam.set_process(not on)
	if game.hud:
		game.hud.visible = not on
	if on:
		game.cancel_mode()
		game.apply_speed(0)


func _on_gui_input(event: InputEvent) -> void:
	# (a finger comes as a mouse click too: the project emulates the mouse from touch)
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance()
		_root.accept_event()


func _input(event: InputEvent) -> void:
	if not running or not (event is InputEventKey) or not event.is_pressed():
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not event.is_echo():
				advance()
		KEY_ESCAPE:
			skip()
	get_viewport().set_input_as_handled()  # (no other key while it plays: the HUD's are off)
