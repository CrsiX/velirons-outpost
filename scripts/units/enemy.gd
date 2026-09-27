class_name Enemy
extends Unit
## Any attacker (goblin, skeleton, ...). Walks the road flow field from the map
## edge to the nearest village gate. Stats come from Config.ENEMIES[kind].

signal killed(enemy: Enemy)
signal reached_gate(enemy: Enemy)

var kind := "goblin"
var max_hp := 10.0
var hp := 10.0
var demolition := 1
var wave := 0
var dead := false
## Close combat against summons (earth elementals) that block the way.
var damage := 4.0
var attack_cooldown := 1.0
var _attack_timer := 0.0
var _foe: Node = null
var _scan_timer := 0.0


func setup(p_game: Game, route: Array[Vector2i], hp_scale: float, p_kind: String = "goblin") -> void:
	game = p_game
	kind = p_kind
	max_hp = Config.enemy_stat(kind, "hp") * hp_scale
	hp = max_hp
	speed = Config.enemy_stat(kind, "speed") * randf_range(0.92, 1.08)
	demolition = Config.enemy_stat_int(kind, "demolition")
	damage = Config.enemy_stat(kind, "damage")
	attack_cooldown = Config.enemy_stat(kind, "attack_cooldown")
	_init_sprite("unit_" + kind)
	var pts := PackedVector2Array()
	# A small sideways offset per enemy so groups don't walk in single file.
	var jitter := Vector2(randf_range(-0.18, 0.18), randf_range(-0.18, 0.18))
	for t in route:
		pts.append(Vector2(t) + jitter)
	set_grid_pos(pts[0])
	follow(pts)
	add_to_group("enemies")
	_update_visibility()


## Tiles left until the gate (lower = more dangerous).
func remaining() -> int:
	return path.size() - path_index


func hit_point() -> Vector2:
	return global_position + Vector2(0, -18)


func _process(delta: float) -> void:
	if dead:
		return
	if _fight(delta):
		_update_visibility()
		return
	if step_path(delta):
		dead = true
		remove_from_group("enemies")
		reached_gate.emit(self)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
		return
	_update_visibility()


## Stops to fight a summon standing in the way. Returns true while fighting.
func _fight(delta: float) -> bool:
	_attack_timer -= delta
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.2
		_foe = null
		for node in get_tree().get_nodes_in_group("summons"):
			if node.grid_pos.distance_to(grid_pos) <= Config.SUMMON["attack_range"]:
				_foe = node
				break
	if not is_instance_valid(_foe) or _foe.dead:
		return false
	_set_moving(false)
	sprite.flip_h = Iso.to_world(_foe.grid_pos - grid_pos).x < 0.0
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_foe.take_damage(damage)
	return true


## Only seen while under surveillance (near villagers, soldiers or manned towers).
func _update_visibility() -> void:
	visible = game.fog.is_watched(current_tile())


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		dead = true
		remove_from_group("enemies")
		killed.emit(self)
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2(1.2, 0.3), 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	var w := 28.0
	var r := Rect2(-w / 2.0, -46.0, w, 5.0)
	draw_rect(r.grow(1.5), Color("15110d"))
	draw_rect(r, Color("4a1510"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), r.size.y)), Color("d8412f"))
