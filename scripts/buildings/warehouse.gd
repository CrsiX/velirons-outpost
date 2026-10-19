class_name Warehouse
extends Building
## The guild's warehouse (2x2; docs/scenarios-design.md §7.7), only in the
## campaign's scenarios (scenario 4: it must not fall). Enemies breaking into
## the village go for it as for a hut (Siege: its tiles are targets of the
## siege field); each one that gets to it plunders it, takes
## Config.WAREHOUSE["raid_damage"] of its HP and is gone. At 0 HP it is
## devastated; a builder repairs it like any building. It can't be torn down.

var _site_spr: Sprite2D


func _build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.show_behind_parent = true
	add_child(sprite)
	_site_spr = Art.sprite("site")
	_site_spr.show_behind_parent = true
	_site_spr.scale *= 1.4
	add_child(_site_spr)


func refresh() -> void:
	Art.apply(sprite, "warehouse")
	sprite.visible = complete
	_site_spr.visible = not complete
	queue_redraw()


## A raid target now: standing (enemies don't plunder rubble).
func raidable() -> bool:
	return working() and village != null


## Enemy `g` got to it: it loses its raid damage, and `g` is gone.
func plunder(g: Enemy) -> void:
	if not raidable():
		return
	village.events.important("%s plundered %s" % [g.label().capitalize(), label()])
	village.toast("The %s is being plundered!" % display_name().to_lower(), Color("ff7a6a"))
	take_damage(float(Config.WAREHOUSE["raid_damage"]), g)


func can_tear_down() -> bool:
	return false


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if complete:
		lines.append("Enemies that get to it plunder it: %d HP each." % int(Config.WAREHOUSE["raid_damage"]))
	return d


func pick_rect() -> Rect2:
	return Rect2(-100, -110, 200, 150)


func _bar_y() -> float:
	return -104.0
