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
var village_rect: Rect2i
var gates: Array[Vector2i] = []
var edge_spawns: Array[Vector2i] = []
## Planned village pieces: [{kind, tile, flip}] consumed by World when spawning.
var village_layout: Array[Dictionary] = []
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


func in_village(t: Vector2i) -> bool:
	return village_rect.has_point(t)


func building_at(t: Vector2i) -> Node:
	return buildings.get(t)


static func neighbors4(t: Vector2i) -> Array[Vector2i]:
	return [t + Vector2i.RIGHT, t + Vector2i.LEFT, t + Vector2i.DOWN, t + Vector2i.UP]
