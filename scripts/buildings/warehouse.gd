class_name Warehouse
extends Building
## The guild's warehouse (2x2; docs/scenarios-design.md §7.7), only in the
## campaign's scenarios (scenario 4: it must not fall). Only thieves go for
## it (ThiefBehavior; enemies breaking into the village go for the huts):
## each one that gets to it plunders it, takes Config.WAREHOUSE["raid_damage"]
## of its HP, and runs off with gold. At 0 HP it is devastated. It can't be
## repaired (what is plundered is gone) or torn down.

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


## Thief `g` got to it (ThiefBehavior): it loses its raid damage.
func plunder(g: Enemy) -> void:
	if not raidable():
		return
	village.events.important("%s plundered %s" % [g.label().capitalize(), label()])
	village.toast("The %s is being plundered!" % display_name().to_lower(), Color("ff7a6a"))
	take_damage(float(Config.WAREHOUSE["raid_damage"]), g)  # (a raid, not a blow: pure)


func can_tear_down() -> bool:
	return false


## Plundered goods are gone: no repairs.
func can_repair() -> bool:
	return false


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if complete:
		lines.append("Thieves that get to it plunder it: %d HP each. What is plundered is gone: it can't be repaired." % int(Config.WAREHOUSE["raid_damage"]))
	return d


func _bar_y() -> float:
	return -104.0
