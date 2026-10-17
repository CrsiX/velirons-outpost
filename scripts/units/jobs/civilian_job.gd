class_name CivilianJob
extends RefCounted
## A villager's job as a small state machine, driven by its worker (a Civilian).
## Jobs are shared: the builder, explorer and gatherer each run one, and the
## hero runs the same jobs (a bit less efficiently) depending on its mode.

var w: Civilian


func bind(worker: Civilian) -> void:
	w = worker


## Advance the job; called from the worker's _tick.
func tick(_delta: float) -> void:
	pass


## The worker is about to run home from an enemy.
func on_evade() -> void:
	pass


## The worker got home safely after evading.
func after_evade() -> void:
	pass


## A loaded game (docs/save-design.md): the worker stands out in the field
## with its job's state as it was saved (what it carries, its claims) and
## asks once what to do from here.
func resume() -> void:
	pass


## Drop any claims (the worker died or switched jobs).
func release() -> void:
	pass


func status() -> String:
	return "resting"


## Unexplored tile this job is heading for (explorers avoid each other's).
func exploring_target() -> Vector2i:
	return Vector2i(-1, -1)
