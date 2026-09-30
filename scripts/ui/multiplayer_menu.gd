class_name MultiplayerMenu
extends VBoxContainer
## The title screen's Multiplayer pages (docs/multiplayer-design.md §3):
##   join page - your village name and colour, Host game, games found on the
##               local network, join by address, Back;
##   lobby     - two panes: on the left everyone's village (name in its colour,
##               ready or not); on the right your name and colour (changeable
##               until you're ready), the game's settings (the host picks the
##               difficulty, map type and seed) and Ready / Start / Leave.
##               In portrait the panes are stacked.

signal back_pressed

var name_edit: LineEdit
var host_button: Button
var address_edit: LineEdit
var join_button: Button
var games_box: VBoxContainer
var status_label: Label
var back_button: Button
var swatches: Array[Button] = []
# lobby
var lobby: VBoxContainer
var panes: BoxContainer
var players_pane: VBoxContainer
var settings_pane: VBoxContainer
var players_box: VBoxContainer
var ready_button: Button
var start_button: Button
var difficulty_button: Button
var map_button: Button
var seed_edit: LineEdit
var leave_button: Button
var apply_button: Button
var lobby_status: Label
var _join_page: VBoxContainer
var _color := 0


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(400, 0)
	_color = Settings.player_color
	_join_page = VBoxContainer.new()
	_join_page.add_theme_constant_override("separation", 10)
	add_child(_join_page)
	_build_join_page()
	lobby = VBoxContainer.new()
	lobby.add_theme_constant_override("separation", 10)
	add_child(lobby)
	_build_lobby()
	Net.lobby_changed.connect(refresh)
	Net.lobby_message.connect(func(t: String) -> void:
		status_label.text = t
		lobby_status.text = t)
	Net.discovery.games_changed.connect(_refresh_games)
	visibility_changed.connect(_on_shown)
	refresh()


func _panel_label(text: String, size: int = 18, col: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, h: float = 52.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	return b


func _identity_rows(parent: Control) -> void:
	parent.add_child(_panel_label("Your village", 20, UiTheme.GOLD))
	var ne := LineEdit.new()
	ne.placeholder_text = "Village name"
	ne.max_length = 20
	ne.text = Settings.player_name
	ne.custom_minimum_size = Vector2(0, 48)
	ne.add_theme_font_size_override("font_size", 20)
	ne.text_changed.connect(func(t: String) -> void:
		Settings.player_name = t.strip_edges()
		Settings.save_player())
	parent.add_child(ne)
	name_edit = ne
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for i in Config.VILLAGE_COLORS.size():
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(40, 40)
		sw.focus_mode = Control.FOCUS_NONE
		sw.tooltip_text = "Village colour"
		sw.pressed.connect(func() -> void: pick_color(i))
		row.add_child(sw)
		swatches.append(sw)


func _build_join_page() -> void:
	_identity_rows(_join_page)
	host_button = _btn("Host game", 60)
	UiTheme.style_primary(host_button)
	host_button.pressed.connect(func() -> void:
		var err := Net.host(name_edit.text, _color)
		status_label.text = err
		refresh())
	_join_page.add_child(host_button)
	_join_page.add_child(_panel_label("Games on your network", 18, UiTheme.GOLD))
	games_box = VBoxContainer.new()
	games_box.add_theme_constant_override("separation", 6)
	_join_page.add_child(games_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_join_page.add_child(row)
	address_edit = LineEdit.new()
	address_edit.placeholder_text = "Join by address (e.g. 192.168.1.20)"
	address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_edit.custom_minimum_size = Vector2(0, 48)
	row.add_child(address_edit)
	join_button = _btn("Join", 48)
	join_button.custom_minimum_size.x = 90
	join_button.pressed.connect(func() -> void: join(address_edit.text))
	row.add_child(join_button)
	status_label = _panel_label("", 16, UiTheme.BAD)
	_join_page.add_child(status_label)
	back_button = _btn("Back")
	back_button.pressed.connect(func() -> void:
		Net.leave()
		back_pressed.emit())
	_join_page.add_child(back_button)


func _build_lobby() -> void:
	lobby.add_child(_panel_label("Lobby", 30, UiTheme.GOLD))
	panes = BoxContainer.new()
	panes.add_theme_constant_override("separation", 24)
	lobby.add_child(panes)
	# Left: the players.
	players_pane = VBoxContainer.new()
	players_pane.add_theme_constant_override("separation", 8)
	players_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_pane.custom_minimum_size = Vector2(300, 0)
	panes.add_child(players_pane)
	players_pane.add_child(_panel_label("Players", 20, UiTheme.GOLD))
	players_box = VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 4)
	players_pane.add_child(players_box)
	# Right: your village, the game's settings, and the buttons.
	settings_pane = VBoxContainer.new()
	settings_pane.add_theme_constant_override("separation", 10)
	settings_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_pane.custom_minimum_size = Vector2(340, 0)
	panes.add_child(settings_pane)
	apply_button = _btn("Use this name and colour", 44)
	apply_button.pressed.connect(func() -> void: Net.set_identity(name_edit.text, _color))
	settings_pane.add_child(apply_button)
	settings_pane.add_child(_panel_label("Game", 20, UiTheme.GOLD))
	difficulty_button = _btn("", 48)
	difficulty_button.pressed.connect(func() -> void:
		Net.set_difficulty(Settings.CYCLE[Net.difficulty]))
	settings_pane.add_child(difficulty_button)
	map_button = _btn("", 48)
	map_button.pressed.connect(func() -> void:
		Settings.cycle_map_type()
		Net.set_map(Settings.map_type, Net.map_seed))
	settings_pane.add_child(map_button)
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "Map seed (empty: random)"
	seed_edit.custom_minimum_size = Vector2(0, 44)
	seed_edit.add_theme_font_size_override("font_size", 18)
	seed_edit.text_submitted.connect(func(t: String) -> void: Net.set_map(Net.map_type, Settings.parse_seed(t)))
	seed_edit.focus_exited.connect(func() -> void: Net.set_map(Net.map_type, Settings.parse_seed(seed_edit.text)))
	settings_pane.add_child(seed_edit)
	ready_button = _btn("Ready", 56)
	ready_button.toggle_mode = true
	ready_button.toggled.connect(func(on: bool) -> void:
		Net.set_ready(on)
		ready_button.text = "Ready ✓" if on else "Ready")
	settings_pane.add_child(ready_button)
	start_button = _btn("Start", 60)
	UiTheme.style_good(start_button)
	start_button.pressed.connect(func() -> void: Net.start_game())
	settings_pane.add_child(start_button)
	lobby_status = _panel_label("", 16, UiTheme.BAD)
	settings_pane.add_child(lobby_status)
	leave_button = _btn("Leave")
	UiTheme.style_danger(leave_button)
	leave_button.pressed.connect(func() -> void:
		Net.leave()
		refresh())
	settings_pane.add_child(leave_button)
	Layout.changed.connect(func(_p: bool) -> void: _fit_panes())
	_fit_panes()


## Side by side in landscape, stacked in portrait.
func _fit_panes() -> void:
	panes.vertical = Layout.portrait


func pick_color(i: int) -> void:
	_color = i
	Settings.player_color = i
	Settings.save_player()
	_refresh_swatches()


func join(address: String) -> void:
	var a := address.strip_edges()
	if a == "":
		status_label.text = "Type the host's address, or pick a game from the list"
		return
	status_label.text = Net.join(a, name_edit.text, _color)
	if status_label.text == "":
		status_label.text = "Connecting to %s..." % a


func _on_shown() -> void:
	if is_visible_in_tree():
		status_label.text = ""
		if not Net.discovery.is_listening() and not Net.is_host():
			var err := Net.discovery.start_listening()
			if err != "":
				status_label.text = err
		_refresh_games()
	else:
		Net.discovery.stop_listening()


## Shows the join page or the lobby, whichever fits the session.
func refresh() -> void:
	var in_lobby := Net.is_online() and (Net.is_host() or not Net.players.is_empty())
	_join_page.visible = not in_lobby
	lobby.visible = in_lobby
	# Your name and colour sit at the top of the lobby's right pane.
	if in_lobby and name_edit.get_parent() != settings_pane:
		name_edit.get_parent().remove_child(name_edit)
		settings_pane.add_child(name_edit)
		settings_pane.move_child(name_edit, 0)
		var row := swatches[0].get_parent()
		row.get_parent().remove_child(row)
		settings_pane.add_child(row)
		settings_pane.move_child(row, 1)
	elif not in_lobby and name_edit.get_parent() == settings_pane:
		for n in [name_edit, swatches[0].get_parent()]:
			settings_pane.remove_child(n)
			_join_page.add_child(n)
			_join_page.move_child(n, 1 if n == name_edit else 2)
	for c in players_box.get_children():
		c.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	var me := Net.my_id()
	var mine: Dictionary = Net.players.get(me, {})
	for id in ids:
		var p: Dictionary = Net.players[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var chip := ColorRect.new()
		chip.color = Config.VILLAGE_COLORS[int(p["color"])]
		chip.custom_minimum_size = Vector2(22, 22)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		var l := _panel_label("%s%s" % [p["name"], "  (you)" if id == me else ""], 20, Config.VILLAGE_COLORS[int(p["color"])])
		# One line per player: no wrapping (a wrapped label in a row has no width
		# to wrap in and ends up one letter per line).
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var state := _panel_label("host" if id == 1 else ("ready" if p["ready"] else "not ready"), 16, UiTheme.GOOD if (id == 1 or p["ready"]) else UiTheme.MUTED)
		state.autowrap_mode = TextServer.AUTOWRAP_OFF
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(state)
		players_box.add_child(row)
	var ready_now: bool = mine.get("ready", false)
	name_edit.editable = not ready_now or Net.is_host()
	apply_button.visible = in_lobby and not ready_now
	ready_button.visible = Net.is_client()
	ready_button.set_pressed_no_signal(ready_now)
	ready_button.text = "Ready ✓" if ready_now else "Ready"
	difficulty_button.visible = Net.is_host()
	difficulty_button.text = "Difficulty: %s" % Settings.NAMES[Net.difficulty]
	# Everyone sees the map settings; only the host changes them.
	map_button.disabled = not Net.is_host()
	map_button.text = "Map: %s" % Settings.map_type_name(Net.map_type) + ("" if Net.is_host() else "  (host)")
	map_button.visible = in_lobby
	seed_edit.visible = in_lobby and Net.is_host()
	if Net.is_host() and not seed_edit.has_focus():
		seed_edit.text = str(Net.map_seed) if Net.map_seed != 0 else ""
	start_button.visible = Net.is_host()
	start_button.disabled = not Net.can_start()
	start_button.text = "Start" if Net.can_start() else "Start (waiting for everyone to be ready)"
	if not mine.is_empty():
		_color = int(mine["color"])
	_refresh_swatches()


func _refresh_swatches() -> void:
	var taken := {}
	for id in Net.players:
		if id != Net.my_id():
			taken[int(Net.players[id]["color"])] = true
	for i in swatches.size():
		var sw := swatches[i]
		var col := Config.VILLAGE_COLORS[i]
		if taken.has(i):
			col = col.darkened(0.6)
		sw.add_theme_stylebox_override("normal", UiTheme.box(col, Color.WHITE if i == _color else UiTheme.INK, 4 if i == _color else 2, 6, 0))
		sw.add_theme_stylebox_override("hover", UiTheme.box(col.lightened(0.15), UiTheme.GOLD, 3, 6, 0))
		sw.add_theme_stylebox_override("pressed", UiTheme.box(col, UiTheme.GOLD, 3, 6, 0))
		sw.disabled = taken.has(i)


func _refresh_games() -> void:
	if games_box == null:
		return
	for c in games_box.get_children():
		c.queue_free()
	var games := Net.discovery.games()
	var seen := {}
	for g in games:
		var key := "%s:%d" % [g["name"], g["port"]]
		if seen.has(key):
			continue  # (the same game heard via loopback and the network)
		seen[key] = true
		var b := _btn("%s   %d/%d   %s" % [g["name"], g["players"], g["max"], g["difficulty"]], 48)
		b.disabled = g["proto"] != Net.PROTOCOL or g["players"] >= g["max"]
		if g["proto"] != Net.PROTOCOL:
			b.text += "   (other version)"
		var addr := "%s:%d" % [g["address"], g["port"]]
		b.pressed.connect(func() -> void: join(addr))
		games_box.add_child(b)
	if games_box.get_child_count() == 0:
		games_box.add_child(_panel_label("Looking for games...", 16, UiTheme.MUTED))
