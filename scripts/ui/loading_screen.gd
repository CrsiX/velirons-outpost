class_name LoadingScreen
extends CanvasLayer
## The start screen (autoload "Loading"; docs/ui-design.md §2a): black over
## everything from the moment a game is started (free play's Play, a loaded
## save, a co-op start), a bar while a map is generated, "Waiting for
## clients..." while a co-op start waits for everyone, then plain black for a
## moment (Config.LOADING "black") and a fade into the game (LOADING "fade",
## real time), so the game never fades in over the bar. It lives across the scene change
## from the title to the game. Clicks and keys don't reach the game under it.

## Black, and not yet fading in.
var active := false
## What the next title screen tells the player (a start that gave up): "" for nothing.
var notice := ""
var _black: ColorRect
var _bar: ProgressBar
var _waiting: Label
var _fade: Tween


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.anchor_left = 0.3
	_bar.anchor_right = 0.7
	_bar.anchor_top = 0.62
	_bar.anchor_bottom = 0.62
	_bar.offset_top = -9.0
	_bar.offset_bottom = 9.0
	_bar.add_theme_stylebox_override("background", UiTheme.box(Color("2a2016"), UiTheme.MUTED, 1, 4, 0))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 4, 0))
	_black.add_child(_bar)
	_waiting = Label.new()
	_waiting.text = "Waiting for clients..."
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting.add_theme_font_size_override("font_size", 20)
	_waiting.add_theme_color_override("font_color", UiTheme.MUTED)
	_waiting.anchor_left = 0.0
	_waiting.anchor_right = 1.0
	_waiting.anchor_top = 0.62
	_waiting.anchor_bottom = 0.62
	_waiting.offset_top = 22.0
	_waiting.offset_bottom = 52.0
	_black.add_child(_waiting)
	_hide()


## Black at once; with `bar` (a map to generate) the bar at 0.
func begin(bar: bool) -> void:
	if _fade:
		_fade.kill()
	active = true
	visible = true
	_black.modulate.a = 1.0
	_bar.visible = bar
	_bar.value = 0.0
	_waiting.visible = false


## Black at once, then `path` from the next frame on (so the black is drawn
## before the scene loads).
func change_scene(path: String, bar: bool) -> void:
	begin(bar)
	var tree := get_tree()
	tree.process_frame.connect(func() -> void: tree.change_scene_to_file(path), CONNECT_ONE_SHOT)


## The bar's share (0..1); it never goes back.
func progress(f: float) -> void:
	if active:
		_bar.value = maxf(_bar.value, clampf(f, 0.0, 1.0))


func value() -> float:
	return _bar.value if _bar.visible else -1.0


func set_waiting(on: bool) -> void:
	_waiting.visible = on and active


## The game is ready: the bar goes, plain black for Config.LOADING "black",
## then a fade into the game over LOADING "fade" (real seconds).
func finish() -> void:
	if not active:
		return
	active = false
	_bar.visible = false
	_waiting.visible = false
	_fade = create_tween()
	_fade.set_ignore_time_scale(true)
	_fade.tween_interval(float(Config.LOADING["black"]))
	_fade.tween_property(_black, "modulate:a", 0.0, float(Config.LOADING["fade"]))
	_fade.tween_callback(_hide)


## Gone at once (a start given up, or a session that ended meanwhile).
func cancel() -> void:
	if _fade:
		_fade.kill()
	active = false
	_hide()


## Whether the black (or its fade) still covers the screen.
func covering() -> bool:
	return visible


func _hide() -> void:
	visible = false
	_bar.visible = false
	_waiting.visible = false


func _input(event: InputEvent) -> void:
	if visible and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch):
		get_viewport().set_input_as_handled()
