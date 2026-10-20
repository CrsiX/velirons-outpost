extends Scenario
## Scenario 6: The Dead (docs/scenarios-design.md §3.6, §7.11). The plain where
## Fiona's and Rhodri's armies met: the dead of both sides still lie where they
## fell (fallen soldiers' corpses, Corpse.fallen), and the necromancers that
## follow the war raise them. A village of survivors, their priest Anselm,
## gravediggers (gatherers) and a graveyard by a ruined chapel that is only
## sleeping. Bury enough of the fallen before too many of them rise; the
## chapel awakens when Brenna goes there, and its acolytes' holy light is the
## answer to the Undead. The waves come until enough are buried. Brenna can't
## be brought back.


func _init() -> void:
	number = 6
	title = "The Dead"
	blurb = "On the plain where the armies met, the dead were never buried, and something is raising them. Help the old priest lay them to rest."
	map_path = "res://data/maps/battlefield.json"
	place = "battlefield"
	portrait = "portrait_anselm"

	# The baseline: a village of survivors on dry land (food is short), two
	# gravediggers, Anselm in his house, a small garrison, Pell's wagon, the
	# graveyard by the chapel.
	difficulty = "easy"
	enemy_scale = {"hp": 1.0, "damage": 1.0, "spell_damage": 1.0}
	resources = {"gold": 240, "food": 90, "materials": 200}
	civilians = ["builder", "builder", "farmer", "forester", "gatherer", "gatherer", "merchant", "priest"]
	names = {"merchant": "Pell", "priest": "Anselm"}
	homes = {"Anselm": {"art": "priest_house", "name": "Anselm's House"}}
	buildings = ["farm", "camp"]
	pieces_standing = {"gate": 3, "wall_tower": 3}
	pieces_hp = 0.8
	prebuilt = [
		{"kind": "graveyard", "near_site": "chapel"},
		{"kind": "stall", "road": 1, "at": [3, 7], "level": 1},
		{"kind": "barracks", "road": 0, "at": [5, 9], "units": [{"kind": "shield_bearer", "level": 4}]},
		{"kind": "tower", "road": 0, "at": [3, 5], "units": [{"kind": "archer", "level": 4}]},
		{"kind": "tower", "road": 2, "at": [3, 5], "units": [{"kind": "archer", "level": 3}]},
		{"kind": "wall_tower", "road": 1, "units": [{"kind": "archer", "level": 3}]},
	]
	hero_name = "Brenna"
	hero_level = 9

	units = ["archer", "shield_bearer", "acolyte"]
	build = ["tower", "farm", "camp", "lightstone", "barracks", "training"]
	specialise = true
	hero_revives = false
	must_live = ["Pell", "Anselm"]
	# The chapel is only sleeping: Brenna can wake it from the start.
	sites = {"chapel": 0}

	# The Undead, with Wilderness leftovers; the first necromancer in wave 3, a
	# few thieves and witches. After the last listed wave it comes again,
	# growing, until enough of the fallen are buried.
	waves = [
		{"kinds": {"skeleton": 6, "goblin": 2}, "spawns": 2},
		{"kinds": {"skeleton": 7, "goblin": 3}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"skeleton": 7, "goblin": 3, "necromancer": 1}, "spawns": 3},
		{"kinds": {"skeleton": 8, "ork": 2, "thief": 1, "witch": 1}, "spawns": 3},
		{"kinds": {"skeleton": 9, "goblin": 3, "ork": 2, "necromancer": 1}, "rat_packs": [5], "spawns": 3},
		{"kinds": {"skeleton": 10, "ork": 2, "necromancer": 2, "witch": 1, "thief": 1}, "spawns": 3},
		{"kinds": {"skeleton": 11, "ork": 3, "necromancer": 2, "slime3": 1}, "rat_packs": [6], "spawns": 4},
		{"kinds": {"skeleton": 12, "ork": 3, "necromancer": 2, "witch": 2, "thief": 2}, "spawns": 4},
	]
	repeat_last = true
	more_each_wave = {"skeleton": 2, "ork": 1}
	# (the waves come by themselves: the field is only safe for so long)
	first_wave_waits = false
	wave_gap = 45.0

	speakers = {
		"brenna": {"name": "Brenna", "portrait": "portrait_brenna", "color": Color("e0b46a")},
		"pell": {"name": "Pell", "portrait": "portrait_pell", "color": Color("e8c890")},
		"anselm": {"name": "Anselm", "portrait": "portrait_anselm", "color": Color("d8d0c0")},
	}


## The fallen on the field at the start, in clusters where the lines met, and
## how many must be buried.
const FALLEN := 36
const CLUSTERS := 4
const BURY := 24
## Tiles from the village centre the clusters lie at.
const FIELD := Vector2(8.0, 17.0)


# --- the story -----------------------------------------------------------------------------

func intro(r: ScenarioRunner) -> Array[Dictionary]:
	var c := r.game.player_village.center
	var gy := _graveyard(r)
	var grave: Vector2 = r.at(gy.tile) if gy else r.at(c)
	var field: Vector2 = r.at(_clusters(r)[0]) if not _clusters(r).is_empty() else r.at(c)
	return [
		{"fade": "out", "time": 0.01},
		{"camera": field + Vector2(0, -30), "zoom": 0.9, "time": 0.01},
		{"title": "The Dead", "sub": "Scenario 6", "time": 3.0},
		{"say": "", "text": "The plain where the armies of Fiona and Rhodri met. The dead of both sides still lie where they fell, and the dry air keeps them."},
		{"fade": "in", "time": 1.2},
		{"do": func() -> void: r.mark["anselm actor"] = r.actor("unit_priest", Vector2(gy.tile) + Vector2(0.6, 0.6) if gy else Vector2(c))},
		{"camera": grave + Vector2(0, -30), "zoom": 1.1, "time": 3.0},
		{"say": "", "text": "By the broken chapel an old priest is digging a grave, alone."},
		{"say": "pell", "text": "Father? We're only passing through. East, to the queen's court, if it still exists."},
		{"say": "anselm", "text": "Then you'll pass a great many dead on your way. I'm Anselm. I bury them. One a day, when my back allows it."},
		{"say": "brenna", "text": "There must be thousands."},
		{"say": "anselm", "text": "And something walks the field at night and stands them up again. My gravediggers can't go out alone. Help us, knight, and I'll tell you where the court went."},
		{"say": "anselm", "text": "And the chapel there: it isn't dead, only sleeping. Go and see for yourself."},
		{"do": func() -> void: _drop_actor(r)},
		{"camera": r.at(c) + Vector2(0, -40), "zoom": 1.0, "time": 2.0},
		{"say": "", "text": "Bury %d of the fallen in the graveyard before too many of them rise, and wake the chapel. Brenna can't be brought back here; Pell and Anselm must not die." % BURY},
	]


func outro(r: ScenarioRunner) -> Array[Dictionary]:
	var gy := _graveyard(r)
	var grave: Vector2 = r.at(gy.tile) if gy else r.at(r.game.player_village.center)
	return [
		{"do": func() -> void: r.dusk(3.0)},
		{"camera": grave + Vector2(0, -30), "zoom": 1.15, "time": 2.0},
		{"say": "", "text": "The last grave of the day is filled. Anselm plants the cross himself, and stands a while."},
		{"say": "anselm", "text": "Blue and crimson, side by side. They'll quarrel less down there than they did up here."},
		{"say": "brenna", "text": "You said you'd tell me where the court went."},
		{"say": "anselm", "text": "East. Fiona's court and what was left of the church, to a valley in the forest where the druids keep their distance from the war."},
		{"say": "anselm", "text": "Take this. A priest's word, sealed. It will get a knight of Rhodri's army through their gate."},
		{"say": "anselm", "text": "It won't get you trusted. That you'll have to do yourself."},
		{"say": "pell", "text": "Then we'd better start early."},
		{"fade": "out", "time": 1.5},
	]


## Anselm tells of the battle and the dead between the waves.
func on_wave_finished(r: ScenarioRunner, n: int) -> void:
	var lines: Array[Dictionary] = []
	match n:
		1:
			lines = [
				{"say": "brenna", "text": "Who were they?"},
				{"say": "anselm", "text": "Fiona's soldiers and her mages, who fell here. And Rhodri's soldiers, who fell beside them. The crows didn't care whose they were."},
				{"say": "anselm", "text": "The church came to bury them, after. Too many dead, too few hands, and the beasts came down for them. So they lie."},
			]
		5:
			lines = [
				{"say": "pell", "text": "They say Rhodri does this. That he feeds on the war."},
				{"say": "anselm", "text": "He feeds on it, maybe. But it isn't his will alone. His dead rise, and hers, and the beasts' too. The land is sick with the unburied."},
				{"say": "anselm", "text": "Every grave we fill is one soldier fewer for whatever walks out there."},
			]
	if lines.is_empty():
		return
	var scene: Array[Dictionary] = [{"camera": r.at(r.game.player_village.center) + Vector2(0, -40), "zoom": 1.1, "time": 1.0}]
	scene.append_array(lines)
	r.play_scene(scene)


## Wave 3: the first necromancer.
func on_wave_started(r: ScenarioRunner, n: int) -> void:
	if n == 3:
		r.play_scene([
			{"say": "anselm", "text": "There. The one in green. It walks among the dead and calls them, and they come."},
			{"say": "brenna", "text": "Then it doesn't reach the field."},
		])


## The chapel awake (once Brenna woke it); the dead raised: too many, lost.
func on_poll(r: ScenarioRunner) -> void:
	if r.cutscene == null:
		_drop_actor(r)  # (a skipped intro leaves him standing)
	if r.game.is_unlocked("acolyte") and not r.mark.has("chapel scene"):
		r.mark["chapel scene"] = true
		var ch := r.site("chapel")
		r.play_scene([
			{"camera": r.at(ch.tile if ch else r.game.player_village.center) + Vector2(0, -40), "zoom": 1.1, "time": 1.5},
			{"say": "", "text": "Light falls through the broken roof of the chapel, though the sky is grey."},
			{"say": "anselm", "text": "You see? Sleeping. Now it has someone to answer. Send me the willing, and I'll make acolytes of them."},
		])
	if _buried(r) + _still_to_bury(r) < BURY:
		r.lose("Too many of the fallen have risen: no longer enough are left to bury.")


# --- the cards ------------------------------------------------------------------------------

func steps(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"title": "The fallen",
			"text": "The dead of the battle lie on the plain (marked). Gatherers carry them to the graveyard by the chapel, where Anselm buries them; once buried, nobody can raise them. Gatherers only go out where no enemy is near: recruit another one.",
			"done": func() -> bool: return _buried(r) >= 3,
			"point": func() -> Dictionary:
				var tiles: Array = []
				for cl in _clusters(r):
					tiles.append(cl)
				if g.population.count("gatherer") < 3:
					return {"hud": ["village:gatherer", "tab:village", "dock"], "tab": "village", "tiles": tiles}
				return {"tiles": tiles}},
		{"title": "The sleeping chapel",
			"text": "Anselm says the chapel isn't dead, only sleeping. Send Brenna exploring: she goes there first and wakes it, and you can recruit acolytes.",
			"done": func() -> bool: return g.is_unlocked("acolyte"),
			"point": func() -> Dictionary:
				var ch := r.site("chapel")
				var tiles: Array = [ch.tile] if ch else []
				return {"tiles": tiles} if g.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"], "tiles": tiles}},
		{"title": "Holy light",
			"text": "An acolyte's holy light hurts the Undead most: skeletons, the necromancers, and everything they raise. Recruit one and station it on a tower by the field.",
			"done": func() -> bool: return g.army.units.any(func(u: MilitaryUnit) -> bool: return u.kind in ["acolyte", "inquisitor", "high_priest"] and u.state == MilitaryUnit.State.STATIONED),
			"point": func() -> Dictionary: return r.unit_point("acolyte", r.towers())},
	]


func hints(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "necromancer",
			"when": func() -> bool: return r.enemy_about("necromancer"),
			"text": "A necromancer: it raises the dead near its road, the fallen of the field too. Kill it before it gets to them, or bury them first."},
		{"id": "risen",
			"when": func() -> bool: return _buried(r) + _still_to_bury(r) < int(r.mark.get("placed", FALLEN)),
			"text": func() -> String: return "One of the fallen has risen. %d can still be buried; %d are needed." % [_still_to_bury(r), maxi(0, BURY - _buried(r))]},
		{"id": "hurt",
			"when": func() -> bool: return not g.hero.dead and g.hero.hp < g.hero.max_hp * 0.35,
			"text": "Brenna is badly hurt, and here nobody can bring her back. Send her home to rest (her panel: Rest) until she has healed."},
		{"id": "food",
			"when": func() -> bool: return g.economy.amount("food") < 40.0,
			"text": "Food is short on this dry land. Pell sells food, and farms do better on what little meadow there is."},
	]


func objectives(r: ScenarioRunner) -> Array[Dictionary]:
	var g := r.game
	return [
		{"id": "bury", "text": "Bury %d of the fallen" % BURY,
			"done": func() -> bool: return _buried(r) >= BURY,
			"detail": func() -> String: return "%d / %d" % [mini(_buried(r), BURY), BURY]},
		{"id": "chapel", "text": "Wake the chapel",
			"done": func() -> bool: return g.is_unlocked("acolyte")},
	]


## The fallen on the field (Anselm knows where they lie: their places are
## uncovered).
func on_start(r: ScenarioRunner) -> void:
	var g := r.game
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var spots := _open_tiles(r)
	var vid := g.player_village.id
	var per := ceili(float(FALLEN) / float(maxi(1, _clusters(r).size())))
	var left := FALLEN
	for cl: Vector2i in _clusters(r):
		g.fog.reveal(Vector2(cl), 4.0, vid)
		var near := spots.filter(func(t: Vector2i) -> bool: return Vector2(t).distance_to(Vector2(cl)) <= 2.6)
		for i in mini(per, left):
			if near.is_empty():
				break
			var t: Vector2i = near.pop_at(rng.randi_range(0, near.size() - 1))
			g.corpses.spawn_fallen(Vector2(t) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))
			left -= 1
	r.mark["placed"] = FALLEN - left


func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s. Pell and Anselm must not die." % [civ.label().capitalize(), reason]


# --- helpers -----------------------------------------------------------------------------

func _graveyard(r: ScenarioRunner) -> Graveyard:
	var list := r.pieces("graveyard")
	return list[0] if not list.is_empty() else null


func _buried(r: ScenarioRunner) -> int:
	var gy := _graveyard(r)
	return gy.buried if gy else 0


## The fallen not yet buried: on the field, and carried by gatherers (and
## Brenna) on their way to the graveyard.
func _still_to_bury(r: ScenarioRunner) -> int:
	var n := r.game.corpses.fallen().size()
	for c in r.game.population.civilians:
		if c is Gatherer:
			n += (c as Gatherer).job.carried_fallen
	var hj = r.game.hero.jobs.get(Hero.Mode.GATHER)
	if hj is GatherJob:
		n += (hj as GatherJob).carried_fallen
	return n


## Where the clusters of the fallen lie: open land FIELD tiles out, as far
## apart as can be (kept once found).
func _clusters(r: ScenarioRunner) -> Array:
	if r.mark.has("clusters"):
		return r.mark["clusters"]
	var c := Vector2(r.game.player_village.center)
	var spots := _open_tiles(r).filter(func(t: Vector2i) -> bool:
		var d := Vector2(t).distance_to(c)
		return d >= FIELD.x and d <= FIELD.y)
	var out: Array = []
	if not spots.is_empty():
		spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return MapData.row_order(a, b))
		out.append(spots[spots.size() / 2])
		while out.size() < CLUSTERS:
			var best: Vector2i = spots[0]
			var best_d := -1.0
			for t: Vector2i in spots:
				var d := INF
				for o: Vector2i in out:
					d = minf(d, Vector2(t).distance_to(Vector2(o)))
				if d > best_d:
					best_d = d
					best = t
			out.append(best)
	r.mark["clusters"] = out
	return out


## Open land the village's people can walk to: no road, water, trees, rock,
## building, object or village.
func _open_tiles(r: ScenarioRunner) -> Array:
	if r.mark.has("open"):
		return (r.mark["open"] as Array).duplicate()
	var g := r.game
	var m := g.map
	var dist := g.world.pathing.distance_field(g.player_village.center)
	var out: Array = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.is_passable(t) and not m.is_road(t) and not m.is_wet(t) and not m.in_village(t) and m.building_at(t) == null and dist[m.index(t)] < Pathing.UNREACHABLE:
				out.append(t)
	r.mark["open"] = out
	return out.duplicate()


func _drop_actor(r: ScenarioRunner) -> void:
	var n = r.mark.get("anselm actor")
	if n is Node and is_instance_valid(n):
		(n as Node).queue_free()
	r.mark.erase("anselm actor")
