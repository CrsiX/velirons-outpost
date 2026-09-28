class_name ArcherBehavior
extends MilitaryBehavior
## Shoots arrows at the enemy in range that is closest to reaching its gate.

const ARROW_SCRIPT := preload("res://scripts/units/arrow.gd")

var _cooldown := 0.3


func tick(tower: Tower, unit: MilitaryUnit, delta: float) -> void:
	_cooldown -= delta
	var targets := enemies_near(tower, tower.range_tiles())
	if targets.is_empty():
		return
	var target := targets[0]
	tower.face(target.grid_pos)
	if _cooldown <= 0.0:
		_cooldown = unit.stat("cooldown")
		var arrow: Arrow = ARROW_SCRIPT.new()
		tower.game.world.effects.add_child(arrow)
		arrow.launch(tower.muzzle_position(), target, unit.stat("damage"), tower)
		if tower.game.replicator:
			tower.game.replicator.arrow(tower.muzzle_position(), target.hit_point())
		Sfx.play("shoot", 0.15)
		tower.recoil()


func info_lines(unit: MilitaryUnit) -> Array[String]:
	return ["Damage %.0f, one shot every %.2f s" % [unit.stat("damage"), unit.stat("cooldown")]]
