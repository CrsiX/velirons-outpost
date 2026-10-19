class_name Wrathwoods
extends Node
## Trees that wake up as wrathwoods (docs/enemies-design.md §15c;
## Config.WRATHWOOD): the roll at a forester's first blow on a tree, "the
## forest remembers" (each village's felled trees), waking one, its kill (gold,
## a log of living wood), and what a save keeps of them. The fight itself is
## WrathwoodBehavior. Wrathwoods count for no wave (Enemy.wild).

const ENEMY_SCRIPT := preload("res://scripts/units/enemy.gd")
const KIND := "wrathwood"

var game: Game
## Trees can wake up in this game (not the tutorial or the title backdrop;
## the co-op host decides). Scenarios will turn it on themselves.
var allowed := true
## Per village id: the trees its foresters felled ("the forest remembers").
var felled: Array[int] = []
## Per village id: none wakes before this wave has begun (after one died).
var calm_until: Array[int] = []
## Tests: every roll wakes the tree (a kind that can wake, when one may).
var always := false
var _rng := RandomNumberGenerator.new()


func setup(p_game: Game) -> void:
	game = p_game
	_rng.randomize()
	allowed = game.backdrop == null and not game.tutorial_mode and not game.is_client
	for v in game.villages:
		felled.append(0)
		calm_until.append(0)


## A forester of `v` felled a tree.
func on_felled(v: Village) -> void:
	felled[v.id] += 1


## The chance that the tree on `t` wakes when a forester of `v` starts on it.
func chance(v: Village, t: Vector2i) -> float:
	var cfg := Config.WRATHWOOD
	var base := float((cfg["chance"] as Dictionary).get(game.map.props.get(t, ""), 0.0))
	if base <= 0.0:
		return 0.0
	return minf(base + float(cfg["remember"]) * felled[v.id], float(cfg["max_chance"]))


## Could a tree wake for village `v` now (the wave, the quiet after the last
## one, one at a time)?
func may_wake(v: Village) -> bool:
	return allowed and game.waves.wave >= int(Config.WRATHWOOD["from_wave"]) and game.waves.wave >= calm_until[v.id] and of_village(v) == null


## The wrathwood of village `v`, or null.
func of_village(v: Village) -> Enemy:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.kind == KIND and not e.dead and e.target_village == v:
			return e
	return null


## A forester's first blow on the tree on `t` (nobody had chopped it yet):
## the roll. Returns the wrathwood, or null.
func on_first_blow(f: Forester, t: Vector2i) -> Enemy:
	var p := chance(f.village, t)
	if not may_wake(f.village) or p <= 0.0 or (_rng.randf() >= p and not always):
		return null
	return wake(t, f.village, f)


## The tree on `t` wakes up as a wrathwood of village `v`, after forester
## `f` (null: nobody; it has nobody to chase and goes for no camp).
func wake(t: Vector2i, v: Village, f: Forester = null) -> Enemy:
	var art := str(game.map.props.get(t, "tree_oak"))
	var what := game.world.tree_label(t)
	game.world.remove_tree(t, false)
	var e := _make(v, Vector2(t), pow(Config.WAVE_HP_GROWTH, maxi(game.waves.wave, 1) - 1))
	(e.behavior as WrathwoodBehavior).start(e, t, art, f, f.camp if f and is_instance_valid(f.camp) else null)
	_register(e)
	v.events.add(EventLog.Level.IMPORTANT, "%s woke up as a wrathwood!%s" % [what.capitalize(), " It is after %s." % f.label() if f else ""])
	Sfx.play("hit")
	return e


## Debug: wakes the explored tree nearest to one of `v`'s foresters (else to
## the village), whatever the odds and the wave. Null if there is none.
func debug_wake(v: Village) -> Enemy:
	var f: Forester = null
	for c in v.population.civilians:
		if c is Forester and not c.dead:
			f = c
			break
	var from := f.current_tile() if f else v.center
	var found := game.world.find_tree(from, 30.0, f if f else v.hero)
	if found.is_empty():
		return null
	return wake(found["tree"], v, f)


func _make(v: Village, pos: Vector2, hp_scale: float) -> Enemy:
	var e: Enemy = ENEMY_SCRIPT.new()
	e.setup(game, [Vector2i(pos.round())] as Array[Vector2i], hp_scale, KIND)
	e.set_grid_pos(pos)
	e.path = PackedVector2Array()
	e.wave = maxi(game.waves.wave, 1)
	e.target_village = v
	e.killed.connect(_on_killed)
	return e


func _add(e: Enemy) -> void:
	game.world.objects.add_child(e)


## Killed: gold to the killer's village (else its own), a log of living wood,
## and quiet for a few waves.
func _on_killed(e: Enemy) -> void:
	game.stats.on_kill(e)
	var gold := Config.enemy_stat_int(KIND, "gold_on_kill")
	var v := game.village_of(e.killer)
	if v == null:
		v = e.target_village
	v.economy.add("gold", gold, "kills")
	game.world.float_text("+%d {gold}" % gold, e.position + Vector2(0, -60), Color("c9a24a"))
	Sfx.play("coin")
	var c := game.corpses.spawn(KIND, e.wave, e.grid_pos)
	c.hp_scale = e.hp_scale
	var own := e.target_village
	calm_until[own.id] = game.waves.wave + int(Config.WRATHWOOD["quiet_waves"])
	own.events.add(EventLog.Level.INFO, "The wrathwood has fallen (%s, +%d gold). Its wood lies there for the taking." % [game.who(e.killer), gold])


# --- saving (docs/save-design.md) ---------------------------------------------------------

func save_state() -> Dictionary:
	var trees: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.kind != KIND or e.dead:
			continue
		var b := e.behavior as WrathwoodBehavior
		trees.append({"v": e.target_village.id, "hp": e.hp, "hs": e.hp_scale, "w": e.wave, "pos": e.grid_pos, "u": e.uid, "n": e.nid,
			"home": b.home, "art": b.tree_art, "st": int(b.state),
			"f": b.forester.nid if is_instance_valid(b.forester) else 0, "c": b.camp.nid if is_instance_valid(b.camp) else 0,
			"wake": b.wake_left, "wander": b.wander_left, "boost": b.boost_left})
	return {"felled": felled.duplicate(), "calm": calm_until.duplicate(), "trees": trees}


## A loaded game: the counters and every wrathwood as it was (its state,
## HP, where it is and what it is after; what it is doing right now starts afresh).
func load_state(d: Dictionary) -> void:
	for i in mini(felled.size(), (d["felled"] as Array).size()):
		felled[i] = int(d["felled"][i])
		calm_until[i] = int(d["calm"][i])
	for t: Dictionary in d["trees"]:
		var vid := int(t["v"])
		if vid < 0 or vid >= game.villages.size():
			continue
		var e := _make(game.villages[vid], t["pos"], float(t["hs"]))
		e.wave = int(t["w"])
		e.hp = clampf(float(t["hp"]), 1.0, e.max_hp)
		e.uid = int(t["u"])
		e.nid = int(t["n"])
		game.register_as(e, e.nid)
		var b := e.behavior as WrathwoodBehavior
		b.start(e, t["home"], str(t["art"]), game.entity(int(t["f"])) as Civilian, game.entity(int(t["c"])) as Building)
		b.state = int(t["st"]) as WrathwoodBehavior.State
		b.wake_left = float(t["wake"])
		b.wander_left = float(t["wander"])
		b.boost_left = float(t["boost"])
		if b.state != WrathwoodBehavior.State.WAKING:
			e.fx.erase("wake")
		if b.state == WrathwoodBehavior.State.WANDER:
			b.wander_from(e.grid_pos)
		_add(e)


## Adds a wrathwood made by _make for good (registered, on the map).
func _register(e: Enemy) -> void:
	e.uid = game.next_id(KIND)
	e.nid = game.register(e)
	_add(e)
