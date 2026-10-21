extends Scenario
## Scenario 9: The Drowned Abbey (docs/scenarios-design.md §3.9, §7.15). A
## pilgrims' ferry village on a drowned shore; out in the lake the church's
## old abbey stands half-sunk on its island, the road crossing to it on
## causeway bridges. The abbey's crypt holds the First King's Hand, a relic
## sword; vampires hold the crypt and a gigantic octopus guards the deep water
## beside it. The priests who stayed don't trust a knight of Rhodri's army:
## they hide, tell what the abbey hides only after wave 4, and unseal the crypt
## after wave 6, when the Legion has come down the causeway with Brenna's old
## captain Lysa. Taking the relic wakes the leviathan, and the Legion's rest
## comes with it. Bring the relic home, slay the leviathan, hold ten waves.
## Brenna can't be brought back; Pell must not die.


func _init() -> void:
	number = 9
	title = "The Drowned Abbey"
	blurb = "The church's old abbey stands half-sunk in a lake, and in its crypt lies the First King's Hand. The Legion wants it too."
	map_path = "res://data/maps/drowned_abbey.json"
	place = "abbey"
	portrait = "portrait_church_priest"

	# The baseline: a ferry village of fishers and the church's last priests
	# (who hide in their house), some walls down, a small barracks, towers by
	# the water, Pell's wagon; two of the band in the reserve.
	difficulty = "easy"
	enemy_scale = {"hp": 1.15, "damage": 1.15, "spell_damage": 1.15}
	resources = {"gold": 300, "food": 170, "materials": 260}
	civilians = ["builder", "builder", "farmer", "forester", "gatherer", "merchant", "priest", "priest"]
	names = {"merchant": "Pell"}
	buildings = ["farm", "camp"]
	huts_standing = 9
	pieces_standing = {"wall": 6, "gate": 3, "wall_tower": 3}
	pieces_hp = 0.8
	prebuilt = [
		{"kind": "stall", "road": 1, "at": [3, 7], "level": 1},
		{"kind": "barracks", "road": 1, "at": [5, 9], "level": 2, "units": [{"kind": "shield_bearer", "level": 7}, {"kind": "archer", "level": 6}]},
		{"kind": "tower", "road": CAUSEWAY_ROAD, "at": [3, 5], "units": [{"kind": "archer", "level": 7}]},
		{"kind": "tower", "road": 2, "at": [3, 5], "units": [{"kind": "apprentice", "level": 6}]},
		{"kind": "wall_tower", "road": CAUSEWAY_ROAD, "units": [{"kind": "archer", "level": 6}]},
	]
	reserve = [{"kind": "summoner", "level": 6}, {"kind": "acolyte", "level": 6}]
	hero_name = "Brenna"
	hero_level = 14

	units = ["archer", "shield_bearer", "apprentice", "acolyte", "summoner"]
	unlocked = ["apprentice", "acolyte", "summoner"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell"]

	# Crabs out of the water first, then the drowned dead and the Evil; the
	# Legion from wave 6 (its column down the causeway is added then). After
	# the tenth the last comes again until the relic is home and the
	# leviathan dead.
	waves = [
		{"kinds": {"crab": 4, "goblin": 3}, "spawns": 2},
		{"kinds": {"crab": 5, "goblin": 4}, "rat_packs": [5], "spawns": 2},
		{"kinds": {"crab": 5, "goblin": 4, "skeleton": 3}, "spawns": 3},
		{"kinds": {"crab": 4, "goblin": 4, "skeleton": 4, "necromancer": 1}, "spawns": 3},
		{"kinds": {"crab": 4, "goblin": 4, "skeleton": 5, "vampire": 1, "gargoyle": 1}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"crab": 4, "goblin": 4, "skeleton": 5, "necromancer": 1, "vampire": 1}, "spawns": 3},
		{"kinds": {"crab": 5, "goblin": 5, "skeleton": 6, "vampire": 2, "gargoyle": 1, "legion_footman": 3}, "spawns": 3},
		{"kinds": {"crab": 5, "goblin": 5, "skeleton": 6, "necromancer": 1, "vampire": 2, "gargoyle": 2, "legion_footman": 3, "legion_archer": 2}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"crab": 6, "goblin": 5, "skeleton": 7, "vampire": 2, "gargoyle": 2, "siren": 1, "legion_footman": 4, "legion_archer": 2, "legion_banner": 1}, "spawns": 3},
		{"kinds": {"crab": 6, "goblin": 6, "skeleton": 7, "necromancer": 2, "vampire": 2, "gargoyle": 2, "legion_footman": 4, "legion_guard": 2, "legion_archer": 2, "legion_banner": 1}, "spawns": 3},
	]
	repeat_last = true
	more_each_wave = {"crab": 1, "skeleton": 1}
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"eldest": {"name": "The eldest priest", "portrait": "portrait_eldest_priest", "color": Color("e0d4b8")},
		"lysa": {"name": "Lysa", "portrait": "portrait_lysa", "color": Color("c8ccd8")},
	}


## The road that crosses the lake (road_spots' order: 0 is the nearest).
const CAUSEWAY_ROAD := 0
## The relic, as the treasure's item.
const RELIC := "the First King's Hand"
## The waves the story needs: the priests tell, the Legion comes, the crypt opens.
const TELL_WAVE := 4
const LEGION_WAVE := 6
const HOLD := 10
## Pell's guild boats bring supplies after these waves.
const BOAT_WAVES: Array[int] = [2, 5, 8]
const BOAT := {"food": 60, "materials": 80, "gold": 40}
## The guard octopus: its HP x this, and how far from the abbey it keeps.
const GUARD_HP := 1.5
const GUARD_LEASH := 6.0
## The leviathan the relic wakes: HP and damage x these.
const LEVIATHAN_HP := 5.0
const LEVIATHAN_POWER := 1.5
## The drowned dead lying on the island.
const DROWNED := 8
## The Legion down the causeway at wave 6, and its rest with the leviathan.
const LEGION_COLUMN := {"legion_footman": 5, "legion_archer": 2, "legion_banner": 1, "legion_guard": 1}
const LEGION_REST := {"legion_footman": 6, "legion_archer": 3, "legion_banner": 1, "legion_guard": 2}


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var ab := _abbey(r)
	var abbey: Vector2 = Vector2(ab.tile) if ab else Vector2(c)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": r.at(abbey) + Vector2(0, -60), "zoom": 0.95, "time": 0.01},
		{"title": "The Drowned Abbey", "sub": "Scenario 9", "time": 3.0},
		{"say": "", "text": "Mist on the delta. Brenna and Pell come over the water on the ferry. Out in the lake the abbey's spires stand up out of it, and somewhere under them a bell rings."},
		{"fade": "in", "time": 1.4},
		{"say": "pell", "text": "The guild's boats will come by when they can. Out here they're the only road that's safe."},
		{"say": "brenna", "text": "And the priests?"},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 2.5},
		{"say": "", "text": "The village's priests take one look at Brenna's colours and shut their door. Nobody says a word about the abbey."},
		{"say": "pell", "text": "You're one of Rhodri's knights, as far as they can see. Give them time."},
		{"say": "", "text": "Hold the village for %d waves and win the priests' trust. Brenna can't be brought back here, and Pell must not die." % HOLD},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var ab := _abbey(r)
	var abbey: Vector2 = Vector2(ab.tile) if ab else Vector2(c)
	return [
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "The priests come out of their house, all of them, for the first time since Brenna came."},
		{"say": "eldest", "text": "We took you for one of his. We were wrong. You stood on our shore against your own company, and against the deep."},
		{"say": "eldest", "text": "The Hand goes to Fiona. Take it to her."},
		{"say": "", "text": "In Brenna's hands the old sword glows, faintly, like a coal under ash."},
		{"camera": r.at(abbey) + Vector2(0, -40), "zoom": 1.05, "time": 2.5},
		{"say": "", "text": "On the causeway Lysa stops on her way back into the mist, and turns. For a moment her eyes are her own."},
		{"say": "lysa", "text": "Hale. We were only to hold you here. Halvard has the main force. He's marching on your home."},
		{"say": "lysa", "text": "Go home, Brenna. Before I ..."},
		{"say": "", "text": "The pallor comes back over her face like a tide, and she walks on into the mist."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "brenna", "text": "Pell. We have to go back."},
		{"say": "pell", "text": "The boats are ready."},
		{"fade": "out", "time": 1.5},
	]


## The story between the waves: Pell's boats, the priests, the crypt opened.
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var g := r.game
	var c := g.player_village.center
	if n >= HOLD:
		r.mark["held"] = true
	if n in BOAT_WAVES:
		for k: String in BOAT:
			g.economy.add(k, int(BOAT[k]), "trade")
		g.world.float_text("+%d {gold} +%d {food} +%d {materials}" % [BOAT["gold"], BOAT["food"], BOAT["materials"]], Iso.to_world(Vector2(c)) + Vector2(0, -60), UiTheme.GOLD)
		g.events.info("Pell's guild boats bring %d gold, %d food and %d material" % [BOAT["gold"], BOAT["food"], BOAT["materials"]])
	var lines: Array[Dictionary] = []
	match n:
		1:
			lines = [
				{"say": "pell", "text": "The priests watched the whole fight from their window. That's something."},
				{"say": "brenna", "text": "They're afraid of me."},
				{"say": "pell", "text": "They're afraid of what you wore. It isn't the same."},
			]
		TELL_WAVE:
			r.mark["told"] = true
			lines = [
				{"say": "", "text": "The eldest of the priests comes to the gate at last, and keeps her distance."},
				{"say": "eldest", "text": "You want to know what the abbey hides. The First King's Hand: his own sword, a relic. We hid it there and let the water in over it, before the war."},
				{"say": "brenna", "text": "Why hide it from your own side?"},
				{"say": "eldest", "text": "We are with Fiona. But we feared he could rise over her. What he would do with it, we couldn't bear to think."},
				{"say": "eldest", "text": "Its crypt is sealed, and vampires nest in it now. And in the deep water beside it lives something bigger. That is all I will say."},
			]
		LEGION_WAVE:
			r.mark["unsealed"] = true
			var ab := _abbey(r)
			if ab:
				ab.sealed = false
				ab.refresh()
			g.events.info("The priests have unsealed the abbey's crypt")
			lines = [
				{"say": "eldest", "text": "We saw you refuse her. Your own captain."},
				{"say": "eldest", "text": "The Legion knows where the Hand lies. Better you than them: we've unsealed the crypt. But the sword is not yours to keep, knight."},
				{"say": "brenna", "text": "I don't want it. I want it out of their reach."},
			]
	if lines.is_empty():
		return
	var scene: Array[Dictionary] = [{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0}]
	scene.append_array(lines)
	r.play_scene(scene)


## Wave 6: the Legion comes down the causeway, led by Lysa.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n != LEGION_WAVE:
		return
	var at := _causeway_spawn(r)
	_send_legion(r, LEGION_COLUMN, at)
	var ab := _abbey(r)
	r.play_scene([
		{"camera": r.at(ab.tile if ab else r.game.player_village.center) + Vector2(0, -40), "zoom": 1.0, "time": 2.0},
		{"say": "", "text": "Over the causeway a column marches out of the mist, past the abbey, in step. At its head a captain with a crimson plume."},
		{"say": "lysa", "text": "The relic. Give it up, and the village is spared."},
		{"say": "brenna", "text": "Lysa. It's me. Hale. You sent me down the pass, the night before ..."},
		{"say": "lysa", "text": "The relic."},
		{"say": "brenna", "text": "No. Not to you, and not to him."},
	])


## The relic leaves the abbey: the leviathan rises, and the Legion's rest
## comes with it. The leviathan slain: the priests agree.
func on_poll(r: ScenarioRunner) -> void:
	var g := r.game
	var ab := _abbey(r)
	if ab and ab.looted and not r.mark.has("risen"):
		r.mark["risen"] = true
		if not g.waves.in_progress():
			g.waves.start_now()  # (the leviathan's wave comes at once)
		r.add_enemies("leviathan", _lake_spawn(r), 1, {"name": "Leviathan", "hp_x": LEVIATHAN_HP, "power": LEVIATHAN_POWER})
		_send_legion(r, LEGION_REST, _causeway_spawn(r))
		g.events.important("The relic has left the abbey: the leviathan rises!")
		r.play_scene([
			{"camera": r.at(ab.tile) + Vector2(0, -40), "zoom": 1.0, "time": 1.5},
			{"say": "", "text": "As the sword leaves the crypt the bell under the water stops. The lake heaves, and something long and dark rises out of it."},
			{"say": "pell", "text": "Brenna! Get off that island!"},
		])
		return
	if r.mark.has("risen") and not r.mark.has("slain"):
		if not r.mark.has("leviathan"):
			var found := r.named_enemy("Leviathan")
			if found != null:
				r.mark["leviathan"] = found
		var lev = r.mark.get("leviathan")
		if lev != null and (not is_instance_valid(lev) or (lev as Enemy).dead):
			r.mark["slain"] = true
			g.events.info("The leviathan is slain")
			r.play_scene([
				{"say": "", "text": "The leviathan sinks, and does not come up again. The lake goes still."},
				{"say": "eldest", "text": "Knight. When this is over, come to our door."},
			])


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "A watch on the water",
			"text": "Crabs climb out of the sea and the lake. Build a watchtower by the water so it covers the shore, and man it.",
			"done": func() -> bool: return r.towers().any(func(t: Building) -> bool: return (t as Tower).garrison != null and _by_water(r, t.tile)),
			"point": func() -> Dictionary: return r.place_point("tower", [])},
		{"title": "The guardian",
			"text": "A gigantic octopus guards the deep water beside the abbey. Its arms grab whoever comes near and drag them under, Brenna too. Towers on the shore can wear it down (level 3 reaches farthest); it doesn't count for the waves.",
			"ready": func() -> bool: return r.mark.has("told"),
			"wait_text": "The priests say nothing yet. Hold the village.",
			"done": func() -> bool: return r.mark.has("unsealed") or not is_instance_valid(r.mark.get("octopus")) or (r.mark["octopus"] as Enemy).dead,
			"point": func() -> Dictionary:
				var o = r.mark.get("octopus")
				return {"tiles": [(o as Enemy).current_tile()] if is_instance_valid(o) else []}},
		{"title": "The First King's Hand",
			"text": "The crypt is open. Clear the vampires at the abbey (tap their camp: Attack with the hero), then send Brenna exploring: she takes the relic and carries it home. Taking it will wake something in the lake.",
			"ready": func() -> bool: return r.mark.has("unsealed"),
			"wait_text": "The priests keep the crypt sealed for now.",
			"done": func() -> bool: return g.player_village.items.has(RELIC),
			"point": func() -> Dictionary:
				var ab := _abbey(r)
				var tiles: Array = [ab.tile] if ab else []
				if ab and ab.guard() != null:
					tiles.append(ab.guard().tile)
				return {"tiles": tiles} if g.hero.mode == Hero.Mode.EXPLORE or (ab and ab.guard() != null) else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"], "tiles": tiles}},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "crab",
			"when": func() -> bool: return r.enemy_about("crab"),
			"text": "Crabs swim through the water and come up on the shore. Under water they can't be hit."},
		{"id": "grabbed",
			"when": func() -> bool: return g.get_tree().get_nodes_in_group("enemies").any(func(e: Node) -> bool: return (e as Enemy).kind == "octopus_arm"),
			"text": "The octopus has someone in its arm! Cut the arm (it's a target of its own) before they're dragged into the deep."},
		{"id": "necromancer",
			"when": func() -> bool: return r.enemy_about("necromancer"),
			"text": "A necromancer: it raises the drowned dead on the island. Acolytes' holy light hurts it most."},
		{"id": "vampire",
			"when": func() -> bool: return r.enemy_about("vampire"),
			"text": "A vampire: it heals from its hits, and beaten it becomes a bat for a while that only ranged attacks reach."},
		{"id": "legion",
			"when": func() -> bool: return r.enemy_about("legion_banner") or r.enemy_about("legion_archer"),
			"text": "The Legion: kill its banner-bearer first (the soldiers near it strike faster); its archers shoot our people in the open."},
		{"id": "siren",
			"when": func() -> bool: return r.enemy_about("siren"),
			"text": "A siren sings from the water: our people are drawn to her and fight slower. Towers and ranged units reach her."},
		{"id": "leviathan",
			"when": func() -> bool: return r.mark.has("risen"),
			"text": "The leviathan blasts whoever is near the water from 4.6 tiles: only level 3 watchtowers and wall towers outrange it. The wave ends only when it is dead."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and here nobody can bring her back. Send her to rest (her panel: Rest) until she has healed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "relic", "text": "Bring the First King's Hand home",
			"done": func() -> bool: return g.player_village.items.has(RELIC),
			"detail": func() -> String: return "sealed" if not r.mark.has("unsealed") else ("in the abbey" if not r.mark.has("risen") else ("home" if g.player_village.items.has(RELIC) else "on the way"))},
		{"id": "leviathan", "text": "Slay the leviathan",
			"done": func() -> bool: return r.mark.has("slain")},
		{"id": "waves", "text": "Hold the village for %d waves" % HOLD,
			"done": func() -> bool: return r.mark.has("held"),
			"detail": func() -> String: return "%d / %d" % [mini(g.waves.wave - (1 if g.waves.in_progress() else 0), HOLD), HOLD]},
	]


## The abbey sealed, holding the relic; the guard octopus in the deep water
## beside it; the drowned dead on the island.
func on_start(r: ScenarioRunner) -> void:
	var g := r.game
	var ab := _abbey(r)
	if ab == null:
		return
	ab.sealed = true
	ab.data["reward"] = {"item": RELIC}
	g.fog.reveal(Vector2(ab.tile), 4.0, g.player_village.id)
	var water := _deep_by(r, ab.tile, GUARD_LEASH)
	if not water.is_empty():
		var o := g.waves.spawn_at("octopus", water[0], g.player_village, 1)
		if o:
			o.post = ab.tile
			o.post_leash = GUARD_LEASH
			o.max_hp *= GUARD_HP
			o.hp = o.max_hp
			r.mark["octopus"] = o
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var placed := 0
	for i in 200:
		if placed >= DROWNED:
			break
		var t := ab.tile + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		if g.map.is_passable(t) and not g.map.is_road(t) and not g.map.buildings.has(t) and not g.map.is_water(t):
			g.corpses.spawn_fallen(Vector2(t) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))
			placed += 1


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

## The drowned abbey (the map's abbey treasure), or null.
func _abbey(r: ScenarioRunner) -> Treasure:
	for o in r.game.world.map_objects:
		if o is Treasure and str((o as Treasure).data.get("treasure", "")) == "abbey":
			return o
	return null


## Deep tiles within `reach` of `t`, nearest first.
func _deep_by(r: ScenarioRunner, t: Vector2i, reach: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var k := ceili(reach)
	for dy in range(-k, k + 1):
		for dx in range(-k, k + 1):
			var q := t + Vector2i(dx, dy)
			if r.game.map.is_deep(q) and Vector2(q).distance_to(Vector2(t)) <= reach:
				out.append(q)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(Vector2(t)) < Vector2(b).distance_to(Vector2(t)))
	return out


## The lake's water spawn (the one nearest the abbey), where the leviathan rises.
func _lake_spawn(r: ScenarioRunner) -> Vector2i:
	var ab := _abbey(r)
	var best := Vector2i(-1, -1)
	for t in r.game.map.water_spawns:
		if best.x < 0 or (ab and Vector2(t).distance_to(Vector2(ab.tile)) < Vector2(best).distance_to(Vector2(ab.tile))):
			best = t
	if best.x < 0 and ab:
		var deep := _deep_by(r, ab.tile, 9.0)
		if not deep.is_empty():
			best = deep[-1]
	return best


## The edge spawn of the road over the causeway.
func _causeway_spawn(r: ScenarioRunner) -> Vector2i:
	var ab := _abbey(r)
	return r.spawn_near(ab.tile if ab else r.game.player_village.center)


## Legion soldiers for the wave under way from `at`, with Lysa at their head.
func _send_legion(r: ScenarioRunner, band: Dictionary, at: Vector2i) -> void:
	r.add_enemies("legion_captain", at, 1, {"name": "Lysa", "art": "legion_captain_lysa"})
	for kind: String in band:
		r.add_enemies(kind, at, int(band[kind]))


## A tile within 3 of deep water.
func _by_water(r: ScenarioRunner, t: Vector2i) -> bool:
	return not _deep_by(r, t, 3.0).is_empty()
