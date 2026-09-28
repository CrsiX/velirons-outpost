class_name EventLog
extends Node
## Game event log shown in the HUD's log field. Three levels:
##   IMPORTANT - deaths (hero, villagers) and destroyed huts, with the cause;
##   INFO      - waves starting / ending, the hero's return, finished buildings,
##               upgrades and training;
##   DEBUG     - every player action and every game event.
## Every message is kept, whatever level is displayed, so changing the level
## also re-filters old messages. Per level only the newest MAX_PER_LEVEL are
## kept (so a flood of debug lines can't push out an important one), and any
## message is dropped LIFETIME seconds (real time) after it was logged.

signal changed
## Every message as it is logged (the log itself keeps only the recent ones).
signal logged(level: int, text: String)

enum Level { DEBUG, INFO, IMPORTANT }
const LEVEL_NAMES: Array[String] = ["Debug", "Info", "Important"]
const MAX_PER_LEVEL := 10
const MAX_SHOWN := 10
const LIFETIME := 30.0

## The lowest level displayed; the game starts on INFO.
var shown_level := Level.INFO
## Entries: {"level": Level, "text": String, "time": float (seconds, real time)}.
var entries: Array[Dictionary] = []
var _prune_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # messages expire while paused, too


func debug(text: String) -> void:
	add(Level.DEBUG, text)


func info(text: String) -> void:
	add(Level.INFO, text)


func important(text: String) -> void:
	add(Level.IMPORTANT, text)


func add(level: Level, text: String) -> void:
	entries.append({"level": level, "text": text, "time": now()})
	logged.emit(level, text)
	var same := entries.filter(func(e: Dictionary) -> bool: return e["level"] == level)
	if same.size() > MAX_PER_LEVEL:
		entries.erase(same[0])
	changed.emit()


## The newest messages at `shown_level` or above, oldest first.
func visible_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(entries.filter(func(e: Dictionary) -> bool: return e["level"] >= shown_level))
	return out.slice(maxi(0, out.size() - MAX_SHOWN))


func cycle_level() -> void:
	shown_level = ((shown_level + 1) % LEVEL_NAMES.size()) as Level
	changed.emit()


func level_name() -> String:
	return LEVEL_NAMES[shown_level]


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	_prune_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _prune_timer > 0.0:
		return
	_prune_timer = 0.5
	var t := now()
	var before := entries.size()
	entries.assign(entries.filter(func(e: Dictionary) -> bool: return t - e["time"] < LIFETIME))
	if entries.size() != before:
		changed.emit()
