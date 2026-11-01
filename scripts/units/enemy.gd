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
	"captain": preload("res://scripts/units/enemies/captain_behavior.gd"),
	"commander": preload("res://scripts/units/enemies/commander_behavior.gd"),
	"legion_archer": preload("res://scripts/units/enemies/legion_archer_behavior.gd"),
	"spider_mother": preload("res://scripts/units/enemies/spider_mother_behavior.gd"),
	"egg": preload("res://scripts/units/enemies/egg_behavior.gd"),
	"wrathwood": preload("res://scripts/units/enemies/wrathwood_behavior.gd"),
	"vulture": preload("res://scripts/units/enemies/vulture_behavior.gd"),
	"mounted": preload("res://scripts/units/enemies/mounted_behavior.gd"),
	"flee": preload("res://scripts/units/enemies/flee_behavior.gd"),
	"ghost": preload("res://scripts/units/enemies/ghost_behavior.gd"),
	"snake": preload("res://scripts/units/enemies/snake_behavior.gd"),
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
## Rooted by a thornling (root): seconds left, and when it may be rooted again (Game.clock).
var _root_left := 0.0
var _root_free_at := -1.0
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
## A name of its own (the campaign's Legion captains: "Lysa"), shown over
## its head and used in the log; "" for the rest.
var given_name := ""
## Its art instead of its kind's (a named captain's own look), "" for none.
var art_override := ""
## Falling back (a Legion captain, CaptainBehavior): nothing targets it.
var retreating := false
## Spared for a scene of a scenario's story (scenario 9's octopus while its
## alarm plays): nothing targets or hurts it meanwhile.
var spared := false
## Where it came onto the map (its road's first tile).
var home_tile := Vector2i.ZERO
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
## A flyer on the ground for now (a vulture eating): see set_landed.
var landed := false
## Meals eaten (a vulture: each one makes it bigger and stronger).
var fed := 0
## A necromancer's spell on a corpse there (grid position; INF = none).
var channel_to := Vector2.INF
var _fly_t := 0.0
var _fly_base := Vector2.ZERO
var _shadow: Polygon2D
## A slime's colour (Config.SLIME_COLORS), rolled at spawn; "" for the rest.
var color := ""
var _sack: Sprite2D
var dive := Dive.UP
## A ghost out of sight (docs/enemies-design.md §15f): untargetable, harmless,
## and no villager runs from it. GhostBehavior sets it.
var faded := false
var _fade_tween: Tween
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
var _siege_cd := 0.0
var _siege_scan := 0.0
## A lurker (lurker()) roaming outside walls it can't break (Config.LURK,
## docs/enemies-design.md §7a), and the seconds it has lurked in all.
var lurking := false
var lurked := 0.0
var _lurk_rest := 0.0
## Gave up (Waves: only enemies that can't get in are left): it walks back the
## way it came and vanishes at the map edge, and can be killed on the way.
var leaving := false
## Slithering (slithers()): tiles moved, and where it was last frame.
var _slither_dist := 0.0
var _slither_from := Vector2.INF
## When it last stopped breaking in (game.clock; -INF: never), for the log.
var _siege_left_at := -INF
## Seconds an intact gate has held it ("entry": "slip").
var _slip := 0.0
## The hut it got to: Game.on_enemy_reached_gate burns this one.
var raid_hut: Hut = null
## A guard of a place, not a wave member (the campaign's octopus at the
## abbey): a water monster keeps to the deep tiles within `post_leash` of
## `post` ((-1, -1): none; AquaBehavior).
var post := Vector2i(-1, -1)
var post_leash := 0.0
## An octopus's arm with someone in its grip (OctopusBehavior: HOLD). Towers
## shoot such arms first where the scenario says so (Scenario.arms_first).
var holding := false
## A scenario's errand for it, or null (scenario 9's Legion company,
## LegionCompany): asked first when its walk ends (on_path_end(enemy) -> bool:
## true when it took care of it), so the end of a path it was given isn't a gate;
## while its holds(enemy) is true the siege leaves it alone (it goes its own way inside).
var errand: Object = null
## Its damage and spell damage x this (a scenario's boss: the leviathan).
var power := 1.0
## Game.clock when it last took damage (-INF: never).
var hurt_at := -INF
var _haste := 1.0
var _guard := 1.0
var _haste_at := -INF
## Riding (docs/enemies-design.md §15e): the animal it rides ("wolf",
## "horse": an ENEMIES kind; "" on foot) and the mount's HP. While the mount
## lives every hit lands on it (take_damage), none on the rider.
var mount := ""
var mount_hp := 0.0
var mount_max := 0.0
## Ridden MOUNTED charge_distance tiles without a fight: its next blow is a
## charge (MountedBehavior).
var charge_ready := false
var _ridden := 0.0
var _ride_from := Vector2.ZERO
var _dust_in := 0.0
## Seconds a halberdier's blow still halts its mount.
var _halt_left := 0.0
## Mounted, it rides into its village through an open breach (MountedBehavior
## sets it): it may break in like anyone on foot, but hits no barrier.
var ride_in := false


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
	home_tile = route[0]
	set_grid_pos(pts[0])
	follow(pts)
	behavior = BEHAVIORS[spec()["behavior"]].new()
	if spec().has("mount"):
		give_mount(str(spec()["mount"]), float(spec()["mount_hp"]))
	if flies() or hovers():
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


## A thornling's blow roots it in place for `seconds`: it can't walk (_walk_factor),
## but fights, casts and shoots on. Not a flyer, not while rooted, and not again
## until SUMMONS.thorn.root_immunity seconds after a root wore off. Whether it took.
func root(seconds: float) -> bool:
	if dead or flies() or _root_left > 0.0 or game.clock < _root_free_at:
		return false
	_root_left = seconds
	_root_free_at = game.clock + seconds + float(Config.SUMMONS["thorn"]["root_immunity"])
	queue_redraw()
	return true


func is_rooted() -> bool:
	return _root_left > 0.0


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


## One blow of its at `foe` (one of ours, not a building) for `amount`: a hit
## of its attack_category, or for a poisoner a dose (Poison.give).
func blow(foe: Node, amount: float) -> void:
	if attack_category() == "poison":
		Poison.give(foe, amount, self)
	else:
		foe.take_damage(amount, self, attack_category())


## Flies (gargoyles; a vampire in bat form): keeps to the roads, but no
## ground slows it, and only ranged attacks and other flyers can go for it.
func flies() -> bool:
	return (airborne or spec().get("flying", false)) and not landed


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
	return not dead and dive == Dive.UP and not retreating and not spared and not faded


## Does a hit of `category` (Config.DAMAGE_CATEGORIES) hurt it at all? A ghost
## takes none of a melee or projectile hit: whoever deals only that can't go for it.
func hurt_by(category: String) -> bool:
	return damage_factor(category) > 0.0


## What it takes of a hit of `category`: its kind's "resist", and for the
## raised and undead the necromancer's raised_holy and raised_poison on top.
func damage_factor(category: String) -> float:
	var f := float(spec().get("resist", {}).get(category, 1.0))
	if raised or undead:
		var n: Dictionary = Config.ENEMIES["necromancer"]
		if category == "holy":
			f *= float(n["raised_holy"])
		elif category == "poison":
			f *= float(n["raised_poison"])
	return f


## Villagers run from it? (Not a kind that "scares" nobody, nor a faded ghost.)
func scary() -> bool:
	return spec().get("scares", true) and not faded


## A ghost turns faded or solid (the look takes GHOST.phase_time).
func set_faded(on: bool) -> void:
	if faded == on:
		return
	faded = on
	if _fade_tween:
		_fade_tween.kill()
	if dead:
		return
	var to: float = float(Config.GHOST["faded_alpha"]) if on else 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", to, float(Config.GHOST["phase_time"]))


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
	return "unit_%s%s" % [art_base(), "_" + color if color != "" else ""]


## Its sprite again (a new look: identity, colour, mount), facing the same way.
func _refresh_art() -> void:
	var flip := sprite.flip_h
	Art.apply(sprite, unit_art())
	sprite.flip_h = flip


## A name and a look of its own (a named Legion captain).
func set_identity(p_name: String, p_art: String) -> void:
	given_name = p_name
	if p_art != "" and p_art != art_override:
		art_override = p_art
		_refresh_art()
	queue_redraw()


## A slime's halves keep its colour.
func set_color(c: String) -> void:
	if c == "" or c == color:
		return
	color = c
	_refresh_art()


## Jelly (slimes): squashes and stretches as it walks.
func is_jelly() -> bool:
	return spec().has("colors")


## Split off a bigger slime: it pops out of it.
func pop_in() -> void:
	scale = Vector2(0.4, 0.4)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate(delta: float) -> void:
	if _wades() or hovers():
		return  # (see _wade: no walking sway in the water; a ghost floats instead)
	if slithers():
		_slither()
		return
	if not is_jelly():
		super._animate(delta)
		if charge_ready and mount != "":
			sprite.rotation += -0.12 if sprite.flip_h else 0.12
		return
	_bob += delta * 8.0
	var q := sin(_bob) * 0.1
	sprite.scale = Vector2(0.5 * (1.0 + q), 0.5 * (1.0 - q))


func _set_moving(v: bool) -> void:
	super._set_moving(v)
	if not v and is_jelly():
		sprite.scale = Vector2(0.5, 0.5)
	if not v and slithers():
		_slither_from = Vector2.INF
		_show_art(unit_art())  # (coiled)


## Slithers (a snake: its kind's "slither" frames) instead of walking.
func slithers() -> bool:
	return spec().has("slither")


## The next slither frame: one every slither_step tiles it moved, so it never
## slides on the spot (slowed, rooted) and every speed looks right.
func _slither() -> void:
	if _slither_from != Vector2.INF:
		_slither_dist += grid_pos.distance_to(_slither_from)
	_slither_from = grid_pos
	var f := int(_slither_dist / float(spec()["slither_step"])) % int(spec()["slither"])
	_show_art("unit_%s_slither_%d" % [art_base(), f])


## Shows the sprite `art` (unless it already does), keeping its facing and scale.
func _show_art(art: String) -> void:
	if sprite.texture == Art.tex(art):
		return
	var flip := sprite.flip_h
	var sc := sprite.scale
	Art.apply(sprite, art)
	sprite.flip_h = flip
	sprite.scale = sc


## The art it shows now: its own, or the bat's; a rider its kind doesn't
## mount by itself (a captain on a horse): its art + "_mounted".
func art_base() -> String:
	if airborne:
		return "vampire_bat"
	if landed and spec().has("landed_art"):
		return str(spec()["landed_art"])
	var base := art_override if art_override != "" else str(spec()["art"])
	return base + "_mounted" if mount != "" and not spec().has("mount") else base


# --- riding (docs/enemies-design.md §15e) ---------------------------------------------------

## On a mount: `animal` (an ENEMIES kind) with `base_hp` HP, scaled like its
## own HP (wave, difficulty). A kind that doesn't ride by itself (a captain
## a scenario puts on a horse) gets MOUNTED mounts' speed.
func give_mount(animal: String, base_hp: float) -> void:
	mount = animal
	mount_max = base_hp * hp_scale * Settings.enemy_multiplier("hp")
	mount_hp = mount_max
	_ridden = 0.0
	_ride_from = grid_pos
	if not spec().has("mount"):
		var m: Dictionary = Config.MOUNTED["mounts"][animal]
		set_walk_speed(float(m["speed"]) * Settings.enemy_multiplier("speed") * randf_range(0.92, 1.08))
		_refresh_art()
	queue_redraw()


## Its walking speed without slows is `v` now (a slow on it goes on).
func set_walk_speed(v: float) -> void:
	base_speed = v
	speed = v * (_slow if _slow_left > 0.0 else 1.0)


## Its mount is gone: `slain` (killed by `source`: Waves.mount_fell pays its
## gold and lays its corpse) or it got off (at a gate: the mount runs off).
## A kind with a "rider" turns into that kind here, in place; anyone else
## goes on on foot. Then its behavior hears of it (on_dismount).
func dismount(source: Node = null, slain := true) -> void:
	if mount == "" or dead:
		return
	var animal := mount
	if slain:
		killer = source
		game.waves.mount_fell(self, animal)
		killer = null
	else:
		_run_off(animal)
		if is_instance_valid(target_village):
			target_village.events.debug("%s gets off its %s" % [label(), animal])
	mount = ""
	mount_hp = 0.0
	mount_max = 0.0
	charge_ready = false
	_halt_left = 0.0
	Combat.burst(game, "dust", position, 0.7)
	var rider := str(spec().get("rider", ""))
	if rider != "":
		_become(rider)
	else:
		set_walk_speed(stat("speed") * randf_range(0.92, 1.08) * (float(spec().get("retreat_speed", 1.0)) if retreating else 1.0))
		_refresh_art()
	queue_redraw()
	behavior.on_dismount(self, slain)


## Turns into `new_kind` where it stands (a raider's goblin): a new number,
## its HP (the same share of it), speed, behavior and look; its wave, road
## and target stay.
func _become(new_kind: String) -> void:
	var share := hp / max_hp if max_hp > 0.0 else 1.0
	var old := label()
	kind = new_kind
	uid = game.next_id(kind)
	max_hp = stat("hp") * hp_scale
	hp = max_hp * share
	set_walk_speed(stat("speed") * randf_range(0.92, 1.08))
	behavior = BEHAVIORS[spec()["behavior"]].new()
	_refresh_art()
	if is_instance_valid(target_village):
		target_village.events.debug("%s fights on as %s" % [old, label()])


## The mount runs off the map: its picture galloping away and fading (a
## look only: no corpse, no gold).
func _run_off(animal: String) -> void:
	var s := Art.sprite("unit_" + str(Config.ENEMIES[animal]["art"]))
	var away := Vector2.RIGHT
	if is_instance_valid(target_village):
		away = (grid_pos - Vector2(target_village.center)).normalized()
	s.flip_h = Iso.to_world(away).x < 0.0
	s.position = position
	game.world.effects.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "position", Iso.to_world(grid_pos + away * 4.0), 1.6)
	tw.tween_property(s, "modulate:a", 0.0, 1.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)


## A halberdier's blow: the mount stops for `seconds`.
func halt(seconds: float) -> void:
	if mount != "":
		_halt_left = maxf(_halt_left, seconds)


## Its charge is used up (a blow, or a halberdier broke it): it has to ride
## charge_distance tiles again.
func spend_charge() -> void:
	charge_ready = false
	_ridden = 0.0
	_ride_from = grid_pos


## Counts the ground it rides: far enough without a fight, it charges (never
## while a scenario's errand leads it: scenario 9's Lysa).
func _tick_ride(delta: float) -> void:
	if _halt_left > 0.0:
		_halt_left -= delta
	_ridden += grid_pos.distance_to(_ride_from)
	_ride_from = grid_pos
	if not charge_ready and errand == null and _ridden >= float(Config.MOUNTED["charge_distance"]):
		charge_ready = true


## Charging (every machine, for looks): dust under the hooves (and leaning
## into it, see _animate).
func _charge_look(delta: float) -> void:
	if not (charge_ready and moving):
		return
	_dust_in -= delta
	if _dust_in <= 0.0:
		_dust_in = 0.22
		Combat.local_burst(game, "dust", position + Vector2(-10.0 if not sprite.flip_h else 10.0, 0.0), 0.35)


## Co-op client: the host's mount, its HP and the charge (and the kind it is now).
func net_mount(p_kind: String, p_mount: String, p_hp: float, p_max: float, p_charge: bool) -> void:
	var looks := false
	if p_kind != kind:
		kind = p_kind
		looks = true
	if p_mount != mount:
		if p_mount == "":
			Combat.local_burst(game, "dust", position, 0.7)
		mount = p_mount
		looks = true
	mount_hp = p_hp
	mount_max = p_max
	charge_ready = p_charge
	if looks:
		_refresh_art()


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


## A flyer comes down (`on`: a vulture landing at its meal, a ground target
## then) or takes off again.
func set_landed(on: bool) -> void:
	if landed == on:
		return
	landed = on
	var flip := sprite.flip_h
	Art.apply(sprite, "unit_" + art_base())
	sprite.flip_h = flip
	if landed:
		_land()
	else:
		_take_off()
	set_fed(fed)  # (Art.apply resets the size)


## `n` meals eaten: drawn a little bigger with each (the stats: VultureBehavior).
func set_fed(n: int) -> void:
	fed = n
	sprite.scale = Vector2(0.5, 0.5) * (1.0 + 0.1 * fed)


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
	if _root_left > 0.0 or _halt_left > 0.0:
		return 0.0  # (held by roots, or a halberdier halted its mount)
	return 1.0 if flies() or habitat() != "land" or spec().get("ethereal", false) else super._walk_factor()


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


## Not part of any wave (a camp guard, a wrathwood; EnemyBehavior.wild; a
## guard of a place, `post`: scenario 9's octopus).
func wild() -> bool:
	return post.x >= 0 or (behavior != null and behavior.wild())


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
	if given_name != "":
		return given_name
	return "%s %d" % [str(spec()["name"]).to_lower(), uid]


## A config value for this kind, difficulty-scaled where appropriate (and
## `power` for a boss's damage).
func stat(key: String) -> float:
	if power != 1.0 and (key == "damage" or key == "spell_damage"):
		return Config.enemy_stat(kind, key) * power
	return Config.enemy_stat(kind, key)


## How much faster its blows and shots come: a Dread Legion soldier within a
## living banner-bearer's banner_radius strikes 1 + banner_haste times as
## fast, within a commander's command_radius 1 + command_haste times (the
## strongest counts); everyone else 1. Checked every 0.5 s.
func haste() -> float:
	_lead()
	return _haste


## The share of damage it takes: a Dread Legion soldier within a living
## commander's command_radius takes command_guard x (the strongest counts).
func guard() -> float:
	_lead()
	return _guard


## Who leads it (banners, commanders): sets _haste and _guard, every 0.5 s.
func _lead() -> void:
	if not kind.begins_with("legion_"):
		_haste = 1.0
		_guard = 1.0
		return
	if game.clock - _haste_at < 0.5:
		return
	_haste_at = game.clock
	_haste = 1.0
	_guard = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var b := e as Enemy
		if b.dead or b.retreating:
			continue
		var sp := b.spec()
		var d := b.grid_pos.distance_to(grid_pos)
		if sp.has("banner_haste") and d <= float(sp["banner_radius"]):
			_haste = maxf(_haste, 1.0 + float(sp["banner_haste"]))
		if sp.has("command_haste") and d <= float(sp["command_radius"]):
			_haste = maxf(_haste, 1.0 + float(sp["command_haste"]))
			_guard = minf(_guard, float(sp["command_guard"]))


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
	elif hovers():
		_hover(delta)
	if channel_to != Vector2.INF or submerged() or not fx.is_empty():
		queue_redraw()
	if _wades():
		_wade(delta)
	behavior.animate(self, delta)
	if mount != "":
		_charge_look(delta)
	if game.is_client:
		if dive == Dive.DIVING or dive == Dive.SURFACING:
			_dive_t += delta
			_show_dive()
		net_follow(delta)  # the host simulates; we just follow
		return
	if spec().has("submerges"):
		_tick_dive(delta)
	_push_immune -= delta
	if mount != "":
		_tick_ride(delta)
	if raised and decay_rate > 0.0:
		hp -= decay_rate * delta
		queue_redraw()
		if hp <= 0.0:
			decayed = true
			take_damage(1.0, null)
			decayed = dead  # (unless a vampire saved itself as a bat)
			if dead:
				return
	if _root_left > 0.0:
		_root_left -= delta
		if _root_left <= 0.0:
			queue_redraw()  # (the roots let go)
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
		if leaving:
			vanish()
			return
		if _held_at_gate(delta):
			_set_moving(false)
			_update_visibility()
			return
		if errand != null and errand.on_path_end(self):
			_update_visibility()
			return  # (a scenario's errand took care of it)
		if behavior.on_path_end(self):
			return  # (a thief turning back, or escaping)
		if entry() == "siege":
			# A held wall loses no hut (docs/enemies-design.md §7a): from the end
			# of its road it breaks in, lurks, or (it can't) gives up.
			if not _start_siege_at_end():
				_log_unbroken_entry()
				vanish()
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
	return entry() == "siege" and habitat() != "water" and not airborne and not retreating and not leaving and (mount == "" or ride_in) and not game.is_client \
		and is_instance_valid(target_village) and not target_village.fallen and not wild() \
		and not (errand != null and errand.has_method("holds") and errand.holds(self))


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
## gate, or the road ends short of the village): break in (or lurk) from
## here: at the village it stands in, else at its target. Returns whether it does.
func _start_siege_at_end() -> bool:
	var vid := game.map.village_at(current_tile())
	if vid >= 0 and vid < game.villages.size() and (not is_instance_valid(target_village) or target_village.id != vid):
		target_village = game.villages[vid]
	if not _may_siege():
		return false
	sieging = true
	return true


## Its road ended and it couldn't break in or lurk from there: it gives up
## (vanish) rather than get in without a breach. Logged loudly with the
## reason, as this shouldn't happen.
func _log_unbroken_entry() -> void:
	var v := target_village
	if not is_instance_valid(v):
		return
	v.events.important("%s couldn't get at the village and leaves: %s" % [label().capitalize(), _no_siege_reason()])
	v.events.debug(_unbroken_entry_details())


## Everything needed to find out from the game log file why its road ended
## where it couldn't go on (debug detail of _log_unbroken_entry).
func _unbroken_entry_details() -> String:
	var v := target_village
	var here := current_tile()
	var at_vid := game.map.village_at(here)
	var parts: Array[String] = []
	parts.append("enemy %s #%d wave %d, hp %.1f/%.1f, behavior %s" % [kind, uid, wave, hp, max_hp, behavior.get_script().resource_path.get_file()])
	parts.append("raised %s, undead %s, from_lair %s, wild %s, named '%s'" % [raised, undead, from_lair, wild(), given_name])
	parts.append("mount '%s' (ride_in %s), airborne %s, habitat %s, retreating %s, errand %s" % [mount, ride_in, airborne, habitat(), retreating, errand != null])
	parts.append("tile %s, path %d points (index %d) from %s to %s" % [here, path.size(), path_index, path[0] if path.size() > 0 else Vector2.INF, path[path.size() - 1] if path.size() > 0 else Vector2.INF])
	parts.append("sieging %s, left a siege %s, raid_hut %s" % [sieging, ("%.1f s ago" % (game.clock - _siege_left_at)) if _siege_left_at > -INF else "never", raid_hut.label() if is_instance_valid(raid_hut) else "none"])
	parts.append("target village #%d %s rect %s fallen %s; tile in village #%d" % [v.id, v.village_name, v.rect, v.fallen, at_vid])
	parts.append("in siege zone %s, field value %d, best way %d" % [game.siege.in_zone(v, here), game.siege.value(v, here, false), game.siege.best_way(v, here, false)])
	var b = game.map.building_at(here)
	parts.append("on tile: %s" % (("%s (complete %s, devastated %s, hp %.0f)" % [b.label(), b.complete, b.devastated, b.hp]) if b is Building else "nothing"))
	parts.append("village huts intact %d, clock %.1f" % [v.intact_huts().size(), game.clock])
	return "Couldn't get at the village, details: " + "; ".join(parts)


## Why _may_siege() is false (for the log).
func _no_siege_reason() -> String:
	if airborne:
		return "airborne"
	if habitat() == "water":
		return "in the water"
	if retreating:
		return "retreating"
	if mount != "" and not ride_in:
		return "mounted"
	if not is_instance_valid(target_village) or target_village.fallen:
		return "no target village"
	if wild():
		return "wild"
	if errand != null:
		return "held by an errand"
	if leaving:
		return "leaving"
	return "unknown"


## Leaves the siege (a new target village, or a vampire turning into a bat).
func leave_siege() -> void:
	if sieging:
		_siege_left_at = game.clock
	sieging = false
	breach = null
	lurking = false


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
	if lurker():
		return _lurk_tick(v, delta)
	_siege_cd -= delta
	_siege_scan -= delta
	if air:
		breach = null
	if is_instance_valid(breach) and breach.complete and not breach.devastated:
		_at_barrier(v)
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
		if under != null:
			breach = under  # (standing on it: a gate it walked onto)
			return true
	if game.siege.value(v, here, air) >= Siege.BLOCKED:
		return _to_field(v, game.siege.field_entry(v, here, air), delta)  # (its road ended short of the village)
	var n := game.siege.next_step(v, here, air)
	if n == here:
		_set_moving(false)  # (no way in from here: wait)
		return true
	var b := game.siege.barrier_at(v, n) if not air else null
	if b != null:
		breach = b
		face(Vector2(n))
		return true
	follow(PackedVector2Array([grid_pos, Vector2(n) + _jitter]))
	step_path(delta)
	return true


## Walks from outside its village's field to `to`, the field tile nearest it
## (from where the field leads on). Without one it waits.
func _to_field(_v: Village, to: Vector2i, delta: float) -> bool:
	if to.x < 0:
		_set_moving(false)
		return true
	var p := find_way(current_tile(), to)
	if p.size() < 2:
		_set_moving(false)
		return true
	p[0] = grid_pos
	follow(p)
	step_path(delta)
	return true


## In front of a barrier: hits it (EnemyBehavior.siege_attack) and now and
## then checks for a clearly cheaper way.
func _at_barrier(v: Village) -> void:
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


# --- lurking (docs/enemies-design.md §7a) ---------------------------------------------------

## Can't break anything and goes on foot: a lurker (Config.LURK).
func lurker() -> bool:
	return lurker_kind(spec()) and not flies()


## A kind (its ENEMIES entry) that lurks: breaks in by the siege field but
## can't hurt a barrier, and isn't a flyer or a fleeing raised horse.
static func lurker_kind(sp: Dictionary) -> bool:
	return str(sp.get("entry", "siege")) == "siege" and float(sp.get("siege", 0.0)) <= 0.0 \
		and not sp.get("flying", false) and str(sp.get("behavior", "")) != "flee"


## A lurker at its village: in through a breach if there is one (the open
## field: no intact barrier on the way), else it roams outside the walls.
func _lurk_tick(v: Village, delta: float) -> bool:
	var here := current_tile()
	if game.siege.open_way(v):
		if lurking:
			lurking = false
			path = PackedVector2Array()
			path_index = 0
			v.events.debug("%s goes in through the breach" % label())
		if path_index < path.size():
			step_path(delta)
			return true
		var hut := game.siege.hut_at(v, here)
		if hut != null:
			raid_hut = hut
			_get_in()
			return true
		if game.siege.open_value(v, here) >= Siege.BLOCKED:
			return _to_field(v, game.siege.open_entry(v, here), delta)
		var n := game.siege.open_next_step(v, here)
		if n == here:
			_set_moving(false)
			return true
		follow(PackedVector2Array([grid_pos, Vector2(n) + _jitter]))
		step_path(delta)
		return true
	if not lurking:
		lurking = true
		path = PackedVector2Array()
		path_index = 0
		_lurk_rest = 0.0
		v.events.debug("%s can't break in and lurks outside the walls" % label())
	lurked += delta
	if path_index < path.size():
		step_path(delta)
		return true
	_set_moving(false)
	_lurk_rest -= delta
	if _lurk_rest > 0.0:
		return true
	var rest: Array = Config.LURK["rest"]
	_lurk_rest = randf_range(float(rest[0]), float(rest[1]))
	var goal := behavior.lurk_goal(self)
	var to := Vector2i(goal.round()) if goal != Vector2.INF and in_lurk_range(v, Vector2i(goal.round())) else _roam_tile(v)
	if to != here:
		var p := find_way(here, to)
		if p.size() >= 2:
			p[0] = grid_pos
			follow(p)
	return true


## May a lurker of `v` be on `t`? Outside its walls, within the leash.
func in_lurk_range(v: Village, t: Vector2i) -> bool:
	if v.rect.has_point(t) or not game.world.pathing.is_walkable(t):
		return false
	return Hero.rect_distance(v.rect, Vector2(t)) <= float(Config.SIEGE["approach"]) + float(Config.LURK["leash"])


## Somewhere to roam to: a stretch away, outside `v`'s walls within the
## leash; shy kinds ("lurk_shy") out of the reach of manned towers.
func _roam_tile(v: Village) -> Vector2i:
	var here := current_tile()
	var stretch: Array = Config.LURK["stretch"]
	var shy := bool(spec().get("lurk_shy", false))
	var fallback := here
	for i in 16:
		var d := Vector2.from_angle(randf() * TAU) * randf_range(float(stretch[0]), float(stretch[1]))
		var t := Vector2i((grid_pos + d).round())
		if not in_lurk_range(v, t):
			continue
		if shy and tower_reach(Vector2(t)):
			if fallback == here:
				fallback = t
			continue
		return t
	return fallback


## Is `at` within reach (plus LURK tower_margin) of a manned tower of any village?
func tower_reach(at: Vector2) -> bool:
	var margin := float(Config.LURK["tower_margin"])
	for b in game.world.towers():
		var t := b as Tower
		if t and t.garrison != null and t.garrison.state == MilitaryUnit.State.STATIONED and t.garrison.fights() \
				and Vector2(t.tile).distance_to(at) <= t.range_tiles() + margin:
			return true
	return false


## Gives up (Waves: only enemies that can't get in are left of the wave):
## walks back the way it came and vanishes at the map edge, no loot. It can
## still be killed on the way.
func give_up() -> void:
	if leaving or dead:
		return
	leave_siege()
	leaving = true
	breach = null
	if is_instance_valid(target_village):
		target_village.events.info("%s gives up and leaves" % label().capitalize())
	var back := CaptainBehavior.way_back(self)
	if back.size() < 2:
		vanish()
		return
	follow(back)


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
	if dead or spared or faded:
		return
	if mount != "":
		_hurt_mount(amount, source, category)
		return
	amount *= damage_factor(category)
	if category != "pure":
		amount *= guard()  # (a commander's soldiers)
	hp -= amount
	hurt_at = game.clock
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
		if spec().get("release", false):
			_release()
			return
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2(1.2, 0.3), 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)
		return
	if source != null:
		behavior.on_damaged(self, source)


## A hit on its mount (the animal's "resist"; a commander's guard): none of
## it reaches the rider, also when it kills the mount (dismount).
func _hurt_mount(amount: float, source: Node, category: String) -> void:
	amount *= float(Config.ENEMIES[mount].get("resist", {}).get(category, 1.0))
	if category != "pure":
		amount *= guard()
	mount_hp -= amount
	hurt_at = game.clock
	queue_redraw()
	sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if mount_hp <= 0.0:
		dismount(source, true)
		return
	if source != null:
		behavior.on_damaged(self, source)


## A Dread Legion soldier falls (docs/story-design.md §5): the pale colour
## fades into a living one, a breath goes out, and it sinks down and is gone.
func _release() -> void:
	Combat.burst(game, "release", position + Vector2(0, -34), 0.6)
	sprite.self_modulate = Color(0.8, 0.85, 0.95)
	var tw := create_tween()
	tw.tween_property(sprite, "self_modulate", Color(1.08, 0.95, 0.85), 0.45)
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 0.85), 0.6)
	tw.tween_callback(queue_free)


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


## Floats instead of walking (a ghost): bobs gently over its shadow, moving or not.
func hovers() -> bool:
	return spec().get("hover", false)


func _hover(delta: float) -> void:
	_fly_t += delta
	var bob := sin(_fly_t * 2.4)
	# (offset is in texture pixels: the sprite is drawn at half size)
	sprite.offset = _fly_base + Vector2(0.0, (-7.0 - 3.0 * bob) * 2.0)
	if _shadow:
		_shadow.scale = Vector2.ONE * (1.0 - 0.1 * bob)  # smaller while higher


func _draw() -> void:
	if not dead:
		_draw_water()
	if not dead and spec().has("banner_radius"):
		# A banner-bearer: a faint pale ring on the ground, as far as its banner reaches.
		var r := float(spec()["banner_radius"]) * Iso.HALF_W * 1.414
		_ring(Vector2.ZERO, r, r * 0.5, Color(0.86, 0.88, 0.95, 0.22), 2.0)
	if not dead and not retreating and spec().has("command_radius"):
		# A commander: a double ring, cold gold, as far as its command reaches.
		var r := float(spec()["command_radius"]) * Iso.HALF_W * 1.414
		_ring(Vector2.ZERO, r, r * 0.5, Color(0.92, 0.84, 0.6, 0.26), 2.0)
		_ring(Vector2.ZERO, r * 0.94, r * 0.47, Color(0.92, 0.84, 0.6, 0.14), 1.5)
	if _root_left > 0.0 and not dead:
		_draw_roots()
	if channel_to != Vector2.INF and not dead:
		# The necromancer's green beam to the corpse, flickering.
		var to := Iso.to_world(channel_to) - position
		var from := Vector2(8, -40)
		var a := 0.45 + 0.3 * sin(Time.get_ticks_msec() / 90.0)
		draw_line(from, to, Color(0.42, 1.0, 0.54, a * 0.5), 6.0)
		draw_line(from, to, Color(0.75, 1.0, 0.8, a), 2.0)
		draw_circle(to, 7.0 + 2.0 * sin(Time.get_ticks_msec() / 120.0), Color(0.42, 1.0, 0.54, a * 0.35))
	if given_name != "" and not dead:
		var f := ThemeDB.fallback_font
		var w := f.get_string_size(given_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var y := _bar_y() - 10.0
		draw_string_outline(f, Vector2(-w / 2.0, y), given_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.08, 0.06, 0.05, 0.9))
		draw_string(f, Vector2(-w / 2.0, y), given_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8d8b0"))
	if dead or dive == Dive.DOWN:
		return
	var bar_y := -62.0 if flies() else _bar_y()
	if hp < max_hp:
		_draw_hp_bar(28.0, bar_y, 5.0, hp / max_hp, Color("4a1510"), Color("d8412f"))
		bar_y += 7.0
	if mount != "" and mount_hp < mount_max:  # (its mount's, brown)
		_draw_hp_bar(28.0, bar_y, 4.0, mount_hp / mount_max, Color("3a2614"), Color("b07a3a"))


## Where its HP bar goes: its kind's hp_bar_y, higher on a horse it doesn't
## ride by itself (a captain a scenario mounted).
func _bar_y() -> float:
	var y := float(spec().get("hp_bar_y", -46.0))
	return y - 18.0 if mount != "" and not spec().has("mount") else y


## Water monsters: ripples and a trail of bubbles while under; a siren's song
## ring; a leviathan's water column; an octopus's arms (see `fx`).
## Roots: green-brown tendrils curling up round its feet.
func _draw_roots() -> void:
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var base := Vector2(cos(a) * 9.0, sin(a) * 4.0)
		var tip := base * 0.4 + Vector2(0, -11.0 - 3.0 * float(i % 2))
		var mid := (base + tip) * 0.5 + Vector2(cos(a + 1.2) * 4.0, 0)
		draw_polyline(PackedVector2Array([base, mid, tip]), Color("15110d"), 3.2, true)
		draw_polyline(PackedVector2Array([base, mid, tip]), Color("5a7a32") if i % 2 == 0 else Color("6a4a28"), 1.8, true)


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
