class_name UpgradeDialog
extends PanelContainer
## The upgrade dialog of a military unit (docs/ui-design.md §7, docs/military-design.md §7):
## one card per upgrade option (MilitaryUnit.upgrade_options), the level-up first,
## then the specialisations, and the ones not reached yet (locked_branches) greyed
## out under a lock. Side by side in landscape, stacked in portrait; a scrollbar
## only when they don't fit. After an upgrade it shows the unit as it is now and
## stays open while something more can be bought at once.

## Card sizes: a landscape card's width and picture; a portrait card's picture.
const CARD_W := 200.0
const PICTURE := 128.0
const PICTURE_PORTRAIT := 96.0
## A portrait card's width at most.
const PORTRAIT_W := 520.0
## Between the numbers on a portrait card's one line: a middle dot.
const FACT_GAP := "  ·  "
## The close button's side (a square beside the title).
const CLOSE_SIDE := 40.0
## Room kept free around the dialog on the screen.
const SCREEN_MARGIN := 24.0
## A co-op client waits this long (real seconds) for the host's answer before
## its buttons work again.
const PENDING_TIME := 2.0

var hud: Hud
## The unit it is open for (null: closed).
var unit: MilitaryUnit
## One per card, in order: {"to": kind, "locked": bool, "cost": {}, "card", "buy",
## "picture", "help": Button, "bar": ProgressBar or null}.
var cards: Array[Dictionary] = []
var title: Label
var scroll: ScrollContainer
var close_button: Button

var _list: BoxContainer
var _shown := ""  # what the cards were built from (_state)
var _pending := 0.0  # Time (s) until which a picked upgrade waits for its result


func setup(p_hud: Hud) -> void:
	hud = p_hud
	name = "UpgradeDialog"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	# The title, and in its row on the right a square X that closes it.
	# (the title row and the rule under it, with as much room above the row as
	# between it and the rule: the panel's top margin)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 0)
	v.add_child(top)
	var head := HBoxContainer.new()
	top.add_child(head)
	title = _text_label("", 22, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	close_button = Button.new()
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(CLOSE_SIDE, CLOSE_SIDE)
	close_button.tooltip_text = "Close"
	close_button.add_child(_full_rect_texture(Art.tex("icon_no"), CLOSE_SIDE * 0.22))
	close_button.pressed.connect(close)
	head.add_child(close_button)
	top.add_child(_rule(false, 0.0, roundi(2.0 * get_theme_stylebox("panel").get_margin(SIDE_TOP))))
	scroll = ScrollContainer.new()
	scroll.follow_focus = false
	v.add_child(scroll)
	# (thick enough to grab with a finger)
	scroll.get_h_scroll_bar().custom_minimum_size.y = 16
	scroll.get_v_scroll_bar().custom_minimum_size.x = 16
	visible = false
	Layout.changed.connect(func(_p: bool) -> void:
		if visible:
			_rebuild())


func open(u: MilitaryUnit) -> void:
	unit = u
	_pending = 0.0
	visible = true
	_rebuild()


func close() -> void:
	visible = false
	unit = null
	_shown = ""


## Follows the unit and the resources: rebuilt when the unit changed (a level,
## a kind, downed or back, its training), the buttons when only the gold did.
## After a picked upgrade went through, it closes if nothing more can be bought.
func refresh() -> void:
	if not visible:
		return
	if not is_instance_valid(unit) or unit.village != hud.game.player_village or (unit.upgrade_options().is_empty() and unit.locked_branches().is_empty()):
		close()
		return
	if _state() != _shown:
		var picked := _pending > 0.0
		_pending = 0.0
		_rebuild()
		if picked and not _anything_buyable():
			close()
		return
	if _pending > 0.0 and _now() > _pending:
		_pending = 0.0
	_refresh_buttons()


## The facts on the card for option `opt` of a unit of `from_kind` at
## `from_level` (0-based): a level-up as the change, a specialisation as its
## level 1. {"stats": its numbers, "food": what it eats ("" if nothing to
## say), "desc": its short description}, all with icon tokens. `factor`: the
## game's upkeep_factor.
static func facts(from_kind: String, from_level: int, opt: Dictionary, factor := 1.0) -> Dictionary:
	var k: String = opt["to"]
	var lv: int = opt["level"]
	var change := k == from_kind
	var st: Dictionary = Config.MILITARY[k]["stats"]
	var stats: Array[String] = []
	var was := from_level
	if st.has("aura"):  # (its damage is only a counter-strike)
		_fact(stats, change, "buffs allies %s {dmg}" if change else "buffs allies +%s {dmg}", 100.0 * Config.unit_stat(k, "aura", lv), 100.0 * Config.unit_stat(k, "aura", was), "%")
	elif st.has("damage"):
		_fact(stats, change, "%s {dmg}/s", _per_s(k, "damage", lv), _per_s(k, "damage", was))
	_fact(stats, change, "%s {hp}", Config.unit_stat(k, "hp", lv), Config.unit_stat(k, "hp", was))
	if st.has("heal"):
		_fact(stats, change, "heals allies %s {hp}/s", _per_s(k, "heal", lv), _per_s(k, "heal", was))
	if st.has("max_summons"):
		_fact(stats, change, "%s summons" if change else "up to %s summons", roundf(Config.unit_stat(k, "max_summons", lv)), roundf(Config.unit_stat(k, "max_summons", was)))
	if st.has("cry"):
		_fact(stats, change, "war cry %s", 100.0 * Config.unit_stat(k, "cry", lv), 100.0 * Config.unit_stat(k, "cry", was), "%")
	if st.has("rage"):
		_fact(stats, change, "rage %s" if change else "rage up to %s", _rage(k, lv), _rage(k, was), "x")
	var food: Array[String] = []
	if factor > 0.0:
		_fact(food, change, "%s {food}/min", Config.unit_upkeep(k, lv) * factor * 60.0, Config.unit_upkeep(k, was) * factor * 60.0)
	var desc: Array[String] = []
	if not change:
		desc.assign(Config.MILITARY[k].get("short_desc", []))
	return {"stats": stats, "food": food[0] if not food.is_empty() else "", "desc": desc}


## The facts one per line (a landscape card's).
static func fact_lines(f: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.assign(f["stats"])
	if f["food"] != "":
		out.append(f["food"])
	out.append_array(f["desc"])
	return out


## One fact: `now`, or (`change`) its difference to `before`, signed; a change
## that rounds to nothing is left out.
static func _fact(out: Array[String], change: bool, fmt: String, now: float, before: float, suffix := "") -> void:
	var x := now - before if change else now
	var t := _num(absf(x))
	if change:
		if t == "0":
			return
		t = ("+" if x >= 0.0 else "-") + t
	out.append(fmt % (t + suffix))


## `key` (damage or heal) per second at `level`.
static func _per_s(kind: String, key: String, level: int) -> float:
	return Config.unit_stat(kind, key, level) / Config.unit_stat(kind, "cooldown", level)


## How much faster rage makes it at most (a berserker).
static func _rage(kind: String, level: int) -> float:
	return 1.0 / maxf(1.0 - Config.unit_stat(kind, "rage", level), 0.05)


## The buy button's words: a level-up "+1 {lvl}  -120 {gold}", a specialisation
## "-100 {gold}", one not reached yet "After level 3".
static func price_text(opt: Dictionary, level_up: bool) -> String:
	if opt.get("locked", false):
		return "After level %d" % Config.BRANCH_MIN_LEVEL
	var parts: PackedStringArray = []
	for res in ["gold", "food", "materials"]:
		if opt["cost"].has(res):
			parts.append("-%d {%s}" % [opt["cost"][res], res])
	return ("+1 {lvl}  " if level_up else "") + "  ".join(parts)


## The title: the unit as it is now ("Archer 5"), and why it can't be upgraded now.
static func title_text(u: MilitaryUnit) -> String:
	var t := "%s %d" % [u.display_name(), u.level + 1]
	if u.is_downed():
		return "Downed: " + t
	return t if u.is_available() else "Unavailable: " + t


# --- building ------------------------------------------------------------------------------

func _rebuild() -> void:
	_shown = _state()
	var keep := Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)
	title.text = title_text(unit)
	if _list:
		scroll.remove_child(_list)
		_list.queue_free()
	cards.clear()
	var portrait := Layout.portrait
	_list = VBoxContainer.new() if portrait else HBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if portrait else ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if portrait else ScrollContainer.SCROLL_MODE_DISABLED
	var opts := unit.upgrade_options()
	for b in unit.locked_branches():
		opts.append({"to": b, "level": 0, "cost": {}, "locked": true})
	var factor := MilitaryUnit.upkeep_factor(hud.game)
	for i in opts.size():
		if i > 0:
			_list.add_child(_rule(not portrait, 6.0 if not portrait else 12.0, 21 if portrait else 49))
		_list.add_child(_card(opts[i], factor, portrait))
	_refresh_buttons()
	_fit()
	_fit.call_deferred()  # (again once the wrapped texts are laid out)
	scroll.set_deferred("scroll_horizontal", int(keep.x))
	scroll.set_deferred("scroll_vertical", int(keep.y))


func _card(opt: Dictionary, factor: float, portrait: bool) -> Control:
	var to: String = opt["to"]
	var locked: bool = opt.get("locked", false)
	var level_up := to == unit.kind
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5 if portrait else 8)
	var name_label := _text_label(str(Config.MILITARY[to]["name"]), 19, UiTheme.GOLD)
	v.add_child(name_label)
	var picture := _picture(to, locked, PICTURE_PORTRAIT if portrait else PICTURE)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := facts(unit.kind, unit.level, opt, factor)
	if portrait:
		for t in _number_lines(f, minf(PORTRAIT_W, _room().x - 40.0) - PICTURE_PORTRAIT - 12.0):
			lines.add_child(_rich_label(t, 16))
		for t: String in f["desc"]:
			lines.add_child(_rich_label(t, 16))
	else:
		for t in fact_lines(f):
			lines.add_child(_rich_label(t, 16))
	if portrait:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(picture)
		row.add_child(lines)
		v.add_child(row)
		var gap := Control.new()  # (the room the cards share: buttons at the bottom)
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(gap)
	else:
		v.custom_minimum_size.x = CARD_W
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(picture)
		v.add_child(lines)
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	v.add_child(buttons)
	var buy := Button.new()
	buy.focus_mode = Control.FOCUS_NONE
	buy.custom_minimum_size = Vector2(0, 48)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_font_size_override("font_size", 17)
	if not level_up and not locked:
		UiTheme.style_primary(buy)
	hud.set_rich_text(buy, price_text(opt, level_up))
	buttons.add_child(buy)
	var help := Button.new()
	help.text = "?"
	help.focus_mode = Control.FOCUS_NONE
	help.custom_minimum_size = Vector2(48, 48)
	help.tooltip_text = "%s in the library" % Config.MILITARY[to]["name"]
	help.pressed.connect(func() -> void: hud.open_library("units"))
	buttons.add_child(help)
	var bar: ProgressBar = null
	if level_up and unit.train_xp > 0.0:
		bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = unit.trained_share()
		bar.tooltip_text = "%d%% trained" % floori(100.0 * unit.trained_share())
		bar.add_theme_stylebox_override("background", UiTheme.box(Color("1a2433"), UiTheme.INK, 1, 3, 0))
		bar.add_theme_stylebox_override("fill", UiTheme.box(Color("4a9ae8"), Color("4a9ae8"), 0, 3, 0))
		v.add_child(bar)
	elif not portrait:
		var slot := Control.new()  # (the bar's room: the buttons stay in line)
		slot.custom_minimum_size.y = 6
		v.add_child(slot)
	var pick := func() -> void: _pick(to if not level_up else "")
	buy.pressed.connect(pick)
	(picture as Button).pressed.connect(pick)
	if locked or not unit.is_available():
		for c: CanvasItem in [name_label, picture, lines]:
			c.modulate = Color(0.55, 0.55, 0.55)
	cards.append({"to": to, "locked": locked, "cost": opt["cost"], "card": v, "buy": buy, "picture": picture, "help": help, "bar": bar})
	return v


## A portrait card's numbers: on one line if they fit in `width`, else the
## food on a line of its own.
func _number_lines(f: Dictionary, width: float) -> Array[String]:
	var stats := FACT_GAP.join(f["stats"])
	var out: Array[String] = []
	if f["food"] == "":
		out.append(stats)
	elif _text_width(stats + FACT_GAP + f["food"], 16) <= width:
		out.append(stats + FACT_GAP + f["food"])
	else:
		out.append_array([stats, f["food"]])
	return out


## How wide `text` (icon tokens drawn as icons) is at font size `size`.
func _text_width(text: String, size: int) -> float:
	var font := get_theme_font("normal_font", "RichTextLabel")
	var px := int(size * 1.15)
	var w := 0.0
	var words := text
	for tok: String in Hud.ICON_ART:
		var n := words.count(tok)
		w += n * (int(px * float(Hud.ICON_SCALE.get(tok, 1.0))) + 2)
		words = words.replace(tok, "")
	return w + font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A thin rule between the cards, or under the title: `vertical` or across,
## shortened by `inset` at both ends, with `room` around it.
static func _rule(vertical: bool, inset: float, room: int) -> Separator:
	var r: Separator
	if vertical:
		r = VSeparator.new()
	else:
		r = HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("5a4a30")
	line.thickness = 1
	line.vertical = vertical
	line.grow_begin = -inset
	line.grow_end = -inset
	r.add_theme_stylebox_override("separator", line)
	r.add_theme_constant_override("separation", room)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The unit's square picture (unit_card_<kind>) on a flat button; a lock over it
## while the specialisation isn't reached yet.
func _picture(kind: String, locked: bool, side: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(side, side)
	b.tooltip_text = Config.MILITARY[kind]["name"]
	b.add_child(_full_rect_texture(Art.tex("unit_card_" + kind), 0.0))
	if locked:
		b.add_child(_full_rect_texture(Art.tex("icon_lock"), side * 0.2))
	return b


func _full_rect_texture(tex: Texture2D, inset: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.offset_left = inset
	r.offset_top = inset
	r.offset_right = -inset
	r.offset_bottom = -inset
	return r


func _text_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A line of a card: icons drawn for their tokens. Never wraps: the cards are
## made wide enough for their facts.
func _rich_label(text: String, size: int) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_color_override("default_color", UiTheme.TEXT)
	rt.text = Hud.icon_bbcode(text, size)
	rt.set_meta("plain", Config.plain_text(text))
	return rt


## Sized and centred again (the screen changed).
func refit() -> void:
	_fit()


## The dialog at its content's size, with a scrollbar where that is more than
## the screen has room for; centred.
func _fit() -> void:
	if not visible or _list == null:
		return
	var room := _room()
	if Layout.portrait:
		_list.custom_minimum_size.x = minf(PORTRAIT_W, room.x - 40.0)
	_same_size()
	var content := _list.get_combined_minimum_size()
	scroll.custom_minimum_size = content
	var over := get_combined_minimum_size() - room
	if Layout.portrait:
		if over.y > 0.0:
			scroll.custom_minimum_size.y = maxf(content.y - over.y, 120.0)
			scroll.custom_minimum_size.x = content.x + scroll.get_v_scroll_bar().custom_minimum_size.x + 4.0
	elif over.x > 0.0:
		scroll.custom_minimum_size.x = maxf(content.x - over.x, CARD_W)
		scroll.custom_minimum_size.y = content.y + scroll.get_h_scroll_bar().custom_minimum_size.y + 4.0
	reset_size()
	position = ((hud.ui_size() - size) / 2.0).max(Vector2(8, 8)).floor()


## The screen's room for the dialog.
func _room() -> Vector2:
	return hud.ui_size() - Vector2(SCREEN_MARGIN, SCREEN_MARGIN) * 2.0


## Every card as big as the biggest one: the longest name or facts set the
## width (landscape) or the height (portrait) for all, the rest is room.
func _same_size() -> void:
	var biggest := Vector2.ZERO
	for c in cards:
		var card: Control = c["card"]
		card.custom_minimum_size = Vector2(0.0 if Layout.portrait else CARD_W, 0.0)
		biggest = biggest.max(card.get_combined_minimum_size())
	for c in cards:
		(c["card"] as Control).custom_minimum_size = biggest


# --- state ---------------------------------------------------------------------------------

## What the cards show, besides the gold.
func _state() -> String:
	if not is_instance_valid(unit):
		return ""
	var kinds: Array = unit.upgrade_options().map(func(o: Dictionary) -> String: return o["to"])
	return "|".join([unit.kind, str(unit.level), str(unit.state), str(snappedf(unit.trained_share(), 0.01)), str(unit.locked_branches()), str(kinds), str(Layout.portrait)])


func _refresh_buttons() -> void:
	var ok_unit := unit.is_available() and _pending <= 0.0
	for c in cards:
		var buy: Button = c["buy"]
		var afford: bool = hud.game.economy.can_afford(c["cost"])
		var on: bool = ok_unit and not c["locked"] and afford
		buy.disabled = not on
		(c["picture"] as Button).disabled = not on
		var rt := buy.get_node_or_null("Rich") as RichTextLabel
		var red: bool = not c["locked"] and not afford
		if rt:
			rt.add_theme_color_override("default_color", UiTheme.BAD if red else UiTheme.TEXT)
		else:
			buy.add_theme_color_override("font_disabled_color", UiTheme.BAD if red else Color("7a6f60"))


func _anything_buyable() -> bool:
	if not unit.is_available():
		return false
	for c in cards:
		if not c["locked"] and hud.game.economy.can_afford(c["cost"]):
			return true
	return false


func _pick(to: String) -> void:
	if not is_instance_valid(unit) or _pending > 0.0:
		return
	var r := hud.game.command("upgrade_unit", {"unit": unit.nid, "to": to})
	if not r["ok"]:
		hud.toast(r["error"], UiTheme.BAD)
		return
	_pending = _now() + PENDING_TIME
	_refresh_buttons()
	refresh()  # (the host has upgraded it already; a co-op client waits for the news)
	hud.refresh_soon()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A number for a card: whole from 10 on, else with one decimal ("4.5", "12").
static func _num(x: float) -> String:
	if absf(x) >= 10.0:
		return str(roundi(x))
	var s := "%.1f" % x
	return s.trim_suffix(".0")
