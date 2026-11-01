class_name ThiefBehavior
extends MeleeBehavior
## Thieves (Config.ENEMIES["thief"]) fight like goblins on the way. At a gate
## they burn nothing: they steal gold (Game.thief_steals) and run back the way
## they came, carrying it (Enemy.loot_gold, shown as a sack). Back at the map
## edge they are gone with it; killed on the way, their corpse holds it.
## Where their village has a standing guild warehouse (Warehouse, scenario 4)
## they go for that instead: along their road to where it passes nearest the
## warehouse, then across to it; there they plunder it and steal the same way.

var escaping := false
## The warehouse it is after (null: the gate).
var store: Warehouse = null
var _routed := false


func tick(enemy: Enemy, delta: float) -> bool:
	if not _routed and not enemy.game.is_client:
		_routed = true
		_route_to_store(enemy)
	return super.tick(enemy, delta)


func on_path_end(enemy: Enemy) -> bool:
	if escaping:
		var v := enemy.target_village
		if v and enemy.loot_gold > 0:
			v.events.info("%s got away with %d gold" % [enemy.label().capitalize(), enemy.loot_gold])
		enemy.vanish()
		return true
	if store != null:
		if is_instance_valid(store) and store.raidable():
			store.plunder(enemy)
			enemy.set_loot(enemy.game.thief_steals(enemy, store))
	else:
		enemy.set_loot(enemy.game.thief_steals(enemy))
	escaping = true
	note(enemy, "%s runs back the way it came with %d gold" % [enemy.label(), enemy.loot_gold])
	var back := enemy.path.duplicate()
	back.reverse()
	back[0] = enemy.grid_pos
	enemy.follow(back)
	return true


## Its village's standing warehouse, if any: the road up to where it passes
## nearest it, then the way across (never through the walls).
func _route_to_store(enemy: Enemy) -> void:
	var v := enemy.target_village
	if v == null or enemy.path.size() - enemy.path_index < 2:
		return
	var w: Warehouse = null
	for b in v.buildings():
		if b is Warehouse and (b as Warehouse).raidable():
			w = b
			break
	if w == null:
		return
	var goal := w.work_tile()
	var best := enemy.path_index
	var best_d := INF
	for i in range(enemy.path_index, enemy.path.size()):
		var d := enemy.path[i].distance_to(Vector2(goal))
		if d < best_d:
			best_d = d
			best = i
	var across := enemy.game.world.pathing.find_path(Vector2i(enemy.path[best].round()), goal)
	if across.is_empty():
		return
	var inside := v.rect.grow(-1)
	for p in across:
		if inside.has_point(Vector2i(p.round())):
			return  # (that way leads through the village: the gate, then)
	var way := enemy.path.slice(0, best + 1)
	way.append_array(across.slice(1))
	enemy.path = way
	store = w
	note(enemy, "%s goes for %s instead of the gate" % [enemy.label(), w.label()])
