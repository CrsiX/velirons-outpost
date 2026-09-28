class_name CameraController
extends Camera2D
## Map navigation for mouse, touch and keyboard.
## Drag = pan, wheel / pinch / trackpad = zoom, short press = tap.

signal tapped(world_pos: Vector2)
signal hovered(world_pos: Vector2)
signal cancelled

const MIN_ZOOM := 0.3
const MAX_ZOOM := 1.6
const DRAG_THRESHOLD := 12.0
const KEY_PAN_SPEED := 900.0

var bounds := Rect2()
## Optional: called with the screen position of a left press on the map; if it
## returns true the press belongs to someone else (e.g. dragging a unit off a
## tower), so the camera neither pans nor reports a tap for it.
var press_filter: Callable

var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _touches: Dictionary = {}  # index -> screen position
var _pinch_dist := 0.0


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func focus(world_pos: Vector2) -> void:
	position = world_pos
	_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if press_filter.is_valid() and press_filter.call(mb.position):
						_pressing = false
						return
					_pressing = true
					_dragging = false
					_press_pos = mb.position
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoom_at(mb.position, 1.12)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom_at(mb.position, 1.0 / 1.12)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
					cancelled.emit()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.position, mg.factor)
	elif event is InputEventPanGesture:
		position += (event as InputEventPanGesture).delta * 12.0 / zoom
		_clamp()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancelled.emit()


func _input(event: InputEvent) -> void:
	# Pinch zoom with two fingers.
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() == 2:
			_pinch_dist = _touch_spread()
			_dragging = true  # a pinch is never a tap
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			var d := _touch_spread()
			if _pinch_dist > 0.0 and d > 0.0:
				zoom_at(_touch_center(), d / _pinch_dist)
			_pinch_dist = d
	# Panning / tapping (mouse, or touch emulated as mouse).
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing:
			if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging and _touches.size() < 2:
				position -= mm.relative / zoom
				_clamp()
		else:
			hovered.emit(screen_to_world(mm.position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _pressing:
			_pressing = false
			if not _dragging:
				tapped.emit(screen_to_world(mb.position))
			_dragging = false


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		# Real delta so panning speed ignores the game-speed setting.
		position += dir.normalized() * KEY_PAN_SPEED * delta / Engine.time_scale / zoom.x
		_clamp()


func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	var z := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	force_update_scroll()
	var after := screen_to_world(screen_pos)
	position += before - after
	_clamp()


func _clamp() -> void:
	if bounds.size != Vector2.ZERO:
		position = position.clamp(bounds.position, bounds.end)


func _touch_spread() -> float:
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _touch_center() -> Vector2:
	var pts := _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0
