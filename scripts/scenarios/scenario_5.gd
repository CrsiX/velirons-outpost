extends Scenario
## Scenario 5: The Betrayal (docs/scenarios-design.md §3.5, §7.9; docs/story-design.md).
## Brenna's old fort, a citadel filling the only pass through the mountains
## that split the land: whole, and empty. Brenna and Pell come alone; the fort
## holds four people. Sigmund, an old veteran camping in the south, joins once
## found (and the waves begin), and tells over the first waves what happened
## the night her company was given to the crown's ritual. Three pieces of
## evidence lie on both sides of the range (treasures, the two in the northern
## wilderness guarded by camps): the order, the roll of the fallen, a foreign
## seal. Ten waves from both sides; witches and gargoyles join, and in the
## last one the first Dread Legion patrol comes down the pass, led by Brenna's
## old captain Lysa and her comrade Torben (captains: they fall back, they
## don't fall), while the gargoyles above the pass come alive. Brenna can't be
## brought back.


func _init() -> void:
	number = 5
	title = "The Betrayal"
	blurb = "Brenna goes back to the fort in the pass where her company was left to its fate. Find out what happened there, and hold the pass while you do."
	map_path = "res://data/maps/old_fort.json"
	place = "old_fort"
	portrait = "portrait_sigmund"

	# The baseline: the fort whole and empty, its four huts, two barracks and
	# training grounds inside; only Pell, his wagon (a peddler's stall again)
	# outside the south gate. No farm.
	difficulty = "easy"
	enemy_scale = {"hp": 0.95, "damage": 0.95, "spell_damage": 0.95}
	resources = {"gold": 220, "food": 150, "materials": 220}
	civilians = ["merchant"]
	names = {"merchant": "Pell"}
	buildings = []
	build_inside = true
	piece_levels = {"gate": 2}
	prebuilt = [
		{"kind": "stall", "offset": Vector2i(2, 7), "level": 1},
		{"kind": "barracks", "offset": Vector2i(-3, -3)},
		{"kind": "training", "offset": Vector2i(-3, 1)},
		{"kind": "barracks", "offset": Vector2i(1, 1)},
	]
	hero_name = "Brenna"
	hero_level = 7

	units = ["archer", "shield_bearer"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell"]

	# Wilderness and Renegades, then the first Arcane: witches from wave 3,
	# gargoyles from wave 6, from both sides of the range. Wave 10 brings the
	# Legion (on_wave_started adds it, down the pass, with its captains, and
	# the gargoyles above the pass).
	waves = [
		{"kinds": {"goblin": 6}, "rat_packs": [4], "spawns": 2, "lairs": true},
		{"kinds": {"goblin": 6, "ork": 1, "thief": 2}, "spawns": 3, "lairs": true},
		{"kinds": {"goblin": 6, "ork": 2, "witch": 1}, "spawns": 3, "lairs": true},
		{"kinds": {"goblin": 6, "ork": 2, "witch": 1, "thief": 2}, "rat_packs": [5], "spawns": 3, "lairs": true},
		{"kinds": {"goblin": 7, "ork": 2, "witch": 2, "slime3": 1}, "spawns": 4, "lairs": true},
		{"kinds": {"goblin": 7, "ork": 3, "witch": 1, "gargoyle": 1, "thief": 2}, "rat_packs": [5], "spawns": 4, "lairs": true},
		{"kinds": {"goblin": 8, "ork": 3, "witch": 2, "gargoyle": 1}, "spawns": 4, "lairs": true},
		{"kinds": {"goblin": 8, "ork": 3, "witch": 2, "gargoyle": 2, "thief": 3}, "rat_packs": [6], "spawns": 4, "lairs": true},
		{"kinds": {"goblin": 9, "ork": 4, "witch": 2, "gargoyle": 2, "slime3": 2}, "rat_packs": [6], "spawns": 4, "lairs": true},
		{"kinds": {"goblin": 6, "ork": 2}, "spawns": 2, "lairs": true},
	]
	# The hollow tree in the northern forest (the map's only lair) wakes at
	# wave 6, or as soon as it is found (on_poll), and sends its theme with
	# every wave from then on; cleared, it stays cleared.
	lairs = [{"wake": LAIR_WAVE}]
	# Wave 1 waits until Sigmund is found (on_poll releases it).
	first_wave_waits = true
	first_wave_call = false
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"sigmund": {"name": "Sigmund", "portrait": "portrait_sigmund", "color": Color("c8b090")},
		"lysa": {"name": "Lysa", "portrait": "portrait_lysa", "color": Color("c8ccd8")},
	}


## Where Sigmund camps, south of the range (the map tool prints it:
## tools/make_scenario_map.gd 5); he stands beside his tent.
const SIGMUND_TENT := Vector2i(24, 54)


## The Legion patrol of the last wave (down the pass), and the gargoyles that
## come alive on the rocks above the pass.
const LEGION := {"legion_footman": 8}
## They ride (docs/enemies-design.md §15e): their horses' HP.
const CAPTAINS: Array[Dictionary] = [
	{"name": "Lysa", "art": "legion_captain_lysa", "mount": "horse", "mount_hp": 60.0},
	{"name": "Torben", "art": "legion_captain", "mount": "horse", "mount_hp": 60.0},
]
const GATE_GARGOYLES := 3
## The wave the lair wakes at, unless it is found before.
const LAIR_WAVE := 6
## Seconds from Sigmund found to wave 1.
const FIRST_WAVE_AFTER := 10.0

## The three pieces of evidence, in the order they are found.
const EVIDENCE: Array[Dictionary] = [
	{"title": "Rhodri's order",
		"text": "Sealed with the crown, to the garrison of the pass:\n\n\"Hold until the last. Do not ask for relief. Relief will not come.\n\nThe crown will come to you itself, on the night after the new moon. Have the company drawn up on the field, unarmed, to receive it.\"\n\nSigned with a single R."},
	{"title": "The roll of the fallen",
		"text": "The roll of the company of the pass, \"fallen to the last\":\n\nLysa Varr, captain. Torben Ashe. Mael. Corin. Old Hesk. Dagny. Wilm the Younger. Brenna Hale ...\n\nForty-one names, the ink all one colour, written on one day. Not one of them is marked with a grave."},
	{"title": "A foreign seal",
		"text": "A wax seal, broken off a letter that is long gone: a tower over three waves, pressed by a hand that knew its work.\n\nPell has seen it before, on the guild's letters from abroad. He can't say from which court. Neither can anyone else, it seems, and maybe that is the point."},
]


# --- the story -----------------------------------------------------------------------------

# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var north := r.road_in(c + Vector2i(0, -30), 12)
	var field: Vector2 = r.at(north[0]) if not north.is_empty() else r.at(c)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 0.95, "time": 0.01},
		{"title": "The Betrayal", "sub": "Scenario 5", "time": 3.0},
		{"say": "", "text": "The fort in the pass. Brenna has not seen it since the night she rode down that road."},
		{"fade": "in", "time": 1.2},
		{"say": "brenna", "text": "The walls are whole. The gates stand open. And not a soul on them."},
		{"say": "pell", "text": "No smoke, no guard, not even a dog. Brenna, a fort this size doesn't empty itself."},
		{"say": "brenna", "text": "It did once. Forty-one of us held it, and one morning nobody was left."},
		{"camera": field + Vector2(0, -30), "zoom": 1.0, "time": 3.0},
		{"say": "brenna", "text": "Out there, below the north wall. That's where the company stood that night."},
		{"say": "pell", "text": "You don't have to do this."},
		{"say": "brenna", "text": "I do. The roll says they died here. I want to know who wrote it, and why. Whatever was left behind lies out in the hills, on both sides of the pass."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 2.0},
		{"say": "pell", "text": "Then I'll set up the wagon outside the south gate. If anyone still comes up this road, they'll want something to eat."},
		{"say": "", "text": "Find the three pieces of evidence, north and south of the mountains, and hold the fort for ten waves. The fort holds four people: Pell and three more. Brenna can't be brought back here, and Pell must not die."},
	]


## Sigmund found by his tent: he joins, and the beasts aren't far behind.
func _sigmund_scene(r: ScenarioRunner) -> Array[Dictionary]:
	return [
		{"camera": r.at(SIGMUND_TENT) + Vector2(0, -40), "zoom": 1.1, "time": 1.5},
		{"say": "", "text": "A tent on the plain below the pass, and an old man beside it, leaning on a spear more than holding it."},
		{"say": "sigmund", "text": "Well. Brenna Hale. Every name on that roll is dead, they say, yours too. You look well for a dead woman."},
		{"say": "brenna", "text": "Sigmund! The fort is empty. Where is everyone?"},
		{"say": "sigmund", "text": "Gone. Some marched, some ran. I couldn't sleep inside those walls after that night, so I sleep out here."},
		{"say": "sigmund", "text": "But if you're holding the fort again, I'll come back. Somebody has to mend your walls. And ready them: the beasts know it's empty. They'll come from both sides."},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	return [
		{"do": func() -> void: r.dusk(3.0)},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "The patrol is gone back up the pass. In the barracks, by the last of the light, Brenna unfolds the order."},
		{"say": "brenna", "text": "\"Hold until the last. Do not ask for relief.\""},
		{"say": "brenna", "text": "He gave them to his crown, Pell. All of them. Lysa sent me away that night, and that's the only reason I'm not marching behind her."},
		{"say": "pell", "text": "And the seal?"},
		{"say": "brenna", "text": "Someone abroad made him what he is. I can't fight a seal. But I can't stand aside any more either."},
		{"say": "brenna", "text": "The only one left who can stand against him is his sister. I'm going to find Fiona."},
		{"say": "pell", "text": "Her court fled east, they say. The way there crosses the field where the armies met."},
		{"say": "brenna", "text": "Then we cross it. The dead of this pass were never buried either."},
		{"fade": "out", "time": 1.5},
	]


## Sigmund tells it, a piece after each of the first waves.
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var c := r.game.player_village.center
	var lines: Array[Dictionary] = []
	match n:
		1:
			lines = [
				{"say": "sigmund", "text": "You want to know about that night. Lysa sent you down the pass, the night before. I saw you ride."},
				{"say": "brenna", "text": "With a plea for relief. Nobody at the bottom would even read it."},
				{"say": "sigmund", "text": "She said to me: if relief comes, it comes because of Hale. She knew, I think. Or she guessed."},
			]
		2:
			lines = [
				{"say": "sigmund", "text": "The next evening he came himself. Rhodri. Up the pass with his mages, and the crown on his head, shining like a cold moon."},
				{"say": "brenna", "text": "I saw it from the ridge. I was riding back. I was too late."},
			]
		3:
			lines = [
				{"say": "sigmund", "text": "He had them drawn up on the field. No weapons. He said the crown would keep them safe."},
				{"say": "brenna", "text": "They knelt, all of them. The light went out of the crown and into them. And when they stood up, they weren't looking at anything."},
			]
		5:
			lines = [
				{"say": "sigmund", "text": "I hid in the cellar like the old coward I am. When I came out, they were gone. Marching. Not one body on that field."},
				{"say": "brenna", "text": "Because nobody died. He didn't kill them, Sigmund. He bound them to him."},
			]
		7:
			lines = [
				{"say": "pell", "text": "Brenna. If they're alive, what are they now?"},
				{"say": "brenna", "text": "His. Whatever he tells them, they do. Like a hand on a puppet."},
			]
	if lines.is_empty():
		return
	var scene: Array[Dictionary] = [{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0}]
	scene.append_array(lines)
	r.play_scene(scene)




## Wave 10: the Legion comes down the pass, and the gargoyles above it wake.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n != waves.size():
		return
	var c := r.game.player_village.center
	var pass_spawn := r.spawn_near(c + Vector2i(0, -40))
	for kind: String in LEGION:
		r.add_enemies(kind, pass_spawn, int(LEGION[kind]))
	for cap in CAPTAINS:
		r.add_enemies("legion_captain", pass_spawn, 1, cap)
	var gate := _gargoyle_rock(r)
	r.add_enemies("gargoyle", gate, GATE_GARGOYLES)
	var road := r.road_in(c + Vector2i(0, -40), 16)
	r.play_scene([
		{"camera": r.at(road[0]) + Vector2(0, -40) if not road.is_empty() else r.at(c), "zoom": 1.0, "time": 2.0},
		{"say": "", "text": "Down the pass comes a column of soldiers, marching in step. Pale faces, and the colours of a company Brenna knows."},
		{"say": "brenna", "text": "No. That's Lysa. And Torben, beside her."},
		{"say": "lysa", "text": "Hold until the last. Do not ask for relief."},
		{"say": "brenna", "text": "Lysa! It's me. It's Hale!"},
		{"say": "lysa", "text": "Hold until the last."},
		{"camera": r.at(gate) + Vector2(0, -60), "zoom": 1.0, "time": 2.0},
		{"say": "", "text": "Behind them, on the rocks above the pass, the stone gargoyles shake off their moss and spread their wings."},
	])




## Sigmund found (his tent's tile explored): the waves come, and he joins. A
## found piece of evidence: its page. A captain falling back: Brenna sees it.
func on_poll(r: ScenarioRunner) -> void:
	var g := r.game
	if not r.mark.has("sigmund found"):
		var seen := g.fog.is_explored_by(g.player_village.id, SIGMUND_TENT)
		for n: String in ["tent", "sigmund actor"]:
			if r.mark.has(n) and is_instance_valid(r.mark[n]):
				(r.mark[n] as Node2D).visible = seen
		if seen:
			r.mark["sigmund found"] = true
			r.release_waves(FIRST_WAVE_AFTER)
			g.events.info("Sigmund found by his tent, south of the pass")
			r.play_scene(_sigmund_scene(r))
	if r.mark.has("sigmund found") and not r.mark.has("sigmund in") and r.cutscene == null:
		_house_sigmund(r)  # (after his scene: he is seen by his tent)
	for l in r.lairs():
		var lair := l as MonsterLair
		if not lair.awake and not lair.cleared and lair.is_found_by(g.player_village):
			var n := maxi(1, g.waves.wave)
			lair.wake_wave = n
			lair.on_wave(n)  # (found: it wakes now)
	if r.journal != null and r.journal.visible:
		return
	for t in _evidence(r):
		var key := "found %s" % (t as Treasure).tile
		if r.mark.has(key) or not (t as Treasure).looted:
			continue
		r.mark[key] = true
		var k := int(r.mark.get("found", 0))
		r.mark["found"] = k + 1
		r.show_journal(EVIDENCE[mini(k, EVIDENCE.size() - 1)]["title"], EVIDENCE[mini(k, EVIDENCE.size() - 1)]["text"])
		g.events.info("Evidence found (%d / %d)" % [k + 1, EVIDENCE.size()])
		return
	if not r.mark.has("fell back"):
		for cap in CAPTAINS:
			var e := r.named_enemy(str(cap["name"]))
			if e != null and e.retreating:
				r.mark["fell back"] = true
				r.play_scene([
					{"say": "brenna", "text": "%s! ... Falling back. Still following orders." % cap["name"]},
					{"say": "brenna", "text": "They're alive, Pell. All of them. And I'll free them, if it's the last thing I do."},
				])
				return


## Sigmund into the fort: a free hut; else a builder makes room for him; else
## he waits by his tent until the player frees a hut (the "roof" objective).
func _house_sigmund(r: ScenarioRunner) -> void:
	var pop := r.game.population
	if pop.free_huts().is_empty():
		var builders := pop.civilians.filter(func(c: Civilian) -> bool: return c.role == "builder" and not c.dead)
		if builders.is_empty():
			return
		var leaving := builders[0] as Civilian
		r.game.events.info("%s makes room for Sigmund" % leaving.label().capitalize())
		pop.retire(leaving)
	var civ := r.join_villager("builder", "Sigmund", SIGMUND_TENT)
	if civ == null:
		return
	r.mark["sigmund in"] = true
	for n: String in ["tent", "sigmund actor"]:
		if r.mark.has(n) and is_instance_valid(r.mark[n]):
			(r.mark[n] as Node).queue_free()


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "An empty fort",
			"text": "The fort holds four people: Pell has a hut, three are free. Recruit who you need in the Village tab, a builder to mend, a farmer (there is no farm yet: the meadows lie south). Choose well: there is no room for more.",
			"done": func() -> bool: return g.population.count() >= 2,
			"point": func() -> Dictionary: return {"hud": ["tab:village", "dock"], "tab": "village"}},
		{"title": "Man the fort",
			"text": "The barracks and training grounds stand empty, and the beasts will come from both sides of the pass. Buy shield bearers in the Army tab for the barracks' benches, and archers for the wall towers.",
			"done": func() -> bool: return g.army.units.any(func(u: MilitaryUnit) -> bool: return u.post != null),
			"point": func() -> Dictionary: return {"hud": ["tab:army", "dock"], "tab": "army"}},
		{"title": "The evidence",
			"text": "Three pieces of evidence lie hidden on both sides of the mountains: two in the wild forest to the north, one in the meadows to the south. Send Brenna exploring: she loots what isn't guarded, and goes for a camp's treasure only once you order her to attack the camp.",
			"done": func() -> bool: return int(r.mark.get("found", 0)) >= 1,
			"point": func() -> Dictionary:
				return {} if g.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"]}},
		{"title": "Guarded",
			"text": "The pieces in the north lie by monster camps. Tap a camp and send Brenna to attack it, but mind her HP: if she falls here, it is over. Towers built near a camp wear it down first.",
			"done": func() -> bool: return int(r.mark.get("found", 0)) >= EVIDENCE.size()},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "roof",
			"when": func() -> bool: return _sigmund_waits(r),
			"text": "Every hut in the fort is taken, and Sigmund needs one. Retire a villager in the villager list (the people button in the top bar) to make room for him."},
		{"id": "witch",
			"when": func() -> bool: return r.enemy_about("witch"),
			"text": "A witch: Arcane, a magic-user. Her bolts bewitch a tower's unit for a moment. Towers within her reach can hit back."},
		{"id": "gargoyle",
			"when": func() -> bool: return r.enemy_about("gargoyle"),
			"text": "A gargoyle flies along the road: only towers, archers and mages can reach it."},
		{"id": "legion",
			"when": func() -> bool: return r.enemy_about("legion_footman"),
			"text": "The Dread Legion: Rhodri's bound soldiers. When one falls, it is released."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and here nobody can bring her back. Send her home to rest (her panel: Rest) until she has healed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "evidence", "text": "Find the three pieces of evidence",
			"done": func() -> bool: return int(r.mark.get("found", 0)) >= mini(EVIDENCE.size(), _evidence(r).size()),
			"detail": func() -> String: return "%d / %d" % [int(r.mark.get("found", 0)), mini(EVIDENCE.size(), _evidence(r).size())]},
		{"id": "roof", "text": "Give Sigmund a roof over his head",
			"shown": func() -> bool: return r.mark.has("sigmund found"),
			"done": func() -> bool: return r.mark.has("sigmund in")},
		{"id": "waves", "text": "Hold the fort for %d waves" % waves.size(),
			"done": func() -> bool: return g.waves.all_done(),
			"detail": func() -> String: return "%d / %d" % [g.waves.wave - (1 if g.waves.in_progress() else 0), waves.size()]},
	]


## Sigmund's tent and Sigmund beside it, hidden until their tile is explored.
func on_start(r: ScenarioRunner) -> void:
	r.mark["tent"] = r.actor("tent_small", Vector2(SIGMUND_TENT) + Vector2(-0.6, -0.4))
	r.mark["sigmund actor"] = r.actor("unit_builder", Vector2(SIGMUND_TENT))
	for n: String in ["tent", "sigmund actor"]:
		(r.mark[n] as Node2D).visible = false


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

## Sigmund is found and waits for a hut: none free, no builder to make room.
func _sigmund_waits(r: ScenarioRunner) -> bool:
	return r.mark.has("sigmund found") and not r.mark.has("sigmund in") and r.game.population.free_huts().is_empty() \
		and not r.game.population.civilians.any(func(c: Civilian) -> bool: return c.role == "builder")


## The treasures that hold the evidence: the map's far ones (tier 2 and 3:
## the two guarded ones in the north, one in the south), farthest first.
func _evidence(r: ScenarioRunner) -> Array:
	if not r.mark.has("evidence"):
		r.mark["evidence"] = r.treasures().filter(func(t: Treasure) -> bool: return int(t.data.get("tier", 1)) >= 2).slice(0, EVIDENCE.size())
	return r.mark["evidence"]


## A road tile up the north road, above the pass: where its gargoyles wake.
func _gargoyle_rock(r: ScenarioRunner) -> Vector2i:
	var road := r.road_in(r.game.player_village.center + Vector2i(0, -40), 14)
	return road[0] if not road.is_empty() else r.spawn_near(r.game.player_village.center)
