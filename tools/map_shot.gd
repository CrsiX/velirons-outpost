extends Node
## Renders a whole generated map to a PNG, the way the game draws it (ground
## tiles, roads, trees, mountains, every village's walls, towers and huts),
## on the CPU from the SVG art: works headless, no GPU or display needed.
## Fog is left out; each village gets a tint of its colour and a marker.
##
##   godot --headless --path . res://tools/map_shot.tscn -- <players> <out.png> [seed] [scale] [plan|iso] [map type]
##
## "plan" (default): a flat top-down plan (one coloured square per tile:
## roads, forest, desert, mountains, villages, spawns), `scale` pixels per
## tile. "iso": the isometric picture, `scale` x the game at 100 % zoom.
##
## (A scene, not a --script: config.gd needs the autoloads.)
##
## Usually run through tools/map_shot.sh, which numbers the files.

const TINT := 0.28  # village colour over its ground


var _cache: Dictionary = {}
var _scale := 0.35
var _origin := Vector2.ZERO
var _img: Image


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <players> <out.png> [seed] [scale]")
		get_tree().quit(2)
		return
	var players := clampi(int(args[0]), 1, Config.MAX_PLAYERS)
	var out := args[1]
	var seed_value := int(args[2]) if args.size() > 2 and args[2] != "" else randi()
	var iso := args.size() > 4 and args[4] == "iso"
	_scale = 0.35 if iso else 6.0
	if args.size() > 3 and args[3] != "":
		_scale = float(args[3])
	var t0 := Time.get_ticks_msec()
	var map_type := args[5] if args.size() > 5 and args[5] != "" else "temperate"
	var m := MapGenerator.generate(seed_value, players, map_type)
	if iso:
		_render(m)
	else:
		_plan(m, maxi(1, roundi(_scale)))
	var err := _img.save_png(out)
	if err != OK:
		printerr("could not write %s (error %d)" % [out, err])
		get_tree().quit(1)
		return
	print("%s  players %d  seed %d  %s  map %dx%d  image %dx%d  (%.1f s)" % [out, players, seed_value, map_type, m.size, m.size, _img.get_width(), _img.get_height(), (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0)


## The art `art_name` rasterised at the current scale, flipped if asked:
## [image, anchor (pixels)].
func _art(art_name: String, flip: bool = false) -> Array:
	var key := "%s%s" % [art_name, "_f" if flip else ""]
	if not _cache.has(key):
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://art/%s.svg" % art_name), _scale)
		img.convert(Image.FORMAT_RGBA8)
		var m := Art.info(art_name)
		var anchor := Vector2(m.get("ax", m.get("w", 0.0) / 2.0), m.get("ay", m.get("h", 0.0) / 2.0)) * _scale
		if flip:
			img.flip_x()
			anchor.x = img.get_width() - anchor.x
		_cache[key] = [img, anchor]
	return _cache[key]


func _px(world: Vector2) -> Vector2:
	return (world - _origin) * _scale


## Draws `art_name` with its centre on `world` (ground tiles).
func _blit_centered(art_name: String, world: Vector2) -> void:
	var a: Array = _art(art_name)
	var img: Image = a[0]
	var p := _px(world) - Vector2(img.get_size()) / 2.0
	_img.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(p.round()))


## Draws `art_name` with its anchor (feet / tile centre) on `world`.
func _blit_anchored(art_name: String, world: Vector2, flip: bool = false) -> void:
	var a: Array = _art(art_name, flip)
	var img: Image = a[0]
	var p := _px(world) - (a[1] as Vector2)
	_img.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(p.round()))


func _render(m: MapData) -> void:
	# World bounds of the diamond, plus room for tall art at the top.
	var n := m.size
	var left := Iso.tile_to_world(Vector2i(0, n - 1)).x - Iso.HALF_W
	var right := Iso.tile_to_world(Vector2i(n - 1, 0)).x + Iso.HALF_W
	var top := Iso.tile_to_world(Vector2i(0, 0)).y - Iso.HALF_H - 180.0
	var bottom := Iso.tile_to_world(Vector2i(n - 1, n - 1)).y + Iso.HALF_H + 10.0
	_origin = Vector2(left, top)
	var size := Vector2i((Vector2(right - left, bottom - top) * _scale).ceil())
	_img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_img.fill(Color("1a1410"))
	# Ground, like GroundLayer: base, then sand, then roads (soft rims overlap);
	# then water and lava (WaterLayer), then fords, bridges and shore foam.
	for layer in 6:
		for s in range(0, n * 2 - 1):
			for x in range(maxi(0, s - n + 1), mini(s, n - 1) + 1):
				var t := Vector2i(x, s - x)
				var v := m.get_terrain(t)
				var under := int(m.crossings[t][1]) if m.crossings.has(t) else v
				var h := posmod(t.x * 7 + t.y * 13 + (t.x * t.y) % 5, 3)
				var w := Iso.tile_to_world(t)
				var zone: Dictionary = Config.ZONES[m.zone(t)]
				match layer:
					0:
						if v == MapData.Terrain.MOUNTAIN:
							_blit_centered("tile_rock", w)
						elif v == MapData.Terrain.FOREST and zone.has("forest_floor"):
							_blit_centered(zone["forest_floor"], w)
						elif m.zone(t) == "steppe" or m.beaches.has(t):
							_blit_centered("tile_meadow_%d" % h, w)
						else:
							var arts: Array = zone["ground"]
							_blit_centered(arts[h % arts.size()], w)
					1:
						if m.beaches.has(t) and v != MapData.Terrain.ROAD:
							_blit_centered("tile_sand", w)
						elif m.zone(t) == "steppe" and not m.is_water(t):
							_blit_centered("tile_desert_%d" % (h % 2), w)
					2:
						if v == MapData.Terrain.ROAD and not m.crossings.has(t):
							var rocky := 0
							for nb in MapData.neighbors4(t):
								if m.is_mountain(nb):
									rocky += 1
							_blit_centered("tile_road_pass" if rocky >= 2 else "tile_road", w)
					3:
						if under == MapData.Terrain.WATER:
							_blit_centered("tile_water_%d" % ((t.x * 3 + t.y) % 2), w)
						elif under == MapData.Terrain.SHALLOW:
							_blit_centered("tile_shallow", w)
						elif under == MapData.Terrain.LAVA:
							_blit_centered("tile_lava", w)
					4:
						if m.crossings.has(t):
							var art: String = m.crossings[t][0]
							if art == "tile_ford":
								_blit_centered(art, w)
							else:
								_blit_anchored(art, w)
					5:
						if not m.is_water(t) and v != MapData.Terrain.LAVA and not m.crossings.has(t):
							for e in GroundLayer.foam_edges(m, t):
								_line(_px(e[0]), _px(e[1]), GroundLayer.FOAM, maxf(1.0, 2.4 * _scale))
	_tint_villages(m)
	# Objects back to front (the game y-sorts them): props, village pieces.
	var objs: Array = []  # [world y, art, world pos, flip]
	for t: Vector2i in m.props:
		var hh := absi(hash(t))
		var pos := Iso.tile_to_world(t)
		if m.is_mountain(t):
			pos += Vector2((hh % 9) - 4, 0)
		else:
			pos += Vector2((hh % 11) - 5, ((hh / 11) % 7) - 3)
		if m.props[t] == "volcano":
			pos = Iso.tile_to_world(t)
			objs.append([pos.y + 0.02, "volcano_smoke", pos + Vector2(0, -float(Art.info("volcano").get("crater", 200.0))), false])
		objs.append([pos.y, m.props[t], pos, false])
	for t: Vector2i in m.decor:
		var pos := Iso.tile_to_world(t)
		objs.append([pos.y, m.decor[t], pos, absi(hash(t)) % 2 == 0])
	for o in m.objects:
		var pos := Building.anchor_world(o["tile"], o.get("size", 1))
		objs.append([pos.y, o["art"], pos, false])
	for piece in m.village_layout:
		var pos := Iso.tile_to_world(piece["tile"])
		var kind: String = piece["kind"]
		objs.append([pos.y, kind, pos, piece["flip"]])
		if kind == "wall_tower":
			objs.append([pos.y + 0.01, "wall_tower_front", pos, piece["flip"]])
	objs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for o in objs:
		_blit_anchored(o[1], o[2], o[3])
	_mark_spawns(m)


const ZONE_COLORS := {
	"meadow": Color("8fbf5a"), "oak": Color("6f9a48"), "pine": Color("4f7a3a"), "heath": Color("8a7a52"),
	"steppe": Color("cdb27a"), "swamp": Color("5d6b3c"), "ash": Color("77736d"),
}
const OBJECT_COLORS := {
	"treasure": Color("f2c230"), "camp": Color("b0381f"), "unlock": Color("b777ff"), "ruin": Color("f4f0e6"),
	"lair": Color("1b1411"), "mine": Color("ff8a1f"),
}


## Top-down plan, `px` pixels per tile: zones (trees darker), water, mountains,
## roads, bridges and fords, villages, spawns, objects and slice borders.
func _plan(m: MapData, px: int) -> void:
	_img = Image.create(m.size * px, m.size * px, false, Image.FORMAT_RGBA8)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var c: Color = ZONE_COLORS[m.zone(t)]
			match m.get_terrain(t):
				MapData.Terrain.FOREST: c = c.darkened(0.45)
				MapData.Terrain.ROAD: c = Color("f2e2b0")
				MapData.Terrain.MOUNTAIN: c = Color("8a837c")
				MapData.Terrain.WATER: c = Color("2f5f8f")
				MapData.Terrain.SHALLOW: c = Color("6fa3c8")
				MapData.Terrain.LAVA: c = Color("ff5a1a")
			if m.beaches.has(t) and not m.is_road(t) and not m.is_water(t):
				c = Color("efe0a8")
			if m.crossings.has(t):
				c = Color("9ad0e8") if m.crossings[t][0] == "tile_ford" else Color("8a5a2b")
			if m.decor.has(t):
				c = c.darkened(0.15)
			var vid := m.village_at(t) if m.in_village(t) else -1
			if vid >= 0:
				c = Config.VILLAGE_COLORS[vid % Config.VILLAGE_COLORS.size()]
			var right := t + Vector2i(1, 0)
			var down := t + Vector2i(0, 1)
			if (m.in_bounds(right) and m.slice_of[m.index(right)] != m.slice_of[m.index(t)]) or (m.in_bounds(down) and m.slice_of[m.index(down)] != m.slice_of[m.index(t)]):
				c = c.lerp(Color.BLACK, 0.35)
			_img.fill_rect(Rect2i(x * px, y * px, px, px), c)
	for v in m.volcanoes:
		_img.fill_rect(Rect2i((v.x - 1) * px, (v.y - 1) * px, px * 3, px * 3), Color("5a1a10"))
		_img.fill_rect(Rect2i(v.x * px, v.y * px, px, px), Color("ff7a1a"))
	for o in m.objects:
		var t: Vector2i = o["tile"]
		var sz: int = o.get("size", 1)
		var c: Color = OBJECT_COLORS.get(o["kind"], Color.MAGENTA)
		_img.fill_rect(Rect2i(t.x * px - px / 2, t.y * px - px / 2, px * (sz + 1), px * (sz + 1)), Color.BLACK)
		_img.fill_rect(Rect2i(t.x * px, t.y * px, px * sz, px * sz), c)
	for s in m.edge_spawns:
		_img.fill_rect(Rect2i(s.x * px - px, s.y * px - px, px * 3, px * 3), Color("e0303a"))


## Each village's ground gets a tint of its colour (so you can tell them apart).
func _tint_villages(m: MapData) -> void:
	for i in m.villages.size():
		var v: Dictionary = m.villages[i]
		var col: Color = Config.VILLAGE_COLORS[i % Config.VILLAGE_COLORS.size()]
		var r: Rect2i = v["rect"]
		var poly := PackedVector2Array()
		for c in [Vector2(r.position) - Vector2(0.5, 0.5), Vector2(r.end.x, r.position.y) - Vector2(0.5, 0.5), Vector2(r.end) - Vector2(0.5, 0.5), Vector2(r.position.x, r.end.y) - Vector2(0.5, 0.5)]:
			poly.append(_px(Iso.to_world(c)))
		_fill_poly(poly, Color(col, TINT))


## Where the waves come from: red dots on the map edge.
func _mark_spawns(m: MapData) -> void:
	for s in m.edge_spawns:
		var c := _px(Iso.tile_to_world(s))
		var rad := maxf(3.0, 14.0 * _scale)
		for y in range(int(c.y - rad), int(c.y + rad) + 1):
			for x in range(int(c.x - rad), int(c.x + rad) + 1):
				if Vector2(x, y).distance_to(c) <= rad and x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height():
					_img.set_pixel(x, y, Color("e0303a"))


## Blends a thick line (pixel coordinates) with `col`.
func _line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var steps := int(a.distance_to(b)) + 1
	var r := width / 2.0
	for k in steps + 1:
		var p := a.lerp(b, float(k) / steps)
		for y in range(int(p.y - r), int(p.y + r) + 1):
			for x in range(int(p.x - r), int(p.x + r) + 1):
				if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height() and Vector2(x, y).distance_to(p) <= r:
					_img.set_pixel(x, y, _img.get_pixel(x, y).blend(Color(col, col.a * 0.5)))


## Blends a convex polygon (pixel coordinates) with `col`.
func _fill_poly(poly: PackedVector2Array, col: Color) -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for y in range(maxi(0, int(r.position.y)), mini(_img.get_height(), int(r.end.y) + 1)):
		for x in range(maxi(0, int(r.position.x)), mini(_img.get_width(), int(r.end.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
				_img.set_pixel(x, y, _img.get_pixel(x, y).blend(col))
