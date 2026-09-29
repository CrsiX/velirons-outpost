#!/usr/bin/env python3
"""Generates all SVG art for Veliron's Outpost plus scripts/core/art_manifest.gd.

Everything is authored in 1x world units (an iso tile is 128x64) relative to an
anchor point (the tile centre on the ground for objects, the feet for units).
SVGs are written at 2x pixel size for crisp high-DPI rendering; the game draws
them at 0.5 scale. Run:  python3 tools/gen_art.py
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")
MANIFEST = os.path.join(ROOT, "scripts", "core", "art_manifest.gd")

INK = "#15110d"
TW, TH = 64, 32  # half tile width/height

# Palette: dark forest fantasy
GRASS = ["#3e592d", "#3c572c", "#405b2e"]
GRASS_DARK = "#314a24"
GRASS_LIGHT = "#4d6b37"
FOREST_FLOOR = "#2e4422"
DIRT = "#6e5638"
DIRT_DARK = "#574329"
DIRT_LIGHT = "#836a47"
STONE_L, STONE_R, STONE_T, STONE_D = "#77736c", "#5a5751", "#8b877f", "#46433f"
WOOD, WOOD_D, WOOD_L = "#5e4129", "#43301e", "#7a5738"
CRIMSON, CRIMSON_D = "#8c1c2b", "#64121e"
GOLD, GOLD_D = "#c9a24a", "#8f6f2a"
GLOW = "#f0b04a"

manifest = {}


def P(gx, gy, z=0.0):
    """Grid offset (tiles) + height (px) -> screen offset from anchor."""
    return ((gx - gy) * TW, (gx + gy) * TH - z)


def fmt(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


class Art:
    def __init__(self):
        self.els = []
        self.pts = []

    def _track(self, pts):
        self.pts.extend(pts)

    def poly(self, pts, fill, stroke=INK, sw=1.4, opacity=None, join="round"):
        self._track(pts)
        d = " ".join("%s,%s" % (fmt(x), fmt(y)) for x, y in pts)
        op = ' opacity="%s"' % opacity if opacity is not None else ""
        st = ' stroke="%s" stroke-width="%s" stroke-linejoin="%s"' % (stroke, sw, join) if stroke else ""
        self.els.append('<polygon points="%s" fill="%s"%s%s/>' % (d, fill, st, op))

    def line(self, pts, color=INK, sw=1.4, opacity=None, cap="round"):
        self._track(pts)
        d = " ".join("%s,%s" % (fmt(x), fmt(y)) for x, y in pts)
        op = ' opacity="%s"' % opacity if opacity is not None else ""
        self.els.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="%s" stroke-linejoin="round"%s/>' % (d, color, sw, cap, op))

    def ellipse(self, cx, cy, rx, ry, fill, stroke=None, sw=1.4, opacity=None):
        self._track([(cx - rx, cy - ry), (cx + rx, cy + ry)])
        op = ' opacity="%s"' % opacity if opacity is not None else ""
        st = ' stroke="%s" stroke-width="%s"' % (stroke, sw) if stroke else ""
        self.els.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"%s%s/>' % (fmt(cx), fmt(cy), fmt(rx), fmt(ry), fill, st, op))

    def raw(self, svg, bbox):
        self._track(bbox)
        self.els.append(svg)

    def box(self, x0, x1, y0, y1, z0, z1, top, left, right, sw=1.4, stroke=INK):
        """Iso box; draws the two visible side faces and the top."""
        self.poly([P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)], left, stroke, sw)
        self.poly([P(x1, y1, z0), P(x1, y0, z0), P(x1, y0, z1), P(x1, y1, z1)], right, stroke, sw)
        self.poly([P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)], top, stroke, sw)

    def shadow(self, rx, ry=None, cx=0, cy=0, opacity=0.35):
        self.ellipse(cx, cy, rx, ry if ry else rx / 2, "#000", opacity=opacity)

    def save(self, name, pad=3, extra=None, fixed=None):
        if fixed:
            minx, miny, maxx, maxy = fixed
        else:
            xs = [p[0] for p in self.pts]
            ys = [p[1] for p in self.pts]
            minx, miny, maxx, maxy = min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad
        w, h = maxx - minx, maxy - miny
        body = "\n  ".join(self.els)
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">\n  %s\n</svg>\n'
               % (math.ceil(w * 2), math.ceil(h * 2), fmt(minx), fmt(miny), fmt(math.ceil(w * 2) / 2), fmt(math.ceil(h * 2) / 2), body))
        with open(os.path.join(ART, name + ".svg"), "w") as f:
            f.write(svg)
        entry = {"ax": -minx, "ay": -miny, "w": math.ceil(w * 2) / 2, "h": math.ceil(h * 2) / 2}
        if extra:
            entry.update(extra)
        manifest[name] = entry


def diamond(scale_x=1.0, scale_y=None, cx=0, cy=0):
    sy = scale_y if scale_y is not None else scale_x
    return [(cx, cy - TH * sy), (cx + TW * scale_x, cy), (cx, cy + TH * sy), (cx - TW * scale_x, cy)]


def rand_in_diamond(rng, s=0.8):
    while True:
        gx, gy = rng.uniform(-0.5, 0.5) * s, rng.uniform(-0.5, 0.5) * s
        return P(gx, gy)


# ---------------------------------------------------------------- ground tiles

def tile_grass(i):
    rng = random.Random(10 + i)
    a = Art()
    a.poly(diamond(1.03), GRASS[i], stroke=None)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(8, 16), rng.uniform(4, 7), GRASS_LIGHT if rng.random() < 0.5 else GRASS_DARK, opacity=0.18)
    for _ in range(7):
        x, y = rand_in_diamond(rng, 0.8)
        a.line([(x - 2, y), (x - 3, y - 4)], GRASS_DARK, 1.1)
        a.line([(x, y), (x, y - 5)], GRASS_DARK, 1.1)
        a.line([(x + 2, y), (x + 3, y - 4)], GRASS_DARK, 1.1)
    if i == 2:
        for _ in range(2):
            x, y = rand_in_diamond(rng, 0.6)
            a.ellipse(x, y, 1.6, 1.6, "#b9a36a")
    a.save("tile_grass_%d" % i, pad=0, fixed=(-66, -34, 66, 34))


def tile_forest():
    rng = random.Random(77)
    a = Art()
    a.poly(diamond(1.03), FOREST_FLOOR, stroke=None)
    for _ in range(9):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(4, 10), rng.uniform(2, 4), "#26391c", opacity=0.6)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.8)
        a.line([(x - 3, y), (x + 3, y - 1)], "#5a4630", 1.0, opacity=0.7)
    a.save("tile_forest", pad=0, fixed=(-66, -34, 66, 34))


def tile_road():
    rng = random.Random(5)
    a = Art()
    # soft semi-transparent outer rim so neighbouring road tiles blend together
    a.poly(diamond(1.16), DIRT, stroke=None, opacity=0.45)
    a.poly(diamond(1.06), DIRT, stroke=None)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(5, 12), rng.uniform(2, 5), DIRT_DARK if rng.random() < 0.6 else DIRT_LIGHT, opacity=0.5)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.85)
        a.ellipse(x, y, rng.uniform(1.2, 2.4), rng.uniform(1, 1.6), "#9a8866" if rng.random() < 0.5 else "#4b3a26")
    a.save("tile_road", pad=0, fixed=(-76, -38, 76, 38))


def tile_desert(i):
    rng = random.Random(40 + i)
    a = Art()
    base = ["#86724a", "#8a764c"][i]
    # soft rim so desert blends into neighbouring meadow
    a.poly(diamond(1.14), base, stroke=None, opacity=0.5)
    a.poly(diamond(1.04), base, stroke=None)
    for _ in range(4):
        x, y = rand_in_diamond(rng, 0.7)
        w = rng.uniform(16, 30)
        a.raw('<path d="M%s,%s q%s,-6 %s,0" fill="none" stroke="#6f5d3b" stroke-width="1.6" stroke-linecap="round" opacity="0.7"/>' % (fmt(x - w / 2), fmt(y), fmt(w / 2), fmt(w)), [(x - w / 2, y - 6), (x + w / 2, y)])
        a.raw('<path d="M%s,%s q%s,-5 %s,0" fill="none" stroke="#a08a5c" stroke-width="1.2" stroke-linecap="round" opacity="0.6"/>' % (fmt(x - w / 2 + 2), fmt(y - 2), fmt(w / 2 - 2), fmt(w - 4)), [(x - w / 2, y - 7), (x + w / 2, y)])
    for _ in range(4):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(1.2, 2.2), rng.uniform(0.9, 1.5), "#5e4f33")
    a.save("tile_desert_%d" % i, pad=0, fixed=(-74, -37, 74, 37))


def tile_rock():
    rng = random.Random(55)
    a = Art()
    a.poly(diamond(1.03), "#4a4740", stroke=None)
    for _ in range(8):
        x, y = rand_in_diamond(rng, 0.85)
        a.ellipse(x, y, rng.uniform(3, 8), rng.uniform(2, 4), "#5c5850" if rng.random() < 0.5 else "#3a3833", opacity=0.8)
    a.save("tile_rock", pad=0, fixed=(-66, -34, 66, 34))


def mountain(i):
    """Rocky peak filling one tile; neighbouring peaks overlap into ranges."""
    rng = random.Random(90 + i)
    a = Art()
    h = [82, 104, 66][i]
    ax = [6, -8, 10][i]
    left, front, right = (-68, 2), (0, 34), (68, 2)
    apex = (ax, -h)
    a.poly([left, front, right, (40, -18), apex, (-44, -16)], "#3e3b36", stroke=None, opacity=0.4)  # shadowed back
    a.poly([left, front, apex], "#77726a")
    a.poly([front, right, apex], "#57534c")
    # secondary shoulder peak
    sh = (ax - 34 if i != 1 else ax + 30, -h * 0.55)
    a.poly([left if i != 1 else front, (sh[0] - 10, 8), sh], "#6d685f")
    # strata / cracks
    for _ in range(4):
        t = rng.uniform(0.25, 0.8)
        x0, y0 = front[0] + (apex[0] - front[0]) * t, front[1] + (apex[1] - front[1]) * t
        a.line([(x0, y0), (x0 - rng.uniform(10, 24), y0 + rng.uniform(4, 10))], "#4f4b45", 1.4)
        a.line([(x0, y0), (x0 + rng.uniform(10, 24), y0 + rng.uniform(4, 10))], "#403d38", 1.4)
    # snow cap on the taller peaks
    if h > 70:
        k = 0.3
        sl = (apex[0] + (left[0] - apex[0]) * k, apex[1] + (left[1] - apex[1]) * k)
        sf = (apex[0] + (front[0] - apex[0]) * k, apex[1] + (front[1] - apex[1]) * k)
        sr = (apex[0] + (right[0] - apex[0]) * k, apex[1] + (right[1] - apex[1]) * k)
        a.poly([sl, (sl[0] + 8, sl[1] + 6), sf, apex], "#dcdad2", INK, 1.1)
        a.poly([sf, (sr[0] - 6, sr[1] + 5), sr, apex], "#b9b7af", INK, 1.1)
    a.line([front, apex], "#8d887f", 1.6)
    a.line([left, apex, right], INK, 1.6)
    a.line([left, front, right], INK, 1.2)
    a.save("mountain_%d" % i)


# ------------------------------------------------------------------ trees

def tree_pine(i):
    rng = random.Random(30 + i)
    s = 1.0 + 0.12 * i
    a = Art()
    a.shadow(28 * s, 13 * s)
    a.poly([(-3, 0), (3, 0), (3, -16), (-3, -16)], WOOD_D)
    tiers = [(-12, 30, -52), (-34, 25, -72), (-54, 18, -94)]
    greens = [("#1f3a28", "#162c1e"), ("#244330", "#193322"), ("#2a4c36", "#1d3827")]
    for (base, hw, apex), (gl, gr) in zip(tiers, greens):
        base, hw, apex = base * s, hw * s, apex * s
        a.poly([(-hw, base), (0, apex), (hw, base), (0, base + 5)], gl)
        a.poly([(0, apex), (hw, base), (0, base + 5)], gr, stroke=None)
        a.line([(-hw, base), (0, apex), (hw, base)], INK, 1.4)
    a.line([(-6 * s, -58 * s), (-2 * s, -80 * s)], "#3a6448", 1.6, opacity=0.8)
    a.save("tree_pine_%d" % i)


def tree_oak():
    a = Art()
    a.shadow(34, 16)
    a.poly([(-5, 0), (5, 0), (4, -30), (-4, -30)], WOOD_D)
    a.line([(0, -26), (-12, -40)], INK, 4.5)
    a.line([(0, -26), (-12, -40)], WOOD_D, 2.5)
    for cx, cy, r, c in [(-18, -50, 20, "#203a22"), (18, -50, 20, "#1b331d"), (0, -68, 26, "#26442a"), (-8, -76, 12, "#2e5232")]:
        a.ellipse(cx, cy, r, r * 0.9, c, INK, 1.4)
    a.ellipse(-12, -74, 5, 4, "#3d6a42", opacity=0.8)
    a.save("tree_oak")


def tree_dead():
    a = Art()
    a.shadow(18, 8)
    a.poly([(-4, 0), (4, 0), (2, -46), (-2, -46)], "#4a4036")
    for pts in [[(0, -30), (-16, -48), (-20, -60)], [(0, -38), (14, -54), (22, -58)], [(1, -46), (4, -64)], [(-10, -42), (-4, -52)]]:
        a.line(pts, INK, 4.2)
        a.line(pts, "#5c5145", 2.2)
    a.save("tree_dead")


# --------------------------------------------------------------- buildings

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


def wall():
    a = Art()
    x0, x1, y0, y1, h = -0.5, 0.5, -0.14, 0.14, 34
    a.box(x0, x1, y0, y1, 0, h, STONE_T, STONE_L, STONE_R)
    for z in (11, 22):
        a.line([P(x0, y1, z), P(x1, y1, z)], STONE_D, 1)
    for gx, z0 in [(-0.25, 0), (0.15, 0), (-0.05, 11), (0.35, 11), (-0.35, 22), (0.05, 22)]:
        a.line([P(gx, y1, z0), P(gx, y1, z0 + 11)], STONE_D, 1)
    for gx in (-0.42, -0.08, 0.26):
        a.box(gx, gx + 0.16, y0, y1, h, h + 8, STONE_T, STONE_L, STONE_R)
    a.save("wall")


def gate():
    a = Art()
    x0, x1, y0, y1 = -0.5, 0.5, -0.16, 0.16
    a.box(x0, -0.22, y0, y1, 0, 46, STONE_T, STONE_L, STONE_R)
    a.box(0.22, x1, y0, y1, 0, 46, STONE_T, STONE_L, STONE_R)
    a.box(-0.22, 0.22, y0, y1, 30, 42, STONE_T, STONE_L, STONE_R)
    # doors in the opening
    a.poly([P(-0.22, y1 - 0.04, 0), P(0.22, y1 - 0.04, 0), P(0.22, y1 - 0.04, 30), P(-0.22, y1 - 0.04, 30)], WOOD_D)
    for gx in (-0.11, 0.0, 0.11):
        a.line([P(gx, y1 - 0.04, 0), P(gx, y1 - 0.04, 30)], "#2b1e14", 1.4)
    a.line([P(-0.22, y1 - 0.04, 14), P(0.22, y1 - 0.04, 14)], "#8a8a8a", 1.6)
    for gx in (-0.5, -0.36, 0.22, 0.36):
        a.box(gx, gx + 0.14, y0, y1, 46, 54, STONE_T, STONE_L, STONE_R)
    # Veliron banner
    a.poly([P(-0.36, y1, 44), P(-0.26, y1, 44), P(-0.26, y1, 18), P(-0.31, y1, 23), P(-0.36, y1, 18)], CRIMSON)
    a.poly([P(0.26, y1, 44), P(0.36, y1, 44), P(0.36, y1, 18), P(0.31, y1, 23), P(0.26, y1, 18)], CRIMSON)
    x, y = P(-0.31, y1, 34)
    a.ellipse(x, y, 2.2, 2.2, GOLD)
    x, y = P(0.31, y1, 34)
    a.ellipse(x, y, 2.2, 2.2, GOLD)
    a.save("gate")


def merlons(a, s, z, front):
    """Merlons around a square top of half-size s. front=True draws only the front edges."""
    k = 0.13
    spots_back = [(-s, -s), (-s + 0.25 * 2 * s, -s), (s - k, -s), (-s, 0 - k / 2)]
    spots_front = [(-s, s - k), (0 - k / 2, s - k), (s - k, s - k), (s - k, 0 - k / 2), (s - k, -s)]
    for gx, gy in (spots_front if front else spots_back):
        a.box(gx, gx + k, gy, gy + k, z, z + 9, STONE_T, STONE_L, STONE_R)


def hanging_banner(a, face, u0, u1, z_top, z_bot, colour=CRIMSON, emblem=GOLD):
    """Swallow-tailed banner on a visible face ('left' = gy+, 'right' = gx+)."""
    def at(u, z):
        return P(u, face[1], z) if face[0] == "left" else P(face[1], -u, z)
    um = (u0 + u1) / 2
    a.poly([at(u0, z_top), at(u1, z_top), at(u1, z_bot), at(um, z_bot + 6), at(u0, z_bot)], colour, INK, 1.2)
    x, y = at(um, (z_top + z_bot) / 2 + 2)
    a.ellipse(x, y, 2.6, 2.6, emblem, INK, 0.8)


def wall_tower(front=False, level=1):
    a = Art()
    s, h = 0.36, 74
    if not front:
        a.shadow(52, 26, cy=4)
        a.box(-s, s, -s, s, 0, h, STONE_T, STONE_L, STONE_R)
        for z in (18, 36, 54):
            a.line([P(-s, s, z), P(s, s, z)], STONE_D, 1)
            a.line([P(s, s, z), P(s, -s, z)], STONE_D, 1)
        a.poly([P(-0.05, s, 34), P(0.05, s, 34), P(0.05, s, 48), P(-0.05, s, 48)], "#1a1612")
        a.box(-s - 0.03, s + 0.03, -s - 0.03, s + 0.03, h, h + 4, STONE_T, STONE_L, STONE_R)
        # banner pole at the back
        a.line([P(-s + 0.06, -s + 0.06, h + 4), P(-s + 0.06, -s + 0.06, h + 44)], INK, 3)
        x, y = P(-s + 0.06, -s + 0.06, h + 44)
        a.poly([(x, y), (x + 20, y + 4), (x + 14, y + 9), (x + 20, y + 14), (x, y + 16)], CRIMSON)
        merlons(a, s + 0.03, h + 4, False)
        if level >= 2:  # crimson banner and an iron ring below the parapet
            hanging_banner(a, ("left", s), -0.22, -0.02, h - 4, h - 34)
            a.line([P(-s, s, h - 2), P(s, s, h - 2), P(s, -s, h - 2)], "#3a3632", 3)
        if level >= 3:  # second banner, gold trim, a brazier burning on top
            hanging_banner(a, ("right", s), -0.12, 0.08, h - 4, h - 34)
            a.line([P(-s - 0.03, s + 0.03, h + 4), P(s + 0.03, s + 0.03, h + 4), P(s + 0.03, -s - 0.03, h + 4)], GOLD, 2)
            for u in (-0.25, 0.0, 0.25):
                x, y = P(u, s, h - 2)
                a.ellipse(x, y, 1.4, 1.4, GOLD)
            bx, by = P(s - 0.12, -s + 0.12, h + 4)
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
        # little crimson pennant
        a.line([P(plat - 0.03, -plat, post_h + 18), P(plat - 0.03, -plat, post_h + 44)], INK, 2.2)
        x, y = P(plat - 0.03, -plat, post_h + 44)
        a.poly([(x, y), (x + 16, y + 4), (x, y + 9)], CRIMSON)
        if level >= 2:  # iron-banded stone base
            for z in (5, base_h - 4):
                a.line([P(-s, s, z), P(s, s, z), P(s, -s, z)], "#3a3632", 2.4)
        if level >= 3:  # gold trim on the platform and a second, golden pennant
            a.line([P(-plat, plat, post_h + 6), P(plat, plat, post_h + 6), P(plat, -plat, post_h + 6)], GOLD, 2)
            a.line([P(-plat + 0.02, -plat, post_h + 18), P(-plat + 0.02, -plat, post_h + 40)], INK, 2.2)
            x, y = P(-plat + 0.02, -plat, post_h + 40)
            a.poly([(x, y), (x + 14, y + 4), (x, y + 8)], GOLD, INK, 0.8)
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


def site():
    a = Art()
    a.poly(diamond(0.78), DIRT_DARK, stroke=None, opacity=0.85)
    for gx, gy in [(-0.38, -0.38), (0.38, -0.38), (-0.38, 0.38), (0.38, 0.38)]:
        a.box(gx - 0.025, gx + 0.025, gy - 0.025, gy + 0.025, 0, 12, WOOD_L, WOOD, WOOD_D, sw=0.9)
    a.line([P(-0.38, 0.38, 10), P(0.38, 0.38, 10), P(0.38, -0.38, 10)], "#c9b98f", 1)
    # scaffold frame
    for gx, gy in [(-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)]:
        a.line([P(gx, gy, 0), P(gx, gy, 38)], WOOD_D, 2.2)
    a.line([P(-0.25, 0.25, 30), P(0.25, 0.25, 30), P(0.25, -0.25, 30)], WOOD, 2.2)
    a.line([P(-0.25, 0.25, 4), P(0.25, 0.25, 30)], WOOD, 1.8)
    # plank + stone piles
    a.box(-0.3, 0.05, 0.12, 0.26, 0, 4, WOOD_L, WOOD, WOOD_D, sw=1)
    a.box(-0.26, 0.09, 0.14, 0.24, 4, 7, WOOD_L, WOOD, WOOD_D, sw=1)
    a.box(0.1, 0.24, -0.1, 0.06, 0, 6, STONE_T, STONE_L, STONE_R, sw=1)
    a.save("site")


def farm_field(kind):
    """3x3 flat field, anchor at centre tile. kind: 'field' or 'site'."""
    a = Art()
    s = 1.45
    border = [P(-s, -s), P(s, -s), P(s, s), P(-s, s)]
    a.poly(border, "#4a3a27" if kind == "field" else "#4f3f2b", INK, 1.4)
    rng = random.Random(3)
    if kind == "field":
        gy = -s + 0.18
        while gy < s - 0.1:
            a.line([P(-s + 0.12, gy), P(s - 0.12, gy)], "#3a2c1c", 3.2)
            a.line([P(-s + 0.12, gy - 0.02), P(s - 0.12, gy - 0.02)], "#8c7a3c", 2.2)
            gx = -s + 0.2
            while gx < s - 0.15:
                x, y = P(gx + rng.uniform(-0.03, 0.03), gy)
                a.line([(x, y), (x - 1.5, y - 6), (x, y - 8), (x + 1.5, y - 6), (x, y)], "#b0993f", 1.1)
                gx += 0.22
            gy += 0.27
        # fence posts
        for t in [i / 8 for i in range(9)]:
            for p in (P(-s + 2 * s * t, s), P(s, s - 2 * s * t)):
                a.line([p, (p[0], p[1] - 9)], WOOD_D, 2.2)
        a.line([(P(-s, s)[0], P(-s, s)[1] - 6), (P(s, s)[0], P(s, s)[1] - 6), (P(s, -s)[0], P(s, -s)[1] - 6)], WOOD, 1.6)
        a.save("farm_field")
    else:
        gy = -s + 0.25
        while gy < s - 0.1:
            a.line([P(-s + 0.15, gy), P(s - 0.15, gy)], "#3d2f20", 2, opacity=0.8)
            gy += 0.3
        for gx, gy in [(-s, -s), (s, -s), (-s, s), (s, s), (0, s), (s, 0), (0, -s), (-s, 0)]:
            x, y = P(gx, gy)
            a.line([(x, y), (x, y - 10)], WOOD_L, 2)
        a.line([(P(-s, s)[0], P(-s, s)[1] - 8), (P(s, s)[0], P(s, s)[1] - 8), (P(s, -s)[0], P(s, -s)[1] - 8)], "#c9b98f", 1)
        a.save("farm_site")


def farm_shed():
    a = Art()
    a.shadow(30, 15, cy=2)
    x0, x1, y0, y1, h = -0.26, 0.26, -0.22, 0.22, 20
    a.box(x0, x1, y0, y1, 0, h, WOOD_L, WOOD, WOOD_D)
    for t in (0.25, 0.5, 0.75):
        gx = x0 + (x1 - x0) * t
        a.line([P(gx, y1, 0), P(gx, y1, h)], WOOD_D, 1)
    a.poly([P(-0.08, y1, 0), P(0.08, y1, 0), P(0.08, y1, 14), P(-0.08, y1, 14)], "#241911")
    e = 0.06
    a.poly([P(x0 - e, y0 - e, h + 14), P(x1 + e, y0 - e, h + 14), P(x1 + e, y1 + e, h), P(x0 - e, y1 + e, h)], "#5b4a2e")
    a.poly([P(x1 + e, y0 - e, h + 14), P(x1 + e, y1 + e, h), P(x1, y1, h), P(x1, y0, h + 14)], "#43351f")
    # hay bale
    a.box(0.3, 0.46, -0.12, 0.06, 0, 9, "#b49a4a", "#9c8440", "#7d6a33", sw=1)
    a.save("farm_shed")


# -------------------------------------------------------------------- units

def person(name, body, hood=None, hat=None, prop=None, skin="#d8b08c", robe=False, extra=None):
    """Generic villager, facing right, feet at (0,0), ~42px tall."""
    a = Art()
    a.shadow(11, 4.5, opacity=0.4)
    if prop == "back":
        pass
    # legs
    if robe:
        a.poly([(-9, -2), (9, -2), (7, -26), (-7, -26)], body[0])
        a.poly([(0, -2), (9, -2), (7, -26), (0, -26)], body[1], stroke=None)
        a.line([(-9, -2), (9, -2), (7, -26)], INK, 1.4)
    else:
        a.line([(-3, -1), (-3, -12)], INK, 5)
        a.line([(3, -1), (3, -12)], INK, 5)
        a.line([(-3, -1.5), (-3, -12)], "#3a3128", 3)
        a.line([(3, -1.5), (3, -12)], "#3a3128", 3)
        a.ellipse(-3.5, -1, 3.5, 1.8, "#2a211a", INK, 1)
        a.ellipse(3.5, -1, 3.5, 1.8, "#2a211a", INK, 1)
        # torso
        a.poly([(-7, -11), (7, -11), (6, -27), (-6, -27)], body[0])
        a.poly([(0, -11), (7, -11), (6, -27), (0, -27)], body[1], stroke=None)
        a.line([(-7, -11), (7, -11), (6, -27)], INK, 1.2)
        a.line([(-7, -15), (7, -15)], "#2a1e14", 2)
    if extra:
        extra(a, "back")
    # head
    a.ellipse(0, -33, 6, 6, skin, INK, 1.3)
    a.ellipse(3, -33.5, 0.9, 0.9, INK)
    if hood:
        a.raw('<path d="M-7,-30 Q-8,-43 0,-43 Q8,-43 7,-34 L4,-36 Q0,-40 -4,-36 Q-5,-33 -5,-28 Z" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (hood, INK), [(-8, -44), (8, -28)])
    if hat:
        hat(a)
    if extra:
        extra(a, "front")
    a.save(name)


def builder():
    def extra(a, layer):
        if layer == "front":
            # hammer
            a.line([(6, -18), (13, -30)], INK, 3.6)
            a.line([(6, -18), (13, -30)], WOOD_L, 2)
            a.poly([(9, -33), (17, -29), (15, -26), (8, -30)], "#8a8a8a")
            a.line([(4, -20), (8, -20)], INK, 4)
            # apron
            a.poly([(-5, -12), (5, -12), (4, -23), (-4, -23)], "#7a5a38", INK, 1)

    def hat(a):
        a.raw('<path d="M-7,-35 Q-6,-42 0,-42 Q7,-42 7,-35 Z" fill="#5c5448" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -43), (8, -34)])
        a.line([(-8, -35), (9, -35)], INK, 2)
    person("unit_builder", ("#7a6048", "#5f4a37"), hat=hat, extra=extra)


def farmer():
    def extra(a, layer):
        if layer == "front":
            a.line([(8, -4), (12, -38)], INK, 3)
            a.line([(8, -4), (12, -38)], WOOD_L, 1.6)
            a.line([(9, -38), (15, -38)], INK, 1.8)
            for x in (9, 12, 15):
                a.line([(x, -38), (x, -44)], "#8a8a8a", 1.4)
            a.line([(4, -20), (9, -22)], INK, 4)

    def hat(a):
        a.ellipse(0, -38, 11, 3.2, "#b8a060", INK, 1.2)
        a.raw('<path d="M-5,-38 Q-4,-45 0,-45 Q4,-45 5,-38 Z" fill="#c9b070" stroke="%s" stroke-width="1.2"/>' % INK, [(-6, -46), (6, -37)])
    person("unit_farmer", ("#566a3a", "#43532d"), hat=hat, extra=extra)


def explorer():
    def extra(a, layer):
        if layer == "back":
            a.poly([(-10, -14), (-5, -14), (-5, -26), (-10, -26)], "#5a4630")  # pack
        else:
            a.line([(5, -20), (10, -18)], INK, 4)
            a.line([(10, -18), (10, -12)], INK, 1.2)
            a.poly([(7, -12), (13, -12), (12, -5), (8, -5)], "#3a3128")
            a.ellipse(10, -8.5, 2.2, 2.6, GLOW)
            a.ellipse(10, -8.5, 6, 6, GLOW, opacity=0.25)
    person("unit_explorer", ("#3a4a44", "#2c3934"), hood="#34453f", extra=extra)


def archmage():
    def extra(a, layer):
        if layer == "front":
            a.line([(10, 0), (10, -44)], INK, 3.4)
            a.line([(10, 0), (10, -44)], "#3a2c22", 1.8)
            a.ellipse(10, -47, 4.2, 4.2, "#b88cff", INK, 1.2)
            a.ellipse(10, -47, 9, 9, "#9a6cff", opacity=0.3)
            a.raw('<path d="M-3,-30 Q0,-18 3,-30 Z" fill="#cfcfcf" stroke="%s" stroke-width="1"/>' % INK, [(-4, -31), (4, -18)])

    def hat(a):
        a.raw('<path d="M-9,-36 L9,-36 L2,-40 L-3,-58 L-4,-40 Z" fill="#2e2442" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-10, -59), (10, -35)])
        a.ellipse(-3, -58, 1.6, 1.6, GOLD)
    person("unit_archmage", ("#3a2d55", "#2a2040"), hat=hat, robe=True, extra=extra)


def archer():
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -16), (-5, -16), (-3, -30), (-7, -30)], WOOD, INK, 1)
            a.line([(-6, -30), (-7, -35)], INK, 1.2)
        else:
            a.poly([(-7, -24), (7, -18), (7, -15), (-7, -21)], CRIMSON, INK, 0.8)  # sash
            a.line([(4, -21), (11, -22)], INK, 4)
            a.raw('<path d="M9,-38 Q19,-22 9,-6" fill="none" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % INK, [(8, -39), (18, -5)])
            a.raw('<path d="M9,-38 Q19,-22 9,-6" fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round"/>' % "#8a5a30", [(8, -39), (18, -5)])
            a.line([(9, -38), (9, -6)], "#d8d0b8", 0.8)
    person("unit_archer", ("#33472f", "#263623"), hood="#2c3f29", extra=extra)


def gatherer():
    """Hunter-like villager without a bow: feathered cap, leather jerkin, knife, big sack."""
    def extra(a, layer):
        if layer == "back":
            a.raw('<path d="M-15,-12 Q-17,-30 -8,-30 L-4,-28 Q-2,-14 -6,-10 Z" fill="#8a7248" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % INK, [(-18, -31), (-2, -10)])
            a.line([(-12, -29), (-6, -27)], "#5a4a30", 1.4)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a5236", INK, 1)  # leather jerkin
            a.line([(-6, -24), (4, -14)], "#3a2c1c", 2)  # strap
            a.line([(5, -19), (10, -15)], INK, 4)
            a.line([(10, -15), (15, -13)], "#c9ccd4", 2.2)  # skinning knife
            a.line([(9, -15.5), (11, -14.5)], "#3a2c1c", 3)

    def hat(a):
        a.raw('<path d="M-7,-35 Q-5,-43 1,-42 Q8,-41 8,-35 Z" fill="#4a5a36" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -44), (9, -34)])
        a.line([(-8, -35), (10, -35)], INK, 1.8)
        a.raw('<path d="M5,-39 Q13,-48 18,-50 Q13,-43 7,-37 Z" fill="#b8402e" stroke="%s" stroke-width="1"/>' % INK, [(4, -51), (19, -36)])
    person("unit_gatherer", ("#56643a", "#434f2d"), hat=hat, extra=extra)


def forester():
    """Woodcutter with a big axe over the shoulder."""
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#7a3a2a", INK, 1)  # red check shirt
            for yy in (-16, -21):
                a.line([(-5.5, yy), (5.5, yy)], "#5a2a1e", 1.2)
            a.line([(-2, -26), (-2, -12), (2, -26), (2, -12)], "#5a2a1e", 1.0)
            a.line([(4, -20), (8, -24)], INK, 4)  # arm
            a.line([(3, -8), (13, -38)], INK, 3.6)  # axe haft
            a.line([(3, -8), (13, -38)], WOOD_L, 2)
            a.poly([(10, -40), (19, -41), (20, -32), (12, -34)], "#9a9a9a", INK, 1.2)  # axe head
            a.line([(19, -41), (20, -32)], "#d8d8d8", 1.2)

    def hat(a):
        a.raw('<path d="M-7,-34 Q-7,-43 0,-43 Q7,-43 7,-34 Z" fill="#3a4a2a" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -44), (8, -33)])
        a.line([(-7.5, -34.5), (7.5, -34.5)], INK, 2)
        a.raw('<path d="M-6,-30 Q0,-24 6,-30 Q4,-26 0,-25 Q-4,-26 -6,-30Z" fill="#6a4a2a"/>', [(-6, -31), (6, -24)])  # beard
    person("unit_forester", ("#4a3a2a", "#3a2c1e"), hat=hat, extra=extra)


def worker_camp():
    """Canvas tent with a chopping block, axe and stacked logs in front."""
    a = Art()
    a.shadow(44, 22, cy=3)
    a.poly(diamond(0.8), DIRT, stroke=None, opacity=0.8)
    # tent: ridge along gx, two canvas slopes
    x0, x1, y0, y1, ridge = -0.34, 0.28, -0.3, 0.12, 40
    ym = (y0 + y1) / 2
    a.poly([P(x0, y0, 0), P(x1, y0, 0), P(x1, ym, ridge), P(x0, ym, ridge)], "#8a8062")
    a.poly([P(x1, y0, 0), P(x1, ym, ridge), P(x1, y1, 0)], "#6e6650")  # rear-right end
    a.poly([P(x1, ym - 0.05, 0), P(x1, ym, ridge * 0.6), P(x1, ym + 0.05, 0)], "#2a2419", stroke=None)  # opening
    a.poly([P(x0, ym, ridge), P(x1, ym, ridge), P(x1, y1, 0), P(x0, y1, 0)], "#a39a78")
    a.line([P(x0, ym, ridge), P(x1, ym, ridge)], "#5a5240", 2)
    a.line([P(x0 - 0.06, ym, ridge + 6), P(x0 - 0.06, ym, 0)], WOOD_D, 2.2)  # pole
    a.line([P(x1 + 0.06, ym, ridge + 6), P(x1 + 0.06, ym, 0)], WOOD_D, 2.2)
    # tools in front: log pile, chopping block with axe, saw
    for i, (gx, gy) in enumerate([(-0.3, 0.3), (-0.18, 0.3), (-0.24, 0.3)]):
        z = 0 if i < 2 else 6
        a.box(gx - 0.05, gx + 0.05, gy - 0.12, gy + 0.12, z, z + 6, "#b08a58", WOOD, WOOD_D, sw=1)
    a.box(0.12, 0.24, 0.22, 0.34, 0, 9, "#b08a58", WOOD, WOOD_D, sw=1)
    x, y = P(0.18, 0.28, 9)
    a.line([(x, y), (x + 8, y - 14)], INK, 3)
    a.line([(x, y), (x + 8, y - 14)], WOOD_L, 1.6)
    a.poly([(x + 5, y - 17), (x + 12, y - 17), (x + 12, y - 11), (x + 7, y - 12)], "#9a9a9a", INK, 1)
    a.line([P(0.36, -0.1, 2), P(0.36, 0.14, 8)], "#9a9a9a", 2.4)  # leaning saw
    a.save("worker_camp")


def light_stone(glow_only=False):
    """Carved pillar on a plinth; runes glow dim yellow. Glow is a separate
    layer (same canvas) so the game can pulse it."""
    a = Art()
    rune = "#e8c860"
    if not glow_only:
        a.shadow(34, 17, cy=3)
        a.box(-0.3, 0.3, -0.3, 0.3, 0, 12, STONE_T, STONE_L, STONE_R)  # plinth
        a.box(-0.14, 0.14, -0.14, 0.14, 12, 84, "#6f6b64", "#6f6b64", "#55524c")  # pillar
        a.box(-0.19, 0.19, -0.19, 0.19, 84, 92, STONE_T, STONE_L, STONE_R)  # cap
        a.poly([P(-0.1, -0.1, 92), P(0.1, -0.1, 92), P(0.1, 0.1, 92), P(-0.1, 0.1, 92)], "#4a4740", stroke=None)
    # runes on both visible faces (drawn in both layers, glow layer adds halos)
    glyphs = [[(0, 0), (0.6, 1)], [(0.6, 0), (0, 1)], [(0.3, 0), (0.3, 1)], [(0, 0.5), (0.6, 0.5)], [(0, 0), (0.6, 0), (0.3, 1)]]
    for face in ("left", "right"):
        for k, g in enumerate(glyphs[:4] if face == "left" else glyphs[1:]):
            z0 = 20 + k * 15
            pts = []
            for (u, v) in g:
                if face == "left":
                    pts.append(P(-0.1 + u * 0.33, 0.14, z0 + 10 - v * 10))
                else:
                    pts.append(P(0.14, 0.1 - u * 0.33, z0 + 10 - v * 10))
            if glow_only:
                a.line(pts, rune, 6, opacity=0.35)
            a.line(pts, rune if glow_only else "#8a7a3a", 1.8)
    if glow_only:
        a._track([P(-0.3, 0.3, 0), P(0.3, -0.3, 0), P(-0.3, -0.3, 0), P(0.3, 0.3, 0), P(0, 0, 92)])
    return a


def warning_light():
    """Soft red glow shown where hidden enemies will come out of the dark."""
    a = Art()
    a.raw('<defs><radialGradient id="w"><stop offset="0" stop-color="#ff3b2a" stop-opacity="0.75"/><stop offset="0.45" stop-color="#e02a1c" stop-opacity="0.35"/><stop offset="1" stop-color="#e02a1c" stop-opacity="0"/></radialGradient></defs>', [(0, 0)])
    a.ellipse(0, 0, 52, 26, "url(#w)")
    a.save("warning_light")


def light_halo():
    """Soft ground glow under the light stone."""
    a = Art()
    a.raw('<defs><radialGradient id="g"><stop offset="0" stop-color="#f0d070" stop-opacity="0.45"/><stop offset="1" stop-color="#f0d070" stop-opacity="0"/></radialGradient></defs>', [(0, 0)])
    a.ellipse(0, 0, 150, 75, "url(#g)")
    a.save("light_halo")


BONE, BONE_D = "#d8d0bc", "#a89f88"


def skeleton():
    a = Art()
    a.shadow(11, 4.5, opacity=0.4)
    # legs
    for x0, x1 in ((-3, -4), (3, 4)):
        a.line([(x0, -1), (x1, -12)], INK, 3.6)
        a.line([(x0, -1), (x1, -12)], BONE, 2)
        a.ellipse(x0 + (-1 if x0 < 0 else 1), -1, 3, 1.5, BONE, INK, 1)
    # pelvis + tattered loincloth
    a.poly([(-6, -13), (6, -13), (4, -9), (-4, -9)], "#4a3a44", INK, 1)
    a.poly([(-5, -9), (-2, -9), (-4, -5)], "#4a3a44", INK, 0.8)
    a.poly([(1, -9), (5, -9), (3, -4)], "#4a3a44", INK, 0.8)
    # spine + ribs
    a.line([(0, -13), (0, -27)], INK, 3.4)
    a.line([(0, -13), (0, -27)], BONE, 1.8)
    for k, y in enumerate((-24, -21, -18)):
        w = 6 - k
        a.raw('<path d="M%d,%d Q0,%d %d,%d" fill="none" stroke="%s" stroke-width="3.2" stroke-linecap="round"/>' % (-w, y + 2, y - 1, w, y + 2, INK), [(-w, y - 1), (w, y + 2)])
        a.raw('<path d="M%d,%d Q0,%d %d,%d" fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % (-w, y + 2, y - 1, w, y + 2, BONE), [(-w, y - 1), (w, y + 2)])
    # bony arms reaching forward, empty-handed
    for pts in ([(3, -25), (8, -19), (12, -21)], [(-3, -25), (-6, -18), (-5, -13)]):
        a.line(pts, INK, 3.4)
        a.line(pts, BONE, 1.8)
    for fx in (12.5, 14):
        a.line([(12, -21), (fx, -23)], BONE, 1.2)
    # skull with glowing sockets
    a.ellipse(0, -32, 6.5, 6, BONE, INK, 1.3)
    a.poly([(-3.5, -28), (3.5, -28), (3, -25), (-3, -25)], BONE, INK, 1)
    a.line([(-1.5, -26.5), (-1.5, -25)], INK, 0.8)
    a.line([(1.5, -26.5), (1.5, -25)], INK, 0.8)
    a.ellipse(-2.2, -32.5, 1.8, 2, "#1a1612")
    a.ellipse(2.5, -32.5, 1.8, 2, "#1a1612")
    a.ellipse(-2.2, -32.5, 0.9, 0.9, "#9fe8ff")
    a.ellipse(2.5, -32.5, 0.9, 0.9, "#9fe8ff")
    a.save("unit_skeleton")


def ork():
    """Big, hunched brute with pointy ears, tusks, an iron pauldron and a sword."""
    a = Art()
    a.shadow(14, 5.5, opacity=0.45)
    skin, skin_d = "#6b7a52", "#55623f"
    for x0, x1 in ((-5, -6), (5, 6)):  # thick legs
        a.line([(x0, -1), (x1, -12)], INK, 7)
        a.line([(x0, -1.5), (x1, -12)], "#4a3a2a", 4.6)
        a.ellipse(x0 + (-1 if x0 < 0 else 1), -1, 4.5, 2, "#2a211a", INK, 1)
    a.poly([(-11, -11), (10, -11), (12, -30), (-10, -32)], "#5a4432", INK, 1.4)  # leather armour
    a.poly([(0, -11), (10, -11), (12, -30), (0, -31)], "#4a3828", stroke=None)
    a.line([(-10, -16), (10, -16)], "#2a1e14", 2.2)
    a.poly([(-13, -34), (-3, -34), (-2, -26), (-13, -26)], "#7d7a74", INK, 1.2)  # iron pauldron
    a.ellipse(-8, -30, 1.2, 1.2, "#b0aca4")
    # sword arm and a broad straight sword
    a.line([(8, -26), (14, -18)], INK, 5.5)
    a.line([(8, -26), (14, -18)], skin, 3.4)
    a.line([(12, -16), (17, -20)], INK, 3)  # guard
    a.poly([(14.5, -20), (17, -18), (25, -42), (23, -44)], "#b8b8b8", INK, 1.2)  # blade
    a.line([(15.5, -20), (23.5, -42)], "#e0e0e0", 0.8)
    # head: heavy jaw, tusks, pointy ears, small red eyes
    a.poly([(-16, -40), (-7, -38), (-8, -34)], skin, INK, 1.2)
    a.poly([(15, -41), (7, -38), (8, -34)], skin, INK, 1.2)
    a.poly([(-8, -46), (8, -46), (9, -35), (5, -30), (-5, -30), (-9, -35)], skin, INK, 1.4)
    a.poly([(0, -46), (8, -46), (9, -35), (5, -30), (0, -30)], skin_d, stroke=None, opacity=0.7)
    a.line([(-6, -41), (-1, -40)], INK, 2)  # brow
    a.line([(6, -41), (1, -40)], INK, 2)
    a.ellipse(-3.5, -38.5, 1.3, 1.1, "#e03020")
    a.ellipse(3.5, -38.5, 1.3, 1.1, "#e03020")
    a.poly([(-4, -32), (-3, -36), (-2, -32)], "#efe8d0", INK, 0.7)  # tusks
    a.poly([(2, -32), (3, -36), (4, -32)], "#efe8d0", INK, 0.7)
    a.save("unit_ork")


def witch():
    """Human-like witch: pale face, long dark hair, black dress, wide-brimmed pointy black hat."""
    def extra(a, layer):
        if layer == "back":
            a.raw('<path d="M-7,-34 Q-10,-24 -8,-16 L-4,-18 Q-5,-26 -4,-33 Z" fill="#241c20" stroke="%s" stroke-width="1"/>' % INK, [(-10, -35), (-3, -16)])  # hair
        else:
            a.poly([(-5, -24), (5, -24), (3, -20), (-3, -20)], "#5a2a4a", INK, 0.8)  # collar
            a.line([(4, -21), (11, -26)], INK, 3.8)  # arm raised, casting
            a.line([(4, -21), (11, -26)], "#1c1820", 2.2)
            a.ellipse(13, -28, 5, 5, "#ff6ad5", opacity=0.35)
            a.ellipse(13, -28, 2, 2, "#ffb0ec")

    def hat(a):
        a.ellipse(0, -37.5, 12, 3.2, "#15121a", INK, 1.2)  # wide brim
        a.raw('<path d="M-6,-38 L6,-38 L2,-44 L6,-58 L-3,-45 Z" fill="#1c1822" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-7, -59), (7, -37)])
        a.line([(-5.5, -39.5), (5.5, -39.5)], "#7a3a6a", 1.6)  # band
    person("unit_witch", ("#1c1820", "#141118"), hat=hat, robe=True, skin="#e8d8c8", extra=extra)


def corpse_ork():
    a = Art()
    a.ellipse(0, 0, 22, 7, "#000", opacity=0.3)
    a.ellipse(0, 1, 18, 5, "#3a1a14", opacity=0.5)
    a.poly([(-15, -3), (8, -8), (12, -1), (-12, 5)], "#5a4432", INK, 1.2)
    a.line([(-15, 0), (-24, 3)], INK, 6)
    a.line([(-15, 0), (-24, 3)], "#4a3a2a", 4)
    a.ellipse(15, -4, 7.5, 6, "#6b7a52", INK, 1.3)
    a.poly([(19, -8), (27, -12), (21, -3)], "#6b7a52", INK, 1)
    a.line([(12.5, -6), (15, -3)], INK, 1.3)
    a.line([(15, -6), (12.5, -3)], INK, 1.3)
    a.poly([(-4, 7), (-20, 11), (-19, 13), (-3, 9)], "#b8b8b8", INK, 1)  # dropped sword
    a.save("corpse_ork")


def corpse_witch():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.poly([(-14, 0), (6, -5), (10, 2), (-10, 5)], "#1c1820", INK, 1.2)  # dress
    a.ellipse(12, -3, 5, 4.5, "#e8d8c8", INK, 1.2)
    a.line([(12, -3), (16, 2)], "#241c20", 3)  # hair
    a.ellipse(-4, -9, 9, 2.5, "#15121a", INK, 1)  # hat on the ground
    a.poly([(-8, -9), (0, -9), (-3, -20)], "#1c1822", INK, 1)
    a.ellipse(-16, 5, 3, 3, "#ff6ad5", opacity=0.3)  # fading magic
    a.save("corpse_witch")


def spell_bolt():
    """Whirling, glowing pink ball."""
    a = Art()
    a.raw('<defs><radialGradient id="sb"><stop offset="0" stop-color="#ffe0f6"/><stop offset="0.45" stop-color="#ff6ad5"/><stop offset="1" stop-color="#ff6ad5" stop-opacity="0"/></radialGradient></defs>', [(0, 0)])
    a.ellipse(0, 0, 14, 14, "url(#sb)")
    for k in range(3):
        ang = k * 2.094
        x0, y0 = math.cos(ang) * 3, math.sin(ang) * 3
        x1, y1 = math.cos(ang + 1.6) * 10, math.sin(ang + 1.6) * 10
        a.raw('<path d="M%s,%s Q%s,%s %s,%s" fill="none" stroke="#ffd0f0" stroke-width="1.6" stroke-linecap="round"/>' % (fmt(x0), fmt(y0), fmt(math.cos(ang + 0.8) * 9), fmt(math.sin(ang + 0.8) * 9), fmt(x1), fmt(y1)), [(-11, -11), (11, 11)])
    a.save("spell_bolt")


def spell_glow():
    """Soft pink halo around a bewitched unit's head."""
    a = Art()
    a.raw('<defs><radialGradient id="sg"><stop offset="0" stop-color="#ff6ad5" stop-opacity="0.7"/><stop offset="1" stop-color="#ff6ad5" stop-opacity="0"/></radialGradient></defs>', [(0, 0)])
    a.ellipse(0, 0, 14, 12, "url(#sg)")
    for (x, y) in [(-8, -6), (7, -8), (9, 3), (-9, 4)]:
        a.ellipse(x, y, 1.3, 1.3, "#ffd0f0")
    a.save("spell_glow")


def summoner():
    """Mage without a staff: pointy hat, dark robe, a glowing purple orb held in the hand."""
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -26), (6, -26), (4, -22), (-4, -22)], "#5a3a7a", INK, 0.8)  # violet collar
            a.line([(4, -22), (11, -24)], INK, 4.2)  # arm held out
            a.line([(4, -22), (11, -24)], "#243a44", 2.6)
            a.ellipse(13, -27, 9, 9, "#9a6cff", opacity=0.3)
            a.ellipse(13, -27, 4.2, 4.2, "#a87cff", INK, 1.2)
            a.ellipse(12, -28.2, 1.4, 1.4, "#e8dcff")

    def hat(a):
        a.raw('<path d="M-9,-36 L9,-36 L3,-40 L-1,-57 L-4,-40 Z" fill="#3a2a55" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-10, -58), (10, -35)])
        a.line([(-6, -38.5), (6, -38.5)], "#9a6cff", 1.6)
    person("unit_summoner", ("#243a44", "#1a2c34"), hat=hat, robe=True, extra=extra)


def earth_elemental():
    """Small walking boulder with glowing cracks."""
    a = Art()
    a.shadow(12, 5, opacity=0.4)
    rock, rock_d, rock_l = "#7a6e5e", "#5a5044", "#948672"
    glow = "#e8a040"
    a.box(-0.07, -0.02, -0.03, 0.02, 0, 8, rock_l, rock, rock_d, sw=1)  # legs
    a.box(0.02, 0.07, -0.03, 0.02, 0, 8, rock_l, rock, rock_d, sw=1)
    a.poly([(-10, -8), (-12, -20), (-6, -28), (6, -29), (12, -20), (10, -8)], rock, INK, 1.4)  # body
    a.poly([(0, -29), (6, -29), (12, -20), (10, -8), (0, -8)], rock_d, stroke=None, opacity=0.6)
    a.line([(-6, -12), (-2, -18), (-5, -23)], glow, 1.6)  # glowing cracks
    a.line([(4, -11), (2, -17), (6, -21)], glow, 1.4)
    for (x, y, r) in [(-15, -18, 4.5), (-17, -11, 3.5), (15, -19, 4.5), (17, -12, 3.8)]:  # boulder fists
        a.ellipse(x, y, r, r * 0.9, rock_l if x < 0 else rock, INK, 1.2)
    a.ellipse(0, -33, 6, 5, rock_l, INK, 1.3)  # head
    a.ellipse(-2, -33.5, 1.2, 1, glow)
    a.ellipse(2.5, -33.5, 1.2, 1, glow)
    a.poly([(-3, -38), (-1, -42), (1, -38)], "#6a9a4a", INK, 0.8)  # moss tuft
    a.save("unit_earth_elemental")


def caravan():
    """Two-wheeled cart with sacks and planks, pulled by a brown horse (faces right)."""
    a = Art()
    a.ellipse(0, 1, 26, 7, "#000", opacity=0.35)
    wood, wood_d = WOOD, WOOD_D
    # cart bed and load
    a.poly([(-24, -12), (2, -12), (4, -20), (-22, -20)], wood, INK, 1.3)
    a.poly([(-24, -12), (2, -12), (2, -9), (-24, -9)], wood_d, INK, 1.1)
    a.ellipse(-16, -24, 6, 5, "#c9a86a", INK, 1.1)  # sacks
    a.ellipse(-8, -25, 6, 5.5, "#b8955a", INK, 1.1)
    a.ellipse(-12, -30, 5, 4.2, "#d4b478", INK, 1.0)
    a.poly([(-3, -21), (3, -21), (1, -31), (-5, -31)], "#8a6a44", INK, 1.0)  # planks
    a.line([(-2, -21), (-4, -31)], "#6a5034", 0.8)
    a.ellipse(-12, -6, 6.5, 6.5, wood_d, INK, 1.4)  # wheel
    a.ellipse(-12, -6, 2, 2, "#3a2a1a")
    for d in ((-4.5, 0), (4.5, 0), (0, -4.5), (0, 4.5)):
        a.line([(-12, -6), (-12 + d[0], -6 + d[1])], INK, 0.9)
    a.line([(3, -14), (12, -12)], wood_d, 2.2)  # shafts
    # horse
    horse, horse_d = "#7a5234", "#5a3a22"
    for x in (13, 17, 25, 29):  # legs
        a.line([(x, -12), (x + (1 if x % 2 else -1), 0)], INK, 3.2)
        a.line([(x, -12), (x + (1 if x % 2 else -1), 0)], horse_d, 1.8)
    a.ellipse(21, -16, 10, 6, horse, INK, 1.3)  # body
    a.poly([(28, -19), (32, -29), (36, -30), (38, -26), (33, -18)], horse, INK, 1.2)  # neck + head
    a.poly([(34, -30), (40, -27), (39, -24), (35, -25)], horse, INK, 1.0)
    a.poly([(29, -21), (31, -30), (33, -30), (31, -20)], "#2a1a10")  # mane
    a.ellipse(36, -28, 0.9, 0.9, "#111")
    a.line([(11, -17), (6, -10)], "#2a1a10", 2)  # tail
    a.poly([(16, -21), (26, -21), (26, -17), (16, -17)], CRIMSON, INK, 0.8, opacity=0.9)  # harness blanket
    a.save("unit_caravan")


def shield_bearer():
    """Smaller soldier almost hidden behind a big tower shield (planks, iron rim, crest)."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-8, -24), (-12, -32)], INK, 3)  # spear shaft behind
            a.line([(-8, -24), (-12, -32)], WOOD_L, 1.6)
        else:
            a.poly([(1, -2), (15, -4), (15, -36), (1, -38)], "#6a4a2c", INK, 1.6)  # the shield
            for x in (5.5, 10.5):
                a.line([(x, -2.6), (x, -37.2)], "#4a3220", 1)
            a.poly([(1, -2), (15, -4), (15, -36), (1, -38)], "none", "#9aa0a8", 1.8)  # iron rim
            a.ellipse(8, -20, 3.4, 4.2, "#9aa0a8", INK, 1)  # boss
            a.poly([(5, -30), (8, -34), (11, -30), (8, -26)], CRIMSON, INK, 0.8)  # crest

    def hat(a):
        a.raw('<path d="M-6.5,-33 Q-6,-41 0,-41 Q6,-41 6.5,-33 Z" fill="#8a9098" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -42), (7, -32)])
    person("unit_shield_bearer", ("#5a4a3a", "#463a2c"), hat=hat, extra=extra)


def crossbowman():
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -26), (6, -26), (6, -16), (-6, -16)], "#6a5236", INK, 0.8)  # leather jerkin
            a.line([(0, -20), (16, -22)], INK, 4)  # stock
            a.line([(0, -20), (16, -22)], WOOD, 2.2)
            a.raw('<path d="M13,-31 Q18,-22 13,-13" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % INK, [(12, -32), (18, -12)])
            a.raw('<path d="M13,-31 Q18,-22 13,-13" fill="none" stroke="#7a7a80" stroke-width="1.6" stroke-linecap="round"/>', [(12, -32), (18, -12)])
            a.line([(13, -31), (9, -22), (13, -13)], "#d8d0b8", 0.7)
            a.line([(9, -21), (19, -22.5)], "#b08a58", 1.2)  # bolt

    def hat(a):
        a.raw('<path d="M-8,-35 Q0,-44 8,-35 Z" fill="#5a4630" stroke="%s" stroke-width="1.2"/>' % INK, [(-9, -45), (9, -34)])
        a.line([(-9, -35), (9, -35)], INK, 1.6)
    person("unit_crossbowman", ("#4a3e2e", "#3a3022"), hat=hat, extra=extra)


def swiftbowman():
    """Fancier archer: green and gold, feathered cap, a bow with several strings."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -16), (-5, -16), (-3, -31), (-7, -31)], "#6a4a2a", INK, 1)
            for x in (-7.5, -6, -4.5):
                a.line([(x, -31), (x - 1, -36)], "#e8d890", 1)
        else:
            a.poly([(-7, -24), (7, -18), (7, -15), (-7, -21)], GOLD, INK, 0.8)  # golden sash
            a.line([(4, -21), (11, -22)], INK, 4)
            a.raw('<path d="M9,-40 Q21,-22 9,-4" fill="none" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % INK, [(8, -41), (20, -3)])
            a.raw('<path d="M9,-40 Q21,-22 9,-4" fill="none" stroke="#c8a050" stroke-width="1.8" stroke-linecap="round"/>', [(8, -41), (20, -3)])
            for dx in (0.0, 1.6, 3.2):  # three strings
                a.line([(9 + dx * 0.3, -40), (9 - dx, -22), (9 + dx * 0.3, -4)], "#f0ecd8", 0.6)

    def hat(a):
        a.raw('<path d="M-7,-35 Q0,-43 7,-35 L6,-33 L-6,-33 Z" fill="#2f6a3a" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -44), (8, -32)])
        a.raw('<path d="M3,-40 Q10,-50 14,-47 Q9,-43 5,-38 Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (GOLD, INK), [(2, -51), (15, -37)])
    person("unit_swiftbowman", ("#2f5a36", "#244a2a"), extra=extra, hat=hat)


def fire_summoner():
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -26), (6, -26), (4, -22), (-4, -22)], "#c8501e", INK, 0.8)
            a.line([(4, -22), (11, -24)], INK, 4.2)
            a.line([(4, -22), (11, -24)], "#5a2418", 2.6)
            a.ellipse(13, -27, 9, 9, "#ff8a30", opacity=0.35)
            a.raw('<path d="M13,-35 Q18,-28 15,-24 Q13,-21 11,-24 Q8,-28 13,-35 Z" fill="#ffb040" stroke="%s" stroke-width="1"/>' % INK, [(8, -36), (18, -21)])
            a.ellipse(13, -26, 1.6, 1.6, "#fff0b0")

    def hat(a):
        a.raw('<path d="M-9,-36 L9,-36 L3,-40 L-1,-57 L-4,-40 Z" fill="#6a2418" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-10, -58), (10, -35)])
        a.line([(-6, -38.5), (6, -38.5)], "#ff8a30", 1.6)
    person("unit_fire_summoner", ("#5a2418", "#461a12"), hat=hat, robe=True, extra=extra)


def fire_elemental():
    """A small living flame, hovering (no feet): the game bobs and flickers it."""
    a = Art()
    a.shadow(8, 3.5, opacity=0.3)
    a.raw('<path d="M0,-40 Q9,-30 10,-20 Q11,-8 0,-6 Q-11,-8 -10,-20 Q-9,-28 -4,-33 Q-3,-26 0,-26 Q1,-33 0,-40 Z" fill="#ff7a20" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-11, -41), (11, -5)])
    a.raw('<path d="M0,-31 Q6,-24 6,-17 Q6,-10 0,-10 Q-6,-10 -6,-17 Q-5,-22 -2,-25 Q-1,-20 1,-21 Q2,-26 0,-31 Z" fill="#ffc040"/>', [(-7, -32), (7, -9)])
    a.ellipse(0, -14, 3.2, 3.6, "#fff4c0")
    a.ellipse(-2.5, -19, 1.2, 1.4, INK)
    a.ellipse(2.5, -19, 1.2, 1.4, INK)
    a.save("unit_fire_elemental")


def mage(name, robe, trim, staff_top, glow, tome, hood=None):
    """Apprentice-style mage: staff in one hand, a thick tome in the other; no hat, no beard."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-9, -2), (-9, -44)], INK, 3.4)  # staff
            a.line([(-9, -2), (-9, -44)], "#4a3a2c", 1.8)
            a.ellipse(-9, -46, 8, 8, glow, opacity=0.3)
            staff_top(a)
        else:
            a.poly([(-6, -27), (6, -27), (4, -22), (-4, -22)], trim, INK, 0.8)  # collar
            a.line([(4, -21), (9, -19)], INK, 4)  # arm with the tome
            a.poly([(7, -24), (15, -22), (15, -13), (7, -15)], tome, INK, 1.2)
            a.line([(8, -22), (14, -20.5)], "#e8e0c8", 1)
            a.line([(8, -18), (14, -16.5)], "#e8e0c8", 1)

    def hair(a):
        a.raw('<path d="M-6,-34 Q-6,-40 0,-40 Q6,-40 6,-34 Q3,-37 0,-37 Q-3,-37 -6,-34 Z" fill="#3a2a1e" stroke="%s" stroke-width="1"/>' % INK, [(-7, -41), (7, -33)])
    person(name, robe, hood=hood, hat=None if hood else hair, robe=True, extra=extra)


def mages():
    def orb(col, core):
        def f(a):
            a.ellipse(-9, -46, 3.8, 3.8, col, INK, 1.2)
            a.ellipse(-10, -47, 1.3, 1.3, core)
        return f

    def flame(a):
        a.raw('<path d="M-9,-54 Q-5,-48 -6,-45 Q-8,-42 -9,-44 Q-12,-47 -9,-54 Z" fill="#ffb040" stroke="%s" stroke-width="1"/>' % INK, [(-13, -55), (-5, -41)])

    def crystal(a):
        a.poly([(-9, -54), (-6, -47), (-9, -42), (-12, -47)], "#bfe8ff", INK, 1)
        a.line([(-9, -54), (-9, -42)], "#ffffff", 0.6)

    def leaf(a):
        a.raw('<path d="M-9,-53 Q-3,-48 -9,-42 Q-15,-48 -9,-53 Z" fill="#7ad06a" stroke="%s" stroke-width="1"/>' % INK, [(-15, -54), (-3, -41)])
        a.line([(-9, -52), (-9, -43)], "#3a7a30", 0.7)

    def ring(a):
        a.ellipse(-9, -47, 4.6, 4.6, "none", "#c89cff", 1.6)
        a.ellipse(-9, -47, 1.8, 1.8, "#e8d8ff", INK, 0.8)

    mage("unit_apprentice", ("#4a4a50", "#38383e"), "#6a6a74", orb("#3a5ab0", "#b8c8ff"), "#3a5ab0", "#5a3a2a")
    mage("unit_fire_mage", ("#7a2a20", "#5e1e18"), "#d8602a", flame, "#ff8a30", "#4a1a12")
    mage("unit_ice_mage", ("#5a8ab0", "#467090"), "#cfeaff", crystal, "#a8dcff", "#2a4a6a")
    mage("unit_healing_mage", ("#3a7a44", "#2c6034"), "#bfe8a0", leaf, "#8ae08a", "#e8e0c8")
    mage("unit_spatial_mage", ("#4a3070", "#3a2458"), "#b08ae0", ring, "#b08ae0", "#2a1a40")


def spatial_archmage():
    """Civilian: robed in violet and gold, a rune halo floating above the head."""
    def extra(a, layer):
        if layer == "back":
            a.ellipse(0, -48, 13, 4.5, "none", "#c89cff", 1.6)
            for k in range(6):
                ang = k * math.pi / 3
                a.ellipse(math.cos(ang) * 13, -48 + math.sin(ang) * 4.5, 1.5, 1.5, GOLD)
        else:
            a.poly([(-7, -26), (7, -26), (5, -12), (-5, -12)], "none", GOLD, 1.2)
            a.line([(10, 0), (10, -46)], INK, 3.4)
            a.line([(10, 0), (10, -46)], "#2a1a40", 1.8)
            a.ellipse(10, -49, 5, 5, "#b08ae0", INK, 1.2)
            a.ellipse(10, -49, 10, 10, "#b08ae0", opacity=0.3)

    def hood(a):
        a.raw('<path d="M-7,-30 Q-8,-43 0,-43 Q8,-43 7,-34 L4,-36 Q0,-40 -4,-36 Q-5,-33 -5,-28 Z" fill="#3a2458" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-8, -44), (8, -28)])
        a.line([(-6, -37), (6, -39)], GOLD, 1.2)
    person("unit_spatial_archmage", ("#4a3070", "#3a2458"), hat=hood, robe=True, extra=extra)


def projectiles():
    a = Art()  # light arrow with pale fletching
    a.line([(-12, 0), (10, 0)], INK, 2)
    a.line([(-12, 0), (10, 0)], "#d8c090", 1)
    a.poly([(9, -2), (14, 0), (9, 2)], "#c8c8c8", INK, 0.8)
    a.poly([(-15, -2.5), (-10, 0), (-15, 2.5), (-12, 0)], "#e8e0a0", INK, 0.6)
    a.save("swift_arrow")
    a = Art()  # short heavy crossbow bolt
    a.line([(-8, 0), (8, 0)], INK, 3.4)
    a.line([(-8, 0), (8, 0)], "#8a6a40", 2)
    a.poly([(7, -3), (13, 0), (7, 3)], "#7a7a80", INK, 1)
    a.poly([(-10, -2.5), (-6, 0), (-10, 2.5)], "#5a5a5a", INK, 0.6)
    a.save("crossbow_bolt")

    def orb(name, outer, mid, core, swirl):
        o = Art()
        gid = name.replace("_", "")
        o.raw('<defs><radialGradient id="%s"><stop offset="0" stop-color="%s"/><stop offset="0.45" stop-color="%s"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient></defs>' % (gid, core, mid, outer), [(0, 0)])
        o.ellipse(0, 0, 14, 14, "url(#%s)" % gid)
        for k in range(3):
            ang = k * 2.094
            x0, y0 = math.cos(ang) * 3, math.sin(ang) * 3
            x1, y1 = math.cos(ang + 1.6) * 10, math.sin(ang + 1.6) * 10
            o.raw('<path d="M%s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % (fmt(x0), fmt(y0), fmt(math.cos(ang + 0.8) * 9), fmt(math.sin(ang + 0.8) * 9), fmt(x1), fmt(y1), swirl), [(-11, -11), (11, 11)])
        return o

    orb("arcane_orb", "#1a2a80", "#3a5ad0", "#d0dcff", "#8aa8ff").save("arcane_orb")
    fb = orb("fireball", "#c83010", "#ff8020", "#fff0a0", "#ffe070")
    for (x, y) in [(-9, -7), (8, -9), (10, 5), (-7, 9), (1, -12)]:  # sparkles
        fb.ellipse(x, y, 1.4, 1.4, "#fff4c0")
    fb.save("fireball")
    fr = orb("frost_orb", "#5aa8e0", "#a8dcff", "#ffffff", "#e0f4ff")
    fr.poly([(0, -8), (2, 0), (0, 8), (-2, 0)], "#ffffff", None)
    fr.save("frost_orb")
    orb("warp_orb", "#5a2a90", "#a878e8", "#f0e0ff", "#d8c0ff").save("warp_orb")


def barracks(level):
    """2x2 yard like the training grounds, no weapons lying about: benches (one
    per level), a table with bread, cheese and mugs, a barrel, and a straw
    puppet full of arrows."""
    a = Art()
    s = 0.98
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#7a6446", None)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], DIRT, INK, 1.2, opacity=0.9)
    for t in [i / 6 for i in range(7)]:  # fence on the front edges
        for p in (P(-s + 2 * s * t, s), P(s, s - 2 * s * t)):
            a.line([p, (p[0], p[1] - 9)], WOOD_D, 2.2)
    a.line([(P(-s, s)[0], P(-s, s)[1] - 6), (P(s, s)[0], P(s, s)[1] - 6), (P(s, -s)[0], P(s, -s)[1] - 6)], WOOD, 1.6)
    # the hut at the back, a little bigger with each level
    hx, hy = -0.6, -0.6
    w = 0.25 + 0.04 * level
    a.box(hx - w, hx + w, hy - 0.22, hy + 0.22, 0, 18, "#8c7b62", "#8c7b62", "#6c5e4a")
    a.poly([P(hx - w, hy + 0.22, 0), P(hx - w + 0.15, hy + 0.22, 0), P(hx - w + 0.15, hy + 0.22, 12), P(hx - w, hy + 0.22, 12)], "#2b1e14")
    e = 0.05
    roof = "#6a2a24" if level >= 2 else "#4a3b24"
    a.poly([P(hx - w - e, hy - 0.22 - e, 18), P(hx + w + e, hy - 0.22 - e, 18), P(hx + w + e, hy, 34), P(hx - w - e, hy, 34)], roof)
    a.poly([P(hx - w - e, hy, 34), P(hx + w + e, hy, 34), P(hx + w + e, hy + 0.22 + e, 18), P(hx - w - e, hy + 0.22 + e, 18)], "#7a3a30" if level >= 2 else "#5b4a2e")
    if level >= 3:  # a banner on the hut
        bx, by = P(hx + w, hy - 0.22, 34)
        a.line([(bx, by), (bx, by - 18)], WOOD_D, 1.6)
        a.poly([(bx, by - 18), (bx + 11, by - 15), (bx, by - 12)], CRIMSON, INK, 0.8)
    # benches (the game seats the units on them)
    for (gx, gy) in [(-0.35, 0.45), (0.45, 0.35), (0.1, -0.25)][:level]:
        a.box(gx - 0.2, gx + 0.2, gy - 0.07, gy + 0.07, 0, 5, WOOD_L, WOOD, WOOD_D)
    # table with bread, cheese and mugs, and a barrel
    tx, ty = 0.55, -0.5
    a.box(tx - 0.16, tx + 0.16, ty - 0.12, ty + 0.12, 0, 8, WOOD_L, WOOD, WOOD_D)
    x, y = P(tx, ty, 8)
    a.ellipse(x - 5, y - 2, 4, 2.2, "#c8904a", INK, 0.8)  # bread
    a.poly([(x + 1, y - 1), (x + 6, y - 3), (x + 6, y), (x + 1, y + 1)], "#e8c850", INK, 0.6)  # cheese
    for dx in (-1.0, 4.0):  # mugs
        a.poly([(x + dx, y - 7), (x + dx + 3, y - 7), (x + dx + 3, y - 2), (x + dx, y - 2)], "#8a6a40", INK, 0.7)
        a.ellipse(x + dx + 1.5, y - 7, 1.5, 0.7, "#f0e8d0")
    bx, by = P(0.85, -0.1, 0)
    a.poly([(bx - 6, by), (bx + 6, by), (bx + 7, by - 14), (bx - 7, by - 14)], WOOD, INK, 1)
    for yy in (-3, -11):
        a.line([(bx - 6.5, by + yy), (bx + 6.5, by + yy)], "#6a6a6a", 1.2)
    a.ellipse(bx, by - 14, 7, 2.5, WOOD_D, INK, 0.8)
    # straw puppet with arrows stuck in it
    px, py = P(-0.7, 0.05, 0)
    a.line([(px, py), (px, py - 30)], WOOD_D, 2.4)
    a.line([(px - 9, py - 22), (px + 9, py - 22)], WOOD_D, 2)
    a.ellipse(px, py - 20, 6, 8, "#d8c070", INK, 1.2)
    a.ellipse(px, py - 31, 4.2, 4.2, "#d8c070", INK, 1.1)
    for (dx, dy, ang) in [(-2, -22, -0.3), (3, -18, 0.4), (1, -31, -0.2)]:
        ex, ey = px + dx, py + dy
        ox, oy = ex - 8 * math.cos(ang), ey - 8 * math.sin(ang) + 1
        a.line([(ex, ey), (ox, oy)], INK, 1.6)
        a.line([(ex, ey), (ox, oy)], "#b08a58", 0.8)
        a.poly([(ox, oy - 1.3), (ox - 2.6, oy), (ox, oy + 1.3)], CRIMSON)
    a.save("barracks" if level == 1 else "barracks_%d" % level)


def corpse_skeleton():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    for (x0, y0, x1, y1) in [(-14, 2, -4, -2), (-2, 4, 9, 1), (4, -4, 14, -1), (-10, -3, -1, -6)]:
        a.line([(x0, y0), (x1, y1)], INK, 3.4)
        a.line([(x0, y0), (x1, y1)], BONE, 1.8)
        for (x, y) in ((x0, y0), (x1, y1)):
            a.ellipse(x, y, 1.6, 1.3, BONE, INK, 0.8)
    a.ellipse(12, -5, 5.5, 5, BONE, INK, 1.2)  # skull
    a.ellipse(10.5, -5.5, 1.4, 1.5, "#1a1612")
    a.ellipse(13.5, -5.5, 1.4, 1.5, "#1a1612")
    a.save("corpse_skeleton")


def hero():
    """Hero: steel helmet with a crimson plume, blue-steel armour, crimson cape, raised sword."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-8, -27), (-4, -27), (-3, -4), (-11, -6)], CRIMSON, INK, 1.1)  # cape
        else:
            a.poly([(-6, -14), (6, -14), (5, -26), (-5, -26)], "#6a7a8e", INK, 1)  # breastplate
            a.line([(0, -26), (0, -15)], "#4a5666", 1.2)
            a.poly([(-7, -26), (-3, -27), (-3, -23), (-8, -23)], "#8a96a6", INK, 1)  # pauldron
            a.line([(4, -22), (10, -27)], INK, 4)  # sword arm
            a.line([(4, -22), (10, -27)], "#6a7a8e", 2.4)
            a.line([(8, -29), (13, -25)], INK, 2.4)  # guard
            a.line([(8, -29), (13, -25)], GOLD, 1.2)
            a.poly([(10, -28), (11.5, -26.5), (20, -44), (18.5, -45)], "#d0d4dc", INK, 1)  # blade
            a.line([(11, -27.5), (19, -44)], "#ffffff", 0.6)

    def hat(a):
        a.raw('<path d="M-6.5,-32 Q-7,-41 0,-41 Q7,-41 6.5,-32 L4,-31 L4,-34 L-4,-34 L-4,-31 Z" fill="#9aa4b2" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-8, -42), (8, -30)])
        a.raw('<path d="M-1,-41 Q-2,-50 6,-50 Q2,-46 3,-41 Z" fill="%s" stroke="%s" stroke-width="1"/>' % (CRIMSON, INK), [(-2, -51), (7, -40)])  # plume
        a.line([(0, -40), (0, -34)], "#6a7482", 1.2)
    person("unit_hero", ("#3a4656", "#2c3644"), hat=hat, extra=extra)


def training_grounds():
    """2x2 yard: small hut, weapon rack with swords and axes, archery targets with arrows."""
    a = Art()
    s = 0.98
    yard = [P(-s, -s), P(s, -s), P(s, s), P(-s, s)]
    a.poly(yard, "#7a6446", None)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], DIRT, INK, 1.2, opacity=0.9)
    for (gx, gy) in [(-0.3, 0.4), (0.4, -0.2), (0.1, 0.6)]:  # trampled patches
        x, y = P(gx, gy)
        a.ellipse(x, y, 14, 6, DIRT_DARK, opacity=0.6)
    # fence along the two front edges
    for t in [i / 6 for i in range(7)]:
        for p in (P(-s + 2 * s * t, s), P(s, s - 2 * s * t)):
            a.line([p, (p[0], p[1] - 9)], WOOD_D, 2.2)
    a.line([(P(-s, s)[0], P(-s, s)[1] - 6), (P(s, s)[0], P(s, s)[1] - 6), (P(s, -s)[0], P(s, -s)[1] - 6)], WOOD, 1.6)
    # small hut at the back corner
    hx, hy = -0.62, -0.62
    a.box(hx - 0.25, hx + 0.25, hy - 0.22, hy + 0.22, 0, 18, "#8c7b62", "#8c7b62", "#6c5e4a")
    a.poly([P(hx - 0.25, hy + 0.22, 0), P(hx - 0.1, hy + 0.22, 0), P(hx - 0.1, hy + 0.22, 12), P(hx - 0.25, hy + 0.22, 12)], "#2b1e14")
    e = 0.05
    a.poly([P(hx - 0.25 - e, hy - 0.22 - e, 18), P(hx + 0.25 + e, hy - 0.22 - e, 18), P(hx + 0.25 + e, hy, 34), P(hx - 0.25 - e, hy, 34)], "#4a3b24")
    a.poly([P(hx - 0.25 - e, hy, 34), P(hx + 0.25 + e, hy, 34), P(hx + 0.25 + e, hy + 0.22 + e, 18), P(hx - 0.25 - e, hy + 0.22 + e, 18)], "#5b4a2e")
    a.poly([P(hx + 0.25, hy - 0.22, 18), P(hx + 0.25, hy, 32), P(hx + 0.25, hy + 0.22, 18)], "#7a6a52")
    # weapon rack (left side) with swords and axes
    rx, ry = -0.55, 0.25
    a.line([P(rx - 0.2, ry, 0), P(rx - 0.2, ry, 22)], WOOD_D, 3)
    a.line([P(rx + 0.2, ry, 0), P(rx + 0.2, ry, 22)], WOOD_D, 3)
    a.line([P(rx - 0.22, ry, 20), P(rx + 0.22, ry, 20)], WOOD, 3)
    for k, u in enumerate((-0.12, 0.0, 0.12)):
        x0, y0 = P(rx + u, ry, 20)
        x1, y1 = P(rx + u, ry, 2)
        if k != 1:  # swords
            a.line([(x0, y0 - 4), (x1, y1)], INK, 3)
            a.line([(x0, y0 - 4), (x1, y1)], "#d0d4dc", 1.6)
            a.line([(x0 - 3, y0 + 1), (x0 + 3, y0 + 1)], GOLD, 1.6)
        else:  # axe
            a.line([(x0, y0 - 2), (x1, y1)], INK, 3)
            a.line([(x0, y0 - 2), (x1, y1)], WOOD_L, 1.6)
            a.poly([(x0, y0), (x0 + 7, y0 - 3), (x0 + 7, y0 + 6), (x0, y0 + 4)], "#9a9a9a", INK, 1)
    # an axe and a sword lying on the ground
    x, y = P(-0.05, 0.55)
    a.line([(x - 12, y), (x + 8, y - 4)], INK, 3)
    a.line([(x - 12, y), (x + 8, y - 4)], "#d0d4dc", 1.4)
    x, y = P(0.3, 0.2)
    a.line([(x - 8, y + 3), (x + 8, y - 1)], INK, 3)
    a.line([(x - 8, y + 3), (x + 8, y - 1)], WOOD_L, 1.6)
    a.poly([(x + 6, y - 5), (x + 12, y - 3), (x + 10, y + 3), (x + 5, y + 1)], "#9a9a9a", INK, 1)
    # two archery targets on stands, arrows stuck in them
    for (tx, ty) in [(0.45, -0.55), (0.7, -0.05)]:
        bx, by = P(tx, ty, 0)
        a.line([(bx - 6, by), (bx, by - 26)], WOOD_D, 2.4)
        a.line([(bx + 6, by), (bx, by - 26)], WOOD_D, 2.4)
        cx, cy = bx, by - 22
        a.ellipse(cx, cy, 10, 11, "#c9b070", INK, 1.3)  # straw
        a.ellipse(cx, cy, 7, 8, "#f0e8d0", None)
        a.ellipse(cx, cy, 4.6, 5.2, CRIMSON, None)
        a.ellipse(cx, cy, 2, 2.3, GOLD, None)
        for (dx, dy, ang) in [(-2, -3, -0.4), (3, 1, 0.3), (0, 4, -0.1)]:
            ex, ey = cx + dx, cy + dy
            ox, oy = ex - 9 * math.cos(ang), ey - 9 * math.sin(ang) + 2
            a.line([(ex, ey), (ox, oy)], INK, 1.8)
            a.line([(ex, ey), (ox, oy)], "#b08a58", 0.9)
            a.poly([(ox, oy - 1.5), (ox - 3, oy), (ox, oy + 1.5)], CRIMSON)
    a.save("training_grounds")


def corpse_goblin():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.ellipse(0, 1, 14, 4, "#3a1a14", opacity=0.55)  # dark stain
    a.poly([(-12, -2), (6, -6), (9, -1), (-10, 3)], "#4a3a2a")  # tunic, lying down
    a.line([(-12, 0), (-19, 2)], INK, 4.5)
    a.line([(-12, 0), (-19, 2)], "#4a6029", 2.6)
    a.ellipse(12, -3, 6, 5, "#56702f", INK, 1.2)  # head
    a.poly([(15, -6), (22, -9), (17, -3)], "#56702f")  # ear
    a.line([(10, -4.5), (12, -2.5)], INK, 1.2)
    a.line([(12, -4.5), (10, -2.5)], INK, 1.2)
    a.line([(-2, 4), (-12, 8)], INK, 2.8)
    a.line([(-2, 4), (-12, 8)], "#43301e", 1.4)
    a.poly([(-12, 5), (-18, 8), (-15, 11), (-10, 8)], "#6d6a64")  # dropped cleaver
    a.save("corpse_goblin")


def goblin():
    a = Art()
    a.shadow(11, 4.5, opacity=0.4)
    skin, skin_d = "#5f7a36", "#4a6029"
    a.line([(-3, -1), (-4, -9)], INK, 5)
    a.line([(3, -1), (4, -9)], INK, 5)
    a.line([(-3, -1.5), (-4, -9)], skin_d, 3)
    a.line([(3, -1.5), (4, -9)], skin_d, 3)
    a.poly([(-8, -8), (7, -8), (8, -22), (-5, -24)], "#4a3a2a")
    a.line([(-8, -12), (7, -12)], "#2a1e14", 1.6)
    # cleaver
    a.line([(5, -14), (12, -24)], INK, 3.4)
    a.line([(5, -14), (12, -24)], WOOD_D, 1.8)
    a.poly([(10, -30), (17, -26), (13, -20), (9, -24)], "#7d7a74")
    a.poly([(10, -30), (17, -26), (16, -25)], "#8c2a1c", stroke=None, opacity=0.8)
    # head with ears
    a.poly([(-14, -28), (-5, -27), (-6, -23)], skin)
    a.poly([(12, -30), (4, -28), (5, -24)], skin)
    a.ellipse(0, -27, 7.5, 6.5, skin, INK, 1.3)
    a.ellipse(-2, -28, 1.6, 1.3, "#ff3b2a")
    a.ellipse(3.5, -28, 1.6, 1.3, "#ff3b2a")
    a.line([(-2, -23.5), (4, -23.5)], INK, 1.2)
    a.poly([(-0.5, -23.5), (0.5, -21), (1.5, -23.5)], "#e8e0c8", INK, 0.6)
    a.raw('<path d="M-7,-30 Q-4,-38 2,-37 Q7,-36 7,-30 Q0,-33 -7,-30Z" fill="#3b3b3b" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -39), (8, -29)])
    a.save("unit_goblin")


def rat():
    """A small grey-brown rat, side view, facing right (the game flips it)."""
    a = Art()
    a.shadow(9, 3, opacity=0.35)
    fur, fur_d, pink = "#6e6258", "#4e443c", "#c98a8a"
    # tail
    a.raw('<path d="M-7,-4 Q-15,-3 -17,-9 Q-18,-13 -14,-14" fill="none" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>' % INK, [(-18, -15), (-6, -2)])
    a.raw('<path d="M-7,-4 Q-15,-3 -17,-9 Q-18,-13 -14,-14" fill="none" stroke="%s" stroke-width="1.3" stroke-linecap="round"/>' % pink, [(-18, -15), (-6, -2)])
    # feet
    for x in (-4, 4):
        a.line([(x, -3), (x + 1, 0)], INK, 2.6)
        a.line([(x, -3), (x + 1, 0)], pink, 1.2)
    # body and head
    a.ellipse(-1, -7, 8.5, 5.2, fur, INK, 1.3)
    a.ellipse(-2, -9, 5, 2.2, "#857a70", opacity=0.6)
    a.poly([(5, -11), (13, -7), (11, -4), (4, -4)], fur, INK, 1.2)
    a.ellipse(4.5, -11, 2.6, 2.4, fur_d, INK, 1.1)  # ear
    a.ellipse(4.6, -11, 1.3, 1.2, pink)
    a.ellipse(9, -8.2, 1.1, 1.0, "#ff3b2a")  # eye
    a.ellipse(13, -6.4, 1.2, 1.0, "#e0a0a0", INK, 0.7)  # nose
    a.line([(12, -6), (16, -7.5)], "#d8d0c8", 0.6)
    a.line([(12, -5.5), (16, -4.5)], "#d8d0c8", 0.6)
    a.save("unit_rat")


# ---------------------------------------------------------------- small bits

def arrow():
    a = Art()
    a.line([(-12, 0), (10, 0)], INK, 2.4)
    a.line([(-12, 0), (10, 0)], "#b08a58", 1.2)
    a.poly([(9, -2.5), (15, 0), (9, 2.5)], "#9a9a9a", INK, 1)
    a.poly([(-15, -2.5), (-10, 0), (-15, 2.5), (-12, 0)], CRIMSON, INK, 0.8)
    a.save("arrow")


def sack():
    a = Art()
    a.raw('<path d="M-6,0 Q-8,-8 -3,-10 L-4,-13 L4,-13 L3,-10 Q8,-8 6,0 Z" fill="#b89a60" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % INK, [(-8, -14), (8, 0)])
    a.line([(-3.5, -10.5), (3.5, -10.5)], "#6a5230", 1.4)
    a.save("sack")


def icon_svg(name, body):
    with open(os.path.join(ART, name + ".svg"), "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 64 64">\n%s\n</svg>\n' % body)


def icons():
    # XP: three sparkling green orbs.
    icon_svg("icon_xp", f"""
  <circle cx="21" cy="40" r="13" fill="#3fbf3a" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="44" cy="44" r="11" fill="#57d24a" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="34" cy="19" r="12" fill="#6fe35a" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="17" cy="36" r="4" fill="#d6ffb8"/>
  <circle cx="41" cy="40" r="3.5" fill="#d6ffb8"/>
  <circle cx="30" cy="15" r="4" fill="#e8ffd4"/>
  <path d="M52 10 L54 16 L60 18 L54 20 L52 26 L50 20 L44 18 L50 16Z" fill="#f2ffe0" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M8 16 L9 19 L12 20 L9 21 L8 24 L7 21 L4 20 L7 19Z" fill="#f2ffe0"/>""")
    # HP: a plain bold red heart with a highlight.
    icon_svg("icon_hp", f"""
  <path d="M32 56 C20 46 6 36 6 22 C6 13 13 7 21 7 C26 7 30 10 32 14 C34 10 38 7 43 7 C51 7 58 13 58 22 C58 36 44 46 32 56Z" fill="#d8342c" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 50 C24 43 14 35 13 25" fill="none" stroke="#a82420" stroke-width="3" stroke-linecap="round"/>
  <path d="M14 20 Q15 13 22 13" fill="none" stroke="#ff9a8a" stroke-width="4" stroke-linecap="round"/>""")
    icon_svg("icon_gold", f'''
  <circle cx="32" cy="35" r="24" fill="{GOLD_D}" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="31" r="24" fill="{GOLD}" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="31" r="16" fill="none" stroke="{GOLD_D}" stroke-width="3"/>
  <path d="M32 19 L36 29 L46 31 L36 33 L32 43 L28 33 L18 31 L28 29Z" fill="{GOLD_D}"/>
  <path d="M17 21 Q22 12 32 11" fill="none" stroke="#f3dc93" stroke-width="3.5" stroke-linecap="round"/>''')
    icon_svg("icon_food", f'''
  <path d="M8 40 Q6 22 24 18 Q32 12 42 16 Q58 20 56 38 Q56 50 32 50 Q10 50 8 40Z" fill="#b07a3a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M10 38 Q30 44 54 36" fill="none" stroke="#8a5a26" stroke-width="3"/>
  <path d="M20 24 L26 34 M31 20 L36 31 M42 21 L46 31" stroke="#e0b070" stroke-width="3.5" stroke-linecap="round"/>''')
    icon_svg("icon_materials", f'''
  <rect x="6" y="28" width="38" height="14" rx="7" fill="{WOOD}" stroke="{INK}" stroke-width="3.5"/>
  <ellipse cx="41" cy="35" rx="5" ry="7" fill="#b08a58" stroke="{INK}" stroke-width="3"/>
  <circle cx="41" cy="35" r="2" fill="{WOOD_D}"/>
  <rect x="10" y="16" width="34" height="13" rx="6.5" fill="{WOOD_L}" stroke="{INK}" stroke-width="3.5"/>
  <ellipse cx="41" cy="22.5" rx="5" ry="6.5" fill="#c49a64" stroke="{INK}" stroke-width="3"/>
  <path d="M34 58 L30 44 L42 38 L58 42 L60 56Z" fill="{STONE_L}" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M42 38 L46 50 L60 56 M46 50 L34 58" fill="none" stroke="{STONE_D}" stroke-width="2.5"/>''')
    icon_svg("icon_population", f'''
  <circle cx="22" cy="20" r="8" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M8 50 Q8 30 22 30 Q36 30 36 50Z" fill="#7a6048" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="42" cy="22" r="8" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M28 54 Q28 32 42 32 Q56 32 56 54Z" fill="#566a3a" stroke="{INK}" stroke-width="3.5"/>''')
    icon_svg("icon_build", f'''
  <path d="M14 54 L38 30" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>
  <path d="M14 54 L38 30" stroke="{WOOD_L}" stroke-width="5" stroke-linecap="round"/>
  <path d="M30 14 L50 34 L56 28 L44 16 Q38 8 30 14Z" fill="#8a8a8a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''')
    icon_svg("icon_village", f'''
  <path d="M8 32 L32 12 L56 32Z" fill="#5b4a2e" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <rect x="14" y="32" width="36" height="22" fill="#8c7b62" stroke="{INK}" stroke-width="3.5"/>
  <rect x="27" y="38" width="10" height="16" fill="#2b1e14"/>
  <rect x="40" y="37" width="6" height="6" fill="{GLOW}"/>''')
    icon_svg("icon_army", f'''
  <path d="M18 8 Q48 32 18 56" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M18 8 Q48 32 18 56" fill="none" stroke="#8a5a30" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M18 8 L18 56" stroke="#d8d0b8" stroke-width="2"/>
  <path d="M8 32 L50 32" stroke="{INK}" stroke-width="4"/>
  <path d="M48 26 L58 32 L48 38Z" fill="#9a9a9a" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M6 27 L12 32 L6 37" fill="{CRIMSON}" stroke="{INK}" stroke-width="2"/>''')
    icon_svg("icon_enemies", f'''
  <path d="M10 8 L40 38 L46 32 L16 2Z" fill="#9a9a9a" stroke="{INK}" stroke-width="3" stroke-linejoin="round" transform="translate(2 8)"/>
  <path d="M54 8 L24 38 L18 32 L48 2Z" fill="#8a8a8a" stroke="{INK}" stroke-width="3" stroke-linejoin="round" transform="translate(-2 8)"/>
  <path d="M14 42 L24 52 M50 42 L40 52" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M14 42 L24 52 M50 42 L40 52" stroke="{WOOD_L}" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M10 46 L20 36 M54 46 L44 36" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>
  <circle cx="32" cy="46" r="7" fill="{CRIMSON}" stroke="{INK}" stroke-width="3"/>''')
    icon_svg("icon_fullscreen", f'''
  <path d="M8 24 L8 8 L24 8 M40 8 L56 8 L56 24 M56 40 L56 56 L40 56 M24 56 L8 56 L8 40" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M8 24 L8 8 L24 8 M40 8 L56 8 L56 24 M56 40 L56 56 L40 56 M24 56 L8 56 L8 40" fill="none" stroke="#efe3c8" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_pause", f'''
  <rect x="15" y="12" width="12" height="40" rx="3" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>
  <rect x="37" y="12" width="12" height="40" rx="3" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>''')
    icon_svg("icon_play", f'''
  <path d="M18 12 L50 32 L18 52Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''')
    icon_svg("icon_fast", f'''
  <path d="M6 14 L32 32 L6 50Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 14 L58 32 L32 50Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''')
    icon_svg("icon_hero", f'''
  <path d="M10 54 L44 20 M54 54 L20 20" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M10 54 L44 20 M54 54 L20 20" stroke="#d0d4dc" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M16 30 Q15 10 32 10 Q49 10 48 30 L42 32 L42 26 L22 26 L22 32 Z" fill="#9aa4b2" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M30 10 Q28 -2 44 2 Q36 6 36 10 Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="2.5"/>
  <path d="M32 11 L32 25" stroke="#6a7482" stroke-width="2.5"/>
  <path d="M12 50 L20 42 M52 50 L44 42" stroke="{GOLD}" stroke-width="4" stroke-linecap="round"/>''')
    icon_svg("icon_fastest", f'''
  <path d="M2 16 L20 32 L2 48Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M22 16 L40 32 L22 48Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M42 16 L60 32 L42 48Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''')
    icon_svg("icon_collapse", f'''
  <path d="M24 12 L44 32 L24 52" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_expand", f'''
  <path d="M40 12 L20 32 L40 52" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')
    # Settings: a gear with 6 teeth.
    teeth = 6
    pts = []
    for i in range(teeth * 4):
        ang = math.pi * 2 * i / (teeth * 4) - math.pi / 2
        r = 27 if i % 4 in (1, 2) else 19
        pts.append((32 + r * math.cos(ang), 32 + r * math.sin(ang)))
    gear = "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"
    icon_svg("icon_settings", f'''
  <path d="{gear} M32 23 A9 9 0 1 0 32.01 23 Z" fill="#c9ccd4" fill-rule="evenodd" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>
  <circle cx="32" cy="32" r="9" fill="none" stroke="#8a8f99" stroke-width="2"/>''')
    icon_svg("icon_sheet_up", f'''
  <path d="M12 40 L32 20 L52 40" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_sheet_down", f'''
  <path d="M12 24 L32 44 L52 24" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')


def flags():
    """Language flags for the settings dialog (landscape 60x30 viewBox)."""
    with open(os.path.join(ART, "flag_gb.svg"), "w") as f:
        f.write('''<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60" viewBox="0 0 60 30">
<clipPath id="s"><path d="M0,0 v30 h60 v-30 z"/></clipPath>
<clipPath id="t"><path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z"/></clipPath>
<g clip-path="url(#s)">
<path d="M0,0 v30 h60 v-30 z" fill="#012169"/>
<path d="M0,0 L60,30 M60,0 L0,30" stroke="#fff" stroke-width="6"/>
<path d="M0,0 L60,30 M60,0 L0,30" clip-path="url(#t)" stroke="#C8102E" stroke-width="4"/>
<path d="M30,0 v30 M0,15 h60" stroke="#fff" stroke-width="10"/>
<path d="M30,0 v30 M0,15 h60" stroke="#C8102E" stroke-width="6"/>
</g>
<rect x="0.5" y="0.5" width="59" height="29" fill="none" stroke="#15110d" stroke-width="1"/>
</svg>
''')


def app_icon():
    with open(os.path.join(ROOT, "icon.svg"), "w") as f:
        f.write(f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1c2430"/><stop offset="1" stop-color="#3a4a3a"/></linearGradient></defs>
  <rect x="8" y="8" width="240" height="240" rx="44" fill="url(#sky)" stroke="{INK}" stroke-width="8"/>
  <circle cx="186" cy="64" r="22" fill="#e8dcb0" opacity="0.9"/>
  <path d="M12 200 L40 150 L62 190 L86 140 L110 200Z M150 200 L178 146 L200 186 L222 150 L244 200Z" fill="#1a2c20"/>
  <path d="M12 204 Q128 180 244 204 L244 210 Q244 244 204 244 L52 244 Q12 244 12 210Z" fill="#314a24"/>
  <path d="M92 96 L164 96 L158 214 L98 214Z" fill="{STONE_L}" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>
  <path d="M128 96 L164 96 L158 214 L128 214Z" fill="{STONE_R}"/>
  <path d="M84 84 L172 84 L172 100 L84 100Z" fill="{STONE_T}" stroke="{INK}" stroke-width="6"/>
  <path d="M84 66 h18 v18 h-18z M119 66 h18 v18 h-18z M154 66 h18 v18 h-18z" fill="{STONE_T}" stroke="{INK}" stroke-width="6"/>
  <path d="M116 214 L116 180 Q128 166 140 180 L140 214Z" fill="#2b1e14" stroke="{INK}" stroke-width="5"/>
  <rect x="121" y="124" width="14" height="22" rx="7" fill="{GLOW}" stroke="{INK}" stroke-width="4"/>
  <path d="M128 66 L128 26" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M131 28 L170 36 L158 46 L170 56 L131 62Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
  <circle cx="146" cy="45" r="5" fill="{GOLD}"/>
</svg>
''')


def title_background():
    """1920x1080 title backdrop: moonlit dusk over mountains, the walled outpost
    on a hill with lit windows, dark pine forest and a few goblin eyes."""
    rng = random.Random(1337)
    W, H = 1920, 1080
    out = []
    out.append('''<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#0a0f1a"/><stop offset="0.55" stop-color="#1c2433"/><stop offset="1" stop-color="#3a3140"/>
  </linearGradient>
  <radialGradient id="moonglow"><stop offset="0" stop-color="#efe3b8" stop-opacity="0.55"/><stop offset="1" stop-color="#efe3b8" stop-opacity="0"/></radialGradient>
  <radialGradient id="windowglow"><stop offset="0" stop-color="#f0b04a" stop-opacity="0.5"/><stop offset="1" stop-color="#f0b04a" stop-opacity="0"/></radialGradient>
  <linearGradient id="mist" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a90a0" stop-opacity="0"/><stop offset="0.5" stop-color="#8a90a0" stop-opacity="0.16"/><stop offset="1" stop-color="#8a90a0" stop-opacity="0"/></linearGradient>
  <radialGradient id="vignette" cx="0.5" cy="0.45" r="0.75"><stop offset="0.55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.75"/></radialGradient>
</defs>''')
    out.append('<rect width="%d" height="%d" fill="url(#sky)"/>' % (W, H))
    for _ in range(140):
        x, y = rng.uniform(0, W), rng.uniform(0, 520)
        out.append('<circle cx="%.0f" cy="%.0f" r="%.1f" fill="#e8e4d0" opacity="%.2f"/>' % (x, y, rng.uniform(0.6, 1.8), rng.uniform(0.2, 0.8)))
    out.append('<circle cx="1480" cy="230" r="260" fill="url(#moonglow)"/>')
    out.append('<circle cx="1480" cy="230" r="74" fill="#e8dcb0"/>')
    out.append('<circle cx="1455" cy="215" r="14" fill="#d2c595"/><circle cx="1505" cy="255" r="10" fill="#d2c595"/>')

    def ridge(base, amp, step, color, seed, snow=None):
        r = random.Random(seed)
        pts = [(0, H)]
        x = 0
        y = base
        while x <= W + step:
            y = base - r.uniform(0, amp)
            pts.append((x, y))
            x += r.uniform(step * 0.6, step * 1.4)
        pts.append((W, H))
        d = " ".join("%.0f,%.0f" % p for p in pts)
        out.append('<polygon points="%s" fill="%s"/>' % (d, color))
        if snow:
            for (px, py) in pts[1:-1]:
                if py < base - amp * 0.7:
                    out.append('<polygon points="%.0f,%.0f %.0f,%.0f %.0f,%.0f" fill="%s" opacity="0.5"/>' % (px, py, px - 22, py + 26, px + 20, py + 24, snow))
    ridge(640, 260, 150, "#1f2733", 1, snow="#5a6474")
    out.append('<rect x="0" y="520" width="%d" height="200" fill="url(#mist)"/>' % W)
    ridge(720, 150, 110, "#18201f", 2)
    out.append('<rect x="0" y="640" width="%d" height="160" fill="url(#mist)"/>' % W)

    # the outpost on its hill
    out.append('<path d="M560,860 Q760,640 960,650 Q1160,640 1360,860 Z" fill="#141c18"/>')
    out.append('<path d="M900,880 Q930,800 960,735 Q990,800 1040,880" fill="none" stroke="#2b241c" stroke-width="18" stroke-linecap="round"/>')
    wall = "#0f1512"
    rim = "#3a4a52"
    out.append('<rect x="820" y="610" width="280" height="90" fill="%s"/>' % wall)
    for x in range(820, 1100, 28):
        out.append('<rect x="%d" y="596" width="16" height="16" fill="%s"/>' % (x, wall))
    for tx in (800, 1080):
        out.append('<rect x="%d" y="560" width="46" height="140" fill="%s"/>' % (tx, wall))
        for k in range(3):
            out.append('<rect x="%d" y="546" width="10" height="16" fill="%s"/>' % (tx + k * 18, wall))
        out.append('<line x1="%d" y1="546" x2="%d" y2="500" stroke="%s" stroke-width="3"/>' % (tx + 23, tx + 23, wall))
        out.append('<path d="M%d,502 l34,8 l-10,8 l10,8 l-34,6 Z" fill="#8c1c2b"/>' % (tx + 25))
        out.append('<line x1="%d" y1="560" x2="%d" y2="700" stroke="%s" stroke-width="2" opacity="0.6"/>' % (tx + 45, tx + 45, rim))
    for hx, hy in [(860, 590), (920, 575), (985, 585), (1045, 592)]:
        out.append('<path d="M%d,%d l30,-26 l30,26 Z" fill="#1a1510"/>' % (hx - 30, hy))
    for wx, wy in [(850, 640), (905, 655), (1010, 645), (1060, 660), (815, 590), (1095, 600)]:
        out.append('<circle cx="%d" cy="%d" r="30" fill="url(#windowglow)"/>' % (wx, wy))
        out.append('<rect x="%d" y="%d" width="8" height="11" fill="#f0b04a"/>' % (wx - 4, wy - 5))
    out.append('<path d="M940,700 L940,668 Q960,648 980,668 L980,700 Z" fill="#050807"/>')
    out.append('<rect x="0" y="760" width="%d" height="140" fill="url(#mist)"/>' % W)

    def pine(x, base, h, color):
        w = h * 0.36
        pts = []
        for k in range(4):
            t0 = k / 4.0
            yb = base - h * t0 * 0.85
            ww = w * (1 - t0 * 0.7)
            pts.append("M%.0f,%.0f L%.0f,%.0f L%.0f,%.0f Z" % (x - ww, yb, x, yb - h * 0.38, x + ww, yb))
        out.append('<path d="%s" fill="%s"/>' % (" ".join(pts), color))
        out.append('<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="%s"/>' % (x - h * 0.03, base - 4, h * 0.06, h * 0.12, color))

    for layer, (base, hmin, hmax, color, count) in enumerate([(880, 90, 160, "#0e1612", 60), (960, 140, 240, "#0a110d", 46), (1080, 260, 420, "#060a08", 18)]):
        for i in range(count):
            x = rng.uniform(-40, W + 40)
            if layer == 2 and 520 < x < 1400:
                continue  # keep the centre open so the outpost stays visible
            pine(x, base + rng.uniform(-20, 30), rng.uniform(hmin, hmax), color)
    for gx, gy in [(330, 930), (1610, 905), (1290, 985)]:
        out.append('<circle cx="%d" cy="%d" r="3" fill="#ff3b2a"/><circle cx="%d" cy="%d" r="3" fill="#ff3b2a"/>' % (gx, gy, gx + 12, gy))
    out.append('<rect width="%d" height="%d" fill="url(#vignette)"/>' % (W, H))
    with open(os.path.join(ART, "title_bg.svg"), "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s\n</svg>\n' % (W, H, W, H, "\n".join(out)))


# ============================================================ biome expansion
# New ground tiles, bridges, props, map objects, lairs and the miner.

def _glow(a, x, y, rx, ry, col, op=0.6):
    """Soft radial glow (unique gradient id per file)."""
    gid = "gl%d" % len(a.els)
    a.raw('<defs><radialGradient id="%s"><stop offset="0" stop-color="%s" stop-opacity="%s"/>'
          '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient></defs>' % (gid, col, op, col), [(x, y)])
    a.ellipse(x, y, rx, ry, "url(#%s)" % gid)


def _tuft(a, x, y, col, sw=1.1, h=5.0):
    a.line([(x - 2, y), (x - 3, y - h * 0.8)], col, sw)
    a.line([(x, y), (x, y - h)], col, sw)
    a.line([(x + 2, y), (x + 3, y - h * 0.8)], col, sw)


def _arc(a, x, y, w, lift, col, sw, op):
    a.raw('<path d="M%s,%s q%s,%s %s,0" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" opacity="%s"/>'
          % (fmt(x - w / 2), fmt(y), fmt(w / 2), fmt(-lift), fmt(w), col, sw, op), [(x - w / 2, y - lift), (x + w / 2, y)])


def _rock(a, rng, cx, cy, r, h=None, light="#77736c", dark="#57534c", top="#8b877f", moss=None, sw=1.3, n=7):
    """Faceted boulder standing on the ground at screen (cx, cy)."""
    h = h if h is not None else r * 0.9
    sil = []
    for i in range(n + 1):
        ang = math.pi * i / n
        rr = rng.uniform(0.82, 1.05) if 0 < i < n else 1.0
        sil.append((cx + math.cos(ang) * r * rr, cy - math.sin(ang) * h * rr))
    base = [(cx - r * 0.6, cy + r * 0.2), (cx + r * 0.05, cy + r * 0.28), (cx + r * 0.6, cy + r * 0.2)]
    a.poly(sil + base, dark, INK, sw)
    m = n // 2
    a.poly(sil[m:] + [base[0], base[1]], light, stroke=None)
    tx, ty = sil[m]
    a.poly([sil[m - 1] if m > 0 else sil[m], sil[m], sil[m + 1], (tx - r * 0.1, ty + h * 0.3)], top, stroke=None, opacity=0.8)
    if moss:
        a.ellipse(tx - r * 0.15, ty + h * 0.15, r * 0.45, h * 0.18, moss, opacity=0.85)
    a.line(sil + [base[2], base[1], base[0], sil[-1]], INK, sw)
    a.line([sil[m], base[1]], INK, sw * 0.6, opacity=0.5)


def _save_pair(a, b, na, nb, extra=None):
    """Save two variants on an identical canvas so they line up."""
    pts = a.pts + b.pts
    a.pts, b.pts = pts[:], pts[:]
    a.save(na, extra=extra)
    b.save(nb, extra=extra)


# ------------------------------------------------------------ new ground tiles

def tile_grass_dark(i):
    rng = random.Random(200 + i)
    a = Art()
    a.poly(diamond(1.03), ["#35502c", "#334e2b"][i], stroke=None)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(8, 16), rng.uniform(4, 7), "#41603a" if rng.random() < 0.5 else "#27401f", opacity=0.22)
    for _ in range(7):
        x, y = rand_in_diamond(rng, 0.8)
        _tuft(a, x, y, "#243a1e")
    for _ in range(4 + 2 * i):  # fallen needles
        x, y = rand_in_diamond(rng, 0.8)
        d = rng.uniform(-1.5, 1.5)
        a.line([(x - 3, y + d), (x + 3, y - d)], "#5a4630", 0.9, opacity=0.6)
    a.save("tile_grass_dark_%d" % i, pad=0, fixed=(-66, -34, 66, 34))


def tile_meadow(i):
    rng = random.Random(210 + i)
    a = Art()
    a.poly(diamond(1.03), ["#4b6a31", "#4d6c33", "#4a6930"][i], stroke=None)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(8, 16), rng.uniform(4, 7), "#5f813d" if rng.random() < 0.6 else "#3d5a28", opacity=0.22)
    for _ in range(7):
        x, y = rand_in_diamond(rng, 0.8)
        _tuft(a, x, y, "#39552a")
    for _ in range([0, 5, 8][i]):
        x, y = rand_in_diamond(rng, 0.78)
        col = rng.choice(["#ece6d0", "#e2c24a", "#9a7ac8", "#ece6d0"])
        a.line([(x, y + 2.5), (x, y)], "#39552a", 0.9)
        a.ellipse(x, y, 1.6, 1.3, col, "#2a3a1c", 0.5)
    a.save("tile_meadow_%d" % i, pad=0, fixed=(-66, -34, 66, 34))


def tile_heath(i):
    rng = random.Random(220 + i)
    a = Art()
    a.poly(diamond(1.03), ["#4f4b31", "#524d32"][i], stroke=None)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(8, 15), rng.uniform(4, 7), "#5d5b37" if rng.random() < 0.5 else "#3f3a26", opacity=0.35)
    for _ in range(4):
        x, y = rand_in_diamond(rng, 0.8)
        _tuft(a, x, y, "#3a3a24")
    for _ in range(6):  # heather tufts
        x, y = rand_in_diamond(rng, 0.78)
        a.line([(x - 2, y), (x - 3, y - 4)], "#3a3222", 1.0)
        a.line([(x + 2, y), (x + 3, y - 4)], "#3a3222", 1.0)
        for _ in range(4):
            a.ellipse(x + rng.uniform(-3.5, 3.5), y - rng.uniform(2, 5.5), rng.uniform(1.2, 1.9), rng.uniform(1.0, 1.5),
                      rng.choice(["#7c4a78", "#935c8c", "#6a3e66"]))
    for _ in range(1 + i):  # pebbles
        x, y = rand_in_diamond(rng, 0.7)
        a.ellipse(x, y, 2.8, 1.8, "#86827a", INK, 0.8)
        a.ellipse(x - 0.8, y - 0.6, 1.2, 0.6, "#a8a49a")
    a.save("tile_heath_%d" % i, pad=0, fixed=(-66, -34, 66, 34))


def tile_swamp(i):
    rng = random.Random(230 + i)
    a = Art()
    a.poly(diamond(1.03), ["#3b4527", "#394326"][i], stroke=None)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(8, 15), rng.uniform(4, 7), "#2e381f" if rng.random() < 0.6 else "#4a532e", opacity=0.4)
    pools = [(-0.12, 0.05)] if i == 0 else [(0.15, -0.12), (-0.2, 0.18)]
    for (gx, gy) in pools:
        x, y = P(gx + rng.uniform(-0.05, 0.05), gy + rng.uniform(-0.05, 0.05))
        rx, ry = rng.uniform(13, 18), rng.uniform(5.5, 7.5)
        a.ellipse(x, y + 0.8, rx + 1.5, ry + 1.2, "#2a3120", opacity=0.8)
        a.ellipse(x, y, rx, ry, "#1d3636", "#26301e", 1.2)
        a.ellipse(x - rx * 0.2, y - ry * 0.25, rx * 0.55, ry * 0.4, "#2a4a48", opacity=0.7)
        a.line([(x - rx * 0.5, y - ry * 0.3), (x - rx * 0.1, y - ry * 0.4)], "#6a8a84", 1.0, opacity=0.5)
        for _ in range(3):  # reed stubs at the pool rim
            ang = rng.uniform(0, math.pi * 2)
            px, py = x + math.cos(ang) * rx * 0.95, y + math.sin(ang) * ry * 0.95
            hh = rng.uniform(4, 8)
            a.line([(px, py), (px + rng.uniform(-1, 1), py - hh)], "#6c6838", 1.2)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.8)
        _tuft(a, x, y, "#2c381d")
    a.save("tile_swamp_%d" % i, pad=0, fixed=(-66, -34, 66, 34))


def tile_ash(i):
    rng = random.Random(240 + i)
    a = Art()
    a.poly(diamond(1.03), ["#55524d", "#524f4a"][i], stroke=None)
    for _ in range(7):
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(7, 15), rng.uniform(3, 6), "#48453f" if rng.random() < 0.6 else "#63605a", opacity=0.5)
    for _ in range(9):  # cinders
        x, y = rand_in_diamond(rng, 0.82)
        a.ellipse(x, y, rng.uniform(1.2, 2.8), rng.uniform(0.8, 1.6), "#2c2a27", opacity=0.85)
    for _ in range(2 - i):
        x, y = rand_in_diamond(rng, 0.6)
        a.ellipse(x, y, 5, 3, "#e0602a", opacity=0.22)
        a.ellipse(x, y, 1.1, 0.8, "#f0902a")
    if i == 1:
        x, y = rand_in_diamond(rng, 0.5)
        a.ellipse(x, y, 4, 2.4, "#e0602a", opacity=0.15)
        a.ellipse(x, y, 0.8, 0.6, "#d8782a", opacity=0.8)
    a.save("tile_ash_%d" % i, pad=0, fixed=(-66, -34, 66, 34))


def tile_forest_oak():
    rng = random.Random(250)
    a = Art()
    a.poly(diamond(1.03), "#374a25", stroke=None)
    for _ in range(8):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(4, 10), rng.uniform(2, 4), "#2c3d1d", opacity=0.55)
    for _ in range(14):  # fallen leaves
        x, y = rand_in_diamond(rng, 0.82)
        ang = rng.uniform(0, math.pi)
        dx, dy = math.cos(ang) * 2.6, math.sin(ang) * 1.3
        px, py = -math.sin(ang) * 1.2, math.cos(ang) * 0.6
        a.poly([(x - dx, y - dy), (x + px, y + py), (x + dx, y + dy), (x - px, y - py)],
               rng.choice(["#8a6428", "#a0762e", "#6e4c22", "#7a5a2a", "#94702c"]), stroke=None, opacity=0.9)
    for _ in range(3):
        x, y = rand_in_diamond(rng, 0.8)
        a.line([(x - 4, y), (x + 4, y - 1.5)], "#4a3824", 1.1, opacity=0.8)
    a.save("tile_forest_oak", pad=0, fixed=(-66, -34, 66, 34))


def tile_sand():
    rng = random.Random(260)
    a = Art()
    base = "#bba671"
    a.poly(diamond(1.14), base, stroke=None, opacity=0.5)
    a.poly(diamond(1.04), base, stroke=None)
    for _ in range(4):
        x, y = rand_in_diamond(rng, 0.7)
        w = rng.uniform(16, 30)
        _arc(a, x, y, w, 6, "#a38f5e", 1.5, 0.7)
        _arc(a, x + 1, y - 2, w - 4, 5, "#d2c08e", 1.1, 0.6)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(1.0, 1.8), rng.uniform(0.7, 1.2), "#8e7e56")
    for _ in range(2):
        x, y = rand_in_diamond(rng, 0.7)
        a.ellipse(x, y, 1.6, 1.1, "#ece2c8", "#8e7e56", 0.5)
    a.save("tile_sand", pad=0, fixed=(-74, -37, 74, 37))


def tile_water(i):
    rng = random.Random(270 + i)
    a = Art()
    a.poly(diamond(1.13), "#1f3a4a", stroke=None)  # (overlaps its neighbours: no seams)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.7)
        a.ellipse(x, y, rng.uniform(10, 18), rng.uniform(4, 7), "#1a3140" if rng.random() < 0.6 else "#27465a", opacity=0.5)
    for _ in range(3 + i):
        x, y = rand_in_diamond(rng, 0.7)
        w = rng.uniform(8, 14)
        _arc(a, x, y, w, 2.5, "#3f6a7c", 1.2, 0.55)
    a.save("tile_water_%d" % i, pad=0, fixed=(-74, -37, 74, 37))


SHALLOW = "#3b6a6a"


def tile_shallow():
    rng = random.Random(280)
    a = Art()
    a.poly(diamond(1.13), SHALLOW, stroke=None)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(9, 16), rng.uniform(4, 7), "#6d8a72", opacity=0.3)
    for _ in range(7):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(1.3, 2.6), rng.uniform(0.9, 1.6), "#58766e" if rng.random() < 0.5 else "#7a9486", opacity=0.75)
    for _ in range(3):
        x, y = rand_in_diamond(rng, 0.7)
        _arc(a, x, y, rng.uniform(8, 13), 2.2, "#8ab8b0", 1.1, 0.45)
    a.save("tile_shallow", pad=0, fixed=(-74, -37, 74, 37))


def tile_lava():
    rng = random.Random(290)
    a = Art()
    a.poly(diamond(1.13), "#2a1e18", stroke=None)
    _glow(a, 0, 0, 62, 31, "#e05a1a", 0.55)
    # crust plates
    for _ in range(7):
        x, y = rand_in_diamond(rng, 0.8)
        r = rng.uniform(7, 12)
        pts = [(x + math.cos(t) * r * rng.uniform(0.7, 1.1), y + math.sin(t) * r * 0.5 * rng.uniform(0.7, 1.1))
               for t in [k * math.pi / 3 for k in range(6)]]
        a.poly(pts, rng.choice(["#3a2c24", "#30241e", "#342820"]), "#1a110c", 1.0, opacity=0.9)
    # glowing cracks from the core to each edge midpoint, so neighbouring tiles connect
    for (gx, gy) in [(0.5, 0), (-0.5, 0), (0, 0.5), (0, -0.5)]:
        pts = [(0.0, 0.0)]
        for t in (0.3, 0.6):
            x, y = P(gx * t, gy * t)
            pts.append((x + rng.uniform(-5, 5), y + rng.uniform(-2.5, 2.5)))
        pts.append(P(gx * 1.02, gy * 1.02))
        a.line(pts, "#b8360c", 4.2, opacity=0.8)
        a.line(pts, "#f08a24", 2.0)
        a.line(pts, "#ffd870", 0.8)
    for _ in range(3):  # small side cracks
        x, y = rand_in_diamond(rng, 0.6)
        pts = [(x, y), (x + rng.uniform(-9, 9), y + rng.uniform(-4, 4))]
        a.line(pts, "#b8360c", 2.6, opacity=0.7)
        a.line(pts, "#f08a24", 1.1)
    a.ellipse(0, 0, 15, 7.5, "#e0601a", "#8a2408", 1.2)
    a.ellipse(0, -0.5, 9, 4.2, "#f8a030")
    a.ellipse(0, -0.8, 4.5, 2, "#ffe080")
    a.save("tile_lava", pad=0, fixed=(-74, -37, 74, 37))


def tile_ford():
    rng = random.Random(300)
    a = Art()
    a.poly(diamond(1.16), SHALLOW, stroke=None, opacity=0.45)
    a.poly(diamond(1.06), SHALLOW, stroke=None)
    for _ in range(5):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(9, 16), rng.uniform(4, 7), "#6d8a72", opacity=0.35)
    for _ in range(26):  # gravel bed
        x, y = rand_in_diamond(rng, 0.9)
        a.ellipse(x, y, rng.uniform(0.9, 1.9), rng.uniform(0.7, 1.2), rng.choice(["#8a8676", "#6a6a60", "#9c9888"]), opacity=0.85)
    a.poly(diamond(0.8), "#8a8a74", stroke=None, opacity=0.25)  # a paler gravel bank under the stones
    for gx in (-0.33, 0.0, 0.33):  # flat stepping stones in a grid: reads as a path both ways
        for gy in (-0.33, 0.0, 0.33):
            x, y = P(gx + rng.uniform(-0.03, 0.03), gy + rng.uniform(-0.03, 0.03))
            rx, ry = rng.uniform(7, 8.5), rng.uniform(3.6, 4.3)
            a.ellipse(x, y + 1.6, rx + 1.2, ry + 0.8, "#24484a", opacity=0.7)
            a.ellipse(x, y, rx, ry, "#8a857a", INK, 1.1)
            a.ellipse(x - rx * 0.2, y - ry * 0.25, rx * 0.55, ry * 0.45, "#a39e90", opacity=0.9)
    for _ in range(3):
        x, y = rand_in_diamond(rng, 0.8)
        _arc(a, x, y, rng.uniform(7, 11), 2, "#8ab8b0", 1.0, 0.45)
    a.save("tile_ford", pad=0, fixed=(-76, -38, 76, 38))


def tile_road_pass():
    rng = random.Random(310)
    a = Art()
    base = "#6a6154"
    a.poly(diamond(1.16), base, stroke=None, opacity=0.45)
    a.poly(diamond(1.06), base, stroke=None)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.8)
        a.ellipse(x, y, rng.uniform(5, 12), rng.uniform(2, 5), "#574f44" if rng.random() < 0.6 else "#7e7667", opacity=0.55)
    for _ in range(16):
        x, y = rand_in_diamond(rng, 0.88)
        a.ellipse(x, y, rng.uniform(0.9, 2.0), rng.uniform(0.7, 1.3), rng.choice(["#9a9486", "#4a443b", "#857e70"]))
    for (gx, gy) in [(-0.25, -0.2), (0.22, -0.28), (0.02, 0.05), (-0.28, 0.25), (0.3, 0.18), (0.05, 0.36)]:
        x, y = P(gx + rng.uniform(-0.06, 0.06), gy + rng.uniform(-0.06, 0.06))
        rx = rng.uniform(3.5, 6)
        a.ellipse(x, y + 1, rx + 0.8, rx * 0.5 + 0.6, "#3a352e", opacity=0.6)
        a.ellipse(x, y, rx, rx * 0.55, "#7c776c", INK, 1.0)
        a.ellipse(x - rx * 0.25, y - rx * 0.15, rx * 0.5, rx * 0.25, "#9c978a")
    a.save("tile_road_pass", pad=0, fixed=(-76, -38, 76, 38))


def tile_foam():
    rng = random.Random(320)
    a = Art()
    for scale, sw, op in ((0.99, 2.2, 0.38), (0.9, 1.2, 0.22)):
        d = diamond(scale)
        for k in range(4):
            (x0, y0), (x1, y1) = d[k], d[(k + 1) % 4]
            t = rng.uniform(0, 0.06)
            while t < 1:
                t1 = min(1, t + rng.uniform(0.1, 0.24))
                a.line([(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t), (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1)], "#e6efe8", sw, opacity=op)
                t = t1 + rng.uniform(0.04, 0.1)
    for _ in range(10):
        k = rng.randrange(4)
        (x0, y0), (x1, y1) = diamond(0.94)[k], diamond(0.94)[(k + 1) % 4]
        t = rng.uniform(0, 1)
        a.ellipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 1.2, 0.8, "#e6efe8", opacity=0.3)
    a.save("tile_foam", pad=0, fixed=(-66, -34, 66, 34))


# --------------------------------------------------------------------- bridges

BRIDGE_SEEDS = {"stone": 400, "timber": 410, "rope": 420, "stilts": 430, "charred": 440}


def bridge(style, axis):
    """One-tile bridge. axis 'x' runs along grid x (upper-left to lower-right),
    'y' along grid y (upper-right to lower-left). u = along the span, v = across."""
    rng = random.Random(BRIDGE_SEEDS[style] + (0 if axis == "x" else 5))
    a = Art()
    hw = 0.275

    def Q(u, v, z=0.0):
        return P(u, v, z) if axis == "x" else P(v, u, z)

    lit = axis == "x"  # the long visible face is the lit left face for _x, the dark right face for _y
    prof = {"stone": lambda u: 4 + 7 * (1 - (2 * u) ** 2),
            "timber": lambda u: 8.0,
            "rope": lambda u: 8 - 2 * (1 - (2 * u) ** 2),
            "stilts": lambda u: 8 - 3.5 * (1 - (2 * u) ** 2),
            "charred": lambda u: 7.0}[style]
    us = [-0.5 + k / 10 for k in range(11)]

    def strip(v0, v1, dz0=0.0, dz1=0.0, u0=-0.5, u1=0.5, n=10):
        uu = [u0 + (u1 - u0) * k / n for k in range(n + 1)]
        return [Q(u, v0, prof(u) + dz0) for u in uu] + [Q(u, v1, prof(u) + dz1) for u in reversed(uu)]

    def face(v, ztop, zbot, u0=-0.5, u1=0.5, n=10):
        """Vertical band at across-position v; ztop/zbot are functions of u."""
        uu = [u0 + (u1 - u0) * k / n for k in range(n + 1)]
        return [Q(u, v, ztop(u)) for u in uu] + [Q(u, v, zbot(u)) for u in reversed(uu)]

    # shadow on the water
    a.poly([Q(-0.5, -hw + 0.06, 0), Q(0.5, -hw + 0.06, 0), Q(0.5, hw + 0.12, 0), Q(-0.5, hw + 0.12, 0)], "#000", stroke=None, opacity=0.25)

    if style == "stone":
        sl, sr, st = ("#7a766e", "#5c5953", "#8e8a82")
        side = sl if lit else sr
        ra = 0.34  # arch half-span

        def zb(u):
            return -2 + (9 * (1 - (u / ra) ** 2) if abs(u) < ra else 0)
        # far body face, seen through the arch
        a.poly(face(-hw, lambda u: prof(u), zb, n=16), "#2c2a27", INK, 1.0)
        a.poly(strip(-hw, hw), "#7e7a72", INK, 1.2)  # deck
        for k in range(1, 10):  # paving joints
            u = -0.5 + k / 10
            a.line([Q(u, -hw + 0.05, prof(u)), Q(u, hw - 0.05, prof(u))], "#65625b", 0.9)
        a.line([Q(u, 0, prof(u)) for u in us], "#65625b", 0.9)
        # far parapet
        a.poly(face(-hw + 0.06, lambda u: prof(u) + 6, lambda u: prof(u)), side, INK, 1.1)
        a.poly(strip(-hw, -hw + 0.06, 6, 6), st, INK, 1.1)
        # near body face with the arch, running up into the near parapet
        a.poly(face(hw, lambda u: prof(u) + 6, zb, n=16), side, INK, 1.3)
        for k in range(-3, 4):  # voussoirs
            u = k * ra / 3.5
            z0 = zb(u)
            a.line([Q(u, hw, z0), Q(u * 1.12, hw, z0 + 4)], "#46433f", 1.0)
        for u in (-0.44, 0.44):
            a.line([Q(u, hw, -2), Q(u, hw, prof(u) + 6)], "#46433f", 1.0)
        a.line([Q(u, hw, prof(u) + 1) for u in us], "#46433f", 0.9)  # coping course
        a.poly(strip(hw - 0.06, hw, 6, 6), st, INK, 1.1)
        a.poly([Q(0.5, -hw, prof(0.5)), Q(0.5, hw, prof(0.5)), Q(0.5, hw, -2), Q(0.5, -hw, -2)], sr if lit else sl, INK, 1.1)
        a.poly([Q(0.5, hw - 0.06, prof(0.5) + 6), Q(0.5, hw, prof(0.5) + 6), Q(0.5, hw, prof(0.5)), Q(0.5, hw - 0.06, prof(0.5))], sr if lit else sl, INK, 1.1)
        for (u, v) in [(-0.2, -0.1), (0.15, 0.12), (0.3, -0.15)]:
            x, y = Q(u, v, prof(u))
            a.ellipse(x, y, 3, 1.3, "#5a6a40", opacity=0.6)  # a little moss
        a.save("bridge_%s_%s" % (style, axis))
        return

    pal = {"timber": (["#6e5a40", "#665236", "#76603f", "#6a6050"], WOOD, WOOD_D, WOOD_L),
           "rope": (["#b5a57e", "#a8986e", "#c2b28a", "#b0a080"], "#a89670", "#857554", "#c8b890"),
           "stilts": (["#5e4a32", "#56432d", "#64503a", "#5a4a36"], "#4e3e2a", "#3a2e20", "#6a563c"),
           "charred": (["#2c2521", "#241e1b", "#3a302a", "#2f2824"], "#2a2420", "#1a1512", "#4a3e36")}[style]
    planks, post_c, post_d, post_l = pal
    front_c = post_c if lit else post_d

    # supports below the deck (back row first)
    if style in ("timber", "stilts", "rope"):
        piles = [-0.42, 0.0, 0.42] if style == "stilts" else [-0.46, 0.46]
        for v in (-hw + 0.03, hw - 0.03):
            for u in piles:
                a.line([Q(u, v, -4), Q(u, v, prof(u) - 2)], INK, 4.2)
                a.line([Q(u, v, -4), Q(u, v, prof(u) - 2)], post_d if v < 0 else post_c, 2.4)
            if style == "stilts":
                a.line([Q(-0.42, v, -2), Q(0.0, v, prof(0) - 3)], INK, 2.6)
                a.line([Q(-0.42, v, -2), Q(0.0, v, prof(0) - 3)], post_d, 1.2)
    if style == "charred":
        for v in (-hw + 0.03, hw - 0.03):
            a.line([Q(0.46, v, -4), Q(0.46, v, prof(0.46) - 2)], INK, 4.2)
            a.line([Q(0.46, v, -4), Q(0.46, v, prof(0.46) - 2)], post_c, 2.4)
        a.line([Q(-0.3, hw - 0.03, -4), Q(-0.36, hw - 0.03, 3)], INK, 4.2)  # a snapped pile
        a.line([Q(-0.3, hw - 0.03, -4), Q(-0.36, hw - 0.03, 3)], post_c, 2.4)

    # stringers (seen through gaps)
    for v in (-hw + 0.05, hw - 0.05):
        pts = [Q(u, v, prof(u) - 2) for u in us]
        if style == "charred" and v > 0:
            pts = pts[:5]
        a.line(pts, INK, 3.4)
        a.line(pts, post_d, 1.8)

    # far railing
    def railing(v, near):
        if style == "charred":
            posts = [(-0.44, 12), (-0.12, 6), (0.2, 13), (0.44, 4)] if not near else [(-0.44, 5), (0.05, 11), (0.44, 8)]
        elif style == "stilts":
            posts = [(-0.44, 12), (-0.1, 11), (0.3, 12)] if not near else [(-0.44, 12), (0.1, 10)]
        else:
            posts = [(-0.44, 14), (0.0, 14), (0.44, 14)]
        tops = []
        for (u, h) in posts:
            z0, z1 = prof(u), prof(u) + h
            a.line([Q(u, v, z0), Q(u, v, z1)], INK, 3.6)
            a.line([Q(u, v, z0), Q(u, v, z1)], post_c if near else post_d, 2.0)
            if style == "charred":
                x, y = Q(u, v, z1)
                a.poly([(x - 1.6, y + 1), (x - 0.5, y - 2.5), (x + 0.4, y), (x + 1.6, y - 1.5), (x + 1.6, y + 1)], "#1a1512", stroke=None)
            tops.append((u, z1))
        if style == "rope":
            for (u0, z0), (u1, z1) in zip(tops, tops[1:]):
                for dz in (0, -6):
                    pts = [Q(u0 + (u1 - u0) * t, v, z0 + dz - 1 + (z1 - z0) * t - 3.5 * math.sin(math.pi * t)) for t in [k / 6 for k in range(7)]]
                    a.line(pts, INK, 2.0)
                    a.line(pts, "#d6c89c", 1.0)
            for (u, z) in tops:
                x, y = Q(u, v, z - 1)
                a.ellipse(x, y, 2, 1.4, "#d6c89c", INK, 0.7)
        elif style == "charred":
            if not near:
                pts = [Q(-0.44, v, prof(-0.44) + 10), Q(-0.12, v, prof(-0.12) + 5)]
                a.line(pts, INK, 3.4)
                a.line(pts, "#3a302a", 1.8)
            else:  # a rail hanging off, broken
                pts = [Q(0.05, v, prof(0.05) + 9), Q(0.36, v + 0.08, prof(0.36) - 6)]
                a.line(pts, INK, 3.4)
                a.line(pts, "#3a302a", 1.8)
        else:
            u0, u1 = tops[0][0], tops[-1][0]
            sag = 2.5 if style == "stilts" else 0
            pts = [Q(u0 + (u1 - u0) * t, v, prof(u0 + (u1 - u0) * t) + tops[0][1] - prof(u0) - 2 - sag * math.sin(math.pi * t))
                   for t in [k / 8 for k in range(9)]]
            a.line(pts, INK, 3.4)
            a.line(pts, post_l if near else post_c, 1.8)

    railing(-hw + 0.02, False)

    # planks
    n = 11
    missing = {"charred": {2, 6, 7}, "stilts": {8}}.get(style, set())
    for k in range(n):
        if k in missing:
            continue
        u0 = -0.5 + k / n + 0.006
        u1 = -0.5 + (k + 1) / n - 0.006
        dz = 0.0
        if style == "charred" and k == 9:
            dz = -3.0
        vj0, vj1 = -hw - rng.uniform(0, 0.03), hw + rng.uniform(0, 0.03)
        if style == "charred" and k in (3, 8):
            vj1 -= rng.uniform(0.08, 0.16)  # burnt off short
        col = rng.choice(planks)
        pts = [Q(u0, vj0, prof(u0) + dz), Q(u1, vj0, prof(u1) + dz), Q(u1, vj1, prof(u1) + dz), Q(u0, vj1, prof(u0) + dz)]
        a.poly(pts, col, INK, 0.9)
        # plank edge face on the near side
        a.poly([Q(u0, vj1, prof(u0) + dz), Q(u1, vj1, prof(u1) + dz), Q(u1, vj1, prof(u1) + dz - 2), Q(u0, vj1, prof(u0) + dz - 2)], front_c, INK, 0.7)
        if style == "charred" and rng.random() < 0.6:
            x, y = Q((u0 + u1) / 2, rng.uniform(-0.1, 0.1), prof(u0) + dz)
            a.line([(x - 3, y), (x + 3, y - 1)], "#5a4e44", 0.8, opacity=0.8)
        if style in ("timber", "rope") and rng.random() < 0.4:
            x, y = Q((u0 + u1) / 2, rng.uniform(-0.15, 0.15), prof(u0))
            a.line([(x - 3, y - 0.5), (x + 3, y + 0.5)], post_d, 0.6, opacity=0.6)
    if style == "stilts":
        for (u, v, rx) in [(-0.3, -0.05, 6), (0.12, 0.15, 5), (0.35, -0.12, 4)]:
            x, y = Q(u, v, prof(u))
            a.ellipse(x, y, rx, rx * 0.45, "#4f6a2c", opacity=0.85)
            a.ellipse(x - 1, y - 0.5, rx * 0.5, rx * 0.2, "#6a8a3a", opacity=0.8)
        for u in (-0.25, 0.05, 0.3):
            x, y = Q(u, hw, prof(u) - 2)
            a.line([(x, y), (x + 0.5, y + rng.uniform(4, 7))], "#4f6a2c", 1.4, opacity=0.9)
    if style == "charred":
        for _ in range(4):
            u = rng.uniform(-0.45, 0.45)
            x, y = Q(u, rng.uniform(-0.2, 0.2), prof(u))
            a.ellipse(x, y, 1.6, 0.8, "#6a655e", opacity=0.7)

    railing(hw - 0.02, True)
    a.save("bridge_%s_%s" % (style, axis))


# ----------------------------------------------------------------------- props

def reeds():
    rng = random.Random(500)
    a = Art()
    a.ellipse(0, 1, 18, 7, "#1d3030", opacity=0.45)
    stalks = sorted([(rng.uniform(-13, 13), rng.uniform(-4, 5)) for _ in range(11)], key=lambda p: p[1])
    for (x, y) in stalks:
        h = rng.uniform(26, 44)
        lean = rng.uniform(-6, 6)
        top = (x + lean, y - h)
        mid = (x + lean * 0.4, y - h * 0.5)
        a.line([(x, y), mid, top], INK, 2.8)
        a.line([(x, y), mid, top], rng.choice(["#6a7438", "#5a6a30", "#7a7a40"]), 1.4)
        if rng.random() < 0.5:  # cattail head
            hx, hy = x + lean * 0.85, y - h * 0.82
            a.ellipse(hx, hy, 2.2, 5, "#5a3a22", INK, 1.0)
        else:  # leaf blade
            a.line([(x, y - 2), (x + lean * 1.6 + rng.choice([-7, 7]), y - h * 0.6)], "#4e6030", 1.4)
    a.save("reeds")


def boulder():
    rng = random.Random(510)
    a = Art()
    a.shadow(26, 10, cy=2)
    _rock(a, rng, 0, 0, 22, 26, moss="#4d6a34")
    _rock(a, rng, 18, 5, 8, 8)
    a.ellipse(-6, -20, 7, 2.6, "#5d7c3e", opacity=0.8)
    a.save("boulder")


def cactus():
    a = Art()
    a.shadow(12, 5)
    g, gd, gl = "#5a7a3e", "#3e5a2c", "#6e9048"

    def limb(pts, w):
        a.line(pts, INK, w + 2.6)
        a.line(pts, g, w)
        a.line([(x - w * 0.25, y) for (x, y) in pts], gl, w * 0.3, opacity=0.8)
    limb([(-9, -12), (-10, -17), (-10, -24)], 5)
    limb([(8, -9), (10, -14), (10, -20)], 5)
    a.line([(-9, -12), (-2, -12)], INK, 7.6)
    a.line([(-9, -12), (-2, -12)], g, 5)
    a.line([(8, -9), (2, -9)], INK, 7.6)
    a.line([(8, -9), (2, -9)], g, 5)
    limb([(0, 0), (0, -32)], 8)
    a.line([(2.5, -2), (2.5, -31)], gd, 1.6, opacity=0.8)
    for (x, y) in [(-3, -26), (3, -18), (-3, -10), (3, -6), (-10, -20), (10, -16)]:
        a.line([(x, y), (x + (1.5 if x > 0 else -1.5), y - 1)], "#e8e0c0", 0.6)
    a.ellipse(0, -34, 2.2, 1.6, "#d86a8a", INK, 0.6)
    a.save("cactus")


def stump_charred():
    a = Art()
    a.shadow(18, 7)
    for pts in [[(-8, -2), (-16, 3)], [(7, -1), (15, 4)], [(0, 1), (2, 6)]]:  # roots
        a.line(pts, INK, 5)
        a.line(pts, "#2a2420", 3)
    a.poly([(-9, 0), (9, 0), (8, -18), (4, -24), (1, -20), (-3, -26), (-8, -19)], "#2a2420")
    a.poly([(0, 0), (9, 0), (8, -18), (4, -24), (1, -20), (0, -20)], "#1a1512", stroke=None)
    a.line([(-9, 0), (9, 0), (8, -18), (4, -24), (1, -20), (-3, -26), (-8, -19), (-9, 0)], INK, 1.3)
    for x in (-5, -1, 4):
        a.line([(x, -2), (x + 0.5, -16)], "#3e342c", 1.0)
    for (x, y) in [(-6, -10), (-2, -6), (5, -12)]:  # char scales
        a.line([(x, y), (x + 2, y), (x + 2, y + 2)], "#4a3e36", 0.8)
    a.ellipse(-2, -19, 2.5, 1.2, "#6a655e", opacity=0.7)  # ash
    a.ellipse(1, -12, 3.5, 3.5, "#e0602a", opacity=0.12)
    a.save("stump_charred")


def lava_rock():
    rng = random.Random(520)
    a = Art()
    a.shadow(22, 8, cy=2)
    pts = [(-20, 0), (-18, -10), (-12, -14), (-8, -24), (-2, -19), (3, -28), (9, -18), (15, -16), (20, -4), (18, 2), (0, 6)]
    a.poly(pts, "#221c19", INK, 1.4)
    a.poly([(-20, 0), (-18, -10), (-12, -14), (-8, -24), (-2, -19), (3, -28), (1, -8), (-2, 5), (-12, 4)], "#342c27", stroke=None)
    a.line(pts + [pts[0]], INK, 1.4)
    crack = [(-4, 3), (-2, -6), (1, -9), (0, -16), (3, -22)]
    a.line(crack, "#b8360c", 3.6, opacity=0.5)
    a.line(crack, "#f07a20", 1.4)
    a.line([(1, -9), (8, -12)], "#f07a20", 1.0)
    _glow(a, 0, -8, 12, 12, "#f07a20", 0.3)
    for _ in range(3):
        x, y = rng.uniform(-14, 14), rng.uniform(-14, -4)
        a.ellipse(x, y, 1.0, 0.7, "#4a403a")
    a.save("lava_rock")


VOLCANO_CRATER = 220


def volcano():
    rng = random.Random(530)
    a = Art()
    cz = VOLCANO_CRATER
    a.poly([P(-1.5, -1.5), P(1.5, -1.5), P(1.5, 1.5), P(-1.5, 1.5)], "#2a2622", stroke=None, opacity=0.35)
    a.ellipse(0, 20, 196, 78, "#000", opacity=0.25)
    rim_rx, rim_ry = 40, 12
    base = [(-178, 4), (-130, 46), (-68, 76), (0, 88), (68, 76), (130, 46), (178, 4)]

    def flank(side):
        pts = []
        for k in range(10):
            s = k / 9
            x = side * (178 - (178 - rim_rx) * s)
            y = 4 + (-cz - 4) * s ** 1.7
            if 0 < k < 9:
                x += rng.uniform(-4, 4)
                y += rng.uniform(-3, 3)
            pts.append((x, y))
        return pts
    lf, rf = flank(-1), flank(1)
    front_top = (-4, -cz + rim_ry)
    ridge = [(10, 88), (6, 30), (12, -40), (0, -110), (4, -170), front_top]
    # back (shadowed) silhouette behind the crater
    a.poly(lf + list(reversed(ridge)) + [(-68, 76), (-130, 46)], "#4c4742", stroke=None)
    a.poly(rf + list(reversed(ridge)) + [(68, 76), (130, 46)], "#302c29", stroke=None)
    # gullies
    for side, col in ((-1, "#3a3632"), (1, "#1e1b19")):
        for _ in range(6):
            s0 = rng.uniform(0.35, 0.9)
            x0 = side * rng.uniform(10, rim_rx + 10) * (1 - s0 * 0.2)
            y0 = -cz + 20 + (1 - s0) * 60
            pts = [(x0, y0)]
            for _ in range(3):
                x0 += side * rng.uniform(8, 22)
                y0 += rng.uniform(30, 55)
                pts.append((x0, min(y0, 70)))
            a.line(pts, col, 1.6, opacity=0.9)
    # lighter left-face highlights and strata
    for _ in range(5):
        x, y = rng.uniform(-120, -30), rng.uniform(-120, 40)
        a.line([(x, y), (x - rng.uniform(12, 24), y + rng.uniform(6, 12))], "#5c5650", 1.4, opacity=0.8)
    # lava streaks
    for pts in ([(-20, -cz + 10), (-26, -170), (-44, -120), (-40, -70), (-66, -20), (-72, 30)],
                [(18, -cz + 10), (30, -168), (26, -120), (52, -60), (60, 0)]):
        a.line(pts, "#6a1a06", 7, opacity=0.9)
        a.line(pts, "#d8501a", 3.8)
        a.line(pts, "#ffc050", 1.4)
        _glow(a, pts[-1][0], pts[-1][1] + 2, 16, 8, "#f07a20", 0.5)
        a.ellipse(pts[-1][0], pts[-1][1] + 1, 6, 2.6, "#f08a24", "#6a1a06", 1)
    # outlines
    a.line(lf, INK, 1.8)
    a.line(rf, INK, 1.8)
    a.line(base, INK, 1.3)
    a.line(ridge, "#5e5852", 1.4, opacity=0.8)
    # crater
    _glow(a, 0, -cz - 10, 90, 50, "#f07a20", 0.45)
    a.ellipse(0, -cz, rim_rx + 2, rim_ry + 2, "#3e3833", INK, 1.6)
    a.ellipse(0, -cz + 0.5, rim_rx - 8, rim_ry - 3.5, "#b8360c", "#1a1210", 1.2)
    a.ellipse(0, -cz + 1, rim_rx - 14, rim_ry - 5.5, "#f08a24")
    a.ellipse(0, -cz + 1.2, rim_rx - 24, rim_ry - 8.5, "#ffe080")
    a.line([(-rim_rx - 1, -cz + 1), (-rim_rx + 8, -cz + 7), (0, -cz + rim_ry + 1)], "#5a534c", 1.4)  # rim lip
    # boulders at the foot
    for (x, y, r) in [(-110, 60, 9), (-40, 84, 7), (90, 64, 8), (150, 30, 6)]:
        _rock(a, rng, x, y, r, r * 0.9, light="#4c4742", dark="#302c29", top="#5c5650")
    a.save("volcano", extra={"crater": cz})


def volcano_smoke():
    a = Art()
    a._track([(0, 0)])
    for (x, y, r, c, op) in [(0, -6, 12, "#6a6660", 0.7), (-9, -26, 16, "#7a7670", 0.6), (7, -50, 20, "#8a8680", 0.45)]:
        a.ellipse(x, y, r, r * 0.8, c, opacity=op)
        a.ellipse(x - r * 0.3, y - r * 0.25, r * 0.55, r * 0.4, "#a8a49e", opacity=op * 0.6)
    a.save("volcano_smoke")


# ------------------------------------------------------------------ treasures

def _bone(a, x0, y0, x1, y1, w=1.8):
    a.line([(x0, y0), (x1, y1)], INK, w + 1.6)
    a.line([(x0, y0), (x1, y1)], BONE, w)
    for (x, y) in ((x0, y0), (x1, y1)):
        a.ellipse(x, y, w * 0.8, w * 0.65, BONE, INK, 0.7)


def chest(looted=False):
    a = Art()
    a.shadow(22, 10, cy=2)
    x0, x1, y0, y1, h = -0.17, 0.17, -0.1, 0.1, 11
    if looted:  # lid thrown open, standing up at the back
        a.poly([P(x0, y0, h), P(x1, y0, h), P(x1, y0 - 0.05, h + 13), P(x0, y0 - 0.05, h + 13)], WOOD, INK, 1.2)
        for u in (-0.1, 0.1):
            a.line([P(u, y0, h), P(u, y0 - 0.05, h + 13)], "#4a4a4a", 1.6)
    a.box(x0, x1, y0, y1, 0, h, "#1a120c" if looted else WOOD_L, WOOD, WOOD_D)
    if looted:
        a.poly([P(x0 + 0.02, y0 + 0.02, h), P(x1 - 0.02, y0 + 0.02, h), P(x1 - 0.02, y0 + 0.02, h - 5), P(x0 + 0.02, y0 + 0.02, h - 5)], "#2a1c12", stroke=None)
    for u in (-0.1, 0.1):  # iron bands
        a.line([P(u, y1, 0), P(u, y1, h)], "#4a4a4a", 1.8)
    a.line([P(x1, y1 - 0.03, 0), P(x1, y1 - 0.03, h)], "#4a4a4a", 1.6)
    a.line([P(x1, y0 + 0.03, 0), P(x1, y0 + 0.03, h)], "#4a4a4a", 1.6)
    if not looted:  # rounded lid
        ym = 0.0
        a.poly([P(x0, y0, h), P(x1, y0, h), P(x1, ym, h + 7), P(x0, ym, h + 7)], "#6a4a2e", INK, 1.2)
        a.poly([P(x0, ym, h + 7), P(x1, ym, h + 7), P(x1, y1, h), P(x0, y1, h)], WOOD_L, INK, 1.2)
        a.poly([P(x1, y0, h), P(x1, ym, h + 7), P(x1, y1, h)], WOOD, INK, 1.1)
        for u in (-0.1, 0.1):
            a.line([P(u, y0, h), P(u, ym, h + 7), P(u, y1, h)], "#4a4a4a", 1.8)
        x, y = P(0, y1, h - 1)
        a.poly([(x - 2.5, y - 1), (x + 2.5, y - 1), (x + 2.5, y + 4), (x - 2.5, y + 4)], GOLD, INK, 0.8)
        a.ellipse(x, y + 1.6, 0.7, 0.9, INK)
    else:
        for (x, y) in [(16, 6), (19, 3)]:  # a couple of stray coins left behind
            a.ellipse(x, y, 2.2, 1.2, GOLD, INK, 0.6)
    return a


def ruins(looted=False):
    rng = random.Random(600)
    a = Art()
    a.poly(diamond(0.82), "#2e3a24", stroke=None, opacity=0.5)
    sl, sr, st = "#6e6a62", "#54514b", "#7e7a72"
    moss = "#4a6034"

    def wall(axis, a0, a1, c0, c1, prof):
        """Crumbling wall; axis 'x' runs along gx (c = gy range), 'y' along gy (c = gx range).
        prof: [(t, h)] along the wall, t from a0 to a1."""
        def W(t, c, z):
            return P(t, c, z) if axis == "x" else P(c, t, z)
        face_c, end_c = (sl, sr) if axis == "x" else (sr, sl)
        a.poly([W(a0, c1, 0), W(a1, c1, 0)] + [W(t, c1, h) for (t, h) in reversed(prof)], face_c, INK, 1.2)
        for (t0, h0), (t1, h1) in zip(prof, prof[1:]):
            a.poly([W(t0, c0, h0), W(t1, c0, h1), W(t1, c1, h1), W(t0, c1, h0)], st, INK, 1.0)
            for z in (9, 18, 27, 36):  # mortar courses
                if min(h0, h1) > z + 1:
                    a.line([W(t0, c1, z), W(t1, c1, z)], "#46433f", 0.8)
            x, y = W((t0 + t1) / 2, (c0 + c1) / 2, (h0 + h1) / 2)
            if rng.random() < 0.6:
                a.ellipse(x, y, 4.5, 1.8, moss, opacity=0.85)
        hend = prof[-1][1]
        a.poly([W(a1, c1, 0), W(a1, c0, 0), W(a1, c0, hend), W(a1, c1, hend)], end_c, INK, 1.1)
        return W
    Wb = wall("x", -0.4, 0.26, -0.38, -0.26, [(-0.4, 32), (-0.3, 38), (-0.2, 35), (-0.12, 22), (-0.02, 25), (0.08, 13), (0.18, 10), (0.26, 5)])
    Ws = wall("y", -0.26, 0.14, -0.4, -0.28, [(-0.26, 34), (-0.16, 28), (-0.06, 30), (0.04, 14), (0.14, 9)])
    # a window gap in the tall piece
    a.poly([P(-0.22, -0.26, 13), P(-0.15, -0.26, 13), P(-0.15, -0.26, 23), P(-0.22, -0.26, 23)], "#1a1612")
    # ivy creeping up the walls
    for (gx, zt) in [(-0.36, 26), (-0.14, 16), (0.1, 9)]:
        for _ in range(8):
            x, y = P(gx + rng.uniform(-0.05, 0.05), -0.26, rng.uniform(1, zt))
            a.ellipse(x, y, rng.uniform(1.8, 3), rng.uniform(1.3, 2.2), rng.choice(["#2e4a26", "#3a5a2c", "#25401f"]), opacity=0.95)
    for gy in (-0.1, 0.08):
        for _ in range(6):
            x, y = P(-0.28, gy + rng.uniform(-0.05, 0.05), rng.uniform(1, 14))
            a.ellipse(x, y, rng.uniform(1.8, 3), rng.uniform(1.3, 2.2), rng.choice(["#2a4424", "#223a1c"]), opacity=0.95)
    # rubble
    for (gx, gy) in [(0.2, -0.1), (0.3, 0.05), (-0.15, 0.2), (0.05, 0.1)]:
        x, y = P(gx, gy)
        _rock(a, rng, x, y, rng.uniform(3.5, 5.5), None, sl, sr, st, sw=1.0, n=5)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.7)
        _tuft(a, x, y, "#2a3e1e")
    if looted:  # dug-up soil in front
        x, y = P(0.18, 0.28)
        a.ellipse(x + 10, y - 1, 11, 5, DIRT, INK, 1.1)
        a.ellipse(x + 8, y - 3, 6, 2.5, DIRT_LIGHT, opacity=0.8)
        a.ellipse(x - 6, y + 2, 9, 4.5, "#1c140e", INK, 1.1)
        a.ellipse(x - 6, y + 1, 6, 2.4, "#0e0a07")
        for (dx, dy) in [(-16, 4), (2, 7), (20, 3)]:
            a.ellipse(x + dx, y + dy, 2, 1.2, DIRT_DARK, INK, 0.6)
    return a


def shrine(looted=False):
    rng = random.Random(610)
    a = Art()
    a.shadow(34, 16, cy=3)
    sl, sr, st = "#7a766e", "#5c5953", "#8e8a82"
    a.box(-0.28, 0.28, -0.28, 0.28, 0, 5, st, sl, sr)
    a.box(-0.22, 0.22, -0.22, 0.22, 5, 9, st, sl, sr)
    s, top = 0.16, 38
    # a niche: walls on the two back sides, open towards the viewer
    wl, wr = "#55524c", "#46433e"
    a.box(-s - 0.04, s + 0.04, -s - 0.04, -s + 0.02, 9, top, st, wl, sr, sw=1.1)
    a.box(-s - 0.04, -s + 0.02, -s + 0.02, s + 0.04, 9, top, st, sl, wr, sw=1.1)
    for z in (18, 28):
        a.line([P(-s + 0.02, -s + 0.02, z), P(s + 0.04, -s + 0.02, z)], "#3e3b37", 0.9)
        a.line([P(-s + 0.02, -s + 0.02, z), P(-s + 0.02, s + 0.04, z)], "#3a3733", 0.9)
    if looted:
        a.poly([P(s + 0.04, -s + 0.02, top), P(s - 0.06, -s + 0.02, top), P(s - 0.02, -s + 0.02, top - 9), P(s + 0.04, -s + 0.02, top - 13)], "#2a2622", stroke=None)
    if not looted:  # golden idol on a small plinth
        a.box(-0.06, 0.06, -0.06, 0.06, 9, 13, st, sl, sr, sw=0.9)
        x, y = P(0, 0, 13)
        _glow(a, x, y - 10, 22, 18, "#f0d070", 0.55)
        a.raw('<path d="M%s,%s q-5,-6 -2.5,-11 q2.5,-3 0,-5 q2.5,-3.5 5,0 q-2.5,2 0,5 q2.5,5 -2.5,11 Z" fill="%s" stroke="%s" stroke-width="1.1"/>'
              % (fmt(x), fmt(y), GOLD, INK), [(x - 6, y - 20), (x + 4, y)])
        a.ellipse(x, y - 19, 3, 3, GOLD, INK, 1.0)
        a.line([(x - 1.5, y - 14), (x - 1.5, y - 6)], "#f0d890", 1.0)
        a.ellipse(x - 1, y - 20, 1.1, 0.9, "#f8e8a8")
    else:
        a.box(-0.06, 0.06, -0.06, 0.06, 9, 14, "#5c5953", sl, sr, sw=0.9)
        a.line([P(-0.06, 0.06, 14), P(0.0, 0.06, 11), P(0.03, 0.06, 9)], "#1e1b18", 1.0)
    # roof: slab + pyramid
    r = 0.22
    a.box(-r, r, -r, r, top, top + 4, st, sl, sr)
    apex = P(0, 0, top + 22)
    a.poly([P(-r, r, top + 4), P(r, r, top + 4), apex], "#6a665e")
    a.poly([P(r, r, top + 4), P(r, -r, top + 4), apex], "#4e4b46")
    if looted:  # cracks, chipped roof corner
        a.poly([P(r, -r, top + 4), P(r, -r + 0.12, top + 4), P(r - 0.05, -r + 0.04, top + 9)], "#2a2622", stroke=None)
        for pts in ([P(-0.18, 0.28, 5), P(-0.12, 0.28, 2), P(-0.06, 0.28, 3.5)],
                    [P(-0.1, r, top + 4), P(-0.05, r, top + 1)],
                    [P(0.28, 0.1, 5), P(0.28, 0.02, 2), P(0.28, -0.05, 0)],
                    [apex, (apex[0] - 3, apex[1] + 8), (apex[0] - 1, apex[1] + 14)]):
            a.line(pts, "#1e1b18", 1.1)
        for (gx, gy) in [(0.34, -0.1), (0.3, 0.3)]:
            x, y = P(gx, gy)
            _rock(a, rng, x, y, 3.5, None, sl, sr, st, sw=0.9, n=5)
    else:
        for (gx, gy) in [(0.2, 0.02), (0.02, 0.2)]:  # offering candles
            x, y = P(gx, gy, 9)
            a.poly([(x - 1.3, y), (x + 1.3, y), (x + 1.3, y - 5), (x - 1.3, y - 5)], "#e8dcc0", INK, 0.6)
            a.ellipse(x, y - 7, 1.1, 1.8, GLOW)
    return a


def standing_stones(looted=False):
    rng = random.Random(620)
    a = Art()
    a.ellipse(0, 2, 44, 20, "#000", opacity=0.22)
    rune = "#2e2c28" if looted else "#9ad0c8"
    stones = sorted([(-0.25, -0.25, 58), (-0.1, 0.3, 46), (0.3, -0.05, 50)], key=lambda s: s[0] + s[1])
    for (gx, gy, h) in stones:
        x, y = P(gx, gy)
        w = rng.uniform(8, 10)
        lean = rng.uniform(-3, 3)
        pts = [(x - w, y), (x - w * 0.8 + lean, y - h * 0.85), (x - w * 0.2 + lean, y - h), (x + w * 0.6 + lean, y - h * 0.92), (x + w, y - 2), (x + w * 0.2, y + 3)]
        a.poly(pts, "#5a5751")
        a.poly([pts[0], pts[1], pts[2], (x - w * 0.1 + lean * 0.6, y - h * 0.5), (x - w * 0.1, y + 2.5)], "#7a766e", stroke=None)
        a.line(pts + [pts[0]], INK, 1.4)
        a.ellipse(x - w * 0.3 + lean, y - h * 0.92, w * 0.5, 2.2, "#4d6a34", opacity=0.8)  # moss cap
        a.ellipse(x, y, w * 1.1, 2.5, "#3a5028", opacity=0.8)
        # runes on the lit face
        gx0 = x - w * 0.55 + lean * 0.5
        for k, g in enumerate([[(0, 0), (0, 8), (3, 4)], [(0, 0), (3, 3), (0, 6), (3, 9)], [(1.5, 0), (1.5, 8), (0, 3), (3, 3)]]):
            yb = y - h * 0.3 - k * 11
            pts2 = [(gx0 + u, yb - v) for (u, v) in g]
            if not looted:
                a.line(pts2, rune, 4.5, opacity=0.25)
            a.line(pts2, rune, 1.2, opacity=0.9)
    return a


def shipwreck(looted=False):
    rng = random.Random(630)
    a = Art()
    a.poly(diamond(0.98), "#bba671", stroke=None, opacity=0.4)
    a.poly(diamond(0.84), "#bba671", stroke=None, opacity=0.85)
    for _ in range(3):
        x, y = rand_in_diamond(rng, 0.6)
        _arc(a, x, y, rng.uniform(14, 22), 5, "#a38f5e", 1.4, 0.7)
    hull_o, hull_i = "#6e5438", "#4a3624"
    # inside of the hull (tilted, far gunwale high)
    far = [P(0.36, -0.06, 5), P(0.2, -0.14, 15), P(-0.1, -0.16, 17), P(-0.34, -0.1, 14)]
    near = [P(-0.34, 0.1, 8), P(-0.1, 0.14, 9), P(0.2, 0.12, 8), P(0.36, -0.06, 5)]
    a.poly(far + near, hull_i, INK, 1.2)
    for gx in (-0.22, -0.05, 0.12):  # ribs
        a.line([P(gx, -0.15, 16), P(gx, 0, 2), P(gx, 0.13, 9)], "#6a543a", 1.8)
    a.line([P(-0.12, -0.15, 12), P(-0.12, 0.13, 7)], WOOD, 2.6)  # thwart
    # transom (stern end)
    a.poly([P(-0.34, -0.1, 14), P(-0.34, 0.1, 8), P(-0.36, 0.08, 0), P(-0.36, -0.06, 2)], "#4a3824", INK, 1.2)
    # outer near hull side
    outer = near + [P(0.3, -0.02, 0), P(0.1, 0.08, -1), P(-0.2, 0.08, -1), P(-0.36, 0.08, 0)]
    a.poly(outer, hull_o, INK, 1.3)
    for dz in (3, 6):
        a.line([P(-0.34, 0.1, dz), P(-0.1, 0.13, dz + 1), P(0.2, 0.1, dz), P(0.33, -0.03, dz * 0.7)], "#3e2e1e", 0.9)
    # broken hole with a snapped plank
    x, y = P(0.02, 0.12, 5)
    a.poly([(x - 8, y - 3), (x - 2, y - 7), (x + 6, y - 4), (x + 4, y + 2), (x - 5, y + 3)], "#140e09", INK, 1.0)
    a.line([(x + 5, y - 4), (x + 13, y - 11)], INK, 3.2)
    a.line([(x + 5, y - 4), (x + 13, y - 11)], hull_o, 1.8)
    # oar in the sand
    x, y = P(-0.2, 0.34)
    a.line([(x - 18, y + 2), (x + 10, y - 4)], INK, 2.6)
    a.line([(x - 18, y + 2), (x + 10, y - 4)], "#8a7250", 1.4)
    a.poly([(x + 8, y - 5.5), (x + 18, y - 7), (x + 18, y - 3), (x + 9, y - 2.5)], "#8a7250", INK, 1)
    if not looted:
        a.box(0.22, 0.36, 0.2, 0.34, 0, 12, "#9a7a4e", "#7a5e3a", "#5e472c", sw=1.2)
        for (p0, p1) in [(P(0.22, 0.34, 0), P(0.36, 0.34, 12)), (P(0.36, 0.34, 0), P(0.22, 0.34, 12)),
                         (P(0.36, 0.34, 0), P(0.36, 0.2, 12)), (P(0.36, 0.2, 0), P(0.36, 0.34, 12))]:
            a.line([p0, p1], "#4a3824", 1.0)
        x, y = P(0.29, 0.27, 12)
        a.ellipse(x, y, 2.6, 1.3, GOLD, INK, 0.6)
    else:  # empty spot, footprints
        for k in range(4):
            x, y = P(0.18 + k * 0.05, 0.3 - k * 0.02)
            a.ellipse(x, y, 1.6, 0.9, "#8e7e56", opacity=0.8)
    return a


def dragon_bones(looted=False):
    rng = random.Random(640)
    a = Art()
    a.poly(diamond(0.9), "#2e2a20", stroke=None, opacity=0.35)
    ribs = [0.05, 0.16, 0.27, 0.38, 0.48]
    if looted:
        ribs = [0.05, 0.27, 0.48]

    def rib(gx, side, broken=False):
        pts = []
        for k in range(7):
            t = k / 6
            if broken and t > 0.6:
                break
            pts.append(P(gx + 0.05 * t, side * 0.3 * math.sin(t * math.pi / 2) ** 0.8, 30 * math.cos(t * math.pi / 2) + 2))
        a.line(pts, INK, 4.4)
        a.line(pts, BONE, 2.6)
        a.line(pts, BONE_D, 0.8, opacity=0.6)
    for gx in ribs:
        rib(gx, -1, broken=(gx == 0.27))
    if looted:  # dug pit among the bones
        x, y = P(0.25, 0.05)
        a.ellipse(x + 12, y + 2, 12, 5, DIRT, INK, 1.0)
        a.ellipse(x, y, 13, 6, "#1c140e", INK, 1.1)
        a.ellipse(x, y - 1, 9, 3.5, "#0c0806")
    spine = [P(-0.08, 0, 26), P(0.1, 0, 32), P(0.3, 0, 31), P(0.5, 0, 26), P(0.62, 0, 14)]
    a.line(spine, INK, 5)
    a.line(spine, BONE, 3.2)
    for p in spine[1:4]:
        a.ellipse(p[0], p[1] - 1, 2.4, 3, BONE, INK, 0.8)
    for gx in ribs:
        rib(gx, 1, broken=(gx == 0.38))
    # skull lying at the front-left
    sx, sy = P(-0.28, 0.12)
    a.raw('<path d="M%s,%s q-4,-12 8,-18 q14,-5 22,2 q5,5 2,12 l-6,2 l-10,4 l-10,2 Z" fill="%s" stroke="%s" stroke-width="1.4" stroke-linejoin="round"/>'
          % (fmt(sx - 20), fmt(sy), BONE, INK), [(sx - 24, sy - 24), (sx + 14, sy + 2)])
    a.raw('<path d="M%s,%s q-6,6 -18,4 l2,-4 l3,1 l1,-3 l3,1 l1,-3 l3,1 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>'
          % (fmt(sx - 2), fmt(sy - 2), BONE_D, INK), [(sx - 22, sy - 6), (sx, sy + 3)])  # jaw
    a.ellipse(sx - 4, sy - 12, 3.6, 2.8, "#1a1612")  # eye socket
    a.ellipse(sx - 15, sy - 6, 1.4, 1, "#1a1612")  # nostril
    for pts in ([(sx + 2, sy - 18), (sx + 10, sy - 30), (sx + 22, sy - 34)], [(sx + 7, sy - 14), (sx + 18, sy - 22), (sx + 28, sy - 22)]):
        a.line(pts, INK, 4.4)
        a.line(pts, BONE_D, 2.6)
    if not looted:
        for _ in range(3):
            x, y = rand_in_diamond(rng, 0.6)
            _bone(a, x - 5, y, x + 5, y - 2)
    else:
        x, y = P(0.1, 0.35)
        _bone(a, x - 5, y, x + 5, y - 2)
    return a


# --------------------------------------------------------------- camp / sites

def camp(cleared=False):
    rng = random.Random(650)
    a = Art()
    a.poly(diamond(0.86), "#4a3a28", stroke=None, opacity=0.55)
    hide, hide_d, patch = "#6a5a44", "#4e4232", "#7e6a4c"
    x0, x1, y0, y1, ridge = -0.38, 0.12, -0.36, 0.06, 38
    ym = (y0 + y1) / 2
    if not cleared:
        a.poly([P(x0, y0, 0), P(x1, y0, 0), P(x1, ym, ridge), P(x0, ym, ridge)], hide_d)
        a.poly([P(x1, y0, 0), P(x1, ym, ridge), P(x1, y1, 0)], "#5a4c38")
        a.poly([P(x1, ym - 0.08, 0), P(x1, ym, ridge * 0.7), P(x1, ym + 0.08, 0)], "#140e0a", stroke=None)  # dark opening
        a.poly([P(x0, ym, ridge), P(x1, ym, ridge), P(x1, y1, 0), P(x0 + 0.04, y1 + 0.02, 2), P(x0, y1, 0)], hide)
        for (gx, gz, w) in [(-0.25, 20, 0.08), (0.0, 10, 0.07)]:  # patches
            a.poly([P(gx, ym + 0.08, gz + 8), P(gx + w, ym + 0.08, gz + 8), P(gx + w, ym + 0.13, gz), P(gx, ym + 0.13, gz)], patch, INK, 0.8)
        # ragged hem
        for k in range(6):
            gx = x0 + (x1 - x0) * (k + 0.5) / 6
            p = P(gx, y1, 0)
            a.poly([(p[0] - 3, p[1] - 3), (p[0] + 3, p[1] - 3), (p[0], p[1] + 2)], hide, INK, 0.7)
        for gx in (x0 - 0.05, x1 + 0.05):  # crossed poles
            b = P(gx, ym, ridge)
            a.line([(b[0] - 5, b[1] - 8), (b[0] + 3, b[1] + 4)], WOOD_D, 2.2)
            a.line([(b[0] + 5, b[1] - 8), (b[0] - 3, b[1] + 4)], WOOD_D, 2.2)
        a.line([P(x0, ym, ridge), P(x1, ym, ridge)], "#3a3024", 2)
        # skull on a stake by the tent
        x, y = P(0.2, -0.3)
        a.line([(x, y), (x, y - 26)], WOOD_D, 2.2)
        a.ellipse(x, y - 28, 4, 3.6, BONE, INK, 1)
        a.ellipse(x - 1.3, y - 28.5, 0.9, 1, INK)
        a.ellipse(x + 1.5, y - 28.5, 0.9, 1, INK)
    else:  # collapsed tent
        a.poly([P(x0, y0 + 0.02, 0), P(x1 - 0.05, y0, 0), P(x1, ym, 9), P(x1 + 0.02, y1 + 0.04, 0), P(x0 + 0.05, y1 + 0.02, 0), P(x0 - 0.02, ym, 6)], hide_d)
        a.poly([P(x0 - 0.02, ym, 6), P(-0.1, ym + 0.02, 12), P(x1, ym, 9), P(x1 + 0.02, y1 + 0.04, 0), P(x0 + 0.05, y1 + 0.02, 0)], hide)
        a.poly([P(-0.2, ym + 0.02, 10), P(-0.12, ym + 0.02, 10), P(-0.12, ym + 0.08, 5), P(-0.2, ym + 0.08, 5)], patch, INK, 0.7)
        a.line([P(x0 - 0.1, ym - 0.05, 0), P(x0 + 0.1, ym + 0.02, 14)], WOOD_D, 2.2)  # broken poles poking out
        a.line([P(x1 + 0.12, ym + 0.1, 0), P(x1 - 0.02, ym, 10)], WOOD_D, 2.2)
        x, y = P(0.2, -0.3)
        a.line([(x, y), (x, y - 10)], WOOD_D, 2.2)
        a.line([(x, y - 10), (x + 2, y - 13)], WOOD_D, 1.4)
    # banner
    bx, by = P(-0.32, 0.26)
    if not cleared:
        a.line([(bx, by), (bx, by - 54)], INK, 3.4)
        a.line([(bx, by), (bx, by - 54)], WOOD, 1.8)
        a.line([(bx - 6, by - 50), (bx + 20, by - 52)], WOOD_D, 2)
        a.poly([(bx + 1, by - 51), (bx + 19, by - 52), (bx + 17, by - 34), (bx + 14, by - 38), (bx + 11, by - 30), (bx + 7, by - 36), (bx + 2, by - 32)], "#6a1e18", INK, 1.1)
        a.ellipse(bx + 10, by - 44, 3, 2.8, "#d8d0bc", opacity=0.85)  # daubed skull
        a.line([(bx + 7, by - 39), (bx + 13, by - 39)], "#d8d0bc", 1.2, opacity=0.85)
    else:  # fallen banner
        a.line([(bx - 10, by + 4), (bx + 36, by - 10)], INK, 3.4)
        a.line([(bx - 10, by + 4), (bx + 36, by - 10)], WOOD, 1.8)
        a.poly([(bx + 26, by - 8), (bx + 38, by - 12), (bx + 42, by - 2), (bx + 30, by + 1)], "#4a1a14", INK, 0.9)
    # campfire
    fx, fy = P(0.28, 0.2)
    for k in range(7):
        ang = k * math.pi * 2 / 7
        a.ellipse(fx + math.cos(ang) * 9, fy + math.sin(ang) * 4.5, 2.6, 1.8, "#6b665e", INK, 0.8)
    a.ellipse(fx, fy, 6.5, 3, "#1e1a16")
    if not cleared:
        _glow(a, fx, fy - 6, 34, 20, GLOW, 0.4)
        a.line([(fx - 6, fy + 1), (fx + 5, fy - 2)], INK, 3.2)
        a.line([(fx - 6, fy + 1), (fx + 5, fy - 2)], WOOD, 1.8)
        a.line([(fx - 5, fy - 2), (fx + 6, fy + 1)], INK, 3.2)
        a.line([(fx - 5, fy - 2), (fx + 6, fy + 1)], WOOD_L, 1.8)
        a.poly([(fx - 5, fy - 1), (fx - 2, fy - 12), (fx, fy - 6), (fx + 2, fy - 16), (fx + 5, fy - 1)], "#e0702a", "#8a2a10", 1.0)
        a.poly([(fx - 2.5, fy - 1), (fx, fy - 9), (fx + 2.5, fy - 1)], "#ffd060", stroke=None)
        a.ellipse(fx - 2, fy - 26, 5, 4, "#6a6660", opacity=0.35)
        _bone(a, fx + 12, fy + 8, fx + 20, fy + 5, 1.4)
    else:
        a.ellipse(fx, fy - 0.5, 5, 2, "#4a4744")
        a.line([(fx - 5, fy), (fx + 4, fy - 1.5)], "#2a2420", 2)
        a.line([(fx - 3, fy - 2), (fx + 5, fy + 1)], "#3a3430", 1.6)
    for _ in range(3):
        x, y = rand_in_diamond(rng, 0.6)
        if cleared:
            _bone(a, x - 4, y, x + 4, y - 1.5, 1.3)
    return a


def stone_circle(awake=False):
    rng = random.Random(660)
    a = Art()
    a.ellipse(0, 0, 58, 29, "#2e3a24", opacity=0.45)
    a.ellipse(0, 0, 40, 20, "#3a4a2c", "#2a3620", 1.0, opacity=0.6)
    n = 7
    stones = []
    for k in range(n):
        ang = k * 2 * math.pi / n + 0.3
        gx, gy = math.cos(ang) * 0.42, math.sin(ang) * 0.42
        stones.append((gx, gy, rng.uniform(18, 27), rng.uniform(5.5, 7.5), rng.uniform(-2, 2)))
    stones.sort(key=lambda s: s[0] + s[1])
    rune = "#bfe6ff"

    def draw(gx, gy, h, w, lean):
        x, y = P(gx, gy)
        pts = [(x - w, y), (x - w * 0.8 + lean, y - h * 0.85), (x + lean, y - h), (x + w * 0.8 + lean, y - h * 0.8), (x + w, y), (x, y + 2)]
        a.poly(pts, "#56534d")
        a.poly([pts[0], pts[1], pts[2], (x + lean * 0.5, y - h * 0.4), (x, y + 2)], "#77736c", stroke=None)
        a.line(pts + [pts[0]], INK, 1.3)
        a.ellipse(x - w * 0.2 + lean, y - h * 0.9, w * 0.7, 2, "#4d6a34", opacity=0.85)
        a.ellipse(x, y, w * 1.2, 2.2, "#3a5028", opacity=0.8)
        g = [(x - w * 0.45 + lean * 0.5, y - h * 0.3), (x - w * 0.45 + lean * 0.6, y - h * 0.62), (x - w * 0.1 + lean * 0.6, y - h * 0.5)]
        if awake:
            a.line(g, rune, 4.5, opacity=0.35)
            a.line(g, rune, 1.3)
        else:
            a.line(g, "#4a4842", 1.1)
    back = [s for s in stones if s[0] + s[1] < 0]
    front = [s for s in stones if s[0] + s[1] >= 0]
    for s in back:
        draw(*s)
    # flat altar stone in the middle
    a.poly([(-12, -1), (0, -7), (12, -1), (0, 5)], "#7e7a72", INK, 1.2)
    a.poly([(-12, -1), (0, 5), (12, -1), (12, 2), (0, 8), (-12, 2)], "#56534d", INK, 1.0)
    if awake:
        _glow(a, 0, -4, 54, 28, "#a8d8ff", 0.45)
        _glow(a, 0, -30, 14, 36, "#cfeaff", 0.35)
        for (x, y) in [(-8, -20), (6, -32), (1, -44)]:
            a.ellipse(x, y, 1.3, 1.3, "#e8f6ff", opacity=0.9)
    for s in front:
        draw(*s)
    return a


def mage_tower(awake=False):
    rng = random.Random(670)
    a = Art()
    a.shadow(40, 18, cy=3)
    sl, sr, st = "#6e6a62", "#4e4b46", "#7e7a72"

    def cyl(r, y_bot, top_fn, n=12, light=sl, dark=sr):
        ry = r * 0.5
        bot = [(r * math.cos(t), y_bot + ry * math.sin(t)) for t in [k * math.pi / n for k in range(n + 1)]]  # right -> left
        topl = [(x, top_fn(x)) for x in [-r + 2 * r * k / n for k in range(n + 1)]]  # left -> right
        a.poly(bot + topl, dark, INK, 1.3)
        a.poly([p for p in topl if p[0] <= 1e-6] + [p for p in bot if p[0] <= 1e-6], light, stroke=None)
        a.line(bot + topl + [bot[0]], INK, 1.3)
    # base plinth
    cyl(26, 0, lambda x: -10 - 13 * math.sqrt(max(0.0, 1 - (x / 26) ** 2)))
    a.ellipse(0, -10, 26, 13, st, INK, 1.2)
    # tower body with a broken, jagged top
    r = 16
    jag = {}
    for k in range(13):
        x = -r + 2 * r * k / 12
        base_top = -150 + (x + r) * 0.9  # higher on the left, crumbling to the right
        jag[k] = base_top + rng.uniform(-6, 6) + (18 if 7 <= k <= 9 else 0)

    def top_fn(x):
        k = round((x + r) / (2 * r) * 12)
        return jag[max(0, min(12, k))]
    cyl(r, -10, top_fn)
    # stone courses
    for yy in range(-24, -140, -13):
        pts = [(r * math.cos(t), yy + r * 0.5 * math.sin(t)) for t in [k * math.pi / 10 for k in range(11)]]
        pts = [p for p in pts if p[1] > top_fn(p[0]) + 3]
        if len(pts) > 1:
            a.line(pts, "#3e3b37", 0.9, opacity=0.8)
    # inner wall visible at the broken top
    a.poly([(-8, top_fn(-8) + 3), (4, top_fn(4) + 4), (4, top_fn(4) + 12), (-8, top_fn(-8) + 10)], "#2a2622", stroke=None, opacity=0.9)
    # door and window
    a.raw('<path d="M-9,-8 L-9,-24 Q-5,-31 -1,-24 L-1,-6 Z" fill="#141110" stroke="%s" stroke-width="1.2"/>' % INK, [(-10, -31), (0, -6)])
    wy = -100
    if awake:
        _glow(a, -5, wy - 6, 26, 26, "#b070ff", 0.55)
    a.raw('<path d="M-9,%s L-9,%s Q-5,%s -1,%s L-1,%s Z" fill="%s" stroke="%s" stroke-width="1.2"/>'
          % (fmt(wy), fmt(wy - 11), fmt(wy - 17), fmt(wy - 11), fmt(wy + 1), "#d8a8ff" if awake else "#141110", INK), [(-10, wy - 17), (0, wy + 1)])
    if awake:
        a.line([(-5, wy - 14), (-5, wy)], "#8a4ad8", 1.0)
    a.raw('<path d="M5,-62 L5,-70 Q8,-74 11,-70 L11,-60 Z" fill="%s" stroke="%s" stroke-width="1"/>' % ("#b070ff" if awake else "#141110", INK), [(4, -74), (12, -60)])
    # ivy
    for _ in range(26):
        x = rng.uniform(-r, -2) if rng.random() < 0.7 else rng.uniform(-2, r)
        y = rng.uniform(-80, -12) if rng.random() < 0.7 else rng.uniform(-130, -80)
        if y < top_fn(x) + 4:
            continue
        a.ellipse(x, y, rng.uniform(2, 3.5), rng.uniform(1.4, 2.4), rng.choice(["#2e4a26", "#3a5a2c", "#28401f"]), opacity=0.95)
    a.line([(-12, -12), (-13, -40), (-10, -66), (-12, -90)], "#2a3a1e", 1.2)
    # rubble at the foot
    for (x, y, rr) in [(24, 4, 5), (30, -6, 4), (-28, 6, 4.5)]:
        _rock(a, rng, x, y, rr, None, sl, sr, st, sw=1.0, n=5)
    if awake:
        for (x, y) in [(-22, -150), (14, -168), (26, -132), (-4, -176), (-28, -118)]:
            a.ellipse(x, y, 4, 4, "#b070ff", opacity=0.3)
            a.ellipse(x, y, 1.4, 1.4, "#f0e0ff")
    return a


def watchtower_ruin():
    rng = random.Random(680)
    a = Art()
    s, base_h, post_h, plat = 0.3, 16, 60, 0.38
    a.shadow(46, 23, cy=4)
    a.box(-s, s, -s, s, 0, base_h, STONE_T, STONE_L, STONE_R)
    a.poly([P(s, 0.1, base_h), P(s, -0.05, base_h), P(s, -0.02, base_h - 6), P(s, 0.06, base_h - 8)], "#2a2622", stroke=None)  # chipped
    for (gx, gy) in [(-0.1, 0.0), (0.12, -0.15), (-0.2, -0.2)]:
        x, y = P(gx, gy, base_h)
        a.ellipse(x, y, 8, 3, "#4a6034", opacity=0.85)
    for (gx, z) in [(-0.2, 4), (0.05, 9)]:
        x, y = P(gx, s, z)
        a.ellipse(x, y, 5, 2.5, "#4a6034", opacity=0.8)
    k = 0.06
    posts = [(-s + 0.02, -s + 0.02, post_h), (s - 0.08, -s + 0.02, 42), (-s + 0.02, s - 0.08, post_h), (s - 0.08, s - 0.08, 30)]
    for (gx, gy, h) in posts:
        a.box(gx, gx + k, gy, gy + k, base_h, h, "#6a6050", "#5a4a38", "#3e3226", sw=1.1)
        if h < post_h:  # splintered top
            x, y = P(gx + k / 2, gy + k / 2, h)
            a.poly([(x - 3.5, y + 1), (x - 2, y - 5), (x, y - 1), (x + 1.5, y - 6), (x + 3.5, y + 1)], "#6a6050", INK, 0.8)
    a.line([P(-s, s - 0.05, base_h + 4), P(0.05, s - 0.05, base_h + 24)], "#3e3226", 2.4)  # broken brace
    # half the platform is left, sagging to the right
    a.box(-plat, 0.02, -plat, plat, post_h, post_h + 6, "#7a6a52", "#5a4a38", "#3e3226")
    for (gy, l) in [(-0.3, 0.14), (-0.1, 0.06), (0.12, 0.18), (0.3, 0.1)]:  # plank stubs
        a.poly([P(0.02, gy - 0.06, post_h + 6), P(0.02 + l, gy - 0.06, post_h + 4), P(0.02 + l, gy + 0.06, post_h + 4), P(0.02, gy + 0.06, post_h + 6)], "#6a5a44", INK, 0.9)
    for (gx, gy) in [(-0.2, -0.05), (-0.1, 0.2)]:  # holes
        a.poly([P(gx, gy, post_h + 6), P(gx + 0.1, gy, post_h + 6), P(gx + 0.1, gy + 0.08, post_h + 6), P(gx, gy + 0.08, post_h + 6)], "#1a1410", stroke=None)
    for t in (-0.2, 0.0, 0.2):
        a.line([P(-plat, t, post_h + 6), P(0.02, t, post_h + 6)], "#43301e", 1)
    # one remaining railing post and a dangling plank
    a.box(-plat, -plat + 0.05, -plat, -plat + 0.05, post_h + 6, post_h + 20, "#6a6050", "#5a4a38", "#3e3226", sw=1)
    a.line([P(-plat, -plat, post_h + 18), P(-plat + 0.25, -plat, post_h + 12)], "#3e3226", 2.4)
    a.line([P(-plat, plat, post_h + 4), P(-plat + 0.1, plat + 0.05, post_h - 22)], INK, 4.2)
    a.line([P(-plat, plat, post_h + 4), P(-plat + 0.1, plat + 0.05, post_h - 22)], "#6a5a44", 2.6)
    # fallen planks and moss on the ground
    for (gx, gy, ang) in [(0.42, 0.1, 0.4), (0.2, 0.42, -0.3)]:
        x, y = P(gx, gy)
        dx, dy = 12 * math.cos(ang), 6 * math.sin(ang)
        a.line([(x - dx, y - dy), (x + dx, y + dy)], INK, 4.2)
        a.line([(x - dx, y - dy), (x + dx, y + dy)], "#6a5a44", 2.6)
    for _ in range(4):
        x, y = rand_in_diamond(rng, 0.9)
        _tuft(a, x, y, "#2a3e1e")
    a.save("watchtower_ruin")


def mine():
    rng = random.Random(690)
    a = Art()
    left, front, right, apex = (-68, 4), (0, 34), (68, 4), (8, -76)
    a.poly([left, front, right, (46, -22), apex, (-40, -30)], "#3e3b36", stroke=None, opacity=0.5)
    a.poly([left, front, apex], "#77726a")
    a.poly([front, right, apex], "#57534c")
    a.poly([left, (-30, 12), (-46, -24)], "#6d685f")
    a.poly([(28, -30), (52, 8), (64, 4)], "#4e4a44", stroke=None)  # shoulder on the shadow side
    for _ in range(4):
        t = rng.uniform(0.3, 0.8)
        x0, y0 = left[0] + (apex[0] - left[0]) * t, left[1] + (apex[1] - left[1]) * t
        a.line([(x0, y0), (x0 + rng.uniform(12, 22), y0 + rng.uniform(3, 8))], "#5f5a52", 1.3)
    for (x, y) in [(-44, -8), (-6, -46), (30, -20)]:
        a.ellipse(x, y, 7, 2.6, "#4d6a34", opacity=0.7)
    for _ in range(3):
        t = rng.uniform(0.3, 0.7)
        x0, y0 = front[0] + (apex[0] - front[0]) * t, front[1] + (apex[1] - front[1]) * t
        a.line([(x0, y0), (x0 + rng.uniform(10, 22), y0 + rng.uniform(4, 9))], "#403d38", 1.4)
    a.line([left, apex, right], INK, 1.6)
    a.line([left, front, right], INK, 1.2)
    # the mouth on the left face, framed by timber
    mx, my = -24, 18
    a.poly([(mx - 13, my), (mx - 13, my - 22), (mx - 6, my - 28), (mx + 6, my - 28), (mx + 13, my - 22), (mx + 13, my + 4)], "#0d0a08", INK, 1.2)
    _glow(a, mx + 2, my - 8, 8, 8, GLOW, 0.2)
    for x in (mx - 13, mx + 13):
        a.line([(x, my + (4 if x > mx else 0)), (x, my - 26)], INK, 4.6)
        a.line([(x, my + (4 if x > mx else 0)), (x, my - 26)], WOOD, 2.8)
    a.line([(mx - 17, my - 26), (mx + 17, my - 27)], INK, 5)
    a.line([(mx - 17, my - 26), (mx + 17, my - 27)], WOOD_L, 3)
    # rails running out towards the viewer
    for off in (-5, 5):
        a.line([(mx + off, my), (mx + off + 14, my + 12)], "#6a6a6a", 1.4)
    for k in range(4):
        x, y = mx + 3.5 * k, my + 3 * k + 1
        a.line([(x - 7, y), (x + 7, y)], WOOD_D, 1.8)
    # mine cart with ore
    cx, cy = mx + 12, my + 8
    a.poly([(cx - 9, cy - 10), (cx + 9, cy - 10), (cx + 7, cy - 2), (cx - 7, cy - 2)], "#5a5048", INK, 1.2)
    a.poly([(cx, cy - 10), (cx + 9, cy - 10), (cx + 7, cy - 2), (cx, cy - 2)], "#443c36", stroke=None)
    a.line([(cx - 9, cy - 10), (cx + 9, cy - 10), (cx + 7, cy - 2), (cx - 7, cy - 2), (cx - 9, cy - 10)], INK, 1.2)
    for (x, y, c) in [(cx - 4, cy - 12, "#6a6660"), (cx + 2, cy - 13, "#8a8478"), (cx + 5, cy - 11, "#b89a4a")]:
        a.ellipse(x, y, 3, 2.2, c, INK, 0.7)
    for x in (cx - 5, cx + 5):
        a.ellipse(x, cy - 1, 2, 2, "#2a2622", INK, 0.8)
    # lantern hanging from the lintel
    lx, ly = mx + 16, my - 20
    a.line([(lx, my - 27), (lx, ly - 3)], INK, 0.9)
    _glow(a, lx, ly, 14, 14, GLOW, 0.5)
    a.poly([(lx - 2.5, ly - 3), (lx + 2.5, ly - 3), (lx + 2.5, ly + 3), (lx - 2.5, ly + 3)], GLOW, INK, 0.9)
    a.save("mine")


# ---------------------------------------------------------------- monster lairs

def lair_cave(big=False):
    rng = random.Random(700 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()

    def S(x, y):
        return (x * k, y * k)
    a.ellipse(0, 6 * k, 64 * k, 26 * k, "#000", opacity=0.25)
    left, front, right = S(-62, 6), S(4, 32), S(62, 4)
    ridge = [S(-44, -28), S(-22, -50), S(6, -58), S(30, -44), S(46, -24)]
    a.poly([left] + ridge + [right, front], "#57534c")
    a.poly([left] + ridge[:3] + [S(10, -20), front], "#77726a", stroke=None)
    a.poly([ridge[2], ridge[3], S(20, -30), S(10, -20)], "#8b877f", stroke=None, opacity=0.6)
    a.line([left] + ridge + [right], INK, 1.6)
    a.line([left, front, right], INK, 1.2)
    for _ in range(int(3 * k)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(-30, 0) * k
        a.line([(x, y), (x + rng.uniform(-14, 14) * k, y + rng.uniform(5, 10) * k)], "#403d38", 1.4)
    for _ in range(int(4 * k)):
        x, y = rng.uniform(-40, 10) * k, rng.uniform(-40, -8) * k
        a.ellipse(x, y, rng.uniform(3, 6) * k, rng.uniform(1.5, 2.5) * k, "#4a6034", opacity=0.7)
    # the mouth
    mx, my, mw, mh = -8 * k, 16 * k, 24 * k, 36 * k
    mouth = [(mx - mw, my)] + [(mx - mw * math.cos(t), my - mh * math.sin(t) * (0.9 + 0.1 * math.sin(3 * t))) for t in [j * math.pi / 10 for j in range(1, 10)]] + [(mx + mw, my + 3 * k)]
    a.poly(mouth + [(mx, my + 6 * k)], "#0c0908", INK, 1.6)
    a.poly([(mx - mw * 0.7, my - mh * 0.3), (mx - mw * 0.4, my - mh * 0.75), (mx + mw * 0.3, my - mh * 0.8), (mx + mw * 0.6, my - mh * 0.4)], "#1c1714", stroke=None, opacity=0.8)
    for (dx, dy) in [(-5, -14), (3, -15)]:  # eyes in the dark
        a.ellipse(mx + dx * k, my + dy * k, 1.4, 1.0, "#d83a2a", opacity=0.9)
    # claw marks on the right face
    for j in range(3):
        x0, y0 = (26 + 5 * j) * k, -30 * k
        a.line([(x0, y0), (x0 + 6 * k, y0 + 14 * k)], "#2a2622", 1.6 + 0.4 * k)
        a.line([(x0 + 1, y0 + 1), (x0 + 6 * k + 1, y0 + 14 * k + 1)], "#8b877f", 0.8, opacity=0.6)
    # bones in front
    for _ in range(int(4 * k + 1)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(22, 34) * k
        ang = rng.uniform(-0.5, 0.5)
        _bone(a, x - 5 * math.cos(ang), y - 2 * math.sin(ang), x + 5 * math.cos(ang), y + 2 * math.sin(ang))
    x, y = 20 * k, 24 * k
    a.ellipse(x, y, 4.5, 4, BONE, INK, 1.1)
    a.ellipse(x - 1.4, y - 0.5, 1, 1.1, "#1a1612")
    a.ellipse(x + 1.6, y - 0.5, 1, 1.1, "#1a1612")
    a.save("lair_cave_big" if big else "lair_cave")


def lair_tree():
    rng = random.Random(710)
    a = Art()
    a.ellipse(0, 4, 120, 50, "#000", opacity=0.3)
    bark, bark_l, bark_d = "#3a3028", "#4c4036", "#241e19"
    # canopy behind
    for (x, y, r, c) in [(-70, -150, 30, "#1c2619"), (60, -160, 32, "#1a2417"), (-20, -190, 34, "#1f2a1c"), (30, -196, 26, "#1c2619")]:
        a.ellipse(x, y, r, r * 0.75, c, INK, 1.3)
    # branches
    for pts in [[(-14, -120), (-44, -140), (-80, -150), (-104, -170)], [(10, -124), (40, -146), (66, -158), (94, -150)],
                [(0, -130), (-6, -172), (-20, -200)], [(4, -128), (22, -176), (34, -206)], [(-40, -140), (-50, -176)]]:
        a.line(pts, INK, 9)
        a.line(pts, bark, 6.4)
    # roots
    for pts in [[(-30, -12), (-60, 4), (-96, 18), (-116, 16)], [(28, -12), (58, 2), (96, 12), (112, 8)],
                [(-18, -4), (-36, 24), (-52, 44)], [(16, -2), (30, 26), (40, 46)], [(-4, 0), (-6, 30), (2, 52)]]:
        a.line(pts, INK, 12)
        a.line(pts, bark_l, 8.6)
        a.line([(x + 1.5, y + 1.5) for (x, y) in pts], bark_d, 2.4, opacity=0.7)
    # trunk
    trunk = [(-46, -4), (-36, -40), (-26, -80), (-22, -120), (-14, -136), (12, -138), (22, -118), (26, -80), (38, -40), (50, -2), (0, 8)]
    a.poly(trunk, bark_d, INK, 1.6)
    a.poly(trunk[:6] + [(0, -110), (-4, -40), (0, 8)], bark, stroke=None)
    a.line(trunk + [trunk[0]], INK, 1.6)
    for pts in [[(-30, -20), (-22, -70), (-18, -110)], [(18, -30), (14, -80), (10, -120)], [(-8, -60), (-10, -100)]]:
        a.line(pts, bark_d, 1.6)
    # the hollow
    a.raw('<path d="M-22,6 Q-26,-30 -8,-52 Q2,-60 12,-50 Q28,-28 22,8 Q0,14 -22,6 Z" fill="#080605" stroke="%s" stroke-width="1.6"/>' % INK, [(-26, -60), (28, 14)])
    for (x, y) in [(-5, -30), (5, -30)]:
        a.ellipse(x, y, 1.8, 1.2, "#d8c040", opacity=0.9)
    # moss, ivy, hanging vines
    for _ in range(30):
        x, y = rng.uniform(-40, 30), rng.uniform(-130, -4)
        if -24 < x < 24 and y > -54:
            continue
        a.ellipse(x, y, rng.uniform(2, 4), rng.uniform(1.4, 2.6), rng.choice(["#2e4a26", "#3a5a2c", "#28401f"]), opacity=0.95)
    for (x, y, l) in [(-80, -140, 30), (-60, -146, 22), (50, -150, 28), (80, -152, 20), (-24, -180, 24)]:
        a.line([(x, y), (x + 2, y + l * 0.5), (x - 1, y + l)], "#3a4a26", 1.4, opacity=0.9)
    for (x, y, r) in [(-66, -148, 12), (68, -164, 14), (-10, -196, 14)]:
        a.ellipse(x, y, r, r * 0.6, "#2a3a22", opacity=0.9)
    a.save("lair_tree")


def lair_ruin(big=False):
    rng = random.Random(720 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()
    sl, sr, st = "#6a675f", "#4e4b46", "#7a766e"
    moss = "#4a6030"
    # the flooded pool
    pool = [(math.cos(t) * 52 * k * rng.uniform(0.9, 1.05), math.sin(t) * 24 * k * rng.uniform(0.9, 1.05) + 2 * k) for t in [j * math.pi / 8 for j in range(16)]]
    a.poly([(x * 1.08, y * 1.1) for (x, y) in pool], "#2e3a24", stroke=None, opacity=0.8)
    a.poly(pool, "#1d3636", "#26301e", 1.4)
    a.ellipse(-8 * k, 0, 30 * k, 11 * k, "#244442", opacity=0.7)

    def column(x, y, r, h, top_jag=True):
        ry = r * 0.5
        a.poly([(x - r, y), (x - r, y - h), (x - r * 0.3, y - h - 3), (x + r * 0.4, y - h + 2), (x + r, y - h - 1), (x + r, y)], sr, INK, 1.2)
        a.poly([(x - r, y), (x - r, y - h), (x - r * 0.3, y - h - 3), (x, y - h - 1), (x, y + ry)], sl, stroke=None)
        a.ellipse(x, y - h, r * 0.8, ry * 0.6, moss, opacity=0.85)
        a.ellipse(x, y, r + 2.5, ry + 1.2, "#1d3636", "#4a6a66", 0.9, opacity=0.9)  # water line ripple
    # a broken wall with an arch at the back
    wx, wy = -14 * k, -8 * k
    ww, wh = 26 * k, 34 * k
    a.poly([(wx - ww, wy), (wx - ww, wy - wh * 0.8), (wx - ww * 0.5, wy - wh), (wx, wy - wh * 0.85), (wx + ww * 0.4, wy - wh * 0.9), (wx + ww, wy - wh * 0.5), (wx + ww, wy)], sl, INK, 1.3)
    a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#141a18" stroke="%s" stroke-width="1.2"/>'
          % (fmt(wx - ww * 0.45), fmt(wy), fmt(wx - ww * 0.45), fmt(wy - wh * 0.45), fmt(wx), fmt(wy - wh * 0.85), fmt(wx + ww * 0.45), fmt(wy - wh * 0.45), fmt(wx + ww * 0.45), fmt(wy), INK),
          [(wx - ww, wy - wh), (wx + ww, wy)])
    for j in range(1, 4):
        a.line([(wx - ww, wy - wh * 0.2 * j), (wx - ww * 0.5, wy - wh * 0.2 * j)], "#4e4b46", 0.9)
        a.line([(wx + ww * 0.5, wy - wh * 0.2 * j), (wx + ww, wy - wh * 0.2 * j)], "#4e4b46", 0.9)
    for _ in range(int(8 * k)):
        a.ellipse(wx + rng.uniform(-ww, ww), wy - rng.uniform(0.2, 0.9) * wh, rng.uniform(2, 4), rng.uniform(1.4, 2.5), rng.choice(["#2e4a26", "#3a5a2c"]), opacity=0.95)
    a.line([(wx - ww, wy), (wx + ww, wy)], "#6a8a84", 1.0, opacity=0.7)
    cols = [(24, -6, 7, 26), (-34, 8, 6, 14), (12, 14, 6.5, 8)]
    if big:
        cols += [(40, 4, 6, 18), (-10, 18, 5, 5)]
    for (x, y, r, h) in sorted(cols, key=lambda c: c[1]):
        column(x * k, y * k, r * (1.3 if big else 1), h * k)
    # lily pads and a toppled drum
    for _ in range(int(3 * k)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(-6, 16) * k
        a.ellipse(x, y, 4, 2, "#3e5a2a", INK, 0.6)
    for _ in range(int(4 * k)):
        x, y = rng.uniform(-44, 44) * k, rng.uniform(-10, 18) * k
        a.line([(x - 4, y), (x + 4, y)], "#6a8a84", 0.9, opacity=0.5)
    a.save("lair_ruin_big" if big else "lair_ruin")


def lair_pit(big=False):
    rng = random.Random(730 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()
    rx, ry = 40 * k, 19 * k
    a.ellipse(0, 2, rx * 1.4, ry * 1.5, "#2a2420", opacity=0.6)
    rocks = []
    n = int(10 * k)
    for j in range(n):
        t = j * 2 * math.pi / n + rng.uniform(-0.1, 0.1)
        rocks.append((math.cos(t) * rx * 1.05, math.sin(t) * ry * 1.05, rng.uniform(6, 10) * (k ** 0.6)))
    back = [r for r in rocks if r[1] < 0]
    front = [r for r in rocks if r[1] >= 0]
    for (x, y, r) in sorted(back, key=lambda r: r[1]):
        _rock(a, rng, x, y, r, r * 0.8, "#4c4742", "#302c29", "#5c5650", sw=1.1, n=5)
    a.ellipse(0, 0, rx, ry, "#140e0a", INK, 1.4)
    _glow(a, 0, 2, rx * 0.9, ry * 0.9, "#e05a1a", 0.8)
    a.ellipse(0, 3, rx * 0.35, ry * 0.3, "#f08a24", opacity=0.7)
    a.ellipse(0, 3, rx * 0.15, ry * 0.13, "#ffd060", opacity=0.8)
    for (x, y, r) in sorted(front, key=lambda r: r[1]):
        _rock(a, rng, x, y, r, r * 0.8, "#4c4742", "#302c29", "#5c5650", sw=1.1, n=5)
    # glowing cracks in the ground around
    for j in range(int(5 * k)):
        t = rng.uniform(0.15, math.pi - 0.15)  # front half only, on the ground
        x0, y0 = math.cos(t) * rx * 1.15, math.sin(t) * ry * 1.15
        pts = [(x0, y0), (x0 * 1.12 + rng.uniform(-3, 3), y0 * 1.12 + rng.uniform(-1.5, 1.5)), (x0 * 1.25, y0 * 1.25)]
        a.line(pts, "#b8360c", 3.2, opacity=0.6)
        a.line(pts, "#f08a24", 1.2)
    # smoke
    for (x, y, r, op) in [(-4, -18, 10, 0.45), (6, -38, 14, 0.35), (-6, -62, 17, 0.25)]:
        a.ellipse(x * k, y * k, r * k, r * k * 0.8, "#6a6660", opacity=op)
    a.save("lair_pit_big" if big else "lair_pit")


def lair_crypt(big=False):
    rng = random.Random(740 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()
    sand, sand_l, sand_d = "#b3a06c", "#c6b27c", "#9a8658"
    a.ellipse(0, 6 * k, 64 * k, 26 * k, "#bba671", opacity=0.5)
    # the dune
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s" stroke="%s" stroke-width="1.3"/>'
          % (fmt(-62 * k), fmt(8 * k), fmt(-40 * k), fmt(-44 * k), fmt(6 * k), fmt(-40 * k), fmt(52 * k), fmt(-36 * k), fmt(62 * k), fmt(6 * k),
             fmt(0), fmt(40 * k), fmt(-62 * k), fmt(8 * k), sand_d, INK), [(-62 * k, -44 * k), (62 * k, 30 * k)])
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s"/>'
          % (fmt(-60 * k), fmt(8 * k), fmt(-40 * k), fmt(-42 * k), fmt(6 * k), fmt(-39 * k), fmt(-6 * k), fmt(-10 * k), fmt(2 * k), fmt(26 * k),
             fmt(-30 * k), fmt(22 * k), fmt(-60 * k), fmt(8 * k), sand), [(-60 * k, -42 * k), (6 * k, 26 * k)])
    for _ in range(int(3 * k)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(-24, 10) * k
        _arc(a, x, y, rng.uniform(14, 22) * k ** 0.7, 4, sand_l, 1.2, 0.7)
    # the crypt entrance on the front of the dune
    cx, cy = -6 * k, 14 * k
    pw, ph = 26 * k, 30 * k
    sl, sr, st = "#8a847a", "#6a655d", "#9c968a"
    a.poly([(cx - pw * 0.7, cy), (cx - pw * 0.7, cy - ph), (cx + pw * 0.7, cy - ph), (cx + pw * 0.7, cy)], "#0b0908", INK, 1.2)
    for x in (cx - pw, cx + pw * 0.7):  # pillars
        a.poly([(x, cy + 2 * k), (x, cy - ph), (x + pw * 0.3, cy - ph), (x + pw * 0.3, cy + 2 * k)], sl if x < cx else sr, INK, 1.2)
        a.line([(x + pw * 0.15, cy - ph + 4), (x + pw * 0.15, cy - 2)], "#5a554e", 0.9)
    a.poly([(cx - pw * 1.12, cy - ph), (cx - pw * 1.05, cy - ph - 9 * k), (cx + pw * 1.05, cy - ph - 9 * k), (cx + pw * 1.12, cy - ph)], st, INK, 1.3)  # lintel
    x, y = cx, cy - ph - 4.5 * k
    a.ellipse(x, y, 3.8 * k, 3.2 * k, "#c8c0a8", INK, 0.9)  # carved skull
    a.ellipse(x - 1.3 * k, y - 0.4 * k, 0.9 * k, 1 * k, INK)
    a.ellipse(x + 1.3 * k, y - 0.4 * k, 0.9 * k, 1 * k, INK)
    for (dx, sgn) in [(-2.2, -1), (2.2, 1)]:  # carved wings
        a.line([(x + dx * 2 * k, y), (x + sgn * 16 * k, y - 1.5 * k), (x + sgn * 12 * k, y + 1.5 * k)], "#6a655d", 1.0)
    # sand drifting over the bottom of the doorway
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s" stroke="%s" stroke-width="1.1"/>'
          % (fmt(cx - pw * 1.3), fmt(cy + 6 * k), fmt(cx - pw * 0.4), fmt(cy - 12 * k), fmt(cx + pw * 0.2), fmt(cy + 2 * k),
             fmt(cx + pw * 1.0), fmt(cy - 2 * k), fmt(cx + pw * 1.4), fmt(cy + 8 * k), sand, INK), [(cx - pw * 1.3, cy - 12 * k), (cx + pw * 1.4, cy + 8 * k)])
    # a stone block and a bone sticking out of the sand
    for (x, y) in [(30 * k, -8 * k), (-40 * k, 6 * k)][: (2 if big else 1)]:
        a.poly([(x - 6, y), (x - 6, y - 7), (x + 5, y - 9), (x + 7, y - 2), (x + 3, y + 2)], sl, INK, 1.0)
    _bone(a, 26 * k, 20 * k, 34 * k, 16 * k)
    a.save("lair_crypt_big" if big else "lair_crypt")


# ----------------------------------------------------------------------- miner

def miner():
    """Miner with a pickaxe over the shoulder and a lamp on his leather cap."""
    def extra(a, layer):
        if layer == "back":
            a.line([(8, -14), (-8, -38)], INK, 3.6)  # haft over the shoulder
            a.line([(8, -14), (-8, -38)], WOOD_L, 2)
            a.raw('<path d="M-17,-31 Q-12,-40 -8,-39 Q-3,-41 2,-46 Q-3,-38 -7,-36 Q-12,-35 -17,-31 Z" fill="#8a8a8a" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % INK,
                  [(-18, -47), (3, -30)])
        else:
            for (x, y) in [(-4, -19), (3, -14), (-2, -24)]:  # dust on the clothes
                a.ellipse(x, y, 1.8, 1.2, "#8a8274", opacity=0.6)
            a.line([(-6, -25), (4, -13)], "#3a2c1c", 1.8)  # strap
            a.line([(4, -21), (8, -16)], INK, 4)  # arm holding the haft
            a.ellipse(8, -15, 1.8, 1.8, "#d8b08c", INK, 0.8)

    def hat(a):
        a.raw('<path d="M-7,-34 Q-7,-43 0,-43 Q7,-43 7,-34 Z" fill="#5a4030" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -44), (8, -33)])
        a.line([(-7.5, -34.5), (9, -34.5)], INK, 2)
        a.ellipse(6.5, -39, 7, 7, GLOW, opacity=0.25)
        a.poly([(4.5, -41.5), (8.5, -41.5), (8.5, -37), (4.5, -37)], "#6a6a6a", INK, 0.9)
        a.ellipse(7.2, -39.2, 1.6, 1.8, GLOW)
        a.ellipse(-2, -30, 2, 1, "#8a8274", opacity=0.6)  # sooty cheek
    person("unit_miner", ("#6a6254", "#524b40"), hat=hat, extra=extra)


def biome_art():
    """All sprites added for the new biomes (called from main)."""
    for i in range(2):
        tile_grass_dark(i)
    for i in range(3):
        tile_meadow(i)
    for i in range(2):
        tile_heath(i)
        tile_swamp(i)
        tile_ash(i)
    tile_forest_oak()
    tile_sand()
    tile_water(0)
    tile_water(1)
    tile_shallow()
    tile_lava()
    tile_ford()
    tile_road_pass()
    tile_foam()
    for style in ("stone", "timber", "rope", "stilts", "charred"):
        for axis in ("x", "y"):
            bridge(style, axis)
    reeds()
    boulder()
    cactus()
    stump_charred()
    lava_rock()
    volcano()
    volcano_smoke()
    _save_pair(chest(), chest(True), "chest", "chest_looted")
    _save_pair(ruins(), ruins(True), "ruins", "ruins_looted")
    _save_pair(shrine(), shrine(True), "shrine", "shrine_looted")
    _save_pair(standing_stones(), standing_stones(True), "standing_stones", "standing_stones_looted")
    _save_pair(shipwreck(), shipwreck(True), "shipwreck", "shipwreck_looted")
    _save_pair(dragon_bones(), dragon_bones(True), "dragon_bones", "dragon_bones_looted")
    _save_pair(camp(), camp(True), "camp", "camp_cleared")
    _save_pair(stone_circle(), stone_circle(True), "stone_circle", "stone_circle_awake")
    _save_pair(mage_tower(), mage_tower(True), "mage_tower_ruin", "mage_tower_awake")
    watchtower_ruin()
    mine()
    lair_cave()
    lair_cave(big=True)
    lair_tree()
    lair_ruin()
    lair_ruin(big=True)
    lair_pit()
    lair_pit(big=True)
    lair_crypt()
    lair_crypt(big=True)
    miner()


def write_manifest():
    lines = ["# Generated by tools/gen_art.py - do not edit by hand.",
             "# name -> anchor (ax, ay) and size (w, h) in 1x world units; extra keys per sprite.",
             "class_name ArtManifest", "extends RefCounted", "", "const SPRITES := {"]
    for name in sorted(manifest):
        e = manifest[name]
        kv = ", ".join('"%s": %s' % (k, fmt(v)) for k, v in e.items())
        lines.append('\t"%s": {%s},' % (name, kv))
    lines.append("}")
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    os.makedirs(ART, exist_ok=True)
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    for i in range(3):
        tile_grass(i)
    tile_forest()
    tile_road()
    tile_desert(0)
    tile_desert(1)
    tile_rock()
    for i in range(3):
        mountain(i)
    tree_pine(0)
    tree_pine(1)
    tree_oak()
    tree_dead()
    hut()
    hut(ruin=True)
    wall()
    gate()
    # Tower levels 1-3 share one canvas so sprites line up when a tower levels up.
    for lvl in (1, 2, 3):
        suffix = "" if lvl == 1 else "_%d" % lvl
        wt = wall_tower(level=lvl)
        wt.pts = wall_tower(level=3).pts[:]
        wt.save("wall_tower" + suffix, extra={"platform": 78})
        wtf = wall_tower(front=True, level=lvl)
        wtf.pts = wt.pts[:]  # identical canvas so both layers line up
        wtf.save("wall_tower_front" + suffix)
        w = watchtower(level=lvl)
        w.pts = watchtower(level=3).pts[:]
        w.save("watchtower" + suffix, extra={"platform": 66})
        wf = watchtower(front=True, level=lvl)
        wf.pts = w.pts[:]
        wf.save("watchtower_front" + suffix)
    site()
    farm_field("field")
    farm_field("site")
    farm_shed()
    builder()
    farmer()
    explorer()
    archmage()
    archer()
    goblin()
    rat()
    gatherer()
    forester()
    worker_camp()
    ls = light_stone()
    ls.save("light_stone")
    lg = light_stone(glow_only=True)
    lg.pts = ls.pts[:]
    lg.save("light_stone_glow")
    light_halo()
    warning_light()
    corpse_goblin()
    hero()
    caravan()
    shield_bearer()
    crossbowman()
    swiftbowman()
    fire_summoner()
    fire_elemental()
    mages()
    spatial_archmage()
    projectiles()
    for lv in (1, 2, 3):
        barracks(lv)
    training_grounds()
    skeleton()
    corpse_skeleton()
    summoner()
    earth_elemental()
    ork()
    witch()
    corpse_ork()
    corpse_witch()
    spell_bolt()
    spell_glow()
    arrow()
    sack()
    biome_art()
    icons()
    flags()
    app_icon()
    title_background()
    write_manifest()
    print("generated %d sprites" % len(manifest))


if __name__ == "__main__":
    main()
