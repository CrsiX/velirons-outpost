class_name Civilian
extends Unit
## A villager. Lives in the village; hidden while resting at home.
## Subclasses implement their job as a small state machine in `_tick`.
## Every villager outside watches its surroundings (surveillance) and runs
## home when an enemy comes close; subclasses react in `_on_evade`.

signal died(civ: Civilian)

## Number within its role (see label()).
var uid := 0
## Co-op client: what the host says this villager is doing.
var net_status := ""
var role := ""
## A name of their own (a scenario's named villager: "Einar"); "" for none.
var given_name := ""
## The village this villager (or hero) belongs to; set before setup().
var village: Village
## The hut this villager lives in (every villager has exactly one).
var hut: Hut = null
var at_home := true
var dead := false
var max_hp := Config.CIVILIAN_HP
var hp := Config.CIVILIAN_HP
var rest_timer := 0.0
var evading := false
var _threat_timer := 0.0


func setup(p_game: Game, p_role: String) -> void:
	game = p_game
	role = p_role
	speed = Config.CIVILIANS[role]["speed"]
	_init_sprite("unit_" + role)
	set_grid_pos(Vector2(village.center))
	_set_home(true)
	rest_timer = randf_range(0.2, 1.5)
	add_to_group("observers")
	add_to_group("villagers")  # (enemies can hurt them; see take_damage)


func display_name() -> String:
	return Config.CIVILIANS[role]["name"]


## What it's doing, for panels (status(); on co-op clients as the host says).
func status_text() -> String:
	return net_status if game.is_client else status()


## Log name, numbered per role: "farmer 3"; a named villager by name.
func label() -> String:
	return given_name if given_name != "" else "%s %d" % [display_name().to_lower(), uid]


func _process(delta: float) -> void:
	if dead:
		return
	if game.is_client:
		net_follow(delta)  # the host simulates; we just follow
		return
	_home_regen(delta)
	if not at_home and not evading and wants_to_evade() and not inside_walls():
		_threat_timer -= delta
		if _threat_timer <= 0.0:
			_threat_timer = 0.25
			if enemy_nearby():
				_evade()
	if evading:
		if step_path(delta):
			arrive_home()
			evading = false
			rest_timer = Config.EVADE_REST
			_after_evade()
		return
	_tick(delta)


func enemy_nearby() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var g := node as Enemy
		if not g.dead and g.spec().get("scares", true) and g.grid_pos.distance_to(grid_pos) < Config.EVADE_RADIUS:
			return true
	return false


func _evade() -> void:
	village.events.debug("%s flees home from enemies" % label())
	_reveal_camps()
	evading = true
	_on_evade()
	sprite.rotation = 0.0
	float_text("Enemies!", Color("ff7a6a"))
	head_home()


## Fleeing from a monster camp's guards: the camp is uncovered (and found) for
## our village, so the hero can be sent to attack it even while the fog by it
## stays (explorers keep away from camps).
func _reveal_camps() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var g := node as Enemy
		if g.dead or g.grid_pos.distance_to(grid_pos) >= Config.EVADE_RADIUS or not (g.behavior is CampBehavior):
			continue
		var camp := (g.behavior as CampBehavior).camp as MapObject
		if is_instance_valid(camp) and not camp.is_found_by(village):
			game.fog.reveal(Vector2(camp.tile), Config.CAMP_REVEAL, village.id)
			camp.on_found(village.id, false)
			village.events.info("%s fled from %s" % [label().capitalize(), camp.label()])


## A loaded game (docs/save-design.md): out in the field (state, carried
## loads and claims as saved), it asks once what to do from here and does it.
## Roles override this; by default it walks home and starts again from there.
func resume_work() -> void:
	evading = true
	_on_evade()
	head_home()


## Override: false for units that stand and fight (the defending hero).
func wants_to_evade() -> bool:
	return true


## Override: called for every action worth experience (only the hero learns).
func on_action(_kind: String) -> void:
	pass


## The building this villager works at (farm, camp), or null. Roles with a
## workplace ("works_at" in Config.CIVILIANS) implement assign(b) / unassign() too.
func workplace() -> Building:
	return null


## Override: unexplored tile this unit is heading for, if exploring.
func exploring_target() -> Vector2i:
	return Vector2i(-1, -1)


## Override: drop or pause the current job when running from enemies.
func _on_evade() -> void:
	pass


## Override: back home safely after evading.
func _after_evade() -> void:
	pass


# --- surveillance (group "observers") -------------------------------------------

func sight_radius() -> float:
	return 0.0 if at_home or dead else Config.UNIT_SIGHT


func sight_center() -> Vector2:
	return grid_pos


## Override with the job logic.
func _tick(_delta: float) -> void:
	pass


## Short status line for the UI.
func status() -> String:
	if evading:
		return "fleeing from enemies"
	return "resting" if at_home else "out"


func _set_home(v: bool) -> void:
	at_home = v
	visible = not v


## A way from `from` to `to` for them (the hero keeps out of where she is barred).
func find_way(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return game.world.pathing.find_path(from, to)


## Leave the village towards `target`. Returns false when there's no way there.
func head_out(target: Vector2i) -> bool:
	var p := find_way(current_tile(), target)
	if p.is_empty():
		return false
	if at_home:
		set_grid_pos(Vector2(home_spot()))
		_set_home(false)
	follow(p)
	return true


## Where they step out from when they leave home, and go in when they get
## back (the village centre; the hero: her own post, a tent outside the walls
## in some scenarios; a resident: a home of their own, scenario 9's church).
func home_spot() -> Vector2i:
	return village.center


func head_home() -> void:
	var p := find_way(current_tile(), home_spot())
	if p.is_empty():
		arrive_home()  # stuck somewhere: just teleport home
		return
	follow(p)


func arrive_home() -> void:
	set_grid_pos(Vector2(home_spot()))
	_set_home(true)
	_set_moving(false)


## Out and about where enemies can get at it (not at home, not inside a mine,
## not inside the village walls).
func is_exposed() -> bool:
	return not at_home and not dead and visible and not inside_walls()


## Within the village walls: safe while no enemy is in there too
## (docs/siege-design.md §5.3), so villagers working there (a builder on a
## hut) carry on through an attack until the walls are broken.
func inside_walls() -> bool:
	var vid := game.map.village_at(current_tile())
	if vid < 0:
		return game.map.in_village(current_tile())  # (a ruin nobody plays)
	return not game.siege.breached(vid)


## Hurt by an enemy (a blow, a bite, a spell): at 0 HP the villager dies.
## Villagers never fight back; they flee (see _evade).
func take_damage(amount: float, source = null, _category: String = "pure") -> void:
	if not is_exposed():  # (nor if dead)
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.5, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		hp = 0.0
		village.population.kill(self, "from the attack of %s" % game.who(source), "enemies")
	elif not evading and wants_to_evade():
		_evade()


## At home, hurt villagers get their HP back.
func _home_regen(delta: float) -> void:
	if at_home and hp < max_hp:
		hp = minf(max_hp, hp + Config.CIVILIAN_REGEN * delta)
		queue_redraw()


func _draw() -> void:
	if dead or hp >= max_hp or at_home:
		return
	_draw_hp_bar(24.0, -44.0, 4.0, hp / max_hp, Color("3a2a10"), Color("8fd05a"))


## Called by Population when this villager is killed (or retires: `note` is
## what floats up). Subclasses release jobs.
func kill(note: String = "lost") -> void:
	if dead:
		return
	dead = true
	_release_jobs()
	died.emit(self)
	if visible:
		float_text("%s %s" % [display_name(), note], Color("ff7a6a") if note == "lost" else UiTheme.MUTED)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func _release_jobs() -> void:
	pass
