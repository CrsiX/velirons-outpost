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
## Rats left over once the rest of the wave is gone get RAT_WAVE_LINGER
## seconds; then `rats_leave` is set and they all vanish (RatBehavior).
var rat_deadline := -1.0
var rats_leave := false
var _rat_scan := 0.0


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
	rat_deadline = -1.0
	rats_leave = false
	wave += 1
	countdown = -1.0
	var n := wave
	var hp_scale := pow(Config.WAVE_HP_GROWTH, n - 1)
	game.world.wake_lairs(n)
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
## kinds arrive mixed, from up to wave_spawn_points(n) of `spawns` plus the
## awake lairs of its slice (each one more spawn point, sending its theme).
func _share(n: int, hp_scale: float, spawns: Array[Vector2i], target: Village) -> Array:
	var points := spawns.duplicate() if not spawns.is_empty() else game.map.edge_spawns.duplicate()
	points.shuffle()
	points = points.slice(0, mini(Config.wave_spawn_points(n), points.size()))
	var pool: Array = []  # (untyped: edge tiles and lairs)
	pool.append_array(points)
	var rat_pool: Array = pool.duplicate()
	for l in game.world.awake_lairs(int(game.map.villages[target.id].get("slice", 0))):
		pool.append(l)
		if (l.theme()["kinds"] as Array).has("rat"):
			rat_pool.append(l)
	var kinds := _kinds(n)
	kinds.shuffle()
	var out := []
	for i in kinds.size():
		out.append(_spec(kinds[i], pool[i % pool.size()], hp_scale, target))
	_theme_lairs(out, n)
	# Rat packs: whole packs, each from one spawn, the rats a moment apart.
	var rp: Dictionary = Config.RAT_PACKS
	if n >= int(rp["from_wave"]) and _rng.randf() < float(rp["chance"]):
		var packs := _rng.randi_range(int(rp["packs"][0]), int(rp["packs"][1])) + (n - int(rp["from_wave"])) / int(rp["more_every"])
		for p in packs:
			var at = rat_pool[_rng.randi() % rat_pool.size()]
			var pack := []
			for k in _rng.randi_range(int(rp["size"][0]), int(rp["size"][1])):
				var spec := _spec("rat", at, hp_scale, target)
				if k > 0:
					spec["gap"] = float(rp["gap"])
				pack.append(spec)
			var pos := _rng.randi_range(0, out.size())
			while pos < out.size() and out[pos].has("gap"):
				pos += 1  # (never into the middle of another pack)
			for k in pack.size():
				out.insert(pos + k, pack[k])
	return out


## A queue entry: `at` is a spawn tile or a lair (its door).
func _spec(kind: String, at, hp_scale: float, target: Village) -> Dictionary:
	var spec := {"kind": kind, "spawn": at, "hp_scale": hp_scale, "village": target}
	if at is MonsterLair:
		spec["spawn"] = (at as MonsterLair).door()
		spec["lair"] = at
	return spec


## Lairs send only their theme's kinds: a lair's entry with another kind
## swaps it with an edge entry of a fitting kind, else becomes one.
func _theme_lairs(out: Array, n: int) -> void:
	for spec in out:
		if not spec.has("lair"):
			continue
		var fits: Array[String] = (spec["lair"] as MonsterLair).kinds_for(n)
		if fits.has(spec["kind"]):
			continue
		var swap = null
		for other in out:
			if not other.has("lair") and fits.has(other["kind"]):
				swap = other
				break
		if swap != null:
			var k: String = swap["kind"]
			swap["kind"] = spec["kind"]
			spec["kind"] = k
		else:
			spec["kind"] = fits[_rng.randi() % fits.size()]


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
	_check_rats(delta)
	if _queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn(_queue.pop_front())
		# Each village at its own pace; the rats of a pack follow each other closely.
		var next: Dictionary = _queue[0] if not _queue.is_empty() else {}
		_spawn_timer = float(next["gap"]) if next.has("gap") else Config.WAVE_SPAWN_GAP / game.villages.size()


## Once no enemy but rats is left (and only rats are still to come), the rats
## get RAT_WAVE_LINGER seconds; then they all vanish.
func _check_rats(delta: float) -> void:
	if rats_leave:
		return
	if rat_deadline >= 0.0:
		rat_deadline -= delta
		if rat_deadline <= 0.0:
			rats_leave = true
		return
	_rat_scan -= delta
	if _rat_scan > 0.0 or _alive <= 0:
		return
	_rat_scan = 0.5
	if _queue.any(func(sp: Dictionary) -> bool: return sp.get("kind", "") != "rat"):
		return
	var others := false
	var rats := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or e.behavior is CampBehavior:
			continue
		if e.kind == "rat":
			rats = true
		else:
			others = true
			break
	if rats and not others:
		rat_deadline = Config.RAT_WAVE_LINGER


func _spawn(spec: Dictionary) -> Enemy:
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
	var lair = spec.get("lair")
	g.from_lair = is_instance_valid(lair) and (lair as MonsterLair).woke_at == wave
	_add(g, target)
	g.target_village.events.debug("%s appears at %s" % [g.label(), str(route[0])])
	return g


func _add(g: Enemy, target: Village) -> void:
	g.uid = game.next_id(g.kind)
	g.nid = game.register(g)
	g.target_village = target
	g.killed.connect(_on_enemy_killed)
	g.reached_gate.connect(_on_enemy_reached_gate)
	g.vanished.connect(func(e: Enemy) -> void: _enemy_gone(e))
	game.world.objects.add_child(g)
	_alive += 1


## Debug (Commands._debug): an enemy of `kind` at a random edge spawn of
## `target`, now, wave or no wave. It doesn't count for the wave.
func debug_spawn(kind: String, target: Village) -> Enemy:
	var points: Array = target.home_spawns if game.villages.size() > 1 and not target.home_spawns.is_empty() else game.map.edge_spawns
	if points.is_empty():
		return null
	var g := _spawn(_spec(kind, points[_rng.randi() % points.size()], pow(Config.WAVE_HP_GROWTH, maxi(wave, 1) - 1), target))
	_alive -= 1
	_uncounted[g] = true
	return g


## Villages whose first raised dead are logged already (at Info; later: Debug).
var _raise_logged := {}


## A necromancer's spell is done: the corpse rises as its old kind, with a
## share of its HP draining away (Enemy.make_raised), and walks the roads to
## the necromancer's village. It counts as alive for the wave.
func raise_corpse(c: Corpse, by: Enemy) -> Enemy:
	if not game.corpses.corpses.has(c):
		return null
	var target: Village = by.target_village if is_instance_valid(by.target_village) else game.villages[0]
	var pathing := game.world.pathing
	var road := pathing.nearest_road(c.tile())
	var field := target.id if game.villages.size() > 1 and pathing.enemy_distance(road, target.id) < Pathing.UNREACHABLE else -1
	var route := pathing.enemy_route(road, _rng, field)
	var g: Enemy = ENEMY_SCRIPT.new()
	g.setup(game, route, c.hp_scale, c.kind)
	g.wave = c.wave
	var pts := PackedVector2Array([c.grid_pos])
	pts.append_array(g.path)
	g.set_grid_pos(c.grid_pos)
	g.follow(pts)
	var spec: Dictionary = by.spec()
	g.make_raised(float(spec["raise_hp"]), float(spec["raise_decay"]))
	game.corpses.remove(c)
	_add(g, target)
	var first := not _raise_logged.has(target.id)
	_raise_logged[target.id] = true
	target.events.add(EventLog.Level.INFO if first else EventLog.Level.DEBUG, "A necromancer raised a dead %s!" % str(g.spec()["name"]).to_lower() if first else "%s raised %s from the dead" % [by.label(), g.label()])
	Combat.burst(game, "warp", g.position + Vector2(0, -16), 0.8)
	return g


func _on_enemy_killed(g: Enemy) -> void:
	# The kill pays whoever made it (tower, elemental, hero); else the village it attacked.
	var gold := Config.enemy_stat_int(g.kind, "gold_on_kill")
	if g.raised:  # (its gold was paid once already; drained away: nothing)
		gold = 0 if g.decayed else floori(gold * float(Config.ENEMIES["necromancer"]["raise_gold"]))
	var v := game.village_of(g.killer)
	if v == null:
		v = g.target_village if is_instance_valid(g.target_village) else game.villages[0]
	if g.decayed:
		v.events.debug("%s crumbles to dust" % g.label())
	else:
		v.economy.add("gold", gold)
		v.events.debug("killed %s (by %s, +%d gold)" % [g.label(), game.who(g.killer), gold])
		if gold > 0:
			game.world.float_text("+%d {gold}" % gold, g.position + Vector2(0, -50), Color("c9a24a"))
			Sfx.play("coin")
	if g.spec().get("corpse", true):
		var c := game.corpses.spawn(g.kind, g.wave, g.grid_pos)
		c.extra_gold = g.loot_gold
		c.hp_scale = g.hp_scale
		c.revivable = c.revivable and not g.raised
	_enemy_gone(g)


func _on_enemy_reached_gate(g: Enemy) -> void:
	game.on_enemy_reached_gate(g)
	_enemy_gone(g)


## Debug enemies (debug_spawn), which don't count for the wave.
var _uncounted := {}


func _enemy_gone(g: Enemy = null) -> void:
	if _uncounted.erase(g):
		changed.emit()
		return
	_alive -= 1
	if not in_progress() and wave > 0:
		rat_deadline = -1.0
		rats_leave = false
		countdown = Config.WAVE_BUFFER
		game.log_all(EventLog.Level.INFO, "Wave %d is over" % wave)
		wave_finished.emit(wave)
	changed.emit()
