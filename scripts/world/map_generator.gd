class_name MapGenerator
extends RefCounted
## Seeded level generation (docs/world-design.md §3), in stages:
##   1. slices: one equal-area slice per player around the map centre,
##   2. fields: height and moisture,
##   3. water: coast (Coast type), lakes, rivers,
##   4. mountain ranges and volcanoes (ash land around them),
##   5. zones and vegetation,
##   6. villages near their slice's centre,
##   7-8. road network and routing (bridges, fords, passes),
##   9. fix steps: farm plot, fair land, trees for the camp,
##   10. special objects (treasures, camps, unlock sites, ruins, lairs, mines),
##   11. checks: a map that fails them is made again from the next seed.
## Only randomness seeded from `seed_value` is used, so a seed (and map type)
## always gives the same map (the co-op host generates, clients receive it).


static func generate(seed_value: int, players: int = 1, map_type: String = "temperate") -> MapData:
	var best: MapData = null
	var best_score := INF
	for attempt in Config.MAP_TRIES:
		var c := GenContext.new(seed_value + attempt * 7919, players, map_type)
		run(c)
		c.m.seed_value = seed_value
		var score := c.failures.size() * 100.0 + c.soft.size()
		if score < best_score:
			best_score = score
			best = c.m
		# Hard failures are retried; soft ones (slice fairness) only once.
		if c.failures.is_empty() and (c.soft.is_empty() or attempt >= 1):
			break
		if attempt == Config.MAP_TRIES - 1:
			push_warning("map %d (%s, %d players): %s" % [seed_value, map_type, players, "; ".join(c.failures + c.soft)])
	return best


static func run(c: GenContext) -> void:
	var t0 := Time.get_ticks_msec()
	var marks: Array[String] = []
	GenSlices.cut(c)
	marks.append("slices %d" % (Time.get_ticks_msec() - t0))
	GenFields.make(c)
	marks.append("fields %d" % (Time.get_ticks_msec() - t0))
	GenWater.place(c)
	marks.append("water %d" % (Time.get_ticks_msec() - t0))
	GenRelief.raise(c)
	marks.append("relief %d" % (Time.get_ticks_msec() - t0))
	GenZones.paint(c)
	marks.append("zones %d" % (Time.get_ticks_msec() - t0))
	GenVillages.place(c)
	marks.append("villages %d" % (Time.get_ticks_msec() - t0))
	GenRoads.build(c)
	marks.append("roads %d" % (Time.get_ticks_msec() - t0))
	GenFixes.run(c)
	marks.append("fixes %d" % (Time.get_ticks_msec() - t0))
	GenObjects.place(c)
	marks.append("objects %d" % (Time.get_ticks_msec() - t0))
	if OS.has_environment("GEN_PROFILE"):
		print(", ".join(marks))
	for t: Vector2i in c.beaches:
		if c.is_land(t) and not c.m.is_road(t):
			c.m.beaches[t] = true
	GenChecks.run(c)
