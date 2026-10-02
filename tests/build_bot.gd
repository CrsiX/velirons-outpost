extends "res://tests/bot_base.gd"
## Headless test of placing buildings with a mouse and with a finger: one
## building per pick (build mode ends once it's placed), the Build entry
## toggles, the big Cancel button, touch's preview with Build / Cancel beside
## it, dragging an entry onto the map (a finger's building shows above it),
## and Android's back button. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/build_bot.tscn
## Also the portrait bottom sheet: at most half the screen, its entries
## scroll by finger from anywhere (a scroll is no tap), and its handle drags.
## Exits 0 when every check passes.

var hud: Hud
var _touch := false


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	get_viewport().size = Vector2i(1280, 720)
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = 4242  # (the same map every run)
	add_child(game)
	await frames(3)
	hud = game.hud
	for r in ["gold", "materials", "food"]:
		game.economy.add(r, 5000)
	await _mouse()
	await _touch_preview()
	await _drag()
	await _back_button()
	await _sheet()
	Layout.touch = false
	print("CHECKS %d  FAILURES %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# --- input, as a mouse or as a finger (touch emulated as mouse, as Godot does) ---

func use_touch(on: bool) -> void:
	_touch = on
	if on:
		var t := InputEventScreenTouch.new()
		t.pressed = false
		t.position = Vector2(-50, -50)
		get_viewport().push_input(t)
	else:
		Layout.touch = false
	await frames(1)


func mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.device = InputEvent.DEVICE_ID_EMULATION if _touch else 0
	get_viewport().push_input(e, true)


func motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.device = InputEvent.DEVICE_ID_EMULATION if _touch else 0
	get_viewport().push_input(e, true)


func tap(pos: Vector2) -> void:
	mouse(pos, true)
	await frames(1)
	mouse(pos, false)
	await frames(2)


## Press `from`, move in steps to `to`, let go.
func drag(from: Vector2, to: Vector2) -> void:
	mouse(from, true)
	await frames(1)
	for i in range(1, 11):
		motion(from.lerp(to, i / 10.0))
		await frames(1)
	mouse(to, false)
	await frames(2)


func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## The screen position of tile `t` (its middle), the camera centred near it.
func on_screen(t: Vector2i) -> Vector2:
	return game.camera.world_to_screen(Iso.to_world(t))


func spot(kind: String, avoid: Array[Vector2i] = []) -> Vector2i:
	var c := game.player_village.center
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var t := c + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(c))
			if d >= best_d or game.construction.placement_error(kind, t) != "":
				continue
			var near := false
			for a in avoid:
				near = near or maxi(absi(a.x - t.x), absi(a.y - t.y)) <= 2
			if not near:
				best_d = d
				best = t
	return best


func built_at(kind: String, t: Vector2i) -> bool:
	return game.player_village.buildings().any(func(b: Building) -> bool: return b.kind == kind and b.tile == t)


func count(kind: String) -> int:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b.kind == kind).size()


func open_build_tab() -> void:
	hud.show_tab("build")
	await frames(2)
	hud.scroll_to(hud._build_buttons["tower"])
	await frames(2)


# --- the parts -------------------------------------------------------------------

func _mouse() -> void:
	print("-- with a mouse")
	await use_touch(false)
	await open_build_tab()
	var button: Button = hud._build_buttons["tower"]
	await tap(center(button))
	check(game.mode == Game.Mode.BUILD and game.build_kind == "tower", "the Build entry picks the watchtower")
	var cb := hud._cancel_button
	var vp := get_viewport().get_visible_rect()
	var r := cb.get_global_rect()
	check(cb.is_visible_in_tree() and vp.encloses(r) and r.size.x >= 160.0 and r.size.y >= 60.0 and r.position.y > vp.size.y * 0.7, "a big Cancel button in the bottom corner (%s)" % str(r))
	check(not hud._sidebar.get_global_rect().intersects(r), "beside the sidebar, not over it")
	await tap(center(button))
	check(game.mode == Game.Mode.NONE and not cb.visible, "tapping the entry again puts it away")
	await tap(center(button))
	await tap(center(cb))
	check(game.mode == Game.Mode.NONE, "Cancel puts it away")
	var t := spot("tower")
	game.camera.focus(Iso.to_world(t))
	await frames(2)
	await tap(center(button))
	await tap(on_screen(t))
	check(built_at("tower", t), "a click on the map builds it there at once %s" % str(t))
	check(game.mode == Game.Mode.NONE and game.build_kind == "", "and build mode ends: the next click builds nothing")
	var n := count("tower")
	await tap(on_screen(t + Vector2i(3, 0)))
	check(count("tower") == n, "a click afterwards just selects")


func _touch_preview() -> void:
	print("-- with a finger: preview, then Build")
	await use_touch(true)
	check(Layout.touch, "a touch is noticed")
	await open_build_tab()
	var button: Button = hud._build_buttons["tower"]
	var taken: Array[Vector2i] = []
	for b in game.player_village.buildings():
		taken.append(b.tile)
	var t1 := spot("tower", taken)
	taken.append(t1)
	var t2 := spot("tower", taken)
	game.camera.focus((Iso.to_world(t1) + Iso.to_world(t2)) / 2.0)
	await frames(2)
	await tap(center(button))
	var n := count("tower")
	await tap(on_screen(t1))
	check(count("tower") == n and game.pending_tile == t1 and game.mode == Game.Mode.BUILD, "the first tap only shows it there %s" % str(t1))
	var bar := hud._place_bar
	await frames(2)
	var vp := get_viewport().get_visible_rect()
	check(bar.is_visible_in_tree() and vp.encloses(bar.get_global_rect()) and not hud._place_build.disabled, "with Build / Cancel beside it, on screen")
	check(bar.get_global_rect().position.y > on_screen(t1).y, "under the building")
	await tap(on_screen(t2))
	check(game.pending_tile == t2 and count("tower") == n, "a tap elsewhere moves it %s" % str(t2))
	var before := bar.position
	game.camera.focus(game.camera.position + Vector2(60, 40))
	await frames(2)
	check(bar.position != before, "Build / Cancel follow it when the map moves")
	await tap(center(hud._place_build))
	check(built_at("tower", t2) and game.mode == Game.Mode.NONE and not bar.visible, "Build builds it, and build mode ends")
	taken.append(t2)
	var t3 := spot("tower", taken)
	game.camera.focus(Iso.to_world(t3))
	await frames(2)
	await tap(center(button))
	await tap(on_screen(t3))
	await tap(on_screen(t3))
	check(built_at("tower", t3) and game.mode == Game.Mode.NONE, "a second tap on the building builds it too")
	game.camera.focus(Iso.to_world(game.player_village.center))
	await frames(2)
	await tap(center(button))
	await tap(on_screen(game.player_village.center))
	check(game.pending_tile == game.player_village.center and hud._place_build.disabled and hud._mode_label.text != "", "a spot it can't go: Build is off, the hint says why (%s)" % hud._mode_label.text)
	await tap(on_screen(game.player_village.center))
	check(game.mode == Game.Mode.BUILD, "tapping it again builds nothing")
	await tap(center(bar.get_child(1)))
	check(game.mode == Game.Mode.NONE and not bar.visible, "its ✕ cancels")


func _drag() -> void:
	print("-- dragging from the Build tab")
	for finger in [false, true]:
		await use_touch(finger)
		await open_build_tab()
		var taken: Array[Vector2i] = []
		for b in game.player_village.buildings():
			taken.append(b.tile)
		var t := spot("tower", taken)
		game.camera.focus(Iso.to_world(t))
		await frames(2)
		var to := on_screen(t) + (Vector2(0, Game.DRAG_LIFT) if finger else Vector2.ZERO)
		var n := count("tower")
		await drag(center(hud._build_buttons["tower"]), to)
		var how := "a finger (the building shows above it)" if finger else "a mouse"
		check(built_at("tower", t) and count("tower") == n + 1, "%s: dragged onto the map and let go, it's built there %s" % [how, str(t)])
		check(game.mode == Game.Mode.NONE and not game.build_drag, "%s: and build mode ends" % how)
	await use_touch(false)
	await open_build_tab()
	var n2 := count("tower")
	var b: Button = hud._build_buttons["tower"]
	var map_pos := Vector2(300, 400)
	mouse(center(b), true)
	await frames(1)
	for i in range(1, 6):
		motion(center(b).lerp(map_pos, i / 5.0))
		await frames(1)
	check(game.mode == Game.Mode.BUILD and game.build_drag, "while dragged, it's being placed")
	for i in range(1, 6):
		motion(map_pos.lerp(center(b), i / 5.0))
		await frames(1)
	mouse(center(b), false)
	await frames(2)
	check(count("tower") == n2 and game.mode == Game.Mode.NONE, "let go over the sidebar: put away")
	var inside := center(b) + Vector2(0, 30)
	await drag(center(b), inside)
	check(game.mode == Game.Mode.NONE and count("tower") == n2, "a drag inside the sidebar (scrolling) doesn't pick it")


func _back_button() -> void:
	print("-- Android's back button")
	game.begin_build("farm")
	check(not get_tree().quit_on_go_back, "while placing, back doesn't quit")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.mode == Game.Mode.NONE, "back cancels placing")
	check(get_tree().quit_on_go_back, "and quits as before once nothing is being placed")


## Every control under `n` that isn't a button lets the mouse through; buttons pass it on.
func _blockers(n: Node, out: Array[String]) -> Array[String]:
	for k in n.get_children():
		if k is Control and k.is_visible_in_tree():
			var f: int = k.mouse_filter
			if (k is BaseButton and f != Control.MOUSE_FILTER_PASS) or (not k is BaseButton and f == Control.MOUSE_FILTER_STOP):
				out.append("%s %s" % [k.get_class(), k.name])
		_blockers(k, out)
	return out


func sheet_h() -> float:
	return -hud._sidebar.offset_top


## Drags the handle (or `at`) by `dy` px in `steps` frames, then lets go.
func drag_handle(dy: float, steps: int, at := Vector2(-1, -1)) -> void:
	var from := center(hud._sheet_handle) if at == Vector2(-1, -1) else at
	mouse(from, true)
	await frames(1)
	for i in range(1, steps + 1):
		motion(from + Vector2(0, dy * i / steps))
		await frames(1)
	mouse(from + Vector2(0, dy), false)
	await frames(12)  # (it glides into place)


func _sheet() -> void:
	print("-- the portrait sheet")
	game.cancel_mode()
	await use_touch(true)
	for sz in [Vector2i(400, 640), Vector2i(720, 1280), Vector2i(600, 800)]:
		get_window().size = sz
		get_viewport().size = sz
		await frames(4)
		hud.set_dock_open(true)
		for tab in ["build", "village", "army"]:
			hud.show_tab(tab)
			await frames(3)
			var vh := get_viewport().get_visible_rect().size.y
			check(hud.is_portrait() and sheet_h() <= vh * Hud.SHEET_MAX + 0.5, "%dx%d %s: the open sheet takes at most half the screen (%.0f of %.0f px)" % [sz.x, sz.y, tab, sheet_h(), vh])
			var blocking := _blockers(hud._sheet_scroll, [] as Array[String])
			check(blocking.is_empty(), "%s: a finger scrolls it from anywhere (nothing stops the drag: %s)" % [tab, ", ".join(blocking)])
	hud.show_tab("build")
	# A page longer than the screen (e.g. many units in the reserve): capped, it scrolls.
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(0, 1500)
	hud._tab_pages["build"].add_child(filler)
	await frames(4)
	var vh := get_viewport().get_visible_rect().size.y
	var sc := hud._sheet_scroll
	var long: float = sc.get_child(0).get_combined_minimum_size().y
	check(absf(sheet_h() - vh * Hud.SHEET_MAX) < 1.0 and long > sc.size.y, "a page taller than that: the sheet stops at half the screen (%.0f px), its entries scroll (%.0f of %.0f px)" % [sheet_h(), sc.size.y, long])
	check(filler.mouse_filter == Control.MOUSE_FILTER_IGNORE, "what's added later lets the finger through too")
	sc.scroll_vertical = 10000
	await frames(2)
	check(sc.scroll_vertical > 0, "and it scrolls (%d px)" % sc.scroll_vertical)
	filler.queue_free()
	await frames(4)
	sc.scroll_vertical = 0
	# A press on an entry's button that turns into a scroll is no tap.
	var b: Button = hud._build_buttons["farm"]
	hud.scroll_to(b)
	await frames(2)
	var p := center(b)
	mouse(p, true)
	await frames(1)
	for i in range(1, 6):
		motion(p + Vector2(0, -6.0 * i))
		await frames(1)
	for i in range(1, 6):
		motion(p + Vector2(0, -30.0 + 6.0 * i))
		await frames(1)
	mouse(p, false)
	await frames(2)
	check(game.mode == Game.Mode.NONE, "scrolled on the farm's button and let go on it: it isn't picked")
	await tap(center(b))
	check(game.mode == Game.Mode.BUILD and game.build_kind == "farm", "a plain tap still picks it")
	game.cancel_mode()
	await frames(2)
	# The handle: the sheet follows the finger; a flick or the nearer end decides.
	hud.set_dock_open(false)
	await frames(3)
	var lo := sheet_h()
	var from := center(hud._sheet_handle)
	mouse(from, true)
	await frames(1)
	for i in range(1, 11):
		motion(from + Vector2(0, -8.0 * i))
		await frames(1)
	check(absf(sheet_h() - (lo + 80.0)) < 2.0 and hud._sheet_scroll.visible, "dragging the handle up, the sheet follows the finger (%.0f -> %.0f px)" % [lo, sheet_h()])
	for i in range(1, 11):
		motion(from + Vector2(0, -80.0 + 6.0 * i))
		await frames(1)
	mouse(from + Vector2(0, -20.0), false)
	await frames(12)
	check(not hud.dock_open() and absf(sheet_h() - lo) < 1.0, "let go slowly, not far up: it slides back closed")
	await drag_handle(-hud._sheet_open_height() * 0.7, 40)
	check(hud.dock_open() and absf(sheet_h() - hud._sheet_open_height()) < 1.0, "dragged most of the way up: it opens (%.0f px)" % sheet_h())
	await drag_handle(60.0, 3)
	check(not hud.dock_open(), "a quick flick down: it closes")
	await drag_handle(-60.0, 3)
	check(hud.dock_open(), "a quick flick up: it opens")
	await drag_handle(60.0, 3)
	hud.set_dock_open(true)  # (at once, while it's still gliding shut)
	await frames(12)
	check(hud.dock_open() and absf(sheet_h() - hud._sheet_open_height()) < 1.0, "opened while gliding shut: it stays open")
	await tap(center(hud._sheet_handle))
	check(not hud.dock_open(), "a tap on the handle still closes it")
	await tap(center(hud._sidebar_toggle))
	check(hud.dock_open(), "and the button beside the tabs still opens it")
	# The tabs, the gaps between them and that button drag it too; a tap stays a tap.
	hud.show_tab("build")
	await frames(2)
	var village: Button = hud._tab_buttons["village"]
	await drag_handle(hud._sheet_open_height(), 30, center(village))
	check(not hud.dock_open() and hud._current_tab == "build", "a tab dragged down closes it, and doesn't switch to Village")
	await drag_handle(-hud._sheet_open_height() * 0.7, 30, center(village))
	check(hud.dock_open() and hud._current_tab == "build" and absf(sheet_h() - hud._sheet_open_height()) < 1.0, "dragged up: it opens, still on Build")
	await tap(center(village))
	check(hud._current_tab == "village" and hud.dock_open(), "a tap on a tab switches it")
	var b_rect := (hud._tab_buttons["build"] as Control).get_global_rect()
	var gap := Vector2(b_rect.end.x + 3.0, b_rect.get_center().y)
	check(not b_rect.has_point(gap) and not village.get_global_rect().has_point(gap) and hud._tabs_row.get_global_rect().has_point(gap), "(a spot between two tabs)")
	await drag_handle(60.0, 3, gap)
	check(not hud.dock_open(), "the gap between the tabs: a flick down closes it")
	b_rect = (hud._tab_buttons["build"] as Control).get_global_rect()  # (closed, the tabs sit lower)
	await drag_handle(-60.0, 3, Vector2(b_rect.end.x + 3.0, b_rect.get_center().y))
	check(hud.dock_open(), "and a flick up opens it")
	var toggle := center(hud._sidebar_toggle)
	await drag_handle(hud._sheet_open_height() * 0.7, 30, toggle)
	check(not hud.dock_open(), "the open / close button dragged down: closed")
	await drag_handle(-hud._sheet_open_height() * 0.2, 30, center(hud._sidebar_toggle))
	check(not hud.dock_open() and absf(sheet_h() - hud._handle_and_tabs_height()) < 1.0, "dragged up only a little and slowly: back closed (not tapped open)")
	await tap(center(hud._sidebar_toggle))
	check(hud.dock_open(), "a tap on it opens at once")
	get_window().size = Vector2i(1280, 720)
	get_viewport().size = Vector2i(1280, 720)
	await use_touch(false)
	await frames(3)
