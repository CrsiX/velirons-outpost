class_name EnemyArrow
extends Sprite2D
## A Legion archer's arrow (LegionArcherBehavior): flies on a low arc at one
## of ours (the hero, a soldier, a summon, a villager) or at a barrier in the
## archer's way, following it, and deals its damage on arrival (projectile).

var target: Node
var damage := 0.0
## The archer who shot it (may be gone by the time it lands; left untyped).
var archer = null
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _t := 0.0
var _duration := 0.3


func launch(p_archer: Enemy, p_target: Node, p_damage: float) -> void:
	archer = p_archer
	target = p_target
	damage = p_damage
	Art.apply(self, "arrow")
	_start = p_archer.hit_point()
	_end = _aim()
	global_position = _start
	var px := p_archer.stat("arrow_speed") * Iso.HALF_W * 1.4
	_duration = clampf(_start.distance_to(_end) / maxf(px, 1.0), 0.1, 1.2)
	z_index = 5


func _aim() -> Vector2:
	if target is Building:
		return (target as Building).global_position + Vector2(0, -24)
	return (target as Node2D).global_position + Vector2(0, -18)


func _process(delta: float) -> void:
	if is_instance_valid(target):
		_end = _aim()
	_t += delta / _duration
	var k := minf(_t, 1.0)
	var arc := _start.distance_to(_end) * 0.15
	var p := _start.lerp(_end, k) + Vector2(0, -arc * 4.0 * k * (1.0 - k))
	if p != global_position:
		rotation = (p - global_position).angle()
	global_position = p
	if _t < 1.0:
		return
	var source: Node = archer if is_instance_valid(archer) else null
	if is_instance_valid(target):
		if target is Building:
			(target as Building).take_damage(damage, source, "projectile")
		elif not target.dead:
			target.take_damage(damage, source, "projectile")
	queue_free()
