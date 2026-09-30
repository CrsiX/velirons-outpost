extends Node
## Headless test of rats, villager HP, farm defence, dropped loot and the
## icon UI. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/rat_bot.tscn
## Exits 0 when every check passes.

const SEED := 777

var failures: Array[String] = []
var checks := 0
var game: Game
var logs: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures.append(msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout:
			return false
	return true


func _run() -> void:
	_test_config()
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEED
	game.reveal_map = true
	game.disable_fog = true
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	game.player_village.events.logged.connect(func(_l: int, text: String) -> void: logs.append(text))
	Engine.time_scale = 6.0
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	_bench_hero(true)
	await _test_packs()
	await _test_farm()
	await _test_gate()
	await _test_villagers()
	await _test_defence()
	await _test_loot()
	await _test_ui()
	await _test_teardown()
	await _test_boxed_in_tower()
	await _test_fog()
	await _test_safe_walls()
	await _test_rats_give_up()
	_test_hero_bar()
	_test_people()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _bench_hero(on: bool) -> void:
	var h := game.hero
	h.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if on:
		h.remove_from_group("melee_defenders")
	else:
		h.add_to_group("melee_defenders")


## A rat (or `kind`) standing on `at`, walking the road from there.
func spawn(kind: String, at: Vector2, hp_scale: float = 1.0) -> Enemy:
	game.waves._spawn({"kind": kind, "spawn": game.map.edge_spawns[0], "hp_scale": hp_scale, "village": game.player_village})
	var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
	e.set_grid_pos(at)
	if e.behavior is RatBehavior:
		(e.behavior as RatBehavior)._to_road(e)
	return e


func rats() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e) -> bool: return e.kind == "rat" and not e.dead)


func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			e.take_damage(1e9)
	await frames(3)


# --- config ---------------------------------------------------------------------------------

func _test_config() -> void:
	var rat: Dictionary = Config.ENEMIES["rat"]
	var fastest := 0.0
	for k in Config.ENEMIES:
		if k != "rat":
			fastest = maxf(fastest, float(Config.ENEMIES[k]["speed"]))
	for k in Config.CIVILIANS:
		fastest = maxf(fastest, float(Config.CIVILIANS[k]["speed"]))
	for k in Config.MILITARY:
		fastest = maxf(fastest, float(Config.MILITARY[k]["speed"]))
	fastest = maxf(fastest, float(Config.HERO["speed"]))
	fastest = maxf(fastest, Config.CARAVAN_SPEED)
	for s in Config.SUMMONS:
		fastest = maxf(fastest, float(Config.SUMMON["speed"]) * float(Config.SUMMONS[s]["speed"]))
	check(float(rat["speed"]) > fastest, "rats are faster than any other unit (%.1f > %.1f)" % [rat["speed"], fastest])
	check(float(rat["hp"]) < float(Config.ENEMIES["goblin"]["hp"]) / 2.0, "rats are frail (%.0f HP)" % rat["hp"])
	var dps := float(rat["damage"]) / float(rat["attack_cooldown"])
	check(dps < 1.0, "their bites do very little damage (%.2f per second)" % dps)
	check(not rat.get("corpse", true) and float(rat["bite_range"]) < float(rat["farm_search"]), "no corpse; they bite closer than they look for farms")


# --- packs ------------------------------------------------------------------------------------

func _test_packs() -> void:
	var w := game.waves
	var before: Array = w._share(Config.RAT_PACKS["from_wave"] - 1, 1.0, game.map.edge_spawns, game.player_village)
	check(not before.any(func(sp: Dictionary) -> bool: return sp["kind"] == "rat"), "no rats before wave %d" % Config.RAT_PACKS["from_wave"])
	var share: Array = []
	for tries in 40:
		share = w._share(6, 1.0, game.map.edge_spawns, game.player_village)
		if share.any(func(sp: Dictionary) -> bool: return sp["kind"] == "rat"):
			break
	# Packs: runs of rats from one spawn, the followers with the short gap.
	var runs: Array[int] = []
	var i := 0
	var same_spawn := true
	while i < share.size():
		if share[i]["kind"] == "rat" and not share[i].has("gap"):
			var n := 1
			while i + n < share.size() and share[i + n].get("gap", 0.0) > 0.0:
				same_spawn = same_spawn and share[i + n]["spawn"] == share[i]["spawn"]
				n += 1
			runs.append(n)
			i += n
		else:
			i += 1
	check(not runs.is_empty() and runs.all(func(n: int) -> bool: return n >= Config.RAT_PACKS["size"][0] and n <= Config.RAT_PACKS["size"][1]) and same_spawn, "later waves bring packs of 4-7 rats from one spawn %s" % str(runs))
	# Spawned: a moment apart, so a little space between them.
	for sp in share:
		if sp["kind"] == "rat":
			w._queue.append(sp)
	var first_pack := runs[0] if not runs.is_empty() else 0
	w._queue = w._queue.filter(func(sp: Dictionary) -> bool: return sp["kind"] == "rat").slice(0, first_pack)
	w._spawn_timer = 0.0
	w.countdown = 0.0  # (spawning runs only between countdowns)
	var out := await wait_until(func() -> bool: return rats().size() >= first_pack, 20.0)
	await wait(0.3)
	var rs := rats()
	var min_gap := INF
	for a in rs:
		for b in rs:
			if a != b:
				min_gap = minf(min_gap, a.grid_pos.distance_to(b.grid_pos))
	check(out and min_gap > 0.2, "the pack runs with a little space between the rats (closest %.2f tiles)" % min_gap)
	# A fire mage's explosion catches several of them (a pack bunched up).
	for k in rs.size():
		rs[k].set_grid_pos(rs[0].grid_pos + Vector2(0.3 * k, 0.0))
	var pack_hp := rs.map(func(e: Enemy) -> float: return e.hp)
	var fm := MilitaryUnit.new("fire_mage")
	fm.village = game.player_village
	Combat.hit(game, fm, rs[0], fm.stat("damage"), null, rs[0].hit_point())
	var hurt := 0
	for k in rs.size():
		if not is_instance_valid(rs[k]) or rs[k].dead or rs[k].hp < pack_hp[k]:
			hurt += 1
	check(hurt >= 2, "a fireball's splash hits several rats of a pack (%d)" % hurt)
	var gold0 := game.economy.amount("gold")
	var corpses0 := game.corpses.count()
	await clear_enemies()
	check(game.economy.amount("gold") > gold0 and game.corpses.count() == corpses0, "killed rats pay a little gold and leave no corpse")
	w._queue.clear()
	w.countdown = 99999.0


# --- farms ------------------------------------------------------------------------------------

var farm: Farm


func _test_farm() -> void:
	farm = game.world.buildings.filter(func(b: Building) -> bool: return b is Farm)[0]
	farm.stored = 30.0
	var road := game.world.pathing.nearest_road(farm.tile)
	var rs: Array[Enemy] = []
	for k in 3:
		rs.append(spawn("rat", Vector2(road) + Vector2(k * 0.3, 0.0)))
	var went := await wait_until(func() -> bool: return farm.has_rats(), 20.0)
	check(went and (rs[0].behavior as RatBehavior).farm == farm, "a rat near a farm leaves the road and goes for it")
	# The farmer is away, so nothing but the rats changes the stock.
	game.population.unassign_farmer(farm)
	await wait_until(func() -> bool: return farm.rats.size() == 3, 10.0)
	var s0 := farm.stored
	await wait(3.0)
	check(farm.stored < s0 - 0.5, "they eat the stored food (%.1f -> %.1f)" % [s0, farm.stored])
	game.population.assign_farmer(farm)
	farm.stored = 5.0
	await wait(2.0)
	check(farm.stored <= 5.0, "while rats are on it, the farm grows nothing (%.1f)" % farm.stored)
	check(" ".join(farm.info()["lines"]).contains("eating the crops"), "the farm's panel says rats are eating the crops")
	var moved := false
	var p0 := rs[1].grid_pos
	for k in 60:
		await get_tree().process_frame
		moved = moved or rs[1].grid_pos.distance_to(p0) > 0.3 or absf(rs[1].sprite.rotation) > 0.02
	check(moved and farm.tiles().has(rs[1].current_tile()), "they wander about the field, nibbling")
	# Left alone, a rat on a farm is gone after vanish_after seconds; attacked, it stays.
	var kept := rs[2]
	var t := 0.0
	var gone := false
	var gold0 := game.economy.amount("gold")
	while t < Config.ENEMIES["rat"]["vanish_after"] + 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		farm.stored = maxf(farm.stored, 10.0)  # (food left: they stay)
		if is_instance_valid(kept) and not kept.dead and int(t * 10) % 50 == 0:
			kept.behavior.on_damaged(kept, game.hero)  # (someone keeps after it)
		gone = not is_instance_valid(rs[0]) or rs[0].dead
		if gone and t > Config.ENEMIES["rat"]["vanish_after"] + 1.0:
			break
	check(gone and t >= Config.ENEMIES["rat"]["vanish_after"] - 0.5, "a rat left alone on a farm vanishes after %.0f s (%.0f s)" % [Config.ENEMIES["rat"]["vanish_after"], t])
	check(is_instance_valid(kept) and not kept.dead, "one that is attacked stays")
	check(game.economy.amount("gold") == gold0, "vanishing rats give no gold")
	await clear_enemies()
	# Leftover rats once the rest of the wave is gone: all gone within RAT_WAVE_LINGER.
	game.waves.wave = 3
	game.waves.countdown = 0.0
	var r2 := spawn("rat", Vector2(road))
	var linger := await wait_until(func() -> bool: return game.waves.rat_deadline > 0.0, 5.0)
	var cleared := await wait_until(func() -> bool: return not is_instance_valid(r2) or r2.dead, Config.RAT_WAVE_LINGER + 5.0)
	check(linger and cleared and not game.waves.in_progress(), "rats alone at the end of a wave vanish within %.0f s and the wave ends" % Config.RAT_WAVE_LINGER)
	await wait(0.5)
	game.waves.countdown = 99999.0
	game.waves.rats_leave = false


# --- the gate --------------------------------------------------------------------------------

func _test_gate() -> void:
	var v := game.player_village
	v.economy.add("food", 300 - v.economy.amount("food"))
	var huts := v.intact_huts().size()
	var g: Vector2i = v.gates[0]
	for gg in v.gates:
		if game.map.is_road(gg + (gg - v.center).sign() * 2):
			g = gg
	var r := spawn("rat", Vector2(g + (g - v.center).sign() * 2))
	# (no farm near this gate for the test)
	(r.behavior as RatBehavior).state = RatBehavior.State.ROAD
	for f in game.world.buildings:
		if f is Farm:
			f.complete = false
	var got_in := await wait_until(func() -> bool: return not is_instance_valid(r) or r.dead, 20.0)
	for f in game.world.buildings:
		if f is Farm:
			f.complete = true
	var eaten := 300 - int(v.economy.amount("food"))
	var want := maxi(Config.ENEMIES["rat"]["gate_eat"], roundi(300 * Config.ENEMIES["rat"]["gate_eat_share"]))
	# (the villagers eat a little meanwhile)
	check(got_in and eaten >= want and eaten <= want + 2 and v.intact_huts().size() == huts, "a rat through the gate eats max(5, 5 %%) of the food (%d) and burns nothing" % eaten)
	check(logs.any(func(l: String) -> bool: return "got into the village and ate %d food" % want in l), "the log says so")
	v.economy.add("food", 300 - v.economy.amount("food"))
	v.economy.add("food", -290)
	var r3 := spawn("rat", Vector2(g + (g - v.center).sign() * 2))
	(r3.behavior as RatBehavior).state = RatBehavior.State.ROAD
	for f in game.world.buildings:
		if f is Farm:
			f.complete = false
	await wait_until(func() -> bool: return not is_instance_valid(r3) or r3.dead, 20.0)
	for f in game.world.buildings:
		if f is Farm:
			f.complete = true
	check(logs.any(func(l: String) -> bool: return "ate %d food" % Config.ENEMIES["rat"]["gate_eat"] in l), "with little food left, it eats at least %d" % Config.ENEMIES["rat"]["gate_eat"])


# --- villagers ---------------------------------------------------------------------------------

func _test_villagers() -> void:
	var v := game.player_village
	var ex: Civilian = v.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "explorer")[0]
	check(is_equal_approx(ex.max_hp, Config.CIVILIAN_HP) and ex.is_in_group("villagers"), "villagers have %.0f HP" % Config.CIVILIAN_HP)
	ex.set_process(false)
	ex.at_home = false
	ex.visible = true
	var spot := game.world.pathing.nearest_walkable(v.center + Vector2i(7, 0))
	ex.set_grid_pos(Vector2(spot))
	var r := spawn("rat", Vector2(spot) + Vector2(1.2, 0.0))
	var bitten := await wait_until(func() -> bool: return ex.hp < ex.max_hp, 10.0)
	check(bitten and (r.behavior as RatBehavior).state == RatBehavior.State.CHASE, "a rat bites a villager within reach")
	r.take_damage(1e9)
	# Any enemy hurts villagers; at 0 HP they die, with the cause.
	var gob := spawn("goblin", Vector2(spot) + Vector2(0.4, 0.0), 20.0)
	gob.speed = 0.0
	var hp0 := ex.hp
	var hit := await wait_until(func() -> bool: return ex.hp < hp0, 10.0)
	check(hit, "a goblin hits a villager too")
	ex.take_damage(1e9, gob)
	await frames(2)
	check(not v.population.civilians.has(ex) and logs.any(func(l: String) -> bool: return "died from the attack of goblin" in l), "at 0 HP the villager dies (logged with the cause)")
	gob.take_damage(1e9)
	# Hurt villagers heal at home.
	var fo: Civilian = v.population.civilians[0]
	fo.hp = 5.0
	fo.at_home = true
	await wait(2.0)
	check(fo.hp > 5.0, "at home they heal (%.1f HP)" % fo.hp)
	await clear_enemies()


# --- defending farms -----------------------------------------------------------------------------

func _test_defence() -> void:
	var v := game.player_village
	var hero := game.hero
	_bench_hero(false)
	hero.set_mode(Hero.Mode.DEFEND)
	hero.max_hp = 5000.0
	hero.hp = 5000.0
	var road := game.world.pathing.nearest_road(farm.tile)
	var r := spawn("rat", Vector2(road), 30.0)
	await wait_until(func() -> bool: return farm.has_rats(), 20.0)
	var goes := await wait_until(func() -> bool: return hero.target == r, 10.0)
	check(goes, "Defend: with nothing near the gates, the hero goes for rats on his farm")
	# A real threat at a gate comes first.
	var g: Vector2i = v.gates[0]
	var gob := spawn("goblin", Vector2(game.world.pathing.nearest_road(g + (g - v.center).sign() * 3)), 50.0)
	gob.speed = 0.0
	var turned := await wait_until(func() -> bool: return hero.target == gob, 10.0)
	check(turned, "an enemy near a gate comes before rats on a farm")
	await clear_enemies()
	hero.set_mode(Hero.Mode.REST)
	_bench_hero(true)
	await clear_enemies()
	# Barracks guard farms within twice their range.
	game.economy.add("materials", 500)
	game.economy.add("gold", 500)
	var spot := Vector2i(-1, -1)
	var best := INF
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			var d := Vector2(t).distance_to(Vector2(farm.tile))
			if d > 6.0 and d < 7.5 and game.construction.placement_error("barracks", t) == "" and d < best:
				best = d
				spot = t
	var b: Barracks = game.construction.place("barracks", spot)
	game.construction.queue.erase(b)
	b.progress = b.build_time
	game.construction.complete(b)
	await frames(2)
	var u := game.army.recruit("shield_bearer")
	game.army.station(u, b)
	await wait_until(func() -> bool: return b.slots[0] == u, 60.0)
	var dist := Vector2(farm.tile).distance_to(b.act_center())
	check(dist > b.activation_range() and dist <= b.activation_range() * Config.BARRACKS_FARM_RANGE_FACTOR, "(a farm beyond the barracks' range, within twice it: %.1f)" % dist)
	var r2 := spawn("rat", Vector2(road), 30.0)
	await wait_until(func() -> bool: return farm.has_rats(), 20.0)
	var out := await wait_until(func() -> bool: return u.out and is_instance_valid(u.walker) and (u.walker as Soldier).farm == farm, 10.0)
	check(out, "the barracks send their unit out to the farm with rats")
	# A real threat near the barracks comes first.
	var sw := u.walker as Soldier
	var gob2 := spawn("goblin", Vector2(game.world.pathing.nearest_walkable(Vector2i(b.act_center().round()) + Vector2i(1, 1))), 50.0)
	gob2.speed = 0.0
	var turned2 := await wait_until(func() -> bool: return is_instance_valid(sw) and sw.farm == null and sw.target == gob2, 10.0)
	check(turned2, "an enemy at the barracks calls it back from the farm")
	await clear_enemies()
	await wait_until(func() -> bool: return not u.out, 30.0)
	# A plain rat: dealt with quickly.
	var r3 := spawn("rat", Vector2(road))
	await wait_until(func() -> bool: return farm.has_rats(), 20.0)
	var killed := await wait_until(func() -> bool: return not is_instance_valid(r3) or r3.dead, 30.0)
	var back := await wait_until(func() -> bool: return not u.out, 30.0)
	check(killed and back, "it deals with the rats and goes back to its bench")
	await clear_enemies()


# --- dropped loot ------------------------------------------------------------------------------

func _test_loot() -> void:
	var v := game.player_village
	var hero := game.hero
	_bench_hero(false)
	var job: HeroExploreJob = hero.jobs[Hero.Mode.EXPLORE]
	hero.set_mode(Hero.Mode.EXPLORE)
	await frames(2)
	hero.at_home = false
	hero.set_grid_pos(Vector2(game.world.pathing.nearest_walkable(v.center + Vector2i(6, 3))))
	job.carrying = {"gold": 40}
	job.carrying_from = "buried chest"
	job.task = HeroExploreJob.Task.CARRYING
	var n0 := game.world.map_objects.size()
	hero.set_mode(Hero.Mode.REST)
	await frames(2)
	var sack: Treasure = game.world.map_objects.back() if game.world.map_objects.size() > n0 else null
	check(sack != null and sack.data.get("sack", false) and sack.reward().get("gold", 0) == 40, "changing his mode while carrying loot drops it")
	_bench_hero(true)
	# A gatherer picks it up and brings it home.
	game.economy.add("food", 200)
	while game.population.free_huts().is_empty():
		game.population.kill(game.population.civilians.back())
	var ga: Civilian = game.population.recruit("gatherer")
	var gold0 := game.economy.amount("gold")
	var picked := await wait_until(func() -> bool: return not is_instance_valid(sack) or sack.looted, 60.0)
	var paid := await wait_until(func() -> bool: return game.economy.amount("gold") >= gold0 + 40, 60.0)
	check(ga != null and picked and paid, "a gatherer picks up the dropped loot and brings it home (+40 gold)")


# --- icons and the Army tab ---------------------------------------------------------------------

func _test_ui() -> void:
	var hud := game.hud
	hud._refresh()
	var place: Button = hud._build_buttons["tower"]
	var rich: RichTextLabel = place.get_node_or_null("Rich")
	check(rich != null and "icon_materials.svg" in rich.text and Hud.button_text(place).contains("materials"), "costs show their icon (%s)" % Hud.button_text(place))
	check(place.text == "" and place.get_combined_minimum_size().x >= 100.0, "under the icons the button has no text of its own, and still its size (%.0f px)" % place.get_combined_minimum_size().x)
	var recruit: Button = hud._military_buttons["archer"]
	check(recruit.get_node_or_null("Rich") != null and "icon_gold.svg" in (recruit.get_node("Rich") as RichTextLabel).text, "gold costs show the gold icon")
	hud._refresh_hero()
	check(hud._hero_button.get_node_or_null("Rich") != null and "icon_xp.svg" in (hud._hero_button.get_node("Rich") as RichTextLabel).text and Hud.button_text(hud._hero_button).begins_with("XP "), "the hero's XP shows the XP icon")
	hud._hero_panel.visible = true
	hud._refresh_hero()
	check("icon_hp.svg" in hud._hero_stats.text and not "HP" in hud._hero_stats.text, "the hero panel shows his HP with a heart")
	hud._hero_panel.visible = false
	var hurt := game.army.recruit("archer")
	hurt.hp = hurt.max_hp() * 0.5
	hud._reserve_signature = ""
	hud._rebuild_reserve()
	var cards := hud._reserve_grid.get_children().filter(func(c: Node) -> bool: return c.get_node_or_null("Rich") != null)
	check(not cards.is_empty() and "icon_hp.svg" in (cards[0].get_node("Rich") as RichTextLabel).text and Hud.button_text(cards[0]).ends_with("HP"), "a hurt unit's card shows a heart and its HP")
	var page: Control = hud._reserve_grid.get_parent()
	var grid_i := -1
	for c in page.get_children():
		if c is GridContainer and c != hud._reserve_grid:
			grid_i = c.get_index()
	check(hud._reserve_grid.get_index() < grid_i, "the Army tab shows the units in stock above the recruiting")
	check(ResourceLoader.exists("res://art/icon_xp.svg") and ResourceLoader.exists("res://art/unit_rat.svg"), "the XP icon and the rat have their art")


# --- tear-down ---------------------------------------------------------------------------------

func find_spot(kind: String, near: Vector2i) -> Vector2i:
	var cands: Array = []
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			if game.construction.placement_error(kind, t) == "":
				cands.append([Vector2(t).distance_to(Vector2(near)), t])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in cands:
		var t: Vector2i = c[1]
		for nb in [t, t + Vector2i(1, 0), t + Vector2i(-1, 0), t + Vector2i(0, 1), t + Vector2i(0, -1)]:
			if game.world.pathing.is_walkable(nb) and not game.world.pathing.find_path(game.player_village.center, nb).is_empty():
				return t
	return Vector2i(-1, -1)


## Earlier tests kill villagers: makes sure one of `role` is there (a hut
## freed from a gatherer or explorer if need be).
func ensure_role(role: String) -> void:
	if game.population.count(role) > 0:
		return
	game.economy.add("food", 100)
	while game.population.free_huts().is_empty():
		var spare := game.population.civilians.filter(func(c: Civilian) -> bool: return c.role in ["gatherer", "explorer", "miner"])
		game.population.kill(spare.back() if not spare.is_empty() else game.population.civilians.back())
	game.population.recruit(role)


func built(kind: String) -> Building:
	game.economy.add("materials", 300)
	game.economy.add("gold", 300)
	var b := game.construction.place(kind, find_spot(kind, game.player_village.center + Vector2i(6, 6)))
	game.construction.queue.erase(b)
	b.progress = b.build_time
	game.construction.complete(b)
	return b


func _test_teardown() -> void:
	var v := game.player_village
	await clear_enemies()
	ensure_role("builder")
	# A manned tower: the unit leaves at once, a builder takes it down, 33 % back.
	var tower := built("tower") as Tower
	var u := game.army.recruit("archer")
	game.army.station(u, tower)
	await wait_until(func() -> bool: return u.state == MilitaryUnit.State.STATIONED, 60.0)
	var d := game.building_info(tower)
	var acts: Array = d["actions"]
	check(not acts.is_empty() and str(acts.back()["label"]).begins_with("Tear down"), "a finished building's panel ends with \"Tear down\" (%s)" % Config.plain_text(str(acts.back()["label"])))
	var mats := game.economy.amount("materials")
	check(game.command("tear_down", {"building": tower.nid})["ok"] and tower.tearing_down, "Tear down marks it, no questions asked")
	check(u.state != MilitaryUnit.State.STATIONED and tower.garrison == null and not tower.can_garrison(), "its unit leaves at once, and nobody can be stationed there")
	check(game.construction.queue.has(tower) and tower.has_work(), "it's a job for the builders now")
	var info_d := game.building_info(tower)
	check((info_d["actions"] as Array).any(func(x: Dictionary) -> bool: return x["label"] == "Stop tear-down"), "its panel offers \"Stop tear-down\"")
	var home := await wait_until(func() -> bool: return u.state == MilitaryUnit.State.RESERVE, 60.0)
	check(home, "the unit walks back into the reserve")
	var want := floori(Config.BUILDINGS["tower"]["cost"]["materials"] * Config.TEARDOWN_REFUND)
	var gone := await wait_until(func() -> bool: return not is_instance_valid(tower) or tower.is_queued_for_deletion(), 90.0)
	await frames(2)
	if not gone:
		print("    (builders %d, tower builder %s, %.0f%%, queue %s)" % [game.population.count("builder"), tower.builder, 100 * tower.work_fraction(), game.construction.queue.map(func(x: Building) -> String: return x.label())])
	check(gone and game.economy.amount("materials") >= mats + want and logs.any(func(l: String) -> bool: return "torn down: +%d materials" % want in l), "a builder tears it down: +%d materials (33 %%), logged" % want)
	# A barracks, upgraded once: the upgrade counts; a pending upgrade is refunded; stoppable.
	var b := built("barracks") as Barracks
	b.level = 2
	b.fit_slots()
	var spent: int = Config.BUILDINGS["barracks"]["cost"]["materials"] + Config.BARRACKS_LEVELS[1]["cost"]["materials"]
	check(b.teardown_refund() == floori(spent * Config.TEARDOWN_REFUND), "paid upgrades count towards the refund (%d)" % b.teardown_refund())
	game.construction.order_upgrade(b)
	var before := game.economy.amount("materials")
	game.command("tear_down", {"building": b.nid})
	check(not b.upgrading and game.economy.amount("materials") == before + int(Config.BARRACKS_LEVELS[2]["cost"].get("materials", 0)), "a pending upgrade is called off and refunded")
	check(game.command("stop_tear_down", {"building": b.nid})["ok"] and not b.tearing_down and b.working() and not game.construction.queue.has(b), "Stop tear-down: it works again as before")
	# A farm: its farmer is freed (or moves to another vacant farm); huts can't go.
	ensure_role("farmer")
	var f := built("farm") as Farm
	game.population.unassign_farmer(f)
	if farm.farmer == null:
		game.population.assign_farmer(farm)
	var worker: Civilian = farm.farmer
	game.command("tear_down", {"building": farm.nid})
	if not (worker != null and farm.farmer == null and worker.workplace() == f):
		print("    (worker %s, farm.farmer %s, now at %s, f %s, farms %s)" % [worker.label() if worker else "none", farm.farmer, worker.workplace().label() if worker and worker.workplace() else "-", f.label(), game.world.buildings.filter(func(x: Building) -> bool: return x is Farm).map(func(x: Building) -> String: return "%s:%s" % [x.label(), x.worker != null])])
	check(worker != null and farm.farmer == null and worker.workplace() == f, "a farm's farmer is freed at once and moves to a vacant farm")
	game.population.unassign_farmer(f)
	game.command("stop_tear_down", {"building": farm.nid})
	check(farm.farmer == worker, "spared, a free farmer takes it up again")
	var hut: Building = v.intact_huts()[0]
	check(not game.command("tear_down", {"building": hut.nid})["ok"] and not hut.can_tear_down(), "village huts can't be torn down")
	var wall: Building = game.world.buildings.filter(func(x: Building) -> bool: return x.kind == "wall_tower")[0]
	check(not wall.can_tear_down(), "nor the wall towers")
	# Barracks range on the map, like a tower's.
	game.select(b)
	check(is_equal_approx(game.world.overlay._range, b.activation_range()) and game.world.overlay._range_center == b.act_center(), "a selected barracks shows its range (%.1f)" % b.activation_range())
	game.deselect()
	check(not game.hud._recruit_rows.has("spatial_archmage"), "the Spatial Archmage isn't in the Village tab")


func _test_hero_bar() -> void:
	var hud := game.hud
	check(hud._hero_button.get_node_or_null("HealthBar") != null and hud._hero_hp_bar.size.y >= 6.0, "the hero button has a health bar along its bottom (%.0f px)" % hud._hero_hp_bar.size.y)
	check(hud.hero_hp_color(1.0) == hud.hero_hp_color(0.5) and hud.hero_hp_color(0.49) == hud.hero_hp_color(0.2) and hud.hero_hp_color(0.19) != hud.hero_hp_color(0.2) and hud.hero_hp_color(0.5) != hud.hero_hp_color(0.49), "green from 50 %, yellow from 20 %, red below")
	var h := game.hero
	h.hp = h.max_hp * 0.3
	check(is_equal_approx(hud.hero_hp_share(), 0.3), "it shows his share of HP")
	h.hp = h.max_hp


# --- a tower boxed in by trees -------------------------------------------------------------------

## The free tile next to a tower nearest the village can be a pocket cut off
## by trees; units must use a tile they can actually reach.
func _test_boxed_in_tower() -> void:
	var v := game.player_village
	await clear_enemies()
	var tower := built("tower") as Tower
	var t := tower.tile
	var toward := Vector2i((Vector2(v.center) - Vector2(t)).sign())  # the corner facing the village
	if toward.x == 0:
		toward.x = 1
	if toward.y == 0:
		toward.y = 1
	var pocket := t + toward
	var trees: Array[Vector2i] = []
	for d in [Vector2i(toward.x, 0), Vector2i(0, toward.y), toward * 2, Vector2i(toward.x * 2, toward.y), Vector2i(toward.x, toward.y * 2), Vector2i(toward.x * 2, 0), Vector2i(0, toward.y * 2)]:
		trees.append(t + d)
	var old := {}
	for tt in trees + [pocket]:
		old[tt] = game.map.get_terrain(tt)
	for tt in trees:
		game.map.set_terrain(tt, MapData.Terrain.FOREST)
		game.world.pathing.set_solid(tt, false)
	game.map.set_terrain(pocket, MapData.Terrain.GRASS)
	game.world.pathing.set_solid(pocket, false)
	var reach := game.world.pathing.find_path(v.center, tower.work_tile())
	var u := game.army.recruit("archer")
	var err := game.army.station_error(u, tower)
	check(err == "" and not reach.is_empty() and tower.work_tile() != pocket, "a tower whose nearest free side is cut off by trees can still be manned (%s)" % err)
	# Placing: a tower that nobody could reach once it's built is refused.
	var spot := find_spot("tower", v.center + Vector2i(-7, 6))
	var ring := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := spot + Vector2i(dx, dy)
			if n != spot:
				ring[n] = game.map.get_terrain(n)
				game.map.set_terrain(n, MapData.Terrain.FOREST)
				game.world.pathing.set_solid(n, false)
	var why := game.construction.placement_error("tower", spot)
	check(why.begins_with("Nobody could get to it"), "a tower ringed by trees can't be placed (%s)" % why)
	for n in ring:
		game.map.set_terrain(n, ring[n])
		game.world.pathing.set_solid(n, false)
	check(game.construction.placement_error("tower", spot) == "", "with a way next to it, it can")
	for tt in old:
		game.map.set_terrain(tt, old[tt])
		game.world.pathing.set_solid(tt, false)
	game.army.units.erase(u)


# --- the villager list -----------------------------------------------------------------------------

func _test_people() -> void:
	var hud := game.hud
	check(hud._pop_button.icon == Art.tex("icon_population") and hud._pop_button.text == "%d / %d" % [game.population.count(), game.population.cap()], "the people button shows civilians / huts (%s)" % hud._pop_button.text)
	hud._hero_panel.visible = true
	hud._pop_button.pressed.emit()
	var list := hud.people()
	check(hud._people_panel.visible and not hud._hero_panel.visible, "tapping it opens the villager list (and closes the hero panel)")
	check(hud._people_list.get_child_count() == list.size() and list.size() == game.population.count(), "one row per villager (%d)" % list.size())
	var c: Civilian = list[0]
	var status: RichTextLabel = hud._people_rows[c]
	check(status.get_meta("plain", "") == c.status_text(), "each row says what the villager does (%s: %s)" % [c.label(), c.status_text()])
	var orders := list.map(func(x: Civilian) -> int: return Config.CIVILIAN_ORDER.find(x.role))
	var sorted := orders.duplicate()
	sorted.sort()
	check(orders == sorted, "sorted by role")
	# Go to: the camera moves to the villager (outside) or the village centre (at home).
	var out: Civilian = null
	for x in list:
		if not x.at_home:
			out = x
	if out == null:
		out = list[-1]
		out.at_home = false
		out.visible = true
		out.set_grid_pos(Vector2(game.player_village.center + Vector2i(5, 5)))
	var row: Control = (hud._people_rows[out] as Control).get_parent().get_parent()
	var go: Button = row.get_child(row.get_child_count() - 1)
	go.pressed.emit()
	check(Hud.button_text(go) == "Go to" and game.camera.position.distance_to(out.position) < 2.0, "Go to moves the view to %s" % out.label())
	var home: Civilian = null
	for x in list:
		if x.at_home:
			home = x
	if home:
		hud.go_to_person(home)
		check(game.camera.position.distance_to(Iso.tile_to_world(game.player_village.center)) < 2.0, "for one at home: the village centre")
	# A new villager shows up in the list.
	var n := list.size()
	game.economy.add("food", 100)
	if game.population.free_huts().is_empty():
		game.population.kill(list[-1])
	game.population.recruit("builder")
	hud._refresh_people()
	check(hud._people_list.get_child_count() == hud.people().size(), "the list follows new villagers (%d -> %d)" % [n, hud.people().size()])
	# Destroyed huts: "Rebuild all huts" at the top queues them all.
	check(not hud._rebuild_huts_button.visible, "no destroyed hut: no rebuild button")
	var empty := game.player_village.intact_huts().filter(func(h: Building) -> bool: return not is_instance_valid((h as Hut).resident))
	for h in empty.slice(0, 3):
		(h as Hut).destroy("test")
	hud._refresh_people()
	var ruined := game.construction.ruined_huts().size()
	check(ruined == 3 and hud._rebuild_huts_button.visible and Hud.button_text(hud._rebuild_huts_button).begins_with("Rebuild all huts (3)") and hud._rebuild_huts_button.get_index() < hud._people_scroll.get_index(), "3 destroyed huts: \"%s\" at the top of the list" % Hud.button_text(hud._rebuild_huts_button))
	var per := int(Config.BUILDINGS["hut"]["cost"]["materials"])
	game.economy.add("materials", per * 2 - game.economy.amount("materials"))
	hud._rebuild_huts_button.pressed.emit()
	check(game.construction.ruined_huts().size() == 1 and game.construction.queue.filter(func(x: Building) -> bool: return x is Hut).size() == 2, "it queues as many as the material pays for (2 of 3)")
	game.economy.add("materials", per)
	hud._rebuild_huts_button.pressed.emit()
	hud._refresh_people()
	check(game.construction.ruined_huts().is_empty() and not hud._rebuild_huts_button.visible, "then the rest; the button goes away")
	hud.toggle_people(false)
	check(not hud._people_panel.visible, "and closes again")


# --- fog: every unit explores a little; explorers look into forest --------------------------------

func unexplore(tiles: Array[Vector2i]) -> void:
	var vid := game.player_village.id
	for t in tiles:
		game.fog.explored_of[vid][game.map.index(t)] = 0
		game.map.explored[game.map.index(t)] = 0


func around(c: Vector2i, r: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := int(ceil(r))
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var t := c + Vector2i(dx, dy)
			if game.map.in_bounds(t) and Vector2(dx, dy).length() <= r:
				out.append(t)
	return out


func _test_fog() -> void:
	var v := game.player_village
	var vid := v.id
	await clear_enemies()
	# The hero building (not exploring) uncovers the fog around him, and learns.
	game.fog.disabled = false  # (this bot plays without fog)
	var hero := game.hero
	_bench_hero(false)
	hero.set_mode(Hero.Mode.BUILD)
	await frames(2)
	hero.set_process(false)  # (stands still where we put him)
	var spot := game.world.pathing.nearest_walkable(v.center + Vector2i(9, -3))
	hero.at_home = false
	hero.visible = true
	hero.set_grid_pos(Vector2(spot))
	var patch := around(spot, 1.5)
	unexplore(patch)
	var xp0 := hero.xp
	await wait(0.6)
	check(patch.all(func(t: Vector2i) -> bool: return game.fog.is_explored_by(vid, t)) and hero.xp > xp0, "the hero in Build mode uncovers the fog around him and earns XP (+%d)" % (hero.xp - xp0))
	hero.set_process(true)
	hero.set_mode(Hero.Mode.REST)
	_bench_hero(true)
	# So does a villager at work (no XP: only the hero learns).
	ensure_role("gatherer")
	var ga: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "gatherer")[0]
	ga.set_process(false)
	ga.at_home = false
	ga.visible = true
	var spot2 := game.world.pathing.nearest_walkable(v.center + Vector2i(-9, 4))
	ga.set_grid_pos(Vector2(spot2))
	var patch2 := around(spot2, 1.5)
	unexplore(patch2)
	await wait(0.6)
	check(patch2.all(func(t: Vector2i) -> bool: return game.fog.is_explored_by(vid, t)), "a villager outside uncovers the fog around it too")
	ga.set_process(true)
	ga.arrive_home()
	game.fog.disabled = true
	# Unexplored forest next to open land: the explorer goes to its edge and looks in.
	game.fog.reveal_all()
	var edge := Vector2i(-1, -1)
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			if edge == Vector2i(-1, -1) and game.map.get_terrain(t) == MapData.Terrain.FOREST and Vector2(t).distance_to(Vector2(v.center)) < 20.0:
				for nb in [t + Vector2i(1, 0), t + Vector2i(-1, 0), t + Vector2i(0, 1), t + Vector2i(0, -1)]:
					if game.world.pathing.is_walkable(nb) and game.world.pathing.can_reach(v.center, nb):
						edge = t
	var woods: Array[Vector2i] = around(edge, 1.5).filter(func(t: Vector2i) -> bool: return game.map.get_terrain(t) == MapData.Terrain.FOREST)
	unexplore(woods)
	ensure_role("explorer")
	var ex: Explorer = game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "explorer")[0]
	var goal := ex.job.choose_target(v.center)
	check(woods.has(goal) and game.world.pathing.is_walkable(ex.job.stand) and Vector2(ex.job.stand).distance_to(Vector2(goal)) < 1.5, "fog over forest by open land is a target: the explorer stands at its edge (%s for %s)" % [ex.job.stand, goal])
	var seen := await wait_until(func() -> bool: return woods.all(func(t: Vector2i) -> bool: return game.fog.is_explored_by(vid, t)), 90.0)
	check(seen, "and uncovers it from there")
	# Land cleared of trees: walkable, reachable and explored like any other.
	var wall: Array[Vector2i] = []
	var base := game.world.pathing.nearest_walkable(v.center + Vector2i(0, 10))
	for dx in range(-6, 7):
		wall.append(base + Vector2i(dx, 2))
	var keep := {}
	for t in wall:
		keep[t] = game.map.get_terrain(t)
		game.map.set_terrain(t, MapData.Terrain.FOREST)
		game.world.pathing.set_solid(t, false)
	var beyond := base + Vector2i(0, 4)
	game.map.set_terrain(beyond, MapData.Terrain.GRASS)
	game.world.pathing.set_solid(beyond, false)
	var blocked := game.world.pathing.find_path(base, beyond).size()
	for t in wall.slice(5, 8):
		game.world.remove_tree(t)
	var cut: Array[Vector2i] = wall.slice(5, 8)
	var path := game.world.pathing.find_path(base, beyond)
	var through := false
	for p in path:
		through = through or cut.has(Vector2i(p))
	check(game.world.pathing.can_reach(base, wall[6]) and not path.is_empty() and (through or blocked > 0), "paths lead through a cut forest (%d steps)" % path.size())
	unexplore(cut)
	var goal2 := ex.job.choose_target(base)
	check(cut.has(goal2) and ex.job.stand == goal2, "unexplored cleared land is walked onto (%s)" % goal2)
	for t in keep:
		game.map.set_terrain(t, keep[t])
		game.world.pathing.set_solid(t, false)


# --- inside the walls is safe ----------------------------------------------------------------

func _test_safe_walls() -> void:
	var v := game.player_village
	await clear_enemies()
	ensure_role("builder")
	var hut: Hut = null
	for h in v.intact_huts():
		if hut == null and not is_instance_valid((h as Hut).resident):
			hut = h
	if hut == null:
		hut = v.intact_huts()[0]
	hut.destroy("test")
	# A goblin right outside the nearest gate, rooted there.
	var gate: Vector2i = v.gates[0]
	for g in v.gates:
		if Vector2(g).distance_to(Vector2(hut.tile)) < Vector2(gate).distance_to(Vector2(hut.tile)):
			gate = g
	var out := gate + (gate - v.center).sign()
	var gob := spawn("goblin", Vector2(game.world.pathing.nearest_walkable(out)), 50.0)
	gob.speed = 0.0
	check(Vector2(hut.tile).distance_to(gob.grid_pos) < Config.EVADE_RADIUS, "(a goblin %.1f tiles from the ruined hut, outside the gate)" % Vector2(hut.tile).distance_to(gob.grid_pos))
	var b: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "builder")[0]
	var fled := false
	game.economy.add("materials", 100)
	game.construction.order_rebuild(hut)
	var built := false
	var t := 0.0
	while t < 60.0 and not built:
		await get_tree().process_frame
		t += get_process_delta_time()
		fled = fled or b.evading
		built = hut.is_intact()
	check(built and not fled, "a builder rebuilds a hut inside the walls with a goblin at the gate, and doesn't flee")
	# Inside the walls nobody can be hurt.
	b.set_process(false)
	b.at_home = false
	b.visible = true
	b.set_grid_pos(Vector2(hut.tile))
	var hp0 := b.hp
	b.take_damage(5.0, gob)
	check(b.inside_walls() and not b.is_exposed() and b.hp == hp0, "inside the walls a villager can't be hurt")
	b.set_grid_pos(Vector2(game.world.pathing.nearest_walkable(out + (gate - v.center).sign() * 2)))
	check(not b.inside_walls() and b.is_exposed(), "outside it can")
	b.set_process(true)
	b.arrive_home()
	await clear_enemies()


# --- rats move on from empty farms -----------------------------------------------------------------

func _test_rats_give_up() -> void:
	await clear_enemies()
	var farms: Array = game.world.buildings.filter(func(x: Building) -> bool: return x is Farm and x.working())
	var decoy: Farm = farms[0]
	# A bare farm (nothing stored, nobody working it): rats don't stay.
	game.population.unassign_farmer(decoy)
	decoy.stored = 0.0
	decoy.since_gain = 100.0
	var road := game.world.pathing.nearest_road(decoy.tile)
	var r := spawn("rat", Vector2(road))
	var came := await wait_until(func() -> bool: return decoy.rats.has(r), 20.0)
	var t0 := 0.0
	var left := false
	while t0 < 12.0 and not left:
		await get_tree().process_frame
		t0 += get_process_delta_time()
		left = not is_instance_valid(r) or r.dead or (r.behavior as RatBehavior).ignored.has(decoy)
	check(came and left and t0 < 10.0, "a rat on an empty, barren farm gives it up within seconds (%.1f s)" % t0)
	var back := false
	for k in 120:
		await get_tree().process_frame
		back = back or (is_instance_valid(r) and decoy.rats.has(r))
	check(not back, "and never goes back to it")
	await clear_enemies()
	# A stocked farm: eaten empty first; 15 s after its last growth they move on, before 30 s.
	decoy.stored = 2.0
	decoy.since_gain = 0.0
	var pack: Array = []  # (untyped: rats that moved on and left are freed)
	for k in 3:
		pack.append(spawn("rat", Vector2(road) + Vector2(0.3 * k, 0.0)))
	await wait_until(func() -> bool: return pack.all(func(x) -> bool: return decoy.rats.has(x)), 20.0)
	check(decoy.barren(0.0) == false, "(it has food at first)")
	var t := 0.0
	var gone := false
	var gave_up := {}  # rat -> how long the farm had grown nothing when it gave up
	while t < 40.0 and not gone:
		await get_tree().process_frame
		t += get_process_delta_time()
		gone = true
		for x in pack:
			if is_instance_valid(x) and not x.dead:
				if (x.behavior as RatBehavior).ignored.has(decoy):
					if not gave_up.has(x):
						gave_up[x] = decoy.since_gain
				else:
					gone = false
	var earliest: float = gave_up.values().min() if not gave_up.is_empty() else -1.0
	check(gone and not gave_up.is_empty() and decoy.stored <= 0.001 and earliest >= Config.ENEMIES["rat"]["give_up_after"] - 0.05 and t < Config.ENEMIES["rat"]["vanish_after"], "they eat it empty, then move on once it grew nothing for %.0f s (first at %.1f s, all within %.0f s of arriving: before vanishing at %.0f s)" % [Config.ENEMIES["rat"]["give_up_after"], earliest, t, Config.ENEMIES["rat"]["vanish_after"]])
	await clear_enemies()
