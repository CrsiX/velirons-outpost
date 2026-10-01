extends "res://tests/bot_base.gd"
## Headless test of the guided tutorial (docs/tutorial-design.md, part A): its
## setup (map, small village, waiting waves), every one of the 12 steps done
## with commands as a player would, the two tutorial waves, Play on / Skip
## leading to a normal game, the defeat button and the title screen's
## Tutorial button. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/tutorial_bot.tscn
## Exits 0 when every check passes.

var tut: Tutorial
var _done_before := false


func _run() -> void:
	_done_before = Settings.tutorial_done
	Settings.tutorial_done = false
	var diff := Settings.difficulty
	Settings.difficulty = Settings.Difficulty.HARD
	await _play_through()
	await _skip()
	await _defeat()
	await _title()
	check(Settings.difficulty == Settings.Difficulty.HARD, "the player's difficulty is back once the tutorial game is gone")
	Settings.difficulty = diff
	Settings.tutorial_done = _done_before
	Settings.save_player()
	Engine.time_scale = 1.0
	print("CHECKS %d  FAILURES %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _new_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await frames(2)
	Settings.tutorial_next = true
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await frames(3)
	tut = game.tutorial


func at_step(i: int, timeout: float) -> bool:
	return await wait_until(func() -> bool: return tut.step == i and tut._next_in < 0.0, timeout)


func steps_wait_text() -> String:
	return str(tut.steps[5]["wait_text"])


func cmd(type: String, args: Dictionary = {}) -> Dictionary:
	var r := game.command(type, args)
	if not r["ok"]:
		print("    (%s refused: %s)" % [type, r["error"]])
	return r


func _play_through() -> void:
	print("-- setup")
	await _new_game()
	var v := game.player_village
	check(tut != null and tut.active, "the tutorial runs (from Settings.tutorial_next)")
	check(not Settings.tutorial_next, "the request is used up")
	check(game.map.seed_value == 1337 and game.map.map_type == "highlands", "map: Highlands, seed 1337")
	check(Settings.difficulty == Settings.Difficulty.EASY, "difficulty: Easy")
	var roles := v.population.civilians.map(func(c: Civilian) -> String: return c.role)
	roles.sort()
	check(roles == ["builder", "forester"], "only a builder and a forester (%s)" % str(roles))
	var kinds := v.buildings().filter(func(b: Building) -> bool: return not (b is Hut) and b.kind != "gate").map(func(b: Building) -> String: return b.kind)
	check(not kinds.has("farm") and kinds.has("camp"), "the forester's camp and no farm (%s)" % str(kinds))
	check(int(v.economy.amount("materials")) == int(Config.TUTORIAL["resources"]["materials"]), "the tutorial's resources")
	check(game.hero.mode == Hero.Mode.REST, "the hero rests")
	check(game.waves.hold and not game.corpses.rot, "waves wait, corpses don't rot")
	check(tut.card.visible and tut._title.text == "Build a watchtower" and tut._progress.text == "Step 1 of 12", "card: step 1 of 12")
	for t in [tut.tower_tile, tut.farm_tile, tut.barracks_tile]:
		check(t != Vector2i(-1, -1), "a spot was picked: %s" % str(t))
	check(game.construction.placement_error("tower", tut.tower_tile) == "", "the watchtower spot can be built on now")
	check(game.construction.placement_error("farm", tut.farm_tile) == "", "the farm field can be built on now")
	check(game.construction.placement_error("barracks", tut.barracks_tile) == "", "the barracks spot can be built on now")
	check(tut.route.size() == int(Config.TUTORIAL["spawn_distance"]) + 1 and tut.route.has(tut.spawn_tile), "the waves' road: %d tiles" % tut.route.size())
	check(tut.highlight.target == game.hud.control_named("build:tower") and tut.highlight.tiles == [tut.tower_tile], "step 1 points at the Watchtower entry and the spot")
	await wait(1.0)
	check(game.waves.countdown == Config.FIRST_WAVE_DELAY, "no countdown")
	Engine.time_scale = 8.0

	print("-- steps 1-2: the watchtower")
	game.begin_build("tower")
	await frames(2)
	check(tut.highlight.target == null, "placing: only the spot is marked")
	game._try_place(tut.tower_tile)
	game.cancel_mode()
	check(await at_step(1, 5.0), "step 2 once the site is placed")
	check(await at_step(2, 60.0), "step 3 once the tower is finished")
	var tower: Tower = tut._towers()[0]

	print("-- step 3: an archer")
	check(tut.highlight.target == game.hud.control_named("army:archer"), "points at the archer entry (Army tab)")
	check(game.hud._current_tab == "army", "the Army tab opened")
	var u: MilitaryUnit = game.entity(int(cmd("recruit_unit", {"kind": "archer"})["id"]))
	cmd("station_unit", {"unit": u.nid, "post": tower.nid})
	check(await at_step(3, 60.0), "step 4 once the archer is on the tower")

	print("-- step 4: a farm")
	check(game.hud._current_tab == "build" and tut.highlight.target == game.hud.control_named("build:farm"), "points at the farm entry")
	check(tut.highlight.tiles.size() == 9, "and marks the 3x3 field")
	cmd("place_building", {"kind": "farm", "tile": tut.farm_tile})
	await wait(1.0)
	check(tut.highlight.target == game.hud.control_named("village:farmer"), "then at the farmer entry")
	cmd("recruit_villager", {"role": "farmer"})
	check(await at_step(4, 90.0), "step 5 once the farm is worked")

	print("-- step 5: wave 1")
	check(tut.highlight.target == game.hud.control_named("call"), "points at Call now")
	var gold := int(v.economy.amount("gold"))
	cmd("call_wave")
	check(int(v.economy.amount("gold")) > gold, "calling early pays")
	await wait(0.5)
	var queued := game.waves._queue.map(func(sp: Dictionary) -> String: return sp["kind"])
	check(game.waves.wave == 1 and game.waves.enemies_left() == 2, "wave 1: 2 enemies (%d)" % game.waves.enemies_left())
	check(queued.all(func(k: String) -> bool: return k == "goblin"), "goblins")
	check(game.waves._queue.all(func(sp: Dictionary) -> bool: return sp["spawn"] == tut.spawn_tile), "from the tutorial's road")
	await wait(2.0)
	check(tut.step == 4 and game.corpses.count() == 0, "step 5 done, but step 6 waits for the wave")
	check(tut._text.text == steps_wait_text(), "the card: here they come")
	check(await wait_until(func() -> bool: return tut.step == 5, 120.0), "step 6 comes...")
	check(game.corpses.count() > 0, "...with the first corpse")

	print("-- step 6: a gatherer")
	cmd("recruit_villager", {"role": "gatherer"})
	check(await wait_until(func() -> bool: return not game.waves.in_progress(), 120.0), "wave 1 is over")
	check(game.player_village.intact_huts().size() == game.player_village.huts().size(), "no hut burnt: the archer won")
	check(not game.waves.can_call() and not cmd("call_wave")["ok"], "wave 2 can't be called")
	check(game.waves.countdown > 0.0, "a countdown is set...")
	var cd := game.waves.countdown
	await wait(2.0)
	check(game.waves.countdown == cd, "...but stands still")
	check(await at_step(6, 120.0), "step 7 once a corpse is home (%d delivered)" % v.corpses_delivered)

	print("-- step 7: the hero explores")
	check(tut.highlight.target == game.hud.control_named("hero"), "points at the hero button")
	game.hud._hero_button.pressed.emit()
	await wait(0.5)
	check(tut.highlight.target == game.hud.control_named("hero_mode:%d" % Hero.Mode.EXPLORE), "then at the Explore mode")
	check(tut.card.position.x >= game.hud.hero_panel_rect().end.x, "the card moves beside the hero panel")
	cmd("hero_mode", {"mode": Hero.Mode.EXPLORE})
	check(await at_step(7, 120.0), "step 8 once he has earned XP")

	print("-- step 8: a hero level")
	check(game.hero.xp >= game.hero.level_up_cost(), "he has the XP for it (%d)" % game.hero.xp)
	cmd("hero_level_up")
	check(await at_step(8, 5.0), "step 9 at level 2")

	print("-- step 9: barracks")
	check(game.waves.wave == 1, "wave 2 waits for the barracks")
	cmd("place_building", {"kind": "barracks", "tile": tut.barracks_tile})
	check(await wait_until(func() -> bool: return tut._barracks().any(func(b: Barracks) -> bool: return b.complete), 90.0), "the barracks are built")
	var barracks: Barracks = tut._barracks()[0]
	var sb: MilitaryUnit = game.entity(int(cmd("recruit_unit", {"kind": "shield_bearer"})["id"]))
	cmd("station_unit", {"unit": sb.nid, "post": barracks.nid})
	check(await wait_until(func() -> bool: return tut.step == 9, 60.0), "step 10 once a shield bearer is on a bench")
	await wait(0.5)
	var w2 := {}
	for sp in game.waves._queue:
		w2[sp["kind"]] = w2.get(sp["kind"], 0) + 1
	check(game.waves.wave == 2 and game.waves.enemies_left() == 6, "wave 2 started: 6 enemies (%d)" % game.waves.enemies_left())
	check(w2.get("ork", 0) + (0 if game.waves._queue.size() == 6 else 1) >= 1, "with an ork (%s)" % str(w2))

	print("-- step 10: a unit level")
	await at_step(9, 5.0)
	check(cmd("upgrade_unit", {"unit": u.nid})["ok"], "the archer goes up a level")
	check(await at_step(10, 5.0), "step 11")

	print("-- step 11: a tower upgrade")
	check(cmd("upgrade_tower", {"building": tower.nid})["ok"], "the watchtower upgrade is ordered")
	check(await at_step(11, 120.0), "step 12 once it's finished (level %d)" % tower.level)

	print("-- step 12: the end")
	check(tut._end_row.visible and not tut._skip.visible, "the end card: Play on / Back to title")
	check(await wait_until(func() -> bool: return not game.waves.in_progress(), 180.0), "wave 2 is over")
	Engine.time_scale = 1.0
	check(game.waves.wave == 2 and not game.waves.can_call(), "wave 3 waits for the end card")
	tut.finish(true)
	await frames(2)
	check(not tut.active and not is_instance_valid(tut.card) and not is_instance_valid(tut.highlight), "Play on: the card is gone")
	check(Settings.tutorial_done, "remembered as done")
	check(not game.waves.hold and not game.waves.call_locked and game.corpses.rot and game.waves.scripted.is_empty(), "a normal game: waves and corpses as ever")
	cd = game.waves.countdown
	await wait(1.0)
	check(game.waves.countdown < cd, "the countdown runs")
	check(game.waves.can_call(), "wave 3 can be called")
	game.command("call_wave")
	await wait(0.2)
	check(game.waves.wave == 3 and game.waves.enemies_left() == Config.wave_size(3) or game.waves.enemies_left() > 2, "wave 3 is a normal wave (%d enemies)" % game.waves.enemies_left())


func _skip() -> void:
	print("-- skip")
	Settings.tutorial_done = false
	await _new_game()
	tut._skip.pressed.emit()
	check(tut.skip_dialog.visible, "Skip tutorial asks first")
	var back: Button = tut.skip_dialog.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Back to the tutorial")[0]
	back.pressed.emit()
	check(not tut.skip_dialog.visible and tut.active, "Back to the tutorial: it goes on")
	tut.open_skip_dialog()
	var on: Button = tut.skip_dialog.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Play on")[0]
	on.pressed.emit()
	await frames(2)
	check(not tut.active and Settings.tutorial_done, "Play on: over, and remembered")
	check(not game.waves.hold and game.waves.scripted.is_empty(), "no tutorial waves left")
	var cd := game.waves.countdown
	await wait(1.0)
	check(game.waves.countdown < cd, "the normal countdown runs")


func _defeat() -> void:
	print("-- defeat")
	await _new_game()
	game.game_over = true
	game.hud.show_game_over("Fallen", "test")
	check(game.hud._overlay_button.text == "Try the tutorial again", "defeat offers the tutorial again")
	await frames(1)
	check(not tut.card.visible, "the card hides on defeat")
	game.hud._overlay.visible = false
	game.game_over = false
	tut.finish(true)
	game.hud.show_game_over("Fallen", "test")
	check(game.hud._overlay_button.text == "Try again", "after the tutorial: a plain Try again")
	game.queue_free()
	await frames(2)


func _title() -> void:
	print("-- title screen")
	var t = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await frames(2)
	t.show_page(t._sp_page)
	var tb: Button = t.tutorial_button
	check(tb.get_index() == t.play_button.get_index() - 1, "Tutorial sits above Play")
	check(tb.icon != null, "done: it has a tick")
	Settings.tutorial_done = false
	t._update_sp_buttons()
	check(tb.icon == null, "not done: no tick")
	t.queue_free()
	await frames(1)
