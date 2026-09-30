extends Node
## Headless test of the thief, the gargoyle and the necromancer. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/enemy_bot.tscn
## Exits 0 when every check passes.

const SEED := 778

var failures: Array[String] = []
var checks := 0
var game: Game
var logs: Array[String] = []
## Levels of the "raised from the dead" log lines.
var raise_levels: Array[int] = []


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
	game.player_village.events.logged.connect(func(l: int, text: String) -> void:
		logs.append(text)
		if "raised" in text:
			raise_levels.append(l))
	Engine.time_scale = 6.0
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	_bench_hero(true)
	await _test_thief()
	await _test_gargoyle()
	await _test_necromancer()
	await _test_fog_corpses()
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


## An enemy of `kind` at `at`. `walk`: it walks the roads from there to the
## village; else it stands still.
func spawn(kind: String, at: Vector2, hp_scale: float = 1.0, walk: bool = false) -> Enemy:
	game.waves._spawn({"kind": kind, "spawn": game.map.edge_spawns[0], "hp_scale": hp_scale, "village": game.player_village})
	var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
	e.set_grid_pos(at)
	if walk:
		var road := game.world.pathing.nearest_road(Vector2i(at.round()))
		var route := game.world.pathing.enemy_route(road, RandomNumberGenerator.new(), -1)
		var pts := PackedVector2Array([at])
		for t in route:
			pts.append(Vector2(t))
		e.follow(pts)
	else:
		e.speed = 0.0
		e.follow(PackedVector2Array([at, at + Vector2(0.001, 0)]))
	return e


func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			e.take_damage(1e9)
	await frames(3)


func clear_corpses() -> void:
	for c in game.corpses.corpses.duplicate():
		game.corpses.remove(c)
	await frames(2)


func ensure_role(role: String) -> Civilian:
	for c in game.population.civilians:
		if c.role == role:
			return c
	game.economy.add("food", 100)
	while game.population.free_huts().is_empty():
		var spare := game.population.civilians.filter(func(c: Civilian) -> bool: return c.role in ["explorer", "miner"])
		game.population.kill(spare.back() if not spare.is_empty() else game.population.civilians.back())
	return game.population.recruit(role)


## A road tile about `steps` road tiles out from a gate.
func road_out(steps: int) -> Vector2i:
	var v := game.player_village
	var gate: Vector2i = v.gates[0]
	var t := gate
	var seen := {gate: true}
	for i in steps:
		var nxt := t
		for n in MapData.neighbors4(t):
			if game.map.is_road(n) and not seen.has(n) and not game.map.in_village(n):
				nxt = n
				break
		if nxt == t:
			break
		seen[nxt] = true
		t = nxt
	return t


# --- config --------------------------------------------------------------------------------------

func _test_config() -> void:
	var E := Config.ENEMIES
	check(E["thief"]["speed"] > E["goblin"]["speed"] and E["thief"]["speed"] < E["rat"]["speed"] and E["thief"]["hp"] == E["goblin"]["hp"] and E["thief"]["damage"] == E["goblin"]["damage"], "the thief: a goblin's strength, quicker (%.1f)" % E["thief"]["speed"])
	check(E["thief"]["gold_on_kill"] > 0 and E["thief"]["gold_on_collect"] > 0 and E["thief"]["food_on_collect"] == 0, "a thief pays a little gold at once and as a corpse, no food")
	check(E["gargoyle"].get("flying", false) and is_equal_approx(E["gargoyle"]["speed"], E["ork"]["speed"]) and E["gargoyle"]["gold_on_kill"] > 0 and E["gargoyle"]["gold_on_collect"] == 0 and E["gargoyle"]["food_on_collect"] > 0, "the gargoyle flies, as slow as an ork; kill gold, a corpse of food only")
	check(E["necromancer"]["speed"] < E["skeleton"]["speed"] and E["necromancer"]["speed"] > E["ork"]["speed"] and E["necromancer"]["damage"] == 0.0 and E["necromancer"]["hp"] == E["goblin"]["hp"], "the necromancer: between skeleton and ork in speed, goblin HP, no attack")
	check(E["necromancer"]["gold_on_kill"] >= 4 * E["goblin"]["gold_on_kill"] and E["necromancer"]["gold_on_collect"] == 0 and E["necromancer"]["food_on_collect"] == 0 and not E["necromancer"].get("revivable", true), "much gold on kill; its corpse yields nothing and can't be raised")
	var firsts := {}
	for kind in ["thief", "gargoyle", "necromancer"]:
		for n in range(1, 30):
			if Config.wave_composition(n).has(kind):
				firsts[kind] = n
				break
	check(firsts.get("thief") == 7 and firsts.get("gargoyle") == 10 and firsts.get("necromancer") == 20, "they join from waves 7, 10 and 20 (%s)" % str(firsts))
	var late := Config.wave_composition(40)
	check(late.has(Config.WAVE_FILLER) and late.has("necromancer") and late.has("skeleton"), "late waves still have some of everything (%s)" % str(late))
	for kind in ["thief", "gargoyle", "necromancer"]:
		check(ResourceLoader.exists("res://art/unit_%s.svg" % kind) and ResourceLoader.exists("res://art/corpse_%s.svg" % kind), "%s art and corpse" % kind)
	check(ResourceLoader.exists("res://art/unit_gargoyle_flap.svg"), "the gargoyle has a second wing pose")


# --- thief ---------------------------------------------------------------------------------------------

func _test_thief() -> void:
	var v := game.player_village
	game.waves.wave = 10
	v.economy.add("gold", 500 - v.economy.amount("gold"))
	var huts := v.intact_huts().size()
	var start := Vector2(road_out(6))
	var th := spawn("thief", start, 1.0, true)
	var stole := await wait_until(func() -> bool: return th.loot_gold > 0 or th.dead, 30.0)
	var taken := 500 - int(v.economy.amount("gold"))
	# max(randi(10, 20), 4 % of 500 = 20) = 20
	check(stole and taken == 20 and th.loot_gold == 20 and not th.dead and v.intact_huts().size() == huts, "at the gate a thief steals max(wave..2x wave, 4 %%) of the gold (%d) and burns no hut" % taken)
	check(logs.any(func(l: String) -> bool: return "stole 20 gold" in l) and th._sack != null and th._sack.visible, "logged; it carries a sack of coins")
	await wait(1.0)
	check(not th.dead and th.grid_pos.distance_to(start) < th.path[th.path_index - 1].distance_to(Vector2(v.gates[0])) + 50.0 and (th.behavior as ThiefBehavior).escaping, "it runs back the way it came")
	# Killed on the way: its gold at once, the loot in its corpse; a gatherer brings it all home.
	var gold0 := int(v.economy.amount("gold"))
	th.take_damage(1e9)
	await frames(2)
	var paid := int(v.economy.amount("gold")) - gold0
	var c: Corpse = game.corpses.corpses.back() if not game.corpses.corpses.is_empty() else null
	check(paid == Config.enemy_stat_int("thief", "gold_on_kill") and c != null and c.kind == "thief" and c.extra_gold == 20, "killed: +%d gold at once; its corpse holds the 20 stolen" % paid)
	var ga := ensure_role("gatherer")
	var gold1 := int(v.economy.amount("gold"))
	var home := await wait_until(func() -> bool: return int(v.economy.amount("gold")) >= gold1 + 20 + Config.enemy_stat_int("thief", "gold_on_collect"), 120.0)
	check(ga != null and home, "a gatherer brings the corpse home: its value plus the stolen gold (+%d)" % (int(v.economy.amount("gold")) - gold1))
	# One that gets away takes the gold with it.
	v.economy.add("gold", 300 - v.economy.amount("gold"))
	var th2 := spawn("thief", Vector2(road_out(3)), 1.0, true)
	var away := await wait_until(func() -> bool: return th2.dead or not is_instance_valid(th2), 60.0)
	check(away and int(v.economy.amount("gold")) < 300 and logs.any(func(l: String) -> bool: return "got away with" in l), "one that makes it back is gone with the gold")
	await clear_enemies()
	await clear_corpses()


# --- gargoyle -------------------------------------------------------------------------------------------

func _test_gargoyle() -> void:
	var v := game.player_village
	# Flying: no ground slows it.
	var slow := Vector2i(-1, -1)
	for y in game.map.size:
		for x in game.map.size:
			if slow == Vector2i(-1, -1) and game.map.walk_factor(Vector2i(x, y)) < 1.0:
				slow = Vector2i(x, y)
	var gob := spawn("goblin", Vector2(slow))
	var ga := spawn("gargoyle", Vector2(slow))
	check(slow != Vector2i(-1, -1) and gob._walk_factor() < 1.0 and ga._walk_factor() == 1.0 and ga.flies(), "swamps and fords slow a goblin (x%.1f), not a gargoyle" % gob._walk_factor())
	# It looks like it flies: wings beat, it bobs, its shadow stays below.
	var arts := {}
	var offs := {}
	for k in 40:
		await get_tree().process_frame
		arts[ga.sprite.texture] = true
		offs[snappedf(ga.sprite.offset.y, 0.5)] = true
	check(arts.size() == 2 and offs.size() > 3 and ga._shadow != null and ga._shadow.get_index() == 0, "it flaps its wings (2 poses), bobs up and down, and casts a shadow")
	await clear_enemies()
	# Ground melee can't go for it; ranged can.
	var gate: Vector2i = v.gates[0]
	var near := Vector2(road_out(2))
	var g2 := spawn("gargoyle", near, 5.0)
	_bench_hero(false)
	game.hero.set_mode(Hero.Mode.DEFEND)
	await frames(2)
	check(game.hero._pick_enemy() == null, "the hero doesn't go for a gargoyle at the gate")
	var el: EarthElemental = preload("res://scripts/units/earth_elemental.gd").new()
	el.village = v
	el.setup(game, Vector2i(near.round()), Vector2i(near.round()) + Vector2i(1, 0), 50.0, 5.0, "earth")
	game.world.objects.add_child(el)
	el._pick_target()
	var earth_t := el.target
	var fire: EarthElemental = preload("res://scripts/units/earth_elemental.gd").new()
	fire.village = v
	fire.setup(game, Vector2i(near.round()), Vector2i(near.round()) + Vector2i(1, 0), 50.0, 5.0, "fire")
	game.world.objects.add_child(fire)
	fire._pick_target()
	check(earth_t == null and fire.target == g2, "an earth elemental can't go for it; a fire elemental (a flyer too) can")
	el.crumble()
	fire.crumble()
	await frames(2)
	var tw: Tower = game.world.towers().filter(func(t: Tower) -> bool: return Vector2(t.tile).distance_to(near) <= t.range_tiles())[0] if game.world.towers().any(func(t: Tower) -> bool: return Vector2(t.tile).distance_to(near) <= t.range_tiles()) else null
	var ar := game.army.recruit("archer")
	if tw:
		game.army.station(ar, tw)
	var hp0 := g2.hp
	var shot := await wait_until(func() -> bool: return g2.hp < hp0 or g2.dead, 60.0)
	check(tw != null and shot, "an archer on a tower shoots it")
	game.army.unstation(ar)
	await clear_enemies()
	# Counter-strikes: it hits the hero; his blow is ready, so he hits back.
	var hero := game.hero
	hero.max_hp = 5000.0
	hero.hp = 5000.0
	var g3 := spawn("gargoyle", hero.grid_pos + Vector2(0.6, 0.0), 5.0)
	hero.at_home = false
	var hp3 := g3.hp
	var hit_back := await wait_until(func() -> bool: return g3.hp < hp3, 20.0)
	check(hit_back and hero.target != g3 and hero.hp < 5000.0, "hit by a gargoyle, the hero strikes back (it loses %.0f HP), though he never goes for it" % (hp3 - g3.hp))
	hero.set_mode(Hero.Mode.REST)
	_bench_hero(true)
	await clear_enemies()
	# Barracks with only melee benches don't turn out for a lone flyer.
	var spot := Vector2i(-1, -1)
	for y in range(v.center.y - 12, v.center.y + 12):
		for x in range(v.center.x - 12, v.center.x + 12):
			if spot == Vector2i(-1, -1) and game.construction.placement_error("barracks", Vector2i(x, y)) == "" and Vector2(x, y).distance_to(Vector2(v.center)) > 6:
				spot = Vector2i(x, y)
	game.economy.add("materials", 300)
	game.economy.add("gold", 300)
	var b: Barracks = game.construction.place("barracks", spot)
	game.construction.queue.erase(b)
	b.progress = b.build_time
	game.construction.complete(b)
	var sb := game.army.recruit("shield_bearer")
	game.army.station(sb, b)
	await wait_until(func() -> bool: return sb.state == MilitaryUnit.State.STATIONED, 60.0)
	var g4 := spawn("gargoyle", b.act_center() + Vector2(1.5, 1.5), 5.0)
	await wait(2.0)
	check(not sb.out, "a barracks with only melee units doesn't turn out for a gargoyle")
	game.army.unstation(sb)
	await clear_enemies()
	await clear_corpses()


# --- necromancer --------------------------------------------------------------------------------------------

func _test_necromancer() -> void:
	var v := game.player_village
	await clear_enemies()
	await clear_corpses()
	var at := Vector2(road_out(8))
	var c := game.corpses.spawn("goblin", game.waves.wave, at + Vector2(1.5, 0.0))
	c.hp_scale = 2.0
	var nec := spawn("necromancer", at)
	var nb := nec.behavior as NecromancerBehavior
	var started := await wait_until(func() -> bool: return nb.corpse == c, 5.0)
	check(started and nec.channel_to == c.grid_pos and c.raising_by == nec, "a necromancer stops at a corpse and channels on it (the green beam)")
	await wait(Config.ENEMIES["necromancer"]["cast_time"] * 0.6)
	check(game.corpses.corpses.has(c), "slowly: nothing rises before its cast time is up")
	var risen := await wait_until(func() -> bool: return not game.corpses.corpses.has(c), 10.0)
	var raised: Array = get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.raised)
	var g: Enemy = raised[0] if not raised.is_empty() else null
	check(risen and g != null and g.kind == "goblin", "then the corpse rises as a goblin again")
	if g == null:
		return
	var full: float = Config.enemy_stat("goblin", "hp") * 2.0
	check(is_equal_approx(g.max_hp, full * 0.5) and g.modulate.g > g.modulate.r, "with half the HP of the original (%.0f of %.0f), pale and green" % [g.max_hp, full])
	check(raise_levels.size() == 1 and raise_levels[0] == EventLog.Level.INFO and logs.any(func(l: String) -> bool: return "A necromancer raised a dead goblin" in l), "the first raise is logged (Info)")
	check(nec.channel_to == Vector2.INF and nb.corpse == null, "the necromancer walks on")
	# Right after a raise it won't start the next spell for a while.
	var c3 := game.corpses.spawn("ork", game.waves.wave, nec.grid_pos + Vector2(-1.0, 0.5))
	var soon := await wait_until(func() -> bool: return nb.corpse == c3, Config.ENEMIES["necromancer"]["cast_time"] * 0.5)
	check(not soon, "after a raise it walks on for a while before the next spell")
	# Its HP drains away; decayed it pays nothing and can't rise again.
	var h1 := g.hp
	await wait(2.0)
	var rate := (h1 - g.hp) / 2.0
	check(rate > 0.0 and absf(rate - g.max_hp / Config.ENEMIES["necromancer"]["raise_decay"]) < g.max_hp * 0.05, "its HP drains to 0 over %.0f s (%.2f HP/s)" % [Config.ENEMIES["necromancer"]["raise_decay"], rate])
	var gold0 := int(v.economy.amount("gold"))
	g.speed = 0.0
	var seen := {}
	var decayed := await wait_until(func() -> bool:
		if g.dead:
			seen["decayed"] = g.decayed
		return g.dead, 30.0)
	await frames(2)
	var c2: Corpse = null
	for x in game.corpses.corpses:
		if x.kind == "goblin":
			c2 = x
	check(decayed and seen.get("decayed", false) and int(v.economy.amount("gold")) == gold0 and c2 != null and not c2.revivable, "decayed: no gold, and its corpse can't be raised again")
	# The second raise (the ork, after the cooldown): logged at Debug only; killed, half the gold.
	var again := await wait_until(func() -> bool: return not game.corpses.corpses.has(c3), 30.0)
	var orc: Enemy = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.raised and e.kind == "ork" and not e.dead:
			orc = e
	check(again and orc != null and raise_levels.size() == 2 and raise_levels[1] == EventLog.Level.DEBUG, "the next raise is logged at Debug only")
	if orc:
		var gold1 := int(v.economy.amount("gold"))
		orc.take_damage(1e9, game.hero)
		await frames(2)
		var got := int(v.economy.amount("gold")) - gold1
		check(got == floori(Config.enemy_stat_int("ork", "gold_on_kill") * 0.5), "a raised ork killed pays half an ork's gold, rounded down (%d)" % got)
	# Never its own kind, nor corpses already claimed; a lost corpse ends the spell.
	await clear_corpses()
	var nc := game.corpses.spawn("necromancer", game.waves.wave, nec.grid_pos + Vector2(1.0, 0.0))
	nb._cool = 0.0
	await wait(1.5)
	check(nb.corpse == null and not nc.revivable, "a necromancer's corpse can't be raised")
	await clear_corpses()
	var c4 := game.corpses.spawn("goblin", game.waves.wave, nec.grid_pos + Vector2(1.0, 0.0))
	nb._cool = 0.0
	await wait_until(func() -> bool: return nb.corpse == c4, 5.0)
	game.corpses.remove(c4)
	await wait(1.0)
	check(nb.corpse == null and nec.channel_to == Vector2.INF and not get_tree().get_nodes_in_group("enemies").any(func(e: Enemy) -> bool: return e.raised and not e.dead), "the corpse gone mid-spell: the cast is lost")
	# Killed, it pays a lot; its corpse is worth nothing.
	var gold2 := int(v.economy.amount("gold"))
	nec.take_damage(1e9, game.hero)
	await frames(2)
	check(int(v.economy.amount("gold")) - gold2 == Config.enemy_stat_int("necromancer", "gold_on_kill") and game.corpses.corpses.any(func(x: Corpse) -> bool: return x.kind == "necromancer"), "killed: +%d gold; it leaves a corpse" % (int(v.economy.amount("gold")) - gold2))


# --- corpses in the fog --------------------------------------------------------------------------

func _test_fog_corpses() -> void:
	var v := game.player_village
	await clear_enemies()
	await clear_corpses()
	var ga := ensure_role("gatherer")
	var t := road_out(5)
	var explorers := game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "explorer")
	for ex in explorers:
		ex.set_process(false)  # (they would go and explore it)
	var hidden := game.corpses.spawn("goblin", game.waves.wave, Vector2(t))
	game.fog.explored_of[v.id][game.map.index(t)] = 0
	await wait(8.0)
	check(game.corpses.corpses.has(hidden) and hidden.claimed_by == null, "a corpse in the fog (unexplored land) isn't gathered")
	game.fog.explored_of[v.id][game.map.index(t)] = 1
	var taken := await wait_until(func() -> bool: return not game.corpses.corpses.has(hidden), 60.0)
	check(ga != null and taken, "once that land is explored, a gatherer fetches it")
	for ex in explorers:
		ex.set_process(true)
