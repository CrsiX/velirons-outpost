extends Scenario
## Scenario 3: The Wardline (docs/scenarios-design.md §3.3, docs/story-design.md).
## The home map, grown: the road north to the border is lined with the ruins
## of the Wardline. Brenna claims them (Explore mode), the builders restore
## them, units man them, and light stones light the road between them, while
## the waves keep coming; the first Renegades (thieves) in wave 3. Each
## restored tower (six) gives up a page of its garrison's journal, some
## followed by a word between Brenna and Pell; the barracks its logbook, in the
## hand of Brenna's old captain, Lysa. Teaches:
## specialising, the training grounds and Train mode, restoring ruins.


func _init() -> void:
	number = 3
	title = "The Wardline"
	blurb = "The road to the border is cut where the Wardline's towers stood. Restore and man the ruined towers and the old barracks, and light the road between them."
	map_path = "res://data/maps/wardline.json"
	place = "outpost"
	portrait = "portrait_brenna"

	# The baseline: the village at its best so far: all huts, a barracks, towers
	# on the roads (one the ruin by the village restored in scenario 2), Pell's
	# stall; no training grounds yet. The Wardline: six ruined watchtowers and a
	# ruined barracks along the border road.
	difficulty = "easy"
	enemy_scale = {"hp": 0.75, "damage": 0.75, "spell_damage": 0.75}
	resources = {"gold": 260, "food": 160, "materials": 280}
	civilians = ["builder", "builder", "farmer", "farmer", "forester", "gatherer", "merchant"]
	names = {"forester": "Einar", "merchant": "Pell"}
	buildings = ["farm", "camp"]
	prebuilt = [
		{"kind": "stall", "road": 1, "at": [3, 7], "level": 2},
		{"kind": "farm", "road": 2, "at": [4, 9]},
		{"kind": "barracks", "road": 0, "at": [6, 10], "units": [{"kind": "shield_bearer", "level": 3}]},
		{"kind": "tower", "road": 0, "at": [3, 5], "units": [{"kind": "archer", "level": 3}]},
		{"kind": "tower", "road": 1, "at": [8, 11], "units": [{"kind": "archer", "level": 3}]},
		{"kind": "tower", "ruin": 0, "units": [{"kind": "archer", "level": 2}]},
	]
	hero_name = "Brenna"
	hero_level = 4

	# Specialising is open now (from unit level 3), and the training grounds.
	units = ["archer", "shield_bearer"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	must_live = ["Pell"]

	# Wilderness, and from wave 3 the first Renegades: thieves. The waves keep
	# coming until the line is restored and lit: the last one again, growing.
	waves = [
		{"kinds": {"goblin": 5}, "rat_packs": [4], "spawns": 2},
		{"kinds": {"goblin": 6, "ork": 1}, "spawns": 2},
		{"kinds": {"goblin": 5, "ork": 1, "thief": 2}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 7, "ork": 2, "thief": 2}, "spawns": 3},
		{"kinds": {"goblin": 7, "ork": 2, "thief": 3, "slime3": 1}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 8, "ork": 3, "thief": 3, "slime3": 2}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"goblin": 8, "ork": 3, "thief": 4, "slime3": 2}, "spawns": 4},
		{"kinds": {"goblin": 9, "ork": 3, "thief": 4, "slime3": 2}, "rat_packs": [6], "spawns": 4},
	]
	repeat_last = true
	more_each_wave = {"goblin": 2, "ork": 1, "thief": 1}
	first_wave_waits = false
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
	}


## The garrison's journal, one page per restored watchtower (in the order they
## are restored), and the barracks' logbook.
const PAGES: Array[String] = [
	"Third week of the thaw. Quiet on the line. Goblins in the far hills, but they know better than to come within bowshot of a manned tower. Mended the brazier.",
	"Orders came today: half the garrison to march for the capital. Nobody says for whom. The tower next along has its lamp out tonight. Without it the road between us is blind.",
	"The captain rode the line today, tower to tower, from the sea cliffs to the mountains. She counted heads at every hearth and asked who could be spared. She wrote every name down, and didn't say what for.",
	"Down to four men, too few to walk the road at night. So we set rune stones along it, between the towers: their glow shows us the stretch no tower can see. A tower alone sees its own bit of road; a lit road between them is what makes them a line.",
	"Goblins tried the road by the river bridge last night. The stones showed them to us a long way off, and the two towers shot them down between them before they ever reached the bridge. Neither tower could have done it alone.",
	"Last page. They called the rest of us in, and the rune stones have gone dark behind us. If anyone reads this: the Wardline was never the towers. It was the light between them, and the people who kept it burning.",
]
## What Brenna and Pell say once a page is closed (by its number, from 1).
const TALKS := {
	2: [
		{"say": "pell", "text": "Half the garrison in one night. And the other towers?"},
		{"say": "brenna", "text": "The same, I'd wager. The line ran the whole border, from the sea cliffs to the mountains. Every tower that emptied left the next one blind."},
		{"say": "pell", "text": "Then there's a long way still to go."},
	],
	4: [
		{"say": "brenna", "text": "Four men to a tower, and they still held. Rune stones and stubbornness."},
		{"say": "pell", "text": "My guild's carters will want to meet whoever thought of the stones. A lit road is a road a cart can take at dusk."},
		{"say": "brenna", "text": "Then we light it all the way. West and east."},
	],
}
const LOGBOOK := "Garrison logbook, last entry:\n\n\"By order of the crown: abandon the post and march for the capital. The border will hold itself.\"\n\nIt is signed twice, once in Fiona's name and once in Rhodri's, as if either would do. The hand that wrote it is careful and square."


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var first := _north_sites(r)
	var ruin: Vector2 = r.at(first[0]["tile"]) if not first.is_empty() else r.at(r.game.player_village.center)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": r.at(r.game.player_village.center), "zoom": 0.9, "time": 0.01},
		{"title": "The Wardline", "sub": "Scenario 3", "time": 3.0},
		{"fade": "in", "time": 1.2},
		{"say": "", "text": "Brenna and Pell walk the north road, out towards the border."},
		{"camera": ruin + Vector2(0, -40), "zoom": 1.1, "time": 3.5},
		{"say": "pell", "text": "There. The first of them. Or what's left."},
		{"say": "brenna", "text": "A Wardline tower. A whole chain of them ran along the border road, west and east, each in sight of the next."},
		{"say": "pell", "text": "Six of them on this stretch alone, the old maps say. And the barracks at the east end, where the garrison slept."},
		{"say": "pell", "text": "The crown paid for them, and the knights manned them, and the wilderness stayed out of the farms. Then the war came and called the knights home."},
		{"say": "brenna", "text": "I served on the line, before. We kept a lamp burning every night. You could see the next tower's lamp from ours."},
		{"say": "pell", "text": "Then you know what it takes. Rebuild them, man them, and light the road between them, and my guild's caravans can pass."},
		{"say": "", "text": "Pell must not die. The waves keep coming until the line is restored and lit."},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var road := r.road_in(r.game.player_village.center + Vector2i(0, -40), 40)
	var mid: Vector2 = r.at(road[road.size() / 2]) if not road.is_empty() else r.at(r.game.player_village.center)
	return [
		{"do": func() -> void:
			if road.size() > 8:
				var c := r.actor("unit_caravan", Vector2(road[0]))
				r.move_actor(c, road.slice(0, road.size() - 6), 14.0)},
		{"camera": mid, "zoom": 1.0, "time": 2.5},
		{"say": "", "text": "The road is open. Down it, between the lit stones, comes the first guild caravan in a year."},
		{"say": "pell", "text": "Look at that. Flour, timber, salt. And letters."},
		{"say": "pell", "text": "From the border town, Brenna. The guild's store there is under pressure: the rival guilds want it, and they're not asking politely."},
		{"say": "pell", "text": "I have to go. And I'd rather not go alone."},
		{"say": "brenna", "text": "The village has its towers now, and Father has his timber. I'm coming with you."},
		{"do": func() -> void: r.dusk(3.0)},
		{"say": "", "text": "From here on, Brenna leaves her home behind. Out there, nobody can bring her back if she falls."},
		{"fade": "out", "time": 1.5},
	]


## The road out to the first ruin is known: Brenna and Pell walk it in the intro.
func on_start(r: ScenarioRunner) -> void:
	var first := _north_sites(r)
	if first.is_empty():
		return
	var vid := r.game.player_village.id
	for t in r.road_to_village(first[0]["tile"]):
		r.game.fog.reveal(Vector2(t), 2.0, vid)
	r.game.fog.reveal(Vector2(first[0]["tile"]), 3.5, vid)


## Each restored watchtower: a page of the garrison's journal (and the hint
## that the stones between them matter); the restored barracks: the logbook.
## One at a time: the next once the page shown is closed.
func on_poll(r: ScenarioRunner) -> void:
	if r.journal != null and r.journal.visible:
		return
	for site in r.ruin_sites:
		var key := "page %s" % site["tile"]
		if r.mark.has(key) or r.restored(site) == null:
			continue
		r.mark[key] = true
		if site["building"] == "barracks":
			r.show_journal("The garrison's logbook", LOGBOOK)
			r.journal.closed.connect(func() -> void:
				r.play_scene([
					{"say": "brenna", "text": "I know that hand. Square and careful. That's Lysa's. My old captain."},
					{"say": "pell", "text": "Your captain signed for both heirs?"},
					{"say": "brenna", "text": "Somebody ordered her to. I'd like to know who."},
				]), CONNECT_ONE_SHOT)
		else:
			var n := int(r.mark.get("pages", 0))
			r.mark["pages"] = n + 1
			r.show_journal("A garrison journal, page %d" % (n + 1), PAGES[mini(n, PAGES.size() - 1)])
			if TALKS.has(n + 1):
				var talk: Array[Dictionary] = []
				talk.assign(TALKS[n + 1])
				r.journal.closed.connect(func() -> void: r.play_scene(talk), CONNECT_ONE_SHOT)
			if n == 0:
				r.game.events.info("A Wardline tower is restored. Light stones between the towers light the road")
		return


# --- the cards (specialising, training grounds and Train, the ruins) -------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "Claim the ruins",
			"text": "Send Brenna exploring: before new land she claims the ruins she finds. The old Wardline runs along the border road in the north, from the west edge to the east.",
			"done": func() -> bool: return r.ruin_sites.any(r.claimed),
			"point": func() -> Dictionary: return {} if g.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"]}},
		{"title": "Restore a tower",
			"text": "Tap a claimed ruin and restore it: a builder repairs it for half its price. Then station a unit on it.",
			"done": func() -> bool: return r.ruin_sites.any(func(s: Dictionary) -> bool: return r.on_site(s) is Building and not (r.on_site(s) is MapObject)),
			"point": func() -> Dictionary: return {"tiles": _claimed_tiles(r)}},
		{"title": "Specialise",
			"text": "Your archers have reached level 3: they can specialise now. Tap one and pick a branch: a Crossbowman for heavy bolts, or a Swiftbowman for a hail of arrows.",
			"done": func() -> bool: return g.army.units.any(func(u: MilitaryUnit) -> bool: return Config.MILITARY[u.kind].has("branch_of")),
			"point": func() -> Dictionary: return {"units": g.army.stationed().filter(func(u: MilitaryUnit) -> bool: return u.kind == "archer" and is_instance_valid(u.post) and u.post.unit_rect(u).has_area())}},
		{"title": "Training grounds",
			"text": "Training grounds let Brenna pass her XP on to a unit: free levels instead of gold. Build them and station a unit there.",
			"done": func() -> bool: return g.army.units.any(func(u: MilitaryUnit) -> bool: return u.post is TrainingGrounds and u.state == MilitaryUnit.State.STATIONED),
			"point": func() -> Dictionary:
				var tg := g.player_village.buildings().filter(func(b: Building) -> bool: return b is TrainingGrounds)
				if tg.is_empty():
					return r.place_point("training", [])
				return r.unit_point("archer", tg)},
		{"title": "Train",
			"text": "Set Brenna to Train: she walks to the grounds and passes her XP on until the unit levels up.",
			"start": r.mark_units,
			"done": func() -> bool: return g.army.units.any(func(u: MilitaryUnit) -> bool: return u.post is TrainingGrounds and r.mark.get("units", {}).has(u) and u.level > int(r.mark["units"][u][1])),
			"point": func() -> Dictionary: return {} if g.hero.mode == Hero.Mode.TRAIN else {"hud": ["hero_mode:%d" % Hero.Mode.TRAIN, "hero"]}},
		{"title": "Light the road",
			"ready": func() -> bool: return not _known_dark_road(r).is_empty() or g.player_village.buildings().any(func(b: Building) -> bool: return b is LightStone),
			"wait_title": "Explore the line",
			"wait_text": "Keep Brenna (or an explorer) exploring north along the road. Once the road between a restored tower and the village is known, you can light it.",
			"text": "A tower sees its own stretch of road. Light stones light the rest: place them where the road between the towers lies dark.",
			"done": func() -> bool: return g.player_village.buildings().any(func(b: Building) -> bool: return b is LightStone and b.complete),
			"point": func() -> Dictionary: return r.place_point("lightstone", [])},  # (where: the player sees the dark road)
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	return [
		{"id": "thieves",
			"when": func() -> bool: return r.enemy_about("thief"),
			"text": "Renegades on the road: thieves! At a gate they steal gold and run. Stop them before they get there, or catch them on the way out."},
		{"id": "pell",
			"when": func() -> bool: return r.merchant() != null and r.merchant().evading,
			"text": "Pell flees from an enemy! He must not die."},
		{"id": "camp",
			"when": func() -> bool: return _camps_found(r),
			"text": "A monster camp! Its guards stay by it, and explorers (Brenna too) keep away from them, so the land around it stays dark. Brenna can attack it on your order (tap the camp: Attack with the hero), and towers and barracks within range fight its guards on their own."},
		{"id": "explorer",
			"when": func() -> bool: return (r.game.waves.wave > 3 or (r.game.waves.wave == 3 and not r.game.waves.in_progress())) and r.game.population.count("explorer") == 0,
			"text": "No explorer in the village. Recruit one (Village tab; it needs a free hut): explorers uncover the land on their own, and Brenna is free for other work."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	return [
		{"id": "towers", "text": "Restore and man the Wardline's towers",
			"done": func() -> bool: return _manned(r, "tower") >= _sites(r, "tower").size(),
			"detail": func() -> String: return "%d / %d" % [_manned(r, "tower"), _sites(r, "tower").size()]},
		{"id": "barracks", "text": "Restore and man the old barracks",
			"done": func() -> bool: return _manned(r, "barracks") >= _sites(r, "barracks").size(),
			"detail": func() -> String: return "%d / %d" % [_manned(r, "barracks"), _sites(r, "barracks").size()]},
		{"id": "lit", "text": "Light the road between them",
			"done": func() -> bool: return _dark_road(r).is_empty(),
			"detail": func() -> String: return "%d %%" % roundi(100.0 * (1.0 - float(_dark_road(r).size()) / maxf(1.0, float(_line(r).size()))))},
	]


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

func _sites(r: ScenarioRunner, kind: String) -> Array:
	return r.ruin_sites.filter(func(s: Dictionary) -> bool: return s["building"] == kind)


## The restored buildings of `kind` with a unit on them.
func _manned(r: ScenarioRunner, kind: String) -> int:
	var n := 0
	for s in _sites(r, kind):
		var b := r.restored(s)
		if b is MilitaryPost and not (b as MilitaryPost).units().is_empty():
			n += 1
	return n


## The ruin sites up the north road, nearest the village first.
func _north_sites(r: ScenarioRunner) -> Array:
	var c := Vector2(r.game.player_village.center)
	var out := r.ruin_sites.filter(func(s: Dictionary) -> bool: return (s["tile"] as Vector2i).y < r.game.player_village.center.y - 4)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["tile"]).distance_to(c) < Vector2(b["tile"]).distance_to(c))
	return out


func _claimed_tiles(r: ScenarioRunner) -> Array:
	var out: Array = []
	for s in r.ruin_sites:
		if r.on_site(s) is RuinedTower and r.claimed(s):
			out.append(s["tile"])
	return out


## The road of the line: from the village out to every ruin site (computed once).
func _line(r: ScenarioRunner) -> Array[Vector2i]:
	if r.mark.has("line"):
		return r.mark["line"]
	var seen := {}
	var out: Array[Vector2i] = []
	var gate_side := r.game.player_village.rect.grow(1)
	for s in r.ruin_sites:
		for t in r.road_to_village(s["tile"]):
			if not seen.has(t) and not gate_side.has_point(t):
				seen[t] = true
				out.append(t)
	r.mark["line"] = out
	return out


## A monster camp the village has found, not yet cleared.
func _camps_found(r: ScenarioRunner) -> bool:
	return r.game.world.map_objects.any(func(o: MapObject) -> bool: return o is MonsterCamp and not (o is MonsterLair) and not (o as MonsterCamp).cleared and o.is_found_by(r.game.player_village))


## The dark road of the line between the village and a restored tower that the
## village has explored (where a light stone makes sense now).
func _known_dark_road(r: ScenarioRunner) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var line := _line(r)
	for s in r.ruin_sites:
		if r.restored(s) == null:
			continue
		for t in r.road_to_village(s["tile"]):
			if line.has(t) and not r.lit(t) and r.game.map.is_explored(t) and not out.has(t):
				out.append(t)
	return out


## The road of the line that no building of ours lights yet.
func _dark_road(r: ScenarioRunner) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in _line(r):
		if not r.lit(t):
			out.append(t)
	return out
