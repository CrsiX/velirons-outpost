class_name WitchBehavior
extends EnemyBehavior
## Walks to the village until something worth enchanting is within spell range:
##   1. whoever last attacked her (a tower's unit, or an earth elemental),
##   2. otherwise the nearest manned tower.
## She then stands and casts a pink bolt every `spell_cooldown` seconds. A bolt
## enchants a tower's unit for `spell_cooldown * enchant_ratio` seconds (it stops
## shooting/summoning; no damage), or deals `spell_damage` to an elemental.
## Witches never fight in melee.

const BOLT_SCRIPT := preload("res://scripts/units/enemies/spell_bolt.gd")

var attacker: Node = null
var target: Node = null
var _cooldown := 0.4


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
	return true


func on_damaged(_enemy: Enemy, source: Node) -> void:
	if source is Tower or source is EarthElemental:
		attacker = source


func _choose_target(enemy: Enemy) -> Node:
	var reach := enemy.stat("spell_range")
	if _valid(attacker) and _target_grid(attacker).distance_to(enemy.grid_pos) <= reach:
		return attacker
	var best: Tower = null
	var best_d := INF
	for t in enemy.game.world.towers():
		if not _valid(t):
			continue
		var d := Vector2(t.tile).distance_to(enemy.grid_pos)
		if d <= reach and d < best_d:
			best_d = d
			best = t
	return best


## A usable target: a finished tower with a unit on duty, or a living elemental.
static func _valid(n: Node) -> bool:
	if not is_instance_valid(n):
		return false
	if n is Tower:
		return n.complete and n.garrison != null
	if n is EarthElemental:
		return not n.dead
	return false


static func _target_grid(n: Node) -> Vector2:
	return Vector2(n.tile) if n is Tower else n.grid_pos
