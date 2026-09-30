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


## Log name, numbered per role: "farmer 3".
func label() -> String:
	return "%s %d" % [display_name().to_lower(), uid]


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
		if not g.dead and g.grid_pos.distance_to(grid_pos) < Config.EVADE_RADIUS:
			return true
	return false


func _evade() -> void:
	village.events.debug("%s flees home from enemies" % label())
	evading = true
	_on_evade()
	sprite.rotation = 0.0
	float_text("Enemies!", Color("ff7a6a"))
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


## Leave the village towards `target`. Returns false when there's no way there.
func head_out(target: Vector2i) -> bool:
	var p := game.world.pathing.find_path(current_tile(), target)
	if p.is_empty():
		return false
	if at_home:
		set_grid_pos(Vector2(village.center))
		_set_home(false)
	follow(p)
	return true


func head_home() -> void:
	var p := game.world.pathing.find_path(current_tile(), village.center)
	if p.is_empty():
		arrive_home()  # stuck somewhere: just teleport home
		return
	follow(p)


func arrive_home() -> void:
	set_grid_pos(Vector2(village.center))
	_set_home(true)
	_set_moving(false)


## Out and about where enemies can get at it (not at home, not inside a mine,
## not inside the village walls).
func is_exposed() -> bool:
	return not at_home and not dead and visible and not inside_walls()


## Within the village walls: always safe. Enemies never get in (at a gate
## they burn a hut, or a rat eats food, and are gone), so villagers working
## there (a builder on a hut) carry on through an attack.
func inside_walls() -> bool:
	return game.map.in_village(current_tile())


## Hurt by an enemy (a blow, a bite, a spell): at 0 HP the villager dies.
## Villagers never fight back; they flee (see _evade).
func take_damage(amount: float, source = null) -> void:
	if not is_exposed():  # (nor if dead)
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.5, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		hp = 0.0
		village.population.kill(self, "from the attack of %s" % game.who(source))
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


## Called by Population when this villager is killed. Subclasses release jobs.
func kill() -> void:
	if dead:
		return
	dead = true
	_release_jobs()
	died.emit(self)
	if visible:
		float_text("%s lost" % display_name(), Color("ff7a6a"))
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func _release_jobs() -> void:
	pass
