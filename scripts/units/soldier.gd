class_name Soldier
extends Unit
## The body of a MilitaryUnit outside: walking to or from a post (or another
## village), or out on a barracks sortie. Soldiers watch their surroundings
## (surveillance) and can be hurt (enemies stop to fight them; witches'
## spells hit them): the damage goes to the unit's HP, and at 0 it is downed
## (Army.down). Walking soldiers don't fight back, they keep walking.
##
## On a sortie (docs/military-design.md §5) it fights near its barracks:
## melee units close in and strike; ranged units walk until the nearest enemy
## is within their own range, then shoot (their behavior, with this body as
## the post); healers stay with their comrades; summoners step outside and
## summon. They never chase beyond the barracks' range + SORTIE_LEASH and
## walk back to their bench once no enemy is left in range.

signal arrived(soldier: Soldier)

enum Mode { WALK, SORTIE, BACK }

var unit: MilitaryUnit
var mode := Mode.WALK
var barracks: Barracks = null
## Out to guard this farm against rats (else: around the barracks).
var farm: Farm = null
var target: Enemy = null
var _think := 0.0
var _strike_cd := 0.0
var _calm := 0.0
var _chase_tile := Vector2i(-9999, -9999)


func setup(p_game: Game, p_unit: MilitaryUnit, from: Vector2i) -> void:
	game = p_game
	unit = p_unit
	speed = unit.spec()["speed"]
	_init_sprite("unit_" + unit.kind)
	set_grid_pos(Vector2(from))
	add_to_group("observers")
	add_to_group("melee_defenders")
	add_to_group("field_units")


## Its unit's village (for surveillance, gold for kills, the log).
var village: Village:
	get: return unit.village if unit else null

var dead: bool:
	get: return unit == null or unit.is_downed() or is_queued_for_deletion()


func label() -> String:
	return unit.label()


## Starts walking to `tile`. Returns false when there is no way there.
func walk_to(tile: Vector2i) -> bool:
	var p := game.world.pathing.find_path(current_tile(), tile)
	if p.is_empty():
		return false
	follow(p)
	return true


func start_sortie(b: Barracks, p_farm: Farm = null) -> void:
	barracks = b
	farm = p_farm
	mode = Mode.SORTIE
	_calm = 0.0
	sprite.texture = Art.tex("unit_" + unit.kind)


func _process(delta: float) -> void:
	if game.is_client:
		net_follow(delta)  # the host simulates; we just follow
		return
	if dead:
		return
	match mode:
		Mode.WALK:
			# A unit sent to another village is theirs as soon as it's inside their walls.
			var entered := unit.state == MilitaryUnit.State.TRAVELLING and unit.travel_to.rect.has_point(current_tile())
			if step_path(delta) or entered:
				arrived.emit(self)
		Mode.SORTIE:
			_sortie(delta)
		Mode.BACK:
			if step_path(delta):
				arrived.emit(self)


# --- barracks sortie ------------------------------------------------------------------------

func _sortie(delta: float) -> void:
	if not is_instance_valid(barracks):
		mode = Mode.WALK
		arrived.emit(self)
		return
	_think -= delta
	_strike_cd -= delta
	if _think <= 0.0:
		_think = 0.3
		if farm != null and (not is_instance_valid(farm) or barracks.enemy_near()):
			farm = null  # a real threat at the barracks comes first
		target = _nearest_foe()
	if target == null:
		_calm += delta
		if _calm >= 1.0:  # nobody left in range: back to the bench
			mode = Mode.BACK
			if not walk_to(barracks.work_tile()):
				arrived.emit(self)
		elif unit.role() == "healer" or unit.role() == "summoner":
			unit.behavior.tick(self, unit, delta)
		return
	_calm = 0.0
	match unit.role():
		"melee":
			if target.grid_pos.distance_to(grid_pos) > Config.UNIT_MELEE_RANGE:
				_close_in(delta, target.grid_pos)
			else:
				_set_moving(false)
				face(target.grid_pos)
				if _strike_cd <= 0.0:
					_strike_cd = unit.stat("cooldown")
					Combat.attack(game, unit, muzzle_position(), target, self)
					recoil()
		"ranged":
			if target.grid_pos.distance_to(grid_pos) > unit.field_range() * 0.95:
				_close_in(delta, target.grid_pos)
			else:
				_set_moving(false)
				unit.behavior.tick(self, unit, delta)
		"healer":
			var mates := _comrades_center()
			if mates.distance_to(grid_pos) > 1.2:
				_close_in(delta, mates)
			else:
				_set_moving(false)
			unit.behavior.tick(self, unit, delta)
		"summoner":
			_set_moving(false)  # summons from just outside the barracks
			unit.behavior.tick(self, unit, delta)


## The enemy within the barracks' reach nearest to this soldier.
func _nearest_foe() -> Enemy:
	var reach := barracks.activation_range() + Config.SORTIE_LEASH
	var home := barracks.act_center()
	if farm != null:
		reach = Config.FARM_DEFENSE_LEASH
		home = Vector2(farm.tile)
	var best: Enemy = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or e.grid_pos.distance_to(home) > reach:
			continue
		var d := e.grid_pos.distance_to(grid_pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func _close_in(delta: float, to: Vector2) -> void:
	var pathing := game.world.pathing
	var tile := Vector2i(to.round())
	var open := pathing.is_walkable(tile)
	if not open:
		tile = pathing.nearest_walkable(tile)  # (it stands where we can't: get as near as we can)
	if path_index >= path.size() or tile != _chase_tile:
		_chase_tile = tile
		var p := pathing.find_path(current_tile(), tile)
		if p.is_empty():
			return
		p[0] = grid_pos
		if open:
			p[p.size() - 1] = to
		follow(p)
	step_path(delta)


## Where the other units out from the same barracks are (or its door).
func _comrades_center() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for s in get_tree().get_nodes_in_group("field_units"):
		var so := s as Soldier
		if so != self and so.barracks == barracks and so.mode == Mode.SORTIE and not so.dead:
			sum += so.grid_pos
			n += 1
	return sum / n if n > 0 else Vector2(barracks.work_tile())


# --- taking hits ---------------------------------------------------------------------------

func take_damage(amount: float, source = null) -> void:
	if dead:
		return
	unit.hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.5, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if unit.hp <= 0.0:
		village.army.down(unit, source)


## Downed: gone with a little flash; no corpse.
func vanish() -> void:
	remove_from_group("melee_defenders")
	remove_from_group("field_units")
	remove_from_group("observers")
	set_process(false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_property(self, "scale", Vector2(1.3, 0.4), 0.35)
	tw.chain().tween_callback(queue_free)


# --- the "post" behaviors act from on a sortie (see MilitaryBehavior) ---------------------

func act_center() -> Vector2:
	return grid_pos


func act_range() -> float:
	return unit.field_range()


func face(grid_target: Vector2) -> void:
	sprite.flip_h = Iso.to_world(grid_target - grid_pos).x < 0.0


func recoil() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "position", Vector2(0, -3), 0.06)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.1)


func muzzle_position() -> Vector2:
	return global_position + Vector2(0, -24)


func outer_tile() -> Vector2i:
	return current_tile()


func sight_radius() -> float:
	return Config.UNIT_SIGHT


func sight_center() -> Vector2:
	return grid_pos


func _draw() -> void:
	if unit == null or dead or unit.hp >= unit.max_hp():
		return
	var w := 26.0
	var r := Rect2(-w / 2.0, -50.0, w, 4.0)
	draw_rect(r.grow(1.5), Color("15110d"))
	draw_rect(r, Color("3a2a10"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(unit.hp / unit.max_hp(), 0.0, 1.0), r.size.y)), Color("e0c050"))
