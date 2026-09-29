class_name Construction
extends Node
## Construction orders: validation, placing paid sites, and a FIFO job queue
## that builders claim from.

signal changed

const KIND_SCRIPTS := {
	"tower": preload("res://scripts/buildings/tower.gd"),
	"farm": preload("res://scripts/buildings/farm.gd"),
	"camp": preload("res://scripts/buildings/worker_camp.gd"),
	"lightstone": preload("res://scripts/buildings/light_stone.gd"),
	"training": preload("res://scripts/buildings/training_grounds.gd"),
	"barracks": preload("res://scripts/buildings/barracks.gd"),
}

var game: Game
## The village whose construction queue this is.
var village: Village
var queue: Array[Building] = []


func setup(p_village: Village) -> void:
	village = p_village
	game = village.game


## "" if `kind` can be placed with its anchor on `tile`, else the reason.
## `free`: a starting building, so no cost and no need for explored land.
func placement_error(kind: String, tile: Vector2i, free: bool = false) -> String:
	var spec: Dictionary = Config.BUILDINGS[kind]
	var map := game.map
	for t in Building.footprint(tile, spec["size"]):
		if not map.in_bounds(t):
			return "Outside the map"
		if not free and not game.fog.is_explored_by(village.id, t):
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
	if not free and not village.economy.can_afford(spec["cost"]):
		return "Not enough building material" if spec["cost"].keys() == ["materials"] else "Not enough resources"
	return ""


func place(kind: String, tile: Vector2i) -> Building:
	if placement_error(kind, tile) != "":
		return null
	village.economy.spend(Config.BUILDINGS[kind]["cost"])
	var b: Building = KIND_SCRIPTS[kind].new()
	b.village = village
	b.setup(game, kind, tile, false)
	game.world.add_building(b)
	queue.append(b)
	village.events.debug("place %s at %s for %s" % [b.label(), str(tile), Config.cost_text(Config.BUILDINGS[kind]["cost"])])
	Sfx.play("place")
	changed.emit()
	return b


func order_rebuild(hut: Hut) -> bool:
	if not hut.ruined or not hut.complete or not village.economy.spend(Config.BUILDINGS["hut"]["cost"]):
		return false
	hut.start_rebuild()
	queue.append(hut)
	village.events.debug("order rebuilding %s" % hut.label())
	Sfx.play("place")
	changed.emit()
	return true


## Next unclaimed site in order, or null.
func claim(builder: Node) -> Building:
	for site in queue:
		if site.builder == null and not site.get_meta("unreachable_until", 0.0) > Time.get_ticks_msec() / 1000.0:
			site.builder = builder
			village.events.debug("%s starts work on %s" % [builder.label(), site.label()])
			changed.emit()
			return site
	return null


func release(site: Building, unreachable: bool) -> void:
	site.builder = null
	if unreachable:
		site.set_meta("unreachable_until", Time.get_ticks_msec() / 1000.0 + 5.0)
	changed.emit()


## Queues a paid tower upgrade as a builder job; the tower keeps fighting.
## A tower or barracks: its next level, for building material and a builder's time.
func order_upgrade(tower: Building) -> bool:
	if not tower.can_upgrade() or not village.economy.spend(tower.upgrade_cost()):
		return false
	village.events.debug("order upgrade of %s to level %d for %s" % [tower.label(), tower.level + 1, Config.cost_text(tower.upgrade_cost())])
	tower.start_upgrade()
	queue.append(tower)
	Sfx.play("place")
	changed.emit()
	return true


func complete(site: Building) -> void:
	queue.erase(site)
	site.builder = null
	if site.complete and site.upgrading:
		site.finish_upgrade()
		village.events.info("%s upgraded to level %d" % [site.label(), site.level])
		Sfx.play("build")
		changed.emit()
		return
	site.finish()
	game.world.refresh_building(site)
	village.events.info("%s %s" % [site.label(), "rebuilt" if site is Hut else "finished"])
	if site is Workplace:
		village.population.assign_worker(site, true)  # an idle farmer / forester takes it
	Sfx.play("build")
	changed.emit()


# --- starting buildings -----------------------------------------------------------------

## The free, finished buildings the level starts with (Config.START_BUILDINGS):
## the farm on the map's guaranteed farm plot, a worker camp close to the
## village by the forest. Run before the villagers move in, who then take them.
func build_starting() -> void:
	for kind in Config.START_BUILDINGS:
		var spot := _start_spot(kind)
		if spot == Vector2i(-1, -1):
			push_warning("No room for the starting %s" % kind)
			continue
		var b: Building = KIND_SCRIPTS[kind].new()
		b.village = village
		b.setup(game, kind, spot, true)
		game.world.add_building(b)
		village.events.debug("%s stands ready at %s (free at the start)" % [b.label(), str(spot)])
		game.fog.reveal(Vector2(spot), 2.5)


func _start_spot(kind: String) -> Vector2i:
	if kind == "farm" and village.farm_plot != Vector2i(-1, -1) and placement_error(kind, village.farm_plot, true) == "":
		return village.farm_plot
	# Anywhere near the village, not crowding a gate; a camp wants trees close by.
	var centre := village.center
	var candidates: Array = []
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var t := centre + Vector2i(dx, dy)
			if placement_error(kind, t, true) != "" or _next_to_gate(t):
				continue
			var score := Vector2(t).distance_to(Vector2(centre))
			if kind == "camp":
				var trees := _trees_near(t, 5)
				if trees < 6:
					continue
				score -= minf(trees, 20) * 0.25
			candidates.append([score, t])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in candidates:  # (farms and camps don't block walking; just be reachable)
		if not game.world.pathing.find_path(centre, c[1]).is_empty():
			return c[1]
	return Vector2i(-1, -1)


func _next_to_gate(t: Vector2i) -> bool:
	for g in game.map.gates:
		if maxi(absi(g.x - t.x), absi(g.y - t.y)) <= 2:
			return true
	return false


func _trees_near(t: Vector2i, r: int) -> int:
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if game.world.is_tree(t + Vector2i(dx, dy)):
				n += 1
	return n


func cancel(site: Building) -> void:
	village.events.debug("cancel %s of %s (refunded)" % ["upgrade" if site.complete and site.upgrading else "construction", site.label()])
	if site.complete and site.upgrading:
		queue.erase(site)
		village.economy.refund(site.pending_upgrade_cost())
		site.builder = null
		site.cancel_upgrade()
		changed.emit()
		return
	if site.complete:
		return
	queue.erase(site)
	var cost: Dictionary = Config.BUILDINGS[site.kind]["cost"]
	village.economy.refund(cost)
	if site is Hut:
		(site as Hut).cancel_rebuild()
	else:
		game.world.remove_building(site)
	if village.is_local():
		game.deselect()
	changed.emit()


func pending_count() -> int:
	return queue.size()
