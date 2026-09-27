class_name Config
extends RefCounted
## Every tunable number lives here so balancing is one-file work.
## Costs are dictionaries of resource -> amount ("gold", "food", "materials").

const MAP_SIZE := 75
const VILLAGE_CENTER := Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)
const VILLAGE_ORIGIN := VILLAGE_CENTER - Vector2i(2, 2)  # top-left tile of the 5x5 walled village
## Village layout from the design doc. T tower, W wall, G gate, V hut.
const VILLAGE_LAYOUT: Array[String] = [
	"TWGWT",
	"WVVVW",
	"GVVVG",
	"WVVVW",
	"TWGWT",
]

const START_RESOURCES := {"gold": 150, "food": 120, "materials": 70}
const START_CIVILIANS: Array[String] = ["builder", "farmer", "explorer"]
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
	"lightstone": {
		"name": "Light Stone", "cost": {"materials": 40}, "build_time": 10.0, "size": 1, "art": "light_stone",
		"desc": "Rune pillar that lights up the land around it. Needs no one to man it.",
	},
}

## Tower range in tiles. Towers own the range; units own damage and speed.
const TOWER_RANGE := {"tower": 3.6, "wall_tower": 4.2}
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
	},
	"archmage": {
		"name": "Archmage", "cost": {"food": 150, "gold": 600}, "speed": 0.6,
		"desc": "Coming soon: may one day break the siege of Veliron.",
	},
}
const CIVILIAN_ORDER: Array[String] = ["builder", "farmer", "forester", "explorer", "gatherer", "archmage"]

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
const MILITARY := {
	"archer": {
		"name": "Archer", "cost": {"gold": 40}, "speed": 1.8, "behavior": "archer",
		"desc": "Shoots enemies from a tower.",
		# Upgrades improve damage and attack speed; range comes from the tower.
		"levels": [
			{"damage": 7.0, "cooldown": 1.0},
			{"damage": 11.0, "cooldown": 0.85, "cost": {"gold": 45}},
			{"damage": 16.0, "cooldown": 0.72, "cost": {"gold": 80}},
			{"damage": 24.0, "cooldown": 0.6, "cost": {"gold": 130}},
		],
	},
	"summoner": {
		"name": "Summoner", "cost": {"gold": 60}, "speed": 1.4, "behavior": "summoner",
		"desc": "Summons earth elementals while enemies are in sight.",
		# Upgrades speed up summoning, raise the cap, and strengthen *new* summons.
		"levels": [
			{"interval": 6.0, "max_summons": 2, "summon_hp": 20.0, "summon_damage": 4.0},
			{"interval": 5.0, "max_summons": 3, "summon_hp": 26.0, "summon_damage": 5.0, "cost": {"gold": 60}},
			{"interval": 4.2, "max_summons": 4, "summon_hp": 34.0, "summon_damage": 6.5, "cost": {"gold": 100}},
			{"interval": 3.5, "max_summons": 5, "summon_hp": 44.0, "summon_damage": 8.5, "cost": {"gold": 150}},
		],
	},
}
const MILITARY_ORDER: Array[String] = ["archer", "summoner"]

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
##   demolition ....... huts destroyed when it gets through a gate
##   damage ........... close-combat damage per hit (0 = never fights in melee)
##   attack_cooldown .. seconds between melee hits
##   gold_on_kill ..... paid the moment it dies
##   gold_on_collect, food_on_collect .. paid when a gatherer brings the corpse home
## Behaviours may add their own keys (see "witch").
const ENEMIES := {
	"goblin": {
		"name": "Goblin", "art": "goblin", "behavior": "melee",
		"hp": 20.0, "speed": 1.1, "demolition": 1,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 3, "gold_on_collect": 3, "food_on_collect": 2,
	},
	# Same as goblins, but bones give no food.
	"skeleton": {
		"name": "Skeleton", "art": "skeleton", "behavior": "melee",
		"hp": 20.0, "speed": 1.1, "demolition": 1,
		"damage": 4.0, "attack_cooldown": 1.0,
		"gold_on_kill": 3, "gold_on_collect": 3, "food_on_collect": 0,
	},
	# Slower and much tougher; hits hard. Gold only on kill, lots of food as a corpse.
	"ork": {
		"name": "Ork", "art": "ork", "behavior": "melee",
		"hp": 55.0, "speed": 0.8, "demolition": 1,
		"damage": 11.0, "attack_cooldown": 1.2,
		"gold_on_kill": 6, "gold_on_collect": 0, "food_on_collect": 6,
	},
	# Fragile spell-caster: no melee. Stops at manned towers in range and
	# enchants their unit (it stops shooting/summoning for a while). Spells hurt
	# earth elementals. Whoever attacks her becomes her first target.
	"witch": {
		"name": "Witch", "art": "witch", "behavior": "witch",
		"hp": 12.0, "speed": 1.0, "demolition": 1,
		"damage": 0.0, "attack_cooldown": 1.0,
		"gold_on_kill": 12, "gold_on_collect": 0, "food_on_collect": 1,
		"spell_range": 4.5,  # tiles
		"spell_cooldown": 2.0,  # s between casts: twice an archer's first-level shot interval
		"enchant_ratio": 0.9,  # a tower unit stays enchanted for 90% of the cooldown
		"spell_damage": 5.0,  # dealt to earth elementals (tower units take none)
		"spell_speed": 5.0,  # tiles per second of the pink bolt
	},
}

## Values scaled by the difficulty multiplier. Timings and ranges are not
## scaled (a bigger cooldown would make "hard" enemies weaker).
const DIFFICULTY_SCALED: Array[String] = [
	"hp", "speed", "demolition", "damage", "spell_damage",
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
## values (demolition, loot) are rounded and never drop below 1, except values
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
