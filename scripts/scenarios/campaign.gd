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

## The campaign map's layout (docs/ui-design.md): its size, the places on it
## (each scenario names one, Scenario.place; scenarios on the same map share
## one), the road crossings and the roads, in the picture's units. The same
## file draws the picture (tools/gen_art.py, art "campaign_map").
const MAP_FILE := "res://data/campaign_map.json"
static var _layout := {}

## The map's region names, laid over the picture: [text, at (share), font size (map units)].
const REGIONS: Array = [
	["VELIRON", Vector2(0.6, 0.64), 34],
	["THE WILDERNESS", Vector2(0.6, 0.06), 18],
	["THE WARDLINE", Vector2(0.62, 0.128), 11],
	["KINGDOM OF\nKARMERE", Vector2(0.91, 0.27), 16],
	["REPUBLIC OF\nLYRENNE", Vector2(0.91, 0.62), 16],
	["THE HOLY DOMINION OF AURELITH", Vector2(0.55, 0.94), 18],
	["THE\nWESTERN\nOCEAN", Vector2(0.045, 0.36), 13],
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


# --- the map -------------------------------------------------------------------------------

## MAP_FILE, read once.
static func layout() -> Dictionary:
	if _layout.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
		_layout = d if d is Dictionary else {"size": [1200, 750], "places": {}, "junctions": {}, "roads": []}
	return _layout


static func map_size() -> Vector2:
	var sz: Array = layout()["size"]
	return Vector2(float(sz[0]), float(sz[1]))


## Place id -> {"name", "at": Vector2 (map units), "pin": its symbol (art "pin_<pin>")}.
static func places() -> Dictionary:
	var out := {}
	var ps: Dictionary = layout()["places"]
	for id: String in ps:
		var p: Dictionary = ps[id]
		out[id] = {"name": str(p["name"]), "at": _vec(p["at"]), "pin": str(p["pin"])}
	return out


## The way along the roads from place `from` to place `to` (the fewest miles),
## each road smoothed as the picture draws it; [] if no road leads there.
static func route(from: String, to: String) -> PackedVector2Array:
	var nodes := {}
	for id: String in layout()["places"]:
		nodes[id] = _vec(layout()["places"][id]["at"])
	for id: String in layout()["junctions"]:
		nodes[id] = _vec(layout()["junctions"][id])
	var edges := {}  # node -> [[next node, its road from here]]
	for r: Dictionary in layout()["roads"]:
		var pts := PackedVector2Array([nodes[r["a"]]])
		for q: Array in r["via"]:
			pts.append(_vec(q))
		pts.append(nodes[r["b"]])
		var back := pts.duplicate()
		back.reverse()
		for pair: Array in [[str(r["a"]), str(r["b"]), pts], [str(r["b"]), str(r["a"]), back]]:
			if not edges.has(pair[0]):
				edges[pair[0]] = []
			(edges[pair[0]] as Array).append([pair[1], pair[2]])
	var dist := {from: 0.0}
	var prev := {}
	var todo: Array = [from]
	while not todo.is_empty():
		todo.sort_custom(func(x: String, y: String) -> bool: return float(dist[x]) < float(dist[y]))
		var n: String = todo.pop_front()
		if n == to:
			break
		for e: Array in edges.get(n, []):
			var d := float(dist[n]) + _length(e[1])
			if d < float(dist.get(e[0], INF)):
				dist[e[0]] = d
				prev[e[0]] = [n, e[1]]
				todo.append(e[0])
	if not prev.has(to):
		return PackedVector2Array()
	var legs: Array = []
	var at := to
	while at != from:
		legs.push_front(prev[at][1])
		at = prev[at][0]
	var out := PackedVector2Array()
	for leg: PackedVector2Array in legs:
		var sm := smooth(leg)
		if not out.is_empty():
			sm = sm.slice(1)
		out.append_array(sm)
	return out


## Corner-cutting smoothing, the ends kept (tools/gen_art.py's chaikin does the same).
static func smooth(pts: PackedVector2Array, times := 3) -> PackedVector2Array:
	for _i in times:
		var out := PackedVector2Array([pts[0]])
		for k in pts.size() - 1:
			out.append(pts[k] * 0.75 + pts[k + 1] * 0.25)
			out.append(pts[k] * 0.25 + pts[k + 1] * 0.75)
		out.append(pts[pts.size() - 1])
		pts = out
	return pts


static func _length(pts: PackedVector2Array) -> float:
	var n := 0.0
	for k in pts.size() - 1:
		n += pts[k].distance_to(pts[k + 1])
	return n


static func _vec(v: Variant) -> Vector2:
	return Vector2(float((v as Array)[0]), float((v as Array)[1]))


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
