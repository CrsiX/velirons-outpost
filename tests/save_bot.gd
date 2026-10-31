extends "res://tests/bot_base.gd"
## Headless test of saving and loading (docs/save-design.md): a game with
## every kind of state saved and loaded again gives the same save; the loaded
## game runs on (a wave, the autosave after it); saving only between waves,
## never in the tutorial; the files (header-only list, refusals, delete,
## autosaves kept for the newest games only); Continue's pick; two villages
## (a caravan, a unit on its way, the hero supporting, a fallen village).
## Saves go to a folder of their own (SaveGame.dir_override). Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/save_bot.tscn
## Exits 0 when every check passes.

const DIR := "user://save_bot"
const ELEMENTAL_SCRIPT := preload("res://scripts/units/earth_elemental.gd")


func _run() -> void:
	SaveGame.dir_override = DIR
	_clear_dir()
	await _single()
	await _files()
	await _tutorial()
	await _villages()
	_clear_dir()
	SaveGame.dir_override = ""
	Engine.time_scale = 1.0
	get_tree().paused = false
	print("CHECKS %d  FAILURES %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func _new_game(villages: int = 1, seed_value: int = 7) -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = seed_value
	game.test_villages = villages
	add_child(game)
	await frames(3)


## The game saved in `body` (Settings.pending_save), built paused so nothing moves before it's looked at.
func _load_game(body: Dictionary) -> void:
	Settings.pending_save = body
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	get_tree().paused = true
	await frames(3)


func _end_game() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	game.queue_free()
	await frames(3)


## Differences between two saves' bodies ("path: a != b"), at most `limit`.
func _diff(a: Variant, b: Variant, path: String, out: Array[String], limit: int = 12) -> void:
	if out.size() >= limit:
		return
	if a is Dictionary and b is Dictionary:
		var keys := {}
		for k in (a as Dictionary).keys() + (b as Dictionary).keys():
			keys[k] = true
		for k in keys:
			if not a.has(k) or not b.has(k):
				out.append("%s/%s: only in %s" % [path, str(k), "the first" if a.has(k) else "the second"])
			else:
				_diff(a[k], b[k], "%s/%s" % [path, str(k)], out, limit)
		return
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			out.append("%s: %d entries != %d" % [path, (a as Array).size(), (b as Array).size()])
			return
		for i in (a as Array).size():
			_diff(a[i], b[i], "%s[%d]" % [path, i], out, limit)
		return
	if (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 0.001:
			out.append("%s: %s != %s" % [path, str(a), str(b)])
		return
	if a is Vector2 and b is Vector2:
		if (a as Vector2).distance_to(b) > 0.001:
			out.append("%s: %s != %s" % [path, str(a), str(b)])
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("%s: %s != %s" % [path, str(a).left(60), str(b).left(60)])


## The body without what a load makes anew (the id counter: walking units get new bodies).
func _comparable(body: Dictionary) -> Dictionary:
	var d := body.duplicate(true)
	(d["game"] as Dictionary).erase("next_nid")
	return d


func _same_body(a: Dictionary, b: Dictionary, what: String) -> void:
	var out: Array[String] = []
	_diff(_comparable(a), _comparable(b), "", out)
	check(out.is_empty(), "%s: saving the loaded game gives the same save%s" % [what, "" if out.is_empty() else " (" + "; ".join(out) + ")"])


# --- single player -----------------------------------------------------------------------

func _wall_towers(v: Village) -> Array[Tower]:
	var out: Array[Tower] = []
	for b in v.buildings():
		if b is Tower and b.kind == "wall_tower":
			out.append(b)
	return out


func _place_done(kind: String, near: Vector2i) -> Building:
	var t := find_spot(kind, near)
	var b := game.construction.place(kind, t)
	if b:
		game.construction.complete(b)
	return b


## A tree with a free tile next to it that can be walked to from the village.
func _reachable_tree(t: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if game.world.pathing.is_walkable(t + d) and not game.world.pathing.find_path(game.player_village.center, t + d).is_empty():
			return true
	return false


func _single() -> void:
	print("-- single player: everything saved and loaded")
	await _new_game()
	var v := game.player_village
	var w := game.world
	game.waves.hold = true
	for res in Economy.RESOURCES:
		v.economy.add(res, 5000)
	check(game.game_id != "" and game.save_error() == "", "a new game has an id and can be saved before wave 1")
	var c := v.center
	# Buildings: finished, a site, an upgrade, a tear-down, barracks, a ruined hut rebuilt.
	var tower := _place_done("tower", c + Vector2i(5, 0))
	var site := game.construction.place("tower", find_spot("tower", c + Vector2i(-5, 3)))
	site.progress = site.build_time * 0.4
	game.construction.order_upgrade(tower)
	tower.upgrade_progress = tower.upgrade_time * 0.25
	var barracks := _place_done("barracks", c + Vector2i(0, 6))
	game.construction.order_upgrade(barracks)
	game.construction.complete(barracks)
	var stone := _place_done("lightstone", c + Vector2i(6, 6))
	game.construction.order_tear_down(stone)
	stone.teardown_progress = 1.0
	var empty_hut: Hut = null
	for h in v.huts():
		if (h as Hut).resident == null and (h as Hut).is_intact():
			empty_hut = h
	empty_hut.destroy("a test")
	game.construction.order_rebuild(empty_hut)
	for b in v.buildings():
		if b is Farm:
			(b as Farm).stored = 7.5
	# Units: on a tower, on a bench, in the reserve, downed, specialised, a summoner with an elemental, training.
	var walls := _wall_towers(v)
	var archer := v.army.recruit("archer")
	v.army.station(archer, walls[0])
	v.army._on_arrived(archer.walker)
	archer.level = 4
	archer.hp = 20.0
	var bearer := v.army.recruit("shield_bearer")
	v.army.station(bearer, barracks)
	v.army._on_arrived(bearer.walker)
	var spare := v.army.recruit("archer")
	spare.level = 2
	v.army.upgrade(spare, "crossbowman")
	var downed := v.army.recruit("archer")
	v.army.down(downed)
	var marching := v.army.recruit("archer")
	v.army.station(marching, tower)
	game.unlock("summoner")
	var summoner := v.army.recruit("summoner")
	v.army.station(summoner, walls[1])
	v.army._on_arrived(summoner.walker)
	var el: EarthElemental = ELEMENTAL_SCRIPT.new()
	el.village = v
	el.setup(game, walls[1].tile, walls[1].work_tile(), 30.0, 5.0, "earth")
	el.uid = game.next_id("elemental")
	el.nid = game.register(el)
	w.objects.add_child(el)
	(summoner.behavior as SummonerBehavior).summons.append(el)
	el.hp = 17.0
	# The hero: level 2, out in the field carrying loot.
	var h := game.hero
	h.xp = 400
	h.level_up()
	h.xp = 33
	h.hp = h.max_hp - 5.0
	h.set_mode(Hero.Mode.EXPLORE)
	h.set_grid_pos(Vector2(c + Vector2i(4, 4)))
	h._set_home(false)
	var ex := h.jobs[Hero.Mode.EXPLORE] as HeroExploreJob
	ex.carrying = {"gold": 30}
	ex.carrying_from = "chest"
	ex.task = HeroExploreJob.Task.CARRYING
	h.head_home()
	# A gatherer out with corpses, the world: corpses, a hurt camp guard, trees, fog, a relic.
	var gath := v.population.recruit("gatherer") as Gatherer
	gath.job.carried.assign(["goblin", "orc"])
	gath.job.carried_gold = 3
	gath.set_grid_pos(Vector2(c + Vector2i(3, -4)))
	gath._set_home(false)
	game.corpses.spawn("orc", 0, Vector2(tower.work_tile()))
	var guard: Enemy = null
	for o in w.map_objects:
		if o is MonsterCamp and not (o as MonsterCamp).alive().is_empty():
			guard = (o as MonsterCamp).alive()[0]
			guard.hp -= 3.0
			break
	var trees: Array[Vector2i] = []
	for t: Vector2i in game.map.props:
		if w.is_tree(t) and Vector2(t).distance_to(Vector2(c)) < 14.0 and trees.size() < 2 and _reachable_tree(t):
			trees.append(t)
	w.remove_tree(trees[0])
	w.chop_tree(trees[1], 2.5)
	game.fog.reveal(Vector2(c + Vector2i(12, 0)), 4.0, v.id)
	v.relics.append(Config.RELICS.keys()[0])
	await frames(10)
	# Right before saving (no frame in between): a forester at his tree, a builder out in the field.
	var forester: Forester = null
	var builder: Builder = null
	for civ in v.population.civilians:
		if civ is Forester:
			forester = civ
		elif civ is Builder:
			builder = civ
	forester._release_tree()
	forester.tree = trees[1]
	w.claim_tree(trees[1], forester)
	forester.carrying = 0
	forester.state = Forester.State.CHOPPING
	forester.set_grid_pos(Vector2(forester._stand_tile()))
	forester._set_home(false)
	builder.job.release()
	builder.job.state = BuildJob.State.RESTING
	builder.set_grid_pos(Vector2(barracks.work_tile()))
	builder._set_home(false)
	# A wrathwood out wandering, hurt, after the forester (docs/enemies-design.md §15c).
	var lt_tile := Vector2i(-1, -1)
	for t: Vector2i in game.map.props:
		if w.is_tree(t) and not trees.has(t) and Vector2(t).distance_to(Vector2(c)) < 16.0:
			lt_tile = t
			break
	game.wrathwoods.felled[v.id] = 4
	game.wrathwoods.calm_until[v.id] = 2
	var living := game.wrathwoods.wake(lt_tile, v, forester)
	var lb := living.behavior as WrathwoodBehavior
	lb.state = WrathwoodBehavior.State.WANDER
	lb.wander_left = 7.5
	living.fx.erase("wake")
	living.hp = living.max_hp * 0.6
	living.set_grid_pos(Vector2(lt_tile) + Vector2(0.4, 0.2))
	get_tree().paused = true
	var err := game.save_named("Bot game")
	check(err == "", "Save: written (%s)" % err)
	var path := SaveGame.path_for("Bot game")
	var r := SaveGame.read(path)
	check(r["error"] == "" and r["header"]["name"] == "Bot game" and not r["header"]["auto"] and int(r["header"]["wave"]) == 0,
		"the file reads back, its header names it (%s)" % r["error"])
	check(not FileAccess.file_exists(path + ".tmp"), "no temporary file is left behind")
	var listed := SaveGame.list(false)
	check(listed.size() == 1 and listed[0]["path"] == path and not listed[0].has("body"), "the list has it (headers only)")
	check(SaveGame.list(true).is_empty(), "a single-player save isn't a co-op save")
	check(SaveGame.newest_single() == path, "Continue would load it")
	var body: Dictionary = r["body"]
	var gold := v.economy.amount("gold")
	var id := game.game_id
	var site_progress := site.progress
	var ids := {"site": site.nid, "tower": tower.nid, "barracks": barracks.nid, "archer": archer.nid, "wall0": walls[0].nid,
		"marching": marching.nid, "spare": spare.nid, "downed": downed.nid, "summoner": summoner.nid, "gath": gath.nid, "guard": guard.nid,
		"forester": forester.nid, "builder": builder.nid, "living": living.nid}
	var living_hp := living.hp
	var guard_hp := guard.hp
	var stats_time := game.stats.time
	var nid_before := game._next_nid
	await _end_game()

	await _load_game(body)
	v = game.player_village
	w = game.world
	check(game.loaded and game.game_id == id, "the loaded game keeps the game's id")
	_same_body(body, SaveGame.capture(game), "single player")
	check(game._next_nid >= nid_before, "new ids don't clash with saved ones")
	check(absf(v.economy.amount("gold") - gold) < 0.01, "the gold is back (%d)" % int(v.economy.amount("gold")))
	var site2 := game.entity(ids["site"]) as Building
	check(site2 != null and not site2.complete and absf(site2.progress - site_progress) < 0.01 and v.construction.queue.has(site2), "the site is there, as far along, in the build queue")
	var tower2 := game.entity(ids["tower"]) as Tower
	check(tower2 != null and tower2.upgrading and tower2.level == 1 and v.construction.queue.has(tower2), "the ordered tower upgrade waits for a builder")
	var barracks2 := game.entity(ids["barracks"]) as Barracks
	check(barracks2 != null and barracks2.level == 2 and barracks2.slots[0] != null and barracks2.slots[0].kind == "shield_bearer", "the barracks: level 2, the shield bearer on its bench")
	var archer2 := game.entity(ids["archer"]) as MilitaryUnit
	check(archer2 != null and archer2.state == MilitaryUnit.State.STATIONED and archer2.level == 4 and absf(archer2.hp - 20.0) < 0.01
		and archer2.post == game.entity(ids["wall0"]) and archer2.post.garrison == archer2, "the archer is on its wall tower, level 5, hurt")
	var march2 := game.entity(ids["marching"]) as MilitaryUnit
	check(march2 != null and march2.state == MilitaryUnit.State.MARCHING and is_instance_valid(march2.walker) and tower2.incoming == march2, "the marching archer walks on to its tower")
	check((game.entity(ids["spare"]) as MilitaryUnit).kind == "crossbowman", "the specialised unit is a crossbowman")
	var down2 := game.entity(ids["downed"]) as MilitaryUnit
	check(down2.state == MilitaryUnit.State.DOWNED and down2.revive_left > 0.0, "the downed unit waits to revive")
	var summ2 := game.entity(ids["summoner"]) as MilitaryUnit
	var summons: Array = (summ2.behavior as SummonerBehavior).summons
	# (idle, it heals SUMMONS "regen" per second from the load on)
	check(summons.size() == 1 and (summons[0] as EarthElemental).hp >= 16.99 and (summons[0] as EarthElemental).hp < 20.0, "the summoner's elemental is back, as hurt as it was")
	h = game.hero
	check(h.level == 1 and h.xp == 33 and not h.at_home and (h.jobs[Hero.Mode.EXPLORE] as HeroExploreJob).task == HeroExploreJob.Task.CARRYING and not h.path.is_empty(),
		"the hero: level 2, her XP, out in the field carrying her loot home (%d, %d, %s, %d)" % [h.level, h.xp, h.at_home, (h.jobs[Hero.Mode.EXPLORE] as HeroExploreJob).task])
	var gath2 := game.entity(ids["gath"]) as Gatherer
	check(gath2 != null and gath2.job.carried.size() == 2 and not gath2.evading and gath2.job.state == GatherJob.State.TO_CORPSE
		and gath2.job.target == game.corpses.corpses[0] and gath2.hut != null and gath2.hut.resident == gath2,
		"the gatherer goes on from where he was: room for more, so to the corpse, with his load (state %d)" % gath2.job.state)
	var for2 := game.entity(ids["forester"]) as Forester
	check(for2 != null and for2.tree == trees[1] and for2.state == Forester.State.TO_TREE and not for2.evading and for2.camp != null,
		"the forester at his tree goes on with that tree (state %d), not home first" % for2.state)
	var bui2 := game.entity(ids["builder"]) as Builder
	check(bui2 != null and bui2.job.state == BuildJob.State.TO_SITE and bui2.job.site != null and bui2.job.site.builder == bui2 and not bui2.evading,
		"the builder out in the field walks from there to a site (state %d)" % bui2.job.state)
	check(game.corpses.corpses.size() == 1 and game.corpses.corpses[0].kind == "orc", "the corpse lies there")
	var living2 := game.entity(ids["living"]) as Enemy
	var lb2 := living2.behavior as WrathwoodBehavior if living2 else null
	check(living2 != null and lb2 != null and absf(living2.hp - living_hp) < 0.01 and lb2.state == WrathwoodBehavior.State.WANDER and is_equal_approx(lb2.wander_left, 7.5)
		and lb2.home == lt_tile and living2.grid_pos.distance_to(Vector2(lt_tile) + Vector2(0.4, 0.2)) < 0.001 and lb2.forester == for2 and lb2.camp == for2.camp,
		"the wrathwood is back: where it was, as hurt, wandering, its home and its forester and camp")
	check(game.wrathwoods.felled[v.id] == 4 and game.wrathwoods.calm_until[v.id] == 2 and not w.is_tree(lt_tile), "what the forest remembers is kept")
	var guard2 := game.entity(ids["guard"]) as Enemy
	check(guard2 != null and absf(guard2.hp - guard_hp) < 0.01 and guard2.behavior is CampBehavior, "the hurt camp guard is still hurt")
	check(not w.is_tree(trees[0]) and absf(w.tree_progress(trees[1]) - 2.5 / w.tree_chop_time(trees[1])) < 0.01, "the felled tree is gone, the chopped one as far chopped")
	check(game.fog.is_explored_by(v.id, c + Vector2i(12, 0)), "the explored land is explored")
	check(v.relics.size() == 1, "the relic is kept")
	check(absf(game.stats.time - stats_time) < 0.01 and game.stats.enabled, "the statistics go on from where they were")
	var lines: Array = v.events.entries.map(func(e: Dictionary) -> String: return str(e["text"]))
	check(lines.any(func(l: String) -> bool: return l.begins_with("Game loaded: wave 0")) and lines.size() <= 3,
		"the log says it was loaded, and nothing of the restore (%s)" % str(lines))
	var cam_off: float = game.camera.position.distance_to(Iso.tile_to_world(v.center))
	check(cam_off < 1.0, "the view starts on the village")

	# It runs on: a wave comes and goes, then the autosave.
	get_tree().paused = false
	Engine.time_scale = 4.0
	game.waves.hold = false
	game.waves.call_next(v)
	await frames(2)
	check(game.save_error() == "You can save between waves", "during a wave it can't be saved")
	check(await wait_until(func() -> bool: return not get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return not (e.behavior is CampBehavior)).is_empty() or not game.waves.in_progress(), 20.0), "the wave comes")
	for k in 40:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not ((e as Enemy).behavior is CampBehavior):
				kill(e)
		await frames(5)
		if not game.waves.in_progress():
			break
	await frames(5)
	var auto := SaveGame.auto_path(game.game_id)
	check(not game.waves.in_progress() and FileAccess.file_exists(auto), "after the wave the game saved itself (%s)" % auto.get_file())
	var ar := SaveGame.read(auto)
	check(ar["error"] == "" and ar["header"]["auto"] and int(ar["header"]["wave"]) == 1, "the autosave: wave 1, marked as an autosave")
	check(SaveGame.newest_single() == auto and SaveGame.newest_of(game.game_id) == auto, "Continue (and Load last save) now take the autosave, the newest")
	check(await wait_until(when_gone(site2, func(x: Object) -> bool: return x.complete), 120.0), "a builder finishes the saved site")
	await _end_game()


# --- files ---------------------------------------------------------------------------

func _files() -> void:
	print("-- files")
	var good := SaveGame.newest_single()
	var raw := FileAccess.get_file_as_bytes(good)
	var bad_magic := DIR.path_join("bad1.vsave")
	var f := FileAccess.open(bad_magic, FileAccess.WRITE)
	f.store_buffer("NOPE and more bytes here".to_ascii_buffer())
	f.close()
	check(SaveGame.read(bad_magic)["error"] == "Not a save file", "a file that isn't a save is refused")
	var other := raw.duplicate()
	other.encode_u32(4, SaveGame.FORMAT + 1)
	f = FileAccess.open(DIR.path_join("bad2.vsave"), FileAccess.WRITE)
	f.store_buffer(other)
	f.close()
	check(SaveGame.read(DIR.path_join("bad2.vsave"))["error"] == "Made with another version of the game", "another format version is refused")
	var r := SaveGame.read(good)
	var body: Dictionary = r["body"]
	(body["units"] as Array).append({"k": "dragon_rider"})
	check(SaveGame.check(body) == "Made with another version of the game", "a kind this version doesn't know is refused")
	var errs := SaveGame.list(false).filter(func(e: Dictionary) -> bool: return e["error"] != "")
	check(errs.size() == 2, "the list shows the broken files too (with why)")
	SaveGame.delete(bad_magic)
	SaveGame.delete(DIR.path_join("bad2.vsave"))
	check(SaveGame.list(false).all(func(e: Dictionary) -> bool: return e["error"] == ""), "Delete removes them")
	# A newer co-op save doesn't change what Continue loads.
	var h: Dictionary = (r["header"] as Dictionary).duplicate()
	h["coop"] = true
	h["villages"] = [{"name": "A", "color": "ffffff"}, {"name": "B", "color": "000000"}]
	h["saved_at"] = int(h["saved_at"]) + 100
	SaveGame.write(DIR.path_join("coop.vsave"), h, r["body"])
	check(SaveGame.newest_single() == good and SaveGame.list(true).size() == 1, "Continue ignores a newer co-op save; the lobby lists it")
	SaveGame.delete(DIR.path_join("coop.vsave"))
	# Autosaves: only the newest games' are kept.
	for i in 7:
		var ah: Dictionary = (r["header"] as Dictionary).duplicate()
		ah["auto"] = true
		ah["saved_at"] = 1000 + i
		SaveGame.write(SaveGame.auto_path("old%d" % i), ah, r["body"])
	SaveGame._prune_autosaves()
	var autos := SaveGame.list(false).filter(func(e: Dictionary) -> bool: return str(e["path"]).get_file().begins_with(SaveGame.AUTO_PREFIX))
	check(autos.size() == int(Config.SAVE["keep_autosaves"]) and not FileAccess.file_exists(SaveGame.auto_path("old0")) and FileAccess.file_exists(good),
		"autosaves are kept for the newest %d games only" % int(Config.SAVE["keep_autosaves"]))
	check(SaveGame.path_for("Auto-1").get_file() != SaveGame.auto_path("1").get_file() and SaveGame.path_for("My / Game!").get_file() == "my-game.vsave",
		"save names make safe file names, never an autosave's")
	# The title screen's Continue.
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await frames(2)
	check(title.continue_button.visible and title._continue_path == SaveGame.newest_single() and title.continue_label.text.begins_with("Wave"),
		"the Singleplayer page offers Continue, with what it is (%s)" % title.continue_label.text)
	check(not title.singleplayer_button.get_parent().get_children().any(func(n: Node) -> bool: return n is Button and (n as Button).text == "Continue"),
		"the main page has no Continue")
	# The save list's map: only the land the save had explored (its fog), nothing else.
	title.save_list.choose(false, func(_p: String) -> void: pass)
	await frames(2)
	var shown := SaveGame.read(title.save_list.selected_path())
	var fog: PackedByteArray = shown["body"]["fog"][0]
	var m := SaveGame.saved_map(shown["body"])
	var img: Image = title.save_list._preview._tex.get_image()
	var hidden := 0
	var leaked := 0
	for i in fog.size():
		var black := _is_fog(img.get_pixel(i % m.size, i / m.size))
		if fog[i] == 0:
			hidden += 1
			leaked += 0 if black else 1
		elif black:
			leaked += 1
	check(hidden > 0 and leaked == 0, "the save list's map shows only the explored land (%d tiles hidden, %d wrong)" % [hidden, leaked])
	var objs := m.objects.filter(func(o: Dictionary) -> bool: return fog[m.index(o["tile"])] == 0)
	check(not objs.is_empty() and objs.all(func(o: Dictionary) -> bool: return _is_fog(img.get_pixelv(o["tile"]))), "and no object hidden in the fog is marked (%d of them)" % objs.size())
	title.save_list.close()
	title.queue_free()
	await frames(2)


## A preview pixel in the fog colour (8 bits per channel: not exact).
func _is_fog(c: Color) -> bool:
	return absf(c.r - MapPlan.FOG.r) < 0.01 and absf(c.g - MapPlan.FOG.g) < 0.01 and absf(c.b - MapPlan.FOG.b) < 0.01


func _tutorial() -> void:
	print("-- tutorial")
	game = load("res://scenes/main.tscn").instantiate()
	game.tutorial_mode = true
	add_child(game)
	await frames(3)
	check(game.save_error() != "", "the tutorial can't be saved")
	game.hud.open_settings()
	await frames(1)
	check(not game.hud._settings_save_button.visible and not game.hud._settings_load_button.visible, "its settings have no Save or Load")
	game.hud.close_settings()
	await _end_game()


# --- two villages ------------------------------------------------------------------------

func _villages() -> void:
	print("-- two villages")
	await _new_game(2, 11)
	game.waves.hold = true
	var a := game.villages[0]
	var b := game.villages[1]
	for res in Economy.RESOURCES:
		a.economy.add(res, 2000)
	var r := game.commands.submit(a, "send_caravan", {"target": 1, "gold": 100})
	check(r["ok"], "a caravan is on its way")
	var u := a.army.recruit("archer")
	a.army.send(u, b)
	var unit_nid := u.nid
	game.commands.submit(a, "hero_mode", {"mode": Hero.Mode.SUPPORT})
	game.commands.submit(a, "hero_support", {"target": 1})
	for civ in b.population.civilians.duplicate():
		b.population.kill(civ, "in a test")
	await frames(20)
	check(b.fallen and not a.fallen and not game.game_over, "the second village has fallen, the first stands")
	get_tree().paused = true
	var body := SaveGame.capture(game)
	var hd := SaveGame.header(game, "Two", false)
	check(hd["coop"] and (hd["villages"] as Array).size() == 2, "a game of two villages is a co-op save")
	var seen := SaveGame.seen(body)
	var f0: PackedByteArray = body["fog"][0]
	var f1: PackedByteArray = body["fog"][1]
	var union_ok := true
	for i in seen.size():
		if seen[i] != maxi(f0[i], f1[i]):
			union_ok = false
	check(union_ok and seen.count(1) > f0.count(1) and seen.count(1) > f1.count(1) and seen.count(0) > 0,
		"its preview shows the land every village explored together (%d tiles, %d and %d alone)" % [seen.count(1), f0.count(1), f1.count(1)])
	await _end_game()
	await _load_game(body)
	check(game.villages.size() == 2 and game.villages[1].fallen, "both villages are back, the fallen one fallen")
	_same_body(body, SaveGame.capture(game), "two villages")
	var u2 := game.entity(unit_nid) as MilitaryUnit
	check(u2 != null and u2.state == MilitaryUnit.State.TRAVELLING and u2.travel_to == game.villages[1] and is_instance_valid(u2.walker), "the unit walks on to the other village")
	check(game.villages[0].hero.mode == Hero.Mode.SUPPORT and game.villages[0].hero.support_target == game.villages[1], "the hero still supports the other village")
	var caravans := game.world.objects.get_children().filter(func(n: Node) -> bool: return n is Caravan)
	check(caravans.size() == 1 and (caravans[0] as Caravan).to == game.villages[1] and (caravans[0] as Caravan).cargo.get("gold", 0) == 100, "the caravan goes on with its cargo")
	await _end_game()
