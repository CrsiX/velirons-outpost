class_name Gatherer
extends Civilian
## Stays in the village until enemies have been killed, then collects "safe"
## corpses for gold and a little food. The logic lives in GatherJob (shared
## with the hero).

const State = GatherJob.State

var job := GatherJob.new()
var state: int:
	get: return job.state
var target: Corpse:
	get: return job.target
var carried: Array[String]:
	get: return job.carried


func setup(p_game: Game, p_role: String) -> void:
	super.setup(p_game, p_role)
	job.bind(self)


func _tick(delta: float) -> void:
	job.tick(delta)


func status() -> String:
	return "fleeing from enemies" if evading else job.status()


func _on_evade() -> void:
	job.on_evade()


func _after_evade() -> void:
	job.after_evade()


func _release_jobs() -> void:
	job.release()
