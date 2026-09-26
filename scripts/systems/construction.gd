class_name Construction
extends Node
## Construction orders: validation, placing paid sites, and a FIFO job queue
## that builders claim from.

signal changed

const KIND_SCRIPTS := {
	"tower": preload("res://scripts/buildings/tower.gd"),
	"farm": preload("res://scripts/buildings/farm.gd"),
}

var game: Game
var queue: Array[Building] = []


func setup(p_game: Game) -> void:
	game = p_game


## "" if `kind` can be placed with its anchor on `tile`, else the reason.
func placement_error(kind: String, tile: Vector2i) -> String:
	var spec: Dictionary = Config.BUILDINGS[kind]
	var r: int = spec["size"] / 2
	var map := game.map
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := tile + Vector2i(dx, dy)
			if not map.in_bounds(t):
				return "Outside the map"
			if not map.is_explored(t):
				return "Unexplored land"
			if map.in_village(t):
				return "Must be outside the village walls"
			if map.building_at(t) != null:
				return "Something is already built here"
			match map.get_terrain(t):
				MapData.Terrain.ROAD:
					return "Can't build on the road"
				MapData.Terrain.FOREST:
					return "Trees are in the way"
				MapData.Terrain.MOUNTAIN:
					return "Mountains are in the way"
				MapData.Terrain.DESERT:
					if kind == "farm":
						return "Nothing grows in the desert"
	if not game.economy.can_afford(spec["cost"]):
		return "Not enough building material"
	return ""


func place(kind: String, tile: Vector2i) -> Building:
	if placement_error(kind, tile) != "":
		return null
	game.economy.spend(Config.BUILDINGS[kind]["cost"])
	var b: Building = KIND_SCRIPTS[kind].new()
	b.setup(game, kind, tile, false)
	game.world.add_building(b)
	queue.append(b)
	Sfx.play("place")
	changed.emit()
	return b


func order_rebuild(hut: Hut) -> bool:
	if not hut.ruined or not hut.complete or not game.economy.spend(Config.BUILDINGS["hut"]["cost"]):
		return false
	hut.start_rebuild()
	queue.append(hut)
	Sfx.play("place")
	changed.emit()
	return true


## Next unclaimed site in order, or null.
func claim(builder: Node) -> Building:
	for site in queue:
		if site.builder == null and not site.get_meta("unreachable_until", 0.0) > Time.get_ticks_msec() / 1000.0:
			site.builder = builder
			changed.emit()
			return site
	return null


func release(site: Building, unreachable: bool) -> void:
	site.builder = null
	if unreachable:
		site.set_meta("unreachable_until", Time.get_ticks_msec() / 1000.0 + 5.0)
	changed.emit()


func complete(site: Building) -> void:
	queue.erase(site)
	site.builder = null
	site.finish()
	game.world.refresh_building(site)
	Sfx.play("build")
	changed.emit()


func cancel(site: Building) -> void:
	if site.complete:
		return
	queue.erase(site)
	var cost: Dictionary = Config.BUILDINGS[site.kind]["cost"]
	game.economy.refund(cost)
	if site is Hut:
		(site as Hut).cancel_rebuild()
	else:
		game.world.remove_building(site)
	game.deselect()
	changed.emit()


func pending_count() -> int:
	return queue.size()
