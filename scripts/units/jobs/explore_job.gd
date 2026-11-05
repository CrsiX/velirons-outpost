class_name ExploreJob
extends CivilianJob
## Scouts the fog (Config.EXPLORE):
## - goes where it would uncover the most fog for the walk, keeping its
##   heading if it can: a target about a sight radius into the fog, so its
##   sweeps lie a sight width apart;
## - sticks to that target until it gets there or the fog round it is mostly
##   gone (not as soon as the target tile itself is seen);
## - finishes the fog within reach first, but on a leash: fog much farther
##   from the village than the village's nearest fog worth a trip scores
##   less the farther past it lies, so it turns and sweeps back through fog;
##   it goes straight for the village's fog only with nothing within reach
##   or far past the leash;
## - walks there through fog rather than over explored land or the way it
##   came this trip (`_trail`, Pathing.scout_path);
## - avoids fog another explorer is already heading for;
## - keeps away from monster camp guards (it would only flee from them, again
##   and again): fog by them waits until the camp is cleared, and so does fog
##   it fled from them on its way to (the way there runs past them).
## `reveal` is the sight radius used for exploring.

enum State { RESTING, EXPLORING, RETURNING }

var state := State.RESTING
## The unexplored tile it's after, and the walkable tile it goes to for it
## (the same, or the edge of forest / rock it can only look into).
var target := Vector2i(-1, -1)
var stand := Vector2i(-1, -1)
var reveal := Config.EXPLORER_REVEAL
var _reveal_timer := 0.0
var _think_timer := 0.0
## The fog round the target when it was picked (it re-picks once most is gone).
var _target_gain := 0
## Where it stood at the last pick: its heading is from there to here.
var _last_pick := Vector2.INF
## Fog set aside: [tile, the instance ids of the camp guards fled from on the
## way there]; it waits while any of them lives (Config.EXPLORER_BLOCKED_RADIUS
## around the tile).
var _blocked: Array = []
## 1 per tile on or by the way it walked since it left home (not saved: a
## loaded game starts a fresh one).
var _trail := PackedByteArray()
var _trail_at := Vector2i(-1, -1)


func _init(p_reveal: float = Config.EXPLORER_REVEAL) -> void:
	reveal = p_reveal


func tick(delta: float) -> void:
	match state:
		State.RESTING:
			w.rest_timer -= delta
			if w.rest_timer > 0.0:
				return
			w.rest_timer = 3.0  # idle re-check when nothing is left to explore
			if _pick_target():
				state = State.EXPLORING
		State.EXPLORING:
			_reveal_timer -= delta
			if _reveal_timer <= 0.0:
				_reveal_timer = 0.15
				var fresh := w.game.fog.reveal(w.grid_pos, reveal, w.village.id)
				if fresh > 0:
					w.on_action("explore")
					w.game.stats.credit(w.village, "explorers", w.label(), fresh)
			var arrived := w.step_path(delta)
			_mark_trail()
			_think_timer -= delta
			# There, or the fog round the target is mostly seen already: the next one.
			if arrived or (_think_timer <= 0.0 and _spent()):
				if not arrived:
					_think_timer = Config.EXPLORE["think_every"]
				if not _pick_target():
					_go_home_idle()
		State.RETURNING:
			var home := w.step_path(delta)
			_mark_trail()
			if home:
				w.arrive_home()
				state = State.RESTING
				w.rest_timer = 5.0


## Out in the field after a load: the next fog from here, else home.
func resume() -> void:
	if _pick_target():
		state = State.EXPLORING
	else:
		_go_home_idle()


func on_evade() -> void:
	if target != Vector2i(-1, -1):
		var guards: Array[int] = []
		for node in w.get_tree().get_nodes_in_group("enemies"):
			var g := node as Enemy
			if not g.dead and g.wild() and g.grid_pos.distance_to(w.grid_pos) < Config.EVADE_RADIUS + 0.5:
				guards.append(g.get_instance_id())
		if not guards.is_empty():
			_blocked.append([target, guards])
	state = State.RESTING
	target = Vector2i(-1, -1)


func release() -> void:
	target = Vector2i(-1, -1)


func exploring_target() -> Vector2i:
	return target


func _go_home_idle() -> void:
	target = Vector2i(-1, -1)
	state = State.RETURNING
	if w.at_home:
		w.head_home()
		return
	var p := _route(w.current_tile(), w.home_spot())
	if p.is_empty():
		w.head_home()
	else:
		w.follow(p)


## Override: an area its ways keep out of (the hero shut out, Hero.barred).
func _bar() -> Rect2i:
	return Rect2i()


## Sets off for `t` (from home or from here) by a scout route. False if
## there is no way.
func _walk_to(t: Vector2i) -> bool:
	var from := w.home_spot() if w.at_home else w.current_tile()
	if w.at_home:
		_trail.fill(0)  # (a new trip)
	var p := _route(from, t)
	if p.is_empty():
		p = w.find_way(from, t)
	return w.head_out_on(p)


func _route(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	var q: Dictionary = Config.EXPLORE
	var map := w.game.map
	if _trail.size() != map.size * map.size:
		_trail.resize(map.size * map.size)
		_trail.fill(0)
	return w.game.world.pathing.scout_path(from, to, w.game.fog.explored_of[w.village.id], _trail, float(q["explored_cost"]), float(q["trail_cost"]), _bar())


## Marks the tiles round where it stands as its trail.
func _mark_trail() -> void:
	if w.at_home:
		return
	var t := w.current_tile()
	if t == _trail_at:
		return
	_trail_at = t
	var map := w.game.map
	var n := map.size
	if _trail.size() != n * n:
		_trail.resize(n * n)
		_trail.fill(0)
	var r := int(Config.EXPLORE["trail_radius"])
	for y in range(maxi(0, t.y - r), mini(n, t.y + r + 1)):
		for x in range(maxi(0, t.x - r), mini(n, t.x + r + 1)):
			_trail[y * n + x] = 1


## Chooses the next target and starts walking. False if none is reachable.
func _pick_target() -> bool:
	var chosen := choose_target(w.current_tile() if not w.at_home else w.village.center)
	if chosen == Vector2i(-1, -1):
		return false
	if not _walk_to(stand):
		return false
	if chosen != target:
		w.village.events.debug("%s heads for the fog at %s" % [w.label(), str(chosen)])
	target = chosen
	_target_gain = gain(stand)
	_last_pick = w.grid_pos
	_think_timer = Config.EXPLORE["think_every"]
	return true


## Most of the fog the target was picked for is seen now.
func _spent() -> bool:
	return target == Vector2i(-1, -1) or gain(stand) <= floori(_target_gain * float(Config.EXPLORE["replan_share"]))


## Unexplored tiles it would see from `t` (those FogLayer.reveal uncovers).
func gain(t: Vector2i) -> int:
	return _gain_in(t, w.game.fog.explored_of[w.village.id], _sight())


func _gain_in(t: Vector2i, explored: PackedByteArray, sight: Array[Vector2i]) -> int:
	var n := w.game.map.size
	var fog := 0
	for o in sight:
		var x := t.x + o.x
		var y := t.y + o.y
		if x >= 0 and y >= 0 and x < n and y < n and explored[y * n + x] == 0:
			fog += 1
	return fog


## The offsets within its sight radius.
func _sight() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := ceili(reveal)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dy).length() <= reveal:
				out.append(Vector2i(dx, dy))
	return out


## Override: an extra factor on a tile's score (the hero stays near a site
## she had to flee from).
func _bias(_t: Vector2i) -> float:
	return 1.0


func choose_target(from: Vector2i) -> Vector2i:
	var pathing := w.game.world.pathing
	var map := w.game.map
	var explored := w.game.fog.explored_of[w.village.id]
	var from_village := w.game.world.village_distance(w.village)
	var claims: Array[Vector2i] = []
	for other in w.village.workers():
		if other != w and other.exploring_target() != Vector2i(-1, -1):
			claims.append(other.exploring_target())
	var danger := _with_blocked(_camp_danger())
	# The village's fog: [target, stand, steps from the village].
	var home := _village_fog(explored, claims, danger, from_village)
	var has_home: bool = home[0] != Vector2i(-1, -1)
	var limit := INF
	if has_home:
		limit = float(home[2]) * Config.EXPLORER_WANDER_FACTOR + Config.EXPLORER_WANDER_SLACK
	var local := _best_within(from, explored, claims, danger, from_village, limit)
	var best_local: Vector2i = local[0]
	var best_local_stand: Vector2i = local[1]
	if best_local == Vector2i(-1, -1):
		# Nothing within reach: the nearest fog, as a frontier search finds it.
		var near := pathing.nearest_frontier(from, explored, claims, Config.EXPLORER_CLAIM_RADIUS, Config.EXPLORER_CLAIM_PENALTY, danger)
		if near.is_empty():
			return Vector2i(-1, -1)
		best_local = near[0]
		best_local_stand = near[1]
	# Far past the leash (the leash only bends the way back otherwise): the
	# village's fog.
	var local_from_village := from_village[map.index(best_local_stand)]
	if has_home and local_from_village < Pathing.UNREACHABLE and local_from_village > limit + int(Config.EXPLORE["leash_hard"]):
		stand = home[1]
		return home[0]
	stand = best_local_stand
	return best_local


## The fog nearest the village worth a trip (see Config.EXPLORER_WANDER_FACTOR):
## [target, stand, steps from the village], or the nearest fog of all when no
## fog tile has enough fog in view; [(-1, -1), (-1, -1), 0] when none is left.
## Fog near another scout's target counts EXPLORER_CLAIM_PENALTY steps farther.
func _village_fog(explored: PackedByteArray, claims: Array[Vector2i], danger: PackedByteArray, from_village: PackedInt32Array) -> Array:
	var map := w.game.map
	var n := map.size
	var sight := _sight()
	var need := ceili(sight.size() * float(Config.EXPLORE["home_min_share"]))
	var best := -1
	var best_score := Pathing.UNREACHABLE
	for i in w.game.world.village_order(w.village):
		var d := from_village[i]
		if d >= best_score:
			break  # (nearest first: nothing nearer is left)
		if explored[i] == 1 or (not danger.is_empty() and danger[i] == 1):
			continue
		var t := Vector2i(i % n, i / n)
		if _gain_in(t, explored, sight) < need:
			continue
		var score := d
		for c in claims:
			if Vector2(c).distance_to(Vector2(t)) < Config.EXPLORER_CLAIM_RADIUS:
				score += Config.EXPLORER_CLAIM_PENALTY
				break
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		var b := Vector2i(best % n, best / n)
		return [b, b, from_village[best]]
	var near := w.game.world.pathing.nearest_frontier(w.village.center, explored, claims, Config.EXPLORER_CLAIM_RADIUS, Config.EXPLORER_CLAIM_PENALTY, danger)
	if near.is_empty():
		return [Vector2i(-1, -1), Vector2i(-1, -1), 0]
	return [near[0], near[1], from_village[map.index(near[1])]]


## The best tile within Config.EXPLORE.search_reach of `from` (see Config.EXPLORE),
## past `limit` steps from the village less the farther past:
## [target, stand] (the same walkable tile), or [(-1, -1), (-1, -1)].
func _best_within(from: Vector2i, explored: PackedByteArray, claims: Array[Vector2i], danger: PackedByteArray, from_village: PackedInt32Array, limit: float) -> Array[Vector2i]:
	var map := w.game.map
	var n := map.size
	var q: Dictionary = Config.EXPLORE
	var reached := PackedInt32Array()
	var dist := w.game.world.pathing.octile_within(from, float(q["search_reach"]), reached, danger)
	var sight := _sight()
	var heading := Vector2.ZERO
	if _last_pick != Vector2.INF and w.grid_pos.distance_to(_last_pick) > 0.5 and not w.at_home:
		heading = (w.grid_pos - _last_pick).normalized()
	var here := Vector2(from)
	var pull := float(q["leash_pull"])
	var best := -1
	var best_score := 0.0
	for i in reached:
		var t := Vector2i(i % n, i / n)
		var fog := _gain_in(t, explored, sight)
		if fog <= 0:
			continue
		var score := float(fog) / (dist[i] + float(q["dist_offset"]))
		if heading != Vector2.ZERO and t != from:
			score *= 1.0 + float(q["momentum"]) * heading.dot((Vector2(t) - here).normalized())
		for c in claims:
			if Vector2(c).distance_to(Vector2(t)) < Config.EXPLORER_CLAIM_RADIUS:
				score *= float(q["claim_factor"])
				break
		var vd := from_village[i]
		if vd < Pathing.UNREACHABLE and float(vd) > limit:
			score /= 1.0 + pull * (float(vd) - limit)
		score *= _bias(t)
		if score > best_score:
			best_score = score
			best = i
	if best < 0:
		return [Vector2i(-1, -1), Vector2i(-1, -1)]
	var b := Vector2i(best % n, best / n)
	return [b, b]


## Tiles near camp guards and wrathwoods (Enemy.wild: where it would
## flee), or empty if there are none.
func _camp_danger() -> PackedByteArray:
	var out := PackedByteArray()
	var map := w.game.map
	var r := Config.EVADE_RADIUS + 0.5
	for node in w.get_tree().get_nodes_in_group("enemies"):
		var g := node as Enemy
		if g.dead or not g.wild():
			continue
		if out.is_empty():
			out.resize(map.size * map.size)
		var c := g.grid_pos
		for y in range(floori(c.y - r), ceili(c.y + r) + 1):
			for x in range(floori(c.x - r), ceili(c.x + r) + 1):
				if x >= 0 and y >= 0 and x < map.size and y < map.size and Vector2(x, y).distance_to(c) < r:
					out[y * map.size + x] = 1
	return out


## `danger` with the fog set aside marked too (sized on demand); forgets what
## waits no more: every guard fled from is gone.
func _with_blocked(danger: PackedByteArray) -> PackedByteArray:
	var map := w.game.map
	var r := Config.EXPLORER_BLOCKED_RADIUS
	_blocked = _blocked.filter(func(b: Array) -> bool: return (b[1] as Array).any(func(id: int) -> bool:
		return is_instance_id_valid(id) and not (instance_from_id(id) as Enemy).dead))
	for b: Array in _blocked:
		if danger.is_empty():
			danger.resize(map.size * map.size)
		var c: Vector2i = b[0]
		for y in range(c.y - ceili(r), c.y + ceili(r) + 1):
			for x in range(c.x - ceili(r), c.x + ceili(r) + 1):
				if x >= 0 and y >= 0 and x < map.size and y < map.size and Vector2(x, y).distance_to(Vector2(c)) <= r:
					danger[y * map.size + x] = 1
	return danger


func status() -> String:
	match state:
		State.EXPLORING: return "exploring"
		State.RETURNING: return "returning home"
	return "resting"
