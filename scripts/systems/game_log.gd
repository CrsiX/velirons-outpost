class_name GameLog
extends Node
## Writes every event-log message of a game to a text file for debugging
## (Config.GAME_LOG). One line per message, fixed offsets:
##   [HH:MM:SS] [D|I|W] [WW] message
## in-game time, level (Debug / Info / Important as W), the wave counter
## padded to 2 digits. The file starts with a header (game version and commit, map, seed,
## village names, real time). A game that was loaded appends to its own file
## and says so (a line that never shows in the game's own log).
## On the web (debug builds only) there is no file: the lines are kept in
## memory for this running game and the Debug page downloads them
## (`download`). A loaded game's lines start at the load there.

const LEVEL_LETTERS := ["D", "I", "W"]

var game: Game
var path := ""
## Web debug builds: the lines kept in memory instead of a file.
var web_lines := PackedStringArray()
var _web := false
## Game.log_all adds the same message to every village: only one copy is written.
var _muted := false


## Opens (or, for a loaded game, reopens) the file and listens to every
## village's log. Writes nothing where a log makes no sense.
func setup(p_game: Game) -> void:
	game = p_game
	if game.backdrop or game.tutorial_mode or game.is_client:
		return
	if OS.has_feature("web"):
		if not OS.is_debug_build():
			return
		_web = true
		_listen()
		_write_header()
		return
	var dir := str(Config.GAME_LOG["dir"])
	DirAccess.make_dir_recursive_absolute(dir)
	path = _existing(dir) if game.loaded else ""
	var resumed := path != ""
	if not resumed:
		path = dir.path_join("%s_%s.log" % [Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"), game.game_id])
		_prune(dir)
	_listen()
	if resumed:
		return
	_write_header()


## Whether this game's log is being kept (in a file or, on the web, in memory).
func active() -> bool:
	return path != "" or _web


## Web: hands the browser the whole log so far as a text file.
func download() -> void:
	if not _web:
		return
	var file := "game_%s.log" % game.game_id
	JavaScriptBridge.download_buffer(("\n".join(web_lines) + "\n").to_utf8_buffer(), file, "text/plain")


func _listen() -> void:
	for v in game.villages:
		v.events.logged.connect(func(level: int, text: String) -> void: _on_logged(v, level, text))


## Game.log_all: one line for all villages, then the villages' own copies are
## ignored until `end_all`.
func begin_all(level: int, text: String) -> void:
	_write(level, text)
	_muted = true


func end_all() -> void:
	_muted = false


## A loaded game: the INFO line (real time, in-game time, wave) and a DEBUG
## snapshot of every village.
func note_resumed() -> void:
	if not active():
		return
	var real := Time.get_datetime_string_from_system(false, true)
	_write(EventLog.Level.INFO, "Game resumed (real time %s, in-game time %s, wave %d)" % [real, _clock(), game.waves.wave])
	for v in game.villages:
		_write(EventLog.Level.DEBUG, snapshot(v))


## The most important numbers of a village in one line.
func snapshot(v: Village) -> String:
	var buildings := v.buildings().filter(func(b: Building) -> bool: return b.complete and not (b is Hut or b is StaticPiece))
	var hero := v.hero
	return "Snapshot%s: hero level %d, hero XP %d, hero HP %d/%d, gold %d, food %d, materials %d, villagers %d, huts %d, military %d, buildings %d" % [
		(" of " + v.village_name) if game.villages.size() > 1 else "",
		hero.level + 1, hero.xp, int(hero.hp), int(hero.max_hp),
		int(v.economy.amount("gold")), int(v.economy.amount("food")), int(v.economy.amount("materials")),
		v.population.count(), v.intact_huts().size(), v.army.units.size(), buildings.size(),
	]


func _on_logged(v: Village, level: int, text: String) -> void:
	if _muted:
		return
	_write(level, text, ("[%s] " % v.village_name) if game.villages.size() > 1 else "")


func _write_header() -> void:
	var names: Array[String] = []
	for v in game.villages:
		names.append(v.village_name)
	var map_name := str(game.map.meta.get("name", ""))
	if game.scenario:
		map_name = "Scenario %d: %s" % [game.scenario.spec.number, game.scenario.spec.title]
	var lines: Array[String] = [
		"Game version: %s" % BuildInfo.game_version(),
		"Game commit:  %s" % BuildInfo.game_commit(),
		"Game id:      %s" % game.game_id,
		"Map type:     %s" % game.map_type,
		"Map seed:     %d" % game.map.seed_value,
		"Map name:     %s" % (map_name if map_name != "" else "(generated)"),
		"Village:      %s" % ", ".join(names),
		"Started:      %s" % Time.get_datetime_string_from_system(false, true),
		"",
	]
	if _web:
		web_lines.append_array(lines)
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")


func _write(level: int, text: String, prefix := "") -> void:
	if not active() or level >= LEVEL_LETTERS.size():
		return
	var line := "[%s] [%s] [%02d] %s%s" % [_clock(), LEVEL_LETTERS[level], game.waves.wave, prefix, text]
	if _web:
		web_lines.append(line)
		return
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)


## The in-game time, HH:MM:SS.
func _clock() -> String:
	var t := int(game.clock)
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


## The file this game was started in ("" if there is none any more).
func _existing(dir: String) -> String:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with("_%s.log" % game.game_id):
			return dir.path_join(f)
	return ""


## Deletes all but the newest files, to make room for the new one.
func _prune(dir: String) -> void:
	var files := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".log"))
	files.sort()  # (the names start with the date)
	for i in maxi(0, files.size() - int(Config.GAME_LOG["keep"]) + 1):
		DirAccess.remove_absolute(dir.path_join(str(files[i])))
