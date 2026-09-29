class_name Village
extends Node
## One player's village and everything that belongs to it: economy, villagers,
## construction queue, army, hero and event log. Buildings, villagers, units
## and elementals know their village (`village`) and use its systems, never
## someone else's. Single player has one village; co-op will have one per
## player (docs/multiplayer-design.md). The map, waves, corpses, fog and
## pathing are shared and stay on Game.

signal fallen_changed(village: Village)

const HERO_SCRIPT := preload("res://scripts/units/hero.gd")

var game: Game
## 0-based player / village number.
var id := 0
var village_name := "Veliron's Outpost"
var color := Color("c9a24a")
## Village centre tile (where villagers live and the hero waits).
var center := Config.VILLAGE_CENTER
## Its 5x5 walls, gates, the edge road tiles its own wave comes from, and its
## guaranteed farm plot (all from the map, see apply_map).
var rect := Rect2i(Config.VILLAGE_ORIGIN, Vector2i(5, 5))
var gates: Array[Vector2i] = []
var home_spawns: Array[Vector2i] = []
var farm_plot := Vector2i(-1, -1)

var economy: Economy
var population: Population
var construction: Construction
var army: Army
var events: EventLog
var hero: Hero
## No villagers or no intact huts left (see update_fallen).
var fallen := false
## Relics found (Config.RELICS keys): small permanent bonuses.
var relics: Array[String] = []


## Creates the (not yet set up) systems as child nodes. Call before the world
## is built, so its buildings can be given this village as owner.
func create(p_game: Game, p_id: int, p_name: String, p_color: Color) -> void:
	game = p_game
	id = p_id
	village_name = p_name
	color = p_color
	name = "Village%d" % id
	events = EventLog.new()
	events.name = "Events"
	add_child(events)
	economy = Economy.new()
	economy.name = "Economy"
	add_child(economy)
	construction = Construction.new()
	construction.name = "Construction"
	add_child(construction)
	population = Population.new()
	population.name = "Population"
	add_child(population)
	army = Army.new()
	army.name = "Army"
	add_child(army)


## Sum of a bonus over the relics this village has found ("food", "revive"...).
func relic_bonus(key: String) -> float:
	var sum := 0.0
	for r in relics:
		sum += float(Config.RELICS[r].get(key, 0.0))
	return sum


## Takes this village's place on the generated map (MapData.villages[id]).
func apply_map(d: Dictionary) -> void:
	center = d["center"]
	rect = d["rect"]
	gates.assign(d["gates"])
	home_spawns.assign(d["home_spawns"])
	farm_plot = d["farm_plot"]


## Starting state: resources, the free starting buildings, villagers, the hero.
func setup() -> void:
	economy.setup(Config.START_RESOURCES)
	construction.setup(self)
	construction.build_starting()  # before the villagers, who then go to work there
	population.setup(self)
	army.setup(self)
	hero = HERO_SCRIPT.new()
	hero.setup_hero(game, self)
	hero.nid = game.register(hero)
	game.world.objects.add_child(hero)


## Co-op client: the same systems, but empty: villagers, buildings and the
## hero's state all come from the host (Replicator).
func setup_client() -> void:
	economy.setup(Config.START_RESOURCES)
	construction.setup(self)
	population.setup(self, false)
	army.setup(self)
	hero = HERO_SCRIPT.new()
	hero.setup_hero(game, self)
	hero.visible = false
	game.world.objects.add_child(hero)


## The village the person at this device plays.
func is_local() -> bool:
	return self == game.player_village


## A HUD toast for this village's player (co-op host: sent to theirs).
func toast(text: String, col: Color = UiTheme.TEXT) -> void:
	if is_local() and game.hud:
		game.hud.toast(text, col)
	elif game.replicator and game.replicator.hosting:
		game.replicator.toast(id, text, col)


func buildings() -> Array[Building]:
	return game.world.buildings.filter(func(b: Building) -> bool: return b.village == self)


func huts() -> Array[Building]:
	return game.world.huts().filter(func(b: Building) -> bool: return b.village == self)


func intact_huts() -> Array[Building]:
	return game.world.intact_huts().filter(func(b: Building) -> bool: return b.village == self)


## Everyone who can take on villager jobs here: villagers plus the hero.
func workers() -> Array[Civilian]:
	var out: Array[Civilian] = population.civilians.duplicate()
	if is_instance_valid(hero) and not hero.dead:
		out.append(hero)
	return out


## Standing needs at least one villager and one intact hut.
func is_standing() -> bool:
	return population.count() > 0 and not intact_huts().is_empty()


## Re-checks standing / fallen; returns true if it changed.
func update_fallen() -> bool:
	var now_fallen := not is_standing()
	if now_fallen == fallen:
		return false
	fallen = now_fallen
	fallen_changed.emit(self)
	return true
