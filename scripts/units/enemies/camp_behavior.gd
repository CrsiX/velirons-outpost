class_name CampBehavior
extends EnemyBehavior
## A camp monster (docs/world-design.md §9.3): never walks a road. It stays
## by its camp, attacks any defender (the hero, soldiers, elementals) that
## comes within CAMP_AGGRO of the camp, never follows it farther than
## CAMP_LEASH, and walks back to its spot when nobody is left.

var camp: Node
var home := Vector2.ZERO
var _attack_timer := 0.0
var _scan_timer := 0.0
var _foe: Node = null


func setup(p_camp: Node, p_home: Vector2) -> void:
	camp = p_camp
	home = p_home


## Always holds the enemy (it has no road to walk); moves it by hand.
func tick(enemy: Enemy, delta: float) -> bool:
	_attack_timer -= delta
	_scan_timer -= delta
	var centre := Vector2(camp.tile) if is_instance_valid(camp) else home
	if _scan_timer <= 0.0:
		_scan_timer = 0.25
		_foe = null
		var best := INF
		for node in enemy.get_tree().get_nodes_in_group("melee_defenders") + enemy.get_tree().get_nodes_in_group("villagers"):
			if node.dead or _sheltered(node) or node.grid_pos.distance_to(centre) > Config.CAMP_AGGRO:
				continue
			var d: float = node.grid_pos.distance_to(enemy.grid_pos)
			if d < best:
				best = d
				_foe = node
	if is_instance_valid(_foe) and not _foe.dead:
		var d: float = _foe.grid_pos.distance_to(enemy.grid_pos)
		enemy.face(_foe.grid_pos)
		if d > Config.SUMMON["attack_range"]:
			var step: Vector2 = enemy.grid_pos.move_toward(_foe.grid_pos, enemy.speed * delta)
			if step.distance_to(centre) <= Config.CAMP_LEASH:
				enemy.set_grid_pos(step)
				enemy.moving = true
		elif _attack_timer <= 0.0:
			_attack_timer = float(enemy.spec().get("attack_cooldown", 1.2))
			var dmg := enemy.stat("damage") if float(enemy.spec().get("damage", 0.0)) > 0.0 else 0.0
			if dmg <= 0.0:  # (a witch at a camp hits with her spell)
				dmg = maxf(float(enemy.spec().get("spell_damage", 4.0)), 4.0)
			enemy.swing(_foe.grid_pos)
			_foe.take_damage(dmg, enemy, enemy.attack_category())
		return true
	# Nobody around: back to its spot by the fire.
	if enemy.grid_pos.distance_to(home) > 0.05:
		enemy.set_grid_pos(enemy.grid_pos.move_toward(home, enemy.speed * 0.6 * delta))
	return true
