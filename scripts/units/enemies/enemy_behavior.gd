class_name EnemyBehavior
extends RefCounted
## What an enemy does besides walking to a gate. One instance per enemy.


## Called every frame. Return true to hold the enemy in place this frame
## (e.g. while fighting or casting), false to let it keep walking.
func tick(_enemy: Enemy, _delta: float) -> bool:
	return false


## Called when the enemy is hurt by `source` (a Tower or an EarthElemental).
func on_damaged(_enemy: Enemy, _source: Node) -> void:
	pass
