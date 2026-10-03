class_name Tutorial
extends Node
## The guided tutorial (docs/tutorial-design.md, part A): a first game on a
## fixed map, one instruction at a time. A card (top left) says what to do, a
## highlight points at it, and a step ends when the player has done it (checked
## every 0.25 s; nothing is blocked meanwhile). Afterwards the same map goes
## on as a normal endless game.
##
## While it runs: waves wait to be called (wave 1 by the player in step 6,
## wave 2 by the tutorial after step 10, both from Config.TUTORIAL), corpses
## don't rot, and the village starts small (Config.TUTORIAL).

signal step_started(index: int)
## The tutorial is over: `played_on` (a normal game goes on) or back to the title.
signal finished(played_on: bool)

const POLL := 0.25

var game: Game
## Running: steps are shown and checked (false once finished or skipped).
var active := false
## Index into `steps` (0-based; the card says "Step index + 1 of N").
var step := -1
var steps: Array[Dictionary] = []
## How far (tiles) a taken spot looks for a free one.
const SPOT_SEARCH := 6
## The spots the steps point at (picked by the road the waves take).
var tower_tile := Vector2i(-1, -1)
var farm_tile := Vector2i(-1, -1)
var barracks_tile := Vector2i(-1, -1)
## Where the tutorial waves appear (a road tile), and their road to the gate.
var spawn_tile := Vector2i(-1, -1)
## kind + picked spot -> the spot shown now, when the picked one got taken (see _spot).
var _moved := {}
var route: Array[Vector2i] = []

var _poll := 0.0
## Counting down to the next card after a step is done (< 0: not done yet).
var _next_in := -1.0
## What a step noted when it began (XP, unit levels, ...).
var _mark := {}
var _tab := ""
var _corpses_placed := false
var _old_difficulty = null  # (Settings.Difficulty)

var highlight: TutorialHighlight
var card: PanelContainer
var _title: Label
var _tick: TextureRect
var _text: Label
var _progress: Label
var _skip: Button
var _end_row: HBoxContainer
var _go: Button
var skip_dialog: Control


## Before the world is made: the map, the difficulty, the small village.
func prepare(p_game: Game) -> void:
	game = p_game
	var td: Dictionary = Config.TUTORIAL
	game.map_seed = int(td["seed"])
	game.map_type = str(td["map_type"])
	game.reveal_map = false
	game.disable_fog = false
	game.start_resources = (td["resources"] as Dictionary).duplicate()
	game.start_civilians.assign(td["civilians"])
	game.start_buildings.assign(td["buildings"])
	_old_difficulty = Settings.difficulty
	Settings.difficulty = Settings.difficulty_of(str(td["difficulty"]))


func _exit_tree() -> void:
	if _old_difficulty != null:
		Settings.difficulty = _old_difficulty


## Once the game is set up (villages, HUD): waves wait, the hero rests, the card shows.
func start() -> void:
	active = true
	game.waves.hold = true
	game.corpses.rot = false
	game.hero.set_mode(Hero.Mode.REST)
	_pick_spots()
	for w in Config.TUTORIAL["waves"]:
		game.waves.scripted.append({"kinds": w, "spawn": spawn_tile})
	for t in [tower_tile, farm_tile, barracks_tile]:
		if t != Vector2i(-1, -1):
			game.fog.reveal(Vector2(t), 2.5, game.player_village.id)
	_build_steps()
	highlight = TutorialHighlight.new(game)
	highlight.name = "TutorialHighlight"
	game.hud.add_layer(highlight, true)  # (before the card: the skip dialog goes over it)
	_build_card()
	game.hud.set_dock_open(false)  # (the first thing to tap: open it)
	game.events.debug("tutorial: tower %s, farm %s, barracks %s, waves from %s" % [tower_tile, farm_tile, barracks_tile, spawn_tile])
	_begin(0)


# --- the spots ----------------------------------------------------------------------

## The waves' road: from the edge spawn nearest to the village (by road), the
## last `spawn_distance` tiles before the gate. The watchtower goes by the
## road 3 to 7 tiles before the gate, the barracks 8 to 13; the farm on the
## map's guaranteed farm plot.
func _pick_spots() -> void:
	var td: Dictionary = Config.TUTORIAL
	var pathing := game.world.pathing
	var best := Vector2i(-1, -1)
	var best_d := Pathing.UNREACHABLE
	for sp in game.map.edge_spawns:
		var d := pathing.enemy_distance(sp)
		if d < best_d:
			best_d = d
			best = sp
	if best == Vector2i(-1, -1):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(td["seed"])
	var full := pathing.enemy_route(best, rng)
	var keep := mini(full.size(), int(td["spawn_distance"]) + 1)
	route = full.slice(full.size() - keep)
	spawn_tile = route[0]
	tower_tile = td["tower_tile"] if td["tower_tile"] != Vector2i(-1, -1) else _by_road("tower", 3, 7, [])
	var taken: Array[Vector2i] = [tower_tile]
	farm_tile = td["farm_tile"]
	if farm_tile == Vector2i(-1, -1):
		var plot := game.player_village.farm_plot
		farm_tile = plot if plot != Vector2i(-1, -1) and _fits("farm", plot, taken) else _near_village("farm", taken)
	taken.append_array(Building.footprint(farm_tile, 3))
	barracks_tile = td["barracks_tile"] if td["barracks_tile"] != Vector2i(-1, -1) else _by_road("barracks", 8, 13, taken)


## A free spot for `kind` right next to the route, `lo` to `hi` road tiles
## before the gate (nearest to the middle of that stretch), clear of `taken`.
func _by_road(kind: String, lo: int, hi: int, taken: Array[Vector2i]) -> Vector2i:
	var size: int = Config.BUILDINGS[kind]["size"]
	var best := Vector2i(-1, -1)
	var best_score := INF
	var n := route.size()
	for i in n:
		var before_gate := n - 1 - i
		if before_gate < lo or before_gate > hi:
			continue
		var r := route[i]
		for dy in range(-size, size + 1):
			for dx in range(-size, size + 1):
				var t := r + Vector2i(dx, dy)
				if not _fits(kind, t, taken) or not _touches_road(t, size):
					continue
				var score := absf(before_gate - (lo + hi) / 2.0) + 0.1 * Vector2(t).distance_to(Vector2(game.player_village.center))
				if score < best_score:
					best_score = score
					best = t
	return best if best != Vector2i(-1, -1) else _near_village(kind, taken)


## The spot to mark for `kind`: `picked` while it's still free, else the
## nearest free spot to it (kept while it stays free, so the mark doesn't
## wander), else `picked` all the same.
func _spot(kind: String, picked: Vector2i) -> Vector2i:
	var key := "%s %s" % [kind, picked]
	if picked == Vector2i(-1, -1) or game.construction.placement_error(kind, picked, true) == "":
		_moved.erase(key)
		return picked
	var last: Vector2i = _moved.get(key, Vector2i(-1, -1))
	if last != Vector2i(-1, -1) and game.construction.placement_error(kind, last, true) == "":
		return last
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-SPOT_SEARCH, SPOT_SEARCH + 1):
		for dx in range(-SPOT_SEARCH, SPOT_SEARCH + 1):
			var t := picked + Vector2i(dx, dy)
			var d := Vector2(dx, dy).length()
			if d < best_d and game.map.in_bounds(t) and game.construction.placement_error(kind, t, true) == "":
				best_d = d
				best = t
	if best == Vector2i(-1, -1):
		_moved.erase(key)
		return picked
	_moved[key] = best
	game.events.debug("tutorial: %s spot %s is taken, marking %s" % [kind, picked, best])
	return best


func _touches_road(t: Vector2i, size: int) -> bool:
	for f in Building.footprint(t, size):
		for n in MapData.neighbors4(f):
			if route.has(n):
				return true
	return false


## Free for `kind` (ignoring fog and cost), not on or right next to `taken`.
func _fits(kind: String, t: Vector2i, taken: Array[Vector2i]) -> bool:
	if game.construction.placement_error(kind, t, true) != "":
		return false
	for f in Building.footprint(t, Config.BUILDINGS[kind]["size"]):
		for k in taken:
			if maxi(absi(f.x - k.x), absi(f.y - k.y)) <= 1:
				return false
	return true


func _near_village(kind: String, taken: Array[Vector2i]) -> Vector2i:
	var c := game.player_village.center
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var t := c + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(c))
			if d < best_d and _fits(kind, t, taken):
				best_d = d
				best = t
	return best


# --- the steps ----------------------------------------------------------------------

## Each step: "title", "text", "start" (optional), "ready" (optional: the
## card waits for it, showing "wait_text"), "done" -> bool and "point"
## -> {"hud": [control names, the first visible one is outlined], "tab": dock
## tab to open, "tiles": map tiles to mark}. See docs/tutorial-design.md §3.3.
func _build_steps() -> void:
	steps = [
		{"title": "Welcome!",
			"text": "This is your village. Enemies come in waves: keep them out. A few short steps show you how.",
			"button": "Let's go",
			"done": func() -> bool: return false,  # (the button goes on)
			"point": func() -> Dictionary: return {}},
		{"title": "Build a watchtower",
			"text": "Enemies come along the roads. Build a watchtower on the marked spot by the road: open the menu, Build tab, Watchtower, then tap the spot.",
			"done": func() -> bool: return not _towers().is_empty(),
			"point": func() -> Dictionary: return _place_point("tower", [_spot("tower", tower_tile)])},
		{"title": "Your builder at work",
			"text": "Your builder walks there and builds it. Villagers do their work on their own.",
			"done": func() -> bool: return _towers().any(func(t: Tower) -> bool: return t.complete),
			"point": func() -> Dictionary: return {"tiles": _first_tiles(_towers())}},
		{"title": "Man the tower",
			"text": "Recruit an archer (Army tab) and drag it onto the tower.",
			"done": func() -> bool: return _towers(true).any(func(t: Tower) -> bool: return t.garrison != null and t.garrison.state == MilitaryUnit.State.STATIONED),
			"point": func() -> Dictionary: return _unit_point("archer", _towers())},
		{"title": "Food",
			"text": "Villagers need to eat. Place a farm on the marked field, then recruit a farmer to work it. The top bar shows your food and how it changes per minute.",
			"done": func() -> bool: return _farms().any(func(f: Farm) -> bool: return f.complete and f.farmer != null),
			"point": _farm_point},
		{"title": "The first wave",
			"text": "Ready? Start the first wave now with Call now: calling early pays bonus gold.",
			"done": func() -> bool: return game.waves.wave >= 1,
			"point": func() -> Dictionary: return {"hud": ["call"]}},
		{"title": "Gatherers", "id": "gatherers",
			"ready": func() -> bool: return game.corpses.count() > 0 or game.player_village.corpses_delivered > 0,
			"wait_text": "Here they come! Watch your archer on the tower.",
			"text": "Enemies leave corpses. A gatherer brings them home for gold and food. Recruit one in the Village tab.",
			"done": func() -> bool: return game.population.count("gatherer") > 0 and game.player_village.corpses_delivered > 0,
			"point": func() -> Dictionary: return {} if game.population.count("gatherer") > 0 else {"hud": ["village:gatherer", "tab:village", "dock"], "tab": "village"}},
		{"title": "Your hero",
			"text": "This is your hero. Tap him in the top bar and send him exploring: he uncovers the fog and earns XP.",
			"start": func() -> void: _mark = {"xp": game.hero.xp, "level": game.hero.level},
			"done": func() -> bool: return game.hero.mode == Hero.Mode.EXPLORE and (game.hero.xp > int(_mark["xp"]) or game.hero.level > int(_mark["level"])),
			"point": func() -> Dictionary: return {} if game.hero.mode == Hero.Mode.EXPLORE else {"hud": ["hero_mode:%d" % Hero.Mode.EXPLORE, "hero"]}},
		{"title": "Hero levels",
			"text": "He has enough XP for a level: more HP and a harder sword. Level him up.",
			"start": _top_up_xp,
			"done": func() -> bool: return game.hero.level >= 1,
			"point": _level_point},
		{"title": "Barracks", "id": "barracks",
			"text": "Barracks send their units out to fight what comes near. Build one by the road and station a shield bearer.",
			"done": func() -> bool: return game.army.units.any(func(u: MilitaryUnit) -> bool: return u.post is Barracks and u.state == MilitaryUnit.State.STATIONED),
			"point": _barracks_point},
		{"title": "Unit levels",
			"text": "Units get better with levels. Tap one and promote it with gold. (Later, training grounds let the hero pass on his XP to a unit instead.)",
			"start": _mark_units,
			"done": _unit_promoted,
			"point": _promote_point},
		{"title": "Tower upgrades",
			"text": "Towers can be upgraded too: tap the watchtower and upgrade it. Your builder does the work.",
			"done": func() -> bool: return _towers(true).any(func(t: Tower) -> bool: return t.level >= 2),
			"point": func() -> Dictionary: return {"tiles": _first_tiles(_towers())}},
		{"title": "Well done!",
			"text": "That's all you need. Waves get bigger and new enemies show up. Survive as long as you can!",
			"done": func() -> bool: return false,
			"point": func() -> Dictionary: return {}},
	]


## Placing a `kind`: its Build entry (until placing), and the marked spot.
func _place_point(kind: String, tiles: Array) -> Dictionary:
	var placing := game.mode == Game.Mode.BUILD and game.build_kind == kind
	return {"hud": [] if placing else ["build:" + kind, "tab:build", "dock"], "tab": "build", "tiles": tiles}


## Manning `posts`: the recruit entry for `kind`, the reserve while a unit
## waits there, nothing in the dock while one walks to its post.
func _unit_point(kind: String, posts: Array) -> Dictionary:
	var tiles := _first_tiles(posts)
	if not game.army.reserve().is_empty():
		return {"hud": ["reserve", "tab:army", "dock"], "tab": "army", "tiles": tiles}
	if not game.army.walking().is_empty():
		return {"tiles": tiles}
	return {"hud": ["army:" + kind, "tab:army", "dock"], "tab": "army", "tiles": tiles}


func _farm_point() -> Dictionary:
	var farms := _farms()
	if farms.is_empty():
		return _place_point("farm", Building.footprint(_spot("farm", farm_tile), 3))
	if game.population.count("farmer") == 0:
		return {"hud": ["village:farmer", "tab:village", "dock"], "tab": "village", "tiles": _first_tiles(farms)}
	return {"tiles": _first_tiles(farms)}


func _level_point() -> Dictionary:
	_top_up_xp()
	return {"hud": ["hero_level", "hero"]}


func _barracks_point() -> Dictionary:
	var bs := _barracks()
	if bs.is_empty():
		return _place_point("barracks", Building.footprint(_spot("barracks", barracks_tile), 2))
	return _unit_point("shield_bearer", bs)


## Step 11: every unit stationed on a post (its figure, not the post); with
## none, the reserve while a unit waits there; with no unit at all, the Army tab.
func _promote_point() -> Dictionary:
	var on_posts := game.army.stationed().filter(func(u: MilitaryUnit) -> bool:
		return is_instance_valid(u.post) and u.post.unit_rect(u).has_area())
	if not on_posts.is_empty():
		return {"units": on_posts}
	if not game.army.reserve().is_empty():
		return {"hud": ["reserve", "tab:army", "dock"], "tab": "army"}
	return {"hud": ["tab:army", "dock"]}


## Step 11: every unit's kind and level now; done when one has gone up.
func _mark_units() -> void:
	_mark = {}
	for u in game.army.units:
		_mark[u] = [u.kind, u.level]


func _unit_promoted() -> bool:
	for u in game.army.units:
		if _mark.has(u) and (u.kind != _mark[u][0] or u.level > int(_mark[u][1])):
			return true
	return false


## The player's watchtowers; `walls`: the wall towers too (they can be
## manned and upgraded the same way).
func _towers(walls := false) -> Array:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b is Tower and (walls or b.kind == "tower"))


func _farms() -> Array:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b is Farm)


func _barracks() -> Array:
	return game.player_village.buildings().filter(func(b: Building) -> bool: return b is Barracks)


func _first_tiles(list: Array) -> Array[Vector2i]:
	return (list[0] as Building).tiles() if not list.is_empty() else [] as Array[Vector2i]


## Step 9: the hero gets the XP his next level costs, if he has less.
func _top_up_xp() -> void:
	var h := game.hero
	if h.level == 0 and not h.dead and h.xp < h.level_up_cost():
		h.xp = h.level_up_cost()
		h.changed.emit()


func _begin(i: int) -> void:
	step = i
	_next_in = -1.0
	_tab = ""
	var s: Dictionary = steps[i]
	if s.has("start"):
		(s["start"] as Callable).call()
	_title.text = s["title"]
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_tick.visible = false
	_text.text = s["text"]
	_progress.text = "Step %d of %d" % [i + 1, steps.size()]
	var last := i == steps.size() - 1
	_end_row.visible = last
	_skip.visible = not last
	_go.visible = s.has("button")
	_go.text = str(s.get("button", ""))
	game.events.debug("tutorial step %d: %s" % [i + 1, s["title"]])
	_poll = 0.0
	_point()
	_place_card()
	step_started.emit(i)


func _process(delta: float) -> void:
	if not active:
		return
	var over := game.game_over
	card.visible = not over
	highlight.visible = not over
	if over:
		return
	_place_card()
	game.waves.call_locked = game.waves.wave >= 1  # (the tutorial starts wave 2)
	if _next_in >= 0.0:
		_next_in -= delta
		if _next_in < 0.0:
			var next: Dictionary = steps[step + 1]
			if next.has("ready") and not (next["ready"] as Callable).call():
				_next_in = 0.0  # (keeps waiting: step 7 comes with the first corpse)
				_text.text = str(next.get("wait_text", _text.text))
				if next.get("id") == "gatherers":
					_corpse_fallback()
			else:
				_begin(step + 1)
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	if steps[step].get("id") == "gatherers":
		_corpse_fallback()
	if (steps[step]["done"] as Callable).call():
		_step_done()
	else:
		_point()


func _step_done() -> void:
	_tick.visible = true
	_title.add_theme_color_override("font_color", UiTheme.GOOD)
	_progress.text = "Well done!"
	highlight.clear()
	Sfx.play("chime", 0.0)
	game.events.debug("tutorial step %d done" % (step + 1))
	if steps[step].get("id") == "barracks":
		game.waves.start_now()  # wave 2, for the barracks
	_next_in = float(Config.TUTORIAL["step_pause"])


## Updates the highlight; opens the dock on the step's tab when that changes
## (folded, the tab is picked and the highlight points at the dock's button).
func _point() -> void:
	var p: Dictionary = (steps[step]["point"] as Callable).call()
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
		game.hud.scroll_to(target)  # (once: the player may scroll away)
	var tiles: Array[Vector2i] = []
	tiles.assign(p.get("tiles", []))
	var units: Array[MilitaryUnit] = []
	units.assign(p.get("units", []))
	highlight.point_at(target, game.hud.dock_clip(target), tiles, units)


## The gatherers' step needs corpses: if wave 1 is over and left none (the goblins got
## through), two goblin corpses lie by the tower.
func _corpse_fallback() -> void:
	var w := game.waves
	if _corpses_placed or w.in_progress() or w.wave < 1 or game.corpses.count() > 0 or game.player_village.corpses_delivered > 0:
		return
	_corpses_placed = true
	var at := Vector2(tower_tile if not route.is_empty() else game.player_village.center)
	if not route.is_empty():
		at = Vector2(route[maxi(0, route.size() - 6)])
	for k in 2:
		game.corpses.spawn("goblin", w.wave, at + Vector2(0.3 * k, -0.2 * k))


# --- the card -----------------------------------------------------------------------

func _build_card() -> void:
	var hud := game.hud
	card = PanelContainer.new()
	card.name = "TutorialCard"
	card.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14ee"), UiTheme.GOLD, 3, 12, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	_tick = hud._icon(Art.tex("icon_check"), 28)
	_tick.visible = false
	head.add_child(_tick)
	_title = hud._label("", 22, UiTheme.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	_text = hud._label("", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	_go = hud._button("", Vector2(0, 50))
	UiTheme.style_good(_go)
	_go.pressed.connect(_on_go)
	v.add_child(_go)
	_end_row = HBoxContainer.new()
	_end_row.add_theme_constant_override("separation", 8)
	v.add_child(_end_row)
	var on := hud._button("Play on", Vector2(0, 50))
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_good(on)
	on.pressed.connect(finish.bind(true))
	_end_row.add_child(on)
	var title := hud._button("Back to title", Vector2(0, 50))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.pressed.connect(finish.bind(false))
	_end_row.add_child(title)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	_progress = hud._label("", 14, UiTheme.MUTED)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_progress)
	_skip = hud._button("Skip tutorial", Vector2(0, 36))
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 15)
	_skip.add_theme_color_override("font_color", UiTheme.MUTED)
	_skip.pressed.connect(open_skip_dialog)
	foot.add_child(_skip)
	hud.add_layer(card, false)
	_build_skip_dialog()


## Top left under the top bar; beside the hero panel, villager list or
## material dialog while one is open (portrait: under it), and under the
## placing hint in portrait.
func _place_card() -> void:
	var hud := game.hud
	var vp := card.get_viewport_rect().size
	var portrait := hud.is_portrait()
	var w := minf(vp.x - 20.0, 520.0) if portrait else 360.0
	var pos := Vector2(10.0, hud.top_height() + 6.0)
	var corner := hud.corner_panel_rect()
	if corner.has_area():
		if portrait:
			pos.y = corner.end.y + 6.0
		else:
			pos.x = corner.end.x + 10.0
	if portrait and hud._mode_panel.visible:
		pos.y = maxf(pos.y, hud._mode_panel.get_global_rect().end.y + 6.0)
	card.custom_minimum_size.x = w
	card.size = Vector2(w, 0.0)
	card.position = pos


func _build_skip_dialog() -> void:
	var hud := game.hud
	skip_dialog = CenterContainer.new()
	skip_dialog.name = "TutorialSkip"
	skip_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14"), UiTheme.GOLD, 4, 14, 22))
	skip_dialog.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(minf(400.0, game.get_viewport().get_visible_rect().size.x - 64.0), 0)
	panel.add_child(v)
	v.add_child(hud._label("Skip the tutorial?", 26, UiTheme.GOLD))
	var t := hud._label("You can play on in this village.", 17)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var on := hud._button("Play on", Vector2(0, 54))
	UiTheme.style_good(on)
	on.pressed.connect(finish.bind(true))
	v.add_child(on)
	var title := hud._button("Back to title", Vector2(0, 50))
	UiTheme.style_danger(title)
	title.pressed.connect(finish.bind(false))
	v.add_child(title)
	var back := hud._button("Back to the tutorial", Vector2(0, 46))
	back.pressed.connect(func() -> void: skip_dialog.visible = false)
	v.add_child(back)
	skip_dialog.visible = false
	hud.add_layer(skip_dialog, true)


## A step's button (the welcome's "Let's go"): straight on to the next step.
func _on_go() -> void:
	if active and step + 1 < steps.size() and steps[step].has("button"):
		_begin(step + 1)


func open_skip_dialog() -> void:
	skip_dialog.visible = true


# --- the end --------------------------------------------------------------------------

## Over, finished or skipped: a normal game goes on from the next wave
## (`play_on`), or back to the title.
func finish(play_on: bool) -> void:
	if not active:
		return
	active = false
	game.tutorial_mode = false
	game.waves.hold = false
	game.waves.call_locked = false
	game.waves.scripted.clear()
	game.corpses.rot = true
	for c in [card, highlight, skip_dialog]:
		if is_instance_valid(c):
			c.queue_free()
	game.events.debug("tutorial over (%s)" % ("play on" if play_on else "back to title"))
	finished.emit(play_on)
	if not play_on:
		game.go_to_title()
