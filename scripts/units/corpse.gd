class_name Corpse
extends Node2D
## What's left of a killed enemy. Lies where it fell until a gatherer carries
## it home, it rots away (CORPSE_LIFETIME), or the wave after next is finished.

var game: Game
var kind := "goblin"
var wave := 0
var grid_pos := Vector2.ZERO
var time_left := Config.CORPSE_LIFETIME
## Gatherer currently heading for this corpse (reserves it).
var claimed_by: Node = null
## Numbered across all kinds: "corpse 12".
var uid := 0
## Network id (Game.register).
var nid := 0


func label() -> String:
	return "corpse %d" % uid


func setup(p_game: Game, p_kind: String, p_wave: int, at: Vector2) -> void:
	game = p_game
	kind = p_kind
	wave = p_wave
	grid_pos = at
	position = Iso.to_world(at)
	var s := Art.sprite("corpse_" + Config.ENEMIES[kind]["art"])
	s.flip_h = randf() < 0.5
	add_child(s)


func tile() -> Vector2i:
	return Vector2i(grid_pos.round())


func spec() -> Dictionary:
	return Config.ENEMIES[kind]


func _process(delta: float) -> void:
	if game.is_client:
		return
	time_left -= delta
	if time_left < 10.0:
		modulate.a = clampf(time_left / 10.0, 0.0, 1.0)
	if time_left <= 0.0:
		game.log_all(EventLog.Level.DEBUG, "%s rotted away" % label())
		game.corpses.remove(self)
