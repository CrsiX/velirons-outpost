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
	"leviathan": preload("res://scripts/units/enemies/leviathan_behavior.gd"),
	"siren": preload("res://scripts/units/enemies/siren_behavior.gd"),
	"octopus": preload("res://scripts/units/enemies/octopus_behavior.gd"),
	"arm": preload("res://scripts/units/enemies/arm_behavior.gd"),
	"spider_mother": preload("res://scripts/units/enemies/spider_mother_behavior.gd"),
	"egg": preload("res://scripts/units/enemies/egg_behavior.gd"),
	"wrathwood": preload("res://scripts/units/enemies/wrathwood_behavior.gd"),
}
## How many tiles farther a low_priority enemy (a spider egg) counts for
## whoever picks a target: anything else in reach comes first.
const LOW_PRIORITY_TILES := 1000.0

## Water monsters (docs/aquatic-design.md §2): up (targetable), diving, down
## or surfacing (all three untargetable).
enum Dive { UP, DIVING, DOWN, SURFACING }

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
## Undead without being raised (a raised spider mother's eggs and their
## spiderlings): unholy, and holy damage hurts it like the raised; no drain.
var undead := false
## A hatched egg: only its broken shell, out of everyone's reach (hatch_out).
var shell := false
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
var dive := Dive.UP
var _dive_t := 0.0
var _splash_in := 0.0
## What a behavior shows besides the sprite (co-op clients get it too):
## "song" (a siren's ring: its radius), "jet" (a leviathan's water column:
## the target's grid position) with "wind" (0..1 while it winds up), "arms"
## (an octopus's reaching or holding arms: [grid position of the tip]).
var fx := {}
## The deep-water body a water-bound monster lives in (Pathing.bodies).
var body := -1
## Breaking into its village (docs/siege-design.md §5): off the road, tile by
## tile along the siege field (Siege), hitting the barrier in its way.
var sieging := false
var breach: Building = null
## A barrier it couldn't hurt and walks through after SIEGE.stuck_slip.
var _passing: Building = null
var _siege_cd := 0.0
var _siege_scan := 0.0
var _stuck := 0.0
## Seconds an intact gate has held it ("entry": "slip").
var _slip := 0.0
## The hut it got to: Game.on_enemy_reached_gate burns this one.
var raid_hut: Hut = null


func setup(p_game: Game, route: Array[Vector2i], p_hp_scale: float, p_kind: String) -> void:
	game = p_game
	kind = p_kind
	hp_scale = p_hp_scale
	max_hp = float(spec()["hp"]) if spec().get("fixed_hp", false) else stat("hp") * hp_scale
	hp = max_hp
	speed = stat("speed") * randf_range(0.92, 1.08)
	base_speed = speed
	var colors: Array = spec().get("colors", [])
	if not colors.is_empty():
		color = colors[randi() % colors.size()]
	_init_sprite(unit_art())
	var pts := PackedVector2Array()
	# A small sideways offset per enemy so groups don't walk in single file
	# (not in deep water: monsters there keep to the tiles' middles).
	if habitat() != "water":
		_jitter = Vector2(randf_range(-0.18, 0.18), randf_range(-0.18, 0.18))
	for t in route:
		pts.append(Vector2(t) + _jitter)
	set_grid_pos(pts[0])
	follow(pts)
	behavior = BEHAVIORS[spec()["behavior"]].new()
	if flies():
		_take_off()
	if habitat() == "water" and game.world and game.world.pathing:
		body = game.world.pathing.body_of(current_tile())
	add_to_group("enemies")
	_update_visibility()


## Co-op: turns towards `v` (its target fell), along the roads from where it
## is (an amphibian: roads and water; water-bound monsters only change sides).
func retarget(v: Village, rng: RandomNumberGenerator) -> void:
	if habitat() == "water":
		target_village = v
		return
	var amph := is_amphibian()
	var from := current_tile()
	if not (amph and game.map.is_wet(from)):
		from = game.world.pathing.nearest_road(from)
	var field := v.id if game.world.pathing.enemy_distance(from, v.id, amph) < Pathing.UNREACHABLE else -1
	var route := game.world.pathing.enemy_route(from, rng, field, amph)
	var old := target_village
	target_village = v
	leave_siege()
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
	if sieging and _push_immune <= 0.0:
		_push_immune = immunity
		_siege_push(tiles)
		return true
	if _push_immune > 0.0 or path.size() < 2 or habitat() == "water":
		return false  # (water-bound monsters have no road to be thrown back along)
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


# --- water monsters (docs/aquatic-design.md) -------------------------------------------

## "land", "amphibian" (roads and water) or "water" (deep water only).
func habitat() -> String:
	return str(spec().get("habitat", "land"))


## Walks the amphibians' flow field (roads and water). Raised from its corpse
## it keeps that, but never dives again.
func is_amphibian() -> bool:
	return habitat() == "amphibian"


## Can it dive? Only a kind that submerges, never a raised one.
func can_submerge() -> bool:
	return spec().get("submerges", false) and not raised


## On a deep water tile (where it may dive; melee reaches it only from the shore).
func on_deep() -> bool:
	return game.map.is_deep(current_tile())


## Passing under a bridge at path waypoint `i`: a water-bound monster under
## any bridge on its way; an amphibian when it swims across under it (water
## before and after, not the road along it).
func _under_bridge_at(i: int) -> bool:
	if i < 0 or i >= path.size():
		return false
	var t := Vector2i((path[i] - _jitter).round())
	if not game.map.is_bridge(t):
		return false
	if habitat() == "water":
		return true
	var a := Vector2i((path[i - 1] - _jitter).round()) if i > 0 else t
	var b := Vector2i((path[i + 1] - _jitter).round()) if i + 1 < path.size() else t
	return a != t and b != t and not game.map.is_road(a) and not game.map.is_road(b)


## Under a bridge, or about to go under one: it must be under water there (it
## can't come up beneath a bridge, nor get out of the water onto it).
func must_be_under() -> bool:
	if habitat() == "land":
		return false
	var t := current_tile()
	if game.map.is_bridge(t):
		if habitat() == "water":
			return true
		for i in [path_index - 1, path_index]:
			if i >= 0 and i < path.size() and Vector2i((path[i] - _jitter).round()) == t and _under_bridge_at(i):
				return true
		return false
	return _under_bridge_at(path_index)


## The one test every targeting site uses: alive and up (not diving, down or
## surfacing).
func targetable() -> bool:
	return not dead and dive == Dive.UP


## Down (or on its way down or up): ripples instead of the monster.
func submerged() -> bool:
	return dive != Dive.UP


## Starts diving (only on deep water, or to pass under a bridge). Returns
## whether it does.
func dive_down() -> bool:
	if dive == Dive.DOWN or dive == Dive.DIVING or not can_submerge() or not (on_deep() or must_be_under()):
		return false
	_set_dive(Dive.DIVING)
	Combat.local_burst(game, "splash", position, 0.6)
	return true


## Starts coming up (never under a bridge).
func surface() -> void:
	if dive == Dive.UP or dive == Dive.SURFACING or must_be_under():
		return
	_set_dive(Dive.SURFACING)


func _set_dive(d: Dive) -> void:
	if dive == d:
		return
	if d == Dive.SURFACING and dive != Dive.DOWN:
		Combat.local_burst(game, "splash", position, 0.6)
	dive = d
	_dive_t = 0.0
	_show_dive()
	queue_redraw()


## Diving and surfacing take their time (AQUA); a crab dives and surfaces by
## itself on deep water and off it; every kind dives to pass under a bridge.
func _tick_dive(delta: float) -> void:
	if can_submerge() and must_be_under() and (dive == Dive.UP or dive == Dive.SURFACING):
		dive_down()
	if spec().get("auto_submerge", false) and can_submerge():
		if on_deep() or must_be_under():
			if dive == Dive.UP or dive == Dive.SURFACING:
				dive_down()
		elif dive == Dive.DOWN or dive == Dive.DIVING:
			surface()
	elif dive != Dive.UP and not can_submerge():
		_set_dive(Dive.UP)  # (raised: never under again)
	if dive == Dive.DIVING or dive == Dive.SURFACING:
		_dive_t += delta
		var need := float(Config.AQUA["dive_time" if dive == Dive.DIVING else "surface_time"])
		if _dive_t >= need:
			_set_dive(Dive.DOWN if dive == Dive.DIVING else Dive.UP)
		else:
			_show_dive()


## The sprite sinks under the surface and fades, or rises out of it.
func _show_dive() -> void:
	var k := 1.0
	match dive:
		Dive.DOWN:
			k = 0.0
		Dive.DIVING:
			k = 1.0 - clampf(_dive_t / float(Config.AQUA["dive_time"]), 0.0, 1.0)
		Dive.SURFACING:
			k = clampf(_dive_t / float(Config.AQUA["surface_time"]), 0.0, 1.0)
	sprite.visible = k > 0.01
	sprite.modulate.a = k
	sprite.offset.y = (1.0 - k) * 24.0


## In the water it rides it instead of walking (see _wade): a water-bound
## monster (leviathan, octopus; not an arm) always, an amphibian (crab, siren)
## while in water (deep, shallow or a ford; on roads and land it walks).
func _wades() -> bool:
	if habitat() == "water":
		return spec()["behavior"] != "arm"
	return habitat() == "amphibian" and game.map != null and game.map.in_water(current_tile())


## Up in the water: a slow rise and fall (no walking sway), and while it
## moves, splashes now and then round its body (this machine only: a co-op
## client plays its own).
func _wade(delta: float) -> void:
	_bob += delta * (1.6 if moving else 1.0)
	sprite.rotation = 0.0
	sprite.position.y = (-3.0 - 3.0 * sin(_bob)) if habitat() == "water" else (-1.5 - 1.5 * sin(_bob))
	_splash_in -= delta
	if moving and dive == Dive.UP and _splash_in <= 0.0:
		_splash_in = randf_range(0.7, 1.3)
		var big := habitat() == "water"
		var side := Vector2(randf_range(-1.0, 1.0), randf_range(0.0, 0.5)).normalized() * (26.0 if big else 10.0)
		Combat.local_burst(game, "splash", position + Vector2(side.x, side.y * 0.5), 0.45 if big else 0.25)


## Co-op client: the host's dive state.
func net_dive(d: int) -> void:
	if d != dive:
		_set_dive(d as Dive)


## Can a melee blow from someone standing at `from` (grid) go for it? Not
## while it is under; on deep water only from a walkable tile next to it
## (§2.1); and a siren in water only from inside a High Priest's aura (§6),
## unless the blow is a `flame` (a fire elemental's).
func melee_ok(from: Vector2, flame := false) -> bool:
	if not targetable():
		return false
	var t := current_tile()
	if not flame and spec().get("melee_proof_in_water", false) and game.map.in_water(t) and not Combat.in_holy_aura(game, from):
		return false
	if game.map.is_deep(t):
		return game.world.pathing.stand_near(t, from) != Vector2i(-1, -1)
	return true


## A melee attacker's reach towards it: on deep water it is struck from the
## tile next to it (AQUA melee_reach), so at least that.
func melee_reach(base: float) -> float:
	return maxf(base, float(Config.AQUA["melee_reach"])) if on_deep() else base


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
	if _wades():
		return  # (see _wade: no walking sway in the water)
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
	return 1.0 if flies() or habitat() != "land" else super._walk_factor()


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


## Undead from the start (see `undead`): as pale as the raised.
func make_undead() -> void:
	undead = true
	modulate = Color(0.7, 1.0, 0.75, 0.8)


## Unholy: its kind is, or it was raised or is undead (the Inquisitor hunts it).
func is_unholy() -> bool:
	return raised or undead or spec().get("unholy", false)


## Not part of any wave (a camp guard, a wrathwood; EnemyBehavior.wild).
func wild() -> bool:
	return behavior != null and behavior.wild()


## Comes last for whoever picks a target (a spider egg; see LOW_PRIORITY_TILES).
func low_priority() -> bool:
	return spec().get("low_priority", false)


## An egg hatched (Waves.hatch): its broken shell stays shell_time s, out of
## everyone's reach, then fades (on a co-op client the host removes it).
func hatch_out() -> void:
	if dead:
		return
	dead = true
	shell = true
	remove_from_group("enemies")
	behavior.on_death(self)
	_show_shell()
	if game.is_client:
		return
	vanished.emit(self)
	var tw := create_tween()
	tw.tween_interval(float(spec().get("shell_time", 3.0)))
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _show_shell() -> void:
	shell = true
	Art.apply(sprite, "unit_%s_shell" % spec()["art"])
	sprite.rotation = 0.0
	sprite.scale = Vector2(0.5, 0.5)
	queue_redraw()


## Co-op client: the host's egg hatched.
func net_shell() -> void:
	if not shell:
		dead = true
		_show_shell()


## Log name, numbered per kind: "goblin 4".
func label() -> String:
	return "%s %d" % [str(spec()["name"]).to_lower(), uid]


## A config value for this kind, difficulty-scaled where appropriate.
func stat(key: String) -> float:
	return Config.enemy_stat(kind, key)


## Tiles left until the gate (lower = more dangerous); breaking in: tiles to
## the village's walls (0 at or inside them).
func remaining() -> int:
	if sieging and is_instance_valid(target_village):
		return floori(Hero.rect_distance(target_village.rect, grid_pos))
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
		if shell and not game.is_client:
			_update_visibility()  # (a shell is seen like any enemy)
		return
	if flies():
		_fly(delta)
	if channel_to != Vector2.INF or submerged() or not fx.is_empty():
		queue_redraw()
	if _wades():
		_wade(delta)
	behavior.animate(self, delta)
	if game.is_client:
		if dive == Dive.DIVING or dive == Dive.SURFACING:
			_dive_t += delta
			_show_dive()
		net_follow(delta)  # the host simulates; we just follow
		return
	if spec().has("submerges"):
		_tick_dive(delta)
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
	elif _siege_tick(delta):
		if dead:
			return
	elif step_path(delta):
		if _held_at_gate(delta):
			_set_moving(false)
			_update_visibility()
			return
		if behavior.on_path_end(self):
			return  # (a thief turning back, or escaping)
		if entry() == "siege" and _start_siege_at_end():
			_update_visibility()
			return
		_get_in()
		return
	_update_visibility()


## Through: it burns a hut (raid_hut, or one at random), eats food or steals
## (Game.on_enemy_reached_gate), and is gone.
func _get_in() -> void:
	dead = true
	remove_from_group("enemies")
	reached_gate.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


# --- at the village (docs/siege-design.md §5) -------------------------------------------------

## How it gets into a village: "siege" (break in) or "slip" (held by a gate).
func entry() -> String:
	return str(spec().get("entry", "siege"))


## May break into its village by the siege field now?
func _may_siege() -> bool:
	return entry() == "siege" and habitat() != "water" and not airborne and not game.is_client \
		and is_instance_valid(target_village) and not target_village.fallen and not wild()


## A "slip" enemy at the end of its road on an intact gate: held for SIEGE.slip_time.
func _held_at_gate(delta: float) -> bool:
	if entry() != "slip":
		return false
	var b = game.map.building_at(current_tile())
	if not (b is StaticPiece and b.kind == "gate" and b.complete and not b.devastated):
		return false
	if _slip == 0.0 and b.village:
		b.village.events.debug("%s is held up at %s" % [label(), b.label()])
	_slip += delta
	return _slip < float(Config.SIEGE["slip_time"])


## The road ended (it never got near enough to switch, e.g. raised at the
## gate): break in from here, if it is at a village. Returns whether it does.
func _start_siege_at_end() -> bool:
	var vid := game.map.village_at(current_tile())
	if vid < 0 or vid >= game.villages.size() or airborne or habitat() == "water":
		return false
	if not is_instance_valid(target_village) or target_village.id != vid:
		target_village = game.villages[vid]
	if not _may_siege():
		return false
	sieging = true
	return true


## Leaves the siege (a new target village, or a vampire turning into a bat).
func leave_siege() -> void:
	sieging = false
	breach = null
	_passing = null
	_stuck = 0.0


## Breaking in: returns true while the siege moves (or holds) it this frame.
func _siege_tick(delta: float) -> bool:
	var v := target_village
	if not sieging:
		if not _may_siege() or not game.siege.in_zone(v, current_tile()):
			return false
		if game.siege.value(v, current_tile(), flies()) >= Siege.BLOCKED:
			return false
		sieging = true
		path = PackedVector2Array()
		path_index = 0
		v.events.debug("%s leaves the road to break into %s" % [label(), v.village_name])
	elif not _may_siege():
		leave_siege()
		return false
	var air := flies()
	_siege_cd -= delta
	_siege_scan -= delta
	if air:
		breach = null
	if is_instance_valid(breach) and breach.complete and not breach.devastated and breach != _passing:
		_at_barrier(v, delta)
		return true
	breach = null
	if path_index < path.size():
		step_path(delta)
		return true
	var here := current_tile()
	var hut := game.siege.hut_at(v, here)
	if hut != null:
		raid_hut = hut
		_get_in()
		return true
	if not air:
		var under := game.siege.barrier_at(v, here)
		if under != null and under != _passing:
			breach = under  # (standing on it: a gate it walked onto)
			return true
	var n := game.siege.next_step(v, here, air, _passing)
	if n == here:
		_set_moving(false)  # (no way in from here: wait)
		return true
	var b := game.siege.barrier_at(v, n) if not air else null
	if b != null and b != _passing:
		breach = b
		_stuck = 0.0
		face(Vector2(n))
		return true
	follow(PackedVector2Array([grid_pos, Vector2(n) + _jitter]))
	step_path(delta)
	return true


## In front of a barrier: hits it (EnemyBehavior.siege_attack), now and then
## checks for a clearly cheaper way, and slips past one it can't hurt.
func _at_barrier(v: Village, delta: float) -> void:
	_set_moving(false)
	face(Vector2(breach.tile))
	if _siege_scan <= 0.0:
		_siege_scan = float(Config.SIEGE["rescan"])
		var here := current_tile()
		var now := game.siege.way_cost(v, breach.tile, false)
		var best := game.siege.best_way(v, here, false)
		if best < Siege.BLOCKED and best + float(Config.SIEGE["switch_margin"]) * Siege.STEP < now:
			breach = null
			return
	if _siege_cd > 0.0:
		return
	var cd := behavior.siege_attack(self, breach)
	if cd > 0.0:
		_siege_cd = cd
		_stuck = 0.0
		return
	_stuck += delta
	if _stuck >= float(Config.SIEGE["stuck_slip"]):
		v.events.debug("%s slips past %s" % [label(), breach.label()])
		_passing = breach
		breach = null


## Spatial magic on an enemy breaking in: thrown back up the field, tile by
## tile, over ground it can walk.
func _siege_push(tiles: float) -> void:
	var v := target_village
	var air := flies()
	var t := current_tile()
	for i in maxi(1, roundi(tiles)):
		var best := t
		var here := game.siege.value(v, t, air)
		var best_k := -INF
		for n in MapData.neighbors4(t):
			var val := game.siege.value(v, n, air)
			if val >= Siege.BLOCKED or val <= here or game.siege.enter_cost(v, n, air) > int(Config.SIEGE["slow_cost"]) or (not air and game.siege.barrier_at(v, n) != null):
				continue
			# Farther from the huts; between equals, farther from the walls.
			var k := val * 100.0 + Hero.rect_distance(v.rect, Vector2(n))
			if k > best_k:
				best_k = k
				best = n
		if best == t:
			break
		t = best
	breach = null
	path = PackedVector2Array()
	path_index = 0
	set_grid_pos(Vector2(t) + _jitter)
	Combat.burst(game, "warp", position + Vector2(0, -16), 0.8)


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
	if (raised or undead) and category == "holy":
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
	if not dead:
		_draw_water()
	if channel_to != Vector2.INF and not dead:
		# The necromancer's green beam to the corpse, flickering.
		var to := Iso.to_world(channel_to) - position
		var from := Vector2(8, -40)
		var a := 0.45 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
		draw_line(from, to, Color(0.42, 1.0, 0.54, a * 0.5), 6.0)
		draw_line(from, to, Color(0.75, 1.0, 0.8, a), 2.0)
		draw_circle(to, 7.0 + 2.0 * sin(Time.get_ticks_msec() / 120.0), Color(0.42, 1.0, 0.54, a * 0.35))
	if dead or hp >= max_hp or dive == Dive.DOWN:
		return
	_draw_hp_bar(28.0, -62.0 if flies() else float(spec().get("hp_bar_y", -46.0)), 5.0, hp / max_hp, Color("4a1510"), Color("d8412f"))


## Water monsters: ripples and a trail of bubbles while under; a siren's song
## ring; a leviathan's water column; an octopus's arms (see `fx`).
func _draw_water() -> void:
	var ms := Time.get_ticks_msec() / 1000.0
	var big := 1.8 if habitat() == "water" else 1.0
	if dive != Dive.UP:
		for i in 3:
			var k := fmod(ms * 0.7 + i / 3.0, 1.0)
			var rx := (8.0 + 22.0 * k) * big
			_ring(Vector2.ZERO, rx, rx * 0.45, Color(0.8, 0.92, 1.0, 0.55 * (1.0 - k)), 2.0)
		for i in 4:
			var k := fmod(ms * 1.1 + i * 0.27, 1.0)
			var bx := sin(ms * 3.0 + i * 1.7) * 6.0 * big
			draw_circle(Vector2(bx, -2.0 - 10.0 * k), 1.5 + 1.5 * k, Color(0.9, 0.97, 1.0, 0.7 * (1.0 - k)))
	if fx.has("song"):
		var r := float(fx["song"]) * Iso.HALF_W
		var pulse := 0.5 + 0.5 * sin(ms * 4.0)
		_ring(Vector2.ZERO, r, r * 0.5, Color(0.55, 0.95, 0.9, 0.35 + 0.15 * pulse), 3.0)
		_ring(Vector2.ZERO, r * 0.66, r * 0.33, Color(0.55, 0.95, 0.9, 0.18 + 0.1 * pulse), 2.0)
		for i in 3:  # notes drifting up
			var k := fmod(ms * 0.5 + i / 3.0, 1.0)
			var at := Vector2(-14.0 + 14.0 * i, -50.0 - 26.0 * k)
			var col := Color(0.7, 1.0, 0.95, 1.0 - k)
			draw_circle(at, 3.0, col)
			draw_line(at + Vector2(2.5, 0), at + Vector2(2.5, -10), col, 1.5)
			draw_line(at + Vector2(2.5, -10), at + Vector2(6.5, -7), col, 1.5)
	if fx.has("jet"):
		var to := Iso.to_world(Vector2(fx["jet"])) - position
		var wind := float(fx.get("wind", 1.0))
		var from := Vector2(0, -40)
		if wind < 1.0:  # winding up: a ring tightening on the target
			_ring(to, 26.0 * (1.0 - wind) + 8.0, (26.0 * (1.0 - wind) + 8.0) * 0.5, Color(0.6, 0.85, 1.0, 0.4 + 0.5 * wind), 3.0)
		else:
			var w := 9.0 + 3.0 * sin(ms * 25.0)
			draw_line(from, to, Color(0.35, 0.6, 0.95, 0.5), w * 1.8)
			draw_line(from, to, Color(0.75, 0.9, 1.0, 0.9), w * 0.7)
			draw_circle(to, 10.0 + 3.0 * sin(ms * 20.0), Color(0.85, 0.95, 1.0, 0.6))
	if fx.has("arms"):
		for tip in fx["arms"]:
			_tentacle(Iso.to_world(Vector2(tip)) - position, ms)


## A tentacle from the body to `to` (local), curling a little.
func _tentacle(to: Vector2, ms: float) -> void:
	var from := Vector2(0, -12)
	var pts := PackedVector2Array()
	var side := (to - from).orthogonal().normalized()
	for i in 13:
		var k := i / 12.0
		var wave := sin(k * PI * 2.0 + ms * 4.0) * 7.0 * sin(k * PI)
		pts.append(from.lerp(to, k) + side * wave)
	for i in pts.size() - 1:
		var k := i / 12.0
		draw_line(pts[i], pts[i + 1], Color("15110d"), 11.0 * (1.0 - k * 0.7) + 2.0)
	for i in pts.size() - 1:
		var k := i / 12.0
		draw_line(pts[i], pts[i + 1], Color("8a3a5a"), 11.0 * (1.0 - k * 0.7))
	for i in range(2, 12, 2):
		draw_circle(pts[i] - side * 2.0, 1.8 * (1.0 - i / 14.0) + 0.6, Color("e0b8c8"))


func _ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w)
