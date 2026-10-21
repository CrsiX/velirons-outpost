class_name FleeBehavior
extends EnemyBehavior
## The undead horse (Config.ENEMIES["horse"]; docs/enemies-design.md §15e): it
## never fights. It bolts to the spot within flee_search tiles with the fewest
## of our people and towers around (looking again every flee_every s) and
## dies of the raised drain. Unraised (a debug one) it vanishes after flee_time s.

## Tiles round a spot in which our people and towers count against it.
const WATCH := 5.0

var _again := 0.0
var _age := 0.0


func tick(enemy: Enemy, delta: float) -> bool:
	_age += delta
	if not enemy.raised and _age >= float(enemy.spec()["flee_time"]):
		enemy.vanish()
		return true
	_again -= delta
	if _again <= 0.0:
		_again = float(enemy.spec()["flee_every"])
		_bolt(enemy)
	enemy.walk_own(delta)
	return true


## The quietest of a few spots round it it can walk to (not in a village).
func _bolt(enemy: Enemy) -> void:
	var game := enemy.game
	var pathing := game.world.pathing
	var r := float(enemy.spec()["flee_search"])
	var best := enemy.current_tile()
	var best_k := _danger(enemy, enemy.grid_pos)
	for i in 16:
		var t := Vector2i((enemy.grid_pos + Vector2.from_angle(TAU * (i + randf()) / 16.0) * r * randf_range(0.5, 1.0)).round())
		if not pathing.is_walkable(t) or game.map.village_at(t) >= 0:
			continue
		var k := _danger(enemy, Vector2(t))
		if k < best_k:
			best_k = k
			best = t
	if best == enemy.current_tile():
		return
	var p := pathing.find_path(enemy.current_tile(), best)
	if p.size() > 1:
		p[0] = enemy.grid_pos
		enemy.follow(p)


## How many of our people (villagers outside, the hero, soldiers, summons)
## are within WATCH tiles of `at`, a manned tower in range counting twice.
static func _danger(enemy: Enemy, at: Vector2) -> float:
	var n := 0.0
	var tree := enemy.get_tree()
	for node in tree.get_nodes_in_group("melee_defenders") + tree.get_nodes_in_group("villagers"):
		if not node.dead and not _sheltered(node) and (node.grid_pos as Vector2).distance_to(at) <= WATCH:
			n += 1.0
	for b in enemy.game.world.towers():
		var t := b as Tower
		if t and t.garrison != null and t.garrison.state == MilitaryUnit.State.STATIONED and Vector2(t.tile).distance_to(at) <= t.range_tiles():
			n += 2.0
	return n
