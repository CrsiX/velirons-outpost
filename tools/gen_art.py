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
    icons()
    flags()
    app_icon()
    title_background()
    write_manifest()
    print("generated %d sprites" % len(manifest))


if __name__ == "__main__":
    main()
