extends "res://tests/bot_base.gd"
## Headless test of the title screen's background game (TitleBackdrop,
## Config.TITLE_BACKDROP): black first, then every scene with its posts
## manned, its enemies coming, slow motion, no sound, no input, no raids, no
## defeat; the next scene after the last one's time; all undone on leaving.
## Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/title_bot.tscn
## Exits 0 when every check passes.

var title: TitleScreen
var bd: TitleBackdrop
const CFG := Config.TITLE_BACKDROP


func _run() -> void:
	var diff := Settings.difficulty
	title = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	bd = title.backdrop
	check(bd != null and bd.modulate == Color.BLACK and bd.game == null, "the title screen starts on black, the game not made yet")
	check(title.singleplayer_button.is_visible_in_tree(), "the menu is there at once")
	check(await wait_until(func() -> bool: return bd.game != null, 30.0), "then the first scene's game is made")
	check(bd.index == 0, "the first scene first (as listed)")
	await frames(2)
	check(bd.modulate.v > 0.0 and bd.modulate.v < 1.0 - float(CFG["shade"]) + 0.01, "and it fades in")
	await wait(float(CFG["fade_in"]) * float(CFG["speed"]) + 0.5)
	check(is_equal_approx(bd.modulate.v, 1.0 - float(CFG["shade"])), "up to the shade (%.2f)" % bd.modulate.v)
	check(is_equal_approx(Engine.time_scale, float(CFG["speed"])), "slow motion: speed %.2f" % Engine.time_scale)
	check(Sfx.muted, "no sound")
	_input_check()
	for i in (CFG["scenes"] as Array).size():
		if i > 0:
			bd.play(i)
		await _scene(i)
	check(Settings.difficulty == diff and not Settings.tutorial_next, "the settings are untouched")
	# Its time over, the next scene (the first again after the last).
	var started := []
	bd.scene_started.connect(func(n: int) -> void: started.append(n))
	var real := float(bd.value("duration")) + 2.0
	await wait(real * float(CFG["speed"]))
	check(started == [0], "after its time the next scene plays (the first after the last): %s" % [started])
	title.queue_free()
	await frames(2)
	check(Engine.time_scale == 1.0 and not Sfx.muted, "leaving the title screen: normal speed and sound again")
	print("CHECKS %d  FAILURES %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _input_check() -> void:
	var g := bd.game
	var cam := g.camera.position
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_WHEEL_UP
	mb.pressed = true
	mb.position = Vector2(600, 400)
	Input.parse_input_event(mb)
	await frames(3)
	check(not get_tree().paused and g.speed_index == 0, "keys don't reach the game (Space doesn't pause it)")
	check(is_equal_approx(g.camera.zoom.x, float(bd.value("camera").get("zoom", 1.0))), "the wheel doesn't zoom it")
	check(cam != Vector2.ZERO and not g.hud.visible, "no HUD")


func _scene(i: int) -> void:
	var sc: Dictionary = CFG["scenes"][i]
	var name := str(sc["name"])
	print("-- scene %d: %s" % [i, name])
	check(await wait_until(func() -> bool: return bd.game != null and bd.index == i and bd.game.is_inside_tree(), 30.0), "%s: its game plays" % name)
	var g := bd.game
	check(g.backdrop == bd and not g.tutorial_mode and g.disable_fog, "%s: a backdrop game without fog" % name)
	check(g.map_seed == int(bd.value("seed")) and g.map.map_type == str(bd.value("map_type")), "%s: on its map (%s, seed %d)" % [name, g.map.map_type, g.map_seed])
	check(not bd.route.is_empty(), "%s: its road (to %s)" % [name, str(bd.route.back()) if not bd.route.is_empty() else "-"])
	check(g.hero.mode_name().to_lower() == str(bd.value("hero")), "%s: the hero %s" % [name, g.hero.mode_name()])
	var used: Array = []
	for p: Dictionary in sc.get("posts", []):
		var b := _post(g, p, used)
		check(b != null, "%s: a %s stands there%s" % [name, p["kind"], " (a site)" if p.get("site", false) else ""])
		if b == null:
			continue
		used.append(b)
		if p.get("site", false):
			check(not b.complete and g.construction.queue.has(b), "%s: the %s is a site to build" % [name, p["kind"]])
			continue
		if p.has("level"):
			check(b.level == int(p["level"]), "%s: the %s at level %d" % [name, p["kind"], b.level])
		var units: Array = p.get("units", [])
		for k in units.size():
			var u: MilitaryUnit = (b as MilitaryPost).slots[k]
			check(u != null and u.kind == units[k]["kind"] and u.level == int(units[k]["level"]) - 1 and u.state == MilitaryUnit.State.STATIONED,
				"%s: %s level %d on it" % [name, units[k]["kind"], units[k]["level"]])
	var kinds := {}
	for grp: Dictionary in sc.get("enemies", []):
		for k: String in grp["kinds"]:
			kinds[k] = true
	var huts := g.player_village.intact_huts().size()
	var seen := {}
	var t := 0.0
	while t < 10.0:  # (game seconds; the scene lasts duration x speed)
		await get_tree().process_frame
		t += get_process_delta_time()
		for e in get_tree().get_nodes_in_group("enemies"):
			if not ((e as Enemy).behavior is CampBehavior):  # (monster camps' guards stay home)
				seen[(e as Enemy).kind] = true
	for k in kinds:
		check(seen.has(k), "%s: %ss come down the road" % [name, k])
	if kinds.is_empty():
		check(seen.is_empty(), "%s: no enemies" % name)
	check(is_instance_valid(g) and bd.game == g, "%s: still playing" % name)
	if not is_instance_valid(g):
		return
	check(not g.game_over and g.player_village.intact_huts().size() == huts, "%s: no raids, no defeat" % name)


## The building the scene's post `p` made (not one counted already).
func _post(g: Game, p: Dictionary, used: Array) -> Building:
	if p["kind"] == "wall_tower":
		for b in g.player_village.buildings():
			if b is Tower and g.map.in_village(b.tile) and (b as Tower).garrison != null:
				return b
		return null
	for b in g.player_village.buildings():
		if b.kind == p["kind"] and not used.has(b) and not g.map.in_village(b.tile) and (b is MilitaryPost or p.has("at")):
			var at: Array = p.get("at", [0, 99])
			for d in range(int(at[0]), int(at[1]) + 1):
				for f in Building.footprint(b.tile, Config.BUILDINGS[b.kind]["size"]):
					for n in MapData.neighbors4(f):
						if n == bd.road_tile(d):
							return b
	return null
