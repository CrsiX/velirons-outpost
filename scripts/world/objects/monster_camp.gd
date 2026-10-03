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
	return "camp_cleared" if cleared else "camp"


func display_name() -> String:
	return "Monster camp"


## Host: the monsters come out at the start.
func spawn_monsters() -> void:
	_spawn_guards(data.get("monsters", []), Config.CAMP_HP_SCALE)


## Can the hero be sent against it now?
func attackable() -> bool:
	return not cleared


func _spawn_guards(kinds: Array, hp_scale: float) -> void:
	left = kinds.size()
	var spots: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := tile + Vector2i(dx, dy)
			if t != tile and game.world.pathing.is_walkable(t):
				spots.append(t)
	for k in kinds.size():
		var home: Vector2i = spots[k % spots.size()] if not spots.is_empty() else tile
		var e: Enemy = ENEMY_SCRIPT.new()
		var route: Array[Vector2i] = [home]
		e.setup(game, route, hp_scale, kinds[k])
		e.behavior = CAMP_BEHAVIOR.new()
		(e.behavior as CampBehavior).setup(self, Vector2(home))
		e.uid = game.next_id(e.kind)
		e.nid = game.register(e)
		e.killed.connect(_on_killed)
		game.world.objects.add_child(e)
		monsters.append(e)


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
	return "Found a monster camp guarding a treasure. Tap it and order: Attack with the hero."


func info() -> Dictionary:
	var d := super.info()
	var lines: Array[String] = d["lines"]
	if cleared:
		lines.append("Cleared. Nothing left to fear here.")
		return d
	lines.append("%d monster%s guard a treasure here." % [left, "" if left == 1 else "s"])
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
