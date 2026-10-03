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
			MapData.Terrain.WATER, MapData.Terrain.SHALLOW:
				return "Water is in the way"
			MapData.Terrain.LAVA:
				return "Lava is in the way"
		if kind == "farm" and Config.ZONES[map.zone(t)].get("no_farms", false):
			return "Nothing grows in the %s" % Config.ZONES[map.zone(t)]["name"].to_lower()
		if map.near_crater(t):
			return "Too close to the volcano"
	if SOLID_KINDS.has(kind) and not _reachable_side(Building.footprint(tile, spec["size"])):
		return "Nobody could get to it: keep a way free next to it"
	if not free and not village.economy.can_afford(spec["cost"]):
		return "Not enough building material" if spec["cost"].keys() == ["materials"] else "Not enough resources"
	return ""


## Kinds that block their tiles once built (Building.is_solid_when_complete):
## a builder and units need a free, reachable tile next to them.
const SOLID_KINDS := ["tower", "lightstone"]


func _reachable_side(footprint: Array[Vector2i]) -> bool:
	var pathing := game.world.pathing
	for t in footprint:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := t + Vector2i(dx, dy)
				if not footprint.has(n) and pathing.is_walkable(n) and pathing.can_reach(village.center, n):
					return true
	return false


## A claimed ruined watchtower becomes a watchtower site at `cost` (half
## price); a builder builds it like any site.
func restore_ruin(ruin: RuinedTower, cost: Dictionary) -> Building:
	if not village.economy.spend(cost, "buildings"):
		return null
	var tile := ruin.tile
	game.world.remove_map_object(ruin)
	var b := _new_building("tower", tile, false)
	queue.append(b)
	village.events.info("A builder will restore the ruined watchtower (%s)" % Config.cost_text(cost))
	Sfx.play("place")
	changed.emit()
	return b


## A new building of ours on the map: a site, or already `complete`.
func _new_building(kind: String, tile: Vector2i, complete: bool) -> Building:
	var b: Building = KIND_SCRIPTS[kind].new()
	b.village = village
	b.setup(game, kind, tile, complete)
	game.world.add_building(b)
	return b


func place(kind: String, tile: Vector2i) -> Building:
	if placement_error(kind, tile) != "":
		return null
	village.economy.spend(Config.BUILDINGS[kind]["cost"], "buildings")
	var b := _new_building(kind, tile, false)
	queue.append(b)
	village.events.debug("place %s at %s for %s" % [b.label(), str(tile), Config.cost_text(Config.BUILDINGS[kind]["cost"])])
	Sfx.play("place")
	changed.emit()
	return b


func order_rebuild(hut: Hut) -> bool:
	if not hut.ruined or not hut.complete or not village.economy.spend(Config.BUILDINGS["hut"]["cost"], "buildings"):
		return false
	hut.start_rebuild()
	queue.append(hut)
	village.events.debug("order rebuilding %s" % hut.label())
	Sfx.play("place")
	changed.emit()
	return true


## Destroyed huts of this village not ordered for rebuilding yet, nearest to
## the centre first.
func ruined_huts() -> Array[Hut]:
	var out: Array[Hut] = []
	for b in village.huts():
		var h := b as Hut
		if h and h.ruined and h.complete:
			out.append(h)
	var c := Vector2(village.center)
	out.sort_custom(func(a: Hut, b: Hut) -> bool: return Vector2(a.tile).distance_to(c) < Vector2(b.tile).distance_to(c))
	return out


## Orders every destroyed hut rebuilt, as many as the building material pays
## for. Returns how many were queued.
func rebuild_all_huts() -> int:
	var n := 0
	for h in ruined_huts():
		if not order_rebuild(h):
			break
		n += 1
	return n


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


## A tower or barracks: its next level, for building material and a builder's time.
func order_upgrade(tower: Building) -> bool:
	if not tower.can_upgrade() or not village.economy.spend(tower.upgrade_cost(), "upgrades"):
		return false
	village.events.debug("order upgrade of %s to level %d for %s" % [tower.label(), tower.level + 1, Config.cost_text(tower.upgrade_cost())])
	tower.start_upgrade()
	queue.append(tower)
	Sfx.play("place")
	changed.emit()
	return true


## Marks a finished building for tear-down: it stops working at once (its
## units walk home, its worker is freed, a pending upgrade is refunded) and a
## builder comes to take it apart. Stoppable until then (stop_tear_down).
func order_tear_down(b: Building) -> bool:
	if not b.can_tear_down():
		return false
	if b.upgrading:
		cancel(b)
	village.events.debug("order tear-down of %s" % b.label())
	b.set_tearing_down(true)
	village.army.eject(b)
	if b is Workplace:
		village.population.free_workplace(b)
	if b is Farm:
		(b as Farm).rats.clear()
	queue.append(b)
	Sfx.play("place")
	changed.emit()
	return true


## Spares a building marked for tear-down: it works again as before. (Units
## that were sent away stay in the reserve; a free worker takes it up.)
func stop_tear_down(b: Building) -> void:
	if not b.tearing_down:
		return
	village.events.debug("stop tearing down %s" % b.label())
	queue.erase(b)
	b.builder = null
	b.set_tearing_down(false)
	if b is Workplace:
		village.population.assign_worker(b, true)
	changed.emit()


func _torn_down(b: Building) -> void:
	var back := b.teardown_refund()
	village.economy.add("materials", back, "teardown")
	game.stats.count(village, "torn_down")
	village.events.info("%s torn down: +%d materials" % [b.label().capitalize(), back])
	if village.is_local() and game.selected == b:
		game.deselect()
	game.world.remove_building(b)
	Sfx.play("build")
	changed.emit()


func complete(site: Building) -> void:
	queue.erase(site)
	site.builder = null
	if site.complete and site.tearing_down:
		_torn_down(site)
		return
	if site.complete and site.upgrading:
		site.finish_upgrade()
		village.events.info("%s upgraded to level %d" % [site.label(), site.level])
		Sfx.play("build")
		changed.emit()
		return
	site.finish()
	game.stats.count(village, "huts_rebuilt" if site is Hut else "built")
	game.world.refresh_building(site)
	village.events.info("%s %s" % [site.label(), "rebuilt" if site is Hut else "finished"])
	if site is Workplace:
		village.population.assign_worker(site, true)  # an idle farmer / forester takes it
	Sfx.play("build")
	changed.emit()


# --- starting buildings -----------------------------------------------------------------

## The free, finished buildings the level starts with (Game.start_buildings,
## normally Config.START_BUILDINGS):
## the farm on the map's guaranteed farm plot, a worker camp close to the
## village by the forest. Run before the villagers move in, who then take them.
func build_starting() -> void:
	for kind in game.start_buildings:
		var spot := _start_spot(kind)
		if spot == Vector2i(-1, -1):
			push_warning("No room for the starting %s" % kind)
			continue
		var b := _new_building(kind, spot, true)
		village.events.debug("%s stands ready at %s (free at the start)" % [b.label(), str(spot)])
		game.fog.reveal(Vector2(spot), 2.5, village.id)


func _start_spot(kind: String) -> Vector2i:
	if kind == "farm" and village.farm_plot != Vector2i(-1, -1) and placement_error(kind, village.farm_plot, true) == "":
		return village.farm_plot
	var fixed: Vector2i = Config.TUTORIAL["camp_tile"]
	if kind == "camp" and game.tutorial_mode and fixed != Vector2i(-1, -1) and placement_error(kind, fixed, true) == "":
		return fixed
	# Anywhere near the village, not crowding a gate; a camp wants trees close by.
	var centre := village.center
	var candidates: Array = []
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var t := centre + Vector2i(dx, dy)
			if placement_error(kind, t, true) != "" or _next_to_gate(t) or _hidden(t):
				continue
			var score := Vector2(t).distance_to(Vector2(centre))
			if kind == "camp":
				var trees := _trees_near(t, 5)
				if trees < 6:
					continue
				score -= minf(trees, 20) * 0.25 + _trees_near(t, 2) * 0.3  # (by the forest's edge)
			candidates.append([score, t])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in candidates:  # (farms and camps don't block walking; just be reachable)
		if not game.world.pathing.find_path(centre, c[1]).is_empty():
			return c[1]
	return Vector2i(-1, -1)


## On screen right behind the village's walls (one row), its corner towers
## (two rows) or a tree, so they would hide it.
func _hidden(t: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if game.world.is_tree(t + d):
			return true
	var r := village.rect
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var corner := (x == r.position.x or x == r.end.x - 1) and (y == r.position.y or y == r.end.y - 1)
			var ahead := (x + y) - (t.x + t.y)  # (half-tile rows in front of it)
			if absi((x - y) - (t.x - t.y)) <= 1 and ahead > 0 and ahead <= (4 if corner else 2):
				return true
	return false


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
	if site.tearing_down:
		stop_tear_down(site)
		return
	village.events.debug("cancel %s of %s (refunded)" % ["upgrade" if site.complete and site.upgrading else "construction", site.label()])
	if site.complete and site.upgrading:
		queue.erase(site)
		village.economy.refund(site.pending_upgrade_cost(), "upgrades")
		site.builder = null
		site.cancel_upgrade()
		changed.emit()
		return
	if site.complete:
		return
	queue.erase(site)
	var cost: Dictionary = Config.BUILDINGS[site.kind]["cost"]
	village.economy.refund(cost, "buildings")
	if site is Hut:
		(site as Hut).cancel_rebuild()
	else:
		game.world.remove_building(site)
	if village.is_local():
		game.deselect()
	changed.emit()

