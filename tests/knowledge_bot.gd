extends "res://tests/bot_base.gd"
## Headless test of the knowledge base (docs/tutorial-design.md, part B): every
## kind in Config has its entry with Config's numbers, the art exists, the
## book icon opens it in a game (pausing single player, back at the old speed
## after; co-op doesn't pause), on the title screen, and it fits on screen in
## landscape and portrait. Run with:
##   godot --headless --fixed-fps 60 --path . res://tests/knowledge_bot.tscn
## Exits 0 when every check passes.


func _run() -> void:
	_pages()
	await _in_game()
	await _title()
	await _first_open()
	Engine.time_scale = 1.0
	print("CHECKS %d  FAILURES %d" % [checks, failures.size()])
	for f in failures:
		print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _names(tab: String) -> Array[String]:
	var out: Array[String] = []
	for e in KnowledgeBase.entries(tab):
		out.append(str(e["name"]))
	return out


func _entry(tab: String, name: String) -> Dictionary:
	for e in KnowledgeBase.entries(tab):
		if e["name"] == name:
			return e
	return {}


func _facts(tab: String, name: String) -> String:
	var e := _entry(tab, name)
	return "\n".join(e.get("facts", PackedStringArray()))


func _all_in(names: Array[String], wanted: Array, what: String) -> void:
	var missing: Array = wanted.filter(func(n: String) -> bool: return not n in names)
	check(missing.is_empty(), "%s: every one has an entry (missing %s)" % [what, str(missing)])


func _pages() -> void:
	print("-- the pages")
	_all_in(_names("enemies"), Config.ENEMIES.values().map(func(e: Dictionary) -> String: return e["name"]), "enemies")
	_all_in(_names("units"), Config.MILITARY_TREE.map(func(k: String) -> String: return Config.MILITARY[k]["name"]), "units, specialisations too")
	_all_in(_names("units"), Config.SUMMONS.values().map(func(s: Dictionary) -> String: return s["name"]), "summoned elementals")
	_all_in(_names("buildings"), Config.BUILDINGS.values().map(func(b: Dictionary) -> String: return b["name"]) + ["Wall Tower"], "buildings")
	_all_in(_names("villagers"), Config.CIVILIAN_ORDER.map(func(k: String) -> String: return Config.CIVILIANS[k]["name"]), "villagers, locked ones too")
	var modes: Array = []
	for m in Hero.MODE_NAMES:
		modes.append("Mode: %s" % m + (" (co-op)" if m == "Support" else ""))
	_all_in(_names("hero"), ["Hero", "Earning XP"] + modes, "the hero and his modes")
	_all_in(_names("places"), Config.TREASURES.values().map(func(t: Dictionary) -> String: return t["name"]) + ["Relics", "Monster camp", "Monster lair", "Mine", "Ruined watchtower"], "treasures and places")
	_all_in(_names("places"), Config.UNLOCK_SITES.values().map(func(s: Dictionary) -> String: return s["name"]), "unit-unlock sites")
	# The numbers are Config's.
	var gob := _facts("enemies", "Goblin")
	check(("HP %s" % KnowledgeBase._n(Config.enemy_stat("goblin", "hp"))) in gob and "from wave 1" in gob, "goblin: HP and first wave from Config\n%s" % gob)
	check("from wave %d" % Config.WAVE_MIX["vampire"]["from_wave"] in _facts("enemies", "Vampire") and "magical" in _facts("enemies", "Vampire"), "vampire: its wave and its resistance")
	check("leaves no corpse" in _facts("enemies", "Rat") and "in packs" in _facts("enemies", "Rat"), "rats: packs, no corpse")
	check("Flies" in _facts("enemies", "Gargoyle"), "gargoyles fly")
	var arch := _facts("units", "Archer")
	check(("Recruit: %s" % Config.cost_text(Config.MILITARY["archer"]["cost"])) in arch and "Crossbowman, Swiftbowman" in arch, "archer: cost and specialisations\n%s" % arch)
	check("Barracks only" in _facts("units", "Shield Bearer"), "shield bearers: barracks only")
	check("found first" in _facts("units", "Summoner") and "stone circle" in _facts("units", "Summoner"), "summoner: found at the stone circle")
	check("specialisation of the Apprentice" in _facts("units", "Fire Mage"), "fire mage: an apprentice's specialisation")
	check(("%s tiles" % KnowledgeBase._n(Config.TOWER_RANGE["tower"])) in _facts("buildings", "Watchtower"), "watchtower: its range")
	check("3 benches" in _facts("buildings", "Barracks"), "barracks: its levels")
	check("found first" in _facts("villagers", "Miner") and "Can't be recruited" in _facts("villagers", "Spatial Archmage"), "miner locked, archmage not recruited")
	check(("%d XP for level 2" % Config.hero_level_cost(0)) in _facts("hero", "Hero"), "hero: level cost")
	var lair := _facts("places", "Monster lair")
	check(("wave %d" % Config.LAIR_FROM_WAVE) in lair and "Crypt" in lair, "lairs: their wave and kinds\n%s" % lair)
	# Every entry has text or facts, and its art exists.
	var bad: Array[String] = []
	var empty: Array[String] = []
	for tab in KnowledgeBase.TABS:
		for e in KnowledgeBase.entries(tab):
			if not ResourceLoader.exists("res://art/%s.svg" % e["art"]):
				bad.append("%s (%s)" % [e["name"], e["art"]])
			if str(e.get("text", "")) == "" and (e["facts"] as PackedStringArray).is_empty():
				empty.append(str(e["name"]))
	check(bad.is_empty(), "every entry's art exists %s" % str(bad))
	check(empty.is_empty(), "every entry says something %s" % str(empty))


func _in_game() -> void:
	print("-- in a game")
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await frames(3)
	var hud := game.hud
	var kb := hud.knowledge_base
	check(hud._book_button.get_index() == hud._settings_button.get_index() - 1, "the book icon sits left of the settings icon")
	hud.set_speed_index(Game.SPEEDS.find(2.0))
	await frames(1)
	hud._book_button.pressed.emit()
	await frames(2)
	check(kb.visible and get_tree().paused, "the book icon opens it and pauses the game")
	for tab in KnowledgeBase.TABS:
		(kb._tab_buttons[tab] as Button).pressed.emit()
		await frames(1)
		check(kb.tab == tab and kb.shown_names() == _names(tab), "tab %s shows its %d entries" % [tab, _names(tab).size()])
	hud.toggle_pause()
	check(get_tree().paused and kb.visible, "Space does nothing while it's open")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	kb._unhandled_key_input(esc)
	await frames(2)
	check(not kb.visible and not get_tree().paused and Game.SPEEDS[hud._speed_index] == 2.0, "Escape closes it; the game goes on at 2x")
	hud.open_knowledge_base()
	check(kb.tab == "places", "it opens on the tab shown last")
	kb.close()
	await frames(1)
	hud.set_speed_index(Game.SPEEDS.find(0.0))
	hud.open_knowledge_base("units")
	check(kb.tab == "units", "it can open on a given tab")
	kb.close()
	await frames(1)
	check(get_tree().paused and Game.SPEEDS[hud._speed_index] == 0.0, "paused before: still paused after")
	hud.set_speed_index(Game.SPEEDS.find(1.0))
	await frames(1)
	game.networked = true  # (as in co-op)
	hud.open_knowledge_base()
	check(kb.visible and not get_tree().paused, "co-op: it doesn't pause")
	kb.close()
	game.networked = false
	await frames(1)
	for sz in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		get_window().size = sz
		get_viewport().size = sz
		await frames(4)
		var vp := Rect2(Vector2.ZERO, Vector2(sz))
		check(vp.encloses(hud._topbar.get_global_rect().grow(-0.5)) and hud._settings_button.is_visible_in_tree(), "%dx%d: the top bar with the book icon fits" % [sz.x, sz.y])
		var wave_y: float = hud._top_right.get_global_rect().position.y
		var res_y: float = hud._top_left.get_global_rect().position.y
		if sz.y > sz.x:
			check(wave_y < res_y, "portrait: the wave, speed, book and settings row is above the resources and hero")
		else:
			check(is_equal_approx(wave_y, res_y) and hud._top_left.get_global_rect().position.x < hud._top_right.get_global_rect().position.x, "landscape: one row, resources on the left")
		hud.open_knowledge_base("units")
		await frames(3)
		var r: Rect2 = kb._panel.get_global_rect()
		check(vp.encloses(r) and r.size.x >= minf(sz.x - 24.0, 900.0) - 1.0, "%dx%d: the knowledge base fits on screen (%s)" % [sz.x, sz.y, str(r)])
		kb.close()
		await frames(1)
	game.queue_free()
	await frames(3)


## A new one opened the first time, on a phone screen: it fits at once, and a
## drag on an entry (not only between them) reaches the scroll list.
func _first_open() -> void:
	print("-- first open, portrait")
	var sz := Vector2i(720, 1280)
	get_window().size = sz
	get_viewport().size = sz
	await frames(3)
	var layer := CanvasLayer.new()
	add_child(layer)
	var kb := KnowledgeBase.new()
	layer.add_child(kb)
	await frames(1)
	kb.open("enemies")
	var vp := Rect2(Vector2.ZERO, Vector2(sz))
	await frames(3)
	check(vp.encloses(kb._panel.get_global_rect()), "the first open fits on screen (%s)" % str(kb._panel.get_global_rect()))
	var stops: Array[String] = []
	for c in kb._list.find_children("*", "Control", true, false):
		if (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			stops.append(str(c.get_class()))
	check(stops.is_empty(), "nothing in the entries catches the mouse, so they scroll %s" % str(stops))
	check(kb._scroll.get_v_scroll_bar().max_value > kb._scroll.size.y, "the list is longer than the view: it scrolls")
	var first: Control = kb._list.get_child(0)
	var at := first.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	down.position = at
	down.global_position = at
	get_viewport().push_input(down)
	await frames(2)
	check(kb._scroll.scroll_vertical > 0, "the wheel over an entry scrolls (%d)" % kb._scroll.scroll_vertical)
	layer.queue_free()
	await frames(1)


func _title() -> void:
	print("-- title screen")
	var t = load("res://scenes/title.tscn").instantiate()
	add_child(t)
	await frames(3)
	var bb: Button = t.knowledge_button
	check(bb.is_visible_in_tree() and bb.get_index() == t.multiplayer_button.get_index() + 1, "the title screen's menu has Knowledge base, under Multiplayer")
	check(t.help_button.is_visible_in_tree() and t.help_button.get_index() == bb.get_index() + 1, "and Help under that")
	bb.pressed.emit()
	await frames(2)
	var kb: KnowledgeBase = t.knowledge_base
	check(kb.visible and kb.shown_names().size() > 0, "it opens the knowledge base")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	kb._unhandled_key_input(esc)
	await frames(1)
	check(not kb.visible and t._main_page.visible, "Escape closes it, the menu stays")
	t.queue_free()
	await frames(1)
