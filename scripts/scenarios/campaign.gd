class_name Campaign
extends RefCounted
## The campaign (docs/scenarios-design.md): its scenarios in order, each one
## file. Add a scenario by writing scenario_<n>.gd and listing it here.
##
## The player's progress (which scenarios are completed) is kept on this device
## in PROGRESS_FILE, each scenario by its title, so adding, removing or
## reordering scenarios keeps it: the file also records the campaign it was
## written for ("campaign", the titles in order) and its format.

const SCENARIOS: Array[Script] = [
	preload("res://scripts/scenarios/scenario_1.gd"),
	preload("res://scripts/scenarios/scenario_2.gd"),
	preload("res://scripts/scenarios/scenario_3.gd"),
	preload("res://scripts/scenarios/scenario_4.gd"),
	preload("res://scripts/scenarios/scenario_5.gd"),
	preload("res://scripts/scenarios/scenario_6.gd"),
	preload("res://scripts/scenarios/scenario_7.gd"),
	preload("res://scripts/scenarios/scenario_8.gd"),
	preload("res://scripts/scenarios/scenario_9.gd"),
	preload("res://scripts/scenarios/scenario_10.gd"),
	preload("res://scripts/scenarios/scenario_11.gd"),
]

## How many the campaign will have (the map says the rest are to come).
const PLANNED := 11

## The campaign map's picture (art "campaign_map"), in its own units.
const MAP_SIZE := Vector2(1200, 750)
## The places on it (docs/story-design.md §4a): id -> {"name", "at": a share
## of MAP_SIZE, "pin": its symbol (art "pin_<pin>")}. Each scenario names its
## place (Scenario.place); scenarios on the same map share one.
const PLACES := {
	"outpost": {"name": "The outpost", "at": Vector2(0.35, 0.2), "pin": "outpost"},
	"guild_town": {"name": "The guild town", "at": Vector2(0.14, 0.47), "pin": "guild"},
	"old_fort": {"name": "The old fort", "at": Vector2(0.69, 0.22), "pin": "fort"},
	"battlefield": {"name": "The battlefield", "at": Vector2(0.54, 0.44), "pin": "battlefield"},
	"refuge": {"name": "Fiona's refuge", "at": Vector2(0.73, 0.63), "pin": "grove"},
	"capital": {"name": "The capital", "at": Vector2(0.42, 0.6), "pin": "palace"},
	"abbey": {"name": "The drowned abbey", "at": Vector2(0.36, 0.8), "pin": "abbey"},
}
## The map's region names, laid over the picture: [text, at (share), font size (map units)].
const REGIONS: Array = [
	["VELIRON", Vector2(0.56, 0.78), 30],
	["THE WILDERNESS", Vector2(0.5, 0.045), 18],
	["KINGDOM OF\nKARMERE", Vector2(0.91, 0.27), 16],
	["REPUBLIC OF\nLYRENNE", Vector2(0.91, 0.62), 16],
	["THE HOLY DOMINION OF AURELITH", Vector2(0.55, 0.94), 18],
	["THE\nWESTERN\nOCEAN", Vector2(0.045, 0.3), 13],
]

const PROGRESS_FILE := "user://campaign.json"
## The progress file's layout; a file of another format is ignored (read as no progress).
const PROGRESS_FORMAT := 1


static func count() -> int:
	return SCENARIOS.size()


## Scenario `n` (1-based), made fresh, or null if there is none.
static func scenario(n: int) -> Scenario:
	if n < 1 or n > SCENARIOS.size():
		return null
	return SCENARIOS[n - 1].new() as Scenario


## The scenarios' titles in order.
static func titles() -> Array[String]:
	var out: Array[String] = []
	for n in range(1, count() + 1):
		out.append(scenario(n).title)
	return out


# --- progress ---------------------------------------------------------------------------------

## The titles of the completed scenarios (also ones no longer in the campaign).
static func completed() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(PROGRESS_FILE):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_FILE))
	if not data is Dictionary or int((data as Dictionary).get("format", 0)) != PROGRESS_FORMAT:
		return out
	var list: Variant = (data as Dictionary).get("completed", [])
	if list is Array:
		for t: Variant in list:
			if t is String and not out.has(t):
				out.append(t)
	return out


## Scenario `n` is won: remembered as completed.
static func complete(n: int) -> void:
	var done := completed()
	var t := scenario(n).title
	if done.has(t):
		return
	done.append(t)
	var f := FileAccess.open(PROGRESS_FILE, FileAccess.WRITE)
	if f == null:
		push_warning("Campaign: can't write %s" % PROGRESS_FILE)
		return
	f.store_string(JSON.stringify({"format": PROGRESS_FORMAT, "campaign": titles(), "completed": done}, "\t"))


## Forgets all progress (tests).
static func reset_progress() -> void:
	if FileAccess.file_exists(PROGRESS_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_FILE))


static func is_completed(n: int, done: Array[String]) -> bool:
	return n >= 1 and n <= count() and done.has(scenario(n).title)


## Scenario `n` can be played: the first one, one after a completed one, or
## one before a completed one (so a scenario added later never locks out the
## ones already played). `all` (debug builds): every one.
static func unlocked(n: int, done: Array[String], all := OS.is_debug_build()) -> bool:
	if n < 1 or n > count():
		return false
	if all or n == 1 or is_completed(n - 1, done):
		return true
	for m in range(n, count() + 1):
		if is_completed(m, done):
			return true
	return false


## The scenario to play next: the one after the highest completed (1 if none),
## 0 when the last is completed.
static func next_to_play(done: Array[String]) -> int:
	var n := 1
	for m in range(1, count() + 1):
		if is_completed(m, done):
			n = m + 1
	return n if n <= count() else 0
