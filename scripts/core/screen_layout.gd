extends Node
## Autoload "Layout": landscape or portrait, following the device.
##
## Android turns the screen by its rotation sensor (project setting
## display/window/handheld/orientation = sensor). Browsers and desktop windows
## simply resize. Either way the window is portrait while it's taller than
## wide. The logical canvas then becomes 720 wide instead of 720 high, so the
## UI keeps the same physical size in both orientations (with the landscape
## base of 1280x720 a phone held upright would show the UI at about half size).
## Screens listen to `changed` (or the viewport's size_changed) and rearrange.

signal changed(portrait: bool)
## The safe area moved (a turn put the camera cutout on another side).
signal safe_area_changed


const LANDSCAPE_BASE := Vector2i(1280, 720)
const PORTRAIT_BASE := Vector2i(720, 1280)

var portrait := false
## The last press came from a finger (no hover then: building shows a preview
## to confirm, see Game). A real mouse click sets it back.
var touch := false
## The last full screen request was for this landscape spell (one per turn
## to landscape: a player who leaves full screen isn't asked again until then).
var _fullscreen_asked := false
## The screen's unusable edges in canvas units: a camera cutout or notch on
## a phone (Android, iOS; Godot's safe area), else none. x left, y top,
## z right, w bottom. The HUD and the map editor keep their controls inside
## (`inset`); the map and full-screen backgrounds still go edge to edge (`bleed`).
var insets := Vector4.ZERO
var _forced := false
var _poll := 0.0
## Controls kept inside the safe area / spread over the whole screen.
var _inset: Array[Control] = []
var _bleed: Array[Control] = []


func _ready() -> void:
	get_window().size_changed.connect(_update)
	_update()
	_landscape_fullscreen()
	set_process(OS.has_feature("mobile"))  # (the safe area: see _process)


## Android can report the new safe area a little after a turn: look again
## now and then.
func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = Config.SAFE_AREA_POLL
		_update_insets()


## Keeps `c` (a full-rect control) inside the safe area.
func inset(c: Control) -> void:
	_inset.append(c)
	_apply(c, 1.0)


## Spreads `c` (a background inside an inset control) over the whole screen.
func bleed(c: Control) -> void:
	_bleed.append(c)
	_apply(c, -1.0)


## For tests and screenshots: pretend the screen has these unusable edges.
func force_insets(v: Vector4) -> void:
	_forced = true
	_set_insets(v)


func clear_forced_insets() -> void:
	_forced = false
	_set_insets(Vector4.ZERO)
	_update_insets()


func _apply(c: Control, dir: float) -> void:
	c.offset_left = insets.x * dir
	c.offset_top = insets.y * dir
	c.offset_right = -insets.z * dir
	c.offset_bottom = -insets.w * dir


func _update_insets() -> void:
	if _forced or not OS.has_feature("mobile"):
		return
	var win := get_window()
	var canvas := win.get_visible_rect().size
	if win.size.x <= 0 or canvas.x <= 0.0:
		return
	var px := Rect2(DisplayServer.get_display_safe_area())
	if px.size.x <= 0.0 or px.size.y <= 0.0:
		return
	var scale := Vector2(win.size) / canvas
	var full := Rect2(Vector2(win.position), Vector2(win.size))
	_set_insets(Vector4(
		maxf(0.0, px.position.x - full.position.x) / scale.x,
		maxf(0.0, px.position.y - full.position.y) / scale.y,
		maxf(0.0, full.end.x - px.end.x) / scale.x,
		maxf(0.0, full.end.y - px.end.y) / scale.y).round())


func _set_insets(v: Vector4) -> void:
	if v == insets:
		return
	insets = v
	_inset.assign(_inset.filter(func(c: Control) -> bool: return is_instance_valid(c)))
	_bleed.assign(_bleed.filter(func(c: Control) -> bool: return is_instance_valid(c)))
	for c in _inset:
		_apply(c, 1.0)
	for c in _bleed:
		_apply(c, -1.0)
	safe_area_changed.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch = true
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		touch = false


func _update() -> void:
	var s := get_window().size
	var p := s.y > s.x
	var base := PORTRAIT_BASE if p else LANDSCAPE_BASE
	if get_window().content_scale_size != base:
		get_window().content_scale_size = base
	_update_insets()
	if p != portrait:
		portrait = p
		changed.emit(p)
		_landscape_fullscreen()


## Phones and tablets go full screen when turned to landscape: the Android
## app at once; a mobile browser on the next tap (browsers only allow it in
## answer to one). iOS Safari has no full screen for pages, so nothing there.
func _landscape_fullscreen() -> void:
	if portrait:
		_fullscreen_asked = false
		return
	if _fullscreen_asked:
		return
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		_fullscreen_asked = true
		JavaScriptBridge.eval("""
			if (!window.velironFullscreen) {
				window.velironFullscreen = { armed: false };
				var go = function () {
					var fs = window.velironFullscreen;
					if (!fs.armed || window.innerHeight > window.innerWidth) return;
					fs.armed = false;
					var el = document.documentElement;
					if (!document.fullscreenElement && el.requestFullscreen) el.requestFullscreen().catch(function () {});
				};
				document.addEventListener('touchend', go, true);
				document.addEventListener('click', go, true);
			}
			window.velironFullscreen.armed = true;
		""", true)
	elif OS.has_feature("mobile"):
		_fullscreen_asked = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
