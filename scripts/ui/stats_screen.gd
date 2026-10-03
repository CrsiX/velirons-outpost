class_name StatsScreen
extends Control
## The statistics screen (docs/statistics-design.md §6): tabs Summary (the
## counters, a column per village), Timeline (a line graph of the samples)
## and Awards. Built from Game.stats whenever it opens or the numbers change.
## Opened by the HUD (bar-chart icon in the top bar, T, the game-over screen),
## which pauses the game if it should (Hud.open_stats).

signal closed

const TABS: Array[String] = ["summary", "timeline", "awards"]
const TAB_NAMES := {"summary": "Summary", "timeline": "Timeline", "awards": "Awards"}
## Timeline metrics: [name, series key ("army_hp" is computed), icon].
const METRICS: Array = [
	["Gold", "gold", "icon_gold"], ["Food", "food", "icon_food"], ["Material", "materials", "icon_materials"],
	["Villagers", "villagers", "icon_population"], ["Huts", "huts", "hut"], ["Army", "units", "icon_army"],
	["Army HP %", "army_hp", "icon_hp"], ["Buildings", "buildings", "watchtower"], ["Explored", "explored", "mode_explore"],
	["Enemies", "enemies", "icon_enemies"], ["Corpses", "corpses", "mode_gather"],
	["Hero XP", "hero_xp", "icon_xp"], ["Hero level", "hero_level", "icon_hero"], ["Hero HP", "hero_hp", "icon_hp"],
]
const SOURCE_NAMES := {
	"kills": "kills", "corpses": "corpses", "mines": "mines", "treasure": "treasure", "call": "calling waves early",
	"caravans": "caravans received", "farms": "farms", "foresters": "foresters", "trade": "trade",
	"teardown": "tear-down refunds",
}
const SPENT_NAMES := {
	"buildings": "buildings", "units": "units", "upgrades": "upgrades", "villagers": "villagers",
	"trade": "trade", "caravans": "caravans sent",
}
const RES_ICONS := {"gold": "icon_gold", "food": "icon_food", "materials": "icon_materials"}
const RES_NAMES := {"gold": "Gold", "food": "Food", "materials": "Material"}
const FOUND_NAMES := {
	"treasure": "treasures", "ruin": "ruined watchtowers", "mine": "mines", "camp": "monster camps",
	"lair": "monster lairs", "unlock": "unlock sites",
}
const LOST_NAMES := {"enemies": "killed by enemies", "starved": "starved", "hut": "hut burned", "other": "other causes"}

static var _last_tab := "summary"
static var _last_metric := 0
## Folded Summary sections (by title), kept while the game runs.
static var _folded := {}

var game: Game
var tab := ""
var _panel: PanelContainer
var _tab_buttons := {}
var _scroll: ScrollContainer
var _list: VBoxContainer
var _next_refresh := 0


func _init() -> void:
	name = "StatsScreen"
	theme = UiTheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS  # (open while the game is paused)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color("2a1a14"), UiTheme.GOLD, 4, 14, 16))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_icon("icon_stats", 40))
	var title := _label("Statistics", 30, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var close_button := _button("Close", Vector2(110, 48))
	UiTheme.style_good(close_button)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for key in TABS:
		var b := _button(TAB_NAMES[key], Vector2(0, 44))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: show_tab(key))
		tabs.add_child(b)
		_tab_buttons[key] = b
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	visible = false


func setup(p_game: Game) -> void:
	game = p_game
	game.stats.updated.connect(func() -> void:
		if visible:
			_rebuild())


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## Shows the screen on `p_tab` (empty: the tab shown last).
func open(p_tab := "") -> void:
	visible = true
	tab = p_tab if p_tab in TABS else _last_tab
	_rebuild()
	_next_refresh = Time.get_ticks_msec() + int(float(Config.STATS["client_refresh"]) * 1000.0)
	game.stats.request()
	_fit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func show_tab(key: String) -> void:
	tab = key
	_last_tab = key
	_scroll.scroll_vertical = 0
	_scroll.scroll_horizontal = 0
	_rebuild()


## While it's open and the game goes on (co-op, or after a resume), the
## numbers are fetched again now and then (a client asks the host).
func _process(_delta: float) -> void:
	if not visible or game.stats.ended or get_tree().paused:
		return
	if Time.get_ticks_msec() >= _next_refresh:
		_next_refresh = Time.get_ticks_msec() + int(float(Config.STATS["client_refresh"]) * 1000.0)
		game.stats.request()


func _rebuild() -> void:
	for k: String in _tab_buttons:
		UiTheme.style_selected(_tab_buttons[k], k == tab)
	var keep := Vector2i(_scroll.scroll_horizontal, _scroll.scroll_vertical)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if tab == "summary" else ScrollContainer.SCROLL_MODE_DISABLED
	if not game.stats.ready_to_show():
		_list.add_child(_label("Loading…", 20, UiTheme.MUTED))
		return
	match tab:
		"summary":
			_build_summary()
		"timeline":
			_build_timeline()
		"awards":
			_build_awards()
	_scroll.set_deferred("scroll_horizontal", keep.x)
	_scroll.set_deferred("scroll_vertical", keep.y)


func _fit() -> void:
	var vp := get_viewport_rect().size
	var s := Vector2(minf(vp.x - 24.0, 960.0), minf(vp.y - 24.0, 780.0))
	_panel.size = s
	_panel.position = ((vp - s) / 2.0).floor()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_F11:
		return  # (fullscreen still works)
	if (key == KEY_ESCAPE or key == KEY_T) and not event.is_echo():
		close()
	get_viewport().set_input_as_handled()  # (modal: no Space, Tab, Enter behind it)


# --- Summary ------------------------------------------------------------------------------

## The Summary's sections: {"title", "rows": [{"name", "icon", "key" or
## "get": Callable(vid) -> float, "fmt": "n" / "time" / "wave", "rank":
## "high" / "low" / "", "sub": a sub-row (shown only where some village has it)}]}.
func summary_sections() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mil: Array = [_row("Enemies killed", "kills", "high", "icon_enemies")]
	for k: String in Config.STATS["kill_kinds"]:
		mil.append(_sub(Config.ENEMIES[k]["name"] + "s", "kill." + k, "high"))
	mil.append(_sub("Raised dead", "kill.raised", "high"))
	mil.append(_sub("Others", "kill.other", "high"))
	for by in [["by towers", "tower"], ["by barracks units", "units"], ["by summons", "summons"], ["by the hero", "hero"]]:
		mil.append(_sub(by[0], "kill_by." + by[1], "high"))
	mil.append(_row("Got through a gate", "gate", "low"))
	mil.append(_row("Huts burned", "huts_burned", "low", "hut_ruin"))
	mil.append(_row("Waves survived", "waves", "high"))
	var big := _row("Biggest wave (enemies)", "biggest_wave", "high")
	big["fmt"] = "wave"
	big["wave_key"] = "biggest_wave_n"
	mil.append(big)
	var fast := _row("Fastest wave cleared", "fastest_wave", "low", "icon_fastest")
	fast["fmt"] = "time"
	fast["wave_key"] = "fastest_wave_n"
	mil.append(fast)
	mil.append(_row("Units recruited", "units_recruited", "high", "icon_army"))
	mil.append(_row("Unit levels bought", "units_upgraded", "high"))
	mil.append(_row("Units specialised", "units_specialised", "high"))
	mil.append(_row("Unit levels trained", "units_trained", "high"))
	mil.append(_row("Units downed", "units_downed", "low"))
	out.append({"title": "Military", "rows": mil})

	var eco: Array = []
	for res in ["gold", "food", "materials"]:
		eco.append(_row(RES_NAMES[res] + " earned", "earn." + res, "high", RES_ICONS[res]))
		for src: String in SOURCE_NAMES:
			eco.append(_sub("from " + SOURCE_NAMES[src], "earn.%s.%s" % [res, src], "high"))
	for res in ["gold", "food", "materials"]:
		eco.append(_row(RES_NAMES[res] + " spent", "spend." + res, "", RES_ICONS[res]))
		for what: String in SPENT_NAMES:
			eco.append(_sub("on " + SPENT_NAMES[what], "spend.%s.%s" % [res, what], ""))
	eco.append(_row("Gold stolen by thieves", "stolen", "low", "icon_gold"))
	eco.append(_row("Food eaten by rats at the gates", "rat_food_gate", "low", "icon_food"))
	eco.append(_row("Food eaten by rats on farms", "rat_food_farm", "low", "icon_food"))
	out.append({"title": "Economy", "rows": eco})

	var vil: Array = [_row("Villagers recruited", "_recruited", "high", "icon_population")]
	vil[0]["get"] = func(vid: int) -> float: return _sum_prefix(vid, "recruit.")
	for role: String in Config.CIVILIANS:
		vil.append(_sub(Config.CIVILIANS[role]["name"] + "s", "recruit." + role, "high"))
	vil.append(_row("Villagers lost", "_lost", "low"))
	vil[-1]["get"] = func(vid: int) -> float: return _sum_prefix(vid, "lost.")
	for cause: String in LOST_NAMES:
		vil.append(_sub(LOST_NAMES[cause], "lost." + cause, "low"))
	vil.append(_row("Buildings built", "built", "high", "watchtower"))
	vil.append(_row("Buildings torn down", "torn_down", ""))
	vil.append(_row("Buildings lost (huts burned)", "huts_burned", "low", "hut_ruin"))
	vil.append(_row("Huts rebuilt", "huts_rebuilt", "", "hut"))
	vil.append(_row("Tiles explored", "explored", "high", "mode_explore"))
	vil.append(_row("Special objects found", "_found", "high"))
	vil[-1]["get"] = func(vid: int) -> float: return _sum_prefix(vid, "found.")
	for kind: String in FOUND_NAMES:
		vil.append(_sub(FOUND_NAMES[kind], "found." + kind, "high"))
	out.append({"title": "Village", "rows": vil})

	var hero: Array = [
		_row("Kills", "hero.kills", "high", "icon_enemies"),
		_row("XP earned", "hero.xp", "high", "icon_xp"),
		_row("Highest level", "hero.level", "high", "icon_hero"),
		_row("Times downed", "hero.downed", "low"),
	]
	var streak := _row("Longest time without being downed", "hero.streak", "high")
	streak["fmt"] = "time"
	hero.append(streak)
	out.append({"title": "Hero", "rows": hero})

	if game.stats.villages.size() > 1:
		var coop: Array = [_row("Caravans sent", "caravans_sent", "high", "unit_caravan")]
		for res in ["gold", "food", "materials"]:
			coop.append(_sub(RES_NAMES[res] + " sent", "caravan_sent." + res, "high"))
		for res in ["gold", "food", "materials"]:
			coop.append(_row(RES_NAMES[res] + " received (after tax)", "caravan_got." + res, "", RES_ICONS[res]))
		coop.append(_row("Units sent", "units_sent", "high", "icon_army"))
		coop.append(_row("Units received", "units_got", ""))
		var sup := _row("Hero's time in Support mode", "hero.support_time", "high", "icon_hero")
		sup["fmt"] = "time"
		coop.append(sup)
		coop.append(_row("Hero's kills in Support mode", "hero.support_kills", "high"))
		out.append({"title": "Co-op", "rows": coop})
	return out


func _row(p_name: String, key: String, rank: String, icon := "") -> Dictionary:
	return {"name": p_name, "key": key, "rank": rank, "icon": icon, "fmt": "n", "sub": false}


func _sub(p_name: String, key: String, rank: String) -> Dictionary:
	var r := _row(p_name, key, rank)
	r["sub"] = true
	return r


func _sum_prefix(vid: int, prefix: String) -> float:
	var total := 0.0
	var c: Dictionary = game.stats.villages[vid]["c"]
	for k: String in c:
		if k.begins_with(prefix):
			total += float(c[k])
	return total


## Row `r`'s number for village `vid`, and whether it has one at all.
func row_value(r: Dictionary, vid: int) -> float:
	if r.has("get"):
		return (r["get"] as Callable).call(vid)
	return game.stats.value(vid, r["key"])


func _row_has(r: Dictionary, vid: int) -> bool:
	if r.has("get"):
		return true
	if r["fmt"] == "time" or r["fmt"] == "wave":
		return game.stats.has_value(vid, r["key"])
	return true


func _build_summary() -> void:
	var n := game.stats.villages.size()
	if n > 1:
		var head := _grid(n)
		head.add_child(_label("", 16))
		for vid in n:
			var l := _label(str(game.stats.villages[vid]["name"]), 17, game.stats.villages[vid]["color"])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			head.add_child(l)
		_list.add_child(head)
	for sec in summary_sections():
		var title: String = sec["title"]
		var folded := bool(_folded.get(title, false))
		var b := _button(("▸ " if folded else "▾ ") + title, Vector2(0, 40))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", UiTheme.GOLD)
		b.set_meta("section", title)
		b.pressed.connect(func() -> void:
			_folded[title] = not bool(_folded.get(title, false))
			_rebuild())
		_list.add_child(b)
		if folded:
			continue
		var grid := _grid(n)
		for r: Dictionary in sec["rows"]:
			var vals: Array[float] = []
			var any := false
			for vid in n:
				vals.append(row_value(r, vid))
				if vals[vid] != 0.0 and _row_has(r, vid):
					any = true
			if r["sub"] and not any:
				continue  # (sub-rows only where something happened)
			grid.add_child(_row_label(r))
			var best := _best(r, vals) if n > 1 else -1
			for vid in n:
				var l := _label(_format(r, vid, vals[vid]), 16 if not r["sub"] else 15, UiTheme.GOLD if vid == best else (UiTheme.TEXT if not r["sub"] else UiTheme.MUTED))
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				l.custom_minimum_size = Vector2(120, 0)
				if vid == best:
					l.set_meta("best", true)
				grid.add_child(l)
		_list.add_child(grid)


func _grid(n: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = n + 1
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 4)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _row_label(r: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size = Vector2(300, 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if r["sub"]:
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(22, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(pad)
	elif r["icon"] != "":
		h.add_child(_icon(r["icon"], 22))
	else:
		var pad2 := Control.new()
		pad2.custom_minimum_size = Vector2(22, 0)
		pad2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(pad2)
	var l := _label(r["name"], 15 if r["sub"] else 16, UiTheme.MUTED if r["sub"] else UiTheme.TEXT)
	l.set_meta("row", r["name"])
	h.add_child(l)
	return h


## Co-op: the village with the best value in the row (-1: no rank, a tie, or nothing yet).
func _best(r: Dictionary, vals: Array[float]) -> int:
	if r["rank"] == "":
		return -1
	var best := -1
	var tie := false
	for vid in vals.size():
		if not _row_has(r, vid):
			continue
		if best < 0:
			best = vid
			continue
		var better: bool = vals[vid] > vals[best] if r["rank"] == "high" else vals[vid] < vals[best]
		if better:
			best = vid
			tie = false
		elif vals[vid] == vals[best]:
			tie = true
	if best < 0 or tie:
		return -1
	if r["rank"] == "high" and vals[best] <= 0.0:
		return -1
	return best


func _format(r: Dictionary, vid: int, v: float) -> String:
	if not _row_has(r, vid):
		return "–"
	match r["fmt"]:
		"time":
			var s := format_time(v)
			if r.has("wave_key"):
				s += "  (wave %d)" % int(game.stats.value(vid, r["wave_key"]))
			return s
		"wave":
			return "%d  (wave %d)" % [int(v), int(game.stats.value(vid, r["wave_key"]))]
	return format_number(v)


static func format_number(v: float) -> String:
	if absf(v - roundf(v)) < 0.05 or absf(v) >= 100.0:
		return str(int(roundf(v)))
	return "%.1f" % v


## "1:05", "1:02:03".
static func format_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


# --- Timeline -----------------------------------------------------------------------------

func _build_timeline() -> void:
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(240, 44)
	pick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for i in METRICS.size():
		var m: Array = METRICS[i]
		pick.add_icon_item(Art.tex(m[2]) if ResourceLoader.exists("res://art/%s.svg" % m[2]) else null, m[0], i)
	pick.select(_last_metric)
	pick.get_popup().process_mode = Node.PROCESS_MODE_ALWAYS
	_list.add_child(pick)
	var graph := StatsGraph.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(0, 300)
	_list.add_child(graph)
	graph.set_data(_timeline_data(_last_metric))
	pick.item_selected.connect(func(i: int) -> void:
		_last_metric = i
		graph.set_data(_timeline_data(i)))
	if game.stats.villages.size() > 1:
		var legend := HFlowContainer.new()
		legend.add_theme_constant_override("h_separation", 16)
		for v in game.stats.villages:
			legend.add_child(_label("■ " + str(v["name"]), 16, v["color"]))
		_list.add_child(legend)


## What the graph shows for metric `i`: {"name", "times", "marks", "lines": [{"name", "color", "values"}]}.
func _timeline_data(i: int) -> Dictionary:
	var key: String = METRICS[i][1]
	var lines: Array = []
	for vid in game.stats.villages.size():
		var vals := PackedFloat32Array()
		if key == "army_hp":
			var hp := game.stats.series(vid, "units_hp")
			var mx := game.stats.series(vid, "units_max_hp")
			for k in hp.size():
				vals.append(hp[k] / mx[k] * 100.0 if mx[k] > 0.0 else 0.0)
		else:
			vals = game.stats.series(vid, key)
		lines.append({"name": game.stats.villages[vid]["name"], "color": game.stats.villages[vid]["color"], "values": vals})
	return {"name": METRICS[i][0], "times": game.stats.times, "marks": game.stats.wave_marks, "lines": lines}


# --- Awards -------------------------------------------------------------------------------

## The award cards: {"title", "art", "text", "detail"} (one per award that has a winner).
func awards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var st := game.stats
	var coop := st.villages.size() > 1
	# Deadliest tower.
	var best: Array = []
	var best_v := -1
	for vid in st.villages.size():
		for nid in st.villages[vid]["towers"]:
			var row: Array = st.villages[vid]["towers"][nid]
			if best.is_empty() or int(row[1]) > int(best[1]):
				best = row
				best_v = vid
	if not best.is_empty():
		var detail := "Level %d tower" % int(best[2])
		if str(best[3]) != "":
			detail += ", %s" % best[3]
		out.append({"title": "Deadliest tower", "art": "watchtower" if int(best[2]) <= 1 else "watchtower_%d" % mini(int(best[2]), 3),
			"text": "%s%s: %d kills" % [str(best[0]).capitalize(), _of(best_v, coop), int(best[1])], "detail": detail})
	var g := _top(st, "gatherers")
	if not g.is_empty():
		out.append({"title": "Busiest gatherer", "art": "unit_gatherer",
			"text": "%s%s" % [str(g[0]).capitalize(), _of(g[2], coop)], "detail": "%d corpses brought home" % int(g[1])})
	var e := _top(st, "explorers")
	if not e.is_empty():
		out.append({"title": "Best explorer", "art": "unit_explorer",
			"text": "%s%s" % [str(e[0]).capitalize(), _of(e[2], coop)], "detail": "%d tiles uncovered" % int(e[1])})
	var hw_best := 0
	var hw_wave := 0
	var hw_v := -1
	for vid in st.villages.size():
		var hw: Dictionary = st.villages[vid]["hero_waves"]
		for w in hw:
			if int(hw[w]) > hw_best:
				hw_best = int(hw[w])
				hw_wave = int(w)
				hw_v = vid
	if hw_best > 0:
		out.append({"title": "Hero's finest wave", "art": "unit_hero",
			"text": "Wave %d%s" % [hw_wave, _of(hw_v, coop)], "detail": "%d kills by the hero" % hw_best})
	var cc_v := -1
	for vid in st.villages.size():
		if st.value(vid, "huts_burned") > 0.0 and (cc_v < 0 or st.value(vid, "min_huts") < st.value(cc_v, "min_huts")):
			cc_v = vid
	if cc_v >= 0:
		var left := int(st.value(cc_v, "min_huts"))
		out.append({"title": "Closest call", "art": "hut_ruin",
			"text": "%d intact hut%s left%s" % [left, "" if left == 1 else "s", _of(cc_v, coop)],
			"detail": "in wave %d" % int(st.value(cc_v, "min_huts_wave"))})
	else:
		out.append({"title": "Closest call", "art": "hut", "text": "Not a single hut burned", "detail": ""})
	if coop:
		var nb_v := -1
		var nb := 0.0
		for vid in st.villages.size():
			var sent := _sum_prefix(vid, "caravan_sent.") + st.value(vid, "units_sent") * float(Config.STATS["unit_sent_value"])
			if sent > nb:
				nb = sent
				nb_v = vid
		if nb_v >= 0:
			out.append({"title": "Best neighbour", "art": "unit_caravan", "text": str(st.villages[nb_v]["name"]),
				"detail": "%d resources and %d units sent" % [int(_sum_prefix(nb_v, "caravan_sent.")), int(st.value(nb_v, "units_sent"))]})
	return out


## The best entry of award table `table` over every village: [name, amount, village id] (empty: none).
func _top(st: Stats, table: String) -> Array:
	var out: Array = []
	for vid in st.villages.size():
		var t: Dictionary = st.villages[vid][table]
		for who in t:
			if out.is_empty() or float(t[who]) > float(out[1]):
				out = [who, t[who], vid]
	return out


func _of(vid: int, coop: bool) -> String:
	return " (%s)" % game.stats.villages[vid]["name"] if coop and vid >= 0 else ""


func _build_awards() -> void:
	var list := awards()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(flow)
	for a in list:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiTheme.box(Color("1f1611"), Color("4a3a26"), 1, 8, 10))
		box.custom_minimum_size = Vector2(280, 0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_meta("award", a["title"])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(h)
		h.add_child(_icon(a["art"], 64))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(a["title"], 18, UiTheme.GOLD))
		var t := _label(a["text"], 16)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		if a["detail"] != "":
			var d := _label(a["detail"], 14, UiTheme.MUTED)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(d)
		flow.add_child(box)


# --- helpers ------------------------------------------------------------------------------

func _icon(art: String, px: float) -> TextureRect:
	var r := TextureRect.new()
	if art != "" and ResourceLoader.exists("res://art/%s.svg" % art):
		r.texture = Art.tex(art)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _label(text: String, px: int, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b
