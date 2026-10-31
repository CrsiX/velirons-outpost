extends Scenario
## Scenario 10: The Last Wardline (docs/scenarios-design.md §3.10, §7.17). Home,
## at its strongest: every hut, a guild market, barracks, the restored
## Wardline manned. The Dread Legion marches on the village by every road,
## with everything else that follows Rhodri. Lothar demands Brenna's surrender
## once more; Fiona's court mages come to help; Torben and Lysa lead the
## Legion's attacks, and in the sixteenth wave its marshal, Halvard. Guild
## caravans come down the Wardline road while it is clear. Brenna can't be
## brought back even at home; Pell must not die.


func _init() -> void:
	number = 10
	title = "The Last Wardline"
	blurb = "The Dread Legion marches on your home by every road. Hold the village and the restored Wardline against Rhodri's marshal."
	map_path = "res://data/maps/wardline.json"
	place = "outpost"
	portrait = "portrait_halvard"

	# The baseline: the village at its strongest: every hut, Pell's guild
	# market, barracks, training grounds, the Wardline restored and manned.
	difficulty = "easy"
	enemy_scale = {"hp": 1.15, "damage": 1.15, "spell_damage": 1.15}
	resources = {"gold": 450, "food": 320, "materials": 360}
	civilians = ["builder", "builder", "farmer", "farmer", "forester", "gatherer", "gatherer", "merchant"]
	names = {"forester": "Einar", "merchant": "Pell"}
	buildings = ["farm", "camp"]
	prebuilt = [
		{"kind": "stall", "road": 1, "at": [3, 7], "level": 3},
		{"kind": "farm", "road": 2, "at": [4, 9]},
		{"kind": "barracks", "road": 0, "at": [6, 10], "level": 3,
			"units": [{"kind": "warrior", "level": 6}, {"kind": "halberdier", "level": 5}, {"kind": "berserker", "level": 5}]},
		{"kind": "training", "road": 1, "at": [8, 12]},
		# The ruins, nearest the village first: the tower by the village (restored
		# in scenario 2), then the Wardline's six along the border road (by
		# distance: north of the village, west of the bridge, north-east, far
		# west, east, at the west edge) and its barracks at the east end.
		{"kind": "tower", "ruin": 0, "level": 2, "units": [{"kind": "crossbowman", "level": 6}]},
		{"kind": "tower", "ruin": 1, "level": 2, "units": [{"kind": "swiftbowman", "level": 6}]},
		{"kind": "tower", "ruin": 2, "units": [{"kind": "archer", "level": 8}]},
		{"kind": "tower", "ruin": 3, "level": 2, "units": [{"kind": "crossbowman", "level": 5}]},
		{"kind": "tower", "ruin": 4, "units": [{"kind": "swiftbowman", "level": 5}]},
		{"kind": "tower", "ruin": 5, "units": [{"kind": "archer", "level": 6}]},
		{"kind": "tower", "ruin": 6, "units": [{"kind": "archer", "level": 5}]},
		{"kind": "barracks", "ruin": 0, "level": 2, "units": [{"kind": "shield_bearer", "level": 7}, {"kind": "inquisitor", "level": 4}]},
		{"kind": "tower", "road": 0, "at": [3, 5], "level": 2, "units": [{"kind": "high_priest", "level": 4}]},
		{"kind": "tower", "road": 1, "at": [3, 5], "level": 2, "units": [{"kind": "crossbowman", "level": 5}]},
		{"kind": "tower", "road": 2, "at": [3, 6], "level": 2, "units": [{"kind": "fire_summoner", "level": 5}]},
		{"kind": "wall_tower", "road": 0, "units": [{"kind": "archer", "level": 7}]},
		{"kind": "wall_tower", "road": 1, "units": [{"kind": "acolyte", "level": 6}]},
	]
	reserve = [{"kind": "archer", "level": 5}, {"kind": "shield_bearer", "level": 5}]
	hero_name = "Brenna"
	hero_level = 16

	unlocked = ["apprentice", "acolyte", "summoner"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell"]

	# Everything that follows Rhodri, by every road; the Legion from wave 4.
	waves = [
		{"kinds": {"goblin": 6, "orc": 2}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 6, "skeleton": 4, "orc": 2, "thief": 2}, "spawns": 3},
		{"kinds": {"goblin": 6, "skeleton": 5, "witch": 2, "gargoyle": 1, "slime3": 1}, "rat_packs": [6], "spawns": 4},
		{"kinds": {"skeleton": 5, "orc": 2, "witch": 1, "legion_footman": 6, "legion_archer": 2, "legion_banner": 1}, "spawns": 4},
		{"kinds": {"goblin": 6, "vampire": 1, "necromancer": 1, "legion_footman": 6, "legion_cavalry": 1, "legion_archer": 2, "legion_guard": 1}, "rat_packs": [5], "spawns": 4},
		{"kinds": {"skeleton": 6, "spider_mother": 1, "gargoyle": 2, "legion_footman": 7, "legion_cavalry": 1, "legion_archer": 3, "legion_banner": 1}, "spawns": 4},
		{"kinds": {"goblin": 6, "thief": 3, "witch": 2, "vampire": 2, "legion_footman": 7, "legion_cavalry": 1, "legion_guard": 2, "legion_archer": 3}, "spawns": 4},
		{"kinds": {"skeleton": 6, "necromancer": 2, "gargoyle": 2, "legion_footman": 8, "legion_cavalry": 2, "legion_guard": 2, "legion_archer": 3, "legion_banner": 1}, "spawns": 4},
		{"kinds": {"goblin": 8, "orc": 3, "vampire": 2, "slime3": 2, "legion_footman": 8, "legion_cavalry": 2, "legion_archer": 4, "legion_banner": 1}, "rat_packs": [6], "spawns": 4},
		{"kinds": {"skeleton": 8, "witch": 2, "gargoyle": 3, "spider_mother": 1, "legion_footman": 9, "legion_cavalry": 2, "legion_guard": 3, "legion_archer": 4}, "spawns": 4},
		{"kinds": {"orc": 4, "vampire": 3, "necromancer": 2, "thief": 3, "legion_footman": 9, "legion_cavalry": 2, "legion_guard": 3, "legion_archer": 4, "legion_banner": 2}, "spawns": 4},
		{"kinds": {"skeleton": 8, "gargoyle": 3, "witch": 2, "legion_footman": 10, "legion_cavalry": 3, "legion_guard": 3, "legion_archer": 5, "legion_banner": 2}, "rat_packs": [6], "spawns": 4},
		{"kinds": {"goblin": 8, "orc": 4, "vampire": 3, "spider_mother": 1, "legion_footman": 10, "legion_cavalry": 3, "legion_guard": 4, "legion_archer": 5, "legion_banner": 2}, "spawns": 4},
		{"kinds": {"skeleton": 10, "necromancer": 2, "gargoyle": 4, "witch": 3, "legion_footman": 11, "legion_cavalry": 3, "legion_guard": 4, "legion_archer": 5, "legion_banner": 2}, "rat_packs": [7], "spawns": 4},
		{"kinds": {"orc": 5, "vampire": 4, "slime3": 2, "thief": 3, "legion_footman": 12, "legion_cavalry": 3, "legion_guard": 4, "legion_archer": 6, "legion_banner": 2}, "spawns": 4},
		{"kinds": {"skeleton": 8, "gargoyle": 3, "vampire": 3, "legion_footman": 12, "legion_cavalry": 4, "legion_guard": 5, "legion_archer": 6, "legion_banner": 3}, "spawns": 4},
	]
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 40.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"einar": {"name": "Einar", "portrait": "portrait_einar", "color": Color("c8a878")},
		"idris": {"name": "Idris", "portrait": "portrait_mage", "color": Color("c0a8f0")},
		"lothar": {"name": "Lothar", "portrait": "portrait_lothar", "color": Color("d8d4e4")},
		"lysa": {"name": "Lysa", "portrait": "portrait_lysa", "color": Color("c8ccd8")},
		"halvard": {"name": "Halvard", "portrait": "portrait_halvard", "color": Color("c4c8d0")},
	}


## The waves the story needs: word from Fiona, Lothar's demand, the Legion,
## the mages, Torben, Lysa, Halvard.
const WORD_WAVE := 2
const DEMAND_WAVE := 3
const LEGION_WAVE := 4
const TORBEN_WAVE := 8
const LYSA_WAVE := 12
const HOLD := 16
## Guild caravans set out down the Wardline road when these waves start.
const CARAVAN_WAVES: Array[int] = [3, 6, 9, 12, 15]
const CARAVAN := {"gold": 80, "food": 60, "materials": 100}
## Fiona's court mages, into the reserve after the Legion's first wave.
const MAGES: Array[Dictionary] = [{"kind": "fire_mage", "level": 5}, {"kind": "ice_mage", "level": 5}, {"kind": "healing_mage", "level": 5}]
## Halvard's HP scale, and the soldiers marching with him.
const HALVARD_HP := 1.0
## Torben, Lysa and Halvard ride (docs/enemies-design.md §15e): their horses' HP.
const CAPTAIN_HORSE_HP := 70.0
const HALVARD_HORSE_HP := 250.0
const HALVARD_GUARD := {"legion_guard": 2, "legion_banner": 1}


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var north := _north_road(r)
	var far: Vector2 = Vector2(north[north.size() / 3]) if north.size() > 3 else Vector2(c) + Vector2(0, -20)
	return [
		{"fade": "out", "time": 0.01},
		{"do": func() -> void: r.dusk(0.01)},
		{"camera": r.at(c) + Vector2(0, -60), "zoom": 0.9, "time": 0.01},
		{"title": "The Last Wardline", "sub": "Scenario 10", "time": 3.0},
		{"say": "", "text": "Home, at dusk. Brenna and Pell stand on the wall. Out on the horizon, torches: more than anyone can count, on every road."},
		{"fade": "in", "time": 1.4},
		{"camera": r.at(far) + Vector2(0, -40), "zoom": 0.8, "time": 3.0},
		{"say": "pell", "text": "All of that. For one village."},
		{"say": "brenna", "text": "For the village that stood with Fiona. And for me."},
		{"say": "brenna", "text": "Lysa is out there, my captain. Torben, who marched beside me for six years. They don't know their own names any more."},
		{"say": "brenna", "text": "I will free them."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.5},
		{"say": "", "text": "Below the wall Einar comes in from the woods with his axe on his shoulder, as on any evening."},
		{"say": "einar", "text": "Ah, my girl! How goes it?"},
		{"say": "brenna", "text": "Father, the Legion is coming. Get everyone inside!"},
		{"say": "einar", "text": "Then I'll put the kettle on for after."},
		{"say": "", "text": "Hold the village through %d waves. The Wardline is restored and manned; guild caravans come down its road while it is clear. Brenna can't be brought back, not even at home, and Pell must not die." % HOLD},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	return [
		{"do": func() -> void: r.dusk(3.0)},
		{"camera": r.at(c) + Vector2(0, -50), "zoom": 1.05, "time": 2.0},
		{"say": "", "text": "The Legion is stopped. On the road only the fallen remain, and the quiet."},
		{"say": "", "text": "Halvard lies where he fell. Brenna kneels by him. The pallor has left his face; he is an old soldier, tired, and he knows her."},
		{"say": "halvard", "text": "Hale. Brenna Hale. I gave you your spurs."},
		{"say": "", "text": "He takes her hand, and holds it."},
		{"say": "halvard", "text": "Thank you."},
		{"say": "", "text": "Then he is gone, and the breath that goes out of him is his own."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "idris", "text": "A messenger from Fiona. She rides for the capital, with the priests and every mage she has. She has the Hand."},
		{"say": "pell", "text": "Then so do we, I suppose."},
		{"say": "brenna", "text": "So do we. It ends at the throne."},
		{"fade": "out", "time": 1.5},
	]


func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var c := r.game.player_village.center
	if n >= HOLD:
		r.mark["held"] = true
	var lines: Array[Dictionary] = []
	match n:
		1:
			lines = [
				{"say": "pell", "text": "That was only the wilderness, running ahead of them like animals before a fire."},
				{"say": "brenna", "text": "The fire comes next."},
			]
		WORD_WAVE:
			lines = [
				{"say": "", "text": "A rider comes in at a gallop, a court mage's sigil on her cloak."},
				{"say": "brenna", "text": "From Fiona?"},
				{"say": "", "text": "Fiona's words: her mages are coming. Hold until they do."},
			]
		DEMAND_WAVE:
			_demand(r)
			return
		LEGION_WAVE:
			r.mark["mages"] = r.give_units(MAGES)
			r.game.events.info("Fiona's court mages join the village: a fire mage, an ice mage and a healing mage are in the reserve")
			lines = [
				{"say": "", "text": "Three court mages come up the road at dusk, Idris at their head."},
				{"say": "idris", "text": "Fiona sends us, and her regards. Where do you want us?"},
				{"say": "brenna", "text": "Where the Legion comes thickest. That's everywhere."},
			]
		TORBEN_WAVE:
			lines = [
				{"say": "brenna", "text": "Torben fell back. He didn't know me. He looked right at me and didn't know me."},
				{"say": "pell", "text": "He's still alive, Brenna. While he lives, there's something to free."},
			]
	if lines.is_empty():
		return
	var scene: Array[Dictionary] = [{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0}]
	scene.append_array(lines)
	r.play_scene(scene)


## Lothar under his white flag: surrender, or not (a choice).
func _demand(r: ScenarioRunner) -> void:
	var road := _north_road(r)
	var herald: Vector2 = Vector2(road[road.size() - 4]) if road.size() >= 4 else Vector2(r.game.player_village.center) + Vector2(0, -6)
	r.play_scene([
		{"do": func() -> void: r.mark["actors"] = [r.actor("unit_herald", herald)]},
		{"camera": r.at(herald) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "Lothar rides up to the gate under his white flag, alone."},
		{"say": "lothar", "text": "Dame Brenna. His Majesty's last word, and the Legion's marshal behind it. Open your gates and kneel, and your village lives."},
		{"say": "lothar", "text": "Refuse, and Halvard will take it apart, tower by tower."},
		{"say": "brenna", "text": "...",
			"choices": [
				{"text": "Open the gates", "do": func() -> void:
					_drop_actors(r)
					r.lose("Brenna opened the gates. The village knelt to the crown, and the Legion marched in, in step.")},
				{"text": "Refuse", "do": func() -> void: pass},
			]},
		{"say": "brenna", "text": "These towers kept the wilderness out for a hundred years. They'll keep him out too."},
		{"say": "lothar", "text": "I hoped you would say yes. I truly did. Farewell, Dame Brenna."},
		{"do": func() -> void: _drop_actors(r)},
	])


## The Legion comes; Torben, Lysa and Halvard lead its attacks; the caravans set out.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n in CARAVAN_WAVES:
		var cv := r.caravan(_north_spawn(r), CARAVAN)
		if cv:
			r.mark["caravans out"] = int(r.mark.get("caravans out", 0)) + 1
			cv.delivered.connect(func() -> void: r.mark["caravans in"] = int(r.mark.get("caravans in", 0)) + 1)
	var c := r.game.player_village.center
	match n:
		LEGION_WAVE:
			r.play_scene([
				{"camera": r.at(c) + Vector2(0, -60), "zoom": 0.85, "time": 1.5},
				{"say": "", "text": "Drums. Down every road the Legion comes in ranks, pale, silent, in step."},
				{"say": "brenna", "text": "Here they are. To the walls!"},
			])
		TORBEN_WAVE:
			var at := _road_spawn(r, 1)
			r.add_enemies("legion_captain", at, 1, {"name": "Torben", "mount": "horse", "mount_hp": CAPTAIN_HORSE_HP})
			r.play_scene([
				{"camera": r.at(at) + Vector2(0, -40), "zoom": 1.0, "time": 1.5},
				{"say": "", "text": "At the head of a column rides a captain Brenna knows: broad, red-bearded, the scar she sewed up herself."},
				{"say": "brenna", "text": "Torben!"},
			])
		LYSA_WAVE:
			var at := _road_spawn(r, 2)
			r.add_enemies("legion_captain", at, 1, {"name": "Lysa", "art": "legion_captain_lysa", "mount": "horse", "mount_hp": CAPTAIN_HORSE_HP})
			r.play_scene([
				{"camera": r.at(at) + Vector2(0, -40), "zoom": 1.0, "time": 1.5},
				{"say": "lysa", "text": "Hale. You should have stayed at the delta."},
				{"say": "brenna", "text": "You told me to go home, Lysa. I did."},
			])
		HOLD:
			var at := _north_spawn(r)
			r.add_enemies("legion_marshal", at, 1, {"name": "Halvard", "hp_x": HALVARD_HP, "mount": "horse", "mount_hp": HALVARD_HORSE_HP})
			for k: String in HALVARD_GUARD:
				r.add_enemies(k, at, int(HALVARD_GUARD[k]))
			r.add_enemies("legion_captain", _road_spawn(r, 1), 1, {"name": "Torben", "mount": "horse", "mount_hp": CAPTAIN_HORSE_HP})
			r.add_enemies("legion_captain", _road_spawn(r, 2), 1, {"name": "Lysa", "art": "legion_captain_lysa", "mount": "horse", "mount_hp": CAPTAIN_HORSE_HP})
			r.mark["halvard sent"] = true
			r.play_scene([
				{"camera": r.at(at) + Vector2(0, -40), "zoom": 0.95, "time": 2.0},
				{"say": "", "text": "Down the Wardline road comes the marshal himself, grey-bearded, in dark plate, his baton raised. Where he rides, the Legion stands straighter."},
				{"say": "halvard", "text": "The King's peace on this village. Break it."},
				{"say": "brenna", "text": "Halvard. You taught me to hold a line."},
				{"say": "halvard", "text": "Then hold it."},
			])


## Halvard found once he is on the map; his fall.
func on_poll(r: ScenarioRunner) -> void:
	if r.cutscene == null:
		_drop_actors(r)  # (a skipped scene leaves the herald standing)
	if r.mark.has("halvard sent") and not r.mark.has("halvard down"):
		if not r.mark.has("halvard"):
			var found := r.named_enemy("Halvard")
			if found != null:
				r.mark["halvard"] = found
		var h = r.mark.get("halvard")
		if h != null and (not is_instance_valid(h) or (h as Enemy).dead):
			r.mark["halvard down"] = true
			r.game.events.important("Halvard, the Legion's marshal, has fallen")
			r.play_scene([
				{"say": "", "text": "The marshal goes down. All along the roads the Legion falters, as if a rope holding it had been cut."},
			])


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	return [
		{"title": "The line is manned",
			"text": "The Wardline and every road are manned already. Make them stronger: upgrade a unit (tap it on its post, or the Army tab: Upgrade).",
			"start": func() -> void: r.mark_units(),
			"done": func() -> bool: return r.unit_promoted(),
			"point": func() -> Dictionary: return {"hud": ["tab:army", "dock"], "tab": "army"}},
		{"title": "The guild's caravans",
			"text": "A guild caravan comes down the Wardline road. It halts while enemies are near it and goes on once the road is clear. Keep the road clear and it brings gold, food and material.",
			"ready": func() -> bool: return r.mark.has("caravans out"),
			"wait_text": "The guild sends caravans down the Wardline road from wave %d." % CARAVAN_WAVES[0],
			"done": func() -> bool: return int(r.mark.get("caravans in", 0)) >= 1},
		{"title": "Fiona's mages",
			"text": "Fiona's three court mages wait in the reserve: a fire mage, an ice mage and a healing mage. Station them where the Legion comes thickest.",
			"ready": func() -> bool: return r.mark.has("mages"),
			"wait_text": "Fiona's mages are on their way.",
			"done": func() -> bool: return (r.mark["mages"] as Array).filter(func(u: MilitaryUnit) -> bool: return u.state == MilitaryUnit.State.STATIONED).size() >= 2,
			"point": func() -> Dictionary: return {"hud": ["reserve", "tab:army", "dock"], "tab": "army", "tiles": r.first_tiles(r.towers(true))}},
		{"title": "The marshal",
			"text": "Halvard leads the last attack. The Legion near him strikes harder and takes less harm (the gold ring), and while he lives he rallies fresh soldiers down the roads. Bring him down.",
			"ready": func() -> bool: return r.mark.has("halvard sent"),
			"wait_text": "Hold the line. The Legion's marshal will come.",
			"done": func() -> bool: return r.mark.has("halvard down"),
			"point": func() -> Dictionary:
				var h = r.mark.get("halvard")
				return {"tiles": [(h as Enemy).current_tile()] if is_instance_valid(h) and not (h as Enemy).dead else []}},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "legion_cavalry",
			"when": func() -> bool: return r.enemy_about("legion_cavalry"),
			"text": "Legion cavalry: fast riders that keep with their soldiers and run down our fighters. A charge hits twice as hard; halberdiers break it and hurt horses most. Unhorsed, the rider fights on as a footman."},
		{"id": "legion_archer",
			"when": func() -> bool: return r.enemy_about("legion_archer"),
			"text": "Legion archers shoot whoever of ours is out in the open, from a little less than a watchtower's range. Towers outrange them."},
		{"id": "legion_banner",
			"when": func() -> bool: return r.enemy_about("legion_banner"),
			"text": "A Legion banner-bearer: the soldiers near its banner strike and shoot faster. Kill it first."},
		{"id": "captain",
			"when": func() -> bool: return r.enemy_about("legion_captain"),
			"text": "A Legion captain falls back when it is beaten. It can't be killed here."},
		{"id": "halted",
			"when": func() -> bool: return g.world.objects.get_children().any(func(n: Node) -> bool: return n is ScenarioCaravan and (n as ScenarioCaravan).halted),
			"text": "The guild caravan has halted: enemies on the Wardline road. Clear them and it goes on."},
		{"id": "marshal",
			"when": func() -> bool: return r.enemy_about("legion_marshal"),
			"text": "Halvard rallies the Legion: every half minute while he lives, more soldiers come down the roads."},
		{"id": "spider",
			"when": func() -> bool: return r.enemy_about("spider_mother"),
			"text": "A spider mother lays eggs on her way. Smash the eggs before they hatch."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and nobody can bring her back. Send her to rest (her panel: Rest) until she has healed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "waves", "text": "Hold the village through %d waves" % HOLD,
			"done": func() -> bool: return r.mark.has("held"),
			"detail": func() -> String: return "%d / %d" % [mini(g.waves.wave - (1 if g.waves.in_progress() else 0), HOLD), HOLD]},
		{"id": "halvard", "text": "Bring down the marshal, Halvard",
			"done": func() -> bool: return r.mark.has("halvard down")},
		{"id": "caravans", "text": "Bring in the guild's caravans", "optional": true,
			"done": func() -> bool: return int(r.mark.get("caravans in", 0)) >= CARAVAN_WAVES.size(),
			"detail": func() -> String: return "%d / %d" % [int(r.mark.get("caravans in", 0)), CARAVAN_WAVES.size()]},
	]


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

## The Wardline road, from the map edge to the gate.
func _north_road(r: ScenarioRunner) -> Array[Vector2i]:
	return r.road_in(r.game.player_village.center + Vector2i(0, -200), 100000)


func _north_spawn(r: ScenarioRunner) -> Vector2i:
	return r.spawn_near(r.game.player_village.center + Vector2i(0, -200))


## The edge spawn of another road: `i` (1, 2...) of the spawns away from the north one.
func _road_spawn(r: ScenarioRunner, i: int) -> Vector2i:
	var north := _north_spawn(r)
	var others := r.game.map.edge_spawns.filter(func(t: Vector2i) -> bool: return t != north)
	if others.is_empty():
		return north
	return others[(i - 1) % others.size()]


func _drop_actors(r: ScenarioRunner) -> void:
	for n in r.mark.get("actors", []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	r.mark.erase("actors")
