extends "res://tests/bot_base.gd"
## Headless test of the thief, the gargoyle, the necromancer, the vampire
## and the monster lairs. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/enemy_bot.tscn
## Exits 0 when every check passes.

const SEED := 778

var logs: Array[String] = []
## Levels of the "raised from the dead" log lines.
var raise_levels: Array[int] = []


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
	await _test_kill_xp()
	await _test_thief()
	await _test_gargoyle()
	await _test_necromancer()
	await _test_fog_corpses()
	await _test_vampire()
	await _test_lairs()
	await _test_slimes()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


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


## The hero's blow that kills an enemy earns HERO_XP_PER_ACTION "kill" on top of its "hit".
func _test_kill_xp() -> void:
	var hero := game.hero
	var per_hit := int(Config.HERO_XP_PER_ACTION["hit"])
	var bonus := int(Config.HERO_XP_PER_ACTION["kill"])
	check(bonus == 10, "the kill bonus is 10 XP")
	var g := spawn("goblin", Vector2(game.player_village.center) + Vector2(1, 0), 1000.0)
	var xp0: int = hero.xp
	hero._strike(g)
	check(not g.dead and hero.xp - xp0 == per_hit, "a hit that doesn't kill: %d XP (+%d)" % [per_hit, hero.xp - xp0])
	g.hp = 0.1
	xp0 = hero.xp
	hero._strike(g)
	check(g.dead and hero.xp - xp0 == per_hit + bonus, "the last hit: %d + %d XP (+%d)" % [per_hit, bonus, hero.xp - xp0])
	await frames(2)


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
	var enemies := Config.ENEMIES
	check(enemies["thief"]["speed"] > enemies["goblin"]["speed"] and enemies["thief"]["speed"] < enemies["rat"]["speed"] and enemies["thief"]["hp"] == enemies["goblin"]["hp"] and enemies["thief"]["damage"] == enemies["goblin"]["damage"], "the thief: a goblin's strength, quicker (%.1f)" % enemies["thief"]["speed"])
	check(enemies["thief"]["gold_on_kill"] > 0 and enemies["thief"]["gold_on_collect"] > 0 and enemies["thief"]["food_on_collect"] == 0, "a thief pays a little gold at once and as a corpse, no food")
	check(enemies["gargoyle"].get("flying", false) and is_equal_approx(enemies["gargoyle"]["speed"], enemies["ork"]["speed"]) and enemies["gargoyle"]["gold_on_kill"] > 0 and enemies["gargoyle"]["gold_on_collect"] == 0 and enemies["gargoyle"]["food_on_collect"] > 0, "the gargoyle flies, as slow as an ork; kill gold, a corpse of food only")
	check(enemies["necromancer"]["speed"] < enemies["skeleton"]["speed"] and enemies["necromancer"]["speed"] > enemies["ork"]["speed"] and enemies["necromancer"]["damage"] == 0.0 and enemies["necromancer"]["hp"] == enemies["goblin"]["hp"], "the necromancer: between skeleton and ork in speed, goblin HP, no attack")
	check(enemies["necromancer"]["gold_on_kill"] >= 4 * enemies["goblin"]["gold_on_kill"] and enemies["necromancer"]["gold_on_collect"] == 0 and enemies["necromancer"]["food_on_collect"] == 0 and not enemies["necromancer"].get("revivable", true), "much gold on kill; its corpse yields nothing and can't be raised")
	check(enemies["witch"]["spell_range"] <= Config.TOWER_RANGE["tower"] + Config.TOWER_LEVELS[0]["range_bonus"], "a witch can't outrange a level 1 watchtower (%.1f vs %.1f)" % [enemies["witch"]["spell_range"], Config.TOWER_RANGE["tower"]])
	var firsts := {}
	for kind in ["thief", "gargoyle", "necromancer"]:
		for n in range(1, 30):
			if Config.wave_composition(n).has(kind):
				firsts[kind] = n
				break
	var want := {}
	for kind in ["thief", "gargoyle", "necromancer"]:
		want[kind] = Config.WAVE_MIX[kind]["from_wave"]
	check(firsts == want, "they join from their waves (%s)" % str(firsts))
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
	var again := await wait_until(func() -> bool: return raise_levels.size() >= 2, 30.0)
	check(again and raise_levels[1] == EventLog.Level.DEBUG, "the next raise is logged at Debug only")
	var orc: Enemy = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.raised and e.kind == "ork" and not e.dead:
			orc = e
	if orc == null:  # (it may have drained away already: raise a fresh one)
		var c5 := game.corpses.spawn("ork", game.waves.wave, nec.grid_pos + Vector2(0.5, 1.0))
		nb._cool = 0.0
		await wait_until(func() -> bool: return not game.corpses.corpses.has(c5), 20.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.raised and e.kind == "ork" and not e.dead:
				orc = e
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
	# One of our fighters near: it stands and waits for its next raise.
	await clear_corpses()
	nec.speed = Config.ENEMIES["necromancer"]["speed"]
	var road := game.world.pathing.nearest_road(Vector2i(nec.grid_pos.round()))
	var route := game.world.pathing.enemy_route(road, RandomNumberGenerator.new(), -1)
	var pts := PackedVector2Array([nec.grid_pos])
	for t in route:
		pts.append(Vector2(t))
	nec.follow(pts)
	var hero := game.hero
	hero.add_to_group("melee_defenders")  # (benched: he stands there, it doesn't fight)
	hero.set_grid_pos(nec.grid_pos + Vector2(1.5, 0.0))
	var p0 := nec.grid_pos
	await wait(2.0)
	var held := nec.grid_pos.distance_to(p0) < 0.05
	hero.set_grid_pos(Vector2(v.center))
	hero.remove_from_group("melee_defenders")
	await wait(2.0)
	check(held and nec.grid_pos.distance_to(p0) > 0.5, "a fighter of ours near: the necromancer stands and waits; gone: it walks on")
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


# --- vampire and damage categories ------------------------------------------------------------------

func _test_vampire() -> void:
	var v := game.player_village
	var enemies := Config.ENEMIES
	await clear_enemies()
	await clear_corpses()
	check(Config.ATTACKS.values().all(func(a: Dictionary) -> bool: return Config.DAMAGE_CATEGORIES.has(a.get("category", ""))) and enemies["witch"]["attack_category"] == "magical", "every attack has a damage category (the witch's is magical)")
	var first := -1
	for n in range(1, 30):
		if first < 0 and Config.wave_composition(n).has("vampire"):
			first = n
	check(first == Config.WAVE_MIX["vampire"]["from_wave"] and first == 13, "vampires join from wave 13")
	check(enemies["vampire"]["hp"] == 2.0 * enemies["goblin"]["hp"] and enemies["vampire"]["speed"] < enemies["goblin"]["speed"] and enemies["vampire"]["damage"] / enemies["vampire"]["attack_cooldown"] == enemies["goblin"]["damage"] / enemies["goblin"]["attack_cooldown"], "a vampire: twice a goblin's HP, slower, a goblin's blows")
	check(enemies["vampire"]["gold_on_kill"] == 6 and enemies["vampire"]["gold_on_collect"] == 8 and enemies["vampire"]["food_on_collect"] == 0, "loot: 6 gold, a corpse of 8 gold, no food")
	# Magic hurts it less: a fireball (and its splash) 0.67 x, an arrow in full.
	var at := Vector2(road_out(7))
	var vp := spawn("vampire", at, 10.0)
	var fm := MilitaryUnit.new("fire_mage")
	fm.village = v
	var h0 := vp.hp
	Combat.hit(game, fm, vp, 10.0, null, vp.hit_point())
	var magic := h0 - vp.hp
	var ar := MilitaryUnit.new("archer")
	ar.village = v
	h0 = vp.hp
	Combat.hit(game, ar, vp, 10.0, null, vp.hit_point())
	var arrow := h0 - vp.hp
	check(is_equal_approx(magic, 6.7) and is_equal_approx(arrow, 10.0), "magic does 0.67 x to a vampire (%.1f of 10), an arrow all of it (%.1f)" % [magic, arrow])
	var gob := spawn("goblin", at + Vector2(0.5, 0.0), 10.0)
	h0 = gob.hp
	Combat.hit(game, fm, gob, 10.0, null, gob.hit_point())
	check(is_equal_approx(h0 - gob.hp, 10.0), "a goblin takes magic in full")
	gob.take_damage(1e9)
	# Never killed in one blow: a deadly hit leaves it a bat with a third of its HP.
	vp.take_damage(1e9, null, "projectile")
	check(not vp.dead and is_equal_approx(vp.hp, vp.max_hp * enemies["vampire"]["bat_below"]) and vp.airborne, "a deadly blow at full HP: it keeps %d %% of its HP and becomes a bat" % roundi(enemies["vampire"]["bat_below"] * 100))
	vp.take_damage(1e9, null, "projectile")
	check(vp.dead, "only once: the next deadly blow kills it")
	var rv := spawn("vampire", at + Vector2(0.0, 0.6), 10.0)
	rv.make_raised(0.5, 1000.0)
	rv.take_damage(1e9, null, "projectile")
	check(not rv.dead and absf(rv.hp - rv.max_hp * enemies["vampire"]["bat_below"]) < 0.5 and rv.max_hp < enemies["vampire"]["hp"] * 10.0, "a raised vampire too, at a third of its (halved) max HP")
	kill(rv)
	await frames(2)
	await clear_corpses()
	# It drains what it really takes: 4 damage at a villager with 2 HP left: +2 x 0.67.
	var vic: Civilian = ensure_role("gatherer")
	vic.set_process(false)
	vic.at_home = false
	vic.visible = true
	var spot := Vector2(road_out(28))  # (far out: as a bat it flies 18 tiles along the road)
	vic.set_grid_pos(spot)
	vic.hp = 2.0
	var va := spawn("vampire", spot + Vector2(0.6, 0.0), 1.0, true)
	va.speed = 0.0
	va.hp = 30.0
	var bit := await wait_until(func() -> bool: return vic.dead or not is_instance_valid(vic), 10.0)
	await frames(1)
	check(bit and is_equal_approx(va.hp, 30.0 + 2.0 * 0.67), "it heals 67 %% of the HP really taken (2 of a 4 blow: +%.2f)" % (va.hp - 30.0))
	# Never above its max.
	var hero := game.hero
	hero.add_to_group("melee_defenders")
	hero.max_hp = 5000.0
	hero.hp = 5000.0
	hero.set_grid_pos(va.grid_pos + Vector2(0.5, 0.0))
	va.hp = va.max_hp - 0.5
	await wait_until(func() -> bool: return hero.hp < 4990.0, 10.0)
	check(is_equal_approx(va.hp, va.max_hp), "and never above its max HP")
	# Below a third of its HP, once, a bat for 10 s: it flies and doesn't bite.
	# (Its road leads out and back, so the bat's flight never reaches a gate.)
	var vb := va.behavior as VampireBehavior
	var loop := PackedVector2Array([va.grid_pos])
	for k in 40:  # (back and forth, 40 tiles: longer than the bat's 18)
		loop.append(va.grid_pos + Vector2(1.0 if k % 2 == 0 else 0.0, 0.0))
	va.follow(loop)
	va.hp = va.max_hp * 0.2
	await frames(3)
	var hhp := hero.hp
	check(va.airborne and va.flies() and is_equal_approx(va.speed, enemies["vampire"]["bat_speed"]) and is_equal_approx(va.hp, va.max_hp * enemies["vampire"]["bat_below"]), "below a third of its HP it turns into a bat (back at a third): it flies, and fast")
	await wait(0.6)
	var arts := {}
	for k in 30:
		await get_tree().process_frame
		arts[va.sprite.texture] = true
	check(arts.has(Art.tex("unit_vampire_bat")) and arts.has(Art.tex("unit_vampire_bat_flap")) and va._shadow != null and va._shadow.visible, "it beats its bat wings over its shadow")
	check(is_equal_approx(hero.hp, hhp) and game.hero._pick_enemy() == null, "a bat doesn't bite, and the hero can't go for it")
	var landed := await wait_until(func() -> bool: return not va.airborne, enemies["vampire"]["bat_time"] + 3.0)
	await wait(1.0)
	check(landed and vb.bat_used and not va.airborne and va.sprite.texture == Art.tex("unit_vampire") and is_equal_approx(va.speed, 0.0), "after %.0f s it lands as a vampire again, at its old speed" % enemies["vampire"]["bat_time"])
	check(not va.airborne, "only once: still low on HP, it stays on its feet")
	hero.remove_from_group("melee_defenders")
	hero.set_grid_pos(Vector2(v.center))
	# Raised by a necromancer once.
	kill(va, hero)
	await frames(2)
	var vc: Corpse = null
	for c in game.corpses.corpses:
		if c.kind == "vampire":
			vc = c
	check(vc != null and vc.revivable and vc.extra_gold == 0, "its corpse can be raised (once)")
	# A bat at a gate: no harm done; it gains a third of its HP and flies back.
	# Landed, the vampire walks to the village again.
	var huts := v.intact_huts().size()
	var people := game.population.count()
	var near := spawn("vampire", Vector2(road_out(3)), 1.0, true)
	near.take_damage(1e9, null, "projectile")
	var nb2 := near.behavior as VampireBehavior
	var turned := await wait_until(func() -> bool: return nb2.fled, 10.0)
	var gate_hp := near.hp
	check(turned and near.airborne and is_equal_approx(gate_hp, near.max_hp * (enemies["vampire"]["bat_below"] + enemies["vampire"]["bat_gate_heal"])) and v.intact_huts().size() == huts and game.population.count() == people, "a bat at a gate gains a third of its HP back (%.0f of %.0f), burns nothing and kills nobody" % [gate_hp, near.max_hp])
	var g0 := near.grid_pos.distance_to(Vector2(v.center))
	await wait(1.0)
	check(near.grid_pos.distance_to(Vector2(v.center)) > g0 + 0.5, "and flies back the way it came")
	var down := await wait_until(func() -> bool: return not near.airborne, enemies["vampire"]["bat_time"] + 3.0)
	var to_gate := false
	if down and not near.path.is_empty():
		for gt in v.gates:
			to_gate = to_gate or near.path[near.path.size() - 1].distance_to(Vector2(gt)) < 1.5
	check(down and not nb2.fled and to_gate and near.speed < enemies["vampire"]["bat_speed"], "landed, the vampire walks to the village again")
	kill(near)
	# Holy damage: a necromancer 1.5 x, a goblin 0.75 x, a raised goblin 2 x that (docs/acolyte-design.md).
	var nk := spawn("necromancer", at, 10.0)
	var gb := spawn("goblin", at + Vector2(0.5, 0.0), 10.0)
	var rg := spawn("goblin", at + Vector2(-0.5, 0.0), 10.0)
	rg.make_raised(1.0, 1000.0)
	var hs := [nk.hp, gb.hp, rg.hp]
	for e in [nk, gb, rg]:
		e.take_damage(10.0, null, "holy")
	check(is_equal_approx(hs[0] - nk.hp, 15.0) and is_equal_approx(hs[1] - gb.hp, 7.5) and absf(hs[2] - rg.hp - 15.0) < 0.2, "holy damage: a necromancer takes 1.5 x, a goblin 0.75 x, a raised goblin 2 x that")
	await clear_enemies()
	await clear_corpses()


# --- monster lairs -------------------------------------------------------------------------------

## A lair of `art` beside the road tile `door`, found by us.
func _make_lair(art: String, door: Vector2i) -> MonsterLair:
	var t := Vector2i(-1, -1)
	for n in MapData.neighbors4(door):
		if t.x < 0 and game.map.in_bounds(n) and not game.map.is_road(n) and not game.map.in_village(n) and not game.map.buildings.has(n) and game.world.pathing.is_walkable(n):
			t = n
	var d := {"kind": "lair", "art": art, "tile": t, "size": 1, "slice": 0, "front": door}
	game.map.objects.append(d)
	var o := game.world._add_map_object(game.map.objects.size() - 1, d) as MonsterLair
	o.on_found(game.player_village.id, true)
	return o


func _test_lairs() -> void:
	var v := game.player_village
	var w := game.waves
	await clear_enemies()
	var a := _make_lair("lair_crypt", road_out(12))
	var b := _make_lair("lair_cave", road_out(18))
	game.world._schedule_lairs()
	var at: Array = []
	for o in game.world.map_objects:
		if o is MonsterLair and int(o.data["slice"]) == 0:
			at.append(o.wake_wave)
	at.sort()
	var want: Array = []
	for k in at.size():
		want.append(Config.LAIR_FROM_WAVE + k * Config.LAIR_EVERY)
	check(at.size() >= 2 and at == want, "a slice's lairs wake one by one: the first at wave 10, then one every 3 waves (%s)" % str(at))
	for o in game.world.map_objects:
		if o is MonsterLair:
			o.wake_wave = 0  # (the map's own lairs sleep through this test)
	a.wake_wave = 10
	b.wake_wave = 13
	check(not game.command("attack_camp", {"camp": a.nid})["ok"], "a sleeping lair can't be attacked")
	a.found_by.erase(v.id)
	logs.clear()
	game.world.wake_lairs(9)
	check(not a.awake and a.alive().is_empty(), "before its wave a lair sleeps, with no guards")
	w.wave = 10
	game.world.wake_lairs(10)
	var guards: Array = Config.LAIR_THEMES["lair_crypt"]["guards"]
	check(a.awake and not b.awake and a.alive().size() == guards.size() and a.alive().all(func(g: Enemy) -> bool: return g.behavior is CampBehavior and is_equal_approx(g.hp_scale, pow(Config.WAVE_HP_GROWTH, 9))), "at wave 10 the first lair wakes up, with %d guards as strong as the wave" % guards.size())
	check(a._glow != null and a._glow.visible, "awake, it glows red")
	check(logs.any(func(l: String) -> bool: return "Something stirs in a crypt somewhere to the" in l and "Skeletons will come out" in l), "not found yet: the log says roughly which way it is and what comes out")
	# One more spawn point: its share of the wave, its theme's kinds only.
	var share: Array = w._share(10, 1.0, game.map.edge_spawns, v)
	var pts := mini(Config.wave_spawn_points(10), game.map.edge_spawns.size())
	var plain := share.filter(func(sp: Dictionary) -> bool: return sp["kind"] != "rat")
	var from_lair := plain.filter(func(sp: Dictionary) -> bool: return sp.has("lair"))
	var expect := 0
	for i in plain.size():
		if i % (pts + 1) == pts:
			expect += 1
	check(from_lair.size() == expect and expect > 0, "the lair is one more spawn point: %d of %d enemies (%d edge spawns + the lair)" % [from_lair.size(), plain.size(), pts])
	check(from_lair.all(func(sp: Dictionary) -> bool: return sp["kind"] == "skeleton" and sp["spawn"] == a.door()), "a crypt at wave 10 sends skeletons, from its door")
	var comp := {}
	for sp in plain:
		comp[sp["kind"]] = comp.get(sp["kind"], 0) + 1
	check(comp == Config.wave_composition(10), "the wave keeps its mix (the lair takes its kinds from the share)")
	check(str(b.kinds_for(13)) == str(["ork", "gargoyle"]) and str(a.kinds_for(13)) == str(["skeleton", "necromancer", "vampire"]) and str(b.kinds_for(3)) == str(["ork"]) and str(b.kinds_for(1)) == str(["goblin"]), "themes: a cave sends orks and gargoyles, a crypt skeletons, necromancers and vampires (once their wave has come; goblins before)")
	w._spawn(from_lair[0])
	await frames(2)
	var e: Enemy = null
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.from_lair:
			e = node
	var to_gate := e != null and v.gates.has(Vector2i(e.path[e.path.size() - 1].round()))
	check(e != null and Vector2i(e.path[0].round()) == a.door() and to_gate, "its enemies walk its winding road and on to a gate")
	check(game.world.warnings.enabled() == (Settings.difficulty != Settings.Difficulty.HARD), "the warning lights mark the new road in (easy and normal), even after wave %d" % Config.WARNING_LIGHT_WAVES)
	kill(e)
	# Cleared by the hero: loot at its door, quiet for 3 waves, then awake again.
	a.on_found(v.id, true)
	check(game.command("attack_camp", {"camp": a.nid})["ok"] and game.hero.camp_target == a, "an awake lair can be attacked with the hero")
	logs.clear()
	for g in a.alive():
		kill(g, game.hero)
	await frames(3)
	game.hero.camp_target = null
	var sacks := game.world.map_objects.filter(func(o: MapObject) -> bool: return o.data.get("sack", false))
	check(a.cleared and not a.awake and not a._glow.visible and a.quiet_until == 11 + Config.LAIR_QUIET_WAVES, "cleared, it sleeps (no glow) until wave %d" % (11 + Config.LAIR_QUIET_WAVES))
	check(not sacks.is_empty() and Vector2(sacks.back().tile).distance_to(Vector2(a.door())) <= 1.5 and not (sacks.back().data["reward"] as Dictionary).is_empty(), "it leaves a sack of loot at its door (%s)" % (str(sacks.back().data["reward"]) if not sacks.is_empty() else "none"))
	check(logs.any(func(l: String) -> bool: return "cleared a monster lair" in l), "the log says so")
	check(w._share(11, 1.0, game.map.edge_spawns, v).all(func(sp: Dictionary) -> bool: return not sp.has("lair")), "a cleared lair sends nobody")
	game.world.wake_lairs(13)
	check(b.awake and not a.awake, "wave 13: the next lair of the slice wakes up; the cleared one still sleeps")
	logs.clear()
	game.world.wake_lairs(14)
	check(a.awake and a.alive().size() == guards.size() and logs.any(func(l: String) -> bool: return "The crypt to the" in l and "woken up again" in l), "wave 14: it wakes up again, with new guards, and the log says so")
	for l in [a, b]:
		for g in l.alive():
			kill(g)
	await clear_enemies()


# --- slimes ------------------------------------------------------------------------------------------

func _slimes(kind: String) -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.kind == kind and not e.dead)


func _test_slimes() -> void:
	print("-- slimes")
	var enemies := Config.ENEMIES
	var s3: Dictionary = enemies["slime3"]
	var s2: Dictionary = enemies["slime2"]
	var s1: Dictionary = enemies["slime1"]
	check(s3["hp"] == 40.0 and s3["damage"] == enemies["ork"]["damage"] and s3["attack_cooldown"] == enemies["ork"]["attack_cooldown"] and s3["speed"] == enemies["ork"]["speed"], "a big slime: 40 HP, an ork's blows and pace")
	check(s3["hp"] == 2.0 * s2["hp"] and s2["hp"] == 2.0 * s1["hp"] and s3["damage"] == 2.0 * s2["damage"] and s2["damage"] == 2.0 * s1["damage"], "each level has twice the HP and damage of the one below")
	check(s1["speed"] > s2["speed"] and s2["speed"] == enemies["goblin"]["speed"] and s2["speed"] > s3["speed"], "level 1 is fast, level 2 normal, level 3 slow")
	check([s3, s2, s1].all(func(d: Dictionary) -> bool: return not d.get("corpse", true) and d["behavior"] == "melee"), "slimes leave no corpse (nothing to raise) and walk the roads like goblins and orks")
	check(not s3.has("raid_chance") and s2["raid_chance"] == 0.5 and s1["raid_chance"] == 0.25, "at the gate: a big slime always burns a hut, a slime half, a small one a quarter of the time")
	var first := 0
	for n in range(1, 30):
		if Config.wave_composition(n).has("slime3"):
			first = n
			break
	check(first == 4 and not Config.wave_composition(12).has("slime2") and not Config.wave_composition(12).has("slime1"), "big slimes march from wave 4 (%d); the smaller ones only come out of them" % first)
	var art_ok := true
	var widths: Array[float] = []
	for lv in [3, 2, 1]:
		widths.append(Art.tex("unit_slime%d" % lv).get_width())
		for c in Config.SLIME_COLORS:
			art_ok = art_ok and ResourceLoader.exists("res://art/unit_slime%d_%s.svg" % [lv, c])
	check(art_ok and Config.SLIME_COLORS == ["red", "blue", "yellow", "green", "pink"], "every level in all 5 colours")
	check(widths[0] > widths[1] and widths[1] > widths[2], "the bigger the level, the bigger the sprite %s" % str(widths))
	# The die: each colour about a fifth of the time.
	var counts := {}
	for i in 500:
		var e: Enemy = Enemy.new()
		e.setup(game, [Vector2i(game.player_village.center)] as Array[Vector2i], 1.0, "slime3")
		counts[e.color] = counts.get(e.color, 0) + 1
		e.free()
	check(counts.size() == 5 and counts.values().all(func(n: int) -> bool: return n > 60 and n < 140), "each spawned slime rolls its colour, all equally likely %s" % str(counts))
	var shares := {}
	for kind in ["slime3", "slime2", "slime1", "goblin"]:
		var e: Enemy = Enemy.new()
		e.setup(game, [Vector2i(game.player_village.center)] as Array[Vector2i], 1.0, kind)
		var hits := 0
		for i in 4000:
			hits += 1 if game.raid_roll(e) else 0
		shares[kind] = hits / 4000.0
		e.free()
	check(shares["slime3"] == 1.0 and shares["goblin"] == 1.0 and absf(shares["slime2"] - 0.5) < 0.04 and absf(shares["slime1"] - 0.25) < 0.04, "the gate roll: big slime always, slime ~50 %%, small slime ~25 %% %s" % str(shares))

	# A big slime splits into 2 slimes, each into 2 small ones; those just die.
	await clear_corpses()
	var at := Vector2(road_out(8))
	var big := spawn("slime3", at, 1.0, true)
	await frames(2)
	check(big.color in Config.SLIME_COLORS and big.sprite.texture == Art.tex("unit_slime3_" + big.color), "it shows its colour (%s)" % big.color)
	var col := big.color
	var big_pos := big.grid_pos
	var big_target := big.target_village
	var alive0: int = game.waves._alive
	var gold0 := int(game.economy.amount("gold"))
	big.take_damage(1e9, game.hero)
	await frames(2)
	var mids := _slimes("slime2")
	check(mids.size() == 2 and mids.all(func(e: Enemy) -> bool: return e.color == col and e.sprite.texture == Art.tex("unit_slime2_" + col)), "slain, it splits into 2 slimes of its colour")
	check(mids.all(func(e: Enemy) -> bool: return e.grid_pos.distance_to(big_pos) < 0.6 and e.path.size() >= 2 and e.target_village == big_target) and mids[0].grid_pos.distance_to(mids[1].grid_pos) > 0.2, "side by side where it died, walking on along its road")
	check(game.waves._alive == alive0 + 1 and game.corpses.corpses.is_empty() and int(game.economy.amount("gold")) - gold0 == Config.enemy_stat_int("slime3", "gold_on_kill"), "both count for the wave; no corpse; the kill pays %d gold" % Config.enemy_stat_int("slime3", "gold_on_kill"))
	check(logs.any(func(l: String) -> bool: return "splits into" in l), "the split is logged")
	for m: Enemy in mids:
		m.take_damage(1e9, game.hero)
	await frames(2)
	var smalls := _slimes("slime1")
	check(smalls.size() == 4 and smalls.all(func(e: Enemy) -> bool: return e.color == col) and game.waves._alive == alive0 + 3, "each slime splits into 2 small slimes (4, same colour)")
	for m: Enemy in smalls:
		m.take_damage(1e9, game.hero)
	await frames(2)
	check(_slimes("slime1").is_empty() and _slimes("slime2").is_empty() and game.corpses.corpses.is_empty() and game.waves._alive == alive0 - 1, "small slimes just die: no split, no corpse; all gone, the wave is clear of them")

	# At the gate: a big slime burns a hut; the smaller ones may melt away.
	for kind in ["slime1", "slime2", "slime3"]:
		var huts := game.player_village.intact_huts().size()
		var n_logs := logs.size()
		var e := spawn(kind, Vector2(road_out(2)), 1.0, true)
		var t := 0.0
		while is_instance_valid(e) and not e.dead and t < 20.0:
			await wait(0.25)
			t += 0.25
		await frames(2)
		var lost := huts - game.player_village.intact_huts().size()
		var melted := logs.slice(n_logs).any(func(l: String) -> bool: return "melted away" in l)
		var ok := lost == 1 and not melted if kind == "slime3" else (lost == 1) != melted
		check((not is_instance_valid(e) or e.dead) and ok, "%s at the gate: %d hut%s destroyed%s" % [kind, lost, "" if lost == 1 else "s", " (it melted away)" if melted else ""])
	check(_slimes("slime2").is_empty() and _slimes("slime1").is_empty(), "nothing splits at the gate")

	var lib := Library.entries("enemies")
	var bigs := lib.filter(func(d: Dictionary) -> bool: return "slime" in str(d["name"]).to_lower())
	var e3: Dictionary = bigs[0] if bigs.size() == 1 else {}
	check(bigs.size() == 1 and e3["name"] == "Slime" and e3["art"] == "unit_slime3", "the library has one entry, \"Slime\", showing the big slime")
	check(e3.get("text", "") == "Slain, it splits into two smaller slimes, and each of those into two more." and ("HP %s" % Library._n(Config.enemy_stat("slime3", "hp"))) in "\n".join(e3.get("facts", [])), "its text only tells of the split; its numbers are the big slime's")

