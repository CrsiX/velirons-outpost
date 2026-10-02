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

const LANDSCAPE_BASE := Vector2i(1280, 720)
const PORTRAIT_BASE := Vector2i(720, 1280)

var portrait := false
## The last full screen request was for this landscape spell (one per turn
## to landscape: a player who leaves full screen isn't asked again until then).
var _fullscreen_asked := false


func _ready() -> void:
	get_window().size_changed.connect(_update)
	_update()
	_landscape_fullscreen()


func _update() -> void:
	var s := get_window().size
	var p := s.y > s.x
	var base := PORTRAIT_BASE if p else LANDSCAPE_BASE
	if get_window().content_scale_size != base:
		get_window().content_scale_size = base
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
