class_name WitchBehavior
extends EnemyBehavior
## Walks to the village until something worth enchanting is within spell range:
##   1. whoever last attacked her (a tower's unit, or an earth elemental),
##   2. otherwise the nearest manned tower or military unit outside (walking,
##      or out of a barracks: even a summoner, who never attacks her).
## She then stands and casts a pink bolt every `spell_cooldown` seconds. A bolt
## enchants a tower's unit for `spell_cooldown * enchant_ratio` seconds (it stops
## shooting/summoning; no damage), or deals `spell_damage` to an elemental or
## a unit outside.
## Witches never fight in melee.
##
## Anti-stall tracker: she counts her casts per target. A target that has taken
## `spell_ignore_after` casts is ignored from then on, unless that same target
## attacks her again, which resets its count. So she can't stand still forever
## bewitching something that never fights back (e.g. a tower just out of its
## unit's range, or a summoner, whose elementals attack rather than the tower).

const BOLT_SCRIPT := preload("res://scripts/units/enemies/spell_bolt.gd")

var attacker: Node = null
var target: Node = null
var _cooldown := 0.4
## Casts per target, keyed by instance id (targets may be freed meanwhile).
var _casts: Dictionary = {}


func tick(enemy: Enemy, delta: float) -> bool:
	_cooldown -= delta
	target = _choose_target(enemy)
	if target == null:
		return false
	enemy.face(_target_grid(target))
	if _cooldown <= 0.0:
		_cooldown = enemy.stat("spell_cooldown")
		var bolt: SpellBolt = BOLT_SCRIPT.new()
		enemy.game.world.effects.add_child(bolt)
		bolt.launch(enemy, target)
		var id := target.get_instance_id()
		_casts[id] = _casts.get(id, 0) + 1
		var who := enemy.game.who(target)
		enemy.game.log_for(target, EventLog.Level.DEBUG, "%s casts a spell at %s" % [enemy.label(), who])
		if _casts[id] == int(enemy.stat("spell_ignore_after")):
			enemy.game.log_for(target, EventLog.Level.DEBUG, "%s now ignores %s (%d spells without an answer)" % [enemy.label(), who, _casts[id]])
	return true


## How many spells she has cast at `n` since it last attacked her.
func casts_at(n: Node) -> int:
	return _casts.get(n.get_instance_id(), 0)


func is_ignoring(n: Node, enemy: Enemy) -> bool:
	return casts_at(n) >= int(enemy.stat("spell_ignore_after"))


func on_damaged(_enemy: Enemy, source: Node) -> void:
	if source is Tower or source.is_in_group("melee_defenders"):
		if attacker != source:
			_enemy.game.log_for(source, EventLog.Level.DEBUG, "%s turns on %s, who attacked her" % [_enemy.label(), _enemy.game.who(source)])
		attacker = source
		_casts.erase(source.get_instance_id())  # it fought back: fair game again


func _choose_target(enemy: Enemy) -> Node:
	var reach := enemy.stat("spell_range")
	if _valid(attacker) and not is_ignoring(attacker, enemy) and _target_grid(attacker).distance_to(enemy.grid_pos) <= reach:
		return attacker
	var best: Node = null
	var best_d := INF
	var candidates: Array = []
	candidates.append_array(enemy.game.world.towers())
	candidates.append_array(enemy.get_tree().get_nodes_in_group("field_units"))
	for t in candidates:
		if not _valid(t) or is_ignoring(t, enemy):
			continue
		var d := _target_grid(t).distance_to(enemy.grid_pos)
		if d <= reach and d < best_d:
			best_d = d
			best = t
	return best


## A usable target: a finished tower with a unit on duty, or a living melee
## defender (earth elemental, hero).
## Untyped on purpose: the remembered attacker may already be freed, and a freed
## object can't be passed as a typed Node argument.
static func _valid(n) -> bool:
	if not is_instance_valid(n):
		return false
	if n is Tower:
		return n.complete and n.garrison != null
	if n.is_in_group("melee_defenders"):
		return not n.dead
	return false


static func _target_grid(n: Node) -> Vector2:
	return Vector2(n.tile) if n is Tower else n.grid_pos
