class_name BalancePart
extends RefCounted
## One of the three parts of the balancing bot's player (BalancePlayer): the
## economy, the hero and the military (docs/balance-bot-design.md §3). This
## base holds what they share: the helpers for the game's state, sending a
## command, and placing a building (where it is worth most; each part scores
## the kinds it places in `_score`).

var p: BalancePlayer
var game: Game
var village: Village
var _params: Dictionary = Config.BALANCE_BOT


func _init(p_player: BalancePlayer) -> void:
	p = p_player
	game = p_player.game
	village = p_player.village


# --- helpers ----------------------------------------------------------------------------

func _cmd(type: String, args: Dictionary = {}) -> Dictionary:
	return p.send(type, args)


func _wave() -> int:
	return game.waves.wave


func _in_wave() -> bool:
	return game.waves.in_progress()


func _gold() -> float:
	return village.economy.amount("gold")


func _materials() -> float:
	return village.economy.amount("materials")


## The first target of a schedule [[from wave, value], ...] that applies now
## (the last entry whose wave has come), or `none`.
func _scheduled(table: Array, none: int = 0) -> int:
	var out := none
	for row: Array in table:
		if _wave() >= int(row[0]):
			out = int(row[1])
	return out


func _buildings_of(kind: String) -> Array[Building]:
	var out: Array[Building] = []
	for b in village.buildings():
		if b.kind == kind and not b.tearing_down:
			out.append(b)
	return out


## Sites placed and not finished yet (the builders' queue).
func _open_sites() -> int:
	return village.construction.queue.size()


func _site_room() -> bool:
	return _open_sites() < village.population.count("builder") + int(_params["queue_slack"])


func _can_afford(cost: Dictionary) -> bool:
	return village.economy.can_afford(cost)


## Notes what's missing when only material is: anything essential holds the
## upgrades back (want_materials); only what is critical (a repair, a hut,
## the farm) makes the economy's trade buy material with gold (want_critical):
## the foresters' material comes in by itself, gold is for the army.
func _note_missing(cost: Dictionary, essential := true, critical := false) -> void:
	if not essential:
		return
	var lack := int(cost.get("materials", 0)) - int(_materials())
	if lack > 0 and int(cost.get("gold", 0)) <= int(_gold()):
		p.want_materials = maxi(p.want_materials, lack)
		if critical:
			p.want_critical = true
			p.critical_lack = maxi(p.critical_lack, lack)


# --- training (the hero's XP into a unit's levels) ---------------------------------------

## The levels (at most BALANCE_HERO "train_levels") the hero can still train `u`
## by: 0 when it can't level up any more.
func _train_levels(u: MilitaryUnit) -> int:
	return clampi(int(Config.BALANCE_HERO["train_levels"]), 0, Config.MAX_UNIT_LEVEL - 1 - u.level)


## The hero XP it takes to train `u` through its next `levels` levels (what is
## still missing of the next one, then each following level whole).
func _train_need(u: MilitaryUnit, levels: int) -> float:
	var total := u.train_xp_needed() - u.train_xp
	var diff: float = Config.TRAIN_XP_DIFFICULTY[Settings.difficulty_key()]
	for i in range(1, levels):
		if u.level + i < Config.MAX_UNIT_LEVEL - 1:
			total += Config.unit_train_xp(u.kind, u.level + i) * diff
	return maxf(total, 0.0)


# --- placing ----------------------------------------------------------------------------

## Places a `kind` where it is worth most; remembers when there was no spot.
func _place(kind: String) -> void:
	if not _site_room():
		return
	var cost: Dictionary = Config.BUILDINGS[kind]["cost"]
	if not _can_afford(cost):
		_note_missing(cost, true, _critical_kind(kind))
		return
	if float(p.no_spot.get(kind, -1.0)) > game.clock:
		return
	var retry := _retry(kind)
	var tile := _spot(kind)
	if tile == Vector2i(-1, -1):
		p.no_spot[kind] = game.clock + retry  # (more land gets explored meanwhile)
		return
	var r := _cmd("place_building", {"kind": kind, "tile": tile})
	if not r["ok"]:
		p.no_spot[kind] = game.clock + retry / 2.0
	else:
		p.approach_version = -1  # (the covered road changed)


## Whether gold may buy the material for a `kind` that can't be afforded.
func _critical_kind(_kind: String) -> bool:
	return false


## Seconds before a `kind` that found no spot is tried again.
func _retry(_kind: String) -> float:
	return 20.0


func _spot(kind: String) -> Vector2i:
	var size: int = Config.BUILDINGS[kind]["size"]
	var c := village.center
	var radius := int(_params["scan_radius"])
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var ctx := _spot_context(kind)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var t := c + Vector2i(dx, dy)
			if p.bad_spots.has(t) or game.construction.placement_error(kind, t) != "":
				continue
			var score := _score(kind, t, size, ctx)
			if score > best_score:
				best_score = score
				best = t
	return best if best_score > -INF else Vector2i(-1, -1)


## Whatever _score needs once per search (the roads a post covers already).
func _spot_context(_kind: String) -> Dictionary:
	return {}


func _score(_kind: String, t: Vector2i, size: int, _ctx: Dictionary) -> float:
	return -_centre(t, size).distance_to(Vector2(village.center))  # close to home


func _centre(t: Vector2i, size: int) -> Vector2:
	return Vector2(t) + Vector2(0.5, 0.5) * float(size - 1) if size % 2 == 0 else Vector2(t)
