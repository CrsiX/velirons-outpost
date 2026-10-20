class_name Combat
extends RefCounted
## How military units' attacks play out (Config.ATTACKS), the same from a
## tower and out in the field: the shot, then the hit's damage and effect
## (splash, slow, push back, a berserker's lifesteal), and healing for
## healers. Also the High Priests' holy auras (docs/acolyte-design.md §6):
## allies in one deal more damage, necromancers raise slower; the
## warriors' war cries (docs/military-design.md §3a): allies attack faster;
## and the sirens' songs (docs/aquatic-design.md §6): allies attack slower.

const SHOT_SCRIPT := preload("res://scripts/units/shot.gd")
const BURST_SCRIPT := preload("res://scripts/units/military/burst.gd")


## `unit` attacks `target` from world position `from`. `source` is who the
## enemy sees as the attacker (a tower, or the unit's body outside).
static func attack(game: Game, unit: MilitaryUnit, from: Vector2, target: Enemy, source: Node) -> void:
	var a: Dictionary = Config.ATTACKS[unit.spec()["attack"]]
	var dmg := unit.stat("damage") if unit.has_stat("damage") else 0.0
	if is_instance_valid(source) and source.has_method("act_center"):
		dmg *= 1.0 + holy_bonus(game, source.act_center())
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
	if is_instance_valid(t) and not t.dead and not (t as Enemy).targetable():
		return  # it dived meanwhile: the shot fizzles
	var center := Iso.to_grid(at)
	if is_instance_valid(t) and not t.dead:
		var e := t as Enemy
		center = e.grid_pos
		var before := e.hp
		e.take_damage(dmg, source if is_instance_valid(source) else null, a.get("category", "pure"))
		if unit.has_stat("lifesteal"):
			_lifesteal(unit, before - maxf(e.hp, 0.0))
		if not e.dead:
			if unit.has_stat("slow"):
				e.slow(unit.stat("slow"), unit.stat("slow_time"))
			if unit.has_stat("push"):
				e.push_back(unit.stat("push"), a.get("push_immunity", 4.0))
	if a.has("burst"):  # (the acolyte's beam from above, the inquisitor's flash)
		burst(game, a["burst"], Iso.to_world(center), 1.0)
	if unit.has_stat("splash"):
		var r := unit.stat("splash")
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var o := node as Enemy
			if o != t and o.targetable() and o.grid_pos.distance_to(center) <= r:
				o.take_damage(dmg * float(a.get("splash_share", 0.5)), source if is_instance_valid(source) else null, a.get("category", "pure"))
	if a.get("explode", false):
		burst(game, "explosion", Iso.to_world(center) + Vector2(0, -16), unit.stat("splash") if unit.has_stat("splash") else 1.0)


## A berserker below lifesteal_below of its max HP gets back "lifesteal" x
## the HP its blow really took (`dealt`), never above its max.
static func _lifesteal(unit: MilitaryUnit, dealt: float) -> void:
	if dealt <= 0.0 or unit.hp >= unit.max_hp() * float(unit.spec().get("lifesteal_below", 0.5)):
		return
	unit.heal(dealt * unit.stat("lifesteal"))
	if is_instance_valid(unit.walker):
		unit.walker.queue_redraw()


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


# --- holy auras (High Priests) -------------------------------------------------------

## Every High Priest's aura right now: on a tower (as far as the tower
## reaches), or out on a barracks sortie (its own range). Not on a bench, on
## the training grounds or walking. [{"c": grid centre, "r": radius,
## "bonus": damage share, "slow": necromancer factor}], made once per frame.
static var _auras: Array[Dictionary] = []
static var _auras_frame := -1
static var _auras_game := 0


static func holy_auras(game: Game) -> Array[Dictionary]:
	var frame := Engine.get_process_frames()
	if frame == _auras_frame and _auras_game == game.get_instance_id():
		return _auras
	_auras_frame = frame
	_auras_game = game.get_instance_id()
	_auras = []
	for b in game.world.towers():
		var t := b as Tower
		var u := t.garrison
		if t.working() and u != null and u.role() == "support" and u.state == MilitaryUnit.State.STATIONED:
			_auras.append({"c": t.act_center(), "r": t.act_range(), "bonus": u.stat("aura"), "slow": float(u.spec()["necro_slow"])})
	for node in game.get_tree().get_nodes_in_group("field_units"):
		var so := node as Soldier
		if not so.dead and so.unit.role() == "support" and so.unit.out:
			_auras.append({"c": so.grid_pos, "r": so.unit.field_range(), "bonus": so.unit.stat("aura"), "slow": float(so.unit.spec()["necro_slow"])})
	return _auras


## The damage bonus (share) of the strongest aura over `pos` (grid); 0 outside.
## Auras never stack.
static func holy_bonus(game: Game, pos: Vector2) -> float:
	var best := 0.0
	for a in holy_auras(game):
		if pos.distance_to(a["c"]) <= a["r"]:
			best = maxf(best, a["bonus"])
	return best


## Is `pos` (grid) in a High Priest's aura? (The hook for revealing invisible
## enemies, once there are any.)
static func in_holy_aura(game: Game, pos: Vector2) -> bool:
	for a in holy_auras(game):
		if pos.distance_to(a["c"]) <= a["r"]:
			return true
	return false


## How many times as long a necromancer's raise takes at `pos` (grid): 1 outside
## any aura.
static func necro_slow(game: Game, pos: Vector2) -> float:
	var best := 1.0
	for a in holy_auras(game):
		if pos.distance_to(a["c"]) <= a["r"]:
			best = maxf(best, a["slow"])
	return best


# --- war cries (warriors) ------------------------------------------------------------

## How fast `holder`'s attack, summon and heal timers run (1 = normal): 1 + its
## war-cry haste while that lasts, times a siren's slow at `pos` (grid; INF:
## none). `holder`: a MilitaryUnit, Hero or EarthElemental (each has
## cry_bonus / cry_until), or null.
static func haste(game: Game, holder: Object, pos := Vector2.INF) -> float:
	var song := song_rate(game, pos) if pos != Vector2.INF else 1.0
	if holder == null or not is_instance_valid(game) or game.clock >= float(holder.get("cry_until")):
		return song
	return (1.0 + float(holder.get("cry_bonus"))) * song


## A warrior's war cry at `center` (grid): every ally within `radius` tiles,
## of any village (units out on a sortie, tower units by their tower's tile,
## summons, heroes) is hasted by `bonus` for `duration` s. Returns how many.
static func war_cry(game: Game, center: Vector2, radius: float, bonus: float, duration: float) -> int:
	var holders: Array[Object] = []
	for b in game.world.towers():
		var t := b as Tower
		var u := t.garrison
		if t.working() and u != null and u.state == MilitaryUnit.State.STATIONED and t.act_center().distance_to(center) <= radius:
			holders.append(u)
	for node in game.get_tree().get_nodes_in_group("field_units"):
		var so := node as Soldier
		if not so.dead and so.out_fighting() and so.grid_pos.distance_to(center) <= radius:
			holders.append(so.unit)
	for node in game.get_tree().get_nodes_in_group("heroes"):
		var h := node as Hero
		if not h.dead and h.grid_pos.distance_to(center) <= radius:
			holders.append(h)
	for node in game.get_tree().get_nodes_in_group("summons"):
		var e := node as EarthElemental
		if not e.dead and e.grid_pos.distance_to(center) <= radius:
			holders.append(e)
	for h in holders:
		_hasten(game, h, bonus, duration)
	burst(game, "war_cry", Iso.to_world(center), radius)
	Sfx.play("recruit", 0.15)
	return holders.size()


## One haste per holder, never stacked: a cry at least as strong as the one it
## has refills it (the stronger value, the later end); a weaker cry counts only
## once the stronger one has run out.
static func _hasten(game: Game, h: Object, bonus: float, duration: float) -> void:
	var now := game.clock
	var until: float = h.get("cry_until")
	var cur: float = h.get("cry_bonus")
	if now >= until or bonus > cur + 0.0001:
		h.set("cry_bonus", bonus)
		h.set("cry_until", now + duration)
	elif bonus >= cur - 0.0001:
		h.set("cry_until", maxf(until, now + duration))


# --- siren songs (docs/aquatic-design.md §6) ---------------------------------------------

## Every singing siren right now: [{"e": the siren, "c": grid centre, "r":
## radius, "slow", "pull"}], made once per frame.
static var _songs: Array[Dictionary] = []
static var _songs_frame := -1
static var _songs_game := 0


static func songs(game: Game) -> Array[Dictionary]:
	var frame := Engine.get_process_frames()
	if frame == _songs_frame and _songs_game == game.get_instance_id():
		return _songs
	_songs_frame = frame
	_songs_game = game.get_instance_id()
	_songs = []
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e.dead or not e.fx.has("song"):
			continue
		var sp := e.spec()
		_songs.append({"e": e, "c": e.grid_pos, "r": float(e.fx["song"]), "slow": float(sp.get("song_slow", 0.0)), "pull": float(sp.get("song_pull", 0.0))})
	return _songs


## The strongest song over `pos` (grid): [strength 0..1 (1 - d / radius), its
## song entry]; [0, {}] outside every song or inside a High Priest's aura.
static func song_at(game: Game, pos: Vector2) -> Array:
	var best := 0.0
	var which := {}
	for s in songs(game):
		var k := 1.0 - pos.distance_to(s["c"]) / maxf(s["r"], 0.01)
		if k > best:
			best = k
			which = s
	if best > 0.0 and in_holy_aura(game, pos):
		return [0.0, {}]
	return [best, which]


## How fast timers run at `pos` under the strongest song: 1 - slow x strength.
static func song_rate(game: Game, pos: Vector2) -> float:
	if not is_instance_valid(game) or game.world == null:
		return 1.0
	var s := song_at(game, pos)
	if float(s[0]) <= 0.0:
		return 1.0
	return maxf(1.0 - float(s[1]["slow"]) * float(s[0]), 0.05)
