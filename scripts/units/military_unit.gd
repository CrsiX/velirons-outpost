class_name MilitaryUnit
extends RefCounted
## A military unit owned by the army (any kind: archer, shield bearer, mages...;
## see Config.MILITARY and docs/military-design.md). Not a scene node itself:
## it waits in the reserve (sidebar), walks as a `Soldier` node, sits on a
## post (tower, training grounds, a barracks bench), or is out on a barracks
## sortie (a Soldier again). On a tower its behavior acts through the tower.
##
## Units have HP. On towers they can't be hurt; outside (walking, on a sortie)
## they can. At 0 HP they're downed and revive after a while: on their bench
## if they belong to barracks, otherwise in the reserve. While downed nothing
## can be done with them. They heal on benches and unused in the reserve.

const BEHAVIORS := {
	"ranged": preload("res://scripts/units/military/ranged_behavior.gd"),
	"summoner": preload("res://scripts/units/military/summoner_behavior.gd"),
	"healer": preload("res://scripts/units/military/healer_behavior.gd"),
	"melee": preload("res://scripts/units/military/military_behavior.gd"),
}

enum State { RESERVE, MARCHING, STATIONED, RETURNING, TRAVELLING, DOWNED }

static var _next_id := 1

var id := 0
var kind := ""
## 0-based: 0 = level 1 ... Config.MAX_UNIT_LEVEL - 1.
var level := 0
var state := State.RESERVE
## Post it is marching to or stationed on (tower, training grounds, barracks).
var post: MilitaryPost = null
## Which of the post's slots (barracks benches) it holds.
var slot := 0
## STATIONED at barracks: out fighting (its `walker` is the body outside).
var out := false
var hp := 1.0
## DOWNED: seconds until it's back, and whether on its barracks bench.
var revive_left := 0.0
var revive_at_post := false
## XP passed on by the hero at the training grounds towards the next level.
var train_xp := 0.0
## Body outside: walking (MARCHING, RETURNING, TRAVELLING) or on a sortie.
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
	id = _next_id
	_next_id += 1
	set_kind(p_kind)
	hp = max_hp()


## Becomes `p_kind` (recruiting, or specialising), with that kind's behavior.
func set_kind(p_kind: String) -> void:
	kind = p_kind
	behavior = BEHAVIORS[role()].new()


func spec() -> Dictionary:
	return Config.MILITARY[kind]


func display_name() -> String:
	return spec()["name"]


## Log name, numbered per kind: "archer 5".
func label() -> String:
	return "%s %d" % [display_name().to_lower(), uid]


## "ranged", "melee", "summoner" or "healer".
func role() -> String:
	return spec()["role"]


## Can it serve on this kind of post ("tower", "barracks"; training grounds take anyone)?
func fits(post_kind: String) -> bool:
	return post_kind == "training" or spec()["posts"].has(post_kind)


func state_text() -> String:
	match state:
		State.MARCHING: return "marching to its post"
		State.STATIONED: return "out fighting" if out else "on duty"
		State.RETURNING: return "returning to the village"
		State.TRAVELLING: return "on the way to %s" % (travel_to.village_name if travel_to else "another village")
		State.DOWNED: return "downed: back in %d s" % ceili(revive_left)
	return "in reserve"


## A stat of the current level ("damage", "cooldown", "interval", ...).
func stat(key: String) -> float:
	return Config.unit_stat(kind, key, level)


func has_stat(key: String) -> bool:
	return spec()["stats"].has(key)


func max_hp() -> float:
	return stat("hp")


## Own range out in the field (ranged units; never upgraded).
func field_range() -> float:
	return float(spec().get("range", Config.UNIT_MELEE_RANGE))


func is_downed() -> bool:
	return state == State.DOWNED


## Available for orders (not downed, not on its way to another village).
func is_available() -> bool:
	return state != State.DOWNED and state != State.TRAVELLING


func heal(amount: float) -> void:
	if not is_downed():
		hp = minf(max_hp(), hp + amount)


func can_train() -> bool:
	return level < Config.MAX_UNIT_LEVEL - 1 and not is_downed()


## XP needed for the next level via training (grows by level and difficulty).
func train_xp_needed() -> float:
	if level >= Config.MAX_UNIT_LEVEL - 1:
		return 0.0
	return Config.unit_train_xp(kind, level) * Config.TRAIN_XP_DIFFICULTY[Settings.difficulty_key()]


func can_upgrade() -> bool:
	return level < Config.MAX_UNIT_LEVEL - 1


func upgrade_cost() -> Dictionary:
	return Config.unit_upgrade_cost(kind, level)


## Every way to upgrade it now: the next level of its own kind; from
## BRANCH_MIN_LEVEL on, level 1 of each specialisation it branches into; a
## spatial mage of ARCHMAGE_LEVEL, the Spatial Archmage (a civilian).
## [{"to": kind, "level": 0-based, "cost": {}, "archmage": bool}]
func upgrade_options() -> Array[Dictionary]:
	var out_opts: Array[Dictionary] = []
	if can_upgrade():
		out_opts.append({"to": kind, "level": level + 1, "cost": upgrade_cost(), "archmage": false})
	if level + 1 >= Config.BRANCH_MIN_LEVEL:
		for b in spec().get("branches", []):
			out_opts.append({"to": b, "level": 0, "cost": Config.MILITARY[b]["branch_cost"], "archmage": false})
	if spec().get("archmage", false) and level + 1 >= Config.ARCHMAGE_LEVEL:
		out_opts.append({"to": "spatial_archmage", "level": 0, "cost": Config.ARCHMAGE_COST, "archmage": true})
	return out_opts


## A short stat line for an upgrade option ("Archer 6: 27 damage, every 0.62 s").
static func option_text(opt: Dictionary) -> String:
	if opt["archmage"]:
		return "Spatial Archmage: leaves the army and becomes a civilian"
	var k: String = opt["to"]
	var lv: int = opt["level"]
	var sp: Dictionary = Config.MILITARY[k]
	var parts: Array[String] = ["%s %d:" % [sp["name"], lv + 1], "%.0f HP" % Config.unit_stat(k, "hp", lv)]
	var st: Dictionary = sp["stats"]
	if st.has("damage"):
		parts.append("%.0f damage every %.2f s" % [Config.unit_stat(k, "damage", lv), Config.unit_stat(k, "cooldown", lv)])
	if st.has("heal"):
		parts.append("heals %.0f every %.1f s" % [Config.unit_stat(k, "heal", lv), Config.unit_stat(k, "cooldown", lv)])
	if st.has("interval"):
		parts.append("up to %d summons" % roundi(Config.unit_stat(k, "max_summons", lv)))
	if sp.has("range"):
		parts.append("range %.1f" % sp["range"])
	return " ".join(parts)
