class_name ThiefBehavior
extends MeleeBehavior
## Thieves (Config.ENEMIES["thief"]) fight like goblins on the way. At a gate
## they burn nothing: they steal gold (Game.thief_steals) and run back the way
## they came, carrying it (Enemy.loot_gold, shown as a sack). Back at the map
## edge they are gone with it; killed on the way, their corpse holds it.
## Where their village has a standing guild warehouse (Warehouse, scenario 4)
## they go for that instead: along their road to where it passes nearest the
## warehouse, then across to it; there they plunder it and steal the same way.
## A loaded trade caravan within "rob_reach" comes first (docs/market-design.md
## §5): the thief goes for it, takes its whole cargo (TradeCaravan.rob) and
## runs for the nearest map edge with it; killed, it leaves it as salvage.

var escaping := false
## The warehouse it is after (null: the gate).
var store: Warehouse = null
var _routed := false
## The trade caravan it is after, or null.
var prey: TradeCaravan = null
var _prey_scan := 0.0


func tick(enemy: Enemy, delta: float) -> bool:
	if enemy.game.is_client:
		return super.tick(enemy, delta)
	if not _routed:
		_routed = true
		_route_to_store(enemy)
	if not escaping and _hunt(enemy, delta):
		return true
	return super.tick(enemy, delta)


## Goes for a loaded trade caravan in reach, and robs it once there. True
## while it holds the thief (the robbery itself).
func _hunt(enemy: Enemy, delta: float) -> bool:
	_prey_scan -= delta
	if prey != null and (not is_instance_valid(prey) or prey.dead or prey.cargo.is_empty()):
		prey = null  # (it left its road for the cart: none to go back to, off it goes)
		_escape_to_edge(enemy)
		return false
	if prey == null:
		if _prey_scan > 0.0:
			return false
		_prey_scan = 0.5
		var reach := enemy.stat("rob_reach")
		for node in enemy.get_tree().get_nodes_in_group("trade_caravans"):
			var tc := node as TradeCaravan
			if not tc.dead and not tc.cargo.is_empty() and tc.grid_pos.distance_to(enemy.grid_pos) <= reach:
				prey = tc
				note(enemy, "%s goes for %s" % [enemy.label(), tc.label()])
				break
		if prey == null:
			return false
		_prey_scan = 0.0
	if prey.grid_pos.distance_to(enemy.grid_pos) <= Config.SUMMON["attack_range"] + 0.2:
		enemy.set_cargo(prey.rob(enemy))
		prey = null
		_escape_to_edge(enemy)
		return true
	_prey_scan -= delta
	if _prey_scan <= 0.0:
		_prey_scan = 0.4
		var p := enemy.game.world.pathing.find_path(enemy.current_tile(), prey.current_tile())
		if p.size() > 1:
			p[0] = enemy.grid_pos
			p[p.size() - 1] = prey.grid_pos
			enemy.follow(p)
	return false


## Off with the cargo to the nearest map edge (the spawns).
func _escape_to_edge(enemy: Enemy) -> void:
	escaping = true
	var g := enemy.game
	var best := Vector2i(-1, -1)
	var best_d := INF
	for t in g.map.edge_spawns:
		var d := Vector2(t).distance_to(enemy.grid_pos)
		if d < best_d:
			best_d = d
			best = t
	var p := g.world.pathing.find_path(enemy.current_tile(), best) if best != Vector2i(-1, -1) else PackedVector2Array()
	if p.is_empty():
		var back := enemy.path.slice(0, enemy.path_index + 1)
		back.reverse()
		p = back
	if p.size() > 0:
		p[0] = enemy.grid_pos
	enemy.follow(p)
	note(enemy, "%s runs for the edge with the caravan's goods" % enemy.label())


func on_path_end(enemy: Enemy) -> bool:
	if escaping:
		var v := enemy.target_village
		if v and enemy.loot_gold > 0:
			v.events.info("%s got away with %d gold" % [enemy.label().capitalize(), enemy.loot_gold])
		if not enemy.loot_cargo.is_empty():
			var m := enemy.game.entity(int(enemy.loot_cargo["market"])) as Market
			if m != null:
				m.village.events.info("%s got away with %s" % [enemy.label().capitalize(), Market._goods_text(enemy.loot_cargo["goods"])])
			enemy.loot_cargo = {}
		enemy.vanish()
		return true
	if prey != null:
		_prey_scan = 0.0  # (the cart moved on: after it)
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
