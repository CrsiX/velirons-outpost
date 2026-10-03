class_name GenFixes
extends RefCounted
## Stage 9 (docs/world-design.md §3.2): small local repairs after the big
## stages, per village:
##   - a guaranteed 3x3 farm plot next to the clearing (repainted as meadow if
##     the ground there doesn't allow farms),
##   - fair land: no steppe, swamp or ash within ZONE_FAIR_CLEAR, and at least
##     ZONE_FAIR_MIN meadow and trees within ZONE_FAIR_RADIUS,
##   - trees within reach of the worker camp.


static func run(c: GenContext) -> void:
	for v in c.m.villages:
		_fair_land(c, v)
		_farm_plot(c, v)
		_camp_trees(c, v)
	c.m.farm_plot = c.m.villages[0]["farm_plot"]


static func _fair_land(c: GenContext, v: Dictionary) -> void:
	var m := c.m
	var centre: Vector2i = v["center"]
	var r := int(Config.ZONE_FAIR_RADIUS)
	var land: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := centre + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(Vector2(centre))
			if not m.in_bounds(t) or d > Config.ZONE_FAIR_RADIUS or not c.is_land(t) or m.in_village(t):
				continue
			if d <= Config.ZONE_FAIR_CLEAR and m.zone(t) in ["steppe", "swamp", "ash"]:
				_to_meadow(m, t)
				if m.is_forest(t):
					m.props[t] = "tree_oak"
			land.append(t)
	if land.is_empty():
		return
	# Enough meadow: the nearest open tiles become meadow.
	var need_meadow := int(ceil(Config.ZONE_FAIR_MIN["meadow"] * land.size()))
	var meadow := land.filter(func(t: Vector2i) -> bool: return m.zone(t) == "meadow").size()
	if meadow < need_meadow:
		var open := land.filter(func(t: Vector2i) -> bool: return m.zone(t) != "meadow" and not m.is_forest(t))
		open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(Vector2(centre)) < Vector2(b).distance_squared_to(Vector2(centre)))
		for t in open.slice(0, need_meadow - meadow):
			_to_meadow(m, t)
	# Enough trees: woods grow in patches (Config.ZONE_FAIR_WOODS).
	var need_trees := int(ceil(Config.ZONE_FAIR_MIN["trees"] * land.size()))
	var trees := land.filter(func(t: Vector2i) -> bool: return m.is_forest(t)).size()
	if trees < need_trees:
		var ring := Config.FOREST_CLEARING_RING + 1
		var open := land.filter(func(t: Vector2i) -> bool: return not m.is_forest(t) and not m.is_road(t) and maxi(absi(t.x - centre.x), absi(t.y - centre.y)) > ring and not _next_to_road(m, t))
		_grow_woods(c, centre, open, need_trees - trees, float(Config.ZONE_FAIR_WOODS["far"]))


## Plants `count` trees on tiles of `open`, the best scoring first (forest
## around it, a noise patch, `far` x distance from `centre`, so negative:
## nearest first; meadow last). Each tile
## becomes woods of ZONE_FAIR_WOODS["zone"], so ground and trees match.
static func _grow_woods(c: GenContext, centre: Vector2i, open: Array, count: int, far: float) -> void:
	var m := c.m
	var w: Dictionary = Config.ZONE_FAIR_WOODS
	var noise := FastNoiseLite.new()
	noise.seed = c.seed_value * 31 + centre.x * 101 + centre.y
	noise.frequency = float(w["noise"])
	var base := {}
	for t: Vector2i in open:
		base[t] = float(w["clump"]) * (noise.get_noise_2d(t.x, t.y) * 0.5 + 0.5) \
			+ far * Vector2(t).distance_to(Vector2(centre)) / Config.ZONE_FAIR_RADIUS \
			- (float(w["meadow"]) if m.zone(t) == "meadow" else 0.0)
	var zone: String = w["zone"]
	for i in mini(count, open.size()):
		var best := -1
		var best_s := -INF
		for k in open.size():
			var t: Vector2i = open[k]
			var s: float = base[t]
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and m.is_forest(t + Vector2i(dx, dy)):
						s += float(w["grow"])
			if s > best_s:
				best_s = s
				best = k
		var t: Vector2i = open[best]
		open.remove_at(best)
		m.set_zone(t, zone)
		m.set_terrain(t, MapData.Terrain.FOREST)
		m.props[t] = c.pick(Config.ZONES[zone]["mix"])
		m.decor.erase(t)


static func _next_to_road(m: MapData, t: Vector2i) -> bool:
	for nb in MapData.neighbors4(t):
		if m.is_road(nb):
			return true
	return false


## Guarantees one 3x3 farm plot touching the village's clear ring, inside its
## starting view; stored as the village's "farm_plot".
## `t` becomes meadow: grass instead of sand, no decor.
static func _to_meadow(m: MapData, t: Vector2i) -> void:
	m.set_zone(t, "meadow")
	if m.get_terrain(t) == MapData.Terrain.DESERT:
		m.set_terrain(t, MapData.Terrain.GRASS)
	m.decor.erase(t)


static func _farm_plot(c: GenContext, v: Dictionary) -> void:
	var m := c.m
	var centre: Vector2i = v["center"]
	var corners: Array[Vector2i] = [Vector2i(4, 4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-4, -4)]
	c.shuffle(corners)
	for off in [Vector2i(5, 5), Vector2i(-5, 5), Vector2i(5, -5), Vector2i(-5, -5), Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 6), Vector2i(0, -6)]:
		corners.append(off)
	for off in corners:
		var plot := centre + off
		var ok := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var t := plot + Vector2i(dx, dy)
				if not m.in_bounds(t) or m.is_road(t) or m.in_village(t) or m.is_edge(t):
					ok = false
		if not ok:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				GenZones.clear(c, plot + Vector2i(dx, dy), "meadow")
		# A walkway from the plot to the ring around the walls.
		var step := -off.sign()
		var p := plot
		while maxi(absi(p.x - centre.x), absi(p.y - centre.y)) > Config.FOREST_CLEARING_RING:
			p += step
			for t in [p, p - Vector2i(step.x, 0)]:
				if not m.is_road(t) and not m.in_village(t):
					GenZones.clear(c, t)
		v["farm_plot"] = plot
		return
	c.fail("no farm plot for village at %s" % str(centre))


## A worker camp wants 8+ trees within 5 tiles of a spot near the village (the camp itself needs 6): if
## no such spot exists, a small round grove of woods is planted (ZONE_FAIR_WOODS["grove"] trees).
static func _camp_trees(c: GenContext, v: Dictionary) -> void:
	var m := c.m
	var centre: Vector2i = v["center"]
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var t := centre + Vector2i(dx, dy)
			if maxi(absi(dx), absi(dy)) <= Config.FOREST_CLEARING_RING or not c.is_land(t) or m.is_forest(t):
				continue
			var n := 0
			for ny in range(-5, 6):
				for nx in range(-5, 6):
					if m.is_forest(t + Vector2i(nx, ny)):
						n += 1
			if n >= 8:
				return
	# Plant a grove on the side away from the farm plot.
	var away: Vector2i = -((v["farm_plot"] as Vector2i) - centre).sign() if v["farm_plot"] != Vector2i(-1, -1) else Vector2i(1, 0)
	var grove := centre + away * 8
	var open: Array = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := grove + Vector2i(dx, dy)
			if Vector2(dx, dy).length() <= 3.2 and c.is_land(t) and not m.is_forest(t) and not m.is_road(t) and not _next_to_road(m, t) and not m.in_village(t):
				open.append(t)
	_grow_woods(c, grove, open, int(Config.ZONE_FAIR_WOODS["grove"]), -float(Config.ZONE_FAIR_WOODS["far"]))
