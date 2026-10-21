extends Scenario
## Scenario 11: The Crown (docs/scenarios-design.md §3.11, §7.18). The
## capital's streets by the throne hall: cobbles and ash, a few trees, no
## fields. Brenna's and Fiona's forces hold a final camp while the waves come,
## the Dread Legion at full strength and everything else Rhodri has drawn to
## him. Fiona's mages hold the camp's ward on their towers; food comes only by
## caravan and from Pell. In the last wave Rhodri himself comes out of the
## throne hall with Lothar: beaten, he isn't killed but flees back inside, and
## the outro ends the campaign. Brenna can't be brought back; Pell and Fiona
## must not die.


func _init() -> void:
	number = 11
	title = "The Crown"
	blurb = "The final camp in the capital's streets, before the throne hall. Hold until Rhodri himself comes out, and beat him."
	map_path = "res://data/maps/capital.json"
	place = "capital"
	portrait = "portrait_rhodri"

	# The baseline: a camp in the streets inside a broken wall, Fiona in her
	# house, Pell's stall, Fiona's mages on the towers (they take no orders),
	# the army that came with Brenna. No farms here.
	difficulty = "easy"
	enemy_scale = {"hp": 1.25, "damage": 1.2, "spell_damage": 1.2}
	resources = {"gold": 520, "food": 240, "materials": 380}
	civilians = ["builder", "builder", "forester", "forester", "gatherer", "gatherer", "merchant", "princess"]
	names = {"merchant": "Pell", "princess": "Fiona"}
	homes = {"Fiona": {"art": "fiona_house", "name": "Fiona's House"}}
	buildings = []  # (no trees by the walls: the camp goes up by a grove)
	huts_standing = 9
	pieces_standing = {"wall": 5, "gate": 3, "wall_tower": 2}
	pieces_hp = 0.7
	prebuilt = [
		{"kind": "stall", "road": 1, "at": [3, 7], "level": 2},
		{"kind": "barracks", "road": 0, "at": [5, 9], "level": 3,
			"units": [{"kind": "warrior", "level": 7}, {"kind": "halberdier", "level": 6}, {"kind": "inquisitor", "level": 6}]},
		{"kind": "tower", "road": 0, "at": [3, 5], "level": 2, "units": [{"kind": "fire_mage", "level": 7, "fixed": true}]},
		{"kind": "tower", "road": 1, "at": [3, 5], "level": 2, "units": [{"kind": "ice_mage", "level": 7, "fixed": true}]},
		{"kind": "tower", "road": 2, "at": [3, 5], "level": 2, "units": [{"kind": "healing_mage", "level": 6, "fixed": true}]},
		{"kind": "wall_tower", "road": 0, "units": [{"kind": "crossbowman", "level": 7}]},
		{"kind": "wall_tower", "road": 1, "units": [{"kind": "archer", "level": 8}]},
	]
	reserve = [
		{"kind": "archer", "level": 6}, {"kind": "shield_bearer", "level": 6}, {"kind": "acolyte", "level": 6},
		{"kind": "summoner", "level": 6}, {"kind": "apprentice", "level": 6},
	]
	hero_name = "Brenna"
	hero_level = 18

	unlocked = ["apprentice", "acolyte", "summoner"]
	build = ["tower", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell", "Fiona"]

	# Everything, the Legion at full strength; Rhodri comes out in the last.
	waves = [
		{"kinds": {"skeleton": 6, "vampire": 1, "legion_footman": 4, "legion_archer": 1}, "spawns": 3},
		{"kinds": {"goblin": 6, "ork": 2, "witch": 1, "legion_footman": 5, "legion_cavalry": 1, "legion_archer": 2}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"skeleton": 6, "necromancer": 1, "gargoyle": 2, "legion_footman": 5, "legion_cavalry": 1, "legion_guard": 1, "legion_banner": 1}, "spawns": 3},
		{"kinds": {"goblin": 6, "thief": 2, "vampire": 2, "spider_mother": 1, "legion_footman": 6, "legion_cavalry": 1, "legion_archer": 2}, "spawns": 3},
		{"kinds": {"skeleton": 8, "witch": 2, "slime3": 2, "legion_footman": 6, "legion_cavalry": 2, "legion_guard": 2, "legion_archer": 2, "legion_banner": 1}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"ork": 4, "vampire": 2, "necromancer": 2, "gargoyle": 2, "legion_footman": 7, "legion_cavalry": 2, "legion_guard": 2, "legion_archer": 3, "legion_banner": 1}, "spawns": 3},
		{"kinds": {"goblin": 8, "thief": 3, "spider_mother": 1, "witch": 2, "legion_footman": 8, "legion_cavalry": 2, "legion_guard": 2, "legion_archer": 3, "legion_banner": 1}, "spawns": 3},
		{"kinds": {"skeleton": 8, "vampire": 3, "gargoyle": 3, "legion_footman": 8, "legion_cavalry": 2, "legion_guard": 3, "legion_archer": 4, "legion_banner": 2}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"ork": 5, "necromancer": 2, "witch": 3, "slime3": 2, "legion_footman": 9, "legion_cavalry": 3, "legion_guard": 3, "legion_archer": 4, "legion_banner": 2}, "spawns": 3},
		{"kinds": {"skeleton": 10, "vampire": 3, "spider_mother": 1, "gargoyle": 3, "legion_footman": 10, "legion_cavalry": 3, "legion_guard": 3, "legion_archer": 5, "legion_banner": 2}, "spawns": 3},
		{"kinds": {"goblin": 8, "ork": 5, "vampire": 4, "necromancer": 2, "legion_footman": 11, "legion_cavalry": 3, "legion_guard": 4, "legion_archer": 5, "legion_banner": 2}, "rat_packs": [7], "spawns": 3},
		{"kinds": {"skeleton": 10, "vampire": 4, "gargoyle": 4, "witch": 3, "legion_footman": 12, "legion_cavalry": 4, "legion_guard": 5, "legion_archer": 6, "legion_banner": 3}, "spawns": 3},
	]
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"fiona": {"name": "Fiona", "portrait": "portrait_fiona", "color": Color("9ab8f0")},
		"cursed": {"name": "Fiona", "portrait": "portrait_fiona_cursed", "color": Color("b890c8")},
		"rhodri": {"name": "Rhodri", "portrait": "portrait_rhodri", "color": Color("b8c0d8")},
		"lothar": {"name": "Lothar", "portrait": "portrait_lothar", "color": Color("d8d4e4")},
	}


## The waves the story needs, and the last one.
const VOICE_WAVE := 4
const COURT_WAVE := 8
const HOLD := 12
## A food caravan after every wave (no farms here).
const CARAVAN := {"food": 70, "materials": 30}
## Rhodri and Lothar: HP scales; the court that comes out with them.
const RHODRI_HP := 1.0
## Rhodri rides out, and fights on on foot once his horse falls
## (docs/enemies-design.md §15e): its HP.
const RHODRI_HORSE_HP := 350.0
const LOTHAR_HP := 0.8
const COURT := {"legion_guard": 3, "legion_banner": 1}


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var hall := _hall_tile(r)
	return [
		{"fade": "out", "time": 0.01},
		{"do": func() -> void: r.dusk(0.01)},
		{"camera": r.at(c) + Vector2(0, -50), "zoom": 0.95, "time": 0.01},
		{"title": "The Crown", "sub": "Scenario 11", "time": 3.0},
		{"say": "", "text": "The capital. In the burned streets below the throne hall, Brenna's and Fiona's people have made their last camp."},
		{"fade": "in", "time": 1.4},
		{"say": "brenna", "text": "Fiona. This is yours."},
		{"say": "", "text": "Brenna holds out the First King's Hand. Fiona takes it, and for a moment it glows in her hands like a coal."},
		{"say": "fiona", "text": "My grandfather's grandfather's. My brother never held it. He wasn't allowed to."},
		{"say": "fiona", "text": "My mages hold the ward on the towers. Keep them standing, and keep me standing, and we will see whether the old stories are true."},
		{"say": "pell", "text": "And I keep everyone fed. There's not a field in this city. The guild's carts will come when they can."},
		{"camera": r.at(hall) + Vector2(0, -60), "zoom": 0.95, "time": 3.0},
		{"say": "", "text": "In the throne hall Rhodri sits on his father's throne, the reworked crown cold on his brow, his pale court around him. He hears the camp, far below."},
		{"say": "", "text": "He smiles."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 2.5},
		{"say": "", "text": "Hold the camp for %d waves; in the last, Rhodri will come out. Beat him. Brenna can't be brought back, and Pell and Fiona must not die." % HOLD},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var hall := _hall_tile(r)
	var door := Vector2(hall) + Vector2(1.0, 3.2)
	return [
		{"do": func() -> void: r.dusk(2.0)},
		{"camera": r.at(hall) + Vector2(0, -40), "zoom": 1.1, "time": 2.5},
		{"say": "", "text": "The throne hall is empty but for him. His court is gone; his Legion lies in the streets. Rhodri sits on the steps below the throne, alone."},
		{"do": func() -> void: r.mark["actors"] = [r.actor("unit_legion_king", door + Vector2(0.6, -0.6)), r.actor("unit_princess", door + Vector2(-0.8, 0.8))]},
		{"say": "", "text": "Fiona walks in with the First King's Hand."},
		{"say": "rhodri", "text": "Sister. You came."},
		{"say": "fiona", "text": "Rhodri. Look at me. Is anything of you still in there?"},
		{"say": "rhodri", "text": "A little. Enough to be sorry. It is so heavy, Fiona. I only wanted to keep them all safe."},
		{"say": "rhodri", "text": "Do it. Please. While I'm still the one asking."},
		{"say": "", "text": "Fiona raises the old sword, and brings it down."},
		{"do": func() -> void:
			Combat.burst(r.game, "curse", r.at(door), 3.0)
			var a: Array = r.mark.get("actors", [])
			if not a.is_empty() and is_instance_valid(a[0]):
				(a[0] as Node).queue_free()},
		{"say": "", "text": "The crown falls to the floor and breaks into many pieces. Out of them something dark spills across the stones, finds Fiona, and runs into her, through her whole body."},
		{"do": func() -> void: Combat.burst(r.game, "curse", r.at(door + Vector2(-0.8, 0.8)), 1.6)},
		{"say": "", "text": "She lets go of the sword. It rings on the floor."},
		{"say": "cursed", "text": "..."},
		{"say": "", "text": "When she looks up, her eyes are black."},
		{"fade": "out", "time": 2.5},
		{"say": "", "text": "The end of the campaign."},
	]


func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var c := r.game.player_village.center
	if n >= HOLD:
		r.mark["held"] = true
		return
	if r.caravan(_food_spawn(r), CARAVAN) != null:
		r.mark["caravans"] = int(r.mark.get("caravans", 0)) + 1
	var lines: Array[Dictionary] = []
	match n:
		1:
			lines = [
				{"say": "pell", "text": "The guild's carts got through. Bread, and a little timber. Don't ask what it cost."},
				{"say": "brenna", "text": "Whatever it cost, it's cheaper than starving."},
			]
		VOICE_WAVE:
			lines = [
				{"say": "", "text": "A voice carries down from the throne hall over the whole city, calm and pleasant."},
				{"say": "rhodri", "text": "Brenna. You were always my best. Do you remember the night before the field? You said you'd follow me anywhere."},
				{"say": "brenna", "text": "I remember. I followed a man. Not a crown."},
				{"say": "rhodri", "text": "There's no difference any more. Come and see."},
			]
		COURT_WAVE:
			lines = [
				{"say": "fiona", "text": "He was a kind boy. He used to cry when the hounds killed a hare."},
				{"say": "fiona", "text": "Whatever is left of him, I'll find it. I owe him that."},
			]
	if lines.is_empty():
		return
	var scene: Array[Dictionary] = [{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0}]
	scene.append_array(lines)
	r.play_scene(scene)


## The last wave: Rhodri comes out of the throne hall with Lothar and his court.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n != HOLD:
		return
	var at := r.spawn_near(_hall_tile(r))
	r.add_enemies("legion_king", at, 1, {"name": "Rhodri", "hp_x": RHODRI_HP, "mount": "horse", "mount_hp": RHODRI_HORSE_HP})
	r.add_enemies("legion_champion", at, 1, {"name": "Lothar", "art": "herald", "hp_x": LOTHAR_HP})
	for k: String in COURT:
		r.add_enemies(k, at, int(COURT[k]))
	r.mark["rhodri sent"] = true
	r.play_scene([
		{"camera": r.at(_hall_tile(r)) + Vector2(0, -40), "zoom": 0.95, "time": 2.0},
		{"say": "", "text": "The throne hall's doors open. Out comes the king, the crown blazing cold, a heavy sword in his hand, and at his side his herald with a blade in place of his flag."},
		{"say": "rhodri", "text": "Enough. I'll do it myself."},
		{"say": "lothar", "text": "Your Majesty, I am with you. To the last."},
	])


## Rhodri, Lothar: found once on the map; Rhodri speaks at half HP; beaten,
## he flees; Lothar falls.
func on_poll(r: ScenarioRunner) -> void:
	if r.cutscene == null:
		_drop_actors(r)
	if not r.mark.has("rhodri sent"):
		return
	for who in ["Rhodri", "Lothar"]:
		if not r.mark.has(who):
			var found := r.named_enemy(who)
			if found != null:
				r.mark[who] = found
	var rh = r.mark.get("Rhodri")
	if rh != null and is_instance_valid(rh) and not (rh as Enemy).retreating and (rh as Enemy).hp < (rh as Enemy).max_hp * 0.5 and not r.mark.has("rhodri half"):
		r.mark["rhodri half"] = true
		r.play_scene([
			{"say": "rhodri", "text": "Brenna, it hurts. It always hurts. Why does it hurt?"},
			{"say": "brenna", "text": "Because it isn't you, Rhodri. Let go of it."},
			{"say": "rhodri", "text": "I can't. I can't."},
		])
	if rh != null and not r.mark.has("rhodri down") and (not is_instance_valid(rh) or (rh as Enemy).retreating or (rh as Enemy).dead):
		r.mark["rhodri down"] = true
		r.game.events.important("Rhodri is beaten and flees into the throne hall")
		r.play_scene([
			{"say": "", "text": "The king staggers, beaten. He doesn't fall: he turns and flees, back up the street into his throne hall."},
			{"say": "fiona", "text": "Let him go. I know where he is going. Finish this, and then I'll go to him."},
		])
	var lo = r.mark.get("Lothar")
	if lo != null and not r.mark.has("lothar down") and (not is_instance_valid(lo) or (lo as Enemy).dead):
		r.mark["lothar down"] = true
		r.game.events.info("Lothar, the court's herald, has fallen: the last of the court")
		r.play_scene([
			{"say": "", "text": "Lothar falls, the last of the court. For a moment he only looks surprised, and very tired."},
			{"say": "lothar", "text": "I carried his words. All of them. I hope someone will remember the kind ones."},
		])


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "The last camp",
			"text": "Your army waits in the reserve. Station it: towers on the streets, the barracks, the wall towers. Fiona's mages hold their own towers and take no orders.",
			"done": func() -> bool: return g.army.stationed().size() >= 10,
			"point": func() -> Dictionary: return {"hud": ["reserve", "tab:army", "dock"], "tab": "army", "tiles": r.first_tiles(r.towers(true))}},
		{"title": "Timber",
			"text": "Trees grow only in a few patches of steppe out in the city. Build a worker camp beside one, and your foresters will cut there.",
			"done": func() -> bool: return g.player_village.buildings().any(func(b: Building) -> bool: return b.kind == "camp"),
			"point": func() -> Dictionary: return r.place_point("camp", _grove_tiles(r))},
		{"title": "No fields here",
			"text": "Nothing grows in the city. Food comes from the guild's carts (one after every wave, as long as the road is clear) and from Pell: buy food at his stall when it runs short.",
			"done": func() -> bool: return int(r.mark.get("caravans", 0)) >= 1,
			"point": func() -> Dictionary: return {"tiles": r.first_tiles(r.stalls())}},
		{"title": "The king",
			"text": "Rhodri has come out. The Legion near him strikes harder and takes less harm, he rallies more soldiers while he stands, and his blows cleave. Beat him: he won't die, but he will flee.",
			"ready": func() -> bool: return r.mark.has("rhodri sent"),
			"wait_text": "Hold the camp. The king will come out in the last wave.",
			"done": func() -> bool: return r.mark.has("rhodri down"),
			"point": func() -> Dictionary:
				var h = r.mark.get("Rhodri")
				return {"tiles": [(h as Enemy).current_tile()] if is_instance_valid(h) and not (h as Enemy).dead else []}},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "legion_cavalry",
			"when": func() -> bool: return r.enemy_about("legion_cavalry"),
			"text": "Legion cavalry: fast riders that keep with their soldiers and run down our fighters. A charge hits twice as hard; halberdiers break it and hurt horses most. Unhorsed, the rider fights on as a footman."},
		{"id": "starving",
			"when": func() -> bool: return g.economy.amount("food") < 40.0,
			"text": "Food is short, and no farms can grow here. Buy food at Pell's stall, or recruit nobody new until the next cart comes."},
		{"id": "legion_banner",
			"when": func() -> bool: return r.enemy_about("legion_banner"),
			"text": "A Legion banner-bearer: the soldiers near its banner strike and shoot faster. Kill it first."},
		{"id": "legion_guard",
			"when": func() -> bool: return r.enemy_about("legion_guard"),
			"text": "A Legion guardsman: arrows and bolts do only half to it. Mages, acolytes and melee do better."},
		{"id": "spider",
			"when": func() -> bool: return r.enemy_about("spider_mother"),
			"text": "A spider mother lays eggs on her way. Smash the eggs before they hatch."},
		{"id": "trees",
			"when": func() -> bool: return g.economy.amount("materials") < 60.0,
			"text": "Material is short. The few trees in the city grow in the steppe patches: a worker camp near them lets the foresters reach them."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and nobody can bring her back. Send her to rest (her panel: Rest) until she has healed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "waves", "text": "Hold the camp for %d waves" % HOLD,
			"done": func() -> bool: return r.mark.has("held"),
			"detail": func() -> String: return "%d / %d" % [mini(g.waves.wave - (1 if g.waves.in_progress() else 0), HOLD), HOLD]},
		{"id": "rhodri", "text": "Beat Rhodri",
			"done": func() -> bool: return r.mark.has("rhodri down")},
	]


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell and Fiona must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

## The throne hall (the map's landmark), or null.
func _hall(r: ScenarioRunner) -> Treasure:
	for o in r.game.world.map_objects:
		if o is Treasure and str((o as Treasure).data.get("treasure", "")) == "throne_hall":
			return o
	return null


func _hall_tile(r: ScenarioRunner) -> Vector2i:
	var h := _hall(r)
	return h.tile if h else r.game.player_village.center + Vector2i(0, -20)


## Open tiles beside the city's trees (its steppe spots), nearest the village first.
func _grove_tiles(r: ScenarioRunner) -> Array:
	var c := Vector2(r.game.player_village.center)
	var out: Array = []
	for t: Vector2i in r.game.map.props:
		if not r.game.map.is_forest(t):
			continue
		for n in MapData.neighbors4(t):
			if r.game.player_village.construction.placement_error("camp", n, true) == "" and not out.has(n):
				out.append(n)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(c) < Vector2(b).distance_to(c))
	return out.slice(0, 3)


## The edge spawn farthest from the throne hall: the carts' road.
func _food_spawn(r: ScenarioRunner) -> Vector2i:
	var hall := Vector2(_hall_tile(r))
	var best := Vector2i(-1, -1)
	for t in r.game.map.edge_spawns:
		if best.x < 0 or Vector2(t).distance_to(hall) > Vector2(best).distance_to(hall):
			best = t
	return best


func _drop_actors(r: ScenarioRunner) -> void:
	for n in r.mark.get("actors", []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	r.mark.erase("actors")
