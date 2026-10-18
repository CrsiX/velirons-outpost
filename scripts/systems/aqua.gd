class_name Aqua
extends RefCounted
## Which water monsters can come for a village, and from where
## (docs/aquatic-design.md §9). Worked out once per game and village (Waves).
##
## The threatened tiles are the land and shallow tiles within AQUA
## threat_radius of the village centre that someone can stand on (not inside
## the walls). A kind is eligible when a body of deep water fits it
## (min_deep_tiles, min_width) and has a deep tile within the kind's reach of
## a threatened tile; water-bound kinds (leviathan, octopus) also only when a
## tower could cover the body's deep tile nearest the village (open land
## within a level 3 watchtower's reach of it), or nobody could ever kill them
## and the wave would never end. Amphibians (crab, siren) need a way over
## road and water to the village's gates.
##
## Spawns: the map's water spawns in a fitting body; with none there, a deep
## tile of the body at least AQUA spawn_shore from the threatened tiles (the
## farthest if none is that far). Amphibians may also come from the edge.


## {kind: Array[Vector2i] (its spawn tiles; may be empty for an amphibian,
## which then comes from the edge)} for village `vi`; kinds not listed can't
## come for it.
static func eligibility(game: Game, vi: int) -> Dictionary:
	var map := game.map
	var pathing := game.world.pathing
	var out := {}
	if pathing.bodies.is_empty() or vi < 0 or vi >= map.villages.size():
		return out
	var kinds: Array[String] = []
	var max_reach := 0.0
	for kind: String in Config.WAVE_MIX:
		if Config.WAVE_MIX[kind].get("needs", "") == "water":
			kinds.append(kind)
			max_reach = maxf(max_reach, float(Config.ENEMIES[kind].get("reach", 2.0)))
	var center: Vector2i = map.villages[vi]["center"]
	var dist := threat_distance(game, center, ceili(max_reach) + 1)
	var spawn_shore := float(Config.AQUA["spawn_shore"])
	var cover := Config.TOWER_RANGE["tower"] + float(Config.TOWER_LEVELS[Config.TOWER_LEVELS.size() - 1]["range_bonus"])
	var coverable := {}  # body -> bool
	for kind in kinds:
		var e: Dictionary = Config.ENEMIES[kind]
		var reach := float(e.get("reach", 2.0))
		var water_bound := str(e.get("habitat", "land")) == "water"
		var spawns: Array[Vector2i] = []
		var ok := false
		for b in pathing.bodies.size():
			if not pathing.body_fits(b, kind):
				continue
			var home := pathing.nearest_deep(b, Vector2(center))
			if home.x < 0 or dist[map.index(home)] > ceili(reach):
				continue
			if water_bound:
				if not coverable.has(b):
					coverable[b] = buildable_within(game, home, cover)
				if not coverable[b]:
					continue
			var mine: Array[Vector2i] = []
			for t in map.water_spawns:
				if pathing.body_of(t) == b and (water_bound or _amph_reaches(game, t, vi)):
					mine.append(t)
			if mine.is_empty():
				var pick := _far_tile(game, b, dist, spawn_shore)
				if pick.x >= 0 and (water_bound or _amph_reaches(game, pick, vi)):
					mine.append(pick)
			if water_bound and mine.is_empty():
				continue
			ok = true
			spawns.append_array(mine)
		if ok and not water_bound and spawns.is_empty() and not _edge_reaches(game, vi):
			ok = false
		if ok:
			out[kind] = spawns
	return out


## Chebyshev steps from the nearest threatened tile of the village at
## `center`, up to `limit` (beyond: limit + 1).
static func threat_distance(game: Game, center: Vector2i, limit: int) -> PackedInt32Array:
	var map := game.map
	var pathing := game.world.pathing
	var dist := PackedInt32Array()
	dist.resize(map.size * map.size)
	dist.fill(limit + 1)
	var r := float(Config.AQUA["threat_radius"])
	var queue: Array[Vector2i] = []
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var t := center + Vector2i(dx, dy)
			if not map.in_bounds(t) or Vector2(t).distance_to(Vector2(center)) > r:
				continue
			if pathing.is_walkable(t) and not map.in_village(t):
				dist[map.index(t)] = 0
				queue.append(t)
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		var d := dist[map.index(t)] + 1
		if d > limit:
			continue
		for k in 8:
			var nb := t + Vector2i([-1, 1, 0, 0, -1, 1, -1, 1][k], [0, 0, -1, 1, -1, -1, 1, 1][k])
			if map.in_bounds(nb) and dist[map.index(nb)] > d:
				dist[map.index(nb)] = d
				queue.append(nb)
	return dist


## Open land a tower could go on (grass or sand, nothing on it, not inside
## any walls nor by a crater) within `r` of `t`?
static func buildable_within(game: Game, t: Vector2i, r: float) -> bool:
	var map := game.map
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var p := t + Vector2i(dx, dy)
			if not map.in_bounds(p) or Vector2(p).distance_to(Vector2(t)) > r:
				continue
			var v := map.get_terrain(p)
			if v != MapData.Terrain.GRASS and v != MapData.Terrain.DESERT:
				continue
			if map.in_village(p) or map.near_crater(p) or map.building_at(p) != null:
				continue
			return true
	return false


## A deep tile of body `b` at least `shore` from the threatened tiles (`dist`),
## else its farthest one. (-1, -1) if the body has none.
static func _far_tile(game: Game, b: int, dist: PackedInt32Array, shore: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1
	var good: Array[Vector2i] = []
	for t: Vector2i in game.world.pathing.bodies[b]["tiles"]:
		if not game.map.is_deep(t):
			continue  # (not under a bridge)
		var d := dist[game.map.index(t)]
		if d >= ceili(shore):
			good.append(t)
		if d > best_d:
			best_d = d
			best = t
	if not good.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([game.map.seed_value, b])
		return good[rng.randi() % good.size()]
	return best


## Can an amphibian get from `t` to village `vi`'s gates over road and water?
static func _amph_reaches(game: Game, t: Vector2i, vi: int) -> bool:
	var field := vi if game.villages.size() > 1 else -1
	return game.world.pathing.enemy_distance(t, field, true) < Pathing.UNREACHABLE


## Does village `vi` have an edge spawn its waves come from?
static func _edge_reaches(game: Game, vi: int) -> bool:
	if game.villages.size() > 1:
		return not (game.map.villages[vi]["home_spawns"] as Array).is_empty()
	return not game.map.edge_spawns.is_empty()
