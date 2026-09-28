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
##   Rest    - walks back to the village centre and stays there, fighting nobody.
##   Support - (co-op) walks to another village (`support_target`) and defends
##             it as in Defend mode: its gates, its centre. He keeps his XP,
##             heals idling in its centre, and when downed revives at home and
##             walks back. The village he helps can't give him orders.
## Whenever he idles in the village centre (any mode) he slowly gets his HP
## back: Config.HERO "rest_regen" per second after "rest_delay" seconds.
## Every action except training earns XP (Config.HERO_XP_PER_ACTION). When his
## HP runs out he is downed: all XP is lost, he leaves no corpse, and he revives
## in the village centre when the wave is over, still in the same mode.
## He has no hut, eats nothing and doesn't count as a villager.

signal changed

enum Mode { DEFEND, BUILD, EXPLORE, GATHER, TRAIN, REST, SUPPORT }
const MODE_NAMES: Array[String] = ["Defend", "Build", "Explore", "Gather", "Train", "Rest", "Support"]

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
## Walking back to the village centre after a fight (Defend).
var _returning := false
## Support mode: the village he goes to defend.
var support_target: Village = null
## Seconds he has been idling in the village centre (see _regen).
var _idle_time := 0.0


func setup_hero(p_game: Game, p_village: Village) -> void:
	game = p_game
	village = p_village
	role = "hero"
	var spec: Dictionary = Config.HERO
	speed = spec["speed"]
	max_hp = spec["hp"]
	hp = max_hp
	_init_sprite("unit_hero")
	set_grid_pos(Vector2(village.center))
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


func label() -> String:
	return "the hero"


# --- modes ---------------------------------------------------------------------------

func set_mode(m: int) -> void:
	if m == mode:
		return
	_leave_mode()
	mode = m as Mode
	village.events.debug("hero mode: %s" % mode_name())
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
		if b is TrainingGrounds and b.village == village and b.is_ready_for_training():
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


## Where he stands guard and rests: the supported village in Support mode,
## else his own.
func base() -> Village:
	if mode == Mode.SUPPORT and support_target != null and support_target != village:
		return support_target
	return village


func set_support_target(v: Village) -> void:
	if v == support_target:
		return
	support_target = v
	target = null
	_returning = false
	if v:
		village.events.debug("the hero will support %s" % v.village_name)
	changed.emit()


func _leave_mode() -> void:
	if mode == Mode.SUPPORT and at_home and base() != village:
		_set_home(false)  # standing in someone else's village: walk from there
	if jobs.has(mode):
		jobs[mode].release()
		jobs[mode].state = 0
	_stop_training()
	target = null
	_returning = false
	sprite.rotation = 0.0


func _stop_training() -> void:
	if is_instance_valid(training_at) and training_at.trainee_hero == self:
		training_at.trainee_hero = null
	training_at = null


# --- Civilian hooks ------------------------------------------------------------------------

## He stays visible in the village centre (villagers vanish into their huts).
## Back at his post: his own village centre, or the one he supports.
func arrive_home() -> void:
	set_grid_pos(Vector2(base().center))
	_set_home(true)
	_set_moving(false)


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
		Mode.REST:
			target = null
			_return_home(delta)
		Mode.SUPPORT:
			_defend(delta)  # relative to base(): the village he supports
	_regen(delta)


## Idle in the village centre: after a short while the HP slowly comes back.
func _regen(delta: float) -> void:
	var idle := at_home and not evading and not is_instance_valid(target) and grid_pos.distance_to(Vector2(base().center)) < 0.2
	_idle_time = _idle_time + delta if idle else 0.0
	if _idle_time < Config.HERO["rest_delay"] or hp >= max_hp:
		return
	hp = minf(max_hp, hp + Config.HERO["rest_regen"] * delta)
	queue_redraw()
	if hp >= max_hp:
		village.events.debug("the hero is fully rested (%d HP)" % int(max_hp))
	changed.emit()


# --- Defend -----------------------------------------------------------------------------------

func _defend(delta: float) -> void:
	_attack_timer -= delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.3
		var t := _pick_enemy()
		if t != null and t != target:
			village.events.debug("the hero attacks %s" % t.label())
		target = t
	if is_instance_valid(target) and not target.dead:
		_returning = false
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
	_return_home(delta)


## Walks back to the village centre (Defend re-targets on the way, see
## _pick_enemy). Never teleports: a chase path may still be half walked.
func _return_home(delta: float) -> void:
	if at_home and grid_pos.distance_to(Vector2(base().center)) > 0.2:
		_set_home(false)  # his post moved (Support): set off
	if not at_home:
		if not _returning:
			_returning = true
			_walk_home()
		if step_path(delta):
			if grid_pos.distance_to(Vector2(base().center)) < 0.1:
				_returning = false
				arrive_home()
			else:
				_walk_home()  # that path ended elsewhere: plan again


## A walkable path from here to the village centre; straight across if none.
func _walk_home() -> void:
	var home_tile := base().center
	var centre := Vector2(home_tile)
	var p := game.world.pathing.find_path(current_tile(), home_tile)
	if p.is_empty():
		# Standing on a tile the pathing doesn't allow (e.g. mid-chase on a
		# corner): try from a walkable neighbour.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			p = game.world.pathing.find_path(current_tile() + d, home_tile)
			if not p.is_empty():
				p.insert(0, grid_pos)
				break
	if p.is_empty():
		p = PackedVector2Array([grid_pos, centre])
	p[p.size() - 1] = centre
	follow(p)


## Enemies near a gate (or near him, within his leash), nearest first, then strongest.
func _pick_enemy() -> Enemy:
	var best: Enemy = null
	var best_key := Vector2(INF, INF)
	var centre := Vector2(base().center)
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or e.grid_pos.distance_to(centre) > Config.HERO["leash"]:
			continue
		var near_gate := false
		for g in base().gates:
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
		village.events.debug("the hero heads to %s to train %s" % [g.label(), g.trainable_unit().label()])
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
		var used := village.army.train(g.trainable_unit(), n)
		xp -= used
		changed.emit()


# --- health -----------------------------------------------------------------------------------

func take_damage(amount: float, source = null) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.5, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	changed.emit()
	if hp <= 0.0:
		_downed(source)


## Out of the fight until the wave ends. XP is lost; the mode is kept.
func _downed(source = null) -> void:
	village.events.important("The hero was struck down by %s (%d XP lost); back after the wave" % [game.who(source), xp])
	float_text("Hero down!", Color("ff7a6a"))
	if jobs.has(mode):
		jobs[mode].release()
		jobs[mode].state = 0
	_stop_training()
	target = null
	_returning = false
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
	set_grid_pos(Vector2(village.center))
	path = PackedVector2Array()
	at_home = true
	visible = true
	add_to_group("melee_defenders")
	village.events.info("The hero returns to the village")
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
		Mode.SUPPORT:
			var b := base()
			if is_instance_valid(target) and not target.dead:
				return "fighting a %s at %s" % [target.spec()["name"].to_lower(), b.village_name]
			if b == village:
				return "no village to support"
			return "defending %s" % b.village_name if at_home or grid_pos.distance_to(Vector2(b.center)) < 6.0 else "on the way to %s" % b.village_name
		Mode.REST:
			if not at_home:
				return "walking back to rest"
			return "resting (HP recovering)" if hp < max_hp else "resting (full HP)"
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
