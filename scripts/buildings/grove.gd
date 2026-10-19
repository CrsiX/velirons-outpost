class_name Grove
extends Barracks
## The druids' grove by their stone circle (2x2; scenario 7,
## docs/scenarios-design.md §7.10), only in the campaign: a scenario prebuilds
## it at its level, with its druids on the benches. Barracks in all but name:
## the druids turn out for enemies near it and come back to heal. Only druids
## serve here ("posts": grove), and they take no orders (MilitaryUnit.fixed).
## It can't be upgraded or torn down.


func post_kind() -> String:
	return "grove"


func max_level() -> int:
	return level


func _art() -> String:
	return "grove"


func can_tear_down() -> bool:
	return false
