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
##   -- --only=1|2|...|11  one scenario only (the title screen with 1); several: --only=9,11
##   -- --s9=rescued|drowned|escape|more  scenario 9: just that part

var sc: ScenarioRunner
## Every named enemy that came on the map (name -> kind), however soon it was gone.
var named := {}


func _run() -> void:
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Enemy:
			(func() -> void:
				if is_instance_valid(n) and (n as Enemy).given_name != "":
					named[(n as Enemy).given_name] = (n as Enemy).kind).call_deferred())
	var diff := Settings.difficulty
	Settings.difficulty = Settings.Difficulty.HARD
	var only := PackedStringArray()  # (empty: everything)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	if only.is_empty() or "1" in only:
		_map_file()
		await _play_through()
		await _defeat()
		await _hints()
	if only.is_empty() or "2" in only:
		await _scenario_2()
	if only.is_empty() or "3" in only:
		await _scenario_3()
	if only.is_empty() or "4" in only:
		await _cutscene_choice()
		await _scenario_4()
	if only.is_empty() or "5" in only:
		await _scenario_5()
	if only.is_empty() or "6" in only:
		await _scenario_6()
	if only.is_empty() or "7" in only:
		await _scenario_7()
	if only.is_empty() or "8" in only:
		await _scenario_8()
	if only.is_empty() or "9" in only:
		await _scenario_9()
	if only.is_empty() or "10" in only:
		await _scenario_10()
	if only.is_empty() or "11" in only:
		await _scenario_11()
	if is_instance_valid(game):
		game.queue_free()
		await frames(2)
	check(Settings.difficulty == Settings.Difficulty.HARD and Settings.enemy_scale.is_empty(), "the player's difficulty is back, no scenario scale left, once the game is gone")
	if only.is_empty() or "1" in only or "title" in only:
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
	named.clear()
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

	print("-- card 9: mending the walls")
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
	for b: Building in sc.pieces("gate") + sc.pieces("wall") + sc.pieces("wall_tower"):
		if not sc.whole(b) and not b.repairing:
			cmd("repair", {"building": b.nid})
	game.hero.set_mode(Hero.Mode.BUILD)
	check(await wait_until(func() -> bool: return sc.pieces("hut").all(sc.whole), 600.0), "every hut rebuilt")
	cmd("recruit_villager", {"role": "builder"})
	check(await wait_until(func() -> bool: return (sc.pieces("gate") + sc.pieces("wall") + sc.pieces("wall_tower")).all(sc.whole), 600.0), "every gate, wall and wall tower repaired")
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
		if e.given_name != "" and e.given_name == spare:
			continue
		if spare_kinds.has(e.kind) or spare_kinds.any(func(k: String) -> bool: return k.ends_with("*") and e.kind.begins_with(k.trim_suffix("*"))):
			continue
		if kill_camps or not (e.behavior is CampBehavior):
			kill(e, game.hero)


## _kill_wave kills the camps' guards too (scenario 3: two camps by the north road).
var kill_camps := false
## _kill_wave leaves the enemy of this name alone (scenario 9's leviathan, for a while).
var spare := ""
## _kill_wave leaves enemies of these kinds alone ("legion_*": every kind beginning so).
var spare_kinds: Array[String] = []


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
	print("-- campaign progress")
	Campaign.reset_progress()
	var none := Campaign.completed()
	check(none.is_empty() and Campaign.next_to_play(none) == 1, "no progress: scenario 1 is next")
	check(Campaign.unlocked(1, none, false) and not Campaign.unlocked(2, none, false), "release: only scenario 1 is open")
	check(Campaign.unlocked(5, none, true), "debug builds: every scenario")
	Campaign.complete(1)
	Campaign.complete(2)
	Campaign.complete(1)
	var done := Campaign.completed()
	check(done == ["Homecoming", "The Old Friend"], "completed scenarios are kept by their titles (%s)" % str(done))
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Campaign.PROGRESS_FILE))
	check(int(file["format"]) == Campaign.PROGRESS_FORMAT and file["campaign"] == Array(Campaign.titles()), "the file records its format and the campaign it was written for")
	check(Campaign.next_to_play(done) == 3 and Campaign.unlocked(3, done, false) and not Campaign.unlocked(4, done, false), "then 3 is next and open, 4 locked")
	done.append("A scenario that is gone")
	check(Campaign.next_to_play(done) == 3, "a title no longer in the campaign changes nothing")
	var later: Array[String] = ["The Split"]
	check(Campaign.unlocked(2, later, false) and Campaign.unlocked(5, later, false), "a scenario before a completed one stays open (one added later)")
	print("-- title screen")
	var t = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await frames(2)
	var cb: Button = t.campaign_button
	check(cb.is_visible_in_tree() and cb.get_index() == 0 and cb.icon == Art.tex("icon_campaign"), "Campaign comes first on the main page, with its banner")
	cb.pressed.emit()
	await frames(2)
	var cm: CampaignMap = t.campaign_map
	check(cm.visible and not t._menu.visible, "it opens the campaign map over the whole screen")
	var places := {}
	for n in range(1, Campaign.count() + 1):
		var sp := Campaign.scenario(n)
		check(Campaign.places().has(sp.place) and ResourceLoader.exists("res://art/%s.svg" % sp.portrait), "scenario %d has a place on the map and a portrait (%s)" % [n, sp.place])
		places[sp.place] = true
	check(places.size() == Campaign.places().size(), "every place has a scenario")
	check(cm.scenarios_at("outpost") == [1, 2, 3, 10] and cm.scenarios_at("capital") == [8, 11], "scenarios on the same map share a place")
	var ms := Campaign.map_size() * cm.zoom
	check(ms.x >= cm.size.x - 0.5 and ms.y >= cm.size.y - 0.5, "the map covers the whole screen")
	var gaps := range(2, Campaign.count() + 1).filter(func(n: int) -> bool: return Campaign.scenario(n - 1).place != Campaign.scenario(n).place and cm.route_to(n).size() < 2)
	check(gaps.is_empty(), "every stretch of Brenna's route follows the roads (%s)" % str(gaps))
	var roads: Array = Campaign.layout()["roads"]
	var ends := func(id: String) -> int: return roads.filter(func(rd: Dictionary) -> bool: return rd["a"] == id or rd["b"] == id).size()
	check(ends.call("outpost") == 1 and ends.call("refuge") == 1, "the outpost and Fiona's refuge each lie at the end of one road")
	check(ends.call("north_town") >= 2 and not Campaign.places().has("north_town"), "the outpost's road leads to an unnamed town (no pin)")
	var through := func(from: String, to: String, via: String) -> bool:
		var way := Campaign.route(from, to)
		var at: Vector2 = Campaign.places()[via]["at"] if Campaign.places().has(via) else Vector2(-1, -1)
		return not way.is_empty() and Array(way).any(func(q: Vector2) -> bool: return q.distance_to(at) < 1.0)
	check(through.call("battlefield", "to_karmere", "old_fort"), "the road to Karmere runs through the old fort")
	check(not Campaign.route("battlefield", "to_lyrenne").is_empty() and not through.call("battlefield", "to_lyrenne", "refuge"), "the road to Lyrenne doesn't pass the refuge")
	check(ends.call("to_aurelith_west") == 1 and ends.call("to_aurelith_east") == 1 and through.call("capital", "to_aurelith_west", "abbey"), "two roads into Aurelith, one by the drowned abbey")
	check(Campaign.places().values().all(func(p: Dictionary) -> bool: return Array(str(p["name"]).split(" ")).all(func(w: String) -> bool: return w == w.capitalize() or w.ends_with("'s"))), "place names in Title Case")
	var r := Campaign.route("outpost", "guild_town")
	check(r.size() > 2 and r[0] == Campaign.places()["outpost"]["at"] and r[r.size() - 1] == Campaign.places()["guild_town"]["at"], "a route runs from place to place")
	await wait(1.0)
	var free := cm._free_rect()
	check(free.has_point(cm.place_point("outpost")) and cm.zoom > Campaign.map_size().x / 1e4, "the map glides to the chosen place, beside the scroll")
	check(cm.card_open() and cm.selected == 3, "the card opens on the next to play (3)")
	check(cm.rows.has(1) and cm.rows[1].icon == Art.tex("icon_check") and cm.rows[3].icon == null and not cm.play_button.disabled, "its place's scenarios: completed ones carry a check")
	check(Campaign.places().keys().all(func(id: String) -> bool: return not cm.unknown(id)), "a debug build: every place shown")
	var before := cm.center
	for ev: InputEvent in [_mouse(true, Vector2(500, 400)), _motion(Vector2(560, 430)), _motion(Vector2(620, 460)), _mouse(false, Vector2(620, 460))]:
		cm._on_map_input(ev)
	check(cm.center != before and cm.card_open(), "dragging the map pans it (the scroll stays)")
	cm._on_map_input(_mouse(true, Vector2(500, 400)))
	cm._on_map_input(_mouse(false, Vector2(502, 401)))
	check(not cm.card_open(), "a tap on the map rolls the scroll up")
	cm.show_card(3)
	cm.step(1)
	check(cm.selected == 4 and cm.rows.has(4) and not cm.rows.has(3), "a step: the next scenario, at its own place")
	cm.pin("old_fort").pressed.emit()
	check(cm.selected == 5, "a tap on a pin: its scenario")
	var started := [0]
	cm.play.connect(func(n: int) -> void: started[0] = n)
	t.campaign_map.play.disconnect(t.play_scenario)
	cm.play_button.pressed.emit()
	check(started[0] == 5, "Play starts it")
	cm.show_all = false
	cm.open()
	await frames(2)
	check(cm.unknown("battlefield") and not cm.pin("battlefield").visible and not cm.unknown("outpost") and cm.unknown("guild_town"), "a release build: places not open aren't shown (1 and 2 done: only the outpost)")
	check(cm.sealed("guild_town") == false and not cm.sealed("outpost"), "no seal where something is left to play")
	Campaign.complete(4)
	cm.open()
	await frames(2)
	check(cm.sealed("guild_town") and cm.selected == 5 and not cm.unknown("old_fort"), "4 done: the guild town sealed, the old fort open and next")
	cm.show_card(10)
	check(cm.play_button.disabled and cm.rows[10].text == "10. Locked", "a locked scenario: shown as locked, no Play")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	check(not cm.card_open() and cm.visible, "Esc: the card closes first")
	Input.parse_input_event(esc)
	await frames(2)
	check(not cm.visible and t._menu.visible and t._main_page.visible, "then the map, back to the menu")
	t.queue_free()
	Campaign.reset_progress()
	await frames(1)


func _mouse(down: bool, at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.global_position = at
	return e


func _motion(at: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.global_position = at
	return e


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
	check(await wait_until(func() -> bool: return sc.step == 1, 240.0) and sc.card.lesson_title() == "Brenna explores", "the hero's card once it stands (%s)" % sc.card.lesson_title())
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
	stall.stored = 0.0
	stall.sold = 0  # (the trade card comes later; these buys don't count for it)

	print("-- scenario 2: rats at the stall")
	var road_t := sc.road_to_village(stall.tile)
	var near: Vector2i = road_t[0] if not road_t.is_empty() else stall.tile
	game.population.unassign_worker(stall)  # (Pell goes home: a rat would go for him first)
	check(await wait_until(func() -> bool: return pell.at_home, 60.0) and not stall.is_open(), "Pell away: the stall is closed")
	stall.stored = 30.0
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
	stall.stored = 0.0

	print("-- scenario 2: the ruin, trade after wave 2, levels, barracks, a tower upgrade")
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	var site: Dictionary = sc.ruin_sites[0]
	check(await wait_until(func() -> bool: return sc.claimed(site), 400.0), "Brenna claims the broken watchtower")
	check(await wait_until(func() -> bool: return sc.step == 2, 5.0), "the restore card")
	var ruin = sc.on_site(site)
	check(cmd("restore_ruin", {"ruin": ruin.nid})["ok"], "it is restored")
	await wait(3.0)
	check(sc.step == 2 and sc.card.lesson_title() == "Pell's goods" and sc.highlight.tiles.is_empty(), "the trade card waits for wave 2 and the goods; nothing is marked (%s)" % sc.card.lesson_title())
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	while game.waves.wave < 2 or game.waves.in_progress():
		stall.stored = 0.0  # (no goods yet: the card waits for both)
		if sc.cutscene != null:
			await _skip_scene()
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
	stall.stored = 0.0
	await wait(1.0)
	check(sc.step == 2, "after wave 2, still waiting while the stall is empty")
	stall.stored = 30.0
	check(await wait_until(func() -> bool: return sc.step == 3, 10.0) and sc.card.lesson_title() == "Trade", "the goods are in: the trade card")
	check(await wait_until(func() -> bool: return sc.highlight.tiles.has(stall.tile), 5.0), "the stall is marked")
	check(cmd("trade", {"building": stall.nid, "good": "food"})["ok"], "a lot of food bought")
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
	check(sc._goal_state.get("walls", false), "the walls hold (an optional objective)")
	var scenes := 0
	while not game.waves.all_done() and not game.game_over:
		if sc.cutscene != null:
			scenes += 1
			await _skip_scene()
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
	guard.queue_free()
	check(scenes >= 2 and not game.game_over, "seven waves, with talks between them (%d scenes after wave 2)" % scenes)
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

	for how in ["torn down", "destroyed"]:
		print("-- scenario 2: the stall %s" % how)
		await _new_game(2)
		await _skip_scene()
		Engine.time_scale = 4.0
		check(cmd("place_building", {"kind": "stall", "tile": sc.highlight.tiles[0]})["ok"], "the stall is placed")
		check(await wait_until(func() -> bool: return sc.stalls().any(func(b: Stall) -> bool: return b.complete), 240.0), "and stands")
		var st: Stall = sc.stalls()[0]
		if how == "torn down":
			check(cmd("tear_down", {"building": st.nid})["ok"], "a tear-down is ordered")
		else:
			st.take_damage(1e6)
		check(await wait_until(func() -> bool: return game.game_over, 120.0) and game.hud._overlay_sub.text.contains("stall was %s" % how), "the stall %s: the scenario is lost (%s)" % [how, game.hud._overlay_sub.text])
		Engine.time_scale = 1.0


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
	check(sc.spec._known_dark_road(sc).is_empty(), "no tower restored yet: no road to light (the light card would wait)")
	var camps := game.world.map_objects.filter(func(o: MapObject) -> bool: return o is MonsterCamp and not (o is MonsterLair) and not (o as MonsterCamp).cleared)
	check(not camps.is_empty(), "monster camps by the road")
	if not camps.is_empty():
		(camps[0] as MapObject).on_found(v.id, true)
		check(await wait_until(func() -> bool: return sc._hints_shown.has("camp"), 10.0) and sc.card.hint().contains("Attack with the hero"), "a camp found: a hint on attacking it (%s)" % sc.card.hint())
	var explorer_hint: Callable = sc.spec.hints(sc).filter(func(h: Dictionary) -> bool: return h["id"] == "explorer")[0]["when"]
	var wave_was := game.waves.wave
	check(not explorer_hint.call(), "no explorer hint before wave 3 is over")
	game.waves.wave = 3
	check(game.population.count("explorer") == 0 and (game.waves.in_progress() or explorer_hint.call()), "after wave 3, without an explorer: the hint to recruit one")
	game.waves.wave = wave_was

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

	print("-- scenario 3: the light card")
	check(sc.spec._known_dark_road(sc).all(func(tt: Vector2i) -> bool: return game.map.is_explored(tt)), "the light card counts only road the village has explored")
	if sc.step == sc.steps.size() - 1:
		check(sc.highlight.tiles.is_empty(), "the light card marks no spot on the road")

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
	await wait(20.0)
	check(w.hp == w.max_hp() and is_instance_valid(gob) and not gob.dead, "a goblin by the warehouse leaves it alone (it goes for the huts)")
	kill(gob)
	var edge: Vector2i = game.map.edge_spawns[0]
	for sp: Vector2i in game.map.edge_spawns:
		if Vector2(sp).distance_to(Vector2(w.tile)) < Vector2(edge).distance_to(Vector2(w.tile)):
			edge = sp
	var thief := game.waves.spawn_at("thief", edge, v, 1)
	thief.max_hp = 1e6
	thief.hp = thief.max_hp
	await frames(2)
	var tb := thief.behavior as ThiefBehavior
	check(tb.store == w, "a thief goes for the warehouse")
	var inside := v.rect.grow(-1)
	check(not Array(thief.path).any(func(p: Vector2) -> bool: return inside.has_point(Vector2i(p.round()))), "its way never leads through the walls")
	var huts := v.intact_huts().size()
	var gold0 := v.economy.amount("gold")
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return w.hp < w.max_hp() or not is_instance_valid(thief) or thief.dead, 300.0), "it gets there")
	check(is_equal_approx(w.hp, w.max_hp() - float(Config.WAREHOUSE["raid_damage"])), "and plunders it: %d HP (%d / %d)" % [int(Config.WAREHOUSE["raid_damage"]), w.hp, w.max_hp()])
	check(is_instance_valid(thief) and tb.escaping and thief.loot_gold > 0 and v.economy.amount("gold") < gold0, "and runs off with gold (%d)" % (thief.loot_gold if is_instance_valid(thief) else -1))
	check(v.intact_huts().size() == huts, "no hut burned for it")
	if is_instance_valid(thief):
		kill(thief)
	Engine.time_scale = 1.0
	check(await wait_until(func() -> bool: return sc.card.hint().begins_with("The warehouse is plundered"), 5.0), "a hint: it can't be repaired")
	check(not w.can_repair() and not cmd("repair", {"building": w.nid})["ok"] and not w.info()["actions"].any(func(a: Dictionary) -> bool: return str(a["label"]).begins_with("Repair")), "it can't be repaired (no command, no button)")

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
	var from_edge: Array[String] = []
	var offered := false
	var coins := false
	var t := 0.0
	while not game.waves.all_done() and not game.game_over and t < 1500.0:
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if e.kind == "crab" and game.map.is_water(e.home_tile):
				crab_water = true
			if e.kind in ["crab", "siren"] and not game.map.is_water(e.home_tile) and not from_edge.has(e.label()):
				from_edge.append(e.label())
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
	check(crab_water and from_edge.is_empty(), "crabs and the siren come out of the sea only, never from the edge (%s)" % str(from_edge))
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
	var c := v.center
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Old Fort", "scenario 5 runs on the old fort's map")
	check(game.map.is_mountain(c + Vector2i(-4, 0)) and game.map.is_mountain(c + Vector2i(4, 0)) and game.map.is_mountain(Vector2i(4, c.y)) and game.map.is_mountain(Vector2i(game.map.size - 5, c.y)),
		"the fort fills a pass through a range across the map")
	check(sc.pieces("gate").size() == 2 and sc.pieces("wall_tower").size() == 4 and sc.pieces("wall").size() == 8 and sc.pieces("gate").all(func(b: Building) -> bool: return absi(b.tile.x - c.x) <= 1),
		"two walls across the pass, a gate in each and a tower at each end")
	check(sc.pieces("gate").all(func(b: Building) -> bool: return b.level == 2 and b.hp == b.max_hp()), "both gates at level 2")
	check(v.buildings().all(func(b: Building) -> bool: return not b.devastated) and v.intact_huts().size() == 4 and v.huts().size() == 4, "everything stands whole, 4 huts")
	check(game.population.count() == 1 and game.population.civilians[0] is Merchant and game.population.civilians[0].given_name == "Pell", "only Pell lives there")
	var inside := v.buildings().filter(func(b: Building) -> bool: return (b.kind == "barracks" or b.kind == "training") and v.rect.has_point(b.tile))
	check(inside.size() == 3 and inside.all(func(b: Building) -> bool: return b.complete and (b as MilitaryPost).units().is_empty()), "two barracks and training grounds inside, empty")
	check(game.map.decor.get(c + Vector2i(-2, -1), "") == "well_dry" and game.world.is_tree(c + Vector2i(-3, 0)), "a dried-up well and one dead tree inside")
	check(v.huts().all(func(h: Building) -> bool: return game.world.pathing.is_walkable(h.tile + Vector2i(1, 0)) and v.huts().all(func(o: Building) -> bool: return o == h or Vector2(o.tile).distance_to(Vector2(h.tile)) >= 2.0)),
		"the huts a tile apart, and a tile clear of the mountains")
	check(sc.farms().filter(func(b: Building) -> bool: return not (b is Stall)).is_empty(), "no farm")
	check(sc.stalls().size() == 1 and sc.stalls()[0].tile.y > v.rect.end.y and (sc.stalls()[0] as Stall).farmer == sc.merchant(), "Pell's stall outside the south gate, Pell at it")
	var north := game.map.edge_spawns.filter(func(t: Vector2i) -> bool: return t.y < c.y)
	check(game.map.edge_spawns.size() == 6 and north.size() == 3, "six roads in, three from each side (%d, %d north)" % [game.map.edge_spawns.size(), north.size()])
	var camps := game.world.map_objects.filter(func(o: Node) -> bool: return o is MonsterCamp)
	check(not camps.is_empty() and camps.all(func(o: MonsterCamp) -> bool: return o.tile.y < c.y), "the monster camps are all in the north")
	check(["oak", "pine"].has(game.map.zone(Vector2i(c.x, 8))) and ["meadow", "steppe"].has(game.map.zone(Vector2i(c.x + 6, game.map.size - 8))), "forest to the north, meadow and steppe to the south")
	check(v.construction.placement_error("tower", c + Vector2i(3, 0), true) == "", "buildings may go inside the fort")
	check(game.population.retire_error(game.population.civilians[0]) != "", "Pell can't retire")
	check(game.hero.level == 6 and not sc.spec.hero_revives, "Brenna at level 7, no revive")
	var lairs := sc.lairs()
	check(lairs.size() == 1 and (lairs[0] as MonsterLair).tile.y < c.y and not (lairs[0] as MonsterLair).awake and (lairs[0] as MonsterLair).wake_wave == 6,
		"a lair in the northern forest, asleep until wave 6")
	var ev: Array = sc.spec._evidence(sc)
	check(ev.size() == 3 and ev.filter(func(o: Treasure) -> bool: return o.tile.y < c.y).size() == 2, "three treasures hold the evidence, two north and one south")
	check(not ev.any(func(o: Treasure) -> bool: return game.fog.is_explored_by(v.id, o.tile)), "their places are hidden in the fog")
	check(sc.spec.steps(sc).all(func(st: Dictionary) -> bool: return not st.has("point") or not (st["point"] as Callable).call().has("tiles")), "no card marks where they lie")
	var tent := sc.spec.SIGMUND_TENT as Vector2i
	check(tent.y > c.y and game.world.pathing.is_walkable(tent) and not game.fog.is_explored_by(v.id, tent) and not (sc.mark["sigmund actor"] as Node2D).visible, "Sigmund's tent in the south, hidden")
	check(game.waves.hold and not game.waves.can_call(), "wave 1 waits for Sigmund, and can't be called")
	check(game.waves.scripted.size() == 10, "ten waves")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("pell") and said.has("brenna"), "the intro: Brenna and Pell (%s)" % str(said))
	check(sc.card.lesson_title() == "An empty fort", "the empty fort card")
	check(not (sc.card._rows["roof"]["tick"] as Control).get_parent().visible, "Sigmund's roof isn't an objective yet")

	print("-- scenario 5: Sigmund, the huts full")
	for role in ["farmer", "forester", "gatherer"]:
		cmd("recruit_villager", {"role": role})
	check(game.population.count() == 4 and game.population.free_huts().is_empty(), "three recruits fill the fort")
	check(await wait_until(func() -> bool: return sc.card.lesson_title() == "Man the fort", 5.0), "then: man the fort")
	game.fog.reveal(Vector2(tent), 2.0, v.id)
	check(await wait_until(func() -> bool: return sc.mark.has("sigmund found"), 3.0), "his tent uncovered: Sigmund is found")
	check((sc.mark["sigmund actor"] as Node2D).visible and sc.cutscene != null, "he shows by his tent, and tells Brenna why")
	await _skip_scene()
	check(not game.waves.hold and game.waves.countdown > 0.0, "wave 1 is on its way (%.0f s)" % game.waves.countdown)
	await wait(1.0)
	check(not sc.mark.has("sigmund in") and game.population.count() == 4, "no hut free, no builder: he waits")
	check((sc.card._rows["roof"]["tick"] as Control).get_parent().visible and not sc._goal_state.get("roof", true), "the objective: give Sigmund a roof")
	check(sc._hints_shown.has("roof"), "a hint: retire someone")
	var gath: Civilian = game.population.civilians.filter(func(x: Civilian) -> bool: return x.role == "gatherer")[0]
	cmd("retire_villager", {"civilian": gath.nid})
	check(await wait_until(func() -> bool: return sc.mark.has("sigmund in"), 3.0), "a gatherer retired: Sigmund moves in")
	var sig := game.population.civilians.filter(func(x: Civilian) -> bool: return x.given_name == "Sigmund")
	check(sig.size() == 1 and (sig[0] as Civilian).role == "builder" and game.population.count() == 4, "Sigmund, a builder, in the fort")
	check(not is_instance_valid(sc.mark["tent"]), "his tent is packed up")
	check(await wait_until(func() -> bool: return sc._goal_state.get("roof", false), 3.0), "the roof objective is met")
	check(await wait_until(func() -> bool: return game.waves.in_progress(), 30.0), "wave 1 comes")
	_kill_wave()

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
	var legion_names: Array = Config.ENEMIES.keys().filter(func(k: String) -> bool: return k.begins_with("legion_")).map(func(k: String) -> String: return str(Config.ENEMIES[k]["name"]))
	var lib := Library.entries("enemies").filter(func(e: Dictionary) -> bool: return legion_names.has(str(e["name"])))
	check(lib.size() == legion_names.size() and lib.size() == 8 and lib.all(func(e: Dictionary) -> bool: return (e["facts"] as PackedStringArray).has("The Dread Legion: people, bound to Rhodri. Only in the campaign")), "the library has every Legion kind, as people (%d)" % lib.size())

	print("-- scenario 5: the evidence")
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
	var pages := 0
	for o: Treasure in ev:
		o.mark_looted()
		check(await wait_until(func() -> bool: return sc.journal != null and sc.journal.visible, 10.0), "a found piece: its page")
		if pages == 0:
			check(get_tree().paused and sc.journal._gray.visible, "the game waits behind it, grey")
		pages += 1
		_close_journal()
		check(not sc.journal._gray.visible, "closed, the game has its colours back")
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
	var gate := sc.spec._gargoyle_rock(sc) as Vector2i
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
	check((lairs[0] as MonsterLair).woke_at == 6, "the lair woke at wave 6 (%d)" % (lairs[0] as MonsterLair).woke_at)
	check(await wait_until(func() -> bool: return sc.cutscene != null, 120.0), "the outro plays")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("brenna") and said.has("pell"), "Brenna reads the order (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Betrayal: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 5: Sigmund, a builder makes room")
	await _new_game(5)
	await wait(1.0)
	await _skip_scene()
	for role in ["builder", "farmer", "forester"]:
		cmd("recruit_villager", {"role": role})
	game.fog.reveal(Vector2(sc.spec.SIGMUND_TENT), 2.0, game.player_village.id)
	await wait_until(func() -> bool: return sc.cutscene != null, 3.0)
	check(not sc.mark.has("sigmund in"), "found: he waits by his tent while he talks")
	await _skip_scene()
	check(await wait_until(func() -> bool: return sc.mark.has("sigmund in"), 5.0), "then, the huts full: he moves in at once")
	var builders := game.population.civilians.filter(func(x: Civilian) -> bool: return x.role == "builder")
	check(builders.size() == 1 and builders[0].given_name == "Sigmund" and game.population.count() == 4, "the builder left, Sigmund took his hut")
	check(not sc._hints_shown.has("roof") and await wait_until(func() -> bool: return sc._goal_state.get("roof", false), 3.0), "no hint, the roof objective met at once")
	var lair := sc.lairs()[0] as MonsterLair
	game.fog.reveal(Vector2(lair.tile), 2.0, game.player_village.id)
	check(await wait_until(func() -> bool: return lair.awake, 3.0), "the lair found before wave 6: it wakes at once")
	check(not lair.monsters.is_empty() and game.world.awake_lairs().has(lair), "its guards are out, and the waves come out of it too")


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
	check(game.population.count("gatherer") == 0, "no gravediggers at the start")
	var units := game.army.units
	check(units.size() == 2 and game.army.reserve().is_empty() and units.all(func(u: MilitaryUnit) -> bool: return u.level == 0 and u.state == MilitaryUnit.State.STATIONED), "two units at level 1, both stationed, none in the reserve")
	check(units.any(func(u: MilitaryUnit) -> bool: return u.kind == "archer" and u.post.kind == "wall_tower") and units.any(func(u: MilitaryUnit) -> bool: return u.kind == "shield_bearer" and u.post is Barracks), "the archer on a wall tower, the shield bearer in the barracks")
	check(sc.towers().is_empty(), "no watchtowers")
	check(fallen.all(func(c: Corpse) -> bool: return sc.spec._by_road(sc, c.tile())), "the fallen lie by the roads, where necromancers come")
	var anselm: Resident = ans[0]
	check(anselm.rounds.size() == 2, "Anselm has his rounds: the chapel and the graveyard (%d)" % anselm.rounds.size())
	await wait(1.0)
	check(game.population.civilians.all(func(c: Civilian) -> bool: return not c.is_processing() and c.at_home), "during the intro the villagers wait at home")
	var said := await _watch(sc.cutscene)
	check(said.has("anselm") and said.has("brenna"), "the intro: Anselm and Brenna (%s)" % str(said))
	check(game.population.civilians.all(func(c: Civilian) -> bool: return c.is_processing()), "after it they go to work")
	check(sc.card.lesson_title() == "The sleeping chapel", "the chapel card first")
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return not anselm.at_home, 60.0), "Anselm walks his rounds (%s)" % anselm.status())
	check(await wait_until(func() -> bool: return anselm.status().begins_with("praying"), 60.0), "and prays out there (%s)" % anselm.status())
	Engine.time_scale = 1.0

	print("-- scenario 6: the chapel")
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return game.is_unlocked("acolyte"), 180.0), "Brenna wakes the chapel: acolytes")
	check(await wait_until(func() -> bool: return sc.cutscene != null, 5.0), "a scene at the chapel")
	await _skip_scene()
	Engine.time_scale = 1.0
	cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
	check(await _at_card(1, 10.0), "the fallen card")
	check(sc.card.lesson_title() == "The fallen" and not sc.card.lesson_text().contains("recruit"), "it doesn't say to recruit gatherers")
	check(sc.steps.size() == 2, "no acolyte card")

	print("-- scenario 6: the fallen")
	game.corpses.clear_wave(99)
	fallen[0].time_left = -1.0
	await frames(2)
	check(sc.spec._still_to_bury(sc) + gy.buried == sc.spec.FALLEN, "the fallen never rot and are never cleared away (%d)" % (sc.spec._still_to_bury(sc) + gy.buried))
	for i in 2:
		check(cmd("recruit_villager", {"role": "gatherer"})["ok"], "gatherer %d recruited" % (i + 1))
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return gy.buried >= 1, 120.0), "gatherers carry the fallen to the graveyard: buried (%d)" % gy.buried)
	check(game.population.civilians.any(func(c: Civilian) -> bool: return c is Gatherer and (c as Gatherer).status().contains("graveyard")) or gy.buried > 0, "on their way: to the graveyard")
	check(await wait_until(func() -> bool: return sc.step >= sc.steps.size(), 120.0), "the fallen card is done once three are buried (%d): the cards are done" % gy.buried)
	var necro := game.waves.spawn_at("necromancer", game.world.pathing.nearest_road(v.center + Vector2i(0, -10)), v, 1)
	var risen := game.waves.raise_corpse(game.corpses.fallen()[-1], necro)
	check(risen != null and risen.kind == "skeleton" and risen.raised, "a necromancer raises one of the fallen: a skeleton")
	check(await wait_until(func() -> bool: return sc.card.hint().begins_with("One of the fallen has risen"), 3.0), "a hint says so (%s)" % sc.card.hint())
	kill(necro)
	kill(risen)
	Engine.time_scale = 1.0

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
	var walkers := [false]
	sc.cutscene.tapped.connect(func() -> void:
		var actors: Array = sc.mark.get("outro actors", [])
		if actors.size() >= 3 and not game.hero.visible:
			walkers[0] = true)
	said = await _watch(sc.cutscene)
	check(said.has("anselm") and said.has("brenna"), "Anselm tells where the court went (%s)" % str(said))
	check(walkers[0], "Anselm, Brenna and Pell walk to the graveyard in the outro")
	var actors: Array = sc.mark.get("outro actors", [])
	check(actors.size() == 4 and is_instance_valid(actors[3]) and Vector2((actors[3] as Node2D).position).distance_to(sc.at(gy.visit_tile())) < 64.0, "Anselm plants the cross there")
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Dead: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 6: the gravediggers' hint")
	await _new_game(6)
	sc.cutscene.skip()
	await frames(2)
	game.waves.wave = 2
	check(await wait_until(func() -> bool: return sc.card.hint().contains("Gatherers carry them"), 3.0), "wave 2 over and no gatherer: a hint says gatherers carry the fallen (%s)" % sc.card.hint())
	await frames(2)
	check(sc.highlight.target == game.hud.control_named("village:gatherer") or sc.highlight.target == game.hud.control_named("tab:village") or sc.highlight.target == game.hud.control_named("dock"), "and points at recruiting one")
	check(str(sc._hint_on.get("id", "")) == "gravediggers", "it stays until one is recruited")
	check(cmd("recruit_villager", {"role": "gatherer"})["ok"], "one is recruited")
	check(await wait_until(func() -> bool: return sc._hint_on.is_empty() and sc.card.hint() == "", 3.0), "the hint is gone")

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


# --- scenario 8: The Pale Court ----------------------------------------------------------------

## Plays the scene running now through, picking choice `pick` (Refuse).
func _through_scene(pick := 1) -> void:
	if sc.cutscene != null:
		await _watch(sc.cutscene, pick)
		await frames(2)


func _scenario_8() -> void:
	print("-- scenario 8: setup")
	await _new_game(8)
	var v := game.player_village
	var h := game.hero
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Pale Court", "scenario 8 runs on the Pale Court's map")
	check(game.army.reserve().size() == 8 and game.army.units.size() == 8, "the band waits in the reserve (%d)" % game.army.reserve().size())
	check(not game.available("archer") and not cmd("recruit_unit", {"kind": "archer"})["ok"], "nobody can be recruited")
	check(game.is_unlocked("apprentice") and game.is_unlocked("summoner") and game.is_unlocked("acolyte"), "the band's kinds are unlocked")
	var crypts := sc.lairs()
	check(crypts.size() == 3 and crypts.all(func(o: Node) -> bool: return str((o as MonsterLair).data["art"]).begins_with("lair_crypt") and not (o as MonsterLair).awake), "three crypts, asleep")
	check(crypts.all(func(o: Node) -> bool: return game.map.is_road((o as MonsterLair).door())), "their doors on the roads")
	check([1, 4, 7] == crypts.map(func(o: Node) -> int: return (o as MonsterLair).wake_wave), "they wake at waves 1, 4 and 7")
	var camps: Array = sc.spec._legion_camps(sc)
	check(camps.size() == 2 and camps.all(func(o: MonsterCamp) -> bool: return o.art() == "legion_camp" and o.alive().all(func(e: Enemy) -> bool: return e.kind.begins_with("legion_"))), "two Legion camps at the court's gates")
	check(h.level == 12 and not sc.spec.hero_revives, "Brenna at level 13, no revive")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("lothar") and said.has("idris") and said.has("brenna"), "the intro: Lothar under his white flag (%s)" % str(said))
	check(not sc.mark.has("actors"), "the herald is gone after it")

	print("-- scenario 8: the band")
	var posts: Array = sc.towers(true).filter(func(b: Building) -> bool: return b.working() and (b as Tower).garrison == null)
	posts.append_array(sc.pieces("barracks"))
	var i := 0
	for post in posts:
		if game.army.reserve().is_empty():
			break
		var u: MilitaryUnit = game.army.reserve().filter(func(m: MilitaryUnit) -> bool: return m.fits(post.post_kind()))[0] if game.army.reserve().any(func(m: MilitaryUnit) -> bool: return m.fits(post.post_kind())) else null
		if u:
			cmd("station_unit", {"unit": u.nid, "post": post.nid})
			i += 1
	check(await _at_card(1, 60.0), "stationed: on to the next card (%d sent)" % i)
	game.economy.add("gold", 500)
	var unit: MilitaryUnit = game.army.units[0]
	cmd("upgrade_unit", {"unit": unit.nid, "to": unit.kind})
	check(await wait_until(func() -> bool: return sc.step == 1 and sc._next_in >= 0.0, 30.0), "an upgrade: that card is done")
	await wait(2.0)
	check(sc.card.lesson_text().begins_with("The first crypt wakes"), "the crypt card waits for wave 1 (%s)" % sc.card.lesson_text())

	print("-- scenario 8: the crypts")
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	Engine.time_scale = 4.0
	cmd("call_wave")
	await frames(2)
	var c1 := crypts[0] as MonsterLair
	check(c1.awake and c1.alive().size() == 4 and c1.alive().any(func(e: Enemy) -> bool: return e.kind == "vampire"), "wave 1 wakes the first crypt, with its guards")
	check(await wait_until(func() -> bool: return get_tree().get_nodes_in_group("enemies").any(func(e: Node) -> bool: return (e as Enemy).home_tile == c1.door() and not ((e as Enemy).behavior is CampBehavior)), 30.0), "its monsters come out of it with the wave")
	guard.start()
	var offer := false
	var rurik := false
	var scenes: Array[String] = []
	var t := 0.0
	while not sc.phase in [ScenarioRunner.Phase.OUTRO, ScenarioRunner.Phase.OVER] and not game.game_over and t < 1800.0:
		if sc.cutscene != null:
			var first: Array = sc.cutscene.steps.filter(func(st: Dictionary) -> bool: return st.has("text"))
			scenes.append("w%d %s" % [game.waves.wave, str(first[0]["text"]).left(30) if not first.is_empty() else "?"])
			if sc.cutscene.steps.any(func(s: Dictionary) -> bool: return s.has("choices")):
				offer = true
			await _through_scene(1)
		var ru = sc.mark.get("rurik")
		if is_instance_valid(ru):
			rurik = rurik or ((ru as Enemy).kind == "legion_champion" and (crypts[2] as MonsterLair).monsters.has(ru))
		for l in crypts:
			var lair := l as MonsterLair
			if lair.awake and game.waves.wave >= 3:
				for e in lair.alive():
					kill(e, h)
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5
	check(not game.game_over and sc.phase == ScenarioRunner.Phase.OUTRO, "the three crypts cleared%s" % (" (game over: %s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(crypts.all(func(o: Node) -> bool: return (o as MonsterLair).cleared and not (o as MonsterLair).awake), "they stay cleared")
	check(offer, "Lothar's offer came, and was refused")
	check((rurik or named.get("Rurik", "") == "legion_champion") and sc.mark.has("rurik down"), "Rurik stood at the third crypt, and fell (seen %s, %s, fell %s)" % [rurik, named.get("Rurik", ""), sc.mark.has("rurik down")])
	print("   scenes: %s" % str(scenes))
	check(scenes.any(func(x: String) -> bool: return x.contains("The court mages called it")), "the talk after wave 1")
	check(scenes.any(func(x: String) -> bool: return x.contains("The crown.")), "the talk after wave 5")
	if sc.cutscene != null and not sc._outro_started:
		await _through_scene()  # (Rurik's fall)
	check(await wait_until(func() -> bool: return sc.cutscene != null and sc._outro_started, 120.0), "the outro plays after it")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("priest") and said.has("rhodri"), "the Hand, and Rhodri laughing (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Pale Court: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 8: taking the offer")
	await _new_game(8)
	sc.cutscene.skip()
	await frames(2)
	sc.spec._offer(sc)
	await frames(2)
	await _watch(sc.cutscene, 0)
	check(await wait_until(func() -> bool: return game.game_over, 3.0) and game.hud._overlay_sub.text.contains("Rhodri's side"), "going back to Rhodri loses (%s)" % game.hud._overlay_sub.text)

	print("-- scenario 8: the Legion's kinds")
	await _new_game(8)
	sc.cutscene.skip()
	await frames(2)
	v = game.player_village
	h = game.hero
	var road := sc.road_in(v.center + Vector2i(0, 30), 9)
	var at: Vector2i = road[0]
	var foot := game.waves.spawn_at("legion_footman", at, v, 1)
	var flag := game.waves.spawn_at("legion_banner", at, v, 1)
	await frames(2)
	foot._haste_at = -INF
	check(is_equal_approx(foot.haste(), 1.25), "a footman by a banner strikes 1.25x as fast (%s)" % foot.haste())
	flag.set_grid_pos(Vector2(at) + Vector2(4, 0))
	foot._haste_at = -INF
	check(is_equal_approx(foot.haste(), 1.0) and is_equal_approx(game.waves.spawn_at("goblin", at, v, 1).haste(), 1.0), "not away from it, and never a goblin (%s at %.1f)" % [foot.haste(), foot.grid_pos.distance_to(flag.grid_pos)])
	var shield := game.waves.spawn_at("legion_guard", at, v, 1)
	var hp0 := shield.hp
	shield.take_damage(10.0, null, "projectile")
	check(is_equal_approx(hp0 - shield.hp, 5.0), "a guardsman takes half from arrows")
	await clear_enemies()
	h.set_mode(Hero.Mode.EXPLORE)
	var archer := game.waves.spawn_at("legion_archer", at, v, 1)
	h.set_grid_pos(archer.grid_pos + Vector2(1.5, 0.5))
	h.set_process(false)
	var hp1 := h.hp
	check(await wait_until(func() -> bool: return h.hp < hp1, 8.0), "a Legion archer shoots Brenna out in the open")
	h.set_process(true)
	var champ := game.waves.spawn_at("legion_champion", at, v, 1)
	check(champ.max_hp >= 500.0 and champ.spec()["cleave"] > 0.0 and champ.spec()["release"], "the court champion: a boss whose blows cleave")
	await clear_enemies()


# --- scenario 9: The Drowned Abbey -------------------------------------------------------------

func _scenario_9() -> void:
	var part := ""  # (-- --only=9 --s9=rescued|drowned|escape|more: just that part)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--s9="):
			part = a.trim_prefix("--s9=")
	if part in ["", "rescued"]:
		await _s9_rescued()
	if part in ["", "drowned"]:
		await _s9_drowned()
	if part in ["", "escape"]:
		await _s9_escape()
	if part in ["", "more"]:
		await _s9_church()
		await _s9_ground()
		await _s9_yes()


func _s9() -> Scenario:
	return sc.spec


## Waves on (each one's enemies dying as they come, but for the spared),
## through every scene, until wave `n` is over.
func _s9_waves_to(n: int, timeout := 900.0) -> void:
	var t := 0.0
	while not (game.waves.wave >= n and not game.waves.in_progress()) and not game.game_over and t < timeout:
		if sc.cutscene != null:
			await _through_scene()
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5


## The village's priests (Residents), eldest first.
func _s9_priests() -> Array:
	return game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "priest")


## Why the game ended, if it did (for a failed check).
func _s9_why() -> String:
	if game.game_over:
		return " (game over: %s)" % game.hud._overlay_sub.text.split("\n")[0]
	var h := game.hero
	var sack = sc.mark.get("sack")
	var lev := sc.named_enemy("Leviathan")
	var near := ""
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.grid_pos.distance_to(h.grid_pos) < 8.0:
			near += " %s%s at %s" % [e.kind, " (camp)" if e.behavior is CampBehavior else "", str(e.current_tile())]
	return " (processing %s, at_home %s, next %s; hero speed %.2f, paused %s, speed %.1f, scene %s; held by %s; near:%s; forced %s, path %d/%d to %s, home %s; hero at %s, mode %d, %s, evading %s, hp %d; sack %s; leviathan %s)" % [str(h.is_processing()), str(h.at_home), str(h.path.slice(maxi(h.path_index - 1, 0), h.path_index + 2)), h.speed, str(get_tree().paused), Engine.time_scale, ("\"%s\"" % sc.cutscene.line) if sc.cutscene else "-", "%s at %s, dead %s" % [h.held_by.kind, str(h.held_by.current_tile()), str(h.held_by.dead)] if is_instance_valid(h.held_by) else "-", near, str(h.is_forced()), h.path_index, h.path.size(), str(h.path[-1]) if h.path.size() > 0 else "-", str(h.home()), str(h.current_tile()), h.mode, h.status(), str(h.evading), int(h.hp),
		str((sack as Treasure).tile) if is_instance_valid(sack) else "-", str(lev.current_tile()) if lev else "-"]


func _s9_guard() -> Timer:
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	guard.start()
	return guard


## The rescued branch, won: the watch, the rescue, the Legion at the seal,
## the crypt opened, the leviathan waking, slain, the relic home.
func _s9_rescued() -> void:
	print("-- scenario 9: setup")
	await _new_game(9)
	var v := game.player_village
	var h := game.hero
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Drowned Abbey", "scenario 9 runs on the drowned abbey's map")
	var ab: Treasure = _s9()._abbey(sc)
	check(ab != null and ab.sealed and not ab.lootable() and ab.reward().get("item", "") == _s9().RELIC, "the abbey holds the relic, sealed")
	check(ab != null and ab.seal_max == _s9().SEAL_HP and ab.seal_hp == ab.seal_max, "its seal has %d HP" % int(_s9().SEAL_HP))
	check(ab != null and ab.guard() != null and ab.guard().alive().filter(func(e: Enemy) -> bool: return e.kind == "vampire").size() == 2, "vampires hold its crypt")
	var ruins := game.world.map_objects.filter(func(o: Node) -> bool: return o is RuinedTower and Vector2((o as RuinedTower).tile).distance_to(Vector2(ab.tile)) < 7.0)
	check(ruins.size() == 3 and ruins.filter(func(o: Node) -> bool: return (o as RuinedTower).building() == "barracks").size() == 1, "two ruined watchtowers and a ruined barracks on the island (%d)" % ruins.size())
	var church: Church = _s9()._church(sc)
	check(church != null and church.complete and game.map.in_village(church.tile) and not church.holds_relic, "the church stands inside the walls, empty")
	var bridge: Array[Vector2i] = []
	for t: Vector2i in game.map.crossings:
		if game.map.is_bridge(t) and Vector2(t).distance_to(Vector2(ab.tile)) < 13.0:
			bridge.append(t)
	check(bridge.size() >= 3 and bridge.all(func(t: Vector2i) -> bool: return t.y == bridge[0].y),
		"one straight bridge onto the island, from bank to bank (%s)" % str(bridge))
	# Only over it: the island out of reach with the bridge blocked.
	var seen := {game.player_village.center: true}
	var todo: Array[Vector2i] = [game.player_village.center]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_back()
		for n in MapData.neighbors4(t):
			if not seen.has(n) and not bridge.has(n) and game.map.is_passable(n):
				seen[n] = true
				todo.append(n)
	check(not seen.has(ab.visit_tile()) and game.world.pathing.can_reach(game.player_village.center, ab.visit_tile()),
		"the island is reached only over that bridge, and from the village's side")
	var octo = sc.mark.get("octopus")
	check(octo is Enemy and (octo as Enemy).kind == "octopus" and (octo as Enemy).post == ab.tile and game.waves.enemies_left() == 0, "a gigantic octopus guards the abbey, outside the waves")
	var drowned := game.corpses.fallen().filter(func(c: Corpse) -> bool: return c.grid_pos.distance_to(Vector2(ab.tile)) < 6.0)
	check(drowned.size() == _s9().DROWNED, "the drowned dead lie on the island (%d)" % drowned.size())
	var priests := _s9_priests()
	check(priests.size() == 2 and priests.all(func(c: Civilian) -> bool: return c is Resident and c.given_name == "" and not (c as Resident).rounds.is_empty()), "two priests, unnamed, walk their rounds")
	check(priests.all(func(c: Civilian) -> bool: return c.home_spot() == _s9()._church_door(sc) and church.tiles().has(c.home_spot() + Vector2i(0, -1))), "they live in the church: in and out of its door")
	check(not sc.stalls().is_empty() and game.available("archer") and game.army.reserve().size() == 2, "Pell's stall stands; recruiting is open; two of the band in the reserve")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("pell") and said.has("brenna"), "the intro: the boat in the mist (%s)" % str(said))

	print("-- scenario 9: the card while paused")
	cmd("set_speed", {"index": Game.SPEEDS.find(0.0)})
	await frames(2)
	game.hud._hero_button.pressed.emit()
	await frames(3)
	check(get_tree().paused and sc.card.position.x >= game.hud.corner_panel_rect().end.x, "paused, the hero panel opened: the card moves beside it at once")
	var tall := sc.card.size.y
	sc.card.set_folded(true)
	await frames(2)
	check(sc.card.size.y < tall * 0.5, "folded while paused: the box shrinks at once (%.0f -> %.0f)" % [tall, sc.card.size.y])
	sc.card.set_folded(false)
	await frames(2)
	check(absf(sc.card.size.y - tall) < 2.0, "unfolded: as tall as before")
	game.hud._hero_button.pressed.emit()
	cmd("set_speed", {"index": 0})
	await frames(2)

	print("-- scenario 9: the watch on the water")
	check(game.waves.hold and game.waves.wave == 0 and game.waves.can_call(), "wave 1 waits (no countdown), and can be called")
	var shore := Vector2i(-1, -1)
	var best := INF
	for y in game.map.size:
		for x in game.map.size:
			var st := Vector2i(x, y)
			var d := Vector2(st).distance_to(Vector2(v.center))
			if d < best and _s9()._by_water(sc, st) and game.construction.placement_error("tower", st) == "":
				best = d
				shore = st
	var row := func() -> bool: return ((sc.card._rows["watch"]["tick"] as Control).get_parent() as Control).visible
	check(sc.card._rows.has("watch") and row.call() and not sc.objectives[0]["done"].call(), "an objective says so: build a watchtower by the shore")
	check(cmd("place_building", {"kind": "tower", "tile": shore})["ok"], "a watchtower placed by the shore %s" % shore)
	await wait(0.6)
	check(game.waves.hold and game.waves.wave == 0, "placed: wave 1 still waits")
	var pt: Dictionary = sc.steps[0]["point"].call()
	check(not (pt.get("hud", []) as Array).has("build:tower") and (pt.get("tiles", []) as Array).has(shore), "the card now points at the tower being built, not at the Build tab")
	var placed: Building = game.map.building_at(shore)
	check(await wait_until(func() -> bool: return placed.complete, 240.0), "it is built")
	await wait(0.6)
	check(not game.waves.hold and game.waves.countdown > _s9().FIRST_WAVE_AFTER - 5.0, "built (nobody on it yet): wave 1's countdown runs at once (%.0f s)" % game.waves.countdown)
	check(sc.objectives[0]["done"].call() and row.call(), "the objective is ticked")
	check(await wait_until(func() -> bool: return not row.call(), _s9().WATCH_GOAL_STAYS + 3.0), "then it is gone: it was only for the start")
	var unit: MilitaryUnit = game.army.reserve()[0]
	cmd("station_unit", {"unit": unit.nid, "post": placed.nid})
	check(await wait_until(func() -> bool: return (placed as Tower).garrison != null, 120.0), "a unit stationed on it")

	print("-- scenario 9: the waves, the boats, the rescue")
	spare_kinds = ["octopus", "octopus_arm"]
	var guard := _s9_guard()
	Engine.time_scale = 4.0
	var gold0 := game.economy.amount("gold")
	await _s9_waves_to(2)
	await wait_until(func() -> bool: return game.events.entries.any(func(en) -> bool: return str(en["text"]).begins_with("The guild caravan is in")), 60.0)
	check(game.economy.amount("gold") > gold0, "after wave 2 a guild boat comes in, and a cart takes its goods to Pell's stall")
	await _s9_waves_to(_s9().RESCUE_WAVE)
	await _through_scene()
	check(sc.mark.has("rescue"), "after wave 4 a priest walks down to the harbour")
	Engine.time_scale = 1.0
	var quay: Vector2i = _s9()._quay(sc)
	check((octo as Enemy).grid_pos.distance_to(Vector2(quay)) > 10.0, "the octopus is still out by the abbey meanwhile")
	check(await wait_until(func() -> bool: return sc.mark.has("grabbed"), 90.0), "he gets to the quay: the octopus comes up by the pier and grabs him")
	var p: Resident = _s9()._priest(sc, false)
	var ob := ((octo as Enemy).behavior as OctopusBehavior)
	check((octo as Enemy).grid_pos.distance_to(Vector2(quay)) < 5.0, "by the pier")
	await wait(1.0)
	var busy := ob.arms.filter(func(a: Dictionary) -> bool: return a["state"] != OctopusBehavior.Arm.IDLE and a["state"] != OctopusBehavior.Arm.GONE)
	check(busy.size() == 1 and busy[0]["target"] == p, "one arm holds him; the others keep still (no towers smashed)")
	check(sc.cutscene != null and not sc.mark.has("countdown"), "a scene: the alarm, and no time running yet")
	var hp0 := p.hp
	await _through_scene()
	check(p.hp >= hp0 and not p.dead, "unharmed while it played")
	check(await wait_until(func() -> bool: return sc.mark.has("countdown"), 3.0) and ob.hold_left(p) > _s9().RESCUE_HOLD - 2.0, "the scene over: now his %.0f s run" % ob.hold_left(p))
	await wait(3.0)
	check(p != null and not p.dead and game.map.get_terrain(p.current_tile()) == MapData.Terrain.SHALLOW, "he is held in the shallows")
	var post: Building = sc.towers()[0]
	var near := MilitaryBehavior.enemies_near(post, 200.0)
	check(not near.is_empty() and near[0].kind == "octopus_arm" and near[0].holding and p.held_by == near[0],
		"towers go for the arm holding him first, not the octopus (%s)" % str(near.map(func(e: Enemy) -> String: return e.kind)))
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).kind == "octopus_arm":
			kill(e, h)
	check(await wait_until(func() -> bool: return sc.mark.has("rescued"), 5.0) and not p.dead, "its arm cut: the priest is saved")
	said = await _watch(sc.cutscene)
	check(said.has("priest") and said.has("eldest"), "the priests tell what the abbey hides (%s)" % str(said))

	print("-- scenario 9: the Legion at the seal")
	Engine.time_scale = 4.0
	await _s9_waves_to(_s9().LEGION_WAVES[0] - 1)
	spare_kinds = ["octopus", "octopus_arm", "legion_*"]
	check(await wait_until(func() -> bool: return game.waves.in_progress() and sc.named_enemy("Lysa") != null, 120.0), "wave 6: Lysa comes")
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await wait_until(func() -> bool: return sc.cutscene != null and sc.cutscene.line != "", 20.0)
	var ly := sc.named_enemy("Lysa")
	var off := game.camera.position.distance_to(ly.position + Vector2(0, -40)) if ly else INF
	var at0 := ly.grid_pos if ly else Vector2.ZERO
	await wait(4.0)
	var off2 := game.camera.position.distance_to(ly.position + Vector2(0, -40)) if is_instance_valid(ly) else INF
	check(off < 60.0 and off2 < 60.0 and is_instance_valid(ly) and ly.grid_pos.distance_to(at0) > 0.5, "the scene's camera stays on Lysa while she walks (%.0f, %.0f px off)" % [off, off2])
	Engine.time_scale = ts
	await _through_scene()
	var co: LegionCompany = sc.mark.get("company")
	await wait_until(func() -> bool: return co.members.size() >= 9, 20.0)
	check(co != null and co.leader == sc.named_enemy("Lysa") and co.members.size() >= 9, "her soldiers march with her as a company (%d)" % (co.members.size() if co else 0))
	await wait(4.0)
	var lysa := sc.named_enemy("Lysa")
	var near_her := co.members.filter(func(m: Enemy) -> bool: return m.grid_pos.distance_to(lysa.grid_pos) < 5.0).size() if lysa else 0
	check(near_her >= co.members.size() - 2, "they keep close behind her (%d of %d within 5 tiles)" % [near_her, co.members.size()])
	check(await wait_until(func() -> bool: return ab.seal_hp < ab.seal_max, 120.0), "at the abbey they strike its seal (%d HP)" % int(ab.seal_hp))
	check(lysa != null and lysa.visible, "Lysa is seen there, fog or not")
	spare_kinds = ["octopus", "octopus_arm"]
	await _s9_waves_to(_s9().LEGION_WAVES[0])
	await _through_scene()
	check(sc.mark.has("unsealed") and not ab.sealed and ab.seal_hp > 0.0 and _s9()._relic_at(sc) == "crypt", "the Legion beaten: the priests unseal the crypt")
	check(not get_tree().get_nodes_in_group("enemies").any(func(e: Node) -> bool: return (e as Enemy).kind.begins_with("legion_")), "no Legion in the waves after")

	print("-- scenario 9: the crypt and the leviathan")
	await wait_until(func() -> bool: return not game.waves.in_progress(), 120.0)
	kill(octo as Enemy, h)  # (the guard by the island: Brenna exploring would run from it)
	kill_camps = true
	await wait(1.0)
	kill_camps = false
	spare = "Leviathan"
	check(ab.guard() == null and ab.lootable(), "its vampires cleared: the crypt can be entered")
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	check(await wait_until(func() -> bool: return sc.mark.has("woken"), 300.0), "Brenna goes into the crypt, and the leviathan wakes")
	check(ab.blocked != "" and not ab.lootable() and not ab.looted and _s9()._relic_at(sc) == "crypt", "it blocks the crypt: the relic is still in it")
	await wait(0.5)
	check(sc._goal_shown.has("leviathan"), "the objective: slay the leviathan")
	var lev := sc.named_enemy("Leviathan")
	check(lev != null and lev.max_hp >= Config.enemy_stat("leviathan", "hp") * 4.9 and lev.power == _s9().LEVIATHAN_POWER, "a boss: five times the HP, harder blasts")
	await _through_scene()
	spare = ""
	kill(lev, h)
	check(await wait_until(func() -> bool: return sc.mark.has("slain"), 5.0) and ab.blocked == "", "the leviathan slain: the crypt is open")
	await _through_scene()
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	check(await wait_until(func() -> bool: return _s9()._relic_at(sc) != "crypt", 600.0), "Brenna takes the relic%s" % _s9_why())
	if _s9()._relic_at(sc) == "hero":
		cmd("hero_mode", {"mode": Hero.Mode.DEFEND})
		check(await wait_until(func() -> bool: return _s9()._relic_at(sc) == "ground", 3.0), "switched out of Explore on the way, she drops it: it lies on the ground")
		var dropped: Treasure = sc.mark.get("sack")
		check(dropped != null and dropped.art() == "relic_sword" and dropped.lootable(), "the sword on the ground, for anyone to pick up")
		cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
		check(await wait_until(func() -> bool: return _s9()._relic_at(sc) != "ground", 300.0), "back in Explore, she picks it up again (%s)%s" % [_s9()._relic_at(sc), _s9_why()])
	check(await wait_until(func() -> bool: return _s9()._relic_mine(sc), 300.0) and church.holds_relic, "she carries it home: the church keeps it")
	check(await wait_until(func() -> bool: return sc.phase in [ScenarioRunner.Phase.OUTRO, ScenarioRunner.Phase.OVER], 60.0), "relic home and leviathan slain: done")
	while sc.cutscene != null and not sc._outro_started:
		await _through_scene()
	check(await wait_until(func() -> bool: return sc.cutscene != null and sc._outro_started, 300.0), "the outro plays (once the wave is over)")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("eldest") and said.has("lysa"), "the priests agree, and Lysa warns her (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Drowned Abbey: complete", "won: %s%s" % [game.hud._overlay_title.text, _s9_why()])
	spare_kinds = []


## The drowned branch, won: the priest drowned, Brenna in her tent, the
## Legion breaking the seal, Lysa taking the relic and dropping it, the relic
## handed in, the priests' trust, the request refused, Fiona's decree.
func _s9_drowned() -> void:
	print("-- scenario 9: the priest drowns")
	await _new_game(9)
	var h := game.hero
	await wait(1.0)
	sc.cutscene.skip()
	await frames(3)
	var ab: Treasure = _s9()._abbey(sc)
	var church: Church = _s9()._church(sc)
	var octo := sc.mark.get("octopus") as Enemy
	spare_kinds = ["octopus", "octopus_arm"]
	var guard := _s9_guard()
	Engine.time_scale = 4.0
	await _s9_waves_to(_s9().RESCUE_WAVE)
	await _through_scene()
	Engine.time_scale = 1.0
	check(await wait_until(func() -> bool: return sc.mark.has("grabbed"), 90.0), "the octopus grabs the priest")
	await _through_scene()
	await wait_until(func() -> bool: return sc.mark.has("countdown"), 3.0)
	for a in (octo.behavior as OctopusBehavior).arms:
		if a.has("wait"):
			a["wait"] = 0.0
	check(await wait_until(func() -> bool: return sc.mark.has("drowned"), 30.0), "nobody cuts him free: he drowns")
	check(_s9_priests().size() == 1 and h.home_override == sc.mark.get("tent") and not game.map.in_village(h.home_override), "the priests shut Brenna out: her tent outside the walls is her home")
	check(h.barred == game.player_village.rect, "she may not set foot in the village, not even in a gate")
	check(await wait_until(func() -> bool: return not h.barred.has_point(h.current_tile()), 60.0), "she leaves it")
	var inside := [false]
	var watch := Timer.new()
	watch.wait_time = 0.2
	watch.timeout.connect(func() -> void:
		if h.barred.has_area() and h.barred.has_point(h.current_tile()):
			if not inside[0]:
				print("    (inside at %s: mode %d evading %s at_home %s home %s path end %s target %s camp %s held %s)" % [h.grid_pos, h.mode, h.evading, h.at_home, h.home(), h.path[h.path.size() - 1] if h.path.size() > 0 else "-", h.target, h.camp_target, h.held_by])
			inside[0] = true)
	add_child(watch)
	watch.start()
	await _through_scene()

	print("-- scenario 9: the Legion breaks the seal")
	Engine.time_scale = 4.0
	await _s9_waves_to(_s9().LEGION_WAVES[0] - 1)
	spare_kinds = ["octopus", "octopus_arm", "legion_*"]
	spare = "Leviathan"
	check(await wait_until(func() -> bool: return sc.named_enemy("Lysa") != null, 120.0), "wave 6: Lysa comes")
	await _through_scene()
	check(await wait_until(func() -> bool: return not ab.sealed, 300.0), "nobody stops them: the seal breaks")
	check(await wait_until(func() -> bool: return sc.mark.has("woken"), 5.0) and ab.blocked == "", "the leviathan wakes, but blocks nothing")
	await _through_scene()
	check(await wait_until(func() -> bool: return _s9()._relic_at(sc) == "lysa", 60.0), "Lysa searches the crypt and takes the relic")
	var lysa := sc.named_enemy("Lysa")
	lysa.take_damage(lysa.hp - lysa.max_hp * 0.2, h, "pure")
	check(await wait_until(func() -> bool: return _s9()._relic_at(sc) == "ground", 5.0) and lysa.retreating, "beaten, she falls back and drops it")
	var sack: Treasure = sc.mark.get("sack")
	await wait(3.0)
	var co: LegionCompany = sc.mark.get("company")
	var guards := co.members.filter(func(m: Enemy) -> bool: return m.grid_pos.distance_to(Vector2(sack.tile)) < 3.0).size()
	check(sack != null and sack.art() == "relic_sword" and guards >= 3, "her soldiers stand round it (%d)" % guards)
	spare_kinds = ["octopus", "octopus_arm"]
	await wait(2.0)
	kill_camps = true  # (the vampires by the abbey: she'd run from them)
	await wait(1.0)
	kill_camps = false
	if is_instance_valid(octo) and not octo.dead:
		kill(octo, h)  # (the guard by the island: Brenna exploring would run from it)
	game.waves.hold = true  # (wave 7 waits until she has taken it to the gate: it's a long way round from her tent)
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	check(await wait_until(func() -> bool: return _s9()._relic_at(sc) == "hero", 300.0), "Brenna picks it up%s" % _s9_why())
	check(h.home_override == _s9()._hand_in_tile(sc), "she takes it to the gate, not to her tent")
	check(await wait_until(func() -> bool: return _s9()._relic_at(sc) == "home", 300.0) and church.holds_relic and not _s9()._relic_mine(sc), "the priests take it in: they keep it")
	check(not game.map.in_village(_s9()._hand_in_tile(sc)) and not inside[0], "handed in at the gate, from outside")
	await _through_scene()
	check(await wait_until(func() -> bool: return h.home_override == sc.mark.get("tent"), 5.0), "and she goes back to her tent")
	game.waves.hold = false

	print("-- scenario 9: three Legion waves, the priests' trust")
	var seen := {sc.mark.get("company"): true}
	var t := 0.0
	while not sc.mark.has("trust") and not game.game_over and t < 1500.0:
		if sc.cutscene != null:
			await _through_scene()
		seen[sc.mark.get("company")] = true
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5
	check(seen.size() == 3, "the Legion comes in waves 6, 7 and 8 (%d columns)" % seen.size())
	watch.queue_free()
	check(not inside[0], "all that time, she never set foot in the village")
	check(not h.barred.has_area(), "trusted: the village is open to her again")
	check(sc.mark.has("trust") and h.home_override == Vector2i(-1, -1) and _s9()._relic_mine(sc), "after the third the priests let her in, and the relic is hers")

	print("-- scenario 9: the request, the messenger, the decree")
	check(await wait_until(func() -> bool: return sc.mark.has("asked"), 30.0), "the leviathan lives: the priests ask her to slay it")
	while sc.cutscene != null:
		await _through_scene(1)
	check(sc.mark.has("messenger") and (sc.mark.has("decree") or not sc._goal_shown.has("leviathan")), "she refuses: a messenger goes to Fiona")
	if not sc.mark.has("decree"):
		await _s9_waves_to(int(sc.mark["messenger"]) + 1)
	await _through_scene()
	check(sc.mark.has("decree") and await wait_until(func() -> bool: return sc._goal_shown.has("leviathan"), 3.0), "a wave later, Fiona's decree: slay the leviathan")
	spare = ""
	kill(sc.named_enemy("Leviathan"), h)
	check(await wait_until(func() -> bool: return sc.phase in [ScenarioRunner.Phase.OUTRO, ScenarioRunner.Phase.OVER], 300.0), "slain: done")
	while sc.cutscene != null and not sc._outro_started:
		await _through_scene()
	await wait_until(func() -> bool: return sc.cutscene != null and sc._outro_started, 300.0)
	guard.queue_free()
	Engine.time_scale = 1.0
	var said := await _watch(sc.cutscene)
	check(said.has("eldest") and said.has("lysa"), "the outro (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won, "won: %s%s" % [game.hud._overlay_title.text, _s9_why()])
	spare_kinds = []


## A fresh game with the intro skipped, and its Legion column sent for the
## relic now (the wave under way); Lysa is made hard to stop. Returns her.
func _s9_legion_now() -> Enemy:
	cmd("hero_mode", {"mode": Hero.Mode.REST})
	game.waves.start_now()
	_s9()._send_legion(sc, _s9().LEGION_COLUMNS[0], _s9()._legion_spawn(sc))
	await wait_until(func() -> bool: return sc.named_enemy("Lysa") != null, 30.0)
	var l := sc.named_enemy("Lysa")
	if l:
		l.max_hp *= 30.0  # (nobody stops her in these tests)
		l.hp = l.max_hp
	return l


## The relic in the church (home): Lysa gets in, searches it 8 s and takes it.
func _s9_church() -> void:
	print("-- scenario 9: Lysa searches the church")
	await _new_game(9)
	await wait(1.0)
	sc.cutscene.skip()
	await frames(3)
	var v := game.player_village
	var church: Church = _s9()._church(sc)
	var ab: Treasure = _s9()._abbey(sc)
	ab.sealed = false
	ab.mark_looted()
	v.items.append(_s9().RELIC)
	church.holds_relic = true
	sc.mark["relic"] = "home"
	sc.mark["slain"] = true  # (no request scene in the way)
	var lysa := await _s9_legion_now()
	await wait(2.0)
	var inside := church.tile + Vector2i(0, 2)
	lysa.set_grid_pos(Vector2(inside))
	lysa.follow(PackedVector2Array([Vector2(inside)]))  # (as if she had broken in: her walk ends inside)
	var co: LegionCompany = sc.mark.get("company")
	check(await wait_until(func() -> bool: return co.state == LegionCompany.State.SEARCH, 30.0) and co._search_at == "church", "inside the walls Lysa goes to the church and searches it")
	var t0 := game.clock
	var taken := await wait_until(func() -> bool: return _s9()._relic_at(sc) == "lysa", 30.0)
	check(taken and game.clock - t0 >= co.SEARCH_TIME - 0.5, "she takes the relic after searching %.1f s" % (game.clock - t0))
	check(not church.holds_relic and not v.items.has(_s9().RELIC), "the church has lost it")


## The relic on the ground: Lysa picks it up at once, no searching.
func _s9_ground() -> void:
	print("-- scenario 9: Lysa picks the relic up from the ground")
	await _new_game(9)
	await wait(1.0)
	sc.cutscene.skip()
	await frames(3)
	var ab: Treasure = _s9()._abbey(sc)
	ab.sealed = false
	ab.mark_looted()
	var road := sc.road_in(ab.tile, 100000)
	var at := road[mini(8, road.size() - 1)]
	sc.mark["sack"] = game.world.add_dropped_loot(at, {"item": _s9().RELIC})
	sc.mark["relic"] = "ground"
	Engine.time_scale = 4.0
	await _s9_legion_now()
	var co: LegionCompany = sc.mark.get("company")
	check(await wait_until(func() -> bool: return _s9()._relic_at(sc) == "lysa", 120.0), "Lysa walks to the relic on the road and takes it")
	check(co._search_at == "" and co.state == LegionCompany.State.CARRY, "at once, without searching: off with it")
	Engine.time_scale = 1.0


## The relic home, the leviathan alive: the priests ask, she says yes.
func _s9_yes() -> void:
	print("-- scenario 9: yes to the priests")
	await _new_game(9)
	await wait(1.0)
	sc.cutscene.skip()
	await frames(3)
	var ab: Treasure = _s9()._abbey(sc)
	ab.sealed = false
	ab.mark_looted()
	game.player_village.items.append(_s9().RELIC)
	_s9()._church(sc).holds_relic = true
	sc.mark["relic"] = "home"
	sc.mark["watch"] = game.clock - 10.0  # (the start's goal, as if met long ago)
	_s9()._wake_leviathan(sc, false)
	check(await wait_until(func() -> bool: return sc.mark.has("asked"), 10.0), "the relic home, the leviathan alive: the priests ask")
	while sc.cutscene != null:
		await _through_scene(0)  # (the leviathan's scene, then the request: yes)
	check(sc.mark.has("hunt") and not sc.mark.has("messenger"), "she says yes: no messenger")
	check(await wait_until(func() -> bool: return sc._goal_shown.has("leviathan"), 3.0), "the objective: slay the leviathan")
	check(sc.phase == ScenarioRunner.Phase.PLAY, "not won while it lives")
	kill(sc.named_enemy("Leviathan"), game.hero)
	check(await wait_until(func() -> bool: return sc.phase in [ScenarioRunner.Phase.OUTRO, ScenarioRunner.Phase.OVER], 10.0), "slain: done")


## Lysa gets to the map edge with the relic: lost.
func _s9_escape() -> void:
	print("-- scenario 9: Lysa escapes")
	await _new_game(9)
	await wait(1.0)
	sc.cutscene.skip()
	await frames(3)
	var ab: Treasure = _s9()._abbey(sc)
	ab.seal_hp = 1.0
	cmd("hero_mode", {"mode": Hero.Mode.REST})
	spare_kinds = ["octopus", "octopus_arm", "legion_*"]
	var guard := _s9_guard()  # (the wave's crabs and goblins: Pell must not die meanwhile)
	game.waves.start_now()
	_s9()._send_legion(sc, _s9().LEGION_COLUMNS[0], _s9()._legion_spawn(sc))
	await wait_until(func() -> bool: return sc.named_enemy("Lysa") != null, 30.0)
	var l := sc.named_enemy("Lysa")
	if l:
		l.max_hp *= 30.0  # (nobody stops her in this test)
		l.hp = l.max_hp
	Engine.time_scale = 4.0
	check(await wait_until(func() -> bool: return _s9()._relic_at(sc) == "lysa", 300.0), "the seal broken, Lysa takes the relic")
	var lysa := sc.named_enemy("Lysa")
	if lysa and lysa.path.size() > 3:
		lysa.set_grid_pos(lysa.path[lysa.path.size() - 2])
		lysa.path_index = lysa.path.size() - 1
	check(await wait_until(func() -> bool: return game.game_over, 60.0), "she gets to the edge of the map")
	guard.queue_free()
	spare_kinds = []
	Engine.time_scale = 1.0
	check(game.game_over and not game.hud._overlay_won and game.hud._overlay_sub.text.contains("Lysa"), "lost: %s" % game.hud._overlay_sub.text.split("\n")[0])


# --- scenario 10: The Last Wardline ------------------------------------------------------------

func _scenario_10() -> void:
	print("-- scenario 10: setup")
	await _new_game(10)
	var v := game.player_village
	var h := game.hero
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Wardline", "scenario 10 runs on the home map, grown")
	check(sc.ruin_sites.is_empty() and not game.world.map_objects.any(func(o: Node) -> bool: return o is RuinedTower), "every Wardline ruin stands restored")
	var restored := v.buildings().filter(func(b: Building) -> bool: return b is MilitaryPost and (b as MilitaryPost).capacity() > 0 and b.complete and not b.devastated)
	check(restored.size() >= 9, "a village at its strongest: many manned posts (%d)" % restored.size())
	check(game.army.stationed().size() >= 14 and game.army.reserve().size() == 2, "its army on them, two in the reserve (%d stationed)" % game.army.stationed().size())
	check(v.huts().all(func(b: Building) -> bool: return not (b as Hut).ruined), "every hut stands")
	var einar := game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Einar")
	check(einar.size() == 1 and (einar[0] as Civilian).role == "forester", "Einar is the forester")
	check(h.level == 15 and not sc.spec.hero_revives, "Brenna at level 16, no revive even at home")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("einar") and said.has("pell") and said.has("brenna"), "the intro: torches on the horizon, Einar's greeting (%s)" % str(said))

	print("-- scenario 10: the commander")
	var at: Vector2i = game.map.edge_spawns[0]
	var foot := game.waves.spawn_at("legion_footman", at, v, 1)
	var marshal := game.waves.spawn_at("legion_marshal", at, v, 1)
	await frames(2)
	foot._haste_at = -INF
	check(is_equal_approx(foot.haste(), 1.3) and is_equal_approx(foot.guard(), 0.75), "a footman near the marshal strikes 1.3x as fast and takes 0.75x (%s, %s)" % [foot.haste(), foot.guard()])
	var hp0 := foot.hp
	foot.take_damage(8.0, null, "melee")
	check(is_equal_approx(hp0 - foot.hp, 6.0), "8 damage takes 6")
	marshal.set_grid_pos(Vector2(at) + Vector2(6, 0))
	foot._haste_at = -INF
	check(is_equal_approx(foot.haste(), 1.0) and is_equal_approx(foot.guard(), 1.0), "away from him, as ever")
	kill(marshal, h)
	check(marshal.dead, "the marshal can be killed")
	await clear_enemies()

	print("-- scenario 10: the waves, the caravans, the mages, the marshal")
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	Engine.time_scale = 4.0
	guard.start()
	var demand := false
	var torben := false
	var lysa := false
	var halvard := false
	var rallied := false
	var halted := false
	spare = "Halvard"  # (alive a while when he comes: he rallies)
	var t := 0.0
	while not sc.phase in [ScenarioRunner.Phase.OUTRO, ScenarioRunner.Phase.OVER] and not game.game_over and t < 2400.0:
		if sc.cutscene != null:
			if sc.cutscene.steps.any(func(s: Dictionary) -> bool: return s.has("choices")):
				demand = true
			await _through_scene(1)
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Enemy
			torben = torben or en.given_name == "Torben"
			lysa = lysa or en.given_name == "Lysa"
			if en.given_name == "Halvard" and not halvard:
				halvard = true
				var near := game.waves.spawn_at("legion_footman", en.current_tile(), v, 1)
				await frames(1)
				near.set_grid_pos(en.grid_pos)
				near._haste_at = -INF
				check(near.guard() < 1.0, "his soldiers take less harm near him")
				near.take_damage(1e9)
		if halvard and spare == "Halvard":
			rallied = rallied or game.events.entries.any(func(en) -> bool: return str(en["text"]).contains("rallies the Legion"))
			if rallied:
				spare = ""
		for n in game.world.objects.get_children():
			if is_instance_valid(n) and n is ScenarioCaravan and not halted and game.waves.in_progress() and not (n as ScenarioCaravan).arrived \
					and (n as ScenarioCaravan).progress < (n as ScenarioCaravan).road.size() - 8:
				halted = true
				var cv := n as ScenarioCaravan
				var stop := game.waves.spawn_at("goblin", cv.road[mini(int(cv.progress) + 2, cv.road.size() - 1)], v, 1)
				stop.set_process(false)
				stop.set_identity("Roadblock", "")
				stop.max_hp = 1e8  # (the towers don't shoot it away meanwhile)
				stop.hp = 1e8
				var spared := spare
				spare = "Roadblock"  # (nor the guard)
				await wait(1.0)
				check(cv.halted, "a caravan halts with an enemy on the road ahead")
				var p0 := cv.progress
				await wait(0.5)
				check(is_equal_approx(cv.progress, p0), "and doesn't move")
				if is_instance_valid(stop):
					kill(stop)
				spare = spared
				await wait(1.0)
				check(not cv.halted and cv.progress > p0, "the road clear, it goes on")
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5
	check(not game.game_over and sc.phase == ScenarioRunner.Phase.OUTRO, "sixteen waves held%s" % (" (game over: %s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(demand, "Lothar's demand came, and was refused")
	check(sc.mark.has("mages") and game.army.units.filter(func(u: MilitaryUnit) -> bool: return u.kind in ["fire_mage", "ice_mage", "healing_mage"]).size() >= 3, "Fiona's three mages joined")
	check((torben or named.get("Torben", "") == "legion_captain") and (lysa or named.get("Lysa", "") == "legion_captain"), "Torben and Lysa led attacks")
	check(halvard and rallied and sc.mark.has("halvard down"), "Halvard came, rallied the Legion and fell")
	check(int(sc.mark.get("caravans in", 0)) >= 4, "the guild's caravans came in (%d)" % int(sc.mark.get("caravans in", 0)))
	while sc.cutscene != null and not sc._outro_started:
		await _through_scene()
	check(await wait_until(func() -> bool: return sc.cutscene != null and sc._outro_started, 120.0), "the outro plays")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("halvard") and said.has("idris"), "Halvard's thanks, and Fiona's word (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Last Wardline: complete", "won: %s" % game.hud._overlay_title.text)

	print("-- scenario 10: opening the gates")
	await _new_game(10)
	sc.cutscene.skip()
	await frames(2)
	sc.spec._demand(sc)
	await frames(2)
	await _watch(sc.cutscene, 0)
	check(await wait_until(func() -> bool: return game.game_over, 3.0) and game.hud._overlay_sub.text.contains("opened the gates"), "surrendering loses (%s)" % game.hud._overlay_sub.text)


# --- scenario 11: The Crown --------------------------------------------------------------------

func _scenario_11() -> void:
	print("-- scenario 11: setup")
	await _new_game(11)
	var v := game.player_village
	var h := game.hero
	check(sc != null and sc.error == "" and MapJson.map_name(game.map) == "The Capital", "scenario 11 runs on the capital's map")
	var city := 0
	var houses := 0
	var farmable := 0
	for y in game.map.size:
		for x in game.map.size:
			var tt := Vector2i(x, y)
			if game.map.zone(tt) == "city":
				city += 1
				if game.map.is_mountain(tt) and str(game.map.props.get(tt, "")).begins_with("house"):
					houses += 1
			if game.map.is_passable(tt) and not bool(Config.ZONES[game.map.zone(tt)].get("no_farms", false)):
				farmable += 1
	check(city > 1000 and houses > 150, "a city: cobbles and houses (%d city tiles, %d houses)" % [city, houses])
	check(farmable < 200 and not sc.allows_building("farm"), "no fields: nothing to farm, no farms to build (%d)" % farmable)
	var hall: Treasure = sc.spec._hall(sc)
	check(hall != null and int(hall.data["size"]) == 3 and not hall.lootable() and hall.landmark() != "", "the throne hall: a landmark nobody loots")
	var fiona := game.population.civilians.filter(func(c: Civilian) -> bool: return c.given_name == "Fiona")
	check(fiona.size() == 1 and fiona[0] is Resident and sc.spec.must_live.has("Fiona"), "Fiona stays in her house and must not die")
	var bound := game.army.units.filter(func(u: MilitaryUnit) -> bool: return u.bound)
	check(bound.size() == 3 and bound.all(func(u: MilitaryUnit) -> bool: return u.state == MilitaryUnit.State.STATIONED and u.kind.ends_with("_mage")), "Fiona's three mages hold their towers, taking no orders")
	check(h.level == 17 and game.army.reserve().size() == 5, "Brenna at level 18, the army in the reserve")
	await wait(1.0)
	var said := await _watch(sc.cutscene)
	check(said.has("fiona") and said.has("pell"), "the intro: the Hand given to Fiona (%s)" % str(said))

	print("-- scenario 11: the king")
	var at := sc.spawn_near(hall.tile)
	var king := game.waves.spawn_at("legion_king", at, v, 1)
	await frames(2)
	check(king.spec()["cleave"] > 0.0 and king.spec().has("command_radius"), "the king: a commander whose blows cleave")
	kill(king, h)
	await frames(2)
	check(not king.dead and king.retreating and king.hp >= 1.0 and not king.targetable(), "at 0 HP he is downed, not killed, and can't be hit")
	check(await wait_until(func() -> bool: return not is_instance_valid(king) or king.dead, 60.0), "he flees along his road and is gone")
	await clear_enemies()

	print("-- scenario 11: the waves, the carts, Rhodri")
	var posts: Array = sc.towers(true).filter(func(b: Building) -> bool: return b.working() and (b as Tower).garrison == null)
	posts.append_array(v.buildings().filter(func(b: Building) -> bool: return b is Barracks))
	for post in posts:
		var fit := game.army.reserve().filter(func(m: MilitaryUnit) -> bool: return m.fits(post.post_kind()))
		if not fit.is_empty():
			cmd("station_unit", {"unit": (fit[0] as MilitaryUnit).nid, "post": post.nid})
	var guard := Timer.new()
	guard.wait_time = 0.5
	guard.timeout.connect(_kill_wave)
	add_child(guard)
	Engine.time_scale = 4.0
	guard.start()
	var food0 := game.economy.amount("food")
	var fed := false
	var rhodri := false
	var t := 0.0
	while not sc.phase in [ScenarioRunner.Phase.OUTRO, ScenarioRunner.Phase.OVER] and not game.game_over and t < 2400.0:
		if sc.cutscene != null:
			await _through_scene()
		if not fed and game.events.entries.any(func(en) -> bool: return str(en["text"]).begins_with("The guild caravan is in")):
			fed = true
		rhodri = rhodri or sc.named_enemy("Rhodri") != null or sc.mark.has("rhodri down")  # (beaten and fled between two looks: he came out)
		if game.waves.can_call():
			cmd("call_wave")
		await wait(0.5)
		t += 0.5
	check(not game.game_over and sc.phase == ScenarioRunner.Phase.OUTRO, "twelve waves held%s" % (" (game over: %s)" % game.hud._overlay_sub.text if game.game_over else ""))
	check(fed and food0 > 0.0, "food came by the guild's carts")
	check(rhodri and sc.mark.has("rhodri down") and sc.mark.has("lothar down"), "Rhodri came out, was beaten and fled; Lothar fell (seen %s, down %s, Lothar down %s)" % [rhodri, sc.mark.has("rhodri down"), sc.mark.has("lothar down")])
	while sc.cutscene != null and not sc._outro_started:
		await _through_scene()
	check(await wait_until(func() -> bool: return sc.cutscene != null and sc._outro_started, 120.0), "the outro plays")
	guard.queue_free()
	Engine.time_scale = 1.0
	said = await _watch(sc.cutscene)
	check(said.has("rhodri") and said.has("cursed"), "Fiona and her brother; the curse (%s)" % str(said))
	await frames(3)
	check(game.game_over and game.hud._overlay_won and game.hud._overlay_title.text == "The Crown: complete", "won: %s" % game.hud._overlay_title.text)
