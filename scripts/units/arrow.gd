class_name Arrow
extends Sprite2D
## Arrow on a shallow arc that homes in on its enemy.

var target: Enemy
var damage := 5.0
## Tower that shot this arrow (so the victim knows who attacked it).
var source: Node = null
## Co-op client: only a picture of an arrow the host shot.
var visual_only := false

var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _t := 0.0
var _duration := 0.3
var _arc := 20.0


func launch(from: Vector2, p_target: Enemy, p_damage: float, p_source: Node = null) -> void:
	source = p_source
	Art.apply(self, "arrow")
	target = p_target
	damage = p_damage
	_start = from
	_end = p_target.hit_point()
	global_position = from
	var dist := from.distance_to(_end)
	_duration = clampf(dist / 700.0, 0.12, 0.7)
	_arc = dist * 0.15


## Co-op client: an arrow from `from` to `to` (world positions), no damage.
func fly(from: Vector2, to: Vector2) -> void:
	Art.apply(self, "arrow")
	visual_only = true
	_start = from
	_end = to
	global_position = from
	var dist := from.distance_to(to)
	_duration = clampf(dist / 700.0, 0.12, 0.7)
	_arc = dist * 0.15


func _process(delta: float) -> void:
	if not visual_only and is_instance_valid(target) and not target.dead:
		_end = target.hit_point()
	_t += delta / _duration
	var k := minf(_t, 1.0)
	var p := _start.lerp(_end, k) + Vector2(0, -_arc * 4.0 * k * (1.0 - k))
	if p != global_position:
		rotation = (p - global_position).angle()
	global_position = p
	if _t >= 1.0:
		if not visual_only and is_instance_valid(target) and not target.dead:
			target.take_damage(damage, source)
			Sfx.play("hit", 0.2)
		queue_free()
