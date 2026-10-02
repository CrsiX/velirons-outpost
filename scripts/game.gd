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
## Debug switches, defaulting to config.gd (tests may override before _ready).
var reveal_map := Config.REVEAL_MAP
var disable_fog := Config.DISABLE_FOG
## Villages on this device (1 = single player; more = hot-seat co-op test mode).
var hotseat_villages := Config.HOTSEAT_VILLAGES
## Co-op client: the host simulates; this game only shows what it sends.
var is_client := false
## Co-op (host or client): keeps clients in step (see Replicator).
var replicator: Replicator
## Networked game (host or client), not hot-seat.
var networked := false
## The guided tutorial runs in this game (single player; tests may set it
## before _ready, the title screen asks via Settings.tutorial_next).
var tutorial_mode := false
var tutorial: Tutorial = null
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


func _ready() -> void:
	tutorial_mode = (Settings.take_tutorial() or tutorial_mode) and not (Net.in_game and Net.is_online()) and hotseat_villages <= 1
	if tutorial_mode:
		tutorial = Tutorial.new()
		tutorial.name = "Tutorial"
		tutorial.prepare(self)  # (the map, the difficulty and the small village)
	var s := map_seed if map_seed != 0 else (Settings.map_seed if Settings.map_seed != 0 else randi())
	if map_seed == 0:
		map_type = Settings.resolve_map_type(Settings.map_type, s)
	commands = Commands.new()
	commands.name = "Commands"
	commands.setup(self)
	$Systems.add_child(commands)
	# Co-op over the network: the lobby decided the villages (Net.setup).
	networked = Net.in_game and Net.is_online()
	is_client = networked and Net.is_client()
	var names: Array = []
	var colors: Array = []
	if networked:
		for pv in Net.setup["villages"]:
			names.append(pv["name"])
			colors.append(Config.VILLAGE_COLORS[int(pv["color"])])
		s = int(Net.setup.get("seed", s))
		map_type = str(Net.setup.get("map_type", map_type))
		reveal_map = bool(Net.setup.get("reveal_map", reveal_map))
		disable_fog = bool(Net.setup.get("disable_fog", disable_fog))
	else:
		for i in clampi(hotseat_villages, 1, Config.MAX_PLAYERS):
			names.append(Config.VILLAGE_NAMES[i])
			colors.append(Config.VILLAGE_COLORS[i])
	# Villages first (empty), so the world can hand them their buildings.
	for i in names.size():
		var v: Village = VILLAGE_SCRIPT.new()
		v.create(self, i, names[i], colors[i])
		$Systems.add_child(v)
		villages.append(v)
	player_village = villages[int(Net.setup.get("local", 0)) if networked else 0]
	world.setup(self, s)
	fog.local = player_village.id
	for village in villages:
		village.apply_map(map.villages[village.id])
	waves.setup(self)
	corpses.setup(self)
	for village in villages:
		if is_client:
			village.setup_client()
		else:
			village.setup()
			village.population.civilian_lost.connect(func(_c: Civilian) -> void: _check_defeat())
	hud.setup(self)
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

	camera.process_mode = Node.PROCESS_MODE_ALWAYS  # pan and zoom while paused
	camera.bounds = world.world_rect().grow(-200.0)
	camera.focus(Iso.tile_to_world(player_village.center))
	camera.zoom = Vector2(0.75, 0.75)
	camera.tapped.connect(_on_tapped)
	camera.press_filter = _claim_press
	camera.hovered.connect(_on_hovered)
	camera.cancelled.connect(cancel_mode)


func _process(delta: float) -> void:
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
		if t.complete:
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
	lines.append("Drag it onto another tower or barracks to move it there, or onto the %s to withdraw it." % ("panel below" if Layout.portrait else "sidebar"))
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
## withdraw it). Anywhere else nothing happens.
func _drop_stationed(unit: MilitaryUnit, screen_pos: Vector2) -> void:
	var from: MilitaryPost = _udrag["from"]
	if hud.is_over_dock(screen_pos):
		events.debug("drag %s from %s to the reserve (withdraw)" % [unit.label(), from.label()])
		command("withdraw_unit", {"unit": unit.nid})
		deselect()
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


## While dragging `unit`: mark every post it could go to, the one under the
## pointer, and (for a stationed unit) an arrow from its post to the pointer.
func preview_drag(unit: MilitaryUnit, screen_pos: Vector2) -> void:
	var targets: Array[Vector2i] = []
	for p in world.military_posts():
		if _drop_error(unit, p) == "":
			targets.append_array(p.tiles())
	var hover: Array[Vector2i] = []
	var t := drop_target(unit, screen_pos)
	if t:
		hover = t.tiles()
	var stationed := unit.state == MilitaryUnit.State.STATIONED
	var from := unit.post.position + Vector2(0, -40) if stationed else Vector2.ZERO
	world.overlay.show_drag(targets, hover, from, camera.screen_to_world(screen_pos), stationed)
	var tex := Art.tex("unit_" + unit.kind)
	var state := "move" if t else ("withdraw" if stationed and hud.is_over_dock(screen_pos) else "none")
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

## A thief at a gate steals max(a random whole number from wave to 2 x
## wave, steal_share of the gold), never more than the village has.
## Returns the amount (it carries it away, see ThiefBehavior).
func thief_steals(g: Enemy) -> int:
	var v: Village = g.target_village if is_instance_valid(g.target_village) else player_village
	var gold := int(v.economy.amount("gold"))
	var w := maxi(1, waves.wave)
	var n := maxi(maxi(randi_range(w, 2 * w), roundi(gold * float(g.spec()["steal_share"]))), 0)
	n = mini(n, gold)
	v.economy.add("gold", -n)
	v.events.info("%s got into the village and stole %d gold" % [g.label().capitalize(), n])
	v.toast("A thief stole %d gold!" % n, Color("ffb07a"))
	return n


func on_enemy_reached_gate(g: Enemy) -> void:
	if game_over:
		return
	# Exactly one random hut of the village it attacked, on every difficulty.
	# Only a villager who happens to live in that hut dies; nobody else is killed.
	var v: Village = g.target_village if is_instance_valid(g.target_village) else player_village
	if g.kind == "rat":
		# Rats burn nothing: they eat food and are gone.
		var spec: Dictionary = g.spec()
		var eat := maxi(int(spec["gate_eat"]), roundi(v.economy.amount("food") * float(spec["gate_eat_share"])))
		eat = mini(eat, int(v.economy.amount("food")))
		v.economy.add("food", -eat)
		v.events.info("%s got into the village and ate %d food" % [g.label().capitalize(), eat])
		v.toast("A rat ate %d food!" % eat, Color("ffb07a"))
		return
	v.events.debug("%s broke through the gate" % g.label())
	var intact := v.intact_huts()
	if not intact.is_empty():
		(intact.pick_random() as Hut).destroy(g.label())
	if v.is_local():
		Sfx.play("raid")
	v.toast("Enemies broke into the village!", Color("ff7a6a"))
	v.population.changed.emit()
	_check_defeat()


## A village falls with no villagers or no intact huts; the game is lost when
## every village has fallen.
func _check_defeat() -> void:
	if game_over:
		return
	for v in villages:
		if v.update_fallen() and villages.size() > 1:
			if v.fallen:
				log_all(EventLog.Level.IMPORTANT, "%s has fallen" % v.village_name)
				_reroute_from(v)
			else:
				log_all(EventLog.Level.INFO, "%s stands again" % v.village_name)
			world.refresh_village_labels()
	if not villages.all(func(v: Village) -> bool: return v.fallen):
		return
	var no_people := population.count() == 0
	game_over = true
	cancel_mode()
	Engine.time_scale = 1.0
	Sfx.play("lose", 0.0)
	var why := "No villagers are left." if no_people else "Every hut lies in ruins."
	events.important("Veliron's outpost has fallen: %s" % why.to_lower().trim_suffix("."))
	hud.show_game_over("Veliron's outpost has fallen", "%s\nYou held out for %d wave%s." % [why, maxi(waves.wave - 1, 0), "" if waves.wave == 2 else "s"])


func go_to_title() -> void:
	if Net.is_online():
		Net.leave()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(Net.TITLE_SCENE)


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
	return villages[0]


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
	var d := b.info()
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


## Hot-seat test mode: the device's player takes over the next village (or `v`).
func switch_village(v: Village = null) -> void:
	if v == null:
		v = villages[(player_village.id + 1) % villages.size()]
	cancel_mode()
	player_village = v
	fog.set_local(v.id)
	world.refresh_props()
	camera.focus(Iso.tile_to_world(v.center))
	hud.bind_village(v)
	world.refresh_village_labels()


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


## `again_tutorial`: start the guided tutorial again.
func restart(again_tutorial := false) -> void:
	Settings.tutorial_next = again_tutorial
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
