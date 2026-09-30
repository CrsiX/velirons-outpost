class_name GenRelief
extends RefCounted
## Stage 4 (docs/world-design.md §7): mountain ranges along the ridges of a
## ridge noise on high ground, volcanoes (3x3, impassable) with a ragged ring
## of ash land, and on the Volcanic type a lava river from each volcano.

const PEAK_ARTS: Array[String] = ["mountain_0", "mountain_1", "mountain_2"]


static func raise(c: GenContext) -> void:
	_mountains(c)
	_volcanoes(c)
	for y in c.m.size:
		for x in c.m.size:
			var t := Vector2i(x, y)
			if c.m.is_mountain(t) and not _volcano_tile(c, t):
				c.m.props[t] = PEAK_ARTS[c.rng.randi() % PEAK_ARTS.size()]


static func _mountains(c: GenContext) -> void:
	var m := c.m
	var rn := FastNoiseLite.new()
	rn.seed = c.seed_value * 31 + 3
	rn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rn.frequency = 1.0 / (Config.ZONE_SIZE * 1.5)
	rn.fractal_octaves = 2
	var scored: Array[Vector2] = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if not c.is_land(t) or c.near_slice_centre(t, Config.VILLAGE_CENTER_RADIUS - 4.0):
				continue
			var ridge := 1.0 - absf(rn.get_noise_2d(x, y))
			var s := ridge * 0.7 + c.h(t) * 0.3 + c.detail[c.i(t)] * 0.03
			scored.append(Vector2(-s, c.i(t)))
	scored.sort()
	var share := c.rng.randf_range(Config.MOUNTAIN_SHARE.x, Config.MOUNTAIN_SHARE.y) * float(c.type.get("mountains", 1.0))
	var n := mini(int(share * m.size * m.size), scored.size())
	for r in n:
		m.terrain[int(scored[r].y)] = MapData.Terrain.MOUNTAIN
	# Lone specks aren't ranges.
	var seen := {}
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if not m.is_mountain(t) or seen.has(t):
				continue
			var comp: Array[Vector2i] = [t]
			seen[t] = true
			var head := 0
			while head < comp.size():
				var p := comp[head]
				head += 1
				for nb in MapData.neighbors4(p):
					if m.is_mountain(nb) and not seen.has(nb):
						seen[nb] = true
						comp.append(nb)
			if comp.size() < 5:
				for p in comp:
					m.set_terrain(p, MapData.Terrain.GRASS)


static func _volcano_tile(c: GenContext, t: Vector2i) -> bool:
	for v in c.m.volcanoes:
		if absi(t.x - v.x) <= 1 and absi(t.y - v.y) <= 1:
			return true
	return false


static func _volcanoes(c: GenContext) -> void:
	var m := c.m
	var vr: Array = c.type.get("volcanoes", [0, 0])
	var n := c.rng.randi_range(int(vr[0]), int(vr[1]))
	for k in n:
		var best := Vector2i(-1, -1)
		var best_s := -INF
		for dist_try in [Config.VOLCANO_SLICE_DIST, Config.VOLCANO_SLICE_DIST * 0.75, Config.VILLAGE_VOLCANO_DIST]:
			for sample in 120:
				var t := Vector2i(c.rng.randi_range(6, m.size - 7), c.rng.randi_range(6, m.size - 7))
				if c.near_slice_centre(t, dist_try):
					continue
				var ok := true
				for v in m.volcanoes:
					ok = ok and Vector2(t).distance_to(Vector2(v)) >= 16.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var p := t + Vector2i(dx, dy)
						ok = ok and (c.is_land(p) or m.is_mountain(p))
				if not ok:
					continue
				var mountains := 0
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						if m.is_mountain(t + Vector2i(dx, dy)):
							mountains += 1
				var s := c.h(t) + minf(mountains, 8) * 0.08 + c.rng.randf() * 0.1
				if s > best_s:
					best_s = s
					best = t
			if best.x >= 0:
				break
		if best.x < 0:
			continue
		m.volcanoes.append(best)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := best + Vector2i(dx, dy)
				m.set_terrain(p, MapData.Terrain.MOUNTAIN)
				m.props.erase(p)
		m.props[best] = "volcano"
		# Ash land: a ragged ring around the crater (painted in the zone stage).
		var r := int(Config.VOLCANO_ASH_RADIUS + 2)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p := best + Vector2i(dx, dy)
				if m.in_bounds(p) and Vector2(p).distance_to(Vector2(best)) <= Config.VOLCANO_ASH_RADIUS + c.detail[c.i(p)] * 1.5:
					c.ash[p] = true
		if c.type.get("lava_rivers", false):
			# From a flank of the volcano down the slope (try each side until one flows).
			var sides: Array[Vector2i] = [Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
			var start := c.rng.randi() % sides.size()
			for j in sides.size():
				var src := best + sides[(start + j) % sides.size()]
				if not m.in_bounds(src) or not c.is_land(src):
					continue
				var before := c.rivers.size()
				GenWater.route_river(c, src, true, 28)
				if c.rivers.size() - before >= 3:
					break
