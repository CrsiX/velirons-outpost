class_name VulturePack
extends RefCounted
## A pack of vultures (docs/enemies-design.md §15d; Config.VULTURES): the
## corpse it is after and what it does together. SEEK: its birds fly to its
## target and eat it; gone, the pack takes the edible corpse nearest to it.
## None left: SEARCH for search_time s, then LEAVE for the map edge nearest
## by flight. Its birds (VultureBehavior) ask it every frame; it thinks once
## per frame.

enum Mode { SEEK, SEARCH, LEAVE }

var game: Game
var members: Array[Enemy] = []
var target: Corpse = null
var mode := Mode.SEEK
## Where it leaves the map (LEAVE).
var exit := Vector2i(-1, -1)
var _search_left := 0.0
var _scan := 0.0
var _frame := -1


func _init(p_game: Game, p_target: Corpse = null) -> void:
	game = p_game
	target = p_target


## A corpse vultures go for: still lying, not sinking, not of a kind they
## leave alone (a vulture's, the wrathwood's log). The campaign's fallen too.
static func edible(c) -> bool:
	if not is_instance_valid(c) or c.is_queued_for_deletion():
		return false
	var corpse := c as Corpse
	return not corpse.sinking and not (Config.VULTURES["never_eats"] as Array).has(corpse.kind) and corpse.game.corpses.corpses.has(corpse)


## Its birds still alive.
func alive() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in members:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	return out


## The middle of its living birds (grid).
func middle() -> Vector2:
	var birds := alive()
	if birds.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for e in birds:
		sum += e.grid_pos
	return sum / float(birds.size())


## Its bird number `e` (0 first), for spreading them round a corpse.
func index_of(e: Enemy) -> int:
	return maxi(members.find(e), 0)


func think(delta: float) -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	var vc: Dictionary = Config.VULTURES
	match mode:
		Mode.SEEK:
			if not edible(target):
				target = nearest(middle())
				if target == null:
					mode = Mode.SEARCH
					_search_left = float(vc["search_time"])
					_scan = 0.0
		Mode.SEARCH:
			_search_left -= delta
			_scan -= delta
			if _scan <= 0.0:
				_scan = 0.5
				target = nearest(middle())
				if target != null:
					mode = Mode.SEEK
					return
			if _search_left <= 0.0:
				mode = Mode.LEAVE
				exit = game.world.pathing.sky_edge(Vector2i(middle().round()))
				var birds := alive()
				if not birds.is_empty():
					var v := birds[0].target_village
					if is_instance_valid(v):
						v.events.debug("vultures find nothing more to eat and leave (%s)" % ", ".join(birds.map(func(e: Enemy) -> String: return e.label())))


## The edible corpse nearest `p`, or null.
func nearest(p: Vector2) -> Corpse:
	var best: Corpse = null
	var best_d := INF
	for c in game.corpses.corpses:
		if edible(c) and c.grid_pos.distance_squared_to(p) < best_d:
			best_d = c.grid_pos.distance_squared_to(p)
			best = c
	return best
