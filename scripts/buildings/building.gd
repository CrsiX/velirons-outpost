class_name Building
extends Node2D
## Base for everything placed on the tile grid. A building is either a
## construction site (complete == false, worked on by builders) or finished.

signal completed(building: Building)

## Number within its kind (see label()), given when it is added to the world.
var uid := 0
var game: Game
## Owner. Set before setup(); the village's systems handle everything for it.
var village: Village
## Id that commands use to name this building (Game.register).
var nid := 0
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
## Marked for tear-down (a builder's job, see Construction.order_tear_down):
## the building stops working at once; when the work is done it is removed
## and a share of its building material comes back.
var tearing_down := false
var teardown_progress := 0.0
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


## Tile a builder stands on while working (and units step on and off a
## tower from): the free tile next to it nearest the village that can be
## reached from there. Trees can cut off the nearest one.
func work_tile() -> Vector2i:
	if not is_solid_when_complete():
		return tile
	var pathing := game.world.pathing
	var home: Vector2i = village.center if village else Config.VILLAGE_CENTER
	var best := tile
	var best_d := INF
	var reached := false
	for t in neighbour_tiles():
		if not pathing.is_walkable(t):
			continue
		var ok := pathing.can_reach(home, t)
		var d := Vector2(t).distance_to(Vector2(home))
		if (ok and not reached) or (ok == reached and d < best_d):
			reached = ok
			best_d = d
			best = t
	return best


## Tiles around the footprint (8-connected), not in it.
func neighbour_tiles() -> Array[Vector2i]:
	var own := tiles()
	var out: Array[Vector2i] = []
	for t in own:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := t + Vector2i(dx, dy)
				if not own.has(n) and not out.has(n):
					out.append(n)
	return out


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
	return not complete or upgrading or tearing_down


## Finished and not being torn down: the building does its job.
func working() -> bool:
	return complete and not tearing_down


func work_fraction() -> float:
	if not complete:
		return clampf(progress / build_time, 0.0, 1.0)
	if tearing_down:
		return clampf(teardown_progress / teardown_time(), 0.0, 1.0)
	return clampf(upgrade_progress / upgrade_time, 0.0, 1.0)


## Advance construction (or an upgrade). Returns true once done.
func add_progress(dt: float) -> bool:
	queue_redraw()
	if not complete:
		progress += dt
		return progress >= build_time
	if tearing_down:
		teardown_progress += dt
		return teardown_progress >= teardown_time()
	upgrade_progress += dt
	return upgrade_progress >= upgrade_time


# --- tear-down ---------------------------------------------------------------------------

## Buildings a player places can be torn down (not village huts).
func can_tear_down() -> bool:
	return complete and not tearing_down and Construction.KIND_SCRIPTS.has(kind)


## A builder's time to tear it down: a share of its build time.
func teardown_time() -> float:
	return build_time * Config.TEARDOWN_TIME_SHARE


## Building material spent on it: its price plus paid upgrades (override).
func materials_spent() -> int:
	return int(Config.BUILDINGS[kind]["cost"].get("materials", 0)) if Config.BUILDINGS.has(kind) else 0


## What a finished tear-down gives back.
func teardown_refund() -> int:
	return floori(materials_spent() * Config.TEARDOWN_REFUND)


## Marked for / spared from tear-down: subclasses stop their work here (the
## units and workers are sent away by Construction).
func set_tearing_down(on: bool) -> void:
	tearing_down = on
	teardown_progress = 0.0
	modulate = Color(1, 1, 1, 0.6) if on else Color.WHITE
	refresh()


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
		actions.append({"label": "Cancel (refund)", "action": func() -> void: game.command("cancel_site", {"building": nid})})
	elif tearing_down:
		lines.append("Tearing down: %d%%" % int(100.0 * work_fraction()))
		lines.append("Builder at work" if builder != null else "Waiting for a builder")
		lines.append(Config.cost_icons({"materials": teardown_refund()}) + " back when it's done")
		actions.append({"label": "Stop tear-down", "action": func() -> void: game.command("stop_tear_down", {"building": nid})})
	return {"title": display_name(), "lines": lines, "actions": actions}


## The panel's last action: tearing it down (after the building's own ones).
func add_tear_down_action(d: Dictionary) -> void:
	if not can_tear_down():
		return
	var actions: Array[Dictionary] = d["actions"]
	actions.append({
		"label": "Tear down (+%s)" % Config.cost_icons({"materials": teardown_refund()}),
		"action": func() -> void: game.command("tear_down", {"building": nid}),
	})


func pick_rect() -> Rect2:
	return Rect2(-40, -60, 80, 80)


func _draw() -> void:
	if not has_work():
		return
	var w := 60.0
	var r := Rect2(-w / 2.0, _bar_y(), w, 7.0)
	draw_rect(r.grow(2.0), Color("15110d"))
	draw_rect(r, Color("3a2e22"))
	draw_rect(Rect2(r.position, Vector2(w * bar_fraction(), r.size.y)), work_color())


## Progress bar fill: a tear-down empties it.
func bar_fraction() -> float:
	return 1.0 - work_fraction() if tearing_down else work_fraction()


## Progress bar colour: construction, upgrade, or (counting down) tear-down.
func work_color() -> Color:
	if not complete:
		return Color("c9a24a")
	return TEARDOWN_COLOR if tearing_down else Color("8fb8e0")


## Tear-down bars count down in this colour.
const TEARDOWN_COLOR := Color("a8553a")


## Height of the work progress bar above the anchor.
func _bar_y() -> float:
	return -78.0
