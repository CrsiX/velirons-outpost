class_name SnakeBehavior
extends MeleeBehavior
## The snake (Config.ENEMIES["snake"]; docs/enemies-design.md §15g): bites
## like a melee kind, but its bite is a poison dose (Enemy.blow). It can't
## break anything, so at a village without a breach it lurks (Enemy.lurker):
## out of the towers' reach ("lurk_shy") it goes for the nearest of ours
## outside within hunt_radius tiles. Through a breach it mauls ("raid").


## Who it went for last time it looked (for the log: only changes are told).
var _quarry_id := 0


## Lurking: the nearest of ours outside within hunt_radius (a villager out
## of the walls, the hero, a soldier or an elemental), else it roams.
func lurk_goal(enemy: Enemy) -> Vector2:
	var r := float(enemy.spec()["hunt_radius"])
	var best: Node = null
	var best_d := r
	var tree := enemy.get_tree()
	for node in tree.get_nodes_in_group("melee_defenders") + tree.get_nodes_in_group("villagers"):
		if node.dead or _sheltered(node):
			continue
		var d: float = (node.grid_pos as Vector2).distance_to(enemy.grid_pos)
		if d <= best_d:
			best_d = d
			best = node
	var id := best.get_instance_id() if best != null else 0
	if id != _quarry_id:
		_quarry_id = id
		if best != null:
			note(enemy, "%s, lurking, slithers after %s" % [enemy.label(), enemy.game.who(best)])
		else:
			note(enemy, "%s, lurking, finds no one to bite and roams" % enemy.label())
	return best.grid_pos if best != null else Vector2.INF
