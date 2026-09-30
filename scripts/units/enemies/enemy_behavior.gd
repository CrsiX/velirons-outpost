class_name EnemyBehavior
extends RefCounted
## What an enemy does besides walking to a gate. One instance per enemy.


## Called every frame. Return true to hold the enemy in place this frame
## (e.g. while fighting or casting), false to let it keep walking.
func tick(_enemy: Enemy, _delta: float) -> bool:
	return false


## Called when the enemy is hurt by `source` (a Tower, or a melee defender).
func on_damaged(_enemy: Enemy, _source: Node) -> void:
	pass


## Called when the enemy's walk ends (normally: at a gate). Return true when
## the behavior took care of it (a thief turns back with its loot); false and
## it has reached the gate.
func on_path_end(_enemy: Enemy) -> bool:
	return false


## Called once when the enemy dies or vanishes.
func on_death(_enemy: Enemy) -> void:
	pass
