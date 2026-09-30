class_name ThiefBehavior
extends MeleeBehavior
## Thieves (Config.ENEMIES["thief"]) fight like goblins on the way. At a gate
## they burn nothing: they steal gold (Game.thief_steals) and run back the way
## they came, carrying it (Enemy.loot_gold, shown as a sack). Back at the map
## edge they are gone with it; killed on the way, their corpse holds it.

var escaping := false


func on_path_end(enemy: Enemy) -> bool:
	if escaping:
		var v := enemy.target_village
		if v and enemy.loot_gold > 0:
			v.events.info("%s got away with %d gold" % [enemy.label().capitalize(), enemy.loot_gold])
		enemy.vanish()
		return true
	enemy.set_loot(enemy.game.thief_steals(enemy))
	escaping = true
	var back := enemy.path.duplicate()
	back.reverse()
	back[0] = enemy.grid_pos
	enemy.follow(back)
	return true
