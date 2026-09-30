class_name Population
extends Node
## Civilian registry: recruiting, food upkeep, starvation, and job assignment.
## Workers are assigned automatically: a new farmer / forester (any role with
## "works_at") goes to a vacant workplace of that kind, and a finished
## workplace takes an idle worker. The player can still unassign and assign.
## Every villager lives in exactly one intact hut; when that hut is destroyed
## the villager dies with it, so the hut count caps the population implicitly.

signal changed
signal civilian_lost(civ: Civilian)

const ROLE_SCRIPTS := {
	"builder": preload("res://scripts/units/builder.gd"),
	"farmer": preload("res://scripts/units/farmer.gd"),
	"explorer": preload("res://scripts/units/explorer.gd"),
	"gatherer": preload("res://scripts/units/gatherer.gd"),
	"forester": preload("res://scripts/units/forester.gd"),
	"spatial_archmage": preload("res://scripts/units/archmage.gd"),
	"miner": preload("res://scripts/units/miner.gd"),
}

var game: Game
## The village these villagers belong to.
var village: Village
var civilians: Array[Civilian] = []
var starving := false
var _starve_timer := 0.0


func setup(p_village: Village, spawn_start: bool = true) -> void:
	village = p_village
	game = village.game
	if not spawn_start:
		return
	for role in Config.START_CIVILIANS:
		spawn(role)


func count(role: String = "") -> int:
	if role == "":
		return civilians.size()
	return civilians.filter(func(c: Civilian) -> bool: return c.role == role).size()


func cap() -> int:
	return village.intact_huts().size()


## Net food flow: upkeep plus the average output of worked farms.
func food_per_second() -> float:
	var food := 0.0
	for b in game.world.buildings:
		if b is Farm and b.village == village and b.complete and b.farmer != null:
			food += (b as Farm).rate()
	return food - Config.FOOD_UPKEEP * civilians.size()


## Intact huts nobody lives in yet.
func free_huts() -> Array[Building]:
	return village.intact_huts().filter(func(h: Hut) -> bool: return h.resident == null)


## Returns "" when recruiting is possible, else the reason why not.
func recruit_error(role: String) -> String:
	if not Config.CIVILIANS[role].get("recruit", true):
		return "Only a level %d spatial mage can become one" % Config.ARCHMAGE_LEVEL
	if not game.is_unlocked(role):
		return "Walk up to a mine first"
	if free_huts().is_empty():
		return "No free hut (%d/%d)" % [count(), cap()]
	if not village.economy.can_afford(Config.CIVILIANS[role]["cost"]):
		return "Not enough resources"
	return ""


func recruit(role: String) -> Civilian:
	if recruit_error(role) != "":
		return null
	village.economy.spend(Config.CIVILIANS[role]["cost"])
	Sfx.play("recruit")
	var civ := spawn(role)
	if civ:
		village.events.debug("recruit %s for %s" % [civ.label(), Config.cost_text(Config.CIVILIANS[role]["cost"])])
	if civ and civ.workplace():
		village.toast("The new %s goes to work at the %s" % [civ.display_name().to_lower(), civ.workplace().display_name().to_lower()], UiTheme.GOLD)
	return civ


## Creates a villager in a free hut. Returns null when every hut is taken.
func spawn(role: String) -> Civilian:
	var homes := free_huts()
	if homes.is_empty():
		return null
	var civ: Civilian = ROLE_SCRIPTS[role].new()
	civ.village = village
	civ.setup(game, role)
	civ.nid = game.register(civ)
	civ.uid = game.next_id(role)
	var hut: Hut = homes[0]
	hut.resident = civ
	civ.hut = hut
	game.world.objects.add_child(civ)
	civilians.append(civ)
	village.events.debug("%s moves into %s" % [civ.label(), hut.label()])
	var vacant := vacant_workplaces(role)
	if not vacant.is_empty():
		_assign(civ, vacant[0], true)
	elif role == "miner":
		var m := free_mine(civ)
		if m:
			civ.assign(m)
	changed.emit()
	return civ


## `reason` completes "farmer 2 died ...", e.g. "by goblin 4 burning their hut".
func kill(civ: Civilian, reason: String = "of unknown causes") -> void:
	if not civilians.has(civ):
		return
	village.events.important("%s died %s" % [civ.label(), reason])
	civilians.erase(civ)
	if is_instance_valid(civ.hut) and civ.hut.resident == civ:
		civ.hut.resident = null
	civ.kill()
	Sfx.play("death")
	civilian_lost.emit(civ)
	changed.emit()


func kill_random(n: int) -> void:
	for i in n:
		if civilians.is_empty():
			return
		kill(civilians[randi() % civilians.size()])


func _process(delta: float) -> void:
	if game == null or game.is_client or civilians.is_empty():
		return
	starving = village.economy.consume_food(Config.FOOD_UPKEEP * civilians.size() * delta)
	if starving:
		_starve_timer += delta
		if _starve_timer >= Config.STARVATION_INTERVAL:
			_starve_timer = 0.0
			if not civilians.is_empty():
				kill(civilians[randi() % civilians.size()], "of starvation")
			village.toast("A villager starved to death.", Color("ff7a6a"))
	else:
		_starve_timer = 0.0


## The nearest mine this village has found that nobody works or heads for.
func free_mine(for_civ: Civilian = null) -> Mine:
	var best: Mine = null
	var best_d := INF
	for o in game.world.map_objects:
		var m := o as Mine
		if m == null or not m.is_free() or not m.is_found_by(village):
			continue
		var heading := civilians.any(func(c: Civilian) -> bool: return c != for_civ and c is Miner and (c as Miner).mine == m)
		if heading:
			continue
		var d := Vector2(m.tile).distance_to(Vector2(village.center))
		if d < best_d:
			best_d = d
			best = m
	return best


# --- workplaces (farms, worker camps, ...) ------------------------------------------

## Villagers of `role` without a workplace.
func free_workers(role: String) -> Array[Civilian]:
	return civilians.filter(func(c: Civilian) -> bool: return c.role == role and c.workplace() == null)


## Finished workplaces for `role` that nobody works at, nearest to the village first.
func vacant_workplaces(role: String) -> Array[Building]:
	var kind: String = Config.CIVILIANS[role].get("works_at", "")
	if kind == "":
		return []
	var out: Array[Building] = game.world.buildings.filter(func(b: Building) -> bool: return b is Workplace and b.village == village and b.kind == kind and b.working() and b.worker == null)
	var c := Vector2(village.center)
	out.sort_custom(func(a: Building, b: Building) -> bool: return Vector2(a.tile).distance_to(c) < Vector2(b.tile).distance_to(c))
	return out


## Puts an idle worker of the right role to work at `place`. False if it's
## taken, unfinished, or nobody is free.
func assign_worker(place: Workplace, auto: bool = false) -> bool:
	if place.worker != null or not place.working():
		return false
	var free := free_workers(place.worker_role())
	if free.is_empty():
		return false
	_assign(free[0], place, auto)
	changed.emit()
	return true


## The workplace is going (tear-down): its worker leaves and takes up
## another vacant one of its kind if there is one.
func free_workplace(place: Workplace) -> void:
	var civ: Civilian = place.worker
	unassign_worker(place)
	if civ == null or civ.dead:
		return
	var other := vacant_workplaces(civ.role)
	if not other.is_empty():
		_assign(civ, other[0], true)
		changed.emit()


func unassign_worker(place: Workplace) -> void:
	if place.worker:
		village.events.debug("unassign %s from %s" % [place.worker.label(), place.label()])
		place.worker.unassign()
		place.worker = null
		place.refresh()
		changed.emit()


func _assign(civ: Civilian, place: Workplace, auto: bool) -> void:
	village.events.debug("assign %s to %s%s" % [civ.label(), place.label(), " (automatic)" if auto else ""])
	civ.assign(place)
	place.worker = civ
	place.refresh()


# Farmer / forester names for the same thing (free_* for the building panels; the rest for tests).

func free_farmers() -> Array[Civilian]:
	return free_workers("farmer")


func assign_farmer(farm: Farm) -> bool:
	return assign_worker(farm)


func unassign_farmer(farm: Farm) -> void:
	unassign_worker(farm)


func free_foresters() -> Array[Civilian]:
	return free_workers("forester")


func assign_forester(camp: WorkerCamp) -> bool:
	return assign_worker(camp)


func unassign_forester(camp: WorkerCamp) -> void:
	unassign_worker(camp)
