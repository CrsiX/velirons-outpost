class_name CommanderBehavior
extends MountedBehavior
## A Dread Legion commander (Config.ENEMIES "legion_marshal", "legion_king";
## the campaign's Halvard and Rhodri, docs/scenarios-design.md §7.16): fights
## like a champion (its blows may cleave, MeleeBehavior), leads the Legion
## soldiers near it (its command aura: Enemy.haste, Enemy.guard), and every
## `rally_every` seconds while it lives sends `rally` more for the wave from
## an edge spawn. "downed": at 0 HP it isn't killed but keeps 1 HP and falls
## back the way it came (as a captain does, CaptainBehavior), and is gone.
## A scenario may put it on a horse (MountedBehavior): it rides with its
## soldiers, and fights on foot once the horse falls (Rhodri's two phases).

var _rally := -1.0


func tick(enemy: Enemy, delta: float) -> bool:
	if enemy.retreating:
		return false  # (only walks away)
	if _rally < 0.0:
		_rally = float(enemy.spec()["first_rally"])
	_rally -= delta
	if _rally <= 0.0:
		_rally = float(enemy.spec()["rally_every"])
		_send_rally(enemy)
	return super.tick(enemy, delta)


## Fresh soldiers for the wave under way, down the road from an edge spawn.
func _send_rally(enemy: Enemy) -> void:
	var waves := enemy.game.waves
	var spawns: Array = enemy.target_village.home_spawns if enemy.target_village and not enemy.target_village.home_spawns.is_empty() else enemy.game.map.edge_spawns
	if spawns.is_empty() or not waves.in_progress():
		return
	var at: Vector2i = spawns[randi() % spawns.size()]
	var rally: Dictionary = enemy.spec()["rally"]
	for k: String in rally:
		waves.add_to_wave(k, at, int(rally[k]))
	if enemy.target_village:
		enemy.target_village.events.info("%s rallies the Legion: more soldiers come down the road" % enemy.label().capitalize())


func on_hurt(enemy: Enemy) -> void:
	if not enemy.spec().get("downed", false) or enemy.hp > 0.0:
		return
	enemy.hp = 1.0
	if enemy.retreating:
		return
	enemy.retreating = true
	_foe = null
	if enemy.sieging:
		enemy.leave_siege()
	enemy.speed = enemy.base_speed * float(enemy.spec()["retreat_speed"])
	enemy.base_speed = enemy.speed
	enemy.modulate.a = 0.75
	if enemy.target_village:
		enemy.target_village.events.important("%s is beaten and falls back" % enemy.label().capitalize())
	enemy.follow(CaptainBehavior._way_back(enemy))
	enemy.queue_redraw()


## Back at the map edge: gone.
func on_path_end(enemy: Enemy) -> bool:
	if not enemy.retreating:
		return super.on_path_end(enemy)
	enemy.vanish()
	return true
