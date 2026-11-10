class_name Hero
extends Civilian
## The hero: part villager, part soldier, with a sword for close combat.
## Starts in the village centre; the player picks what she does (her mode):
##   Defend  - waits in the centre; when enemies come near the walls she goes out
##             and fights them (inside the walls first, then the nearest, then the strongest).
##   Build / Explore / Gather - the villager jobs, done a little less well.
##   Train   - at training grounds with a unit ready, passes her XP on to it;
##             without such grounds she defends instead, but drops any fight as
##             soon as a unit is ready to train.
##   Rest    - walks back to the village centre and goes into the town hall,
##             fighting nobody: out of reach and out of sight, she heals fast
##             there (a devastated hall: she rests in the centre instead).
##   Support - (co-op) walks to another village (`support_target`) and defends
##             it as in Defend mode: its gates, its centre. She keeps her XP,
##             heals idling in its centre, and when downed revives at home and
##             walks back. The village she helps can't give her orders.
## Whenever she idles in the village centre (any mode) she slowly gets her HP
## back: Config.HERO "rest_regen" per second after "rest_delay" seconds; inside
## the town hall (Rest) faster (hall_regen).
## Every action except training earns XP (Config.HERO_XP_PER_ACTION; the
## blow that kills an enemy earns a "kill" bonus on top). When her
## HP runs out she is downed: all XP is lost, she leaves no corpse, and she revives
## in the village centre when the wave is over (downed between waves: when the
## next one begins), still in the same mode.
## She has no hut, eats nothing and doesn't count as a villager.
## Equipment (docs/items-design.md): four slots (Config.ITEM_SLOTS); an empty
## slot is its default item, today's plain hero. Worn items change her by
## modifiers (`eq`), multiplied across slots; swaps only while she is idle at
## her post at home and the town hall stands (`swap_error`). Kept when downed.

signal changed
## Struck down (0 HP).
signal downed

enum Mode { DEFEND, BUILD, EXPLORE, GATHER, TRAIN, REST, SUPPORT }
const MODE_NAMES: Array[String] = ["Defend", "Build", "Explore", "Gather", "Train", "Rest", "Support"]
## The mode as a word for her panel's title ("Hero: defending").
const MODE_WORDS: Array[String] = ["defending", "building", "exploring", "gathering", "training", "resting", "supporting"]
## Icon per mode (art/mode_*.svg).
const MODE_ICONS: Array[String] = ["mode_defend", "mode_build", "mode_explore", "mode_gather", "mode_train", "mode_rest", "mode_support"]

var mode := Mode.DEFEND
var xp := 0
## 0-based: level 1 ... Config.HERO_MAX_LEVEL. Bought with her own XP; kept when downed.
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
## Support mode: the village she goes to defend.
var support_target: Village = null
## Seconds she has been idling in the village centre (see _regen).
var _idle_time := 0.0
## Resting: the next snore's Z in ... s.
var _snore_in := 0.0
var _snores := 0
## Real seconds left of her pause after a unit levelled up (Train).
var train_pause := 0.0
## The monster camp she was ordered to clear (docs/world-design.md §9.3).
var camp_target: MonsterCamp = null
## Seconds she has had none of its monsters she could get to (HERO camp_give_up).
var _camp_stuck := 0.0
## A warrior's war cry (Combat.war_cry): her sword is faster until Game.clock reaches cry_until.
var cry_bonus := 0.0
var cry_until := -1.0
## What she wears: slot -> Config.ITEMS key; a slot not in it holds its default.
var equipped := {}
## Seconds until her net (an accessory) can be thrown again.
var net_cooldown := 0.0


func setup_hero(p_game: Game, p_village: Village) -> void:
	game = p_game
	village = p_village
	role = "hero"
	var spec: Dictionary = Config.HERO
	speed = walk_speed()
	max_hp = spec["hp"]
	hp = max_hp
	_init_sprite(art_name(village.color, game.villages.size()))
	UnitFx.add_halo(sprite, game, func() -> Vector2: return grid_pos)
	UnitFx.add_cry_mark(sprite, game, func() -> Object: return self)
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
	# Back when a wave is over, or (downed between waves) when the next one begins.
	for sig: Signal in [game.waves.wave_finished, game.waves.wave_started]:
		sig.connect(func(_n: int) -> void:
			if dead:
				revive())


func display_name() -> String:
	return given_name if given_name != "" else Config.HERO["name"]


## "the hero"; in a scenario her name ("Brenna").
func label() -> String:
	return given_name if given_name != "" else "the hero"


# --- modes ---------------------------------------------------------------------------

func set_mode(m: int) -> void:
	if camp_target != null:  # (a new order: the camp can wait)
		village.events.info("The hero gives up on the %s" % camp_target.display_name().to_lower() if is_instance_valid(camp_target) else "The hero gives up on the camp")
		_end_camp()
	if m == mode:
		return
	_leave_mode()
	mode = m as Mode
	rest_timer = 0.0  # (no rest first: the new mode starts at once)
	_think_timer = 0.0  # (Defend looks for an enemy at once; the blow's cooldown stays)
	_stop_evading()
	village.events.debug("hero mode: %s" % mode_name())
	changed.emit()


func mode_name() -> String:
	return MODE_NAMES[mode]


## Training grounds where a unit is ready to learn from her, or null.
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


## What she is actually doing: Train falls back to Defend without ready grounds.
func effective_mode() -> Mode:
	if mode == Mode.TRAIN and ready_grounds() == null:
		return Mode.DEFEND
	return mode


## Where she lives instead of her village's centre (scenario 7: her tent
## outside the walls until Fiona lets her in); (-1, -1): the centre.
var home_override := Vector2i(-1, -1)
## Tiles she may not walk into (scenario 9: the village, while the priests
## shut her out; an empty rect: none). Her ways go round it, and she leaves
## enemies in it alone.
## Resting inside her town hall (Rest mode; _update_hall): hidden, out of reach.
var in_hall := false
## Her few steps between her post and the hall's door (TownHall.door_spot),
## the mode's own walking paused meanwhile: 1 going in, -1 coming out, 0 none.
var _door_walk := 0
## The hall was looked at once: a new or loaded game starts her inside at once.
var _hall_checked := false
## Her fast healing in there is under way (for the log: _note_hall_heal).
var _hall_healing := false
var barred := Rect2i()


func find_way(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if eq_flag("free_walk") and not barred.has_area():
		return game.world.pathing.free_path(from, to)  # (feather boots)
	return game.world.pathing.find_path_outside(from, to, barred)


## Feather boots: no ground slows her.
func _walk_factor() -> float:
	return 1.0 if eq_flag("free_walk") else super._walk_factor()


## Heavy steel boots: nothing moves or holds her (Unit.force_move).
func immovable() -> bool:
	return eq_flag("immovable")


## Feather boots: an octopus can pull her into deep water, but it can't drown her.
func drown_proof() -> bool:
	return eq_flag("free_walk")


## Her walking speed (Config.HERO), times what she wears.
func walk_speed() -> float:
	return float(Config.HERO["speed"]) * eq("speed")


func home_spot() -> Vector2i:
	return home()


## Her post: where she stands guard, rests, heals and revives (the centre of
## base(), or home_override at home).
func home() -> Vector2i:
	if home_override != Vector2i(-1, -1) and base() == village:
		return home_override
	return base().center


## Walks back to her post (home()).
func head_home() -> void:
	var p := find_way(current_tile(), home())
	if p.is_empty():
		arrive_home()
		return
	follow(p)


## Where she stands guard and rests: the supported village in Support mode,
## else her own.
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


## A new order while she runs from enemies takes effect at once, wherever she
## is: she stops running unless her new mode is a villager job and an enemy is
## still close (then that job flees on, as it would anyway).
func _stop_evading() -> void:
	if not evading:
		return
	if wants_to_evade() and not inside_walls() and enemy_nearby():
		_on_evade()
		return
	evading = false
	path = PackedVector2Array()
	path_index = 0
	_set_moving(false)


## Lets go of whatever she was doing: her mode's job, training, a fight.
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

## She stays visible in the village centre (villagers vanish into their huts).
## Back at her post: her own village centre, or the one she supports.
func arrive_home() -> void:
	set_grid_pos(Vector2(home()))
	_set_home(true)
	_set_moving(false)


func _set_home(v: bool) -> void:
	at_home = v
	visible = not dead and not in_hall


## Runs away (not home) from enemies only while exploring (Config.FLEE).
func flees_away() -> bool:
	return mode == Mode.EXPLORE and super.flees_away()


## Only runs from enemies while doing villager jobs; a defender stands and fights.
func wants_to_evade() -> bool:
	return camp_target == null and effective_mode() in [Mode.BUILD, Mode.EXPLORE, Mode.GATHER]


func on_action(kind: String) -> void:
	var n := roundi(int(Config.HERO_XP_PER_ACTION.get(kind, 0)) * eq("xp"))  # (a scholar's tome)
	xp += n
	game.stats.count(village, "hero.xp", n)
	game.stats.count(village, "hero.xp." + kind, n)
	changed.emit()


func exploring_target() -> Vector2i:
	return jobs[Mode.EXPLORE].exploring_target() if mode == Mode.EXPLORE else Vector2i(-1, -1)


## After a load: her mode's villager job asks what to do from where she
## stands; the other modes (and a camp to clear) decide that every frame anyway.
func resume_work() -> void:
	if camp_target == null and jobs.has(mode):
		jobs[mode].resume()


func _on_evade() -> void:
	if jobs.has(mode):
		jobs[mode].on_evade()


func _after_evade() -> void:
	if jobs.has(mode):
		jobs[mode].after_evade()


func sight_radius() -> float:
	return 0.0 if at_home or dead else float(Config.HERO["sight"])


func _tick(delta: float) -> void:
	if _door_walk != 0 and _door_step(delta):
		return
	if camp_target != null:
		if is_instance_valid(camp_target) and not camp_target.cleared and not camp_target.alive().is_empty():
			_update_hall()  # (out of the hall first, if she rested there)
			_attack_camp(delta)
			_regen(delta)
			return
		_end_camp()
	match mode:
		Mode.DEFEND:
			_defend(delta)
		Mode.BUILD, Mode.EXPLORE, Mode.GATHER:
			jobs[mode].tick(delta)
			if _job_idle() and not at_home:
				_return_home(delta)  # switched to it out in the field, nothing to do yet: home
			else:
				_returning = false
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
			_defend(delta)  # relative to base(): the village she supports
	_update_hall()
	_regen(delta)


## Her villager job waits for work (resting), with no task of its own.
func _job_idle() -> bool:
	var job = jobs[mode]
	if job is HeroExploreJob and (job as HeroExploreJob).task != HeroExploreJob.Task.NONE:
		return false
	return job.state == 0


## Idle in the village centre: after a short while the HP comes back, slowly
## there, fast inside the town hall (hall_regen). A hearth stone adds to both.
func _regen(delta: float) -> void:
	var idle := at_home and not evading and not is_instance_valid(target) and grid_pos.distance_to(Vector2(home())) < 0.2
	_idle_time = _idle_time + delta if idle else 0.0
	_note_hall_heal(in_hall and _idle_time >= Config.HERO["rest_delay"] and hp < max_hp)
	if _idle_time < Config.HERO["rest_delay"] or hp >= max_hp:
		return
	hp = minf(max_hp, hp + (hall_regen() if in_hall else float(Config.HERO["rest_regen"])) * delta)
	queue_redraw()
	hp = minf(max_hp, hp + village.relic_bonus("hero_rest") * delta)  # (a hearth stone)
	if hp >= max_hp:
		village.events.debug("the hero is fully rested (%d HP)" % int(max_hp))
	changed.emit()


## Logs (Debug) when her fast healing inside the town hall starts and stops, and why it stopped.
func _note_hall_heal(on: bool) -> void:
	if on == _hall_healing:
		return
	_hall_healing = on
	if on:
		village.events.debug("the hero starts healing in the town hall (%.1f HP/s, %d / %d HP)" % [hall_regen() + village.relic_bonus("hero_rest"), int(hp), int(max_hp)])
		return
	var why := "full HP" if hp >= max_hp else ("she is down" if dead else ("she left it" if not in_hall else "interrupted"))
	village.events.debug("the hero stops healing in the town hall: %s (%d / %d HP)" % [why, int(hp), int(max_hp)])


## Fights with a melee weapon (anything but thrown axes): what critical hits need.
func has_melee_weapon() -> bool:
	return not throws()


## HP per second resting inside the town hall: max(max HP x hall_regen_share, hall_regen_min).
func hall_regen() -> float:
	return maxf(max_hp * float(Config.HERO["hall_regen_share"]), float(Config.HERO["hall_regen_min"]))


## Rest mode at home in her own village goes into its town hall (unless it is
## devastated); any other mode, an order or a devastated hall brings her out.
## She walks from her post to its door and in, and comes out of the door
## (TownHall.door_spot); a new or loaded game starts her inside at once.
## Inside she is out of sight and out of every enemy's reach, and her place is
## her post (resting, swapping equipment).
func _update_hall() -> void:
	var first := not _hall_checked
	_hall_checked = true
	if _door_walk != 0:
		return
	var want := _hall_wanted()
	if in_hall and not want:
		_set_in_hall(false)
		_walk_out()
	elif want and not in_hall and grid_pos.distance_to(Vector2(home())) < 0.2:
		if first:
			_set_in_hall(true)
		else:
			_walk_in()


## Should she be inside the hall (wherever she stands at home)?
func _hall_wanted() -> bool:
	var h := village.town_hall()
	return mode == Mode.REST and camp_target == null and not dead and at_home and not evading \
		and base() == village and home_override == Vector2i(-1, -1) and is_instance_valid(h) and not h.devastated


## From her post to the path in front of the door, then to the door.
func _walk_in() -> void:
	var h := village.town_hall()
	follow(PackedVector2Array([grid_pos, h.door_front(), h.door_spot()]))
	_door_walk = 1


## Out of the door onto the path in front of it; from there her mode walks her on.
func _walk_out() -> void:
	var h := village.town_hall()
	if not is_instance_valid(h):
		return
	set_grid_pos(h.door_spot())
	_set_home(false)
	_returning = false
	follow(PackedVector2Array([h.door_spot(), h.door_front()]))
	_door_walk = -1


## A step of the walk to or from the door; false when it is called off (on her
## way in she isn't wanted inside any more: she goes on from where she stands).
func _door_step(delta: float) -> bool:
	if _door_walk > 0 and not _hall_wanted():
		_door_walk = 0
		path = PackedVector2Array()
		path_index = 0
		_returning = false
		_set_home(false)
		return false
	if step_path(delta):
		if _door_walk > 0:
			_set_in_hall(true)
			set_grid_pos(Vector2(home()))  # (inside, her place is her post)
		_door_walk = 0
	return true


func _set_in_hall(on: bool) -> void:
	in_hall = on
	visible = not on and not dead
	for group in ["melee_defenders", "villagers"]:
		if on:
			remove_from_group(group)
		elif not dead:
			add_to_group(group)
	village.events.debug("the hero %s the town hall" % ("goes into" if on else "comes out of"))
	changed.emit()


# --- Defend -----------------------------------------------------------------------------------

func _defend(delta: float) -> void:
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
	if not can_hit(target):
		target = null  # it dived, or it's out of a sword's reach
		return
	if at_home:
		_set_home(false)
	var dist := target.grid_pos.distance_to(grid_pos)
	if dist <= reach_to(target):
		_set_moving(false)
		face(target.grid_pos)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown()
			_strike(target)
	else:
		if path_index >= path.size() or target.current_tile() != _chase_tile:
			_chase()
		if target != null:
			step_path(delta)


## Walks back to the village centre (Defend re-targets on the way, see
## _pick_enemy). Never teleports: a chase path may still be half walked.
func _return_home(delta: float) -> void:
	if at_home and grid_pos.distance_to(Vector2(home())) > 0.2:
		_set_home(false)  # her post moved (Support): set off
	if not at_home:
		if not _returning:
			_returning = true
			_walk_home()
		if step_path(delta):
			if grid_pos.distance_to(Vector2(home())) < 0.1:
				_returning = false
				arrive_home()
			else:
				_walk_home()  # that path ended elsewhere: plan again


## A walkable path from here to the village centre; straight across if none.
func _walk_home() -> void:
	var to := home()
	var centre := Vector2(to)
	var p := find_way(current_tile(), to)
	if p.is_empty():
		# Standing on a tile the pathing doesn't allow (e.g. mid-chase on a
		# corner): try from a walkable neighbour.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			p = find_way(current_tile() + d, to)
			if not p.is_empty():
				p.insert(0, grid_pos)
				break
	if p.is_empty():
		p = PackedVector2Array([grid_pos, centre])
	p[p.size() - 1] = centre
	follow(p)


## Distance from `p` (grid) to the nearest tile of `r` (0 inside).
## The hero's art: crimson cape and plume (unit_hero) when she is the only
## hero, else her village's colour (unit_hero_c<i>, i the colour's index in
## Config.VILLAGE_COLORS), so each player tells their own apart and every peer
## shows the same hero alike. A colour not in the list keeps the crimson.
static func art_name(color: Color, village_count: int) -> String:
	if village_count > 1:
		for i in Config.VILLAGE_COLORS.size():
			var c := Config.VILLAGE_COLORS[i]
			if absf(c.r - color.r) + absf(c.g - color.g) + absf(c.b - color.b) < 0.02:
				return "unit_hero_c%d" % i
	return "unit_hero"


static func rect_distance(r: Rect2i, p: Vector2) -> float:
	var cx := clampf(p.x, r.position.x, r.end.x - 1)
	var cy := clampf(p.y, r.position.y, r.end.y - 1)
	return p.distance_to(Vector2(cx, cy))


## Enemies near the walls (or near him, within his leash): inside the walls
## first, then the nearest, then the strongest; spider eggs last.
func _pick_enemy() -> Enemy:
	var best: Enemy = null
	var best_key := Vector2(INF, INF)
	var centre := Vector2(home())
	# Beyond her leash (another mode took her out there): she still takes on
	# what is within her sight on her way back.
	var out_far := grid_pos.distance_to(centre) > Config.HERO["leash"]
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.faded or not e.hurt_by(weapon_category()):
			continue  # (a ghost: faded, or her weapon can't hurt it)
		if (e.flies() and not reaches_flyers()) or not can_hit(e):
			continue  # (flyers: out of a blade's reach, she only hits back; under water or out at sea: none)
		if barred.has_area() and barred.has_point(e.current_tile()):
			continue  # (where she may not go)
		var near_me := not at_home and e.grid_pos.distance_to(grid_pos) <= Config.HERO["sight"]
		if e.grid_pos.distance_to(centre) > Config.HERO["leash"] and not (out_far and near_me):
			continue
		# Near the wall ring (docs/siege-design.md §6); inside the walls first.
		var inside := base().rect.has_point(e.current_tile())
		var near_walls := inside or Hero.rect_distance(base().rect, e.grid_pos) <= Config.HERO["alert_radius"]
		if not (near_walls or near_me):
			continue
		var key := Vector2(floorf(e.grid_pos.distance_to(grid_pos)) - (1000.0 if inside else 0.0) + (Enemy.LOW_PRIORITY_TILES * 3.0 if e.low_priority() else 0.0), -e.max_hp)
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = e
	if best != null:
		return best
	# Last priority: rats on her village's farms, however far out (no leash).
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if not e.targetable() or not (e.behavior is RatBehavior):
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
	var stand := game.world.pathing.stand_near(_chase_tile, grid_pos)  # (in deep water: from the shore)
	var p := find_way(current_tile(), stand) if stand != Vector2i(-1, -1) else PackedVector2Array()
	if p.is_empty():
		target = null
		return
	p[0] = grid_pos
	p[p.size() - 1] = target.grid_pos if stand == _chase_tile else Vector2(stand)
	follow(p)


## A flyer hit her: if her blow is ready she strikes back at once.
func counter_strike(e: Enemy) -> void:
	if dead or _attack_timer > 0.0 or e.dead or not e.hurt_by(weapon_category()):
		return
	_attack_timer = attack_cooldown()
	_strike(e)


func _strike(foe: Enemy) -> void:
	var crit := Combat.critical(game, village, foe) if has_melee_weapon() else 1.0  # (Eye for vital points)
	var dmg := blow_damage() * (1.0 + Combat.holy_bonus(game, grid_pos)) * crit  # (a High Priest blesses her)
	if throws():
		_throw(foe, dmg)
	else:
		_land_blow(foe, dmg)
	var tw := create_tween()
	var lunge := (Iso.to_world(foe.grid_pos) - position).normalized() * 6.0
	tw.tween_property(sprite, "position", lunge, 0.08)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.12)
	village.sound("hit", 0.25)


# --- levels -------------------------------------------------------------------------------------

func level_up_cost() -> int:
	return Config.hero_level_cost(level)


func can_level_up() -> bool:
	return level < Config.HERO_MAX_LEVEL - 1 and xp >= level_up_cost()


## Spends her XP on the next level: more HP (she gains the difference now) and
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
	village.sound("build")
	queue_redraw()
	changed.emit()
	return true


func _process(delta: float) -> void:
	if not dead and not game.is_client:
		# Her blow's cooldown runs in every mode, also while she flees, and no
		# mode change resets it: switching modes never gives her an extra blow.
		_attack_timer -= delta * Combat.haste(game, self, Vector2.INF if immovable() else grid_pos)  # (heavy boots: no song slows her)
		_tick_net(delta)
		if is_instance_valid(held_by) and not held_by.dead:
			# An octopus's arm holds her: she fights it, whatever her mode, even fleeing.
			target = held_by as Enemy
			_fight(delta)
			return
	super(delta)
	_snore(delta)


## Resting in the village: Z's keep rising from her head and fade away, small
## to big ("Zzz" in motion). Co-op clients too: they know her mode.
func _snore(delta: float) -> void:
	if dead or mode != Mode.REST or grid_pos.distance_to(Vector2(home())) > 0.3:
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
	var rise := Vector2(16.0, -40.0)
	var hall := village.town_hall()
	if in_hall and is_instance_valid(hall):  # (she is inside: the Z's rise from its roof)
		z.position = Vector2(-30.0, -float(Art.info(hall._art()).get("roof", 110.0)) + 10.0)
		hall.add_child(z)
	else:
		add_child(z)
	var tw := z.create_tween().set_parallel()
	tw.tween_property(z, "position", z.position + rise, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(z, "modulate:a", 1.0, 0.3)
	tw.tween_property(z, "modulate:a", 0.0, 1.0).set_delay(1.0)
	tw.chain().tween_callback(z.queue_free)


## Three glowing chevrons rise over her head (co-op clients play it too,
## when the host says her level went up).
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
	# She lights up for a moment as well.
	sprite.modulate = Color(1.6, 1.6, 1.2)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.6)


# --- monster camps -------------------------------------------------------------------------------

## Ordered from the camp's panel: go and clear it, whatever the mode.
func attack_camp(camp: MonsterCamp) -> void:
	if dead:
		return
	var job = jobs.get(mode)
	if job is HeroExploreJob:
		(job as HeroExploreJob)._drop_task()  # (keeps any loot she's carrying)
	camp_target = camp
	target = null
	_returning = false
	_stop_evading()
	village.events.info("The hero sets off to clear a %s" % camp.display_name().to_lower())
	changed.emit()


func _attack_camp(delta: float) -> void:
	# None of its monsters she can get to for a while: she gives up the order.
	_camp_stuck = _camp_stuck + delta if not is_instance_valid(target) or target.dead else 0.0
	if _camp_stuck >= float(Config.HERO["camp_give_up"]):
		village.events.info("The hero can't get at the %s's monsters and gives up" % camp_target.display_name().to_lower())
		_end_camp()
		return
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
	_camp_stuck = 0.0
	target = null
	_returning = false
	sprite.rotation = 0.0
	var job = jobs.get(mode)
	if job is HeroExploreJob and (job as HeroExploreJob).task == HeroExploreJob.Task.CARRYING:
		head_home()
	elif job != null:
		job.state = 0  # (the job picks up from where she stands)
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
		# A unit just levelled up: a moment to change her mode and keep the XP.
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
			village.events.info("%s reached level %d. The hero pauses %d s: change her mode now to keep her %d XP." % [unit.label().capitalize(), unit.level + 1, int(Config.HERO["train_pause"]), xp])
		changed.emit()


# --- health -----------------------------------------------------------------------------------

## (The hero heals her own way: see _regen.)
func _home_regen(_delta: float) -> void:
	pass


## A hit on her: what she wears may block it, scale it or strike back
## (docs/items-design.md §6); "pure" (drowning, a drain) is never changed.
func take_damage(amount: float, source = null, category: String = "pure") -> void:
	if dead:
		return
	if category != "pure":
		var block := eq_block(category)
		if block > 0.0 and randf() < block:  # (no roll without a shield: the defaults leave the random sequence alone)
			float_text("Blocked", Color("cfd8e0"))
			return
		var foe: Enemy = source if is_instance_valid(source) and source is Enemy else null
		if foe != null and category == "melee" and eq("thorns", 0.0) > 0.0 and not foe.dead:
			foe.take_damage(amount * eq("thorns", 0.0), self, "pure")  # (thorn mail)
		amount *= eq("taken") * eq_resist(category)
		if foe != null and foe.flies():
			amount *= eq("flyer_taken")
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
	in_hall = false
	_door_walk = 0
	xp = 0
	hp = 0.0
	remove_from_group("melee_defenders")
	visible = false
	path = PackedVector2Array()
	village.sound("death")
	changed.emit()
	downed.emit()


func revive() -> void:
	dead = false
	hp = max_hp
	set_grid_pos(Vector2(village.center if home_override == Vector2i(-1, -1) else home_override))  # (at home, even in Support mode)
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
		return "downed - revives when the wave is over" if game.waves.in_progress() else "downed - revives when the next wave begins"
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
			var where := "in the town hall" if in_hall else "in the centre"
			return "resting %s (HP recovering)" % where if hp < max_hp else "resting %s (full HP)" % where
		Mode.TRAIN:
			if xp <= 0:
				return "at the training grounds: no XP left to pass on"
			if train_pause > 0.0:
				return "pausing after a level-up (%d s): change her mode to keep her XP" % ceili(train_pause)
			return "training a %s" % training_at.garrison.display_name().to_lower() if is_instance_valid(training_at) and training_at.garrison else "walking to the training grounds"
	return jobs[mode].status()


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	_draw_hp_bar(30.0, -52.0, 5.0, hp / max_hp, Color("3a2a10"), Color("e8c040"))


# --- equipment (docs/items-design.md) -------------------------------------------------------

## The item in `slot`: what she wears there, or its default.
func worn(slot: String) -> String:
	return str(equipped.get(slot, Config.ITEM_DEFAULTS[slot]))


## A modifier `key` of what she wears (Config.ITEMS): factors multiply across
## the slots; a slot without it counts `none` (1: no change; 0 for a share).
func eq(key: String, none := 1.0) -> float:
	var f := 1.0
	var any := false
	for slot: String in equipped:
		var it: Dictionary = Config.ITEMS[equipped[slot]]
		if it.has(key) and typeof(it[key]) in [TYPE_FLOAT, TYPE_INT]:
			f *= float(it[key])
			any = true
	return f if any else none


func eq_flag(key: String) -> bool:
	for slot: String in equipped:
		if Config.ITEMS[equipped[slot]].get(key, false):
			return true
	return false


## The first worn item's value for `key` (a list or table), or `none`.
func eq_value(key: String, none: Variant = null) -> Variant:
	for slot: String in Config.ITEM_SLOTS:
		if equipped.has(slot) and Config.ITEMS[equipped[slot]].has(key):
			return Config.ITEMS[equipped[slot]][key]
	return none


## The share of a hit of `category` she still takes (resist tables multiply).
func eq_resist(category: String) -> float:
	var f := 1.0
	for slot: String in equipped:
		f *= float((Config.ITEMS[equipped[slot]].get("resist", {}) as Dictionary).get(category, 1.0))
	return f


## The chance a hit of `category` is blocked whole (several blocks: each gets its chance).
func eq_block(category: String) -> float:
	var through := 1.0
	for slot: String in equipped:
		through *= 1.0 - float((Config.ITEMS[equipped[slot]].get("block", {}) as Dictionary).get(category, 0.0))
	return 1.0 - through


## Her weapon's attack (Config.ATTACKS), or {} for her plain sword.
func weapon_attack() -> Dictionary:
	var a := str(Config.ITEMS[worn("weapon")].get("attack", ""))
	return Config.ATTACKS[a] if a != "" else {}


func weapon_category() -> String:
	return str(weapon_attack().get("category", Config.HERO["category"]))


## Thrown axes: a ranged weapon.
func throws() -> bool:
	return str(weapon_attack().get("projectile", "")) != ""


func reaches_flyers() -> bool:
	return throws() or eq_flag("hits_flyers")


## Can she go for `e` with her weapon from where she stands? A thrown axe:
## anything up and in sight; a blade: Enemy.melee_ok (a burning one reaches a siren in water).
## A blade with no shore reach (the great axe) has nothing on deep water as a
## target unless it is in her reach now (feather boots: she walks out to it).
func can_hit(e: Enemy) -> bool:
	if throws():
		return e.targetable()
	if not e.melee_ok(grid_pos, eq_flag("flame")):
		return false
	if eq_flag("no_shore_reach") and not eq_flag("free_walk") and e.on_deep():
		return e.grid_pos.distance_to(grid_pos) <= reach_to(e)
	return true


## How close she must be to strike `e`. A blade reaches one on deep water from
## the shore (Enemy.melee_reach), except one with no shore reach (the great axe).
func reach_to(e: Enemy) -> float:
	if throws():
		return float(Config.ITEMS[worn("weapon")]["range"])
	var base := float(Config.HERO["attack_range"]) * eq("reach")
	return base if eq_flag("no_shore_reach") else e.melee_reach(base)


func attack_cooldown() -> float:
	return float(Config.HERO["attack_cooldown"]) * eq("cooldown")


## One blow's damage before blessings and crits: her level's, times what she wears.
func blow_damage() -> float:
	return Config.hero_stat("damage", level) * eq("damage")


## A blade's blow on `foe` (and, with a great axe, everyone around her; with a
## mace, the one behind it): damage, a poison dose, healing from what it dealt.
func _land_blow(foe: Enemy, dmg: float) -> void:
	var cat := weapon_category()
	var hits: Array[Array] = [[foe, dmg]]
	var circle: Array = eq_value("circle", [])
	if not circle.is_empty():
		hits.clear()
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e.grid_pos.distance_to(grid_pos) <= float(circle[0]) and e.hurt_by(cat) and can_hit(e) and (reaches_flyers() or not e.flies() or e == foe):
				hits.append([e, dmg * float(circle[1])])
	var behind: Array = eq_value("behind", [])
	if not behind.is_empty():
		var b := _behind(foe, float(behind[1]))
		if b != null:
			hits.append([b, dmg * float(behind[0])])
	var dealt := 0.0
	for h in hits:
		var e: Enemy = h[0]
		if e.dead:
			continue
		var before := e.hp + e.mount_hp
		e.take_damage(h[1], self, cat)
		dealt += before - maxf(e.hp, 0.0) - maxf(e.mount_hp, 0.0)
		if eq("poison", 0.0) > 0.0 and not e.dead:
			Poison.give(e, float(h[1]) * eq("poison", 0.0), self)
		on_action("hit")
		if e.dead:  # the last hit: a bonus
			on_action("kill")
	if eq("lifesteal", 0.0) > 0.0 and dealt > 0.0:
		hp = minf(max_hp, hp + dealt * eq("lifesteal", 0.0))
		queue_redraw()
		changed.emit()


## The enemy behind `foe` seen from her: the nearest one within `reach` of the
## spot a tile beyond it, on the line from her through it; null if none.
func _behind(foe: Enemy, reach: float) -> Enemy:
	var dir := (foe.grid_pos - grid_pos).normalized()
	if dir == Vector2.ZERO:
		return null
	var spot := foe.grid_pos + dir
	var best: Enemy = null
	var best_d := reach
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == foe or not e.hurt_by(weapon_category()) or not can_hit(e) or (e.flies() and not reaches_flyers()):
			continue
		var d := e.grid_pos.distance_to(spot)
		if d <= best_d:
			best_d = d
			best = e
	return best


## Thrown axes: a projectile at `foe` that strikes when it lands.
func _throw(foe: Enemy, dmg: float) -> void:
	var a := weapon_attack()
	var shot := Shot.new()
	shot.source = self
	game.world.effects.add_child(shot)
	var from := position + Vector2(0, -30)
	shot.launch(a, from, foe, func(t, _at: Vector2) -> void:
		if not is_instance_valid(t) or t.dead or not (t as Enemy).targetable():
			return
		(t as Enemy).take_damage(dmg, self if is_instance_valid(self) else null, str(a["category"]))
		if is_instance_valid(self) and not dead:
			on_action("hit")
			if t.dead:
				on_action("kill"))
	if game.replicator and game.replicator.hosting:
		game.replicator.shot(str(Config.ITEMS[worn("weapon")]["attack"]), from, foe.hit_point())


## Her net (an accessory) on its cooldown: thrown at her target when it is in range.
func _tick_net(delta: float) -> void:
	var n: Array = eq_value("net", [])
	if n.is_empty():
		return
	net_cooldown = maxf(net_cooldown - delta, 0.0)
	if net_cooldown > 0.0 or not is_instance_valid(target) or target.dead or in_hall:
		return
	if target.grid_pos.distance_to(grid_pos) > float(n[1]) or not target.can_be_netted():
		return
	target.net(float(n[2]))
	net_cooldown = float(n[0])
	village.events.debug("the hero nets %s" % target.label())


## Ghosts within this many tiles of her show themselves (a lantern); 0: none.
func ghost_light() -> float:
	return 0.0 if dead or in_hall else eq("ghost_light", 0.0)


## Why she can't change her equipment now ("" when she can): only while she is
## idle at her post at home (not downed, fleeing, fighting or on an order) and
## its town hall stands and isn't devastated.
func swap_error() -> String:
	if not game.items_enabled():
		return "There is no equipment here"
	if dead:
		return "The hero is down"
	if not village.armoury.is_open():
		return "The town hall is devastated: the armoury is closed"
	if camp_target != null or evading or is_instance_valid(target) or base() != village \
			or not at_home or grid_pos.distance_to(Vector2(home())) > 0.3:
		return "She changes equipment only while idle at her post in the village"
	return ""


## Puts on `id` (Config.ITEMS); whatever was in its slot goes to the armoury.
## The caller checks the armoury holds it and swap_error.
func equip(id: String) -> void:
	var slot := str(Config.ITEMS[id]["slot"])
	village.armoury.take(id)
	var old := worn(slot)
	equipped[slot] = id
	if old != Config.ITEM_DEFAULTS[slot]:
		village.armoury.items.append(old)  # (the place `id` left: never over the cap)
		village.armoury.changed.emit()
	village.events.info("The hero puts on the %s" % str(Config.ITEMS[id]["name"]).to_lower())
	apply_equipment()


## Takes off what is in `slot` (back to its default); it goes to the armoury.
func unequip(slot: String) -> void:
	var old := worn(slot)
	equipped.erase(slot)
	village.armoury.add(old)
	village.events.info("The hero takes off the %s" % str(Config.ITEMS[old]["name"]).to_lower())
	apply_equipment()


## What she wears applies to what is set up front: walking speed, her jobs.
func apply_equipment() -> void:
	var spec: Dictionary = Config.HERO
	speed = walk_speed()
	(jobs[Mode.BUILD] as BuildJob).efficiency = float(spec["build_efficiency"]) * eq("build")
	(jobs[Mode.EXPLORE] as HeroExploreJob).reveal = float(spec["explore_reveal"]) * eq("explore")
	(jobs[Mode.GATHER] as GatherJob).capacity = roundi(int(spec["gather_capacity"]) * eq("gather"))
	changed.emit()
