extends "res://tests/bot_base.gd"
## Headless test of the military expansion (docs/military-design.md): the
## config's tech tree and curves, barracks (benches, sorties, upgrades),
## unit HP, downing and reviving, healing, every attack effect, fire
## elementals, specialising and the Spatial Archmage. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/military_bot.tscn
## Exits 0 when every check passes.

const SEED := 20260928

var far := Vector2i.ZERO


## A real tap (press and release) on a control, as a player would.
func tap(c: Control) -> void:
	var pos := c.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)
		await frames(1)


func on_screen(c: Control) -> bool:
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(c.get_global_rect())


func find_spot(kind: String, near: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			if game.construction.placement_error(kind, t) == "":
				var d := Vector2(t).distance_to(Vector2(near))
				if d < best_d:
					best_d = d
					best = t
	return best


## An enemy standing still at `at` (grid), with `hp_scale` x its HP.
func spawn_dummy(kind: String, at: Vector2, hp_scale: float) -> Enemy:
	game.waves._spawn({"kind": kind, "spawn": far, "hp_scale": hp_scale})
	var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
	e.speed = 0.0
	e.set_grid_pos(at)
	return e


func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		kill(e)
	await frames(2)


## A finished building of `kind` near `near`.
func build(kind: String, near: Vector2i) -> Building:
	game.economy.add("materials", 500)
	game.economy.add("gold", 500)
	var b := game.construction.place(kind, find_spot(kind, near))
	b.progress = 1.0
	b.finish()
	await frames(2)
	return b


func _run() -> void:
	_test_config()
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEED
	game.reveal_map = true
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true  # (this test predates unit unlocks: tests/world_bot.gd)
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	far = game.map.edge_spawns[0]
	Engine.time_scale = 4.0
	await _test_barracks()
	await _test_downing()
	await _test_effects()
	await _test_branching()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- config ------------------------------------------------------------------------------

func _dps(kind: String, lv: int) -> float:
	return Config.unit_stat(kind, "damage", lv) / Config.unit_stat(kind, "cooldown", lv)


func _test_config() -> void:
	var min_tower: float = Config.TOWER_RANGE.values().min()
	var ranges_ok := true
	var tree_ok := true
	var curves_ok := true
	for k in Config.MILITARY:
		var sp: Dictionary = Config.MILITARY[k]
		if sp.has("range"):
			ranges_ok = ranges_ok and sp["range"] < min_tower
		for b in sp.get("branches", []):
			tree_ok = tree_ok and Config.MILITARY.has(b) and Config.MILITARY[b]["branch_of"] == k and not Config.MILITARY[b]["recruit"]
		tree_ok = tree_ok and Config.MILITARY_TREE.has(k) and BEHAVIORS_HAVE(sp["role"])
		tree_ok = tree_ok and (not sp.has("attack") or Config.ATTACKS.has(sp["attack"]))
		for key in sp["stats"]:
			var a := Config.unit_stat(k, key, 0)
			var z := Config.unit_stat(k, key, Config.MAX_UNIT_LEVEL - 1)
			var ends: Array = sp["stats"][key]
			curves_ok = curves_ok and is_equal_approx(a, ends[0]) and is_equal_approx(z, ends[1])
	check(Config.MAX_UNIT_LEVEL == 10, "units go up to level 10")
	check(ranges_ok, "every unit's own range is below the smallest tower range (%.1f)" % min_tower)
	check(tree_ok, "tech tree: every branch exists, points back, can't be recruited; roles and attacks exist")
	check(curves_ok, "stat curves run from their level 1 to their level 10 values")
	check(absf(_dps("archer", 2) - _dps("crossbowman", 0)) < 0.5, "archer L3 and crossbowman L1 deal about the same DPS (%.1f / %.1f)" % [_dps("archer", 2), _dps("crossbowman", 0)])
	check(_dps("swiftbowman", 0) < _dps("archer", 2) and Config.unit_stat("swiftbowman", "cooldown", 0) * 2.0 <= Config.unit_stat("archer", "cooldown", 2), "swiftbowman: a bit less DPS, at least twice the fire rate")
	check(Config.unit_stat("crossbowman", "cooldown", 0) > 2.0 * Config.unit_stat("archer", "cooldown", 2) and Config.MILITARY["crossbowman"]["range"] > Config.MILITARY["archer"]["range"], "crossbowman: much slower fire, more range")
	check(Config.unit_stat("shield_bearer", "hp", 0) >= 0.8 * Config.ENEMIES["ork"]["hp"] and Config.unit_stat("shield_bearer", "hp", 0) > 1.5 * Config.unit_stat("archer", "hp", 0) and Config.MILITARY["shield_bearer"]["posts"] == ["barracks"], "shield bearer: ork-like HP, barracks only")
	check(Config.unit_stat("healing_mage", "hp", 0) < Config.unit_stat("apprentice", "hp", 0) and Config.unit_stat("apprentice", "hp", 0) < Config.unit_stat("archer", "hp", 0), "HP: healing mage < apprentice < archer")
	check(Config.unit_stat("ice_mage", "slow", 9) < Config.unit_stat("ice_mage", "slow", 0), "the ice mage's slow grows with its level")
	var top := 0
	for k in Config.MILITARY:
		for lv in Config.MAX_UNIT_LEVEL - 1:
			top = maxi(top, int(Config.unit_upgrade_cost(k, lv).get("gold", 0)))
	check(top <= 300 and Config.unit_upgrade_cost("archer", Config.MAX_UNIT_LEVEL - 1).is_empty(), "upgrades cost at most 300 gold; none past level 10")
	check(Config.unit_revive_time(9) > Config.unit_revive_time(0), "revive time grows with the level (%.0f to %.0f s)" % [Config.unit_revive_time(0), Config.unit_revive_time(9)])
	check(Config.BARRACKS_LEVELS.map(func(l: Dictionary) -> int: return l["slots"]) == [1, 2, 3], "barracks: 1 / 2 / 3 benches")


func BEHAVIORS_HAVE(role: String) -> bool:
	return MilitaryUnit.BEHAVIORS.has(role)


# --- barracks ------------------------------------------------------------------------------

var barracks: Barracks


func _test_barracks() -> void:
	var gate: Vector2i = game.player_village.gates.filter(func(g: Vector2i) -> bool: return game.map.is_road(g + (g - game.player_village.center).sign() * 2))[0]
	var out_dir := (gate - game.player_village.center).sign()
	barracks = await build("barracks", gate + out_dir * 3)
	check(barracks is Barracks and barracks.tiles().size() == 4, "barracks: a 2x2 building")
	check(barracks.capacity() == 1 and barracks.slots.size() == 1, "level 1 has one bench")
	var tower: Tower = game.world.buildings.filter(func(b: Building) -> bool: return b is Tower and b.complete)[0]
	var sb := game.army.recruit("shield_bearer")
	check(sb != null, "shield bearer recruited")
	check(game.army.station_error(sb, tower) == "A shield bearer can't serve on towers", "shield bearers are refused on towers")
	check(game.army.station(sb, barracks), "a shield bearer is sent to the barracks")
	await wait_until(func() -> bool: return barracks.slots[0] == sb, 60.0)
	check(barracks.slots[0] == sb and barracks._bench_sprites[0].visible, "it sits on the bench")
	var ar := game.army.recruit("archer")
	check(game.army.station_error(ar, barracks) == "Already manned: withdraw its unit first", "a full barracks takes no one else")
	# The panel: one line per bench, per-bench actions.
	var inf := barracks.info()
	var labels: Array = inf["actions"].map(func(a: Dictionary) -> String: return a["label"])
	check(labels.any(func(l: String) -> bool: return "Withdraw shield bearer (bench 1)" == l) and labels.any(func(l: String) -> bool: return l.begins_with("Upgrade barracks")), "barracks panel: withdraw per bench and upgrade the barracks")
	# Upgrade: two benches, more range.
	var r0 := barracks.activation_range()
	check(game.construction.order_upgrade(barracks), "barracks upgrade ordered")
	barracks.upgrade_progress = barracks.upgrade_time
	barracks.finish_upgrade()
	await frames(2)
	check(barracks.level == 2 and barracks.capacity() == 2 and barracks.slots.size() == 2 and barracks.activation_range() > r0, "level 2: two benches and more range")
	check(game.army.station(ar, barracks), "an archer takes the second bench")
	await wait_until(func() -> bool: return barracks.slots[1] == ar, 60.0)
	check(barracks.units().size() == 2, "both benches are taken")
	# Sortie: an enemy in range brings everyone out; they come back after.
	var c := barracks.act_center()
	var foe := spawn_dummy("goblin", c + Vector2(out_dir) * (barracks.activation_range() - 0.5), 2.0)
	var went := await wait_until(func() -> bool: return sb.out and ar.out, 5.0)
	check(went and is_instance_valid(sb.walker) and is_instance_valid(ar.walker), "an enemy within range: everyone turns out")
	var killed := await wait_until(func() -> bool: return foe.dead, 60.0)
	check(killed, "they kill it (hp %.0f, sb %s at %s, ar %s, foe at %s)" % [foe.hp, sb.state_text(), sb.walker.grid_pos if is_instance_valid(sb.walker) else Vector2.ZERO, ar.state_text(), foe.grid_pos])
	var back := await wait_until(func() -> bool: return not sb.out and not ar.out, 60.0)
	check(back and sb.state == MilitaryUnit.State.STATIONED and barracks._bench_sprites[0].visible, "no enemy left: they walk back to their benches")
	# Out of range: nobody moves.
	var distant := spawn_dummy("goblin", c + Vector2(out_dir) * (barracks.activation_range() + Config.SORTIE_LEASH + 3.0), 1.0)
	await wait(2.0)
	check(not sb.out and not ar.out, "an enemy beyond the range doesn't bring anyone out")
	distant.take_damage(1e9)
	# Withdraw one bench; the other stays.
	game.army.unstation(ar)
	check(barracks.slots[1] == null and barracks.slots[0] == sb, "withdrawing frees just that bench")
	await wait_until(func() -> bool: return ar.state == MilitaryUnit.State.RESERVE, 60.0)


# --- HP, downing, reviving, healing -------------------------------------------------------

func _test_downing() -> void:
	var sb: MilitaryUnit = barracks.slots[0]
	# Regen on the bench.
	sb.hp = sb.max_hp() * 0.5
	var h0 := sb.hp
	await wait(2.0)
	check(sb.hp > h0, "units heal on the bench (%.1f -> %.1f, %s)" % [h0, sb.hp, sb.state_text()])
	# Downed during a sortie: back on its bench after the revive time.
	sb.hp = sb.max_hp()
	var c := barracks.act_center()
	var foe := spawn_dummy("ork", c + Vector2(1.5, 0), 50.0)
	await wait_until(func() -> bool: return sb.out, 5.0)
	(sb.walker as Soldier).take_damage(1e9, foe)
	check(sb.is_downed() and sb.revive_at_post and barracks.slots[0] == sb and sb.walker == null, "0 HP: downed, keeps its bench")
	check(is_equal_approx(sb.revive_left, Config.unit_revive_time(sb.level)), "revives after its level's revive time")
	check(game.army.upgrade_error(sb) != "" and game.army.station_error(sb, barracks) != "", "nothing can be done with a downed unit")
	await wait(1.5)
	check(not sb.out and barracks.slots[0] == sb and sb.is_downed(), "it doesn't turn out while downed")
	foe.take_damage(1e9)
	sb.revive_left = 0.2
	await wait(0.5)
	check(sb.state == MilitaryUnit.State.STATIONED and is_equal_approx(sb.hp, sb.max_hp()), "revived on its bench with full HP")
	# Downed while walking: revives in the reserve.
	var ar: MilitaryUnit = game.army.reserve().filter(func(u: MilitaryUnit) -> bool: return u.kind == "archer")[0]
	var tower: Tower = game.world.buildings.filter(func(b: Building) -> bool: return b is Tower and b.complete and b.garrison == null and b.incoming == null)[0]
	check(game.army.station(ar, tower), "an archer marches to a tower")
	await frames(3)
	(ar.walker as Soldier).take_damage(1e9)
	check(ar.is_downed() and not ar.revive_at_post and ar.post == null and tower.incoming == null, "downed on the way: the tower is free again")
	var hud := game.hud
	hud._rebuild_reserve()
	await frames(2)
	check(game.army.downed().has(ar), "the downed unit waits (dimmed) in the reserve list")
	ar.revive_left = 0.1
	await wait(0.4)
	check(ar.state == MilitaryUnit.State.RESERVE, "revived in the reserve")
	# Regen in the reserve, same speed as the bench.
	ar.hp = 1.0
	await wait(2.0)
	check(ar.hp > 1.0, "unused units heal in the reserve too")
	# Tower units can't be hurt (no body outside).
	check(game.army.station(ar, tower), "back to the tower")
	await wait_until(func() -> bool: return tower.garrison == ar, 60.0)
	check(ar.walker == null, "on a tower it has no body to hit")


# --- attack effects -----------------------------------------------------------------------

## A unit of `kind` at level `lv`, stationed on a free tower; returns [unit, tower].
func _manned(kind: String) -> Array:
	var tower: Tower = null
	for b in game.world.buildings:
		if b is Tower and b.complete and b.garrison == null and b.incoming == null:
			tower = b
			break
	if tower == null:
		tower = await build("tower", game.player_village.center + Vector2i(0, -6))
	var base: String = Config.MILITARY[kind].get("branch_of", kind)
	game.economy.add("gold", 2000)
	var u := game.army.recruit(base)
	if kind != base:
		u.level = Config.BRANCH_MIN_LEVEL - 1
		check(game.army.upgrade(u, kind), "a level %d %s becomes a %s" % [Config.BRANCH_MIN_LEVEL, base, kind])
	game.army.station(u, tower)
	await wait_until(func() -> bool: return tower.garrison == u, 60.0)
	return [u, tower]


func _near_tower(tower: Tower, d: float) -> Vector2:
	var c: Vector2 = tower.act_center()
	var dir := (Vector2(tower.tile) - Vector2(game.player_village.center)).normalized()
	return c + dir * d


func _test_effects() -> void:
	await clear_enemies()
	# Fire mage: splash + explosion.
	var fm: Array = await _manned("fire_mage")
	var p := _near_tower(fm[1], 2.0)
	var a := spawn_dummy("ork", p, 20.0)
	var b := spawn_dummy("ork", p + Vector2(0.4, 0.3), 20.0)
	var bhp := b.hp
	var ahp := a.hp
	var exploded := await wait_until(func() -> bool: return game.world.effects.get_children().any(func(n: Node) -> bool: return n.get_script() == Combat.BURST_SCRIPT and n.kind == "explosion"), 10.0)
	await wait(0.3)
	check(exploded, "fireballs explode")
	check(a.hp < ahp and b.hp < bhp, "the explosion also hurts enemies next to the one hit")
	await clear_enemies()
	game.army.unstation(fm[0])
	# Ice mage: slow.
	var im: Array = await _manned("ice_mage")
	var e := spawn_dummy("goblin", _near_tower(im[1], 2.0), 20.0)
	e.speed = 1.0
	e.base_speed = 1.0
	var slowed := await wait_until(func() -> bool: return e.is_slowed(), 10.0)
	check(slowed and e.speed < 1.0 and is_equal_approx(e.speed, Config.unit_stat("ice_mage", "slow", 0)), "frost orbs slow the enemy hit (x%.2f)" % e.speed)
	e.speed = 0.0
	await clear_enemies()
	game.army.unstation(im[0])
	# Spatial mage: pushed back along its road, then immune for a while.
	var sm: Array = await _manned("spatial_mage")
	# An enemy on its own road, as close to the tower as the road comes (within range).
	var w := spawn_dummy("goblin", _near_tower(sm[1], 2.0), 20.0)
	var best := -1
	var best_d := INF
	for i in range(1, w.path.size()):
		var d: float = w.path[i].distance_to(sm[1].act_center())
		if d < best_d:
			best_d = d
			best = i
	w.path_index = best
	w.set_grid_pos(w.path[best])
	var left0 := w.remaining()
	var pushed := await wait_until(func() -> bool: return w.remaining() > left0, 10.0)
	check(pushed and best_d < sm[1].act_range(), "warp orbs throw the enemy back along its road, away from the village (%d -> %d tiles to go)" % [left0, w.remaining()])
	check(w._push_immune > 0.0, "after a push it's immune to pushes for a while")
	await clear_enemies()
	game.army.unstation(sm[0])
	# Healing mage: heals units and heroes of every village, not summons.
	var hm: Array = await _manned("healing_mage")
	var tw: Tower = hm[1]
	check(is_equal_approx(HealerBehavior.heal_radius(tw, hm[0]), tw.act_range()) and not is_equal_approx(tw.act_range(), hm[0].stat("radius")), "in a tower it heals as far as the tower reaches (%.1f tiles, not its own %.1f)" % [tw.act_range(), hm[0].stat("radius")])
	var hurt := game.army.recruit("archer")
	var far: Soldier = game.army._spawn_walker(hurt, tw.outer_tile())
	far.set_process(false)
	hurt.state = MilitaryUnit.State.MARCHING
	far.set_grid_pos(tw.act_center() + Vector2(tw.act_range() - 0.15, 0.0))
	hurt.hp = 5.0
	check(await wait_until(func() -> bool: return hurt.hp > 5.0, 10.0), "a unit near the edge of the tower's range gets healed")
	far.set_grid_pos(tw.act_center() + Vector2(tw.act_range() + 0.6, 0.0))
	await frames(2)
	var hp1 := hurt.hp
	await wait(Config.unit_stat("healing_mage", "cooldown", hm[0].level) * 2.0 + 0.5)
	check(is_equal_approx(hurt.hp, hp1), "one just outside it doesn't")
	far.queue_free()
	hurt.walker = null
	hurt.state = MilitaryUnit.State.RESERVE
	var field: Soldier = game.army._spawn_walker(hurt, tw.outer_tile())
	field.set_process(false)
	check(is_equal_approx(HealerBehavior.heal_radius(field, hm[0]), hm[0].stat("radius")), "out of a tower (in the field): its own radius (%.1f tiles)" % hm[0].stat("radius"))
	field.queue_free()
	hurt.walker = null
	var hero := game.hero
	hero.hp = hero.max_hp * 0.4
	var hero_home := hero.grid_pos
	hero.set_grid_pos(hm[1].act_center() + Vector2(0.5, 0.5))
	var el: EarthElemental = SummonerBehavior.ELEMENTAL_SCRIPT.new()
	el.setup(game, hm[1].outer_tile(), hm[1].outer_tile(), 50.0, 1.0)
	el.village = game.player_village
	game.world.objects.add_child(el)
	el.hp = 10.0
	var h0 := hero.hp
	var healed := await wait_until(func() -> bool: return hero.hp > h0, 10.0)
	check(healed, "the healing mage heals the hero nearby")
	check(el.hp == 10.0, "summons aren't healed")
	el.crumble()
	# A walking unit nearby of this village gets healed too.
	var ar := game.army.recruit("archer")
	var s: Soldier = game.army._spawn_walker(ar, hm[1].outer_tile())
	s.set_grid_pos(hm[1].act_center() + Vector2(0.4, 0.4))
	s.set_process(false)  # (it just stands there)
	ar.state = MilitaryUnit.State.MARCHING  # (no reserve regen)
	ar.hp = 5.0
	var got := await wait_until(func() -> bool: return ar.hp > 5.0, 10.0)
	check(got, "it heals allied units out in the field")
	ar.state = MilitaryUnit.State.RESERVE
	s.queue_free()
	ar.walker = null
	hero.set_grid_pos(hero_home)
	game.army.unstation(hm[0])
	# Fire summoner: fire elementals hover, hit hard, burn themselves.
	await clear_enemies()
	var fs: Array = await _manned("fire_summoner")
	var foe := spawn_dummy("ork", _near_tower(fs[1], 2.5), 50.0)
	var beh: SummonerBehavior = fs[0].behavior
	var summoned := await wait_until(func() -> bool: return not beh.summons.is_empty(), 20.0)
	check(summoned and beh.summons[0].summon == "fire", "the fire summoner summons fire elementals")
	if summoned:
		var fe: EarthElemental = beh.summons[0]
		var expected := Config.unit_stat("fire_summoner", "summon_hp", 0) * Config.SUMMONS["fire"]["hp"]
		check(is_equal_approx(fe.max_hp, expected), "less HP (%.0f), more damage (%.1f)" % [fe.max_hp, fe.damage])
		var full := fe.max_hp
		var burned := await wait_until(func() -> bool: return not is_instance_valid(fe) or fe.dead or fe.hp < full, 20.0)
		check(burned, "hitting burns the fire elemental itself")
	foe.take_damage(1e9)
	game.army.unstation(fs[0])
	await clear_enemies()
	# A summoner in the barracks steps outside and summons there; it can be hit.
	var su := game.army.recruit("summoner")
	for u in barracks.units():
		game.army.unstation(u)
	await frames(2)
	check(game.army.station(su, barracks), "a summoner can sit in the barracks")
	await wait_until(func() -> bool: return barracks.slots[0] == su, 60.0)
	var sfoe := spawn_dummy("goblin", Vector2(game.world.pathing.nearest_walkable(Vector2i((barracks.act_center() + Vector2(2.5, 0)).round()))), 50.0)
	var sbeh: SummonerBehavior = su.behavior
	var summoned_out := await wait_until(func() -> bool: return su.out and not sbeh.summons.is_empty(), 30.0)
	check(summoned_out, "an enemy near: it goes out and summons")
	check(is_instance_valid(su.walker) and su.walker.is_in_group("melee_defenders") and not su.has_stat("damage"), "out there enemies can attack it; it has no attack of its own")
	# A witch goes for it too, though it never attacks her (no manned tower near).
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	var witch := spawn_dummy("witch", su.walker.grid_pos + Vector2(2.0, 0.5), 50.0)
	var wb: WitchBehavior = witch.behavior
	var aimed := await wait_until(func() -> bool: return is_instance_valid(su.walker) and wb.target == su.walker, 10.0)
	check(aimed, "a witch casts at a summoner out of its barracks, though it never attacks her")
	witch.take_damage(1e9)
	sfoe.take_damage(1e9)
	var home := await wait_until(func() -> bool: return not su.out, 60.0)
	check(home and sbeh.summons.is_empty(), "back on its bench, its summons are dismissed")


# --- specialising, the upgrade dialog, the Spatial Archmage --------------------------------

func _test_branching() -> void:
	var hud := game.hud
	game.economy.add("gold", 3000)
	var ap := game.army.recruit("apprentice")
	check(ap.upgrade_options().size() == 1, "a level 1 apprentice can only level up")
	ap.level = Config.BRANCH_MIN_LEVEL - 1
	var kinds: Array = ap.upgrade_options().map(func(o: Dictionary) -> String: return o["to"])
	check(kinds == ["apprentice", "fire_mage", "ice_mage", "healing_mage", "spatial_mage"], "from level %d: level up or one of four mages" % Config.BRANCH_MIN_LEVEL)
	hud.open_upgrade(ap)
	await frames(2)
	check(hud._upgrade_panel.visible and hud._upgrade_options.get_child_count() >= 5, "the upgrade dialog lists every option")
	check(on_screen(hud._upgrade_panel), "the dialog fits on screen (%s)" % hud._upgrade_panel.get_global_rect())
	var ice_btn: Button = null
	for n in hud._upgrade_options.find_children("*", "Button", true, false):
		if "Ice Mage" in Hud.button_text(n as Button):
			ice_btn = n
	check(ice_btn != null, "with the ice mage among them")
	if ice_btn:
		await tap(ice_btn)
		await frames(2)
	check(ap.kind == "ice_mage" and ap.level == 0 and not hud._upgrade_panel.visible, "picking it makes an ice mage, level 1")
	# Training at the grounds only levels up (no specialising): train() keeps the kind.
	var sp := game.army.recruit("apprentice")
	sp.level = Config.BRANCH_MIN_LEVEL - 1
	game.army.upgrade(sp, "spatial_mage")
	sp.level = Config.ARCHMAGE_LEVEL - 1
	check(sp.upgrade_options().any(func(o: Dictionary) -> bool: return o["archmage"]), "a level %d spatial mage can become the Spatial Archmage" % Config.ARCHMAGE_LEVEL)
	# Needs a free hut.
	while game.population.free_huts().size() > 0 and game.population.recruit("farmer") != null:
		pass
	var no_hut := game.army.archmage_error(sp)
	check(game.population.free_huts().is_empty() == (no_hut == "The Spatial Archmage needs a free hut"), "the Spatial Archmage needs a free hut")
	if game.population.free_huts().is_empty():
		game.population.kill_random(1)
		await frames(2)
	game.economy.add("gold", 1000)
	hud.open_upgrade(sp)
	await frames(2)
	var arch_btn: Button = null
	for n in hud._upgrade_options.find_children("*", "Button", true, false):
		if "Archmage" in Hud.button_text(n as Button):
			arch_btn = n
	check(arch_btn != null, "the dialog offers the Spatial Archmage")
	if arch_btn:
		await tap(arch_btn)
		await frames(2)
	check(hud._confirm_panel.visible and "600" in Hud.button_text(hud._confirm_yes), "it asks for confirmation first (600 gold)")
	var g0 := game.economy.amount("gold")
	check(on_screen(hud._confirm_panel), "the confirmation fits on screen")
	await tap(hud._confirm_yes)
	await frames(3)
	check(not game.army.units.has(sp) and game.population.count("spatial_archmage") == 1, "confirmed: the mage leaves the army, the Spatial Archmage moves into a hut")
	check(g0 - game.economy.amount("gold") == Config.ARCHMAGE_COST["gold"], "for 600 gold")
