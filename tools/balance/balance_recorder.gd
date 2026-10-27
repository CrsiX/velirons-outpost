class_name BalanceRecorder
extends Node
## Watches one game of the balancing bot and builds its record (the schema is
## in docs/balance-bot-design.md §4). It only looks: it reads the game's own
## Stats and hooks the enemies' signals, it never changes the game.
##
## What it keeps:
##  - per wave: what came (kinds, HP), what we had (army, economy), how long it
##    took, what it cost (every Stats counter's change), and per enemy kind how
##    many were spawned / killed / got through and how far along their road
##    they got before they died;
##  - a timeline of the village's state (column-wise, one row per sample);
##  - at the end: the final state and every Stats counter.

var game: Game
var village: Village
var player: BalancePlayer
var waves: Array[Dictionary] = []
var timeline: Dictionary = {}
var waves_finished := 0
var _row: Dictionary = {}
var _counters_at_start: Dictionary = {}
var _next_sample := 0.0
## Wave number -> enemies of it still alive (a wave row closes with the wave).
var _tracked := {}


func setup(p_game: Game, p_player: BalancePlayer) -> void:
	game = p_game
	player = p_player
	village = game.player_village
	game.waves.wave_started.connect(_on_wave_started)
	game.waves.wave_finished.connect(_on_wave_finished)
	get_tree().node_added.connect(_on_node_added)
	for c in TIMELINE_COLUMNS:
		timeline[c] = []
	_sample()


const TIMELINE_COLUMNS: Array[String] = [
	"t", "wave", "in_wave", "gold", "food", "materials", "villagers", "huts", "explored",
	"units", "unit_levels", "army_hp", "army_dps", "towers", "barracks", "hero_level", "hero_xp", "enemies",
]


func _process(_delta: float) -> void:
	if game == null or game.stats == null or not game.stats.enabled:
		return
	if game.stats.time >= _next_sample:
		_next_sample += float(Config.BALANCE_BOT["sample_interval"])
		_sample()


func now() -> float:
	return game.stats.time


# --- snapshots -----------------------------------------------------------------------------

## Nominal damage per second of a military unit (its stats, no targets, no
## misses): damage / cooldown; a summoner: its cap of elementals striking.
static func unit_dps(u: MilitaryUnit) -> float:
	if u.has_stat("damage") and u.has_stat("cooldown"):
		return u.stat("damage") / maxf(u.stat("cooldown"), 0.01)
	if u.has_stat("summon_damage"):
		var s: Dictionary = Config.SUMMONS[str(u.spec()["summon"])]
		return u.stat("max_summons") * u.stat("summon_damage") * float(s["damage"]) / float(Config.SUMMON["attack_cooldown"])
	return 0.0


## What the village has now (units, posts, hero).
func army_snapshot() -> Dictionary:
	var d := {"units": 0, "on_duty": 0, "level_sum": 0, "hp": 0.0, "dps": 0.0, "by_kind": {},
		"towers": 0, "barracks": 0, "training": 0, "tower_levels": 0, "free_posts": 0}
	for u in village.army.units:
		d["units"] += 1
		d["level_sum"] += u.level + 1
		d["hp"] += u.max_hp()
		d["dps"] += unit_dps(u)
		if u.state == MilitaryUnit.State.STATIONED:
			d["on_duty"] += 1
		var row: Array = d["by_kind"].get(u.kind, [0, 0])
		d["by_kind"][u.kind] = [int(row[0]) + 1, int(row[1]) + u.level + 1]
	for b in village.buildings():
		if not b.complete:
			continue
		if b is Tower:
			d["towers"] += 1
			d["tower_levels"] += (b as Tower).level
		elif b is Barracks:
			d["barracks"] += 1
		elif b is TrainingGrounds:
			d["training"] += 1
		if b is MilitaryPost and (b as MilitaryPost).free_slot() >= 0:
			d["free_posts"] += 1
	return d


func state_snapshot() -> Dictionary:
	var h := village.hero
	var roles := {}
	for c in village.population.civilians:
		roles[c.role] = int(roles.get(c.role, 0)) + 1
	var farms := 0
	for b in village.buildings():
		if b is Farm and not (b is Stall) and b.working():
			farms += 1
	var hero := {"level": h.level + 1, "xp": h.xp, "dps": Config.hero_stat("damage", h.level) / float(Config.HERO["attack_cooldown"]), "hp": h.max_hp, "dead": h.dead}
	return {
		"gold": village.economy.amount("gold"), "food": village.economy.amount("food"), "materials": village.economy.amount("materials"),
		"villagers": roles, "huts": village.intact_huts().size(), "farms": farms, "explored": game.fog.explored_of[village.id].count(1),
		"army": army_snapshot(), "hero": hero,
	}


func _sample() -> void:
	var a := army_snapshot()
	var h := village.hero
	var enemies := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n as Enemy).wild():
			enemies += 1
	var row := {
		"t": now(), "wave": game.waves.wave, "in_wave": 1 if game.waves.in_progress() else 0,
		"gold": village.economy.amount("gold"), "food": village.economy.amount("food"), "materials": village.economy.amount("materials"),
		"villagers": village.population.count(), "huts": village.intact_huts().size(), "explored": game.fog.explored_of[village.id].count(1),
		"units": a["units"], "unit_levels": a["level_sum"], "army_hp": a["hp"], "army_dps": a["dps"],
		"towers": a["towers"], "barracks": a["barracks"], "hero_level": h.level + 1, "hero_xp": h.xp, "enemies": enemies,
	}
	for c in TIMELINE_COLUMNS:
		timeline[c].append(_round(row[c]))


static func _round(v: Variant) -> Variant:
	return snappedf(float(v), 0.01) if v is float else v


# --- waves ---------------------------------------------------------------------------------------

func _counters() -> Dictionary:
	return (game.stats.villages[village.id]["c"] as Dictionary).duplicate()


func _on_wave_started(n: int) -> void:
	var comp := {}
	var hp_total := 0.0
	var hp_scale := 1.0
	for spec: Dictionary in game.waves._queue:
		var k: String = spec["kind"]
		comp[k] = int(comp.get(k, 0)) + 1
		hp_scale = float(spec["hp_scale"])
		hp_total += Config.enemy_stat(k, "hp") * hp_scale
	_counters_at_start = _counters()
	_row = {
		"wave": n, "t_start": now(), "enemies": game.waves.enemies_left(), "hp_total": snappedf(hp_total, 0.1), "hp_scale": snappedf(hp_scale, 0.0001),
		"comp": comp, "start": state_snapshot(), "by_kind": {}, "survived": false, "spawn_points": Config.wave_spawn_points(n),
	}
	waves.append(_row)
	_tracked[n] = _row


func _on_wave_finished(n: int) -> void:
	waves_finished += 1
	_close_wave(n, true)


## Closes wave `n`'s row: its end state and what the counters changed during it.
func _close_wave(n: int, survived: bool) -> void:
	if not _tracked.has(n):
		return
	var row: Dictionary = _tracked[n]
	_tracked.erase(n)
	row["t_end"] = now()
	row["duration"] = snappedf(float(row["t_end"]) - float(row["t_start"]), 0.01)
	row["end"] = state_snapshot()
	row["survived"] = survived
	var d := {}
	var c := _counters()
	for k in c:
		var diff := float(c[k]) - float(_counters_at_start.get(k, 0.0))
		if absf(diff) > 0.0001 and not str(k).begins_with("hero.streak") and k != "explored":
			d[k] = snappedf(diff, 0.01)
	row["d"] = d
	_counters_at_start = c


## The game is over (or the run was stopped): the wave in progress is closed.
func finish(defeated: bool) -> void:
	for n in _tracked.keys():
		_close_wave(int(n), false if defeated else true)
	_sample()


# --- enemies ----------------------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if not node is Enemy:
		return
	var e := node as Enemy
	if e.behavior is CampBehavior:
		return
	# The tally of its kind in its wave's row, kept by reference: the last enemy
	# of a wave dies after the wave's row has closed.
	var entry := _kind_row(e)
	var info := {"len": maxi(e.path.size(), 1), "t0": now(), "entry": entry}
	e.killed.connect(_on_enemy_end.bind("killed", info))
	e.reached_gate.connect(_on_enemy_end.bind("reached", info))
	e.vanished.connect(_on_enemy_end.bind("gone", info))
	entry["spawned"] = int(entry.get("spawned", 0)) + 1
	entry["hp"] = snappedf(float(entry.get("hp", 0.0)) + e.max_hp, 0.1)


func _kind_name(e: Enemy) -> String:
	return "raised_" + e.kind if e.raised else e.kind


## The row of enemy `e`'s kind in the by_kind table of its wave (a fresh one
## nobody reads if no wave is running).
func _kind_row(e: Enemy) -> Dictionary:
	var n := e.wave if _tracked.has(e.wave) else game.waves.wave
	if not _tracked.has(n):
		return {}
	var by_kind: Dictionary = (_tracked[n] as Dictionary)["by_kind"]
	var k := _kind_name(e)
	if not by_kind.has(k):
		by_kind[k] = {}
	return by_kind[k]


func _on_enemy_end(e: Enemy, how: String, info: Dictionary) -> void:
	var entry: Dictionary = info["entry"]
	entry[how] = int(entry.get(how, 0)) + 1
	var progress := 1.0
	if how != "reached":
		progress = clampf(1.0 - float(e.remaining()) / float(info["len"]), 0.0, 1.0)
	entry["progress"] = snappedf(float(entry.get("progress", 0.0)) + progress, 0.001)
	entry["life"] = snappedf(float(entry.get("life", 0.0)) + now() - float(info["t0"]), 0.01)
