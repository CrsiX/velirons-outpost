class_name CaptainBehavior
extends MountedBehavior
## A Dread Legion captain (Config.ENEMIES["legion_captain"]; the campaign's
## Lysa and Torben, docs/scenarios-design.md §7.7) fights like a footman,
## harder. It is never killed: the moment its HP would drop below
## `retreat_below` of its max, it keeps that much and falls back
## (Enemy.retreating): nothing can target it any more, and it walks back the
## way it came, faster, and leaves the map there. (The story needs them later.)
## A scenario may put it on a horse (MountedBehavior: it rides with its
## column; falling back mounted it is faster still).


func tick(enemy: Enemy, delta: float) -> bool:
	if enemy.retreating:
		return false  # (only walks away)
	return super.tick(enemy, delta)


func on_hurt(enemy: Enemy) -> void:
	var floor_hp := enemy.max_hp * float(enemy.spec()["retreat_below"])
	if enemy.hp >= floor_hp:
		return
	enemy.hp = maxf(floor_hp, enemy.hp) if not enemy.retreating else maxf(enemy.hp, 1.0)
	if not enemy.retreating:
		_fall_back(enemy)


func _fall_back(enemy: Enemy) -> void:
	enemy.retreating = true
	_foe = null
	if enemy.sieging:
		enemy.leave_siege()
	enemy.speed = enemy.base_speed * float(enemy.spec()["retreat_speed"])
	enemy.base_speed = enemy.speed
	enemy.modulate.a = 0.75
	var v := enemy.target_village
	if v:
		v.events.info("%s falls back" % enemy.label().capitalize())
	enemy.follow(_way_back(enemy))


## From where it is to the road it came by (walking: over bridges and land,
## never across deep water, e.g. off scenario 9's island), and back along it
## to its start.
static func _way_back(enemy: Enemy) -> PackedVector2Array:
	var pathing := enemy.game.world.pathing
	var route := pathing.enemy_route(enemy.home_tile, RandomNumberGenerator.new())
	var here := pathing.nearest_road(enemy.current_tile())
	var k := 0
	for i in route.size():
		if Vector2(route[i]).distance_to(Vector2(here)) < Vector2(route[k]).distance_to(Vector2(here)):
			k = i
	var pts := PackedVector2Array([enemy.grid_pos])
	if not route.is_empty():
		var walk := pathing.find_path(enemy.current_tile(), route[k])
		for i in range(1, walk.size() - 1):
			pts.append(walk[i])
	for i in range(k, -1, -1):
		pts.append(Vector2(route[i]))
	return pts


## Back at the map edge: gone (it lives to fight another day).
func on_path_end(enemy: Enemy) -> bool:
	if not enemy.retreating:
		return super.on_path_end(enemy)
	enemy.vanish()
	return true
