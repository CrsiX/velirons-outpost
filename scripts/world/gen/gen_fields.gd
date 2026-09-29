class_name GenFields
extends RefCounted
## Stage 2: height and moisture fields from low-frequency noise, made uniform
## over the map (each value replaced by its rank, 0..1) so zone shares are
## predictable on every seed, then shifted by the map type. Plus a -1..1
## detail noise for ragged zone borders.


static func make(c: GenContext) -> void:
	var m := c.m
	var area := m.size * m.size
	var hn := _noise(c.seed_value * 7 + 11, 1.0 / (Config.ZONE_SIZE * 2.2), 3)
	var mn := _noise(c.seed_value * 13 + 23, 1.0 / (Config.ZONE_SIZE * 1.7), 3)
	var dn := _noise(c.seed_value * 17 + 5, 0.16, 2)
	var hraw := PackedFloat32Array()
	var mraw := PackedFloat32Array()
	hraw.resize(area)
	mraw.resize(area)
	c.detail.resize(area)
	for y in m.size:
		for x in m.size:
			var k := y * m.size + x
			hraw[k] = hn.get_noise_2d(x, y)
			mraw[k] = mn.get_noise_2d(x, y)
			c.detail[k] = dn.get_noise_2d(x, y)
	c.height = _ranked(hraw, float(c.type.get("height", 0.0)))
	c.moisture = _ranked(mraw, float(c.type.get("moisture", 0.0)))


static func _noise(p_seed: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = p_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Each value's rank among all values (0..1), plus `shift`.
static func _ranked(raw: PackedFloat32Array, shift: float) -> PackedFloat32Array:
	var sorted := raw.duplicate()
	sorted.sort()
	var out := PackedFloat32Array()
	out.resize(raw.size())
	var last := float(maxi(raw.size() - 1, 1))
	for k in raw.size():
		out[k] = float(sorted.bsearch(raw[k])) / last + shift
	return out
