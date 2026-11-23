class_name Corpse
extends Node2D
## What's left of a killed enemy. Lies where it fell until a gatherer carries
## it home, it rots away (CORPSE_LIFETIME; later near a village holding Grave
## salt), or the wave after next is finished.
## On deep water it sinks: it fades over AQUA sink_time and is gone (nobody
## can gather it; a necromancer can still raise it until then).
## A battlefield's fallen soldier (scenario 6, `fallen`) lies until it is
## buried: it never rots or is cleared away, gatherers carry it to a graveyard
## (Graveyard) for nothing but its grave, and raised it is a skeleton.
## A ghoul's corpse (docs/enemies-design.md §10.17) is downed while a living
## ghoul stays within wake_range: it twitches, and when its hidden timer runs
## out it rises (Waves.rise_ghoul). Laid to rest (`at_rest`), it never does.

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
## A ghoul's: times it rose already, the max HP of its next life, and whether
## it is laid to rest (never rises: holy kill, or rise_max below min_hp).
var rises := 0
var rise_max := 0.0
var at_rest := false
## A ghoul's: a living ghoul is near and the wake timer runs (it twitches; on
## a co-op client set by the host).
var downed := false
var _wake_left := 0.0
var _scan := 0.0
## The living ghoul keeping it downed.
var _waker: Enemy = null
## Seconds to the next twitch, and what is left of the one shown now.
var _twitch_in := 0.0
var _twitch_left := 0.0


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
	else:
		time_left = Config.CORPSE_LIFETIME * (1.0 + _salt())


## The Grave salt of the village nearest to it (0: none there).
func _salt() -> float:
	var best: Village = null
	for v: Village in game.villages:
		if best == null or Vector2(v.center).distance_to(grid_pos) < Vector2(best.center).distance_to(grid_pos):
			best = v
	return best.relic_bonus("corpse_life") if best != null else 0.0


## Makes it one of the battlefield's fallen (raised: a skeleton, its `kind`).
func make_fallen() -> void:
	fallen = true
	Art.apply(_sprite, "corpse_fallen" if randf() < 0.5 else "corpse_fallen_2")  # (Fiona's blue, Rhodri's crimson)


func tile() -> Vector2i:
	return Vector2i(grid_pos.round())


func spec() -> Dictionary:
	return Config.ENEMIES[kind]


func _process(delta: float) -> void:
	_twitch(delta)
	if game.is_client:
		return
	if rise_max > 0.0 and not at_rest and not sinking and not fallen:
		_wake_tick(delta)
		if not is_instance_valid(self) or is_queued_for_deletion():
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


# --- a ghoul's corpse ------------------------------------------------------------------------------

## A living ghoul within wake_range (null: none). `prefer` first, if it still is.
func waker(prefer: Enemy = null) -> Enemy:
	var r := float(spec()["wake_range"])
	if prefer != null and is_instance_valid(prefer) and _wakes(prefer, r):
		return prefer
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy and _wakes(n as Enemy, r):
			return n
	return null


func _wakes(e: Enemy, r: float) -> bool:
	return e.kind == kind and not e.dead and not e.raised and not e.wild() and e.grid_pos.distance_to(grid_pos) <= r


## Host: downed while a living ghoul is near (a fresh, jittered timer each time
## it starts; slower in a High Priest's aura), still when none is; rises when
## the timer runs out.
func _wake_tick(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0 or (downed and (not is_instance_valid(_waker) or _waker.dead)):
		_scan = 0.25
		_waker = waker(_waker if is_instance_valid(_waker) else null)
		if _waker == null:
			if downed:
				_set_downed(false)
		elif not downed:
			var j: Array = spec()["wake_jitter"]
			_wake_left = float(spec()["wake_time"]) * randf_range(float(j[0]), float(j[1]))
			_set_downed(true)
	if not downed:
		return
	_wake_left -= delta / Combat.necro_slow(game, grid_pos)
	if _wake_left <= 0.0:
		game.waves.rise_ghoul(self, _waker)


func _set_downed(on: bool) -> void:
	downed = on
	_twitch_in = randf_range(0.2, 0.8)
	if not on:
		_end_twitch()


## While downed: now and then the twitch frame for a moment, with a jolt.
func _twitch(delta: float) -> void:
	if not downed:
		return
	if _twitch_left > 0.0:
		_twitch_left -= delta
		if _twitch_left <= 0.0:
			_end_twitch()
		return
	_twitch_in -= delta
	if _twitch_in > 0.0:
		return
	_twitch_in = randf_range(0.6, 2.0)
	_twitch_left = randf_range(0.2, 0.4)
	Art.apply(_sprite, "corpse_%s_twitch" % str(spec()["art"]))
	_sprite.position = Vector2(randf_range(-1.5, 1.5), -randf_range(0.5, 2.0))
	_sprite.rotation = randf_range(-0.08, 0.08)


func _end_twitch() -> void:
	_twitch_left = 0.0
	Art.apply(_sprite, "corpse_" + str(spec()["art"]))
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0


## Co-op client: the host says whether it is downed.
func net_downed(on: bool) -> void:
	if on != downed:
		_set_downed(on)
