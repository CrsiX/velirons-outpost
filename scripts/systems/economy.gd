class_name Economy
extends Node
## The three resources. Costs are dictionaries: {"gold": 40, "food": 10, ...}.

signal changed
## Income with a source ("kills", "farms", ...; see add), for the statistics.
signal earned(res: String, amount: float, source: String)
## Spending with a purpose ("buildings", "units", ...; negative: a refund).
signal spent(res: String, amount: float, what: String)

const RESOURCES: Array[String] = ["gold", "food", "materials"]

var _amounts := {"gold": 0.0, "food": 0.0, "materials": 0.0}


func setup(start: Dictionary) -> void:
	for res in RESOURCES:
		_amounts[res] = float(start.get(res, 0))
	changed.emit()


func amount(res: String) -> float:
	return _amounts[res]


func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		if _amounts[res] + 0.0001 < cost[res]:
			return false
	return true


## `what` it is spent on ("buildings", "upgrades", "units", "villagers",
## "trade", "caravans") is counted by the statistics.
func spend(cost: Dictionary, what: String = "") -> bool:
	if not can_afford(cost):
		return false
	for res in cost:
		_amounts[res] -= cost[res]
		if what != "":
			spent.emit(res, float(cost[res]), what)
	changed.emit()
	return true


## Gives back what `spend(cost, what)` took (the statistics count it off again).
func refund(cost: Dictionary, what: String = "") -> void:
	for res in cost:
		_amounts[res] += cost[res]
		if what != "":
			spent.emit(res, -float(cost[res]), what)
	changed.emit()


## Co-op client: the amounts as the host has them.
func set_amounts(d: Dictionary) -> void:
	for res in RESOURCES:
		_amounts[res] = float(d.get(res, _amounts[res]))
	changed.emit()


## `source` of income ("kills", "corpses", "mines", "treasure", "call",
## "caravans", "farms", "foresters", "trade", "teardown") is counted by the
## statistics; without one (losses, debug) it isn't.
func add(res: String, value: float, source: String = "") -> void:
	_amounts[res] += value
	if source != "" and value > 0.0:
		earned.emit(res, value, source)
	changed.emit()


## Removes up to `value` food; returns true if the storage ran dry.
func consume_food(value: float) -> bool:
	var before := int(_amounts["food"])
	_amounts["food"] = maxf(_amounts["food"] - value, 0.0)
	if int(_amounts["food"]) != before:
		changed.emit()
	return _amounts["food"] <= 0.0


## Static exchange: gold -> building material, `bundles` at a time.
func buy_materials(bundles: int) -> bool:
	var cost := {"gold": Config.MATERIALS_TRADE["gold"] * bundles}
	if not spend(cost, "trade"):
		return false
	add("materials", Config.MATERIALS_TRADE["materials"] * bundles, "trade")
	return true
