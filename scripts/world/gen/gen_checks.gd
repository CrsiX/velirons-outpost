class_name GenChecks
extends RefCounted
## Stage 11 (docs/world-design.md §5.3, §14): a map that fails these is made
## again from the next seed (Config.MAP_TRIES).


static func run(c: GenContext) -> void:
	var m := c.m
	for vi in m.villages.size():
		var v := m.villages[vi]
		var spawns: Array = v["home_spawns"]
		if spawns.is_empty():
			c.fail("village %d has no spawn" % vi)
			continue
		var field := road_field(m, v["gates"])
		for s in spawns:
			if field[m.index(s)] >= 1 << 29:
				c.fail("spawn %s can't reach village %d by road" % [str(s), vi])
		if GenRoads.approaches(m, v) < 2:
			c.fail("village %d has fewer than 2 approaches" % vi)
		if v["farm_plot"] == Vector2i(-1, -1):
			c.fail("village %d has no farm plot" % vi)
	if c.players > 1:
		var shares := zone_shares(m)
		for z in Config.ZONE_ORDER:
			var lo := INF
			var hi := -INF
			for s in c.players:
				lo = minf(lo, shares[s].get(z, 0.0))
				hi = maxf(hi, shares[s].get(z, 0.0))
			if hi - lo > Config.ZONE_FAIR_SPREAD:
				c.warn("%s shares differ by %d points between slices" % [z, roundi((hi - lo) * 100)])


## Road steps from every road tile to the nearest of `gates`.
static func road_field(m: MapData, gates: Array) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(m.size * m.size)
	dist.fill(1 << 30)
	var queue: Array[Vector2i] = []
	for g in gates:
		dist[m.index(g)] = 0
		queue.append(g)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for n in MapData.neighbors4(t):
			if m.is_road(n) and dist[m.index(n)] > dist[m.index(t)] + 1:
				dist[m.index(n)] = dist[m.index(t)] + 1
				queue.append(n)
	return dist


## Per slice: {zone: share of that slice's land tiles}.
static func zone_shares(m: MapData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var totals: Array[int] = []
	for s in m.slices.size():
		out.append({})
		totals.append(0)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			var v := m.get_terrain(t)
			if v == MapData.Terrain.WATER or v == MapData.Terrain.SHALLOW or v == MapData.Terrain.LAVA or v == MapData.Terrain.MOUNTAIN:
				continue
			var s := m.slice_of[m.index(t)]
			var z := m.zone(t)
			out[s][z] = out[s].get(z, 0.0) + 1.0
			totals[s] += 1
	for s in out.size():
		for z in out[s]:
			out[s][z] /= maxf(totals[s], 1)
	return out
