class_name BalanceLedger
extends RefCounted
## What the balancing bot built and how well it did (docs/balance-bot-design.md
## §4): one row per building of the kinds in TRACKED, filled in every round of
## the player (BalancePlayer.think), plus what the hero spent her time on and
## which villagers stood idle. It only looks, it never changes the game.
##
## A building row: `n` id, `k` kind, `x` `y` tile, `o` origin ("start": there at
## the start, "built": placed or restored later), `w` the wave it was first
## seen in, `t0` the game second it was first seen (placed), `td` when it was
## finished (-1: never), `up` seconds it stood finished and working, `dv` times
## it was devastated, `dv_s` seconds it lay devastated, `idle` seconds a
## workplace stood without its worker, `slot_s` / `empty_s` the post's slot
## seconds and how many of them were empty, `out` what a workplace brought home
## (food, material), `kills` a tower's kills, `lv` its level at the last look,
## `g` when it was gone (-1: still there at the end).

## The kinds the ledger follows (huts, walls and gates are in Stats).
const TRACKED: Array[String] = ["farm", "camp", "tower", "wall_tower", "barracks", "training", "lightstone"]

var game: Game
var village: Village
var _rows: Dictionary = {}
var _last := -1.0
## Hero mode name -> game seconds in it ("down" while she was).
var hero_seconds: Dictionary = {}
## Role -> villager seconds standing idle for lack of a workplace.
var idle_villager_s: Dictionary = {}


func _init(p_game: Game) -> void:
	game = p_game
	village = p_game.player_village


func update() -> void:
	var now := game.stats.time
	var dt := 0.0 if _last < 0.0 else now - _last
	_last = now
	var seen := {}
	for b in village.buildings():
		if not TRACKED.has(b.kind) or b.tearing_down and not _rows.has(b.nid):
			continue
		seen[b.nid] = true
		var row: Dictionary = _rows.get(b.nid, {})
		if row.is_empty():
			row = {"n": b.nid, "k": b.kind, "x": b.tile.x, "y": b.tile.y, "o": "start" if now < 5.0 else "built",
				"w": game.waves.wave, "t0": snappedf(now, 0.1), "td": -1.0, "up": 0.0, "dv": 0, "dv_s": 0.0, "idle": 0.0,
				"slot_s": 0.0, "empty_s": 0.0, "out": 0.0, "kills": 0, "lv": b.level, "g": -1.0, "_dev": false}
			_rows[b.nid] = row
		_look(row, b, now, dt)
	for nid: int in _rows:
		var row: Dictionary = _rows[nid]
		if not seen.has(nid) and float(row["g"]) < 0.0:
			row["g"] = snappedf(now, 0.1)
	_hero(dt)
	_villagers(dt)


func _look(row: Dictionary, b: Building, now: float, dt: float) -> void:
	row["lv"] = b.level
	if b.complete and float(row["td"]) < 0.0:
		row["td"] = snappedf(now, 0.1)
	if b.devastated:
		row["dv_s"] += dt
		if not row["_dev"]:
			row["dv"] += 1
	row["_dev"] = b.devastated
	if not (b.complete and b.working()):
		return
	row["up"] += dt
	if b is Workplace:
		if (b as Workplace).worker == null:
			row["idle"] += dt
		row["out"] = snappedf((b as Workplace).delivered, 0.1)
	elif b is MilitaryPost:
		var post := b as MilitaryPost
		row["slot_s"] += dt * post.capacity()
		row["empty_s"] += dt * (post.capacity() - post.units().size())
		var towers: Dictionary = game.stats.villages[village.id]["towers"]
		if towers.has(b.nid):
			row["kills"] = int((towers[b.nid] as Array)[1])


func _hero(dt: float) -> void:
	var h := village.hero
	if not is_instance_valid(h):
		return
	var mode: String = "down" if h.dead else h.mode_name()
	hero_seconds[mode] = float(hero_seconds.get(mode, 0.0)) + dt


func _villagers(dt: float) -> void:
	for role: String in ["farmer", "forester"]:
		var n := village.population.free_workers(role).size()
		if n > 0:
			idle_villager_s[role] = float(idle_villager_s.get(role, 0.0)) + dt * n


## The rows for the record (the working fields left out).
func buildings() -> Array:
	var out: Array = []
	for nid: int in _rows:
		var row: Dictionary = (_rows[nid] as Dictionary).duplicate()
		row.erase("_dev")
		for k: String in ["up", "dv_s", "idle", "slot_s", "empty_s"]:
			row[k] = snappedf(float(row[k]), 0.1)
		out.append(row)
	return out


## What the hero did: seconds per mode, XP by source, kills in all and by
## wave, how often she fell (the Stats counters; her levels are in the
## timeline).
func hero() -> Dictionary:
	var c: Dictionary = game.stats.villages[village.id]["c"]
	var xp := {}
	for k: String in c:
		if k.begins_with("hero.xp."):
			xp[k.substr(8)] = c[k]
	var by_wave := {}
	var hw: Dictionary = game.stats.villages[village.id]["hero_waves"]
	for w in hw:
		by_wave[str(w)] = hw[w]
	var secs := {}
	for m: String in hero_seconds:
		secs[m] = snappedf(float(hero_seconds[m]), 0.1)
	return {"seconds": secs, "xp": xp, "kills": c.get("hero.kills", 0.0), "kills_by_wave": by_wave,
		"downed": c.get("hero.downed", 0.0), "level": c.get("hero.level", 1.0), "idle_villager_s": idle_villager_s}
