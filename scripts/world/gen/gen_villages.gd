class_name GenVillages
extends RefCounted
## Stage 6 (docs/world-design.md §3.2): each slice's village goes on the best
## tile within VILLAGE_CENTER_RADIUS of the slice's centre: dry, flat,
## buildable land, no water, mountains or volcano close to the walls, away
## from the slice border. If nothing qualifies the rules are loosened step by
## step. The 5x5 village and its clearing ring are then stamped in.

## Loosening steps: [radius, border gap, clear radius, volcano distance, sea distance].
const TIERS: Array = [
	[Config.VILLAGE_CENTER_RADIUS, Config.VILLAGE_BORDER_GAP, Config.VILLAGE_CLEAR_RADIUS, Config.VILLAGE_VOLCANO_DIST, Config.VILLAGE_SEA_DIST],
	[Config.VILLAGE_CENTER_RADIUS + 4.0, 5.0, 3.0, 14.0, 6.0],
	[Config.VILLAGE_CENTER_RADIUS + 12.0, 2.0, 1.0, 8.0, 3.0],
]


static func place(c: GenContext) -> void:
	var m := c.m
	# Chebyshev distance to the nearest water, mountain or lava tile.
	var obst := c.distance_to(func(t: Vector2i) -> bool: return not c.is_land(t), true)
	var sea_dist := c.distance_to(func(t: Vector2i) -> bool: return c.sea.has(t))
	for s in c.players:
		var centre: Vector2 = m.slices[s]["center"]
		var spot := Vector2i(-1, -1)
		for tier in TIERS:
			spot = _best(c, s, centre, tier, obst, sea_dist)
			if spot.x >= 0:
				break
		if spot.x < 0:
			spot = Vector2i(centre.round())
			c.fail("no good village spot in slice %d" % s)
		_stamp(c, spot, s)
	m.village_rect = m.villages[0]["rect"]


static func _best(c: GenContext, s: int, centre: Vector2, tier: Array, obst: PackedInt32Array, sea_dist: PackedInt32Array) -> Vector2i:
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
			if obst[k] <= 2 + int(tier[2]):
				continue  # (5x5 walls: 2 tiles from the centre, then the clearance)
			if not c.sea.is_empty() and sea_dist[k] < int(tier[4]):
				continue
			var far := true
			for v in m.volcanoes:
				far = far and Vector2(t).distance_to(Vector2(v)) >= float(tier[3])
			for other in m.villages:
				far = far and Vector2(t).distance_to(Vector2(other["center"])) >= 14.0
			if not far:
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


## Lays out the 5x5 walled village around `center` (Config.VILLAGE_LAYOUT)
## and clears the ring around it.
static func _stamp(c: GenContext, center: Vector2i, s: int) -> void:
	var m := c.m
	var id := m.villages.size()
	var o := center - Vector2i(2, 2)
	var rect := Rect2i(o, Vector2i(5, 5))
	var v := {"center": center, "rect": rect, "gates": [] as Array[Vector2i], "home_spawns": [] as Array[Vector2i], "farm_plot": Vector2i(-1, -1), "slice": s}
	m.villages.append(v)
	var ring := Config.FOREST_CLEARING_RING
	for dy in range(-ring, ring + 1):
		for dx in range(-ring, ring + 1):
			var t := center + Vector2i(dx, dy)
			var z := m.zone(t)
			GenZones.clear(c, t, "meadow" if z in ["steppe", "swamp", "ash"] else z)
	for row in 5:
		for col in 5:
			var t := o + Vector2i(col, row)
			var kind: String = {"T": "wall_tower", "W": "wall", "G": "gate", "V": "hut"}[Config.VILLAGE_LAYOUT[row][col]]
			# Walls on the left/right edges run along the grid's y axis: mirror them.
			var flip := col == 0 or col == 4
			m.village_layout.append({"kind": kind, "tile": t, "flip": flip, "owner": id})
			if kind == "gate":
				m.gates.append(t)
				(v["gates"] as Array[Vector2i]).append(t)
				m.set_terrain(t, MapData.Terrain.ROAD)
