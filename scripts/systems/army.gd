class_name Army
extends Node
## Military units: bought with gold, kept in reserve, stationed on towers.
## There is no cap on military units.

signal changed

var game: Game
var units: Array[MilitaryUnit] = []


func setup(p_game: Game) -> void:
	game = p_game


func reserve() -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.post == null)


func stationed() -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.post != null)


func recruit(kind: String = "archer") -> MilitaryUnit:
	if not game.economy.spend(Config.MILITARY[kind]["cost"]):
		return null
	var u := MilitaryUnit.new(kind)
	units.append(u)
	Sfx.play("recruit")
	changed.emit()
	return u


## Puts `unit` on `tower`; whoever was there goes back to the reserve.
func station(unit: MilitaryUnit, tower: Tower) -> bool:
	if unit == null or tower == null or not tower.can_garrison():
		return false
	if unit.post == tower:
		return true
	if unit.post:
		unit.post.set_garrison(null)
	if tower.garrison:
		tower.garrison.post = null
	unit.post = tower
	tower.set_garrison(unit)
	Sfx.play("place")
	changed.emit()
	return true


func unstation(unit: MilitaryUnit) -> void:
	if unit.post:
		unit.post.set_garrison(null)
		unit.post = null
		changed.emit()


func upgrade(unit: MilitaryUnit) -> bool:
	if not unit.can_upgrade() or not game.economy.spend(unit.upgrade_cost()):
		return false
	unit.level += 1
	if unit.post:
		unit.post.refresh()
	Sfx.play("build")
	changed.emit()
	return true
