class_name MountedBehavior
extends MeleeBehavior
## A rider while its mount lives (Enemy.mount; docs/enemies-design.md §15e;
## numbers: Config.MOUNTED):
##   ROAD   - runs its road to the village (the Enemy walks it);
##   CIRCLE - within `approach` tiles of its village's walls it rides round the
##            village, `ring` tiles outside them; it never breaks in mounted;
##   IN     - a broken gate or wall leaves an open way into its village (no
##            intact barrier on it): it rides in like anyone on foot (the
##            Enemy's siege field, Enemy.ride_in) and burns a hut; a barrier
##            in its way sends it back to circling;
##   GATE   - after `circle_time` s at the village without a blow it rides to
##            the nearest gate and gets off there (Enemy.dismount, not slain):
##            the rider breaks in on foot;
##   HUNT   - rides at a target of ours within `hunt_radius` ("hunts": "all":
##            anyone outside, villagers too; "melee": melee fighters only) and
##            fights it; gives up beyond `chase` tiles;
##   ESCORT - a Legion rider ("escort") keeps within `escort_radius` of the
##            nearest Legion soldier on foot, hunting from there.
## A scenario's errand (Enemy.errand: scenario 9's Lysa at the head of her
## LegionCompany) leads it instead: see _on_errand.
## A charge (Enemy.charge_ready) does charge_x times the damage, unless the
## foe breaks charges (a halberdier). On foot it is a MeleeBehavior (a
## captain or a commander; a raider or cavalry turns into its rider's kind).

enum State { ROAD, CIRCLE, GATE, HUNT, ESCORT, IN }

var state := State.ROAD
var _prey: Node = null
var _lead: Enemy = null
var _think := 0.0
var _repath := 0.0
## Seconds at the village without a blow (GATE once circle_time).
var _calm := 0.0
var _ring := PackedVector2Array()
var _ring_i := 0
var _ring_dir := 1
var _gate_t := 0.0
## Targets it can't get at without riding through a village: target -> Game.clock until when it leaves them be.
var _skip := {}
## Whether its village has an open way in (looked at every second), and till
## when it believes it hasn't (a barrier stood in its way).
var _open := false
var _open_at := -INF
var _closed_until := -INF


func tick(enemy: Enemy, delta: float) -> bool:
	if enemy.mount == "":
		return super.tick(enemy, delta)
	if enemy.retreating or not enemy.targetable():
		return false
	if enemy.errand != null:
		_on_errand(enemy, delta)
		return super.tick(enemy, delta)
	var m := Config.MOUNTED
	_attack_timer -= delta
	if state == State.CIRCLE or state == State.GATE or _at_village(enemy):
		_calm += delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		_choose(enemy, m)
	match state:
		State.HUNT:
			return _hunt(enemy, delta)
		State.ESCORT:
			return _escort(enemy, delta, m)
		State.CIRCLE:
			return _circle(enemy, delta)
		State.GATE:
			return _gate(enemy, delta)
		State.IN:
			if enemy.sieging and is_instance_valid(enemy.breach):
				_closed_until = enemy.game.clock + 5.0  # (a wall after all: round again)
				_start_circle(enemy)
				return true
			var v := enemy.target_village
			if enemy.sieging or enemy.game.siege.in_zone(v, enemy.current_tile()):
				return false  # (the Enemy rides the siege field in)
			if not _ride_to(enemy, delta, Vector2(v.center)):
				_closed_until = enemy.game.clock + 5.0
				_start_circle(enemy)
			return true
	return false  # (ROAD: the Enemy walks it)


## The end of its road (a gate) while mounted: it rides round instead.
func on_path_end(enemy: Enemy) -> bool:
	if enemy.mount == "":
		return super.on_path_end(enemy)
	if enemy.errand != null:
		return not enemy.ride_in  # (it waits by the gate; through a breach it rides in)
	if state != State.GATE:
		_start_circle(enemy)
	return true


## Led by a scenario's errand: it rides where the errand sends it (the Enemy
## walks its path) and fights what comes within reach (MeleeBehavior: no
## charge, see Enemy._tick_ride); it hunts, escorts and circles nobody. Waiting at its
## village (its path ended there) it rides in through an open breach; with
## none after `circle_time` it gets off (the mount runs off) and breaks in
## on foot.
func _on_errand(enemy: Enemy, delta: float) -> void:
	var waiting := enemy.path_index >= enemy.path.size() and _at_village(enemy) and not enemy.game.map.in_village(enemy.current_tile())
	_calm = _calm + delta if waiting and not enemy.ride_in else 0.0
	_think -= delta
	if _think <= 0.0 and waiting:
		_think = 1.0
		enemy.ride_in = _breach_open(enemy)
	if _calm >= float(Config.MOUNTED["circle_time"]):
		enemy.dismount(null, false)



## Named riders (the campaign's captains, Rhodri) are told about.
func on_dismount(enemy: Enemy, slain: bool) -> void:
	if slain and enemy.given_name != "" and is_instance_valid(enemy.target_village):
		enemy.target_village.events.info("%s's horse falls! %s fights on foot" % [enemy.label(), enemy.label()])


## What to do now: a target first; a Legion rider stays with its soldiers;
## at the village it circles until circle_time is up, then gets off at a gate.
func _choose(enemy: Enemy, m: Dictionary) -> void:
	if state == State.GATE:
		return
	if state != State.IN:
		_stop_riding_in(enemy)
	var prey := _find_prey(enemy, m)
	if prey != null:
		if prey != _prey:
			enemy.game.log_for(prey, EventLog.Level.DEBUG, "%s rides at %s" % [enemy.label(), prey.label()])
		_prey = prey
		_set_state(enemy, State.HUNT)
		return
	_prey = null
	_lead = _nearest_lead(enemy) if enemy.spec().get("escort", enemy.kind.begins_with("legion_")) else null
	if _lead != null:
		_set_state(enemy, State.ESCORT)
		return
	if _at_village(enemy):
		if _breach_open(enemy):
			if state != State.IN:
				enemy.target_village.events.debug("%s rides in through the breach" % enemy.label())
			state = State.IN
			enemy.ride_in = true
		elif state == State.IN:
			_start_circle(enemy)
		elif _calm >= float(m["circle_time"]):
			_start_gate(enemy)
		elif state != State.CIRCLE:
			_start_circle(enemy)
	elif state != State.ROAD:
		_to_road(enemy)


func _set_state(enemy: Enemy, s: State) -> void:
	state = s
	if s != State.IN:
		_stop_riding_in(enemy)


func _stop_riding_in(enemy: Enemy) -> void:
	enemy.ride_in = false
	if enemy.sieging:
		enemy.leave_siege()


## An open way into its village: the way anyone on foot would break in
## (the siege field, from the edge of its zone nearest the rider) reaches a
## hut without an intact gate, wall or wall tower on it (a broken one lets it
## through).
func _breach_open(enemy: Enemy) -> bool:
	var game := enemy.game
	if game.clock < _closed_until:
		return false
	if game.clock - _open_at < 1.0:
		return _open
	_open_at = game.clock
	_open = false
	var v := enemy.target_village
	var siege := game.siege
	var zone := v.rect.grow(int(Config.SIEGE["approach"]))
	var t := enemy.current_tile()
	t = Vector2i(clampi(t.x, zone.position.x, zone.end.x - 1), clampi(t.y, zone.position.y, zone.end.y - 1))
	if siege.value(v, t, false) >= Siege.BLOCKED:
		return false
	for i in 4 * zone.size.x:
		if siege.hut_at(v, t) != null:
			_open = true
			break
		var n := siege.next_step(v, t, false)
		if n == t or siege.barrier_at(v, n) != null:
			break
		t = n
	return _open


func _at_village(enemy: Enemy) -> bool:
	var v := enemy.target_village
	return is_instance_valid(v) and Hero.rect_distance(v.rect, enemy.grid_pos) <= float(Config.MOUNTED["approach"])


## Its current target while it is still worth chasing, else the nearest one
## within hunt_radius: "all" hunts anyone of ours outside (the hero, soldiers,
## summons, villagers out of shelter), "melee" only melee fighters (the hero,
## melee soldiers, summons). Never inside a village's walls.
func _find_prey(enemy: Enemy, m: Dictionary) -> Node:
	var all := str(enemy.spec().get("hunts", "melee")) == "all"
	if _prey_ok(_prey, all) and _prey.grid_pos.distance_to(enemy.grid_pos) <= float(m["chase"]) and not _skipped(enemy, _prey):
		return _prey
	var best: Node = null
	var best_d := float(m["hunt_radius"])
	var groups := ["melee_defenders", "villagers"] if all else ["melee_defenders"]
	for group in groups:
		for node in enemy.get_tree().get_nodes_in_group(group):
			if not _prey_ok(node, all) or _skipped(enemy, node):
				continue
			var d: float = node.grid_pos.distance_to(enemy.grid_pos)
			if d < best_d:
				best_d = d
				best = node
	return best


func _skipped(enemy: Enemy, node) -> bool:
	return is_instance_valid(node) and _skip.has(node) and enemy.game.clock < float(_skip[node])


static func _prey_ok(node, all: bool) -> bool:
	if not is_instance_valid(node) or node.dead or _sheltered(node):
		return false
	return all or not (node is Soldier and (node as Soldier).unit.role() != "melee")


## The nearest Dread Legion soldier on foot (not itself, not falling back).
static func _nearest_lead(enemy: Enemy) -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for node in enemy.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == enemy or e.dead or e.mount != "" or e.retreating or e.wild() or not e.kind.begins_with("legion_"):
			continue
		var d := e.grid_pos.distance_to(enemy.grid_pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func _hunt(enemy: Enemy, delta: float) -> bool:
	if not is_instance_valid(_prey) or _prey.dead:
		return true  # (it stops; the next think picks what next)
	var to: Vector2 = _prey.grid_pos
	if to.distance_to(enemy.grid_pos) <= Config.SUMMON["attack_range"]:
		enemy.face(to)
		if _attack_timer <= 0.0:
			_strike(enemy, _prey)
		return true
	if not _ride_to(enemy, delta, to):
		_skip[_prey] = enemy.game.clock + 5.0  # (behind the walls: not now)
		_prey = null
		_think = 0.0
	return true


## Keeps near its Legion soldier: rides up while farther than half its
## escort_radius, waits while near.
func _escort(enemy: Enemy, delta: float, m: Dictionary) -> bool:
	if not is_instance_valid(_lead) or _lead.dead:
		return true
	if _lead.grid_pos.distance_to(enemy.grid_pos) <= float(m["escort_radius"]) * 0.5:
		return true
	if not _ride_to(enemy, delta, _lead.grid_pos + enemy._jitter * 5.0):  # (riders side by side, not on one spot)
		_lead = null  # (its soldiers are inside: it waits outside)
	return true


## Rides to `to` (grid), finding its way again every 0.4 s. False when the
## way leads through an intact gate or wall (a rider never breaks one: it stays).
func _ride_to(enemy: Enemy, delta: float, to: Vector2) -> bool:
	_repath -= delta
	if _repath <= 0.0 or enemy.path_index >= enemy.path.size():
		_repath = 0.4
		var p := enemy.game.world.pathing.find_path(enemy.current_tile(), Vector2i(to.round()))
		if p.is_empty():
			p = PackedVector2Array([enemy.grid_pos, to])
		if not open_way(enemy, p):
			enemy.follow(PackedVector2Array([enemy.grid_pos]))
			return false
		p[0] = enemy.grid_pos
		enemy.follow(p)
	enemy.walk_own(delta)
	return true


## Does the way `p` cross no intact gate, wall or wall tower (any village's)?
static func open_way(enemy: Enemy, p: PackedVector2Array) -> bool:
	for q in p:
		var b = enemy.game.map.building_at(Vector2i(q.round()))
		if b is Building and Siege.BARRIERS.has(b.kind) and b.complete and not b.devastated:
			return false
	return true


## One blow: a charge does charge_x x its damage, except on a foe that breaks
## charges (a halberdier: it is spent for nothing).
func _strike(enemy: Enemy, foe: Node) -> void:
	_attack_timer = enemy.stat("attack_cooldown") / enemy.haste()
	_calm = 0.0
	enemy.swing(foe.grid_pos)
	var dmg := enemy.stat("damage")
	if enemy.charge_ready:
		if not breaks_charge(foe):
			dmg *= float(Config.MOUNTED["charge_x"])
			enemy.game.log_for(foe, EventLog.Level.DEBUG, "%s charges %s" % [enemy.label(), foe.label()])
			Combat.burst(enemy.game, "dust", enemy.position, 0.6)
		enemy.spend_charge()
	cleave(enemy, foe)
	enemy.blow(foe, dmg)


## Does `foe` break a rider's charge (a halberdier, MILITARY "breaks_charge")?
static func breaks_charge(foe: Node) -> bool:
	return foe is Soldier and (foe as Soldier).unit.spec().get("breaks_charge", false)


# --- round the village, and off at a gate -------------------------------------------------------

## Round its village, `ring` tiles outside the walls: eight points (corners
## and the middles of the sides) on ground it can walk, from the one nearest
## it, one way round or the other.
func _start_circle(enemy: Enemy) -> void:
	_set_state(enemy, State.CIRCLE)
	var v := enemy.target_village
	if not is_instance_valid(v):
		return
	var pathing := enemy.game.world.pathing
	var r := int(ceil(float(Config.MOUNTED["ring"])))
	var box := v.rect.grow(r)
	var a := box.position
	var b := box.end - Vector2i.ONE
	var mid := (a + b) / 2
	_ring = PackedVector2Array()
	for t in [a, Vector2i(mid.x, a.y), Vector2i(b.x, a.y), Vector2i(b.x, mid.y), b, Vector2i(mid.x, b.y), Vector2i(a.x, b.y), Vector2i(a.x, mid.y)]:
		var w := pathing.nearest_walkable(t)
		if pathing.is_walkable(w):
			_ring.append(Vector2(w))
	if _ring.is_empty():
		return
	_ring_i = 0
	for i in _ring.size():
		if _ring[i].distance_to(enemy.grid_pos) < _ring[_ring_i].distance_to(enemy.grid_pos):
			_ring_i = i
	_ring_dir = 1 if randf() < 0.5 else -1
	_repath = 0.0
	v.events.debug("%s rides round %s" % [enemy.label(), v.village_name])
	_path_to_ring(enemy)


func _path_to_ring(enemy: Enemy) -> void:
	for tries in _ring.size():
		var p := enemy.game.world.pathing.find_path(enemy.current_tile(), Vector2i(_ring[_ring_i].round()))
		if p.size() > 1 and open_way(enemy, p):
			p[0] = enemy.grid_pos
			enemy.follow(p)
			return
		_ring_i = posmod(_ring_i + _ring_dir, _ring.size())
	enemy.follow(PackedVector2Array([enemy.grid_pos]))


func _circle(enemy: Enemy, delta: float) -> bool:
	if _ring.is_empty():
		return true
	if enemy.walk_own(delta):
		_ring_i = posmod(_ring_i + _ring_dir, _ring.size())
		_path_to_ring(enemy)
	return true


## Time's up: to the nearest gate of its village, and off there.
func _start_gate(enemy: Enemy) -> void:
	_set_state(enemy, State.GATE)
	_gate_t = 0.0
	var v := enemy.target_village
	if not is_instance_valid(v):
		enemy.dismount(null, false)
		return
	var best := Vector2i(-1, -1)
	for g in v.gates:
		if best.x < 0 or Vector2(g).distance_to(enemy.grid_pos) < Vector2(best).distance_to(enemy.grid_pos):
			best = g
	var p := PackedVector2Array()
	if best.x >= 0:
		p = enemy.game.world.pathing.find_path(enemy.current_tile(), enemy.game.world.pathing.nearest_walkable(best))
	if p.is_empty():
		p = PackedVector2Array([enemy.grid_pos])
	p[0] = enemy.grid_pos
	enemy.follow(p)
	v.events.debug("%s rides for the gate" % enemy.label())


## On its way to the gate it still fights whoever is in reach; there (or
## after 20 s) it gets off.
func _gate(enemy: Enemy, delta: float) -> bool:
	_gate_t += delta
	for node in enemy.get_tree().get_nodes_in_group("melee_defenders"):
		if not node.dead and node.grid_pos.distance_to(enemy.grid_pos) <= Config.SUMMON["attack_range"]:
			enemy.face(node.grid_pos)
			if _attack_timer <= 0.0:
				_strike(enemy, node)
			return true
	if enemy.walk_own(delta) or _gate_t >= 20.0:
		enemy.dismount(null, false)
	return true


## Back to its road and on to the village (after a hunt or an escort).
func _to_road(enemy: Enemy) -> void:
	_set_state(enemy, State.ROAD)
	var pathing := enemy.game.world.pathing
	var road := pathing.nearest_road(enemy.current_tile())
	var v := enemy.target_village
	var field := v.id if v and enemy.game.villages.size() > 1 and pathing.enemy_distance(road, v.id) < Pathing.UNREACHABLE else -1
	var route := pathing.enemy_route(road, RandomNumberGenerator.new(), field)
	var pts := pathing.find_path(enemy.current_tile(), road)
	if pts.is_empty():
		pts = PackedVector2Array([enemy.grid_pos])
	pts[0] = enemy.grid_pos
	for t in route.slice(1):
		pts.append(Vector2(t))
	enemy.follow(pts)

