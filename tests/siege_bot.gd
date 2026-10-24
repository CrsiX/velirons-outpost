extends "res://tests/bot_base.gd"
## Headless test of building HP, devastation, repairs, gate and wall levels,
## and enemies breaking into the village (docs/siege-design.md). Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/siege_bot.tscn
## Exits 0 when every check passes.

const SEED := 778

var logs: Array[String] = []


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
	game.player_village.events.logged.connect(func(_l: int, text: String) -> void: logs.append(text))
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	_bench_hero(true)
	game.economy.add("materials", 2000)
	game.economy.add("gold", 2000)
	Engine.time_scale = 6.0
	_test_hp()
	await _test_repair()
	await _test_devastated_tower()
	await _test_farm()
	await _test_levels()
	_test_teardown_refund()
	await _test_huts_first()
	await _test_queue_rules()
	await _test_chain()
	_test_field()
	await _test_break_in()
	await _test_weaker_wall()
	await _test_broken_wall()
	await _test_fight_first()
	await _test_flyer()
	await _test_slip()
	await _test_witch()
	await _test_no_siege()
	await _test_exposed()
	_test_hero_targets()
	await _test_push()
	_test_save()
	_test_stats()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- helpers --------------------------------------------------------------------------------------

## An enemy of `kind` at `at` (grid), walking the roads to the village from there.
func spawn(kind: String, at: Vector2) -> Enemy:
	game.waves._spawn({"kind": kind, "spawn": game.map.edge_spawns[0], "hp_scale": 1.0, "village": game.player_village})
	var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
	e.set_grid_pos(at)
	var road := game.world.pathing.nearest_road(Vector2i(at.round()))
	var route := game.world.pathing.enemy_route(road, RandomNumberGenerator.new(), -1)
	var pts := PackedVector2Array([at])
	for t in route:
		pts.append(Vector2(t))
	e.follow(pts)
	return e


## A standing enemy at `at` that never walks.
func spawn_still(kind: String, at: Vector2) -> Enemy:
	var e := spawn(kind, at)
	e.speed = 0.0
	e.follow(PackedVector2Array([at, at + Vector2(0.001, 0)]))
	return e


## The gate whose road we use, and the way into the village through it.
func gate() -> StaticPiece:
	return game.map.building_at(game.player_village.gates[0]) as StaticPiece


## One step from the gate into the village.
func inward(g: Vector2i) -> Vector2i:
	var r := game.player_village.rect
	if g.x == r.position.x:
		return Vector2i(1, 0)
	if g.x == r.end.x - 1:
		return Vector2i(-1, 0)
	if g.y == r.position.y:
		return Vector2i(0, 1)
	return Vector2i(0, -1)


## The two walls beside the gate.
func walls_beside(g: Vector2i) -> Array[StaticPiece]:
	var d := inward(g)
	var side := Vector2i(d.y, d.x)
	var out: Array[StaticPiece] = []
	for t in [g + side, g - side]:
		var b = game.map.building_at(t)
		if b is StaticPiece and b.kind == "wall":
			out.append(b)
	return out


## A road tile about `steps` road tiles out from the gate.
func road_out(steps: int) -> Vector2i:
	var g: Vector2i = game.player_village.gates[0]
	var t := g
	var seen := {g: true}
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


## Every village piece whole and at level 1 again; every hut standing.
func reset_village() -> void:
	for b in game.player_village.buildings():
		if b is StaticPiece or (b is Tower and b.kind == "wall_tower"):
			b.level = 1
			if b.devastated:
				b.set_devastated(false)
			b.hp = b.max_hp()
			b.refresh()
			b.queue_redraw()
		if b is Hut and (b as Hut).ruined:
			(b as Hut).ruined = false
			b.refresh()
	game.siege.mark_stale(game.player_village, true)


func intact() -> int:
	return game.player_village.intact_huts().size()


## Lets the builders finish everything queued.
func finish_work() -> bool:
	return await wait_until(func() -> bool: return game.construction.queue.is_empty(), 90.0)


# --- config ---------------------------------------------------------------------------------------

func _test_config() -> void:
	var hp := Config.BUILDING_HP
	check(hp["gate"] == [80.0, 160.0, 320.0] and hp["wall"] == [100.0, 200.0, 400.0] and hp["wall_tower"] == [200.0, 400.0, 800.0] and hp["hut"] == [1.0], "HP: gate 80/160/320, wall 100/200/400, wall tower 200/400/800, hut 1")
	check(hp["gate"][0] < hp["wall"][0], "a gate is weaker than a wall at level 1")
	for kind in Config.BUILDINGS:
		check(hp.has(kind), "%s has HP" % kind)
	check(int(Config.BUILDINGS["hut"]["cost"]["materials"]) == 80 and int(Hut.rebuild_cost()["materials"]) == 40, "a hut lists 80 material; rebuilding one costs 40")
	check(RuinedTower.restore_cost() == {"materials": 15}, "restoring a ruined watchtower: half its price")
	for art in ["wall_ruin", "gate_ruin", "wall_tower_ruin", "rubble", "gate_2", "gate_3", "wall_2", "wall_3"]:
		check(ResourceLoader.exists("res://art/%s.svg" % art), "art: %s" % art)
	check(Config.ENEMIES["rat"].get("entry", "") == "slip" and Config.ENEMIES["thief"].get("entry", "") == "slip", "rats and thieves slip through gates")
	check(float(Config.ENEMIES["goblin"].get("siege", 0.0)) > 0.0 and float(Config.ENEMIES["necromancer"].get("siege", 0.0)) == 0.0, "goblins hurt walls, necromancers can't")


# --- HP, repairs, devastation ------------------------------------------------------------------------

func _test_hp() -> void:
	var g := gate()
	var w := walls_beside(g.tile)
	var corners := game.player_village.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower")
	check(g.hp == 80.0 and g.max_hp() == 80.0 and not w.is_empty() and w[0].hp == 100.0 and corners.size() == 4 and corners[0].hp == 200.0, "the village's pieces start at full HP")
	var hut: Hut = game.player_village.intact_huts()[0]
	check(hut.max_hp() == 1.0 and not hut.can_repair(), "a hut has 1 HP and is rebuilt, not repaired")


func _test_repair() -> void:
	var g := gate()
	g.take_damage(30.0)
	check(g.hp == 50.0 and not g.devastated and g.working(), "a gate hit for 30: 50 / 80 HP, still standing")
	var info := game.building_info(g)
	var labels: Array = info["actions"].map(func(a: Dictionary) -> String: return a["label"])
	check(info["lines"].any(func(l: String) -> bool: return "{hp} 50 / 80" in l) and labels.any(func(l: String) -> bool: return l.begins_with("Repair")), "its panel shows its HP and offers a repair")
	# 40 (its repair price) x 50 % x 30 / 80 missing = 7.5 -> 8
	check(g.repair_cost() == {"materials": 8}, "the repair costs half the price times the missing share, rounded up (%s)" % str(g.repair_cost()))
	await wait(1.0)
	check(g.hp == 50.0, "it doesn't heal by itself")
	var mat := int(game.economy.amount("materials"))
	var r := game.command("repair", {"building": g.nid})
	check(r["ok"] and mat - int(game.economy.amount("materials")) == 8 and g.repairing, "the repair is ordered and paid")
	var done := await finish_work()
	check(done and g.hp == 80.0 and not g.repairing and logs.any(func(l: String) -> bool: return "repaired" in l), "a builder repairs it to full HP")
	check(not game.command("repair", {"building": g.nid})["ok"], "nothing to repair at full HP")
	# Cancelling before any work refunds it all.
	g.take_damage(40.0)
	mat = int(game.economy.amount("materials"))
	game.command("repair", {"building": g.nid})
	game.construction.cancel(g)
	check(int(game.economy.amount("materials")) == mat and not g.repairing and g.hp == 40.0, "a repair cancelled before any work: everything back")
	reset_village()


func _test_devastated_tower() -> void:
	var v := game.player_village
	var spot := find_spot("tower", v.center + Vector2i(6, 0))
	var r := game.command("place_building", {"kind": "tower", "tile": spot})
	await finish_work()
	var tw := game.entity(int(r.get("id", 0))) as Tower
	check(tw != null and tw.complete and tw.hp == 100.0 and tw.is_solid(), "a new watchtower: 100 HP")
	var ar := game.army.recruit("archer")
	game.army.station(ar, tw)
	await wait_until(func() -> bool: return tw.garrison == ar, 60.0)
	tw.take_damage(1000.0)
	check(tw.devastated and tw.hp == 0.0 and not tw.working() and not tw.is_solid() and tw.sight_radius() == 0.0, "at 0 HP it is devastated: it does nothing, blocks nothing, sees nothing")
	check(tw.garrison == null and (ar.state == MilitaryUnit.State.RETURNING or ar.state == MilitaryUnit.State.RESERVE), "its archer walks back home")
	check(logs.any(func(l: String) -> bool: return "devastated" in l), "logged")
	check(game.building_info(tw)["title"].begins_with("Devastated"), "its panel says so")
	check(game.army.station_error(ar, tw) != "", "nobody can be stationed on it")
	check(not tw.can_upgrade(), "it can't be upgraded")
	check(tw.repair_cost() == {"materials": 15}, "repairing it costs half its price (%s)" % str(tw.repair_cost()))
	game.command("repair", {"building": tw.nid})
	await finish_work()
	check(not tw.devastated and tw.hp == 100.0 and tw.working() and tw.is_solid(), "repaired, it works again")
	# A ruined watchtower restored: a devastated watchtower repaired.
	game.construction.order_upgrade(tw)
	await finish_work()
	check(tw.level == 2 and tw.hp == 200.0, "a level 2 watchtower has 200 HP")
	tw.take_damage(1000.0)
	check(tw.repair_cost() == {"materials": 30}, "devastated after an upgrade: half of price and upgrade (%s)" % str(tw.repair_cost()))
	game.command("repair", {"building": tw.nid})
	await finish_work()
	game.world.remove_building(tw)
	await frames(2)


func _test_farm() -> void:
	var farm: Farm = game.player_village.buildings().filter(func(b: Building) -> bool: return b is Farm)[0]
	var farmer := farm.farmer
	farm.take_damage(1000.0)
	check(farm.devastated and farm.farmer == null and not farm.working(), "a devastated farm loses its farmer")
	check(farm._rubble != null and farm._rubble.visible, "rubble lies on it")
	game.command("repair", {"building": farm.nid})
	await finish_work()
	check(not farm.devastated and farm.working() and farm.farmer != null, "repaired, a farmer takes it again (%s)" % (farm.farmer.label() if farm.farmer else "none"))
	check(farmer == null or farm.farmer == farmer, "the same farmer")


func _test_levels() -> void:
	var g := gate()
	g.take_damage(30.0)
	check(g.can_upgrade() and g.upgrade_cost() == {"materials": 30}, "a gate can be upgraded (30 material)")
	var r := game.command("upgrade_tower", {"building": g.nid})
	await finish_work()
	check(r["ok"] and g.level == 2 and g.max_hp() == 160.0 and g.hp == 130.0, "level 2: 160 max HP, keeping the 30 it was missing (%.0f)" % g.hp)
	check(g.sprite.texture == Art.tex("gate_2"), "it looks it")
	g.take_damage(1000.0)
	check(g.devastated and not g.can_upgrade() and g.sprite.texture == Art.tex("gate_ruin"), "a devastated gate: its ruin, no upgrade")
	check(g.repair_cost() == {"materials": 35}, "its repair: half of price and upgrade (%s)" % str(g.repair_cost()))
	var w := walls_beside(g.tile)[0]
	check(w.upgrade_cost() == {"materials": 35}, "a wall upgrades for 35")
	reset_village()


func _test_teardown_refund() -> void:
	var farm: Farm = game.player_village.buildings().filter(func(b: Building) -> bool: return b is Farm)[0]
	farm.hp = farm.max_hp() * 0.5
	# 50 material x 33 % x 50 % = 8.25 -> 8
	check(farm.teardown_refund() == 8, "tear-down gives back less of a damaged building (%d)" % farm.teardown_refund())
	farm.hp = 0.0
	check(farm.teardown_refund() == 0, "nothing of a devastated one")
	farm.hp = farm.max_hp()


## The queue's tiers: hut rebuilds first, then gates and walls, then the rest.
func _test_huts_first() -> void:
	var c := game.construction
	await finish_work()
	var farm: Building = game.player_village.buildings().filter(func(b: Building) -> bool: return b is Farm and b.working())[0]
	farm.take_damage(30.0)
	c.order_repair(farm)  # (ordered first, done last)
	var g := gate()
	g.take_damage(30.0)
	c.order_repair(g)
	var hut: Hut = game.player_village.intact_huts().back()
	var res := hut.resident
	hut.resident = null  # (nobody dies in this test)
	hut.destroy("test")
	hut.resident = res
	c.order_rebuild(hut)
	for site in c.queue:
		site.builder = null
	var first := c.claim(game.hero)
	check(c.queue.find(g) < c.queue.find(hut) and first == hut, "a hut rebuild ordered later still comes first")
	c.release(first, false)
	var second := c.claim(game.hero)
	check(second == hut, "and again when a job is picked anew (after fleeing)")
	var third := c.claim(game.player_village.hero)
	check(c.queue.find(farm) < c.queue.find(g) and third == g, "then the gate, before a farm's repair ordered earlier")
	c.release(third, false)
	c.release(second, false)
	await finish_work()
	check(hut.is_intact() and g.hp == g.max_hp() and farm.hp == farm.max_hp(), "all get done")
	reset_village()


## Config.BUILD_QUEUE: within a bucket the nearest job, unless an older one
## has waited long enough; started jobs first; a job fled from too often
## drops a bucket until it has been calm a while; none with an enemy in sight
## near it.
func _test_queue_rules() -> void:
	var c := game.construction
	var v := game.player_village
	await finish_work()
	var hero := game.hero
	var from: Vector2 = Vector2(v.center) if hero.at_home else hero.grid_pos
	var cands: Array = v.buildings().filter(func(b: Building) -> bool: return (b is Workplace or b.kind == "wall_tower") and b.working())
	cands.sort_custom(func(a: Building, b: Building) -> bool: return Vector2(a.tile).distance_to(from) < Vector2(b.tile).distance_to(from))
	var near: Building = cands.front()
	var far: Building = cands.back()
	var q: Dictionary = Config.BUILD_QUEUE
	far.take_damage(10.0)
	c.order_repair(far)  # (older)
	near.take_damage(10.0)
	c.order_repair(near)
	var first := c.claim(hero)
	check(c.bucket(near) == c.bucket(far) and first == near, "the same bucket: the nearest job first")
	c.release(first, false)
	var gap := Vector2(far.tile).distance_to(from) - Vector2(near.tile).distance_to(from)
	far.queued_at -= (gap / float(q["age_tiles_per_min"]) + 0.5) * 60.0
	first = c.claim(hero)
	check(first == far, "but one that has waited long enough goes first (%.0f tiles further)" % gap)
	c.release(first, false)
	near.repair_progress = 0.1
	first = c.claim(hero)
	check(first == near, "a job already started goes first in its bucket")
	c.release(first, false)
	# Demoted after fleeing from it twice; back once calm.
	var g := gate()
	g.take_damage(20.0)
	c.order_repair(g)
	first = c.claim(hero)
	check(first == g, "a gate before the rest")
	for i in int(q["demote_after"]):
		c.release(g, false, true)
		if i + 1 < int(q["demote_after"]):
			c.claim(hero)
	first = c.claim(hero)
	check(c.bucket(g) == c.bucket(near) and first == near, "fled from %d times, the gate drops a bucket" % int(q["demote_after"]))
	c.release(first, false)
	c._process(float(q["demote_calm"]) + 0.1)
	first = c.claim(hero)
	check(g.interrupts == 0 and first == g, "and is back after %d s without enemies near it" % int(q["demote_calm"]))
	c.release(first, false)
	# An enemy in sight near the gate: skipped meanwhile.
	var e := spawn_still("goblin", Vector2(road_out(2)))
	first = c.claim(hero)
	check(c.in_danger(g) and first != g, "with an enemy in sight near it, the gate waits")
	if first:
		c.release(first, false)
	kill(e)
	await clear_enemies()
	for site: Building in [far, near, g]:
		c.cancel(site)
		site.hp = site.max_hp()


## A builder done with a job walks straight on to the next one close by.
func _test_chain() -> void:
	var c := game.construction
	await finish_work()
	var builders: Array = game.population.civilians.filter(func(x: Civilian) -> bool: return x is Builder)
	var walls := walls_beside(game.player_village.gates[0])
	for w in walls:
		w.take_damage(30.0)
		c.order_repair(w)
	var done := await wait_until(func() -> bool: return walls.any(func(w: Building) -> bool: return w.hp >= w.max_hp()), 90.0)
	var other: Building = walls[0] if walls[0].hp < walls[0].max_hp() else walls[1]
	var b: Builder = builders[0] if builders.size() == 1 else null
	check(done and walls.size() == 2 and b != null and not b.at_home and b.job.site == other, "the builder goes straight on to the wall next to it, not home first")
	await finish_work()
	reset_village()


# --- the siege field ----------------------------------------------------------------------------------

func _test_field() -> void:
	var v := game.player_village
	var g := gate()
	var front := g.tile - inward(g.tile)
	var s := game.siege
	check(s.in_zone(v, front) and not s.in_zone(v, v.rect.position - Vector2i(5, 5)), "the band around the walls is the siege zone")
	check(s.next_step(v, front, false) == g.tile and s.barrier_at(v, g.tile) == g, "in front of the gate the way in leads through it")
	# A corner tower: broken, it leads nowhere while both its walls stand.
	var corner: Building = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower")[0]
	var adj_huts := MapData.neighbors4(corner.tile).filter(func(t: Vector2i) -> bool: return s.hut_at(v, t) != null)
	check(adj_huts.is_empty(), "no hut is next to a corner (only diagonally)")
	corner.take_damage(1e6)
	check(corner.devastated and not corner.is_solid(), "a corner tower can be devastated")
	var through := s.value(v, corner.tile, false)
	var wall_cost := s.enter_cost(v, walls_beside(g.tile)[0].tile, false)
	check(through >= wall_cost, "through a broken corner tower still means breaking a wall (%d >= %d)" % [through, wall_cost])
	reset_village()


func _test_break_in() -> void:
	var v := game.player_village
	var g := gate()
	var hut_in := game.map.building_at(g.tile + inward(g.tile)) as Hut
	var huts := intact()
	var gob := spawn("goblin", Vector2(road_out(7)))
	gob.max_hp = 1e6
	gob.hp = 1e6
	var at_gate := await wait_until(func() -> bool: return gob.breach == g, 40.0)
	check(at_gate and gob.sieging, "a goblin leaves its road near the village and goes for the gate")
	await wait(3.0)
	check(not gob.dead and g.hp < 80.0 and intact() == huts and gob.current_tile() != g.tile, "it stops in front of the gate and hits it (%.0f HP left); no hut burns yet" % g.hp)
	var gone := await wait_until(func() -> bool: return gob.dead, 60.0)
	check(gone and g.devastated, "the gate breaks; the goblin walks in")
	check(intact() == huts - 1 and hut_in != null and hut_in.ruined, "it burns the nearest hut (behind the gate)")
	check(logs.any(func(l: String) -> bool: return "under attack" in l), "the first blow at the gate is announced")
	reset_village()


func _test_weaker_wall() -> void:
	var g := gate()
	g.level = 3
	g.hp = g.max_hp()
	var w := walls_beside(g.tile)[0]
	w.hp = 20.0
	game.siege.mark_stale(game.player_village, true)
	var gob := spawn("goblin", Vector2(road_out(7)))
	gob.max_hp = 1e6
	gob.hp = 1e6
	var hit := await wait_until(func() -> bool: return is_instance_valid(gob.breach) and gob.breach != null, 40.0)
	check(hit and gob.breach == w, "with the gate upgraded, the weaker wall beside it is attacked (%s)" % (gob.breach.label() if hit else "none"))
	var gone := await wait_until(func() -> bool: return gob.dead, 40.0)
	check(gone and w.devastated and g.hp == g.max_hp(), "it breaks the wall and gets in past the gate")
	reset_village()


func _test_broken_wall() -> void:
	var g := gate()
	var w := walls_beside(g.tile)[0]
	w.take_damage(1e6)
	var huts := intact()
	var gob := spawn("goblin", Vector2(road_out(7)))
	var gone := await wait_until(func() -> bool: return gob.dead, 40.0)
	check(gone and g.hp == g.max_hp() and intact() == huts - 1, "a broken wall: enemies walk round the gate and in through the gap")
	reset_village()


func _test_fight_first() -> void:
	var g := gate()
	var gob := spawn("goblin", Vector2(road_out(7)))
	gob.max_hp = 1e6
	gob.hp = 1e6
	await wait_until(func() -> bool: return gob.breach == g, 40.0)
	var hero := game.hero
	hero.max_hp = 1e6
	hero.hp = 1e6
	_bench_hero(false)
	hero.set_grid_pos(gob.grid_pos + Vector2(0.4, 0.0))
	await wait(2.0)
	var hp0 := g.hp
	await wait(2.0)
	check(logs.any(func(l: String) -> bool: return "fights the hero" in l) and g.hp == hp0, "a defender comes first: the goblin turns from the gate to fight the hero")
	_bench_hero(true)
	await clear_enemies()
	hero.hp = 100.0
	hero.max_hp = Config.hero_stat("hp", hero.level)
	hero.hp = hero.max_hp
	reset_village()


func _test_flyer() -> void:
	var g := gate()
	var huts := intact()
	var ga := spawn("gargoyle", Vector2(road_out(6)))
	var gone := await wait_until(func() -> bool: return ga.dead, 60.0)
	check(gone and g.hp == g.max_hp() and intact() == huts - 1, "a gargoyle flies over the walls and burns a hut; the gate is untouched")
	reset_village()


func _test_slip() -> void:
	var v := game.player_village
	var g := gate()
	v.economy.add("food", 500 - v.economy.amount("food"))
	var rat := spawn("rat", Vector2(road_out(4)))
	rat.max_hp = 1e6
	rat.hp = 1e6
	for b in game.world.buildings:
		if b is Farm:
			(rat.behavior as RatBehavior).ignored[b] = true  # (straight to the gate)
	var at := await wait_until(func() -> bool: return rat.dead or rat.current_tile() == g.tile, 40.0)
	check(at and not rat.dead, "a rat reaches the gate")
	await wait(1.5)
	check(not rat.dead and rat._slip > 0.0 and not logs.any(func(l: String) -> bool: return "got into the village and ate" in l), "an intact gate holds it a while")
	var gone := await wait_until(when_gone(rat, func(x: Object) -> bool: return x.dead), 20.0)
	check(gone and logs.any(func(l: String) -> bool: return "got into the village and ate" in l) and g.hp == g.max_hp(), "then it slips through and eats food; the gate is unhurt")
	reset_village()


func _test_witch() -> void:
	var g := gate()
	var wi := spawn("witch", Vector2(road_out(7)))
	wi.max_hp = 1e6
	wi.hp = 1e6
	var hurt := await wait_until(func() -> bool: return g.hp < g.max_hp(), 60.0)
	check(hurt and not wi.dead, "a witch casts her bolts at the gate when nothing else is in range")
	await clear_enemies()
	reset_village()


func _test_no_siege() -> void:
	var g := gate()
	var huts := intact()
	for c in game.corpses.corpses.duplicate():
		game.corpses.remove(c)
	var ne := spawn("necromancer", Vector2(road_out(6)))
	ne.max_hp = 1e6
	ne.hp = 1e6
	var waiting := await wait_until(func() -> bool: return ne.breach == g, 90.0)
	await wait(5.0)
	check(waiting and not ne.dead and g.hp == g.max_hp() and intact() == huts, "a necromancer can't hurt the gate: it waits in front of it")
	var gone := await wait_until(func() -> bool: return ne.dead, float(Config.SIEGE["stuck_slip"]) + 30.0)
	check(gone and intact() == huts - 1 and g.hp == g.max_hp(), "after a while it slips past and burns a hut (no stalled wave)")
	reset_village()


func _test_exposed() -> void:
	var v := game.player_village
	var walker: Civilian = null
	for c in game.population.civilians:
		if not c.at_home:
			walker = c
			break
	if walker == null:
		walker = game.population.civilians[0]
		walker.at_home = false
	var keep := walker.grid_pos
	walker.set_grid_pos(Vector2(v.center))
	await frames(2)
	check(walker.inside_walls() and not walker.is_exposed(), "inside the walls a villager is safe")
	var e := spawn_still("goblin", Vector2(v.center) + Vector2(1, 0))
	e.process_mode = Node.PROCESS_MODE_DISABLED  # (it stays there)
	await wait(0.6)
	check(game.siege.breached(v.id) and not walker.inside_walls(), "with an enemy inside the walls, villagers in there are exposed")
	await clear_enemies()
	await wait(0.6)
	check(not game.siege.breached(v.id), "safe again once it's gone")
	walker.set_grid_pos(keep)
	check(e == null or not is_instance_valid(e) or e.dead, "(the enemy is gone)")


func _test_hero_targets() -> void:
	var v := game.player_village
	var hero := game.hero
	var r := v.rect
	# Off a corner, far from every gate.
	var by_wall := Vector2(r.position.x - 4, r.position.y - 4)
	var far := true
	for gt in v.gates:
		far = far and by_wall.distance_to(Vector2(gt)) > Config.HERO["alert_radius"]
	var e := spawn_still("goblin", by_wall)
	hero.set_grid_pos(Vector2(v.center))
	check(far and hero._pick_enemy() == e, "the hero goes for enemies by the walls, not only by the gates")
	e.process_mode = Node.PROCESS_MODE_DISABLED
	var inside := spawn_still("goblin", Vector2(v.center) + Vector2(0, 1))
	inside.process_mode = Node.PROCESS_MODE_DISABLED
	var near := spawn_still("goblin", Vector2(v.center) + Vector2(0, -0.5))
	near.process_mode = Node.PROCESS_MODE_DISABLED
	near.set_grid_pos(Vector2(r.position.x - 1, v.center.y))
	hero.set_grid_pos(Vector2(r.position.x, v.center.y))
	check(hero._pick_enemy() == inside, "enemies inside the walls come first")
	for x in [e, inside, near]:
		kill(x)
	hero.set_grid_pos(Vector2(v.center))


func _test_push() -> void:
	var g := gate()
	var gob := spawn("goblin", Vector2(road_out(7)))
	gob.max_hp = 1e6
	gob.hp = 1e6
	await wait_until(func() -> bool: return gob.breach == g, 40.0)
	var v0 := game.siege.value(game.player_village, gob.current_tile(), false)
	var moved := gob.push_back(2.0, 1.0)
	check(moved and game.siege.value(game.player_village, gob.current_tile(), false) > v0 and gob.breach == null, "spatial magic throws a besieger back, away from the huts")
	await clear_enemies()
	reset_village()


func _test_save() -> void:
	var g := gate()
	g.take_damage(30.0)
	var w := walls_beside(g.tile)[0]
	w.take_damage(1e6)
	var body := SaveGame.capture(game)
	var gs: Dictionary = {}
	var ws: Dictionary = {}
	for d: Dictionary in body["buildings"]:
		if d["n"] == g.nid:
			gs = d
		if d["n"] == w.nid:
			ws = d
	check(float(gs.get("hp", 0.0)) == 50.0 and bool(ws.get("dv", false)), "a save holds HP and devastation")
	reset_village()


func _test_stats() -> void:
	var st := game.stats
	var vid := game.player_village.id
	check(st.value(vid, "building_damage") > 0.0 and st.value(vid, "devastated") > 0.0 and st.value(vid, "repairs") > 0.0, "the statistics count damage, devastation and repairs")
	check(st.value(vid, "spend.materials.repairs") > 0.0, "material spent on repairs")
