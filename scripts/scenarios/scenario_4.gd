extends Scenario
## Scenario 4: The Split (docs/scenarios-design.md §3.4, docs/story-design.md).
## Away from home for the first time: the Silver Thread Guild's walled market town
## on the coast. Its master, Wenna, keeps the books in the guild house; its
## warehouse stands by the harbour and must not fall while the convoy is
## loaded (nine waves). Crabs come out of the sea (only the sea), at most one
## siren; thieves in numbers, and they go for the warehouse (the Wilderness
## goes for the huts); more of them once the foreign coins are found (after
## wave 6). Before wave 4 a rival guild's master offers Brenna gold to
## leave (a choice: taking it loses the scenario); after wave 6 a captured
## Renegade carries coins of three foreign mints. Brenna can't be brought
## back here; Pell and Wenna must not die.


func _init() -> void:
	number = 4
	title = "The Split"
	blurb = "The Silver Thread Guild's last market town is under pressure. Hold it, and its harbour warehouse, until the convoy is loaded and away."
	map_path = "res://data/maps/guildtown.json"
	place = "guild_town"
	portrait = "portrait_wenna"

	# The baseline: the guild's town, its staff in the huts, the full guild
	# market, a small garrison; the warehouse by the harbour.
	difficulty = "easy"
	enemy_scale = {"hp": 0.9, "damage": 0.9, "spell_damage": 0.9}
	resources = {"gold": 200, "food": 170, "materials": 200}
	civilians = ["builder", "builder", "farmer", "farmer", "forester", "gatherer", "merchant", "guildmaster"]
	names = {"merchant": "Pell", "guildmaster": "Wenna"}
	homes = {"Wenna": {"art": "guild_house", "name": "Guild House"}}
	buildings = ["farm", "camp"]
	prebuilt = [
		{"kind": "warehouse", "near_water": true},
		{"kind": "stall", "road": 0, "at": [3, 7], "level": 3},
		{"kind": "barracks", "road": 0, "at": [7, 11], "units": [{"kind": "shield_bearer", "level": 3}]},
		{"kind": "tower", "road": 1, "at": [3, 6], "units": [{"kind": "archer", "level": 3}]},
		{"kind": "tower", "road": 2, "at": [3, 6], "units": [{"kind": "archer", "level": 2}]},
	]
	hero_name = "Brenna"
	hero_level = 5

	units = ["archer", "shield_bearer"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell", "Wenna"]
	must_stand = ["warehouse"]

	# Wilderness and Renegades in numbers (about 2.5 x a home wave): thieves
	# on every road, going for the warehouse. Crabs from wave 2 come out of
	# the sea; one siren, in wave 7. Once the foreign coins are found (after
	# wave 6) the paymasters send about twice the thieves.
	waves = [
		{"kinds": {"goblin": 12, "thief": 5}, "spawns": 2},
		{"kinds": {"goblin": 12, "crab": 4, "thief": 4}, "rat_packs": [5, 5], "spawns": 2},
		{"kinds": {"goblin": 12, "ork": 3, "thief": 6, "crab": 5}, "spawns": 3},
		{"kinds": {"goblin": 14, "ork": 4, "thief": 7}, "rat_packs": [6, 5], "spawns": 3},
		{"kinds": {"goblin": 14, "ork": 5, "crab": 6, "thief": 7, "slime3": 2}, "spawns": 3},
		{"kinds": {"goblin": 16, "ork": 5, "thief": 8, "crab": 5}, "rat_packs": [6, 6], "spawns": 3},
		{"kinds": {"goblin": 15, "ork": 6, "thief": 16, "crab": 6, "siren": 1}, "spawns": 3},
		{"kinds": {"goblin": 16, "ork": 6, "thief": 18, "crab": 6, "slime3": 3}, "rat_packs": [6, 6], "spawns": 3},
		{"kinds": {"goblin": 20, "ork": 8, "thief": 22, "crab": 8}, "rat_packs": [6, 6, 5], "spawns": 3},
	]
	amphibians_from_water = true
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 40.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"wenna": {"name": "Wenna", "portrait": "portrait_wenna", "color": Color("9ab8e0")},
		"rival": {"name": "A rival master", "portrait": "portrait_rival", "color": Color("d0a0c0")},
	}


## What the captured Renegade carried (after wave 6).
const COINS := "Taken from a captured Renegade:\n\nA purse of coins from three mints. A crowned head of Karmere. The sun-and-scales of the Republic of Lyrenne. The burning eye of the Holy Dominion of Aurelith.\n\nNo Renegade on this coast earns coin like that. Somebody beyond the border is paying for trouble in Veliron, and paying well."


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var store: Vector2 = r.at(_warehouse(r).tile) if _warehouse(r) else r.at(c)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": store + Vector2(0, -40), "zoom": 1.0, "time": 0.01},
		{"title": "The Split", "sub": "Scenario 4", "time": 3.0},
		{"say": "", "text": "The guild town on the coast. Half its harbour lies behind a rival guild's chains; the other half is all the Silver Thread Guild has left."},
		{"fade": "in", "time": 1.2},
		{"say": "pell", "text": "My old guild house. I kept the books there once, before the guild broke apart."},
		{"say": "wenna", "text": "Pell Dunmore. You took your time. And you brought a knight."},
		{"say": "pell", "text": "Wenna, master of the Silver Thread Merchant Guild. Brenna Hale, the best friend I have."},
		{"say": "wenna", "text": "The convoy is loading in the warehouse by the harbour. Everything we own is in it. If the warehouse falls, the guild falls with it."},
		{"say": "brenna", "text": "Then it won't fall. How long do you need?"},
		{"say": "wenna", "text": "Nine days, if the weather holds. Nine nights of whatever comes up the roads and out of the sea."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.0, "time": 2.0},
		{"say": "", "text": "Brenna is far from home: if she falls here, nobody can bring her back. Pell and Wenna must not die, and the warehouse must not fall."},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var store: Vector2 = r.at(_warehouse(r).tile) if _warehouse(r) else r.at(r.game.player_village.center)
	var road := r.road_in(r.game.player_village.center, 30)
	return [
		{"do": func() -> void:
			if road.size() > 8:
				var way := road.duplicate()
				way.reverse()
				var a := r.actor("unit_caravan", Vector2(way[0]))
				r.move_actor(a, way, 12.0)},
		{"camera": store + Vector2(0, -40), "zoom": 1.05, "time": 2.0},
		{"say": "", "text": "The convoy rolls out of the gate at dawn, heavy and slow, and the harbour is quiet behind it."},
		{"say": "wenna", "text": "The guild owes you, Brenna Hale. I don't say that often."},
		{"do": func() -> void: r.dusk(3.0)},
		{"camera": r.at(r.game.player_village.center) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "That night, by a candle in the guild house, Pell reads the ledger they took from the Renegades' leader."},
		{"say": "pell", "text": "Payments. Month after month, to a quartermaster of Rhodri's army. From three sources: Karmere, Lyrenne, Aurelith."},
		{"say": "brenna", "text": "All three? They're rivals. They'd never work together."},
		{"say": "pell", "text": "Then maybe one of them wants it to look that way. Either way, someone bought him."},
		{"say": "brenna", "text": "Rhodri's army left my company in the pass with no relief. I always told myself it was the war."},
		{"say": "brenna", "text": "I'm going back to the fort, Pell. I want to know why we were left behind."},
		{"fade": "out", "time": 1.5},
	]


## Between waves: Wenna on the guild's split; the rival's offer (before wave
## 4: a choice); the captured Renegade's coins (after wave 6).
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var c := r.game.player_village.center
	match n:
		1:
			r.play_scene([
				{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0},
				{"say": "brenna", "text": "Pell told me the guild broke apart in the war. How?"},
				{"say": "wenna", "text": "Every master had to choose. Most picked an heir: the old masters in the capital went for Rhodri and his army's contracts, the church towns for Fiona."},
				{"say": "wenna", "text": "A few of us tried to stay out of it. Trade with whoever pays, carry what's needed. That's the Silver Thread now: the ones who wouldn't choose. The Leftovers, the others call us."},
				{"say": "pell", "text": "And the others don't forgive us for it."},
			])
		3:
			var road := r.road_in(c, 14)
			var who := [null]
			r.play_scene([
				{"do": func() -> void:
					if road.size() > 4:
						who[0] = r.actor("unit_explorer", Vector2(road[0]))
						(who[0] as Node2D).modulate = Color(1.0, 0.8, 0.95)
						r.move_actor(who[0], road.slice(0, road.size() - 3), 5.0)},
				{"camera": r.at(road[road.size() - 4]) + Vector2(0, -40) if road.size() > 4 else r.at(c), "zoom": 1.1, "time": 2.0},
				{"wait": 2.5},
				{"say": "rival", "text": "Brenna Hale. A knight, guarding a storehouse for a guild that doesn't exist any more. What a waste."},
				{"say": "rival", "text": "My masters pay better than Wenna ever could. A purse of gold, and you ride home tonight. The town can fend for itself."},
				{"say": "brenna", "text": "And the warehouse?",
					"choices": [
						{"text": "Take the gold and leave", "do": func() -> void:
							_cleanup(who)
							r.lose("Brenna took the rival guild's gold and rode away. Without her the town fell, and the Silver Thread Guild with it.")},
						{"text": "Refuse", "do": func() -> void: pass},
					]},
				{"say": "brenna", "text": "Keep your gold. And tell your masters the warehouse has a guard now."},
				{"say": "rival", "text": "Pity. You'll find the roads less friendly from tonight."},
				{"do": func() -> void: _cleanup(who)},
				{"say": "wenna", "text": "Thank you. He's offered the same to every guard I had. Most of them took it."},
			])
		6:
			r.show_journal("Foreign coins", COINS)
			r.journal.closed.connect(func() -> void:
				r.play_scene([
					{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0},
					{"say": "pell", "text": "The gatherers caught one of the thieves alive. That purse was all he had on him."},
					{"say": "wenna", "text": "Three mints, and none of them ours. They pay Renegades to choke the last free market on the coast."},
					{"say": "brenna", "text": "Or someone wants us to think so. Keep the purse, Wenna. I'd like to know where it leads."},
					{"say": "wenna", "text": "Whoever it is, they know we've seen it now. They'll send more. Twice as many thieves, if I know paymasters."},
					{"do": func() -> void: r.game.events.info("The paymasters send more thieves: watch the warehouse")},
				]), CONNECT_ONE_SHOT)


func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n == 7:
		r.game.events.info("The convoy is being loaded: hold the warehouse")
		r.play_scene([
			{"say": "wenna", "text": "They're loading the convoy now. Three more nights. Keep them off the warehouse."},
		])


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "The warehouse",
			"text": "The guild's warehouse stands by the harbour, outside the walls. The monsters go for the huts, but thieves go for the warehouse: each one that gets there plunders it and runs off with gold, and nothing can mend it. Tap it to see its HP.",
			"done": func() -> bool: return _warehouse(r) == null or g.selected == _warehouse(r),
			"point": func() -> Dictionary: return {"tiles": [] if _warehouse(r) == null else _warehouse(r).tiles()}},
		{"title": "Guard the harbour",
			"text": "Crabs will come out of the sea, and the harbour road leads straight to the warehouse. Build a watchtower near it and station an archer there.",
			"done": func() -> bool: return _guarded(r),
			"point": func() -> Dictionary:
				var ts := r.towers().filter(func(t: Tower) -> bool: return _near_store(r, t))
				if ts.is_empty():
					return r.place_point("tower", [])
				return r.unit_point("archer", ts)},
		{"title": "Call the first wave",
			"text": "When you are ready, call the first wave. Brenna fights too, but here she can't be brought back: keep her out of the worst of it.",
			"done": func() -> bool: return g.waves.wave >= 1,
			"point": func() -> Dictionary: return {"hud": ["call"]}},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "crabs",
			"when": func() -> bool: return r.enemy_about("crab"),
			"text": "Crabs out of the sea! They swim and dive: under deep water nothing can hit them. Catch them when they come ashore."},
		{"id": "siren",
			"when": func() -> bool: return r.enemy_about("siren"),
			"text": "A siren! Her song pulls our people towards the water and slows every unit. Only ranged attacks reach her in the water."},
		{"id": "plundered",
			"when": func() -> bool: return _warehouse(r) != null and _warehouse(r).hp < _warehouse(r).max_hp(),
			"text": "The warehouse is plundered! It can't be repaired: every thief that gets there costs it for good. If it falls, the scenario is lost."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and here nobody can bring her back. Send her home to rest (her panel: Rest) until she has healed."},
		{"id": "thieves",
			"when": func() -> bool: return g.waves.wave >= 1 and r.enemy_about("thief"),
			"text": "Thieves on every road, and they're after the warehouse: each one that gets there plunders it and runs off with gold. Kill them on the way back to get the gold."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "waves", "text": "Hold until the convoy leaves",
			"done": func() -> bool: return g.waves.all_done(),
			"detail": func() -> String: return "%d / %d" % [g.waves.wave - (1 if g.waves.in_progress() else 0), waves.size()]},
		{"id": "store", "text": "Keep the warehouse standing",
			"done": func() -> bool: return _warehouse(r) != null and not _warehouse(r).devastated,
			"detail": func() -> String: return "" if _warehouse(r) == null else "%d %%" % roundi(100.0 * _warehouse(r).hp_share())},
	]


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell and Wenna must not die." % [civ.label().capitalize(), reason]


func fallen_text(_b: Building) -> String:
	return "The warehouse was plundered and lies in ruins. The convoy will never leave, and the Silver Thread Guild is finished."


# --- helpers -----------------------------------------------------------------------------

func _warehouse(r: ScenarioRunner) -> Warehouse:
	var list := r.pieces("warehouse")
	return list[0] if not list.is_empty() else null


func _near_store(r: ScenarioRunner, t: Building) -> bool:
	var w := _warehouse(r)
	return w != null and Vector2(t.tile).distance_to(Vector2(w.tile) + Vector2(0.5, 0.5)) <= 5.0


## A manned watchtower of ours near the warehouse.
func _guarded(r: ScenarioRunner) -> bool:
	return r.towers().any(func(t: Tower) -> bool: return _near_store(r, t) and t.complete and t.garrison != null)


func _cleanup(who: Array) -> void:
	if is_instance_valid(who[0]):
		(who[0] as Node).queue_free()
