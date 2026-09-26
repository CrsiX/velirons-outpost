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
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	game.map_seed = SEED
	add_child(game)
	_run.call_deferred()


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


func civs(role: String) -> Array:
	return game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == role)


# --- the test run -----------------------------------------------------------------

func _run() -> void:
	await frames(3)
	var hud := game.hud
	var map := game.map
	print("viewport ", get_viewport().get_visible_rect().size)

	# Title screen
	check(hud.is_title_visible(), "title screen shown")
	await tap(center(hud._overlay_button))
	check(not hud.is_title_visible(), "title dismissed by its button")

	# --- map -------------------------------------------------------------------
	print("map: %d spawns, %d trees" % [map.edge_spawns.size(), map.trees.size()])
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
	for y in range(23, 28):
		for x in range(23, 28):
			road_in_village = road_in_village or map.is_road(Vector2i(x, y))
	check(not road_in_village, "no road inside the village")
	var route := game.world.pathing.enemy_route(map.edge_spawns[0], RandomNumberGenerator.new())
	check(map.gates.has(route[-1]) and route.all(func(t: Vector2i) -> bool: return map.is_road(t) or map.gates.has(t)), "goblin route stays on roads and ends at a gate")

	# --- start state -----------------------------------------------------------
	check(game.population.count() == 3 and game.population.cap() == 9, "3 civilians, 9 huts")
	check(civs("builder").size() == 1 and civs("farmer").size() == 1 and civs("explorer").size() == 1, "one builder, farmer, explorer")
	var wall_towers := game.world.towers().filter(func(t: Tower) -> bool: return t.kind == "wall_tower")
	check(wall_towers.size() == 4 and wall_towers.all(func(t: Tower) -> bool: return t.garrison == null), "4 unmanned wall towers")
	check(game.world.pathing.astar.is_point_solid(Vector2i(23, 24)) and not game.world.pathing.astar.is_point_solid(Vector2i(25, 23)), "walls block, gates don't")
	var explored0 := game.fog.explored_count()
	check(explored0 > 50 and explored0 < 300, "fog of war around the village (%d tiles explored)" % explored0)

	Engine.time_scale = 6.0

	# --- explorer ---------------------------------------------------------------
	await wait(25.0)
	var explored1 := game.fog.explored_count()
	check(explored1 > explored0 + 40, "explorer reveals the map (%d -> %d)" % [explored0, explored1])

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

	# --- army: recruit + drag & drop onto a wall tower ------------------------------
	game.economy.add("gold", 500)
	hud._select_tab("army")
	await frames(2)
	var gold2 := game.economy.amount("gold")
	await tap(center(hud._archer_button))
	check(game.army.reserve().size() == 1 and game.economy.amount("gold") == gold2 - 40, "archer recruited for 40 gold")
	await frames(2)
	var card: Button = hud._reserve_grid.get_child(0)
	var wt: Tower = wall_towers[0]
	var target := screen(wt.position + Vector2(0, -50))
	mouse(center(card), true)
	await frames(1)
	var steps := 8
	for i in range(1, steps + 1):
		motion(center(card).lerp(target, float(i) / steps))
		await frames(1)
	mouse(target, false)
	await frames(2)
	check(wt.garrison != null, "archer dragged from the sidebar onto a wall tower")
	check(game.army.reserve().is_empty(), "reserve is empty after stationing")
	# Tap mode: tap a card, then tap the new watchtower.
	await tap(center(hud._archer_button))
	await frames(2)
	card = hud._reserve_grid.get_child(0)
	await tap(center(card))
	check(game.mode == Game.Mode.STATION, "tapping a reserve card enters station mode")
	await tap(screen(watchtower.position + Vector2(0, -40)))
	check(watchtower.garrison != null, "tap-to-station on the watchtower")
	var unit := watchtower.garrison
	check(game.army.upgrade(unit) and unit.level == 1, "archer upgraded with gold")
	# Man the other wall towers too.
	for t in wall_towers.slice(1):
		game.army.station(game.army.recruit(), t)

	# --- waves ----------------------------------------------------------------------
	check(game.waves.waiting_for_first(), "first wave waits for the player")
	await wait(3.0)
	check(game.waves.wave == 0, "no wave starts on its own")
	var gold3 := game.economy.amount("gold")
	await tap(center(hud._call_button))
	check(game.waves.wave == 1 and game.waves.in_progress(), "call button starts wave 1")
	var cleared := await wait_until(func() -> bool: return not game.waves.in_progress(), 240.0)
	check(cleared, "wave 1 ends")
	print("  wave 1: gold %d -> %d, civilians %d, huts %d" % [gold3, game.economy.amount("gold"), game.population.count(), game.population.cap()])
	check(game.economy.amount("gold") > gold3, "archers killed goblins for gold")
	check(absf(game.waves.countdown - Config.WAVE_BUFFER) < 2.0, "next wave counts down from %ds after the last goblin" % int(Config.WAVE_BUFFER))
	await wait(5.0)
	var bonus := game.waves.early_call_bonus()
	var gold4 := game.economy.amount("gold")
	game.waves.call_next()
	check(game.waves.wave == 2 and game.economy.amount("gold") == gold4 + bonus and bonus > 0, "calling early starts wave 2 with +%d gold" % bonus)
	await wait_until(func() -> bool: return not game.waves.in_progress(), 240.0)
	var auto := await wait_until(func() -> bool: return game.waves.wave == 3, Config.WAVE_BUFFER + 5.0)
	check(auto, "wave 3 starts automatically after the buffer")
	await wait_until(func() -> bool: return not game.waves.in_progress(), 300.0)

	# --- demolition at the gate -------------------------------------------------------
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	var huts0 := game.population.cap()
	var pop0 := game.population.count()
	var gate: Vector2i = map.gates[0]
	var outside := gate + (gate - Config.VILLAGE_CENTER).sign()
	game.waves._spawn({"kind": "goblin", "spawn": outside, "hp_scale": 1.0})
	await wait_until(func() -> bool: return game.population.cap() < huts0, 20.0)
	check(game.population.cap() == huts0 - 1, "a goblin at the gate destroys a hut")
	check(game.population.count() == mini(pop0 - 1, game.population.cap()), "and kills a civilian")

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
		game.population.spawn("explorer")
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
	await wait(8.0)  # let any farmer already carrying food get home
	var pop1 := game.population.count()
	game.economy.consume_food(100000.0)
	await wait(Config.STARVATION_INTERVAL + 2.0)
	check(game.population.count() < pop1, "a villager starves when food runs out")

	# --- defeat -------------------------------------------------------------------------------
	game.population.kill_random(game.population.count())
	await frames(2)
	check(game.game_over and hud._overlay.visible, "losing every villager ends the game")

	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures.size() > 0 else 0)
