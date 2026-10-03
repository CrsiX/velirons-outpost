class_name UnitFx
extends Node2D
## Effects on a unit's sprite, drawn as a child of it (in its pixels;
## docs/acolyte-design.md): an acolyte's soft pulsing light behind the figure
## (Config.MILITARY "glow"), and the small holy halo over the head of anyone
## in a High Priest's aura (Combat.holy_bonus). Also swaps in a unit's
## casting frame for a moment ("cast_art").

enum Kind { GLOW, HALO }

const CAST_TIME := 0.35
const HALO_COLOR := Color(1.0, 0.9, 0.5)

var kind := Kind.GLOW
var color := Color.WHITE
## HALO: whose blessing to check, and where it stands (grid).
var game: Game
var where: Callable
var _t := 0.0
var _flare := 0.0
var _scan := 0.0


## Shows `unit_kind`'s figure on `s`, with its glow if it has one.
static func show_unit(s: Sprite2D, unit_kind: String) -> void:
	Art.apply(s, "unit_" + unit_kind)
	s.set_meta("unit_kind", unit_kind)
	var g := s.get_node_or_null("Glow") as UnitFx
	var col: String = Config.MILITARY.get(unit_kind, {}).get("glow", "")
	if col == "":
		if g:
			s.remove_child(g)
			g.queue_free()
		return
	if g == null:
		g = UnitFx.new()
		g.name = "Glow"
		g.show_behind_parent = true
		s.add_child(g)
	g.color = Color(col)


## An attack: the casting frame for a moment, and the glow flares.
static func cast(s: Sprite2D, unit_kind: String) -> void:
	var g := s.get_node_or_null("Glow") as UnitFx
	if g:
		g._flare = 1.0
	var art: String = Config.MILITARY.get(unit_kind, {}).get("cast_art", "")
	if art == "":
		return
	Art.apply(s, art)
	s.create_tween().tween_interval(CAST_TIME).finished.connect(func() -> void:
		if s.get_meta("unit_kind", "") == unit_kind:
			Art.apply(s, "unit_" + unit_kind))


## A halo on `s` that shows while `p_where` (grid) is in a High Priest's aura.
static func add_halo(s: Sprite2D, p_game: Game, p_where: Callable) -> UnitFx:
	var h := UnitFx.new()
	h.name = "Halo"
	h.kind = Kind.HALO
	h.game = p_game
	h.where = p_where
	h.visible = false
	s.add_child(h)
	return h


func _process(delta: float) -> void:
	_t += delta
	if kind == Kind.GLOW:
		_flare = maxf(0.0, _flare - delta * 2.5)
		queue_redraw()
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.2
		visible = is_instance_valid(game) and Combat.holy_bonus(game, where.call()) > 0.0


func _draw() -> void:
	var s := get_parent() as Sprite2D
	if s == null or s.texture == null:
		return
	var r := s.get_rect()
	if kind == Kind.GLOW:
		var k := 0.5 + 0.5 * sin(_t * 2.6) + _flare
		var c := Vector2(0.0, r.position.y + r.size.y * 0.5)
		var rad := r.size.x * 0.5 * (0.9 + 0.12 * k)
		for i in 4:
			draw_circle(c, rad * (1.0 - 0.22 * i), Color(color, 0.07 + 0.05 * k))
		return
	# A still, thin ring of light just over the head (sprite pixels: 2 x art units).
	var y := maxf(r.position.y + 4.0, -92.0)
	_ring(Vector2(0.0, y), 11.0, Color(HALO_COLOR, 0.35), 5.0)
	_ring(Vector2(0.0, y), 11.0, Color(1.0, 0.97, 0.8, 0.95), 2.0)


func _ring(c: Vector2, rx: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * rx * 0.32))
	draw_polyline(pts, col, w, true)
