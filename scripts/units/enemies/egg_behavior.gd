class_name EggBehavior
extends EnemyBehavior
## A spider mother's egg (Config.ENEMIES["spider_egg"], laid by
## Waves.lay_eggs): it never moves, and after hatch_time s it hatches into
## its hatch_into (Waves.hatch). For the last wobble_time s it wobbles; then
## its broken shell stays a while (Enemy.hatch_out).

var age := 0.0
var _phase := randf() * TAU


func tick(enemy: Enemy, delta: float) -> bool:
	age += delta
	if age >= float(enemy.spec()["hatch_time"]):
		enemy.game.waves.hatch(enemy)
	return true


func on_path_end(_enemy: Enemy) -> bool:
	return true


## Every frame, on every machine (a co-op client counts its own age): it
## wobbles faster and harder the nearer it is to hatching.
func animate(enemy: Enemy, delta: float) -> void:
	if enemy.game.is_client:
		age += delta
	var spec := enemy.spec()
	var k := 1.0 - (float(spec["hatch_time"]) - age) / maxf(float(spec["wobble_time"]), 0.01)
	if k <= 0.0:
		return
	k = minf(k, 1.0)
	var t := age * (12.0 + 10.0 * k) + _phase
	enemy.sprite.rotation = sin(t) * (0.06 + 0.22 * k)
	var q := sin(t * 1.7) * 0.07 * k
	enemy.sprite.scale = Vector2(0.5 * (1.0 + q), 0.5 * (1.0 - q))
