class_name FogLayer
extends Node2D
## Fog of war with three states per tile:
##   unexplored          -> black (terrain unknown)
##   explored            -> darkened; terrain known, enemies hidden
##   under surveillance  -> clear; enemies visible
## Explorers explore; units outside the village and manned towers ("observers")
## put explored tiles under surveillance.
##
## Every village has its own fog (co-op: players only see what their own
## explorers explored and their own units and buildings watch). `map.explored`
## / `map.watched` are the local player's village's, used for drawing and the
## HUD; game logic for a particular village uses is_explored_by / is_watched_by.
##
## Drawn as one tiny texture (one pixel per tile) through a grid->iso transform,
## so linear filtering gives soft edges for free and redraws stay cheap.

## Tiles the local village just explored (World shows the trees there).
signal revealed(tiles: Array[Vector2i])
## Any village explored new tiles (the co-op host tells that player).
signal explored_changed(vid: int, tiles: Array[Vector2i])

const FOG_LUMA := 8  # 0..255, the fog's grey level
const UNEXPLORED_ALPHA := 255
const UNWATCHED_ALPHA := 120
const WATCH_INTERVAL := 0.2

var map: MapData
## Per village id: 1 = explored / under surveillance.
var explored_of: Array[PackedByteArray] = []
var watched_of: Array[PackedByteArray] = []
## The village whose fog is drawn (the local player's).
var local := 0
## No fog at all: every tile is explored and under surveillance (Config.DISABLE_FOG).
var disabled := false
var _image: Image
var _texture: ImageTexture
var _pixels := PackedByteArray()
var _watch_timer := 0.0
var _explored_dirty := true
## Units outside explore around them (Config.UNIT_REVEAL). Off on co-op
## clients: the host explores and tells them.
var units_explore := true


func setup(p_map: MapData, villages: int = 1) -> void:
	map = p_map
	for i in maxi(1, villages):
		var e := PackedByteArray()
		e.resize(map.size * map.size)
		explored_of.append(e)
		var w := PackedByteArray()
		w.resize(map.size * map.size)
		watched_of.append(w)
	# Grid space -> iso world: x axis goes down-right, y axis down-left.
	transform = Transform2D(Vector2(Iso.HALF_W, Iso.HALF_H), Vector2(-Iso.HALF_W, Iso.HALF_H), Vector2.ZERO)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var side := map.size + 2  # one pixel of padding around the map (see _rebuild)
	_pixels.resize(side * side * 2)
	_image = Image.create_from_data(side, side, false, Image.FORMAT_LA8, _pixels)
	_texture = ImageTexture.create_from_image(_image)
	_rebuild()


## Marks tiles within `radius` (grid units) of `center` as explored for
## village `vid` (-1: the local one). Returns how many tiles were newly explored.
func reveal(center: Vector2, radius: float, vid: int = -1) -> int:
	var fresh: Array[Vector2i] = []
	var r := int(ceil(radius))
	var c := Vector2i(center.round())
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := c + Vector2i(dx, dy)
			if map.in_bounds(t) and Vector2(t).distance_to(center) <= radius:
				fresh.append(t)
	return explore_tiles(fresh, vid).size()


## Marks `tiles` explored for village `vid` (-1: local); returns the new ones.
func explore_tiles(tiles: Array[Vector2i], vid: int = -1) -> Array[Vector2i]:
	if vid < 0:
		vid = local
	var e := explored_of[vid]
	var fresh: Array[Vector2i] = []
	for t in tiles:
		var i := map.index(t)
		if e[i] == 0:
			e[i] = 1
			fresh.append(t)
	if fresh.is_empty():
		return fresh
	explored_of[vid] = e
	explored_changed.emit(vid, fresh)
	if vid == local:
		for t in fresh:
			map.explored[map.index(t)] = 1
		_explored_dirty = true
		revealed.emit(fresh)
	return fresh


## Marks the whole map explored (Config.REVEAL_MAP) for every village.
## Surveillance still applies.
func reveal_all() -> void:
	var all: Array[Vector2i] = []
	for i in map.size * map.size:
		all.append(Vector2i(i % map.size, i / map.size))
	for vid in explored_of.size():
		explore_tiles(all, vid)


func is_explored_by(vid: int, t: Vector2i) -> bool:
	return map.in_bounds(t) and explored_of[clampi(vid, 0, explored_of.size() - 1)][map.index(t)] == 1


func is_watched_by(vid: int, t: Vector2i) -> bool:
	return is_explored_by(vid, t) and watched_of[clampi(vid, 0, watched_of.size() - 1)][map.index(t)] == 1


## Shows village `vid`'s fog (the local player's village).
func set_local(vid: int) -> void:
	local = vid
	map.explored = explored_of[vid].duplicate()
	map.watched = watched_of[vid].duplicate()
	_rebuild()


func set_disabled(v: bool) -> void:
	disabled = v
	if disabled:
		reveal_all()
	update_surveillance()


func explored_count() -> int:
	return map.explored.count(1)


func watched_count() -> int:
	return map.watched.count(1)


func is_watched(t: Vector2i) -> bool:
	return map.is_explored(t) and map.is_watched(t)


func _process(delta: float) -> void:
	_watch_timer -= delta
	if _watch_timer <= 0.0 or _explored_dirty:
		_watch_timer = WATCH_INTERVAL
		update_surveillance()


## Recomputes which tiles every village's observers watch.
func update_surveillance() -> void:
	var n := watched_of.size()
	var area := map.size * map.size
	var all := PackedByteArray()  # every village's surveillance, one after another
	all.resize(n * area)
	all.fill(1 if disabled else 0)
	if not disabled:
		for node in get_tree().get_nodes_in_group("observers"):
			var vid := observer_village(node)
			if vid < 0 or vid >= n:
				continue
			var radius: float = node.sight_radius()
			if radius <= 0.0:
				continue
			if units_explore and not (node is Building):
				_unit_reveal(node, vid)
			var base := vid * area
			var c: Vector2 = node.sight_center()
			var r := int(ceil(radius))
			var ct := Vector2i(c.round())
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var t := ct + Vector2i(dx, dy)
					if map.in_bounds(t) and Vector2(t).distance_to(c) <= radius:
						all[base + map.index(t)] = 1
	for vid in n:
		watched_of[vid] = all.slice(vid * area, (vid + 1) * area)
	map.watched = watched_of[local].duplicate()
	_rebuild()


## A unit outside explores around it; the hero learns from it (unless he's
## exploring: his Explore job counts that).
func _unit_reveal(node: Node, vid: int) -> void:
	var c: Vector2 = node.sight_center()
	if reveal(c, Config.UNIT_REVEAL, vid) > 0 and node is Hero and (node as Hero).mode != Hero.Mode.EXPLORE:
		(node as Hero).on_action("explore")


## Which village an observer watches for: its own (units, buildings, a
## soldier's unit, a caravan's sender); -1 if none.
static func observer_village(node: Node) -> int:
	var v = node.get("village")
	if v == null and node is Soldier:
		v = (node as Soldier).unit.village
	return (v as Village).id if v is Village else -1


func _rebuild() -> void:
	_explored_dirty = false
	var side := map.size + 2
	var px := PackedByteArray()
	px.resize(side * side * 2)
	for i in side * side:
		px[i * 2] = FOG_LUMA
		px[i * 2 + 1] = UNEXPLORED_ALPHA
	# The padding repeats the edge tiles: the fog is drawn over the objects, and
	# a dark rim would cut off whatever tall stands on the edge (trees, peaks,
	# lairs). The map's dark rim is MapEdgeFade, under the objects.
	for y in side:
		for x in side:
			var i := clampi(y - 1, 0, map.size - 1) * map.size + clampi(x - 1, 0, map.size - 1)
			var alpha := UNEXPLORED_ALPHA
			if map.explored[i] == 1:
				alpha = 0 if map.watched[i] == 1 else UNWATCHED_ALPHA
			px[(y * side + x) * 2 + 1] = alpha
	if px == _pixels:
		return
	_pixels = px
	_image.set_data(side, side, false, Image.FORMAT_LA8, _pixels)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	# Pixel (i, j) covers grid tile (i - 1, j - 1), i.e. [i - 1.5, i - 0.5].
	var side := float(map.size + 2)
	draw_texture_rect(_texture, Rect2(-1.5, -1.5, side, side), false)
