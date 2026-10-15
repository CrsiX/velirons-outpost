class_name IsoView
extends Node2D
## The map editor's isometric view: the game's own ground, water, lava and
## top layers (GroundLayer, WaterLayer) and sprites for trees, peaks, decor,
## village pieces and map objects, as the game draws them (no fog). After an
## edit only the changed tiles are drawn again (`refresh_tiles`); village
## pieces and objects are rebuilt (`refresh_things`).

var map: MapData
var ground: GroundLayer
var water: WaterLayer
var lava: WaterLayer
var ground_top: GroundLayer
var edge: MapEdgeFade
## Trees, peaks, decor, pieces and objects, sorted by their feet.
var things: Node2D
var _props: Dictionary = {}  # tile -> Sprite2D
var _decor: Dictionary = {}  # tile -> Sprite2D
var _built: Array[Node] = []  # pieces and objects


func setup(m: MapData, overlays: Array) -> void:
	map = m
	for c in get_children():
		remove_child(c)
		if not overlays.has(c):
			c.queue_free()
	_props.clear()
	_decor.clear()
	_built.clear()
	ground = GroundLayer.new()
	ground.name = "Ground"
	add_child(ground)
	ground.setup(map, false)
	water = WaterLayer.new()
	lava = WaterLayer.new()
	ground_top = GroundLayer.new()
	for layer in [lava, water, ground_top]:
		add_child(layer)
	water.setup(map, false)
	lava.setup(map, true)
	ground_top.setup(map, true)
	edge = MapEdgeFade.new()
	add_child(edge)
	edge.setup(map)
	things = Node2D.new()
	things.y_sort_enabled = true
	add_child(things)
	for o in overlays:
		add_child(o)  # (over everything: markers stay visible behind trees)
	for y in map.size:
		for x in map.size:
			_refresh_sprites(Vector2i(x, y))
	refresh_things()


## The ground and sprites of `tiles` (and the ring around them, whose rims overlap) again.
func refresh_tiles(tiles: Array) -> void:
	var seen := {}
	for t: Vector2i in tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := t + Vector2i(dx, dy)
				if map.in_bounds(p) and not seen.has(p):
					seen[p] = true
					ground.redraw_tile(p)
					ground_top.redraw_tile(p)
					_refresh_sprites(p)
	water.queue_redraw()
	lava.queue_redraw()


## Village pieces and map objects again.
func refresh_things() -> void:
	for n in _built:
		n.queue_free()
	_built.clear()
	for p in map.village_layout:
		_add_piece(p, false)
	for a in map.abandoned:
		for p in a["pieces"]:
			_add_piece(p, true)
	for o in map.objects:
		var art := str(o.get("art", MapJson.object_art(o)))
		if not ArtManifest.SPRITES.has(art):
			continue
		var s := Art.sprite(art)
		s.position = Building.anchor_world(o["tile"], int(o.get("size", 1)))
		things.add_child(s)
		_built.append(s)


func _add_piece(p: Dictionary, ruined: bool) -> void:
	var kind: String = p["kind"]
	var art := kind
	if kind == "hut":
		art = "hut_ruin" if ruined else "hut"
	var s := Art.sprite(art)
	s.position = Iso.tile_to_world(p["tile"])
	if kind in ["wall", "gate"]:
		s.flip_h = p["flip"]
	things.add_child(s)
	_built.append(s)
	if kind == "wall_tower":
		var f := Art.sprite("wall_tower_front")
		f.position = Vector2(0, 0.01)
		s.add_child(f)


func _refresh_sprites(t: Vector2i) -> void:
	_set_sprite(_props, t, str(map.props.get(t, "")), true)
	_set_sprite(_decor, t, str(map.decor.get(t, "")), false)


func _set_sprite(store: Dictionary, t: Vector2i, art: String, prop: bool) -> void:
	var s: Sprite2D = store.get(t)
	if s and (art == "" or s.get_meta("art", "") != art):
		s.queue_free()
		store.erase(t)
		s = null
	if art == "" or s != null or not ArtManifest.SPRITES.has(art):
		return
	s = Art.sprite(art)
	s.set_meta("art", art)
	var h := absi(hash(t))
	if not prop:
		s.position = Iso.tile_to_world(t) + Vector2((h % 13) - 6, ((h / 13) % 9) - 4)
		s.scale *= 0.85 + ((h / 117) % 4) * 0.08
		s.flip_h = h % 2 == 0
	elif art == "volcano":
		s.position = Iso.tile_to_world(t)
	elif map.is_mountain(t):
		s.position = Iso.tile_to_world(t) + Vector2((h % 9) - 4, 0)
		s.scale *= 0.95 + ((h / 9) % 4) * 0.08
	else:
		s.position = Iso.tile_to_world(t) + Vector2((h % 11) - 5, ((h / 11) % 7) - 3)
		s.scale *= 0.9 + ((h / 77) % 5) * 0.05
	things.add_child(s)
	store[t] = s


## Another map of the same size (undo / redo): only the tiles that differ are drawn again.
func set_map(m: MapData, changed: Array) -> void:
	map = m
	for layer in [ground, ground_top, water, lava]:
		layer.map = m
	refresh_tiles(changed)
	refresh_things()
