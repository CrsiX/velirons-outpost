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
	"archmage": preload("res://scripts/units/archmage.gd"),
}

var game: Game
var civilians: Array[Civilian] = []
var starving := false
var _starve_timer := 0.0


func setup(p_game: Game) -> void:
	game = p_game
	for role in Config.START_CIVILIANS:
		spawn(role)


func count(role: String = "") -> int:
	if role == "":
		return civilians.size()
	return civilians.filter(func(c: Civilian) -> bool: return c.role == role).size()


func cap() -> int:
	return game.world.intact_huts().size()


## Net food flow: upkeep plus the average output of worked farms.
func food_per_second() -> float:
	var farms := game.world.buildings.filter(func(b: Building) -> bool: return b is Farm and b.complete and b.farmer != null)
	return Config.FARM_RATE * farms.size() - Config.FOOD_UPKEEP * civilians.size()


## Intact huts nobody lives in yet.
func free_huts() -> Array[Building]:
	return game.world.intact_huts().filter(func(h: Hut) -> bool: return h.resident == null)


## Returns "" when recruiting is possible, else the reason why not.
func recruit_error(role: String) -> String:
	if free_huts().is_empty():
		return "No free hut (%d/%d)" % [count(), cap()]
	if not game.economy.can_afford(Config.CIVILIANS[role]["cost"]):
		return "Not enough resources"
	return ""


func recruit(role: String) -> Civilian:
	if recruit_error(role) != "":
		return null
	game.economy.spend(Config.CIVILIANS[role]["cost"])
	Sfx.play("recruit")
	var civ := spawn(role)
	if civ:
		game.events.debug("recruit %s for %s" % [civ.label(), Config.cost_text(Config.CIVILIANS[role]["cost"])])
	if civ and civ.workplace():
		game.hud.toast("The new %s goes to work at the %s" % [civ.display_name().to_lower(), Config.BUILDINGS[civ.workplace().kind]["name"].to_lower()], UiTheme.GOLD)
	return civ


## Creates a villager in a free hut. Returns null when every hut is taken.
func spawn(role: String) -> Civilian:
	var homes := free_huts()
	if homes.is_empty():
		return null
	var civ: Civilian = ROLE_SCRIPTS[role].new()
	civ.setup(game, role)
	civ.uid = game.next_id(role)
	var hut: Hut = homes[0]
	hut.resident = civ
	civ.hut = hut
	game.world.objects.add_child(civ)
	civilians.append(civ)
	game.events.debug("%s moves into %s" % [civ.label(), hut.label()])
	var vacant := vacant_workplaces(role)
	if not vacant.is_empty():
		_assign(civ, vacant[0], true)
	changed.emit()
	return civ


## `reason` completes "farmer 2 died ...", e.g. "by goblin 4 burning their hut".
func kill(civ: Civilian, reason: String = "of unknown causes") -> void:
	if not civilians.has(civ):
		return
	game.events.important("%s died %s" % [civ.label(), reason])
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
	if civilians.is_empty():
		return
	starving = game.economy.consume_food(Config.FOOD_UPKEEP * civilians.size() * delta)
	if starving:
		_starve_timer += delta
		if _starve_timer >= Config.STARVATION_INTERVAL:
			_starve_timer = 0.0
			if not civilians.is_empty():
				kill(civilians[randi() % civilians.size()], "of starvation")
			game.hud.toast("A villager starved to death.", Color("ff7a6a"))
	else:
		_starve_timer = 0.0


# --- workplaces (farms, worker camps, ...) ------------------------------------------

## Villagers of `role` without a workplace.
func free_workers(role: String) -> Array[Civilian]:
	return civilians.filter(func(c: Civilian) -> bool: return c.role == role and c.workplace() == null)


## Finished workplaces for `role` that nobody works at, nearest to the village first.
func vacant_workplaces(role: String) -> Array[Building]:
	var kind: String = Config.CIVILIANS[role].get("works_at", "")
	if kind == "":
		return []
	var out: Array[Building] = game.world.buildings.filter(func(b: Building) -> bool: return b is Workplace and b.kind == kind and b.complete and b.worker == null)
	var c := Vector2(Config.VILLAGE_CENTER)
	out.sort_custom(func(a: Building, b: Building) -> bool: return Vector2(a.tile).distance_to(c) < Vector2(b.tile).distance_to(c))
	return out


## Puts an idle worker of the right role to work at `place`. False if it's
## taken, unfinished, or nobody is free.
func assign_worker(place: Workplace, auto: bool = false) -> bool:
	if place.worker != null or not place.complete:
		return false
	var free := free_workers(place.worker_role())
	if free.is_empty():
		return false
	_assign(free[0], place, auto)
	changed.emit()
	return true


func unassign_worker(place: Workplace) -> void:
	if place.worker:
		game.events.debug("unassign %s from %s" % [place.worker.label(), place.label()])
		place.worker.unassign()
		place.worker = null
		place.refresh()
		changed.emit()


func _assign(civ: Civilian, place: Workplace, auto: bool) -> void:
	game.events.debug("assign %s to %s%s" % [civ.label(), place.label(), " (automatic)" if auto else ""])
	civ.assign(place)
	place.worker = civ
	place.refresh()


# Farmer / forester names for the same thing (used by the building panels).

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
