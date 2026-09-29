class_name MonsterLair
extends MapObject
## A monster lair (docs/world-design.md §9.6): scenery for now, no mechanics.
## Its look depends on where it is: a cave in the mountains, a huge hollow
## tree in the pine forest, a sunken ruin in the swamp, a smoking pit in ash
## land, a crypt in the steppe; 1x1 or 2x2. It blocks walking.


func display_name() -> String:
	return "Monster lair"


func is_solid() -> bool:
	return true


func is_solid_when_complete() -> bool:
	return true


func info() -> Dictionary:
	var d := super.info()
	(d["lines"] as Array).append("Something lives in there. Better leave it alone for now.")
	return d
