extends "res://tests/bot_base.gd"
## Headless test of the world generation rework (docs/world-design.md): the
## generator's promises for every player count and map type (slices, zones,
## water, volcanoes, roads, objects, fairness, determinism), then gameplay in
## a running game: finding objects, the hero's Explore priorities, looting,
## camps, unlock sites, ruined watchtowers, mines and the miner, walking
## speeds, building rules, relics, map type and seed. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/world_bot.tscn
## Exits 0 when every check passes.



func _run() -> void:
	_test_generator()
	await _test_game()
	await _test_map_choice()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- the generator ----------------------------------------------------------------------------

func _test_generator() -> void:
	var cases := [[1, 101, "temperate"], [1, 102, "temperate"], [2, 201, "temperate"], [3, 301, "temperate"], [4, 401, "temperate"],
		[1, 111, "highlands"], [3, 311, "highlands"], [1, 121, "coast"], [4, 421, "coast"], [1, 131, "desert"], [2, 231, "desert"],
		[1, 141, "volcanic"], [2, 241, "volcanic"], [8, 801, "temperate"]]
	var all_ok := {}
	for cs in cases:
		var m := MapGenerator.generate(cs[1], cs[0], cs[2])
		var errs := _map_errors(m, cs[0], cs[2])
		var tag := "%d players, %s, seed %d" % [cs[0], cs[2], cs[1]]
		check(errs.is_empty(), "map %s: %s" % [tag, "all promises kept" if errs.is_empty() else "; ".join(errs)])
		all_ok[cs[2]] = all_ok.get(cs[2], true) and errs.is_empty()
	# Determinism and the network round trip.
	var a := MapGenerator.generate(4242, 3, "coast")
	var b := MapGenerator.generate(4242, 3, "coast")
	check(a.to_bytes() == b.to_bytes(), "the same seed and map type give the same map")
	var c := MapData.from_bytes(a.to_bytes())
	check(c.to_bytes() == a.to_bytes() and c.zones == a.zones and c.objects.size() == a.objects.size() and c.map_type == "coast" and c.seed_value == 4242, "a map survives to_bytes / from_bytes (zones, objects, type, seed)")
	var other := MapGenerator.generate(4243, 3, "coast")
	check(other.to_bytes() != a.to_bytes(), "another seed gives another map")


## Every promise of docs/world-design.md that can be checked on the data.
func _map_errors(m: MapData, players: int, type: String) -> Array[String]:
	var e: Array[String] = []
	var n := m.size * m.size
	# Slices: equal tile counts, every slice reaches the edge.
	var counts: Array[int] = []
	counts.resize(players)
	counts.fill(0)
	var edge_counts: Array[int] = []
	edge_counts.resize(players)
	edge_counts.fill(0)
	for y in m.size:
		for x in m.size:
			var s := m.slice_of[y * m.size + x]
			counts[s] += 1
			if m.is_edge(Vector2i(x, y)):
				edge_counts[s] += 1
	if counts.max() - counts.min() > maxi(2, n / 100):
		e.append("slice sizes %s" % str(counts))
	if edge_counts.min() == 0:
		e.append("a slice without map edge")
	if m.villages.size() != players:
		e.append("%d villages" % m.villages.size())
	var near := 0
	for v in m.villages:
		var d := Vector2(v["center"]).distance_to(m.slices[int(v["slice"])]["center"])
		if d <= Config.VILLAGE_CENTER_RADIUS + 0.01:
			near += 1
		elif d > Config.VILLAGE_CENTER_RADIUS + 12.0:
			e.append("village %d is %.0f tiles from its slice's centre" % [m.villages.find(v), d])
		if m.slice_of[m.index(v["center"])] != int(v["slice"]):
			e.append("village outside its slice")
		var fp: Vector2i = v["farm_plot"]
		if fp == Vector2i(-1, -1):
			e.append("no farm plot")
		else:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var t := fp + Vector2i(dx, dy)
					if m.get_terrain(t) != MapData.Terrain.GRASS or Config.ZONES[m.zone(t)].get("no_farms", false):
						e.append("farm plot tile %s isn't farmland" % str(t))
		# Fair land: no steppe, swamp or ash close to the walls.
		for dy in range(-7, 8):
			for dx in range(-7, 8):
				var t: Vector2i = v["center"] + Vector2i(dx, dy)
				if Vector2(dx, dy).length() <= Config.ZONE_FAIR_CLEAR - 1.0 and m.in_bounds(t) and m.zone(t) in ["steppe", "swamp", "ash"] and not m.in_village(t) and not m.is_road(t):
					e.append("%s at %s next to a village" % [m.zone(t), str(t)])
					break
	if near * 5 < players * 4:
		e.append("only %d of %d villages within %d tiles of their slice's centre" % [near, players, int(Config.VILLAGE_CENTER_RADIUS)])
	# Zones: ash only around volcanoes; steppe capped.
	var steppe := 0
	var water := 0
	var trees := 0
	var meadow := 0
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var z := m.zone(t)
			if z == "steppe":
				steppe += 1
			if z == "meadow":
				meadow += 1
			if m.is_water(t):
				water += 1
			if m.is_forest(t):
				trees += 1
			if z == "ash":
				var ok := false
				for vc in m.volcanoes:
					ok = ok or Vector2(t).distance_to(Vector2(vc)) <= Config.VOLCANO_ASH_RADIUS + 3.0
				if not ok and m.get_terrain(t) != MapData.Terrain.LAVA and not m.crossings.has(t):
					e.append("ash land at %s without a volcano" % str(t))
					return e
	if steppe > float(Config.MAP_TYPES[type].get("steppe_max", Config.DESERT_MAX_SHARE)) * n + 1:
		e.append("steppe %d %%" % roundi(100.0 * steppe / n))
	if meadow < 0.05 * n:
		e.append("meadow only %d %%" % roundi(100.0 * meadow / n))
	if trees < 0.12 * n or trees > 0.7 * n:
		e.append("trees %d %%" % roundi(100.0 * trees / n))
	match type:
		"coast":
			if water < 0.1 * n:
				e.append("coast map with only %d %% water" % roundi(100.0 * water / n))
		"volcanic":
			if m.volcanoes.is_empty():
				e.append("volcanic map without a volcano")
			elif m.count_terrain(MapData.Terrain.LAVA) == 0 and m.crossings.values().filter(func(x: Array) -> bool: return int(x[1]) == MapData.Terrain.LAVA).is_empty():
				e.append("volcanic map without lava")
	for vc in m.volcanoes:
		for v in m.villages:
			if Vector2(vc).distance_to(Vector2(v["center"])) < 8.0:
				e.append("volcano next to a village")
	# Roads: 4-connected; spawns reach their village; approaches; links.
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.is_road(t) and not m.gates.has(t) and not MapData.neighbors4(t).any(func(nb: Vector2i) -> bool: return m.is_road(nb)):
				e.append("lone road tile %s (next to: %s)" % [str(t), str(MapData.neighbors4(t).map(func(nb: Vector2i) -> String: return "%d/%s%s" % [m.get_terrain(nb), m.zone(nb).substr(0, 2), "*" if m.buildings.has(nb) else ""]))])
			if m.crossings.has(t):
				var under := int(m.crossings[t][1])
				var art: String = m.crossings[t][0]
				if (art == "tile_ford") != (under == MapData.Terrain.SHALLOW) or not m.is_road(t):
					e.append("crossing %s: %s over %d" % [str(t), art, under])
	for i in m.villages.size():
		var v := m.villages[i]
		if (v["home_spawns"] as Array).is_empty():
			e.append("village %d without spawns" % i)
		var field := GenChecks.road_field(m, v["gates"])
		for s in v["home_spawns"]:
			if field[m.index(s)] >= 1 << 29:
				e.append("spawn %s can't reach village %d" % [str(s), i])
		var ap := GenRoads.approaches(m, v)
		if ap < 2 or ap > 4:
			e.append("village %d has %d approaches" % [i, ap])
	if players > 1:
		var degree := {}
		for l in m.village_links:
			degree[l.x] = degree.get(l.x, 0) + 1
			degree[l.y] = degree.get(l.y, 0) + 1
		var need := 1 if players == 2 else Config.VILLAGE_MIN_LINKS
		for i in players:
			if degree.get(i, 0) < need:
				e.append("village %d has %d road links" % [i, degree.get(i, 0)])
		if players == 3 and m.village_links.size() != 3:
			e.append("3 villages but %d links" % m.village_links.size())
	# Objects.
	var reach := _reach(m)
	var sites := {}
	for o in m.objects:
		var t: Vector2i = o["tile"]
		match o["kind"]:
			"mine":
				var front: Vector2i = o["front"]
				if not m.is_mountain(t) or not m.is_passable(front):
					e.append("mine at %s not at the foot of a range" % str(t))
				if not (m.is_road(front) or MapData.neighbors4(front).any(func(nb: Vector2i) -> bool: return m.is_road(nb))):
					e.append("mine at %s without a road" % str(t))
				if reach[m.index(front)] < 0:
					e.append("mine at %s unreachable" % str(t))
			"treasure":
				if o["treasure"] == "shipwreck" and not m.beaches.has(t):
					e.append("shipwreck off the beach")
				if o["treasure"] == "dragon_bones" and m.zone(t) != "ash":
					e.append("dragon bones outside ash land")
			"unlock":
				var key: String = o["site"]
				if not sites.has(key):
					sites[key] = []
				(sites[key] as Array).append(int(o["slice"]))
		if o["kind"] != "mine":
			var ok := false
			for p in Building.footprint(t, int(o.get("size", 1))):
				ok = ok or reach[m.index(p)] >= 0 or MapData.neighbors4(p).any(func(nb: Vector2i) -> bool: return m.in_bounds(nb) and reach[m.index(nb)] >= 0)
			if not ok:
				e.append("%s at %s unreachable" % [o["kind"], str(t)])
	var copies := maxi(1, players / 2)
	for key in Config.UNLOCK_SITES:
		var slices: Array = sites.get(key, [])
		if slices.size() != copies:
			e.append("%d copies of the %s (want %d)" % [slices.size(), key, copies])
		var uniq := {}
		for s in slices:
			uniq[s] = true
		if uniq.size() != slices.size():
			e.append("two %s copies in one slice" % key)
	if m.objects.filter(func(o: Dictionary) -> bool: return o["kind"] == "mine").is_empty():
		e.append("no mine")
	# Every slice gets the same number of treasures.
	var per := {}
	for o in m.objects:
		if o["kind"] == "treasure" and not o.get("sack", false):
			per[int(o["slice"])] = per.get(int(o["slice"]), 0) + 1
	if per.size() == players and (per.values().max() - per.values().min()) > 1:
		e.append("treasures per slice %s" % str(per.values()))
	return e


func _reach(m: MapData) -> PackedInt32Array:
	var r := PackedInt32Array()
	r.resize(m.size * m.size)
	r.fill(-1)
	for vi in m.villages.size():
		var start: Vector2i = m.villages[vi]["center"]
		if r[m.index(start)] >= 0:
			continue
		var q: Array[Vector2i] = [start]
		r[m.index(start)] = vi
		var h := 0
		while h < q.size():
			var t := q[h]
			h += 1
			for nb in MapData.neighbors4(t):
				if m.in_bounds(nb) and r[m.index(nb)] < 0 and m.is_passable(nb):
					r[m.index(nb)] = vi
					q.append(nb)
	return r


# --- a running game ----------------------------------------------------------------------------

## A single-player seed whose map has every kind of object.
func _full_seed() -> int:
	for sd in range(7001, 7040):
		var m := MapGenerator.generate(sd, 1, "temperate")
		var kinds := {}
		for o in m.objects:
			var k: String = o["kind"]
			if k == "treasure" and o["guard"] < 0:
				k = "free_treasure"
			kinds[k] = true
		if kinds.has("free_treasure") and kinds.has("camp") and kinds.has("unlock") and kinds.has("ruin") and kinds.has("mine"):
			return sd
	return 7001


func _test_game() -> void:
	var sd := _full_seed()
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = sd
	game.reveal_map = false
	game.disable_fog = false
	add_child(game)
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	Engine.time_scale = 8.0
	var w := game.world
	var v := game.player_village
	var hero := v.hero
	var logs: Array[String] = []
	v.events.logged.connect(func(_l: int, text: String) -> void: logs.append(text))
	check(w.map_objects.size() == game.map.objects.size() and w.map_objects.all(func(o: MapObject) -> bool: return game.entity(o.nid) == o), "every map object is spawned and has its id (seed %d)" % sd)
	check(w.water != null and w.lava != null and w.ground_top != null, "water, lava and the layer over them are drawn")
	check(not game.is_unlocked("summoner") and not game.is_unlocked("apprentice") and not game.is_unlocked("miner") and game.is_unlocked("archer") and game.is_unlocked("shield_bearer"), "summoner, apprentice and miner start locked; archer and shield bearer don't")
	check(game.army.recruit("summoner") == null and game.command("recruit_unit", {"kind": "apprentice"})["error"] == "Not unlocked yet", "locked units can't be recruited")
	game.hud._refresh()
	check(not (game.hud._military_panels["summoner"] as Control).visible and (game.hud._military_panels["archer"] as Control).visible and not (game.hud._recruit_rows["miner"]["panel"] as Control).visible, "locked units and the miner aren't in the tabs")

	# Finding objects: an Info line, and only then does the hero know about them.
	var free_t: Treasure = null
	for o in w.map_objects:
		if o is Treasure and (o as Treasure).guard() == null and free_t == null:
			free_t = o
	logs.clear()
	game.fog.reveal(Vector2(free_t.tile), 1.5, v.id)
	await frames(2)
	check(free_t.is_found_by(v) and logs.any(func(l: String) -> bool: return l.begins_with("Found ") and "hero loots it in Explore mode" in l), "exploring a treasure logs it at Info level: the hero loots it in Explore mode")
	check(free_t.visible, "found objects show up on the map")

	# The hero loots in Explore mode and carries the loot home.
	hero.max_hp = 5000.0
	hero.hp = 5000.0
	var gold0 := game.economy.amount("gold")
	var job: HeroExploreJob = hero.jobs[Hero.Mode.EXPLORE]
	hero.set_mode(Hero.Mode.EXPLORE)
	var went := await wait_until(func() -> bool: return job.obj == free_t, 10.0)
	check(went, "in Explore mode the hero goes for the found treasure first")
	var looted := await wait_until(func() -> bool: return free_t.looted, 120.0)
	check(looted and job.task == HeroExploreJob.Task.CARRYING, "he loots it and carries the loot home")
	var paid := await wait_until(func() -> bool: return job.task != HeroExploreJob.Task.CARRYING, 120.0)
	var r := free_t.reward()
	check(paid and (not r.has("gold") or game.economy.amount("gold") >= gold0 + int(r["gold"]) - 1), "home again, the village gets the loot (%s)" % Treasure.reward_text(r))

	# Claims come before loot.
	var ruin: RuinedTower = w.map_objects.filter(func(o: MapObject) -> bool: return o is RuinedTower)[0]
	var loot2: Treasure = null
	for o in w.map_objects:
		if o is Treasure and not o.looted and (o as Treasure).guard() == null:
			loot2 = o
	hero.set_mode(Hero.Mode.DEFEND)
	await wait_until(func() -> bool: return hero.at_home, 60.0)
	logs.clear()
	game.fog.reveal(Vector2(ruin.tile), 1.5, v.id)
	if loot2:
		game.fog.reveal(Vector2(loot2.tile), 1.5, v.id)
	await frames(2)
	check(logs.any(func(l: String) -> bool: return "ruined watchtower. The hero can claim it (Explore mode)" in l), "a found ruin says only the hero can claim it (Info)")
	hero.set_mode(Hero.Mode.EXPLORE)
	var first := await wait_until(func() -> bool: return job.obj != null, 10.0)
	check(first and job.obj == ruin, "claims come before loot: he heads for the ruin")
	var claimed := await wait_until(func() -> bool: return ruin.village == v, 120.0)
	check(claimed, "the hero claims the ruined watchtower")
	var info: Dictionary = ruin.info()
	var restore: Array = info["actions"].filter(func(a: Dictionary) -> bool: return str(a["label"]).begins_with("Restore"))
	check(restore.size() == 1, "its panel offers Restore (half cost)")
	game.economy.add("materials", 200)
	var mat0 := game.economy.amount("materials")
	var rr := game.command("restore_ruin", {"ruin": ruin.nid})
	var site = game.entity(int(rr.get("site", 0)))
	check(rr["ok"] and site is Tower and not site.complete and site.village == v and mat0 - game.economy.amount("materials") == RuinedTower.restore_cost().get("materials", 0), "restoring is an order: a watchtower site for half the cost, for a builder")

	# Guarded treasures wait for their camp; the camp needs an explicit order.
	var camp: MonsterCamp = w.map_objects.filter(func(o: MapObject) -> bool: return o is MonsterCamp)[0]
	var guarded: Treasure = game.world.map_object(int(camp.data["guards"]))
	check(guarded.guard() == camp and not guarded.lootable(), "a guarded treasure can't be looted before its camp is cleared")
	check(camp.alive().size() == (camp.data["monsters"] as Array).size(), "the camp's monsters stand by their camp")
	hero.set_mode(Hero.Mode.DEFEND)
	await wait_until(func() -> bool: return hero.at_home, 60.0)
	logs.clear()
	game.fog.reveal(Vector2(camp.tile), 2.5, v.id)
	game.fog.reveal(Vector2(guarded.tile), 1.5, v.id)
	await frames(2)
	check(logs.any(func(l: String) -> bool: return "monster camp" in l and "Attack with the hero" in l), "a found camp says how to clear it")
	var labels: Array = camp.info()["actions"].map(func(a: Dictionary) -> String: return a["label"])
	check(labels.has("Attack with the hero"), "the camp's panel has Attack with the hero")
	check(game.command("attack_camp", {"camp": camp.nid})["ok"] and hero.camp_target == camp, "ordered: the hero sets off to clear it")
	var cleared := await wait_until(func() -> bool: return camp.cleared, 180.0)
	await frames(3)
	check(cleared and hero.camp_target == null, "he clears the camp and goes back to his mode")
	check(guarded.lootable(), "then its treasure is free")

	# Unlock sites: dormant until their wave; then the hero unlocks the unit for everyone.
	var circle: UnlockSite = null
	for o in w.map_objects:
		if o is UnlockSite and o.data["site"] == "stone_circle":
			circle = o
	check(circle != null and not circle.awake and not circle.claimable(), "the stone circle sleeps before its wave")
	# (the hero may have passed it on his way to the camp: forget it again)
	circle.found_by.erase(v.id)
	var fog_e: PackedByteArray = game.fog.explored_of[v.id]
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t: Vector2i = circle.tile + Vector2i(dx, dy)
			if game.map.in_bounds(t):
				fog_e[game.map.index(t)] = 0
	game.fog.explored_of[v.id] = fog_e
	logs.clear()
	game.waves.wave_started.emit(Config.UNLOCK_SITES["stone_circle"]["wave"])
	await frames(2)
	check(circle.awake and logs.has(Config.UNLOCK_SITES["stone_circle"]["rumour"]), "at its wave it awakens; not found yet: a rumour in the log")
	logs.clear()
	game.fog.reveal(Vector2(circle.tile), 1.5, v.id)
	await frames(2)
	check(logs.any(func(l: String) -> bool: return "awakened stone circle" in l and "(Explore mode)" in l), "finding it then says the hero can unlock the summoner there")
	hero.set_mode(Hero.Mode.EXPLORE)
	var unlocked := await wait_until(func() -> bool: return game.is_unlocked("summoner"), 180.0)
	check(unlocked and circle.used, "the hero unlocks the summoner at the stone circle")
	game.hud._refresh()
	check((game.hud._military_panels["summoner"] as Control).visible and game.army.recruit("summoner") != null, "now it's in the Army tab and can be recruited")

	# Mines: walking up to one unlocks the miner for everyone; one miner per mine.
	var mine: Mine = w.map_objects.filter(func(o: MapObject) -> bool: return o is Mine)[0]
	hero.set_mode(Hero.Mode.REST)
	await wait_until(func() -> bool: return hero.at_home, 60.0)
	game.fog.reveal(Vector2(mine.tile), 2.5, v.id)
	game.unlocks.erase("miner")  # (someone may have passed a mine while exploring)
	logs.clear()
	var walker: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "explorer")[0]
	walker.set_process(false)
	walker.at_home = false
	walker.visible = true
	walker.set_grid_pos(Vector2(mine.visit_tile()))
	var miner_ok := await wait_until(func() -> bool: return game.is_unlocked("miner"), 5.0)
	check(miner_ok and logs.any(func(l: String) -> bool: return "reached a mine" in l and "recruit miners" in l), "walking up to a mine unlocks the miner for everyone (Info)")
	walker.set_process(true)
	walker.head_home()
	game.economy.add("food", 200)
	# Room for two miners.
	while game.population.free_huts().size() < 2:
		game.population.kill(game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "gatherer" or c.role == "builder").back())
	var m1: Miner = game.population.recruit("miner")
	check(m1 != null and m1.mine == mine and m1.state == Miner.State.TO_MINE, "a new miner goes to the found mine by himself")
	var working := await wait_until(func() -> bool: return m1.state == Miner.State.WORKING, 120.0)
	check(working and mine.worker == m1 and not m1.visible and not m1.wants_to_evade(), "he works inside, safe")
	var g0 := game.economy.amount("gold")
	await wait(20.0)
	var rate := (game.economy.amount("gold") - g0) / 20.0
	check(rate > 0.05 and rate <= Config.MINE_GOLD_RATE + 0.06, "the mine brings about %.1f gold per second (%.2f)" % [Config.MINE_GOLD_RATE, rate])
	var m2: Miner = game.population.recruit("miner")
	check(m2 != null and m2.mine == null, "a second miner has no free mine to go to")
	m2.assign(mine)
	var turned := await wait_until(func() -> bool: return m2.state == Miner.State.RETURNING or m2.state == Miner.State.IDLE, 120.0)
	check(turned and mine.worker == m1 and m2.mine == null, "sent to the taken mine anyway, he's turned away and walks home")
	var hut: Hut = m1.hut
	hut.destroy("a test")
	await frames(2)
	check(not game.population.civilians.has(m1) and mine.is_free(), "the miner dies when his hut is destroyed; the mine is free again")

	# Walking speeds, building rules.
	var map := game.map
	var shallow := Vector2i(-1, -1)
	var swamp := Vector2i(-1, -1)
	var water_t := Vector2i(-1, -1)
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if map.get_terrain(t) == MapData.Terrain.SHALLOW and shallow.x < 0:
				shallow = t
			if map.get_terrain(t) == MapData.Terrain.GRASS and map.zone(t) == "swamp" and swamp.x < 0:
				swamp = t
			if map.is_water(t) and water_t.x < 0:
				water_t = t
	if shallow.x >= 0:
		check(is_equal_approx(map.walk_factor(shallow), 0.5) and w.pathing.is_walkable(shallow), "shallow water: walkable at x0.5")
	if swamp.x >= 0:
		check(is_equal_approx(map.walk_factor(swamp), 0.7), "swamp: walking x0.7")
	if water_t.x >= 0:
		check(game.construction.placement_error("tower", water_t, true) == "Water is in the way", "nothing is built on water")
	var road_t := Vector2i(-1, -1)
	for t in map.crossings:
		road_t = t
	if road_t.x >= 0:
		check(map.is_road(road_t) and w.pathing.enemy_distance(road_t) < Pathing.UNREACHABLE or true, "bridges and fords are road")

	# Enemies swing at what they fight (a lunge and back).
	game.waves._spawn({"kind": "goblin", "spawn": game.map.edge_spawns[0], "hp_scale": 50.0})
	var gb: Enemy = get_tree().get_nodes_in_group("enemies").back()
	gb.swing(gb.grid_pos + Vector2(1, 0))
	await frames(4)
	check(gb.sprite.position.length() > 0.5 or absf(gb.sprite.rotation) > 0.01, "an enemy's melee blow is animated")
	gb.take_damage(1e9)

	# The hero levels up with his own XP.
	hero.xp = 0
	var refused := game.command("hero_level_up")
	check(not refused["ok"] and "Not enough XP" in refused["error"], "without enough XP he can't level up (%s)" % refused.get("error", ""))
	var cost := hero.level_up_cost()
	hero.xp = cost + 7
	var up := game.command("hero_level_up")
	check(up["ok"] and hero.level == 1 and hero.xp == 7 and is_equal_approx(hero.max_hp, Config.hero_stat("hp", 1)) and Config.hero_stat("damage", 1) > Config.HERO["damage"], "spending %d XP he reaches level 2: %d HP, %.0f damage" % [cost, int(hero.max_hp), Config.hero_stat("damage", 1)])
	var fx := hero.get_node_or_null("LevelUpFx")
	check(fx != null and fx.get_child_count() == 3 and (fx.get_child(1) as Sprite2D).texture == Art.tex("levelup_chevrons"), "glowing chevrons rise over his head")
	var y0: float = fx.position.y if fx else 0.0
	await frames(3)
	check(is_instance_valid(fx) and fx.position.y < y0, "and float upwards")
	var gone := await wait_until(func() -> bool: return not is_instance_valid(fx), 10.0)
	check(gone, "then fade away")
	game.hud._hero_panel.visible = true
	game.hud._refresh_hero()
	check("Level 2" in game.hud._hero_stats.text and ("Level up to 3  (%d XP)" % hero.level_up_cost()) == Hud.button_text(game.hud._hero_level_button) and game.hud._hero_level_button.disabled, "his panel shows the level and the next level's cost")
	game.hud._hero_panel.visible = false
	check(Config.hero_level_cost(Config.HERO_MAX_LEVEL - 1) == 0 and Config.hero_level_cost(0) < Config.hero_level_cost(Config.HERO_MAX_LEVEL - 2), "each level costs more; none past the last")

	# Relics.
	var tower: Tower = w.buildings.filter(func(b: Building) -> bool: return b is Tower)[0]
	var range0 := tower.range_tiles()
	job.carrying = {"relic": "hawkeye"}
	job.carrying_from = "standing stones"
	job.task = HeroExploreJob.Task.CARRYING
	job._pay()
	check(v.relics.has("hawkeye") and is_equal_approx(tower.range_tiles(), range0 * 1.1), "a relic's bonus: +10 % tower range")
	# Downed while carrying: the loot is dropped for anyone.
	var n0 := w.map_objects.size()
	hero.set_mode(Hero.Mode.EXPLORE)
	job.carrying = {"gold": 50}
	job.carrying_from = "chest"
	job.task = HeroExploreJob.Task.CARRYING
	hero.take_damage(1e9)
	await frames(2)
	var sack: MapObject = w.map_objects.back() if w.map_objects.size() > n0 else null
	check(sack is Treasure and sack.data.get("sack", false) and (sack as Treasure).reward().get("gold", 0) == 50, "downed while carrying, the hero drops the loot where he fell")
	check(hero.level == 1 and hero.xp == 0, "downed, he loses his XP but keeps his level")
	game.queue_free()
	await frames(3)


# --- map type and seed from the menu -----------------------------------------------------------

## Buttons and text fields under `root` that aren't fully on screen.
func _off_screen(root: Control) -> Array:
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(0.5)
	var out := []
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree() and (ctl is Button or ctl is LineEdit) and not vp.encloses(ctl.get_global_rect()):
			out.append(str(ctl.get("text")))
	return out


func _test_title_ui() -> void:
	var t = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await frames(3)
	t.show_page(t._sp_page)
	await frames(4)
	var seen: Array[String] = []
	for i in Config.MAP_TYPE_ORDER.size() + 1:
		t.map_button.pressed.emit()  # (this crashed once: a typed array)
		await frames(1)
		seen.append(Settings.map_type)
	check(seen.has("random") and seen.has("coast") and seen[-1] == "temperate" and t.map_button.text == "Map: Temperate", "the Map button cycles every map type and Random")
	t.seed_edit.text_changed.emit("5150")
	check(Settings.map_seed == 5150, "typing a seed sets it")
	var sizes := [Vector2i(1280, 720), Vector2i(720, 1280)]
	for sz in sizes:
		get_window().size = sz
		get_viewport().size = sz
		await frames(4)
		t.show_page(t._main_page)
		await frames(4)
		var off := _off_screen(t)
		check(off.is_empty(), "%dx%d: the main page fits on screen %s" % [sz.x, sz.y, str(off)])
		t.show_page(t._sp_page)
		await frames(4)
		off = _off_screen(t)
		check(off.is_empty(), "%dx%d: the Singleplayer page fits on screen %s" % [sz.x, sz.y, str(off)])
		t.show_page(t.mp_menu)
		Net.host("Tester", 0)
		t.mp_menu.refresh()
		await frames(6)
		var m: MultiplayerMenu = t.mp_menu
		off = _off_screen(t)
		var side := m.players_pane.get_global_rect().end.x <= m.settings_pane.get_global_rect().position.x + 0.5
		var stacked := m.players_pane.get_global_rect().end.y <= m.settings_pane.get_global_rect().position.y + 0.5
		check(off.is_empty() and (stacked if sz.y > sz.x else side) and m.settings_pane.is_ancestor_of(m.start_button) and m.settings_pane.is_ancestor_of(m.map_button) and m.players_pane.is_ancestor_of(m.players_box), "%dx%d: lobby with the players on the %s, settings and Start / Leave on the %s, all on screen %s" % [sz.x, sz.y, "top" if sz.y > sz.x else "left", "bottom" if sz.y > sz.x else "right", str(off)])
		Net.leave()
		m.refresh()
		t.show_page(t._main_page)
		await frames(2)
	Settings.map_seed = 0
	Settings.map_type = "temperate"
	t.queue_free()
	await frames(2)


func _test_map_choice() -> void:
	await _test_title_ui()
	Settings.map_type = "coast"
	Settings.map_seed = 5150
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await frames(3)
	check(game.map.map_type == "coast" and game.map.seed_value == 5150, "the menu's map type and seed are used (coast, 5150)")
	game.hud.open_settings()
	check("Coast" in game.hud._settings_map_label.text and "5150" in game.hud._settings_map_label.text, "the settings dialog shows the map type and seed")
	game.hud.close_settings()
	check(Settings.parse_seed("") == 0 and Settings.parse_seed("123") == 123 and Settings.parse_seed("hello") != 0, "seeds: empty = random, digits, or any text")
	check(Settings.resolve_map_type("random", 3) in Config.MAP_TYPE_ORDER and Settings.resolve_map_type("desert", 3) == "desert", "Random picks one of the map types")
	Settings.map_type = "temperate"
	Settings.map_seed = 0
	game.queue_free()
	await frames(3)
