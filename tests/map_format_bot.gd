extends "res://tests/bot_base.gd"
## End-to-end tests of the map file format (docs/map-editor-design.md §6, §10)
## on generated maps: MapData (in memory) <-> JSON (text) <-> packed bytes
## (MapData.to_bytes, as in BakedMap and the co-op start), the canonical
## export, the tolerant import and every kind of refusal; then maps from JSON
## played: a wave on a loaded map, a non-standard village with one approach,
## and a village nobody plays (ownerless ruins). Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/map_format_bot.tscn

## [map type, size, villages, seed] of the generated maps the conversions run on.
const MAPS: Array = [
	["temperate", 75, 1, 38], ["highlands", 75, 1, 5], ["coast", 75, 1, 11], ["desert", 75, 1, 7],
	["volcanic", 75, 1, 3], ["temperate", 50, 1, 21], ["coast", 100, 3, 4], ["temperate", 200, 1, 9],
]


func _run() -> void:
	Engine.time_scale = 1.0
	var small: MapData = null
	var two: MapData = null
	for spec in MAPS:
		var m := await _generated(spec)
		if spec[1] == 50:
			small = m
		_generated_material(m, str(spec[0]))
		_conversions(m, "%s %dx%d, %d %s" % [spec[0], spec[1], spec[1], spec[2], "village" if spec[2] == 1 else "villages"])
	_title_map()
	_tolerant(small)
	_refusals(small)
	_materials(small)
	_sizes()
	await _play_loaded()
	await _play_odd_village()
	await _play_materials()
	two = MapGenerator.generate(12, 2, "temperate")
	two.meta = {"name": "Two villages"}
	await _play_ownerless(MapJson.read(MapJson.write(two))["map"])
	Settings.custom_map = null
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _generated(spec: Array) -> MapData:
	await frames(1)
	var t0 := Time.get_ticks_msec()
	var m := MapGenerator.generate(int(spec[3]), int(spec[2]), str(spec[0]), int(spec[1]))
	m.meta = {"name": "Test %s %d" % [spec[0], spec[1]], "author": "bot", "description": "A generated map.\nSecond line \"quoted\".",
		"origin": {"generator_seed": int(spec[3]), "edited": false, "game_version": "test"}}
	print("  (generated %s %dx%d in %.1f s)" % [spec[0], m.size, m.size, (Time.get_ticks_msec() - t0) / 1000.0])
	return m


# --- conversions -----------------------------------------------------------------------------

func _conversions(g: MapData, what: String) -> void:
	var j1 := MapJson.write(g)
	check(j1 == MapJson.write(g), "%s: exporting twice gives the same bytes" % what)
	var r := MapJson.read(j1)
	var m1: MapData = r["map"]
	check(m1 != null and (r["errors"] as Array).is_empty(), "%s: the export reads back without errors %s" % [what, str((r["errors"] as Array).slice(0, 3))])
	if m1 == null:
		return
	var diff := differ(g, m1)
	check(diff == "", "%s: MapData -> JSON -> MapData: equal in every stored field%s" % [what, "" if diff == "" else " (" + diff + ")"])
	check(MapJson.write(m1) == j1, "%s: JSON -> MapData -> JSON: byte-identical" % what)
	var m2 := MapData.from_bytes(m1.to_bytes())
	check(MapJson.write(m2) == j1 and differ(m1, m2, true) == "", "%s: MapData -> packed -> MapData -> JSON: the same text" % what)
	var gp := MapData.from_bytes(g.to_bytes())
	check(MapJson.write(gp) == j1, "%s: the generated map packed and unpacked exports the same" % what)
	check(j1.begins_with("{\n  \"format\": \"velirons-outpost-map\",\n  \"format_version\": %d,\n" % MapJson.VERSION) and j1.ends_with("}\n") and not "\t" in j1 and not "\r" in j1, "%s: canonical layout (2-space indent, \\n, a final newline)" % what)
	var lines := j1.split("\n")
	check(lines.size() > g.size * 6 and lines.size() < g.size * 7 + 200 + g.objects.size() + g.crossings.size() + g.village_layout.size(), "%s: one line per row, object, crossing and piece (%d lines)" % [what, lines.size()])
	var errs := MapChecks.errors(MapChecks.run(m1)).map(func(p: Dictionary) -> String: return p["text"])
	check(errs.is_empty(), "%s: a generated map passes the custom map checks %s" % [what, str(errs.slice(0, 3))])
	if m1.villages.size() >= 3:
		_for_game(m1, what)
	var mini_diff := differ(MapJson.read(JSON.stringify(JSON.parse_string(j1)))["map"], m1, true)
	check(mini_diff == "", "%s: minified JSON (keys sorted) reads the same%s" % [what, "" if mini_diff == "" else " (" + mini_diff + ")"])


## Villages 2 and 0 of a map played (in that order): the map remapped for them.
func _for_game(m: MapData, what: String) -> void:
	var g := m.for_game([2, 0])
	check(g.villages.size() == 2 and g.villages[0]["center"] == m.villages[2]["center"] and g.villages[1]["center"] == m.villages[0]["center"], "%s, villages 3 and 1 played: they become villages 1 and 2" % what)
	check(g.abandoned.size() == m.villages.size() - 2 and g.abandoned[0]["center"] == m.villages[1]["center"] and (g.abandoned[0]["pieces"] as Array).size() == 25, "%s: the other village is abandoned, all its pieces kept" % what)
	var s2 := int(m.villages[2]["slice"])
	var ok := true
	for i in m.slice_of.size():
		if (m.slice_of[i] == s2) != (g.slice_of[i] == 0):
			ok = false
			break
	check(ok and int(g.villages[0]["slice"]) == 0 and int(g.villages[1]["slice"]) == 1, "%s: the first played village's slice is slice 0, the second's 1" % what)
	var objs_ok := true
	for i in m.objects.size():
		if (int(m.objects[i]["slice"]) == s2) != (int(g.objects[i]["slice"]) == 0):
			objs_ok = false
	check(objs_ok, "%s: objects keep their slice under its new number" % what)
	var want: Array = (m.villages[2]["home_spawns"] as Array) + (m.villages[0]["home_spawns"] as Array)
	check(_sorted(g.edge_spawns) == _sorted(want) and g.gates.size() == 8, "%s: only the played villages' spawns and gates" % what)
	check(g.village_layout.size() == 50 and g.village_layout.all(func(p: Dictionary) -> bool: return int(p["owner"]) in [0, 1]), "%s: the played villages' pieces, with their new owners" % what)
	check(g.village_links.all(func(l: Vector2i) -> bool: return l.x in [0, 1] and l.y in [0, 1]), "%s: road links only between played villages" % what)
	var back := MapData.from_bytes(g.to_bytes())
	check(back.abandoned.size() == g.abandoned.size() and back.abandoned[0]["center"] == g.abandoned[0]["center"], "%s: the abandoned village travels in the packed map (co-op start)" % what)


## The first stored field where `a` and `b` differ ("" if none); `meta`
## only counts with `with_meta`.
func differ(a: MapData, b: MapData, with_meta: bool = false) -> String:
	if a == null or b == null:
		return "a map is missing"
	if a.size != b.size:
		return "size %d vs %d" % [a.size, b.size]
	for f in ["terrain", "zones", "slice_of"]:
		var pa: PackedByteArray = a.get(f)
		var pb: PackedByteArray = b.get(f)
		if pa != pb:
			for i in pa.size():
				if i >= pb.size() or pa[i] != pb[i]:
					return "%s at %s" % [f, str(Vector2i(i % a.size, i / a.size))]
	for f in ["props", "decor", "crossings", "beaches"]:
		var da: Dictionary = a.get(f)
		var db: Dictionary = b.get(f)
		if da.size() != db.size():
			return "%s: %d vs %d entries" % [f, da.size(), db.size()]
		for k in da:
			if not db.has(k) or str(da[k]) != str(db[k]):
				return "%s at %s: %s vs %s" % [f, str(k), str(da[k]), str(db.get(k))]
	for f in ["volcanoes", "edge_spawns", "gates", "village_links"]:
		if _sorted(a.get(f)) != _sorted(b.get(f)):
			return "%s: %s vs %s" % [f, str(a.get(f)), str(b.get(f))]
	if a.village_rect != b.village_rect:
		return "village_rect"
	if a.villages.size() != b.villages.size():
		return "villages: %d vs %d" % [a.villages.size(), b.villages.size()]
	for i in a.villages.size():
		var va := a.villages[i]
		var vb := b.villages[i]
		for k in ["center", "rect", "slice"]:
			if va.get(k) != vb.get(k):
				return "village %d %s: %s vs %s" % [i, k, str(va.get(k)), str(vb.get(k))]
		for k in ["gates", "home_spawns"]:
			if _sorted(va.get(k, [])) != _sorted(vb.get(k, [])):
				return "village %d %s" % [i, k]
	if a.village_layout.size() != b.village_layout.size():
		return "village_layout: %d vs %d pieces" % [a.village_layout.size(), b.village_layout.size()]
	for i in a.village_layout.size():
		var pa := a.village_layout[i]
		var pb := b.village_layout[i]
		for k in ["kind", "tile", "flip", "owner", "material"]:
			if pa.get(k) != pb.get(k):
				return "village_layout[%d].%s: %s vs %s" % [i, k, str(pa.get(k)), str(pb.get(k))]
	if a.objects.size() != b.objects.size():
		return "objects: %d vs %d" % [a.objects.size(), b.objects.size()]
	for i in a.objects.size():
		var oa := a.objects[i]
		var ob := b.objects[i]
		if oa.keys().size() != ob.keys().size():
			return "objects[%d] (%s): keys %s vs %s" % [i, oa["kind"], str(oa.keys()), str(ob.keys())]
		for k in oa:
			if not ob.has(k) or typeof(oa[k]) != typeof(ob[k]) or (oa[k] != ob[k] if oa[k] is Dictionary else str(oa[k]) != str(ob[k])):
				return "objects[%d].%s: %s vs %s" % [i, k, var_to_str(oa[k]), var_to_str(ob.get(k))]
	if a.slices.size() != b.slices.size():
		return "slices: %d vs %d" % [a.slices.size(), b.slices.size()]
	for i in a.slices.size():
		if not (a.slices[i]["center"] as Vector2).is_equal_approx(b.slices[i]["center"]) or int(a.slices[i].get("tiles", 0)) != int(b.slices[i].get("tiles", 0)):
			return "slice %d: %s vs %s" % [i, str(a.slices[i]), str(b.slices[i])]
	if a.map_type != b.map_type or a.seed_value != b.seed_value:
		return "map type / seed: %s %d vs %s %d" % [a.map_type, a.seed_value, b.map_type, b.seed_value]
	if with_meta and var_to_str(a.meta) != var_to_str(b.meta):
		return "meta: %s vs %s" % [str(a.meta), str(b.meta)]
	return ""


func _sorted(list) -> Array:
	var out: Array = (list as Array).duplicate()
	out.sort_custom(func(x, y) -> bool: return str(x) < str(y))
	return out


## A title map (baked, packed) -> JSON -> MapData -> packed -> MapData.
func _title_map() -> void:
	var baked := BakedMap.load_map(str(Config.TITLE_BACKDROP["map_type"]), int(Config.TITLE_BACKDROP["seed"]))
	check(baked != null, "a title map is baked")
	if baked == null:
		return
	var m := MapJson.read(MapJson.write(baked))["map"] as MapData
	var back := MapData.from_bytes(m.to_bytes()) if m else null
	var diff := differ(baked, back)
	check(m != null and diff == "", "a title map (packed) -> JSON -> MapData -> packed -> MapData: equal%s" % ("" if diff == "" else " (" + diff + ")"))


# --- tolerant import -------------------------------------------------------------------------

func _tolerant(m: MapData) -> void:
	var text := MapJson.write(m)
	var want: MapData = MapJson.read(text)["map"]
	var d: Dictionary = JSON.parse_string(text)
	# Keys in another order (sorted), minified, CRLF and a BOM.
	var variants := {
		"minified with sorted keys": JSON.stringify(d),
		"tab-indented": JSON.stringify(d, "\t"),
		"\\r\\n line ends": text.replace("\n", "\r\n"),
		"a UTF-8 BOM": String.chr(0xFEFF) + text,
		"whole numbers as floats": text.replace("\"size\": %d," % m.size, "\"size\": %d.0," % m.size).replace("\"tier\": 1,", "\"tier\": 1.0,"),
	}
	for what in variants:
		var r := MapJson.read(variants[what])
		check(r["map"] != null and differ(r["map"], want, true) == "", "import accepts %s %s" % [what, str((r["errors"] as Array).slice(0, 2))])
	# Lists in another order, optional keys left out (their defaults are what the file had).
	var e: Dictionary = JSON.parse_string(text)
	(e["objects"] as Array).reverse()
	(e["crossings"] as Array).reverse()
	for v in e["villages"]:
		(v["pieces"] as Array).reverse()
		(v["spawns"] as Array).reverse()
		for p in v["pieces"]:
			if p["flip"] == false:
				p.erase("flip")
	(e["villages"] as Array).reverse()
	for o in e["objects"]:
		if o["size"] == 1.0:
			o.erase("size")
	for k in ["legend", "author", "description"]:
		e.erase(k)
	var r2 := MapJson.read(JSON.stringify(e, "  ", false))
	var got: MapData = r2["map"]
	if got:
		got.meta["author"] = want.meta["author"]
		got.meta["description"] = want.meta["description"]
	check(got != null and differ(got, want, true) == "", "import accepts reordered lists and missing optional keys (flip, size, legend, author, description) %s" % str((r2["errors"] as Array).slice(0, 2)))
	# Origin left out: no seed (0), nothing else changes.
	var f: Dictionary = JSON.parse_string(text)
	f.erase("origin")
	var r3: MapData = MapJson.read(JSON.stringify(f))["map"]
	check(r3 != null and r3.seed_value == 0 and r3.meta["origin"]["generator_seed"] == null, "without \"origin\" the map has no generator seed")
	# Seeds beyond 10^9 (random ones reach 2^32) are read back as they were.
	var big_ok := r3 != null
	for big: int in [4294967295, 9007199254740991]:
		if r3 == null:
			break
		r3.meta["origin"]["generator_seed"] = big
		var rb: MapData = MapJson.read(MapJson.write(r3))["map"]
		big_ok = big_ok and rb != null and rb.seed_value == big
	check(big_ok, "a generator seed up to 2^53 (2^32 - 1, 2^53 - 1) comes back unchanged")


# --- refusals --------------------------------------------------------------------------------

func _refusals(m: MapData) -> void:
	var text := MapJson.write(m)
	var cases: Array = [
		["not JSON at all", func(_d: Dictionary) -> String: return "this is { not json", "not valid JSON"],
		["a list at the top", func(_d: Dictionary) -> String: return "[1, 2]", "must hold a JSON object"],
		["a wrong format", func(d: Dictionary) -> Variant: d["format"] = "something-else"; return d, "format"],
		["a newer version", func(d: Dictionary) -> Variant: d["format_version"] = 99; return d, "newer than this game knows"],
		["a missing required key", func(d: Dictionary) -> Variant: d.erase("objects"); return d, "objects: missing"],
		["an unknown key", func(d: Dictionary) -> Variant: d["extra"] = 1; return d, "extra: unknown key"],
		["an unknown key in an object", func(d: Dictionary) -> Variant: d["objects"][0]["colour"] = "red"; return d, "objects[0].colour: unknown key"],
		["a wrong type", func(d: Dictionary) -> Variant: d["name"] = 12; return d, "name: must be text"],
		["a size that isn't a map size", func(d: Dictionary) -> Variant: d["size"] = 60; return d, "size: must be one of"],
		["a fractional number", func(d: Dictionary) -> Variant: d["villages"][0]["center"] = [3.5, 4]; return d, "must be a whole number"],
		["a short row", func(d: Dictionary) -> Variant: d["layers"]["terrain"][12] = str(d["layers"]["terrain"][12]).substr(1); return d, "layers.terrain row 12: has %d characters" % (m.size - 1)],
		["an unknown code", func(d: Dictionary) -> Variant: d["layers"]["terrain"][12] = "X" + str(d["layers"]["terrain"][12]).substr(1); return d, "layers.terrain row 12, column 0: unknown code \"X\""],
		["an undefined palette letter", func(d: Dictionary) -> Variant: d["layers"]["props"]["rows"][3] = "Z" + str(d["layers"]["props"]["rows"][3]).substr(1); return d, "letter \"Z\" isn't in the palette"],
		["an unknown art", func(d: Dictionary) -> Variant: d["layers"]["props"]["palette"]["a"] = "no_such_art"; return d, "unknown art \"no_such_art\""],
		["an unknown object kind", func(d: Dictionary) -> Variant: d["objects"][0]["kind"] = "dragon"; return d, "objects[0].kind: must be one of"],
		["an unknown enemy in a camp", func(d: Dictionary) -> Variant: return _with_camp(d, ["goblin", "balrog"]), "unknown enemy \"balrog\""],
		["a coordinate outside", func(d: Dictionary) -> Variant: d["objects"][0]["tile"] = [m.size, 3]; return d, "is outside the map"],
		["duplicate ids", func(d: Dictionary) -> Variant: d["objects"][1]["id"] = d["objects"][0]["id"]; return d, "is used twice"],
		["a dangling reference", func(d: Dictionary) -> Variant: return _with_camp(d, ["goblin"], 9999), "9999 isn't the id of a treasure"],
		["too many villages", func(d: Dictionary) -> Variant: d["villages"].append(d["villages"][0].duplicate(true)); return d, "holds at most 1"],
		["a crossing off the road", func(d: Dictionary) -> Variant: d["crossings"] = [{"tile": [0, 0], "art": "tile_ford", "under": "shallow"}]; d["layers"]["terrain"][0] = "." + str(d["layers"]["terrain"][0]).substr(1); return d, "isn't road in layers.terrain"],
		["a bad map type", func(d: Dictionary) -> Variant: d["map_type"] = "<script>"; return d, "map_type: only letters"],
		["a name too long", func(d: Dictionary) -> Variant: d["name"] = "x".repeat(61); return d, "name: must be 1 to 60 characters"],
		["an unknown material", func(d: Dictionary) -> Variant: _piece(d, "wall")["material"] = "marble"; return d, "material: must be one of"],
	]
	for c in cases:
		var d: Dictionary = JSON.parse_string(text)
		var made = (c[1] as Callable).call(d)
		var src: String = made if made is String else JSON.stringify(made)
		var r := MapJson.read(src)
		var errs: Array = r["errors"]
		var named := errs.any(func(e: String) -> bool: return str(c[2]) in e)
		check(r["map"] == null and named, "import refuses %s, naming the place (%s)" % [c[0], errs[0] if not errs.is_empty() else "no error"])


## The first piece of `kind` in the file's first village.
func _piece(d: Dictionary, kind: String) -> Dictionary:
	for p in d["villages"][0]["pieces"]:
		if p["kind"] == kind:
			return p
	return {}


## A camp guarding treasure `guards` (default: the first treasure) with `monsters`.
func _with_camp(d: Dictionary, monsters: Array, guards: int = -1) -> Dictionary:
	var treasure := -1
	var top := 0
	for o in d["objects"]:
		top = maxi(top, int(o["id"]))
		if o["kind"] == "treasure" and treasure < 0:
			treasure = int(o["id"])
	d["objects"].append({"id": top + 1, "kind": "camp", "tile": [1, 1], "size": 1, "tier": 1, "guards": guards if guards >= 0 else treasure, "monsters": monsters})
	return d


# --- materials (docs/siege-design.md §2a) ----------------------------------------------------

## The generator gives a village one material, by map type.
func _generated_material(m: MapData, map_type: String) -> void:
	var want: String = Config.PIECE_MATERIAL_BY_MAP_TYPE.get(map_type, "stone")
	check(m.village_layout.all(func(p: Dictionary) -> bool: return p["material"] == want), "%s: every piece, huts too, is %s" % [map_type, want])


## Mixed materials come back from a file; a file without them (format 4) gets its map type's.
func _materials(m: MapData) -> void:
	var mixed := m.copy()
	var k := 0
	for p in mixed.village_layout:
		p["material"] = Config.PIECE_MATERIAL_ORDER[k % Config.PIECE_MATERIAL_ORDER.size()] if p["kind"] != "hut" else "basalt"
		k += 1
	var text := MapJson.write(mixed)
	var hut_lines := Array(text.split("\n")).filter(func(l: String) -> bool: return '"kind": "hut"' in l)
	check('"material": "wood"' in text and not hut_lines.is_empty() and hut_lines.all(func(l: String) -> bool: return '"material": "basalt"' in l), "the export writes each piece's material, huts too")
	var back: MapData = MapJson.read(text)["map"]
	check(back != null and differ(back, mixed) == "", "every piece keeps its material through a file (%s)" % (differ(back, mixed) if back else "not read"))
	var d: Dictionary = JSON.parse_string(text)
	d["format_version"] = 4
	for p in d["villages"][0]["pieces"]:
		p.erase("material")
	d["map_type"] = "temperate"
	var old: MapData = MapJson.read(JSON.stringify(d))["map"]
	check(old != null and old.village_layout.all(func(p: Dictionary) -> bool: return p["material"] == "stone"), "a format 4 temperate file (no materials) reads as all stone")
	d["map_type"] = "desert"
	var dry: MapData = MapJson.read(JSON.stringify(d))["map"]
	check(dry != null and dry.village_layout.all(func(p: Dictionary) -> bool: return p["material"] == "sandstone"), "a format 4 desert file (no materials) reads as all sandstone, the map type's")


## A village of wood: 60 % of the HP, costs and times, its own art; a sandstone piece among it.
func _play_materials() -> void:
	var g := MapGenerator.generate(38, 1, "temperate")
	g.meta = {"name": "Wooden outpost"}
	var odd := Vector2i(-1, -1)
	for p in g.village_layout:
		p["material"] = "wood"
		if p["kind"] == "wall" and odd.x < 0:
			odd = p["tile"]
			p["material"] = "sandstone"
	Settings.custom_map = MapJson.read(MapJson.write(g))["map"]
	Settings.custom_village = 0
	await _start_game()
	var f := float(Config.PIECE_MATERIALS["wood"]["factor"])
	var wall: StaticPiece = null
	var gate: StaticPiece = null
	var tower: Tower = null
	var other: StaticPiece = null
	for b in game.player_village.buildings():
		if b.tile == odd:
			other = b
		elif b.kind == "wall" and wall == null:
			wall = b
		elif b.kind == "gate" and gate == null:
			gate = b
		elif b.kind == "wall_tower" and tower == null:
			tower = b
	check(wall != null and wall.made_of == "wood" and is_equal_approx(wall.max_hp(), Config.BUILDING_HP["wall"][0] * f) and wall.hp == wall.max_hp(), "a wooden wall has %s %% of a stone wall's HP" % Library._n(f * 100.0))
	check(gate != null and gate.upgrade_cost() == Config.material_cost(Config.PIECE_LEVELS["gate"][1]["cost"], "wood") and int(gate.upgrade_cost()["materials"]) < int(Config.PIECE_LEVELS["gate"][1]["cost"]["materials"]), "its upgrade costs less (%s)" % (str(gate.upgrade_cost()) if gate else ""))
	check(gate != null and is_equal_approx(gate.build_time, float(Config.PIECE_PRICES["gate"]["build_time"]) * f) and gate.materials_spent() == roundi(float(Config.PIECE_PRICES["gate"]["cost"]["materials"]) * f), "and it counts a cheaper price and a shorter build time for repairs")
	check(tower != null and tower.made_of == "wood" and is_equal_approx(tower.hp_at(3), Config.BUILDING_HP["wall_tower"][2] * f) and tower.upgrade_cost() == Config.material_cost(Config.TOWER_LEVELS[1]["cost"], "wood"), "a wooden wall tower too: HP and upgrades")
	check(wall != null and wall._look() == "wood_wall" and tower != null and tower._look() == "wood_wall_tower" and tower._front_art() == "wood_wall_tower_front", "they look wooden")
	check(tower != null and Art.info(tower._art())["platform"] < Art.info("wall_tower")["platform"], "the wooden tower's deck is lower: its unit stands on it")
	check(other != null and other.made_of == "sandstone" and is_equal_approx(other.max_hp(), Config.BUILDING_HP["wall"][0]) and other._look() == "sandstone_wall", "a sandstone wall among them is as strong as stone and looks its own")
	if wall:
		wall.take_damage(wall.max_hp() + 1.0, null)
		check(wall.devastated and wall._look() == "wood_wall_ruin", "a devastated wooden wall shows its own ruin")
	if gate:
		gate.level = 2
		gate.refresh()
		check(gate._look() == "wood_gate_2", "and a gate its level")
	var hut: Hut = game.player_village.intact_huts()[0]
	check(hut.made_of == "wood" and hut.sprite.texture == Art.tex("wood_hut") and hut.max_hp() == 1.0 and hut.build_time == float(Config.BUILDINGS["hut"]["build_time"]), "a hut of wood is a tent, as fragile and as dear as a cabin")
	hut.destroy("test")
	check(hut.sprite.texture == Art.tex("wood_hut_ruin"), "burnt, its ruin")
	await _end_game()
	Settings.custom_map = null


# --- sizes -----------------------------------------------------------------------------------

func _sizes() -> void:
	for n in Config.MAP_SIZES:
		check(Config.MAP_SIZE_SLOTS.has(n), "%dx%d maps have a village limit (%d)" % [n, n, Config.MAP_SIZE_SLOTS.get(n, 0)])
	check(is_equal_approx(Config.gen_area_scale(Config.map_size(1), 1), 1.0) and is_equal_approx(Config.gen_area_scale(Config.map_size(4), 4), 1.0), "the generator's amounts are unscaled at the usual sizes")
	var a := MapGenerator.generate(38, 1, "temperate")
	var b := MapGenerator.generate(38, 1, "temperate", Config.map_size(1))
	check(a.to_bytes() == b.to_bytes(), "asking for the usual size gives the very same map")


# --- playing maps from files -----------------------------------------------------------------

func _start_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await wait_until(func() -> bool: return game.hud != null and game.stats != null and game.player_village.hero != null, 60.0)
	await frames(3)


func _end_game() -> void:
	game.queue_free()
	await frames(3)
	game = null
	Engine.time_scale = 1.0


func _play_loaded() -> void:
	var g := MapGenerator.generate(38, 1, "temperate")
	g.meta = {"name": "Loaded map", "origin": {"generator_seed": 38, "edited": false, "game_version": ""}}
	var m: MapData = MapJson.read(MapJson.write(g))["map"]
	Settings.custom_map = m
	Settings.custom_village = 0
	await _start_game()
	check(game.map.meta.get("name") == "Loaded map" and game.map.size == 75 and game.map.abandoned.is_empty(), "a map from JSON is the game's map")
	check(game.player_village.center == m.villages[0]["center"] and game.player_village.intact_huts().size() == 9, "the village stands where the file says, all its huts intact")
	check(game.player_village.buildings().any(func(b: Building) -> bool: return b is Farm), "the starting farm found a spot of its own")
	game.waves.countdown = 0.5
	var started := await wait_until(func() -> bool: return game.waves.wave == 1 and game.waves.enemies_left() > 0, 30.0)
	check(started, "a wave starts on it")
	Engine.time_scale = 4.0
	var near := await wait_until(func() -> bool: return get_tree().get_nodes_in_group("enemies").any(func(e: Enemy) -> bool: return not e.dead and e.grid_pos.distance_to(Vector2(game.player_village.center)) < 12.0), 120.0)
	check(near, "its enemies come down the roads to the village")
	await _end_game()


## One gate left (the others walled up) and a missing hut: the warnings, no errors, and it plays.
func _play_odd_village() -> void:
	var g := MapGenerator.generate(38, 1, "temperate")
	g.meta = {"name": "Odd village"}
	var m: MapData = MapJson.read(MapJson.write(g))["map"]
	# Keep the gate most spawns reach by road; the other spawns go.
	var keep := Vector2i(-1, -1)
	var reach: Array = []
	for gate: Vector2i in m.villages[0]["gates"]:
		var field := GenChecks.road_field(m, [gate])
		var r: Array = (m.villages[0]["home_spawns"] as Array).filter(func(sp: Vector2i) -> bool: return field[m.index(sp)] < 1 << 29)
		if r.size() > reach.size():
			reach = r
			keep = gate
	check(keep.x >= 0, "a gate some spawn reaches by road")
	var kept: Array[Vector2i] = []
	kept.assign(reach)
	m.villages[0]["home_spawns"] = kept
	for p in m.village_layout:
		if p["kind"] == "gate" and p["tile"] != keep:
			p["kind"] = "wall"
	var dropped := false
	for i in m.village_layout.size():
		if m.village_layout[i]["kind"] == "hut" and not dropped:
			m.village_layout.remove_at(i)
			dropped = true
			break
	m.derive()
	# Lairs and mines whose road only led to a closed gate go too.
	var to_gate := GenChecks.road_field(m, [keep])
	m.objects.assign(m.objects.filter(func(o: Dictionary) -> bool: return not o["kind"] in ["lair", "mine"] or to_gate[m.index(o["front"])] < 1 << 29))
	var problems := MapChecks.run(m)
	var warns: Array = problems.filter(func(p: Dictionary) -> bool: return p["level"] == "warning").map(func(p: Dictionary) -> String: return p["text"])
	check(MapChecks.errors(problems).is_empty(), "one gate and 8 huts: no errors %s" % str(MapChecks.errors(problems).map(func(p: Dictionary) -> String: return p["text"])))
	check(warns.any(func(w: String) -> bool: return "fewer than 2 approaches" in w) and warns.any(func(w: String) -> bool: return "standard layout" in w), "but warnings: one approach, not the standard layout")
	var back: MapData = MapJson.read(MapJson.write(m))["map"]
	check(back != null and back.village_pieces(0).size() == 24 and differ(back, m) == "", "the odd village survives the file as it is")
	Settings.custom_map = back
	Settings.custom_village = 0
	await _start_game()
	check(game.player_village.intact_huts().size() == 8 and game.player_village.gates.size() == 1, "the game builds it as the file says: 8 huts, 1 gate")
	game.waves.countdown = 0.5
	check(await wait_until(func() -> bool: return game.waves.wave == 1 and game.waves.enemies_left() > 0, 30.0), "and a wave starts on it")
	await _end_game()


## Village 1 of a two-village map played alone: village 0 is an ownerless ruin.
func _play_ownerless(m: MapData) -> void:
	check(m != null and m.villages.size() == 2, "a two-village map from JSON")
	if m == null:
		return
	Settings.custom_map = m
	Settings.custom_village = 1
	await _start_game()
	var v := game.player_village
	check(game.villages.size() == 1 and v.center == m.villages[1]["center"], "single player on village 2: one village, at the second's place")
	check(game.map.abandoned.size() == 1 and game.map.abandoned[0]["center"] == m.villages[0]["center"], "the other is abandoned")
	var ruins: Array = game.world.buildings.filter(func(b: Building) -> bool: return b.has_meta("abandoned"))
	var huts: Array = ruins.filter(func(b: Building) -> bool: return b is Hut)
	check(ruins.size() == 25 and huts.size() == 9 and huts.all(func(h: Hut) -> bool: return h.village == null and not h.is_intact()), "it stands: 25 pieces, nobody's, every hut a ruin")
	var r: Dictionary = game.command("rebuild_hut", {"building": huts[0].nid})
	check(not r["ok"] and game.building_info(huts[0])["actions"].is_empty() and "abandoned" in str(game.building_info(huts[0])["lines"]), "its ruins can't be rebuilt (no actions, refused)")
	var ring: Array = ruins.filter(func(b: Building) -> bool: return b is Tower)
	game.economy.add("gold", 500)
	var archer := game.army.recruit("archer")
	r = game.command("station_unit", {"unit": archer.nid if archer else 0, "post": ring[0].nid})
	check(archer != null and not r["ok"] and "isn't your tower" in str(r.get("error", "")), "its wall towers can't be manned")
	check(game.map.edge_spawns.all(func(s: Vector2i) -> bool: return (m.villages[1]["home_spawns"] as Array).has(s)) and not game.map.edge_spawns.is_empty(), "only the played village's spawns send waves")
	check(game.map.gates.all(func(t: Vector2i) -> bool: return v.gates.has(t)), "and enemies head only for its gates")
	check(game.fog.is_explored_by(v.id, m.villages[0]["center"]), "the ruined village is known on the map")
	game.waves.countdown = 0.5
	check(await wait_until(func() -> bool: return game.waves.wave == 1 and game.waves.enemies_left() > 0, 30.0), "a wave starts")
	await frames(5)
	check(get_tree().get_nodes_in_group("enemies").all(func(e: Enemy) -> bool: return e.target_village == v or e.behavior is CampBehavior), "its enemies all go for the played village")
	await _end_game()
