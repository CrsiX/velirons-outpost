class_name Tower
extends Building
## A tower that can hold one military unit. Used for both the four pre-built
## village wall towers ("wall_tower") and player-built watchtowers ("tower").
## The tower itself never attacks; its garrison does, using the tower's range.

const ARROW_SCRIPT := preload("res://scripts/units/arrow.gd")

var garrison: MilitaryUnit = null
## Unit currently marching here (reserves the tower).
var incoming: MilitaryUnit = null
var _cooldown := 0.0
var _unit_sprite: Sprite2D
var _front: Sprite2D
var _site_sprite: Sprite2D


func _art() -> String:
	return "wall_tower" if kind == "wall_tower" else "watchtower"


func display_name() -> String:
	return "Wall Tower" if kind == "wall_tower" else "Watchtower"


func range_tiles() -> float:
	return Config.TOWER_RANGE[kind]


func _build_visuals() -> void:
	sprite = Art.sprite(_art())
	sprite.show_behind_parent = true
	add_child(sprite)
	_unit_sprite = Sprite2D.new()
	_unit_sprite.show_behind_parent = true
	add_child(_unit_sprite)
	_front = Art.sprite(_art() + "_front")
	_front.show_behind_parent = true
	add_child(_front)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	add_child(_site_sprite)


func refresh() -> void:
	sprite.visible = complete
	_front.visible = complete
	_site_sprite.visible = not complete
	_unit_sprite.visible = complete and garrison != null
	if garrison:
		Art.apply(_unit_sprite, "unit_" + garrison.kind)
		_unit_sprite.position = Vector2(0, -Art.info(_art())["platform"] + 2.0)
	queue_redraw()


func is_solid() -> bool:
	return complete


func is_solid_when_complete() -> bool:
	return true


func can_garrison() -> bool:
	return complete


## Every finished tower watches like a building; manned ones watch their range.
func sight_radius() -> float:
	var r := super.sight_radius()
	if complete and garrison != null:
		r = maxf(r, range_tiles() + Config.TOWER_SIGHT_BONUS)
	return r


func set_garrison(unit: MilitaryUnit) -> void:
	garrison = unit
	_cooldown = 0.3
	refresh()


func _process(delta: float) -> void:
	if not complete or garrison == null:
		return
	_cooldown -= delta
	var target := _find_target()
	if target == null:
		return
	_unit_sprite.flip_h = Iso.to_world(target.grid_pos).x < position.x
	if _cooldown <= 0.0:
		_cooldown = garrison.cooldown()
		_shoot(target)


func _find_target() -> Goblin:
	var best: Goblin = null
	var r := range_tiles()
	for node in get_tree().get_nodes_in_group("enemies"):
		var g := node as Goblin
		if g.dead or g.grid_pos.distance_to(Vector2(tile)) > r:
			continue
		# Most dangerous = closest to reaching its gate.
		if best == null or g.remaining() < best.remaining():
			best = g
	return best


func _shoot(target: Goblin) -> void:
	var arrow: Arrow = ARROW_SCRIPT.new()
	game.world.effects.add_child(arrow)
	arrow.launch(to_global(_unit_sprite.position + Vector2(0, -24)), target, garrison.damage())
	Sfx.play("shoot", 0.15)
	var tw := create_tween()
	var base := _unit_sprite.position
	tw.tween_property(_unit_sprite, "position", base + Vector2(3.0 if _unit_sprite.flip_h else -3.0, 0), 0.05)
	tw.tween_property(_unit_sprite, "position", base, 0.12)


func info() -> Dictionary:
	var d := super.info()
	if not complete:
		return d
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	lines.append("Range: %.1f tiles" % range_tiles())
	if garrison:
		lines.append("Garrison: %s (level %d)" % [garrison.display_name(), garrison.level + 1])
		lines.append("Damage %.0f, %.2f s per shot" % [garrison.damage(), garrison.cooldown()])
		if garrison.can_upgrade():
			actions.append({
				"label": "Upgrade (%s)" % Config.cost_text(garrison.upgrade_cost()),
				"disabled": not game.economy.can_afford(garrison.upgrade_cost()),
				"action": func() -> void: game.army.upgrade(garrison),
			})
		actions.append({"label": "Withdraw (walks home)", "action": func() -> void: game.army.unstation(garrison)})
	elif incoming:
		lines.append("An %s is marching here." % incoming.display_name().to_lower())
		actions.append({"label": "Call back", "action": func() -> void: game.army.unstation(incoming)})
	else:
		lines.append("Unmanned: towers only fight with a unit on them.")
		var reserve := game.army.reserve()
		var err := "No archers in reserve" if reserve.is_empty() else game.army.station_error(reserve[0], self)
		actions.append({
			"label": "Send archer" if err == "" else err,
			"disabled": err != "",
			"action": func() -> void: game.army.station(game.army.reserve()[0], self),
		})
	return d


func pick_rect() -> Rect2:
	return Rect2(-40, -Art.info(_art())["platform"] - 40, 80, Art.info(_art())["platform"] + 60)
