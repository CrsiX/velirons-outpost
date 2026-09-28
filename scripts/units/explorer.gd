class_name Explorer
extends Civilian
## Scouts the fog on their own and runs home when an enemy comes close (shared
## Civilian evasion). The logic lives in ExploreJob (shared with the hero).

const State = ExploreJob.State

var job := ExploreJob.new()
var state: int:
	get: return job.state
var target: Vector2i:
	get: return job.target


func setup(p_game: Game, p_role: String) -> void:
	super.setup(p_game, p_role)
	job.bind(self)


func _tick(delta: float) -> void:
	job.tick(delta)


func exploring_target() -> Vector2i:
	return job.exploring_target()


func status() -> String:
	return "fleeing from enemies" if evading else job.status()


func _on_evade() -> void:
	job.on_evade()


func _release_jobs() -> void:
	job.release()
