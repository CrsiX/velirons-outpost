class_name MapData
extends RefCounted
## Pure tile data: terrain, zones, fog, and which building occupies which tile.
## Terrain says what a tile does (walkable, buildable, road, water...); the
## zone (Config.ZONE_ORDER index) how it looks and what grows there.

enum Terrain { GRASS, ROAD, FOREST, DESERT, MOUNTAIN, WATER, SHALLOW, LAVA }

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
## Zone per tile (index into Config.ZONE_ORDER).
var zones: PackedByteArray
## Small walkable props (reeds, boulders, cacti): tile -> art. Cleared by buildings.
var decor: Dictionary = {}
## Road tiles over water or lava: tile -> [art ("bridge_<style>_x" / "_y" or
## "tile_ford"), the terrain under it (WATER, SHALLOW or LAVA)].
var crossings: Dictionary = {}
## Land tiles by the sea, drawn as sand.
var beaches: Dictionary = {}
## Centre tiles of volcanoes (each covers 3x3 mountain tiles).
var volcanoes: Array[Vector2i] = []
## Which player's slice each tile is in (docs/world-design.md §3.1).
var slice_of: PackedByteArray
## Per slice: {"center": Vector2 (its tiles' centre of mass)}.
var slices: Array[Dictionary] = []
## Special objects (treasures, camps, unlock sites, ruins, lairs, mines):
## [{kind, tile, size, slice, ...}], spawned by World.
var objects: Array[Dictionary] = []
var map_type := "temperate"
var seed_value := 0


func _init(p_size: int) -> void:
	size = p_size
	terrain.resize(size * size)
	terrain.fill(Terrain.GRASS)
	explored.resize(size * size)
	explored.fill(0)
	watched.resize(size * size)
	watched.fill(0)
	zones.resize(size * size)
	zones.fill(0)
	slice_of.resize(size * size)
	slice_of.fill(0)


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


func is_water(t: Vector2i) -> bool:
	return in_bounds(t) and (terrain[index(t)] == Terrain.WATER or terrain[index(t)] == Terrain.SHALLOW)


func is_deep(t: Vector2i) -> bool:
	return in_bounds(t) and terrain[index(t)] == Terrain.WATER


## Ground units (civilians, soldiers) can't enter forest, mountains, deep water or lava.
func is_passable(t: Vector2i) -> bool:
	if not in_bounds(t):
		return false
	var v := terrain[index(t)]
	return v != Terrain.FOREST and v != Terrain.MOUNTAIN and v != Terrain.WATER and v != Terrain.LAVA


func zone(t: Vector2i) -> String:
	return Config.ZONE_ORDER[zones[index(t)]] if in_bounds(t) else "meadow"


func set_zone(t: Vector2i, z: String) -> void:
	zones[index(t)] = Config.ZONE_ORDER.find(z)


## Walking speed factor on `t`: shallow water and fords x SHALLOW_WALK, swamp
## off the road x its "walk".
func walk_factor(t: Vector2i) -> float:
	if not in_bounds(t):
		return 1.0
	var v := terrain[index(t)]
	if v == Terrain.SHALLOW or (crossings.has(t) and int(crossings[t][1]) == Terrain.SHALLOW):
		return Config.SHALLOW_WALK
	if v != Terrain.ROAD:
		return float(Config.ZONES[zone(t)].get("walk", 1.0))
	return 1.0


## Within VOLCANO_NO_BUILD of a volcano's centre tile.
func near_crater(t: Vector2i) -> bool:
	for c in volcanoes:
		if Vector2(t).distance_to(Vector2(c)) <= Config.VOLCANO_NO_BUILD + 1.0:
			return true
	return false


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
		"zones": zones, "decor": decor, "crossings": crossings, "volcanoes": volcanoes, "beaches": beaches,
		"slice_of": slice_of, "slices": slices, "objects": objects, "map_type": map_type, "seed": seed_value,
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
	m.zones = d["zones"]
	m.decor = d["decor"]
	m.crossings = d["crossings"]
	m.beaches = d["beaches"]
	m.volcanoes.assign(d["volcanoes"])
	m.slice_of = d["slice_of"]
	m.slices.assign(d["slices"])
	m.objects.assign(d["objects"])
	m.map_type = d["map_type"]
	m.seed_value = d["seed"]
	return m


static func neighbors4(t: Vector2i) -> Array[Vector2i]:
	return [t + Vector2i.RIGHT, t + Vector2i.LEFT, t + Vector2i.DOWN, t + Vector2i.UP]
