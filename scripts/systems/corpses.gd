class_name Corpses
extends Node
## Registry of enemy corpses. Killing an enemy pays `gold_on_kill` at once and
## leaves a corpse; gatherers bring corpses home for `gold_on_collect` and
## `food_on_collect`. Corpses rot after CORPSE_LIFETIME, and all corpses of
## wave N disappear when wave N + 1 is finished.

signal changed

const CORPSE_SCRIPT := preload("res://scripts/units/corpse.gd")

var game: Game
var corpses: Array[Corpse] = []


func setup(p_game: Game) -> void:
	game = p_game
	game.waves.wave_finished.connect(func(n: int) -> void: clear_wave(n - 1))


func spawn(kind: String, wave: int, at: Vector2) -> Corpse:
	var c: Corpse = CORPSE_SCRIPT.new()
	c.setup(game, kind, wave, at)
	c.uid = game.next_id("corpse")
	c.nid = game.register(c)
	game.log_all(EventLog.Level.DEBUG, "%s left behind (%s)" % [c.label(), kind])
	game.world.decals.add_child(c)  # flat on the ground, under walking units
	corpses.append(c)
	changed.emit()
	return c


func remove(c: Corpse) -> void:
	if not corpses.has(c):
		return
	corpses.erase(c)
	c.queue_free()
	changed.emit()


func clear_wave(wave: int) -> void:
	var n := 0
	for c in corpses.duplicate():
		if c.wave <= wave:
			remove(c)
			n += 1
	if n > 0:
		game.log_all(EventLog.Level.DEBUG, "%d corpse%s of wave %d and older cleared away" % [n, "" if n == 1 else "s", wave])


## Safe = no living enemy within CORPSE_SAFE_RADIUS.
func is_safe(c: Corpse) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var g := node as Enemy
		if not g.dead and g.grid_pos.distance_to(c.grid_pos) < Config.CORPSE_SAFE_RADIUS:
			return false
	return true


func available() -> Array[Corpse]:
	return corpses.filter(func(c: Corpse) -> bool: return c.claimed_by == null and is_safe(c))


func count() -> int:
	return corpses.size()
