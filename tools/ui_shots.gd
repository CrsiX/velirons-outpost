extends Node
## Screenshots of the UI on a real display, for looking at the layout (headless
## runs can't render): the title screen, the map editor (both views, layers,
## tools, inspector, dialogs, the picker, portrait), the co-op lobby with a map
## file, and a game on a map with an abandoned village.
##
##   DISPLAY=:0 godot --path . res://tools/ui_shots.tscn -- --out=/some/dir [--only=editor] [--max]
##
## `--max`: the window maximised (the display's size) instead of 1280x720 for
## the landscape pictures; portrait is always 540x960.
##
## `--cutout=l,t,r,b`: pretend the screen has a camera cutout (unusable edges
## in canvas units, Layout.force_insets), drawn black like the real thing;
## the game then also shows the library and a portrait picture (cutout on top).
##
## (A scene, not a --script: config.gd needs the autoloads.) Each picture is
## <out>/<nn>_<name>.png.

var out := ""
var only := ""
var maximize := false
var cutout := Vector4.ZERO
var _cut_layer: CanvasLayer
var _n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		if a == "--max":
			maximize = true
		if a.begins_with("--cutout="):
			var v := a.trim_prefix("--cutout=").split_floats(",")
			if v.size() == 4:
				cutout = Vector4(v[0], v[1], v[2], v[3])
	if out == "":
		printerr("usage: -- --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	if cutout != Vector4.ZERO:
		_show_cutout(cutout)
	_run.call_deferred()


## The fake cutout: Layout keeps the UI clear of it, a black bar shows where.
func _show_cutout(v: Vector4) -> void:
	Layout.force_insets(v)
	if _cut_layer == null:
		_cut_layer = CanvasLayer.new()
		_cut_layer.layer = 128
		add_child(_cut_layer)
		var c := Control.new()
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func() -> void:
			var r := c.get_rect()
			var ins := Layout.insets
			for b in [Rect2(0, 0, ins.x, r.size.y), Rect2(0, 0, r.size.x, ins.y), Rect2(r.size.x - ins.z, 0, ins.z, r.size.y), Rect2(0, r.size.y - ins.w, r.size.x, ins.w)]:
				if b.has_area():
					c.draw_rect(b, Color(0, 0, 0, 0.85)))
		c.resized.connect(c.queue_redraw)
		_cut_layer.add_child(c)
	_cut_layer.get_child(0).queue_redraw()


func _run() -> void:
	await _landscape()
	if only in ["", "title"]:
		await _title()
	if only in ["", "editor"]:
		await _editor()
	if only in ["", "lobby"]:
		await _lobby()
	if only in ["", "game"]:
		await _game()
	print("done: %d pictures in %s" % [_n, out])
	get_tree().quit(0)


## Landscape: maximised with --max, else 1280x720.
func _landscape() -> void:
	if maximize:
		get_window().mode = Window.MODE_MAXIMIZED
		await _frames(20)
		print("window %s" % str(get_window().size))
	else:
		await _size(Vector2i(1280, 720))


func _size(s: Vector2i) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = s
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_n += 1
	img.save_png(out.path_join("%02d_%s.png" % [_n, name]))
	print("shot %s" % name)


## A map file to show: two villages on 100x100, saved under your maps.
func _sample_map() -> MapData:
	var m := MapGenerator.generate(4242, 2, "temperate", 100)
	m.meta = {"name": "Shot map", "author": "ui_shots", "description": "Two villages for the pictures.", "origin": {"generator_seed": 4242, "edited": false, "game_version": ""}}
	m = MapJson.read(MapJson.write(m))["map"]
	MapLibrary.save(m, MapLibrary.user_dir().path_join("shot-map.json"))
	return m


func _title() -> void:
	var t: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await _frames(30)
	await shot("title_main")
	Settings.custom_map = _sample_map()
	Settings.custom_village = 1
	t.show_page(t._sp_page)
	t._update_sp_buttons()
	await _frames(10)
	await shot("title_singleplayer_custom")
	Settings.custom_map = null
	Settings.map_type = "random"
	t._update_sp_buttons()
	t._cycle_map()
	t.picker.refresh(MapLibrary.user_dir().path_join("shot-map.json"))
	await _frames(10)
	await shot("title_picker")
	t.picker.close()
	t.queue_free()
	await _frames(3)


func _editor() -> void:
	_sample_map()
	var ed: MapEditor = load("res://scenes/map_editor.tscn").instantiate()
	add_child(ed)
	await _frames(10)
	var r := MapLibrary.load_file(MapLibrary.user_dir().path_join("shot-map.json"))
	ed.set_map(r["map"], MapLibrary.user_dir().path_join("shot-map.json"), false)
	ed.camera.zoom = Vector2(0.35, 0.35)
	await _frames(10)
	await shot("editor_iso")
	ed.layers["slices"] = true
	ed.layers["spawns"] = true
	ed.layers["rings"] = true
	ed.layers["flow"] = 0
	ed.redraw_layers()
	ed.ui.refresh()
	await _frames(5)
	await shot("editor_iso_layers")
	ed.layers["flow"] = -1
	ed.layers["zones"] = true
	ed.layers["passable"] = true
	ed.redraw_layers()
	await _frames(5)
	await shot("editor_iso_zones_passable")
	ed.layers["zones"] = false
	ed.layers["passable"] = false
	ed.redraw_layers()
	ed.toggle_view()
	await _frames(5)
	await shot("editor_plan")
	ed.camera.zoom = Vector2(0.55, 0.55)
	ed.view_tile(ed.map.villages[0]["center"])
	ed.layers["grid"] = true
	ed.redraw_layers()
	await _frames(5)
	await shot("editor_plan_zoomed_grid")
	ed.layers["grid"] = false
	ed.redraw_layers()
	ed.toggle_view()
	ed.camera.zoom = Vector2(0.8, 0.8)
	ed.view_tile(ed.map.villages[0]["center"])
	ed.ui.set_tool("terrain")
	ed.hover = ed.map.villages[0]["center"] + Vector2i(8, 2)
	ed._redraw_pointer()
	await _frames(5)
	await shot("editor_terrain_tool")
	var oi := -1
	for i in ed.map.objects.size():
		if ed.map.objects[i]["kind"] == "treasure":
			oi = i
			break
	ed.ui.set_tool("look")
	ed.select({"type": "object", "index": oi})
	ed.view_tile(ed.map.objects[oi]["tile"])
	await _frames(5)
	await shot("editor_treasure_inspector")
	ed.select({"type": "village", "index": 0})
	ed.view_tile(ed.map.villages[0]["center"])
	await _frames(5)
	await shot("editor_village_inspector")
	ed.ui.set_tool("object")
	await _frames(3)
	await shot("editor_object_tool")
	ed.ui.show_new()
	await _frames(5)
	await shot("editor_new_dialog")
	ed.ui.close_dialog()
	ed.ui.show_properties(false)
	await _frames(5)
	await shot("editor_properties")
	ed.ui.close_dialog()
	ed.ui.show_play()
	await _frames(5)
	await shot("editor_play_dialog")
	ed.ui.close_dialog()
	ed.ui.picker.open(false, "Open a map", "Open")
	await _frames(8)
	await shot("editor_open_picker")
	ed.ui.picker.close()
	await _size(Vector2i(540, 960))
	await _frames(10)
	ed.ui.set_tool("terrain")
	await _frames(5)
	await shot("editor_portrait_tools")
	ed.ui._tab = "info"
	ed.ui._fit()
	await _frames(5)
	await shot("editor_portrait_info")
	await _landscape()
	ed.queue_free()
	await _frames(3)


func _lobby() -> void:
	var m := _sample_map()
	Net.host("Shothost", 0)
	Net.set_custom_map(m)
	var t: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await _frames(20)
	t.show_page(t.mp_menu)
	t.mp_menu.refresh()
	await _frames(15)
	await shot("lobby_custom_map")
	Net.leave()
	t.queue_free()
	await _frames(3)


func _game() -> void:
	var m := _sample_map()
	Settings.custom_map = m
	Settings.custom_village = 1
	Settings.editor_play = true
	var g: Game = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _frames(60)
	g.camera.focus(Iso.tile_to_world(m.villages[0]["center"]))
	g.camera.zoom = Vector2(0.6, 0.6)
	g.fog.reveal_all()
	await _frames(10)
	await shot("game_abandoned_village")
	for b in g.world.buildings:
		if b.has_meta("abandoned") and b is Hut:
			g.select(b)
			break
	await _frames(5)
	await shot("game_abandoned_hut_info")
	g.deselect()
	g.hud.open_settings()
	await _frames(5)
	await shot("game_settings_back_to_editor")
	g.hud.close_settings()
	if cutout != Vector4.ZERO:
		g.hud.open_library()
		await _frames(5)
		await shot("game_cutout_library")
		g.hud.library.close()
		await _size(Vector2i(540, 960))
		_show_cutout(Vector4(0, cutout.x + cutout.z, 0, 0))  # (turned upright: the camera on top)
		await _frames(10)
		await shot("game_cutout_portrait")
		_show_cutout(cutout)
		await _landscape()
	Settings.editor_play = false
	Settings.custom_map = null
	g.queue_free()
	await _frames(3)
