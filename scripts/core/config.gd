class_name Config
extends RefCounted
## Every tunable number lives here so balancing is one-file work.
## Costs are dictionaries of resource -> amount ("gold", "food", "materials").

const MAP_SIZE := 50
const VILLAGE_ORIGIN := Vector2i(23, 23)  # top-left tile of the 5x5 walled village
const VILLAGE_CENTER := Vector2i(25, 25)
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
const START_REVEAL_RADIUS := 6.5

## Buildings the player can order. "size" is the square footprint in tiles.
const BUILDINGS := {
	"tower": {
		"name": "Watchtower", "cost": {"materials": 30}, "build_time": 8.0, "size": 1,
		"desc": "Built in the wilderness by a builder. Station an archer on it.",
	},
	"farm": {
		"name": "Farm", "cost": {"materials": 50}, "build_time": 12.0, "size": 3,
		"desc": "3x3, outside the walls. Produces food while a farmer works it.",
	},
	"hut": {
		"name": "Village Hut", "cost": {"materials": 40}, "build_time": 10.0, "size": 1,
		"desc": "Houses one civilian. Can only be rebuilt on a ruined lot.",
	},
}

## Tower range in tiles. Towers own the range; units own damage and speed.
const TOWER_RANGE := {"tower": 3.6, "wall_tower": 4.2}

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
		"desc": "Scouts the fog on their own. Flees from goblins.",
	},
	"archmage": {
		"name": "Archmage", "cost": {"food": 150, "gold": 600}, "speed": 0.6,
		"desc": "Coming soon: may one day break the siege of Veliron.",
	},
}
const CIVILIAN_ORDER: Array[String] = ["builder", "farmer", "explorer", "archmage"]

const FOOD_UPKEEP := 0.05  # food per civilian per second
const STARVATION_INTERVAL := 15.0  # a civilian dies this often while food is 0

const BUILDER_REST := 3.0
const FARMER_REST := 4.0
const HARVEST_TIME := 2.5
const FARM_RATE := 0.4  # food per second while a farmer is assigned
const FARM_CAPACITY := 40.0
const EXPLORER_REVEAL := 2.6
const EXPLORER_FLEE_RADIUS := 4.5
const EXPLORER_REST := 6.0
## An explorer abandons its local frontier when that target is this much farther
## from the village than the closest unexplored tile to the village.
const EXPLORER_WANDER_FACTOR := 1.6
const EXPLORER_WANDER_SLACK := 8
const EXPLORER_CLAIM_RADIUS := 7.0
const EXPLORER_CLAIM_PENALTY := 30

const MILITARY := {
	"archer": {
		"name": "Archer", "cost": {"gold": 40},
		"desc": "Shoots goblins from a tower.",
		# Upgrades improve damage and attack speed; range comes from the tower.
		"levels": [
			{"damage": 7.0, "cooldown": 1.0},
			{"damage": 11.0, "cooldown": 0.85, "cost": {"gold": 45}},
			{"damage": 16.0, "cooldown": 0.72, "cost": {"gold": 80}},
			{"damage": 24.0, "cooldown": 0.6, "cost": {"gold": 130}},
		],
	},
}

const MATERIALS_TRADE := {"materials": 10, "gold": 15}

const ENEMIES := {
	"goblin": {"name": "Goblin", "hp": 20.0, "speed": 1.1, "reward": 4, "demolition": 1},
}
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
