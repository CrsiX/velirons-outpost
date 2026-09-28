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


func _ready() -> void:
	get_window().size_changed.connect(_update)
	_update()


func _update() -> void:
	var s := get_window().size
	var p := s.y > s.x
	var base := PORTRAIT_BASE if p else LANDSCAPE_BASE
	if get_window().content_scale_size != base:
		get_window().content_scale_size = base
	if p != portrait:
		portrait = p
		changed.emit(p)
