class_name WrathwoodBehavior
extends EnemyBehavior
## A wrathwood (Config.ENEMIES["wrathwood"], docs/enemies-design.md §15c),
## woken by Wrathwoods out of a tree a forester started on. It walks its own
## way over ground and forest (Pathing.wood_path), never a road:
## WAKING (still its tree, shuddering) -> CHASE (the forester, until he is
## dead or safe) -> CAMP (his worker camp, until it is devastated) -> WANDER
## (a while round about) -> HOME (back to its tile) -> GUARD (for good: anyone
## of ours in its territory is attacked, within its leash). Whoever hurts it
## while it wanders, goes home or guards becomes its foe. In every state but
## GUARD a ready blow goes at whatever is in reach as it passes. It heals near
## trees, and now and then its roots hold everyone of ours close by in place.
## Only the host runs tick(); animate() runs on every machine and
## read `fx` ("wake": the tree's art while it wakes, "cast": the grip's pose,
## "grip": [[grid position, 0..1 of the hold]]).

enum State { WAKING, CHASE, CAMP, WANDER, HOME, GUARD }

var state := State.WAKING
## Its old tile (it guards it in the end).
var home := Vector2i.ZERO
## The art of the tree it was (shown while it wakes).
var tree_art := "tree_oak"
## Who woke it, and where he worked.
var forester: Civilian = null
var camp: Building = null
## Seconds of waking, of wandering and of the home boost left.
var wake_left := 0.0
var wander_left := 0.0
var boost_left := 0.0
## Someone (a unit, the hero, a tower) it fights back, and where its leash counts from.
var _foe: Node = null
var _foe_from := Vector2.ZERO
var _attack := 0.0
## Until the next root grip; the grip's pose left; who is held, for how long.
var _grip := 0.0
var _cast := 0.0
var _held: Dictionary = {}
var _goal := Vector2i(-1, -1)
var _plan := 0.0
var _wander_from := Vector2.ZERO
var _near_trees := false
var _tree_scan := 0.0
var _scan := 0.0
## What animate() shows now (every machine), and the roots drawn over the
## held (a child of the tree, above the units it holds).
var _shown := ""
var _t := 0.0
var _roots: Node2D = null


## Just woken out of the tree at `p_home` (art `p_art`) by `p_forester`.
func start(enemy: Enemy, p_home: Vector2i, p_art: String, p_forester: Civilian, p_camp: Building) -> void:
	var spec := enemy.spec()
	home = p_home
	tree_art = p_art
	forester = p_forester
	camp = p_camp
	state = State.WAKING
	wake_left = float(spec["wake_time"])
	_grip = float(spec["wake_time"]) + float(spec["grip_every"])
	enemy.fx = {"wake": tree_art}


func wild() -> bool:
	return true


func tick(enemy: Enemy, delta: float) -> bool:
	var spec := enemy.spec()
	_regrow(enemy, delta, spec)
	_hold(enemy, delta)
	if state == State.WAKING:
		wake_left -= delta
		if wake_left <= 0.0:
			enemy.fx.erase("wake")
			state = State.CHASE
			enemy.target_village.events.debug("%s is awake" % enemy.label())
		return true
	_attack -= delta
	_grip -= delta
	if _cast > 0.0:
		_cast -= delta
		if _cast <= 0.0:
			enemy.fx.erase("cast")
		return true
	if _grip <= 0.0 and _try_grip(enemy, spec):
		return true
	if state != State.CHASE and state != State.CAMP and _defend(enemy, delta, spec):
		return true
	match state:
		State.CHASE:
			if not is_instance_valid(forester) or forester.dead or _sheltered(forester):
				_next(enemy, State.CAMP)
				return true
			_go(enemy, delta, forester.current_tile(), 0.5)
			_swing_by(enemy, forester, spec)
		State.CAMP:
			if not is_instance_valid(camp) or not camp.complete or camp.devastated:
				_next(enemy, State.WANDER)
				return true
			if _in_reach(enemy, camp, float(spec["reach"])):
				enemy.face(Vector2(camp.tile))
				if _attack <= 0.0:
					_hit(enemy, camp, spec)
			else:
				_go(enemy, delta, camp.tile, 2.0)
				_swing_by(enemy, camp, spec)
		State.WANDER:
			wander_left -= delta
			if wander_left <= 0.0:
				_next(enemy, State.HOME)
				return true
			if _goal == Vector2i(-1, -1) or enemy.path_index >= enemy.path.size():
				_goal = _wander_spot(enemy, float(spec["wander_radius"]))
			_go(enemy, delta, _goal, 99.0)
			_swing_by(enemy, null, spec)
		State.HOME:
			if enemy.grid_pos.distance_to(Vector2(home)) < 0.1:
				_next(enemy, State.GUARD)
				return true
			_go(enemy, delta, home, 99.0)
			_swing_by(enemy, null, spec)
		State.GUARD:
			if enemy.grid_pos.distance_to(Vector2(home)) >= 0.1:
				_go(enemy, delta, home, 99.0)
	return true


## On to `s` (logged at Debug).
func _next(enemy: Enemy, s: State) -> void:
	state = s
	_goal = Vector2i(-1, -1)
	enemy.path = PackedVector2Array()
	enemy.path_index = 0
	var spec := enemy.spec()
	var what := ""
	match s:
		State.CAMP:
			what = "turns to %s" % camp.label() if is_instance_valid(camp) and camp.complete and not camp.devastated else "has nobody left to chase"
		State.WANDER:
			wander_left = float(spec["wander_time"])
			_wander_from = enemy.grid_pos
			what = "wanders about"
		State.HOME:
			what = "walks back to its spot"
		State.GUARD:
			boost_left = float(spec["home_boost_time"])
			what = "takes root at its old spot and guards it"
	enemy.target_village.events.debug("%s %s" % [enemy.label(), what])


# --- moving -------------------------------------------------------------------------------

## Walks towards `goal` over ground and forest, finding the way again every
## `replan` seconds (and when the goal changes or the way ends).
func _go(enemy: Enemy, delta: float, goal: Vector2i, replan: float) -> void:
	_plan -= delta
	if goal != _goal or _plan <= 0.0 or enemy.path_index >= enemy.path.size():
		_plan = replan
		_goal = goal
		var p := enemy.game.world.pathing.wood_path(enemy.current_tile(), goal)
		if p.size() < 2 and enemy.current_tile() != goal:
			enemy.path = PackedVector2Array()
			return
		p[0] = enemy.grid_pos
		enemy.follow(p)
	if enemy.path_index < enemy.path.size():
		enemy.walk_own(delta)


## Wanders round about `p` (a loaded game: where it stands).
func wander_from(p: Vector2) -> void:
	_wander_from = p


## A tile within `r` of where it started to wander that it can stand on.
func _wander_spot(enemy: Enemy, r: float) -> Vector2i:
	var pathing := enemy.game.world.pathing
	for i in 12:
		var a := randf() * TAU
		var t := Vector2i((_wander_from + Vector2(cos(a), sin(a)) * randf_range(1.0, r)).round())
		if pathing.wood_open(t):
			return t
	return enemy.current_tile()


# --- fighting -----------------------------------------------------------------------------

## Distance from the tree to `n`: a unit's position, or a building's footprint.
func _dist(enemy: Enemy, n: Node) -> float:
	if n is Building:
		var b := n as Building
		var o := b.tile - Vector2i((b.size - 1) / 2, (b.size - 1) / 2)
		return Hero.rect_distance(Rect2i(o, Vector2i(b.size, b.size)), enemy.grid_pos)
	return (n as Node2D).get("grid_pos").distance_to(enemy.grid_pos)


## Within `reach` of `n` (of a building's footprint from the tile next to it,
## diagonally too).
func _in_reach(enemy: Enemy, n: Node, reach: float) -> bool:
	return _dist(enemy, n) <= reach + (0.5 if n is Building else 0.0)


func _where(n: Node) -> Vector2:
	return Vector2((n as Building).tile) if n is Building else n.get("grid_pos")


## One blow at `n`: a building takes damage x siege.
func _hit(enemy: Enemy, n: Node, spec: Dictionary) -> void:
	_attack = enemy.stat("attack_cooldown")
	enemy.swing(_where(n))
	if n is Building:
		(n as Building).take_damage(enemy.stat("damage") * float(spec["siege"]), enemy, enemy.attack_category())
	else:
		enemy.blow(n, enemy.stat("damage"))


## Can it hit `n` (alive, standing, not sheltered)?
func _can_hit(n: Node) -> bool:
	if not is_instance_valid(n):
		return false
	if n is Building:
		var b := n as Building
		return b.can_be_hurt() and not (b is Hut)
	return not n.dead and not _sheltered(n)


static func _flies(n: Node) -> bool:
	return n.has_method("flies") and n.flies()


## Passing by: a ready blow goes at `target` if it is in reach, else at one of
## ours on the ground in reach, else at a building in reach (not a hut).
func _swing_by(enemy: Enemy, target: Node, spec: Dictionary) -> void:
	if _attack > 0.0:
		return
	var reach := float(spec["reach"])
	if target != null and _can_hit(target) and _in_reach(enemy, target, reach):
		_hit(enemy, target, spec)
		return
	for node in _ours(enemy):
		if not _flies(node) and node.grid_pos.distance_to(enemy.grid_pos) <= reach:
			_hit(enemy, node, spec)
			return
	var t := enemy.current_tile()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var b = enemy.game.map.building_at(t + Vector2i(dx, dy))
			if b is Building and _can_hit(b) and _in_reach(enemy, b, reach):
				_hit(enemy, b, spec)
				return


## Everyone of ours it could go for: exposed villagers, the hero, soldiers
## outside, elementals (alive, not sheltered).
func _ours(enemy: Enemy) -> Array:
	var out := []
	var seen := {}
	for node in enemy.get_tree().get_nodes_in_group("melee_defenders") + enemy.get_tree().get_nodes_in_group("villagers"):
		if seen.has(node) or node.dead or _sheltered(node):
			continue
		seen[node] = true
		out.append(node)
	return out


func on_damaged(enemy: Enemy, source: Node) -> void:
	if state == State.WAKING or state == State.CHASE or state == State.CAMP:
		return
	if not (source is Building or source is Unit) or not _can_hit(source) or (_can_hit(_foe) and _foe != source and _dist(enemy, _foe) <= _dist(enemy, source)):
		return
	if _foe != source:
		enemy.target_village.events.debug("%s turns on %s" % [enemy.label(), source.label()])
	_foe = source
	_foe_from = Vector2(home) if state == State.GUARD else enemy.grid_pos


## Fighting back (and, guarding, anyone in its territory). Returns true while
## it does.
func _defend(enemy: Enemy, delta: float, spec: Dictionary) -> bool:
	if state == State.GUARD and not _can_hit(_foe):
		_scan -= delta
		if _scan <= 0.0:
			_scan = 0.25
			_foe = null
			var best := INF
			for node in _ours(enemy):
				var d: float = node.grid_pos.distance_to(Vector2(home))
				if d <= float(spec["territory"]) and d < best:
					best = d
					_foe = node
					_foe_from = Vector2(home)
	if not _can_hit(_foe):
		_foe = null
		return false
	var reach := float(spec["reach"])
	if _in_reach(enemy, _foe, reach):
		enemy.face(_where(_foe))
		if _attack <= 0.0:
			_hit(enemy, _foe, spec)
		return true
	if _where(_foe).distance_to(_foe_from) > float(spec["leash"]) + reach:
		_foe = null  # (out of its leash: it lets go)
		return false
	_go(enemy, delta, Vector2i(_where(_foe).round()), 0.5)
	return true


# --- regrowth and roots -------------------------------------------------------------------

## Near trees it heals `regrow` of its max HP per second; back home, `home_boost` x that for a while.
func _regrow(enemy: Enemy, delta: float, spec: Dictionary) -> void:
	boost_left -= delta
	_tree_scan -= delta
	if _tree_scan <= 0.0:
		_tree_scan = 0.5
		_near_trees = _trees_near(enemy, float(spec["regrow_radius"]))
	var rate := float(spec["regrow"])
	if boost_left > 0.0:
		rate *= float(spec["home_boost"])
	elif not _near_trees:
		return
	if enemy.hp < enemy.max_hp:
		enemy.hp = minf(enemy.max_hp, enemy.hp + enemy.max_hp * rate * delta)
		enemy.queue_redraw()


static func _trees_near(enemy: Enemy, r: float) -> bool:
	var c := enemy.current_tile()
	var n := ceili(r)
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var t := c + Vector2i(dx, dy)
			if Vector2(t).distance_to(enemy.grid_pos) <= r and enemy.game.world.is_tree(t):
				return true
	return false


## Roots out of the ground: everyone of ours on the ground within grip_radius
## is held in place grip_time s; it stops for grip_cast s.
func _try_grip(enemy: Enemy, spec: Dictionary) -> bool:
	var caught := []
	for node in _ours(enemy):
		if not _flies(node) and node is Unit and node.grid_pos.distance_to(enemy.grid_pos) <= float(spec["grip_radius"]):
			caught.append(node)
	if caught.is_empty():
		_grip = 0.25
		return false
	_grip = float(spec["grip_every"])
	_cast = float(spec["grip_cast"])
	enemy.fx["cast"] = true
	enemy.path = PackedVector2Array()
	enemy.path_index = 0
	var names := PackedStringArray()
	for n in caught:
		_held[n] = float(spec["grip_time"])
		names.append(n.label())
	Sfx.play("hit")
	enemy.target_village.events.debug("%s's roots hold %s" % [enemy.label(), ", ".join(names)])
	return true


## Keeps the held in place (Unit.force_move without a step) and tells every
## machine where the roots are.
func _hold(enemy: Enemy, delta: float) -> void:
	if _held.is_empty():
		if enemy.fx.has("grip"):
			enemy.fx.erase("grip")
		return
	var total := float(enemy.spec()["grip_time"])
	var roots := []
	for n in _held.keys():
		var left: float = _held[n] - delta
		if left <= 0.0 or not is_instance_valid(n) or n.dead:
			_held.erase(n)
			continue
		_held[n] = left
		(n as Unit).force_move(Vector2.ZERO, enemy)
		roots.append([(n as Unit).grid_pos, 1.0 - left / total])
	enemy.fx["grip"] = roots


func on_death(_enemy: Enemy) -> void:
	_held.clear()


# --- looks (every machine) ----------------------------------------------------------------

func animate(enemy: Enemy, delta: float) -> void:
	_t += delta
	var art := "unit_wrathwood"
	if enemy.fx.has("wake"):
		art = str(enemy.fx["wake"])
	elif enemy.fx.has("cast"):
		art = "unit_wrathwood_grip"
	if art != _shown:
		var flip := enemy.sprite.flip_h
		Art.apply(enemy.sprite, art)
		enemy.sprite.flip_h = flip
		enemy.sprite.rotation = 0.0
		if _shown.begins_with("tree") and not art.begins_with("tree"):  # (out of its tree)
			Combat.local_burst(enemy.game, "leaves", enemy.position + Vector2(0, -40), 1.2)
			enemy.sprite.scale = Vector2(0.4, 0.4)
			enemy.create_tween().tween_property(enemy.sprite, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shown = art
	if enemy.fx.has("wake"):
		# Shuddering, harder towards the end.
		var k := clampf(_t / float(enemy.spec()["wake_time"]), 0.0, 1.0)
		enemy.sprite.rotation = sin(_t * 38.0) * (0.02 + 0.06 * k)
	if enemy.fx.has("grip") and _roots == null:
		_roots = Node2D.new()
		_roots.z_index = 3  # (over the units they hold)
		_roots.draw.connect(_draw_roots.bind(enemy))
		enemy.add_child(_roots)
	if _roots:
		_roots.visible = enemy.fx.has("grip")
		_roots.queue_redraw()


## Roots breaking out of the ground round everyone held (fx "grip") and
## coiling up their legs: they grow at first and sink back at the end.
func _draw_roots(enemy: Enemy) -> void:
	if not enemy.fx.has("grip"):
		return
	var ms := Time.get_ticks_msec() / 1000.0
	for r in enemy.fx["grip"]:
		var at := Iso.to_world(Vector2(r[0])) - enemy.position
		var k := float(r[1])
		var grow := clampf(k / 0.15, 0.0, 1.0) * clampf((1.0 - k) / 0.2, 0.0, 1.0)
		if grow <= 0.0:
			continue
		_roots.draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		_roots.draw_circle(Vector2.ZERO, 17.0 * grow, Color(0.2, 0.13, 0.07, 0.45))  # broken earth
		_roots.draw_set_transform(Vector2.ZERO)
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			var base := at + Vector2(cos(a) * 15.0, sin(a) * 7.0)
			var top := at + Vector2(-cos(a) * 5.0, -10.0 - 9.0 * float(i % 3))  # (coiling round the legs)
			var pts := PackedVector2Array()
			for j in 9:
				var s := j / 8.0 * grow
				var curl := sin(s * PI) * 6.0 * (1.0 if i % 2 else -1.0) + sin(ms * 4.0 + i) * 1.2 * s
				pts.append(base.lerp(top, s) + Vector2(curl, 0.0))
			_roots.draw_polyline(pts, Color("15110d"), 5.0)
			_roots.draw_polyline(pts, Color("6b4a2c"), 3.0)
			_roots.draw_circle(pts[pts.size() - 1], 1.6, Color("8a6440"))
