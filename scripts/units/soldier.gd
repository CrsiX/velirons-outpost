class_name Soldier
extends Unit
## The walking body of a MilitaryUnit on its way to a tower or back home.
## Soldiers watch their surroundings (surveillance) but don't fight while walking.

signal arrived(soldier: Soldier)

var unit: MilitaryUnit


func setup(p_game: Game, p_unit: MilitaryUnit, from: Vector2i) -> void:
	game = p_game
	unit = p_unit
	speed = unit.spec()["speed"]
	_init_sprite("unit_" + unit.kind)
	set_grid_pos(Vector2(from))
	add_to_group("observers")


## Starts walking to `tile`. Returns false when there is no way there.
func walk_to(tile: Vector2i) -> bool:
	var p := game.world.pathing.find_path(current_tile(), tile)
	if p.is_empty():
		return false
	follow(p)
	return true


func _process(delta: float) -> void:
	if game.is_client:
		net_follow(delta)  # the host simulates; we just follow
		return
	# A unit sent to another village is theirs as soon as it's inside their walls.
	var entered := unit.state == MilitaryUnit.State.TRAVELLING and unit.travel_to.rect.has_point(current_tile())
	if step_path(delta) or entered:
		arrived.emit(self)


func sight_radius() -> float:
	return Config.UNIT_SIGHT


func sight_center() -> Vector2:
	return grid_pos
