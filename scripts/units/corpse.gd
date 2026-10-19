class_name Corpse
extends Node2D
## What's left of a killed enemy. Lies where it fell until a gatherer carries
## it home, it rots away (CORPSE_LIFETIME), or the wave after next is finished.
## On deep water it sinks: it fades over AQUA sink_time and is gone (nobody
## can gather it; a necromancer can still raise it until then).
## A battlefield's fallen soldier (scenario 6, `fallen`) lies until it is
## buried: it never rots or is cleared away, gatherers carry it to a graveyard
## (Graveyard) for nothing but its grave, and raised it is a skeleton.

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
## Gold a thief stole, paid out with the corpse.
var extra_gold := 0
## The HP factor of its wave (a raised enemy keeps it).
var hp_scale := 1.0
## Can a necromancer raise it? (Not a raised enemy's, nor a necromancer's.)
var revivable := true
## The necromancer raising it right now.
var raising_by: Node = null
## One of the battlefield's fallen (make_fallen): buried in a graveyard, never rots.
var fallen := false
## Sinking on deep water (see _process).
var sinking := false
var _sink_total := 1.0
var _sprite: Sprite2D


func label() -> String:
	return "corpse %d" % uid


func setup(p_game: Game, p_kind: String, p_wave: int, at: Vector2) -> void:
	game = p_game
	kind = p_kind
	wave = p_wave
	grid_pos = at
	position = Iso.to_world(at)
	revivable = Config.ENEMIES[kind].get("revivable", true)
	var s := Art.sprite("corpse_" + Config.ENEMIES[kind]["art"])
	s.flip_h = randf() < 0.5
	add_child(s)
	_sprite = s
	if game.map and game.map.is_deep(tile()):
		sinking = true
		_sink_total = float(Config.AQUA["sink_time"])
		time_left = _sink_total


## Makes it one of the battlefield's fallen (raised: a skeleton, its `kind`).
func make_fallen() -> void:
	fallen = true
	Art.apply(_sprite, "corpse_fallen" if randf() < 0.5 else "corpse_fallen_2")  # (Fiona's blue, Rhodri's crimson)


func tile() -> Vector2i:
	return Vector2i(grid_pos.round())


func spec() -> Dictionary:
	return Config.ENEMIES[kind]


func _process(delta: float) -> void:
	if game.is_client:
		return
	if sinking:
		time_left -= delta
		var k := clampf(time_left / _sink_total, 0.0, 1.0)
		modulate.a = k
		_sprite.position.y = (1.0 - k) * 10.0
		if time_left <= 0.0:
			game.log_all(EventLog.Level.DEBUG, "%s sank" % label())
			game.corpses.remove(self)
		return
	if not game.corpses.rot or fallen:
		return
	time_left -= delta
	if time_left < 10.0:
		modulate.a = clampf(time_left / 10.0, 0.0, 1.0)
	if time_left <= 0.0:
		game.log_all(EventLog.Level.DEBUG, "%s rotted away" % label())
		game.corpses.remove(self)
