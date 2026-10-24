class_name Config
extends RefCounted
## Every tunable number lives here so balancing is one-file work.
## Costs are dictionaries of resource -> amount ("gold", "food", "materials").

const MAP_SIZE := 75
const VILLAGE_CENTER := Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
const VILLAGE_ORIGIN := VILLAGE_CENTER - Vector2i(2, 2)  # top-left tile of the 5x5 walled village

# --- co-op (docs/multiplayer-design.md) ---------------------------------------------------
const MAX_PLAYERS := 8
const WAVE_EXTRA_PER_PLAYER := 0.25  # extra enemies: this x one village's wave, per player
const CARAVAN_SPEED := 1.4  # tiles per second
const VILLAGE_NAMES: Array[String] = ["Veliron's Outpost", "Rivermoor", "Eastwatch", "Ashford", "Greyholt", "Thornvale", "Kestrel Keep", "Mirefield"]
const VILLAGE_COLORS: Array[Color] = [Color("e0b340"), Color("4f8fe0"), Color("d8573e"), Color("5fbf5a"), Color("b86fe0"), Color("46c3c0"), Color("e07fb4"), Color("e8e0cf")]


## Map side length for `players` villages: +25 for every 2 players beyond the second.
static func map_size(players: int) -> int:
	return MAP_SIZE + 25 * (ceili(clampi(players, 1, MAX_PLAYERS) / 2.0) - 1)


## Map side lengths a map can have (docs/map-editor-design.md §3). Generated
## games use map_size(players); the map editor makes and loads any of these.
const MAP_SIZES: Array[int] = [50, 75, 100, 125, 150, 175, 200]
## How many villages a map of each size may hold.
const MAP_SIZE_SLOTS := {50: 1, 75: 2, 100: 4, 125: 6, 150: 8, 175: 8, 200: 8}


## The generator's per-slice amounts (treasures, ruins, lairs, mines) are tuned
## for the slices of map_size(players); a map of another size scales them by
## its slices' area (1.0 at the usual size, so those maps stay as they were).
static func gen_area_scale(size: int, players: int) -> float:
	return pow(float(size) / map_size(players), 2.0)


## The same for amounts that go with the map's width (edge spawns, rivers).
static func gen_length_scale(size: int, players: int) -> float:
	return float(size) / map_size(players)


## Tax on resources sent to another village: 10 % per extra player, at most 50 %.
static func help_tax(players: int) -> float:
	return minf(0.1 * (players - 1), 0.5)
## Village layout from the design doc. T tower, W wall, G gate, V hut.
const VILLAGE_LAYOUT: Array[String] = [
	"TWGWT",
	"WVVVW",
	"GVVVG",
	"WVVVW",
	"TWGWT",
]

const START_RESOURCES := {"gold": 150, "food": 120, "materials": 70}
const START_CIVILIANS: Array[String] = ["builder", "farmer", "forester", "explorer"]
## Built for free near the village at the start (the camp close to the
## forest); the starting farmer and forester work them. Each goes on the
## nearest free spot within START_BUILDING_RADIUS of the centre that isn't
## next to a gate; where none fits (a farm among ash, sand, swamp or trees),
## the village simply starts without it. The map makes no room for them.
const START_BUILDINGS: Array[String] = ["farm", "camp"]
## How far from the village centre (tiles, square) a starting building may stand.
const START_BUILDING_RADIUS := 9
const START_REVEAL_RADIUS := 7.5

## The guided tutorial (docs/tutorial-design.md): its map, the small starting
## village (no farm, no farmer, no explorer), enough resources for every step,
## and its two waves. The spots for the steps (watchtower, farm field,
## barracks) are picked on the road the tutorial waves take (Vector2i(-1, -1):
## pick; the farm field: the nearest free spot by the village). Its waves come
## down that road from `spawn_distance` road tiles before the gate.
const TUTORIAL := {
	"seed": 1337, "map_type": "highlands", "difficulty": "easy",
	"civilians": ["builder", "forester"], "buildings": ["camp"],
	"resources": {"gold": 200, "food": 150, "materials": 150},
	"tower_tile": Vector2i(-1, -1), "farm_tile": Vector2i(-1, -1), "barracks_tile": Vector2i(-1, -1),
	"camp_tile": Vector2i(32, 38),  # (west of the village, by the forest, in plain view; -1: the usual start spot)
	"spawn_distance": 18,
	"waves": [{"goblin": 2}, {"goblin": 5, "ork": 1}],
	"step_pause": 1.0,  # seconds between a finished step and the next card
}

## The title screen's background (scripts/ui/title_backdrop.gd): real games
## that play themselves behind the menu in slow motion, one scene after the
## other, each a fresh game on its own fixed map with a fixed setup. No fog,
## no sound, no input; enemies at a gate just vanish and the village can't fall.
## Times are real seconds, except a scene's enemy "at" / "every" (game time).
## Every key of the defaults below can be set per scene too.
## The maps ("map_type", "seed") are baked beforehand into data/title_maps/:
## rerun tools/bake_title_maps.gd after changing them or the map generator
## (tests/title_bot.gd says when they are stale; a missing one is generated).
## Scene keys:
##   "name":    for the log and the tests.
##   "road":    which road the scene is on: 0 = the shortest from the map edge
##              to a gate, 1 = the next, ... (several can share their last stretch).
##   "posts":   what stands there, ready, before it starts. Each one: "kind" (a
##              BUILDINGS key, or "wall_tower": the village's corner tower
##              nearest the road's gate), "at" [lo, hi] (by the road, lo to hi
##              road tiles before the gate), "level" (towers, barracks),
##              "units" [{"kind": a MILITARY key, specialisations too, "level"}]
##              (barracks: one per bench), "site": true (a construction site
##              the builders work on instead).
##   "enemies": groups coming down the road: "kinds" {kind: count}, "from" (road
##              tiles before the gate), "at" (first, game seconds after the
##              start), "every" (again and again; 0: once), "gap" (seconds
##              between two of a group), "wave" (their strength, as in that wave).
##   "camera":  "from" and "to", where it drifts in the scene's time: a number is
##              the road tile that far before the gate, [x, y] a tile offset from
##              the village centre; "zoom".
const TITLE_BACKDROP := {
	"speed": 0.33,  # game speed behind the menu (1.0: normal): slow motion
	"duration": 40.0,  # per scene
	"fade_in": 2.5,  # from black, once a scene is ready
	"fade_out": 1.5,  # to black, before the next scene
	"black": 0.3,  # at least this long black between two scenes (real seconds)
	"build_slice": 0.05,  # a scene's game is made over several frames, at most about this long each (seconds), so the menu stays responsive
	"shade": 0.3,  # darkens the game behind the menu, so it reads (0: none)
	"random": true,  # every new scene a random one, never the one just played (false: as listed)
	"map_type": "temperate", "seed": 38,
	"resources": {"gold": 0, "food": 5000, "materials": 0},
	"civilians": ["builder", "farmer", "forester", "gatherer"],
	"buildings": ["farm", "camp"],
	"hero": "defend",  # her mode (Hero.MODE_NAMES, lower case)
	"scenes": [
		{
			"name": "Archers hold the gate", "road": 1,
			"posts": [
				{"kind": "wall_tower", "units": [{"kind": "archer", "level": 4}]},
				{"kind": "tower", "at": [3, 6], "level": 3, "units": [{"kind": "crossbowman", "level": 3}]},
				{"kind": "tower", "at": [8, 11], "level": 2, "units": [{"kind": "swiftbowman", "level": 2}]},
			],
			"enemies": [{"kinds": {"goblin": 5, "ork": 1}, "from": 18, "at": 0.0, "every": 14.0, "gap": 1.2, "wave": 4}],
			"camera": {"from": 13, "to": 3, "zoom": 1.1},
		},
		{
			"name": "Fire on the farm", "road": 1,
			"posts": [
				{"kind": "farm", "at": [14, 19]},
				{"kind": "tower", "at": [12, 17], "level": 2, "units": [{"kind": "fire_mage", "level": 4}]},
			],
			"enemies": [{"kinds": {"rat": 6}, "from": 26, "at": 0.0, "every": 16.0, "gap": 0.4, "wave": 4}],
			"camera": {"from": 20, "to": 14, "zoom": 1.2},
		},
		{
			"name": "The barracks turn out", "road": 2,
			"posts": [
				{"kind": "barracks", "at": [7, 11], "level": 3, "units": [
					{"kind": "shield_bearer", "level": 4}, {"kind": "shield_bearer", "level": 4}, {"kind": "shield_bearer", "level": 3}]},
				{"kind": "tower", "at": [3, 6], "level": 2, "units": [{"kind": "archer", "level": 3}]},
			],
			"enemies": [{"kinds": {"ork": 3, "goblin": 2}, "from": 20, "at": 0.0, "every": 16.0, "gap": 1.5, "wave": 4}],
			"camera": {"from": 15, "to": 6, "zoom": 1.1},
		},
		{
			"name": "Summoner and witch", "road": 2,
			"posts": [
				{"kind": "tower", "at": [5, 8], "level": 3, "units": [{"kind": "summoner", "level": 5}]},
				{"kind": "tower", "at": [10, 13], "level": 2, "units": [{"kind": "archer", "level": 3}]},
			],
			"enemies": [{"kinds": {"witch": 1, "goblin": 4}, "from": 20, "at": 0.0, "every": 16.0, "gap": 1.2, "wave": 5}],
			"camera": {"from": 15, "to": 5, "zoom": 1.1},
		},
		{
			"name": "Flyers over the swamp", "road": 0,
			"posts": [
				{"kind": "tower", "at": [21, 24], "level": 3, "units": [{"kind": "ice_mage", "level": 4}]},
				{"kind": "tower", "at": [25, 28], "level": 3, "units": [{"kind": "crossbowman", "level": 4}]},
				{"kind": "tower", "at": [17, 20], "level": 2, "units": [{"kind": "fire_summoner", "level": 3}]},
			],
			"enemies": [{"kinds": {"gargoyle": 3, "vampire": 2}, "from": 34, "at": 0.0, "every": 16.0, "gap": 1.6, "wave": 10}],
			"camera": {"from": 30, "to": 18, "zoom": 1.1},
		},
		{
			"name": "Slimes split", "road": 0,
			"posts": [
				{"kind": "tower", "at": [4, 7], "level": 3, "units": [{"kind": "swiftbowman", "level": 4}]},
				{"kind": "tower", "at": [8, 11], "level": 2, "units": [{"kind": "apprentice", "level": 4}]},
			],
			"enemies": [{"kinds": {"slime3": 2, "goblin": 2}, "from": 16, "at": 0.0, "every": 15.0, "gap": 2.0, "wave": 4}],
			"camera": {"from": 12, "to": 4, "zoom": 1.2},
		},
		{
			"name": "A quiet day", "road": 1, "hero": "build",
			"civilians": ["builder", "farmer", "farmer", "forester", "forester", "gatherer"],
			"buildings": ["farm", "farm", "camp", "camp"],
			"posts": [{"kind": "tower", "at": [4, 7], "site": true}],
			"enemies": [],
			"camera": {"from": [-5, 4], "to": [3, -3], "zoom": 1.0},
		},
	],
}

## In-game statistics (docs/statistics-design.md): the Statistics screen
## (top-bar button next to the library, key T, the game-over screen).
##   "from_wave":       the screen opens from this wave on (always at game over);
##   "sample_interval": game seconds between two samples for the Timeline graphs
##                      (game time: faster at 2x / 4x, nothing while paused);
##   "client_refresh":  co-op client: real seconds between two requests for
##                      fresh numbers while the screen is open;
##   "unit_sent_value": the "Best neighbour" award: a unit sent counts as much
##                      as this many resources sent by caravan;
##   "kill_kinds":      enemy kinds with their own "killed" row (the rest:
##                      "Others"; raised dead have a row of their own).
const STATS := {
	"from_wave": 2,
	"sample_interval": 15.0,
	"client_refresh": 5.0,
	"unit_sent_value": 50,
	"kill_kinds": ["goblin", "skeleton", "ork", "witch", "rat", "wolf", "goblin_raider", "thief", "gargoyle", "necromancer", "wrathwood"],
}

## Saving and loading games (docs/save-design.md): where the save files go,
## how many games keep their autosave (older ones are deleted; manual saves
## never are), and the longest name a save can have.
const SAVE := {
	"dir": "user://saves",
	"keep_autosaves": 5,
	"name_max": 30,
}

## The balancing bot (tools/balance_bot.gd, docs/balance-bot-design.md): it
## plays whole single-player games the way a player would and records how far
## it got. Everything it decides on its own (how often, how far it looks, when
## it gives up) is here, the player's choices are in BALANCE_PROFILES.
##   "think_interval":  game seconds between two rounds of decisions;
##   "speed":           Engine.time_scale while it plays (the game's own
##                      fastest speed is 4; higher is quicker but coarser);
##   "max_waves":       a run that survives this many waves stops, "censored"
##                      (the true answer is higher). 0 = never stop;
##   "max_game_seconds", "max_real_seconds": the same, by game / wall clock;
##   "max_wave_seconds": a wave that has run this long without ending (an
##                      enemy that can't be reached, say) ends the run, "stalled";
##   "scan_radius":     tiles around the village centre where it looks for
##                      building spots;
##   "tower_spacing":   towers (and barracks) keep this far from each other;
##   "approach_steps":  road steps from a gate that count as "the approach"
##                      a tower should cover;
##   "queue_slack":     unfinished sites allowed per builder before it stops
##                      placing new ones;
##   "farm_road_gap":   a farm keeps this many tiles from any road (rats)
##                      where it can: a spot closer to one scores
##                      "farm_road_penalty" less (the same as that many tiles
##                      farther from home), so it is used only when no other fits;
##   "min_food":        villagers are only recruited while this much food is left;
##   "gold_reserve":    gold it keeps back from upgrades (it still buys
##                      units for empty posts);
##   "sample_interval": game seconds between the army / economy snapshots of
##                      the timeline in the record (the game's own Stats
##                      samples are in the record as well);
##   "track_interval":  game seconds between looks at the enemies on the map;
##   "unit_dps_summon_life": seconds a summoner's elementals count as fighting
##                      in its nominal DPS;
##   "repair_below":    a building of ours below this share of its HP (or
##                      devastated) is repaired, before anything else;
##   "material_window": game seconds over which the foresters' material rate
##                      is measured (a profile's "material_rate");
##   "hero_rest_below", "hero_rest_until": below this share of her HP the
##                      hero is sent to rest (whatever her mode) until she has
##                      this share again;
##   "barracks_support": towers and barracks work together: a barracks goes
##                      where towers (the higher the better) shoot over its
##                      fighting ground, towers don't shun a barracks' road,
##                      and towers over a barracks are upgraded first, the
##                      barracks only once every tower has its level (false:
##                      each sort covers the road the other doesn't).
const BALANCE_BOT := {
	"think_interval": 2.0,
	"speed": 4.0,
	"max_waves": 40,
	"max_game_seconds": 14400.0,
	"max_real_seconds": 3000.0,
	"max_wave_seconds": 900.0,
	"scan_radius": 18,
	"tower_spacing": 2.5,
	"approach_steps": 18,
	"queue_slack": 2,
	"farm_road_gap": 2,
	"farm_road_penalty": 30.0,
	"hero_rest_below": 0.15,
	"hero_rest_until": 0.6,
	"repair_below": 0.9,
	"material_window": 180.0,
	"min_food": 20.0,
	"gold_reserve": 0.0,
	"sample_interval": 15.0,
	"track_interval": 0.25,
	"unit_dps_summon_life": 12.0,
	"barracks_support": true,
}

## The player the balancing bot plays (--policy=<name>). All counts are
## targets it works towards as resources allow, in this order of priority:
## huts rebuilt, villagers, economy buildings, army, upgrades.
##   "villagers":      role -> how many it wants (it recruits in "villager_order");
##   "farms", "camps": worker camps and farms to build (one worker each);
##                      the camps (and their foresters) before any new post
##                      ahead of wave 1;
##   "material_rate", "max_camps": from wave 1, one more camp while the
##                      foresters bring in less than this much building
##                      material per minute, up to max_camps;
##   "retire_explorer_wave": from this wave the explorer retires, to free a hut
##                      (0 = never);
##   "towers":         [at start, more per wave, at most] watchtowers;
##   "tower_levels":   [[from wave, level], ...] the level every tower is
##                      upgraded to (wall towers too);
##   "barracks":       [[from wave, count], ...] barracks wanted;
##   "barracks_levels": [[from wave, level], ...] the same for their upgrades;
##   "training":       from this wave on: one training grounds (0 = never);
##   "tower_units":    unit kinds for the towers, in turn (kinds not unlocked
##                      yet are skipped; the first one is the fallback);
##   "wall_units":     the same for the wall towers (they take what the
##                      watchtowers take if empty);
##   "barracks_units": the same for the barracks' benches;
##   "branch":         unit kind -> specialisation it takes as soon as it can
##                      (BRANCH_MIN_LEVEL); a kind not listed keeps levelling;
##   "upgrade_order":  which units get gold first: "lowest" level first, or
##                      "kinds" (the order of the unit lists, then lowest);
##   "hero":           "explore_waves": until this wave she explores between
##                      waves and during them while no enemy is near the
##                      walls (then she trains, or defends); "attack_camps":
##                      from this hero level she is sent against known camps;
##   "call_early":     calls the next wave as soon as everything is bought and
##                      manned (for the bonus gold; faster games);
##   "buy_materials":  trades gold for building material, only for what
##                      can't wait: a repair, a ruined hut, the farm when
##                      there is none (repairs come before everything);
##   "cheats":         debug commands run at the start ("unlock": every
##                      unit and role that has to be found, "gold": +1000...).
const BALANCE_PROFILES := {
	"balanced": {
		"desc": "Economy first (three foresters before wave 1, about 20 material a minute), repairs before anything; watchtowers with archers and (once the hero unlocks them) apprentices in turn, then barracks with shield bearers and archers, training grounds and upgrades; crossbowmen, fire mages, warriors. The default player.",
		"villagers": {"builder": 2, "farmer": 2, "forester": 4, "explorer": 1, "gatherer": 2, "miner": 1},
		"villager_order": ["forester", "forester", "forester", "builder", "farmer", "gatherer", "builder", "farmer", "gatherer", "forester", "miner"],
		"farms": 2, "camps": 3, "max_camps": 4, "material_rate": 20.0, "retire_explorer_wave": 6,
		"towers": [2, 1.0, 12], "tower_levels": [[3, 2], [8, 3]],
		"barracks": [[2, 1], [8, 2]], "barracks_levels": [[4, 2], [9, 3]],
		"training": 3,
		"tower_units": ["archer", "apprentice"], "wall_units": [], "barracks_units": ["shield_bearer", "archer"],
		"branch": {"archer": "crossbowman", "shield_bearer": "warrior", "apprentice": "fire_mage"},
		"upgrade_order": "lowest",
		"hero": {"explore_waves": 4, "attack_camps": 0},
		"call_early": false, "buy_materials": true, "cheats": [],
	},
	"archers": {
		"desc": "Towers only: every wall tower and watchtower gets an archer, tower upgrades, no barracks.",
		"villagers": {"builder": 2, "farmer": 2, "forester": 2, "explorer": 1, "gatherer": 2, "miner": 1},
		"villager_order": ["builder", "farmer", "forester", "gatherer", "builder", "farmer", "forester", "gatherer", "miner"],
		"farms": 2, "camps": 2, "retire_explorer_wave": 6,
		"towers": [3, 1.5, 16], "tower_levels": [[2, 2], [6, 3]],
		"barracks": [], "barracks_levels": [],
		"training": 3,
		"tower_units": ["archer"], "wall_units": ["archer"], "barracks_units": [],
		"branch": {"archer": "crossbowman"},
		"upgrade_order": "lowest",
		"hero": {"explore_waves": 4, "attack_camps": 0},
		"call_early": false, "buy_materials": true, "cheats": [],
	},
	"swift": {
		"desc": "Like archers, but every archer becomes a swiftbowman.",
		"villagers": {"builder": 2, "farmer": 2, "forester": 2, "explorer": 1, "gatherer": 2, "miner": 1},
		"villager_order": ["builder", "farmer", "forester", "gatherer", "builder", "farmer", "forester", "gatherer", "miner"],
		"farms": 2, "camps": 2, "retire_explorer_wave": 6,
		"towers": [3, 1.5, 16], "tower_levels": [[2, 2], [6, 3]],
		"barracks": [], "barracks_levels": [],
		"training": 3,
		"tower_units": ["archer"], "wall_units": ["archer"], "barracks_units": [],
		"branch": {"archer": "swiftbowman"},
		"upgrade_order": "lowest",
		"hero": {"explore_waves": 4, "attack_camps": 0},
		"call_early": false, "buy_materials": true, "cheats": [],
	},
	"melee": {
		"desc": "Barracks first: shield bearers who turn into warriors, berserkers or halberdiers, a few archer towers.",
		"villagers": {"builder": 2, "farmer": 2, "forester": 2, "explorer": 1, "gatherer": 2, "miner": 1},
		"villager_order": ["builder", "farmer", "forester", "gatherer", "builder", "farmer", "forester", "gatherer", "miner"],
		"farms": 2, "camps": 2, "retire_explorer_wave": 6,
		"towers": [1, 0.4, 5], "tower_levels": [[4, 2]],
		"barracks": [[1, 1], [4, 2], [8, 3]], "barracks_levels": [[2, 2], [5, 3]],
		"training": 3,
		"tower_units": ["archer"], "wall_units": [], "barracks_units": ["shield_bearer"],
		"branch": {"shield_bearer": "berserker"},
		"upgrade_order": "lowest",
		"hero": {"explore_waves": 4, "attack_camps": 0},
		"call_early": false, "buy_materials": true, "cheats": [],
	},
	"mages": {
		"desc": "Apprentices and summoners on the towers (everything unlocked at the start), fire mages and fire summoners.",
		"villagers": {"builder": 2, "farmer": 2, "forester": 2, "explorer": 1, "gatherer": 2, "miner": 1},
		"villager_order": ["builder", "farmer", "forester", "gatherer", "builder", "farmer", "forester", "gatherer", "miner"],
		"farms": 2, "camps": 2, "retire_explorer_wave": 6,
		"towers": [3, 1.5, 16], "tower_levels": [[2, 2], [6, 3]],
		"barracks": [], "barracks_levels": [],
		"training": 3,
		"tower_units": ["apprentice", "summoner"], "wall_units": ["apprentice", "summoner"], "barracks_units": [],
		"branch": {"apprentice": "fire_mage", "summoner": "fire_summoner"},
		"upgrade_order": "lowest",
		"hero": {"explore_waves": 0, "attack_camps": 0},
		"call_early": false, "buy_materials": true, "cheats": ["unlock"],
	},
	"holy": {
		"desc": "Acolytes in the barracks and on the towers (unlocked at the start), inquisitors and high priests.",
		"villagers": {"builder": 2, "farmer": 2, "forester": 2, "explorer": 1, "gatherer": 2, "miner": 1},
		"villager_order": ["builder", "farmer", "forester", "gatherer", "builder", "farmer", "forester", "gatherer", "miner"],
		"farms": 2, "camps": 2, "retire_explorer_wave": 6,
		"towers": [2, 1.0, 12], "tower_levels": [[3, 2], [8, 3]],
		"barracks": [[1, 1], [6, 2]], "barracks_levels": [[3, 2], [8, 3]],
		"training": 3,
		"tower_units": ["acolyte"], "wall_units": [], "barracks_units": ["acolyte"],
		"branch": {"acolyte": "inquisitor"},
		"upgrade_order": "lowest",
		"hero": {"explore_waves": 0, "attack_camps": 0},
		"call_early": false, "buy_materials": true, "cheats": ["unlock"],
	},
}

## World generation (docs/world-design.md). The map is cut into one equal-area
## slice per player around its centre; each village sits near its slice's
## centre. Zones come from height x moisture; ash land only around volcanoes.
const MAP_TYPE_ORDER: Array[String] = ["temperate", "highlands", "coast", "desert", "volcanic"]
## Per type: shifts of the height / moisture fields, sea edges, multipliers for
## lakes, rivers, mountains and mines, the volcano count range, lava rivers,
## the chance of a lagoon by each village (LAGOON_SIZE).
const MAP_TYPES := {
	"temperate": {"name": "Temperate", "height": 0.0, "moisture": 0.0, "coast_edges": [0, 0], "lakes": 1.0, "rivers": 1.0, "mountains": 1.0, "volcanoes": [0, 1], "mines": 1.0, "lagoon": 0.3},
	"highlands": {"name": "Highlands", "height": 0.15, "moisture": -0.05, "coast_edges": [0, 0], "lakes": 0.5, "rivers": 1.5, "mountains": 1.6, "volcanoes": [0, 1], "mines": 1.5, "lagoon": 0.2},
	"coast": {"name": "Coast", "height": -0.05, "moisture": 0.08, "coast_edges": [1, 2], "lakes": 0.7, "rivers": 1.0, "mountains": 0.8, "volcanoes": [0, 0], "mines": 1.0, "lagoon": 0.0},
	"desert": {"name": "Desert", "height": 0.0, "moisture": -0.22, "coast_edges": [0, 0], "lakes": 0.3, "rivers": 0.3, "mountains": 1.0, "volcanoes": [0, 1], "mines": 1.0, "steppe_max": 0.4, "lagoon": 0.1},
	"volcanic": {"name": "Volcanic", "height": 0.1, "moisture": -0.1, "coast_edges": [0, 0], "lakes": 0.5, "rivers": 0.0, "mountains": 1.2, "volcanoes": [1, 3], "mines": 1.0, "lava_rivers": true, "lagoon": 0.0},
}
## Zones: ground art (variants), tree share and tree mix (weights), decoration
## props (not trees; walkable; cleared by buildings) and rules. "peaks": what
## stands on the zone's mountain tiles instead of peaks (the city's houses),
## drawn on the zone's own ground. The city is never generated: only map files
## (the campaign's capital) have it.
## Decorations no zone scatters, for hand-made maps (the map editor offers
## them with the zones' own): the dried-up well in scenario 5's fort.
const EXTRA_DECOR: Array[String] = ["well_dry"]
const ZONE_ORDER: Array[String] = ["meadow", "oak", "pine", "heath", "steppe", "swamp", "ash", "city"]
const ZONES := {
	"meadow": {"name": "Meadow", "ground": ["tile_meadow_0", "tile_meadow_1", "tile_meadow_2"], "trees": 0.06, "mix": {"tree_oak": 1}, "decor": 0.0, "decor_mix": {}, "farm_bonus": 0.2},
	"oak": {"name": "Oak woods", "ground": ["tile_grass_0", "tile_grass_1", "tile_grass_2"], "forest_floor": "tile_forest_oak", "trees": 0.45, "mix": {"tree_oak": 6, "tree_pine_0": 1}, "decor": 0.01, "decor_mix": {"boulder": 1}},
	"pine": {"name": "Pine forest", "ground": ["tile_grass_dark_0", "tile_grass_dark_1"], "forest_floor": "tile_forest", "trees": 0.85, "mix": {"tree_pine_0": 4, "tree_pine_1": 4, "tree_dead": 1}, "decor": 0.0, "decor_mix": {}},
	"heath": {"name": "Heath", "ground": ["tile_heath_0", "tile_heath_1"], "trees": 0.15, "mix": {"tree_dead": 1}, "decor": 0.06, "decor_mix": {"boulder": 1}},
	"steppe": {"name": "Steppe", "ground": ["tile_desert_0", "tile_desert_1"], "trees": 0.03, "mix": {"tree_dead": 1}, "decor": 0.03, "decor_mix": {"cactus": 1}, "no_farms": true},
	"swamp": {"name": "Swamp", "ground": ["tile_swamp_0", "tile_swamp_1"], "trees": 0.2, "mix": {"tree_dead": 1}, "decor": 0.18, "decor_mix": {"reeds": 1}, "no_farms": true, "walk": 0.7},
	"ash": {"name": "Ash land", "ground": ["tile_ash_0", "tile_ash_1"], "trees": 0.05, "mix": {"stump_charred": 1}, "decor": 0.05, "decor_mix": {"lava_rock": 1}, "no_farms": true},
	"city": {"name": "City", "ground": ["tile_cobble_0", "tile_cobble_1", "tile_cobble_2"], "trees": 0.0, "mix": {}, "decor": 0.05, "decor_mix": {"city_rubble": 1}, "no_farms": true,
		"peaks": ["house_0", "house_1", "house_2", "house_ruin_0", "house_ruin_1"]},
}
## Land shares of the zones from height x moisture (before map-type shifts);
## ash comes on top, around volcanoes.
const ZONE_SIZE := 22.0  # typical zone diameter, tiles
const ZONE_BLEND := 0.06  # field noise at zone borders (share of the 0..1 range)
const DESERT_MAX_SHARE := 0.2  # steppe at most this share of the map (Desert type: its "steppe_max")
const FOREST_CLEARING_RING := 4  # tiles around the village centre kept free (Chebyshev)
const ZONE_FAIR_RADIUS := 12.0  # around every village: enough meadow and trees
const ZONE_FAIR_MIN := {"meadow": 0.25, "trees": 0.25}
const ZONE_FAIR_CLEAR := 8.0  # no steppe, swamp or ash this close to a village
const ZONE_FAIR_SPREAD := 0.15  # max difference in zone shares between slices
## Trees planted when a village has too few (ZONE_FAIR_MIN["trees"]): they grow
## as woods of zone "zone" (its ground and tree mix), one tile at a time, on the
## open tile scoring best. Score = "grow" x forest tiles among its 8 neighbours
## + "clump" x a noise value (0..1; "noise" is its frequency, so groves form
## in patches) + "far" x distance from the centre / ZONE_FAIR_RADIUS
## - "meadow" if it is meadow (kept for farms where possible). "grove": trees
## in the grove planted when no spot near a village suits the worker camp
## (nearest its middle first there, the same scoring otherwise).
const ZONE_FAIR_WOODS := {"zone": "oak", "grow": 1.0, "clump": 2.0, "noise": 0.15, "far": 0.6, "meadow": 1.5, "grove": 14}
## Villages: within this of their slice's centre, on dry flat land.
const VILLAGE_CENTER_RADIUS := 12.0
const VILLAGE_CLEAR_RADIUS := 5.0  # no water, mountains or volcanoes this close to the walls
const VILLAGE_BORDER_GAP := 8.0  # tiles from the slice's border
const VILLAGE_MAP_MARGIN := 9  # village centres stay this far from the map edge
const VILLAGE_VOLCANO_DIST := 20.0
const VILLAGE_SEA_DIST := 10.0
## Roads (A*, 4 directions, on a cost map by zone; see docs/world-design.md §5).
const VILLAGE_MIN_LINKS := 2  # road links per village with 3+ players (1 with 2)
const ROAD_DETOUR_MAX := 2.5  # a link longer than this x the straight distance is dropped
const ROAD_COSTS := {"road": 0.3, "meadow": 1.0, "steppe": 1.0, "heath": 1.6, "oak": 1.6, "pine": 2.5, "swamp": 2.5, "ash": 2.0, "city": 1.0, "crossing": 4.0, "pass": 15.0}
const ROAD_COST_NOISE := 0.3
const ROAD_BESIDE_COST := 2.0  # extra cost next to an existing road: merge or keep away
const SP_SPAWNS := Vector2i(3, 5)  # single player: edge spawns
const COOP_SPAWNS := Vector2i(2, 3)  # co-op: edge spawns per village, on its slice's edge
## Water.
const SHALLOW_WALK := 0.5  # walking speed factor in shallow water and fords
const LAKE_COUNT := Vector2i(1, 3)  # per 75x75 of map area
const LAKE_SIZE := Vector2i(12, 60)
const LAKE_VILLAGE_DIST := 6.0
const RIVER_COUNT := Vector2i(0, 2)
## Rivers wind: a river heads for a random edge / water tile within
## RIVER_GOAL_SLACK x the nearest one's distance (the nearest is usually in
## line with its source: only a straight path would be shortest). A ridged
## noise (zero lines every ~1/freq tiles) adds up to RIVER_MEANDER to a tile's
## routing cost, so it follows winding channels, and a little per-tile
## jitter breaks the remaining ties.
const RIVER_MEANDER := 10.0
const RIVER_MEANDER_FREQ := 0.1
const RIVER_JITTER := 0.4
const RIVER_GOAL_SLACK := 1.3
const COAST_SHARE := Vector2(0.15, 0.3)
## Water for the water monsters (docs/world-design.md §9.8). Coast maps: every
## village gets an inlet from the sea, a channel COAST_INLET_WIDTH wide (a
## deep core with a shallow rim), dead-ending within COAST_INLET_DIST of its
## walls; the sea keeps the rest of VILLAGE_SEA_DIST. Other map types: with
## the type's "lagoon" chance a village gets a lagoon, a lake of LAGOON_SIZE
## tiles whose shore comes within LAGOON_DIST of its walls (deep core at least
## LAGOON_MIN_WIDTH wide). WATER_SPAWNS: deep tiles per water body water
## monsters can live in, where they come from.
const COAST_INLET_DIST := 8.0
const COAST_INLET_WIDTH := 5
const LAGOON_SIZE := Vector2i(60, 110)
const LAGOON_DIST := 6.0
const LAGOON_MIN_WIDTH := 3
const WATER_SPAWNS := Vector2i(1, 2)
## Bridge look by the zone around it (the look only).
const BRIDGE_STYLES := {"meadow": "stone", "oak": "stone", "pine": "timber", "heath": "timber", "steppe": "rope", "swamp": "stilts", "ash": "charred", "city": "stone"}
## Mountains and volcanoes.
const MOUNTAIN_SHARE := Vector2(0.05, 0.08)  # of the map, x the type's "mountains"
const VOLCANO_ASH_RADIUS := 6.0
const VOLCANO_NO_BUILD := 3.0  # tiles from the crater's centre tile
const VOLCANO_SLICE_DIST := 26.0  # from every slice centre (villages keep VILLAGE_VOLCANO_DIST)
## Tries with the next seed when a generated map fails its checks.
const MAP_TRIES := 5

## Special objects (docs/world-design.md §9). Treasures: per slice (the same
## number and tiers for every slice), looted by the hero in Explore mode.
const TREASURE_COUNT := Vector2i(3, 5)
const TREASURE_DISTANCE := Vector2(10.0, 35.0)  # from the slice's village
const TREASURE_TIER_DIST: Array[float] = [18.0, 26.0]  # tier 1 closer than 18, tier 2 than 26, else 3
const TREASURE_TIER_SCALE: Array[float] = [1.0, 1.5, 2.0]  # rewards x this per tier
const OBJECT_SPACING := 6.0  # objects at least this far apart
## Per kind: zones it appears in ([] = any; "beach" / "hills" are special),
## pick weight, loot time and reward (ranges, x the tier scale). "relic": may
## hold a relic instead; "heal_units" / "hero_xp": the shrine's blessings.
const TREASURES := {
	"chest": {"name": "Buried chest", "zones": [], "weight": 3.0, "loot_time": 4.0, "reward": {"gold": [40, 80]}},
	"ruins": {"name": "Overgrown ruins", "zones": ["oak", "pine", "heath"], "weight": 2.0, "loot_time": 8.0, "reward": {"materials": [30, 60], "gold": [20, 40]}},
	"shrine": {"name": "Shrine", "zones": ["meadow", "heath"], "weight": 2.0, "loot_time": 6.0, "reward": {"hero_xp": [80, 120]}, "alt_reward": {"heal_units": [1, 1]}},
	"standing_stones": {"name": "Standing stones", "zones": ["heath", "hills"], "weight": 1.5, "loot_time": 6.0, "reward": {"gold": [50, 90]}, "relic": true},
	"shipwreck": {"name": "Shipwreck", "zones": ["beach"], "weight": 5.0, "loot_time": 8.0, "reward": {"gold": [60, 120], "food": [20, 40]}},
	"dragon_bones": {"name": "Dragon bones", "zones": ["ash"], "weight": 5.0, "loot_time": 10.0, "reward": {"gold": [100, 150]}, "relic": true},
	# The campaign's drowned abbey (scenario 9), placed by its map file: never
	# generated, not in the library. Its reward is an item (the relic sword).
	"abbey": {"name": "Drowned abbey", "zones": [], "weight": 0.0, "loot_time": 8.0, "reward": {}, "campaign": true},
	# The capital's throne hall (scenario 11), 3x3: a landmark, never looted
	# ("landmark": what its panel says instead).
	"throne_hall": {"name": "Throne hall", "zones": [], "weight": 0.0, "loot_time": 1.0, "reward": {}, "campaign": true,
		"landmark": "The throne hall of Veliron. Rhodri sits within, with what is left of his court."},
}
const RELIC_MAX := 2  # per map
## Relics: a small permanent bonus for the village that finds one.
const RELICS := {
	"hawkeye": {"name": "Hawk-eye relic", "desc": "+10 % tower range", "tower_range": 0.1},
	"phoenix": {"name": "Phoenix feather", "desc": "units revive 20 % faster", "revive": -0.2},
	"hearth": {"name": "Hearth stone", "desc": "+1 hero HP per second while resting", "hero_rest": 1.0},
	"harvest": {"name": "Harvest idol", "desc": "+10 % food from farms", "food": 0.1},
}
## Monster camps guard some far treasures: neutral monsters that stay by the
## camp and fight whoever comes close. Cleared only on the player's order.
const CAMP_CHANCE: Array[float] = [0.0, 0.5, 1.0]  # a camp guards a treasure of tier 1/2/3 (every slice has one tier-3 camp)
const CAMP_MONSTERS: Array = [["goblin", "goblin"], ["goblin", "goblin", "ork"], ["goblin", "ork", "ork", "witch"]]
const CAMP_AGGRO := 3.5  # monsters attack what comes this close to the camp
const CAMP_LEASH := 5.0  # and never follow it farther from the camp
const CAMP_HP_SCALE := 1.5  # camp monsters are a bit tougher than wave enemies
## Unit-unlock sites: dormant until their wave, then the hero unlocks the unit
## there for every player. Copies: max(1, floor(players x UNLOCK_SITE_SHARE)).
## When new units are added later: ask how each one is unlocked.
const UNLOCK_SITES := {
	"stone_circle": {"name": "Stone circle", "unlocks": "summoner", "wave": 3, "distance": [12.0, 18.0], "visit_time": 5.0,
		"rumour": "Travellers speak of an old stone circle somewhere in the wilderness. Whoever finds it can call forth summoners.",
		"awake": "The stone circle has awakened. The hero can unlock the summoner there (Explore mode)."},
	"mage_tower": {"name": "Mage's tower", "unlocks": "apprentice", "wave": 5, "distance": [15.0, 22.0], "visit_time": 5.0,
		"rumour": "Travellers speak of a mage's tower lost in the wilderness. Whoever finds it can train apprentices.",
		"awake": "A light shines in the mage's tower. The hero can unlock the apprentice there (Explore mode)."},
	"chapel": {"name": "Ruined chapel", "unlocks": "acolyte", "wave": 6, "distance": [16.0, 24.0], "visit_time": 5.0,
		"rumour": "Travellers speak of a ruined chapel where a light still burns. Whoever finds it can ordain acolytes.",
		"awake": "Light falls through the roof of the ruined chapel. The hero can unlock the acolyte there (Explore mode)."},
}
const UNLOCK_SITE_SHARE := 0.5
## Ruined watchtowers: claimed by the hero (Explore mode), restored by a builder.
const RUINED_TOWERS := Vector2i(0, 2)  # per slice
const RUIN_DISTANCE := Vector2(12.0, 40.0)
const RUIN_CLAIM_TIME := 5.0
## Monster lairs: their look by zone (1x1 or 2x2).
const LAIRS := {"mountain": "lair_cave", "pine": "lair_tree", "swamp": "lair_ruin", "ash": "lair_pit", "steppe": "lair_crypt"}
const LAIRS_PER_SLICE := Vector2i(0, 2)
const LAIR_DISTANCE := 25.0
## Every lair gets a winding road to the network: bent through one or two
## waypoints pushed this share of its length off the straight line (at least
## LAIR_ROAD_BEND_MIN tiles; one bend from LAIR_ROAD_BENDS.x tiles long, two
## from .y), over extra cost noise.
const LAIR_ROAD_BEND := Vector2(0.25, 0.4)
const LAIR_ROAD_BEND_MIN := 2.0
const LAIR_ROAD_BENDS := Vector2(5.0, 16.0)
const LAIR_ROAD_NOISE := 0.8
## Lairs wake up (docs/world-design.md §9.6): per slice, the first at
## LAIR_FROM_WAVE, each further one LAIR_EVERY waves later (in random order).
## An awake lair is one more spawn point for its slice's share of the wave,
## sending only its theme's kinds (those whose wave has come; goblins
## otherwise), and has guards (wave-strength). The hero can clear it: it drops
## loot and sleeps LAIR_QUIET_WAVES waves, then wakes again.
const LAIR_FROM_WAVE := 10
const LAIR_EVERY := 3
const LAIR_QUIET_WAVES := 3
const LAIR_THEMES := {
	"lair_cave": {"name": "cave", "kinds": ["ork", "gargoyle"], "guards": ["ork", "ork", "goblin"]},
	"lair_tree": {"name": "hollow tree", "kinds": ["goblin", "rat", "spider_mother"], "guards": ["goblin", "goblin", "goblin"]},
	"lair_ruin": {"name": "sunken ruin", "kinds": ["skeleton", "witch"], "guards": ["skeleton", "skeleton", "witch"]},
	"lair_pit": {"name": "smoking pit", "kinds": ["ork", "gargoyle"], "guards": ["ork", "ork", "goblin"]},
	"lair_crypt": {"name": "crypt", "kinds": ["skeleton", "necromancer", "vampire"], "guards": ["skeleton", "skeleton", "skeleton"]},
}
## A cleared lair's loot (a sack at its door): x (1 + LAIR_LOOT_GROWTH per
## wave past LAIR_FROM_WAVE); sometimes a relic instead (one the clearing
## village doesn't have yet).
const LAIR_LOOT := {"gold": [60, 100], "materials": [20, 40]}
const LAIR_LOOT_GROWTH := 0.1
const LAIR_RELIC_CHANCE := 0.25
## Mines on the outer edge of mountain ranges, linked to the roads, worked
## by one miner (first to arrive). Walking up to one unlocks the miner for all.
const MINES_PER_SLICE := 1.0  # x the map type's "mines"
const MINE_DISTANCE := 10.0  # from any village
const MINE_GOLD_RATE := 0.25  # gold per second
const MINE_REACH := 2.0

## Sight: explored tiles are only "under surveillance" (enemies visible) near
## observers. Building sight is BUILDING_SIGHT + size / 2 (whole tiles) around the anchor tile.
const UNIT_SIGHT := 4.0  # villagers and soldiers outside the walls
## Every unit of ours outside (villagers, the hero, soldiers, summons,
## caravans) also explores the fog this close around it, whatever it's doing.
## The hero earns XP for it like for exploring. Explorers see further.
const UNIT_REVEAL := 1.8
const HUT_SIGHT := 4.0  # every intact hut
const GATE_SIGHT := 3.0  # every gate, manned or not
const LIGHTSTONE_SIGHT := 5.5  # light stones watch this far, entirely passively
const BUILDING_SIGHT := 3.0  # every other finished building
const TOWER_SIGHT_BONUS := 1.5  # manned towers see this far beyond their range

## Buildings the player can order. "size" is the square footprint in tiles.
const BUILDINGS := {
	"tower": {
		"name": "Watchtower", "cost": {"materials": 30}, "build_time": 8.0, "size": 1, "art": "watchtower",
		"desc": "Built in the wilderness by a builder. Station an archer on it.",
	},
	"farm": {
		"name": "Farm", "cost": {"materials": 50}, "build_time": 12.0, "size": 3, "art": "farm_field",
		"desc": "3x3, outside the walls. Produces food while a farmer works it.",
	},
	"hut": {
		# (Never built new: a ruined hut is rebuilt for REPAIR_SHARE of this, i.e. 40.)
		"name": "Village Hut", "cost": {"materials": 80}, "build_time": 10.0, "size": 1, "art": "hut",
		"desc": "Houses one civilian. Can only be rebuilt on a ruined lot.",
	},
	"camp": {
		"name": "Worker Camp", "cost": {"materials": 25}, "build_time": 6.0, "size": 1, "art": "worker_camp",
		"desc": "Base for one forester, who cuts nearby trees for building material.",
	},
	"barracks": {
		"name": "Barracks", "cost": {"materials": 20, "gold": 30}, "build_time": 16.0, "size": 2, "art": "barracks",
		"desc": "2x2. Units wait on its benches (1 per level, up to 3) and turn out when enemies come near. Upgrade for more benches and range.",
	},
	"training": {
		"name": "Training Grounds", "cost": {"materials": 40, "gold": 40}, "build_time": 14.0, "size": 2, "art": "training_grounds",
		"desc": "2x2. Station a military unit here; the hero (in Train mode) passes on her XP to level it up for free.",
	},
	"lightstone": {
		"name": "Light Stone", "cost": {"materials": 20}, "build_time": 10.0, "size": 1, "art": "light_stone",
		"desc": "Rune pillar that lights up the land around it. Needs no one to man it.",
	},
	# The merchant's trade stall (docs/scenarios-design.md §7.4): only in the
	# campaign's scenarios that allow it ("campaign": never in a normal game).
	# Its level is its stage (STALL_LEVELS); the merchant works it.
	"stall": {
		"name": "Trade Stall", "cost": {"materials": 30}, "build_time": 12.0, "size": 2, "art": "stall",
		"campaign": true,
		"desc": "2x2. The merchant's stall: while he tends it, gold buys building material and food from his stock. Rats eat his goods.",
	},
	# The guild's warehouse (scenario 4: it must not fall); prebuilt by a
	# scenario, never placed by the player. Enemies breaking in go for it as
	# for a hut and plunder it (WAREHOUSE).
	"warehouse": {
		"name": "Guild Warehouse", "cost": {"materials": 80}, "build_time": 20.0, "size": 2, "art": "warehouse",
		"campaign": true,
		"desc": "2x2. The guild's stock. Enemies that break in go for it as for a hut and plunder it.",
	},
	# The battlefield's graveyard by the chapel (scenario 6); prebuilt by the
	# scenario. Gatherers carry the fallen (Corpse.fallen) here to be buried.
	"graveyard": {
		"name": "Graveyard", "cost": {"materials": 40}, "build_time": 16.0, "size": 3, "art": "graveyard",
		"campaign": true,
		"desc": "3x3. Gatherers carry the fallen of the battlefield here and bury them, so no necromancer can raise them again.",
	},
	# The druids' grove by their stone circle (scenario 7): barracks whose
	# benches only druids sit on; prebuilt by the scenario at level 3.
	"grove": {
		"name": "Druids' Grove", "cost": {"materials": 40}, "build_time": 16.0, "size": 2, "art": "grove",
		"campaign": true,
		"desc": "2x2. The druids' own barracks by their stone circle. They turn out for enemies near it, but take no orders.",
	},
}

## The guild warehouse (Warehouse; docs/scenarios-design.md §7.7):
## raid_damage: HP an enemy that gets to it takes (it is gone then, as after
## burning a hut).
const WAREHOUSE := {"raid_damage": 50.0}

## The battlefield's fallen (scenario 6; Corpse.fallen, Graveyard): a
## gatherer carries "carry" of them per trip (the dead are heavy), and lays
## each in its grave in "bury_time" seconds.
const FALLEN := {"carry": 1, "bury_time": 4.0}

## The trade stall's stages (Building.level 1-3): peddler, stall, guild market.
## "stock": goods it holds at most (a lot sold takes its "amount" of goods);
## "refill": goods per minute while the merchant tends it; "lots": what gold
## buys, {good: {"amount", "gold"}}.
const STALL_LEVELS: Array[Dictionary] = [
	{"name": "Peddler's Stall", "stock": 30, "refill": 6.0,
		"lots": {"materials": {"amount": 10, "gold": 15}, "food": {"amount": 10, "gold": 12}}},
	{"name": "Trade Stall", "stock": 60, "refill": 12.0,
		"lots": {"materials": {"amount": 15, "gold": 20}, "food": {"amount": 15, "gold": 15}}},
	{"name": "Guild Market", "stock": 120, "refill": 24.0,
		"lots": {"materials": {"amount": 25, "gold": 30}, "food": {"amount": 25, "gold": 22}}},
]

## Tower range in tiles. Towers own the range; units own damage and speed.
const TOWER_RANGE := {"tower": 3.6, "wall_tower": 4.8}
## Tower levels (wall towers and watchtowers alike start at 1). Levels only add
## range for the stationed unit. Upgrading costs building material and a
## builder's time; the tower keeps fighting meanwhile.
const TOWER_LEVELS: Array[Dictionary] = [
	{"range_bonus": 0.0},
	{"range_bonus": 0.8, "cost": {"materials": 30}, "work_time": 8.0},
	{"range_bonus": 1.6, "cost": {"materials": 55}, "work_time": 12.0},
]

## Building HP (docs/siege-design.md §2): max HP per kind and level (index =
## level - 1; kinds without levels have one entry). Huts have 1: any enemy
## that reaches one burns it. Upgrades add the difference to the current HP.
const BUILDING_HP := {
	"gate": [80.0, 160.0, 320.0],
	"wall": [100.0, 200.0, 400.0],
	"wall_tower": [200.0, 400.0, 800.0],
	"tower": [100.0, 200.0, 400.0],
	"barracks": [150.0, 250.0, 400.0],
	"farm": [100.0],
	"camp": [50.0],
	"lightstone": [80.0],
	"training": [150.0],
	"stall": [100.0, 150.0, 200.0],
	"warehouse": [500.0],  # (10 thieves' plunder: WAREHOUSE.raid_damage)
	"graveyard": [150.0],
	"grove": [400.0, 400.0, 400.0],
	"hut": [1.0],
}
## The village's pieces were never bought: their price and build time count
## for repairs (and tear-down shares, should they ever be torn down).
const PIECE_PRICES := {
	"gate": {"cost": {"materials": 40}, "build_time": 10.0},
	"wall": {"cost": {"materials": 30}, "build_time": 10.0},
	"wall_tower": {"cost": {"materials": 60}, "build_time": 14.0},
}
## Gate and wall levels (all start at 1): only more HP (BUILDING_HP) and a
## look. Like tower upgrades: building material and a builder's time.
const PIECE_LEVELS := {
	"gate": [{}, {"cost": {"materials": 30}, "work_time": 8.0}, {"cost": {"materials": 60}, "work_time": 12.0}],
	"wall": [{}, {"cost": {"materials": 35}, "work_time": 8.0}, {"cost": {"materials": 70}, "work_time": 12.0}],
}
## Repairs (docs/siege-design.md §4): building material only, REPAIR_SHARE of
## the material spent on the building (price plus paid upgrades) times the
## missing share of its HP (rounded up); a builder's REPAIR_TIME_SHARE of its
## build time times that share. A devastated building costs half of what went
## into it; a ruined watchtower is restored the same way, a ruined hut rebuilt.
const REPAIR_SHARE := 0.5
const REPAIR_TIME_SHARE := 1.0
## Enemies at the village (docs/siege-design.md §5).
const SIEGE := {
	"approach": 3,  # tiles around the village's pieces where enemies leave their road
	"hp_per_step": 10.0,  # an intact barrier counts one step's detour per this much HP
	"switch_margin": 3.0,  # steps cheaper before an enemy leaves the barrier it hits
	"rescan": 0.5,  # s between an enemy's second thoughts at a barrier
	"rebuild_interval": 0.4,  # s: a stale field is rebuilt at most this often
	"slip_time": 4.0,  # s an intact gate holds a rat or thief ("entry": "slip")
	"stuck_slip": 45.0,  # s before an enemy that can't hurt a barrier slips past it
	"slow_cost": 20,  # field cost of a step on shallow water or swamp (ground: 10)
}

const CIVILIANS := {
	"builder": {
		"name": "Builder", "cost": {"food": 30}, "speed": 1.7,
		"desc": "Walks to construction sites and builds them.",
	},
	"farmer": {
		"name": "Farmer", "cost": {"food": 25}, "speed": 1.5,
		"desc": "Works one farm and carries its food home.",
		"works_at": "farm",  # new farmers go straight to a farm without one
	},
	"explorer": {
		"name": "Explorer", "cost": {"food": 25}, "speed": 2.0,
		"desc": "Scouts the fog on their own. Flees from enemies.",
	},
	"gatherer": {
		"name": "Gatherer", "cost": {"food": 30}, "speed": 1.6,
		"desc": "Collects enemy corpses once it's safe, for gold and a little food.",
	},
	"forester": {
		"name": "Forester", "cost": {"food": 25}, "speed": 1.5,
		"desc": "Works from a worker camp, chopping nearby trees for building material.",
		"works_at": "camp",
	},
	"miner": {
		"name": "Miner", "cost": {"food": 30}, "speed": 1.5,
		"desc": "Works a mine in the mountains for gold. Stays at the mine, safe inside; one miner per mine.",
	},
	# Can't be recruited: only a campaign scenario has one (Pell; docs/scenarios-design.md §7.4).
	"merchant": {
		"name": "Merchant", "cost": {}, "speed": 1.5, "recruit": false,
		"desc": "Tends the trade stall: while he is there, gold buys his goods. Flees from enemies.",
		"works_at": "stall",
	},
	# Can't be recruited: only a campaign scenario has one (Wenna, scenario 4;
	# docs/scenarios-design.md §7.7). Stays in her hut, the guild house.
	"guildmaster": {
		"name": "Guild Master", "cost": {}, "speed": 1.2, "recruit": false,
		"desc": "Keeps the guild's books in the guild house and never leaves it. She dies if it burns.",
		"stays_home": "keeping the guild's books",
	},
	# Can't be recruited: Anselm, the battlefield's priest (scenario 6). Stays
	# in his hut ("stays_home": what he does there).
	"priest": {
		"name": "Priest", "cost": {}, "speed": 1.1, "recruit": false,
		"desc": "Prays for the dead in his house and never leaves it. He dies if it burns.",
		"stays_home": "praying for the dead",
	},
	# Can't be recruited: Fiona, the old king's daughter (scenario 7). Stays in
	# her house.
	"princess": {
		"name": "Princess", "cost": {}, "speed": 1.2, "recruit": false,
		"desc": "The old king's daughter holds her court in her house and never leaves it. She dies if it burns.",
		"stays_home": "holding her court",
	},
	# Can't be recruited: a spatial mage of level ARCHMAGE_LEVEL becomes one
	# (docs/military-design.md §7). A key to ending the siege, later.
	"spatial_archmage": {
		"name": "Spatial Archmage", "cost": {}, "speed": 0.6, "recruit": false,
		"desc": "Only a level %d spatial mage can become one. May one day break the siege of Veliron." % ARCHMAGE_LEVEL,
	},
}
## The role that works at buildings of `kind` ("" if none), from "works_at".
static func worker_role(kind: String) -> String:
	for role in CIVILIANS:
		if CIVILIANS[role].get("works_at", "") == kind:
			return role
	return ""


const CIVILIAN_ORDER: Array[String] = ["builder", "farmer", "forester", "explorer", "gatherer", "miner", "merchant", "guildmaster", "priest", "princess", "spatial_archmage"]
## Unit kinds and villager roles that have to be unlocked first, and how
## (docs/world-design.md §9.4, §9.6). Unlocks are global: for every village.
const LOCKED := {"summoner": "stone_circle", "apprentice": "mage_tower", "acolyte": "chapel", "miner": "mine"}

## Villagers have HP: any enemy can hurt them (they flee, never fight); at 0
## they die. At home they heal CIVILIAN_REGEN per second.
const CIVILIAN_HP := 20.0
const CIVILIAN_REGEN := 2.0
const FOOD_UPKEEP := 0.05  # food per civilian per second
const STARVATION_INTERVAL := 15.0  # a civilian dies this often while food is 0
## HUD warnings (real seconds, whatever the game speed; paused time doesn't
## count): "nobody can build" once the build queue has waited
## this long with no builder (and the hero not building); "food shortage" once
## the food has been at 0 with a negative rate this long.
const NO_BUILDER_DELAY := 5.0
const FOOD_SHORTAGE_DELAY := 5.0

const BUILDER_REST := 3.0
## Tearing down a placed building (not huts): a builder takes this share of
## its build time, and this share of the building material spent on it
## (price plus paid upgrades, rounded down) comes back.
const TEARDOWN_TIME_SHARE := 0.5
const TEARDOWN_REFUND := 0.33
const FARMER_REST := 4.0
const HARVEST_TIME := 2.5
const FARM_RATE := 0.4  # food per second while a farmer is assigned
const FARM_WATER_BONUS := 0.1  # a farm next to water (meadow: ZONES.meadow.farm_bonus)
const FARM_CAPACITY := 40.0
const EXPLORER_REVEAL := 2.6
const EVADE_RADIUS := 4.5  # civilians run home when an enemy gets this close
## A villager (or the hero) fleeing from a monster camp's guards uncovers the
## camp this far round its tile (Civilian._reveal_camps), so it can be attacked.
const CAMP_REVEAL := 1.5
const EVADE_REST := 6.0
const FORESTER_CHOP_SESSION := 4.0  # seconds of chopping per trip
const FORESTER_REST := 3.0  # rest at the camp between trips
const FORESTER_MATERIAL_PER_TRIP := 3  # paid every time the forester is back at camp
const FORESTER_SEARCH_RADIUS := 10.0  # trees farther than this from the camp are ignored
## Total chopping time (seconds) before a tree falls and its tile turns to
## meadow, per tree art/flavour.
const TREE_CHOP_TIME := {"tree_pine_0": 20.0, "tree_pine_1": 28.0, "tree_oak": 36.0, "tree_dead": 10.0, "stump_charred": 8.0}
const GATHERER_CAPACITY := 6  # corpses carried per trip
const GATHERER_LOOT_TIME := 1.0  # seconds per corpse
const GATHERER_REST := 3.0
## A corpse is "safe" when no living enemy is this close to it.
const CORPSE_SAFE_RADIUS := 6.0
const CORPSE_LIFETIME := 240.0  # seconds before an uncollected corpse rots away
## An explorer abandons its local frontier when that target is this much farther
## from the village than the closest unexplored tile to the village.
const EXPLORER_WANDER_FACTOR := 1.6
const EXPLORER_WANDER_SLACK := 8
const EXPLORER_CLAIM_RADIUS := 7.0
const EXPLORER_CLAIM_PENALTY := 30
## A scout (explorer, the hero exploring) that fled from a monster camp's guards
## on its way to some fog sets that fog aside, and all fog this close to it,
## while those guards live: the way there runs past them (ExploreJob).
const EXPLORER_BLOCKED_RADIUS := 4.0

## --- Military (docs/military-design.md) ------------------------------------------------
## Every unit goes up to MAX_UNIT_LEVEL. Stats are given for level 1 and level 10
## ("stats": key -> [level 1, level 10]); levels in between follow the curve
## (t = 0 at level 1 .. 1 at level 10, value = a + (b - a) * t^curve; "curve"
## for all of a unit's stats, "curves": stat -> its own exponent).
## "upgrade_cost" / "train_xp": gold / hero XP to reach level 2 and level 10
## (along the same curve), "branch_cost": gold to turn into this specialisation.
## A specialisation's level 1 is never weaker than its base unit's level 3
## (where it branches: HP, DPS, summons), and its level 10 is stronger than
## the base unit's level 10 (tests/military_bot.gd).
## Roles: "ranged" (towers or barracks; own "range" in the field, never upgraded,
## always below the smallest tower range), "melee" (barracks only), "summoner"
## (summons elementals; no attack of its own), "healer" (heals allies around it),
## "support" (High Priest: an aura, see docs/acolyte-design.md).
## Optional: "glow" (a soft pulsing light behind the figure: its colour),
## "cast_art" (sprite shown for a moment on every attack), "hunt" (melee
## target priorities, see "inquisitor"), "aura" stat and "necro_slow" (see
## "high_priest"), "range" on a melee unit (its reach, else UNIT_MELEE_RANGE),
## "hits_flyers" (a melee unit that can go for flyers), "vs_mounted" (its
## damage factor against a mount, never the rider: docs/enemies-design.md
## §15e) and "breaks_charge" (a charge on it gives no bonus; its blow halts a
## mount for MOUNTED halt_time s and spends its charge), the war cry (see
## "warrior") and rage and lifesteal (see "berserker").
const MAX_UNIT_LEVEL := 10
## From this level a base unit can also turn into level 1 of a specialisation.
const BRANCH_MIN_LEVEL := 3
## A spatial mage of this level can become the Spatial Archmage (a civilian).
const ARCHMAGE_LEVEL := 10
const ARCHMAGE_COST := {"gold": 600}
## Seconds a downed unit needs to come back: level 1 / level 10 (linear between).
const UNIT_REVIVE_TIME := [30.0, 45.0]
## HP per second a unit heals on a barracks bench, or unused in the reserve.
const UNIT_REGEN := 1.0
## Field combat (barracks sorties): melee reach, and how far beyond the
## barracks' range units chase before turning back.
const UNIT_MELEE_RANGE := 0.8
const SORTIE_LEASH := 2.0

const MILITARY := {
	"archer": {
		"name": "Archer", "role": "ranged", "posts": ["tower", "barracks"], "recruit": true,
		"cost": {"gold": 40}, "speed": 1.8, "attack": "arrow", "range": 2.6,
		"desc": "Shoots arrows, from a tower or out of the barracks.",
		"stats": {"hp": [30.0, 90.0], "damage": [7.0, 40.0], "cooldown": [1.0, 0.45]},
		"upgrade_cost": [45, 300], "train_xp": [30, 400],
		"branches": ["crossbowman", "swiftbowman"],
	},
	"crossbowman": {
		"name": "Crossbowman", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "archer", "branch_cost": {"gold": 100},
		"speed": 1.6, "attack": "bolt", "range": 3.2, "pierce": true,  # (piercing: for shielded enemies, later)
		"desc": "Slow, heavy crossbow bolts; reaches further than an archer in the field.",
		"stats": {"hp": [44.0, 100.0], "damage": [50.0, 170.0], "cooldown": [2.25, 1.7]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"swiftbowman": {
		"name": "Swiftbowman", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "archer", "branch_cost": {"gold": 100},
		"speed": 2.0, "attack": "swift_arrow", "range": 2.6,
		"desc": "A hail of light arrows: tiny hits, very fast.",
		"stats": {"hp": [44.0, 95.0], "damage": [7.5, 18.0], "cooldown": [0.3, 0.18]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"shield_bearer": {
		"name": "Shield Bearer", "role": "melee", "posts": ["barracks"], "recruit": true,
		"cost": {"gold": 50}, "speed": 1.3, "attack": "strike",
		"desc": "Barracks only. Huge shield, lots of HP, little damage: holds enemies up.",
		"stats": {"hp": [55.0, 180.0], "damage": [3.0, 12.0], "cooldown": [1.2, 0.9]},
		"upgrade_cost": [40, 250], "train_xp": [30, 350],
		"branches": ["warrior", "berserker", "halberdier"],
	},
	# War cry: out on a sortie, at once and then every cry_interval s, every ally
	# within cry_radius tiles (units out, tower units, summons, heroes, himself)
	# is hasted by "cry" for "cry_time" s: all its attack, summon and heal timers
	# run 1 + cry times as fast. One haste per unit, never stacked: an equal or
	# stronger cry refills it, a weaker one counts once it has run out.
	"warrior": {
		"name": "Warrior", "role": "melee", "posts": ["barracks"], "recruit": false,
		"branch_of": "shield_bearer", "branch_cost": {"gold": 100},
		"speed": 1.4, "attack": "strike", "cry_interval": 10.0, "cry_radius": 2.5,
		"desc": "Barracks only. Mail, shield and sword, the most HP of all; his war cry makes allies near him attack faster.",
		"stats": {"hp": [90.0, 300.0], "damage": [6.0, 30.0], "cooldown": [1.15, 0.85], "cry": [0.1, 0.5], "cry_time": [3.0, 5.0]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	# Rage: his strike interval x (1 - rage x share of HP missing). Lifesteal:
	# while below lifesteal_below of his max HP, he gets back "lifesteal" x the
	# HP his blows really take (never above his max).
	"berserker": {
		"name": "Berserker", "role": "melee", "posts": ["barracks"], "recruit": false,
		"branch_of": "shield_bearer", "branch_cost": {"gold": 100},
		"speed": 1.6, "attack": "strike", "lifesteal_below": 0.5,
		"desc": "Barracks only. A great axe and no armour: the more HP he has lost, the faster he strikes, and when low he heals from his blows.",
		"stats": {"hp": [85.0, 200.0], "damage": [8.0, 71.0], "cooldown": [1.15, 0.8], "rage": [0.3, 0.8], "lifesteal": [0.1, 0.25]},
		"curves": {"lifesteal": 1.5},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"halberdier": {
		"name": "Halberdier", "role": "melee", "posts": ["barracks"], "recruit": false,
		"branch_of": "shield_bearer", "branch_cost": {"gold": 100},
		"speed": 1.3, "attack": "strike", "range": 1.2, "hits_flyers": true,
		"vs_mounted": 2.5, "breaks_charge": true,
		"desc": "Barracks only. A long halberd reaches farther than other blades, up to flyers, and is the bane of riders.",
		"stats": {"hp": [85.0, 200.0], "damage": [9.0, 76.0], "cooldown": [1.25, 0.85]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"summoner": {
		"name": "Summoner", "role": "summoner", "posts": ["tower", "barracks"], "recruit": true,
		"cost": {"gold": 60}, "speed": 1.4, "summon": "earth",
		"desc": "Summons earth elementals while enemies are near. Fragile, no attack of its own.",
		"stats": {"hp": [18.0, 50.0], "interval": [6.0, 2.5], "max_summons": [2.0, 8.0], "summon_hp": [20.0, 90.0], "summon_damage": [4.0, 18.0]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
		"branches": ["fire_summoner", "druid"],
	},
	"fire_summoner": {
		"name": "Fire Summoner", "role": "summoner", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "summoner", "branch_cost": {"gold": 100},
		"speed": 1.4, "summon": "fire",
		"desc": "Summons fire elementals: quick and deadly, but they burn themselves up.",
		"stats": {"hp": [26.0, 55.0], "interval": [3.9, 2.5], "max_summons": [4.0, 8.0], "summon_hp": [36.0, 95.0], "summon_damage": [7.5, 20.0]},
		"upgrade_cost": [70, 300], "train_xp": [45, 400],
	},
	"apprentice": {
		"name": "Apprentice", "role": "ranged", "posts": ["tower", "barracks"], "recruit": true,
		"cost": {"gold": 55}, "speed": 1.6, "attack": "orb", "range": 2.8,
		"desc": "A young mage: whirling dark-blue orbs. Grows into a specialised mage.",
		"stats": {"hp": [20.0, 60.0], "damage": [8.0, 40.0], "cooldown": [1.0, 0.55]},
		"upgrade_cost": [50, 300], "train_xp": [35, 400],
		"branches": ["fire_mage", "ice_mage", "healing_mage", "spatial_mage"],
	},
	"fire_mage": {
		"name": "Fire Mage", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "fireball", "range": 2.8,
		"desc": "Fireballs that explode: an apprentice's damage, splashed over whole groups.",
		"stats": {"hp": [29.0, 65.0], "damage": [16.0, 42.0], "cooldown": [0.95, 0.55], "splash": [1.2, 1.8]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"ice_mage": {
		"name": "Ice Mage", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "frost", "range": 2.8,
		"desc": "Frost orbs: a bit more damage, and the enemy hit is slowed for a while.",
		"stats": {"hp": [29.0, 65.0], "damage": [16.0, 44.0], "cooldown": [0.95, 0.55], "slow": [0.7, 0.4], "slow_time": [2.0, 3.5]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"healing_mage": {
		"name": "Healing Mage", "role": "healer", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "heal",
		"desc": "No damage. Heals every allied unit and hero around it (not summons): in a tower as far as the tower reaches, elsewhere within its own radius.",
		"stats": {"hp": [29.0, 65.0], "heal": [6.0, 30.0], "cooldown": [3.0, 1.4], "radius": [2.5, 3.5]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"spatial_mage": {
		"name": "Spatial Mage", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "warp", "range": 2.8,
		"desc": "An apprentice's damage, and the enemy hit is thrown back along its road. At level %d it can become the Spatial Archmage." % ARCHMAGE_LEVEL,
		"stats": {"hp": [29.0, 65.0], "damage": [16.0, 42.0], "cooldown": [0.95, 0.55], "push": [1.5, 4.0]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
		"archmage": true,
	},
	"acolyte": {
		"name": "Acolyte", "role": "ranged", "posts": ["tower", "barracks"], "recruit": true,
		"cost": {"gold": 50}, "speed": 1.7, "attack": "holy_beam", "range": 1.6,
		"glow": "#ffe9a0", "cast_art": "unit_acolyte_cast",
		"desc": "Prays, and a beam of holy light falls on the enemy from above. Short reach out of the barracks; holy damage hurts the undead most.",
		"stats": {"hp": [30.0, 90.0], "damage": [6.5, 36.0], "cooldown": [1.0, 0.48]},
		"upgrade_cost": [50, 300], "train_xp": [35, 400],
		"branches": ["inquisitor", "high_priest"],
	},
	# Holy melee. Target: the lowest "effective distance" (real distance minus
	# the bonus of the enemy's class) among enemies within the barracks' reach;
	# a class's enemies farther than its max are ignored. Classes: "witch"
	# (the witch), "unholy" (ENEMIES "unholy", or raised). It drops its fight
	# only for an enemy at least hunt_switch tiles better.
	"inquisitor": {
		"name": "Inquisitor", "role": "melee", "posts": ["barracks"], "recruit": false,
		"branch_of": "acolyte", "branch_cost": {"gold": 100},
		"speed": 1.6, "attack": "smite",
		"hunt": {"witch": {"bonus": 4.0, "max": 7.0}, "unholy": {"bonus": 2.0, "max": 5.0}}, "hunt_switch": 1.0,
		"desc": "Holy cross and warhammer. Hunts witches first, then the undead, then anything else. Barracks only.",
		"stats": {"hp": [45.0, 140.0], "damage": [17.0, 57.0], "cooldown": [1.1, 0.75]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	# No attack: a weak melee counter-strike (damage / cooldown) when hit in
	# melee. Aura: allies within reach (on a tower the tower's range, out of
	# the barracks on a sortie its own "range") deal +aura x damage (the
	# strongest aura counts, never stacked); necromancers in it, or raising a
	# corpse in it, take necro_slow x as long.
	"high_priest": {
		"name": "High Priest", "role": "support", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "acolyte", "branch_cost": {"gold": 100},
		"speed": 1.5, "attack": "strike", "range": 2.6, "glow": "#fff2c0", "necro_slow": 2.0,
		"desc": "Blesses every ally around it: more damage for units, towers, the hero and summons. Necromancers raise slower near it.",
		"stats": {"hp": [44.0, 95.0], "aura": [0.02, 0.2], "damage": [3.0, 10.0], "cooldown": [1.4, 1.0]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	# The summoner's plant branch (docs/military-design.md §3b): thornlings,
	# slow and sturdy, whose every blow roots the enemy in place for "root"
	# seconds (then it is immune for a while: SUMMONS.thorn.root_immunity).
	# Scenario 7's grove druids are druids that take no orders
	# (MilitaryUnit.bound).
	"druid": {
		"name": "Druid", "role": "summoner", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "summoner", "branch_cost": {"gold": 100},
		"speed": 1.3, "summon": "thorn",
		"desc": "Calls up thornlings: slow and tough, and every blow roots the enemy in place for a moment.",
		"stats": {"hp": [26.0, 56.0], "interval": [5.0, 2.5], "max_summons": [3.0, 8.0], "summon_hp": [36.0, 100.0], "summon_damage": [7.2, 23.0], "root": [0.6, 1.2]},
		"upgrade_cost": [70, 300], "train_xp": [45, 400],
	},
}
## Recruitable units in the Army tab (specialisations come from upgrades).
const MILITARY_ORDER: Array[String] = ["archer", "shield_bearer", "summoner", "apprentice", "acolyte"]
## Kinds in tech-tree order (base unit, then its specialisations).
const MILITARY_TREE: Array[String] = ["archer", "crossbowman", "swiftbowman", "shield_bearer", "warrior", "berserker", "halberdier", "summoner", "fire_summoner", "druid", "apprentice", "fire_mage", "ice_mage", "healing_mage", "spatial_mage", "acolyte", "inquisitor", "high_priest"]

## What a unit's attack looks like and does. "projectile": art of the shot
## ("" = no shot); "whirl": the shot spins; "arc": arrows fly on an arc.
## Effects: "splash" (damage to others within the unit's "splash" radius,
## times splash_share), "slow" (the unit's "slow" speed factor for "slow_time"
## s), "push" (thrown back "push" tiles along its road, once per push_immunity s),
## "heal" (heals allies within the unit's "radius"); "burst": an effect played
## on the target with every hit (Burst kinds).
const ATTACKS := {
	"arrow": {"projectile": "arrow", "arc": true, "sound": "shoot", "category": "projectile"},
	"swift_arrow": {"projectile": "swift_arrow", "arc": true, "sound": "shoot", "category": "projectile"},
	"bolt": {"projectile": "crossbow_bolt", "arc": false, "speed": 900.0, "sound": "shoot", "category": "projectile"},
	"orb": {"projectile": "arcane_orb", "whirl": true, "speed": 420.0, "sound": "hit", "category": "magical"},
	"fireball": {"projectile": "fireball", "whirl": true, "speed": 380.0, "splash_share": 0.6, "explode": true, "sound": "hit", "category": "fire"},
	"frost": {"projectile": "frost_orb", "whirl": true, "speed": 420.0, "sound": "hit", "category": "magical"},
	"warp": {"projectile": "warp_orb", "whirl": true, "speed": 460.0, "push_immunity": 4.0, "sound": "hit", "category": "magical"},
	"heal": {"projectile": "", "sound": "recruit", "category": "holy"},
	"strike": {"projectile": "", "sound": "hit", "category": "melee"},
	"holy_beam": {"projectile": "", "burst": "holy_beam", "sound": "recruit", "category": "holy"},
	"smite": {"projectile": "", "burst": "holy_flash", "sound": "hit", "category": "holy"},
}

## What kind of damage a hit does (ATTACKS "category"; enemies: "attack_category",
## melee if not given). An enemy's "resist" table scales what it takes by
## category (a vampire takes 0.67 x magical damage). The hero's sword, earth
## elementals and soldiers' strikes are melee; fireballs (and their splash)
## and fire elementals are fire, a category of its own (a wrathwood takes
## x2, water monsters x0.5). Every hit has exactly one category.
## "pure" (a raised enemy's drain, a flame burning itself up) is never scaled.
const DAMAGE_CATEGORIES: Array[String] = ["melee", "projectile", "magical", "fire", "holy", "pure"]
## The library's Damage page (Library._damage), one entry per category: its
## name, picture and a short text. Who deals it and who resists it are read
## from ATTACKS, SUMMONS, HERO and ENEMIES, so only a new category needs a line here.
const DAMAGE_INFO := {
	"melee": {"name": "Melee", "art": "unit_shield_bearer", "text": "Close combat: blades, hammers, fists, claws and teeth."},
	"projectile": {"name": "Projectile", "art": "unit_archer", "text": "Arrows and bolts."},
	"magical": {"name": "Magical", "art": "unit_apprentice", "text": "Spells: arcane orbs, frost and warp, a witch's bolt, a leviathan's water."},
	"fire": {"name": "Fire", "art": "unit_fire_mage", "text": "Fireballs and living flame. Wood burns well; what lives in the water hardly at all."},
	"holy": {"name": "Holy", "art": "unit_acolyte", "text": "The light of the acolyte line. It sears the undead."},
	"pure": {"name": "Pure", "art": "unit_necromancer", "text": "Nothing makes it stronger or weaker: a raised enemy draining away, a fire elemental burning itself up."},
}

## Summoned elementals: "hp" and "damage" multiply the summoner's summon_hp
## and summon_damage; "speed" is in tiles per second; "category": what their
## blows do (DAMAGE_CATEGORIES).
## "regen" (optional): share of its max HP it heals per second while idle
## (no target, and SUMMON.regen_delay seconds since its last blow or hurt;
## a fire elemental burns itself only with its blows, so it heals idle too).
const SUMMONS := {
	"earth": {"name": "Earth Elemental", "art": "unit_earth_elemental", "hp": 1.0, "damage": 1.0, "speed": 1.1, "self_damage": 0.0, "hover": false, "category": "melee", "regen": 0.04},
	# Fire elementals hover and flicker; they lose self_damage x the damage they deal, as HP.
	"fire": {"name": "Fire Elemental", "art": "unit_fire_elemental", "hp": 0.5, "damage": 2.5, "speed": 1.8, "self_damage": 0.25, "hover": true, "category": "fire", "regen": 0.04},
	# The druid's thornlings: slow and tough; each blow roots the enemy (the
	# druid's "root" seconds); a rooted enemy is then immune to roots for
	# root_immunity seconds. Flyers can't be rooted (nor reached).
	"thorn": {"name": "Thornling", "art": "unit_thornling", "hp": 1.5, "damage": 0.8, "speed": 0.8, "self_damage": 0.0, "hover": false, "category": "melee", "root_immunity": 2.0, "regen": 0.04},
}

## Barracks levels: benches (unit slots) and how near enemies must come before
## everyone on the benches turns out. Upgrades cost material and a builder's time.
const BARRACKS_LEVELS: Array[Dictionary] = [
	{"slots": 1, "range": 4.0},
	{"slots": 2, "range": 5.0, "cost": {"materials": 60}, "work_time": 10.0},
	{"slots": 3, "range": 6.0, "cost": {"materials": 90}, "work_time": 14.0},
]


## A unit's stat at `level` (0-based: 0 = level 1), from the curve (see MILITARY).
static func unit_stat(kind: String, key: String, level: int) -> float:
	var spec: Dictionary = MILITARY[kind]
	var ends: Array = spec["stats"][key]
	var curve: float = spec.get("curves", {}).get(key, spec.get("curve", 1.0))
	return _curve(ends[0], ends[1], clampi(level, 0, MAX_UNIT_LEVEL - 1), MAX_UNIT_LEVEL, curve)


## Gold to go from `level` to the next one (0-based), or {} at the top.
static func unit_upgrade_cost(kind: String, level: int) -> Dictionary:
	if level >= MAX_UNIT_LEVEL - 1:
		return {}
	var spec: Dictionary = MILITARY[kind]
	var ends: Array = spec["upgrade_cost"]
	var v := _curve(ends[0], ends[1], level, MAX_UNIT_LEVEL - 1, spec.get("curve", 1.0))
	return {"gold": roundi(v / 5.0) * 5}


## Hero XP for the next level at the training grounds (before the difficulty factor).
static func unit_train_xp(kind: String, level: int) -> float:
	if level >= MAX_UNIT_LEVEL - 1:
		return 0.0
	var spec: Dictionary = MILITARY[kind]
	var ends: Array = spec["train_xp"]
	return roundf(_curve(ends[0], ends[1], level, MAX_UNIT_LEVEL - 1, spec.get("curve", 1.0)))


## Seconds a downed unit of `level` needs to revive.
static func unit_revive_time(level: int) -> float:
	return lerpf(UNIT_REVIVE_TIME[0], UNIT_REVIVE_TIME[1], float(clampi(level, 0, MAX_UNIT_LEVEL - 1)) / (MAX_UNIT_LEVEL - 1))


## Value `i` of `n` steps from `first` to `last` (t^curve; 1 = linear).
static func _curve(first: float, last: float, i: int, n: int, curve: float) -> float:
	if n <= 1:
		return last
	return lerpf(first, last, pow(float(i) / float(n - 1), curve))
## Training XP needed is multiplied by this per difficulty (see Settings).
const TRAIN_XP_DIFFICULTY := {"easy": 0.8, "normal": 1.0, "hard": 1.5}

## The hero: a fighter who can also do a little of every villager job.
## She has no hut, eats nothing and doesn't count as a villager.
const HERO := {
	"name": "Hero", "hp": 60.0, "speed": 1.8,
	# Train: after a unit levels up she waits this many real seconds (whatever the
	# game speed) before training on, so her mode can be changed to keep her XP.
	"train_pause": 4.0,
	"damage": 8.0, "attack_cooldown": 0.9, "attack_range": 0.8,
	"category": "melee",  # his sword's damage (DAMAGE_CATEGORIES)
	"sight": 4.0,  # surveillance while outside
	"alert_radius": 6.0,  # Defend: enemies this close to a gate draw her out
	"leash": 14.0,  # Defend: she won't chase farther than this from the centre
	"build_efficiency": 0.5,  # "a little" of each job: half a builder's speed
	"explore_reveal": 1.8,  # explorers see 2.6
	"gather_capacity": 2,  # gatherers carry 6
	"train_rate": 10.0,  # XP per second passed on at the training grounds
	"rest_regen": 3.0,  # HP per second while resting idle in the village centre
	"rest_delay": 3.0,  # seconds of idling there before the HP starts coming back
	"camp_give_up": 3.0,  # seconds with none of an ordered camp's monsters she can get to: she gives the order up
}
## XP the hero earns per action (training earns none).
## The hero spends her own XP on levels (the level-up button in her panel).
## HP and sword damage run from level 1 (HERO "hp" / "damage") to
## HERO_MAX_LEVEL; "xp_cost" is the XP from level 1 to 2 ... up to the last
## level. Being downed loses her unspent XP, never her levels.
const HERO_MAX_LEVEL := 20
const HERO_LEVELS := {"hp": [60.0, 320.0], "damage": [8.0, 64.0], "xp_cost": [50.0, 400.0]}


## A hero stat ("hp", "damage") at `level` (0-based).
static func hero_stat(key: String, level: int) -> float:
	var r: Array = HERO_LEVELS[key]
	return lerpf(r[0], r[1], float(clampi(level, 0, HERO_MAX_LEVEL - 1)) / (HERO_MAX_LEVEL - 1))


## XP to go from `level` (0-based) to the next one, or 0 at the top.
static func hero_level_cost(level: int) -> int:
	if level >= HERO_MAX_LEVEL - 1:
		return 0
	var r: Array = HERO_LEVELS["xp_cost"]
	return roundi(lerpf(r[0], r[1], float(level) / maxf(HERO_MAX_LEVEL - 2, 1)))


const HERO_XP_PER_ACTION := {
	"hit": 2,  # a melee hit in combat
	"kill": 10,  # extra, for the blow that kills the enemy (on top of its "hit")
	"build_second": 1,  # each second of construction work
	"explore": 1,  # each exploring step that uncovers new tiles
	"corpse": 4,  # each corpse picked up
	"loot": 10,  # each treasure looted (not for picking up dropped loot)
}

## What every summoned elemental shares (their own numbers are in SUMMONS).
## HP and damage come from the summoner's level; at level 1 an earth elemental
## is as strong as a Normal goblin.
const SUMMON := {
	"attack_cooldown": 1.0,
	"attack_range": 0.8,  # close combat
	"sight": 3.5,  # notices enemies this close
	"leash": 4.0,  # wanders and chases within this distance of its tower
	"regen_delay": 2.0,  # seconds after its last blow or hurt before it heals (SUMMONS "regen")
}

const MATERIALS_TRADE := {"materials": 10, "gold": 15}

## Phones: how often (seconds) the screen's safe area (a camera cutout or
## notch the UI keeps clear of, see Layout.insets) is read again.
const SAFE_AREA_POLL := 0.5

## The map view: zoom limits (1 = the art's own size; smaller sees more of the
## map) and the factor of one + / - key press (the mouse wheel uses its own).
const CAMERA_MIN_ZOOM := 0.22
const CAMERA_MAX_ZOOM := 1.6

# --- the map editor (docs/map-editor-design.md) --------------------------------------------
const EDITOR := {
	"undo_steps": 100,  # edits kept for undo
	"brush_sizes": [1, 3, 5, 9],  # brush widths (tiles)
	"min_zoom": 0.05, "max_zoom": 1.6,  # isometric view (the game: CAMERA_MIN_ZOOM)
	"plan_tile_px": 16.0,  # top-down view: pixels per tile at zoom 1
	"plan_min_zoom": 0.15, "plan_max_zoom": 6.0,
	"web_large_size": 150,  # web build: maps this big or bigger warn when opened
	"name_max": 60, "author_max": 60, "description_max": 1000, "map_type_max": 40,  # file text limits
	"library_dir": "user://maps",  # your maps
	"builtin_dir": "res://data/maps",  # maps shipped with the game
}
const CAMERA_KEY_ZOOM := 1.12

# --- enemies ------------------------------------------------------------------------
## Every enemy kind in one place. Keys (all required):
##   name, art ........ display name; sprites are unit_<art> and corpse_<art>
##   desc ............. one line for the library
##   behavior ......... what it does besides walking to a gate (scripts/units/enemies/):
##                      "melee" (fights defenders in its way and villagers in reach),
##                      "witch", "rat", "thief", "necromancer", "vampire",
##                      "spider_mother", "egg" (a spider egg),
##                      "mounted" (a rider: goblin raider, Legion cavalry), "flee" (the undead horse),
##                      "leviathan", "siren", "octopus" or "arm" (an octopus's arm)
##   hp, speed ........ hit points; tiles per second along the road
##   damage ........... close-combat damage per hit (0 = never fights in melee)
##   attack_cooldown .. seconds between melee hits
##   gold_on_kill ..... paid the moment it dies
##   gold_on_collect, food_on_collect .. paid when a gatherer brings the corpse home
##   (optional: materials_on_collect, building material, see "wrathwood")
## Behaviours may add their own keys (see "witch").
## Optional: corpse (false: none), raid_chance (of burning a hut at the gate; 1),
## raid ("maul": kills a villager in their hut instead of burning it, see "wolf"),
## plural (its name for many, "Wolves"; default: name + "s"), first (logged
## at Info when the first one of the game comes),
## pack / pack_gap (comes in packs, see "wolf"), mount and the other mounted keys (see "goblin_raider"),
## gone (the log's words when it doesn't: "melted away"),
## split_into / split_count, colors, level, hp_bar_y (see "slime3"),
## resist (damage taken by category, see DAMAGE_CATEGORIES; holy: docs/acolyte-design.md §3),
## unholy (true: the Inquisitor hunts it; everything a necromancer raises counts too),
## library (false: no library entry of its own), library_name (its name there),
## habitat, submerges and the other water keys (see "crab" and AQUA),
## revivable (false: a necromancer can't raise its corpse),
## fixed_hp (true: its hp is never scaled by difficulty or wave, see "spider_egg"),
## low_priority (true: towers and fighters go for it only when nothing else is in reach),
## scares (false: villagers don't run from it, see "spider_egg"),
## entry ("siege", the default: breaks into the village; "slip": held a while
## by an intact gate, then through it; docs/siege-design.md §5.1; "none":
## never moves, see "spider_egg"),
## siege (damage factor against walls, gates and wall towers; 0 or missing:
## it can't hurt them, waits, and slips past after SIEGE.stuck_slip).
## Any enemy that gets into the village burns the nearest intact hut, on every
## difficulty (the villager living there, if any, dies with it). Except
## rats (they eat food), thieves (they steal gold), vampire bats (they turn
## back at the gate), and kinds with a raid_chance roll for it.
## The pastel colours a slime can roll (equal chances), see "slime3".
const SLIME_COLORS: Array[String] = ["red", "blue", "yellow", "green", "pink"]
const ENEMIES := {
	"goblin": {
		"name": "Goblin", "art": "goblin", "behavior": "melee",
		"siege": 1.0,
		"desc": "The most common foe: walks the road to a gate and fights whatever blocks its way.",
		"hp": 20.0, "speed": 1.1,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 3, "gold_on_collect": 3, "food_on_collect": 2,
		"resist": {"holy": 0.75},
	},
	# Same as goblins, but bones give no food.
	"skeleton": {
		"name": "Skeleton", "art": "skeleton", "behavior": "melee",
		"siege": 1.0,
		"desc": "A goblin's strength in bones. Its corpse gives gold, but no food.",
		"hp": 20.0, "speed": 1.1,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 3, "gold_on_collect": 3, "food_on_collect": 0,
		"resist": {"holy": 1.25}, "unholy": true,
	},
	# Slower and much tougher; hits hard. Gold only on kill, lots of food as a corpse.
	"ork": {
		"name": "Ork", "art": "ork", "behavior": "melee",
		"siege": 1.0,
		"desc": "Slow and very tough, and it hits hard. A good meal as a corpse.",
		"hp": 55.0, "speed": 0.8,
		"damage": 11.0, "attack_cooldown": 1.2,
		"gold_on_kill": 6, "gold_on_collect": 0, "food_on_collect": 6,
		"resist": {"holy": 0.75},
	},
	# Slimes come in 3 levels, each its own kind: a slime that dies splits
	# into `split_count` of `split_into` (level 3 -> 2 x level 2 -> 2 x level 1
	# each); level 1 just dies. Each level has twice the HP and damage of the
	# one below. A spawned slime rolls one of `colors` (Enemy.color, sprite
	# unit_<art>_<color>); its halves keep it. No corpses, so nothing for the
	# necromancer. At the gate a big slime burns a hut like any enemy; the
	# smaller ones only with `raid_chance`, else they just melt away.
	"slime3": {
		"name": "Big slime", "art": "slime3", "behavior": "melee", "corpse": false, "level": 3,
		"siege": 1.0,
		"desc": "Slain, it splits into two smaller slimes, and each of those into two more.",
		"library_name": "Slime",
		"hp": 40.0, "speed": 0.8,
		"damage": 11.0, "attack_cooldown": 1.2,
		"gold_on_kill": 3, "gold_on_collect": 0, "food_on_collect": 0,
		"split_into": "slime2", "split_count": 2,
		"colors": SLIME_COLORS, "hp_bar_y": -33.0,
	},
	"slime2": {
		"name": "Slime", "art": "slime2", "behavior": "melee", "corpse": false, "level": 2, "raid_chance": 0.25, "library": false,
		"siege": 1.0,
		"desc": "Half of a big slime. Slain, it splits into two small slimes. In the village, it burns a hut only half of the time.",
		"hp": 20.0, "speed": 1.1,
		"damage": 5.5, "attack_cooldown": 1.2,
		"gold_on_kill": 2, "gold_on_collect": 0, "food_on_collect": 0,
		"split_into": "slime1", "split_count": 2,
		"colors": SLIME_COLORS, "hp_bar_y": -25.0,
	},
	"slime1": {
		"name": "Small slime", "art": "slime1", "behavior": "melee", "corpse": false, "level": 1, "raid_chance": 0.1, "library": false,
		"siege": 1.0,
		"desc": "The smallest and quickest slime. It just dies. In the village, it burns a hut only a quarter of the time.",
		"hp": 10.0, "speed": 1.4,
		"damage": 2.75, "attack_cooldown": 1.2,
		"gold_on_kill": 1, "gold_on_collect": 0, "food_on_collect": 0,
		"colors": SLIME_COLORS, "hp_bar_y": -19.0,
	},
	# Fragile spell-caster: no melee. Stops at manned towers in range and
	# enchants their unit (it stops shooting/summoning for a while). Spells hurt
	# earth elementals. Whoever attacks her becomes her first target.
	"witch": {
		"name": "Witch", "art": "witch", "behavior": "witch", "attack_category": "magical",
		"siege": 1.0,
		"desc": "No close combat: she stops at manned towers in range and bewitches their unit, which then stops shooting for a moment.",
		"hp": 12.0, "speed": 1.0,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 12, "gold_on_collect": 0, "food_on_collect": 1,
		"spell_range": 3.6,  # tiles: no farther than a level 1 watchtower shoots (TOWER_RANGE)
		"spell_cooldown": 2.0,
		"enchant_ratio": 0.45,  # a bewitched unit stops for 45 % of her spell cooldown (0.9 s)
		"spell_damage": 5.0,  # to elementals, the hero, units and villagers outside (tower units take none)
		"spell_speed": 5.0,  # tiles per second of the pink bolt
		# After this many casts at the same target she ignores it, unless that
		# target attacks her again (which resets its count). Stops endless stalls.
		"spell_ignore_after": 20,
	},
	# Rats come in packs (RAT_PACKS), faster than anything, frail but growing
	# with the waves like the rest. They don't burn huts: they go for farms.
	# On the road they look out for a farm within farm_search; there they eat
	# (the farm grows nothing, and each rat eats farm_eat stored food per
	# second) and wander about the field. Villagers and units within
	# bite_range get bitten (very little damage). A rat that got through a gate
	# eats max(gate_eat, gate_eat_share x the village's food) and is gone. A rat
	# on a farm vanishes after vanish_after seconds without being attacked (no
	# corpse, no gold); left over when the rest of the wave is gone, they all
	# vanish within RAT_WAVE_LINGER seconds. Killed: a little gold, no corpse.
	"rat": {
		"name": "Rat", "art": "rat", "behavior": "rat", "corpse": false,
		"entry": "slip",
		"desc": "Comes in fast packs and goes for the farms, eating their food. Rats that get through a gate eat from the stores.",
		"hp": 7.0, "speed": 2.4,
		"damage": 0.6, "attack_cooldown": 0.8,
		"gold_on_kill": 1, "gold_on_collect": 0, "food_on_collect": 0,
		"farm_search": 6.0, "bite_range": 2.5,
		"farm_eat": 0.2, "gate_eat": 5, "gate_eat_share": 0.05,
		"vanish_after": 30.0,
		# An empty farm that grew nothing for give_up_after s: every
		# give_up_check s each rat on it gives it up for good with give_up_chance.
		"give_up_after": 15.0, "give_up_check": 1.0, "give_up_chance": 0.5,
	},
	# A goblin's strength, quicker on its feet. At a gate it burns nothing: it
	# steals max(a random whole number from wave to 2 x wave, steal_share of
	# the gold), never more than there is, and runs back to where it came
	# from. Killed with the loot, its corpse holds the stolen gold as well.
	"thief": {
		"name": "Thief", "art": "thief", "behavior": "thief",
		"entry": "slip",
		"desc": "Quick on its feet. At a gate it burns nothing: it steals gold and runs back. Kill it to get the gold back.",
		"hp": 20.0, "speed": 1.5,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 2, "gold_on_collect": 3, "food_on_collect": 0,
		"steal_share": 0.04,
		"resist": {"holy": 0.75},
	},
	# The first flyer: it keeps to the roads, but no ground slows it (swamps,
	# fords). Fights like a goblin. Only ranged attacks (towers, archers,
	# mages) and fire elementals (flyers too) can go for it; ground melee
	# units (the hero, shield bearers, earth elementals) only hit back when it
	# hits them and their own blow is ready (a counter-strike).
	"gargoyle": {
		"name": "Gargoyle", "art": "gargoyle", "behavior": "melee", "flying": true,
		"siege": 1.0,
		"desc": "Flies along the roads: only ranged attacks and fire elementals can go for it.",
		"hp": 40.0, "speed": 0.8,
		"damage": 7.0, "attack_cooldown": 1.2,
		"gold_on_kill": 8, "gold_on_collect": 0, "food_on_collect": 4,
		"resist": {"holy": 0.75},
	},
	# No attack: it raises the dead. When a corpse of another enemy lies within
	# raise_range it stops and channels on it for cast_time seconds; then the
	# corpse rises again as its old kind with raise_hp of its max HP, which
	# drains to 0 over raise_decay seconds. After a raise it walks for at least
	# cast_time before the next one. Killed, a raised enemy pays raise_gold of
	# its kind's kill gold (rounded down); decayed, nothing. A raised enemy's
	# corpse, and a necromancer's own, can never be raised.
	"necromancer": {
		"name": "Necromancer", "art": "necromancer", "behavior": "necromancer", "revivable": false,
		"siege": 0.0,
		"desc": "No attack: it stops by the corpses of other enemies and raises them again for a while.",
		"hp": 20.0, "speed": 0.95,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 25, "gold_on_collect": 0, "food_on_collect": 0,
		"cast_time": 5.0, "raise_range": 3.0, "raise_hp": 0.5, "raise_decay": 20.0, "raise_gold": 0.5,
		"resist": {"holy": 1.5}, "unholy": true,  # holy damage hurts it more
		"raised_holy": 2.0,  # what it raises takes 2 x holy damage (on top of its kind's own factor)
	},
	# Slower than a goblin, twice its HP, a goblin's blows. Takes resist x the
	# damage of a category (magic: 0.67). Of the HP it really takes from
	# whatever it hits it gets `drain` back (never over its max). Once, the
	# moment its HP would drop below bat_below of its max (even to 0: it is
	# never killed in one blow), it keeps that much HP and turns into a bat
	# for bat_time s: it flies (only ranged attacks and fire elementals reach
	# it) over every ground unit, at bat_speed, and can't attack. A bat that
	# reaches a gate does no harm: it gains bat_gate_heal of its max HP (never
	# over its max) and flies back the way it came. Landed, it walks to the
	# village again as a vampire. (Flying allied units, if they ever come,
	# would be the bat's to fight.)
	"vampire": {
		"name": "Vampire", "art": "vampire", "behavior": "vampire",
		"siege": 1.0,
		"desc": "Drains life with its bites. Almost beaten, it turns into a bat once and flies away to heal.",
		"hp": 40.0, "speed": 0.9,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 6, "gold_on_collect": 8, "food_on_collect": 0,
		"resist": {"magical": 0.67, "fire": 0.67, "holy": 1.5}, "unholy": true,
		"drain": 0.67,
		"bat_below": 0.33, "bat_time": 10.0, "bat_speed": 1.8, "bat_gate_heal": 0.33,
	},
	# --- spiders (Wilderness; docs/enemies-design.md §15b) ---
	# A huge, slow spider that fights like an ork and lays eggs (`lays`, a kind
	# of its own): a clutch of clutch[0]..clutch[1] eggs around her
	# (lay_spread tiles) as she walks, without stopping: the first once she is
	# within lay_near tiles of a manned tower or barracks of ours whose units
	# fight (lay_near: a little more than a level 3 wall tower's range,
	# TOWER_RANGE + TOWER_LEVELS: 6.4), or when she is first alarmed; then
	# every lay_every s. She lays at most max_clutches clutches (timed and
	# alarmed together; raised, she counts afresh); then she just fights.
	# Alarmed (one of ours who fights within alarm_range, or a manned tower
	# with her in range, or she is hurt) while fewer than guard_count of her
	# spiderlings and eggs are within guard_radius, she stops, lays a clutch
	# and waits until it has hatched (or is gone), still fighting whoever
	# comes close; then not again for alarm_cooldown s. Raised by a
	# necromancer she lays too, at once when she rises and then every
	# lay_every s (she drains away in the necromancer's raise_decay):
	# those eggs and their spiderlings are undead (unholy, raised_holy x holy
	# damage), but they don't drain away. Laying takes no time.
	"spider_mother": {
		"name": "Spider mother", "art": "spider_mother", "behavior": "spider_mother",
		"siege": 1.0,
		"desc": "A huge, slow spider. Now and then she lays a clutch of eggs; threatened while few of her young are around her, she stops and lays more, and waits for them to hatch.",
		"hp": 90.0, "speed": 0.6,
		"damage": 9.0, "attack_cooldown": 1.3,
		"gold_on_kill": 10, "gold_on_collect": 8, "food_on_collect": 0,
		"resist": {"holy": 0.75},
		"hp_bar_y": -50.0,
		"lays": "spider_egg", "clutch": [4, 6], "lay_spread": 0.6, "lay_near": 7.0, "lay_every": 15.0, "max_clutches": 5,
		"alarm_range": 4.0, "guard_radius": 2.5, "guard_count": 3, "alarm_cooldown": 12.0,
	},
	# One egg of a clutch: always 1 HP (fixed_hp: no difficulty or wave
	# scaling), never moves. After hatch_time s it hatches into `hatch_into`
	# (as strong as its mother's wave); it wobbles for the last wobble_time s.
	# The broken shell stays shell_time s (nothing can hit it). Towers and
	# fighters go for eggs only when no other enemy is in reach
	# (low_priority). Villagers don't run from eggs (scares false), only from
	# what hatches. It counts for the wave; hatching or killed, no corpse.
	"spider_egg": {
		"name": "Spider egg", "art": "spider_egg", "behavior": "egg", "corpse": false, "library": false,
		"entry": "none", "fixed_hp": true, "low_priority": true, "scares": false,
		"desc": "A spider mother's egg. Smash it before it hatches.",
		"hp": 1.0, "speed": 0.0,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 0, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"holy": 0.75},
		"hp_bar_y": -18.0,
		"hatch_into": "spiderling", "hatch_time": 6.0, "wobble_time": 2.5, "shell_time": 4.0,
	},
	# Hatched from a spider mother's egg: about a rat's strength, fights like
	# a goblin and breaks walls and gates, but burns no huts (raid_chance 0:
	# inside the walls it scuttles off).
	"spiderling": {
		"name": "Spiderling", "art": "spiderling", "behavior": "melee", "corpse": false, "raid_chance": 0.0, "gone": "scuttled off",
		"siege": 1.0,
		"desc": "Hatched from a spider mother's eggs. Weak and quick; it gnaws at gates and walls, but burns no huts.",
		"hp": 8.0, "speed": 1.8,
		"damage": 1.5, "attack_cooldown": 1.0,
		"gold_on_kill": 1, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"holy": 0.75},
		"hp_bar_y": -20.0,
	},
	# --- the wrathwood (Wilderness; docs/enemies-design.md §15c) ---
	# Never in a wave: a tree a forester starts on may wake up as one
	# (WRATHWOOD). It walks over forest too (Pathing.wood_path), never takes
	# a road or breaks into a village (entry "none"). After its forester
	# (chase), then his worker camp, then it wanders wander_time s within
	# wander_radius, walks home to its old tile and guards it for good:
	# anyone of ours within territory tiles is attacked, chased no farther
	# than leash tiles from home. Whoever hurts it is its foe (while
	# wandering, going home or guarding; within leash). In every state but
	# guarding, a ready blow goes at what is within reach as it passes
	# (its target first, then one of ours, then a building that isn't a hut),
	# without stopping. Blows on buildings do damage x siege.
	# Within regrow_radius of a tree it heals regrow x its max HP per s, x
	# home_boost for home_boost_time s once back home. Root grip: every
	# grip_every s (the first that long after waking), with one of ours on
	# the ground within grip_radius, it stops grip_cast s and holds them all
	# in place for grip_time s (they still fight). It wakes over wake_time s
	# (still looking like its tree; it can be hit). Its corpse is a log of
	# living wood: materials_on_collect building material, nothing else.
	"wrathwood": {
		"name": "Wrathwood", "art": "wrathwood", "behavior": "wrathwood", "revivable": false,
		"entry": "none", "siege": 3.0,
		"desc": "A tree that woke up under a forester's axe. It goes after him, then smashes his camp, and guards its old spot for good. Fire hurts it twice as much; arrows barely scratch it.",
		"hp": 220.0, "speed": 0.45,
		"damage": 22.0, "attack_cooldown": 2.5,
		"gold_on_kill": 35, "gold_on_collect": 0, "food_on_collect": 0, "materials_on_collect": 40,
		"resist": {"projectile": 0.5, "fire": 2.0, "holy": 0.75},
		"hp_bar_y": -84.0,
		"wake_time": 3.0, "reach": 1.0,
		"regrow": 0.04, "regrow_radius": 2.5, "home_boost": 2.0, "home_boost_time": 10.0,
		"wander_time": 20.0, "wander_radius": 3.0, "territory": 4.0, "leash": 6.0,
		"grip_every": 8.0, "grip_radius": 1.6, "grip_cast": 0.6, "grip_time": 2.0,
	},
	# Carrion birds (Wilderness, animals; docs/enemies-design.md §15d): in packs
	# for the corpses left lying (VULTURES: how many, eating, leaving). It flies
	# its own way (`own_way`: no road; Pathing.sky_path) and lands to eat
	# (`landed_art` while on the ground: melee can hit it then). It fights only
	# for itself and its corpse; hurt by a tower it flees. Never at a gate.
	# Each meal makes it stronger (VULTURES grow / max_meals).
	"vulture": {
		"name": "Vulture", "art": "vulture", "behavior": "vulture", "flying": true, "own_way": true,
		"landed_art": "vulture_landed", "entry": "none", "siege": 0.0,
		"desc": "Carrion birds that come for the dead left on the field. Every corpse they eat is loot lost, and each meal makes them stronger. They leave once nothing is left to eat.",
		"hp": 18.0, "speed": 1.6,
		"damage": 3.0, "attack_cooldown": 1.0,
		"gold_on_kill": 2, "gold_on_collect": 0, "food_on_collect": 3,
		"resist": {"projectile": 1.25, "fire": 1.25, "holy": 0.75},
	},
	# --- water monsters (docs/aquatic-design.md; the shared rules are in AQUA) ---
	# Every kind has a "habitat": "land" (the default), "amphibian" (roads and
	# water: deep, shallow, fords, bridges; it leaves the water only onto a
	# road) or "water" (deep water only). "submerges": it can dive on deep
	# tiles, and is untargetable while diving, down or surfacing.
	# "min_deep_tiles" / "min_width": the smallest water body it lives in (deep
	# tiles; widest point in tiles, a one-tile river is 1). "reach": how far
	# from its water it threatens the land (wave eligibility, AQUA).
	# A goblin that can swim: submerged while on deep water, surfaced
	# everywhere else (never by choice). Fights like a goblin.
	"crab": {
		"name": "Crab", "art": "crab", "behavior": "melee",
		"siege": 1.0,
		"desc": "A goblin that swims: it comes up rivers and lakes, out of sight under deep water, and climbs out onto the roads.",
		"hp": 20.0, "speed": 1.1,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 3, "gold_on_collect": 3, "food_on_collect": 2,
		"resist": {"fire": 0.5},
		"habitat": "amphibian", "submerges": true, "auto_submerge": true,
		"min_deep_tiles": 6, "min_width": 1, "reach": 2.0,
	},
	# A sea serpent that never leaves deep water and never moves while up. It
	# lurks submerged (swim speed "speed"), surfaces near our people for
	# surface_min..surface_max s and channels a water blast (blast_windup s,
	# then spell_damage per s for blast_time s, magical) at someone within
	# blast_range: villagers, units and the hero outside, elementals; never a
	# tower's unit, nobody inside the walls. A blast every blast_cooldown s.
	# Losing flee_share of its max HP in one surfacing makes it dive early;
	# then it stays up at least flee_min_up s the next time. It moves on at
	# least move_on tiles after each dive. With nobody to blast it still comes
	# up every idle_surface s at the deep tile nearest the village.
	"leviathan": {
		"name": "Leviathan", "art": "leviathan", "behavior": "leviathan", "attack_category": "magical", "revivable": false,
		"desc": "A sea serpent of the deep. It surfaces near the shore and blasts whoever is out there with a column of water, then dives and moves on.",
		"hp": 220.0, "speed": 1.3,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 40, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"fire": 0.5},
		"habitat": "water", "submerges": true,
		"min_deep_tiles": 30, "min_width": 2, "reach": 5.6,
		"blast_range": 4.6,  # below a level 3 watchtower's reach (5.2), above a level 2's (4.4)
		"spell_damage": 6.0, "blast_windup": 0.8, "blast_time": 4.0, "blast_cooldown": 8.0,
		"surface_min": 5.0, "surface_max": 9.0, "idle_surface": 20.0,
		"flee_share": 0.25, "flee_min_up": 3.0, "move_on": 6.0,
	},
	# A support monster: she keeps hold_range from the nearest of ours (a
	# unit, building or villager) and sings (song_radius). At distance d her
	# song's strength is s = 1 - d / song_radius: mobile units of ours (the
	# hero, soldiers on a sortie, elementals, villagers outside) are pulled
	# towards her at song_pull x s tiles/s (never into deep water), and every
	# unit's attack, cast, summon and heal timers run 1 - song_slow x s as
	# fast (tower units too). A High Priest's aura makes a unit immune. Melee
	# can't touch her while she stands in water (deep or shallow, a ford;
	# a bridge is land), except from inside a High Priest's aura. After
	# patience s without luring anyone, or max_hold s of holding in all
	# (luring or not: our people passing by can't keep her there for good),
	# she walks to the gate and stops for nothing. Submerged while
	# travelling in deep water; up when one of ours is within song_radius;
	# dives for dive_time s after losing dive_loss of her max HP within
	# dive_window s.
	"siren": {
		"name": "Siren", "art": "siren", "behavior": "siren",
		"siege": 0.0,
		"desc": "She sings from the water: our people are drawn towards her and fight slower. Melee can't reach her in the water, unless a High Priest blesses them.",
		"hp": 24.0, "speed": 0.9,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 14, "gold_on_collect": 0, "food_on_collect": 1,
		"resist": {"melee": 1.5, "magical": 0.67, "fire": 0.5},
		"habitat": "amphibian", "submerges": true,
		"min_deep_tiles": 6, "min_width": 1, "reach": 5.5,
		"song_radius": 4.5, "song_pull": 0.9, "song_slow": 0.6,
		"hold_range": 4.0, "patience": 30.0, "max_hold": 60.0,
		"dive_loss": 0.3, "dive_window": 6.0, "dive_time": 5.0,
		"melee_proof_in_water": true,
	},
	# The strongest water monster, rare (WAVE_MIX: chance, max_count). Never
	# leaves deep water; moves at "speed" towards our people (else to the deep
	# tile nearest the village). Its `arms` arms each reach arm_range, one
	# target each (never two on one): villagers outside, the hero, soldiers on
	# a sortie, elementals. A hooked unit is pulled towards it at arm_pull
	# tiles/s (into deep water too: it drowns; the hero is downed; flyers
	# don't drown) and takes spell_damage per s; it fights the arm, which is
	# a target of its own while reaching or holding ("octopus_arm": its HP is
	# arm_hp, scaled like enemy HP by difficulty and the wave). An arm at 0 HP
	# frees its unit and is gone for arm_respawn s. After a grapple an arm
	# waits arm_cooldown s; the arms start arm_stagger s apart. It dives
	# (arms let go) for dive_time s after losing dive_loss of its max HP
	# within dive_window s, then can't dive again for dive_lockout s.
	"octopus": {
		"name": "Gigantic octopus", "art": "octopus", "behavior": "octopus", "revivable": false,
		"desc": "Rare and huge. Its eight arms grab people near the shore and drag them into the deep. Cut an arm to free whoever it holds.",
		"hp": 1200.0, "speed": 0.5,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 250, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"fire": 0.5},
		"habitat": "water", "submerges": true, "hp_bar_y": -70.0,
		"min_deep_tiles": 80, "min_width": 3, "reach": 5.5,
		"arms": 8, "arm_range": 4.5, "arm_cooldown": 6.0, "arm_stagger": 0.75,
		"arm_reach_speed": 8.0,  # tiles per second of a reaching arm's tip
		"spell_damage": 3.0, "arm_pull": 0.6, "arm_respawn": 30.0,
		# With nobody in reach, an arm smashes a building of ours within
		# arm_range instead: arm_smash HP every smash_cooldown s (docs/siege-design.md §5.5).
		"arm_smash": 8.0, "smash_cooldown": 2.0,
		"dive_loss": 0.15, "dive_window": 6.0, "dive_time": 6.0, "dive_lockout": 20.0,
	},
	# One of the octopus's arms while it reaches or holds: a target like any
	# enemy, but not a wave member (no gold, no corpse, not counted).
	"octopus_arm": {
		"name": "Tentacle", "art": "octopus_arm", "behavior": "arm", "corpse": false, "library": false,
		"desc": "An arm of the gigantic octopus.",
		"hp": 30.0, "speed": 0.0,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 0, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"fire": 0.5},
		"habitat": "water", "hp_bar_y": -30.0,
	},
	# --- wolves and riders (docs/enemies-design.md §15e; MOUNTED) ---
	# An animal (holy x1) that hunts in packs of pack[0]..pack[1] (Waves
	# groups a wave's wolves, from one spawn, pack_gap s apart). It breaks
	# gates weakly. Through ("raid": "maul") it kills the villager of the hut
	# it got to (or of the nearest lived-in one), leaves the hut standing and
	# is gone. Its corpse is also a fallen raider's mount's. Raised: an undead wolf.
	"wolf": {
		"name": "Wolf", "plural": "Wolves", "art": "wolf", "behavior": "melee",
		"siege": 0.5, "raid": "maul",
		"desc": "Hunts in packs. Through a gate it kills a villager in their hut and is gone.",
		"hp": 13.0, "speed": 1.4,
		"damage": 4.0, "attack_cooldown": 0.8,
		"gold_on_kill": 2, "gold_on_collect": 0, "food_on_collect": 3,
		"pack": [2, 3], "pack_gap": 0.3,
		"first": "Wolves! They hunt in packs, and a wolf through the gate kills a villager in their hut.",
	},
	# A goblin on a wolf (MountedBehavior), alone. Mounted keys:
	#   mount ..... the animal it rides (an ENEMIES kind: its corpse and resist)
	#   mount_hp .. the mount's HP (scaled like hp); every hit lands on it
	#               while it lives, and none carries over to the rider
	#   rider ..... what it is once the mount falls (its hp is the rider's)
	#   hunts ..... "all" (anything of ours outside) or "melee" (melee fighters only)
	#   escort .... true: keeps near the Legion's soldiers on foot (MOUNTED)
	# speed is the mounted speed, siege its blows on walls while mounted,
	# gold_on_kill is paid when the mount falls (the rider pays its own).
	"goblin_raider": {
		"name": "Goblin Raider", "art": "goblin_raider", "behavior": "mounted", "corpse": false,
		"siege": 0.3,
		"desc": "A goblin on a wolf: fast, it rides round the village and runs down anyone outside. When the wolf falls, the goblin fights on.",
		"hp": 20.0, "speed": 1.6,
		"damage": 5.0, "attack_cooldown": 1.0,
		"gold_on_kill": 2, "gold_on_collect": 0, "food_on_collect": 0,
		"mount": "wolf", "mount_hp": 18.0, "rider": "goblin", "hunts": "all",
		"first": "A goblin raider! It rides round the village and runs down anyone outside. Halberdiers are the bane of riders.",
		"hp_bar_y": -54.0,
	},
	# There is no living horse: only a fallen mount's corpse, and raised by a
	# necromancer an undead horse (FleeBehavior) that never fights: it bolts
	# to the quietest spot within flee_search tiles (again every flee_every s)
	# and dies of the drain; an unraised one vanishes after flee_time s.
	"horse": {
		"name": "Horse", "plural": "Horses", "art": "horse", "behavior": "flee",
		"siege": 0.0, "scares": false,
		"desc": "A Legion rider's mount. Its corpse feeds a village; raised by a necromancer it bolts as an undead horse and soon falls apart.",
		"hp": 45.0, "speed": 1.5,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 2, "gold_on_collect": 0, "food_on_collect": 8,
		"flee_search": 8.0, "flee_every": 3.0, "flee_time": 20.0,
		"hp_bar_y": -50.0,
	},
	# The Dread Legion (docs/story-design.md §5): Rhodri's soldiers, people
	# bound by the crown's ritual, not monsters. Only in the campaign
	# ("campaign": never in the normal waves). A fallen one is released
	# ("release": the pale colour fades, a breath goes out) and leaves no corpse.
	"legion_footman": {
		"name": "Legion Footman", "art": "legion_footman", "behavior": "melee", "corpse": false,
		"siege": 1.0, "campaign": true, "release": true,
		"desc": "A soldier of the Dread Legion, bound to Rhodri: pale, silent, and marching in step. A person, not a monster.",
		"hp": 38.0, "speed": 0.95,
		"damage": 7.0, "attack_cooldown": 1.1,
		"gold_on_kill": 5, "gold_on_collect": 0, "food_on_collect": 0,
	},
	# A Legion captain (the campaign's Lysa and Torben, named by the scenario):
	# a tougher footman that is never killed. Below retreat_below of its HP it
	# falls back (CaptainBehavior): untargetable, retreat_speed x as fast, back
	# the way it came and off the map. ("Commanding abilities": open.)
	"legion_captain": {
		"name": "Legion Captain", "art": "legion_captain", "behavior": "captain", "corpse": false,
		"siege": 1.0, "campaign": true, "release": true,
		"desc": "Leads the Dread Legion's soldiers: plumed helm, a captain's cloak. It falls back when beaten instead of falling.",
		"hp": 140.0, "speed": 0.95,
		"damage": 12.0, "attack_cooldown": 1.2,
		"gold_on_kill": 0, "gold_on_collect": 0, "food_on_collect": 0,
		"retreat_below": 0.3, "retreat_speed": 1.4, "hp_bar_y": -52.0,
	},
	# A Legion archer: stops on its road to shoot our people out in the open
	# (the hero, soldiers out, summons, villagers outside) within shoot_range,
	# a little less than a level 1 watchtower's range, so towers outrange it;
	# never a tower's unit. Its arrows are projectiles. At a barrier it shoots
	# that (damage x siege). LegionArcherBehavior.
	"legion_archer": {
		"name": "Legion Archer", "art": "legion_archer", "behavior": "legion_archer", "corpse": false,
		"siege": 0.6, "campaign": true, "release": true, "attack_category": "projectile",
		"desc": "A bowman of the Dread Legion. It stops to shoot whoever of ours is out in the open, from a little less than a watchtower's range.",
		"hp": 26.0, "speed": 0.95,
		"damage": 5.0, "attack_cooldown": 1.6,
		"gold_on_kill": 6, "gold_on_collect": 0, "food_on_collect": 0,
		"shoot_range": 3.2, "arrow_speed": 9.0,
	},
	# A Legion guardsman behind a tower shield: slow and tough, and arrows and
	# bolts (projectile damage) do half to it. Breaks gates and walls well.
	"legion_guard": {
		"name": "Legion Guardsman", "art": "legion_guard", "behavior": "melee", "corpse": false,
		"siege": 1.5, "campaign": true, "release": true,
		"desc": "A Legion soldier behind a tall tower shield. Slow, tough, and arrows and bolts do only half to it.",
		"hp": 70.0, "speed": 0.75,
		"damage": 6.0, "attack_cooldown": 1.3,
		"gold_on_kill": 7, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"projectile": 0.5},
	},
	# A Legion banner-bearer: weak with its spear, but every Legion soldier
	# within banner_radius of its banner (itself too) strikes and shoots
	# 1 + banner_haste times as fast (Enemy.haste; several banners: one counts).
	"legion_banner": {
		"name": "Legion Banner-bearer", "art": "legion_banner", "behavior": "melee", "corpse": false,
		"siege": 0.5, "campaign": true, "release": true,
		"desc": "Carries the Legion's pale banner. Legion soldiers near it strike and shoot faster: kill it first.",
		"hp": 45.0, "speed": 0.9,
		"damage": 3.0, "attack_cooldown": 1.2,
		"gold_on_kill": 8, "gold_on_collect": 0, "food_on_collect": 0,
		"banner_radius": 2.5, "banner_haste": 0.25, "hp_bar_y": -58.0,
	},
	# The Pale Court's champion (the campaign's Rurik, named by the scenario):
	# a boss. Each blow also hits every other one of ours within cleave_radius
	# of its target for cleave x the damage (MeleeBehavior, CampBehavior).
	"legion_champion": {
		"name": "Court Champion", "art": "legion_champion", "behavior": "melee", "corpse": false,
		"siege": 2.0, "campaign": true, "release": true,
		"desc": "The Pale Court's champion in pale plate, with a greatsword whose blows cleave through everyone around its target.",
		"hp": 520.0, "speed": 0.8,
		"damage": 15.0, "attack_cooldown": 1.5,
		"gold_on_kill": 60, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"projectile": 0.75},
		"cleave": 0.6, "cleave_radius": 1.3, "hp_bar_y": -62.0,
	},
	# A Legion commander (CommanderBehavior): a boss that fights like a
	# champion and leads. Every Legion soldier within command_radius (itself
	# too) strikes and shoots 1 + command_haste times as fast and takes
	# command_guard x the damage (Enemy.haste, Enemy.guard; the strongest
	# commander counts, a banner's haste doesn't add to it). Every rally_every
	# seconds while it lives it sends `rally` (kind: count) more for the wave
	# from an edge spawn (the first after first_rally). "downed": at 0 HP it
	# isn't killed: it keeps 1 HP, can't be targeted, and falls back the way
	# it came (faster by retreat_speed) and is gone.
	# The marshal: scenario 10's Halvard; can be killed.
	"legion_marshal": {
		"name": "Legion Marshal", "art": "legion_marshal", "behavior": "commander", "corpse": false,
		"siege": 2.0, "campaign": true, "release": true,
		"desc": "The Dread Legion's marshal: he leads its soldiers in the field. Those near him strike faster and take less harm, and while he lives fresh soldiers keep coming down the roads.",
		"hp": 760.0, "speed": 0.8,
		"damage": 16.0, "attack_cooldown": 1.4,
		"gold_on_kill": 80, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"projectile": 0.75},
		"command_radius": 3.0, "command_haste": 0.3, "command_guard": 0.75,
		"rally_every": 30.0, "first_rally": 20.0, "rally": {"legion_footman": 2},
		"hp_bar_y": -64.0,
	},
	# The king (scenario 11's Rhodri): a commander whose blows cleave, downed
	# at 0 HP instead of killed.
	"legion_king": {
		"name": "The Crowned King", "art": "legion_king", "behavior": "commander", "corpse": false,
		"siege": 2.0, "campaign": true, "release": false,
		"desc": "Rhodri on the field, the reworked crown on his head. His blows cleave, his soldiers fight harder near him, and he is not so easily killed.",
		"hp": 1000.0, "speed": 0.85,
		"damage": 18.0, "attack_cooldown": 1.4,
		"gold_on_kill": 0, "gold_on_collect": 0, "food_on_collect": 0,
		"resist": {"projectile": 0.75},
		"cleave": 0.6, "cleave_radius": 1.3,
		"command_radius": 3.5, "command_haste": 0.35, "command_guard": 0.7,
		"rally_every": 25.0, "first_rally": 15.0, "rally": {"legion_footman": 2, "legion_guard": 1},
		"downed": true, "retreat_speed": 1.4, "hp_bar_y": -66.0,
	},
	# A Legion rider (MountedBehavior; mounted keys: see "goblin_raider"):
	# keeps with the soldiers on foot and rides down our melee fighters. When
	# its horse falls it is a footman.
	"legion_cavalry": {
		"name": "Legion Cavalry", "art": "legion_cavalry", "behavior": "mounted", "corpse": false,
		"siege": 0.3, "campaign": true, "release": true,
		"desc": "A Legion soldier on a pale horse. It rides with the column and runs down our fighters; unhorsed, it fights on as a footman.",
		"hp": 38.0, "speed": 1.5,
		"damage": 8.0, "attack_cooldown": 1.1,
		"gold_on_kill": 2, "gold_on_collect": 0, "food_on_collect": 0,
		"mount": "horse", "mount_hp": 45.0, "rider": "legion_footman", "hunts": "melee", "escort": true,
		"hp_bar_y": -62.0,
	},
}
## Mounted enemies (docs/enemies-design.md §15e; Enemy.mount, MountedBehavior):
##   approach ......... tiles from its village's walls at which a rider stops
##                      following the road and starts circling the village
##   ring ............. tiles outside the walls it circles at
##   circle_time ...... seconds at the village without a blow; then it rides
##                      to the nearest gate, gets off (the mount runs away)
##                      and breaks in on foot
##   hunt_radius ...... it rides at a target of ours within this many tiles
##   chase ............ and gives up beyond this many tiles from it
##   escort_radius .... a Legion rider keeps within this of the nearest Legion
##                      soldier on foot (while there is one)
##   charge_distance .. tiles ridden without a fight: its next blow is a charge,
##   charge_x ......... doing this many times its damage
##   halt_time ........ seconds a halberdier's blow halts a mount
##   mounts ........... a mount a scenario gives (a queue entry's "mount"):
##                      its HP (unless the entry has "mount_hp") and speed
const MOUNTED := {
	"approach": 5.0, "ring": 3.0, "circle_time": 40.0,
	"hunt_radius": 5.0, "chase": 8.0, "escort_radius": 2.5,
	"charge_distance": 3.0, "charge_x": 2.0, "halt_time": 0.5,
	"mounts": {"horse": {"hp": 60.0, "speed": 1.5}},
}
## When a tree wakes up as a wrathwood (docs/enemies-design.md §15c;
## Wrathwoods). Rolled once per tree, at a forester's first blow on it:
##   chance ........ by tree kind (a prop in TREE_CHOP_TIME); missing or 0: never
##   remember ...... added for every tree that village's foresters felled so far
##                   ("the forest remembers"; only for kinds with a chance)
##   max_chance .... the chance never goes above this
##   from_wave ..... none before this wave has begun
##   quiet_waves ... none for this many waves after the village's last one died
## A village has one at most at a time. Never in the tutorial or the title
## backdrop (Game.wrathwoods).
const WRATHWOOD := {
	"chance": {"tree_oak": 0.015, "tree_pine_0": 0.003, "tree_pine_1": 0.003},
	"remember": 0.0005,
	"max_chance": 0.03,
	"from_wave": 8,
	"quiet_waves": 3,
}

## Vulture packs (docs/enemies-design.md §15d; Waves._vulture_packs,
## VulturePack, VultureBehavior). At a wave's start, after its mix:
##   from_wave ...... none before this wave (a scenario may set its own:
##                    Scenario.vultures_from_wave)
##   per_corpses .... one pack per this many edible corpses lying nearest the
##                    village (rounded down) ...
##   max_packs ...... ... at most this many
##   pack ........... vultures per pack (from, to)
##   gap ............ seconds between a pack's birds spawning
##   never_eats ..... corpse kinds they leave alone (sinking ones too)
##   eat_time ....... seconds a meal takes (landed on the corpse)
##   vanish_chance .. after a finished meal the corpse is gone with this chance
##   grow ........... each meal adds this share of its starting max HP (and as
##                    much HP) and damage ...
##   max_meals ...... ... for at most this many meals (4 x 25 %: twice as strong)
##   search_time .... no corpse left: the pack searches this long ...
##   search_spread .. ... spreading out this far, then leaves for the map's edge
##   hidden_time .... leaving, a bird is gone after this long out of every
##                    village's sight (or this long at the edge)
##   chase .......... it fights back at one of ours in the field until that one
##                    is this far from the pack's corpse
##   flee_time ...... hurt by a tower it flees out of its range (+ flee_margin)
##                    and comes back this long after the last hit
const VULTURES := {
	"from_wave": 6, "per_corpses": 5, "max_packs": 3, "pack": [2, 4], "gap": 0.4,
	"never_eats": ["vulture", "wrathwood"],
	"eat_time": 4.0, "vanish_chance": 0.5, "grow": 0.25, "max_meals": 4,
	"search_time": 10.0, "search_spread": 3.0, "hidden_time": 3.0,
	"chase": 6.0, "flee_time": 8.0, "flee_margin": 1.0,
}

## The water monsters' shared rules (docs/aquatic-design.md):
##   dive_time / surface_time .. seconds of diving and of coming up (untargetable)
##   sink_time ....... a corpse on deep water sinks (fades) over this and is gone
##   threat_radius ... the land and shallow tiles within this of a village centre
##                     are what water monsters threaten (wave eligibility)
##   spawn_shore ..... a water spawn picked by the game keeps this far from them
##   melee_reach ..... melee reaches a mob on deep water from the tile next to it
##   warn_after ...... once only water monsters are left in a wave (the rest of it
##                     dead, nothing more to come), after this many seconds the log
##                     (Important) and a toast say so, once per wave: the wave ends
##                     only when they are dead, so towers by the water are needed
##   leave_after ..... once only water-bound ones (leviathan, octopus: habitat
##                     "water") are left in a wave, none named or on a post, and
##                     none in a fight (hurt within 1 s, blasting, an arm out) for
##                     this many seconds, they go back into the deep (no corpse,
##                     no gold) and the wave can end
const AQUA := {
	"dive_time": 0.5, "surface_time": 0.5, "sink_time": 6.0,
	"threat_radius": 12.0, "spawn_shore": 8.0, "melee_reach": 1.5,
	"warn_after": 15.0, "leave_after": 3.0,
}
## The log's line for the first of each water kind in a game (Info; the octopus: Important).
const AQUA_FIRST := {
	"crab": "Crabs crawl up out of the water!",
	"siren": "A siren sings from the water!",
	"leviathan": "A leviathan rises from the deep!",
	"octopus": "A gigantic octopus rises from the deep!",
}
## Rat packs: from `from_wave`, a wave gets rat packs with chance `chance`:
## `packs` of them (more every `more_every` waves), `size` rats each, spawned
## `gap` seconds apart (a little space between them).
const RAT_PACKS := {"from_wave": 3, "chance": 0.6, "packs": [1, 2], "more_every": 5, "size": [4, 7], "gap": 0.25}
const RAT_WAVE_LINGER := 30.0
## Barracks also guard their village's farms against rats: within this x their
## range (level 3: 12 tiles), when no other enemy is in their normal range.
## Units out for a farm stay within FARM_DEFENSE_LEASH of it.
const BARRACKS_FARM_RANGE_FACTOR := 2.0
const FARM_DEFENSE_LEASH := 4.0

## Values scaled by the difficulty multiplier. Timings and ranges are not
## scaled (a bigger cooldown would make "hard" enemies weaker).
const DIFFICULTY_SCALED: Array[String] = [
	"hp", "speed", "damage", "spell_damage",
	"gold_on_kill", "gold_on_collect", "food_on_collect", "materials_on_collect",
]
## What each DIFFICULTY_SCALED value is multiplied by, per difficulty: a value
## listed by name takes its own factor, every other one "all". (Hard's enemies
## are only a little faster: speed and HP together decide how long they stay
## in a tower's range.) A scenario may set its own (Settings.enemy_scale).
const DIFFICULTY_MULTIPLIERS := {
	"easy": {"all": 0.67},
	"normal": {"all": 1.0},
	"hard": {"all": 1.5, "speed": 1.2},
}


## The DIFFICULTY_MULTIPLIERS factor of value `key` on `difficulty` ("easy" ...).
static func difficulty_multiplier(difficulty: String, key: String) -> float:
	var row: Dictionary = DIFFICULTY_MULTIPLIERS[difficulty]
	return float(row.get(key, row["all"]))

## Which enemies march in wave n. Each kind joins from `from_wave`; its share of
## the wave starts at `share` and grows by `growth` per wave, up to `max_share`.
## WAVE_FILLER makes up the rest. Optional: "needs": "water" (only for a
## village its water monsters can reach, see Aqua; elsewhere the filler takes
## its share), "max_count" (at most this many per wave and village; the rest
## go to the filler; with "max_count_every" it grows by 1 every that many
## waves after from_wave) and "chance" (it comes in a wave only with this chance,
## rolled per wave and village by Waves).
const WAVE_MIX := {
	"skeleton": {"from_wave": 2, "share": 0.12, "growth": 0.06, "max_share": 0.35},
	"ork": {"from_wave": 3, "share": 0.10, "growth": 0.03, "max_share": 0.25},
	"slime3": {"from_wave": 4, "share": 0.06, "growth": 0.02, "max_share": 0.15},
	"witch": {"from_wave": 5, "share": 0.10, "growth": 0.02, "max_share": 0.2},
	"wolf": {"from_wave": 5, "share": 0.06, "growth": 0.02, "max_share": 0.15},
	"goblin_raider": {"from_wave": 7, "share": 0.05, "growth": 0.015, "max_share": 0.125},
	"thief": {"from_wave": 7, "share": 0.08, "growth": 0.01, "max_share": 0.15},
	"gargoyle": {"from_wave": 10, "share": 0.06, "growth": 0.01, "max_share": 0.15},
	"necromancer": {"from_wave": 13, "share": 0.04, "growth": 0.005, "max_share": 0.08},
	"vampire": {"from_wave": 13, "share": 0.05, "growth": 0.01, "max_share": 0.12},
	"spider_mother": {"from_wave": 9, "share": 0.04, "growth": 0.005, "max_share": 0.08, "max_count": 2, "max_count_every": 5},
	"crab": {"from_wave": 6, "share": 0.08, "growth": 0.01, "max_share": 0.15, "needs": "water"},
	"siren": {"from_wave": 8, "share": 0.06, "growth": 0.005, "max_share": 0.1, "needs": "water"},
	"leviathan": {"from_wave": 10, "share": 0.03, "growth": 0.0, "max_share": 0.03, "needs": "water", "max_count": 2},
	"octopus": {"from_wave": 20, "share": 0.01, "growth": 0.0, "max_share": 0.01, "needs": "water", "max_count": 1, "chance": 0.25},
}
const WAVE_FILLER := "goblin"
## The special kinds together never take more than this share of a wave
## (scaled down evenly beyond it), so late waves keep some of everything.
const WAVE_MIX_CAP := 0.85


## Kind -> count for wave n (counts add up to wave_size(n)). The kinds that
## need water only with `water` (a village water monsters can reach), and of
## those only the ones in `only` if it isn't empty.
static func wave_composition(n: int, water := false, only: Array = []) -> Dictionary:
	var total := wave_size(n)
	var out := {}
	var used := 0
	var shares := {}
	var sum := 0.0
	for kind in WAVE_MIX:
		var mix: Dictionary = WAVE_MIX[kind]
		if n < mix["from_wave"]:
			continue
		if mix.get("needs", "") == "water" and (not water or (not only.is_empty() and not only.has(kind))):
			continue
		shares[kind] = minf(mix["share"] + mix["growth"] * (n - mix["from_wave"]), mix["max_share"])
		sum += shares[kind]
	var k := WAVE_MIX_CAP / sum if sum > WAVE_MIX_CAP else 1.0
	for kind in shares:
		var share: float = shares[kind] * k
		var c := maxi(1, roundi(total * share))
		c = mini(c, total - used)
		if c > 0:
			out[kind] = c
			used += c
	out[WAVE_FILLER] = out.get(WAVE_FILLER, 0) + total - used
	return out


## The most of `kind` in wave `n` (per village): WAVE_MIX "max_count", plus 1
## every "max_count_every" waves after its from_wave; -1 without a cap.
static func wave_max_count(kind: String, n: int) -> int:
	var mix: Dictionary = WAVE_MIX.get(kind, {})
	if not mix.has("max_count"):
		return -1
	var every := int(mix.get("max_count_every", 0))
	var more := maxi(n - int(mix["from_wave"]), 0) / every if every > 0 else 0
	return int(mix["max_count"]) + more


## Warning lights (easy/normal only) show where hidden enemies will emerge.
const WARNING_LIGHT_WAVES := 5  # only during the first N waves
## An enemy value, scaled by the chosen difficulty if it is in DIFFICULTY_SCALED
## (see Settings; a scenario may set its own scale per value). Whole-number
## values (loot) are rounded and never drop below 1, except values
## that are 0 to begin with (e.g. skeletons give no food).
static func enemy_stat(kind: String, key: String) -> float:
	var base: float = ENEMIES[kind][key]
	return base * Settings.enemy_multiplier(key) if key in DIFFICULTY_SCALED else base


static func enemy_stat_int(kind: String, key: String) -> int:
	if ENEMIES[kind][key] == 0:
		return 0
	return maxi(1, roundi(enemy_stat(kind, key)))


const FIRST_WAVE_DELAY := 90.0  # seconds from game start to the first wave
const WAVE_BUFFER := 30.0  # seconds after the previous wave is gone
const WAVE_SPAWN_GAP := 1.1
const WAVE_HP_GROWTH := 1.12
const EARLY_CALL_GOLD_PER_SECOND := 0.5


static func wave_size(n: int) -> int:
	return 4 + n * 2


static func wave_spawn_points(n: int) -> int:
	return mini(1 + n / 2, 4)


## A cost for the UI, with icons: "60 {gold}, 30 {materials}" (Hud.set_rich_text
## draws the tokens as icons). For the log use cost_text.
static func cost_icons(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res in ["gold", "food", "materials"]:
		if cost.has(res):
			parts.append("%d {%s}" % [cost[res], res])
	return "  ".join(parts)


## Text with icon tokens ({gold} {food} {materials} {xp}) as plain words.
static func plain_text(text: String) -> String:
	return text.replace("{gold}", "gold").replace("{food}", "food").replace("{materials}", "materials").replace("{xp}", "XP").replace("{hp}", "HP")


static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res in ["gold", "food", "materials"]:
		if cost.has(res):
			parts.append("%d %s" % [cost[res], res])
	return ", ".join(parts)
