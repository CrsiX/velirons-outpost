class_name Civilian
extends Unit
## A villager. Lives in the village; hidden while resting at home.
## Subclasses implement their job as a small state machine in `_tick`.

signal died(civ: Civilian)

var role := ""
var at_home := true
var dead := false
var rest_timer := 0.0


func setup(p_game: Game, p_role: String) -> void:
	game = p_game
	role = p_role
	speed = Config.CIVILIANS[role]["speed"]
	_init_sprite("unit_" + role)
	set_grid_pos(Vector2(Config.VILLAGE_CENTER))
	_set_home(true)
	rest_timer = randf_range(0.2, 1.5)


func display_name() -> String:
	return Config.CIVILIANS[role]["name"]


func _process(delta: float) -> void:
	if dead:
		return
	_tick(delta)


## Override with the job logic.
func _tick(_delta: float) -> void:
	pass


## Short status line for the UI.
func status() -> String:
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
		set_grid_pos(Vector2(Config.VILLAGE_CENTER))
		_set_home(false)
	follow(p)
	return true


func head_home() -> void:
	var p := game.world.pathing.find_path(current_tile(), Config.VILLAGE_CENTER)
	if p.is_empty():
		arrive_home()  # stuck somewhere: just teleport home
		return
	follow(p)


func arrive_home() -> void:
	set_grid_pos(Vector2(Config.VILLAGE_CENTER))
	_set_home(true)
	_set_moving(false)


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
