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
	# A fire mage's explosion catches several of them.
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
	b.progress = 1.0
	b.finish()
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
	check(rich != null and "icon_materials.svg" in rich.text and place.text.contains("materials"), "costs show their icon (%s)" % place.text)
	var recruit: Button = hud._military_buttons["archer"]
	check(recruit.get_node_or_null("Rich") != null and "icon_gold.svg" in (recruit.get_node("Rich") as RichTextLabel).text, "gold costs show the gold icon")
	hud._refresh_hero()
	check(hud._hero_button.get_node_or_null("Rich") != null and "icon_xp.svg" in (hud._hero_button.get_node("Rich") as RichTextLabel).text and hud._hero_button.text.begins_with("XP "), "the hero's XP shows the XP icon")
	var page: Control = hud._reserve_grid.get_parent()
	var grid_i := -1
	for c in page.get_children():
		if c is GridContainer and c != hud._reserve_grid:
			grid_i = c.get_index()
	check(hud._reserve_grid.get_index() < grid_i, "the Army tab shows the units in stock above the recruiting")
	check(ResourceLoader.exists("res://art/icon_xp.svg") and ResourceLoader.exists("res://art/unit_rat.svg"), "the XP icon and the rat have their art")
