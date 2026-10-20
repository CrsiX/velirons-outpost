class_name ScenarioRunner
extends Node
## Plays one Scenario (docs/scenarios-design.md) in a game (a child of Game,
## as the tutorial is). It sets up the scenario's baseline (map file,
## village, villagers, hero, resources), applies its rules (what can be built
## and recruited, enemy strength, its waves, its defeats), and runs its story:
## the intro cutscene, the hero's walk to the village, her arrival, the
## teaching cards, one-time hints, the objectives, and the outro once every
## objective is met.
##
## The content comes from the Scenario (scenario_<n>.gd); the helpers below
## (spots, towers(), farms(), ...) are for its cards and objectives.

signal won

enum Phase { INTRO, WALK, ARRIVAL, PLAY, OUTRO, OVER }

const POLL := 0.25
## Seconds between a done card and the next one.
const STEP_PAUSE := 1.2
## Seconds a hint stays on the card.
const HINT_TIME := 14.0
## Tiles revealed around the tent, and along the hero's way to the village.
const TENT_REVEAL := 3.5
const WAY_REVEAL := 2.2

var game: Game
var spec: Scenario
var phase := Phase.INTRO
## Why the map file couldn't be used ("" if it could): the game then runs on a
## generated map, and the scenario says so.
var error := ""
var spots: RoadSpots
var highlight: TutorialHighlight
var card: ScenarioCard
## The cutscene playing now, or null.
var cutscene: Cutscene
var tent_node: Node2D
## The hero's way from her start to the village centre (tiles).
var way: Array[Vector2i] = []
var steps: Array[Dictionary] = []
## Index into steps (-1 before the first; steps.size() when they're all done).
var step := -1
var hints: Array[Dictionary] = []
var objectives: Array[Dictionary] = []
## Whatever a card needs to remember (unit levels when it began, ...).
var mark := {}
var start_villagers := 0
## Each objective's last state (id -> done), so a change is logged once.
var _goal_state := {}
## Objectives with "shown" that have appeared (id -> true).
var _goal_shown := {}
var _hints_shown := {}
var _hint_left := 0.0
var _poll := 0.0
var _next_in := -1.0
var _tab := ""
var _old_difficulty = null  # (Settings.Difficulty)
## Smoke over ruined huts (hut -> particles), gone once rebuilt.
var _smoke := {}
var _outro_started := false
## Prebuilt posts and their units: [[post, [{"kind", "level"}]]].
var _prebuilt: Array = []
## The map's ruins by kind, nearest the village first, as they were (_restore_ruin).
var _ruin_order := {}
## RoadSpots per road index (road_spots).
var _roads := {}
## The map's ruined towers and barracks at the start: [{"tile", "building"}].
var ruin_sites: Array[Dictionary] = []
## Scenes waiting for the one playing now (play_scene).
var _scene_queue: Array = []
## The journal shown now (show_journal), or null.
var journal: Journal = null


## Before the world is made: the map from its file, the difficulty and the
## enemy strength, the starting village.
func prepare(p_game: Game, p_spec: Scenario) -> void:
	game = p_game
	spec = p_spec
	var r := MapLibrary.load_file(spec.map_path)
	if r["map"] == null:
		error = "The scenario's map couldn't be read: %s" % "; ".join(r["errors"])
		push_error(error)
	else:
		var m: MapData = r["map"]
		game.preset_map = m.for_game([clampi(spec.village, 0, m.villages.size() - 1)])
	game.disable_fog = false
	game.start_resources = spec.resources.duplicate()
	game.start_civilians.assign(spec.civilians)
	game.start_buildings.assign(spec.buildings)
	_old_difficulty = Settings.difficulty
	Settings.difficulty = Settings.difficulty_of(spec.difficulty)
	Settings.enemy_scale = spec.enemy_scale.duplicate()


func _exit_tree() -> void:
	if _old_difficulty != null:
		Settings.difficulty = _old_difficulty
	Settings.enemy_scale = {}


## The world is made, the villagers aren't yet: the village as the scenario
## has it (ruined huts, broken walls, gates and towers).
func apply_baseline() -> void:
	var v := game.player_village
	v.construction.setup(v)  # (before the village's own setup: the prebuilt posts need it)
	var c := Vector2(v.center)
	var huts := v.huts()
	huts.sort_custom(func(a: Building, b: Building) -> bool: return Vector2(a.tile).distance_to(c) < Vector2(b.tile).distance_to(c))
	for i in huts.size():
		if i >= spec.huts_standing:
			var h := huts[i] as Hut
			h.ruined = true
			h.refresh()
	for kind: String in spec.piece_levels:
		for b in v.buildings().filter(func(x: Building) -> bool: return x.kind == kind):
			b.level = int(spec.piece_levels[kind])
			b.hp = b.max_hp()
			b.refresh()
	for kind: String in spec.pieces_standing:
		var list := v.buildings().filter(func(b: Building) -> bool: return b.kind == kind)
		list.sort_custom(func(a: Building, b: Building) -> bool: return MapData.row_order(a.tile, b.tile))
		for i in list.size():
			var b: Building = list[i]
			if i < int(spec.pieces_standing[kind]):
				b.hp = maxf(1.0, roundf(b.max_hp() * spec.pieces_hp))
				b.queue_redraw()
			else:
				b.set_devastated(true)
	_prebuild()
	game.siege.mark_stale(v, true)
	for o in game.world.map_objects:
		if o is RuinedTower:
			ruin_sites.append({"tile": o.tile, "building": (o as RuinedTower).building()})


## The scenario's prebuilt posts and buildings (Scenario.prebuilt), finished;
## their units come once the army is set up (_man_prebuilt).
func _prebuild() -> void:
	var v := game.player_village
	var taken: Array[Vector2i] = []
	for p in spec.prebuilt:
		var kind := str(p["kind"])
		var b: Building = null
		if kind == "wall_tower":
			b = _wall_tower_by(road_spots(int(p.get("road", 0))))
		elif p.has("ruin"):
			b = _restore_ruin(kind, int(p["ruin"]))
		else:
			var t: Vector2i = p.get("tile", Vector2i(-1, -1))
			if p.has("offset"):
				t = _spot_near(kind, v.center + (p["offset"] as Vector2i), taken)
			elif p.get("near_water", false):
				t = _spot_by_water(kind, taken)
			elif p.has("near_site"):
				t = _spot_by_site(kind, str(p["near_site"]), taken)
			if t == Vector2i(-1, -1):
				var at: Array = p.get("at", [3, 7])
				t = road_spots(int(p.get("road", 0))).by_road(kind, int(at[0]), int(at[1]), taken)
			if t == Vector2i(-1, -1) or v.construction.placement_error(kind, t, true) != "":
				push_warning("scenario %d: no room for a prebuilt %s (%s)" % [spec.number, kind, str(p)])
				continue
			b = v.construction._new_building(kind, t, true)
			taken.append_array(Building.footprint(t, int(Config.BUILDINGS[kind]["size"])))
			for q in b.tiles():
				game.world.clear_decor(q)  # (the decor isn't drawn yet: nothing else clears it)
			game.fog.reveal(Vector2(t), 3.0, v.id)
		if b == null:
			continue
		if p.has("level"):
			b.level = int(p["level"])
			b.hp = b.max_hp()
			b.refresh()
		if p.has("units"):
			_prebuilt.append([b, p["units"]])


## The map's ruin of a `kind` ("tower", "barracks") number `i` (nearest the
## village first), standing restored and finished; null if there is none.
func _restore_ruin(kind: String, i: int) -> Building:
	if not _ruin_order.has(kind):  # (in the map's order, before any is restored)
		var c := Vector2(game.player_village.center)
		var all := game.world.map_objects.filter(func(o: Node) -> bool: return o is RuinedTower and (o as RuinedTower).building() == kind)
		all.sort_custom(func(a: Node, b: Node) -> bool: return Vector2((a as RuinedTower).tile).distance_to(c) < Vector2((b as RuinedTower).tile).distance_to(c))
		_ruin_order[kind] = all
	var list: Array = _ruin_order[kind]
	if i < 0 or i >= list.size() or not is_instance_valid(list[i]) or not game.world.map_objects.has(list[i]):
		push_warning("scenario %d: no ruined %s number %d" % [spec.number, kind, i])
		return null
	var ruin := list[i] as RuinedTower
	var t := ruin.tile
	game.world.remove_map_object(ruin)
	var b := game.player_village.construction._new_building(kind, t, true)
	game.fog.reveal(Vector2(t), 3.0, game.player_village.id)
	return b


## Where a `kind` goes near `want`: there, else the free spot nearest it
## (off the roads, within 6 tiles); (-1, -1) if there is none.
func _spot_near(kind: String, want: Vector2i, taken: Array[Vector2i]) -> Vector2i:
	var v := game.player_village
	var size := int(Config.BUILDINGS[kind]["size"])
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var t := want + Vector2i(dx, dy)
			var d := Vector2(dx, dy).length()
			if d >= best_d or Building.footprint(t, size).any(func(q: Vector2i) -> bool: return taken.has(q) or not game.map.in_bounds(q) or game.map.is_road(q)):
				continue
			if v.construction.placement_error(kind, t, true) == "":
				best_d = d
				best = t
	return best


## Where a `kind` goes by the water: a free spot next to the walls (within
## the band where enemies leave their roads, Config.SIEGE.approach) nearest
## the water; (-1, -1) if there is none.
func _spot_by_water(kind: String, taken: Array[Vector2i]) -> Vector2i:
	var v := game.player_village
	var size := int(Config.BUILDINGS[kind]["size"])
	var band := v.rect.grow(int(Config.SIEGE["approach"]) - 1)
	var water: Array[Vector2i] = []
	var look := v.rect.grow(14)
	for y in range(look.position.y, look.end.y):
		for x in range(look.position.x, look.end.x):
			if game.map.is_water(Vector2i(x, y)):
				water.append(Vector2i(x, y))
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(band.position.y, band.end.y):
		for x in range(band.position.x, band.end.x):
			var t := Vector2i(x, y)
			var fp := Building.footprint(t, size)
			if fp.any(func(q: Vector2i) -> bool: return not band.has_point(q) or taken.has(q) or game.map.is_road(q)):
				continue
			if v.construction.placement_error(kind, t, true) != "":
				continue
			var d := INF
			for w in water:
				d = minf(d, Vector2(w).distance_to(Vector2(t)))
			if d < best_d:
				best_d = d
				best = t
	return best


## Where a `kind` goes by the map's unlock site of `site_kind`: the free spot
## nearest it (off the roads, within 6 tiles); (-1, -1) if there is none.
func _spot_by_site(kind: String, site_kind: String, taken: Array[Vector2i]) -> Vector2i:
	var s := site(site_kind)
	if s == null:
		return Vector2i(-1, -1)
	var v := game.player_village
	var size := int(Config.BUILDINGS[kind]["size"])
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var t := s.tile + Vector2i(dx, dy)
			var fp := Building.footprint(t, size)
			if fp.any(func(q: Vector2i) -> bool: return taken.has(q) or not game.map.in_bounds(q) or game.map.is_road(q) or game.map.props.has(q) or Vector2(q).distance_to(Vector2(s.tile)) < 1.5):
				continue
			if v.construction.placement_error(kind, t, true) != "":
				continue
			var d := Vector2(t).distance_to(Vector2(s.tile))
			if d < best_d:
				best_d = d
				best = t
	return best


## The village's corner tower nearest the gate of `rs`'s road.
func _wall_tower_by(rs: RoadSpots) -> Building:
	var gate: Vector2 = Vector2(rs.route[-1]) if not rs.route.is_empty() else Vector2(game.player_village.center)
	var best: Building = null
	for b in pieces("wall_tower"):
		if best == null or Vector2(b.tile).distance_to(gate) < Vector2(best.tile).distance_to(gate):
			best = b
	return best


## The prebuilt posts' units, on their posts (no walking there, no gold).
func _man_prebuilt() -> void:
	var army := game.army
	for pair in _prebuilt:
		var post := pair[0] as MilitaryPost
		if post == null:
			continue
		var list: Array = pair[1]
		for i in mini(list.size(), post.capacity()):
			var u: Dictionary = list[i]
			var unit := MilitaryUnit.new(str(u["kind"]))
			unit.village = game.player_village
			unit.original_owner = game.player_village
			unit.nid = game.register(unit)
			unit.uid = game.next_id(unit.kind)
			unit.level = clampi(int(u.get("level", 1)) - 1, 0, Config.MAX_UNIT_LEVEL - 1)
			unit.hp = unit.max_hp()
			unit.bound = bool(u.get("fixed", false))
			army.units.append(unit)
			unit.post = post
			unit.slot = i
			unit.state = MilitaryUnit.State.STATIONED
			post.set_slot(i, unit)
	army.changed.emit()


## The scenario's units in the reserve at the start (Scenario.reserve).
func _fill_reserve() -> void:
	give_units(spec.reserve)


## Units into the reserve: [{"kind", "level"}] (a scenario's band,
## reinforcements); returns them.
func give_units(list: Array[Dictionary]) -> Array[MilitaryUnit]:
	var out: Array[MilitaryUnit] = []
	for u in list:
		var unit := MilitaryUnit.new(str(u["kind"]))
		unit.village = game.player_village
		unit.original_owner = game.player_village
		unit.nid = game.register(unit)
		unit.uid = game.next_id(unit.kind)
		unit.level = clampi(int(u.get("level", 1)) - 1, 0, Config.MAX_UNIT_LEVEL - 1)
		unit.hp = unit.max_hp()
		game.army.units.append(unit)
		out.append(unit)
	if not list.is_empty():
		game.army.changed.emit()
	return out


## The map's lairs as the scenario has them (Scenario.lairs), nearest first.
func _set_lairs() -> void:
	if spec.lairs.is_empty():
		return
	var list := lairs()
	for i in list.size():
		var l := list[i] as MonsterLair
		l.stays_cleared = true
		if i >= spec.lairs.size():
			l.wake_wave = 0
			continue
		var d: Dictionary = spec.lairs[i]
		l.wake_wave = int(d.get("wake", 0))
		l.guard_kinds = d.get("guards", [])
		l.guard_hp = float(d.get("guard_hp", 0.0))
		l.kinds_any.assign(d.get("kinds", []))


## The map's monster lairs, nearest the village first.
func lairs() -> Array:
	var c := Vector2(game.player_village.center)
	var list := game.world.map_objects.filter(func(o: Node) -> bool: return o is MonsterLair)
	list.sort_custom(func(a: Node, b: Node) -> bool: return Vector2((a as MonsterLair).tile).distance_to(c) < Vector2((b as MonsterLair).tile).distance_to(c))
	return list


## A RoadSpots on road `which` (0: the one nearest the village by road), kept.
func road_spots(which: int) -> RoadSpots:
	if not _roads.has(which):
		var rs := RoadSpots.new(game)
		rs.pick_route(60, spec.number, which)
		_roads[which] = rs
	return _roads[which]


## Once the game is set up (villages, HUD): the rules, the hero at her start,
## the card, and the intro.
func start() -> void:
	var v := game.player_village
	var h := game.hero
	start_villagers = game.population.count()
	for key in spec.unlocked:
		game.unlocks[key] = true
	for kind: String in spec.sites:
		if int(spec.sites[kind]) == 0:
			awaken_site(kind, false)
	_name_villagers()
	_man_prebuilt()
	_fill_reserve()
	_set_lairs()
	if spec.hero_name != "":
		h.given_name = spec.hero_name
	if spec.hero_level > 1:
		h.level = spec.hero_level - 1
		h.max_hp = Config.hero_stat("hp", h.level)
		h.hp = h.max_hp
	h.downed.connect(_on_hero_downed)
	game.population.civilian_died.connect(_on_villager_died)
	var w := game.waves
	w.hold = spec.first_wave_waits
	w.buffer = spec.wave_gap
	w.last_wave = 0 if spec.repeat_last else spec.waves.size()
	w.amphibians_from_water = spec.amphibians_from_water
	w.call_locked = spec.first_wave_waits and not spec.first_wave_call
	for wave in spec.waves:
		w.scripted.append(wave.duplicate(true))
	w.wave_started.connect(_on_wave_started)
	w.wave_finished.connect(_on_wave_finished)
	game.corpses.rot = spec.corpses_rot
	spots = RoadSpots.new(game)
	spots.pick_route(18, spec.number)
	if spec.hero_start != Vector2i(-1, -1) and game.map.in_bounds(spec.hero_start):
		_place_hero_at_start()
	_smoke_ruins()
	highlight = TutorialHighlight.new(game)
	highlight.name = "ScenarioHighlight"
	game.hud.add_layer(highlight, true)
	Layout.bleed(highlight)
	card = ScenarioCard.new()
	card.build(game.hud, "Scenario %d: %s" % [spec.number, spec.title])
	card.set_folded(false)
	game.hud.add_layer(card, false)
	steps = spec.steps(self)
	hints = spec.hints(self)
	objectives = spec.objectives(self)
	card.set_objectives(objectives)
	spec.on_start(self)
	game.events.debug("scenario %d (%s): %d waves, the hero starts at %s" % [spec.number, spec.title, spec.waves.size(), spec.hero_start])
	if error != "":
		v.toast(error, UiTheme.BAD)
	_play(spec.intro(self), _after_intro)


# --- the start: the hero's tent, her walk, the ruins' smoke ----------------------------------

func _name_villagers() -> void:
	var named := {}
	for c in game.population.civilians:
		if spec.names.has(c.role) and not named.has(c.role):
			named[c.role] = true
			c.given_name = str(spec.names[c.role])
			if spec.homes.has(c.given_name) and is_instance_valid(c.hut):
				var home: Dictionary = spec.homes[c.given_name]
				c.hut.look = str(home.get("art", ""))
				c.hut.look_name = str(home.get("name", ""))
				c.hut.refresh()


## She stands by her tent (it is uncovered, and so is the road she came by
## and the way home); she waits there until the intro is over.
func _place_hero_at_start() -> void:
	var h := game.hero
	var from := spec.hero_start
	h.set_grid_pos(Vector2(from))
	h.at_home = true
	h.set_process(false)
	var vid := game.player_village.id
	game.fog.reveal(Vector2(from), TENT_REVEAL, vid)
	var p := game.world.pathing.find_path(from, game.player_village.center)
	way.clear()
	for q in p:
		way.append(Vector2i(q.round()))
	for i in range(0, way.size(), 2):
		game.fog.reveal(Vector2(way[i]), WAY_REVEAL, vid)
	if spec.tent_tile != Vector2i(-1, -1):
		tent_node = Node2D.new()
		tent_node.name = "Tent"
		tent_node.position = Iso.tile_to_world(spec.tent_tile)
		tent_node.add_child(Art.sprite("tent_small"))
		game.world.objects.add_child(tent_node)
		game.fog.reveal(Vector2(spec.tent_tile), TENT_REVEAL, vid)
	game.camera.focus(Iso.to_world(Vector2(from)))


## A column of smoke over a few ruined huts (gone once rebuilt).
func _smoke_ruins() -> void:
	var n := 0
	for h in game.player_village.huts():
		if (h as Hut).ruined and n < 3:
			var p := CPUParticles2D.new()
			p.texture = _puff()
			p.amount = 18
			p.lifetime = 4.5
			p.preprocess = 4.5
			p.direction = Vector2(0.3, -1)
			p.spread = 12.0
			p.gravity = Vector2(6, -12)
			p.initial_velocity_min = 16.0
			p.initial_velocity_max = 26.0
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.1
			var grow := Curve.new()
			grow.add_point(Vector2(0, 0.4))
			grow.add_point(Vector2(1, 1.6))
			p.scale_amount_curve = grow
			var ramp := Gradient.new()
			ramp.set_color(0, Color(0.22, 0.2, 0.19, 0.85))
			ramp.set_color(1, Color(0.5, 0.48, 0.46, 0.0))
			p.color_ramp = ramp
			game.world.effects.add_child(p)
			p.global_position = h.global_position + Vector2(0, -20)
			_smoke[h] = p
			n += 1


## A soft round puff for the smoke.
static func _puff() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 48
	t.height = 48
	return t


func _after_intro(_skipped: bool) -> void:
	if spec.hero_start == Vector2i(-1, -1):
		_begin_play()
		return
	if spec.hero_lives_out:
		game.hero.set_process(true)
		game.hero.home_override = spec.hero_start
		_begin_play()
		return
	phase = Phase.WALK
	var h := game.hero
	h.set_process(true)
	h.set_mode(Hero.Mode.REST)  # (she walks to the centre: Rest's way home)
	card.visible = true
	card.show_lesson(spec.walk_title, spec.walk_text)
	game.events.debug("scenario: %s walks from %s to the village" % [h.label(), spec.hero_start])


func _walk(_delta: float) -> void:
	var h := game.hero
	card.place()
	game.camera.focus(h.position)
	if h.at_home and h.grid_pos.distance_to(Vector2(game.player_village.center)) < 0.2:
		phase = Phase.ARRIVAL
		h.set_mode(Hero.Mode.DEFEND)  # (no resting, no snoring: she's home)
		if is_instance_valid(tent_node):
			tent_node.queue_free()  # (packed up and brought home)
		card.visible = false
		_play(spec.arrival(self), func(_s: bool) -> void: _begin_play())


## She may live in the village now (hero_lives_out): she packs up her tent
## and walks in.
func hero_moves_in() -> void:
	var h := game.hero
	if h.home_override == Vector2i(-1, -1):
		return
	h.home_override = Vector2i(-1, -1)
	if is_instance_valid(tent_node):
		tent_node.queue_free()
	game.events.info("%s moves into the village" % h.label())


func _begin_play() -> void:
	phase = Phase.PLAY
	game.hero.set_mode(Hero.Mode.DEFEND)
	card.visible = true
	if not steps.is_empty():
		_begin(0)
	else:
		_end_steps()
	_poll_now()


# --- cutscenes ---------------------------------------------------------------------------------

## Plays `list` (nothing if empty) and calls `then(skipped)` once it is over.
func _play(list: Array[Dictionary], then: Callable) -> void:
	if list.is_empty():
		then.call(false)
		return
	var was_card := card != null and card.visible
	var held := game.waves.hold
	game.waves.hold = true  # (no countdown runs out during a cutscene)
	if card:
		card.visible = false
	if highlight:
		highlight.visible = false
	cutscene = Cutscene.new()
	cutscene.name = "Cutscene"
	cutscene.finished.connect(func(skipped: bool) -> void:
		cutscene = null
		game.waves.hold = held
		if card:
			card.visible = was_card
		game.events.debug("cutscene over%s" % (" (skipped)" if skipped else ""))
		if phase == Phase.OVER:
			return  # (lost meanwhile: nothing follows)
		if highlight:
			highlight.visible = true
		then.call(skipped))
	cutscene.play(game, list, spec.speakers)


## A short scene during play (between waves: a talk, a visitor); one after
## the other if one is playing already.
func play_scene(list: Array[Dictionary]) -> void:
	if cutscene != null:
		_scene_queue.append(list)
		return
	_play(list, func(_s: bool) -> void:
		if not _scene_queue.is_empty() and phase == Phase.PLAY:
			play_scene(_scene_queue.pop_front()))


## Helpers for the cutscenes: where a tile is on the map (world position).
func at(tile) -> Vector2:
	return Iso.to_world(Vector2(tile))


## A figure for a cutscene (a cart, a person) standing on `tile`: a sprite of `art`.
func actor(art: String, tile: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = Iso.to_world(tile)
	n.add_child(Art.sprite(art))
	game.world.objects.add_child(n)
	return n


## Moves `n` along `tiles` (grid positions) in `time` real seconds.
func move_actor(n: Node2D, tiles: Array, time: float) -> void:
	if tiles.size() < 2:
		return
	var tw := n.create_tween()
	tw.set_ignore_time_scale(true)
	var per := time / float(tiles.size() - 1)
	var left := Iso.to_world(Vector2(tiles[-1])).x < Iso.to_world(Vector2(tiles[0])).x
	n.scale.x = -absf(n.scale.x) if left else absf(n.scale.x)  # (art faces right)
	for i in range(1, tiles.size()):
		tw.tween_property(n, "position", Iso.to_world(Vector2(tiles[i])), per)


## The last `n` road tiles a wagon (or an enemy) takes from the map edge to the
## gate nearest `near` (the edge spawn closest to it); [] if there's none.
func road_in(near: Vector2i, n: int) -> Array[Vector2i]:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for sp in game.map.edge_spawns:
		var d := Vector2(sp).distance_to(Vector2(near))
		if d < best_d:
			best_d = d
			best = sp
	if best == Vector2i(-1, -1):
		return [] as Array[Vector2i]
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.number
	var full := game.world.pathing.enemy_route(best, rng)
	return full.slice(maxi(0, full.size() - n))


## A guild caravan (ScenarioCaravan) down the road from the edge spawn
## nearest `near` to the gate, bringing `cargo` ({"gold", "food",
## "materials"}); it halts while an enemy is near it.
func caravan(near: Vector2i, cargo: Dictionary) -> ScenarioCaravan:
	var road := road_in(near, 100000)
	if road.size() < 2:
		return null
	var c := ScenarioCaravan.new()
	c.setup(game, road, cargo)
	game.world.objects.add_child(c)
	game.events.info("A guild caravan is on the road with %s" % Config.cost_text(cargo))
	return c


## The map darkens to dusk over `time` seconds (a cutscene's evening).
func dusk(time: float) -> void:
	var cm := CanvasModulate.new()
	cm.name = "Dusk"
	cm.color = Color.WHITE
	game.add_child(cm)
	var tw := cm.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(cm, "color", Color(0.72, 0.6, 0.55), time)


# --- the cards ---------------------------------------------------------------------------------

func _begin(i: int) -> void:
	step = i
	_next_in = -1.0
	_tab = ""
	var s: Dictionary = steps[i]
	if s.has("start"):
		(s["start"] as Callable).call()
	card.show_lesson(str(s["title"]), str(s["text"]))
	game.events.debug("scenario card %d: %s" % [i + 1, s["title"]])
	_point()


func _end_steps() -> void:
	step = steps.size()
	highlight.clear()
	card.show_lesson("", "")


func _poll_steps(delta: float) -> void:
	if step < 0 or step >= steps.size():
		return
	if _next_in >= 0.0:
		_next_in -= delta
		if _next_in < 0.0:
			if step + 1 >= steps.size():
				_end_steps()
				return
			var next: Dictionary = steps[step + 1]
			if next.has("ready") and not (next["ready"] as Callable).call():
				_next_in = 0.0  # (keeps waiting)
				if next.has("wait_title") and card.lesson_title() != str(next["wait_title"]):
					card.show_lesson(str(next["wait_title"]), str(next.get("wait_text", "")))
				else:
					card.set_lesson_text(str(next.get("wait_text", card.lesson_text())))
			else:
				_begin(step + 1)
		return
	if (steps[step]["done"] as Callable).call():
		card.lesson_done()
		highlight.clear()
		Sfx.play("chime", 0.0)
		game.events.debug("scenario card %d done" % (step + 1))
		spec.on_card_done(self, str(steps[step].get("id", "")))
		_next_in = STEP_PAUSE
	else:
		_point()


## Updates the highlight, as the tutorial's (see Tutorial._point).
func _point() -> void:
	var s: Dictionary = steps[step]
	var p: Dictionary = (s["point"] as Callable).call() if s.has("point") else {}
	var tab := str(p.get("tab", ""))
	if tab != "" and tab != _tab:
		game.hud.show_tab(tab, game.hud.dock_open())
	_tab = tab
	var target: Control = null
	for n in p.get("hud", []):
		var c := game.hud.control_named(n)
		if c and c.is_visible_in_tree():
			target = c
			break
	if target and target != highlight.target:
		game.hud.scroll_to(target)
	var tiles: Array[Vector2i] = []
	tiles.assign(p.get("tiles", []))
	var units: Array[MilitaryUnit] = []
	units.assign(p.get("units", []))
	highlight.point_at(target, game.hud.dock_clip(target), tiles, units)


## The current card's title ("" when none is shown).
func card_title() -> String:
	return str(steps[step]["title"]) if step >= 0 and step < steps.size() else ""


# --- polling: cards, hints, objectives --------------------------------------------------------

func _process(delta: float) -> void:
	if game == null or phase == Phase.OVER:
		return
	if game.game_over:
		card.visible = false
		highlight.visible = false
		return
	match phase:
		Phase.WALK:
			_walk(delta)
		Phase.PLAY:
			card.place()
			_poll_steps(delta)
			if _hint_left > 0.0:
				_hint_left -= delta
				if _hint_left <= 0.0:
					card.show_hint("")
			_poll -= delta
			if _poll <= 0.0:
				_poll_now()
		Phase.OUTRO:
			if not _outro_started and not game.waves.in_progress() and cutscene == null:  # (a scene playing ends first)
				_outro_started = true
				card.visible = false
				highlight.clear()
				_play(spec.outro(self), func(_s: bool) -> void: _win())


func _poll_now() -> void:
	_poll = POLL
	_check_must_stand()
	if phase == Phase.OVER:
		return
	spec.on_poll(self)
	for hut: Node in _smoke.keys():
		if not is_instance_valid(hut) or not (hut as Hut).ruined:
			if is_instance_valid(_smoke[hut]):
				(_smoke[hut] as Node).queue_free()
			_smoke.erase(hut)
	for hn in hints:
		var id := str(hn["id"])
		if not _hints_shown.has(id) and (hn["when"] as Callable).call():
			_hints_shown[id] = true
			var t := str((hn["text"] as Callable).call()) if hn["text"] is Callable else str(hn["text"])
			card.show_hint(t)
			_hint_left = HINT_TIME
			game.events.important(t)
			Sfx.play("chime", 0.0)
	var all := not objectives.is_empty()
	for o in objectives:
		var id := str(o["id"])
		if o.has("shown") and not _goal_shown.has(id):
			if not (o["shown"] as Callable).call():
				card.show_objective(id, false)
				continue
			_goal_shown[id] = true
			card.show_objective(id, true)
		var done: bool = (o["done"] as Callable).call()
		var detail := str((o["detail"] as Callable).call()) if o.has("detail") else ""
		card.set_objective(id, done, detail)
		if done and _goal_state.has(id) and not _goal_state[id]:
			game.events.info("Objective done: %s" % o["text"])  # (not for one met from the start)
		_goal_state[id] = done
		all = all and (done or bool(o.get("optional", false)))
	if all:
		phase = Phase.OUTRO
		game.events.info("Every objective is met")
		game.waves.hold = true
		game.waves.call_locked = true


# --- the rules ---------------------------------------------------------------------------------

## Whether this scenario lets the village have `key` (a military kind or a villager role).
func allows(key: String) -> bool:
	if Config.MILITARY.has(key):
		return spec.recruiting and (spec.units.is_empty() or spec.units.has(key))
	return true


func allows_building(kind: String) -> bool:
	if spec.build.is_empty():
		return not Config.BUILDINGS.get(kind, {}).get("campaign", false)
	return spec.build.has(kind)


func allows_branches() -> bool:
	return spec.specialise


## Why the scenario refuses a command now, or "".
func command_error(type: String, args: Dictionary) -> String:
	var story := phase in [Phase.INTRO, Phase.WALK, Phase.ARRIVAL]
	match type:
		"place_building":
			if not allows_building(str(args.get("kind", ""))):
				return "That can't be built yet"
		"recruit_unit", "send_unit":
			if not allows(str(args.get("kind", ""))):
				return "That unit can't be recruited yet"
		"upgrade_unit":
			var u = game.entity(int(args.get("unit", 0)))
			var to := str(args.get("to", ""))
			if not allows_branches() and u is MilitaryUnit and to != "" and to != (u as MilitaryUnit).kind:
				return "Units can't specialise yet"
		"hero_mode", "hero_support", "attack_camp":
			if story:
				return "%s is on her way home" % game.hero.label()
		"call_wave":
			if story:
				return "Not yet"
	return spec.command_error(self, type, args)


## A kind that must not fall (Scenario.must_stand) has fallen: lost.
func _check_must_stand() -> void:
	for kind in spec.must_stand:
		var list := pieces(kind)
		if list.is_empty() or list.any(func(b: Building) -> bool: return not b.devastated):
			continue
		lose(spec.fallen_text(list[0]))
		return


func _on_villager_died(civ: Civilian, reason: String, _cause: String) -> void:
	if (spec.fail_on_villager_death or spec.must_live.has(civ.given_name)) and phase != Phase.OVER:
		lose(spec.death_text(civ, reason))


func _on_hero_downed() -> void:
	if not spec.hero_revives and phase != Phase.OVER:
		lose("%s was struck down, and nobody can bring her back here." % game.hero.label())


func _on_wave_started(n: int) -> void:
	if n == 1:
		game.waves.hold = false  # (from now on the countdown runs)
	spec.on_wave_started(self, n)


func _on_wave_finished(n: int) -> void:
	spec.on_wave_finished(self, n)
	if spec.repeat_last and n >= spec.waves.size() and game.waves.scripted.is_empty() and not spec.waves.is_empty():
		game.waves.scripted.append(next_wave(n + 1))
	elif n >= spec.waves.size() and phase == Phase.PLAY:
		game.events.info("That was the last wave")


## Wave `n` past the scenario's list (repeat_last): the last one, with
## `more_each_wave` more of its kinds for every wave past it.
func next_wave(n: int) -> Dictionary:
	var w: Dictionary = spec.waves[-1].duplicate(true)
	var past := n - spec.waves.size()
	var kinds: Dictionary = w.get("kinds", {})
	for k in spec.more_each_wave:
		kinds[k] = int(kinds.get(k, 0)) + int(spec.more_each_wave[k]) * past
	w["kinds"] = kinds
	return w


## The first wave may come: its countdown starts at `delay` seconds.
func release_waves(delay: float) -> void:
	var w := game.waves
	w.hold = false
	w.call_locked = false
	if w.wave == 0:
		w.countdown = delay
	w.changed.emit()


## The scenario is lost: `why` on the defeat screen.
func lose(why: String) -> void:
	if phase == Phase.OVER or game.game_over:
		return
	phase = Phase.OVER
	if cutscene:
		cutscene.stop()
	card.visible = false
	highlight.visible = false
	game.events.important("Scenario lost: %s" % why)
	game.end_game("%s failed" % spec.title, "%s\nTry again: the scenario starts over." % why)


func _win() -> void:
	phase = Phase.OVER
	game.events.info("Scenario %d complete" % spec.number)
	Campaign.complete(spec.number)
	won.emit()
	game.end_game("%s: complete" % spec.title, "Scenario %d of the campaign is done." % spec.number, true)


# --- helpers for a scenario's cards and objectives -------------------------------------------

## The player's watchtowers; `walls`: the wall towers too.
func towers(walls := false) -> Array:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b is Tower and (walls or b.kind == "tower"))


func farms() -> Array:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b is Farm and b.kind == "farm")


## The village's pieces of `kind` ("gate", "wall", "wall_tower", "hut").
func pieces(kind: String) -> Array:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b.kind == kind)


## The map's treasures (Treasure), farthest from the village first.
func treasures() -> Array:
	var c := Vector2(game.player_village.center)
	var out := game.world.map_objects.filter(func(o: Node) -> bool: return o is Treasure)
	out.sort_custom(func(a: Node, b: Node) -> bool: return Vector2((a as Treasure).tile).distance_to(c) > Vector2((b as Treasure).tile).distance_to(c))
	return out


## The edge spawn whose road comes in nearest `near` (a tile), or (-1, -1).
func spawn_near(near: Vector2i) -> Vector2i:
	var road := road_in(near, 100000)
	return road[0] if not road.is_empty() else Vector2i(-1, -1)


## `count` more of `kind` for the wave under way, from road tile `tile`
## (they count for the wave); `extra`: "name", "art" (a named Legion captain).
func add_enemies(kind: String, tile: Vector2i, count: int = 1, extra: Dictionary = {}) -> void:
	if tile != Vector2i(-1, -1):
		game.waves.add_to_wave(kind, tile, count, extra)


## Whether an enemy of `kind` is about now (not counting wild ones: camp guards, wrathwoods).
func enemy_about(kind: String) -> bool:
	return game.get_tree().get_nodes_in_group("enemies").any(func(e: Node) -> bool: return (e as Enemy).kind == kind and not (e as Enemy).wild())


## The living enemy named `who` (a Legion captain), or null.
func named_enemy(who: String) -> Enemy:
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).given_name == who and not (e as Enemy).dead:
			return e
	return null


## The map's unlock site of `kind` ("chapel", "stone_circle", "mage_tower"), or null.
func site(kind: String) -> UnlockSite:
	for o in game.world.map_objects:
		if o is UnlockSite and o.data["site"] == kind:
			return o
	return null


## Awakens the map's site of `kind`: the hero can unlock its unit there now
## (`tell`: the log says so).
func awaken_site(kind: String, tell := true) -> void:
	var s := site(kind)
	if s == null or s.awake:
		return
	s.awaken()
	if tell and not game.is_unlocked(str(Config.UNLOCK_SITES[kind]["unlocks"])):
		game.events.info(str(Config.UNLOCK_SITES[kind]["awake"]))


## The village's merchant (the stall's man), or null.
func merchant() -> Merchant:
	for c in game.population.civilians:
		if c is Merchant:
			return c
	return null


## A named villager of `role` joins: made in a free hut (none free: null),
## standing on `at`, from where they go to work or home.
func join_villager(role: String, who: String, at: Vector2i) -> Civilian:
	var civ := game.population.spawn(role)
	if civ == null:
		return null
	civ.given_name = who
	civ.set_grid_pos(Vector2(at))
	civ._set_home(false)
	civ.resume_work()
	game.events.info("%s joins the village" % who)
	return civ


## The village's trade stalls.
func stalls() -> Array:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b is Stall)


## What stands on ruin site `site` (ruin_sites) now: the ruin itself
## (MapObject), the building restored from it, or null.
func on_site(site: Dictionary) -> Node:
	return game.map.building_at(site["tile"])


## The building restored from ruin site `site`: standing (not devastated, no
## repair left), or null.
func restored(site: Dictionary) -> Building:
	var b = on_site(site)
	if b is Building and not (b is MapObject) and b.kind == site["building"] and b.complete and not b.devastated and not b.repairing:
		return b
	return null


## Has the ruin at `site` been claimed by the village (or restored since)?
func claimed(site: Dictionary) -> bool:
	var b = on_site(site)
	return (b is RuinedTower and (b as RuinedTower).village == game.player_village) or (b is Building and not (b is MapObject) and b.village == game.player_village)


## The road tiles from `a` to `b` (both on or next to a road), along the roads
## only, in order; [] if the roads don't join them.
func road_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var m := game.map
	var from := _road_near(a)
	var to := _road_near(b)
	if from == Vector2i(-1, -1) or to == Vector2i(-1, -1):
		return [] as Array[Vector2i]
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var i := 0
	while i < q.size():
		var t := q[i]
		i += 1
		if t == to:
			break
		for n in MapData.neighbors4(t):
			if m.in_bounds(n) and m.is_road(n) and not prev.has(n):
				prev[n] = t
				q.append(n)
	if not prev.has(to):
		return [] as Array[Vector2i]
	var out: Array[Vector2i] = [to]
	while out[0] != from:
		out.push_front(prev[out[0]])
	return out


## The road tiles from (next to) `t` to the village's walls, along the roads
## only, in order; [] if no road joins them.
func road_to_village(t: Vector2i) -> Array[Vector2i]:
	var m := game.map
	var from := _road_near(t)
	if from == Vector2i(-1, -1):
		return [] as Array[Vector2i]
	var near := game.player_village.rect.grow(1)
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var i := 0
	var end := Vector2i(-1, -1)
	while i < q.size():
		var c := q[i]
		i += 1
		if near.has_point(c):
			end = c
			break
		for n in MapData.neighbors4(c):
			if m.in_bounds(n) and m.is_road(n) and not prev.has(n):
				prev[n] = c
				q.append(n)
	if end == Vector2i(-1, -1):
		return [] as Array[Vector2i]
	var out: Array[Vector2i] = [end]
	while out[0] != from:
		out.push_front(prev[out[0]])
	return out


## `t` if it is a road tile, else the nearest road tile within 2.
func _road_near(t: Vector2i) -> Vector2i:
	if game.map.in_bounds(t) and game.map.is_road(t):
		return t
	for r in [1, 2]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := t + Vector2i(dx, dy)
				if game.map.in_bounds(n) and game.map.is_road(n):
					return n
	return Vector2i(-1, -1)


## Watched by one of the village's buildings (towers, light stones, ...: what
## they see, not where people happen to walk).
func lit(t: Vector2i) -> bool:
	for b in game.player_village.buildings():
		var r := b.sight_radius()
		if r > 0.0 and b.working() and b.sight_center().distance_to(Vector2(t)) <= r:
			return true
	return false


## A journal page, a letter or a logbook over the game, paused meanwhile
## (single player); Close or Esc goes on.
func show_journal(title: String, text: String) -> void:
	if journal == null:
		journal = Journal.new()
		journal.setup(game)
	journal.open(title, text)


## Standing at full HP, with no repair, rebuild or upgrade left to do.
func whole(b: Building) -> bool:
	if b is Hut:
		return (b as Hut).is_intact()
	return b.complete and not b.devastated and b.hp >= b.max_hp() - 0.01 and not b.repairing


func first_tiles(list: Array) -> Array[Vector2i]:
	return (list[0] as Building).tiles() if not list.is_empty() else [] as Array[Vector2i]


## Placing a `kind`: its Build entry (until placing), and the marked tiles.
func place_point(kind: String, tiles: Array) -> Dictionary:
	var placing := game.mode == Game.Mode.BUILD and game.build_kind == kind
	return {"hud": [] if placing else ["build:" + kind, "tab:build", "dock"], "tab": "build", "tiles": tiles}


## Manning `posts`: the recruit entry for `kind`, the reserve while a unit
## waits there, nothing in the dock while one walks to its post.
func unit_point(kind: String, posts: Array) -> Dictionary:
	var tiles := first_tiles(posts)
	if not game.army.reserve().is_empty():
		return {"hud": ["reserve", "tab:army", "dock"], "tab": "army", "tiles": tiles}
	if not game.army.walking().is_empty():
		return {"tiles": tiles}
	return {"hud": ["army:" + kind, "tab:army", "dock"], "tab": "army", "tiles": tiles}


## Every unit's kind and level now, in mark["units"] (a card that waits for a promotion).
func mark_units() -> void:
	var units := {}
	for u in game.army.units:
		units[u] = [u.kind, u.level]
	mark["units"] = units


## A unit has gone up a level (or specialised) since mark_units.
func unit_promoted() -> bool:
	var units: Dictionary = mark.get("units", {})
	for u in game.army.units:
		if units.has(u) and (u.kind != units[u][0] or u.level > int(units[u][1])):
			return true
	return false
