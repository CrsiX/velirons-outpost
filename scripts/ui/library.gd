class_name Library
extends Control
## The library (docs/tutorial-design.md §4): reference pages in tabs
## (enemies, units, buildings, villagers, hero, places). Every entry is built
## from Config when its tab opens, so the numbers never go out of date. Used
## by the HUD (book icon in the top bar) and the title screen; whoever opens
## it pauses the game if it should (Hud.open_library). It shows
## everything, also what hasn't been found yet.

signal closed

const TABS: Array[String] = ["enemies", "units", "buildings", "villagers", "hero", "places"]
const TAB_NAMES := {"enemies": "Enemies", "units": "Units", "buildings": "Buildings", "villagers": "Villagers", "hero": "Hero", "places": "Places"}
## Unit stats (Config.MILITARY "stats") in words.
const STAT_NAMES := {
	"hp": "HP", "damage": "Damage per hit", "cooldown": "Seconds between attacks",
	"interval": "Seconds between summons", "max_summons": "Elementals at once",
	"summon_hp": "Elemental HP", "summon_damage": "Elemental damage per hit",
	"heal": "Heals per pulse", "radius": "Heal radius out of a tower (tiles)", "splash": "Splash radius (tiles)",
	"slow": "Slowed to (x speed)", "slow_time": "Slow lasts (s)", "push": "Throws back (tiles)",
}
const XP_WORDS := {
	"hit": "per hit in a fight", "build_second": "per second of building",
	"explore": "per exploring step that uncovers land", "corpse": "per corpse picked up",
	"kill": "more for the blow that kills an enemy",
}
const TREASURE_TEXT := {
	"chest": "A chest buried in the wilds, full of gold.",
	"ruins": "Old walls overgrown by the forest: building material and some gold.",
	"shrine": "A holy place: its blessing gives the hero XP, or else heals your units.",
	"standing_stones": "A ring of old stones. Gold, and sometimes a relic.",
	"shipwreck": "A wreck washed up on the beach: gold and food.",
	"dragon_bones": "The bones of a dragon in the ash land: lots of gold, sometimes a relic.",
}
const LAIR_ZONE_WORDS := {"mountain": "in the mountains", "pine": "in the pine forest", "swamp": "in the swamp", "ash": "in the ash land", "steppe": "in the steppe"}

## The tab shown last (kept for the next time it opens, also on the title screen).
static var _last_tab := "enemies"

var tab := ""
var _panel: PanelContainer
var _tab_buttons := {}
var _note: Label
var _scroll: ScrollContainer
var _list: VBoxContainer


func _init() -> void:
	name = "Library"
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
	head.add_child(_icon("icon_book", 40))
	var title := _label("Library", 30, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	var close_button := _button("Close", Vector2(110, 48))
	UiTheme.style_good(close_button)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	v.add_child(tabs)
	for key in TABS:
		var b := _button(TAB_NAMES[key], Vector2(0, 44))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: show_tab(key))
		tabs.add_child(b)
		_tab_buttons[key] = b
	_note = _label("", 15, UiTheme.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	visible = false


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	# Wrapped text is tall before it knows its width (the first open): fit
	# again once it has, so the panel doesn't stay too tall.
	_panel.minimum_size_changed.connect(func() -> void: _fit.call_deferred())
	_fit()


## Shows the dialog on `p_tab` (empty: the tab shown last).
func open(p_tab := "") -> void:
	visible = true
	show_tab(p_tab if p_tab in TABS else _last_tab)
	_fit()
	_fit.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func show_tab(key: String) -> void:
	tab = key
	_last_tab = key
	for k: String in _tab_buttons:
		UiTheme.style_selected(_tab_buttons[k], k == key)
	_note.text = tab_note(key)
	_note.visible = _note.text != ""
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for e in entries(key):
		_list.add_child(_entry(e))
	_scroll.scroll_vertical = 0


## The names on the tab shown (for the tests).
func shown_names() -> Array[String]:
	var out: Array[String] = []
	for c in _list.get_children():
		out.append(str(c.get_meta("entry_name", "")))
	return out


## Up to 900 x 780, a 12 px margin on small screens; centred.
func _fit() -> void:
	var vp := get_viewport_rect().size
	var s := Vector2(minf(vp.x - 24.0, 900.0), minf(vp.y - 24.0, 780.0))
	_panel.size = s
	_panel.position = ((vp - s) / 2.0).floor()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_F11:
		return  # (fullscreen still works)
	if key == KEY_ESCAPE and not event.is_echo():
		close()
	get_viewport().set_input_as_handled()  # (modal: no Space, Tab, Enter behind it)


# --- one entry -------------------------------------------------------------------

## (Nothing in an entry takes the mouse: a drag anywhere scrolls the list.)
func _entry(e: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.box(Color("1f1611"), Color("4a3a26"), 1, 8, 10))
	box.set_meta("entry_name", e["name"])
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	var art := str(e.get("art", ""))
	var pic := _icon(art, 72)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(_label(e["name"], 22, UiTheme.GOLD))
	if str(e.get("text", "")) != "":
		var t := _label(e["text"], 17)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
	var facts: PackedStringArray = e.get("facts", PackedStringArray())
	if not facts.is_empty():
		var f := _label("• " + "\n• ".join(facts), 15, Color("cdbf9f"))
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(f)
	return box


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


# --- the pages, from Config ------------------------------------------------------------

## A line over the entries of `key` ("" for none).
static func tab_note(key: String) -> String:
	match key:
		"enemies":
			return "Numbers for %s difficulty, in wave 1. Enemies get %s %% more HP with every wave." % [Settings.difficulty_name(), _n((Config.WAVE_HP_GROWTH - 1.0) * 100.0)]
		"units":
			return "Values go from level 1 to level %d. On a tower a unit shoots as far as the tower reaches." % Config.MAX_UNIT_LEVEL
	return ""


## The entries of tab `key`: {"name", "art", "text", "facts": PackedStringArray}.
static func entries(key: String) -> Array[Dictionary]:
	match key:
		"enemies":
			return _enemies()
		"units":
			return _units()
		"buildings":
			return _buildings()
		"villagers":
			return _villagers()
		"hero":
			return _hero()
		"places":
			return _places()
	return []


static func _enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: String in Config.ENEMIES:
		var e: Dictionary = Config.ENEMIES[kind]
		if not e.get("library", true):
			continue  # (the smaller slimes: part of the slime's entry)
		var f := PackedStringArray()
		var from := _enemy_from_wave(kind)
		if from > 0:
			f.append("In the waves from wave %d%s" % [from, " (in packs)" if kind == "rat" else ""])
		f.append("HP %s · speed %s tiles/s" % [_n(Config.enemy_stat(kind, "hp")), _n(Config.enemy_stat(kind, "speed"))])
		if e.has("split_into"):
			f.append("Slain, it splits into %d smaller slimes, and each of those into %d more" % [e["split_count"], Config.ENEMIES[e["split_into"]]["split_count"]])
		if float(e["damage"]) > 0.0:
			f.append("Hits for %s every %s s" % [_n(Config.enemy_stat(kind, "damage")), _n(e["attack_cooldown"])])
		else:
			f.append("Doesn't fight in close combat")
		if e.has("attack_category"):
			f.append("Does %s damage" % e["attack_category"])
		if e.get("flying", false):
			f.append("Flies: only ranged attacks and fire elementals reach it")
		for cat: String in e.get("resist", {}):
			f.append("Takes %s x %s damage" % [_n(e["resist"][cat]), cat])
		var loot := "Killed: %d gold" % Config.enemy_stat_int(kind, "gold_on_kill")
		if e.get("corpse", true):
			var c := PackedStringArray()
			for res in ["gold", "food"]:
				var v := Config.enemy_stat_int(kind, res + "_on_collect")
				if v > 0:
					c.append("%d %s" % [v, res])
			loot += "; its corpse, brought home: %s" % (", ".join(c) if not c.is_empty() else "nothing")
		else:
			loot += "; leaves no corpse"
		f.append(loot)
		var lairs := PackedStringArray()
		for art: String in Config.LAIR_THEMES:
			if kind in Config.LAIR_THEMES[art]["kinds"]:
				lairs.append(str(Config.LAIR_THEMES[art]["name"]))
		if not lairs.is_empty():
			f.append("Comes out of monster lairs: %s" % ", ".join(lairs))
		out.append({"name": e.get("library_name", e["name"]), "art": "unit_" + str(e["art"]), "text": e.get("desc", ""), "facts": f})
	return out


## The first wave `kind` marches in (0: only from lairs and camps).
static func _enemy_from_wave(kind: String) -> int:
	if kind == Config.WAVE_FILLER:
		return 1
	if Config.WAVE_MIX.has(kind):
		return int(Config.WAVE_MIX[kind]["from_wave"])
	if kind == "rat":
		return int(Config.RAT_PACKS["from_wave"])
	return 0


static func _units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var top := Config.MAX_UNIT_LEVEL - 1
	for kind in Config.MILITARY_TREE:
		var m: Dictionary = Config.MILITARY[kind]
		var f := PackedStringArray()
		f.append("On towers and in the barracks" if "tower" in m["posts"] else "Barracks only")
		if m.has("branch_of"):
			f.append("A specialisation of the %s: from level %d, for %s" % [Config.MILITARY[m["branch_of"]]["name"], Config.BRANCH_MIN_LEVEL, Config.cost_text(m["branch_cost"])])
		else:
			f.append("Recruit: %s" % Config.cost_text(m["cost"]))
		if Config.LOCKED.has(kind):
			var site: Dictionary = Config.UNLOCK_SITES[Config.LOCKED[kind]]
			f.append("Has to be found first: the hero unlocks it at a %s (from wave %d)" % [str(site["name"]).to_lower(), site["wave"]])
		for stat: String in m["stats"]:
			var stat_name: String = "Seconds between heals" if stat == "cooldown" and m["role"] == "healer" else STAT_NAMES.get(stat, stat)
			f.append("%s: %s" % [stat_name, _span(Config.unit_stat(kind, stat, 0), Config.unit_stat(kind, stat, top))])
		if m.has("range"):
			f.append("Range out of the barracks: %s tiles" % _n(m["range"]))
		if m.has("attack"):
			f.append("Damage type: %s" % Config.ATTACKS[m["attack"]]["category"])
		if m.has("summon"):
			f.append("Summons: %s" % Config.SUMMONS[m["summon"]]["name"])
		f.append("Speed %s tiles/s" % _n(m["speed"]))
		f.append("Level 2 costs %s, or %d hero XP at the training grounds" % [Config.cost_text(Config.unit_upgrade_cost(kind, 0)), int(Config.unit_train_xp(kind, 0))])
		if m.has("branches"):
			var names := PackedStringArray()
			for b: String in m["branches"]:
				names.append(str(Config.MILITARY[b]["name"]))
			f.append("From level %d it can become: %s" % [Config.BRANCH_MIN_LEVEL, ", ".join(names)])
		if m.get("archmage", false):
			f.append("At level %d it can become the %s, for %s" % [Config.ARCHMAGE_LEVEL, Config.CIVILIANS["spatial_archmage"]["name"], Config.cost_text(Config.ARCHMAGE_COST)])
		out.append({"name": m["name"], "art": "unit_" + kind, "text": m["desc"], "facts": f})
	for s: String in Config.SUMMONS:
		var sp: Dictionary = Config.SUMMONS[s]
		var f := PackedStringArray()
		f.append("HP and damage come from the summoner's level (x%s HP, x%s damage)" % [_n(sp["hp"]), _n(sp["damage"])])
		f.append("Speed %s tiles/s" % _n(Config.SUMMON["speed"] * float(sp["speed"])))
		if sp["hover"]:
			f.append("Hovers: it can fight flyers")
		if float(sp["self_damage"]) > 0.0:
			f.append("Burns itself up: loses %s %% of the damage it deals as HP" % _n(float(sp["self_damage"]) * 100.0))
		var by := ""
		for kind: String in Config.MILITARY:
			if Config.MILITARY[kind].get("summon", "") == s:
				by = str(Config.MILITARY[kind]["name"])
		out.append({"name": sp["name"], "art": sp["art"], "text": "Summoned by the %s while enemies are near. It fights close by its post." % by, "facts": f})
	return out


static func _buildings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: String in Config.BUILDINGS:
		var b: Dictionary = Config.BUILDINGS[kind]
		var f := PackedStringArray()
		f.append("Cost: %s · built in %s s · %dx%d" % [Config.cost_text(b["cost"]), _n(b["build_time"]), b["size"], b["size"]])
		match kind:
			"tower":
				f.append_array(_tower_facts("tower"))
			"farm":
				f.append("%s food per second while a farmer works it; stores up to %d" % [_n(Config.FARM_RATE), int(Config.FARM_CAPACITY)])
				f.append("Next to water: +%s %%" % _n(Config.FARM_WATER_BONUS * 100.0))
			"camp":
				f.append("A forester brings %d building material per trip" % Config.FORESTER_MATERIAL_PER_TRIP)
			"barracks":
				for i in Config.BARRACKS_LEVELS.size():
					var l: Dictionary = Config.BARRACKS_LEVELS[i]
					var cost := " (%s)" % Config.cost_text(l["cost"]) if l.has("cost") else ""
					f.append("Level %d%s: %d bench%s, turns out at %s tiles" % [i + 1, cost, l["slots"], "" if int(l["slots"]) == 1 else "es", _n(l["range"])])
			"training":
				f.append("The hero passes on %s XP per second" % _n(Config.HERO["train_rate"]))
			"lightstone":
				f.append("Lights up %s tiles around it" % _n(Config.LIGHTSTONE_SIGHT))
		out.append({"name": b["name"], "art": b["art"], "text": b["desc"], "facts": f})
	out.append({
		"name": "Wall Tower", "art": "wall_tower",
		"text": "The towers at the corners of the village walls. They come with the village; station a unit on them and upgrade them like watchtowers.",
		"facts": _tower_facts("wall_tower"),
	})
	return out


static func _tower_facts(kind: String) -> PackedStringArray:
	var f := PackedStringArray()
	f.append("Range %s tiles" % _n(Config.TOWER_RANGE[kind]))
	for i in range(1, Config.TOWER_LEVELS.size()):
		var l: Dictionary = Config.TOWER_LEVELS[i]
		f.append("Level %d (%s): +%s range" % [i + 1, Config.cost_text(l["cost"]), _n(l["range_bonus"])])
	return f


static func _villagers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for role in Config.CIVILIAN_ORDER:
		var c: Dictionary = Config.CIVILIANS[role]
		var f := PackedStringArray()
		f.append("Recruit: %s" % Config.cost_text(c["cost"]) if c.get("recruit", true) else "Can't be recruited")
		if Config.LOCKED.has(role):
			f.append("Has to be found first: unlocked when someone first walks up to a mine")
		f.append("HP %d, heals %s per second at home · speed %s tiles/s" % [int(Config.CIVILIAN_HP), _n(Config.CIVILIAN_REGEN), _n(c["speed"])])
		f.append("Eats %s food per minute" % _n(Config.FOOD_UPKEEP * 60.0))
		match role:
			"farmer":
				f.append("A farm makes %s food per second while worked" % _n(Config.FARM_RATE))
			"forester":
				f.append("%d building material per trip" % Config.FORESTER_MATERIAL_PER_TRIP)
			"gatherer":
				f.append("Carries up to %d corpses per trip" % Config.GATHERER_CAPACITY)
			"explorer":
				f.append("Uncovers %s tiles around them" % _n(Config.EXPLORER_REVEAL))
			"miner":
				f.append("A mine gives %s gold per second" % _n(Config.MINE_GOLD_RATE))
		out.append({"name": c["name"], "art": "unit_" + role, "text": c["desc"], "facts": f})
	return out


static func _hero() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var h: Dictionary = Config.HERO
	var top := Config.HERO_MAX_LEVEL - 1
	var f := PackedStringArray()
	f.append("HP %s · sword damage %s (level 1 to %d)" % [_span(Config.hero_stat("hp", 0), Config.hero_stat("hp", top)), _span(Config.hero_stat("damage", 0), Config.hero_stat("damage", top)), Config.HERO_MAX_LEVEL])
	f.append("A blow every %s s · speed %s tiles/s" % [_n(h["attack_cooldown"]), _n(h["speed"])])
	f.append("Levels are bought with his own XP: %d XP for level 2, up to %d for level %d" % [Config.hero_level_cost(0), Config.hero_level_cost(top - 1), Config.HERO_MAX_LEVEL])
	f.append("In the village centre he heals %s HP per second" % _n(h["rest_regen"]))
	f.append("Downed: he loses his unspent XP (never his levels) and is back when the wave is over")
	out.append({"name": h["name"], "art": "unit_hero",
		"text": "Your champion: he fights with a sword and can do a little of every villager's job. He eats nothing and needs no hut. Tap him in the top bar to give him orders.",
		"facts": f})
	for i in Hero.MODE_NAMES.size():
		var name := "Mode: %s" % Hero.MODE_NAMES[i]
		if i == Hero.Mode.SUPPORT:
			name += " (co-op)"
		out.append({"name": name, "art": Hero.MODE_ICONS[i], "text": Hud.HERO_MODE_HINTS[i], "facts": PackedStringArray()})
	var xp := PackedStringArray()
	for k: String in Config.HERO_XP_PER_ACTION:
		xp.append("%d XP %s" % [Config.HERO_XP_PER_ACTION[k], XP_WORDS.get(k, k)])
	xp.append("A shrine's blessing: %s XP" % _range(Config.TREASURES["shrine"]["reward"]["hero_xp"]))
	xp.append("Training a unit earns nothing: he passes his XP on")
	out.append({"name": "Earning XP", "art": "icon_xp", "text": "Everything the hero does earns XP, except training.", "facts": xp})
	return out


static func _places() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var scale_top: float = Config.TREASURE_TIER_SCALE[-1]
	for kind: String in Config.TREASURES:
		var t: Dictionary = Config.TREASURES[kind]
		var f := PackedStringArray()
		f.append("Found %s" % _zones_text(t["zones"]))
		var r := PackedStringArray()
		for res: String in t["reward"]:
			r.append("%s %s" % [_range(t["reward"][res]), "XP for the hero" if res == "hero_xp" else res])
		f.append("Holds %s (farther from the village: up to x%s)" % [", ".join(r), _n(scale_top)])
		if t.get("relic", false):
			f.append("May hold a relic instead")
		f.append("The hero loots it in Explore mode: %s s, and the reward is paid when he's home" % _n(t["loot_time"]))
		out.append({"name": t["name"], "art": kind, "text": TREASURE_TEXT.get(kind, ""), "facts": f})
	var relics := PackedStringArray()
	for k: String in Config.RELICS:
		relics.append("%s: %s" % [Config.RELICS[k]["name"], Config.RELICS[k]["desc"]])
	out.append({"name": "Relics", "art": "sack",
		"text": "Rare finds in some treasures and lairs: a small bonus for the village, for good. At most %d on a map." % Config.RELIC_MAX,
		"facts": relics})
	var camp := PackedStringArray()
	for i in Config.CAMP_MONSTERS.size():
		if Config.CAMP_CHANCE[i] <= 0.0:
			continue
		camp.append("Tier %d treasures (%d %% of them): %s" % [i + 1, roundi(Config.CAMP_CHANCE[i] * 100.0), _kind_names(Config.CAMP_MONSTERS[i])])
	camp.append("Its monsters have %d %% more HP than wave enemies" % roundi((Config.CAMP_HP_SCALE - 1.0) * 100.0))
	camp.append("Killed monsters stay dead, so a failed attack isn't wasted")
	out.append({"name": "Monster camp", "art": "camp",
		"text": "Neutral monsters guarding a far treasure. They fight whoever comes within %s tiles and never follow farther than %s. Cleared only on your order: Attack with the hero, from the camp's panel." % [_n(Config.CAMP_AGGRO), _n(Config.CAMP_LEASH)],
		"facts": camp})
	var lair := PackedStringArray()
	lair.append("The first wakes at wave %d, then one more every %d waves" % [Config.LAIR_FROM_WAVE, Config.LAIR_EVERY])
	for zone: String in Config.LAIRS:
		var th: Dictionary = Config.LAIR_THEMES[Config.LAIRS[zone]]
		lair.append("%s, %s: sends %s" % [str(th["name"]).capitalize(), LAIR_ZONE_WORDS.get(zone, zone), _kinds_plural(th["kinds"])])
	var loot := PackedStringArray()
	for res: String in Config.LAIR_LOOT:
		loot.append("%s %s" % [_range(Config.LAIR_LOOT[res]), res])
	lair.append("Cleared: %s (more in later waves), sometimes a relic; then it sleeps %d waves" % [", ".join(loot), Config.LAIR_QUIET_WAVES])
	out.append({"name": "Monster lair", "art": "lair_cave",
		"text": "A den of monsters. Awake, it sends enemies out with every wave, and guards stand by it. The hero can clear it (Attack with the hero).",
		"facts": lair})
	out.append({"name": "Mine", "art": "mine",
		"text": "A gold mine at the edge of the mountains, with a road to it. Whoever walks up to one first unlocks the miner for every village. One miner works it at a time.",
		"facts": PackedStringArray(["%s gold per second while a miner works it" % _n(Config.MINE_GOLD_RATE)])})
	var tower_cost: Dictionary = Config.BUILDINGS["tower"]["cost"]
	var restore := {}
	for res: String in tower_cost:
		restore[res] = roundi(tower_cost[res] * Config.RUIN_RESTORE_SHARE)
	out.append({"name": "Ruined watchtower", "art": "watchtower_ruin",
		"text": "An old watchtower, fallen apart. Only the hero can claim it (Explore mode); then a builder restores it, and it's yours.",
		"facts": PackedStringArray(["Claiming takes %s s" % _n(Config.RUIN_CLAIM_TIME), "Restoring costs %s (half a watchtower)" % Config.cost_text(restore)])})
	for kind: String in Config.UNLOCK_SITES:
		var s: Dictionary = Config.UNLOCK_SITES[kind]
		var art := kind if ResourceLoader.exists("res://art/%s.svg" % kind) else kind + "_ruin"
		out.append({"name": s["name"], "art": art, "text": s["rumour"],
			"facts": PackedStringArray([
				"Awakens at wave %d" % s["wave"],
				"The hero unlocks the %s there for every village (Explore mode, %s s)" % [str(Config.MILITARY[s["unlocks"]]["name"]).to_lower(), _n(s["visit_time"])],
			])})
	return out


static func _zones_text(zones: Array) -> String:
	if zones.is_empty():
		return "anywhere"
	var w := PackedStringArray()
	for z: String in zones:
		match z:
			"beach":
				w.append("on beaches")
			"hills":
				w.append("in the hills")
			_:
				w.append("in the " + str(Config.ZONES[z]["name"]).to_lower() if Config.ZONES.has(z) else z)
	return ", ".join(w)


## Kinds as words: ["goblin", "goblin", "ork"] -> "2 goblins, ork".
static func _kind_names(kinds: Array) -> String:
	var counts := {}
	var order: Array[String] = []
	for k: String in kinds:
		if not counts.has(k):
			order.append(k)
		counts[k] = counts.get(k, 0) + 1
	var w := PackedStringArray()
	for k in order:
		var n: int = counts[k]
		var name := str(Config.ENEMIES[k]["name"]).to_lower()
		w.append(name if n == 1 else "%d %s" % [n, _plural(name)])
	return ", ".join(w)


## Kinds in general: ["ork", "gargoyle"] -> "orks and gargoyles".
static func _kinds_plural(kinds: Array) -> String:
	var w := PackedStringArray()
	for k: String in kinds:
		w.append(_plural(str(Config.ENEMIES[k]["name"]).to_lower()))
	if w.size() < 2:
		return ", ".join(w)
	return ", ".join(w.slice(0, -1)) + " and " + w[-1]


static func _plural(word: String) -> String:
	return word + ("es" if word.ends_with("ch") else "s")


## A number without needless decimals: 1, 0.45, 2.5.
static func _n(v: float) -> String:
	var s := "%.2f" % v
	return s.rstrip("0").rstrip(".")


static func _span(a: float, b: float) -> String:
	return _n(a) if is_equal_approx(a, b) else "%s to %s" % [_n(a), _n(b)]


static func _range(r: Array) -> String:
	return _span(float(r[0]), float(r[1]))
