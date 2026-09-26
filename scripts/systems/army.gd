class_name Army
extends Node
## Military units: bought with gold, kept in reserve, and sent to towers.
## Equipping and unequipping take time: soldiers walk from the village to the
## tower and back before they are available again. No cap on military units.

signal changed

const SOLDIER_SCRIPT := preload("res://scripts/units/soldier.gd")

var game: Game
var units: Array[MilitaryUnit] = []


func setup(p_game: Game) -> void:
	game = p_game


func reserve() -> Array[MilitaryUnit]:
	return _in_state(MilitaryUnit.State.RESERVE)


func stationed() -> Array[MilitaryUnit]:
	return _in_state(MilitaryUnit.State.STATIONED)


func walking() -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.state == MilitaryUnit.State.MARCHING or u.state == MilitaryUnit.State.RETURNING)


func _in_state(s: int) -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.state == s)


func recruit(kind: String = "archer") -> MilitaryUnit:
	if not game.economy.spend(Config.MILITARY[kind]["cost"]):
		return null
	var u := MilitaryUnit.new(kind)
	units.append(u)
	Sfx.play("recruit")
	changed.emit()
	return u


## "" if `unit` can be sent to `tower`, else the reason.
func station_error(unit: MilitaryUnit, tower: Tower) -> String:
	if unit == null or unit.state != MilitaryUnit.State.RESERVE:
		return "That unit isn't in the reserve"
	if tower == null or not tower.can_garrison():
		return "Pick a finished tower"
	if tower.incoming != null:
		return "A unit is already marching to that tower"
	if tower.garrison != null:
		return "Tower is manned: withdraw its unit first"
	if game.world.pathing.find_path(Config.VILLAGE_CENTER, tower.work_tile()).is_empty():
		return "No path to that tower"
	return ""


## Sends a reserve unit out of the village to man `tower`.
func station(unit: MilitaryUnit, tower: Tower) -> bool:
	if station_error(unit, tower) != "":
		return false
	var s := _spawn_walker(unit, Config.VILLAGE_CENTER)
	s.walk_to(tower.work_tile())
	unit.state = MilitaryUnit.State.MARCHING
	unit.post = tower
	tower.incoming = unit
	tower.refresh()
	Sfx.play("place")
	changed.emit()
	return true


## Pulls a unit off its tower (or turns it around mid-march) and walks it home.
func unstation(unit: MilitaryUnit) -> void:
	match unit.state:
		MilitaryUnit.State.STATIONED:
			var tower := unit.post
			tower.set_garrison(null)
			_send_home(unit, _spawn_walker(unit, tower.work_tile()))
		MilitaryUnit.State.MARCHING:
			if is_instance_valid(unit.post):
				unit.post.incoming = null
				unit.post.refresh()
			_send_home(unit, unit.walker)
		_:
			return
	changed.emit()


func upgrade(unit: MilitaryUnit) -> bool:
	if not unit.can_upgrade() or not game.economy.spend(unit.upgrade_cost()):
		return false
	unit.level += 1
	if unit.post and unit.state == MilitaryUnit.State.STATIONED:
		unit.post.refresh()
	Sfx.play("build")
	changed.emit()
	return true


func _spawn_walker(unit: MilitaryUnit, from: Vector2i) -> Soldier:
	var s: Soldier = SOLDIER_SCRIPT.new()
	s.setup(game, unit, from)
	s.arrived.connect(_on_arrived)
	game.world.objects.add_child(s)
	unit.walker = s
	return s


func _send_home(unit: MilitaryUnit, s: Soldier) -> void:
	unit.state = MilitaryUnit.State.RETURNING
	unit.post = null
	if not s.walk_to(Config.VILLAGE_CENTER):
		_on_arrived(s)  # stranded: just count it as home


func _on_arrived(s: Soldier) -> void:
	var unit := s.unit
	match unit.state:
		MilitaryUnit.State.MARCHING:
			var tower := unit.post
			if not is_instance_valid(tower) or not tower.can_garrison():
				_send_home(unit, s)
				return
			tower.incoming = null
			tower.set_garrison(unit)
			unit.state = MilitaryUnit.State.STATIONED
		MilitaryUnit.State.RETURNING:
			unit.state = MilitaryUnit.State.RESERVE
	unit.walker = null
	s.queue_free()
	changed.emit()
