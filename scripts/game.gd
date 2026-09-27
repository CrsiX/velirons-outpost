class_name Game
extends Node2D
## Composition root: creates the world and systems, routes player input
## (select / build / station), and resolves goblin raids and defeat.

enum Mode { NONE, BUILD, STATION }

@export var map_seed := 0  # 0 = random every game

var mode := Mode.NONE
var build_kind := ""
var station_unit: MilitaryUnit = null
var selected: Building = null
var game_over := false
var map: MapData:
	get: return world.map
var fog: FogLayer:
	get: return world.fog

var _info_timer := 0.0

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
	var s := map_seed if map_seed != 0 else randi()
	economy.setup(Config.START_RESOURCES)
	world.setup(self, s)
	population.setup(self)
	construction.setup(self)
	army.setup(self)
	waves.setup(self)
	corpses.setup(self)
	hud.setup(self)

	camera.process_mode = Node.PROCESS_MODE_ALWAYS  # pan and zoom while paused
	camera.bounds = world.world_rect().grow(-200.0)
	camera.focus(Iso.tile_to_world(Config.VILLAGE_CENTER))
	camera.zoom = Vector2(0.75, 0.75)
	camera.tapped.connect(_on_tapped)
	camera.hovered.connect(_on_hovered)
	camera.cancelled.connect(cancel_mode)
	population.civilian_lost.connect(func(_c: Civilian) -> void: _check_defeat())


func _process(delta: float) -> void:
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = 0.25
		if selected != null:
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
	hud.set_mode_hint("Tap a finished tower to station the %s" % unit.display_name().to_lower())
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
	selected = b
	if b == null:
		deselect()
		return
	if b is Tower and b.complete:
		world.overlay.show_selection(b.tiles(), Vector2(b.tile), b.range_tiles())
	else:
		world.overlay.show_selection(b.tiles())
	hud.show_info(b.info())
	_info_timer = 0.25


func deselect() -> void:
	selected = null
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
			var err := army.station_error(station_unit, t as Tower)
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
	var tiles: Array[Vector2i] = []
	var r := size / 2
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			tiles.append(tile + Vector2i(dx, dy))
	var art: String = Config.BUILDINGS[build_kind]["art"]
	var rng := Config.TOWER_RANGE.get(build_kind, 0.0) as float
	if build_kind == "lightstone":
		rng = Config.LIGHTSTONE_SIGHT
	world.overlay.show_ghost(art, Iso.tile_to_world(tile), tiles, ok, Vector2(tile), rng)


func _highlight_towers() -> void:
	var tiles: Array[Vector2i] = []
	for t in world.towers():
		if t.complete:
			tiles.append(t.tile)
	world.overlay.show_selection(tiles)


## Drop from the HUD's reserve card at a screen position (drag & drop).
func drop_unit(unit: MilitaryUnit, screen_pos: Vector2) -> bool:
	var t := world.pick_building(camera.screen_to_world(screen_pos))
	var err := army.station_error(unit, t as Tower)
	if err == "" and army.station(unit, t):
		select(t)
		hud.toast("The %s is marching out" % station_unit_name(t), Color("c9a24a"))
		return true
	hud.toast(err, Color("ff9a8a"))
	return false


func station_unit_name(t: Tower) -> String:
	return t.incoming.display_name().to_lower() if t.incoming else "unit"


# --- raids and defeat -----------------------------------------------------------------

func on_goblin_reached_gate(g: Goblin) -> void:
	if game_over:
		return
	var intact := world.intact_huts()
	intact.shuffle()
	for i in mini(g.demolition, intact.size()):
		(intact[i] as Hut).destroy()
	population.kill_random(g.demolition)
	population.enforce_cap()
	Sfx.play("raid")
	hud.toast("Goblins broke into the village!", Color("ff7a6a"))
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
	hud.show_game_over("Veliron's outpost has fallen", "%s\nYou held out for %d wave%s." % [why, maxi(waves.wave - 1, 0), "" if waves.wave == 2 else "s"])


func go_to_title() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
