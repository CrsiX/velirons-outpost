extends "res://tests/bot_base.gd"
## Headless test of the military expansion (docs/military-design.md): the
## config's tech tree and curves, barracks (benches, sorties, upgrades),
## unit HP, downing and reviving, healing, every attack effect, fire
## elementals, specialising and the Spatial Archmage, and the acolyte line
## (holy damage, the Inquisitor's hunt, the High Priest's aura; docs/acolyte-design.md),
## and the shield bearer's branches (the warrior's war cry, the berserker's
## rage and lifesteal, the halberdier against flyers; §3a). Run with:
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
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true  # (this test predates unit unlocks: tests/world_bot.gd)
	await frames(3)
	game.fog.reveal_all()  # (the whole map known, as the Debug page's Reveal does)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	# (Fed for good: a starving village's units are slower (HUNGER_PENALTY), and
	# how soon its food runs out depends on how long the checks take.)
	game.economy.add("food", 100000)
	far = game.map.edge_spawns[0]
	Engine.time_scale = 4.0
	await _test_barracks()
	await _test_downing()
	await _test_effects()
	await _test_branching()
	await _test_holy()
	await _test_shield_branches()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- config ------------------------------------------------------------------------------

func _dps(kind: String, lv: int) -> float:
	return Config.unit_stat(kind, "damage", lv) / Config.unit_stat(kind, "cooldown", lv)


## Elementals' damage per blow, all of them together: max_summons x
## summon_damage x the summon kind's damage factor.
func _summon_output(kind: String, lv: int) -> float:
	var f: float = Config.SUMMONS[Config.MILITARY[kind].get("summon", "earth")]["damage"]
	return roundi(Config.unit_stat(kind, "max_summons", lv)) * Config.unit_stat(kind, "summon_damage", lv) * f


## The specialisation rules (docs/military-design.md §3), as the list of what
## breaks them:
## - specialising never costs strength: level 1 at least as strong as the base
##   unit's level 3 (where it branches): HP; DPS if it attacks (ranged, melee);
##   summoners as many and as strong summons, no longer interval;
## - the ceiling is higher: level 10 stronger than the base unit's level 10:
##   more HP; more DPS if it attacks; summoners more summon output.
## The healing mage and the High Priest have no real attack: only HP counts.
func _spec_rule_breaks() -> Array[String]:
	var out: Array[String] = []
	var b3 := Config.BRANCH_MIN_LEVEL - 1
	var top := Config.MAX_UNIT_LEVEL - 1
	for k in Config.MILITARY:
		var sp: Dictionary = Config.MILITARY[k]
		if not sp.has("branch_of"):
			continue
		var b: String = sp["branch_of"]
		var attacks: bool = sp["role"] in ["ranged", "melee"]
		if Config.unit_stat(k, "hp", 0) < Config.unit_stat(b, "hp", b3) - 0.001:
			out.append("%s L1 HP" % k)
		if attacks and _dps(k, 0) < _dps(b, b3) - 0.001:
			out.append("%s L1 DPS" % k)
		if sp["stats"].has("interval"):
			for key in ["summon_hp", "summon_damage"]:
				if Config.unit_stat(k, key, 0) < Config.unit_stat(b, key, b3) - 0.001:
					out.append("%s L1 %s" % [k, key])
			if roundi(Config.unit_stat(k, "max_summons", 0)) < roundi(Config.unit_stat(b, "max_summons", b3)):
				out.append("%s L1 max_summons" % k)
			if Config.unit_stat(k, "interval", 0) > Config.unit_stat(b, "interval", b3) + 0.001:
				out.append("%s L1 interval" % k)
		if Config.unit_stat(k, "hp", top) <= Config.unit_stat(b, "hp", top):
			out.append("%s L10 HP" % k)
		if attacks and _dps(k, top) <= _dps(b, top):
			out.append("%s L10 DPS" % k)
		if sp["stats"].has("interval") and _summon_output(k, top) <= _summon_output(b, top):
			out.append("%s L10 summon output" % k)
	return out


## An idle elemental (every kind) heals its SUMMONS "regen" share of its max
## HP per second, SUMMON.regen_delay after it was last hurt.
func _test_elemental_regen() -> void:
	var t := find_spot("lightstone", game.player_village.center + Vector2i(0, 9))
	var els: Array[EarthElemental] = []
	for kind: String in Config.SUMMONS:
		var el: EarthElemental = SummonerBehavior.ELEMENTAL_SCRIPT.new()
		el.setup(game, t, t, 100.0, 1.0, kind)
		el.village = game.player_village
		game.world.objects.add_child(el)
		el.take_damage(50.0)
		els.append(el)
	await wait(1.0)
	var waited := els.all(func(el: EarthElemental) -> bool: return el.hp == 50.0)
	await wait(Config.SUMMON["regen_delay"] + 1.0)
	var ok := true
	for el in els:
		var rate: float = Config.SUMMONS[el.summon]["regen"]
		ok = ok and rate > 0.0 and el.hp > 50.0 and el.hp <= 50.0 + 100.0 * rate * 3.0
		el.crumble()
	check(waited and ok, "idle elementals (earth, fire, thornling) heal by their regen, %s s after they were hurt" % Config.SUMMON["regen_delay"])


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
		tree_ok = tree_ok and Config.MILITARY_TREE.has(k) and behaviors_have(sp["role"])
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
	var pinned := Config.MILITARY.values().filter(func(sp: Dictionary) -> bool: return sp.has("pinned") or sp.has("upgrade_cost_pinned") or sp.has("train_xp_pinned"))
	check(pinned.is_empty() and is_equal_approx(Config.unit_stat("archer", "damage", 3), 7.0 + 33.0 / 3.0), "every unit runs on its curves only (no pinned levels)")
	check(Config.unit_stat("swiftbowman", "cooldown", 0) * 2.0 <= Config.unit_stat("archer", "cooldown", 2), "swiftbowman: at least twice the fire rate")
	var breaks := _spec_rule_breaks()
	check(breaks.is_empty(), "every specialisation: level 1 at least as strong as its base unit's level 3, level 10 stronger than its level 10 %s" % str(breaks))
	check(Config.unit_stat("crossbowman", "cooldown", 0) > 2.0 * Config.unit_stat("archer", "cooldown", 2) and Config.MILITARY["crossbowman"]["range"] > Config.MILITARY["archer"]["range"], "crossbowman: much slower fire, more range")
	check(Config.unit_stat("shield_bearer", "hp", 0) >= 0.8 * Config.ENEMIES["ork"]["hp"] and Config.unit_stat("shield_bearer", "hp", 0) > 1.5 * Config.unit_stat("archer", "hp", 0) and Config.MILITARY["shield_bearer"]["posts"] == ["barracks"], "shield bearer: ork-like HP, barracks only")
	check(Config.unit_stat("apprentice", "hp", 0) < Config.unit_stat("archer", "hp", 0), "HP: apprentice < archer")
	check(Config.unit_stat("ice_mage", "slow", 9) < Config.unit_stat("ice_mage", "slow", 0), "the ice mage's slow grows with its level")
	var top := 0
	for k in Config.MILITARY:
		for lv in Config.MAX_UNIT_LEVEL - 1:
			top = maxi(top, int(Config.unit_upgrade_cost(k, lv).get("gold", 0)))
	check(top <= 300 and Config.unit_upgrade_cost("archer", Config.MAX_UNIT_LEVEL - 1).is_empty(), "upgrades cost at most 300 gold; none past level 10")
	check(Config.unit_revive_time(9) > Config.unit_revive_time(0), "revive time grows with the level (%.0f to %.0f s)" % [Config.unit_revive_time(0), Config.unit_revive_time(9)])
	check(Config.BARRACKS_LEVELS.map(func(l: Dictionary) -> int: return l["slots"]) == [1, 2, 3], "barracks: 1 / 2 / 3 benches")


func behaviors_have(role: String) -> bool:
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
	if went:
		check(sb.walker.grid_pos.distance_to(barracks.bench_point(sb)) < 0.3 and sb.walker.mode in [Soldier.Mode.LEAVE, Soldier.Mode.SORTIE], "it steps down from its bench (%s, bench %s)" % [sb.walker.grid_pos, barracks.bench_point(sb)])
	var killed := await wait_until(func() -> bool: return foe.dead, 60.0)
	check(killed, "they kill it (hp %.0f, sb %s at %s, ar %s, foe at %s)" % [foe.hp, sb.state_text(), sb.walker.grid_pos if is_instance_valid(sb.walker) else Vector2.ZERO, ar.state_text(), foe.grid_pos])
	var seat := {}
	var back := await wait_until(func() -> bool:
		if is_instance_valid(sb.walker) and sb.walker.mode == Soldier.Mode.SEAT:
			seat["seen"] = true
			seat["last"] = sb.walker.grid_pos
		return not sb.out and not ar.out, 60.0)
	check(back and sb.state == MilitaryUnit.State.STATIONED and barracks._bench_sprites[0].visible, "no enemy left: they walk back to their benches")
	check(seat.get("seen", false) and Vector2(seat["last"]).distance_to(barracks.bench_point(sb)) < 0.2, "up onto the bench itself before it sits there (%s)" % str(seat))
	# Swapping posts (one unit dragged onto another): only when each fits the other's post.
	var tw_ar: MilitaryUnit = tower.garrison
	if tw_ar == null:
		tw_ar = game.army.recruit("archer")
		game.army.station(tw_ar, tower)
		await wait_until(func() -> bool: return tower.garrison == tw_ar, 60.0)
	check(game.army.swap_error(sb, tw_ar) == "A shield bearer can't serve on towers", "a shield bearer in barracks and an archer on a tower can't swap")
	check(game.army.swap_error(ar, sb) == "They're on the same post" and not game.command("swap_units", {"unit": sb.nid, "other": tw_ar.nid})["ok"], "nor can two units on the same post, and the command refuses what doesn't fit")
	ar.out = true
	check(game.army.swap_error(tw_ar, ar) == "It's out fighting: wait until it's back on its bench", "a unit out on a sortie can't swap")
	ar.out = false
	check(game.command("swap_units", {"unit": tw_ar.nid, "other": ar.nid})["ok"], "an archer on a tower and one in the barracks swap posts")
	check(tw_ar.state == MilitaryUnit.State.MARCHING and ar.state == MilitaryUnit.State.MARCHING and tower.garrison == null and barracks.slots[1] == null, "both leave their posts at once")
	check(tower.incoming == ar and barracks.incoming_slots[1] == tw_ar and tw_ar.slot == 1 and ar.slot == 0, "each heads for the other's slot")
	var swapped := await wait_until(func() -> bool: return tower.garrison == ar and barracks.slots[1] == tw_ar, 60.0)
	check(swapped and ar.state == MilitaryUnit.State.STATIONED and tw_ar.state == MilitaryUnit.State.STATIONED and barracks.slots[0] == sb, "they take up each other's posts")
	check(game.army.swap(ar, tw_ar), "and swap back")
	await wait_until(func() -> bool: return tower.garrison == tw_ar and barracks.slots[1] == ar, 60.0)
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
	await frames(2)
	check(barracks._bars_shown, "a hurt unit on its bench shows its HP bar")
	sb.hp = sb.max_hp()
	await frames(3)
	check(not barracks._bars_shown, "healed: the bar is gone")
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
	# (By its distance from the walls: by the gate it lays siege, and then remaining() counts that, not road steps.)
	var walls := game.player_village.rect
	var away0 := Hero.rect_distance(walls, w.grid_pos)
	var pushed := await wait_until(func() -> bool: return Hero.rect_distance(walls, w.grid_pos) > away0 + 0.5, 10.0)
	check(pushed and best_d < sm[1].act_range(), "warp orbs throw the enemy back along its road, away from the village (%.1f -> %.1f tiles from the walls)" % [away0, Hero.rect_distance(walls, w.grid_pos)])
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
	el._busy_left = 1e9  # (no regen of its own meanwhile)
	var h0 := hero.hp
	var healed := await wait_until(func() -> bool: return hero.hp > h0, 10.0)
	check(healed, "the healing mage heals the hero nearby")
	check(el.hp == 10.0, "summons aren't healed")
	el.crumble()
	await _test_elemental_regen()
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
		var burned := await wait_until(when_gone(fe, func(x: Object) -> bool: return x.dead or x.hp < full), 20.0)
		check(burned, "hitting burns the fire elemental itself")
	foe.take_damage(1e9)
	game.army.unstation(fs[0])
	await clear_enemies()
	# Druid: thornlings, slow and tough; every blow roots (docs/military-design.md §3b).
	var dr: Array = await _manned("druid")
	var dbeh: SummonerBehavior = dr[0].behavior
	var dfoe := spawn_dummy("ork", _near_tower(dr[1], 2.5), 50.0)
	var grown := await wait_until(func() -> bool: return not dbeh.summons.is_empty(), 20.0)
	check(grown and dbeh.summons[0].summon == "thorn" and dbeh.summons[0].label().begins_with("thornling"), "the druid calls up thornlings")
	if grown:
		var th: EarthElemental = dbeh.summons[0]
		check(is_equal_approx(th.max_hp, Config.unit_stat("druid", "summon_hp", 0) * Config.SUMMONS["thorn"]["hp"]) and is_equal_approx(th.root_time, Config.unit_stat("druid", "root", 0)), "more HP (%.0f), roots for %.1f s" % [th.max_hp, th.root_time])
		check(th.speed < Config.SUMMONS["earth"]["speed"], "slower than an earth elemental")
		check(await wait_until(func() -> bool: return dfoe.is_rooted(), 20.0), "its blow roots the enemy")
	dfoe.take_damage(1e9)
	game.army.unstation(dr[0])
	await clear_enemies()
	var walker := game.waves.spawn_at("goblin", game.map.edge_spawns[0], game.player_village, 1)
	walker.max_hp = 1e9  # (nothing near may kill it meanwhile)
	walker.hp = walker.max_hp
	await wait(0.5)
	check(walker.root(1.0) and walker.is_rooted(), "rooted")
	var at := walker.grid_pos
	await wait(0.7)
	check(walker.grid_pos.distance_to(at) < 0.01, "a rooted enemy doesn't walk")
	check(not walker.root(1.0), "no root on top of a root")
	await wait(0.6)
	check(not walker.is_rooted() and walker.grid_pos.distance_to(at) > 0.05, "the roots let go: it walks on")
	check(not walker.root(1.0), "then it is immune for a while")
	await wait(float(Config.SUMMONS["thorn"]["root_immunity"]) + 0.2)
	check(walker.root(0.5), "and can be rooted again after it")
	var gar := game.waves.spawn_at("gargoyle", game.map.edge_spawns[0], game.player_village, 1)
	check(not gar.root(1.0), "flyers can't be rooted")
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
	# Too poor while it's open: greyed out; gold earned meanwhile turns it on (also the trade dialog's buttons).
	var gold_had := game.economy.amount("gold")
	var ice_cost := int(ap.upgrade_options().filter(func(o: Dictionary) -> bool: return o["to"] == "ice_mage")[0]["cost"]["gold"])
	game.economy.spend({"gold": gold_had - (ice_cost - 1)})
	await frames(2)
	var poor := ice_btn != null and ice_btn.disabled
	game.economy.add("gold", 1, "kills")
	await frames(2)
	check(poor and ice_btn != null and not ice_btn.disabled and hud._upgrade_panel.visible, "too little gold: the option is greyed out; gold earned while the dialog is open turns it on")
	var five: int = Config.MATERIALS_TRADE["gold"] * 5
	game.economy.spend({"gold": game.economy.amount("gold") - (five - 1)})
	await frames(2)
	var trade_off := not hud._trade_buttons[0].disabled and hud._trade_buttons[1].disabled
	game.economy.add("gold", 1, "kills")
	await frames(2)
	check(trade_off and not hud._trade_buttons[1].disabled, "the trade dialog's buttons follow the gold too")
	game.economy.add("gold", gold_had - game.economy.amount("gold"))
	await frames(2)  # (the dialog's buttons follow the gold back)
	if ice_btn:
		await tap(ice_btn)
		await frames(2)
	check(ap.kind == "ice_mage" and ap.level == 0 and not hud._upgrade_panel.visible, "picking it makes an ice mage, level 1")
	# Training progress takes its share off the next level's gold, 1:1; specialising stays full price.
	var tr := game.army.recruit("archer")
	tr.level = Config.BRANCH_MIN_LEVEL - 1
	var full := int(Config.unit_upgrade_cost("archer", tr.level)["gold"])
	tr.train_xp = tr.train_xp_needed() * 0.6
	var part := int(tr.upgrade_cost()["gold"])
	var branch_full: bool = tr.upgrade_options().filter(func(o: Dictionary) -> bool: return o["to"] == "crossbowman")[0]["cost"] == Config.MILITARY["crossbowman"]["branch_cost"]
	check(part == roundi(full * 0.4) and branch_full, "60 %% trained leaves 40 %% of the level's gold (%d of %d); a specialisation costs its full price" % [part, full])
	game.economy.add("gold", 1000)
	var gold_before := game.economy.amount("gold")
	game.army.upgrade(tr)
	check(gold_before - game.economy.amount("gold") == part and tr.train_xp == 0.0 and tr.upgrade_cost()["gold"] == Config.unit_upgrade_cost("archer", tr.level)["gold"], "the upgrade charges the rest and resets the training")
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
	var gold_kept := game.economy.amount("gold")
	game.economy.spend({"gold": gold_kept - (Config.ARCHMAGE_COST["gold"] - 1)})
	await frames(2)
	var no_gold := hud._confirm_yes.disabled
	game.economy.add("gold", gold_kept - game.economy.amount("gold"))
	await frames(2)
	check(no_gold and not hud._confirm_yes.disabled, "short of gold its OK is greyed out, and turns on once the gold is there")
	var g0 := game.economy.amount("gold")
	check(on_screen(hud._confirm_panel), "the confirmation fits on screen")
	await tap(hud._confirm_yes)
	await frames(3)
	check(not game.army.units.has(sp) and game.population.count("spatial_archmage") == 1, "confirmed: the mage leaves the army, the Spatial Archmage moves into a hut")
	check(g0 - game.economy.amount("gold") == Config.ARCHMAGE_COST["gold"], "for 600 gold")


# --- the acolyte line: holy damage, the Inquisitor, the High Priest ---------------------------

func _test_holy() -> void:
	await clear_enemies()
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	for u in barracks.units():
		game.army.unstation(u)
	await frames(2)
	# Config: the factors and flags of docs/acolyte-design.md, the chapel.
	var want := {"goblin": 0.75, "skeleton": 1.25, "ork": 0.75, "witch": 1.0, "rat": 1.0, "thief": 0.75, "gargoyle": 0.75, "necromancer": 1.5, "vampire": 1.5}
	var factors_ok := true
	for k in want:
		factors_ok = factors_ok and is_equal_approx(float(Config.ENEMIES[k].get("resist", {}).get("holy", 1.0)), want[k])
	check(factors_ok, "holy factors per enemy kind as designed")
	check(Config.ENEMIES.keys().filter(func(k: String) -> bool: return Config.ENEMIES[k].get("unholy", false)) == ["skeleton", "necromancer", "vampire"], "skeletons, necromancers and vampires are unholy")
	check(Config.LOCKED.get("acolyte", "") == "chapel" and Config.UNLOCK_SITES["chapel"]["wave"] == 6 and Config.UNLOCK_SITES["chapel"]["distance"].map(func(v) -> int: return int(v)) == [16, 24], "the acolyte is unlocked at the ruined chapel, from wave 6, 16-24 tiles out")
	check(Config.MILITARY["acolyte"]["cost"] == {"gold": 50} and Config.MILITARY["acolyte"]["range"] < Config.MILITARY["archer"]["range"], "acolyte: 50 gold, shorter field range than the archer")
	check(absf(Config.unit_stat("acolyte", "hp", 0) - Config.unit_stat("archer", "hp", 0)) < 0.01 and _dps("acolyte", 9) <= _dps("archer", 9) and _dps("acolyte", 9) > 0.7 * _dps("archer", 9), "acolyte: archer HP, a little less DPS")
	check(Config.MILITARY["inquisitor"]["posts"] == ["barracks"], "the inquisitor never goes on towers")
	# Damage taken.
	var gob := spawn_dummy("goblin", Vector2(far), 50.0)
	var h0 := gob.hp
	gob.take_damage(10.0, null, "holy")
	check(is_equal_approx(h0 - gob.hp, 7.5), "a goblin takes x0.75 holy damage")
	var sk := spawn_dummy("skeleton", Vector2(far), 50.0)
	h0 = sk.hp
	sk.take_damage(10.0, null, "holy")
	check(is_equal_approx(h0 - sk.hp, 12.5), "a skeleton takes x1.25")
	sk.raised = true
	h0 = sk.hp
	sk.take_damage(10.0, null, "holy")
	check(is_equal_approx(h0 - sk.hp, 25.0), "raised by a necromancer: twice that again")
	h0 = sk.hp
	sk.take_damage(10.0, null, "melee")
	check(is_equal_approx(h0 - sk.hp, 10.0), "other damage isn't changed")
	await clear_enemies()
	# The acolyte: a beam from above, holy damage.
	var ac: Array = await _manned("acolyte")
	var tw: Tower = ac[1]
	var foe := spawn_dummy("skeleton", _near_tower(tw, 1.5), 50.0)
	var fh := foe.hp
	var beamed := await wait_until(func() -> bool: return game.world.effects.get_children().any(func(n: Node) -> bool: return n.get_script() == Combat.BURST_SCRIPT and n.kind == "holy_beam"), 15.0)
	check(beamed and foe.hp < fh, "an acolyte on a tower strikes with a beam of light from above")
	check(tw._unit_sprite.get_node_or_null("Glow") != null, "it glows on its tower")
	await clear_enemies()
	# Turning into an inquisitor on a tower: it walks back into the reserve.
	var acu: MilitaryUnit = ac[0]
	await wait_until(func() -> bool: return acu.state == MilitaryUnit.State.STATIONED, 60.0)
	acu.level = Config.BRANCH_MIN_LEVEL - 1
	game.economy.add("gold", 500)
	check(game.army.upgrade(acu, "inquisitor"), "an acolyte on a tower can still become an inquisitor")
	check(tw.garrison == null and tw._unit_sprite.get_node_or_null("Glow") == null, "it leaves the tower at once")
	check(await wait_until(func() -> bool: return acu.state == MilitaryUnit.State.RESERVE, 90.0), "and walks back into the reserve")
	# The hunt: witches, then the unholy, then the rest, by effective distance.
	var hunt: Dictionary = Config.MILITARY["inquisitor"]["hunt"]
	var w := spawn_dummy("witch", Vector2(far), 50.0)
	var s2 := spawn_dummy("skeleton", Vector2(far), 50.0)
	var g2 := spawn_dummy("goblin", Vector2(far), 50.0)
	check(Soldier._hunt_distance(w, 6.0, hunt) < Soldier._hunt_distance(g2, 2.5, hunt), "a witch 6 tiles away beats a goblin 2.5 tiles away")
	check(Soldier._hunt_distance(s2, 3.0, hunt) < Soldier._hunt_distance(g2, 1.5, hunt), "a skeleton 3 tiles away beats a goblin 1.5 tiles away")
	check(is_equal_approx(Soldier._hunt_distance(w, 8.0, hunt), 8.0) and is_equal_approx(Soldier._hunt_distance(s2, 5.5, hunt), 5.5), "beyond their caps they count like anyone")
	await clear_enemies()
	# In the barracks it goes for the witch first.
	game.army.station(acu, barracks)
	await wait_until(func() -> bool: return barracks.slots[0] == acu, 60.0)
	var bc := barracks.act_center()
	var near_gob := spawn_dummy("goblin", Vector2(game.world.pathing.nearest_walkable(Vector2i((bc + Vector2(1.5, 0)).round()))), 200.0)
	var far_witch := spawn_dummy("witch", Vector2(game.world.pathing.nearest_walkable(Vector2i((bc + Vector2(-3.5, 0)).round()))), 200.0)
	var went := await wait_until(func() -> bool: return acu.out and is_instance_valid(acu.walker) and acu.walker.target == far_witch, 20.0)
	check(went, "out on a sortie the inquisitor goes for the witch, not the nearer goblin")
	near_gob.take_damage(1e9)
	far_witch.take_damage(1e9)
	await wait_until(func() -> bool: return not acu.out, 60.0)
	game.army.unstation(acu)
	await clear_enemies()
	# An acolyte out of the barracks becomes an inquisitor: the one out there looks (and walks) like one.
	game.economy.add("gold", 500)
	var ac2 := game.army.recruit("acolyte")
	ac2.level = Config.BRANCH_MIN_LEVEL - 1
	game.army.station(ac2, barracks)
	await wait_until(func() -> bool: return ac2.state == MilitaryUnit.State.STATIONED, 60.0)
	var bait := spawn_dummy("goblin", Vector2(game.world.pathing.nearest_walkable(Vector2i((bc + Vector2(1.5, 0)).round()))), 200.0)
	var ac2_out := await wait_until(func() -> bool: return ac2.out and is_instance_valid(ac2.walker), 20.0)
	var body := ac2.walker as Soldier
	var glowed := ac2_out and body.sprite.get_node_or_null("Glow") != null
	check(ac2_out and game.army.upgrade(ac2, "inquisitor") and ac2.walker == body, "an acolyte out on a sortie becomes an inquisitor")
	check(glowed and body.sprite.get_meta("unit_kind", "") == "inquisitor" and body.sprite.get_node_or_null("Glow") == null and is_equal_approx(body.speed, Config.MILITARY["inquisitor"]["speed"]),
		"the one out there turns into an inquisitor at once: its look (no acolyte glow) and its speed")
	bait.take_damage(1e9)
	await wait_until(func() -> bool: return not ac2.out, 60.0)
	game.army.unstation(ac2)
	await clear_enemies()
	# The High Priest's aura.
	var hp1: Array = await _manned("high_priest")
	var pt: Tower = hp1[1]
	var pu: MilitaryUnit = hp1[0]
	await wait_until(func() -> bool: return pu.state == MilitaryUnit.State.STATIONED, 60.0)
	await frames(2)
	var edge := pt.act_center() + Vector2(pt.act_range() - 0.1, 0.0)
	var out := pt.act_center() + Vector2(pt.act_range() + 0.3, 0.0)
	check(is_equal_approx(Combat.holy_bonus(game, edge), Config.unit_stat("high_priest", "aura", 0)) and Combat.holy_bonus(game, out) == 0.0, "a High Priest on a tower: +%d %% damage as far as the tower reaches" % roundi(Config.unit_stat("high_priest", "aura", 0) * 100))
	check(is_equal_approx(Combat.necro_slow(game, edge), 2.0) and Combat.necro_slow(game, out) == 1.0, "necromancers in it raise twice as slowly")
	pu.level = Config.MAX_UNIT_LEVEL - 1
	await frames(1)
	check(is_equal_approx(Combat.holy_bonus(game, edge), 0.2), "+20 %% at level 10")
	# A second, weaker priest next to it: the stronger aura counts, they don't stack.
	var t2: Tower = await build("tower", pt.tile + Vector2i(1, 1))
	game.economy.add("gold", 2000)
	var pu2 := game.army.recruit("acolyte")
	pu2.level = Config.BRANCH_MIN_LEVEL - 1
	game.army.upgrade(pu2, "high_priest")
	game.army.station(pu2, t2)
	await wait_until(func() -> bool: return pu2.state == MilitaryUnit.State.STATIONED, 60.0)
	await frames(1)
	check(is_equal_approx(Combat.holy_bonus(game, pt.act_center()), 0.2), "two auras don't stack: the strongest counts")
	# Who it boosts: tower units' attacks, the hero (with a halo), summons.
	var dummy := spawn_dummy("goblin", Vector2(far), 200.0)
	var probe := game.army.recruit("acolyte")
	h0 = dummy.hp
	Combat.attack(game, probe, Vector2.ZERO, dummy, pt)
	var boosted := h0 - dummy.hp
	h0 = dummy.hp
	Combat.attack(game, probe, Vector2.ZERO, dummy, null)
	var plain := h0 - dummy.hp
	check(is_equal_approx(boosted, plain * 1.2), "attacks from inside it deal +20 %% (%.2f vs %.2f)" % [boosted, plain])
	var hero := game.hero
	var hero_home := hero.grid_pos
	hero.set_grid_pos(pt.act_center() + Vector2(0.5, 0.5))
	var halo := hero.sprite.get_node("Halo") as CanvasItem
	check(await wait_until(func() -> bool: return halo.visible, 2.0), "the hero inside shows a little halo")
	hero.set_grid_pos(Vector2(far))
	check(await wait_until(func() -> bool: return not halo.visible, 2.0), "outside it's gone")
	hero.set_grid_pos(hero_home)
	var el: EarthElemental = SummonerBehavior.ELEMENTAL_SCRIPT.new()
	el.setup(game, pt.outer_tile(), pt.outer_tile(), 50.0, 4.0)
	el.village = game.player_village
	game.world.objects.add_child(el)
	el.set_process(false)
	el.set_grid_pos(pt.act_center() + Vector2(0.3, 0.3))
	await frames(1)
	check(Combat.holy_bonus(game, el.grid_pos) > 0.0, "summons inside are boosted too")
	el.crumble()
	await clear_enemies()
	game.army.unstation(pu)
	game.army.unstation(pu2)
	await frames(2)
	# From the barracks only while out on a sortie, and it strikes back in melee.
	await wait_until(func() -> bool: return pu.state == MilitaryUnit.State.RESERVE, 90.0)
	check(game.army.station(pu, barracks), "a High Priest can sit in the barracks (%s)" % game.army.station_error(pu, barracks))
	await wait_until(func() -> bool: return barracks.slots[0] == pu, 60.0)
	await frames(1)
	var reach := pu.field_range()
	check(is_equal_approx(Combat.holy_bonus(game, barracks.act_center()), 0.2) and Combat.holy_bonus(game, barracks.act_center() + Vector2(reach + 0.3, 0.0)) == 0.0, "on its bench its aura works too, within its own %.1f tiles" % reach)
	# Units downed on a bench in it come back faster (x3 at level 10).
	var x := Config.unit_stat("high_priest", "revive", pu.level)
	check(is_equal_approx(x, 3.0) and is_equal_approx(Config.unit_stat("high_priest", "revive", 0), 1.25), "revive speed-up: x1.25 at level 1, x3 at level 10")
	check(is_equal_approx(Combat.revive_rate(game, barracks), x), "its own barracks is in it")
	check(is_equal_approx(barracks.yard_distance(barracks.act_center()), 0.0) and is_equal_approx(barracks.yard_distance(Vector2(barracks.tile) + Vector2(-1.5, 0.5)), 1.0), "a barracks counts by the nearest point of its yard")
	var mate: MilitaryUnit = barracks.slots[1] if barracks.slots.size() > 1 else null
	if mate == null:
		mate = game.army.recruit("shield_bearer")
		game.army.station(mate, barracks)
		await wait_until(func() -> bool: return barracks.slots[1] == mate and mate.state == MilitaryUnit.State.STATIONED, 60.0)
	game.army.down(mate)
	var rl0 := mate.revive_left
	await wait(1.0)
	var sped := rl0 - mate.revive_left
	check(mate.is_downed() and sped > 2.5 and sped < 3.5, "a unit downed on a bench in it counts down %.1f s per second" % sped)
	await frames(2)
	check(barracks._bars_shown, "the downed unit shows its clock on the bench")
	game.army.revive(mate)
	await frames(2)
	var bg := spawn_dummy("goblin", Vector2(game.world.pathing.nearest_walkable(Vector2i((bc + Vector2(2.0, 0)).round()))), 200.0)
	var sortie := await wait_until(func() -> bool: return pu.out and is_instance_valid(pu.walker), 20.0)
	await frames(1)
	check(sortie and Combat.holy_bonus(game, pu.walker.grid_pos) > 0.0, "out on a sortie it is (its own %.1f tiles)" % Config.MILITARY["high_priest"]["range"])
	if sortie:
		var bh := bg.hp
		pu.walker._strike_cd = 0.0
		pu.walker.take_damage(1.0, bg, "melee")
		check(bg.hp < bh, "hit in melee, it strikes back")
	bg.take_damage(1e9)
	await wait_until(func() -> bool: return not pu.out, 60.0)
	game.army.unstation(pu)
	await frames(2)
	check(Combat.revive_rate(game, barracks) == 1.0, "without a priest: the normal revive time")
	await clear_enemies()


# --- the shield bearer's branches: warrior, berserker, halberdier (§3a) -----------------------

## A barracks unit of `kind` (a shield bearer branch), on the barracks' first bench.
func _benched(kind: String) -> MilitaryUnit:
	for u in barracks.units():
		game.army.unstation(u)
	await frames(2)
	game.economy.add("gold", 2000)
	var u := game.army.recruit("shield_bearer")
	u.level = Config.BRANCH_MIN_LEVEL - 1
	check(game.army.upgrade(u, kind), "a level %d shield bearer becomes a %s" % [Config.BRANCH_MIN_LEVEL, kind])
	game.army.station(u, barracks)
	await wait_until(func() -> bool: return barracks.slots[0] == u and u.state == MilitaryUnit.State.STATIONED, 60.0)
	return u


func _test_shield_branches() -> void:
	await clear_enemies()
	# The config: three barracks-only branches, never weaker than a level 3 shield bearer.
	var sb_hp := Config.unit_stat("shield_bearer", "hp", Config.BRANCH_MIN_LEVEL - 1)
	var sb_dps := _dps("shield_bearer", Config.BRANCH_MIN_LEVEL - 1)
	check(Config.MILITARY["shield_bearer"]["branches"] == ["warrior", "berserker", "halberdier"], "the shield bearer branches into warrior, berserker and halberdier")
	var ok := true
	for k in ["warrior", "berserker", "halberdier"]:
		var sp: Dictionary = Config.MILITARY[k]
		ok = ok and sp["posts"] == ["barracks"] and sp["branch_cost"] == {"gold": 100} and sp["role"] == "melee"
		ok = ok and Config.unit_stat(k, "hp", 0) >= sb_hp and _dps(k, 0) >= sb_dps
	check(ok, "all three: barracks only, 100 gold, and level 1 at least as strong as a level %d shield bearer (%.0f HP, %.1f DPS)" % [Config.BRANCH_MIN_LEVEL, sb_hp, sb_dps])
	var top := Config.MAX_UNIT_LEVEL - 1
	check(absf(_dps("berserker", top) - _dps("archer", top)) < 1.5 and absf(_dps("halberdier", top) - _dps("archer", top)) < 1.5, "berserker and halberdier at level 10 deal an archer's DPS (%.0f / %.0f / %.0f)" % [_dps("berserker", top), _dps("halberdier", top), _dps("archer", top)])
	var ls5 := Config.unit_stat("berserker", "lifesteal", 4)
	check(is_equal_approx(ls5, 0.1 + 0.15 * pow(4.0 / 9.0, 1.5)) and is_equal_approx(Config.unit_stat("berserker", "lifesteal", top), 0.25), "the berserker's lifesteal follows its own curve (%.3f at level 5, 0.25 at 10)" % ls5)
	check(is_equal_approx(Config.unit_stat("berserker", "rage", 0), 0.3) and is_equal_approx(Config.unit_stat("berserker", "damage", 4), 8.0 + 63.0 * 4.0 / 9.0), "its other stats stay linear")

	# Haste: one per unit, refilled by an equal or stronger cry, never stacked.
	var probe := game.army.recruit("archer")
	var now := game.clock
	Combat._hasten(game, probe, 0.3, 3.0)
	check(is_equal_approx(Combat.haste(game, probe), 1.3) and is_equal_approx(probe.rate(game), 1.3), "a war cry of +30 %: its timers run 1.3x as fast")
	Combat._hasten(game, probe, 0.1, 10.0)
	check(is_equal_approx(probe.cry_bonus, 0.3) and is_equal_approx(probe.cry_until, now + 3.0), "a weaker cry meanwhile changes nothing")
	Combat._hasten(game, probe, 0.3, 5.0)
	check(is_equal_approx(probe.cry_bonus, 0.3) and is_equal_approx(probe.cry_until, now + 5.0), "an equal cry refills it (no stacking: still +30 %)")
	Combat._hasten(game, probe, 0.5, 1.0)
	check(is_equal_approx(probe.cry_bonus, 0.5) and is_equal_approx(probe.cry_until, now + 1.0), "a stronger one takes over")
	game.clock = now + 2.0
	check(is_equal_approx(Combat.haste(game, probe), 1.0), "and when it runs out the timers are back to normal")
	Combat._hasten(game, probe, 0.1, 3.0)
	check(is_equal_approx(probe.cry_bonus, 0.1), "then a weaker cry counts again")
	probe.cry_until = -1.0
	game.army.units.erase(probe)

	# Rage and lifesteal.
	game.economy.add("gold", 500)
	var bz := game.army.recruit("shield_bearer")
	bz.level = Config.BRANCH_MIN_LEVEL - 1
	game.army.upgrade(bz, "berserker")
	bz.level = top
	bz.hp = bz.max_hp()
	check(is_equal_approx(bz.rate(game), 1.0), "a berserker at full HP strikes at its normal pace")
	bz.hp = bz.max_hp() * 0.1
	var want := 1.0 / (1.0 - Config.unit_stat("berserker", "rage", top) * 0.9)
	check(is_equal_approx(bz.rate(game), want), "at 10 %% HP %.1fx as fast" % want)
	var dummy := spawn_dummy("goblin", Vector2(far), 200.0)
	bz.hp = bz.max_hp() * 0.4
	var hb := bz.hp
	var eh := dummy.hp
	Combat.attack(game, bz, Vector2.ZERO, dummy, null)
	var dealt := eh - dummy.hp
	check(dealt > 0.0 and is_equal_approx(bz.hp - hb, dealt * Config.unit_stat("berserker", "lifesteal", top)), "below half HP its blow heals it by 25 %% of the damage dealt (+%.1f HP)" % (bz.hp - hb))
	bz.hp = bz.max_hp() * 0.6
	hb = bz.hp
	Combat.attack(game, bz, Vector2.ZERO, dummy, null)
	check(is_equal_approx(bz.hp, hb), "above half HP no lifesteal")
	game.army.units.erase(bz)
	await clear_enemies()

	# The war cry's reach: a tower unit within 2.5 tiles, the hero, not beyond.
	var tw: Array = await _manned("archer")
	var tu: MilitaryUnit = tw[0]
	var tt: Tower = tw[1]
	var hero := game.hero
	var hero_home := hero.grid_pos
	var spot := tt.act_center() + Vector2(2.0, 0.0)
	hero.set_grid_pos(spot + Vector2(0.0, 0.5))
	var n := Combat.war_cry(game, spot, float(Config.MILITARY["warrior"]["cry_radius"]), 0.4, 4.0)
	check(n >= 2 and Combat.haste(game, tu) > 1.0 and Combat.haste(game, hero) > 1.0, "a war cry reaches the unit on a tower 2 tiles away and the hero (%d hasted)" % n)
	var mark := tt._unit_sprite.get_node("CryMark") as CanvasItem
	check(await wait_until(func() -> bool: return mark.visible, 1.0), "the tower's unit shows the war cry's chevrons")
	tu.cry_until = -1.0
	hero.cry_until = -1.0
	Combat.war_cry(game, tt.act_center() + Vector2(3.0, 0.0), float(Config.MILITARY["warrior"]["cry_radius"]), 0.4, 4.0)
	check(is_equal_approx(Combat.haste(game, tu), 1.0), "not from 3 tiles away")
	check(await wait_until(func() -> bool: return not mark.visible, 1.0), "the chevrons go when the haste is over")
	hero.set_grid_pos(hero_home)
	game.army.unstation(tu)

	# The warrior out on a sortie shouts at once; it hastes himself too.
	var wr: MilitaryUnit = await _benched("warrior")
	var bc := barracks.act_center()
	var foe := spawn_dummy("goblin", Vector2(game.world.pathing.nearest_walkable(Vector2i((bc + Vector2(2.0, 0)).round()))), 200.0)
	var cried := await wait_until(func() -> bool: return wr.out and Combat.haste(game, wr) > 1.0, 20.0)
	check(cried and is_equal_approx(Combat.haste(game, wr), 1.0 + wr.stat("cry")), "out on a sortie the warrior shouts at once: +%d %% attack speed, himself included" % roundi(wr.stat("cry") * 100.0))
	foe.take_damage(1e9)
	await wait_until(func() -> bool: return not wr.out, 60.0)

	# The halberdier: barracks with him turn out for a gargoyle, and he goes for it.
	var hb_unit: MilitaryUnit = await _benched("halberdier")
	check(is_equal_approx(hb_unit.field_range(), 1.2) and hb_unit.hits_flyers(), "the halberdier reaches 1.2 tiles, and up to flyers")
	var garg := spawn_dummy("gargoyle", Vector2(game.world.pathing.nearest_walkable(Vector2i((bc + Vector2(2.0, 0)).round()))), 200.0)
	check(garg.flies(), "(a flyer)")
	var g0 := garg.hp
	var hits := await wait_until(func() -> bool: return hb_unit.out and is_instance_valid(hb_unit.walker) and hb_unit.walker.target == garg and garg.hp < g0, 30.0)
	check(hits, "barracks with a halberdier turn out for a gargoyle, and he strikes it")
	garg.take_damage(1e9)
	await wait_until(func() -> bool: return not hb_unit.out, 60.0)
	# A shield bearer alone doesn't.
	game.army.unstation(hb_unit)
	await frames(2)
	game.economy.add("gold", 500)
	var sb2 := game.army.recruit("shield_bearer")
	game.army.station(sb2, barracks)
	await wait_until(func() -> bool: return barracks.slots[0] == sb2 and sb2.state == MilitaryUnit.State.STATIONED, 60.0)
	var garg2 := spawn_dummy("gargoyle", Vector2(game.world.pathing.nearest_walkable(Vector2i((bc + Vector2(2.0, 0)).round()))), 200.0)
	await wait(2.0)
	check(not sb2.out, "a bench of only shield bearers doesn't turn out for it")
	garg2.take_damage(1e9)
	game.army.unstation(sb2)
	await clear_enemies()
