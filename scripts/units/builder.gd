class_name Builder
extends Civilian
## Rest -> claim the next construction site -> walk there -> build -> walk home.
## The logic lives in BuildJob (shared with the hero).

const State = BuildJob.State

var job := BuildJob.new()
var state: int:
	get: return job.state
var site: Building:
	get: return job.site


func setup(p_game: Game, p_role: String) -> void:
	super.setup(p_game, p_role)
	job.bind(self)


func _tick(delta: float) -> void:
	job.tick(delta)


func status() -> String:
	return job.status()


func _on_evade() -> void:
	job.on_evade()


func _release_jobs() -> void:
	job.release()
