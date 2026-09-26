class_name Farm
extends Building
## 3x3 field outside the walls. Grows food while a farmer is assigned; the
## farmer carries the stored food home.

var farmer: Node = null
var stored := 0.0
var _field: Sprite2D
var _shed: Sprite2D
var _site_sprite: Sprite2D


func _build_visuals() -> void:
	# The field is flat, so it lives on the decal layer (under units);
	# the shed on the back tile is a normal y-sorted sprite.
	_field = Sprite2D.new()
	_field.position = position
	game.world.decals.add_child(_field)
	_shed = Art.sprite("farm_shed")
	_shed.show_behind_parent = true
	_shed.position = Iso.to_world(Vector2(-1, -1))
	add_child(_shed)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	add_child(_site_sprite)
	# Sort by the back tile so units on the field are drawn in front of the shed.
	position = Iso.tile_to_world(tile + Vector2i(-1, -1))
	_shed.position = Vector2.ZERO
	_site_sprite.position = Iso.to_world(Vector2(1, 1))


func refresh() -> void:
	Art.apply(_field, "farm_field" if complete else "farm_site")
	_shed.visible = complete
	_site_sprite.visible = not complete
	_field.modulate = Color.WHITE if (farmer != null or not complete) else Color(0.7, 0.7, 0.7)
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(_field):
		_field.queue_free()


func _process(delta: float) -> void:
	if complete and farmer != null:
		stored = minf(stored + Config.FARM_RATE * delta, Config.FARM_CAPACITY)


func take_food() -> int:
	var amount := int(stored)
	stored -= amount
	return amount


func info() -> Dictionary:
	var d := super.info()
	if not complete:
		return d
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	lines.append("Stored food: %d / %d" % [int(stored), int(Config.FARM_CAPACITY)])
	if farmer:
		lines.append("Worked by a farmer (+%.1f food/s)" % Config.FARM_RATE)
		actions.append({"label": "Unassign farmer", "action": func() -> void: game.population.unassign_farmer(self)})
	else:
		lines.append("Idle: assign a farmer to grow food.")
		var free := game.population.free_farmers()
		actions.append({
			"label": "Assign farmer" if not free.is_empty() else "No free farmer",
			"disabled": free.is_empty(),
			"action": func() -> void: game.population.assign_farmer(self),
		})
	return d


## Bottom progress bar sits over the field centre, not the back-tile origin.
func _draw() -> void:
	if complete:
		return
	var c := Iso.to_world(Vector2(1, 1))
	var w := 80.0
	var r := Rect2(c + Vector2(-w / 2.0, -70.0), Vector2(w, 8.0))
	draw_rect(r.grow(2.0), Color("15110d"))
	draw_rect(r, Color("3a2e22"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(progress / build_time, 0.0, 1.0), r.size.y)), Color("c9a24a"))


func pick_rect() -> Rect2:
	var c := Iso.to_world(Vector2(1, 1))
	return Rect2(c - Vector2(180, 90), Vector2(360, 180))
