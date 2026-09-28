class_name Economy
extends Node
## The three resources. Costs are dictionaries: {"gold": 40, "food": 10, ...}.

signal changed

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


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for res in cost:
		_amounts[res] -= cost[res]
	changed.emit()
	return true


func refund(cost: Dictionary) -> void:
	for res in cost:
		_amounts[res] += cost[res]
	changed.emit()


## Co-op client: the amounts as the host has them.
func set_amounts(d: Dictionary) -> void:
	for res in RESOURCES:
		_amounts[res] = float(d.get(res, _amounts[res]))
	changed.emit()


func add(res: String, value: float) -> void:
	_amounts[res] += value
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
	if not spend(cost):
		return false
	add("materials", Config.MATERIALS_TRADE["materials"] * bundles)
	return true
