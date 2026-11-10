class_name Village
extends Node
## One player's village and everything that belongs to it: economy, villagers,
## construction queue, army, hero and event log. Buildings, villagers, units
## and elementals know their village (`village`) and use its systems, never
## someone else's. Single player has one village; co-op has one per
## player (docs/multiplayer-design.md). The map, waves, corpses, fog and
## pathing are shared and stay on Game.


const HERO_SCRIPT := preload("res://scripts/units/hero.gd")

var game: Game
## 0-based player / village number.
var id := 0
var village_name := "Veliron's Outpost"
var color := Color("c9a24a")
## Village centre tile: the middle of the path cross (where villagers live,
## enemies head for and the hero waits).
var center := Config.VILLAGE_CENTER
## Its walled block, gates and the edge road tiles its own wave comes from (all
## from the map, see apply_map).
var rect := Rect2i(Config.VILLAGE_ORIGIN, Vector2i.ONE * (2 * Config.VILLAGE_HALF + 1))
var gates: Array[Vector2i] = []
var home_spawns: Array[Vector2i] = []

var economy: Economy
var population: Population
var construction: Construction
var army: Army
var research: Research
## Equipment the hero isn't wearing (docs/items-design.md §4).
var armoury: Armoury
var events: EventLog
var hero: Hero
## No villagers left, or its town hall has fallen (see update_fallen).
var fallen := false
## The last stand (docs/village-design.md §3b): game seconds left to repair the
## devastated town hall to full HP (-1: none running). `stand_retry`: it is a
## fallen co-op village's second chance (the longer countdown). `hall_lost`:
## the hall fell (a countdown ran out, or it was devastated with nobody
## left): the village has fallen until the hall is back at full HP.
## `no_more_stands`: a second chance failed: no new countdown until then.
var last_stand := -1.0
var stand_retry := false
var hall_lost := false
var no_more_stands := false
## Its hall has fallen and nobody was left at some point since: a villager
## coming back may start the second chance (§3b step 4). A village that fell
## with people alive gets none until it empties and fills again.
var stand_emptied := false
## The last stand's repair waits for building material (the warning says so).
var stand_unpaid := false
var _hall: TownHall
## The village-wide and map-wide relics it has (Config.RELICS keys, duplicates kept:
## each counts once; docs/items-design.md §7). They take room in the armoury.
var relics: Array[String] = []
## Campaign items brought home (a treasure's "item": scenario 9's relic sword).
var items: Array[String] = []
## Corpses brought home so far (by gatherers or the hero).
var corpses_delivered := 0


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
	research = Research.new()
	research.name = "Research"
	add_child(research)
	armoury = Armoury.new()
	armoury.name = "Armoury"
	armoury.village = self
	add_child(armoury)


## Sum of a bonus over the village-wide relics this village has, each kind once
## ("food", "revive"...; Relics.bonus).
func relic_bonus(key: String) -> float:
	return Relics.bonus(self, key)


# --- advancements (docs/advancements-design.md; Research) -----------------------------------

## The sum of advancement effect `key` this village has researched (0: none).
func adv_bonus(key: String) -> float:
	return research.bonus(key) if research else 0.0


## The highest level its walls, gates, wall towers and watchtowers may reach.
func max_piece_level() -> int:
	var lv := Config.PIECE_BASE_MAX_LEVEL
	if research:
		for id in research.done:
			lv = maxi(lv, int(Config.ADVANCEMENTS[id].get("max_piece_level", 0)))
	return lv


## How much faster villagers of `role` walk (Quick feet).
func walk_bonus(role: String) -> float:
	var sum := 0.0
	if research:
		for id in research.done:
			sum += float((Config.ADVANCEMENTS[id].get("walk", {}) as Dictionary).get(role, 0.0))
	return sum


## "better", "manual" or "" (the default rule): its targeting advancement.
func targeting() -> String:
	return str(research.effect("targeting", "")) if research else ""


## Gold for a kill worth `base` (Skilled looting and a Tithe box: a share
## more, at least 1 more).
func kill_gold(base: int) -> int:
	var b := adv_bonus("kill_gold") + relic_bonus("kill_gold")
	if base <= 0 or b <= 0.0:
		return base
	return base + maxi(1, roundi(base * b))


## Its critical hits ({"chance", "factor"}; empty: none): Eye for vital points.
func crit() -> Dictionary:
	return research.effect("crit", {}) if research else {}


## A military unit's recruiting price here (cheaper base units).
func recruit_cost(kind: String) -> Dictionary:
	return Config.scaled_cost(Config.MILITARY[kind]["cost"], 1.0 - adv_bonus("recruit_cost"))


## Takes this village's place on the generated map (MapData.villages[id]).
func apply_map(d: Dictionary) -> void:
	center = d["center"]
	rect = d["rect"]
	gates.assign(d["gates"])
	home_spawns.assign(d["home_spawns"])


## Starting state: resources, the free starting buildings, villagers, the hero.
func setup() -> void:
	economy.setup(game.start_resources)
	construction.setup(self)
	construction.build_starting()  # before the villagers, who then go to work there
	population.setup(self)
	army.setup(self)
	research.setup(self)
	hero = HERO_SCRIPT.new()
	hero.setup_hero(game, self)
	hero.nid = game.register(hero)
	game.world.objects.add_child(hero)


## A loaded game (docs/save-design.md): the systems empty and the hero made;
## SaveGame.restore_entities fills them in (and gives the hero her id).
func setup_restored() -> void:
	economy.setup({})
	construction.setup(self)
	population.setup(self, false)
	army.setup(self)
	research.setup(self)
	hero = HERO_SCRIPT.new()
	hero.setup_hero(game, self)
	game.world.objects.add_child(hero)


## Co-op client: the same systems, but empty: villagers, buildings and the
## hero's state all come from the host (Replicator).
func setup_client() -> void:
	economy.setup(Config.START_RESOURCES)
	construction.setup(self)
	population.setup(self, false)
	army.setup(self)
	research.setup(self)
	hero = HERO_SCRIPT.new()
	hero.setup_hero(game, self)
	hero.visible = false
	game.world.objects.add_child(hero)


## The village the person at this device plays.
func is_local() -> bool:
	return self == game.player_village


## A sound for this village's player only (co-op host: sent to theirs).
## Game-wide sounds go through Game.sound_all.
func sound(sound_name: String, pitch_jitter: float = 0.08) -> void:
	if is_local():
		Sfx.play(sound_name, pitch_jitter)
	elif game.replicator and game.replicator.hosting:
		game.replicator.sound(id, sound_name, pitch_jitter)


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


## Its town hall (null on a map without one: such a map is refused for play).
## Its marketplace (finished or not), or null: one per village.
func market() -> Market:
	for b in buildings():
		if b is Market:
			return b
	return null


func town_hall() -> TownHall:
	if not is_instance_valid(_hall):
		_hall = null
		for b in buildings():
			if b is TownHall:
				_hall = b
				break
	return _hall


## Standing needs at least one villager and a town hall that hasn't fallen.
func is_standing() -> bool:
	return population.count() > 0 and not hall_lost


# --- the last stand (docs/village-design.md §3b) ------------------------------------------

## Seconds left of a running last stand, or -1.
func last_stand_left() -> float:
	return last_stand


## Its town hall was devastated (Construction.on_devastated): the last stand
## starts while anyone lives here; with nobody left the hall has fallen.
func on_hall_devastated() -> void:
	if game.backdrop or game.is_client:
		return
	if population.count() == 0:
		hall_lost = true
		stand_emptied = true
		return
	_start_last_stand(false)


func _start_last_stand(retry: bool) -> void:
	var secs := float(Config.TOWN_HALL["last_stand"][Settings.difficulty_key()])
	if retry:
		secs *= float(Config.TOWN_HALL["retry_factor"])
	last_stand = secs
	stand_retry = retry
	stand_emptied = false
	_order_hall_repair()
	events.important("The town hall has fallen: repair it to full HP within %d s, or %s falls" % [ceili(secs), village_name])
	sound("raid")
	for v in game.villages:
		if v != self:
			v.events.important("Town %s falls in %d s" % [village_name, ceili(secs)])


## Orders the hall's repair if it isn't ordered yet and the material is there.
func _order_hall_repair() -> void:
	var h := town_hall()
	stand_unpaid = false
	if h == null or h.repairing or not h.can_repair():
		return
	if not construction.order_repair(h):
		stand_unpaid = true


## The town hall is whole again (or, nobody left: no stand at all).
func _end_last_stand(saved: bool) -> void:
	last_stand = -1.0
	stand_unpaid = false
	if saved:
		hall_lost = false
		no_more_stands = false
		stand_emptied = false
		events.important("The town hall is repaired: %s stands" % village_name)
		toast("The town hall stands again!", Color("9fe07a"))
	else:
		hall_lost = true
		if stand_retry:
			no_more_stands = true
	stand_retry = false
	game.check_defeat()


## The countdown, the repair order, and a fallen hall back at full HP (host only).
func _process(delta: float) -> void:
	if game == null or game.is_client or game.backdrop or game.game_over:
		return
	var h := town_hall()
	if h == null:
		return
	var whole := h.complete and not h.devastated and h.hp >= h.max_hp() - 0.01
	if last_stand >= 0.0:
		if whole:
			_end_last_stand(true)
		elif population.count() == 0:
			_end_last_stand(false)
		else:
			_order_hall_repair()
			last_stand -= delta
			if last_stand <= 0.0:
				events.important("The town hall wasn't repaired in time: %s has fallen" % village_name)
				_end_last_stand(false)
		return
	if hall_lost and whole:
		hall_lost = false
		no_more_stands = false
		stand_emptied = false
		game.check_defeat()
	elif hall_lost and population.count() == 0:
		stand_emptied = true
	elif hall_lost and stand_emptied and h.devastated and not no_more_stands:
		_start_last_stand(true)  # (co-op: a fallen village got a villager again)


## Re-checks standing / fallen; returns true if it changed.
func update_fallen() -> bool:
	var now_fallen := not is_standing()
	if now_fallen == fallen:
		return false
	fallen = now_fallen
	return true
