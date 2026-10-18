class_name ArmBehavior
extends EnemyBehavior
## One arm of a gigantic octopus while it reaches or holds (OctopusBehavior
## moves it). It stands still on its own; cut to 0 HP it tells the octopus.

## The octopus it belongs to.
var octopus: Enemy = null


func tick(enemy: Enemy, _delta: float) -> bool:
	enemy.self_moved = true  # (the octopus moves it)
	return true


func on_death(enemy: Enemy) -> void:
	if is_instance_valid(octopus) and not octopus.dead and octopus.behavior is OctopusBehavior:
		(octopus.behavior as OctopusBehavior).arm_cut(octopus, enemy)
