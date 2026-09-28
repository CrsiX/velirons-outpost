class_name MilitaryUnit
extends RefCounted
## A military unit owned by the army (any kind: archer, summoner, ...). Not a
## scene node itself: it waits in the reserve (sidebar), walks to or from a
## tower as a `Soldier` node, or is stationed on a tower, where its behavior
## (see Config.MILITARY[kind]["behavior"]) acts through the tower.

const BEHAVIORS := {
	"archer": preload("res://scripts/units/military/archer_behavior.gd"),
	"summoner": preload("res://scripts/units/military/summoner_behavior.gd"),
}

enum State { RESERVE, MARCHING, STATIONED, RETURNING, TRAVELLING }

static var _next_id := 1

var id := 0
var kind := ""
var level := 0
var state := State.RESERVE
## Tower (or other military post) it is marching to or stationed on.
var post: MilitaryPost = null
## XP passed on by the hero at the training grounds towards the next level.
var train_xp := 0.0
## Walking body while MARCHING or RETURNING.
var walker: Node = null
var behavior: MilitaryBehavior
## Number within its kind (see label()), given by Army.recruit.
var uid := 0
## The village it belongs to (whose army it's in).
var village: Village
## Id that commands use to name this unit (Game.register).
var nid := 0
## The village that recruited it (kept when it's sent to another village;
## statistics only, never shown).
var original_owner: Village
## TRAVELLING: the village it walks to, which becomes its owner on arrival.
var travel_to: Village


func _init(p_kind: String) -> void:
	kind = p_kind
	behavior = BEHAVIORS[spec()["behavior"]].new()
	id = _next_id
	_next_id += 1


func spec() -> Dictionary:
	return Config.MILITARY[kind]


func display_name() -> String:
	return spec()["name"]


## Log name, numbered per kind: "archer 5".
func label() -> String:
	return "%s %d" % [display_name().to_lower(), uid]


func state_text() -> String:
	match state:
		State.MARCHING: return "marching to a tower"
		State.STATIONED: return "on duty"
		State.RETURNING: return "returning to the village"
		State.TRAVELLING: return "on the way to %s" % (travel_to.village_name if travel_to else "another village")
	return "in reserve"


func _level() -> Dictionary:
	return spec()["levels"][level]


## A stat of the current level ("damage", "interval", ...).
func stat(key: String) -> float:
	return _level()[key]



func can_train() -> bool:
	return can_upgrade()


## XP needed for the next level via training (grows by level and difficulty).
func train_xp_needed() -> float:
	if not can_train():
		return 0.0
	return float(spec()["train_xp"][level]) * Config.TRAIN_XP_DIFFICULTY[Settings.difficulty_key()]


func can_upgrade() -> bool:
	return level < spec()["levels"].size() - 1


func upgrade_cost() -> Dictionary:
	return spec()["levels"][level + 1]["cost"] if can_upgrade() else {}
