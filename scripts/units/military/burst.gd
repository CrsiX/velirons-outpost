extends Node2D
## A short effect drawn in code: an exploding fireball (flash, fire ring and
## sparks), a healing ring, a warp blink, a puff of dark smoke, an acolyte's
## beam of light from straight above, a flash of holy light from a blow, a
## warrior's war cry (red-orange rings rushing out to its reach), a water
## monster's splash as it dives or comes up, leaves flying off a tree that
## wakes up as a wrathwood, a Legion soldier's last breath (release), or
## the crown's curse breaking loose (curse: dark tendrils creeping out and a
## shadow rising, slower), or dust kicked up (a charging rider's hooves, a
## mount falling). Fades out on its own.

const LIFE := 0.55
## Kinds that last longer than LIFE.
const LIVES := {"curse": 2.4}

var kind := "explosion"
var radius := 1.0
var _t := 0.0
var _life := LIFE
var _sparks: Array[Vector2] = []


func setup(p_kind: String, p_radius: float) -> void:
	kind = p_kind
	radius = p_radius
	_life = float(LIVES.get(kind, LIFE))
	z_index = 6
	for i in 14:
		_sparks.append(Vector2.from_angle(TAU * i / 14.0 + randf() * 0.3) * randf_range(0.6, 1.0))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _life:
		queue_free()


func _draw() -> void:
	var k := _t / _life
	var rx := radius * Iso.HALF_W * (0.3 + 0.7 * k)
	var fade := 1.0 - k
	match kind:
		"explosion":
			draw_circle(Vector2.ZERO, rx * 0.55 * (1.0 - k * 0.5), Color(1.0, 0.95, 0.6, 0.8 * fade))
			_ellipse(rx, Color(1.0, 0.5, 0.1, 0.9 * fade), 6.0)
			_ellipse(rx * 0.7, Color(0.9, 0.2, 0.05, 0.7 * fade), 4.0)
			for s in _sparks:
				var p := Vector2(s.x * rx * 1.1, s.y * rx * 0.55 - 20.0 * k)
				draw_circle(p, 3.0 * fade + 1.0, Color(1.0, 0.8, 0.3, fade))
		"heal":
			_ellipse(rx, Color(0.4, 1.0, 0.5, 0.8 * fade), 4.0)
			_ellipse(rx * 0.6, Color(0.7, 1.0, 0.7, 0.5 * fade), 3.0)
			for s in _sparks.slice(0, 6):
				draw_string(ThemeDB.fallback_font, Vector2(s.x * rx * 0.8 - 5.0, s.y * rx * 0.4 - 30.0 * k), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 1.0, 0.6, fade))
		"warp":
			_ellipse(rx * 0.5 * (1.0 - k) + 6.0, Color(0.75, 0.5, 1.0, 0.9 * fade), 4.0)
			_ellipse(rx * 0.3, Color(0.9, 0.8, 1.0, 0.6 * fade), 2.0)
		"smoke":  # a vampire changing shape: dark puffs drifting out and up
			for s in _sparks:
				var p := Vector2(s.x * rx * 0.9, s.y * rx * 0.45 - 18.0 * k)
				draw_circle(p, 7.0 + 6.0 * k, Color(0.16, 0.08, 0.14, 0.7 * fade))
			draw_circle(Vector2.ZERO, rx * 0.35 * (1.0 - k) + 4.0, Color(0.55, 0.1, 0.18, 0.5 * fade))

		"holy_beam":  # a thin golden beam falling from high above, a flash where it lands
			var w := 7.0 * (1.0 - k * 0.6)
			var top := Vector2(0.0, -260.0)
			draw_line(top, Vector2.ZERO, Color(1.0, 0.9, 0.45, 0.35 * fade), w * 2.6)
			draw_line(top, Vector2.ZERO, Color(1.0, 0.97, 0.8, 0.95 * fade), w)
			draw_circle(Vector2.ZERO, 10.0 * (1.0 - k) + 4.0, Color(1.0, 0.98, 0.85, 0.9 * fade))
			_ellipse(rx * 0.6, Color(1.0, 0.85, 0.35, 0.8 * fade), 3.0)
			for s in _sparks.slice(0, 7):
				draw_circle(Vector2(s.x * rx * 0.5, s.y * rx * 0.25 - 26.0 * k), 2.0 * fade + 1.0, Color(1.0, 0.95, 0.6, fade))
		"holy_flash":  # an Inquisitor's blow: a burst of white-gold light and a cross of rays
			draw_circle(Vector2(0.0, -14.0), rx * 0.45 * (1.0 - k * 0.4), Color(1.0, 0.97, 0.75, 0.7 * fade))
			var l := 10.0 + 22.0 * k
			draw_line(Vector2(0.0, -14.0 - l), Vector2(0.0, -14.0 + l), Color(1.0, 0.9, 0.45, fade), 3.0)
			draw_line(Vector2(-l * 0.7, -14.0), Vector2(l * 0.7, -14.0), Color(1.0, 0.9, 0.45, fade), 3.0)
			_ellipse(rx * 0.8, Color(1.0, 0.85, 0.35, 0.6 * fade), 2.5)
		"splash":  # a water monster diving or coming up: a white ring and droplets
			_ellipse(rx, Color(0.85, 0.95, 1.0, 0.8 * fade), 3.0)
			_ellipse(rx * 0.55, Color(0.6, 0.8, 1.0, 0.6 * fade), 2.0)
			for s in _sparks.slice(0, 9):
				var p := Vector2(s.x * rx * 0.8, s.y * rx * 0.4 - 30.0 * sin(k * PI))
				draw_circle(p, 2.5 * fade + 0.8, Color(0.8, 0.93, 1.0, fade))
		"release":  # a Legion soldier falls: a pale breath goes out of it and rises
			for s in _sparks.slice(0, 5):
				var p := Vector2(s.x * rx * 0.35, -26.0 * k - absf(s.y) * 8.0)
				draw_circle(p, 3.5 + 5.0 * k, Color(0.92, 0.95, 1.0, 0.55 * fade))
		"leaves":  # a tree waking up: leaves whirl out and drift down
			for i in _sparks.size():
				var s := _sparks[i]
				var p := Vector2(s.x * rx * 1.2, s.y * rx * 0.6 - 30.0 * sin(k * PI) + 24.0 * k)
				var col := Color(0.24, 0.42, 0.18, fade) if i % 3 else Color(0.55, 0.45, 0.16, fade)
				var a := k * 9.0 + i
				draw_line(p - Vector2.from_angle(a) * 4.0, p + Vector2.from_angle(a) * 4.0, col, 3.5)
		"curse":  # black-violet tendrils creeping out along the floor, a shadow rising
			var reach := radius * Iso.HALF_W * (0.2 + 0.8 * sqrt(k))
			var fade_in := minf(1.0, k * 4.0) * (1.0 - k * k)
			for i in _sparks.size():
				var s := _sparks[i]
				var pts := PackedVector2Array()
				for j in 6:
					var f := float(j) / 5.0
					var wob := sin(f * 6.0 + i + k * 5.0) * 6.0 * f
					pts.append(Vector2(s.x * reach * f + wob, s.y * reach * 0.5 * f))
				draw_polyline(pts, Color(0.16, 0.04, 0.2, 0.85 * fade_in), 4.0 - 2.0 * k, true)
				draw_polyline(pts, Color(0.45, 0.12, 0.55, 0.5 * fade_in), 1.5, true)
			draw_circle(Vector2(0.0, -30.0 * k), 14.0 + 18.0 * k, Color(0.1, 0.02, 0.12, 0.45 * fade_in))
		"war_cry":  # a warrior's shout: rings rushing out to the cry's reach, short strokes on the way
			var reach := radius * Iso.HALF_W * (0.15 + 0.85 * sqrt(k))
			_ellipse(reach, Color(1.0, 0.45, 0.15, 0.85 * fade), 5.0)
			_ellipse(reach * 0.7, Color(1.0, 0.7, 0.3, 0.6 * fade), 3.0)
			for s in _sparks.slice(0, 10):
				var p := Vector2(s.x * reach, s.y * reach * 0.5)
				draw_line(p * 0.82 + Vector2(0, -18), p + Vector2(0, -18), Color(1.0, 0.55, 0.2, fade), 2.5)
		"dust":  # brown-grey puffs low on the ground, drifting out and fading
			for s in _sparks.slice(0, 8):
				var p := Vector2(s.x * rx * 0.9, s.y * rx * 0.4 - 6.0 * k)
				draw_circle(p, 4.0 + 6.0 * k, Color(0.52, 0.44, 0.34, 0.55 * fade))


func _ellipse(rx: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * rx, sin(a) * rx * 0.5))
	draw_polyline(pts, col, w, true)
