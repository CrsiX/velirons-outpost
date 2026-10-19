extends Scenario
## Scenario 5: The Betrayal (docs/scenarios-design.md §3.5, docs/story-design.md).
## Brenna's old fort where the road comes down out of the pass: two walls
## stand, the rest is ruin. Sigmund, an old veteran who stayed, tells over the
## first waves what happened the night her company was given to the crown's
## ritual. Three pieces of evidence lie in the hills (treasures, the far ones
## guarded by camps): the order, the roll of the fallen, a foreign seal. Ten
## waves; witches and gargoyles join, and in the last one the first Dread
## Legion patrol comes down the pass, led by Brenna's old captain Lysa and her
## comrade Torben (captains: they fall back, they don't fall), while the
## gargoyles of the fort's old gate come alive. Brenna can't be brought back.


func _init() -> void:
	number = 5
	title = "The Betrayal"
	blurb = "Brenna goes back to the fort in the pass where her company was left to its fate. Find out what happened there, and hold the ruins while you do."
	map_path = "res://data/maps/old_fort.json"

	# The baseline: a ruined fort, a few survivors, a small barracks, Pell's
	# wagon (a peddler's stall again).
	difficulty = "easy"
	enemy_scale = {"hp": 0.95, "damage": 0.95, "spell_damage": 0.95}
	resources = {"gold": 220, "food": 150, "materials": 220}
	civilians = ["builder", "builder", "farmer", "forester", "gatherer", "merchant"]
	names = {"builder": "Sigmund", "merchant": "Pell"}
	buildings = ["farm", "camp"]
	huts_standing = 6
	pieces_standing = {"wall": 2, "gate": 1, "wall_tower": 1}
	pieces_hp = 0.6
	prebuilt = [
		{"kind": "stall", "road": 1, "at": [3, 7], "level": 1},
		{"kind": "barracks", "road": 0, "at": [5, 9], "units": [{"kind": "shield_bearer", "level": 3}]},
		{"kind": "tower", "road": 0, "at": [3, 5], "units": [{"kind": "archer", "level": 3}]},
		{"kind": "wall_tower", "road": 1, "units": [{"kind": "archer", "level": 2}]},
	]
	hero_name = "Brenna"
	hero_level = 7

	units = ["archer", "shield_bearer"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell"]

	# Wilderness and Renegades, then the first Arcane: witches from wave 3,
	# gargoyles from wave 6. Wave 10 brings the Legion (on_wave_started adds
	# it, down the pass, with its captains, and the old gate's gargoyles).
	waves = [
		{"kinds": {"goblin": 6}, "rat_packs": [4], "spawns": 2},
		{"kinds": {"goblin": 6, "ork": 1, "thief": 2}, "spawns": 2},
		{"kinds": {"goblin": 6, "ork": 2, "witch": 1}, "spawns": 3},
		{"kinds": {"goblin": 6, "ork": 2, "witch": 1, "thief": 2}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 7, "ork": 2, "witch": 2, "slime3": 1}, "spawns": 3},
		{"kinds": {"goblin": 7, "ork": 3, "witch": 1, "gargoyle": 1, "thief": 2}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 8, "ork": 3, "witch": 2, "gargoyle": 1}, "spawns": 3},
		{"kinds": {"goblin": 8, "ork": 3, "witch": 2, "gargoyle": 2, "thief": 3}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"goblin": 9, "ork": 4, "witch": 2, "gargoyle": 2, "slime3": 2}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"goblin": 6, "ork": 2}, "spawns": 2},
	]
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"sigmund": {"name": "Sigmund", "portrait": "portrait_sigmund", "color": Color("c8b090")},
		"lysa": {"name": "Lysa", "portrait": "portrait_lysa", "color": Color("c8ccd8")},
	}


## The Legion patrol of the last wave (down the pass), and the gargoyles that
## come alive at the fort's old gate.
const LEGION := {"legion_footman": 8}
const CAPTAINS: Array[Dictionary] = [
	{"name": "Lysa", "art": "legion_captain_lysa"},
	{"name": "Torben", "art": "legion_captain"},
]
const GATE_GARGOYLES := 3

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

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var pass_road := r.road_in(c + Vector2i(0, -30), 18)
	var field: Vector2 = r.at(pass_road[pass_road.size() / 2]) if not pass_road.is_empty() else r.at(c)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 0.95, "time": 0.01},
		{"title": "The Betrayal", "sub": "Scenario 5", "time": 3.0},
		{"say": "", "text": "The fort at the foot of the pass. Brenna has not seen it since the night she rode down that road."},
		{"fade": "in", "time": 1.2},
		{"say": "brenna", "text": "Two walls still standing. The barracks. And the field, out there. That's where the company stood."},
		{"camera": field + Vector2(0, -30), "zoom": 1.0, "time": 3.0},
		{"say": "pell", "text": "You don't have to do this."},
		{"say": "brenna", "text": "I do. The roll says they died here. I want to know who wrote it, and why."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 2.0},
		{"say": "sigmund", "text": "Well. Brenna Hale. Every name on that roll is dead, they say, yours too. You look well for a dead woman."},
		{"say": "brenna", "text": "Sigmund. You stayed."},
		{"say": "sigmund", "text": "Someone had to. If you want answers, they're in the hills: what the riders left behind, before the beasts moved in."},
		{"say": "", "text": "Find the three pieces of evidence in the hills, and hold the fort for ten waves. Brenna can't be brought back here, and Pell must not die."},
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


## Wave 10: the Legion comes down the pass, and the old gate's gargoyles wake.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n != waves.size():
		return
	var c := r.game.player_village.center
	var pass_spawn := r.spawn_near(c + Vector2i(0, -40))
	for kind: String in LEGION:
		r.add_enemies(kind, pass_spawn, int(LEGION[kind]))
	for cap in CAPTAINS:
		r.add_enemies("legion_captain", pass_spawn, 1, cap)
	var gate := _old_gate(r)
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
		{"say": "", "text": "Behind them, on the fort's old gate, the stone gargoyles shake off their moss and spread their wings."},
	])


## Each found piece of evidence: its page. A captain falling back: Brenna sees it.
func on_poll(r: ScenarioRunner) -> void:
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
		r.game.events.info("Evidence found (%d / %d)" % [k + 1, EVIDENCE.size()])
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


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "The evidence",
			"text": "Three pieces of evidence lie in the hills around the fort (marked). Send Brenna exploring: she loots what isn't guarded, and goes for a camp's treasure only once you order her to attack the camp.",
			"done": func() -> bool: return int(r.mark.get("found", 0)) >= 1,
			"point": func() -> Dictionary:
				var tiles: Array = []
				for t in _evidence(r):
					if not (t as Treasure).looted:
						tiles.append((t as Treasure).tile)
				return {"tiles": tiles} if g.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"], "tiles": tiles}},
		{"title": "Guarded",
			"text": "The far pieces lie by monster camps. Tap a camp and send Brenna to attack it, but mind her HP: if she falls here, it is over. Towers built near a camp wear it down first.",
			"done": func() -> bool: return int(r.mark.get("found", 0)) >= EVIDENCE.size(),
			"point": func() -> Dictionary:
				var tiles: Array = []
				for t in _evidence(r):
					if not (t as Treasure).looted:
						tiles.append((t as Treasure).tile)
				return {"tiles": tiles}},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
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
		{"id": "waves", "text": "Hold the fort for %d waves" % waves.size(),
			"done": func() -> bool: return g.waves.all_done(),
			"detail": func() -> String: return "%d / %d" % [g.waves.wave - (1 if g.waves.in_progress() else 0), waves.size()]},
	]


## Sigmund knows where the riders left things: the evidence's places are known.
func on_start(r: ScenarioRunner) -> void:
	var vid := r.game.player_village.id
	for t in _evidence(r):
		r.game.fog.reveal(Vector2((t as Treasure).tile), 2.5, vid)


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

## The treasures that hold the evidence: the three farthest from the fort.
func _evidence(r: ScenarioRunner) -> Array:
	if not r.mark.has("evidence"):
		r.mark["evidence"] = r.treasures().slice(0, EVIDENCE.size())
	return r.mark["evidence"]


## A road tile by the fort's old gate, up the pass road: where its gargoyles wake.
func _old_gate(r: ScenarioRunner) -> Vector2i:
	var road := r.road_in(r.game.player_village.center + Vector2i(0, -40), 14)
	return road[0] if not road.is_empty() else r.spawn_near(r.game.player_village.center)
