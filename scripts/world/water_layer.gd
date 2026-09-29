class_name WaterLayer
extends Node2D
## Deep and shallow water, or lava (`lava = true`), drawn once over the ground
## (docs/world-design.md §6.5). A small shader makes it shimmer: a slow wave
## of brightness across the surface (lava: a stronger, slower glow).
## Tiles under bridges and fords are drawn too; the top layer covers them.

const SHADER := """
shader_type canvas_item;
uniform float strength = 0.07;
uniform float speed = 1.2;
varying vec2 wpos;
void vertex() {
	wpos = VERTEX;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float w = sin(TIME * speed + wpos.x * 0.021 + wpos.y * 0.034) * 0.5
		+ sin(TIME * speed * 0.63 - wpos.x * 0.013 + wpos.y * 0.017) * 0.5;
	c.rgb *= 1.0 + strength * w;
	COLOR = c;
}
"""

var map: MapData
var lava := false


func setup(p_map: MapData, p_lava: bool) -> void:
	map = p_map
	lava = p_lava
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("strength", 0.22 if lava else 0.07)
	mat.set_shader_parameter("speed", 0.8 if lava else 1.2)
	material = mat
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var deep: Array[Texture2D] = [Art.tex("tile_water_0"), Art.tex("tile_water_1")]
	var shallow := Art.tex("tile_shallow")
	var lava_tex := Art.tex("tile_lava")
	for s in range(0, map.size * 2 - 1):
		for x in range(maxi(0, s - map.size + 1), mini(s, map.size - 1) + 1):
			var t := Vector2i(x, s - x)
			var v := map.get_terrain(t)
			if map.crossings.has(t):
				v = int(map.crossings[t][1])
			var tex: Texture2D = null
			if lava:
				if v == MapData.Terrain.LAVA:
					tex = lava_tex
			elif v == MapData.Terrain.WATER:
				tex = deep[(t.x * 3 + t.y) % 2]
			elif v == MapData.Terrain.SHALLOW:
				tex = shallow
			if tex:
				var size := tex.get_size() * 0.5
				draw_texture_rect(tex, Rect2(Iso.tile_to_world(t) - size / 2.0, size), false)
