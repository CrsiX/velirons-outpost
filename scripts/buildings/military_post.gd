class_name MilitaryPost
extends Building
## A building with a slot for one military unit, which walks there from the
## village when stationed and back when withdrawn (see Army). Towers let the
## unit fight; the training grounds let the hero train it.

var garrison: MilitaryUnit = null
## Unit currently marching here (reserves the slot).
var incoming: MilitaryUnit = null
## Where the stationed unit is drawn (made by the subclass's _build_visuals).
var _unit_sprite: Sprite2D


func can_garrison() -> bool:
	return complete


func set_garrison(unit: MilitaryUnit) -> void:
	garrison = unit
	refresh()


## The stationed unit's figure, in local coordinates (empty without one).
## Tapping it selects the unit; pressing and dragging it moves the unit.
func unit_pick_rect() -> Rect2:
	if garrison == null or garrison.state != MilitaryUnit.State.STATIONED or _unit_sprite == null or not _unit_sprite.visible:
		return Rect2()
	var r := _unit_sprite.get_rect()
	var sc := _unit_sprite.scale.abs()
	return Rect2(_unit_sprite.position + r.position * sc, r.size * sc).grow(4.0)


## Dims the unit while it is being dragged away.
func set_unit_ghosted(on: bool) -> void:
	if _unit_sprite:
		_unit_sprite.modulate.a = 0.35 if on else 1.0
