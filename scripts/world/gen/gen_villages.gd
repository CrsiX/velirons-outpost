class_name GenVillages
extends RefCounted
## Stage 6 (docs/world-design.md §3.2): each slice's village goes on the best
## tile within VILLAGE_CENTER_RADIUS of the slice's centre: the 7x7 block on
## land (no water, mountain or lava under it, trees are cleared), land in
## front of every gate, away from the sea, volcanoes, other villages and the
## slice border. If nothing qualifies the rules are loosened step by step.
## The village (Config.VILLAGE_LAYOUT, its town hall included) is then
## stamped in; its free tiles and paths are grass.

## Loosening steps: [radius, border gap, volcano distance, sea distance].
const TIERS: Array = [
	[Config.VILLAGE_CENTER_RADIUS, Config.VILLAGE_BORDER_GAP, Config.VILLAGE_VOLCANO_DIST, Config.VILLAGE_SEA_DIST],
	[Config.VILLAGE_CENTER_RADIUS + 4.0, 5.0, 14.0, 6.0],
	[Config.VILLAGE_CENTER_RADIUS + 12.0, 2.0, 8.0, 3.0],
]


static func place(c: GenContext) -> void:
	var m := c.m
	var sea_dist := c.distance_to(func(t: Vector2i) -> bool: return c.sea.has(t))
	for s in c.players:
		var centre: Vector2 = m.slices[s]["center"]
		var spot := Vector2i(-1, -1)
		for tier in TIERS:
			spot = _best(c, s, centre, tier, sea_dist)
			if spot.x >= 0:
				break
		if spot.x < 0:
			spot = Vector2i(centre.round())
			c.fail("no good village spot in slice %d" % s)
		_stamp(c, spot, s)
	m.village_rect = m.villages[0]["rect"]


## Can the village stand with its centre on `t`: its block on land, nothing
## on a crater, and land (forest is fine) in front of every gate?
static func fits(c: GenContext, t: Vector2i) -> bool:
	var h := Config.VILLAGE_HALF
	for dy in range(-h, h + 1):
		for dx in range(-h, h + 1):
			var p := t + Vector2i(dx, dy)
			if not c.is_land(p) or c.m.near_crater(p):
				return false
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if not c.is_land(t + d * (h + 1)):
			return false
	return true


static func _best(c: GenContext, s: int, centre: Vector2, tier: Array, sea_dist: PackedInt32Array) -> Vector2i:
	var m := c.m
	var radius: float = tier[0]
	var r := int(ceil(radius))
	var margin := Config.VILLAGE_MAP_MARGIN
	var best := Vector2i(-1, -1)
	var best_s := INF
	var ct := Vector2i(centre.round())
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := ct + Vector2i(dx, dy)
			var d := Vector2(t).distance_to(centre)
			if d > radius or t.x < margin or t.y < margin or t.x > m.size - 1 - margin or t.y > m.size - 1 - margin:
				continue
			var k := c.i(t)
			if m.slice_of[k] != s:
				continue
			if c.players > 1 and c.border_dist[k] < int(tier[1]):
				continue
			if not c.sea.is_empty() and sea_dist[k] < int(tier[3]):
				continue
			var far := true
			for v in m.volcanoes:
				far = far and Vector2(t).distance_to(Vector2(v)) >= float(tier[2])
			for other in m.villages:
				far = far and Vector2(t).distance_to(Vector2(other["center"])) >= 14.0
			if not far or not fits(c, t):
				continue
			var score := d
			match m.zone(t):
				"steppe", "swamp", "ash": score += 5.0
				"pine": score += 1.0
				"meadow": score -= 0.5
			if score < best_s:
				best_s = score
				best = t
	return best


## Lays out the walled village around `center` (Config.VILLAGE_LAYOUT): its
## tiles cleared to grass (steppe, swamp and ash inside become meadow), the
## gates on road.
static func _stamp(c: GenContext, center: Vector2i, s: int) -> void:
	var m := c.m
	var id := m.villages.size()
	var h := Config.VILLAGE_HALF
	var rect := Rect2i(center - Vector2i(h, h), Vector2i(2 * h + 1, 2 * h + 1))
	var v := {"center": center, "rect": rect, "gates": [] as Array[Vector2i], "home_spawns": [] as Array[Vector2i], "slice": s}
	m.villages.append(v)
	for t in MapData.rect_tiles(rect):
		var z := m.zone(t)
		GenZones.clear(c, t, "meadow" if z in ["steppe", "swamp", "ash"] else z)
		m.decor.erase(t)
	# One material for the whole village, by map type.
	var mat: String = Config.PIECE_MATERIAL_BY_MAP_TYPE.get(c.type_key, "stone")
	for p in MapData.standard_pieces(center, mat):
		p["owner"] = id
		m.village_layout.append(p)
		if p["kind"] == "gate":
			var t: Vector2i = p["tile"]
			m.gates.append(t)
			(v["gates"] as Array[Vector2i]).append(t)
			m.set_terrain(t, MapData.Terrain.ROAD)
