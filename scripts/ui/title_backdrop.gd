class_name TitleBackdrop
extends TextureRect
## The title screen's background (Config.TITLE_BACKDROP): real games playing
## themselves behind the menu in slow motion, one scene after the other. Each
## scene is a fresh Game (Game.backdrop) on its own fixed map, with its posts
## ready and manned, enemies coming down its road in groups, and the camera
## drifting from one spot to another. Black until the first scene is made,
## then it fades in; between scenes it fades to black and back. The game
## renders into its own SubViewport (at the window's resolution), shown here;
## nothing passes input on to it, so the menu over it gets every key, click
## and touch. It plays no sound; leaving the title screen ends it.

signal scene_started(index: int)

## The game playing now (null while none is).
var game: Game = null
## Index into Config.TITLE_BACKDROP["scenes"] of the scene playing now.
var index := -1
## The scene playing now, with the defaults of Config.TITLE_BACKDROP filled in.
var scene: Dictionary = {}
## The scene's road, from its map-edge spawn to the gate.
var route: Array[Vector2i] = []
## Real seconds into the scene, and game seconds (its enemies' "at").
var clock := 0.0
var game_time := 0.0
var _viewport: SubViewport
var _order: Array[int] = []
## Per enemy group: game time it comes next (INF: done).
var _next_group: Array[float] = []
## Enemies of the groups still to show up: {"kind", "at", "from", "wave"}.
var _pending: Array[Dictionary] = []
var _cam_from := Vector2.ZERO
var _cam_to := Vector2.ZERO
var _leaving := false
var _fade: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	modulate = Color.BLACK
	_viewport = SubViewport.new()
	_viewport.name = "Viewport"
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size_2d_override_stretch = true
	add_child(_viewport)
	texture = _viewport.get_texture()
	resized.connect(_fit)
	_fit()
	var count: int = (Config.TITLE_BACKDROP["scenes"] as Array).size()
	for i in count:
		_order.append(i)
	if Config.TITLE_BACKDROP["shuffle"]:
		_order.shuffle()
	if count == 0:
		return
	# The menu shows first, over black; then the first scene is made.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and index < 0:
		_next_scene()


## The game sees the screen as the menu does (its UI size), drawn with
## every pixel of the window.
func _fit() -> void:
	var k := get_viewport().get_final_transform().get_scale().x if get_viewport() else 1.0
	var s := size.round()
	_viewport.size_2d_override = Vector2i(s)
	_viewport.size = Vector2i((s * maxf(k, 1.0)).round()).maxi(1)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Sfx.muted = false


## The default of Config.TITLE_BACKDROP, or the scene's own value.
func value(key: String):
	return scene.get(key, Config.TITLE_BACKDROP.get(key))


## Plays scene `i` now (tests; -1: the next one in the order).
func play(i: int) -> void:
	if _fade:
		_fade.kill()
	_next_scene(i)


func _next_scene(i := -1) -> void:
	if game:
		_viewport.remove_child(game)
		game.queue_free()
		game = null
	var scenes: Array = Config.TITLE_BACKDROP["scenes"]
	if i >= 0:
		index = i
	else:
		index = _order[(_order.find(index) + 1) % _order.size()] if index >= 0 else _order[0]
	scene = scenes[index]
	clock = 0.0
	game_time = 0.0
	_leaving = false
	_pending.clear()
	_next_group.clear()
	for grp: Dictionary in value("enemies"):
		_next_group.append(float(grp.get("at", 0.0)))
	Sfx.muted = true
	Engine.time_scale = 1.0
	var g: Game = (load(Net.GAME_SCENE) as PackedScene).instantiate()
	g.backdrop = self
	_viewport.add_child(g)  # (makes its map and village: Game._ready calls prepare and start)
	Engine.time_scale = float(value("speed"))
	_fade_to(Color.WHITE.darkened(float(value("shade"))), float(value("fade_in")))
	scene_started.emit(index)


func _fade_to(c: Color, seconds: float) -> Tween:
	if _fade:
		_fade.kill()
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(self, "modulate", c, maxf(seconds, 0.01))
	return _fade


## Game._ready, before the world is made: the scene's map and village.
func prepare(g: Game) -> void:
	g.map_seed = int(value("seed"))
	g.map_type = str(value("map_type"))
	g.reveal_map = true
	g.disable_fog = true
	g.hotseat_villages = 1
	g.start_resources = (value("resources") as Dictionary).duplicate()
	g.start_civilians.assign(value("civilians"))
	g.start_buildings.assign(value("buildings"))


## Game._ready, once it's set up: no HUD or input, its posts, the camera.
func start(g: Game) -> void:
	game = g
	g.hud.visible = false
	g.set_process_input(false)
	g.camera.set_process(false)  # (it would pan with the arrow keys)
	g.camera.set_process_input(false)
	g.camera.set_process_unhandled_input(false)
	g.waves.hold = true  # (no waves: only the scene's enemies)
	for key: String in Config.LOCKED:
		g.unlock(key)
	var mode := Hero.MODE_NAMES.find(str(value("hero")).capitalize())
	if mode >= 0:
		g.hero.set_mode(mode)
	route = _pick_route(int(value("road")))
	var taken: Array[Vector2i] = []
	for p: Dictionary in value("posts"):
		_place(p, taken)
	var cam: Dictionary = value("camera")
	_cam_from = _anchor(cam.get("from", 0))
	_cam_to = _anchor(cam.get("to", cam.get("from", 0)))
	var z := float(cam.get("zoom", 1.0))
	g.camera.zoom = Vector2(z, z)
	g.camera.position = _cam_from
	g.events.debug("title backdrop: %s on road %s" % [value("name"), str(route.back()) if not route.is_empty() else "-"])


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	clock += delta / maxf(Engine.time_scale, 0.001)
	game_time += delta
	var t := clampf(clock / maxf(float(value("duration")), 0.01), 0.0, 1.0)
	game.camera.position = _cam_from.lerp(_cam_to, smoothstep(0.0, 1.0, t))
	_spawn_due()
	if not _leaving and clock >= float(value("duration")) - float(value("fade_out")):
		_leaving = true
		_fade_to(Color.BLACK, float(value("fade_out"))).finished.connect(_next_scene.bind(-1))


# --- enemies --------------------------------------------------------------------------

func _spawn_due() -> void:
	var groups: Array = value("enemies")
	for i in groups.size():
		if game_time < _next_group[i]:
			continue
		var grp: Dictionary = groups[i]
		var j := 0
		for kind: String in grp["kinds"]:
			for k in int(grp["kinds"][kind]):
				_pending.append({"kind": kind, "at": _next_group[i] + j * float(grp.get("gap", 1.0)), "from": int(grp.get("from", 18)), "wave": int(grp.get("wave", 1))})
				j += 1
		var every := float(grp.get("every", 0.0))
		_next_group[i] = _next_group[i] + every if every > 0.0 else INF
	for e in _pending.duplicate():
		if game_time >= float(e["at"]):
			_pending.erase(e)
			var at := road_tile(int(e["from"]))
			if at != Vector2i(-1, -1):
				game.waves.spawn_at(e["kind"], at, game.player_village, e["wave"])


# --- the spots ------------------------------------------------------------------------

## Road `i` (0: the shortest from the map edge to a gate, 1: the next, ...).
func _pick_route(i: int) -> Array[Vector2i]:
	var pathing := game.world.pathing
	var spawns: Array[Vector2i] = []
	spawns.assign(game.map.edge_spawns.filter(func(sp: Vector2i) -> bool: return pathing.enemy_distance(sp) < Pathing.UNREACHABLE))
	if spawns.is_empty():
		return [] as Array[Vector2i]
	spawns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return pathing.enemy_distance(a) < pathing.enemy_distance(b))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(value("seed"))
	return pathing.enemy_route(spawns[posmod(i, spawns.size())], rng)


## The road tile `d` tiles before the gate (as far as the road goes).
func road_tile(d: int) -> Vector2i:
	if route.is_empty():
		return Vector2i(-1, -1)
	return route[clampi(route.size() - 1 - d, 0, route.size() - 1)]


## A camera spot: a number is a road tile that far before the gate, [x, y] a
## tile offset from the village centre.
func _anchor(a) -> Vector2:
	if a is Array:
		return Iso.tile_to_world(game.player_village.center + Vector2i(int(a[0]), int(a[1])))
	var t := road_tile(int(a))
	return Iso.tile_to_world(t if t != Vector2i(-1, -1) else game.player_village.center)


func _place(p: Dictionary, taken: Array[Vector2i]) -> void:
	var v := game.player_village
	var kind := str(p["kind"])
	var b: Building = null
	if kind == "wall_tower":
		b = _wall_tower()
	else:
		var at: Array = p.get("at", [3, 6])
		var tile := _by_road(kind, int(at[0]), int(at[1]), taken)
		if tile == Vector2i(-1, -1):
			push_warning("Title backdrop: no room for a %s in %s" % [kind, value("name")])
			return
		var site := bool(p.get("site", false))
		b = v.construction._new_building(kind, tile, not site)
		taken.append_array(Building.footprint(tile, Config.BUILDINGS[kind]["size"]))
		if site:
			v.construction.queue.append(b)
			v.construction.changed.emit()
			return
	if b == null:
		return
	if p.has("level") and "level" in b:
		b.level = int(p["level"])
		b.refresh()
	if b is Workplace:
		v.population.assign_worker(b, true)
	if b is MilitaryPost:
		var post := b as MilitaryPost
		var units: Array = p.get("units", [])
		for i in mini(units.size(), post.capacity()):
			_man(post, i, units[i])


## A unit of the scene, already on its post (no walking there, no gold).
func _man(post: MilitaryPost, slot: int, u: Dictionary) -> void:
	var army := game.player_village.army
	var unit := MilitaryUnit.new(str(u["kind"]))
	unit.village = game.player_village
	unit.original_owner = game.player_village
	unit.nid = game.register(unit)
	unit.uid = game.next_id(unit.kind)
	unit.level = clampi(int(u.get("level", 1)) - 1, 0, Config.MAX_UNIT_LEVEL - 1)
	unit.hp = unit.max_hp()
	army.units.append(unit)
	unit.post = post
	unit.slot = slot
	unit.state = MilitaryUnit.State.STATIONED
	post.set_slot(slot, unit)


## The village's corner tower nearest the road's gate.
func _wall_tower() -> Tower:
	var gate := road_tile(0)
	var best: Tower = null
	for b in game.player_village.buildings():
		if b is Tower and game.map.in_village(b.tile) and (best == null or Vector2(b.tile).distance_to(Vector2(gate)) < Vector2(best.tile).distance_to(Vector2(gate))):
			best = b
	return best


## A free spot for `kind` right by the road, `lo` to `hi` road tiles before
## the gate (nearest the middle of that stretch), clear of `taken`.
func _by_road(kind: String, lo: int, hi: int, taken: Array[Vector2i]) -> Vector2i:
	var size: int = Config.BUILDINGS[kind]["size"]
	var best := Vector2i(-1, -1)
	var best_score := INF
	var n := route.size()
	for i in n:
		var before_gate := n - 1 - i
		if before_gate < lo or before_gate > hi:
			continue
		for dy in range(-size, size + 1):
			for dx in range(-size, size + 1):
				var t := route[i] + Vector2i(dx, dy)
				if not _fits(kind, t, taken) or not _touches_road(t, size):
					continue
				var score := absf(before_gate - (lo + hi) / 2.0) + 0.1 * Vector2(t).distance_to(Vector2(game.player_village.center))
				if score < best_score:
					best_score = score
					best = t
	return best


func _touches_road(t: Vector2i, size: int) -> bool:
	for f in Building.footprint(t, size):
		for n in MapData.neighbors4(f):
			if route.has(n):
				return true
	return false


## Free for `kind` (ignoring cost), not on or right next to `taken`.
func _fits(kind: String, t: Vector2i, taken: Array[Vector2i]) -> bool:
	if game.player_village.construction.placement_error(kind, t, true) != "":
		return false
	for f in Building.footprint(t, Config.BUILDINGS[kind]["size"]):
		for k in taken:
			if maxi(absi(f.x - k.x), absi(f.y - k.y)) <= 1:
				return false
	return true
