class_name Enemy
extends Unit
## Any attacker. The base class only walks the road flow field to the nearest
## gate, takes damage and dies; everything else is the kind's behavior script
## (Config.ENEMIES[kind]["behavior"], see scripts/units/enemies/). All numbers
## come from Config.ENEMIES[kind] via stat(), scaled by difficulty.

signal killed(enemy: Enemy)
signal reached_gate(enemy: Enemy)

const BEHAVIORS := {
	"melee": preload("res://scripts/units/enemies/melee_behavior.gd"),
	"witch": preload("res://scripts/units/enemies/witch_behavior.gd"),
}

var kind := ""
var max_hp := 10.0
var hp := 10.0
var wave := 0
var dead := false
var behavior: EnemyBehavior
## Number within its kind (see label()).
var uid := 0
## Whoever dealt the killing blow (for the log, and who gets the gold).
var killer: Node = null
## The village this enemy is sent against (its raid hits that village's huts).
var target_village: Village = null
var _jitter := Vector2.ZERO


func setup(p_game: Game, route: Array[Vector2i], hp_scale: float, p_kind: String) -> void:
	game = p_game
	kind = p_kind
	max_hp = stat("hp") * hp_scale
	hp = max_hp
	speed = stat("speed") * randf_range(0.92, 1.08)
	_init_sprite("unit_" + spec()["art"])
	var pts := PackedVector2Array()
	# A small sideways offset per enemy so groups don't walk in single file.
	_jitter = Vector2(randf_range(-0.18, 0.18), randf_range(-0.18, 0.18))
	for t in route:
		pts.append(Vector2(t) + _jitter)
	set_grid_pos(pts[0])
	follow(pts)
	behavior = BEHAVIORS[spec()["behavior"]].new()
	add_to_group("enemies")
	_update_visibility()


## Co-op: turns towards `v` (its target fell), along the roads from where it is.
func retarget(v: Village, rng: RandomNumberGenerator) -> void:
	var from := game.world.pathing.nearest_road(current_tile())
	var field := v.id if game.world.pathing.enemy_distance(from, v.id) < Pathing.UNREACHABLE else -1
	var route := game.world.pathing.enemy_route(from, rng, field)
	var old := target_village
	target_village = v
	var pts := PackedVector2Array([grid_pos])
	for t in route:
		pts.append(Vector2(t) + _jitter)
	follow(pts)
	game.log_all(EventLog.Level.DEBUG, "%s turns from %s to %s" % [label(), old.village_name if old else "?", v.village_name])


func spec() -> Dictionary:
	return Config.ENEMIES[kind]


## Log name, numbered per kind: "goblin 4".
func label() -> String:
	return "%s %d" % [str(spec()["name"]).to_lower(), uid]


## A config value for this kind, difficulty-scaled where appropriate.
func stat(key: String) -> float:
	return Config.enemy_stat(kind, key)


## Tiles left until the gate (lower = more dangerous).
func remaining() -> int:
	return path.size() - path_index


func hit_point() -> Vector2:
	return global_position + Vector2(0, -18)


func face(grid_target: Vector2) -> void:
	sprite.flip_h = Iso.to_world(grid_target - grid_pos).x < 0.0


func _process(delta: float) -> void:
	if dead:
		return
	if game.is_client:
		net_follow(delta)  # the host simulates; we just follow
		return
	# The behavior may hold the enemy in place (fighting, casting).
	if behavior.tick(self, delta):
		_set_moving(false)
	elif step_path(delta):
		dead = true
		remove_from_group("enemies")
		reached_gate.emit(self)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
		return
	_update_visibility()


## Only seen while under surveillance (near villagers, soldiers or manned towers).
func _update_visibility() -> void:
	visible = game.fog.is_watched(current_tile())


## `source` is whoever dealt the damage (a Tower for arrows, an EarthElemental
## in melee); behaviors may react to it.
func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		dead = true
		killer = source
		remove_from_group("enemies")
		killed.emit(self)
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2(1.2, 0.3), 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)
		return
	if source != null:
		behavior.on_damaged(self, source)


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	var w := 28.0
	var r := Rect2(-w / 2.0, -46.0, w, 5.0)
	draw_rect(r.grow(1.5), Color("15110d"))
	draw_rect(r, Color("4a1510"))
	draw_rect(Rect2(r.position, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), r.size.y)), Color("d8412f"))
