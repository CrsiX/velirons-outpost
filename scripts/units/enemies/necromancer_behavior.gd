class_name NecromancerBehavior
extends EnemyBehavior
## Necromancers (Config.ENEMIES["necromancer"]) have no attack. When the
## corpse of another enemy lies within raise_range (and nobody else is raising
## or carrying it), one stops and channels on it for cast_time seconds (a
## green beam, Enemy.channel_to); then it rises again (Waves.raise_corpse)
## and the necromancer walks on for at least cast_time before the next one.
## A corpse that is gone before the spell is done: the cast is lost.
## While one of the village's fighters is near (the hero, a soldier or an
## elemental within raise_range, or a manned tower that has it in range), it
## doesn't walk on: it stays and waits for its next raise. In a High
## Priest's aura (it or the corpse) the spell takes necro_slow x as long.

var corpse: Corpse = null
var _channel := 0.0
var _cool := 0.0
var _scan := 0.0
var _ally_scan := 0.0
## A fighter of the village is near: it stands and waits (see tick).
var _held := false


func tick(enemy: Enemy, delta: float) -> bool:
	var cast := float(enemy.spec()["cast_time"])
	_cool -= delta
	if corpse != null:
		if not _corpse_ok(enemy):
			enemy.game.log_all(EventLog.Level.DEBUG, "%s loses its spell" % enemy.label())
			_stop(enemy)
			_cool = cast
			return false
		# Near a High Priest (it or the corpse in an aura) the spell takes longer.
		_channel += delta / maxf(Combat.necro_slow(enemy.game, enemy.grid_pos), Combat.necro_slow(enemy.game, corpse.grid_pos))
		enemy.face(corpse.grid_pos)
		corpse.modulate = Color(0.7, 1.0, 0.75).lerp(Color.WHITE, 0.5 + 0.5 * sin(_channel * 6.0))
		if _channel >= cast:
			var c := corpse
			_stop(enemy)
			_cool = cast
			enemy.game.waves.raise_corpse(c, enemy)
			return false
		return true
	_ally_scan -= delta
	if _ally_scan <= 0.0:
		_ally_scan = 0.3
		_held = _fighter_near(enemy)
	if _cool > 0.0:
		return _held
	_scan -= delta
	if _scan > 0.0:
		return _held
	_scan = 0.5
	var c := _find(enemy)
	if c == null:
		return _held
	corpse = c
	c.raising_by = enemy
	_channel = 0.0
	enemy.channel_to = c.grid_pos
	enemy.game.log_all(EventLog.Level.DEBUG, "%s starts raising %s (%s)" % [enemy.label(), c.label(), c.kind])
	return true


func on_death(enemy: Enemy) -> void:
	_stop(enemy)


func _corpse_ok(enemy: Enemy) -> bool:
	return is_instance_valid(corpse) and enemy.game.corpses.corpses.has(corpse) and corpse.claimed_by == null and corpse.raising_by == enemy


func _stop(enemy: Enemy) -> void:
	if is_instance_valid(corpse):
		corpse.modulate = Color.WHITE
		if corpse.raising_by == enemy:
			corpse.raising_by = null
	corpse = null
	enemy.channel_to = Vector2.INF


static func _fighter_near(enemy: Enemy) -> bool:
	var r := float(enemy.spec()["raise_range"])
	for node in enemy.get_tree().get_nodes_in_group("melee_defenders"):
		if not node.dead and node.grid_pos.distance_to(enemy.grid_pos) <= r:
			return true
	for b in enemy.game.world.towers():
		var t := b as Tower
		if t and t.garrison != null and t.garrison.state == MilitaryUnit.State.STATIONED and Vector2(t.tile).distance_to(enemy.grid_pos) <= t.range_tiles():
			return true
	return false


## The nearest corpse it may raise: another kind's, never raised before, not
## claimed by a gatherer or another necromancer.
static func _find(enemy: Enemy) -> Corpse:
	var best: Corpse = null
	var best_d := float(enemy.spec()["raise_range"])
	for c in enemy.game.corpses.corpses:
		if not c.revivable or c.claimed_by != null or (c.raising_by != null and is_instance_valid(c.raising_by)):
			continue
		var d := c.grid_pos.distance_to(enemy.grid_pos)
		if d <= best_d:
			best_d = d
			best = c
	return best
