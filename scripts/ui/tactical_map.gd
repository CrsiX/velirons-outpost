class_name TacticalMap
extends Control
## The tactical map (M, docs/ui-design.md §12): the whole map from above, as
## the same isometric diamond as the game view, with the local village's fog,
## its buildings, found objects, range rings, its people, the enemies it can
## see and HP bars. Only an overview: a click centres the game's view there
## (and closes the map, unless Shift or a long press keeps it open); the
## wheel / pinch / + - zoom it, a drag or WASD pans it. The game runs on.
## The HUD opens and closes it (Hud.open_map / close_map).

signal closed

const C := Config.TACTICAL_MAP
const DRAG_THRESHOLD := 12.0
## Slots in a row: centre to centre, in slot-dot radii.
const SLOT_GAP := 4.0
## The toggles, in their order along the top: layer key -> [icon, tooltip].
const LAYERS := {
	"rings": ["icon_range", "Range rings of manned towers and barracks"],
	"hp": ["icon_hp", "HP bars: the hero, units and damaged buildings"],
	"units": ["icon_army", "Our people: the hero, units, summons, villagers outside"],
	"enemies": ["icon_enemies", "Enemies on watched land"],
}

var game: Game
## The game's view is centred on this world point when the map is clicked
## there (set by `pick`, for tests).
var last_focus := Vector2.INF
var buttons: Dictionary = {}  # layer key -> Button

var _bar: HBoxContainer
var _ground: ImageTexture
var _ground_image: Image
## A felled tree changed a tile since the ground texture was last uploaded.
var _ground_dirty := false
var _fog: ImageTexture
var _fog_image: Image
var _fog_in := 0.0
var _t := 0.0
## The map's scale (screen px per world unit) at zoom 1: the fitted size.
var _fit := 1.0
var _zoom := 1.0
## The world point shown in the middle of the map area.
var _center := Vector2.ZERO
var _pressing := false
var _dragged := false
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _held := 0.0
var _touches: Dictionary = {}  # index -> screen position
var _pinch := 0.0


func setup(p_game: Game) -> void:
	game = p_game
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true  # (zoomed in, the map stays below the top bar)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = C["background"]
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Layout.bleed(bg)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	add_child(_bar)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 10
	_bar.offset_right = -10
	_bar.offset_top = 8
	for key: String in LAYERS:
		var b := _icon_button(LAYERS[key][0], LAYERS[key][1])
		b.toggle_mode = true
		b.button_pressed = bool(Settings.map_layers.get(key, true))
		b.toggled.connect(func(on: bool) -> void: set_layer(key, on))
		_bar.add_child(b)
		buttons[key] = b
		_show_toggle(key)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(gap)
	var close_button := _icon_button("icon_no", "Close the map (M, Esc)")
	close_button.pressed.connect(close)
	_bar.add_child(close_button)
	resized.connect(_refit)
	game.world.tree_felled.connect(_on_tree_felled)


func _icon_button(icon_name: String, tooltip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(48, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = Art.tex(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tooltip
	return b


## Keeps the map below the top bar (`top`: its height in the HUD's units).
func set_top(top: float) -> void:
	offset_top = top


## Opens fitted to the land the village has explored (`open_pad` tiles round
## it), never smaller than the whole map.
func open() -> void:
	_refit()
	_frame_explored()
	_redraw_ground()
	_redraw_fog()
	visible = true
	game.events.debug("open map")


func close() -> void:
	if not visible:
		return
	visible = false
	_pressing = false
	_touches.clear()
	game.events.debug("close map")
	closed.emit()


func is_on(key: String) -> bool:
	return bool(Settings.map_layers.get(key, true))


## Turns a layer on or off; remembered on the device.
func set_layer(key: String, on: bool) -> void:
	Settings.map_layers[key] = on
	Settings.save_player()
	if buttons.has(key):
		(buttons[key] as Button).set_pressed_no_signal(on)
		_show_toggle(key)
	queue_redraw()


func _show_toggle(key: String) -> void:
	(buttons[key] as Button).modulate.a = 1.0 if is_on(key) else 0.45


# --- the view: world <-> screen -------------------------------------------------------

## The area the map is drawn in: under the toggles.
func _area() -> Rect2:
	var top := _bar.position.y + _bar.size.y + 4.0
	return Rect2(Vector2(0, top), Vector2(size.x, maxf(size.y - top, 1.0)))


func _frame_explored() -> void:
	_zoom = 1.0
	_center = _map_center()
	var fog := game.fog
	if fog.disabled:
		return
	var n := game.map.size
	var explored := fog.explored_of[fog.local]
	var lo := Vector2(INF, INF)
	var hi := -lo
	for i in n * n:
		if explored[i] == 1:
			var w := Iso.to_world(Vector2(i % n, i / n))
			lo = lo.min(w)
			hi = hi.max(w)
	if lo.x == INF:
		return
	var pad := float(C["open_pad"]) * Vector2(Iso.HALF_W, Iso.HALF_H) * 2.0
	lo -= pad
	hi += pad
	var a := _area()
	var m: float = C["margin"]
	var s := minf((a.size.x - 2.0 * m) / (hi.x - lo.x), (a.size.y - 2.0 * m) / (hi.y - lo.y))
	_zoom = clampf(s / _fit, float(C["min_zoom"]), float(C["max_zoom"]))
	_center = (lo + hi) / 2.0
	_clamp()


func _map_center() -> Vector2:
	return Vector2(0.0, (game.map.size - 1) * Iso.HALF_H)


func _refit() -> void:
	if game == null:
		return
	var n := float(game.map.size)
	var m: float = C["margin"]
	var a := _area()
	_fit = maxf(minf((a.size.x - 2.0 * m) / (n * Iso.HALF_W * 2.0), (a.size.y - 2.0 * m) / (n * Iso.HALF_H * 2.0)), 0.0001)
	_clamp()
	queue_redraw()


func _scale() -> float:
	return _fit * _zoom


func to_screen(world: Vector2) -> Vector2:
	return _area().get_center() + (world - _center) * _scale()


func to_world(screen: Vector2) -> Vector2:
	return _center + (screen - _area().get_center()) / _scale()


func _grid_screen(g: Vector2) -> Vector2:
	return to_screen(Iso.to_world(g))


func zoom_at(screen: Vector2, factor: float) -> void:
	var before := to_world(screen)
	_zoom = clampf(_zoom * factor, float(C["min_zoom"]), float(C["max_zoom"]))
	_center += before - to_world(screen)
	_clamp()
	queue_redraw()


## + / -: zoom about the middle of the map area.
func zoom_key(factor: float) -> void:
	zoom_at(_area().get_center(), factor)


func pan(screen_delta: Vector2) -> void:
	_center -= screen_delta / _scale()
	_clamp()
	queue_redraw()


func _clamp() -> void:
	var n := float(game.map.size)
	var half := Vector2(n * Iso.HALF_W, n * Iso.HALF_H)
	var c := _map_center()
	_center = _center.clamp(c - half, c + half)


## A click or tap at `screen`: the game's view is centred there; unless
## `stay`, the map closes and what stands on that tile is selected (its panel
## would close the map anyway).
func pick(screen: Vector2, stay: bool) -> void:
	var g := Iso.to_grid(to_world(screen))
	var n := float(game.map.size)
	g = g.clamp(Vector2(-0.5, -0.5), Vector2(n - 0.5, n - 0.5))
	last_focus = Iso.to_world(g)
	game.events.debug("map: view to %s" % str(Vector2i(g.round())))
	game.camera.focus(last_focus)
	if stay:
		return
	close()
	var b := building_on(Vector2i(g.round()))
	if b != null:
		game.select(b)


## What a click on tile `t` selects: the building whose footprint covers it
## (a post rather than the unit on it), else a map object the village has
## found there; null on land it hasn't explored.
func building_on(t: Vector2i) -> Building:
	if not _explored(t):
		return null
	var b := game.map.building_at(t) as Building
	if b != null and not (b is MapObject) and is_instance_valid(b):
		return b
	for o in game.world.map_objects:
		if is_instance_valid(o) and o.is_found_by(game.player_village) and t in o.tiles():
			return o
	return null


# --- input ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() == 2:
			_pinch = _spread()
			_dragged = true  # (a pinch is never a tap)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			var d := _spread()
			if _pinch > 0.0 and d > 0.0:
				var pts := _touches.values()
				zoom_at(((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0, d / _pinch)
			_pinch = d
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressing = true
					_dragged = false
					_held = 0.0
					_press_pos = mb.position
					_last_pos = mb.position
				elif _pressing:
					_pressing = false
					if not _dragged:
						pick(mb.position, mb.shift_pressed)
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoom_at(mb.position, 1.12)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom_at(mb.position, 1.0 / 1.12)
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if not _dragged and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragged = true
		# By position, never by `relative` (Firefox's touch; see CameraController).
		if _dragged and _touches.size() < 2:
			pan(mm.position - _last_pos)
		_last_pos = mm.position
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.position, mg.factor)
	elif event is InputEventPanGesture:
		pan(-(event as InputEventPanGesture).delta * 12.0)
	else:
		return
	accept_event()


func _spread() -> float:
	var pts := _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _process(delta: float) -> void:
	if not visible or game == null:
		return
	var real := delta / maxf(Engine.time_scale, 0.001)
	_t += real
	# A long press: the view goes there, the map stays.
	if _pressing and not _dragged:
		_held += real
		if _held >= float(C["long_press"]):
			_pressing = false
			pick(_press_pos, true)
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		pan(-dir.normalized() * float(C["key_pan"]) * real)
	if _ground_dirty:
		_ground_dirty = false
		_ground.update(_ground_image)
	_fog_in -= real
	if _fog_in <= 0.0:
		_redraw_fog()
	queue_redraw()


# --- drawing --------------------------------------------------------------------------

## The whole ground, when the map opens.
func _redraw_ground() -> void:
	var m := game.map
	_ground_image = Image.create(m.size, m.size, false, Image.FORMAT_RGBA8)
	for y in m.size:
		for x in m.size:
			var t := Vector2i(x, y)
			_ground_image.set_pixelv(t, MapPlan.ground_color(m, t))
	_ground = ImageTexture.create_from_image(_ground_image)
	_ground_dirty = false


## A felled tree: its tile is meadow now (uploaded with the next frame the map shows).
func _on_tree_felled(t: Vector2i) -> void:
	if _ground_image != null:
		_ground_image.set_pixelv(t, MapPlan.ground_color(game.map, t))
		_ground_dirty = true


func _redraw_fog() -> void:
	_fog_in = float(C["fog_refresh"])
	var fog := game.fog
	var n := game.map.size
	var data := PackedByteArray()
	data.resize(n * n * 2)
	if not fog.disabled:
		var vid := fog.local
		var explored := fog.explored_of[vid]
		var watched := fog.watched_of[vid]
		var dim := int(255.0 * float(C["fog_dim"]))
		for i in n * n:
			data[i * 2 + 1] = 255 if explored[i] == 0 else (0 if watched[i] == 1 else dim)
	if _fog_image == null or _fog_image.get_width() != n:
		_fog_image = Image.create_from_data(n, n, false, Image.FORMAT_LA8, data)
		_fog = ImageTexture.create_from_image(_fog_image)
	else:
		_fog_image.set_data(n, n, false, Image.FORMAT_LA8, data)
		_fog.update(_fog_image)


## Can the local village see tile `t` (explored / watched)?
func _explored(t: Vector2i) -> bool:
	return game.fog.disabled or game.fog.is_explored_by(game.fog.local, t)


func _watched(t: Vector2i) -> bool:
	return game.fog.disabled or game.fog.is_watched_by(game.fog.local, t)


func _draw() -> void:
	if game == null or _ground == null:
		return
	var s := _scale()
	var a := _area()
	# Texture pixel (x, y) is tile (x, y), its centre at grid (x, y): the
	# texture's corner sits at grid (-0.5, -0.5).
	var origin := a.get_center() - _center * s + Iso.to_world(Vector2(-0.5, -0.5)) * s
	var tr := Transform2D(Vector2(Iso.HALF_W, Iso.HALF_H) * s, Vector2(-Iso.HALF_W, Iso.HALF_H) * s, origin)
	draw_set_transform_matrix(tr)
	draw_texture(_ground, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_buildings()
	_draw_objects()
	draw_set_transform_matrix(tr)
	draw_texture(_fog, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if is_on("rings"):
		_draw_rings()
	if is_on("units"):
		_draw_people()
	if is_on("enemies"):
		_draw_enemies()
	if is_on("hp"):
		_draw_hp_bars()


func _tile_poly(t: Vector2i, grow := 1.0) -> PackedVector2Array:
	var pts := Iso.diamond(t, 1, grow)
	for i in pts.size():
		pts[i] = to_screen(pts[i])
	return pts


func _dot_radius(factor := 1.0) -> float:
	return float(C["dot"]) * factor * clampf(sqrt(_zoom), 1.0, 2.5)


func _building_color(b: Building) -> Color:
	var colors: Dictionary = C["colors"]
	var col: Color = colors.get(b.kind, colors["other"])
	if b.village != null and b.village != game.player_village:
		col = b.village.color.darkened(0.2)
	if (b is Hut and (b as Hut).ruined) or b.devastated or b.village == null:
		col = C["devastated"]
	elif not b.complete:
		col.a = float(C["site_alpha"])
	return col


func _draw_buildings() -> void:
	for b in game.world.buildings:
		if b is MapObject or not is_instance_valid(b) or not _explored(b.tile):
			continue
		var col := _building_color(b)
		for t in b.tiles():
			draw_colored_polygon(_tile_poly(t), col)
		if not (b is StaticPiece):  # (walls and gates join up; everything else gets an edge)
			draw_polyline(_footprint_outline(b), Color(col.darkened(0.6), 1.0), 1.0, true)
		if b is MilitaryPost and b.working() and b.village != null:
			_draw_slots(b as MilitaryPost)


## One dot per slot (a tower's post, each bench of barracks), in a row across
## the building: filled while its unit sits there, an empty ring while the
## slot is free or its unit is away (marching, out on a sortie, downed).
func _draw_slots(b: MilitaryPost) -> void:
	var ours := b.village == game.player_village
	if not ours and not _watched(b.tile):
		return
	var col: Color = C["slot"] if ours else C["ally_unit"]
	var r := _dot_radius(0.8)
	for i in b.capacity():
		var p := _slot_point(b, i)
		if _seated(b, i):
			draw_circle(p, r, col)
		else:
			draw_arc(p, r, 0.0, TAU, 16, Color(col, 0.7), 1.2, true)


## Where slot `i` of `b` is drawn: a row across its middle.
func _slot_point(b: MilitaryPost, i: int) -> Vector2:
	var n := b.capacity()
	return _footprint_center(b) + Vector2((i - (n - 1) / 2.0) * _dot_radius(0.8) * SLOT_GAP, 0.0)


## Is slot `i`'s unit sitting there now?
func _seated(b: MilitaryPost, i: int) -> bool:
	var u: MilitaryUnit = b.slots[i] if i < b.slots.size() else null
	return u != null and u.state == MilitaryUnit.State.STATIONED and not u.out


func _footprint_center(b: Building) -> Vector2:
	return to_screen(Building.anchor_world(b.tile, b.size))


func _footprint_outline(b: Building) -> PackedVector2Array:
	var t := b.tiles()
	var lo := Vector2(t[0]) - Vector2(0.5, 0.5)
	var hi := Vector2(t[-1]) + Vector2(0.5, 0.5)
	return PackedVector2Array([_grid_screen(lo), _grid_screen(Vector2(hi.x, lo.y)), _grid_screen(hi), _grid_screen(Vector2(lo.x, hi.y)), _grid_screen(lo)])


func _draw_objects() -> void:
	for o in game.world.map_objects:
		if not is_instance_valid(o) or not o.is_found_by(game.player_village):
			continue
		var col: Color = MapPlan.OBJECT_COLORS.get(String(o.data.get("kind", "")), Color.MAGENTA)
		for t in o.tiles():
			draw_colored_polygon(_tile_poly(t), col)
		if o is MonsterLair and (o as MonsterLair).awake:
			var c := _footprint_center(o)
			draw_arc(c, _dot_radius(2.2), 0.0, TAU, 24, C["enemy"], 2.0, true)


func _draw_rings() -> void:
	for b in game.world.military_posts():
		if b.village != game.player_village or not b.working() or (b as MilitaryPost).units().is_empty():
			continue
		var center := Vector2.ZERO
		var r := 0.0
		if b is Tower:
			center = Vector2(b.tile)
			r = (b as Tower).range_tiles()
		elif b is Barracks:
			center = (b as Barracks).act_center()
			r = (b as Barracks).activation_range()
		if r <= 0.0:
			continue
		var pts := Iso.ellipse(center, r, 48)
		for i in pts.size():
			pts[i] = to_screen(pts[i])
		pts.append(pts[0])
		draw_polyline(pts, C["ring"], 1.5, true)


func _ours(n: Node) -> bool:
	return "village" in n and n.get("village") == game.player_village


## Villagers outside the walls, units and summons out in the field, heroes:
## ours, and (co-op) other villages' where the village watches the land, in
## their own colours.
func _draw_people() -> void:
	var r := _dot_radius()
	for n in get_tree().get_nodes_in_group("villagers"):
		var c := n as Civilian
		if c == null or c is Hero or c.dead or not c.visible or c.at_home or c.inside_walls():
			continue
		if _ours(c):
			draw_circle(_grid_screen(c.grid_pos), r * 0.8, C["villager"])
		elif _watched(c.current_tile()):
			draw_circle(_grid_screen(c.grid_pos), r * 0.8, C["ally_villager"])
	for group in ["field_units", "summons"]:
		for n in get_tree().get_nodes_in_group(group):
			var u := n as Unit
			if u == null or not u.visible or ("dead" in u and u.get("dead")):
				continue
			if _ours(u):
				draw_circle(_grid_screen(u.grid_pos), r, C["unit"])
			elif _watched(u.current_tile()):
				draw_circle(_grid_screen(u.grid_pos), r, C["ally_unit"])
	for n in get_tree().get_nodes_in_group("heroes"):
		var h := n as Hero
		if h == null or h.village == game.player_village or h.dead or not _watched(h.current_tile()):
			continue
		_hero_mark(_grid_screen(h.grid_pos), C["ally_unit"])
	var mine: Hero = game.hero
	if mine != null:
		_hero_mark(_grid_screen(mine.grid_pos), C["downed"] if mine.dead else C["hero"])


func _hero_mark(p: Vector2, col: Color) -> void:
	var r := _dot_radius()
	draw_circle(p, r * 1.6, col)
	draw_arc(p, r * 2.4, 0.0, TAU, 24, col, 2.0, true)


## The enemies the map shows: alive, in sight, on land the village watches.
func shown_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and not e.dead and e.visible and e.dive != Enemy.Dive.DOWN and _watched(e.current_tile()):
			out.append(e)
	return out


func _draw_enemies() -> void:
	var r := _dot_radius()
	for e in shown_enemies():
		var p := _grid_screen(e.grid_pos)
		if e.given_name != "":
			draw_circle(p, r * 1.5, C["enemy"])
			draw_arc(p, r * 2.3, 0.0, TAU, 24, C["named"], 2.0, true)
		else:
			draw_circle(p, r, C["flyer"] if e.flies() else C["enemy"])
	var pulse := 0.55 + 0.35 * sin(_t * 4.0)
	var warn: Color = C["warning"]
	warn.a = pulse
	for spot: Vector2 in game.world.warnings.spots:
		var p := to_screen(spot)
		draw_arc(p, r * 2.0, 0.0, TAU, 24, warn, 2.5, true)
		draw_circle(p, r * 0.8, warn)


func _draw_hp_bars() -> void:
	for b in game.world.buildings:
		if b is MapObject or b is Hut or b.village != game.player_village or not b.complete:
			continue
		var share := 0.0 if b.devastated else b.hp_share()
		if share < 1.0:
			_hp_bar(_footprint_center(b), share)
		elif b is MilitaryPost and b.working():
			# A hurt unit sitting on its post or bench: over its slot's dot
			# (out on a sortie, its own dot carries its bar).
			var post := b as MilitaryPost
			for i in post.capacity():
				var u: MilitaryUnit = post.slots[i] if i < post.slots.size() else null
				if _seated(post, i) and u.hp < u.max_hp():
					_hp_bar(_slot_point(post, i), u.hp / u.max_hp(), _dot_radius(0.8) * (SLOT_GAP - 0.6) / _hp_width(), 1.3)
	if is_on("units"):
		for n in get_tree().get_nodes_in_group("field_units"):
			var so := n as Soldier
			if so != null and so.visible and so.unit != null and _ours(so) and so.unit.hp < so.unit.max_hp():
				_hp_bar(_grid_screen(so.grid_pos), so.unit.hp / so.unit.max_hp())
		var h: Hero = game.hero
		if h != null and not h.dead and h.hp < h.max_hp:
			_hp_bar(_grid_screen(h.grid_pos), h.hp / h.max_hp)


func _hp_width() -> float:
	return (C["hp_bar"] as Vector2).x * clampf(sqrt(_zoom), 1.0, 2.0)


## A small bar above `p`, green / yellow / red like the hero's (`width`: a
## share of the usual width; `lift`: how far above, in dot radii).
func _hp_bar(p: Vector2, share: float, width := 1.0, lift := 2.6) -> void:
	share = clampf(share, 0.0, 1.0)
	var bar_size := Vector2(_hp_width() * width, (C["hp_bar"] as Vector2).y * clampf(sqrt(_zoom), 1.0, 2.0))
	var rect := Rect2(p - Vector2(bar_size.x / 2.0, bar_size.y + _dot_radius(lift)), bar_size)
	draw_rect(rect.grow(1.0), Color("15110d"))
	if share > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * share, rect.size.y)), Hud.hero_hp_color(share))
