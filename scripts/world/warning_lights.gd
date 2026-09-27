class_name WarningLights
extends Node2D
## Beginner help: during the first WARNING_LIGHT_WAVES waves on easy and normal,
## a soft red light marks where each hidden enemy will come out of the dark,
## i.e. where its road first enters land under surveillance. Drawn above the fog.

const UPDATE_INTERVAL := 0.3
const MERGE_DISTANCE := 2.5  # lights closer than this (tiles) are merged

var game: Game
var _pool: Array[Sprite2D] = []
var _active := 0
var _timer := 0.0
var _t := 0.0
## Current light positions in grid space (for tests and debugging).
var spots: Array[Vector2] = []


func setup(p_game: Game) -> void:
	game = p_game


func enabled() -> bool:
	var w := game.waves
	return Settings.difficulty != Settings.Difficulty.HARD and w.wave >= 1 and w.wave <= Config.WARNING_LIGHT_WAVES and w.in_progress()


func _process(delta: float) -> void:
	if game == null:
		return
	_t += delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		spots.clear()
		if enabled():
			spots = compute_spots()
		_show(spots)
	var pulse := 0.55 + 0.25 * sin(_t * 4.0)
	for i in _active:
		_pool[i].modulate.a = pulse


## For every enemy hidden from view, the point where its route crosses from
## unwatched into watched land (the edge of the fog).
func compute_spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or e.visible:
			continue
		var prev := e.grid_pos
		for i in range(e.path_index, e.path.size()):
			var p := e.path[i]
			if game.fog.is_watched(Vector2i(p.round())):
				var edge := (prev + p) / 2.0
				if not out.any(func(o: Vector2) -> bool: return o.distance_to(edge) < MERGE_DISTANCE):
					out.append(edge)
				break
			prev = p
	return out


func _show(points: Array[Vector2]) -> void:
	while _pool.size() < points.size():
		var s := Art.sprite("warning_light")
		add_child(s)
		_pool.append(s)
	for i in _pool.size():
		_pool[i].visible = i < points.size()
		if i < points.size():
			_pool[i].position = Iso.to_world(points[i])
	_active = points.size()
