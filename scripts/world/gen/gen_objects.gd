class_name GenObjects
extends RefCounted
## Stage 10 (docs/world-design.md §9): special objects, placed per slice.
## Not every kind appears in every slice (mines need mountains, lairs and
## ruins are spread out, unlock sites come in fewer copies than slices); what
## is kept fair is the treasure count and tiers per slice. Every object stands
## on land reachable from its slice's village. Entries of MapData.objects:
##   {"kind": "treasure" | "camp" | "unlock" | "ruin" | "lair" | "mine",
##    "art", "tile", "size", "slice", ...kind-specific fields}

var c: GenContext
var m: MapData
var reach := PackedInt32Array()  # per tile: walking-connected area id, or -1
var _home_area: Array[int] = []  # per village: the area id of its centre
var _router: GenRoads = null  # (for mine spurs, set up once)
var _lair_router: GenRoads = null  # (for lair roads, which keep off the objects)


static func place(p_c: GenContext) -> void:
	var g := GenObjects.new()
	g.c = p_c
	g.m = p_c.m
	g._reach()
	g._mines()
	g._reach()  # (mine spurs may connect more land)
	g._ruins()
	g._treasures()
	g._unlock_sites()
	g._lairs()


# --- helpers ---------------------------------------------------------------------------------

## Which village each walkable tile is reachable from (walking, not roads only).
func _reach() -> void:
	reach.resize(m.size * m.size)
	reach.fill(-1)
	_home_area.clear()
	for vi in m.villages.size():
		var start: Vector2i = m.villages[vi]["center"]
		_home_area.append(reach[c.i(start)] if reach[c.i(start)] >= 0 else vi)
		if reach[c.i(start)] >= 0:
			continue
		var queue: Array[Vector2i] = [start]
		reach[c.i(start)] = vi
		var head := 0
		while head < queue.size():
			var t := queue[head]
			head += 1
			for nb in MapData.neighbors4(t):
				if m.in_bounds(nb) and reach[c.i(nb)] < 0 and m.is_passable(nb):
					reach[c.i(nb)] = vi
					queue.append(nb)


## Can an object of `size` stand with its anchor on `t` (land, no road, not
## in a village, away from other objects, reachable from village `vi`)?
func _free(t: Vector2i, size: int, vi: int, spacing: float = Config.OBJECT_SPACING) -> bool:
	for p in Building.footprint(t, size):
		if not m.in_bounds(p) or m.is_edge(p) or not c.is_land(p) or m.is_road(p) or m.in_village(p):
			return false
		for v in m.villages:
			if Vector2(p).distance_to(Vector2(v["center"])) < Config.FOREST_CLEARING_RING + 4:
				return false
		for v in m.villages:
			var fp: Vector2i = v["farm_plot"]
			if fp.x >= 0 and absi(p.x - fp.x) <= 2 and absi(p.y - fp.y) <= 2:
				return false
	for o in m.objects:
		if Vector2(t).distance_to(Vector2(o["tile"])) < spacing:
			return false
	# Reachable: the tile itself or a walkable neighbour.
	var area := _home_area[vi]
	for p in Building.footprint(t, size):
		if reach[c.i(p)] == area:
			return true
		for nb in MapData.neighbors4(p):
			if m.in_bounds(nb) and reach[c.i(nb)] == area:
				return true
	return false


func _village_of_slice(s: int) -> int:
	for vi in m.villages.size():
		if int(m.villages[vi].get("slice", 0)) == s:
			return vi
	return 0


func _nearest_village_dist(t: Vector2i) -> float:
	var d := INF
	for v in m.villages:
		d = minf(d, Vector2(t).distance_to(Vector2(v["center"])))
	return d


## A random tile in slice `s` at a distance within `band` from its village,
## for which `ok` holds. (-1, -1) if none found.
func _sample(s: int, band: Vector2, ok: Callable, tries: int = 300) -> Vector2i:
	var vi := _village_of_slice(s)
	var centre := Vector2(m.villages[vi]["center"])
	for k in tries:
		var a := c.rng.randf() * TAU
		var d := c.rng.randf_range(band.x, band.y)
		var t := Vector2i((centre + Vector2.from_angle(a) * d).round())
		if m.in_bounds(t) and m.slice_of[c.i(t)] == s and ok.call(t):
			return t
	return Vector2i(-1, -1)


func _add(o: Dictionary) -> int:
	for p in Building.footprint(o["tile"], o.get("size", 1)):
		if o["kind"] != "mine":
			GenZones.clear(c, p)
	m.objects.append(o)
	return m.objects.size() - 1


# --- mines --------------------------------------------------------------------------------------

func _mines() -> void:
	var want := Config.MINES_PER_SLICE * float(c.type.get("mines", 1.0))
	# Outer-edge mountain tiles per slice (a walkable, reachable tile in front).
	var by_slice: Array = []
	for s in c.players:
		by_slice.append([])
	for y in range(1, m.size - 1):
		for x in range(1, m.size - 1):
			var t := Vector2i(x, y)
			if not m.is_mountain(t) or GenRelief._volcano_tile(c, t) or _nearest_village_dist(t) < Config.MINE_DISTANCE:
				continue
			var s := m.slice_of[c.i(t)]
			if _front(t, _village_of_slice(s)).x >= 0:
				by_slice[s].append(t)
	var placed := 0
	for s in c.players:
		var n := int(want) + (1 if c.rng.randf() < want - int(want) else 0)
		for k in n:
			if _mine_in(s, by_slice[s]):
				placed += 1
	if placed == 0:
		for s in c.players:
			if _mine_in(s, by_slice[s]):
				break


func _mine_in(s: int, candidates: Array) -> bool:
	var vi := _village_of_slice(s)
	var free := candidates.filter(func(t: Vector2i) -> bool: return m.objects.all(func(o: Dictionary) -> bool: return Vector2(t).distance_to(Vector2(o["tile"])) >= 8.0))
	if free.is_empty():
		return false
	var t: Vector2i = free[c.rng.randi() % free.size()]
	var front := _front(t, vi)
	m.props.erase(t)
	_add({"kind": "mine", "art": "mine", "tile": t, "size": 1, "slice": s, "front": front})
	if _router == null:
		_router = GenRoads.router(c)
	_router.spur_from(front)
	return true


## The walkable land tile in front of a mountain tile (outer edge of a range).
func _front(t: Vector2i, vi: int) -> Vector2i:
	for nb in MapData.neighbors4(t):
		if c.is_land(nb) and not m.in_village(nb) and reach[c.i(nb)] == _home_area[vi] and not m.is_edge(nb):
			return nb
	return Vector2i(-1, -1)


# --- ruined watchtowers --------------------------------------------------------------------------

func _ruins() -> void:
	for s in c.players:
		var vi := _village_of_slice(s)
		for k in c.count_in(Config.RUINED_TOWERS):
			var best := Vector2i(-1, -1)
			var best_s := -INF
			for tries in 12:
				var t := _sample(s, Config.RUIN_DISTANCE, func(p: Vector2i) -> bool: return _free(p, 1, vi) and _roads_near(p, 2) > 0)
				if t.x < 0:
					continue
				var score := float(_roads_near(t, 2)) + c.rng.randf()
				if score > best_s:
					best_s = score
					best = t
			if best.x >= 0:
				_add({"kind": "ruin", "art": "watchtower_ruin", "tile": best, "size": 1, "slice": s})


func _roads_near(t: Vector2i, r: int) -> int:
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if m.is_road(t + Vector2i(dx, dy)):
				n += 1
	return n


# --- treasures and camps ------------------------------------------------------------------------

func _treasures() -> void:
	var k := c.count_in(Config.TREASURE_COUNT)
	var relics := 0
	var relic_keys: Array = Config.RELICS.keys()
	for s in c.players:
		var vi := _village_of_slice(s)
		for j in k:
			var tier := 1 + int(j * 3 / k)  # the same tier pattern in every slice
			var lo: float = Config.TREASURE_DISTANCE.x if tier == 1 else Config.TREASURE_TIER_DIST[tier - 2]
			var hi: float = Config.TREASURE_TIER_DIST[tier - 1] if tier < 3 else Config.TREASURE_DISTANCE.y
			var t := _treasure_spot(s, vi, tier, lo, hi)
			if t.x < 0:
				continue
			var kind := _treasure_kind(t)
			var spec: Dictionary = Config.TREASURES[kind]
			var o := {"kind": "treasure", "treasure": kind, "art": kind, "tile": t, "size": 1, "slice": s, "tier": tier, "guard": -1}
			var reward_src: Dictionary = spec["reward"]
			if spec.has("alt_reward") and c.rng.randf() < 0.5:
				reward_src = spec["alt_reward"]
			var reward := {}
			for key in reward_src:
				var r: Array = reward_src[key]
				var base := c.rng.randi_range(int(r[0]), int(r[1]))
				reward[key] = base if key == "heal_units" else roundi(base * Config.TREASURE_TIER_SCALE[tier - 1])
			if spec.get("relic", false) and tier >= 2 and relics < Config.RELIC_MAX and c.rng.randf() < 0.5:
				reward = {"relic": relic_keys[c.rng.randi() % relic_keys.size()]}
				relics += 1
			o["reward"] = reward
			var idx := _add(o)
			if c.rng.randf() < Config.CAMP_CHANCE[tier - 1]:
				_camp_for(idx, s, vi, tier)


func _treasure_kind(t: Vector2i) -> String:
	var z := m.zone(t)
	var weights := {}
	for kind in Config.TREASURES:
		var zones: Array = Config.TREASURES[kind]["zones"]
		var fits := zones.is_empty() or zones.has(z) or (zones.has("beach") and c.beaches.has(t)) or (zones.has("hills") and c.h(t) > 0.65)
		if kind == "shipwreck" and not c.beaches.has(t):
			fits = false
		if fits:
			weights[kind] = Config.TREASURES[kind]["weight"]
	return c.pick(weights) if not weights.is_empty() else "chest"


## Where a treasure of this tier goes. A tier-3 one always gets a camp, so it
## needs room for one beside it; if its band is too crowded, it may come
## closer to the village (still tier 3) rather than be left out.
func _treasure_spot(s: int, vi: int, tier: int, lo: float, hi: float) -> Vector2i:
	if tier < 3:
		return _sample(s, Vector2(lo, hi), func(p: Vector2i) -> bool: return _free(p, 1, vi))
	var fits := func(p: Vector2i) -> bool: return _free(p, 1, vi) and _camp_ring(p, vi).x >= 0
	for low in [lo, Config.TREASURE_TIER_DIST[0], Config.TREASURE_DISTANCE.x]:
		var t := _sample(s, Vector2(low, hi), fits)
		if t.x >= 0:
			return t
	return _sample(s, Vector2(lo, hi), func(p: Vector2i) -> bool: return _free(p, 1, vi))


func _camp_for(idx: int, s: int, vi: int, tier: int) -> void:
	var at: Vector2i = m.objects[idx]["tile"]
	var spot := Vector2i(-1, -1)
	for tries in 40:
		var t := at + Vector2i(c.rng.randi_range(-3, 3), c.rng.randi_range(-3, 3))
		var d := Vector2(t).distance_to(Vector2(at))
		if d >= 1.9 and d <= 3.2 and _free(t, 1, vi, 1.5):
			spot = t
			break
	if spot.x < 0:
		spot = _camp_ring(at, vi)
	if spot.x < 0:
		return
	var cid := _add({"kind": "camp", "art": "camp", "tile": spot, "size": 1, "slice": s, "tier": tier, "guards": idx, "monsters": (Config.CAMP_MONSTERS[tier - 1] as Array).duplicate()})
	m.objects[idx]["guard"] = cid


## The first free tile 2-3 tiles from a treasure where its camp could stand.
func _camp_ring(at: Vector2i, vi: int) -> Vector2i:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := at + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(at))
			if d >= 1.9 and d <= 3.2 and _free(t, 1, vi, 1.5):
				return t
	return Vector2i(-1, -1)


# --- unit-unlock sites ---------------------------------------------------------------------------

func _unlock_sites() -> void:
	var copies := maxi(1, int(floor(c.players * Config.UNLOCK_SITE_SHARE)))
	for kind in Config.UNLOCK_SITES:
		var spec: Dictionary = Config.UNLOCK_SITES[kind]
		var order: Array = range(c.players)
		c.shuffle(order)
		var placed := 0
		for s in order:
			if placed >= copies:
				break
			var vi := _village_of_slice(s)
			var band := Vector2(spec["distance"][0], spec["distance"][1])
			var t := _sample(s, band, func(p: Vector2i) -> bool: return _free(p, 1, vi))
			if t.x < 0:
				t = _sample(s, band + Vector2(-2, 6), func(p: Vector2i) -> bool: return _free(p, 1, vi, 3.0))
			if t.x < 0:
				continue
			_add({"kind": "unlock", "site": kind, "art": kind if kind != "mage_tower" else "mage_tower_ruin", "tile": t, "size": 1, "slice": s, "unlocks": spec["unlocks"], "wave": spec["wave"]})
			placed += 1
		if placed == 0:
			c.fail("no room for any %s" % kind)


# --- lairs ------------------------------------------------------------------------------------

func _lairs() -> void:
	for s in c.players:
		var vi := _village_of_slice(s)
		for k in c.count_in(Config.LAIRS_PER_SLICE):
			var found := false
			for tries in 60:
				var t := _sample(s, Vector2(Config.LAIR_DISTANCE, Config.LAIR_DISTANCE + 25.0), func(p: Vector2i) -> bool: return _lair_art(p) != "", 20)
				if t.x < 0:
					continue
				var art := _lair_art(t)
				var size := 2 if art == "lair_tree" or c.rng.randf() < 0.5 else 1
				if not _free(t, size, vi):
					size = 1
					if art == "lair_tree" or not _free(t, 1, vi):
						continue
				var front := _lair_road(t, size, vi)
				if front.x < 0:
					continue
				if size == 2 and art != "lair_tree":
					art += "_big"
				_add({"kind": "lair", "art": art, "tile": t, "size": size, "slice": s, "front": front})
				found = true
				break
			if not found:
				break


## Links a lair at `t` to the road network by a winding road (§9.6). Returns
## the tile in front of it where its road starts, or (-1, -1) if no road fits.
func _lair_road(t: Vector2i, size: int, vi: int) -> Vector2i:
	if _lair_router == null:
		_lair_router = GenRoads.router(c)
		for o in m.objects:  # roads keep off the other objects
			for p in Building.footprint(o["tile"], o.get("size", 1)):
				_lair_router.astar.set_point_solid(p, true)
	var astar := _lair_router.astar
	var foot := Building.footprint(t, size)
	var fronts: Array[Vector2i] = []
	for p in foot:
		for nb in MapData.neighbors4(p):
			if foot.has(nb) or fronts.has(nb) or not m.in_bounds(nb):
				continue
			if m.is_road(nb):
				return nb
			if c.is_land(nb) and not m.in_village(nb) and not m.is_edge(nb) and reach[c.i(nb)] == _home_area[vi] and not astar.is_point_solid(nb):
				fronts.append(nb)
	var centre := Vector2(m.villages[vi]["center"])
	fronts.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(centre) < Vector2(b).distance_to(centre))
	var was: Array[bool] = []
	for p in foot:
		was.append(astar.is_point_solid(p))
		astar.set_point_solid(p, true)
	for f in fronts:
		if _lair_router.winding_spur_from(f):
			return f
	for k in foot.size():
		astar.set_point_solid(foot[k], was[k])
	return Vector2i(-1, -1)


## The lair art that fits the surroundings of `t` ("" if none).
func _lair_art(t: Vector2i) -> String:
	for nb in MapData.neighbors4(t):
		if m.is_mountain(nb) and not GenRelief._volcano_tile(c, nb):
			return Config.LAIRS["mountain"]
	return Config.LAIRS.get(m.zone(t), "")
