class_name Game
extends Node2D
## Composition root: creates the world and systems, routes player input
## (select / build / station), and resolves enemy raids and defeat.

enum Mode { NONE, BUILD, STATION }

const HERO_SCRIPT := preload("res://scripts/units/hero.gd")

@export var map_seed := 0  # 0 = random every game
## Debug switches, defaulting to config.gd (tests may override before _ready).
var reveal_map := Config.REVEAL_MAP
var disable_fog := Config.DISABLE_FOG

var mode := Mode.NONE
var build_kind := ""
var station_unit: MilitaryUnit = null
var selected: Building = null
## A stationed military unit selected by tapping it on its post.
var selected_unit: MilitaryUnit = null
## Stationed unit being pressed / dragged off its post:
## {"unit", "from" (post), "start" (screen pos), "active" (dragging yet)}.
var _udrag: Dictionary = {}
const DRAG_THRESHOLD := 12.0
var hero: Hero
var game_over := false
var map: MapData:
	get: return world.map
var fog: FogLayer:
	get: return world.fog

var _info_timer := 0.0
## Game event log (HUD log field). Created first so every system can log.
var events: EventLog
## Per-kind counters behind the numbers in labels ("farmer 3", "goblin 4").
var _ids: Dictionary = {}

@onready var camera: CameraController = $Camera
@onready var world: World = $World
@onready var economy: Economy = $Systems/Economy
@onready var population: Population = $Systems/Population
@onready var construction: Construction = $Systems/Construction
@onready var army: Army = $Systems/Army
@onready var waves: Waves = $Systems/Waves
@onready var corpses: Corpses = $Systems/Corpses
@onready var hud: Hud = $HUD


func _ready() -> void:
	events = EventLog.new()
	events.name = "Events"
	$Systems.add_child(events)
	var s := map_seed if map_seed != 0 else randi()
	economy.setup(Config.START_RESOURCES)
	world.setup(self, s)
	construction.setup(self)
	construction.build_starting()  # before the villagers, who then go to work there
	population.setup(self)
	army.setup(self)
	waves.setup(self)
	corpses.setup(self)
	hero = HERO_SCRIPT.new()
	hero.setup_hero(self)
	world.objects.add_child(hero)
	hud.setup(self)

	camera.process_mode = Node.PROCESS_MODE_ALWAYS  # pan and zoom while paused
	camera.bounds = world.world_rect().grow(-200.0)
	camera.focus(Iso.tile_to_world(Config.VILLAGE_CENTER))
	camera.zoom = Vector2(0.75, 0.75)
	camera.tapped.connect(_on_tapped)
	camera.press_filter = _claim_press
	camera.hovered.connect(_on_hovered)
	camera.cancelled.connect(cancel_mode)
	population.civilian_lost.connect(func(_c: Civilian) -> void: _check_defeat())


func _process(delta: float) -> void:
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = 0.25
		if selected_unit != null:
			if selected_unit.state == MilitaryUnit.State.STATIONED and is_instance_valid(selected_unit.post):
				hud.show_info(unit_info(selected_unit))
			else:
				deselect()  # it left its post
		elif selected != null:
			if is_instance_valid(selected) and selected.is_inside_tree():
				hud.show_info(selected.info())
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
	hud.set_mode_hint("Tap explored grass to place a %s" % Config.BUILDINGS[kind]["name"])


func begin_station(unit: MilitaryUnit) -> void:
	if game_over:
		return
	deselect()
	mode = Mode.STATION
	station_unit = unit
	build_kind = ""
	hud.set_mode_hint("Tap a finished tower or training grounds to station the %s" % unit.display_name().to_lower())
	_highlight_towers()


func cancel_mode() -> void:
	mode = Mode.NONE
	build_kind = ""
	station_unit = null
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
	else:
		world.overlay.show_selection(b.tiles())
	hud.show_info(b.info())
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
			_try_place(tile)
		Mode.STATION:
			var t := world.pick_building(world_pos)
			var err := army.station_error(station_unit, t as MilitaryPost)
			if err == "" and army.station(station_unit, t):
				cancel_mode()
				select(t)
				hud.toast("The %s is marching out" % station_unit_name(t), Color("c9a24a"))
			else:
				hud.toast(err, Color("ff9a8a"))
		_:
			var b := world.pick_building(world_pos)
			if b == selected:
				deselect()
			else:
				select(b)


func _on_hovered(world_pos: Vector2) -> void:
	if mode == Mode.BUILD:
		_preview(Iso.to_tile(world_pos))


func _try_place(tile: Vector2i) -> void:
	var err := construction.placement_error(build_kind, tile)
	if err != "":
		_preview(tile)
		hud.toast(err, Color("ff9a8a"))
		return
	construction.place(build_kind, tile)
	_preview(tile)
	if not economy.can_afford(Config.BUILDINGS[build_kind]["cost"]):
		cancel_mode()


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
	else:
		world.overlay.show_selection(p.tiles())
	events.debug("select %s on %s" % [unit.label(), p.label()])
	hud.show_info(unit_info(unit))
	_info_timer = 0.25


func unit_info(unit: MilitaryUnit) -> Dictionary:
	var lines: Array[String] = ["Level %d, on %s" % [unit.level + 1, unit.post.display_name()]]
	lines.append_array(unit.behavior.info_lines(unit))
	lines.append("Drag it onto another tower to move it there, or onto the %s to withdraw it." % ("panel below" if Layout.portrait else "sidebar"))
	var actions: Array[Dictionary] = []
	if unit.can_upgrade():
		actions.append({
			"label": "Upgrade  (%s)" % Config.cost_text(unit.upgrade_cost()),
			"disabled": not economy.can_afford(unit.upgrade_cost()),
			"action": func() -> void: army.upgrade(unit),
		})
	actions.append({"label": "Withdraw", "action": func() -> void:
		army.unstation(unit)
		deselect()})
	return {"title": unit.display_name(), "lines": lines, "actions": actions}


## Camera hook: a press on a stationed unit's figure starts a (possible) drag.
func _claim_press(screen_pos: Vector2) -> bool:
	if mode != Mode.NONE or game_over:
		return false
	var post := world.pick_unit(camera.screen_to_world(screen_pos))
	if post == null:
		return false
	_udrag = {"unit": post.garrison, "from": post, "start": screen_pos, "active": false}
	return true


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
			(_udrag["from"] as MilitaryPost).set_unit_ghosted(true)
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
		army.unstation(unit)
		deselect()
		return
	var target := drop_target(unit, screen_pos)
	if target != null:
		events.debug("drag %s from %s to %s" % [unit.label(), from.label(), target.label()])
		army.transfer(unit, target)
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
	var err := army.station_error(unit, t as MilitaryPost)
	if err == "":
		events.debug("drag %s from the reserve to %s" % [unit.label(), t.label()])
	if err == "" and army.station(unit, t):
		select(t)
		hud.toast("The %s is marching out" % station_unit_name(t), Color("c9a24a"))
		return true
	hud.toast(err, Color("ff9a8a"))
	return false


func station_unit_name(t: MilitaryPost) -> String:
	return t.incoming.display_name().to_lower() if t.incoming else "unit"


# --- raids and defeat -----------------------------------------------------------------

func on_enemy_reached_gate(g: Enemy) -> void:
	if game_over:
		return
	# Exactly one random hut per enemy, on every difficulty. Only a villager who
	# happens to live in that hut dies; nobody else is killed.
	events.debug("%s broke through the gate" % g.label())
	var intact := world.intact_huts()
	if not intact.is_empty():
		(intact.pick_random() as Hut).destroy(g.label())
	Sfx.play("raid")
	hud.toast("Enemies broke into the village!", Color("ff7a6a"))
	population.changed.emit()
	_check_defeat()


func _check_defeat() -> void:
	if game_over:
		return
	var no_people := population.count() == 0
	var no_huts := world.intact_huts().is_empty()
	if not (no_people or no_huts):
		return
	game_over = true
	cancel_mode()
	Engine.time_scale = 1.0
	Sfx.play("lose", 0.0)
	var why := "No villagers are left." if no_people else "Every hut lies in ruins."
	events.important("Veliron's outpost has fallen: %s" % why.to_lower().trim_suffix("."))
	hud.show_game_over("Veliron's outpost has fallen", "%s\nYou held out for %d wave%s." % [why, maxi(waves.wave - 1, 0), "" if waves.wave == 2 else "s"])


func go_to_title() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


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
	if n.has_method("label"):
		return n.label()
	return str(n.name)


## Everyone who can take on villager jobs: villagers plus the hero.
func workers() -> Array[Civilian]:
	var out: Array[Civilian] = population.civilians.duplicate()
	if is_instance_valid(hero) and not hero.dead:
		out.append(hero)
	return out


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
