class_name Caravan
extends Unit
## A horse-drawn cart taking resources from one village to another (co-op help).
## The sender pays when it leaves; the receiver gets the cargo minus the help
## tax (Config.help_tax) when it arrives at their village centre. Enemies
## ignore caravans, nothing stops them, and they can't be recalled.

var from: Village
var to: Village
## Owner (the sender): whose surveillance it adds to.
var village: Village
## Resources on board, before tax: {"gold": n, "food": n, "materials": n}.
var cargo: Dictionary = {}
var tax := 0.0
var uid := 0


func setup(p_game: Game, p_from: Village, p_to: Village, p_cargo: Dictionary, p_tax: float) -> void:
	game = p_game
	from = p_from
	to = p_to
	village = p_from
	cargo = p_cargo
	tax = p_tax
	uid = game.next_id("caravan")
	speed = Config.CARAVAN_SPEED
	_init_sprite("unit_caravan")
	set_grid_pos(Vector2(from.center))
	add_to_group("observers")
	var p := game.world.pathing.find_path(from.center, to.center)
	follow(p)


func label() -> String:
	return "caravan %d" % uid


## What the receiver gets: each amount minus the tax, rounded down.
func delivered() -> Dictionary:
	var out := {}
	for res in cargo:
		out[res] = floori(cargo[res] * (1.0 - tax))
	return out


func _process(delta: float) -> void:
	if game.is_client:
		net_follow(delta)  # the host simulates; we just follow
		return
	if step_path(delta):
		_arrive()


func _arrive() -> void:
	set_process(false)
	var got := delivered()
	for res in got:
		to.economy.add(res, got[res], "caravans")
		game.stats.count(to, "caravan_got." + res, got[res])
	var text := ", ".join(got.keys().filter(func(r: String) -> bool: return got[r] > 0).map(func(r: String) -> String: return "+%d %s" % [got[r], "material" if r == "materials" else r]))
	to.events.info("Caravan from %s arrived: %s" % [from.village_name, text])
	from.events.info("Your caravan reached %s: %s" % [to.village_name, text])
	float_text(", ".join(got.keys().filter(func(r: String) -> bool: return got[r] > 0).map(func(r: String) -> String: return "+%d {%s}" % [got[r], r])), UiTheme.GOLD)
	Sfx.play("coin")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func sight_radius() -> float:
	return Config.UNIT_SIGHT


func sight_center() -> Vector2:
	return grid_pos
