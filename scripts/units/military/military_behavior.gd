class_name MilitaryBehavior
extends RefCounted
## What a military unit does while stationed on a tower. One instance per unit,
## so a behavior can keep its own state (cooldowns, summons, ...).
## The tower provides range, sight and the unit's sprite; the behavior acts.


## Called every frame while the unit is on a finished tower.
func tick(_tower: Tower, _unit: MilitaryUnit, _delta: float) -> void:
	pass


## Called when the unit leaves its tower (withdrawn, or the tower is lost).
func on_leave(_tower: Tower, _unit: MilitaryUnit) -> void:
	pass


## Stat lines for the tower panel and the army tab.
func info_lines(_unit: MilitaryUnit) -> Array[String]:
	return []


## Enemies within `radius` tiles of the tower, closest to their gate first.
static func enemies_near(tower: Tower, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node in tower.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.dead and e.grid_pos.distance_to(Vector2(tower.tile)) <= radius:
			out.append(e)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.remaining() < b.remaining())
	return out
