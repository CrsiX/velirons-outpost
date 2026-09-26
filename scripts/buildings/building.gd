class_name Building
extends Node2D
## Base for everything placed on the tile grid. A building is either a
## construction site (complete == false, worked on by builders) or finished.

signal completed(building: Building)

var game: Game
var kind := ""
## Anchor tile. For odd-sized footprints this is the centre tile.
var tile := Vector2i.ZERO
var size := 1
var complete := true
var progress := 0.0
var build_time := 1.0
## Builder currently assigned to this site (if any).
var builder: Node = null
var sprite: Sprite2D


func setup(p_game: Game, p_kind: String, p_tile: Vector2i, p_complete: bool) -> void:
	game = p_game
	kind = p_kind
	tile = p_tile
	complete = p_complete
	if Config.BUILDINGS.has(kind):
		size = Config.BUILDINGS[kind]["size"]
		build_time = Config.BUILDINGS[kind]["build_time"]
	position = Iso.tile_to_world(tile)
	_build_visuals()
	refresh()


func tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := size / 2
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			out.append(tile + Vector2i(dx, dy))
	return out


func display_name() -> String:
	return Config.BUILDINGS[kind]["name"] if Config.BUILDINGS.has(kind) else kind.capitalize()


## Blocks civilian movement? Sites never do, so builders can walk onto them.
func is_solid() -> bool:
	return false


## Tile a builder stands on while working.
func work_tile() -> Vector2i:
	if not is_solid_when_complete():
		return tile
	var best := tile
	var best_d := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := tile + Vector2i(dx, dy)
			if t == tile or not game.world.pathing.is_walkable(t):
				continue
			var d := Vector2(t).distance_to(Vector2(Config.VILLAGE_CENTER))
			if d < best_d:
				best_d = d
				best = t
	return best


func is_solid_when_complete() -> bool:
	return false


## Advance construction. Returns true once finished.
func add_progress(dt: float) -> bool:
	progress += dt
	queue_redraw()
	return progress >= build_time


func finish() -> void:
	complete = true
	progress = build_time
	refresh()
	var tw := create_tween()
	scale = Vector2(1.08, 0.92)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	completed.emit(self)


## Override: create sprites.
func _build_visuals() -> void:
	pass


## Override: update sprites for the current state.
func refresh() -> void:
	queue_redraw()


## Override: info panel content. Returns {title, lines: Array[String], actions: Array[Dictionary]}.
func info() -> Dictionary:
	var lines: Array[String] = []
	var actions: Array[Dictionary] = []
	if not complete:
		lines.append("Construction site: %d%%" % int(100.0 * progress / build_time))
		lines.append("Builder at work" if builder != null else "Waiting for a builder")
		actions.append({"label": "Cancel (refund)", "action": func() -> void: game.construction.cancel(self)})
	return {"title": display_name(), "lines": lines, "actions": actions}


func pick_rect() -> Rect2:
	return Rect2(-40, -60, 80, 80)


func _draw() -> void:
	if complete:
		return
	var w := 60.0
	var r := Rect2(-w / 2.0, -78.0, w, 7.0)
	draw_rect(r.grow(2.0), Color("15110d"))
	draw_rect(r, Color("3a2e22"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(progress / build_time, 0.0, 1.0), r.size.y)), Color("c9a24a"))
