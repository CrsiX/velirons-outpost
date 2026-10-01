class_name EnemyBehavior
extends RefCounted
## What an enemy does besides walking to a gate. One instance per enemy.


## A villager enemies can't get at (at home, in a mine, inside the walls).
## The hero is a Civilian too, but never counts as sheltered.
static func _sheltered(node) -> bool:
	return node is Civilian and not (node is Hero) and not (node as Civilian).is_exposed()


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


## Called right after the enemy lost HP, before it may die (a vampire saves
## itself as a bat here).
func on_hurt(_enemy: Enemy) -> void:
	pass


## Called once when the enemy dies or vanishes.
func on_death(_enemy: Enemy) -> void:
	pass
