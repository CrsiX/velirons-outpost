class_name EditorTools
extends RefCounted
## The map editor's edits (docs/map-editor-design.md §4.3), on a MapData and
## nothing else: each returns the tiles it changed (for the tidy-up and the
## views), or an error text for edits that can't be done. MapEditor wraps
## them with undo, tidy-up, derive() and the checks.

const PIECE_SOLID := ["wall", "wall_tower", "hut"]


## The tiles of a brush of width `width` around `t` (square, or round).
static func brush(t: Vector2i, width: int, round_brush: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := (width - 1) / 2
	for dy in range(-r, width - r):
		for dx in range(-r, width - r):
			if round_brush and width > 2 and Vector2(dx, dy).length() > width / 2.0:
				continue
			out.append(t + Vector2i(dx, dy))
	return out


# --- ground ----------------------------------------------------------------------------------

static func paint_terrain(m: MapData, tiles: Array, terrain: int) -> Array[Vector2i]:
	var pieces := MapTidy.piece_tiles(m)
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if not m.in_bounds(t) or pieces.has(t) or m.get_terrain(t) == terrain:
			continue
		if MapTidy.in_volcano(m, t):
			out.append_array(remove_volcano(m, t))
		m.crossings.erase(t)
		m.set_terrain(t, terrain)
		out.append(t)
	return out


## Flood-fills the area of `t`'s terrain (4 directions) with `terrain`.
static func fill_terrain(m: MapData, t: Vector2i, terrain: int) -> Array[Vector2i]:
	if not m.in_bounds(t):
		return []
	var from := m.get_terrain(t)
	if from == terrain:
		return []
	var area: Array[Vector2i] = [t]
	var seen := {t: true}
	var head := 0
	while head < area.size():
		var p := area[head]
		head += 1
		for n in MapData.neighbors4(p):
			if m.in_bounds(n) and not seen.has(n) and m.get_terrain(n) == from:
				seen[n] = true
				area.append(n)
	return paint_terrain(m, area, terrain)


static func paint_zone(m: MapData, tiles: Array, zone: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if m.in_bounds(t) and m.zone(t) != zone:
			m.set_zone(t, zone)
			out.append(t)
	return out


## Trees on forest, peaks on mountains: `art`, or "auto" (the zone's mix).
static func paint_prop(m: MapData, tiles: Array, art: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if not m.in_bounds(t) or MapTidy.in_volcano(m, t):
			continue
		var want := ""
		if m.is_forest(t):
			want = MapTidy.tree_for(m, t) if art == "auto" or MapTidy.PEAK_ARTS.has(art) else art
		elif m.is_mountain(t):
			want = MapTidy.PEAK_ARTS[absi(hash(t)) % MapTidy.PEAK_ARTS.size()] if art == "auto" or not MapTidy.PEAK_ARTS.has(art) else art
		if want != "" and m.props.get(t, "") != want:
			m.props[t] = want
			out.append(t)
	return out


## Decor on open land: `art`, "auto" (the zone's), or "" to clear it.
static func paint_decor(m: MapData, tiles: Array, art: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if not m.in_bounds(t):
			continue
		if art == "":
			if m.decor.erase(t):
				out.append(t)
			continue
		if m.is_road(t) or not m.is_passable(t) or m.get_terrain(t) == MapData.Terrain.SHALLOW:
			continue
		var want := MapTidy.decor_for(m, t) if art == "auto" else art
		if m.decor.get(t, "") != want:
			m.decor[t] = want
			out.append(t)
	return out


static func paint_beach(m: MapData, tiles: Array, on: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if not m.in_bounds(t):
			continue
		if on and not m.beaches.has(t) and not m.is_water(t) and not m.is_road(t):
			m.beaches[t] = true
			out.append(t)
		elif not on and m.beaches.erase(t):
			out.append(t)
	return out


static func paint_slice(m: MapData, tiles: Array, s: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if m.in_bounds(t) and m.slice_of[m.index(t)] != s:
			m.slice_of[m.index(t)] = s
			out.append(t)
	return out


## Every tile to its nearest village (in steps; ties to the lower id). No
## village: slice 0 everywhere.
static func recompute_slices(m: MapData) -> Array[Vector2i]:
	var n := m.size * m.size
	var owner := PackedInt32Array()
	owner.resize(n)
	owner.fill(-1)
	var queue: Array[Vector2i] = []
	for i in m.villages.size():
		var c: Vector2i = m.villages[i]["center"]
		if m.in_bounds(c) and owner[m.index(c)] < 0:
			owner[m.index(c)] = i
			queue.append(c)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := t + Vector2i(dx, dy)
				if m.in_bounds(p) and owner[m.index(p)] < 0:
					owner[m.index(p)] = owner[m.index(t)]
					queue.append(p)
	var out: Array[Vector2i] = []
	for i in n:
		var s := maxi(owner[i], 0)
		if m.slice_of[i] != s:
			m.slice_of[i] = s
			out.append(Vector2i(i % m.size, i / m.size))
	return out


# --- roads -----------------------------------------------------------------------------------

## Road on `tiles` (over water and lava: a crossing), or back to the zone's
## ground with `erase` (a crossing: back to its water or lava).
static func paint_road(m: MapData, tiles: Array, erase: bool) -> Array[Vector2i]:
	var pieces := MapTidy.piece_tiles(m)
	var out: Array[Vector2i] = []
	for t: Vector2i in tiles:
		if not m.in_bounds(t) or (pieces.has(t) and pieces[t] != "gate"):
			continue
		var v := m.get_terrain(t)
		if erase:
			if v != MapData.Terrain.ROAD or pieces.has(t):
				continue
			if m.crossings.has(t):
				m.set_terrain(t, int(m.crossings[t][1]))
				m.crossings.erase(t)
			else:
				m.set_terrain(t, MapTidy.ground(m, t))
			out.append(t)
			continue
		if v == MapData.Terrain.ROAD or MapTidy.in_volcano(m, t):
			continue
		if v in [MapData.Terrain.WATER, MapData.Terrain.SHALLOW, MapData.Terrain.LAVA]:
			MapTidy.set_crossing(m, t, v)
		m.set_terrain(t, MapData.Terrain.ROAD)
		m.props.erase(t)
		m.decor.erase(t)
		out.append(t)
	# Bridges turn with the road.
	for t in out.duplicate():
		for n in [t] + MapData.neighbors4(t):
			if m.crossings.has(n) and m.is_road(n) and str(m.crossings[n][0]).begins_with("bridge_"):
				MapTidy.set_crossing(m, n, int(m.crossings[n][1]))
	return out


## The cheapest way for a road from `a` to `b` (over open land first, then
## forest, water, mountains; never through walls, huts or objects).
static func road_path(m: MapData, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not m.in_bounds(a) or not m.in_bounds(b):
		return out
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, m.size, m.size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	var pieces := MapTidy.piece_tiles(m)
	var objects := MapTidy.object_tiles(m)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if (pieces.has(t) and pieces[t] != "gate") or objects.has(t) or MapTidy.in_volcano(m, t):
				astar.set_point_solid(t, true)
				continue
			var cost := 1.0
			match m.get_terrain(t):
				MapData.Terrain.ROAD: cost = 0.4
				MapData.Terrain.FOREST: cost = 3.0
				MapData.Terrain.MOUNTAIN: cost = 6.0
				MapData.Terrain.WATER, MapData.Terrain.LAVA: cost = 5.0
				MapData.Terrain.SHALLOW: cost = 3.0
			astar.set_point_weight_scale(t, cost)
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return out
	out.assign(astar.get_id_path(a, b))
	return out


# --- volcanoes -------------------------------------------------------------------------------

## A volcano on `t` (3x3 mountain, its crater in the middle) and, with `ash`,
## ash land around it.
static func add_volcano(m: MapData, t: Vector2i, ash: bool) -> Variant:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p := t + Vector2i(dx, dy)
			if not m.in_bounds(p) or MapTidy.piece_tiles(m).has(p) or MapTidy.object_tiles(m).has(p) or MapTidy.in_volcano(m, p):
				return "A volcano needs 3x3 free tiles inside the map"
	var out: Array[Vector2i] = []
	m.volcanoes.append(t)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p := t + Vector2i(dx, dy)
			m.crossings.erase(p)
			m.set_terrain(p, MapData.Terrain.MOUNTAIN)
			m.props.erase(p)
			out.append(p)
	m.props[t] = "volcano"
	if ash:
		var r := int(Config.VOLCANO_ASH_RADIUS)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p := t + Vector2i(dx, dy)
				if m.in_bounds(p) and Vector2(dx, dy).length() <= Config.VOLCANO_ASH_RADIUS and m.zone(p) != "ash":
					m.set_zone(p, "ash")
					out.append(p)
	return out


## Removes the volcano covering `t` (its tiles stay mountains).
static func remove_volcano(m: MapData, t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in m.volcanoes.duplicate():
		if absi(t.x - c.x) <= 1 and absi(t.y - c.y) <= 1:
			m.volcanoes.erase(c)
			m.props.erase(c)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					out.append(c + Vector2i(dx, dy))
	return out


# --- villages --------------------------------------------------------------------------------

## A standard village (Config.VILLAGE_LAYOUT) around `center`: its index, or why not.
static func add_village(m: MapData, center: Vector2i) -> Variant:
	var slots := int(Config.MAP_SIZE_SLOTS.get(m.size, Config.MAX_PLAYERS))
	if m.villages.size() >= slots:
		return "A %dx%d map holds at most %d villages" % [m.size, m.size, slots]
	var pieces := MapCheckFree.new(m)
	var want := MapChecks.standard_pieces(center)
	for p in want:
		var why := pieces.why_not(p["tile"])
		if why != "":
			return why
	var i := m.villages.size()
	m.villages.append({"center": center, "home_spawns": [] as Array[Vector2i]})
	for p in want:
		p["owner"] = i
		m.village_layout.append(p)
	return i


## Moves village `i` so its centre is on `center` (pieces, centre; not its spawns).
static func move_village(m: MapData, i: int, center: Vector2i) -> Variant:
	var d: Vector2i = center - (m.villages[i]["center"] as Vector2i)
	if d == Vector2i.ZERO:
		return [] as Array[Vector2i]
	var free := MapCheckFree.new(m, i)
	for p in m.village_pieces(i):
		var why := free.why_not(p["tile"] + d)
		if why != "":
			return why
	var out: Array[Vector2i] = []
	for p in m.village_layout:
		if int(p["owner"]) == i:
			out.append(p["tile"])
			p["tile"] = (p["tile"] as Vector2i) + d
			out.append(p["tile"])
	m.villages[i]["center"] = center
	return out


static func delete_village(m: MapData, i: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var keep: Array[Dictionary] = []
	for p in m.village_layout:
		var o := int(p["owner"])
		if o == i:
			out.append(p["tile"])
			continue
		if o > i:
			p["owner"] = o - 1
		keep.append(p)
	m.village_layout = keep
	m.villages.remove_at(i)
	var links: Array[Vector2i] = []
	for l in m.village_links:
		if l.x != i and l.y != i:
			links.append(Vector2i(l.x - (1 if l.x > i else 0), l.y - (1 if l.y > i else 0)))
	m.village_links = links
	return out


## Swaps villages `i` and `j` (their numbers; slots in co-op).
static func swap_villages(m: MapData, i: int, j: int) -> void:
	if i == j or i < 0 or j < 0 or i >= m.villages.size() or j >= m.villages.size():
		return
	var tmp := m.villages[i]
	m.villages[i] = m.villages[j]
	m.villages[j] = tmp
	for p in m.village_layout:
		var o := int(p["owner"])
		p["owner"] = j if o == i else (i if o == j else o)
	var links: Array[Vector2i] = []
	for l in m.village_links:
		var a := j if l.x == i else (i if l.x == j else l.x)
		var b := j if l.y == i else (i if l.y == j else l.y)
		links.append(Vector2i(mini(a, b), maxi(a, b)))
	m.village_links = links
	m.village_layout.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["owner"]) < int(b["owner"]) or (int(a["owner"]) == int(b["owner"]) and MapData.row_order(a["tile"], b["tile"])))


## A village piece on `t`: `kind` ("wall", "gate", "wall_tower", "hut"),
## "erase", or "flip" (a wall's side). New pieces belong to village `owner`.
static func set_piece(m: MapData, t: Vector2i, kind: String, owner: int) -> Variant:
	if not m.in_bounds(t):
		return "Outside the map"
	for k in m.village_layout.size():
		var p := m.village_layout[k]
		if p["tile"] != t:
			continue
		match kind:
			"erase":
				m.village_layout.remove_at(k)
			"flip":
				p["flip"] = not p["flip"]
			_:
				p["kind"] = kind
		return [t] as Array[Vector2i]
	if kind in ["erase", "flip"]:
		return "No village piece there"
	if owner < 0 or owner >= m.villages.size():
		return "Place or pick a village first"
	var why := MapCheckFree.new(m).why_not(t)
	if why != "":
		return why
	m.village_layout.append({"kind": kind, "tile": t, "flip": false, "owner": owner})
	m.village_layout.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["owner"]) < int(b["owner"]) or (int(a["owner"]) == int(b["owner"]) and MapData.row_order(a["tile"], b["tile"])))
	return [t] as Array[Vector2i]


## Adds or removes a spawn on edge road tile `t` (for village `owner`, or the
## village of its slice when -1).
static func toggle_spawn(m: MapData, t: Vector2i, owner: int) -> Variant:
	for v in m.villages:
		var hs: Array = v["home_spawns"]
		if hs.has(t):
			hs.erase(t)
			return [t] as Array[Vector2i]
	if m.villages.is_empty():
		return "Place a village first"
	if not m.is_edge(t) or not m.is_road(t):
		return "A spawn goes on a road tile at the map's edge"
	var vi := owner
	if vi < 0:
		vi = 0
		for i in m.villages.size():
			if int(m.slice_of[m.index(m.villages[i]["center"])]) == int(m.slice_of[m.index(t)]):
				vi = i
	(m.villages[vi]["home_spawns"] as Array).append(t)
	return [t] as Array[Vector2i]


## Adds or removes a water spawn (docs/aquatic-design.md §9) on deep-water tile `t`.
static func toggle_water_spawn(m: MapData, t: Vector2i) -> Variant:
	if m.water_spawns.has(t):
		m.water_spawns.erase(t)
		return [t] as Array[Vector2i]
	if not m.is_deep(t):
		return "A water spawn goes on deep water"
	m.water_spawns.append(t)
	m.water_spawns.sort_custom(MapData.row_order)
	return [t] as Array[Vector2i]


# --- objects ---------------------------------------------------------------------------------

## A new object of `kind` on `t` with its default fields: its index, or why not.
static func add_object(m: MapData, kind: String, t: Vector2i, size: int = 1) -> Variant:
	var free := MapCheckFree.new(m)
	for p in Building.footprint(t, size):
		var why := free.why_not(p)
		if why != "":
			return why
	var o := {"kind": kind, "tile": t, "size": size}
	match kind:
		"treasure":
			o.merge({"treasure": "chest", "tier": 1, "guard": -1, "reward": {"gold": 50}})
		"camp":
			var g := _unguarded_treasure(m, t)
			if g < 0:
				return "A camp guards a treasure: place one first (one without a camp)"
			o.merge({"tier": int(m.objects[g]["tier"]), "guards": g, "monsters": (Config.CAMP_MONSTERS[int(m.objects[g]["tier"]) - 1] as Array).duplicate()})
		"unlock":
			o.merge({"site": "stone_circle", "unlocks": Config.UNLOCK_SITES["stone_circle"]["unlocks"], "wave": int(Config.UNLOCK_SITES["stone_circle"]["wave"])})
		"lair":
			o["art"] = "lair_cave" if size == 1 else "lair_cave_big"
			o["front"] = _front(m, t, size)
		"mine":
			o["front"] = _front(m, t, size)
		"ruin":
			o["building"] = "barracks" if size == 2 else "tower"  # (a 2x2 ruin was barracks)
	if not o.has("art"):
		o["art"] = MapJson.object_art(o)
	m.objects.append(o)
	var i := m.objects.size() - 1
	if kind == "camp":
		m.objects[o["guards"]]["guard"] = i
	return i


## Moves object `i` to `t`.
static func move_object(m: MapData, i: int, t: Vector2i) -> Variant:
	var o := m.objects[i]
	var free := MapCheckFree.new(m, -1, i)
	for p in Building.footprint(t, int(o.get("size", 1))):
		var why := free.why_not(p)
		if why != "":
			return why
	var out: Array[Vector2i] = Building.footprint(o["tile"], int(o.get("size", 1)))
	var d: Vector2i = t - (o["tile"] as Vector2i)
	o["tile"] = t
	if o.has("front") and m.in_bounds((o["front"] as Vector2i) + d):
		o["front"] = (o["front"] as Vector2i) + d
	out.append_array(Building.footprint(t, int(o.get("size", 1))))
	return out


## Deletes object `i` (a treasure's camp goes with it; a camp's treasure stays).
static func delete_object(m: MapData, i: int) -> Array[Vector2i]:
	var gone := {i: true}
	if m.objects[i]["kind"] == "treasure" and int(m.objects[i].get("guard", -1)) >= 0:
		gone[int(m.objects[i]["guard"])] = true
	var out: Array[Vector2i] = []
	var keep: Array[Dictionary] = []
	var new_index := {}
	for k in m.objects.size():
		if gone.has(k):
			out.append_array(Building.footprint(m.objects[k]["tile"], int(m.objects[k].get("size", 1))))
		else:
			new_index[k] = keep.size()
			keep.append(m.objects[k])
	for o in keep:
		if o["kind"] == "camp":
			o["guards"] = new_index[int(o["guards"])]
		elif o["kind"] == "treasure":
			o["guard"] = -1
	for k in keep.size():
		if keep[k]["kind"] == "camp":
			keep[int(keep[k]["guards"])]["guard"] = k
	m.objects = keep
	return out


## Changes field `key` of object `i` to `value` (keeps the art and the camp link right).
static func set_object_field(m: MapData, i: int, key: String, value: Variant) -> void:
	var o := m.objects[i]
	if key == "guards":
		var old := int(o.get("guards", -1))
		if old >= 0 and old < m.objects.size():
			m.objects[old]["guard"] = -1
		o["guards"] = int(value)
		if int(value) >= 0:
			m.objects[int(value)]["guard"] = i
		return
	o[key] = value
	if key == "site":
		o["unlocks"] = Config.UNLOCK_SITES[value]["unlocks"]
		o["wave"] = int(Config.UNLOCK_SITES[value]["wave"])
	if key == "tier" and o["kind"] == "camp":
		o["monsters"] = (Config.CAMP_MONSTERS[int(value) - 1] as Array).duplicate()
	if o["kind"] != "lair":
		o["art"] = MapJson.object_art(o)


## The nearest treasure to `t` that no camp guards yet (-1: none).
static func _unguarded_treasure(m: MapData, t: Vector2i) -> int:
	var best := -1
	var best_d := INF
	for k in m.objects.size():
		var o := m.objects[k]
		if o["kind"] == "treasure" and int(o.get("guard", -1)) < 0:
			var d := Vector2(o["tile"]).distance_to(Vector2(t))
			if d < best_d:
				best_d = d
				best = k
	return best


## The tile in front of an object at `t`: a road next to it if there is one,
## else the first walkable one (the tile below it otherwise).
static func _front(m: MapData, t: Vector2i, size: int) -> Vector2i:
	var foot := Building.footprint(t, size)
	var ring: Array[Vector2i] = []
	for p in foot:
		for n in MapData.neighbors4(p):
			if m.in_bounds(n) and not foot.has(n) and not ring.has(n):
				ring.append(n)
	for n in ring:
		if m.is_road(n):
			return n
	for n in ring:
		if m.is_passable(n):
			return n
	return foot[0] + Vector2i(0, size)


## Which tiles can take a new piece or object (`skip_village` / `skip_object`:
## the one being moved doesn't count).
class MapCheckFree:
	var m: MapData
	var pieces := {}
	var objects := {}

	func _init(p_m: MapData, skip_village: int = -1, skip_object: int = -1) -> void:
		m = p_m
		for p in m.village_layout:
			if int(p["owner"]) != skip_village:
				pieces[p["tile"]] = true
		for k in m.objects.size():
			if k != skip_object:
				for t in Building.footprint(m.objects[k]["tile"], int(m.objects[k].get("size", 1))):
					objects[t] = true

	func why_not(t: Vector2i) -> String:
		if not m.in_bounds(t):
			return "Outside the map"
		if pieces.has(t):
			return "A village stands there"
		if objects.has(t):
			return "Something stands there already"
		if MapTidy.in_volcano(m, t):
			return "A volcano is there"
		return ""
