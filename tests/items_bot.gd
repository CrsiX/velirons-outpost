extends "res://tests/bot_base.gd"
## Headless test of the hero's equipment (docs/items-design.md §2-4, §6): the
## item list in Config, the defaults leaving the hero unchanged, every item's
## effect, the swap rules (armoury, idle at her post, a devastated hall, full
## armoury, downed keeps items, modes without equipment), where items come
## from (§5: carriers and their sacks, gathering them home, a full armoury,
## treasures and lairs, the market's offer), relics (§7), and the save. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/items_bot.tscn
## Exits 0 when every check passes.

const SEED := 778

var v: Village
var h: Hero


func _run() -> void:
	_test_config()
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEED
	game.disable_fog = true
	add_child(game)
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	_bench_hero(true)
	v = game.player_village
	h = game.hero
	seed(SEED)
	_test_defaults()
	_test_swaps()
	await _test_weapons()
	_test_armour()
	await _test_accessories()
	await _test_movement()
	await _test_sources()
	await _test_relics()
	await _test_save()
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func spawn(kind: String, at: Vector2, hp_scale: float = 50.0, walk := false) -> Enemy:
	game.waves._spawn({"kind": kind, "spawn": game.map.edge_spawns[0], "hp_scale": hp_scale, "village": v})
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


## Puts `ids` on her straight away (through the armoury, as the command does);
## every other slot back to its default.
func wear(ids: Array) -> void:
	h.equipped.clear()
	for id: String in ids:
		h.equipped[str(Config.ITEMS[id]["slot"])] = id
	h.apply_equipment()


func give(id: String) -> Dictionary:
	return game.command("debug", {"what": "item", "kind": id})


func reset_hero() -> void:
	h.hp = h.max_hp
	h.target = null
	h.set_grid_pos(Vector2(h.home()))
	h._set_home(true)


func _test_config() -> void:
	var ok := true
	var why := ""
	for id: String in Config.ITEMS:
		var it: Dictionary = Config.ITEMS[id]
		if not (it.has("name") and it.has("desc") and str(it.get("slot", "")) in Config.ITEM_SLOTS):
			ok = false
			why = id
		if it.has("attack") and not Config.ATTACKS.has(it["attack"]):
			ok = false
			why = id + " (attack)"
		if not ResourceLoader.exists("res://art/%s.svg" % Config.item_icon(id)):
			ok = false
			why = id + " (icon)"
	check(ok, "every item: a name, a text, a slot, its attack in ATTACKS, its icon (%s)" % why)
	var defaults_ok := true
	for slot: String in Config.ITEM_SLOTS:
		var d: Dictionary = Config.ITEMS[Config.ITEM_DEFAULTS[slot]]
		defaults_ok = defaults_ok and str(d["slot"]) == slot and d.keys().all(func(k: String) -> bool: return k in ["slot", "name", "desc"])
	check(defaults_ok, "each slot has its default item there, with no effect at all")
	var campaign: Array = Config.ITEMS.keys().filter(func(id: String) -> bool: return Config.campaign_item(id))
	check(Config.ITEMS.size() - campaign.size() == 28, "the full list of docs/items-design.md §6: 28 items (%d)" % (Config.ITEMS.size() - campaign.size()))
	check(campaign == ["first_kings_hand"], "one campaign item: the First King's Hand (%s)" % str(campaign))
	check(ResourceLoader.exists("res://art/throwing_axe.svg") and ResourceLoader.exists("res://art/net_pin.svg"), "art for the thrown axe and the net")


## Today's hero, exactly, with nothing equipped.
func _test_defaults() -> void:
	var spec: Dictionary = Config.HERO
	check(h.equipped.is_empty() and Config.ITEM_SLOTS.all(func(s: String) -> bool: return h.worn(s) == Config.ITEM_DEFAULTS[s]), "a new hero wears the four defaults")
	check(is_equal_approx(h.speed, float(spec["speed"])) and is_equal_approx(h.attack_cooldown(), float(spec["attack_cooldown"])), "defaults: her speed and blow's cooldown as before")
	check(is_equal_approx(h.blow_damage(), Config.hero_stat("damage", h.level)) and h.weapon_category() == str(spec["category"]) and h.has_melee_weapon() and not h.throws() and not h.reaches_flyers(), "defaults: her sword's damage and category, melee, no flyers")
	var e := spawn("goblin", Vector2(h.home()) + Vector2(4, 0))
	check(is_equal_approx(h.reach_to(e), float(spec["attack_range"])), "defaults: her reach")
	check(is_equal_approx((h.jobs[Hero.Mode.BUILD] as BuildJob).efficiency, float(spec["build_efficiency"]))
		and is_equal_approx((h.jobs[Hero.Mode.EXPLORE] as HeroExploreJob).reveal, float(spec["explore_reveal"]))
		and (h.jobs[Hero.Mode.GATHER] as GatherJob).capacity == int(spec["gather_capacity"]), "defaults: her jobs as before")
	h.hp = h.max_hp
	h.take_damage(10.0, e, "melee")
	check(is_equal_approx(h.max_hp - h.hp, 10.0), "defaults: a hit hurts her in full")
	var xp := h.xp
	h.on_action("kill")
	check(h.xp - xp == int(Config.HERO_XP_PER_ACTION["kill"]), "defaults: XP as before")
	check(not h.immovable() and not h.drown_proof() and h.ghost_light() == 0.0, "defaults: no special powers")
	kill(e)
	reset_hero()


func _test_swaps() -> void:
	var arm := v.armoury
	check(game.items_enabled() and h.swap_error() == "", "a free game has equipment; idle at her post she may change")
	check(not game.command("equip", {"item": "lance"})["ok"], "nothing to put on that the armoury doesn't hold")
	check(not give("longsword")["ok"] and not game.command("equip", {"item": "longsword"})["ok"], "a default isn't an item: never given, never put on")
	check(give("lance")["ok"] and arm.has("lance"), "debug: an item into the armoury")
	check(game.command("equip", {"item": "lance"})["ok"] and h.worn("weapon") == "lance" and not arm.has("lance"), "put on: out of the armoury, in her weapon slot")
	give("mace")
	check(game.command("equip", {"item": "mace"})["ok"] and h.worn("weapon") == "mace" and arm.has("lance") and arm.items.size() == 1, "a swap: the lance goes back into the armoury")
	check(game.command("unequip", {"slot": "weapon"})["ok"] and h.worn("weapon") == "longsword" and arm.items.size() == 2, "taken off: the longsword again, the mace in the armoury")
	check(not game.command("unequip", {"slot": "weapon"})["ok"], "nothing to take off from a default slot")
	give("lance")
	check(arm.items.count("lance") == 2, "duplicates are allowed")
	# Full armoury: no taking off, but a straight swap still works.
	game.command("equip", {"item": "lance"})
	while not arm.full():
		give("net")
	check(not give("net")["ok"], "a full armoury takes nothing more")
	check(not game.command("unequip", {"slot": "weapon"})["ok"] and h.worn("weapon") == "lance", "full: she can't take off into it")
	check(game.command("equip", {"item": "mace"})["ok"] and h.worn("weapon") == "mace" and arm.full() and arm.has("lance"), "full: a straight swap still works")
	# Only while idle at her post at home, the hall standing.
	h.set_grid_pos(Vector2(h.home()) + Vector2(3, 0))
	h._set_home(false)
	check(h.swap_error() != "" and not game.command("equip", {"item": "lance"})["ok"], "away from her post: no swap (%s)" % h.swap_error())
	reset_hero()
	var foe := spawn("goblin", Vector2(h.home()) + Vector2(5, 0))
	h.target = foe
	check(h.swap_error() != "", "with an enemy to fight: no swap")
	h.target = null
	kill(foe)
	var hall := v.town_hall()
	hall.devastated = true
	check(not arm.is_open() and h.swap_error().contains("devastated"), "a devastated town hall closes the armoury (%s)" % h.swap_error())
	hall.devastated = false
	# Resting inside the town hall counts as at her post.
	h.mode = Hero.Mode.REST
	h._set_in_hall(true)
	check(h.in_hall and h.swap_error() == "", "resting inside the town hall she may change (%s)" % h.swap_error())
	check(game.command("equip", {"item": "lance"})["ok"] and h.worn("weapon") == "lance" and arm.has("mace"), "inside the hall: a swap")
	check(game.command("equip", {"item": "mace"})["ok"] and h.worn("weapon") == "mace" and arm.has("lance") and h.in_hall, "inside the hall: and back, still inside")
	h._set_in_hall(false)
	h.mode = Hero.Mode.DEFEND
	game.tutorial_mode = true
	check(not game.items_enabled() and h.swap_error() != "" and not give("net")["ok"], "the tutorial has no equipment")
	game.tutorial_mode = false
	# Downed: she keeps what she wears.
	h._downed(null)
	check(h.swap_error() != "", "downed: no swap")
	check(h.worn("weapon") == "mace", "downed: she keeps her items")
	h.revive()
	check(h.worn("weapon") == "mace" and h.swap_error() == "", "back: still wearing them, and she may change again")
	arm.set_items([])
	wear([])
	reset_hero()


func _test_weapons() -> void:
	var home := Vector2(h.home())
	var base := Config.hero_stat("damage", h.level)
	# Flame sword and blessed blade: their category.
	wear(["flame_sword"])
	check(h.weapon_category() == "fire" and h.has_melee_weapon(), "flame sword: fire, still a blade")
	wear(["blessed_blade"])
	check(h.weapon_category() == "holy", "blessed blade: holy")
	var ghost := spawn("ghost", home + Vector2(9, 0))
	check(not ghost.hurt_by(str(Config.HERO["category"])) and ghost.hurt_by(h.weapon_category()), "a ghost: her sword can't hurt it, the blessed blade can")
	kill(ghost)
	# Poison-coated sword: a dose with the blow.
	wear(["poison_sword"])
	var g := spawn("goblin", home + Vector2(0.7, 0))
	h._strike(g)
	check(Poison.of(g) != null, "poison sword: the blow leaves a dose")
	kill(g)
	# Cleaver: heals a share of what it dealt.
	wear(["cleaver"])
	g = spawn("goblin", home + Vector2(0.7, 0))
	h.hp = 10.0
	var before := g.hp
	Engine.time_scale = 1.0
	h._land_blow(g, 20.0)
	var dealt := before - g.hp
	check(is_equal_approx(h.hp, 10.0 + dealt * float(Config.ITEMS["cleaver"]["lifesteal"])), "cleaver: she heals %s of %s dealt" % [str(h.hp - 10.0), str(dealt)])
	kill(g)
	h.hp = h.max_hp
	# Mace: the enemy behind takes a share.
	wear(["mace"])
	var front := spawn("goblin", home + Vector2(0.7, 0))
	var back := spawn("goblin", home + Vector2(1.7, 0))
	var side := spawn("goblin", home + Vector2(0, 2.5))
	var fb := front.hp
	var bb := back.hp
	var sb := side.hp
	h._land_blow(front, 20.0)
	check(is_equal_approx(fb - front.hp, 20.0) and is_equal_approx(bb - back.hp, 20.0 * float(Config.ITEMS["mace"]["behind"][0])) and side.hp == sb, "mace: the one behind takes %s, one beside nothing" % str(bb - back.hp))
	for e in [front, back, side]:
		kill(e)
	# Great axe: everyone around her, each for less.
	wear(["great_axe"])
	var circle: Array = Config.ITEMS["great_axe"]["circle"]
	var near: Array[Enemy] = [spawn("goblin", home + Vector2(0.8, 0)), spawn("goblin", home + Vector2(-0.6, 0.6)), spawn("goblin", home + Vector2(0, -1.1))]
	var far := spawn("goblin", home + Vector2(float(circle[0]) + 1.5, 0))
	var hps := near.map(func(e: Enemy) -> float: return e.hp)
	var fh := far.hp
	h._land_blow(near[0], 20.0)
	var all_hit := true
	for i in near.size():
		all_hit = all_hit and is_equal_approx(float(hps[i]) - near[i].hp, 20.0 * float(circle[1]))
	check(all_hit and far.hp == fh, "great axe: every enemy within reach takes the share, none farther")
	for e in near:
		kill(e)
	kill(far)
	# Great axe: no reach from the shore at one on deep water.
	var shore := Vector2i(-1, -1)
	var water := Vector2i(-1, -1)
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			if water == Vector2i(-1, -1) and game.map.is_deep(t) and game.world.pathing.is_walkable(t + Vector2i(1, 0)):
				water = t
				shore = t + Vector2i(1, 0)
	check(water != Vector2i(-1, -1), "the test map has deep water by a shore")
	if water != Vector2i(-1, -1):
		var crab := spawn("goblin", Vector2(water))
		h.set_grid_pos(Vector2(shore))
		check(is_equal_approx(h.reach_to(crab), float(Config.HERO["attack_range"])) and not h.can_hit(crab), "great axe: one on deep water off the shore is no target (reach %.1f)" % h.reach_to(crab))
		wear([])
		check(h.can_hit(crab) and h.reach_to(crab) >= float(Config.AQUA["melee_reach"]), "a sword strikes it from the shore")
		kill(crab)
		reset_hero()
	wear(["great_axe"])
	check(h.reach_to(spawn("goblin", home + Vector2(3, 0))) <= float(Config.ITEMS["great_axe"]["circle"][0]), "great axe: her target is always within the circle")
	await clear_enemies()
	# Lance: reach and flyers.
	wear(["lance"])
	g = spawn("goblin", home + Vector2(4, 0))
	check(is_equal_approx(h.reach_to(g), float(Config.HERO["attack_range"]) * float(Config.ITEMS["lance"]["reach"])) and h.reaches_flyers(), "lance: a longer reach, and flyers")
	kill(g)
	# Throwing axes: a ranged attack, no crits, flyers too.
	wear(["throwing_axes"])
	g = spawn("goblin", home + Vector2(2.5, 0))
	check(h.throws() and not h.has_melee_weapon() and h.reaches_flyers() and is_equal_approx(h.reach_to(g), float(Config.ITEMS["throwing_axes"]["range"])), "throwing axes: thrown from a few tiles, no blade, flyers too")
	check(is_equal_approx(h.blow_damage(), base * float(Config.ITEMS["throwing_axes"]["damage"])), "throwing axes: their damage share")
	before = g.hp
	h._strike(g)
	await wait_until(func() -> bool: return g.hp < before, 3.0)
	check(g.hp < before, "a thrown axe lands and hurts")
	kill(g)
	# Ring of might and bearskin: damage factors multiply.
	wear(["ring_of_might", "bearskin"])
	check(is_equal_approx(h.blow_damage(), base * 1.2 * 1.2), "ring of might x bearskin: the damage factors multiply")
	wear([])


func _test_armour() -> void:
	var e := spawn("goblin", Vector2(h.home()) + Vector2(3, 0))
	wear(["full_plate"])
	h.hp = h.max_hp
	h.take_damage(10.0, e, "melee")
	check(is_equal_approx(h.max_hp - h.hp, 10.0 * float(Config.ITEMS["full_plate"]["taken"])) and is_equal_approx(h.speed, float(Config.HERO["speed"]) * float(Config.ITEMS["full_plate"]["speed"])), "full plate: less damage, slower")
	wear(["full_plate", "swift_boots"])
	check(is_equal_approx(h.speed, float(Config.HERO["speed"]) * 0.8 * 1.25), "full plate and swift boots: speed factors multiply")
	wear(["bearskin"])
	h.hp = h.max_hp
	h.take_damage(10.0, e, "melee")
	check(is_equal_approx(h.max_hp - h.hp, 10.0 * float(Config.ITEMS["bearskin"]["taken"])), "bearskin: more damage taken")
	h.take_damage(10.0, e, "pure")
	check(is_equal_approx(h.max_hp - h.hp, 10.0 * float(Config.ITEMS["bearskin"]["taken"]) + 10.0), "pure damage is never scaled")
	for pair in [["buckler", "melee"], ["buckler", "projectile"], ["magical_shield", "magical"]]:
		wear([pair[0]])
		var blocked := 0
		for i in 400:
			h.hp = h.max_hp
			h.take_damage(1.0, e, pair[1])
			if h.hp >= h.max_hp:
				blocked += 1
		var want := float(Config.ITEMS[pair[0]]["block"][pair[1]])
		check(absf(blocked / 400.0 - want) < 0.08, "%s: blocks about %d %% of %s hits whole (%d of 400)" % [pair[0], int(want * 100.0), pair[1], blocked])
	wear(["buckler"])
	var hits := 0
	for i in 100:
		h.hp = h.max_hp
		h.take_damage(1.0, e, "magical")
		if h.hp < h.max_hp:
			hits += 1
	check(hits == 100, "a buckler blocks no magic")
	wear(["thorn_mail"])
	h.hp = h.max_hp
	var eh := e.hp
	h.take_damage(10.0, e, "melee")
	check(is_equal_approx(eh - e.hp, 10.0 * float(Config.ITEMS["thorn_mail"]["thorns"])), "thorn mail: a share of a melee hit back")
	eh = e.hp
	h.take_damage(10.0, e, "magical")
	check(e.hp == eh, "thorn mail: nothing back from a spell")
	kill(e)
	wear([])
	h.hp = h.max_hp


func _test_accessories() -> void:
	var home := Vector2(h.home())
	var e := spawn("goblin", home + Vector2(3, 0))
	wear(["rose_necklace"])
	h.hp = h.max_hp
	h.take_damage(10.0, e, "poison")
	check(is_equal_approx(h.max_hp - h.hp, 10.0 * float(Config.ITEMS["rose_necklace"]["resist"]["poison"])), "rose necklace: poison hurts less")
	kill(e)
	wear(["gatherers_satchel"])
	check((h.jobs[Hero.Mode.GATHER] as GatherJob).capacity == roundi(int(Config.HERO["gather_capacity"]) * float(Config.ITEMS["gatherers_satchel"]["gather"])), "gatherer's satchel: she carries more")
	wear(["builders_gloves"])
	check(is_equal_approx((h.jobs[Hero.Mode.BUILD] as BuildJob).efficiency, float(Config.HERO["build_efficiency"]) * float(Config.ITEMS["builders_gloves"]["build"])), "builder's gloves: she builds faster")
	wear(["scholars_tome"])
	var xp := h.xp
	h.on_action("kill")
	check(h.xp - xp == roundi(int(Config.HERO_XP_PER_ACTION["kill"]) * float(Config.ITEMS["scholars_tome"]["xp"])), "scholar's tome: more XP (%d)" % (h.xp - xp))
	reset_hero()
	# Lantern: ghosts near her show themselves.
	var ghost := spawn("ghost", home + Vector2(2, 0))
	(ghost.behavior as GhostBehavior)._picked = true
	check(not GhostBehavior._revealed(ghost), "no lantern: the ghost stays unseen")
	wear(["lantern"])
	check(GhostBehavior._revealed(ghost), "lantern: a ghost near her is revealed")
	ghost.set_grid_pos(home + Vector2(float(Config.ITEMS["lantern"]["ghost_light"]) + 2.0, 0))
	check(not GhostBehavior._revealed(ghost), "lantern: not one farther away")
	kill(ghost)
	# Net: pins her target; never a boss or a water-only kind.
	wear(["net"])
	var road := game.map.edge_spawns[0]
	h.set_grid_pos(Vector2(road))
	var walker := spawn("goblin", Vector2(road) + Vector2(0.5, 0.5), 50.0, true)
	walker.speed = 1.0
	h.target = walker
	h.net_cooldown = 0.0
	h._tick_net(0.1)
	check(walker.is_netted() and walker.fx.has("net"), "net: thrown at her target in range")
	var at := walker.grid_pos
	await wait(1.0)
	check(walker.grid_pos.distance_to(at) < 0.01 and walker.is_netted(), "net: it doesn't move while held")
	check(not walker.can_be_netted(), "net: not again while it is held")
	await wait_until(func() -> bool: return not walker.is_netted(), float(Config.ITEMS["net"]["net"][2]) + 2.0)
	check(not walker.is_netted() and not walker.fx.has("net"), "net: it wears off")
	kill(walker)
	var boss := spawn("legion_captain", home + Vector2(2, 0))
	check(not boss.can_be_netted(), "net: never a boss")
	kill(boss)
	var named := spawn("goblin", home + Vector2(2, 0))
	named.given_name = "Grut"
	check(not named.can_be_netted(), "net: never a named enemy")
	kill(named)
	h.target = null
	wear([])
	reset_hero()


func _test_movement() -> void:
	var p := game.world.pathing
	var map := game.map
	wear(["swift_boots"])
	check(is_equal_approx(h.speed, float(Config.HERO["speed"]) * float(Config.ITEMS["swift_boots"]["speed"])), "swift boots: faster")
	wear(["pathfinders_boots"])
	check(is_equal_approx((h.jobs[Hero.Mode.EXPLORE] as HeroExploreJob).reveal, float(Config.HERO["explore_reveal"]) * float(Config.ITEMS["pathfinders_boots"]["explore"])), "pathfinder's boots: a wider area explored")
	# Feather boots: forest, deep water and walls; nothing slows her.
	wear(["feather_boots"])
	check(is_equal_approx(h.attack_cooldown(), float(Config.HERO["attack_cooldown"]) * float(Config.ITEMS["feather_boots"]["cooldown"])) and h.drown_proof(), "feather boots: slower blows, deep water can't drown her")
	var forest := Vector2i(-1, -1)
	var deep := Vector2i(-1, -1)
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if forest == Vector2i(-1, -1) and map.is_forest(t) and map.building_at(t) == null and not p.is_walkable(t):
				forest = t
			if deep == Vector2i(-1, -1) and map.is_deep(t) and map.building_at(t) == null:
				deep = t
	var wall: Building = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall")[0]
	check(forest != Vector2i(-1, -1) and p.free_open(forest) and not p.is_walkable(forest), "feather boots: forest is open to her")
	check(deep == Vector2i(-1, -1) or p.free_open(deep), "feather boots: deep water is open to her")
	check(p.free_open(wall.tile) and not p.is_walkable(wall.tile), "feather boots: she crosses walls")
	check(not h.find_way(h.current_tile(), forest).is_empty(), "feather boots: a way into the forest")
	var rock := Vector2i(-1, -1)
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if rock == Vector2i(-1, -1) and not map.is_passable(t) and not map.is_deep(t) and not map.is_forest(t) and map.building_at(t) == null:
				rock = t
	check(rock != Vector2i(-1, -1) and not p.free_open(rock), "feather boots: never over mountains or other impassable ground")
	var e := spawn("gargoyle", Vector2(h.home()) + Vector2(2, 0))
	h.hp = h.max_hp
	h.take_damage(5.0, e, "melee")
	check(e.flies() and is_equal_approx(h.max_hp - h.hp, 5.0 * float(Config.ITEMS["feather_boots"]["flyer_taken"])), "feather boots: flyers hit her harder")
	kill(e)
	h.set_grid_pos(Vector2(forest))
	check(is_equal_approx(h._walk_factor(), 1.0), "feather boots: no ground slows her")
	reset_hero()
	# Heavy steel boots: nothing moves her.
	wear(["heavy_boots"])
	check(h.immovable(), "heavy boots: immovable")
	var at := h.grid_pos
	h.force_move(Vector2(0.5, 0), self)
	check(h.grid_pos == at and not h.is_forced(), "heavy boots: a pull doesn't move her")
	# A wrathwood's roots: they grow on her, then fall off at once.
	var tree := spawn("wrathwood", at + Vector2(1, 0))
	var wb := tree.behavior as WrathwoodBehavior
	var total := float(tree.spec()["grip_time"])
	wb._held[h] = total
	var steps := 0
	while wb._held.has(h) and steps < 600:
		wb._hold(tree, 1.0 / 60.0)
		steps += 1
	var took := steps / 60.0
	check(took >= total * WrathwoodBehavior.ROOTS_GROW and took < total * (WrathwoodBehavior.ROOTS_GROW + WrathwoodBehavior.ROOTS_SINK) + 0.1 and h.grid_pos == at,
		"heavy boots: the roots grow on and fall off at once (%.2f s of %.1f)" % [took, total])
	kill(tree)
	wear([])
	h.force_move(Vector2(0.3, 0), self)
	check(h.grid_pos != at, "without them, a pull does")
	await frames(3)
	reset_hero()
	wear([])


func _item_sacks() -> Array[Treasure]:
	var out: Array[Treasure] = []
	for o in game.world.map_objects:
		if o is Treasure and (o as Treasure).reward().has("equipment") and not (o as Treasure).looted and o.data.get("sack", false):
			out.append(o)
	return out


func _test_sources() -> void:
	reset_hero()
	wear([])
	v.armoury.set_items([])
	# Which items, who may carry.
	var pool := ItemDrops.pool(game)
	check(not pool.has("longsword") and not pool.has("soldiers_boots") and pool.has("flame_sword") and not pool.has("first_kings_hand") and pool.size() == Config.ITEMS.size() - Config.ITEM_DEFAULTS.size() - 1, "every item but the defaults and the campaign's can come from a source (%d)" % pool.size())
	# A campaign item: only its scenario gives it, nothing hands it out or trades it.
	var hand := "first_kings_hand"
	check(not v.armoury.add(hand) and not v.armoury.has(hand), "the armoury never takes a campaign item")
	check(not game.command("debug", {"what": "item", "kind": hand})["ok"] and not game.command("equip", {"item": hand})["ok"], "nor the debug page, nor can she wear it")
	var probe := spawn("goblin", Vector2(v.center) + Vector2(6, 0))
	ItemDrops.give(probe, hand)
	check(probe.carried_item == "", "no enemy carries one")
	probe.queue_free()
	var never := true
	for kind: String in Config.ENEMIES:
		var sp: Dictionary = Config.ENEMIES[kind]
		if (str(sp.get("habitat", "land")) == "water" or sp.get("flying", false) or sp.get("pin_proof", false)) and ItemDrops.can_carry(kind):
			never = false
	check(never and ItemDrops.can_carry("goblin") and not ItemDrops.can_carry("goblin", "Lysa"), "carriers: never water-only, flying, bosses or named ones")
	check(ItemDrops.carriers_on(game), "single player has random carriers")
	for sk in _item_sacks():  # (camp guards killed by the earlier tests may have carried one)
		sk.mark_looted()
	# A carrier: the glint, the sack where it falls.
	var at := Vector2(v.center + Vector2i(6, 0))
	game.waves._spawn({"kind": "goblin", "spawn": game.map.edge_spawns[0], "hp_scale": 1.0, "village": v, "item": "lance"})
	var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
	e.set_grid_pos(at)
	e.speed = 0.0
	check(e.carried_item == "lance" and e.fx.has("glint"), "a wave entry's \"item\": the enemy carries it, with a glint")
	kill(e)
	await frames(3)
	var sacks := _item_sacks()
	check(sacks.size() == 1 and str(sacks[0].reward()["equipment"]) == "lance" and Vector2(sacks[0].tile).distance_to(at) <= float(Config.ITEM_SOURCES["drop_radius"]) * 1.5, "killed, it drops the item in a sack nearby (%s near %s)" % [str(sacks.map(func(t: Treasure) -> Vector2i: return t.tile)), str(at)])
	if sacks.is_empty():
		return
	check(sacks[0].display_name() == "Dropped item" and sacks[0].art() == "sack", "the sack doesn't say which item")
	# Full armoury: no one picks it up; with room, the hero gathering brings it home.
	var full: Array[String] = []
	for k in v.armoury.cap():
		full.append("net")
	v.armoury.set_items(full)
	check(not ItemDrops.room_for(v, sacks[0].reward()), "a full armoury: the sack waits")
	v.armoury.set_items([])
	_bench_hero(false)
	game.command("hero_mode", {"mode": Hero.Mode.GATHER})
	check(await wait_until(func() -> bool: return v.armoury.has("lance"), 120.0), "the hero gathering brings it to the armoury")
	check(_item_sacks().is_empty(), "and the sack is gone")
	game.command("hero_mode", {"mode": Hero.Mode.DEFEND})
	_bench_hero(true)
	reset_hero()
	# Brought home to a full armoury: it waits by the town hall.
	v.armoury.set_items(full)
	Treasure.pay(v, {"equipment": "mace"})
	sacks = _item_sacks()
	check(sacks.size() == 1 and str(sacks[0].reward()["equipment"]) == "mace" and Vector2(sacks[0].tile).distance_to(Vector2(v.town_hall().tile)) < 8.0, "home to a full armoury: the item waits by the town hall")
	for sk in sacks:
		sk.mark_looted()
	v.armoury.set_items([])
	Treasure.pay(v, {"equipment": "mace"})
	check(v.armoury.has("mace"), "a treasure's item goes to the armoury")
	# A camp carrier keeps its item through a save; camps roll their carriers.
	var rng := RandomNumberGenerator.new()
	var camp_guards: Array = []
	for i in 3:
		var g: Enemy = game.waves._walker("goblin", at, 1.0, v)
		camp_guards.append(g)
	var c := ItemDrops.maybe_carrier(game, camp_guards, 1.0, rng)
	check(c != null and c.carried_item != "" and pool.has(c.carried_item), "a sure chance: one guard carries a random item")
	check(ItemDrops.maybe_carrier(game, camp_guards, 0.0, rng) == null, "no chance: none more")
	for g: Enemy in camp_guards:
		g.free()
	# The market's offer.
	v.economy.add("materials", 200, "debug")
	v.economy.add("gold", 100, "debug")
	var spot := find_spot("market", v.center)
	var placed := game.command("place_building", {"kind": "market", "tile": spot})
	var m := v.market()
	check(placed["ok"] and m != null, "a market to test the item offer (%s)" % placed.get("error", ""))
	if m == null:
		return
	m.finish()
	v.construction.queue.erase(m)
	check(m.item_offer.size() == int(Config.MARKET["item_offer"]) and m.item_offer.all(func(id: String) -> bool: return pool.has(id)), "the market offers %d random items" % int(Config.MARKET["item_offer"]))
	var want := m.item_offer[0]
	v.economy.add("gold", int(Config.MARKET["item_gold"]) * 2, "debug")
	var gold := v.economy.amount("gold")
	v.armoury.set_items(full)
	check(not game.command("market_buy_item", {"building": m.nid, "item": want}).get("ok", false), "no buying into a full armoury")
	v.armoury.set_items([])
	check(game.command("market_buy_item", {"building": m.nid, "item": want}).get("ok", false) and v.armoury.has(want), "bought: into the armoury")
	check(v.economy.amount("gold") == gold - int(Config.MARKET["item_gold"]) and m.item_offer.size() == int(Config.MARKET["item_offer"]) - 1, "for its price, and off the offer")
	check(not game.command("market_buy_item", {"building": m.nid, "item": "longsword"}).get("ok", false), "only what is on offer")
	var body := SaveGame.capture(game)
	var found := false
	for bd: Dictionary in body["buildings"]:
		if bd.has("mk"):
			found = bd["mk"]["io"] == m.item_offer
	check(found, "a save holds the market's offer")
	v.armoury.set_items([])


## Relics (docs/items-design.md §7): the list, every relic's effect, a
## duplicate counting once, map-wide ones for everyone, room in the armoury,
## never an item, the sources and the market's relic offer.
func _test_relics() -> void:
	print("-- relics")
	reset_hero()
	wear([])
	v.armoury.set_items([])
	v.relics.clear()
	for sk in _item_sacks():
		sk.mark_looted()
	# The list.
	var shape := true
	for k: String in Config.RELICS:
		var r: Dictionary = Config.RELICS[k]
		shape = shape and str(r.get("reach", "")) in ["village", "map"] and r.has("name") and r.has("desc") and not Config.ITEMS.has(k)
	check(shape, "every relic is village-wide or map-wide, named, described, and no item shares its id")
	check(Config.ITEMS.keys().all(func(id: String) -> bool: return not Relics.is_relic(id) and not Config.ITEMS[id].has("relic")), "no equipment is a relic: equipment is worn, a relic never")
	var pool := Relics.pool(game)
	check(pool.has("hawkeye") and pool.has("sun_disc") and not pool.has("peace_ribbon") and pool.all(func(id: String) -> bool: return Config.RELICS.has(id)), "single player: every relic but the peace ribbon (co-op only) can come, and only relics")
	check(Relics.pool_for(2).has("peace_ribbon"), "two villages: the peace ribbon too")
	check(Relics.usable(game, "peace_ribbon", 3) != "peace_ribbon" and Relics.reach(Relics.usable(game, "peace_ribbon", 3)) == "village" and Relics.usable(game, "stormglass", 3) == "stormglass", "a relic this game can't use is swapped for a village-wide one")
	# Village-wide, a duplicate once.
	check(v.kill_gold(100) == 100, "no relic: plain kill gold")
	Treasure.pay(v, {"relic": "tithe_box"})
	check(v.relics == ["tithe_box"] and v.kill_gold(100) == 100 + roundi(100 * float(Config.RELICS["tithe_box"]["kill_gold"])), "a tithe box: more gold per kill (%d)" % v.kill_gold(100))
	Treasure.pay(v, {"relic": "tithe_box"})
	check(v.relics.count("tithe_box") == 2 and v.kill_gold(100) == 100 + roundi(100 * float(Config.RELICS["tithe_box"]["kill_gold"])), "a second tithe box is kept but counts once")
	check(Relics.has_relic(v, "tithe_box") and v.armoury.count() == 2, "relics take room in the armoury (%d)" % v.armoury.count())
	v.relics.clear()
	# Mason's seal: repairs.
	var hall := v.town_hall()
	hall.hp = hall.max_hp() * 0.5
	var plain := int(hall.repair_cost().get("materials", 0))
	v.relics.assign(["masons_seal"])
	var sealed := int(hall.repair_cost().get("materials", 0))
	check(plain > 0 and sealed < plain, "a mason's seal: repairs cost less (%d, not %d)" % [sealed, plain])
	hall.hp = hall.max_hp()
	# Old kings' banner: units in towers.
	v.economy.add("gold", 500, "debug")
	var u := v.army.recruit("archer")
	check(u != null, "an archer to test the banner")
	if u != null:
		u.post = hall
		u.state = MilitaryUnit.State.STATIONED
		v.relics.clear()
		var r0 := u.rate(game)
		v.relics.assign(["kings_banner"])
		check(is_equal_approx(u.rate(game), r0 * (1.0 + float(Config.RELICS["kings_banner"]["tower_attack"]))), "old kings' banner: a unit in a tower attacks faster")
		u.state = MilitaryUnit.State.RESERVE
		check(is_equal_approx(u.rate(game), r0), "but not out of it")
		u.post = null
	# Woodcutter's axe, toll charter, cartographer's chart: their bonus.
	v.relics.assign(["woodcutters_axe", "cartographers_chart"])
	check(is_equal_approx(v.relic_bonus("chop"), float(Config.RELICS["woodcutters_axe"]["chop"])) and v.relic_bonus("chart") > 0.0, "the woodcutter's axe and the cartographer's chart count")
	var camp_like := game.world.map_objects.filter(func(o: MapObject) -> bool: return is_instance_valid(o) and o is MonsterCamp)
	check(not camp_like.is_empty() and TacticalMap.is_rumour(camp_like[0]), "the chart shows a camp as a rumour")
	# Grave salt: corpses near the village rot later.
	v.relics.assign(["grave_salt"])
	var c := game.corpses.spawn("goblin", 0, Vector2(v.center) + Vector2(3, 0))
	check(is_equal_approx(c.time_left, Config.CORPSE_LIFETIME * (1.0 + float(Config.RELICS["grave_salt"]["corpse_life"]))), "grave salt: a corpse by the village rots later (%.0f s)" % c.time_left)
	game.corpses.remove(c)
	c.queue_free()
	v.relics.clear()
	# Map-wide: for every enemy, once however many.
	var sk := spawn("skeleton", Vector2(v.center) + Vector2(9, 0))
	var gob := spawn("goblin", Vector2(v.center) + Vector2(9, 1))
	var holy0 := sk.damage_factor("holy")
	var gob0 := gob.damage_factor("holy")
	v.relics.assign(["sun_disc", "sun_disc"])
	check(is_equal_approx(sk.damage_factor("holy"), holy0 * (1.0 + float(Config.RELICS["sun_disc"]["sun_holy"]))) and is_equal_approx(gob.damage_factor("holy"), gob0), "a sun disc (two count once): the undead take more holy damage, others not")
	v.fallen = true
	check(is_equal_approx(sk.damage_factor("holy"), holy0), "a fallen village's relics work no more")
	v.fallen = false
	kill(sk)
	kill(gob)
	v.relics.assign(["stormglass", "peace_ribbon"])
	check(is_equal_approx(Relics.dive_time(game, 6.0), 6.0 * (1.0 - float(Config.RELICS["stormglass"]["dive"]))), "stormglass: a hurt water monster's dive is shorter")
	check(is_equal_approx(Relics.map_bonus(game, "help_tax"), float(Config.RELICS["peace_ribbon"]["help_tax"])), "peace ribbon: the help tax is lower")
	v.relics.clear()
	# A full armoury: looters leave it, and one brought home waits by the hall.
	var full: Array[String] = []
	for k in v.armoury.cap() - 1:
		full.append("net")
	v.armoury.set_items(full)
	v.relics.assign(["hawkeye"])
	check(v.armoury.full() and not ItemDrops.room_for(v, {"relic": "harvest"}), "items and relics fill the armoury together: no room for a relic")
	Treasure.pay(v, {"relic": "harvest"})
	var waiting := game.world.map_objects.filter(func(o: MapObject) -> bool: return is_instance_valid(o) and o is Treasure and (o as Treasure).data.get("sack", false) and not (o as Treasure).looted and str((o as Treasure).reward().get("relic", "")) == "harvest")
	check(not v.relics.has("harvest") and waiting.size() == 1 and (waiting[0] as Treasure).display_name() == "Dropped relic", "brought home to a full armoury: it waits by the town hall")
	for w: Treasure in waiting:
		w.mark_looted()
	v.armoury.set_items([])
	# The market's relic offer.
	var m := v.market()
	check(m != null, "the market from the item test")
	if m != null:
		m.relic_offer.clear()
		m.stationed = 0.0
		m.roll_items()
		check(m.relic_offer.is_empty() and m.worker == null, "no trader: a new equipment offer brings no relic")
		await frames(30)
		check(m.relic_offer.is_empty() and m.stationed == 0.0, "and no trader's time counts")
		var after := float(Config.MARKET["relic_after"])
		m.tend_relic(after * 0.6)
		m.tend_relic(after * 0.3)
		check(m.relic_offer.is_empty() and is_equal_approx(m.stationed, after * 0.9), "the trader's time adds up, short of a relic")
		m.tend_relic(after * 0.2)
		check(m.relic_offer.size() == 1 and pool.has(m.relic_offer[0]) and m.stationed == 0.0, "after %s s of his time he brings a relic for sale" % str(after))
		m.relic_offer.assign(["peace_ribbon"])  # (one no source here gives: its swap shows)
		m.tend_relic(after * 0.5)
		check(m.relic_offer == ["peace_ribbon"] and is_equal_approx(m.stationed, after * 0.5), "his time goes on counting while it is on offer")
		m.tend_relic(after * 0.5)
		check(m.relic_offer.size() == 1 and m.relic_offer[0] != "peace_ribbon" and m.stationed == 0.0, "not bought in its time: it is gone, a new one instead (%s)" % str(m.relic_offer))
		var want := m.relic_offer[0]
		v.economy.add("gold", int(Config.MARKET["relic_gold"]), "debug")
		var gold := v.economy.amount("gold")
		check(game.command("market_buy_item", {"building": m.nid, "item": want}).get("ok", false) and Relics.has_relic(v, want), "bought the %s" % want)
		check(v.economy.amount("gold") == gold - int(Config.MARKET["relic_gold"]) and m.relic_offer.is_empty(), "for the relic price, and off the offer")
		m.tend_relic(after * 0.9)
		check(m.relic_offer.is_empty(), "bought: the offer stays empty for the rest of its time")
		m.tend_relic(after * 0.1)
		check(m.relic_offer.size() == 1, "then he brings the next one")
		m.tend_relic(12.5)
		var mk := {}
		for bd: Dictionary in SaveGame.capture(game)["buildings"]:
			if bd.has("mk"):
				mk = bd["mk"]
		check(mk.get("ro", []) == Array(m.relic_offer) and not m.relic_offer.is_empty(), "a save holds the relic offer")
		check(is_equal_approx(float(mk.get("st", -1.0)), 12.5), "and the trader's time towards the next one")
	v.armoury.set_items([])
	v.relics.assign(["sun_disc", "sun_disc", "hawkeye"])


func _test_save() -> void:
	wear(["ring_of_might", "swift_boots"])
	v.armoury.set_items(["lance", "lance", "net"])
	h.net_cooldown = 7.5
	var body := SaveGame.capture(game)
	var hv: Dictionary = body["villages"][0]
	check(hv["arm"] == ["lance", "lance", "net"] and hv["hero"]["eq"] == {"accessory": "ring_of_might", "movement": "swift_boots"}, "a save holds the armoury and what she wears")
	check(hv["hero"]["eqt"] == {"net": 7.5}, "a save holds her items' timers: the net's cooldown")
	game.queue_free()
	await frames(3)
	Settings.pending_save = body
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await frames(3)
	v = game.player_village
	h = game.hero
	check(game.loaded and h.worn("accessory") == "ring_of_might" and h.worn("movement") == "swift_boots" and h.worn("weapon") == "longsword", "loaded: she wears the same")
	check(Array(v.armoury.items) == ["lance", "lance", "net"], "loaded: the armoury holds the same")
	check(Array(v.relics) == ["sun_disc", "sun_disc", "hawkeye"] and Relics.map_bonus(game, "sun_holy") > 0.0, "loaded: the relics, a duplicate too, and they work")
	check(h.net_cooldown > 0.0 and h.net_cooldown <= 7.5, "loaded: the net's cooldown goes on (%.2f)" % h.net_cooldown)
	check(is_equal_approx(h.speed, float(Config.HERO["speed"]) * float(Config.ITEMS["swift_boots"]["speed"])), "loaded: her boots work again")
	game.queue_free()
	await frames(3)
