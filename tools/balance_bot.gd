extends Node
## The balancing bot (docs/balance-bot-design.md): plays whole single-player
## games the way a player would (BalancePlayer) and writes one JSON line per
## game (BalanceRecorder) to a results file: for a map type, seed, difficulty
## and playing style, how many waves did the village survive, and everything
## the statistics know about how.
##
##   godot --headless --fixed-fps 60 --path . res://tools/balance_bot.tscn -- \
##       --map=temperate,coast --seeds=1-5 --difficulty=normal --policy=balanced \
##       --out=balance_runs/runs.jsonl
##
## Options (all `--name=value`; lists with commas, seeds also as a range 1-5,
## `all` for every map type / difficulty / policy):
##   --map, --seeds, --difficulty, --policy   the cases: their cross product
##   --max-waves, --max-game-seconds, --max-real-seconds, --speed
##                                            override Config.BALANCE_BOT
##   --out=<file>      results, appended (default balance_runs/runs.jsonl)
##   --label=<text>    names the variant being tested (kept in every record)
##   --overrides=<text> what was changed in config (kept; tools/balance_variant.py)
##   --rev=<text>      the code revision to record (default: git, if there is one)
##   --shard=i/n       runs only every n-th case from i (to share a sweep)
##   --no-detail       leave the timeline and the per-wave rows out
##   --require-waves=N exit 1 unless every game survived at least N waves (CI's smoke test)
## Exits 0 when every case ran (survived waves are the result, not a pass / fail,
## unless --require-waves says otherwise).

const SCHEMA := 1

var _args := {}
var _out_path := ""


func _ready() -> void:
	call_deferred("_main")


func _main() -> void:
	_args = _parse_args()
	if _args.has("help") or _args.has("h"):
		print(_help())
		get_tree().quit(0)
		return
	for key: String in _args:
		if not OPTIONS.has(key):
			push_error("unknown option --%s (see --help)" % key)
			get_tree().quit(2)
			return
	var cases := _cases()
	_out_path = str(_args.get("out", "balance_runs/runs.jsonl"))
	if not _out_path.is_absolute_path():
		_out_path = ProjectSettings.globalize_path("res://").path_join(_out_path)
	DirAccess.make_dir_recursive_absolute(_out_path.get_base_dir())
	print("balance bot: %d case(s) -> %s" % [cases.size(), _out_path])
	var failed := 0
	var short: Array[String] = []
	var required := int(_args.get("require-waves", 0))
	for i in cases.size():
		var c: Dictionary = cases[i]
		print("case %d/%d: map=%s seed=%d difficulty=%s policy=%s" % [i + 1, cases.size(), c["map"], c["seed"], c["difficulty"], c["policy"]])
		var rec := await _play(c)
		if rec.is_empty():
			failed += 1
			continue
		_append(rec)
		var r: Dictionary = rec["result"]
		if int(r["waves_survived"]) < required:
			short.append("%s: %d of %d waves (%s)" % [rec["run_id"], r["waves_survived"], required, r["ended_by"]])
		print("  -> survived %d waves (%s%s) in %.0f game s, %.0f real s" % [r["waves_survived"], r["ended_by"], ", censored" if r["censored"] else "", r["game_seconds"], r["real_seconds"]])
	print("BALANCE DONE: %d run(s), %d failed" % [cases.size() - failed, failed])
	for line in short:
		print("BALANCE FAIL: " + line)
	get_tree().quit(1 if failed > 0 or not short.is_empty() else 0)


## Every option the bot knows (--help prints them; unknown ones are refused).
const OPTIONS := ["help", "h", "map", "seeds", "difficulty", "policy", "max-waves", "max-game-seconds", "max-real-seconds", "speed", "out", "label", "overrides", "rev", "shard", "no-detail", "require-waves"]


func _help() -> String:
	var b: Dictionary = Config.BALANCE_BOT
	var lines: Array[String] = [
		"Balancing bot: plays whole games and appends one JSON line per game to --out.",
		"",
		"  godot --headless --fixed-fps 60 --path . res://tools/balance_bot.tscn -- [options]",
		"",
		"Cases (the cross product of these is played; lists with commas, `all` = every value):",
		"  --map=LIST         map types: %s, random   (default temperate)" % ", ".join(Config.MAP_TYPE_ORDER),
		"  --seeds=LIST       map seeds: 1,2,3 or a range 1-10 or both 1-5,9   (default 1)",
		"  --difficulty=LIST  easy, normal, hard   (default normal)",
		"  --policy=LIST      the playing style (Config.BALANCE_PROFILES; default balanced):",
	]
	for name: String in Config.BALANCE_PROFILES:
		lines.append("                       %s: %s" % [name, Config.BALANCE_PROFILES[name]["desc"]])
	lines.append_array([
		"",
		"Limits (defaults from Config.BALANCE_BOT; a run hitting one ends 'censored'):",
		"  --max-waves=N          stop after N survived waves (default %d, 0 = never)" % int(b["max_waves"]),
		"  --max-game-seconds=S   game time cap (default %d)" % int(b["max_game_seconds"]),
		"  --max-real-seconds=S   wall clock cap per game (default %d)" % int(b["max_real_seconds"]),
		"  --speed=X              Engine.time_scale (default %s; the game's fastest speed is 4)" % str(b["speed"]),
		"",
		"Output and bookkeeping:",
		"  --out=FILE         results, appended (default balance_runs/runs.jsonl)",
		"  --label=TEXT       names the variant being tested (default base)",
		"  --overrides=TEXT   what was changed in config (kept in the record; tools/balance/sweep.py sets it)",
		"  --rev=TEXT         code revision to record (default: git's, if any)",
		"  --shard=I/N        play only every N-th case from I (to split a sweep over processes)",
		"  --no-detail        leave out the per-wave rows and the timeline (much smaller files)",
		"  --require-waves=N  exit 1 unless every game survived at least N waves (a smoke test)",
		"  --help             this text",
		"",
		"Many cases at once, and config variants: python3 tools/balance/sweep.py --help",
		"Results to tables and charts:            python3 tools/balance/report.py --help",
		"More: docs/balance-bot-design.md",
	])
	return "\n".join(lines)


# --- arguments --------------------------------------------------------------------------------------

func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


func _list(key: String, all: Array, default: Array) -> Array:
	var raw := str(_args.get(key, ""))
	if raw == "":
		return default
	if raw == "all":
		return all
	return Array(raw.split(",", false))


func _seeds() -> Array:
	var out := []
	for part in str(_args.get("seeds", "1")).split(",", false):
		if "-" in part.substr(1):
			var ab := part.split("-", false)
			for s in range(int(ab[0]), int(ab[1]) + 1):
				out.append(s)
		else:
			out.append(int(part))
	return out


func _cases() -> Array:
	var maps := _list("map", Config.MAP_TYPE_ORDER, ["temperate"])
	var diffs := _list("difficulty", ["easy", "normal", "hard"], ["normal"])
	var policies := _list("policy", Config.BALANCE_PROFILES.keys(), ["balanced"])
	var cases := []
	for p in policies:
		for m in maps:
			for d in diffs:
				for s in _seeds():
					cases.append({"map": str(m), "seed": int(s), "difficulty": str(d), "policy": str(p)})
	var shard := str(_args.get("shard", "0/1")).split("/")
	var si := int(shard[0])
	var sn := maxi(int(shard[1]), 1) if shard.size() > 1 else 1
	var mine := []
	for i in cases.size():
		if i % sn == si:
			mine.append(cases[i])
	for c in mine:
		assert(Config.BALANCE_PROFILES.has(c["policy"]), "unknown policy %s (have: %s)" % [c["policy"], Config.BALANCE_PROFILES.keys()])
	return mine


func _param(key: String, arg: String) -> float:
	return float(_args[arg]) if _args.has(arg) else float(Config.BALANCE_BOT[key])


# --- one game ----------------------------------------------------------------------------------------

func _play(c: Dictionary) -> Dictionary:
	var started := Time.get_ticks_msec()
	var difficulty := Settings.difficulty_of(c["difficulty"])
	Settings.difficulty = difficulty
	Settings.map_type = c["map"]
	Settings.map_seed = int(c["seed"])
	Settings.custom_map = null
	Settings.pending_save = {}
	var run_seed := hash("%s/%d/%s/%s" % [c["map"], c["seed"], c["difficulty"], c["policy"]])
	seed(run_seed)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: Game = scene.instantiate()
	game.map_seed = int(c["seed"])
	game.map_type = Settings.resolve_map_type(c["map"], int(c["seed"]))  # (the game only does this without a seed)
	add_child(game)
	var ready := false
	for i in 600:
		await get_tree().process_frame
		if game.stats != null and game.stats.enabled and game.hud != null and game.hud._overlay != null:
			ready = true
			break
	if not ready:
		push_error("the game did not come up")
		game.queue_free()
		return {}
	game.waves._rng.seed = run_seed  # (the waves' dice: same game, same waves)
	var player := BalancePlayer.new()
	player.name = "BalancePlayer"
	add_child(player)
	player.setup(game, c["policy"])
	var recorder := BalanceRecorder.new()
	recorder.name = "BalanceRecorder"
	add_child(recorder)
	recorder.setup(game, player)
	var history: Array = []
	game.events.logged.connect(func(level: int, text: String) -> void: history.append([level, text]))
	var limits := {
		"waves": int(_param("max_waves", "max-waves")), "game": _param("max_game_seconds", "max-game-seconds"),
		"real": _param("max_real_seconds", "max-real-seconds"), "wave": float(Config.BALANCE_BOT["max_wave_seconds"]),
	}
	var speed := _param("speed", "speed")
	var ended_by := ""
	var frames := 0
	while ended_by == "":
		Engine.time_scale = speed
		await get_tree().process_frame
		frames += 1
		if game.game_over:
			ended_by = "defeat"
		elif int(limits["waves"]) > 0 and recorder.waves_finished >= int(limits["waves"]):
			ended_by = "wave_cap"
		elif game.stats.time >= float(limits["game"]):
			ended_by = "game_time_cap"
		elif (Time.get_ticks_msec() - started) / 1000.0 >= float(limits["real"]):
			ended_by = "real_time_cap"
		elif game.waves.in_progress() and not recorder.waves.is_empty() and game.stats.time - float(recorder.waves[-1]["t_start"]) >= float(limits["wave"]):
			ended_by = "stalled"
	Engine.time_scale = 1.0
	recorder.finish(ended_by == "defeat")
	var rec := _record(c, game, player, recorder, ended_by, history, frames, (Time.get_ticks_msec() - started) / 1000.0, speed)
	player.queue_free()
	recorder.queue_free()
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return rec


func _record(c: Dictionary, game: Game, player: BalancePlayer, rec: BalanceRecorder, ended_by: String, history: Array, frames: int, real_seconds: float, speed: float) -> Dictionary:
	var village := game.player_village
	var survived := rec.waves_finished
	var cap_like := ended_by != "defeat"
	var important: Array = []
	for h: Array in history:
		if int(h[0]) == EventLog.Level.IMPORTANT:
			important.append(h[1])
	var result := {
		"waves_survived": survived, "wave_reached": game.waves.wave, "ended_by": ended_by, "censored": cap_like,
		"game_seconds": snappedf(game.stats.time, 0.01), "real_seconds": snappedf(real_seconds, 0.1), "frames": frames,
		"defeat": "" if ended_by != "defeat" else ("no_villagers" if village.population.count() == 0 else "no_huts"),
	}
	var out := {
		"schema": SCHEMA,
		"run_id": "%s-%s-%d-%s-%s" % [str(_args.get("label", "base")), c["map"], c["seed"], c["difficulty"], c["policy"]],
		"label": str(_args.get("label", "base")),
		"overrides": str(_args.get("overrides", "")),
		"rev": str(_args.get("rev", _git_rev())),
		"config_hash": _config_hash(),
		"headline": _headline(),
		"when": Time.get_datetime_string_from_system(true),
		"case": {"map_type": game.map.map_type, "map_requested": c["map"], "seed": c["seed"], "difficulty": c["difficulty"], "policy": c["policy"], "speed": speed},
		"result": result,
		"counters": game.stats.villages[0]["c"],
		"final": rec.state_snapshot(),
		"actions": player.commands_sent,
		"refusals": player.refusals,
		"early_calls": player.early_calls,
		"important_log": important.slice(maxi(important.size() - 12, 0)),
	}
	if not _args.has("no-detail"):
		out["waves"] = rec.waves
		out["timeline"] = rec.timeline
		var series := {}
		for k: String in Stats.SERIES:
			series[k] = Array(game.stats.series(0, k))
		series["t"] = Array(game.stats.times)
		out["stats_series"] = series
	return out


func _append(rec: Dictionary) -> void:
	var f := FileAccess.open(_out_path, FileAccess.READ_WRITE if FileAccess.file_exists(_out_path) else FileAccess.WRITE)
	if f == null:
		push_error("can't write %s" % _out_path)
		return
	f.seek_end()
	f.store_line(JSON.stringify(rec))
	f.close()


func _git_rev() -> String:
	var out := []
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
		return str(out[0]).strip_edges()
	return ""


## Identifies the numbers a game is played with: two records with the same
## hash were balanced the same.
func _config_hash() -> String:
	var all := {
		"enemies": Config.ENEMIES, "military": Config.MILITARY, "summons": Config.SUMMONS, "buildings": Config.BUILDINGS,
		"civilians": Config.CIVILIANS, "hero": Config.HERO, "hero_levels": Config.HERO_LEVELS, "tower_levels": Config.TOWER_LEVELS,
		"barracks_levels": Config.BARRACKS_LEVELS, "wave_mix": Config.WAVE_MIX, "start": Config.START_RESOURCES,
		"scalars": [Config.WAVE_HP_GROWTH, Config.FIRST_WAVE_DELAY, Config.WAVE_BUFFER, Config.FARM_RATE, Config.FOOD_UPKEEP,
			Config.MINE_GOLD_RATE, Config.CIVILIAN_HP, Config.UNIT_REGEN, Config.TREE_CHOP_TIME, Config.MATERIALS_TRADE,
			Config.EARLY_CALL_GOLD_PER_SECOND, Config.WAVE_MIX_CAP, Config.TEARDOWN_REFUND],
		"bot": [Config.BALANCE_BOT, Config.BALANCE_PROFILES],
	}
	return "%08x" % absi(var_to_str(all).hash())


## A few numbers that tell which balance a record was made with at a glance.
func _headline() -> Dictionary:
	return {
		"wave_hp_growth": Config.WAVE_HP_GROWTH, "goblin_hp": Config.ENEMIES["goblin"]["hp"], "goblin_damage": Config.ENEMIES["goblin"]["damage"],
		"archer_hp": Config.MILITARY["archer"]["stats"]["hp"], "archer_damage": Config.MILITARY["archer"]["stats"]["damage"],
		"archer_cost": Config.MILITARY["archer"]["cost"]["gold"], "start": Config.START_RESOURCES, "wave_buffer": Config.WAVE_BUFFER,
	}
