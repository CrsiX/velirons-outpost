class_name Waves
extends Node
## Endless enemy waves. The first wave starts FIRST_WAVE_DELAY seconds into the
## game; every later wave starts WAVE_BUFFER seconds after the previous one is
## completely gone. The countdown can be skipped for bonus gold.

signal changed
signal wave_started(n: int)
## Emitted when the last enemy of wave `n` is gone.
signal wave_finished(n: int)

const ENEMY_SCRIPT := preload("res://scripts/units/enemy.gd")

var game: Game
var wave := 0
## Countdown to the next wave; negative while a wave is running.
var countdown := -1.0
var _queue: Array[Dictionary] = []
var _spawn_timer := 0.0
var _alive := 0
var _rng := RandomNumberGenerator.new()


func setup(p_game: Game) -> void:
	game = p_game
	_rng.randomize()
	countdown = Config.FIRST_WAVE_DELAY


func in_progress() -> bool:
	return not _queue.is_empty() or _alive > 0


func can_call() -> bool:
	return not in_progress()


## Enemies alive plus those of the current wave still to come.
func enemies_left() -> int:
	return _alive + _queue.size()


func early_call_bonus() -> int:
	return int(maxf(countdown, 0.0) * Config.EARLY_CALL_GOLD_PER_SECOND)


## Starts the next wave now, skipping the countdown.
func call_next() -> void:
	if not can_call():
		return
	var bonus := early_call_bonus()
	if bonus > 0:
		game.economy.add("gold", bonus)
		game.hud.toast("Called early: +%d gold" % bonus, Color("c9a24a"))
	_start_wave()


func _start_wave() -> void:
	wave += 1
	countdown = -1.0
	var n := wave
	var spawns := game.map.edge_spawns.duplicate()
	spawns.shuffle()
	spawns = spawns.slice(0, mini(Config.wave_spawn_points(n), spawns.size()))
	var hp_scale := pow(Config.WAVE_HP_GROWTH, n - 1)
	# Kinds from Config.wave_composition, shuffled so they arrive mixed.
	var kinds: Array[String] = []
	var comp := Config.wave_composition(n)
	for kind in comp:
		for i in comp[kind]:
			kinds.append(kind)
	kinds.shuffle()
	for i in kinds.size():
		_queue.append({"kind": kinds[i], "spawn": spawns[i % spawns.size()], "hp_scale": hp_scale})
	_spawn_timer = 0.5
	Sfx.play("horn", 0.0)
	wave_started.emit(wave)
	changed.emit()


func _process(delta: float) -> void:
	if countdown > 0.0:
		countdown -= delta
		if countdown <= 0.0:
			_start_wave()
		return
	if _queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = Config.WAVE_SPAWN_GAP
		_spawn(_queue.pop_front())


func _spawn(spec: Dictionary) -> void:
	var route := game.world.pathing.enemy_route(spec["spawn"], _rng)
	var g: Enemy = ENEMY_SCRIPT.new()
	g.setup(game, route, spec["hp_scale"], spec.get("kind", Config.WAVE_FILLER))
	g.wave = wave
	g.killed.connect(_on_enemy_killed)
	g.reached_gate.connect(_on_enemy_reached_gate)
	game.world.objects.add_child(g)
	_alive += 1


func _on_enemy_killed(g: Enemy) -> void:
	var gold := Config.enemy_stat_int(g.kind, "gold_on_kill")
	game.economy.add("gold", gold)
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
		wave_finished.emit(wave)
	changed.emit()
