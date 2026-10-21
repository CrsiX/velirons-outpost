class_name Game
extends Node2D
## Composition root: creates the world, the shared systems (waves, corpses)
## and the villages, routes player input (select / build / station), and
## resolves enemy raids and defeat.
##
## Per-player state lives in Village nodes (economy, population, construction,
## army, hero, event log). `economy`, `population`, ... below are shortcuts to
## the local player's village, for the HUD and input handling; game logic uses
## the owning village of whatever it works on.

enum Mode { NONE, BUILD, STATION }

signal speed_changed(index: int)

## Game speeds the speed button cycles through; 0 = paused.
const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 0.0]

const VILLAGE_SCRIPT := preload("res://scripts/systems/village.gd")

## Map type (Config.MAP_TYPES) and seed; 0 = random seed.
@export var map_seed := 0  # 0 = random every game
var map_type := "temperate"
## No fog of war at all (every tile explored and watched): only for the
## title backdrop and tests, set before _ready; never in a game anyone plays.
var disable_fog := false
## Tests only: this many villages in one game without a network (co-op rules,
## played as village 0). Players get several villages only through LAN co-op.
var test_villages := 1
## Co-op client: the host simulates; this game only shows what it sends.
var is_client := false
## Seconds of game time since this game began (stops while paused, runs with the
## game speed). Timed effects (a war cry's haste) end at a clock time.
var clock := 0.0
## Co-op (host or client): keeps clients in step (see Replicator).
var replicator: Replicator
## Networked game (host or client).
var networked := false
## The guided tutorial runs in this game (single player; tests may set it
## before _ready, the title screen asks via Settings.tutorial_next).
var tutorial_mode := false
var tutorial: Tutorial = null
## The campaign's scenario this game plays (Campaign; 0: none). Tests may set
## it before _ready, the title screen asks via Settings.scenario_next.
var scenario_number := 0
## Plays that scenario (docs/scenarios-design.md), or null.
var scenario: ScenarioRunner = null
## The title screen's background game plays in this game (set before _ready):
## its scene's map and setup, no input, no HUD, no sound, no raids, no defeat.
var backdrop: TitleBackdrop = null
## A map made beforehand (the backdrop's baked maps): used instead of generating one.
var preset_map: MapData = null
## This game's id (docs/save-design.md): kept through saves and loads, it
## names the game's autosave.
var game_id := ""
## While a loaded game is being built: the save's body (SaveGame). Empty otherwise.
var restoring: Dictionary = {}
## This game was loaded from a save (or resumed in the lobby).
var loaded := false
var _slice_from := 0
## How the villages start (Config.START_*; the tutorial's: Config.TUTORIAL).
var start_resources: Dictionary = Config.START_RESOURCES.duplicate()
var start_civilians: Array[String] = Config.START_CIVILIANS.duplicate()
var start_buildings: Array[String] = Config.START_BUILDINGS.duplicate()

var mode := Mode.NONE
var build_kind := ""
## Touch: the tile the building to place is shown on, waiting for Build (NO_TILE: none yet).
var pending_tile := NO_TILE
## A Build entry is being dragged onto the map.
var build_drag := false
var station_unit: MilitaryUnit = null
var selected: Building = null
## A stationed military unit selected by tapping it on its post.
var selected_unit: MilitaryUnit = null
## Stationed unit being pressed / dragged off its post:
## {"unit", "from" (post), "start" (screen pos), "active" (dragging yet)}.
var _udrag: Dictionary = {}
const DRAG_THRESHOLD := 12.0
const NO_TILE := Vector2i(-1, -1)
## Dragging a building with a finger, it shows this far above it (px).
const DRAG_LIFT := 70.0
var game_over := false
## Every village in the game (one in single player).
var villages: Array[Village] = []
## The village the person at this device plays.
var player_village: Village
var economy: Economy:
	get: return player_village.economy
var population: Population:
	get: return player_village.population
var construction: Construction:
	get: return player_village.construction
var army: Army:
	get: return player_village.army
var hero: Hero:
	get: return player_village.hero
## The local player's event log (HUD log field).
var events: EventLog:
	get: return player_village.events
var map: MapData:
	get: return world.map
var fog: FogLayer:
	get: return world.fog

var _info_timer := 0.0
## All player actions go through here (see Commands and command()).
var commands: Commands
## Index into SPEEDS (set by the host only, see apply_speed).
var speed_index := 0
## Entities commands can name: id -> Building / MilitaryUnit (see register).
var _entities: Dictionary = {}
var _next_nid := 1
## Per-kind counters behind the numbers in labels ("farmer 3", "goblin 4").
var _ids: Dictionary = {}

@onready var camera: CameraController = $Camera
@onready var world: World = $World
@onready var waves: Waves = $Systems/Waves
@onready var corpses: Corpses = $Systems/Corpses
@onready var hud: Hud = $HUD
## The in-game statistics (docs/statistics-design.md).
var stats: Stats
## Enemies breaking into villages (docs/siege-design.md).
var siege: Siege
## Trees waking up as wrathwoods (docs/enemies-design.md §15c).
var wrathwoods: Wrathwoods


func _ready() -> void:
	tutorial_mode = backdrop == null and (Settings.take_tutorial() or tutorial_mode) and not (Net.in_game and Net.is_online()) and test_villages <= 1
	if tutorial_mode:
		tutorial = Tutorial.new()
		tutorial.name = "Tutorial"
		tutorial.prepare(self)  # (the map, the difficulty and the small village)
	var asked := Settings.take_scenario()
	if backdrop == null and not tutorial_mode and not (Net.in_game and Net.is_online()) and test_villages <= 1:
		scenario_number = asked if asked > 0 else scenario_number
		var spec := Campaign.scenario(scenario_number)
		if spec:
			scenario = ScenarioRunner.new()
			scenario.name = "Scenario"
			scenario.prepare(self, spec)  # (its map, village and enemy strength)
			add_child(scenario)
	if scenario == null:
		scenario_number = 0
	if backdrop:
		backdrop.prepare(self)  # (its scene's map and village)
	var s := map_seed if map_seed != 0 else (Settings.map_seed if Settings.map_seed != 0 else randi())
	if map_seed == 0:
		map_type = Settings.resolve_map_type(Settings.map_type, s)
	commands = Commands.new()
	commands.name = "Commands"
	commands.setup(self)
	$Systems.add_child(commands)
	# Co-op over the network: the lobby decided the villages (Net.setup).
	networked = Net.in_game and Net.is_online() and backdrop == null
	is_client = networked and Net.is_client()
	game_id = "%08x%08x" % [randi(), randi()]
	if backdrop == null and not tutorial_mode and scenario == null and not is_client:
		restoring = Net.resume_body if networked else Settings.take_pending_save()
	if not restoring.is_empty():
		loaded = true
		var g: Dictionary = restoring["game"]
		game_id = str(g["game_id"])
		Settings.difficulty = int(g["difficulty"]) as Settings.Difficulty
		preset_map = SaveGame.saved_map(restoring)
		map_type = preset_map.map_type
		map_seed = preset_map.seed_value
		s = map_seed
	var names: Array = []
	var colors: Array = []
	if not restoring.is_empty() and not networked:
		for sv: Dictionary in restoring["villages"]:
			names.append(sv["name"])
			colors.append(Color(str(sv["color"])))
	elif networked:
		for pv in Net.setup["villages"]:
			names.append(pv["name"])
			colors.append(Config.VILLAGE_COLORS[int(pv["color"])])
		if restoring.is_empty():
			s = int(Net.setup.get("seed", s))
			map_type = str(Net.setup.get("map_type", map_type))
	else:
		for i in clampi(test_villages, 1, Config.MAX_PLAYERS):
			names.append(Config.VILLAGE_NAMES[i])
			colors.append(Config.VILLAGE_COLORS[i])
	# Villages first (empty), so the world can hand them their buildings.
	for i in names.size():
		var v: Village = VILLAGE_SCRIPT.new()
		v.create(self, i, names[i], colors[i])
		$Systems.add_child(v)
		villages.append(v)
	player_village = villages[int(Net.setup.get("local", 0)) if networked else 0]
	stats = Stats.new()
	stats.name = "Stats"
	stats.setup(self)
	$Systems.add_child(stats)
	siege = Siege.new()
	siege.name = "Siege"
	siege.setup(self)
	$Systems.add_child(siege)
	wrathwoods = Wrathwoods.new()
	wrathwoods.name = "Wrathwoods"
	wrathwoods.setup(self)
	$Systems.add_child(wrathwoods)
	_slice_from = Time.get_ticks_usec()
	_use_custom_map()
	if backdrop:
		hud.visible = false
	await world.setup(self, s)
	if not restoring.is_empty():
		SaveGame.restore_world(self, restoring)
	# What world.setup explored for this village (co-op client: not village 0)
	# becomes the drawn fog, and the trees and objects follow it.
	fog.set_local(player_village.id)
	world.refresh_props()
	for village in villages:
		village.apply_map(map.villages[village.id])
	waves.setup(self)
	waves.wave_started.connect(func(_n: int) -> void: siege.on_wave_started())
	corpses.setup(self)
	await build_step()
	if scenario:
		scenario.apply_baseline()  # (ruins, before the villagers move in)
	for village in villages:
		if is_client:
			village.setup_client()
			continue
		if loaded:
			village.setup_restored()
		else:
			village.setup()
		village.population.civilian_lost.connect(func(_c: Civilian) -> void: _check_defeat())
	if loaded:
		SaveGame.restore_entities(self, restoring)
		stats.load_state(restoring["stats"])
		_log_loaded(restoring["villages"], waves.wave)
		restoring = {}
	elif is_client and bool(Net.setup.get("resumed", false)) and not Net.resume.is_empty():  # (not when rejoining later)
		_log_loaded(Net.resume.get("villages", []), int(Net.resume.get("wave", 0)))
	else:
		stats.start()
	waves.wave_finished.connect(func(_n: int) -> void: _autosave.call_deferred())
	await build_step()
	await hud.setup(self)
	if networked:
		replicator = Replicator.new()
		replicator.name = "Replicator"
		replicator.setup(self, not is_client)
		add_child(replicator)
		Net.session_ended.connect(_on_session_ended)
		Net.command_refused.connect(func(_t: String, err: String) -> void: hud.toast(err, UiTheme.BAD))
		if is_client:
			Net.client_game_ready(self)
		else:
			Net.host_game_ready(self)

	if tutorial:
		add_child(tutorial)
		tutorial.start()
	if scenario:
		scenario.start()

	camera.process_mode = Node.PROCESS_MODE_ALWAYS  # pan and zoom while paused
	camera.bounds = world.world_rect().grow(-200.0)
	camera.focus(Iso.tile_to_world(player_village.center))
	camera.zoom = Vector2(0.75, 0.75)
	camera.tapped.connect(_on_tapped)
	camera.press_filter = _claim_press
	camera.wheel_filter = func(screen_pos: Vector2) -> bool: return hud != null and hud.is_over_dock(screen_pos)
	camera.hovered.connect(_on_hovered)
	camera.cancelled.connect(cancel_mode)
	if backdrop:
		await build_step(true)  # (the last first draws, before it shows)
		backdrop.start(self)


## A map from a file (docs/map-editor-design.md §8): single player plays
## Settings.custom_map's chosen village; a co-op host the map picked in the
## lobby, each player on the village assigned to them (clients get the host's
## map). The other villages are built as ownerless ruins.
func _use_custom_map() -> void:
	if backdrop or tutorial_mode or scenario or is_client or preset_map != null:
		return
	if networked:
		if Net.custom_map == null:
			return
		var played: Array = []
		for pv in Net.setup["villages"]:
			played.append(int(pv.get("slot", played.size())))
		preset_map = Net.custom_map.for_game(played)
	elif Settings.custom_map != null and test_villages <= 1:
		preset_map = Settings.custom_map.for_game([clampi(Settings.custom_village, 0, Settings.custom_map.villages.size() - 1)])
	if preset_map:
		map_type = preset_map.map_type
		map_seed = preset_map.seed_value


## The title backdrop builds its game over several frames, so the menu over it
## stays responsive: once the current frame has spent
## Config.TITLE_BACKDROP["build_slice"] seconds on it (or with `force`), this
## waits for the next frame. Any other game is made at once (it returns
## straight away).
func build_step(force := false) -> void:
	if backdrop == null:
		return
	if not force and Time.get_ticks_usec() - _slice_from < int(float(Config.TITLE_BACKDROP["build_slice"]) * 1000000.0):
		return
	await get_tree().process_frame
	_slice_from = Time.get_ticks_usec()


func _process(delta: float) -> void:
	clock += delta
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = 0.25
		if villages.size() > 1 and not is_client:
			_check_defeat()  # co-op: villages fall and rise again at any time
		if selected_unit != null:
			if selected_unit.state == MilitaryUnit.State.STATIONED and is_instance_valid(selected_unit.post):
				hud.show_info(unit_info(selected_unit))
			else:
				deselect()  # it left its post
		elif selected != null:
			if is_instance_valid(selected) and selected.is_inside_tree():
				hud.show_info(building_info(selected))
			else:
				deselect()


# --- modes ------------------------------------------------------------------------

func begin_build(kind: String) -> void:
	if game_over:
		return
	deselect()
	mode = Mode.BUILD
	build_kind = kind
	station_unit = null
	pending_tile = NO_TILE
	hud.hide_place_confirm()
	hud.set_mode_hint("Tap explored grass to place a %s" % Config.BUILDINGS[kind]["name"])
	get_tree().quit_on_go_back = false  # (Android's back button cancels instead)


## The Build entry: picks `kind`, or (picked already) puts it away again.
func toggle_build(kind: String) -> void:
	if mode == Mode.BUILD and build_kind == kind:
		cancel_mode()
	else:
		begin_build(kind)


func begin_station(unit: MilitaryUnit) -> void:
	if game_over:
		return
	deselect()
	mode = Mode.STATION
	station_unit = unit
	build_kind = ""
	hud.set_mode_hint("Tap a finished tower or training grounds to station the %s" % unit.display_name().to_lower())
	_highlight_towers()
	get_tree().quit_on_go_back = false


func cancel_mode() -> void:
	mode = Mode.NONE
	build_kind = ""
	station_unit = null
	pending_tile = NO_TILE
	build_drag = false
	hud.hide_place_confirm()
	get_tree().quit_on_go_back = true
	world.overlay.clear()
	hud.set_mode_hint("")
	deselect()


# --- selection ----------------------------------------------------------------------

func select(b: Building) -> void:
	selected_unit = null
	selected = b
	if b == null:
		deselect()
		return
	events.debug("select %s" % b.label())
	if b is Tower and b.complete:
		world.overlay.show_selection(b.tiles(), Vector2(b.tile), b.range_tiles())
	elif b is Barracks and b.complete:
		world.overlay.show_selection(b.tiles(), b.act_center(), b.activation_range())
	else:
		world.overlay.show_selection(b.tiles())
	hud.show_info(building_info(b))
	_info_timer = 0.25


func deselect() -> void:
	selected = null
	selected_unit = null
	if mode == Mode.NONE:
		world.overlay.clear()
	hud.hide_info()


# --- input from the camera ---------------------------------------------------------

func _on_tapped(world_pos: Vector2) -> void:
	if game_over:
		return
	var tile := Iso.to_tile(world_pos)
	match mode:
		Mode.BUILD:
			if Layout.touch:
				_touch_place(tile)
			else:
				_try_place(tile)
		Mode.STATION:
			var t := world.pick_building(world_pos)
			var r := command("station_unit", {"unit": id_of(station_unit), "post": id_of(t)})
			if r["ok"]:
				cancel_mode()
				select(t)
				hud.toast("The %s is marching out" % station_unit_name(t), Color("c9a24a"))
			else:
				hud.toast(r["error"], Color("ff9a8a"))
		_:
			var b := world.pick_building(world_pos)
			if b == selected:
				deselect()
			else:
				select(b)


func _on_hovered(world_pos: Vector2) -> void:
	if mode == Mode.BUILD and not build_drag and not Layout.touch:
		_preview(Iso.to_tile(world_pos))


func _try_place(tile: Vector2i) -> bool:
	var r := command("place_building", {"kind": build_kind, "tile": tile})
	_preview(tile)
	if not r["ok"]:
		hud.toast(r["error"], Color("ff9a8a"))
		return false
	cancel_mode()  # (one building per pick: no stray second one with the next tap)
	return true


## Touch (no hover to see where it goes): the first tap shows the building
## there with Build / Cancel beside it; a tap on that building, or Build,
## places it; a tap elsewhere moves it.
func _touch_place(tile: Vector2i) -> void:
	if pending_tile != NO_TILE and tile in Building.footprint(pending_tile, Config.BUILDINGS[build_kind]["size"]):
		confirm_place()
	else:
		show_pending(tile)


func show_pending(tile: Vector2i) -> void:
	pending_tile = tile
	_preview(tile)
	var err := construction.placement_error(build_kind, tile)
	hud.show_place_confirm(err)
	hud.set_mode_hint(err if err != "" else "Tap Build (or the %s) to build it here, or tap elsewhere to move it" % Config.BUILDINGS[build_kind]["name"].to_lower())


## The Build button beside the previewed building.
func confirm_place() -> void:
	if mode == Mode.BUILD and pending_tile != NO_TILE:
		_try_place(pending_tile)


## Where the previewed building stands on screen (Build / Cancel go below it).
func pending_screen_pos() -> Vector2:
	var size: int = Config.BUILDINGS[build_kind]["size"]
	return camera.world_to_screen(Building.anchor_world(pending_tile, size))


# --- dragging a building from the Build tab -------------------------------------------

## Over the map while a Build entry is dragged: the building shows where it
## would go. A finger hides what's under it, so then it goes a bit above.
func drag_build_tile(screen_pos: Vector2) -> Vector2i:
	var lift := Vector2(0, -DRAG_LIFT) if Layout.touch else Vector2.ZERO
	return Iso.to_tile(camera.screen_to_world(screen_pos + lift))


func drag_build(kind: String, screen_pos: Vector2) -> void:
	if mode != Mode.BUILD or build_kind != kind:
		begin_build(kind)
	build_drag = true
	pending_tile = NO_TILE
	hud.hide_place_confirm()
	_preview(drag_build_tile(screen_pos))


## Let go: built there; over the HUD: put away. Can't be built there: it
## stays picked (on touch shown there with Build / Cancel, to move it).
func drop_build(screen_pos: Vector2) -> void:
	if mode != Mode.BUILD:
		return
	build_drag = false
	if hud.is_over_ui(screen_pos):
		cancel_mode()
		return
	var tile := drag_build_tile(screen_pos)
	if not _try_place(tile) and Layout.touch:
		show_pending(tile)


func _preview(tile: Vector2i) -> void:
	var ok := construction.placement_error(build_kind, tile) == ""
	var size: int = Config.BUILDINGS[build_kind]["size"]
	var tiles := Building.footprint(tile, size)
	var art: String = Config.BUILDINGS[build_kind]["art"]
	var rng := Config.TOWER_RANGE.get(build_kind, 0.0) as float
	if build_kind == "lightstone":
		rng = Config.LIGHTSTONE_SIGHT
	world.overlay.show_ghost(art, Building.anchor_world(tile, size), tiles, ok, Vector2(tile), rng)


func _highlight_towers() -> void:
	var tiles: Array[Vector2i] = []
	for t in world.military_posts():
		if t.complete and not t.has_meta("abandoned"):
			tiles.append_array(t.tiles())
	world.overlay.show_selection(tiles)


# --- stationed units: select, drag & drop -------------------------------------------

## A stationed unit, selected by tapping its figure on the tower.
func select_unit(unit: MilitaryUnit) -> void:
	deselect()
	selected_unit = unit
	var p := unit.post
	if p is Tower:
		world.overlay.show_selection(p.tiles(), Vector2(p.tile), (p as Tower).range_tiles())
	elif p is Barracks:
		world.overlay.show_selection(p.tiles(), (p as Barracks).act_center(), (p as Barracks).activation_range())
	else:
		world.overlay.show_selection(p.tiles())
	events.debug("select %s on %s" % [unit.label(), p.label()])
	hud.show_info(unit_info(unit))
	_info_timer = 0.25


func unit_info(unit: MilitaryUnit) -> Dictionary:
	var lines: Array[String] = ["Level %d, on %s" % [unit.level + 1, unit.post.display_name()]]
	if not (unit.post is Tower):
		lines.append("{hp} %d / %d" % [ceili(unit.hp), ceili(unit.max_hp())])
	lines.append_array(unit.behavior.info_lines(unit))
	lines.append("Drag it onto another tower or barracks to move it there, onto another unit to swap places, or onto the %s to withdraw it." % ("panel below" if Layout.portrait else "sidebar"))
	var actions: Array[Dictionary] = []
	if not unit.upgrade_options().is_empty():
		actions.append({"label": "Upgrade...", "action": func() -> void: hud.open_upgrade(unit)})
	actions.append({"label": "Withdraw", "action": func() -> void:
		command("withdraw_unit", {"unit": unit.nid})
		deselect()})
	return {"title": unit.display_name(), "lines": lines, "actions": actions}


## Camera hook: a press on a stationed unit's figure starts a (possible) drag.
func _claim_press(screen_pos: Vector2) -> bool:
	if mode != Mode.NONE or game_over:
		return false
	var u := world.pick_unit(camera.screen_to_world(screen_pos))
	if u == null:
		return false
	_udrag = {"unit": u, "from": u.post, "start": screen_pos, "active": false}
	return true


## Android's back button while placing or stationing: cancels it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and mode != Mode.NONE:
		cancel_mode()


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true


func _input(event: InputEvent) -> void:
	if _udrag.is_empty():
		return
	var unit: MilitaryUnit = _udrag["unit"]
	if unit.state != MilitaryUnit.State.STATIONED:
		_end_unit_drag()  # it was withdrawn meanwhile
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		if not _udrag["active"] and pos.distance_to(_udrag["start"]) > DRAG_THRESHOLD:
			_udrag["active"] = true
			(_udrag["from"] as MilitaryPost).set_unit_ghosted(true, unit)
		if _udrag["active"]:
			preview_drag(unit, pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _udrag["active"]:
			_drop_stationed(unit, event.position)
		else:
			select_unit(unit)  # a tap
		_end_unit_drag()


func _end_unit_drag() -> void:
	if is_instance_valid(_udrag.get("from")):
		(_udrag["from"] as MilitaryPost).set_unit_ghosted(false)
	_udrag = {}
	end_drag_preview()


## Moves the dragged unit if it was dropped on a free post (or the dock, to
## withdraw it), or swaps it with the unit it was dropped on. Anywhere else
## nothing happens.
func _drop_stationed(unit: MilitaryUnit, screen_pos: Vector2) -> void:
	var from: MilitaryPost = _udrag["from"]
	if hud.is_over_dock(screen_pos):
		events.debug("drag %s from %s to the reserve (withdraw)" % [unit.label(), from.label()])
		command("withdraw_unit", {"unit": unit.nid})
		deselect()
		return
	var partner := swap_partner(unit, screen_pos)
	if partner != null:
		events.debug("drag %s from %s onto %s on %s (swap)" % [unit.label(), from.label(), partner.label(), partner.post.label()])
		command("swap_units", {"unit": unit.nid, "other": partner.nid})
		deselect()
		hud.toast("The %s and the %s swap places" % [unit.display_name().to_lower(), partner.display_name().to_lower()], Color("c9a24a"))
		return
	var target := drop_target(unit, screen_pos)
	if target != null:
		events.debug("drag %s from %s to %s" % [unit.label(), from.label(), target.label()])
		command("move_unit", {"unit": unit.nid, "post": target.nid})
		select(target)
		hud.toast("The %s is on the move" % unit.display_name().to_lower(), Color("c9a24a"))
	else:
		events.debug("drag %s from %s dropped on nothing: stays put" % [unit.label(), from.label()])


## The post under `screen_pos` that `unit` could go to right now, or null.
## Works for reserve units (station) and stationed ones (transfer).
func drop_target(unit: MilitaryUnit, screen_pos: Vector2) -> MilitaryPost:
	if hud.is_over_ui(screen_pos):
		return null
	var p := world.pick_building(camera.screen_to_world(screen_pos)) as MilitaryPost
	if p == null:
		return null
	return p if _drop_error(unit, p) == "" else null


func _drop_error(unit: MilitaryUnit, p: MilitaryPost) -> String:
	return army.transfer_error(unit, p) if unit.state == MilitaryUnit.State.STATIONED else army.station_error(unit, p)


## The stationed unit that the stationed `unit`, dropped at `screen_pos`,
## would swap posts with, or null: the one whose figure is under the pointer;
## else, on a post under the pointer with no free slot for `unit`, the one
## there whose figure is nearest the pointer.
func swap_partner(unit: MilitaryUnit, screen_pos: Vector2) -> MilitaryUnit:
	if unit.state != MilitaryUnit.State.STATIONED or hud.is_over_ui(screen_pos):
		return null
	var wp := camera.screen_to_world(screen_pos)
	var b := world.pick_unit(wp)
	if b != null and b != unit and army.swap_error(unit, b) == "":
		return b
	var p := world.pick_building(wp) as MilitaryPost
	if p == null or p == unit.post or drop_target(unit, screen_pos) != null:
		return null
	var best: MilitaryUnit = null
	var best_d := INF
	for o in p.units():
		var r := p.unit_rect(o)
		if r.has_area() and army.swap_error(unit, o) == "":
			var d := (p.position + r.get_center()).distance_to(wp)
			if d < best_d:
				best = o
				best_d = d
	return best


## Where a stationed unit's figure is, in world coordinates.
func _figure_pos(unit: MilitaryUnit) -> Vector2:
	var r := unit.post.unit_rect(unit)
	return unit.post.position + (r.get_center() if r.has_area() else Vector2(0, -40))


## While dragging `unit`: mark every post it could go to (or swap with a unit
## on), the one under the pointer, and (for a stationed unit) an arrow from
## its post to the pointer, or two curved arrows back and forth when dropping
## it would swap it with the unit there.
func preview_drag(unit: MilitaryUnit, screen_pos: Vector2) -> void:
	var stationed := unit.state == MilitaryUnit.State.STATIONED
	var targets: Array[Vector2i] = []
	for p in world.military_posts():
		if _drop_error(unit, p) == "" or (stationed and p.units().any(func(o: MilitaryUnit) -> bool: return army.swap_error(unit, o) == "")):
			targets.append_array(p.tiles())
	var hover: Array[Vector2i] = []
	var partner := swap_partner(unit, screen_pos)
	var t := drop_target(unit, screen_pos) if partner == null else null
	if partner:
		hover = partner.post.tiles()
	elif t:
		hover = t.tiles()
	var from := _figure_pos(unit) if stationed else Vector2.ZERO
	var to := _figure_pos(partner) if partner else camera.screen_to_world(screen_pos)
	world.overlay.show_drag(targets, hover, from, to, stationed, partner != null)
	var tex := Art.tex("unit_" + unit.kind)
	var state := "swap" if partner else ("move" if t else ("withdraw" if stationed and hud.is_over_dock(screen_pos) else "none"))
	hud.show_drag_feedback(tex, screen_pos, state)


func end_drag_preview() -> void:
	world.overlay.clear_drag()
	hud.hide_drag_feedback()


## Drop from the HUD's reserve card at a screen position (drag & drop).
func drop_unit(unit: MilitaryUnit, screen_pos: Vector2) -> bool:
	var t := world.pick_building(camera.screen_to_world(screen_pos))
	if army.station_error(unit, t as MilitaryPost) == "":
		events.debug("drag %s from the reserve to %s" % [unit.label(), t.label()])
	var r := command("station_unit", {"unit": unit.nid, "post": id_of(t)})
	if r["ok"]:
		select(t)
		hud.toast("The %s is marching out" % station_unit_name(t), Color("c9a24a"))
		return true
	hud.toast(r["error"], Color("ff9a8a"))
	return false


func station_unit_name(t: MilitaryPost) -> String:
	return t.incoming.display_name().to_lower() if t.incoming else "unit"


# --- raids and defeat -----------------------------------------------------------------

## A thief at a gate (or, `store`, at the guild warehouse it plundered)
## steals max(a random whole number from wave to 2 x wave, steal_share of
## the gold), never more than the village has. Returns the amount (it
## carries it away, see ThiefBehavior).
func thief_steals(g: Enemy, store: Building = null) -> int:
	var v: Village = g.target_village if is_instance_valid(g.target_village) else player_village
	var gold := int(v.economy.amount("gold"))
	var w := maxi(1, waves.wave)
	var n := maxi(maxi(randi_range(w, 2 * w), roundi(gold * float(g.spec()["steal_share"]))), 0)
	n = mini(n, gold)
	v.economy.add("gold", -n)
	stats.count(v, "stolen", n)
	if store != null:
		v.events.info("%s ran off from %s with %d gold" % [g.label().capitalize(), store.label(), n])
	else:
		v.events.info("%s got into the village and stole %d gold" % [g.label().capitalize(), n])
	v.toast("A thief stole %d gold!" % n, Color("ffb07a"))
	return n


## Whether `g`, through a gate, burns a hut: always, or with its kind's
## raid_chance (the small slimes).
func raid_roll(g: Enemy) -> bool:
	return randf() < float(g.spec().get("raid_chance", 1.0))


func on_enemy_reached_gate(g: Enemy) -> void:
	if game_over or backdrop:
		return
	# Exactly one hut of the village it attacked, on every difficulty.
	# Only a villager who happens to live in that hut dies; nobody else is killed.
	var v: Village = g.target_village if is_instance_valid(g.target_village) else player_village
	stats.count(v, "gate")
	if g.kind == "rat":
		# Rats burn nothing: they eat food and are gone.
		var spec: Dictionary = g.spec()
		var eat := maxi(int(spec["gate_eat"]), roundi(v.economy.amount("food") * float(spec["gate_eat_share"])))
		eat = mini(eat, int(v.economy.amount("food")))
		v.economy.add("food", -eat)
		stats.count(v, "rat_food_gate", eat)
		v.events.info("%s got into the village and ate %d food" % [g.label().capitalize(), eat])
		v.toast("A rat ate %d food!" % eat, Color("ffb07a"))
		return
	if str(g.spec().get("raid", "")) == "maul":
		_maul(g, v)
		return
	if not raid_roll(g):
		v.events.debug("%s got into the village and %s" % [g.label().capitalize(), str(g.spec().get("gone", "melted away"))])
		return
	v.events.debug("%s broke into the village" % g.label())
	# The hut it got to (docs/siege-design.md §5.3); one at random if it came
	# in some other way.
	var hut := g.raid_hut
	if not is_instance_valid(hut) or not hut.is_intact() or hut.village != v:
		var intact := v.intact_huts()
		hut = null if intact.is_empty() else intact.pick_random() as Hut
	if hut != null:
		hut.destroy(g.label())
	if v.is_local():
		Sfx.play("raid")
	v.toast("Enemies broke into the village!", Color("ff7a6a"))
	v.population.changed.emit()
	_check_defeat()


## A wolf got in ("raid": "maul"; docs/enemies-design.md §15e): it kills the
## villager living in the hut it got to (or in the lived-in intact hut
## nearest it); the hut stands. Then it is gone.
func _maul(g: Enemy, v: Village) -> void:
	var hut := g.raid_hut
	if not (is_instance_valid(hut) and hut.is_intact() and hut.village == v and is_instance_valid(hut.resident)):
		hut = null
		var best := INF
		for b in v.intact_huts():
			var h := b as Hut
			var d := Vector2(h.tile).distance_to(g.grid_pos)
			if is_instance_valid(h.resident) and d < best:
				best = d
				hut = h
	if hut == null:
		v.events.info("%s got into the village and found nobody" % g.label().capitalize())
		return
	v.population.kill(hut.resident, "when %s got into their hut" % g.label(), "enemies")
	if v.is_local():
		Sfx.play("raid")
	v.toast("A wolf got into the village and killed a villager!", Color("ff7a6a"))
	_check_defeat()


## A village falls with no villagers or no intact huts; the game is lost when
## every village has fallen.
func _check_defeat() -> void:
	if game_over or backdrop:
		return
	for v in villages:
		if not v.update_fallen():
			continue
		if v.fallen:
			stats.on_village_fell(v)
		if villages.size() > 1:
			if v.fallen:
				log_all(EventLog.Level.IMPORTANT, "%s has fallen" % v.village_name)
				_reroute_from(v)
			else:
				log_all(EventLog.Level.INFO, "%s stands again" % v.village_name)
			world.refresh_village_labels()
	if not villages.all(func(v: Village) -> bool: return v.fallen):
		return
	var no_people := population.count() == 0
	var why := "No villagers are left." if no_people else "Every hut lies in ruins."
	events.important("Veliron's Outpost has fallen: %s" % why.to_lower().trim_suffix("."))
	if scenario:
		scenario.lose(why.trim_suffix("."))
		return
	end_game("Veliron's Outpost has fallen", "%s\nYou held out for %d wave%s." % [why, maxi(waves.wave - 1, 0), "" if waves.wave == 2 else "s"])


## The game is over: lost, or (a scenario) `won`. The overlay says `title`
## and `sub` and offers what comes next.
func end_game(title: String, sub: String, won := false) -> void:
	if game_over:
		return
	game_over = true
	cancel_mode()
	Engine.time_scale = 1.0
	Sfx.play("win" if won else "lose", 0.0)
	stats.finish()
	hud.show_game_over(title, sub, won)


## Back to the map editor whose Play started this game (its map and state wait in Settings.editor_session).
func go_to_editor() -> void:
	Settings.editor_play = false
	Settings.custom_map = null
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(TitleScreen.EDITOR_SCENE)


func go_to_title() -> void:
	if Net.is_online():
		Net.leave()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(Net.TITLE_SCENE)


## A won scenario's next step: the next scenario of the campaign (completed
## or not), or after the last one the title screen's campaign map.
func play_next_scenario() -> void:
	if Campaign.scenario(scenario_number + 1) == null:
		Settings.campaign_next = true
		go_to_title()
		return
	Settings.scenario_next = scenario_number + 1
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- commands, entity ids, speed ---------------------------------------------------------

## Runs a player action for the local player's village; see Commands for the
## types and arguments. Returns {"ok": bool, "error": String, ...}.
func command(type: String, args: Dictionary = {}) -> Dictionary:
	if is_client:
		Net.send_command(type, args)  # the host applies it; a refusal comes back as a toast
		return {"ok": true, "sent": true}
	return commands.submit(player_village, type, args)


## Gives `o` (a Building, unit, corpse or MilitaryUnit) an id that commands and
## the co-op Replicator use to refer to it.
func register(o) -> int:
	var id := _next_nid
	_next_nid += 1
	register_as(o, id)
	return id


## An id both sides know without being told (map objects: OBJECT_NID_BASE +
## their index in MapData.objects). Not replicated as an entity.
func register_fixed(o, id: int) -> void:
	_entities[id] = o


## Co-op client: `o` takes the id the host gave it.
func register_as(o, id: int) -> void:
	_entities[id] = o
	_next_nid = maxi(_next_nid, id + 1)
	if o is Node:
		var n := o as Node
		if not n.is_in_group("replicated"):
			n.add_to_group("replicated")
		# Freed nodes (dead enemies, collected corpses, ...) drop out of the registry,
		# so it doesn't grow all game long. (Only when freed, not when reparented,
		# and only if the id still means this node.)
		n.tree_exited.connect(func() -> void:
			if n.is_queued_for_deletion() and _entities.get(id) == n:
				_entities.erase(id))


## The person at this device controls the game speed (single player, or the co-op host).
func is_host_player() -> bool:
	return player_village == host_village() and not is_client


func _on_session_ended(reason: String) -> void:
	game_over = true
	hud.show_session_ended(reason)


func unregister(id: int) -> void:
	_entities.erase(id)


## The entity with id `id`, or null (unknown, or freed meanwhile).
func entity(id: int):
	var o = _entities.get(id)
	if o is Object and not is_instance_valid(o):
		return null
	return o


## Id to put into a command for `o` (0 = none).
func id_of(o) -> int:
	return o.nid if o != null and is_instance_valid(o) and "nid" in o else 0


## The village that controls the game speed (the host; single player: the only one).
func host_village() -> Village:
	return villages[clampi(int(Net.setup.get("host", 0)), 0, villages.size() - 1)] if networked else villages[0]


## Sets game speed SPEEDS[i] (0 = paused). Use the "set_speed" command.
func apply_speed(i: int) -> void:
	speed_index = i
	var speed := SPEEDS[i]
	get_tree().paused = speed == 0.0
	if speed > 0.0:
		Engine.time_scale = speed
	speed_changed.emit(i)


## A building's panel; another village's buildings can be looked at, not ordered.
func building_info(b: Building) -> Dictionary:
	if b.has_meta("abandoned"):  # (a village of the map nobody plays)
		var title := "Ruined Hut" if b is Hut else b.display_name()
		return {"title": title, "lines": ["An abandoned village: nobody lives here,", "and its ruins can't be rebuilt."], "actions": [] as Array[Dictionary]}
	var d := b.info()
	if not (b is Hut) and not b.tearing_down:
		var lines: Array[String] = d["lines"]
		var actions: Array[Dictionary] = d["actions"]
		b.add_hp_info(lines, actions)
	b.add_tear_down_action(d)
	if b.village and b.village != player_village:
		d["actions"] = [] as Array[Dictionary]
		(d["lines"] as Array).push_front("Belongs to %s." % b.village.village_name)
	return d


# --- unlocks (docs/world-design.md §9.4): global, for every village --------------------

## Unlocked unit kinds / villager roles (Config.LOCKED keys).
var unlocks: Dictionary = {}


func is_unlocked(key: String) -> bool:
	return not Config.LOCKED.has(key) or unlocks.has(key)


## Can the village have `key` (a unit kind or villager role) now: unlocked,
## and a scenario's rules allow it.
func available(key: String) -> bool:
	return is_unlocked(key) and (scenario == null or scenario.allows(key))


## Can `kind` be built (a scenario may allow only some buildings; the
## campaign's own kinds, the stall, only where a scenario lists them)?
func allows_building(kind: String) -> bool:
	if scenario == null:
		return not Config.BUILDINGS.get(kind, {}).get("campaign", false)
	return scenario.allows_building(kind)


## Can units specialise (a scenario may forbid it)?
func allows_branches() -> bool:
	return scenario == null or scenario.allows_branches()


## Unlocks `key` for everyone; `v` / `who` did it (for the log).
func unlock(key: String, v: Village = null, who: Node = null) -> void:
	if is_unlocked(key):
		return
	unlocks[key] = true
	var what: String = Config.MILITARY[key]["name"] if Config.MILITARY.has(key) else Config.CIVILIANS[key]["name"]
	var by := ""
	if v:
		by = "%s's %s" % [v.village_name, (who.label() if who else "people")] if villages.size() > 1 else (who.label().capitalize() if who else "Your people")
	if key == "miner":
		log_all(EventLog.Level.INFO, "%s reached a mine: every village can recruit miners now." % (by if by != "" else "Someone"))
	else:
		log_all(EventLog.Level.INFO, "%s unlocked the %s: every village can recruit it now." % [by if by != "" else "Someone", what.to_lower()])
	for vil in villages:
		vil.toast("%s unlocked!" % what, UiTheme.GOLD)
	world.on_unlocked(key)
	hud._queue_refresh()


## Next number for `key` (a kind or role), counting from 1 per game.
func next_id(key: String) -> int:
	_ids[key] = _ids.get(key, 0) + 1
	return _ids[key]


## Log name of whoever caused something: "archer 5 on watchtower 2",
## "elemental 3", "the hero", "goblin 4".
func who(n) -> String:
	if not is_instance_valid(n):
		return "something"
	if n is Tower:
		return "%s on %s" % [n.garrison.label(), n.label()] if n.garrison else n.label()
	if n is Soldier:
		return n.unit.label()
	if n.has_method("label"):
		return n.label()
	return str(n.name)


## The local player's workers: villagers plus the hero (see Village.workers).
func workers() -> Array[Civilian]:
	return player_village.workers()


## The village something belongs to (buildings, villagers, the hero, military
## units, elementals), or null for enemies, corpses and the like.
func village_of(n) -> Village:
	if n is MilitaryUnit:
		return n.village
	if not is_instance_valid(n):
		return null
	if n is Tower and n.garrison:
		return n.garrison.village
	var v = n.get("village")
	return v if v is Village else null


## The standing village whose centre is nearest to `t`, or null if all fell.
func nearest_standing_village(t: Vector2i) -> Village:
	var best: Village = null
	var best_d := INF
	for v in villages:
		var d := Vector2(t).distance_squared_to(Vector2(v.center))
		if not v.fallen and d < best_d:
			best_d = d
			best = v
	return best


## Enemies on their way to a village that just fell turn to the nearest standing one.
func _reroute_from(v: Village) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or e.target_village != v:
			continue
		if e.behavior is ThiefBehavior and (e.behavior as ThiefBehavior).escaping:
			continue  # (running off with its loot)
		var nv := nearest_standing_village(e.current_tile())
		if nv:
			e.retarget(nv, rng)


## Logs to every village (waves, enemies: things everyone may hear about).
func log_all(level: EventLog.Level, text: String) -> void:
	for v in villages:
		v.events.add(level, text)


## Logs to the village `about` belongs to, or to every village if none.
func log_for(about, level: EventLog.Level, text: String) -> void:
	var v := village_of(about)
	if v:
		v.events.add(level, text)
	else:
		log_all(level, text)


## `again_tutorial`: start the guided tutorial again. A scenario starts over.
func restart(again_tutorial := false) -> void:
	Settings.tutorial_next = again_tutorial
	Settings.scenario_next = scenario_number if scenario else 0
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- saving and loading (docs/save-design.md) ----------------------------------------------

## A loaded game says so in the log; a resumed co-op village that has a new
## player says that too (it takes the player's name and keeps its colour).
## (A co-op client says it too, from the save's header.)
func _log_loaded(saved: Array, wave: int) -> void:
	for v in villages:
		var old := str(saved[v.id]["name"]) if v.id < saved.size() else v.village_name
		if old != v.village_name:
			log_all(EventLog.Level.INFO, "Village %s is now played as %s" % [old, v.village_name])
	log_all(EventLog.Level.INFO, "Game loaded: wave %d" % wave)


## "" if the game can be saved now, else why not: only between waves, never
## in the tutorial, a scenario, the title backdrop or on a co-op client.
func save_error() -> String:
	if backdrop != null or tutorial_mode or scenario != null or is_client:
		return "This game can't be saved"
	if game_over:
		return "The game is over"
	if waves.in_progress():
		return "You can save between waves"
	return ""


## Saves the game under `save_name` (Save... in the settings); "" or why not.
func save_named(save_name: String) -> String:
	var err := save_error()
	if err == "":
		err = SaveGame.save_named(self, save_name)
	if err == "":
		events.debug("game saved as '%s'" % save_name)
		_tell_clients_saved()
	return err


## After each wave (on the next frame: the wave's last enemy is still going):
## the game's autosave. Not in the map editor's test game.
func _autosave() -> void:
	if save_error() != "" or Settings.editor_play or not is_inside_tree():
		return
	var err := SaveGame.autosave(self)
	if err != "":
		hud.toast("Couldn't autosave: %s" % err, UiTheme.BAD)
		return
	hud.toast("Autosaved", UiTheme.MUTED)
	_tell_clients_saved()


func _tell_clients_saved() -> void:
	if networked:
		for v in villages:
			if v != player_village:
				v.toast("The host saved the game", UiTheme.MUTED)


## Leaves this game and loads the save at `path` (single player); "" or why not.
func load_save(path: String) -> String:
	if networked:
		return "A co-op game is resumed from the lobby"
	return SaveGame.start(path, get_tree())
