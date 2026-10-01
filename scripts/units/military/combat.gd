class_name Combat
extends RefCounted
## How military units' attacks play out (Config.ATTACKS), the same from a
## tower and out in the field: the shot, then the hit's damage and effect
## (splash, slow, push back), and healing for healers.

const SHOT_SCRIPT := preload("res://scripts/units/shot.gd")
const BURST_SCRIPT := preload("res://scripts/units/military/burst.gd")


## `unit` attacks `target` from world position `from`. `source` is who the
## enemy sees as the attacker (a tower, or the unit's body outside).
static func attack(game: Game, unit: MilitaryUnit, from: Vector2, target: Enemy, source: Node) -> void:
	var a: Dictionary = Config.ATTACKS[unit.spec()["attack"]]
	var dmg := unit.stat("damage") if unit.has_stat("damage") else 0.0
	Sfx.play(a.get("sound", "shoot"), 0.15)
	if a["projectile"] == "":  # a melee strike lands at once
		hit(game, unit, target, dmg, source, target.hit_point())
		return
	var shot: Shot = SHOT_SCRIPT.new()
	shot.source = source
	game.world.effects.add_child(shot)
	shot.launch(a, from, target, func(t, at: Vector2) -> void: hit(game, unit, t, dmg, source, at))
	if game.replicator and game.replicator.hosting:
		game.replicator.shot(unit.spec()["attack"], from, target.hit_point())


## The hit: damage, then the unit's effect. `t` is untyped: the target may
## have been freed while the shot was flying.
static func hit(game: Game, unit: MilitaryUnit, t, dmg: float, source: Node, at: Vector2) -> void:
	var a: Dictionary = Config.ATTACKS[unit.spec()["attack"]]
	var center := Iso.to_grid(at)
	if is_instance_valid(t) and not t.dead:
		var e := t as Enemy
		center = e.grid_pos
		e.take_damage(dmg, source if is_instance_valid(source) else null, a.get("category", "pure"))
		if not e.dead:
			if unit.has_stat("slow"):
				e.slow(unit.stat("slow"), unit.stat("slow_time"))
			if unit.has_stat("push"):
				e.push_back(unit.stat("push"), a.get("push_immunity", 4.0))
	if unit.has_stat("splash"):
		var r := unit.stat("splash")
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var o := node as Enemy
			if o != t and not o.dead and o.grid_pos.distance_to(center) <= r:
				o.take_damage(dmg * float(a.get("splash_share", 0.5)), source if is_instance_valid(source) else null, a.get("category", "pure"))
	if a.get("explode", false):
		burst(game, "explosion", Iso.to_world(center) + Vector2(0, -16), unit.stat("splash") if unit.has_stat("splash") else 1.0)


## The effect on this machine only (each player plays it, e.g. a vampire
## changing shape, which every client sees happen by itself).
static func local_burst(game: Game, kind: String, at: Vector2, radius: float) -> void:
	var b: Node2D = BURST_SCRIPT.new()
	b.setup(kind, radius)
	b.position = at
	game.world.effects.add_child(b)


## Heals every allied unit outside (any village's) and every hero within
## `radius` tiles of `center` (grid) by `amount`; summons aren't healed.
## Returns how many were hurt and got healed.
static func heal_around(game: Game, center: Vector2, radius: float, amount: float) -> int:
	var n := 0
	for s in game.get_tree().get_nodes_in_group("field_units"):
		var so := s as Soldier
		if so.unit.is_downed() or so.grid_pos.distance_to(center) > radius or so.unit.hp >= so.unit.max_hp():
			continue
		so.unit.heal(amount)
		so.queue_redraw()
		n += 1
	for h in game.get_tree().get_nodes_in_group("heroes"):
		var hero := h as Hero
		if hero.dead or hero.grid_pos.distance_to(center) > radius or hero.hp >= hero.max_hp:
			continue
		hero.hp = minf(hero.max_hp, hero.hp + amount)
		hero.queue_redraw()
		hero.changed.emit()
		n += 1
	if n > 0:
		burst(game, "heal", Iso.to_world(center), radius)
	return n


## A short visual effect ("explosion", "heal", "warp") at world position `at`.
static func burst(game: Game, kind: String, at: Vector2, radius: float) -> void:
	local_burst(game, kind, at, radius)
	if game.replicator and game.replicator.hosting:
		game.replicator.burst(kind, at, radius)
