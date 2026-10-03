extends "res://tests/bot_base.gd"
## Headless test of the in-game statistics (docs/statistics-design.md): the
## counters (kills by kind and by whom, earned and spent, recruits, losses,
## huts), sampling every 15 game seconds (game speed counts, a pause doesn't),
## the top-bar button (from wave 2, T, pausing single player), the three tabs,
## the game-over button, hot-seat columns with the best value marked, and the
## numbers surviving the trip to a co-op client (to_net / from_net). Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/stats_bot.tscn
## Exits 0 when every check passes.


func _run() -> void:
	await _single()
	await _hotseat()
	Engine.time_scale = 1.0
	get_tree().paused = false
	print("CHECKS %d  FAILURES %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


func _tower() -> Tower:
	for b in game.player_village.buildings():
		if b is Tower:
			return b
	return null


## Every control under `n` that has meta `key` (optionally equal to `value`).
func _with_meta(n: Node, key: String, value: Variant = null) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		if c.has_meta(key) and (value == null or c.get_meta(key) == value):
			out.append(c)
		out.append_array(_with_meta(c, key, value))
	return out


func _single() -> void:
	print("-- single player")
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await frames(3)
	var st := game.stats
	var v := game.player_village
	var hud := game.hud
	check(st != null and st.enabled, "a game has its statistics, counting")
	check(st.times.size() == 1 and st.times[0] == 0.0, "the first sample is taken at the start")
	check(st.series(0, "villagers")[0] == float(v.population.count()), "it holds the villagers at the start")
	check(not st.has_value(0, "built") and not st.has_value(0, "recruit.builder"), "what comes with the start doesn't count")

	# Sampling in game time.
	Engine.time_scale = 4.0
	await wait_until(func() -> bool: return st.time > 15.5, 30.0)
	Engine.time_scale = 1.0
	check(st.times.size() == 2 and absf(st.times[1] - 15.0) < 0.5, "the next sample after 15 game seconds, at 4x too (%s)" % str(st.times))
	hud.set_speed_index(Game.SPEEDS.find(0.0))
	await frames(2)
	var t0 := st.time
	await wait(0.5)
	check(st.time == t0, "no game time passes while paused")
	hud.set_speed_index(Game.SPEEDS.find(1.0))
	await frames(2)

	# Kills: by whom and what.
	_bench_hero(true)
	var gold0 := st.value(0, "earn.gold.kills")
	var g := game.waves.debug_spawn("goblin", v)
	kill(g, game.hero)
	await frames(2)
	check(st.value(0, "kills") == 1.0 and st.value(0, "kill.goblin") == 1.0 and st.value(0, "kill_by.hero") == 1.0, "a goblin killed by the hero: counted by kind and by whom")
	check(st.value(0, "hero.kills") == 1.0 and not (st.villages[0]["hero_waves"] as Dictionary).is_empty(), "the hero's kills, per wave too")
	check(st.value(0, "earn.gold.kills") - gold0 == float(Config.enemy_stat("goblin", "gold_on_kill")), "its kill gold counts as gold from kills")
	var tower := _tower()
	var o := game.waves.debug_spawn("ork", v)
	kill(o, tower)
	await frames(2)
	check(st.value(0, "kill.ork") == 1.0 and st.value(0, "kill_by.tower") == 1.0, "an ork killed by a tower")
	check((st.villages[0]["towers"] as Dictionary).has(tower.nid), "the tower is in the running for Deadliest tower")
	var r := game.waves.debug_spawn("skeleton", v)
	r.raised = true
	kill(r, tower)
	var d := game.waves.debug_spawn("goblin", v)
	d.raised = true
	d.decayed = true
	kill(d)
	await frames(2)
	check(st.value(0, "kill.raised") == 1.0 and st.value(0, "kills") == 3.0, "raised dead count as such; one that crumbled counts for nobody")
	var w := game.waves.debug_spawn("witch", v)
	kill(w)
	await frames(2)
	check(st.value(0, "kill.witch") == 1.0 and st.value(0, "kill_by.other") == 1.0, "no killer known: 'other'")
	_bench_hero(false)

	# Economy and the village.
	var food0 := st.value(0, "earn.food")
	game.economy.add("food", 500)
	game.economy.add("gold", 500)
	check(st.value(0, "earn.food") == food0, "resources without a source (debug, start) aren't earnings")
	v.population.recruit("builder")
	check(st.value(0, "recruit.builder") == 1.0 and st.value(0, "spend.food.villagers") == float(Config.CIVILIANS["builder"]["cost"]["food"]), "a recruit: counted, and its food as spent on villagers")
	v.army.recruit("archer")
	check(st.value(0, "units_recruited") == 1.0 and st.value(0, "spend.gold.units") == float(Config.MILITARY["archer"]["cost"]["gold"]), "an archer: counted, and its gold as spent on units")
	var huts0 := v.intact_huts().size()
	var hut: Hut = null
	for h in v.intact_huts():
		if (h as Hut).resident != null:
			hut = h
	hut.destroy("goblin 99")
	await frames(2)
	check(st.value(0, "huts_burned") == 1.0 and st.value(0, "lost.hut") == 1.0, "a burned hut and its villager, lost to the fire")
	check(st.value(0, "min_huts") == float(huts0 - 1), "the fewest intact huts so far")
	var th := game.waves.debug_spawn("thief", v)
	var stolen := game.thief_steals(th)
	check(stolen > 0 and st.value(0, "stolen") == float(stolen), "gold stolen by a thief")
	kill(th)
	await frames(2)

	# The button: from wave 2.
	check(hud._stats_button != null and hud._stats_button.get_index() == hud._book_button.get_index() + 1, "the statistics button sits right of the library")
	check(not hud.stats_available() and hud._stats_button.modulate.a < 1.0 and "wave 2" in hud._stats_button.tooltip_text, "before wave 2 it's greyed out and says when")
	hud._stats_button.pressed.emit()
	await frames(1)
	check(not hud.stats_screen.visible, "and it doesn't open")
	game.waves.wave = 2
	hud._refresh()
	check(hud.stats_available() and hud._stats_button.modulate.a == 1.0, "from wave 2 it's available")
	hud.set_speed_index(Game.SPEEDS.find(2.0))
	await frames(1)
	hud._unhandled_key_input(_key(KEY_T))
	await frames(2)
	var scr := hud.stats_screen
	check(scr.visible and get_tree().paused, "T opens it and pauses the game")
	check(hud._stats_gray.visible and hud._stats_gray.get_index() == 0, "paused: the game behind it turns grey")
	hud.toggle_pause()
	check(get_tree().paused and scr.visible, "Space does nothing while it's open")

	# The tabs.
	scr.show_tab("summary")
	await frames(2)
	check(not _with_meta(scr, "row", "Enemies killed").is_empty() and not _with_meta(scr, "row", "Goblins").is_empty(), "Summary: the kill rows")
	check(_with_meta(scr, "row", "Gargoyles").is_empty(), "sub-rows only where something happened")
	check(_with_meta(scr, "section", "Co-op").is_empty(), "no Co-op section with one village")
	var mil: Button = _with_meta(scr, "section", "Military")[0]
	mil.pressed.emit()
	await frames(2)
	check(_with_meta(scr, "row", "Enemies killed").is_empty(), "a section folds")
	(_with_meta(scr, "section", "Military")[0] as Button).pressed.emit()
	await frames(2)
	check(not _with_meta(scr, "row", "Enemies killed").is_empty(), "and opens again")
	scr.show_tab("timeline")
	await frames(2)
	var graphs := scr.find_children("*", "StatsGraph", true, false)
	check(graphs.size() == 1 and (graphs[0] as StatsGraph).data["lines"].size() == 1, "Timeline: a graph with one line")
	var graph: StatsGraph = graphs[0]
	graph.hover_at(graph.size.x - 20.0)
	check(graph.hover == st.times.size() - 1, "hovering shows the newest sample at the right end")
	scr.show_tab("awards")
	await frames(2)
	var titles := _with_meta(scr, "award").map(func(n: Node) -> String: return n.get_meta("award"))
	check("Deadliest tower" in titles and "Hero's finest wave" in titles and "Closest call" in titles, "Awards: %s" % str(titles))
	check(not "Best neighbour" in titles, "no Best neighbour alone")
	scr._unhandled_key_input(_key(KEY_ESCAPE))
	await frames(2)
	check(not scr.visible and not get_tree().paused and Game.SPEEDS[hud._speed_index] == 2.0, "Escape closes it; the game goes on at 2x")
	hud.set_speed_index(Game.SPEEDS.find(1.0))
	await frames(1)
	game.networked = true  # (as in co-op)
	hud.open_stats()
	check(scr.visible and not get_tree().paused and not hud._stats_gray.visible, "co-op: it doesn't pause, nor turn grey")
	scr._unhandled_key_input(_key(KEY_T))
	await frames(1)
	check(not scr.visible, "T closes it too")
	game.networked = false

	# A co-op client gets the numbers: through the same encoding as an RPC.
	var copy := Stats.new()
	copy.game = game
	add_child(copy)
	check(not copy.received, "a client has nothing before the host answers")
	copy.from_net(bytes_to_var(var_to_bytes(st.to_net())))
	check(copy.received and copy.value(0, "kills") == st.value(0, "kills") and copy.series(0, "gold") == st.series(0, "gold") and copy.times == st.times, "the host's counters and samples arrive whole")
	check((copy.villages[0]["towers"] as Dictionary).size() == 1, "the award tables too")
	copy.queue_free()

	# Game over.
	var n0 := st.times.size()
	game.game_over = true
	hud.show_game_over("The outpost has fallen", "test")
	await frames(3)
	check(st.ended and st.times.size() == n0 + 1, "game over: one last sample, then it stops")
	var k0 := st.value(0, "kills")
	kill(game.waves.debug_spawn("goblin", v), game.hero)
	await frames(2)
	check(st.value(0, "kills") == k0, "nothing counts after the end")
	check(hud._stats_overlay_button.visible, "the game-over screen has a Statistics button")
	hud._stats_overlay_button.pressed.emit()
	await frames(2)
	check(scr.visible and scr.get_index() > hud._overlay.get_index(), "it opens the statistics over the game-over screen")
	check(hud._food_rate_label.text.begins_with("(") and hud._food_rate_label.text.ends_with("/min)") and str(int(game.economy.amount("food"))) == hud._food_label.text, "the food rate is a label of its own next to the amount")
	scr.close()
	game.queue_free()
	await frames(3)
	get_tree().paused = false


func _hotseat() -> void:
	print("-- hot-seat co-op")
	game = load("res://scenes/main.tscn").instantiate()
	game.hotseat_villages = 2
	add_child(game)
	await frames(3)
	var st := game.stats
	check(st.villages.size() == 2 and st.series(1, "huts").size() == 1, "one set of numbers per village")
	for i in 3:
		var e := game.waves.debug_spawn("goblin", game.villages[1])
		kill(e, game.villages[1].hero)
	await frames(2)
	check(st.value(1, "kills") == 3.0 and st.value(0, "kills") == 0.0, "kills go to the killer's village")
	st.count(game.villages[0], "caravan_sent.gold", 100)
	st.count(game.villages[0], "caravans_sent")
	game.waves.wave = 3
	game.hud._refresh()
	game.hud.open_stats("summary")
	await frames(3)
	var scr := game.hud.stats_screen
	check(get_tree().paused, "hot-seat pauses like single player")
	var grids := scr.find_children("*", "GridContainer", true, false)
	check(not grids.is_empty() and (grids[0] as GridContainer).columns == 3, "a column per village")
	check(not _with_meta(scr, "section", "Co-op").is_empty(), "the Co-op section with 2 villages")
	var best := _with_meta(scr, "best")
	check(not best.is_empty(), "the best value in a row is marked")
	scr.show_tab("timeline")
	await frames(2)
	var graph: StatsGraph = scr.find_children("*", "StatsGraph", true, false)[0]
	check(graph.data["lines"].size() == 2, "the Timeline has a line per village")
	scr.show_tab("awards")
	await frames(2)
	var titles := _with_meta(scr, "award").map(func(n: Node) -> String: return n.get_meta("award"))
	check("Best neighbour" in titles, "Awards: Best neighbour in co-op")
	scr.close()
	await frames(1)
	check(not get_tree().paused, "closing it goes on")
	game.queue_free()
	await frames(3)
