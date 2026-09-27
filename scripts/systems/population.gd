class_name Population
extends Node
## Civilian registry: recruiting, food upkeep, starvation, and job assignment.
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
	return spawn(role)


## Creates a villager in a free hut. Returns null when every hut is taken.
func spawn(role: String) -> Civilian:
	var homes := free_huts()
	if homes.is_empty():
		return null
	var civ: Civilian = ROLE_SCRIPTS[role].new()
	civ.setup(game, role)
	var hut: Hut = homes[0]
	hut.resident = civ
	civ.hut = hut
	game.world.objects.add_child(civ)
	civilians.append(civ)
	changed.emit()
	return civ


func kill(civ: Civilian) -> void:
	if not civilians.has(civ):
		return
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
			kill_random(1)
			game.hud.toast("A villager starved to death.", Color("ff7a6a"))
	else:
		_starve_timer = 0.0


# --- farmers --------------------------------------------------------------------

func free_farmers() -> Array[Civilian]:
	return civilians.filter(func(c: Civilian) -> bool: return c is Farmer and c.farm == null)


func assign_farmer(farm: Farm) -> bool:
	if farm.farmer != null or not farm.complete:
		return false
	var free := free_farmers()
	if free.is_empty():
		return false
	var f: Farmer = free[0]
	f.assign(farm)
	farm.farmer = f
	farm.refresh()
	changed.emit()
	return true


# --- foresters -------------------------------------------------------------------

func free_foresters() -> Array[Civilian]:
	return civilians.filter(func(c: Civilian) -> bool: return c is Forester and c.camp == null)


func assign_forester(camp: WorkerCamp) -> bool:
	if camp.forester != null or not camp.complete:
		return false
	var free := free_foresters()
	if free.is_empty():
		return false
	var f: Forester = free[0]
	f.assign(camp)
	camp.forester = f
	changed.emit()
	return true


func unassign_forester(camp: WorkerCamp) -> void:
	if camp.forester:
		(camp.forester as Forester).unassign()
		camp.forester = null
		changed.emit()


func unassign_farmer(farm: Farm) -> void:
	if farm.farmer:
		(farm.farmer as Farmer).unassign()
		farm.farmer = null
		farm.refresh()
		changed.emit()
