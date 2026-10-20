class_name LeviathanBehavior
extends AquaBehavior
## The leviathan (docs/aquatic-design.md §5): never leaves deep water and
## never moves while up. Submerged it swims to a deep tile from which someone
## of ours is within blast range (else the one nearest the village), comes up
## for surface_min..surface_max s and channels its water blast (a wind-up,
## then damage every second for blast_time) at someone in range, a blast every
## blast_cooldown. Losing flee_share of its max HP while up makes it dive
## early (but the next time it stays up at least flee_min_up s). After each
## dive it moves on at least move_on tiles. With nobody about it still comes
## up every idle_surface s, at the deep tile nearest the village, where towers
## can be built to cover it: it must always be killable.

enum State { SWIM, UP }

var state := State.SWIM
var _started := false
var _up_t := 0.0
var _up_for := 0.0
var _hp_up := 0.0
var _min_up := 0.0
var _idle := 0.0
var _cooldown := 0.0
var _blast_t := -1.0
var _victim: Node = null
var _plan := 0.0
var _last_spot := Vector2i(-1, -1)


func tick(enemy: Enemy, delta: float) -> bool:
	enemy.self_moved = true
	if not _started:
		_started = true
		enemy.dive = Enemy.Dive.DOWN  # (it arrives under water)
		enemy._show_dive()
	if state == State.SWIM:
		_tick_swim(enemy, delta)
	else:
		_tick_up(enemy, delta)
	return true


func _tick_swim(enemy: Enemy, delta: float) -> void:
	_idle += delta
	if enemy.dive != Enemy.Dive.DOWN:
		return  # (still going under)
	var blast_r := enemy.stat("blast_range")
	_plan -= delta
	if _plan <= 0.0 or _goal.x < 0:
		_plan = 1.5
		_goal = _spot(enemy, blast_r - 0.3, _last_spot, enemy.stat("move_on"))
	var there := _swim(enemy, delta)
	if not there:
		return
	enemy._set_moving(false)
	var someone := nearest_within(enemy, people(enemy.game), blast_r) != null
	if someone or _idle >= enemy.stat("idle_surface"):
		_come_up(enemy)


func _come_up(enemy: Enemy) -> void:
	state = State.UP
	_up_t = 0.0
	_up_for = randf_range(enemy.stat("surface_min"), enemy.stat("surface_max"))
	_hp_up = enemy.hp
	_idle = 0.0
	enemy.surface()
	home_village(enemy).events.debug("%s surfaces" % enemy.label())


func _tick_up(enemy: Enemy, delta: float) -> void:
	_cooldown -= delta
	if enemy.dive != Enemy.Dive.UP:
		return  # (still coming up)
	_up_t += delta
	_blast(enemy, delta)
	var early := _hp_up - enemy.hp >= enemy.stat("flee_share") * enemy.max_hp and _up_t >= _min_up
	if early or _up_t >= _up_for:
		_min_up = enemy.stat("flee_min_up") if early else 0.0
		_go_down(enemy)


func _blast(enemy: Enemy, delta: float) -> void:
	var blast_r := enemy.stat("blast_range")
	if _blast_t < 0.0:
		if _cooldown > 0.0:
			return
		_victim = nearest_within(enemy, people(enemy.game), blast_r)
		if _victim == null:
			return
		_blast_t = 0.0
		_cooldown = enemy.stat("blast_cooldown")
		enemy.game.log_for(_victim, EventLog.Level.DEBUG, "%s blasts water at %s" % [enemy.label(), enemy.game.who(_victim)])
	if not reachable(_victim) or (_victim.grid_pos as Vector2).distance_to(enemy.grid_pos) > blast_r + 0.5:
		_end_blast(enemy)
		return
	_blast_t += delta
	var windup := enemy.stat("blast_windup")
	enemy.face(_victim.grid_pos)
	enemy.fx["jet"] = _victim.grid_pos
	enemy.fx["wind"] = minf(_blast_t / maxf(windup, 0.01), 1.0)
	if _blast_t > windup:
		_victim.take_damage(enemy.stat("spell_damage") * delta, enemy, "magical")
	if _blast_t >= windup + enemy.stat("blast_time"):
		_end_blast(enemy)


func _end_blast(enemy: Enemy) -> void:
	_blast_t = -1.0
	_victim = null
	enemy.fx.erase("jet")
	enemy.fx.erase("wind")


func _go_down(enemy: Enemy) -> void:
	_end_blast(enemy)
	state = State.SWIM
	_last_spot = enemy.current_tile()
	_goal = Vector2i(-1, -1)
	_plan = 0.0
	enemy.dive_down()
	home_village(enemy).events.debug("%s dives" % enemy.label())


## Blasting someone counts as a fight too.
func engaged(enemy: Enemy) -> bool:
	return super(enemy) or _blast_t >= 0.0


func on_death(enemy: Enemy) -> void:
	_end_blast(enemy)
