extends Node
## Screenshots of the UI on a real display, for looking at the layout (headless
## runs can't render): the title screen, the map editor (both views, layers,
## tools, inspector, dialogs, the picker, portrait), the co-op lobby with a map
## file, a game on a map with an abandoned village, (`--only=swap`)
## dragging stationed units onto each other to swap them (mouse in landscape,
## real touch events in portrait), and (`--only=saves`) saving and loading:
## the settings with Save / Load, the save page, Continue, the save list (in
## landscape and portrait), and (`--only=siege`) building HP: hurt, devastated
## and upgraded walls, gates and buildings, their panels, a repair under way,
## goblins hitting a gate, the library's gate entry and the statistics, and
## (`--only=scenario`) scenario 1: the campaign page, the intro cutscene, the
## walk home, the arrival, the cards and objectives, the outro and the end
## (landscape, and the intro and a card in portrait).
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
	if only in ["", "swap"]:
		await _swap()
	if only in ["", "saves"]:
		await _saves()
	if only in ["", "siege"]:
		await _siege()
	if only in ["", "scenario"]:
		await _scenario()
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
	ed.ui.set_tool("slice")
	await _frames(3)
	await shot("editor_slice_tool")
	ed.ui.set_panel_open(true, false)
	ed.ui.set_panel_open(false, false)
	await _frames(3)
	await shot("editor_panels_folded")
	ed.ui.set_panel_open(true, true)
	ed.ui.set_panel_open(false, true)
	var oi := -1
	for i in ed.map.objects.size():
		if ed.map.objects[i]["kind"] == "treasure":
			oi = i
			break
	ed.ui.set_tool("file")
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
	await _frames(3)
	await shot("editor_portrait_folded")
	ed.ui._on_tab_pressed("tools")
	await _frames(5)
	await shot("editor_portrait_tools")
	ed.ui.set_tool("file")
	await _frames(5)
	await shot("editor_portrait_file")
	ed.ui._on_tab_pressed("info")
	await _frames(5)
	await shot("editor_portrait_info")
	ed.ui._on_tab_pressed("info")
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


# --- saving and loading ---------------------------------------------------------------

func _saves() -> void:
	SaveGame.dir_override = "user://ui_shots_saves"
	var g: Game = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	await _frames(60)
	g.save_named("Shot village")
	g.hud.open_settings()
	await _frames(5)
	await shot("saves_settings")
	g.hud._show_save(true)
	await _frames(5)
	await shot("saves_save_page")
	g.hud.close_settings()
	g.queue_free()
	await _frames(3)
	for portrait in [false, true]:
		if portrait:
			await _size(Vector2i(540, 960))
		var t: TitleScreen = load("res://scenes/title.tscn").instantiate()
		add_child(t)
		await _frames(30)
		t.show_page(t._sp_page)
		t._update_sp_buttons()
		await _frames(10)
		await shot("saves_title_singleplayer" + ("_portrait" if portrait else ""))
		t.save_list.choose(false, func(_p: String) -> void: pass)
		await _frames(10)
		await shot("saves_list" + ("_portrait" if portrait else ""))
		t.save_list.close()
		t.queue_free()
		await _frames(3)
	await _landscape()
	for f in DirAccess.get_files_at(SaveGame.dir()):
		DirAccess.remove_absolute(SaveGame.dir().path_join(f))
	SaveGame.dir_override = ""


# --- swapping stationed units --------------------------------------------------------

var _sg: Game


func _swap() -> void:
	_sg = load("res://scenes/main.tscn").instantiate()
	_sg.map_seed = 4242
	add_child(_sg)
	await _frames(30)
	for k in Config.LOCKED:
		_sg.unlocks[k] = true
	_sg.fog.reveal_all()
	_sg.waves.countdown = 99999.0
	_sg.waves.hold = true
	var v := _sg.player_village
	var towers: Array = _sg.world.buildings.filter(func(b: Building) -> bool: return b is Tower and b.complete and b.village == v)
	towers.sort_custom(func(a: Tower, b: Tower) -> bool: return a.tile.y < b.tile.y or (a.tile.y == b.tile.y and a.tile.x < b.tile.x))
	var t1: Tower = towers[0]  # the two top wall towers
	var t2: Tower = towers[1]
	var t3: Tower = towers[2]
	_sg.economy.add("gold", 5000)
	_sg.economy.add("materials", 2000)
	var gate: Vector2i = v.gates.filter(func(g: Vector2i) -> bool: return g.y < v.center.y)[0]
	var bar := _sg.construction.place("barracks", _free_spot("barracks", gate + Vector2i(0, -4)))
	bar.progress = 1.0
	bar.finish()
	var mage := _sg.army.recruit("apprentice")
	_sg.army.upgrade(mage)
	_sg.army.upgrade(mage)
	_sg.army.upgrade(mage, "healing_mage")
	var a1 := _sg.army.recruit("archer")
	var a2 := _sg.army.recruit("archer")
	var aco := _sg.army.recruit("acolyte")
	var sb := _sg.army.recruit("shield_bearer")
	_sg.army.station(a1, t1)
	_sg.army.station(a2, t2)
	_sg.army.station(mage, t3)
	_sg.army.station(aco, bar)
	Engine.time_scale = 8.0
	for i in 600:
		await get_tree().process_frame
		if t1.garrison and t2.garrison and t3.garrison and bar.slots[0] != null:
			break
	Engine.time_scale = 1.0
	_sg.camera.focus((t1.position + t2.position + bar.position) / 3.0)
	_sg.camera.zoom = Vector2(0.9, 0.9)
	await _frames(10)
	await shot("swap_start")
	# Archer onto archer (tower to tower): two curved arrows.
	await _mdrag(_fig(a1), _fig(a2))
	await shot("swap_tower_tower")
	_mouse(_fig(a2), false)
	await _frames(3)
	Engine.time_scale = 8.0
	for i in 600:
		await get_tree().process_frame
		if t1.garrison == a2 and t2.garrison == a1:
			break
	Engine.time_scale = 1.0
	await _frames(5)
	# Archer onto the acolyte in the (full) barracks, pointer on the yard, not the figure.
	await _mdrag(_fig(a2), _win(_sg.camera.world_to_screen(bar.position)))
	await shot("swap_tower_barracks")
	_mouse(_win(_sg.camera.world_to_screen(bar.position)), false)
	await _frames(3)
	Engine.time_scale = 8.0
	for i in 600:
		await get_tree().process_frame
		if t1.garrison == aco and bar.slots[0] == a2:
			break
	Engine.time_scale = 1.0
	print("after: t1 %s t2 %s bar %s" % [t1.garrison.label() if t1.garrison else "-", t2.garrison.label() if t2.garrison else "-", bar.slots[0].label() if bar.slots[0] else "-"])
	await _frames(5)
	await shot("swap_done")
	# Shield bearer in barracks onto the healing mage on a tower: no swap.
	_sg.army.unstation(bar.slots[0])
	for i in 600:
		await get_tree().process_frame
		if bar.free_slot() >= 0:
			break
	_sg.army.station(sb, bar)
	Engine.time_scale = 8.0
	for i in 600:
		await get_tree().process_frame
		if bar.slots[0] == sb:
			break
	Engine.time_scale = 1.0
	_sg.camera.focus((t3.position + bar.position) / 2.0)
	await _frames(5)
	await _mdrag(_fig(sb), _fig(mage))
	await shot("swap_refused_shield_on_mage")
	_mouse(_fig(mage), false)
	await _frames(3)
	print("refused: sb on %s, mage on %s" % [sb.post.label(), mage.post.label()])
	# Portrait phone, real touch events.
	await _size(Vector2i(540, 960))
	_sg.camera.focus((t1.position + t2.position) / 2.0)
	await _frames(10)
	var tower_a: MilitaryUnit = t1.garrison
	var tower_b: MilitaryUnit = t2.garrison if t2.garrison else t3.garrison
	await _tdrag(_fig(tower_a), _fig(tower_b))
	await shot("swap_portrait_touch")
	_touch(_fig(tower_b), false)
	await _frames(3)
	print("touch: %s -> %s, %s -> %s" % [tower_a.label(), tower_a.post.label(), tower_b.label(), tower_b.post.label()])
	Engine.time_scale = 8.0
	for i in 600:
		await get_tree().process_frame
		if tower_a.state == MilitaryUnit.State.STATIONED and tower_b.state == MilitaryUnit.State.STATIONED:
			break
	Engine.time_scale = 1.0
	await _frames(5)
	await shot("swap_portrait_after")
	await _landscape()
	_sg.queue_free()
	await _frames(3)


func _free_spot(kind: String, near: Vector2i) -> Vector2i:
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := near + Vector2i(dx, dy)
				if _sg.construction.placement_error(kind, t) == "":
					return t
	return near


## Where `u`'s figure is, in window pixels (what Input events carry; the
## viewport is scaled in portrait).
func _fig(u: MilitaryUnit) -> Vector2:
	return _win(_sg.camera.world_to_screen(_sg._figure_pos(u)))


func _win(vp: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * vp


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _mdrag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	await _frames(2)
	for i in range(1, 13):
		var e := InputEventMouseMotion.new()
		e.position = from.lerp(to, i / 12.0)
		e.global_position = e.position
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(e)
		await _frames(2)
	await _frames(4)


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = pos
	Input.parse_input_event(e)


func _tdrag(from: Vector2, to: Vector2) -> void:
	_touch(from, true)
	await _frames(2)
	var last := from
	for i in range(1, 13):
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = from.lerp(to, i / 12.0)
		e.relative = e.position - last
		last = e.position
		Input.parse_input_event(e)
		await _frames(2)
	await _frames(4)


# --- building HP and sieges (docs/siege-design.md) ----------------------------------------

func _siege() -> void:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.map_seed = 4242
	add_child(g)
	await _frames(30)
	g.fog.reveal_all()
	g.waves.countdown = 99999.0
	g.waves.hold = true
	var v := g.player_village
	g.economy.add("materials", 2000)
	g.economy.add("gold", 2000)
	for t in g.world.towers():
		if t.garrison:
			g.army.unstation(t.garrison)
	var gates: Array[Vector2i] = v.gates.duplicate()
	gates.sort_custom(MapData.row_order)
	var pieces := func(at: Vector2i) -> Building: return g.map.building_at(at) as Building
	# The top gate hurt, the left gate at level 3, a wall at level 2, a wall
	# beside the right gate broken, a corner tower broken.
	var top: Building = pieces.call(gates[0])
	top.take_damage(45.0)
	var left: Building = pieces.call(gates[1])
	left.level = 3
	left.hp = left.max_hp()
	left.refresh()
	var right: Building = pieces.call(gates[2])
	for d in [Vector2i(0, 1), Vector2i(0, -1)]:
		var w: Building = pieces.call(right.tile + d)
		if w and w.kind == "wall":
			w.take_damage(1e6)
			break
	for d in [Vector2i(0, 1), Vector2i(0, -1)]:
		var w: Building = pieces.call(left.tile + d)
		if w and w.kind == "wall":
			w.level = 2
			w.hp = w.max_hp()
			w.refresh()
			break
	var corners: Array = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower")
	corners.sort_custom(func(a: Building, b: Building) -> bool: return MapData.row_order(a.tile, b.tile))
	(corners[3] as Building).take_damage(1e6)
	(corners[0] as Building).take_damage(120.0)
	# Outside: the farm and a new watchtower devastated, a camp hurt.
	var tower := g.construction.place("tower", _free_spot_in(g, "tower", v.center + Vector2i(5, -1)))
	tower.progress = tower.build_time
	g.construction.complete(tower)
	tower.take_damage(1e6)
	for b in v.buildings():
		if b is Farm:
			b.take_damage(1e6)
		elif b is WorkerCamp:
			b.take_damage(20.0)
	await _frames(5)
	g.camera.focus(Iso.tile_to_world(v.center))
	g.camera.zoom = Vector2(0.85, 0.85)
	await _frames(10)
	await shot("siege_village")
	g.select(top)
	await _frames(5)
	await shot("siege_gate_hurt_panel")
	g.command("repair", {"building": top.nid})
	await _frames(70)
	g.select(top)
	await _frames(5)
	await shot("siege_gate_repairing")
	g.select(corners[3])
	await _frames(5)
	await shot("siege_corner_devastated_panel")
	g.select(left)
	await _frames(5)
	await shot("siege_gate_level3_panel")
	g.select(tower)
	await _frames(5)
	await shot("siege_watchtower_devastated_panel")
	g.deselect()
	# Goblins at the top gate (at level 3 now: they hit it a long while).
	await _frames(400)
	top.level = 3
	top.hp = top.max_hp()
	top.refresh()
	for b in v.buildings():  # (no other way in: they have to break the gate)
		if (b is StaticPiece or b.kind == "wall_tower") and b.devastated:
			b.set_devastated(false)
			b.hp = b.max_hp()
	var road := gates[0]
	var seen := {road: true}
	for i in 7:
		for n in MapData.neighbors4(road):
			if g.map.is_road(n) and not seen.has(n) and not g.map.in_village(n):
				seen[n] = true
				road = n
				break
	for k in 4:
		g.waves._spawn({"kind": "goblin" if k < 3 else "ork", "spawn": g.map.edge_spawns[0], "hp_scale": 50.0, "village": v})
		var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
		var at := Vector2(road) + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		e.set_grid_pos(at)
		var route := g.world.pathing.enemy_route(road, RandomNumberGenerator.new(), -1)
		var pts := PackedVector2Array([at])
		for t in route:
			pts.append(Vector2(t))
		e.follow(pts)
	Engine.time_scale = 3.0
	await _frames(110)
	Engine.time_scale = 1.0
	g.camera.focus(Iso.tile_to_world(gates[0]))
	g.camera.zoom = Vector2(1.2, 1.2)
	await _frames(10)
	await shot("siege_goblins_at_gate")
	g.select(top)
	await _frames(5)
	await shot("siege_gate_under_attack_panel")
	g.deselect()
	g.hud.open_library("buildings")
	await _frames(10)
	await shot("siege_library_buildings")
	g.hud.library.close()
	g.waves.wave = 3
	g.hud.open_stats("summary")
	await _frames(10)
	await shot("siege_stats_summary")
	g.hud.stats_screen.close()
	# Portrait, with a panel.
	await _size(Vector2i(540, 960))
	g.camera.focus(Iso.tile_to_world(v.center))
	g.camera.zoom = Vector2(0.7, 0.7)
	g.select(corners[0])
	await _frames(15)
	await shot("siege_portrait_panel")
	g.deselect()
	await _landscape()
	g.queue_free()
	await _frames(3)


func _free_spot_in(g: Game, kind: String, near: Vector2i) -> Vector2i:
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := near + Vector2i(dx, dy)
				if g.construction.placement_error(kind, t) == "":
					return t
	return near


# --- a scenario (docs/scenarios-design.md) -------------------------------------------------

func _scenario() -> void:
	var t: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await _frames(30)
	t.show_page(t._campaign_page)
	await _frames(10)
	await shot("scenario_campaign_page")
	t.queue_free()
	await _frames(3)
	Settings.scenario_next = 1
	var g: Game = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	var sc: ScenarioRunner = null
	for i in 600:
		await _frames(1)
		sc = g.scenario
		if sc and sc.cutscene and sc.cutscene.index >= 3:
			break
	await _frames(70)
	await shot("scenario_intro_title")
	await _cut_to_line(sc, "brenna")
	await shot("scenario_intro_brenna")
	await _cut_to_line(sc, "brenna", "Smoke")
	await _frames(20)
	await shot("scenario_intro_smoke")
	await _size(Vector2i(540, 960))
	await _frames(10)
	await shot("scenario_intro_portrait")
	await _landscape()
	sc.cutscene.skip()
	await _frames(90)
	await shot("scenario_walk_home")
	g.hero.set_grid_pos(Vector2(g.player_village.center))
	g.hero.arrive_home()
	for i in 120:
		await _frames(1)
		if sc.cutscene and sc.cutscene.line != "":
			break
	await _frames(40)
	await shot("scenario_arrival_einar")
	sc.cutscene.skip()
	await _frames(40)
	await shot("scenario_card_huts")
	g.command("rebuild_hut", {"building": g.player_village.huts().filter(func(h: Hut) -> bool: return h.ruined)[0].nid})
	await _frames(120)
	await shot("scenario_card_tower")
	await _size(Vector2i(540, 960))
	await _frames(20)
	await shot("scenario_card_portrait")
	await _landscape()
	g.hud.show_tab("army")
	await _frames(10)
	await shot("scenario_army_tab")
	sc._hints_shown["hurt"] = true
	sc.card.show_hint(str(sc.hints[1]["text"]))
	await _frames(5)
	await shot("scenario_hint")
	sc.card.show_hint("")
	# Straight to the end: the objectives met, the outro.
	var v := g.player_village
	for h: Hut in v.huts():
		if h.ruined:
			h.ruined = false
			h.refresh()
	for b: Building in sc.pieces("gate") + sc.pieces("wall_tower"):
		if b.devastated:
			b.set_devastated(false)
		b.hp = b.max_hp()
	v.population.spawn("gatherer")
	g.waves.wave = 5
	g.waves.hold = true
	for i in 300:
		await _frames(1)
		if sc.cutscene and sc.cutscene.line != "":
			break
	await _frames(30)
	await shot("scenario_outro")
	await _cut_to_line(sc, "pell")
	await _frames(120)
	await shot("scenario_outro_pell")
	sc.cutscene.skip()
	await _frames(30)
	await shot("scenario_complete")
	g.queue_free()
	await _frames(3)
	Settings.scenario_next = 1
	g = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	for i in 600:
		await _frames(1)
		if g.scenario and g.scenario.cutscene:
			break
	g.scenario.cutscene.skip()
	await _frames(10)
	var einar: Civilian = g.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Einar")[0]
	g.population.kill(einar, "from the attack of goblin 2", "enemies")
	await _frames(10)
	await shot("scenario_failed")
	g.queue_free()
	await _frames(3)


## On through the cutscene until `who` says a line (containing `part`).
func _cut_to_line(sc: ScenarioRunner, who: String, part := "") -> void:
	for i in 2000:
		var c := sc.cutscene
		if c == null or not c.running:
			return
		if c.line != "":
			var s: Dictionary = c.steps[c.index]
			if str(s["say"]) == who and (part == "" or c.line.contains(part)):
				await _frames(60)
				return
			c.advance()
			c.advance()
		await _frames(1)
