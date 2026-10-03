class_name World
extends Node2D
## Owns the map data, navigation and all layers; spawns terrain objects and the
## starting village; keeps the tile -> building registry in sync with pathing.

const PIECE_SCRIPTS := {
	"hut": preload("res://scripts/buildings/hut.gd"),
	"wall": preload("res://scripts/buildings/static_piece.gd"),
	"gate": preload("res://scripts/buildings/static_piece.gd"),
	"wall_tower": preload("res://scripts/buildings/tower.gd"),
}

const OBJECT_SCRIPTS := {
	"treasure": preload("res://scripts/world/objects/treasure.gd"),
	"camp": preload("res://scripts/world/objects/monster_camp.gd"),
	"unlock": preload("res://scripts/world/objects/unlock_site.gd"),
	"ruin": preload("res://scripts/world/objects/ruined_tower.gd"),
	"lair": preload("res://scripts/world/objects/monster_lair.gd"),
	"mine": preload("res://scripts/world/objects/mine.gd"),
}
## Map objects' ids: this + their index in MapData.objects (the same on every side).
const OBJECT_NID_BASE := 1 << 24

var game: Game
var map: MapData
## Special objects (docs/world-design.md §9), by index.
var map_objects: Array[MapObject] = []
var _objects_by_index: Dictionary = {}
## While the level is being set up, finding objects isn't announced.
var _quiet := true
var _mine_timer := 0.0
var pathing: Pathing
var buildings: Array[Building] = []

var _props: Dictionary = {}  # tile -> Sprite2D (trees, mountain peaks, volcanoes)
var _decor: Dictionary = {}  # tile -> Sprite2D (reeds, boulders, cacti...)
## Water, lava and the layer over them (fords, bridges, foam); after Ground.
var water: WaterLayer
var lava: WaterLayer
var ground_top: GroundLayer
## Walking distance from each village centre (id -> field), rebuilt when dirty.
var _village_dist: Dictionary = {}
var _village_dist_dirty := true
## Name labels floating over the villages (co-op), id -> Label.
var _village_labels: Dictionary = {}

@onready var ground: GroundLayer = $Ground
@onready var decals: Node2D = $Decals
@onready var fog: FogLayer = $Fog
@onready var warnings: WarningLights = $Warnings
@onready var objects: Node2D = $Objects
@onready var effects: Node2D = $Effects
@onready var overlay: WorldOverlay = $Overlay


func setup(p_game: Game, seed_value: int) -> void:
	game = p_game
	# Co-op clients use the map the host generated and sent (Net.map); the
	# title backdrop brings a baked one (Game.preset_map).
	if game.preset_map:
		map = game.preset_map
	elif game.is_client and Net.map:
		map = Net.map
	else:
		map = MapGenerator.generate(seed_value, game.villages.size(), game.map_type)
	await game.build_step()
	pathing = Pathing.new(map)
	await game.build_step()
	await ground.setup(map, false, game)
	await game.build_step(true)  # (its first draw comes at the end of the frame)
	water = WaterLayer.new()
	water.name = "Water"
	lava = WaterLayer.new()
	lava.name = "Lava"
	ground_top = GroundLayer.new()
	ground_top.name = "GroundTop"
	for layer in [ground_top, lava, water]:
		add_child(layer)
		move_child(layer, ground.get_index() + 1)
	water.setup(map, false)
	lava.setup(map, true)
	await game.build_step(true)
	await ground_top.setup(map, true, game)
	await game.build_step(true)
	var rim := MapEdgeFade.new()
	rim.name = "EdgeFade"
	add_child(rim)
	move_child(rim, decals.get_index() + 1)  # (over the ground and decals, under the overlay and objects)
	rim.setup(map)
	fog.setup(map, game.villages.size())
	fog.units_explore = not game.is_client
	fog.revealed.connect(_on_revealed)
	fog.explored_changed.connect(_on_explored)
	warnings.setup(game)
	await game.build_step()
	await _spawn_props()
	if not game.is_client:  # (clients get every building from the host)
		_spawn_village()
	await game.build_step()
	_spawn_map_objects()
	await game.build_step()
	game.waves.wave_started.connect(_on_wave_started)
	# Each village knows its own surroundings, and every village's 5x5 walls
	# (docs/multiplayer-design.md §6).
	for i in map.villages.size():
		var v: Dictionary = map.villages[i]
		fog.reveal(Vector2(v["center"]), Config.START_REVEAL_RADIUS, i)
		if v["farm_plot"] != Vector2i(-1, -1):
			fog.reveal(Vector2(v["farm_plot"]), 2.0, i)
		for j in map.villages.size():
			fog.explore_tiles(MapData.rect_tiles(v["rect"]), j)
	if map.villages.size() > 1:
		_spawn_village_labels()
	if game.reveal_map:
		fog.reveal_all()
	if game.disable_fog:
		fog.set_disabled(true)


func _spawn_props() -> void:
	for t: Vector2i in map.props:
		var s := Art.sprite(map.props[t])
		var h := absi(hash(t))
		if map.props[t] == "volcano":
			s.position = Iso.tile_to_world(t)
			_add_smoke(s)
		elif map.is_mountain(t):
			s.position = Iso.tile_to_world(t) + Vector2((h % 9) - 4, 0)
			s.scale *= 0.95 + ((h / 9) % 4) * 0.08
		else:
			# Slight random offset/scale so the forest doesn't look like a grid.
			s.position = Iso.tile_to_world(t) + Vector2((h % 11) - 5, ((h / 11) % 7) - 3)
			s.scale *= 0.9 + ((h / 77) % 5) * 0.05
		s.visible = false
		objects.add_child(s)
		_props[t] = s
		await game.build_step()
	for t: Vector2i in map.decor:
		var s := Art.sprite(map.decor[t])
		var h := absi(hash(t))
		s.position = Iso.tile_to_world(t) + Vector2((h % 13) - 6, ((h / 13) % 9) - 4)
		s.scale *= 0.85 + ((h / 117) % 4) * 0.08
		s.flip_h = h % 2 == 0
		s.visible = false
		objects.add_child(s)
		_decor[t] = s
		await game.build_step()


# --- special objects (docs/world-design.md §9) -------------------------------------------

func _spawn_map_objects() -> void:
	for i in map.objects.size():
		_add_map_object(i, map.objects[i])
	if not game.is_client:
		for o in map_objects:
			if o is MonsterCamp:
				(o as MonsterCamp).spawn_monsters()
		_schedule_lairs()
	(func() -> void: _quiet = false).call_deferred()


## Host: when each lair first wakes up. Per slice, in an order fixed by the
## map's seed: the first at LAIR_FROM_WAVE, each further one LAIR_EVERY later.
func _schedule_lairs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed_value * 13 + 5
	var by_slice := {}
	for o in map_objects:
		if o is MonsterLair:
			var s := int(o.data.get("slice", 0))
			if not by_slice.has(s):
				by_slice[s] = []
			by_slice[s].append(o)
	for s in by_slice:
		var list: Array = by_slice[s]
		for i in range(list.size() - 1, 0, -1):  # (shuffled with the seeded rng)
			var j := rng.randi_range(0, i)
			var tmp = list[i]
			list[i] = list[j]
			list[j] = tmp
		for k in list.size():
			(list[k] as MonsterLair).wake_wave = Config.LAIR_FROM_WAVE + k * Config.LAIR_EVERY


## Host, at the start of wave `n`: lairs whose time has come wake up.
func wake_lairs(n: int) -> void:
	for o in map_objects:
		if o is MonsterLair:
			(o as MonsterLair).on_wave(n)


## The awake lairs in slice `s` (-1: all).
func awake_lairs(s: int = -1) -> Array[MonsterLair]:
	var out: Array[MonsterLair] = []
	for o in map_objects:
		if o is MonsterLair and (o as MonsterLair).awake and (s < 0 or int(o.data.get("slice", 0)) == s):
			out.append(o)
	return out


func _add_map_object(i: int, d: Dictionary) -> MapObject:
	var o: MapObject = OBJECT_SCRIPTS[d["kind"]].new()
	o.setup_object(game, i, d)
	o.nid = OBJECT_NID_BASE + i
	game.register_fixed(o, o.nid)
	objects.add_child(o)
	map_objects.append(o)
	_objects_by_index[i] = o
	for t in o.tiles():
		map.buildings[t] = o
		if o.is_solid():
			pathing.set_solid(t, true)
	return o


func map_object(i: int) -> MapObject:
	return _objects_by_index.get(i)


## Co-op client: the sacks the host has, [[index, tile], ...]; others go.
func sync_net_sacks(list: Array) -> void:
	var keep := {}
	for e in list:
		keep[int(e[0])] = true
		if map_object(int(e[0])) == null:
			add_dropped_loot(e[1], {}, int(e[0]))
	for o in map_objects.duplicate():
		if o.data.get("sack", false) and not keep.has(o.index):
			remove_map_object(o)


func remove_map_object(o: MapObject) -> void:
	map_objects.erase(o)
	_objects_by_index.erase(o.index)
	for t in o.tiles():
		if map.buildings.get(t) == o:
			map.buildings.erase(t)
			pathing.set_solid(t, false)
	game.unregister(o.nid)
	o.queue_free()


## A downed looter's loot, where he fell: anyone can pick it up (the hero or
## a gatherer). The host makes it; co-op clients get it through the snapshots
## (add_net_sack).
func add_dropped_loot(t: Vector2i, reward: Dictionary, index: int = -1) -> Treasure:
	var d := {"kind": "treasure", "treasure": "chest", "sack": true, "art": "sack", "tile": t, "size": 1, "slice": map.slice_of[map.index(t)], "tier": 1, "guard": -1, "reward": reward}
	if index < 0:
		map.objects.append(d)
		index = map.objects.size() - 1
	var o := _add_map_object(index, d) as Treasure
	for v in game.villages:
		if fog.is_explored_by(v.id, t):
			o.on_found(v.id, true)
	o.update_visibility()
	return o


func _on_explored(vid: int, tiles: Array[Vector2i]) -> void:
	for t in tiles:
		var b = map.buildings.get(t)
		if b is MapObject:
			(b as MapObject).on_found(vid, _quiet)


## Unit-unlock sites awaken at their wave (every copy at once); each player
## hears about it: where it is if they found a copy, a rumour otherwise.
func _on_wave_started(n: int) -> void:
	for kind in Config.UNLOCK_SITES:
		var spec: Dictionary = Config.UNLOCK_SITES[kind]
		if n < int(spec["wave"]):
			continue
		var sites: Array = map_objects.filter(func(o: MapObject) -> bool: return o is UnlockSite and o.data["site"] == kind and not o.awake)
		if sites.is_empty():
			continue
		for s in sites:
			(s as UnlockSite).awaken()
		if game.is_client or game.is_unlocked(spec["unlocks"]):
			continue
		for v in game.villages:
			var known := map_objects.any(func(o: MapObject) -> bool: return o is UnlockSite and o.data["site"] == kind and o.is_found_by(v))
			v.events.info(spec["awake"] if known else spec["rumour"])


## Everything unlocked: the unlock sites for that unit have nothing left to give.
func on_unlocked(key: String) -> void:
	for o in map_objects:
		if o is UnlockSite and o.unlocks() == key:
			(o as UnlockSite).mark_used()


func _process(delta: float) -> void:
	if game == null or game.is_client or game.is_unlocked("miner"):
		return
	_mine_timer -= delta
	if _mine_timer > 0.0:
		return
	_mine_timer = 0.5
	# The first to walk up to a mine unlocks the miner for everyone.
	var mines: Array = map_objects.filter(func(o: MapObject) -> bool: return o is Mine)
	for node in get_tree().get_nodes_in_group("observers"):
		if not (node is Unit) or node.get("dead") == true or (node is Civilian and node.at_home):
			continue
		for m in mines:
			if node.grid_pos.distance_to(Vector2((m as Mine).visit_tile())) <= Config.MINE_REACH:
				game.unlock("miner", game.village_of(node), node)
				return


## Smoke puffs rising from a volcano's crater, looping.
func _add_smoke(volcano: Sprite2D) -> void:
	var crater: float = Art.info("volcano").get("crater", 200.0)
	for k in 2:
		var puff := Art.sprite("volcano_smoke")
		puff.position = Vector2(0, -crater * 2.0)  # (in the volcano's unscaled space)
		puff.scale = Vector2.ONE
		volcano.add_child(puff)
		var tw := puff.create_tween().set_loops()
		tw.tween_interval(k * 2.2)
		tw.tween_property(puff, "position:y", -crater * 2.0 - 90.0, 4.4).from(-crater * 2.0)
		tw.parallel().tween_property(puff, "modulate:a", 0.0, 4.4).from(0.9)


## Removes the decoration on `t` (a building goes there).
func clear_decor(t: Vector2i) -> void:
	var s: Sprite2D = _decor.get(t)
	if s:
		s.queue_free()
	_decor.erase(t)
	map.decor.erase(t)


func _spawn_village() -> void:
	for piece in map.village_layout:
		var kind: String = piece["kind"]
		var b: Building = PIECE_SCRIPTS[kind].new()
		if b is StaticPiece:
			b.flip = piece["flip"]
		b.village = game.villages[piece.get("owner", 0)]
		b.setup(game, kind, piece["tile"], true)
		add_building(b)


## Trees and peaks show on explored tiles of the local village's fog.
func refresh_props() -> void:
	for o in map_objects:
		o.update_visibility()
	for t: Vector2i in _props:
		_props[t].visible = map.is_explored(t)
	for t: Vector2i in _decor:
		_decor[t].visible = map.is_explored(t)


func _on_revealed(tiles: Array[Vector2i]) -> void:
	for t in tiles:
		var b = map.buildings.get(t)
		if b is MapObject:
			(b as MapObject).update_visibility()
		if _props.has(t):
			_props[t].visible = true
		if _decor.has(t):
			_decor[t].visible = true


# --- building registry -------------------------------------------------------------

func add_building(b: Building) -> void:
	if b.uid == 0:
		b.uid = game.next_id(b.kind)
	if b.nid == 0:
		b.nid = game.register(b)
	if b.get_parent() == null:
		objects.add_child(b)
	buildings.append(b)
	for t in b.tiles():
		map.buildings[t] = b
		if _decor.has(t):
			clear_decor(t)
	refresh_building(b)


func remove_building(b: Building) -> void:
	game.unregister(b.nid)
	buildings.erase(b)
	for t in b.tiles():
		if map.buildings.get(t) == b:
			map.buildings.erase(t)
			pathing.set_solid(t, false)
	_village_dist_dirty = true
	b.queue_free()


## Re-syncs pathing after a building changes state (e.g. a tower is finished).
func refresh_building(b: Building) -> void:
	for t in b.tiles():
		pathing.set_solid(t, b.is_solid())
	_village_dist_dirty = true


func huts() -> Array[Building]:
	return buildings.filter(func(b: Building) -> bool: return b is Hut)


func intact_huts() -> Array[Building]:
	return buildings.filter(func(b: Building) -> bool: return b is Hut and b.is_intact())


func towers() -> Array[Building]:
	return buildings.filter(func(b: Building) -> bool: return b is Tower)


## Towers and every other building that can hold a military unit.
func military_posts() -> Array[Building]:
	return buildings.filter(func(b: Building) -> bool: return b is MilitaryPost)


## Walking distance from a village's centre to every tile (cached); the local
## player's village when none is given.
func village_distance(v: Village = null) -> PackedInt32Array:
	if v == null:
		v = game.player_village
	if _village_dist_dirty:
		_village_dist.clear()
		_village_dist_dirty = false
	if not _village_dist.has(v.id):
		_village_dist[v.id] = pathing.distance_field(v.center)
	return _village_dist[v.id]


## Co-op: every village's name floats over its centre in its colour. The
## local player's own village doesn't need one.
func _spawn_village_labels() -> void:
	for v in game.villages:
		var l := Label.new()
		l.text = v.village_name
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 8)
		l.size = Vector2(400, 40)
		l.position = Iso.tile_to_world(map.villages[v.id]["center"]) + Vector2(-200, -150)
		l.z_index = 50
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effects.add_child(l)
		_village_labels[v.id] = l
	refresh_village_labels()


## Label colours and visibility: hidden over the local village, grey while fallen.
func refresh_village_labels() -> void:
	for v in game.villages:
		var l: Label = _village_labels.get(v.id)
		if l == null:
			continue
		l.visible = not v.is_local()
		l.text = v.village_name + ("  (fallen)" if v.fallen else "")
		l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6) if v.fallen else v.color)


## The stationed unit whose figure (on a tower, a barracks bench...) is under
## `world_pos`, or null. Its post is `unit.post`.
func pick_unit(world_pos: Vector2) -> MilitaryUnit:
	var best: MilitaryUnit = null
	var best_y := -INF
	for p in military_posts():
		var u: MilitaryUnit = p.unit_at(world_pos - p.position)
		if u != null and p.position.y > best_y:
			best = u
			best_y = p.position.y
	return best


## Front-most building whose sprite covers `world_pos`, falling back to the tile.
func pick_building(world_pos: Vector2) -> Building:
	var best: Building = null
	var cands: Array[Building] = buildings.duplicate()
	for o in map_objects:
		if o.visible:
			cands.append(o)
	for b in cands:
		if b.pick_rect().has_point(world_pos - b.position) and (best == null or b.position.y > best.position.y):
			if b is Farm and map.building_at(Iso.to_tile(world_pos)) != b:
				continue  # farm rect is a loose box; require the actual footprint
			best = b
	if best == null:
		best = map.building_at(Iso.to_tile(world_pos))
	return best


# --- trees (foresters) -----------------------------------------------------------

## Seconds a tree has already been chopped: tile -> float.
var _chopped: Dictionary = {}
## Tree reservations so two foresters don't work the same tree: tile -> Node.
var _tree_claims: Dictionary = {}


func is_tree(t: Vector2i) -> bool:
	return map.is_forest(t) and map.props.has(t)


func tree_chop_time(t: Vector2i) -> float:
	return Config.TREE_CHOP_TIME.get(map.props.get(t, ""), 20.0)


func tree_progress(t: Vector2i) -> float:
	return _chopped.get(t, 0.0) / tree_chop_time(t)


func claim_tree(t: Vector2i, who: Node) -> void:
	_tree_claims[t] = who


func release_tree(t: Vector2i, who: Node) -> void:
	if _tree_claims.get(t) == who:
		_tree_claims.erase(t)


## Closest explored, unclaimed tree to `from` within `radius` tiles that has a
## walkable tile next to it. Returns {tree, stand} or {} if none.
func find_tree(from: Vector2i, radius: float, who: Node) -> Dictionary:
	var dist := pathing.distance_field(from)
	var best := {}
	var best_d := Pathing.UNREACHABLE
	var r := int(ceil(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := from + Vector2i(dx, dy)
			if not is_tree(t) or not fog.is_explored_by(maxi(0, FogLayer.observer_village(who)), t) or Vector2(t).distance_to(Vector2(from)) > radius:
				continue
			var owner: Node = _tree_claims.get(t)
			if owner != null and owner != who and is_instance_valid(owner):
				continue
			for ny in range(-1, 2):
				for nx in range(-1, 2):
					var st := t + Vector2i(nx, ny)
					if st == t or not pathing.is_walkable(st):
						continue
					var d := dist[map.index(st)]
					if d < best_d:
						best_d = d
						best = {"tree": t, "stand": st}
	return best


## Log name of the tree on `t`, numbered by its tile: "tree 482".
func tree_label(t: Vector2i) -> String:
	return "tree %d" % map.index(t)


## Chops `seconds` off a tree. Returns true when it falls (tile becomes meadow).
func chop_tree(t: Vector2i, seconds: float) -> bool:
	if not is_tree(t):
		return true
	_chopped[t] = _chopped.get(t, 0.0) + seconds
	var s: Sprite2D = _props.get(t)
	if s:
		s.rotation = sin(Time.get_ticks_msec() / 60.0) * 0.03  # shudders under the axe
		s.modulate = Color.WHITE.lerp(Color(0.75, 0.65, 0.55), tree_progress(t))
	if _chopped[t] >= tree_chop_time(t):
		remove_tree(t)
		return true
	return false


func remove_tree(t: Vector2i) -> void:
	var s: Sprite2D = _props.get(t)
	if s:
		var tw := s.create_tween()
		tw.tween_property(s, "rotation", 1.3, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.6)
		tw.tween_callback(s.queue_free)
	_props.erase(t)
	map.props.erase(t)
	_chopped.erase(t)
	_tree_claims.erase(t)
	map.set_terrain(t, MapData.Terrain.GRASS)
	pathing.set_solid(t, false)
	_village_dist_dirty = true
	ground.redraw_tile(t)


## A short text rising from `at` (world position) and fading. Icon tokens
## ({gold} {food} {materials} {xp} {hp}) are drawn as their icons.
func float_text(text: String, at: Vector2, color: Color) -> void:
	if game.replicator and game.replicator.hosting:
		game.replicator.float_text(text, at, color)
	var l: Control
	if "{" in text:
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.scroll_active = false
		rt.fit_content = true
		rt.autowrap_mode = TextServer.AUTOWRAP_OFF
		rt.add_theme_font_size_override("normal_font_size", 20)
		rt.add_theme_color_override("default_color", color)
		rt.add_theme_color_override("font_outline_color", Color("15110d"))
		rt.add_theme_constant_override("outline_size", 6)
		rt.text = "[center]%s[/center]" % Hud.icon_bbcode(text, 20)
		rt.custom_minimum_size = Vector2(FLOAT_TEXT_W, 0)
		l = rt
	else:
		var lb := Label.new()
		lb.text = text
		lb.add_theme_font_size_override("font_size", 20)
		lb.add_theme_color_override("font_color", color)
		lb.add_theme_color_override("font_outline_color", Color("15110d"))
		lb.add_theme_constant_override("outline_size", 6)
		l = lb
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.add_child(l)
	var sz := l.get_minimum_size()
	if l is RichTextLabel:
		sz = Vector2(FLOAT_TEXT_W, 26.0)
	l.position = at - sz / 2.0
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 36.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## Width of a floating text with icons (centred in it).
const FLOAT_TEXT_W := 320.0


func world_rect() -> Rect2:
	var s := float(map.size) - 0.5
	var r := Rect2(Iso.to_world(Vector2(-0.5, -0.5)), Vector2.ZERO)
	for p in [Vector2(s, -0.5), Vector2(-0.5, s), Vector2(s, s)]:
		r = r.expand(Iso.to_world(p))
	return r
