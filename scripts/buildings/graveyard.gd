class_name Graveyard
extends Building
## The graveyard by the battlefield's chapel (3x3; scenario 6,
## docs/scenarios-design.md §7.10), only in the campaign: a scenario prebuilds
## it. Gatherers (and the hero gathering) carry the battlefield's fallen
## (Corpse.fallen) here instead of home, and each one is buried: a mound for
## every grave, and no necromancer can raise it again. It can't be torn down.

## Mounds in rows over the plot, in the order they are dug.
const GRAVES_PER_ROW := 6
const ROWS := 5

## How many of the fallen lie buried here.
var buried := 0
var _ground: Sprite2D
var _site_spr: Sprite2D
var _mounds: Array[Sprite2D] = []


func _build_visuals() -> void:
	# The plot is flat: the decal layer (under walking units), mounds with it.
	_ground = Sprite2D.new()
	_ground.position = position
	game.world.decals.add_child(_ground)
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	add_child(sprite)
	_site_spr = Art.sprite("site")
	_site_spr.show_behind_parent = true
	add_child(_site_spr)


func _exit_tree() -> void:
	if is_instance_valid(_ground):
		_ground.queue_free()
	for m in _mounds:
		if is_instance_valid(m):
			m.queue_free()


func refresh() -> void:
	Art.apply(_ground, "graveyard")
	_ground.visible = complete
	_ground.modulate = Color(0.7, 0.68, 0.66) if devastated else Color.WHITE
	sprite.visible = false
	_site_spr.visible = not complete
	while _mounds.size() < mini(buried, GRAVES_PER_ROW * ROWS):
		var i := _mounds.size()
		var m := Art.sprite("grave_mound")
		var spot := Vector2(-1.05 + 2.1 * float(i % GRAVES_PER_ROW) / float(GRAVES_PER_ROW - 1), -0.9 + 1.8 * float(i / GRAVES_PER_ROW) / float(ROWS - 1))
		m.position = position + Iso.to_world(spot)
		m.flip_h = i % 2 == 1
		game.world.decals.add_child(m)
		_mounds.append(m)
	queue_redraw()


## Where those who bring the dead walk to (the plot's middle).
func visit_tile() -> Vector2i:
	return tile


## `n` of the fallen brought by `by` are laid in their graves.
func bury(n: int, by: Node) -> void:
	if n <= 0:
		return
	buried += n
	village.events.info("%s buried %d of the fallen (%d in the graveyard)" % [game.who(by).capitalize(), n, buried])
	refresh()


## Takes the dead in: standing, not a ruin or a site.
func open() -> bool:
	return working() and village != null


func can_tear_down() -> bool:
	return false


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if complete:
		lines.append("%d of the fallen buried here. Gatherers bring them from the field; buried, they can't be raised." % buried)
	return d


func pick_rect() -> Rect2:
	return Rect2(-150, -80, 300, 160)


func _bar_y() -> float:
	return -60.0
