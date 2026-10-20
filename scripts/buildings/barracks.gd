class_name Barracks
extends MilitaryPost
## 2x2 yard with a hut, benches, a table with food and drink and a straw
## puppet full of arrows (docs/military-design.md §5). Units stationed here
## sit on the benches (one per level, Config.BARRACKS_LEVELS). When an enemy
## comes within the barracks' range, everyone on the benches turns out and
## fights (Soldier sortie), and walks back once no enemy is left. Upgrades
## (building material and a builder's time) add a bench and range. Units heal
## on the benches.

## Where the benches' sitters are drawn (per bench, local coordinates).
const BENCH_SPOTS: Array[Vector2] = [Vector2(-0.35, 0.45), Vector2(0.45, 0.35), Vector2(0.1, -0.25)]

var _bench_sprites: Array[Sprite2D] = []
var _site_sprite: Sprite2D
var _scan := 0.0
## A sitter's HP bar was drawn (redrawn until it is gone).
var _bars_shown := false


func _build_visuals() -> void:
	sprite = Art.sprite("barracks")
	sprite.show_behind_parent = true
	add_child(sprite)
	for i in BENCH_SPOTS.size():
		var s := Sprite2D.new()
		s.show_behind_parent = true
		s.position = Iso.to_world(BENCH_SPOTS[i]) + Vector2(0, -4)
		s.visible = false
		add_child(s)
		_bench_sprites.append(s)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	_site_sprite.scale *= 1.4
	add_child(_site_sprite)


func post_kind() -> String:
	return "barracks"


func capacity() -> int:
	return Config.BARRACKS_LEVELS[level - 1]["slots"]


func max_level() -> int:
	return Config.BARRACKS_LEVELS.size()


## Enemies this close (tiles from the yard's middle) make everyone turn out.
func activation_range() -> float:
	return Config.BARRACKS_LEVELS[level - 1]["range"]


func act_center() -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


func refresh() -> void:
	fit_slots()
	Art.apply(sprite, _art())
	sprite.visible = complete
	_site_sprite.visible = not complete
	for i in _bench_sprites.size():
		var u: MilitaryUnit = slots[i] if i < slots.size() else null
		var s := _bench_sprites[i]
		s.visible = complete and u != null and not u.out and not devastated
		if s.visible:
			UnitFx.show_unit(s, u.kind)
			s.modulate = Color(1, 1, 1, 0.35) if u.is_downed() else Color.WHITE
	queue_redraw()


func _art() -> String:
	return "barracks" if level == 1 else "barracks_%d" % level


## Where `unit`'s bench is (grid position: where its sitter is drawn), or
## Vector2.INF if it has none here.
func bench_point(unit: MilitaryUnit) -> Vector2:
	var i := slots.find(unit)
	if i < 0 or i >= _bench_sprites.size():
		return Vector2.INF
	return Iso.to_grid(position + _bench_sprites[i].position)


## Enemies near? Everyone who's sitting on a bench (and not downed) goes out.
func _process(delta: float) -> void:
	if _hurt_on_bench() or _bars_shown:
		queue_redraw()  # (their HP bars, while they heal)
	if game.is_client or not working():
		return
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.3
	var farm: Farm = null
	if not enemy_near():
		farm = _farm_with_rats()
		if farm == null:
			return
	for u in units():
		if u.state == MilitaryUnit.State.STATIONED and not u.out:
			village.army.sortie(u, farm)


## One of our farms with rats on it, within BARRACKS_FARM_RANGE_FACTOR x range.
func _farm_with_rats() -> Farm:
	var c := act_center()
	var r := activation_range() * Config.BARRACKS_FARM_RANGE_FACTOR
	for b in game.world.buildings:
		if b is Farm and b.village == village and b.has_rats() and Vector2(b.tile).distance_to(c) <= r:
			return b
	return null


## An enemy the bench can fight within the activation range? (Soldiers
## guarding a farm drop it for this.)
func enemy_near() -> bool:
	var c := act_center()
	var r := activation_range()
	var no_flyers := not units().any(func(u: MilitaryUnit) -> bool: return u.hits_flyers())
	var only_melee := units().all(func(u: MilitaryUnit) -> bool: return u.role() == "melee")
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.targetable() or (e.flies() and no_flyers):
			continue  # (only melee on the benches, no halberdier: they can't go for flyers)
		if only_melee and not e.melee_ok(c):
			continue  # (out in deep water, or a siren in the water: blades can't reach it)
		if e.grid_pos.distance_to(c) <= r:
			return true
	return false


# --- upgrades (like towers: building material and a builder's time) --------------------

func can_upgrade() -> bool:
	return free_for_work() and level < max_level()


## Its price plus the upgrades paid for (tear-down refund).
func materials_spent() -> int:
	var n := super.materials_spent()
	for i in range(1, level):
		n += int(Config.BARRACKS_LEVELS[i]["cost"].get("materials", 0))
	return n


func upgrade_cost() -> Dictionary:
	return Config.BARRACKS_LEVELS[level]["cost"] if level < max_level() else {}


func start_upgrade() -> void:
	upgrading = true
	upgrade_progress = 0.0
	upgrade_time = Config.BARRACKS_LEVELS[level]["work_time"]
	queue_redraw()


func pending_upgrade_cost() -> Dictionary:
	return upgrade_cost() if upgrading else {}


func finish_upgrade() -> void:
	super.finish_upgrade()
	gain_level()
	refresh()


# --- picking units on the benches ---------------------------------------------------------

func unit_at(local: Vector2) -> MilitaryUnit:
	for i in _bench_sprites.size():
		var s := _bench_sprites[i]
		if s.visible and i < slots.size() and slots[i] != null and slots[i].state == MilitaryUnit.State.STATIONED and sprite_rect(s).has_point(local):
			return slots[i]
	return null


func unit_pick_rect() -> Rect2:
	return Rect2()  # (several benches: see unit_at)


func unit_rect(unit: MilitaryUnit) -> Rect2:
	for i in mini(_bench_sprites.size(), slots.size()):
		if unit != null and slots[i] == unit and unit.state == MilitaryUnit.State.STATIONED and _bench_sprites[i].visible:
			return sprite_rect(_bench_sprites[i])
	return Rect2()


func set_unit_ghosted(on: bool, unit: MilitaryUnit = null) -> void:
	for i in _bench_sprites.size():
		if unit == null or (i < slots.size() and slots[i] == unit):
			_bench_sprites[i].modulate.a = 0.35 if on else 1.0


# --- panel --------------------------------------------------------------------------------

func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	if not working():
		return d
	d["title"] = "%s  ·  Level %d/%d" % [display_name(), level, max_level()]
	lines.append("%d bench%s; turns out for enemies within %.1f tiles." % [capacity(), "" if capacity() == 1 else "es", activation_range()])
	for i in capacity():
		var u: MilitaryUnit = slots[i]
		var inc: MilitaryUnit = incoming_slots[i]
		if u:
			lines.append("Bench %d: %s, level %d: {hp} %d/%d, %s" % [i + 1, u.display_name(), u.level + 1, ceili(u.hp), ceili(u.max_hp()), u.state_text()])
			if u.is_available() and not u.upgrade_options().is_empty():
				actions.append({"label": "Upgrade %s (bench %d)..." % [u.display_name().to_lower(), i + 1], "action": func() -> void: game.hud.open_upgrade(u)})
			if u.is_available() and not u.fixed():
				actions.append({"label": "Withdraw %s (bench %d)" % [u.display_name().to_lower(), i + 1], "action": func() -> void: game.command("withdraw_unit", {"unit": u.nid})})
		elif inc:
			lines.append("Bench %d: %s marching here." % [i + 1, inc.display_name()])
		else:
			lines.append("Bench %d: free. Drag a unit from the Army tab here." % (i + 1))
	if upgrading:
		lines.append("Upgrading to level %d: %d%% (%s)" % [level + 1, int(100.0 * work_fraction()), "builder at work" if builder != null else "waiting for a builder"])
		add_cancel_action(lines, actions, "Cancel upgrade")
	elif level < max_level() and not repairing:
		var nxt: Dictionary = Config.BARRACKS_LEVELS[level]
		lines.append("Next level: %d benches, range %.1f, {hp} %d." % [nxt["slots"], nxt["range"], roundi(Config.BUILDING_HP[kind][level])])
		actions.append({
			"label": "Upgrade barracks (%s)" % Config.cost_icons(upgrade_cost()),
			"disabled": not village.economy.can_afford(upgrade_cost()),
			"action": func() -> void: game.command("upgrade_tower", {"building": nid}),
		})
	return d


func pick_rect() -> Rect2:
	return Rect2(-110, -80, 220, 130)



## A unit sitting on a bench (shown) with less than full HP.
func _hurt_on_bench() -> bool:
	for i in mini(_bench_sprites.size(), slots.size()):
		var u: MilitaryUnit = slots[i]
		if u != null and _bench_sprites[i].visible and not u.is_downed() and u.hp < u.max_hp():
			return true
	return false


## The bars, and an HP bar over every hurt sitter (as over a soldier out), until it has healed.
func _draw() -> void:
	super._draw()
	_bars_shown = false
	for i in mini(_bench_sprites.size(), slots.size()):
		var u: MilitaryUnit = slots[i]
		var spr := _bench_sprites[i]
		if u == null or not spr.visible or u.is_downed() or u.hp >= u.max_hp():
			continue
		_bars_shown = true
		var r := Rect2(spr.position + Vector2(-13.0, -50.0), Vector2(26.0, 4.0))
		draw_rect(r.grow(1.5), Color("15110d"))
		draw_rect(r, Color("3a2a10"))
		draw_rect(Rect2(r.position, Vector2(26.0 * clampf(u.hp / u.max_hp(), 0.0, 1.0), 4.0)), Color("e0c050"))


func _bar_y() -> float:
	return -86.0
