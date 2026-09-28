class_name MilitaryPost
extends Building
## A building with a slot for one military unit, which walks there from the
## village when stationed and back when withdrawn (see Army). Towers let the
## unit fight; the training grounds let the hero train it.

var garrison: MilitaryUnit = null
## Unit currently marching here (reserves the slot).
var incoming: MilitaryUnit = null


func can_garrison() -> bool:
	return complete


func set_garrison(unit: MilitaryUnit) -> void:
	garrison = unit
	refresh()
