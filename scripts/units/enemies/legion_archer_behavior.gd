class_name LegionArcherBehavior
extends EnemyBehavior
## A Legion archer (Config.ENEMIES["legion_archer"]): walks its road until one
## of ours is out in the open within `shoot_range` (the hero outside the
## walls, soldiers out, summons, villagers outside: AquaBehavior.people; never
## a tower's unit), then stands and shoots the nearest, an arrow every
## attack_cooldown (faster near a Legion banner, Enemy.haste). Breaking in, it
## shoots the barrier in its way (damage x siege).

const ARROW_SCRIPT := preload("res://scripts/units/enemies/enemy_arrow.gd")

var _cooldown := 0.3
var _scan := 0.0
var _target: Node = null


func tick(enemy: Enemy, delta: float) -> bool:
	_cooldown -= delta
	_scan -= delta
	var reach := enemy.stat("shoot_range")
	if _scan <= 0.0:
		_scan = 0.25
		_target = AquaBehavior.nearest_within(enemy, AquaBehavior.people(enemy.game), reach)
	if not AquaBehavior.reachable(_target) or (_target.grid_pos as Vector2).distance_to(enemy.grid_pos) > reach + 0.3:
		_target = null
		return false
	enemy.face(_target.grid_pos)
	if _cooldown <= 0.0:
		_cooldown = enemy.stat("attack_cooldown") / enemy.haste()
		_shoot(enemy, _target, enemy.stat("damage"))
		enemy.game.log_for(_target, EventLog.Level.DEBUG, "%s shoots at %s" % [enemy.label(), enemy.game.who(_target)])
	return true


func siege_attack(enemy: Enemy, b: Building) -> float:
	var dmg := enemy.stat("damage") * float(enemy.spec().get("siege", 0.0))
	if dmg <= 0.0:
		return 0.0
	enemy.face(Vector2(b.tile))
	_shoot(enemy, b, dmg)
	return enemy.stat("attack_cooldown") / enemy.haste()


func _shoot(enemy: Enemy, at: Node, dmg: float) -> void:
	var a: EnemyArrow = ARROW_SCRIPT.new()
	enemy.game.world.effects.add_child(a)
	a.launch(enemy, at, dmg)
