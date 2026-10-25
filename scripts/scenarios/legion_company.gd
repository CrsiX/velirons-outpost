class_name LegionCompany
extends Node
## A Dread Legion company after the First King's Hand (scenario 9,
## docs/scenarios-design.md §9a): its captain (Lysa) and the soldiers with
## her. The scenario says where the relic is (`relic`); the company goes for
## it, wherever it is:
## - sealed in the abbey's crypt: they march to the abbey and strike the seal
##   (Treasure.seal_hp) until it breaks; Lysa searches the crypt (SEARCH_TIME);
## - lying on the ground: Lysa walks to it and picks it up at once;
## - in the church (home): they march on the village and break in as any
##   enemy does; inside, Lysa goes to the church and searches it;
## - carried by the hero: they march on the village.
## With the relic Lysa walks back to the map edge she came from: there she is
## gone with it (escaped). Beaten (a captain falls back below 30 % HP) she
## drops it where she stands; her soldiers then stand round it and fight on
## until someone takes it, and go for the village after that.
##
## The soldiers march as a company: each keeps a place in a loose column on
## the captain's trail (ranks two abreast, a little apart), and fights what
## comes at it as ever (their behaviors). Each one's errand is this company
## (Enemy.errand): the end of a path it was given is a place to stand, not a
## gate.

signal seal_broken
## The relic is Lysa's now; `from`: "crypt", "ground" or "church".
signal relic_taken(from: String)
## Lysa was beaten while carrying it: it lies on `tile`.
signal relic_dropped(tile: Vector2i)
## Lysa got to the map edge with it.
signal escaped

enum State { MARCH, BREAK, SEARCH, CARRY, BROKEN }

## Seconds Lysa searches the crypt or the church for the relic.
const SEARCH_TIME := 8.0
## Tiles between ranks of the column, and to each side of the trail.
const RANK := 0.85
const SIDE := 0.32
## The seal takes each soldier's blow x this (Legion soldiers striking a door).
const SEAL_SHARE := 1.0
## How near the abbey (tiles) a soldier strikes the seal, and Lysa picks up a relic.
const AT_ABBEY := 2.4
const PICK_UP := 0.7
## Seconds between re-planning the captain's way.
const REPLAN := 1.0

var game: Game
var leader: Enemy = null
var members: Array[Enemy] = []
var abbey: Treasure = null
## Callable() -> {"at": "crypt" | "ground" | "church" | "hero" | "lysa" | "home",
## "sack": the relic lying on the ground (a Treasure), "church": the Church}.
var relic: Callable
var state := State.MARCH
## Lysa carries the relic.
var carrying := false
var _search_left := 0.0
var _search_at := ""
var _trail := PackedVector2Array()
var _replan := 0.0
var _goal := ""
var _hit_cd := {}
var _relic_spr: Sprite2D
## Lysa is inside the walls, on her way to the church (the siege leaves her alone).
var _inside := false


func setup(p_game: Game, p_abbey: Treasure, p_relic: Callable) -> void:
	game = p_game
	abbey = p_abbey
	relic = p_relic


## A company member on the map (Waves "on_spawn"); the captain leads.
func join(e: Enemy) -> void:
	e.errand = self
	if e.kind == "legion_captain":
		leader = e
		_trail = PackedVector2Array([e.grid_pos])
	else:
		members.append(e)


func _process(delta: float) -> void:
	if game == null or game.is_client or game.game_over:
		return
	members = members.filter(func(m: Enemy) -> bool: return is_instance_valid(m) and not m.dead)
	if state == State.BROKEN:
		_tick_broken()
		return
	if leader == null:
		return  # (she hasn't come out yet: the soldiers walk their road)
	if not is_instance_valid(leader) or leader.dead or leader.retreating:
		_break_up()
		return
	if _trail.is_empty() or leader.grid_pos.distance_to(_trail[-1]) > 0.2:
		_trail.append(leader.grid_pos)
		if _trail.size() > 200:
			_trail = _trail.slice(_trail.size() - 200)
	match state:
		State.MARCH:
			_tick_march(delta)
		State.BREAK:
			_tick_break(delta)
		State.SEARCH:
			_tick_search(delta)
		State.CARRY:
			pass
	_place_members(delta)
	if is_instance_valid(_relic_spr):
		_relic_spr.visible = leader.visible


# --- the captain -------------------------------------------------------------------------------

func _tick_march(delta: float) -> void:
	var r: Dictionary = relic.call()
	var at := str(r["at"])
	_replan -= delta
	if at == _goal and _replan > 0.0:
		return
	_replan = REPLAN
	var changed := at != _goal
	_goal = at
	match at:
		"crypt":
			if changed:
				_route_to(abbey.visit_tile())
		"ground":
			var sack := _sack(r)
			if sack:
				if leader.grid_pos.distance_to(Vector2(sack.tile)) <= PICK_UP:
					_take("ground", sack)
				else:
					_walk_to(sack.tile)
		"church":  # (the village, breaking in as any enemy; inside, to the church)
			var church: Church = r.get("church")
			var v := leader.target_village
			if not _inside and is_instance_valid(church) and v and v.rect.grow(-1).has_point(leader.current_tile()):
				_inside = true
				_walk_to(church.tile)
		_:  # (carried by the hero: the village, as any enemy)
			if changed and leader.path_index >= leader.path.size():
				_back_on_road()


## The siege leaves her alone (Enemy._may_siege): inside on her way to the
## church, searching, or carrying the relic away.
func holds(e: Enemy) -> bool:
	return e == leader and state != State.BROKEN and (_inside or state in [State.SEARCH, State.CARRY])


## Its walk ended (Enemy.errand): a place to stand, or where it goes on.
func on_path_end(e: Enemy) -> bool:
	if e.retreating or e.errand != self:
		return false
	if e != leader or state == State.BROKEN:
		return true  # (a soldier at its place in the column, or round the relic: it waits there)
	match state:
		State.CARRY:
			_escape()
			return true
		State.MARCH:
			var r: Dictionary = relic.call()
			match str(r["at"]):
				"crypt":
					if leader.grid_pos.distance_to(Vector2(abbey.visit_tile())) <= AT_ABBEY:
						if abbey.sealed:
							state = State.BREAK
							game.player_village.events.important("The Legion strikes at the abbey's seal!")
						else:
							_begin_search("crypt")
					else:
						_route_to(abbey.visit_tile())
					return true
				"ground":
					var sack := _sack(r)
					if sack and leader.grid_pos.distance_to(Vector2(sack.tile)) <= PICK_UP + 0.5:
						_take("ground", sack)
					return true
				"church":
					var church: Church = r.get("church")
					if is_instance_valid(church) and game.map.in_village(leader.current_tile()):
						if leader.grid_pos.distance_to(Vector2(church.tile)) <= 1.6:
							_begin_search("church")
						else:
							_walk_to(church.tile)
						return true
			return false  # (at the village: break in as ever)
	return true


## Along her road to where it passes nearest `goal`, then across to it.
func _route_to(goal: Vector2i) -> void:
	var path := leader.path
	var best := leader.path_index
	var best_d := INF
	for i in range(leader.path_index, path.size()):
		var d := path[i].distance_to(Vector2(goal))
		if d < best_d:
			best_d = d
			best = i
	var from := Vector2i(path[best].round()) if best < path.size() else leader.current_tile()
	var across := game.world.pathing.find_path(from, goal)
	var way := path.slice(leader.path_index, best + 1) if best < path.size() else PackedVector2Array()
	way.insert(0, leader.grid_pos)
	if not across.is_empty():
		way.append_array(across.slice(1))
	leader.follow(way)


func _walk_to(goal: Vector2i) -> void:
	var p := game.world.pathing.find_path(leader.current_tile(), goal)
	if p.is_empty():
		p = PackedVector2Array([Vector2(goal)])
	p[0] = leader.grid_pos
	leader.follow(p)


## Back onto her road to the village (after a detour).
func _back_on_road() -> void:
	var road := game.world.pathing.nearest_road(leader.current_tile())
	var route := game.world.pathing.enemy_route(road, RandomNumberGenerator.new())
	var p := PackedVector2Array([leader.grid_pos])
	for t in route:
		p.append(Vector2(t))
	leader.follow(p)


func _tick_break(delta: float) -> void:
	if not abbey.sealed or abbey.seal_hp <= 0.0:
		_begin_search("crypt")
		return
	for e: Enemy in [leader] + members:
		if not is_instance_valid(e) or e.dead or e.grid_pos.distance_to(Vector2(abbey.tile)) > AT_ABBEY + 0.6:
			continue
		var cd := float(_hit_cd.get(e, 0.0)) - delta
		if cd <= 0.0:
			cd = e.stat("attack_cooldown") / e.haste()
			e.swing(Vector2(abbey.tile))
			abbey.seal_hp = maxf(0.0, abbey.seal_hp - e.stat("damage") * SEAL_SHARE)
			abbey.queue_redraw()
		_hit_cd[e] = cd
	if abbey.seal_hp <= 0.0:
		abbey.sealed = false
		abbey.refresh()
		seal_broken.emit()
		_begin_search("crypt")


func _begin_search(where: String) -> void:
	state = State.SEARCH
	_search_at = where
	_search_left = SEARCH_TIME
	leader.path = PackedVector2Array()
	leader.path_index = 0
	leader.float_text("Searching the %s..." % where, Color("e0d4b8"))
	game.player_village.events.important("%s searches the %s for the relic!" % [leader.label().capitalize(), where])


func _tick_search(delta: float) -> void:
	_search_left -= delta
	leader.sprite.rotation = sin(Time.get_ticks_msec() / 90.0) * 0.06
	if _search_left > 0.0:
		return
	leader.sprite.rotation = 0.0
	_take(_search_at, null)


## The relic is hers (from the crypt, the ground or the church): off to the edge.
func _take(from: String, sack: Treasure) -> void:
	if is_instance_valid(sack):
		sack.mark_looted()
	carrying = true
	state = State.CARRY
	_relic_spr = Art.sprite("relic_sword")
	_relic_spr.scale = Vector2(0.32, 0.32)
	_relic_spr.position = Vector2(0, -78)
	leader.add_child(_relic_spr)
	leader.float_text("The relic!", Color("ff7a6a"))
	relic_taken.emit(from)
	leader.follow(CaptainBehavior._way_back(leader))


func _escape() -> void:
	carrying = false
	escaped.emit()


## The captain is beaten or gone: she drops what she carries; the soldiers
## guard it, or go for the village.
func _break_up() -> void:
	state = State.BROKEN
	if carrying and is_instance_valid(leader):
		carrying = false
		if is_instance_valid(_relic_spr):
			_relic_spr.queue_free()
		relic_dropped.emit(leader.current_tile())
	if is_instance_valid(leader):
		leader.errand = null
	_tick_broken()


func _tick_broken() -> void:
	var r: Dictionary = relic.call()
	var sack := _sack(r) if str(r["at"]) == "ground" else null
	for i in members.size():
		var m := members[i]
		if not is_instance_valid(sack):
			if m.errand == self:
				m.errand = null
				var road := game.world.pathing.nearest_road(m.current_tile())
				var route := game.world.pathing.enemy_route(road, RandomNumberGenerator.new())
				var p := _way(m, Vector2(road))
				for t in route:
					p.append(Vector2(t))
				m.follow(p)
			continue
		var ang := TAU * float(i) / maxf(1.0, float(members.size()))
		var spot := Vector2(sack.tile) + Vector2(cos(ang), sin(ang)) * 1.1
		if m.grid_pos.distance_to(spot) > 0.3 and m.path_index >= m.path.size():
			m.follow(_way(m, spot))


## A soldier's way to `to`: straight where no deep water or mountain is in
## the way, else walked to the walkable tile nearest it (round the water,
## over a bridge) and on; stays put if there is no way.
func _way(m: Enemy, to: Vector2) -> PackedVector2Array:
	var pathing := game.world.pathing
	var d := m.grid_pos.distance_to(to)
	var clear := true
	for k in range(1, int(d / 0.25) + 1):
		var t := Vector2i(m.grid_pos.lerp(to, k * 0.25 / d).round())
		if (game.map.is_deep(t) and not game.map.is_bridge(t)) or game.map.is_mountain(t):
			clear = false
			break
	if clear:
		return PackedVector2Array([m.grid_pos, to])
	var p := pathing.find_path(m.current_tile(), pathing.nearest_walkable(Vector2i(to.round())))
	if p.is_empty():
		return PackedVector2Array([m.grid_pos])
	p[0] = m.grid_pos
	p.append(to)
	return p


## The relic lying on the ground in `r` (relic()), or null (taken meanwhile: freed).
static func _sack(r: Dictionary) -> Treasure:
	var s = r.get("sack")
	if s == null or not is_instance_valid(s) or (s as Treasure).looted:
		return null
	return s


# --- the column ------------------------------------------------------------------------------

## Each soldier walks to its place: in the column on the captain's trail, or
## round the abbey while they break the seal.
func _place_members(_delta: float) -> void:
	for i in members.size():
		var m := members[i]
		if m.retreating:
			continue
		var spot: Vector2
		if state == State.BREAK or (state == State.SEARCH and _search_at == "crypt"):
			var ang := TAU * float(i) / maxf(1.0, float(members.size())) + 0.3
			spot = Vector2(abbey.tile) + Vector2(cos(ang), sin(ang)) * 1.6
		else:
			spot = _column_spot(i)
		var end := m.path[m.path.size() - 1] if m.path.size() > 0 else m.grid_pos
		if end.distance_to(spot) > 0.4 or (m.path_index >= m.path.size() and m.grid_pos.distance_to(spot) > 0.4):
			m.follow(_way(m, spot))


## Soldier `i`'s place: rank i / 2 behind the captain along her trail, to
## the left or right of it.
func _column_spot(i: int) -> Vector2:
	var back := RANK * float(i / 2 + 1)
	var k := _trail.size() - 1
	var walked := 0.0
	while k > 0 and walked + _trail[k].distance_to(_trail[k - 1]) < back:
		walked += _trail[k].distance_to(_trail[k - 1])
		k -= 1
	var p := _trail[k]
	var dir := (_trail[mini(k + 1, _trail.size() - 1)] - _trail[maxi(k - 1, 0)])
	if dir.length() < 0.01:
		dir = Vector2.DOWN
	var side := Vector2(-dir.y, dir.x).normalized() * (SIDE if i % 2 == 0 else -SIDE)
	return p + side
