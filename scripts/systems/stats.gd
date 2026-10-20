class_name Stats
extends Node
## In-game statistics (docs/statistics-design.md): counters that add up events
## as they happen (the Summary), samples of each village's state every
## Config.STATS["sample_interval"] game seconds (the Timeline), and what the
## awards need. One per game, under Game/Systems. The host (or single player)
## counts; a co-op client asks the host for everything (request / from_net).
## The title backdrop counts nothing.

## The numbers changed (a client got them from the host, or the game ended).
signal updated

## Sampled per village, in this order (see _sample).
const SERIES: Array[String] = [
	"gold", "food", "materials", "villagers", "huts", "units", "units_hp", "units_max_hp",
	"buildings", "explored", "hero_xp", "hero_level", "hero_hp", "wave", "enemies", "corpses",
]

var game: Game
## Counting at all (from start(); not on a co-op client, not in the title backdrop).
var enabled := false
var _can_count := false
## Game seconds since the start (game speed counts, a pause doesn't).
var time := 0.0
## When each sample was taken (game seconds).
var times := PackedFloat32Array()
## [time, wave number] for every wave that started.
var wave_marks: Array = []
## Per village id: {"name", "color", "c": counters (key -> number),
## "s": samples (SERIES key -> PackedFloat32Array, one value per `times`),
## "towers": nid -> [label, kills, tower level, unit], "gatherers" / "explorers":
## label -> corpses / tiles, "hero_waves": wave -> the hero's kills,
## "hut_waves": wave -> the fewest intact huts after a burn in it, "fell_waves":
## wave -> true for each wave in which the village fell (Closest call skips those)}.
var villages: Array[Dictionary] = []
## A co-op client has had numbers from the host.
var received := false
var ended := false
var _next_sample := 0.0
var _wave_started_at := -1.0
## Per village: when the hero last came back (or the game started); -1 while she's down.
var _hero_up_since: Array[float] = []


func setup(p_game: Game) -> void:
	game = p_game
	_can_count = game.backdrop == null and not game.is_client
	for v in game.villages:
		villages.append({"name": v.village_name, "color": v.color, "c": {}, "s": _empty_series(),
			"towers": {}, "gatherers": {}, "explorers": {}, "hero_waves": {},
			"hut_waves": {}, "fell_waves": {}})
		_hero_up_since.append(0.0)
		v.economy.earned.connect(_on_earned.bind(v.id))
		v.economy.spent.connect(_on_spent.bind(v.id))


func _empty_series() -> Dictionary:
	var s := {}
	for k in SERIES:
		s[k] = PackedFloat32Array()
	return s


## The villages are set up (what came with the start doesn't count): the first sample (time 0).
func start() -> void:
	enabled = _can_count
	if not enabled:
		return
	game.waves.wave_started.connect(_on_wave_started)
	game.waves.wave_finished.connect(_on_wave_finished)
	_sample()
	_next_sample = float(Config.STATS["sample_interval"])


func _process(delta: float) -> void:
	if not enabled or ended:
		return
	if game.game_over:
		finish()
		return
	time += delta
	for v in game.villages:
		var h := v.hero
		if is_instance_valid(h) and not h.dead and h.mode == Hero.Mode.SUPPORT and h.support_target != null and h.support_target != v:
			count(v, "hero.support_time", delta)
	if time >= _next_sample:
		_next_sample += float(Config.STATS["sample_interval"])
		_sample()


## Game over: the last sample; nothing is counted after it. (Co-op host: every
## client gets the numbers.)
func finish() -> void:
	if not enabled or ended:
		return
	_sample()
	ended = true
	if game.replicator and game.replicator.hosting:
		Net.broadcast_stats(to_net())
	updated.emit()


# --- counting ---------------------------------------------------------------------------

func count(v: Village, key: String, amount: float = 1.0) -> void:
	if not enabled or ended or v == null:
		return
	var c: Dictionary = villages[v.id]["c"]
	c[key] = c.get(key, 0.0) + amount


func set_max(v: Village, key: String, value: float) -> void:
	if not enabled or ended or v == null:
		return
	var c: Dictionary = villages[v.id]["c"]
	c[key] = maxf(c.get(key, value), value)


func set_min(v: Village, key: String, value: float) -> void:
	if not enabled or ended or v == null:
		return
	var c: Dictionary = villages[v.id]["c"]
	c[key] = minf(c.get(key, value), value)


## Counter `key` of village `vid` (0 if never counted).
func value(vid: int, key: String) -> float:
	if vid < 0 or vid >= villages.size():
		return 0.0
	return float(villages[vid]["c"].get(key, 0.0))


func has_value(vid: int, key: String) -> bool:
	return vid >= 0 and vid < villages.size() and villages[vid]["c"].has(key)


## Adds `amount` to `table[name]` of village `v`'s awards ("gatherers", "explorers").
func credit(v: Village, table: String, name: String, amount: float = 1.0) -> void:
	if not enabled or ended or v == null:
		return
	var t: Dictionary = villages[v.id][table]
	t[name] = t.get(name, 0.0) + amount


## Kinds with a "killed" row of their own; everything else is "other".
static func kill_group(e: Enemy) -> String:
	if e.raised:
		return "raised"
	return e.kind if (Config.STATS["kill_kinds"] as Array).has(e.kind) else "other"


## An enemy died (a wave's, a camp's, a debug one): who killed it, and what.
## Raised dead that crumbled by themselves count for nobody.
func on_kill(e: Enemy) -> void:
	if not enabled or ended or e.decayed:
		return
	var k := e.killer
	var v := game.village_of(k)
	if v == null:
		v = e.target_village if is_instance_valid(e.target_village) else null
	if v == null:
		return
	var by := "other"
	if k is Tower:
		by = "tower"
	elif k is Soldier:
		by = "units"
	elif k is EarthElemental:
		by = "summons"
	elif k is Hero:
		by = "hero"
	count(v, "kills")
	count(v, "kill." + kill_group(e))
	count(v, "kill_by." + by)
	if k is Tower:
		var t := k as Tower
		var towers: Dictionary = villages[v.id]["towers"]
		var row: Array = towers.get(t.nid, [t.label(), 0, 0, ""])
		row[1] = int(row[1]) + 1
		row[2] = t.level
		if t.garrison:
			row[3] = "%s, level %d" % [t.garrison.display_name(), t.garrison.level + 1]
		towers[t.nid] = row
	elif k is Hero:
		var h := k as Hero
		count(v, "hero.kills")
		var hw: Dictionary = villages[v.id]["hero_waves"]
		hw[game.waves.wave] = int(hw.get(game.waves.wave, 0)) + 1
		if h.mode == Hero.Mode.SUPPORT and h.support_target != null and h.support_target != v:
			count(v, "hero.support_kills")


## A hut burned: one more, and the fewest intact huts in this wave (Closest call).
func on_hut_burned(v: Village) -> void:
	if not enabled or ended or v == null:
		return
	count(v, "huts_burned")
	var left := v.intact_huts().size()
	var hw: Dictionary = villages[v.id]["hut_waves"]
	hw[game.waves.wave] = mini(int(hw.get(game.waves.wave, left)), left)


## Village `v` fell (its last villager or hut lost): Closest call leaves this wave out.
func on_village_fell(v: Village) -> void:
	if not enabled or ended or v == null:
		return
	villages[v.id]["fell_waves"][game.waves.wave] = true


## Closest call of village `vid`: [fewest intact huts, wave] over the waves
## with a burned hut in which it didn't fall, or [] if there is none.
func closest_call(vid: int) -> Array:
	var best: Array = []
	var fell: Dictionary = villages[vid].get("fell_waves", {})
	var hw: Dictionary = villages[vid].get("hut_waves", {})
	for w in hw:
		if not fell.has(w) and (best.is_empty() or int(hw[w]) < best[0]):
			best = [int(hw[w]), int(w)]
	return best


func on_hero_down(v: Village) -> void:
	if not enabled or ended or v == null:
		return
	count(v, "hero.downed")
	if _hero_up_since[v.id] >= 0.0:
		set_max(v, "hero.streak", time - _hero_up_since[v.id])
	_hero_up_since[v.id] = -1.0


func on_hero_back(v: Village) -> void:
	if v != null and v.id < _hero_up_since.size():
		_hero_up_since[v.id] = time


func _on_earned(res: String, amount: float, source: String, vid: int) -> void:
	if amount == 0.0:
		return
	var v := game.villages[vid]
	count(v, "earn.%s.%s" % [res, source], amount)
	count(v, "earn." + res, amount)


func _on_spent(res: String, amount: float, what: String, vid: int) -> void:
	var v := game.villages[vid]
	count(v, "spend.%s.%s" % [res, what], amount)
	count(v, "spend." + res, amount)


func _on_wave_started(n: int) -> void:
	wave_marks.append([time, n])
	_wave_started_at = time
	for v in game.villages:
		set_max(v, "biggest_wave", game.waves.enemies_left())
		if game.waves.enemies_left() >= value(v.id, "biggest_wave"):
			villages[v.id]["c"]["biggest_wave_n"] = float(n)


func _on_wave_finished(n: int) -> void:
	var took := time - _wave_started_at if _wave_started_at >= 0.0 else -1.0
	_wave_started_at = -1.0
	for v in game.villages:
		if v.fallen:
			continue
		count(v, "waves")
		if took >= 0.0 and (not has_value(v.id, "fastest_wave") or took < value(v.id, "fastest_wave")):
			villages[v.id]["c"]["fastest_wave"] = took
			villages[v.id]["c"]["fastest_wave_n"] = float(n)


# --- samples ---------------------------------------------------------------------------

func _sample() -> void:
	times.append(time)
	var corpses: Array = game.corpses.corpses
	var enemies := game.get_tree().get_nodes_in_group("enemies")
	for v in game.villages:
		var row := {}
		row["gold"] = v.economy.amount("gold")
		row["food"] = v.economy.amount("food")
		row["materials"] = v.economy.amount("materials")
		row["villagers"] = v.population.count()
		row["huts"] = v.intact_huts().size()
		var hp := 0.0
		var max_hp := 0.0
		for u in v.army.units:
			hp += maxf(u.hp, 0.0)
			max_hp += u.max_hp()
		row["units"] = v.army.units.size()
		row["units_hp"] = hp
		row["units_max_hp"] = max_hp
		var built := 0
		for b in v.buildings():
			if b.complete and not v.rect.has_point(b.tile) and not (b is Hut) and not (b is StaticPiece):
				built += 1
		row["buildings"] = built
		row["explored"] = game.fog.explored_of[v.id].count(1)
		var h := v.hero
		row["hero_xp"] = h.xp if is_instance_valid(h) else 0
		row["hero_level"] = h.level + 1 if is_instance_valid(h) else 0
		row["hero_hp"] = maxf(h.hp, 0.0) if is_instance_valid(h) and not h.dead else 0.0
		row["wave"] = game.waves.wave
		var near := 0
		for node in enemies:
			var e := node as Enemy
			if not e.dead and e.target_village == v and not e.wild():
				near += 1
		row["enemies"] = near
		var lying := 0
		for c in corpses:
			if is_instance_valid(c) and game.fog.is_explored_by(v.id, (c as Corpse).tile()):
				lying += 1
		row["corpses"] = lying
		var s: Dictionary = villages[v.id]["s"]
		for k in SERIES:
			var arr: PackedFloat32Array = s[k]
			arr.append(float(row[k]))
			s[k] = arr
		var c: Dictionary = villages[v.id]["c"]
		c["explored"] = float(row["explored"])
		set_max(v, "hero.level", float(row["hero_level"]))
		if _hero_up_since[v.id] >= 0.0:
			set_max(v, "hero.streak", time - _hero_up_since[v.id])


## Village `vid`'s samples of `key` (one per `times`).
func series(vid: int, key: String) -> PackedFloat32Array:
	if vid < 0 or vid >= villages.size():
		return PackedFloat32Array()
	return villages[vid]["s"].get(key, PackedFloat32Array())


# --- the screen and co-op ---------------------------------------------------------------

## The numbers are wanted (the screen opened): a co-op client asks the host,
## everyone else has them already.
func request() -> void:
	if game.is_client:
		Net.request_stats()
	else:
		updated.emit()


## Everything, for a client (one message; never part of the snapshots).
func to_net() -> Dictionary:
	if not ended:
		for v in game.villages:
			if _hero_up_since[v.id] >= 0.0:
				set_max(v, "hero.streak", time - _hero_up_since[v.id])
	return {"time": time, "times": times, "marks": wave_marks, "villages": villages, "ended": ended}


## Everything, for a save (docs/save-design.md).
func save_state() -> Dictionary:
	var d := to_net()
	d["villages"] = villages.duplicate(true)
	d["next"] = _next_sample
	d["wave_at"] = _wave_started_at
	d["hero_up"] = Array(_hero_up_since)
	return d


## A loaded game: the numbers as saved, and counting goes on (instead of start()).
## Village names and colours are the game's now (a co-op village may have a new player).
func load_state(d: Dictionary) -> void:
	time = float(d.get("time", 0.0))
	times = d.get("times", PackedFloat32Array())
	wave_marks = d.get("marks", [])
	var saved: Array = d.get("villages", [])
	for i in mini(saved.size(), villages.size()):
		var row: Dictionary = saved[i]
		row["name"] = villages[i]["name"]
		row["color"] = villages[i]["color"]
		villages[i] = row
	_next_sample = float(d.get("next", time + float(Config.STATS["sample_interval"])))
	_wave_started_at = float(d.get("wave_at", -1.0))
	var up: Array = d.get("hero_up", [])
	for i in mini(up.size(), _hero_up_since.size()):
		_hero_up_since[i] = float(up[i])
	enabled = _can_count
	if enabled:
		game.waves.wave_started.connect(_on_wave_started)
		game.waves.wave_finished.connect(_on_wave_finished)


## Co-op client: the host's numbers.
func from_net(d: Dictionary) -> void:
	time = float(d.get("time", 0.0))
	times = d.get("times", PackedFloat32Array())
	wave_marks = d.get("marks", [])
	villages.assign(d.get("villages", []))
	ended = bool(d.get("ended", false))
	received = true
	updated.emit()


## Has numbers to show (single player and the host always; a client once the host answered).
func ready_to_show() -> bool:
	return not game.is_client or received
