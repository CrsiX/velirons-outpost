extends Scenario
## Scenario 8: The Pale Court (docs/scenarios-design.md §3.8, §7.14). The
## burned capital's outskirts, a camp in a ruined court district on ash land.
## Brenna has no army here, only the band that came with her from the refuge
## (court mages, acolytes, a few archers and shield bearers): nobody can be
## recruited, gold only levels and specialises them. Three crypts lie under
## the court, where the Evil gathers; they wake one by one, each sending its
## monsters with every wave, and the hero clears them on the player's order.
## The Dread Legion holds two camps at the court's gates. Lothar, the court's
## herald, brings Rhodri's offer (taking it loses); at the last crypt waits
## Rurik, the court's champion. Brenna can't be brought back; Pell must not die.


func _init() -> void:
	number = 8
	title = "The Pale Court"
	blurb = "In the burned capital's ruins the Evil gathers in three crypts under the old court. Clear them with the little band that followed you."
	map_path = "res://data/maps/pale_court.json"
	place = "capital"
	portrait = "portrait_lothar"

	# The baseline: a camp in a ruined district (half the huts stand, most
	# walls are broken), an old guardhouse and one tower, Pell's wagon; the
	# band waits in the reserve.
	difficulty = "easy"
	enemy_scale = {"hp": 1.1, "damage": 1.1, "spell_damage": 1.1}
	resources = {"gold": 320, "food": 160, "materials": 260}
	civilians = ["builder", "builder", "farmer", "forester", "gatherer", "merchant"]
	names = {"merchant": "Pell"}
	buildings = ["farm", "camp"]
	huts_standing = 5
	pieces_standing = {"wall": 4, "gate": 2, "wall_tower": 2}
	pieces_hp = 0.6
	prebuilt = [
		{"kind": "stall", "road": 1, "at": [3, 7], "level": 1},
		{"kind": "barracks", "road": 0, "at": [5, 9], "level": 2},
		{"kind": "tower", "road": 2, "at": [3, 5]},
	]
	reserve = [
		{"kind": "archer", "level": 6}, {"kind": "archer", "level": 5},
		{"kind": "shield_bearer", "level": 6}, {"kind": "shield_bearer", "level": 5},
		{"kind": "apprentice", "level": 6}, {"kind": "apprentice", "level": 5},
		{"kind": "acolyte", "level": 6}, {"kind": "summoner", "level": 5},
	]
	hero_name = "Brenna"
	hero_level = 13

	units = ["archer", "shield_bearer", "apprentice", "acolyte", "summoner"]
	recruiting = false
	unlocked = ["apprentice", "acolyte", "summoner"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell"]
	army_upkeep = 0.0  # (no army upkeep here for now)

	# The crypts, nearest first: when each wakes, its guards and what it sends.
	lairs = [
		{"wake": 1, "guards": ["skeleton", "skeleton", "skeleton", "vampire"], "guard_hp": 1.5, "kinds": ["skeleton", "vampire"]},
		{"wake": 4, "guards": ["skeleton", "skeleton", "vampire", "vampire", "gargoyle"], "guard_hp": 1.7, "kinds": ["skeleton", "vampire", "necromancer"]},
		{"wake": CRYPT_3_WAVE, "guards": ["vampire", "vampire", "gargoyle"], "guard_hp": 1.9, "kinds": ["vampire", "necromancer", "gargoyle"]},
	]

	# Undead and Evil out of the crypts (the awake ones are spawn points too),
	# gargoyles off the palace, witches; the Legion's squads from wave 4.
	waves = [
		{"kinds": {"skeleton": 5, "goblin": 2}, "spawns": 2, "lairs": true},
		{"kinds": {"skeleton": 5, "goblin": 2, "vampire": 1}, "spawns": 2, "lairs": true},
		{"kinds": {"skeleton": 5, "vampire": 1, "necromancer": 1, "witch": 1}, "spawns": 2, "lairs": true},
		{"kinds": {"skeleton": 5, "vampire": 1, "gargoyle": 1, "witch": 1, "legion_footman": 3}, "spawns": 3, "lairs": true},
		{"kinds": {"skeleton": 6, "vampire": 2, "necromancer": 1, "gargoyle": 1, "legion_footman": 3, "legion_archer": 2}, "spawns": 3, "lairs": true},
		{"kinds": {"skeleton": 6, "vampire": 2, "witch": 1, "gargoyle": 1, "legion_footman": 3, "legion_cavalry": 1, "legion_archer": 2, "legion_banner": 1}, "spawns": 3, "lairs": true},
		{"kinds": {"skeleton": 6, "vampire": 2, "necromancer": 1, "gargoyle": 2, "legion_footman": 4, "legion_cavalry": 1, "legion_guard": 1, "legion_archer": 2, "legion_banner": 1}, "spawns": 3, "lairs": true},
		{"kinds": {"skeleton": 7, "vampire": 2, "witch": 2, "gargoyle": 2, "legion_footman": 4, "legion_cavalry": 2, "legion_guard": 2, "legion_archer": 2, "legion_banner": 1}, "spawns": 3, "lairs": true},
		{"kinds": {"skeleton": 7, "vampire": 3, "necromancer": 2, "gargoyle": 2, "legion_footman": 4, "legion_cavalry": 2, "legion_guard": 2, "legion_archer": 3, "legion_banner": 1}, "spawns": 3, "lairs": true},
	]
	repeat_last = true
	more_each_wave = {"skeleton": 1, "legion_footman": 1}
	first_wave_waits = true
	first_wave_call = true
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"idris": {"name": "Idris", "portrait": "portrait_mage", "color": Color("c0a8f0")},
		"lothar": {"name": "Lothar", "portrait": "portrait_lothar", "color": Color("d8d4e4")},
		"rurik": {"name": "Rurik", "portrait": "portrait_rurik", "color": Color("c8ccd8")},
		"priest": {"name": "A priest", "portrait": "portrait_church_priest", "color": Color("d8c8a0")},
		"rhodri": {"name": "Rhodri", "portrait": "portrait_rhodri", "color": Color("b8c0d8")},
	}


## Lothar comes back with Rhodri's offer after this wave.
const OFFER_WAVE := 3
## The third crypt wakes at this wave, with Rurik at its door.
const CRYPT_3_WAVE := 7
## Rurik's HP scale (a guard of the third crypt).
const RURIK_HP := 1.2


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var road := r.road_in(c + Vector2i(0, 30), 14)
	var herald: Vector2 = Vector2(road[road.size() - 4]) if road.size() >= 4 else Vector2(c) + Vector2(0, 6)
	return [
		{"fade": "out", "time": 0.01},
		{"do": func() -> void: r.dusk(0.01)},
		{"camera": r.at(c) + Vector2(0, -60), "zoom": 0.85, "time": 0.01},
		{"title": "The Pale Court", "sub": "Scenario 8", "time": 3.0},
		{"say": "", "text": "The capital, by night. The city burned in the war; the palace did not. It stands dark against a red sky, and nothing in it sleeps."},
		{"fade": "in", "time": 1.4},
		{"say": "pell", "text": "Home of kings. I sold silk on that square once. Now look at it."},
		{"say": "brenna", "text": "We camp in the old court district. What's left of the walls will have to do."},
		{"do": func() -> void: r.mark["actors"] = [r.actor("unit_herald", herald)]},
		{"camera": r.at(herald) + Vector2(0, -40), "zoom": 1.15, "time": 2.5},
		{"say": "", "text": "On the road waits a man in pale colours under a white flag. He bows, deep and slow."},
		{"say": "lothar", "text": "Dame Brenna Hale. His Majesty bids you welcome home. I am Lothar, herald of the court."},
		{"say": "brenna", "text": "He gave my company to his crown. Tell him that's no welcome I'll take."},
		{"say": "lothar", "text": "I shall tell him you are well. He will be glad. I will come again, when you have had time to think."},
		{"do": func() -> void: _drop_actors(r)},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 2.0},
		{"say": "idris", "text": "Under the court lie the old crypts. The Evil gathers there, drawn by the dead and by him. As long as they're full, the court is never alone."},
		{"say": "brenna", "text": "Then we empty them. There's no army to hire here, only us. It will have to be enough."},
		{"say": "", "text": "Clear the three crypts under the court. Nobody can be recruited here: level up and specialise your band. Brenna can't be brought back, and Pell must not die."},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	return [
		{"do": func() -> void: r.dusk(3.0)},
		{"camera": r.at(c) + Vector2(0, -60), "zoom": 1.0, "time": 2.0},
		{"say": "", "text": "The last crypt is quiet. Up at the palace the throne hall's gate stands open, and Brenna walks as far as its doorway."},
		{"say": "", "text": "On the throne sits Rhodri. On his head the old king's crown, reworked, glowing cold, and his face as pale as the light it gives."},
		{"say": "brenna", "text": "It isn't a gift he wears. It's feeding on him."},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "priest", "text": "Knight. I'm of the church, what's left of it here. Some of our priests hid something from him, long before the war: the First King's Hand."},
		{"say": "priest", "text": "A sword of the first king's, kept in the abbey that sank in the delta. It's said to cleanse the blood. Whether it can break such a thing as that crown, nobody knows."},
		{"say": "idris", "text": "A rider from Fiona, just now. She has heard of it too. The Hand is real, she writes, and the priests of the delta still keep it."},
		{"say": "brenna", "text": "Then we go to the delta, Pell."},
		{"say": "pell", "text": "Of course we do."},
		{"camera": r.at(c) + Vector2(0, -80), "zoom": 0.85, "time": 2.5},
		{"say": "lothar", "text": "Your Majesty. She refused."},
		{"say": "rhodri", "text": "Did she. Did she, now."},
		{"say": "", "text": "In the throne hall, Rhodri starts to laugh, and does not stop."},
		{"fade": "out", "time": 1.5},
	]


## The story between the waves: the crypts, Lothar's offer, the crown.
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var c := r.game.player_village.center
	var lines: Array[Dictionary] = []
	match n:
		1:
			lines = [
				{"say": "idris", "text": "The court mages called it the Pale Court even before the war ended: the nobles who stayed, the officers, the Legion at its gates. Everything near him goes pale."},
				{"say": "brenna", "text": "And the things in the crypts?"},
				{"say": "idris", "text": "Not courtiers. Monsters, drawn by the death. He lets them stay. They are his court as much as anyone."},
			]
		OFFER_WAVE:
			_offer(r)
			return
		5:
			lines = [
				{"say": "pell", "text": "The crown. Everyone in the market talks about it. The old king's own, they say, but it shines now."},
				{"say": "idris", "text": "A goldsmith came from abroad and reworked it for him. A very good goldsmith. Nobody saw him leave, and nobody knows where he came from."},
				{"say": "brenna", "text": "Whoever he was, he made it what it is."},
			]
	if lines.is_empty():
		return
	var scene: Array[Dictionary] = [{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.1, "time": 1.0}]
	scene.append_array(lines)
	r.play_scene(scene)


## Lothar comes back under his white flag with Rhodri's offer: a choice.
func _offer(r: ScenarioRunner) -> void:
	var c := r.game.player_village.center
	var road := r.road_in(c + Vector2i(0, 30), 14)
	var herald: Vector2 = Vector2(road[road.size() - 4]) if road.size() >= 4 else Vector2(c) + Vector2(0, 6)
	r.play_scene([
		{"do": func() -> void: r.mark["actors"] = [r.actor("unit_herald", herald)]},
		{"camera": r.at(herald) + Vector2(0, -40), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "Lothar comes up the road again, under his white flag."},
		{"say": "lothar", "text": "His Majesty's words, Dame Brenna: come back to his side. Your rank, your company, your name off that roll. All of it forgiven."},
		{"say": "lothar", "text": "You were his best. He remembers it."},
		{"say": "brenna", "text": "My company ...",
			"choices": [
				{"text": "Go back to Rhodri's side", "do": func() -> void:
					_drop_actors(r)
					r.lose("Brenna went back to Rhodri's side. She knelt before the crown on the field, as her company had, and stood up his.")},
				{"text": "Refuse", "do": func() -> void: pass},
			]},
		{"say": "brenna", "text": "... is out there marching behind his banner, with nothing behind their eyes. Tell him no. Tell him I'm coming for them."},
		{"say": "lothar", "text": "He will be sorry to hear it. Truly. Good night, Dame Brenna."},
		{"do": func() -> void: _drop_actors(r)},
	])


## The third crypt wakes with Rurik, the court's champion, at its door.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n != CRYPT_3_WAVE:
		return
	var list := r.lairs()
	if list.size() < 3:
		return
	var crypt := list[2] as MonsterLair
	var rurik := crypt.add_guard("legion_champion", RURIK_HP)
	rurik.set_identity("Rurik", "")
	r.mark["rurik"] = rurik
	r.game.fog.reveal(Vector2(crypt.tile), 3.0, r.game.player_village.id)
	r.play_scene([
		{"camera": r.at(crypt.tile) + Vector2(0, -50), "zoom": 1.1, "time": 2.0},
		{"say": "", "text": "The last crypt wakes. Before its door stands a man in pale plate, a greatsword over his shoulder."},
		{"say": "rurik", "text": "Rurik, champion of the court. The King said you would come. He said I should let you try."},
		{"say": "brenna", "text": "Rurik. You stood beside him at the coronation. I remember you."},
		{"say": "rurik", "text": "I don't remember you."},
	])


## Rurik is slain: Brenna sees him released.
func on_poll(r: ScenarioRunner) -> void:
	if r.cutscene == null:
		_drop_actors(r)  # (a skipped scene leaves the herald standing)
	var ru = r.mark.get("rurik")
	if ru != null and not r.mark.has("rurik down") and (not is_instance_valid(ru) or (ru as Enemy).dead):
		r.mark["rurik down"] = true
		r.game.events.info("Rurik, the court's champion, has fallen")
		r.play_scene([
			{"say": "", "text": "The champion falls. For a moment the pallor leaves his face, and he breathes out, like a man setting down something heavy."},
			{"say": "brenna", "text": "Rest, Rurik. Whoever you were before the crown."},
		])


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "Your band",
			"text": "There is no army to hire here: only your band, waiting in the reserve. Station them on the posts (drag a card onto a tower or the barracks); the wall towers that stand take a unit too.",
			"done": func() -> bool: return g.army.stationed().size() >= 4,
			"point": func() -> Dictionary: return {"hud": ["reserve", "tab:army", "dock"], "tab": "army", "tiles": r.first_tiles(r.towers(true))}},
		{"title": "Better, not more",
			"text": "Gold buys no new soldiers here, but it makes the ones you have better: upgrade one (tap it on its post, or the Army tab: Upgrade). From level 3 they can specialise.",
			"start": func() -> void: r.mark_units(),
			"done": func() -> bool: return r.unit_promoted(),
			"point": func() -> Dictionary: return {"hud": ["tab:army", "dock"], "tab": "army"}},
		{"title": "The first crypt",
			"text": "The nearest crypt has woken: with every wave its monsters come out of it. Tap it and order Attack with the hero. Towers built near it wear its guards down first, and mind her HP: here nobody can bring her back.",
			"ready": func() -> bool: return r.lairs().any(func(o: Node) -> bool: return (o as MonsterLair).awake or (o as MonsterLair).cleared),
			"wait_text": "The first crypt wakes with the first wave. Call it when your band is ready.",
			"done": func() -> bool: return _cleared(r) >= 1,
			"point": func() -> Dictionary:
				var list := r.lairs()
				var tiles: Array = [(list[0] as MonsterLair).tile] if not list.is_empty() else []
				return {"tiles": tiles}},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "vampire",
			"when": func() -> bool: return r.enemy_about("vampire"),
			"text": "A vampire: it heals from every hit it lands, and beaten it turns into a bat for a while. Only ranged attacks reach a bat."},
		{"id": "necromancer",
			"when": func() -> bool: return r.enemy_about("necromancer"),
			"text": "A necromancer raises the dead near it. Acolytes' holy light hurts it most."},
		{"id": "gargoyle",
			"when": func() -> bool: return r.enemy_about("gargoyle"),
			"text": "A gargoyle off the palace roofs: a flyer. Only towers, archers and mages reach it."},
		{"id": "legion_cavalry",
			"when": func() -> bool: return r.enemy_about("legion_cavalry"),
			"text": "Legion cavalry: fast riders that keep with their soldiers and run down our fighters. A charge hits twice as hard; halberdiers break it and hurt horses most. Unhorsed, the rider fights on as a footman."},
		{"id": "legion_archer",
			"when": func() -> bool: return r.enemy_about("legion_archer"),
			"text": "Legion archers shoot whoever of ours is out in the open, from a little less than a watchtower's range. Towers outrange them."},
		{"id": "legion_banner",
			"when": func() -> bool: return r.enemy_about("legion_banner"),
			"text": "A Legion banner-bearer: the soldiers near its banner strike and shoot faster. Kill it first."},
		{"id": "legion_guard",
			"when": func() -> bool: return r.enemy_about("legion_guard"),
			"text": "A Legion guardsman behind a tower shield: arrows and bolts do only half to it. Mages, acolytes and melee do better."},
		{"id": "legion_camp",
			"when": func() -> bool: return _legion_camps(r).any(func(o: MonsterCamp) -> bool: return o.is_found_by(g.player_village)),
			"text": "A Legion camp at one of the court's gates, guarding a treasure. Clearing it is up to you (tap it: Attack with the hero)."},
		{"id": "rurik",
			"when": func() -> bool: return r.mark.has("rurik"),
			"text": "Rurik's blows cleave everyone around his target. Wear him down with towers by the crypt before Brenna goes in."},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and here nobody can bring her back. Send her to rest (her panel: Rest) until she has healed."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	return [
		{"id": "crypts", "text": "Clear the three crypts",
			"done": func() -> bool: return _cleared(r) >= mini(3, r.lairs().size()),
			"detail": func() -> String: return "%d / %d" % [_cleared(r), mini(3, r.lairs().size())]},
		{"id": "camps", "text": "Break the Legion's camps", "optional": true,
			"done": func() -> bool: return not _legion_camps(r).is_empty() and _legion_camps(r).all(func(o: MonsterCamp) -> bool: return o.cleared),
			"detail": func() -> String: return "%d / %d" % [_legion_camps(r).filter(func(o: MonsterCamp) -> bool: return o.cleared).size(), _legion_camps(r).size()]},
	]


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

## How many of the crypts are cleared.
func _cleared(r: ScenarioRunner) -> int:
	return r.lairs().filter(func(o: Node) -> bool: return (o as MonsterLair).cleared).size()


## The Legion's camps (camps of Legion soldiers; not the lairs).
func _legion_camps(r: ScenarioRunner) -> Array:
	return r.game.world.map_objects.filter(func(o: Node) -> bool: return o is MonsterCamp and not (o is MonsterLair) and (o as MonsterCamp).display_name() == "Legion camp")


func _drop_actors(r: ScenarioRunner) -> void:
	for n in r.mark.get("actors", []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	r.mark.erase("actors")
