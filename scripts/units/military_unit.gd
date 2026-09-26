class_name MilitaryUnit
extends RefCounted
## A soldier owned by the army. Not a scene node itself: it waits in the
## reserve (sidebar), walks to or from a tower as a `Soldier` node, or is
## stationed on a tower, which draws and fires for it.

enum State { RESERVE, MARCHING, STATIONED, RETURNING }

static var _next_id := 1

var id := 0
var kind := "archer"
var level := 0
var state := State.RESERVE
## Tower it is marching to or stationed on.
var post: Tower = null
## Walking body while MARCHING or RETURNING.
var walker: Node = null


func _init(p_kind: String = "archer") -> void:
	kind = p_kind
	id = _next_id
	_next_id += 1


func spec() -> Dictionary:
	return Config.MILITARY[kind]


func display_name() -> String:
	return spec()["name"]


func state_text() -> String:
	match state:
		State.MARCHING: return "marching to a tower"
		State.STATIONED: return "on duty"
		State.RETURNING: return "returning to the village"
	return "in reserve"


func _level() -> Dictionary:
	return spec()["levels"][level]


func damage() -> float:
	return _level()["damage"]


func cooldown() -> float:
	return _level()["cooldown"]


func can_upgrade() -> bool:
	return level < spec()["levels"].size() - 1


func upgrade_cost() -> Dictionary:
	return spec()["levels"][level + 1]["cost"] if can_upgrade() else {}
