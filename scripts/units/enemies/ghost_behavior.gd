class_name GhostBehavior
extends EnemyBehavior
## A ghost (docs/enemies-design.md §15f; Config.GHOST): it picks one living
## villager of its village and hunts them, not the village. It follows its
## road for road_share of it, then flies (Pathing.ghost_path) to where its
## target is. Faded (untargetable, harmless, unseen by villagers) unless
## revealed (a working light stone's light, a High Priest's aura) or hunting
## within melee range + solid_margin of its target. A miner target inside a
## mine is driven out once the ghost stands by the mine. Its target fled home
## (hidden in the village) it lurks: faded, strolling a few tiles at a time,
## until they come out again; after `retreats` such escapes it gives up. Its
## target gone (dead, retired or given up) it roams faded for roam_time s, then
## vanishes. Revealed and
## hurt, it hits back at whoever hurt it if they are in reach (a tower it
## ignores). Moves itself: tick always holds the enemy.

enum Mode { ROAD, SEARCH, LURK, ROAM }

var mode := Mode.ROAD
## The villager it hunts (null: none, or its hunt is over).
var target: Civilian = null
## Seconds it has hunted in all (faded or solid; the road counts).
var hunted := 0.0
var enraged := false
## How often its target got home safe while it was after them.
var retreats := 0
## The target was running (evading) and not home yet.
var _chased := false
var _picked := false
var _roam_left := 0.0
var _lit := false
var _scan := 0.0
var _attack_timer := 0.0
var _hurt_by: Node = null
var _goal := Vector2.INF
var _replan := 0.0
var _detour := Vector2.INF
var _detour_roll := 0.0
var _roam_to := Vector2.INF
var _lurk_to := Vector2.INF


func tick(enemy: Enemy, delta: float) -> bool:
	enemy.self_moved = true
	var gc: Dictionary = Config.GHOST
	if not _picked:
		_pick(enemy)
	_attack_timer -= delta
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.2
		_lit = _revealed(enemy)
	if mode != Mode.ROAM:
		if _target_gone():
			_lose_target(enemy)
		else:
			_track_retreats(enemy)
	if mode == Mode.ROAD or mode == Mode.SEARCH:
		hunted += delta
		if not enraged and hunted >= float(gc["enrage_after"]):
			enraged = true
			enemy.set_walk_speed(enemy.base_speed * float(gc["enrage_speed"]))
			enemy.target_village.events.debug("%s hunts faster" % enemy.label())
	var reach := float(Config.SUMMON["attack_range"])
	var close := (mode == Mode.ROAD or mode == Mode.SEARCH) and enemy.grid_pos.distance_to(target.grid_pos) <= reach + float(gc["solid_margin"])
	enemy.set_faded(not (_lit or close))
	if mode == Mode.ROAM:
		_roam_left -= delta
		if _roam_left <= 0.0:
			enemy.target_village.events.debug("%s fades away" % enemy.label())
			enemy.vanish()
			return true
	if not enemy.faded and _fight(enemy, reach):
		return true
	match mode:
		Mode.ROAD:
			var share := float(enemy.path_index) / maxf(float(enemy.path.size()), 1.0)
			if enemy.walk_own(delta) or share >= float(gc["road_share"]):
				mode = Mode.SEARCH
				_goal = Vector2.INF
		Mode.SEARCH:
			_search(enemy, delta, reach)
		Mode.LURK:
			if _lurk_to == Vector2.INF or enemy.grid_pos.distance_to(_lurk_to) < 0.5:
				_lurk_to = _lurk_point(enemy)
			_fly_to(enemy, _lurk_to, delta)
		Mode.ROAM:
			if _roam_to == Vector2.INF or enemy.grid_pos.distance_to(_roam_to) < 0.6:
				_roam_to = _roam_point(enemy)
			_fly_to(enemy, _roam_to, delta)
	return true


## Its target: a living villager of its village, at random (none: it roams).
func _pick(enemy: Enemy) -> void:
	_picked = true
	var pool: Array[Civilian] = []
	if is_instance_valid(enemy.target_village):
		for civ in enemy.target_village.population.civilians:
			if not civ.dead:
				pool.append(civ)
	if pool.is_empty():
		_lose_target(enemy)
		return
	target = pool[randi() % pool.size()]
	enemy.target_village.events.debug("%s hunts %s" % [enemy.label(), target.label()])


## Dead, retired (out of the village's people), or freed.
func _target_gone() -> bool:
	return target == null or not is_instance_valid(target) or target.dead or not target.village.population.civilians.has(target)


## Its target running home and getting there: one escape (they may be hunted again
## when they come out), and after `retreats` of them it gives up. While they are
## hidden at home it lurks, and goes after them again when they come out.
func _track_retreats(enemy: Enemy) -> void:
	if target.evading and not target.at_home:
		_chased = true
	if target.at_home:
		if _chased:
			_chased = false
			retreats += 1
			enemy.target_village.events.debug("%s escaped %s (%d)" % [target.label(), enemy.label(), retreats])
			if retreats >= int(Config.GHOST["retreats"]):
				_lose_target(enemy)
				return
		if mode == Mode.SEARCH:
			mode = Mode.LURK
			_lurk_to = Vector2.INF
			_detour = Vector2.INF
	elif mode == Mode.LURK:
		mode = Mode.SEARCH
		_goal = Vector2.INF


## No one left to hunt: it fades and roams for roam_time s, then vanishes.
func _lose_target(enemy: Enemy) -> void:
	target = null
	mode = Mode.ROAM
	_roam_left = float(Config.GHOST["roam_time"])
	_goal = Vector2.INF
	_detour = Vector2.INF
	enemy.target_village.events.debug("%s has no one left to haunt" % enemy.label())


## Lit by a working light stone, or in a High Priest's aura (any village's).
static func _revealed(enemy: Enemy) -> bool:
	if Combat.in_holy_aura(enemy.game, enemy.grid_pos):
		return true
	for b in enemy.game.world.buildings:
		if b is LightStone and b.working() and Vector2(b.tile).distance_to(enemy.grid_pos) <= Config.LIGHTSTONE_SIGHT:
			return true
	return false


## Solid: a blow at whoever hurt it (in reach), else at its target in reach
## (not one sheltered: it then hovers there). True while it holds.
func _fight(enemy: Enemy, reach: float) -> bool:
	if is_instance_valid(_hurt_by) and not _hurt_by.dead and (_hurt_by.grid_pos as Vector2).distance_to(enemy.grid_pos) <= reach * 1.5:
		_strike(enemy, _hurt_by)
		return true
	_hurt_by = null
	if mode == Mode.ROAM or mode == Mode.LURK or target == null or enemy.grid_pos.distance_to(target.grid_pos) > reach:
		return false
	if not _sheltered(target):
		_strike(enemy, target)
	enemy.face(target.grid_pos)
	enemy._set_moving(false)
	return true


func _strike(enemy: Enemy, foe: Node) -> void:
	enemy.face(foe.grid_pos)
	enemy._set_moving(false)
	if _attack_timer > 0.0:
		return
	_attack_timer = enemy.stat("attack_cooldown") / enemy.haste()
	enemy.swing(foe.grid_pos)
	enemy.blow(foe, enemy.stat("damage"))


## Flying to its target; a miner inside his mine is driven out by the ghost
## standing next to it.
func _search(enemy: Enemy, delta: float, reach: float) -> void:
	var to := target.grid_pos
	var d := enemy.grid_pos.distance_to(to)
	if target is Miner and (target as Miner).state == Miner.State.WORKING and d <= reach + 0.7:
		(target as Miner).drive_out(enemy)
		return
	if d <= reach * 0.75:
		enemy._set_moving(false)
		return
	_detour_roll -= delta
	if _detour == Vector2.INF and _detour_roll <= 0.0:
		_detour_roll = float(Config.GHOST["replan"])
		if d > 2.0 * float(Config.GHOST["detour_length"]) and randf() < float(Config.GHOST["detour_chance"]):
			_detour = _open_near(enemy, enemy.grid_pos + (to - enemy.grid_pos).normalized().rotated(randf_range(-1.2, 1.2)) * float(Config.GHOST["detour_length"]))
	if _detour != Vector2.INF:
		if enemy.grid_pos.distance_to(_detour) < 1.0 or _detour == enemy.grid_pos:
			_detour = Vector2.INF
		else:
			to = _detour
	_fly_to(enemy, to, delta)


func on_damaged(_enemy: Enemy, source: Node) -> void:
	if is_instance_valid(source) and source.is_in_group("melee_defenders"):
		_hurt_by = source  # (a tower it can't get at is ignored)


## Flies towards `to` (grid), the way plotted again now and then.
func _fly_to(enemy: Enemy, to: Vector2, delta: float) -> void:
	if enemy.grid_pos.distance_to(to) < 0.1:
		enemy._set_moving(false)
		return
	_replan -= delta
	if _goal == Vector2.INF or _goal.distance_to(to) > 0.6 or _replan <= 0.0:
		_goal = to
		_replan = float(Config.GHOST["replan"])
		var pts := enemy.game.world.pathing.ghost_path(enemy.current_tile(), Vector2i(to.round()))
		if pts.size() > 1:
			pts.remove_at(0)  # (the tile it is on)
		else:
			pts.clear()
		if not pts.is_empty():
			pts.remove_at(pts.size() - 1)
		pts.append(to)
		enemy.follow(pts)
	if enemy.walk_own(delta):
		enemy._set_moving(false)


## The open tile nearest `p` (looking a few tiles round), else where it is.
func _open_near(enemy: Enemy, p: Vector2) -> Vector2:
	var pathing := enemy.game.world.pathing
	var t := Vector2i(p.round())
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if pathing.ghost_open(t + Vector2i(dx, dy)):
					return Vector2(t + Vector2i(dx, dy))
	return enemy.grid_pos


## A place 3 to 6 tiles (lurk_step) away to stroll to, not farther than lurk_leash
## from its target; if none is found, one back towards them.
func _lurk_point(enemy: Enemy) -> Vector2:
	var gc: Dictionary = Config.GHOST
	var step: Array = gc["lurk_step"]
	var pathing := enemy.game.world.pathing
	for i in 10:
		var p := enemy.grid_pos + Vector2.from_angle(randf() * TAU) * randf_range(float(step[0]), float(step[1]))
		if pathing.ghost_open(Vector2i(p.round())) and p.distance_to(target.grid_pos) <= float(gc["lurk_leash"]):
			return p
	return _open_near(enemy, enemy.grid_pos.move_toward(target.grid_pos, float(step[1])))


## A place a roam_leg or so away to drift to.
func _roam_point(enemy: Enemy) -> Vector2:
	var leg := float(Config.GHOST["roam_leg"])
	for i in 8:
		var p := enemy.grid_pos + Vector2.from_angle(randf() * TAU) * leg * randf_range(0.6, 1.0)
		if enemy.game.world.pathing.ghost_open(Vector2i(p.round())):
			return p
	return enemy.grid_pos
