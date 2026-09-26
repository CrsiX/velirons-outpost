class_name GroundLayer
extends Node2D
## Draws every terrain tile once (the canvas item caches the draw list).

var map: MapData


func setup(p_map: MapData) -> void:
	map = p_map
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var grass: Array[Texture2D] = [Art.tex("tile_grass_0"), Art.tex("tile_grass_1"), Art.tex("tile_grass_2")]
	var forest := Art.tex("tile_forest")
	var road := Art.tex("tile_road")
	# Draw back-to-front so the soft road rims overlap consistently.
	for s in range(0, map.size * 2 - 1):
		for x in range(maxi(0, s - map.size + 1), mini(s, map.size - 1) + 1):
			var t := Vector2i(x, s - x)
			var tex: Texture2D
			match map.get_terrain(t):
				MapData.Terrain.FOREST: tex = forest
				MapData.Terrain.ROAD: continue
				_: tex = grass[posmod(t.x * 7 + t.y * 13 + (t.x * t.y) % 5, 3)]
			_blit(tex, t)
	for s in range(0, map.size * 2 - 1):
		for x in range(maxi(0, s - map.size + 1), mini(s, map.size - 1) + 1):
			var t := Vector2i(x, s - x)
			if map.is_road(t):
				_blit(road, t)


func _blit(tex: Texture2D, t: Vector2i) -> void:
	var size := tex.get_size() * 0.5
	draw_texture_rect(tex, Rect2(Iso.tile_to_world(t) - size / 2.0, size), false)
