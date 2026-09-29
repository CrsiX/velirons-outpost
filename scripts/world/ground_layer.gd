class_name GroundLayer
extends Node2D
## Draws every land tile: the ground art of its zone (docs/world-design.md §4),
## forest floors, rock under mountains, then desert and beach sand and roads,
## which have soft rims that overlap their neighbours. Water and lava are drawn
## by WaterLayer on top; fords, bridges and shore foam by the top layer
## (`top = true`).
##
## The map is cut into CHUNK x CHUNK tile chunks, one set per drawing pass
## (base, sand, roads; or the top layer's one pass), each its own canvas item
## (its draw list is cached). When a tile changes (a tree falls) only its
## chunks are redrawn. Tiles are drawn back to front within a chunk, and the
## chunks back to front, so overlapping rims stay consistent.

const CHUNK := 16

var map: MapData
## The top layer: fords, bridges and shore foam (over the water).
var top := false
var _tex_cache: Dictionary = {}
## Per pass, per tile index: the texture to draw ("" = nothing), cached.
var _art: Array[PackedStringArray] = []
## Chunk nodes per pass: Vector2i(chunk x, chunk y) -> Chunk.
var _chunks: Array[Dictionary] = []


class Chunk:
	extends Node2D
	var layer: GroundLayer
	var pass_i := 0
	var origin := Vector2i.ZERO

	func _draw() -> void:
		layer._draw_chunk(self)


func setup(p_map: MapData, p_top: bool = false) -> void:
	map = p_map
	top = p_top
	var passes := 1 if top else 3
	_art.clear()
	_chunks.clear()
	for p in passes:
		var arts := PackedStringArray()
		arts.resize(map.size * map.size)
		_art.append(arts)
		_chunks.append({})
	for y in map.size:
		for x in map.size:
			_cache_tile(Vector2i(x, y))
	# Chunks back to front (by their diagonal), pass by pass.
	var nc := ceili(float(map.size) / CHUNK)
	for p in passes:
		for s in range(0, nc * 2 - 1):
			for cx in range(maxi(0, s - nc + 1), mini(s, nc - 1) + 1):
				var c := Chunk.new()
				c.layer = self
				c.pass_i = p
				c.origin = Vector2i(cx, s - cx) * CHUNK
				add_child(c)
				_chunks[p][Vector2i(cx, s - cx)] = c


## A tile changed (a tree fell): redraw the chunks it's in.
func redraw_tile(t: Vector2i) -> void:
	if map == null or not map.in_bounds(t):
		return
	_cache_tile(t)
	var key := t / CHUNK
	for p in _chunks.size():
		var c: Chunk = _chunks[p].get(key)
		if c:
			c.queue_redraw()


func _tex(art_name: String) -> Texture2D:
	if not _tex_cache.has(art_name):
		_tex_cache[art_name] = Art.tex(art_name)
	return _tex_cache[art_name]


## Works out what each pass draws on `t`.
func _cache_tile(t: Vector2i) -> void:
	var k := map.index(t)
	var v := map.get_terrain(t)
	if top:
		# (fords and bridges: their art; foam is drawn from the terrain directly)
		_art[0][k] = map.crossings[t][0] if map.crossings.has(t) else ""
		return
	var h := posmod(t.x * 7 + t.y * 13 + (t.x * t.y) % 5, 3)
	var zname := map.zone(t)
	var zone: Dictionary = Config.ZONES[zname]
	var base := ""
	if v == MapData.Terrain.MOUNTAIN:
		base = "tile_rock"
	elif v == MapData.Terrain.FOREST and zone.has("forest_floor"):
		base = zone["forest_floor"]
	elif zname == "steppe" or map.beaches.has(t):
		base = "tile_meadow_%d" % h  # (under the sand's soft rim)
	else:
		var arts: Array = zone["ground"]
		base = arts[h % arts.size()]
	_art[0][k] = base
	var sand := ""
	if map.beaches.has(t) and v != MapData.Terrain.ROAD:
		sand = "tile_sand"
	elif zname == "steppe" and v != MapData.Terrain.WATER and v != MapData.Terrain.SHALLOW:
		sand = "tile_desert_%d" % (h % 2)
	_art[1][k] = sand
	var road := ""
	if v == MapData.Terrain.ROAD and not map.crossings.has(t):
		road = "tile_road_pass" if _mountains_beside(t) >= 2 else "tile_road"
	_art[2][k] = road


func _draw_chunk(c: Chunk) -> void:
	var arts := _art[c.pass_i]
	var x1 := mini(c.origin.x + CHUNK, map.size)
	var y1 := mini(c.origin.y + CHUNK, map.size)
	# Back to front within the chunk: by diagonal.
	for s in range(c.origin.x + c.origin.y, x1 + y1 - 1):
		for x in range(maxi(c.origin.x, s - y1 + 1), mini(s - c.origin.y, x1 - 1) + 1):
			var t := Vector2i(x, s - x)
			var art := arts[t.y * map.size + t.x]
			if top:
				_draw_top_tile(c, t, art)
			elif art != "":
				_blit(c, _tex(art), t)


## Fords and bridges over the water layer, and foam where land meets water.
func _draw_top_tile(c: Chunk, t: Vector2i, art: String) -> void:
	if art == "tile_ford":
		_blit(c, _tex(art), t)
	elif art != "":
		var tex := _tex(art)
		var m := Art.info(art)
		var size := tex.get_size() * 0.5
		var anchor := Vector2(m.get("ax", size.x / 2.0), m.get("ay", size.y / 2.0))
		c.draw_texture_rect(tex, Rect2(Iso.tile_to_world(t) - anchor, size), false)
	elif not map.is_water(t) and map.get_terrain(t) != MapData.Terrain.LAVA:
		for e in foam_edges(map, t):
			c.draw_line(e[0], e[1], FOAM, 2.4, true)


const FOAM := Color(0.9, 0.95, 0.92, 0.4)


## Short broken lines (world positions) along the edges of land tile `t`
## that touch open water: the shore's foam.
static func foam_edges(m: MapData, t: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var nb: Vector2i = t + d
		if not m.is_water(nb) or m.crossings.has(nb):
			continue
		var dv := Vector2(d)
		var side := Vector2(-dv.y, dv.x)
		var mid := Vector2(t) + dv * 0.44  # just inside the land tile
		var h := absi(hash(t * 3 + d))
		# Two dashes with a gap that moves from tile to tile.
		var gap := 0.1 + (h % 5) * 0.06
		out.append([Iso.to_world(mid - side * 0.46), Iso.to_world(mid + side * (gap - 0.5 + 0.04))])
		out.append([Iso.to_world(mid + side * (gap - 0.5 + 0.16)), Iso.to_world(mid + side * 0.46)])
	return out


func _mountains_beside(t: Vector2i) -> int:
	var n := 0
	for nb in MapData.neighbors4(t):
		if map.is_mountain(nb):
			n += 1
	return n


func _blit(c: Chunk, tex: Texture2D, t: Vector2i) -> void:
	var size := tex.get_size() * 0.5
	c.draw_texture_rect(tex, Rect2(Iso.tile_to_world(t) - size / 2.0, size), false)
