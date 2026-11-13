"""Village pieces in limestone."""

import math
import random

from ..core import (
    Art, BRASS, CRIMSON_D, diamond, GLOW, GOLD, hanging_banner, INK, IRON, IRON_L,
    _merlon_spots, _opening, P,
)


# Limestone (Coast): sea-worn ashlar of pale grey-cream blocks (cooler and greyer
# than sandstone) on a sloped, battered foot crusted with barnacles and weed;
# dark rain streaks under the copings, orange lichen; merlons with saddle-backed
# caps, round arches. Level 2 crimson cloth and arrow loops, level 3 gilt, ship's
# lanterns and a beacon fire on the towers.

LIME_T, LIME_L, LIME_R = "#d6d1c1", "#bdb7a5", "#928c7c"
LIME_J, LIME_JR = "#857f6f", "#6c6759"  # joints on the front and side faces
LIME_STREAK = "#4e4a40"
LICHEN, LICHEN_L = "#cf8a24", "#e6b445"
WEED = "#3b5a34"


def _lime_q(face, at):
    return (lambda g, z: P(g, at, z)) if face == "front" else (lambda g, z: P(at, g, z))


def _lime_ashlar(a, rng, face, at, g0, g1, z0, z1, rows):
    """Courses of big blocks of uneven height, staggered joints."""
    q = _lime_q(face, at)
    col = LIME_J if face == "front" else LIME_JR
    cuts = [z0] + sorted(z0 + (z1 - z0) * (r + rng.uniform(-0.15, 0.15)) / rows for r in range(1, rows)) + [z1]
    for r in range(rows):
        za, zb = cuts[r], cuts[r + 1]
        if r > 0:
            a.line([q(g0, za), q(g1, za)], col, 1)
        u = g0 + rng.uniform(0.08, 0.22)
        while u < g1 - 0.07:
            a.line([q(u, za), q(u, zb)], col, 1)
            u += rng.uniform(0.2, 0.32)


def _streaks(a, rng, face, at, g0, g1, z_top, n, length=(10, 20)):
    """Dark rain streaks running down a face from z_top, tapering."""
    q = _lime_q(face, at)
    for _ in range(n):
        g = rng.uniform(g0 + 0.03, g1 - 0.03)
        w = rng.uniform(0.012, 0.025)
        ln = rng.uniform(*length)
        a.poly([q(g - w, z_top), q(g + w, z_top), q(g + w * 0.3, z_top - ln), q(g, z_top - ln - 3), q(g - w * 0.5, z_top - ln * 0.7)], LIME_STREAK, stroke=None, opacity=0.28)


def _lichen(a, rng, face, at, g0, g1, z0, z1, n):
    """Orange lichen in little clusters."""
    q = _lime_q(face, at)
    for _ in range(n):
        x, y = q(rng.uniform(g0 + 0.03, g1 - 0.03), rng.uniform(z0, z1))
        for _ in range(3):
            a.ellipse(x + rng.uniform(-2.2, 2.2), y + rng.uniform(-1.2, 1.2), rng.uniform(0.9, 1.6), rng.uniform(0.7, 1.1), rng.choice([LICHEN, LICHEN_L]), opacity=0.9)


def _battered_foot(a, rng, x0, x1, y0, y1, zb, out=0.06):
    """A sloped foot round a box (wider at the ground), barnacles and weed on it."""
    fx0, fx1, fy1, fy0 = x0 - out, x1 + out, y1 + out, y0 - out
    a.poly([P(fx0, fy1, 0), P(fx1, fy1, 0), P(x1, y1, zb), P(x0, y1, zb)], LIME_L, INK, 1.3)
    a.poly([P(fx1, fy1, 0), P(fx1, fy0, 0), P(x1, y0, zb), P(x1, y1, zb)], LIME_R, INK, 1.3)
    n = max(4, int((x1 - x0) / 0.06))
    pts = [P(fx0, fy1, 0), P(fx1, fy1, 0)]
    for k in range(n, -1, -1):  # weed along the waterline, ragged
        t = k / n
        pts.append(P(fx0 + (fx1 - fx0) * t, fy1 - out * 0.35, 2.4 + (1.6 if k % 2 else 0)))
    a.poly(pts, WEED, stroke=None, opacity=0.7)
    a.poly([P(fx1, fy1, 0), P(fx1, fy0, 0), P(fx1 - out * 0.35, fy0, 2.6), P(fx1 - out * 0.35, fy1, 3.6)], "#2c4528", stroke=None, opacity=0.7)
    for _ in range(max(2, n // 3)):  # barnacles in little clusters, low on the foot
        t = rng.uniform(0.08, 0.92)
        for _ in range(3):
            h = rng.uniform(0.3, 0.5)
            x, y = P(fx0 + (fx1 - fx0) * t, fy1 - out * h, zb * h)
            x += rng.uniform(-2.5, 2.5)
            a.ellipse(x, y, 0.9, 0.7, "#d8d2c2", "#5e5a4e", 0.4)


def _saddle(a, gx, gy, kx, ky, z, rise=4.0, gold=False):
    """A saddle-backed coping stone on top of a merlon: its ridge along gx."""
    ym = gy + ky / 2
    o = 0.012
    a.poly([P(gx - o, ym, z + rise), P(gx + kx + o, ym, z + rise), P(gx + kx + o, gy + ky + o, z), P(gx - o, gy + ky + o, z)], LIME_T, INK, 1)
    a.poly([P(gx + kx + o, gy - o, z), P(gx + kx + o, ym, z + rise), P(gx + kx + o, gy + ky + o, z)], LIME_R, INK, 1)
    if gold:
        a.line([P(gx - o, ym, z + rise), P(gx + kx + o, ym, z + rise)], GOLD, 1.6)


def _ledge(a, x0, x1, y0, y1, z0, z1, o=0.02):
    """A course standing out from a body's two visible faces (no top over the body)."""
    a.poly([P(x0 - o, y1 + o, z0), P(x1 + o, y1 + o, z0), P(x1 + o, y1 + o, z1), P(x0 - o, y1 + o, z1)], LIME_L, INK, 1.1)
    a.poly([P(x1 + o, y1 + o, z0), P(x1 + o, y0 - o, z0), P(x1 + o, y0 - o, z1), P(x1 + o, y1 + o, z1)], LIME_R, INK, 1.1)
    a.poly([P(x0 - o, y1 + o, z1), P(x1 + o, y1 + o, z1), P(x1 + o, y0 - o, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)], LIME_T, INK, 0.9)


def _lime_merlon(a, gx, gy, kx, ky, z, hgt=7, gold=False):
    a.box(gx, gx + kx, gy, gy + ky, z, z + hgt, LIME_T, LIME_L, LIME_R, sw=1.2)
    _saddle(a, gx, gy, kx, ky, z + hgt, gold=gold)


def _arrow_loop(a, face, at, g, z, hgt=12):
    """A cross-shaped arrow loop on a face."""
    q = _lime_q(face, at)
    a.poly([q(g - 0.012, z), q(g + 0.012, z), q(g + 0.012, z + hgt), q(g - 0.012, z + hgt)], "#1c1a16", INK, 0.6)
    a.poly([q(g - 0.04, z + hgt * 0.55), q(g + 0.04, z + hgt * 0.55), q(g + 0.04, z + hgt * 0.7), q(g - 0.04, z + hgt * 0.7)], "#1c1a16", INK, 0.6)


def _ship_lantern(a, x, y):
    """A brass ship's lantern hung from an iron bracket, its top at screen (x, y)."""
    a.ellipse(x, y + 6, 8, 8, GLOW, opacity=0.3)
    a.line([(x, y - 1), (x, y + 1.5)], INK, 1)
    a.poly([(x - 2.6, y + 1.5), (x + 2.6, y + 1.5), (x + 2.6, y + 9), (x - 2.6, y + 9)], GLOW, BRASS, 1.1)
    a.poly([(x - 3.4, y + 1.5), (x, y - 1.5), (x + 3.4, y + 1.5)], BRASS, INK, 0.8)


def lime_wall(level=1):
    rng = random.Random(1500 + level)
    a = Art()
    x0, x1, y0, y1, h = -0.5, 0.5, -0.13, 0.13, 32
    _battered_foot(a, rng, x0, x1, y0, y1, 8)
    a.box(x0, x1, y0, y1, 8, h, LIME_T, LIME_L, LIME_R)
    _lime_ashlar(a, rng, "front", y1, x0, x1, 8, h, 3)
    _streaks(a, rng, "front", y1, x0, x1, h, 4)
    _lichen(a, rng, "front", y1, x0, x1, 10, h - 3, 3)
    a.box(x0, x1, y0 - 0.02, y1 + 0.02, h, h + 3, LIME_T, LIME_L, LIME_R, sw=1.2)  # the coping
    if level >= 2:
        _arrow_loop(a, "front", y1, -0.3, 14)
        _arrow_loop(a, "front", y1, 0.32, 14)
        hanging_banner(a, ("left", y1), -0.07, 0.07, h - 2, 10)
    for gx in (-0.44, -0.1, 0.24):
        _lime_merlon(a, gx, y0, 0.18, y1 - y0, h + 3, gold=level >= 3)
    if level >= 3:
        a.line([P(x0, y1 + 0.02, h + 3), P(x1, y1 + 0.02, h + 3)], GOLD, 1.8)
        x, y = P(0.15, y1 + 0.05, h - 4)
        a.line([P(0.15, y1, h - 4), (x, y)], IRON, 1.6)
        _ship_lantern(a, x, y)
    a.save("limestone_wall" if level == 1 else "limestone_wall_%d" % level)


def _lime_rubble(a, rng, n, g0, g1, d0, d1):
    for _ in range(n):
        x, y = P(rng.uniform(g0, g1), rng.uniform(d0, d1))
        w = rng.uniform(3.5, 6)
        a.poly([(x - w, y), (x - w * 0.6, y - w * 0.75), (x + w * 0.6, y - w * 0.7), (x + w, y)], rng.choice([LIME_T, LIME_L, LIME_R]), INK, 1)
        if rng.random() < 0.3:
            a.ellipse(x - w * 0.2, y - w * 0.5, 1.2, 0.8, LICHEN, opacity=0.9)


def lime_wall_ruin():
    rng = random.Random(1510)
    a = Art()
    y0, y1 = -0.13, 0.13
    a.poly(diamond(0.75, 0.4), "#2d2a24", stroke=None, opacity=0.4)
    _battered_foot(a, rng, -0.5, 0.5, y0, y1, 6)
    for (u0, u1, h) in [(-0.5, -0.2, 18), (-0.2, 0.06, 8), (0.06, 0.3, 23), (0.3, 0.5, 11)]:
        if h > 8:
            a.box(u0, u1, y0, y1, 6, h, LIME_T, LIME_L, LIME_R)
            _lime_ashlar(a, rng, "front", y1, u0, u1, 6, h, max(1, int((h - 6) / 7)))
            x, y = P(u1 - 0.04, y1, h)
            a.poly([(x - 5, y), (x - 2, y - 4), (x + 2, y + 1)], "#5e5a4e", stroke=None)
    _streaks(a, rng, "front", y1, -0.45, 0.45, 16, 3, (6, 10))
    _lime_rubble(a, rng, 9, -0.45, 0.45, 0.22, 0.45)
    a.save("limestone_wall_ruin")


def lime_gate(level=1):
    rng = random.Random(1520 + level)
    a = Art()
    x0, x1, y0, y1 = -0.5, 0.5, -0.16, 0.16
    def tower(g0, g1):
        _battered_foot(a, rng, g0, g1, y0, y1, 10, out=0.05)
        a.box(g0, g1, y0, y1, 10, 50, LIME_T, LIME_L, LIME_R)
        _lime_ashlar(a, rng, "front", y1, g0, g1, 10, 50, 5)
        _lime_ashlar(a, rng, "side", g1, y0, y1, 10, 50, 5)
        _streaks(a, rng, "front", y1, g0, g1, 50, 2)
        _lichen(a, rng, "front", y1, g0, g1, 14, 44, 2)
        a.box(g0, g1, y0 - 0.02, y1 + 0.02, 50, 53, LIME_T, LIME_L, LIME_R, sw=1.2)
        if level >= 2:
            _arrow_loop(a, "front", y1, (g0 + g1) / 2, 30)
    tower(x0, -0.22)  # back to front: the left tower, the arch, the right tower
    a.box(-0.22, 0.22, y0, y1, 0, 46, LIME_T, LIME_L, LIME_R)
    w, spring, rise = 0.17, 20, 13
    arc = [P(-w * math.cos(math.pi * k / 12), y1, spring + rise * math.sin(math.pi * k / 12)) for k in range(13)]
    a.poly([P(-w, y1, 0)] + arc + [P(w, y1, 0)], "#6a5a48", INK, 1.2)  # weathered doors
    for gx in (-0.115, -0.06, 0.06, 0.115):
        a.line([P(gx, y1, 0), P(gx, y1, spring + rise * math.sqrt(max(0.0, 1 - (gx / w) ** 2)) - 1)], "#4a3e30", 1.1)
    a.line([P(0.0, y1, 0), P(0.0, y1, spring + rise - 1)], INK, 1.4)
    for z in (7, 18):
        a.line([P(-w, y1, z), P(w, y1, z)], IRON, 2.6 if level >= 2 else 1.8)
    if level >= 2:
        for z in (7, 18):
            for gx in (-0.13, -0.05, 0.05, 0.13):
                x, y = P(gx, y1, z)
                a.ellipse(x, y, 1.2, 1.2, IRON_L)
    ring = [P(-(w + 0.025) * math.cos(math.pi * k / 9), y1, spring + (rise + 3) * math.sin(math.pi * k / 9)) for k in range(10)]
    a.line(ring, INK, 6.4)
    a.line(ring, LIME_T, 4.6)  # the voussoirs
    for k in range(1, 9):
        p0 = P(-w * math.cos(math.pi * k / 9), y1, spring + rise * math.sin(math.pi * k / 9))
        p1 = ring[k]
        a.line([p0, (p1[0] + (p1[0] - p0[0]) * 0.6, p1[1] + (p1[1] - p0[1]) * 0.6)], LIME_J, 0.9)
    _streaks(a, rng, "front", y1, -0.2, 0.2, 46, 2, (6, 9))
    a.box(-0.22, 0.22, y0 - 0.02, y1 + 0.02, 46, 49, LIME_T, LIME_L, LIME_R, sw=1.2)
    tower(0.22, x1)
    hanging_banner(a, ("left", y1), -0.42, -0.3, 48, 22)
    hanging_banner(a, ("left", y1), 0.3, 0.42, 48, 22)
    for gx in (x0, 0.26):
        _lime_merlon(a, gx, y0, 0.1, y1 - y0, 53, gold=level >= 3)
        _lime_merlon(a, gx + 0.14, y0, 0.1, y1 - y0, 53, gold=level >= 3)
    if level >= 3:
        a.line([P(-0.22, y1 + 0.02, 46), P(0.22, y1 + 0.02, 46)], GOLD, 2)
        for gx in (-0.2, 0.2):
            x, y = P(gx, y1 + 0.05, 32)
            a.line([P(gx, y1, 32), (x, y)], IRON, 1.6)
            _ship_lantern(a, x, y)
    a.save("limestone_gate" if level == 1 else "limestone_gate_%d" % level)


def lime_gate_ruin():
    rng = random.Random(1530)
    a = Art()
    y0, y1 = -0.16, 0.16
    a.poly(diamond(0.75, 0.42), "#2d2a24", stroke=None, opacity=0.4)
    _battered_foot(a, rng, -0.5, -0.22, y0, y1, 8, out=0.05)
    a.box(-0.5, -0.22, y0, y1, 8, 30, LIME_T, LIME_L, LIME_R)
    _lime_ashlar(a, rng, "front", y1, -0.5, -0.22, 8, 30, 3)
    _battered_foot(a, rng, 0.22, 0.5, y0, y1, 8, out=0.05)
    a.box(0.22, 0.5, y0, y1, 8, 15, LIME_T, LIME_L, LIME_R)
    for (gx, h) in [(-0.24, 30), (0.48, 15)]:
        x, y = P(gx, y1, h)
        a.poly([(x - 6, y), (x - 2, y - 5), (x + 3, y + 1)], "#5e5a4e", stroke=None)
    a.poly([P(-0.2, y1 + 0.04, 0), P(0.14, y1 + 0.06, 0), P(0.18, y1 + 0.32, 0), P(-0.14, y1 + 0.29, 0)], "#3e3226", INK, 1.2)  # a door, burnt
    a.line([P(-0.03, y1 + 0.05, 0), P(0.01, y1 + 0.31, 0)], "#241c14", 1.2)
    _lime_rubble(a, rng, 9, -0.45, 0.45, 0.22, 0.46)
    a.poly([P(-0.42, y1, 28), P(-0.32, y1, 28), P(-0.33, y1, 14), P(-0.37, y1, 18), P(-0.41, y1, 12)], CRIMSON_D, INK, 0.9)
    a.save("limestone_gate_ruin")


def _beacon(a, x, y):
    """A beacon fire in an iron basket on a short post at screen (x, y)."""
    a.ellipse(x, y - 18, 18, 14, GLOW, opacity=0.35)
    a.line([(x, y), (x, y - 6)], INK, 3)
    a.poly([(x - 7, y - 6), (x + 7, y - 6), (x + 5, y - 12), (x - 5, y - 12)], IRON, INK, 1)
    for d in (-3.5, 0, 3.5):
        a.line([(x + d * 1.3, y - 6), (x + d, y - 12)], IRON_L, 0.6)
    a.poly([(x - 6, y - 12), (x - 3, y - 22), (x - 0.5, y - 16), (x + 1.5, y - 27), (x + 3.5, y - 17), (x + 6, y - 12)], GLOW, "#b8401e", 1.1)
    a.poly([(x - 2.5, y - 12), (x + 0.5, y - 20), (x + 2.5, y - 12)], "#fff1b8", stroke=None)


def lime_wall_tower(front=False, level=1):
    rng = random.Random(1540 + level)
    a = Art()
    s, h, k = 0.34, 74, 0.12
    p = s + 0.03  # the parapet's half-size
    if front:
        a._track([P(-0.36, 0.36, 0), P(0.36, -0.36, 0), P(-0.36, -0.36, h + 60), P(0.36, 0.36, 0)])
        for gx, gy in _merlon_spots(p, True, k):
            _lime_merlon(a, gx, gy, k, k, h + 4, hgt=8, gold=level >= 3)
        return a
    a.shadow(52, 26, cy=4)
    _battered_foot(a, rng, -s, s, -s, s, 14, out=0.07)
    a.box(-s, s, -s, s, 14, h, LIME_T, LIME_L, LIME_R)
    _lime_ashlar(a, rng, "front", s, -s, s, 14, h - 4, 7)
    _lime_ashlar(a, rng, "side", s, -s, s, 14, h - 4, 7)
    _ledge(a, -s, s, -s, s, 40, 43)  # a string course
    _streaks(a, rng, "front", s, -s, s, h - 4, 4, (12, 26))
    _streaks(a, rng, "side", s, -s, s, h - 4, 3, (12, 22))
    _streaks(a, rng, "front", s + 0.02, -s, s, 40, 3, (6, 12))
    _lichen(a, rng, "front", s, -s, s, 18, h - 8, 4)
    _lichen(a, rng, "side", s, -s, s, 18, h - 8, 3)
    for u, z in ((-0.12, 48), (0.14, 22)):
        _opening(a, "front", s, u, u + 0.06, z, z + 10, "#1c1a16", arch=3, sw=0.8)
    _opening(a, "side", s, 0.03, -0.03, 50, 60, "#1c1a16", arch=3, sw=0.8)
    a.box(-p, p, -p, p, h - 4, h + 4, LIME_T, LIME_L, LIME_R)  # the parapet's course
    a.poly([P(-p + 0.04, -p + 0.04, h + 4), P(p - 0.04, -p + 0.04, h + 4), P(p - 0.04, p - 0.04, h + 4), P(-p + 0.04, p - 0.04, h + 4)], "#b5af9e", stroke=None)  # flagstones
    for t in (-0.12, 0.12):
        a.line([P(-p + 0.04, t, h + 4), P(p - 0.04, t, h + 4)], LIME_J, 0.8, opacity=0.8)
        a.line([P(t, -p + 0.04, h + 4), P(t, p - 0.04, h + 4)], LIME_J, 0.8, opacity=0.8)
    for gx, gy in _merlon_spots(p, False, k):
        _lime_merlon(a, gx, gy, k, k, h + 4, hgt=8, gold=level >= 3)
    if level >= 2:
        hanging_banner(a, ("left", s), -0.24, -0.04, h - 6, h - 34)
        _arrow_loop(a, "side", s, 0.12, 22)
    if level >= 3:
        hanging_banner(a, ("right", s), -0.06, 0.14, h - 6, h - 34)
        a.line([P(-p, p, h + 4), P(p, p, h + 4), P(p, -p, h + 4)], GOLD, 2)
        bx, by = P(0.16, -0.16, h + 4)  # inside, between the back and front merlons
        _beacon(a, bx, by)
    return a


def lime_wall_tower_ruin():
    rng = random.Random(1550)
    a = Art()
    s, h = 0.34, 30
    a.shadow(52, 26, cy=4)
    _battered_foot(a, rng, -s, s, -s, s, 14, out=0.07)
    a.box(-s, s, -s, s, 14, h, LIME_T, LIME_L, LIME_R)
    a.box(-s, -s + 0.22, -s, -s + 0.22, h, h + 24, LIME_T, LIME_L, LIME_R)  # the back corner still standing
    a.box(-s + 0.22, s - 0.28, -s, -s + 0.13, h, h + 10, LIME_T, LIME_L, LIME_R)
    _lime_ashlar(a, rng, "front", s, -s, s, 14, h, 2)
    _lime_ashlar(a, rng, "front", -s + 0.22, -s, -s + 0.22, h, h + 24, 3)
    _streaks(a, rng, "front", s, -s, s, h, 3, (6, 12))
    _lichen(a, rng, "front", s, -s, s, 16, h - 2, 3)
    for _ in range(10):
        gx, gy = rng.uniform(-0.5, 0.5), rng.uniform(0.45, 0.56)
        if rng.random() < 0.5:
            gx, gy = rng.uniform(0.45, 0.56), rng.uniform(-0.5, 0.5)
        _lime_rubble(a, rng, 1, gx, gx, gy, gy)
    a.save("limestone_wall_tower_ruin")


PLANK, PLANK_L, PLANK_D = "#8a7b68", "#a39480", "#64584a"
SHINGLE, SHINGLE_D = "#6e655b", "#4e4740"


def _pile(a, x, y, top, r=2.6):
    """A tarred pile from the ground (screen x, y) up `top` px, weed at its foot."""
    a.line([(x, y), (x, y - top)], INK, r * 2 + 1.4)
    a.line([(x, y), (x, y - top)], "#5a4a3a", r * 2)
    a.line([(x, y), (x, y - 6)], "#2a241e", r * 2)  # tarred foot
    a.ellipse(x, y, r + 1.2, 1.4, WEED, opacity=0.8)


def _fish(a, x, y, s=1.0):
    a.poly([(x, y), (x + 1.6 * s, y + 3 * s), (x + 1 * s, y + 7 * s), (x, y + 8 * s), (x - 1 * s, y + 7 * s), (x - 1.6 * s, y + 3 * s)], "#a8a8a0", INK, 0.6)
    a.poly([(x, y + 8 * s), (x + 1.8 * s, y + 10.5 * s), (x - 1.8 * s, y + 10.5 * s)], "#8a8a82", INK, 0.6)


def lime_hut(ruin=False):
    """Limestone: a fisher's hut of weathered planks on tarred piles over
    stone footings, a ladder up to its little porch, a net over the rail, fish
    drying on a rack, a shingle roof and a lantern by the door."""
    rng = random.Random(1560)
    a = Art()
    d = 18  # the deck's height
    x0, x1, y0, y1 = -0.34, 0.3, -0.3, 0.32  # the deck
    hx0, hx1, hy0, hy1 = -0.3, 0.26, -0.27, 0.1  # the hut on it
    piles = [(-0.3, -0.26), (0.26, -0.26), (-0.3, 0.02), (0.26, 0.02), (-0.3, 0.28), (0.26, 0.28), (-0.02, 0.28)]
    if ruin:
        a.poly(diamond(0.8), "#2d2a24", stroke=None, opacity=0.5)
        for (gx, gy), hh in zip(piles, (14, 8, 18, 5, 10, 16, 3)):  # broken piles, charred tops
            x, y = P(gx, gy)
            a.ellipse(x, y, 4.5, 2.2, LIME_L, INK, 0.9)
            _pile(a, x, y, hh)
            a.ellipse(x, y - hh, 2.6, 1.3, "#1e1810")
        a.poly([P(-0.3, -0.1, 14), P(0.2, -0.24, 6), P(0.26, 0.08, 0), P(-0.24, 0.24, 6)], "#4e4236", INK, 1.2)  # the deck, slumped
        for t in (0.25, 0.5, 0.75):
            a.line([P(-0.3 + 0.5 * t, -0.1 - 0.14 * t, 14 - 8 * t), P(-0.24 + 0.5 * t, 0.24 - 0.16 * t, 6 - 6 * t)], "#2e261e", 1)
        a.poly([P(-0.1, 0.05, 6), P(0.2, -0.05, 3), P(0.24, 0.15, 1), P(-0.04, 0.24, 3)], SHINGLE_D, INK, 1)  # a piece of roof
        for (g0, dd0, g1, dd1) in [(-0.4, 0.36, -0.05, 0.48), (0.25, 0.3, 0.46, 0.1)]:
            a.line([P(g0, dd0, 1), P(g1, dd1, 1)], INK, 4)
            a.line([P(g0, dd0, 1), P(g1, dd1, 1)], PLANK, 2.4)
        for _ in range(3):
            x, y = P(rng.uniform(-0.2, 0.2), rng.uniform(-0.1, 0.2))
            a.ellipse(x, y, 2, 1.3, "#c04a1e", opacity=0.7)
        a.save("limestone_hut_ruin")
        return
    a.shadow(44, 22, cy=4)
    for gx, gy in sorted(piles, key=lambda q: q[0] + q[1]):  # stone footings, piles
        x, y = P(gx, gy)
        a.ellipse(x, y, 4.5, 2.2, LIME_L, INK, 0.9)
        _pile(a, x, y, d - 3)
    for f0, f1 in [((-0.3, 0.28), (0.26, 0.28)), ((0.26, 0.28), (0.26, -0.26))]:  # cross braces
        p0, p1 = P(f0[0], f0[1], 2), P(f1[0], f1[1], d - 4)
        a.line([p0, p1], INK, 3)
        a.line([p0, p1], "#4a3c2e", 1.6)
    a.box(x0, x1, y0, y1, d - 3, d, PLANK_L, PLANK_D, "#4e4438", sw=1.2)  # the deck
    for k in range(1, 6):
        u = x0 + (x1 - x0) * k / 6
        a.line([P(u, hy1, d), P(u, y1, d)], PLANK_D, 0.8, opacity=0.8)
    # the hut: vertical boards
    h = d + 22
    a.box(hx0, hx1, hy0, hy1, d, h, PLANK_L, PLANK, PLANK_D)
    for k in range(1, 9):
        u = hx0 + (hx1 - hx0) * k / 9
        a.line([P(u, hy1, d), P(u, hy1, h)], PLANK_D, 0.9)
    for k in range(1, 6):
        u = hy0 + (hy1 - hy0) * k / 6
        a.line([P(hx1, u, d), P(hx1, u, h)], "#4e4438", 0.9)
    _opening(a, "front", hy1, -0.08, 0.06, d, d + 15, "#2a2018", sw=1.1)
    _opening(a, "front", hy1, 0.12, 0.21, d + 7, d + 14, GLOW, sw=1)
    _opening(a, "side", hx1, -0.06, -0.16, d + 7, d + 14, GLOW, sw=1)
    # a shingle roof, ridge along gx
    ridge = h + 20
    ym = (hy0 + hy1) / 2
    ey, ex = 0.05, 0.04
    slope = (ridge - h) / (hy1 - ym)
    eave_h = h - slope * ey
    xa, xb = hx0 - ex, hx1 + ex
    a.poly([P(xa, hy0 - ey, eave_h), P(xb, hy0 - ey, eave_h), P(xb, ym, ridge), P(xa, ym, ridge)], SHINGLE_D)
    a.poly([P(hx1, hy0, h), P(hx1, ym, ridge), P(hx1, hy1, h)], PLANK_D, INK, 1.2)
    front = [P(xa, ym, ridge), P(xb, ym, ridge), P(xb, hy1 + ey, eave_h), P(xa, hy1 + ey, eave_h)]
    a.poly(front, SHINGLE)
    for t in (0.25, 0.5, 0.75):
        yy = ym + (hy1 + ey - ym) * t
        zz = ridge - (ridge - eave_h) * t
        a.line([P(xa, yy, zz), P(xb, yy, zz)], SHINGLE_D, 1)
    a.line(front + [front[0]], INK, 1.3)
    a.line([P(xb, hy0 - ey, eave_h), P(xb, ym, ridge), P(xb, hy1 + ey, eave_h)], INK, 2)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], INK, 3.4)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], "#3a342e", 1.8)
    x, y = P(-0.18, ym - 0.04, ridge - 4)  # a stovepipe
    a.line([(x, y), (x, y - 14)], INK, 4.4)
    a.line([(x, y), (x, y - 14)], "#4a4642", 2.8)
    a.ellipse(x + 2, y - 22, 4, 6, "#8a8580", opacity=0.22)
    # the porch rail with a net over it, a lantern by the door
    for gx in (x0 + 0.02, -0.16, 0.12, x1 - 0.02):
        a.line([P(gx, y1 - 0.02, d), P(gx, y1 - 0.02, d + 9)], INK, 2.6)
        a.line([P(gx, y1 - 0.02, d), P(gx, y1 - 0.02, d + 9)], PLANK, 1.4)
    a.line([P(x0 + 0.02, y1 - 0.02, d + 9), P(x1 - 0.02, y1 - 0.02, d + 9)], INK, 2.8)
    a.line([P(x0 + 0.02, y1 - 0.02, d + 9), P(x1 - 0.02, y1 - 0.02, d + 9)], PLANK_L, 1.5)
    for k in range(6):  # the net hanging over the rail
        u = 0.02 + 0.045 * k
        a.line([P(u, y1 - 0.01, d + 9), P(u + 0.01, y1 + 0.01, d - 4 - 2 * math.sin(k))], "#4a4030", 0.8)
    for z in (d + 4, d - 1):
        a.line([P(0.02, y1, z + 2), P(0.13, y1, z), P(0.25, y1, z + 2)], "#4a4030", 0.8)
    x, y = P(0.25, y1, d + 9)
    a.ellipse(x, y, 2.2, 1.6, "#c58a3a", INK, 0.7)  # a cork float
    x, y = P(-0.11, hy1 + 0.02, d + 18)
    _ship_lantern(a, x, y)
    # the fish rack on the side: a pole on two posts, fish hung from it
    for gy in (-0.2, 0.0):
        a.line([P(x1 + 0.08, gy, 0), P(x1 + 0.08, gy, d + 6)], INK, 2.6)
        a.line([P(x1 + 0.08, gy, 0), P(x1 + 0.08, gy, d + 6)], "#5a4a3a", 1.4)
    a.line([P(x1 + 0.08, -0.22, d + 6), P(x1 + 0.08, 0.02, d + 6)], INK, 2.4)
    a.line([P(x1 + 0.08, -0.22, d + 6), P(x1 + 0.08, 0.02, d + 6)], PLANK_L, 1.2)
    for gy in (-0.16, -0.11, -0.06, -0.01):
        x, y = P(x1 + 0.08, gy, d + 6)
        _fish(a, x, y, 0.9)
    # the ladder up to the porch
    for gx in (-0.26, -0.17):
        a.line([P(gx, y1 + 0.14, 0), P(gx, y1, d + 4)], INK, 2.8)
        a.line([P(gx, y1 + 0.14, 0), P(gx, y1, d + 4)], PLANK_L, 1.4)
    for j in range(1, 5):
        t = j / 5
        a.line([P(-0.26, y1 + 0.14 * (1 - t), (d + 4) * t), P(-0.17, y1 + 0.14 * (1 - t), (d + 4) * t)], PLANK_L, 1.3)
    a.save("limestone_hut")
