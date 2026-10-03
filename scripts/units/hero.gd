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
## Every action except training earns XP (Config.HERO_XP_PER_ACTION; the
## blow that kills an enemy earns a "kill" bonus on top). When his
## HP runs out he is downed: all XP is lost, he leaves no corpse, and he revives
## in the village centre when the wave is over, still in the same mode.
## He has no hut, eats nothing and doesn't count as a villager.

signal changed

enum Mode { DEFEND, BUILD, EXPLORE, GATHER, TRAIN, REST, SUPPORT }
const MODE_NAMES: Array[String] = ["Defend", "Build", "Explore", "Gather", "Train", "Rest", "Support"]
## The mode as a word for his panel's title ("Hero: defending").
const MODE_WORDS: Array[String] = ["defending", "building", "exploring", "gathering", "training", "resting", "supporting"]
## Icon per mode (art/mode_*.svg).
const MODE_ICONS: Array[String] = ["mode_defend", "mode_build", "mode_explore", "mode_gather", "mode_train", "mode_rest", "mode_support"]

var mode := Mode.DEFEND
var xp := 0
## 0-based: level 1 ... Config.HERO_MAX_LEVEL. Bought with his own XP; kept when downed.
var level := 0
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
## Resting: the next snore's Z in ... s.
var _snore_in := 0.0
var _snores := 0
## Real seconds left of his pause after a unit levelled up (Train).
var train_pause := 0.0
## The monster camp he was ordered to clear (docs/world-design.md §9.3).
var camp_target: MonsterCamp = null


func setup_hero(p_game: Game, p_village: Village) -> void:
	game = p_game
	village = p_village
	role = "hero"
	var spec: Dictionary = Config.HERO
	speed = spec["speed"]
	max_hp = spec["hp"]
	hp = max_hp
	_init_sprite("unit_hero")
	UnitFx.add_halo(sprite, game, func() -> Vector2: return grid_pos)
	set_grid_pos(Vector2(village.center))
	at_home = true
	add_to_group("observers")
	add_to_group("melee_defenders")
	add_to_group("heroes")  # (healing mages heal every village's hero)
	jobs[Mode.BUILD] = BuildJob.new(spec["build_efficiency"])
	jobs[Mode.EXPLORE] = HeroExploreJob.new(spec["explore_reveal"])
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
	_drop_work()
	sprite.rotation = 0.0


## Lets go of whatever he was doing: his mode's job, training, a fight.
func _drop_work() -> void:
	if jobs.has(mode):
		jobs[mode].release()
		jobs[mode].state = 0
	_stop_training()
	target = null
	_returning = false


func _stop_training() -> void:
	train_pause = 0.0
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
	return camp_target == null and effective_mode() in [Mode.BUILD, Mode.EXPLORE, Mode.GATHER]


func on_action(kind: String) -> void:
	xp += int(Config.HERO_XP_PER_ACTION.get(kind, 0))
	game.stats.count(village, "hero.xp", int(Config.HERO_XP_PER_ACTION.get(kind, 0)))
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
	if camp_target != null:
		if is_instance_valid(camp_target) and not camp_target.cleared and not camp_target.alive().is_empty():
			_attack_camp(delta)
			_regen(delta)
			return
		_end_camp()
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
	hp = minf(max_hp, hp + village.relic_bonus("hero_rest") * delta)  # (a hearth stone)
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
		_fight(delta)
		return
	target = null
	_return_home(delta)


## Goes for `target` and strikes it when in reach.
func _fight(delta: float) -> void:
	_returning = false
	if at_home:
		_set_home(false)
	var dist := target.grid_pos.distance_to(grid_pos)
	if dist <= Config.HERO["attack_range"]:
		_set_moving(false)
		face(target.grid_pos)
		if _attack_timer <= 0.0:
			_attack_timer = Config.HERO["attack_cooldown"]
			_strike(target)
	else:
		if path_index >= path.size() or target.current_tile() != _chase_tile:
			_chase()
		if target != null:
			step_path(delta)


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
		if e.dead or e.flies() or e.grid_pos.distance_to(centre) > Config.HERO["leash"]:
			continue  # (flyers: out of his sword's reach, he only hits back)
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
	if best != null:
		return best
	# Last priority: rats on his village's farms, however far out (no leash).
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or not (e.behavior is RatBehavior):
			continue
		var f: Farm = (e.behavior as RatBehavior).farm
		if not is_instance_valid(f) or f.village != base():
			continue
		var d := e.grid_pos.distance_to(grid_pos)
		if d < best_d:
			best_d = d
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


## A flyer hit him: if his blow is ready he strikes back at once.
func counter_strike(e: Enemy) -> void:
	if dead or _attack_timer > 0.0 or e.dead:
		return
	_attack_timer = Config.HERO["attack_cooldown"]
	_strike(e)


func _strike(foe: Enemy) -> void:
	foe.take_damage(Config.hero_stat("damage", level) * (1.0 + Combat.holy_bonus(game, grid_pos)), self, "melee")  # (a High Priest blesses him)
	on_action("hit")
	if foe.dead:  # the last hit: a bonus
		on_action("kill")
	var tw := create_tween()
	var lunge := (Iso.to_world(foe.grid_pos) - position).normalized() * 6.0
	tw.tween_property(sprite, "position", lunge, 0.08)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.12)
	Sfx.play("hit", 0.25)


# --- levels -------------------------------------------------------------------------------------

func level_up_cost() -> int:
	return Config.hero_level_cost(level)


func can_level_up() -> bool:
	return level < Config.HERO_MAX_LEVEL - 1 and xp >= level_up_cost()


## Spends his XP on the next level: more HP (he gains the difference now) and
## a harder sword.
func level_up() -> bool:
	if not can_level_up():
		return false
	xp -= level_up_cost()
	var old_max := max_hp
	level += 1
	max_hp = Config.hero_stat("hp", level)
	if not dead:
		hp = minf(max_hp, hp + max_hp - old_max)
	village.events.info("The hero reached level %d: %d HP, %d damage" % [level + 1, int(max_hp), int(Config.hero_stat("damage", level))])
	float_text("Level %d!" % (level + 1), UiTheme.GOLD)
	play_level_up_fx()
	Sfx.play("build")
	queue_redraw()
	changed.emit()
	return true


func _process(delta: float) -> void:
	super(delta)
	_snore(delta)


## Resting in the village: Z's keep rising from his head and fade away, small
## to big ("Zzz" in motion). Co-op clients too: they know his mode.
func _snore(delta: float) -> void:
	if dead or mode != Mode.REST or grid_pos.distance_to(Vector2(base().center)) > 0.3:
		_snore_in = 0.0
		return
	_snore_in -= delta
	if _snore_in > 0.0:
		return
	_snore_in = 0.8
	var big := _snores % 3  # (z, z, Z)
	_snores += 1
	var z := Label.new()
	z.name = "Snore"
	z.text = "Z" if big == 2 else "z"
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.add_theme_font_size_override("font_size", 16 + 5 * big)
	z.add_theme_color_override("font_color", Color("e8ecff"))
	z.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.16, 0.8))
	z.add_theme_constant_override("outline_size", 5)
	z.position = Vector2(6.0, -64.0)
	z.modulate.a = 0.0
	add_child(z)
	var tw := z.create_tween().set_parallel()
	tw.tween_property(z, "position", Vector2(22.0, -104.0), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(z, "modulate:a", 1.0, 0.3)
	tw.tween_property(z, "modulate:a", 0.0, 1.0).set_delay(1.0)
	tw.chain().tween_callback(z.queue_free)


## Three glowing chevrons rise over his head (co-op clients play it too,
## when the host says his level went up).
func play_level_up_fx() -> void:
	var fx := Node2D.new()
	fx.name = "LevelUpFx"
	fx.position = Vector2(0, -52)
	add_child(fx)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Sprite2D.new()
	glow.texture = Art.tex("levelup_glow")
	glow.material = add
	glow.scale = Vector2.ONE * 0.75
	fx.add_child(glow)
	var chev := Sprite2D.new()
	chev.texture = Art.tex("levelup_chevrons")
	chev.scale = Vector2.ONE * 0.38
	fx.add_child(chev)
	var shine := Sprite2D.new()  # (the chevrons once more, added on top: they glow)
	shine.texture = chev.texture
	shine.material = add
	shine.scale = chev.scale * 1.08
	fx.add_child(shine)
	fx.modulate.a = 0.0
	var tw := fx.create_tween().set_parallel()
	tw.tween_property(fx, "position:y", -96.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 1.0, 0.25)
	tw.tween_property(glow, "scale", Vector2.ONE * 1.15, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shine, "modulate:a", 0.25, 0.4).set_delay(0.25)
	tw.chain().tween_property(fx, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(fx.queue_free)
	# He lights up for a moment as well.
	sprite.modulate = Color(1.6, 1.6, 1.2)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.6)


# --- monster camps -------------------------------------------------------------------------------

## Ordered from the camp's panel: go and clear it, whatever the mode.
func attack_camp(camp: MonsterCamp) -> void:
	if dead:
		return
	var job = jobs.get(mode)
	if job is HeroExploreJob:
		(job as HeroExploreJob)._drop_task()  # (keeps any loot he's carrying)
	camp_target = camp
	target = null
	_returning = false
	village.events.info("The hero sets off to clear a %s" % camp.display_name().to_lower())
	changed.emit()


func _attack_camp(delta: float) -> void:
	_attack_timer -= delta
	_think_timer -= delta
	if _think_timer <= 0.0 or not is_instance_valid(target) or target.dead:
		_think_timer = 0.3
		var best: Enemy = null
		var best_d := INF
		for e in camp_target.alive():
			var d := e.grid_pos.distance_to(grid_pos)
			if d < best_d:
				best_d = d
				best = e
		target = best
	if is_instance_valid(target) and not target.dead:
		_fight(delta)


func _end_camp() -> void:
	camp_target = null
	target = null
	_returning = false
	sprite.rotation = 0.0
	var job = jobs.get(mode)
	if job is HeroExploreJob and (job as HeroExploreJob).task == HeroExploreJob.Task.CARRYING:
		head_home()
	elif job != null:
		job.state = 0  # (the job picks up from where he stands)
	changed.emit()


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
	if train_pause > 0.0:
		# A unit just levelled up: a moment to change his mode and keep the XP.
		train_pause -= delta / maxf(Engine.time_scale, 0.001)
		sprite.rotation = 0.0
		if train_pause <= 0.0:
			changed.emit()
		return
	if xp <= 0:
		return  # nothing left to pass on
	_bob += delta * 9.0
	sprite.rotation = sin(_bob) * 0.2  # sparring
	_train_acc += Config.HERO["train_rate"] * delta
	var n := mini(int(_train_acc), xp)
	if n > 0:
		_train_acc -= n
		var unit := g.trainable_unit()
		var level_before := unit.level
		var used := village.army.train(unit, n)
		xp -= used
		if unit.level > level_before and xp > 0:
			train_pause = Config.HERO["train_pause"]
			_train_acc = 0.0
			sprite.rotation = 0.0
			village.events.info("%s reached level %d. The hero pauses %d s: change his mode now to keep his %d XP." % [unit.label().capitalize(), unit.level + 1, int(Config.HERO["train_pause"]), xp])
		changed.emit()


# --- health -----------------------------------------------------------------------------------

## (The hero heals his own way: see _regen.)
func _home_regen(_delta: float) -> void:
	pass


func take_damage(amount: float, source = null, _category: String = "pure") -> void:
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
	game.stats.on_hero_down(village)
	camp_target = null
	_drop_work()
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
	game.stats.on_hero_back(village)
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
			if train_pause > 0.0:
				return "pausing after a level-up (%d s): change his mode to keep his XP" % ceili(train_pause)
			return "training a %s" % training_at.garrison.display_name().to_lower() if is_instance_valid(training_at) and training_at.garrison else "walking to the training grounds"
	return jobs[mode].status()


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	_draw_hp_bar(30.0, -52.0, 5.0, hp / max_hp, Color("3a2a10"), Color("e8c040"))
