class_name Building
extends Node2D
## Base for everything placed on the tile grid. A building is either a
## construction site (complete == false, worked on by builders) or finished.

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
## Its job in the build queue (Construction.claim): when it was queued
## (Game.clock), how often builders fled from it, and for how long no enemy
## has been near it since.
var queued_at := 0.0
var interrupts := 0
var calm := 0.0
## Share of the kind's listed price that was really paid for the construction
## under way.
var paid_share := 1.0
## Level (towers, barracks, gates and walls level up; the rest stay at 1).
var level := 1
## HP (docs/siege-design.md): enemies wear it down, it never heals by itself;
## at 0 the building is devastated and does nothing until it is repaired.
var hp := 1.0
var devastated := false
## A repair ordered (a builder's job, like an upgrade): the HP it gives back
## and what it cost (refunded in part when cancelled).
var repairing := false
var repair_progress := 0.0
var repair_time := 1.0
var repair_hp := 0.0
var repair_paid := {}
## Heaps of rubble over a devastated building without ruin art of its own.
var _rubble: Sprite2D
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
## Tear-down bars count down in this colour.
const TEARDOWN_COLOR := Color("a8553a")
var sprite: Sprite2D


func setup(p_game: Game, p_kind: String, p_tile: Vector2i, p_complete: bool) -> void:
	game = p_game
	kind = p_kind
	tile = p_tile
	complete = p_complete
	if Config.BUILDINGS.has(kind):
		size = Config.BUILDINGS[kind]["size"]
	build_time = float(Building.price(kind).get("build_time", 1.0))
	hp = max_hp()
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


## A kind's price and build time: Config.BUILDINGS, or for the village's
## pieces Config.PIECE_PRICES (never bought; it counts for repairs).
static func price(p_kind: String) -> Dictionary:
	if Config.BUILDINGS.has(p_kind):
		return Config.BUILDINGS[p_kind]
	return Config.PIECE_PRICES.get(p_kind, {})


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

## Finished buildings watch BUILDING_SIGHT + size / 2 (whole tiles) around their anchor tile.
func sight_radius() -> float:
	return Config.BUILDING_SIGHT + size / 2 if complete and not devastated else 0.0


func sight_center() -> Vector2:
	return Vector2(tile)


## Finished, standing and not being torn down: the building does its job.
func working() -> bool:
	return complete and not tearing_down and not devastated


func has_work() -> bool:
	return not complete or upgrading or tearing_down or repairing


func work_fraction() -> float:
	if not complete:
		return clampf(progress / build_time, 0.0, 1.0)
	if tearing_down:
		return clampf(teardown_progress / teardown_time(), 0.0, 1.0)
	if repairing:
		return clampf(repair_progress / repair_time, 0.0, 1.0)
	return clampf(upgrade_progress / upgrade_time, 0.0, 1.0)


## Advance construction (or a tear-down, a repair or an upgrade). Returns true once done.
func add_progress(dt: float) -> bool:
	queue_redraw()
	if not complete:
		progress += dt
		return progress >= build_time
	if tearing_down:
		teardown_progress += dt
		return teardown_progress >= teardown_time()
	if repairing:
		repair_progress += dt
		return repair_progress >= repair_time
	upgrade_progress += dt
	return upgrade_progress >= upgrade_time


# --- HP, devastation and repairs (docs/siege-design.md) -------------------------------------

## Max HP at its level (Config.BUILDING_HP).
func max_hp() -> float:
	var list: Array = Config.BUILDING_HP.get(kind, [1.0])
	return float(list[clampi(level - 1, 0, list.size() - 1)])


func hp_share() -> float:
	return clampf(hp / max_hp(), 0.0, 1.0)


## Can enemies hurt it now? Finished, standing, owned (not a ruin nobody
## plays), and not in the title backdrop; the co-op host decides.
func can_be_hurt() -> bool:
	return complete and not devastated and village != null and not game.backdrop and not game.is_client


## Damage from an enemy (`source`); every category counts the same. At 0 HP
## the building is devastated (Construction.on_devastated).
func take_damage(amount: float, source: Node = null) -> void:
	if amount <= 0.0 or not can_be_hurt():
		return
	var before := hp
	hp = maxf(hp - amount, 0.0)
	game.siege.on_damaged(self, source, before - hp)
	queue_redraw()
	if sprite:
		sprite.self_modulate = Color(1.0, 0.55, 0.5)
		create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
	if hp <= 0.0:
		village.construction.on_devastated(self, source)


## Devastated or standing again: its look, its solidity, and the siege field.
func set_devastated(on: bool) -> void:
	devastated = on
	if on:
		hp = 0.0
	refresh()
	_update_ruin_look()
	if game.world:
		game.world.refresh_building(self)


## Kinds with ruin art of their own (towers, walls, gates) show it in refresh();
## the rest are darkened, with rubble on top.
func has_ruin_art() -> bool:
	return false


func _update_ruin_look() -> void:
	var show := devastated and not has_ruin_art()
	if show and _rubble == null:
		_rubble = Art.sprite("rubble")
		_rubble.scale *= 0.7 + 0.45 * (size - 1)
		add_child(_rubble)
	if _rubble:
		_rubble.visible = show
	_update_tint()


## Dimmed while torn down, darkened while devastated (without ruin art).
func _update_tint() -> void:
	var c := Color.WHITE
	if devastated and not has_ruin_art():
		c = Color(0.5, 0.46, 0.43)
	if tearing_down:
		c.a = 0.6
	modulate = c


## Missing share of its HP (0: whole).
func missing_share() -> float:
	return 1.0 - hp_share()


## Can a repair be ordered? Finished, hurt, nothing else under way.
func can_repair() -> bool:
	return complete and village != null and not repairing and not upgrading and not tearing_down and missing_share() > 0.0


## Building material for a repair: REPAIR_SHARE of what was spent on it,
## times the missing share of its HP (rounded up, at least 1).
func repair_cost() -> Dictionary:
	if missing_share() <= 0.0:
		return {}
	return {"materials": maxi(1, ceili(materials_spent() * Config.REPAIR_SHARE * missing_share() - 0.0001))}


func start_repair(cost: Dictionary) -> void:
	repairing = true
	repair_progress = 0.0
	repair_hp = max_hp() - hp
	repair_time = maxf(build_time * Config.REPAIR_TIME_SHARE * missing_share(), 0.5)
	repair_paid = cost.duplicate()
	queue_redraw()


## The repair is done: back the HP that was paid for; standing again.
func finish_repair() -> void:
	repairing = false
	hp = minf(max_hp(), hp + repair_hp)
	repair_hp = 0.0
	repair_paid = {}
	if devastated and hp > 0.0:
		set_devastated(false)
	refresh()
	queue_redraw()


func cancel_repair() -> void:
	repairing = false
	repair_progress = 0.0
	repair_hp = 0.0
	repair_paid = {}
	queue_redraw()


## One level up (an upgrade finished): the max HP grows, and so does its HP.
func gain_level() -> void:
	var before := max_hp()
	level += 1
	if not devastated:
		hp += max_hp() - before


## Nothing else under way: an upgrade can be ordered (with levels left).
func free_for_work() -> bool:
	return working() and not upgrading and not repairing


# --- cancelling a site or an ordered upgrade ----------------------------------------------

## What was paid for the construction under way.
func paid_cost() -> Dictionary:
	var out := {}
	if not Config.BUILDINGS.has(kind):
		return out
	var cost: Dictionary = Building.price(kind)["cost"]
	for res in cost:
		out[res] = ceili(cost[res] * paid_share)
	return out


## Share of what was paid that cancelling gives back, for a site and for an
## ordered upgrade alike: all of it while no builder has worked on it, falling
## off evenly with the work done, and none of it by the time it is finished.
func refund_share() -> float:
	if tearing_down or (complete and not upgrading and not repairing):
		return 0.0
	return 1.0 - work_fraction()


## Resources cancelling gives back right now: what is left of the site's
## price, or of the ordered upgrade's.
func cancel_refund() -> Dictionary:
	var out := {}
	var share := refund_share()
	var paid := paid_cost()
	if complete:
		paid = repair_paid if repairing else pending_upgrade_cost()
	for res in paid:
		var n := floori(paid[res] * share)
		if n > 0:
			out[res] = n
	return out


# --- tear-down ---------------------------------------------------------------------------

## Buildings a player places can be torn down (not village huts).
func can_tear_down() -> bool:
	return complete and not tearing_down and Construction.KIND_SCRIPTS.has(kind)


## A builder's time to tear it down: a share of its build time.
func teardown_time() -> float:
	return build_time * Config.TEARDOWN_TIME_SHARE


## Building material spent on it: its price plus paid upgrades (override).
## The village's pieces count their Config.PIECE_PRICES.
func materials_spent() -> int:
	return int(Building.price(kind).get("cost", {}).get("materials", 0))


## What a finished tear-down gives back: a share of the material spent on
## it, scaled by its HP (a devastated building gives nothing back).
func teardown_refund() -> int:
	return floori(materials_spent() * Config.TEARDOWN_REFUND * hp_share() + 0.0001)


## Marked for / spared from tear-down: subclasses stop their work here (the
## units and workers are sent away by Construction).
func set_tearing_down(on: bool) -> void:
	tearing_down = on
	teardown_progress = 0.0
	_update_tint()
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
	hp = max_hp()
	refresh()
	var tw := create_tween()
	scale = Vector2(1.08, 0.92)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		add_cancel_action(lines, actions, "Cancel")
	elif tearing_down:
		lines.append("Tearing down: %d%%" % int(100.0 * work_fraction()))
		lines.append("Builder at work" if builder != null else "Waiting for a builder")
		lines.append(Config.cost_icons({"materials": teardown_refund()}) + " back when it's done")
		actions.append({"label": "Stop tear-down", "action": func() -> void: game.command("stop_tear_down", {"building": nid})})
	var title := display_name()
	if complete and devastated:
		title = "Devastated %s" % display_name()
	return {"title": title, "lines": lines, "actions": actions}


## The HP line and the repair (or its progress) for a finished building's
## panel, at the top of its lines; a devastated one says it does nothing.
func add_hp_info(lines: Array[String], actions: Array[Dictionary]) -> void:
	if not complete or village == null:
		return
	var top: Array[String] = []
	if devastated:
		top.append("Devastated: it does nothing until it is repaired.")
	else:
		top.append("{hp} %d / %d" % [ceili(hp), roundi(max_hp())])
	if repairing:
		top.append("Repairing: %d%% (%s)" % [int(100.0 * work_fraction()), "builder at work" if builder != null else "waiting for a builder"])
		add_cancel_action(top, actions, "Cancel repair")
	elif can_repair() and not tearing_down:
		var cost := repair_cost()
		actions.append({
			"label": "Repair (%s)" % Config.cost_icons(cost),
			"disabled": not village.economy.can_afford(cost),
			"action": func() -> void: game.command("repair", {"building": nid}),
		})
	for i in top.size():
		lines.insert(i, top[i])


## Calling off the work under way (a site, or an ordered upgrade: `what` names
## it on the button), saying what is left of its price to come back.
func add_cancel_action(lines: Array[String], actions: Array[Dictionary], what: String) -> void:
	var back := cancel_refund()
	var press := func() -> void: game.command("cancel_site", {"building": nid})
	if back.is_empty():
		lines.append("Too far along to get anything back")
		actions.append({"label": what, "action": press})
		return
	lines.append("%s back if you cancel now" % Config.cost_icons(back))
	actions.append({"label": "%s (+%s)" % [what, Config.cost_icons(back)], "action": press})


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
	_draw_bars()


## The HP bar (hurt) and the work progress bar (a kind that draws itself
## differently, like the stall, still calls it).
func _draw_bars() -> void:
	var w := 60.0
	if complete and not devastated and hp < max_hp() and village != null:
		var share := hp_share()
		var col := Color("5fbf4a") if share >= 0.5 else (Color("e0c040") if share >= 0.25 else Color("d04a3a"))
		var hr := Rect2(-w / 2.0, _bar_y() + (11.0 if has_work() else 0.0), w, 5.0)
		draw_rect(hr.grow(2.0), Color("15110d"))
		draw_rect(hr, Color("3a2e22"))
		draw_rect(Rect2(hr.position, Vector2(w * share, hr.size.y)), col)
	if not has_work():
		return
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
	if repairing and not tearing_down:
		return Color("6fc2a8")
	return TEARDOWN_COLOR if tearing_down else Color("8fb8e0")


## Height of the work progress bar above the anchor.
func _bar_y() -> float:
	return -78.0
