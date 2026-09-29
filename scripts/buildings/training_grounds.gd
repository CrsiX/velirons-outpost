class_name TrainingGrounds
extends MilitaryPost
## 2x2 yard with a small hut, weapon racks and archery targets. It has two
## slots: one military unit (stationed like on a tower; it doesn't fight here)
## and the hero, who in Train mode passes his XP on to that unit until it has
## enough for its next level, which it then gets for free.

## The hero currently training here (null if none).
var trainee_hero: Node = null
var _site_sprite: Sprite2D


func _build_visuals() -> void:
	sprite = Art.sprite("training_grounds")
	sprite.show_behind_parent = true
	add_child(sprite)
	_unit_sprite = Sprite2D.new()
	_unit_sprite.show_behind_parent = true
	_unit_sprite.position = Iso.to_world(Vector2(0.35, -0.1))
	add_child(_unit_sprite)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	_site_sprite.scale *= 1.4
	add_child(_site_sprite)


func refresh() -> void:
	sprite.visible = complete
	_site_sprite.visible = not complete
	_unit_sprite.visible = complete and garrison != null
	if garrison:
		Art.apply(_unit_sprite, "unit_" + garrison.kind)
	queue_redraw()


## The stationed unit, if it is here and can still level up by training.
func post_kind() -> String:
	return "training"


func trainable_unit() -> MilitaryUnit:
	if working() and garrison != null and garrison.state == MilitaryUnit.State.STATIONED and garrison.can_train():
		return garrison
	return null


func is_ready_for_training() -> bool:
	return trainable_unit() != null


func _process(_delta: float) -> void:
	if trainee_hero != null and not is_instance_valid(trainee_hero):
		trainee_hero = null
	queue_redraw()


func info() -> Dictionary:
	var d := super.info()
	if not working():
		return d
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	var hero: Hero = village.hero
	if garrison:
		lines.append("%s, level %d" % [garrison.display_name(), garrison.level + 1])
		if garrison.can_train():
			lines.append("Training to level %d: %d / %d XP" % [garrison.level + 2, int(garrison.train_xp), int(garrison.train_xp_needed())])
		else:
			lines.append("Fully trained (max level).")
		actions.append({"label": "Withdraw", "action": func() -> void: game.command("withdraw_unit", {"unit": garrison.nid})})
	elif incoming:
		lines.append("%s marching here." % incoming.display_name())
		actions.append({"label": "Withdraw", "action": func() -> void: game.command("withdraw_unit", {"unit": incoming.nid})})
	else:
		lines.append("No unit. Drag a unit from the Army tab here to train it.")
	if trainee_hero != null:
		lines.append("Hero training here: %d XP left to pass on" % hero.xp)
	else:
		lines.append("Hero XP: %d (set the hero to Train mode to pass it on)" % hero.xp)
	return d


func pick_rect() -> Rect2:
	return Rect2(-110, -80, 220, 130)


func _bar_y() -> float:
	return -86.0


func _draw() -> void:
	super._draw()
	var u := trainable_unit()
	if u == null:
		return
	# Purple bar: the unit's progress towards its next level through training.
	var w := 90.0
	var r := Rect2(-w / 2.0, -74.0, w, 7.0)
	draw_rect(r.grow(2.0), Color("15110d"))
	draw_rect(r, Color("2a1e3a"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(u.train_xp / maxf(u.train_xp_needed(), 1.0), 0.0, 1.0), r.size.y)), Color("b07cff"))
