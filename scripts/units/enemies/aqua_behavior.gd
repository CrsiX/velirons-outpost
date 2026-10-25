class_name AquaBehavior
extends EnemyBehavior
## What the water monsters share (docs/aquatic-design.md): who of ours they
## go for, and for the water-bound ones (leviathan, octopus) moving over the
## deep tiles of their own body of water towards a spot near the village.

## Deep tiles of its body near its village (where it looks for a spot), and
## the one nearest the village centre (where it comes up with nobody about);
## a guard's (Enemy.post): near its post, and the one nearest that.
var _near: Array[Vector2i] = []
var _home := Vector2i(-1, -1)
var _goal := Vector2i(-1, -1)
var _cached := false


## Keeps to the deep tiles within `leash` of `tile` from now on ((-1, -1): no
## post, the village as ever): a scenario moves a guard (scenario 9's octopus
## to the harbour and back, the leviathan between the crypt and the boats).
func set_post(enemy: Enemy, tile: Vector2i, leash: float) -> void:
	enemy.post = tile
	enemy.post_leash = leash
	_cached = false
	_near.clear()
	_home = Vector2i(-1, -1)
	_goal = Vector2i(-1, -1)


## Our people the monster can get at: villagers outside the walls, the hero
## outside, units outside (with `sortie_only`, only those out of their
## barracks), elementals. Never a unit on a tower or a bench, nobody inside
## the walls. Any village's.
static func people(game: Game, sortie_only := false) -> Array[Node]:
	var out: Array[Node] = []
	var tree := game.get_tree()
	for node in tree.get_nodes_in_group("villagers"):
		var c := node as Civilian
		if c.is_exposed():
			out.append(c)
	for node in tree.get_nodes_in_group("heroes"):
		var h := node as Hero
		if not h.dead and h.visible and not h.inside_walls():
			out.append(h)
	for node in tree.get_nodes_in_group("field_units"):
		var s := node as Soldier
		if s.dead or game.map.in_village(s.current_tile()):
			continue
		if sortie_only and not s.out_fighting():
			continue
		out.append(s)
	for node in tree.get_nodes_in_group("summons"):
		var el := node as EarthElemental
		if not el.dead:
			out.append(el)
	return out


## In a fight now: hurt within the last second, or (the kinds say) attacking
## someone or something. Waves: water-bound monsters left alone leave.
func engaged(enemy: Enemy) -> bool:
	return enemy.game.clock - enemy.hurt_at < 1.0


## Still someone it can get at?
static func reachable(n) -> bool:
	if not is_instance_valid(n) or n.is_queued_for_deletion():
		return false
	if n is Civilian:
		return (n as Civilian).is_exposed() or (n is Hero and not n.dead and n.visible and not (n as Hero).inside_walls())
	return not n.dead


## The village it threatens (its target, else the first).
static func home_village(enemy: Enemy) -> Village:
	if is_instance_valid(enemy.target_village):
		return enemy.target_village
	return enemy.game.villages[0]


func _cache(enemy: Enemy) -> void:
	if _cached:
		return
	_cached = true
	var pathing := enemy.game.world.pathing
	if enemy.body < 0:
		enemy.body = pathing.body_of(enemy.current_tile())
	if enemy.body < 0:
		return
	var c := Vector2(home_village(enemy).center)
	var r := float(Config.AQUA["threat_radius"]) + float(enemy.spec().get("reach", 5.0))
	if enemy.post.x >= 0:  # (a guard keeps to its post's water)
		c = Vector2(enemy.post)
		r = enemy.post_leash
	_home = pathing.nearest_deep(enemy.body, c)
	for t: Vector2i in pathing.bodies[enemy.body]["tiles"]:
		if enemy.game.map.is_deep(t) and Vector2(t).distance_to(c) <= r:  # (never a spot under a bridge)
			_near.append(t)


## A deep tile from which someone of ours is within `reach`, not within
## `keep_off` of `avoid` if there is a choice, nearest to the monster; else
## the tile nearest the village.
func _spot(enemy: Enemy, reach: float, avoid := Vector2i(-1, -1), keep_off := 0.0) -> Vector2i:
	_cache(enemy)
	var folk := people(enemy.game)
	var best := Vector2i(-1, -1)
	var best_d := INF
	var fallback := Vector2i(-1, -1)
	var fallback_d := INF
	if not folk.is_empty():
		for t in _near:
			var tp := Vector2(t)
			var in_reach := false
			for p in folk:
				if (p.grid_pos as Vector2).distance_to(tp) <= reach:
					in_reach = true
					break
			if not in_reach:
				continue
			var d := tp.distance_to(enemy.grid_pos)
			if avoid.x >= 0 and tp.distance_to(Vector2(avoid)) < keep_off:
				if d < fallback_d:
					fallback_d = d
					fallback = t
				continue
			if d < best_d:
				best_d = d
				best = t
	if best.x >= 0:
		return best
	if fallback.x >= 0:
		return fallback
	return _home


## Swims (over deep water only) towards `_goal`; true once there.
func _swim(enemy: Enemy, delta: float) -> bool:
	if _goal.x < 0:
		return true
	if enemy.path_index >= enemy.path.size() or Vector2i(enemy.path[enemy.path.size() - 1].round()) != _goal:
		if enemy.current_tile() == _goal and enemy.grid_pos.distance_to(Vector2(_goal)) < 0.05:
			return true
		var p := enemy.game.world.pathing.water_path(enemy.current_tile(), _goal)
		if p.is_empty():
			_goal = enemy.current_tile()
			return true
		p[0] = enemy.grid_pos
		enemy.follow(p)
	return enemy.walk_own(delta)


## Someone of ours within `r` of the monster, nearest first (or null).
static func nearest_within(enemy: Enemy, folk: Array[Node], r: float, exclude: Dictionary = {}) -> Node:
	var best: Node = null
	var best_d := r
	for p in folk:
		if exclude.has(p):
			continue
		var d := (p.grid_pos as Vector2).distance_to(enemy.grid_pos)
		if d <= best_d:
			best_d = d
			best = p
	return best


## HP lost within the last `window` seconds (from `log`: [[clock, hp], ...]).
static func recent_loss(log: Array, now: float, window: float, hp: float) -> float:
	while not log.is_empty() and float(log[0][0]) < now - window:
		log.pop_front()
	var top := hp
	for entry in log:
		top = maxf(top, float(entry[1]))
	return top - hp
