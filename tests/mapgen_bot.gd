extends "res://tests/bot_base.gd"
## Headless unit tests of map generation (scripts/world/map_generator.gd and
## scripts/world/gen/*), without a Game or a World behind them: the building
## blocks every stage draws from (GenContext's seeded random helpers), what
## MapData promises about its tiles and its save format, determinism, and
## Pathing on a freshly generated map. Then a sweep over many seeds that makes
## one attempt per map -- no MAP_TRIES retries -- so the numbers are the
## generator's own hit rate and not what the retry loop hides. Every map of
## the sweep is printed as a MAPGEN line for tests/summarize.py, and the bot
## prints the same as tables at the end. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/mapgen_bot.tscn
## Env (all optional):
##   MAPGEN_SEEDS            seeds per map type and player count (6)
##   MAPGEN_TYPES            "coast,desert", or empty for all of them
##   MAPGEN_PLAYERS          "1,2,4"
##   MAPGEN_BUDGET_MS        stop the sweep after this long (240000)
##   MAPGEN_MAX_FAIL_SHARE   seeds that may miss on the first attempt (0.25)
##   GEN_PROFILE=1           the generator prints its own per stage timings
## Exits 0 when every check passes.

## The terrain names of MapData.Terrain, in its order.
const TERRAIN_NAMES: Array[String] = ["grass", "road", "forest", "desert", "mountain", "water", "shallow", "lava"]
## Everything to_bytes()/from_bytes() carries (the co-op host sends it).
const SAVED_FIELDS: Array[String] = ["size", "terrain", "props", "village_rect", "gates", "edge_spawns",
	"villages", "village_links", "village_layout", "farm_plot", "zones", "decor", "crossings",
	"volcanoes", "beaches", "slice_of", "slices", "objects", "map_type", "seed_value"]
## ... and the fields that only ever exist in a running game.
const RUNTIME_FIELDS: Array[String] = ["explored", "watched", "buildings"]

## Promises the sweep's maps broke: what -> [how many maps, the first one].
var faults := {}
## One row per map the sweep made.
var rows: Array[Dictionary] = []


func _run() -> void:
	_test_context()
	_test_map_data()
	_test_determinism()
	_test_pathing()
	_sweep()
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- the generator's building blocks ------------------------------------------------------------

## GenContext's seeded helpers. Every stage draws from them, so a change here
## changes every map: they are worth checking on their own, away from a map.
func _test_context() -> void:
	var c := GenContext.new(7, 2, "temperate")
	check(c.m != null and c.m.size == Config.map_size(2), "a 2 player context starts on a %dx%d map" % [Config.map_size(2), Config.map_size(2)])
	check(c.m.map_type == "temperate" and not c.type.is_empty(), "with its map type's settings")
	check(GenContext.new(7, 99, "temperate").players == Config.MAX_PLAYERS, "more players than %d are clamped" % Config.MAX_PLAYERS)
	check(GenContext.new(7, 1, "nonsense").type_key == "temperate", "and an unknown map type falls back to temperate")

	# pick(): weighted, only ever a key it was given, never one weighted 0.
	var weights := {"a": 3.0, "b": 1.0, "c": 0.0}
	var seen := {}
	for n in 2000:
		var k := c.pick(weights)
		seen[k] = int(seen.get(k, 0)) + 1
	check(seen.keys().all(func(k: Variant) -> bool: return weights.has(k)), "pick() only returns keys it was given (%s)" % ", ".join(PackedStringArray(seen.keys())))
	check(not seen.has("c"), "and never one weighted 0")
	var share := float(seen.get("a", 0)) / 2000.0
	check(share > 0.70 and share < 0.80, "weight 3 against 1 comes up %.0f%% of the time" % (share * 100.0))
	check(c.pick({}) == "", "an empty table gives an empty string")

	# count_in(): inside its range, scaled.
	var lo := 999
	var hi := -1
	for n in 2000:
		var v := c.count_in(Vector2i(3, 7))
		lo = mini(lo, v)
		hi = maxi(hi, v)
	check(lo == 3 and hi == 7, "count_in((3, 7)) stays in 3..7 and uses all of it (saw %d..%d)" % [lo, hi])
	check(c.count_in(Vector2i(0, 0)) == 0, "count_in((0, 0)) is 0")
	var scaled := c.count_in(Vector2i(10, 10), 2.0)
	check(scaled == 20 or scaled == 21, "and a scale of 2 doubles it (%d)" % scaled)

	# shuffle(): a permutation, the same one for the same seed.
	var a := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var b := a.duplicate()
	GenContext.new(99, 1, "temperate").shuffle(a)
	GenContext.new(99, 1, "temperate").shuffle(b)
	check(a == b, "shuffle() gives the same order for the same seed")
	check(a != [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "and does move things (%s)" % str(a))
	var back := a.duplicate()
	back.sort()
	check(back == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "and keeps every element (it is a permutation)")

	# distance_to(): plain breadth-first steps, no terrain in the way.
	var d4 := c.distance_to(func(t: Vector2i) -> bool: return t == Vector2i.ZERO)
	var d8 := c.distance_to(func(t: Vector2i) -> bool: return t == Vector2i.ZERO, true)
	var ok4 := true
	var ok8 := true
	for y in range(0, c.m.size, 7):
		for x in range(0, c.m.size, 7):
			ok4 = ok4 and d4[c.i(Vector2i(x, y))] == x + y
			ok8 = ok8 and d8[c.i(Vector2i(x, y))] == maxi(x, y)
	check(ok4, "distance_to() counts 4 direction steps to the nearest source")
	check(ok8, "and 8 direction steps with `diagonal`")
	var none := c.distance_to(func(_t: Vector2i) -> bool: return false)
	check(none[0] > c.m.size * c.m.size, "with no source at all every tile stays far away")


# --- MapData ------------------------------------------------------------------------------------

## What MapData promises about its tiles, and the save format co-op sends.
func _test_map_data() -> void:
	var m := MapGenerator.generate(20260101, 2, "coast")
	check(m != null and m.size == Config.map_size(2), "generate() gives a map of the size its player count asks for")
	check(m.seed_value == 20260101, "that remembers the seed it was asked for, not the one a retry used")
	check(m.map_type == "coast", "and its map type")

	# index() and the terrain helpers, over every tile.
	var bad_index := Vector2i(-1, -1)
	var bad_pass := Vector2i(-1, -1)
	var bad_zone := Vector2i(-1, -1)
	var slowest := 1.0
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if m.index(t) != y * m.size + x and bad_index.x < 0:
				bad_index = t
			var v := m.get_terrain(t)
			var passable := v != MapData.Terrain.FOREST and v != MapData.Terrain.MOUNTAIN \
				and v != MapData.Terrain.WATER and v != MapData.Terrain.LAVA
			if m.is_passable(t) != passable and bad_pass.x < 0:
				bad_pass = t
			if not Config.ZONES.has(m.zone(t)) and bad_zone.x < 0:
				bad_zone = t
			slowest = minf(slowest, m.walk_factor(t))
	check(bad_index.x < 0, "index() runs row by row over every tile")
	check(bad_pass.x < 0, "is_passable() lets through exactly what the terrain allows")
	check(bad_zone.x < 0, "every tile has a zone the game knows")
	check(slowest > 0.0 and slowest <= 1.0, "and a walking factor in 0..1 (slowest %.2f)" % slowest)
	check(not m.in_bounds(Vector2i(-1, 0)) and not m.in_bounds(Vector2i(m.size, 0)) and not m.in_bounds(Vector2i(0, m.size)), "in_bounds() stops at the edges")
	check(not m.is_passable(Vector2i(-1, 0)) and not m.is_road(Vector2i(-1, 0)) and not m.is_water(Vector2i(-1, 0)) and not m.is_mountain(Vector2i(-1, 0)), "and the tile helpers all say no outside the map")
	check(m.is_edge(Vector2i(0, 5)) and m.is_edge(Vector2i(m.size - 1, 5)) and not m.is_edge(Vector2i(1, 5)), "is_edge() is the outermost ring")
	check(m.count_terrain(MapData.Terrain.ROAD) == _count_terrain(m, MapData.Terrain.ROAD), "count_terrain() counts what is on the map")
	var rect := MapData.rect_tiles(Rect2i(2, 3, 4, 5))
	check(rect.size() == 20 and rect[0] == Vector2i(2, 3) and rect[19] == Vector2i(5, 7), "rect_tiles() walks the whole rect, row by row")
	var nb := MapData.neighbors4(Vector2i(5, 5))
	check(nb.size() == 4 and not nb.has(Vector2i(5, 5)) and nb.has(Vector2i(6, 5)) and nb.has(Vector2i(5, 4)), "neighbors4() gives the 4 tiles around one")

	# village_at() and in_village() are asked the same question in two ways.
	var mismatch := Vector2i(-1, -1)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if (m.village_at(t) >= 0) != m.in_village(t) and mismatch.x < 0:
				mismatch = t
	check(mismatch.x < 0, "village_at() and in_village() agree on every tile")

	# The save format: what the host sends comes back the same.
	var copy := MapData.from_bytes(m.to_bytes())
	var lost: Array[String] = []
	for f in SAVED_FIELDS:
		if var_to_bytes(copy.get(f)) != var_to_bytes(m.get(f)):
			lost.append(f)
	check(lost.is_empty(), "every saved field survives to_bytes()/from_bytes() (lost: %s)" % ", ".join(lost))
	check(copy.to_bytes() == m.to_bytes(), "and the map that comes back saves to the same bytes again")
	var known := SAVED_FIELDS.duplicate()
	known.append_array(RUNTIME_FIELDS)
	var unknown: Array[String] = []
	for p in m.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not known.has(str(p["name"])):
			unknown.append(str(p["name"]))
	check(unknown.is_empty(), "every field of MapData is either saved or runtime only (new: %s -- put it in to_bytes()/from_bytes() too, or co-op clients get a different map)" % ", ".join(unknown))


# --- determinism --------------------------------------------------------------------------------

## A seed has to give the same map every time: the title screen's baked maps
## (data/title_maps/) and tools/map_shot.sh both rely on it.
func _test_determinism() -> void:
	for type in Config.MAP_TYPE_ORDER:
		var a := MapGenerator.generate(555, 2, type)
		var b := MapGenerator.generate(555, 2, type)
		check(a.to_bytes() == b.to_bytes(), "%s: the same seed gives the same map twice" % type)
		check(MapGenerator.generate(556, 2, type).to_bytes() != a.to_bytes(), "%s: and the next seed a different one" % type)


# --- pathing on a generated map -------------------------------------------------------------------

## Pathing is built from the map alone, so it can be checked here, with no
## World around it: what the generator calls passable is what units walk on.
func _test_pathing() -> void:
	var m := MapGenerator.generate(31337, 2, "highlands")
	var p := Pathing.new(m)
	var bad := Vector2i(-1, -1)
	var walkable := 0
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if p.is_walkable(t) != m.is_passable(t) and bad.x < 0:
				bad = t
			walkable += 1 if p.is_walkable(t) else 0
	check(bad.x < 0, "pathing walks exactly the tiles the map calls passable (%d of %d)" % [walkable, m.size * m.size])

	var centre: Vector2i = m.villages[0]["center"]
	check(p.is_walkable(centre), "the village centre is walkable")
	var unreachable: Array[String] = []
	for i in m.villages.size():
		var v: Dictionary = m.villages[i]
		for g: Vector2i in v["gates"]:
			if not p.can_reach(v["center"], g):
				unreachable.append("village %d's gate %s" % [i, str(g)])
		if not p.can_reach(centre, v["center"]):
			unreachable.append("village %d from village 0" % i)
	check(unreachable.is_empty(), "every village reaches its own gates and all the others (%s)" % ", ".join(unreachable))

	var field := p.reach_from(centre)
	var reached := 0
	for i in field.size():
		reached += 1 if field[i] < Pathing.UNREACHABLE else 0
	check(reached > walkable / 2, "%.0f%% of the walkable tiles can be walked to from the village" % (100.0 * reached / maxi(1, walkable)))

	var gate: Vector2i = m.villages[0]["gates"][0]
	var path := p.find_path(centre, gate)
	var steps_ok := not path.is_empty() and Vector2i(path[path.size() - 1]) == gate
	for k in range(1, path.size()):
		var step := Vector2i(path[k]) - Vector2i(path[k - 1])
		steps_ok = steps_ok and p.is_walkable(Vector2i(path[k])) and absi(step.x) <= 1 and absi(step.y) <= 1 and step != Vector2i.ZERO
	check(steps_ok, "a path from the village centre to a gate steps one tile at a time (%d steps)" % path.size())
	check(p.find_path(centre, Vector2i(-5, -5)).is_empty(), "and there is no path to a tile outside the map")
	check(p.is_walkable(p.nearest_walkable(centre)) and p.is_walkable(p.nearest_walkable(Vector2i(0, 0))), "nearest_walkable() gives back a walkable tile")

	var disagree := 0
	for k in 60:
		var t := Vector2i((k * 7919) % m.size, (k * 104729) % m.size)
		if not p.is_walkable(t):
			continue
		if p.can_reach(centre, t) != (not p.find_path(centre, t).is_empty()):
			disagree += 1
	check(disagree == 0, "can_reach() and find_path() say the same thing about 60 sample tiles")


# --- the sweep ----------------------------------------------------------------------------------

## Makes many maps, one attempt each, and collects what came out.
func _sweep() -> void:
	var seeds := maxi(1, int(_env("MAPGEN_SEEDS", "6")))
	var budget := maxi(1000, int(_env("MAPGEN_BUDGET_MS", "240000")))
	var max_fail := clampf(float(_env("MAPGEN_MAX_FAIL_SHARE", "0.25")), 0.0, 1.0)
	var types: Array[String] = []
	for t in _env("MAPGEN_TYPES", "").split(",", false):
		if Config.MAP_TYPES.has(t.strip_edges()):
			types.append(t.strip_edges())
	if types.is_empty():
		types.assign(Config.MAP_TYPE_ORDER)
	var counts: Array[int] = []
	for s in _env("MAPGEN_PLAYERS", "1,2,4").split(",", false):
		counts.append(clampi(int(s.strip_edges()), 1, Config.MAX_PLAYERS))

	# Seed by seed, so a sweep that runs out of budget still saw every case.
	var t0 := Time.get_ticks_msec()
	var skipped := 0
	for n in seeds:
		for type in types:
			for players in counts:
				if Time.get_ticks_msec() - t0 > budget:
					skipped += 1
					continue
				_one(1000 + n * 7919, players, type)
	check(not rows.is_empty(), "the sweep made %d maps in %d ms" % [rows.size(), Time.get_ticks_msec() - t0])
	if skipped > 0:
		print("  (%d maps left out: the %d ms budget of MAPGEN_BUDGET_MS ran out)" % [skipped, budget])

	# One check per promise the maps broke, so each one reads on its own.
	if faults.is_empty():
		check(true, "all %d maps keep the structure the game relies on" % rows.size())
	for what: String in faults:
		check(false, "%d of %d maps broke it: %s (first on %s)" % [faults[what][0], rows.size(), what, faults[what][1]])

	var missed := 0
	var warned := 0
	var slowest := 0
	var all_cases := {}
	var good_cases := {}
	for r in rows:
		missed += 1 if not (r["hard"] as Array).is_empty() else 0
		warned += 1 if not (r["soft"] as Array).is_empty() else 0
		slowest = maxi(slowest, int(r["ms"]))
		var key := "%s with %d players" % [r["type"], r["players"]]
		all_cases[key] = true
		if (r["hard"] as Array).is_empty():
			good_cases[key] = true
	var share := float(missed) / maxf(1.0, float(rows.size()))
	check(share <= max_fail, "the generator meets its own checks on the first attempt for %.0f%% of seeds (%d of %d missed, %.0f%% allowed; MAP_TRIES = %d hides the rest from players, at the price of making the map again)"
		% [100.0 * (1.0 - share), missed, rows.size(), 100.0 * max_fail, Config.MAP_TRIES])
	var never: Array[String] = []
	for key: String in all_cases:
		if not good_cases.has(key):
			never.append(key)
	check(never.is_empty(), "every map type and player count made at least one map that passed first time (never: %s)" % ", ".join(never))
	check(slowest < 30000, "no single map took longer than 30 s to make (slowest %d ms, %d of %d maps had soft warnings)" % [slowest, warned, rows.size()])
	_report()


## One map: one attempt, no retry, then everything worth knowing about it.
func _one(seed_value: int, players: int, type: String) -> void:
	var c := GenContext.new(seed_value, players, type)
	var t0 := Time.get_ticks_msec()
	MapGenerator.run(c)
	var ms := Time.get_ticks_msec() - t0
	var m := c.m
	var row := {
		"seed": seed_value, "players": players, "type": type, "ms": ms,
		"hard": c.failures.duplicate(), "soft": c.soft.duplicate(),
		"shares": _shares(m), "objects": _objects(m),
	}
	row["faults"] = _structure(m, players, type, seed_value)
	rows.append(row)
	var shares: Dictionary = row["shares"]
	var terrain_bits: Array[String] = []
	for name in TERRAIN_NAMES:
		terrain_bits.append("%s:%.3f" % [name, shares[name]])
	var zone_bits: Array[String] = []
	for z in Config.ZONE_ORDER:
		zone_bits.append("%s:%.3f" % [z, shares["zone_" + z]])
	var object_bits: Array[String] = []
	for kind: String in row["objects"]:
		object_bits.append("%s:%d" % [kind, row["objects"][kind]])
	object_bits.sort()
	print("MAPGEN type=%s players=%d seed=%d size=%d ms=%d hard=%d soft=%d faults=%d villages=%d gates=%d spawns=%d links=%d crossings=%d volcanoes=%d props=%d terrain=%s zones=%s objects=%s" % [
		type, players, seed_value, m.size, ms, (row["hard"] as Array).size(), (row["soft"] as Array).size(), row["faults"],
		m.villages.size(), m.gates.size(), m.edge_spawns.size(), m.village_links.size(), m.crossings.size(),
		m.volcanoes.size(), m.props.size(), ",".join(terrain_bits), ",".join(zone_bits), ",".join(object_bits)])
	for why in c.failures:
		print("MAPGEN-FAIL type=%s players=%d seed=%d | %s" % [type, players, seed_value, why])
	for why in c.soft:
		print("MAPGEN-SOFT type=%s players=%d seed=%d | %s" % [type, players, seed_value, why])


## Terrain and zone shares of `m`, by tile.
func _shares(m: MapData) -> Dictionary:
	var area := float(maxi(1, m.size * m.size))
	var out := {}
	for v in TERRAIN_NAMES.size():
		out[TERRAIN_NAMES[v]] = m.count_terrain(v) / area
	var per_zone := PackedInt32Array()
	per_zone.resize(Config.ZONE_ORDER.size())
	for i in m.zones.size():
		var z := int(m.zones[i])
		if z >= 0 and z < per_zone.size():
			per_zone[z] += 1
	for z in Config.ZONE_ORDER.size():
		out["zone_" + Config.ZONE_ORDER[z]] = per_zone[z] / area
	return out


## How many of each kind of special object `m` has.
func _objects(m: MapData) -> Dictionary:
	var out := {}
	for o in m.objects:
		var kind := str(o.get("kind", "?"))
		out[kind] = int(out.get(kind, 0)) + 1
	return out


## The promises that hold for every map, whatever the generator's own checks
## make of it: no broken enum, nothing outside the map, a village per player.
## They are collected over the whole sweep and reported once, by kind.
func _structure(m: MapData, players: int, type: String, seed_value: int) -> int:
	var where := "%s, %d players, seed %d" % [type, players, seed_value]
	var n := 0
	var tiles := m.size * m.size
	n += _fault(m.size == Config.map_size(players), "the map has the size its player count asks for", where)
	n += _fault(m.map_type == type, "the map remembers its map type", where)
	n += _fault(m.terrain.size() == tiles and m.zones.size() == tiles and m.slice_of.size() == tiles,
		"terrain, zones and slices cover every tile", where)
	var bad_terrain := 0
	var bad_zone := 0
	var bad_slice := 0
	for i in mini(tiles, mini(m.terrain.size(), mini(m.zones.size(), m.slice_of.size()))):
		bad_terrain += 1 if m.terrain[i] >= TERRAIN_NAMES.size() else 0
		bad_zone += 1 if m.zones[i] >= Config.ZONE_ORDER.size() else 0
		bad_slice += 1 if m.slice_of[i] >= players else 0
	n += _fault(bad_terrain == 0, "every tile has a terrain the game knows", where)
	n += _fault(bad_zone == 0, "every tile has a zone the game knows", where)
	n += _fault(bad_slice == 0, "every tile belongs to one of the players' slices", where)
	n += _fault(m.villages.size() == players and m.slices.size() == players, "there is one village and one slice per player", where)
	for v in m.villages:
		var rect: Rect2i = v["rect"]
		n += _fault(m.in_bounds(rect.position) and m.in_bounds(rect.end - Vector2i.ONE), "every village is inside the map", where)
		n += _fault(rect.has_point(v["center"]), "and its centre inside its own walls", where)
		n += _fault(not (v["gates"] as Array).is_empty(), "and has at least one gate", where)
		for g: Vector2i in v["gates"]:
			n += _fault(m.is_road(g), "every gate is a road tile", where)
	n += _fault(not m.edge_spawns.is_empty(), "enemies have somewhere to come from", where)
	for t in m.edge_spawns:
		n += _fault(m.is_edge(t), "and they only ever come in at the map edge", where)
	for o in m.objects:
		n += _fault(m.in_bounds(o["tile"]), "every special object sits on a tile of the map", where)
	for t in m.volcanoes:
		n += _fault(m.in_bounds(t), "every volcano sits on a tile of the map", where)
	for t: Vector2i in m.props:
		n += _fault(m.in_bounds(t), "every prop sits on a tile of the map", where)
	for t: Vector2i in m.crossings:
		var under := int((m.crossings[t] as Array)[1])
		n += _fault(m.is_road(t), "every bridge and ford is a road tile", where)
		n += _fault(under == MapData.Terrain.WATER or under == MapData.Terrain.SHALLOW or under == MapData.Terrain.LAVA,
			"and remembers water or lava underneath it", where)
	return n


## Counts a broken promise, and prints the first map that broke it.
func _fault(ok: bool, what: String, where: String) -> int:
	if ok:
		return 0
	if not faults.has(what):
		faults[what] = [0, where]
		print("MAPGEN-FAULT %s | %s" % [where, what])
	faults[what][0] = int(faults[what][0]) + 1
	return 1


# --- the report ---------------------------------------------------------------------------------

## The sweep's numbers as tables, so the log reads on its own. tests/summarize.py
## builds the same thing (and more) out of the MAPGEN lines above.
func _report() -> void:
	var keys: Array[String] = []
	var by_case := {}
	for r in rows:
		var key := "%s %d" % [r["type"], r["players"]]
		if not by_case.has(key):
			by_case[key] = []
			keys.append(key)
		(by_case[key] as Array).append(r)
	print("")
	print("--- map generation: %d maps, one attempt each (no MAP_TRIES retries) ---" % rows.size())
	print("  %-10s %7s %5s %10s %6s %7s %7s %6s" % ["type", "players", "maps", "first try", "soft", "ms p50", "ms p95", "tiles"])
	for key in keys:
		var g: Array = by_case[key]
		var ms: Array = []
		var missed := 0
		var warned := 0
		for r in g:
			ms.append(r["ms"])
			missed += 1 if not (r["hard"] as Array).is_empty() else 0
			warned += 1 if not (r["soft"] as Array).is_empty() else 0
		var parts := key.split(" ")
		print("  %-10s %7s %5d %9.0f%% %6d %7d %7d %6d" % [parts[0], parts[1], g.size(),
			100.0 * (g.size() - missed) / maxi(1, g.size()), warned, _pct(ms, 0.5), _pct(ms, 0.95), int(g[0]["players"])])
	_reasons("what the generator's own checks caught on the first attempt", "hard")
	_reasons("soft warnings (retried once, then the best map is kept)", "soft")
	_makeup()
	if OS.has_environment("GEN_PROFILE"):
		print("  per stage timings are in the lines above, one per attempt (GEN_PROFILE is set)")


## The failure texts of the sweep, numbers taken out, most common first.
func _reasons(title: String, field: String) -> void:
	var digits := RegEx.create_from_string("[0-9]+([.,][0-9]+)?")
	var counts := {}
	var first := {}
	for r in rows:
		for why: String in r[field]:
			var key := digits.sub(why, "#", true)
			counts[key] = int(counts.get(key, 0)) + 1
			if not first.has(key):
				first[key] = "%s, %d players, seed %d" % [r["type"], r["players"], r["seed"]]
	if counts.is_empty():
		print("  %s: none" % title)
		return
	var order: Array = counts.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]))
	print("  %s:" % title)
	for key: String in order:
		print("    %4dx  %s  (e.g. %s)" % [counts[key], key, first[key]])


## What the maps are made of and what is on them, per map type.
func _makeup() -> void:
	var types: Array[String] = []
	var by_type := {}
	for r in rows:
		var key: String = r["type"]
		if not by_type.has(key):
			by_type[key] = []
			types.append(key)
		(by_type[key] as Array).append(r)
	print("  what the maps are made of (mean share of their tiles):")
	for key in types:
		var g: Array = by_type[key]
		var terrain_bits: Array[String] = []
		for name in TERRAIN_NAMES:
			var sum := 0.0
			for r in g:
				sum += float((r["shares"] as Dictionary)[name])
			if sum / g.size() >= 0.001:
				terrain_bits.append("%s %.2f" % [name, sum / g.size()])
		var zone_bits: Array[String] = []
		for z in Config.ZONE_ORDER:
			var sum := 0.0
			for r in g:
				sum += float((r["shares"] as Dictionary)["zone_" + z])
			if sum / g.size() >= 0.001:
				zone_bits.append("%s %.2f" % [z, sum / g.size()])
		print("    %-10s %s" % [key, ", ".join(terrain_bits)])
		print("    %-10s zones: %s" % ["", ", ".join(zone_bits)])
	print("  what is on them (mean per map):")
	for key in types:
		var g: Array = by_type[key]
		var totals := {}
		for r in g:
			for kind: String in r["objects"]:
				totals[kind] = float(totals.get(kind, 0.0)) + float((r["objects"] as Dictionary)[kind])
		var names: Array = totals.keys()
		names.sort()
		var bits: Array[String] = []
		for kind: String in names:
			bits.append("%s %.1f" % [kind, float(totals[kind]) / g.size()])
		print("    %-10s %s" % [key, ", ".join(bits) if not bits.is_empty() else "nothing"])


# --- small helpers ------------------------------------------------------------------------------

func _env(name: String, fallback: String) -> String:
	var v := OS.get_environment(name)
	return v if v != "" else fallback


## The `q` quantile of `values` (0.5 is the median), nearest rank.
func _pct(values: Array, q: float) -> int:
	if values.is_empty():
		return 0
	var v := values.duplicate()
	v.sort()
	return int(v[clampi(roundi(q * (v.size() - 1)), 0, v.size() - 1)])


func _count_terrain(m: MapData, v: int) -> int:
	var n := 0
	for y in m.size:
		for x in m.size:
			n += 1 if m.get_terrain(Vector2i(x, y)) == v else 0
	return n
