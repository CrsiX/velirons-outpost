class_name GroundLayer
extends Node2D
## Draws every land tile once (the canvas item caches the draw list): the
## ground art of its zone (docs/world-design.md §4), forest floors, rock
## under mountains, then desert and beach sand and roads, which have soft rims
## that overlap their neighbours. Water and lava are drawn by WaterLayer on top,
## fords, bridges and shore foam by the top layer (`top = true`).
## Everything back to front, so overlaps are consistent.

var map: MapData
## The top layer: fords, bridges and shore foam (over the water).
var top := false
var _cache: Dictionary = {}


func setup(p_map: MapData, p_top: bool = false) -> void:
	map = p_map
	top = p_top
	queue_redraw()


func _tex(art_name: String) -> Texture2D:
	if not _cache.has(art_name):
		_cache[art_name] = Art.tex(art_name)
	return _cache[art_name]


func _draw() -> void:
	if map == null:
		return
	if top:
		_draw_top()
		return
	var road := _tex("tile_road")
	var pass_road := _tex("tile_road_pass")
	# Pass 0: base ground. Pass 1: desert and beach sand. Pass 2: roads.
	for layer in 3:
		for s in range(0, map.size * 2 - 1):
			for x in range(maxi(0, s - map.size + 1), mini(s, map.size - 1) + 1):
				var t := Vector2i(x, s - x)
				var v := map.get_terrain(t)
				var h := posmod(t.x * 7 + t.y * 13 + (t.x * t.y) % 5, 3)
				var zone: Dictionary = Config.ZONES[map.zone(t)]
				match layer:
					0:
						if v == MapData.Terrain.MOUNTAIN:
							_blit(_tex("tile_rock"), t)
						elif v == MapData.Terrain.FOREST and zone.has("forest_floor"):
							_blit(_tex(zone["forest_floor"]), t)
						elif map.zone(t) == "steppe" or map.beaches.has(t):
							_blit(_tex("tile_meadow_%d" % h), t)  # (under the sand's soft rim)
						else:
							var arts: Array = zone["ground"]
							_blit(_tex(arts[h % arts.size()]), t)
					1:
						if map.beaches.has(t) and v != MapData.Terrain.ROAD:
							_blit(_tex("tile_sand"), t)
						elif map.zone(t) == "steppe" and v != MapData.Terrain.WATER and v != MapData.Terrain.SHALLOW:
							_blit(_tex("tile_desert_%d" % (h % 2)), t)
					2:
						if v == MapData.Terrain.ROAD and not map.crossings.has(t):
							_blit(pass_road if _mountains_beside(t) >= 2 else road, t)


## Fords and bridges over the water layer, and foam where land meets water.
func _draw_top() -> void:
	for s in range(0, map.size * 2 - 1):
		for x in range(maxi(0, s - map.size + 1), mini(s, map.size - 1) + 1):
			var t := Vector2i(x, s - x)
			if map.crossings.has(t):
				var art: String = map.crossings[t][0]
				if art == "tile_ford":
					_blit(_tex(art), t)
				else:
					var tex := _tex(art)
					var m := Art.info(art)
					var size := tex.get_size() * 0.5
					var anchor := Vector2(m.get("ax", size.x / 2.0), m.get("ay", size.y / 2.0))
					draw_texture_rect(tex, Rect2(Iso.tile_to_world(t) - anchor, size), false)
			elif not map.is_water(t) and map.get_terrain(t) != MapData.Terrain.LAVA:
				for e in foam_edges(map, t):
					draw_line(e[0], e[1], FOAM, 2.4, true)


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


func _water_beside(t: Vector2i) -> bool:
	for nb in MapData.neighbors4(t):
		if map.is_water(nb) and not map.crossings.has(nb):
			return true
	return false


func _blit(tex: Texture2D, t: Vector2i) -> void:
	var size := tex.get_size() * 0.5
	draw_texture_rect(tex, Rect2(Iso.tile_to_world(t) - size / 2.0, size), false)
