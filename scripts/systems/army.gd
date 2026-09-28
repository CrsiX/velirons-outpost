class_name Army
extends Node
## Military units: bought with gold, kept in reserve, and sent to towers.
## Equipping and unequipping take time: soldiers walk from the village to the
## tower and back before they are available again. No cap on military units.

signal changed

const SOLDIER_SCRIPT := preload("res://scripts/units/soldier.gd")

var game: Game
## The village this army belongs to.
var village: Village
var units: Array[MilitaryUnit] = []


func setup(p_village: Village) -> void:
	village = p_village
	game = village.game


func reserve() -> Array[MilitaryUnit]:
	return _in_state(MilitaryUnit.State.RESERVE)


func stationed() -> Array[MilitaryUnit]:
	return _in_state(MilitaryUnit.State.STATIONED)


func walking() -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.state in [MilitaryUnit.State.MARCHING, MilitaryUnit.State.RETURNING, MilitaryUnit.State.TRAVELLING])


func _in_state(s: int) -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.state == s)


func recruit(kind: String) -> MilitaryUnit:
	if not village.economy.spend(Config.MILITARY[kind]["cost"]):
		return null
	var u := MilitaryUnit.new(kind)
	u.village = village
	u.original_owner = village
	u.nid = game.register(u)
	u.uid = game.next_id(kind)
	units.append(u)
	village.events.debug("recruit %s for %s" % [u.label(), Config.cost_text(Config.MILITARY[kind]["cost"])])
	Sfx.play("recruit")
	changed.emit()
	return u


## "" if `unit` can be sent to `tower`, else the reason.
func station_error(unit: MilitaryUnit, tower: MilitaryPost) -> String:
	if unit == null or unit.state != MilitaryUnit.State.RESERVE:
		return "That unit isn't in the reserve"
	if tower == null or not tower.can_garrison():
		return "Pick a finished tower or training grounds"
	if tower.village != unit.village:
		return "That isn't your tower"
	if tower.incoming != null:
		return "A unit is already marching there"
	if tower.garrison != null:
		return "Already manned: withdraw its unit first"
	if game.world.pathing.find_path(village.center, tower.work_tile()).is_empty():
		return "No path there"
	return ""


## Sends a reserve unit out of the village to man `tower` (any military post).
func station(unit: MilitaryUnit, tower: MilitaryPost) -> bool:
	if station_error(unit, tower) != "":
		return false
	village.events.debug("send %s from the reserve to %s" % [unit.label(), tower.label()])
	var s := _spawn_walker(unit, village.center)
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
	if post.village != unit.village:
		return "That isn't your tower"
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
	village.events.debug("move %s from %s to %s" % [unit.label(), from.label(), post.label()])
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


## "" if the reserve `unit` can be sent to `target` (another village), else why not.
func send_error(unit: MilitaryUnit, target: Village) -> String:
	if unit == null or unit.state != MilitaryUnit.State.RESERVE:
		return "Only units in the reserve can be sent"
	if target == null or target == village:
		return "Pick another village"
	if game.world.pathing.find_path(village.center, target.center).is_empty():
		return "No road to that village"
	return ""


## Sends a reserve unit to another village. It walks there from this village's
## centre and can't be recalled; entering that village's walls, it joins that
## village's army (see _on_arrived).
func send(unit: MilitaryUnit, target: Village) -> bool:
	if send_error(unit, target) != "":
		return false
	var s := _spawn_walker(unit, village.center)
	s.walk_to(target.center)
	unit.state = MilitaryUnit.State.TRAVELLING
	unit.travel_to = target
	village.events.debug("send %s to %s" % [unit.label(), target.village_name])
	Sfx.play("place")
	changed.emit()
	return true


## Takes in a unit sent here by another village: from now on it's ours.
func adopt(unit: MilitaryUnit) -> void:
	var from := unit.village
	if from and from.army != self:
		from.army.units.erase(unit)
		from.army.changed.emit()
	unit.village = village
	unit.travel_to = null
	unit.state = MilitaryUnit.State.RESERVE
	unit.post = null
	units.append(unit)
	village.events.info("%s arrived from %s" % [unit.display_name(), from.village_name if from else "afar"])
	if from:
		from.events.debug("%s reached %s" % [unit.label(), village.village_name])
	changed.emit()


## Pulls a unit off its tower (or turns it around mid-march) and walks it home.
func unstation(unit: MilitaryUnit) -> void:
	match unit.state:
		MilitaryUnit.State.STATIONED:
			var tower := unit.post
			village.events.debug("withdraw %s from %s" % [unit.label(), tower.label()])
			tower.set_garrison(null)
			_send_home(unit, _spawn_walker(unit, tower.work_tile()))
		MilitaryUnit.State.MARCHING:
			village.events.debug("call %s back on its way to %s" % [unit.label(), unit.post.label() if is_instance_valid(unit.post) else "its post"])
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
		village.events.info("%s fully trained to level %d%s" % [unit.label(), unit.level + 1, " at %s" % unit.post.label() if unit.post else ""])
		if unit.post:
			unit.post.refresh()
			game.world.float_text("%s level %d!" % [unit.display_name(), unit.level + 1], unit.post.position + Vector2(0, -90), UiTheme.GOLD)
		Sfx.play("build")
		changed.emit()
	return used


func upgrade(unit: MilitaryUnit) -> bool:
	if not unit.can_upgrade() or not village.economy.spend(unit.upgrade_cost()):
		return false
	unit.level += 1
	unit.train_xp = 0.0  # training was towards the level just bought
	village.events.debug("level-up %s to level %d for %s" % [unit.label(), unit.level + 1, Config.cost_text(unit.spec()["levels"][unit.level]["cost"])])
	if unit.post and unit.state == MilitaryUnit.State.STATIONED:
		unit.post.refresh()
	Sfx.play("build")
	changed.emit()
	return true


func _spawn_walker(unit: MilitaryUnit, from: Vector2i) -> Soldier:
	var s: Soldier = SOLDIER_SCRIPT.new()
	s.setup(game, unit, from)
	s.nid = game.register(s)
	s.arrived.connect(_on_arrived)
	game.world.objects.add_child(s)
	unit.walker = s
	return s


func _send_home(unit: MilitaryUnit, s: Soldier) -> void:
	unit.state = MilitaryUnit.State.RETURNING
	unit.post = null
	if not s.walk_to(village.center):
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
			village.events.debug("%s takes up its post on %s" % [unit.label(), tower.label()])
		MilitaryUnit.State.RETURNING:
			unit.state = MilitaryUnit.State.RESERVE
			village.events.debug("%s is back in the reserve" % unit.label())
		MilitaryUnit.State.TRAVELLING:
			unit.travel_to.army.adopt(unit)
	unit.walker = null
	s.set_process(false)
	s.queue_free()
	changed.emit()
