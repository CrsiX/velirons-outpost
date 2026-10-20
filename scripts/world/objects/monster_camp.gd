class_name MonsterCamp
extends MapObject
## A monster camp guarding a treasure (docs/world-design.md §9.3): a tent, a
## fire and 2-4 neutral monsters that stay by the camp (CampBehavior) and
## fight whoever comes close. Only cleared on the player's order: the camp's
## panel has "Attack with the hero". Killed monsters stay dead and hurt ones
## don't heal, so a failed attack isn't wasted.

const ENEMY_SCRIPT := preload("res://scripts/units/enemy.gd")
const CAMP_BEHAVIOR := preload("res://scripts/units/enemies/camp_behavior.gd")

var monsters: Array[Enemy] = []
var cleared := false
## Monsters left (co-op clients know only this).
var left := 0


func art() -> String:
	if _legion():
		return "legion_camp_cleared" if cleared else "legion_camp"
	return "camp_cleared" if cleared else "camp"


## Held by the Dread Legion (the campaign's camps at the court's gates)?
func _legion() -> bool:
	var kinds: Array = data.get("monsters", [])
	return not kinds.is_empty() and kinds.all(func(k) -> bool: return str(k).begins_with("legion_"))


func display_name() -> String:
	return "Legion camp" if _legion() else "Monster camp"


## Host: the monsters come out at the start.
func spawn_monsters() -> void:
	_spawn_guards(data.get("monsters", []), Config.CAMP_HP_SCALE)


## Can the hero be sent against it now?
func attackable() -> bool:
	return not cleared


func _spawn_guards(kinds: Array, hp_scale: float) -> void:
	for k in kinds.size():
		add_guard(str(kinds[k]), hp_scale)


## One more guard of `kind` by the camp (on the next free spot round it).
func add_guard(kind: String, hp_scale: float) -> Enemy:
	var spots: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := tile + Vector2i(dx, dy)
			if t != tile and game.world.pathing.is_walkable(t):
				spots.append(t)
	var home: Vector2i = spots[monsters.size() % spots.size()] if not spots.is_empty() else tile
	var e: Enemy = ENEMY_SCRIPT.new()
	var route: Array[Vector2i] = [home]
	e.setup(game, route, hp_scale, kind)
	e.behavior = CAMP_BEHAVIOR.new()
	(e.behavior as CampBehavior).setup(self, Vector2(home))
	e.uid = game.next_id(e.kind)
	e.nid = game.register(e)
	e.killed.connect(_on_killed)
	game.world.objects.add_child(e)
	monsters.append(e)
	left = monsters.size()
	return e


## A loaded game (docs/save-design.md): one guard as it was saved
## (SaveGame: kind, HP, position, home spot, ids).
func restore_guard(d: Dictionary) -> void:
	var home: Vector2 = d["home"]
	var e: Enemy = ENEMY_SCRIPT.new()
	var route: Array[Vector2i] = [Vector2i(home.round())]
	e.setup(game, route, float(d["hs"]), str(d["k"]))
	e.set_color(str(d.get("c", "")))
	e.wave = int(d["w"])
	e.hp = clampf(float(d["hp"]), 1.0, e.max_hp)
	e.set_grid_pos(d["pos"])
	e.behavior = CAMP_BEHAVIOR.new()
	(e.behavior as CampBehavior).setup(self, home)
	e.uid = int(d["u"])
	e.nid = int(d["n"])
	game.register_as(e, e.nid)
	e.killed.connect(_on_killed)
	game.world.objects.add_child(e)
	monsters.append(e)
	left = monsters.size()


func _on_killed(e: Enemy) -> void:
	monsters.erase(e)
	left = monsters.size()
	game.stats.on_kill(e)
	var v := game.village_of(e.killer)
	var gold := Config.enemy_stat_int(e.kind, "gold_on_kill")
	if v:
		v.economy.add("gold", gold, "kills")
		v.events.debug("killed %s at a camp (by %s, +%d gold)" % [e.label(), game.who(e.killer), gold])
	game.world.float_text("+%d {gold}" % gold, e.position + Vector2(0, -50), Color("c9a24a"))
	if monsters.is_empty() and not cleared:
		cleared = true
		_on_cleared(v)
		refresh()
		Sfx.play("build")


func _on_cleared(v: Village) -> void:
	var who := v.village_name if v else "Someone"
	game.log_all(EventLog.Level.INFO, "%s cleared a monster camp. Its treasure is free for the taking." % who)


## Monsters still standing.
func alive() -> Array[Enemy]:
	return monsters.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and not e.dead)


func found_message(_v: Village) -> String:
	if cleared:
		return ""
	return "Found a %s guarding a treasure. Tap it and order: Attack with the hero." % display_name().to_lower()


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if cleared:
		lines.append("Cleared. Nothing left to fear here.")
		return d
	lines.append("%d %s%s guard a treasure here." % [left, "Legion soldier" if _legion() else "monster", "" if left == 1 else "s"])
	_attack_lines(d)
	return d


## "They don't heal" and the Attack with the hero button.
func _attack_lines(d: Dictionary) -> void:
	(d["lines"] as Array).append("They don't heal: a failed attack isn't wasted.")
	var hero := game.player_village.hero
	var busy := hero.camp_target == self
	(d["actions"] as Array).append({
		"label": "The hero is attacking" if busy else "Attack with the hero",
		"disabled": busy or hero.dead or not is_found_by(game.player_village),
		"action": func() -> void: game.command("attack_camp", {"camp": nid}),
	})


func net_state() -> Array:
	return [cleared, left]


func apply_net_state(s: Array) -> void:
	if s.size() >= 2:
		left = int(s[1])
		if bool(s[0]) != cleared:
			cleared = bool(s[0])
			refresh()
