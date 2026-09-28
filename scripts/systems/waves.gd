class_name Waves
extends Node
## Endless enemy waves. The first wave starts FIRST_WAVE_DELAY seconds into the
## game; every later wave starts WAVE_BUFFER seconds after the previous one is
## completely gone. The countdown can be skipped for bonus gold.
## Co-op: one wave for the whole game. Every village gets its own share (the
## single-player wave) from its home edge, plus WAVE_EXTRA_PER_PLAYER x P of a
## village's wave from random edge spawns, for the standing village nearest to
## where they spawn. Shares of fallen villages go to the nearest standing one.

signal changed
signal wave_started(n: int)
## Emitted when the last enemy of wave `n` is gone.
signal wave_finished(n: int)

const ENEMY_SCRIPT := preload("res://scripts/units/enemy.gd")

var game: Game
var wave := 0
## Countdown to the next wave; negative while a wave is running.
var countdown := -1.0
## Tests / debugging: the countdown stands still (calling a wave still works).
var hold := false
## Co-op client: [wave, countdown, in progress, enemies left, can call].
var _net: Array = [0, 0.0, false, 0, true]
var _queue: Array[Dictionary] = []
var _spawn_timer := 0.0
var _alive := 0
var _rng := RandomNumberGenerator.new()


func setup(p_game: Game) -> void:
	game = p_game
	_rng.randomize()
	countdown = Config.FIRST_WAVE_DELAY


func in_progress() -> bool:
	if game and game.is_client:
		return _net[2]
	return not _queue.is_empty() or _alive > 0


func can_call() -> bool:
	if game and game.is_client:
		return _net[4]
	return not in_progress()


## Enemies alive plus those of the current wave still to come.
func enemies_left() -> int:
	if game and game.is_client:
		return _net[3]
	return _alive + _queue.size()


## Co-op client: the wave as the host has it.
func set_net_state(p_wave: int, p_countdown: float, p_in_progress: bool, p_left: int, p_can_call: bool) -> void:
	var changed_now: bool = p_wave != wave or p_in_progress != _net[2] or p_left != _net[3]
	wave = p_wave
	countdown = p_countdown
	_net = [p_wave, p_countdown, p_in_progress, p_left, p_can_call]
	if changed_now:
		changed.emit()


func early_call_bonus() -> int:
	return int(maxf(countdown, 0.0) * Config.EARLY_CALL_GOLD_PER_SECOND)


## Starts the next wave now, skipping the countdown. Every village gets the
## early-call bonus; `caller` (the village that called) is named in the log.
func call_next(caller: Village = null) -> void:
	if not can_call():
		return
	var bonus := early_call_bonus()
	var who := caller.village_name if caller and game.villages.size() > 1 else ""
	for v in game.villages:
		if bonus > 0:
			v.economy.add("gold", bonus)
			v.toast("Called early: +%d gold" % bonus, Color("c9a24a"))
		if who != "":
			v.events.info("%s called wave %d early: +%d gold" % [who, wave + 1, bonus])
		else:
			v.events.debug("call wave %d early (+%d gold)" % [wave + 1, bonus])
	_start_wave()


func _start_wave() -> void:
	wave += 1
	countdown = -1.0
	var n := wave
	var hp_scale := pow(Config.WAVE_HP_GROWTH, n - 1)
	if game.villages.size() == 1:
		_queue.append_array(_share(n, hp_scale, game.map.edge_spawns, game.villages[0]))
	else:
		var shares: Array = []
		for v in game.villages:
			shares.append(_share(n, hp_scale, v.home_spawns, v))
		shares.append(_extra(n, hp_scale))
		# Interleaved, so every village's share arrives at the same time.
		var i := 0
		while shares.any(func(sh: Array) -> bool: return i < sh.size()):
			for sh in shares:
				if i < sh.size():
					_queue.append(sh[i])
			i += 1
	_spawn_timer = 0.5
	game.log_all(EventLog.Level.INFO, "Wave %d begins: %d enemies" % [n, _queue.size()])
	Sfx.play("horn", 0.0)
	wave_started.emit(wave)
	changed.emit()


## One village's share of wave `n`: Config.wave_composition, shuffled so the
## kinds arrive mixed, from up to wave_spawn_points(n) of `spawns`.
func _share(n: int, hp_scale: float, spawns: Array[Vector2i], target: Village) -> Array:
	var points := spawns.duplicate() if not spawns.is_empty() else game.map.edge_spawns.duplicate()
	points.shuffle()
	points = points.slice(0, mini(Config.wave_spawn_points(n), points.size()))
	var kinds := _kinds(n)
	kinds.shuffle()
	var out := []
	for i in kinds.size():
		out.append({"kind": kinds[i], "spawn": points[i % points.size()], "hp_scale": hp_scale, "village": target})
	return out


## Co-op extra: WAVE_EXTRA_PER_PLAYER x P of one village's wave, spawning at
## random edge roads; the target is picked when each one spawns.
func _extra(n: int, hp_scale: float) -> Array:
	var count := roundi(Config.wave_size(n) * Config.WAVE_EXTRA_PER_PLAYER * game.villages.size())
	var kinds := _kinds(n)
	var spawns := game.map.edge_spawns
	var out := []
	for i in count:
		out.append({"kind": kinds[_rng.randi() % kinds.size()], "spawn": spawns[_rng.randi() % spawns.size()], "hp_scale": hp_scale, "village": null})
	return out


func _kinds(n: int) -> Array[String]:
	var kinds: Array[String] = []
	var comp := Config.wave_composition(n)
	for kind in comp:
		for i in comp[kind]:
			kinds.append(kind)
	return kinds


func _process(delta: float) -> void:
	if game.is_client:
		return
	if countdown > 0.0:
		if hold:
			return
		countdown -= delta
		if countdown <= 0.0:
			_start_wave()
		return
	if _queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = Config.WAVE_SPAWN_GAP / game.villages.size()  # each village at its own pace
		_spawn(_queue.pop_front())


func _spawn(spec: Dictionary) -> void:
	var target: Village = spec.get("village")
	var coop := game.villages.size() > 1
	if target == null or (coop and target.fallen):
		target = game.nearest_standing_village(spec["spawn"])
	if target == null:
		target = game.villages[0]
	# Single player: the nearest gate, as ever. Co-op: the target village's gates.
	var field := target.id if coop and game.world.pathing.enemy_distance(spec["spawn"], target.id) < Pathing.UNREACHABLE else -1
	var route := game.world.pathing.enemy_route(spec["spawn"], _rng, field)
	var g: Enemy = ENEMY_SCRIPT.new()
	g.setup(game, route, spec["hp_scale"], spec.get("kind", Config.WAVE_FILLER))
	g.wave = wave
	g.uid = game.next_id(g.kind)
	g.nid = game.register(g)
	g.target_village = target
	g.target_village.events.debug("%s appears at %s" % [g.label(), str(route[0])])
	g.killed.connect(_on_enemy_killed)
	g.reached_gate.connect(_on_enemy_reached_gate)
	game.world.objects.add_child(g)
	_alive += 1


func _on_enemy_killed(g: Enemy) -> void:
	# The kill pays whoever made it (tower, elemental, hero); else the village it attacked.
	var gold := Config.enemy_stat_int(g.kind, "gold_on_kill")
	var v := game.village_of(g.killer)
	if v == null:
		v = g.target_village if is_instance_valid(g.target_village) else game.villages[0]
	v.economy.add("gold", gold)
	v.events.debug("killed %s (by %s, +%d gold)" % [g.label(), game.who(g.killer), gold])
	game.world.float_text("+%d gold" % gold, g.position + Vector2(0, -50), Color("c9a24a"))
	Sfx.play("coin")
	game.corpses.spawn(g.kind, g.wave, g.grid_pos)
	_enemy_gone()


func _on_enemy_reached_gate(g: Enemy) -> void:
	game.on_enemy_reached_gate(g)
	_enemy_gone()


func _enemy_gone() -> void:
	_alive -= 1
	if not in_progress() and wave > 0:
		countdown = Config.WAVE_BUFFER
		game.log_all(EventLog.Level.INFO, "Wave %d is over" % wave)
		wave_finished.emit(wave)
	changed.emit()
