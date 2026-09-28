class_name SpellBolt
extends Node2D
## A witch's whirling pink bolt. Homes in on its target: a tower's unit gets
## enchanted (no damage); a melee defender (earth elemental, hero) takes damage.

var target: Node
## The witch who cast it (may be gone by the time it hits; left untyped).
var witch = null
var damage := 0.0
var enchant := 0.0
var speed_px := 400.0
var _sprite: Sprite2D
var _t := 0.0


func launch(p_witch: Enemy, p_target: Node) -> void:
	target = p_target
	witch = p_witch
	damage = p_witch.stat("spell_damage")
	enchant = p_witch.stat("spell_cooldown") * p_witch.stat("enchant_ratio")
	speed_px = p_witch.stat("spell_speed") * Iso.HALF_W * 1.4
	global_position = p_witch.hit_point() + Vector2(8, -6)
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
	var source: Node = witch if is_instance_valid(witch) else null
	if target is Tower:
		var t := target as Tower
		if t.garrison:
			t.game.events.debug("%s bewitched by %s" % [t.game.who(t), t.game.who(source)])
		t.enchant(enchant)
	elif target.is_in_group("melee_defenders") and not target.dead:
		target.take_damage(damage, source)  # elementals, the hero
	queue_free()
