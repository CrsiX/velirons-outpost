class_name Builder
extends Civilian
## Rest -> claim the next construction site -> walk there -> build -> walk home.

enum State { RESTING, TO_SITE, BUILDING, RETURNING }

var state := State.RESTING
var site: Building = null


func _tick(delta: float) -> void:
	match state:
		State.RESTING:
			rest_timer -= delta
			if rest_timer > 0.0:
				return
			rest_timer = 1.0  # re-check for work once a second
			var s := game.construction.claim(self)
			if s == null:
				return
			if head_out(s.work_tile()):
				site = s
				state = State.TO_SITE
			else:
				game.construction.release(s, true)
		State.TO_SITE:
			if not _site_valid():
				_go_home()
				return
			if step_path(delta):
				state = State.BUILDING
				_set_moving(false)
		State.BUILDING:
			if not _site_valid():
				_go_home()
				return
			_animate_work(delta)
			if site.add_progress(delta):
				game.construction.complete(site)
				site = null
				_go_home()
		State.RETURNING:
			if step_path(delta):
				arrive_home()
				state = State.RESTING
				rest_timer = Config.BUILDER_REST


func _site_valid() -> bool:
	return is_instance_valid(site) and not site.complete and site.builder == self


func _go_home() -> void:
	site = null
	state = State.RETURNING
	sprite.rotation = 0.0
	head_home()


func _animate_work(delta: float) -> void:
	_bob += delta * 14.0
	sprite.rotation = sin(_bob) * 0.15


func status() -> String:
	match state:
		State.TO_SITE: return "walking to a site"
		State.BUILDING: return "building"
		State.RETURNING: return "returning"
	return "resting"


func _release_jobs() -> void:
	if is_instance_valid(site) and site.builder == self:
		game.construction.release(site, false)
	site = null
