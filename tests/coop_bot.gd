extends "res://tests/bot_base.gd"
## Headless test of the co-op groundwork (milestone 3 of docs/multiplayer-design.md):
## the multi-village map generator, and a game with several villages on one device (Game.test_villages)
## on one device: ownership, switching villages, waves per village, rerouting
## when a village falls, standing again. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/coop_bot.tscn
## Exits 0 when every check passes.

const SEEDS: Array[int] = [20260926, 777]



func _run() -> void:
	_test_generator()
	await _test_villages()
	await _test_help()
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- map generator --------------------------------------------------------------------------

func _test_generator() -> void:
	var table := {1: 75, 2: 75, 3: 100, 4: 100, 5: 125, 6: 125, 7: 150, 8: 150}
	var sizes_ok := true
	for p in table:
		sizes_ok = sizes_ok and Config.map_size(p) == table[p]
	check(sizes_ok, "map size follows the table: 75 / 75 / 100 / 100 / 125 / 125 / 150 / 150")
	check(is_equal_approx(Config.help_tax(1), 0.0) and is_equal_approx(Config.help_tax(2), 0.1) and is_equal_approx(Config.help_tax(3), 0.2) and is_equal_approx(Config.help_tax(6), 0.5) and is_equal_approx(Config.help_tax(8), 0.5), "help tax: 0 / 10 / 20 ... capped at 50 %")
	for p in range(1, Config.MAX_PLAYERS + 1):
		for sd in SEEDS:
			_check_map(p, sd)


func _check_map(p: int, sd: int) -> void:
	var m := MapGenerator.generate(sd, p)
	var tag := "P=%d seed %d" % [p, sd]
	var errs: Array[String] = []
	if m.size != Config.map_size(p):
		errs.append("size %d" % m.size)
	if m.villages.size() != p:
		errs.append("%d villages" % m.villages.size())
	var mid := Vector2(m.size - 1, m.size - 1) / 2.0
	if p == 1 and Vector2(m.villages[0]["center"]).distance_to(mid) > Config.VILLAGE_CENTER_RADIUS + 0.01:
		errs.append("single player village not near the middle")
	var pathing := Pathing.new(m)
	var min_d := 14.0
	for i in m.villages.size():
		var v: Dictionary = m.villages[i]
		var c: Vector2i = v["center"]
		if mini(c.x, c.y) < Config.VILLAGE_MAP_MARGIN or maxi(c.x, c.y) > m.size - 1 - Config.VILLAGE_MAP_MARGIN:
			errs.append("village %d too close to the edge" % i)
		for j in range(i + 1, m.villages.size()):
			if Vector2(c).distance_to(Vector2(m.villages[j]["center"])) < min_d:
				errs.append("villages %d and %d too close" % [i, j])
		# At least two gates lead somewhere (co-op: the ring road joins them all).
		var open_gates := (v["gates"] as Array).filter(func(g: Vector2i) -> bool: return m.is_road(g + (g - c).sign()))
		if open_gates.size() < (4 if p > 1 else 2):
			errs.append("village %d: only %d gates with a road" % [i, open_gates.size()])
		# Home spawns: its own, and its wave's route ends at its own gate.
		var homes: Array = v["home_spawns"]
		if homes.is_empty():
			errs.append("village %d has no home spawn" % i)
		for sp: Vector2i in homes:
			if p > 1 and m.slice_of[m.index(sp)] != int(v["slice"]):
				errs.append("village %d home spawn %s is outside its slice" % [i, sp])
			var route := pathing.enemy_route(sp, RandomNumberGenerator.new(), i if p > 1 else -1)
			if not (v["gates"] as Array).has(route[-1]):
				errs.append("village %d: route from %s doesn't reach its gate" % [i, sp])
		# Farm plot: free 3x3 meadow.
		var fp: Vector2i = v["farm_plot"]
		if fp == Vector2i(-1, -1):
			errs.append("village %d has no farm plot" % i)
		else:
			for t in Building.footprint(fp, 3):
				if m.get_terrain(t) != MapData.Terrain.GRASS or m.in_village(t):
					errs.append("village %d farm plot not clear at %s" % [i, t])
					break
		# Villagers can walk to every other village.
		for j in m.villages.size():
			if j != i and pathing.find_path(c, m.villages[j]["center"]).is_empty():
				errs.append("no walking path from village %d to %d" % [i, j])
		# Roads join every village to every other.
		for j in m.villages.size():
			if j != i and pathing.enemy_distance(v["gates"][0], j) >= Pathing.UNREACHABLE:
				errs.append("no road from village %d to %d" % [i, j])
	if p > 1:
		var degree := PackedInt32Array()
		degree.resize(p)
		for l in m.village_links:
			degree[l.x] += 1
			degree[l.y] += 1
		for i in p:
			if degree[i] < mini(Config.VILLAGE_MIN_LINKS, p - 1):
				errs.append("village %d has only %d link(s)" % [i, degree[i]])
	for t in m.props:
		if m.is_road(t):
			errs.append("prop on a road at %s" % t)
			break
	var m2 := MapGenerator.generate(sd, p)
	if m2.terrain != m.terrain or m2.props != m.props:
		errs.append("same seed, different map")
	check(errs.is_empty(), "%s: %dx%d, %d village(s), %d link(s), %d edge spawns %s" % [tag, m.size, m.size, m.villages.size(), m.village_links.size(), m.edge_spawns.size(), str(errs.slice(0, 4)) if not errs.is_empty() else ""])


# --- several villages on one device (Game.test_villages) --------------------------------

## Plays village `v` from here on (what a LAN player of that village does).
func _play_as(v: Village) -> void:
	game.cancel_mode()
	game.player_village = v
	game.fog.set_local(v.id)
	game.world.refresh_props()
	game.hud.bind_village(v)
	game.world.refresh_village_labels()


func _test_villages() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEEDS[0]
	game.test_villages = 3
	game.reveal_map = false
	game.disable_fog = false
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true  # (this test predates unit unlocks: tests/world_bot.gd)
	await frames(3)
	var hud := game.hud
	var vs := game.villages
	game.waves.countdown = 99999.0
	game.waves.hold = true
	Engine.time_scale = 4.0

	check(vs.size() == 3 and game.map.size == Config.map_size(3), "3 villages on a %dx%d map" % [game.map.size, game.map.size])
	check(vs.all(func(v: Village) -> bool: return v.village_name == Config.VILLAGE_NAMES[v.id] and v.color == Config.VILLAGE_COLORS[v.id]), "each village has its name and colour")
	var own_ok := true
	for v in vs:
		for b in v.buildings():
			own_ok = own_ok and (not game.map.in_village(b.tile) or game.map.village_at(b.tile) == v.id)
		own_ok = own_ok and v.population.count() == Config.START_CIVILIANS.size() and v.hero.grid_pos.distance_to(Vector2(v.center)) < 0.1
		own_ok = own_ok and v.population.civilians.all(func(c: Civilian) -> bool: return c.village == v and c.hut.village == v)
		var start := v.buildings().filter(func(b: Building) -> bool: return b is Workplace)
		own_ok = own_ok and start.size() == 2 and start.all(func(b: Building) -> bool: return b.complete and b.worker != null and Vector2(b.tile).distance_to(Vector2(v.center)) < 10.0)
	check(own_ok, "every village has its own walls, villagers, hero, and a staffed farm and camp nearby")
	var labels: Dictionary = game.world._village_labels
	check(labels.size() == 3 and not labels[0].visible and labels[1].visible and labels[1].text == vs[1].village_name and labels[2].get_theme_color("font_color") == vs[2].color, "the other villages' names float over them in their colour")

	# Playing another village: the HUD follows.
	vs[1].economy.add("gold", 777 - vs[1].economy.amount("gold"))
	_play_as(vs[1])
	await frames(3)
	check(hud._gold_label.text == "777" and not labels[1].visible and labels[0].visible, "playing village 1: the HUD shows its resources, and the labels follow")
	var r := game.command("recruit_unit", {"kind": "archer"})
	check(r["ok"] and vs[1].army.units.size() == 1 and vs[0].army.units.is_empty(), "commands act for the current village")
	var foreign_tower: Tower = vs[0].buildings().filter(func(b: Building) -> bool: return b is Tower)[0]
	var r2 := game.command("station_unit", {"unit": vs[1].army.units[0].nid, "post": foreign_tower.nid})
	check(not r2["ok"] and r2["error"] == "That isn't your tower", "a village can't station units on another village's tower")
	_play_as(vs[0])
	await frames(2)

	# Waves: one share per village plus the extra.
	var ws := Config.wave_size(1)
	var want := 3 * ws + roundi(ws * Config.WAVE_EXTRA_PER_PLAYER * 3)
	check(game.command("call_wave")["ok"] and game.waves._queue.size() == want, "a wave for 3 villages is 3 shares + the extra: %d enemies (one village's wave: %d)" % [game.waves._queue.size(), ws])
	var per_village := {}
	for q in game.waves._queue:
		var tv = q["village"]
		var k: int = tv.id if tv else -1
		per_village[k] = per_village.get(k, 0) + 1
		if tv and not (tv as Village).home_spawns.has(q["spawn"]):
			per_village["bad"] = true
	check(per_village.get(0, 0) == ws and per_village.get(1, 0) == ws and per_village.get(2, 0) == ws and per_village.get(-1, 0) == want - 3 * ws and not per_village.has("bad"), "each village's share spawns on its own home edge (%s)" % str(per_village))
	check(logged_all("Wave 1 begins"), "every village's log hears about the wave")
	# Let them all spawn, frozen in place.
	await wait_until(func() -> bool: return game.waves._queue.is_empty(), 60.0)
	await frames(2)
	var enemies := _enemies()
	for e in enemies:
		e.speed = 0.0
	var routes_ok := enemies.size() == want
	for e in enemies:
		routes_ok = routes_ok and e.target_village != null and e.target_village.gates.has(Vector2i(e.path[-1].round()))
	check(routes_ok, "every enemy's road ends at a gate of the village it was sent against (%d enemies)" % enemies.size())
	# Gold for a kill goes to whoever made it.
	var t1: Tower = vs[1].buildings().filter(func(b: Building) -> bool: return b is Tower)[0]
	game.army.recruit("archer")  # (an archer of village 0: a tower needs a unit to count as its village's)
	var archer1: MilitaryUnit = vs[1].army.units[0]
	t1.set_garrison(archer1)
	archer1.state = MilitaryUnit.State.STATIONED
	var g0 := vs[0].economy.amount("gold")
	var g1 := vs[1].economy.amount("gold")
	enemies[0].take_damage(1e9, t1)
	check(vs[1].economy.amount("gold") > g1 and vs[0].economy.amount("gold") == g0, "gold for a kill goes to the killer's village")
	# A raid hits the village it attacked, nobody else.
	var huts_before := vs.map(func(v: Village) -> int: return v.intact_huts().size())
	var raider := _enemies().filter(func(e: Enemy) -> bool: return e.target_village == vs[1])[0] as Enemy
	game.on_enemy_reached_gate(raider)
	var huts_after := vs.map(func(v: Village) -> int: return v.intact_huts().size())
	check(huts_after[1] == huts_before[1] - 1 and huts_after[0] == huts_before[0] and huts_after[2] == huts_before[2], "a raid burns a hut of the village it attacked only")

	# A village falls: its enemies turn to the nearest standing one.
	var v2 := vs[2]
	var bound_for_2 := _enemies().filter(func(e: Enemy) -> bool: return e.target_village == v2)
	for c in v2.population.civilians.duplicate():
		v2.population.kill(c, "in a test")
	await frames(2)
	check(v2.fallen and not game.game_over, "a village without villagers has fallen, the game goes on")
	check(vs[0].events.entries.any(func(e: Dictionary) -> bool: return e["text"] == "%s has fallen" % v2.village_name and e["level"] == EventLog.Level.IMPORTANT), "everyone hears that %s has fallen" % v2.village_name)
	check(labels[2].text.ends_with("(fallen)"), "its label shows it has fallen")
	var turned := not bound_for_2.is_empty()
	for e in bound_for_2:
		turned = turned and e.target_village != v2 and not e.target_village.fallen and e.target_village.gates.has(Vector2i(e.path[-1].round()))
	check(turned, "its %d enemies turn to a standing village, along the roads" % bound_for_2.size())
	game.waves._spawn({"kind": "goblin", "spawn": v2.home_spawns[0], "hp_scale": 1.0, "village": v2})
	var late: Enemy = _enemies().back()
	late.speed = 0.0
	check(late.target_village != v2 and not late.target_village.fallen, "its share of the wave goes to the nearest standing village")
	# Its hero still comes back after the wave.
	v2.hero.take_damage(1e9)
	check(v2.hero.dead, "(the fallen village's hero is down)")
	game.waves.wave_finished.emit(game.waves.wave)
	await frames(2)
	check(not v2.hero.dead and v2.hero.grid_pos.distance_to(Vector2(v2.center)) < 0.1, "the fallen village's hero revives in its centre after the wave")
	# Standing again with one villager in an intact hut.
	check(v2.population.spawn("builder") != null, "(a new villager moves in)")
	await wait_until(func() -> bool: return not v2.fallen, 3.0)
	check(not v2.fallen and vs[0].events.entries.any(func(e: Dictionary) -> bool: return e["text"] == "%s stands again" % v2.village_name), "with a villager in an intact hut it stands again")
	check(not labels[2].text.ends_with("(fallen)"), "its label is back to normal")
	game.waves._spawn({"kind": "goblin", "spawn": v2.home_spawns[0], "hp_scale": 1.0, "village": v2})
	late = _enemies().back()
	late.speed = 0.0
	check(late.target_village == v2, "and its wave comes for it again")

	# Lost only when every village has fallen.
	for v in [vs[0], vs[1]]:
		for c in v.population.civilians.duplicate():
			v.population.kill(c, "in a test")
	await frames(2)
	check(vs[0].fallen and vs[1].fallen and not v2.fallen and not game.game_over, "two villages down, one standing: not lost yet")
	for c in v2.population.civilians.duplicate():
		v2.population.kill(c, "in a test")
	await frames(2)
	check(game.game_over, "when the last village falls, the game is lost")


## Live wave enemies (not the monsters standing by their camps).
func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool: return is_instance_valid(e) and not e.dead and not e.behavior is CampBehavior)


func logged_all(part: String) -> bool:
	return game.villages.all(func(v: Village) -> bool: return v.events.entries.any(func(e: Dictionary) -> bool: return part in e["text"]))


func _tap(c: Control) -> void:
	if game and game.hud._sheet_scroll.is_ancestor_of(c):
		game.hud._sheet_scroll.ensure_control_visible(c)  # (scroll to it, as a player would)
		await frames(2)
	var pos := c.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)
		await frames(1)


# --- sending help (milestone 4) ------------------------------------------------------------

func _test_help() -> void:
	game.queue_free()
	await frames(2)
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEEDS[1]
	game.test_villages = 2
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true  # (this test predates unit unlocks: tests/world_bot.gd)
	await frames(3)
	var hud := game.hud
	var v0 := game.villages[0]
	var v1 := game.villages[1]
	game.waves.countdown = 99999.0
	game.waves.hold = true
	Engine.time_scale = 8.0
	var tax := Config.help_tax(2)

	# Resources by caravan, through the Village tab.
	hud._select_tab("village")
	hud.set_sheet_open(true)
	await frames(3)
	var entry: Button = hud._send_entry["button"]
	check(hud._send_entry["panel"].is_visible_in_tree(), "co-op: the Village tab offers Send resources")
	await _tap(entry)
	await frames(2)
	check(hud._send_panel.visible and v1.village_name in hud._send_target_button.text, "it opens the send dialog, addressed to the other village")
	v0.economy.add("gold", 500)
	var steps: Array = hud._send_labels["gold"].get_parent().get_children()
	await _tap(steps[5])  # +50
	await _tap(steps[5])
	var food_steps: Array = hud._send_labels["food"].get_parent().get_children()
	await _tap(food_steps[4])  # +10
	check(hud._send_amounts["gold"] == 100 and hud._send_amounts["food"] == 10 and "Tax 10 %" in hud._send_tax_label.text and "90 gold" in hud._send_tax_label.text and "9 food" in hud._send_tax_label.text, "picking amounts shows what arrives after the %d %% tax (%s)" % [roundi(tax * 100), hud._send_tax_label.text])
	var g0 := v0.economy.amount("gold")
	var f0 := v0.economy.amount("food")
	var g1 := v1.economy.amount("gold")
	var f1 := v1.economy.amount("food")
	await _tap(hud._send_button)
	await frames(2)
	var caravans := game.world.objects.get_children().filter(func(n) -> bool: return n is Caravan)
	check(caravans.size() == 1 and absf(v0.economy.amount("gold") - (g0 - 100)) < 1.0 and absf(v0.economy.amount("food") - (f0 - 10)) < 2.0 and not hud._send_panel.visible, "Send: the sender pays at once and a caravan sets off (gold %d -> %d)" % [g0, v0.economy.amount("gold")])
	var cv: Caravan = caravans[0] if not caravans.is_empty() else null
	check(cv != null and not cv.is_in_group("melee_defenders") and not cv.is_in_group("enemies"), "enemies can't attack caravans (nothing targets them)")
	var arrived := await wait_until(func() -> bool: return not is_instance_valid(cv) or v1.economy.amount("gold") >= g1 + 90, 60.0)
	var got_line := v1.events.entries.any(func(e: Dictionary) -> bool: return e["text"] == "Caravan from %s arrived: +90 gold, +9 food" % v0.village_name)
	check(arrived and got_line and v1.economy.amount("gold") >= g1 + 90 - 1.0, "on arrival the receiver gets the cargo minus the tax (+90 gold, +9 food; gold %d -> %d)" % [g1, v1.economy.amount("gold")])
	check(v1.events.entries.any(func(e: Dictionary) -> bool: return e["text"].begins_with("Caravan from %s arrived" % v0.village_name)) and v0.events.entries.any(func(e: Dictionary) -> bool: return e["text"].begins_with("Your caravan reached")), "both villages' logs hear about it")
	check(not game.command("send_caravan", {"target": 1, "gold": 999999})["ok"] and not game.command("send_caravan", {"target": 0, "gold": 1})["ok"] and not game.command("send_caravan", {"target": 1})["ok"], "can't send more than you have, to yourself, or nothing")

	# A reserve unit to the other village.
	hud._select_tab("army")
	await frames(2)
	var r := game.command("recruit_unit", {"kind": "archer"})
	var u: MilitaryUnit = game.entity(r["id"])
	hud._selected_unit = u
	hud._queue_refresh()
	await frames(3)
	check(hud._send_reserve_button.is_visible_in_tree(), "a Send... button sits next to Upgrade selected")
	await _tap(hud._send_reserve_button)
	check(hud._send_unit_panel.visible and v1.village_name in hud._send_unit_target_button.text, "it asks where to send the unit")
	await _tap(hud._send_unit_go)
	await frames(2)
	check(u.state == MilitaryUnit.State.TRAVELLING and not v0.army.reserve().has(u) and v0.army.walking().has(u), "the archer leaves the reserve and walks off")
	var own_tower: Tower = v0.buildings().filter(func(b: Building) -> bool: return b is Tower)[0]
	var no1 := game.command("station_unit", {"unit": u.nid, "post": own_tower.nid})
	var no2 := game.command("upgrade_unit", {"unit": u.nid})
	var no3 := game.command("withdraw_unit", {"unit": u.nid})
	var no4 := game.commands.submit(v1, "upgrade_unit", {"unit": u.nid})
	check(not no1["ok"] and not no2["ok"] and not no3["ok"] and not no4["ok"], "on the way it can't be recalled or given orders, by either village")
	var joined := await wait_until(func() -> bool: return u.village == v1, 60.0)
	check(joined and v1.army.reserve().has(u) and not v0.army.units.has(u) and u.original_owner == v0 and u.state == MilitaryUnit.State.RESERVE, "entering the other village it joins that village's reserve (the original owner is only remembered)")
	check(v1.events.entries.any(func(e: Dictionary) -> bool: return e["text"] == "Archer arrived from %s" % v0.village_name), "the receiver's log says it arrived")
	var t1: Tower = v1.buildings().filter(func(b: Building) -> bool: return b is Tower)[0]
	check(game.commands.submit(v1, "station_unit", {"unit": u.nid, "post": t1.nid})["ok"], "the new owner can station it like any of its own units")

	# The hero supports the other village.
	var hero := v0.hero
	await _tap(hud._hero_button)
	check(not hud._hero_support_button.is_visible_in_tree(), "(Defend: no support toggle)")
	check(game.command("hero_mode", {"mode": Hero.Mode.SUPPORT})["ok"] and hero.support_target == v1, "Support mode picks the other village")
	hud._refresh_hero()
	await frames(2)
	check(hud._hero_support_button.is_visible_in_tree() and v1.village_name in hud._hero_support_button.text and "defends it" in hud._hero_mode_hint.text and hud._hero_mode_word.text == "supporting" and hud._hero_mode_buttons[Hero.Mode.SUPPORT].visible, "the panel shows a second toggle with the village he supports (\"Hero: supporting\", Support icon shown in co-op)")
	var walk := {"ok": true, "last": hero.grid_pos}
	var there := await wait_until(func() -> bool:
		walk["ok"] = walk["ok"] and hero.grid_pos.distance_to(walk["last"]) < 1.0
		walk["last"] = hero.grid_pos
		return hero.at_home and hero.grid_pos.distance_to(Vector2(v1.center)) < 0.3, 90.0)
	check(there and walk["ok"] and ("defending %s" % v1.village_name) in hero.status(), "he walks to %s and stands guard there (%s)" % [v1.village_name, hero.status()])
	var own_mode := v1.hero.mode
	check(game.commands.submit(v1, "hero_mode", {"mode": Hero.Mode.REST})["ok"] and hero.mode == Hero.Mode.SUPPORT and v1.hero.mode == Hero.Mode.REST, "the supported village's orders go to its own hero, never to him")
	game.commands.submit(v1, "hero_mode", {"mode": own_mode})
	var g: Vector2i = v1.gates[0]
	var foe_at := Vector2(game.world.pathing.nearest_road(g + (g - v1.center).sign() * 3))
	game.waves._spawn({"kind": "goblin", "spawn": game.map.edge_spawns[0], "hp_scale": 1000.0, "village": v1})
	var foe: Enemy = _enemies().back()
	foe.speed = 0.0
	foe.set_grid_pos(foe_at)
	var xp0 := hero.xp
	var fights := await wait_until(func() -> bool: return hero.target == foe and hero.xp > xp0, 30.0)
	check(fights, "an enemy at %s's gate: he goes out and fights it, earning XP" % v1.village_name)
	foe.take_damage(1e9)
	hero.hp = hero.max_hp * 0.5
	var back := await wait_until(func() -> bool: return hero.at_home and hero.grid_pos.distance_to(Vector2(v1.center)) < 0.3, 60.0)
	var hp_b := hero.hp
	await wait_until(func() -> bool: return hero.hp > hp_b + 1.0, Config.HERO["rest_delay"] + 6.0)
	check(back and hero.hp > hp_b, "back at %s's centre he rests and heals there" % v1.village_name)
	hero.take_damage(1e9)
	game.waves.wave_finished.emit(game.waves.wave)
	await frames(3)
	check(not hero.dead and hero.mode == Hero.Mode.SUPPORT and hero.grid_pos.distance_to(Vector2(v0.center)) < 3.0, "downed, he revives at home, still in Support mode")
	var d0 := hero.grid_pos.distance_to(Vector2(v1.center))
	await wait_until(func() -> bool: return hero.grid_pos.distance_to(Vector2(v1.center)) < d0 - 3.0, 20.0)
	check(hero.grid_pos.distance_to(Vector2(v1.center)) < d0 - 3.0, "and heads back to %s" % v1.village_name)
	game.command("hero_mode", {"mode": Hero.Mode.DEFEND})
	var home := await wait_until(func() -> bool: return hero.at_home and hero.grid_pos.distance_to(Vector2(v0.center)) < 0.3, 90.0)
	check(home, "back in Defend mode he walks home")
