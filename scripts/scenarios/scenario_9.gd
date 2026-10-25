extends Scenario
## Scenario 9: The Drowned Abbey (docs/scenarios-design.md §9a). A walled
## harbour village on the shore; north-east of it the church's old abbey
## stands half-sunk on an island in a broad river, one bridge from the
## village's bank. Its crypt holds the First King's Hand, a relic sword; vampires
## hold the crypt and a gigantic octopus guards the water.
##
## After wave 4 the octopus grabs a priest at the harbour; the player has
## about RESCUE_HOLD seconds to cut him free. Rescued, the priests tell what
## the abbey hides, and once the Legion's column of wave 6 is beaten they
## unseal the crypt. Drowned, they shut Brenna out (she lives in a tent
## outside the walls) and say nothing; the Legion comes in waves 6, 7 and 8;
## after that they give in.
##
## The Legion goes for the relic wherever it is (LegionCompany): the crypt's
## seal, the relic on the ground, the church once it is home. Lysa searches,
## takes it and walks it back to the map edge: if she gets there the scenario
## is lost. The leviathan wakes when the crypt is first used (Brenna going in,
## or the seal broken): woken by Brenna it blocks the crypt until it is slain.
## Won when the relic is home (and Brenna's) and the leviathan is dead.


func _init() -> void:
	number = 9
	title = "The Drowned Abbey"
	blurb = "The church's old abbey stands half-sunk in the river, and in its crypt lies the First King's Hand. The Legion wants it too."
	map_path = "res://data/maps/drowned_abbey.json"
	place = "abbey"
	portrait = "portrait_eldest_priest"

	# The baseline: a harbour village of fishers and the church's priests,
	# some walls down, the new church, a small barracks, two towers, Pell's
	# stall by the quay; two of the band in the reserve.
	difficulty = "easy"
	enemy_scale = {"hp": 1.15, "damage": 1.15, "spell_damage": 1.15}
	resources = {"gold": 300, "food": 170, "materials": 260}
	civilians = ["builder", "builder", "farmer", "forester", "gatherer", "merchant", "priest", "priest"]
	names = {"merchant": "Pell"}
	buildings = ["farm", "camp"]
	huts_standing = 9
	pieces_standing = {"wall": 14, "gate": 3, "wall_tower": 3}
	pieces_hp = 0.8
	prebuilt = [
		{"kind": "church", "tile": CHURCH_TILE},
		{"kind": "stall", "offset": Vector2i(-4, 8), "level": 1},
		{"kind": "barracks", "offset": Vector2i(-8, 2), "level": 2, "units": [{"kind": "shield_bearer", "level": 7}, {"kind": "archer", "level": 6}]},
		{"kind": "tower", "offset": Vector2i(-3, -5), "units": [{"kind": "archer", "level": 7}]},
		{"kind": "tower", "offset": Vector2i(7, -3), "units": [{"kind": "apprentice", "level": 6}]},
	]
	reserve = [{"kind": "summoner", "level": 6}, {"kind": "acolyte", "level": 6}]
	hero_name = "Brenna"
	hero_level = 14

	units = ["archer", "shield_bearer", "apprentice", "acolyte", "summoner"]
	unlocked = ["apprentice", "acolyte", "summoner"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell", ELDEST]
	arms_first = true  # (towers cut the octopus's arm that holds someone, not its body)

	# Crabs out of the water first, then the drowned dead and the Evil, and
	# the Wilderness all along: orks from wave 2, big slimes, spider mothers
	# (7, 9, 10), rat packs. The Legion's columns are added when their waves
	# begin (LEGION_COLUMNS). After the tenth the last comes again, bigger,
	# until the scenario is won.
	waves = [
		{"kinds": {"crab": 5, "goblin": 4}, "spawns": 2},
		{"kinds": {"crab": 5, "goblin": 5, "ork": 1}, "rat_packs": [6], "spawns": 2},
		{"kinds": {"crab": 6, "goblin": 4, "ork": 1, "slime3": 1, "skeleton": 3}, "spawns": 3},
		{"kinds": {"crab": 5, "goblin": 5, "ork": 2, "skeleton": 4, "necromancer": 1}, "spawns": 3},
		{"kinds": {"crab": 5, "goblin": 4, "ork": 2, "slime3": 1, "skeleton": 5, "vampire": 1, "gargoyle": 1}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"crab": 5, "goblin": 5, "ork": 2, "skeleton": 5, "necromancer": 1, "vampire": 1}, "spawns": 3},
		{"kinds": {"crab": 6, "goblin": 5, "ork": 2, "spider_mother": 1, "skeleton": 6, "vampire": 2, "gargoyle": 1}, "spawns": 3},
		{"kinds": {"crab": 6, "goblin": 5, "ork": 3, "slime3": 2, "skeleton": 6, "necromancer": 1, "vampire": 2, "gargoyle": 2}, "rat_packs": [7, 5], "spawns": 3},
		{"kinds": {"crab": 7, "goblin": 5, "ork": 3, "spider_mother": 1, "skeleton": 7, "vampire": 2, "gargoyle": 2, "siren": 1}, "spawns": 3},
		{"kinds": {"crab": 7, "goblin": 6, "ork": 3, "slime3": 1, "spider_mother": 1, "skeleton": 7, "necromancer": 2, "vampire": 2, "gargoyle": 2}, "spawns": 3},
	]
	repeat_last = true
	more_each_wave = {"crab": 2, "skeleton": 2, "ork": 1}
	# And two more each repeat, in turn: the Wilderness, thieves, vampires, necromancers.
	rotate_kinds = ["goblin", "ork", "slime3", "crab", "spider_mother", "thief", "vampire", "necromancer"]
	rotate_count = 2
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"eldest": {"name": "The eldest priest", "portrait": "portrait_eldest_priest", "color": Color("e0d4b8")},
		"priest": {"name": "A priest", "portrait": "portrait_church_priest", "color": Color("d8c8a8")},
		"lysa": {"name": "Lysa", "portrait": "portrait_lysa", "color": Color("c8ccd8")},
	}


## The vampires' camp at the abbey: its first vampire is the Fallen Abbot,
## with this many times the HP and damage; the other vampire and the
## skeleton have CAMP_GUARD_HP times the HP (their damage as ever).
const ABBOT := "Fallen Abbot"
const ABBOT_HP := 5.0
const ABBOT_POWER := 4.0
const CAMP_GUARD_HP := 3.0
## The two priests' names (for the log, the villager list and must_live): the
## eldest (she must not die; she looks as in her portrait) and the younger
## one, whom the octopus catches.
const ELDEST := "Eldest priest"
const YOUNGER := "Priest"
## The relic, as the treasure's item.
const RELIC := "the First King's Hand"
## The map's church (its centre: data/maps/drowned_abbey.json, tools/abbey_map.gd).
const CHURCH_TILE := Vector2i(34, 45)
## Wave 1's countdown, started the moment a watchtower of the player's by the shore stands.
const FIRST_WAVE_AFTER := 60.0
## Its objective stays ticked this long (s), then it is gone (it is only for the start).
const WATCH_GOAL_STAYS := 4.0
## Lysa is seen wherever she walks: the land this far round her is watched.
const LYSA_SIGHT := 3.0
## After this wave the octopus grabs a priest at the harbour: it holds him in
## the shallows this long before it drags him under, and he has this many
## times a villager's HP (its arm hurts him meanwhile).
const RESCUE_WAVE := 4
const RESCUE_HOLD := 20.0
const PRIEST_HP_X := 8.0
## Rescued and home in the church, he stays in this long before his rounds again (s).
const RESCUED_REST := 30.0
## The Legion's columns: the waves they come in (rescued: only the first; the
## priests drowned: all three), each stronger than the last.
const LEGION_WAVES: Array[int] = [6, 7, 8]
const LEGION_COLUMNS: Array[Dictionary] = [
	{"legion_footman": 5, "legion_archer": 2, "legion_banner": 1, "legion_guard": 1},
	{"legion_footman": 6, "legion_archer": 3, "legion_banner": 1, "legion_guard": 2},
	{"legion_footman": 8, "legion_archer": 3, "legion_banner": 1, "legion_guard": 3},
]
## Seconds between the column's soldiers coming out (Waves "gap").
const COLUMN_GAP := 0.45
## The crypt's seal: HP the Legion has to break.
const SEAL_HP := 600.0
## The guard octopus: its HP x this, and how far from its post it keeps.
const GUARD_HP := 1.5
const GUARD_LEASH := 6.0
## The leviathan: HP and damage x these (its blast: 30 x 1.15 (the
## scenario's enemy scale) = 34.5 HP/s while it lasts, no boss bonus); how far from the crypt it keeps while the relic is in it, and
## from the pier while a boat comes in; else it haunts the harbour's shore,
## this far round the pier.
const LEVIATHAN_HP := 5.0
const LEVIATHAN_POWER := 1.0
const CRYPT_LEASH := 7.0
const PIER_LEASH := 5.0
const SHORE_LEASH := 9.0
## Pell's guild boats: after these waves, with this, unless the leviathan
## lives (it sinks them). Tiles per second they sail.
const BOAT_WAVES: Array[int] = [2, 5, 8]
const BOAT := {"food": 60, "materials": 80, "gold": 40}
const BOAT_SPEED := 1.6
## The drowned dead lying on the island.
const DROWNED := 8
## Scenery near the quay: [art, offset from the quay, flipped].
const HARBOUR_PROPS: Array = [
	["ferry_bell", Vector2i(1, 0), false],
	["harbour_crates", Vector2i(-2, 0), false],
	["net_rack", Vector2i(2, -1), false],
	["mooring_post", Vector2i(-1, 0), false],
	["mooring_post", Vector2i(3, 0), true],
	["boat_upturned", Vector2i(-4, 0), false],
	["boat_upturned", Vector2i(5, 0), true],
	["fish_rack", Vector2i(-5, -1), false],
	["fish_rack", Vector2i(-7, -1), true],
	["driftwood", Vector2i(-9, 0), false],
	["driftwood", Vector2i(7, 0), true],
	["driftwood", Vector2i(-12, 0), true],
]
## The second pier, about here from the quay (the nearest shore tile with
## water in front of it), and its scenery: [art, offset from its land end,
## flipped]; boats on the water by it.
const SECOND_PIER := Vector2i(-7, 0)
const SECOND_PIER_PROPS: Array = [
	["harbour_crates", Vector2i(1, 0), false],
	["harbour_crates", Vector2i(-1, -1), true],
	["mooring_post", Vector2i(-1, 0), false],
	["mooring_post", Vector2i(2, 0), true],
	["net_rack", Vector2i(2, -1), false],
	["fish_rack", Vector2i(-2, 0), true],
	["boat_upturned", Vector2i(3, -1), false],
]
const SECOND_PIER_BOATS: Array = [["boat", Vector2i(1, 2)], ["boat_supply", Vector2i(-1, 2)], ["boat", Vector2i(1, 3)]]
## What each prop is called where it keeps a tile free ("The ferry bell stands here").
const PROP_NAMES := {"ferry_bell": "ferry bell", "harbour_crates": "harbour's crates", "net_rack": "net rack", "mooring_post": "mooring post",
	"boat_upturned": "upturned boat", "fish_rack": "fish rack", "driftwood": "driftwood", "beacon": "beacon"}
## How far the octopus comes up from the piers and the quay (tiles, at least).
const OCTOPUS_OFF_PIER := 2.0
## The beacon on the river's bank near the sea (an offset from the quay;
## the nearest open bank tile), and how many gulls circle it.
const BEACON_OFFSET := Vector2i(16, -2)
const GULLS := 3


## Brenna's tent when the priests shut her out (near this offset from the village centre).
const TENT_OFFSET := Vector2i(-9, 3)


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var ab := _abbey(r)
	var abbey: Vector2 = Vector2(ab.tile) if ab else Vector2(c)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": r.at(abbey) + Vector2(0, -60), "zoom": 0.95, "time": 0.01},
		{"title": "The Drowned Abbey", "sub": "Scenario 9", "time": 3.0},
		{"say": "", "text": "Mist on the shore. Brenna and Pell come in on the guild's boat. Behind the village the abbey's spires rise out of the river, and somewhere under them a bell rings."},
		{"fade": "in", "time": 1.4},
		{"say": "pell", "text": "The guild's boats will come by when they can. Out here the sea is the only road that's safe."},
		{"say": "brenna", "text": "And the priests?"},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 2.5},
		{"say": "", "text": "The priests on their way to the new church take one look at Brenna's colours and hurry on. Nobody says a word about the abbey."},
		{"say": "pell", "text": "You're one of Rhodri's knights, as far as they can see. Give them time."},
		{"say": "", "text": "Hold the village and win the priests' trust. Brenna can't be brought back here, and neither Pell nor the eldest priest may die."},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var ab := _abbey(r)
	var abbey: Vector2 = Vector2(ab.tile) if ab else Vector2(c)
	# Lysa on the north road, by the island, then back up it.
	var road := r.road_in(_legion_spawn(r), 100000)
	var near := 0
	for i in road.size():
		if Vector2(road[i]).distance_to(abbey) < Vector2(road[near]).distance_to(abbey):
			near = i
	var stand: Vector2 = Vector2(road[maxi(near - 7, 0)]) if not road.is_empty() else abbey
	var away: Array = road.slice(maxi(near - 18, 0), maxi(near - 6, 1)) if not road.is_empty() else []
	away.reverse()
	var lysa := r.actor("unit_legion_captain_lysa", stand)
	r.keep_in_sight(lysa, LYSA_SIGHT)
	var scene: Array[Dictionary] = [
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "The priests come out of their church, all of them, and the village gathers round."},
	]
	if r.mark.has("rescued"):
		scene.append({"say": "eldest", "text": "We took you for one of his. We were wrong. You pulled our brother out of the sea, and stood against your own company, and against the deep."})
	else:
		scene.append({"say": "eldest", "text": "We shut our door on you, and you held our shore for us all the same. Against your own company, and against the deep. We were wrong."})
	scene.append_array([
		{"say": "eldest", "text": "The Hand goes to Fiona. Take it to her."},
		{"say": "", "text": "In Brenna's hands the old sword glows, faintly, like a coal under ash."},
		{"camera": r.at(stand) + Vector2(0, -40), "zoom": 1.05, "time": 2.5},
		{"say": "", "text": "On the north road Lysa stops on her way back into the mist, and turns. For a moment her eyes are her own."},
		{"say": "lysa", "text": "Hale. We were only to hold you here. Halvard has the main force. He's marching on your home."},
		{"say": "lysa", "text": "Go home, Brenna. Before I ..."},
		{"do": func() -> void: r.move_actor(lysa, away, 7.0)},
		{"say": "", "text": "The pallor comes back over her face like a tide, and she walks on into the mist."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "brenna", "text": "Pell. We have to go back."},
		{"say": "pell", "text": "The boats are ready."},
		{"fade": "out", "time": 1.5},
	])
	return scene


## Between the waves: Pell's boats, the rescue, the priests, the Legion's
## aftermath, Fiona's decree.
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var g := r.game
	var c := g.player_village.center
	if n in BOAT_WAVES:
		_send_boat(r)
	if r.mark.has("messenger") and not r.mark.has("decree") and n > int(r.mark["messenger"]):
		_decree(r)
	if n == RESCUE_WAVE:
		_begin_rescue(r)
		return
	if r.mark.has("rescued") and n == LEGION_WAVES[0] and _relic_at(r) == "crypt" and not r.mark.has("unsealed"):
		_unseal(r, false)
		return
	if r.mark.has("drowned") and n == LEGION_WAVES[-1] and not r.mark.has("trust"):
		_trust(r)
		return
	if n == 1:
		r.play_scene([
			{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0},
			{"say": "pell", "text": "The priests watched the whole fight from their church. That's something."},
			{"say": "brenna", "text": "They're afraid of me."},
			{"say": "pell", "text": "They're afraid of what you wear. It isn't the same."},
		])


## The Legion's waves: a column with Lysa at its head, after the relic.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	var k := LEGION_WAVES.find(n)
	if k < 0 or (k > 0 and not r.mark.has("drowned")) or r.mark.has("lost_relic"):
		return
	var at := _legion_spawn(r)
	_send_legion(r, LEGION_COLUMNS[k], at)
	var lines: Array[Dictionary] = [
		{"until": func() -> bool: return r.named_enemy("Lysa") != null, "max": 4.0},
		{"follow": func() -> Node2D: return r.named_enemy("Lysa"), "offset": Vector2(0, -40), "zoom": 1.0, "time": 2.0},
		{"wait": 1.5},
	]
	if k == 0:
		lines.append_array([
			{"say": "", "text": "Out of the mist in the north a column marches down the road towards the village, in step. At its head a captain with a crimson plume."},
			{"say": "lysa", "text": "The relic. Give it up, and the village is spared."},
			{"say": "brenna", "text": "Lysa. It's me. Hale. You sent me down the pass, the night before ..."},
			{"say": "lysa", "text": "The relic."},
			{"say": "brenna", "text": "No. Not to you, and not to him."},
		])
	else:
		lines.append_array([
			{"say": "", "text": "The Legion again, more of them, Lysa at their head. They don't come for the village. They come for the relic."},
			{"say": "lysa", "text": "The relic, Hale."},
		])
	r.play_scene(lines)


## Every quarter second: the first wave's release, the rescue, the relic, the
## leviathan.
func on_poll(r: ScenarioRunner) -> void:
	var g := r.game
	if not r.mark.has("watch") and g.waves.wave > 0:
		r.mark["watch"] = g.clock  # (wave 1 called early: the watch's goal is moot)
	if not r.mark.has("watch") and r.cutscene == null and not _shore_towers(r, true).is_empty():
		r.mark["watch"] = g.clock
		r.release_waves(FIRST_WAVE_AFTER)
		g.events.info("A watch by the shore: the first wave is coming")
	for e in g.get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).given_name == "Lysa":
			r.keep_in_sight(e, LYSA_SIGHT)
	_poll_rescue(r)
	_poll_relic(r)
	_poll_leviathan(r)


func can_win(r: ScenarioRunner) -> bool:
	return _relic_mine(r) and r.mark.has("slain")


# --- the rescue (after wave 4) -------------------------------------------------------------

func _begin_rescue(r: ScenarioRunner) -> void:
	var g := r.game
	var p := _priest(r, false)
	var o = r.mark.get("octopus")
	if p == null or not is_instance_valid(o) or (o as Enemy).dead:
		_rescued(r)  # (no octopus left to grab him: as good as rescued)
		return
	var quay := _quay(r)
	var bell: Array[Dictionary] = [{"tile": quay, "to": "the harbour", "doing": "ringing the ferry bell"}]
	p.start_rounds(bell, 600.0)
	p.max_hp *= PRIEST_HP_X
	p.hp = p.max_hp
	r.mark["rescue"] = true
	g.fog.reveal(Vector2(quay), 4.0, g.player_village.id)
	r.play_scene([
		{"camera": r.at(quay) + Vector2(0, -40), "zoom": 1.1, "time": 2.0},
		{"say": "", "text": "One of the priests walks down to the harbour to ring the ferry bell, as they do every evening. The water by the pier is very still."},
	])


## The rescue, step by step: the priest walks to the quay; there the octopus
## comes up by the pier and drags him into the shallows (unharmed while the
## scene plays); once it is over his RESCUE_HOLD seconds run. Cut free, he
## runs for the church ("fleeing"); caught again on the way, he has a new
## RESCUE_HOLD seconds. Rescued once he is inside the church.
func _poll_rescue(r: ScenarioRunner) -> void:
	if not r.mark.has("rescue"):
		return
	var p := _priest(r, false)
	var o = r.mark.get("octopus")
	if p == null or p.dead:
		_drowned(r)
		return
	if not is_instance_valid(o) or (o as Enemy).dead:
		if r.mark.has("grabbed"):
			_rescued(r)
		return
	var oct := o as Enemy
	var ob := oct.behavior as OctopusBehavior
	if not r.mark.has("grabbed"):
		if r.cutscene == null and not p.evading and p.grid_pos.distance_to(Vector2(_quay(r))) < 1.2:
			_octopus_strikes(r, oct, p)
		return
	if not r.mark.has("countdown"):
		if r.cutscene == null:  # (the scene is over: now his time runs)
			ob.grab(oct, p, RESCUE_HOLD, true)
			ob.catch_hold[p] = RESCUE_HOLD  # (caught again later: a new hold, never drowned at once)
			r.mark["arm"] = p.held_by
			r.mark["countdown"] = r.game.clock
			r.game.events.important("The octopus has the priest! Cut its arm before it drags him under.")
			r.game.player_village.toast("The octopus has the priest! Cut its arm!", UiTheme.BAD)
		return
	if is_instance_valid(p.held_by):
		if p.held_by != r.mark.get("arm"):  # (caught again: his time runs anew, the arm saw to that)
			r.mark.erase("fleeing")
			r.mark["arm"] = p.held_by
			r.mark["countdown"] = r.game.clock
			r.mark["catches"] = int(r.mark.get("catches", 1)) + 1
			r.game.events.important("The octopus has caught the priest again! Cut him free.")
			r.game.player_village.toast("The octopus has the priest again!", UiTheme.BAD)
	elif r.mark.has("fleeing"):
		if p.at_home:
			_rescued(r)
		return
	elif r.game.clock - float(r.mark["countdown"]) > 1.0:
		r.mark["fleeing"] = true
		r.mark.erase("shown_sec")
		p.rounds.clear()  # (no more bell: home, and he stays there)
		p.run_home()
		p.float_text("Free!", UiTheme.GOOD)
		r.game.events.info("The priest is free: he runs for the church")
		return
	else:
		return
	var sec := ceili(ob.hold_left(p))
	if sec != int(r.mark.get("shown_sec", -1)):
		r.mark["shown_sec"] = sec
		p.float_text("%d" % sec if sec > 0 else "Under!", Color("ff7a6a"))


## The priest at the quay: the octopus comes up by the pier and grabs him.
func _octopus_strikes(r: ScenarioRunner, oct: Enemy, p: Resident) -> void:
	var quay := _quay(r)
	var piers: Array = r.mark.get("piers", [])
	var water := _deep_by(r, quay, 7.0).filter(func(t: Vector2i) -> bool:
		return Vector2(t).distance_to(Vector2(quay)) >= OCTOPUS_OFF_PIER \
			and piers.all(func(q: Vector2i) -> bool: return Vector2(t).distance_to(Vector2(q)) >= OCTOPUS_OFF_PIER))
	if not water.is_empty():
		(oct.behavior as AquaBehavior).set_post(oct, water[0], 2.5)
		oct.set_grid_pos(Vector2(water[0]))
	oct.surface()
	(oct.behavior as OctopusBehavior).grab(oct, p, 1e6, false)  # (held, unharmed, until the scene is over)
	r.mark["grabbed"] = r.game.clock
	r.play_scene([
		{"camera": r.at(quay) + Vector2(0, -40), "zoom": 1.15, "time": 1.0},
		{"wait": 1.5},
		{"say": "", "text": "The water by the pier heaves. Grey-pink arms come up out of the sea, seize the priest and drag him off the quay into the shallows."},
		{"say": "pell", "text": "The octopus! It has him! Brenna, cut him loose before it pulls him under!"},
	])


func _rescued(r: ScenarioRunner) -> void:
	r.mark["rescued"] = true
	r.mark.erase("rescue")
	var p := _priest(r, false)
	if p and p.at_home:
		p.rounds = _rounds(r, false)  # (but he stays in the church a good while first)
		p.stay = 10.0
		p.rest_timer = RESCUED_REST
	elif p:
		p.start_rounds(_rounds(r, false), 10.0)
	if p:
		p.max_hp = Config.CIVILIAN_HP
		p.hp = minf(p.hp, p.max_hp)
	_send_octopus_home(r)
	r.game.events.info("The priest is safe")
	r.play_scene([
		{"camera": r.at(r.game.player_village.center) + Vector2(0, -40), "zoom": 1.1, "time": 1.5},
		{"say": "priest", "text": "You came for me. Into the water, for one of us."},
		{"say": "", "text": "The eldest of the priests comes to the gate at last, and doesn't keep her distance."},
		{"say": "eldest", "text": "You want to know what the abbey hides. The First King's Hand: the sword of the first king, who founded the Wardline. A relic. We hid it there and let the water in over it, before the war."},
		{"say": "brenna", "text": "Why hide it from your own side?"},
		{"say": "eldest", "text": "We are with Fiona. But we feared Rhodri could rise over her. What he would do with it, we couldn't bear to think."},
		{"say": "eldest", "text": "Its crypt is sealed, and vampires nest in it now. Something sleeps in the deep under it. And we're not the only ones who know where it lies."},
	])


func _drowned(r: ScenarioRunner) -> void:
	r.mark["drowned"] = true
	r.mark.erase("rescue")
	_send_octopus_home(r)
	r.game.hero.barred = r.game.player_village.rect  # (not even through a gate: up to the gates, no further)
	r.hero_moves_out(_tent_tile(r))
	r.game.events.important("The priest drowned. The priests shut their gates on Brenna.")
	r.play_scene([
		{"camera": r.at(r.game.player_village.center) + Vector2(0, -40), "zoom": 1.1, "time": 1.5},
		{"say": "", "text": "The ferry bell by the pier is silent. The priests carry nothing home from the harbour."},
		{"say": "eldest", "text": "You stood on our wall and watched him go under. One of Rhodri's knights."},
		{"say": "eldest", "text": "Not inside our walls. Not one more night."},
		{"say": "pell", "text": "I'll talk to them. Give it time, Brenna. Hold the shore, and they'll see."},
	])


func _send_octopus_home(r: ScenarioRunner) -> void:
	var o = r.mark.get("octopus")
	var ab := _abbey(r)
	if is_instance_valid(o) and not (o as Enemy).dead:
		((o as Enemy).behavior as OctopusBehavior).catch_hold.clear()  # (the rescue is over, one way or the other)
	if is_instance_valid(o) and not (o as Enemy).dead and ab:
		var oct := o as Enemy
		(oct.behavior as AquaBehavior).set_post(oct, ab.tile, GUARD_LEASH)


# --- the priests' trust (the drowned branch) and the crypt ------------------------------------

## After the third Legion wave the priests give in: Brenna may come home;
## the crypt is unsealed, or the relic they hold is hers.
func _trust(r: ScenarioRunner) -> void:
	r.mark["trust"] = true
	r.game.hero.barred = Rect2i()
	r.hero_moves_in()
	var scene: Array[Dictionary] = [
		{"camera": r.at(r.game.player_village.center) + Vector2(0, -40), "zoom": 1.1, "time": 1.5},
		{"say": "", "text": "In the morning the gate stands open, and the eldest priest waits in it."},
		{"say": "eldest", "text": "Three times they came for it, your own company, and three times you stood against them. Come in, knight. We trust you, a little."},
	]
	if _relic_at(r) == "crypt" and not r.mark.has("unsealed"):
		scene.append({"say": "eldest", "text": "The crypt is open now. Bring the Hand out before they come back for it."})
		_unseal(r, true)
	elif _relic_at(r) == "home":
		r.mark["given"] = true
		scene.append({"say": "eldest", "text": "And the Hand is yours to carry. We have kept it long enough."})
	r.play_scene(scene)


func _unseal(r: ScenarioRunner, quiet: bool) -> void:
	r.mark["unsealed"] = true
	var ab := _abbey(r)
	if ab:
		ab.sealed = false
		ab.refresh()
	r.game.events.info("The priests have unsealed the abbey's crypt")
	if quiet:
		return
	r.play_scene([
		{"camera": r.at(r.game.player_village.center) + Vector2(0, -40), "zoom": 1.1, "time": 1.0},
		{"say": "eldest", "text": "We saw you refuse her. Your own captain."},
		{"say": "eldest", "text": "The Legion knows where the Hand lies. Better you than them: we've unsealed the crypt. But the sword is not yours to keep, knight."},
		{"say": "brenna", "text": "I don't want it. I want it out of their reach."},
	])


# --- the relic ------------------------------------------------------------------------------

## Where the relic is: "crypt", "lysa", "ground", "hero" or "home" (in the church).
func _relic_at(r: ScenarioRunner) -> String:
	return str(r.mark.get("relic", "crypt"))


## It is home and Brenna's (in the drowned branch, once the priests gave it).
func _relic_mine(r: ScenarioRunner) -> bool:
	return _relic_at(r) == "home" and (not r.mark.has("drowned") or r.mark.has("given"))


## For the Legion (LegionCompany.relic).
func _relic_for(r: ScenarioRunner) -> Dictionary:
	var at := _relic_at(r)
	match at:
		"ground":
			return {"at": "ground", "sack": r.mark.get("sack")}
		"home":
			return {"at": "church", "church": _church(r)}
	return {"at": at}


func _poll_relic(r: ScenarioRunner) -> void:
	var g := r.game
	var v := g.player_village
	var ab := _abbey(r)
	var job := g.hero.jobs.get(Hero.Mode.EXPLORE) as HeroExploreJob
	var carried := job != null and job.task == HeroExploreJob.Task.CARRYING and job.carrying.has("item")
	match _relic_at(r):
		"crypt":
			if ab and ab.looted:
				r.mark["relic"] = "hero"
				if r.mark.has("drowned") and not r.mark.has("trust"):
					g.hero.home_override = _hand_in_tile(r)  # (she hands it in at the gate)
		"ground":
			var sack = r.mark.get("sack")
			if not is_instance_valid(sack) or (sack as Treasure).looted:
				if carried or v.items.has(RELIC):  # (picked up, maybe already home: "hero" sees to that next)
					r.mark["relic"] = "hero"
					r.mark.erase("sack")
					g.events.info("%s has the relic again" % g.hero.label())
					if r.mark.has("drowned") and not r.mark.has("trust"):
						g.hero.home_override = _hand_in_tile(r)
		"hero":
			if v.items.has(RELIC):
				r.mark["relic"] = "home"
				var ch := _church(r)
				if ch:
					ch.holds_relic = true
					ch.refresh()
				if r.mark.has("drowned") and not r.mark.has("trust"):
					g.hero.home_override = _tent_tile(r)
					r.play_scene([
						{"say": "", "text": "At the gate Brenna holds out the sword. A priest takes it without a word, and the gate closes again."},
						{"say": "pell", "text": "They have it now. It's a start."},
					])
				elif r.mark.has("trust"):
					r.mark["given"] = true
			elif not carried:  # (dropped on the way: it lies where she was)
				var sack := _find_sack(r)
				if sack:
					r.mark["relic"] = "ground"
					r.mark["sack"] = sack
	if _relic_mine(r) and not r.mark.has("slain") and not r.mark.has("asked"):
		_ask(r)


## The relic lying on the ground (a dropped "sack" with it), or null.
func _find_sack(r: ScenarioRunner) -> Treasure:
	for o in r.game.world.map_objects:
		if o is Treasure and (o as Treasure).data.get("sack", false) and not (o as Treasure).looted and (o as Treasure).reward().has("item"):
			return o
	return null


# --- the Legion -----------------------------------------------------------------------------

## Legion soldiers for the wave under way from `at`, with Lysa at their head
## (a LegionCompany after the relic): they come next, close behind each other.
func _send_legion(r: ScenarioRunner, band: Dictionary, at: Vector2i) -> void:
	var co := LegionCompany.new()
	co.name = "LegionCompany"
	co.setup(r.game, _abbey(r), func() -> Dictionary: return _relic_for(r))
	r.game.add_child(co)
	co.seal_broken.connect(func() -> void: _on_seal_broken(r))
	co.relic_taken.connect(func(from: String) -> void: _on_lysa_takes(r, from))
	co.relic_dropped.connect(func(t: Vector2i) -> void: _on_lysa_drops(r, t))
	co.escaped.connect(func() -> void:
		r.mark["lost_relic"] = true
		r.lose("Lysa got away with the First King's Hand."))
	r.mark["company"] = co
	var join := func(e: Enemy) -> void: co.join(e)
	for kind: String in band:
		r.add_enemies(kind, at, int(band[kind]), {"on_spawn": join, "gap": COLUMN_GAP}, true)
	r.add_enemies("legion_captain", at, 1, {"name": "Lysa", "art": "legion_captain_lysa", "on_spawn": join, "gap": COLUMN_GAP}, true)


func _on_seal_broken(r: ScenarioRunner) -> void:
	r.mark["unsealed"] = true
	r.game.events.important("The Legion has broken the crypt's seal!")
	_wake_leviathan(r, false)


func _on_lysa_takes(r: ScenarioRunner, from: String) -> void:
	var v := r.game.player_village
	if from == "church":
		v.items.erase(RELIC)
		var ch := _church(r)
		if ch:
			ch.holds_relic = false
			ch.refresh()
	elif from == "crypt":
		var ab := _abbey(r)
		if ab:
			ab.mark_looted()
	r.mark["relic"] = "lysa"
	r.mark.erase("sack")
	r.mark.erase("given")
	r.game.events.important("Lysa has the First King's Hand! Stop her before she reaches the edge of the map.")
	v.toast("Lysa has the relic! Stop her!", UiTheme.BAD)


func _on_lysa_drops(r: ScenarioRunner, t: Vector2i) -> void:
	var sack := r.game.world.add_dropped_loot(t, {"item": RELIC})
	r.mark["relic"] = "ground"
	r.mark["sack"] = sack
	r.game.fog.reveal(Vector2(t), 3.0, r.game.player_village.id)
	r.game.events.important("Lysa falls back and drops the relic! Send Brenna exploring to take it back.")


# --- the leviathan -------------------------------------------------------------------------

## The leviathan rises by the island (`by_hero`: Brenna went into the crypt;
## then it blocks the crypt until it is slain).
func _wake_leviathan(r: ScenarioRunner, by_hero: bool) -> void:
	if r.mark.has("woken"):
		return
	r.mark["woken"] = true
	var g := r.game
	var ab := _abbey(r)
	var at: Array[Vector2i] = _deep_by(r, ab.tile, 9.0) if ab else ([] as Array[Vector2i])
	if not at.is_empty():
		var lev := g.waves.spawn_at("leviathan", at[mini(3, at.size() - 1)], g.player_village, maxi(g.waves.wave, 1))
		if lev:
			lev.set_identity("Leviathan", "")
			lev.max_hp *= LEVIATHAN_HP
			lev.hp = lev.max_hp
			lev.power = LEVIATHAN_POWER
			r.mark["leviathan"] = lev
	if by_hero and ab:
		ab.blocked = "The leviathan coils round the island: nobody gets into the crypt while it lives."
		var job := g.hero.jobs.get(Hero.Mode.EXPLORE) as HeroExploreJob
		if job and job.obj == ab:
			job.release()
			g.hero.head_home()
	g.events.important("The leviathan rises from the river!")
	var scene: Array[Dictionary] = [
		{"camera": r.at(ab.tile if ab else g.player_village.center) + Vector2(0, -40), "zoom": 1.0, "time": 1.5},
		{"say": "", "text": "The bell under the water stops. The river heaves, and something long and dark rises out of it and coils round the island."},
	]
	if by_hero:
		scene.append({"say": "pell", "text": "Brenna! Get off that island! Nobody's getting into that crypt while it lives."})
	else:
		scene.append({"say": "pell", "text": "They broke the seal, and woke it. And Lysa's still in there!"})
	r.play_scene(scene)


func _poll_leviathan(r: ScenarioRunner) -> void:
	var g := r.game
	var ab := _abbey(r)
	if not r.mark.has("woken") and ab and not ab.sealed and _relic_at(r) == "crypt":
		var job := g.hero.jobs.get(Hero.Mode.EXPLORE) as HeroExploreJob
		if job and job.obj == ab and job.task == HeroExploreJob.Task.WORKING:
			_wake_leviathan(r, true)
	if not r.mark.has("woken") or r.mark.has("slain"):
		return
	var lev = r.mark.get("leviathan")
	if lev == null or not is_instance_valid(lev) or (lev as Enemy).dead:
		r.mark["slain"] = true
		if ab:
			ab.blocked = ""
		g.events.info("The leviathan is slain")
		r.play_scene([
			{"say": "", "text": "The leviathan sinks, and does not come up again. The river runs still."},
			{"say": "eldest", "text": "Knight. When this is over, come to our door."},
		])
		return
	# Its goal: a boat coming in, else the crypt while the relic is in it, else the harbour's shore.
	var e := lev as Enemy
	var post := _pier_end(r)
	var leash := SHORE_LEASH
	if is_instance_valid(r.mark.get("boat")):
		post = _pier_end(r)
		leash = PIER_LEASH
	elif _relic_at(r) == "crypt" and ab:
		post = ab.tile
		leash = CRYPT_LEASH
	if post != e.post:
		(e.behavior as AquaBehavior).set_post(e, post, leash)


# --- the priests' request, the messenger and the decree ------------------------------------

## The relic is home, the leviathan lives: the priests ask Brenna to slay it.
func _ask(r: ScenarioRunner) -> void:
	r.mark["asked"] = true
	r.play_scene([
		{"camera": r.at(r.game.player_village.center) + Vector2(0, -40), "zoom": 1.1, "time": 1.5},
		{"say": "eldest", "text": "The Hand is safe. But the thing in the river is awake now, and it won't sleep again. Our boats, our shore, our children on the pier."},
		{"say": "eldest", "text": "Kill it, knight, before you go. For us.", "choices": [
			{"text": "We'll kill it.", "do": func() -> void: r.mark["hunt"] = true},
			{"text": "We have to go. Fiona needs the Hand.", "do": func() -> void: _messenger(r)},
		]},
	])


func _messenger(r: ScenarioRunner) -> void:
	r.mark["messenger"] = r.game.waves.wave
	r.game.events.info("The priests send a messenger to Fiona")
	r.play_scene([
		{"say": "eldest", "text": "Then we'll ask her ourselves. A boat leaves tonight."},
		{"say": "", "text": "A young priest rows out past the pier with a letter sealed in wax, and the mist takes him."},
	])


## The messenger is back with Fiona's decree: the leviathan first.
func _decree(r: ScenarioRunner) -> void:
	r.mark["decree"] = true
	r.mark["hunt"] = true
	r.play_scene([
		{"camera": r.at(_quay(r)) + Vector2(0, -40), "zoom": 1.1, "time": 1.5},
		{"say": "", "text": "The messenger is back, soaked to the skin, a letter in his hand. The seal on it is Fiona's."},
		{"say": "priest", "text": "\"To Brenna Hale, knight: the people of the drowned shore have kept the Hand for the crown. Rid their water of the beast before you leave them. You are urgently requested. Fiona of House Aldmoor.\""},
		{"say": "brenna", "text": "Then we kill it."},
	])


# --- the harbour ------------------------------------------------------------------------------

## A guild boat sails in to the pier; its goods go to Pell's stall by cart.
## While the leviathan lives it goes for the boat, and sinks it.
func _send_boat(r: ScenarioRunner) -> void:
	var g := r.game
	var pier := _pier_end(r)
	var from := Vector2i(pier.x, g.map.size - 1)
	var p := g.world.pathing.water_path(from, pier)
	if p.size() < 2:
		p = PackedVector2Array([Vector2(from), Vector2(pier)])
	var boat := r.actor("boat_supply", Vector2(from))
	r.mark["boat"] = boat
	var tw := boat.create_tween()
	for i in range(1, p.size()):
		tw.tween_property(boat, "position", Iso.to_world(p[i]), p[i].distance_to(p[i - 1]) / BOAT_SPEED)
	tw.tween_callback(func() -> void: _boat_in(r, boat))
	g.events.info("A guild boat is coming in")


func _boat_in(r: ScenarioRunner, boat: Node2D) -> void:
	var g := r.game
	var lev = r.mark.get("leviathan")
	r.mark.erase("boat")
	if is_instance_valid(lev) and not (lev as Enemy).dead:
		Combat.burst(g, "splash", boat.position + Vector2(0, -10), 1.6)
		var sink := boat.create_tween()
		sink.tween_property(boat, "modulate:a", 0.0, 1.2)
		sink.parallel().tween_property(boat, "position", boat.position + Vector2(0, 18), 1.2)
		sink.tween_callback(boat.queue_free)
		g.events.important("The leviathan sank the guild's boat: its goods are lost")
		return
	var stall := _stall(r)
	var to := stall.tile if stall else g.player_village.center
	var road: Array[Vector2i] = []
	for q in g.world.pathing.find_path(_quay(r), to):
		road.append(Vector2i(q.round()))
	if road.size() >= 2:
		var cart := ScenarioCaravan.new()
		cart.setup(g, road, BOAT.duplicate())
		g.world.objects.add_child(cart)
	var leave := boat.create_tween()
	leave.tween_interval(6.0)
	leave.tween_property(boat, "modulate:a", 0.0, 1.5)
	leave.tween_callback(boat.queue_free)
	g.events.info("Pell's guild boat is in: its goods go to his stall")


## The harbour's scenery (it never changes; nothing can be built where it
## stands on land: ScenarioRunner.keep_free): two piers with moored boats,
## the ferry bell at the quay, crates, nets, fish racks, upturned boats,
## mooring posts and driftwood along the beach; on the river's bank near the
## sea a beacon, a wreck in the shallows beside it, and gulls circling it.
func _build_harbour(r: ScenarioRunner) -> void:
	var q := _quay(r)
	var piers: Array[Vector2i] = []
	piers.append_array(_pier(r, q))
	r.actor("boat", Vector2(q + Vector2i(1, 2)))
	r.actor("boat", Vector2(q + Vector2i(-1, 3)))
	var taken: Array[Vector2i] = [q]
	var q2 := _second_quay(r)
	if q2.x >= 0:
		taken.append(q2)
		r.keep_free(q2, "pier")
		piers.append_array(_pier(r, q2))
		for b: Array in SECOND_PIER_BOATS:
			var w: Vector2i = q2 + (b[1] as Vector2i)
			if r.game.map.is_water(w):
				r.actor(str(b[0]), Vector2(w))
		_props(r, q2, SECOND_PIER_PROPS, taken)
	r.mark["piers"] = piers
	_props(r, q, HARBOUR_PROPS, taken)
	var bank := _free_shore(r, q + BEACON_OFFSET, taken, false)
	if bank.x < 0:
		return
	taken.append(bank)
	r.keep_free(bank, PROP_NAMES["beacon"])
	r.mark["beacon"] = bank
	r.actor("beacon", Vector2(bank))
	var wet := _free_shore(r, bank + Vector2i(1, 1), taken, true)
	if wet.x >= 0:
		r.actor("wreck", Vector2(wet))
	for k in GULLS:
		_gull(r, Vector2(bank), k)


## A pier from `land` out over the water (up to 3 tiles): its tiles on the water.
func _pier(r: ScenarioRunner, land: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(1, 4):
		var t := land + Vector2i(0, i)
		if r.game.map.is_water(t):
			r.actor("pier", Vector2(t))
			out.append(t)
	return out


## Scenery `list` ([art, offset from `at`, flipped]) on the free shore tiles
## nearest their spots, each tile then kept free of buildings.
func _props(r: ScenarioRunner, at: Vector2i, list: Array, taken: Array[Vector2i]) -> void:
	for prop: Array in list:
		var t := _free_shore(r, at + (prop[1] as Vector2i), taken, false)
		if t.x < 0:
			continue
		taken.append(t)
		var n := r.actor(str(prop[0]), Vector2(t))
		n.get_child(0).flip_h = bool(prop[2])
		r.keep_free(t, str(PROP_NAMES.get(prop[0], "harbour")))


## The second pier's land end: the shore tile nearest SECOND_PIER from the
## quay with two tiles of water in front of it (south), off the roads; (-1, -1) if none.
func _second_quay(r: ScenarioRunner) -> Vector2i:
	var m := r.game.map
	var want := _quay(r) + SECOND_PIER
	var best := Vector2i(-1, -1)
	for dy in range(-3, 4):
		for dx in range(-4, 5):
			var t := want + Vector2i(dx, dy)
			if not m.in_bounds(t) or m.is_water(t) or not m.is_passable(t) or m.is_road(t):
				continue
			if not (m.is_water(t + Vector2i.DOWN) and m.is_water(t + Vector2i(0, 2))):
				continue
			if best.x < 0 or Vector2(t).distance_to(Vector2(want)) < Vector2(best).distance_to(Vector2(want)):
				best = t
	return best


## The open land tile nearest `want` that is by the water (`wet`: a shallow
## water tile by the land instead), not a road, building or other prop; (-1, -1) if none.
func _free_shore(r: ScenarioRunner, want: Vector2i, taken: Array[Vector2i], wet: bool) -> Vector2i:
	var g := r.game
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var t := want + Vector2i(dx, dy)
			if not g.map.in_bounds(t) or taken.has(t) or g.map.buildings.has(t) or g.map.is_road(t) or g.map.in_village(t):
				continue
			var near_land := false
			var near_water := false
			for n in MapData.neighbors4(t):
				if g.map.in_bounds(n):
					near_water = near_water or g.map.is_water(n)
					near_land = near_land or (not g.map.is_water(n) and g.map.is_passable(n))
			var ok := (g.map.get_terrain(t) == MapData.Terrain.SHALLOW and near_land) if wet \
				else (g.map.is_passable(t) and not g.map.is_water(t) and not g.map.is_forest(t) and near_water)
			var d := Vector2(dx, dy).length()
			if ok and d < best_d:
				best_d = d
				best = t
	return best


## Gull `k` circling `over` (a tile) for good, high up, at its own pace.
func _gull(r: ScenarioRunner, over: Vector2, k: int) -> void:
	var n := r.actor("gull", over)
	var centre := Iso.to_world(over) + Vector2(0, -150 - 20 * k)
	var rx := 70.0 + 22.0 * k
	var period := 7.0 + 2.5 * k
	var tw := n.create_tween().set_loops()
	tw.tween_method(func(a: float) -> void:
		n.position = centre + Vector2(cos(a) * rx, sin(a) * rx * 0.4)
		(n.get_child(0) as Sprite2D).flip_h = sin(a) < 0.0, k * 2.1, k * 2.1 + TAU, period)


# --- the cards, hints and objectives --------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "A watch on the water",
			"text": "Crabs climb out of the sea and the river. Build a watchtower by the water so it covers the shore. Once it stands, the first wave is on its way.",
			"done": func() -> bool: return r.mark.has("watch"),
			"point": func() -> Dictionary:
				# Placed: its site while it is built; else placing one.
				var mine := _shore_towers(r, false)
				return r.place_point("tower", []) if mine.is_empty() else {"tiles": r.first_tiles(mine)}},
		{"title": "The First King's Hand",
			"text": "The crypt is open. Clear the Fallen Abbot and his vampires at the abbey (tap their camp: Attack with the hero), then send Brenna exploring: she goes into the crypt for the relic.",
			"ready": func() -> bool: return _abbey(r) == null or not _abbey(r).sealed,
			"wait_title": "The abbey",
			"wait_text": "The crypt is sealed. Hold the village, and win the priests' trust.",
			"done": func() -> bool: return r.mark.has("woken") or _relic_at(r) != "crypt",
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
		{"id": "rescue",
			"when": func() -> bool: return r.mark.has("countdown") and r.mark.has("rescue"),
			"text": "The octopus holds the priest in the shallows: cut its arm (a target of its own) with towers, ranged units or Brenna before it drags him under (%d s)." % int(RESCUE_HOLD)},
		{"id": "ruins",
			"when": func() -> bool: return (r.mark.has("rescued") or r.mark.has("drowned")) and r.cutscene == null,
			"text": "On the abbey's island stand two ruined watchtowers and a ruined barracks. Clear the Fallen Abbot's camp, send Brenna exploring to claim them, then restore them (tap a ruin): the abbey can be held from there."},
		{"id": "legion",
			"when": func() -> bool: return r.enemy_about("legion_captain"),
			"text": "The Legion doesn't come for the village: it comes for the relic. At the abbey they break its seal, and Lysa searches the crypt. Beaten, she drops what she carries."},
		{"id": "lysa_relic",
			"when": func() -> bool: return _relic_at(r) == "lysa",
			"text": "Lysa has the relic and walks it back to the map edge. Stop her: beaten, she drops it."},
		{"id": "relic_ground",
			"when": func() -> bool: return _relic_at(r) == "ground",
			"text": "The relic lies on the ground. Brenna picks it up in Explore mode; Lysa's soldiers stand round it."},
		{"id": "necromancer",
			"when": func() -> bool: return r.enemy_about("necromancer"),
			"text": "A necromancer: it raises the drowned dead on the island. Acolytes' holy light hurts it most."},
		{"id": "vampire",
			"when": func() -> bool: return r.enemy_about("vampire"),
			"text": "A vampire: it heals from its hits, and beaten it becomes a bat for a while that only ranged attacks reach."},
		{"id": "siren",
			"when": func() -> bool: return r.enemy_about("siren"),
			"text": "A siren sings from the water: our people are drawn to her and fight slower. Towers and ranged units reach her."},
		{"id": "leviathan",
			"when": func() -> bool: return r.mark.has("woken"),
			"text": "The leviathan blasts whoever is near the water from 4.6 tiles: only level 3 watchtowers and wall towers outrange it. While it lives it sinks Pell's boats."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and here nobody can bring her back. Send her to rest (her panel: Rest) until she has healed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	return [
		{"id": "watch", "text": "Build a watchtower by the shore",
			"done": func() -> bool: return r.mark.has("watch"),
			"gone": func() -> bool: return r.mark.has("watch") and r.game.clock - float(r.mark["watch"]) > WATCH_GOAL_STAYS,
			"detail": func() -> String: return "" if r.mark.has("watch") else "then wave 1 comes"},
		{"id": "rescue", "text": "Save the priest from the octopus", "optional": true,
			"shown": func() -> bool: return r.mark.has("countdown") or (r.mark.has("drowned") and r.mark.has("grabbed")),
			"done": func() -> bool: return r.mark.has("rescued"),
			"failed": func() -> bool: return r.mark.has("drowned"),
			"detail": func() -> String:
				if r.mark.has("drowned"):
					return "drowned"
				var o = r.mark.get("octopus")
				var p := _priest(r, false)
				if r.mark.has("rescued") or p == null or not is_instance_valid(o):
					return ""
				if r.mark.has("fleeing"):
					return "running for the church"
				return "%d s" % ceili(((o as Enemy).behavior as OctopusBehavior).hold_left(p))},
		{"id": "abbey", "text": "Keep the relic from the Legion", "optional": true,
			"shown": func() -> bool: return r.mark.has("company"),
			"done": func() -> bool: return not _legion_about(r) and _relic_at(r) != "lysa",
			"detail": func() -> String:
				var ab := _abbey(r)
				if _relic_at(r) == "lysa":
					return "Lysa has it!"
				return "seal %d %%" % roundi(100.0 * ab.seal_hp / SEAL_HP) if ab and ab.sealed and _legion_about(r) else ""},
		{"id": "relic", "text": "Bring the First King's Hand home",
			"done": func() -> bool: return _relic_mine(r),
			"detail": func() -> String:
				match _relic_at(r):
					"crypt": return "sealed" if _abbey(r) and _abbey(r).sealed else "in the crypt"
					"lysa": return "Lysa has it"
					"ground": return "on the ground"
					"hero": return "on the way"
					"home": return "home" if _relic_mine(r) else "the priests keep it"
				return ""},
		{"id": "leviathan", "text": "Slay the leviathan",
			"shown": func() -> bool: return r.mark.has("hunt") or r.mark.has("slain") or (_abbey(r) != null and _abbey(r).blocked != ""),
			"done": func() -> bool: return r.mark.has("slain")},
	]


## The abbey sealed, holding the relic; the guard octopus in the deep water
## beside it; the drowned dead on the island; the priests' rounds; the harbour.
func on_start(r: ScenarioRunner) -> void:
	var g := r.game
	r.mark["towers0"] = r.towers()  # (the first wave waits for one of the player's by the shore)
	r.mark["relic"] = "crypt"
	_build_harbour(r)
	var both: Array = g.population.civilians.filter(func(c: Civilian) -> bool: return c is Resident and c.role == "priest")
	if both.size() >= 2:
		(both[0] as Civilian).given_name = ELDEST
		(both[1] as Civilian).given_name = YOUNGER
		Art.apply((both[0] as Civilian).sprite, "unit_eldest_priest")
	var eldest := _priest(r, true)
	var younger := _priest(r, false)
	var church := _church(r)
	for p: Resident in [eldest, younger]:
		if p:
			if church:
				p.home_tile = _church_door(r)  # (they live in the church: in and out of its door)
				p.set_grid_pos(Vector2(p.home_tile))
			p.rounds = _rounds(r, p == eldest)
			p.stay = 10.0
	var ab := _abbey(r)
	if ab == null:
		return
	ab.sealed = true
	ab.seal_max = SEAL_HP
	ab.seal_hp = SEAL_HP
	ab.data["reward"] = {"item": RELIC}
	g.fog.reveal(Vector2(ab.tile), 4.0, g.player_village.id)
	var camp := ab.guard()
	if camp:  # (the first of its vampires is the Fallen Abbot)
		for e in camp.monsters:
			if e.kind == "vampire" and not r.mark.has("abbot"):
				e.max_hp *= ABBOT_HP
				e.power = ABBOT_POWER
				e.set_identity(ABBOT, "")
				r.mark["abbot"] = e
			else:
				e.max_hp *= CAMP_GUARD_HP
			e.hp = e.max_hp
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
		var t := ab.tile + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
		if g.map.is_passable(t) and not g.map.is_road(t) and not g.map.buildings.has(t) and not g.map.is_water(t):
			g.corpses.spawn_fallen(Vector2(t) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))
			placed += 1


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. %s must not die." % [civ.label(), reason, "The eldest priest" if civ.given_name == ELDEST else "Pell"]


# --- helpers -----------------------------------------------------------------------------

## The drowned abbey (the map's abbey treasure), or null.
func _abbey(r: ScenarioRunner) -> Treasure:
	for o in r.game.world.map_objects:
		if o is Treasure and str((o as Treasure).data.get("treasure", "")) == "abbey":
			return o
	return null


func _church(r: ScenarioRunner) -> Church:
	for b in r.game.player_village.buildings():
		if b is Church:
			return b
	return null


func _stall(r: ScenarioRunner) -> Building:
	var list := r.stalls()
	return list[0] if not list.is_empty() else null


## The eldest priest (`eldest`), or the younger one; null if gone. (The
## younger is the one the octopus grabs; drowned, he is gone for good.)
func _priest(r: ScenarioRunner, eldest: bool) -> Resident:
	var who := ELDEST if eldest else YOUNGER
	for c in r.game.population.civilians:
		if c is Resident and c.given_name == who and not c.dead:
			return c
	return null


## A priest's rounds out of the church (their home): the eldest to the north
## gate, looking out over the river; the younger to the harbour.
func _rounds(r: ScenarioRunner, eldest: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if eldest:
		out.append({"tile": _hand_in_tile(r), "to": "the east gate", "doing": "looking out over the river"})
	else:
		out.append({"tile": _quay(r), "to": "the harbour", "doing": "blessing the boats"})
	return out


## The church's door: the tile in front of it (where its priests go in and out).
func _church_door(r: ScenarioRunner) -> Vector2i:
	var ch := _church(r)
	return ch.tile + Vector2i(0, 2) if ch else r.game.player_village.center


## The quay: the harbour road's end at the water (below the south gate).
func _quay(r: ScenarioRunner) -> Vector2i:
	var t := r.game.player_village.center
	while r.game.map.in_bounds(t + Vector2i.DOWN) and not r.game.map.is_water(t + Vector2i.DOWN):
		t += Vector2i.DOWN
	return t


## Where boats tie up: the pier's far end (on the water).
func _pier_end(r: ScenarioRunner) -> Vector2i:
	var q := _quay(r)
	var t := q
	for i in range(1, 4):
		if r.game.map.is_water(q + Vector2i(0, i)):
			t = q + Vector2i(0, i)
	return t


## Where Brenna hands the relic in while she is shut out: outside the east
## gate (the one towards the island).
func _hand_in_tile(r: ScenarioRunner) -> Vector2i:
	var v := r.game.player_village
	return Vector2i(v.rect.end.x, v.center.y + 1)


## Brenna's tent while the priests shut her out: open land near TENT_OFFSET.
func _tent_tile(r: ScenarioRunner) -> Vector2i:
	if r.mark.has("tent"):
		return r.mark["tent"]
	var g := r.game
	var want := g.player_village.center + TENT_OFFSET
	var best := want
	var best_d := INF
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var t := want + Vector2i(dx, dy)
			if not g.map.in_bounds(t) or g.map.in_village(t) or g.map.is_road(t) or not g.world.pathing.is_walkable(t) or g.map.buildings.has(t):
				continue
			var d := Vector2(dx, dy).length()
			if d < best_d and g.world.pathing.can_reach(g.player_village.center, t):
				best_d = d
				best = t
	r.mark["tent"] = best
	return best


func _legion_about(r: ScenarioRunner) -> bool:
	return r.game.get_tree().get_nodes_in_group("enemies").any(func(e: Node) -> bool: return str((e as Enemy).kind).begins_with("legion_") and not (e as Enemy).dead)


## Deep tiles within `reach` of `t`, nearest first.
func _deep_by(r: ScenarioRunner, t: Vector2i, reach: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var k := ceili(reach)
	for dy in range(-k, k + 1):
		for dx in range(-k, k + 1):
			var q := t + Vector2i(dx, dy)
			if r.game.map.is_deep(q) and not r.game.map.is_bridge(q) and Vector2(q).distance_to(Vector2(t)) <= reach:
				out.append(q)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(Vector2(t)) < Vector2(b).distance_to(Vector2(t)))
	return out


## The Legion's edge spawn: the north road's, on the north edge (west of the
## river; the east road's spawn is in the north-east corner, on the east edge).
func _legion_spawn(r: ScenarioRunner) -> Vector2i:
	for sp in r.game.map.edge_spawns:
		if sp.y == 0:
			return sp
	var ab := _abbey(r)
	return r.spawn_near(ab.tile if ab else r.game.player_village.center)


## The player's own watchtowers by the shore (not the prebuilt ones):
## finished ones only (`built`), or sites too.
func _shore_towers(r: ScenarioRunner, built: bool) -> Array:
	var towers0: Array = r.mark.get("towers0", [])
	return r.towers().filter(func(t: Building) -> bool: return not towers0.has(t) and (t.complete or not built) and _by_water(r, t.tile))


## A tile within 3 of deep water.
func _by_water(r: ScenarioRunner, t: Vector2i) -> bool:
	return not _deep_by(r, t, 3.0).is_empty()
