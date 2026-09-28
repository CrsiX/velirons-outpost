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


func recruit(kind: String) -> MilitaryUnit:
	if not game.economy.spend(Config.MILITARY[kind]["cost"]):
		return null
	var u := MilitaryUnit.new(kind)
	u.uid = game.next_id(kind)
	units.append(u)
	game.events.debug("recruit %s for %s" % [u.label(), Config.cost_text(Config.MILITARY[kind]["cost"])])
	Sfx.play("recruit")
	changed.emit()
	return u


## "" if `unit` can be sent to `tower`, else the reason.
func station_error(unit: MilitaryUnit, tower: MilitaryPost) -> String:
	if unit == null or unit.state != MilitaryUnit.State.RESERVE:
		return "That unit isn't in the reserve"
	if tower == null or not tower.can_garrison():
		return "Pick a finished tower or training grounds"
	if tower.incoming != null:
		return "A unit is already marching there"
	if tower.garrison != null:
		return "Already manned: withdraw its unit first"
	if game.world.pathing.find_path(Config.VILLAGE_CENTER, tower.work_tile()).is_empty():
		return "No path there"
	return ""


## Sends a reserve unit out of the village to man `tower` (any military post).
func station(unit: MilitaryUnit, tower: MilitaryPost) -> bool:
	if station_error(unit, tower) != "":
		return false
	game.events.debug("send %s from the reserve to %s" % [unit.label(), tower.label()])
	var s := _spawn_walker(unit, Config.VILLAGE_CENTER)
	s.walk_to(tower.work_tile())
	unit.state = MilitaryUnit.State.MARCHING
	unit.post = tower
	tower.incoming = unit
	tower.refresh()
	Sfx.play("place")
	changed.emit()
	return true


## "" if the stationed `unit` can move straight over to `post`, else why not.
func transfer_error(unit: MilitaryUnit, post: MilitaryPost) -> String:
	if unit == null or unit.state != MilitaryUnit.State.STATIONED:
		return "That unit isn't on duty"
	if post == null or post == unit.post or not post.can_garrison():
		return "Pick another finished tower or training grounds"
	if post.incoming != null or post.garrison != null:
		return "That post is taken"
	if game.world.pathing.find_path(unit.post.work_tile(), post.work_tile()).is_empty():
		return "No path there"
	return ""


## Moves a stationed unit from its post straight to another (drag & drop);
## it walks over and takes up the new post on arrival.
func transfer(unit: MilitaryUnit, post: MilitaryPost) -> bool:
	if transfer_error(unit, post) != "":
		return false
	var from := unit.post
	game.events.debug("move %s from %s to %s" % [unit.label(), from.label(), post.label()])
	from.set_garrison(null)
	var s := _spawn_walker(unit, from.work_tile())
	s.walk_to(post.work_tile())
	unit.state = MilitaryUnit.State.MARCHING
	unit.post = post
	post.incoming = unit
	post.refresh()
	Sfx.play("place")
	changed.emit()
	return true


## Pulls a unit off its tower (or turns it around mid-march) and walks it home.
func unstation(unit: MilitaryUnit) -> void:
	match unit.state:
		MilitaryUnit.State.STATIONED:
			var tower := unit.post
			game.events.debug("withdraw %s from %s" % [unit.label(), tower.label()])
			tower.set_garrison(null)
			_send_home(unit, _spawn_walker(unit, tower.work_tile()))
		MilitaryUnit.State.MARCHING:
			game.events.debug("call %s back on its way to %s" % [unit.label(), unit.post.label() if is_instance_valid(unit.post) else "its post"])
			if is_instance_valid(unit.post):
				unit.post.incoming = null
				unit.post.refresh()
			_send_home(unit, unit.walker)
		_:
			return
	changed.emit()


## Passes up to `amount` of the hero's XP on to `unit` (training grounds).
## When the unit has collected enough it levels up for free. Returns the XP used.
func train(unit: MilitaryUnit, amount: int) -> int:
	if amount <= 0 or not unit.can_train():
		return 0
	var used := clampi(ceili(unit.train_xp_needed() - unit.train_xp), 0, amount)
	unit.train_xp += used
	if unit.train_xp >= unit.train_xp_needed() - 0.001:
		unit.level += 1
		unit.train_xp = 0.0
		game.events.info("%s fully trained to level %d%s" % [unit.label(), unit.level + 1, " at %s" % unit.post.label() if unit.post else ""])
		if unit.post:
			unit.post.refresh()
			game.world.float_text("%s level %d!" % [unit.display_name(), unit.level + 1], unit.post.position + Vector2(0, -90), UiTheme.GOLD)
		Sfx.play("build")
		changed.emit()
	return used


func upgrade(unit: MilitaryUnit) -> bool:
	if not unit.can_upgrade() or not game.economy.spend(unit.upgrade_cost()):
		return false
	unit.level += 1
	unit.train_xp = 0.0  # training was towards the level just bought
	game.events.debug("level-up %s to level %d for %s" % [unit.label(), unit.level + 1, Config.cost_text(unit.spec()["levels"][unit.level]["cost"])])
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
			game.events.debug("%s takes up its post on %s" % [unit.label(), tower.label()])
		MilitaryUnit.State.RETURNING:
			unit.state = MilitaryUnit.State.RESERVE
			game.events.debug("%s is back in the reserve" % unit.label())
	unit.walker = null
	s.queue_free()
	changed.emit()
