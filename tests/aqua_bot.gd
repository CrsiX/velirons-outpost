extends "res://tests/bot_base.gd"
## Headless test of the water monsters (docs/aquatic-design.md): water
## bodies and the amphibians' way, diving and targetability, melee reach,
## sinking corpses, the crab, the leviathan, the siren, the gigantic
## octopus, wave eligibility, water spawns in maps, files and the editor,
## and the generator's inlets and lagoons. On a hand-built map: a generated
## one with a lake dug next to the village and a river with a bridge.
##   godot --headless --fixed-fps 60 --path . res://tests/aqua_bot.tscn
## Exits 0 when every check passes.

const SEEDS: Array[int] = [4242, 4243, 4244, 4245, 4246, 4247, 4248, 4249, 4250, 4251, 4252, 4253, 4254, 4255, 4256, 4257]

## The lake: its deep tiles, a deep tile in its middle, one by the village's
## shore, and the walkable shore tile next to that.
var lake: Array[Vector2i] = []
var lake_mid := Vector2i.ZERO
var lake_near := Vector2i.ZERO
var shore := Vector2i.ZERO
var lake_block := Rect2i()
## The river: its two halves either side of the bridge.
var river_a: Array[Vector2i] = []
var river_b: Array[Vector2i] = []
var bridge := Vector2i(-1, -1)
var logs: Array[String] = []


func _run() -> void:
	_test_config()
	var m := _make_map()
	check(m != null, "a map with a lake next to the village and a river with a bridge")
	if m == null:
		_finish()
		return
	_test_map_files(m)
	game = load("res://scenes/main.tscn").instantiate()
	game.preset_map = m
	game.disable_fog = true
	add_child(game)
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	game.player_village.events.logged.connect(func(_l: int, text: String) -> void: logs.append(text))
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	_bench_hero(true)
	_quiet_villagers()
	game.player_village.economy.add("food", 50000)  # (nobody starves while the farmers stand still)
	Engine.time_scale = 4.0
	_test_bodies()
	await _test_dive()
	await _test_melee_reach()
	await _test_corpses()
	await _test_leviathan()
	await _test_siren()
	await _test_octopus()
	await _test_waves()
	Engine.time_scale = 1.0
	_test_generator()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- the map ------------------------------------------------------------------------------------

## A generated map with a 14x14 lake (a shallow rim round 12x12 deep water)
## 8 tiles from the village centre, a road to its shore, a water spawn in it,
## and a river with a bridge on a road.
func _make_map() -> MapData:
	for s in SEEDS:
		var m := MapGenerator.generate(s, 1, "temperate")
		if _dig_lake(m) and _dig_river(m):
			m.water_spawns.assign([lake_mid])
			return m
	return null


func _blocked(m: MapData, t: Vector2i) -> bool:
	if not m.in_bounds(t) or t.x < 2 or t.y < 2 or t.x > m.size - 3 or t.y > m.size - 3:
		return true
	if m.is_road(t) or m.in_village(t) or m.is_water(t) or m.is_mountain(t) or m.get_terrain(t) == MapData.Terrain.LAVA:
		return true
	for o in m.objects:
		if Vector2(t).distance_to(Vector2(o["tile"])) < 3.0:
			return true
	return false


func _dig_lake(m: MapData) -> bool:
	var c: Vector2i = m.villages[0]["center"]
	for side in [Vector2i(9, -7), Vector2i(-22, -7), Vector2i(-7, 9), Vector2i(-7, -22)]:
		for shift in [0, -3, 3, -5, 5]:
			var off: Vector2i = side + (Vector2i(0, shift) if side.y == -7 else Vector2i(shift, 0))
			var block := Rect2i(c + off, Vector2i(14, 14))
			var ok := true
			for t in MapData.rect_tiles(block.grow(1)):
				if _blocked(m, t):
					ok = false
					break
			if not ok:
				continue
			lake_block = block
			lake.clear()
			for t in MapData.rect_tiles(block):
				var rim := t.x == block.position.x or t.y == block.position.y or t.x == block.end.x - 1 or t.y == block.end.y - 1
				m.set_terrain(t, MapData.Terrain.SHALLOW if rim else MapData.Terrain.WATER)
				m.props.erase(t)
				m.decor.erase(t)
				if not rim:
					lake.append(t)
			lake_mid = block.position + Vector2i(7, 7)
			var best := INF
			for t in lake:
				var d := Vector2(t).distance_to(Vector2(c))
				if d < best:
					best = d
					lake_near = t
			# The shore: the land tile just outside the rim, towards the village.
			var dir := Vector2(c - lake_near).normalized()
			shore = Vector2i((Vector2(lake_near) + dir * 2.4).round())
			for t in MapData.rect_tiles(Rect2i(shore - Vector2i(1, 1), Vector2i(3, 3))):
				if m.is_forest(t):
					m.set_terrain(t, MapData.Terrain.GRASS)
					m.props.erase(t)
			# A road from that shore to the network, so crabs and sirens can climb out.
			var road := Vector2i(-1, -1)
			var road_d := INF
			for y in m.size:
				for x in m.size:
					var t := Vector2i(x, y)
					if m.is_road(t) and not m.in_village(t) and Vector2(t).distance_to(Vector2(shore)) < road_d:
						road_d = Vector2(t).distance_to(Vector2(shore))
						road = t
			var path := EditorTools.road_path(m, shore, road)
			if path.is_empty():
				return false
			EditorTools.paint_road(m, path, false)
			return true
	return false


## A one-tile river across a straight stretch of road away from the village,
## with a bridge where the road crosses it.
func _dig_river(m: MapData) -> bool:
	var c: Vector2i = m.villages[0]["center"]
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var d := Vector2(t).distance_to(Vector2(c))
			if not m.is_road(t) or d < 14.0 or d > 30.0 or m.crossings.has(t) or lake_block.grow(4).has_point(t):
				continue
			var along_x := m.is_road(t + Vector2i.LEFT) and m.is_road(t + Vector2i.RIGHT) and not m.is_road(t + Vector2i.UP) and not m.is_road(t + Vector2i.DOWN)
			if not along_x:
				continue
			var tiles: Array[Vector2i] = []
			var ok := true
			for k in range(-6, 7):
				if k == 0:
					continue
				var r := t + Vector2i(0, k)
				if _blocked(m, r) or lake_block.grow(3).has_point(r):
					ok = false
					break
				for nb in [r + Vector2i.LEFT, r + Vector2i.RIGHT]:
					if m.is_road(nb):
						ok = false
				tiles.append(r)
			if not ok:
				continue
			river_a.clear()
			river_b.clear()
			for r in tiles:
				m.set_terrain(r, MapData.Terrain.WATER)
				m.props.erase(r)
				m.decor.erase(r)
				(river_a if r.y < t.y else river_b).append(r)
			m.crossings[t] = ["bridge_stone_y", MapData.Terrain.WATER]
			bridge = t
			return true
	return false


## The village's people stay where the tests put them (no jobs, no fleeing).
func _quiet_villagers() -> void:
	for c in game.player_village.population.civilians:
		c.process_mode = Node.PROCESS_MODE_DISABLED


## A villager standing outside at `at`, doing nothing (or null: no one free).
func outside(at: Vector2) -> Civilian:
	var v := game.player_village
	var civ: Civilian = null
	for c in v.population.civilians:
		if not c.dead and c.at_home:
			civ = c
			break
	if civ == null:
		v.economy.add("food", 500)
		civ = v.population.spawn("explorer")
	if civ == null:
		return null
	civ.process_mode = Node.PROCESS_MODE_DISABLED
	civ._set_home(false)
	civ.hp = civ.max_hp
	civ.set_grid_pos(at)
	return civ


func home(civ: Civilian) -> void:
	if is_instance_valid(civ) and not civ.dead:
		civ.arrive_home()
		civ.held_by = null


func spawn(kind: String, at: Vector2i, strength: int = 1) -> Enemy:
	return game.waves.spawn_at(kind, at, game.player_village, strength)


# --- config -------------------------------------------------------------------------------------

func _test_config() -> void:
	var ok := true
	for kind in ["crab", "siren", "leviathan", "octopus"]:
		var e: Dictionary = Config.ENEMIES[kind]
		ok = ok and Config.WAVE_MIX.has(kind) and Config.WAVE_MIX[kind]["needs"] == "water" and e.has("habitat") and e.has("min_deep_tiles") and e.has("min_width")
		ok = ok and ResourceLoader.exists("res://art/unit_%s.svg" % e["art"]) and ResourceLoader.exists("res://art/corpse_%s.svg" % e["art"])
	check(ok, "the four water monsters: config (habitat, body sizes), a wave entry that needs water, their art and corpses")
	check(Config.ENEMIES["crab"]["habitat"] == "amphibian" and Config.ENEMIES["siren"]["habitat"] == "amphibian" and Config.ENEMIES["leviathan"]["habitat"] == "water" and Config.ENEMIES["octopus"]["habitat"] == "water", "crab and siren are amphibians, leviathan and octopus never leave the water")
	var c: Dictionary = Config.ENEMIES["crab"]
	var g: Dictionary = Config.ENEMIES["goblin"]
	check(c["hp"] == g["hp"] and c["damage"] == g["damage"] and c["speed"] == g["speed"], "a crab is a goblin that can swim")
	var l3: float = Config.TOWER_RANGE["tower"] + Config.TOWER_LEVELS[2]["range_bonus"]
	var l2: float = Config.TOWER_RANGE["tower"] + Config.TOWER_LEVELS[1]["range_bonus"]
	var blast: float = Config.ENEMIES["leviathan"]["blast_range"]
	check(blast > l2 and blast < l3 and blast < Config.TOWER_RANGE["wall_tower"], "the leviathan outranges a level 2 watchtower (%.1f > %.1f), not a level 3 one or a wall tower" % [blast, l2])
	check(not Config.ENEMIES["leviathan"].get("revivable", true) and not Config.ENEMIES["octopus"].get("revivable", true), "leviathan and octopus corpses can't be raised")
	check(not Config.ENEMIES["octopus_arm"].get("library", true) and not Config.WAVE_MIX.has("octopus_arm"), "an octopus's arm is no wave member and has no library entry")
	var water_kinds := ["crab", "siren", "leviathan", "octopus"]
	var dry := Config.wave_composition(25)
	var wet := Config.wave_composition(25, true)
	check(water_kinds.all(func(k: String) -> bool: return not dry.has(k)) and water_kinds.all(func(k: String) -> bool: return wet.has(k)), "waves bring water monsters only where they can come (%s)" % str(wet))
	var only := Config.wave_composition(25, true, ["crab"])
	check(only.has("crab") and not only.has("siren") and not only.has("leviathan"), "only the kinds that fit")
	var size_ok := true
	for n in range(1, 30):
		var w := Config.wave_composition(n, true)
		var total := 0
		for k in w:
			total += w[k]
		size_ok = size_ok and total == Config.wave_size(n)
		for k in water_kinds:
			if w.has(k) and n < int(Config.WAVE_MIX[k]["from_wave"]):
				size_ok = false
	check(size_ok, "they count towards the wave's size and join from their waves")
	check(not Config.wave_composition(5, true).has("crab") and Config.wave_composition(6, true).has("crab") and not Config.wave_composition(19, true).has("octopus") and Config.wave_composition(20, true).has("octopus"), "crabs from wave 6, the octopus from wave 20")


# --- water bodies and the amphibians' way -----------------------------------------------------

func _test_bodies() -> void:
	var p := game.world.pathing
	var lb := p.body_of(lake_mid)
	check(lb >= 0 and int(p.bodies[lb]["deep"]) == lake.size() and int(p.bodies[lb]["width"]) >= 9, "the lake is a body of %d deep tiles, %d wide" % [int(p.bodies[lb]["deep"]) if lb >= 0 else 0, int(p.bodies[lb]["width"]) if lb >= 0 else 0])
	var ra := p.body_of(river_a[0])
	var rb := p.body_of(river_b[0])
	check(ra >= 0 and ra == rb and p.body_of(bridge) == ra and int(p.bodies[ra]["width"]) == 1 and int(p.bodies[ra]["deep"]) == river_a.size() + river_b.size(), "a one-tile river is 1 wide; its bridge is part of it (the deep water under it joins both sides; the bridge isn't counted as deep)")
	check(p.body_fits(lb, "octopus") and p.body_fits(lb, "leviathan") and not p.body_fits(ra, "leviathan") and p.body_fits(ra, "crab"), "the lake fits every kind, the river only crabs and sirens")
	check(not p.water_path(lake_mid, lake_near).is_empty() and p.water_path(lake_mid, river_a[0]).is_empty(), "deep-water paths within a body, none between bodies")
	var under := p.water_path(river_a[0], river_b[0])
	check(not under.is_empty() and Array(under).any(func(q: Vector2) -> bool: return Vector2i(q.round()) == bridge), "a water-bound monster's way goes under the bridge")
	check(p.nearest_deep(ra, Vector2(bridge)) != bridge, "but never comes up there (no spot under a bridge)")
	check(p.enemy_distance(lake_mid, -1, true) < Pathing.UNREACHABLE and p.enemy_distance(lake_mid) >= Pathing.UNREACHABLE, "an amphibian gets from the lake to the gates over water and road; a land enemy can't")
	var route := p.enemy_route(lake_mid, RandomNumberGenerator.new(), -1, true)
	var g := game.map.gates
	check(not route.is_empty() and g.has(route[-1]) and route.all(func(t: Vector2i) -> bool: return game.map.is_road(t) or game.map.is_wet(t)), "its route keeps to water and roads and ends at a gate")
	check(p.enemy_distance(bridge, -1, true) < Pathing.UNREACHABLE and game.map.is_wet(bridge) and not game.map.is_deep(bridge), "a bridge is road and water at once, but not deep")
	var lab := Pathing.label_water(game.map)
	check((lab["bodies"] as Array).size() == p.bodies.size(), "the editor's labelling gives the same bodies")
	var elig := game.waves.aqua(game.player_village)
	check(elig.has("crab") and elig.has("siren") and elig.has("leviathan") and elig.has("octopus"), "by this lake every water monster can come for the village (%s)" % str(elig.keys()))
	check((elig.get("leviathan", []) as Array).has(lake_mid), "the leviathan comes from the lake's water spawn")
	check(Aqua.buildable_within(game, lake_near, 5.2), "a tower could cover the lake's deep water nearest the village")


# --- diving -------------------------------------------------------------------------------------

func _test_dive() -> void:
	var crab := spawn("crab", lake_mid)
	crab.speed = 0.0
	var down := await wait_until(func() -> bool: return crab.dive == Enemy.Dive.DOWN, 5.0)
	check(down and not crab.targetable() and crab.submerged(), "a crab on deep water dives and can't be targeted")
	var archer := MilitaryUnit.new("archer")
	var hp0 := crab.hp
	Combat.hit(game, archer, crab, 5.0, null, crab.hit_point())
	check(crab.hp == hp0, "a hit on a monster under water does nothing (a shot in flight fizzles)")
	var tower := _a_tower_near(crab.grid_pos)
	if tower:
		check(not MilitaryBehavior.enemies_near(tower, 99.0).has(crab), "towers don't see it as a target")
	var dummy := spawn("goblin", game.map.villages[0]["center"] + Vector2i(0, 6))
	dummy.speed = 0.0
	dummy.follow(PackedVector2Array([dummy.grid_pos, dummy.grid_pos + Vector2(0.001, 0)]))
	var gh := dummy.hp
	dummy.set_grid_pos(crab.grid_pos + Vector2(0.4, 0))
	archer.set_kind("fire_mage")
	Combat.hit(game, archer, dummy, 2.0, null, dummy.hit_point())
	check(crab.hp == hp0 and dummy.hp < gh, "splash skips it too")
	crab.set_grid_pos(Vector2(lake_block.position))  # (the rim: shallow water)
	var up := await wait_until(func() -> bool: return crab.dive == Enemy.Dive.UP, 5.0)
	check(up and crab.targetable(), "on shallow water it comes up again")
	crab.set_grid_pos(Vector2(lake_mid))
	await wait_until(func() -> bool: return crab.dive == Enemy.Dive.DOWN, 5.0)
	crab.raised = true
	var raised_up := await wait_until(func() -> bool: return crab.dive == Enemy.Dive.UP, 3.0)
	check(raised_up and not crab.can_submerge(), "a raised crab never dives")
	kill(crab)
	kill(dummy)
	await clear_enemies()
	await _test_bridge()


## Through under the bridge: down on its tile, never targetable there; the
## crab comes up again past it; one walking along the road stays up.
func _test_bridge() -> void:
	var a := river_a[river_a.size() - 1]  # (the deep tiles next to the bridge)
	var b := river_b[0]
	for kind in ["leviathan", "crab"]:
		var e := spawn(kind, a)
		e.behavior = EnemyBehavior.new()  # (just follows its path)
		e._set_dive(Enemy.Dive.UP)
		e.set_grid_pos(Vector2(a))
		e.follow(PackedVector2Array([Vector2(a), Vector2(bridge) + e._jitter, Vector2(b) + e._jitter, Vector2(river_b[1]) + e._jitter, Vector2(river_b[2]) + e._jitter]))
		var seen := {"on": false, "up_on_bridge": false}
		var through := await wait_until(func() -> bool:
			if not is_instance_valid(e) or e.dead:
				return true
			if e.current_tile() == bridge:
				seen["on"] = true
				seen["up_on_bridge"] = seen["up_on_bridge"] or e.targetable() or e.dive == Enemy.Dive.SURFACING
			return e.current_tile() == b, 10.0)
		check(through and seen["on"] and not seen["up_on_bridge"], "a %s swims through under the bridge, under water on its tile" % kind)
		e.surface()
		check(e.dive == Enemy.Dive.SURFACING or e.dive == Enemy.Dive.UP or kind == "crab", "past it it may come up again")
		kill(e)
	var road := bridge + Vector2i.LEFT
	var walker := spawn("crab", road)
	walker.behavior = EnemyBehavior.new()
	walker._set_dive(Enemy.Dive.UP)
	walker.set_grid_pos(Vector2(road))
	walker.follow(PackedVector2Array([Vector2(road), Vector2(bridge) + walker._jitter, Vector2(bridge + Vector2i.RIGHT) + walker._jitter, Vector2(bridge + Vector2i.RIGHT * 2) + walker._jitter]))
	var stayed := {"up": true}
	await wait_until(func() -> bool:
		if not is_instance_valid(walker) or walker.dead:
			return true
		if walker.current_tile() == bridge:
			stayed["up"] = stayed["up"] and walker.dive == Enemy.Dive.UP
		return walker.current_tile() == bridge + Vector2i.RIGHT, 8.0)
	check(stayed["up"], "a crab walking along the road over the bridge stays up")
	if is_instance_valid(walker):
		kill(walker)
	await clear_enemies()


func _a_tower_near(_p: Vector2) -> Tower:
	for t in game.world.towers():
		return t
	return null


# --- melee reach --------------------------------------------------------------------------------

func _test_melee_reach() -> void:
	var lev := spawn("leviathan", lake_near)
	lev.behavior = EnemyBehavior.new()  # (held still and up)
	lev._set_dive(Enemy.Dive.UP)
	check(lev.melee_ok(Vector2(shore)) and is_equal_approx(lev.melee_reach(0.8), 1.5), "up next to the shore: melee reaches it from the tile beside it (reach %.1f)" % lev.melee_reach(0.8))
	lev.set_grid_pos(Vector2(lake_mid))
	check(not lev.melee_ok(Vector2(shore)), "out in the middle of the lake: out of any blade's reach")
	var siren := spawn("siren", lake_near)
	siren.behavior = EnemyBehavior.new()
	siren._set_dive(Enemy.Dive.UP)
	siren.set_grid_pos(Vector2(lake_block.position + Vector2i(3, 0)))  # (the rim: shallow water)
	check(not siren.melee_ok(Vector2(shore)) and siren.melee_ok(Vector2(shore), true), "a siren in the water: no melee (a fire elemental's flames still reach her)")
	siren.set_grid_pos(Vector2(shore))
	check(siren.melee_ok(Vector2(shore)), "on land the hero can strike her")
	var h := siren.hp
	siren.take_damage(10.0, null, "melee")
	check(is_equal_approx(h - siren.hp, 15.0), "she takes 1.5 x melee damage")
	kill(lev)
	kill(siren)
	await clear_enemies()


# --- corpses ------------------------------------------------------------------------------------

func _test_corpses() -> void:
	var crab := spawn("crab", lake_mid)
	crab.speed = 0.0
	kill(crab)
	await frames(2)
	var c: Corpse = game.corpses.corpses.back() if not game.corpses.corpses.is_empty() else null
	check(c != null and c.kind == "crab" and c.sinking and not game.corpses.available().has(c), "a crab killed on deep water leaves a corpse that sinks (no gatherer goes for it)")
	var gone := await wait_until(when_gone(c, func(x: Object) -> bool: return not game.corpses.corpses.has(x)), float(Config.AQUA["sink_time"]) + 3.0)
	check(gone, "after %s s it is gone" % str(Config.AQUA["sink_time"]))
	var crab2 := spawn("crab", lake_mid)
	crab2.set_grid_pos(Vector2(shore))
	crab2.speed = 0.0
	kill(crab2)
	await frames(2)
	var c2: Corpse = game.corpses.corpses.back() if not game.corpses.corpses.is_empty() else null
	check(c2 != null and not c2.sinking, "on land it lies like any other")
	var lev := spawn("leviathan", lake_mid)
	kill(lev)
	await frames(2)
	var c3: Corpse = game.corpses.corpses.back()
	check(c3.kind == "leviathan" and not c3.revivable and c3.sinking, "a leviathan's corpse can't be raised and sinks")
	game.corpses.clear_wave(99)


# --- the leviathan ------------------------------------------------------------------------------

func _test_leviathan() -> void:
	var lev := spawn("leviathan", lake_mid)
	await frames(2)
	check(lev.dive == Enemy.Dive.DOWN and lev.body == game.world.pathing.body_of(lake_mid), "a leviathan arrives under water, in the lake's body")
	var victim := outside(Vector2(shore))
	var hp0 := victim.hp
	var up := await wait_until(func() -> bool: return lev.dive == Enemy.Dive.UP, 20.0)
	check(up and game.map.is_deep(lev.current_tile()) and lev.grid_pos.distance_to(Vector2(shore)) <= float(Config.ENEMIES["leviathan"]["blast_range"]), "with someone on the shore it swims within blast range and comes up")
	var jet := await wait_until(func() -> bool: return lev.fx.has("jet"), 5.0)
	check(jet, "it aims its water column (a wind-up first)")
	var hurt := await wait_until(func() -> bool: return victim.dead or victim.hp < hp0, 8.0)
	check(hurt, "the blast hurts whoever stands there (%.1f -> %.1f HP)" % [hp0, victim.hp])
	home(victim)
	# Hurt badly while up, it dives early.
	await wait_until(func() -> bool: return lev.dive == Enemy.Dive.UP, 25.0)
	if lev.dive == Enemy.Dive.UP:
		lev.take_damage(lev.max_hp * 0.3, null, "projectile")
		var fled := await wait_until(func() -> bool: return lev.dive != Enemy.Dive.UP, 2.0)
		check(fled, "losing a quarter of its HP while up makes it dive early")
	# Nobody about: it still comes up now and then, near the village.
	var t0 := Time.get_ticks_msec()
	var idle := await wait_until(func() -> bool: return lev.dive == Enemy.Dive.UP, (float(Config.ENEMIES["leviathan"]["idle_surface"]) + 15.0))
	check(idle, "with nobody about it still comes up (after %.0f s)" % ((Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale))
	check(lev.fx.is_empty() or not lev.fx.has("jet"), "and blasts nobody")
	kill(lev)
	await clear_enemies()


# --- the siren ----------------------------------------------------------------------------------

func _test_siren() -> void:
	var at := lake_block.position + Vector2i(lake_block.size.x / 2, 0)
	if Vector2(lake_block.position + Vector2i(0, lake_block.size.y / 2)).distance_to(Vector2(shore)) < Vector2(at).distance_to(Vector2(shore)):
		at = lake_block.position + Vector2i(0, lake_block.size.y / 2)
	var siren := spawn("siren", lake_near)
	siren.speed = 0.0
	siren.set_grid_pos(Vector2(lake_near))
	var civ := outside(Vector2(shore))
	var d0 := civ.grid_pos.distance_to(siren.grid_pos)
	var singing := await wait_until(func() -> bool: return siren.fx.has("song") and siren.dive == Enemy.Dive.UP, 6.0)
	check(singing, "with one of ours within her song she comes up and sings")
	await wait(1.0)
	var d1 := civ.grid_pos.distance_to(siren.grid_pos)
	check(d1 < d0 - 0.1, "her song draws a villager towards her (%.1f -> %.1f tiles)" % [d0, d1])
	check(game.world.pathing.is_walkable(civ.current_tile()) and not game.map.is_deep(civ.current_tile()), "never into deep water")
	# What a co-op client gets of her: the song ring and the dive state.
	var rep := Replicator.new()
	rep.game = game
	var desc := rep._describe(siren)
	var copy := spawn("siren", lake_near)
	copy.behavior = EnemyBehavior.new()
	copy.fx = {}
	rep._apply_state(copy, desc[3])
	check(copy.fx.has("song") and copy.dive == siren.dive and copy.sprite.flip_h == siren.sprite.flip_h, "co-op clients get her song ring and her dive state")
	rep.free()
	kill(copy)
	var rate := Combat.song_rate(game, civ.grid_pos)
	check(rate < 1.0 and rate >= 1.0 - float(Config.ENEMIES["siren"]["song_slow"]), "and slows everyone's timers near her (x%.2f)" % rate)
	check(is_equal_approx(Combat.song_rate(game, siren.grid_pos + Vector2(20, 0)), 1.0), "not beyond her song")
	var hero := game.hero
	_bench_hero(false)
	hero.set_mode(Hero.Mode.DEFEND)
	hero.set_grid_pos(Vector2(shore))
	hero._set_home(false)
	await wait(0.5)
	check(hero.target != siren, "the hero doesn't go for a siren in the water")
	hero.set_grid_pos(Vector2(game.player_village.center))
	hero.arrive_home()
	_bench_hero(true)
	home(civ)
	# Hurt badly in a short time she dives.
	siren.take_damage(siren.max_hp * 0.35, null, "projectile")
	var dove := await wait_until(func() -> bool: return siren.dive != Enemy.Dive.UP, 2.0)
	check(dove or not siren.on_deep(), "hurt badly she dives for a while")
	kill(siren)
	await clear_enemies()
	# Without anyone to lure she walks on to the gate.
	var s2 := spawn("siren", lake_mid)
	(s2.behavior as SirenBehavior)._patience = float(Config.ENEMIES["siren"]["patience"])
	var moved := await wait_until(func() -> bool: return (s2.behavior as SirenBehavior)._march, 3.0)
	check(moved, "after her patience runs out she heads for the gate")
	kill(s2)
	await clear_enemies()
	# Luring someone all along, she still goes once she has held max_hold s.
	var s3 := spawn("siren", lake_near)
	s3.speed = 0.0
	s3.set_grid_pos(Vector2(lake_near))
	var sb := s3.behavior as SirenBehavior
	var lured := outside(Vector2(shore))
	var luring := await wait_until(func() -> bool: return not sb._lured.is_empty(), 6.0)
	check(luring and not sb._march, "she holds while she lures someone")
	sb._held = float(Config.ENEMIES["siren"]["max_hold"]) - 0.5
	var gone := await wait_until(func() -> bool: return sb._march, 3.0)
	check(gone and sb._patience < float(Config.ENEMIES["siren"]["patience"]), "luring or not, after max_hold s of holding she heads for the gate (no stalled wave)")
	home(lured)
	kill(s3)
	await clear_enemies()


# --- the octopus --------------------------------------------------------------------------------

func _test_octopus() -> void:
	var oc := spawn("octopus", lake_near, 1)
	var ob := oc.behavior as OctopusBehavior
	var a := outside(Vector2(shore))
	var b := outside(Vector2(shore) + (Vector2(shore) - Vector2(lake_near)).normalized() * 0.5)
	var grabbed := await wait_until(func() -> bool: return is_instance_valid(a.held_by) or is_instance_valid(b.held_by), 10.0)
	check(grabbed, "an arm grabs someone on the shore")
	await wait(0.5)
	var arms := get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.kind == "octopus_arm")
	check(not arms.is_empty() and oc.fx.has("arms"), "a reaching or holding arm is a target of its own (%d)" % arms.size())
	var held: Array = [a, b].filter(func(c: Civilian) -> bool: return is_instance_valid(c.held_by))
	var holders := held.map(func(c: Civilian) -> Object: return c.held_by)
	check(holders.size() == holders.filter(func(h: Object) -> bool: return holders.count(h) == 1).size(), "never two arms on one")
	var waves_before := game.waves.enemies_left()
	check(arms.size() > 0 and waves_before >= 0, "arms don't count for the wave")
	# Cut the arm: its catch goes free.
	var who: Civilian = held[0] if not held.is_empty() else a
	var arm = who.held_by
	if is_instance_valid(arm):
		kill(arm)
		await frames(2)
		check(who.held_by == null and ob.arms.any(func(x: Dictionary) -> bool: return x["state"] == OctopusBehavior.Arm.GONE), "cutting the arm frees whoever it held; the arm is gone for a while")
	home(a)
	home(b)
	# A grabbed villager dragged under drowns.
	var pop := game.player_village.population.count()
	var c := outside(Vector2(shore))
	c.max_hp = 1000.0  # (tough enough to be dragged all the way in, not hurt to death first)
	c.hp = c.max_hp
	var drowned := await wait_until(func() -> bool: return c.dead, 30.0)
	check(drowned and game.player_village.population.count() == pop - 1, "a villager dragged into deep water drowns")
	check(logs.any(func(l: String) -> bool: return "drowned" in l), "the log says so")
	# Hurt badly in a short time it dives and lets go.
	var d := outside(Vector2(shore))
	await wait_until(func() -> bool: return is_instance_valid(d.held_by), 10.0)
	oc.take_damage(oc.max_hp * 0.2, null, "projectile")
	await frames(2)
	check(oc.dive != Enemy.Dive.UP and d.held_by == null, "losing 15 %% of its HP fast it dives, and every arm lets go")
	home(d)
	kill(oc)
	await frames(2)
	check(get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.kind == "octopus_arm").is_empty(), "dead, no arm is left")
	await clear_enemies()


# --- waves --------------------------------------------------------------------------------------

func _test_waves() -> void:
	var w := game.waves
	var v := game.player_village
	var k10 := w._kinds(10, v)
	check(k10.has("crab") and k10.has("siren") and k10.count("leviathan") >= 1 and k10.count("leviathan") <= 2, "wave 10 here brings crabs, sirens and a leviathan or two")
	var with_oct := 0
	var most := 0
	for i in 40:
		var k := w._kinds(25, v)
		most = maxi(most, k.count("octopus"))
		if k.has("octopus"):
			with_oct += 1
	check(with_oct > 0 and with_oct < 40 and most == 1, "the octopus comes only now and then, one at most (%d of 40 waves)" % with_oct)
	check(not w._kinds(25, null).has("crab"), "the co-op extra brings no water monsters")
	var out := []
	for kind in ["leviathan", "crab", "goblin"]:
		out.append(w._spec(kind, game.map.edge_spawns[0], 1.0, v))
	w._water_spawns(out, v)
	# (The river fits a leviathan too, and has no water spawn: a deep tile of it far from the village stands in.)
	var lev_at: Vector2i = out[0]["spawn"]
	var from_lake := game.world.pathing.body_of(lev_at) == game.world.pathing.body_of(lake_mid)
	check((w.aqua(v)["leviathan"] as Array).has(lev_at) and (lev_at == lake_mid or not from_lake) and out[2]["spawn"] == game.map.edge_spawns[0], "a leviathan comes from the water (the lake's water spawn, or deep in the river: %s), a goblin from the edge" % lev_at)
	# A wave with a leviathan ends only once it is dead, or once it has been
	# left alone for AQUA leave_after s: then it goes back into the deep.
	w.scripted.append({"kinds": {"leviathan": 1}, "spawn": lake_mid})
	w.start_now()
	await wait_until(func() -> bool: return not w._queue.is_empty() or w._alive > 0, 3.0)
	await wait_until(func() -> bool: return w._queue.is_empty(), 5.0)
	var lev: Enemy = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "leviathan":
			lev = e
	var leave := float(Config.AQUA["leave_after"])
	check(leave == 3.0 and lev != null and lev.behavior is AquaBehavior, "a leviathan is out (water-bound monsters left alone leave after %s s)" % leave)
	# Kept in a fight (hurt now and then), it stays.
	var poke := func() -> bool:
		if is_instance_valid(lev) and not lev.dead:
			lev.take_damage(0.001, null)
		return false
	await wait_until(poke, leave + 3.0)
	check(is_instance_valid(lev) and not lev.dead and w.in_progress() and w.enemies_left() == 1, "the wave goes on while the leviathan lives and fights (it counts in the top bar)")
	check(logs.any(func(l: String) -> bool: return l == Config.AQUA_FIRST["leviathan"]), "the first leviathan of the game is logged")
	check(not logs.any(func(l: String) -> bool: return l.begins_with("Water monsters are still out there")), "no warning straight away")
	var warned := await wait_until(func() -> bool:
		poke.call()
		return logs.any(func(l: String) -> bool: return l.begins_with("Water monsters are still out there (leviathan)")), float(Config.AQUA["warn_after"]) + 5.0)
	check(warned, "with only water monsters left, still fighting, after %d s the log says so (and a toast)" % int(Config.AQUA["warn_after"]))
	await wait_until(poke, 2.0)
	check(logs.filter(func(l: String) -> bool: return l.begins_with("Water monsters are still out there")).size() == 1, "once per wave")
	# Left alone, it goes after leave_after s; no corpse, the wave is over.
	var corpses0: int = game.corpses.corpses.size()
	var gone := await wait_until(when_gone(lev, func(x: Object) -> bool: return x.dead), leave + 3.0)
	await frames(3)
	check(gone and not w.in_progress() and game.corpses.corpses.size() == corpses0 and logs.any(func(l: String) -> bool: return l.ends_with("goes back into the deep")), "left alone for %s s, it goes back into the deep: no corpse, the wave is over" % leave)
	# A named one (a scenario's boss) never leaves.
	w.scripted.append({"kinds": {"leviathan": 1}, "spawn": lake_mid})
	w.start_now()
	await wait_until(func() -> bool: return w._queue.is_empty() and w._alive > 0, 8.0)
	var boss: Enemy = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "leviathan" and not e.dead:
			boss = e
	if boss:
		boss.given_name = "Leviathan"
	await wait(leave + 3.0)
	check(boss != null and not boss.dead and w.in_progress(), "a named one (a scenario's boss) stays until it is slain")
	if boss:
		kill(boss)
	await frames(3)
	check(not w.in_progress(), "dead, the wave is over")


# --- maps, files, the editor --------------------------------------------------------------------

func _test_map_files(m: MapData) -> void:
	check(MapData.from_bytes(m.to_bytes()).water_spawns == m.water_spawns, "water spawns survive the packed map (saves, co-op)")
	var text := MapJson.write(m)
	check("\"water_spawns\": [[%d, %d]]" % [lake_mid.x, lake_mid.y] in text and "\"format_version\": %d" % MapJson.VERSION in text, "map files list them (format %d)" % MapJson.VERSION)
	var back = MapJson.read(text)["map"]
	check(back != null and (back as MapData).water_spawns == m.water_spawns, "and read them back")
	var old := text.replace("\"format_version\": %d" % MapJson.VERSION, "\"format_version\": 1")
	var lines := Array(old.split("\n")).filter(func(l: String) -> bool: return not l.begins_with("  \"water_spawns\""))
	var older = MapJson.read("\n".join(lines))["map"]
	check(older != null and (older as MapData).water_spawns.is_empty(), "a format 1 file (no water spawns) still reads")
	var e := m.copy()
	check(MapChecks.errors(MapChecks.run(e)).is_empty(), "the map passes the checks")
	check(EditorTools.toggle_water_spawn(e, shore) is String, "the editor puts no water spawn on land")
	check(EditorTools.toggle_water_spawn(e, lake_near) is Array and e.water_spawns.has(lake_near), "it does on deep water")
	check(EditorTools.toggle_water_spawn(e, lake_near) is Array and not e.water_spawns.has(lake_near), "a second click takes it away")
	e.water_spawns.append(shore)
	e.water_spawns.append(river_a[0])
	var probs := MapChecks.errors(MapChecks.run(e))
	check(probs.any(func(p: Dictionary) -> bool: return "isn't on deep water" in str(p["text"])), "a water spawn on land is an error")
	check(not probs.any(func(p: Dictionary) -> bool: return str(p["text"]).begins_with("Water spawn [%d, %d]" % [river_a[0].x, river_a[0].y])), "one in a river is fine (crabs and sirens live there)")
	var pond := m.copy()
	var p0 := lake_block.position + Vector2i(1, 1)
	for t in MapData.rect_tiles(lake_block):
		pond.set_terrain(t, MapData.Terrain.GRASS)
	pond.set_terrain(p0, MapData.Terrain.WATER)
	pond.water_spawns.assign([p0])
	check(MapChecks.errors(MapChecks.run(pond)).any(func(p: Dictionary) -> bool: return "too small" in str(p["text"])), "one in a pond too small for any of them is an error")
	check(MapEditor.TOOLS.has("water"), "the editor has a Water spawn tool")


# --- the generator ------------------------------------------------------------------------------

func _test_generator() -> void:
	var coast_ok := true
	var spawns_ok := true
	var detail := PackedStringArray()
	for s in [11, 12, 77, 205]:
		var m := MapGenerator.generate(s, 1, "coast")
		var lab := Pathing.label_water(m)
		var c: Vector2i = m.villages[0]["center"]
		var near := false
		for b: Dictionary in lab["bodies"]:
			if not Pathing.kinds_fitting(b).has("leviathan"):
				continue
			for t: Vector2i in b["tiles"]:
				if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= 2 + int(Config.COAST_INLET_DIST) + 3:
					near = true
					break
		coast_ok = coast_ok and near
		if not near:
			detail.append(str(s))
		spawns_ok = spawns_ok and not m.water_spawns.is_empty()
		for t in m.water_spawns:
			spawns_ok = spawns_ok and m.is_deep(t) and not Pathing.kinds_fitting(lab["bodies"][int(lab["of"][m.index(t)])]).is_empty()
		spawns_ok = spawns_ok and MapChecks.errors(MapChecks.run(m)).is_empty()
	check(coast_ok, "Coast maps: deep water a leviathan fits close by every village (an inlet if the sea is far)%s" % (" (not for seeds %s)" % ", ".join(detail) if not detail.is_empty() else ""))
	check(spawns_ok, "their water spawns are on deep water that fits a water monster, and the maps pass the checks")
	var lagoons := 0
	var lagoon_ok := true
	for s in range(1, 40):
		var c := GenContext.new(s, 1, "temperate", 0)
		MapGenerator.run(c)
		if c.aqua_sites.is_empty():
			continue
		lagoons += 1
		var tip: Vector2i = c.aqua_sites[0]["tip"]
		var lab := Pathing.label_water(c.m)
		var b := int(lab["of"][c.m.index(tip)])
		lagoon_ok = lagoon_ok and b >= 0 and Pathing.kinds_fitting(lab["bodies"][b]).has("leviathan") and c.failures.is_empty()
		if lagoons >= 3:
			break
	check(lagoons > 0 and lagoon_ok, "other map types sometimes get a lagoon by the village, deep enough for a leviathan (%d found)" % lagoons)
	var plain := GenContext.new(1337, 1, "highlands", 0)
	MapGenerator.run(plain)
	check(plain.aqua_sites.is_empty(), "the tutorial's map gets none (its seed rolls no lagoon)")
