"""Village pieces in basalt."""

import random

from ..core import (
    Art, CRIMSON_D, diamond, GLOW, hanging_banner, INK, IRON, IRON_L, _merlon_spots,
    _opening, P,
)


# Basalt: dark volcanic columns (columnar jointing) of uneven height with an
# obsidian sheen, jagged merlons; level 2 iron spikes and bands, level 3 lava
# glowing in the seams and ember braziers.

BAS_T, BAS_L, BAS_R, BAS_D = "#5a5862", "#45434d", "#312f37", "#1d1c22"
OBSIDIAN, SHEEN = "#24202c", "#8a84a8"
LAVA, LAVA_GLOW = "#e8642a", "#ff9a3c"


def _bas_column(a, rng, g0, g1, gy0, gy1, z0, z1, sheen=True, right=BAS_R):
    a.box(g0, g1, gy0, gy1, z0, z1, BAS_T, BAS_L, right, sw=1.1)
    if rng.random() < 0.5:  # a cross joint
        z = rng.uniform(z0 + 6, z1 - 6)
        a.line([P(g0, gy1, z), P(g1, gy1, z + rng.uniform(-1.5, 1.5))], BAS_D, 1)
    if sheen and rng.random() < 0.45:  # an obsidian glint
        u = g0 + (g1 - g0) * 0.35
        z = rng.uniform(z0 + 6, z1 - 8)
        a.line([P(u, gy1, z), P(u + (g1 - g0) * 0.3, gy1, z + 6)], SHEEN, 1.2, opacity=0.8)


def _spike(a, x, y, h=7):
    a.poly([(x - 1.8, y), (x, y - h), (x + 1.8, y)], "#2a2a2e", INK, 0.8)
    a.line([(x - 0.6, y - 1), (x, y - h + 1)], IRON_L, 0.6, opacity=0.8)


def _seam(a, pts):
    a.line(pts, LAVA_GLOW, 4, opacity=0.35)
    a.line(pts, LAVA, 1.5)


def bas_wall(level=1):
    rng = random.Random(960 + level)
    a = Art()
    y0, y1, h = -0.14, 0.14, 34
    a.poly(diamond(0.62, 0.24), "#1a1816", stroke=None, opacity=0.35)
    n = 10
    tops = []
    for k in range(n):
        g0 = -0.5 + k / n
        tall = k % 3 == 1
        hh = h + rng.uniform(-3, 2) + (9 if tall else 0)
        _bas_column(a, rng, g0, g0 + 1 / n, y0, y1, 0, hh)
        tops.append((g0, hh, tall))
        if level >= 2 and tall:
            x, y = P(g0 + 0.5 / n, 0, hh)
            _spike(a, x, y)
    if level >= 2:
        a.line([P(-0.5, y1, 10), P(0.5, y1, 10)], IRON, 2.6)
        for gx in (-0.35, -0.05, 0.25):
            x, y = P(gx, y1, 10)
            a.ellipse(x, y, 1.2, 1.2, IRON_L)
    if level >= 3:
        for k in (2, 5, 8):
            g = -0.5 + k / n
            _seam(a, [P(g, y1, 2), P(g, y1, 12), P(g + 0.01, y1, 20), P(g, y1, 26)])
        _seam(a, [P(-0.2, y1, 18), P(-0.1, y1, 19)])
    a.save("basalt_wall" if level == 1 else "basalt_wall_%d" % level)


def bas_wall_ruin():
    rng = random.Random(970)
    a = Art()
    y0, y1 = -0.14, 0.14
    a.poly(diamond(0.75, 0.4), "#1a1816", stroke=None, opacity=0.5)
    n = 10
    for k in range(n):
        g0 = -0.5 + k / n
        hh = rng.choice([3, 6, 9, 14, 20, 4, 11])
        _bas_column(a, rng, g0, g0 + 1 / n, y0, y1, 0, hh, sheen=False)
    for (g0, d0) in [(-0.4, 0.22), (0.05, 0.3), (-0.1, -0.35)]:  # toppled columns
        a.box(g0, g0 + 0.32, d0, d0 + 0.09, 0, 6, BAS_T, BAS_L, BAS_R, sw=1.1)
    for _ in range(5):
        x, y = P(rng.uniform(-0.45, 0.45), rng.uniform(0.18, 0.45))
        w = rng.uniform(3, 5.5)
        a.poly([(x - w, y), (x - w * 0.3, y - w * 0.9), (x + w * 0.5, y - w * 0.6), (x + w, y)], rng.choice([BAS_L, BAS_R, OBSIDIAN]), INK, 1)
    for _ in range(3):
        x, y = P(rng.uniform(-0.4, 0.4), rng.uniform(0.1, 0.4))
        a.ellipse(x, y, 2, 1.3, LAVA, opacity=0.6)
    a.save("basalt_wall_ruin")


def bas_gate(level=1):
    rng = random.Random(980 + level)
    a = Art()
    y0, y1 = -0.16, 0.16
    a.poly(diamond(0.62, 0.26), "#1a1816", stroke=None, opacity=0.35)
    beside = {}  # the tops of the two columns beside the door
    def door():
        """The door, thick iron-bound planks."""
        a.box(-0.22, 0.22, y1 - 0.13, y1 - 0.04, 0, 34, "#5a4430", "#2e2218", "#1e160e", sw=1.2)  # thick planks: the top edge shows
        for gx in (-0.15, -0.04, 0.07, 0.18):
            a.line([P(gx, y1 - 0.13, 34), P(gx, y1 - 0.04, 34)], "#3a2a1c", 1)
        for gx in (-0.11, 0.0, 0.11):
            a.line([P(gx, y1 - 0.04, 0), P(gx, y1 - 0.04, 34)], "#1a120c", 1.4)
        for z in (6, 26):
            a.line([P(-0.22, y1 - 0.04, z), P(0.22, y1 - 0.04, z)], IRON, 2.6 if level >= 2 else 1.8)
        if level >= 2:
            for z in (6, 26):
                for gx in (-0.17, -0.06, 0.06, 0.17):
                    x, y = P(gx, y1 - 0.04, z)
                    a.ellipse(x, y, 1.2, 1.2, IRON_L)
    for g0, g1 in [(-0.5, -0.22), (0.22, 0.5)]:
        if g0 > 0:
            door()  # between the two columns: the right ones cover its side
        for k in range(3):
            c0 = g0 + (g1 - g0) * k / 3
            hh = 48 + rng.uniform(-2, 8)
            if (g0 < 0 and k == 2) or (g0 > 0 and k == 0):
                beside[c0 + (g1 - g0) / 6] = hh
            end = g1 == 0.5 and k == 2  # the end face: in the front faces' shade, no dark bar
            _bas_column(a, rng, c0, c0 + (g1 - g0) / 3, y0, y1, 0, hh, right=BAS_L if end else BAS_R)
            if end:
                for u in (y0 + (y1 - y0) / 3, y0 + 2 * (y1 - y0) / 3):
                    a.line([P(g1, u, 0), P(g1, u, hh)], BAS_D, 1.1)
            if level >= 2:
                x, y = P(c0 + (g1 - g0) / 6, 0, hh)
                _spike(a, x, y, 8)
    hanging_banner(a, ("left", y1), -0.42, -0.32, 44, 20)
    hanging_banner(a, ("left", y1), 0.32, 0.42, 44, 20)
    if level >= 3:
        _seam(a, [P(-0.31, y1, 2), P(-0.31, y1, 16), P(-0.3, y1, 30)])
        _seam(a, [P(0.31, y1, 4), P(0.31, y1, 22)])
        for gx in sorted(beside):  # an ember brazier on each column beside the door
            bx, by = P(gx, 0, beside[gx])
            a.ellipse(bx, by - 12, 12, 10, LAVA_GLOW, opacity=0.3)
            a.poly([(bx - 5, by - 5), (bx + 5, by - 5), (bx + 3, by), (bx - 3, by)], "#2a2a2e", INK, 1)
            a.poly([(bx - 3.5, by - 5), (bx, by - 14), (bx + 3.5, by - 5)], LAVA_GLOW, LAVA, 1)
    a.save("basalt_gate" if level == 1 else "basalt_gate_%d" % level)


def bas_gate_ruin():
    rng = random.Random(990)
    a = Art()
    y0, y1 = -0.16, 0.16
    a.poly(diamond(0.75, 0.42), "#1a1816", stroke=None, opacity=0.5)
    for g0, hs in [(-0.5, (26, 18, 9)), (0.22, (12, 5, 15))]:
        for k in range(3):
            c0 = g0 + 0.28 * k / 3
            _bas_column(a, rng, c0, c0 + 0.28 / 3, y0, y1, 0, hs[k], sheen=False)
    a.box(-0.24, 0.3, 0.2, 0.33, 0, 9, "#3a3644", OBSIDIAN, "#16141c", sw=1.3)  # the lintel on the ground
    a.line([P(-0.15, 0.33, 6), P(0.1, 0.33, 4)], SHEEN, 1.2, opacity=0.7)
    a.poly([P(-0.2, y1 + 0.02, 0), P(0.14, y1 + 0.04, 0), P(0.12, 0.2, 0), P(-0.18, 0.2, 0)], "#2e2218", INK, 1)
    for _ in range(3):
        x, y = P(rng.uniform(-0.4, 0.4), rng.uniform(0.1, 0.45))
        a.ellipse(x, y, 2, 1.3, LAVA, opacity=0.6)
    a.poly([P(-0.42, y1, 24), P(-0.32, y1, 24), P(-0.33, y1, 10), P(-0.37, y1, 14), P(-0.41, y1, 8)], CRIMSON_D, INK, 0.9)
    a.save("basalt_gate_ruin")


def _bas_merlons(a, rng, s, z, front, level, k=0.13):
    for gx, gy in _merlon_spots(s, front, k):
        hh = rng.uniform(8, 13)
        a.box(gx, gx + k, gy, gy + k, z, z + hh, BAS_T, BAS_L, BAS_R, sw=1.1)
        x, y = P(gx + k * 0.5, gy + k * 0.5, z + hh)
        a.poly([P(gx, gy + k, z + hh), (x, y - 5), P(gx + k, gy + k, z + hh)], BAS_L, INK, 0.9)  # a jagged top
        a.poly([P(gx + k, gy + k, z + hh), (x, y - 5), P(gx + k, gy, z + hh)], BAS_R, INK, 0.9)
        if level >= 2:
            _spike(a, x, y - 4, 6)


def bas_wall_tower(front=False, level=1):
    rng = random.Random(1000 + level)
    a = Art()
    s, h = 0.36, 74
    if front:
        a._track([P(-s, s, 0), P(s, -s, 0), P(-s, -s, h + 60), P(s, s, 0)])
        _bas_merlons(a, random.Random(1010), s + 0.03, h + 4, True, level)
        return a
    a.shadow(52, 26, cy=4)
    a.box(-s, s, -s, s, 0, h, BAS_T, BAS_L, BAS_R)
    for k in range(1, 6):  # the columns' joints on both faces, staggered cross joints
        u = -s + 2 * s * k / 6
        a.line([P(u, s, 0), P(u, s, h)], BAS_D, 1.1)
        a.line([P(s, -u, 0), P(s, -u, h)], BAS_D, 1.1)
    for k in range(6):
        u = -s + 2 * s * (k + 0.5) / 6
        for z in (rng.uniform(12, 28), rng.uniform(40, 62)):
            a.line([P(u - s / 6, s, z), P(u + s / 6, s, z + rng.uniform(-2, 2))], BAS_D, 0.9)
            z2 = z + rng.uniform(-6, 6)
            a.line([P(s, -u - s / 6, z2), P(s, -u + s / 6, z2 + rng.uniform(-2, 2))], "#17161b", 0.9)
        if rng.random() < 0.5:
            z = rng.uniform(16, 60)
            a.line([P(u - 0.02, s, z), P(u + 0.03, s, z + 8)], SHEEN, 1.2, opacity=0.75)
    a.poly([P(-0.05, s, 34), P(0.05, s, 34), P(0.05, s, 48), P(-0.05, s, 48)], "#0e0c10")
    a.box(-s - 0.03, s + 0.03, -s - 0.03, s + 0.03, h, h + 4, "#3a3644", OBSIDIAN, "#16141c")
    _bas_merlons(a, random.Random(1011), s + 0.03, h + 4, False, level)
    if level >= 2:
        a.line([P(-s, s, h - 3), P(s, s, h - 3), P(s, -s, h - 3)], IRON, 3)
        hanging_banner(a, ("left", s), -0.22, -0.02, h - 6, h - 34)
    if level >= 3:
        _seam(a, [P(-s + 2 * s / 6, s, 2), P(-s + 2 * s / 6, s, 20), P(-s + 2 * s / 6 + 0.01, s, 34)])
        _seam(a, [P(s, -(-s + 4 * s / 6), 4), P(s, -(-s + 4 * s / 6), 30)])
        _seam(a, [P(s, -(-s + 2 * s / 6), 40), P(s, -(-s + 2 * s / 6), 58)])
        bx, by = P(0.16, -0.16, h + 4)  # inside, between the back and front merlons
        a.ellipse(bx, by - 14, 16, 12, LAVA_GLOW, opacity=0.35)
        a.poly([(bx - 6, by - 6), (bx + 6, by - 6), (bx + 4, by), (bx - 4, by)], "#2a2a2e", INK, 1)
        a.poly([(bx - 4, by - 6), (bx, by - 18), (bx + 4, by - 6)], LAVA_GLOW, LAVA, 1)
    return a


def bas_wall_tower_ruin():
    rng = random.Random(1020)
    a = Art()
    s = 0.36
    a.shadow(52, 26, cy=4)
    n = 4
    for j in range(n):  # broken columns, back rows first
        for i in range(n):
            g0, d0 = -s + 2 * s * i / n, -s + 2 * s * j / n
            hh = rng.choice([8, 14, 20, 26, 32, 40]) if (i == 0 or j == 0) else rng.choice([6, 10, 16, 22])
            _bas_column(a, rng, g0, g0 + 2 * s / n, d0, d0 + 2 * s / n, 0, hh, sheen=False)
    for (g0, d0) in [(-0.3, 0.42), (0.38, -0.2)]:
        a.box(g0, g0 + 0.3, d0, d0 + 0.09, 0, 6, BAS_T, BAS_L, BAS_R, sw=1.1)
    for _ in range(7):
        gx, gy = rng.uniform(-0.5, 0.5), rng.uniform(0.4, 0.55)
        if rng.random() < 0.5:
            gx, gy = rng.uniform(0.4, 0.55), rng.uniform(-0.5, 0.5)
        x, y = P(gx, gy)
        w = rng.uniform(3, 6)
        a.poly([(x - w, y), (x - w * 0.3, y - w * 0.9), (x + w * 0.5, y - w * 0.6), (x + w, y)], rng.choice([BAS_L, BAS_R, OBSIDIAN]), INK, 1)
    for _ in range(4):
        x, y = P(rng.uniform(-0.3, 0.3), rng.uniform(-0.2, 0.45))
        a.ellipse(x, y, 2, 1.3, LAVA, opacity=0.6)
    a.save("basalt_wall_tower_ruin")


def bas_hut(ruin=False):
    """Basalt: a squat, solid house of black blocks with thick walls, a steep
    slate roof, a heavy chimney and small deep windows glowing warm."""
    rng = random.Random(1110)
    a = Art()
    x0, x1, y0, y1, h = -0.34, 0.34, -0.3, 0.3, 28
    roof_l, roof_r, roof_back = "#3c3b47", "#2c2b35", "#24232c"
    if ruin:
        a.poly(diamond(0.8), "#1a1816", stroke=None, opacity=0.6)
        for (u0, u1, hh) in [(x0, -0.1, 16), (-0.1, 0.12, 6), (0.12, x1, 12)]:
            a.box(u0, u1, y1 - 0.1, y1, 0, hh, BAS_T, BAS_L, BAS_R, sw=1.2)
        a.box(x1 - 0.1, x1, y0, y1 - 0.1, 0, 20, BAS_T, BAS_L, BAS_R, sw=1.2)
        a.box(x0, x0 + 0.34, y0, y0 + 0.1, 0, 13, BAS_T, BAS_L, BAS_R, sw=1.2)  # the back wall's stump
        for (g0, d0, g1, d1) in [(-0.3, 0.05, 0.2, -0.2), (-0.1, 0.25, 0.3, 0.1)]:
            a.line([P(g0, d0, 2), P(g1, d1, 14)], INK, 4.5)
            a.line([P(g0, d0, 2), P(g1, d1, 14)], "#2a1e15", 2.6)
        for _ in range(7):
            x, y = P(rng.uniform(-0.35, 0.4), rng.uniform(0.32, 0.55))
            w = rng.uniform(3, 5.5)
            a.poly([(x - w, y), (x - w * 0.3, y - w * 0.9), (x + w * 0.5, y - w * 0.6), (x + w, y)], rng.choice([BAS_L, BAS_R, roof_l]), INK, 1)
        for _ in range(3):
            x, y = P(rng.uniform(-0.25, 0.25), rng.uniform(-0.2, 0.25))
            a.ellipse(x, y, 2, 1.3, LAVA, opacity=0.6)
        a.save("basalt_hut_ruin")
        return
    a.shadow(44, 22, cy=4)
    a.box(x0, x1, y0, y1, 0, h, BAS_T, BAS_L, BAS_R)
    for k, z in enumerate((9, 18)):  # block courses, staggered joints
        a.line([P(x0, y1, z), P(x1, y1, z)], BAS_D, 1)
        a.line([P(x1, y1, z), P(x1, y0, z)], "#17161b", 1)
    for k in range(3):
        for j in range(4):
            gx = x0 + 0.08 + j * 0.18 + (0.09 if k % 2 else 0)
            if gx < x1 - 0.03 and not -0.12 < gx < 0.1:
                a.line([P(gx, y1, 9 * k), P(gx, y1, 9 * k + 9)], BAS_D, 1)
    # a heavy iron-bound door and small deep windows, glowing
    a.poly([P(-0.09, y1, 0), P(0.07, y1, 0), P(0.07, y1, 16), P(-0.09, y1, 16)], "#2e2218", INK, 1.2)
    a.line([P(-0.09, y1, 5), P(0.07, y1, 5)], IRON, 1.6)
    a.line([P(-0.09, y1, 11), P(0.07, y1, 11)], IRON, 1.6)
    a.box(-0.12, 0.1, y1, y1 + 0.03, 16, 19, "#3a3644", OBSIDIAN, "#16141c", sw=1)  # an obsidian lintel
    _opening(a, "front", y1, 0.17, 0.25, 9, 16, GLOW, sw=1.1)
    _opening(a, "side", x1, 0.12, 0.02, 9, 16, GLOW, sw=1.1)
    # steep slate roof, ridge along gx (as the cabin's)
    ridge = h + 26
    ym = (y0 + y1) / 2
    ey, ex = 0.04, 0.03
    slope = (ridge - h) / (y1 - ym)
    eave_h = h - slope * ey
    xa, xb = x0 - ex, x1 + ex
    a.poly([P(xa, y0 - ey, eave_h), P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xa, ym, ridge)], roof_back)
    a.poly([P(x1, y0, h), P(x1, ym, ridge), P(x1, y1, h)], BAS_R)
    a.line([P(x1, ym - 0.1, h + 4), P(x1, ym + 0.1, h + 4)], "#17161b", 1)
    a.poly([P(xa, ym, ridge), P(xb, ym, ridge), P(xb, y1 + ey, eave_h), P(xa, y1 + ey, eave_h)], roof_l)
    for t in (0.25, 0.5, 0.75):  # slate courses
        yy = ym + (y1 + ey - ym) * t
        zz = ridge - (ridge - eave_h) * t
        a.line([P(xa, yy, zz), P(xb, yy, zz)], roof_r, 1.3)
    a.line([P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xb, y1 + ey, eave_h)], INK, 2.4)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], "#1d1c22", 3)
    a.box(-0.22, -0.1, -0.1, 0.0, ridge - 14, ridge + 6, BAS_T, BAS_L, BAS_R, sw=1.2)  # a stout chimney
    x, y = P(-0.16, -0.05, ridge + 6)
    a.ellipse(x, y - 3, 6, 4, LAVA_GLOW, opacity=0.35)
    a.save("basalt_hut")
