extends "res://tests/bot_base.gd"
## Headless test of the hero's equipment (docs/items-design.md §2-4, §6): the
## item list in Config, the defaults leaving the hero unchanged, every item's
## effect, the swap rules (armoury, idle at her post, a devastated hall, full
## armoury, downed keeps items, modes without equipment), and the save. Run with:
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
	h.phoenix_used = false
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
	check(Config.ITEMS.size() == 30, "the full list of docs/items-design.md §6: 30 items (%d)" % Config.ITEMS.size())
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
	wear(["seers_eye"])
	h._set_home(false)
	check(is_equal_approx(h.sight_radius(), float(Config.HERO["sight"]) * float(Config.ITEMS["seers_eye"]["sight"])), "seer's eye: she sees farther")
	reset_hero()
	# Phoenix pendant: once per wave.
	wear(["phoenix_pendant"])
	h.hp = 5.0
	h.take_damage(100.0, null, "melee")
	check(not h.dead and is_equal_approx(h.hp, h.max_hp * float(Config.ITEMS["phoenix_pendant"]["phoenix"])) and h.phoenix_used, "phoenix pendant: the killing blow leaves her standing")
	h.take_damage(1000.0, null, "melee")
	check(h.dead, "phoenix pendant: only once per wave")
	h.revive()
	game.waves.wave_started.emit(1)
	check(not h.phoenix_used, "a new wave: the pendant is ready again")
	game.waves.wave_started.emit(1)
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
	h._net_cd = 0.0
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
	wear([])
	h.force_move(Vector2(0.3, 0), self)
	check(h.grid_pos != at, "without them, a pull does")
	await frames(3)
	reset_hero()
	wear([])


func _test_save() -> void:
	wear(["ring_of_might", "swift_boots"])
	v.armoury.set_items(["lance", "lance", "net"])
	var body := SaveGame.capture(game)
	var hv: Dictionary = body["villages"][0]
	check(hv["arm"] == ["lance", "lance", "net"] and hv["hero"]["eq"] == {"accessory": "ring_of_might", "movement": "swift_boots"}, "a save holds the armoury and what she wears")
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
	check(is_equal_approx(h.speed, float(Config.HERO["speed"]) * float(Config.ITEMS["swift_boots"]["speed"])), "loaded: her boots work again")
	game.queue_free()
	await frames(3)
