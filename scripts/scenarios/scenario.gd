class_name Scenario
extends RefCounted
## One scenario of the campaign (docs/scenarios-design.md): its whole content,
## set by a subclass, one file per scenario (scenario_1.gd, scenario_2.gd, ...;
## the list is Campaign.SCENARIOS). ScenarioRunner plays it.
##
## Data (set in the subclass's _init): what the map, the village and the
## rules are, the waves, who speaks. Content (overridden functions, called with
## the runner, so they can look at the game): the cutscenes, the teaching
## cards, the hints, the objectives and scripted events. Numbers that belong to
## one scenario live in its file, not in config.gd.

# --- what it is ---------------------------------------------------------------------------

var number := 0
var title := ""
## One or two sentences for the campaign menu.
var blurb := ""
## The map file (made by tools/make_scenario_map.gd, edited by hand since).
var map_path := ""
## Which of the map's villages is played.
var village := 0
## Where it is on the campaign map (a Campaign.PLACES key), and the portrait
## its card there shows (an art name).
var place := "outpost"
var portrait := "portrait_brenna"

# --- the baseline (docs/scenarios-design.md §1: nothing carries over) -----------------------

## "easy", "normal" or "hard": scales what `enemy_scale` doesn't (Config.DIFFICULTY_SCALED).
var difficulty := "normal"
## Enemy values scaled by these instead of by the difficulty: {"hp": 0.5, ...}
## (keys of Config.DIFFICULTY_SCALED). Below Easy is fine.
var enemy_scale := {}
var resources := {"gold": 0, "food": 0, "materials": 0}
## The villagers at the start, by role (Config.CIVILIANS keys).
var civilians: Array[String] = []
## Names for villagers: role -> name, given to the first of that role.
var names := {}
## A named villager's hut with a look of its own: name -> {"art", "name"}
## (Wenna's guild house).
var homes := {}
## Built for free at the start (Config.START_BUILDINGS' rules).
var buildings: Array[String] = []
## How many of the village's 9 huts stand (the ones nearest the centre); the
## rest are ruins.
var huts_standing := 9
## How many of each village piece stand ("gate", "wall", "wall_tower"); the
## others are devastated. A kind left out stands complete.
var pieces_standing := {}
## The HP share the standing pieces have left.
var pieces_hp := 1.0
## Village pieces that start above level 1, by kind ("gate", "wall",
## "wall_tower"): every one of that kind at that level, at full HP.
var piece_levels := {}
## Posts and buildings that stand finished at the start, manned:
## {"kind": a Config.BUILDINGS key, or "wall_tower" (the corner tower nearest
## that road's gate), "road": which road (0: the one nearest the village by
## road, 1: the next, ...), "at": [lo, hi] road tiles before its gate (or
## "tile": a fixed tile, or "near_water": true, the free spot by the walls
## nearest the water, or "near_site": an unlock site's kind, the free spot
## nearest the map's site of that kind), "level", "units": [{"kind",
## "level", "fixed": takes no orders (MilitaryUnit.bound)}] (one per slot)}.
## "offset": a tile relative to the village centre, else the free spot
## nearest it (scenario 5's fort and Pell's stall).
## A workplace among them takes its worker (the stall: the merchant).
var prebuilt: Array[Dictionary] = []
## Units waiting in the reserve at the start: [{"kind", "level"}] (scenario 8's band).
var reserve: Array[Dictionary] = []
## The hero: a name, the level (1 = the first), and where she starts (a tile;
## (-1, -1): the village centre; from there she walks to the village after
## the intro). A tent stands on `tent_tile` ((-1, -1): none).
var hero_name := ""
var hero_level := 1
var hero_start := Vector2i(-1, -1)
var tent_tile := Vector2i(-1, -1)
## She doesn't walk in after the intro: she lives at her start (by her tent)
## until the scenario lets her in (ScenarioRunner.hero_moves_in; scenario 7).
var hero_lives_out := false
## The card while she walks from her start to the village.
var walk_title := "On the way"
var walk_text := ""

# --- rules --------------------------------------------------------------------------------

## Military kinds that can be recruited ([]: all, as unlocked on the map).
var units: Array[String] = []
## Units can be recruited at all (false: only those the scenario gives).
var recruiting := true
## Buildings that can be placed ([]: all).
var build: Array[String] = []
## Buildings may go inside the village's walls too, on free tiles off the
## road (scenario 5's fort, where barracks and training grounds stand inside).
var build_inside := false
## Units may specialise (from Config.BRANCH_MIN_LEVEL).
var specialise := true
## The hero comes back after being downed (home); false: downed is a defeat.
var hero_revives := true
## Any villager's death is a defeat (scenario 1).
var fail_on_villager_death := false
## Named villagers whose death is a defeat ("Pell").
var must_live: Array[String] = []
## Building kinds that must not fall: once every one of a kind is devastated
## (or gone), the scenario is lost (the guild warehouse).
var must_stand: Array[String] = []
## Corpses rot as usual (false: they lie until gathered or the next wave ends).
var corpses_rot := true
## When the map's unit-unlock sites awaken, by site (Config.UNLOCK_SITES key):
## the wave (0: at the start; -1: only when the scenario awakens it,
## ScenarioRunner.awaken_site). Sites left out awaken as in a normal game.
var sites := {}
## Units and roles unlocked from the start (Config.LOCKED keys), as if found.
var unlocked: Array[String] = []
## The map's monster lairs, nearest the village first: {"wake": the wave it
## wakes up at, "guards": [kinds] (its theme's if left out), "guard_hp": their
## HP scale (the waking wave's if left out), "kinds": [kinds it sends, whatever
## the wave] (its theme's if left out)}. Cleared, a scenario's lair stays
## cleared. Lairs past the list never wake. [] leaves them as in a normal game.
var lairs: Array[Dictionary] = []

# --- waves --------------------------------------------------------------------------------

## The scenario's waves, in order: {"kinds": {kind: count}, "spawns": how many
## edge spawns they come from (spread over them), "rat_packs": [pack sizes]
## (each pack from one spawn)}. After the last one no more waves come.
var waves: Array[Dictionary] = []
## Wave 1 comes only when the player calls it (no countdown).
var first_wave_waits := true
## While wave 1 waits, the player may call it; false: it waits until the
## scenario releases the waves (ScenarioRunner.release_waves).
var first_wave_call := true
## After the last listed wave more come until the objectives are met: the
## last one again, with `more_each_wave` ({kind: count}) more per wave.
var repeat_last := false
var more_each_wave := {}
## Seconds between a wave's end and the next (the countdown).
var wave_gap := 30.0
## Amphibians (crabs, sirens) come out of the water only, never from the map edge.
var amphibians_from_water := false

# --- who speaks ---------------------------------------------------------------------------

## Speaker id -> {"name", "portrait" (art), "color"}; "" is the narrator.
var speakers := {}


# --- content: override in the scenario's file ----------------------------------------------

## The intro cutscene: Cutscene steps (see Cutscene).
func intro(_r: ScenarioRunner) -> Array[Dictionary]:
	return []


## The outro cutscene, once every objective is met.
func outro(_r: ScenarioRunner) -> Array[Dictionary]:
	return []


## Played when the hero has walked from her start to the village (hero_start
## set), before the cards begin.
func arrival(_r: ScenarioRunner) -> Array[Dictionary]:
	return []


## The teaching cards, in order. Each: "title", "text", "done" (Callable ->
## bool, polled), optional "point" (Callable -> Dictionary, as the tutorial's:
## "hud", "tab", "tiles", "units"), "start" (Callable), "ready" + "wait_text"
## (the card waits for it; "wait_title": the card's title meanwhile, else the
## last card's stays), "id".
func steps(_r: ScenarioRunner) -> Array[Dictionary]:
	return []


## One-time hints: {"id", "when": Callable -> bool (polled), "text" (a String,
## or a Callable -> String)}; shown on the card and logged the first time
## "when" holds.
func hints(_r: ScenarioRunner) -> Array[Dictionary]:
	return []


## The objectives, shown under the card: {"id", "text", "done": Callable ->
## bool, "detail": optional Callable -> String (progress, e.g. "3 / 5"),
## "optional": true (shown, not needed to win), "shown": Callable -> bool
## (hidden until it first holds; needed to win only once shown)}. All the
## others done (at once) win the scenario.
func objectives(_r: ScenarioRunner) -> Array[Dictionary]:
	return []


## Once everything is set up, before the intro.
func on_start(_r: ScenarioRunner) -> void:
	pass


## Every 0.25 s while it is played (events that aren't a wave: something restored...).
func on_poll(_r: ScenarioRunner) -> void:
	pass


## A teaching card is done (its "id", "" if it has none).
func on_card_done(_r: ScenarioRunner, _id: String) -> void:
	pass


func on_wave_started(_r: ScenarioRunner, _n: int) -> void:
	pass


func on_wave_finished(_r: ScenarioRunner, _n: int) -> void:
	pass


## Why this scenario refuses a command now (its own rules: scenario 7's
## trust), or "" (ScenarioRunner.command_error asks it after its own rules).
func command_error(_r: ScenarioRunner, _type: String, _args: Dictionary) -> String:
	return ""


## The defeat screen's line when the last building of a `must_stand` kind fell.
func fallen_text(b: Building) -> String:
	return "The %s fell." % b.display_name().to_lower()


## The defeat screen's line for a villager's death ("a goblin killed Einar").
func death_text(civ: Civilian, reason: String) -> String:
	return "%s died %s." % [civ.label().capitalize(), reason]
