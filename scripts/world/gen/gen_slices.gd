class_name GenSlices
extends RefCounted
## Stage 1 (docs/world-design.md §3.1): one equal-area slice per player around
## the map centre, with a random rotation. Tiles are sorted by their angle
## around the centre and split into N runs of equal length, so every slice
## holds the same number of tiles (± 1), reaches the map edge and touches the
## middle.


static func cut(c: GenContext) -> void:
	var m := c.m
	var n := c.players
	var mid := Vector2(m.size - 1, m.size - 1) / 2.0
	var rot := c.rng.randf() * TAU
	var angles := PackedFloat32Array()
	angles.resize(m.size * m.size)
	for y in m.size:
		for x in m.size:
			# (a tiny per-tile offset breaks ties between tiles on the same ray)
			angles[y * m.size + x] = fposmod((Vector2(x, y) - mid).angle() - rot, TAU) + float((y * m.size + x) * 7919 % 997) * 2e-6
	# Cut angles at the 1/N quantiles, so every slice holds the same number of tiles.
	var sorted := angles.duplicate()
	sorted.sort()
	var cuts := PackedFloat32Array()
	for s in range(1, n):
		cuts.append(sorted[int(float(s) * sorted.size() / n)])
	var sums: Array[Vector2] = []
	var counts: Array[int] = []
	for s in n:
		sums.append(Vector2.ZERO)
		counts.append(0)
	for idx in angles.size():
		var s := cuts.bsearch(angles[idx], false)
		m.slice_of[idx] = s
		sums[s] += Vector2(idx % m.size, idx / m.size)
		counts[s] += 1
	m.slices.clear()
	for s in n:
		var centre := mid if n == 1 else sums[s] / maxf(counts[s], 1)
		m.slices.append({"center": centre, "tiles": counts[s]})
	# Steps from every tile to the nearest tile of another slice.
	if n == 1:
		c.border_dist.resize(m.size * m.size)
		c.border_dist.fill(1 << 20)
	else:
		c.border_dist = c.distance_to(func(t: Vector2i) -> bool: return _on_border(m, t))


static func _on_border(m: MapData, t: Vector2i) -> bool:
	var s := m.slice_of[m.index(t)]
	for nb in MapData.neighbors4(t):
		if m.in_bounds(nb) and m.slice_of[m.index(nb)] != s:
			return true
	return false
