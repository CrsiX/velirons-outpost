class_name HeroExploreJob
extends ExploreJob
## The hero's Explore mode (docs/world-design.md §9.1): before exploring
## unknown land he goes for known things only a hero can do, the nearest of
## the highest priority first, anywhere on the map:
##   1. claims: awakened unit-unlock sites and ruined watchtowers,
##   2. looting unguarded treasures (first come, first served),
##   3. exploring, as the explorer does.
## Loot is carried home and paid there; downed on the way, he drops it.

enum Task { NONE, TO_OBJECT, WORKING, CARRYING }

var task := Task.NONE
var obj: MapObject = null
var work_left := 0.0
## What he carries home (a treasure's reward) and where it came from.
var carrying: Dictionary = {}
var carrying_from := ""
var _look := 0.0


func tick(delta: float) -> void:
	match task:
		Task.CARRYING:
			if w.step_path(delta):
				w.arrive_home()
				_pay()
		Task.TO_OBJECT:
			if not _still_wanted():
				_drop_task()
				return
			if w.step_path(delta):
				task = Task.WORKING
				work_left = _duration()
				w.sprite.rotation = 0.0
		Task.WORKING:
			if not _still_wanted():
				_drop_task()
				return
			work_left -= delta
			w.sprite.rotation = sin(Time.get_ticks_msec() / 90.0) * 0.08  # (digging, looking around)
			if work_left <= 0.0:
				w.sprite.rotation = 0.0
				_finish()
		Task.NONE:
			_look -= delta
			if _look <= 0.0:
				_look = 0.5
				if _pick_task():
					return
			super.tick(delta)


## The best thing to do, by priority, then distance. Starts walking there.
func _pick_task() -> bool:
	var v := w.village
	var best: MapObject = null
	var best_key := Vector2(INF, INF)
	for o in w.game.world.map_objects:
		var prio := -1
		if o is UnlockSite and (o as UnlockSite).claimable():
			prio = 0
		elif o is RuinedTower and (o as RuinedTower).claimable():
			prio = 0
		elif o is Treasure and (o as Treasure).lootable():
			prio = 1
		if prio < 0 or not o.is_found_by(v):
			continue
		var key := Vector2(prio, Vector2(o.tile).distance_to(w.grid_pos))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			var p := w.game.world.pathing.find_path(w.current_tile(), o.visit_tile())
			if p.is_empty():
				continue
			best_key = key
			best = o
	if best == null:
		return false
	if not w.head_out(best.visit_tile()):
		return false
	obj = best
	obj.set("claimed_by", w)
	task = Task.TO_OBJECT
	target = Vector2i(-1, -1)  # (not exploring meanwhile)
	state = State.RESTING
	w.village.events.debug("the hero heads for %s" % obj.label())
	return true


func _still_wanted() -> bool:
	if not is_instance_valid(obj):
		return false
	if obj is Treasure:
		return not (obj as Treasure).looted and (obj as Treasure).guard() == null
	if obj is UnlockSite:
		return not (obj as UnlockSite).used and not w.game.is_unlocked((obj as UnlockSite).unlocks())
	if obj is RuinedTower:
		return obj.village == null
	return false


func _duration() -> float:
	if obj is Treasure:
		return (obj as Treasure).loot_time()
	if obj is UnlockSite:
		return float((obj as UnlockSite).spec()["visit_time"])
	return Config.RUIN_CLAIM_TIME


func _finish() -> void:
	var v := w.village
	var o := obj
	obj = null
	task = Task.NONE
	if o is UnlockSite:
		var site := o as UnlockSite
		w.on_action("explore")
		w.game.unlock(site.unlocks(), v, w)
		w.float_text("%s unlocked!" % Config.MILITARY[site.unlocks()]["name"], UiTheme.GOLD)
		_look = 0.0
	elif o is RuinedTower:
		(o as RuinedTower).claim(v)
		w.on_action("explore")
		v.events.info("The hero claimed a ruined watchtower. Tap it to restore it (half the cost).")
		w.float_text("Claimed!", v.color)
		_look = 0.0
	elif o is Treasure:
		var tr := o as Treasure
		carrying = tr.reward().duplicate()
		carrying_from = tr.display_name().to_lower()
		tr.mark_looted()
		w.on_action("gather")
		v.events.info("The hero looted %s (%s) and carries it home." % [_a(carrying_from), Treasure.reward_text(carrying)])
		for other in w.game.villages:
			if other != v:
				other.events.info("%s's hero looted %s." % [v.village_name, _a(carrying_from)])
		task = Task.CARRYING
		w.head_home()


static func _a(name: String) -> String:
	return ("an " if name.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a ") + name if not name.begins_with("dropped") else "some " + name


## Home with the loot: the village gets it.
func _pay() -> void:
	task = Task.NONE
	var v := w.village
	var r := carrying
	carrying = {}
	var parts: Array[String] = []
	for k in r:
		match k:
			"gold", "food", "materials":
				v.economy.add(k, int(r[k]))
				parts.append("+%d %s" % [int(r[k]), k])
			"hero_xp":
				(w as Hero).xp += int(r[k])
				parts.append("+%d XP" % int(r[k]))
			"heal_units":
				for u in v.army.units:
					u.heal(u.max_hp())
				parts.append("units healed")
			"relic":
				var key: String = r[k]
				if not v.relics.has(key):
					v.relics.append(key)
				var spec: Dictionary = Config.RELICS[key]
				v.events.important("Found the %s: %s!" % [spec["name"], spec["desc"]])
				parts.append(spec["name"])
	if not parts.is_empty():
		w.float_text(", ".join(parts), UiTheme.GOLD)
		Sfx.play("coin")
	(w as Hero).changed.emit()


## Downed (or the mode changed) while carrying: the loot stays where he is.
func drop_loot() -> void:
	if task == Task.CARRYING and not carrying.is_empty():
		w.game.world.add_dropped_loot(w.current_tile(), carrying)
		w.village.events.info("The hero dropped the loot from %s. Anyone can pick it up." % _a(carrying_from))
	carrying = {}
	_drop_task()


func _drop_task() -> void:
	if is_instance_valid(obj) and obj.get("claimed_by") == w:
		obj.set("claimed_by", null)
	obj = null
	if task != Task.CARRYING:
		task = Task.NONE


func on_evade() -> void:
	if task == Task.CARRYING:
		return  # (running home is where he was going anyway)
	_drop_task()
	super.on_evade()


func after_evade() -> void:
	if task == Task.CARRYING:
		_pay()


func release() -> void:
	drop_loot()
	super.release()


func status() -> String:
	match task:
		Task.TO_OBJECT:
			return "heading for %s" % obj.display_name().to_lower() if is_instance_valid(obj) else "on the move"
		Task.WORKING:
			if obj is Treasure:
				return "looting %s" % obj.display_name().to_lower()
			return "claiming %s" % obj.display_name().to_lower() if is_instance_valid(obj) else "busy"
		Task.CARRYING:
			return "carrying loot home"
	return super.status()
