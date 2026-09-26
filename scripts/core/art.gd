class_name Art
extends RefCounted
## Sprite factory for the generated SVG art (see tools/gen_art.py).
## SVGs are rasterised at 2x, so sprites are drawn at half scale.

static var _textures: Dictionary = {}


static func tex(art_name: String) -> Texture2D:
	if not _textures.has(art_name):
		_textures[art_name] = load("res://art/%s.svg" % art_name)
	return _textures[art_name]


static func info(art_name: String) -> Dictionary:
	return ArtManifest.SPRITES.get(art_name, {})


## A Sprite2D whose origin sits on the art's anchor (tile centre or feet).
static func sprite(art_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	apply(s, art_name)
	return s


static func apply(s: Sprite2D, art_name: String) -> void:
	var m := info(art_name)
	s.texture = tex(art_name)
	s.scale = Vector2(0.5, 0.5)
	s.centered = true
	s.offset = Vector2(m.w - 2.0 * m.ax, m.h - 2.0 * m.ay)


## Local rect (1x units, relative to the anchor) covered by an art piece.
static func rect(art_name: String) -> Rect2:
	var m := info(art_name)
	return Rect2(-m.ax, -m.ay, m.w, m.h)
