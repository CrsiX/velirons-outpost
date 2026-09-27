class_name MeleeBehavior
extends EnemyBehavior
## Goblins, skeletons, orks: stop to fight any summon (earth elemental) that
## stands in the way, then walk on. Enemies with 0 damage never stop.

var _attack_timer := 0.0
var _scan_timer := 0.0
var _foe: EarthElemental = null


func tick(enemy: Enemy, delta: float) -> bool:
	if enemy.stat("damage") <= 0.0:
		return false
	_attack_timer -= delta
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.2
		_foe = null
		for node in enemy.get_tree().get_nodes_in_group("summons"):
			var s := node as EarthElemental
			if not s.dead and s.grid_pos.distance_to(enemy.grid_pos) <= Config.SUMMON["attack_range"]:
				_foe = s
				break
	if not is_instance_valid(_foe) or _foe.dead:
		return false
	enemy.face(_foe.grid_pos)
	if _attack_timer <= 0.0:
		_attack_timer = enemy.stat("attack_cooldown")
		_foe.take_damage(enemy.stat("damage"))
	return true
