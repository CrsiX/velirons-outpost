class_name MilitaryUnit
extends RefCounted
## A soldier owned by the army. Not a scene node: it lives in the reserve
## (sidebar) or is stationed on a tower, which draws and fires for it.

static var _next_id := 1

var id := 0
var kind := "archer"
var level := 0
var post: Tower = null


func _init(p_kind: String = "archer") -> void:
	kind = p_kind
	id = _next_id
	_next_id += 1


func spec() -> Dictionary:
	return Config.MILITARY[kind]


func display_name() -> String:
	return spec()["name"]


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
