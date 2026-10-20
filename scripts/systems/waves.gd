class_name Waves
extends Node
## Endless enemy waves. The first wave starts FIRST_WAVE_DELAY seconds into the
## game; every later wave starts WAVE_BUFFER seconds after the previous one is
## completely gone. The countdown can be skipped for bonus gold.
## Co-op: one wave for the whole game. Every village gets its own share (the
## single-player wave) from its home edge, plus WAVE_EXTRA_PER_PLAYER x P of a
## village's wave from random edge spawns, for the standing village nearest to
## where they spawn. Shares of fallen villages go to the nearest standing one.
## Water monsters (docs/aquatic-design.md §9) join a village's share only
## where they can reach it (Aqua.eligibility), from its water spawns.

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
## The tutorial: the player can't call a wave (the tutorial starts it).
var call_locked := false
## Scripted waves (the tutorial's, a scenario's), used up first:
## [{"kinds": {kind: count}, "spawn": tile}] (all from that road tile), or
## without "spawn": spread over "spawns" edge spawns (default: as many as a
## normal wave n uses), with "rat_packs": [sizes] (a pack from one spawn each);
## "lairs": true adds the awake lairs as spawn points (each sending its kinds).
var scripted: Array[Dictionary] = []
## Seconds from a wave's end to the next one (a scenario may set its own).
var buffer := Config.WAVE_BUFFER
## The last wave (a scenario's): after it no more waves come. 0: endless.
var last_wave := 0
## A scenario's rule: amphibians come from the water spawns only, never the edge.
var amphibians_from_water := false
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
## Per village id: Aqua.eligibility (worked out at the first wave).
var _aqua: Dictionary = {}
## Water kinds whose first one was logged already (once per game).
var _aqua_logged := {}
## Seconds that only water monsters have been left in this wave, and whether
## that was announced (AQUA warn_after; once per wave).
var _water_only := 0.0
var _water_warned := false
## Seconds that only water-bound ones (leviathan, octopus) have been left of
## this wave with none of them in a fight (AQUA leave_after).
var _water_idle := 0.0
var _water_scan := 0.0


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
	return not in_progress() and not call_locked and not all_done()


## A scenario's last wave is over: no more come.
func all_done() -> bool:
	return last_wave > 0 and wave >= last_wave and not in_progress()


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
			v.economy.add("gold", bonus, "call")
			v.toast("Called early: +%d gold" % bonus, Color("c9a24a"))
		if who != "":
			v.events.info("%s called wave %d early: +%d gold" % [who, wave + 1, bonus])
		else:
			v.events.debug("call wave %d early (+%d gold)" % [wave + 1, bonus])
	_start_wave()


## The next wave now, without the early-call bonus (the tutorial's wave 2).
func start_now() -> void:
	countdown = -1.0
	_start_wave()


func _start_wave() -> void:
	rat_deadline = -1.0
	rats_leave = false
	_water_only = 0.0
	_water_warned = false
	_water_idle = 0.0
	wave += 1
	countdown = -1.0
	var n := wave
	var hp_scale := pow(Config.WAVE_HP_GROWTH, n - 1)
	game.world.wake_lairs(n)
	if not scripted.is_empty():
		_queue.append_array(_scripted_wave(scripted.pop_front(), n, hp_scale))
	elif game.villages.size() == 1:
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
	var kinds := _kinds(n, target)
	kinds.shuffle()
	var out := []
	for i in kinds.size():
		out.append(_spec(kinds[i], pool[i % pool.size()], hp_scale, target))
	_theme_lairs(out, n)
	_water_spawns(out, target)
	# Rat packs: whole packs, each from one spawn, the rats a moment apart.
	var rp: Dictionary = Config.RAT_PACKS
	if n >= int(rp["from_wave"]) and _rng.randf() < float(rp["chance"]):
		var packs := _rng.randi_range(int(rp["packs"][0]), int(rp["packs"][1])) + (n - int(rp["from_wave"])) / int(rp["more_every"])
		for p in packs:
			_insert_pack(out, rat_pool[_rng.randi() % rat_pool.size()], _rng.randi_range(int(rp["size"][0]), int(rp["size"][1])), hp_scale, target)
	return out


## A scripted wave's queue (see `scripted`), for village 0.
func _scripted_wave(sw: Dictionary, n: int, hp_scale: float) -> Array:
	var target := game.villages[0]
	var out := []
	if sw.has("spawn"):
		for kind in sw["kinds"]:
			for i in int(sw["kinds"][kind]):
				out.append(_spec(kind, sw["spawn"], hp_scale, target))
		return out
	var points: Array = game.map.edge_spawns.duplicate()
	points.shuffle()
	points = points.slice(0, clampi(int(sw.get("spawns", Config.wave_spawn_points(n))), 1, maxi(points.size(), 1)))
	var kinds: Array[String] = []
	for kind in sw.get("kinds", {}):
		for i in int(sw["kinds"][kind]):
			kinds.append(kind)
	kinds.shuffle()
	var pool: Array = []  # (untyped: edge tiles and lairs)
	pool.append_array(points)
	if sw.get("lairs", false):
		pool.append_array(game.world.awake_lairs())
	for i in kinds.size():
		out.append(_spec(kinds[i], pool[i % pool.size()], hp_scale, target))
	_theme_lairs(out, n)
	for size in sw.get("rat_packs", []):
		_insert_pack(out, points[_rng.randi() % points.size()], int(size), hp_scale, target)
	_water_spawns(out, target)
	return out


## A pack of `size` rats from `at` into `out`, at a random place (never into
## the middle of another pack), the rats a moment apart.
func _insert_pack(out: Array, at, size: int, hp_scale: float, target: Village) -> void:
	var pack := []
	for k in size:
		var spec := _spec("rat", at, hp_scale, target)
		if k > 0:
			spec["gap"] = float(Config.RAT_PACKS["gap"])
		pack.append(spec)
	var pos := _rng.randi_range(0, out.size())
	while pos < out.size() and out[pos].has("gap"):
		pos += 1
	for k in pack.size():
		out.insert(pos + k, pack[k])


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


## The kinds of village `target`'s share of wave `n` (null: the co-op extra,
## no water monsters). Water kinds only if they can reach the village; then
## each kind's "chance" is rolled and its max count (Config.wave_max_count) applied (the rest go to
## the filler).
func _kinds(n: int, target: Village = null) -> Array[String]:
	var kinds: Array[String] = []
	var elig := aqua(target)
	var comp := Config.wave_composition(n, not elig.is_empty(), elig.keys())
	for kind: String in comp.keys():
		var mix: Dictionary = Config.WAVE_MIX.get(kind, {})
		var keep := int(comp[kind])
		if mix.has("chance") and _rng.randf() >= float(mix["chance"]):
			keep = 0
		if mix.has("max_count"):
			keep = mini(keep, Config.wave_max_count(kind, n))
		if keep < int(comp[kind]):
			comp[Config.WAVE_FILLER] = int(comp.get(Config.WAVE_FILLER, 0)) + int(comp[kind]) - keep
			if keep > 0:
				comp[kind] = keep
			else:
				comp.erase(kind)
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
	_check_water(delta)
	if _queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn(_queue.pop_front())
		# Each village at its own pace; the rats of a pack follow each other closely.
		var next: Dictionary = _queue[0] if not _queue.is_empty() else {}
		_spawn_timer = float(next["gap"]) if next.has("gap") else Config.WAVE_SPAWN_GAP / game.villages.size()


## Once nothing but water monsters is left of the wave (nothing more to
## come), the villages they came for hear about it after AQUA warn_after
## seconds, once per wave: the wave ends only when those are dead (or gone,
## _check_leave).
func _check_water(delta: float) -> void:
	if wave <= 0:
		return
	_water_scan -= delta
	if _water_scan > 0.0:
		return
	var step := 0.5 - _water_scan
	_water_scan = 0.5
	var left := _water_left()
	if left.is_empty() or not _queue.is_empty():
		_water_only = 0.0
		_water_idle = 0.0
		return
	_water_only += step
	if _check_leave(left, step) or _water_warned or _water_only < float(Config.AQUA["warn_after"]):
		return
	_water_warned = true
	var per: Dictionary = {}  # village -> kind names
	for e: Enemy in left:
		var v: Village = e.target_village if is_instance_valid(e.target_village) else game.villages[0]
		var names: Array = per.get(v, [])
		var n := str(e.spec()["name"]).to_lower()
		if not names.has(n):
			names.append(n)
		per[v] = names
	for v: Village in per:
		var what := ", ".join(per[v])
		v.events.important("Water monsters are still out there (%s). The wave ends only when they are dead: build towers by the water" % what)
		v.toast("Water monsters remain: %s" % what, Color("7ac8ff"))


## When the wave's last ones (`left`) are all water-bound (habitat "water":
## leviathan, octopus; no amphibian), none named (a scenario's boss) or on a
## post, and none of them has been in a fight (AquaBehavior.engaged) for AQUA
## leave_after s, they go back into the deep (Enemy.vanish: no corpse, no
## gold) and the wave can end. True when they went.
func _check_leave(left: Array[Enemy], step: float) -> bool:
	for e in left:
		var ab := e.behavior as AquaBehavior
		if e.habitat() != "water" or e.given_name != "" or e.post.x >= 0 or ab == null or ab.engaged(e):
			_water_idle = 0.0
			return false
	_water_idle += step
	if _water_idle < float(Config.AQUA["leave_after"]):
		return false
	_water_idle = 0.0
	for e in left:
		var v: Village = e.target_village if is_instance_valid(e.target_village) else game.villages[0]
		v.events.info("%s goes back into the deep" % e.label())
		e.vanish()
	return true


## The wave's living enemies if every one of them is a water monster (crab,
## siren, leviathan, octopus; not an arm, a camp guard, a wrathwood or a
## debug one), else [].
func _water_left() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or e.wild() or e.behavior is ArmBehavior or _uncounted.has(e):
			continue
		if e.habitat() == "land":
			return [] as Array[Enemy]
		out.append(e)
	return out


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
		if e.dead or e.wild():
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
	var kind: String = spec.get("kind", Config.WAVE_FILLER)
	var habitat := str(Config.ENEMIES[kind].get("habitat", "land"))
	var amph := habitat == "amphibian"
	var route: Array[Vector2i] = [spec["spawn"]]
	if habitat != "water":  # (water-bound monsters have no route: their behavior moves them)
		# Single player: the nearest gate, as ever. Co-op: the target village's gates.
		var field := target.id if coop and game.world.pathing.enemy_distance(spec["spawn"], target.id, amph) < Pathing.UNREACHABLE else -1
		route = game.world.pathing.enemy_route(spec["spawn"], _rng, field, amph)
	var g: Enemy = ENEMY_SCRIPT.new()
	g.setup(game, route, spec["hp_scale"], kind)
	if spec.has("name") or spec.has("art"):
		g.set_identity(str(spec.get("name", "")), str(spec.get("art", "")))
	if spec.has("hp_x"):  # (a scenario's boss)
		g.max_hp *= float(spec["hp_x"])
		g.hp = g.max_hp
	g.power = float(spec.get("power", 1.0))
	if habitat != "land" and not _aqua_logged.has(kind) and not _uncounted_next:
		_aqua_logged[kind] = true
		target.events.add(EventLog.Level.IMPORTANT if kind == "octopus" else EventLog.Level.INFO, str(Config.AQUA_FIRST.get(kind, "A %s comes out of the water!" % str(g.spec()["name"]).to_lower())))
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


## A scenario's extra enemies for the wave under way (they count for it):
## `count` of `kind` from road tile `tile`, at the end of its queue; `extra`
## goes into each one's queue entry ("name", "art": Enemy.set_identity;
## "hp_x": its HP times that, "power": its damage, Enemy.power).
func add_to_wave(kind: String, tile: Vector2i, count: int = 1, extra: Dictionary = {}) -> void:
	var hp_scale := pow(Config.WAVE_HP_GROWTH, maxi(wave, 1) - 1)
	for i in count:
		var sp := _spec(kind, tile, hp_scale, game.villages[0])
		sp.merge(extra)
		_queue.append(sp)
	changed.emit()


## Debug (Commands._debug): an enemy of `kind` at a random edge spawn of
## `target`, now, wave or no wave (a water monster: at one of its water
## spawns, or any water spawn or deep tile its kind can live in). It doesn't
## count for the wave.
func debug_spawn(kind: String, target: Village) -> Enemy:
	if str(Config.ENEMIES[kind].get("habitat", "land")) == "water":
		var water: Array = aqua(target).get(kind, [])
		if water.is_empty():
			for t in game.map.water_spawns:
				if game.world.pathing.body_fits(game.world.pathing.body_of(t), kind):
					water.append(t)
		if water.is_empty():
			for b in game.world.pathing.bodies.size():
				if game.world.pathing.body_fits(b, kind):
					water.append(game.world.pathing.nearest_deep(b, Vector2(target.center)))
		if water.is_empty():
			return null
		return spawn_at(kind, water[_rng.randi() % water.size()], target, wave)
	var points: Array = target.home_spawns if game.villages.size() > 1 and not target.home_spawns.is_empty() else game.map.edge_spawns
	if points.is_empty():
		return null
	return spawn_at(kind, points[_rng.randi() % points.size()], target, wave)


## An enemy of `kind` at `tile` (on a road; a water monster: on deep water),
## as strong as in wave `strength`, now; it doesn't count for the wave
## (debug_spawn, the title backdrop, tests).
func spawn_at(kind: String, tile: Vector2i, target: Village, strength: int) -> Enemy:
	_uncounted_next = true
	var g := _spawn(_spec(kind, tile, pow(Config.WAVE_HP_GROWTH, maxi(strength, 1) - 1), target))
	_uncounted_next = false
	_alive -= 1
	_uncounted[g] = true
	return g


## Village `v`'s Aqua.eligibility ({} for null), worked out once.
func aqua(v: Village) -> Dictionary:
	if v == null or game.world == null or game.world.pathing == null:
		return {}
	if not _aqua.has(v.id):
		_aqua[v.id] = Aqua.eligibility(game, v.id)
	return _aqua[v.id]


## Water monsters in a share come from the village's water spawns (water-bound
## ones always; amphibians half of the time, else from the edge, as rolled;
## always with `amphibians_from_water`, a scenario's rule).
func _water_spawns(out: Array, target: Village) -> void:
	var elig := aqua(target)
	for spec in out:
		var kind: String = spec["kind"]
		if not elig.has(kind):
			continue
		var spawns: Array = elig[kind]
		var water_bound := str(Config.ENEMIES[kind].get("habitat", "land")) == "water"
		if spawns.is_empty() or (not water_bound and not amphibians_from_water and _rng.randf() < 0.5):
			continue
		spec["spawn"] = spawns[_rng.randi() % spawns.size()]
		spec.erase("lair")


## Villages whose first raised dead are logged already (at Info; later: Debug).
var _raise_logged := {}


## A necromancer's spell is done: the corpse rises as its old kind, with a
## share of its HP draining away (Enemy.make_raised), and walks the roads to
## the necromancer's village. It counts as alive for the wave.
func raise_corpse(c: Corpse, by: Enemy) -> Enemy:
	if not game.corpses.corpses.has(c):
		return null
	var target: Village = by.target_village if is_instance_valid(by.target_village) else game.villages[0]
	var g := _walker(c.kind, c.grid_pos, c.hp_scale, target)
	g.wave = c.wave
	var spec: Dictionary = by.spec()
	g.make_raised(float(spec["raise_hp"]), float(spec["raise_decay"]))
	game.corpses.remove(c)
	_add(g, target)
	var first := not _raise_logged.has(target.id)
	_raise_logged[target.id] = true
	target.events.add(EventLog.Level.INFO if first else EventLog.Level.DEBUG, "A necromancer raised a dead %s!" % str(g.spec()["name"]).to_lower() if first else "%s raised %s from the dead" % [by.label(), g.label()])
	Combat.burst(game, "warp", g.position + Vector2(0, -16), 0.8)
	return g


## An enemy of `kind` standing at `pos` (grid), not yet added: its road from
## the nearest road tile (an amphibian in water: from there) to `target`.
func _walker(kind: String, pos: Vector2, hp_scale: float, target: Village) -> Enemy:
	var pathing := game.world.pathing
	var tile := Vector2i(pos.round())
	var amph := str(Config.ENEMIES[kind].get("habitat", "land")) == "amphibian"  # (a raised crab swims on, but never dives)
	var road := tile if amph and game.map.is_wet(tile) else pathing.nearest_road(tile)
	var field := target.id if game.villages.size() > 1 and pathing.enemy_distance(road, target.id, amph) < Pathing.UNREACHABLE else -1
	var route := pathing.enemy_route(road, _rng, field, amph)
	var g: Enemy = ENEMY_SCRIPT.new()
	g.setup(game, route, hp_scale, kind)
	var pts := PackedVector2Array([pos])
	pts.append_array(g.path)
	g.set_grid_pos(pos)
	g.follow(pts)
	return g


## A spider mother lays a clutch: clutch[0]..clutch[1] eggs of her `lays`
## kind around her (lay_spread tiles, on ground one can walk), with her HP
## scale; undead if she was raised or is undead. They count for the wave
## (or not, like a debug mother).
func lay_eggs(m: Enemy) -> Array[Enemy]:
	var spec: Dictionary = m.spec()
	var kind := str(spec["lays"])
	var target: Village = m.target_village if is_instance_valid(m.target_village) else game.villages[0]
	var n := _rng.randi_range(int(spec["clutch"][0]), int(spec["clutch"][1]))
	var out: Array[Enemy] = []
	var turn := _rng.randf() * TAU
	for i in n:
		var a := turn + TAU * (float(i) + _rng.randf() * 0.5) / float(n)
		var pos := m.grid_pos + Vector2(cos(a), sin(a)) * float(spec["lay_spread"]) * _rng.randf_range(0.5, 1.0)
		if not game.world.pathing.is_walkable(Vector2i(pos.round())):
			pos = m.grid_pos + Vector2(cos(a), sin(a)) * 0.15
		var e: Enemy = ENEMY_SCRIPT.new()
		e.setup(game, [Vector2i(pos.round())] as Array[Vector2i], m.hp_scale, kind)
		e.set_grid_pos(pos)
		e.follow(PackedVector2Array([pos]))
		e.wave = m.wave
		if m.raised or m.undead:
			e.make_undead()
		_add(e, target)
		if _uncounted.has(m):
			_alive -= 1
			_uncounted[e] = true
		e.pop_in()
		out.append(e)
	target.events.debug("%s lays %d eggs" % [m.label(), n])
	return out


## A spider egg hatches: its hatch_into comes out where it lay, as strong as
## the egg's wave (undead from an undead egg), and takes the road to the
## egg's village; the egg is a broken shell for a while (Enemy.hatch_out).
## The spiderling counts for the wave (or not, like the egg).
func hatch(egg: Enemy) -> Enemy:
	if egg.dead:
		return null
	var target: Village = egg.target_village if is_instance_valid(egg.target_village) else game.villages[0]
	var g := _walker(str(egg.spec()["hatch_into"]), egg.grid_pos, egg.hp_scale, target)
	g.wave = egg.wave
	if egg.undead:
		g.make_undead()
	_add(g, target)
	if _uncounted.has(egg):
		_alive -= 1
		_uncounted[g] = true
	g.pop_in()
	target.events.debug("%s hatches: %s" % [egg.label(), g.label()])
	egg.hatch_out()  # (after the spiderling counts: the wave can't end in between)
	return g


func _on_enemy_killed(g: Enemy) -> void:
	game.stats.on_kill(g)
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
		v.economy.add("gold", gold, "kills")
		v.events.debug("killed %s (by %s, +%d gold)" % [g.label(), game.who(g.killer), gold])
		if gold > 0:
			game.world.float_text("+%d {gold}" % gold, g.position + Vector2(0, -50), Color("c9a24a"))
			Sfx.play("coin")
	if g.spec().get("corpse", true) and not g.raised:  # (the raised leave none)
		var c := game.corpses.spawn(g.kind, g.wave, g.grid_pos)
		c.extra_gold = g.loot_gold
		c.hp_scale = g.hp_scale
	_split(g)
	_enemy_gone(g)


## A slain slime splits into split_count smaller ones (Config "split_into"),
## side by side where it died, in its colour; they walk on along its road.
## They count for the wave (or not, like a debug slime).
func _split(g: Enemy) -> void:
	var into := str(g.spec().get("split_into", ""))
	if into == "" or g.raised:
		return
	var target: Village = g.target_village if is_instance_valid(g.target_village) else game.villages[0]
	var rest := g.path.slice(mini(g.path_index, g.path.size()))
	var ahead := (rest[0] - g.grid_pos) if not rest.is_empty() else Vector2.RIGHT
	var side := Vector2(-ahead.y, ahead.x).normalized() if ahead.length() > 0.01 else Vector2(0.7, -0.7)
	var n := int(g.spec()["split_count"])
	var names := PackedStringArray()
	for i in n:
		var c: Enemy = ENEMY_SCRIPT.new()
		c.setup(game, [g.current_tile()] as Array[Vector2i], g.hp_scale, into)
		c.wave = g.wave
		c.set_color(g.color)
		var start := g.grid_pos + side * 0.25 * (float(i) - (n - 1) / 2.0) * 2.0
		var pts := PackedVector2Array([start])
		for p in rest:
			pts.append(p - g._jitter + c._jitter)
		c.set_grid_pos(start)
		c.follow(pts)
		_add(c, target)
		if _uncounted.has(g):
			_alive -= 1
			_uncounted[c] = true
		c.pop_in()
		names.append(c.label())
	target.events.debug("%s splits into %s" % [g.label(), " and ".join(names)])


func _on_enemy_reached_gate(g: Enemy) -> void:
	game.on_enemy_reached_gate(g)
	_enemy_gone(g)


## Debug enemies (debug_spawn), which don't count for the wave.
var _uncounted := {}
## spawn_at is making one of those (no "first one" log for it).
var _uncounted_next := false


func _enemy_gone(g: Enemy = null) -> void:
	if _uncounted.erase(g):
		changed.emit()
		return
	_alive -= 1
	if not in_progress() and wave > 0:
		rat_deadline = -1.0
		rats_leave = false
		countdown = buffer if last_wave <= 0 or wave < last_wave else -1.0
		game.log_all(EventLog.Level.INFO, "Wave %d is over" % wave)
		wave_finished.emit(wave)
	changed.emit()
