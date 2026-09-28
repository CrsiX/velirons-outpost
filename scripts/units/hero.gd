class_name Hero
extends Civilian
## The hero: part villager, part soldier, with a sword for close combat.
## Starts in the village centre; the player picks what he does (his mode):
##   Defend  - waits in the centre; when enemies come near a gate he goes out
##             and fights them (nearest first, then the strongest).
##   Build / Explore / Gather - the villager jobs, done a little less well.
##   Train   - at training grounds with a unit ready, passes his XP on to it;
##             without such grounds he defends instead, but drops any fight as
##             soon as a unit is ready to train.
## Every action except training earns XP (Config.HERO_XP_PER_ACTION). When his
## HP runs out he is downed: all XP is lost, he leaves no corpse, and he revives
## in the village centre when the wave is over, still in the same mode.
## He has no hut, eats nothing and doesn't count as a villager.

signal changed

enum Mode { DEFEND, BUILD, EXPLORE, GATHER, TRAIN }
const MODE_NAMES: Array[String] = ["Defend", "Build", "Explore", "Gather", "Train"]

var mode := Mode.DEFEND
var xp := 0
var max_hp := 60.0
var hp := 60.0
var target: Enemy = null
var training_at: TrainingGrounds = null
var jobs := {}  # Mode -> CivilianJob

var _attack_timer := 0.0
var _think_timer := 0.0
var _chase_tile := Vector2i(-9999, -9999)
var _train_acc := 0.0


func setup_hero(p_game: Game) -> void:
	game = p_game
	role = "hero"
	var spec: Dictionary = Config.HERO
	speed = spec["speed"]
	max_hp = spec["hp"]
	hp = max_hp
	_init_sprite("unit_hero")
	set_grid_pos(Vector2(Config.VILLAGE_CENTER))
	at_home = true
	add_to_group("observers")
	add_to_group("melee_defenders")
	jobs[Mode.BUILD] = BuildJob.new(spec["build_efficiency"])
	jobs[Mode.EXPLORE] = ExploreJob.new(spec["explore_reveal"])
	jobs[Mode.GATHER] = GatherJob.new(spec["gather_capacity"])
	for j in jobs.values():
		j.bind(self)
	game.waves.wave_finished.connect(func(_n: int) -> void:
		if dead:
			revive())


func display_name() -> String:
	return Config.HERO["name"]


# --- modes ---------------------------------------------------------------------------

func set_mode(m: int) -> void:
	if m == mode:
		return
	_leave_mode()
	mode = m as Mode
	changed.emit()


func cycle_mode() -> void:
	set_mode((mode + 1) % MODE_NAMES.size())


func mode_name() -> String:
	return MODE_NAMES[mode]


## Training grounds where a unit is ready to learn from him, or null.
func ready_grounds() -> TrainingGrounds:
	var best: TrainingGrounds = null
	var best_d := INF
	for b in game.world.buildings:
		if b is TrainingGrounds and b.is_ready_for_training():
			var d := Vector2(b.tile).distance_to(grid_pos)
			if d < best_d:
				best_d = d
				best = b
	return best


## What he is actually doing: Train falls back to Defend without ready grounds.
func effective_mode() -> Mode:
	if mode == Mode.TRAIN and ready_grounds() == null:
		return Mode.DEFEND
	return mode


func _leave_mode() -> void:
	if jobs.has(mode):
		jobs[mode].release()
		jobs[mode].state = 0
	_stop_training()
	target = null
	sprite.rotation = 0.0


func _stop_training() -> void:
	if is_instance_valid(training_at) and training_at.trainee_hero == self:
		training_at.trainee_hero = null
	training_at = null


# --- Civilian hooks ------------------------------------------------------------------------

## He stays visible in the village centre (villagers vanish into their huts).
func _set_home(v: bool) -> void:
	at_home = v
	visible = not dead


## Only runs from enemies while doing villager jobs; a defender stands and fights.
func wants_to_evade() -> bool:
	return effective_mode() in [Mode.BUILD, Mode.EXPLORE, Mode.GATHER]


func on_action(kind: String) -> void:
	xp += int(Config.HERO_XP_PER_ACTION.get(kind, 0))
	changed.emit()


func exploring_target() -> Vector2i:
	return jobs[Mode.EXPLORE].exploring_target() if mode == Mode.EXPLORE else Vector2i(-1, -1)


func _on_evade() -> void:
	if jobs.has(mode):
		jobs[mode].on_evade()


func _after_evade() -> void:
	if jobs.has(mode):
		jobs[mode].after_evade()


func sight_radius() -> float:
	return 0.0 if at_home or dead else Config.HERO["sight"]


func _tick(delta: float) -> void:
	match mode:
		Mode.DEFEND:
			_defend(delta)
		Mode.BUILD, Mode.EXPLORE, Mode.GATHER:
			jobs[mode].tick(delta)
		Mode.TRAIN:
			var g := ready_grounds()
			if g != null:
				_train(g, delta)
			else:
				_stop_training()
				_defend(delta)  # stand-in until a unit is ready to train


# --- Defend -----------------------------------------------------------------------------------

func _defend(delta: float) -> void:
	_attack_timer -= delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.3
		target = _pick_enemy()
	if is_instance_valid(target) and not target.dead:
		if at_home:
			_set_home(false)
		var dist := target.grid_pos.distance_to(grid_pos)
		if dist <= Config.HERO["attack_range"]:
			_set_moving(false)
			sprite.flip_h = Iso.to_world(target.grid_pos - grid_pos).x < 0.0
			if _attack_timer <= 0.0:
				_attack_timer = Config.HERO["attack_cooldown"]
				_strike()
		else:
			if path_index >= path.size() or target.current_tile() != _chase_tile:
				_chase()
			step_path(delta)
		return
	target = null
	# Nothing to fight: back to the village centre.
	if not at_home:
		if path_index >= path.size() and grid_pos.distance_to(Vector2(Config.VILLAGE_CENTER)) > 0.1:
			head_home()
		if step_path(delta):
			arrive_home()


## Enemies near a gate (or near him, within his leash), nearest first, then strongest.
func _pick_enemy() -> Enemy:
	var best: Enemy = null
	var best_key := Vector2(INF, INF)
	var centre := Vector2(Config.VILLAGE_CENTER)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or e.grid_pos.distance_to(centre) > Config.HERO["leash"]:
			continue
		var near_gate := false
		for g in game.map.gates:
			near_gate = near_gate or e.grid_pos.distance_to(Vector2(g)) <= Config.HERO["alert_radius"]
		var near_me := not at_home and e.grid_pos.distance_to(grid_pos) <= Config.HERO["sight"]
		if not (near_gate or near_me):
			continue
		var key := Vector2(floorf(e.grid_pos.distance_to(grid_pos)), -e.max_hp)
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = e
	return best


func _chase() -> void:
	_chase_tile = target.current_tile()
	var p := game.world.pathing.find_path(current_tile(), _chase_tile)
	if p.is_empty():
		target = null
		return
	p[0] = grid_pos
	p[p.size() - 1] = target.grid_pos
	follow(p)


func _strike() -> void:
	target.take_damage(Config.HERO["damage"], self)
	on_action("hit")
	var tw := create_tween()
	var lunge := (Iso.to_world(target.grid_pos) - position).normalized() * 6.0
	tw.tween_property(sprite, "position", lunge, 0.08)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.12)
	Sfx.play("hit", 0.25)


# --- Train --------------------------------------------------------------------------------------

func _train(g: TrainingGrounds, delta: float) -> void:
	target = null  # abandon any fight
	if training_at != g:
		_stop_training()
		training_at = g
		g.trainee_hero = self
		if not head_out(g.work_tile()):
			return
	if grid_pos.distance_to(Vector2(g.work_tile())) > 0.2:
		if path_index >= path.size():
			head_out(g.work_tile())
		step_path(delta)
		return
	_set_moving(false)
	if xp <= 0:
		return  # nothing left to pass on
	_bob += delta * 9.0
	sprite.rotation = sin(_bob) * 0.2  # sparring
	_train_acc += Config.HERO["train_rate"] * delta
	var n := mini(int(_train_acc), xp)
	if n > 0:
		_train_acc -= n
		var used := game.army.train(g.trainable_unit(), n)
		xp -= used
		changed.emit()


# --- health -----------------------------------------------------------------------------------

func take_damage(amount: float, _source: Node = null) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.5, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	changed.emit()
	if hp <= 0.0:
		_downed()


## Out of the fight until the wave ends. XP is lost; the mode is kept.
func _downed() -> void:
	float_text("Hero down!", Color("ff7a6a"))
	if jobs.has(mode):
		jobs[mode].release()
		jobs[mode].state = 0
	_stop_training()
	target = null
	dead = true
	evading = false
	xp = 0
	hp = 0.0
	remove_from_group("melee_defenders")
	visible = false
	path = PackedVector2Array()
	Sfx.play("death")
	changed.emit()


func revive() -> void:
	dead = false
	hp = max_hp
	set_grid_pos(Vector2(Config.VILLAGE_CENTER))
	path = PackedVector2Array()
	at_home = true
	visible = true
	add_to_group("melee_defenders")
	float_text("The hero returns!", UiTheme.GOLD)
	changed.emit()


func status() -> String:
	if dead:
		return "downed - revives when the wave is over"
	if evading:
		return "fleeing from enemies"
	match effective_mode():
		Mode.DEFEND:
			if mode == Mode.TRAIN:
				return "defending (no unit ready at training grounds)"
			return "fighting a %s" % target.spec()["name"].to_lower() if is_instance_valid(target) and not target.dead else "guarding the village"
		Mode.TRAIN:
			if xp <= 0:
				return "at the training grounds: no XP left to pass on"
			return "training a %s" % training_at.garrison.display_name().to_lower() if is_instance_valid(training_at) and training_at.garrison else "walking to the training grounds"
	return jobs[mode].status()


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	var w := 30.0
	var r := Rect2(-w / 2.0, -52.0, w, 5.0)
	draw_rect(r.grow(1.5), Color("15110d"))
	draw_rect(r, Color("3a2a10"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), r.size.y)), Color("e8c040"))
