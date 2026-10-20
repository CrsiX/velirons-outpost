class_name ScenarioCaravan
extends Node2D
## A scenario's guild caravan (docs/scenarios-design.md §7.16): a cart down a
## road from the map edge to the gate, in game time. It halts while an enemy
## (of a wave; not camp guards) is within HALT tiles of it, and at the gate
## pays its cargo to the village. Enemies don't attack it.

signal delivered

## Tiles per second, how near an enemy halts it, and how far they must be
## before it goes on again.
const SPEED := 1.2
const HALT := 3.5
const GO := 4.5

var game: Game
var road: Array[Vector2i] = []
var cargo := {}
## Where it is along the road (an index with a fraction).
var progress := 0.0
var halted := false
var arrived := false
var _sprite: Sprite2D
var _was_halted := false
var _logged_at := -INF


func setup(p_game: Game, p_road: Array[Vector2i], p_cargo: Dictionary) -> void:
	game = p_game
	road = p_road
	cargo = p_cargo
	_sprite = Art.sprite("unit_caravan")
	add_child(_sprite)
	position = Iso.to_world(Vector2(road[0]))


## Where it is on the map (grid space).
func grid_pos() -> Vector2:
	var i := mini(floori(progress), road.size() - 1)
	var j := mini(i + 1, road.size() - 1)
	return Vector2(road[i]).lerp(Vector2(road[j]), progress - float(i))


func _process(delta: float) -> void:
	if arrived or game == null or game.game_over:
		return
	var here := grid_pos()
	var reach := GO if halted else HALT
	halted = game.get_tree().get_nodes_in_group("enemies").any(func(e: Node) -> bool:
		return not (e as Enemy).dead and not (e as Enemy).wild() and (e as Enemy).grid_pos.distance_to(here) <= reach)
	if halted != _was_halted:
		_was_halted = halted
		if halted and game.clock - _logged_at > 20.0:
			_logged_at = game.clock
			game.events.info("The guild caravan halts: enemies on the road")
		_sprite.modulate = Color(0.75, 0.75, 0.8) if halted else Color.WHITE
	if halted:
		return
	var before := Iso.to_world(here)
	progress = minf(progress + SPEED * delta, float(road.size() - 1))
	position = Iso.to_world(grid_pos())
	if absf(position.x - before.x) > 0.01:
		_sprite.flip_h = position.x < before.x
	if progress >= float(road.size() - 1):
		_arrive()


func _arrive() -> void:
	arrived = true
	var v := game.player_village
	var parts: Array[String] = []
	for k in ["gold", "food", "materials"]:
		if cargo.has(k):
			v.economy.add(k, int(cargo[k]), "trade")
			parts.append("+%d {%s}" % [int(cargo[k]), k])
	game.world.float_text(" ".join(parts), position + Vector2(0, -60), UiTheme.GOLD)
	v.events.info("The guild caravan is in: %s" % Config.cost_text(cargo))
	delivered.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
