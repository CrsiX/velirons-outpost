class_name BuildJob
extends CivilianJob
## Rest -> claim the next construction site -> walk there -> build -> walk home.
## `efficiency` scales the work speed (the hero builds more slowly).

enum State { RESTING, TO_SITE, BUILDING, RETURNING }

var state := State.RESTING
var site: Building = null
var efficiency := 1.0
var _work_acc := 0.0


func _init(p_efficiency: float = 1.0) -> void:
	efficiency = p_efficiency


func tick(delta: float) -> void:
	match state:
		State.RESTING:
			w.rest_timer -= delta
			if w.rest_timer > 0.0:
				return
			w.rest_timer = 1.0  # re-check for work once a second
			var s := w.village.construction.claim(w)
			if s == null:
				return
			if w.head_out(s.work_tile()):
				site = s
				state = State.TO_SITE
			else:
				w.village.construction.release(s, true)
		State.TO_SITE:
			if not _site_valid():
				_go_home()
				return
			if w.step_path(delta):
				state = State.BUILDING
				w._set_moving(false)
		State.BUILDING:
			if not _site_valid():
				_go_home()
				return
			w._bob += delta * 14.0
			w.sprite.rotation = sin(w._bob) * 0.15
			_work_acc += delta
			if _work_acc >= 1.0:
				_work_acc -= 1.0
				w.on_action("build_second")
			if site.add_progress(delta * efficiency):
				w.village.construction.complete(site)
				site = null
				_go_home()
		State.RETURNING:
			if w.step_path(delta):
				w.arrive_home()
				state = State.RESTING
				w.rest_timer = Config.BUILDER_REST


func _site_valid() -> bool:
	return is_instance_valid(site) and site.has_work() and site.builder == w


func _go_home() -> void:
	site = null
	state = State.RETURNING
	w.sprite.rotation = 0.0
	w.head_home()


func status() -> String:
	match state:
		State.TO_SITE: return "walking to a site"
		State.BUILDING: return "building"
		State.RETURNING: return "returning"
	return "resting"


func on_evade() -> void:
	# The site keeps its progress; any builder can pick it up again later.
	release()
	state = State.RESTING


func release() -> void:
	if is_instance_valid(site) and site.builder == w:
		w.village.construction.release(site, false)
	site = null
	w.sprite.rotation = 0.0
