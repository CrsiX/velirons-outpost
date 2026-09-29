class_name Army
extends Node
## Military units: bought with gold, kept in reserve, and sent to posts
## (towers, training grounds, barracks benches). Equipping and unequipping take
## time: soldiers walk from the village to the post and back before they are
## available again. No cap on military units.
##
## Units have HP (docs/military-design.md §4): they can be hurt outside
## (walking, on barracks sorties), never on towers. At 0 HP a unit is downed;
## after Config.unit_revive_time it's back, on its barracks bench if it
## belonged to one, else in the reserve. Units heal Config.UNIT_REGEN HP/s on
## benches and unused in the reserve. Barracks turn their benches out when
## enemies come near (sortie); units walk back when none are left.

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


func downed() -> Array[MilitaryUnit]:
	return _in_state(MilitaryUnit.State.DOWNED)


func walking() -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.state in [MilitaryUnit.State.MARCHING, MilitaryUnit.State.RETURNING, MilitaryUnit.State.TRAVELLING])


func _in_state(s: int) -> Array[MilitaryUnit]:
	return units.filter(func(u: MilitaryUnit) -> bool: return u.state == s)


func recruit(kind: String) -> MilitaryUnit:
	if not game.is_unlocked(kind) or not Config.MILITARY[kind].get("recruit", false) or not village.economy.spend(Config.MILITARY[kind]["cost"]):
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


# --- time: reviving and healing -------------------------------------------------------

func _process(delta: float) -> void:
	if game == null or game.is_client:
		return
	for u in units:
		match u.state:
			MilitaryUnit.State.DOWNED:
				u.revive_left -= delta
				if u.revive_left <= 0.0:
					revive(u)
			MilitaryUnit.State.RESERVE:
				u.heal(Config.UNIT_REGEN * delta)
			MilitaryUnit.State.STATIONED:
				if u.post is Barracks and not u.out:
					u.heal(Config.UNIT_REGEN * delta)  # resting on the bench


# --- stationing --------------------------------------------------------------------------

## "" if `unit` can be sent to `post`, else the reason.
func station_error(unit: MilitaryUnit, post: MilitaryPost) -> String:
	if unit == null or unit.state != MilitaryUnit.State.RESERVE:
		return "That unit isn't in the reserve" if unit == null or not unit.is_downed() else "It's downed: wait until it's back"
	return _post_error(unit, post, village.center)


func _post_error(unit: MilitaryUnit, post: MilitaryPost, from: Vector2i) -> String:
	if post == null or not post.can_garrison():
		return "Pick a finished tower, barracks or training grounds"
	if post.village != unit.village:
		return "That isn't your tower"
	if not unit.fits(post.post_kind()):
		return "A %s can't serve %s" % [unit.display_name().to_lower(), "on towers" if post.post_kind() == "tower" else "in barracks"]
	if post.free_slot() < 0:
		if post.capacity() == 1:
			return "A unit is already marching there" if post.incoming != null else "Already manned: withdraw its unit first"
		return "Every bench is taken"
	if game.world.pathing.find_path(from, post.work_tile()).is_empty():
		return "No path there"
	return ""


## Sends a reserve unit out of the village to a free slot of `post`.
func station(unit: MilitaryUnit, post: MilitaryPost) -> bool:
	if station_error(unit, post) != "":
		return false
	village.events.debug("send %s from the reserve to %s" % [unit.label(), post.label()])
	var s := _spawn_walker(unit, village.center)
	s.walk_to(post.work_tile())
	_reserve_slot(unit, post)
	Sfx.play("place")
	changed.emit()
	return true


func _reserve_slot(unit: MilitaryUnit, post: MilitaryPost) -> void:
	unit.state = MilitaryUnit.State.MARCHING
	unit.post = post
	unit.slot = post.free_slot()
	post.incoming_slots[unit.slot] = unit
	post.refresh()


## "" if the stationed `unit` can move straight over to `post`, else why not.
func transfer_error(unit: MilitaryUnit, post: MilitaryPost) -> String:
	if unit == null or unit.state != MilitaryUnit.State.STATIONED:
		return "That unit isn't on duty"
	if post == unit.post:
		return "Pick another finished tower, barracks or training grounds"
	return _post_error(unit, post, unit.post.work_tile())


## Moves a stationed unit from its post straight to another (drag & drop);
## it walks over and takes up the new post on arrival.
func transfer(unit: MilitaryUnit, post: MilitaryPost) -> bool:
	if transfer_error(unit, post) != "":
		return false
	var from := unit.post
	village.events.debug("move %s from %s to %s" % [unit.label(), from.label(), post.label()])
	var start := _leave_post(unit)
	var s := _body(unit, start)
	s.walk_to(post.work_tile())
	_reserve_slot(unit, post)
	Sfx.play("place")
	changed.emit()
	return true


## Takes `unit` off its post's slot; returns where its body starts walking.
func _leave_post(unit: MilitaryUnit) -> Vector2i:
	var post := unit.post
	var start := post.work_tile() if is_instance_valid(post) else village.center
	if unit.out and is_instance_valid(unit.walker):
		start = (unit.walker as Soldier).current_tile()
		unit.behavior.on_leave(unit.walker, unit)
	unit.out = false
	if is_instance_valid(post) and unit.slot < post.slots.size() and post.slots[unit.slot] == unit:
		post.set_slot(unit.slot, null)
	return start


## The unit's body outside: its sortie body if it has one, else a new one at `from`.
func _body(unit: MilitaryUnit, from: Vector2i) -> Soldier:
	if is_instance_valid(unit.walker):
		var s := unit.walker as Soldier
		s.mode = Soldier.Mode.WALK
		return s
	return _spawn_walker(unit, from)


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


## Pulls a unit off its post (or turns it around mid-march) and walks it home.
func unstation(unit: MilitaryUnit) -> void:
	match unit.state:
		MilitaryUnit.State.STATIONED:
			village.events.debug("withdraw %s from %s" % [unit.label(), unit.post.label()])
			var start := _leave_post(unit)
			_send_home(unit, _body(unit, start))
		MilitaryUnit.State.MARCHING:
			village.events.debug("call %s back on its way to %s" % [unit.label(), unit.post.label() if is_instance_valid(unit.post) else "its post"])
			_free_reservation(unit)
			_send_home(unit, unit.walker)
		_:
			return
	changed.emit()


## The post is being torn down: every unit on it (or marching to it) walks
## back to the town centre into the reserve; downed ones revive there.
func eject(post: Building) -> void:
	if not (post is MilitaryPost):
		return
	for u in units.duplicate():
		if u.post != post:
			continue
		match u.state:
			MilitaryUnit.State.STATIONED, MilitaryUnit.State.MARCHING:
				unstation(u)
			MilitaryUnit.State.DOWNED:
				if u.revive_at_post and u.slot < post.slots.size() and post.slots[u.slot] == u:
					post.set_slot(u.slot, null)
				u.revive_at_post = false
				u.post = null
	post.refresh()
	changed.emit()


func _free_reservation(unit: MilitaryUnit) -> void:
	var p := unit.post
	if is_instance_valid(p) and unit.slot < p.incoming_slots.size() and p.incoming_slots[unit.slot] == unit:
		p.incoming_slots[unit.slot] = null
		p.refresh()


# --- barracks sorties -----------------------------------------------------------------------

## A unit on a barracks bench goes out to fight (near the barracks, or to
## guard `farm` against rats).
func sortie(unit: MilitaryUnit, farm: Farm = null) -> void:
	if unit.state != MilitaryUnit.State.STATIONED or unit.out or not (unit.post is Barracks):
		return
	var b := unit.post as Barracks
	unit.out = true
	var s := _spawn_walker(unit, b.work_tile())
	s.start_sortie(b, farm)
	b.refresh()
	changed.emit()


## Back on the bench after a sortie.
func back_to_bench(unit: MilitaryUnit) -> void:
	if is_instance_valid(unit.walker):
		unit.behavior.on_leave(unit.walker, unit)
		unit.walker.queue_free()
	unit.walker = null
	unit.out = false
	if is_instance_valid(unit.post):
		unit.post.refresh()
	changed.emit()


# --- downed and back ------------------------------------------------------------------------

## HP ran out (only possible outside). It vanishes and comes back later: on its
## barracks bench if it belongs to barracks, else in the reserve.
func down(unit: MilitaryUnit, source = null) -> void:
	if unit.is_downed():
		return
	var at_bench := unit.state == MilitaryUnit.State.STATIONED and unit.post is Barracks
	village.events.info("%s was downed by %s" % [unit.label().capitalize(), game.who(source)])
	if is_instance_valid(unit.walker):
		unit.behavior.on_leave(unit.walker, unit)
		(unit.walker as Soldier).vanish()
	unit.walker = null
	unit.out = false
	if unit.state == MilitaryUnit.State.MARCHING:
		_free_reservation(unit)
	if not at_bench:
		if is_instance_valid(unit.post) and unit.state == MilitaryUnit.State.STATIONED:
			unit.post.set_slot(unit.slot, null)
		unit.post = null
	unit.travel_to = null  # (downed on the way: it never got there)
	unit.revive_at_post = at_bench
	unit.hp = 0.0
	unit.revive_left = Config.unit_revive_time(unit.level) * maxf(0.2, 1.0 + village.relic_bonus("revive"))
	unit.state = MilitaryUnit.State.DOWNED
	if at_bench:
		unit.post.refresh()
	Sfx.play("death", 0.2)
	changed.emit()


func revive(unit: MilitaryUnit) -> void:
	unit.hp = unit.max_hp()
	unit.revive_left = 0.0
	if unit.revive_at_post and is_instance_valid(unit.post) and unit.post.slots[unit.slot] == unit:
		unit.state = MilitaryUnit.State.STATIONED
		unit.post.refresh()
	else:
		unit.state = MilitaryUnit.State.RESERVE
		unit.post = null
	unit.revive_at_post = false
	village.events.info("%s is back on its feet" % unit.label().capitalize())
	changed.emit()


# --- training and upgrading --------------------------------------------------------------------

## Passes up to `amount` of the hero's XP on to `unit` (training grounds).
## When the unit has collected enough it levels up for free (never into a
## specialisation). Returns the XP used.
func train(unit: MilitaryUnit, amount: int) -> int:
	if amount <= 0 or not unit.can_train():
		return 0
	var used := clampi(ceili(unit.train_xp_needed() - unit.train_xp), 0, amount)
	unit.train_xp += used
	if unit.train_xp >= unit.train_xp_needed() - 0.001:
		_set_level(unit, unit.kind, unit.level + 1)
		village.events.info("%s fully trained to level %d%s" % [unit.label(), unit.level + 1, " at %s" % unit.post.label() if unit.post else ""])
		if unit.post:
			game.world.float_text("%s level %d!" % [unit.display_name(), unit.level + 1], unit.post.position + Vector2(0, -90), UiTheme.GOLD)
		Sfx.play("build")
		changed.emit()
	return used


## "" if `unit` can take upgrade `to` (its own kind: the next level; a
## specialisation: its level 1) now, else why not.
func upgrade_error(unit: MilitaryUnit, to: String = "") -> String:
	if unit == null or not unit.is_available():
		return "Not now: it's downed or away"
	var kind := unit.kind if to == "" else to
	for opt in unit.upgrade_options():
		if opt["to"] == kind and not opt["archmage"]:
			if not village.economy.can_afford(opt["cost"]):
				return "Not enough gold"
			if unit.post and unit.state != MilitaryUnit.State.RESERVE and not MilitaryUnit.new(kind).fits(unit.post.post_kind()):
				return "It can't stay on this post as a %s" % Config.MILITARY[kind]["name"].to_lower()
			return ""
	return "Already at max level" if kind == unit.kind else "It can't become that"


## Next level of its own kind (`to` empty or its kind), or level 1 of a
## specialisation `to` (from BRANCH_MIN_LEVEL on). Paid in gold.
func upgrade(unit: MilitaryUnit, to: String = "") -> bool:
	if upgrade_error(unit, to) != "":
		return false
	var kind := unit.kind if to == "" else to
	var opt: Dictionary = unit.upgrade_options().filter(func(o: Dictionary) -> bool: return o["to"] == kind)[0]
	village.economy.spend(opt["cost"])
	var was := unit.display_name()
	var was_kind := unit.kind
	_set_level(unit, kind, opt["level"])
	if kind == was_kind:
		village.events.debug("level-up %s to level %d for %s" % [unit.label(), unit.level + 1, Config.cost_text(opt["cost"])])
	else:
		village.events.info("%s trained as a %s" % [was, unit.display_name()])
	Sfx.play("build")
	changed.emit()
	return true


func _set_level(unit: MilitaryUnit, kind: String, level: int) -> void:
	var ratio := unit.hp / maxf(unit.max_hp(), 1.0)
	if kind != unit.kind:
		unit.behavior.on_leave(unit.walker if unit.out else unit.post, unit)
		unit.set_kind(kind)
	unit.level = level
	unit.train_xp = 0.0  # training was towards the level just reached
	unit.hp = unit.max_hp() * maxf(ratio, 0.0) if unit.is_downed() else unit.max_hp()
	if is_instance_valid(unit.post):
		unit.post.refresh()


## "" if `unit` (a spatial mage of ARCHMAGE_LEVEL) can become the Spatial
## Archmage now, else why not.
func archmage_error(unit: MilitaryUnit) -> String:
	if unit == null or not unit.upgrade_options().any(func(o: Dictionary) -> bool: return o["archmage"]):
		return "Only a level %d spatial mage can become the Spatial Archmage" % Config.ARCHMAGE_LEVEL
	if not unit.is_available():
		return "Not now: it's downed or away"
	if village.population.free_huts().is_empty():
		return "The Spatial Archmage needs a free hut"
	if not village.economy.can_afford(Config.ARCHMAGE_COST):
		return "Not enough gold"
	return ""


## The spatial mage leaves the army for good and moves into a hut as the
## Spatial Archmage, a civilian.
func promote_archmage(unit: MilitaryUnit) -> Civilian:
	if archmage_error(unit) != "":
		return null
	village.economy.spend(Config.ARCHMAGE_COST)
	match unit.state:
		MilitaryUnit.State.STATIONED:
			_leave_post(unit)
		MilitaryUnit.State.MARCHING:
			_free_reservation(unit)
	if is_instance_valid(unit.walker):
		unit.walker.queue_free()
	unit.walker = null
	units.erase(unit)
	game.unregister(unit.nid)
	var civ := village.population.spawn("spatial_archmage")
	village.events.info("%s has become the Spatial Archmage" % unit.label().capitalize())
	game.world.float_text("The Spatial Archmage!", Iso.tile_to_world(village.center) + Vector2(0, -60), Color("c9a8ff"))
	Sfx.play("build")
	changed.emit()
	return civ


# --- bodies --------------------------------------------------------------------------------

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
			var post := unit.post
			if not is_instance_valid(post) or not post.can_garrison():
				_send_home(unit, s)
				return
			post.incoming_slots[unit.slot] = null
			post.set_slot(unit.slot, unit)
			unit.state = MilitaryUnit.State.STATIONED
			village.events.debug("%s takes up its post on %s" % [unit.label(), post.label()])
		MilitaryUnit.State.RETURNING:
			unit.state = MilitaryUnit.State.RESERVE
			village.events.debug("%s is back in the reserve" % unit.label())
		MilitaryUnit.State.TRAVELLING:
			unit.travel_to.army.adopt(unit)
		MilitaryUnit.State.STATIONED:
			if unit.out:  # back from a sortie
				back_to_bench(unit)
				return
	unit.walker = null
	s.set_process(false)
	s.queue_free()
	changed.emit()
