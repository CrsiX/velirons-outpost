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

var game: Game
var map: MapData
var pathing: Pathing
var buildings: Array[Building] = []

var _props: Dictionary = {}  # tile -> Sprite2D (trees, mountain peaks)
var _village_dist := PackedInt32Array()
var _village_dist_dirty := true

@onready var ground: GroundLayer = $Ground
@onready var decals: Node2D = $Decals
@onready var fog: FogLayer = $Fog
@onready var objects: Node2D = $Objects
@onready var effects: Node2D = $Effects
@onready var overlay: WorldOverlay = $Overlay


func setup(p_game: Game, seed_value: int) -> void:
	game = p_game
	map = MapGenerator.generate(seed_value)
	pathing = Pathing.new(map)
	ground.setup(map)
	fog.setup(map)
	fog.revealed.connect(_on_revealed)
	_spawn_props()
	_spawn_village()
	fog.reveal(Vector2(Config.VILLAGE_CENTER), Config.START_REVEAL_RADIUS)
	if map.farm_plot != Vector2i(-1, -1):
		fog.reveal(Vector2(map.farm_plot), 2.0)
	if Config.REVEAL_MAP:
		fog.reveal_all()
	if Config.DISABLE_FOG:
		fog.set_disabled(true)


func _spawn_props() -> void:
	for t: Vector2i in map.props:
		var s := Art.sprite(map.props[t])
		var h := absi(hash(t))
		if map.is_mountain(t):
			s.position = Iso.tile_to_world(t) + Vector2((h % 9) - 4, 0)
			s.scale *= 0.95 + ((h / 9) % 4) * 0.08
		else:
			# Slight random offset/scale so the forest doesn't look like a grid.
			s.position = Iso.tile_to_world(t) + Vector2((h % 11) - 5, ((h / 11) % 7) - 3)
			s.scale *= 0.9 + ((h / 77) % 5) * 0.05
		s.visible = false
		objects.add_child(s)
		_props[t] = s


func _spawn_village() -> void:
	for piece in map.village_layout:
		var kind: String = piece["kind"]
		var b: Building = PIECE_SCRIPTS[kind].new()
		if b is StaticPiece:
			b.flip = piece["flip"]
		b.setup(game, kind, piece["tile"], true)
		add_building(b)


func _on_revealed(tiles: Array[Vector2i]) -> void:
	for t in tiles:
		if _props.has(t):
			_props[t].visible = true


# --- building registry -------------------------------------------------------------

func add_building(b: Building) -> void:
	if b.get_parent() == null:
		objects.add_child(b)
	buildings.append(b)
	for t in b.tiles():
		map.buildings[t] = b
	refresh_building(b)


func remove_building(b: Building) -> void:
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


## Walking distance from the village centre to every tile (cached).
func village_distance() -> PackedInt32Array:
	if _village_dist_dirty:
		_village_dist = pathing.distance_field(Config.VILLAGE_CENTER)
		_village_dist_dirty = false
	return _village_dist


## Front-most building whose sprite covers `world_pos`, falling back to the tile.
func pick_building(world_pos: Vector2) -> Building:
	var best: Building = null
	for b in buildings:
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
			if not is_tree(t) or not map.is_explored(t) or Vector2(t).distance_to(Vector2(from)) > radius:
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
	ground.queue_redraw()


func float_text(text: String, at: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("15110d"))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.add_child(l)
	var sz := l.get_minimum_size()
	l.position = at - sz / 2.0
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 36.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func world_rect() -> Rect2:
	var s := float(map.size) - 0.5
	var r := Rect2(Iso.to_world(Vector2(-0.5, -0.5)), Vector2.ZERO)
	for p in [Vector2(s, -0.5), Vector2(-0.5, s), Vector2(s, s)]:
		r = r.expand(Iso.to_world(p))
	return r
