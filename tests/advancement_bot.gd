extends "res://tests/bot_base.gd"
## Headless test of the advancements (docs/advancements-design.md): research at
## the town hall (conditions, gold and time, cancelling, a devastated hall
## pausing it, exclusive locks), each effect, both targeting advancements, the
## save, and shared vision in a two-village game. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/advancement_bot.tscn
## Exits 0 when every check passes.

const SEED := 778

var v: Village
var r: Research


func _run() -> void:
	_test_config()
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEED
	game.disable_fog = true
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	_bench_hero(true)
	v = game.player_village
	r = v.research
	game.economy.add("gold", 5000)
	game.economy.add("materials", 2000)
	Engine.time_scale = 6.0
	_test_conditions()
	await _test_research()
	_test_effects()
	await _test_targeting()
	_test_save()
	game.queue_free()
	await frames(3)
	await _test_shared_vision()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


## Researched at once (for the effect tests): what _finish does, without the wait.
func grant(id: String) -> void:
	r.current = id
	r._finish()


func _test_config() -> void:
	var ok := true
	for id: String in Config.ADVANCEMENTS:
		var a: Dictionary = Config.ADVANCEMENTS[id]
		ok = ok and a.has("name") and a.has("desc") and int(a["tier"]) in [1, 2] and int(a["gold"]) > 0 and float(a["time"]) > 0.0
		for n: String in a.get("needs", []):
			ok = ok and Config.ADVANCEMENTS.has(n)
		if a.has("excludes"):
			ok = ok and str(Config.ADVANCEMENTS[str(a["excludes"])].get("excludes", "")) == id
	check(ok, "every advancement: a name, a tier, gold, time, a text; prerequisites exist; exclusive pairs point at each other")
	check(not Config.ADVANCEMENTS.values().any(func(a: Dictionary) -> bool: return a.has("max_piece_level") and a.has("excludes")), "wall levels are never part of an exclusive pair")
	check(Config.ADVANCEMENTS.keys().all(func(id: String) -> bool: return ResourceLoader.exists("res://art/%s.svg" % Config.advancement_icon(id))), "every advancement has its icon")
	check(Config.plain_text("Researching {adv:drill_1} Drill I") == "Researching Drill I", "an advancement's icon token reads as nothing in plain text")


func _test_conditions() -> void:
	var hall := v.town_hall()
	check(r.enabled() and r.offered().size() == Config.ADVANCEMENTS.size() - 1, "a free game offers every advancement but the co-op one (shared vision)")
	check(r.error("quick_feet").contains("Town hall level 2"), "at hall level 1: nothing (%s)" % r.error("quick_feet"))
	hall.level = 2
	hall.refresh()
	check(r.error("quick_feet") == "", "at level 2 tier 1 opens")
	check(r.error("fortifications_5").contains("Town hall level 3"), "tier 2 waits for level 3")
	check(r.error("faster_attacks").contains("Wave 10"), "a wave condition (%s)" % r.error("faster_attacks"))
	check(r.error("skilled_looting").contains("gold earned"), "an earned-gold condition (%s)" % r.error("skilled_looting"))
	check(r.error("vital_points").contains("melee kills"), "a deed (%s)" % r.error("vital_points"))
	check(r.error("caravan_rights") == "", "Caravan rights: nothing but the tier")
	check(Research.is_market("caravan_rights") and Research.is_market("guild_partners") and Research.is_market("extra_caravan") and not Research.is_market("drill_1"), "the market's three are known by their effects (offered only where a marketplace can be built)")
	game.stats.count(v, "earn.gold", 500.0)
	check(r.error("skilled_looting") == "", "500 gold earned: it opens")
	game.stats.count(v, "kill_by.melee", 40.0)
	check(r.error("vital_points") == "", "40 melee kills: it opens")
	game.waves.wave = 10
	check(r.error("faster_attacks") == "", "wave 10: it opens")
	hall.level = 3
	hall.refresh()
	check(r.error("drill_2").contains("Wave 14"), "tier 2 at level 3, still its wave (%s)" % r.error("drill_2"))
	game.waves.wave = 14
	check(r.error("drill_2").contains("Drill I"), "and a prerequisite (%s)" % r.error("drill_2"))
	check(r.error("guild_partners").contains("sales delivered"), "Guild partners: a deed of sales (%s)" % r.error("guild_partners"))
	game.stats.count(v, "trade.sold", 10.0)
	check(r.error("guild_partners") == "", "10 sales of any kind: it opens")
	check(r.error("extra_caravan").contains("Caravan rights"), "One more caravan needs Caravan rights (%s)" % r.error("extra_caravan"))
	game.waves.wave = 10


func _test_research() -> void:
	var gold := v.economy.amount("gold")
	var res := game.command("research", {"id": "quick_feet"})
	check(res["ok"] and r.current == "quick_feet" and v.economy.amount("gold") == gold - 100, "research starts and is paid in gold")
	check(not game.command("research", {"id": "drill_1"})["ok"], "one research at a time")
	check(r.cancel_refund() == 100, "cancelled before any research: all of it back")
	r.progress = float(Config.ADVANCEMENTS["quick_feet"]["time"]) * 0.5
	check(r.cancel_refund() == 50, "half done: half back")
	game.command("cancel_research")
	check(r.current == "" and v.economy.amount("gold") == gold - 50, "cancelled: the rest comes back")
	game.command("research", {"id": "quick_feet"})
	var hall := v.town_hall()
	hall.devastated = true
	var p0 := r.progress
	await wait(1.0)
	check(r.progress == p0, "a devastated town hall pauses the research")
	hall.devastated = false
	var done := await wait_until(func() -> bool: return r.has("quick_feet"), 120.0)
	check(done and r.current == "", "and it finishes in its time")
	if not done:
		print("    research: current '%s', progress %.2f, hall working %s, processing %s, client %s, over %s" % [r.current, r.progress, hall.working(), r.is_processing(), game.is_client, game.game_over])
	# Exclusive: the other half locked for good.
	game.command("research", {"id": "manual_targeting"})
	await wait_until(func() -> bool: return r.has("manual_targeting"), 120.0)
	check(r.locked.has("better_targeting") and r.error("better_targeting").begins_with("Locked"), "an exclusive choice locks the other for good")


func _test_effects() -> void:
	# Fortifications.
	var wall: StaticPiece = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall")[0]
	var wt: Tower = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower")[0]
	check(wall.max_level() == 3 and wt.max_level() == 3, "walls and towers stop at level 3")
	grant("fortifications_4")
	check(wall.max_level() == 4 and wt.max_level() == 4 and v.town_hall().max_level() == 3, "Fortifications IV: level 4 (the hall keeps its own levels)")
	grant("fortifications_5")
	check(wall.max_level() == 5 and ResourceLoader.exists("res://art/wall_5.svg") and ResourceLoader.exists("res://art/wood_wall_tower_front_5.svg"), "Fortifications V: level 5, with its art")
	# Quick feet (researched above).
	var forester: Civilian = game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == "forester")[0]
	check(is_equal_approx(forester.speed, float(Config.CIVILIANS["forester"]["speed"]) * 1.15), "Quick feet: foresters walk 15 % faster")
	# Faster attacks, more damage.
	var ar := game.army.recruit("archer")
	var rate0 := ar.rate(game)
	var dmg0 := ar.stat("damage")
	grant("faster_attacks")
	grant("more_damage")
	check(is_equal_approx(ar.rate(game), rate0 * 1.1) and is_equal_approx(ar.stat("damage"), dmg0 * 1.1), "faster attacks +10 %, more damage +10 %")
	# Drill.
	var lvl_cost: int = Config.unit_upgrade_cost("archer", 0)["gold"]
	grant("drill_1")
	check(int(ar.upgrade_cost()["gold"]) == roundi(lvl_cost * 0.85), "Drill I: a level-up 15 %% less (%d)" % int(ar.upgrade_cost()["gold"]))
	grant("drill_2")
	check(int(ar.upgrade_cost()["gold"]) == roundi(lvl_cost * 0.7) and is_equal_approx(ar.drill_factor(), 0.7), "Drill II: 30 % less in all, XP too")
	# Skilled looting.
	grant("skilled_looting")
	check(v.kill_gold(4) == 5 and v.kill_gold(2) == 3 and v.kill_gold(12) == 15, "Skilled looting: +25 %, at least 1 more")
	# Master builders / cheaper repairs; cheaper recruits.
	var b: Builder = game.population.civilians.filter(func(c: Civilian) -> bool: return c is Builder)[0]
	var speed0 := b.job.work_speed()
	grant("master_builders")
	check(is_equal_approx(b.job.work_speed(), speed0 * 1.25) and r.locked.has("cheaper_repairs"), "Master builders: 25 % faster; cheaper repairs locked")
	wall.take_damage(50.0)
	var full := wall.repair_cost()
	r.done.erase("master_builders")
	r.done.append("cheaper_repairs")
	check(int(wall.repair_cost()["materials"]) < int(full["materials"]), "Cheaper repairs: less material (%s vs %s)" % [str(wall.repair_cost()), str(full)])
	r.done.erase("cheaper_repairs")
	grant("cheaper_recruits")
	check(int(v.recruit_cost("archer")["gold"]) == roundi(40 * 0.8), "cheaper base units: recruiting 20 % less")
	r.done.erase("cheaper_recruits")
	grant("cheaper_specialising")
	ar.level = Config.BRANCH_MIN_LEVEL - 1
	var opts := ar.upgrade_options().filter(func(o: Dictionary) -> bool: return o["to"] != "archer")
	check(not opts.is_empty() and int(opts[0]["cost"]["gold"]) == roundi(int(Config.MILITARY[opts[0]["to"]]["branch_cost"]["gold"]) * 0.75), "cheaper specialising: 25 % less")
	# The market's: more caravans, a lower guild tax.
	var spot := find_spot("market", v.center)
	var mk := v.construction.place("market", spot) as Market if spot != Vector2i(-1, -1) else null
	check(mk != null, "a marketplace for the market's advancements")
	if mk != null:
		mk.finish()
		v.construction.queue.erase(mk)
		var cap0 := mk.caravan_cap()
		var tax0 := mk.tax()
		grant("caravan_rights")
		check(mk.caravan_cap() == cap0 + 1, "Caravan rights: one more caravan (%d)" % mk.caravan_cap())
		grant("extra_caravan")
		check(mk.caravan_cap() == cap0 + 2 and r.locked.has("guild_partners"), "One more caravan adds another; Guild partners locked")
		r.done.erase("extra_caravan")
		r.locked.erase("guild_partners")
		grant("guild_partners")
		check(is_equal_approx(mk.tax(), tax0 * 0.75) and mk.guild_price("hearth") > 0, "Guild partners: the guild tax a quarter lower (%.3f)" % mk.tax())
		v.relics.append("toll_charter")
		check(is_equal_approx(mk.tax(), tax0 * (1.0 - 0.25 - float(Config.RELICS["toll_charter"]["tax"]))), "and it adds to a Toll charter")
		v.relics.erase("toll_charter")
	# Eye for vital points.
	grant("vital_points")
	var crits := 0
	for i in 2000:
		if Combat.critical(game, v, null) > 1.0:
			crits += 1
	check(crits > 120 and crits < 280 and game.hero.has_melee_weapon(), "Eye for vital points: about 10 %% of melee blows are critical (%d of 2000)" % crits)


## Better targeting by unit kind, manual by the tower's switch.
func _test_targeting() -> void:
	var wt: Tower = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower")[0]
	check(v.targeting() == "manual", "(manual targeting researched above)")
	check(Targeting.rule(v, wt, "archer") == "default", "a tower starts at nearest the centre")
	check(game.command("set_targeting", {"building": wt.nid, "mode": "strongest"})["ok"] and Targeting.rule(v, wt, "archer") == "strongest", "its switch: strongest first")
	var info := game.building_info(wt)
	check(str(info["lines"]).contains("Targets: Strongest first") and info["actions"].any(func(a: Dictionary) -> bool: return str(a["label"]).begins_with("Target:")), "the tower's panel shows the switch")
	var ar := game.army.recruit("archer")
	ar.level = 0
	var near_strong: Array = _two_foes(wt)
	var order := MilitaryBehavior.enemies_near(wt, 3.0, ar)  # (only the two by it: camp guards stand elsewhere)
	check(order.size() >= 2 and order[0] == near_strong[1], "strongest first: the orc before the goblin nearer the centre")
	game.command("set_targeting", {"building": wt.nid, "mode": "weakest"})
	order = MilitaryBehavior.enemies_near(wt, 3.0, ar)  # (only the two by it: camp guards stand elsewhere)
	check(order[0] == near_strong[0], "weakest first: the goblin")
	# Better targeting: by kind.
	r.done.erase("manual_targeting")
	r.done.append("better_targeting")
	check(Targeting.rule(v, wt, "crossbowman") == "strongest" and Targeting.rule(v, wt, "ice_mage") == "fastest" and Targeting.rule(v, wt, "archer") == "default", "better targeting: by the unit's kind")
	check(Targeting.rule(v, null, "crossbowman") == "default", "out of a barracks (no tower): the default")
	await clear_enemies()


## A goblin nearer the centre and an orc a little further out (both standing), near `t`.
func _two_foes(t: Tower) -> Array:
	var out: Array = []
	for kind in ["goblin", "orc"]:
		game.waves._spawn({"kind": kind, "spawn": game.map.edge_spawns[0], "hp_scale": 1.0, "village": v})
		var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
		var at := Vector2(t.tile) + (Vector2(-1.0, -1.0) if kind == "goblin" else Vector2(-1.5, -1.5))
		e.set_grid_pos(at)
		e.speed = 0.0
		e.process_mode = Node.PROCESS_MODE_DISABLED
		out.append(e)
	return out


func _test_save() -> void:
	var wt: Tower = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower")[0]
	wt.targeting = "fastest"
	r.current = "shared_vision"
	r.progress = 12.0
	var body := SaveGame.capture(game)
	var res: Dictionary = body["villages"][0]["res"]
	var saved: Array = body["buildings"].filter(func(d: Dictionary) -> bool: return d["n"] == wt.nid)
	check(res["done"].size() == r.done.size() and res["cur"] == "shared_vision" and is_equal_approx(float(res["p"]), 12.0) and res["locked"] == Array(r.locked), "a save holds what was researched, the research under way and the locks")
	check(saved.size() == 1 and saved[0].get("tg", "") == "fastest", "and each tower's targeting")
	r.current = ""


## Shared vision (co-op, one way): the researcher sees what the others watch.
func _test_shared_vision() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = 12
	game.test_villages = 2
	add_child(game)
	await frames(5)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	var a := game.villages[0]
	var b := game.villages[1]
	check(a.research.offered().has("shared_vision"), "with two villages shared vision is offered")
	a.research.current = "shared_vision"
	a.research._finish()
	game.fog.update_surveillance()
	var t: Vector2i = b.center
	check(game.fog.is_watched_by(a.id, t) and game.fog.is_explored_by(a.id, t), "village 1 watches village 2's centre now")
	check(not game.fog.is_watched_by(b.id, a.center), "one way: village 2 doesn't see village 1's")
	game.queue_free()
	await frames(3)
