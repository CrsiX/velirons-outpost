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
	"support": preload("res://scripts/units/military/support_behavior.gd"),
}

enum State { RESERVE, MARCHING, STATIONED, RETURNING, TRAVELLING, DOWNED }

static var _next_id := 1

var id := 0
var kind := ""
## Takes no orders (fixed()): set by a scenario (scenario 7's grove druids).
var bound := false
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
## A warrior's war cry: how much faster its timers run, until Game.clock
## reaches cry_until (Combat.war_cry).
var cry_bonus := 0.0
var cry_until := -1.0


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


## Takes no orders (`bound`: scenario 7's grove druids): it can't be moved,
## withdrawn, upgraded or sent; it stays on its post.
func fixed() -> bool:
	return bound


## "ranged", "melee", "summoner", "healer" or "support".
func role() -> String:
	return spec()["role"]


## Can it serve on this kind of post ("tower", "barracks"; training grounds
## take anyone; a druids' grove only druids)?
func fits(post_kind: String) -> bool:
	if post_kind == "grove":
		return kind == "druid"
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


## Food per second it eats (Config.unit_upkeep, scaled by a scenario's
## army_upkeep; Population.army_upkeep sums them).
func upkeep() -> float:
	return Config.unit_upkeep(kind, level) * upkeep_factor(village.game if village else null)


## A scenario's army_upkeep (1 in a free game).
static func upkeep_factor(game: Game) -> float:
	return game.scenario.spec.army_upkeep if game != null and game.scenario != null else 1.0


## Its panel lines about food: what it eats, and how hunger weakens it.
func food_lines() -> Array[String]:
	var out: Array[String] = []
	if upkeep() > 0.0:
		out.append("Eats {food} %.1f per minute" % (upkeep() * 60.0))
	if hungry():
		var pct := roundi(100.0 * Config.HUNGER_PENALTY)
		out.append("Hungry (no food): %d%% slower, %d%% more damage taken" % [pct, pct])
	return out


## Its village is out of food (Population.starving): it moves, acts and
## shrugs off hits Config.HUNGER_PENALTY worse.
func hungry() -> bool:
	return village != null and village.population != null and village.population.starving


## Its timers' factor from hunger (1 = fed).
func hunger_rate() -> float:
	return 1.0 - Config.HUNGER_PENALTY if hungry() else 1.0


## How fast its attack, summon and heal timers run (1 = normal): a war cry's
## haste, a siren's song at `pos` (grid; where it acts from), hunger, and a
## berserker's rage (the more HP it has lost, the faster).
func rate(game: Game, pos := Vector2.INF) -> float:
	var r := Combat.haste(game, self, pos) * hunger_rate()
	if has_stat("rage"):
		var missing := clampf(1.0 - hp / max_hp(), 0.0, 1.0)
		r /= maxf(1.0 - stat("rage") * missing, 0.05)
	return r


## Can it go for flyers? Every unit that shoots or casts; of the melee units
## only those with "hits_flyers" (the halberdier).
func hits_flyers() -> bool:
	return role() != "melee" or spec().get("hits_flyers", false)


## The kind of damage it deals (Config.DAMAGE_CATEGORIES): its attack's, or its
## summons' for a summoner; "" for a healer or a High Priest.
func damage_category() -> String:
	match role():
		"healer", "support":
			return ""
		"summoner":
			return str(Config.SUMMONS[spec().get("summon", "earth")]["category"])
	return str(Config.ATTACKS[spec()["attack"]]["category"])


## Is `e` worth turning out for: does its damage hurt it at all (a ghost takes no
## melee or projectile damage)? A healer or a High Priest deals none, and goes
## all the same (its aura or heal helps the others).
func can_face(e: Enemy) -> bool:
	var c := damage_category()
	return c == "" or e.hurt_by(c)


## Does it fight at all? Not a Healing Mage or a High Priest (no attack); a
## summoner does (its elementals).
func fights() -> bool:
	return role() not in ["healer", "support"]


## Own range out in the field (ranged units; never upgraded; a melee unit's reach).
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


## Gold for the next level, less what training has already paid for
## (`trained_share` × TRAIN_GOLD_DISCOUNT of it; at least 1 gold).
func upgrade_cost() -> Dictionary:
	var cost := Config.unit_upgrade_cost(kind, level)
	var off := trained_share() * Config.TRAIN_GOLD_DISCOUNT
	if cost.has("gold") and off > 0.0:
		cost["gold"] = maxi(1, roundi(cost["gold"] * (1.0 - clampf(off, 0.0, 1.0))))
	return cost


## How far its training towards the next level has come (0-1).
func trained_share() -> float:
	var need := train_xp_needed()
	return clampf(train_xp / need, 0.0, 1.0) if need > 0.0 else 0.0


## Every way to upgrade it now: the next level of its own kind; from
## BRANCH_MIN_LEVEL on, level 1 of each specialisation it branches into; a
## spatial mage of ARCHMAGE_LEVEL, the Spatial Archmage (a civilian).
## [{"to": kind, "level": 0-based, "cost": {}, "archmage": bool}]
func upgrade_options() -> Array[Dictionary]:
	var out_opts: Array[Dictionary] = []
	if fixed():
		return out_opts
	if can_upgrade():
		out_opts.append({"to": kind, "level": level + 1, "cost": upgrade_cost(), "archmage": false})
	if level + 1 >= Config.BRANCH_MIN_LEVEL and (village == null or village.game.allows_branches()):
		for b in spec().get("branches", []):
			out_opts.append({"to": b, "level": 0, "cost": Config.MILITARY[b]["branch_cost"], "archmage": false})
	if spec().get("archmage", false) and level + 1 >= Config.ARCHMAGE_LEVEL:
		out_opts.append({"to": "spatial_archmage", "level": 0, "cost": Config.ARCHMAGE_COST, "archmage": true})
	return out_opts


## A short stat line for an upgrade option ("Archer 6: 27 damage, every 0.62 s").
## `factor`: the game's upkeep_factor, for what the option eats.
static func option_text(opt: Dictionary, factor := 1.0) -> String:
	if opt["archmage"]:
		return "Spatial Archmage: leaves the army and becomes a civilian"
	var k: String = opt["to"]
	var lv: int = opt["level"]
	var sp: Dictionary = Config.MILITARY[k]
	var parts: Array[String] = ["%s %d:" % [sp["name"], lv + 1], "%.0f HP" % Config.unit_stat(k, "hp", lv)]
	var st: Dictionary = sp["stats"]
	if st.has("aura"):  # (its damage is only a counter-strike)
		parts.append("allies +%d%% damage" % roundi(100.0 * Config.unit_stat(k, "aura", lv)))
	elif st.has("damage"):
		parts.append("%.0f damage every %.2f s" % [Config.unit_stat(k, "damage", lv), Config.unit_stat(k, "cooldown", lv)])
	if st.has("heal"):
		parts.append("heals %.0f every %.1f s" % [Config.unit_stat(k, "heal", lv), Config.unit_stat(k, "cooldown", lv)])
	if st.has("interval"):
		parts.append("up to %d summons" % roundi(Config.unit_stat(k, "max_summons", lv)))
	if st.has("cry"):
		parts.append("war cry +%d%%" % roundi(100.0 * Config.unit_stat(k, "cry", lv)))
	if st.has("rage"):
		parts.append("rage up to %.1fx" % (1.0 / maxf(1.0 - Config.unit_stat(k, "rage", lv), 0.05)))
	if sp.get("hits_flyers", false):
		parts.append("hits flyers")
	if sp.has("range"):
		parts.append("range %.1f" % sp["range"])
	if factor > 0.0:
		parts.append("eats {food} %.1f/min" % (Config.unit_upkeep(k, lv) * factor * 60.0))
	return " ".join(parts)
