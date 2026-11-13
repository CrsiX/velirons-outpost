class_name Art
extends RefCounted
## Sprite factory for the generated SVG art (see tools/gen_art.py).
## SVGs are rasterised at 2x, so sprites are drawn at half scale.

const FLAG_NODE := "Flag"

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


## Shows `art_name` on `s`. `tint`: the village colour its banner cloth wears
## (docs/village-design.md §12); transparent (the default) keeps the art's crimson.
## Set `s.flip_h` before calling: the cloth copies it.
static func apply(s: Sprite2D, art_name: String, tint := Color.TRANSPARENT) -> void:
	var m := info(art_name)
	s.texture = tex(art_name)
	s.scale = Vector2(0.5, 0.5)
	s.centered = true
	s.offset = Vector2(m.w - 2.0 * m.ax, m.h - 2.0 * m.ay)
	var f := flag_of(s)
	if tint.a <= 0.0 or not has_flag(art_name):
		if f:
			f.visible = false
		return
	if f == null:
		f = Sprite2D.new()
		f.name = FLAG_NODE
		f.use_parent_material = true
		s.add_child(f)
	f.texture = tex(art_name + "_flag")
	f.centered = true
	f.offset = s.offset
	f.flip_h = s.flip_h
	f.modulate = tint
	f.visible = true


## Whether `art_name` has banner cloth, so a grey `<art_name>_flag` companion to tint.
static func has_flag(art_name: String) -> bool:
	return bool(info(art_name).get("flag", false))


## The tinted cloth Art.apply put on `s` (null when it never had any).
static func flag_of(s: Node) -> Sprite2D:
	return s.get_node_or_null(FLAG_NODE) as Sprite2D


## Art.apply's tinted cloth for a UI icon: lays `art_name`'s companion over `r`
## (same stretch) in `tint`, or hides it (transparent tint, no cloth).
static func tint_rect(r: TextureRect, art_name: String, tint: Color) -> void:
	var f := r.get_node_or_null(FLAG_NODE) as TextureRect
	if tint.a <= 0.0 or not has_flag(art_name):
		if f:
			f.visible = false
		return
	if f == null:
		f = TextureRect.new()
		f.name = FLAG_NODE
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.add_child(f)
	f.texture = tex(art_name + "_flag")
	f.expand_mode = r.expand_mode
	f.stretch_mode = r.stretch_mode
	f.flip_h = r.flip_h
	f.modulate = tint
	f.visible = true


## Local rect (1x units, relative to the anchor) covered by an art piece.
static func rect(art_name: String) -> Rect2:
	var m := info(art_name)
	return Rect2(-m.ax, -m.ay, m.w, m.h)
