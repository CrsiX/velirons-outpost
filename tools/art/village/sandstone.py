"""Village pieces in sandstone."""

import math
import random

from ..core import (
    Art, BRASS, CRIMSON_D, diamond, GLOW, GOLD, GOLD_D, hanging_banner, INK, IRON_L, _merlon_spots, _opening,
    P,
)


# Sandstone: warm ashlar of big smooth blocks on a plinth, a cornice and stepped
# merlons, a pointed arch over the gate; level 2 blue glazed tiles and blue
# cloth, level 3 gilded tops and brass lamps.

SAND_T, SAND_L, SAND_R, SAND_D, SAND_B = "#dcc08e", "#c8a46e", "#a5824f", "#8a6a40", "#b48f5a"
TILE_BLUE, TILE_BLUE_D, TILE_TEAL = "#2c5a86", "#1f405f", "#3a8a8a"


def _sand_merlon(a, gx, gy, kx, ky, z, gold=False):
    """A stepped merlon: a block and a smaller one on top."""
    a.box(gx, gx + kx, gy, gy + ky, z, z + 6, SAND_T, SAND_L, SAND_R)
    ix, iy = kx * 0.22, ky * 0.22
    a.box(gx + ix, gx + kx - ix, gy + iy, gy + ky - iy, z + 6, z + 11, SAND_T, SAND_L, SAND_R)
    if gold:
        a.line([P(gx + ix, gy + ky - iy, z + 11), P(gx + kx - ix, gy + ky - iy, z + 11), P(gx + kx - ix, gy + iy, z + 11)], GOLD, 1.6)


def _sand_ashlar(a, g0, g1, gy, z0, z1, rows=2, seed=0):
    """Joints of big blocks on a front face (gy) between z0 and z1."""
    rng = random.Random(seed)
    for r in range(rows):
        za = z0 + (z1 - z0) * r / rows
        zb = z0 + (z1 - z0) * (r + 1) / rows
        if r > 0:
            a.line([P(g0, gy, za), P(g1, gy, za)], SAND_D, 1)
        u = g0 + rng.uniform(0.12, 0.3) * (1 if r % 2 == 0 else 0.6)
        while u < g1 - 0.08:
            a.line([P(u, gy, za), P(u, gy, zb)], SAND_D, 1)
            u += rng.uniform(0.26, 0.36)


def _sand_ashlar_right(a, gx, g0, g1, z0, z1, rows=2, seed=0):
    rng = random.Random(seed)
    for r in range(rows):
        za = z0 + (z1 - z0) * r / rows
        zb = z0 + (z1 - z0) * (r + 1) / rows
        if r > 0:
            a.line([P(gx, g0, za), P(gx, g1, za)], SAND_D, 1)
        u = g0 + rng.uniform(0.1, 0.25)
        while u < g1 - 0.08:
            a.line([P(gx, u, za), P(gx, u, zb)], SAND_D, 1)
            u += rng.uniform(0.26, 0.36)


def _tile_band(a, g0, g1, gy, z0, z1):
    """A band of blue glazed tiles with gold lozenges on a front face."""
    a.poly([P(g0, gy, z0), P(g1, gy, z0), P(g1, gy, z1), P(g0, gy, z1)], TILE_BLUE, INK, 1)
    n = max(2, int((g1 - g0) / 0.1))
    for k in range(n):
        x, y = P(g0 + (g1 - g0) * (k + 0.5) / n, gy, (z0 + z1) / 2)
        a.poly([(x, y - 2.2), (x + 2.2, y), (x, y + 2.2), (x - 2.2, y)], GOLD if k % 2 == 0 else TILE_TEAL, stroke=None)


def _tile_band_right(a, gx, g0, g1, z0, z1):
    a.poly([P(gx, g1, z0), P(gx, g0, z0), P(gx, g0, z1), P(gx, g1, z1)], TILE_BLUE_D, INK, 1)
    n = max(2, int((g1 - g0) / 0.1))
    for k in range(n):
        x, y = P(gx, g0 + (g1 - g0) * (k + 0.5) / n, (z0 + z1) / 2)
        a.poly([(x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)], GOLD_D if k % 2 == 0 else TILE_TEAL, stroke=None)


def sand_wall(level=1):
    a = Art()
    x0, x1, y0, y1, h = -0.5, 0.5, -0.14, 0.14, 32
    a.box(x0, x1, y0 - 0.03, y1 + 0.03, 0, 6, SAND_B, SAND_L, SAND_R)
    a.box(x0, x1, y0, y1, 6, h, SAND_T, SAND_L, SAND_R)
    _sand_ashlar(a, x0, x1, y1, 6, h, 2, 900 + level)
    a.box(x0, x1, y0 - 0.02, y1 + 0.02, h, h + 3, SAND_T, SAND_B, SAND_R)
    if level >= 2:
        _tile_band(a, x0, x1, y1, h - 6, h - 1)
        hanging_banner(a, ("left", y1), -0.07, 0.07, h - 7, 10)
    for gx in (-0.44, -0.11, 0.22):
        _sand_merlon(a, gx, y0, 0.2, y1 - y0, h + 3, gold=level >= 3)
    if level >= 3:
        a.line([P(x0, y1 + 0.02, h + 3), P(x1, y1 + 0.02, h + 3)], GOLD, 1.8)
    a.save("sandstone_wall" if level == 1 else "sandstone_wall_%d" % level)


def _sand_rubble(a, rng, n, g0, g1, d0, d1):
    for _ in range(n):
        x, y = P(rng.uniform(g0, g1), rng.uniform(d0, d1))
        w = rng.uniform(3.5, 6)
        a.poly([(x - w, y), (x - w * 0.5, y - w * 0.75), (x + w * 0.6, y - w * 0.65), (x + w, y)], rng.choice([SAND_L, SAND_R, SAND_B]), INK, 1)


def _sand_drift(a, rng, n, g0, g1, d0, d1):
    for _ in range(n):
        x, y = P(rng.uniform(g0, g1), rng.uniform(d0, d1))
        a.ellipse(x, y, rng.uniform(7, 12), rng.uniform(2.5, 4), "#d9bf8a", opacity=0.7)


def sand_wall_ruin():
    rng = random.Random(910)
    a = Art()
    y0, y1 = -0.14, 0.14
    a.poly(diamond(0.75, 0.4), "#3a3024", stroke=None, opacity=0.4)
    for (u0, u1, h) in [(-0.5, -0.2, 18), (-0.2, 0.08, 7), (0.08, 0.3, 24), (0.3, 0.5, 10)]:
        a.box(u0, u1, y0 - 0.03, y1 + 0.03, 0, min(h, 6), SAND_B, SAND_L, SAND_R)
        if h > 6:
            a.box(u0, u1, y0, y1, 6, h, SAND_T, SAND_L, SAND_R)
        x, y = P(u1 - 0.04, y1, h)
        a.poly([(x - 5, y), (x - 2, y - 4), (x + 2, y + 1)], "#5a4428", stroke=None)
    _sand_drift(a, rng, 3, -0.4, 0.4, 0.15, 0.4)
    _sand_rubble(a, rng, 8, -0.45, 0.45, 0.18, 0.42)
    a.save("sandstone_wall_ruin")


def _pointed_arch(g0, g1, gy, z_spring, z_apex, steps=6):
    """The outline of a pointed arch on a front face: [left foot ... apex ... right foot]."""
    gm = (g0 + g1) / 2
    w = (g1 - g0) / 2
    left, right = [], []
    for k in range(steps + 1):
        t = k / steps
        ang = math.pi / 2 * t
        u = w - w * (1 - math.cos(ang)) * 1.0
        z = z_spring + (z_apex - z_spring) * math.sin(ang) ** 1.4
        left.append(P(gm - u, gy, z))
        right.append(P(gm + u, gy, z))
    return [P(g0, gy, 0)] + left + [P(gm, gy, z_apex)] + right[::-1] + [P(g1, gy, 0)]


def sand_gate(level=1):
    a = Art()
    x0, x1, y0, y1 = -0.5, 0.5, -0.16, 0.16
    for g0, g1 in [(x0, -0.22), (0.22, x1)]:
        a.box(g0, g1, y0 - 0.03, y1 + 0.03, 0, 6, SAND_B, SAND_L, SAND_R)
        a.box(g0, g1, y0, y1, 6, 50, SAND_T, SAND_L, SAND_R)
        _sand_ashlar(a, g0, g1, y1, 6, 50, 3, 920 + int(g0 * 10))
        a.box(g0, g1, y0 - 0.02, y1 + 0.02, 50, 53, SAND_T, SAND_B, SAND_R)
    a.box(-0.22, 0.22, y0, y1, 0, 44, SAND_T, SAND_L, SAND_R)
    arch = _pointed_arch(-0.17, 0.17, y1, 18, 36)
    a.poly(arch, "#5a3e24", INK, 1.2)
    for gx in (-0.09, 0.0, 0.09):
        a.line([P(gx, y1, 0), P(gx, y1, 33 if gx == 0 else 28)], "#3b2a1a", 1.2)
    a.line(arch[1:-1], SAND_B, 3.4)  # voussoirs round the arch
    a.line(arch[1:-1], INK, 0.9)
    a.line([P(-0.17, y1, 14), P(0.17, y1, 14)], IRON_L, 1.5)
    if level >= 2:
        for z in (6, 22):
            for gx in (-0.13, -0.04, 0.04, 0.13):
                x, y = P(gx, y1, z)
                a.ellipse(x, y, 1.2, 1.2, BRASS)
        _tile_band(a, -0.22, 0.22, y1, 38, 43)
    # Veliron's banners on the towers
    hanging_banner(a, ("left", y1), -0.4, -0.3, 46, 20)
    hanging_banner(a, ("left", y1), 0.3, 0.4, 46, 20)
    for gx in (x0, 0.26):
        _sand_merlon(a, gx, y0, 0.12, y1 - y0, 53, gold=level >= 3)
        _sand_merlon(a, gx + 0.12, y0, 0.12, y1 - y0, 53, gold=level >= 3)
    if level >= 3:
        for gx in (-0.2, 0.2):
            x, y = P(gx, y1 + 0.03, 30)
            a.ellipse(x, y, 8, 8, GLOW, opacity=0.3)
            a.line([(x, y - 9), (x, y - 5)], INK, 1)
            a.poly([(x - 3, y - 5), (x + 3, y - 5), (x + 2, y + 3), (x - 2, y + 3)], GLOW, BRASS, 1.1)
        a.line([P(-0.22, y1, 44), P(0.22, y1, 44)], GOLD, 2)
    a.save("sandstone_gate" if level == 1 else "sandstone_gate_%d" % level)


def sand_gate_ruin():
    rng = random.Random(930)
    a = Art()
    y0, y1 = -0.16, 0.16
    a.poly(diamond(0.75, 0.42), "#3a3024", stroke=None, opacity=0.4)
    a.box(-0.5, -0.22, y0 - 0.03, y1 + 0.03, 0, 6, SAND_B, SAND_L, SAND_R)
    a.box(-0.5, -0.22, y0, y1, 6, 30, SAND_T, SAND_L, SAND_R)
    a.box(0.22, 0.5, y0 - 0.03, y1 + 0.03, 0, 6, SAND_B, SAND_L, SAND_R)
    a.box(0.22, 0.5, y0, y1, 6, 16, SAND_T, SAND_L, SAND_R)
    # the arch's keystone and voussoirs fallen in the opening, the doors burnt
    a.poly([P(-0.18, y1 + 0.04, 0), P(0.14, y1 + 0.06, 0), P(0.18, y1 + 0.32, 0), P(-0.14, y1 + 0.28, 0)], "#3a2818", INK, 1.2)
    _sand_drift(a, rng, 3, -0.4, 0.4, 0.2, 0.42)
    _sand_rubble(a, rng, 9, -0.45, 0.45, 0.2, 0.45)
    a.poly([P(-0.4, y1, 28), P(-0.3, y1, 28), P(-0.31, y1, 14), P(-0.35, y1, 18), P(-0.39, y1, 12)], CRIMSON_D, INK, 0.9)
    a.save("sandstone_gate_ruin")


def sand_wall_tower(front=False, level=1):
    a = Art()
    s, h = 0.36, 74
    k = 0.13
    if front:
        a._track([P(-s, s, 0), P(s, -s, 0), P(-s, -s, h + 60), P(s, s, 0)])
        for gx, gy in _merlon_spots(s + 0.04, True, k):
            _sand_merlon(a, gx, gy, k, k, h + 4, gold=level >= 3)
        return a
    a.shadow(52, 26, cy=4)
    a.box(-s - 0.04, s + 0.04, -s - 0.04, s + 0.04, 0, 8, SAND_B, SAND_L, SAND_R)
    a.box(-s, s, -s, s, 8, h, SAND_T, SAND_L, SAND_R)
    for z0, z1 in [(26, 30), (50, 54)]:  # darker courses
        a.poly([P(-s, s, z0), P(s, s, z0), P(s, s, z1), P(-s, s, z1)], SAND_B, stroke=None)
        a.poly([P(s, s, z0), P(s, -s, z0), P(s, -s, z1), P(s, s, z1)], SAND_D, stroke=None, opacity=0.6)
    _sand_ashlar(a, -s, s, s, 8, 26, 1, 940)
    _sand_ashlar(a, -s, s, s, 30, 50, 2, 941)
    _sand_ashlar_right(a, s, -s, s, 8, 26, 1, 942)
    _sand_ashlar_right(a, s, -s, s, 30, 50, 2, 943)
    for u in (-0.18, 0.12):  # arrow slits
        a.poly([P(u, s, 36), P(u + 0.04, s, 36), P(u + 0.04, s, 48), P(u + 0.02, s, 50), P(u, s, 48)], "#2a1e12", INK, 0.8)
    a.poly([P(s, -0.02, 38), P(s, -0.06, 38), P(s, -0.06, 48), P(s, -0.04, 50), P(s, -0.02, 48)], "#2a1e12", INK, 0.8)
    a.box(-s - 0.04, s + 0.04, -s - 0.04, s + 0.04, h, h + 4, SAND_T, SAND_B, SAND_R)
    for gx, gy in _merlon_spots(s + 0.04, False, k):
        _sand_merlon(a, gx, gy, k, k, h + 4, gold=level >= 3)
    if level >= 2:
        _tile_band(a, -s, s, s, h - 7, h - 1)
        _tile_band_right(a, s, -s, s, h - 7, h - 1)
        hanging_banner(a, ("left", s), -0.22, -0.02, h - 8, h - 36)
    if level >= 3:
        hanging_banner(a, ("right", s), -0.12, 0.08, h - 8, h - 36)
        a.line([P(-s - 0.04, s + 0.04, h + 4), P(s + 0.04, s + 0.04, h + 4), P(s + 0.04, -s - 0.04, h + 4)], GOLD, 2)
        bx, by = P(0.16, -0.16, h + 4)  # inside, between the back and front merlons
        a.ellipse(bx, by - 14, 16, 12, GLOW, opacity=0.35)
        a.poly([(bx - 6, by - 6), (bx + 6, by - 6), (bx + 4, by), (bx - 4, by)], BRASS, INK, 1)
        a.poly([(bx - 4, by - 6), (bx, by - 18), (bx + 4, by - 6)], GLOW, "#b8401e", 1)
    return a


def sand_wall_tower_ruin():
    rng = random.Random(950)
    a = Art()
    s, h = 0.36, 30
    a.shadow(52, 26, cy=4)
    a.box(-s - 0.04, s + 0.04, -s - 0.04, s + 0.04, 0, 8, SAND_B, SAND_L, SAND_R)
    a.box(-s, s, -s, s, 8, h, SAND_T, SAND_L, SAND_R)
    a.box(-s, -s + 0.22, -s, -s + 0.22, h, h + 24, SAND_T, SAND_L, SAND_R)
    a.box(-s, s - 0.3, -s, -s + 0.14, h, h + 10, SAND_T, SAND_L, SAND_R)
    a.poly([P(-s, s, 22), P(s, s, 22), P(s, s, 26), P(-s, s, 26)], SAND_B, stroke=None)
    for gx in (-0.2, 0.05, 0.25):
        x, y = P(gx, s, h)
        a.poly([(x - 6, y), (x - 2, y + 6), (x + 3, y - 1)], "#5a4428", stroke=None)
    x, y = P(0.0, s, 18)
    a.poly([(x - 4, y - 7), (x + 4, y - 7), (x + 4, y + 2), (x - 4, y + 2)], "#2a1e12")
    _sand_drift(a, rng, 3, -0.4, 0.4, 0.4, 0.55)
    for _ in range(10):
        gx, gy = rng.uniform(-0.5, 0.5), rng.uniform(0.4, 0.55)
        if rng.random() < 0.5:
            gx, gy = rng.uniform(0.4, 0.55), rng.uniform(-0.5, 0.5)
        x, y = P(gx, gy)
        w = rng.uniform(3.5, 6.5)
        a.poly([(x - w, y), (x - w * 0.5, y - w * 0.75), (x + w * 0.6, y - w * 0.65), (x + w, y)], rng.choice([SAND_L, SAND_R, SAND_B]), INK, 1)
    a.save("sandstone_wall_tower_ruin")


DOOR_BLUE, DOOR_BLUE_D = "#2a6db0", "#1d4f82"


def _parapet(a, x0, x1, y0, y1, z, cols, part, t=0.035, hgt=4):
    """A low rim round a flat roof: its "back" two sides (drawn before what
    stands on the roof) or its "front" two (after)."""
    if part == "back":
        a.box(x0, x1, y0, y0 + t, z, z + hgt, *cols, sw=1.1)
        a.box(x0, x0 + t, y0, y1, z, z + hgt, *cols, sw=1.1)
    else:
        a.box(x1 - t, x1, y0, y1, z, z + hgt, *cols, sw=1.1)
        a.box(x0, x1, y1 - t, y1, z, z + hgt, *cols, sw=1.1)


def sand_hut(ruin=False):
    """Sandstone: a cube house of the walls' sandstone on a plinth, a flat roof
    with a parapet, a little roof room with a dome, a blue arched door, blue
    shutters and a band of blue tiles."""
    rng = random.Random(1100)
    a = Art()
    x0, x1, y0, y1, h = -0.34, 0.34, -0.3, 0.3, 30
    if ruin:
        a.poly(diamond(0.8), "#3a3024", stroke=None, opacity=0.5)
        tops = [h * f for f in (0.75, 0.45, 0.6, 0.25, 0.5)]
        pts = [P(x0, y1, 0), P(x1, y1, 0)] + [P(x0 + (x1 - x0) * k / 4.0, y1, tops[k]) for k in range(4, -1, -1)]
        a.poly(pts, SAND_L, INK, 1.3)
        tops_r = [h * f for f in (0.5, 0.85, 0.4, 0.7, 0.3)]
        pts_r = [P(x1, y1, 0), P(x1, y0, 0)] + [P(x1, y1 + (y0 - y1) * k / 4.0, tops_r[k]) for k in range(4, -1, -1)]
        a.poly(pts_r, SAND_R, INK, 1.3)
        _opening(a, "side", x1, 0.12, -0.04, 6, 16, "#1c1712")
        a.poly([P(-0.2, y1 + 0.06, 0), P(0.02, y1 + 0.08, 0), P(0.06, y1 + 0.3, 0), P(-0.16, y1 + 0.28, 0)], DOOR_BLUE_D, INK, 1.1)  # the door, fallen
        for _ in range(7):
            x, y = P(rng.uniform(-0.3, 0.4), rng.uniform(0.32, 0.55))
            w = rng.uniform(3, 5.5)
            a.poly([(x - w, y), (x - w * 0.5, y - w * 0.7), (x + w * 0.6, y - w * 0.6), (x + w, y)], rng.choice([SAND_L, SAND_R, SAND_B]), INK, 1)
        a.line([P(-0.1, 0.0, 2), P(0.2, -0.15, 12)], INK, 4.5)
        a.line([P(-0.1, 0.0, 2), P(0.2, -0.15, 12)], "#2a1e15", 2.6)  # a charred roof beam
        a.save("sandstone_hut_ruin")
        return
    a.shadow(44, 22, cy=4)
    a.box(x0 - 0.03, x1 + 0.03, y0 - 0.03, y1 + 0.03, 0, 5, SAND_B, SAND_L, SAND_R)
    a.box(x0, x1, y0, y1, 5, h, SAND_T, SAND_L, SAND_R)
    _sand_ashlar(a, x0, x1, y1, 5, h, 2, 1101)
    _sand_ashlar_right(a, x1, y0, y1, 5, h, 2, 1102)
    _tile_band(a, x0, x1, y1, h - 5, h - 1)
    _tile_band_right(a, x1, y0, y1, h - 5, h - 1)
    _parapet(a, x0, x1, y0, y1, h, (SAND_T, SAND_B, SAND_R), "back")
    # the roof room at the back, with a little dome
    a.box(x0 + 0.04, -0.02, y0 + 0.04, -0.04, h, h + 16, SAND_T, SAND_L, SAND_R, sw=1.2)
    _opening(a, "front", -0.04, -0.2, -0.1, h, h + 10, DOOR_BLUE, arch=4, sw=1)
    cx, cy = P((x0 + 0.04 - 0.02) / 2, (y0 + 0.04 - 0.04) / 2, h + 16)
    dome = [(cx + math.cos(math.pi * k / 12) * 13, cy - math.sin(math.pi * k / 12) * 11) for k in range(13)]
    a.poly(dome, SAND_T, INK, 1.2)
    a.poly([(cx, cy - 11)] + [(cx + math.cos(math.pi * k / 12) * 13, cy - math.sin(math.pi * k / 12) * 11) for k in range(0, 7)], SAND_R, stroke=None, opacity=0.6)
    a.line([(cx, cy - 11), (cx, cy - 16)], INK, 1.4)
    _parapet(a, x0, x1, y0, y1, h, (SAND_T, SAND_B, SAND_R), "front")
    # the blue arched door, blue shutters, a lit window
    _opening(a, "front", y1, -0.1, 0.06, 0, 16, DOOR_BLUE, arch=6, sw=1.1)
    for gx, gy in [(-0.04, y1), (0.0, y1)]:
        x, y = P(gx, gy, 8)
        a.ellipse(x, y, 0.9, 0.9, "#c9d6e6")
    _opening(a, "front", y1, 0.16, 0.26, 10, 19, GLOW, sw=1)
    a.poly([P(0.13, y1, 10), P(0.16, y1, 10), P(0.16, y1, 19), P(0.13, y1, 19)], DOOR_BLUE, INK, 0.8)
    a.poly([P(0.26, y1, 10), P(0.29, y1, 10), P(0.29, y1, 19), P(0.26, y1, 19)], DOOR_BLUE, INK, 0.8)
    _opening(a, "side", x1, 0.12, -0.02, 11, 20, "#1c2430", sw=1)
    a.poly([P(x1, 0.15, 11), P(x1, 0.12, 11), P(x1, 0.12, 20), P(x1, 0.15, 20)], DOOR_BLUE_D, INK, 0.8)
    a.poly([P(x1, -0.02, 11), P(x1, -0.05, 11), P(x1, -0.05, 20), P(x1, -0.02, 20)], DOOR_BLUE_D, INK, 0.8)
    a.save("sandstone_hut")
