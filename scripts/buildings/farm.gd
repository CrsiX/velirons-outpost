class_name Farm
extends Workplace
## 3x3 field outside the walls. Grows food while a farmer is assigned; the
## farmer carries the stored food home.

var farmer: Node:
	get: return worker
	set(v): worker = v
var stored := 0.0
## Rats eating the crops right now (enemy -> true): the farm grows nothing.
var rats: Dictionary = {}
## Seconds since the stock last grew (rats give up on empty, barren farms).
var since_gain := 0.0
var _ground_bonus := -1.0  # (computed once: the ground doesn't change)
var _field: Sprite2D
var _shed: Sprite2D
var _site_sprite: Sprite2D


func _build_visuals() -> void:
	# The field is flat, so it lives on the decal layer (under units);
	# the shed on the back tile is a normal y-sorted sprite.
	_field = Sprite2D.new()
	_field.position = position
	game.world.decals.add_child(_field)
	_shed = Art.sprite("farm_shed")
	_shed.show_behind_parent = true
	_shed.position = Iso.to_world(Vector2(-1, -1))
	add_child(_shed)
	_site_sprite = Art.sprite("site")
	_site_sprite.show_behind_parent = true
	add_child(_site_sprite)
	# Sort by the back tile so units on the field are drawn in front of the shed.
	position = Iso.tile_to_world(tile + Vector2i(-1, -1))
	_shed.position = Vector2.ZERO
	_site_sprite.position = Iso.to_world(Vector2(1, 1))


func refresh() -> void:
	Art.apply(_field, "farm_field" if complete else "farm_site")
	_shed.visible = complete
	_site_sprite.visible = not complete
	_field.modulate = Color.WHITE if (farmer != null or not complete) else Color(0.7, 0.7, 0.7)
	if tearing_down:
		_field.modulate.a = 0.6
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(_field):
		_field.queue_free()


func _process(delta: float) -> void:
	if game.is_client:
		return
	var before := stored
	if working() and farmer != null and not has_rats():
		stored = minf(stored + rate() * delta, Config.FARM_CAPACITY)
	since_gain = 0.0 if stored > before else since_gain + delta


## Nothing stored and nothing grown for `seconds`: nothing left for rats.
func barren(seconds: float) -> bool:
	return stored <= 0.001 and since_gain >= seconds


func add_rat(rat: Node) -> void:
	rats[rat] = true


func remove_rat(rat: Node) -> void:
	rats.erase(rat)


## Any rat (still alive) on the field?
func has_rats() -> bool:
	for r in rats.keys():
		if not is_instance_valid(r) or r.dead:
			rats.erase(r)
	return not rats.is_empty()


## Food per second while worked: FARM_RATE, +20 % on meadow (most of its
## tiles), +10 % next to water, + a relic's bonus.
func rate() -> float:
	if _ground_bonus < 0.0:
		var meadow := 0
		var wet := false
		for t in tiles():
			if game.map.zone(t) == "meadow":
				meadow += 1
			for nb in MapData.neighbors4(t):
				wet = wet or game.map.is_water(nb)
		_ground_bonus = (float(Config.ZONES["meadow"].get("farm_bonus", 0.0)) if meadow * 2 > tiles().size() else 0.0) + (Config.FARM_WATER_BONUS if wet else 0.0)
	return Config.FARM_RATE * (1.0 + _ground_bonus + (village.relic_bonus("food") if village else 0.0))


func take_food() -> int:
	var amount := int(stored)
	stored -= amount
	return amount


func info() -> Dictionary:
	var d := super.info()
	if not working():
		return d
	var lines: Array[String] = d["lines"]
	var actions: Array[Dictionary] = d["actions"]
	lines.append("Stored food: %d / %d" % [int(stored), int(Config.FARM_CAPACITY)])
	if has_rats():
		lines.append("%d rat%s eating the crops: nothing grows!" % [rats.size(), "" if rats.size() == 1 else "s"])
	if farmer:
		lines.append("Worked by a farmer (+%.2f food/s)" % rate())
		if rate() > Config.FARM_RATE + 0.001:
			lines.append("Good ground: +%d %% food" % roundi((rate() / Config.FARM_RATE - 1.0) * 100.0))
		actions.append({"label": "Unassign farmer", "action": func() -> void: game.command("unassign_worker", {"building": nid})})
	else:
		lines.append("Idle: assign a farmer to grow food.")
		var free := village.population.free_farmers()
		actions.append({
			"label": "Assign farmer" if not free.is_empty() else "No free farmer",
			"disabled": free.is_empty(),
			"action": func() -> void: game.command("assign_worker", {"building": nid}),
		})
	return d


## Bottom progress bar sits over the field centre, not the back-tile origin.
func _draw() -> void:
	if not has_work():
		return
	var c := Iso.to_world(Vector2(1, 1))
	var w := 80.0
	var r := Rect2(c + Vector2(-w / 2.0, -70.0), Vector2(w, 8.0))
	draw_rect(r.grow(2.0), Color("15110d"))
	draw_rect(r, Color("3a2e22"))
	draw_rect(Rect2(r.position, Vector2(w * bar_fraction(), r.size.y)), work_color())


func pick_rect() -> Rect2:
	var c := Iso.to_world(Vector2(1, 1))
	return Rect2(c - Vector2(180, 90), Vector2(360, 180))
