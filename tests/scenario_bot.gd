extends "res://tests/bot_base.gd"
## Headless test of the campaign's scenarios (docs/scenarios-design.md):
## scenario 1, Homecoming, played through with commands: its baseline (map
## file, ruins, villagers, Einar, Brenna at her tent), its rules, the intro
## cutscene and the walk home, the arrival, every card, the waves, the
## objectives, the outro and the win; a villager's death as a defeat; the
## hints; the title screen's Campaign page.

var sc: ScenarioRunner


func _run() -> void:
	var diff := Settings.difficulty
	Settings.difficulty = Settings.Difficulty.HARD
	_map_file()
	await _play_through()
	await _defeat()
	await _hints()
	check(Settings.difficulty == Settings.Difficulty.HARD and Settings.enemy_scale.is_empty(), "the player's difficulty is back, no scenario scale left, once the game is gone")
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


func _new_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await frames(2)
	Settings.scenario_next = 1
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await frames(3)
	sc = game.scenario


## Through a cutscene: every line (a tap shows it whole, the next goes on).
## Returns the speakers' ids in order.
func _watch(c: Cutscene) -> Array[String]:
	var said: Array[String] = []
	var t := 0.0
	while is_instance_valid(c) and c.running and t < 90.0:
		if c.line != "":
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


## Every enemy of the waves dies (not the camps' guards).
func _kill_wave() -> void:
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not (e.behavior is CampBehavior):
			kill(e, game.hero)


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
	check(t.scenario_buttons.size() == Campaign.count() and t.scenario_buttons[0].text == "1. Homecoming", "scenario 1 is there: %s" % t.scenario_buttons[0].text)
	check(t._campaign_page.get_children().any(func(c: Node) -> bool: return c is Label and (c as Label).text.contains("still to come")), "and the rest are to come")
	t.show_page(t._main_page)
	t.queue_free()
	await frames(1)
