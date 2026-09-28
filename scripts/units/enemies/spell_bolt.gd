class_name SpellBolt
extends Node2D
## A witch's whirling pink bolt. Homes in on its target: a tower's unit gets
## enchanted (no damage); a melee defender (earth elemental, hero) takes damage.

var target: Node
var damage := 0.0
var enchant := 0.0
var speed_px := 400.0
var _sprite: Sprite2D
var _t := 0.0


func launch(witch: Enemy, p_target: Node) -> void:
	target = p_target
	damage = witch.stat("spell_damage")
	enchant = witch.stat("spell_cooldown") * witch.stat("enchant_ratio")
	speed_px = witch.stat("spell_speed") * Iso.HALF_W * 1.4
	global_position = witch.hit_point() + Vector2(8, -6)
	_sprite = Art.sprite("spell_bolt")
	add_child(_sprite)
	Sfx.play("hit", 0.4)


func _aim() -> Vector2:
	if target is Tower:
		return (target as Tower).muzzle_position()
	return target.global_position + Vector2(0, -18)


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	_t += delta
	_sprite.rotation += delta * 9.0  # whirl
	_sprite.scale = Vector2.ONE * 0.5 * (1.0 + 0.15 * sin(_t * 18.0))
	var to := _aim() - global_position
	var step := speed_px * delta
	if to.length() <= step:
		_hit()
		return
	global_position += to.normalized() * step


func _hit() -> void:
	if target is Tower:
		(target as Tower).enchant(enchant)
	elif target.is_in_group("melee_defenders") and not target.dead:
		target.take_damage(damage)  # elementals, the hero
	queue_free()
