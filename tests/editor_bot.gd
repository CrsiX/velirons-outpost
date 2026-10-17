extends "res://tests/bot_base.gd"
## Headless test of the map editor (docs/map-editor-design.md): the title
## button, a map in both views, every tool's edit with its tidy-up and undo /
## redo, the pointer (a drag paints one undo step), selection and the
## inspector, the checks, the layers, files (save, list, open, delete), the
## map picker, Play's way into a game and back (the session), and the web's
## big-map warning. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/editor_bot.tscn

var ed: MapEditor


func _run() -> void:
	await _title_button()
	ed = load("res://scenes/map_editor.tscn").instantiate()
	add_child(ed)
	await frames(3)
	check(ed.map != null and ed.map.size == 75 and ed.map.villages.size() == 1, "the editor opens on a generated map (75x75, one village)")
	check(MapChecks.errors(ed.problems).is_empty(), "a generated map has no errors %s" % str(MapChecks.errors(ed.problems).map(func(p: Dictionary) -> String: return p["text"])))
	check(ed.iso.visible and not ed.plan.visible and ed.iso.things.get_child_count() > 100, "isometric view with its trees, village and objects")
	await _views()
	await _new_maps()
	_terrain_and_undo()
	_roads()
	_volcano()
	_villages()
	_objects()
	_slices()
	await _pointer()
	await _mouse_buttons()
	await _inspector_and_layers()
	await _panels()
	await _portrait_sheet()
	await _files()
	await _session()
	await _play_flow()
	await _web_warning()
	MapPicker.pretend_web = false
	Settings.editor_session = {}
	Settings.custom_map = null
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _title_button() -> void:
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await frames(2)
	var b := title.editor_button
	check(b != null and b.text == "Map Editor" and b.visible and b.icon != null, "the title screen has a Map Editor button with an icon")
	check(b.get_index() == title.library_button.get_index() + 1, "right below Library")
	check(ResourceLoader.exists(TitleScreen.EDITOR_SCENE), "and the editor's scene is there")
	title.queue_free()
	await frames(2)


## An open, buildable tile near `from` with room around it (`r` tiles all buildable).
func _open_spot(from: Vector2i, r: int = 0, avoid_villages: int = 4) -> Vector2i:
	var m := ed.map
	var pieces := MapTidy.piece_tiles(m)
	var objects := MapTidy.object_tiles(m)
	for d in range(3, m.size):
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				var t := from + Vector2i(dx, dy)
				var ok := true
				for yy in range(-r, r + 1):
					for xx in range(-r, r + 1):
						var p := t + Vector2i(xx, yy)
						if not MapEditor.buildable(m, p, pieces, objects) or m.props.has(p) or m.is_edge(p):
							ok = false
				for v in m.villages:
					if Vector2(t).distance_to(Vector2(v["center"])) < avoid_villages + r:
						ok = false
				if ok:
					return t
	return Vector2i(-1, -1)


func _views() -> void:
	var g := ed._to_grid(ed.camera.position)
	ed.toggle_view()
	await frames(2)
	check(ed.plan_mode and ed.plan.visible and not ed.iso.visible, "Tab / 2D: the top-down view")
	check(ed._to_grid(ed.camera.position).distance_to(g) < 1.5, "the same tile stays in the middle")
	var px := float(Config.EDITOR["plan_tile_px"])
	check(ed.tile_at(Vector2(10.5, 20.5) * px) == Vector2i(10, 20), "a point in the plan is the tile under it")
	ed.toggle_view()
	await frames(2)
	check(not ed.plan_mode and ed.iso.visible and ed._to_grid(ed.camera.position).distance_to(g) < 1.5, "and back to isometric")
	check(ed.tile_at(Iso.tile_to_world(Vector2i(12, 7))) == Vector2i(12, 7), "a point in the isometric view is the tile under it")


func _new_maps() -> void:
	await ed.ui._generate({"size": 50, "type": "highlands", "seed": "77", "villages": 1, "blank": false})
	check(ed.map.size == 50 and ed.map.map_type == "highlands" and ed.dirty and ed.path == "", "New: a 50x50 highlands map, not saved yet")
	check(ed.map.meta["origin"]["generator_seed"] == 77, "it remembers its generator seed")
	await ed.ui._generate({"size": 100, "type": "temperate", "seed": "", "villages": 3, "blank": false})
	check(ed.map.size == 100 and ed.map.villages.size() == 3, "New: 100x100 with three villages")
	await ed.ui._generate({"size": 75, "type": "temperate", "seed": "", "villages": 1, "blank": true})
	check(ed.map.size == 75 and ed.map.villages.is_empty() and ed.map.objects.is_empty() and ed.map.count_terrain(MapData.Terrain.GRASS) == 75 * 75, "New, blank: all meadow, nothing on it")
	check(ed.problems.any(func(p: Dictionary) -> bool: return p["text"] == "The map has no village"), "a blank map: 'no village' is an error")
	await ed.ui._generate({"size": 75, "type": "temperate", "seed": "38", "villages": 1, "blank": false})
	check(ed.map.size == 75 and not ed.can_undo(), "back to a 75x75 map; undo starts over")


func _terrain_and_undo() -> void:
	var m := ed.map
	var t := _open_spot(m.villages[0]["center"], 1)
	ed.tool = "terrain"
	ed.opts["terrain"] = MapData.Terrain.FOREST
	ed.opts["brush"] = 3
	ed.opts["round"] = false
	ed.opts["fill"] = false
	ed._press(t)
	ed._release(t)
	check(m.is_forest(t) and m.is_forest(t + Vector2i(1, 1)) and m.props.has(t) and str(m.props[t]).begins_with("tree"), "Terrain, forest, brush 3: 3x3 forest, with trees (tidy-up)")
	check(ed.can_undo() and ed.dirty, "one step to undo")
	ed.undo()
	m = ed.map
	check(not m.is_forest(t) and not m.props.has(t), "Undo: the meadow is back")
	ed.redo()
	m = ed.map
	check(m.is_forest(t) and m.props.has(t), "Redo: the forest again")
	ed.opts["terrain"] = MapData.Terrain.GRASS
	ed.opts["fill"] = true
	ed._press(t)
	check(not ed.map.is_forest(t) and not ed.map.props.has(t), "Fill: the whole forest patch back to grass, its trees gone")
	ed.opts["fill"] = false
	ed.tool = "zone"
	ed.opts["zone"] = "swamp"
	ed.opts["brush"] = 1
	ed._press(t)
	ed._release(t)
	check(ed.map.zone(t) == "swamp", "Zone: swamp")
	ed.tool = "decor"
	ed.opts["decor"] = "auto"
	ed._press(t)
	ed._release(t)
	check(ed.map.decor.get(t, "") == "reeds", "Decor, auto: the swamp's reeds")
	ed.tool = "terrain"
	ed.opts["terrain"] = MapData.Terrain.MOUNTAIN
	ed._press(t)
	ed._release(t)
	check(ed.map.is_mountain(t) and not ed.map.decor.has(t) and MapTidy.PEAK_ARTS.has(ed.map.props.get(t, "")), "Mountain: a peak, the decor gone")
	ed.tool = "props"
	ed.opts["prop"] = "mountain_2"
	ed._press(t)
	ed._release(t)
	check(ed.map.props.get(t, "") == "mountain_2", "Trees & peaks: the chosen peak")
	ed.tool = "beach"
	ed.opts["beach"] = true
	var land := _open_spot(t, 0)
	ed._press(land)
	ed._release(land)
	check(not ed.map.beaches.has(land), "a beach away from water is tidied away")


func _roads() -> void:
	var m := ed.map
	var water := Vector2i(-1, -1)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if water.x < 0 and m.get_terrain(t) == MapData.Terrain.WATER and not m.crossings.has(t) and not m.is_edge(t):
				water = t
	ed.tool = "road"
	ed.opts["road"] = "free"
	ed.opts["brush"] = 1
	if water.x >= 0:
		ed._press(water)
		ed._release(water)
		m = ed.map
		check(m.is_road(water) and m.crossings.has(water) and int(m.crossings[water][1]) == MapData.Terrain.WATER and str(m.crossings[water][0]).begins_with("bridge_"), "Road over deep water: a bridge")
		ed.opts["road"] = "erase"
		ed._press(water)
		ed._release(water)
		check(ed.map.get_terrain(water) == MapData.Terrain.WATER and not ed.map.crossings.has(water), "Erase: the water is back, no bridge")
	else:
		check(false, "a water tile to bridge")
	var a := _open_spot(ed.map.villages[0]["center"], 0, 8)
	var b := a + Vector2i(6, 3)
	ed.opts["road"] = "path"
	ed._press(a)
	check(ed._road_start == a, "Path: the first click marks the start")
	ed._on_hovered(Iso.tile_to_world(b))
	check(ed.path_preview.size() >= 9 and ed.path_preview[0] == a, "the road to the pointer shows (%d tiles)" % ed.path_preview.size())
	ed._press(b)
	check(ed.map.is_road(a) and ed.map.is_road(b) and ed._road_start == MapEditor.NO_TILE and ed.path_preview.is_empty(), "the second click lays it")
	ed.undo()


func _volcano() -> void:
	var t := _open_spot(ed.map.villages[0]["center"], 2, 10)
	ed.tool = "volcano"
	ed.opts["volcano"] = "add"
	ed.opts["ash"] = true
	ed._press(t)
	var m := ed.map
	check(m.volcanoes.has(t) and m.props.get(t, "") == "volcano" and m.is_mountain(t + Vector2i(1, 1)) and not m.props.has(t + Vector2i(1, 1)), "Volcano: 3x3 mountain, the crater in the middle")
	check(m.zone(t + Vector2i(4, 0)) == "ash", "with ash land around it")
	ed.opts["volcano"] = "remove"
	ed._press(t + Vector2i(1, 0))
	check(not ed.map.volcanoes.has(t) and ed.map.props.get(t, "") != "volcano", "Remove: no volcano (its rock stays)")
	ed.undo()
	ed.undo()
	check(not ed.map.volcanoes.has(t), "undone twice: as before")


func _villages() -> void:
	var t := _open_spot(ed.map.villages[0]["center"], 3, 14)
	ed.tool = "village"
	ed._press(t)
	ed._release(t)
	var m := ed.map
	check(m.villages.size() == 2 and m.village_pieces(1).size() == 25 and MapChecks.standard_layout(m, 1), "Village: a second one, the standard 25 pieces")
	check(ed.selected.get("type") == "village" and int(ed.selected["index"]) == 1, "and it's selected")
	ed._run_checks()
	check(ed.problems.any(func(p: Dictionary) -> bool: return p["level"] == "error" and "Village 2 has no spawn" in p["text"]), "it has no spawn yet: an error")
	ed.tool = "village"
	ed._press(t)
	ed._release(t + Vector2i(2, 0))
	var moved := ed.map.village_pieces(1)
	check(ed.map.villages[1]["center"] == t + Vector2i(2, 0) and moved.size() == 25 and moved.all(func(p: Dictionary) -> bool: return Vector2(p["tile"]).distance_to(Vector2(t + Vector2i(2, 0))) < 3.0), "drag a village: it moves, pieces and all")
	ed.tool = "piece"
	ed.opts["piece"] = "wall"
	var hut_tile: Vector2i = t + Vector2i(2, 0) + Vector2i(-1, -1)
	ed._press(hut_tile)
	check(MapTidy.piece_tiles(ed.map).get(hut_tile, "") == "wall" and not MapChecks.standard_layout(ed.map, 1), "Pieces: a hut becomes a wall (not the standard layout)")
	ed._run_checks()
	check(ed.problems.any(func(p: Dictionary) -> bool: return p["level"] == "warning" and "Village 2 doesn't have the standard layout" in p["text"]), "a warning, not an error")
	ed.opts["piece"] = "flip"
	ed._press(hut_tile)
	check(ed.map.village_layout.any(func(p: Dictionary) -> bool: return p["tile"] == hut_tile and p["flip"]), "Flip turns it")
	ed.opts["piece"] = "erase"
	ed._press(hut_tile)
	check(not MapTidy.piece_tiles(ed.map).has(hut_tile), "Erase removes it")
	# A spawn: an edge road tile.
	var edge := Vector2i(-1, -1)
	for s in ed.map.villages[0]["home_spawns"]:
		edge = s
	ed.tool = "spawn"
	ed.select({"type": "village", "index": 1})
	ed._press(edge)
	check(not (ed.map.villages[0]["home_spawns"] as Array).has(edge), "Spawn on an existing one: removed")
	ed._press(edge)
	check((ed.map.villages[1]["home_spawns"] as Array).has(edge), "again: it belongs to the selected village")
	ed._press(Vector2i(5, 5))
	check(ed.ui._status.text.begins_with("A spawn goes on a road tile"), "off the edge road: refused, with why")
	ed.move_village_number(1, -1)
	check((ed.map.villages[0]["home_spawns"] as Array).has(edge) and ed.map.village_pieces(0).size() == 24, "Number -1: villages 1 and 2 swap")
	ed.select({"type": "village", "index": 0})
	ed.delete_selected()
	check(ed.map.villages.size() == 1 and ed.map.village_pieces(0).size() == 25 and ed.map.village_layout.size() == 25, "Delete village: one left, its pieces gone")
	for k in 9:  # (add, move, wall, flip, erase, two spawns, swap, delete)
		ed.undo()
	check(ed.map.villages.size() == 1 and (ed.map.villages[0]["home_spawns"] as Array).has(edge), "everything undone")


func _objects() -> void:
	var m := ed.map
	var n := m.objects.size()
	var t := _open_spot(m.villages[0]["center"], 1, 6)
	ed.tool = "object"
	ed.opts["object"] = "treasure"
	ed.opts["object_size"] = 1
	ed._press(t)
	ed._release(t)
	check(ed.map.objects.size() == n + 1 and ed.map.objects[n]["kind"] == "treasure" and ed.map.objects[n]["art"] == "chest", "Objects: a treasure (a chest)")
	ed.set_object_field("treasure", "shrine")
	check(ed.map.objects[n]["treasure"] == "shrine" and ed.map.objects[n]["art"] == "shrine", "its kind changes, and its art with it")
	var c := _open_spot(t, 0, 6)
	ed.opts["object"] = "camp"
	ed._press(c)
	ed._release(c)
	check(ed.map.objects.size() == n + 2 and int(ed.map.objects[n + 1]["guards"]) == n and int(ed.map.objects[n]["guard"]) == n + 1, "a camp guards the nearest unguarded treasure")
	ed.tool = "object"
	ed._press(t)
	ed._release(t + Vector2i(1, 0))
	check(ed.map.objects[n]["tile"] == t + Vector2i(1, 0), "drag an object: it moves")
	ed.select({"type": "object", "index": n})
	ed.delete_selected()
	check(ed.map.objects.size() == n, "deleting a treasure takes its camp along")
	ed.undo()
	check(ed.map.objects.size() == n + 2 and int(ed.map.objects[n + 1]["guards"]) == n, "undo: both back, still linked")
	var r := MapJson.read(MapJson.write(ed.map))
	check(r["map"] != null, "the edited map writes and reads back")


func _slices() -> void:
	ed.tool = "slice"
	ed.opts["slice"] = 3
	ed.opts["brush"] = 1
	ed._press(Vector2i(2, 2))
	ed._release(Vector2i(2, 2))
	check(ed.map.slice_of[ed.map.index(Vector2i(2, 2))] == 3, "Slice: painted")
	ed.recompute_slices()
	var m := ed.map
	check(m.slice_of.count(0) == m.size * m.size, "Recompute from the villages: one village, one slice")


## The pointer: a press, a drag over tiles and a release paint one undo step.
func _pointer() -> void:
	ed.tool = "terrain"
	ed.opts["terrain"] = MapData.Terrain.DESERT
	ed.opts["brush"] = 1
	ed.opts["fill"] = false
	var a := _open_spot(ed.map.villages[0]["center"], 1, 8)
	var b := a + Vector2i(4, 0)
	var undo0 := ed._undo.size()
	ed.view_tile(a + Vector2i(2, 0))
	await frames(2)
	Layout.touch = false
	await _mouse(a, true)
	for k in range(1, 5):
		await _move(a + Vector2i(k, 0))
	await _mouse(b, false)
	var all_desert := true
	for k in 5:
		all_desert = all_desert and ed.map.get_terrain(a + Vector2i(k, 0)) == MapData.Terrain.DESERT
	check(all_desert, "a drag paints every tile along it")
	check(ed._undo.size() == undo0 + 1, "one undo step for the whole stroke")
	var cam := ed.camera.position
	ed.tool = "file"
	await _mouse(a + Vector2i(0, 3), true)
	await _move(a + Vector2i(6, 6))
	await _mouse(a + Vector2i(6, 6), false)
	check(ed.camera.position != cam, "with the File tab open a drag pans the map")
	ed.view_tile(a)
	await frames(2)
	ed.select({})
	await _mouse(a, true)
	await _mouse(a, false)
	check(ed.selected.get("type") == "tile" and ed.selected.get("tile") == a and ed._undo.size() == undo0 + 1, "and a click selects the tile, editing nothing")


## The right button: let go where it was pressed, it's the tool's opposite
## there (erase; Zone and Slice take the tile's); dragged, it pans.
func _mouse_buttons() -> void:
	Layout.touch = false
	var m := ed.map
	ed.tool = "terrain"
	ed.opts["terrain"] = MapData.Terrain.DESERT
	ed.opts["brush"] = 1
	ed.opts["fill"] = false
	var a := _open_spot(m.villages[0]["center"], 1, 8)
	ed.view_tile(a)
	await frames(2)
	await _mouse(a, true)
	await _mouse(a, false)
	check(m.get_terrain(a) == MapData.Terrain.DESERT, "Terrain: a left click paints")
	var undo0 := ed._undo.size()
	await _mouse(a, true, MOUSE_BUTTON_RIGHT)
	await _mouse(a, false, MOUSE_BUTTON_RIGHT)
	check(m.get_terrain(a) == MapData.Terrain.GRASS and ed._undo.size() == undo0 + 1, "a right-click puts grass back (one undo step)")
	var cam := ed.camera.position
	var before := m.to_bytes()
	await _mouse(a, true, MOUSE_BUTTON_RIGHT)
	await _move(a + Vector2i(4, 4), MOUSE_BUTTON_MASK_RIGHT)
	await _move(a + Vector2i(8, 8), MOUSE_BUTTON_MASK_RIGHT)
	await _mouse(a + Vector2i(8, 8), false, MOUSE_BUTTON_RIGHT)
	check(ed.camera.position != cam and m.to_bytes() == before and ed._undo.size() == undo0 + 1, "a right drag pans and edits nothing")
	ed.tool = "decor"
	ed.opts["decor"] = "auto"
	ed._press(a)
	ed._release(a)
	var had := m.decor.has(a)
	ed._erase(a)
	check(had and not m.decor.has(a), "Decor: a right-click erases it")
	ed.tool = "road"
	ed.opts["road"] = "free"
	ed._press(a)
	ed._release(a)
	had = m.is_road(a)
	ed._erase(a)
	check(had and not m.is_road(a), "Road: a right-click erases it")
	ed.opts["road"] = "path"
	ed._press(a)
	ed._erase(a + Vector2i(3, 0))
	check(ed._road_start == MapEditor.NO_TILE and ed.path_preview.is_empty() and not m.is_road(a), "a road being laid: a right-click cancels it")
	ed.opts["road"] = "free"
	ed.tool = "zone"
	ed.opts["zone"] = "meadow"
	m.set_zone(a, "swamp")
	ed._erase(a)
	check(ed.opts["zone"] == "swamp", "Zone: a right-click takes the tile's zone")
	ed.tool = "slice"
	ed.opts["slice"] = 5
	ed._erase(a)
	check(int(ed.opts["slice"]) == int(m.slice_of[m.index(a)]), "Slice: and its slice")
	var forest := -1
	for i in m.terrain.size():
		if m.terrain[i] == MapData.Terrain.FOREST:
			forest = i
			break
	ed.tool = "props"
	var n := ed._undo.size()
	ed._erase(Vector2i(forest % m.size, forest / m.size))
	check(ed._undo.size() == n and m.terrain[forest] == MapData.Terrain.FOREST, "Trees, peaks: a right-click does nothing")
	ed.tool = "volcano"
	ed._erase(a)
	check(ed._undo.size() == n and ed.ui._status.text == "No volcano there", "Volcano: nothing to remove, it says so")
	ed.tool = "spawn"
	ed._erase(a)
	check(ed._undo.size() == n and ed.ui._status.text == "No spawn there", "Spawn: nothing to remove, it says so")
	var spawns: Array = m.villages[0]["home_spawns"]
	var sp: Vector2i = spawns[0]
	var count := spawns.size()
	ed._erase(sp)
	check((ed.map.villages[0]["home_spawns"] as Array).size() == count - 1, "and a spawn goes")
	ed.undo()
	m = ed.map
	ed.tool = "piece"
	var wall: Vector2i = m.village_pieces(0).filter(func(p: Dictionary) -> bool: return p["kind"] == "wall")[0]["tile"]
	ed._erase(wall)
	check(not MapTidy.piece_tiles(ed.map).has(wall), "Pieces: a right-click removes one")
	ed.undo()
	ed.tool = "object"
	ed.opts["object"] = "treasure"
	ed.opts["object_size"] = 1
	var objects := ed.map.objects.size()
	ed._press(a)
	ed._release(a)
	ed._erase(a)
	check(ed.map.objects.size() == objects and ed.selected.is_empty(), "Objects: a right-click deletes the one there")
	ed.tool = "terrain"
	ed.opts["terrain"] = MapData.Terrain.FOREST


func _screen(t: Vector2i) -> Vector2:
	return ed.camera.world_to_screen(ed._to_world(Vector2(t)))


func _mouse(t: Vector2i, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = _screen(t)
	e.global_position = e.position
	get_viewport().push_input(e, true)
	await frames(1)


func _move(t: Vector2i, mask: MouseButtonMask = MOUSE_BUTTON_MASK_LEFT) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _screen(t)
	e.global_position = e.position
	e.button_mask = mask
	get_viewport().push_input(e, true)
	await frames(1)


func _inspector_and_layers() -> void:
	var ui := ed.ui
	ed.select({"type": "object", "index": 0})
	await frames(1)
	check(ui._inspect.get_child_count() > 2 and (ui._inspect.get_child(0) as Label).text.begins_with(str(ed.map.objects[0]["kind"]).capitalize()), "Inspector: the selected object, with its fields")
	ed.select({"type": "village", "index": 0})
	await frames(1)
	check((ui._inspect.get_child(0) as Label).text.begins_with("Village 1"), "the selected village")
	ed.select({"type": "tile", "tile": Vector2i(3, 4)})
	await frames(1)
	check((ui._inspect.get_child(0) as Label).text.begins_with("Tile 3, 4"), "a tile")
	for k in ed.layers:
		if k != "flow":
			ed.layers[k] = true
	ed.layers["flow"] = 0
	ed.redraw_layers()
	await frames(2)
	ed.toggle_view()
	await frames(2)
	ed.toggle_view()
	check(true, "every layer drawn in both views")
	for k in ["zones", "slices", "grid", "passable", "buildable", "rings"]:
		ed.layers[k] = false
	ed.layers["flow"] = -1
	ed.redraw_layers()
	check(ui._problems_box.get_child_count() >= 1, "the problems list is filled")
	for t in MapEditor.TOOLS:
		ui.set_tool(t)
		await frames(1)
	check(ed.tool == MapEditor.TOOLS[-1] and ui._options.get_child_count() > 1, "every tool has its options")
	ui.set_tool("file")
	ed.select({})
	ed.hover = Vector2i(5, 6)
	ui.show_hover(ed.hover)
	await frames(1)
	check(ui._tile_box.get_child_count() >= 2 and (ui._tile_box.get_child(1) as Label).text.begins_with("Tile 5, 6"), "the inspector shows the tile under the pointer")
	var v0: Vector2i = ed.map.villages[0]["center"]
	ui.show_hover(v0 + Vector2i(0, 4))
	check(_texts(ui._tile_box).any(func(t: String) -> bool: return t.begins_with("Road steps to village 1")), "with its road steps to each village")


func _texts(n: Node) -> Array[String]:
	var out: Array[String] = []
	for k in n.get_children():
		if k is Label or k is Button:
			out.append(str(k.text))
		out.append_array(_texts(k))
	return out


func _buttons(n: Node) -> Array[Button]:
	var out: Array[Button] = []
	for k in n.get_children():
		if k is Button:
			out.append(k)
		out.append_array(_buttons(k))
	return out


## Landscape: no top bar; the File tab; undo / redo as icons; each side panel
## folds to its edge (its heading left at the top); the slices in their colours.
func _panels() -> void:
	var ui := ed.ui
	await frames(2)
	var vw := ui.root.size.x
	check(ui._left.position.y <= 8.0 and ui._right.position.y <= 8.0 and absf(ui._left.size.x - EditorUi.LEFT_W) < 1.0, "landscape: the tools and the inspector reach the top (no top bar)")
	check(not MapEditor.TOOLS.has("look") and MapEditor.TOOLS[0] == "file", "no Look tool; the File tab comes first")
	ui.set_tool("file")
	await frames(1)
	var names := _texts(ui._options)
	check(["New", "Open", "Save", "Save as", "Import", "Export", "Properties", "Play", "Exit"].all(func(t: String) -> bool: return names.has(t) or names.has(t + "*")) and not names.has("Back"), "the File tab: New, Open, Save, Save as, Import, Export, Properties, Play, Exit")
	check(ui._undo_button.text == "" and ui._undo_button.icon != null and ui._redo_button.icon != null and ui._view_button.text in ["2D", "Isometric"], "undo and redo are icons, by the view toggle")
	ui._left_head.pressed.emit()
	await frames(2)
	check(not ui._left_open and not ui._left_scroll.visible and ui._left.size.x < 160.0 and ui._left.position == Vector2(6, 6) and ui._left_head.visible, "Tools folded: only its heading, at the top left (%.0f x %.0f px)" % [ui._left.size.x, ui._left.size.y])
	check(not ui.is_over_panel(Vector2(150, 300)), "the map gets the room")
	ui.set_panel_open(false, false)
	await frames(2)
	check(not ui._right_scroll.visible and ui._right.size.x < 200.0 and absf(ui._right.position.x + ui._right.size.x - (vw - 6.0)) < 1.5 and ui._right.position.y <= 8.0, "the inspector folds to the right edge, at the top")
	check(ui._left_head.icon != ui._right_head.icon, "each with the chevron the other way")
	ui._left_head.pressed.emit()
	ui._right_head.pressed.emit()
	await frames(2)
	check(ui._left_open and ui._right_open and absf(ui._left.size.x - EditorUi.LEFT_W) < 1.0 and absf(ui._right.size.x - EditorUi.RIGHT_W) < 1.0, "and both open again")
	ed.tool = "slice"
	ui.set_tool("slice")
	await frames(2)
	var sb: Array[Button] = []
	sb.assign(_buttons(ui._options).filter(func(b: Button) -> bool: return b.tooltip_text.begins_with("Slice")))
	check(sb.size() == Config.MAX_PLAYERS and sb[0].text == "Slice 1" and sb[7].text == "Slice 8", "Slice: 8 buttons, Slice 1 to Slice 8 (%s)" % ", ".join(sb.map(func(b: Button) -> String: return b.text)))
	var font := sb[0].get_theme_font("font")
	check(font.get_string_size("Slice 8", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= sb[7].size.x - 8.0, "the whole name fits (%.0f px wide buttons)" % sb[7].size.x)
	var c0 := (sb[0].get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	var c1 := (sb[1].get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	check(c0 != c1 and sb[2].get_theme_color("font_color").is_equal_approx(EditorUi.slice_color(2).lightened(0.45)), "each in its village colour")
	ui.set_tool("file")


## Portrait: a bottom sheet with a handle over the two tabs; a tab opens it,
## the open tab folds it, the handle drags it; the grids get more columns.
func _portrait_sheet() -> void:
	var ui := ed.ui
	get_window().size = Vector2i(720, 1280)
	get_viewport().size = Vector2i(720, 1280)
	await frames(4)
	check(ui._portrait and ui._sheet.visible and not ui._left_head.visible and not ui._left.visible and not ui._right.visible, "portrait: a folded bottom sheet, the handle over the two tabs")
	var vh := ui.root.size.y
	ui._on_tab_pressed("tools")
	await frames(3)
	check(ui._sheet_open and ui._left.visible and not ui._right.visible and ui._sheet_h <= vh * Hud.SHEET_MAX + 0.5, "Tools opens it, at most half the screen (%.0f of %.0f px)" % [ui._sheet_h, vh])
	var grid := ui._tools_box.get_child(1) as GridContainer
	check(grid.columns >= 4, "the tools sit in %d columns" % grid.columns)
	ui._on_tab_pressed("info")
	await frames(3)
	check(ui._right.visible and not ui._left.visible and ui._layers_box.columns >= 2, "Inspector: its page, the layers in %d columns" % ui._layers_box.columns)
	ui._on_tab_pressed("info")
	await frames(3)
	check(not ui._sheet_open and not ui._right.visible, "the open tab folds it")
	var from := ui._handle.get_global_rect().get_center()
	_gui_mouse(from, true)
	await frames(1)
	for i in range(1, 7):
		_gui_motion(from - Vector2(0, 60 * i))
		await frames(1)
	_gui_mouse(from - Vector2(0, 360), false)
	await frames(15)
	check(ui._sheet_open and ui._right.visible and absf(ui._sheet_h - ui._open_h()) < 1.0, "dragging the handle up opens it")
	_gui_mouse(ui._handle.get_global_rect().get_center(), true)
	_gui_mouse(ui._handle.get_global_rect().get_center(), false)
	await frames(3)
	check(not ui._sheet_open, "a tap on the handle folds it")
	get_window().size = Vector2i(1280, 720)
	get_viewport().size = Vector2i(1280, 720)
	await frames(4)
	check(not ui._portrait and ui._left.visible and ui._right.visible and not ui._sheet.visible, "back to landscape: the side panels")


func _gui_mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(e, true)


func _gui_motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func _files() -> void:
	ed.set_properties("Editor bot map", "bot", "Made by the editor bot.", "bot type")
	var p := ed.save_file()
	check(p != "" and FileAccess.file_exists(p) and p.begins_with(MapLibrary.user_dir()) and not ed.dirty, "Save: a file under your maps (%s)" % p)
	var listed := MapLibrary.list().filter(func(e: Dictionary) -> bool: return e["path"] == p)
	check(listed.size() == 1 and listed[0]["name"] == "Editor bot map" and listed[0]["size"] == 75 and listed[0]["map_type"] == "bot type", "the map list shows it with its name, size and type")
	var r := MapLibrary.load_file(p)
	check(r["map"] != null and MapJson.write(r["map"]) == MapJson.write(ed.map), "it reads back as it was saved")
	ed.ui.picker.open(false, "Open a map", "Open")
	ed.ui.picker.refresh(p)
	await frames(2)
	check(ed.ui.picker.visible and ed.ui.picker.selected_path() == p and not ed.ui.picker._ok.disabled, "Open: the picker lists it, ready to open")
	var opened := []
	ed.ui.picker.picked.connect(func(m: MapData, path: String) -> void: opened.append(path), CONNECT_ONE_SHOT)
	ed.ui.picker._choose()
	await frames(2)
	check(opened == [p] and ed.path == p and not ed.dirty, "opening it: the editor has that file")
	# A broken file is listed, and can't be opened.
	var bad := MapLibrary.user_dir().path_join("zz-broken-bot.json")
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("{\"format\": \"velirons-outpost-map\", \"format_version\": 1, \"size\": 60}")
	f.close()
	ed.ui.picker.open(false)
	ed.ui.picker.refresh(bad)
	await frames(1)
	check(ed.ui.picker._ok.disabled and "can't be read" in ed.ui.picker._problems.text, "a broken file: listed, its problems shown, it can't be opened")
	ed.ui.picker.close()
	DirAccess.remove_absolute(bad)
	ed.path = p
	await _singleplayer_custom(p)


## The title's Singleplayer page: Map goes on from Random to Custom... (the picker), then back.
func _singleplayer_custom(p: String) -> void:
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await frames(2)
	Settings.custom_map = null
	Settings.map_type = "random"
	title._update_sp_buttons()
	title._cycle_map()
	await frames(1)
	check(title.picker.visible and title.picker.for_play, "Singleplayer: after Random, Map opens the map picker (for playing)")
	title.picker.refresh(p)
	title.picker._choose()
	await frames(1)
	check(Settings.custom_map != null and MapJson.map_name(Settings.custom_map) == "Editor bot map" and "Editor bot map" in title.map_button.text, "the chosen map is the next game's, its name on the Map button")
	check(not title.seed_edit.visible and not title.village_button.visible, "no seed for a map file; one village: no village choice")
	title._cycle_map()
	check(Settings.custom_map == null and Settings.map_type == Config.MAP_TYPE_ORDER[0] and title.seed_edit.visible, "Map again: back to the first map type")
	title.queue_free()
	await frames(2)


func _session() -> void:
	var t := _open_spot(ed.map.villages[0]["center"], 0, 6)
	ed.tool = "terrain"
	ed.opts["terrain"] = MapData.Terrain.FOREST
	ed.opts["brush"] = 1
	ed._press(t)
	ed._release(t)
	ed.toggle_view()
	var undo_n := ed._undo.size()
	Settings.editor_session = ed.session()
	var path := ed.path
	ed.queue_free()
	await frames(2)
	ed = load("res://scenes/map_editor.tscn").instantiate()
	add_child(ed)
	await frames(3)
	check(ed.map.is_forest(t) and ed.path == path and ed.dirty and ed.plan_mode and ed._undo.size() == undo_n, "Back from Play: the same map, file, unsaved changes, view and undo")
	check(Settings.editor_session.is_empty(), "the session is taken")


func _play_flow() -> void:
	Settings.custom_map = ed.map.copy()
	Settings.custom_village = 0
	Settings.editor_play = true
	Settings.editor_session = ed.session()
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await wait_until(func() -> bool: return game.hud != null and game.stats != null and game.player_village.hero != null, 60.0)
	await frames(3)
	check(game.map.meta.get("name") == "Editor bot map", "Play: the game runs on the editor's map")
	game.hud.open_settings()
	await frames(1)
	check(game.hud._settings_editor_button.visible and "Editor bot map" in game.hud._settings_map_label.text, "its settings offer Back to editor and name the map")
	game.hud.close_settings()
	Settings.editor_play = false
	game.queue_free()
	await frames(3)
	game = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	MapLibrary.delete(ed.path)


func _web_warning() -> void:
	MapPicker.pretend_web = true
	check(MapPicker.warns_large(150) and MapPicker.warns_large(200) and not MapPicker.warns_large(125), "web: maps of 150 and more warn, smaller ones don't")
	MapPicker.pretend_web = false
	check(not MapPicker.warns_large(200), "elsewhere: no warning")
	MapPicker.pretend_web = true
	ed.ui.show_new()
	await frames(1)
	_press_text(ed.ui._dialog_box, "150")
	await frames(1)
	_press_text(ed.ui._dialog_box, "Make it")
	await frames(1)
	check(ed.ui._dialog.visible and (ed.ui._dialog_box.get_child(0) as Label).text == "A big map" and "may run slowly in the browser" in (ed.ui._dialog_box.get_child(1) as Label).text, "web, New 150x150: it asks first")
	ed.ui.close_dialog()
	check(ed.map.size == 75, "and nothing is made until it's confirmed")


## Presses the first button under `n` whose text is `text`.
func _press_text(n: Node, text: String) -> bool:
	for c in n.get_children():
		if c is Button and (c as Button).text == text:
			(c as Button).pressed.emit()
			return true
		if _press_text(c, text):
			return true
	return false
