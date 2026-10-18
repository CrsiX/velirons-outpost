extends Scenario
## Scenario 2: The Old Friend (docs/scenarios-design.md §3.2, docs/story-design.md).
## A few weeks later: the village stands again. Pell Dunmore, an old friend of
## Brenna's, comes up the road with his cart and wants to set up a stall. Once
## it stands the waves come: seven of them, Wilderness only. Between them Pell
## tells what became of the kingdom, and a stranger from a rival guild asks
## questions. Pell must not die. Teaches: placing a building (the stall),
## trade, the hero exploring (she claims the broken watchtower) and levelling
## up, barracks with a shield bearer, tower upgrades.


func _init() -> void:
	number = 2
	title = "The Old Friend"
	blurb = "Pell Dunmore, an old friend, comes up the road with his cart. Help him set up his stall, and hold the village while he tells you what became of the kingdom."
	map_path = "res://data/maps/homecoming.json"  # (home, as in scenario 1)

	# The baseline: the village rebuilt, a farm and a camp, two manned
	# watchtowers, no barracks yet; Pell lives in a hut; food is short.
	difficulty = "easy"
	enemy_scale = {"hp": 0.6, "damage": 0.6, "spell_damage": 0.6}
	resources = {"gold": 120, "food": 60, "materials": 110}
	civilians = ["builder", "farmer", "forester", "gatherer", "merchant"]
	names = {"forester": "Einar", "merchant": "Pell"}
	buildings = ["farm", "camp"]
	prebuilt = [
		{"kind": "tower", "road": 0, "at": [4, 7], "units": [{"kind": "archer", "level": 2}]},
		{"kind": "tower", "road": 1, "at": [4, 7], "units": [{"kind": "archer", "level": 1}]},
	]
	hero_name = "Brenna"
	hero_level = 2

	# Archers and shield bearers, no specialising yet; the stall is Pell's.
	units = ["archer", "shield_bearer"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "stall"]
	specialise = false
	must_live = ["Pell"]

	# Wilderness: goblins, orks, rats, slimes. Wave 4's rat packs test the
	# farm's defence. The first wave comes once the stall stands (on_card_done).
	waves = [
		{"kinds": {"goblin": 4}, "spawns": 1},
		{"kinds": {"goblin": 5}, "rat_packs": [4], "spawns": 2},
		{"kinds": {"goblin": 5, "ork": 1}, "spawns": 2},
		{"kinds": {"goblin": 4, "ork": 1}, "rat_packs": [6, 5], "spawns": 3},
		{"kinds": {"goblin": 6, "ork": 2, "slime3": 1}, "spawns": 2},
		{"kinds": {"goblin": 7, "ork": 2}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 8, "ork": 3, "slime3": 2}, "rat_packs": [5], "spawns": 3},
	]
	first_wave_waits = true
	first_wave_call = false
	wave_gap = 40.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"einar": {"name": "Einar", "portrait": "portrait_einar", "color": Color("a8c878")},
		"scout": {"name": "A stranger", "color": Color("a8b0b8")},
	}


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var gate := _north_gate(r)
	var cart := [null]
	return [
		{"fade": "out", "time": 0.01},
		{"camera": r.at(gate) + Vector2(0, -60), "zoom": 1.2, "time": 0.01},
		{"do": func() -> void:
			cart[0] = r.actor("unit_caravan", Vector2(gate + Vector2i(1, -2)))
			var p := Art.sprite("unit_merchant")
			p.position = Iso.to_world(Vector2(-0.6, 0.9))
			(cart[0] as Node2D).add_child(p)},
		{"title": "The Old Friend", "sub": "Scenario 2", "time": 3.0},
		{"say": "", "text": "A few weeks later. The huts stand again, the walls hold, and the north road has been quiet. Until a cart comes up it."},
		{"fade": "in", "time": 1.2},
		{"say": "pell", "text": "So this is the famous outpost. You did say it was the end of the world."},
		{"say": "brenna", "text": "Pell. You look like you walked here on an empty stomach."},
		{"say": "pell", "text": "Most of the way. The roads aren't kind to a lone cart any more."},
		{"say": "pell", "text": "I went looking for you in the capital, you know. Nobody there had seen you."},
		{"say": "brenna", "text": "I wasn't at the capital. That's all there is to tell. For now."},
		{"say": "pell", "text": "Then I won't ask. But if I'm to stay a while, I need a place to sell my wares. Where can I set up my stall?"},
		{"say": "", "text": "Pell must not die. Place his stall: once it stands, the first wave will not be far behind."},
		{"do": func() -> void:
			if is_instance_valid(cart[0]):
				(cart[0] as Node).queue_free()},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var at: Vector2 = r.at(r.stalls()[0].tile) if not r.stalls().is_empty() else r.at(r.game.player_village.center)
	return [
		{"do": func() -> void: r.dusk(3.0)},
		{"camera": at + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "The last of them lie in the road. By the stall, Pell counts what the rats left him."},
		{"say": "pell", "text": "You know why I really came, Brenna. The guild needs the road to the border town open again."},
		{"say": "pell", "text": "It's cut where the Wardline's towers used to stand. Nobody mans them now, so nobody gets through."},
		{"say": "brenna", "text": "The Wardline. I stood on it once."},
		{"say": "pell", "text": "Help me restore it, and my guild can send caravans. Food, timber, news. This place wouldn't be the end of the world any more."},
		{"say": "brenna", "text": "Then we start in the morning."},
		{"fade": "out", "time": 1.5},
	]


## Between waves, Pell talks (and once a stranger asks questions).
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	match n:
		1:
			r.play_scene([
				{"camera": r.at(r.game.player_village.center), "zoom": 1.1, "time": 1.0},
				{"say": "brenna", "text": "You said you'd tell me the news, Pell. All of it."},
				{"say": "pell", "text": "The old king is dead. Orsin. He never named an heir, and both his children wanted the crown."},
				{"say": "pell", "text": "Fiona, the elder, had the court mages and the church. Rhodri, the younger, had the army. They went to war over it."},
				{"say": "brenna", "text": "And the knights of the border went with them."},
				{"say": "pell", "text": "Every last one. That's why the roads are what they are."},
			])
		3:
			var road := r.road_in(r.game.player_village.center + Vector2i(0, -20), 16)
			var who := [null]
			r.play_scene([
				{"do": func() -> void:
					if road.size() > 4:
						who[0] = r.actor("unit_explorer", Vector2(road[0]))
						r.move_actor(who[0], road.slice(0, road.size() - 4), 6.0)},
				{"camera": r.at(road[road.size() - 5]) if road.size() > 4 else r.at(r.game.player_village.center), "zoom": 1.1, "time": 2.0},
				{"wait": 3.0},
				{"say": "scout", "text": "Good day. A trade stall, out here? Whose colours does your merchant fly?"},
				{"say": "pell", "text": "The neutral guild's. Same as ever."},
				{"say": "scout", "text": "The neutral guild. Is that what's left of it. And who supplies you, this far from anywhere?"},
				{"say": "brenna", "text": "Nobody you need to know. Buy something, or walk on."},
				{"say": "scout", "text": "Another time, perhaps."},
				{"do": func() -> void:
					if is_instance_valid(who[0]):
						(who[0] as Node).queue_free()},
				{"say": "pell", "text": "A rival guild's man. They're counting stalls now. That's never good."},
			])
		5:
			r.play_scene([
				{"camera": r.at(r.game.player_village.center), "zoom": 1.1, "time": 1.0},
				{"say": "brenna", "text": "That stranger. You said rival guild. Since when does the guild have rivals?"},
				{"say": "pell", "text": "Since the war. Every master picked an heir, or tried to stay out of it. The guild broke into pieces, and the pieces don't like each other."},
				{"say": "pell", "text": "What's left of us that stayed out is the neutral guild. Smaller every season."},
				{"say": "einar", "text": "Neutral, like this village. Maybe that's why we're both still standing."},
			])


# --- the cards (tutorial pieces: a building, trade, the hero, barracks, tower upgrades) ----------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	var stall_tile := r.spots.by_road("stall", 3, 8, [])
	var ruin: Dictionary = r.ruin_sites[0] if not r.ruin_sites.is_empty() else {}
	return [
		{"title": "Pell's stall", "id": "stall",
			"text": "Choose a place for Pell's stall: Build tab, Trade Stall, then the marked spot (or anywhere you like). Your builder puts it up, and Pell moves in.",
			"done": func() -> bool: return r.stalls().any(func(b: Stall) -> bool: return b.complete),
			"point": func() -> Dictionary: return r.place_point("stall", Building.footprint(r.spots.spot("stall", stall_tile), 2)) if r.stalls().is_empty() else {"tiles": r.first_tiles(r.stalls())}},
		{"title": "Trade",
			"text": "The stall stands, and the first wave is on its way. Tap Pell's stall and buy something with gold: building material or food. He has only a few goods, and new ones come slowly.",
			"done": func() -> bool: return r.stalls().any(func(b: Stall) -> bool: return b.sold > 0),
			"point": func() -> Dictionary: return {"tiles": r.first_tiles(r.stalls())}},
		{"title": "Brenna explores",
			"text": "Tap Brenna in the top bar and send her exploring. She uncovers the land, earns XP, and claims the broken watchtower out by the road.",
			"done": func() -> bool: return ruin.is_empty() or r.claimed(ruin),
			"point": func() -> Dictionary: return {} if g.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"]}},
		{"title": "Restore the watchtower",
			"text": "The ruin is yours. Tap it and restore it: a builder repairs it for half a watchtower's price. It has a part to play later.",
			"done": func() -> bool: return ruin.is_empty() or r.on_site(ruin) is Tower,
			"point": func() -> Dictionary: return {"tiles": [] if ruin.is_empty() else [ruin["tile"]]}},
		{"title": "Brenna's levels",
			"text": "Brenna has XP for a level: more HP and a harder sword. Level her up in her panel.",
			"start": func() -> void:
				r.mark["hero_level"] = g.hero.level
				_top_up_xp(r),
			"done": func() -> bool: return g.hero.level > int(r.mark["hero_level"]),
			"point": func() -> Dictionary:
				_top_up_xp(r)
				return {"hud": ["hero_level", "hero"]}},
		{"title": "Barracks",
			"text": "Barracks send their units out to fight what comes near: rats on the farm, too. Build one by the road and station a shield bearer on its bench.",
			"done": func() -> bool: return g.army.units.any(func(u: MilitaryUnit) -> bool: return u.post is Barracks and u.state == MilitaryUnit.State.STATIONED),
			"point": func() -> Dictionary:
				var bs := g.player_village.buildings().filter(func(b: Building) -> bool: return b is Barracks)
				if bs.is_empty():
					return r.place_point("barracks", Building.footprint(r.spots.spot("barracks", r.spots.by_road("barracks", 8, 13, [stall_tile] as Array[Vector2i])), 2))
				return r.unit_point("shield_bearer", bs)},
		{"title": "Tower upgrades",
			"text": "Towers can be upgraded: tap a watchtower and upgrade it. Its archer reaches further, and it takes more blows. Your builder does the work.",
			"done": func() -> bool: return r.towers(true).any(func(t: Tower) -> bool: return t.level >= 2),
			"point": func() -> Dictionary: return {"tiles": r.first_tiles(r.towers())}},
	]


func on_card_done(r: ScenarioRunner, id: String) -> void:
	if id == "stall":
		r.release_waves(45.0)
		r.game.events.info("Pell's stall stands. The first wave is coming")


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "pell",
			"when": func() -> bool: return r.merchant() != null and r.merchant().evading,
			"text": "Pell flees from an enemy! He's no fighter: keep the stall's road watched, and he must not die."},
		{"id": "rats",
			"when": func() -> bool: return g.player_village.buildings().any(func(b: Building) -> bool: return b is Farm and (b as Farm).has_rats()),
			"text": "Rats on the farm or the stall: they eat the food and Pell's goods. Barracks units and Brenna go after rats."},
		{"id": "food",
			"when": func() -> bool: return g.population.food_per_second() < 0.0 and g.economy.amount("food") < 40.0,
			"text": "Food is running low. A second farm, or food from Pell's stall, keeps everyone fed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "waves", "text": "Survive %d waves" % waves.size(),
			"done": func() -> bool: return g.waves.all_done(),
			"detail": func() -> String: return "%d / %d" % [g.waves.wave - (1 if g.waves.in_progress() else 0), waves.size()]},
		{"id": "stall", "text": "Keep Pell's stall standing",
			"done": func() -> bool: return r.stalls().any(func(b: Stall) -> bool: return b.working()),
			"detail": func() -> String: return "not built" if r.stalls().is_empty() else ("devastated: repair it" if r.stalls().all(func(b: Stall) -> bool: return b.devastated) else "being built")},
		{"id": "trade", "text": "Buy something from Pell", "optional": true,
			"done": func() -> bool: return r.stalls().any(func(b: Stall) -> bool: return b.sold > 0)},
	]


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

## The village's gate nearest the north road (where Pell comes in).
func _north_gate(r: ScenarioRunner) -> Vector2i:
	var gates: Array = r.game.player_village.gates
	var best: Vector2i = r.game.player_village.center
	for t: Vector2i in gates:
		if best == r.game.player_village.center or t.y < best.y:
			best = t
	return best


## The card on Brenna's levels: she gets the XP her next level costs, if she has less.
func _top_up_xp(r: ScenarioRunner) -> void:
	var h := r.game.hero
	if not h.dead and h.level == int(r.mark.get("hero_level", h.level)) and h.xp < h.level_up_cost():
		h.xp = h.level_up_cost()
		h.changed.emit()
