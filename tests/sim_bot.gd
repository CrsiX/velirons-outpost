extends Node
## Headless end-to-end test of every core mechanic. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/sim_bot.tscn
## Exits 0 when every check passes. Drives real input events where the
## interaction matters (drag & drop, taps), and the public APIs elsewhere.

const SEED := 20260926

var game: Game
var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


## Title screen: menu, difficulty toggle and its effect on enemy stats.
func _test_title() -> void:
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await frames(3)
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn", "the game starts on the title screen")
	check(title.play_button.visible and title.difficulty_button.visible and title.levels_button.visible and title.exit_button.visible, "title has Play, Difficulty, Levels and Exit")
	var seen: Array[String] = [title.difficulty_button.text]
	var mults: Array[float] = [Config.enemy_stat("goblin", "hp") / Config.ENEMIES["goblin"]["hp"]]
	for i in 3:
		await tap(center(title.difficulty_button))
		seen.append(title.difficulty_button.text)
		mults.append(Config.enemy_stat("goblin", "hp") / Config.ENEMIES["goblin"]["hp"])
	check(seen == ["Difficulty: Normal", "Difficulty: Hard", "Difficulty: Easy", "Difficulty: Normal"], "difficulty toggles normal > hard > easy > normal")
	check(is_equal_approx(mults[1], 1.5) and is_equal_approx(mults[2], 0.67) and is_equal_approx(mults[3], 1.0), "enemy values scale x1.5 on hard, x0.67 on easy")
	Settings.difficulty = Settings.Difficulty.HARD
	check(is_equal_approx(Config.enemy_stat("goblin", "speed"), Config.ENEMIES["goblin"]["speed"] * 1.5) and Config.enemy_stat_int("goblin", "gold_on_kill") == roundi(Config.ENEMIES["goblin"]["gold_on_kill"] * 1.5), "difficulty scales speed and loot too")
	Settings.difficulty = Settings.Difficulty.NORMAL
	await tap(center(title.levels_button))
	check(title.levels_panel.visible, "Levels button opens the level list")
	title.queue_free()
	await frames(2)


func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures.append(msg)


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout:
			return false
	return true


func wait(seconds: float) -> void:
	await wait_until(func() -> bool: return false, seconds)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- input helpers -----------------------------------------------------------------

func mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func motion(pos: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func tap(pos: Vector2) -> void:
	mouse(pos, true)
	await frames(1)
	mouse(pos, false)
	await frames(2)


func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func screen(world_pos: Vector2) -> Vector2:
	return game.camera.world_to_screen(world_pos)


# --- helpers ----------------------------------------------------------------------

var _guard_touched := false


func check_silent_guard(g: Gatherer, guarded: Corpse) -> void:
	if is_instance_valid(guarded) and g.target == guarded:
		_guard_touched = true


func find_spot(kind: String, near: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			if game.construction.placement_error(kind, t) == "":
				var d := Vector2(t).distance_to(Vector2(near))
				if d < best_d:
					best_d = d
					best = t
	return best


## Every villager lives in exactly one intact hut, and each hut holds at most one.
func residency_ok() -> bool:
	var seen := {}
	for c in game.population.civilians:
		if not is_instance_valid(c.hut) or c.hut.resident != c or not c.hut.is_intact() or seen.has(c.hut):
			return false
		seen[c.hut] = true
	for h in game.world.huts():
		if h.resident != null and not game.population.civilians.has(h.resident):
			return false
	return true


func civs(role: String) -> Array:
	return game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == role)


# --- the test run -----------------------------------------------------------------

func _run() -> void:
	await _test_title()
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	game.map_seed = SEED
	game.reveal_map = false  # the test needs real fog, whatever config.gd says
	game.disable_fog = false
	add_child(game)
	await frames(3)
	var hud := game.hud
	var map := game.map
	print("viewport ", get_viewport().get_visible_rect().size)

	check(not hud._overlay.visible and not get_tree().paused, "no pop-up over the level; it starts right away")

	# --- camera, sidebar, fullscreen -----------------------------------------------
	var cam := game.camera
	var cam0 := cam.position
	var from := Vector2(400, 400)
	mouse(from, true)
	await frames(1)
	for i in range(1, 9):
		motion(from + Vector2(-20.0 * i, -10.0 * i), Vector2(-20, -10))
		await frames(1)
	mouse(from + Vector2(-160, -80), false)
	await frames(2)
	check(cam.position.distance_to(cam0) > 50.0, "dragging the map pans the camera")
	var z0 := cam.zoom.x
	for i in 3:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = Vector2(400, 400)
		get_viewport().push_input(wheel, true)
		await frames(1)
	check(cam.zoom.x > z0, "mouse wheel zooms in")
	for i in 40:
		cam.zoom_at(Vector2(400, 400), 1.3)
	check(is_equal_approx(cam.zoom.x, CameraController.MAX_ZOOM), "zoom stops at its maximum")
	cam.position = Vector2(1e6, 1e6)
	cam.focus(cam.position)
	check(cam.bounds.has_point(cam.position) or cam.position.is_equal_approx(cam.bounds.end), "the camera can't leave the map")
	cam.zoom = Vector2(0.75, 0.75)
	cam.focus(Iso.tile_to_world(Config.VILLAGE_CENTER))
	await frames(2)
	await tap(center(hud._sidebar_toggle))
	check(not hud._sidebar.visible, "sidebar collapses")
	await tap(center(hud._sidebar_toggle))
	check(hud._sidebar.visible, "and expands again")
	check(hud._fullscreen_button.is_visible_in_tree() and hud._fullscreen_button.pressed.is_connected(hud.toggle_fullscreen), "fullscreen button is present and wired")

	# --- HUD layout & speed button ------------------------------------------------
	var vp := get_viewport().get_visible_rect().size
	await frames(2)
	check(absf(hud._sidebar.get_global_rect().end.x - vp.x) < 1.0, "sidebar is flush with the right screen edge (%.0f vs %.0f)" % [hud._sidebar.get_global_rect().end.x, vp.x])
	check(hud._topbar.get_global_rect().end.x <= vp.x + 0.5 and hud._topbar.get_combined_minimum_size().x <= 1280.0, "top bar fits a 1280px-wide screen (needs %.0f)" % hud._topbar.get_combined_minimum_size().x)
	check(hud._sidebar_toggle.get_global_rect().end.x <= hud._sidebar.get_global_rect().position.x, "sidebar toggle sits left of the sidebar")
	var speeds_seen: Array[String] = []
	for i in 4:
		await tap(center(hud._speed_button))
		speeds_seen.append("paused" if get_tree().paused else "%dx" % int(Engine.time_scale))
	check(speeds_seen == ["2x", "4x", "paused", "1x"], "one speed button cycles 1x > 2x > 4x > paused > 1x (%s)" % str(speeds_seen))
	await wait(2.0)
	check(game.waves.countdown < Config.FIRST_WAVE_DELAY and game.waves.wave == 0, "first wave counts down on its own (%.1fs left)" % game.waves.countdown)
	game.waves.countdown = 99999.0  # hold the first wave while the economy is tested

	# --- map -------------------------------------------------------------------
	var total := map.size * map.size
	var forest := map.count_terrain(MapData.Terrain.FOREST)
	var desert := map.count_terrain(MapData.Terrain.DESERT)
	var mountain := map.count_terrain(MapData.Terrain.MOUNTAIN)
	print("map %dx%d: %d spawns, forest %d%%, desert %d%%, mountain %d%%, road %d tiles" % [map.size, map.size, map.edge_spawns.size(),
		100 * forest / total, 100 * desert / total, 100 * mountain / total, map.count_terrain(MapData.Terrain.ROAD)])
	check(map.size == 75, "map is 75x75")
	# Enemy config is complete and readable.
	var required := ["name", "art", "behavior", "hp", "speed", "damage", "attack_cooldown", "gold_on_kill", "gold_on_collect", "food_on_collect"]
	var cfg_ok := true
	for kind in Config.ENEMIES:
		var e: Dictionary = Config.ENEMIES[kind]
		cfg_ok = cfg_ok and required.all(func(k: String) -> bool: return e.has(k)) and Enemy.BEHAVIORS.has(e["behavior"])
		cfg_ok = cfg_ok and ResourceLoader.exists("res://art/unit_%s.svg" % e["art"]) and ResourceLoader.exists("res://art/corpse_%s.svg" % e["art"])
	check(cfg_ok, "every enemy has all config keys, a known behavior and its art")
	var mix_ok := true
	for n in range(1, 16):
		var comp := Config.wave_composition(n)
		var in_wave := 0
		for k in comp:
			in_wave += comp[k]
		mix_ok = mix_ok and in_wave == Config.wave_size(n)
		for kind in Config.WAVE_MIX:
			if n < Config.WAVE_MIX[kind]["from_wave"] and comp.has(kind):
				mix_ok = false
	check(mix_ok, "wave mix adds up and nobody shows up before their first wave")
	check(not Config.wave_composition(4).has("witch") and Config.wave_composition(5).has("witch"), "witches first appear in wave %d" % Config.WAVE_MIX["witch"]["from_wave"])
	check(not Config.wave_composition(2).has("ork") and Config.wave_composition(3).has("ork"), "orks first appear in wave %d" % Config.WAVE_MIX["ork"]["from_wave"])
	var gob: Dictionary = Config.ENEMIES["goblin"]
	var orc: Dictionary = Config.ENEMIES["ork"]
	var wit: Dictionary = Config.ENEMIES["witch"]
	check(orc["speed"] < gob["speed"] and orc["hp"] > gob["hp"] and orc["damage"] > gob["damage"] * 2.0, "orks: slower, tougher, much harder hitting")
	check(orc["gold_on_kill"] > 0 and orc["gold_on_collect"] == 0 and orc["food_on_collect"] > gob["food_on_collect"], "orks: gold on kill only, more food when gathered")
	check(wit["hp"] < gob["hp"] and wit["damage"] == 0 and wit["gold_on_kill"] > gob["gold_on_kill"] and wit["gold_on_collect"] == 0 and wit["food_on_collect"] <= gob["food_on_collect"], "witches: frail, no melee, rich kill, no gold and little food as corpses")
	check(is_equal_approx(wit["spell_cooldown"], 2.0 * Config.MILITARY["archer"]["levels"][0]["cooldown"]), "witch spell cycle is twice an archer's shot interval")
	Settings.difficulty = Settings.Difficulty.HARD
	check(is_equal_approx(Config.enemy_stat("goblin", "attack_cooldown"), gob["attack_cooldown"]) and is_equal_approx(Config.enemy_stat("witch", "spell_cooldown"), wit["spell_cooldown"]), "difficulty never stretches cooldowns")
	Settings.difficulty = Settings.Difficulty.NORMAL
	check(forest > total * 0.45, "mostly forest (%d%%)" % (100 * forest / total))
	check(desert > 0 and desert <= total * Config.DESERT_MAX_SHARE, "some desert, at most 20%")
	var desert_near := false
	var mountain_bad := false
	var mountain_border := 0
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if map.is_desert(t) and Vector2(t).distance_to(Vector2(Config.VILLAGE_CENTER)) < Config.DESERT_MIN_VILLAGE_DIST:
				desert_near = true
			if map.is_mountain(t):
				if mini(mini(x, y), mini(map.size - 1 - x, map.size - 1 - y)) < Config.MOUNTAIN_BORDER_BAND + 4:
					mountain_border += 1
				for dy in range(-Config.MOUNTAIN_ROAD_MARGIN, Config.MOUNTAIN_ROAD_MARGIN + 1):
					for dx in range(-Config.MOUNTAIN_ROAD_MARGIN, Config.MOUNTAIN_ROAD_MARGIN + 1):
						mountain_bad = mountain_bad or map.is_road(t + Vector2i(dx, dy))
	check(not desert_near, "no desert next to the village")
	check(mountain > 20 and not mountain_bad, "mountain ranges, clear of roads")
	check(mountain_border >= mountain * 0.9, "mountains lie near the map border")
	# Meadow buffer: few forest tiles touch desert directly.
	var desert_edge := 0
	var forest_touching := 0
	for i in total:
		if map.terrain[i] != MapData.Terrain.DESERT:
			continue
		var dt := Vector2i(i % map.size, i / map.size)
		for nb in MapData.neighbors4(dt):
			if map.in_bounds(nb) and not map.is_desert(nb):
				desert_edge += 1
				if map.is_forest(nb):
					forest_touching += 1
	check(forest_touching < desert_edge * 0.3, "meadow mostly separates desert from forest (%d of %d desert edges touch forest)" % [forest_touching, desert_edge])
	check(map.gates.all(func(g: Vector2i) -> bool: return map.is_road(g)), "gate tiles are dirt road")
	var layout_ok := true
	for row in 5:
		for col in 5:
			var t := Config.VILLAGE_ORIGIN + Vector2i(col, row)
			var b: Building = map.building_at(t)
			var want: String = {"T": "wall_tower", "W": "wall", "G": "gate", "V": "hut"}[Config.VILLAGE_LAYOUT[row][col]]
			if b == null or b.kind != want:
				layout_ok = false
	check(layout_ok, "village matches the TWGWT layout")
	check(map.gates.size() == 4, "4 gates")
	check(map.edge_spawns.size() >= 4, "at least 4 edge spawns")
	var all_reach := true
	for s in map.edge_spawns:
		if game.world.pathing.enemy_distance(s) >= Pathing.UNREACHABLE:
			all_reach = false
	check(all_reach, "every edge spawn reaches a gate by road")
	var road_in_village := false
	for y in range(map.village_rect.position.y + 1, map.village_rect.end.y - 1):
		for x in range(map.village_rect.position.x + 1, map.village_rect.end.x - 1):
			road_in_village = road_in_village or map.is_road(Vector2i(x, y))
	check(not road_in_village, "no road inside the village walls")
	var route := game.world.pathing.enemy_route(map.edge_spawns[0], RandomNumberGenerator.new())
	check(map.gates.has(route[-1]) and route.all(func(t: Vector2i) -> bool: return map.is_road(t) or map.gates.has(t)), "enemy route stays on roads and ends at a gate")

	# --- start state -----------------------------------------------------------
	check(game.population.count() == 3 and game.population.cap() == 9, "3 civilians, 9 huts")
	check(civs("builder").size() == 1 and civs("farmer").size() == 1 and civs("explorer").size() == 1, "one builder, farmer, explorer")
	check(residency_ok(), "each starting villager lives in its own hut")
	var wall_towers := game.world.towers().filter(func(t: Tower) -> bool: return t.kind == "wall_tower")
	check(wall_towers.size() == 4 and wall_towers.all(func(t: Tower) -> bool: return t.garrison == null), "4 unmanned wall towers")
	var o := Config.VILLAGE_ORIGIN
	check(game.world.pathing.astar.is_point_solid(o + Vector2i(0, 1)) and not game.world.pathing.astar.is_point_solid(o + Vector2i(2, 0)), "walls block, gates don't")
	var some_forest: Vector2i = map.props.keys().filter(func(t: Vector2i) -> bool: return map.is_forest(t))[0]
	var some_mountain: Vector2i = map.props.keys().filter(func(t: Vector2i) -> bool: return map.is_mountain(t))[0]
	check(game.world.pathing.astar.is_point_solid(some_forest) and game.world.pathing.astar.is_point_solid(some_mountain), "forest and mountains block villagers")
	check(map.farm_plot != Vector2i(-1, -1) and game.construction.placement_error("farm", map.farm_plot) in ["", "Not enough building material"], "a farm fits near the village at the start")
	var desert_tile: Vector2i = Vector2i(-1, -1)
	for i in total:
		var dt := Vector2i(i % map.size, i / map.size)
		var all_desert := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				all_desert = all_desert and map.is_desert(dt + Vector2i(dx, dy))
		if all_desert:
			desert_tile = dt
			break
	game.fog.reveal(Vector2(desert_tile), 2.0)
	game.economy.add("materials", 1000)
	check(game.construction.placement_error("farm", desert_tile) == "Nothing grows in the desert", "no farms in the desert")
	check(game.construction.placement_error("tower", some_mountain) != "", "nothing on mountains")
	game.economy.add("materials", -1000)
	var explored0 := game.fog.explored_count()
	check(explored0 > 50 and explored0 < 300, "fog of war around the village (%d tiles explored)" % explored0)

	Engine.time_scale = 6.0

	# --- explorer ---------------------------------------------------------------
	await wait(25.0)
	var explored1 := game.fog.explored_count()
	check(explored1 > explored0 + 15, "explorer reveals the map (%d -> %d)" % [explored0, explored1])
	# Surveillance: explored land near the (unmanned) village isn't watched;
	# land around a villager outside is.
	var ex0: Explorer = civs("explorer")[0]
	check(not game.fog.is_watched(Config.VILLAGE_CENTER + Vector2i(0, -6)) or not ex0.at_home, "explored land without observers is only darkened")
	# Buildings watch their surroundings: huts 4 tiles, gates and others 3.
	var hut_ok := true
	var gate_ok := true
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if not map.is_explored(t):
				continue
			for h in game.world.intact_huts():
				if Vector2(t).distance_to(Vector2(h.tile)) <= Config.HUT_SIGHT and not map.is_watched(t):
					hut_ok = false
			for g in map.gates:
				if Vector2(t).distance_to(Vector2(g)) <= Config.GATE_SIGHT and not map.is_watched(t):
					gate_ok = false
	check(hut_ok, "every tile within %d of a hut is under surveillance" % int(Config.HUT_SIGHT))
	check(gate_ok, "every tile within %d of an (unmanned) gate is under surveillance" % int(Config.GATE_SIGHT))
	if not ex0.at_home:
		check(game.fog.is_watched(ex0.current_tile()), "land around a villager outside is under surveillance")

	# --- construction: watchtower ------------------------------------------------
	var mats := game.economy.amount("materials")
	var spot := find_spot("tower", Config.VILLAGE_CENTER + Vector2i(0, -5))
	check(spot != Vector2i(-1, -1), "found a spot for a watchtower")
	check(game.construction.placement_error("tower", Vector2i(25, 25)) != "", "can't build inside the village")
	var road_tile: Vector2i = map.gates[0] + (map.gates[0] - Config.VILLAGE_CENTER).sign()
	check(game.construction.placement_error("tower", road_tile) != "", "can't build on a road")
	# Place it through the real UI: Build tab button, then tap the tile.
	await tap(center(hud._build_buttons["tower"]))
	check(game.mode == Game.Mode.BUILD, "build button enters build mode")
	await tap(screen(Iso.tile_to_world(spot)))
	var watchtower: Tower = map.building_at(spot)
	check(watchtower != null and not watchtower.complete, "tap placed a construction site")
	check(game.economy.amount("materials") == mats - 30, "watchtower cost 30 materials")
	game.cancel_mode()
	var builder: Builder = civs("builder")[0]
	await wait_until(func() -> bool: return builder.state == Builder.State.TO_SITE or builder.state == Builder.State.BUILDING, 10.0)
	check(builder.visible and builder.site == watchtower, "builder leaves the village for the site")
	var done := await wait_until(func() -> bool: return watchtower.complete, 60.0)
	check(done, "builder completes the watchtower")
	check(game.world.pathing.astar.is_point_solid(spot), "finished tower blocks walking")
	await wait_until(func() -> bool: return builder.at_home, 30.0)
	check(builder.at_home, "builder walks back home")

	# --- trade + farm -------------------------------------------------------------
	var gold := game.economy.amount("gold")
	await tap(center(hud._materials_button))
	check(hud._trade_panel.visible, "tapping materials opens the trade dialog")
	await tap(center(hud._trade_buttons[0]))
	check(game.economy.amount("gold") == gold - 15 and game.economy.amount("materials") == mats - 30 + 10, "bought 10 materials for 15 gold")
	hud._trade_panel.visible = false
	var farm_spot := find_spot("farm", Config.VILLAGE_CENTER + Vector2i(5, 0))
	check(farm_spot != Vector2i(-1, -1), "found a 3x3 farm spot")
	var farm: Farm = game.construction.place("farm", farm_spot)
	check(farm != null and game.economy.amount("materials") == 0, "farm placed for 50 materials")
	check(game.construction.placement_error("tower", farm_spot + Vector2i(1, 1)) != "", "farm occupies its 3x3 footprint")
	done = await wait_until(func() -> bool: return farm.complete, 90.0)
	check(done, "builder completes the farm")
	check(game.population.assign_farmer(farm), "farmer assigned to the farm")
	check(not game.population.assign_farmer(farm), "a farm holds only one farmer")
	var farmer: Farmer = civs("farmer")[0]
	var food_before := game.economy.amount("food")
	var got_food := await wait_until(func() -> bool: return farmer.state == Farmer.State.RETURNING and farmer.carrying > 0, 90.0)
	check(got_food, "farmer harvests food at the farm")
	var carried := farmer.carrying
	var f0 := game.economy.amount("food")
	await wait_until(func() -> bool: return farmer.at_home, 60.0)
	check(game.economy.amount("food") > f0 + carried * 0.5, "farmer delivers food home (+%d)" % carried)
	check(food_before > 0.0, "upkeep leaves food positive so far")

	# --- light stone --------------------------------------------------------------------
	game.economy.add("materials", 500)
	var ls_spot := find_spot("lightstone", Config.VILLAGE_CENTER + Vector2i(0, 7))
	var ls: LightStone = game.construction.place("lightstone", ls_spot)
	check(ls != null, "light stone placed")
	await wait_until(func() -> bool: return ls.complete, 90.0)
	check(ls.complete and game.world.pathing.astar.is_point_solid(ls_spot), "builder raises the light stone (it blocks walking)")
	await wait(0.5)
	var lit := true
	for y in range(-6, 7):
		for x in range(-6, 7):
			var t := ls_spot + Vector2i(x, y)
			if map.is_explored(t) and Vector2(x, y).length() <= Config.LIGHTSTONE_SIGHT and not map.is_watched(t):
				lit = false
	check(lit, "light stone keeps %.1f tiles under surveillance without anyone in it" % Config.LIGHTSTONE_SIGHT)
	var ls_building: Building = ls
	check(not (ls_building is Tower) and game.army.station_error(null, game.world.pick_building(ls.position + Vector2(0, -40)) as Tower) != "", "nobody can be stationed on a light stone")

	# --- worker camp & forester ----------------------------------------------------------
	var camp_spot := Vector2i(-1, -1)
	var best_trees := 0
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if game.construction.placement_error("camp", t) != "":
				continue
			var n := 0
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					if game.world.is_tree(t + Vector2i(dx, dy)) and map.is_explored(t + Vector2i(dx, dy)):
						n += 1
			if n > best_trees:
				best_trees = n
				camp_spot = t
	var camp: WorkerCamp = game.construction.place("camp", camp_spot)
	check(camp != null, "worker camp placed near the forest (%d trees around)" % best_trees)
	await wait_until(func() -> bool: return camp.complete, 90.0)
	check(camp.complete, "builder puts up the worker camp")
	game.economy.add("food", 100)
	var fo: Forester = game.population.recruit("forester")
	check(fo != null and game.population.assign_forester(camp), "forester recruited and assigned to the camp")
	check(not game.population.assign_forester(camp), "a camp holds only one forester")
	await wait_until(func() -> bool: return fo.state == Forester.State.CHOPPING, 90.0)
	var the_tree := fo.tree
	check(fo.state == Forester.State.CHOPPING and game.world.is_tree(the_tree), "forester walks from the camp to a tree and chops it")
	check(is_equal_approx(game.world.tree_chop_time(the_tree), Config.TREE_CHOP_TIME[map.props[the_tree]]), "chop time comes from the tree type (%s: %.0fs)" % [map.props[the_tree], game.world.tree_chop_time(the_tree)])
	var mats0 := game.economy.amount("materials")
	await wait_until(func() -> bool: return fo.state == Forester.State.AT_CAMP, 60.0)
	check(game.economy.amount("materials") >= mats0 + Config.FORESTER_MATERIAL_PER_TRIP, "back at the camp, the forester delivers building material")
	check(game.world.is_tree(the_tree) and game.world.tree_progress(the_tree) > 0.0, "the tree is partly chopped (%d%%)" % int(100 * game.world.tree_progress(the_tree)))
	await wait_until(func() -> bool: return fo.state == Forester.State.CHOPPING, 60.0)
	check(fo.tree == the_tree, "the forester returns to the same tree")
	game.world._chopped[the_tree] = game.world.tree_chop_time(the_tree) - 0.3
	await wait_until(func() -> bool: return not game.world.is_tree(the_tree), 10.0)
	check(map.get_terrain(the_tree) == MapData.Terrain.GRASS and game.world.pathing.is_walkable(the_tree), "a felled tree leaves walkable meadow")
	await wait_until(func() -> bool: return fo.state == Forester.State.CHOPPING, 90.0)
	check(fo.tree != the_tree and game.world.is_tree(fo.tree), "the forester moves on to the next tree")
	game.population.unassign_forester(camp)

	# --- army: recruit + drag & drop onto a wall tower ------------------------------
	game.economy.add("gold", 500)
	hud._select_tab("army")
	await frames(2)
	var gold2 := game.economy.amount("gold")
	await tap(center(hud._military_buttons["archer"]))
	check(game.army.reserve().size() == 1 and game.economy.amount("gold") == gold2 - 40, "archer recruited for 40 gold")
	await frames(2)
	var card: Button = hud._reserve_grid.get_child(0)
	var wt: Tower = wall_towers[0]
	var target := screen(wt.position + Vector2(0, -50))
	var start := center(card)
	mouse(start, true)
	await frames(1)
	var steps := 8
	for i in range(1, steps + 1):
		motion(start.lerp(target, float(i) / steps))
		await frames(1)
	mouse(target, false)
	await frames(2)
	check(wt.incoming != null and wt.garrison == null, "dragged archer marches out (not instantly on the tower)")
	check(game.army.reserve().is_empty() and game.army.walking().size() == 1, "marching archer has left the reserve")
	check(not game.fog.is_watched(wt.tile + Vector2i(-3, -3)) or game.army.walking().size() == 1, "unmanned wall tower doesn't watch")
	var arrived := await wait_until(func() -> bool: return wt.garrison != null, 30.0)
	check(arrived, "archer reaches the wall tower and mans it")
	await frames(2)
	check(game.fog.is_watched(wt.tile + Vector2i(-3, -3)), "a manned tower keeps its whole range under surveillance")
	# Tap mode: tap a card, then tap the new watchtower.
	await tap(center(hud._military_buttons["archer"]))
	await frames(2)
	card = hud._reserve_grid.get_child(0)
	await tap(center(card))
	check(game.mode == Game.Mode.STATION, "tapping a reserve card enters station mode")
	await tap(screen(watchtower.position + Vector2(0, -40)))
	check(watchtower.incoming != null, "tap-to-station sends an archer to the watchtower")
	await wait_until(func() -> bool: return watchtower.garrison != null, 60.0)
	check(watchtower.garrison != null, "archer arrives at the watchtower")
	var unit := watchtower.garrison
	# Withdraw: the archer walks home before it's back in the reserve.
	game.army.unstation(unit)
	check(watchtower.garrison == null and unit.state == MilitaryUnit.State.RETURNING and not game.army.reserve().has(unit), "withdrawn archer walks home first")
	await wait_until(func() -> bool: return unit.state == MilitaryUnit.State.RESERVE, 60.0)
	check(game.army.reserve().has(unit), "withdrawn archer is back in the reserve")
	game.army.station(unit, watchtower)
	await wait_until(func() -> bool: return watchtower.garrison != null, 60.0)
	check(game.army.upgrade(unit) and unit.level == 1, "archer upgraded with gold")
	# Man the other wall towers too.
	for t in wall_towers.slice(1):
		game.army.station(game.army.recruit("archer"), t)
	await wait_until(func() -> bool: return wall_towers.all(func(t: Tower) -> bool: return t.garrison != null), 60.0)
	check(wall_towers.all(func(t: Tower) -> bool: return t.garrison != null), "all wall towers manned")
	# Balance comes later: make the defence sturdy so the rest of the run is deterministic.
	game.economy.add("gold", 5000)
	for u in game.army.units:
		while u.can_upgrade():
			game.army.upgrade(u)

	# --- waves ----------------------------------------------------------------------
	var gold3 := game.economy.amount("gold")
	game.waves.countdown = 2.0
	var started := await wait_until(func() -> bool: return game.waves.wave == 1, 5.0)
	check(started and game.waves.in_progress(), "wave 1 starts by itself when the timer runs out")
	var warned := await wait_until(func() -> bool: return not game.world.warnings.spots.is_empty(), 20.0)
	check(warned, "early wave on normal: a red warning light marks where hidden enemies are headed")
	if warned:
		var wspot: Vector2 = game.world.warnings.spots[0]
		var near_watched := false
		var near_unwatched := false
		for d in [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
			var t := Vector2i((wspot + d).round())
			near_watched = near_watched or game.fog.is_watched(t)
			near_unwatched = near_unwatched or not game.fog.is_watched(t)
		check(near_watched and near_unwatched, "the light sits on the edge between hidden and watched land")
	Settings.difficulty = Settings.Difficulty.HARD
	check(not game.world.warnings.enabled(), "no warning lights on hard")
	Settings.difficulty = Settings.Difficulty.EASY
	check(game.world.warnings.enabled(), "warning lights on easy")
	Settings.difficulty = Settings.Difficulty.NORMAL
	var real_wave := game.waves.wave
	game.waves.wave = Config.WARNING_LIGHT_WAVES + 1
	check(not game.world.warnings.enabled(), "no warning lights after wave %d" % Config.WARNING_LIGHT_WAVES)
	game.waves.wave = real_wave
	await frames(2)
	check(hud._enemies_label.text == str(game.waves.enemies_left()) and game.waves.enemies_left() == Config.wave_size(1), "HUD shows the enemy count (%s)" % hud._enemies_label.text)
	var cleared := await wait_until(func() -> bool: return not game.waves.in_progress(), 240.0)
	check(cleared, "wave 1 ends")
	print("  wave 1: gold %d -> %d, civilians %d, huts %d" % [gold3, game.economy.amount("gold"), game.population.count(), game.population.cap()])
	check(game.economy.amount("gold") > gold3, "archers killed enemies for gold")
	check(absf(game.waves.countdown - Config.WAVE_BUFFER) < 2.0, "next wave counts down from %ds after the last enemy" % int(Config.WAVE_BUFFER))
	await wait(5.0)
	var bonus := game.waves.early_call_bonus()
	var gold4 := game.economy.amount("gold")
	await tap(center(hud._call_button))
	check(game.waves.wave == 2 and game.economy.amount("gold") == gold4 + bonus and bonus > 0, "calling early starts wave 2 with +%d gold" % bonus)
	await wait_until(func() -> bool: return not game.waves.in_progress(), 240.0)
	var auto := await wait_until(func() -> bool: return game.waves.wave == 3, Config.WAVE_BUFFER + 5.0)
	check(auto, "wave 3 starts automatically after the buffer")
	var skel := game.waves._queue.filter(func(q: Dictionary) -> bool: return q["kind"] == "skeleton").size() + get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.kind == "skeleton").size()
	check(skel > 0, "skeletons march with the goblins in wave 3 (%d)" % skel)
	await wait_until(func() -> bool: return not game.waves.in_progress(), 300.0)
	game.waves.countdown = 99999.0  # hold wave 4

	# --- corpses & gatherer --------------------------------------------------------------
	var cs := game.corpses
	check(cs.count() > 0 and cs.corpses.all(func(c: Corpse) -> bool: return c.wave == 3), "only wave-3 corpses remain (older waves cleared) : %d" % cs.count())
	# Kill payout is instant; the corpse stays where the enemy died.
	var road_spot: Vector2i = map.gates[1] + (map.gates[1] - Config.VILLAGE_CENTER).sign() * 2
	game.waves._spawn({"kind": "goblin", "spawn": road_spot, "hp_scale": 1.0})
	var victim: Enemy = get_tree().get_nodes_in_group("enemies").back()
	victim.speed = 0.0
	var g_before := game.economy.amount("gold")
	var n_before := cs.count()
	victim.take_damage(1e9)
	check(game.economy.amount("gold") == g_before + Config.ENEMIES["goblin"]["gold_on_kill"], "killing pays gold_on_kill instantly")
	check(cs.count() == n_before + 1 and cs.corpses.back().tile() == victim.current_tile(), "a corpse is left where the enemy died")
	game.waves.countdown = 99999.0  # the test goblin's death re-armed the wave timer
	# Skeletons: gold only, no food; bones stay behind.
	game.waves._spawn({"kind": "skeleton", "spawn": road_spot, "hp_scale": 1.0})
	var bones: Enemy = get_tree().get_nodes_in_group("enemies").back()
	bones.speed = 0.0
	var gs := game.economy.amount("gold")
	bones.take_damage(1e9)
	check(bones.kind == "skeleton" and game.economy.amount("gold") == gs + Config.enemy_stat_int("skeleton", "gold_on_kill"), "a killed skeleton pays gold")
	check(cs.corpses.back().kind == "skeleton", "and leaves its bones")
	var no_food := true
	for dif in [Settings.Difficulty.EASY, Settings.Difficulty.NORMAL, Settings.Difficulty.HARD]:
		Settings.difficulty = dif
		no_food = no_food and Config.enemy_stat_int("skeleton", "food_on_collect") == 0 and Config.enemy_stat_int("skeleton", "gold_on_collect") > 0
	Settings.difficulty = Settings.Difficulty.NORMAL
	check(no_food, "skeleton corpses give gold but never food, on every difficulty")
	cs.remove(cs.corpses.back())
	game.waves.countdown = 99999.0
	# Expiry.
	var rotting: Corpse = cs.spawn("goblin", 3, Vector2(road_spot))
	rotting.time_left = 0.05
	await frames(3)
	check(not is_instance_valid(rotting) or not cs.corpses.has(rotting), "uncollected corpses rot away")
	# Wave cleanup: corpses of wave N vanish when wave N+1 is finished.
	var old: Corpse = cs.spawn("goblin", 3, Vector2(road_spot))
	var newer: Corpse = cs.spawn("goblin", 4, Vector2(road_spot))
	game.waves.wave_finished.emit(4)
	check((not is_instance_valid(old) or not cs.corpses.has(old)) and cs.corpses.has(newer), "wave-3 corpses disappear when wave 4 is finished")
	cs.remove(newer)
	# Unsafe corpse: a living goblin stands guard far out on a road, so the
	# gatherer must ignore that corpse (but not the safe ones elsewhere).
	var far_route := game.world.pathing.enemy_route(map.edge_spawns[0], RandomNumberGenerator.new())
	var far_spot: Vector2i = far_route[far_route.size() / 3]
	var guarded: Corpse = cs.spawn("goblin", 3, Vector2(far_spot))
	game.waves._spawn({"kind": "goblin", "spawn": far_spot, "hp_scale": 1000.0})
	var guard: Enemy = get_tree().get_nodes_in_group("enemies").back()
	guard.speed = 0.0
	for t in game.world.towers():
		if t.garrison: game.army.unstation(t.garrison)  # keep the guard alive
	check(not cs.is_safe(guarded) and not cs.available().has(guarded), "corpses next to living enemies are unsafe")
	# Pile of corpses to test capacity and payout.
	var pile_gate: Vector2i = map.gates[0]
	for gt in map.gates:
		if Vector2(gt).distance_to(Vector2(far_spot)) > Vector2(pile_gate).distance_to(Vector2(far_spot)):
			pile_gate = gt
	var pile: Vector2i = pile_gate + (pile_gate - Config.VILLAGE_CENTER).sign() * 2
	check(cs.is_safe(cs.spawn("goblin", 3, Vector2(pile))), "corpses away from enemies are safe")
	for i in Config.GATHERER_CAPACITY + 2:
		cs.spawn("goblin", 3, Vector2(pile))
	game.economy.add("food", 200)
	game.population.civilian_lost.connect(func(c: Civilian) -> void: print("  LOST %s food=%.0f pop=%d cap=%d enemies=%d" % [c.role, game.economy.amount("food"), game.population.count(), game.population.cap(), game.waves.enemies_left()]))
	var gatherer: Gatherer = game.population.recruit("gatherer")
	check(gatherer != null, "gatherer recruited with food")
	var max_carried := 0
	var trip_done := false
	var g0 := game.economy.amount("gold")
	var f0g := game.economy.amount("food")
	var t_run := 0.0
	var delivered := 0
	while t_run < 120.0:
		await get_tree().process_frame
		t_run += get_process_delta_time()
		game.waves.countdown = 99999.0
		max_carried = maxi(max_carried, gatherer.carried.size())
		check_silent_guard(gatherer, guarded)
		if gatherer.state == Gatherer.State.RETURNING and gatherer.carried.size() > 0:
			delivered = gatherer.carried.size()
			await wait_until(func() -> bool: return gatherer.at_home, 60.0)
			trip_done = true
			break
	check(trip_done, "gatherer fetches corpses and walks home")
	check(max_carried == Config.GATHERER_CAPACITY, "gatherer carries up to %d corpses per trip (%d)" % [Config.GATHERER_CAPACITY, max_carried])
	var exp_gold: int = delivered * Config.ENEMIES["goblin"]["gold_on_collect"]
	var exp_food: int = delivered * Config.ENEMIES["goblin"]["food_on_collect"]
	check(game.economy.amount("gold") >= g0 + exp_gold, "delivery pays gold_on_collect (+%d)" % exp_gold)
	check(game.economy.amount("food") >= f0g + exp_food - 10.0, "delivery pays food_on_collect (+%d)" % exp_food)
	check(not _guard_touched, "gatherer never went for the guarded corpse")
	guard.take_damage(1e9)
	game.waves.countdown = 99999.0
	cs.clear_wave(99)
	for t in game.world.towers():
		if t.garrison == null and t.incoming == null and not game.army.reserve().is_empty():
			game.army.station(game.army.reserve()[0], t)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)

	# --- tower panel, tower levels -------------------------------------------------------
	game.waves.countdown = 99999.0
	var labels: Array = watchtower.info()["actions"].map(func(x: Dictionary) -> String: return x["label"])
	check(labels.size() == 2 and labels[0].begins_with("Upgrade tower") and labels[1] == "Withdraw", "tower panel offers only Upgrade tower and Withdraw (%s)" % str(labels))
	var empty_tower: Tower = null
	for t in game.world.towers():
		if t.complete and t.garrison == null and t.incoming == null:
			empty_tower = t
	if empty_tower:
		var el: Array = empty_tower.info()["actions"].map(func(x: Dictionary) -> String: return x["label"])
		check(not el.any(func(l: String) -> bool: return "Send" in l or "Station" in l or "rcher" in l), "unmanned tower has no station button (%s)" % str(el))
	check(watchtower.level == 1 and wall_towers.all(func(t: Tower) -> bool: return t.level == 1), "all towers start at level 1")
	game.economy.add("materials", 200)
	var r1 := watchtower.range_tiles()
	var m1 := game.economy.amount("materials")
	check(game.construction.order_upgrade(watchtower) and game.economy.amount("materials") == m1 - Config.TOWER_LEVELS[1]["cost"]["materials"], "tower upgrade ordered for building material")
	check(watchtower.upgrading and watchtower.complete and watchtower.garrison != null, "tower stays finished and manned while upgrading")
	game.waves._spawn({"kind": "goblin", "spawn": far_spot, "hp_scale": 1000.0})
	var dummy: Enemy = get_tree().get_nodes_in_group("enemies").back()
	dummy.speed = 0.0
	dummy.set_grid_pos(Vector2(watchtower.tile) + Vector2(2.0, 0.0))
	var hp_start := dummy.hp
	var fired_during := await wait_until(func() -> bool: return dummy.hp < hp_start and watchtower.upgrading, 10.0)
	check(fired_during, "the stationed unit keeps shooting while the tower is being upgraded")
	dummy.take_damage(1e9)  # (a goblin this close would make the builder flee)
	var up_done := await wait_until(func() -> bool: return not watchtower.upgrading and watchtower.level == 2, 120.0)
	check(up_done and watchtower.level == 2, "a builder completes the tower upgrade")
	check(is_equal_approx(watchtower.range_tiles(), r1 + Config.TOWER_LEVELS[1]["range_bonus"]), "tower level raises the unit's range (%.1f -> %.1f)" % [r1, watchtower.range_tiles()])
	check(watchtower.sprite.texture == Art.tex("watchtower_2"), "level 2 tower looks different")
	game.waves.countdown = 99999.0

	# --- summoner & earth elementals ------------------------------------------------------
	game.economy.add("gold", 2000)
	var sm_tower: Tower = wall_towers[1]
	if sm_tower.garrison:
		game.army.unstation(sm_tower.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	var summoner := game.army.recruit("summoner")
	check(summoner != null and summoner.kind == "summoner", "summoner recruited with gold")
	game.army.station(summoner, sm_tower)
	await wait_until(func() -> bool: return sm_tower.garrison == summoner, 60.0)
	check(sm_tower.garrison == summoner and sm_tower._unit_sprite.texture == Art.tex("unit_summoner"), "summoner stands on the tower")
	var sb: SummonerBehavior = summoner.behavior
	await wait(8.0)
	check(sb.summons.is_empty(), "no summons while no enemy is in sight")
	# A tough, stationary goblin next to the tower.
	var sm_spot := Vector2i(-1, -1)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := sm_tower.tile + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(sm_tower.tile))
			if sm_spot == Vector2i(-1, -1) and d >= 2.0 and d <= 3.0 and not map.in_village(t) and game.world.pathing.is_walkable(t):
				sm_spot = t
	game.waves._spawn({"kind": "goblin", "spawn": far_spot, "hp_scale": 1000.0})
	var brute: Enemy = get_tree().get_nodes_in_group("enemies").back()
	brute.speed = 0.0
	brute.set_grid_pos(Vector2(sm_spot))
	for t in game.world.towers():
		if t.garrison and t.garrison.kind == "archer":
			game.army.unstation(t.garrison)  # let the elementals do the fighting
	var got := await wait_until(func() -> bool: return sb.summons.size() >= 1, 20.0)
	check(got, "summoner summons earth elementals when an enemy comes into sight")
	var first: EarthElemental = sb.summons[0] if got else null
	if first:
		check(is_equal_approx(first.max_hp, Config.ENEMIES["goblin"]["hp"]) and is_equal_approx(first.damage, Config.ENEMIES["goblin"]["damage"]), "a level-1 elemental is as strong as a goblin")
	await wait(Config.MILITARY["summoner"]["levels"][0]["interval"] * 4.0)
	check(sb.summons.size() <= int(summoner.stat("max_summons")), "summons never exceed the cap (%d/%d)" % [sb.summons.size(), int(summoner.stat("max_summons"))])
	var hp_b := brute.hp
	var fought := await wait_until(func() -> bool: return brute.hp < hp_b and sb.summons.any(func(e) -> bool: return is_instance_valid(e) and e.hp < e.max_hp), 30.0)
	if not fought:
		print("  detail: brute at %s hp %.0f/%.0f; summons: %s" % [brute.grid_pos, brute.hp, hp_b, str(sb.summons.map(func(e) -> String: return "%s tgt=%s hp=%.0f path=%d/%d" % [e.grid_pos, e.target != null, e.hp, e.path_index, e.path.size()]))])
	check(fought, "elementals fight the enemy in close combat, and it fights back")
	var corpses_before := cs.count()
	var doomed: EarthElemental = sb.summons[0] if not sb.summons.is_empty() else null
	if doomed:
		doomed.take_damage(1e9)
		await frames(3)
		check(doomed.dead and cs.count() == corpses_before, "a slain elemental leaves no corpse")
	var survivor: EarthElemental = null
	for e in sb.summons:
		if is_instance_valid(e) and not e.dead:
			survivor = e
	var old_hp := survivor.max_hp if survivor else 0.0
	var old_cap := int(summoner.stat("max_summons"))
	var old_interval := summoner.stat("interval")
	check(game.army.upgrade(summoner), "summoner upgraded with gold")
	check(summoner.stat("interval") < old_interval and int(summoner.stat("max_summons")) > old_cap, "upgrade: faster summoning and a higher cap")
	var is_new := func(e) -> bool: return is_instance_valid(e) and not e.dead and e != survivor and is_equal_approx(e.max_hp, summoner.stat("summon_hp"))
	await wait_until(func() -> bool: return sb.summons.any(is_new), 30.0)
	var newest: Array = sb.summons.filter(is_new)
	check(not newest.is_empty(), "new summons get the upgraded stats")
	if survivor and is_instance_valid(survivor):
		check(is_equal_approx(survivor.max_hp, old_hp), "existing summons keep their old stats")
	game.army.unstation(summoner)
	await frames(3)
	check(sb.summons.is_empty() and get_tree().get_nodes_in_group("summons").is_empty(), "withdrawing the summoner dismisses its elementals")
	brute.take_damage(1e9)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	game.waves.countdown = 99999.0

	# --- ork ---------------------------------------------------------------------------------
	game.waves._spawn({"kind": "ork", "spawn": far_spot, "hp_scale": 1.0})
	var brute_ork: Enemy = get_tree().get_nodes_in_group("enemies").back()
	check(brute_ork.kind == "ork" and brute_ork.behavior is MeleeBehavior and brute_ork.max_hp == Config.enemy_stat("ork", "hp"), "orks spawn with their own stats and melee behavior")
	var g_ork := game.economy.amount("gold")
	brute_ork.take_damage(1e9)
	check(game.economy.amount("gold") == g_ork + Config.enemy_stat_int("ork", "gold_on_kill") and cs.corpses.back().kind == "ork", "a killed ork pays gold and leaves a corpse")
	cs.remove(cs.corpses.back())
	game.waves.countdown = 99999.0

	# --- witch: bewitches manned towers --------------------------------------------------------
	var wt_tower: Tower = watchtower
	if wt_tower.garrison == null:
		game.army.station(game.army.recruit("archer"), wt_tower)
		await wait_until(func() -> bool: return wt_tower.garrison != null, 60.0)
	var wspot2 := Vector2i(-1, -1)
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var t := wt_tower.tile + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(wt_tower.tile))
			if wspot2 == Vector2i(-1, -1) and d >= 3.0 and d <= 4.0 and game.world.pathing.is_walkable(t) and not map.in_village(t):
				wspot2 = t
	game.waves._spawn({"kind": "witch", "spawn": far_spot, "hp_scale": 1000.0})
	var hag: Enemy = get_tree().get_nodes_in_group("enemies").back()
	hag.speed = 0.0
	hag.set_grid_pos(Vector2(wspot2))
	check(hag.kind == "witch" and hag.behavior is WitchBehavior, "witch spawned with the witch behavior")
	var bewitched := await wait_until(func() -> bool: return wt_tower.is_enchanted(), 10.0)
	check(bewitched, "a witch in range bewitches the manned tower with her spell")
	check(wt_tower._spell_glow.visible, "the bewitched unit has a pink glow around its head")
	var expected_enchant: float = Config.ENEMIES["witch"]["spell_cooldown"] * Config.ENEMIES["witch"]["enchant_ratio"]
	check(wt_tower.enchanted <= expected_enchant + 0.01 and wt_tower.enchanted > expected_enchant - 0.5, "the spell lasts %.0f%% of her cooldown (%.2fs)" % [100 * Config.ENEMIES["witch"]["enchant_ratio"], expected_enchant])
	# While bewitched the unit fires nothing new.
	var seen_arrows := {}
	for n in game.world.effects.get_children():
		if n is Arrow:
			seen_arrows[n] = true
	var fired_while_bewitched := false
	var t_w := 0.0
	while wt_tower.is_enchanted() and t_w < 3.0:
		await get_tree().process_frame
		t_w += get_process_delta_time()
		for n in game.world.effects.get_children():
			if n is Arrow and not seen_arrows.has(n) and (n as Arrow).source == wt_tower:
				fired_while_bewitched = true
	check(not fired_while_bewitched, "a bewitched unit does not shoot")
	var gap := await wait_until(func() -> bool: return not wt_tower.is_enchanted(), 3.0)
	check(gap, "between casts the unit gets a short window to act")
	hag.take_damage(1e9)
	await wait(0.5)

	# --- witch vs summoner: attacker first, spells hurt elementals -------------------------------
	var sm2 := summoner
	var sm_t: Tower = wall_towers[1]
	if sm2.state != MilitaryUnit.State.STATIONED:
		await wait_until(func() -> bool: return sm2.state == MilitaryUnit.State.RESERVE, 60.0)
		game.army.station(sm2, sm_t)
		await wait_until(func() -> bool: return sm_t.garrison == sm2, 60.0)
	var sb2: SummonerBehavior = sm2.behavior
	game.waves._spawn({"kind": "witch", "spawn": far_spot, "hp_scale": 1000.0})
	var hag2: Enemy = get_tree().get_nodes_in_group("enemies").back()
	hag2.speed = 0.0
	hag2.set_grid_pos(Vector2(sm_spot))
	var wb: WitchBehavior = hag2.behavior
	var engaged := await wait_until(func() -> bool: return wb.attacker is EarthElemental, 40.0)
	check(engaged, "an elemental attacks the witch")
	if engaged:
		var foe: EarthElemental = wb.attacker
		var hp0 := foe.hp
		var retaliates := await wait_until(func() -> bool: return wb.target == foe, 5.0)
		check(retaliates, "the witch turns her spells on whoever attacks her")
		var hurt := await wait_until(func() -> bool: return not is_instance_valid(foe) or foe.hp < hp0, 8.0)
		check(hurt, "her spell damages earth elementals")
		var keep_fighting := sb2.summons.any(func(e) -> bool: return is_instance_valid(e) and not e.dead)
		check(keep_fighting or not is_instance_valid(foe), "existing elementals keep fighting while their summoner may be bewitched")
	# Regression: elementals dying and being freed while their tower is bewitched
	# (the tower doesn't update then) used to break the summoner for good.
	sm_t.enchant(3.0)
	for e in sb2.summons:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(1e9)
	await wait(1.5)  # long enough for the dead elementals to be freed
	var resumed := await wait_until(func() -> bool: return sb2.summons.size() > 0 and sb2.summons.all(func(x) -> bool: return is_instance_valid(x)), 20.0)
	check(resumed, "summoner keeps summoning after its elementals died while it was bewitched")
	hag2.take_damage(1e9)
	game.army.unstation(sm2)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	game.waves.countdown = 99999.0

	# --- witch anti-stall tracker ----------------------------------------------------------
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	var reach: float = Config.ENEMIES["witch"]["spell_range"]
	# Needs a tower the witch outranges; build a fresh level-1 watchtower if none.
	var lone: Tower = null
	for t in game.world.towers():
		if t.complete and t.range_tiles() < reach - 0.2:
			lone = t
	if lone == null:
		game.economy.add("materials", 100)
		lone = game.construction.place("tower", find_spot("tower", Config.VILLAGE_CENTER + Vector2i(-7, 0)))
		await wait_until(func() -> bool: return lone.complete, 90.0)
	var reserve_archers := game.army.reserve().filter(func(u: MilitaryUnit) -> bool: return u.kind == "archer")
	game.army.station(reserve_archers[0] if not reserve_archers.is_empty() else game.army.recruit("archer"), lone)
	await wait_until(func() -> bool: return lone.garrison != null, 60.0)
	var limit := int(Config.ENEMIES["witch"]["spell_ignore_after"])
	var cast_cd: float = Config.ENEMIES["witch"]["spell_cooldown"]
	var outward := (Vector2(lone.tile) - Vector2(Config.VILLAGE_CENTER)).normalized()
	var stall_pos := Vector2(lone.tile) + outward * ((lone.range_tiles() + reach) / 2.0)
	game.waves._spawn({"kind": "witch", "spawn": far_spot, "hp_scale": 1.0})
	var w3: Enemy = get_tree().get_nodes_in_group("enemies").back()
	w3.speed = 0.0
	w3.set_grid_pos(stall_pos)
	var wb3: WitchBehavior = w3.behavior
	check(stall_pos.distance_to(Vector2(lone.tile)) > lone.range_tiles() and stall_pos.distance_to(Vector2(lone.tile)) <= reach, "witch parked beyond the archer's range but within her own (the old soft-lock)")
	var gave_up := await wait_until(func() -> bool: return wb3.casts_at(lone) >= limit and wb3.target == null, limit * cast_cd + 20.0)
	check(gave_up, "after %d spells at a tower that can't reach her, the witch ignores it (%d casts)" % [limit, wb3.casts_at(lone)])
	check(is_instance_valid(w3) and not w3.dead and is_equal_approx(w3.hp, w3.max_hp), "the tower's unit really could not reach her")
	await wait(3.0)
	check(not lone.is_enchanted(), "the ignored tower is no longer bewitched")
	if is_instance_valid(w3) and not w3.dead:
		w3.take_damage(1.0, lone)
		check(wb3.casts_at(lone) == 0, "when that tower attacks her again, her count for it resets")
		var retarget := await wait_until(func() -> bool: return wb3.target == lone, 3.0)
		check(retarget, "and she targets it again")
		w3.take_damage(1e9)
	game.waves.countdown = 99999.0
	# A walking witch next to a tower manned only by a summoner must not stall.
	game.army.unstation(lone.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	await wait_until(func() -> bool: return summoner.state == MilitaryUnit.State.RESERVE, 60.0)
	game.army.station(summoner, lone)
	await wait_until(func() -> bool: return lone.garrison == summoner, 60.0)
	var near_gate: Vector2i = map.gates[0]
	for gt in map.gates:
		if Vector2(gt).distance_to(Vector2(lone.tile)) < Vector2(near_gate).distance_to(Vector2(lone.tile)):
			near_gate = gt
	var approach: Array[Vector2i] = []
	for sp in map.edge_spawns:
		var r := game.world.pathing.enemy_route(sp, RandomNumberGenerator.new())
		if r[-1] == near_gate:
			approach = r
			break
	if approach.is_empty():
		check(false, "found a road leading to the summoner's gate")
	else:
		game.waves._spawn({"kind": "witch", "spawn": approach[maxi(0, approach.size() - 10)], "hp_scale": 1.0})
		var w4: Enemy = get_tree().get_nodes_in_group("enemies").back()
		var wb4: WitchBehavior = w4.behavior
		var saw_summoner := false
		var t4 := 0.0
		while is_instance_valid(w4) and not w4.dead and t4 < limit * cast_cd + 90.0:
			await get_tree().process_frame
			t4 += get_process_delta_time()
			saw_summoner = saw_summoner or wb4.target == lone
		check(saw_summoner, "the witch bewitches the summoner's tower on her way")
		check(not is_instance_valid(w4) or w4.dead, "but she never stalls there: she is killed or walks on (after %.0fs)" % t4)
	game.army.unstation(summoner)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	game.waves.countdown = 99999.0

	# --- demolition at the gate -------------------------------------------------------
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	var huts0 := game.population.cap()
	var pop0 := game.population.count()
	var homes := {}
	for h in game.world.intact_huts():
		homes[h] = h.resident != null  # a bool: a dead resident's object would read as null later
	var gate: Vector2i = map.gates[0]
	var outside := gate + (gate - Config.VILLAGE_CENTER).sign()
	game.waves._spawn({"kind": "goblin", "spawn": outside, "hp_scale": 1.0})
	await wait_until(func() -> bool: return game.population.cap() < huts0, 20.0)
	var burned: Array = homes.keys().filter(func(h: Hut) -> bool: return not h.is_intact())
	check(burned.size() == 1, "an enemy at the gate destroys exactly one random hut")
	var had_resident: bool = burned.size() == 1 and homes[burned[0]]
	check(game.population.count() == pop0 - (1 if had_resident else 0), "only that hut's resident dies (hut was %s)" % ("occupied" if had_resident else "empty"))
	check(residency_ok(), "everyone else still lives in their own hut")
	game.waves.countdown = 99999.0
	# Hard difficulty: still exactly one hut per enemy that gets in.
	Settings.difficulty = Settings.Difficulty.HARD
	var huts_h := game.population.cap()
	game.waves._spawn({"kind": "ork", "spawn": outside, "hp_scale": 1.0})
	await wait_until(func() -> bool: return game.population.cap() < huts_h, 20.0)
	await wait(1.0)
	check(game.population.cap() == huts_h - 1, "on hard, an enemy at the gate still destroys exactly one hut")
	Settings.difficulty = Settings.Difficulty.NORMAL
	game.waves.countdown = 99999.0
	# Direct checks for both cases.
	var empty_huts := game.world.intact_huts().filter(func(h: Hut) -> bool: return h.resident == null)
	if not empty_huts.is_empty():
		var p1 := game.population.count()
		(empty_huts[0] as Hut).destroy()
		check(game.population.count() == p1, "destroying an empty hut kills nobody")
	var lived := game.world.intact_huts().filter(func(h: Hut) -> bool: return h.resident != null)
	if not lived.is_empty():
		var victim_civ: Civilian = (lived[0] as Hut).resident
		var p2 := game.population.count()
		(lived[0] as Hut).destroy()
		check(game.population.count() == p2 - 1 and not game.population.civilians.has(victim_civ), "destroying an occupied hut kills exactly its resident")
	huts0 = game.population.cap() + game.world.huts().filter(func(h: Hut) -> bool: return h.ruined).size()
	for h in game.world.huts().filter(func(h: Hut) -> bool: return h.ruined).slice(1):
		(h as Hut).finish()  # keep one ruin for the rebuild test
	huts0 = game.population.cap() + 1
	game.waves.countdown = 99999.0  # that goblin's end re-armed the wave timer

	# --- civilians evade enemies ----------------------------------------------------------
	var the_farm: Farm = game.world.buildings.filter(func(b: Building) -> bool: return b is Farm)[0]
	if the_farm.farmer == null:
		if game.population.free_farmers().is_empty():
			game.population.spawn("farmer")
		game.population.assign_farmer(the_farm)
	var fm: Farmer = the_farm.farmer
	# Wait until the farmer is well outside the walls, so the evasion is observable.
	await wait_until(func() -> bool: return not fm.at_home and fm.state == Farmer.State.TO_FARM and fm.grid_pos.distance_to(Vector2(Config.VILLAGE_CENTER)) > 3.0, 90.0)
	game.waves._spawn({"kind": "goblin", "spawn": map.edge_spawns[0], "hp_scale": 100.0})
	var threat: Enemy = get_tree().get_nodes_in_group("enemies").back()
	threat.speed = 0.0
	threat.set_grid_pos(fm.grid_pos + Vector2(1.5, 0))
	var fled := await wait_until(func() -> bool: return fm.evading, 2.0)
	check(fled, "a farmer who spots an enemy runs home" + ("" if fled else " [fm home=%s state=%s dead=%s pos=%s | goblin dead=%s pos=%s dist=%.1f]" % [fm.at_home, fm.state, fm.dead, fm.grid_pos, threat.dead if is_instance_valid(threat) else "freed", threat.grid_pos if is_instance_valid(threat) else Vector2.ZERO, fm.grid_pos.distance_to(threat.grid_pos) if is_instance_valid(threat) else -1.0]))
	var safe := await wait_until(func() -> bool: return fm.at_home, 30.0)
	check(safe and not fm.evading, "the farmer reaches the village safely")
	threat.take_damage(1e9)
	await wait(1.0)

	# --- rebuild the ruin ----------------------------------------------------------------
	var ruin: Hut = game.world.huts().filter(func(h: Hut) -> bool: return h.ruined)[0]
	game.economy.add("materials", 100)
	if civs("builder").is_empty():
		game.population.spawn("builder")
	check(game.construction.order_rebuild(ruin), "rebuild ordered on the ruined lot")
	var rebuilt := await wait_until(func() -> bool: return ruin.is_intact(), 90.0)
	check(rebuilt and game.population.cap() == huts0, "builder rebuilds the hut")

	# --- two explorers split up -------------------------------------------------------------
	game.economy.add("food", 500)
	var e2: Explorer = game.population.recruit("explorer")
	check(e2 != null, "explorer recruited with food")
	while civs("explorer").size() < 2:  # raids may have killed the first one
		if game.population.spawn("explorer") == null:
			break
	var ex := civs("explorer")
	await wait_until(func() -> bool: return ex.all(func(e: Explorer) -> bool: return e.state == Explorer.State.EXPLORING), 30.0)
	if ex.size() >= 2 and ex[0].target != Vector2i(-1, -1) and ex[1].target != Vector2i(-1, -1):
		check(Vector2(ex[0].target).distance_to(Vector2(ex[1].target)) >= Config.EXPLORER_CLAIM_RADIUS * 0.5, "explorers head for different fog (%s vs %s)" % [ex[0].target, ex[1].target])
	else:
		check(false, "both explorers are exploring: %s" % str(ex.map(func(e: Explorer) -> String: return "%s/%s/%s" % [e.state, e.target, e.dead])))

	# --- population cap ----------------------------------------------------------------------
	while game.population.count() < game.population.cap():
		if game.population.recruit("farmer") == null:
			break
	check(game.population.count() == game.population.cap(), "recruited up to the hut cap")
	check(game.population.recruit_error("builder") != "", "recruiting is blocked at the cap")
	game.economy.add("gold", 1000)
	game.population.kill_random(1)
	check(game.population.recruit("archmage") != null, "archmage recruited for food and gold")

	# --- starvation ----------------------------------------------------------------------------
	for f in game.world.buildings.filter(func(b: Building) -> bool: return b is Farm):
		game.population.unassign_farmer(f)
	game.corpses.clear_wave(99)  # gathered corpses would bring in food
	await wait(8.0)  # let any farmer already carrying food get home
	var pop1 := game.population.count()
	game.economy.consume_food(100000.0)
	await wait(Config.STARVATION_INTERVAL + 2.0)
	check(game.population.count() < pop1, "a villager starves when food runs out")

	# --- UI texts talk about enemies, not goblins -------------------------------------------
	var texts := ""
	for b in game.world.buildings:
		var inf: Dictionary = b.info()
		texts += " ".join(inf["lines"]) + " "
	for role in Config.CIVILIANS:
		texts += Config.CIVILIANS[role]["desc"] + " "
	for kind in Config.MILITARY:
		texts += Config.MILITARY[kind]["desc"] + " "
	check(not "oblin" in texts, "building panels and descriptions say enemies, not goblins")

	# --- cancelling construction refunds ---------------------------------------------------------
	game.economy.add("materials", 100)
	var mat_c := game.economy.amount("materials")
	var cspot := find_spot("tower", Config.VILLAGE_CENTER + Vector2i(6, 0))
	var csite := game.construction.place("tower", cspot)
	if csite:
		game.construction.cancel(csite)
		await frames(2)
		check(game.economy.amount("materials") == mat_c and map.building_at(cspot) == null, "cancelling a construction site refunds it and frees the tile")

	# --- fog switches (Config.REVEAL_MAP / DISABLE_FOG) ---------------------------------------
	game.fog.reveal_all()
	await wait(0.5)
	check(game.fog.explored_count() == map.size * map.size and game.fog.watched_count() < map.size * map.size, "REVEAL_MAP explores everything but unwatched land stays dark")
	game.fog.set_disabled(true)
	await frames(2)
	check(game.fog.explored_count() == map.size * map.size and game.fog.watched_count() == map.size * map.size, "without fog the whole map is explored and visible")
	game.fog.set_disabled(false)

	# --- defeat -------------------------------------------------------------------------------
	game.population.kill_random(game.population.count())
	await frames(2)
	check(game.game_over and hud._overlay.visible, "losing every villager ends the game")
	check(hud._overlay_button.is_visible_in_tree() and hud._overlay_menu_button.is_visible_in_tree(), "defeat screen offers Try again and Main menu")
	await frames(2)
	var panel_rect: Rect2 = (hud._overlay_button.get_parent().get_parent() as Control).get_global_rect()
	var vp_center := get_viewport().get_visible_rect().size / 2.0
	check(panel_rect.get_center().distance_to(vp_center) < 4.0 and hud._overlay.get_global_rect().size == get_viewport().get_visible_rect().size, "defeat screen is centred and covers the whole screen (%s vs %s)" % [panel_rect.get_center(), vp_center])

	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures.size() > 0 else 0)
