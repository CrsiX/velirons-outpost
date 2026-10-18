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
## A map from a file (docs/map-editor-design.md): {"name", "author",
## "description", "origin": {"generator_seed", "edited", "game_version"}}.
## Empty for a generated map.
var meta: Dictionary = {}
## Villages of the map that nobody plays (for_game): {"center", "rect",
## "pieces": [{kind, tile, flip}]}. Built as ownerless ruins (§8.2).
var abandoned: Array[Dictionary] = []
## Deep-water tiles where water monsters come from (docs/aquatic-design.md §9).
var water_spawns: Array[Vector2i] = []


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


## Deep water (not a bridge over it): where water monsters dive.
func is_deep(t: Vector2i) -> bool:
	return in_bounds(t) and terrain[index(t)] == Terrain.WATER


## A bridge (a road tile over deep or shallow water; not a ford): water
## monsters pass under it, staying under water there.
func is_bridge(t: Vector2i) -> bool:
	return crossings.has(t) and int(crossings[t][1]) != Terrain.LAVA and str(crossings[t][0]).begins_with("bridge_")


## Deep water, or a bridge over deep water: what water-bound monsters swim
## through (under a bridge they stay under; is_deep is where they may come up).
func is_deep_water(t: Vector2i) -> bool:
	return is_deep(t) or (crossings.has(t) and int(crossings[t][1]) == Terrain.WATER and str(crossings[t][0]).begins_with("bridge_"))


## Water an amphibian swims through: deep or shallow water, or a bridge or
## ford over it.
func is_wet(t: Vector2i) -> bool:
	if not in_bounds(t):
		return false
	var v := terrain[index(t)]
	if v == Terrain.WATER or v == Terrain.SHALLOW:
		return true
	return crossings.has(t) and int(crossings[t][1]) != Terrain.LAVA


## Standing in water for a siren's sake: deep or shallow water or a ford (a
## bridge is land).
func in_water(t: Vector2i) -> bool:
	return is_water(t) or (crossings.has(t) and int(crossings[t][1]) == Terrain.SHALLOW)


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
		"water_spawns": water_spawns,
	}
	if not meta.is_empty():
		d["meta"] = meta
	if not abandoned.is_empty():
		d["abandoned"] = abandoned
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
	m.meta = d.get("meta", {})
	m.abandoned.assign(d.get("abandoned", []))
	m.water_spawns.assign(d.get("water_spawns", []))
	return m


## A deep copy (through the packed form).
func copy() -> MapData:
	return MapData.from_bytes(to_bytes())


## The pieces (walls, gates, wall towers, huts) of village `i`: [{kind, tile, flip}].
func village_pieces(i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in village_layout:
		if int(p.get("owner", 0)) == i:
			out.append({"kind": p["kind"], "tile": p["tile"], "flip": p["flip"]})
	return out


## Rebuilds what follows from the villages' pieces, centres and spawns (a map
## made or changed outside the generator): each village's rect (its pieces'
## bounding box), gates and slice, `gates`, `edge_spawns`, `village_rect`, and
## the slices' centres. Spawns and gates stay in row order, as the generator
## makes them.
func derive() -> void:
	gates.clear()
	var spawns: Array[Vector2i] = []
	for i in villages.size():
		var v := villages[i]
		var rect := Rect2i()
		var vg: Array[Vector2i] = []
		var first := true
		for p in village_pieces(i):
			var t: Vector2i = p["tile"]
			rect = Rect2i(t, Vector2i.ONE) if first else rect.merge(Rect2i(t, Vector2i.ONE))
			first = false
			if p["kind"] == "gate":
				vg.append(t)
		vg.sort_custom(MapData.row_order)
		v["rect"] = rect
		v["gates"] = vg
		v["slice"] = int(slice_of[index(v["center"])]) if in_bounds(v["center"]) else 0
		var hs: Array[Vector2i] = []
		hs.assign(v.get("home_spawns", []))
		hs.sort_custom(MapData.row_order)
		v["home_spawns"] = hs
		if not v.has("farm_plot"):
			v["farm_plot"] = Vector2i(-1, -1)
		gates.append_array(vg)
		spawns.append_array(hs)
	spawns.sort_custom(MapData.row_order)
	edge_spawns = spawns
	village_rect = villages[0]["rect"] if not villages.is_empty() else Rect2i()
	derive_slices()


## The slices' centres and tile counts from `slice_of` (as GenSlices makes them).
func derive_slices() -> void:
	var n := 1
	for i in slice_of.size():
		n = maxi(n, slice_of[i] + 1)
	n = maxi(n, villages.size())
	var sums: Array[Vector2] = []
	var counts: Array[int] = []
	for s in n:
		sums.append(Vector2.ZERO)
		counts.append(0)
	for idx in slice_of.size():
		var s := slice_of[idx]
		sums[s] += Vector2(idx % size, idx / size)
		counts[s] += 1
	var mid := Vector2(size - 1, size - 1) / 2.0
	slices.clear()
	for s in n:
		slices.append({"center": mid if n == 1 else sums[s] / maxf(counts[s], 1), "tiles": counts[s]})


## Tiles in row order (y, then x): the order of lists in map files.
static func row_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


## The map for a game in which villages `played` (indices into `villages`, in
## player order) are played: a copy whose village i is played[i], with the
## slices numbered to match (player i's slice is i, the others after them),
## and every other village moved to `abandoned` (built as ownerless ruins;
## their spawns send nothing). (docs/map-editor-design.md §8)
func for_game(played: Array) -> MapData:
	var m := copy()
	var order: Array[int] = []
	for k in played:
		order.append(int(k))
	# Slices: the played villages' first, in player order, then the rest.
	var slice_map := {}
	for k in order:
		var s := int(villages[k].get("slice", 0))
		if not slice_map.has(s):
			slice_map[s] = slice_map.size()
	var all_slices: Array = []
	for i in slice_of.size():
		if not all_slices.has(slice_of[i]):
			all_slices.append(slice_of[i])
	all_slices.sort()
	for s in all_slices:
		if not slice_map.has(s):
			slice_map[s] = slice_map.size()
	for i in m.slice_of.size():
		m.slice_of[i] = slice_map[int(slice_of[i])]
	for o in m.objects:
		o["slice"] = slice_map.get(int(o.get("slice", 0)), 0)
	var new_villages: Array[Dictionary] = []
	var new_layout: Array[Dictionary] = []
	for n in order.size():
		var v: Dictionary = m.villages[order[n]]
		new_villages.append(v)
		for p in village_pieces(order[n]):
			p["owner"] = n
			new_layout.append(p)
	m.abandoned.clear()
	for k in villages.size():
		if not order.has(k):
			var v: Dictionary = villages[k]
			m.abandoned.append({"center": v["center"], "rect": v["rect"], "pieces": village_pieces(k)})
	m.villages = new_villages
	m.village_layout = new_layout
	var links: Array[Vector2i] = []
	for l in village_links:
		if order.has(l.x) and order.has(l.y):
			links.append(Vector2i(order.find(l.x), order.find(l.y)))
	m.village_links = links
	m.derive()
	return m


## Every tile of `r`, row by row.
static func rect_tiles(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


static func neighbors4(t: Vector2i) -> Array[Vector2i]:
	return [t + Vector2i.RIGHT, t + Vector2i.LEFT, t + Vector2i.DOWN, t + Vector2i.UP]
