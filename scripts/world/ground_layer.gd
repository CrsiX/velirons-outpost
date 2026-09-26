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
	var desert: Array[Texture2D] = [Art.tex("tile_desert_0"), Art.tex("tile_desert_1")]
	var forest := Art.tex("tile_forest")
	var rock := Art.tex("tile_rock")
	var road := Art.tex("tile_road")
	# Pass 1: base ground. Pass 2: desert and pass 3: roads, which have soft
	# rims that overlap their neighbours. Back-to-front so overlaps are consistent.
	for layer in 3:
		for s in range(0, map.size * 2 - 1):
			for x in range(maxi(0, s - map.size + 1), mini(s, map.size - 1) + 1):
				var t := Vector2i(x, s - x)
				var v := map.get_terrain(t)
				var h := posmod(t.x * 7 + t.y * 13 + (t.x * t.y) % 5, 3)
				match layer:
					0:
						match v:
							MapData.Terrain.FOREST: _blit(forest, t)
							MapData.Terrain.MOUNTAIN: _blit(rock, t)
							_: _blit(grass[h], t)
					1:
						if v == MapData.Terrain.DESERT:
							_blit(desert[h % 2], t)
					2:
						if v == MapData.Terrain.ROAD:
							_blit(road, t)


func _blit(tex: Texture2D, t: Vector2i) -> void:
	var size := tex.get_size() * 0.5
	draw_texture_rect(tex, Rect2(Iso.tile_to_world(t) - size / 2.0, size), false)
