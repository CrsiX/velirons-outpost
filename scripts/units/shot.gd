class_name Shot
extends Sprite2D
## A unit's missile (Config.ATTACKS): arrows and bolts on an arc or straight,
## whirling orbs and fireballs. Homes in on its target; on arrival calls
## `on_hit(target, world_position)`. Co-op clients get visual-only shots.

var target: Enemy
var on_hit: Callable
var visual_only := false
## Who fired it (a tower, or a unit's body outside).
var source: Node
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _t := 0.0
var _duration := 0.3
var _arc := 0.0
var _whirl := false


func launch(attack: Dictionary, from: Vector2, p_target: Enemy, p_on_hit: Callable) -> void:
	target = p_target
	on_hit = p_on_hit
	_setup(attack, from, p_target.hit_point())


## Co-op client: a picture of a shot from `from` to `to`, no effect.
func fly(attack: Dictionary, from: Vector2, to: Vector2) -> void:
	visual_only = true
	_setup(attack, from, to)


func _setup(attack: Dictionary, from: Vector2, to: Vector2) -> void:
	Art.apply(self, attack["projectile"])
	_start = from
	_end = to
	global_position = from
	var dist := from.distance_to(to)
	_duration = clampf(dist / float(attack.get("speed", 700.0)), 0.1, 1.2)
	_arc = dist * 0.15 if attack.get("arc", false) else 0.0
	_whirl = attack.get("whirl", false)
	z_index = 5


func _process(delta: float) -> void:
	if not visual_only and is_instance_valid(target) and not target.dead:
		_end = target.hit_point()
	_t += delta / _duration
	var k := minf(_t, 1.0)
	var p := _start.lerp(_end, k) + Vector2(0, -_arc * 4.0 * k * (1.0 - k))
	if _whirl:
		rotation += delta * 12.0
		scale = Vector2.ONE * 0.5 * (1.0 + 0.15 * sin(_t * 30.0))
	elif p != global_position:
		rotation = (p - global_position).angle()
	global_position = p
	if _t >= 1.0:
		if not visual_only and on_hit.is_valid():
			on_hit.call(target, _end)
		queue_free()
