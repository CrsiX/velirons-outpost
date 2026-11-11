class_name MapGenerator
extends RefCounted
## Seeded level generation (docs/world-design.md §3), in stages:
##   1. slices: one equal-area slice per player around the map centre,
##   2. fields: height and moisture,
##   3. water: coast (Coast type), lakes, rivers,
##   4. mountain ranges and volcanoes (ash land around them),
##   5. zones and vegetation,
##   6. villages near their slice's centre, then water near them for the
##      water monsters (Coast: an inlet each; else maybe a lagoon),
##   7-8. road network and routing (bridges, fords, passes), a landing road
##      to each inlet or lagoon,
##   9. fix steps: fair land, trees for the camp,
##   10. special objects (treasures, camps, unlock sites, ruins, lairs, mines),
##      and the water monsters' spawns,
##   11. checks: a map that fails them is made again from the next seed.
## Only randomness seeded from `seed_value` is used, so a seed (and map type)
## always gives the same map (the co-op host generates, clients receive it).


## Tests: every try fails its checks (the start screen's give-up path).
static var fail_for_test := false


## `size` 0: the usual size for the player count (Config.map_size); any of
## Config.MAP_SIZES otherwise (the map editor).
static func generate(seed_value: int, players: int = 1, map_type: String = "temperate", size: int = 0) -> MapData:
	var best: MapData = null
	var best_score := INF
	for attempt in Config.MAP_TRIES:
		var c := _context(seed_value, attempt, players, map_type, size)
		run(c)
		c.m.seed_value = seed_value
		var score := _score(c)
		if score < best_score:
			best_score = score
			best = c.m
		if _accepted(c, attempt):
			break
		if attempt == Config.MAP_TRIES - 1:
			_warn(c, seed_value, map_type, players)
	return best


## The same, over several frames (the start screen, docs/ui-design.md §2a):
## a frame after each stage, so the screen can show `progress` (0..1, never
## backwards). Try n (from 1) fills the bar to n / (n + 1), weighted by
## Config.MAP_STAGE_WEIGHTS; a map that passes jumps it to 1. Null when every
## try fails its hard checks (no map worth playing).
static func generate_async(seed_value: int, players: int, map_type: String, progress: Callable) -> MapData:
	var tree := Engine.get_main_loop() as SceneTree
	var total := 0.0
	for w: float in Config.MAP_STAGE_WEIGHTS.values():
		total += w
	var best: MapData = null
	var best_score := INF
	var shown := 0.0
	for attempt in Config.MAP_TRIES:
		var lo := float(attempt) / float(attempt + 1)
		var hi := float(attempt + 1) / float(attempt + 2)
		var c := _context(seed_value, attempt, players, map_type, 0)
		var done := 0.0
		for st in stages():
			(st[1] as Callable).call(c)
			done += float(Config.MAP_STAGE_WEIGHTS.get(st[0], 0.0))
			shown = maxf(shown, lo + (hi - lo) * done / total)
			progress.call(shown)
			await tree.process_frame
		_finish(c)
		c.m.seed_value = seed_value
		var score := _score(c)
		if score < best_score:
			best_score = score
			best = c.m
		if _accepted(c, attempt):
			progress.call(1.0)
			return c.m
		if attempt == Config.MAP_TRIES - 1:
			_warn(c, seed_value, map_type, players)
	if best_score >= 100.0:
		return null  # (hard failures on every try)
	progress.call(1.0)
	return best  # (only soft failures left: played, as by generate)


static func _context(seed_value: int, attempt: int, players: int, map_type: String, size: int) -> GenContext:
	return GenContext.new(seed_value + attempt * 7919, players, map_type, size)


static func _score(c: GenContext) -> float:
	return c.failures.size() * 100.0 + c.soft.size()


## Hard failures are retried; soft ones (slice fairness) only once.
static func _accepted(c: GenContext, attempt: int) -> bool:
	return c.failures.is_empty() and (c.soft.is_empty() or attempt >= 1)


static func _warn(c: GenContext, seed_value: int, map_type: String, players: int) -> void:
	push_warning("map %d (%s, %d players): %s" % [seed_value, map_type, players, "; ".join(c.failures + c.soft)])


## The stages in order: [name (a Config.MAP_STAGE_WEIGHTS key), Callable(c)].
static func stages() -> Array:
	return [
		["slices", func(c: GenContext) -> void: GenSlices.cut(c)],
		["fields", func(c: GenContext) -> void: GenFields.make(c)],
		["water", func(c: GenContext) -> void: GenWater.place(c)],
		["relief", func(c: GenContext) -> void: GenRelief.raise(c)],
		["zones", func(c: GenContext) -> void: GenZones.paint(c)],
		["villages", func(c: GenContext) -> void: GenVillages.place(c)],
		["aqua", func(c: GenContext) -> void: GenWater.near_villages(c)],
		["roads", func(c: GenContext) -> void:
			GenRoads.build(c)
			GenWater.landings(c)],
		["fixes", func(c: GenContext) -> void: GenFixes.run(c)],
		["objects", func(c: GenContext) -> void:
			GenObjects.place(c)
			GenWater.water_spawns(c)],
		["checks", func(c: GenContext) -> void:
			for t: Vector2i in c.beaches:
				if c.is_land(t) and not c.m.is_road(t):
					c.m.beaches[t] = true
			GenChecks.run(c)],
	]


## One try, all stages at once (GEN_PROFILE set: each stage's time printed).
static func run(c: GenContext) -> void:
	var t0 := Time.get_ticks_msec()
	var marks: Array[String] = []
	for st in stages():
		(st[1] as Callable).call(c)
		marks.append("%s %d" % [st[0], Time.get_ticks_msec() - t0])
	if OS.has_environment("GEN_PROFILE"):
		print(", ".join(marks))
	_finish(c)


## After the stages: the tests' forced failure.
static func _finish(c: GenContext) -> void:
	if fail_for_test:
		c.failures.append("forced by a test")
