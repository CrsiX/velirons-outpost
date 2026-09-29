extends Node
## Headless end-to-end test of every core mechanic. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/sim_bot.tscn
## Exits 0 when every check passes. Drives real input events where the
## interaction matters (drag & drop, taps), and the public APIs elsewhere.

const SEED := 20260926

var game: Game
var failures: Array[String] = []
## Every game event logged during the run: [level, text].
var history: Array = []
## Every command submitted during the run: [type, args, ok].
var cmd_log: Array = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


## Title screen: menu, difficulty toggle and its effect on enemy stats.
func _test_title() -> void:
	var title: TitleScreen = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await frames(3)
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title.tscn", "the game starts on the title screen")
	check(title.singleplayer_button.is_visible_in_tree() and title.exit_button.is_visible_in_tree() and not title.play_button.is_visible_in_tree(), "the title menu offers Singleplayer and Exit")
	await tap(center(title.singleplayer_button))
	check(title.play_button.is_visible_in_tree() and title.difficulty_button.is_visible_in_tree() and title.levels_button.is_visible_in_tree() and title.back_button.is_visible_in_tree() and not title.singleplayer_button.is_visible_in_tree(), "Singleplayer opens a sub-menu with Play, Difficulty, Levels and Back")
	await tap(center(title.back_button))
	check(title.singleplayer_button.is_visible_in_tree() and not title.play_button.is_visible_in_tree(), "Back returns to the main menu")
	check(title.multiplayer_button.is_visible_in_tree(), "the main menu also offers Multiplayer")
	await tap(center(title.multiplayer_button))
	var mp := title.mp_menu
	check(mp.is_visible_in_tree() and mp.name_edit.is_visible_in_tree() and mp.swatches.size() == Config.VILLAGE_COLORS.size() and mp.host_button.is_visible_in_tree() and mp.address_edit.is_visible_in_tree() and mp.back_button.is_visible_in_tree(), "Multiplayer: village name, colours, Host game, games found, join by address, Back")
	check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(mp.get_global_rect()), "the multiplayer page fits the screen")
	await tap(center(mp.swatches[3]))
	check(Settings.player_color == 3, "picking a colour")
	await tap(center(mp.back_button))
	check(title.singleplayer_button.is_visible_in_tree() and not mp.is_visible_in_tree() and not Net.is_online(), "Back returns to the main menu")
	await tap(center(title.singleplayer_button))
	var seen: Array[String] = [title.difficulty_button.text]
	var mults: Array[float] = [Config.enemy_stat("goblin", "hp") / Config.ENEMIES["goblin"]["hp"]]
	for i in 3:
		await tap(center(title.difficulty_button))
		seen.append(title.difficulty_button.text)
		mults.append(Config.enemy_stat("goblin", "hp") / Config.ENEMIES["goblin"]["hp"])
	check(seen == ["Difficulty: Normal", "Difficulty: Hard", "Difficulty: Easy", "Difficulty: Normal"], "difficulty toggles normal > hard > easy > normal")
	check(is_equal_approx(mults[1], 1.5) and is_equal_approx(mults[2], 0.67) and is_equal_approx(mults[3], 1.0), "enemy values scale x1.5 on hard, x0.67 on easy")
	Settings.difficulty = Settings.Difficulty.HARD
	check(is_equal_approx(Config.enemy_stat("goblin", "speed"), Config.ENEMIES["goblin"]["speed"] * 1.5) and Config.enemy_stat_int("goblin", "gold_on_kill") == roundi(Config.ENEMIES["goblin"]["gold_on_kill"] * 1.5), "difficulty scales speed and loot too")
	Settings.difficulty = Settings.Difficulty.NORMAL
	await tap(center(title.levels_button))
	check(title.levels_panel.visible, "Levels button opens the level list")
	var tv := get_viewport().get_visible_rect()
	check(tv.encloses(title.levels_panel.get_global_rect()), "the level list fits the screen")
	title.levels_panel.visible = false
	var land := get_window().size
	get_window().size = Vector2i(1080, 2400)
	await frames(4)
	var pv := get_viewport().get_visible_rect()
	var menu_ok := true
	for b in [title.play_button, title.difficulty_button, title.levels_button]:
		menu_ok = menu_ok and pv.encloses(b.get_global_rect()) and b.get_global_rect().position.y > title._title.get_global_rect().end.y
	check(Layout.portrait and menu_ok and pv.encloses(title._title.get_global_rect()), "portrait title screen: title and menu fit, menu below the title")
	get_window().size = land
	await frames(4)
	title.queue_free()
	await frames(2)


func check(cond: bool, msg: String) -> void:
	checks += 1
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures.append(msg)


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout:
			return false
	return true


func wait(seconds: float) -> void:
	await wait_until(func() -> bool: return false, seconds)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- input helpers -----------------------------------------------------------------

func mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func motion(pos: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func tap(pos: Vector2) -> void:
	mouse(pos, true)
	await frames(1)
	mouse(pos, false)
	await frames(2)


func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func screen(world_pos: Vector2) -> Vector2:
	return game.camera.world_to_screen(world_pos)


# --- helpers ----------------------------------------------------------------------

var _guard_touched := false


func check_silent_guard(g: Gatherer, guarded: Corpse) -> void:
	if is_instance_valid(guarded) and g.target == guarded:
		_guard_touched = true


## The buildable tile nearest to `near` that a builder can walk to.
func find_spot(kind: String, near: Vector2i) -> Vector2i:
	var cands: Array = []
	for y in game.map.size:
		for x in game.map.size:
			var t := Vector2i(x, y)
			if game.construction.placement_error(kind, t) == "":
				cands.append([Vector2(t).distance_to(Vector2(near)), t])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in cands:
		var t: Vector2i = c[1]
		for nb in [t, t + Vector2i(1, 0), t + Vector2i(-1, 0), t + Vector2i(0, 1), t + Vector2i(0, -1)]:
			if game.world.pathing.is_walkable(nb) and not game.world.pathing.find_path(game.player_village.center, nb).is_empty():
				return t
	return Vector2i(-1, -1)


## Every villager lives in exactly one intact hut, and each hut holds at most one.
func residency_ok() -> bool:
	var seen := {}
	for c in game.population.civilians:
		if not is_instance_valid(c.hut) or c.hut.resident != c or not c.hut.is_intact() or seen.has(c.hut):
			return false
		seen[c.hut] = true
	for h in game.world.huts():
		if h.resident != null and not game.population.civilians.has(h.resident):
			return false
	return true


## Takes the hero out of play (or back in) so the older, deterministic checks
## aren't disturbed by him fighting or taking jobs; his own section tests him.
func bench_hero(benched: bool) -> void:
	var h := game.hero
	h.process_mode = Node.PROCESS_MODE_DISABLED if benched else Node.PROCESS_MODE_INHERIT
	if benched:
		h.remove_from_group("melee_defenders")
	elif not h.dead:
		h.add_to_group("melee_defenders")


## A tile on the road just outside a gate, `dist` tiles out.
func outside_gate(gate: Vector2i, dist: int) -> Vector2i:
	return game.world.pathing.nearest_road(gate + (gate - game.player_village.center).sign() * dist)


## A gate with a road leading away from it (not every gate has one).
func open_gate() -> Vector2i:
	for g in game.player_village.gates:
		if game.map.is_road(g + (g - game.player_village.center).sign() * 2):
			return g
	return game.player_village.gates[0]


func spawn_dummy(kind: String, at: Vector2, hp_scale: float, far: Vector2i) -> Enemy:
	game.waves._spawn({"kind": kind, "spawn": far, "hp_scale": hp_scale})
	var e: Enemy = get_tree().get_nodes_in_group("enemies").back()
	e.speed = 0.0
	e.set_grid_pos(at)
	return e


## Visible buttons under `n`.
func buttons_in(n: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree():
			out.append(c)
	return out


## Every visible HUD button outside the dock's scroll area lies fully on screen.
func hud_buttons_on_screen(hud: Hud) -> String:
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(0.5)
	for b in buttons_in(hud._root):
		if hud._sheet_scroll.is_ancestor_of(b):
			continue
		if not vp.encloses(b.get_global_rect()):
			return "%s '%s' at %s" % [b.get_path(), b.text, b.get_global_rect()]
	return ""


## Was something logged at `level` containing `part` (since the run began)?
func logged(part: String, level: int = -1) -> bool:
	for e in history:
		if part in e[1] and (level == -1 or e[0] == level):
			return true
	return false


## Screen position of the unit figure standing on `p`.
func unit_on(p: MilitaryPost) -> Vector2:
	return screen(p.to_global(p.unit_pick_rect().get_center()))


## Press at `from`, move in steps to `to` and release there.
func drag(from: Vector2, to: Vector2, release: bool = true) -> void:
	mouse(from, true)
	await frames(1)
	for i in range(1, 9):
		motion(from.lerp(to, i / 8.0), (to - from) / 8.0)
		await frames(1)
	if release:
		mouse(to, false)
		await frames(2)


func civs(role: String) -> Array:
	return game.population.civilians.filter(func(c: Civilian) -> bool: return c.role == role)


# --- the test run -----------------------------------------------------------------

func _run() -> void:
	await _test_title()
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	game.map_seed = SEED
	game.reveal_map = false  # the test needs real fog, whatever config.gd says
	game.disable_fog = false
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true  # (this test predates unit unlocks: tests/world_bot.gd)
	for e in game.events.entries:  # logged while the level was set up
		history.append([e["level"], e["text"]])
	game.events.logged.connect(func(level: int, text: String) -> void: history.append([level, text]))
	game.commands.applied.connect(func(_v: Village, type: String, args: Dictionary, r: Dictionary) -> void: cmd_log.append([type, args.duplicate(true), r["ok"]]))
	await frames(3)
	var hud := game.hud
	var map := game.map
	print("viewport ", get_viewport().get_visible_rect().size)

	check(not hud._overlay.visible and not get_tree().paused, "no pop-up over the level; it starts right away")

	# --- camera, sidebar, fullscreen -----------------------------------------------
	var cam := game.camera
	var cam0 := cam.position
	var from := Vector2(400, 400)
	mouse(from, true)
	await frames(1)
	for i in range(1, 9):
		motion(from + Vector2(-20.0 * i, -10.0 * i), Vector2(-20, -10))
		await frames(1)
	mouse(from + Vector2(-160, -80), false)
	await frames(2)
	check(cam.position.distance_to(cam0) > 50.0, "dragging the map pans the camera")
	var z0 := cam.zoom.x
	for i in 3:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = Vector2(400, 400)
		get_viewport().push_input(wheel, true)
		await frames(1)
	check(cam.zoom.x > z0, "mouse wheel zooms in")
	for i in 40:
		cam.zoom_at(Vector2(400, 400), 1.3)
	check(is_equal_approx(cam.zoom.x, CameraController.MAX_ZOOM), "zoom stops at its maximum")
	cam.position = Vector2(1e6, 1e6)
	cam.focus(cam.position)
	check(cam.bounds.has_point(cam.position) or cam.position.is_equal_approx(cam.bounds.end), "the camera can't leave the map")
	cam.zoom = Vector2(0.75, 0.75)
	cam.focus(Iso.tile_to_world(game.player_village.center))
	await frames(2)
	await tap(center(hud._sidebar_toggle))
	check(not hud._sidebar.visible, "sidebar collapses")
	await tap(center(hud._sidebar_toggle))
	check(hud._sidebar.visible, "and expands again")
	check(hud._settings_button.is_visible_in_tree() and hud._settings_button.icon == Art.tex("icon_settings") and hud._settings_button.pressed.is_connected(hud.open_settings), "a settings (gear) button sits in the top bar where fullscreen was")

	# --- HUD layout & speed button ------------------------------------------------
	var vp := get_viewport().get_visible_rect().size
	await frames(2)
	check(absf(hud._sidebar.get_global_rect().end.x - vp.x) < 1.0, "sidebar is flush with the right screen edge (%.0f vs %.0f)" % [hud._sidebar.get_global_rect().end.x, vp.x])
	check(hud._topbar.get_global_rect().end.x <= vp.x + 0.5 and hud._topbar.get_combined_minimum_size().x <= 1280.0, "top bar fits a 1280px-wide screen (needs %.0f)" % hud._topbar.get_combined_minimum_size().x)
	check(hud._sidebar_toggle.get_global_rect().end.x <= hud._sidebar.get_global_rect().position.x, "sidebar toggle sits left of the sidebar")
	var speeds_seen: Array[String] = []
	for i in 4:
		await tap(center(hud._speed_button))
		speeds_seen.append("paused" if get_tree().paused else "%dx" % int(Engine.time_scale))
	check(speeds_seen == ["2x", "4x", "paused", "1x"], "one speed button cycles 1x > 2x > 4x > paused > 1x (%s)" % str(speeds_seen))
	await wait(2.0)
	check(game.waves.countdown < Config.FIRST_WAVE_DELAY and game.waves.wave == 0, "first wave counts down on its own (%.1fs left)" % game.waves.countdown)
	game.waves.countdown = 99999.0  # hold the first wave while the economy is tested

	# --- portrait: the device is turned upright -----------------------------------
	var win := get_window()
	var land_size := win.size
	check(not Layout.portrait and not hud._sheet_handle.visible, "landscape to begin with (window %s)" % land_size)
	win.size = Vector2i(1080, 2400)
	await frames(4)
	var pv := get_viewport().get_visible_rect().size
	check(Layout.portrait and is_equal_approx(pv.x, 720.0), "turning the screen upright switches to portrait, 720 wide like landscape is 720 high (%s)" % pv)
	check(hud._topbar_box.vertical and hud._topbar.get_global_rect().end.x <= pv.x + 0.5 and hud._topbar.get_combined_minimum_size().x <= pv.x, "portrait: the top bar takes two rows and fits the width")
	var sr := hud._sidebar.get_global_rect()
	check(absf(sr.end.y - pv.y) < 1.0 and absf(sr.size.x - pv.x) < 1.0 and sr.position.x < 0.5, "portrait: the sidebar is now a bar along the bottom")
	check(not hud._sheet_scroll.visible and hud._tab_buttons["build"].is_visible_in_tree() and sr.size.y < 120.0, "it starts folded: just the handle and the tabs (%.0f px)" % sr.size.y)
	var off := hud_buttons_on_screen(hud)
	check(off == "", "portrait: every button is on screen %s" % off)
	await tap(center(hud._sidebar_toggle))
	var open_r := hud._sidebar.get_global_rect()
	check(hud._sheet_scroll.visible and open_r.size.y > sr.size.y + 100.0 and absf(open_r.end.y - pv.y) < 1.0, "the chevron expands it from the bottom (%.0f px)" % open_r.size.y)
	check(open_r.position.y > hud._topbar.get_global_rect().end.y + 200.0, "the open sheet leaves the map visible above it")
	await tap(center(hud._sidebar_toggle))
	check(not hud._sheet_scroll.visible, "the chevron folds it again")
	await tap(center(hud._tab_buttons["village"]))
	check(hud._sheet_scroll.visible and hud._tab_pages["village"].visible, "tapping a tab opens the sheet on that page")
	await tap(center(hud._tab_buttons["village"]))
	check(not hud._sheet_scroll.visible, "tapping the open tab folds the sheet")
	# Swipe the handle up to open, down to close.
	var hc := center(hud._sheet_handle)
	mouse(hc, true)
	await frames(1)
	motion(hc + Vector2(0, -60), Vector2(0, -60))
	mouse(hc + Vector2(0, -80), false)
	await frames(3)
	check(hud._sheet_scroll.visible, "swiping the handle up opens the sheet")
	hc = center(hud._sheet_handle)
	mouse(hc, true)
	await frames(1)
	motion(hc + Vector2(0, 60), Vector2(0, 60))
	mouse(hc + Vector2(0, 80), false)
	await frames(3)
	check(not hud._sheet_scroll.visible, "swiping it down folds the sheet")
	# Every button of every page can be scrolled into view inside the open sheet.
	hud.set_sheet_open(true)
	var unreachable: Array[String] = []
	for tab in ["build", "village", "army"]:
		if hud._current_tab != tab:
			hud._on_tab_pressed(tab)
		await frames(3)
		for b in buttons_in(hud._tab_pages[tab]):
			hud._sheet_scroll.ensure_control_visible(b)
			await frames(2)
			var clip := hud._sheet_scroll.get_global_rect().grow(0.5)
			if not clip.encloses(b.get_global_rect()) or not Rect2(Vector2.ZERO, pv).encloses(b.get_global_rect()):
				unreachable.append("%s:%s" % [tab, b.text])
	check(unreachable.is_empty() and hud._entry_grids[0].columns == 2, "portrait: all dock buttons are reachable (two columns of entries) %s" % str(unreachable))
	# Placing a building folds the sheet out of the way; Done brings it back.
	hud._on_tab_pressed("build")
	await frames(3)
	check(hud._sheet_scroll.visible, "back on the Build page")
	await tap(center(hud._build_buttons["tower"]))
	check(game.mode == Game.Mode.BUILD and not hud._sheet_scroll.visible and hud._mode_panel.visible, "portrait: placing a building folds the sheet")
	var mp := hud._mode_panel.get_global_rect()
	check(Rect2(Vector2.ZERO, pv).encloses(mp) and mp.position.y >= hud._topbar.get_global_rect().end.y, "the placement hint fits under the top bar")
	await tap(center(buttons_in(hud._mode_panel)[0]))
	check(game.mode == Game.Mode.NONE and hud._sheet_scroll.visible, "Done brings the sheet back")
	# Selecting something folds the sheet; the info panel sits just above it.
	game.select(game.world.towers()[0])
	await frames(3)
	var ip := hud._info_panel.get_global_rect()
	check(not hud._sheet_scroll.visible and ip.end.y <= hud._sidebar.get_global_rect().position.y + 0.5 and ip.position.y > 0.0 and ip.end.x <= pv.x + 0.5, "portrait: a selection folds the sheet, its panel sits above it")
	await tap(center(hud._sidebar_toggle))
	check(hud._sheet_scroll.visible and not hud._info_panel.visible, "opening the sheet closes the info panel")
	hud.set_sheet_open(false)
	# Hero and trade panels fit, and only one of them is open at a time.
	await tap(center(hud._hero_button))
	check(hud._hero_panel.visible and Rect2(Vector2.ZERO, pv).encloses(hud._hero_panel.get_global_rect()), "portrait: the hero panel fits the screen")
	await tap(center(hud._materials_button))
	check(hud._trade_panel.visible and not hud._hero_panel.visible and Rect2(Vector2.ZERO, pv).encloses(hud._trade_panel.get_global_rect()), "portrait: the trade dialog fits and replaces the hero panel")
	hud._trade_panel.visible = false
	off = hud_buttons_on_screen(hud)
	check(off == "", "portrait: still every button on screen %s" % off)
	var plog := hud._log_box.get_global_rect()
	check(absf(plog.size.x - (pv.x - 20.0)) < 1.5 and plog.end.y <= hud._sidebar.get_global_rect().position.y + 0.5, "portrait: the log runs across the screen, just above the bottom bar")
	# A tablet held upright gets a wider portrait canvas.
	win.size = Vector2i(1536, 2048)
	await frames(4)
	check(Layout.portrait and hud_buttons_on_screen(hud) == "", "portrait tablet: everything fits (%s)" % get_viewport().get_visible_rect().size)
	# And back to landscape.
	win.size = land_size
	await frames(4)
	vp = get_viewport().get_visible_rect().size
	check(not Layout.portrait and not hud._topbar_box.vertical and not hud._sheet_handle.visible, "turning back gives the landscape layout")
	check(hud._sidebar.visible and hud._sheet_scroll.visible and absf(hud._sidebar.get_global_rect().end.x - vp.x) < 1.0 and hud._sidebar_toggle.get_parent() == hud._root, "the sidebar is back on the right with its toggle")
	check(hud._sidebar_toggle.get_global_rect().end.x <= hud._sidebar.get_global_rect().position.x and hud_buttons_on_screen(hud) == "", "landscape: toggle beside the sidebar, every button on screen")
	hud._select_tab("build")
	game.waves.countdown = 99999.0

	# --- map -------------------------------------------------------------------
	var total := map.size * map.size
	var forest := map.count_terrain(MapData.Terrain.FOREST)
	var desert := map.count_terrain(MapData.Terrain.DESERT)
	var mountain := map.count_terrain(MapData.Terrain.MOUNTAIN)
	print("map %dx%d: %d spawns, forest %d%%, desert %d%%, mountain %d%%, road %d tiles" % [map.size, map.size, map.edge_spawns.size(),
		100 * forest / total, 100 * desert / total, 100 * mountain / total, map.count_terrain(MapData.Terrain.ROAD)])
	check(map.size == 75, "map is 75x75")
	# Enemy config is complete and readable.
	var required := ["name", "art", "behavior", "hp", "speed", "damage", "attack_cooldown", "gold_on_kill", "gold_on_collect", "food_on_collect"]
	var cfg_ok := true
	for kind in Config.ENEMIES:
		var e: Dictionary = Config.ENEMIES[kind]
		cfg_ok = cfg_ok and required.all(func(k: String) -> bool: return e.has(k)) and Enemy.BEHAVIORS.has(e["behavior"])
		cfg_ok = cfg_ok and ResourceLoader.exists("res://art/unit_%s.svg" % e["art"]) and ResourceLoader.exists("res://art/corpse_%s.svg" % e["art"])
	check(cfg_ok, "every enemy has all config keys, a known behavior and its art")
	var mix_ok := true
	for n in range(1, 16):
		var comp := Config.wave_composition(n)
		var in_wave := 0
		for k in comp:
			in_wave += comp[k]
		mix_ok = mix_ok and in_wave == Config.wave_size(n)
		for kind in Config.WAVE_MIX:
			if n < Config.WAVE_MIX[kind]["from_wave"] and comp.has(kind):
				mix_ok = false
	check(mix_ok, "wave mix adds up and nobody shows up before their first wave")
	check(not Config.wave_composition(4).has("witch") and Config.wave_composition(5).has("witch"), "witches first appear in wave %d" % Config.WAVE_MIX["witch"]["from_wave"])
	check(not Config.wave_composition(2).has("ork") and Config.wave_composition(3).has("ork"), "orks first appear in wave %d" % Config.WAVE_MIX["ork"]["from_wave"])
	var gob: Dictionary = Config.ENEMIES["goblin"]
	var orc: Dictionary = Config.ENEMIES["ork"]
	var wit: Dictionary = Config.ENEMIES["witch"]
	check(orc["speed"] < gob["speed"] and orc["hp"] > gob["hp"] and orc["damage"] > gob["damage"] * 2.0, "orks: slower, tougher, much harder hitting")
	check(orc["gold_on_kill"] > 0 and orc["gold_on_collect"] == 0 and orc["food_on_collect"] > gob["food_on_collect"], "orks: gold on kill only, more food when gathered")
	check(wit["hp"] < gob["hp"] and wit["damage"] == 0 and wit["gold_on_kill"] > gob["gold_on_kill"] and wit["gold_on_collect"] == 0 and wit["food_on_collect"] <= gob["food_on_collect"], "witches: frail, no melee, rich kill, no gold and little food as corpses")
	check(is_equal_approx(wit["spell_cooldown"], 2.0 * Config.unit_stat("archer", "cooldown", 0)), "witch spell cycle is twice an archer's shot interval")
	Settings.difficulty = Settings.Difficulty.HARD
	check(is_equal_approx(Config.enemy_stat("goblin", "attack_cooldown"), gob["attack_cooldown"]) and is_equal_approx(Config.enemy_stat("witch", "spell_cooldown"), wit["spell_cooldown"]), "difficulty never stretches cooldowns")
	Settings.difficulty = Settings.Difficulty.NORMAL
	# (the zones in detail: tests/world_bot.gd)
	check(forest > total * 0.12 and forest < total * 0.7, "a good share of forest (%d%%)" % (100 * forest / total))
	check(desert <= total * Config.DESERT_MAX_SHARE + 1, "at most 20% steppe")
	var desert_near := false
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if map.is_desert(t) and Vector2(t).distance_to(Vector2(game.player_village.center)) < Config.ZONE_FAIR_CLEAR:
				desert_near = true
	check(not desert_near, "no steppe next to the village")
	check(mountain > 20, "mountain ranges")
	check(map.gates.all(func(g: Vector2i) -> bool: return map.is_road(g)), "gate tiles are dirt road")
	var layout_ok := true
	for row in 5:
		for col in 5:
			var t := game.player_village.rect.position + Vector2i(col, row)
			var b: Building = map.building_at(t)
			var want: String = {"T": "wall_tower", "W": "wall", "G": "gate", "V": "hut"}[Config.VILLAGE_LAYOUT[row][col]]
			if b == null or b.kind != want:
				layout_ok = false
	check(layout_ok, "village matches the TWGWT layout")
	check(map.gates.size() == 4, "4 gates")
	check(map.edge_spawns.size() >= Config.SP_SPAWNS.x - 1, "edge spawns around the map (%d)" % map.edge_spawns.size())
	var all_reach := true
	for s in map.edge_spawns:
		if game.world.pathing.enemy_distance(s) >= Pathing.UNREACHABLE:
			all_reach = false
	check(all_reach, "every edge spawn reaches a gate by road")
	var road_in_village := false
	for y in range(map.village_rect.position.y + 1, map.village_rect.end.y - 1):
		for x in range(map.village_rect.position.x + 1, map.village_rect.end.x - 1):
			road_in_village = road_in_village or map.is_road(Vector2i(x, y))
	check(not road_in_village, "no road inside the village walls")
	var route := game.world.pathing.enemy_route(map.edge_spawns[0], RandomNumberGenerator.new())
	check(map.gates.has(route[-1]) and route.all(func(t: Vector2i) -> bool: return map.is_road(t) or map.gates.has(t)), "enemy route stays on roads and ends at a gate")

	# --- start state -----------------------------------------------------------
	check(game.population.count() == 4 and game.population.cap() == 9, "4 civilians, 9 huts")
	check(civs("builder").size() == 1 and civs("farmer").size() == 1 and civs("forester").size() == 1 and civs("explorer").size() == 1, "one builder, farmer, forester, explorer")
	var start_farm: Farm = map.building_at(map.farm_plot) as Farm
	var start_camps := game.world.buildings.filter(func(b: Building) -> bool: return b is WorkerCamp)
	check(start_farm != null and start_farm.complete and start_camps.size() == 1 and start_camps[0].complete, "a farm and a worker camp stand near the village from the start")
	var start_camp: WorkerCamp = start_camps[0] if not start_camps.is_empty() else null
	check(start_camp != null and Vector2(start_camp.tile).distance_to(Vector2(game.player_village.center)) < 10.0 and game.construction._trees_near(start_camp.tile, 5) >= 6, "the starting camp is close to the village, by the trees")
	check(game.economy.amount("materials") == Config.START_RESOURCES["materials"] and game.economy.amount("gold") == Config.START_RESOURCES["gold"], "the starting buildings were free")
	check(start_farm != null and start_farm.farmer == civs("farmer")[0] and start_camp != null and start_camp.forester == civs("forester")[0], "the starting farmer and forester work there")
	# Keep material income out of the exact economy checks below; the camp
	# section puts this forester back to work.
	game.population.unassign_forester(start_camp)
	check(residency_ok(), "each starting villager lives in its own hut")
	# --- the player's village ------------------------------------------------------
	var pvil := game.player_village
	check(game.villages.size() == 1 and game.villages[0] == pvil and pvil.village_name == "Veliron's Outpost" and pvil.is_local(), "single player: one village, the player's")
	check(game.economy == pvil.economy and game.population == pvil.population and game.army == pvil.army and game.construction == pvil.construction and game.hero == pvil.hero and game.events == pvil.events, "the game's economy, population, army, construction, hero and log are the village's")
	check(game.world.buildings.all(func(b: Building) -> bool: return b.village == pvil) and game.workers().all(func(c: Civilian) -> bool: return c.village == pvil), "every building, villager and the hero belong to the village")
	check(pvil.is_standing() and not pvil.fallen and pvil.intact_huts().size() == game.population.cap(), "the village is standing")
	check(civs("farmer")[0].label() == "farmer 1" and game.world.towers()[0].label() == "wall tower 1" and game.world.huts()[0].label() == "hut 1", "entities are numbered per kind for the log (farmer 1, wall tower 1, hut 1)")
	check(game.events.shown_level == EventLog.Level.INFO and hud.log_lines().all(func(t: String) -> bool: return not logged(t, EventLog.Level.DEBUG)), "the log shows Info and up at the start")
	check(logged("assign farmer 1 to farm 1 (automatic)", EventLog.Level.DEBUG) and logged("farmer 1 moves into hut", EventLog.Level.DEBUG), "debug log: villagers moving in and being assigned")
	# --- hero at the start ---------------------------------------------------------
	var hero := game.hero
	check(hero != null and hero.grid_pos.distance_to(Vector2(game.player_village.center)) < 0.1 and hero.visible, "the hero starts in the village centre")
	check(hero.mode == Hero.Mode.DEFEND and hero.xp == 0 and is_equal_approx(hero.hp, Config.HERO["hp"]), "the hero starts in Defend mode with 0 XP and full HP")
	check(not game.population.civilians.has(hero) and game.population.count() == 4, "the hero doesn't count as a villager")
	check(hud._hero_button.is_visible_in_tree() and hud._hero_button.text == "XP 0" and hud._hero_button.icon == Art.tex("icon_hero"), "top bar shows the hero button with his XP")
	await tap(center(hud._hero_button))
	check(hud._hero_panel.visible and "Defend" in hud._hero_mode_button.text, "tapping the hero button opens his panel (mode: Defend)")
	var seen_modes: Array[String] = []
	for i in Hero.MODE_NAMES.size() - 1:  # (Support is skipped in single player)
		await tap(center(hud._hero_mode_button))
		seen_modes.append(hero.mode_name())
	check(seen_modes == ["Build", "Explore", "Gather", "Train", "Rest", "Defend"], "the mode button cycles Defend > Build > Explore > Gather > Train > Rest > Defend")
	hero.set_mode(Hero.Mode.TRAIN)
	hud._refresh_hero()
	check(hud._hero_train_label.visible and "Training Grounds" in hud._hero_train_label.text and "Training Grounds" in hud._hero_mode_hint.text, "Train mode says it needs training grounds")
	hero.set_mode(Hero.Mode.DEFEND)
	game.camera.focus(game.camera.position + Vector2(900, 400))
	await tap(center(hud._hero_goto_button))
	check(game.camera.position.distance_to(hero.position) < 2.0, "'Go to hero' centres the camera on him")
	await tap(center(hud._hero_panel.get_child(0).get_child(0).get_child(2)))
	check(not hud._hero_panel.visible, "the hero panel closes")
	bench_hero(true)
	var wall_towers := game.world.towers().filter(func(t: Tower) -> bool: return t.kind == "wall_tower")
	check(wall_towers.size() == 4 and wall_towers.all(func(t: Tower) -> bool: return t.garrison == null), "4 unmanned wall towers")
	var o := game.player_village.rect.position
	check(game.world.pathing.astar.is_point_solid(o + Vector2i(0, 1)) and not game.world.pathing.astar.is_point_solid(o + Vector2i(2, 0)), "walls block, gates don't")
	var some_forest: Vector2i = map.props.keys().filter(func(t: Vector2i) -> bool: return map.is_forest(t))[0]
	var some_mountain: Vector2i = map.props.keys().filter(func(t: Vector2i) -> bool: return map.is_mountain(t))[0]
	check(game.world.pathing.astar.is_point_solid(some_forest) and game.world.pathing.astar.is_point_solid(some_mountain), "forest and mountains block villagers")
	check(map.farm_plot != Vector2i(-1, -1) and start_farm != null and start_farm.tile == map.farm_plot, "the starting farm sits on the guaranteed farm plot")
	var desert_tile: Vector2i = Vector2i(-1, -1)
	for i in total:
		var dt := Vector2i(i % map.size, i / map.size)
		var all_desert := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				all_desert = all_desert and map.is_desert(dt + Vector2i(dx, dy))
		if all_desert:
			desert_tile = dt
			break
	game.fog.reveal(Vector2(desert_tile), 2.0)
	game.economy.add("materials", 1000)
	check(game.construction.placement_error("farm", desert_tile) == "Nothing grows in the desert", "no farms in the desert")
	check(game.construction.placement_error("tower", some_mountain) != "", "nothing on mountains")
	game.economy.add("materials", -1000)
	var explored0 := game.fog.explored_count()
	check(explored0 > 50 and explored0 < 300, "fog of war around the village (%d tiles explored)" % explored0)

	Engine.time_scale = 6.0

	# --- explorer ---------------------------------------------------------------
	await wait(25.0)
	var explored1 := game.fog.explored_count()
	check(explored1 > explored0 + 15, "explorer reveals the map (%d -> %d)" % [explored0, explored1])
	# Surveillance: explored land near the (unmanned) village isn't watched;
	# land around a villager outside is.
	var ex0: Explorer = civs("explorer")[0]
	check(not game.fog.is_watched(game.player_village.center + Vector2i(0, -6)) or not ex0.at_home, "explored land without observers is only darkened")
	# Buildings watch their surroundings: huts 4 tiles, gates and others 3.
	var hut_ok := true
	var gate_ok := true
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if not map.is_explored(t):
				continue
			for h in game.world.intact_huts():
				if Vector2(t).distance_to(Vector2(h.tile)) <= Config.HUT_SIGHT and not map.is_watched(t):
					hut_ok = false
			for g in map.gates:
				if Vector2(t).distance_to(Vector2(g)) <= Config.GATE_SIGHT and not map.is_watched(t):
					gate_ok = false
	check(hut_ok, "every tile within %d of a hut is under surveillance" % int(Config.HUT_SIGHT))
	check(gate_ok, "every tile within %d of an (unmanned) gate is under surveillance" % int(Config.GATE_SIGHT))
	if not ex0.at_home:
		check(game.fog.is_watched(ex0.current_tile()), "land around a villager outside is under surveillance")

	# --- construction: watchtower ------------------------------------------------
	var mats := game.economy.amount("materials")
	var spot := find_spot("tower", game.player_village.center + Vector2i(0, -5))
	check(spot != Vector2i(-1, -1), "found a spot for a watchtower")
	check(game.construction.placement_error("tower", Vector2i(25, 25)) != "", "can't build inside the village")
	var road_tile: Vector2i = open_gate() + (open_gate() - game.player_village.center).sign()
	check(game.construction.placement_error("tower", road_tile) != "", "can't build on a road")
	# Place it through the real UI: Build tab button, then tap the tile.
	await tap(center(hud._build_buttons["tower"]))
	check(game.mode == Game.Mode.BUILD, "build button enters build mode")
	await tap(screen(Iso.tile_to_world(spot)))
	var watchtower: Tower = map.building_at(spot)
	check(watchtower != null and not watchtower.complete, "tap placed a construction site")
	check(game.economy.amount("materials") == mats - 30, "watchtower cost 30 materials")
	game.cancel_mode()
	var builder: Builder = civs("builder")[0]
	await wait_until(func() -> bool: return builder.state == Builder.State.TO_SITE or builder.state == Builder.State.BUILDING, 10.0)
	check(builder.visible and builder.site == watchtower, "builder leaves the village for the site")
	var done := await wait_until(func() -> bool: return watchtower.complete, 60.0)
	check(done, "builder completes the watchtower")
	check(game.world.pathing.astar.is_point_solid(spot), "finished tower blocks walking")
	await wait_until(func() -> bool: return builder.at_home, 30.0)
	check(builder.at_home, "builder walks back home")

	# --- trade + farm -------------------------------------------------------------
	var gold := game.economy.amount("gold")
	await tap(center(hud._materials_button))
	check(hud._trade_panel.visible, "tapping materials opens the trade dialog")
	await tap(center(hud._trade_buttons[0]))
	check(game.economy.amount("gold") == gold - 15 and game.economy.amount("materials") == mats - 30 + 10, "bought 10 materials for 15 gold")
	hud._trade_panel.visible = false
	# The starting farm took the plot next to the walls: clear the trees off the
	# nearest other 3x3 patch of grass / forest (as foresters would).
	game.fog.reveal(Vector2(game.player_village.center), 12.0)
	var patch := Vector2i(-1, -1)
	var patch_d := INF
	for y in range(-10, 11):
		for x in range(-10, 11):
			var pc := game.player_village.center + Vector2i(x, y)
			var fits := true
			for t in Building.footprint(pc, 3):
				fits = fits and map.is_explored(t) and not map.in_village(t) and map.building_at(t) == null and map.get_terrain(t) in [MapData.Terrain.GRASS, MapData.Terrain.FOREST]
			if fits and Vector2(pc - game.player_village.center).length() < patch_d:
				patch_d = Vector2(pc - game.player_village.center).length()
				patch = pc
	if patch != Vector2i(-1, -1):
		for t in Building.footprint(patch, 3):
			if game.world.is_tree(t):
				game.world.remove_tree(t)
	var farm_spot := find_spot("farm", game.player_village.center + Vector2i(5, 0))
	check(farm_spot != Vector2i(-1, -1), "found a 3x3 farm spot")
	var farm: Farm = game.construction.place("farm", farm_spot)
	check(farm != null and game.economy.amount("materials") == 0, "farm placed for 50 materials")
	check(game.construction.placement_error("tower", farm_spot + Vector2i(1, 1)) != "", "farm occupies its 3x3 footprint")
	done = await wait_until(func() -> bool: return farm.complete, 90.0)
	check(done, "builder completes the farm")
	check(farm.farmer == null and game.population.free_farmers().is_empty(), "the new farm stays empty: the only farmer works the starting farm")
	game.economy.add("food", 100)
	var farmer: Farmer = game.population.recruit("farmer")
	check(farmer != null and farm.farmer == farmer and farmer.farm == farm, "a farmer bought now goes straight to the empty farm")
	check(not game.population.assign_farmer(farm), "a farm holds only one farmer")
	var spare: Farmer = game.population.recruit("farmer")
	check(spare != null and spare.farm == null, "with every farm worked, another farmer stays idle")
	check(game.population.vacant_workplaces("builder").is_empty() and game.population.vacant_workplaces("farmer").is_empty(), "roles without a workplace get none")
	var food_before := game.economy.amount("food")
	var got_food := await wait_until(func() -> bool: return farmer.state == Farmer.State.RETURNING and farmer.carrying > 0, 90.0)
	check(got_food, "farmer harvests food at the farm")
	var carried := farmer.carrying
	var f0 := game.economy.amount("food")
	await wait_until(func() -> bool: return farmer.at_home, 60.0)
	check(logged("%s brings %d food home" % [farmer.label(), carried], EventLog.Level.DEBUG) and game.economy.amount("food") > f0 - 5.0, "farmer delivers food home (+%d)" % carried)
	check(food_before > 0.0, "upkeep leaves food positive so far")

	# --- light stone --------------------------------------------------------------------
	game.economy.add("materials", 500)
	var ls_spot := find_spot("lightstone", game.player_village.center + Vector2i(0, 7))
	var ls: LightStone = game.construction.place("lightstone", ls_spot)
	check(ls != null, "light stone placed")
	await wait_until(func() -> bool: return ls.complete, 90.0)
	check(ls.complete and game.world.pathing.astar.is_point_solid(ls_spot), "builder raises the light stone (it blocks walking)")
	await wait(0.5)
	var lit := true
	for y in range(-6, 7):
		for x in range(-6, 7):
			var t := ls_spot + Vector2i(x, y)
			if map.is_explored(t) and Vector2(x, y).length() <= Config.LIGHTSTONE_SIGHT and not map.is_watched(t):
				lit = false
	check(lit, "light stone keeps %.1f tiles under surveillance without anyone in it" % Config.LIGHTSTONE_SIGHT)
	var ls_building: Building = ls
	check(not (ls_building is Tower) and game.army.station_error(null, game.world.pick_building(ls.position + Vector2(0, -40)) as Tower) != "", "nobody can be stationed on a light stone")

	# --- worker camp & forester ----------------------------------------------------------
	var camp_spot := Vector2i(-1, -1)
	var best_trees := 0
	for y in map.size:
		for x in map.size:
			var t := Vector2i(x, y)
			if game.construction.placement_error("camp", t) != "":
				continue
			var n := 0
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					if game.world.is_tree(t + Vector2i(dx, dy)) and map.is_explored(t + Vector2i(dx, dy)):
						n += 1
			if n > best_trees and not game.world.pathing.find_path(game.player_village.center, t).is_empty():
				best_trees = n
				camp_spot = t
	var camp: WorkerCamp = game.construction.place("camp", camp_spot)
	check(camp != null, "worker camp placed near the forest (%d trees around)" % best_trees)
	var idle_fo: Forester = civs("forester")[0]
	check(idle_fo.camp == null and start_camp.forester == null, "the starting forester is idle (unassigned earlier)")
	await wait_until(func() -> bool: return camp.complete, 90.0)
	check(camp.complete, "builder puts up the worker camp")
	check(camp.forester == idle_fo, "a finished camp takes the idle forester right away")
	game.economy.add("food", 100)
	var new_fo: Forester = game.population.recruit("forester")
	check(new_fo != null and start_camp.forester == new_fo, "a forester bought now goes to the empty starting camp")
	var fo: Forester = camp.forester
	check(not game.population.assign_forester(camp), "a camp holds only one forester")
	await wait_until(func() -> bool: return fo.state == Forester.State.CHOPPING, 90.0)
	var the_tree := fo.tree
	check(fo.state == Forester.State.CHOPPING and game.world.is_tree(the_tree), "forester walks from the camp to a tree and chops it")
	check(is_equal_approx(game.world.tree_chop_time(the_tree), Config.TREE_CHOP_TIME[map.props[the_tree]]), "chop time comes from the tree type (%s: %.0fs)" % [map.props[the_tree], game.world.tree_chop_time(the_tree)])
	var mats0 := game.economy.amount("materials")
	await wait_until(func() -> bool: return fo.state == Forester.State.AT_CAMP, 60.0)
	check(game.economy.amount("materials") >= mats0 + Config.FORESTER_MATERIAL_PER_TRIP, "back at the camp, the forester delivers building material")
	check(game.world.is_tree(the_tree) and game.world.tree_progress(the_tree) > 0.0, "the tree is partly chopped (%d%%)" % int(100 * game.world.tree_progress(the_tree)))
	await wait_until(func() -> bool: return fo.state == Forester.State.CHOPPING, 60.0)
	check(fo.tree == the_tree, "the forester returns to the same tree")
	game.world._chopped[the_tree] = game.world.tree_chop_time(the_tree) - 0.3
	await wait_until(func() -> bool: return not game.world.is_tree(the_tree), 10.0)
	check(map.get_terrain(the_tree) == MapData.Terrain.GRASS and game.world.pathing.is_walkable(the_tree), "a felled tree leaves walkable meadow")
	await wait_until(func() -> bool: return fo.state == Forester.State.CHOPPING, 90.0)
	check(fo.tree != the_tree and game.world.is_tree(fo.tree), "the forester moves on to the next tree")
	game.population.unassign_forester(camp)

	# --- army: recruit + drag & drop onto a wall tower ------------------------------
	game.economy.add("gold", 500)
	hud._select_tab("army")
	await frames(2)
	var gold2 := game.economy.amount("gold")
	await tap(center(hud._military_buttons["archer"]))
	check(game.army.reserve().size() == 1 and game.economy.amount("gold") == gold2 - 40, "archer recruited for 40 gold")
	await frames(2)
	var card: Button = hud._reserve_grid.get_child(0)
	var wt: Tower = wall_towers[0]
	var target := screen(wt.position + Vector2(0, -50))
	var start := center(card)
	mouse(start, true)
	await frames(1)
	var steps := 8
	for i in range(1, steps + 1):
		motion(start.lerp(target, float(i) / steps))
		await frames(1)
	mouse(target, false)
	await frames(2)
	check(wt.incoming != null and wt.garrison == null, "dragged archer marches out (not instantly on the tower)")
	check(game.army.reserve().is_empty() and game.army.walking().size() == 1, "marching archer has left the reserve")
	check(not game.fog.is_watched(wt.tile + Vector2i(-3, -3)) or game.army.walking().size() == 1, "unmanned wall tower doesn't watch")
	var arrived := await wait_until(func() -> bool: return wt.garrison != null, 30.0)
	check(arrived, "archer reaches the wall tower and mans it")
	await frames(2)
	check(game.fog.is_watched(wt.tile + Vector2i(-3, -3)), "a manned tower keeps its whole range under surveillance")
	# Tap mode: tap a card, then tap the new watchtower.
	await tap(center(hud._military_buttons["archer"]))
	await frames(2)
	card = hud._reserve_grid.get_child(0)
	await tap(center(card))
	check(game.mode == Game.Mode.STATION, "tapping a reserve card enters station mode")
	await tap(screen(watchtower.position + Vector2(0, -40)))
	check(watchtower.incoming != null, "tap-to-station sends an archer to the watchtower")
	await wait_until(func() -> bool: return watchtower.garrison != null, 60.0)
	check(watchtower.garrison != null, "archer arrives at the watchtower")
	var unit := watchtower.garrison
	# Withdraw: the archer walks home before it's back in the reserve.
	game.army.unstation(unit)
	check(watchtower.garrison == null and unit.state == MilitaryUnit.State.RETURNING and not game.army.reserve().has(unit), "withdrawn archer walks home first")
	await wait_until(func() -> bool: return unit.state == MilitaryUnit.State.RESERVE, 60.0)
	check(game.army.reserve().has(unit), "withdrawn archer is back in the reserve")
	game.army.station(unit, watchtower)
	await wait_until(func() -> bool: return watchtower.garrison != null, 60.0)
	check(game.army.upgrade(unit) and unit.level == 1, "archer upgraded with gold")

	# --- stationed units: tap to select, drag & drop to move or withdraw ----------
	var wa: MilitaryUnit = wt.garrison
	var t2: Tower = wall_towers[1]
	await tap(unit_on(wt))
	check(game.selected_unit == wa and hud._info_panel.visible and hud._info_title.text == "Archer", "tapping the archer on its tower selects the unit, not the tower")
	var ulabels: Array = []
	for b in buttons_in(hud._info_actions):
		ulabels.append(b.text)
	check(ulabels.any(func(l: String) -> bool: return l.begins_with("Upgrade")) and "Withdraw" in ulabels, "the unit panel offers Upgrade and Withdraw (%s)" % str(ulabels))
	await tap(screen(wt.position + Vector2(0, -6)))
	check(game.selected == wt and game.selected_unit == null, "tapping the tower itself still selects the tower")
	game.deselect()
	var to2 := screen(t2.position + Vector2(0, -40))
	check(not hud.is_over_ui(to2) and not hud.is_over_ui(unit_on(wt)), "(both towers are on screen)")
	await drag(unit_on(wt), to2, false)
	check(hud._drag_ghost.visible and wt._unit_sprite.modulate.a < 0.5, "dragging: the unit follows the pointer, dimmed on its old post")
	check(not game.world.overlay._targets.is_empty() and game.world.overlay._hover == t2.tiles() and game.world.overlay._arrow, "dragging: free posts light up, the one under the pointer in green, with an arrow")
	check(hud._drag_ghost.modulate.g > hud._drag_ghost.modulate.r, "the unit image turns green over a free post")
	mouse(to2, false)
	await frames(2)
	check(wa.state == MilitaryUnit.State.MARCHING and wa.post == t2 and wt.garrison == null and t2.incoming == wa, "dropped on a free tower, the unit walks over from its old post")
	check(not hud._drag_ghost.visible and game.world.overlay._targets.is_empty() and wt._unit_sprite.modulate.a == 1.0, "the drag preview is gone after the drop")
	await wait_until(func() -> bool: return t2.garrison == wa, 60.0)
	check(t2.garrison == wa and wa.state == MilitaryUnit.State.STATIONED, "it takes up the new post")
	check(logged("drag %s from %s to %s" % [wa.label(), wt.label(), t2.label()], EventLog.Level.DEBUG), "debug log: the drag & drop move")
	# Onto a manned tower, or bare ground: nothing happens.
	await drag(unit_on(t2), screen(watchtower.position + Vector2(0, -40)))
	check(wa.post == t2 and t2.garrison == wa and watchtower.garrison == unit, "dropped on a manned tower: nothing happens")
	var bare := Vector2i(-1, -1)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var bt := t2.tile + Vector2i(dx, dy)
			if bare == Vector2i(-1, -1) and absi(dx) + absi(dy) >= 3 and map.building_at(bt) == null and game.world.pick_building(Iso.tile_to_world(bt)) == null and not hud.is_over_ui(screen(Iso.tile_to_world(bt))):
				bare = bt
	await drag(unit_on(t2), screen(Iso.tile_to_world(bare)))
	check(wa.post == t2 and t2.garrison == wa and wa.state == MilitaryUnit.State.STATIONED, "dropped on open ground: nothing happens")
	# Onto the dock: withdraw.
	var dock_at := hud._sidebar.get_global_rect().get_center()
	await drag(unit_on(t2), dock_at, false)
	check(hud._dock_hint.visible and hud._sidebar.modulate != Color.WHITE, "over the sidebar it offers to withdraw the unit")
	mouse(dock_at, false)
	await frames(2)
	check(wa.state == MilitaryUnit.State.RETURNING and t2.garrison == null, "dropped on the sidebar, the unit is withdrawn")
	await wait_until(func() -> bool: return wa.state == MilitaryUnit.State.RESERVE, 60.0)
	game.army.station(wa, wt)
	await wait_until(func() -> bool: return wt.garrison == wa, 60.0)
	# --- commands: every player action is a checked, serialisable command -----------
	var bad := game.command("launch_rockets")
	check(not bad["ok"] and "Unknown" in bad["error"], "an unknown command is refused")
	check(not game.command("withdraw_unit", {"unit": 999999})["ok"] and not game.command("upgrade_tower", {})["ok"], "commands naming nothing (bad or missing ids) are refused")
	var other: Village = Village.new()
	other.create(game, 1, "Elsewhere", Color.RED)
	add_child(other)
	watchtower.village = other
	var foreign := game.command("upgrade_tower", {"building": watchtower.nid})
	watchtower.village = pvil
	unit.village = other
	var foreign_unit := game.command("upgrade_unit", {"unit": unit.nid})
	unit.village = pvil
	check(not foreign["ok"] and not foreign_unit["ok"], "a village can't give orders for another village's tower or unit (%s / %s)" % [foreign["error"], foreign_unit["error"]])
	var speed_other := game.commands.submit(other, "set_speed", {"index": 1})
	check(not speed_other["ok"] and speed_other["error"] == "The host sets the speed" and is_equal_approx(Engine.time_scale, 6.0), "only the host sets the game speed")
	other.queue_free()
	var mat_c0 := game.economy.amount("materials")
	var rb := game.command("buy_materials", {"bundles": 1})
	check(rb["ok"] and game.economy.amount("materials") == mat_c0 + Config.MATERIALS_TRADE["materials"], "a valid command is applied")
	var plain := cmd_log.all(func(c: Array) -> bool: return bytes_to_var(var_to_bytes(c[1])) == c[1] and not c[1].values().any(func(x) -> bool: return x is Object))
	check(not cmd_log.is_empty() and plain, "command arguments are plain data that survive serialisation (%d commands so far)" % cmd_log.size())

	# Man the other wall towers too.
	for t in wall_towers.slice(1):
		game.army.station(game.army.recruit("archer"), t)
	await wait_until(func() -> bool: return wall_towers.all(func(t: Tower) -> bool: return t.garrison != null), 60.0)
	check(wall_towers.all(func(t: Tower) -> bool: return t.garrison != null), "all wall towers manned")
	# Balance comes later: make the defence sturdy so the rest of the run is deterministic.
	game.economy.add("gold", 20000)
	for u in game.army.units:
		while u.can_upgrade() and game.army.upgrade(u):
			pass

	# --- waves ----------------------------------------------------------------------
	var gold3 := game.economy.amount("gold")
	game.waves.countdown = 2.0
	var started := await wait_until(func() -> bool: return game.waves.wave == 1, 5.0)
	check(started and game.waves.in_progress(), "wave 1 starts by itself when the timer runs out")
	var warned := await wait_until(func() -> bool: return not game.world.warnings.spots.is_empty(), 20.0)
	check(warned, "early wave on normal: a red warning light marks where hidden enemies are headed")
	if warned:
		var wspot: Vector2 = game.world.warnings.spots[0]
		var near_watched := false
		var near_unwatched := false
		for d in [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
			var t := Vector2i((wspot + d).round())
			near_watched = near_watched or game.fog.is_watched(t)
			near_unwatched = near_unwatched or not game.fog.is_watched(t)
		check(near_watched and near_unwatched, "the light sits on the edge between hidden and watched land")
	Settings.difficulty = Settings.Difficulty.HARD
	check(not game.world.warnings.enabled(), "no warning lights on hard")
	Settings.difficulty = Settings.Difficulty.EASY
	check(game.world.warnings.enabled(), "warning lights on easy")
	Settings.difficulty = Settings.Difficulty.NORMAL
	var real_wave := game.waves.wave
	game.waves.wave = Config.WARNING_LIGHT_WAVES + 1
	check(not game.world.warnings.enabled(), "no warning lights after wave %d" % Config.WARNING_LIGHT_WAVES)
	game.waves.wave = real_wave
	await frames(2)
	check(hud._enemies_label.text == str(game.waves.enemies_left()) and game.waves.enemies_left() == Config.wave_size(1), "HUD shows the enemy count (%s)" % hud._enemies_label.text)
	var cleared := await wait_until(func() -> bool: return not game.waves.in_progress(), 240.0)
	check(cleared, "wave 1 ends")
	print("  wave 1: gold %d -> %d, civilians %d, huts %d" % [gold3, game.economy.amount("gold"), game.population.count(), game.population.cap()])

	# --- event log & settings dialog ---------------------------------------------------
	var ev := game.events
	var cd0 := game.waves.countdown  # (restored below for the countdown check)
	await frames(2)
	check(logged("Wave 1 begins", EventLog.Level.INFO) and hud.log_lines().has("Wave 1 is over"), "the log shows the wave starting and ending at Info level (%s)" % str(hud.log_lines()))
	check(logged("killed goblin", EventLog.Level.DEBUG) and not hud.log_lines().any(func(t: String) -> bool: return t.begins_with("killed")), "kills are logged at debug level, hidden at Info")
	var lr := hud._log_box.get_global_rect()
	var vpl := get_viewport().get_visible_rect().size
	check(lr.position.x < 12.0 and absf(lr.end.y - (vpl.y - 10.0)) < 1.5 and lr.size.y <= EventLog.MAX_SHOWN * hud.LOG_LINE_H + 1.0, "the log sits bottom left with a capped height (%s)" % lr)
	check(hud._log_box.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._log_box.get_class() == "VBoxContainer" and hud._log_box.get_children().all(func(l: Label) -> bool: return (l.get_theme_color("font_color") as Color).a < 0.85), "the log is bare, see-through text that never catches taps")
	for i in 12:
		ev.info("test info line %d, long enough to need most of the width of the field" % i)
	game.select(game.world.towers()[0])
	hud._hero_panel.visible = true
	hud._refresh_hero()
	await frames(3)
	var lb := hud._log_box.get_global_rect()
	check(not lb.intersects(hud._info_panel.get_global_rect()) and not lb.intersects(hud._hero_panel.get_global_rect()) and hud._log_box.clip_contents, "a full log stays clear of the info and hero panels")
	check(hud._log_box.get_children().all(func(l: Label) -> bool: return not l.visible or lb.encloses(l.get_global_rect().grow(-0.5))), "log lines never spill out of the log field")
	hud._hero_panel.visible = false
	game.deselect()
	await frames(2)
	for i in 25:
		ev.debug("test debug %d" % i)
	ev.important("test important")
	var n_debug := ev.entries.filter(func(e: Dictionary) -> bool: return e["level"] == EventLog.Level.DEBUG).size()
	check(n_debug == EventLog.MAX_PER_LEVEL and ev.entries.any(func(e: Dictionary) -> bool: return e["text"] == "test important"), "each level keeps only its newest %d messages, so debug spam can't push out important ones" % EventLog.MAX_PER_LEVEL)
	# Settings: pauses at the current speed, greys the game, colourful dialog.
	hud.set_speed_index(1)  # 2x
	await tap(center(hud._settings_button))
	check(hud._settings.visible and get_tree().paused, "the gear opens the settings and pauses the game")
	var dialog := hud._settings_continue.get_parent().get_parent() as Control
	check(dialog.get_global_rect().get_center().distance_to(vpl / 2.0) < 4.0, "the dialog is centred")
	var gray := hud._settings.get_child(0) as ColorRect
	check(gray.material is ShaderMaterial and "hint_screen_texture" in (gray.material as ShaderMaterial).shader.code and gray.get_global_rect().size == vpl, "behind it the whole screen is shown in grayscale")
	check(hud._settings_continue.text == "Continue" and hud._settings_log_button.text == "Log level: Info" and hud._settings_lang_button.icon == Art.tex("flag_gb") and hud._settings_lang_button.text == "" and hud._settings_title_button.text == "Back to title", "buttons: Continue, Log level, a British flag for English, Back to title")
	var red := hud._settings_title_button.get_theme_stylebox("normal") as StyleBoxFlat
	check(red.bg_color.r > 0.6 and red.bg_color.g < 0.3 and hud._settings_title_button.pressed.get_connections().size() > 0, "Back to title is red and wired")
	await tap(center(hud._settings_log_button))
	await frames(2)
	check(hud._settings_log_button.text == "Log level: Important" and hud.log_lines().has("test important") and not hud.log_lines().has("Wave 1 is over"), "log level Important: only important messages, old ones included")
	await tap(center(hud._settings_log_button))
	await frames(2)
	check(hud._settings_log_button.text == "Log level: Debug" and hud.log_lines().has("test debug 24") and hud.log_lines().size() == EventLog.MAX_SHOWN, "log level Debug: everything, the newest %d" % EventLog.MAX_SHOWN)
	await tap(center(hud._settings_log_button))
	check(hud._settings_log_button.text == "Log level: Info", "and back to Info")
	await tap(center(hud._settings_lang_button))
	check(Settings.language == "en" and hud._settings_lang_button.icon == Art.tex("flag_gb"), "language toggles through the supported ones (just English)")
	await tap(center(hud._settings_continue))
	check(not hud._settings.visible and not get_tree().paused and is_equal_approx(Engine.time_scale, 2.0), "Continue closes it and resumes at the earlier speed (2x)")
	hud.set_speed_index(0)
	Engine.time_scale = 6.0  # (the test's own pace)
	# Messages disappear 30 s after they were logged.
	var aged := 0
	for e in ev.entries:
		e["time"] -= EventLog.LIFETIME + 1.0
		e["aged"] = true
		aged += 1
	ev.info("fresh message")
	ev._prune_timer = 0.0  # (it prunes every 0.5 s of real time; the test runs faster)
	await frames(3)
	check(aged > 0 and not ev.entries.any(func(e: Dictionary) -> bool: return e.has("aged")) and hud.log_lines().has("fresh message"), "messages are cleared %d s after they were logged; newer ones stay" % int(EventLog.LIFETIME))
	game.waves.countdown = cd0
	check(game.economy.amount("gold") > gold3, "archers killed enemies for gold")
	check(absf(game.waves.countdown - Config.WAVE_BUFFER) < 2.0, "next wave counts down from %ds after the last enemy" % int(Config.WAVE_BUFFER))
	await wait(5.0)
	var bonus := game.waves.early_call_bonus()
	var gold4 := game.economy.amount("gold")
	await tap(center(hud._call_button))
	check(game.waves.wave == 2 and game.economy.amount("gold") == gold4 + bonus and bonus > 0, "calling early starts wave 2 with +%d gold" % bonus)
	await wait_until(func() -> bool: return not game.waves.in_progress(), 240.0)
	var auto := await wait_until(func() -> bool: return game.waves.wave == 3, Config.WAVE_BUFFER + 5.0)
	check(auto, "wave 3 starts automatically after the buffer")
	var skel := game.waves._queue.filter(func(q: Dictionary) -> bool: return q["kind"] == "skeleton").size() + get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return e.kind == "skeleton").size()
	check(skel > 0, "skeletons march with the goblins in wave 3 (%d)" % skel)
	await wait_until(func() -> bool: return not game.waves.in_progress(), 300.0)
	game.waves.countdown = 99999.0
	game.waves.hold = true  # no more real waves: later sections spawn their own enemies

	# --- corpses & gatherer --------------------------------------------------------------
	var cs := game.corpses
	check(cs.count() > 0 and cs.corpses.all(func(c: Corpse) -> bool: return c.wave == 3), "only wave-3 corpses remain (older waves cleared) : %d" % cs.count())
	# Kill payout is instant; the corpse stays where the enemy died.
	var road_spot: Vector2i = map.gates[1] + (map.gates[1] - game.player_village.center).sign() * 2
	game.waves._spawn({"kind": "goblin", "spawn": road_spot, "hp_scale": 1.0})
	var victim: Enemy = get_tree().get_nodes_in_group("enemies").back()
	victim.speed = 0.0
	var g_before := game.economy.amount("gold")
	var n_before := cs.count()
	victim.take_damage(1e9)
	check(game.economy.amount("gold") == g_before + Config.ENEMIES["goblin"]["gold_on_kill"], "killing pays gold_on_kill instantly")
	check(cs.count() == n_before + 1 and cs.corpses.back().tile() == victim.current_tile(), "a corpse is left where the enemy died")
	game.waves.countdown = 99999.0  # the test goblin's death re-armed the wave timer
	# Skeletons: gold only, no food; bones stay behind.
	game.waves._spawn({"kind": "skeleton", "spawn": road_spot, "hp_scale": 1.0})
	var bones: Enemy = get_tree().get_nodes_in_group("enemies").back()
	bones.speed = 0.0
	var gs := game.economy.amount("gold")
	bones.take_damage(1e9)
	check(bones.kind == "skeleton" and game.economy.amount("gold") == gs + Config.enemy_stat_int("skeleton", "gold_on_kill"), "a killed skeleton pays gold")
	check(cs.corpses.back().kind == "skeleton", "and leaves its bones")
	var no_food := true
	for dif in [Settings.Difficulty.EASY, Settings.Difficulty.NORMAL, Settings.Difficulty.HARD]:
		Settings.difficulty = dif
		no_food = no_food and Config.enemy_stat_int("skeleton", "food_on_collect") == 0 and Config.enemy_stat_int("skeleton", "gold_on_collect") > 0
	Settings.difficulty = Settings.Difficulty.NORMAL
	check(no_food, "skeleton corpses give gold but never food, on every difficulty")
	cs.remove(cs.corpses.back())
	game.waves.countdown = 99999.0
	# Expiry.
	var rotting: Corpse = cs.spawn("goblin", 3, Vector2(road_spot))
	rotting.time_left = 0.05
	await frames(3)
	check(not is_instance_valid(rotting) or not cs.corpses.has(rotting), "uncollected corpses rot away")
	# Wave cleanup: corpses of wave N vanish when wave N+1 is finished.
	var old: Corpse = cs.spawn("goblin", 3, Vector2(road_spot))
	var newer: Corpse = cs.spawn("goblin", 4, Vector2(road_spot))
	game.waves.wave_finished.emit(4)
	check((not is_instance_valid(old) or not cs.corpses.has(old)) and cs.corpses.has(newer), "wave-3 corpses disappear when wave 4 is finished")
	cs.remove(newer)
	# Unsafe corpse: a living goblin stands guard far out on a road, so the
	# gatherer must ignore that corpse (but not the safe ones elsewhere).
	var far_route := game.world.pathing.enemy_route(map.edge_spawns[0], RandomNumberGenerator.new())
	var far_spot: Vector2i = far_route[far_route.size() / 3]
	var guarded: Corpse = cs.spawn("goblin", 3, Vector2(far_spot))
	game.waves._spawn({"kind": "goblin", "spawn": far_spot, "hp_scale": 1000.0})
	var guard: Enemy = get_tree().get_nodes_in_group("enemies").back()
	guard.speed = 0.0
	for t in game.world.towers():
		if t.garrison: game.army.unstation(t.garrison)  # keep the guard alive
	check(not cs.is_safe(guarded) and not cs.available().has(guarded), "corpses next to living enemies are unsafe")
	# Pile of corpses to test capacity and payout.
	var pile_gate: Vector2i = open_gate()
	for gt in map.gates:
		if Vector2(gt).distance_to(Vector2(far_spot)) > Vector2(pile_gate).distance_to(Vector2(far_spot)):
			pile_gate = gt
	var pile: Vector2i = pile_gate + (pile_gate - game.player_village.center).sign() * 2
	check(cs.is_safe(cs.spawn("goblin", 3, Vector2(pile))), "corpses away from enemies are safe")
	for i in Config.GATHERER_CAPACITY + 2:
		cs.spawn("goblin", 3, Vector2(pile))
	game.economy.add("food", 200)
	game.population.civilian_lost.connect(func(c: Civilian) -> void: print("  LOST %s food=%.0f pop=%d cap=%d enemies=%d" % [c.role, game.economy.amount("food"), game.population.count(), game.population.cap(), game.waves.enemies_left()]))
	var gatherer: Gatherer = game.population.recruit("gatherer")
	check(gatherer != null, "gatherer recruited with food")
	var max_carried := 0
	var trip_done := false
	var g0 := game.economy.amount("gold")
	var f0g := game.economy.amount("food")
	var t_run := 0.0
	var delivered := 0
	while t_run < 120.0:
		await get_tree().process_frame
		t_run += get_process_delta_time()
		game.waves.countdown = 99999.0
		max_carried = maxi(max_carried, gatherer.carried.size())
		check_silent_guard(gatherer, guarded)
		if gatherer.state == Gatherer.State.RETURNING and gatherer.carried.size() > 0:
			delivered = gatherer.carried.size()
			await wait_until(func() -> bool: return gatherer.at_home, 60.0)
			trip_done = true
			break
	check(trip_done, "gatherer fetches corpses and walks home")
	check(max_carried == Config.GATHERER_CAPACITY, "gatherer carries up to %d corpses per trip (%d)" % [Config.GATHERER_CAPACITY, max_carried])
	var exp_gold: int = delivered * Config.ENEMIES["goblin"]["gold_on_collect"]
	var exp_food: int = delivered * Config.ENEMIES["goblin"]["food_on_collect"]
	check(game.economy.amount("gold") >= g0 + exp_gold, "delivery pays gold_on_collect (+%d)" % exp_gold)
	check(game.economy.amount("food") >= f0g + exp_food - 10.0, "delivery pays food_on_collect (+%d)" % exp_food)
	check(not _guard_touched, "gatherer never went for the guarded corpse")
	guard.take_damage(1e9)
	game.waves.countdown = 99999.0
	cs.clear_wave(99)
	for t in game.world.towers():
		if t.garrison == null and t.incoming == null and not game.army.reserve().is_empty():
			game.army.station(game.army.reserve()[0], t)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)

	# --- tower panel, tower levels -------------------------------------------------------
	game.waves.countdown = 99999.0
	var labels: Array = watchtower.info()["actions"].map(func(x: Dictionary) -> String: return x["label"])
	var can_up := watchtower.garrison != null and not watchtower.garrison.upgrade_options().is_empty()
	check(labels.size() == (3 if can_up else 2) and labels[0].begins_with("Upgrade tower") and (not can_up or labels[1].begins_with("Upgrade ")) and labels[-1] == "Withdraw", "tower panel offers Upgrade tower, Upgrade <unit>... and Withdraw (%s)" % str(labels))
	var empty_tower: Tower = null
	for t in game.world.towers():
		if t.complete and t.garrison == null and t.incoming == null:
			empty_tower = t
	if empty_tower:
		var el: Array = empty_tower.info()["actions"].map(func(x: Dictionary) -> String: return x["label"])
		check(not el.any(func(l: String) -> bool: return "Send" in l or "Station" in l or "rcher" in l), "unmanned tower has no station button (%s)" % str(el))
	check(watchtower.level == 1 and wall_towers.all(func(t: Tower) -> bool: return t.level == 1), "all towers start at level 1")
	game.economy.add("materials", 200)
	var r1 := watchtower.range_tiles()
	var m1 := game.economy.amount("materials")
	check(game.construction.order_upgrade(watchtower) and game.economy.amount("materials") == m1 - Config.TOWER_LEVELS[1]["cost"]["materials"], "tower upgrade ordered for building material")
	check(watchtower.upgrading and watchtower.complete and watchtower.garrison != null, "tower stays finished and manned while upgrading")
	game.waves._spawn({"kind": "goblin", "spawn": far_spot, "hp_scale": 1000.0})
	var dummy: Enemy = get_tree().get_nodes_in_group("enemies").back()
	dummy.speed = 0.0
	dummy.set_grid_pos(Vector2(watchtower.tile) + Vector2(2.0, 0.0))
	var hp_start := dummy.hp
	var fired_during := await wait_until(func() -> bool: return dummy.hp < hp_start and watchtower.upgrading, 10.0)
	check(fired_during, "the stationed unit keeps shooting while the tower is being upgraded")
	dummy.take_damage(1e9)  # (a goblin this close would make the builder flee)
	var up_done := await wait_until(func() -> bool: return not watchtower.upgrading and watchtower.level == 2, 120.0)
	check(up_done and watchtower.level == 2, "a builder completes the tower upgrade")
	check(is_equal_approx(watchtower.range_tiles(), r1 + Config.TOWER_LEVELS[1]["range_bonus"]), "tower level raises the unit's range (%.1f -> %.1f)" % [r1, watchtower.range_tiles()])
	check(watchtower.sprite.texture == Art.tex("watchtower_2"), "level 2 tower looks different")
	game.waves.countdown = 99999.0

	# --- summoner & earth elementals ------------------------------------------------------
	game.economy.add("gold", 2000)
	var sm_tower: Tower = wall_towers[1]
	if sm_tower.garrison:
		game.army.unstation(sm_tower.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	var summoner := game.army.recruit("summoner")
	check(summoner != null and summoner.kind == "summoner", "summoner recruited with gold")
	game.army.station(summoner, sm_tower)
	await wait_until(func() -> bool: return sm_tower.garrison == summoner, 60.0)
	check(sm_tower.garrison == summoner and sm_tower._unit_sprite.texture == Art.tex("unit_summoner"), "summoner stands on the tower")
	var sb: SummonerBehavior = summoner.behavior
	await wait(8.0)
	check(sb.summons.is_empty(), "no summons while no enemy is in sight")
	# A tough, stationary goblin next to the tower.
	var sm_spot := Vector2i(-1, -1)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := sm_tower.tile + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(sm_tower.tile))
			if sm_spot == Vector2i(-1, -1) and d >= 2.0 and d <= 3.0 and not map.in_village(t) and game.world.pathing.is_walkable(t):
				sm_spot = t
	game.waves._spawn({"kind": "goblin", "spawn": far_spot, "hp_scale": 1000.0})
	var brute: Enemy = get_tree().get_nodes_in_group("enemies").back()
	brute.speed = 0.0
	brute.set_grid_pos(Vector2(sm_spot))
	for t in game.world.towers():
		if t.garrison and t.garrison.kind == "archer":
			game.army.unstation(t.garrison)  # let the elementals do the fighting
	var got := await wait_until(func() -> bool: return sb.summons.size() >= 1, 20.0)
	check(got, "summoner summons earth elementals when an enemy comes into sight")
	var first: EarthElemental = sb.summons[0] if got else null
	if first:
		check(is_equal_approx(first.max_hp, Config.ENEMIES["goblin"]["hp"]) and is_equal_approx(first.damage, Config.ENEMIES["goblin"]["damage"]), "a level-1 elemental is as strong as a goblin")
	await wait(Config.unit_stat("summoner", "interval", 0) * 4.0)
	check(sb.summons.size() <= int(summoner.stat("max_summons")), "summons never exceed the cap (%d/%d)" % [sb.summons.size(), int(summoner.stat("max_summons"))])
	var hp_b := brute.hp
	var fought := await wait_until(func() -> bool: return brute.hp < hp_b and sb.summons.any(func(e) -> bool: return is_instance_valid(e) and e.hp < e.max_hp), 30.0)
	if not fought:
		print("  detail: brute at %s hp %.0f/%.0f; summons: %s" % [brute.grid_pos, brute.hp, hp_b, str(sb.summons.map(func(e) -> String: return "%s tgt=%s hp=%.0f path=%d/%d" % [e.grid_pos, e.target != null, e.hp, e.path_index, e.path.size()]))])
	check(fought, "elementals fight the enemy in close combat, and it fights back")
	var corpses_before := cs.count()
	var doomed: EarthElemental = sb.summons[0] if not sb.summons.is_empty() else null
	if doomed:
		doomed.take_damage(1e9)
		await frames(3)
		check(doomed.dead and cs.count() == corpses_before, "a slain elemental leaves no corpse")
	var survivor: EarthElemental = null
	for e in sb.summons:
		if is_instance_valid(e) and not e.dead:
			survivor = e
	var old_hp := survivor.max_hp if survivor else 0.0
	var old_cap := int(summoner.stat("max_summons"))
	var old_interval := summoner.stat("interval")
	check(game.army.upgrade(summoner), "summoner upgraded with gold")
	check(summoner.stat("interval") < old_interval and int(summoner.stat("max_summons")) > old_cap, "upgrade: faster summoning and a higher cap")
	var is_new := func(e) -> bool: return is_instance_valid(e) and not e.dead and e != survivor and is_equal_approx(e.max_hp, summoner.stat("summon_hp"))
	await wait_until(func() -> bool: return sb.summons.any(is_new), 30.0)
	var newest: Array = sb.summons.filter(is_new)
	check(not newest.is_empty(), "new summons get the upgraded stats")
	if survivor and is_instance_valid(survivor):
		check(is_equal_approx(survivor.max_hp, old_hp), "existing summons keep their old stats")
	game.army.unstation(summoner)
	await frames(3)
	check(sb.summons.is_empty() and get_tree().get_nodes_in_group("summons").is_empty(), "withdrawing the summoner dismisses its elementals")
	brute.take_damage(1e9)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	game.waves.countdown = 99999.0

	# --- ork ---------------------------------------------------------------------------------
	game.waves._spawn({"kind": "ork", "spawn": far_spot, "hp_scale": 1.0})
	var brute_ork: Enemy = get_tree().get_nodes_in_group("enemies").back()
	check(brute_ork.kind == "ork" and brute_ork.behavior is MeleeBehavior and brute_ork.max_hp == Config.enemy_stat("ork", "hp"), "orks spawn with their own stats and melee behavior")
	var g_ork := game.economy.amount("gold")
	brute_ork.take_damage(1e9)
	check(game.economy.amount("gold") == g_ork + Config.enemy_stat_int("ork", "gold_on_kill") and cs.corpses.back().kind == "ork", "a killed ork pays gold and leaves a corpse")
	cs.remove(cs.corpses.back())
	game.waves.countdown = 99999.0

	# --- witch: bewitches manned towers --------------------------------------------------------
	var wt_tower: Tower = watchtower
	if wt_tower.garrison == null:
		game.army.station(game.army.recruit("archer"), wt_tower)
		await wait_until(func() -> bool: return wt_tower.garrison != null, 60.0)
	var wspot2 := Vector2i(-1, -1)
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var t := wt_tower.tile + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(wt_tower.tile))
			if wspot2 == Vector2i(-1, -1) and d >= 3.0 and d <= 4.0 and game.world.pathing.is_walkable(t) and not map.in_village(t):
				wspot2 = t
	game.waves._spawn({"kind": "witch", "spawn": far_spot, "hp_scale": 1000.0})
	var hag: Enemy = get_tree().get_nodes_in_group("enemies").back()
	hag.speed = 0.0
	hag.set_grid_pos(Vector2(wspot2))
	check(hag.kind == "witch" and hag.behavior is WitchBehavior, "witch spawned with the witch behavior")
	var bewitched := await wait_until(func() -> bool: return wt_tower.is_enchanted(), 10.0)
	check(bewitched, "a witch in range bewitches the manned tower with her spell")
	check(wt_tower._spell_glow.visible, "the bewitched unit has a pink glow around its head")
	var expected_enchant: float = Config.ENEMIES["witch"]["spell_cooldown"] * Config.ENEMIES["witch"]["enchant_ratio"]
	check(wt_tower.enchanted <= expected_enchant + 0.01 and wt_tower.enchanted > expected_enchant - 0.5, "the spell lasts %.0f%% of her cooldown (%.2fs)" % [100 * Config.ENEMIES["witch"]["enchant_ratio"], expected_enchant])
	# While bewitched the unit fires nothing new.
	var seen_arrows := {}
	for n in game.world.effects.get_children():
		if n is Shot:
			seen_arrows[n] = true
	var fired_while_bewitched := false
	var t_w := 0.0
	while wt_tower.is_enchanted() and t_w < 3.0:
		await get_tree().process_frame
		t_w += get_process_delta_time()
		for n in game.world.effects.get_children():
			if n is Shot and not seen_arrows.has(n) and (n as Shot).source == wt_tower:
				fired_while_bewitched = true
	check(not fired_while_bewitched, "a bewitched unit does not shoot")
	var gap := await wait_until(func() -> bool: return not wt_tower.is_enchanted(), 3.0)
	check(gap, "between casts the unit gets a short window to act")
	hag.take_damage(1e9)
	await wait(0.5)

	# --- witch vs summoner: attacker first, spells hurt elementals -------------------------------
	var sm2 := summoner
	var sm_t: Tower = wall_towers[1]
	if sm2.state != MilitaryUnit.State.STATIONED:
		await wait_until(func() -> bool: return sm2.state == MilitaryUnit.State.RESERVE, 60.0)
		game.army.station(sm2, sm_t)
		await wait_until(func() -> bool: return sm_t.garrison == sm2, 60.0)
	var sb2: SummonerBehavior = sm2.behavior
	game.waves._spawn({"kind": "witch", "spawn": far_spot, "hp_scale": 1000.0})
	var hag2: Enemy = get_tree().get_nodes_in_group("enemies").back()
	hag2.speed = 0.0
	hag2.set_grid_pos(Vector2(sm_spot))
	var wb: WitchBehavior = hag2.behavior
	var engaged := await wait_until(func() -> bool: return wb.attacker is EarthElemental, 40.0)
	check(engaged, "an elemental attacks the witch")
	if engaged:
		var foe: EarthElemental = wb.attacker
		var hp0 := foe.hp
		var retaliates := await wait_until(func() -> bool: return wb.target == foe, 5.0)
		check(retaliates, "the witch turns her spells on whoever attacks her")
		var hurt := await wait_until(func() -> bool: return not is_instance_valid(foe) or foe.hp < hp0, 8.0)
		check(hurt, "her spell damages earth elementals")
		var keep_fighting := sb2.summons.any(func(e) -> bool: return is_instance_valid(e) and not e.dead)
		check(keep_fighting or not is_instance_valid(foe), "existing elementals keep fighting while their summoner may be bewitched")
	# Regression: elementals dying and being freed while their tower is bewitched
	# (the tower doesn't update then) used to break the summoner for good.
	sm_t.enchant(3.0)
	for e in sb2.summons:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(1e9)
	await wait(1.5)  # long enough for the dead elementals to be freed
	var resumed := await wait_until(func() -> bool: return sb2.summons.size() > 0 and sb2.summons.all(func(x) -> bool: return is_instance_valid(x)), 20.0)
	check(resumed, "summoner keeps summoning after its elementals died while it was bewitched")
	hag2.take_damage(1e9)
	game.army.unstation(sm2)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	game.waves.countdown = 99999.0

	# --- witch anti-stall tracker ----------------------------------------------------------
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	var reach: float = Config.ENEMIES["witch"]["spell_range"]
	# Needs a tower the witch outranges; build a fresh level-1 watchtower if none.
	var lone: Tower = null
	for t in game.world.towers():
		if t.complete and t.range_tiles() < reach - 0.2:
			lone = t
	if lone == null:
		game.economy.add("materials", 100)
		lone = game.construction.place("tower", find_spot("tower", game.player_village.center + Vector2i(-7, 0)))
		await wait_until(func() -> bool: return lone.complete, 90.0)
	var reserve_archers := game.army.reserve().filter(func(u: MilitaryUnit) -> bool: return u.kind == "archer")
	game.army.station(reserve_archers[0] if not reserve_archers.is_empty() else game.army.recruit("archer"), lone)
	await wait_until(func() -> bool: return lone.garrison != null, 60.0)
	var limit := int(Config.ENEMIES["witch"]["spell_ignore_after"])
	var cast_cd: float = Config.ENEMIES["witch"]["spell_cooldown"]
	var outward := (Vector2(lone.tile) - Vector2(game.player_village.center)).normalized()
	var stall_pos := Vector2(lone.tile) + outward * ((lone.range_tiles() + reach) / 2.0)
	game.waves._spawn({"kind": "witch", "spawn": far_spot, "hp_scale": 1.0})
	var w3: Enemy = get_tree().get_nodes_in_group("enemies").back()
	w3.speed = 0.0
	w3.set_grid_pos(stall_pos)
	var wb3: WitchBehavior = w3.behavior
	check(stall_pos.distance_to(Vector2(lone.tile)) > lone.range_tiles() and stall_pos.distance_to(Vector2(lone.tile)) <= reach, "witch parked beyond the archer's range but within her own (the old soft-lock)")
	var gave_up := await wait_until(func() -> bool: return wb3.casts_at(lone) >= limit and wb3.target == null, limit * cast_cd + 20.0)
	check(gave_up, "after %d spells at a tower that can't reach her, the witch ignores it (%d casts)" % [limit, wb3.casts_at(lone)])
	check(is_instance_valid(w3) and not w3.dead and is_equal_approx(w3.hp, w3.max_hp), "the tower's unit really could not reach her")
	await wait(3.0)
	check(not lone.is_enchanted(), "the ignored tower is no longer bewitched")
	if is_instance_valid(w3) and not w3.dead:
		w3.take_damage(1.0, lone)
		check(wb3.casts_at(lone) == 0, "when that tower attacks her again, her count for it resets")
		var retarget := await wait_until(func() -> bool: return wb3.target == lone, 3.0)
		check(retarget, "and she targets it again")
		w3.take_damage(1e9)
	game.waves.countdown = 99999.0
	# A walking witch next to a tower manned only by a summoner must not stall.
	game.army.unstation(lone.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	await wait_until(func() -> bool: return summoner.state == MilitaryUnit.State.RESERVE, 60.0)
	game.army.station(summoner, lone)
	await wait_until(func() -> bool: return lone.garrison == summoner, 60.0)
	var near_gate: Vector2i = open_gate()
	for gt in map.gates:
		if Vector2(gt).distance_to(Vector2(lone.tile)) < Vector2(near_gate).distance_to(Vector2(lone.tile)):
			near_gate = gt
	var approach: Array[Vector2i] = []
	for sp in map.edge_spawns:
		var r := game.world.pathing.enemy_route(sp, RandomNumberGenerator.new())
		if r[-1] == near_gate:
			approach = r
			break
	if approach.is_empty():
		check(false, "found a road leading to the summoner's gate")
	else:
		game.waves._spawn({"kind": "witch", "spawn": approach[maxi(0, approach.size() - 10)], "hp_scale": 1.0})
		var w4: Enemy = get_tree().get_nodes_in_group("enemies").back()
		var wb4: WitchBehavior = w4.behavior
		var saw_summoner := false
		var t4 := 0.0
		while is_instance_valid(w4) and not w4.dead and t4 < limit * cast_cd + 90.0:
			await get_tree().process_frame
			t4 += get_process_delta_time()
			saw_summoner = saw_summoner or wb4.target == lone
		check(saw_summoner, "the witch bewitches the summoner's tower on her way")
		check(not is_instance_valid(w4) or w4.dead, "but she never stalls there: she is killed or walks on (after %.0fs)" % t4)
	game.army.unstation(summoner)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	game.waves.countdown = 99999.0

	# --- demolition at the gate -------------------------------------------------------
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	var huts0 := game.population.cap()
	var pop0 := game.population.count()
	var homes := {}
	for h in game.world.intact_huts():
		homes[h] = h.resident != null  # a bool: a dead resident's object would read as null later
	var gate: Vector2i = open_gate()
	var outside := gate + (gate - game.player_village.center).sign()
	game.waves._spawn({"kind": "goblin", "spawn": outside, "hp_scale": 1.0})
	await wait_until(func() -> bool: return game.population.cap() < huts0, 20.0)
	var burned: Array = homes.keys().filter(func(h: Hut) -> bool: return not h.is_intact())
	check(burned.size() == 1, "an enemy at the gate destroys exactly one random hut")
	var had_resident: bool = burned.size() == 1 and homes[burned[0]]
	check(game.population.count() == pop0 - (1 if had_resident else 0), "only that hut's resident dies (hut was %s)" % ("occupied" if had_resident else "empty"))
	check(residency_ok(), "everyone else still lives in their own hut")
	game.waves.countdown = 99999.0
	# Hard difficulty: still exactly one hut per enemy that gets in.
	Settings.difficulty = Settings.Difficulty.HARD
	var huts_h := game.population.cap()
	game.waves._spawn({"kind": "ork", "spawn": outside, "hp_scale": 1.0})
	await wait_until(func() -> bool: return game.population.cap() < huts_h, 20.0)
	await wait(1.0)
	check(game.population.cap() == huts_h - 1, "on hard, an enemy at the gate still destroys exactly one hut")
	Settings.difficulty = Settings.Difficulty.NORMAL
	game.waves.countdown = 99999.0
	# Direct checks for both cases.
	var empty_huts := game.world.intact_huts().filter(func(h: Hut) -> bool: return h.resident == null)
	if not empty_huts.is_empty():
		var p1 := game.population.count()
		(empty_huts[0] as Hut).destroy()
		check(game.population.count() == p1, "destroying an empty hut kills nobody")
	var lived := game.world.intact_huts().filter(func(h: Hut) -> bool: return h.resident != null)
	if not lived.is_empty():
		var victim_civ: Civilian = (lived[0] as Hut).resident
		var p2 := game.population.count()
		(lived[0] as Hut).destroy()
		check(game.population.count() == p2 - 1 and not game.population.civilians.has(victim_civ), "destroying an occupied hut kills exactly its resident")
	huts0 = game.population.cap() + game.world.huts().filter(func(h: Hut) -> bool: return h.ruined).size()
	for h in game.world.huts().filter(func(h: Hut) -> bool: return h.ruined).slice(1):
		(h as Hut).finish()  # keep one ruin for the rebuild test
	huts0 = game.population.cap() + 1
	game.waves.countdown = 99999.0  # that goblin's end re-armed the wave timer

	# --- civilians evade enemies ----------------------------------------------------------
	var the_farm: Farm = game.world.buildings.filter(func(b: Building) -> bool: return b is Farm)[0]
	if the_farm.farmer == null:
		if game.population.free_farmers().is_empty():
			game.population.spawn("farmer")
		game.population.assign_farmer(the_farm)
	var fm: Farmer = the_farm.farmer
	# Wait until the farmer is well outside the walls, so the evasion is observable.
	await wait_until(func() -> bool: return not fm.at_home and fm.state == Farmer.State.TO_FARM and fm.grid_pos.distance_to(Vector2(game.player_village.center)) > 3.0, 90.0)
	game.waves._spawn({"kind": "goblin", "spawn": map.edge_spawns[0], "hp_scale": 100.0})
	var threat: Enemy = get_tree().get_nodes_in_group("enemies").back()
	threat.speed = 0.0
	threat.set_grid_pos(fm.grid_pos + Vector2(1.5, 0))
	var fled := await wait_until(func() -> bool: return fm.evading, 2.0)
	check(fled, "a farmer who spots an enemy runs home" + ("" if fled else " [fm home=%s state=%s dead=%s pos=%s | goblin dead=%s pos=%s dist=%.1f]" % [fm.at_home, fm.state, fm.dead, fm.grid_pos, threat.dead if is_instance_valid(threat) else "freed", threat.grid_pos if is_instance_valid(threat) else Vector2.ZERO, fm.grid_pos.distance_to(threat.grid_pos) if is_instance_valid(threat) else -1.0]))
	var safe := await wait_until(func() -> bool: return fm.at_home, 30.0)
	check(safe and not fm.evading, "the farmer reaches the village safely")
	threat.take_damage(1e9)
	await wait(1.0)

	# --- rebuild the ruin ----------------------------------------------------------------
	var ruin: Hut = game.world.huts().filter(func(h: Hut) -> bool: return h.ruined)[0]
	game.economy.add("materials", 100)
	if civs("builder").is_empty():
		game.population.spawn("builder")
	check(game.construction.order_rebuild(ruin), "rebuild ordered on the ruined lot")
	var rebuilt := await wait_until(func() -> bool: return ruin.is_intact(), 90.0)
	check(rebuilt and game.population.cap() == huts0, "builder rebuilds the hut")

	# --- two explorers split up -------------------------------------------------------------
	game.economy.add("food", 500)
	var e2: Explorer = game.population.recruit("explorer")
	check(e2 != null, "explorer recruited with food")
	while civs("explorer").size() < 2:  # raids may have killed the first one
		if game.population.spawn("explorer") == null:
			break
	var ex := civs("explorer")
	await wait_until(func() -> bool: return ex.all(func(e: Explorer) -> bool: return e.state == Explorer.State.EXPLORING), 30.0)
	if ex.size() >= 2 and ex[0].target != Vector2i(-1, -1) and ex[1].target != Vector2i(-1, -1):
		check(Vector2(ex[0].target).distance_to(Vector2(ex[1].target)) >= Config.EXPLORER_CLAIM_RADIUS * 0.5, "explorers head for different fog (%s vs %s)" % [ex[0].target, ex[1].target])
	else:
		check(false, "both explorers are exploring: %s" % str(ex.map(func(e: Explorer) -> String: return "%s/%s/%s" % [e.state, e.target, e.dead])))

	# --- population cap ----------------------------------------------------------------------
	while game.population.count() < game.population.cap():
		if game.population.recruit("farmer") == null:
			break
	check(game.population.count() == game.population.cap(), "recruited up to the hut cap")
	check(game.population.recruit_error("builder") != "", "recruiting is blocked at the cap")
	game.economy.add("gold", 1000)
	game.population.kill_random(1)
	check(game.population.recruit_error("spatial_archmage") != "", "the Spatial Archmage cannot be recruited (only promoted)")
	check(game.population.recruit("farmer") != null, "a freed hut place can be filled again")

	# --- starvation ----------------------------------------------------------------------------
	for f in game.world.buildings.filter(func(b: Building) -> bool: return b is Farm):
		game.population.unassign_farmer(f)
	game.corpses.clear_wave(99)  # gathered corpses would bring in food
	await wait(8.0)  # let any farmer already carrying food get home
	var pop1 := game.population.count()
	game.economy.consume_food(100000.0)
	await wait(Config.STARVATION_INTERVAL + 2.0)
	check(game.population.count() < pop1, "a villager starves when food runs out")

	# --- UI texts talk about enemies, not goblins -------------------------------------------
	var texts := ""
	for b in game.world.buildings:
		var inf: Dictionary = b.info()
		texts += " ".join(inf["lines"]) + " "
	for role in Config.CIVILIANS:
		texts += Config.CIVILIANS[role]["desc"] + " "
	for kind in Config.MILITARY:
		texts += Config.MILITARY[kind]["desc"] + " "
	check(not "oblin" in texts, "building panels and descriptions say enemies, not goblins")

	# --- cancelling construction refunds ---------------------------------------------------------
	game.economy.add("materials", 100)
	var mat_c := game.economy.amount("materials")
	var cspot := find_spot("tower", game.player_village.center + Vector2i(6, 0))
	var csite := game.construction.place("tower", cspot)
	if csite:
		game.construction.cancel(csite)
		await frames(2)
		check(game.economy.amount("materials") == mat_c and map.building_at(cspot) == null, "cancelling a construction site refunds it and frees the tile")

	# --- the hero ------------------------------------------------------------------------------
	await _test_hero(far_spot)

	# --- fog switches (Config.REVEAL_MAP / DISABLE_FOG) ---------------------------------------
	game.fog.reveal_all()
	await wait(0.5)
	check(game.fog.explored_count() == map.size * map.size and game.fog.watched_count() < map.size * map.size, "REVEAL_MAP explores everything but unwatched land stays dark")
	game.fog.set_disabled(true)
	await frames(2)
	check(game.fog.explored_count() == map.size * map.size and game.fog.watched_count() == map.size * map.size, "without fog the whole map is explored and visible")
	game.fog.set_disabled(false)

	# --- the UI went through commands ------------------------------------------------------
	var seen_cmds := {}
	for c in cmd_log:
		if c[2]:
			seen_cmds[c[0]] = true
	var want_cmds := ["place_building", "buy_materials", "recruit_unit", "station_unit", "move_unit", "withdraw_unit", "call_wave", "set_speed", "hero_mode"]
	check(want_cmds.all(func(t: String) -> bool: return seen_cmds.has(t)), "taps and drags in the UI were applied as commands (missing: %s)" % str(want_cmds.filter(func(t: String) -> bool: return not seen_cmds.has(t))))
	check(pvil.update_fallen() == false and pvil.is_standing(), "the village still stands before the defeat test")

	# --- entity registry: freed things drop out ---------------------------------------------
	game.waves._spawn({"kind": "goblin", "spawn": map.edge_spawns[0], "hp_scale": 1.0})
	var gone: Enemy = get_tree().get_nodes_in_group("enemies").back()
	var gone_id := gone.nid
	var had: bool = game.entity(gone_id) == gone
	gone.take_damage(1e9)
	await wait(1.0)
	game.waves.countdown = 99999.0
	check(had and game.entity(gone_id) == null and not game._entities.has(gone_id), "a dead enemy leaves the entity registry")
	var stale := game._entities.values().filter(func(o) -> bool: return o is Object and not is_instance_valid(o)).size()
	check(stale == 0, "after the whole run the registry holds no freed entities (%d entries)" % game._entities.size())

	# --- the event log saw everything ------------------------------------------------------
	var expect := {
		EventLog.Level.DEBUG: ["recruit archer", "recruit farmer", "assign forester", "unassign forester", "place watchtower", "starts work on", "send archer", "takes up its post on",
			"withdraw archer", "is back in the reserve", "level-up archer", "drag archer", "move archer", "select ", "killed goblin", "killed skeleton", "appears at", "left behind",
			"collected corpse", "corpses home", "cut down tree", "building material at", "food home", "summoned elemental", "crumbles", "casts a spell at", "bewitched by",
			"fights elemental", "the hero attacks", "hero mode: ", "flees home", "heads for the fog", "buy 10 building material", "game speed", "open settings", "log level", "rotted away", "order upgrade of", "cancel construction", "broke through the gate"],
		EventLog.Level.INFO: ["Wave 1 begins", "Wave 1 is over", "watchtower 1 finished", "upgraded to level 2", "The hero returns", "fully trained to level 2", "rebuilt"],
		EventLog.Level.IMPORTANT: ["destroyed by goblin", "destroyed by ork", "died when", "died of starvation", "The hero was struck down"],
	}
	var missing: Array[String] = []
	for level in expect:
		for part in expect[level]:
			if not logged(part, level):
				missing.append("%s: %s" % [EventLog.LEVEL_NAMES[level], part])
	check(missing.is_empty(), "the log has entries for every kind of action and event (%d logged) %s" % [history.size(), str(missing)])

	# --- defeat -------------------------------------------------------------------------------
	game.population.kill_random(game.population.count())
	await frames(2)
	check(game.game_over and hud._overlay.visible, "losing every villager ends the game")
	check(game.player_village.fallen and not game.command("recruit_unit", {"kind": "archer"})["ok"], "the village has fallen, and no more commands are taken")
	check(hud._overlay_button.is_visible_in_tree() and hud._overlay_menu_button.is_visible_in_tree(), "defeat screen offers Try again and Main menu")
	await frames(2)
	var panel_rect: Rect2 = (hud._overlay_button.get_parent().get_parent() as Control).get_global_rect()
	var vp_center := get_viewport().get_visible_rect().size / 2.0
	check(panel_rect.get_center().distance_to(vp_center) < 4.0 and hud._overlay.get_global_rect().size == get_viewport().get_visible_rect().size, "defeat screen is centred and covers the whole screen (%s vs %s)" % [panel_rect.get_center(), vp_center])

	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures.size() > 0 else 0)


## The hero: defend, downed and revival, villager jobs, training grounds.
func _test_hero(far: Vector2i) -> void:
	var map := game.map
	var hero := game.hero
	game.economy.add("food", 500)  # (this part is about the hero, not about food)
	var hud := game.hud
	var cs := game.corpses
	for t in game.world.towers():
		if t.garrison:
			game.army.unstation(t.garrison)  # the hero should do the fighting
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
	bench_hero(false)
	game.waves.countdown = 99999.0
	var military_xp0 := {}
	for u in game.army.units:
		military_xp0[u] = [u.level, u.train_xp]

	# Defend: goes out to an enemy near a gate, fights it, gains XP; it fights back.
	var gate: Vector2i = open_gate()
	var brute := spawn_dummy("goblin", Vector2(outside_gate(gate, 3)), 1000.0, far)
	var went_out := await wait_until(func() -> bool: return hero.target == brute and not hero.at_home, 5.0)
	check(went_out, "Defend: the hero goes out to an enemy approaching a gate")
	var hp_b := brute.hp
	var fought := await wait_until(func() -> bool: return brute.hp < hp_b and hero.hp < hero.max_hp, 40.0)
	check(fought, "the hero fights it with his sword, and it fights back")
	check(hero.xp > 0 and hud._hero_button.text == "XP %d" % hero.xp, "each hit earns the hero XP, shown in the top bar (XP %d)" % hero.xp)
	var xp_fight := hero.xp
	# Re-targeting: nearest first, then the strongest.
	var weak := spawn_dummy("goblin", hero.grid_pos + Vector2(1.5, 0.0), 1.0, far)
	var strong := spawn_dummy("ork", hero.grid_pos + Vector2(0.0, 1.5), 1.0, far)
	brute.take_damage(1e9)
	await wait(0.8)
	check(hero.target == strong or (is_instance_valid(weak) and weak.dead), "after a kill he picks the nearest enemy, the strongest among equals")
	for e in [weak, strong]:
		if is_instance_valid(e):
			e.take_damage(1e9)
	game.waves.countdown = 99999.0
	# He walks back (no teleport), and picks up a new threat on the way.
	var after_fight := hero.grid_pos
	await frames(3)
	check(not hero.at_home and hero.grid_pos.distance_to(after_fight) < 0.5 and hero.grid_pos.distance_to(Vector2(game.player_village.center)) > 1.0, "after the last kill the hero walks back instead of teleporting")
	await wait(0.6)
	var on_way := hero.grid_pos
	check(not hero.at_home and on_way.distance_to(Vector2(game.player_village.center)) < after_fight.distance_to(Vector2(game.player_village.center)), "...heading for the village centre")
	var late := spawn_dummy("goblin", hero.grid_pos + Vector2(1.5, 0.5), 50.0, far)
	var retargeted := await wait_until(func() -> bool: return hero.target == late, 3.0)
	check(retargeted, "on the way home he turns on a new threat nearby")
	late.take_damage(1e9)
	game.waves.countdown = 99999.0
	var walk := {"ok": true, "last": hero.grid_pos}  # (lambdas capture locals by value)
	var home := await wait_until(func() -> bool:
		walk["ok"] = walk["ok"] and hero.grid_pos.distance_to(walk["last"]) < 1.0
		walk["last"] = hero.grid_pos
		return hero.at_home, 40.0)
	check(walk["ok"], "the whole way back is walked, never jumped")
	# Resting in the centre brings his HP back, slowly and only up to the max.
	hero.hp = hero.max_hp * 0.5
	var hp_low := hero.hp
	await wait(Config.HERO["rest_delay"] * 0.5)
	check(is_equal_approx(hero.hp, hp_low), "no healing in the first %.0f s of idling" % Config.HERO["rest_delay"])
	await wait(Config.HERO["rest_delay"] + 4.0)
	var gained := hero.hp - hp_low
	check(gained > 0.0 and gained <= Config.HERO["rest_regen"] * (Config.HERO["rest_delay"] + 4.5), "idle in the village centre he slowly gets HP back (+%.1f)" % gained)
	hero.hp = hero.max_hp - 0.3
	await wait(2.0)
	check(is_equal_approx(hero.hp, hero.max_hp) and logged("the hero is fully rested", EventLog.Level.DEBUG), "healing stops at his max HP")
	# Rest mode: back to the centre, no fighting, heals there.
	hero.set_mode(Hero.Mode.EXPLORE)
	await wait_until(func() -> bool: return not hero.at_home and hero.grid_pos.distance_to(Vector2(game.player_village.center)) > 4.0, 60.0)
	hero.hp = hero.max_hp * 0.6
	hero.set_mode(Hero.Mode.REST)
	var rest_walk := {"ok": true, "last": hero.grid_pos}
	var rested := await wait_until(func() -> bool:
		rest_walk["ok"] = rest_walk["ok"] and hero.grid_pos.distance_to(rest_walk["last"]) < 1.0
		rest_walk["last"] = hero.grid_pos
		return hero.at_home, 60.0)
	check(rested and rest_walk["ok"] and hero.jobs[Hero.Mode.EXPLORE].target == Vector2i(-1, -1), "Rest: the hero drops his job and walks back to the centre")
	var near := spawn_dummy("goblin", Vector2(outside_gate(gate, 2)), 50.0, far)
	await wait(2.0)
	check(hero.target == null and hero.at_home and near.hp == near.max_hp, "Rest: he ignores enemies near the gate")
	near.take_damage(1e9)
	game.waves.countdown = 99999.0
	var hp_r := hero.hp
	await wait(Config.HERO["rest_delay"] + 2.0)
	check(hero.hp > hp_r and "resting" in hero.status(), "Rest: he heals in the centre (%s)" % hero.status())
	hero.set_mode(Hero.Mode.DEFEND)
	check(home and hero.grid_pos.distance_to(Vector2(game.player_village.center)) < 0.2, "with no enemy about he returns to the centre")

	# Downed: XP lost, no corpse, back at the end of the wave, same mode.
	hero.set_mode(Hero.Mode.GATHER)
	var corpses0 := cs.count()
	hero.take_damage(1e9)
	await frames(2)
	check(hero.dead and not hero.visible and hero.xp == 0 and cs.count() == corpses0, "a downed hero loses all XP, vanishes and leaves no corpse")
	check(not game.workers().has(hero) and not hero.is_in_group("melee_defenders"), "a downed hero neither works nor fights")
	check(hud._hero_button.modulate != Color.WHITE and "downed" in hero.status(), "the HUD shows the hero is down")
	game.waves.wave_finished.emit(game.waves.wave)
	await frames(2)
	check(not hero.dead and hero.visible and is_equal_approx(hero.hp, hero.max_hp) and hero.grid_pos.distance_to(Vector2(game.player_village.center)) < 0.1, "he revives in the village centre when the wave is over")
	check(hero.mode == Hero.Mode.GATHER, "his mode survives being downed")
	game.waves.countdown = 99999.0

	# Gather: brings corpses home like a gatherer, a little fewer at a time.
	for g in civs("gatherer"):
		game.population.kill(g)
	var pile: Vector2i = outside_gate(gate, 2)
	for i in 4:
		cs.spawn("goblin", 3, Vector2(pile))
	var gold_g := game.economy.amount("gold")
	var max_carried := 0
	var t_run := 0.0
	var gj: GatherJob = hero.jobs[Hero.Mode.GATHER]
	while t_run < 90.0 and not (gj.state == GatherJob.State.RESTING and max_carried > 0):
		await get_tree().process_frame
		t_run += get_process_delta_time()
		max_carried = maxi(max_carried, gj.carried.size())
	check(max_carried == Config.HERO["gather_capacity"] and game.economy.amount("gold") > gold_g, "Gather: the hero brings %d corpses home for gold" % max_carried)
	check(hero.xp >= max_carried, "each corpse earns him XP (XP %d)" % hero.xp)
	cs.clear_wave(99)

	# Explore: reveals fog, each step that uncovers land earns XP. (Here without
	# treasures or claims to go for first; the priorities: tests/world_bot.gd.)
	for o in game.world.map_objects:
		if o is Treasure:
			(o as Treasure).looted = true
		elif o is RuinedTower:
			o.village = game.villages[0]
		elif o is UnlockSite:
			(o as UnlockSite).used = true
	hero.set_mode(Hero.Mode.EXPLORE)
	var xp_e := hero.xp
	var ex0 := game.fog.explored_count()
	var explored := await wait_until(func() -> bool: return game.fog.explored_count() > ex0 + 10 and hero.xp > xp_e, 90.0)
	check(explored, "Explore: the hero uncovers fog and earns XP (+%d tiles)" % (game.fog.explored_count() - ex0))
	check(not civs("explorer").any(func(e: Explorer) -> bool: return e.target != Vector2i(-1, -1) and Vector2(e.target).distance_to(Vector2(hero.exploring_target())) < 1.0), "explorers don't head for the hero's patch of fog")

	# Build: works on sites like a builder (at half speed) even with no builder left.
	for b in civs("builder"):
		game.population.kill(b)
	hero.set_mode(Hero.Mode.BUILD)
	game.economy.add("materials", 500)
	game.economy.add("gold", 500)
	var spot := find_spot("training", game.player_village.center + Vector2i(0, 7))
	var m0 := game.economy.amount("materials")
	var g0 := game.economy.amount("gold")
	var grounds: TrainingGrounds = game.construction.place("training", spot)
	check(grounds != null and grounds is TrainingGrounds, "training grounds placed")
	if grounds == null:
		return
	var cost: Dictionary = Config.BUILDINGS["training"]["cost"]
	check(game.economy.amount("materials") == m0 - cost["materials"] and game.economy.amount("gold") == g0 - cost["gold"], "training grounds cost %d materials and %d gold" % [cost["materials"], cost["gold"]])
	check(grounds.tiles().size() == 4 and grounds.tiles().all(func(t: Vector2i) -> bool: return map.building_at(t) == grounds), "training grounds take 2x2 tiles")
	var xp_b := hero.xp
	var building := await wait_until(func() -> bool: return hero.jobs[Hero.Mode.BUILD].site == grounds and grounds.progress > 0.0, 60.0)
	check(building, "Build: the hero builds with no builder around")
	var built := await wait_until(func() -> bool: return grounds.complete, 120.0)
	check(built and hero.xp > xp_b, "he finishes the training grounds and earns XP while building (+%d)" % (hero.xp - xp_b))

	# Train without a unit there: he defends instead, and drops the fight once a unit is ready.
	hero.set_mode(Hero.Mode.TRAIN)
	await frames(2)
	check(hero.effective_mode() == Hero.Mode.DEFEND and "defending" in hero.status(), "Train with no unit at the grounds: the hero defends")
	hud._hero_panel.visible = true
	hud._refresh_hero()
	check("No unit ready" in hud._hero_train_label.text and not hud._hero_train_bar.visible, "the panel says no unit is ready")
	var foe := spawn_dummy("goblin", Vector2(outside_gate(gate, 3)), 1000.0, far)
	await wait_until(func() -> bool: return hero.target == foe, 10.0)
	var archer := game.army.recruit("archer")
	check(archer != null and game.army.station(archer, grounds), "an archer is sent to the training grounds")
	var arrived := await wait_until(func() -> bool: return grounds.garrison == archer and archer.state == MilitaryUnit.State.STATIONED, 60.0)
	check(arrived and grounds.is_ready_for_training(), "the archer takes the grounds' unit slot")
	var dropped := await wait_until(func() -> bool: return hero.target == null and hero.training_at == grounds, 3.0)
	check(dropped, "as soon as a unit is ready he abandons the fight and heads for the grounds")
	foe.take_damage(1e9)
	game.waves.countdown = 99999.0

	# Training: XP moves from the hero to the unit, which levels up without gold.
	var need0 := archer.train_xp_needed()
	check(is_equal_approx(need0, Config.MILITARY["archer"]["train_xp"][0]), "level 2 needs %d XP on normal" % int(need0))
	hero.xp = int(need0) + 25
	var gold_t := game.economy.amount("gold")
	var at := await wait_until(func() -> bool: return hero.training_at == grounds and hero.grid_pos.distance_to(Vector2(grounds.work_tile())) < 0.3, 60.0)
	check(at, "the hero walks to the training grounds")
	var partial := await wait_until(func() -> bool: return archer.train_xp > 0.0, 10.0)
	hud._refresh_hero()
	check(partial and "XP needed" in hud._hero_train_label.text and hud._hero_train_bar.visible and hud._hero_train_bar.value > 0.0, "the panel shows XP needed, XP he has and the progress (%s)" % hud._hero_train_label.text)
	check("Training to level 2" in " ".join(grounds.info()["lines"]), "the grounds' panel shows the unit's training progress")
	var leveled := await wait_until(func() -> bool: return archer.level == 1, 60.0)
	check(leveled and game.economy.amount("gold") == gold_t, "the archer reaches level 2 by training, without gold")
	check(hero.xp == 25 and archer.train_xp == 0.0, "exactly the XP needed was passed on (hero has %d left)" % hero.xp)
	check(archer.train_xp_needed() > need0, "the next level needs more XP (%d > %d)" % [int(archer.train_xp_needed()), int(need0)])
	Settings.difficulty = Settings.Difficulty.HARD
	var need_hard := archer.train_xp_needed()
	Settings.difficulty = Settings.Difficulty.EASY
	var need_easy := archer.train_xp_needed()
	Settings.difficulty = Settings.Difficulty.NORMAL
	check(need_hard > archer.train_xp_needed() and need_easy < archer.train_xp_needed(), "XP needed grows with difficulty (easy %d, normal %d, hard %d)" % [int(need_easy), int(archer.train_xp_needed()), int(need_hard)])
	hero.xp = 0
	await wait(1.0)
	check("no XP left" in hero.status() and hero.training_at == grounds, "with no XP left he waits at the grounds")
	while archer.can_train():
		archer.level += 1
	await wait(0.5)
	check(not grounds.is_ready_for_training() and hero.effective_mode() == Hero.Mode.DEFEND, "a fully trained unit frees the hero to defend")
	var others_ok := true
	for u in military_xp0:
		if is_instance_valid(u) and u != archer:
			others_ok = others_ok and u.level == military_xp0[u][0] and u.train_xp == military_xp0[u][1]
	check(others_ok, "other military units gain no XP from fighting")
	game.army.unstation(archer)
	hero.set_mode(Hero.Mode.DEFEND)
	hud._hero_panel.visible = false
	await wait_until(func() -> bool: return game.army.walking().is_empty(), 60.0)
