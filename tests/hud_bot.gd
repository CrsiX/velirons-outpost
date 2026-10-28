extends "res://tests/bot_base.gd"
## Headless test of the HUD: costs, XP and HP shown with their icons, the
## Army tab, the hero's health bar, the villager list (View, Retire, Rebuild
## all huts), picking on the map (pixels, tapping through, see-through),
## floating icons, Space, the "no builder" and food-shortage
## warnings, every hotkey (docs/ui-design.md §10-11; F1 lists them) and the
## tactical map (M, §12).
## Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/hud_bot.tscn
## Exits 0 when every check passes.

const SEED := 777


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.map_seed = SEED
	game.disable_fog = true
	add_child(game)
	for k in Config.LOCKED:
		game.unlocks[k] = true
	await frames(3)
	game.waves.countdown = 99999.0
	game.waves.hold = true
	Engine.time_scale = 6.0
	_bench_hero(true)
	await _test_ui()
	await _test_picking()
	_test_hero_bar()
	await _test_hotkeys()  # (while the village is whole: the next ones kill and retire villagers)
	await _test_new_keys()
	await _test_map()
	await _test_people()
	await _test_hud_extras()
	Engine.time_scale = 1.0
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# --- icons and the Army tab ---------------------------------------------------------------------

func _test_ui() -> void:
	var hud := game.hud
	hud._refresh()
	var place: Button = hud._build_buttons["tower"]
	var rich: RichTextLabel = place.get_node_or_null("Rich")
	check(rich != null and "icon_materials.svg" in rich.text and Hud.button_text(place).contains("materials"), "costs show their icon (%s)" % Hud.button_text(place))
	check(place.text == "" and place.get_combined_minimum_size().x >= 100.0, "under the icons the button has no text of its own, and still its size (%.0f px)" % place.get_combined_minimum_size().x)
	var recruit: Button = hud._military_buttons["archer"]
	check(recruit.get_node_or_null("Rich") != null and "icon_gold.svg" in (recruit.get_node("Rich") as RichTextLabel).text, "gold costs show the gold icon")
	hud._refresh_hero()
	check(hud._hero_button.get_node_or_null("Rich") != null and "icon_xp.svg" in (hud._hero_button.get_node("Rich") as RichTextLabel).text and Hud.button_text(hud._hero_button).begins_with("XP "), "the hero's XP shows the XP icon")
	hud._hero_panel.visible = true
	hud._refresh_hero()
	check("icon_hp.svg" in hud._hero_stats.text and not "HP" in hud._hero_stats.text, "the hero panel shows her HP with a heart")
	hud._hero_panel.visible = false
	var hurt := game.army.recruit("archer")
	hurt.hp = hurt.max_hp() * 0.5
	hud._reserve_signature = ""
	hud._rebuild_reserve()
	var cards := hud._reserve_grid.get_children().filter(func(c: Node) -> bool: return c.get_node_or_null("Rich") != null)
	check(not cards.is_empty() and "icon_hp.svg" in (cards[0].get_node("Rich") as RichTextLabel).text and Hud.button_text(cards[0]).ends_with("HP"), "a hurt unit's card shows a heart and its HP")
	var page: Control = hud._reserve_grid.get_parent()
	var grid_i := -1
	for c in page.get_children():
		if c is GridContainer and c != hud._reserve_grid:
			grid_i = c.get_index()
	check(hud._reserve_grid.get_index() < grid_i, "the Army tab shows the units in stock above the recruiting")
	check(ResourceLoader.exists("res://art/icon_xp.svg") and ResourceLoader.exists("res://art/unit_rat.svg"), "the XP icon and the rat have their art")


# --- picking on the map (Config.PICK) -------------------------------------------------------

## A real tap (press and release) at `world_pos`, with the view centred there.
func _tap_at(world_pos: Vector2) -> void:
	game.camera.position = world_pos
	await frames(2)
	var pos := game.camera.world_to_screen(world_pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)
		await frames(1)
	await frames(1)


func _test_picking() -> void:
	var w := game.world
	game.deselect()
	# Pixels, not boxes: a point in a hut's picture rect that its art leaves
	# empty (and off its footprint) doesn't pick it.
	var hut: Building = game.player_village.buildings().filter(func(b: Building) -> bool: return b is Hut)[0]
	var r := hut.art_rect()
	var empty := Vector2.INF
	for p in [r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2)]:
		if not hut.covers(p) and w.map.building_at(Iso.to_tile(p)) != hut:
			empty = p
	check(empty != Vector2.INF and hut not in w.pick_all(empty) and hut in w.pick_all(r.get_center()), "a tap picks a building by the pixels of its art, not by a box round it")
	# A building hidden in part by one in front: taps go through, front to back, then deselect.
	var back: Building = null
	var front: Building = null
	for b in w.buildings:
		var occ: Array[int] = w._occluders(b)
		if not occ.is_empty():
			back = b
			front = instance_from_id(occ[0]) as Building
			break
	check(back != null, "the village has a building partly hidden behind another one")
	if back == null:
		return
	var spot := Vector2.INF
	var ar := back.art_rect()
	for i in 400:
		var p := ar.position + Vector2(fmod(i * 7.3, ar.size.x), fmod(i * 13.7, ar.size.y))
		if back.covers(p) and front.covers(p):
			spot = p
			break
	var stack := w.pick_all(spot)
	check(stack.size() >= 2 and stack[0] == front and back in stack, "both are under a spot where one hides the other, the front one first (%s)" % [stack])
	await _tap_at(spot)
	check(game.selected == front and game.hud._info_panel.visible, "the first tap selects the front one")
	var line := game._stack_line(front)
	check(line.begins_with("1 of %d here" % stack.size()), "its panel says more is behind it (%s)" % line)
	check(not front.see_through and is_equal_approx(front.modulate.a, 1.0), "nothing is see-through while the front one is selected")
	var seen: Array = [front]
	for i in stack.size() - 1:
		await _tap_at(spot)
		var cur: Object = game.selected_unit if game.selected_unit != null else game.selected
		seen.append(cur)
	check(seen == stack, "taps on the same spot go through to what is behind, one by one (%s)" % [seen])
	game.select(back)
	await frames(1)
	check(front.see_through and front.modulate.a < 0.5, "with the one behind selected, the one in front is see-through")
	check(w.pick_all(spot)[-1] == front, "what is see-through is picked last")
	game.deselect()
	check(not front.see_through and is_equal_approx(front.modulate.a, 1.0), "deselected, it is solid again")
	for i in stack.size() + 1:
		await _tap_at(spot)
	check(game.selected == null and game.selected_unit == null and not game.hud._info_panel.visible, "a tap after the last one deselects (what turned see-through on the way keeps its place)")
	# A unit's figure on a tower comes before its tower.
	var tower: Tower = game.player_village.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower" and (b as Tower).free_slot() >= 0)[0]
	var a := game.army.recruit("archer")
	game.army.station(a, tower)
	game.army._on_arrived(a.walker)
	await frames(2)
	var fig := tower.position + tower.unit_rect(a).get_center()
	var at_fig := w.pick_all(fig)
	check(at_fig[0] == a and at_fig[1] == tower, "a unit's figure is picked before its tower")
	await _tap_at(fig)
	check(game.selected_unit == a, "a tap on the figure selects the unit")
	await _tap_at(fig)
	check(game.selected == tower and game.selected_unit == null, "a second tap there selects its tower")
	game.deselect()
	game.army.unstation(a)


func _test_hero_bar() -> void:
	var hud := game.hud
	check(hud._hero_button.get_node_or_null("HealthBar") != null and hud._hero_hp_bar.size.y >= 6.0, "the hero button has a health bar along its bottom (%.0f px)" % hud._hero_hp_bar.size.y)
	check(hud.hero_hp_color(1.0) == hud.hero_hp_color(0.5) and hud.hero_hp_color(0.49) == hud.hero_hp_color(0.2) and hud.hero_hp_color(0.19) != hud.hero_hp_color(0.2) and hud.hero_hp_color(0.5) != hud.hero_hp_color(0.49), "green from 50 %, yellow from 20 %, red below")
	var h := game.hero
	h.hp = h.max_hp * 0.3
	check(is_equal_approx(hud.hero_hp_share(), 0.3), "it shows her share of HP")
	h.hp = h.max_hp


func _test_people() -> void:
	var hud := game.hud
	check(hud._pop_button.icon == Art.tex("icon_population") and hud._pop_button.text == "%d / %d" % [game.population.count(), game.population.cap()], "the people button shows civilians / huts (%s)" % hud._pop_button.text)
	hud._hero_panel.visible = true
	hud._pop_button.pressed.emit()
	var list := hud.people()
	check(hud._people_panel.visible and not hud._hero_panel.visible, "tapping it opens the villager list (and closes the hero panel)")
	check(hud._people_list.get_child_count() == list.size() and list.size() == game.population.count(), "one row per villager (%d)" % list.size())
	var c: Civilian = list[0]
	var status: RichTextLabel = hud._people_rows[c]
	check(status.get_meta("plain", "") == c.status_text(), "each row says what the villager does (%s: %s)" % [c.label(), c.status_text()])
	var orders := list.map(func(x: Civilian) -> int: return Config.CIVILIAN_ORDER.find(x.role))
	var sorted := orders.duplicate()
	sorted.sort()
	check(orders == sorted, "sorted by role")
	# Go to: the camera moves to the villager (outside) or the village centre (at home).
	var out: Civilian = null
	for x in list:
		if not x.at_home:
			out = x
	if out == null:
		out = list[-1]
		out.at_home = false
		out.visible = true
		out.set_grid_pos(Vector2(game.player_village.center + Vector2i(5, 5)))
	var row: Control = (hud._people_rows[out] as Control).get_parent().get_parent()
	var go: Button = row.get_node("View")
	go.pressed.emit()
	check(Hud.button_text(go) == "View" and game.camera.position.distance_to(out.position) < 2.0, "Go to moves the view to %s" % out.label())
	var home: Civilian = null
	for x in list:
		if x.at_home:
			home = x
	if home:
		hud.go_to_person(home)
		check(game.camera.position.distance_to(Iso.tile_to_world(game.player_village.center)) < 2.0, "for one at home: the village centre")
	# A new villager shows up in the list.
	var n := list.size()
	game.economy.add("food", 100)
	if game.population.free_huts().is_empty():
		game.population.kill(list[-1])
	game.population.recruit("builder")
	hud._refresh_people()
	check(hud._people_list.get_child_count() == hud.people().size(), "the list follows new villagers (%d -> %d)" % [n, hud.people().size()])
	await _test_retire()
	# Destroyed huts: "Rebuild all huts" at the top queues them all.
	check(not hud._rebuild_huts_button.visible, "no destroyed hut: no rebuild button")
	var empty := game.player_village.intact_huts().filter(func(h: Building) -> bool: return not is_instance_valid((h as Hut).resident))
	for h in empty.slice(0, 3):
		(h as Hut).destroy("test")
	hud._refresh_people()
	var ruined := game.construction.ruined_huts().size()
	check(ruined == 3 and hud._rebuild_huts_button.visible and Hud.button_text(hud._rebuild_huts_button).begins_with("Rebuild all huts (3)") and hud._rebuild_huts_button.get_index() < hud._people_scroll.get_index(), "3 destroyed huts: \"%s\" at the top of the list" % Hud.button_text(hud._rebuild_huts_button))
	var per := int(Hut.rebuild_cost()["materials"])
	game.economy.add("materials", per * 2 - game.economy.amount("materials"))
	hud._rebuild_huts_button.pressed.emit()
	check(game.construction.ruined_huts().size() == 1 and game.construction.queue.filter(func(x: Building) -> bool: return x is Hut).size() == 2, "it queues as many as the material pays for (2 of 3)")
	game.economy.add("materials", per)
	hud._rebuild_huts_button.pressed.emit()
	hud._refresh_people()
	check(game.construction.ruined_huts().is_empty() and not hud._rebuild_huts_button.visible, "then the rest; the button goes away")
	hud.toggle_people(false)
	check(not hud._people_panel.visible, "and closes again")


## Retire, next to View: asks first, then the villager leaves and the hut is free.
func _test_retire() -> void:
	var hud := game.hud
	var c: Civilian = hud.people()[-1]
	var row: Control = (hud._people_rows[c] as Control).get_parent().get_parent()
	var retire := row.get_node_or_null("Retire") as Button
	check(retire != null and retire.get_index() == row.get_node("View").get_index() + 1, "a Retire button next to View")
	if retire == null:
		return
	await frames(2)
	var heights := {}
	for x in hud._people_rows:
		var rw: Control = (hud._people_rows[x] as Control).get_parent().get_parent()
		for nm in ["View", "Retire"]:
			var b: Control = rw.get_node(nm)
			heights[b.size.y] = true
			check(absf(b.get_global_rect().get_center().y - rw.get_global_rect().get_center().y) < 1.5, "%s's %s button is centred in its row" % [x.label(), nm])
	check(heights.size() == 1, "every View / Retire button has the same height %s" % str(heights.keys()))
	var hut := c.hut
	var n := game.population.count()
	var label := c.label()
	retire.pressed.emit()
	await frames(2)
	check(hud._confirm_panel.visible and c.label() in hud._confirm_title.text and game.population.count() == n, "Retire asks first (%s), nobody leaves yet" % hud._confirm_title.text)
	check(get_viewport().get_visible_rect().encloses(hud._confirm_panel.get_global_rect()), "the question fits on screen")
	for b in hud._confirm_panel.get_child(0).get_children():
		if b is Button and Hud.button_text(b) == "Cancel":
			b.pressed.emit()
	check(not hud._confirm_panel.visible and game.population.count() == n and not c.dead, "Cancel: they stay")
	retire.pressed.emit()
	hud._confirm_yes.pressed.emit()
	await frames(2)
	check(not hud._confirm_panel.visible and game.population.count() == n - 1 and game.population.civilians.all(func(x: Civilian) -> bool: return x.label() != label), "confirmed: %s leaves the village" % label)
	check(is_instance_valid(hut) and hut.resident == null and game.population.free_huts().has(hut), "and their hut is free again")
	check(game.player_village.events.entries.any(func(e: Dictionary) -> bool: return e["text"] == "%s retired and left the village" % label), "and it's logged")
	check(hud._people_list.get_child_count() == hud.people().size() and hud._people_rows.keys().all(func(x: Object) -> bool: return is_instance_valid(x)), "the list drops them")
	check(not game.player_village.fallen, "the village stands")
	# The last villager stays.
	var keep: Civilian = game.population.civilians[0]
	var roles: Array[String] = []
	for x in game.population.civilians.duplicate():
		if x != keep:
			roles.append(x.role)
			if roles.size() == 1:
				check(game.command("retire_villager", {"civilian": x.nid})["ok"], "the command retires %s" % x.label())
			else:
				game.population.retire(x)
	var r: Dictionary = game.command("retire_villager", {"civilian": keep.nid})
	check(not r["ok"] and game.population.count() == 1 and not game.player_village.fallen, "the last villager can't retire (%s)" % r.get("error", ""))
	check(not game.command("retire_villager", {"civilian": 0})["ok"], "nobody named: refused")
	game.economy.add("food", 500)
	for role in roles:
		game.population.recruit(role)
	hud._refresh_people()


func _test_hud_extras() -> void:
	var hud := game.hud
	game.world.float_text("+3 {gold}  +8 {food}", Vector2(100, 100), UiTheme.GOLD)
	var ft = game.world.effects.get_child(game.world.effects.get_child_count() - 1)
	check(ft is RichTextLabel and "icon_gold.svg" in ft.text and "icon_food.svg" in ft.text, "floating \"+3 gold +8 food\" texts show the icons")
	# Space: pause and back to the speed before; paused with the button, Space goes to 1x.
	var scale := Engine.time_scale
	var pause := Game.SPEEDS.find(0.0)
	hud.set_speed_index(Game.SPEEDS.find(2.0))
	hud.toggle_pause()
	var paused := hud._speed_index == pause
	hud.toggle_pause()
	check(paused and Game.SPEEDS[hud._speed_index] == 2.0, "Space pauses, and Space again goes back to 2x")
	hud.set_speed_index(Game.SPEEDS.find(4.0))
	hud.set_speed_index(pause)
	hud.toggle_pause()
	check(Game.SPEEDS[hud._speed_index] == 1.0, "paused with the speed button, Space goes to 1x")
	Engine.time_scale = scale
	# No builder, the hero not building, something queued: after 5 s a warning.
	for c in game.population.civilians.duplicate():
		if c.role == "builder":
			game.population.kill(c)
	game.hero.set_mode(Hero.Mode.REST)
	game.economy.add("materials", 100)
	var site := game.construction.place("tower", find_spot("tower", game.player_village.center + Vector2i(-6, 6)))
	hud._no_builder_for = 0.0
	hud._refresh_builder_warning(3.0)
	var early := hud._builder_warning.visible
	hud._refresh_builder_warning(2.5)
	check(site != null and not early and hud._builder_warning.visible, "no builder, the hero not building: after 5 s a warning says nothing will be built")
	game.hero.set_mode(Hero.Mode.BUILD)
	hud._refresh_builder_warning(0.25)
	check(not hud._builder_warning.visible, "the hero in Build mode: no warning")
	game.hero.set_mode(Hero.Mode.REST)
	game.construction.cancel(site)
	hud._refresh_builder_warning(0.25)
	check(not hud._builder_warning.visible, "nothing queued: no warning")
	await _food_warning_check()


## Food at 0: a countdown over the last STARVATION_WARNING s before a villager
## starves, with a tip by what is missing.
func _food_warning_check() -> void:
	var hud := game.hud
	var pop := game.population
	var farm := game.construction.place("farm", find_spot("farm", game.player_village.center + Vector2i(8, -8)))
	game.construction.complete(farm)
	await frames(2)
	for f in game.world.buildings.filter(func(b: Building) -> bool: return b is Farm and b.village == game.player_village and b != farm):
		game.construction.order_tear_down(f)  # only our farm works; its farmer is freed
	if pop.count("farmer") == 0:
		game.economy.add("food", 1000)
		pop.recruit("farmer")
	await frames(2)
	if farm.farmer != null:
		pop.unassign_farmer(farm)
	game.economy.set_amounts({"food": 0})
	await frames(2)
	pop.starve_timer = 0.0
	hud._refresh_food_warning()
	var early := hud._food_warning.visible
	pop.starve_timer = Config.STARVATION_INTERVAL - Config.STARVATION_WARNING + 0.5
	hud._refresh_food_warning()
	check(pop.starving and not early and hud._food_warning.visible and "Food shortage: a villager starves in 5." in hud._food_warning.text, "food at 0: no warning at first, then a countdown over the last 5 s (%s)" % hud._food_warning.text)
	pop.starve_timer = Config.STARVATION_INTERVAL - 0.2
	check("starves in 1." in hud.food_warning_text(), "the countdown ends at 1")
	pop.starve_timer = Config.STARVATION_INTERVAL - Config.STARVATION_WARNING + 0.5
	check("Assign a farmer" in hud._food_warning.text, "a free farm and a farmer without one: assign them (%s)" % hud._food_warning.text)
	pop.assign_farmer(farm)
	for c in pop.civilians.duplicate():
		if c.role == "farmer" and c != farm.farmer:
			pop.kill(c)
	var tip := hud.food_warning_text()
	check(tip.begins_with("Food shortage") and tip.ends_with("starves in 5."), "every farm worked: just the warning, no tip (%s)" % tip)
	pop.kill(farm.farmer)
	check("Recruit a farmer" in hud.food_warning_text(), "a farm but no farmer: recruit one")
	game.construction.order_tear_down(farm)
	check("Build a farm" in hud.food_warning_text(), "no farm: build one")
	game.economy.add("food", 10)
	await frames(2)
	hud._refresh_food_warning()
	check(not hud._food_warning.visible, "food in store: no warning (starving %s, timer %.1f, food %.1f, paused %s)" % [pop.starving, pop.starve_timer, game.economy.amount("food"), get_tree().paused])
	game.economy.set_amounts({"food": 500})


func _press(key: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = key
	e.pressed = true
	return e


## Tab / Shift+Tab through the posted units; U and R on a unit, U on a reserve
## card; Q, V, N and F1.
func _test_unit_keys() -> void:
	var hud := game.hud
	var v := game.player_village
	game.economy.add("gold", 500)
	var corners: Array = v.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower" and (b as Tower).free_slot() >= 0)
	var a1 := game.army.recruit("archer")
	var a2 := game.army.recruit("archer")
	for pair in [[a1, corners[0]], [a2, corners[1]]]:
		game.army.station(pair[0], pair[1])
		game.army._on_arrived((pair[0] as MilitaryUnit).walker)
	var order := hud.posted_units()
	hud._unhandled_key_input(_press(KEY_TAB))
	var first := game.selected_unit
	var cam_ok := game.camera.position.distance_to(hud.unit_position(first)) < 2.0
	hud._unhandled_key_input(_press(KEY_TAB))
	var second := game.selected_unit
	var back := _press(KEY_TAB)
	back.shift_pressed = true
	hud._unhandled_key_input(back)
	check(order.size() >= 2 and first == order[0] and second == order[1] and game.selected_unit == first and cam_ok, "Tab selects the next posted unit and centres the view on it; Shift+Tab goes back")
	hud._unhandled_key_input(_press(KEY_U))
	check(hud._upgrade_panel.visible and hud._upgrade_unit == first, "U on a selected unit opens its upgrade dialog")
	hud._upgrade_panel.visible = false
	var mode: int = game.hero.mode
	hud._unhandled_key_input(_press(KEY_R))
	check(first.state != MilitaryUnit.State.STATIONED and game.selected_unit == null and game.hero.mode == mode, "R withdraws the selected unit (and leaves the hero's mode alone)")
	var a3 := game.army.recruit("archer")
	hud._selected_unit = a3
	game.deselect()
	hud._unhandled_key_input(_press(KEY_U))
	check(hud._upgrade_panel.visible and hud._upgrade_unit == a3, "U on a reserve card picked in the Army tab opens its upgrade dialog")
	hud._upgrade_panel.visible = false
	hud._selected_unit = null
	for u: MilitaryUnit in [a1, a2]:
		game.army.unstation(u)
	# Q: repair the selected building.
	var corner: Building = corners[2]
	game.economy.add("materials", 500)
	corner.hp = corner.max_hp() * 0.5
	game.select(corner)
	hud._unhandled_key_input(_press(KEY_Q))
	check(corner.repairing, "Q orders the selected building's repair")
	game.command("cancel_site", {"building": corner.nid})
	corner.hp = corner.max_hp()
	game.economy.add("materials", -500)
	game.deselect()
	# V: the villager list.
	hud._unhandled_key_input(_press(KEY_V))
	var opened := hud._people_panel.visible
	hud._unhandled_key_input(_press(KEY_V))
	check(opened and not hud._people_panel.visible, "V opens and closes the villager list")
	# X: the hero's panel.
	hud._unhandled_key_input(_press(KEY_X))
	var hero_opened := hud._hero_panel.visible
	hud._unhandled_key_input(_press(KEY_X))
	check(hero_opened and not hud._hero_panel.visible, "X shows and hides the hero panel")
	# N: a workplace without its worker (whatever the earlier tests left: idle ones come first).
	var idle_before := hud.idle_workplaces()
	hud._unhandled_key_input(_press(KEY_N))
	var first_ok := game.selected == (idle_before[0] if not idle_before.is_empty() else null)
	game.deselect()
	var w: Workplace = null
	for b in v.buildings():
		if b is Workplace and b.working() and (b as Workplace).worker_role() != "" and is_instance_valid((b as Workplace).worker):
			w = b
			break
	var reached := false
	if w:
		game.command("unassign_worker", {"building": w.nid})
		for i in hud.idle_workplaces().size():
			hud._unhandled_key_input(_press(KEY_N))
			if game.selected == w:
				reached = game.camera.position.distance_to(w.position) < 2.0
				break
		game.command("assign_worker", {"building": w.nid})
	check(first_ok and w != null and reached, "N picks the nearest workplace without its worker (none: nothing), and steps on to the next")
	game.deselect()
	# F1: the list of hotkeys.
	hud._unhandled_key_input(_press(KEY_F1))
	var shown := hud._keys_panel.visible and hud.top_popup() == hud._keys_panel
	hud._unhandled_key_input(_press(KEY_ESCAPE))
	check(shown and not hud._keys_panel.visible, "F1 shows the hotkeys; Esc closes them")


## F2 (a screenshot), F3 (the log level) and . (call the wave).
func _test_new_keys() -> void:
	var hud := game.hud
	var name_ok := RegEx.create_from_string("^Velirons-Outpost_\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}\\.png$").search(Screenshot.file_name()) != null
	var dirs := Screenshot.dirs()
	check(name_ok and not dirs.is_empty() and dirs[-1] == Config.SCREENSHOT["dir"], "F2's screenshot is named Velirons-Outpost_<date>_<time>.png (%s); last resort: %s (%s)" % [Screenshot.file_name(), Config.SCREENSHOT["dir"], dirs])
	hud._unhandled_key_input(_press(KEY_F2))  # (headless: nothing drawn, so nothing saved, but no harm)
	check(game.events.entries.any(func(e: Dictionary) -> bool: return (e["text"] as String).begins_with("screenshot: ")), "F2 takes a screenshot (logged)")
	var names: Array[String] = []
	for i in 4:
		hud._unhandled_key_input(_press(KEY_F3))
		names.append(game.events.level_name())
	check(names == ["Important", "None", "Debug", "Info"], "F3 cycles the log: Info -> Important -> None -> Debug -> Info (%s)" % [names])
	game.events.cycle_level()
	game.events.cycle_level()
	hud._refresh_log()
	check(game.events.shown_level == EventLog.Level.NONE and hud.log_lines().is_empty(), "log level None: the log field is empty")
	game.events.shown_level = EventLog.Level.INFO
	game.waves.call_locked = true
	hud._refresh_wave()
	hud._unhandled_key_input(_press(KEY_PERIOD))
	var held := not game.waves.in_progress()
	game.waves.call_locked = false
	hud._refresh_wave()
	hud._unhandled_key_input(_press(KEY_PERIOD))
	check(held and game.waves.in_progress(), ". calls the next wave like Call now, only while that button is on")
	game.waves._queue.clear()  # (and that wave is over again, for the tests after this one)
	await clear_enemies()
	await wait_until(func() -> bool: return not game.waves.in_progress(), 5.0)
	game.waves.countdown = 99999.0
	game.waves.hold = true


# --- the tactical map (M; docs/ui-design.md §12) -------------------------------------------

func _map_click(m: TacticalMap, local: Vector2, shift := false) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = local
		e.shift_pressed = shift
		m._gui_input(e)


func _test_map() -> void:
	var hud := game.hud
	var m := hud.tactical_map
	var cam := game.camera
	var top := hud._map_button.get_parent()
	check(hud._map_button.get_index() + 1 == hud._book_button.get_index() and top == hud._book_button.get_parent(), "the map icon sits left of the library")
	check("M" in hud.KEYS_HELP.map(func(r: Array) -> String: return r[0]), "F1's list has M")
	var layers := Settings.map_layers.duplicate()
	hud._unhandled_key_input(_press(KEY_M))
	await frames(2)
	check(m.visible and hud.top_popup() == m, "M opens the map, a popup")
	check(not cam.is_processing_unhandled_input() and not cam.is_processing(), "the camera takes no input while the map is open")
	check(m.offset_top >= hud._top_h - 0.5, "the map stays under the top bar (%.0f, %.0f)" % [m.offset_top, hud._top_h])
	var clock := game.clock
	await wait(0.5)
	check(game.clock > clock and not get_tree().paused, "the game runs on under the map")
	# Keys that don't need the view work with the map open.
	hud._unhandled_key_input(_press(KEY_2))
	var speed_ok := Game.SPEEDS[hud._speed_index] == 2.0
	var was_mode: int = game.hero.mode
	hud._unhandled_key_input(_press(KEY_B))
	check(speed_ok and game.hero.mode == Hero.Mode.BUILD and m.visible, "2 and B work with the map open, and it stays open")
	game.command("hero_mode", {"mode": was_mode})
	hud._unhandled_key_input(_press(KEY_3))
	var cam_zoom := cam.zoom
	var z := m._zoom
	hud._unhandled_key_input(_press(KEY_PLUS))
	check(m._zoom > z and cam.zoom == cam_zoom, "+ zooms the map, not the game's view")
	hud._unhandled_key_input(_press(KEY_MINUS))
	# A drag pans and doesn't pick.
	var c0 := m._center
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = m.size / 2.0
	m._gui_input(e)
	var mm := InputEventMouseMotion.new()
	mm.position = m.size / 2.0 + Vector2(60, 30)
	m._gui_input(mm)
	e = e.duplicate() as InputEventMouseButton
	e.pressed = false
	e.position = mm.position
	m._gui_input(e)
	check(m.visible and m._center != c0, "a drag pans the map and doesn't pick")
	# Shift+click: the view goes there, the map stays.
	var far := game.player_village.center + Vector2i(8, -6)
	cam.focus(Iso.tile_to_world(game.player_village.center))
	_map_click(m, m.to_screen(Iso.tile_to_world(far)), true)
	check(m.visible and cam.position.distance_to(Iso.tile_to_world(far)) < 40.0, "Shift+click centres the view there and keeps the map open (%s)" % str(Iso.to_tile(cam.position)))
	# A click: the view goes there and the map closes.
	var spot := game.player_village.center + Vector2i(-5, 4)
	_map_click(m, m.to_screen(Iso.tile_to_world(spot)))
	check(not m.visible and cam.position.distance_to(Iso.tile_to_world(spot)) < 40.0, "a click centres the view there and closes the map")
	check(cam.is_processing_unhandled_input() and cam.is_processing(), "closed: the camera takes input again")
	# Esc, M, other popups and the view keys close it.
	hud.toggle_map(true)
	hud.escape()
	var esc_ok := not m.visible
	hud.toggle_map(true)
	hud._unhandled_key_input(_press(KEY_M))
	check(esc_ok and not m.visible, "Esc and M close the map")
	hud.toggle_map(true)
	hud.toggle_people(true)
	check(not m.visible and hud._people_panel.visible, "another popup (the villager list) closes the map")
	hud.toggle_people(false)
	hud.toggle_map(true)
	cam.focus(Vector2.ZERO)
	hud._unhandled_key_input(_press(KEY_Z))
	check(not m.visible and cam.position.distance_to(Iso.tile_to_world(game.player_village.center)) < 2.0, "Z closes the map and moves the view to the village")
	hud.toggle_map(true)
	hud.open_library()
	check(not m.visible, "the library closes the map")
	hud.library.close()
	await frames(2)
	# Placing a building ends when the map opens.
	game.begin_build("tower")
	hud.toggle_map(true)
	check(game.mode == Game.Mode.NONE and m.visible, "opening the map ends placing a building")
	# The toggles, remembered.
	(m.buttons["enemies"] as Button).button_pressed = false
	check(not Settings.map_layers["enemies"] and m.buttons["enemies"].modulate.a < 1.0, "a toggle turns its layer off (dimmed)")
	var cf := ConfigFile.new()
	cf.load(Settings.PLAYER_FILE)
	check(cf.get_value("ui", "map_layers", {}).get("enemies", true) == false, "the toggles are remembered on the device")
	m.set_layer("enemies", true)
	check(m.buttons["enemies"].button_pressed and m.buttons["enemies"].modulate.a == 1.0, "and back on")
	# Enemies only on watched land.
	var g := game.waves.spawn_at("goblin", game.player_village.home_spawns[0], game.player_village, 1)
	await frames(2)
	var fog := game.fog
	var i := game.map.index(g.current_tile())
	var seen_all := m.shown_enemies().has(g)
	fog.disabled = false
	var was: Array[int] = [fog.explored_of[fog.local][i], fog.watched_of[fog.local][i]]
	fog.explored_of[fog.local][i] = 1
	fog.watched_of[fog.local][i] = 0
	var hidden := not m.shown_enemies().has(g)
	fog.watched_of[fog.local][i] = 1
	var watched := m.shown_enemies().has(g)
	fog.explored_of[fog.local][i] = was[0]
	fog.watched_of[fog.local][i] = was[1]
	fog.disabled = true
	check(seen_all and hidden and watched, "an enemy shows on the map only where the village watches the land")
	await frames(2)  # (drawn with every layer on, no errors)
	await clear_enemies()
	hud.close_map()
	Settings.map_layers = layers
	Settings.save_player()


func _test_hotkeys() -> void:
	var hud := game.hud
	var scale := Engine.time_scale
	var speeds_ok := true
	for pair in [[KEY_1, 1.0], [KEY_2, 2.0], [KEY_3, 4.0]]:
		hud._unhandled_key_input(_press(pair[0]))
		speeds_ok = speeds_ok and Game.SPEEDS[hud._speed_index] == pair[1]
	check(speeds_ok, "1 / 2 / 3 set the speed to 1x / 2x / 4x")
	hud._unhandled_key_input(_press(KEY_SPACE))
	var paused := Game.SPEEDS[hud._speed_index] == 0.0
	hud._unhandled_key_input(_press(KEY_SPACE))
	check(paused and Game.SPEEDS[hud._speed_index] == 4.0, "Space pauses, and Space again goes back to 4x")
	# The hero's modes: P / B / E / G / Y / R.
	var was_mode: int = game.hero.mode
	var modes_ok := true
	for pair in [[KEY_B, Hero.Mode.BUILD], [KEY_E, Hero.Mode.EXPLORE], [KEY_G, Hero.Mode.GATHER], [KEY_R, Hero.Mode.REST], [KEY_P, Hero.Mode.DEFEND]]:
		hud._unhandled_key_input(_press(pair[0]))
		modes_ok = modes_ok and game.hero.mode == pair[1]
	check(modes_ok and Game.SPEEDS[hud._speed_index] == 4.0, "B / E / G / R / P switch the hero to Build / Explore / Gather / Rest / Defend (P no longer pauses)")
	game.command("hero_mode", {"mode": was_mode})
	# U: the selected wall tower is upgraded (queued for a builder).
	var corner: Building = game.player_village.buildings().filter(func(b: Building) -> bool: return b.kind == "wall_tower" and b.can_upgrade())[0]
	game.economy.add("materials", 500)
	game.select(corner)
	hud._unhandled_key_input(_press(KEY_U))
	check(corner.upgrading and game.player_village.construction.queue.has(corner), "U orders the selected tower's upgrade")
	game.command("cancel_site", {"building": corner.nid})
	game.economy.add("materials", -500)
	game.deselect()
	# Zoom.
	var cam := game.camera
	cam.zoom = Vector2.ONE
	hud._unhandled_key_input(_press(KEY_PLUS))
	var zin := cam.zoom.x
	hud._unhandled_key_input(_press(KEY_MINUS))
	hud._unhandled_key_input(_press(KEY_MINUS))
	check(zin > 1.0 and cam.zoom.x < 1.0, "+ zooms in, - zooms out")
	for i in 40:
		hud._unhandled_key_input(_press(KEY_MINUS))
	check(is_equal_approx(cam.zoom.x, Config.CAMERA_MIN_ZOOM) and Config.CAMERA_MIN_ZOOM < 0.3, "zooming out stops at %.2f" % Config.CAMERA_MIN_ZOOM)
	cam.zoom = Vector2.ONE
	# H: to the hero.
	cam.focus(Iso.tile_to_world(game.player_village.center + Vector2i(15, 15)))
	hud._unhandled_key_input(_press(KEY_H))
	check(cam.position.distance_to(game.hero.position) < 2.0, "H centres the view on the hero")
	hud._unhandled_key_input(_press(KEY_Z))
	check(cam.position.distance_to(Iso.tile_to_world(game.player_village.center)) < 2.0, "Z centres the view on the village")
	# H held: the view follows her; let go, it stays where it is.
	var key := _press(KEY_H)
	Input.parse_input_event(key)
	game.hero.position += Vector2(200, 100)
	await frames(2)
	check(hud._follow_hero and cam.position.distance_to(game.hero.position) < 2.0, "H held keeps the view on the hero")
	var up := key.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)
	var left_at := cam.position
	game.hero.position += Vector2(-200, -100)
	await frames(2)
	check(not hud._follow_hero and cam.position == left_at, "H let go: the view stops following")
	await _test_unit_keys()
	# Esc: the newest popup first, as its Cancel / Close; then the settings.
	for i in 10:
		if hud.top_popup() == null:
			break
		hud.escape()
	game.cancel_mode()
	await frames(1)
	var civ: Civilian = null
	for c in game.population.civilians:
		if game.population.retire_error(c) == "":
			civ = c
			break
	var count := game.population.civilians.size()
	hud.toggle_people(true)
	hud.ask_retire(civ)
	hud._unhandled_key_input(_press(KEY_ESCAPE))
	check(civ != null and not hud._confirm_panel.visible and hud._people_panel.visible and game.population.civilians.size() == count, "Esc closes the newest popup first: the retire question, as Cancel")
	hud._unhandled_key_input(_press(KEY_ESCAPE))
	check(not hud._people_panel.visible and not hud._settings.visible, "Esc again closes the one opened before it")
	hud.set_speed_index(Game.SPEEDS.find(2.0))
	hud._unhandled_key_input(_press(KEY_ESCAPE))
	check(hud._settings.visible and get_tree().paused and hud._gray.visible, "with no popup open, Esc pauses and opens the settings")
	hud._unhandled_key_input(_press(KEY_ESCAPE))
	await frames(1)
	check(not hud._settings.visible and not get_tree().paused and Game.SPEEDS[hud._speed_index] == 2.0, "Esc again closes them, and the game goes on at 2x")
	hud.set_speed_index(Game.SPEEDS.find(0.0))
	hud._unhandled_key_input(_press(KEY_ESCAPE))
	hud._unhandled_key_input(_press(KEY_ESCAPE))
	await frames(1)
	check(not hud._settings.visible and Game.SPEEDS[hud._speed_index] == 0.0, "paused before the settings: still paused after")
	hud.set_speed_index(Game.SPEEDS.find(1.0))
	Engine.time_scale = scale
