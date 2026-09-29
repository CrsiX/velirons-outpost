class_name GenZones
extends RefCounted
## Stage 5 (docs/world-design.md §4): every tile gets a zone from height x
## moisture (ash land only around volcanoes), then trees and decoration by
## zone. Steppe tiles are DESERT terrain (no farms); trees are FOREST terrain
## with a tree prop, as before.


static func paint(c: GenContext) -> void:
	var m := c.m
	var water_dist := c.distance_to(func(t: Vector2i) -> bool: return m.is_water(t))
	var dn2 := FastNoiseLite.new()
	dn2.seed = c.seed_value * 19 + 7
	dn2.frequency = 0.17
	var steppe: Array[Vector2] = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var k := c.i(t)
			var hm := c.height[k] + c.detail[k] * Config.ZONE_BLEND
			var mo := c.moisture[k] + dn2.get_noise_2d(x, y) * Config.ZONE_BLEND
			var z := _classify(hm, mo, water_dist[k])
			if c.ash.has(t):
				z = "ash"
			m.set_zone(t, z)
			if z == "steppe":
				steppe.append(Vector2(-mo, k))
	# Cap the steppe: the wettest of it becomes meadow.
	var cap := int(float(c.type.get("steppe_max", Config.DESERT_MAX_SHARE)) * m.size * m.size)
	if steppe.size() > cap:
		steppe.sort()
		for r in steppe.size() - cap:
			m.zones[int(steppe[r].y)] = Config.ZONE_ORDER.find("meadow")
	_vegetate(c)


static func _classify(hm: float, mo: float, water_d: int) -> String:
	if mo > 0.7 and hm < 0.45 and water_d <= 5:
		return "swamp"
	if mo < 0.2:
		return "steppe" if hm < 0.72 else "heath"
	if hm > 0.7 and mo < 0.58:
		return "heath"
	if mo > 0.6:
		return "pine"
	if mo > 0.43 or hm > 0.62:
		return "oak"
	return "meadow"


static func _vegetate(c: GenContext) -> void:
	var m := c.m
	var clump := FastNoiseLite.new()
	clump.seed = c.seed_value * 23 + 1
	clump.frequency = 0.11
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if not c.is_land(t):
				continue
			var z := m.zone(t)
			var spec: Dictionary = Config.ZONES[z]
			m.set_terrain(t, MapData.Terrain.DESERT if z == "steppe" else MapData.Terrain.GRASS)
			if c.beaches.has(t):
				continue
			var p := float(spec["trees"]) * (0.45 + 1.1 * (clump.get_noise_2d(x, y) * 0.5 + 0.5))
			if c.rng.randf() < p:
				m.set_terrain(t, MapData.Terrain.FOREST)
				m.props[t] = c.pick(spec["mix"])
			elif c.rng.randf() < float(spec.get("decor", 0.0)):
				m.decor[t] = c.pick(spec["decor_mix"])


## Makes `t` open, walkable land of zone `z` (no trees, no decoration).
static func clear(c: GenContext, t: Vector2i, z: String = "") -> void:
	var m := c.m
	if not m.in_bounds(t):
		return
	if z != "":
		m.set_zone(t, z)
	if m.get_terrain(t) != MapData.Terrain.ROAD:
		m.set_terrain(t, MapData.Terrain.DESERT if m.zone(t) == "steppe" else MapData.Terrain.GRASS)
	m.props.erase(t)
	m.decor.erase(t)
	c.sea.erase(t)
	c.rivers.erase(t)
