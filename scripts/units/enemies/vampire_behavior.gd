class_name VampireBehavior
extends MeleeBehavior
## Vampires (Config.ENEMIES["vampire"]) fight like goblins, and of the HP they
## really take from whatever they hit they get `drain` back (never over
## their max HP). Once, the moment their HP would drop below `bat_below` of
## their max (even to 0), they keep that much and turn into a bat for
## `bat_time` seconds (Enemy.set_airborne): flying over every ground unit,
## at `bat_speed`, and not attacking. A bat at a gate does no harm: it gains
## `bat_gate_heal` of its max HP and flies back the way it came. Landed, the
## vampire takes the road to the village again (and breaks in, if it gets
## there, like any enemy).
## (Flying allied units, should they come, would be the bat's to fight.)

var bat_left := 0.0
var bat_used := false
## The bat turned back at a gate: landed, it needs a road to the village again.
var fled := false
var _walk_speed := 0.0


func tick(enemy: Enemy, delta: float) -> bool:
	if bat_left > 0.0:
		bat_left -= delta
		if bat_left <= 0.0:
			_land(enemy)
		return false  # (a bat only flies on)
	if not bat_used and enemy.hp < enemy.max_hp * float(enemy.spec()["bat_below"]):
		on_hurt(enemy)  # (drained down there by a necromancer's spell)
		return false
	return super.tick(enemy, delta)


## Never killed in one blow: dropping below bat_below of its HP, it keeps
## that much and becomes a bat (once).
func on_hurt(enemy: Enemy) -> void:
	var floor_hp := enemy.max_hp * float(enemy.spec()["bat_below"])
	if bat_used or enemy.hp >= floor_hp:
		return
	enemy.hp = maxf(floor_hp, enemy.hp)
	_turn_bat(enemy)


func _turn_bat(enemy: Enemy) -> void:
	bat_used = true
	bat_left = float(enemy.spec()["bat_time"])
	_foe = null
	_walk_speed = enemy.base_speed if enemy.is_slowed() else enemy.speed
	enemy.speed = float(enemy.spec()["bat_speed"])
	enemy.base_speed = enemy.speed
	enemy.set_airborne(true)
	enemy.game.log_all(EventLog.Level.DEBUG, "%s turns into a bat" % enemy.label())


func _land(enemy: Enemy) -> void:
	bat_left = 0.0
	enemy.speed = _walk_speed
	enemy.base_speed = _walk_speed
	enemy.set_airborne(false)
	enemy.game.log_all(EventLog.Level.DEBUG, "%s lands again" % enemy.label())
	if fled:
		fled = false
		_to_village(enemy)


## A bat at the end of its road: at a gate it heals and turns back; fleeing,
## it hovers there until it lands. (Only a vampire on its feet breaks in.)
func on_path_end(enemy: Enemy) -> bool:
	if bat_left <= 0.0:
		return false
	if not fled:
		var gain := minf(enemy.max_hp * float(enemy.spec()["bat_gate_heal"]), enemy.max_hp - enemy.hp)
		enemy.hp += gain
		enemy.queue_redraw()
		if gain > 0.0:
			enemy.game.world.float_text("+%d {hp}" % ceili(gain), enemy.position + Vector2(0, -60), Color("e05050"))
		enemy.game.log_all(EventLog.Level.DEBUG, "%s reaches a gate as a bat and flies off again" % enemy.label())
		fled = true
		var back := enemy.path.duplicate()
		back.reverse()
		back[0] = enemy.grid_pos
		enemy.follow(back)
	return true


## On the roads from here to its village's gates again.
static func _to_village(enemy: Enemy) -> void:
	var pathing := enemy.game.world.pathing
	var road := pathing.nearest_road(enemy.current_tile())
	var v := enemy.target_village
	var field := v.id if v and enemy.game.villages.size() > 1 and pathing.enemy_distance(road, v.id) < Pathing.UNREACHABLE else -1
	var route := pathing.enemy_route(road, RandomNumberGenerator.new(), field)
	var pts := PackedVector2Array([enemy.grid_pos])
	for t in route:
		pts.append(Vector2(t))
	enemy.follow(pts)


## A blow that drains: back `drain` x the HP the foe really lost.
func _hit(enemy: Enemy, foe: Node) -> void:
	var before := _hp_of(foe)
	super._hit(enemy, foe)
	var lost := before - maxf(_hp_of(foe), 0.0) if is_instance_valid(foe) else before
	if lost > 0.0:
		var gain := minf(lost * float(enemy.spec()["drain"]), enemy.max_hp - enemy.hp)
		if gain > 0.0:
			enemy.hp += gain
			enemy.queue_redraw()
			enemy.game.world.float_text("+%d {hp}" % ceili(gain), enemy.position + Vector2(0, -56), Color("e05050"))


## HP of whatever a vampire bites: a soldier's are its unit's.
static func _hp_of(n: Node) -> float:
	if not is_instance_valid(n):
		return 0.0
	if n is Soldier:
		return (n as Soldier).unit.hp
	return float(n.get("hp"))
