class_name EnemyBehavior
extends RefCounted
## What an enemy does besides walking to a gate. One instance per enemy.


## A villager enemies can't get at (at home, in a mine, inside the walls).
## The hero is a Civilian too, but never counts as sheltered.
static func _sheltered(node) -> bool:
	return node is Civilian and not (node is Hero) and not (node as Civilian).is_exposed()


## Not part of any wave, and never goes for a village by road (camp guards,
## wrathwoods): the wave's checks, warning lights and the timeline skip it.
func wild() -> bool:
	return false


## A blow that cleaves (the court champion's: "cleave", "cleave_radius"):
## everyone else of ours within cleave_radius of `foe` takes cleave x its
## damage (soldiers, summons, the hero, villagers outside).
static func cleave(enemy: Enemy, foe: Node) -> void:
	var share := float(enemy.spec().get("cleave", 0.0))
	if share <= 0.0 or not is_instance_valid(foe):
		return
	var r := float(enemy.spec()["cleave_radius"])
	var at: Vector2 = foe.grid_pos
	var tree := enemy.get_tree()
	for node in tree.get_nodes_in_group("melee_defenders") + tree.get_nodes_in_group("villagers"):
		if node == foe or node.dead or _sheltered(node) or (node.grid_pos as Vector2).distance_to(at) > r:
			continue
		node.take_damage(enemy.stat("damage") * share, enemy, enemy.attack_category())


## Called every frame. Return true to hold the enemy in place this frame
## (e.g. while fighting or casting), false to let it keep walking.
func tick(_enemy: Enemy, _delta: float) -> bool:
	return false


## Breaking in (docs/siege-design.md §5.3): one blow at the barrier `b` in
## its way, `damage` x the kind's `siege`. Returns the seconds until the next
## (0: it can't hurt it, and waits).
func siege_attack(enemy: Enemy, b: Building) -> float:
	var dmg := enemy.stat("damage") * float(enemy.spec().get("siege", 0.0))
	if dmg <= 0.0:
		return 0.0
	enemy.swing(Vector2(b.tile))
	b.take_damage(dmg, enemy)
	return enemy.stat("attack_cooldown") / enemy.haste()


## Called when the enemy is hurt by `source` (a Tower, or a melee defender).
func on_damaged(_enemy: Enemy, _source: Node) -> void:
	pass


## Called when the enemy's walk ends (normally: at a gate). Return true when
## the behavior took care of it (a thief turns back with its loot); false and
## it has reached the gate.
func on_path_end(_enemy: Enemy) -> bool:
	return false


## Called right after the enemy lost HP, before it may die (a vampire saves
## itself as a bat here).
func on_hurt(_enemy: Enemy) -> void:
	pass


## Called once when the enemy dies or vanishes.
func on_death(_enemy: Enemy) -> void:
	pass


## Called every frame on every machine (a co-op client too), for looks only.
func animate(_enemy: Enemy, _delta: float) -> void:
	pass


## A fighter of any village near `enemy`: the hero, a soldier or an elemental
## within `r` tiles, or a manned tower that has it in range. Units that can't
## hurt it (a Healing Mage, a High Priest) don't count.
static func _fighter_near(enemy: Enemy, r: float) -> bool:
	for node in enemy.get_tree().get_nodes_in_group("melee_defenders"):
		if not node.dead and not (node is Soldier and not node.unit.fights()) and node.grid_pos.distance_to(enemy.grid_pos) <= r:
			return true
	for b in enemy.game.world.towers():
		var t := b as Tower
		if t and t.garrison != null and t.garrison.state == MilitaryUnit.State.STATIONED and t.garrison.fights() \
				and Vector2(t.tile).distance_to(enemy.grid_pos) <= t.range_tiles():
			return true
	return false
