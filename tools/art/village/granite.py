"""Village pieces in granite."""

import math
import random

from ..core import (
    Art, CRIMSON_D, diamond, GLOW, GOLD, hanging_banner, INK, IRON, IRON_L, _opening, P,
    _ring, ROPE_D, _tuft,
)


THATCH, THATCH_L, THATCH_D = "#b8954e", "#cfae66", "#8a6c34"


# Granite (Highlands): rough dry-stone of rounded, speckled blocks without
# mortar, moss in the joints, overhanging slate coping; the wall towers round
# brochs. Level 2 a banner, level 3 gilt and a peat
# brazier.

GRAN_T, GRAN_L, GRAN_R, GRAN_D = "#a89c95", "#8a7f79", "#665d59", "#3e3835"
GRAN_FL = "#d9cdc3"
MOSS, MOSS_D = "#5e7c34", "#45602a"
SLATE_T, SLATE_L, SLATE_R = "#66717c", "#4d5761", "#383f47"
TARTAN = "#2f5a3a"


def _dry_face(a, rng, face, at, g0, g1, z0, z1, rows, side_shade=False):
    """Rough dry-stone: rounded blocks of random size on a face, moss in some joints."""
    def q(g, z):
        return P(g, at, z) if face == "front" else P(at, g, z)
    shades = [GRAN_R, "#5b534f", "#70675f"] if side_shade else [GRAN_L, "#948880", "#7e746e"]
    for r in range(rows):
        za = z0 + (z1 - z0) * r / rows
        zb = z0 + (z1 - z0) * (r + 1) / rows
        u = g0
        while u < g1 - 0.02:
            w = rng.uniform(0.09, 0.2)
            v = min(g1, u + w)
            if g1 - v < 0.05:
                v = g1
            pad_u, pad_z = 0.008, 0.8
            ua, ub = u + pad_u, v - pad_u
            zz0, zz1 = za + pad_z, zb - pad_z + rng.uniform(-0.8, 0.8)
            m = (ua + ub) / 2
            pts = [q(ua + 0.015, zz0), q(m, zz0 - 0.6), q(ub - 0.015, zz0), q(ub, (zz0 + zz1) / 2), q(ub - 0.015, zz1), q(m, zz1 + 0.6), q(ua + 0.015, zz1), q(ua, (zz0 + zz1) / 2)]
            a.poly(pts, rng.choice(shades), GRAN_D, 0.8)
            if rng.random() < 0.35:
                x, y = q(ua + (ub - ua) * rng.uniform(0.2, 0.8), (zz0 + zz1) / 2 + rng.uniform(-1, 1))
                a.ellipse(x, y, 0.7, 0.7, GRAN_FL, opacity=0.8)
            if rng.random() < 0.18:
                x, y = q(ub, zz0)
                a.ellipse(x, y - 0.5, 2.6, 1.3, MOSS, opacity=0.85)
            u = v


def _slate_cap(a, x0, x1, y0, y1, z, t=3, o=0.035):
    a.box(x0 - o, x1 + o, y0 - o, y1 + o, z, z + t, SLATE_T, SLATE_L, SLATE_R, sw=1.1)


def _gran_merlon(a, rng, gx, gy, kx, ky, z, hgt=8, gold=False):
    """A rough stack of stones under a slate slab."""
    a.box(gx, gx + kx, gy, gy + ky, z, z + hgt, GRAN_T, GRAN_L, GRAN_R, sw=1.1)
    zm = z + hgt * rng.uniform(0.4, 0.6)
    a.line([P(gx, gy + ky, zm), P(gx + kx, gy + ky, zm + rng.uniform(-1, 1)), P(gx + kx, gy, zm)], GRAN_D, 0.8)
    a.box(gx - 0.015, gx + kx + 0.015, gy - 0.015, gy + ky + 0.015, z + hgt, z + hgt + 2.4, SLATE_T, SLATE_L, SLATE_R, sw=1)
    if gold:
        a.line([P(gx - 0.015, gy + ky + 0.015, z + hgt + 2.4), P(gx + kx + 0.015, gy + ky + 0.015, z + hgt + 2.4), P(gx + kx + 0.015, gy - 0.015, z + hgt + 2.4)], GOLD, 1.5)


def _peat_brazier(a, x, y):
    a.ellipse(x, y - 14, 16, 12, GLOW, opacity=0.35)
    a.poly([(x - 6, y - 6), (x + 6, y - 6), (x + 4, y), (x - 4, y)], IRON, INK, 1)
    a.poly([(x - 5, y - 6), (x - 4, y - 9), (x + 4, y - 9), (x + 5, y - 6)], "#3a2a1a", INK, 0.8)  # the peat
    a.poly([(x - 3.5, y - 9), (x, y - 19), (x + 3.5, y - 9)], GLOW, "#b8401e", 1)


def gran_wall(level=1):
    rng = random.Random(1300 + level)
    a = Art()
    x0, x1, y0, y1, h = -0.5, 0.5, -0.15, 0.15, 28
    a.box(x0, x1, y0, y1, 0, h, GRAN_T, GRAN_L, GRAN_R)
    _dry_face(a, rng, "front", y1, x0, x1, 0, h, 4)
    _slate_cap(a, x0, x1, y0, y1, h)
    if level >= 2:
        hanging_banner(a, ("left", y1), -0.07, 0.07, h - 2, 6)
    for gx in (-0.44, -0.1, 0.24):
        _gran_merlon(a, rng, gx, y0, 0.2, y1 - y0, h + 3, gold=level >= 3)
    for gx in (-0.2, 0.36):
        x, y = P(gx, y1, h + 3)
        a.ellipse(x, y, 4, 1.6, MOSS, opacity=0.85)
    if level >= 3:
        a.line([P(x0 - 0.035, y1 + 0.035, h + 3), P(x1 + 0.035, y1 + 0.035, h + 3)], GOLD, 1.8)
    a.save("granite_wall" if level == 1 else "granite_wall_%d" % level)


def _boulders(a, rng, n, g0, g1, d0, d1):
    for _ in range(n):
        x, y = P(rng.uniform(g0, g1), rng.uniform(d0, d1))
        w = rng.uniform(3.5, 6.5)
        a.poly([(x - w, y), (x - w, y - w * 0.5), (x - w * 0.5, y - w * 0.9), (x + w * 0.5, y - w * 0.85), (x + w, y - w * 0.4), (x + w * 0.8, y)], rng.choice([GRAN_L, GRAN_R, "#948880"]), INK, 1)
        if rng.random() < 0.4:
            a.ellipse(x - w * 0.2, y - w * 0.8, w * 0.5, w * 0.2, MOSS, opacity=0.85)


def gran_wall_ruin():
    rng = random.Random(1310)
    a = Art()
    y0, y1 = -0.15, 0.15
    a.poly(diamond(0.75, 0.4), "#2a2826", stroke=None, opacity=0.4)
    for (u0, u1, h) in [(-0.5, -0.18, 14), (-0.18, 0.08, 5), (0.08, 0.32, 18), (0.32, 0.5, 8)]:
        a.box(u0, u1, y0, y1, 0, h, GRAN_T, GRAN_L, GRAN_R)
        _dry_face(a, rng, "front", y1, u0, u1, 0, h, max(1, int(h / 7)))
    a.box(0.1, 0.34, 0.24, 0.4, 0, 3, SLATE_T, SLATE_L, SLATE_R, sw=1)  # a fallen slate
    _boulders(a, rng, 8, -0.45, 0.45, 0.2, 0.44)
    for _ in range(3):
        x, y = P(rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.3))
        _tuft(a, x, y, "#4e6a2c")
    a.save("granite_wall_ruin")


def gran_gate(level=1):
    rng = random.Random(1320 + level)
    a = Art()
    x0, x1, y0, y1 = -0.5, 0.5, -0.16, 0.16
    a.poly(diamond(0.62, 0.26), "#2a2826", stroke=None, opacity=0.3)
    # back to front: the left pier, the passage's body (dry-stone over the door), the right pier
    for g0, g1 in [(x0, -0.2), (-0.2, 0.2), (0.2, x1)]:
        a.box(g0, g1, y0, y1, 0, 48, GRAN_T, GRAN_L, GRAN_R)
        _dry_face(a, rng, "front", y1, g0, g1, 34 if g0 == -0.2 else 0, 48, 2 if g0 == -0.2 else 6)
        _dry_face(a, rng, "side", g1, y0, y1, 0, 48, 6, side_shade=True)
        _slate_cap(a, g0, g1, y0, y1, 48)
    # the door in the front face: a dark reveal, thick planks, iron bands
    a.poly([P(-0.2, y1, 0), P(0.2, y1, 0), P(0.2, y1, 29), P(-0.2, y1, 29)], "#1a1612", INK, 1.2)
    a.poly([P(-0.17, y1, 0), P(0.17, y1, 0), P(0.17, y1, 27), P(-0.17, y1, 27)], "#6a4c30", INK, 1)
    for gx in (-0.085, 0.0, 0.085):
        a.line([P(gx, y1, 0), P(gx, y1, 27)], "#21170e", 1.3)
    for z in (6, 21):
        a.line([P(-0.17, y1, z), P(0.17, y1, z)], IRON, 2.6 if level >= 2 else 1.8)
    if level >= 2:
        for z in (6, 21):
            for gx in (-0.13, -0.045, 0.045, 0.13):
                x, y = P(gx, y1, z)
                a.ellipse(x, y, 1.2, 1.2, IRON_L)
    a.box(-0.23, 0.23, y1 - 0.03, y1 + 0.01, 29, 34, "#b0a59e", "#9a8e87", GRAN_R, sw=1.2)  # the lintel stone
    for gx in (-0.13, 0.09):
        x, y = P(gx, y1 + 0.01, 31.5)
        a.ellipse(x, y, 0.8, 0.8, GRAN_FL)
    hanging_banner(a, ("left", y1), -0.42, -0.3, 44, 18)
    hanging_banner(a, ("left", y1), 0.3, 0.42, 44, 18)
    for gx in (x0, 0.26):
        _gran_merlon(a, rng, gx, y0, 0.11, y1 - y0, 51, gold=level >= 3)
        _gran_merlon(a, rng, gx + 0.13, y0, 0.11, y1 - y0, 51, gold=level >= 3)
    if level >= 2:  # stag antlers over the door
        x, y = P(0.0, y1, 40)
        for d in (-1, 1):
            a.line([(x, y - 2), (x + 7 * d, y - 9), (x + 10 * d, y - 15)], "#e6dcc8", 1.6)
            a.line([(x + 5 * d, y - 7), (x + 4 * d, y - 13)], "#e6dcc8", 1.3)
        a.ellipse(x, y - 1, 2.6, 2, "#6a5038", INK, 0.8)
    if level >= 3:
        a.line([P(-0.23, y1 + 0.01, 34), P(0.23, y1 + 0.01, 34)], GOLD, 2)
        for gx in (-0.2, 0.2):
            x, y = P(gx, y1 + 0.02, 26)
            a.ellipse(x, y, 7, 7, GLOW, opacity=0.3)
            a.poly([(x - 2.5, y - 3.5), (x + 2.5, y - 3.5), (x + 2.5, y + 3.5), (x - 2.5, y + 3.5)], GLOW, INK, 0.9)
    a.save("granite_gate" if level == 1 else "granite_gate_%d" % level)


def gran_gate_ruin():
    rng = random.Random(1330)
    a = Art()
    y0, y1 = -0.16, 0.16
    a.poly(diamond(0.75, 0.42), "#2a2826", stroke=None, opacity=0.4)
    a.box(-0.5, -0.2, y0, y1, 0, 28, GRAN_T, GRAN_L, GRAN_R)
    _dry_face(a, rng, "front", y1, -0.5, -0.2, 0, 28, 4)
    a.box(0.2, 0.5, y0, y1, 0, 14, GRAN_T, GRAN_L, GRAN_R)
    _dry_face(a, rng, "front", y1, 0.2, 0.5, 0, 14, 2)
    # the lintel fallen across the opening, the door burnt under it
    a.poly([P(-0.18, y1 + 0.03, 0), P(0.14, y1 + 0.05, 0), P(0.17, y1 + 0.3, 0), P(-0.15, y1 + 0.27, 0)], "#3a2818", INK, 1.2)
    a.box(-0.22, 0.24, y1 + 0.08, y1 + 0.2, 0, 7, GRAN_T, "#9a8e87", GRAN_R, sw=1.3)
    _boulders(a, rng, 8, -0.45, 0.45, 0.24, 0.46)
    a.poly([P(-0.42, y1, 26), P(-0.32, y1, 26), P(-0.33, y1, 12), P(-0.37, y1, 16), P(-0.41, y1, 10)], CRIMSON_D, INK, 0.9)
    a.save("granite_gate_ruin")


def _cylinder(a, r, z0, z1, left, right, top=None, sw=1.4):
    """A round drum: its front half shaded left and right, an outline, a top."""
    a.poly(_ring(r, z0, 45, 135) + _ring(r, z1, 135, 45), left, stroke=None)
    a.poly(_ring(r, z0, -45, 45) + _ring(r, z1, 45, -45), right, stroke=None)
    a.line(_ring(r, z0, -45, 135, 24), INK, sw)
    a.line([_ring(r, z0, 135, 135, 1)[0], _ring(r, z1, 135, 135, 1)[0]], INK, sw)
    a.line([_ring(r, z0, -45, -45, 1)[0], _ring(r, z1, -45, -45, 1)[0]], INK, sw)
    if top:
        a.poly(_ring(r, z1, 0, 360, 36), top, INK, sw)


def _broch_courses(a, rng, r, z0, z1, rows):
    """Dry-stone courses round a drum: wavy bed joints, staggered head joints, moss."""
    for k in range(1, rows):
        z = z0 + (z1 - z0) * k / rows
        pts = []
        for j in range(25):
            t = -45 + 180 * j / 24
            pts.append(P(r * math.cos(math.radians(t)), r * math.sin(math.radians(t)), z + math.sin(j * 1.7 + k) * 0.8))
        a.line(pts, GRAN_D, 0.9)
    for k in range(rows):
        za = z0 + (z1 - z0) * k / rows
        zb = z0 + (z1 - z0) * (k + 1) / rows
        t = -45 + rng.uniform(4, 16)
        while t < 132:
            p0 = P(r * math.cos(math.radians(t)), r * math.sin(math.radians(t)), za)
            p1 = P(r * math.cos(math.radians(t)), r * math.sin(math.radians(t)), zb)
            a.line([p0, p1], GRAN_D, 0.9)
            if rng.random() < 0.3:
                a.ellipse(p0[0] + 3, p0[1] - 3, 0.7, 0.7, GRAN_FL, opacity=0.8)
            if rng.random() < 0.12:
                a.ellipse(p0[0], p0[1] - 1, 3, 1.3, MOSS, opacity=0.85)
            t += rng.uniform(14, 26)


def _broch_merlons(a, rng, r, z, front, level, k=0.12):
    """Merlons round the broch's top: the back ones, or the front ones (by depth)."""
    spots = []
    for j in range(10):
        t = math.radians(36 * j + 18)
        gx, gy = r * math.cos(t), r * math.sin(t)
        if (gx + gy > 0.05) == front:
            spots.append((gx, gy))
    spots.sort(key=lambda q: q[0] + q[1])
    for gx, gy in spots:
        _gran_merlon(a, rng, gx - k / 2, gy - k / 2, k, k, z, 9, gold=level >= 3)


def gran_wall_tower(front=False, level=1):
    """A broch: a round dry-stone tower, battered at the foot."""
    rng = random.Random(1340 + level)
    a = Art()
    s, r, h = 0.36, 0.4, 74
    if front:
        a._track([P(-s, s, 0), P(s, -s, 0), P(-s, -s, h + 60), P(s, s, 0)])
        _broch_merlons(a, random.Random(1349), r - 0.04, h + 4, True, level)
        return a
    a.shadow(52, 26, cy=4)
    _cylinder(a, r + 0.05, 0, 10, GRAN_L, GRAN_R)
    _broch_courses(a, rng, r + 0.05, 0, 10, 2)
    _cylinder(a, r, 10, h, GRAN_L, GRAN_R)
    _broch_courses(a, rng, r, 10, h, 9)
    # a low door and two slits
    t = math.radians(80)
    gx, gy = r * math.cos(t), r * math.sin(t)
    _opening(a, "front", gy + 0.005, gx - 0.05, gx + 0.05, 10, 24, "#1a1612", sw=1)
    for deg, z in ((60, 44), (20, 50)):
        t = math.radians(deg)
        x, y = P(r * math.cos(t), r * math.sin(t), z)
        a.poly([(x - 1.6, y), (x + 1.6, y), (x + 1.6, y - 10), (x - 1.6, y - 10)], "#1a1612", INK, 0.8)
    # the slate-capped top and its floor
    _cylinder(a, r + 0.03, h, h + 4, SLATE_L, SLATE_R, top=SLATE_T)
    a.poly(_ring(r - 0.03, h + 4, 0, 360, 36), "#8d837c", INK, 1)  # flagstones
    for k in (-0.12, 0.12):
        a.line([P(-0.3, k, h + 4), P(0.3, k, h + 4)], GRAN_R, 0.8, opacity=0.7)
        a.line([P(k, -0.3, h + 4), P(k, 0.3, h + 4)], GRAN_R, 0.8, opacity=0.7)
    a.line([P(-s + 0.1, -s + 0.1, h + 4), P(-s + 0.1, -s + 0.1, h + 44)], INK, 3)
    x, y = P(-s + 0.1, -s + 0.1, h + 44)
    a.cloth([(x, y), (x + 20, y + 4), (x + 14, y + 9), (x + 20, y + 14), (x, y + 16)], sw=1.4)
    _broch_merlons(a, random.Random(1348), r - 0.04, h + 4, False, level)
    if level >= 2:
        # a banner down the front, an iron ring round the top
        t0, t1 = 70, 100
        z_top, z_bot = h - 4, h - 36
        tm = (t0 + t1) / 2
        pts = _ring(r + 0.005, z_top, t0, t1, 4) + [_ring(r + 0.005, z_bot, t1, t1, 1)[0], _ring(r + 0.005, z_bot + 6, tm, tm, 1)[0], _ring(r + 0.005, z_bot, t0, t0, 1)[0]]
        a.cloth(pts)
        a.line(_ring(r + 0.004, h - 2, -45, 135, 24), IRON, 3)
    if level >= 3:
        a.line(_ring(r + 0.03, h + 4, -45, 135, 24), GOLD, 2)
        bx, by = P(0.18, -0.18, h + 4)
        _peat_brazier(a, bx, by)
    return a


def gran_wall_tower_ruin():
    rng = random.Random(1350)
    a = Art()
    r, h = 0.4, 26
    a.shadow(52, 26, cy=4)
    _cylinder(a, r + 0.05, 0, 10, GRAN_L, GRAN_R)
    _cylinder(a, r, 10, h, GRAN_L, GRAN_R)
    _broch_courses(a, rng, r, 10, h, 2)
    a.poly(_ring(r, h, 0, 360, 36), GRAN_T, INK, 1.4)  # the wall head, broken
    a.poly(_ring(r - 0.08, h, 0, 360, 36), "#4a423d", INK, 1)  # hollow, rubble inside
    # the back of the wall still stands higher, ragged: its inner face shows
    inner = _ring(r - 0.08, h, 150, 300, 10)
    rise = [6, 14, 22, 27, 31, 26, 20, 23, 14, 8, 2]
    top = [(x, y - rise[j]) for j, (x, y) in enumerate(inner)]
    a.poly(inner + top[::-1], GRAN_R, INK, 1.2)
    for z in (8, 16):
        a.line([(x, y - min(z, rise[j] - 1)) for j, (x, y) in enumerate(inner)], GRAN_D, 0.8)
    a.line(top, GRAN_T, 2.4)
    a.line(top, INK, 0.8)
    for (x, y) in top[2:9:3]:
        a.ellipse(x, y, 3, 1.3, MOSS, opacity=0.9)
    for _ in range(5):  # fallen stones on the rubble inside
        x, y = P(rng.uniform(-0.2, 0.15), rng.uniform(-0.05, 0.2), h)
        w = rng.uniform(3, 5)
        a.poly([(x - w, y), (x - w * 0.6, y - w * 0.8), (x + w * 0.5, y - w * 0.8), (x + w, y)], rng.choice([GRAN_L, GRAN_R, "#948880"]), INK, 1)
    for _ in range(10):
        gx, gy = rng.uniform(-0.5, 0.5), rng.uniform(0.42, 0.56)
        if rng.random() < 0.5:
            gx, gy = rng.uniform(0.42, 0.56), rng.uniform(-0.5, 0.5)
        _boulders(a, rng, 1, gx, gx, gy, gy)
    a.save("granite_wall_tower_ruin")


TURF, TURF_L, TURF_D = "#5d7a36", "#7a9a48", "#3e5426"


def gran_hut(ruin=False):
    """Granite: a blackhouse, long and low, thick dry-stone walls with rounded
    corners, a thatch roof under turf held by ropes weighted with stones, peat
    smoke out of a hole in the roof."""
    rng = random.Random(1360)
    a = Art()
    x0, x1, y0, y1, h = -0.38, 0.38, -0.26, 0.26, 18
    if ruin:
        a.poly(diamond(0.82), "#2a2826", stroke=None, opacity=0.5)
        for (u0, u1, hh) in [(x0, -0.1, 12), (-0.1, 0.12, 4), (0.12, x1, 9)]:
            a.box(u0, u1, y1 - 0.12, y1, 0, hh, GRAN_T, GRAN_L, GRAN_R, sw=1.2)
            _dry_face(a, rng, "front", y1, u0, u1, 0, hh, max(1, int(hh / 6)))
        a.box(x1 - 0.12, x1, y0, y1 - 0.12, 0, 14, GRAN_T, GRAN_L, GRAN_R, sw=1.2)
        a.box(x0, x0 + 0.4, y0, y0 + 0.12, 0, 10, GRAN_T, GRAN_L, GRAN_R, sw=1.2)
        a.poly([P(-0.28, -0.08, 2), P(0.18, -0.12, 3), P(0.22, 0.08, 5), P(-0.22, 0.12, 3)], TURF_D, INK, 1.1)  # the fallen turf
        a.poly([P(-0.05, -0.06, 4), P(0.12, -0.08, 4), P(0.14, 0.04, 5)], "#2a1e15", stroke=None, opacity=0.8)
        a.line([P(-0.25, 0.18, 1), P(0.22, -0.02, 10)], INK, 4.5)
        a.line([P(-0.25, 0.18, 1), P(0.22, -0.02, 10)], "#2a1e15", 2.6)
        _boulders(a, rng, 6, -0.3, 0.4, 0.32, 0.55)
        a.save("granite_hut_ruin")
        return
    a.shadow(48, 22, cy=4)
    a.box(x0, x1, y0, y1, 0, h, GRAN_T, GRAN_L, GRAN_R)
    _dry_face(a, rng, "front", y1, x0, x1, 0, h, 3)
    _dry_face(a, rng, "side", x1, y0, y1, 0, h, 3, side_shade=True)
    _opening(a, "front", y1, -0.12, 0.02, 0, 13, "#3e2c1c", sw=1.1)  # a low door
    a.box(-0.15, 0.05, y1, y1 + 0.03, 13, 16, GRAN_T, "#9a8e87", GRAN_R, sw=1)  # its lintel stone
    _opening(a, "front", y1, 0.18, 0.25, 6, 12, GLOW, sw=1)
    # the roof: a low hipped mass of thatch under turf, sitting inside the wall head
    ridge = h + 24
    ym = (y0 + y1) / 2
    i = 0.04
    rx0, rx1 = x0 + i, x1 - i
    hip = 0.16
    front = [P(rx0 + hip, ym, ridge), P(rx1 - hip, ym, ridge), P(rx1, y1 - i, h), P(rx0, y1 - i, h)]
    end = [P(rx1 - hip, ym, ridge), P(rx1, y0 + i, h), P(rx1, y1 - i, h)]
    a.poly([P(rx0 + hip, ym, ridge), P(rx1 - hip, ym, ridge), P(rx1, y0 + i, h), P(rx0, y0 + i, h)], TURF_D)
    a.poly(end, "#4a6430", INK, 1.2)
    a.poly(front, TURF, INK, 1.3)
    a.poly([P(rx0, y1 - i, h), P(rx1, y1 - i, h), P(rx1, y1 - i + 0.02, h - 3), P(rx0, y1 - i + 0.02, h - 3)], THATCH_D, INK, 1)  # thatch showing at the eave
    for k in range(10):  # grass tufts on the turf
        t = rng.uniform(0.15, 0.85)
        gx = rx0 + 0.06 + (rx1 - rx0 - 0.12) * rng.random()
        x, y = P(gx, ym + (y1 - i - ym) * t, ridge - (ridge - h) * t)
        _tuft(a, x, y, TURF_L, 0.9, 3.5)
    for gx in (-0.18, 0.02, 0.2):  # ropes over the roof, weighted with stones
        p0 = P(gx, ym, ridge)
        p1 = P(gx, y1 - i + 0.03, h - 4)
        a.line([p0, p1], ROPE_D, 1.2)
        a.ellipse(p1[0], p1[1] + 2, 3, 2.6, GRAN_L, INK, 0.9)
    x, y = P(-0.05, ym, ridge)  # the smoke hole, peat smoke
    a.ellipse(x, y, 4, 2, "#1a1612")
    a.ellipse(x + 2, y - 9, 5, 7, "#8a8580", opacity=0.25)
    a.ellipse(x + 6, y - 20, 6, 8, "#8a8580", opacity=0.18)
    a.save("granite_hut")
