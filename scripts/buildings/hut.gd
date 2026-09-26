class_name Hut
extends Building
## A village hut: houses one civilian. Goblins can burn it down to a ruin,
## and the player can order it rebuilt on the same lot.

var ruined := false
var _site_overlay: Sprite2D


func _build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	add_child(sprite)
	_site_overlay = Art.sprite("site")
	_site_overlay.show_behind_parent = true
	add_child(_site_overlay)


func is_intact() -> bool:
	return complete and not ruined


func refresh() -> void:
	Art.apply(sprite, "hut" if is_intact() else "hut_ruin")
	_site_overlay.visible = not complete
	queue_redraw()


func destroy() -> void:
	ruined = true
	complete = true
	progress = 0.0
	refresh()
	var tw := create_tween()
	modulate = Color(1.0, 0.4, 0.3)
	tw.tween_property(self, "modulate", Color.WHITE, 0.8)


## Called by Construction when a rebuild is ordered.
func start_rebuild() -> void:
	complete = false
	progress = 0.0
	refresh()


func cancel_rebuild() -> void:
	complete = true
	ruined = true
	progress = 0.0
	refresh()


func finish() -> void:
	ruined = false
	super.finish()


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if not complete:
		d["title"] = "Hut (rebuilding)"
	elif ruined:
		d["title"] = "Ruined Hut"
		lines.append("Destroyed by goblins.")
		lines.append("Rebuild for %s." % Config.cost_text(Config.BUILDINGS["hut"]["cost"]))
		var actions: Array[Dictionary] = d["actions"]
		actions.append({
			"label": "Rebuild",
			"disabled": not game.economy.can_afford(Config.BUILDINGS["hut"]["cost"]),
			"action": func() -> void: game.construction.order_rebuild(self),
		})
	else:
		lines.append("Houses one villager.")
		lines.append("Village population: %d / %d" % [game.population.count(), game.population.cap()])
	return d


func pick_rect() -> Rect2:
	return Rect2(-46, -62, 92, 90)
