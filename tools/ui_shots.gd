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
## (landscape, and the intro and a card in portrait; the campaign map: all
## open, a release build's progress with seals, a card, portrait); (`--only=campaign`)
## scenarios 2 and 3: Pell's arrival, his stall and its panel, a talk between
## waves, the Wardline's start, a journal page, a restored ruin and the road;
## (`--only=away`) scenarios 4 and 5: Wenna, the warehouse and the guild
## house, the rival's offer (a choice), a plundering goblin; the empty fort,
## the citadel in its pass, Sigmund found by his tent, a page (the game grey
## behind it), the Legion with its named captains;
## (`--only=exile`) scenarios 6 and 7: Anselm, the field of the fallen, the
## graveyard filling; Fiona at the gate, Brenna's tent, the druids' grove and
## its panel, Fiona's house;
## (`--only=court`) scenarios 8 and 9 (`--only=abbey`: just 9): Lothar under his flag, a crypt and its
## guards, a Legion camp and its panel, the Legion's kinds on a road, Rurik;
## the drowned abbey on its island with the octopus, the harbour and church, the octopus holding a priest, the eldest priest, Lysa coming, the seal struck, the leviathan;
## (`--only=spiders`) a spider mother laying eggs, eggs wobbling and hatching,
## the broken shells, spiderlings at a gate, undead ones, the library, and
## (`--only=undead_spiders`) a spider mother raised by a necromancer, in real
## time: the spell, her first clutch at once, undead eggs hatching, her next
## clutch, an acolyte's holy beams on undead spiderlings, her crumbling, her
## library entry (with the log at Debug; it prints what it sees), and
## (`--only=wrathwood`) a tree waking up under a forester's axe, the living
## tree chasing him, its roots holding the hero, smashing the camp, its log, and the library's Damage tab;
## (`--only=vultures`) vultures; (`--only=riders`) wolves and riders: a wolf
## pack, a goblin raider charging a villager and circling the village, one
## unhorsed by its wolf's corpse, Legion cavalry with its footmen, the mounted
## captains and commanders (a hurt horse's bar), Rhodri on foot, an undead
## horse bolting, and the library's raider and halberdier.
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
	if only in ["", "campaign"]:
		await _campaign()
	if only in ["", "away"]:
		await _away()
	if only in ["", "exile"]:
		await _exile()
	if only in ["", "court"]:
		await _court()
	if only == "abbey":
		await _abbey()
	if only in ["", "crown"]:
		await _crown()
	if only in ["", "spiders"]:
		await _spiders()
	if only in ["", "undead_spiders"]:
		await _undead_spiders()
	if only in ["", "wrathwood"]:
		await _wrathwood()
	if only in ["", "vultures"]:
		await _vultures()
	if only in ["", "riders"]:
		await _riders()
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
	var cm := t.campaign_map
	t.open_campaign()
	await _frames(10)
	await shot("scenario_campaign_map")
	# A release build's view with 1 to 4 completed: only what is open, seals, the route.
	cm.show_all = false
	Campaign.reset_progress()
	for n in [1, 2, 3, 4]:
		Campaign.complete(n)
	cm.open()
	await _frames(10)
	await shot("scenario_campaign_progress")
	cm.show_card(4)
	await _frames(6)
	await shot("scenario_campaign_unrolling")
	await _frames(30)
	await shot("scenario_campaign_card")
	var win := get_window().size
	await _size(Vector2i(540, 960))
	cm.open()
	await _frames(6)
	await shot("scenario_campaign_portrait_unrolling")
	await _frames(30)
	await shot("scenario_campaign_portrait")
	await _size(win)
	Campaign.reset_progress()
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
	if sc.cutscene:
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


## A scenario's game, its intro running (a few frames past its start).
func _scenario_game(n: int) -> Game:
	Settings.scenario_next = n
	var g: Game = load("res://scenes/main.tscn").instantiate()
	add_child(g)
	for i in 600:
		await _frames(1)
		if g.scenario and g.scenario.cutscene and g.scenario.cutscene.line != "":
			break
	return g


func _campaign() -> void:
	var g := await _scenario_game(2)
	var sc := g.scenario
	await _cut_to_line(sc, "pell")
	await shot("campaign_s2_reunion")
	sc.cutscene.skip()
	await _frames(30)
	await shot("campaign_s2_stall_card")
	var spot := sc.spots.by_road("stall", 3, 8, [])
	var b: Building = g.player_village.construction._new_building("stall", spot, true)
	g.player_village.population.assign_worker(b as Workplace, true)
	for i in 400:
		await _frames(1)
		if (b as Stall).is_open():
			break
	(b as Stall).stored = 24.0
	g.camera.focus(b.position)
	g.camera.zoom = Vector2(1.3, 1.3)
	g.select(b)
	await _frames(20)
	await shot("campaign_s2_stall_panel")
	g.deselect()
	sc.spec.on_wave_finished(sc, 1)
	for i in 300:
		await _frames(1)
		if sc.cutscene and sc.cutscene.line.contains("Orsin"):
			break
	await _frames(40)
	await shot("campaign_s2_news")
	sc.cutscene.skip()
	g.queue_free()
	await _frames(3)
	g = await _scenario_game(3)
	sc = g.scenario
	await _cut_to_line(sc, "pell", "There")
	await shot("campaign_s3_first_ruin")
	sc.cutscene.skip()
	await _frames(30)
	await shot("campaign_s3_cards")
	var v := g.player_village
	v.economy.add("materials", 900)
	v.economy.add("gold", 900)
	var site: Dictionary = sc.spec._north_sites(sc)[0]
	var ruin = sc.on_site(site)
	(ruin as RuinedTower).claim(v)
	g.command("restore_ruin", {"ruin": ruin.nid})
	var tower: Building = sc.on_site(site)
	tower.finish_repair()
	tower.repairing = false
	v.construction.queue.erase(tower)
	for i in 120:
		await _frames(1)
		if sc.journal and sc.journal.visible:
			break
	await _frames(10)
	await shot("campaign_s3_journal")
	sc.journal.close_page()
	g.army.recruit("archer")
	g.command("station_unit", {"unit": g.army.reserve()[0].nid, "post": tower.nid})
	var dark: Array[Vector2i] = sc.spec._dark_road(sc)
	for k in 2:
		if dark.size() > 3:
			var t := _free_spot_in(g, "lightstone", dark[dark.size() * (k + 1) / 3])
			if t != Vector2i(-1, -1):
				v.construction._new_building("lightstone", t, true)
	g.fog.reveal(Vector2(tower.tile), 14.0, v.id)
	g.camera.focus(tower.position)
	g.camera.zoom = Vector2(0.55, 0.55)
	await _frames(60)
	await shot("campaign_s3_road")
	g.queue_free()
	await _frames(3)


func _away() -> void:
	var g := await _scenario_game(4)
	var sc := g.scenario
	await _cut_to_line(sc, "wenna", "convoy")
	await shot("away_s4_wenna")
	sc.cutscene.skip()
	await _frames(30)
	var v := g.player_village
	var w: Building = sc.pieces("warehouse")[0]
	g.camera.focus(w.position)
	g.camera.zoom = Vector2(0.9, 0.9)
	await _frames(30)
	await shot("away_s4_warehouse_card")
	g.hero.set_mode(Hero.Mode.REST)
	var gob := g.waves.spawn_at("goblin", g.world.pathing.nearest_road(w.tile), v, 1)
	gob.max_hp = 1e6
	gob.hp = gob.max_hp
	for i in 1200:
		await _frames(1)
		if w.hp < w.max_hp():
			break
	g.select(w)
	await _frames(20)
	await shot("away_s4_warehouse_plundered")
	g.deselect()
	var home: Building = null
	for c in g.population.civilians:
		if c.given_name == "Wenna":
			home = c.hut
	if home:
		g.camera.focus(home.position)
		g.camera.zoom = Vector2(1.3, 1.3)
		g.select(home)
		await _frames(30)
		await shot("away_s4_guild_house")
		g.deselect()
	sc.spec.on_wave_finished(sc, 3)
	for i in 600:
		await _frames(1)
		if sc.cutscene and sc.cutscene.choosing():
			break
		if sc.cutscene and sc.cutscene.line != "":
			sc.cutscene.advance()
			sc.cutscene.advance()
	await _frames(30)
	await shot("away_s4_offer")
	sc.cutscene.choose(1)
	await _frames(10)
	sc.cutscene.skip()
	g.queue_free()
	await _frames(3)
	g = await _scenario_game(5)
	sc = g.scenario
	await _cut_to_line(sc, "pell")
	await shot("away_s5_empty_fort")
	sc.cutscene.skip()
	await _frames(30)
	await shot("away_s5_fort_card")
	g.camera.focus(Iso.to_world(Vector2(g.player_village.center)))
	g.camera.zoom = Vector2(0.9, 0.9)
	await _frames(20)
	await shot("away_s5_citadel")
	g.camera.zoom = Vector2(0.35, 0.35)
	await _frames(20)
	await shot("away_s5_pass")
	g.fog.reveal(Vector2(sc.spec.SIGMUND_TENT), 3.0, g.player_village.id)
	for i in 120:
		await _frames(1)
		if sc.cutscene != null:
			break
	await _cut_to_line(sc, "sigmund")
	await shot("away_s5_sigmund")
	sc.cutscene.skip()
	await _frames(30)
	(sc.spec._evidence(sc)[0] as Treasure).mark_looted()
	for i in 120:
		await _frames(1)
		if sc.journal and sc.journal.visible:
			break
	await _frames(10)
	await shot("away_s5_evidence_page")
	sc.journal.close_page()
	v = g.player_village
	var road := sc.road_in(v.center + Vector2i(0, -40), 9)
	g.hero.set_mode(Hero.Mode.REST)
	if not road.is_empty():
		var at: Vector2i = road[0]
		for k in 3:
			g.waves.spawn_at("legion_footman", at, v, 1)
		var lysa := g.waves.spawn_at("legion_captain", at, v, 1)
		lysa.set_identity("Lysa", "legion_captain_lysa")
		var torben := g.waves.spawn_at("legion_captain", at, v, 1)
		torben.set_identity("Torben", "legion_captain")
		g.fog.reveal(Vector2(at), 6.0, v.id)
		for i in 90:
			await _frames(1)
		lysa.take_damage(lysa.max_hp * 0.2)
		g.camera.focus(lysa.position)
		g.camera.zoom = Vector2(1.4, 1.4)
		await _frames(20)
		await shot("away_s5_legion")
	g.queue_free()
	await _frames(3)


func _exile() -> void:
	var g := await _scenario_game(6)
	var sc := g.scenario
	await _cut_to_line(sc, "anselm", "I bury them")
	await shot("exile_s6_anselm")
	sc.cutscene.skip()
	await _frames(30)
	var cl: Vector2i = sc.spec._clusters(sc)[0]
	g.camera.focus(Iso.to_world(Vector2(cl)))
	g.camera.zoom = Vector2(1.2, 1.2)
	await _frames(30)
	await shot("exile_s6_fallen")
	var gy: Graveyard = sc.pieces("graveyard")[0]
	gy.bury(11, g.hero)
	g.camera.focus(gy.position)
	g.camera.zoom = Vector2(1.1, 1.1)
	g.select(gy)
	await _frames(30)
	await shot("exile_s6_graveyard")
	g.deselect()
	var home: Building = null
	for c in g.population.civilians:
		if c.given_name == "Anselm":
			home = c.hut
	if home:
		g.camera.focus(home.position)
		g.camera.zoom = Vector2(1.3, 1.3)
		await _frames(20)
		await shot("exile_s6_anselms_house")
	g.queue_free()
	await _frames(3)
	g = await _scenario_game(7)
	sc = g.scenario
	await _cut_to_line(sc, "fiona", "camp outside")
	await shot("exile_s7_fiona")
	sc.cutscene.skip()
	await _frames(30)
	g.camera.focus(Iso.to_world(Vector2(sc.spec.tent_tile)))
	g.camera.zoom = Vector2(1.2, 1.2)
	await _frames(20)
	await shot("exile_s7_tent")
	var grove: Building = sc.pieces("grove")[0]
	g.camera.focus(grove.position)
	g.camera.zoom = Vector2(1.2, 1.2)
	g.select(grove)
	await _frames(30)
	await shot("exile_s7_grove")
	g.deselect()
	home = null
	for c in g.population.civilians:
		if c.given_name == "Fiona":
			home = c.hut
	if home:
		g.camera.focus(home.position)
		g.camera.zoom = Vector2(1.3, 1.3)
		await _frames(20)
		await shot("exile_s7_fiona_house")
	g.queue_free()
	await _frames(3)


func _court() -> void:
	var g := await _scenario_game(8)
	var sc := g.scenario
	await _cut_to_line(sc, "lothar", "welcome home")
	await shot("court_s8_lothar")
	sc.cutscene.skip()
	await _frames(30)
	var v := g.player_village
	var crypt := sc.lairs()[0] as MonsterLair
	g.fog.reveal(Vector2(crypt.tile), 5.0, v.id)
	crypt.on_wave(1)
	g.camera.focus(Iso.to_world(Vector2(crypt.tile)))
	g.camera.zoom = Vector2(1.2, 1.2)
	g.select(crypt)
	await _frames(30)
	await shot("court_s8_crypt")
	g.deselect()
	var camp: MonsterCamp = sc.spec._legion_camps(sc)[0]
	g.fog.reveal(Vector2(camp.tile), 5.0, v.id)
	g.camera.focus(Iso.to_world(Vector2(camp.tile)))
	g.select(camp)
	await _frames(30)
	await shot("court_s8_legion_camp")
	g.deselect()
	var road := sc.road_in(v.center + Vector2i(0, 30), 12)
	var at: Vector2i = road[0]
	g.fog.reveal(Vector2(at), 6.0, v.id)
	for k in ["legion_footman", "legion_archer", "legion_guard", "legion_banner", "legion_footman", "legion_champion"]:
		var e := g.waves.spawn_at(k, at, v, 1)
		if k == "legion_champion":
			e.set_identity("Rurik", "")
		await _frames(25)
	g.camera.focus(Iso.to_world(Vector2(road[4])))
	g.camera.zoom = Vector2(1.4, 1.4)
	await _frames(40)
	await shot("court_s8_legion")
	g.queue_free()
	await _frames(3)
	await _abbey()


## Scenario 9 (`--only=abbey`, and with scenario 8 in `court`): the mist, the
## abbey, the harbour and church, the rescue, the eldest priest, Lysa coming,
## the seal struck, the leviathan.
func _abbey() -> void:
	var g := await _scenario_game(9)
	var sc := g.scenario
	await _cut_to_line(sc, "", "Mist on the shore")
	await shot("court_s9_mist")
	sc.cutscene.skip()
	await _frames(30)
	var v := g.player_village
	var ab: Treasure = sc.spec._abbey(sc)
	g.fog.reveal(Vector2(ab.tile), 9.0, v.id)
	g.fog.reveal(Vector2(v.center), 14.0, v.id)
	var octo = sc.mark.get("octopus")
	if octo:
		(octo as Enemy).surface()
	g.camera.focus(Iso.to_world(Vector2(ab.tile)))
	g.camera.zoom = Vector2(0.9, 0.9)
	g.select(ab)
	await _frames(60)
	await shot("court_s9_abbey")
	g.deselect()
	# The village, its church and the harbour with the pier.
	g.camera.focus(Iso.to_world(Vector2(v.center) + Vector2(0, 4)))
	g.camera.zoom = Vector2(0.85, 0.85)
	await _frames(40)
	await shot("court_s9_harbour")
	# The beach: the ferry bell, boats, racks, driftwood; the beacon and gulls by the river's mouth.
	var quay: Vector2i = sc.spec._quay(sc)
	g.fog.reveal(Vector2(quay), 18.0, v.id)
	g.hud.set_dock_open(false)
	g.camera.focus(Iso.to_world(Vector2(quay) + Vector2(1, -1)))
	g.camera.zoom = Vector2(1.0, 1.0)
	await _frames(60)
	await shot("court_s9_beach")
	var beacon: Vector2i = sc.mark.get("beacon", quay)
	g.camera.focus(Iso.to_world(Vector2(beacon)) + Vector2(0, -60))
	await _frames(60)
	await shot("court_s9_beacon")
	g.hud.set_dock_open(true)
	# The rescue: the octopus holds the priest at the quay.
	sc.spec.on_wave_finished(sc, sc.spec.RESCUE_WAVE)
	await _cut_to_line(sc, "", "One of the priests")
	sc.cutscene.skip()
	var p: Resident = sc.spec._priest(sc, false)
	if p:
		p.at_home = false
		p.visible = true
		p.set_grid_pos(Vector2(quay))
	for i in 600:
		await _frames(1)
		if sc.mark.has("grabbed"):
			break
	await _frames(90)
	g.camera.focus(Iso.to_world(Vector2(quay)))
	g.camera.zoom = Vector2(1.2, 1.2)
	await _frames(20)
	await shot("court_s9_rescue")
	for e in g.get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).kind == "octopus_arm":
			(e as Enemy).take_damage(1e9, g.hero)
	await _cut_to_line(sc, "eldest", "You want to know")
	await shot("court_s9_eldest_priest")
	if sc.cutscene:
		sc.cutscene.skip()
	await _frames(10)
	# Wave 6: Lysa at the head of the Legion, seen in the fog on the far shore.
	g.waves.wave = sc.spec.LEGION_WAVES[0] - 1
	g.waves.start_now()
	await _cut_to_line(sc, "", "Out of the mist")
	await shot("court_s9_lysa")
	if sc.cutscene:
		sc.cutscene.skip()
	# The column at the abbey, striking the seal.
	for i in 1200:
		await _frames(1)
		if ab.seal_hp < ab.seal_max * 0.8:
			break
	g.camera.focus(Iso.to_world(Vector2(ab.tile)))
	g.camera.zoom = Vector2(1.0, 1.0)
	await _frames(20)
	await shot("court_s9_seal")
	# The leviathan, risen by the island.
	sc.spec._wake_leviathan(sc, false)
	await _frames(30)
	if sc.cutscene:
		sc.cutscene.skip()
	await _frames(10)
	var lev := sc.named_enemy("Leviathan")
	if lev:
		lev.surface()
		g.camera.focus(lev.position)
		g.camera.zoom = Vector2(1.1, 1.1)
	await _frames(40)
	await shot("court_s9_leviathan")
	g.queue_free()
	await _frames(3)


# --- scenarios 10 and 11: the marshal, the capital, the king ----------------------------------

func _crown() -> void:
	var g := await _scenario_game(10)
	var sc := g.scenario
	await _cut_to_line(sc, "einar")
	await shot("crown_s10_einar")
	sc.cutscene.skip()
	await _frames(30)
	var v := g.player_village
	var road: Array[Vector2i] = sc.spec._north_road(sc)
	var at: Vector2i = road[road.size() - 14]
	g.fog.reveal(Vector2(at), 6.0, v.id)
	var cv := sc.caravan(sc.spec._north_spawn(sc), {"gold": 80})
	cv.progress = float(road.size() - 18)
	for k in ["legion_footman", "legion_banner", "legion_footman", "legion_marshal", "legion_guard"]:
		var e := g.waves.spawn_at(k, at, v, 1)
		if k == "legion_marshal":
			e.set_identity("Halvard", "")
		await _frames(25)
	g.camera.focus(Iso.to_world(Vector2(road[road.size() - 11])))
	g.camera.zoom = Vector2(1.3, 1.3)
	await _frames(40)
	await shot("crown_s10_halvard")
	g.queue_free()
	await _frames(3)
	g = await _scenario_game(11)
	sc = g.scenario
	await _cut_to_line(sc, "", "He smiles")
	await shot("crown_s11_throne")
	sc.cutscene.skip()
	await _frames(30)
	v = g.player_village
	g.fog.reveal(Vector2(v.center), 16.0, v.id)
	g.camera.focus(Iso.to_world(Vector2(v.center) + Vector2(-6, -6)))
	g.camera.zoom = Vector2(0.6, 0.6)
	await _frames(60)
	await shot("crown_s11_city")
	var hall: Treasure = sc.spec._hall(sc)
	g.fog.reveal(Vector2(hall.tile), 9.0, v.id)
	var king := g.waves.spawn_at("legion_king", sc.spawn_near(hall.tile), v, 12)
	king.set_identity("Rhodri", "")
	var lothar := g.waves.spawn_at("legion_champion", sc.spawn_near(hall.tile), v, 12)
	lothar.set_identity("Lothar", "herald")
	await _frames(90)
	g.camera.focus(Iso.to_world(Vector2(hall.tile) + Vector2(1, 3)))
	g.camera.zoom = Vector2(1.0, 1.0)
	g.select(hall)
	await _frames(30)
	await shot("crown_s11_rhodri")
	g.deselect()
	Combat.burst(g, "curse", Iso.to_world(Vector2(hall.tile) + Vector2(1, 3.2)), 3.0)
	await _frames(40)
	await shot("crown_s11_curse")
	sc.play_scene([{"say": "cursed", "text": "..."}])
	await _frames(40)
	await shot("crown_s11_fiona")
	g.queue_free()
	await _frames(3)


# --- the spider mother (docs/enemies-design.md §15b) ----------------------------------------

func _spiders() -> void:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.map_seed = 4242
	g.disable_fog = true
	add_child(g)
	await _frames(30)
	g.fog.reveal_all()
	g.waves.countdown = 99999.0
	g.waves.hold = true
	var v := g.player_village
	for t in g.world.towers():
		if t.garrison:
			g.army.unstation(t.garrison)
	var gate: Vector2i = v.gates[0]
	var road := gate
	var seen := {road: true}
	for i in 9:
		for n in MapData.neighbors4(road):
			if g.map.is_road(n) and not seen.has(n) and not g.map.in_village(n):
				seen[n] = true
				road = n
				break
	var spawn := func(kind: String, at: Vector2, hp_scale: float) -> Enemy:
		g.waves._spawn({"kind": kind, "spawn": g.map.edge_spawns[0], "hp_scale": hp_scale, "village": v})
		var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
		e.set_grid_pos(at)
		var route := g.world.pathing.enemy_route(Vector2i(at.round()), RandomNumberGenerator.new(), -1)
		var pts := PackedVector2Array([at])
		for t in route:
			pts.append(Vector2(t))
		e.follow(pts)
		return e
	# A mother next to an ork and a goblin, for size; she lays a clutch.
	var m: Enemy = spawn.call("spider_mother", Vector2(road), 50.0)
	var ork: Enemy = spawn.call("ork", Vector2(road) + Vector2(0.9, -0.6), 50.0)
	var gob: Enemy = spawn.call("goblin", Vector2(road) + Vector2(-0.6, 0.9), 50.0)
	for e: Enemy in [m, ork, gob]:
		e.speed = 0.0
	(m.behavior as SpiderMotherBehavior).started = true
	(m.behavior as SpiderMotherBehavior)._lay = 0.01
	await _frames(5)
	g.camera.focus(Iso.to_world(m.grid_pos))
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(10)
	await shot("spiders_mother_lays")
	ork.vanish()
	gob.vanish()
	# Wobbling just before they hatch, then the shells and the spiderlings.
	var eggs: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if (node as Enemy).kind == "spider_egg":
			eggs.append(node)
	for e in eggs:
		(e.behavior as EggBehavior).age = float(e.spec()["hatch_time"]) - 0.6
	await _frames(12)
	await shot("spiders_eggs_wobble")
	await _frames(40)
	for node in get_tree().get_nodes_in_group("enemies"):
		if (node as Enemy).kind == "spiderling":
			node.speed = 0.0
	await _frames(20)
	await shot("spiders_hatched_shells")
	# Hurt, with her young gone: she stops and guards a new clutch.
	for node in get_tree().get_nodes_in_group("enemies"):
		if (node as Enemy).kind == "spiderling":
			(node as Enemy).vanish()
	await _frames(30)
	m.take_damage(5.0, null)
	m.take_damage(1.0, g.hero)
	await _frames(10)
	await shot("spiders_mother_guards")
	# Spiderlings breaking the top gate.
	m.vanish()
	for node in get_tree().get_nodes_in_group("enemies"):
		(node as Enemy).vanish()
	await _frames(20)
	var near := gate
	seen = {near: true}
	for i in 2:
		for n in MapData.neighbors4(near):
			if g.map.is_road(n) and not seen.has(n) and not g.map.in_village(n):
				seen[n] = true
				near = n
				break
	for k in 7:
		spawn.call("spiderling", Vector2(near) + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)), 50.0)
	Engine.time_scale = 3.0
	await _frames(90)
	Engine.time_scale = 1.0
	g.camera.focus(Iso.tile_to_world(gate))
	g.camera.zoom = Vector2(1.4, 1.4)
	await _frames(10)
	await shot("spiders_spiderlings_at_gate")
	for node in get_tree().get_nodes_in_group("enemies"):
		(node as Enemy).vanish()
	await _frames(20)
	# A raised mother and her undead clutch.
	var c := g.corpses.spawn("spider_mother", 1, Vector2(road))
	c.hp_scale = 50.0
	var nec: Enemy = spawn.call("necromancer", Vector2(road) + Vector2(0.8, 0.0), 1.0)
	var risen := g.waves.raise_corpse(c, nec)
	nec.vanish()
	risen.speed = 0.0
	risen.decay_rate = 0.0
	await _frames(10)
	g.camera.focus(Iso.to_world(risen.grid_pos))
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(10)
	await shot("spiders_undead_clutch")
	for node in get_tree().get_nodes_in_group("enemies"):
		(node as Enemy).vanish()
	g.hud.open_library("enemies")
	await _frames(10)
	await shot("spiders_library")
	g.hud.library.close()
	g.queue_free()
	await _frames(3)


## Waits `seconds` of game time (the frame delta already counts the time scale).
func _game_wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _undead_spiders() -> void:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.map_seed = 4242
	g.disable_fog = true
	add_child(g)
	await _frames(30)
	g.fog.reveal_all()
	g.waves.countdown = 99999.0
	g.waves.hold = true
	g.events.shown_level = EventLog.Level.DEBUG
	var v := g.player_village
	var h := g.hero  # (out of the way: he'd fight everything)
	h.process_mode = Node.PROCESS_MODE_DISABLED
	h.remove_from_group("melee_defenders")
	h.visible = false
	for t in g.world.towers():
		if t.garrison:
			g.army.unstation(t.garrison)
	var gate: Vector2i = v.gates[0]
	var path: Array[Vector2i] = [gate]
	var seen := {gate: true}
	for i in 12:
		for n in MapData.neighbors4(path.back()):
			if g.map.is_road(n) and not seen.has(n) and not g.map.in_village(n):
				seen[n] = true
				path.append(n)
				break
	var far := path[mini(10, path.size() - 1)]
	var spawn := func(kind: String, at: Vector2, hp_scale: float) -> Enemy:
		g.waves._spawn({"kind": kind, "spawn": g.map.edge_spawns[0], "hp_scale": hp_scale, "village": v})
		var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
		e.set_grid_pos(at)
		var route := g.world.pathing.enemy_route(Vector2i(at.round()), RandomNumberGenerator.new(), -1)
		var pts := PackedVector2Array([at])
		for t in route:
			pts.append(Vector2(t))
		e.follow(pts)
		return e
	var count := func(kind: String) -> Array[Enemy]:
		var out: Array[Enemy] = []
		for node in get_tree().get_nodes_in_group("enemies"):
			if (node as Enemy).kind == kind:
				out.append(node)
		return out
	# An acolyte on a watchtower by the road, nearer the village.
	g.unlocks["acolyte"] = true
	g.economy.add("gold", 500)
	g.economy.add("materials", 500)
	var tw := g.construction.place("tower", _free_spot_in(g, "tower", path[mini(5, path.size() - 1)] + Vector2i(1, 1)))
	tw.progress = tw.build_time
	g.construction.complete(tw)
	var aco := g.army.recruit("acolyte")
	g.army.station(aco, tw)
	# A spider mother killed on the road; a necromancer comes for her corpse.
	var m: Enemy = spawn.call("spider_mother", Vector2(far), 12.0)  # (tough: the acolyte shouldn't kill her before she drains away)
	m.speed = 0.0
	await _frames(5)
	m.take_damage(1e9, null)
	await _frames(20)
	var corpse: Corpse = null
	for c in g.corpses.corpses:
		if c.kind == "spider_mother":
			corpse = c
	print("corpse: %s" % (corpse != null))
	var nec: Enemy = spawn.call("necromancer", Vector2(far) + Vector2(1.2, 0.4), 50.0)
	nec.speed = 0.3
	g.camera.focus(Iso.to_world(Vector2(far)))
	g.camera.zoom = Vector2(1.5, 1.5)
	await _game_wait(1.5)
	var nb := nec.behavior as NecromancerBehavior
	print("necromancer channels: %s" % (nb.corpse == corpse))
	await shot("undead_necromancer_channels")
	# The spell ends: she rises and lays a clutch at once.
	Engine.time_scale = 2.0
	var waited := 0.0
	while count.call("spider_mother").is_empty() and waited < 12.0:
		await _game_wait(0.1)
		waited += 0.1
	print("necromancer alive: %s" % (is_instance_valid(nec) and not nec.dead))
	var risen: Array[Enemy] = count.call("spider_mother")
	var mo: Enemy = risen[0] if not risen.is_empty() else null
	Engine.time_scale = 1.0
	await _frames(10)
	var eggs: Array[Enemy] = count.call("spider_egg")
	print("risen: %s raised=%s hp %.0f/%.0f, eggs %d undead %s, next clutch in %.1f s" % [mo != null, mo.raised if mo else false, mo.hp if mo else 0.0, mo.max_hp if mo else 0.0, eggs.size(), eggs.all(func(e: Enemy) -> bool: return e.undead), (mo.behavior as SpiderMotherBehavior)._lay if mo else -1.0])
	nec.vanish()
	if mo:
		mo.speed = 0.15
		mo.base_speed = 0.15
		g.camera.focus(Iso.to_world(mo.grid_pos))
	await _frames(10)
	await shot("undead_mother_rises_lays")
	# Undead eggs wobble, hatch; undead spiderlings walk to the village.
	await _game_wait(float(Config.ENEMIES["spider_egg"]["hatch_time"]) - 0.8)
	await shot("undead_eggs_wobble")
	await _game_wait(1.2)
	var lings: Array[Enemy] = count.call("spiderling")
	print("hatched: %d spiderlings, undead %s, drain %s" % [lings.size(), lings.all(func(e: Enemy) -> bool: return e.undead), lings.any(func(e: Enemy) -> bool: return e.decay_rate > 0.0)])
	await shot("undead_spiderlings_hatch")
	# The acolyte's beams on undead spiderlings (x2 holy).
	g.camera.focus(Iso.tile_to_world(tw.tile))
	await _game_wait(3.0)
	await shot("undead_acolyte_beams")
	# Her second clutch, 15 s after rising.
	print("before the second clutch: mother %s, next clutch in %.1f s" % ["there" if is_instance_valid(mo) and not mo.dead else "gone", (mo.behavior as SpiderMotherBehavior)._lay if is_instance_valid(mo) else -1.0])
	if is_instance_valid(mo) and not mo.dead:
		g.camera.focus(Iso.to_world(mo.grid_pos))
		await _game_wait(maxf((mo.behavior as SpiderMotherBehavior)._lay + 0.3, 0.0))
		var alive := is_instance_valid(mo) and not mo.dead
		print("second clutch: eggs %d, mother %s" % [count.call("spider_egg").size(), "hp %.0f/%.0f" % [mo.hp, mo.max_hp] if alive else "gone"])
		await shot("undead_second_clutch")
	# She drains away: she crumbles to dust (no corpse, no gold).
	var corpses0 := g.corpses.corpses.size()
	await _game_wait(8.0)
	print("mother gone: %s, corpses %d -> %d" % [not is_instance_valid(mo) or mo.dead, corpses0, g.corpses.corpses.size()])
	await shot("undead_mother_crumbled")
	for e in g.events.entries:
		if "spider mother" in str(e["text"]) or "necromancer" in str(e["text"]):
			print("log: %s" % e["text"])
	for node in get_tree().get_nodes_in_group("enemies"):
		(node as Enemy).vanish()
	g.hud.open_library("enemies")
	await _frames(10)
	var lib: Library = g.hud.library
	for c in lib._list.get_children():
		if str(c.get_meta("entry_name", "")) == "Spider mother":
			lib._scroll.ensure_control_visible(c)
	await _frames(10)
	await shot("undead_library_spider_mother")
	lib.close()
	g.queue_free()
	await _frames(3)


# --- the wrathwood (docs/enemies-design.md §15c) --------------------------------------------

func _wrathwood() -> void:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.map_seed = 4242
	g.disable_fog = true
	add_child(g)
	await _frames(30)
	g.fog.reveal_all()
	g.waves.countdown = 99999.0
	g.waves.hold = true
	g.waves.wave = 8
	var v := g.player_village
	var f: Forester = null
	for c in v.population.civilians:
		if c is Forester:
			f = c
	if f == null or not is_instance_valid(f.camp):
		print("wrathwood: no forester with a camp")
		g.queue_free()
		return
	var found := g.world.find_tree(f.camp.tile, 10.0, f)
	var t: Vector2i = found["tree"]
	f._release_tree()
	f.tree = t
	g.world.claim_tree(t, f)
	f.visible = true
	f.set_grid_pos(Vector2(found["stand"]))
	f._set_home(false)
	f.state = Forester.State.CHOPPING
	f._timer = 4.0
	g.wrathwoods.always = true
	g.camera.focus(Iso.tile_to_world(t))
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(20)
	await shot("wrathwood_waking")
	var e := g.wrathwoods.of_village(v)
	if e == null:
		print("wrathwood: it didn't wake")
		g.queue_free()
		return
	var b := e.behavior as WrathwoodBehavior
	await _game_wait(float(e.spec()["wake_time"]) + 1.5)
	await shot("wrathwood_chasing")
	# Its roots hold the hero.
	var h := g.hero
	h.set_grid_pos(e.grid_pos + Vector2(0.9, 0.4))
	b._grip = 0.0
	await _frames(14)
	g.camera.focus(Iso.to_world(e.grid_pos))
	await _frames(4)
	await shot("wrathwood_grip_cast")
	await _game_wait(0.8)
	await shot("wrathwood_roots_hold")
	h.set_grid_pos(Vector2(v.center))
	# Smashing the camp.
	var camp := b.camp
	Engine.time_scale = 4.0
	var waited := 0.0
	while is_instance_valid(camp) and not camp.devastated and waited < 90.0:
		await _game_wait(0.5)
		waited += 0.5
	Engine.time_scale = 1.0
	g.camera.focus(Iso.tile_to_world(camp.tile))
	await _frames(10)
	await shot("wrathwood_camp_smashed")
	# Its log.
	e.take_damage(1e9, h)
	await _frames(20)
	await shot("wrathwood_log")
	g.hud.open_library("damage")
	await _frames(10)
	await shot("wrathwood_library_damage")
	g.hud.library.close()
	g.queue_free()
	await _frames(3)


## Vultures (docs/enemies-design.md §15d): a pack flying in to the corpses by
## the road, landing and eating, one grown on its meals beside a hungry one,
## then searching once the corpses are gone. Prints what it sees.
func _vultures() -> void:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.map_seed = 4242
	g.disable_fog = true
	add_child(g)
	await _frames(30)
	g.fog.reveal_all()
	g.waves.countdown = 99999.0
	g.waves.hold = true
	var v := g.player_village
	for t in g.world.towers():
		if t.garrison:
			g.army.unstation(t.garrison)
	var road: Vector2i = v.gates[0]
	var seen := {road: true}
	for i in 10:
		for n in MapData.neighbors4(road):
			if g.map.is_road(n) and not seen.has(n) and not g.map.in_village(n):
				seen[n] = true
				road = n
				break
	var meal := g.corpses.spawn("goblin", 1, Vector2(road))
	g.corpses.spawn("ork", 1, Vector2(road) + Vector2(0.8, 0.5))
	g.corpses.spawn("skeleton", 1, Vector2(road) + Vector2(-0.6, 0.7))
	var pack := VulturePack.new(g, meal)
	var birds: Array[Enemy] = []
	var from := Vector2(road) + Vector2(-5.0, -4.0)
	for i in 3:
		g.waves._spawn({"kind": "vulture", "spawn": Vector2i(from.round()), "hp_scale": 1.0, "village": v, "pack": pack})
		var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
		e.set_grid_pos(from + Vector2(0.5 * i, -0.4 * i))
		birds.append(e)
	await _frames(40)
	g.camera.focus(Iso.to_world((birds[0].grid_pos + Vector2(road)) / 2.0))
	g.camera.zoom = Vector2(1.5, 1.5)
	await _frames(5)
	print("flying: %s" % str(birds.map(func(e: Enemy) -> String: return "%s at %s flies %s" % [e.label(), str(e.grid_pos.snapped(Vector2(0.1, 0.1))), e.flies()])))
	await shot("vultures_flying")
	Engine.time_scale = 3.0
	for i in 600:
		await get_tree().process_frame
		if birds.all(func(e: Enemy) -> bool: return e.landed):
			break
	Engine.time_scale = 1.0
	g.camera.focus(Iso.tile_to_world(road))
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(10)
	print("eating: %s" % str(birds.map(func(e: Enemy) -> String: return "%s landed %s on %s" % [e.label(), e.landed, str(e.grid_pos.snapped(Vector2(0.1, 0.1)))])))
	await shot("vultures_eating")
	# One fed four times (twice as strong, drawn bigger) next to a hungry one.
	var vb := birds[0].behavior as VultureBehavior
	for i in 4:
		vb.finish_meal(birds[0], 0.9)
	await _frames(10)
	print("grown: %s %d meals, %.0f / %.0f HP, power %.2f; %s %d meals, %.0f HP" % [birds[0].label(), birds[0].fed, birds[0].hp, birds[0].max_hp, birds[0].power, birds[1].label(), birds[1].fed, birds[1].max_hp])
	await shot("vultures_grown")
	# The corpses gone: they take off and search, spreading out.
	for c in g.corpses.corpses.duplicate():
		g.corpses.remove(c)
	await _game_wait(3.0)
	g.camera.zoom = Vector2(1.2, 1.2)
	await _frames(10)
	print("searching: mode %d, %s" % [pack.mode, str(birds.map(func(e: Enemy) -> String: return "%s flies %s" % [e.label(), e.flies()]))])
	await shot("vultures_searching")
	for e in birds:
		if is_instance_valid(e) and not e.dead:
			e.vanish()
	g.queue_free()
	await _frames(3)


## Wolves and riders (docs/enemies-design.md §15e). Prints what it sees.
func _riders() -> void:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.map_seed = 4242
	g.disable_fog = true
	add_child(g)
	await _frames(30)
	g.fog.reveal_all()
	g.waves.countdown = 99999.0
	g.waves.hold = true
	var v := g.player_village
	for t in g.world.towers():
		if t.garrison:
			g.army.unstation(t.garrison)
	g.hero.process_mode = Node.PROCESS_MODE_DISABLED
	g.hero.remove_from_group("melee_defenders")
	var road: Array[Vector2i] = [v.gates[0]]
	var seen := {v.gates[0]: true}
	for i in 24:
		for n in MapData.neighbors4(road.back()):
			if g.map.is_road(n) and not seen.has(n) and not g.map.in_village(n):
				seen[n] = true
				road.append(n)
				break
	var spawn := func(kind: String, at: Vector2, walk: bool, extra := {}) -> Enemy:
		var sp := {"kind": kind, "spawn": g.map.edge_spawns[0], "hp_scale": 1.0, "village": v}
		sp.merge(extra)
		g.waves._spawn(sp)
		var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
		e.set_grid_pos(at)
		if walk:
			var route := g.world.pathing.enemy_route(g.world.pathing.nearest_road(Vector2i(at.round())), RandomNumberGenerator.new(), -1)
			var pts := PackedVector2Array([at])
			for t in route:
				pts.append(Vector2(t))
			e.follow(pts)
		else:
			e.speed = 0.0
			e.base_speed = 0.0
			e.follow(PackedVector2Array([at, at + Vector2(0.001, 0.0)]))
		return e
	var far := Vector2(road[mini(20, road.size() - 1)])
	# A wolf pack on the road.
	var pack: Array[Enemy] = []
	for i in 3:
		pack.append(spawn.call("wolf", far + Vector2(0.4 * i, -0.3 * i), true))
	await _game_wait(2.0)
	g.camera.focus(Iso.to_world(pack[1].grid_pos))
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(6)
	print("wolves: %s" % str(pack.map(func(e: Enemy) -> String: return "%s at %s" % [e.label(), str(e.grid_pos.snapped(Vector2(0.1, 0.1)))])))
	await shot("riders_wolf_pack")
	for e in pack:
		e.vanish()
	# A goblin raider charging a villager out in the open.
	var vic: Civilian = null
	for c in v.population.civilians:
		if c.role in ["forester", "builder", "farmer"]:
			vic = c
	vic.set_process(false)
	vic.at_home = false
	vic.visible = true
	var mid := Vector2(road[mini(9, road.size() - 1)])
	var off := mid + Vector2(1.5, 1.5)
	vic.set_grid_pos(Vector2(g.world.pathing.nearest_walkable(Vector2i(off.round()))))
	var r: Enemy = spawn.call("goblin_raider", Vector2(road[mini(16, road.size() - 1)]), true)
	var rb := r.behavior as MountedBehavior
	for i in 900:
		await get_tree().process_frame
		if r.charge_ready and rb.state == MountedBehavior.State.HUNT and r.grid_pos.distance_to(vic.grid_pos) < 2.2:
			break
	g.camera.focus(Iso.to_world((r.grid_pos + vic.grid_pos) / 2.0))
	await _frames(2)
	print("raider: %s, state %d, charge %s, %.1f tiles from %s" % [r.label(), rb.state, r.charge_ready, r.grid_pos.distance_to(vic.grid_pos), vic.label()])
	await shot("riders_raider_charge")
	vic.at_home = true
	vic.set_process(true)
	# Round the village.
	for i in 1800:
		await get_tree().process_frame
		if rb.state == MountedBehavior.State.CIRCLE and r.path_index > 1:
			break
	g.camera.focus(Iso.to_world(Vector2(v.center)))
	g.camera.zoom = Vector2(0.9, 0.9)
	await _frames(6)
	print("circling: state %d at %s" % [rb.state, str(r.grid_pos.snapped(Vector2(0.1, 0.1)))])
	await shot("riders_raider_circling")
	# Unhorsed: the goblin by its wolf's corpse.
	r.speed = 0.0
	r.take_damage(1e9, null, "projectile")
	r.speed = 0.0
	r.base_speed = 0.0
	r.follow(PackedVector2Array([r.grid_pos]))
	g.camera.focus(Iso.to_world(r.grid_pos))
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(20)
	print("unhorsed: %s (%s), corpses %s" % [r.label(), r.kind, str(g.corpses.corpses.map(func(c: Corpse) -> String: return c.kind))])
	await shot("riders_unhorsed")
	r.vanish()
	# Legion cavalry riding with its footmen.
	var col: Array[Enemy] = []
	for i in 4:
		col.append(spawn.call("legion_footman", far + Vector2(0.3 * i, 0.2 * i), true))
	for i in 2:
		col.append(spawn.call("legion_cavalry", far + Vector2(1.5 + 0.5 * i, -0.8), true))
	await _game_wait(4.0)
	g.camera.focus(Iso.to_world((col[1].grid_pos + col[4].grid_pos) / 2.0))
	await _frames(6)
	print("column: %s" % str(col.map(func(e: Enemy) -> String: return "%s state %s" % [e.label(), str((e.behavior as MountedBehavior).state) if e.behavior is MountedBehavior else "-"])))
	await shot("riders_cavalry_escort")
	for e in col:
		e.vanish()
	# The mounted captains and commanders, side by side; Torben's horse hurt.
	var line: Array[Enemy] = []
	var who := [["legion_captain", {"name": "Lysa", "art": "legion_captain_lysa"}], ["legion_captain", {"name": "Torben"}], ["legion_marshal", {"name": "Halvard"}], ["legion_king", {"name": "Rhodri"}]]
	for i in who.size():
		var extra: Dictionary = who[i][1].duplicate()
		extra["mount"] = "horse"
		extra["mount_hp"] = 100.0
		line.append(spawn.call(who[i][0], mid + Vector2(1.2 * i - 1.8, -1.2 * i + 1.8), false, extra))
		line.back().set_process(false)  # (they stand still for the picture)
	line[1].take_damage(40.0, null, "projectile")
	g.camera.focus(Iso.to_world(mid) + Vector2(80, 0))
	g.camera.zoom = Vector2(1.3, 1.3)
	await _frames(20)
	print("mounted: %s" % str(line.map(func(e: Enemy) -> String: return "%s %s horse %.0f" % [e.label(), e.unit_art(), e.mount_hp])))
	await shot("riders_mounted_captains")
	# Rhodri's horse falls: on foot by its corpse.
	var king := line[3]
	king.take_damage(1e9, null, "projectile")
	king.speed = 0.0
	king.base_speed = 0.0
	for e in line.slice(0, 3):
		e.vanish()
	g.camera.focus(Iso.to_world(king.grid_pos))
	g.camera.zoom = Vector2(1.6, 1.6)
	await _frames(20)
	print("Rhodri: %s, mount '%s'" % [king.unit_art(), king.mount])
	await shot("riders_rhodri_on_foot")
	king.vanish()
	# An undead horse bolting away.
	var horse: Corpse = null
	for c in g.corpses.corpses:
		if c.kind == "horse":
			horse = c
	var nec: Enemy = spawn.call("necromancer", horse.grid_pos + Vector2(1.0, -1.0), false)
	var uh := g.waves.raise_corpse(horse, nec)
	var wolf_c: Corpse = null
	for c in g.corpses.corpses:
		if c.kind == "wolf":
			wolf_c = c
	var uw: Enemy = null
	if wolf_c:
		wolf_c.grid_pos = uh.grid_pos + Vector2(1.2, 0.8)
		wolf_c.position = Iso.to_world(wolf_c.grid_pos)
		uw = g.waves.raise_corpse(wolf_c, nec)
		uw.speed = 0.0
		uw.base_speed = 0.0
		uw.follow(PackedVector2Array([uw.grid_pos, uw.grid_pos + Vector2(0.001, 0.0)]))
	await _game_wait(1.2)
	g.camera.focus(Iso.to_world(uh.grid_pos))
	await _frames(4)
	print("undead horse: %s raised %s at %s; undead wolf: %s" % [uh.label(), uh.raised, str(uh.grid_pos.snapped(Vector2(0.1, 0.1))), uw.label() + (" raised, unholy %s" % uw.is_unholy()) if uw else "none"])
	await shot("riders_undead_horse_and_wolf")
	for node in get_tree().get_nodes_in_group("enemies"):
		(node as Enemy).vanish()
	# The library: the raider and the halberdier.
	for pair in [["enemies", "Goblin Raider"], ["units", "Halberdier"]]:
		g.hud.open_library(pair[0])
		await _frames(10)
		var lib := g.hud.library
		for c in lib._list.get_children():
			if str(c.get_meta("entry_name", "")) == pair[1]:
				lib._scroll.scroll_vertical = int((c as Control).position.y)
		await _frames(6)
		await shot("riders_library_" + str(pair[1]).to_lower().replace(" ", "_"))
		lib.close()
		await _frames(3)
	g.queue_free()
	await _frames(3)
