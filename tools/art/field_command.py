"""The Field Command: the town hall of a wood village (docs/village-design.md §3a),
an improvised war tent. It shares the hall's canvas, tower post and bench
(HALL_DECK, HALL_TOWER_BACK, HALL_BENCH), so a unit stands where it would on
any hall. field_commands() saves it under the wood hall's names."""

import math
import random

from .buildings import (
    HALL_BODY, HALL_DECK, HALL_PALETTES, HALL_PODIUM, HALL_TOWER_BACK, hall_bench, hall_extent, hall_extra,
)
from .core import Art, _glow, GLOW, GOLD, INK, IRON, P, ROPE, shade, TH, WOOD, WOOD_D, WOOD_L

# Patched canvas: sun-bleached sheets, a dyed one, a hide.
CANVAS, CANVAS_L, CANVAS_D = "#c2ad86", "#a8946f", "#867352"
DYED, DYED_D = "#8a6a44", "#6a5034"
HIDE, HIDE_D = "#9a7350", "#6e4f35"
PLANK_T = "#8a6844"
INSIDE = "#2a1f16"

WALL = 22  # the tent's canvas walls
RIDGE = 64  # its ridge
END = 0.45  # the rounded ends' depth along the ridge (gx); across it they are the tent's half width
GORES = 9  # sheets in each rounded end
# The lookout platform stands this much further back (both grid axes) than
# the hall's podium, its deck lower by as much as that raises it on screen:
# deck and unit are where they are on every hall (HALL_DECK, HALL_TOWER_BACK).
PLATFORM_BACK = 0.5
PLATFORM_C = -HALL_TOWER_BACK - PLATFORM_BACK


def _deck_z(level):
    return HALL_DECK[level] - 2 * PLATFORM_BACK * TH


def _mix(c0, c1, f):
    a = [int(c0[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * f) for x, y in zip(a, b))


def _outline():
    """The tent's foot round, as sheets: (p0, p1, normal, ridge point(s), kind),
    p0 and p1 grid points on its foot, the normal outwards. The ends are half
    ellipses, each sheet running up to the ridge's end like a pavilion's."""
    x0, x1, y0, y1 = HALL_BODY
    ym, rd = (y0 + y1) / 2, (y1 - y0) / 2
    xa, xb = x0 + END, x1 - END
    out = []
    for k in range(3):  # the front, three sheets
        g0, g1 = xa + (xb - xa) * k / 3, xa + (xb - xa) * (k + 1) / 3
        out.append(((g0, y1), (g1, y1), (0.0, 1.0), [(g1, ym), (g0, ym)], "front%d" % k))
    for cx, t0 in ((xb, 90.0), (xa, -90.0)):  # the right end, then the left, each round from front to back
        for k in range(GORES):
            ta, tb = math.radians(t0 - 180.0 * k / GORES), math.radians(t0 - 180.0 * (k + 1) / GORES)
            tm = (ta + tb) / 2
            n = (math.cos(tm) / END, math.sin(tm) / rd)
            ln = math.hypot(*n)
            out.append(((cx + END * math.cos(ta), ym + rd * math.sin(ta)), (cx + END * math.cos(tb), ym + rd * math.sin(tb)),
                        (n[0] / ln, n[1] / ln), [(cx, ym)], "%s%d" % ("right" if cx == xb else "left", k)))
        if cx == xb:
            out.append(((xb, y0), (xa, y0), (0.0, -1.0), [(xa, ym), (xb, ym)], "back"))
    return out


def _lit(n):
    """0 (facing right, in shade) to 1 (facing left, lit)."""
    return max(0.0, min(1.0, 0.5 + 0.5 * (n[1] - n[0]) / math.sqrt(2)))


def _seen(n):
    return n[0] + n[1] > 0.05


# Patched sheets: which sheet of the roof (or wall) is a dyed one or a hide.
ROOF_PATCHES = {"front1": DYED, "right3": HIDE, "left1": DYED}
WALL_PATCHES = {"right5": HIDE_D, "front0": DYED}


def _tent(a, level):
    """The commander's tent: a long ridge tent with rounded ends, its walls and
    roof in sheets of patched canvas, a scalloped valance, poles at the eave."""
    _, _, y0, y1 = HALL_BODY
    ym = (y0 + y1) / 2
    sheets = sorted(_outline(), key=lambda sh: sh[0][0] + sh[0][1] + sh[1][0] + sh[1][1])
    walls, roofs = [], []
    for p0, p1, n, ridge, name in sheets:
        f = _lit(n)
        walls.append(([P(p0[0], p0[1], 0), P(p1[0], p1[1], 0), P(p1[0], p1[1], WALL), P(p0[0], p0[1], WALL)],
                      WALL_PATCHES.get(name, _mix(CANVAS_D, CANVAS_L, f))))
        base = ROOF_PATCHES.get(name, CANVAS)
        roofs.append(([P(p0[0], p0[1], WALL), P(p1[0], p1[1], WALL)] + [P(r[0], r[1], RIDGE) for r in ridge],
                      _mix(shade(base, 0.72), base, f)))
    for layer in (walls, roofs):  # an ink underlay, so only the outline shows; then the sheets, seamed
        for pts, _ in layer:
            a.poly(pts, INK, INK, 2.8)
        for pts, col in layer:
            a.poly(pts, col, shade(col, 0.8), 0.9)
    for p0, p1, n, _, name in sheets:  # the valance along the eave, poles a little proud of it
        if not _seen(n):
            continue
        k = max(1, round(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / 0.08))
        for i in range(k):
            ga = (p0[0] + (p1[0] - p0[0]) * i / k, p0[1] + (p1[1] - p0[1]) * i / k)
            gb = (p0[0] + (p1[0] - p0[0]) * (i + 1) / k, p0[1] + (p1[1] - p0[1]) * (i + 1) / k)
            gm = ((ga[0] + gb[0]) / 2, (ga[1] + gb[1]) / 2)
            a.poly([P(ga[0], ga[1], WALL), P(gb[0], gb[1], WALL), P(gm[0], gm[1], WALL - 4)], CANVAS_D, INK, 0.7)
        if name.startswith("front") or int(name[-1]) % 3 == 0:
            a.line([P(p0[0], p0[1], 0), P(p0[0], p0[1], WALL + 5)], WOOD_D, 2.2)
    x0, x1, _, _ = HALL_BODY
    xa, xb = x0 + END, x1 - END
    a.line([P(xa, ym, RIDGE), P(xb, ym, RIDGE)], WOOD_D, 3)  # the ridge pole, its two poles poking through
    for g in (xa, xb):
        a.line([P(g, ym, RIDGE - 2), P(g, ym, RIDGE + 7)], WOOD_D, 2.6)
    if level < 2:  # the village's pennant on the front pole
        x, y = P(xb, ym, RIDGE + 7)
        a.line([(x, y), (x, y - 18)], INK, 2.2)
        a.cloth([(x, y - 18), (x + 14, y - 15), (x, y - 11)], sw=0.8)


def _platform(a, level):
    """The lookout behind the ridge: four lashed log legs, a brace, a ladder, a plank deck."""
    c, s, dz = PLATFORM_C, HALL_PODIUM + 0.04, _deck_z(level)
    lg = s - 0.03
    for gx, gy in ((c - lg, c - lg), (c + lg, c - lg), (c - lg, c + lg), (c + lg, c + lg)):  # back legs first
        a.box(gx - 0.025, gx + 0.025, gy - 0.025, gy + 0.025, 0, dz, WOOD_L, WOOD, WOOD_D, sw=1.1)
    for z in (dz - 26, dz - 10):  # the brace's lashed crossbars on the two faces in front
        a.line([P(c - lg, c + lg, z), P(c + lg, c + lg, z), P(c + lg, c - lg, z)], WOOD_D, 2.2)
    a.line([P(c - lg, c + lg, dz - 26), P(c + lg, c + lg, dz - 10)], WOOD_D, 1.8)
    a.line([P(c + lg, c + lg, dz - 26), P(c + lg, c - lg, dz - 10)], WOOD_D, 1.8)
    for g in (c - s, c + s):  # the beams' ends under the deck
        a.line([P(c + s, g, dz - 3), P(c + s + 0.06, g, dz - 3)], WOOD_D, 2.6)
        a.line([P(g, c + s, dz - 3), P(g, c + s + 0.06, dz - 3)], WOOD_D, 2.6)
    for gy in (c - 0.06, c + 0.06):  # the ladder up its right side
        a.line([P(c + s + 0.25, gy, 0), P(c + s + 0.02, gy, dz + 6)], WOOD, 1.8)
    for z in range(8, int(dz), 8):
        t = z / (dz + 6)
        gx = c + s + 0.25 - 0.23 * t
        a.line([P(gx, c - 0.06, z), P(gx, c + 0.06, z)], WOOD_D, 1.4)
    a.box(c - s, c + s, c - s, c + s, dz, dz + 4, PLANK_T, WOOD_L, WOOD)
    for k in (1, 2, 3):
        g = c - s + 2 * s * k / 4
        a.line([P(g, c - s, dz + 4), P(g, c + s, dz + 4)], WOOD_D, 0.9, opacity=0.7)
    _rail(a, False, dz, level)
    bx, by = P(c - s + 0.06, c - s + 0.06, dz + 4)  # a pole at the back with the village's pennon
    a.line([(bx, by), (bx, by - 36)], INK, 3)
    a.cloth([(bx, by - 36), (bx + 18, by - 32), (bx + 12, by - 28), (bx + 18, by - 24), (bx, by - 22)])
    if level >= 3:
        x, y = P(c + 0.12, c - 0.12, dz + 4)
        _fire(a, x, y, 0.8)


def _rail(a, front, deck, level):
    """The deck's parapet: lashed posts and a plank rail, shields hung on the
    front. `front`: the part drawn over the unit (the hall's front merlons)."""
    c = PLATFORM_C
    s = HALL_PODIUM + 0.03
    z = deck + 4
    if front:
        corners = [(c - s, c + s), (c + s, c + s), (c + s, c - s)]
        rails = [[P(c - s, c + s, z + 9), P(c + s, c + s, z + 9), P(c + s, c - s, z + 9)]]
    else:
        corners = [(c - s, c - s), (c + s, c - s), (c - s, c + s)]
        rails = [[P(c - s, c + s, z + 9), P(c - s, c - s, z + 9), P(c + s, c - s, z + 9)]]
    for gx, gy in corners:
        x, y = P(gx, gy, z)
        a.line([(x, y), (x, y - 13)], INK, 3.2)
        a.line([(x, y), (x, y - 13)], WOOD, 1.8)
    for pts in rails:
        a.line(pts, INK, 3.4)
        a.line(pts, WOOD_L, 2)
    if front:
        pal = HALL_PALETTES["wood"]
        for gx, gy in ((c - 0.02, c + s), (c + s, c - 0.02)):
            x, y = P(gx, gy, z + 7)
            a.ellipse(x, y, 5, 5.5, pal["accent"] if gx < c else WOOD_L, INK, 1.1)
            a.ellipse(x, y, 1.6, 1.8, IRON)
            if level >= 3:
                a.ellipse(x, y, 5, 5.5, "none", pal["metal"], 1.0)


def _fire(a, x, y, scale=1.0):
    """Flames in a pot at (x, y), glowing."""
    _glow(a, x, y - 12 * scale, 16 * scale, 11 * scale, GLOW, 0.35)
    a.poly([(x - 5 * scale, y - 5 * scale), (x + 5 * scale, y - 5 * scale), (x + 3 * scale, y), (x - 3 * scale, y)], IRON, INK, 1)
    a.poly([(x - 3.5 * scale, y - 5 * scale), (x - 1 * scale, y - 13 * scale), (x + 0.5 * scale, y - 9 * scale),
            (x + 2 * scale, y - 16 * scale), (x + 3.5 * scale, y - 5 * scale)], GLOW, "#b8401e", 1)


def _brazier(a, gx, gy, kind):
    """An improvised brazier: an iron pot on stacked stones, or on a tripod."""
    x, y = P(gx, gy)
    if kind == "stones":
        for dx, dy in ((-4, 0), (4, 0), (0, -3)):
            a.ellipse(x + dx, y + dy - 2, 4, 3, "#6b665e", INK, 0.9)
        _fire(a, x, y - 7)
    else:
        for dx in (-6, 0, 6):
            a.line([(x + dx, y + (2 if dx == 0 else 0)), (x, y - 14)], INK, 1.8)
        _fire(a, x, y - 12)


def _porch(a):
    """The door peak: a small gabled tent before the door, its flap tied open on
    a lantern."""
    _, _, _, y1 = HALL_BODY
    px0, px1, pm = -0.2, 0.2, 0.0
    yb, py1 = y1 - 0.05, y1 + 0.26
    w, pr = 18, 40
    a.poly([P(px1, py1, 0), P(px1, yb, 0), P(px1, yb, w), P(px1, py1, w)], CANVAS_D)
    a.poly([P(pm, yb, pr), P(pm, py1, pr), P(px1 + 0.02, py1, w - 1), P(px1 + 0.02, yb, w - 1)], CANVAS_L)
    a.poly([P(px0, py1, 0), P(px1, py1, 0), P(px1, py1, w), P(pm, py1, pr), P(px0, py1, w)], CANVAS)
    a.poly([P(pm - 0.1, py1, 0), P(pm + 0.1, py1, 0), P(pm, py1, 31)], INSIDE)  # the opening
    x, y = P(pm, py1, 0)
    _glow(a, x, y - 12, 12, 10, GLOW, 0.5)
    a.ellipse(x + 3, y - 18, 2.2, 2.6, GLOW, INK, 0.7)  # the lantern
    a.poly([P(pm - 0.1, py1 + 0.01, 0), P(pm - 0.19, py1 + 0.01, 3), P(pm - 0.05, py1 + 0.01, 25)], CANVAS_D, INK, 1.1)  # the flap, tied back
    fx, fy = P(pm - 0.12, py1 + 0.01, 12)
    a.ellipse(fx, fy, 1.8, 1.4, ROPE, INK, 0.6)
    a.line([P(px0 - 0.02, py1, w - 1), P(pm, py1, pr + 1), P(px1 + 0.02, py1, w - 1)], WOOD_D, 2.4)


def _standard(a):
    """The village's standard on a pole beside the door (cloth: the village's colour)."""
    _, _, _, y1 = HALL_BODY
    x, y = P(-0.36, y1 + 0.16)
    a.line([(x, y), (x, y - 72)], INK, 3.4)
    a.line([(x, y), (x, y - 72)], WOOD_D, 1.8)
    a.line([(x - 3, y - 68), (x + 17, y - 68)], WOOD_D, 2)
    a.cloth([(x + 1, y - 68), (x + 16, y - 68), (x + 16, y - 42), (x + 8.5, y - 47), (x + 1, y - 42)])
    a.cloth([(x + 12, y - 68), (x + 16, y - 68), (x + 16, y - 42), (x + 12, y - 45)], dark=True)
    a.ellipse(x + 8.5, y - 57, 2.6, 2.6, GOLD, INK, 0.8)


def _pennon_pole(a, gx, gy, h=54):
    x, y = P(gx, gy)
    a.line([(x, y), (x, y - h)], INK, 2.6)
    a.line([(x, y), (x, y - h)], WOOD_D, 1.3)
    a.cloth([(x, y - h), (x + 15, y - h + 3), (x + 9, y - h + 6), (x + 15, y - h + 9), (x, y - h + 11)], sw=0.9)


def _crates(a, gx, gy):
    a.box(gx - 0.07, gx + 0.07, gy - 0.07, gy + 0.07, 0, 10, PLANK_T, WOOD_L, WOOD, sw=1.1)
    a.box(gx - 0.05, gx + 0.05, gy - 0.04, gy + 0.06, 10, 18, PLANK_T, WOOD_L, WOOD, sw=1.1)
    x, y = P(gx + 0.15, gy + 0.05)
    a.poly([(x - 5, y), (x - 5, y - 11), (x + 5, y - 11), (x + 5, y)], WOOD, INK, 1.1)  # a barrel
    a.ellipse(x, y - 11, 5, 2, WOOD_L, INK, 0.9)
    a.line([(x - 5, y - 4), (x + 5, y - 4)], IRON, 1.2)


def field_command(level=1, front=False):
    """The Field Command at `level` (1 to 3); `front`: the deck's front rail, drawn over the unit."""
    a = Art()
    if front:
        a._track(hall_extent())
        if level >= 2:
            _rail(a, True, _deck_z(level), level)
        return a
    s = 0.98
    a.shadow(110, 52, cy=8)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#5a4a36", INK, 1.0, opacity=0.6)  # the trodden ground
    if level >= 2:
        _platform(a, level)
    _tent(a, level)
    _porch(a)
    _standard(a)
    _brazier(a, -0.72, 0.86, "stones")
    _brazier(a, 0.94, -0.52, "tripod")
    if level >= 2:
        _brazier(a, 0.5, 0.9, "stones")
    _crates(a, 0.86, -0.2)
    if level >= 3:
        hall_bench(a, HALL_PALETTES["wood"]["accent"], HALL_PALETTES["wood"]["metal"])
        x0, x1, y0, y1 = HALL_BODY
        _pennon_pole(a, x0, y1 + 0.03)
        _pennon_pole(a, x1 + 0.03, y0)
    return a


def field_command_ruin():
    """A devastated Field Command: the canvas down and burnt, the lookout's
    legs charred and fallen, braziers tipped over, smoke."""
    rng = random.Random(5311)
    a = Art()
    x0, x1, y0, y1 = HALL_BODY
    s = 0.98
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#2d2a26", INK, 1.0, opacity=0.55)
    c = -HALL_TOWER_BACK
    # the fallen canvas, sagging over what is under it
    a.poly([P(x0, y0 + 0.1, 0), P(x1 - 0.1, y0, 0), P(x1, -0.1, 6), P(x1 + 0.04, y1, 0), P(x0 + 0.1, y1 + 0.04, 0), P(x0 - 0.04, 0.0, 4)], CANVAS_D)
    a.poly([P(x0 + 0.05, -0.2, 4), P(c, c, 22), P(x1, -0.1, 6), P(x1 + 0.04, y1, 0), P(x0 + 0.1, y1 + 0.04, 0)], CANVAS_L)
    a.poly([P(-0.3, 0.1, 8), P(c, c, 22), P(0.3, -0.2, 10), P(0.4, 0.3, 2)], DYED_D, INK, 1.0)
    for _ in range(9):  # scorch holes
        gx, gy = rng.uniform(x0 + 0.2, x1 - 0.1), rng.uniform(-0.3, y1 - 0.05)
        x, y = P(gx, gy, 5)
        r = rng.uniform(3, 7)
        a.poly([(x + r * math.cos(k * 1.05) * (0.7 + 0.3 * (k % 2)), y + r * 0.5 * math.sin(k * 1.05)) for k in range(6)], "#1e1813", "#3a2a1c", 0.8)
    # the tent poles' charred stumps, the lookout's legs fallen across the canvas
    for gx, gy, h in [(-0.41, -0.15, 30), (0.25, -0.15, 20)]:
        a.box(gx - 0.03, gx + 0.03, gy - 0.03, gy + 0.03, 0, h, "#2a1e15", "#3a2a1c", "#22180f", sw=1.1)
        x, y = P(gx, gy, h)
        a.ellipse(x, y, 2.4, 1.6, "#c04a1e", opacity=0.8)
    for (ga, gb, za, zb) in [((-0.75, -0.1), (0.0, -0.75), 6, 4), ((-0.6, -0.45), (0.25, 0.15), 10, 3), ((-0.25, 0.3), (0.45, -0.05), 4, 2)]:
        p0, p1 = P(ga[0], ga[1], za), P(gb[0], gb[1], zb)
        a.line([p0, p1], INK, 6)
        a.line([p0, p1], "#2a1e15", 4)
    # a tipped brazier, its coals spilt
    x, y = P(-0.72, 0.86)
    a.poly([(x - 6, y - 2), (x + 3, y - 8), (x + 7, y - 3), (x - 2, y + 2)], IRON, INK, 1)
    for k in range(4):
        a.ellipse(x + 8 + k * 3, y + 1 + (k % 2), 1.6, 1.1, "#c04a1e", opacity=0.9)
    x, y = P(0.94, -0.52)
    for dx in (-8, 2, 9):
        a.line([(x + dx, y), (x + dx * 0.4 + 4, y - 6)], INK, 1.8)
    for _ in range(3):
        x, y = P(rng.uniform(-0.5, 0.4), rng.uniform(-0.5, 0.2), 30)
        a.ellipse(x, y - 10, 7, 10, "#8a8580", opacity=0.25)  # smoke
    return a


def field_commands():
    """The Field Command's three levels on the hall's one canvas, the deck's
    front rails and the ruin, under the wood hall's names (Config.piece_art)."""
    for lvl in (1, 2, 3):
        name = "wood_town_hall" if lvl == 1 else "wood_town_hall_%d" % lvl
        fc = field_command(lvl)
        fc._track(hall_extent())
        fc.save(name, extra=hall_extra(lvl))
        if lvl >= 2:
            fr = field_command(lvl, front=True)
            fr.pts = fc.pts[:]
            fr.save("wood_town_hall_front_%d" % lvl)
    ru = field_command_ruin()
    ru._track(hall_extent())
    ru.save("wood_town_hall_ruin")
