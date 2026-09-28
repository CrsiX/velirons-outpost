class_name WorkerCamp
extends Workplace
## A tent in the wilderness. One forester works from here, chopping nearby
## trees and dropping building material off at the camp.

var forester: Node:
	get: return worker
	set(v): worker = v
var _site_sprite: Sprite2D


func _build_visuals() -> void:
	sprite = Art.sprite("worker_camp")
	sprite.show_behind_parent = true
	add_child(sprite)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	add_child(_site_sprite)


func refresh() -> void:
	sprite.visible = complete
	_site_sprite.visible = not complete
	queue_redraw()


func info() -> Dictionary:
	var d := super.info()
	if not complete:
		return d
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	if forester:
		lines.append("Forester: %s" % forester.status())
		lines.append("+%d building material per trip" % Config.FORESTER_MATERIAL_PER_TRIP)
		actions.append({"label": "Unassign forester", "action": func() -> void: game.population.unassign_forester(self)})
	else:
		lines.append("Idle: assign a forester to cut trees nearby.")
		var free := game.population.free_foresters()
		actions.append({
			"label": "Assign forester" if not free.is_empty() else "No free forester",
			"disabled": free.is_empty(),
			"action": func() -> void: game.population.assign_forester(self),
		})
	return d


func pick_rect() -> Rect2:
	return Rect2(-48, -56, 96, 80)
