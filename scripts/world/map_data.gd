class_name MapData
extends RefCounted
## Pure tile data: terrain, fog, and which building occupies which tile.

enum Terrain { GRASS, ROAD, FOREST, DESERT, MOUNTAIN }

var size: int
var terrain: PackedByteArray
## Fog: 1 = explored (terrain known). "watched" = currently under surveillance.
var explored: PackedByteArray
var watched: PackedByteArray
## Vector2i -> Building (multi-tile buildings are registered on every tile).
var buildings: Dictionary = {}
## The first village's walls (single player: the only one; see `villages`).
var village_rect: Rect2i
## Gates of every village.
var gates: Array[Vector2i] = []
## One entry per village: {"center": Vector2i, "rect": Rect2i, "gates":
## Array[Vector2i], "home_spawns": Array[Vector2i] (edge road tiles its own wave
## comes from), "farm_plot": Vector2i}.
var villages: Array[Dictionary] = []
## Pairs of village ids joined by a road (co-op maps).
var village_links: Array[Vector2i] = []
var edge_spawns: Array[Vector2i] = []
## Planned village pieces: [{kind, tile, flip}] consumed by World when spawning.
var village_layout: Array[Dictionary] = []  # (+ "owner": village id)
## Tall terrain props (trees on forest, peaks on mountains): tile -> art name.
var props: Dictionary = {}
## Centre of the guaranteed free 3x3 farm plot near the village.
var farm_plot := Vector2i(-1, -1)


func _init(p_size: int) -> void:
	size = p_size
	terrain.resize(size * size)
	terrain.fill(Terrain.GRASS)
	explored.resize(size * size)
	explored.fill(0)
	watched.resize(size * size)
	watched.fill(0)


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size and t.y < size


func index(t: Vector2i) -> int:
	return t.y * size + t.x


func get_terrain(t: Vector2i) -> int:
	return terrain[index(t)]


func set_terrain(t: Vector2i, v: int) -> void:
	terrain[index(t)] = v


func is_road(t: Vector2i) -> bool:
	return in_bounds(t) and terrain[index(t)] == Terrain.ROAD


func is_forest(t: Vector2i) -> bool:
	return in_bounds(t) and terrain[index(t)] == Terrain.FOREST


func is_desert(t: Vector2i) -> bool:
	return in_bounds(t) and terrain[index(t)] == Terrain.DESERT


func is_mountain(t: Vector2i) -> bool:
	return in_bounds(t) and terrain[index(t)] == Terrain.MOUNTAIN


## Ground units (civilians, soldiers) can't enter forest or mountains.
func is_passable(t: Vector2i) -> bool:
	if not in_bounds(t):
		return false
	var v := terrain[index(t)]
	return v != Terrain.FOREST and v != Terrain.MOUNTAIN


func count_terrain(v: int) -> int:
	return terrain.count(v)


func is_explored(t: Vector2i) -> bool:
	return in_bounds(t) and explored[index(t)] == 1


func is_watched(t: Vector2i) -> bool:
	return in_bounds(t) and watched[index(t)] == 1


func is_edge(t: Vector2i) -> bool:
	return t.x == 0 or t.y == 0 or t.x == size - 1 or t.y == size - 1


## Inside the walls of any village.
func in_village(t: Vector2i) -> bool:
	for v in villages:
		if (v["rect"] as Rect2i).has_point(t):
			return true
	return village_rect.has_point(t)


## Id of the village whose walls contain `t`, or -1.
func village_at(t: Vector2i) -> int:
	for i in villages.size():
		if (villages[i]["rect"] as Rect2i).has_point(t):
			return i
	return -1


## Id of the village whose centre is nearest to `t`.
func nearest_village(t: Vector2i) -> int:
	var best := 0
	var best_d := INF
	for i in villages.size():
		var d := Vector2(t).distance_squared_to(Vector2(villages[i]["center"]))
		if d < best_d:
			best_d = d
			best = i
	return best


func building_at(t: Vector2i) -> Node:
	return buildings.get(t)


## The whole map as bytes (the co-op host sends it to everyone; §5.6).
func to_bytes() -> PackedByteArray:
	var d := {
		"size": size, "terrain": terrain, "props": props, "village_rect": village_rect,
		"gates": gates, "edge_spawns": edge_spawns, "villages": villages,
		"village_links": village_links, "village_layout": village_layout, "farm_plot": farm_plot,
	}
	var raw := var_to_bytes(d)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(packed)
	return out


static func from_bytes(bytes: PackedByteArray) -> MapData:
	var raw := bytes.slice(4).decompress(bytes.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	var d: Dictionary = bytes_to_var(raw)
	var m := MapData.new(int(d["size"]))
	m.terrain = d["terrain"]
	m.props = d["props"]
	m.village_rect = d["village_rect"]
	m.gates.assign(d["gates"])
	m.edge_spawns.assign(d["edge_spawns"])
	m.villages.assign(d["villages"])
	m.village_links.assign(d["village_links"])
	m.village_layout.assign(d["village_layout"])
	m.farm_plot = d["farm_plot"]
	return m


static func neighbors4(t: Vector2i) -> Array[Vector2i]:
	return [t + Vector2i.RIGHT, t + Vector2i.LEFT, t + Vector2i.DOWN, t + Vector2i.UP]
