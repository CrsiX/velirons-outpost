class_name MapJson
extends RefCounted
## Maps as JSON files (docs/map-editor-design.md §6): `write` gives the
## canonical text (2-space indent, keys in a fixed order, sorted lists, one
## object per line), so the same map always gives the same bytes; `read` takes
## any valid JSON of the format (minified, keys in any order, whole floats,
## missing optional keys, a BOM, CRLF) and refuses anything else with a list
## of every problem and where it is.

const FORMAT := "velirons-outpost-map"
const VERSION := 2
## One character per tile; the index is the MapData.Terrain value.
const TERRAIN_CODES := ".RFDMWSL"
## One character per tile; the index is the Config.ZONE_ORDER index.
const ZONE_CODES := "mophswa"
const PALETTE_LETTERS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const UNDER := {"water": MapData.Terrain.WATER, "shallow": MapData.Terrain.SHALLOW, "lava": MapData.Terrain.LAVA}
const PIECE_KINDS: Array[String] = ["wall", "gate", "wall_tower", "hut"]
const OBJECT_KINDS: Array[String] = ["treasure", "camp", "unlock", "ruin", "lair", "mine"]
const REWARD_KEYS: Array[String] = ["gold", "food", "materials", "hero_xp", "heal_units", "relic"]

const TOP_KEYS: Array[String] = [
	"format", "format_version", "name", "author", "description", "size", "map_type", "origin",
	"legend", "layers", "crossings", "volcanoes", "water_spawns", "villages", "village_links", "objects",
]
const TOP_REQUIRED: Array[String] = ["format", "format_version", "name", "size", "map_type", "layers", "villages", "objects"]
const LAYER_KEYS: Array[String] = ["terrain", "zone", "slice", "beach", "props", "decor"]
const LAYER_REQUIRED: Array[String] = ["terrain", "zone", "slice", "props"]
const ORIGIN_KEYS: Array[String] = ["generator_seed", "edited", "game_version"]
## Per object kind: its own fields (besides id, kind, tile, size) and which of them are required.
const OBJECT_FIELDS := {
	"treasure": {"fields": ["treasure", "tier", "reward"], "required": ["treasure", "tier"]},
	"camp": {"fields": ["tier", "guards", "monsters"], "required": ["tier", "guards"]},
	"unlock": {"fields": ["site", "unlocks", "wave"], "required": ["site"]},
	"ruin": {"fields": [], "required": []},
	"lair": {"fields": ["art", "front"], "required": ["art", "front"]},
	"mine": {"fields": ["front"], "required": ["front"]},
}

const LEGEND := {
	"terrain": ". grass, R road, F forest, D desert, M mountain, W deep water, S shallow water, L lava",
	"zone": "m meadow, o oak, p pine, h heath, s steppe, w swamp, a ash",
	"slice": "0-7 the slice (village area) a tile belongs to",
	"beach": "b beach, . none",
	"props": ". none, else a letter of props.palette",
	"decor": ". none, else a letter of decor.palette",
}


# --- writing ---------------------------------------------------------------------------------

## The canonical JSON text of `m` (its `meta` gives the name and the rest).
static func write(m: MapData) -> String:
	var meta := m.meta
	# A map without a file behind it (generated, baked): its seed is where it came from.
	var origin: Dictionary = meta.get("origin", {"generator_seed": m.seed_value if m.seed_value != 0 else null})
	var out := PackedStringArray()
	out.append("{")
	out.append('  "format": %s,' % _q(FORMAT))
	out.append('  "format_version": %d,' % VERSION)
	out.append('  "name": %s,' % _q(map_name(m)))
	out.append('  "author": %s,' % _q(str(meta.get("author", ""))))
	out.append('  "description": %s,' % _q(str(meta.get("description", ""))))
	out.append('  "size": %d,' % m.size)
	out.append('  "map_type": %s,' % _q(m.map_type))
	out.append('  "origin": {')
	var gs = origin.get("generator_seed", null)
	out.append('    "generator_seed": %s,' % ("null" if gs == null else str(int(gs))))
	out.append('    "edited": %s,' % ("true" if bool(origin.get("edited", false)) else "false"))
	out.append('    "game_version": %s' % _q(str(origin.get("game_version", game_version()))))
	out.append("  },")
	out.append('  "legend": {')
	for i in LAYER_KEYS.size():
		var k := LAYER_KEYS[i]
		out.append('    %s: %s%s' % [_q(k), _q(LEGEND[k]), "," if i < LAYER_KEYS.size() - 1 else ""])
	out.append("  },")
	out.append('  "layers": {')
	_rows(out, "terrain", _code_rows(m, func(i: int) -> String: return TERRAIN_CODES[m.terrain[i]]), true)
	_rows(out, "zone", _code_rows(m, func(i: int) -> String: return ZONE_CODES[m.zones[i]]), true)
	_rows(out, "slice", _code_rows(m, func(i: int) -> String: return str(m.slice_of[i])), true)
	_rows(out, "beach", _code_rows(m, func(i: int) -> String: return "b" if m.beaches.has(Vector2i(i % m.size, i / m.size)) else "."), true)
	_palette_layer(out, "props", m, m.props, true)
	_palette_layer(out, "decor", m, m.decor, false)
	out.append("  },")
	var cross: Array = m.crossings.keys()
	cross.sort_custom(MapData.row_order)
	var cl := PackedStringArray()
	for t: Vector2i in cross:
		var under := int(m.crossings[t][1])
		cl.append('{"tile": %s, "art": %s, "under": %s}' % [_t(t), _q(str(m.crossings[t][0])), _q(UNDER.find_key(under))])
	_list(out, "crossings", cl, "  ", true)
	var vol: Array = m.volcanoes.duplicate()
	vol.sort_custom(MapData.row_order)
	out.append('  "volcanoes": %s,' % _tiles(vol))
	var ws: Array = m.water_spawns.duplicate()
	ws.sort_custom(MapData.row_order)
	out.append('  "water_spawns": %s,' % _tiles(ws))
	out.append('  "villages": [' if not m.villages.is_empty() else '  "villages": [],')
	for i in m.villages.size():
		var v: Dictionary = m.villages[i]
		out.append("    {")
		out.append('      "id": %d,' % i)
		out.append('      "center": %s,' % _t(v["center"]))
		var sp: Array = (v.get("home_spawns", []) as Array).duplicate()
		sp.sort_custom(MapData.row_order)
		out.append('      "spawns": %s,' % _tiles(sp))
		var pieces := m.village_pieces(i)
		pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return MapData.row_order(a["tile"], b["tile"]))
		var pl := PackedStringArray()
		for p in pieces:
			pl.append('{"kind": %s, "tile": %s, "flip": %s}' % [_q(p["kind"]), _t(p["tile"]), "true" if p["flip"] else "false"])
		_list(out, "pieces", pl, "      ", false)
		out.append("    }" + ("," if i < m.villages.size() - 1 else ""))
	if not m.villages.is_empty():
		out.append("  ],")
	var links: Array = []
	for l in m.village_links:
		links.append(Vector2i(mini(l.x, l.y), maxi(l.x, l.y)))
	links.sort_custom(MapData.row_order)
	var ll := PackedStringArray()
	for l: Vector2i in links:
		ll.append("[%d, %d]" % [l.x, l.y])
	out.append('  "village_links": [%s],' % ", ".join(ll))
	var ol := PackedStringArray()
	for i in m.objects.size():
		if m.objects[i].get("sack", false):
			continue  # (dropped loot only exists in a running game)
		ol.append(_object_line(m.objects[i], i))
	_list(out, "objects", ol, "  ", false)
	out.append("}")
	return "\n".join(out) + "\n"


## The map's name for files and lists ("Untitled map" if it has none).
static func map_name(m: MapData) -> String:
	var n := str(m.meta.get("name", "")).strip_edges()
	return n if n != "" else "Untitled map"


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


static func _q(s: String) -> String:
	return JSON.stringify(s)


static func _t(t: Vector2i) -> String:
	return "[%d, %d]" % [t.x, t.y]


static func _tiles(list: Array) -> String:
	var parts := PackedStringArray()
	for t: Vector2i in list:
		parts.append(_t(t))
	return "[%s]" % ", ".join(parts)


## `"key": [` + one line per entry + `]` (or `[]`), at `indent`.
static func _list(out: PackedStringArray, key: String, lines: PackedStringArray, indent: String, comma: bool) -> void:
	var end := "," if comma else ""
	if lines.is_empty():
		out.append('%s%s: []%s' % [indent, _q(key), end])
		return
	out.append('%s%s: [' % [indent, _q(key)])
	for i in lines.size():
		out.append("%s  %s%s" % [indent, lines[i], "," if i < lines.size() - 1 else ""])
	out.append("%s]%s" % [indent, end])


static func _code_rows(m: MapData, code: Callable) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in m.size:
		var row := PackedStringArray()
		for x in m.size:
			row.append(code.call(y * m.size + x))
		rows.append("".join(row))
	return rows


static func _rows(out: PackedStringArray, key: String, rows: PackedStringArray, comma: bool, indent := "    ") -> void:
	var quoted := PackedStringArray()
	for r in rows:
		quoted.append(_q(r))
	_list(out, key, quoted, indent, comma)


## A layer of art names: a palette (letters in order of first use) and rows.
static func _palette_layer(out: PackedStringArray, key: String, m: MapData, arts: Dictionary, comma: bool) -> void:
	var letters := {}
	var rows := PackedStringArray()
	for y in m.size:
		var row := PackedStringArray()
		for x in m.size:
			var t := Vector2i(x, y)
			if not arts.has(t):
				row.append(".")
				continue
			var art := str(arts[t])
			if not letters.has(art):
				letters[art] = PALETTE_LETTERS[mini(letters.size(), PALETTE_LETTERS.length() - 1)]
			row.append(letters[art])
		rows.append("".join(row))
	out.append('    %s: {' % _q(key))
	if letters.is_empty():
		out.append('      "palette": {},')
	else:
		out.append('      "palette": {')
		var arts_in_order: Array = letters.keys()
		for i in arts_in_order.size():
			out.append('        %s: %s%s' % [_q(letters[arts_in_order[i]]), _q(arts_in_order[i]), "," if i < arts_in_order.size() - 1 else ""])
		out.append("      },")
	_rows(out, "rows", rows, false, "      ")
	out.append("    }" + ("," if comma else ""))


static func _object_line(o: Dictionary, i: int) -> String:
	var parts := PackedStringArray()
	parts.append('"id": %d' % (i + 1))
	parts.append('"kind": %s' % _q(o["kind"]))
	parts.append('"tile": %s' % _t(o["tile"]))
	parts.append('"size": %d' % int(o.get("size", 1)))
	match str(o["kind"]):
		"treasure":
			parts.append('"treasure": %s' % _q(o["treasure"]))
			parts.append('"tier": %d' % int(o["tier"]))
			var reward: Dictionary = o.get("reward", {})
			var rp := PackedStringArray()
			for k in REWARD_KEYS:
				if reward.has(k):
					rp.append("%s: %s" % [_q(k), _q(str(reward[k])) if k == "relic" else str(int(reward[k]))])
			parts.append('"reward": {%s}' % ", ".join(rp))
		"camp":
			parts.append('"tier": %d' % int(o["tier"]))
			parts.append('"guards": %d' % (int(o["guards"]) + 1))
			var mons := PackedStringArray()
			for k in o.get("monsters", []):
				mons.append(_q(str(k)))
			parts.append('"monsters": [%s]' % ", ".join(mons))
		"unlock":
			parts.append('"site": %s' % _q(o["site"]))
			parts.append('"unlocks": %s' % _q(o["unlocks"]))
			parts.append('"wave": %d' % int(o["wave"]))
		"lair":
			parts.append('"art": %s' % _q(o["art"]))
			parts.append('"front": %s' % _t(o["front"]))
		"mine":
			parts.append('"front": %s' % _t(o["front"]))
	return "{%s}" % ", ".join(parts)


## Each object's slice: its tile's; a camp's is its treasure's (it may stand
## just over the border), as the generator makes them.
static func derive_object_slices(m: MapData) -> void:
	for o in m.objects:
		o["slice"] = int(m.slice_of[m.index(o["tile"])]) if m.in_bounds(o["tile"]) else 0
	for o in m.objects:
		var g := int(o.get("guards", -1))
		if o["kind"] == "camp" and g >= 0 and g < m.objects.size():
			o["slice"] = m.objects[g]["slice"]


## An object's art where it follows from its fields (all but a lair's).
static func object_art(o: Dictionary) -> String:
	match str(o["kind"]):
		"treasure": return str(o["treasure"])
		"camp": return "camp"
		"unlock": return str(o["site"]) if o["site"] == "stone_circle" else str(o["site"]) + "_ruin"
		"ruin": return "watchtower_ruin"
		"mine": return "mine"
	return str(o.get("art", ""))


# --- reading ---------------------------------------------------------------------------------

## Reads a map file's text. Returns {"map": MapData, "errors": []} or, when the
## file breaks the format, {"map": null, "errors": [every problem, with where]}.
static func read(text: String) -> Dictionary:
	var r := _Reader.new()
	var m := r.run(text)
	return {"map": m if r.errors.is_empty() else null, "errors": r.errors}


class _Reader:
	var errors: Array[String] = []
	var size := 0

	func err(where: String, what: String) -> void:
		if errors.size() < 200:
			errors.append("%s: %s" % [where, what] if where != "" else what)

	func run(text: String) -> MapData:
		if text.begins_with("﻿"):
			text = text.substr(1)
		var json := JSON.new()
		if json.parse(text) != OK:
			err("", "not valid JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
			return null
		var d = json.data
		if not (d is Dictionary):
			err("", "the file must hold a JSON object")
			return null
		_keys(d, TOP_KEYS, TOP_REQUIRED, "")
		if d.get("format") != FORMAT:
			err("format", "must be \"%s\"" % FORMAT)
			return null
		var version = whole(d.get("format_version"), "format_version")
		if version == null:
			return null
		if version > VERSION:
			err("format_version", "%d is newer than this game knows (%d): update the game" % [version, VERSION])
			return null
		if version < 1:
			err("format_version", "must be at least 1")
			return null
		var sz = whole(d.get("size"), "size")
		if sz == null:
			return null
		if not Config.MAP_SIZES.has(sz):
			err("size", "must be one of %s" % str(Config.MAP_SIZES))
			return null
		size = sz
		var m := MapData.new(size)
		var meta := {
			"name": text_field(d, "name", 1, int(Config.EDITOR["name_max"]), ""),
			"author": text_field(d, "author", 0, int(Config.EDITOR["author_max"]), ""),
			"description": text_field(d, "description", 0, int(Config.EDITOR["description_max"]), ""),
		}
		var mt = text_field(d, "map_type", 1, int(Config.EDITOR["map_type_max"]), "temperate")
		if mt != null and RegEx.create_from_string("^[A-Za-z0-9 _\\-]+$").search(mt) == null:
			err("map_type", "only letters, digits, spaces, _ and - please")
		m.map_type = str(mt) if mt != null else "temperate"
		meta["origin"] = _origin(d.get("origin", {}))
		m.seed_value = int(meta["origin"]["generator_seed"]) if meta["origin"]["generator_seed"] != null else 0
		m.meta = meta
		if d.has("legend") and not (d["legend"] is Dictionary):
			err("legend", "must be an object")
		_layers(d.get("layers"), m)
		_crossings(d.get("crossings", []), m)
		var vol := tile_list(d.get("volcanoes", []), "volcanoes")
		m.volcanoes.assign(vol)
		m.water_spawns.assign(tile_list(d.get("water_spawns", []), "water_spawns"))  # (format 2; none in a format 1 file)
		_villages(d.get("villages"), m)
		_links(d.get("village_links", []), m)
		_objects(d.get("objects"), m)
		if not errors.is_empty():
			return null
		m.derive()
		MapJson.derive_object_slices(m)
		return m

	# - basic values -

	func _keys(d: Dictionary, allowed: Array, required: Array, where: String) -> void:
		for k in d:
			if not allowed.has(k):
				err(_at(where, str(k)), "unknown key")
		for k in required:
			if not d.has(k):
				err(_at(where, k), "missing")

	func _at(where: String, key: String) -> String:
		return key if where == "" else "%s.%s" % [where, key]

	## A whole number (written as 37 or 37.0), else null (and an error).
	func whole(v, where: String):
		if v is int:
			return v
		if v is float and is_finite(v) and v == floorf(v) and absf(v) < 1e9:
			return int(v)
		err(where, "must be a whole number")
		return null

	func text_field(d: Dictionary, key: String, lo: int, hi: int, default: String):
		if not d.has(key):
			return default
		var v = d[key]
		if not (v is String):
			err(key, "must be text")
			return null
		var s: String = v
		if key == "name":
			s = s.strip_edges()
		if s.length() < lo or s.length() > hi:
			err(key, "must be %d to %d characters long" % [lo, hi])
			return null
		return s

	func tile(v, where: String):
		if not (v is Array) or (v as Array).size() != 2:
			err(where, "must be a tile [x, y]")
			return null
		var x = whole(v[0], where + "[0]")
		var y = whole(v[1], where + "[1]")
		if x == null or y == null:
			return null
		var t := Vector2i(int(x), int(y))
		if t.x < 0 or t.y < 0 or t.x >= size or t.y >= size:
			err(where, "[%d, %d] is outside the map (0 to %d)" % [t.x, t.y, size - 1])
			return null
		return t

	func tile_list(v, where: String) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		if not (v is Array):
			err(where, "must be a list")
			return out
		for i in (v as Array).size():
			var t = tile(v[i], "%s[%d]" % [where, i])
			if t != null:
				if out.has(t):
					err("%s[%d]" % [where, i], "[%d, %d] is listed twice" % [t.x, t.y])
				else:
					out.append(t)
		out.sort_custom(MapData.row_order)
		return out

	func _origin(v) -> Dictionary:
		var o := {"generator_seed": null, "edited": false, "game_version": ""}
		if not (v is Dictionary):
			err("origin", "must be an object")
			return o
		_keys(v, ORIGIN_KEYS, [], "origin")
		if v.get("generator_seed") != null:
			var s = whole(v["generator_seed"], "origin.generator_seed")
			o["generator_seed"] = s
		if v.has("edited"):
			if v["edited"] is bool:
				o["edited"] = v["edited"]
			else:
				err("origin.edited", "must be true or false")
		if v.has("game_version"):
			if v["game_version"] is String and (v["game_version"] as String).length() <= 40:
				o["game_version"] = v["game_version"]
			else:
				err("origin.game_version", "must be text of at most 40 characters")
		return o

	# - layers -

	func _layers(v, m: MapData) -> void:
		if not (v is Dictionary):
			err("layers", "must be an object")
			return
		_keys(v, LAYER_KEYS, LAYER_REQUIRED, "layers")
		var terrain := code_rows(v.get("terrain"), "layers.terrain", TERRAIN_CODES)
		if not terrain.is_empty():
			m.terrain = terrain
		var zones := code_rows(v.get("zone"), "layers.zone", ZONE_CODES)
		if not zones.is_empty():
			m.zones = zones
		var slices := code_rows(v.get("slice"), "layers.slice", "01234567")
		if not slices.is_empty():
			m.slice_of = slices
		if v.has("beach"):
			var beach := code_rows(v["beach"], "layers.beach", ".b")
			for i in beach.size():
				if beach[i] == 1:
					m.beaches[Vector2i(i % size, i / size)] = true
		m.props = palette_layer(v.get("props"), "layers.props")
		if v.has("decor"):
			m.decor = palette_layer(v["decor"], "layers.decor")

	## A layer of `size` rows of `size` characters, each one of `codes`: the
	## code indices, row by row (empty after an error).
	func code_rows(v, where: String, codes: String) -> PackedByteArray:
		var out := PackedByteArray()
		if v == null:
			return out
		if not (v is Array):
			err(where, "must be a list of %d rows" % size)
			return out
		var rows: Array = v
		if rows.size() != size:
			err(where, "has %d rows, needs %d" % [rows.size(), size])
			return out
		out.resize(size * size)
		var ok := true
		for y in size:
			var row = rows[y]
			if not (row is String):
				err("%s row %d" % [where, y], "must be text")
				ok = false
				continue
			var s: String = row
			if s.length() != size:
				err("%s row %d" % [where, y], "has %d characters, needs %d" % [s.length(), size])
				ok = false
				continue
			for x in size:
				var c := codes.find(s[x])
				if c < 0:
					err("%s row %d, column %d" % [where, y, x], "unknown code \"%s\"" % s[x])
					ok = false
					if errors.size() >= 200:
						return PackedByteArray()
					continue
				out[y * size + x] = c
		return out if ok else PackedByteArray()

	## {"palette": {letter: art}, "rows": [...]} -> tile -> art.
	func palette_layer(v, where: String) -> Dictionary:
		var out := {}
		if v == null:
			return out
		if not (v is Dictionary):
			err(where, "must be an object with \"palette\" and \"rows\"")
			return out
		_keys(v, ["palette", "rows"], ["palette", "rows"], where)
		var pal := {}
		var pv = v.get("palette", {})
		if not (pv is Dictionary):
			err(where + ".palette", "must be an object")
			return out
		for letter in pv:
			if not (letter is String) or (letter as String).length() != 1 or PALETTE_LETTERS.find(letter) < 0:
				err("%s.palette" % where, "\"%s\" is not a palette letter (a-z, A-Z, 0-9)" % str(letter))
				continue
			var art = pv[letter]
			if not (art is String) or not ArtManifest.SPRITES.has(art):
				err("%s.palette.%s" % [where, letter], "unknown art \"%s\"" % str(art))
				continue
			pal[letter] = art
		var rows = v.get("rows")
		if not (rows is Array) or (rows as Array).size() != size:
			err(where + ".rows", "must be a list of %d rows" % size)
			return out
		for y in size:
			var row = rows[y]
			if not (row is String) or (row as String).length() != size:
				err("%s.rows row %d" % [where, y], "must be text of %d characters" % size)
				continue
			var s: String = row
			for x in size:
				if s[x] == ".":
					continue
				if not pal.has(s[x]):
					err("%s.rows row %d, column %d" % [where, y, x], "letter \"%s\" isn't in the palette" % s[x])
					if errors.size() >= 200:
						return out
					continue
				out[Vector2i(x, y)] = pal[s[x]]
		return out

	# - crossings, villages, objects -

	func _crossings(v, m: MapData) -> void:
		if not (v is Array):
			err("crossings", "must be a list")
			return
		for i in (v as Array).size():
			var where := "crossings[%d]" % i
			var c = v[i]
			if not (c is Dictionary):
				err(where, "must be an object")
				continue
			_keys(c, ["tile", "art", "under"], ["tile", "art", "under"], where)
			var t = tile(c.get("tile"), where + ".tile")
			var art = c.get("art")
			if not (art is String) or not ArtManifest.SPRITES.has(art):
				err(where + ".art", "unknown art \"%s\"" % str(art))
				continue
			if not UNDER.has(c.get("under")):
				err(where + ".under", "must be \"water\", \"shallow\" or \"lava\"")
				continue
			if t == null:
				continue
			if m.crossings.has(t):
				err(where, "a second crossing on [%d, %d]" % [t.x, t.y])
				continue
			if not m.terrain.is_empty() and m.get_terrain(t) != MapData.Terrain.ROAD:
				err(where, "[%d, %d] isn't road in layers.terrain" % [t.x, t.y])
				continue
			m.crossings[t] = [art, int(UNDER[c["under"]])]

	func _villages(v, m: MapData) -> void:
		if not (v is Array):
			err("villages", "must be a list")
			return
		var list: Array = v
		var slots := int(Config.MAP_SIZE_SLOTS.get(size, 8))
		if list.size() > slots:
			err("villages", "%d villages, but a %dx%d map holds at most %d" % [list.size(), size, size, slots])
			return
		var by_id := {}
		var used := {}
		for i in list.size():
			var where := "villages[%d]" % i
			var d = list[i]
			if not (d is Dictionary):
				err(where, "must be an object")
				continue
			_keys(d, ["id", "center", "spawns", "pieces"], ["id", "center", "pieces"], where)
			var id = whole(d.get("id"), where + ".id")
			if id == null:
				continue
			if id < 0 or id >= list.size():
				err(where + ".id", "ids must be 0 to %d" % (list.size() - 1))
				continue
			if by_id.has(id):
				err(where + ".id", "id %d is used twice" % id)
				continue
			var center = tile(d.get("center"), where + ".center")
			var spawns := tile_list(d.get("spawns", []), where + ".spawns")
			var pieces: Array[Dictionary] = []
			var pv = d.get("pieces")
			if not (pv is Array):
				err(where + ".pieces", "must be a list")
				continue
			for j in (pv as Array).size():
				var pw := "%s.pieces[%d]" % [where, j]
				var p = pv[j]
				if not (p is Dictionary):
					err(pw, "must be an object")
					continue
				_keys(p, ["kind", "tile", "flip"], ["kind", "tile"], pw)
				if not PIECE_KINDS.has(p.get("kind")):
					err(pw + ".kind", "must be one of %s" % ", ".join(PIECE_KINDS))
					continue
				var t = tile(p.get("tile"), pw + ".tile")
				var flip = p.get("flip", false)
				if not (flip is bool):
					err(pw + ".flip", "must be true or false")
					continue
				if t == null:
					continue
				if used.has(t):
					err(pw, "a second village piece on [%d, %d]" % [t.x, t.y])
					continue
				used[t] = true
				pieces.append({"kind": p["kind"], "tile": t, "flip": flip})
			if center == null:
				continue
			pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return MapData.row_order(a["tile"], b["tile"]))
			by_id[id] = {"center": center, "home_spawns": spawns, "pieces": pieces}
		if not errors.is_empty():
			return
		for id in list.size():
			var e: Dictionary = by_id[id]
			m.villages.append({"center": e["center"], "home_spawns": e["home_spawns"]})
			for p in e["pieces"]:
				p["owner"] = id
				m.village_layout.append(p)

	func _links(v, m: MapData) -> void:
		if not (v is Array):
			err("village_links", "must be a list")
			return
		var seen := {}
		for i in (v as Array).size():
			var where := "village_links[%d]" % i
			var l = v[i]
			if not (l is Array) or (l as Array).size() != 2:
				err(where, "must be a pair of village ids [a, b]")
				continue
			var a = whole(l[0], where + "[0]")
			var b = whole(l[1], where + "[1]")
			if a == null or b == null:
				continue
			if a == b or a < 0 or b < 0 or a >= m.villages.size() or b >= m.villages.size():
				err(where, "must name two different villages (0 to %d)" % (m.villages.size() - 1))
				continue
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not seen.has(key):
				seen[key] = true
				m.village_links.append(key)
		m.village_links.sort_custom(MapData.row_order)

	func _objects(v, m: MapData) -> void:
		if not (v is Array):
			err("objects", "must be a list")
			return
		var by_id := {}
		for i in (v as Array).size():
			var where := "objects[%d]" % i
			var o = v[i]
			if not (o is Dictionary):
				err(where, "must be an object")
				continue
			var kind = o.get("kind")
			if not OBJECT_KINDS.has(kind):
				err(where + ".kind", "must be one of %s" % ", ".join(OBJECT_KINDS))
				continue
			var spec: Dictionary = OBJECT_FIELDS[kind]
			var allowed: Array = ["id", "kind", "tile", "size"] + spec["fields"]
			_keys(o, allowed, ["id", "kind", "tile"] + spec["required"], where)
			var id = whole(o.get("id"), where + ".id")
			if id == null:
				continue
			if id < 1:
				err(where + ".id", "must be 1 or more")
				continue
			if by_id.has(id):
				err(where + ".id", "id %d is used twice" % id)
				continue
			var t = tile(o.get("tile"), where + ".tile")
			var sz = whole(o.get("size", 1), where + ".size")
			if sz != null and (sz < 1 or sz > 3):
				err(where + ".size", "must be 1 to 3")
				sz = null
			if t == null or sz == null:
				continue
			var d := {"kind": kind, "tile": t, "size": sz}
			if _object_fields(o, d, where):
				by_id[id] = d
		if not errors.is_empty():
			return
		var ids: Array = by_id.keys()
		ids.sort()
		var index_of := {}
		for k in ids.size():
			index_of[ids[k]] = k
		for id in ids:
			m.objects.append(by_id[id])
		# Camps name their treasure by id; in memory both point at each other by index.
		for o in m.objects:
			if o["kind"] == "treasure":
				o["guard"] = -1
		for k in m.objects.size():
			var o := m.objects[k]
			if o["kind"] != "camp":
				continue
			var gid: int = o["guards"]
			if not index_of.has(gid) or m.objects[index_of[gid]]["kind"] != "treasure":
				err("objects (id %d).guards" % ids[k], "%d isn't the id of a treasure" % gid)
				continue
			var tr := m.objects[index_of[gid]]
			if tr["guard"] != -1:
				err("objects (id %d).guards" % ids[k], "treasure %d is guarded by two camps" % gid)
				continue
			o["guards"] = index_of[gid]
			tr["guard"] = k

	## The kind's own fields of object `o` into `d` (with the art); false on an error.
	func _object_fields(o: Dictionary, d: Dictionary, where: String) -> bool:
		var n := errors.size()
		match str(d["kind"]):
			"treasure":
				var kind = o.get("treasure")
				if not Config.TREASURES.has(kind):
					err(where + ".treasure", "unknown treasure \"%s\"" % str(kind))
				d["treasure"] = kind
				d["tier"] = _tier(o.get("tier"), where + ".tier")
				d["reward"] = _reward(o.get("reward", {}), where + ".reward")
			"camp":
				d["tier"] = _tier(o.get("tier"), where + ".tier")
				d["guards"] = whole(o.get("guards"), where + ".guards")
				var tier: int = d["tier"] if d["tier"] != null else 1
				var mons = o.get("monsters", Config.CAMP_MONSTERS[clampi(tier, 1, 3) - 1])
				var list: Array = []
				if not (mons is Array):
					err(where + ".monsters", "must be a list of enemy kinds")
				else:
					for k in mons:
						if not Config.ENEMIES.has(k):
							err(where + ".monsters", "unknown enemy \"%s\"" % str(k))
						list.append(k)
				d["monsters"] = list
			"unlock":
				var site = o.get("site")
				if not Config.UNLOCK_SITES.has(site):
					err(where + ".site", "unknown site \"%s\"" % str(site))
					return false
				var unlocks = o.get("unlocks", Config.UNLOCK_SITES[site]["unlocks"])
				if not (unlocks is String) or not (Config.MILITARY.has(unlocks) or Config.CIVILIANS.has(unlocks)):
					err(where + ".unlocks", "unknown unit \"%s\"" % str(unlocks))
				d["site"] = site
				d["unlocks"] = unlocks
				var wave = whole(o.get("wave", Config.UNLOCK_SITES[site]["wave"]), where + ".wave")
				if wave != null and wave < 1:
					err(where + ".wave", "must be 1 or more")
				d["wave"] = wave
			"lair":
				var art = o.get("art")
				if not (art is String) or not (art as String).begins_with("lair_") or not ArtManifest.SPRITES.has(art):
					err(where + ".art", "unknown lair art \"%s\"" % str(art))
				d["art"] = art
				d["front"] = tile(o.get("front"), where + ".front")
			"mine":
				d["front"] = tile(o.get("front"), where + ".front")
		if errors.size() > n:
			return false
		if not d.has("art"):
			d["art"] = MapJson.object_art(d)
		return true

	func _tier(v, where: String):
		var t = whole(v, where)
		if t != null and (t < 1 or t > 3):
			err(where, "must be 1 to 3")
			return null
		return t

	func _reward(v, where: String) -> Dictionary:
		var out := {}
		if not (v is Dictionary):
			err(where, "must be an object")
			return out
		_keys(v, REWARD_KEYS, [], where)
		for k in v:
			if not REWARD_KEYS.has(k):
				continue
			if k == "relic":
				if not Config.RELICS.has(v[k]):
					err(where + ".relic", "unknown relic \"%s\"" % str(v[k]))
				out[k] = v[k]
			else:
				var n = whole(v[k], "%s.%s" % [where, k])
				if n != null and n < 0:
					err("%s.%s" % [where, k], "must be 0 or more")
				out[k] = n
		return out
