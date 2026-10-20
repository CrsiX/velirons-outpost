class_name Campaign
extends RefCounted
## The campaign (docs/scenarios-design.md): its scenarios in order, each one
## file. Add a scenario by writing scenario_<n>.gd and listing it here.

const SCENARIOS: Array[Script] = [
	preload("res://scripts/scenarios/scenario_1.gd"),
	preload("res://scripts/scenarios/scenario_2.gd"),
	preload("res://scripts/scenarios/scenario_3.gd"),
	preload("res://scripts/scenarios/scenario_4.gd"),
	preload("res://scripts/scenarios/scenario_5.gd"),
	preload("res://scripts/scenarios/scenario_6.gd"),
	preload("res://scripts/scenarios/scenario_7.gd"),
	preload("res://scripts/scenarios/scenario_8.gd"),
	preload("res://scripts/scenarios/scenario_9.gd"),
]

## How many the campaign will have (the menu lists the rest as to come).
const PLANNED := 11


static func count() -> int:
	return SCENARIOS.size()


## Scenario `n` (1-based), made fresh, or null if there is none.
static func scenario(n: int) -> Scenario:
	if n < 1 or n > SCENARIOS.size():
		return null
	return SCENARIOS[n - 1].new() as Scenario
