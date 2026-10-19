extends "res://tests/bot_base.gd"
## Headless test of the campaign's scenarios (docs/scenarios-design.md),
## each played through with commands. Scenario 1, Homecoming: its baseline
## (map file, ruins, villagers, Einar, Brenna at her tent), its rules, the
## intro cutscene and the walk home, the arrival, every card, the waves, the
## objectives, the outro and the win; a villager's death as a defeat; the
## hints; the title screen's Campaign page. Scenario 2, The Old Friend: Pell,
## the stall and trade, the waves waiting for it, rats at the stall, the hero
## claiming the ruin, the cards, the talks between waves, Pell's death as a
## defeat, the win. Scenario 3, The Wardline: the grown map, the ruins (a
## barracks too), restoring, journals and the logbook, specialising and
## training, the lit road, the waves that keep coming, the win. Scenario 4,
## The Split: the guild town, Wenna and her guild house, the warehouse by the
## harbour plundered and its fall as a defeat, the rival's offer (a choice),
## the coins, crabs out of the sea, Brenna downed as a defeat, the win.
## Scenario 5, The Betrayal: the ruined fort, Sigmund, the evidence and its
## pages, the Dread Legion (a footman's release, a captain falling back),
## the last wave's Legion and gargoyles, the win. Scenario 6, The Dead: Anselm,
## the graveyard by the chapel, the fallen (never rotting, buried by the
## gatherers, raised as skeletons), the chapel woken, an acolyte, the waves
## until enough are buried, the win, too many risen as a defeat. Scenario 7,
## The Exile: Fiona, the druids in their grove (no orders), Brenna at her tent,
## Fiona's trust in steps (what is refused when), the mages' tower, wave 5's
## band at the grove, the circle, the win, a druid falling in wave 5.
##   -- --only=1|2|3|4|5|6|7   one scenario only (the title screen with 1)

var sc: ScenarioRunner


func _run() -> void:
	var diff := Settings.difficulty
	Settings.difficulty = Settings.Difficulty.HARD
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	if only in ["", "1"]:
		_map_file()
		await _play_through()
		await _defeat()
		await _hints()
	if only in ["", "2"]:
		await _scenario_2()
	if only in ["", "3"]:
		await _scenario_3()
	if only in ["", "4"]:
		await _cutscene_choice()
		await _scenario_4()
	if only in ["", "5"]:
		await _scenario_5()
	if only in ["", "6"]:
		await _scenario_6()
	if only in ["", "7"]:
		await _scenario_7()
	if is_instance_valid(game):
		game.queue_free()
		await frames(2)
	check(Settings.difficulty == Settings.Difficulty.HARD and Settings.enemy_scale.is_empty(), "the player's difficulty is back, no scenario scale left, once the game is gone")
	if only in ["", "1"]:
		await _title()
	Settings.difficulty = diff
	Engine.time_scale = 1.0
	print("CHECKS %d  FAILURES %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func cmd(type: String, args: Dictionary = {}) -> Dictionary:
	var r := game.command(type, args)
	if not r["ok"]:
		print("    (%s refused: %s)" % [type, r["error"]])
	return r


func _new_game(n := 1) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await frames(2)
	Engine.time_scale = 1.0
	Settings.scenario_next = n
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await frames(3)
	sc = game.scenario


## Through a cutscene: every line (a tap shows it whole, the next goes on).
## A choice gets choice `pick`. Returns the speakers' ids in order.
func _watch(c: Cutscene, pick := 0) -> Array[String]:
	var said: Array[String] = []
	var t := 0.0
	while is_instance_valid(c) and c.running and t < 90.0:
		if c.choosing():
			said.append(str(c.steps[c.index].get("say", "")))
			c.choose(pick)
		elif c.line != "":
			var s: Dictionary = c.steps[c.index]
			said.append(str(s["say"]))
			c.advance()  # (the whole line)
			c.advance()  # (the next step)
		await frames(1)
		t += get_process_delta_time()
	return said


func _at_card(i: int, timeout: float) -> bool:
	return await wait_until(func() -> bool: return sc.step == i and sc._next_in < 0.0, timeout)


func _map_file() -> void:
	print("-- the map file")
	var spec := Campaign.scenario(1)
	check(spec != null and spec.number == 1 and spec.title == "Homecoming", "scenario 1 is Homecoming")
	check(Campaign.scenario(0) == null and Campaign.scenario(Campaign.count() + 1) == null, "no scenario 0 or past the last")
	var r := MapLibrary.load_file(spec.map_path)
	check(r["map"] != null, "its map file reads without errors %s" % str(r["errors"]))
	if r["map"] == null:
		return
	var m: MapData = r["map"]
	check(m.villages.size() == 1 and m.size == 75, "one village on a 75x75 map")
	check(m.objects.filter(func(o: Dictionary) -> bool: return o["kind"] == "ruin").size() == 1, "one ruined watchtower")
	check(not m.objects.any(func(o: Dictionary) -> bool: return o["kind"] in ["unlock", "lair"]), "no unlock sites, no lairs")
	check(m.is_passable(spec.hero_start) and m.is_passable(spec.tent_tile) and not m.is_road(spec.tent_tile), "Brenna's start and her tent are on open land by the road")


func _play_through() -> void:
	print("-- setup")
	await _new_game()
	var v := game.player_village
	check(sc != null and sc.spec.number == 1, "scenario 1 runs (from Settings.scenario_next)")
	check(Settings.scenario_next == 0, "the request is used up")
	check(sc.error == "" and MapJson.map_name(game.map) == "Homecoming", "its map comes from its file (%s)" % sc.error)
	check(Settings.difficulty == Settings.Difficulty.EASY and is_equal_approx(Config.enemy_stat("goblin", "hp"), 10.0), "Easy, with goblins at half HP (weaker than Easy)")
	check(is_equal_approx(Config.enemy_stat("goblin", "speed"), 1.1 * 0.67), "speed as on Easy")
	var roles := v.population.civilians.map(func(c: Civilian) -> String: return c.role)
	roles.sort()
	check(roles == ["builder", "farmer", "forester"], "a builder, a farmer and a forester (%s)" % str(roles))
	var einar: Civilian = v.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "forester")[0]
	check(einar.label() == "Einar" and einar.given_name == "Einar", "the forester is Einar")
	check(v.intact_huts().size() == 4 and v.huts().size() == 9, "4 of 9 huts stand (%d)" % v.intact_huts().size())
	check(sc.pieces("gate").filter(func(b: Building) -> bool: return b.devastated).size() == 3, "3 of 4 gates broken")
	check(sc.pieces("wall_tower").filter(func(b: Building) -> bool: return b.devastated).size() == 3, "3 of 4 wall towers broken")
	check(sc.pieces("wall").filter(func(b: Building) -> bool: return not b.devastated).size() == 3, "3 walls stand")
	var standing: Building = sc.pieces("gate").filter(func(b: Building) -> bool: return not b.devastated)[0]
	check(standing.hp < standing.max_hp(), "the standing gate is hurt (%d / %d)" % [standing.hp, standing.max_hp()])
	check(int(v.economy.amount("materials")) == int(sc.spec.resources["materials"]), "the scenario's resources")
	check(game.hero.label() == "Brenna" and game.hero.display_name() == "Brenna", "the hero is Brenna")
	check(game.hero.grid_pos.distance_to(Vector2(sc.spec.hero_start)) < 0.1, "she starts by the road, at her tent")
	check(is_instance_valid(sc.tent_node), "the tent stands there")
	check(game.map.is_explored(sc.spec.hero_start) and game.map.is_explored(game.player_village.center), "her start and the village are uncovered")
	check(game.waves.hold and game.waves.scripted.size() == 5 and game.waves.last_wave == 5, "five scripted waves, the first waits")
	check(game.waves.scripted[0].get("spawn") == sc.spots.spawn_tile, "wave 1 comes down the cards' road")
	check(not game.corpses.rot, "corpses don't rot (until the gatherers' card)")
	check(game.save_error() != "", "a scenario can't be saved")
	check(game.available("archer") and not game.available("shield_bearer"), "archers only")
	check(not game.allows_building("barracks") and not game.allows_building("training") and game.allows_building("tower"), "no barracks, no training grounds")
	check(not game.hud._build_panels["barracks"].visible and game.hud._build_panels["tower"].visible, "the Build tab hides the barracks")
	check(not game.hud._military_panels["shield_bearer"].visible, "the Army tab shows no shield bearer")

	print("-- the intro")
	check(sc.phase == ScenarioRunner.Phase.INTRO and sc.cutscene != null and sc.cutscene.running, "the intro cutscene plays")
	check(not game.hud.visible, "the HUD is hidden meanwhile")
	check(not cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})["ok"], "no orders for Brenna during it")
	check(not cmd("place_building", {"kind": "barracks", "tile": Vector2i(30, 30)})["ok"], "barracks are refused")
	await wait(4.0)
	var said := await _watch(sc.cutscene)
	check(said.has("brenna") and said.has(""), "Brenna and the narrator speak (%s)" % str(said))
	check(sc.phase == ScenarioRunner.Phase.WALK and game.hud.visible, "then she walks home, the HUD back")
	check(sc.card.visible and sc.card.lesson_title() == "Homeward", "the card: Homeward")

	print("-- the walk home")
	check(await wait_until(func() -> bool: return sc.phase == ScenarioRunner.Phase.ARRIVAL, 60.0), "she reaches the village")
	check(sc.cutscene != null, "the arrival plays")
	said = await _watch(sc.cutscene)
	check(said.has("einar") and said.has("brenna"), "Einar greets her (%s)" % str(said))
	check(sc.phase == ScenarioRunner.Phase.PLAY and game.hero.mode == Hero.Mode.DEFEND, "play: Brenna defends")

	print("-- card 1: huts")
	check(await _at_card(0, 2.0) and sc.card.lesson_title() == "Rebuild the huts", "card 1: rebuild the huts")
	check(not sc.highlight.tiles.is_empty(), "the ruined huts are marked")
	var ruin: Hut = v.huts().filter(func(h: Hut) -> bool: return h.ruined)[0]
	check(cmd("rebuild_hut", {"building": ruin.nid})["ok"], "a hut rebuild is ordered")

	print("-- card 2: watchtower")
	check(await _at_card(1, 5.0), "card 2")
	var spot: Vector2i = sc.highlight.tiles[0] if not sc.highlight.tiles.is_empty() else Vector2i(-1, -1)
	check(cmd("place_building", {"kind": "tower", "tile": spot})["ok"], "the watchtower goes on the marked spot %s" % spot)
	check(await _at_card(2, 5.0), "card 3: the builder at work")
	Engine.time_scale = 4.0
	check(await _at_card(3, 240.0), "card 4 once the tower stands")
	var tower: Tower = sc.towers()[0]
	var r := cmd("recruit_unit", {"kind": "archer"})
	var archer: MilitaryUnit = game.army.reserve()[0] if r["ok"] else null
	check(archer != null, "an archer is recruited")
	check(not cmd("recruit_unit", {"kind": "shield_bearer"})["ok"], "a shield bearer is refused")
	cmd("station_unit", {"unit": archer.nid, "post": tower.nid})

	print("-- card 5: food")
	check(await _at_card(4, 120.0), "card 5 once the archer is on the tower")
	var field: Vector2i = sc.highlight.tiles[0] if not sc.highlight.tiles.is_empty() else Vector2i(-1, -1)
	var fr := cmd("place_building", {"kind": "farm", "tile": field + Vector2i(1, 1)})
	check(fr["ok"], "a second farm on the marked field")

	print("-- card 6: the first wave")
	check(await _at_card(5, 10.0), "card 6: call the wave")
	check(game.hud._wave_label.text.ends_with("waits"), "the wave waits (%s)" % game.hud._wave_label.text)
	check(cmd("call_wave")["ok"], "wave 1 is called")
	await wait(0.3)
	check(game.waves.wave == 1 and game.waves.enemies_left() == 3, "wave 1: 3 goblins (%d)" % game.waves.enemies_left())
	check(not game.waves.hold, "from now on the countdown runs")

	print("-- card 7: gatherers")
	check(await _at_card(6, 120.0), "card 7 once wave 1 left a corpse")
	await wait_until(func() -> bool: return not game.population.free_huts().is_empty(), 120.0)
	check(cmd("recruit_villager", {"role": "gatherer"})["ok"], "a gatherer is recruited")
	check(await _at_card(7, 240.0), "card 8 once a corpse is home")
	check(game.corpses.rot, "corpses rot again")

	print("-- card 8: unit levels")
	check(sc.highlight.units.has(archer), "the archer on its tower is outlined")
	check(archer.upgrade_options().all(func(o: Dictionary) -> bool: return o["to"] == "archer"), "no specialisations offered")
	check(cmd("upgrade_unit", {"unit": archer.nid})["ok"], "the archer is promoted")

	print("-- card 9: gates and wall towers")
	check(await _at_card(8, 10.0), "card 9")
	var gate: Building = sc.pieces("gate").filter(func(b: Building) -> bool: return b.devastated)[0]
	check(cmd("repair", {"building": gate.nid})["ok"], "a gate repair is ordered")
	check(await wait_until(func() -> bool: return sc.step >= sc.steps.size(), 10.0), "the cards are over")
	check(not sc.card._lesson.visible, "only the objectives are left on the card")

	print("-- rebuilding and the waves")
	var guard := Timer.new()  # (enemies die as they come: this tests the flow, not the balance)
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	v.economy.add("materials", 1500)
	v.economy.add("gold", 500)
	v.economy.add("food", 300)
	cmd("rebuild_all_huts")
	for b: Building in sc.pieces("gate") + sc.pieces("wall_tower"):
		if not sc.whole(b) and not b.repairing:
			cmd("repair", {"building": b.nid})
	game.hero.set_mode(Hero.Mode.BUILD)
	check(await wait_until(func() -> bool: return sc.pieces("hut").all(sc.whole), 600.0), "every hut rebuilt")
	cmd("recruit_villager", {"role": "builder"})
	check(await wait_until(func() -> bool: return (sc.pieces("gate") + sc.pieces("wall_tower")).all(sc.whole), 600.0), "every gate and wall tower repaired")
	game.hero.set_mode(Hero.Mode.DEFEND)
	for n in range(game.waves.wave + 1, 6):
		await wait_until(func() -> bool: return game.waves.can_call(), 300.0)
		check(cmd("call_wave")["ok"], "wave %d is called" % n)
		await wait(0.2)
		var kinds := {}
		for q in game.waves._queue:
			kinds[q["kind"]] = kinds.get(q["kind"], 0) + 1
		var want: Dictionary = sc.spec.waves[n - 1]["kinds"].duplicate()
		var rats := 0
		for p in sc.spec.waves[n - 1].get("rat_packs", []):
			rats += int(p)
		if rats > 0:
			want["rat"] = rats
		check(_total(kinds) == _total(want) and want.keys().all(func(k: String) -> bool: return int(kinds.get(k, 0)) == int(want[k])), "wave %d: %s (%s)" % [n, str(want), str(kinds)])
		await wait_until(func() -> bool: return not game.waves.in_progress(), 300.0)
	check(game.waves.all_done() and not game.waves.can_call(), "after wave 5 no more waves come")
	await frames(2)
	check(game.hud._wave_label.text == "All 5 waves survived", "the top bar says so (%s)" % game.hud._wave_label.text)
	if game.population.count() <= sc.start_villagers:
		cmd("recruit_villager", {"role": "farmer"})

	guard.queue_free()
	print("-- the outro and the win")
	check(await wait_until(func() -> bool: return sc.phase == ScenarioRunner.Phase.OUTRO or sc.phase == ScenarioRunner.Phase.OVER, 30.0), "every objective met: the outro (%s)" % str(sc._goal_state))
	check(await wait_until(func() -> bool: return sc.cutscene != null, 10.0), "the outro plays")
	Engine.time_scale = 1.0
	await wait(1.0)
	check(game.get_node_or_null("Dusk") != null, "dusk falls")
	said = await _watch(sc.cutscene)
	check(said.has("pell") and said.has("brenna"), "Pell arrives and speaks (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay.visible, "the scenario is complete")
	check(game.hud._overlay_title.text == "Homecoming: complete" and game.hud._overlay_won, "won: %s" % game.hud._overlay_title.text)
	check(game.hud._overlay_menu_button.text == "Play again" and game.hud._overlay_button.text == "Main menu", "Main menu, or Play again")


## Every enemy of the waves dies (with `kill_camps`, the camps' guards too).
func _kill_wave() -> void:
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if kill_camps or not (e.behavior is CampBehavior):
			kill(e, game.hero)


## _kill_wave kills the camps' guards too (scenario 3: two camps by the north road).
var kill_camps := false


func _total(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


func _defeat() -> void:
	print("-- a villager dies: defeat")
	await _new_game()
	sc.cutscene.skip()
	await frames(2)
	check(sc.phase == ScenarioRunner.Phase.WALK, "a skipped intro: the walk")
	var einar: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Einar")[0]
	game.population.kill(einar, "from the attack of goblin 1", "enemies")
	await frames(2)
	check(game.game_over and game.hud._overlay.visible, "Einar's death ends the scenario")
	check(game.hud._overlay_title.text == "Homecoming failed", "Homecoming failed (%s)" % game.hud._overlay_title.text)
	check(game.hud._overlay_sub.text.contains("Einar, Brenna's father, died from the attack of goblin 1"), "the cause is named (%s)" % game.hud._overlay_sub.text)
	check(game.hud._overlay_button.text == "Try again" and not game.hud._overlay_load_button.visible, "Try again (no save to load)")
	check(not sc.card.visible, "the card is gone")


func _hints() -> void:
	print("-- hints and rules")
	await _new_game()
	sc.cutscene.skip()
	await frames(2)
	game.hero.set_grid_pos(Vector2(game.player_village.center))
	game.hero.arrive_home()
	check(await wait_until(func() -> bool: return sc.cutscene != null, 5.0), "home: the arrival")
	sc.cutscene.skip()
	await frames(2)
	check(sc.phase == ScenarioRunner.Phase.PLAY, "play")
	var farmer: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "farmer")[0]
	farmer.hp = 5.0
	check(await wait_until(func() -> bool: return sc.card.hint() != "", 2.0), "a hurt villager: a hint on the card")
	check(sc.card.hint().begins_with("A villager is hurt"), "it says so (%s)" % sc.card.hint())
	sc.card.show_hint("")
	farmer.hp = 2.0
	await wait(1.0)
	check(sc.card.hint() == "", "once only")
	game.queue_free()
	await frames(2)


func _title() -> void:
	print("-- title screen")
	var t = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await frames(2)
	var cb: Button = t.campaign_button
	check(cb.is_visible_in_tree() and cb.get_index() == 0 and cb.icon == Art.tex("icon_campaign"), "Campaign comes first on the main page, with its banner")
	cb.pressed.emit()
	await frames(1)
	check(t._campaign_page.visible and not t._main_page.visible, "it opens the campaign page")
	var names: Array = t.scenario_buttons.map(func(b: Button) -> String: return b.text)
	check(names == ["1. Homecoming", "2. The Old Friend", "3. The Wardline", "4. The Split", "5. The Betrayal", "6. The Dead", "7. The Exile"], "scenarios 1 to 7 are there: %s" % str(names))
	check(t._campaign_page.get_children().any(func(c: Node) -> bool: return c is Label and (c as Label).text.contains("still to come")), "and the rest are to come")
	t.show_page(t._main_page)
	t.queue_free()
	await frames(1)


# --- scenario 2: The Old Friend ---------------------------------------------------------------

## Skips the cutscene playing now, if any.
func _skip_scene() -> void:
	if sc.cutscene != null:
		sc.cutscene.skip()
		await frames(2)


func _scenario_2() -> void:
	print("-- scenario 2: setup")
	await _new_game(2)
	var v := game.player_village
	check(sc != null and sc.spec.number == 2 and game.map.size == 75 and MapJson.map_name(game.map) == "Homecoming", "scenario 2 runs on the home map")
	var pell: Civilian = sc.merchant()
	check(pell != null and pell.label() == "Pell" and pell.role == "merchant" and is_instance_valid(pell.hut), "Pell is a villager (a merchant) with a hut")
	check(game.population.count() == 5 and v.intact_huts().size() == 9, "five villagers, all nine huts stand")
	check(sc.pieces("gate").all(sc.whole) and sc.pieces("wall_tower").all(sc.whole), "the walls are whole")
	var towers := sc.towers()
	check(towers.size() == 2 and towers.all(func(t: Tower) -> bool: return t.garrison != null and t.garrison.kind == "archer"), "two watchtowers, each with an archer")
	check(game.hero.level == 1 and game.hero.label() == "Brenna", "Brenna at level 2")
	check(game.waves.hold and game.waves.call_locked and not cmd("call_wave")["ok"], "the first wave waits for the stall; it can't be called")
	check(game.allows_building("stall") and game.allows_building("barracks") and not game.allows_building("training"), "the stall and barracks can be built, no training grounds")
	check(game.available("shield_bearer") and not game.available("apprentice"), "shield bearers can be recruited")
	check(game.hud._build_panels["stall"].visible, "the Build tab shows the stall")
	check(not game.population.recruit_error("merchant").is_empty() and not game.hud._recruit_rows.has("merchant"), "merchants can't be recruited")
	await wait(1.0)
	await _skip_scene()
	check(sc.phase == ScenarioRunner.Phase.PLAY and sc.card.lesson_title() == "Pell's stall", "play: the stall's card")

	print("-- scenario 2: the stall")
	var spot: Vector2i = sc.highlight.tiles[0] if not sc.highlight.tiles.is_empty() else Vector2i(-1, -1)
	var r := cmd("place_building", {"kind": "stall", "tile": spot})
	check(r["ok"], "the stall goes on the marked spot %s" % spot)
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return sc.step == 1, 240.0), "the trade card once it stands")
	var stall: Stall = sc.stalls()[0]
	check(stall.size == 2 and stall.display_name() == "Peddler's Stall" and stall.worker == pell, "a 2x2 peddler's stall, Pell's")
	check(not game.waves.hold and not game.waves.call_locked and game.waves.countdown > 30.0, "the first wave's countdown runs (%.0f s)" % game.waves.countdown)
	check(await wait_until(func() -> bool: return stall.is_open(), 60.0), "Pell walks over and opens it")
	check(stall.rate() == 0.0 and game.population.food_per_second() < Config.FARM_RATE, "it grows no food")
	stall.stored = 30.0
	var gold := v.economy.amount("gold")
	var mat := v.economy.amount("materials")
	r = cmd("trade", {"building": stall.nid, "good": "materials"})
	check(r["ok"] and is_equal_approx(v.economy.amount("gold"), gold - 15.0) and is_equal_approx(v.economy.amount("materials"), mat + 10.0) and is_equal_approx(stall.stored, 20.0), "10 material for 15 gold, from his goods (%s)" % str(r))
	check(not cmd("trade", {"building": stall.nid, "good": "gold"})["ok"], "he doesn't sell gold")
	stall.stored = 5.0
	check(not cmd("trade", {"building": stall.nid, "good": "food"})["ok"], "sold out: no trade")
	stall.stored = 30.0
	check(await wait_until(func() -> bool: return sc.step == 2, 5.0), "the hero's card")

	print("-- scenario 2: rats at the stall")
	var road_t := sc.road_to_village(stall.tile)
	var near: Vector2i = road_t[0] if not road_t.is_empty() else stall.tile
	game.population.unassign_worker(stall)  # (Pell goes home: a rat would go for him first)
	check(await wait_until(func() -> bool: return pell.at_home, 60.0) and not stall.is_open(), "Pell away: the stall is closed")
	var rat := game.waves.spawn_at("rat", near, v, 1)
	rat.max_hp = 1e6  # (the watchtower by the road shoots it, but this one lives)
	rat.hp = rat.max_hp
	var before := stall.stored
	check(await wait_until(func() -> bool: return stall.has_rats(), 20.0), "a rat on the road goes for the stall")
	await wait(3.0)
	check(stall.stored < before, "and eats its goods (%.1f -> %.1f)" % [before, stall.stored])
	if is_instance_valid(rat):
		kill(rat)
	game.population.assign_worker(stall)
	check(await wait_until(func() -> bool: return stall.is_open(), 60.0), "Pell back at his stall")
	stall.stored = 30.0

	print("-- scenario 2: the ruin, levels, barracks, a tower upgrade")
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	var site: Dictionary = sc.ruin_sites[0]
	check(await wait_until(func() -> bool: return sc.claimed(site), 400.0), "Brenna claims the broken watchtower")
	check(await wait_until(func() -> bool: return sc.step == 3, 5.0), "the restore card")
	var ruin = sc.on_site(site)
	check(cmd("restore_ruin", {"ruin": ruin.nid})["ok"], "it is restored")
	check(await wait_until(func() -> bool: return sc.step == 4, 5.0), "the level card")
	check(game.hero.can_level_up() and cmd("hero_level_up")["ok"], "Brenna has the XP and levels up")
	check(await wait_until(func() -> bool: return sc.step == 5, 5.0), "the barracks card")
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
	var bspot: Vector2i = sc.highlight.tiles[0] if not sc.highlight.tiles.is_empty() else find_spot("barracks", v.center)
	check(cmd("place_building", {"kind": "barracks", "tile": bspot})["ok"], "barracks on the marked spot")
	check(cmd("recruit_unit", {"kind": "shield_bearer"})["ok"], "a shield bearer")
	var barracks: Barracks = v.buildings().filter(func(b: Building) -> bool: return b is Barracks)[0]
	check(await wait_until(func() -> bool: return barracks.complete, 240.0), "the barracks stand")
	cmd("station_unit", {"unit": game.army.reserve()[0].nid, "post": barracks.nid})
	check(await wait_until(func() -> bool: return sc.step == 6, 120.0), "the tower-upgrade card")
	v.economy.add("materials", 200)
	check(cmd("upgrade_tower", {"building": sc.towers()[0].nid})["ok"], "a watchtower upgrade")
	check(await wait_until(func() -> bool: return sc.step >= sc.steps.size(), 240.0), "the cards are over")

	print("-- scenario 2: the waves and the talks")
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	var scenes := 0
	while not game.waves.all_done() and not game.game_over:
		if sc.cutscene != null:
			scenes += 1
			await _skip_scene()
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
	guard.queue_free()
	check(scenes >= 3 and not game.game_over, "seven waves, with talks between them (%d scenes)" % scenes)
	check(await wait_until(func() -> bool: return sc.phase == ScenarioRunner.Phase.OUTRO or sc.cutscene != null, 30.0), "the objectives are met (%s)" % str(sc._goal_state))
	check(await wait_until(func() -> bool: return sc.cutscene != null, 120.0), "the outro plays")
	Engine.time_scale = 1.0
	var said := await _watch(sc.cutscene)
	check(said.has("pell"), "Pell asks for the Wardline (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Old Friend: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 2: Pell's death")
	await _new_game(2)
	await _skip_scene()
	game.population.kill(sc.merchant(), "from the attack of goblin 3", "enemies")
	await frames(2)
	check(game.game_over and game.hud._overlay_title.text == "The Old Friend failed" and game.hud._overlay_sub.text.contains("Pell must not die"), "Pell dies: the scenario is lost (%s)" % game.hud._overlay_sub.text)


# --- scenario 3: The Wardline -------------------------------------------------------------------

## Closes the journal page; the bot's 4x speed again (closing it puts the
## game's own speed back, 1x here).
func _close_journal() -> void:
	sc.journal.close_page()
	Engine.time_scale = 4.0


func _scenario_3() -> void:
	print("-- scenario 3: setup")
	await _new_game(3)
	var v := game.player_village
	check(sc != null and sc.error == "" and game.map.size == 100 and MapJson.map_name(game.map) == "The Wardline", "scenario 3 runs on the grown 100x100 map")
	check(sc.ruin_sites.size() == 5 and sc.ruin_sites.filter(func(s: Dictionary) -> bool: return s["building"] == "barracks").size() == 1, "five ruins: four watchtowers and a barracks")
	var bruin = sc.on_site(sc.ruin_sites.filter(func(s: Dictionary) -> bool: return s["building"] == "barracks")[0])
	check(bruin is RuinedTower and bruin.size == 2 and bruin.display_name() == "Ruined barracks" and bruin.art() == "barracks_ruin", "the barracks ruin is 2x2, with its own look")
	var stall: Stall = sc.stalls()[0] if not sc.stalls().is_empty() else null
	check(stall != null and stall.level == 2 and stall.display_name() == "Trade Stall" and stall.worker == sc.merchant(), "Pell's trade stall stands (level 2), his")
	check(v.buildings().any(func(b: Building) -> bool: return b is Barracks and not (b as Barracks).units().is_empty()), "barracks with a shield bearer")
	var archer: MilitaryUnit = game.army.units.filter(func(u: MilitaryUnit) -> bool: return u.kind == "archer" and u.level == 2)[0]
	check(archer.upgrade_options().any(func(o: Dictionary) -> bool: return o["to"] == "crossbowman"), "level 3 archers can specialise")
	check(game.hero.level == 3 and game.allows_building("training") and not game.allows_building("stall"), "Brenna at level 4; training grounds allowed")
	check(game.waves.last_wave == 0 and not game.waves.call_locked, "the waves don't stop by themselves")
	var w7 := sc.next_wave(7)
	check(int(w7["kinds"]["goblin"]) == 10 and int(w7["kinds"]["thief"]) == 4, "past the list the last wave comes again, growing (%s)" % str(w7["kinds"]))
	await wait(1.0)
	await _skip_scene()
	check(sc.card.lesson_title() == "Claim the ruins", "the first card: claim the ruins")
	check(not sc.spec._dark_road(sc).is_empty(), "the road out to the ruins is dark")

	print("-- scenario 3: claiming and restoring")
	kill_camps = true  # (the builders would flee from the camps by the road)
	var guard := Timer.new()  # (enemies die as they come, the whole time)
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	Engine.time_scale = 4.0
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	check(await wait_until(func() -> bool: return sc.ruin_sites.any(sc.claimed), 400.0), "Brenna claims a ruin")
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
	game.waves.hold = true  # (no new waves while the builders are out on the road; released for the win)
	v.economy.add("materials", 800)
	v.economy.add("gold", 1500)
	v.economy.add("food", 300)
	for s in sc.ruin_sites:
		var o = sc.on_site(s)
		if o is RuinedTower and o.village == null:
			(o as RuinedTower).claim(v)
	var restored := 0
	for s in sc.ruin_sites:
		if cmd("restore_ruin", {"ruin": sc.on_site(s).nid})["ok"]:
			restored += 1
	check(restored == 5, "all five are restored by order (%d)" % restored)
	var b_site: Dictionary = sc.ruin_sites.filter(func(s: Dictionary) -> bool: return s["building"] == "barracks")[0]
	check(sc.on_site(b_site) is Barracks and (sc.on_site(b_site) as Building).devastated, "the ruined barracks becomes devastated barracks, for the builders")
	check(await wait_until(func() -> bool: return sc.journal != null and sc.journal.visible, 400.0), "a restored tower gives up a journal page")
	check(sc.journal.title().begins_with("A garrison journal, page 1") and get_tree().paused, "page 1, and the game waits meanwhile")
	_close_journal()
	check(not get_tree().paused, "closed, it goes on")
	var pages := 1
	var logbook := false
	var t := 0.0
	while t < 900.0 and not sc.ruin_sites.all(func(s: Dictionary) -> bool: return sc.restored(s) != null):
		if sc.journal.visible:
			if sc.journal.title() == "The garrison's logbook":
				logbook = sc.journal.text().contains("Fiona") and sc.journal.text().contains("Rhodri")
			else:
				pages += 1
			_close_journal()
		await _skip_scene()
		await wait(0.5)
		t += 0.5
	for k in 20:  # (the last pages, one after the other)
		await frames(10)
		if sc.journal.visible:
			if sc.journal.title() == "The garrison's logbook":
				logbook = sc.journal.text().contains("Fiona") and sc.journal.text().contains("Rhodri")
			else:
				pages += 1
			_close_journal()
		await _skip_scene()
	check(sc.ruin_sites.all(func(s: Dictionary) -> bool: return sc.restored(s) != null), "all five stand again%s" % (" (game over: %s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(pages == 4 and logbook, "four journal pages and the logbook, signed for both heirs (%d pages)" % pages)

	print("-- scenario 3: specialising, training, manning")
	check(cmd("upgrade_unit", {"unit": archer.nid, "to": "crossbowman"})["ok"] and archer.kind == "crossbowman", "an archer becomes a crossbowman")
	var tg_spot := find_spot("training", v.center)
	check(cmd("place_building", {"kind": "training", "tile": tg_spot})["ok"], "training grounds are placed")
	var tg: TrainingGrounds = v.buildings().filter(func(b: Building) -> bool: return b is TrainingGrounds)[0]
	check(await wait_until(func() -> bool: return tg.complete, 300.0), "and built")
	cmd("recruit_unit", {"kind": "archer"})
	var trainee: MilitaryUnit = game.army.reserve()[0]
	cmd("station_unit", {"unit": trainee.nid, "post": tg.nid})
	check(await wait_until(func() -> bool: return trainee.state == MilitaryUnit.State.STATIONED, 120.0), "an archer at the training grounds")
	game.hero.xp = 500
	cmd("hero_mode", {"mode": Hero.Mode.TRAIN})
	check(await wait_until(func() -> bool: return trainee.level >= 1, 180.0), "Brenna trains it up a level (mode %s xp %d unit %s L%d txp %.0f/%.0f %s; paused %s phase %d cut %s journal %s)" % [game.hero.mode_name(), game.hero.xp, trainee.kind, trainee.level + 1, trainee.train_xp, trainee.train_xp_needed(), game.hero.status(), get_tree().paused, sc.phase, sc.cutscene != null, sc.journal.title() if sc.journal.visible else "-"])
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
	for s in sc.ruin_sites:
		var post := sc.restored(s) as MilitaryPost
		cmd("recruit_unit", {"kind": "shield_bearer" if post is Barracks else "archer"})
		cmd("station_unit", {"unit": game.army.reserve()[0].nid, "post": post.nid})
	check(await wait_until(func() -> bool: return sc._goal_state.get("towers", false) and sc._goal_state.get("barracks", false), 300.0), "every restored post is manned (%s)" % str(sc._goal_state))

	print("-- scenario 3: lighting the road")
	var stones := 0
	t = 0.0
	while not sc.spec._dark_road(sc).is_empty() and t < 900.0:
		var dark: Array[Vector2i] = sc.spec._dark_road(sc)
		if v.construction.queue.is_empty():
			var at := find_spot("lightstone", dark[0])
			if cmd("place_building", {"kind": "lightstone", "tile": at})["ok"]:
				stones += 1
		await _skip_scene()
		await wait(1.0)
		t += 1.0
	check(sc.spec._dark_road(sc).is_empty() and stones > 0, "light stones light the whole road (%d stones)" % stones)

	print("-- scenario 3: the waves and the win")
	game.waves.hold = false
	check(await wait_until(func() -> bool: return sc.phase != ScenarioRunner.Phase.PLAY or game.game_over, 300.0), "the line is restored and lit: the outro (%s)" % str(sc._goal_state))
	guard.queue_free()
	check(await wait_until(func() -> bool: return sc.cutscene != null or game.game_over, 200.0), "the outro plays")
	Engine.time_scale = 1.0
	await _watch(sc.cutscene)
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Wardline: complete", "won: %s" % game.hud._overlay_title.text)



# --- cutscene choices ----------------------------------------------------------------------------

func _cutscene_choice() -> void:
	print("-- a choice in a cutscene")
	await _new_game(4)
	await _skip_scene()
	var picked := [-1]
	var steps: Array[Dictionary] = [
		{"say": "", "text": "one"},
		{"do": func() -> void: picked[0] = 9},
		{"say": "", "text": "two"},
		{"say": "", "text": "which?", "choices": [
			{"text": "A", "do": func() -> void: picked[0] = 0},
			{"text": "B", "do": func() -> void: picked[0] = 1},
		]},
		{"say": "", "text": "after"},
		{"say": "", "text": "the end"},
	]
	var c := Cutscene.new()
	c.play(game, steps, {})
	await frames(2)
	c.skip()
	await frames(3)
	check(c.running and c.choosing() and c.index == 3, "Skip before a choice jumps to it (step %d)" % c.index)
	check(picked[0] == 9, "the actions on the way still ran")
	c.skip()
	c.advance()
	await frames(2)
	check(c.choosing(), "the choice waits: neither Skip nor a tap passes it")
	c.choose(1)
	await frames(2)
	check(picked[0] == 1 and c.chosen.get(3) == 1 and c.running and c.line == "after", "B picked: its action, and the cutscene goes on")
	c.skip()
	await frames(2)
	check(not is_instance_valid(c) or not c.running, "past the choice, Skip ends it")


# --- scenario 4: The Split ---------------------------------------------------------------------

func _warehouse() -> Warehouse:
	var list := sc.pieces("warehouse")
	return list[0] if not list.is_empty() else null


func _scenario_4() -> void:
	print("-- scenario 4: setup")
	await _new_game(4)
	var v := game.player_village
	check(sc != null and sc.error == "" and game.map.size == 75 and MapJson.map_name(game.map) == "The Guild Town", "scenario 4 runs on the guild town's map")
	check(not game.map.water_spawns.is_empty(), "the map has water spawns")
	var wenna: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Wenna")[0] if game.population.count("guildmaster") > 0 else null
	check(wenna is GuildMaster and wenna.label() == "Wenna", "Wenna, the guild master, is a villager")
	check(wenna != null and wenna.hut.look == "guild_house" and wenna.hut.display_name() == "Guild House", "her hut is the guild house")
	check(not game.population.recruit_error("guildmaster").is_empty() and not game.hud._recruit_rows.has("guildmaster"), "guild masters can't be recruited")
	check(sc.merchant() != null and sc.merchant().label() == "Pell", "Pell is there")
	var stall: Stall = sc.stalls()[0] if not sc.stalls().is_empty() else null
	check(stall != null and stall.level == 3 and stall.display_name() == "Guild Market", "the full guild market")
	var w := _warehouse()
	check(w != null and w.size == 2 and w.complete and w.hp == w.max_hp() and w.display_name() == "Guild Warehouse", "the guild warehouse stands, 2x2, whole")
	check(w != null and game.siege.in_zone(v, w.tile) and not v.rect.has_point(w.tile), "by the walls, where enemies leave their roads")
	var water_d := INF
	for y in range(v.rect.position.y - 14, v.rect.end.y + 14):
		for x in range(v.rect.position.x - 14, v.rect.end.x + 14):
			if game.map.is_water(Vector2i(x, y)) and w != null:
				water_d = minf(water_d, Vector2(x, y).distance_to(Vector2(w.tile)))
	check(water_d <= 8.0, "on the harbour side, by the water (%.1f tiles)" % water_d)
	check(w != null and not w.can_tear_down() and not game.allows_building("warehouse"), "it can't be torn down or built")
	check(game.hero.level == 4 and not sc.spec.hero_revives, "Brenna at level 5; she can't be brought back")
	check(game.waves.scripted.size() == 9 and game.waves.last_wave == 9, "nine scripted waves")
	await wait(1.0)
	check(sc.cutscene != null, "the intro plays")
	var said := await _watch(sc.cutscene)
	check(said.has("wenna") and said.has("pell") and said.has("brenna"), "Wenna, Pell and Brenna speak (%s)" % str(said))
	check(sc.phase == ScenarioRunner.Phase.PLAY and sc.card.lesson_title() == "The warehouse", "play: the warehouse's card")

	print("-- scenario 4: the warehouse is plundered")
	game.selected = w
	check(await wait_until(func() -> bool: return sc.step == 1, 10.0), "the card is done once it is looked at")
	cmd("hero_mode", {"mode": Hero.Mode.REST})
	var road := game.world.pathing.nearest_road(w.tile)
	var gob := game.waves.spawn_at("goblin", road, v, 1)
	gob.max_hp = 1e6
	gob.hp = gob.max_hp
	var huts := v.intact_huts().size()
	check(await wait_until(func() -> bool: return w.hp < w.max_hp() or not is_instance_valid(gob) or gob.dead, 120.0), "a goblin by the warehouse goes for it")
	check(is_equal_approx(w.hp, w.max_hp() - float(Config.WAREHOUSE["raid_damage"])), "and plunders it: %d HP (%d / %d)" % [int(Config.WAREHOUSE["raid_damage"]), w.hp, w.max_hp()])
	check(not is_instance_valid(gob) or gob.dead, "the goblin is gone then")
	check(v.intact_huts().size() == huts, "no hut burned for it")
	check(await wait_until(func() -> bool: return sc.card.hint().begins_with("The warehouse is hit"), 5.0), "a hint: repair it")
	check(w.can_repair() and cmd("repair", {"building": w.nid})["ok"], "it can be repaired")

	print("-- scenario 4: guarding the harbour")
	var spot := find_spot("tower", w.tile)
	check(cmd("place_building", {"kind": "tower", "tile": spot})["ok"], "a watchtower by the warehouse")
	cmd("recruit_unit", {"kind": "archer"})
	Engine.time_scale = 4.0
	var tower: Tower = sc.towers().filter(func(t: Tower) -> bool: return t.tile == spot)[0]
	check(await wait_until(func() -> bool: return tower.complete, 200.0), "it stands")
	cmd("station_unit", {"unit": game.army.reserve()[0].nid, "post": tower.nid})
	check(await wait_until(func() -> bool: return sc.step == 2, 120.0), "manned: the harbour is guarded; the call card")
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})

	print("-- scenario 4: the waves, the offer, the coins")
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	var crab_water := false
	var offered := false
	var coins := false
	var t := 0.0
	while not game.waves.all_done() and not game.game_over and t < 1500.0:
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if e.kind == "crab" and game.map.is_water(e.home_tile):
				crab_water = true
		if sc.journal != null and sc.journal.visible:
			coins = coins or sc.journal.title() == "Foreign coins"
			_close_journal()
		if sc.cutscene != null:
			if sc.cutscene.steps.any(func(st: Dictionary) -> bool: return st.has("choices")):
				offered = true
				await _watch(sc.cutscene, 1)
				Engine.time_scale = 4.0
			else:
				await _skip_scene()
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5
	check(not game.game_over and game.waves.all_done(), "nine waves held%s" % (" (game over: %s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(crab_water, "crabs come out of the sea (a water spawn)")
	check(offered, "the rival's offer was made, and refused")
	check(coins, "the captured Renegade's coins")
	check(await wait_until(func() -> bool: return sc.cutscene != null, 120.0), "the outro plays")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("pell") and said.has("brenna"), "Pell reads the ledger (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Split: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 4: defeats")
	await _new_game(4)
	await _skip_scene()
	sc.spec.on_wave_finished(sc, 3)
	check(await wait_until(func() -> bool: return sc.cutscene != null, 5.0), "the rival's offer")
	await _watch(sc.cutscene, 0)
	await frames(3)
	check(game.game_over and game.hud._overlay_sub.text.contains("took the rival guild's gold"), "taking the gold loses the scenario (%s)" % game.hud._overlay_sub.text)
	await _new_game(4)
	await _skip_scene()
	_warehouse().take_damage(1e6)
	check(await wait_until(func() -> bool: return game.game_over, 3.0), "the warehouse falls: lost")
	check(game.hud._overlay_title.text == "The Split failed" and game.hud._overlay_sub.text.contains("warehouse"), "it says so (%s)" % game.hud._overlay_sub.text)
	await _new_game(4)
	await _skip_scene()
	var wn: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Wenna")[0]
	game.population.kill(wn, "when goblin 2 burned her home", "hut")
	await frames(2)
	check(game.game_over and game.hud._overlay_sub.text.contains("Wenna"), "Wenna dies: lost (%s)" % game.hud._overlay_sub.text)
	await _new_game(4)
	await _skip_scene()
	game.hero.take_damage(1e6)
	await frames(3)
	check(game.game_over and game.hud._overlay_sub.text.contains("nobody can bring her back"), "Brenna is downed: lost (%s)" % game.hud._overlay_sub.text)


# --- scenario 5: The Betrayal ------------------------------------------------------------------

func _scenario_5() -> void:
	print("-- scenario 5: setup")
	await _new_game(5)
	var v := game.player_village
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Old Fort", "scenario 5 runs on the old fort's map")
	var sig := game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Sigmund")
	check(sig.size() == 1 and (sig[0] as Civilian).role == "builder", "Sigmund is there, a builder")
	check(v.intact_huts().size() == 6, "six huts stand (%d)" % v.intact_huts().size())
	check(sc.pieces("wall").filter(func(b: Building) -> bool: return not b.devastated).size() == 2, "two walls stand")
	check(sc.stalls().size() == 1 and sc.stalls()[0].level == 1, "Pell's wagon: a peddler's stall")
	check(game.hero.level == 6 and not sc.spec.hero_revives, "Brenna at level 7, no revive")
	var ev: Array = sc.spec._evidence(sc)
	check(ev.size() == 3, "three treasures hold the evidence")
	check(ev.all(func(o: Treasure) -> bool: return game.fog.is_explored_by(v.id, o.tile)), "their places are known")
	check(game.waves.scripted.size() == 10, "ten waves")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("sigmund") and said.has("brenna"), "the intro: Sigmund and Brenna (%s)" % str(said))
	check(sc.card.lesson_title() == "The evidence", "the evidence card")

	print("-- scenario 5: the Dread Legion")
	cmd("hero_mode", {"mode": Hero.Mode.REST})
	var road := game.world.pathing.nearest_road(v.center + Vector2i(0, -12))
	var foot := game.waves.spawn_at("legion_footman", road, v, 1)
	check(foot.label().begins_with("legion footman") and foot.unit_art() == "unit_legion_footman", "a Legion footman")
	var corpses := game.corpses.corpses.size()
	kill(foot)
	await frames(3)
	check(foot.dead and game.corpses.corpses.size() == corpses, "slain, it is released: no corpse")
	var lysa := game.waves.spawn_at("legion_captain", road, v, 1)
	lysa.set_identity("Lysa", "legion_captain_lysa")
	check(lysa.label() == "Lysa" and lysa.unit_art() == "unit_legion_captain_lysa", "a captain with a name and a look of her own")
	lysa.take_damage(1e6)
	check(not lysa.dead and lysa.retreating and not lysa.targetable(), "never killed: below 30 % she falls back, out of reach")
	check(is_equal_approx(lysa.hp, lysa.max_hp * 0.3), "with 30 % of her HP")
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return not is_instance_valid(lysa) or lysa.dead, 120.0), "she walks back up her road and leaves the map")
	var lib := Library.entries("enemies").filter(func(e: Dictionary) -> bool: return str(e["name"]).begins_with("Legion"))
	check(lib.size() == 2 and lib.all(func(e: Dictionary) -> bool: return (e["facts"] as PackedStringArray).has("The Dread Legion: people, bound to Rhodri. Only in the campaign")), "the library has the footman and the captain, as people")

	print("-- scenario 5: the evidence")
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
	var pages := 0
	for o: Treasure in ev:
		o.mark_looted()
		check(await wait_until(func() -> bool: return sc.journal != null and sc.journal.visible, 10.0), "a found piece: its page")
		pages += 1
		_close_journal()
	check(pages == 3 and int(sc.mark.get("found", 0)) == 3, "all three found (%d)" % int(sc.mark.get("found", 0)))
	check(await wait_until(func() -> bool: return sc._goal_state.get("evidence", false), 5.0), "the evidence objective is met")

	print("-- scenario 5: the waves, the Legion's last wave")
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	var legion := false
	var captains := {}
	var fell_back := false
	var gate := sc.spec._old_gate(sc) as Vector2i
	var gargoyles := [0]
	var seen := func(n: Node) -> void:  # (the guard kills them before the next look; a beaten captain leaves)
		if n is Enemy and (n as Enemy).given_name != "":
			captains[(n as Enemy).given_name] = true
		if n is Enemy and (n as Enemy).kind == "gargoyle" and (n as Enemy).home_tile == gate:
			gargoyles[0] += 1
	get_tree().node_added.connect(seen)
	var scenes := 0
	var t := 0.0
	while not game.waves.all_done() and not game.game_over and t < 1500.0:
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			legion = legion or e.kind == "legion_footman"
			if e.given_name != "":
				captains[e.given_name] = true
		var falls := func(steps: Array) -> bool: return steps.any(func(st: Dictionary) -> bool: return str(st.get("text", "")).contains("Still following orders"))
		if sc._scene_queue.any(func(q: Array) -> bool: return falls.call(q)):
			fell_back = true  # (queued behind the wave's own scene: the wave may end first)
		if sc.cutscene != null:
			scenes += 1
			if falls.call(sc.cutscene.steps):
				fell_back = true
			await _skip_scene()
		if sc.journal != null and sc.journal.visible:
			_close_journal()
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5
	get_tree().node_added.disconnect(seen)
	check(not game.game_over and game.waves.all_done(), "ten waves held%s" % (" (game over: %s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(scenes >= 5, "Sigmund tells it between the waves (%d scenes)" % scenes)
	check(legion and captains.has("Lysa") and captains.has("Torben"), "the last wave: the Legion, with Lysa and Torben (%s)" % str(captains.keys()))
	check(gargoyles[0] == 3, "and the old gate's three gargoyles (%d)" % gargoyles[0])
	check(fell_back, "Brenna sees a captain fall back")
	check(await wait_until(func() -> bool: return sc.cutscene != null, 120.0), "the outro plays")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("brenna") and said.has("pell"), "Brenna reads the order (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Betrayal: complete", "won: %s" % game.hud._overlay_title.text)


# --- scenario 6: The Dead ---------------------------------------------------------------------

func _graveyard() -> Graveyard:
	var list := sc.pieces("graveyard")
	return list[0] if not list.is_empty() else null


func _scenario_6() -> void:
	print("-- scenario 6: setup")
	await _new_game(6)
	var v := game.player_village
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Field of Bones", "scenario 6 runs on the battlefield's map")
	var ans := game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Anselm")
	check(ans.size() == 1 and ans[0] is Resident and (ans[0] as Civilian).role == "priest" and (ans[0] as Civilian).status() == "praying for the dead", "Anselm, the priest, stays in his house")
	check(ans.size() == 1 and (ans[0] as Civilian).hut.look == "priest_house" and (ans[0] as Civilian).hut.display_name() == "Anselm's House", "his house has its own look and name")
	check(not game.population.recruit_error("priest").is_empty() and not game.population.recruit_error("princess").is_empty(), "priests and princesses can't be recruited")
	var gy := _graveyard()
	var chapel := sc.site("chapel")
	check(gy != null and chapel != null and Vector2(gy.tile).distance_to(Vector2(chapel.tile)) <= 7.0, "the graveyard stands by the chapel")
	check(gy != null and gy.working() and gy.buried == 0 and not gy.can_tear_down(), "an empty graveyard, which can't be torn down")
	check(chapel != null and chapel.awake, "the chapel is only sleeping: awake from the start")
	var fallen := game.corpses.fallen()
	check(fallen.size() == sc.spec.FALLEN, "%d of the fallen lie on the field (%d)" % [sc.spec.FALLEN, fallen.size()])
	check(fallen.all(func(c: Corpse) -> bool: return game.fog.is_explored_by(v.id, c.tile()) and c.kind == "skeleton" and c.revivable), "their places are known; raised, they'd be skeletons")
	check(game.hero.level == 8 and not sc.spec.hero_revives and sc.spec.must_live.has("Anselm"), "Brenna at level 9, no revive, Anselm must live")
	check(game.waves.scripted.size() == 8 and sc.spec.repeat_last, "eight waves, then more until enough are buried")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("anselm") and said.has("brenna"), "the intro: Anselm and Brenna (%s)" % str(said))
	check(sc.card.lesson_title() == "The fallen", "the fallen card")

	print("-- scenario 6: the fallen")
	game.corpses.clear_wave(99)
	fallen[0].time_left = -1.0
	await frames(2)
	check(sc.spec._still_to_bury(sc) + gy.buried == sc.spec.FALLEN, "the fallen never rot and are never cleared away (%d)" % (sc.spec._still_to_bury(sc) + gy.buried))
	check(cmd("recruit_villager", {"role": "gatherer"})["ok"], "a third gatherer")
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return gy.buried >= 1, 120.0), "gatherers carry the fallen to the graveyard: buried (%d)" % gy.buried)
	check(game.population.civilians.any(func(c: Civilian) -> bool: return c is Gatherer and (c as Gatherer).status().contains("graveyard")) or gy.buried > 0, "on their way: to the graveyard")
	check(await _at_card(1, 120.0), "the fallen card is done once three are buried (%d)" % gy.buried)
	var necro := game.waves.spawn_at("necromancer", game.world.pathing.nearest_road(v.center + Vector2i(0, -10)), v, 1)
	var risen := game.waves.raise_corpse(game.corpses.fallen()[-1], necro)
	check(risen != null and risen.kind == "skeleton" and risen.raised, "a necromancer raises one of the fallen: a skeleton")
	check(await wait_until(func() -> bool: return sc.card.hint().begins_with("One of the fallen has risen"), 3.0), "a hint says so (%s)" % sc.card.hint())
	kill(necro)
	kill(risen)
	Engine.time_scale = 1.0

	print("-- scenario 6: the chapel")
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return game.is_unlocked("acolyte"), 180.0), "Brenna wakes the chapel: acolytes")
	check(await wait_until(func() -> bool: return sc.cutscene != null, 5.0), "a scene at the chapel")
	await _skip_scene()
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
	check(await _at_card(2, 10.0), "the holy light card")
	var tower: Tower = sc.towers()[0]
	cmd("withdraw_unit", {"unit": tower.garrison.nid})
	check(cmd("recruit_unit", {"kind": "acolyte"})["ok"], "an acolyte")
	var aco: MilitaryUnit = game.army.units.filter(func(u: MilitaryUnit) -> bool: return u.kind == "acolyte")[0]
	check(await wait_until(func() -> bool: return tower.garrison == null and tower.incoming_slots.all(func(u) -> bool: return u == null), 60.0), "the archer walks off")
	cmd("station_unit", {"unit": aco.nid, "post": tower.nid})
	check(await wait_until(func() -> bool: return sc.step >= sc.steps.size(), 90.0), "an acolyte on the tower: the cards are done")

	print("-- scenario 6: the waves, burying")
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	var scenes := 0
	var t := 0.0
	while sc.phase == ScenarioRunner.Phase.PLAY and not game.game_over and t < 1500.0:
		if sc.cutscene != null:
			scenes += 1
			await _skip_scene()
		await wait(0.5)
		t += 0.5
	check(not game.game_over, "no defeat%s" % (" (%s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(gy.buried >= sc.spec.BURY, "%d of the fallen buried (%d)" % [sc.spec.BURY, gy.buried])
	check(scenes >= 2, "Anselm tells of the battle between the waves (%d scenes)" % scenes)
	check(await wait_until(func() -> bool: return sc.cutscene != null, 180.0), "the outro plays")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("anselm") and said.has("brenna"), "Anselm tells where the court went (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Dead: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 6: too many risen")
	await _new_game(6)
	sc.cutscene.skip()
	await frames(2)
	var list := game.corpses.fallen()
	for i in sc.spec.FALLEN - sc.spec.BURY + 1:
		game.corpses.remove(list[i])
	check(await wait_until(func() -> bool: return game.game_over, 3.0), "too many of the fallen gone: lost")
	check(game.hud._overlay_sub.text.contains("Too many of the fallen have risen"), "it says why (%s)" % game.hud._overlay_sub.text)


# --- scenario 7: The Exile --------------------------------------------------------------------

func _druids() -> Array[MilitaryUnit]:
	var out: Array[MilitaryUnit] = []
	out.assign(game.army.units.filter(func(u: MilitaryUnit) -> bool: return u.kind == "druid"))
	return out


func _scenario_7() -> void:
	print("-- scenario 7: setup")
	await _new_game(7)
	var v := game.player_village
	var h := game.hero
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Refuge", "scenario 7 runs on the refuge's map")
	var fi := game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Fiona")
	check(fi.size() == 1 and fi[0] is Resident and (fi[0] as Civilian).hut.display_name() == "Fiona's House", "Fiona stays in her house")
	check(v.intact_huts().size() == 8, "one hut lies in ruins (%d stand)" % v.intact_huts().size())
	check(sc.farms().size() == 1 and await wait_until(func() -> bool: return (sc.farms()[0] as Farm).farmer != null, 5.0), "a farm by a road (no room by the walls), and its farmer")
	var grove: Grove = sc.pieces("grove")[0] if not sc.pieces("grove").is_empty() else null
	var circle := sc.site("stone_circle")
	check(grove != null and circle != null and Vector2(grove.tile).distance_to(Vector2(circle.tile)) <= 7.0, "the druids' grove by the stone circle")
	check(_druids().size() == 3 and _druids().all(func(u: MilitaryUnit) -> bool: return u.post == grove and u.level == 3 and u.fixed()), "three druids (level 4) on its benches")
	check(grove != null and grove.max_level() == grove.level and not grove.can_tear_down(), "the grove can't be upgraded or torn down")
	var d0 := _druids()[0]
	check(not cmd("withdraw_unit", {"unit": d0.nid})["ok"] and not cmd("upgrade_unit", {"unit": d0.nid, "to": "druid"})["ok"] and d0.upgrade_options().is_empty(), "druids take no orders")
	check(game.is_unlocked("acolyte") and not game.is_unlocked("apprentice") and not game.is_unlocked("summoner"), "acolytes from the start; apprentices and summoners not yet")
	check(not sc.site("mage_tower").awake and not circle.awake, "the tower and the circle sleep")
	check(game.waves.scripted.size() == 12 and sc.spec.must_live.has("Fiona"), "twelve waves; Fiona must live")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("fiona") and said.has("brenna") and said.has("pell"), "the intro: Fiona at the gate (%s)" % str(said))
	check(sc.phase == ScenarioRunner.Phase.PLAY and h.home_override == sc.spec.hero_start and is_instance_valid(sc.tent_node), "Brenna camps outside, by her tent")
	check(h.home() == sc.spec.hero_start and h.grid_pos.distance_to(Vector2(sc.spec.hero_start)) < 0.5, "her post is the tent")

	print("-- scenario 7: outside the walls")
	var wall: Building = sc.pieces("wall").filter(func(b: Building) -> bool: return b.devastated)[0]
	var ruin: Building = v.huts().filter(func(b: Building) -> bool: return not (b as Hut).is_intact())[0]
	check(not cmd("repair", {"building": wall.nid})["ok"] and not cmd("rebuild_hut", {"building": ruin.nid})["ok"], "no repairs, no rebuilding")
	check(not cmd("recruit_villager", {"role": "builder"})["ok"] and not cmd("place_building", {"kind": "tower", "tile": find_spot("tower", v.center + Vector2i(6, 3))})["ok"], "no villagers, no building")
	check(cmd("recruit_unit", {"kind": "archer"})["ok"], "soldiers can be hired")
	var post: Building = sc.pieces("wall_tower").filter(func(b: Building) -> bool: return not b.devastated and (b as Tower).garrison == null)[0]
	cmd("station_unit", {"unit": game.army.reserve()[0].nid, "post": post.nid})
	check(await wait_until(func() -> bool: return sc.step >= 1 or sc._next_in >= 0.0, 60.0), "and stationed: the card is done")
	await wait(2.0)
	check(sc.step == 0 and sc.card.lesson_text().begins_with("Hold the first waves"), "the next one waits for Fiona (%s)" % sc.card.lesson_text())

	print("-- scenario 7: the waves, Fiona's trust, the grove")
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	Engine.time_scale = 4.0
	var band := [0]
	var at: Vector2i = sc.spec._grove_road(sc)
	var seen := func(n: Node) -> void:
		if n is Enemy and (n as Enemy).home_tile == at:
			band[0] += 1
	get_tree().node_added.connect(seen)
	var checked_in := false
	var checked_build := false
	var apprentice := false
	var scenes := 0
	var t := 0.0
	guard.start()
	while not game.waves.all_done() and not game.game_over and t < 1800.0:
		if sc.cutscene != null:
			scenes += 1
			await _skip_scene()
		var trust := int(sc.mark.get("trust", 0))
		if trust >= 1 and not checked_in:
			checked_in = true
			check(h.home_override == Vector2i(-1, -1) and not is_instance_valid(sc.tent_node), "after wave 2 Brenna moves in")
			check(sc.site("mage_tower").awake, "the court mages open their tower")
			check(cmd("repair", {"building": wall.nid})["ok"] and cmd("rebuild_hut", {"building": ruin.nid})["ok"], "repairs and rebuilding now")
			check(not cmd("place_building", {"kind": "tower", "tile": find_spot("tower", v.center + Vector2i(6, 3))})["ok"], "but nothing new yet")
			cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
		if checked_in and not apprentice and game.is_unlocked("apprentice"):
			apprentice = true
			cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
		if trust >= 2 and not checked_build:
			checked_build = true
			check(cmd("place_building", {"kind": "tower", "tile": find_spot("tower", v.center + Vector2i(6, 3))})["ok"], "after wave 7 new buildings")
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5
	get_tree().node_added.disconnect(seen)
	check(not game.game_over and game.waves.all_done(), "twelve waves held%s" % (" (game over: %s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(checked_in and checked_build and int(sc.mark.get("trust", 0)) == 2, "Fiona's trust in two steps")
	check(apprentice, "Brenna unlocks the apprentice at the mages' tower")
	check(band[0] == 11, "wave 5's band came down the north road to the grove (%d)" % band[0])
	check(circle.awake and sc.mark.has("grove over"), "the grove held: the circle answers")
	check(scenes >= 4, "the talks between the waves (%d scenes)" % scenes)
	check(await wait_until(func() -> bool: return sc.cutscene != null, 120.0), "the outro plays")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("fiona") and said.has("brenna"), "Fiona's scroll (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Exile: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 7: a druid falls in wave 5")
	await _new_game(7)
	sc.cutscene.skip()
	await frames(2)
	sc.mark["grove watch"] = true
	await wait(0.6)
	game.army.down(_druids()[0], null)
	check(await wait_until(func() -> bool: return game.game_over, 3.0), "a druid downed while the grove is attacked: lost")
	check(game.hud._overlay_sub.text.contains("A druid fell"), "it says why (%s)" % game.hud._overlay_sub.text)
