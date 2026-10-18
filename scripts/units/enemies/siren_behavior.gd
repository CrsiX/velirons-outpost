class_name SirenBehavior
extends AquaBehavior
## The siren (docs/aquatic-design.md §6): walks the amphibians' way (roads
## and water) and keeps her distance: once the nearest of ours (a unit, a
## building or a villager) is within hold_range she stops and sings. Her song
## (Combat.songs) pulls our mobile people towards her (Unit.force_move) and
## slows every unit's timers around her (Combat.song_rate); a High Priest's
## aura shields from it. After `patience` s without luring anyone she walks
## on to the gate and stops for nothing. Submerged while travelling in deep
## water, up when one of ours is within her song; she dives for dive_time s
## after losing dive_loss of her max HP within dive_window s.

var _patience := 0.0
var _march := false
var _scan := 0.0
var _hold := false
var _near_song := false
var _dive_left := 0.0
var _clock := 0.0
var _hp_log: Array = []
var _lured: Array[Node] = []


func tick(enemy: Enemy, delta: float) -> bool:
	_clock += delta
	var radius := enemy.stat("song_radius")
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.25
		_look(enemy, radius)
		_hp_log.append([_clock, enemy.hp])  # (HP over time, for diving when hurt fast)
	_tick_dive(enemy, delta)
	var up := enemy.dive == Enemy.Dive.UP
	if up:
		enemy.fx["song"] = radius
		_sing(enemy, delta, radius)
	else:
		enemy.fx.erase("song")
	if _march:
		return false
	if not _lured.is_empty():
		_patience = 0.0
	else:
		_patience += delta
	if _patience >= enemy.stat("patience"):
		_march = true
		home_village(enemy).events.debug("%s gives up waiting and heads for the gate" % enemy.label())
		return false
	return _hold and up


## Who is around: the nearest of ours for holding back, anyone within the
## song for coming up.
func _look(enemy: Enemy, radius: float) -> void:
	var game := enemy.game
	var nearest := INF
	_near_song = false
	for p in people(game):
		var d := (p.grid_pos as Vector2).distance_to(enemy.grid_pos)
		nearest = minf(nearest, d)
	for b in game.world.buildings:
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		nearest = minf(nearest, Vector2(b.tile).distance_to(enemy.grid_pos))
	_near_song = nearest <= radius
	_hold = nearest <= enemy.stat("hold_range")


## Under while travelling in deep water; up when one of ours is near; down for
## a while when hurt badly within a short time.
func _tick_dive(enemy: Enemy, delta: float) -> void:
	if _dive_left > 0.0:
		_dive_left -= delta
	if not enemy.can_submerge() or enemy.must_be_under():
		return  # (under a bridge she stays under: Enemy sees to it)
	if not enemy.on_deep():
		if enemy.dive == Enemy.Dive.DOWN or enemy.dive == Enemy.Dive.DIVING:
			enemy.surface()  # (shallow water and land: never under)
		return
	if _dive_left > 0.0:
		return
	if _near_song and not _march:
		if enemy.dive == Enemy.Dive.DOWN or enemy.dive == Enemy.Dive.DIVING:
			enemy.surface()
	elif enemy.dive == Enemy.Dive.UP and (_march or not _near_song):
		enemy.dive_down()


## Pulls every mobile one of ours whose strongest song is hers towards her.
func _sing(enemy: Enemy, delta: float, radius: float) -> void:
	_lured.clear()
	var game := enemy.game
	for p in people(game, true):
		var u := p as Unit
		var d := u.grid_pos.distance_to(enemy.grid_pos)
		if d > radius or d < 0.6:
			continue
		var s := Combat.song_at(game, u.grid_pos)
		if float(s[0]) <= 0.0 or (s[1] as Dictionary).get("e") != enemy:
			continue  # (a High Priest shields it, or another siren's song is stronger)
		var step := (enemy.grid_pos - u.grid_pos).normalized() * enemy.stat("song_pull") * float(s[0]) * delta
		u.force_move(step, enemy)
		_lured.append(u)


func on_hurt(enemy: Enemy) -> void:
	if _dive_left > 0.0 or not enemy.on_deep() or not enemy.can_submerge():
		return
	if recent_loss(_hp_log, _clock, enemy.stat("dive_window"), enemy.hp) >= enemy.stat("dive_loss") * enemy.max_hp:
		if enemy.dive_down():
			_dive_left = enemy.stat("dive_time")
			_hp_log.clear()
			home_village(enemy).events.debug("%s dives away from the attack" % enemy.label())


func on_death(enemy: Enemy) -> void:
	enemy.fx.erase("song")
	_lured.clear()
