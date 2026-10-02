class_name Enemy
extends Unit
## Any attacker. The base class only walks the road flow field to the nearest
## gate, takes damage and dies; everything else is the kind's behavior script
## (Config.ENEMIES[kind]["behavior"], see scripts/units/enemies/). All numbers
## come from Config.ENEMIES[kind] via stat(), scaled by difficulty.

signal killed(enemy: Enemy)
signal reached_gate(enemy: Enemy)
## Gone without a fight (a rat that stopped bothering): no corpse, no gold.
signal vanished(enemy: Enemy)

const BEHAVIORS := {
	"melee": preload("res://scripts/units/enemies/melee_behavior.gd"),
	"witch": preload("res://scripts/units/enemies/witch_behavior.gd"),
	"rat": preload("res://scripts/units/enemies/rat_behavior.gd"),
	"thief": preload("res://scripts/units/enemies/thief_behavior.gd"),
	"necromancer": preload("res://scripts/units/enemies/necromancer_behavior.gd"),
	"vampire": preload("res://scripts/units/enemies/vampire_behavior.gd"),
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
## Walking speed without slows; ice mages slow it for a while.
var base_speed := 1.0
var _slow := 1.0
var _slow_left := 0.0
## Seconds before a spatial mage can throw it back again.
var _push_immune := 0.0
## Set by a behavior that moved the enemy itself this frame (rats off the road).
var self_moved := false
## Came out of a lair that woke up this wave (WarningLights mark it).
var from_lair := false
## Its wave's HP factor (a raised corpse keeps it).
var hp_scale := 1.0
## Gold a thief stole; its corpse holds it too.
var loot_gold := 0
## Raised by a necromancer: pale, and its HP drains away (decay_rate per s).
var raised := false
var decay_rate := 0.0
## Died of that drain, not killed: no gold.
var decayed := false
## Flying for now (a vampire in bat form): see set_airborne.
var airborne := false
## A necromancer's spell on a corpse there (grid position; INF = none).
var channel_to := Vector2.INF
var _fly_t := 0.0
var _fly_base := Vector2.ZERO
var _shadow: Polygon2D
## A slime's colour (Config.SLIME_COLORS), rolled at spawn; "" for the rest.
var color := ""
var _sack: Sprite2D


func setup(p_game: Game, route: Array[Vector2i], p_hp_scale: float, p_kind: String) -> void:
	game = p_game
	kind = p_kind
	hp_scale = p_hp_scale
	max_hp = stat("hp") * hp_scale
	hp = max_hp
	speed = stat("speed") * randf_range(0.92, 1.08)
	base_speed = speed
	var colors: Array = spec().get("colors", [])
	if not colors.is_empty():
		color = colors[randi() % colors.size()]
	_init_sprite(unit_art())
	var pts := PackedVector2Array()
	# A small sideways offset per enemy so groups don't walk in single file.
	_jitter = Vector2(randf_range(-0.18, 0.18), randf_range(-0.18, 0.18))
	for t in route:
		pts.append(Vector2(t) + _jitter)
	set_grid_pos(pts[0])
	follow(pts)
	behavior = BEHAVIORS[spec()["behavior"]].new()
	if flies():
		_take_off()
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


## Ice: walks at `factor` of its speed for `seconds` (the strongest slow counts).
func slow(factor: float, seconds: float) -> void:
	if _slow_left <= 0.0:
		base_speed = speed  # (whatever it walks at now)
		_slow = factor
	else:
		_slow = minf(_slow, factor)
	_slow_left = maxf(_slow_left, seconds)
	speed = base_speed * _slow
	sprite.self_modulate = Color(0.65, 0.85, 1.0)


func is_slowed() -> bool:
	return _slow_left > 0.0


## Spatial magic: thrown `tiles` back along its road (away from the village),
## at most once every `immunity` seconds. Returns whether it moved.
func push_back(tiles: float, immunity: float) -> bool:
	if _push_immune > 0.0 or path.size() < 2:
		return false
	_push_immune = immunity
	var left := tiles
	var pos := grid_pos
	var i := mini(path_index, path.size() - 1)
	while left > 0.0 and i > 0:
		var prev := path[i - 1]
		var d := pos.distance_to(prev)
		if d >= left:
			pos = pos.move_toward(prev, left)
			left = 0.0
		else:
			pos = prev
			left -= d
			i -= 1
	path_index = i
	set_grid_pos(pos)
	Combat.burst(game, "warp", position + Vector2(0, -16), 0.8)
	return true


func spec() -> Dictionary:
	return Config.ENEMIES[kind]


## What kind of damage its blows do (Config.DAMAGE_CATEGORIES).
func attack_category() -> String:
	return spec().get("attack_category", "melee")


## Flies (gargoyles; a vampire in bat form): keeps to the roads, but no
## ground slows it, and only ranged attacks and other flyers can go for it.
func flies() -> bool:
	return airborne or spec().get("flying", false)


## Its sprite: unit_<art>, or unit_<art>_<colour> for a slime.
func unit_art() -> String:
	return "unit_%s%s" % [spec()["art"], "_" + color if color != "" else ""]


## A slime's halves keep its colour.
func set_color(c: String) -> void:
	if c == "" or c == color:
		return
	color = c
	var flip := sprite.flip_h
	Art.apply(sprite, unit_art())
	sprite.flip_h = flip


## Jelly (slimes): squashes and stretches as it walks.
func is_jelly() -> bool:
	return spec().has("colors")


## Split off a bigger slime: it pops out of it.
func pop_in() -> void:
	scale = Vector2(0.4, 0.4)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate(delta: float) -> void:
	if not is_jelly():
		super._animate(delta)
		return
	_bob += delta * 8.0
	var q := sin(_bob) * 0.1
	sprite.scale = Vector2(0.5 * (1.0 + q), 0.5 * (1.0 - q))


func _set_moving(v: bool) -> void:
	super._set_moving(v)
	if not v and is_jelly():
		sprite.scale = Vector2(0.5, 0.5)


## The art it shows now: its own, or the bat's.
func art_base() -> String:
	return "vampire_bat" if airborne else str(spec()["art"])


## Into the air (`on`) as a bat, or back on its feet: a puff of dark smoke,
## shrinking into it and growing out again in the new shape.
func set_airborne(on: bool) -> void:
	if airborne == on:
		return
	airborne = on
	Combat.local_burst(game, "smoke", position + Vector2(0, -20), 0.9)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.15, 0.15), 0.15)
	tw.tween_callback(func() -> void:
		var flip := sprite.flip_h
		Art.apply(sprite, "unit_" + art_base())
		sprite.flip_h = flip
		if airborne:
			_take_off()
		else:
			_land()
		sprite.scale = Vector2(0.15, 0.15))
	tw.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Starts flying: a shadow on the ground under it (drawn first), bobbing.
func _take_off() -> void:
	if _shadow == null:
		_shadow = Polygon2D.new()
		var ring := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			ring.append(Vector2(cos(a) * 13.0, 2.0 + sin(a) * 5.0))
		_shadow.polygon = ring
		_shadow.color = Color(0, 0, 0, 0.28)
		_shadow.show_behind_parent = true
		add_child(_shadow)
		move_child(_shadow, 0)
	_shadow.visible = true
	_fly_base = sprite.offset
	_fly_t = randf() * TAU


func _land() -> void:
	if _shadow:
		_shadow.visible = false
	_fly_base = sprite.offset


func _walk_factor() -> float:
	return 1.0 if flies() else super._walk_factor()


## A thief with stolen gold: it shows a coin sack.
func set_loot(gold: int) -> void:
	loot_gold = gold
	if gold > 0 and _sack == null:
		_sack = Art.sprite("sack")
		_sack.position = Vector2(8, -22)
		_sack.scale = Vector2.ONE * 0.8
		add_child(_sack)
	if _sack:
		_sack.visible = gold > 0


## Raised from its corpse: `share` of its HP, draining to 0 in `decay` s.
func make_raised(share: float, decay: float) -> void:
	raised = true
	max_hp *= share
	hp = max_hp
	decay_rate = max_hp / maxf(decay, 0.1)
	modulate = Color(0.7, 1.0, 0.75, 0.8)
	queue_redraw()


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
	return global_position + Vector2(0, -34 if flies() else -18)



## Walks its own path (set with follow) for a behavior that took over.
## Returns true at the end of it.
func walk_own(delta: float) -> bool:
	self_moved = true
	return step_path(delta)


## Leaves the map without a fight: no corpse, no gold.
func vanish() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	behavior.on_death(self)
	vanished.emit(self)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_property(self, "scale", Vector2(0.6, 0.6), 0.5)
	tw.chain().tween_callback(queue_free)


## A melee blow: a quick lunge towards the foe and back, swaying left and
## right (like a forester's axe).
func swing(grid_target: Vector2) -> void:
	face(grid_target)
	var lunge := (Iso.to_world(grid_target) - position).normalized() * 7.0
	var tw := create_tween()
	tw.tween_property(sprite, "position", lunge, 0.08)
	tw.parallel().tween_property(sprite, "rotation", 0.18 if lunge.x >= 0.0 else -0.18, 0.08)
	tw.tween_property(sprite, "rotation", -0.1 if lunge.x >= 0.0 else 0.1, 0.1)
	tw.tween_property(sprite, "position", Vector2.ZERO, 0.14)
	tw.parallel().tween_property(sprite, "rotation", 0.0, 0.14)


func _process(delta: float) -> void:
	if dead:
		return
	if flies():
		_fly(delta)
	if channel_to != Vector2.INF:
		queue_redraw()
	if game.is_client:
		net_follow(delta)  # the host simulates; we just follow
		return
	_push_immune -= delta
	if raised and decay_rate > 0.0:
		hp -= decay_rate * delta
		queue_redraw()
		if hp <= 0.0:
			decayed = true
			take_damage(1.0, null)
			decayed = dead  # (unless a vampire saved itself as a bat)
			if dead:
				return
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:  # the frost wears off
			_slow = 1.0
			speed = base_speed
			sprite.self_modulate = Color.WHITE
	# The behavior may hold the enemy in place (fighting, casting), or move it
	# itself (rats going for a farm).
	self_moved = false
	if behavior.tick(self, delta):
		if dead:
			return
		if not self_moved:
			_set_moving(false)
	elif step_path(delta):
		if behavior.on_path_end(self):
			return  # (a thief turning back, or escaping)
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


## `source` is whoever dealt the damage (a Tower, or a melee defender);
## behaviors may react to it. `category` (Config.DAMAGE_CATEGORIES) is scaled
## by the kind's "resist" table (a vampire takes less from magic).
func take_damage(amount: float, source: Node = null, category: String = "pure") -> void:
	if dead:
		return
	amount *= float(spec().get("resist", {}).get(category, 1.0))
	if raised and category == "holy":
		amount *= float(Config.ENEMIES["necromancer"]["raised_holy"])  # (the undead it raised)
	hp -= amount
	behavior.on_hurt(self)
	queue_redraw()
	sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		dead = true
		killer = source
		remove_from_group("enemies")
		behavior.on_death(self)
		killed.emit(self)
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2(1.2, 0.3), 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)
		return
	if source != null:
		behavior.on_damaged(self, source)


## Wings beating, rising and sinking a little: it flies. (Its shadow stays
## on the ground, see _draw.)
func _fly(delta: float) -> void:
	_fly_t += delta
	# A bat beats its wings faster than a gargoyle and flutters from side to side.
	var bat := airborne
	var flap := int(_fly_t * (14.0 if bat else 7.0)) % 2 == 0
	var art := "unit_%s%s" % [art_base(), "" if flap else "_flap"]
	if sprite.texture != Art.tex(art):
		var flip := sprite.flip_h
		var sc := sprite.scale
		Art.apply(sprite, art)
		sprite.flip_h = flip
		sprite.scale = sc
		_fly_base = sprite.offset
	# (offset is in texture pixels: the sprite is drawn at half size)
	var side := sin(_fly_t * 5.3) * 5.0 if bat else 0.0
	sprite.offset = _fly_base + Vector2(side, (-16.0 - 4.0 * sin(_fly_t * (5.0 if bat else 3.2))) * 2.0)
	if _shadow:  # (a vampire gets its shadow a moment after it starts to change)
		_shadow.scale = Vector2.ONE * (1.0 - 0.12 * sin(_fly_t * 3.2))  # smaller while higher


func _draw() -> void:
	if channel_to != Vector2.INF and not dead:
		# The necromancer's green beam to the corpse, flickering.
		var to := Iso.to_world(channel_to) - position
		var from := Vector2(8, -40)
		var a := 0.45 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
		draw_line(from, to, Color(0.42, 1.0, 0.54, a * 0.5), 6.0)
		draw_line(from, to, Color(0.75, 1.0, 0.8, a), 2.0)
		draw_circle(to, 7.0 + 2.0 * sin(Time.get_ticks_msec() / 120.0), Color(0.42, 1.0, 0.54, a * 0.35))
	if dead or hp >= max_hp:
		return
	_draw_hp_bar(28.0, -62.0 if flies() else float(spec().get("hp_bar_y", -46.0)), 5.0, hp / max_hp, Color("4a1510"), Color("d8412f"))
