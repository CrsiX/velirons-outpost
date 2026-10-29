class_name MapChecks
extends RefCounted
## The checks for a map from a file or the editor (docs/map-editor-design.md
## §5.4). Errors keep it from being played; warnings never do. Each problem:
## {"level": "error" | "warning", "text", "tile" (Vector2i; (-1, -1): none)}.
## (The generator keeps its own, stricter checks for the maps it makes.)

const NO_TILE := Vector2i(-1, -1)


static func run(m: MapData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slots := int(Config.MAP_SIZE_SLOTS.get(m.size, Config.MAX_PLAYERS))
	if m.villages.is_empty():
		_add(out, "error", "The map has no village", NO_TILE)
	elif m.villages.size() > slots:
		_add(out, "error", "%d villages, but a %dx%d map holds at most %d" % [m.villages.size(), m.size, m.size, slots], NO_TILE)
	var pieces := MapTidy.piece_tiles(m)
	var objects := MapTidy.object_tiles(m)
	var walk := _walkable(m, pieces, objects)
	for i in m.villages.size():
		_village(out, m, i, objects, walk)
	for t in m.edge_spawns:
		if not m.is_edge(t) or not m.is_road(t):
			_add(out, "error", "Spawn [%d, %d] isn't a road tile on the map's edge" % [t.x, t.y], t)
	_water_spawns(out, m)
	_objects(out, m, pieces, walk)
	_warnings(out, m)
	return out


## Water spawns (docs/aquatic-design.md §9): on deep water, in a body of
## water at least one water monster fits.
static func _water_spawns(out: Array[Dictionary], m: MapData) -> void:
	if m.water_spawns.is_empty():
		return
	var lab := Pathing.label_water(m)
	for t in m.water_spawns:
		if not m.in_bounds(t) or not m.is_deep(t):
			_add(out, "error", "Water spawn [%d, %d] isn't on deep water" % [t.x, t.y], t if m.in_bounds(t) else NO_TILE)
			continue
		var body: Dictionary = lab["bodies"][int(lab["of"][m.index(t)])]
		if Pathing.kinds_fitting(body).is_empty():
			_add(out, "error", "Water spawn [%d, %d]: its water (%d deep tiles, %d wide) is too small for any water monster" % [t.x, t.y, int(body["deep"]), int(body["width"])], t)


static func errors(problems: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(problems.filter(func(p: Dictionary) -> bool: return p["level"] == "error"))
	return out


## The first error's text ("" when the map can be played).
static func play_error(m: MapData) -> String:
	var e := errors(run(m))
	return "" if e.is_empty() else str(e[0]["text"]) + ("" if e.size() == 1 else " (and %d more)" % (e.size() - 1))


static func _add(out: Array[Dictionary], level: String, text: String, tile: Vector2i) -> void:
	out.append({"level": level, "text": text, "tile": tile})


static func _village(out: Array[Dictionary], m: MapData, i: int, objects: Dictionary, walk: PackedByteArray) -> void:
	var v: Dictionary = m.villages[i]
	var center: Vector2i = v["center"]
	var name := "Village %d" % (i + 1)
	if not m.in_bounds(center):
		_add(out, "error", "%s: its centre is outside the map" % name, NO_TILE)
		return
	var own := m.village_pieces(i)
	if not own.any(func(p: Dictionary) -> bool: return p["kind"] == "gate"):
		_add(out, "error", "%s has no gate" % name, center)
	if not own.any(func(p: Dictionary) -> bool: return p["kind"] == "hut"):
		_add(out, "error", "%s has no hut" % name, center)
	for p in own:
		if objects.has(p["tile"]):
			_add(out, "error", "%s: a %s stands on an object" % [name, str(p["kind"]).replace("_", " ")], p["tile"])
	var spawns: Array = v["home_spawns"]
	if spawns.is_empty():
		_add(out, "error", "%s has no spawn (where its waves come from)" % name, center)
	elif not (v["gates"] as Array).is_empty():
		var field := GenChecks.road_field(m, v["gates"])
		for s: Vector2i in spawns:
			if m.in_bounds(s) and field[m.index(s)] >= 1 << 29:
				_add(out, "error", "%s: spawn [%d, %d] can't reach its gates by road" % [name, s.x, s.y], s)
	if not walk.is_empty() and walk[m.index(center)] == 0:
		_add(out, "error", "%s: its centre is blocked" % name, center)
	# Warnings: one approach, a layout other than the standard one.
	if not (v["gates"] as Array).is_empty() and GenRoads.approaches(m, v) < 2:
		_add(out, "warning", "%s has fewer than 2 approaches" % name, center)
	if not standard_layout(m, i):
		_add(out, "warning", "%s doesn't have the standard layout" % name, center)


## Whether village `i`'s pieces are exactly Config.VILLAGE_LAYOUT around its centre.
static func standard_layout(m: MapData, i: int) -> bool:
	var want := standard_pieces(m.villages[i]["center"])
	var have := m.village_pieces(i)
	if have.size() != want.size():
		return false
	var by_tile := {}
	for p in have:
		by_tile[p["tile"]] = p["kind"]
	for p in want:
		if by_tile.get(p["tile"], "") != p["kind"]:
			return false
	return true


## The standard village (Config.VILLAGE_LAYOUT) around `center`: [{kind, tile,
## flip, material}], all of `material`.
static func standard_pieces(center: Vector2i, material := "stone") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var o := center - Vector2i(2, 2)
	for row in 5:
		for col in 5:
			var kind: String = {"T": "wall_tower", "W": "wall", "G": "gate", "V": "hut"}[Config.VILLAGE_LAYOUT[row][col]]
			out.append({"kind": kind, "tile": o + Vector2i(col, row), "flip": col == 0 or col == 4, "material": material})
	return out


## 1 where a villager could walk from some village centre (passable land,
## not walls, towers or lairs; huts, gates and the other objects are open), else 0.
static func _walkable(m: MapData, pieces: Dictionary, objects: Dictionary) -> PackedByteArray:
	var reach := PackedByteArray()
	reach.resize(m.size * m.size)
	var queue: Array[Vector2i] = []
	for v in m.villages:
		var c: Vector2i = v["center"]
		if m.in_bounds(c) and reach[m.index(c)] == 0:
			reach[m.index(c)] = 1
			queue.append(c)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for n in MapData.neighbors4(t):
			if not m.in_bounds(n) or reach[m.index(n)] == 1 or not m.is_passable(n):
				continue
			if objects.has(n) and m.objects[objects[n]]["kind"] == "lair":
				continue
			if pieces.get(n, "") in ["wall", "wall_tower"]:
				continue
			reach[m.index(n)] = 1
			queue.append(n)
	return reach


static func _objects(out: Array[Dictionary], m: MapData, pieces: Dictionary, walk: PackedByteArray) -> void:
	var road := GenChecks.road_field(m, m.gates) if not m.gates.is_empty() else PackedInt32Array()
	for i in m.objects.size():
		var o := m.objects[i]
		var t: Vector2i = o["tile"]
		var name := "%s %d" % [str(o["kind"]).capitalize(), i + 1]
		var tiles := Building.footprint(t, int(o.get("size", 1)))
		if tiles.any(func(p: Vector2i) -> bool: return not m.in_bounds(p)):
			_add(out, "error", "%s doesn't fit on the map" % name, t)
			continue
		if tiles.any(func(p: Vector2i) -> bool: return pieces.has(p)):
			_add(out, "error", "%s stands on a village" % name, t)
		if tiles.any(func(p: Vector2i) -> bool: return MapTidy.in_volcano(m, p)):
			_add(out, "error", "%s stands on a volcano" % name, t)
		if o["kind"] in ["lair", "mine"]:
			var front: Vector2i = o["front"]
			if not m.is_road(front):
				_add(out, "error", "%s: its front [%d, %d] isn't road" % [name, front.x, front.y], front)
			elif not road.is_empty() and road[m.index(front)] >= 1 << 29:
				_add(out, "error", "%s: its road doesn't lead to a village" % name, front)
		elif not walk.is_empty() and not _reachable(m, tiles, walk):
			_add(out, "error", "%s can't be reached from a village" % name, t)
		if o["kind"] == "camp" and (int(o.get("guards", -1)) < 0 or int(o["guards"]) >= m.objects.size()):
			_add(out, "error", "%s guards no treasure" % name, t)


## Some tile of `tiles` or next to them can be walked to.
static func _reachable(m: MapData, tiles: Array[Vector2i], walk: PackedByteArray) -> bool:
	for t in tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := t + Vector2i(dx, dy)
				if m.in_bounds(p) and walk[m.index(p)] == 1:
					return true
	return false


static func _warnings(out: Array[Dictionary], m: MapData) -> void:
	var n := m.villages.size()
	if n > 1:
		for i in n:
			if not m.village_links.any(func(l: Vector2i) -> bool: return l.x == i or l.y == i):
				_add(out, "warning", "Village %d has no road to another village" % (i + 1), m.villages[i]["center"])
		var shares := GenChecks.zone_shares(m)
		for z in Config.ZONE_ORDER:
			var lo := INF
			var hi := -INF
			for s in mini(n, shares.size()):
				lo = minf(lo, shares[s].get(z, 0.0))
				hi = maxf(hi, shares[s].get(z, 0.0))
			if hi - lo > Config.ZONE_FAIR_SPREAD:
				_add(out, "warning", "%s land differs by %d points between slices" % [Config.ZONES[z]["name"], roundi((hi - lo) * 100)], NO_TILE)
	for s in n:
		if not m.objects.any(func(o: Dictionary) -> bool: return o["kind"] == "treasure" and int(o.get("slice", -1)) == s):
			_add(out, "warning", "Slice %d has no treasure" % (s + 1), NO_TILE)
		if not m.objects.any(func(o: Dictionary) -> bool: return o["kind"] == "camp" and int(o.get("slice", -1)) == s):
			_add(out, "warning", "Slice %d has no monster camp" % (s + 1), NO_TILE)
	for site in Config.UNLOCK_SITES:
		if not m.objects.any(func(o: Dictionary) -> bool: return o["kind"] == "unlock" and o["site"] == site):
			_add(out, "warning", "No %s: the %s can never be unlocked" % [Config.UNLOCK_SITES[site]["name"].to_lower(), Config.UNLOCK_SITES[site]["unlocks"]], NO_TILE)
	for o in m.objects:
		if o["kind"] == "treasure" and int(o.get("tier", 1)) == 3 and int(o.get("guard", -1)) < 0:
			_add(out, "warning", "A far (tier 3) treasure has no camp", o["tile"])
