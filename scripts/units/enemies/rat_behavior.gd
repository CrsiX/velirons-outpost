class_name RatBehavior
extends EnemyBehavior
## Rats (Config.ENEMIES["rat"]): they don't burn huts, they go for farms.
##   ROAD     - walking the road like any enemy, looking out for a farm within
##              `farm_search`, and for villagers or units within `bite_range`;
##   TO_FARM  - off the road to the farm (walking where villagers can walk);
##   ON_FARM  - wandering about the field, nibbling: the farm grows nothing
##              and each rat eats `farm_eat` of its stored food per second;
##              after `vanish_after` s without being attacked the rat is gone;
##   CHASE    - biting a villager or unit within `bite_range` (very little
##              damage); when it's gone or away, back to the farm or the road.
## Leftover rats all vanish once the wave says so (Waves.rats_leave). A rat
## that gets through a gate eats some of the village's food (Game).

enum State { ROAD, TO_FARM, ON_FARM, CHASE }

var state := State.ROAD
var me: Enemy = null
var farm: Farm = null
var foe: Node = null
var _scan := 0.0
var _bite := 0.0
var _idle := 0.0
var _nibble := 0.0
var _repath := 0.0
var _rng := RandomNumberGenerator.new()


func tick(enemy: Enemy, delta: float) -> bool:
	me = enemy
	if enemy.game.waves.rats_leave:
		_leave_farm()
		enemy.vanish()
		return true
	_bite -= delta
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.3
		_think(enemy)
	match state:
		State.CHASE:
			return _chase(enemy, delta)
		State.TO_FARM:
			if not _farm_ok():
				_to_road(enemy)
				return false
			if enemy.walk_own(delta):
				state = State.ON_FARM
				farm.add_rat(enemy)
				_idle = 0.0
				_nibble = _rng.randf_range(0.6, 1.6)
			return true
		State.ON_FARM:
			return _on_farm(enemy, delta)
	return false


## Something to bite first; otherwise, on the road, a farm to go for.
func _think(enemy: Enemy) -> void:
	if state == State.CHASE:
		return
	var victim := _nearest_victim(enemy, float(enemy.spec()["bite_range"]))
	if victim:
		if state == State.ON_FARM and is_instance_valid(farm):
			farm.remove_rat(enemy)  # (off the field while it bites; it comes back)
		foe = victim
		state = State.CHASE
		_repath = 0.0
		return
	if state == State.ROAD:
		var f := _nearest_farm(enemy, float(enemy.spec()["farm_search"]))
		if f:
			_go_farm(enemy, f)


func _on_farm(enemy: Enemy, delta: float) -> bool:
	if not _farm_ok():
		_to_road(enemy)
		return false
	_idle += delta
	if _idle >= float(enemy.spec()["vanish_after"]):
		enemy.game.log_for(farm, EventLog.Level.DEBUG, "%s had its fill and is gone" % enemy.label())
		_leave_farm()
		enemy.vanish()
		return true
	farm.stored = maxf(0.0, farm.stored - float(enemy.spec()["farm_eat"]) * delta)
	if _nibble > 0.0:
		# Eating the crops: a quick bob and a wiggle of the head.
		_nibble -= delta
		enemy.sprite.position.y = -absf(sin(Time.get_ticks_msec() / 70.0)) * 2.0
		enemy.sprite.rotation = sin(Time.get_ticks_msec() / 45.0) * 0.12
		if _nibble <= 0.0:
			enemy.sprite.position.y = 0.0
			enemy.sprite.rotation = 0.0
			var tiles := farm.tiles()
			var to := Vector2(tiles[_rng.randi() % tiles.size()]) + Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4))
			enemy.follow(PackedVector2Array([enemy.grid_pos, to]))
		return true
	if enemy.walk_own(delta):
		_nibble = _rng.randf_range(0.8, 2.0)
	return true


func _chase(enemy: Enemy, delta: float) -> bool:
	var reach := float(enemy.spec()["bite_range"])
	var lost: bool = not is_instance_valid(foe) or foe.dead or (foe is Civilian and not (foe is Hero) and not (foe as Civilian).is_exposed()) or foe.grid_pos.distance_to(enemy.grid_pos) > reach * 1.6
	if lost:
		foe = null
		if _farm_ok():
			_go_farm(enemy, farm)
			return true
		var f := _nearest_farm(enemy, float(enemy.spec()["farm_search"]))
		if f:
			_go_farm(enemy, f)
			return true
		_to_road(enemy)
		return false
	var d: float = foe.grid_pos.distance_to(enemy.grid_pos)
	if d <= Config.SUMMON["attack_range"]:
		enemy.face(foe.grid_pos)
		if _bite <= 0.0:
			_bite = float(enemy.spec()["attack_cooldown"])
			enemy.swing(foe.grid_pos)
			foe.take_damage(enemy.stat("damage"), enemy)
		return true
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.4
		var p := enemy.game.world.pathing.find_path(enemy.current_tile(), Vector2i(foe.grid_pos.round()))
		if p.is_empty():
			p = PackedVector2Array([enemy.grid_pos, foe.grid_pos])
		p[0] = enemy.grid_pos
		enemy.follow(p)
	enemy.walk_own(delta)
	return true


func on_damaged(_enemy: Enemy, _source: Node) -> void:
	_idle = 0.0  # (someone is after it: it stays)


## Villagers outside and units (the hero, soldiers, elementals) within `r`.
static func _nearest_victim(enemy: Enemy, r: float) -> Node:
	var best: Node = null
	var best_d := r
	for group in ["villagers", "melee_defenders"]:
		for node in enemy.get_tree().get_nodes_in_group(group):
			if node.dead or (node is Civilian and not (node is Hero) and not (node as Civilian).is_exposed()):
				continue
			var d: float = node.grid_pos.distance_to(enemy.grid_pos)
			if d <= best_d:
				best_d = d
				best = node
	return best


static func _nearest_farm(enemy: Enemy, r: float) -> Farm:
	var best: Farm = null
	var best_d := r
	for b in enemy.game.world.buildings:
		if b is Farm and b.working():
			var d := Vector2(b.tile).distance_to(enemy.grid_pos)
			if d <= best_d:
				best_d = d
				best = b
	return best


func _farm_ok() -> bool:
	return is_instance_valid(farm) and farm.working() and farm.is_inside_tree()


func _go_farm(enemy: Enemy, f: Farm) -> void:
	var tiles := f.tiles()
	var to := tiles[_rng.randi() % tiles.size()]
	var p := enemy.game.world.pathing.find_path(enemy.current_tile(), to)
	if p.is_empty():
		return
	p[0] = enemy.grid_pos
	if farm != f:
		_leave_farm()
	farm = f
	enemy.follow(p)
	state = State.TO_FARM
	enemy.game.log_for(f, EventLog.Level.DEBUG, "%s runs for %s" % [enemy.label(), f.label()])


func _leave_farm() -> void:
	if is_instance_valid(farm) and me:
		farm.remove_rat(me)
	farm = null


## Back to the road and on towards its village's gates.
func _to_road(enemy: Enemy) -> void:
	_leave_farm()
	state = State.ROAD
	enemy.sprite.position.y = 0.0
	enemy.sprite.rotation = 0.0
	var pathing := enemy.game.world.pathing
	var road := pathing.nearest_road(enemy.current_tile())
	var v := enemy.target_village
	var field := v.id if v and enemy.game.villages.size() > 1 and pathing.enemy_distance(road, v.id) < Pathing.UNREACHABLE else -1
	var route := pathing.enemy_route(road, _rng, field)
	var pts := pathing.find_path(enemy.current_tile(), road)
	if pts.is_empty():
		pts = PackedVector2Array([enemy.grid_pos])
	pts[0] = enemy.grid_pos
	for t in route.slice(1):
		pts.append(Vector2(t))
	enemy.follow(pts)
