class_name EarthElemental
extends Unit
## A small elemental summoned next to its summoner (on a tower, or outside its
## barracks). It wanders around there until it spots an enemy, then walks up
## to it and fights in close combat. Enemies fight back; at 0 hp it crumbles
## (no corpse). Kinds (Config.SUMMONS): earth, and fire, which hovers and
## flickers, is quick and hits hard, but burns itself with every hit.

signal died(elemental: EarthElemental)

var max_hp := 20.0
var hp := 20.0
var damage := 4.0
var dead := false
var target: Enemy = null
## The summoner's post (its tower's tile, or where it stood); the elemental
## stays within its leash of this tile.
var home := Vector2i.ZERO
## Numbered across all summoners: "elemental 3".
var uid := 0
## Its summoner's village.
var village: Village
## "earth" / "fire" (Config.SUMMONS).
var summon := "earth"
var _flicker := 0.0


func label() -> String:
	return "%s %d" % ["fire elemental" if summon == "fire" else "elemental", uid]

var _attack_timer := 0.0
var _think_timer := 0.0
var _idle_timer := 0.0
var _chase_tile := Vector2i(-9999, -9999)


func setup(p_game: Game, p_home: Vector2i, spawn_tile: Vector2i, p_hp: float, p_damage: float, p_summon: String = "earth") -> void:
	game = p_game
	home = p_home
	max_hp = p_hp
	hp = p_hp
	damage = p_damage
	summon = p_summon
	var sm: Dictionary = Config.SUMMONS[summon]
	speed = sm["speed"]
	_init_sprite(sm["art"])
	set_grid_pos(Vector2(spawn_tile))
	add_to_group("summons")
	add_to_group("melee_defenders")
	add_to_group("observers")
	# Rise out of the ground.
	sprite.scale = Vector2(0.5, 0.1)
	create_tween().tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if flies():  # a flame: bobs above the ground and flickers
		_flicker += delta
		sprite.offset.y = -6.0 - 3.0 * sin(_flicker * 5.0)
		sprite.self_modulate = Color(1.0, 0.85 + 0.15 * sin(_flicker * 23.0), 0.8 + 0.2 * sin(_flicker * 17.0))
	if game.is_client:
		net_follow(delta)
		return
	if dead:
		return
	_think_timer -= delta
	_attack_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.3
		_pick_target()
	if is_instance_valid(target) and not target.dead:
		var dist := target.grid_pos.distance_to(grid_pos)
		if dist <= Config.SUMMON["attack_range"]:
			_set_moving(false)
			face(target.grid_pos)
			if _attack_timer <= 0.0:
				_attack_timer = Config.SUMMON["attack_cooldown"]
				_strike(target)
		else:
			if path_index >= path.size() or target.current_tile() != _chase_tile:
				_chase()
			step_path(delta)
	else:
		_wander(delta)


func _pick_target() -> void:
	var best: Enemy = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or (e.flies() and not flies()):
			continue  # (an earth elemental can't reach a flyer; a fire elemental flies too)
		var d := e.grid_pos.distance_to(grid_pos)
		# Only enemies it can see, and not too far from its post.
		if d <= Config.SUMMON["sight"] and e.grid_pos.distance_to(Vector2(home)) <= Config.SUMMON["leash"] + Config.SUMMON["sight"] and d < best_d:
			best_d = d
			best = e
	if best != null and best != target:
		village.events.debug("%s attacks %s" % [label(), best.label()])
	target = best


func _chase() -> void:
	_chase_tile = target.current_tile()
	var p := game.world.pathing.find_path(current_tile(), _chase_tile)
	if p.is_empty():
		target = null
		return
	# Start from where we actually stand (no stepping back to the tile centre)
	# and walk the last stretch straight at the enemy.
	p[0] = grid_pos
	p[p.size() - 1] = target.grid_pos
	follow(p)


func _wander(delta: float) -> void:
	if path_index < path.size():
		step_path(delta)
		return
	_idle_timer -= delta
	if _idle_timer > 0.0:
		return
	_idle_timer = randf_range(1.0, 3.0)
	var leash: float = Config.SUMMON["leash"]
	for _i in 8:
		var t := home + Vector2i(randi_range(-int(leash), int(leash)), randi_range(-int(leash), int(leash)))
		if Vector2(t).distance_to(Vector2(home)) <= leash and game.world.pathing.is_walkable(t):
			var p := game.world.pathing.find_path(current_tile(), t)
			if not p.is_empty():
				follow(p)
				return


## Fire elementals fly (they hover): they fight flyers like anyone.
func flies() -> bool:
	return Config.SUMMONS[summon]["hover"]


## A flyer hit it: if its blow is ready it strikes back at once.
func counter_strike(e: Enemy) -> void:
	if dead or _attack_timer > 0.0 or e.dead:
		return
	_attack_timer = Config.SUMMON["attack_cooldown"]
	_strike(e)


func _strike(foe: Enemy) -> void:
	foe.take_damage(damage, self)
	var burn: float = Config.SUMMONS[summon]["self_damage"]
	if burn > 0.0:
		take_damage(damage * burn, self)  # fire burns itself up
		if dead:
			return
	var tw := create_tween()
	var lunge := (Iso.to_world(foe.grid_pos) - position).normalized() * 5.0
	tw.tween_property(sprite, "position", lunge, 0.08)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.12)
	Sfx.play("hit", 0.25)


func take_damage(amount: float, source = null) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.55, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		village.events.debug("%s destroyed by %s" % [label(), game.who(source)])
		crumble()


## Dies and falls apart into the earth; leaves no corpse.
func crumble() -> void:
	if dead:
		return
	dead = true
	remove_from_group("summons")
	remove_from_group("melee_defenders")
	remove_from_group("observers")
	died.emit(self)
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "scale", Vector2(0.65, 0.05), 0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)


func sight_radius() -> float:
	return 0.0 if dead else Config.SUMMON["sight"]


func sight_center() -> Vector2:
	return grid_pos


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	_draw_hp_bar(26.0, -48.0, 4.0, hp / max_hp, Color("2a3a20"), Color("8fd05a"))
