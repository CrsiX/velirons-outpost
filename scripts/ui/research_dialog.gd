class_name ResearchDialog
extends PanelContainer
## The town hall's research dialog (docs/advancements-design.md §8.3): a tab per
## advancement category (Config.ADVANCEMENT_CATEGORIES) with a square X, the
## category's tree (icons only; tier 1 the bottom row, tier 2 the top one, a
## dotted line between them, lines going up from what is needed to what needs
## it), and the selected advancement's details with its one button (Research,
## or Cancel under the progress bar of the research under way). The details are
## below the tree in portrait and beside it in landscape. Keys: arrows move
## between nodes, Tab / Shift+Tab switch tabs, Enter presses the button (Esc
## closes it through the HUD's popups).

## A node's badge at most and at least (finger-sized), and the room it takes
## across (its slot) at most and at least.
const NODE := 72.0
const NODE_MIN := 48.0
const SLOT := 116.0
## Landscape: the room across a node takes at most, and between groups (less:
## the tree has the dialog's width there).
const SLOT_LANDSCAPE := 100.0
const GROUP_GAP_LANDSCAPE := 0.1
const SLOT_MIN := 64.0
## Between two groups of the tree that share no line, in slots.
const GROUP_GAP := 0.25
## Between the two rows (the dotted line in its middle), and around the tree.
const ROW_GAP := 64.0
const TREE_PAD := 14.0
## The details' width beside the tree (landscape).
const DETAILS_W := 300.0
## The dialog's width in portrait at most.
const PORTRAIT_W := 560.0
## Tabs show their names while all fit in this much room each, else emblems only.
const TAB_NAMES_MIN := 128.0
const CLOSE_SIDE := 40.0
const SCREEN_MARGIN := 24.0
## A line once its parent is researched, and before; the halo's colour.
const LINE_ON := Color("c9a24a")
const LINE_OFF := Color("5a4a30")
const HALO := Color("ffd27a")
## The halo's pulse (real seconds per beat).
const PULSE := 1.6

const GREY_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g) * 0.7, c.a);
}
"""

var hud: Hud
## The category shown, and the advancement selected in it ("": none).
var tab := "arms"
var selected := ""
## The tab last open in this game (not saved); "" before the first time.
var last_tab := ""
## The nodes of the tab shown: id -> its Button; and their centres in the tree.
var nodes: Dictionary = {}
var centres: Dictionary = {}

var _tabs_box: HBoxContainer
var _tab_buttons: Dictionary = {}  # category -> Button
var _tab_name: Label  # (the selected tab's name, under the bar while the tabs show emblems only)
var _body: BoxContainer
var _tree_scroll: ScrollContainer
var _tree: Control
var _details: VBoxContainer
var _bar: ProgressBar
var _button: Button
var _slot := SLOT
var _node := NODE
var _shown := ""  # what the tree and details were built from (_state)
var _grey: ShaderMaterial


func setup(p_hud: Hud) -> void:
	hud = p_hud
	name = "ResearchDialog"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# (the theme's panel, opaque: it is wide and may cover the dock's text)
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.09, 0.08, 0.07), Color("5a4a30")))
	_grey = ShaderMaterial.new()
	_grey.shader = Shader.new()
	_grey.shader.code = GREY_SHADER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	_tabs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tabs_box)
	for cat: String in Config.ADVANCEMENT_CATEGORIES:
		var b := Button.new()
		b.name = "Tab_" + cat
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(CLOSE_SIDE + 8.0, CLOSE_SIDE)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = Art.tex(Config.advancement_category_icon(cat))
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 26)
		b.add_theme_font_size_override("font_size", 17)
		b.tooltip_text = str(Config.ADVANCEMENT_CATEGORIES[cat])
		b.pressed.connect(func() -> void: show_tab(cat))
		_tabs_box.add_child(b)
		_tab_buttons[cat] = b
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(CLOSE_SIDE, CLOSE_SIDE)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.tooltip_text = "Close"
	close_button.add_child(_rect(Art.tex("icon_no"), CLOSE_SIDE * 0.22))
	close_button.pressed.connect(close)
	head.add_child(close_button)
	_tab_name = _text("", 18, UiTheme.GOLD)
	_tab_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_tab_name)
	v.add_child(UpgradeDialog._rule(false, 0.0, 2))
	_body = HBoxContainer.new()
	v.add_child(_body)
	_tree_scroll = ScrollContainer.new()
	_tree_scroll.name = "TreeScroll"
	_tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tree_scroll.get_h_scroll_bar().custom_minimum_size.y = 16
	_tree = Control.new()
	_tree.name = "Tree"
	_tree.draw.connect(_draw_tree)
	_tree_scroll.add_child(_tree)
	_details = VBoxContainer.new()
	_details.name = "Details"
	_details.add_theme_constant_override("separation", 8)
	_body.add_child(_tree_scroll)
	_body.add_child(_details)
	visible = false
	Layout.changed.connect(func(_p: bool) -> void:
		if visible:
			_shown = ""
			refresh())


## Opens on the research under way (its tab), else on the tab last open in
## this game, else Arms.
func open() -> void:
	var r := _research()
	var cat := last_tab if last_tab != "" else "arms"
	if r.current != "":
		cat = str(Config.ADVANCEMENTS[r.current]["category"])
	visible = true
	hud.move_to_top(self)
	show_tab(cat)


func close() -> void:
	visible = false
	_shown = ""


## Shows category `cat` (the first one with anything offered, if it has
## nothing), selecting the research under way, else its first that can be
## researched, else its first.
func show_tab(cat: String) -> void:
	var shown := shown_tabs()
	if shown.is_empty():
		return
	if not shown.has(cat):
		cat = shown[0]
	tab = cat
	last_tab = cat
	var ids := _research().offered_in(cat)
	selected = ids[0]
	var r := _research()
	if ids.has(r.current):
		selected = r.current
	else:
		for id in ids:
			if r.error(id) == "":
				selected = id
				break
	_shown = ""
	refresh()


## The categories with anything offered in this game, in their order.
func shown_tabs() -> Array[String]:
	var out: Array[String] = []
	for cat: String in Config.ADVANCEMENT_CATEGORIES:
		if not _research().offered_in(cat).is_empty():
			out.append(cat)
	return out


func select(id: String) -> void:
	selected = id
	refresh()


## Follows the research and the resources: rebuilt when anything shown changed.
func refresh() -> void:
	if not visible:
		return
	var state := _state()
	if state == _shown:
		return
	_shown = state
	_rebuild()


## Sized and centred again (the screen changed).
func refit() -> void:
	if visible:
		_shown = ""
		refresh()


func _research() -> Research:
	return hud.game.player_village.research


## (Not the resources themselves: what they change shows in the errors, so a
## trickle of gold doesn't rebuild the buttons under a finger. The Cancel
## button's refund follows in _update_bar.)
func _state() -> String:
	var r := _research()
	var parts: Array[String] = [tab, selected, r.current, str(r.done), str(r.locked), str(Layout.portrait), str(hud.ui_size())]
	for id in r.offered():
		parts.append(r.error(id))
	return "|".join(parts)


# --- the tree's layout -----------------------------------------------------------------------

## Where each of `ids` (one category's) stands: {"pos": {id: Vector2(slot, row)},
## "width": slots}; row 0 is tier 1 (drawn at the bottom), row 1 tier 2. Each
## group of advancements joined by lines gets its own columns, in Config order;
## its wider row takes one slot per node (a pair's halves side by side), the
## other row stands over or under what it is joined to.
static func layout(ids: Array[String], gap := GROUP_GAP) -> Dictionary:
	var order: Array = Config.ADVANCEMENTS.keys()
	var sorted: Array[String] = ids.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return order.find(a) < order.find(b))
	# The groups: joined by a need or an exclusion.
	var group := {}
	for id in sorted:
		group[id] = id
	var find := func(x: String) -> String:
		while group[x] != x:
			x = group[x]
		return x
	for id in sorted:
		var links: Array = Config.ADVANCEMENTS[id].get("needs", []).duplicate()
		if Config.ADVANCEMENTS[id].has("excludes"):
			links.append(Config.ADVANCEMENTS[id]["excludes"])
		for n: String in links:
			if group.has(n):
				group[find.call(n)] = find.call(id)
	var groups: Array[Array] = []
	var index := {}
	for id in sorted:
		var root: String = find.call(id)
		if not index.has(root):
			index[root] = groups.size()
			groups.append([])
		groups[index[root]].append(id)
	var pos := {}
	var x0 := 0.0
	for g in groups:
		var w := _layout_group(g, pos, x0)
		x0 += w + gap
	return {"pos": pos, "width": maxf(x0 - gap, 1.0)}


## Lays out one group from slot `x0`; returns its width in slots.
static func _layout_group(g: Array, pos: Dictionary, x0: float) -> float:
	var rows: Array[Array] = [[], []]
	for id: String in g:
		rows[int(Config.ADVANCEMENTS[id]["tier"]) - 1].append(id)
	var wide := 0 if rows[0].size() >= rows[1].size() else 1
	var other := 1 - wide
	var n := rows[wide].size()
	# The wide row: one slot each, a pair's halves together; tier 2 in the order
	# of what it needs.
	var units := _units(rows[wide])
	if wide == 1:
		var order: Array = Config.ADVANCEMENTS.keys()
		units.sort_custom(func(a: Array, b: Array) -> bool: return _mean_index(a, order) < _mean_index(b, order))
	var x := 0.0
	for u: Array in units:
		for id: String in u:
			pos[id] = Vector2(x0 + x, wide)
			x += 1.0
	# The other row: over or under its links in the wide row, kept apart.
	var others := _units(rows[other])
	var want := {}
	for u: Array in others:
		var xs: Array[float] = []
		for id: String in u:
			for link in _links(id, rows[wide]):
				xs.append((pos[link] as Vector2).x - x0)
		var mid := float(n)
		if not xs.is_empty():
			var sum := 0.0
			for v in xs:
				sum += v
			mid = sum / xs.size()
		want[u] = mid - (u.size() - 1) / 2.0
	others.sort_custom(func(a: Array, b: Array) -> bool: return float(want[a]) < float(want[b]))
	var left := -INF
	var placed: Array[float] = []
	for u: Array in others:
		var start := maxf(float(want[u]), left + 1.0)
		placed.append(start)
		left = start + u.size() - 1
	var width := float(n)
	if not others.is_empty():
		var over := left - (n - 1)
		var shift := minf(maxf(over, 0.0), maxf(placed[0], 0.0))
		for i in others.size():
			var u: Array = others[i]
			for k in u.size():
				pos[u[k]] = Vector2(x0 + placed[i] - shift + k, other)
		width = maxf(width, left - shift + 1.0)
	return width


## `row`'s advancements as units: a pair's halves together, the rest alone.
static func _units(row: Array) -> Array[Array]:
	var out: Array[Array] = []
	var seen := {}
	for id: String in row:
		if seen.has(id):
			continue
		seen[id] = true
		var partner := str(Config.ADVANCEMENTS[id].get("excludes", ""))
		if partner != "" and row.has(partner):
			seen[partner] = true
			out.append([id, partner])
		else:
			out.append([id])
	return out


## What `id` is joined to in `row` (the other tier): what it needs, or what needs it.
static func _links(id: String, row: Array) -> Array[String]:
	var out: Array[String] = []
	for other: String in row:
		if (Config.ADVANCEMENTS[id].get("needs", []) as Array).has(other) or (Config.ADVANCEMENTS[other].get("needs", []) as Array).has(id):
			out.append(other)
	return out


## The mean Config index of what a unit of tier 2 needs (its own, if nothing).
static func _mean_index(u: Array, order: Array) -> float:
	var sum := 0.0
	var count := 0
	for id: String in u:
		for n: String in Config.ADVANCEMENTS[id].get("needs", []):
			sum += order.find(n)
			count += 1
	return sum / count if count > 0 else float(order.find(u[0])) + order.size()


# --- building ------------------------------------------------------------------------------

func _rebuild() -> void:
	var portrait := Layout.portrait
	var room := hud.ui_size() - Vector2(SCREEN_MARGIN, SCREEN_MARGIN) * 2.0
	var shown := shown_tabs()
	# The tabs: names while they fit, else emblems with the selected one's name below.
	var width := minf(PORTRAIT_W, room.x) if portrait else room.x
	var names := width - CLOSE_SIDE - 8.0 >= shown.size() * TAB_NAMES_MIN
	for cat: String in _tab_buttons:
		var b: Button = _tab_buttons[cat]
		b.visible = shown.has(cat)
		b.text = str(Config.ADVANCEMENT_CATEGORIES[cat]) if names else ""
		UiTheme.style_selected(b, cat == tab)
	_tab_name.text = str(Config.ADVANCEMENT_CATEGORIES[tab])
	_tab_name.visible = not names
	# The body: the tree beside the details, or over them.
	if (_body is VBoxContainer) != portrait:
		var want_box: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
		var parent := _body.get_parent()
		var at := _body.get_index()
		for c in _body.get_children():
			_body.remove_child(c)
		parent.remove_child(_body)
		_body.queue_free()
		_body = want_box
		parent.add_child(_body)
		parent.move_child(_body, at)
		_body.add_child(_tree_scroll)
		_body.add_child(_details)
	_body.add_theme_constant_override("separation", 14)
	# The tree's size: the widest tab's, so switching tabs keeps the dialog still.
	var slots := 1.0
	for cat in shown:
		slots = maxf(slots, float(layout(_research().offered_in(cat), _gap())["width"]))
	var tree_room := (width if portrait else room.x - DETAILS_W - 14.0) - 2.0 * TREE_PAD
	_slot = clampf(tree_room / slots, SLOT_MIN, SLOT if portrait else SLOT_LANDSCAPE)
	_node = clampf(_slot - 16.0 - 12.0 * (_slot - SLOT_MIN) / (SLOT - SLOT_MIN), NODE_MIN, NODE)
	_build_tree(slots)
	var tree_size := _tree.custom_minimum_size
	var view_w := minf(tree_size.x, maxf(tree_room + 2.0 * TREE_PAD, _slot + 2.0 * TREE_PAD))
	var scrolls := view_w < tree_size.x - 0.5
	_tree_scroll.custom_minimum_size = Vector2(view_w, tree_size.y + (_tree_scroll.get_h_scroll_bar().custom_minimum_size.y + 4.0 if scrolls else 0.0))
	_tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if scrolls else ScrollContainer.SCROLL_MODE_DISABLED
	_tree_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_FILL
	var details_w := width - 8.0 if portrait else DETAILS_W
	_build_details(details_w)
	var details_h := _details_height(details_w)
	_details.custom_minimum_size = Vector2(details_w, details_h if portrait else maxf(details_h, tree_size.y))
	_fit()
	_fit.call_deferred()  # (again once the wrapped texts are laid out)


func _build_tree(slots: float) -> void:
	for c in _tree.get_children():
		_tree.remove_child(c)
		c.queue_free()
	nodes.clear()
	centres.clear()
	var r := _research()
	var lay := layout(r.offered_in(tab), _gap())
	var tree_w := slots * _slot + 2.0 * TREE_PAD
	var off := (slots - float(lay["width"])) * _slot / 2.0  # (a narrower tab: centred)
	_tree.custom_minimum_size = Vector2(tree_w, 2.0 * _node + ROW_GAP + 2.0 * TREE_PAD + 8.0)
	for id: String in lay["pos"]:
		var p: Vector2 = lay["pos"][id]
		var c := Vector2(TREE_PAD + off + (p.x + 0.5) * _slot, _row_y(int(p.y)))
		centres[id] = c
		var b := _node_button(id)
		b.position = c - b.custom_minimum_size / 2.0
		_tree.add_child(b)
		nodes[id] = b
	_tree.queue_redraw()


## A row's centre: tier 1 (row 0) at the bottom.
func _row_y(row: int) -> float:
	var top := TREE_PAD + 4.0 + _node / 2.0
	return top if row == 1 else top + _node + ROW_GAP


## A node: the badge (grey while not yet or locked), a tick once researched, a
## lock once locked for good, the tab's highlight while selected.
func _node_button(id: String) -> Button:
	var b := Button.new()
	b.name = "Adv_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(_node + 10.0, _node + 10.0)
	b.size = b.custom_minimum_size
	b.tooltip_text = str(Config.ADVANCEMENTS[id]["name"])
	var empty := StyleBoxEmpty.new()
	for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, empty)
	if id == selected:
		var hl := UiTheme.box(Color("4a3b2c"), UiTheme.GOLD, 3, 12, 0)
		b.add_theme_stylebox_override("normal", hl)
		b.add_theme_stylebox_override("hover", hl)
		b.add_theme_stylebox_override("pressed", hl)
	else:
		b.add_theme_stylebox_override("hover", UiTheme.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 12, 0))
	var icon := _rect(Art.tex(Config.advancement_icon(id)), 5.0)
	icon.name = "Icon"
	var state := node_state(id)
	if state == "not_yet" or state == "locked":
		icon.material = _grey
	b.add_child(icon)
	var mark := ""
	if state == "researched":
		mark = "icon_check"
	elif state == "locked":
		mark = "icon_lock"
	if mark != "":
		var m := _rect(Art.tex(mark), 0.0)
		m.name = "Mark"
		m.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		var side := roundf(_node * 0.42)
		m.offset_left = -side
		m.offset_top = -side
		m.offset_right = 0.0
		m.offset_bottom = 0.0
		b.add_child(m)
	b.pressed.connect(func() -> void: select(id))
	return b


## How node `id` looks: "researched", "locked" (for good), "current" (under
## way), "ready" (can be researched, or only lacks the price), "not_yet".
func node_state(id: String) -> String:
	var r := _research()
	if r.has(id):
		return "researched"
	if r.locked.has(id):
		return "locked"
	if r.current == id:
		return "current"
	for c in r.conditions(id):
		if not c[1]:
			return "not_yet"
	return "ready"


## The lines (behind the nodes), the dotted line between the tiers, the halo.
func _draw_tree() -> void:
	var r := _research()
	var y_mid := (_row_y(0) + _row_y(1)) / 2.0
	_tree.draw_dashed_line(Vector2(TREE_PAD * 0.5, y_mid), Vector2(_tree.size.x - TREE_PAD * 0.5, y_mid), Color(UiTheme.MUTED, 0.55), 2.0, 3.0)
	var half := _node / 2.0
	var drawn_pairs := {}
	for id: String in centres:
		var a: Dictionary = Config.ADVANCEMENTS[id]
		var partner := str(a.get("excludes", ""))
		var paired := centres.has(partner)
		# A pair's bar, once for the pair.
		if paired and not drawn_pairs.has(partner):
			drawn_pairs[id] = true
			var p: Vector2 = centres[id]
			var q: Vector2 = centres[partner]
			var lit := r.has(id) or r.has(partner)
			_tree.draw_line(Vector2(minf(p.x, q.x) + half, p.y), Vector2(maxf(p.x, q.x) - half, p.y), LINE_ON if lit else LINE_OFF, 4.0)
		# Its needs: from each group's top (a pair's: the bar's middle) to its
		# bottom (a pair's halves needing the same: one stem to their bar).
		var to: Vector2 = centres[id] + Vector2(0.0, half)
		if paired:
			if drawn_pairs.has(id) and _same_needs(id, partner):
				to = ((centres[id] as Vector2) + (centres[partner] as Vector2)) / 2.0
			elif _same_needs(id, partner):
				continue  # (the partner drew the stem)
		for g in Research.needs_groups(a.get("needs", [])):
			if not centres.has(g[0]):
				continue
			var from: Vector2 = centres[g[0]] - Vector2(0.0, half)
			if g.size() == 2 and centres.has(g[1]):
				from = ((centres[g[0]] as Vector2) + (centres[g[1]] as Vector2)) / 2.0
			var lit := g.any(func(n: String) -> bool: return r.has(n))
			_tree.draw_line(from, to, LINE_ON if lit else LINE_OFF, 3.0, true)
	# The research under way: a golden pulse behind it.
	if centres.has(r.current):
		var c: Vector2 = centres[r.current]
		var t := fmod(Time.get_ticks_msec() / 1000.0, PULSE) / PULSE
		var glow := 0.5 + 0.5 * sin(t * TAU)
		for i in 8:
			var k := float(i) / 8.0
			_tree.draw_circle(c, half + 2.0 + (12.0 + 10.0 * glow) * (1.0 - k), Color(HALO, (0.1 + 0.12 * glow) * (0.3 + k)))


static func _same_needs(a: String, b: String) -> bool:
	var x: Array = Config.ADVANCEMENTS[a].get("needs", []).duplicate()
	var y: Array = Config.ADVANCEMENTS[b].get("needs", []).duplicate()
	x.sort()
	y.sort()
	return x == y


func _build_details(w: float) -> void:
	for c in _details.get_children():
		_details.remove_child(c)
		c.queue_free()
	_bar = null
	_button = null
	if selected != "":
		_fill_details(_details, selected, w, true)


## The details of `id` into `box`: its name, icon, text and conditions, then
## (at the bottom) the reason it can't start, the progress bar of the research
## under way, and the button. `live`: the dialog's own (the button works);
## else for measuring (_details_height), with the longest reason it could show.
func _fill_details(box: VBoxContainer, id: String, w: float, live: bool) -> void:
	var r := _research()
	var a: Dictionary = Config.ADVANCEMENTS[id]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var icon := _rect(Art.tex(Config.advancement_icon(id)), 0.0)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	var title := _wrapped(str(a["name"]), 21, UiTheme.GOLD, w - 66.0)
	title.name = "Name"
	names.add_child(title)
	names.add_child(_text("%s, tier %d" % [Config.ADVANCEMENT_CATEGORIES[a["category"]], int(a["tier"])], 14, UiTheme.MUTED))
	var desc := _wrapped(str(a["desc"]), 16, UiTheme.TEXT, w)
	desc.name = "Desc"
	box.add_child(desc)
	var conds := VBoxContainer.new()
	conds.add_theme_constant_override("separation", 3)
	box.add_child(conds)
	for c in r.conditions(id):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var mark := _rect(Art.tex("icon_check" if c[1] else "icon_no"), 0.0)
		mark.custom_minimum_size = Vector2(16, 16)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		row.add_child(_wrapped(str(c[0]), 15, UiTheme.GOOD if c[1] else UiTheme.MUTED, w - 22.0))
		conds.add_child(row)
	if a.has("excludes"):
		conds.add_child(_wrapped("A final choice: researching it locks %s for good." % Config.ADVANCEMENTS[str(a["excludes"])]["name"], 14, UiTheme.MUTED, w))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	var why := r.error(id) if live and r.current != id and not r.has(id) and not r.locked.has(id) else ""
	var reason := _wrapped(why if live else _longest_reason(id), 14, UiTheme.BAD, w)
	reason.name = "Reason"
	reason.visible = not live or why != ""
	box.add_child(reason)
	var button := Button.new()
	button.name = "Action"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(w, 48)
	button.add_theme_font_size_override("font_size", 17)
	if not live:
		button.text = "Research"
		box.add_child(button)
		return
	_button = button
	if r.current == id:
		_bar = ProgressBar.new()
		_bar.name = "Progress"
		_bar.custom_minimum_size = Vector2(w, 12)
		_bar.show_percentage = false
		_bar.max_value = 1.0
		_bar.step = 0.0
		_bar.add_theme_stylebox_override("background", UiTheme.box(Color("2a2016"), UiTheme.INK, 1, 4, 0))
		_bar.add_theme_stylebox_override("fill", UiTheme.box(Color("e0b84a"), Color("e0b84a"), 0, 4, 0))
		box.add_child(_bar)
		button.pressed.connect(func() -> void: _cancel())
	elif r.has(id):
		button.text = "Researched"
		button.disabled = true
	elif r.locked.has(id):
		button.text = "Locked by %s" % Config.ADVANCEMENTS[str(a["excludes"])]["name"]
		button.disabled = true
	else:
		hud.set_rich_text(button, "Research  (%s, %d s)" % [Config.cost_icons(a["cost"]), int(a["time"])])
		button.disabled = why != ""
		if a.has("excludes") and why == "":
			UiTheme.style_primary(button)
		button.pressed.connect(func() -> void: _start(id))
	box.add_child(button)
	if _bar != null:
		_update_bar()


## The longest reason `id` could be refused with (Research.error): what the
## details keep room for above the button, whatever it says now. (The
## progress bar of the research under way is shorter.)
func _longest_reason(id: String) -> String:
	var r := _research()
	var out := "Not enough gold and food and building material"
	var cands: Array[String] = ["The Town Hall is devastated"]
	for c in r.conditions(id):
		cands.append("Needs: %s" % c[0])
	for other in r.offered():
		cands.append("Already researching %s" % Config.ADVANCEMENTS[other]["name"])
	for t in cands:
		if t.length() > out.length():
			out = t
	return out


## The details' height: the most any advancement offered needs (every tab),
## so the dialog keeps its size while you click through them.
func _details_height(w: float) -> float:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.visible = false
	_tree.add_child(box)  # (in the tree for its fonts; hidden, and _tree lays nothing out)
	var most := 0.0
	for id in _research().offered():
		for c in box.get_children():
			box.remove_child(c)
			c.free()
		_fill_details(box, id, w, false)
		most = maxf(most, box.get_combined_minimum_size().y)
	_tree.remove_child(box)
	box.free()
	return most


## A label wrapping at `w` (its size set now, so its height is right before
## any layout: _details_height measures with it).
func _wrapped(text: String, size: int, color: Color, w: float) -> Label:
	var l := _text(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	l.size.x = w
	return l


## The dialog at its content's size, centred, never more than the screen.
func _fit() -> void:
	if not visible:
		return
	reset_size()
	position = ((hud.ui_size() - size) / 2.0).max(Vector2(8, 8)).floor()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _bar != null:
		_update_bar()
	if centres.has(_research().current):
		_tree.queue_redraw()  # (the halo's pulse)


func _update_bar() -> void:
	var r := _research()
	if r.current == "" or _bar == null:
		return
	_bar.value = r.progress / float(Config.ADVANCEMENTS[r.current]["time"])
	_bar.tooltip_text = "%d s left" % ceili(r.time_left())
	var back := r.cancel_refund()
	var label := "Cancel  (+%s)" % Config.cost_icons(back) if not back.is_empty() else "Cancel"
	if _button != null and _button.get_meta("label", "") != label:
		_button.set_meta("label", label)
		hud.set_rich_text(_button, label)


# --- actions -------------------------------------------------------------------------------

## Starts a research; an exclusive one asks first, saying what it locks for good.
func _start(id: String) -> void:
	var a: Dictionary = Config.ADVANCEMENTS[id]
	if not a.has("excludes"):
		_command("research", {"id": id})
		return
	var other := str(Config.ADVANCEMENTS[str(a["excludes"])]["name"])
	hud.ask("A final choice", UiTheme.GOLD, "Researching %s locks %s for the rest of this game. This can't be undone. Research it?" % [a["name"], other],
		"Research %s  (%s)" % [a["name"], Config.cost_icons(a["cost"])], false, func() -> void:
			if _command("research", {"id": id}):
				hud.close_confirm(),
		func() -> bool: return _research().error(id) == "")


func _cancel() -> void:
	_command("cancel_research")


func _command(type: String, args: Dictionary = {}) -> bool:
	var res := hud.game.command(type, args)
	if not res["ok"]:
		hud.toast(str(res["error"]), UiTheme.BAD)
		return false
	_shown = ""
	refresh()
	hud.refresh_soon()
	return true


## Presses the details' button (Enter), as a click would.
func press_button() -> void:
	if _button != null and not _button.disabled:
		_button.pressed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or hud.top_popup() != self:
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_LEFT:
			_step(Vector2.LEFT)
		KEY_RIGHT:
			_step(Vector2.RIGHT)
		KEY_UP:
			_step(Vector2.UP)
		KEY_DOWN:
			_step(Vector2.DOWN)
		KEY_TAB:
			if not k.is_echo():
				_next_tab(-1 if k.shift_pressed else 1)
		KEY_ENTER, KEY_KP_ENTER:
			if not k.is_echo():
				press_button()
		_:
			return
	get_viewport().set_input_as_handled()


## The gap between the tree's groups: less in landscape.
func _gap() -> float:
	return GROUP_GAP if Layout.portrait else GROUP_GAP_LANDSCAPE


## The arrows: left and right step through the selected one's tier (the next
## one that way, nothing past the end); up and down go to the other tier, to
## the one nearest across (straight over or under it if there is one).
func _step(dir: Vector2) -> void:
	if not centres.has(selected):
		return
	var from: Vector2 = centres[selected]
	var best := ""
	var best_score := INF
	for id: String in centres:
		var d: Vector2 = (centres[id] as Vector2) - from
		var same_row := absf(d.y) < 1.0
		var score := INF
		if dir.y == 0.0 and same_row and d.x * dir.x > 0.0:
			score = absf(d.x)
		elif dir.y != 0.0 and not same_row and d.y * dir.y > 0.0:
			score = absf(d.x)
		if score < best_score:
			best_score = score
			best = id
	if best != "":
		select(best)


func _next_tab(step: int) -> void:
	var shown := shown_tabs()
	var i := shown.find(tab)
	show_tab(shown[posmod(i + step, shown.size())])


# --- small builders ------------------------------------------------------------------------

func _rect(tex: Texture2D, inset: float) -> TextureRect:
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


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
