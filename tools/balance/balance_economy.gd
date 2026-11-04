class_name BalanceEconomy
extends BalancePart
## The economy part of the balancing bot's player: the same for every policy
## (Config.BALANCE_ECONOMY). It keeps the village alive and building:
##
##  1. repairs of gates, walls and wall towers,
##  2. a working farm (one that stands, and a farmer on it),
##  3. ruined huts rebuilt,
##  4. every other repair, claimed ruins restored,
##  5. villagers recruited (a farm without its farmer first) and put to work,
##  6. farms and worker camps built, gold traded for material for what can't wait.
##
## Whatever waits for material holds back every other use of it
## (BalancePlayer.repair_wanted), and only these buy material with gold.

const PIECES: Array[String] = ["gate", "wall", "wall_tower"]

var _eco: Dictionary = Config.BALANCE_ECONOMY
## Game clock since when no farm stood (-1: one stands).
var _farmless_since := -1.0
## (game clock, building material the foresters brought so far), sampled
## for the material rate (BALANCE_BOT "material_window").
var _material_log: Array[Vector2] = []


# --- the round --------------------------------------------------------------------------

## The first part of a round, before the hero: what keeps the village standing.
func first() -> void:
	p.repair_wanted = false
	p.no_farm = _farm_wanted()
	_log_materials()
	_cancel_stuck_sites()
	_repair_pieces()
	if not p.repair_wanted:  # (the walls come first: a farm waits behind a wall that waits for material)
		_ensure_farm()
	_rebuild_huts()
	_repair_rest()
	_restore_ruins()
	_staff_workplaces()
	p.farm_unmanned = _farm_unmanned()


## The second part: villagers and economy buildings.
func second() -> void:
	_villagers()
	_economy_buildings()


# --- sites nobody builds ------------------------------------------------------------------

## A site no builder has touched for BALANCE_BOT "stuck_site_after" s (it can't
## be reached, say) is cancelled, its tile is not tried again, and the building
## is placed again somewhere else: it would hold the queue and, for a farm or a
## camp, the military's builds for good.
func _cancel_stuck_sites() -> void:
	for b in village.buildings():
		if b.complete or b is Hut or not b.has_work() or b.progress > 0.0 or b.repairing or b.upgrading:
			continue
		if game.clock - b.queued_at > float(_params["stuck_site_after"]):
			p.bad_spots[b.tile] = true
			_cmd("cancel_site", {"building": b.nid})


# --- repairs ------------------------------------------------------------------------------

## Gates, walls and wall towers that are devastated or below "repair_below" of
## their HP, the most broken first. One that waits for material holds back
## every other use of it, and gold buys the material.
func _repair_pieces() -> void:
	_repair(func(b: Building) -> bool: return PIECES.has(b.kind))


## Every other building (the farm excepted: _ensure_farm repairs a broken one).
func _repair_rest() -> void:
	_repair(func(b: Building) -> bool: return not PIECES.has(b.kind))


func _repair(wanted: Callable) -> void:
	var hurt: Array[Building] = []
	for b in village.buildings():
		if b is Hut or b is Warehouse or not b.can_repair() or not wanted.call(b):
			continue
		if b.devastated or b.hp < b.max_hp() * float(_params["repair_below"]):
			hurt.append(b)
	hurt.sort_custom(func(a: Building, b: Building) -> bool: return a.hp / a.max_hp() < b.hp / b.max_hp())
	for b in hurt:
		var cost := b.repair_cost()
		if _can_afford(cost):
			_cmd("repair", {"building": b.nid})
		else:
			_note_missing(cost, true, true)
			p.repair_wanted = true
			break  # (the most broken one first)


## Ruined huts are rebuilt (all of them, for half their price each).
func _rebuild_huts() -> void:
	if village.construction.ruined_huts().is_empty():
		return
	var rebuild := Hut.rebuild_cost()
	if _can_afford(rebuild):
		_cmd("rebuild_all_huts")
	else:
		_note_missing(rebuild, true, true)
		p.repair_wanted = true


func _restore_ruins() -> void:
	for o in game.world.map_objects:  # claimed ruins become watchtowers
		if o is RuinedTower and o.village == village and not p.repair_wanted and _site_room() and _can_afford(RuinedTower.restore_cost()):
			_cmd("restore_ruin", {"ruin": o.nid})


# --- the farm -------------------------------------------------------------------------------

## The farms that stand, are being built or are being repaired (a devastated
## one nobody repairs yet is not one).
func _farms() -> Array[Building]:
	var out: Array[Building] = []
	for b in _buildings_of("farm"):
		if not b.devastated or b.repairing:
			out.append(b)
	return out


## The village has no farm (the first thing checked every round) and has not
## been without one for longer than "farm_patience".
func _farm_wanted() -> bool:
	if not _farms().is_empty():
		_farmless_since = -1.0
		return false
	if _farmless_since < 0.0:
		_farmless_since = game.clock
	return game.clock - _farmless_since < float(_params["farm_patience"])


## A finished farm stands but nobody works it (its farmer died, or was never
## assigned): the farmer comes before every other recruit (_villagers).
func _farm_unmanned() -> bool:
	var any_done := false
	for b in _farms():
		if b.complete and b.working():
			any_done = true
			if (b as Workplace).worker != null:
				return false
	return any_done


## No farm: a broken one is repaired (cheaper), else a new one is placed, before
## anything but the walls.
func _ensure_farm() -> void:
	if not p.no_farm:
		return
	for b in _buildings_of("farm"):
		if b.devastated and not b.repairing and b.can_repair():
			var cost := b.repair_cost()
			if _can_afford(cost):
				_cmd("repair", {"building": b.nid})
			else:
				_note_missing(cost, true, true)
			return
	_place("farm")
	p.no_farm = _farm_wanted()


func _critical_kind(kind: String) -> bool:
	# (gold buys material only for a farm: the one that is missing, or the one
	# the schedule wants by now)
	return kind == "farm" and (p.no_farm or _farms().size() < _scheduled(_eco["farms"]))


func _retry(kind: String) -> float:
	return 4.0 if kind == "farm" and p.no_farm else 20.0


## Idle villagers go to the workplaces nobody works at (the game does it by
## itself when a workplace is finished or a villager recruited; a farmer who
## lost their farm, say, is not always sent).
func _staff_workplaces() -> void:
	var pop := village.population
	for role: String in ["farmer", "forester"]:
		for place in pop.vacant_workplaces(role):
			if pop.free_workers(role).is_empty():
				break
			_cmd("assign_worker", {"building": place.nid})


# --- villagers ---------------------------------------------------------------------------

func _villagers() -> void:
	var pop := village.population
	var want: Dictionary = _eco["villagers"]
	var rw := int(_eco.get("retire_explorer_wave", 0))
	if rw > 0 and _wave() >= rw and pop.count("explorer") > 0:
		for c in pop.civilians:
			if c.role == "explorer" and pop.retire_error(c) == "":
				_cmd("retire_villager", {"civilian": c.nid})
				break
		want = want.duplicate()
		want["explorer"] = 0
	if p.no_farm:
		return
	# A farm without its farmer comes first, as soon as the food pays for one
	# (min_food doesn't hold it back: the farmer is what brings food in).
	if (p.farm_unmanned or _role_ready("farmer")) and pop.count("farmer") < int(want.get("farmer", 0)):
		if not pop.free_workers("farmer").is_empty():
			return  # (_staff_workplaces sends them)
		if pop.free_huts().is_empty():
			_make_room()
		elif pop.recruit_error("farmer") == "":
			_cmd("recruit_villager", {"role": "farmer"})
		return
	var seen := {}
	for role: String in _eco["villager_order"]:
		seen[role] = int(seen.get(role, 0)) + 1
		var nth: int = seen[role]
		if nth > int(want.get(role, 0)) or pop.count(role) >= nth:
			continue
		if not _role_ready(role):
			continue
		var err := pop.recruit_error(role)
		if err == "No free hut (%d/%d)" % [pop.count(), pop.cap()]:
			return
		if err != "" or village.economy.amount("food") < float(Config.CIVILIANS[role]["cost"]["food"]) + float(_params["min_food"]):
			return
		_cmd("recruit_villager", {"role": role})


## A full village makes room for a farmer: its explorer retires, else a
## second gatherer.
func _make_room() -> void:
	var pop := village.population
	for role: String in ["explorer", "gatherer"]:
		if pop.count(role) <= (0 if role == "explorer" else 1):
			continue
		for c in pop.civilians:
			if c.role == role and pop.retire_error(c) == "":
				_cmd("retire_villager", {"civilian": c.nid})
				return


## Is there something for a villager of `role` to do (so recruiting one pays)?
func _role_ready(role: String) -> bool:
	match role:
		"farmer":
			return _working("farm") > village.population.count("farmer")
		"forester":
			return _working("camp") > village.population.count("forester")
		"gatherer":
			return _wave() >= 1
		"miner":
			return game.is_unlocked("miner") and free_mine() != null
	return true


## Finished `kind` buildings that do their job (a worker only has something to
## do at one of these).
func _working(kind: String) -> int:
	var n := 0
	for b in _buildings_of(kind):
		if b.complete and b.working():
			n += 1
	return n


## A farm or camp placed lately still waits to be built. The game's build queue
## puts them last (after military repairs, buildings and upgrades), so the
## military holds its new buildings and upgrades meanwhile; not for longer than
## BALANCE_BOT "economy_site_patience" s, or a site nobody can reach would stop it.
func site_open() -> bool:
	for kind: String in ["farm", "camp"]:
		for b in _buildings_of(kind):
			if not b.complete and game.clock - b.queued_at < float(_params["economy_site_patience"]):
				return true
	return false


func free_mine() -> Mine:
	for o in game.world.map_objects:
		if o is Mine and o.is_free() and o.is_found_by(village):
			return o
	return null


# --- economy buildings ---------------------------------------------------------------------

func _economy_buildings() -> void:
	var mine := free_mine()
	if mine != null and not village.population.free_workers("miner").is_empty():
		_cmd("assign_miner", {"mine": mine.nid})
	# At least the schedule's farms, and enough to feed the villagers and the army.
	var farms := maxi(_scheduled(_eco["farms"]), ceili(village.population.upkeep() / (Config.FARM_RATE * float(_params["farm_efficiency"]))))
	if village.economy.amount("food") < 40.0 and village.population.food_per_second() < 0.0:
		farms += 1  # the food is running out
	if p.repair_wanted:
		return
	if _farms().size() < farms:
		_place("farm")
	p.no_farm = _farm_wanted()
	if p.no_farm:
		return
	if _buildings_of("camp").size() < _camps_wanted():
		_place("camp")


## Worker camps: the schedule's, then one more while the foresters bring in
## less than "material_rate" per minute, up to "max_camps".
func _camps_wanted() -> int:
	var want := _camps()
	var top := int(_eco.get("max_camps", want))
	var have := _buildings_of("camp").size()
	if have >= want and have < top and _wave() >= 1 and _material_rate() >= 0.0 \
			and _material_rate() < float(_eco.get("material_rate", 0.0)):
		return have + 1
	return want


func _camps() -> int:
	return _scheduled(_eco["camps"])


## Building material per minute the foresters brought in over the last
## "material_window" s (-1 until that much time has passed).
func _material_rate() -> float:
	if _material_log.is_empty() or game.clock - _material_log[0].x < float(_params["material_window"]):
		return -1.0
	var first := _material_log[0]
	var last := _material_log[_material_log.size() - 1]
	return (last.y - first.y) / maxf(last.x - first.x, 1.0) * 60.0


func _log_materials() -> void:
	_material_log.append(Vector2(game.clock, game.stats.value(village.id, "earn.materials.foresters")))
	while _material_log.size() > 2 and game.clock - _material_log[1].x >= float(_params["material_window"]):
		_material_log.pop_front()


## Before the first wave the economy comes first: the camps the schedule
## wants and their foresters before any new post.
func economy_first() -> bool:
	return _wave() == 0 and _buildings_of("camp").size() < _camps()


func _score(kind: String, t: Vector2i, size: int, ctx: Dictionary) -> float:
	var c := _centre(t, size)
	var dist := c.distance_to(Vector2(village.center))
	match kind:
		"farm":
			var meadow := 0
			var wet := false
			for f in Building.footprint(t, size):
				if game.map.zone(f) == "meadow":
					meadow += 1
				for nb in MapData.neighbors4(f):
					wet = wet or game.map.is_water(nb)
			# (Near a road only where nothing else fits: the rats.)
			var road := float(_params["farm_road_penalty"]) if _road_within(c, float(size) / 2.0 + float(_params["farm_road_gap"])) else 0.0
			return -dist - road + (4.0 if meadow * 2 > size * size else 0.0) + (2.0 if wet else 0.0)
		"camp":
			var trees := _trees_near(t, 7)
			return -INF if trees < 4 else float(trees) * 0.3 - dist * 0.5
	return super._score(kind, t, size, ctx)


func _road_within(c: Vector2, r: float) -> bool:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var t := Vector2i(roundi(c.x) + dx, roundi(c.y) + dy)
			if Vector2(t).distance_to(c) <= r and game.map.is_road(t):
				return true
	return false


func _trees_near(t: Vector2i, r: int) -> int:
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if game.map.get_terrain(t + Vector2i(dx, dy)) == MapData.Terrain.FOREST:
				n += 1
	return n


# --- trading ----------------------------------------------------------------------------------

## Gold into building material, only for what can't wait (a repair, a ruined
## hut, the farm).
func trade() -> void:
	if not bool(_eco.get("buy_materials", false)) or not p.want_critical:
		return
	var per: int = Config.MATERIALS_TRADE["materials"]
	var bundles := ceili(float(p.critical_lack) / float(per))
	var gold_per: int = Config.MATERIALS_TRADE["gold"]
	var spare := int(_gold() - float(_params["gold_reserve"]))
	bundles = mini(bundles, spare / gold_per)
	if bundles >= 1:
		_cmd("buy_materials", {"bundles": bundles})
