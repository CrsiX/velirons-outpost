class_name Building
extends Node2D
## Base for everything placed on the tile grid. A building is either a
## construction site (complete == false, worked on by builders) or finished.

signal completed(building: Building)

## Number within its kind (see label()), given when it is added to the world.
var uid := 0
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
## Builder work on a finished building (e.g. a tower upgrade). The building
## keeps working normally meanwhile.
var upgrading := false
var upgrade_progress := 0.0
var upgrade_time := 1.0
var sprite: Sprite2D


func setup(p_game: Game, p_kind: String, p_tile: Vector2i, p_complete: bool) -> void:
	game = p_game
	kind = p_kind
	tile = p_tile
	complete = p_complete
	if Config.BUILDINGS.has(kind):
		size = Config.BUILDINGS[kind]["size"]
		build_time = Config.BUILDINGS[kind]["build_time"]
	position = Building.anchor_world(tile, size)
	add_to_group("observers")
	_build_visuals()
	refresh()


func tiles() -> Array[Vector2i]:
	return Building.footprint(tile, size)


## Tiles covered by a `size` x `size` building anchored on `anchor`. Odd sizes
## are centred on the anchor; even sizes extend right/down from it.
static func footprint(anchor: Vector2i, p_size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-(p_size - 1) / 2, p_size / 2 + 1):
		for dx in range(-(p_size - 1) / 2, p_size / 2 + 1):
			out.append(anchor + Vector2i(dx, dy))
	return out


## World position of a building's visual centre (between tiles for even sizes).
static func anchor_world(anchor: Vector2i, p_size: int) -> Vector2:
	var half := 0.5 if p_size % 2 == 0 else 0.0
	return Iso.to_world(Vector2(anchor) + Vector2(half, half))


func display_name() -> String:
	return Config.BUILDINGS[kind]["name"] if Config.BUILDINGS.has(kind) else kind.capitalize()


## Log name, numbered per kind: "watchtower 2", "farm 1", "hut 4".
func label() -> String:
	var n := display_name().to_lower().trim_prefix("village ")
	return "%s %d" % [n, uid]


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


# --- surveillance (group "observers") -------------------------------------------

## Finished buildings watch BUILDING_SIGHT tiles beyond their footprint.
func sight_radius() -> float:
	return Config.BUILDING_SIGHT + size / 2 if complete else 0.0


func sight_center() -> Vector2:
	return Vector2(tile)


## Does a builder have anything to do here (construction or an upgrade)?
func has_work() -> bool:
	return not complete or upgrading


func work_fraction() -> float:
	if not complete:
		return clampf(progress / build_time, 0.0, 1.0)
	return clampf(upgrade_progress / upgrade_time, 0.0, 1.0)


## Advance construction (or an upgrade). Returns true once done.
func add_progress(dt: float) -> bool:
	queue_redraw()
	if not complete:
		progress += dt
		return progress >= build_time
	upgrade_progress += dt
	return upgrade_progress >= upgrade_time


## Override: apply a finished upgrade.
func finish_upgrade() -> void:
	upgrading = false
	queue_redraw()


## Override: undo an ordered upgrade (the cost is refunded by Construction).
func cancel_upgrade() -> void:
	upgrading = false
	upgrade_progress = 0.0
	queue_redraw()


## Override: cost refunded when an ordered upgrade is cancelled.
func pending_upgrade_cost() -> Dictionary:
	return {}


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
	if not has_work():
		return
	var w := 60.0
	var r := Rect2(-w / 2.0, _bar_y(), w, 7.0)
	draw_rect(r.grow(2.0), Color("15110d"))
	draw_rect(r, Color("3a2e22"))
	draw_rect(Rect2(r.position, Vector2(w * work_fraction(), r.size.y)), Color("c9a24a") if not complete else Color("8fb8e0"))


## Height of the work progress bar above the anchor.
func _bar_y() -> float:
	return -78.0
