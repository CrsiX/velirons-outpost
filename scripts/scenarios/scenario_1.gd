extends Scenario
## Scenario 1: Homecoming (docs/scenarios-design.md §3.1, docs/story-design.md).
## Brenna Hale comes home from the knights' service and finds her village half
## burned: four huts of nine, the walls, gates and wall towers broken. With her
## father Einar (the forester), a builder and a farmer she rebuilds it, grows
## its economy and holds five weak Wilderness waves, and no villager may die.
## When it's done, an old friend comes up the road: Pell.


## Where the south road (Brenna's, and Pell's at the end) leaves the map.
const SOUTH_ROAD := Vector2i(47, 49)


func _init() -> void:
	number = 1
	title = "Homecoming"
	blurb = "Brenna Hale comes home to a half-burned village. Rebuild it with her father Einar, and don't lose a single villager."
	map_path = "res://data/maps/homecoming.json"
	place = "outpost"
	portrait = "portrait_einar"

	# The baseline: a ruined outpost, three villagers, little of anything.
	difficulty = "easy"
	enemy_scale = {"hp": 0.5, "damage": 0.5, "spell_damage": 0.5}  # (weaker than Easy on purpose)
	resources = {"gold": 150, "food": 120, "materials": 180}
	civilians = ["builder", "farmer", "forester"]
	names = {"forester": "Einar"}
	buildings = ["farm", "camp"]
	huts_standing = 4
	pieces_standing = {"gate": 1, "wall": 3, "wall_tower": 1}
	pieces_hp = 0.6
	hero_name = "Brenna"
	hero_level = 1
	hero_start = Vector2i(46, 42)  # (by the south road, where she slept on the way home)
	tent_tile = Vector2i(44, 41)
	walk_title = "Homeward"
	walk_text = "Brenna walks the last stretch of road home."

	# The rules: archers only (no specialising), no barracks or training grounds.
	units = ["archer"]
	build = ["tower", "farm", "camp", "lightstone"]
	specialise = false
	hero_revives = true
	fail_on_villager_death = true
	corpses_rot = false  # (until the gatherers' card is done: on_card_done)

	# Wilderness only, kept weak: goblins, rats from wave 2, an ork from wave 3,
	# slimes in the last wave. Wave 1 comes when the player calls it, down the
	# road the watchtower card points at (on_start).
	waves = [
		{"kinds": {"goblin": 3}, "spawns": 1},
		{"kinds": {"goblin": 4}, "rat_packs": [4], "spawns": 2},
		{"kinds": {"goblin": 4, "ork": 1}, "rat_packs": [4], "spawns": 2},
		{"kinds": {"goblin": 6, "ork": 1}, "rat_packs": [5], "spawns": 2},
		{"kinds": {"goblin": 5, "ork": 2, "slime3": 2}, "rat_packs": [5], "spawns": 3},
	]
	first_wave_waits = true
	wave_gap = 40.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"einar": {"name": "Einar", "portrait": "portrait_einar", "color": Color("a8c878")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
	}


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var tent := r.at(hero_start)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": tent, "zoom": 1.25, "time": 0.01},
		{"title": "Homecoming", "sub": "Scenario 1", "time": 3.0},
		{"say": "", "text": "The old king is dead, they say, and the knights have left the border towers. Out here, at the edge of the kingdom, that is only a rumour."},
		{"fade": "in", "time": 1.5},
		{"say": "brenna", "text": "Morning already. One more stretch of road, and I'm home."},
		{"say": "brenna", "text": "No more orders. No more marching. Father won't believe it when I walk through the gate."},
		{"camera": r.at(r.game.player_village.center), "zoom": 0.8, "time": 3.5},
		{"wait": 0.4},
		{"say": "brenna", "text": "...Smoke?"},
		{"say": "brenna", "text": "The walls are down. Half the huts are burned. Gods, what happened here?"},
		{"say": "brenna", "text": "Father..."},
		{"camera": tent, "zoom": 1.0, "time": 1.5},
	]


func arrival(r: ScenarioRunner) -> Array[Dictionary]:
	return [
		{"camera": r.at(r.game.player_village.center), "zoom": 1.1, "time": 1.0},
		{"say": "einar", "text": "Brenna? Is that... my girl! Look at you, in a knight's steel!"},
		{"say": "brenna", "text": "Father! You're alive. What happened here?"},
		{"say": "einar", "text": "Goblins, out of the hills. Orks too. Nobody mans the old towers any more, so nothing stops them on the roads."},
		{"say": "einar", "text": "We lost the walls and half the huts. There's just the three of us left: me, the builder and the farmer."},
		{"say": "brenna", "text": "Then we rebuild. And nobody else dies here, Father. Not one."},
		{"say": "einar", "text": "That's my girl. The builder will follow your lead, and I'll keep the timber coming."},
		{"say": "", "text": "No villager may die in this scenario. Keep them safe, and keep them fed."},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var road := r.road_from(SOUTH_ROAD, 26)
	var cart_path: Array = road.slice(0, maxi(2, road.size() - 7))
	var stop: Vector2 = r.at(cart_path[-1]) if not cart_path.is_empty() else r.at(r.game.player_village.center)
	var cart := [null]
	return [
		{"do": func() -> void:
			r.dusk(4.0)
			for t in road:
				r.game.fog.reveal(Vector2(t), 2.0, r.game.player_village.id)
			if not cart_path.is_empty():
				var c := r.actor("unit_caravan", Vector2(cart_path[0]))
				var glow := Art.sprite("light_halo")  # (his lantern)
				glow.modulate = Color(1.0, 0.75, 0.4)
				glow.scale = Vector2(0.3, 0.6)  # (the ground glow made round and small)
				glow.position = Vector2(14, -34)
				var add := CanvasItemMaterial.new()
				add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				glow.material = add
				c.add_child(glow)
				r.move_actor(c, cart_path, 14.0)
				cart[0] = c},
		{"say": "", "text": "Evening falls over the mended walls. Out on the road, a lantern swings."},
		{"camera": stop + Vector2(0, -40), "zoom": 1.2, "time": 3.0},
		{"say": "brenna", "text": "A cart, at this hour? Alone, on that road?"},
		{"say": "brenna", "text": "That lantern... I know that lantern. Pell? Pell Dunmore!"},
		{"say": "pell", "text": "Brenna Hale, as I live and breathe! I heard the outpost had burned. Nobody told me you'd come home to put it back together."},
		{"say": "pell", "text": "Have you room for a tired old friend and his cart? I bring news. Not much of it good."},
		{"say": "brenna", "text": "For you, always. Come inside, Pell. The walls hold again."},
		{"fade": "out", "time": 1.5},
		{"do": func() -> void:
			if is_instance_valid(cart[0]):
				(cart[0] as Node).queue_free()},
	]


# --- the cards (the old tutorial's steps 1-7 and 11, and the rebuilding) -------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	var tower_tile := r.spots.by_road("tower", 3, 7, [])
	var farm_tile := r.spots.near_village("farm", [tower_tile] as Array[Vector2i])
	return [
		{"title": "Rebuild the huts",
			"text": "Only four of the nine huts stand. Every villager lives in a hut, so the huts decide how many people the village can have. Tap a ruined hut inside the walls and rebuild it.",
			"done": func() -> bool: return r.pieces("hut").any(func(h: Hut) -> bool: return not h.complete) or r.pieces("hut").filter(func(h: Hut) -> bool: return h.is_intact()).size() > huts_standing,
			"point": func() -> Dictionary: return {"tiles": _ruined_huts(r).slice(0, 1)}},
		{"title": "Watch the road",
			"text": "Enemies come along the roads. Build a watchtower on the marked spot: open the menu, Build tab, Watchtower, then tap the spot.",
			"done": func() -> bool: return not r.towers().is_empty(),
			"point": func() -> Dictionary: return r.place_point("tower", [r.spots.spot("tower", tower_tile)])},
		{"title": "Your builder at work",
			"text": "Your builder works through the jobs one at a time, the huts first. Villagers do their work on their own.",
			"done": func() -> bool: return r.towers().any(func(t: Tower) -> bool: return t.complete),
			"point": func() -> Dictionary: return {"tiles": r.first_tiles(r.towers())}},
		{"title": "Man the tower",
			"text": "Recruit an archer (Army tab) and drag it onto the tower.",
			"done": func() -> bool: return r.towers(true).any(func(t: Tower) -> bool: return t.garrison != null and t.garrison.state == MilitaryUnit.State.STATIONED),
			"point": func() -> Dictionary: return r.unit_point("archer", r.towers())},
		{"title": "Food",
			"text": "Every villager eats, and new villagers cost food. The top bar shows your food and how it changes per minute. At 0 food someone starves, so plan ahead: place a second farm on the marked field.",
			"done": func() -> bool: return r.farms().size() >= 2,
			"point": func() -> Dictionary: return r.place_point("farm", Building.footprint(r.spots.spot("farm", farm_tile), 3))},
		{"title": "The first wave",
			"text": "Ready? Start the first wave with Call now: calling early pays bonus gold. Your villagers run home when they see an enemy, but outside the walls they can be caught.",
			"done": func() -> bool: return g.waves.wave >= 1,
			"point": func() -> Dictionary: return {"hud": ["call"]}},
		{"title": "Gatherers", "id": "gatherers",
			"ready": func() -> bool: return g.corpses.count() > 0 or g.player_village.corpses_delivered > 0,
			"wait_text": "Here they come! Watch your archer on the tower.",
			"text": "Enemies leave corpses. A gatherer brings them home for gold and food. Recruit one in the Village tab (it needs a free hut).",
			"done": func() -> bool: return g.population.count("gatherer") > 0 and g.player_village.corpses_delivered > 0,
			"point": func() -> Dictionary: return {} if g.population.count("gatherer") > 0 else {"hud": ["village:gatherer", "tab:village", "dock"], "tab": "village"}},
		{"title": "Unit levels",
			"text": "Units get better with levels. Tap your archer on its tower and upgrade it: Upgrade, paid with gold.",
			"start": r.mark_units,
			"done": r.unit_promoted,
			"point": func() -> Dictionary: return {"units": g.army.stationed().filter(func(u: MilitaryUnit) -> bool: return is_instance_valid(u.post) and u.post.unit_rect(u).has_area())}},
		{"title": "Mend the walls",
			"text": "With the walls broken, enemies walk straight in. Gates and walls hold them for a while, and wall towers can be manned. Tap a broken gate, wall or wall tower and repair it.",
			"start": func() -> void: r.mark["repairs"] = _repairs_done(r),
			"done": func() -> bool: return _repairs_done(r) > int(r.mark["repairs"]) or _pieces_to_fix(r).any(func(b: Building) -> bool: return b.repairing),
			"point": func() -> Dictionary: return {"tiles": _pieces_to_fix(r).map(func(b: Building) -> Vector2i: return b.tile)}},
	]


func on_card_done(r: ScenarioRunner, id: String) -> void:
	if id == "gatherers":
		r.game.corpses.rot = true  # (the gatherer had wave 1's corpses; from now on they rot as usual)


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "fleeing",
			"when": func() -> bool: return _outside(r).any(func(c: Civilian) -> bool: return c.evading),
			"text": func() -> String: return "%s is in danger: villagers flee home when they see an enemy, but they can be caught on the way. Watch the roads where they work." % _who(_outside(r).filter(func(c: Civilian) -> bool: return c.evading))},
		{"id": "hurt",
			"when": func() -> bool: return g.population.civilians.any(func(c: Civilian) -> bool: return c.hp < c.max_hp and not c.dead),
			"text": "A villager is hurt! They heal at home. One more blow may be the last, and here a single death ends everything."},
		{"id": "food",
			"when": func() -> bool: return g.population.food_per_second() < 0.0 and g.economy.amount("food") < 60.0,
			"text": "Food is falling. At 0 food a villager starves every 15 seconds. Make sure every farm has its farmer, or build another farm."},
		{"id": "breach",
			"when": func() -> bool: return g.siege.breached(g.player_village.id),
			"text": "Enemies are inside the walls! They burn the huts, and whoever lives there dies. Repair the gates, walls and wall towers to keep them out."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "waves", "text": "Survive %d waves" % waves.size(),
			"done": func() -> bool: return g.waves.all_done(),
			"detail": func() -> String: return "%d / %d" % [g.waves.wave - (1 if g.waves.in_progress() else 0), waves.size()]},
		{"id": "huts", "text": "Rebuild every hut",
			"done": func() -> bool: return r.pieces("hut").all(r.whole),
			"detail": func() -> String: return "%d / %d" % [r.pieces("hut").filter(r.whole).size(), r.pieces("hut").size()]},
		{"id": "gates", "text": "Repair the gates",
			"done": func() -> bool: return r.pieces("gate").all(r.whole),
			"detail": func() -> String: return "%d / %d" % [r.pieces("gate").filter(r.whole).size(), r.pieces("gate").size()]},
		{"id": "walls", "text": "Repair the walls",
			"done": func() -> bool: return r.pieces("wall").all(r.whole),
			"detail": func() -> String: return "%d / %d" % [r.pieces("wall").filter(r.whole).size(), r.pieces("wall").size()]},
		{"id": "towers", "text": "Repair the wall towers",
			"done": func() -> bool: return r.pieces("wall_tower").all(r.whole),
			"detail": func() -> String: return "%d / %d" % [r.pieces("wall_tower").filter(r.whole).size(), r.pieces("wall_tower").size()]},
		{"id": "people", "text": "More villagers than at the start",
			"done": func() -> bool: return g.population.count() > r.start_villagers,
			"detail": func() -> String: return "%d / %d" % [g.population.count(), r.start_villagers + 1]},
		{"id": "food", "text": "Food not falling",
			"done": func() -> bool: return g.population.food_per_second() >= 0.0,
			"detail": func() -> String: return "%+d / min" % roundi(g.population.food_per_second() * 60.0)},
	]


func on_start(r: ScenarioRunner) -> void:
	if r.spots.spawn_tile != Vector2i(-1, -1):
		r.game.waves.scripted[0]["spawn"] = r.spots.spawn_tile  # (wave 1 on the watchtower's road)


func death_text(civ: Civilian, reason: String) -> String:
	var who := _who([civ])
	if civ.given_name == "Einar":
		who = "Einar, Brenna's father,"
	return "%s died %s. No villager may die in this scenario." % [who, reason]


# --- helpers -----------------------------------------------------------------------------

## The ruined huts nobody is rebuilding, nearest the village centre first.
func _ruined_huts(r: ScenarioRunner) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h: Hut in r.pieces("hut"):
		if h.ruined and h.complete:
			out.append(h.tile)
	var c := Vector2(r.game.player_village.center)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(c) < Vector2(b).distance_to(c))
	return out


## Gates, walls and wall towers that aren't whole.
func _pieces_to_fix(r: ScenarioRunner) -> Array:
	return _pieces(r).filter(func(b: Building) -> bool: return not r.whole(b))


func _repairs_done(r: ScenarioRunner) -> int:
	return _pieces(r).filter(r.whole).size()


func _pieces(r: ScenarioRunner) -> Array:
	return r.pieces("gate") + r.pieces("wall") + r.pieces("wall_tower")


## Villagers out in the field.
func _outside(r: ScenarioRunner) -> Array:
	return r.game.population.civilians.filter(func(c: Civilian) -> bool: return not c.at_home and not c.dead)


## "Einar" or "Your farmer" for the first of `list`.
func _who(list: Array) -> String:
	if list.is_empty():
		return "A villager"
	var c: Civilian = list[0]
	return c.given_name if c.given_name != "" else "Your %s" % c.display_name().to_lower()
