extends Scenario
## Scenario 7: The Exile (docs/scenarios-design.md §3.7, §7.12). Fiona's
## refuge, a hidden valley in the forest: refugees, a few court mages and
## their tower, and the druids' grove by the stone circle. Fiona doesn't trust
## a knight of Rhodri's army: Brenna starts outside the walls in her tent, and
## the refuge's people take no orders from her. Her trust grows in steps:
## after wave 2 Brenna may come in, and villagers, repairs and rebuilding open
## (and the court mages open their tower: the apprentice); after wave 7 new
## buildings. At wave 5 the grove is attacked: no druid may fall in that wave;
## afterwards the stone circle answers (the summoner). Twelve waves, while the
## court mages finish the working that hides the valley. Brenna can't be
## brought back; Pell and Fiona must not die.


func _init() -> void:
	number = 7
	title = "The Exile"
	blurb = "Fiona's hidden refuge needs defending, but she wants nothing from a knight of her brother's army. Earn her trust."
	map_path = "res://data/maps/refuge.json"
	place = "refuge"
	portrait = "portrait_fiona"

	# The baseline: a refuge of tired people (one farm in the forest, food just
	# about even), a hut and some walls broken, two court mages on watchtowers,
	# a small barracks, the druids in their grove, Pell's wagon. Fiona in her house.
	difficulty = "easy"
	enemy_scale = {"hp": 1.05, "damage": 1.05, "spell_damage": 1.05}
	resources = {"gold": 260, "food": 160, "materials": 240}
	civilians = ["builder", "builder", "farmer", "forester", "gatherer", "merchant", "princess"]
	names = {"merchant": "Pell", "princess": "Fiona"}
	homes = {"Fiona": {"art": "fiona_house", "name": "Fiona's House"}}
	buildings = ["camp"]  # (the forest leaves no room for the usual farm by the walls: its farm is prebuilt by a road)
	huts_standing = 8
	pieces_standing = {"wall": 6, "gate": 3, "wall_tower": 3}
	pieces_hp = 0.7
	prebuilt = [
		{"kind": "grove", "near_site": "stone_circle", "level": 3, "units": [{"kind": "druid", "level": 4, "fixed": true}, {"kind": "druid", "level": 4, "fixed": true}, {"kind": "druid", "level": 4, "fixed": true}]},
		{"kind": "stall", "road": 2, "at": [3, 7], "level": 1},
		{"kind": "farm", "road": 3, "at": [3, 12]},
		{"kind": "tower", "road": 0, "at": [3, 5], "units": [{"kind": "apprentice", "level": 4}]},
		{"kind": "tower", "road": 1, "at": [3, 5], "units": [{"kind": "apprentice", "level": 3}]},
		{"kind": "barracks", "road": 1, "at": [5, 9], "units": [{"kind": "shield_bearer", "level": 4}]},
		{"kind": "wall_tower", "road": 0, "units": [{"kind": "archer", "level": 4}]},
	]
	hero_name = "Brenna"
	hero_level = 11
	# Her tent by the east road, outside the walls, until Fiona lets her in.
	hero_start = Vector2i(46, 39)
	tent_tile = Vector2i(47, 38)
	hero_lives_out = true

	units = ["archer", "shield_bearer", "acolyte", "apprentice", "summoner"]
	unlocked = ["acolyte"]
	# The court mages open their tower after wave 2, the stone circle answers
	# after wave 5 (on_wave_finished).
	sites = {"mage_tower": -1, "stone_circle": -1}
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell", "Fiona"]

	# Wilderness and Undead drawn by the magic, some Renegades, a few witches.
	# Wave 5 brings a second band down the north road, at the grove.
	waves = [
		{"kinds": {"goblin": 5, "skeleton": 3}, "spawns": 2},
		{"kinds": {"goblin": 5, "skeleton": 4, "thief": 1}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 6, "skeleton": 4, "ork": 1, "witch": 1}, "spawns": 3},
		{"kinds": {"goblin": 6, "skeleton": 5, "ork": 2, "thief": 1}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"goblin": 6, "skeleton": 5, "ork": 2, "witch": 1}, "spawns": 3},
		{"kinds": {"goblin": 7, "skeleton": 6, "ork": 2, "necromancer": 1, "thief": 2}, "spawns": 3},
		{"kinds": {"goblin": 7, "skeleton": 6, "ork": 3, "witch": 2}, "rat_packs": [6], "spawns": 3},
		{"kinds": {"goblin": 8, "skeleton": 7, "ork": 3, "necromancer": 1, "slime3": 1, "thief": 2}, "spawns": 4},
		{"kinds": {"goblin": 8, "skeleton": 8, "ork": 3, "witch": 3}, "rat_packs": [6], "spawns": 4},
		{"kinds": {"goblin": 9, "skeleton": 8, "ork": 4, "necromancer": 2, "thief": 2}, "spawns": 4},
		{"kinds": {"goblin": 9, "skeleton": 9, "ork": 4, "witch": 3, "slime3": 1}, "rat_packs": [6], "spawns": 4},
		{"kinds": {"goblin": 10, "skeleton": 10, "ork": 5, "necromancer": 2, "witch": 3, "thief": 3}, "rat_packs": [7], "spawns": 4},
	]
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"fiona": {"name": "Fiona", "portrait": "portrait_fiona", "color": Color("9ab8f0")},
		"elder": {"name": "Elder Oren", "portrait": "portrait_elder", "color": Color("9ad07a")},
		"idris": {"name": "Idris", "portrait": "portrait_mage", "color": Color("c0a8f0")},
	}


## Fiona's trust (mark "trust"): 0 outside, 1 inside (after TRUST_IN), 2 trusted (after TRUST_BUILD).
const TRUST_IN := 2
const TRUST_BUILD := 7
## The wave that comes for the grove, and the band it adds down the north road.
const GROVE_WAVE := 5
const GROVE_BAND := {"goblin": 4, "skeleton": 4, "ork": 2, "witch": 1}
## What Fiona's people won't do for Brenna yet, by trust.
const LOCKED_OUT: Array[String] = ["place_building", "repair", "rebuild_hut", "rebuild_all_huts", "upgrade_tower", "tear_down", "recruit_villager", "retire_villager", "assign_worker", "unassign_worker", "assign_miner", "unassign_miner", "restore_ruin"]
const LOCKED_IN: Array[String] = ["place_building"]


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var road := r.road_in(c + Vector2i(30, 0), 14)
	var edge: Vector2 = r.at(road[0]) if not road.is_empty() else r.at(c)
	var gate := Vector2(c) + Vector2(2.6, 0.0)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": edge + Vector2(0, -30), "zoom": 0.95, "time": 0.01},
		{"title": "The Exile", "sub": "Scenario 7", "time": 3.0},
		{"say": "", "text": "A valley hidden in the forest, east of the war. Brenna and Pell come out of the trees with a priest's sealed word."},
		{"fade": "in", "time": 1.2},
		{"do": func() -> void:
			r.mark["actors"] = [r.actor("unit_princess", gate), r.actor("unit_apprentice", gate + Vector2(0.4, -0.7)), r.actor("unit_apprentice", gate + Vector2(0.4, 0.7))]},
		{"camera": r.at(gate) + Vector2(0, -40), "zoom": 1.15, "time": 3.0},
		{"say": "", "text": "At the gate a woman waits with two mages: red-gold hair, a plain circlet. The old king's daughter."},
		{"say": "fiona", "text": "Anselm vouches for you. He vouches for everyone. You wear my brother's colours, knight."},
		{"say": "brenna", "text": "I wore them. Brenna Hale, of the company of the pass. Your brother gave my company to his crown."},
		{"say": "fiona", "text": "And yet here you stand, unbound, at my gate. You'll understand if I find that hard to believe."},
		{"say": "fiona", "text": "You may camp outside the walls. My people take no orders from you. If you want to help, your sword is welcome. Nothing else is."},
		{"say": "pell", "text": "And my wagon, my lady? Gold buys what it buys, whoever spends it."},
		{"say": "fiona", "text": "Your wagon may come in, merchant."},
		{"do": func() -> void: _drop_actors(r)},
		{"camera": r.at(spec_tent()) + Vector2(0, -40), "zoom": 1.1, "time": 2.0},
		{"say": "", "text": "Hold the refuge for %d waves while the court mages finish the working that hides the valley, and earn Fiona's trust. Brenna can't be brought back here; Pell and Fiona must not die." % waves.size()},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	return [
		{"do": func() -> void: r.dusk(3.0)},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "The working is done. Over the valley the air shimmers once, like heat on a road, and the forest closes over it."},
		{"say": "fiona", "text": "Hale. Take this to the court mages who stayed in the capital. Sealed: open it and they'll know."},
		{"say": "brenna", "text": "And then?"},
		{"say": "fiona", "text": "Only someone of House Aldmoor can end what my brother has become. That is the crown's own law, and the only good thing left in it."},
		{"say": "fiona", "text": "I can't go yet. We need more allies, and more strength. Keep the mages alive until the crown is within reach."},
		{"say": "brenna", "text": "When the time is right, I'll bring you there. My word on it."},
		{"say": "fiona", "text": "A knight's word. Well. I've had worse."},
		{"fade": "out", "time": 1.5},
	]


## The story between the waves: Fiona's trust grows, the elder, Orsin.
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var c := r.game.player_village.center
	var lines: Array[Dictionary] = []
	match n:
		TRUST_IN:
			r.mark["trust"] = 1
			r.hero_moves_in()
			r.awaken_site("mage_tower")
			r.game.events.info("Fiona's people work with Brenna now; she may live inside the walls")
			lines = [
				{"say": "fiona", "text": "You held the east road. My people say you stood where you were needed. They'll work with you now; and you may sleep inside the walls."},
				{"say": "brenna", "text": "Thank you."},
				{"say": "fiona", "text": "Don't. I'm counting my people, not trusting you."},
				{"say": "idris", "text": "Our tower is open to you, knight. Come and see it: we can teach your recruits a little of what we know."},
			]
		GROVE_WAVE:
			if r.mark.has("druid down"):
				return
			r.mark["grove over"] = true
			r.awaken_site("stone_circle")
			lines = [
				{"say": "elder", "text": "The grove stands. We owe you that, knight."},
				{"say": "brenna", "text": "Why weren't you at your queen's side when the war began?"},
				{"say": "elder", "text": "She is not our queen. Our pact is with the first king: the druids keep the land, the crown keeps the border, and neither meddles in the other's affairs. Who wears the crown is the crown's affair."},
				{"say": "elder", "text": "And the church on her side drove us from the towns, in her grandfather's time. We owe her side nothing. We fight for our grove, not for her."},
				{"say": "elder", "text": "But you fought for the grove. The circle will answer you, if you go to it."},
			]
		TRUST_BUILD:
			r.mark["trust"] = 2
			r.game.events.info("Fiona trusts Brenna: new buildings may go up")
			lines = [
				{"say": "fiona", "text": "Build what you need, Hale. You've earned that much."},
				{"say": "brenna", "text": "May I ask you something? Why did your father never name an heir?"},
				{"say": "fiona", "text": "The law and his wish were mine. But the army would not follow a queen, and crowning me against it would have left me a crown and a rebellion."},
				{"say": "fiona", "text": "Naming Rhodri would have broken the law, set the church and the mages against the crown, and put power in the hands of a son he knew was greedy for it."},
				{"say": "fiona", "text": "So he waited to win the officers over. Told no one. And died first."},
				{"say": "fiona", "text": "He was waiting for your side to change its mind. I was his answer, and he never gave it."},
			]
		9:
			lines = [
				{"say": "fiona", "text": "Tell me what happened to your company. All of it."},
				{"say": "brenna", "text": "He came up the pass with the crown. They knelt on the field, and the light went into them. They stood up his. I saw it from the ridge."},
				{"say": "fiona", "text": "The crown binds people. Gods. And you came here because you have nowhere else to go."},
				{"say": "brenna", "text": "I came because you're the only one who can stand against him."},
				{"say": "idris", "text": "He changed, my lady, after the envoys came. Before the war. We all saw it."},
				{"say": "fiona", "text": "Envoys from where?"},
				{"say": "idris", "text": "Nobody could say. That is what frightens me."},
			]
	if lines.is_empty():
		return
	var scene: Array[Dictionary] = [{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0}]
	scene.append_array(lines)
	r.play_scene(scene)


## Wave 5: a second band comes down the north road, for the grove.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n != GROVE_WAVE:
		return
	var gr := _grove(r)
	var at := _grove_road(r)
	for kind: String in GROVE_BAND:
		r.add_enemies(kind, at, int(GROVE_BAND[kind]))
	r.mark["grove watch"] = true
	r.play_scene([
		{"camera": r.at(gr.tile if gr else r.game.player_village.center) + Vector2(0, -40), "zoom": 1.05, "time": 2.0},
		{"say": "", "text": "Down the north road a band of monsters makes straight for the grove."},
		{"say": "elder", "text": "Knight! They come for the circle. We'll hold it, but we are few. Help us, and none of us must fall today."},
	])


## A druid downed during the grove's wave: lost (one still down from an
## earlier wave counts once it stood again).
func on_poll(r: ScenarioRunner) -> void:
	if r.cutscene == null:
		_drop_actors(r)  # (a skipped intro leaves them standing)
	if not r.mark.has("grove watch") or r.mark.has("grove over"):
		return
	var up: Dictionary = r.mark.get("druids up", {})
	r.mark["druids up"] = up
	for u in r.game.army.units:
		if u.kind != "druid":
			continue
		if not u.is_downed():
			up[u] = true
		elif up.has(u):
			r.mark["druid down"] = true
			r.lose("A druid fell defending the grove. The druids will not forgive it.")
			return


## Fiona's trust: what her people won't do for Brenna yet.
func command_error(r: ScenarioRunner, type: String, _args: Dictionary) -> String:
	var trust := int(r.mark.get("trust", 0))
	if trust == 0 and type in LOCKED_OUT:
		return "Fiona's people take no orders from you yet"
	if trust == 1 and type in LOCKED_IN:
		return "Fiona won't have anything new built yet"
	return ""


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "Outside the walls",
			"text": "Fiona doesn't trust a knight of her brother's army. Until she does, her people take no orders from you: nothing can be built, mended or recruited. But your gold still hires soldiers: recruit one and station it on a post.",
			"start": func() -> void: r.mark["units at start"] = g.army.units.size(),
			"done": func() -> bool: return g.army.units.size() > int(r.mark.get("units at start", 0)) and g.army.units.any(func(u: MilitaryUnit) -> bool: return u.state == MilitaryUnit.State.STATIONED and u.kind != "druid" and g.army.units.find(u) >= int(r.mark.get("units at start", 0))),
			"point": func() -> Dictionary: return r.unit_point("archer", r.towers(true))},
		{"title": "The court mages' tower",
			"text": "Fiona's people work with you now, and the court mages have opened their tower. Send Brenna exploring: she goes to the tower, and you can recruit apprentices.",
			"ready": func() -> bool: return int(r.mark.get("trust", 0)) >= 1,
			"wait_text": "Hold the first waves. Fiona is watching.",
			"done": func() -> bool: return g.is_unlocked("apprentice"),
			"point": func() -> Dictionary:
				var s := r.site("mage_tower")
				var tiles: Array = [s.tile] if s else []
				return {"tiles": tiles} if g.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"], "tiles": tiles}},
		{"title": "Mend the refuge",
			"text": "Now you may mend what is broken: rebuild the ruined hut, and repair the broken walls and towers (tap one: Repair).",
			"done": func() -> bool: return r.pieces("hut").all(func(h: Building) -> bool: return (h as Hut).is_intact()),
			"point": func() -> Dictionary:
				var ruined := r.pieces("hut").filter(func(h: Building) -> bool: return not (h as Hut).is_intact())
				return {"tiles": r.first_tiles(ruined)}},
		{"title": "The stone circle",
			"text": "The druids' circle will answer Brenna now. Send her exploring to it, and you can recruit summoners.",
			"ready": func() -> bool: return r.mark.has("grove over"),
			"wait_text": "Wave %d comes for the druids' grove: no druid may fall in it." % GROVE_WAVE,
			"done": func() -> bool: return g.is_unlocked("summoner"),
			"point": func() -> Dictionary:
				var s := r.site("stone_circle")
				var tiles: Array = [s.tile] if s else []
				return {"tiles": tiles} if g.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"], "tiles": tiles}},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "druids",
			"when": func() -> bool: return g.army.units.any(func(u: MilitaryUnit) -> bool: return u.kind == "druid" and u.out),
			"text": "The druids turn out for enemies near their grove. They fight for it, but take no orders."},
		{"id": "grove",
			"when": func() -> bool: return r.mark.has("grove watch") and not r.mark.has("grove over"),
			"text": "No druid may fall in this wave: help them hold the grove (towers by it, Brenna, barracks)."},
		{"id": "witch",
			"when": func() -> bool: return r.enemy_about("witch"),
			"text": "A witch: her bolts bewitch a tower's unit for a moment, and hurt the druids out of their grove."},
		{"id": "necromancer",
			"when": func() -> bool: return r.enemy_about("necromancer"),
			"text": "A necromancer raises the dead near it. Acolytes' holy light hurts it most."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and here nobody can bring her back. Send her to rest (her panel: Rest) until she has healed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "waves", "text": "Hold the refuge for %d waves" % waves.size(),
			"done": func() -> bool: return g.waves.all_done(),
			"detail": func() -> String: return "%d / %d" % [g.waves.wave - (1 if g.waves.in_progress() else 0), waves.size()]},
		{"id": "trust", "text": "Earn Fiona's trust",
			"done": func() -> bool: return int(r.mark.get("trust", 0)) >= 2,
			"detail": func() -> String: return ["outside", "let in", "trusted"][clampi(int(r.mark.get("trust", 0)), 0, 2)]},
	]


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell and Fiona must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

func spec_tent() -> Vector2i:
	return tent_tile


func _grove(r: ScenarioRunner) -> Building:
	var list := r.pieces("grove")
	return list[0] if not list.is_empty() else null


## A road tile up the north road beyond the grove, where wave 5's band comes
## down (so it passes the grove on its way in).
func _grove_road(r: ScenarioRunner) -> Vector2i:
	var c := r.game.player_village.center
	var road := r.road_in(c + Vector2i(0, -40), 40)
	var gr := _grove(r)
	if road.is_empty() or gr == null:
		return r.spawn_near(c + Vector2i(0, -40))
	var best := 0
	for i in road.size():
		if Vector2(road[i]).distance_to(Vector2(gr.tile)) < Vector2(road[best]).distance_to(Vector2(gr.tile)):
			best = i
	return road[maxi(0, best - 8)]


func _drop_actors(r: ScenarioRunner) -> void:
	for n in r.mark.get("actors", []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	r.mark.erase("actors")
