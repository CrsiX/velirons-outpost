class_name Poison
extends Node2D
## A poison dose on a unit (docs/enemies-design.md §4a; numbers: Config.POISON,
## overridden by the poisoner's own "poison" entry): a tick at once, then one
## every `interval` s, each `decay` x the one before, until a tick would be
## below `cutoff`. Every tick is a poison hit on the unit it sits on (its
## resists apply). It is that unit's child, so it goes with it; green bubbles
## show it. On a co-op client it is only the look (`look_only`), set from the
## replicated state.

## The next tick's damage.
var dose := 0.0
var decay := 0.7
var interval := 1.0
var cutoff := 0.5
## Seconds to the next tick.
var left := 0.0
## Who gave it (for the log and the kill), while it lives.
var source: Node = null
var look_only := false
var _t := 0.0


## The dose numbers for a poisoner (an Enemy kind's "poison" entry, else the defaults).
static func params(spec: Dictionary) -> Dictionary:
	var p: Dictionary = Config.POISON.duplicate()
	p.merge(spec.get("poison", {}), true)
	return p


## All a dose deals from a tick of `first` on.
static func total(first: float, p_decay: float, p_cutoff: float) -> float:
	var sum := 0.0
	var d := first
	for i in 200:  # (bounded: a decay of 1 or more would never end)
		if d < p_cutoff or d <= 0.0:
			break
		sum += d
		d *= p_decay
	return sum


## The dose on `u`, or null.
static func of(u: Node) -> Poison:
	if not is_instance_valid(u):
		return null
	for c in u.get_children():
		if c is Poison and not c.is_queued_for_deletion():
			return c
	return null


## Can `u` take poison at all? (The undead, the raised and the unnatural can't.)
static func can_poison(u: Node) -> bool:
	if not is_instance_valid(u) or u.get("dead"):
		return false
	if u is Enemy:
		return (u as Enemy).hurt_by("poison")
	return u is Civilian or u is Soldier or u is EarthElemental


## `source` poisons `u` with a first tick of `first`: a new dose, or one that
## replaces the running dose if it deals more in total than that one has left.
static func give(u: Node, first: float, source: Node) -> void:
	if first <= 0.0 or not can_poison(u):
		return
	var p := params(source.spec() if source is Enemy else {})
	var cur := of(u)
	if cur != null and not cur.look_only and total(cur.dose, cur.decay, cur.cutoff) >= total(first, float(p["decay"]), float(p["cutoff"])):
		return
	if cur == null:
		cur = Poison.new()
		u.add_child(cur)
	cur.look_only = false
	cur.dose = first
	cur.decay = float(p["decay"])
	cur.interval = float(p["interval"])
	cur.cutoff = float(p["cutoff"])
	cur.source = source
	cur._tick()


## A co-op client's look: bubbles on `u` while its host says it is poisoned.
static func show_on(u: Node, on: bool) -> void:
	var cur := of(u)
	if on and cur == null:
		cur = Poison.new()
		cur.look_only = true
		u.add_child(cur)
	elif not on and cur != null:
		cur.queue_free()


## For a save: the dose on `u` ({} for none).
static func capture(u: Node) -> Dictionary:
	var cur := of(u)
	if cur == null or cur.look_only:
		return {}
	return {"d": cur.dose, "dc": cur.decay, "iv": cur.interval, "co": cur.cutoff, "l": cur.left}


## From a save: puts the dose `d` (from capture) back on `u`, without a tick.
static func restore(u: Node, d: Dictionary) -> void:
	if d.is_empty() or not can_poison(u):
		return
	var cur := Poison.new()
	cur.dose = float(d["d"])
	cur.decay = float(d["dc"])
	cur.interval = float(d["iv"])
	cur.cutoff = float(d["co"])
	cur.left = float(d["l"])
	u.add_child(cur)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if look_only:
		return
	left -= delta
	if left <= 0.0:
		_tick()


## One tick: a poison hit on the unit, then the next one is weaker.
func _tick() -> void:
	var u := get_parent()
	if not is_instance_valid(u) or u.get("dead") or dose < cutoff:
		queue_free()
		return
	var hit := dose
	dose *= decay
	left = interval
	if dose < cutoff:
		queue_free()
	u.take_damage(hit, source if is_instance_valid(source) else null, "poison")


## Green bubbles rising over the unit.
func _draw() -> void:
	for i in 3:
		var k := fmod(_t * 0.9 + i / 3.0, 1.0)
		var at := Vector2(sin(_t * 3.0 + i * 2.1) * 5.0, -22.0 - k * 22.0)
		draw_circle(at, 2.6 - k, Color(0.45, 0.95, 0.3, 0.9 * (1.0 - k)))
