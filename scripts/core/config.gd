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
const VILLAGE_EDGE_MARGIN := 14  # village centres stay this far from the map edge
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
const REVEAL_MAP := false  # true: the whole map starts explored (terrain known)
const DISABLE_FOG := true  # true: no fog of war at all; everything is visible

## Terrain generation.
const DESERT_MAX_SHARE := 0.2  # at most this share of all tiles is desert
const DESERT_MIN_VILLAGE_DIST := 12.0  # no desert right next to the village
const MOUNTAIN_RANGES := Vector2i(7, 10)  # min/max number of ranges
const MOUNTAIN_BORDER_BAND := 12  # ranges start within this many tiles of the edge
const MOUNTAIN_ROAD_MARGIN := 2  # keep this many tiles free around roads
const MOUNTAIN_MIN_VILLAGE_DIST := 16.0
const FOREST_CLEARING_RING := 4  # tiles around the village centre kept free (Chebyshev)
## Meadow buffer between desert and forest: forest is skipped this many tiles
## from desert with the given chance (so it's typical, not strict).
const DESERT_FOREST_GAP := 1
const DESERT_FOREST_GAP_CHANCE := 0.85

## Sight: explored tiles are only "under surveillance" (enemies visible) near
## observers. Building sight is measured from the edge of the footprint.
const UNIT_SIGHT := 4.0  # villagers and soldiers outside the walls
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
		"name": "Barracks", "cost": {"materials": 70, "gold": 60}, "build_time": 16.0, "size": 2, "art": "barracks",
		"desc": "2x2. Units wait on its benches (1 per level, up to 3) and turn out when enemies come near. Upgrade for more benches and range.",
	},
	"training": {
		"name": "Training Grounds", "cost": {"materials": 60, "gold": 80}, "build_time": 14.0, "size": 2, "art": "training_grounds",
		"desc": "2x2. Station a military unit here; the hero (in Train mode) passes on his XP to level it up for free.",
	},
	"lightstone": {
		"name": "Light Stone", "cost": {"materials": 40}, "build_time": 10.0, "size": 1, "art": "light_stone",
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


const CIVILIAN_ORDER: Array[String] = ["builder", "farmer", "forester", "explorer", "gatherer", "spatial_archmage"]

const FOOD_UPKEEP := 0.05  # food per civilian per second
const STARVATION_INTERVAL := 15.0  # a civilian dies this often while food is 0

const BUILDER_REST := 3.0
const FARMER_REST := 4.0
const HARVEST_TIME := 2.5
const FARM_RATE := 0.4  # food per second while a farmer is assigned
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
const TREE_CHOP_TIME := {"tree_pine_0": 20.0, "tree_pine_1": 28.0, "tree_oak": 36.0, "tree_dead": 10.0}
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

## Military units. Every kind is stationed on a tower; its "behavior" script
## decides what it does there. Upgrades never change range: towers own range.
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
	"arrow": {"projectile": "arrow", "arc": true, "sound": "shoot"},
	"swift_arrow": {"projectile": "swift_arrow", "arc": true, "sound": "shoot"},
	"bolt": {"projectile": "crossbow_bolt", "arc": false, "speed": 900.0, "sound": "shoot"},
	"orb": {"projectile": "arcane_orb", "whirl": true, "speed": 420.0, "sound": "hit"},
	"fireball": {"projectile": "fireball", "whirl": true, "speed": 380.0, "splash_share": 0.6, "explode": true, "sound": "hit"},
	"frost": {"projectile": "frost_orb", "whirl": true, "speed": 420.0, "sound": "hit"},
	"warp": {"projectile": "warp_orb", "whirl": true, "speed": 460.0, "push_immunity": 4.0, "sound": "hit"},
	"heal": {"projectile": "", "sound": "recruit"},
	"strike": {"projectile": "", "sound": "hit"},
}

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
const HERO_XP_PER_ACTION := {
	"hit": 1,  # a melee hit in combat
	"build_second": 1,  # each second of construction work
	"explore": 1,  # each exploring step that uncovers new tiles
	"corpse": 1,  # each corpse picked up
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
		"name": "Witch", "art": "witch", "behavior": "witch",
		"hp": 12.0, "speed": 1.0,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 12, "gold_on_collect": 0, "food_on_collect": 1,
		"spell_range": 4.0,  # tiles
		"spell_cooldown": 2.0, 
		"enchant_ratio": 0.9,  
		"spell_damage": 5.0,  # dealt to earth elementals (tower units take none)
		"spell_speed": 5.0,  # tiles per second of the pink bolt
		# After this many casts at the same target she ignores it, unless that
		# target attacks her again (which resets its count). Stops endless stalls.
		"spell_ignore_after": 20,
	},
}

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
}
const WAVE_FILLER := "goblin"


## Kind -> count for wave n (counts add up to wave_size(n)).
static func wave_composition(n: int) -> Dictionary:
	var total := wave_size(n)
	var out := {}
	var used := 0
	for kind in WAVE_MIX:
		var mix: Dictionary = WAVE_MIX[kind]
		if n < mix["from_wave"]:
			continue
		var share := minf(mix["share"] + mix["growth"] * (n - mix["from_wave"]), mix["max_share"])
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


static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res in ["gold", "food", "materials"]:
		if cost.has(res):
			parts.append("%d %s" % [cost[res], res])
	return ", ".join(parts)
