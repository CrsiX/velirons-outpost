class_name Config
extends RefCounted
## Every tunable number lives here so balancing is one-file work.
## Costs are dictionaries of resource -> amount ("gold", "food", "materials").

const MAP_SIZE := 75
const VILLAGE_CENTER := Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
const VILLAGE_ORIGIN := VILLAGE_CENTER - Vector2i(2, 2)  # top-left tile of the 5x5 walled village

# --- co-op (docs/multiplayer-design.md) ---------------------------------------------------
const MAX_PLAYERS := 8
## Debug: start this many villages on one device (hot-seat test mode; 1 = normal
## single player). Switch between them with the village button in the top bar or Tab.
const HOTSEAT_VILLAGES := 1
const WAVE_EXTRA_PER_PLAYER := 0.25  # extra enemies: this x one village's wave, per player
const CARAVAN_SPEED := 1.4  # tiles per second
const VILLAGE_NAMES: Array[String] = ["Veliron's Outpost", "Rivermoor", "Eastwatch", "Ashford", "Greyholt", "Thornvale", "Kestrel Keep", "Mirefield"]
const VILLAGE_COLORS: Array[Color] = [Color("e0b340"), Color("4f8fe0"), Color("d8573e"), Color("5fbf5a"), Color("b86fe0"), Color("46c3c0"), Color("e07fb4"), Color("e8e0cf")]


## Map side length for `players` villages: +25 for every 2 players beyond the second.
static func map_size(players: int) -> int:
	return MAP_SIZE + 25 * (ceili(clampi(players, 1, MAX_PLAYERS) / 2.0) - 1)


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
## Built for free near the village at the start (the farm on the guaranteed
## farm plot, the camp close to the forest); the starting farmer and forester work them.
const START_BUILDINGS: Array[String] = ["farm", "camp"]
const START_REVEAL_RADIUS := 7.5

## Debug / sandbox switches.
const DEBUG := true  # true: the settings dialog has a Debug page (resources, XP, reveal, unlocks, enemies)
const REVEAL_MAP := false  # true: the whole map starts explored (terrain known)
const DISABLE_FOG := false  # true: no fog of war at all; everything is visible

## World generation (docs/world-design.md). The map is cut into one equal-area
## slice per player around its centre; each village sits near its slice's
## centre. Zones come from height x moisture; ash land only around volcanoes.
const MAP_TYPE_ORDER: Array[String] = ["temperate", "highlands", "coast", "desert", "volcanic"]
## Per type: shifts of the height / moisture fields, sea edges, multipliers for
## lakes, rivers, mountains and mines, the volcano count range, lava rivers.
const MAP_TYPES := {
	"temperate": {"name": "Temperate", "height": 0.0, "moisture": 0.0, "coast_edges": [0, 0], "lakes": 1.0, "rivers": 1.0, "mountains": 1.0, "volcanoes": [0, 1], "mines": 1.0},
	"highlands": {"name": "Highlands", "height": 0.15, "moisture": -0.05, "coast_edges": [0, 0], "lakes": 0.5, "rivers": 1.5, "mountains": 1.6, "volcanoes": [0, 1], "mines": 1.5},
	"coast": {"name": "Coast", "height": -0.05, "moisture": 0.08, "coast_edges": [1, 2], "lakes": 0.7, "rivers": 1.0, "mountains": 0.8, "volcanoes": [0, 0], "mines": 1.0},
	"desert": {"name": "Desert", "height": 0.0, "moisture": -0.22, "coast_edges": [0, 0], "lakes": 0.3, "rivers": 0.3, "mountains": 1.0, "volcanoes": [0, 1], "mines": 1.0, "steppe_max": 0.4},
	"volcanic": {"name": "Volcanic", "height": 0.1, "moisture": -0.1, "coast_edges": [0, 0], "lakes": 0.5, "rivers": 0.0, "mountains": 1.2, "volcanoes": [1, 3], "mines": 1.0, "lava_rivers": true},
}
## Zones: ground art (variants), tree share and tree mix (weights), decoration
## props (not trees; walkable; cleared by buildings) and rules.
const ZONE_ORDER: Array[String] = ["meadow", "oak", "pine", "heath", "steppe", "swamp", "ash"]
const ZONES := {
	"meadow": {"name": "Meadow", "ground": ["tile_meadow_0", "tile_meadow_1", "tile_meadow_2"], "trees": 0.06, "mix": {"tree_oak": 1}, "decor": 0.0, "decor_mix": {}, "farm_bonus": 0.2},
	"oak": {"name": "Oak woods", "ground": ["tile_grass_0", "tile_grass_1", "tile_grass_2"], "forest_floor": "tile_forest_oak", "trees": 0.45, "mix": {"tree_oak": 6, "tree_pine_0": 1}, "decor": 0.01, "decor_mix": {"boulder": 1}},
	"pine": {"name": "Pine forest", "ground": ["tile_grass_dark_0", "tile_grass_dark_1"], "forest_floor": "tile_forest", "trees": 0.85, "mix": {"tree_pine_0": 4, "tree_pine_1": 4, "tree_dead": 1}, "decor": 0.0, "decor_mix": {}},
	"heath": {"name": "Heath", "ground": ["tile_heath_0", "tile_heath_1"], "trees": 0.15, "mix": {"tree_dead": 1}, "decor": 0.06, "decor_mix": {"boulder": 1}},
	"steppe": {"name": "Steppe", "ground": ["tile_desert_0", "tile_desert_1"], "trees": 0.03, "mix": {"tree_dead": 1}, "decor": 0.03, "decor_mix": {"cactus": 1}, "no_farms": true},
	"swamp": {"name": "Swamp", "ground": ["tile_swamp_0", "tile_swamp_1"], "trees": 0.2, "mix": {"tree_dead": 1}, "decor": 0.18, "decor_mix": {"reeds": 1}, "no_farms": true, "walk": 0.7},
	"ash": {"name": "Ash land", "ground": ["tile_ash_0", "tile_ash_1"], "trees": 0.05, "mix": {"stump_charred": 1}, "decor": 0.05, "decor_mix": {"lava_rock": 1}, "no_farms": true},
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
const ROAD_COSTS := {"road": 0.3, "meadow": 1.0, "steppe": 1.0, "heath": 1.6, "oak": 1.6, "pine": 2.5, "swamp": 2.5, "ash": 2.0, "crossing": 4.0, "pass": 15.0}
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
## Rivers wind: a slow noise (bends every ~1/freq tiles) adds up to
## RIVER_MEANDER to a tile's routing cost (flat land would give a straight
## line; in hills the height still leads), and a little per-tile jitter
## breaks ties (long straight runs with one sharp jog).
const RIVER_MEANDER := 14.0
const RIVER_MEANDER_FREQ := 0.1
const RIVER_JITTER := 0.5
const RIVER_GOAL_SLACK := 1.3
const COAST_SHARE := Vector2(0.15, 0.3)
## Bridge look by the zone around it (the look only).
const BRIDGE_STYLES := {"meadow": "stone", "oak": "stone", "pine": "timber", "heath": "timber", "steppe": "rope", "swamp": "stilts", "ash": "charred"}
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
}
const UNLOCK_SITE_SHARE := 0.5
## Ruined watchtowers: claimed by the hero (Explore mode), restored by a builder.
const RUINED_TOWERS := Vector2i(0, 2)  # per slice
const RUIN_DISTANCE := Vector2(12.0, 40.0)
const RUIN_CLAIM_TIME := 5.0
const RUIN_RESTORE_SHARE := 0.5  # of a watchtower's cost
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
	"lair_tree": {"name": "hollow tree", "kinds": ["goblin", "rat"], "guards": ["goblin", "goblin", "goblin"]},
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
const MINE_GOLD_RATE := 0.1  # gold per second; keep below a forester's material rate
const MINE_REACH := 2.0

## Sight: explored tiles are only "under surveillance" (enemies visible) near
## observers. Building sight is measured from the edge of the footprint.
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
		"name": "Village Hut", "cost": {"materials": 40}, "build_time": 10.0, "size": 1, "art": "hut",
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
		"desc": "2x2. Station a military unit here; the hero (in Train mode) passes on his XP to level it up for free.",
	},
	"lightstone": {
		"name": "Light Stone", "cost": {"materials": 20}, "build_time": 10.0, "size": 1, "art": "light_stone",
		"desc": "Rune pillar that lights up the land around it. Needs no one to man it.",
	},
}

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


const CIVILIAN_ORDER: Array[String] = ["builder", "farmer", "forester", "explorer", "gatherer", "miner", "spatial_archmage"]
## Unit kinds and villager roles that have to be unlocked first, and how
## (docs/world-design.md §9.4, §9.6). Unlocks are global: for every village.
const LOCKED := {"summoner": "stone_circle", "apprentice": "mage_tower", "miner": "mine"}

## Villagers have HP: any enemy can hurt them (they flee, never fight); at 0
## they die. At home they heal CIVILIAN_REGEN per second.
const CIVILIAN_HP := 20.0
const CIVILIAN_REGEN := 2.0
const FOOD_UPKEEP := 0.05  # food per civilian per second
const STARVATION_INTERVAL := 15.0  # a civilian dies this often while food is 0

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

## --- Military (docs/military-design.md) ------------------------------------------------
## Every unit goes up to MAX_UNIT_LEVEL. Stats are given for level 1 and level 10
## ("stats": key -> [level 1, level 10]); levels in between follow the curve
## (t = 0 at level 1 .. 1 at level 10, value = a + (b - a) * t^curve). "pinned"
## fixes the first levels exactly (today's archer and summoner levels 1-4); the
## curve then continues from the last pinned value.
## "upgrade_cost" / "train_xp": gold / hero XP to reach level 2 and level 10
## (pinned the same way), "branch_cost": gold to turn into this specialisation.
## Roles: "ranged" (towers or barracks; own "range" in the field, never upgraded,
## always below the smallest tower range), "melee" (barracks only), "summoner"
## (summons elementals; no attack of its own), "healer" (heals allies around it).
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
		"pinned": {"damage": [7.0, 11.0, 16.0, 24.0], "cooldown": [1.0, 0.85, 0.72, 0.6]},
		"upgrade_cost": [45, 300], "upgrade_cost_pinned": [45, 80, 130],
		"train_xp": [30, 400], "train_xp_pinned": [30, 60, 100],
		"branches": ["crossbowman", "swiftbowman"],
	},
	"crossbowman": {
		"name": "Crossbowman", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "archer", "branch_cost": {"gold": 150},
		"speed": 1.6, "attack": "bolt", "range": 3.2, "pierce": true,  # (piercing: for shielded enemies, later)
		"desc": "Slow, heavy crossbow bolts; reaches further than an archer in the field.",
		"stats": {"hp": [34.0, 100.0], "damage": [50.0, 170.0], "cooldown": [2.25, 1.7]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"swiftbowman": {
		"name": "Swiftbowman", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "archer", "branch_cost": {"gold": 150},
		"speed": 2.0, "attack": "swift_arrow", "range": 2.6,
		"desc": "A hail of light arrows: tiny hits, very fast.",
		"stats": {"hp": [28.0, 85.0], "damage": [5.5, 14.0], "cooldown": [0.3, 0.18]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"shield_bearer": {
		"name": "Shield Bearer", "role": "melee", "posts": ["barracks"], "recruit": true,
		"cost": {"gold": 50}, "speed": 1.3, "attack": "strike",
		"desc": "Barracks only. Huge shield, lots of HP, little damage: holds enemies up.",
		"stats": {"hp": [55.0, 180.0], "damage": [3.0, 12.0], "cooldown": [1.2, 0.9]},
		"upgrade_cost": [40, 250], "train_xp": [30, 350],
	},
	"summoner": {
		"name": "Summoner", "role": "summoner", "posts": ["tower", "barracks"], "recruit": true,
		"cost": {"gold": 60}, "speed": 1.4, "summon": "earth",
		"desc": "Summons earth elementals while enemies are near. Fragile, no attack of its own.",
		"stats": {"hp": [18.0, 50.0], "interval": [6.0, 2.5], "max_summons": [2.0, 8.0], "summon_hp": [20.0, 90.0], "summon_damage": [4.0, 18.0]},
		"pinned": {"interval": [6.0, 5.0, 4.2, 3.5], "max_summons": [2.0, 3.0, 4.0, 5.0], "summon_hp": [20.0, 26.0, 34.0, 44.0], "summon_damage": [4.0, 5.0, 6.5, 8.5]},
		"upgrade_cost": [60, 300], "upgrade_cost_pinned": [60, 100, 150],
		"train_xp": [40, 400], "train_xp_pinned": [40, 80, 130],
		"branches": ["fire_summoner"],
	},
	"fire_summoner": {
		"name": "Fire Summoner", "role": "summoner", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "summoner", "branch_cost": {"gold": 150},
		"speed": 1.4, "summon": "fire",
		"desc": "Summons fire elementals: quick and deadly, but they burn themselves up.",
		"stats": {"hp": [18.0, 50.0], "interval": [4.2, 2.5], "max_summons": [3.0, 7.0], "summon_hp": [34.0, 90.0], "summon_damage": [6.5, 18.0]},
		"upgrade_cost": [70, 300], "train_xp": [45, 400],
	},
	"apprentice": {
		"name": "Apprentice", "role": "ranged", "posts": ["tower", "barracks"], "recruit": true,
		"cost": {"gold": 55}, "speed": 1.6, "attack": "orb", "range": 2.8,
		"desc": "A young mage: whirling dark-blue orbs. Grows into a specialised mage.",
		"stats": {"hp": [20.0, 60.0], "damage": [7.0, 38.0], "cooldown": [1.0, 0.55]},
		"upgrade_cost": [50, 300], "train_xp": [35, 400],
		"branches": ["fire_mage", "ice_mage", "healing_mage", "spatial_mage"],
	},
	"fire_mage": {
		"name": "Fire Mage", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "fireball", "range": 2.8,
		"desc": "Fireballs that explode: less damage per hit, but it splashes whole groups.",
		"stats": {"hp": [20.0, 60.0], "damage": [10.0, 27.0], "cooldown": [0.95, 0.55], "splash": [1.2, 1.8]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"ice_mage": {
		"name": "Ice Mage", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "frost", "range": 2.8,
		"desc": "Frost orbs: a bit more damage, and the enemy hit is slowed for a while.",
		"stats": {"hp": [20.0, 60.0], "damage": [16.0, 44.0], "cooldown": [0.95, 0.55], "slow": [0.7, 0.4], "slow_time": [2.0, 3.5]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"healing_mage": {
		"name": "Healing Mage", "role": "healer", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "heal",
		"desc": "No damage. Heals every allied unit and hero around it (not summons).",
		"stats": {"hp": [15.0, 45.0], "heal": [6.0, 30.0], "cooldown": [3.0, 1.4], "radius": [2.5, 3.5]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
	},
	"spatial_mage": {
		"name": "Spatial Mage", "role": "ranged", "posts": ["tower", "barracks"], "recruit": false,
		"branch_of": "apprentice", "branch_cost": {"gold": 120},
		"speed": 1.6, "attack": "warp", "range": 2.8,
		"desc": "Little damage, but the enemy hit is thrown back along its road. At level %d it can become the Spatial Archmage." % ARCHMAGE_LEVEL,
		"stats": {"hp": [20.0, 60.0], "damage": [9.0, 26.0], "cooldown": [0.95, 0.55], "push": [1.5, 4.0]},
		"upgrade_cost": [60, 300], "train_xp": [40, 400],
		"archmage": true,
	},
}
## Recruitable units in the Army tab (specialisations come from upgrades).
const MILITARY_ORDER: Array[String] = ["archer", "shield_bearer", "summoner", "apprentice"]
## Kinds in tech-tree order (base unit, then its specialisations).
const MILITARY_TREE: Array[String] = ["archer", "crossbowman", "swiftbowman", "shield_bearer", "summoner", "fire_summoner", "apprentice", "fire_mage", "ice_mage", "healing_mage", "spatial_mage"]

## What a unit's attack looks like and does. "projectile": art of the shot
## ("" = no shot); "whirl": the shot spins; "arc": arrows fly on an arc.
## Effects: "splash" (damage to others within the unit's "splash" radius,
## times splash_share), "slow" (the unit's "slow" speed factor for "slow_time"
## s), "push" (thrown back "push" tiles along its road, once per push_immunity s),
## "heal" (heals allies within the unit's "radius").
const ATTACKS := {
	"arrow": {"projectile": "arrow", "arc": true, "sound": "shoot", "category": "projectile"},
	"swift_arrow": {"projectile": "swift_arrow", "arc": true, "sound": "shoot", "category": "projectile"},
	"bolt": {"projectile": "crossbow_bolt", "arc": false, "speed": 900.0, "sound": "shoot", "category": "projectile"},
	"orb": {"projectile": "arcane_orb", "whirl": true, "speed": 420.0, "sound": "hit", "category": "magical"},
	"fireball": {"projectile": "fireball", "whirl": true, "speed": 380.0, "splash_share": 0.6, "explode": true, "sound": "hit", "category": "magical"},
	"frost": {"projectile": "frost_orb", "whirl": true, "speed": 420.0, "sound": "hit", "category": "magical"},
	"warp": {"projectile": "warp_orb", "whirl": true, "speed": 460.0, "push_immunity": 4.0, "sound": "hit", "category": "magical"},
	"heal": {"projectile": "", "sound": "recruit", "category": "holy"},
	"strike": {"projectile": "", "sound": "hit", "category": "melee"},
}

## What kind of damage a hit does (ATTACKS "category"; enemies: "attack_category",
## melee if not given). An enemy's "resist" table scales what it takes by
## category (a vampire takes 0.67 x magical damage). The hero's sword, earth
## elementals and soldiers' strikes are melee; fire elementals are magical.
## "pure" (a raised enemy's drain, a flame burning itself up) is never scaled.
const DAMAGE_CATEGORIES: Array[String] = ["melee", "projectile", "magical", "holy", "pure"]

## Summoned elementals, relative to Config.SUMMON (earth elementals).
const SUMMONS := {
	"earth": {"name": "Earth Elemental", "art": "unit_earth_elemental", "hp": 1.0, "damage": 1.0, "speed": 1.1, "self_damage": 0.0, "hover": false},
	# Fire elementals hover and flicker; they lose self_damage x the damage they deal, as HP.
	"fire": {"name": "Fire Elemental", "art": "unit_fire_elemental", "hp": 0.5, "damage": 2.5, "speed": 1.8, "self_damage": 0.25, "hover": true},
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
	var pinned: Array = spec.get("pinned", {}).get(key, [])
	return _curve(ends[0], ends[1], pinned, clampi(level, 0, MAX_UNIT_LEVEL - 1), MAX_UNIT_LEVEL, spec.get("curve", 1.0))


## Gold to go from `level` to the next one (0-based), or {} at the top.
static func unit_upgrade_cost(kind: String, level: int) -> Dictionary:
	if level >= MAX_UNIT_LEVEL - 1:
		return {}
	var spec: Dictionary = MILITARY[kind]
	var ends: Array = spec["upgrade_cost"]
	var v := _curve(ends[0], ends[1], spec.get("upgrade_cost_pinned", []), level, MAX_UNIT_LEVEL - 1, spec.get("curve", 1.0))
	return {"gold": roundi(v / 5.0) * 5}


## Hero XP for the next level at the training grounds (before the difficulty factor).
static func unit_train_xp(kind: String, level: int) -> float:
	if level >= MAX_UNIT_LEVEL - 1:
		return 0.0
	var spec: Dictionary = MILITARY[kind]
	var ends: Array = spec["train_xp"]
	return roundf(_curve(ends[0], ends[1], spec.get("train_xp_pinned", []), level, MAX_UNIT_LEVEL - 1, spec.get("curve", 1.0)))


## Seconds a downed unit of `level` needs to revive.
static func unit_revive_time(level: int) -> float:
	return lerpf(UNIT_REVIVE_TIME[0], UNIT_REVIVE_TIME[1], float(clampi(level, 0, MAX_UNIT_LEVEL - 1)) / (MAX_UNIT_LEVEL - 1))


## Value `i` of `n` steps from `first` to `last`; `pinned` fixes the first ones,
## the rest continues from the last pinned value.
static func _curve(first: float, last: float, pinned: Array, i: int, n: int, curve: float) -> float:
	if i < pinned.size():
		return pinned[i]
	var from := 0
	var a := first
	if not pinned.is_empty():
		from = pinned.size() - 1
		a = pinned[-1]
	if n - 1 <= from:
		return last
	var t := float(i - from) / float(n - 1 - from)
	return lerpf(a, last, pow(t, curve))
## Training XP needed is multiplied by this per difficulty (see Settings).
const TRAIN_XP_DIFFICULTY := {"easy": 0.8, "normal": 1.0, "hard": 1.5}

## The hero: a fighter who can also do a little of every villager job.
## He has no hut, eats nothing and doesn't count as a villager.
const HERO := {
	"name": "Hero", "hp": 60.0, "speed": 1.8,
	# Train: after a unit levels up he waits this many real seconds (whatever the
	# game speed) before training on, so his mode can be changed to keep his XP.
	"train_pause": 4.0,
	"damage": 8.0, "attack_cooldown": 0.9, "attack_range": 0.8,
	"sight": 4.0,  # surveillance while outside
	"alert_radius": 6.0,  # Defend: enemies this close to a gate draw him out
	"leash": 14.0,  # Defend: he won't chase farther than this from the centre
	"build_efficiency": 0.5,  # "a little" of each job: half a builder's speed
	"explore_reveal": 1.8,  # explorers see 2.6
	"gather_capacity": 2,  # gatherers carry 6
	"train_rate": 5.0,  # XP per second passed on at the training grounds
	"rest_regen": 1.0,  # HP per second while resting idle in the village centre
	"rest_delay": 3.0,  # seconds of idling there before the HP starts coming back
}
## XP the hero earns per action (training earns none).
## The hero spends his own XP on levels (the level-up button in his panel).
## HP and sword damage run from level 1 (HERO "hp" / "damage") to
## HERO_MAX_LEVEL; "xp_cost" is the XP from level 1 to 2 ... up to the last
## level. Being downed loses his unspent XP, never his levels.
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
	"build_second": 1,  # each second of construction work
	"explore": 1,  # each exploring step that uncovers new tiles
	"corpse": 4,  # each corpse picked up
}

## Earth elementals summoned by summoners. hp/damage come from the summoner's
## level; at level 1 an elemental is exactly as strong as a goblin.
const SUMMON := {
	"name": "Earth Elemental", "speed": 1.1, "attack_cooldown": 1.0,
	"attack_range": 0.8,  # close combat
	"sight": 3.5,  # notices enemies this close
	"leash": 4.0,  # wanders and chases within this distance of its tower
}

const MATERIALS_TRADE := {"materials": 10, "gold": 15}

# --- enemies ------------------------------------------------------------------------
## Every enemy kind in one place. Keys (all required):
##   name, art ........ display name; sprites are unit_<art> and corpse_<art>
##   behavior ......... what it does besides walking to a gate: "melee" (fights
##                      summons blocking its way) or "witch" (casts spells)
##   hp, speed ........ hit points; tiles per second along the road
##   damage ........... close-combat damage per hit (0 = never fights in melee)
##   attack_cooldown .. seconds between melee hits
##   gold_on_kill ..... paid the moment it dies
##   gold_on_collect, food_on_collect .. paid when a gatherer brings the corpse home
## Behaviours may add their own keys (see "witch").
## Any enemy that gets through a gate destroys exactly one random hut, on every
## difficulty (the villager living there, if any, dies with it).
const ENEMIES := {
	"goblin": {
		"name": "Goblin", "art": "goblin", "behavior": "melee",
		"hp": 20.0, "speed": 1.1,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 3, "gold_on_collect": 3, "food_on_collect": 2,
	},
	# Same as goblins, but bones give no food.
	"skeleton": {
		"name": "Skeleton", "art": "skeleton", "behavior": "melee",
		"hp": 20.0, "speed": 1.1,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 3, "gold_on_collect": 3, "food_on_collect": 0,
	},
	# Slower and much tougher; hits hard. Gold only on kill, lots of food as a corpse.
	"ork": {
		"name": "Ork", "art": "ork", "behavior": "melee",
		"hp": 55.0, "speed": 0.8,
		"damage": 11.0, "attack_cooldown": 1.2,
		"gold_on_kill": 6, "gold_on_collect": 0, "food_on_collect": 6,
	},
	# Fragile spell-caster: no melee. Stops at manned towers in range and
	# enchants their unit (it stops shooting/summoning for a while). Spells hurt
	# earth elementals. Whoever attacks her becomes her first target.
	"witch": {
		"name": "Witch", "art": "witch", "behavior": "witch", "attack_category": "magical",
		"hp": 12.0, "speed": 1.0,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 12, "gold_on_collect": 0, "food_on_collect": 1,
		"spell_range": 3.6,  # tiles: no farther than a level 1 watchtower shoots (TOWER_RANGE)
		"spell_cooldown": 2.0, 
		"enchant_ratio": 0.45,  # a bewitched unit stops for 45 % of her spell cooldown (0.9 s)
		"spell_damage": 5.0,  # dealt to earth elementals (tower units take none)
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
		"hp": 20.0, "speed": 1.5,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 2, "gold_on_collect": 3, "food_on_collect": 0,
		"steal_share": 0.04,
	},
	# The first flyer: it keeps to the roads, but no ground slows it (swamps,
	# fords). Fights like a goblin. Only ranged attacks (towers, archers,
	# mages) and fire elementals (flyers too) can go for it; ground melee
	# units (the hero, shield bearers, earth elementals) only hit back when it
	# hits them and their own blow is ready (a counter-strike).
	"gargoyle": {
		"name": "Gargoyle", "art": "gargoyle", "behavior": "melee", "flying": true,
		"hp": 40.0, "speed": 0.8,
		"damage": 7.0, "attack_cooldown": 1.2,
		"gold_on_kill": 8, "gold_on_collect": 0, "food_on_collect": 4,
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
		"hp": 20.0, "speed": 0.95,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 25, "gold_on_collect": 0, "food_on_collect": 0,
		"cast_time": 5.0, "raise_range": 3.0, "raise_hp": 0.5, "raise_decay": 20.0, "raise_gold": 0.5,
		"resist": {"holy": 1.5},  # holy damage hurts it more
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
		"hp": 40.0, "speed": 0.9,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 6, "gold_on_collect": 8, "food_on_collect": 0,
		"resist": {"magical": 0.67},
		"drain": 0.67,
		"bat_below": 0.33, "bat_time": 10.0, "bat_speed": 1.8, "bat_gate_heal": 0.33,
	},
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
	"gold_on_kill", "gold_on_collect", "food_on_collect",
]

## Which enemies march in wave n. Each kind joins from `from_wave`; its share of
## the wave starts at `share` and grows by `growth` per wave, up to `max_share`.
## WAVE_FILLER makes up the rest.
const WAVE_MIX := {
	"skeleton": {"from_wave": 2, "share": 0.12, "growth": 0.06, "max_share": 0.35},
	"ork": {"from_wave": 3, "share": 0.10, "growth": 0.03, "max_share": 0.25},
	"witch": {"from_wave": 5, "share": 0.10, "growth": 0.02, "max_share": 0.2},
	"thief": {"from_wave": 7, "share": 0.08, "growth": 0.01, "max_share": 0.15},
	"gargoyle": {"from_wave": 10, "share": 0.06, "growth": 0.01, "max_share": 0.15},
	"necromancer": {"from_wave": 13, "share": 0.04, "growth": 0.005, "max_share": 0.08},
	"vampire": {"from_wave": 13, "share": 0.05, "growth": 0.01, "max_share": 0.12},
}
const WAVE_FILLER := "goblin"
## The special kinds together never take more than this share of a wave
## (scaled down evenly beyond it), so late waves keep some of everything.
const WAVE_MIX_CAP := 0.85


## Kind -> count for wave n (counts add up to wave_size(n)).
static func wave_composition(n: int) -> Dictionary:
	var total := wave_size(n)
	var out := {}
	var used := 0
	var shares := {}
	var sum := 0.0
	for kind in WAVE_MIX:
		var mix: Dictionary = WAVE_MIX[kind]
		if n < mix["from_wave"]:
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


## Warning lights (easy/normal only) show where hidden enemies will emerge.
const WARNING_LIGHT_WAVES := 5  # only during the first N waves
## An enemy value, scaled by the chosen difficulty if it is in DIFFICULTY_SCALED
## (see Settings). Whole-number
## values (loot) are rounded and never drop below 1, except values
## that are 0 to begin with (e.g. skeletons give no food).
static func enemy_stat(kind: String, key: String) -> float:
	var base: float = ENEMIES[kind][key]
	return base * Settings.enemy_multiplier() if key in DIFFICULTY_SCALED else base


static func enemy_stat_int(kind: String, key: String) -> int:
	if ENEMIES[kind][key] == 0:
		return 0
	return maxi(1, roundi(enemy_stat(kind, key)))


const FIRST_WAVE_DELAY := 90.0  # seconds from game start to the first wave
const WAVE_BUFFER := 30.0  # seconds after the previous wave is gone
const WAVE_SPAWN_GAP := 1.1
const WAVE_HP_GROWTH := 1.15
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
