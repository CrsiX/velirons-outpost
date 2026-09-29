class_name MilitaryPost
extends Building
## A building with slots for military units, which walk there from the
## village when stationed and back when withdrawn (see Army). Towers (1 slot)
## let the unit fight from the tower; the training grounds (1 slot) let the
## hero train it; barracks (1-3 benches) send their units out to fight.
## `garrison` / `incoming` are slot 0, for the one-slot posts.

## Stationed unit per slot (null = free), and the unit marching to each slot.
var slots: Array = [null]
var incoming_slots: Array = [null]
var garrison: MilitaryUnit:
	get: return slots[0]
	set(v): slots[0] = v
var incoming: MilitaryUnit:
	get: return incoming_slots[0]
	set(v): incoming_slots[0] = v
## Where the stationed unit is drawn (made by the subclass's _build_visuals).
var _unit_sprite: Sprite2D


func can_garrison() -> bool:
	return complete


## "tower", "barracks" or "training" (which units fit: MilitaryUnit.fits).
func post_kind() -> String:
	return "tower"


func capacity() -> int:
	return 1


## Grows / shrinks the slot lists to capacity() (barracks upgrades).
func fit_slots() -> void:
	while slots.size() < capacity():
		slots.append(null)
		incoming_slots.append(null)


## A slot nobody holds or is marching to, or -1.
func free_slot() -> int:
	for i in capacity():
		if slots[i] == null and incoming_slots[i] == null:
			return i
	return -1


## Stationed units (not the ones on their way).
func units() -> Array[MilitaryUnit]:
	var out: Array[MilitaryUnit] = []
	for u in slots:
		if u != null:
			out.append(u)
	return out


func set_slot(i: int, unit: MilitaryUnit) -> void:
	slots[i] = unit
	refresh()


func set_garrison(unit: MilitaryUnit) -> void:
	set_slot(0, unit)


## The stationed unit whose figure is at `local` (post coordinates), or null.
## Tapping it selects the unit; pressing and dragging it moves the unit.
func unit_at(local: Vector2) -> MilitaryUnit:
	return garrison if unit_pick_rect().has_point(local) else null


## The stationed unit's figure, in local coordinates (empty without one).
func unit_pick_rect() -> Rect2:
	if garrison == null or garrison.state != MilitaryUnit.State.STATIONED or _unit_sprite == null or not _unit_sprite.visible:
		return Rect2()
	return sprite_rect(_unit_sprite)


static func sprite_rect(s: Sprite2D) -> Rect2:
	var r := s.get_rect()
	var sc := s.scale.abs()
	return Rect2(s.position + r.position * sc, r.size * sc).grow(4.0)


## Dims the unit while it is being dragged away.
func set_unit_ghosted(on: bool, unit: MilitaryUnit = null) -> void:
	if _unit_sprite:
		_unit_sprite.modulate.a = 0.35 if on else 1.0
