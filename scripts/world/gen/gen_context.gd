class_name GenContext
extends RefCounted
## Everything the map generator's stages share while one map is being made
## (docs/world-design.md §3): the map, the seeded random numbers, the noise
## fields and bookkeeping between stages. Only `rng` and noise seeded from
## `seed_value` are used, so a seed always gives the same map.

var m: MapData
var rng := RandomNumberGenerator.new()
var seed_value := 0
var players := 1
var type_key := "temperate"
var type: Dictionary = {}
## 0..1 fields (height and moisture are rank-normalised, then shifted by the
## map type), and a -1..1 detail noise for ragged borders.
var height := PackedFloat32Array()
var moisture := PackedFloat32Array()
var detail := PackedFloat32Array()
## River tiles (water or lava) that roads may cross on a bridge.
var rivers: Dictionary = {}
## Sea tiles (coast maps).
var sea: Dictionary = {}
## Land tiles next to the sea (drawn as sand).
var beaches: Dictionary = {}
## Tiles painted as ash land around volcanoes.
var ash: Dictionary = {}
## Per tile: steps to the nearest tile of another slice (large with one slice).
var border_dist := PackedInt32Array()
## Why the map failed its checks (empty: fine).
var failures: Array[String] = []
## Softer shortfalls (slice fairness): retried less, the best try is kept.
var soft: Array[String] = []


func _init(p_seed: int, p_players: int, p_type: String) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	players = clampi(p_players, 1, Config.MAX_PLAYERS)
	type_key = p_type if Config.MAP_TYPES.has(p_type) else "temperate"
	type = Config.MAP_TYPES[type_key]
	m = MapData.new(Config.map_size(players))
	m.map_type = type_key


func i(t: Vector2i) -> int:
	return m.index(t)


func h(t: Vector2i) -> float:
	return height[m.index(t)]


func is_land(t: Vector2i) -> bool:
	if not m.in_bounds(t):
		return false
	var v := m.get_terrain(t)
	return v != MapData.Terrain.WATER and v != MapData.Terrain.SHALLOW and v != MapData.Terrain.LAVA and v != MapData.Terrain.MOUNTAIN


## Weighted pick from {name: weight}.
func pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0] if not weights.is_empty() else ""


## Integer in [range.x, range.y] times `scale`, rounded (at least 0).
func count_in(range_v: Vector2i, scale: float = 1.0) -> int:
	return maxi(0, roundi(rng.randf_range(range_v.x, range_v.y + 0.999) * scale - 0.499))


## Breadth-first steps (4 directions) from every tile to the nearest tile for
## which `is_source` is true, over the whole map. Returns large values where none.
func distance_to(is_source: Callable, diagonal: bool = false) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(m.size * m.size)
	dist.fill(1 << 20)
	var queue: Array[Vector2i] = []
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			if is_source.call(t):
				dist[m.index(t)] = 0
				queue.append(t)
	var head := 0
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	if diagonal:
		steps.append_array([Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])
	while head < queue.size():
		var t := queue[head]
		head += 1
		var d := dist[m.index(t)] + 1
		for s in steps:
			var n := t + s
			if m.in_bounds(n) and dist[m.index(n)] > d:
				dist[m.index(n)] = d
				queue.append(n)
	return dist


func fail(why: String) -> void:
	failures.append(why)


func warn(why: String) -> void:
	soft.append(why)
