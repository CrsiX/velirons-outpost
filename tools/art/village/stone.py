"""Village pieces in stone (the first material): wall, gate, wall tower, watchtower,
their ruins and the hut (a timber cabin)."""

import random

from ..core import (
    Art, _block, CRIMSON, CRIMSON_D, diamond, GLOW, GOLD, hanging_banner, INK, P, STONE_D, STONE_L,
    STONE_R, STONE_T, _tuft, WOOD, WOOD_D, WOOD_L,
)


def hut(ruin=False):
    a = Art()
    x0, x1, y0, y1 = -0.34, 0.34, -0.3, 0.3
    if ruin:
        a.poly(diamond(0.8), "#2d2a26", stroke=None, opacity=0.6)
        a.box(x0, x1 - 0.2, y1 - 0.12, y1, 0, 14, STONE_T, "#6a5e4e", "#51483c")
        a.box(x1 - 0.1, x1, y0, y1 - 0.25, 0, 20, STONE_T, "#6a5e4e", "#51483c")
        a.box(-0.1, 0.1, -0.05, 0.1, 0, 6, "#5a5047", "#4a4138", "#3a332c")
        a.line([P(-0.3, 0.1, 2), P(0.2, -0.2, 18)], INK, 4.5)
        a.line([P(-0.3, 0.1, 2), P(0.2, -0.2, 18)], "#2a1e15", 2.6)
        a.line([P(-0.1, 0.25, 1), P(0.3, 0.15, 10)], INK, 4)
        a.line([P(-0.1, 0.25, 1), P(0.3, 0.15, 10)], "#3a2a1c", 2.2)
        for gx, gy in [(-0.2, -0.15), (0.15, 0.2), (0.25, -0.1)]:
            x, y = P(gx, gy)
            a.ellipse(x, y, 3.5, 2.2, "#6b665e", INK, 1)
        a.save("hut_ruin")
        return
    a.shadow(44, 22, cy=4)
    h, ridge, e = 26, 54, 0.07
    a.box(x0, x1, y0, y1, 0, h, "#8c7b62", "#8c7b62", "#6c5e4a")
    # timber framing on the left face
    for t in (0.0, 0.5, 1.0):
        gx = x0 + (x1 - x0) * t
        a.line([P(gx, y1, 0), P(gx, y1, h)], "#3b2a1d", 2)
    a.line([P(x0, y1, h * 0.5), P(x1, y1, h * 0.5)], "#3b2a1d", 1.6)
    # door + lit window
    a.poly([P(-0.08, y1, 0), P(0.08, y1, 0), P(0.08, y1, 17), P(-0.08, y1, 17)], "#2b1e14")
    a.poly([P(x1, 0.15, 10), P(x1, -0.05, 10), P(x1, -0.05, 19), P(x1, 0.15, 19)], GLOW)
    a.line([P(x1, 0.05, 10), P(x1, 0.05, 19)], "#3b2a1d", 1.2)
    # Gable roof, ridge along gx. The eaves overhang the walls along the roof
    # pitch (so they drop below the wall top), the gable wall reaches the ridge,
    # and barge boards close both roof ends so nothing looks detached.
    ym = (y0 + y1) / 2
    ey, ex = 0.07, 0.03  # overhang across / along the ridge
    slope = (ridge - h) / (y1 - ym)
    eave_h = h - slope * ey
    xa, xb = x0 - ex, x1 + ex
    back = [P(xa, y0 - ey, eave_h), P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xa, ym, ridge)]
    front = [P(xa, ym, ridge), P(xb, ym, ridge), P(xb, y1 + ey, eave_h), P(xa, y1 + ey, eave_h)]
    gable = [P(x1, y0, h), P(x1, ym, ridge), P(x1, y1, h)]
    a.poly(back, "#4a3b24")
    a.poly(gable, "#7a6a52")
    a.line([P(x1, ym, ridge - 8), P(x1, ym, h)], "#3b2a1d", 1.4)  # gable timber
    a.poly(front, "#5b4a2e")
    for t in (0.33, 0.66):
        yy = ym + (y1 + ey - ym) * t
        zz = ridge - (ridge - eave_h) * t
        a.line([P(xa, yy, zz), P(xb, yy, zz)], "#43351f", 1.2)
    # barge board along the visible (right) roof end
    a.line([P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xb, y1 + ey, eave_h)], "#3b2a1d", 3.2)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], "#3b2a1d", 2.4)  # ridge beam
    # chimney
    a.box(0.14, 0.24, -0.1, 0.0, ridge - 14, ridge + 8, STONE_T, STONE_L, STONE_R)
    a.save("hut")


STONE_BRICK = (0.2, 11)  # one brick's length and height: walls, gates and wall towers alike


def _stone_bricks(a, rng, face, u0, u1, at, z0, z1, faint=0):
    """Brick courses on a stone face ('front': u along gx at gy=at; 'side': u along -gy
    at gx=at), head joints staggered course by course and aligned to the tile grid so
    neighbouring pieces match; `faint` bricks a shade darker."""
    bw, bh = STONE_BRICK

    def at_(u, z):
        return P(u, at, z) if face == "front" else P(at, -u, z)
    zs = [z0]
    while zs[-1] + bh < z1 - 3:
        zs.append(zs[-1] + bh)
    bricks = []
    for i, z in enumerate(zs):
        zt = zs[i + 1] if i + 1 < len(zs) else z1
        if i > 0:
            a.line([at_(u0, z), at_(u1, z)], STONE_D, 1)
        u = -0.5 + bw * 0.5 * (i % 2)
        edges = [u0]
        while u < u1:
            if u0 + 0.04 < u < u1 - 0.04:
                a.line([at_(u, z), at_(u, zt)], STONE_D, 1)
                edges.append(u)
            u += bw
        edges.append(u1)
        bricks += [(e0, e1, z, zt) for e0, e1 in zip(edges, edges[1:])]
    for e0, e1, z, zt in rng.sample(bricks, min(faint, len(bricks))):
        colour, op = (STONE_D, 0.35) if face == "front" else ("#2a2622", 0.25)
        a.poly([at_(e0, z), at_(e1, z), at_(e1, zt), at_(e0, zt)], colour, stroke=None, opacity=op)
    a.poly([at_(u0, z0), at_(u1, z0), at_(u1, z1), at_(u0, z1)], "none")  # the outline again, over the joints' ends


def wall(level=1):
    a = Art()
    x0, x1, y0, y1, h = -0.5, 0.5, -0.14, 0.14, 34
    a.box(x0, x1, y0, y1, 0, h, STONE_T, STONE_L, STONE_R)
    rng = random.Random(450 + level)
    _stone_bricks(a, rng, "front", x0, x1, y1, 0, h, faint=2)
    _stone_bricks(a, rng, "side", -y1, -y0, x1, 0, h)
    if level >= 2:  # iron bands and a crimson pennon
        for z in (5, h - 3):
            a.line([P(x0, y1, z), P(x1, y1, z)], "#3a3632", 2.6)
        for gx in (-0.3, 0.1):
            for z in (5, h - 3):
                x, y = P(gx, y1, z)
                a.ellipse(x, y, 1.3, 1.3, "#8a8a8a")
        a.cloth([P(-0.08, y1, h - 2), P(0.08, y1, h - 2), P(0.08, y1, 12), P(0.0, y1, 16), P(-0.08, y1, 12)], sw=1.1)
    for gx in (-0.42, -0.08, 0.26):
        a.box(gx, gx + 0.16, y0, y1, h, h + 8, STONE_T, STONE_L, STONE_R)
        if level >= 3:  # gilded merlon caps
            a.line([P(gx, y1, h + 8), P(gx + 0.16, y1, h + 8), P(gx + 0.16, y0, h + 8)], GOLD, 1.6)
    if level >= 3:
        a.line([P(x0, y1, h), P(x1, y1, h)], GOLD, 1.8)
    a.save("wall" if level == 1 else "wall_%d" % level)


def wall_ruin():
    rng = random.Random(701)
    a = Art()
    y0, y1 = -0.14, 0.14
    a.poly(diamond(0.75, 0.4), "#2d2a26", stroke=None, opacity=0.45)
    for (u0, u1, h) in [(-0.5, -0.22, 16), (-0.22, 0.05, 6), (0.05, 0.3, 21), (0.3, 0.5, 9)]:  # broken stubs
        a.box(u0, u1, y0, y1, 0, h, STONE_T, STONE_L, STONE_R)
        x, y = P(u1 - 0.04, y1, h)
        a.poly([(x - 5, y), (x - 2, y - 4), (x + 2, y + 1)], "#2a2622", stroke=None)  # chipped edge
    for _ in range(9):  # fallen blocks in front
        x, y = P(rng.uniform(-0.45, 0.45), rng.uniform(0.18, 0.42))
        _block(a, rng, x, y, rng.uniform(3.5, 6))
    for _ in range(3):
        x, y = P(rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.3))
        _tuft(a, x, y, "#3c5226")
    a.save("wall_ruin")


def gate(level=1):
    a = Art()
    x0, x1, y0, y1 = -0.5, 0.5, -0.16, 0.16
    # back to front: the left pillar, the lintel and the doors, then the right pillar over them
    rng = random.Random(500 + level)
    a.box(x0, -0.22, y0, y1, 0, 46, STONE_T, STONE_L, STONE_R)
    _stone_bricks(a, rng, "front", x0, -0.22, y1, 0, 46, faint=1)
    a.box(-0.22, 0.22, y0, y1, 30, 42, STONE_T, STONE_L, STONE_R)
    _stone_bricks(a, rng, "front", -0.22, 0.22, y1, 30, 42)
    # doors in the opening
    a.poly([P(-0.22, y1 - 0.04, 0), P(0.22, y1 - 0.04, 0), P(0.22, y1 - 0.04, 30), P(-0.22, y1 - 0.04, 30)], WOOD_D)
    for gx in (-0.11, 0.0, 0.11):
        a.line([P(gx, y1 - 0.04, 0), P(gx, y1 - 0.04, 30)], "#2b1e14", 1.4)
    a.line([P(-0.22, y1 - 0.04, 14), P(0.22, y1 - 0.04, 14)], "#8a8a8a", 1.6)
    if level >= 2:  # iron straps and studs on the doors
        for z in (6, 23):
            a.line([P(-0.22, y1 - 0.04, z), P(0.22, y1 - 0.04, z)], "#3a3632", 2.6)
            for gx in (-0.17, -0.06, 0.06, 0.17):
                x, y = P(gx, y1 - 0.04, z)
                a.ellipse(x, y, 1.2, 1.2, "#9a9a9a")
    a.box(0.22, x1, y0, y1, 0, 46, STONE_T, STONE_L, STONE_R)
    _stone_bricks(a, rng, "front", 0.22, x1, y1, 0, 46, faint=1)
    _stone_bricks(a, rng, "side", -y1, -y0, x1, 0, 46)
    for gx in (-0.5, -0.36, 0.22, 0.36):
        a.box(gx, gx + 0.14, y0, y1, 46, 54, STONE_T, STONE_L, STONE_R)
        if level >= 3:
            a.line([P(gx, y1, 54), P(gx + 0.14, y1, 54), P(gx + 0.14, y0, 54)], GOLD, 1.6)
    # Veliron banner
    a.cloth([P(-0.36, y1, 44), P(-0.26, y1, 44), P(-0.26, y1, 18), P(-0.31, y1, 23), P(-0.36, y1, 18)], sw=1.4)
    a.cloth([P(0.26, y1, 44), P(0.36, y1, 44), P(0.36, y1, 18), P(0.31, y1, 23), P(0.26, y1, 18)], sw=1.4)
    x, y = P(-0.31, y1, 34)
    a.ellipse(x, y, 2.2, 2.2, GOLD)
    x, y = P(0.31, y1, 34)
    a.ellipse(x, y, 2.2, 2.2, GOLD)
    if level >= 3:  # gold trim over the arch and two lanterns
        a.line([P(-0.22, y1, 42), P(0.22, y1, 42)], GOLD, 2)
        for gx in (-0.2, 0.2):
            x, y = P(gx, y1 + 0.02, 28)
            a.ellipse(x, y, 7, 7, GLOW, opacity=0.3)
            a.poly([(x - 2.5, y - 3.5), (x + 2.5, y - 3.5), (x + 2.5, y + 3.5), (x - 2.5, y + 3.5)], GLOW, INK, 0.9)
    a.save("gate" if level == 1 else "gate_%d" % level)


def gate_ruin():
    rng = random.Random(702)
    a = Art()
    y0, y1 = -0.16, 0.16
    a.poly(diamond(0.75, 0.42), "#2d2a26", stroke=None, opacity=0.45)
    a.box(-0.5, -0.22, y0, y1, 0, 26, STONE_T, STONE_L, STONE_R)
    a.box(0.22, 0.5, y0, y1, 0, 15, STONE_T, STONE_L, STONE_R)
    for (gx, h) in [(-0.24, 26), (0.48, 15)]:
        x, y = P(gx, y1, h)
        a.poly([(x - 6, y), (x - 2, y - 5), (x + 3, y + 1)], "#2a2622", stroke=None)
    # the doors torn out, lying in the opening
    a.poly([P(-0.2, y1 + 0.02, 0), P(0.12, y1 + 0.05, 0), P(0.16, y1 + 0.32, 0), P(-0.16, y1 + 0.28, 0)], WOOD_D, INK, 1.2)
    for t in (0.33, 0.66):
        a.line([P(-0.2 + 0.32 * t, y1 + 0.02, 0), P(-0.16 + 0.32 * t, y1 + 0.29, 0)], "#2b1e14", 1.2)
    a.line([P(0.0, y1, 0), P(0.24, y1 + 0.2, 10)], WOOD, 3)  # a splintered plank
    a.line([P(-0.12, y1 + 0.1, 1), P(-0.12, y1 + 0.28, 1)], "#6a6a6a", 1.6)  # a bent strap
    for _ in range(7):
        x, y = P(rng.uniform(-0.45, 0.45), rng.uniform(0.2, 0.45))
        _block(a, rng, x, y, rng.uniform(3, 5.5))
    a.poly([P(-0.36, y1, 24), P(-0.26, y1, 24), P(-0.27, y1, 10), P(-0.32, y1, 15), P(-0.35, y1, 8)], CRIMSON_D, INK, 0.9)  # the torn banner
    a.save("gate_ruin")


def wall_tower_ruin():
    rng = random.Random(703)
    a = Art()
    s, h = 0.36, 30
    a.shadow(52, 26, cy=4)
    a.box(-s, s, -s, s, 0, h, STONE_T, STONE_L, STONE_R)
    # a jagged broken top: the back corner still stands higher
    a.box(-s, -s + 0.22, -s, -s + 0.22, h, h + 26, STONE_T, STONE_L, STONE_R)
    a.box(-s, s - 0.3, -s, -s + 0.14, h, h + 12, STONE_T, STONE_L, STONE_R)
    for z in (10, 20):
        a.line([P(-s, s, z), P(s, s, z)], STONE_D, 1)
        a.line([P(s, s, z), P(s, -s, z)], STONE_D, 1)
    for gx in (-0.2, 0.05, 0.25):
        x, y = P(gx, s, h)
        a.poly([(x - 6, y), (x - 2, y + 6), (x + 3, y - 1)], "#2a2622", stroke=None)
    x, y = P(0.0, s, 16)
    a.poly([(x - 4, y - 7), (x + 4, y - 7), (x + 4, y + 2), (x - 4, y + 2)], "#1a1612")  # the dark doorway
    a.line([P(-s + 0.06, -s + 0.06, h + 26), P(-s + 0.2, -s + 0.02, h + 44)], INK, 3)  # the broken banner pole
    x, y = P(-s + 0.2, -s + 0.02, h + 44)
    a.poly([(x, y), (x + 10, y + 5), (x + 3, y + 10)], CRIMSON_D, INK, 0.9)
    for _ in range(10):
        gx, gy = rng.uniform(-0.5, 0.5), rng.uniform(0.38, 0.55)
        if rng.random() < 0.5:
            gx, gy = rng.uniform(0.38, 0.55), rng.uniform(-0.5, 0.5)
        x, y = P(gx, gy)
        _block(a, rng, x, y, rng.uniform(3.5, 6.5))
    for _ in range(3):
        x, y = P(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), h)
        _tuft(a, x, y, "#3c5226")
    a.save("wall_tower_ruin")


def merlons(a, s, z, front):
    """Merlons around a square top of half-size s. front=True draws only the front edges."""
    k = 0.13
    spots_back = [(-s, -s), (0 - k / 2, -s), (s - k, -s), (-s, 0 - k / 2)]
    spots_front = [(-s, s - k), (0 - k / 2, s - k), (s - k, s - k), (s - k, 0 - k / 2), (s - k, -s)]
    for gx, gy in (spots_front if front else spots_back):
        a.box(gx, gx + k, gy, gy + k, z, z + 9, STONE_T, STONE_L, STONE_R)


def wall_tower(front=False, level=1):
    a = Art()
    s, h = 0.36, 74
    if not front:
        a.shadow(52, 26, cy=4)
        a.box(-s, s, -s, s, 0, h, STONE_T, STONE_L, STONE_R)
        rng = random.Random(3000 + level)
        _stone_bricks(a, rng, "front", -s, s, s, 0, h, faint=6)
        _stone_bricks(a, rng, "side", -s, s, s, 0, h, faint=6)
        a.poly([P(-0.05, s, 34), P(0.05, s, 34), P(0.05, s, 48), P(-0.05, s, 48)], "#1a1612")
        a.box(-s - 0.03, s + 0.03, -s - 0.03, s + 0.03, h, h + 4, STONE_T, STONE_L, STONE_R)
        merlons(a, s + 0.03, h + 4, False)
        if level >= 2:  # crimson banner and an iron ring below the parapet
            hanging_banner(a, ("left", s), -0.22, -0.02, h - 4, h - 34)
            a.line([P(-s, s, h - 2), P(s, s, h - 2), P(s, -s, h - 2)], "#3a3632", 3)
        if level >= 3:  # second banner, gold trim, a brazier burning on top
            hanging_banner(a, ("right", s), -0.12, 0.08, h - 4, h - 34)
            a.line([P(-s - 0.03, s + 0.03, h + 4), P(s + 0.03, s + 0.03, h + 4), P(s + 0.03, -s - 0.03, h + 4)], GOLD, 2)
            for u in (-0.25, 0.0, 0.25):
                for x, y in (P(u, s, h - 2), P(s, -u, h - 2)):  # studs on both faces' ring
                    a.ellipse(x, y, 1.4, 1.4, GOLD)
            bx, by = P(0.16, -0.16, h + 4)  # inside, between the back and front merlons
            a.ellipse(bx, by - 14, 16, 12, GLOW, opacity=0.35)
            a.poly([(bx - 6, by - 6), (bx + 6, by - 6), (bx + 4, by), (bx - 4, by)], "#3a3632", INK, 1)
            a.poly([(bx - 4, by - 6), (bx, by - 18), (bx + 4, by - 6)], GLOW, "#b8401e", 1)
        # Anchor the manifest bbox identically for the front overlay by tracking the same extents.
    else:
        a._track([P(-s, s, 0), P(s, -s, 0), P(-s, -s, h + 60), P(s, s, 0)])
        merlons(a, s + 0.03, h + 4, True)
        if level >= 3:  # gilded merlon caps
            k = 0.13
            for gx, gy in [(-s - 0.03, s + 0.03 - k), (-k / 2, s + 0.03 - k), (s + 0.03 - k, s + 0.03 - k), (s + 0.03 - k, -k / 2), (s + 0.03 - k, -s - 0.03)]:
                a.line([P(gx, gy + k, h + 13), P(gx + k, gy + k, h + 13), P(gx + k, gy, h + 13)], GOLD, 1.6)
    return a


def watchtower(front=False, level=1):
    a = Art()
    s, base_h, post_h, plat = 0.3, 16, 60, 0.38
    if not front:
        a.shadow(46, 23, cy=4)
        a.box(-s, s, -s, s, 0, base_h, STONE_T, STONE_L, STONE_R)
        k = 0.06
        for gx, gy in [(-s + 0.02, -s + 0.02), (s - 0.08, -s + 0.02), (-s + 0.02, s - 0.08), (s - 0.08, s - 0.08)]:
            a.box(gx, gx + k, gy, gy + k, base_h, post_h, WOOD_L, WOOD, WOOD_D, sw=1.1)
        a.line([P(-s, s - 0.05, base_h + 4), P(s, s - 0.05, post_h - 6)], WOOD_D, 2.4)
        a.line([P(s - 0.05, s, base_h + 4), P(s - 0.05, -s, post_h - 6)], WOOD_D, 2.4)
        a.box(-plat, plat, -plat, plat, post_h, post_h + 6, WOOD_L, WOOD, WOOD_D)
        for t in (-0.2, 0.0, 0.2):
            a.line([P(-plat, t, post_h + 6), P(plat, t, post_h + 6)], WOOD_D, 1)
        # back railing
        for gx, gy in [(-plat, -plat), (plat - 0.05, -plat), (-plat, 0)]:
            a.box(gx, gx + 0.05, gy, gy + 0.05, post_h + 6, post_h + 20, WOOD_L, WOOD, WOOD_D, sw=1)
        a.line([P(-plat, -plat, post_h + 18), P(plat, -plat, post_h + 18)], WOOD_D, 2.4)
        a.line([P(-plat, -plat, post_h + 18), P(-plat, plat, post_h + 18)], WOOD_D, 2.4)
        # little pennant
        a.line([P(plat - 0.03, -plat, post_h + 18), P(plat - 0.03, -plat, post_h + 44)], INK, 2.2)
        x, y = P(plat - 0.03, -plat, post_h + 44)
        a.cloth([(x, y), (x + 16, y + 4), (x, y + 9)], sw=1.4)
        if level >= 2:  # iron-banded stone base
            for z in (5, base_h - 4):
                a.line([P(-s, s, z), P(s, s, z), P(s, -s, z)], "#3a3632", 2.4)
        if level >= 3:  # gold trim on the platform and a second pennant
            a.line([P(-plat, plat, post_h + 6), P(plat, plat, post_h + 6), P(plat, -plat, post_h + 6)], GOLD, 2)
            a.line([P(-plat + 0.02, -plat, post_h + 18), P(-plat + 0.02, -plat, post_h + 40)], INK, 2.2)
            x, y = P(-plat + 0.02, -plat, post_h + 40)
            a.cloth([(x, y), (x + 14, y + 4), (x, y + 8)], sw=0.8)
    else:
        a._track([P(-plat, plat, 0), P(plat, -plat, 0), P(-plat, -plat, post_h + 60), P(plat, plat, 0)])
        for gx, gy in [(-plat, plat - 0.05), (plat - 0.05, plat - 0.05), (plat - 0.05, 0)]:
            a.box(gx, gx + 0.05, gy, gy + 0.05, post_h + 6, post_h + 20, WOOD_L, WOOD, WOOD_D, sw=1)
        a.line([P(-plat, plat, post_h + 18), P(plat, plat, post_h + 18)], WOOD_D, 2.6)
        a.line([P(plat, plat, post_h + 18), P(plat, -plat, post_h + 18)], WOOD_D, 2.6)
        if level >= 2:  # crimson shields hung on the front railing
            for gx, gy in [(-0.12, plat), (plat, -0.1)]:
                x, y = P(gx, gy, post_h + 12)
                a.ellipse(x, y, 6, 6.5, CRIMSON, INK, 1.2)
                a.ellipse(x, y, 2, 2, GOLD, INK, 0.6)
        if level >= 3:  # lantern on the front corner post
            x, y = P(-plat + 0.02, plat - 0.02, post_h + 24)
            a.ellipse(x, y, 11, 11, GLOW, opacity=0.3)
            a.poly([(x - 3, y - 4), (x + 3, y - 4), (x + 3, y + 4), (x - 3, y + 4)], GLOW, INK, 1)
    return a
