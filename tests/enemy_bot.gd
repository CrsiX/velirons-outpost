extends "res://tests/bot_base.gd"
## Headless test of the thief, the gargoyle and the necromancer. Run with:
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
	await _test_thief()
	await _test_gargoyle()
	await _test_necromancer()
	await _test_fog_corpses()
	await _test_vampire()
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
	check(E["witch"]["spell_range"] <= Config.TOWER_RANGE["tower"] + Config.TOWER_LEVELS[0]["range_bonus"], "a witch can't outrange a level 1 watchtower (%.1f vs %.1f)" % [E["witch"]["spell_range"], Config.TOWER_RANGE["tower"]])
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
	var E := Config.ENEMIES
	await clear_enemies()
	await clear_corpses()
	check(Config.ATTACKS.values().all(func(a: Dictionary) -> bool: return Config.DAMAGE_CATEGORIES.has(a.get("category", ""))) and E["witch"]["attack_category"] == "magical", "every attack has a damage category (the witch's is magical)")
	var first := -1
	for n in range(1, 30):
		if first < 0 and Config.wave_composition(n).has("vampire"):
			first = n
	check(first == Config.WAVE_MIX["vampire"]["from_wave"] and first == 13, "vampires join from wave 13")
	check(E["vampire"]["hp"] == 2.0 * E["goblin"]["hp"] and E["vampire"]["speed"] < E["goblin"]["speed"] and E["vampire"]["damage"] / E["vampire"]["attack_cooldown"] == E["goblin"]["damage"] / E["goblin"]["attack_cooldown"], "a vampire: twice a goblin's HP, slower, a goblin's blows")
	check(E["vampire"]["gold_on_kill"] == 6 and E["vampire"]["gold_on_collect"] == 8 and E["vampire"]["food_on_collect"] == 0, "loot: 6 gold, a corpse of 8 gold, no food")
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
	check(not vp.dead and is_equal_approx(vp.hp, vp.max_hp * E["vampire"]["bat_below"]) and vp.airborne, "a deadly blow at full HP: it keeps %d %% of its HP and becomes a bat" % roundi(E["vampire"]["bat_below"] * 100))
	vp.take_damage(1e9, null, "projectile")
	check(vp.dead, "only once: the next deadly blow kills it")
	var rv := spawn("vampire", at + Vector2(0.0, 0.6), 10.0)
	rv.make_raised(0.5, 1000.0)
	rv.take_damage(1e9, null, "projectile")
	check(not rv.dead and absf(rv.hp - rv.max_hp * E["vampire"]["bat_below"]) < 0.5 and rv.max_hp < E["vampire"]["hp"] * 10.0, "a raised vampire too, at a third of its (halved) max HP")
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
	check(va.airborne and va.flies() and is_equal_approx(va.speed, E["vampire"]["bat_speed"]) and is_equal_approx(va.hp, va.max_hp * E["vampire"]["bat_below"]), "below a third of its HP it turns into a bat (back at a third): it flies, and fast")
	await wait(0.6)
	var arts := {}
	for k in 30:
		await get_tree().process_frame
		arts[va.sprite.texture] = true
	check(arts.has(Art.tex("unit_vampire_bat")) and arts.has(Art.tex("unit_vampire_bat_flap")) and va._shadow != null and va._shadow.visible, "it beats its bat wings over its shadow")
	check(is_equal_approx(hero.hp, hhp) and game.hero._pick_enemy() == null, "a bat doesn't bite, and the hero can't go for it")
	var landed := await wait_until(func() -> bool: return not va.airborne, E["vampire"]["bat_time"] + 3.0)
	await wait(1.0)
	check(landed and vb.bat_used and not va.airborne and va.sprite.texture == Art.tex("unit_vampire") and is_equal_approx(va.speed, 0.0), "after %.0f s it lands as a vampire again, at its old speed" % E["vampire"]["bat_time"])
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
	check(turned and near.airborne and is_equal_approx(gate_hp, near.max_hp * (E["vampire"]["bat_below"] + E["vampire"]["bat_gate_heal"])) and v.intact_huts().size() == huts and game.population.count() == people, "a bat at a gate gains a third of its HP back (%.0f of %.0f), burns nothing and kills nobody" % [gate_hp, near.max_hp])
	var g0 := near.grid_pos.distance_to(Vector2(v.center))
	await wait(1.0)
	check(near.grid_pos.distance_to(Vector2(v.center)) > g0 + 0.5, "and flies back the way it came")
	var down := await wait_until(func() -> bool: return not near.airborne, E["vampire"]["bat_time"] + 3.0)
	var to_gate := false
	if down and not near.path.is_empty():
		for gt in v.gates:
			to_gate = to_gate or near.path[near.path.size() - 1].distance_to(Vector2(gt)) < 1.5
	check(down and not nb2.fled and to_gate and near.speed < E["vampire"]["bat_speed"], "landed, the vampire walks to the village again")
	kill(near)
	# Holy damage: a necromancer 1.5 x, anything it raised 2 x, a goblin in full.
	var nk := spawn("necromancer", at, 10.0)
	var gb := spawn("goblin", at + Vector2(0.5, 0.0), 10.0)
	var rg := spawn("goblin", at + Vector2(-0.5, 0.0), 10.0)
	rg.make_raised(1.0, 1000.0)
	var hs := [nk.hp, gb.hp, rg.hp]
	for e in [nk, gb, rg]:
		e.take_damage(10.0, null, "holy")
	check(is_equal_approx(hs[0] - nk.hp, 15.0) and is_equal_approx(hs[1] - gb.hp, 10.0) and absf(hs[2] - rg.hp - 20.0) < 0.2, "holy damage: a necromancer takes 1.5 x, a raised enemy 2 x, a goblin 1 x")
	await clear_enemies()
	await clear_corpses()
