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
    h = [82, 104, 66, 92][i]
    ax = [6, -8, 10, -4][i]
    left, front, right = (-68, 2), (0, 34), (68, 2)
    apex = (ax, -h)
    a.poly([left, front, right, (40, -18), apex, (-44, -16)], "#3e3b36", stroke=None, opacity=0.4)  # shadowed back
    if i == 3:  # a twin peak: a second, lower summit behind on the right; the main one narrower
        ta = (34, -h * 0.72)
        a.poly([(0, -10), (40, 18), ta], "#6f6a62")
        a.poly([(40, 18), (68, 2), ta], "#514d47")
        a.line([(40, 18), ta], "#8d887f", 1.4)
        a.line([(40, 18), (68, 2), ta], INK, 1.4)
        front, right = (-8, 32), (40, 18)
    a.poly([left, front, apex], "#77726a")
    a.poly([front, right, apex], "#57534c")
    if i != 3:  # secondary shoulder peak
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


def _bough(a, pts, w0, w1=None, bark=WOOD_D, light=WOOD):
    """A branch along `pts` tapering from width w0 to w1: ink outline, bark, a lit edge."""
    w1 = w1 if w1 is not None else w0 * 0.45
    left, right = [], []
    for k, (x, y) in enumerate(pts):
        nx_, ny_ = pts[min(k + 1, len(pts) - 1)]
        px, py = pts[max(k - 1, 0)]
        dx, dy = nx_ - px, ny_ - py
        ln = math.hypot(dx, dy) or 1.0
        w = (w0 + (w1 - w0) * k / (len(pts) - 1)) / 2.0
        left.append((x - dy / ln * w, y + dx / ln * w))
        right.append((x + dy / ln * w, y - dx / ln * w))
    a.poly(left + right[::-1], bark, INK, 1.3)
    a.line(left if left[0][0] < right[0][0] else right, light, max(0.9, w0 * 0.25), opacity=0.7)


# Oak greens, lower clumps to upper ones (lit, shaded), like the pines' tiers.
OAK_GREENS = [("#203a22", "#172c19"), ("#26442a", "#1b331e"), ("#2c4e30", "#203a24"), ("#335a36", "#264429")]


def _clump(a, cx, cy, r, tone, sheen=False):
    """One round leaf clump in the flat style: ink outline, the left half lit
    and the right half shaded (split down the middle like a pine tier)."""
    lit, shade = OAK_GREENS[tone]
    ry = r * 0.88
    a.ellipse(cx, cy, r, ry, shade, INK, 1.4)
    half = [(cx + math.cos(math.pi / 2 + math.pi * k / 16) * r, cy - math.sin(math.pi / 2 + math.pi * k / 16) * ry) for k in range(17)]
    a.poly(half, lit, stroke=None)
    a.ellipse(cx, cy, r, ry, "none", INK, 1.4)
    if sheen:
        a.line([(cx - r * 0.55, cy - ry * 0.1), (cx - r * 0.3, cy - ry * 0.6)], "#4a7a4c", 1.6, opacity=0.8)


def _oak_trunk(a, w0, w1, top, lean=0.0):
    """A plain tapering trunk, lit left half and shaded right half like the pines' trunks."""
    tx = lean
    a.poly([(-w0, 0), (w0, 0), (tx + w1, top), (tx - w1, top)], WOOD_D, INK, 1.4)
    a.poly([(-w0, 0), (0, 0), (tx, top), (tx - w1, top)], WOOD, stroke=None)
    a.line([(-w0, 0), (tx - w1, top)], INK, 1.4)
    a.line([(w0, 0), (tx + w1, top)], INK, 1.4)


def _limb(a, x0, y0, x1, y1, w, col=WOOD_D, tip=0.4):
    """A plain branch: a tapering outlined wedge."""
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    a.poly([(x0 + nx * w, y0 + ny * w), (x1 + nx * w * tip, y1 + ny * w * tip), (x1 - nx * w * tip, y1 - ny * w * tip), (x0 - nx * w, y0 - ny * w)], col, INK, 1.3)


def tree_oak(i):
    """Oaks in the flat style of the pines: a plain trunk with a couple of
    limbs, and a crown of round clumps, lower ones darker, the top lit.
    0 a broad old oak, 1 a younger, taller one, 2 a crooked one leaning,
    its crown lopsided."""
    a = Art()
    if i == 0:
        a.shadow(36, 16)
        _oak_trunk(a, 6, 4, -34)
        _limb(a, -1, -28, -16, -44, 3.2)
        _limb(a, 1, -30, 17, -46, 3.2)
        for cx, cy, r, tone in [(-22, -54, 17, 0), (22, -54, 17, 0), (0, -52, 16, 0), (-12, -72, 20, 1), (13, -73, 19, 1)]:
            _clump(a, cx, cy, r, tone)
        _clump(a, 0, -90, 16, 2, sheen=True)
        a.save("tree_oak")
    elif i == 1:
        a.shadow(26, 12)
        _oak_trunk(a, 4.5, 3, -40)
        _limb(a, 0, -36, -10, -50, 2.4)
        _limb(a, 0, -38, 10, -52, 2.4)
        for cx, cy, r, tone in [(-11, -60, 13, 0), (11, -61, 13, 0), (-7, -78, 14, 1), (8, -80, 14, 1)]:
            _clump(a, cx, cy, r, tone)
        _clump(a, 0, -98, 13, 2, sheen=True)
        a.save("tree_oak_1")
    else:
        a.shadow(34, 15, cx=4)
        _oak_trunk(a, 6, 4, -30, lean=8)
        _limb(a, 3, -20, -10, -36, 3)
        _limb(a, 8, -28, 24, -42, 3)
        _clump(a, -14, -44, 13, 0)
        for cx, cy, r, tone in [(6, -54, 16, 0), (27, -52, 13, 0), (16, -70, 18, 1), (-4, -66, 13, 1)]:
            _clump(a, cx, cy, r, tone)
        _clump(a, 8, -84, 12, 2, sheen=True)
        a.ellipse(1, -12, 2.4, 3.6, "#1a120b", INK, 1)  # a hollow in the trunk
        a.save("tree_oak_2")


def tree_spruce():
    """The third pine (tree_pine_2): a slim, dark blue-green spruce whose five
    tiers droop at their tips."""
    a = Art()
    a.shadow(24, 11)
    a.poly([(-3, 0), (3, 0), (3, -14), (-3, -14)], WOOD_D)
    tiers = [(-10, 28, -40), (-28, 24, -58), (-46, 20, -76), (-64, 15, -94), (-82, 9, -110)]
    greens = [("#1c3832", "#122822"), ("#203d36", "#152c26"), ("#24433b", "#18302a"), ("#284940", "#1b342d"), ("#2c4e44", "#1e3830")]
    for (base, hw, apex), (gl, gr) in zip(tiers, greens):
        h = base - apex
        lt = [(0, apex), (-hw * 0.42, apex + h * 0.6), (-hw, base + 4), (-hw * 0.62, base - 1), (-hw * 0.3, base + 2), (0, base + 4)]
        rt = [(0, apex), (hw * 0.42, apex + h * 0.6), (hw, base + 4), (hw * 0.62, base - 1), (hw * 0.3, base + 2), (0, base + 4)]
        a.poly(lt, gl, stroke=None)
        a.poly(rt, gr, stroke=None)
        a.line(lt[1:][::-1] + rt[1:], INK, 1.0, opacity=0.6)
        a.line([lt[2], lt[1], (0, apex), rt[1], rt[2]], INK, 1.4)
    a.line([(-5, -60), (-2, -84)], "#3c6656", 1.4, opacity=0.7)
    a.save("tree_pine_2")


def tree_dead(i=0):
    """Dead trees: 0 a bare one with forked twigs, 1 a broken snag (a thick
    stump of a trunk snapped off jaggedly, peeled bark, a bracket fungus)."""
    if i == 1:
        a = Art()
        a.shadow(22, 9)
        bark, bark_l = "#4a4036", "#6b5f50"
        _bough(a, [(3, -26), (14, -34), (20, -46), (28, -50)], 4.2, 1.6, bark, bark_l)
        trunk = [(-11, 2), (-7, -4), (-6, -30), (-7, -40), (-3, -35), (-1, -48), (2, -38), (5, -43), (6, -28), (7, -4), (12, 2), (2, 0.5)]
        a.poly(trunk, bark, INK, 1.4)
        a.poly([(-11, 2), (-7, -4), (-6, -30), (-7, -40), (-3, -35), (-2, -12), (-4, 1)], bark_l, stroke=None, opacity=0.8)
        a.poly([(-1, -30), (3, -30), (2, -16), (-1, -18)], "#8a7d68", INK, 0.9)  # peeled bark
        a.line([(-4, -6), (-5, -26)], "#2f2720", 1.0, opacity=0.7)
        a.line([(4, -5), (3, -22)], "#2f2720", 1.0, opacity=0.7)
        a.poly([(5, -14), (12, -16), (12, -13), (5, -11)], "#a08a5c", INK, 1.0)  # bracket fungus
        a.poly([(5, -20), (10, -21), (10, -19), (5, -18)], "#a08a5c", INK, 0.9)
        a.save("tree_dead_1")
        return
    a = Art()
    a.shadow(20, 8)
    bark, bark_l = "#4a4036", "#5f5446"
    # limbs first (the trunk covers their roots), each a tapering wedge with a twig
    for x0, y0, x1, y1, w, tw in [(-1, -28, -15, -46, 3.0, (-19, -60)), (1, -34, 14, -50, 2.8, (23, -55)), (0, -40, 3, -64, 2.4, None), (-1, -36, -9, -52, 1.8, None)]:
        _limb(a, x0, y0, x1, y1, w, bark, 0.35)
        if tw:
            _limb(a, x1, y1, tw[0], tw[1], w * 0.4, bark, 0.3)
    trunk = [(-7, 1), (-4, -4), (-2, -46), (2, -46), (4, -4), (8, 1), (0, 0)]
    a.poly(trunk, bark, INK, 1.4)
    a.poly([(-7, 1), (-4, -4), (-2, -46), (0, -46), (0, 0)], bark_l, stroke=None)
    a.line([(-7, 1), (-4, -4), (-2, -46)], INK, 1.4)
    a.line([(1, -10), (0.5, -26)], "#352d25", 1.0, opacity=0.8)  # a crack in the bark
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


def wall(level=1):
    a = Art()
    x0, x1, y0, y1, h = -0.5, 0.5, -0.14, 0.14, 34
    a.box(x0, x1, y0, y1, 0, h, STONE_T, STONE_L, STONE_R)
    for z in (11, 22):
        a.line([P(x0, y1, z), P(x1, y1, z)], STONE_D, 1)
    for gx, z0 in [(-0.25, 0), (0.15, 0), (-0.05, 11), (0.35, 11), (-0.35, 22), (0.05, 22)]:
        a.line([P(gx, y1, z0), P(gx, y1, z0 + 11)], STONE_D, 1)
    if level >= 2:  # iron bands and a crimson pennon
        for z in (5, h - 3):
            a.line([P(x0, y1, z), P(x1, y1, z)], "#3a3632", 2.6)
        for gx in (-0.3, 0.1):
            for z in (5, h - 3):
                x, y = P(gx, y1, z)
                a.ellipse(x, y, 1.3, 1.3, "#8a8a8a")
        a.poly([P(-0.08, y1, h - 2), P(0.08, y1, h - 2), P(0.08, y1, 12), P(0.0, y1, 16), P(-0.08, y1, 12)], CRIMSON, INK, 1.1)
    for gx in (-0.42, -0.08, 0.26):
        a.box(gx, gx + 0.16, y0, y1, h, h + 8, STONE_T, STONE_L, STONE_R)
        if level >= 3:  # gilded merlon caps
            a.line([P(gx, y1, h + 8), P(gx + 0.16, y1, h + 8), P(gx + 0.16, y0, h + 8)], GOLD, 1.6)
    if level >= 3:
        a.line([P(x0, y1, h), P(x1, y1, h)], GOLD, 1.8)
    a.save("wall" if level == 1 else "wall_%d" % level)


def _block(a, rng, x, y, w):
    a.poly([(x - w, y), (x - w * 0.4, y - w * 0.7), (x + w * 0.6, y - w * 0.6), (x + w, y)], rng.choice([STONE_L, STONE_R, "#6b665e"]), INK, 1)


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
    a.box(x0, -0.22, y0, y1, 0, 46, STONE_T, STONE_L, STONE_R)
    a.box(0.22, x1, y0, y1, 0, 46, STONE_T, STONE_L, STONE_R)
    a.box(-0.22, 0.22, y0, y1, 30, 42, STONE_T, STONE_L, STONE_R)
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
    for gx in (-0.5, -0.36, 0.22, 0.36):
        a.box(gx, gx + 0.14, y0, y1, 46, 54, STONE_T, STONE_L, STONE_R)
        if level >= 3:
            a.line([P(gx, y1, 54), P(gx + 0.14, y1, 54), P(gx + 0.14, y0, 54)], GOLD, 1.6)
    # Veliron banner
    a.poly([P(-0.36, y1, 44), P(-0.26, y1, 44), P(-0.26, y1, 18), P(-0.31, y1, 23), P(-0.36, y1, 18)], CRIMSON)
    a.poly([P(0.26, y1, 44), P(0.36, y1, 44), P(0.36, y1, 18), P(0.31, y1, 23), P(0.26, y1, 18)], CRIMSON)
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


# ------------------------------------------------------- village pieces in wood
# Wood (Config.PIECE_MATERIALS): an improvised palisade for forward outposts:
# sharpened logs of uneven height, rope lashings, patched rails; level 2 a
# second rank behind with iron bands, level 3 a heavy stockade with hides over
# the top, stakes in front and a lantern. Walls run along gx like the stone ones.

LOG, LOG_L, LOG_D, LOG_CUT = "#6b4a2c", "#86603a", "#4a321d", "#c49a62"
ROPE, ROPE_D = "#bda574", "#7d6a45"
HIDE, HIDE_D = "#9a7350", "#6e4f35"
IRON, IRON_L = "#3a3632", "#8a8a8a"


def _log(a, x, y, h, r, lean=0.0, tip=7.0, charred=False, col=LOG):
    """An upright log standing at screen (x, y): bark, a lit left side, a
    sharpened top showing its cut wood (charred: a broken black stump)."""
    tx = x + lean
    if charred:
        top = [(tx + r, y - h), (tx + r * 0.3, y - h - 3), (tx - r * 0.2, y - h + 1), (tx - r, y - h - 4)]
        a.poly([(x - r, y + r * 0.4), (x + r, y + r * 0.4)] + top, col, INK, 1.2)
        a.poly([(x - r, y + r * 0.4), (tx - r, y - h - 4), (tx - r * 0.2, y - h + 1), (x - r * 0.25, y)], LOG_L, stroke=None, opacity=0.6)
        a.poly(top + [(tx - r, y - h + 3), (tx + r, y - h + 4)], "#1e1610", stroke=None)
        return
    body = [(x - r, y + r * 0.4), (tx - r, y - h), (tx, y - h - tip), (tx + r, y - h), (x + r, y + r * 0.4)]
    a.poly(body, col, INK, 1.2)
    a.poly([(x - r, y + r * 0.4), (tx - r, y - h), (tx - r * 0.25, y - h - tip * 0.75), (x - r * 0.25, y + r * 0.2)], LOG_L, stroke=None, opacity=0.75)
    a.poly([(tx - r, y - h), (tx, y - h - tip), (tx + r * 0.1, y - h + 2)], LOG_CUT, INK, 0.9)  # the cut facet
    a.line([(x + r * 0.35, y - 3), (tx + r * 0.35, y - h * 0.55)], LOG_D, 0.9, opacity=0.8)


def _logs(a, rng, g0, g1, gy, h, r=4.6, n=8, charred=False, var=4.0):
    """A row of logs along gx from g0 to g1 at gy, back to front."""
    out = []
    for k in range(n):
        gx = g0 + (g1 - g0) * (k + 0.5) / n
        x, y = P(gx, gy)
        hh = h + rng.uniform(-var, var)
        _log(a, x, y, hh, r, rng.uniform(-1.2, 1.2), rng.uniform(5.5, 8.5), charred)
        out.append((gx, hh))
    return out


def _lashing(a, g0, g1, gy, z, col=ROPE):
    a.line([P(g0, gy, z), P(g1, gy, z)], INK, 3.4)
    a.line([P(g0, gy, z), P(g1, gy, z)], col, 2.0)


def _stakes(a, rng, g0, g1, gy, n):
    """Sharpened stakes leaning out in front of the base."""
    for k in range(n):
        gx = g0 + (g1 - g0) * (k + 0.5) / n
        x0, y0 = P(gx, gy)
        x1, y1 = P(gx + rng.uniform(-0.03, 0.03), gy + 0.2, 14)
        a.line([(x0, y0), (x1, y1)], INK, 4.2)
        a.line([(x0, y0), (x1, y1)], LOG, 2.6)
        a.line([((x0 + x1 * 3) / 4, (y0 + y1 * 3) / 4), (x1, y1)], LOG_CUT, 2.0)


def _hides(a, rng, g0, g1, gy, z):
    """Hides thrown over the top of a row, hanging down unevenly."""
    gx = g0
    while gx < g1 - 0.05:
        w = rng.uniform(0.14, 0.22)
        e = min(g1, gx + w)
        drop = rng.uniform(9, 15)
        pts = [P(gx, gy, z + 3), P(e, gy, z + 3), P(e, gy, z - drop), P((gx + e) / 2, gy, z - drop + rng.uniform(-3, 4)), P(gx, gy, z - drop + 2)]
        a.poly(pts, rng.choice([HIDE, "#8a6646", "#a88260"]), INK, 1.0)
        a.line([P(gx + 0.03, gy, z), P(e - 0.03, gy, z - drop * 0.6)], HIDE_D, 0.8, opacity=0.7)
        gx = e + rng.uniform(0.03, 0.12)


def _lantern(a, x, y, pole):
    """A lantern hung from a crooked pole at screen (x, y), its glow."""
    a.line([(x, y), (x + 1, y - pole), (x + 8, y - pole - 1)], INK, 3.2)
    a.line([(x, y), (x + 1, y - pole), (x + 8, y - pole - 1)], LOG, 1.8)
    lx, ly = x + 8, y - pole + 7
    a.ellipse(lx, ly, 9, 9, GLOW, opacity=0.3)
    a.line([(lx, y - pole - 1), (lx, ly - 4)], INK, 1)
    a.poly([(lx - 2.6, ly - 4), (lx + 2.6, ly - 4), (lx + 2.6, ly + 3.5), (lx - 2.6, ly + 3.5)], GLOW, INK, 0.9)


def wood_wall(level=1):
    rng = random.Random(720 + level)
    a = Art()
    a.poly(diamond(0.62, 0.22), "#2d2a26", stroke=None, opacity=0.3)
    h = 36
    if level >= 2:  # the second rank behind, and the walkway's edge between them
        _logs(a, rng, -0.5, 0.5, -0.09, h + 6, r=4.2, n=8, var=2.5)
        a.line([P(-0.5, -0.02, h - 8), P(0.5, -0.02, h - 8)], INK, 4)
        a.line([P(-0.5, -0.02, h - 8), P(0.5, -0.02, h - 8)], "#7a5a38", 2.4)
    _logs(a, rng, -0.5, 0.5, 0.06, h, n=8)
    if level >= 2:
        for z in (8, h - 8):  # iron bands, riveted
            a.line([P(-0.5, 0.1, z), P(0.5, 0.1, z)], IRON, 2.6)
            for gx in (-0.36, -0.12, 0.12, 0.36):
                x, y = P(gx, 0.1, z)
                a.ellipse(x, y, 1.2, 1.2, IRON_L)
    else:
        _lashing(a, -0.5, 0.5, 0.1, 10)
        _lashing(a, -0.5, 0.5, 0.1, h - 9)
        # a patched rail: a split board nailed across, a little askew
        a.line([P(-0.32, 0.1, 18), P(0.05, 0.1, 22)], INK, 4)
        a.line([P(-0.32, 0.1, 18), P(0.05, 0.1, 22)], "#8a6a46", 2.4)
    if level >= 3:
        _hides(a, rng, -0.5, 0.5, 0.1, h + 2)
        _stakes(a, rng, -0.45, 0.45, 0.12, 4)
        x, y = P(0.38, 0.12)
        _lantern(a, x, y, h + 14)
    a.save("wood_wall" if level == 1 else "wood_wall_%d" % level)


def wood_wall_ruin():
    rng = random.Random(730)
    a = Art()
    a.poly(diamond(0.75, 0.4), "#2a2420", stroke=None, opacity=0.5)
    for k in range(7):  # burnt stumps
        gx = -0.45 + k * 0.15
        x, y = P(gx, 0.06)
        _log(a, x, y, rng.uniform(4, 18), 4.4, rng.uniform(-1, 1), charred=True)
    for (g0, d0, g1, d1) in [(-0.4, 0.2, 0.05, 0.42), (0.1, 0.18, 0.45, 0.3), (-0.2, -0.25, 0.25, -0.12)]:  # fallen logs
        a.line([P(g0, d0, 3), P(g1, d1, 3)], INK, 8.4)
        a.line([P(g0, d0, 3), P(g1, d1, 3)], LOG, 6)
        a.line([P(g0, d0, 4.5), P(g1, d1, 4.5)], LOG_L, 2, opacity=0.7)
        x, y = P(g1, d1, 3)
        a.ellipse(x, y, 3.2, 3.2, "#2a1e15", INK, 1)  # charred end
    for _ in range(4):
        x, y = P(rng.uniform(-0.4, 0.4), rng.uniform(-0.1, 0.4))
        a.ellipse(x, y, 2, 1.3, "#c04a1e", opacity=0.7)  # embers
    a.save("wood_wall_ruin")


def wood_gate(level=1):
    rng = random.Random(740 + level)
    a = Art()
    a.poly(diamond(0.62, 0.24), "#2d2a26", stroke=None, opacity=0.3)
    h, y1 = 36, 0.06
    if level >= 2:
        _logs(a, rng, -0.5, -0.28, -0.09, h + 6, r=4.2, n=2, var=2)
        _logs(a, rng, 0.28, 0.5, -0.09, h + 6, r=4.2, n=2, var=2)
    _logs(a, rng, -0.5, -0.28, y1, h, n=2)
    # the door: planks between two posts, a Z brace, rope hinges
    d0, d1, dh = -0.22, 0.22, h - 6
    a.poly([P(d0, y1, 0), P(d1, y1, 0), P(d1, y1, dh), P(d0, y1, dh)], "#5a3e24", INK, 1.2)
    for k in range(1, 6):
        gx = d0 + (d1 - d0) * k / 6
        a.line([P(gx, y1, 0), P(gx, y1, dh + rng.uniform(-2, 1))], LOG_D, 1.2)
    for z in (5, dh - 5):
        a.line([P(d0, y1, z), P(d1, y1, z)], INK, 4)
        a.line([P(d0, y1, z), P(d1, y1, z)], "#7a5636", 2.6)
    a.line([P(d0 + 0.02, y1, 6), P(d1 - 0.02, y1, dh - 6)], INK, 4)
    a.line([P(d0 + 0.02, y1, 6), P(d1 - 0.02, y1, dh - 6)], "#7a5636", 2.6)
    if level >= 2:  # iron straps and studs
        for z in (5, dh - 5):
            for gx in (-0.16, -0.05, 0.05, 0.16):
                x, y = P(gx, y1, z)
                a.ellipse(x, y, 1.2, 1.2, IRON_L)
        a.line([P(d0, y1, h * 0.5), P(d1, y1, h * 0.5)], IRON, 2.6)
    else:
        for z in (8, dh - 8):
            x, y = P(d0 + 0.01, y1, z)
            a.line([(x - 2, y - 2), (x + 3, y + 2)], ROPE, 2)
    # two thick posts and the lintel log across them
    for gx in (-0.26, 0.26):
        x, y = P(gx, y1)
        _log(a, x, y, h + 12, 6, 0, 8)
    lz = h + 4
    a.line([P(-0.32, y1, lz), P(0.32, y1, lz)], INK, 8.5)
    a.line([P(-0.32, y1, lz), P(0.32, y1, lz)], LOG, 6)
    a.line([P(-0.32, y1, lz + 1.6), P(0.32, y1, lz + 1.6)], LOG_L, 1.8, opacity=0.8)
    x, y = P(0.32, y1, lz)
    a.ellipse(x, y, 3.3, 3.3, LOG_CUT, INK, 1)
    for gx in (-0.26, 0.26):
        x, y = P(gx, y1, lz)
        a.line([(x - 3, y - 4), (x + 3, y + 4)], ROPE, 2.2)
        a.line([(x + 3, y - 4), (x - 3, y + 4)], ROPE, 2.2)
    # a crimson rag of Veliron tied to the lintel
    x, y = P(0.0, y1, lz - 3)
    a.poly([(x - 5, y), (x + 5, y + 2), (x + 3, y + 14), (x, y + 10), (x - 3, y + 13)], CRIMSON, INK, 1)
    _logs(a, rng, 0.28, 0.5, y1, h, n=2)
    if level >= 3:
        _hides(a, rng, -0.5, -0.29, y1 + 0.02, h + 1)
        _hides(a, rng, 0.29, 0.5, y1 + 0.02, h + 1)
        _stakes(a, rng, -0.48, -0.3, 0.1, 2)
        _stakes(a, rng, 0.3, 0.48, 0.1, 2)
        for gx in (-0.26, 0.26):
            x, y = P(gx, y1 + 0.03, h - 2)
            a.ellipse(x, y - 4, 8, 8, GLOW, opacity=0.3)
            a.poly([(x - 2.5, y - 8), (x + 2.5, y - 8), (x + 2.5, y), (x - 2.5, y)], GLOW, INK, 0.9)
    a.save("wood_gate" if level == 1 else "wood_gate_%d" % level)


def wood_gate_ruin():
    rng = random.Random(750)
    a = Art()
    a.poly(diamond(0.75, 0.42), "#2a2420", stroke=None, opacity=0.5)
    for gx, hh in [(-0.44, 12), (-0.33, 7), (0.33, 15), (0.44, 5)]:
        x, y = P(gx, 0.06)
        _log(a, x, y, hh, 4.4, charred=True)
    x, y = P(-0.26, 0.06)
    _log(a, x, y, 26, 6, charred=True)  # a post still standing, burnt
    # the door fallen flat in the opening
    a.poly([P(-0.2, 0.12, 0), P(0.18, 0.12, 0), P(0.22, 0.42, 0), P(-0.16, 0.42, 0)], "#4a3220", INK, 1.2)
    for t in (0.25, 0.5, 0.75):
        a.line([P(-0.2 + 0.38 * t, 0.12, 0), P(-0.16 + 0.38 * t, 0.42, 0)], "#2b1e14", 1.1)
    a.line([P(-0.16, 0.15, 0), P(0.16, 0.38, 0)], "#5a3e24", 2.2)
    a.line([P(0.2, 0.0, 2), P(0.45, 0.32, 4)], INK, 8)  # the lintel log on the ground
    a.line([P(0.2, 0.0, 2), P(0.45, 0.32, 4)], LOG, 5.6)
    for _ in range(4):
        x, y = P(rng.uniform(-0.4, 0.4), rng.uniform(0.0, 0.45))
        a.ellipse(x, y, 2, 1.3, "#c04a1e", opacity=0.7)
    a.poly([P(0.05, 0.3, 0), P(0.15, 0.3, 0), P(0.13, 0.4, 0)], CRIMSON_D, INK, 0.8)  # the rag
    a.save("wood_gate_ruin")


WOOD_DECK = 60  # the wooden wall tower's platform height


def _wood_rail(a, rng, s, z, front, level):
    """The sharpened railing logs round the deck: the back two sides, or the front two."""
    n = 5
    pts = []
    if front:
        for k in range(n):
            pts.append((-s + 2 * s * (k + 0.5) / n, s))
        for k in range(n):
            pts.append((s, s - 2 * s * (k + 0.5) / n))
        pts.sort(key=lambda q: q[0] + q[1])
    else:
        for k in range(n):
            pts.append((-s + 2 * s * (k + 0.5) / n, -s))
        for k in range(1, n):
            pts.append((-s, -s + 2 * s * k / n))
        pts.sort(key=lambda q: q[0] + q[1])
    for gx, gy in pts:
        x, y = P(gx, gy, z)
        _log(a, x, y, rng.uniform(12, 16), 3.6, rng.uniform(-0.8, 0.8), 5)
    if front:
        _lashing(a, -s, s, s + 0.02, z + 6)
        a.line([P(s + 0.02, s, z + 6), P(s + 0.02, -s, z + 6)], INK, 3.4)
        a.line([P(s + 0.02, s, z + 6), P(s + 0.02, -s, z + 6)], ROPE, 2)
        if level >= 2:
            _hides(a, rng, -s, s, s + 0.03, z + 14)
        if level >= 3:
            for gx in (-s + 0.05, s - 0.1):
                x, y = P(gx, s + 0.04, z + 4)
                a.line([(x, y), (x + 2, y + 10)], INK, 3)
                a.line([(x, y), (x + 2, y + 10)], LOG_CUT, 1.6)


def wood_wall_tower(front=False, level=1):
    """A timber watch platform on four legs with cross braces and a ladder; a
    railing of sharpened logs round the deck (the front side in its own layer,
    over the stationed unit)."""
    rng = random.Random(760 + level + (100 if front else 0))
    a = Art()
    s, z = 0.32, WOOD_DECK
    if front:
        a._track([P(-0.44, 0.44, 0), P(0.44, -0.44, 0), P(-0.44, -0.44, z + 60), P(0.44, 0.44, 0)])
        _wood_rail(a, rng, s, z + 2, True, level)
        return a
    a.shadow(50, 25, cy=4)
    if level >= 2:  # a palisade skirt round the legs
        _logs(a, rng, -s - 0.04, s + 0.04, -s - 0.02, 20, r=4, n=7, var=2)
    for gx, gy in [(-s, -s), (s, -s), (-s, s), (s, s)]:  # the four legs, back to front
        x, y = P(gx, gy)
        if gx == -s and gy == -s:
            _log(a, x, y, z + 2, 4.6, 0, 0.1)
            continue
        if gx == s and gy == s:
            # cross braces on both visible faces, behind the front leg
            for f0, f1 in [((-s, s), (s, s)), ((s, s), (s, -s))]:
                for zz0, zz1 in ((4, z - 6), (z - 6, 4)):
                    p0 = P(f0[0], f0[1], zz0)
                    p1 = P(f1[0], f1[1], zz1)
                    a.line([p0, p1], INK, 4.2)
                    a.line([p0, p1], "#6a4a2c", 2.6)
        _log(a, x, y, z + 2, 4.8, 0, 0.1)
    if level >= 2:
        _logs(a, rng, -s - 0.04, s + 0.04, s + 0.06, 20, r=4, n=7, var=2)
        for gy in (s - 0.1, 0.0, -s + 0.1):
            x, y = P(s + 0.06, gy)
            _log(a, x, y, 20 + rng.uniform(-2, 2), 4, 0, 6)
        a.line([P(-s - 0.04, s + 0.1, 10), P(s + 0.04, s + 0.1, 10)], IRON, 2.6)
    # the deck: thick planks
    a.box(-s - 0.06, s + 0.06, -s - 0.06, s + 0.06, z - 4, z + 2, "#8a6644", "#6a4a2c", "#4e361f", sw=1.3)
    for k in range(1, 5):
        u = -s - 0.06 + (2 * s + 0.12) * k / 5
        a.line([P(u, -s - 0.06, z + 2), P(u, s + 0.06, z + 2)], "#5e4428", 1, opacity=0.8)
    # the ladder up the left face
    for gx in (-0.12, 0.04):
        a.line([P(gx, s + 0.1, 0), P(gx, s + 0.06, z)], INK, 3.2)
        a.line([P(gx, s + 0.1, 0), P(gx, s + 0.06, z)], "#8a6644", 1.8)
    for k in range(1, 8):
        zz = z * k / 8
        a.line([P(-0.12, s + 0.09, zz), P(0.04, s + 0.09, zz)], "#8a6644", 1.6)
    _wood_rail(a, rng, s, z + 2, False, level)
    # Veliron's rag on a pole at the back
    x, y = P(-s + 0.02, -s + 0.02, z + 2)
    a.line([(x, y), (x + 1, y - 40)], INK, 3)
    a.line([(x, y), (x + 1, y - 40)], LOG, 1.6)
    a.poly([(x + 1, y - 40), (x + 17, y - 36), (x + 12, y - 31), (x + 16, y - 26), (x + 1, y - 27)], CRIMSON, INK, 1)
    if level >= 3:
        x, y = P(s, -s, z + 2)
        _lantern(a, x, y, 26)
    return a


def wood_wall_tower_ruin():
    rng = random.Random(770)
    a = Art()
    a.shadow(50, 25, cy=4)
    s = 0.32
    for gx, gy, hh in [(-s, -s, 30), (s, -s, 12), (-s, s, 18), (s, s, 6)]:
        x, y = P(gx, gy)
        _log(a, x, y, hh, 4.6, charred=True)
    # the deck broken in two: one half leaning against a leg, planks scattered
    a.poly([P(-s, -s + 0.05, 26), P(0.02, -s + 0.02, 22), P(0.06, 0.05, 0), P(-s + 0.04, 0.1, 2)], "#5a4028", INK, 1.3)
    for t in (0.33, 0.66):
        a.line([P(-s + (s + 0.02) * t, -s + 0.04, 24 - 2 * t), P(-s + 0.04 + (s + 0.02) * t, 0.08, 1)], "#3a2818", 1.1)
    a.poly([P(0.08, 0.12, 0), P(0.34, 0.06, 0), P(0.4, 0.3, 0), P(0.12, 0.36, 0)], "#5a4028", INK, 1.2)
    a.line([P(0.2, 0.09, 0), P(0.25, 0.33, 0)], "#3a2818", 1.1)
    for (g0, d0, g1, d1) in [(-0.1, 0.42, 0.18, 0.48), (0.36, -0.2, 0.46, 0.05)]:
        a.line([P(g0, d0, 1), P(g1, d1, 1)], INK, 4)
        a.line([P(g0, d0, 1), P(g1, d1, 1)], "#7a5a38", 2.4)
    for (g0, d0, g1, d1) in [(-0.45, 0.35, 0.0, 0.5), (0.3, -0.4, 0.5, 0.2)]:
        a.line([P(g0, d0, 3), P(g1, d1, 3)], INK, 7.4)
        a.line([P(g0, d0, 3), P(g1, d1, 3)], LOG, 5)
    for _ in range(5):
        x, y = P(rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.45))
        a.ellipse(x, y, 2, 1.3, "#c04a1e", opacity=0.7)
    x, y = P(-0.1, 0.3)
    a.ellipse(x, y - 16, 7, 10, "#8a8580", opacity=0.22)  # smoke
    a.save("wood_wall_tower_ruin")


# --------------------------------------------------- village pieces in sandstone
# Sandstone: warm ashlar of big smooth blocks on a plinth, a cornice and stepped
# merlons, a pointed arch over the gate; level 2 blue glazed tiles and blue
# cloth, level 3 gilded tops and brass lamps.

SAND_T, SAND_L, SAND_R, SAND_D, SAND_B = "#dcc08e", "#c8a46e", "#a5824f", "#8a6a40", "#b48f5a"
TILE_BLUE, TILE_BLUE_D, TILE_TEAL = "#2c5a86", "#1f405f", "#3a8a8a"
BRASS = "#b8913a"


def _merlon_spots(s, front, k=0.13):
    """The merlon corners round a square top of half-size s (as merlons())."""
    if front:
        return [(-s, s - k), (0 - k / 2, s - k), (s - k, s - k), (s - k, 0 - k / 2), (s - k, -s)]
    return [(-s, -s), (-s + 0.25 * 2 * s, -s), (s - k, -s), (-s, 0 - k / 2)]


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
        hanging_banner(a, ("left", y1), -0.07, 0.07, h - 7, 10, colour=TILE_BLUE)
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
    # Veliron's banners on the towers: blue in sandstone
    hanging_banner(a, ("left", y1), -0.4, -0.3, 46, 20, colour=TILE_BLUE)
    hanging_banner(a, ("left", y1), 0.3, 0.4, 46, 20, colour=TILE_BLUE)
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
    a.poly([P(-0.4, y1, 28), P(-0.3, y1, 28), P(-0.31, y1, 14), P(-0.35, y1, 18), P(-0.39, y1, 12)], TILE_BLUE_D, INK, 0.9)
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
    a.line([P(-s + 0.06, -s + 0.06, h + 4), P(-s + 0.06, -s + 0.06, h + 44)], INK, 3)
    x, y = P(-s + 0.06, -s + 0.06, h + 44)
    a.poly([(x, y), (x + 20, y + 4), (x + 14, y + 9), (x + 20, y + 14), (x, y + 16)], TILE_BLUE)
    for gx, gy in _merlon_spots(s + 0.04, False, k):
        _sand_merlon(a, gx, gy, k, k, h + 4, gold=level >= 3)
    if level >= 2:
        _tile_band(a, -s, s, s, h - 7, h - 1)
        _tile_band_right(a, s, -s, s, h - 7, h - 1)
        hanging_banner(a, ("left", s), -0.22, -0.02, h - 8, h - 36, colour=TILE_BLUE)
    if level >= 3:
        hanging_banner(a, ("right", s), -0.12, 0.08, h - 8, h - 36, colour=TILE_BLUE)
        a.line([P(-s - 0.04, s + 0.04, h + 4), P(s + 0.04, s + 0.04, h + 4), P(s + 0.04, -s - 0.04, h + 4)], GOLD, 2)
        bx, by = P(s - 0.12, -s + 0.12, h + 4)
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


# ------------------------------------------------------ village pieces in basalt
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
    a.line([P(-s + 0.06, -s + 0.06, h + 4), P(-s + 0.06, -s + 0.06, h + 44)], INK, 3)
    x, y = P(-s + 0.06, -s + 0.06, h + 44)
    a.poly([(x, y), (x + 20, y + 4), (x + 14, y + 9), (x + 20, y + 14), (x, y + 16)], CRIMSON)
    _bas_merlons(a, random.Random(1011), s + 0.03, h + 4, False, level)
    if level >= 2:
        a.line([P(-s, s, h - 3), P(s, s, h - 3), P(s, -s, h - 3)], IRON, 3)
        hanging_banner(a, ("left", s), -0.22, -0.02, h - 6, h - 34)
    if level >= 3:
        _seam(a, [P(-s + 2 * s / 6, s, 2), P(-s + 2 * s / 6, s, 20), P(-s + 2 * s / 6 + 0.01, s, 34)])
        _seam(a, [P(s, -(-s + 4 * s / 6), 4), P(s, -(-s + 4 * s / 6), 30)])
        _seam(a, [P(s, -(-s + 2 * s / 6), 40), P(s, -(-s + 2 * s / 6), 58)])
        bx, by = P(s - 0.12, -s + 0.12, h + 4)
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


# ------------------------------------------------- huts in the other materials
# A village's huts share its material: stone keeps the timber cabin (hut()),
# sandstone a flat-roofed sandstone house with blue doors and tiles, basalt a dark,
# solid house of black blocks under a slate roof, wood a canvas tent.

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


TENT, TENT_L, TENT_D = "#b49c74", "#c9b38a", "#8c7656"


def wood_hut(ruin=False):
    """Wood: a canvas ridge tent on two poles, patched, guy ropes to pegs, its
    flap tied back and warm light inside."""
    rng = random.Random(1120)
    a = Art()
    x0, x1, w, h = -0.32, 0.3, 0.28, 40
    if ruin:
        a.poly(diamond(0.75), "#2a2420", stroke=None, opacity=0.5)
        a.poly([P(-0.3, -0.2, 0), P(0.25, -0.24, 0), P(0.3, 0.2, 0), P(0.0, 0.3, 4), P(-0.32, 0.18, 0)], TENT_D, INK, 1.3)  # the canvas, collapsed
        a.poly([P(-0.2, -0.1, 1), P(0.15, -0.14, 1), P(0.18, 0.12, 3), P(-0.18, 0.1, 2)], TENT, stroke=None, opacity=0.8)
        a.poly([P(0.05, 0.05, 2), P(0.2, 0.0, 1), P(0.24, 0.18, 1), P(0.08, 0.22, 2)], "#2a1e15", stroke=None, opacity=0.9)  # burnt through
        x, y = P(x1, 0.0)
        _log(a, x, y, 18, 2.6, 2, charred=True)  # a broken pole
        a.line([P(-0.4, 0.3, 1), P(-0.05, 0.45, 2)], INK, 3.6)
        a.line([P(-0.4, 0.3, 1), P(-0.05, 0.45, 2)], LOG, 2)
        for _ in range(3):
            x, y = P(rng.uniform(-0.2, 0.3), rng.uniform(-0.1, 0.3))
            a.ellipse(x, y, 2, 1.3, "#c04a1e", opacity=0.7)
        a.save("wood_hut_ruin")
        return
    a.shadow(42, 20, cy=4)
    for gx, gy in [(x0 - 0.06, -w - 0.06), (x1 + 0.06, -w - 0.05)]:  # back guy ropes
        a.line([P(gx * 0.95, 0, h + 2), P(gx, gy, 0)], ROPE_D, 1)
    # back slope (barely seen), the poles, the front slope, the open end
    a.poly([P(x0, 0, h), P(x1, 0, h), P(x1, -w, 0), P(x0, -w, 0)], TENT_D)
    front = [P(x0, 0, h), P(x1, 0, h), P(x1, w, 0), P(x0, w, 0)]
    a.poly(front, TENT)
    a.poly([P(x0, 0, h), P(x0 + 0.25, 0, h), P(x0 + 0.25, w, 0), P(x0, w, 0)], TENT_L, stroke=None, opacity=0.6)
    a.line(front + [front[0]], INK, 1.4)
    a.poly([P(-0.08, 0.12, h * 0.57), P(0.06, 0.12, h * 0.57), P(0.06, 0.22, h * 0.21), P(-0.08, 0.22, h * 0.21)], "#9a8462", INK, 0.9)  # a patch
    for t in (0.3, 0.7):
        a.line([P(-0.08 + 0.14 * t, 0.12, h * 0.57), P(-0.08 + 0.14 * t, 0.22, h * 0.21)], "#6e5a3e", 0.6, opacity=0.8)
    end = [P(x1, w, 0), P(x1, 0, h), P(x1, -w, 0)]
    a.poly(end, TENT_D)
    a.poly([P(x1, 0.14, 0), P(x1, 0, h * 0.72), P(x1, -0.12, 0)], "#1e1610")  # the opening
    x, y = P(x1, 0.0, 5)
    a.ellipse(x, y, 8, 6, GLOW, opacity=0.35)
    a.poly([P(x1, w, 0), P(x1, 0, h), P(x1, 0.14, 0)], TENT_L, INK, 1.1)  # the flap, tied back
    a.line([P(x1, 0.2, 14), P(x1, 0.12, 12)], ROPE_D, 1.2)
    a.line(end, INK, 1.4)
    for gx in (x0, x1):  # pole tops above the ridge
        a.line([P(gx, 0, h - 2), P(gx, 0, h + 6)], INK, 3.4)
        a.line([P(gx, 0, h - 2), P(gx, 0, h + 6)], LOG, 1.8)
    for gx, gy in [(x0 - 0.06, w + 0.06), (x1 + 0.07, w + 0.05)]:  # front guy ropes and pegs
        a.line([P(gx * 0.95, 0, h + 2), P(gx, gy, 0)], ROPE_D, 1.1)
        x, y = P(gx, gy)
        a.line([(x, y + 1), (x, y - 4)], INK, 2.6)
        a.line([(x, y + 1), (x, y - 4)], LOG_CUT, 1.4)
    a.save("wood_hut")


# --------------------------------------------------- village pieces in limestone
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
    a.line([P(-p + 0.07, -p + 0.07, h + 4), P(-p + 0.07, -p + 0.07, h + 44)], INK, 3)
    x, y = P(-p + 0.07, -p + 0.07, h + 44)
    a.poly([(x, y), (x + 20, y + 4), (x + 14, y + 9), (x + 20, y + 14), (x, y + 16)], CRIMSON)
    for gx, gy in _merlon_spots(p, False, k):
        _lime_merlon(a, gx, gy, k, k, h + 4, hgt=8, gold=level >= 3)
    if level >= 2:
        hanging_banner(a, ("left", s), -0.24, -0.04, h - 6, h - 34)
        _arrow_loop(a, "side", s, 0.12, 22)
    if level >= 3:
        hanging_banner(a, ("right", s), -0.06, 0.14, h - 6, h - 34)
        a.line([P(-p, p, h + 4), P(p, p, h + 4), P(p, -p, h + 4)], GOLD, 2)
        bx, by = P(p - 0.13, -p + 0.13, h + 4)
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


THATCH, THATCH_L, THATCH_D = "#b8954e", "#cfae66", "#8a6c34"


# ----------------------------------------------------- village pieces in granite
# Granite (Highlands): rough dry-stone of rounded, speckled blocks without
# mortar, moss in the joints, overhanging slate coping; the wall towers round
# brochs. Level 2 a tartan banner, level 3 gilt and a peat
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


def _tartan_banner(a, face, u0, u1, z_top, z_bot):
    """Veliron's crimson with a green and gold check (a hanging banner)."""
    hanging_banner(a, face, u0, u1, z_top, z_bot)
    def at(u, z):
        return P(u, face[1], z) if face[0] == "left" else P(face[1], -u, z)
    um = (u0 + u1) / 2
    for z in (z_top - (z_top - z_bot) * 0.3, z_top - (z_top - z_bot) * 0.65):
        a.line([at(u0, z), at(u1, z)], TARTAN, 2.2, opacity=0.85)
    for u in (u0 + (u1 - u0) * 0.25, u0 + (u1 - u0) * 0.75):
        a.line([at(u, z_top), at(u, z_bot + 3)], TARTAN, 2, opacity=0.85)
    a.line([at(um, z_top), at(um, z_bot + 6)], GOLD, 0.8, opacity=0.8)


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
        _tartan_banner(a, ("left", y1), -0.07, 0.07, h - 2, 6)
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
    _tartan_banner(a, ("left", y1), -0.42, -0.3, 44, 18)
    _tartan_banner(a, ("left", y1), 0.3, 0.42, 44, 18)
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


def _ring(r, z, t0, t1, n=12):
    """Points round a circle of radius r (tiles) at height z, angles t0..t1 (degrees)."""
    return [P(r * math.cos(math.radians(t0 + (t1 - t0) * k / n)), r * math.sin(math.radians(t0 + (t1 - t0) * k / n)), z) for k in range(n + 1)]


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
    a.poly([(x, y), (x + 20, y + 4), (x + 14, y + 9), (x + 20, y + 14), (x, y + 16)], CRIMSON)
    a.line([(x + 6, y + 1.5), (x + 6, y + 14)], TARTAN, 1.6)
    a.line([(x + 1, y + 8), (x + 16, y + 8)], TARTAN, 1.6)
    _broch_merlons(a, random.Random(1348), r - 0.04, h + 4, False, level)
    if level >= 2:
        # a tartan banner down the front, an iron ring round the top
        t0, t1 = 70, 100
        z_top, z_bot = h - 4, h - 36
        tm = (t0 + t1) / 2
        pts = _ring(r + 0.005, z_top, t0, t1, 4) + [_ring(r + 0.005, z_bot, t1, t1, 1)[0], _ring(r + 0.005, z_bot + 6, tm, tm, 1)[0], _ring(r + 0.005, z_bot, t0, t0, 1)[0]]
        a.poly(pts, CRIMSON, INK, 1.2)
        for z in (z_top - 10, z_top - 21):
            a.line(_ring(r + 0.006, z, t0, t1, 4), TARTAN, 2.2, opacity=0.85)
        for tt in (t0 + 8, t1 - 8):
            a.line([_ring(r + 0.006, z_top, tt, tt, 1)[0], _ring(r + 0.006, z_bot + 3, tt, tt, 1)[0]], TARTAN, 2, opacity=0.85)
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


# ----------------------------------------------------- village pieces in ice
# Ice (the cold north): blocks of glacier ice, pale blue and a little see-through,
# with snow heaped on every coping and ledge and icicles hanging from them; the
# wall towers square, the huts igloos. Level 2 a frost-blue banner and walrus
# tusks over the gate, level 3 gilt and a cold blue fire.

ICE_T, ICE_L, ICE_R, ICE_D = "#e3f3fa", "#a6cfe2", "#7aa5c3", "#3d6987"
ICE_B = ["#b6d9ea", "#9cc6dc", "#add3e6", "#c4e2ef"]  # a block's face shades, light to dark
ICE_BS = ["#86b0cc", "#78a2c0", "#8db7d1"]  # the shaded right faces
ICE_FL = "#f6fcff"
ICE_DEEP = "#14202b"
SNOW, SNOW_L, SNOW_R = "#f7fbfe", "#d3e3ee", "#b3cadb"
FROST = "#2f5f8a"
COLD_FIRE = "#7fd0ff"


def _ice_face(a, rng, face, at, g0, g1, z0, z1, rows, side_shade=False):
    """Blocks of ice on a face in staggered courses: a lit top edge on each, a few cracks."""
    def q(g, z):
        return P(g, at, z) if face == "front" else P(at, g, z)
    shades = ICE_BS if side_shade else ICE_B
    for r in range(rows):
        za = z0 + (z1 - z0) * r / rows
        zb = z0 + (z1 - z0) * (r + 1) / rows
        u = g0 - (0.0 if r % 2 == 0 else rng.uniform(0.04, 0.1))
        while u < g1 - 0.02:
            w = rng.uniform(0.15, 0.24)
            ua, ub = max(g0, u), min(g1, u + w)
            if g1 - ub < 0.06:
                ub = g1
            if ub - ua > 0.03:
                a.poly([q(ua, za), q(ub, za), q(ub, zb), q(ua, zb)], rng.choice(shades), ICE_D, 0.8)
                a.line([q(ua + 0.01, zb - 0.9), q(ub - 0.01, zb - 0.9)], ICE_FL, 1.0, opacity=0.8)
                if rng.random() < 0.14:
                    x, y = q(ua + (ub - ua) * rng.uniform(0.3, 0.7), (za + zb) / 2)
                    a.line([(x, y - 2.2), (x + 1.4, y), (x - 0.8, y + 1.6), (x + 0.6, y + 3)], ICE_D, 0.7, opacity=0.8)
            u += w


def _icicles(a, rng, face, at, g0, g1, z, n, lo=3.0, hi=9.0):
    """Icicles hanging below height z along a face's edge, g0 to g1."""
    for k in range(n):
        g = g0 + (g1 - g0) * (k + rng.uniform(0.2, 0.8)) / n
        x, y = P(g, at, z) if face == "front" else P(at, g, z)
        ln = rng.uniform(lo, hi)
        w = rng.uniform(1.0, 1.7)
        a.poly([(x - w, y), (x + w, y), (x + w * 0.2, y + ln)], "#d6eef8", ICE_D, 0.6)
        a.line([(x - w * 0.3, y + 0.5), (x, y + ln * 0.6)], ICE_FL, 0.6, opacity=0.9)


def _snow_cap(a, rng, x0, x1, y0, y1, z, t=4, o=0.04, drips=True):
    """A heap of snow over a coping: a white slab with a lumpy lip and icicles under its front and right edges."""
    a.box(x0 - o, x1 + o, y0 - o, y1 + o, z, z + t, SNOW, SNOW_L, SNOW_R, sw=1.1)
    for k in range(max(2, int((x1 - x0) / 0.12))):
        gx = x0 + (x1 - x0) * (k + 0.5) / max(2, int((x1 - x0) / 0.12))
        x, y = P(gx, y1 + o, z + t)
        a.ellipse(x, y - 0.4, rng.uniform(2.4, 4.2), rng.uniform(1.2, 1.9), SNOW, opacity=0.95)
    if drips:
        _icicles(a, rng, "front", y1 + o, x0, x1, z, max(2, int((x1 - x0) / 0.09)))
        _icicles(a, rng, "side", x1 + o, y0, y1, z, max(1, int((y1 - y0) / 0.09)), 3, 6)


def _ice_merlon(a, rng, gx, gy, kx, ky, z, hgt=8, gold=False):
    a.box(gx, gx + kx, gy, gy + ky, z, z + hgt, ICE_T, ICE_L, ICE_R, sw=1.1)
    zm = z + hgt * rng.uniform(0.4, 0.6)
    a.line([P(gx, gy + ky, zm), P(gx + kx, gy + ky, zm), P(gx + kx, gy, zm)], ICE_D, 0.8)
    a.box(gx - 0.012, gx + kx + 0.012, gy - 0.012, gy + ky + 0.012, z + hgt, z + hgt + 2.6, SNOW, SNOW_L, SNOW_R, sw=1)
    x, y = P(gx + kx * 0.5, gy + ky + 0.012, z + hgt + 2.6)
    a.ellipse(x, y - 0.3, kx * 26, 1.3, SNOW, opacity=0.95)
    if gold:
        a.line([P(gx - 0.012, gy + ky + 0.012, z + hgt + 2.6), P(gx + kx + 0.012, gy + ky + 0.012, z + hgt + 2.6), P(gx + kx + 0.012, gy - 0.012, z + hgt + 2.6)], GOLD, 1.5)
    _icicles(a, rng, "front", gy + ky, gx, gx + kx, z + hgt, 2, 2, 4)


def _drifts(a, rng, n, g0, g1, d0, d1, big=1.0):
    """Snow banked on the ground."""
    for _ in range(n):
        x, y = P(rng.uniform(g0, g1), rng.uniform(d0, d1))
        w = rng.uniform(4, 8) * big
        a.ellipse(x, y, w, w * 0.4, SNOW_L, opacity=0.9)
        a.ellipse(x - 1, y - 1, w * 0.85, w * 0.32, SNOW)


def _ice_shards(a, rng, n, g0, g1, d0, d1):
    """Broken blocks and shards lying about."""
    for _ in range(n):
        x, y = P(rng.uniform(g0, g1), rng.uniform(d0, d1))
        w = rng.uniform(3.2, 6)
        a.poly([(x - w, y), (x - w * 0.8, y - w * 0.7), (x - w * 0.1, y - w * 1.1), (x + w * 0.7, y - w * 0.8), (x + w, y)], rng.choice(ICE_B), ICE_D, 0.9)
        a.line([(x - w * 0.5, y - w * 0.6), (x - w * 0.1, y - w * 0.95)], ICE_FL, 0.8)
        if rng.random() < 0.6:
            a.ellipse(x, y - w * 1.0, w * 0.7, w * 0.25, SNOW, opacity=0.95)


def _crystal(a, gx, gy, k, z, hgt, glow=False):
    """A four-sided ice spike on the footprint gx..gx+k, gy..gy+k, rising hgt px from height z."""
    lo, co, ro = P(gx, gy + k, z), P(gx + k, gy + k, z), P(gx + k, gy, z)
    top = P(gx + k / 2, gy + k / 2, z + hgt)
    if glow:
        a.ellipse((co[0] + top[0]) / 2, (co[1] + top[1]) / 2, 10, 10, COLD_FIRE, opacity=0.25)
    cl, cr = ("#b9ecff", "#5cb8ea") if glow else ("#d6edf8", "#8fbad4")
    a.poly([lo, co, top], cl, ICE_D, 0.9)
    a.poly([co, ro, top], cr, ICE_D, 0.9)
    a.line([co, top], ICE_FL, 1.0, opacity=0.85)
    a.line([(lo[0] + (top[0] - lo[0]) * 0.25, lo[1] + (top[1] - lo[1]) * 0.25), (co[0] + (top[0] - co[0]) * 0.2, co[1] + (top[1] - co[1]) * 0.2)], ICE_D, 0.6, opacity=0.5)


def _spikes(a, rng, cx, cy, k, z, glow=False, tall=1.0, skip_right=False):
    """A cluster of ice spikes round (cx, cy): a tall one and two shorter, back to front."""
    parts = [(cx + k * 0.9, cy - k * 0.2, k * 0.6, rng.uniform(7, 11) * tall),
             (cx, cy, k, rng.uniform(13, 19) * tall),
             (cx - k * 0.85, cy + k * 0.25, k * 0.55, rng.uniform(6, 9) * tall)]
    if skip_right:  # leave out the small spike behind on the right
        parts = parts[1:]
    for px, py, pk, ph in sorted(parts, key=lambda t: t[0] + t[1]):
        _crystal(a, px - pk / 2, py - pk / 2, pk, z, ph, glow)


def _ice_panels(a, rng, face, at, g0, g1, z0, z1, side_shade=False):
    """Smooth glacier ice on a face: no courses; a deeper blue toward the foot, glare streaks, a fused seam or two, frozen bubbles."""
    def q(g, z):
        return P(g, at, z) if face == "front" else P(at, g, z)
    base = ICE_BS[0] if side_shade else ICE_B[1]
    a.poly([q(g0, z0), q(g1, z0), q(g1, z1), q(g0, z1)], base, ICE_D, 0.9)
    zl = z0 + (z1 - z0) * 0.38
    a.poly([q(g0, z0), q(g1, z0), q(g1, zl), q(g0, zl)], "#4f86ad", stroke=None, opacity=0.35)
    n = max(2, int((g1 - g0) / 0.2))
    for i in range(n):
        u = g0 + (g1 - g0) * (i + rng.uniform(0.15, 0.6)) / n
        w = rng.uniform(0.03, 0.06)
        d = (z1 - z0) * 0.0035
        a.poly([q(min(g1, u + w), z1 - 1), q(min(g1, u + 2 * w), z1 - 1), q(max(g0, min(g1, u + 2 * w - d)), z0 + 1), q(max(g0, u + w - d), z0 + 1)], ICE_FL, stroke=None, opacity=0.33)
    for _ in range(1 + int((g1 - g0) / 0.35)):
        u = rng.uniform(g0 + 0.05, g1 - 0.05)
        pts = [q(u + rng.uniform(-0.012, 0.012), z0 + (z1 - z0) * t / 5) for t in range(6)]
        a.line(pts, "#4f7fa3", 0.9, opacity=0.7)
    for _ in range(int((g1 - g0) * (z1 - z0) / 6) + 1):
        x, y = q(rng.uniform(g0 + 0.03, g1 - 0.03), rng.uniform(z0 + 3, z1 - 3))
        a.ellipse(x, y, rng.uniform(0.5, 1.1), rng.uniform(0.5, 1.1), ICE_FL, opacity=0.65)


def _ice_cap(a, rng, x0, x1, y0, y1, z, o=0.025):
    """A thin glassy cap with a dusting of snow and icicles under its front and right edges."""
    a.box(x0 - o, x1 + o, y0 - o, y1 + o, z, z + 2.4, "#eef9fe", ICE_L, ICE_R, sw=1.1)
    for _ in range(max(2, int((x1 - x0) / 0.15))):
        x, y = P(rng.uniform(x0, x1), rng.uniform(y0, y1), z + 2.4)
        a.ellipse(x, y, rng.uniform(2.2, 4), rng.uniform(1, 1.6), SNOW, opacity=0.9)
    _icicles(a, rng, "front", y1 + o, x0, x1, z, max(2, int((x1 - x0) / 0.08)), 3, 10)
    _icicles(a, rng, "side", x1 + o, y0, y1, z, max(1, int((y1 - y0) / 0.08)), 3, 7)


def _ice_torch(a, gx, y, z):
    """An iron torch on a wall face (front, at y), its flame lit."""
    x, yy = P(gx, y, z)
    a.ellipse(x, yy - 12, 12, 11, GLOW, opacity=0.3)
    a.line([(x, yy), (x, yy - 9)], INK, 4)
    a.line([(x, yy), (x, yy - 9)], IRON, 2.4)
    a.poly([(x - 3.2, yy - 8), (x + 3.2, yy - 8), (x + 2.4, yy - 11), (x - 2.4, yy - 11)], IRON, INK, 0.8)
    a.poly([(x - 3, yy - 11), (x - 1, yy - 17), (x + 0.5, yy - 14), (x + 1.8, yy - 20), (x + 3, yy - 11)], GLOW, "#b8401e", 0.9)
    a.poly([(x - 1.2, yy - 11), (x + 0.3, yy - 15.5), (x + 1.4, yy - 11)], "#fff1b8", stroke=None)


def _ice_lantern(a, gx, y, z):
    """A lantern on a short chain, hung from height z on a front face."""
    x, yy = P(gx, y, z)
    a.line([(x, yy), (x, yy + 6)], IRON, 1.4)
    a.ellipse(x, yy + 13, 9, 9, COLD_FIRE, opacity=0.3)
    a.poly([(x - 3, yy + 6), (x + 3, yy + 6), (x + 3, yy + 17), (x - 3, yy + 17)], COLD_FIRE, INK, 1)
    a.poly([(x - 4, yy + 5), (x + 4, yy + 5), (x + 2, yy + 2), (x - 2, yy + 2)], IRON, INK, 0.8)
    a.line([(x - 4, yy + 17.5), (x + 4, yy + 17.5)], IRON, 1.4)
    a.line([(x, yy + 6), (x, yy + 17)], "#e8f8ff", 0.9, opacity=0.9)


def ice_wall(level=1):
    rng = random.Random(1700 + level)
    a = Art()
    x0, x1, y0, y1, h = -0.5, 0.5, -0.15, 0.15, 28
    a.box(x0 - 0.02, x1 + 0.02, y0 - 0.03, y1 + 0.03, 0, 6, ICE_T, ICE_L, ICE_R)  # the glacier's foot
    a.box(x0, x1, y0, y1, 6, h, ICE_T, ICE_L, ICE_R)
    _ice_panels(a, rng, "front", y1, x0, x1, 6, h)
    _ice_panels(a, rng, "side", x1, y0, y1, 6, h, side_shade=True)
    _ice_cap(a, rng, x0, x1, y0, y1, h)
    if level >= 2:
        hanging_banner(a, ("left", y1), -0.07, 0.07, h - 2, 8, FROST, ICE_T)
    for i, gx in enumerate((-0.4, -0.15, 0.1, 0.35)):
        _spikes(a, rng, gx, 0.0, 0.1, h + 2.4, glow=level >= 3 and i % 2 == 0, tall=1.0 if level < 2 else 1.25)
    if level >= 3:
        _ice_torch(a, 0.3, y1, 8)
    _drifts(a, rng, 3, -0.45, 0.45, 0.17, 0.22, 0.7)
    a.save("ice_wall" if level == 1 else "ice_wall_%d" % level)


def ice_wall_ruin():
    rng = random.Random(1710)
    a = Art()
    y0, y1 = -0.15, 0.15
    a.poly(diamond(0.75, 0.4), "#27323a", stroke=None, opacity=0.35)
    for (u0, u1, h) in [(-0.5, -0.18, 14), (-0.18, 0.08, 5), (0.08, 0.32, 18), (0.32, 0.5, 8)]:
        a.box(u0, u1, y0, y1, 0, h, ICE_T, ICE_L, ICE_R)
        _ice_panels(a, rng, "front", y1, u0, u1, 0, h)
        for cx in (u0 + 0.05, u1 - 0.12):  # broken shards standing on it
            _crystal(a, cx, -0.05, 0.07, h, rng.uniform(4, 13))
        _icicles(a, rng, "front", y1, u0, u1, h, 2, 2.5, 5)
    _ice_shards(a, rng, 8, -0.45, 0.45, 0.2, 0.44)
    _drifts(a, rng, 5, -0.45, 0.45, 0.18, 0.4)
    a.save("ice_wall_ruin")


def ice_gate(level=1):
    rng = random.Random(1720 + level)
    a = Art()
    x0, x1, y0, y1 = -0.5, 0.5, -0.16, 0.16
    a.poly(diamond(0.62, 0.26), "#27323a", stroke=None, opacity=0.3)
    # back to front: the left pier, the passage's body, the right pier
    for g0, g1 in [(x0, -0.2), (-0.2, 0.2), (0.2, x1)]:
        a.box(g0, g1, y0, y1, 0, 48, ICE_T, ICE_L, ICE_R)
        _ice_panels(a, rng, "front", y1, g0, g1, 0, 48)
        _ice_panels(a, rng, "side", g1, y0, y1, 0, 48, side_shade=True)
        _ice_cap(a, rng, g0, g1, y0, y1, 48)
    # the pointed arch of a frozen cave and its door of frosted planks
    def arch(w, spring, apex, n=8):
        pts = [P(-w, y1, 0)]
        for k in range(n + 1):
            pts.append(P(-w * (1 - k / n), y1, spring + (apex - spring) * math.sqrt(k / n)))
        for k in range(1, n + 1):
            pts.append(P(w * k / n, y1, spring + (apex - spring) * math.sqrt(1 - k / n)))
        pts.append(P(w, y1, 0))
        return pts
    a.poly(arch(0.19, 22, 42), ICE_DEEP, INK, 1.3)
    a.poly(arch(0.155, 20, 36), "#5f7587", INK, 1)

    def top_at(gx):
        return 20 + 16 * math.sqrt(max(0.0, 1 - abs(gx) / 0.155))
    for gx in (-0.1, -0.05, 0.0, 0.05, 0.1):
        a.line([P(gx, y1, 0), P(gx, y1, top_at(gx) - 1)], "#2f3f4c", 1.3)
    for z in (6, 16):
        a.line([P(-0.155, y1, z), P(0.155, y1, z)], IRON, 2.6 if level >= 2 else 1.8)
    if level >= 2:
        for z in (6, 16):
            for gx in (-0.12, -0.04, 0.04, 0.12):
                x, y = P(gx, y1, z)
                a.ellipse(x, y, 1.2, 1.2, IRON_L)
    for gx in (-0.13, -0.08, 0.07, 0.12):  # icicles hanging off the arch
        x, y = P(gx, y1, top_at(gx) + 2.5)
        a.poly([(x - 1.2, y), (x + 1.2, y), (x, y + rng.uniform(5, 9))], "#d6eef8", ICE_D, 0.6)
    if level >= 3:
        _ice_lantern(a, -0.285, y1, 40)
    hanging_banner(a, ("left", y1), -0.43, -0.31, 44, 18, FROST, ICE_T)
    hanging_banner(a, ("left", y1), 0.31, 0.43, 44, 18, FROST, ICE_T)
    spots = [(-0.4, 0.0, 0.1, False), (-0.28, 0.0, 0.08, level >= 3), (0.28, 0.0, 0.08, level >= 3), (0.4, 0.0, 0.1, False)]
    for cx, cy, k, gl in spots:
        _spikes(a, rng, cx, cy, k, 50.4, glow=gl, tall=1.0 if level < 2 else 1.3)
    if level >= 2:
        _spikes(a, rng, 0.0, 0.0, 0.1, 50.4, glow=level >= 3, tall=1.2)  # a crown over the arch
    _drifts(a, rng, 4, -0.45, 0.45, 0.19, 0.29, 0.8)
    a.save("ice_gate" if level == 1 else "ice_gate_%d" % level)


def ice_gate_ruin():
    rng = random.Random(1730)
    a = Art()
    y0, y1 = -0.16, 0.16
    a.poly(diamond(0.75, 0.42), "#27323a", stroke=None, opacity=0.35)
    a.box(-0.5, -0.2, y0, y1, 0, 18, ICE_T, ICE_L, ICE_R)
    _ice_panels(a, rng, "front", y1, -0.5, -0.2, 0, 18)
    _crystal(a, -0.46, -0.05, 0.08, 18, 8)
    _crystal(a, -0.32, -0.05, 0.07, 18, 4)
    _icicles(a, rng, "front", y1, -0.5, -0.2, 18, 3, 3, 6)
    a.box(0.2, 0.5, y0, y1, 0, 11, ICE_T, ICE_L, ICE_R)
    _ice_panels(a, rng, "front", y1, 0.2, 0.5, 0, 11)
    _crystal(a, 0.26, -0.05, 0.07, 11, 6)
    _crystal(a, 0.4, -0.05, 0.07, 11, 3)
    # the door split and fallen in the opening, the arch's blocks about it
    a.poly([P(-0.18, y1 + 0.03, 0), P(0.14, y1 + 0.05, 0), P(0.17, y1 + 0.3, 0), P(-0.15, y1 + 0.27, 0)], "#3f4d59", INK, 1.2)
    a.line([P(-0.03, y1 + 0.04, 0), P(0.01, y1 + 0.29, 0)], "#242f38", 1.2)
    _ice_shards(a, rng, 10, -0.45, 0.45, 0.24, 0.46)
    _drifts(a, rng, 5, -0.45, 0.45, 0.2, 0.44)
    a.poly([P(-0.42, y1, 16), P(-0.32, y1, 16), P(-0.33, y1, 7), P(-0.37, y1, 10), P(-0.41, y1, 6)], FROST, INK, 0.9)
    a.save("ice_gate_ruin")


def ice_wall_tower(front=False, level=1):
    """A glacier tower: smooth faceted ice, a shelf with icicles, a crown of ice spikes round its top."""
    rng = random.Random(1740 + level)
    a = Art()
    s, h, k = 0.34, 74, 0.12
    p = s + 0.03
    spots = _merlon_spots(p, front, k)
    if front:
        a._track([P(-0.36, 0.36, 0), P(0.36, -0.36, 0), P(-0.36, -0.36, h + 60), P(0.36, 0.36, 0)])
        for i, (gx, gy) in enumerate(spots):
            if i == 0:  # the left-most cluster sits a little in, so its glow isn't cut off at the sprite's edge
                gx, gy = gx + 0.06, gy - 0.06
            _spikes(a, rng, gx + k / 2, gy + k / 2, k * 0.9, h + 4, glow=level >= 3 and i % 2 == 0, tall=1.0 if level < 2 else 1.2, skip_right=gy == -p and gx == p - k)
        return a
    a.shadow(52, 26, cy=4)
    a.box(-s - 0.05, s + 0.05, -s - 0.05, s + 0.05, 0, 10, ICE_T, ICE_L, ICE_R)  # the glacier's foot
    _ice_panels(a, rng, "front", s + 0.05, -s - 0.05, s + 0.05, 0, 10)
    _ice_panels(a, rng, "side", s + 0.05, -s - 0.05, s + 0.05, 0, 10, side_shade=True)
    a.box(-s, s, -s, s, 10, h, ICE_T, ICE_L, ICE_R)
    _ice_panels(a, rng, "front", s, -s, s, 10, h)
    _ice_panels(a, rng, "side", s, -s, s, 10, h, side_shade=True)
    e = s + 0.025  # a shelf: its two faces only, so its top doesn't hide the body above
    a.poly([P(-e, e, 38), P(e, e, 38), P(e, e, 42), P(-e, e, 42)], ICE_L, ICE_D, 1.1)
    a.poly([P(e, e, 38), P(e, -e, 38), P(e, -e, 42), P(e, e, 42)], ICE_R, ICE_D, 1.1)
    a.line([P(-e, e, 42), P(e, e, 42), P(e, -e, 42)], ICE_FL, 1.4)
    _icicles(a, rng, "front", s + 0.025, -s, s, 38, 7, 4, 11)
    _icicles(a, rng, "side", s + 0.025, -s, s, 38, 7, 4, 11)
    for u, z in ((-0.12, 50), (0.14, 22)):
        _opening(a, "front", s, u, u + 0.06, z, z + 10, ICE_DEEP, arch=4, sw=0.8)
    _opening(a, "side", s, 0.03, -0.03, 52, 62, ICE_DEEP, arch=4, sw=0.8)
    a.box(-p, p, -p, p, h - 4, h + 4, ICE_T, ICE_L, ICE_R)  # the parapet's course
    _ice_panels(a, rng, "front", p, -p, p, h - 4, h + 4)
    _ice_panels(a, rng, "side", p, -p, p, h - 4, h + 4, side_shade=True)
    a.line([P(-p, p, h + 4), P(p, p, h + 4), P(p, -p, h + 4)], INK, 1.4)  # the panels cover the course's top edge
    _icicles(a, rng, "front", p, -p, p, h - 4, 7, 3, 10)
    _icicles(a, rng, "side", p, -p, p, h - 4, 7, 3, 10)
    a.poly([P(-p + 0.03, -p + 0.03, h + 4), P(p - 0.03, -p + 0.03, h + 4), P(p - 0.03, p - 0.03, h + 4), P(-p + 0.03, p - 0.03, h + 4)], "#e6f4fb", stroke=None)  # the glassy floor
    for gx, gy in ((0.0, 0.1), (-0.12, -0.05), (0.14, -0.1)):
        x, y = P(gx, gy, h + 4)
        a.ellipse(x, y, 7, 2.6, SNOW, opacity=0.9)
    a.line([P(-p + 0.07, -p + 0.07, h + 4), P(-p + 0.07, -p + 0.07, h + 44)], INK, 3)
    x, y = P(-p + 0.07, -p + 0.07, h + 44)
    a.poly([(x, y), (x + 20, y + 4), (x + 14, y + 9), (x + 20, y + 14), (x, y + 16)], FROST)
    for i, (gx, gy) in enumerate(spots):
        _spikes(a, rng, gx + k / 2, gy + k / 2, k * 0.9, h + 4, glow=level >= 3 and i % 2 == 0, tall=1.0 if level < 2 else 1.2, skip_right=gy == -p and gx == p - k)
    if level >= 2:
        hanging_banner(a, ("left", s), -0.24, -0.04, h - 6, h - 34, FROST, ICE_T)
        a.line([P(-s, s, h - 6), P(s, s, h - 6), P(s, -s, h - 6)], "#3a3632", 3)
    if level >= 3:
        hanging_banner(a, ("right", s), -0.06, 0.14, h - 6, h - 34, FROST, ICE_T)
    return a


def ice_wall_tower_ruin():
    rng = random.Random(1750)
    a = Art()
    s, h = 0.34, 30
    a.shadow(52, 26, cy=4)
    a.box(-s - 0.05, s + 0.05, -s - 0.05, s + 0.05, 0, 10, ICE_T, ICE_L, ICE_R)
    _ice_panels(a, rng, "front", s + 0.05, -s - 0.05, s + 0.05, 0, 10)
    a.box(-s, s, -s, s, 10, h, ICE_T, ICE_L, ICE_R)
    _ice_panels(a, rng, "front", s, -s, s, 10, h)
    _ice_panels(a, rng, "side", s, -s, s, 10, h, side_shade=True)
    a.box(-s, -s + 0.22, -s, -s + 0.22, h, h + 24, ICE_T, ICE_L, ICE_R)  # the back corner still standing
    _ice_panels(a, rng, "front", -s + 0.22, -s, -s + 0.22, h, h + 24)
    _ice_panels(a, rng, "side", -s + 0.22, -s, -s + 0.22, h, h + 24, side_shade=True)
    a.poly([P(-s, -s, h), P(s, -s, h), P(s, s, h), P(-s, s, h)], "#e6f4fb", ICE_D, 1)  # the broken head
    for gx, gy in ((0.1, 0.05), (-0.1, 0.15), (0.2, -0.1)):
        x, y = P(gx, gy, h)
        a.ellipse(x, y, 8, 3, SNOW, opacity=0.9)
    _crystal(a, -s + 0.07, -s + 0.07, 0.1, h + 24, 10)
    _crystal(a, 0.12, 0.1, 0.09, h, 8)
    _icicles(a, rng, "front", s, -s, s, h, 6, 3, 8)
    for _ in range(10):
        gx, gy = rng.uniform(-0.5, 0.5), rng.uniform(0.45, 0.56)
        if rng.random() < 0.5:
            gx, gy = rng.uniform(0.45, 0.56), rng.uniform(-0.5, 0.5)
        _ice_shards(a, rng, 1, gx, gx, gy, gy)
    _drifts(a, rng, 4, -0.5, 0.5, 0.4, 0.55)
    a.save("ice_wall_tower_ruin")


def _ice_hut_ruin(a, rng, ring_at):
    """The igloo caved in: only its lowest courses stand, the back a little higher,
    their broken tops showing the dome's thickness; blocks fallen inside and out."""
    a.shadow(46, 22, cy=4)
    r0, z0 = ring_at(0)
    a.poly(_ring(r0, z0, 0, 360, 36), SNOW, ICE_D, 0.8)  # the floor, snowed over
    wall = 0.07  # the dome's thickness

    def band(k, t0, t1, inside):
        """Course k between angles t0 and t1, outside or (the back) its inner face."""
        ra, za = ring_at(k)
        rb, zb = ring_at(k + 1)
        if inside:
            a.poly(_ring(ra - wall, za, t0, t1, 10) + _ring(rb - wall, zb, t1, t0, 10), "#5c86a6" if k % 2 == 0 else "#6a94b3", ICE_D, 0.8)
            return
        if t0 < 45:
            a.poly(_ring(ra, za, t0, min(45, t1), 12) + _ring(rb, zb, min(45, t1), t0, 12), ICE_BS[k % 3], stroke=None)
        a.poly(_ring(ra, za, max(45, t0), t1, 12) + _ring(rb, zb, t1, max(45, t0), 12), ICE_B[k % 2 + 1], stroke=None)
        a.line(_ring(ra, za, t0, t1, 24), ICE_D, 1.0)
        t = t0 + rng.uniform(4, 12) + (k % 2) * 12
        while t < t1 - 3:
            a.line([P(ra * math.cos(math.radians(t)), ra * math.sin(math.radians(t)), za), P(rb * math.cos(math.radians(t)), rb * math.sin(math.radians(t)), zb)], ICE_D, 0.8)
            t += rng.uniform(22, 34)

    def rim(k, t0, t1):
        """The broken top of course k: a band of ice as thick as the wall, snow on it."""
        r, z = ring_at(k + 1)
        a.poly(_ring(r, z, t0, t1, 10) + _ring(r - wall, z, t1, t0, 10), "#eef9fe", ICE_D, 1.0)
        for x, y in _ring(r - wall / 2, z, t0, t1, 6)[1:-1:2]:
            a.ellipse(x, y - 0.3, rng.uniform(2, 3.4), 1.1, SNOW, opacity=0.95)

    # the back of the dome, seen from inside: two courses, the second only on part of it
    band(0, 135, 315, True)
    band(1, 165, 285, True)
    rim(0, 135, 165)
    rim(0, 285, 315)
    rim(1, 165, 285)
    # the near side: the lowest course all round the front, a second where the dome held
    band(0, -45, 135, False)
    band(1, 55, 135, False)
    rim(0, -45, 55)
    rim(1, 55, 135)
    # the entrance tunnel, still standing, snowed
    tx0, tx1, ty0, ty1, th = -0.1, 0.1, 0.22, 0.46, 12
    a.box(tx0, tx1, ty0, ty1, 0, th, ICE_T, ICE_L, ICE_R, sw=1.2)
    _ice_face(a, rng, "front", ty1, tx0, tx1, 0, th, 2)
    _ice_face(a, rng, "side", tx1, ty0, ty1, 0, th, 2, side_shade=True)
    _opening(a, "front", ty1, -0.065, 0.065, 0, 8, ICE_DEEP, arch=3, sw=1)
    x, y = P(0, (ty0 + ty1) / 2, th)
    a.ellipse(x, y - 0.5, 10, 4.2, SNOW, ICE_D, 0.8)
    _icicles(a, rng, "front", ty1, tx0, tx1, th, 3, 3, 6)
    # fallen blocks of the dome, in and outside
    for gx, gy in ((0.12, 0.05), (-0.1, -0.02), (0.3, 0.1), (0.2, 0.3), (-0.3, 0.22)):
        x, y = P(gx, gy)
        w = rng.uniform(4, 6)
        a.poly([(x - w, y), (x - w * 0.8, y - w * 0.8), (x + w * 0.2, y - w), (x + w, y - w * 0.4), (x + w * 0.9, y)], rng.choice(ICE_B), ICE_D, 0.9)
        a.ellipse(x, y - w * 0.95, w * 0.7, w * 0.25, SNOW, opacity=0.95)
    _drifts(a, rng, 6, -0.4, 0.4, 0.1, 0.45, 0.8)
    a.save("ice_hut_ruin")


def ice_hut(ruin=False):
    """Ice: an igloo, a dome of stacked ice blocks with a low entrance tunnel,
    snow heaped on top, icicles hanging off the tunnel and the courses, a smoke
    hole; the ruin a caved-in ring of blocks."""
    rng = random.Random(1660)
    a = Art()
    R, RZ, bands = 0.36, 26, 5

    def ring_at(k):
        t = math.pi / 2 * k / bands
        return R * math.cos(t), RZ * math.sin(t)

    if ruin:
        _ice_hut_ruin(a, rng, ring_at)
        return
    a.shadow(46, 22, cy=4)
    _drifts(a, rng, 4, -0.4, 0.4, 0.3, 0.46, 0.8)
    for k in range(bands):
        r0, z0 = ring_at(k)
        r1, z1 = ring_at(k + 1)
        a.poly(_ring(r0, z0, 45, 135) + _ring(r1, z1, 135, 45), ICE_B[k % 2 + 1], stroke=None)
        a.poly(_ring(r0, z0, -45, 45) + _ring(r1, z1, 45, -45), ICE_BS[k % 3], stroke=None)
        a.line(_ring(r0, z0, -45, 135, 24), ICE_D, 1.0)
        a.line(_ring(r0, z0 + 0.8, -35, 125, 20), ICE_FL, 0.8, opacity=0.7)
        t = -45 + rng.uniform(4, 12) + (k % 2) * 12
        while t < 132:  # head joints, staggered
            a.line([P(r0 * math.cos(math.radians(t)), r0 * math.sin(math.radians(t)), z0), P(r1 * math.cos(math.radians(t)), r1 * math.sin(math.radians(t)), z1)], ICE_D, 0.8)
            t += rng.uniform(22, 34)
    r4, z4 = ring_at(bands - 1)
    a.poly(_ring(r4, z4, 0, 360, 36), SNOW, ICE_D, 1.0)  # the heap of snow on top
    x, y = P(0.0, 0.0, RZ)
    a.ellipse(x, y - 1.5, 8, 3.2, SNOW, ICE_D, 0.8)
    x, y = P(-0.05, -0.04, RZ + 1)  # the smoke hole and its breath
    a.ellipse(x, y - 1.5, 3.4, 1.6, ICE_DEEP)
    a.ellipse(x + 2, y - 9, 4.5, 6, "#dfeaf2", opacity=0.3)
    a.ellipse(x + 5, y - 19, 5.5, 7.5, "#dfeaf2", opacity=0.2)
    for t in (10, 55, 100, 125):  # icicles hanging from the courses
        for k in (1, 2):
            r0, z0 = ring_at(k)
            x, y = P(r0 * math.cos(math.radians(t)), r0 * math.sin(math.radians(t)), z0)
            if rng.random() < 0.7:
                ln = rng.uniform(3, 6)
                a.poly([(x - 1.2, y), (x + 1.2, y), (x, y + ln)], "#d6eef8", ICE_D, 0.6)
    # the entrance tunnel toward the front: a half-barrel of blocks
    tx0, tx1, ty0, ty1, th = -0.1, 0.1, 0.22, 0.46, 12
    a.box(tx0, tx1, ty0, ty1, 0, th, ICE_T, ICE_L, ICE_R, sw=1.2)
    _ice_face(a, rng, "front", ty1, tx0, tx1, 0, th, 2)
    _ice_face(a, rng, "side", tx1, ty0, ty1, 0, th, 2, side_shade=True)
    _opening(a, "front", ty1, -0.065, 0.065, 0, 8, ICE_DEEP, arch=3, sw=1)
    x, y = P(0, (ty0 + ty1) / 2, th)
    a.ellipse(x, y - 0.5, 10, 4.2, SNOW, ICE_D, 0.8)
    x, y = P(0, ty1, th)
    a.ellipse(x, y - 0.5, 8.5, 2.4, SNOW, opacity=0.97)
    _icicles(a, rng, "front", ty1, tx0, tx1, th, 4, 3, 7)
    a.save("ice_hut")


def village_pieces_materials():
    """The walls, gates and wall towers in wood, sandstone, basalt, limestone,
    granite and ice (stone's are wall(), gate(), wall_tower()); each tower's levels and
    front layer on one canvas."""
    for lvl in (1, 2, 3):
        wood_wall(lvl)
        wood_gate(lvl)
        sand_wall(lvl)
        sand_gate(lvl)
        bas_wall(lvl)
        bas_gate(lvl)
        lime_wall(lvl)
        lime_gate(lvl)
        gran_wall(lvl)
        gran_gate(lvl)
        ice_wall(lvl)
        ice_gate(lvl)
    wood_wall_ruin()
    wood_gate_ruin()
    wood_wall_tower_ruin()
    for ruin in (False, True):
        sand_hut(ruin)
        bas_hut(ruin)
        wood_hut(ruin)
        lime_hut(ruin)
        gran_hut(ruin)
        ice_hut(ruin)
    sand_wall_ruin()
    sand_gate_ruin()
    sand_wall_tower_ruin()
    bas_wall_ruin()
    bas_gate_ruin()
    bas_wall_tower_ruin()
    lime_wall_ruin()
    lime_gate_ruin()
    lime_wall_tower_ruin()
    gran_wall_ruin()
    gran_gate_ruin()
    gran_wall_tower_ruin()
    ice_wall_ruin()
    ice_gate_ruin()
    ice_wall_tower_ruin()
    for prefix, fn, deck in [("wood_", wood_wall_tower, WOOD_DECK), ("sandstone_", sand_wall_tower, 76), ("basalt_", bas_wall_tower, 76),
                             ("limestone_", lime_wall_tower, 76), ("granite_", gran_wall_tower, 76), ("ice_", ice_wall_tower, 76)]:
        for lvl in (1, 2, 3):
            suffix = "" if lvl == 1 else "_%d" % lvl
            wt = fn(level=lvl)
            wt.pts = fn(level=3).pts[:]
            wt.save(prefix + "wall_tower" + suffix, extra={"platform": deck + 2})
            wtf = fn(front=True, level=lvl)
            wtf.pts = wt.pts[:]
            wtf.save(prefix + "wall_tower_front" + suffix)


def rubble():
    """Heaps of stones and charred beams over a devastated building (scaled to its size)."""
    rng = random.Random(704)
    a = Art()
    a.poly(diamond(0.7, 0.36), "#221e1a", stroke=None, opacity=0.4)
    for (gx, gy, ln) in [(-0.3, 0.05, 0.5), (0.0, -0.25, 0.45), (0.15, 0.2, 0.4)]:
        a.line([P(gx, gy, 2), P(gx + ln * 0.8, gy + ln * 0.3, 9)], INK, 6)
        a.line([P(gx, gy, 2), P(gx + ln * 0.8, gy + ln * 0.3, 9)], "#2a1e15", 4)
        x, y = P(gx + ln * 0.8, gy + ln * 0.3, 9)
        a.ellipse(x, y, 2.4, 1.6, "#c04a1e", opacity=0.8)  # embers
    for _ in range(14):
        x, y = rand_in_diamond(rng, 0.7)
        _block(a, rng, x, y, rng.uniform(3, 6.5))
    for _ in range(3):
        x, y = rand_in_diamond(rng, 0.6)
        a.ellipse(x, y - 14, 6, 9, "#8a8580", opacity=0.25)  # smoke
    a.save("rubble")


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


def tent_small():
    """Brenna's travel tent by the road (scenario 1): a small canvas A-frame,
    a bedroll in front and the cold ring of a campfire."""
    a = Art()
    a.shadow(30, 14, cy=2)
    x0, x1, y0, y1, ridge = -0.22, 0.2, -0.2, 0.1, 28
    ym = (y0 + y1) / 2
    a.poly([P(x0, y0, 0), P(x1, y0, 0), P(x1, ym, ridge), P(x0, ym, ridge)], "#7a6a4e")
    a.poly([P(x1, y0, 0), P(x1, ym, ridge), P(x1, y1, 0)], "#5e523c")
    a.poly([P(x1, ym - 0.04, 0), P(x1, ym, ridge * 0.6), P(x1, ym + 0.04, 0)], "#221c14", stroke=None)  # opening
    a.poly([P(x0, ym, ridge), P(x1, ym, ridge), P(x1, y1, 0), P(x0, y1, 0)], "#968660")
    a.line([P(x0, ym, ridge), P(x1, ym, ridge)], "#4a4030", 1.8)
    a.line([P(x0 - 0.04, ym, ridge + 4), P(x0 - 0.04, ym, 0)], WOOD_D, 2)
    a.line([P(x1 + 0.04, ym, ridge + 4), P(x1 + 0.04, ym, 0)], WOOD_D, 2)
    a.line([P(x1 + 0.04, ym, ridge + 4), P(x1 + 0.2, ym + 0.02, 0)], "#5a5040", 0.8)  # guy line
    # bedroll, rolled up
    bx, by = P(0.3, 0.06)
    a.ellipse(bx, by - 3, 9, 3.6, CRIMSON_D, INK, 1.1)
    a.ellipse(bx + 8, by - 3, 2.6, 3.4, "#a03040", INK, 1)
    a.line([(bx - 3, by - 6.4), (bx - 3, by + 0.4)], "#3a2a1a", 1.4)
    # the cold campfire: a ring of stones, charred sticks, a wisp of smoke
    fx, fy = P(0.08, 0.36)
    for k in range(7):
        ang = k / 7 * math.tau
        a.ellipse(fx + math.cos(ang) * 8, fy + math.sin(ang) * 4, 2.4, 1.6, "#77736c", INK, 0.8)
    a.line([(fx - 5, fy + 1), (fx + 4, fy - 1)], "#2a2018", 2.2)
    a.line([(fx - 3, fy - 2), (fx + 5, fy + 2)], "#2a2018", 2.2)
    a.line([(fx, fy - 4), (fx - 2, fy - 12), (fx + 2, fy - 19)], "#9a9690", 1.6, opacity=0.5)
    # her pack against the pole
    px, py = P(x0 - 0.1, ym + 0.06)
    a.poly([(px - 4, py), (px + 4, py), (px + 3, py - 10), (px - 3, py - 10)], "#5a4630", INK, 1)
    a.line([(px - 3, py - 6), (px + 3, py - 6)], "#3a2a1a", 1)
    a.save("tent_small")


def portrait_svg(name, body, bg="#2a3240"):
    """A dialogue portrait (cutscenes): a bust in a round-cornered frame, 64x64 units."""
    with open(os.path.join(ART, name + ".svg"), "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 64 64">\n'
                '  <clipPath id="c"><rect x="3" y="3" width="58" height="58" rx="6"/></clipPath>\n'
                '  <rect x="1.5" y="1.5" width="61" height="61" rx="7" fill="%s" stroke="%s" stroke-width="3"/>\n'
                '  <g clip-path="url(#c)">%s\n  </g>\n'
                '  <rect x="3" y="3" width="58" height="58" rx="6" fill="none" stroke="%s" stroke-width="1.6"/>\n'
                '</svg>\n' % (bg, INK, body, GOLD_D))


def portraits():
    """The speakers of the scenarios' cutscenes (docs/story-design.md section 2)."""
    # Brenna Hale: a royal knight come home; dark hair tied back, a scar, a worn
    # blue-steel cuirass with a crimson cloak.
    portrait_svg("portrait_brenna", f'''
  <path d="M6 66 Q6 46 20 42 L44 42 Q58 46 58 66Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 66 Q14 48 24 45 L40 45 Q50 48 50 66Z" fill="#6a7a8e" stroke="{INK}" stroke-width="2.2"/>
  <path d="M32 46 L32 66" stroke="#4a5666" stroke-width="1.6"/>
  <path d="M16 50 Q12 44 20 42 L24 46 Z" fill="#8a96a6" stroke="{INK}" stroke-width="1.6"/>
  <path d="M48 50 Q52 44 44 42 L40 46 Z" fill="#8a96a6" stroke="{INK}" stroke-width="1.6"/>
  <rect x="27" y="35" width="10" height="9" fill="#c9a07c" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 24 Q19 10 32 9 Q45 10 44 24 Q44 36 32 39 Q20 36 20 24Z" fill="#d6ad86" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 25 Q16 8 32 6 Q48 7 45 24 Q44 15 36 13 Q28 15 21 14 Q20 19 19 25Z" fill="#3a2a20" stroke="{INK}" stroke-width="2"/>
  <path d="M44 16 Q52 22 49 34 Q47 28 44 26Z" fill="#3a2a20" stroke="{INK}" stroke-width="1.8"/>
  <circle cx="49" cy="25" r="1.6" fill="{CRIMSON}"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#2a1e16" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.5" fill="{INK}"/><circle cx="37" cy="26" r="1.5" fill="{INK}"/>
  <path d="M31.5 27 L30.5 31 L33 31" fill="none" stroke="#9a7458" stroke-width="1.2"/>
  <path d="M28.5 34 Q32 35.4 35.5 34" fill="none" stroke="#7a4a3a" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M39 20 L42 29" stroke="#b07a6a" stroke-width="1.1"/>''', bg="#28323e")
    # Einar: Brenna's father, the village's lumberjack; grey beard, green cap,
    # red check shirt, the axe haft over his shoulder.
    portrait_svg("portrait_einar", f'''
  <path d="M50 66 L60 8" stroke="{INK}" stroke-width="5"/>
  <path d="M50 66 L60 8" stroke="{WOOD_L}" stroke-width="3"/>
  <path d="M54 8 L66 6 L66 18 L57 16Z" fill="#9a9a9a" stroke="{INK}" stroke-width="1.8"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#7a3a2a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 50 L50 50 M12 57 L52 57 M24 44 L22 66 M40 44 L42 66" stroke="#5a2a1e" stroke-width="1.6"/>
  <rect x="27" y="35" width="10" height="9" fill="#c99a78" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 24 Q19 11 32 10 Q45 11 44 24 Q44 35 32 38 Q20 35 20 24Z" fill="#d0a07c" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 26 Q21 44 32 46 Q43 44 44 26 Q40 32 32 32 Q24 32 20 26Z" fill="#b8b2a6" stroke="{INK}" stroke-width="2"/>
  <path d="M27 31 Q32 29 37 31" fill="none" stroke="#8a847a" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M17 18 Q18 5 32 5 Q46 5 47 18Z" fill="#3a4a2a" stroke="{INK}" stroke-width="2.2"/>
  <path d="M15 18 L49 18" stroke="{INK}" stroke-width="3"/>
  <path d="M24 22 L29 23 M35 23 L40 22" stroke="#9a948a" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="27" cy="25.5" r="1.4" fill="{INK}"/><circle cx="37" cy="25.5" r="1.4" fill="{INK}"/>
  <path d="M24 28 Q27 29 29 28 M35 28 Q37 29 40 28" fill="none" stroke="#a87858" stroke-width="0.9"/>''', bg="#2c3428")
    # Pell Dunmore: a travelling merchant; a wide-brimmed hat, a brown coat with
    # a gold-trimmed collar, a short beard and a lantern's warm light.
    portrait_svg("portrait_pell", f'''
  <circle cx="54" cy="44" r="16" fill="{GLOW}" opacity="0.25"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#5a4630" stroke="{INK}" stroke-width="2.4"/>
  <path d="M22 43 L32 56 L42 43" fill="none" stroke="{GOLD}" stroke-width="2.4"/>
  <path d="M32 56 L32 66" stroke="#3a2c1e" stroke-width="1.6"/>
  <circle cx="32" cy="60" r="1.4" fill="{GOLD}"/>
  <rect x="27" y="35" width="10" height="9" fill="#c99a78" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#cfa07c" stroke="{INK}" stroke-width="2.2"/>
  <path d="M22 29 Q24 39 32 40 Q40 39 42 29 Q38 34 32 34 Q26 34 22 29Z" fill="#6a4a30" stroke="{INK}" stroke-width="1.6"/>
  <path d="M27 31.5 Q32 30 37 31.5" fill="none" stroke="#4a3220" stroke-width="2" stroke-linecap="round"/>
  <path d="M8 18 Q32 10 56 18 Q44 21 32 21 Q20 21 8 18Z" fill="#3a2e22" stroke="{INK}" stroke-width="2"/>
  <path d="M20 17 Q21 4 32 4 Q43 4 44 17Z" fill="#4a3a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M20.5 14 L43.5 14" stroke="{CRIMSON}" stroke-width="2.4"/>
  <circle cx="27" cy="25.5" r="1.4" fill="{INK}"/><circle cx="37" cy="25.5" r="1.4" fill="{INK}"/>
  <path d="M24 22.5 L29 22 M35 22 L40 22.5" stroke="#3a2a1a" stroke-width="1.5" stroke-linecap="round"/>
  <path d="M50 46 L58 46 L57 58 L51 58Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.6" opacity="0.95"/>
  <circle cx="54" cy="52" r="2.6" fill="#fff4c0"/>''', bg="#33291f")


def portraits_away():
    """The speakers of scenarios 4 and 5 (docs/story-design.md section 2)."""
    # Wenna: the Silver Thread Guild's master; grey hair in a bun, a dark-blue coat,
    # a gold chain of office, a sharp look over half-moon spectacles.
    portrait_svg("portrait_wenna", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#2f3e5a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M20 46 Q32 58 44 46" fill="none" stroke="{GOLD}" stroke-width="2.4"/>
  <circle cx="32" cy="55" r="3" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>
  <rect x="27" y="35" width="10" height="9" fill="#d0a684" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#d8ae8a" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 26 Q16 9 32 8 Q48 9 45 26 Q44 16 32 15 Q22 16 19 26Z" fill="#9a958c" stroke="{INK}" stroke-width="2"/>
  <circle cx="32" cy="7" r="6" fill="#9a958c" stroke="{INK}" stroke-width="2"/>
  <path d="M23 26 Q27 24 30 26 M34 26 Q37 24 41 26" fill="none" stroke="#8a6a40" stroke-width="1.6"/>
  <path d="M23 27 L30 27 M34 27 L41 27" stroke="{GOLD_D}" stroke-width="1"/>
  <circle cx="27" cy="25.5" r="1.3" fill="{INK}"/><circle cx="37" cy="25.5" r="1.3" fill="{INK}"/>
  <path d="M28.5 33.5 Q32 33 35.5 33.5" fill="none" stroke="#7a4a3a" stroke-width="1.4" stroke-linecap="round"/>""", bg="#262f3c")
    # Sigmund: the old veteran at Brenna's fort; bald, a white beard, a patch
    # over one eye, worn mail under a brown jerkin.
    portrait_svg("portrait_sigmund", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#7a7e86" stroke="{INK}" stroke-width="2.4"/>
  <path d="M12 52 L52 52 M10 58 L54 58 M14 47 L50 47" stroke="#5a5e66" stroke-width="1.4" stroke-dasharray="2 2"/>
  <path d="M20 66 L22 46 L42 46 L44 66Z" fill="#5a4630" stroke="{INK}" stroke-width="2"/>
  <rect x="27" y="35" width="10" height="9" fill="#c49474" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 23 Q19 9 32 9 Q45 9 44 23 Q44 35 32 38 Q20 35 20 23Z" fill="#cc9c78" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 25 Q20 45 32 48 Q44 45 44 25 Q40 32 32 32 Q24 32 20 25Z" fill="#e8e4dc" stroke="{INK}" stroke-width="2"/>
  <path d="M26 31 Q32 29 38 31" fill="none" stroke="#c8c4bc" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M19 19 L45 27" stroke="{INK}" stroke-width="1.8"/>
  <ellipse cx="37" cy="24.5" rx="4" ry="3.4" fill="#2a221c" stroke="{INK}" stroke-width="1.4"/>
  <circle cx="27" cy="25" r="1.4" fill="{INK}"/>
  <path d="M24 21.5 L29 21" stroke="#e8e4dc" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M23 14 Q26 12 29 14" fill="none" stroke="#b0805e" stroke-width="1"/>""", bg="#2e2a26")
    # Lysa: Brenna's old captain, bound to Rhodri; a pale face, empty pale
    # eyes, a captain's helm with a crimson plume, a dark-red braid.
    portrait_svg("portrait_lysa", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#2a2a30" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 66 Q14 48 24 45 L40 45 Q50 48 50 66Z" fill="#5a4448" stroke="{INK}" stroke-width="2.2"/>
  <path d="M18 50 L46 50" stroke="{GOLD_D}" stroke-width="2"/>
  <path d="M18 30 Q10 40 14 56 Q18 46 21 36Z" fill="#6a2a20" stroke="{INK}" stroke-width="1.8"/>
  <rect x="27" y="35" width="10" height="9" fill="#bcc0c4" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#c8cccf" stroke="{INK}" stroke-width="2.2"/>
  <path d="M18 24 Q17 6 32 5 Q47 6 46 24 L42 24 L42 18 Q32 15 22 18 L22 24Z" fill="#8a8e96" stroke="{INK}" stroke-width="2.2"/>
  <path d="M31 18 L31 27 L33 27 L33 18Z" fill="#6a6e76" stroke="{INK}" stroke-width="1.2"/>
  <path d="M38 7 Q50 2 58 14 Q52 10 44 12Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.8"/>
  <ellipse cx="27" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <ellipse cx="37" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <path d="M28.5 33.5 L35.5 33.5" stroke="#7a7e86" stroke-width="1.4" stroke-linecap="round"/>""", bg="#22242a")
    # A rival guild's master: a fur collar, a heavy gold ring, a trimmed beard
    # and a smile that doesn't reach the eyes.
    portrait_svg("portrait_rival", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#4a2a3a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 50 Q20 40 32 46 Q44 40 54 50 Q50 56 44 52 Q38 56 32 52 Q26 56 20 52 Q14 56 10 50Z" fill="#8a7458" stroke="{INK}" stroke-width="1.8"/>
  <rect x="27" y="35" width="10" height="9" fill="#d0a080" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#d8a882" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 22 Q17 7 32 7 Q47 7 45 22 Q42 13 32 13 Q22 13 19 22Z" fill="#1e1a18" stroke="{INK}" stroke-width="2"/>
  <path d="M26 33 Q32 41 38 33 Q35 38 32 38 Q29 38 26 33Z" fill="#1e1a18" stroke="{INK}" stroke-width="1.4"/>
  <path d="M26 31 Q32 33.5 38 31" fill="none" stroke="#6a3a2a" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M24 23 L29 24 M35 24 L40 23" stroke="#1e1a18" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.4" fill="{INK}"/><circle cx="37" cy="26" r="1.4" fill="{INK}"/>
  <circle cx="50" cy="60" r="3.2" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>""", bg="#2e2230")


def campaign_icon():
    """The title screen's Campaign button: a crimson banner on a pole with a gold tower."""
    icon_svg("icon_campaign", f'''
  <path d="M14 4 L14 62" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M14 4 L14 62" stroke="{WOOD_L}" stroke-width="3" stroke-linecap="round"/>
  <circle cx="14" cy="5" r="4" fill="{GOLD}" stroke="{INK}" stroke-width="2"/>
  <path d="M16 10 L56 10 L56 44 L36 36 L16 44Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M28 32 L28 20 L31 20 L31 23 L34 23 L34 20 L38 20 L38 23 L41 23 L41 20 L44 20 L44 32Z" fill="{GOLD}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M34.5 32 L34.5 28 Q36 26 37.5 28 L37.5 32Z" fill="{INK}"/>''')


def _awning_stall(a, cx, cy, w, d, colours):
    """A market booth at grid offset (cx, cy): a counter with goods and a
    striped awning on four posts."""
    x0, x1, y0, y1 = cx - w, cx + w, cy - d, cy + d
    for (gx, gy) in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]:  # posts
        px, py = P(gx, gy, 0)
        a.line([(px, py), (px, py - 30)], WOOD_D, 2.2)
    a.box(x0, x1, y0 + 0.05, y1, 0, 10, WOOD_L, WOOD, WOOD_D)  # counter
    # goods on the counter: sacks, a bolt of cloth, jars
    for i, (gx, col) in enumerate([(x0 + 0.08, "#c9a86a"), (cx, "#7a3a5a"), (x1 - 0.1, "#b8955a")]):
        gxp, gyp = P(gx, cy, 10)
        if i == 1:
            a.poly([(gxp - 6, gyp), (gxp + 6, gyp), (gxp + 5, gyp - 5), (gxp - 5, gyp - 5)], col, INK, 0.8)
        else:
            a.ellipse(gxp, gyp - 3, 4.5, 3.5, col, INK, 0.8)
    # the awning: stripes from back to front
    n = 6
    for i in range(n):
        u0, u1 = x0 - 0.03 + (x1 - x0 + 0.06) * i / n, x0 - 0.03 + (x1 - x0 + 0.06) * (i + 1) / n
        col = colours[i % 2]
        a.poly([P(u0, y0 - 0.04, 30), P(u1, y0 - 0.04, 30), P(u1, y1 + 0.08, 22), P(u0, y1 + 0.08, 22)], col, INK, 0.8)
    a.line([P(x0 - 0.03, y1 + 0.08, 22), P(x1 + 0.03, y1 + 0.08, 22)], INK, 1.2)


def stall(level):
    """The merchant's 2x2 stall: level 1-2 a booth with a striped awning, crates
    and Pell's cart behind it; level 3 (guild market) two booths and a banner."""
    a = Art()
    s = 0.98
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], DIRT, INK, 1.0, opacity=0.85)
    # crates and barrels about the yard
    for (gx, gy) in [(-0.75, 0.55), (-0.55, 0.75)]:
        a.box(gx - 0.1, gx + 0.1, gy - 0.1, gy + 0.1, 0, 9, "#b08a58", WOOD, WOOD_D, sw=1)
    bx, by = P(0.75, 0.6, 0)
    a.poly([(bx - 5, by), (bx + 5, by), (bx + 6, by - 12), (bx - 6, by - 12)], WOOD, INK, 1)
    a.line([(bx - 5.5, by - 4), (bx + 5.5, by - 4)], "#6a6a6a", 1.1)
    a.ellipse(bx, by - 12, 6, 2.2, WOOD_D, INK, 0.8)
    if level >= 3:
        _awning_stall(a, -0.35, -0.35, 0.4, 0.22, [CRIMSON, "#e8dcc0"])
        _awning_stall(a, 0.4, 0.15, 0.3, 0.2, ["#2f5a7a", "#e8dcc0"])
        px, py = P(0.85, -0.85, 0)
        a.line([(px, py), (px, py - 52)], WOOD_D, 2.4)
        a.poly([(px, py - 52), (px + 18, py - 47), (px, py - 40)], GOLD, INK, 1)
        a.save("stall_3")
        return
    # Pell's cart parked at the back
    cx, cy = P(-0.55, -0.55, 0)
    a.poly([(cx - 16, cy - 8), (cx + 12, cy - 14), (cx + 14, cy - 22), (cx - 14, cy - 16)], WOOD, INK, 1.2)
    a.ellipse(cx - 6, cy - 4, 6, 6, WOOD_D, INK, 1.2)
    a.ellipse(cx - 6, cy - 4, 1.8, 1.8, "#3a2a1a")
    a.ellipse(cx - 2, cy - 22, 6, 4.5, "#c9a86a", INK, 1)
    a.ellipse(cx + 6, cy - 24, 5, 4, "#b8955a", INK, 1)
    _awning_stall(a, 0.25, 0.1, 0.45, 0.25, [CRIMSON, "#e8dcc0"])
    a.save("stall")


def merchant():
    """Pell: a wide-brimmed hat, a long brown coat, a lantern."""
    def extra(a, layer):
        if layer == "front":
            a.poly([(-7, -12), (7, -12), (6, -27), (-6, -27)], "#5a4630", INK, 1)  # coat
            a.line([(-1, -26), (-3, -12)], GOLD, 1.2)
            a.line([(5, -21), (10, -16)], INK, 3.6)  # arm
            a.line([(10, -16), (10, -12)], INK, 1)
            a.poly([(8, -12), (12, -12), (11.5, -5), (8.5, -5)], GOLD, INK, 1)  # lantern
            a.ellipse(10, -8.5, 1.5, 2, "#fff4c0")

    def hat(a):
        a.raw('<path d="M-11,-36 Q0,-40 11,-36 Q6,-34 0,-34 Q-6,-34 -11,-36Z" fill="#3a2e22" stroke="%s" stroke-width="1.2"/>' % INK, [(-12, -41), (12, -33)])
        a.raw('<path d="M-6,-36 Q-5,-44 0,-44 Q5,-44 6,-36Z" fill="#4a3a2a" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -45), (7, -35)])
        a.line([(-5.5, -37.5), (5.5, -37.5)], CRIMSON, 1.6)
        a.raw('<path d="M-4,-29 Q0,-25 4,-29 Q3,-27 0,-26.5 Q-3,-27 -4,-29Z" fill="#6a4a30"/>', [(-4, -30), (4, -26)])  # beard
    person("unit_merchant", ("#5a4630", "#46361f"), hat=hat, extra=extra)


def barracks_ruin():
    """A ruined 2x2 barracks of the old Wardline: a broken fence, the burnt
    shell of its hut, a fallen bench and rubble."""
    a = Art()
    s = 0.98
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#5e5040", INK, 1.0, opacity=0.85)
    for t in [i / 6 for i in range(7)]:  # what's left of the fence
        if t in (2 / 6, 3 / 6, 5 / 6):
            continue
        for p in (P(-s + 2 * s * t, s), P(s, s - 2 * s * t)):
            a.line([p, (p[0], p[1] - 4 - 5 * ((t * 7) % 1))], WOOD_D, 2.2)
    hx, hy, w = -0.6, -0.6, 0.33
    a.box(hx - w, hx + w, hy - 0.22, hy + 0.22, 0, 11, "#5a4e40", "#5a4e40", "#463c30")
    a.poly([P(hx - w, hy + 0.22, 11), P(hx - 0.1, hy + 0.22, 17), P(hx + w, hy + 0.22, 9), P(hx + w, hy + 0.22, 11)], "#463c30", INK, 1)
    for (gx, gy, z) in [(hx - 0.1, hy, 11), (hx + 0.15, hy + 0.05, 11)]:  # charred beams
        x, y = P(gx, gy, z)
        a.line([(x - 9, y + 2), (x + 8, y - 6)], "#2a2018", 2.6)
    a.box(0.25, 0.65, 0.3, 0.4, 0, 3, WOOD, WOOD_D, WOOD_D)  # a fallen bench
    for (gx, gy) in [(0.5, -0.4), (0.62, -0.3), (-0.1, 0.5), (0.0, 0.62)]:  # rubble
        x, y = P(gx, gy, 0)
        a.ellipse(x, y - 2, 4, 2.6, "#77736c", INK, 0.8)
    px, py = P(0.6, -0.6, 0)  # a torn banner pole
    a.line([(px, py), (px + 3, py - 28)], WOOD_D, 2)
    a.poly([(px + 3, py - 28), (px + 12, py - 25), (px + 6, py - 22), (px + 9, py - 19), (px + 2, py - 18)], CRIMSON_D, INK, 0.8)
    a.save("barracks_ruin")


def warehouse():
    """The guild's 2x2 warehouse (scenario 4): a long timber-and-stone store
    with a slate roof, a wide loading door, a hoist beam, the Silver Thread Guild's
    sign (gold scales on blue) and crates and sacks in its yard."""
    a = Art()
    s = 0.98
    a.shadow(90, 45, cy=6)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], DIRT, INK, 1.0, opacity=0.85)
    x0, x1, y0, y1, h, ridge = -0.8, 0.55, -0.55, 0.25, 34, 66
    a.box(x0, x1, y0, y1, 0, 12, STONE_T, STONE_L, STONE_R)  # stone footing
    a.box(x0, x1, y0, y1, 12, h, "#8c7b62", "#8c7b62", "#6c5e4a")
    for t in (0.0, 0.25, 0.5, 0.75, 1.0):  # timber framing
        gx = x0 + (x1 - x0) * t
        a.line([P(gx, y1, 12), P(gx, y1, h)], "#3b2a1d", 2)
    a.line([P(x0, y1, 23), P(x1, y1, 23)], "#3b2a1d", 1.6)
    # the loading door (open, dark) and its frame
    a.poly([P(-0.32, y1, 0), P(0.02, y1, 0), P(0.02, y1, 24), P(-0.32, y1, 24)], "#22180f", INK, 1.2)
    a.line([P(-0.15, y1, 0), P(-0.15, y1, 24)], "#3b2a1d", 1.2)
    # slate roof along x
    ym = (y0 + y1) / 2
    ey, ex = 0.08, 0.04
    slope = (ridge - h) / (y1 - ym)
    eave_h = h - slope * ey
    xa, xb = x0 - ex, x1 + ex
    a.poly([P(xa, y0 - ey, eave_h), P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xa, ym, ridge)], "#2e3a44")
    a.poly([P(x1, y0, h), P(x1, ym, ridge), P(x1, y1, h)], "#7a6a52")
    a.poly([P(xa, ym, ridge), P(xb, ym, ridge), P(xb, y1 + ey, eave_h), P(xa, y1 + ey, eave_h)], "#3e4c58")
    for t in (0.25, 0.5, 0.75):
        yy = ym + (y1 + ey - ym) * t
        zz = ridge - (ridge - eave_h) * t
        a.line([P(xa, yy, zz), P(xb, yy, zz)], "#2a343c", 1.2)
    a.line([P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xb, y1 + ey, eave_h)], "#3b2a1d", 3.2)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], "#3b2a1d", 2.4)
    # hoist beam over the door with a rope and a sack
    bx, by = P(-0.15, y1 + 0.02, h + 6)
    a.line([(bx, by), (bx - 10, by + 12)], WOOD_D, 3)
    a.line([(bx - 10, by + 12), (bx - 10, by + 30)], "#c8b080", 1)
    a.ellipse(bx - 10, by + 34, 4.5, 4, "#c9a86a", INK, 0.9)
    # the guild's sign on the gable: gold scales on blue
    sx, sy = P(x1, -0.15, h - 4)
    a.poly([(sx - 2, sy - 10), (sx + 12, sy - 15), (sx + 12, sy - 1), (sx - 2, sy + 4)], "#2f4a6a", INK, 1)
    a.line([(sx + 5, sy - 10), (sx + 5, sy - 1)], GOLD, 1.4)
    a.line([(sx + 1, sy - 6), (sx + 9, sy - 9)], GOLD, 1.4)
    a.ellipse(sx + 1.5, sy - 3.5, 2, 1, GOLD)
    a.ellipse(sx + 9, sy - 6.5, 2, 1, GOLD)
    # crates, barrels and sacks in the yard
    for (gx, gy) in [(0.7, 0.55), (0.82, 0.3), (0.45, 0.75)]:
        a.box(gx - 0.1, gx + 0.1, gy - 0.1, gy + 0.1, 0, 10, "#b08a58", WOOD, WOOD_D, sw=1)
    a.box(0.7, 0.8, 0.45, 0.55, 10, 19, "#b08a58", WOOD, WOOD_D, sw=1)
    for (gx, gy) in [(-0.6, 0.65), (-0.4, 0.8)]:
        x, y = P(gx, gy, 0)
        a.poly([(x - 5, y), (x + 5, y), (x + 6, y - 12), (x - 6, y - 12)], WOOD, INK, 1)
        a.line([(x - 5.5, y - 4), (x + 5.5, y - 4)], "#6a6a6a", 1.1)
        a.ellipse(x, y - 12, 6, 2.2, WOOD_D, INK, 0.8)
    for (gx, gy) in [(0.1, 0.7), (0.22, 0.62)]:
        x, y = P(gx, gy, 0)
        a.ellipse(x, y - 4, 5, 4.2, "#c9a86a", INK, 0.9)
    a.save("warehouse")


def guild_house():
    """Wenna's house in the guild town (scenario 4): a hut's lot, but a
    taller stone-and-timber house with a slate roof and the guild's sign."""
    a = Art()
    x0, x1, y0, y1 = -0.34, 0.34, -0.3, 0.3
    a.shadow(44, 22, cy=4)
    h, ridge = 36, 62
    a.box(x0, x1, y0, y1, 0, 14, STONE_T, STONE_L, STONE_R)
    a.box(x0, x1, y0, y1, 14, h, "#9a8a6e", "#9a8a6e", "#76674f")
    for t in (0.0, 0.5, 1.0):
        gx = x0 + (x1 - x0) * t
        a.line([P(gx, y1, 14), P(gx, y1, h)], "#3b2a1d", 2)
    a.poly([P(-0.08, y1, 0), P(0.08, y1, 0), P(0.08, y1, 17), P(-0.08, y1, 17)], "#2b1e14")
    a.poly([P(x1, 0.15, 20), P(x1, -0.05, 20), P(x1, -0.05, 29), P(x1, 0.15, 29)], GLOW)
    a.poly([P(x1, 0.15, 4), P(x1, -0.05, 4), P(x1, -0.05, 11), P(x1, 0.15, 11)], GLOW)
    ym = (y0 + y1) / 2
    ey, ex = 0.07, 0.03
    slope = (ridge - h) / (y1 - ym)
    eave_h = h - slope * ey
    xa, xb = x0 - ex, x1 + ex
    a.poly([P(xa, y0 - ey, eave_h), P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xa, ym, ridge)], "#2e3a44")
    a.poly([P(x1, y0, h), P(x1, ym, ridge), P(x1, y1, h)], "#8a7a5e")
    a.poly([P(xa, ym, ridge), P(xb, ym, ridge), P(xb, y1 + ey, eave_h), P(xa, y1 + ey, eave_h)], "#3e4c58")
    a.line([P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xb, y1 + ey, eave_h)], "#3b2a1d", 3.2)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], "#3b2a1d", 2.4)
    # the guild's sign over the door
    sx, sy = P(0.0, y1 + 0.02, 22)
    a.line([(sx - 2, sy), (sx + 10, sy - 4)], WOOD_D, 2)
    a.poly([(sx + 4, sy - 2), (sx + 13, sy - 5), (sx + 13, sy + 5), (sx + 4, sy + 8)], "#2f4a6a", INK, 0.9)
    a.line([(sx + 8.5, sy - 2), (sx + 8.5, sy + 5)], GOLD, 1.2)
    a.line([(sx + 5.5, sy + 1), (sx + 11.5, sy - 1)], GOLD, 1.2)
    # chimney
    a.box(0.14, 0.24, -0.1, 0.0, ridge - 14, ridge + 8, STONE_T, STONE_L, STONE_R)
    a.save("guild_house")


def guild_master():
    """Wenna: a long dark-blue robe, a gold chain of office, the guild's ledger."""
    def extra(a, layer):
        if layer == "front":
            a.line([(-4, -26), (0, -20), (4, -26)], GOLD, 1.4)  # chain
            a.ellipse(0, -20, 1.6, 1.6, GOLD, INK, 0.6)
            a.poly([(3, -20), (11, -21), (11, -13), (3, -12)], "#6a2a24", INK, 1)  # ledger
            a.line([(4, -16.5), (10, -17)], "#e8dcc0", 0.8)

    def hat(a):
        a.raw('<path d="M-6,-34 Q-7,-42 0,-41 Q6,-42 6,-35 Q4,-39 0,-39 Q-4,-39 -6,-34Z" fill="#8a8478" stroke="%s" stroke-width="1.1"/>' % INK, [(-7, -43), (7, -33)])
        a.ellipse(-4, -40, 3, 2.6, "#8a8478", INK, 1)  # the bun
    person("unit_guildmaster", ("#2f3e5a", "#243048"), hat=hat, skin="#d8b08c", robe=True, extra=extra)


def corpse_fallen(name, tabard, tabard_d):
    """One of the battlefield's fallen (scenario 6): dried out on the dry plain,
    a dented helm, a faded tabard in the colours of the side he fell for (Fiona's
    blue, Rhodri's crimson), bony hands, a broken spear."""
    a = Art()
    a.ellipse(0, 0, 21, 7, "#000", opacity=0.3)
    a.line([(-20, 7), (14, -9)], INK, 3.2)  # broken spear
    a.line([(-20, 7), (14, -9)], WOOD_L, 1.6)
    a.poly([(14, -9), (19, -12), (16, -7)], "#9a9a9a", INK, 0.8)
    a.poly([(-13, 1), (6, -6), (11, 1), (-8, 7)], tabard, INK, 1.2)  # body in the tabard
    a.poly([(-3, -2), (8, -5), (11, 1), (0, 4)], tabard_d, stroke=None)
    a.line([(-6, -1), (4, 3)], GOLD_D, 1.2)
    for (x0, y0, x1, y1) in [(-13, 2, -21, 0), (-9, 6, -16, 9), (2, -5, -2, -11)]:  # bony limbs
        a.line([(x0, y0), (x1, y1)], INK, 3.0)
        a.line([(x0, y0), (x1, y1)], BONE_D, 1.6)
        a.ellipse(x1, y1, 1.6, 1.2, BONE, INK, 0.7)
    a.ellipse(13, -2, 5.2, 4.6, BONE, INK, 1.1)  # skull
    a.ellipse(11.8, -2.4, 1.3, 1.4, "#1a1612")
    a.ellipse(14.4, -2.4, 1.3, 1.4, "#1a1612")
    a.poly([(8, -4), (11, -9), (17, -9), (19, -4)], "#7a7e86", INK, 1.1)  # dented helm
    a.line([(10, -6.5), (18, -6.5)], "#5a5e66", 0.9)
    a.save(name)


def graveyard():
    """The battlefield's graveyard (scenario 6, 3x3, flat: under walking units):
    trodden earth inside a low stone wall, a lychgate on the near side, old
    crosses along the back, and a fresh grave with a spade in the heap."""
    rng = random.Random(606)
    a = Art()
    s = 1.45
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#6e5a3e", None)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], DIRT_LIGHT, INK, 1.2, opacity=0.85)
    for _ in range(40):  # tufts of dry grass
        gx, gy = rng.uniform(-s, s), rng.uniform(-s, s)
        x, y = P(gx, gy)
        a.line([(x - 1.5, y), (x, y - 3), (x + 1.5, y)], "#8a8450", 0.8, opacity=0.7)
    # the low wall, back edges first, then the near ones with a gap for the gate
    def wall(p0, p1, gap=None):
        steps = 9
        for k in range(steps):
            t0, t1 = k / steps, (k + 1) / steps
            if gap and gap[0] <= t0 < gap[1]:
                continue
            q0 = (p0[0] + (p1[0] - p0[0]) * t0, p0[1] + (p1[1] - p0[1]) * t0)
            q1 = (p0[0] + (p1[0] - p0[0]) * t1, p0[1] + (p1[1] - p0[1]) * t1)
            x0, y0 = P(*q0)
            x1, y1 = P(*q1)
            a.poly([(x0, y0), (x1, y1), (x1, y1 - 5), (x0, y0 - 5)], STONE_L, INK, 0.9)
            a.line([(x0, y0 - 5), (x1, y1 - 5)], STONE_T, 1.2)
    wall((-s, -s), (s, -s))
    wall((-s, -s), (-s, s))
    # old crosses along the back
    for k in range(5):
        gx, gy = -1.1 + 0.55 * k, -1.2
        x, y = P(gx, gy)
        a.line([(x, y), (x, y - 13)], INK, 2.8)
        a.line([(x, y), (x, y - 13)], "#8a7a62", 1.4)
        a.line([(x - 4, y - 9), (x + 4, y - 9)], INK, 2.6)
        a.line([(x - 4, y - 9), (x + 4, y - 9)], "#8a7a62", 1.2)
        a.ellipse(x, y + 1, 5, 2, "#5a4a32", opacity=0.6)
    # a fresh grave and its heap, a spade stuck in it
    x, y = P(0.75, 0.55)
    a.poly([(x - 9, y - 1), (x + 3, y - 6), (x + 9, y - 3), (x - 3, y + 2)], "#2a2016", INK, 1)
    a.ellipse(x + 10, y + 3, 7, 3.4, DIRT_DARK, INK, 0.9)
    a.line([(x + 12, y + 2), (x + 15, y - 14)], WOOD_D, 1.8)
    a.poly([(x + 10.5, y + 3), (x + 14, y + 3.5), (x + 13.5, y - 1), (x + 11, y - 1.5)], "#9a9a9a", INK, 0.8)
    wall((s, -s), (s, s))
    wall((-s, s), (s, s), gap=(0.4, 0.6))
    # the lychgate: two posts and a little roof over the gap
    for t in (0.4, 0.6):
        x, y = P(-s + 2 * s * t, s)
        a.line([(x, y), (x, y - 18)], INK, 3.2)
        a.line([(x, y), (x, y - 18)], WOOD, 1.8)
    xa, ya = P(-s + 2 * s * 0.38, s)
    xb, yb = P(-s + 2 * s * 0.62, s)
    a.poly([(xa - 2, ya - 17), (xb + 2, yb - 17), ((xa + xb) / 2, (ya + yb) / 2 - 26)], "#4a3b24", INK, 1)
    a.save("graveyard")


def grave_mound():
    """One buried soldier: a heap of dry earth and a plain wooden cross."""
    a = Art()
    a.ellipse(0, 0, 9, 3.6, "#000", opacity=0.25)
    a.ellipse(0, -1, 8, 3.2, DIRT, INK, 0.9)
    a.ellipse(-1, -2, 5, 1.6, DIRT_LIGHT, opacity=0.7)
    a.line([(4, -1), (4, -12)], INK, 2.4)
    a.line([(4, -1), (4, -12)], WOOD_L, 1.2)
    a.line([(1, -9), (7, -9)], INK, 2.2)
    a.line([(1, -9), (7, -9)], WOOD_L, 1.0)
    a.save("grave_mound")


def grave_cross():
    """The cross Anselm plants over the last grave of the day (scenario 6's
    outro): a fresh mound and a tall cross of two lashed planks."""
    a = Art()
    a.ellipse(0, 0, 12, 4.6, "#000", opacity=0.25)
    a.ellipse(0, -1, 11, 4.2, DIRT, INK, 0.9)
    a.ellipse(-2, -2.4, 6, 2, DIRT_LIGHT, opacity=0.7)
    a.line([(0, -1), (0, -30)], INK, 4.2)
    a.line([(0, -1), (0, -30)], WOOD_L, 2.4)
    a.line([(-7, -22), (7, -22)], INK, 3.8)
    a.line([(-7, -22), (7, -22)], WOOD_L, 2.0)
    a.line([(-1.6, -23.6), (1.6, -20.4)], INK, 1.0)
    a.line([(-1.6, -20.4), (1.6, -23.6)], INK, 1.0)
    a.save("grave_cross")


def grove():
    """The druids' grove by their stone circle (scenario 7, 2x2): moss and
    ferns inside a ring of small standing stones, an old crooked oak at the
    back, three log seats (the game seats the druids on them), a green fire."""
    rng = random.Random(707)
    a = Art()
    s = 0.98
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#3e5a2c", None)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#4d6a34", INK, 1.2, opacity=0.9)
    for _ in range(26):
        gx, gy = rng.uniform(-s, s), rng.uniform(-s, s)
        x, y = P(gx, gy)
        a.line([(x - 2, y), (x - 1, y - 4), (x, y)], "#6a8a44", 1, opacity=0.8)

    def stone(gx, gy, h):
        x, y = P(gx, gy)
        a.poly([(x - 3, y), (x - 2.4, y - h), (x + 0.5, y - h - 2), (x + 3, y - h + 1), (x + 3, y)], "#77736c", INK, 1)
        a.ellipse(x, y, 3.6, 1.4, "#3a5028", opacity=0.8)
    ring = []
    for k in range(10):
        ang = k * math.tau / 10
        ring.append((math.cos(ang) * 0.9, math.sin(ang) * 0.9))
    back = [p for p in ring if p[0] + p[1] < 0]
    front = [p for p in ring if p[0] + p[1] >= 0]
    for (gx, gy) in back:
        stone(gx, gy, 9)
    # the old oak at the back
    x, y = P(-0.55, -0.55)
    a.poly([(x - 5, y), (x - 3, y - 26), (x - 9, y - 36), (x + 1, y - 30), (x + 6, y - 38), (x + 4, y - 24), (x + 5, y)], WOOD_D, INK, 1.2)
    for (dx, dy, r) in [(-10, -44, 13), (6, -46, 14), (-2, -54, 13), (12, -38, 9), (-14, -34, 9)]:
        a.ellipse(x + dx, y + dy, r, r * 0.8, "#2e4a24", INK, 1.1)
        a.ellipse(x + dx - 2, y + dy - 2, r * 0.6, r * 0.45, "#456a30", opacity=0.8)
    a.ellipse(x + 4, y - 44, 2.2, 2.2, "#e8f0c8")  # mistletoe
    a.ellipse(x - 6, y - 50, 1.8, 1.8, "#e8f0c8")
    # log seats where the game seats the druids
    for (gx, gy) in [(-0.35, 0.45), (0.45, 0.35), (0.1, -0.25)]:
        x, y = P(gx, gy)
        a.poly([(x - 9, y + 1), (x + 9, y - 3), (x + 9, y - 7), (x - 9, y - 3)], WOOD, INK, 1)
        a.ellipse(x + 9, y - 5, 2, 2.2, WOOD_L, INK, 0.8)
    # the green fire
    x, y = P(0.6, -0.45)
    for k in range(6):
        ang = k / 6 * math.tau
        a.ellipse(x + math.cos(ang) * 6, y + math.sin(ang) * 3, 2, 1.4, "#77736c", INK, 0.7)
    a.ellipse(x, y - 6, 8, 9, "#7aff9a", opacity=0.25)
    a.poly([(x - 4, y), (x - 2, y - 9), (x, y - 5), (x + 2, y - 12), (x + 4, y)], "#5ae07a", INK, 0.8)
    a.poly([(x - 2, y), (x, y - 6), (x + 2, y)], "#d8ffd8", stroke=None)
    for (gx, gy) in front:
        stone(gx, gy, 9)
    a.save("grove")


def druid():
    """A druid: a moss-green robe, a hood with a wreath of leaves, a crooked staff."""
    def extra(a, layer):
        if layer == "back":
            a.line([(9, 0), (11, -44)], INK, 3.2)
            a.line([(9, 0), (11, -44)], WOOD, 1.8)
            a.ellipse(11, -45, 3.4, 3, "#5aa04a", INK, 0.9)
        else:
            a.line([(-5, -24), (5, -24)], "#8a6a3a", 1.6)  # rope belt
            a.line([(4, -20), (9, -28)], INK, 4)
            a.line([(4, -20), (9, -28)], "#3e5a2c", 2.6)

    def hat(a):
        for (dx, dy) in [(-6, -38), (-3, -42), (1, -43), (5, -41), (7, -37)]:
            a.ellipse(dx, dy, 2.4, 1.6, "#6aa84a", INK, 0.7)
    person("unit_druid", ("#3e5a2c", "#2e4620"), hood="#4a3a24", hat=hat, robe=True, extra=extra)


def priest_person():
    """Anselm: a black cassock, a white collar, a grey fringe round a bald head,
    a spade from the graves."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-9, 2), (-6, -30)], INK, 2.8)
            a.line([(-9, 2), (-6, -30)], WOOD_L, 1.4)
            a.poly([(-11, 2), (-6, 2), (-6.5, 7), (-10.5, 7)], "#9a9a9a", INK, 0.8)
        else:
            a.poly([(-4, -27), (4, -27), (3, -24), (-3, -24)], "#f0ece0", INK, 0.7)
            a.line([(0, -22), (0, -15)], GOLD, 1.2)
            a.line([(-2, -19.5), (2, -19.5)], GOLD, 1.2)

    def hat(a):
        a.raw('<path d="M-6,-31 Q-7,-37 -4,-37 M6,-32 Q7,-37 4,-37" fill="none" stroke="#b8b4ac" stroke-width="2.6"/>', [(-8, -38), (8, -30)])
    person("unit_priest", ("#26242a", "#1a181e"), hat=hat, skin="#d4a888", robe=True, extra=extra)


def eldest_priest_person():
    """Scenario 9's eldest priest, as in her portrait: a dark-blue habit and veil
    over a white wimple, a gold cross on her chest."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-6, -38), (-10, -18), (-3, -24)], "#26324a", INK, 0.9)  # the veil down her back
        else:
            a.poly([(-5, -29), (5, -29), (4, -24.5), (-4, -24.5)], "#f0ece2", INK, 0.7)  # wimple at the chin
            a.line([(0, -22), (0, -14)], GOLD, 1.4)
            a.line([(-2.5, -19.5), (2.5, -19.5)], GOLD, 1.4)

    def hat(a):
        a.raw('<path d="M-5.5,-36.5 Q0,-39 5.5,-36.5" fill="none" stroke="#f0ece2" stroke-width="2.4"/>', [(-6, -40), (6, -35)])
    person("unit_eldest_priest", ("#26324a", "#1c2638"), hood="#26324a", hat=hat, skin="#d6ae8e", robe=True, extra=extra)


def princess():
    """Fiona: a deep-blue gown with a silver hem, red-gold hair under a thin circlet."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-6, -36), (-10, -14), (-4, -24)], "#b0582a", INK, 0.9)  # hair down her back
        else:
            a.line([(-8, -6), (8, -6)], "#c8ccd8", 1.4)
            a.line([(-5, -26), (5, -26)], "#c8ccd8", 1.2)

    def hat(a):
        a.raw('<path d="M-6,-33 Q-7,-41 0,-41 Q7,-41 6,-33 Q5,-38 0,-38 Q-5,-38 -6,-33Z" fill="#b0582a" stroke="%s" stroke-width="1.1"/>' % INK, [(-7, -42), (7, -32)])
        a.line([(-5.5, -37.5), (5.5, -37.5)], "#d8dce8", 1.4)
        a.ellipse(0, -38, 1.2, 1.2, "#7ab0ff")
    person("unit_princess", ("#243a6a", "#1a2c52"), hat=hat, skin="#e0bc9c", robe=True, extra=extra)


def _manor(name, lower, upper, roof, roof_front, decorate):
    """A taller house on a hut's lot (the campaign's named villagers' homes)."""
    a = Art()
    x0, x1, y0, y1 = -0.34, 0.34, -0.3, 0.3
    a.shadow(44, 22, cy=4)
    h, ridge = 36, 62
    a.box(x0, x1, y0, y1, 0, 14, lower[0], lower[1], lower[2])
    a.box(x0, x1, y0, y1, 14, h, upper[0], upper[1], upper[2])
    a.poly([P(-0.08, y1, 0), P(0.08, y1, 0), P(0.08, y1, 17), P(-0.08, y1, 17)], "#2b1e14")
    a.poly([P(x1, 0.15, 20), P(x1, -0.05, 20), P(x1, -0.05, 29), P(x1, 0.15, 29)], GLOW)
    ym = (y0 + y1) / 2
    ey, ex = 0.07, 0.03
    slope = (ridge - h) / (y1 - ym)
    eave_h = h - slope * ey
    xa, xb = x0 - ex, x1 + ex
    a.poly([P(xa, y0 - ey, eave_h), P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xa, ym, ridge)], roof)
    a.poly([P(x1, y0, h), P(x1, ym, ridge), P(x1, y1, h)], upper[2])
    a.poly([P(xa, ym, ridge), P(xb, ym, ridge), P(xb, y1 + ey, eave_h), P(xa, y1 + ey, eave_h)], roof_front)
    a.line([P(xb, y0 - ey, eave_h), P(xb, ym, ridge), P(xb, y1 + ey, eave_h)], "#3b2a1d", 3.2)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], "#3b2a1d", 2.4)
    decorate(a, x0, x1, y0, y1, h, ridge, ym)
    a.save(name)


def campaign_houses():
    """Anselm's house (scenario 6): whitewashed, a bell-cote with a cross on the
    gable. Fiona's house (scenario 7): grey stone, a slate roof, her blue
    banner with the crown's silver tower."""
    def bell(a, x0, x1, y0, y1, h, ridge, ym):
        bx, by = P(x1, ym, ridge)
        a.poly([(bx - 4, by), (bx + 4, by), (bx + 4, by - 10), (bx - 4, by - 10)], "#d8d0c0", INK, 1)
        a.ellipse(bx, by - 5, 2.2, 2.6, GOLD_D, INK, 0.7)
        a.poly([(bx - 6, by - 10), (bx + 6, by - 10), (bx, by - 15)], "#4a3b24", INK, 0.9)
        a.line([(bx, by - 15), (bx, by - 22)], INK, 2)
        a.line([(bx - 3, by - 19.5), (bx + 3, by - 19.5)], INK, 2)
        for t in (0.25, 0.75):
            gx = x0 + (x1 - x0) * t
            a.poly([P(gx - 0.05, y1, 20), P(gx + 0.05, y1, 20), P(gx + 0.05, y1, 30), P(gx - 0.05, y1, 30)], GLOW)
    _manor("priest_house", ("#b8b0a0", "#b8b0a0", "#948c7e"), ("#e0d8c8", "#e0d8c8", "#bab2a2"), "#4a3b24", "#5b4a2e", bell)

    def banner(a, x0, x1, y0, y1, h, ridge, ym):
        bx, by = P(x0 + 0.1, y1, h + 4)
        a.line([(bx, by), (bx, by - 26)], WOOD_D, 1.8)
        a.poly([(bx, by - 26), (bx + 12, by - 24), (bx + 12, by - 8), (bx + 6, by - 11), (bx, by - 8)], "#243a6a", INK, 0.9)
        a.poly([(bx + 4, by - 13), (bx + 8, by - 13), (bx + 8, by - 21), (bx + 4, by - 21)], "#d8dce8", stroke=None)
        a.box(0.14, 0.24, -0.1, 0.0, ridge - 14, ridge + 8, STONE_T, STONE_L, STONE_R)
    _manor("fiona_house", (STONE_T, STONE_L, STONE_R), ("#8e8a84", "#8e8a84", "#6c6862"), "#2e3a44", "#3e4c58", banner)


def portraits_67():
    """The speakers of scenarios 6 and 7 (docs/story-design.md section 2)."""
    # Anselm: the battlefield's old priest; a grey fringe round a bald crown,
    # a black cassock, a white collar, tired kind eyes, dust on his cheek.
    portrait_svg("portrait_anselm", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#26242a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M26 43 L32 48 L38 43" fill="#f0ece0" stroke="{INK}" stroke-width="1.6"/>
  <path d="M32 50 L32 62 M27 55 L37 55" stroke="{GOLD}" stroke-width="2"/>
  <rect x="27" y="35" width="10" height="9" fill="#c89c7c" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 11 32 10 Q45 11 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#d4a888" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 27 Q16 16 22 14 Q20 20 21 27Z M45 27 Q48 16 42 14 Q44 20 43 27Z" fill="#b8b4ac" stroke="{INK}" stroke-width="1.6"/>
  <path d="M24 23 Q27 21.5 29 23 M35 23 Q37 21.5 40 23" fill="none" stroke="#9a948a" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.3" fill="{INK}"/><circle cx="37" cy="26" r="1.3" fill="{INK}"/>
  <path d="M24 28.5 Q27 30 29 28.5 M35 28.5 Q37 30 40 28.5" fill="none" stroke="#a87858" stroke-width="0.9"/>
  <path d="M28.5 34 Q32 35 35.5 34" fill="none" stroke="#7a4a3a" stroke-width="1.4" stroke-linecap="round"/>
  <ellipse cx="40" cy="31" rx="2.6" ry="1.4" fill="#8a7a62" opacity="0.6"/>""", bg="#2a2824")
    # Fiona: the old king's daughter; red-gold hair, a thin silver circlet, a
    # deep-blue gown with a silver collar, a level, measuring look.
    portrait_svg("portrait_fiona", f"""
  <path d="M20 24 Q10 40 14 58 L23 52 Q19 40 22 30Z" fill="#b0582a" stroke="{INK}" stroke-width="2"/>
  <path d="M44 24 Q54 40 50 58 L41 52 Q45 40 42 30Z" fill="#b0582a" stroke="{INK}" stroke-width="2"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#243a6a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M20 44 Q32 54 44 44" fill="none" stroke="#c8ccd8" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#dcb898" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#e4c0a0" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 27 Q15 8 32 7 Q49 8 45 27 Q44 16 36 14 Q30 18 21 17 Q20 22 19 27Z" fill="#b0582a" stroke="{INK}" stroke-width="2"/>
  <path d="M20 15 Q32 10 44 15" fill="none" stroke="#d8dce8" stroke-width="2"/>
  <circle cx="32" cy="12" r="1.8" fill="#7ab0ff" stroke="{INK}" stroke-width="0.8"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#7a3a1a" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.4" fill="#2a3a5a"/><circle cx="37" cy="26" r="1.4" fill="#2a3a5a"/>
  <path d="M28.5 33.5 L35.5 33.5" stroke="#9a5a4a" stroke-width="1.4" stroke-linecap="round"/>""", bg="#1e2638")
    # The druids' elder: a long white beard, a wreath of oak leaves, a hood of
    # undyed wool over a moss-green robe.
    portrait_svg("portrait_elder", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#3e5a2c" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 40 Q8 8 32 4 Q56 8 54 40 L46 40 Q46 16 32 14 Q18 16 18 40Z" fill="#6a5a40" stroke="{INK}" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#c49474" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#cc9c78" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 27 Q18 56 32 62 Q46 56 44 27 Q40 34 32 34 Q24 34 20 27Z" fill="#ece8e0" stroke="{INK}" stroke-width="2"/>
  <path d="M26 32 Q32 30 38 32" fill="none" stroke="#c8c4bc" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M19 17 Q32 11 45 17" fill="none" stroke="#4a7a32" stroke-width="3.2"/>
  <ellipse cx="22" cy="16" rx="3" ry="2" fill="#6aa84a" stroke="{INK}" stroke-width="0.9"/>
  <ellipse cx="32" cy="12.5" rx="3" ry="2" fill="#6aa84a" stroke="{INK}" stroke-width="0.9"/>
  <ellipse cx="42" cy="16" rx="3" ry="2" fill="#6aa84a" stroke="{INK}" stroke-width="0.9"/>
  <path d="M24 22.5 L29 22 M35 22 L40 22.5" stroke="#e8e4dc" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="27" cy="25.5" r="1.4" fill="{INK}"/><circle cx="37" cy="25.5" r="1.4" fill="{INK}"/>""", bg="#22301e")
    # Idris, a court mage: a dark face, a silver-shot short beard, a deep
    # violet hood with silver stars.
    portrait_svg("portrait_mage", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#3a2a5a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 42 Q8 8 32 5 Q56 8 54 42 L46 42 Q46 16 32 15 Q18 16 18 42Z" fill="#2c2048" stroke="{INK}" stroke-width="2.2"/>
  <circle cx="14" cy="30" r="1" fill="#d8dce8"/><circle cx="50" cy="24" r="1" fill="#d8dce8"/><circle cx="20" cy="12" r="0.9" fill="#d8dce8"/>
  <rect x="27" y="35" width="10" height="9" fill="#7a5038" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#8a5c40" stroke="{INK}" stroke-width="2.2"/>
  <path d="M22 30 Q24 41 32 42 Q40 41 42 30 Q38 35 32 35 Q26 35 22 30Z" fill="#4a4448" stroke="{INK}" stroke-width="1.6"/>
  <path d="M27 38 L29 40 M35 38 L33 40" stroke="#b8b4b0" stroke-width="1"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#1e1a18" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.4" fill="{INK}"/><circle cx="37" cy="26" r="1.4" fill="{INK}"/>
  <path d="M28.5 32.5 Q32 33.4 35.5 32.5" fill="none" stroke="#4a2a1e" stroke-width="1.4" stroke-linecap="round"/>""", bg="#221c30")


def legion_footman():
    """A soldier of the Dread Legion: pale skin, a grey-steel helm, a faded
    tabard that was crimson once, a spear and a round shield; stiff."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-7, -6), (-2, -52)], INK, 3.4)  # spear, upright
            a.line([(-7, -6), (-2, -52)], "#6a5a48", 1.8)
            a.poly([(-3.5, -52), (-2, -60), (-0.5, -52)], "#b8bcc4", INK, 0.8)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a4e50", INK, 1)  # faded tabard
            a.line([(0, -26), (0, -12)], "#5a4446", 1)
            a.ellipse(7, -18, 6, 7, "#5a5e66", INK, 1.2)  # shield
            a.ellipse(7, -18, 2, 2.3, "#8a8e96", INK, 0.8)

    def hat(a):
        a.raw('<path d="M-6.5,-31 Q-7,-41 0,-41 Q7,-41 6.5,-31 L4,-31 L4,-34 L-4,-34 L-4,-31Z" fill="#7a7e86" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -42), (7, -30)])
        a.line([(-1, -34), (-1, -29)], "#5a5e66", 1.4)  # nose guard
        a.ellipse(3, -33, 1.1, 0.8, "#d8e0f0")  # empty, pale eye
    person("unit_legion_footman", ("#4a4c54", "#3a3c44"), hat=hat, skin="#c4c6c8", extra=extra)


def legion_captain(name, plume, hair=None):
    """A Legion captain: the footman's pallor, a plumed helm, a long dark cloak
    and a sword held high. Lysa's own has a crimson plume and a dark-red
    braid; Torben's (the generic one) a pale grey plume."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-7, -27), (-12, -2), (0, -4), (6, -27)], "#2a2a30", INK, 1.2)  # cloak
            if hair:
                a.raw('<path d="M-5,-33 Q-11,-28 -9,-19 Q-8,-24 -4,-29Z" fill="%s" stroke="%s" stroke-width="1"/>' % (hair, INK), [(-11, -34), (-3, -18)])
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#5a4448", INK, 1)
            a.line([(-5, -24), (5, -24)], GOLD_D, 1.4)  # a captain's sash
            a.line([(4, -22), (10, -30)], INK, 3.6)  # sword arm, raised
            a.line([(9, -29), (12, -32)], INK, 2.4)
            a.poly([(11, -33), (13, -31), (21, -46), (20, -47)], "#c8ccd4", INK, 0.9)

    def hat(a):
        a.raw('<path d="M-6.5,-31 Q-7,-41 0,-41 Q7,-41 6.5,-31 L4,-31 L4,-34 L-4,-34 L-4,-31Z" fill="#8a8e96" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -42), (7, -30)])
        a.line([(-1, -34), (-1, -29)], "#5a5e66", 1.4)
        a.raw('<path d="M0,-41 Q-4,-50 -12,-49 Q-6,-46 -4,-41Z" fill="%s" stroke="%s" stroke-width="1"/>' % (plume, INK), [(-13, -51), (1, -40)])
        a.ellipse(3, -33, 1.1, 0.8, "#d8e0f0")
    person(name, ("#3a3a42", "#2c2c34"), hat=hat, skin="#c4c6c8", extra=extra)


# ------------------------------------------------- scenarios 8 and 9: the Legion, the abbey

LEGION_HELM = '<path d="M-6.5,-31 Q-7,-41 0,-41 Q7,-41 6.5,-31 L4,-31 L4,-34 L-4,-34 L-4,-31Z" fill="%s" stroke="%s" stroke-width="1.2"/>'


def _legion_hat(steel="#7a7e86", plume=None):
    def hat(a):
        a.raw(LEGION_HELM % (steel, INK), [(-7, -42), (7, -30)])
        a.line([(-1, -34), (-1, -29)], "#5a5e66", 1.4)  # nose guard
        if plume:
            a.raw('<path d="M0,-41 Q-4,-50 -12,-49 Q-6,-46 -4,-41Z" fill="%s" stroke="%s" stroke-width="1"/>' % (plume, INK), [(-13, -51), (1, -40)])
        a.ellipse(3, -33, 1.1, 0.8, "#d8e0f0")  # empty, pale eye
    return hat


def legion_archer():
    """A Legion archer: the footman's pallor and helm, a quiver on the back,
    a longbow held out in front, the faded tabard."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -14), (-4, -15), (-2, -34), (-7, -34)], "#5a4630", INK, 1)  # quiver
            for x in (-6.5, -4.5):
                a.line([(x, -34), (x - 1, -40)], "#c8c0a8", 1.2)
                a.poly([(x - 2.2, -40), (x + 0.2, -40), (x - 1, -43)], "#b8bcc4", INK, 0.5)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a4e50", INK, 1)  # faded tabard
            a.line([(0, -26), (0, -12)], "#5a4446", 1)
            a.line([(4, -22), (10, -21)], INK, 3.4)  # bow arm
            a.raw('<path d="M10,-40 Q17,-22 10,-4" fill="none" stroke="%s" stroke-width="3.2"/>' % INK, [(9, -41), (17, -3)])
            a.raw('<path d="M10,-40 Q17,-22 10,-4" fill="none" stroke="%s" stroke-width="1.8"/>' % "#6a5038", [(9, -41), (17, -3)])
            a.line([(10, -40), (10, -4)], "#d8d4c8", 0.7)  # string
    person("unit_legion_archer", ("#4a4c54", "#3a3c44"), hat=_legion_hat(), skin="#c4c6c8", extra=extra)


def legion_guard():
    """A Legion guardsman: a tall rectangular tower shield in front, the grey
    helm, a short spear over it."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-4, -4), (4, -50)], INK, 3.2)  # spear
            a.line([(-4, -4), (4, -50)], "#6a5a48", 1.6)
            a.poly([(2.6, -50), (4.4, -57), (6, -49.6)], "#b8bcc4", INK, 0.8)
        else:
            a.poly([(-1, -3), (12, -6), (12, -36), (-1, -33)], "#5a5e66", INK, 1.4)  # tower shield
            a.poly([(1, -6), (10, -8), (10, -33), (1, -31)], "#6a6e76", stroke=None)
            a.line([(5.5, -8), (5.5, -32)], "#8a8e96", 1.4)
            a.line([(1, -20), (10, -21)], "#8a8e96", 1.4)
            a.ellipse(5.5, -20.5, 2.2, 2.4, "#9a9ea6", INK, 0.8)
            a.line([(-1, -3), (12, -6), (12, -36), (-1, -33), (-1, -3)], INK, 1.4)
    person("unit_legion_guard", ("#44464e", "#34363e"), hat=_legion_hat("#8a8e96"), skin="#c4c6c8", extra=extra)


def legion_banner():
    """A Legion banner-bearer: a tall pole with a long pale banner, the crown's
    sigil faded on it; a short spear-point on top."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-6, -4), (-6, -66)], INK, 3.4)  # the banner pole
            a.line([(-6, -4), (-6, -66)], WOOD_D, 1.8)
            a.poly([(-7.4, -66), (-6, -72), (-4.6, -66)], "#b8bcc4", INK, 0.7)
            a.line([(-12, -62), (6, -62)], WOOD_D, 1.8)  # crossbar
            a.poly([(-11, -62), (5, -62), (5, -36), (-3, -40), (-11, -36)], "#d4d6dc", INK, 1.2)  # the pale banner
            a.poly([(-11, -62), (-3, -62), (-3, -40), (-11, -36)], "#c0c3ca", stroke=None)
            a.poly([(-7, -54), (-5, -57), (-3, -54), (-1, -57), (1, -54), (1, -50), (-7, -50)], "#8a8e9a", INK, 0.6)  # a faded crown
            a.line([(-11, -62), (5, -62)], INK, 1.2)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a4e50", INK, 1)
            a.line([(-4, -22), (-7, -26)], INK, 3.4)  # arm on the pole
    person("unit_legion_banner", ("#4a4c54", "#3a3c44"), hat=_legion_hat(), skin="#c4c6c8", extra=extra)


def legion_champion():
    """The court's champion (Rurik): pale plate with broad pauldrons, a white
    plume, a greatsword over the shoulder, a pale cloak."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-8, -27), (-14, -1), (2, -3), (7, -27)], "#c8ccd4", INK, 1.2)  # pale cloak
            a.line([(10, -14), (-10, -56)], INK, 5)  # greatsword over the shoulder
            a.line([(10, -14), (-10, -56)], "#d8dce4", 3)
            a.line([(5, -21), (11, -24)], INK, 3)  # cross-guard
            a.line([(5, -21), (11, -24)], GOLD_D, 1.6)
        else:
            a.poly([(-7, -11), (7, -11), (6, -27), (-6, -27)], "#b8bcc4", INK, 1.2)  # breastplate
            a.poly([(0, -11), (7, -11), (6, -27), (0, -27)], "#9a9ea6", stroke=None)
            a.line([(-6, -19), (6, -19)], "#7a7e86", 1)
            a.ellipse(-7, -26, 4.4, 3.2, "#c8ccd4", INK, 1.1)  # pauldrons
            a.ellipse(7, -26, 4.4, 3.2, "#a8acb4", INK, 1.1)
            a.line([(7, -24), (10, -16)], INK, 4)  # arm to the hilt
    person("unit_legion_champion", ("#9a9ea6", "#7a7e86"), hat=_legion_hat("#b8bcc4", "#eceef2"), skin="#c4c6c8", extra=extra)


def herald():
    """Lothar, the court's herald: a pale tabard over a long coat, a feathered
    cap, a white flag on a staff."""
    def extra(a, layer):
        if layer == "back":
            a.line([(8, -2), (8, -58)], INK, 3)
            a.line([(8, -2), (8, -58)], "#d8d0bc", 1.6)
            a.raw('<path d="M8,-58 Q16,-60 22,-56 Q18,-50 24,-44 Q16,-46 8,-42 Z" fill="#f2f0ea" stroke="%s" stroke-width="1"/>' % INK, [(7, -61), (25, -41)])
        else:
            a.poly([(-6, -10), (6, -10), (5, -27), (-5, -27)], "#d8d6de", INK, 1)  # pale tabard
            a.poly([(-3, -21), (0, -24), (3, -21), (0, -18)], GOLD_D, INK, 0.6)
            a.line([(4, -22), (8, -26)], INK, 3.4)  # hand on the staff

    def hat(a):
        a.raw('<path d="M-7,-35 Q-6,-42 1,-42 Q8,-41 8,-35 Z" fill="#5a5470" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -43), (9, -34)])
        a.raw('<path d="M-4,-41 Q-12,-50 -16,-46 Q-10,-45 -6,-39 Z" fill="#eceae4" stroke="%s" stroke-width="0.9"/>' % INK, [(-17, -51), (-3, -38)])
    person("unit_herald", ("#4a4660", "#3a3650"), hat=hat, skin="#d8ccc4", robe=True, extra=extra)


def legion_camp(cleared=False):
    """A Dread Legion camp at the court's gates: an orderly pale canvas tent,
    a rack of spears, the Legion's pale banner; cleared, the tent down and the
    banner fallen."""
    a = Art()
    a.poly(diamond(0.86), "#3e3a36", stroke=None, opacity=0.5)
    can, can_d, can_s = "#c8c6c0", "#a6a49e", "#b6b4ae"
    x0, x1, y0, y1, ridge = -0.38, 0.12, -0.36, 0.06, 40
    ym = (y0 + y1) / 2
    if not cleared:
        a.poly([P(x0, y0, 0), P(x1, y0, 0), P(x1, ym, ridge), P(x0, ym, ridge)], can_d)
        a.poly([P(x1, y0, 0), P(x1, ym, ridge), P(x1, y1, 0)], can_s)
        a.poly([P(x1, ym - 0.07, 0), P(x1, ym, ridge * 0.7), P(x1, ym + 0.07, 0)], "#24262c", stroke=None)  # opening
        a.poly([P(x0, ym, ridge), P(x1, ym, ridge), P(x1, y1, 0), P(x0, y1, 0)], can)
        a.line([P(x0, ym, ridge), P(x1, ym, ridge)], "#6a6e76", 2)
        for t in (0.25, 0.5, 0.75):  # seams, straight: an army's tent
            gx = x0 + (x1 - x0) * t
            a.line([P(gx, ym, ridge), P(gx, y1, 0)], "#9a9892", 0.9)
        # a rack of spears
        rx, ry = P(0.22, -0.28)
        a.line([(rx - 9, ry), (rx + 9, ry - 4)], WOOD_D, 2.4)
        for k in range(4):
            sx = rx - 7 + k * 5
            sy = ry - k * 1.1
            a.line([(sx, sy + 2), (sx + 1, sy - 30)], INK, 2.2)
            a.line([(sx, sy + 2), (sx + 1, sy - 30)], "#6a5a48", 1.1)
            a.poly([(sx - 0.6, sy - 30), (sx + 1, sy - 35), (sx + 2.4, sy - 30)], "#b8bcc4", INK, 0.5)
    else:
        a.poly([P(x0, y0 + 0.02, 0), P(x1 - 0.05, y0, 0), P(x1, ym, 8), P(x1 + 0.02, y1 + 0.04, 0), P(x0 + 0.05, y1 + 0.02, 0), P(x0 - 0.02, ym, 5)], can_d)
        a.poly([P(x0 - 0.02, ym, 5), P(-0.1, ym + 0.02, 11), P(x1, ym, 8), P(x1 + 0.02, y1 + 0.04, 0), P(x0 + 0.05, y1 + 0.02, 0)], can)
        rx, ry = P(0.22, -0.28)
        for k in range(3):
            a.line([(rx - 12 + k * 4, ry + 2 + k), (rx + 14 + k * 3, ry - 6 + k * 2)], "#6a5a48", 1.4)
    bx, by = P(-0.32, 0.26)
    if not cleared:
        a.line([(bx, by), (bx, by - 58)], INK, 3.4)
        a.line([(bx, by), (bx, by - 58)], WOOD_D, 1.8)
        a.line([(bx - 4, by - 54), (bx + 18, by - 54)], WOOD_D, 2)
        a.poly([(bx + 1, by - 54), (bx + 17, by - 54), (bx + 17, by - 30), (bx + 9, by - 34), (bx + 1, by - 30)], "#d4d6dc", INK, 1.1)
        a.poly([(bx + 5, by - 46), (bx + 7, by - 49), (bx + 9, by - 46), (bx + 11, by - 49), (bx + 13, by - 46), (bx + 13, by - 42), (bx + 5, by - 42)], "#8a8e9a", INK, 0.6)
    else:
        a.line([(bx - 10, by + 4), (bx + 38, by - 10)], INK, 3.4)
        a.line([(bx - 10, by + 4), (bx + 38, by - 10)], WOOD_D, 1.8)
        a.poly([(bx + 24, by - 7), (bx + 38, by - 12), (bx + 42, by - 1), (bx + 28, by + 2)], "#c0c3ca", INK, 0.9)
    # a cold fire, ringed with stones
    fx, fy = P(0.28, 0.2)
    for k in range(7):
        ang = k * math.pi * 2 / 7
        a.ellipse(fx + math.cos(ang) * 9, fy + math.sin(ang) * 4.5, 2.6, 1.8, "#6b665e", INK, 0.8)
    a.ellipse(fx, fy, 6.5, 3, "#1e1a16")
    if not cleared:
        _glow(a, fx, fy - 6, 30, 18, "#c8d8ff", 0.3)
        a.poly([(fx - 4, fy - 1), (fx - 1, fy - 11), (fx + 1, fy - 6), (fx + 3, fy - 13), (fx + 5, fy - 1)], "#9ab0e0", "#4a5a8a", 0.9)
    a.save("legion_camp_cleared" if cleared else "legion_camp")


def abbey(looted=False):
    """The drowned abbey (scenario 9), a 2x2 treasure: a stone church half
    under water, its nave sunk to the windows, a broken spire and a bell
    tower standing out of the lake, water lapping round it. Before it is
    looted a faint gold light shines up through the water from the crypt."""
    k = 2.0
    a = Art()
    water, water_d, foam = "#3a6a8a", "#2a5070", "#a8c8d8"
    a.ellipse(0, 4 * k, 60 * k, 27 * k, water_d, INK, 1.2)
    a.ellipse(0, 3 * k, 54 * k, 23 * k, water)
    if not looted:
        _glow(a, -4 * k, 4 * k, 26 * k, 12 * k, "#ffe08a", 0.45)
    sl, sr, st = "#8a857c", "#66625b", "#9c978d"
    w, l, H, R = 0.42, 0.62, 30, 26

    def p(gx, gy, z=0.0):
        return P(gx * 1.5, gy * 1.5, z * 1.1)
    # the nave, sunk: its walls stand from the water up
    a.poly([p(-w, l), p(w, l), p(w, l, H), p(0, l, H + R), p(-w, l, H)], sl, INK, 1.3)
    a.poly([p(w, l), p(w, -l), p(w, -l, H), p(w, l, H)], sr, INK, 1.3)
    for z in (10, 20):
        a.line([p(-w, l, z), p(w, l, z), p(w, -l, z)], "#3e3b37", 0.8, opacity=0.7)
    a.poly([p(w + 0.04, l + 0.04, H - 2), p(w + 0.04, -l - 0.04, H - 2), p(0, -l - 0.04, H + R), p(0, l + 0.04, H + R)], "#3e4650", INK, 1.2)  # slate roof
    a.poly([p(w, 0.1, H), p(w, -0.22, H), p(0, -0.16, H + R), p(0, 0.16, H + R)], "#15181c", INK, 1.0)  # a hole in it
    for gy in (0.02, -0.12):
        a.line([p(w, gy, H), p(0, gy, H + R)], WOOD_D, 2.2)
    # arched windows on the long side, the water halfway up them
    for gy in (0.38, -0.4):
        wx, wy = p(w, gy, 16)
        a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#141110" stroke="%s" stroke-width="1.1"/>'
              % (fmt(wx - 4), fmt(wy + 2), fmt(wx - 4), fmt(wy - 10), fmt(wx), fmt(wy - 17), fmt(wx + 4), fmt(wy - 12), fmt(wx + 4), fmt(wy), INK),
              [(wx - 5, wy - 17), (wx + 5, wy + 3)])
    # the bell tower at the far end, its spire broken off
    tx0, tx1, ty0, ty1 = -0.3, 0.06, -0.86, -0.5
    th = 62
    a.poly([p(tx0, ty1), p(tx1, ty1), p(tx1, ty1, th), p(tx0, ty1, th)], st, INK, 1.3)
    a.poly([p(tx1, ty1), p(tx1, ty0), p(tx1, ty0, th), p(tx1, ty1, th)], sr, INK, 1.3)
    bx, by = p((tx0 + tx1) / 2, ty1, th - 14)
    a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#141110" stroke="%s" stroke-width="1.1"/>'
          % (fmt(bx - 5), fmt(by + 6), fmt(bx - 5), fmt(by - 6), fmt(bx), fmt(by - 13), fmt(bx + 5), fmt(by - 6), fmt(bx + 5), fmt(by + 6), INK),
          [(bx - 6, by - 13), (bx + 6, by + 6)])
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s" stroke="%s" stroke-width="0.9"/>'
          % (fmt(bx - 3.5), fmt(by + 4), fmt(bx - 3), fmt(by - 6), fmt(bx), fmt(by - 6), fmt(bx + 3), fmt(by - 6), fmt(bx + 3.5), fmt(by + 4),
             GOLD_D, INK), [(bx - 4, by - 7), (bx + 4, by + 5)])
    sx, sy = p((tx0 + tx1) / 2 + 0.06, (ty0 + ty1) / 2, th)
    a.poly([(sx - 13, sy + 2), (sx + 12, sy + 4), (sx + 4, sy - 22), (sx - 1, sy - 14), (sx - 5, sy - 18)], "#3e4650", INK, 1.2)  # the broken spire
    # the lake over the foot of the walls: they stand in it
    a.raw('<path d="M%s,%s A%s,%s 0 0 0 %s,%s Z" fill="%s" opacity="0.8"/>'
          % (fmt(-54 * k), fmt(3 * k), fmt(54 * k), fmt(23 * k), fmt(54 * k), fmt(3 * k), water),
          [(-54 * k, 3 * k), (54 * k, 26 * k)])
    # the water's edge against the walls, with foam
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="2"/>'
          % (fmt(p(-w, l)[0] - 6), fmt(p(-w, l)[1] + 2), fmt(p(0, l)[0]), fmt(p(0, l)[1] + 6), fmt(p(w, l)[0] + 2), fmt(p(w, l)[1] + 2),
             fmt(p(w, 0)[0] + 8), fmt(p(w, 0)[1] + 2), fmt(p(w, -l)[0] + 6), fmt(p(w, -l)[1] + 2), foam),
          [(p(-w, l)[0] - 7, p(-w, -l)[1] - 2), (p(w, -l)[0] + 9, p(0, l)[1] + 8)])
    for (x, y) in [(-40, 14), (36, 18), (10, 30), (-20, 26)]:
        _arc(a, x * k * 0.8, y * k * 0.7, 10 * k, 2.4, foam, 1.0, 0.7)
    a.save("abbey_looted" if looted else "abbey")


def portraits_89():
    """The speakers of scenarios 8 and 9 (docs/story-design.md section 2)."""
    # Lothar, the court's herald: a long pale face, a neat silver beard, a
    # feathered cap, a pale tabard with a gold crown; courteous, cold.
    portrait_svg("portrait_lothar", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#d8d6de" stroke="{INK}" stroke-width="2.4"/>
  <path d="M27 52 L30 48 L32 51 L34 48 L37 52 L37 56 L27 56Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#d8ccc4" stroke="{INK}" stroke-width="1.8"/>
  <path d="M21 24 Q20 11 32 10 Q44 11 43 24 Q43 37 32 40 Q21 37 21 24Z" fill="#e2d6ce" stroke="{INK}" stroke-width="2.2"/>
  <path d="M24 31 Q25 42 32 43 Q39 42 40 31 Q37 36 32 36 Q27 36 24 31Z" fill="#c8c8cc" stroke="{INK}" stroke-width="1.6"/>
  <path d="M15 17 Q18 5 32 5 Q46 5 48 17Z" fill="#5a5470" stroke="{INK}" stroke-width="2"/>
  <path d="M40 9 Q52 0 60 8 Q52 8 46 14Z" fill="#eceae4" stroke="{INK}" stroke-width="1.6"/>
  <path d="M24 22.5 L29 22 M35 22 L40 22.5" stroke="#9a9894" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="27" cy="25.5" r="1.3" fill="{INK}"/><circle cx="37" cy="25.5" r="1.3" fill="{INK}"/>
  <path d="M28.5 33 Q32 34 35.5 33" fill="none" stroke="#8a6a6a" stroke-width="1.3" stroke-linecap="round"/>""", bg="#2a2836")
    # Rurik, the court's champion: a pale square face, a scar over the brow,
    # empty pale eyes, a white plume over a pale steel helm, broad pauldrons.
    portrait_svg("portrait_rurik", f"""
  <path d="M2 66 Q2 44 18 40 L46 40 Q62 44 62 66Z" fill="#b8bcc4" stroke="{INK}" stroke-width="2.4"/>
  <ellipse cx="12" cy="46" rx="10" ry="7" fill="#c8ccd4" stroke="{INK}" stroke-width="2"/>
  <ellipse cx="52" cy="46" rx="10" ry="7" fill="#a8acb4" stroke="{INK}" stroke-width="2"/>
  <rect x="26" y="34" width="12" height="9" fill="#bcc0c4" stroke="{INK}" stroke-width="1.8"/>
  <path d="M19 24 Q18 12 32 11 Q46 12 45 24 Q45 37 32 40 Q19 37 19 24Z" fill="#c8cccf" stroke="{INK}" stroke-width="2.2"/>
  <path d="M17 24 Q16 5 32 4 Q48 5 47 24 L43 24 L43 17 Q32 14 21 17 L21 24Z" fill="#b8bcc4" stroke="{INK}" stroke-width="2.2"/>
  <path d="M31 17 L31 27 L33 27 L33 17Z" fill="#8a8e96" stroke="{INK}" stroke-width="1.2"/>
  <path d="M36 6 Q48 -2 60 10 Q50 6 42 10Z" fill="#eceef2" stroke="{INK}" stroke-width="1.8"/>
  <ellipse cx="27" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <ellipse cx="37" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <path d="M38 19 L42 27" stroke="#9a8a8a" stroke-width="1.2"/>
  <path d="M27.5 33.5 L36.5 33.5" stroke="#7a7e86" stroke-width="1.6" stroke-linecap="round"/>""", bg="#22242a")
    # Rhodri: the king, paler than anyone, the old king's crown reworked and
    # glowing cold over dark hair, a high collar, a thin smile.
    portrait_svg("portrait_rhodri", f"""
  <circle cx="32" cy="10" r="20" fill="#b8d0ff" opacity="0.18"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#1e1a2a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M18 44 L24 36 L32 46 L40 36 L46 44" fill="#3a3450" stroke="{INK}" stroke-width="1.8"/>
  <rect x="27" y="35" width="10" height="9" fill="#d4d8e0" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#e0e4ec" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 27 Q16 12 32 11 Q48 12 45 27 Q44 19 39 17 Q32 18 25 17 Q20 20 19 27Z" fill="#2a2430" stroke="{INK}" stroke-width="2"/>
  <path d="M19 15 L21 4 L26 10 L32 2 L38 10 L43 4 L45 15Z" fill="#c8d8f0" stroke="{INK}" stroke-width="1.8"/>
  <circle cx="32" cy="10" r="2" fill="#eaf4ff" stroke="{INK}" stroke-width="0.8"/>
  <circle cx="24" cy="12" r="1.2" fill="#9ac0ff"/><circle cx="40" cy="12" r="1.2" fill="#9ac0ff"/>
  <path d="M24 22.5 L29 23 M35 23 L40 22.5" stroke="#3a3440" stroke-width="1.5" stroke-linecap="round"/>
  <ellipse cx="27" cy="25.8" rx="1.7" ry="1.2" fill="#b8d0ff" stroke="{INK}" stroke-width="0.6"/>
  <ellipse cx="37" cy="25.8" rx="1.7" ry="1.2" fill="#b8d0ff" stroke="{INK}" stroke-width="0.6"/>
  <path d="M28 33 Q32 35 37 32.5" fill="none" stroke="#8a7a8a" stroke-width="1.3" stroke-linecap="round"/>""", bg="#16141e")
    # A priest of the church, a survivor in the capital: a young, thin face, a
    # brown habit with its hood down, a wooden cross on a cord.
    portrait_svg("portrait_church_priest", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#6a5238" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 46 Q32 38 50 46 Q44 50 32 50 Q20 50 14 46Z" fill="#5a4430" stroke="{INK}" stroke-width="1.6"/>
  <path d="M28 44 L32 52 L36 44" fill="none" stroke="#3a2a1a" stroke-width="1"/>
  <path d="M32 52 L32 61 M28.5 55 L35.5 55" stroke="{WOOD_L}" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="8" fill="#d0a684" stroke="{INK}" stroke-width="1.8"/>
  <path d="M21 25 Q20 12 32 11 Q44 12 43 25 Q43 36 32 39 Q21 36 21 25Z" fill="#dab08e" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 22 Q19 9 32 8 Q45 9 44 22 Q40 14 32 14 Q24 14 20 22Z" fill="#5a3e28" stroke="{INK}" stroke-width="2"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#4a3220" stroke-width="1.4" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.3" fill="{INK}"/><circle cx="37" cy="26" r="1.3" fill="{INK}"/>
  <path d="M29 33.5 Q32 34.5 35 33.5" fill="none" stroke="#8a5a4a" stroke-width="1.3" stroke-linecap="round"/>""", bg="#2a241c")
    # The eldest priest of the drowned shore: a deeply lined
    # face, a white wimple under a dark-blue veil, wary eyes.
    portrait_svg("portrait_eldest_priest", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#26324a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 44 Q8 6 32 4 Q56 6 54 44 L46 44 Q46 16 32 15 Q18 16 18 44Z" fill="#26324a" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 40 Q18 16 32 15 Q46 16 45 40 Q40 44 32 44 Q24 44 19 40Z" fill="#f0ece2" stroke="{INK}" stroke-width="1.8"/>
  <path d="M22 26 Q21 15 32 15 Q43 15 42 26 Q42 36 32 38 Q22 36 22 26Z" fill="#d6ae8e" stroke="{INK}" stroke-width="2"/>
  <path d="M25 30 Q27 31 29 30 M35 30 Q37 31 39 30 M27 35 Q32 36.5 37 35" fill="none" stroke="#a87858" stroke-width="0.9"/>
  <path d="M25 24 L29.5 24.5 M34.5 24.5 L39 24" stroke="#8a7a6a" stroke-width="1.4" stroke-linecap="round"/>
  <circle cx="27.5" cy="27" r="1.3" fill="{INK}"/><circle cx="36.5" cy="27" r="1.3" fill="{INK}"/>
  <path d="M29 33 L35 33" stroke="#8a5a4a" stroke-width="1.3" stroke-linecap="round"/>
  <path d="M32 50 L32 60 M28 54 L36 54" stroke="{GOLD}" stroke-width="2"/>""", bg="#1e2432")


# ------------------------------------------------- scenarios 10 and 11: the marshal, the king, the capital

def legion_marshal():
    """The Legion's marshal (Halvard): dark steel plate under a pale mantle with
    a gold-trimmed collar, a red-white plume, a marshal's baton raised and a
    long sword at his side."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -28), (-15, 0), (4, -2), (8, -28)], "#d4d2dc", INK, 1.2)  # pale mantle
            a.poly([(-15, 0), (-9, -28), (-6, -28), (-10, 0)], "#b8b6c2", stroke=None)
            a.line([(-6, -12), (-12, 2)], INK, 3.4)  # sword at the hip
            a.line([(-6, -12), (-12, 2)], "#c8ccd4", 1.8)
        else:
            a.poly([(-7, -11), (7, -11), (6, -27), (-6, -27)], "#5e626c", INK, 1.2)  # dark breastplate
            a.poly([(0, -11), (7, -11), (6, -27), (0, -27)], "#4a4e58", stroke=None)
            a.line([(-6, -24), (0, -20), (6, -24)], GOLD, 1.4)  # gold trim
            a.ellipse(-7, -26, 4.2, 3.0, "#6e727c", INK, 1.1)
            a.ellipse(7, -26, 4.2, 3.0, "#5a5e68", INK, 1.1)
            a.line([(7, -24), (12, -34)], INK, 4)  # arm up, the baton
            a.line([(11, -32), (15, -42)], INK, 3.6)
            a.line([(11, -32), (15, -42)], GOLD, 2)
            a.ellipse(15, -42, 1.6, 1.6, GOLD, INK, 0.8)
    person("unit_legion_marshal", ("#5e626c", "#4a4e58"), hat=_legion_hat("#6e727c", "#e8e4ea"), skin="#c6c6ca", extra=extra)


def legion_king():
    """Rhodri on the field: a long dark royal coat over pale plate, the
    reworked crown glowing cold on his head, a heavy sword, a halo of cold light."""
    def extra(a, layer):
        if layer == "back":
            _glow(a, 0, -34, 14, 12, "#b8d0ff", 0.35)
            a.poly([(-10, -28), (-17, 0), (6, -1), (9, -28)], "#2a2236", INK, 1.2)  # royal coat
            a.poly([(-17, 0), (-10, -28), (-7, -28), (-12, 0)], "#3a3050", stroke=None)
            a.line([(-16, -1), (5, -2)], "#c8d0e0", 1.4)  # ermine hem
            a.line([(11, -12), (-8, -58)], INK, 5.5)  # the sword
            a.line([(11, -12), (-8, -58)], "#dce4f0", 3.2)
            a.line([(4, -19), (12, -22)], INK, 3)
            a.line([(4, -19), (12, -22)], GOLD, 1.6)
        else:
            a.poly([(-7, -11), (7, -11), (6, -27), (-6, -27)], "#c4c8d2", INK, 1.2)  # pale plate
            a.poly([(0, -11), (7, -11), (6, -27), (0, -27)], "#a4a8b2", stroke=None)
            a.poly([(-4, -27), (0, -22), (4, -27)], "#2a2236", INK, 0.8)
            a.line([(7, -24), (10, -15)], INK, 4)

    def crown(a):
        a.raw('<path d="M-7,-37 L-7,-44 L-3.5,-40 L0,-46 L3.5,-40 L7,-44 L7,-37 Z" fill="#c8d8f0" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -47), (8, -36)])
        a.ellipse(0, -40, 1.3, 1.3, "#eaf4ff", INK, 0.6)
        a.raw('<path d="M-6,-31 Q-7,-38 0,-39 Q7,-38 6,-31 Q5,-35 0,-35 Q-5,-35 -6,-31 Z" fill="#2a2430"/>', [(-7, -40), (7, -30)])
    person("unit_legion_king", ("#c4c8d2", "#a4a8b2"), hat=crown, skin="#e0e4ec", extra=extra)


def tile_cobble(i):
    """The capital's cobblestone ground (the city zone): grey setts in rows,
    ash in the joints, here and there a sett missing."""
    rng = random.Random(260 + i)
    a = Art()
    a.poly(diamond(1.03), ["#6a655e", "#67625b", "#6d6861"][i], stroke=None)
    for row in range(-5, 6):
        for col in range(-5, 6):
            gx, gy = (col + (0.5 if row % 2 else 0.0)) * 0.11, row * 0.11
            if max(abs(gx), abs(gy)) > 0.44 or rng.random() < 0.08:
                continue
            x, y = P(gx, gy)
            w = rng.uniform(4.5, 6.0)
            shade = rng.choice(["#7d776f", "#76716a", "#837d74", "#706b64"])
            a.poly([(x - w, y), (x, y - w * 0.5), (x + w, y), (x, y + w * 0.5)], shade, "#4c4842", 0.8)
    for _ in range(5):  # soot and ash
        x, y = rand_in_diamond(rng, 0.75)
        a.ellipse(x, y, rng.uniform(6, 13), rng.uniform(3, 6), "#3e3b37", opacity=0.3)
    a.save("tile_cobble_%d" % i, pad=0, fixed=(-66, -34, 66, 34))


def _opening(a, face, at, g0, g1, z0, z1, fill, arch=0.0, sw=0.9, opacity=None):
    """A window or door on a wall face ("front": the y = at face, along x;
    "side": the x = at face, along y) from g0 to g1, z0 to z1 high; `arch`:
    a pointed top that much higher in the middle."""
    def q(g, z):
        return P(g, at, z) if face == "front" else P(at, g, z)
    pts = [q(g0, z0), q(g1, z0), q(g1, z1)]
    if arch > 0:
        pts.append(q((g0 + g1) / 2, z1 + arch))
    pts.append(q(g0, z1))
    a.poly(pts, fill, INK, sw, opacity=opacity)


# ------------------------------------------------------- scenario 9: the harbour village

def church():
    """The harbour village's new church (scenario 9, 3x3, inside the walls):
    bigger and newer than the drowned abbey. A pale stone nave along the
    tile's y axis under a dark slate roof, buttresses, tall lit windows, a
    square bell tower at the back with a spire and a gold cross, the door in
    the front gable under a rose window, a paved forecourt."""
    a = Art()
    s = 1.45
    a.shadow(150, 70, cy=8)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#8a857b", INK, 1.0, opacity=0.9)  # paving
    for k in range(-2, 3):
        t = k * 0.55
        a.line([P(-s, t), P(s, t)], "#6e6a62", 0.8, opacity=0.6)
        a.line([P(t, -s), P(t, s)], "#6e6a62", 0.8, opacity=0.6)
    sl, sr, st = "#a8a296", "#837d72", "#bdb7aa"
    w, y0, y1, H, R = 0.55, -0.85, 1.05, 52, 34  # half width, nave from y0 to y1 (front), wall and roof height
    # the bell tower behind the nave
    tx0, tx1, ty0, ty1, th = -0.38, 0.38, -1.35, -0.6, 118
    a.box(tx0, tx1, ty0, ty1, 0, th, st, sl, sr)
    for z in (30, 60, 90):
        a.line([P(tx0, ty1, z), P(tx1, ty1, z), P(tx1, ty0, z)], "#6e695f", 1.0, opacity=0.8)
    bx, by = P(0.0, ty1, th - 22)
    _glow(a, bx, by, 16, 16, "#ffe39a", 0.55)
    a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#ffd970" stroke="%s" stroke-width="1.1"/>'
          % (fmt(bx - 5), fmt(by + 6), fmt(bx - 5), fmt(by - 6), fmt(bx), fmt(by - 14), fmt(bx + 5), fmt(by - 6), fmt(bx + 5), fmt(by + 6), INK),
          [(bx - 6, by - 14), (bx + 6, by + 7)])
    ax, ay = P(0.0, (ty0 + ty1) / 2, th)
    left = P(tx0, ty1, th)
    right = P(tx1, ty1, th)
    back = P(tx1, ty0, th)
    a.poly([left, right, (ax, ay - 62)], "#3a4652", INK, 1.3)  # the spire's faces
    a.poly([right, back, (ax, ay - 62)], "#2a333d", INK, 1.3)
    a.line([(ax, ay - 62), (ax, ay - 80)], INK, 3.2)
    a.line([(ax - 6, ay - 74), (ax + 6, ay - 74)], INK, 3.2)
    a.line([(ax, ay - 62), (ax, ay - 80)], GOLD, 1.6)
    a.line([(ax - 6, ay - 74), (ax + 6, ay - 74)], GOLD, 1.6)
    # the nave: the side (front-right, gx = +w) and the front gable (front-left, gy = y1)
    a.poly([P(w, y1), P(w, y0), P(w, y0, H), P(w, y1, H)], sr, INK, 1.4)
    a.poly([P(-w, y1), P(w, y1), P(w, y1, H), P(0, y1, H + R), P(-w, y1, H)], sl, INK, 1.4)
    for z in (13, 26, 39):
        a.line([P(-w, y1, z), P(w, y1, z), P(w, y0, z)], "#6e695f", 0.9, opacity=0.7)
    for gy in (-0.45, 0.05, 0.55):  # tall lit windows down the side, buttresses between
        wx, wy = P(w, gy + 0.12, 10)
        _glow(a, wx, wy - 14, 14, 20, "#ffd970", 0.45)
        a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#ffd970" stroke="%s" stroke-width="1.1"/>'
              % (fmt(wx - 4), fmt(wy + 2), fmt(wx - 4), fmt(wy - 20), fmt(wx), fmt(wy - 28), fmt(wx + 4), fmt(wy - 22), fmt(wx + 4), fmt(wy), INK),
              [(wx - 5, wy - 28), (wx + 5, wy + 3)])
        a.line([P(w, gy + 0.12, 10), P(w, gy + 0.12, 26)], "#c99a40", 0.8)
    for gy in (-0.7, -0.2, 0.3, 0.8):
        a.box(w, w + 0.1, gy - 0.05, gy + 0.05, 0, 34, st, sl, sr, sw=1.1)
    # the roof along y
    ex = 0.08
    a.poly([P(w + ex, y1 + 0.05, H - 3), P(w + ex, y0 - 0.05, H - 3), P(0, y0 - 0.05, H + R), P(0, y1 + 0.05, H + R)], "#3e4c58", INK, 1.4)
    for k in (0.25, 0.5, 0.75):
        a.line([P(w * (1 - k) + ex * (1 - k), y1 + 0.05, H - 3 + (R + 3) * k), P(w * (1 - k) + ex * (1 - k), y0 - 0.05, H - 3 + (R + 3) * k)], "#2e3a44", 1.0)
    a.line([P(0, y0 - 0.05, H + R), P(0, y1 + 0.05, H + R)], "#2a2f36", 2.6)
    a.line([P(0, y1 + 0.05, H + R), P(w + ex, y1 + 0.05, H - 3)], "#2a2f36", 3.0)
    # the door and the rose window in the gable, a cross on its peak
    dx, dy = P(0, y1)
    a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#2a1d14" stroke="%s" stroke-width="1.3"/>'
          % (fmt(dx - 9), fmt(dy), fmt(dx - 9), fmt(dy - 20), fmt(dx), fmt(dy - 32), fmt(dx + 9), fmt(dy - 20), fmt(dx + 9), fmt(dy + 1), INK),
          [(dx - 10, dy - 32), (dx + 10, dy + 1)])
    a.line([(dx, dy - 30), (dx, dy)], "#5a3e28", 1.2)
    rx, ry = P(0, y1, H + 12)
    _glow(a, rx, ry, 14, 14, "#ffe39a", 0.5)
    a.ellipse(rx, ry, 8, 8, "#ffd970", INK, 1.2)
    for k in range(4):
        ang = k * math.pi / 4
        a.line([(rx - 8 * math.cos(ang), ry - 8 * math.sin(ang)), (rx + 8 * math.cos(ang), ry + 8 * math.sin(ang))], "#b07a2a", 0.9)
    cx, cy = P(0, y1 + 0.05, H + R)
    a.line([(cx, cy), (cx, cy - 14)], INK, 3)
    a.line([(cx - 5, cy - 9), (cx + 5, cy - 9)], INK, 3)
    a.line([(cx, cy), (cx, cy - 14)], GOLD, 1.4)
    a.line([(cx - 5, cy - 9), (cx + 5, cy - 9)], GOLD, 1.4)
    # steps before the door
    a.box(-0.22, 0.22, y1, y1 + 0.18, 0, 4, st, sl, sr, sw=1)
    a.save("church")


def pier():
    """One tile of the harbour's pier (scenario 9): a plank deck along the
    tile's y axis on posts standing in the water, a mooring post."""
    a = Art()
    w = 0.32
    for (gx, gy) in [(-w, -0.45), (w, -0.45), (-w, 0.45), (w, 0.45)]:
        x, y = P(gx, gy)
        a.poly([(x - 2.5, y + 6), (x + 2.5, y + 6), (x + 2.5, y - 10), (x - 2.5, y - 10)], WOOD_D, INK, 1)
        a.ellipse(x, y + 6, 4.5, 1.8, "#cfe6f5", opacity=0.5)
    a.poly([P(-w, -0.5, 10), P(w, -0.5, 10), P(w, 0.5, 10), P(-w, 0.5, 10)], WOOD, INK, 1.3)
    a.poly([P(w, -0.5, 10), P(w, 0.5, 10), P(w, 0.5, 6), P(w, -0.5, 6)], WOOD_D, INK, 1.1)
    a.poly([P(-w, 0.5, 10), P(w, 0.5, 10), P(w, 0.5, 6), P(-w, 0.5, 6)], "#4f3722", INK, 1.1)
    for k in range(1, 6):
        gy = -0.5 + k / 6.0
        a.line([P(-w, gy, 10), P(w, gy, 10)], WOOD_D, 0.9)
    x, y = P(w - 0.05, 0.35, 10)
    a.poly([(x - 2.5, y), (x + 2.5, y), (x + 2.5, y - 10), (x - 2.5, y - 10)], WOOD_L, INK, 1)
    a.ellipse(x, y - 10, 2.6, 1.2, WOOD_D, INK, 0.8)
    a.save("pier")


def boat(sail=False):
    """A boat on the water, along the tile's y axis (scenario 9's harbour):
    a fishing rowboat moored at the pier, or the guild's supply boat with a
    sail and crates aboard (sail=True)."""
    a = Art()
    L = 0.85 if sail else 0.55
    W = 0.32 if sail else 0.22
    a.ellipse(0, 4, 52 if sail else 34, 14 if sail else 9, "#cfe6f5", opacity=0.35)
    hull = [P(0, -L, 4), P(W, -L * 0.45, 4), P(W, L * 0.6, 4), P(0, L, 6), P(-W, L * 0.6, 4), P(-W, -L * 0.45, 4)]
    a.poly([P(0, -L, -2), P(W * 0.8, -L * 0.45, -4), P(W * 0.8, L * 0.6, -4), P(0, L, -2)] + [hull[3], hull[2], hull[1], hull[0]],
           "#5a3e28", INK, 1.2)
    a.poly(hull, "#7a5738" if sail else "#6a4a30", INK, 1.3)
    inner = [P(0, -L * 0.85, 4), P(W * 0.75, -L * 0.4, 4), P(W * 0.75, L * 0.55, 4), P(0, L * 0.85, 5), P(-W * 0.75, L * 0.55, 4), P(-W * 0.75, -L * 0.4, 4)]
    a.poly(inner, "#3b2a1d", INK, 0.9)
    for k in (-0.2, 0.25):
        a.line([P(-W * 0.75, k, 4), P(W * 0.75, k, 4)], WOOD_L, 2.2)
    if sail:
        for (gx, gy) in [(0.0, 0.45), (0.1, 0.25), (-0.1, 0.3)]:
            a.box(gx - 0.08, gx + 0.08, gy - 0.08, gy + 0.08, 4, 13, "#b08a58", WOOD, WOOD_D, sw=0.9)
        mx, my = P(0, -0.15, 4)
        a.line([(mx, my), (mx, my - 78)], INK, 3.2)
        a.line([(mx, my), (mx, my - 78)], WOOD_L, 1.6)
        a.poly([(mx + 2, my - 74), (mx + 34, my - 58), (mx + 32, my - 16), (mx + 2, my - 22)], "#e8dcc0", INK, 1.3)
        a.line([(mx + 4, my - 50), (mx + 32, my - 40)], "#2f4a6a", 2.4)  # the guild's stripe
        a.line([(mx, my - 78), (mx + 6, my - 82)], CRIMSON, 2)
    else:
        a.line([P(-W, 0.05, 6), P(-W - 0.35, -0.2, 2)], "#7a5738", 1.6)  # an oar
        a.ellipse(*P(0, 0.3, 6), 6, 3, "#8a8a7a", INK, 0.8)  # a net, heaped
    a.save("boat_supply" if sail else "boat")


def harbour_crates():
    """Crates, a barrel and sacks on the quay (scenario 9)."""
    a = Art()
    a.shadow(26, 12, cy=2)
    for (gx, gy) in [(-0.12, -0.05), (0.12, 0.05)]:
        a.box(gx - 0.12, gx + 0.12, gy - 0.12, gy + 0.12, 0, 14, "#b08a58", WOOD, WOOD_D, sw=1)
        a.line([P(gx - 0.12, gy + 0.12, 7), P(gx + 0.12, gy + 0.12, 7)], WOOD_D, 0.9)
    a.box(-0.1, 0.12, -0.08, 0.12, 14, 26, "#b08a58", WOOD, WOOD_D, sw=1)
    x, y = P(0.25, -0.22)
    a.poly([(x - 5, y), (x + 5, y), (x + 6, y - 13), (x - 6, y - 13)], WOOD, INK, 1)
    a.line([(x - 5.5, y - 4), (x + 5.5, y - 4)], "#6a6a6a", 1.1)
    a.ellipse(x, y - 13, 6, 2.2, WOOD_D, INK, 0.8)
    x, y = P(-0.28, 0.2)
    a.ellipse(x, y - 4, 6, 4.6, "#c9a86a", INK, 0.9)
    a.save("harbour_crates")


def net_rack():
    """Fishing nets drying on a rack (scenario 9's quay)."""
    a = Art()
    a.shadow(24, 9, cy=2)
    l, r = P(-0.3, 0.05), P(0.3, -0.05)
    for (x, y) in (l, r):
        a.line([(x, y), (x, y - 30)], INK, 3)
        a.line([(x, y), (x, y - 30)], WOOD_L, 1.5)
    a.line([(l[0], l[1] - 28), (r[0], r[1] - 28)], WOOD_D, 2.4)
    a.poly([(l[0] + 1, l[1] - 27), (r[0] - 1, r[1] - 27), (r[0] - 3, r[1] - 6), (l[0] + 4, l[1] - 4)], "#7a7a68", INK, 1, opacity=0.85)
    for k in range(1, 6):
        t = k / 6.0
        a.line([(l[0] + (r[0] - l[0]) * t, l[1] - 27 + (r[1] - l[1]) * t), (l[0] + 3 + (r[0] - l[0] - 6) * t, l[1] - 5 + (r[1] - l[1]) * t)], "#4a4a3c", 0.7)
    for k in range(1, 4):
        t = k / 4.0
        a.line([(l[0] + 1 + 0.5 * t, l[1] - 27 + 22 * t), (r[0] - 1 - 1.5 * t, r[1] - 27 + 22 * t)], "#4a4a3c", 0.7)
    a.save("net_rack")


def ferry_bell():
    """The ferry bell at the end of the quay (scenario 9): a bronze bell under a
    little shingled roof on two posts, its rope hanging down."""
    a = Art()
    a.shadow(18, 7, cy=2)
    l, r = P(-0.16, 0.06), P(0.16, -0.06)
    for (x, y) in (l, r):
        a.poly([(x - 2.5, y), (x + 2.5, y), (x + 2.5, y - 46), (x - 2.5, y - 46)], WOOD, INK, 1.1)
    a.line([(l[0], l[1] - 40), (r[0], r[1] - 40)], WOOD_D, 3)
    mx, my = (l[0] + r[0]) / 2, (l[1] + r[1]) / 2 - 46
    a.poly([(mx - 17, my + 2), (mx, my - 11), (mx + 17, my + 2), (mx + 15, my + 6), (mx, my - 5), (mx - 15, my + 6)], "#5a3e28", INK, 1.2)
    bx, by = mx, my + 8
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="#b08a3a" stroke="%s" stroke-width="1.1"/>'
          % (fmt(bx - 7), fmt(by + 13), fmt(bx - 6), fmt(by - 2), fmt(bx), fmt(by - 2), fmt(bx + 6), fmt(by - 2), fmt(bx + 7), fmt(by + 13), INK),
          [(bx - 8, by - 3), (bx + 8, by + 14)])
    a.line([(bx - 5, by + 11), (bx + 5, by + 11)], GOLD, 1)
    a.ellipse(bx, by + 14, 2, 1.6, "#6a5228", INK, 0.7)
    a.line([(bx, by + 15), (bx + 1, by + 30), (bx - 1, by + 36)], "#c8b080", 1.1)
    a.save("ferry_bell")


def beacon():
    """A small lighthouse on the river bank where the channel meets the sea
    (scenario 9): a round stone tower, a fire basket burning on top, a warm glow."""
    a = Art()
    a.shadow(26, 12, cy=3)
    r, h = 14, 92
    a.poly([(-r - 4, 0), (r + 4, 0), (r + 4, -8), (-r - 4, -8)], STONE_R, INK, 1.2)  # (the plinth)
    a.ellipse(0, -8, r + 4, 6, STONE_T, INK, 1.1)
    a.poly([(-r, -8), (r, -8), (r - 3, -h), (-r + 3, -h)], "#a8a296", INK, 1.3)
    a.poly([(0, -8), (r, -8), (r - 3, -h), (0, -h)], "#837d72", stroke=None)
    a.line([(-r, -8), (-r + 3, -h)], INK, 1.3)
    a.line([(r, -8), (r - 3, -h)], INK, 1.3)
    for k, z in enumerate((-30, -54, -78)):  # (stone bands)
        w = r - 3 * (-z) / h
        a.line([(-w, z), (w, z)], "#6e695f", 1.1)
    a.raw('<path d="M-3,-56 L-3,-66 Q0,-71 3,-66 L3,-56 Z" fill="#ffd970" stroke="%s" stroke-width="1"/>' % INK, [(-4, -71), (4, -55)])
    a.ellipse(0, -h, r, 5, STONE_T, INK, 1.1)
    _glow(a, 0, -h - 14, 40, 30, "#ffb850", 0.6)
    a.poly([(-9, -h - 2), (9, -h - 2), (12, -h - 12), (-12, -h - 12)], "#3a2e26", INK, 1.2)  # (the fire basket)
    for k in range(-2, 3):
        a.line([(k * 4, -h - 2), (k * 5, -h - 12)], "#5a4a3a", 1)
    a.poly([(-9, -h - 12), (-4, -h - 26), (0, -h - 18), (4, -h - 30), (9, -h - 12)], "#f08a2a", INK, 1)
    a.poly([(-5, -h - 12), (-1, -h - 21), (3, -h - 15), (6, -h - 12)], "#ffd970", stroke=None)
    a.save("beacon")


def wreck():
    """A boat's wreck half sunk in the shallows (scenario 9): a broken hull on
    its side, bare ribs, a snapped mast, water round it."""
    a = Art()
    a.ellipse(0, 4, 44, 14, "#cfe6f5", opacity=0.3)
    a.ellipse(0, 4, 38, 11, "#1d3a52", opacity=0.35)
    a.poly([P(-0.5, 0.1, 2), P(0.45, -0.25, 2), P(0.42, -0.3, 14), P(-0.45, 0.05, 20)], "#4a3422", INK, 1.3)  # (the hull's side)
    for k in range(5):
        t = -0.4 + 0.2 * k
        x0, y0 = P(t, -0.08 * k + 0.05, 2)
        a.line([(x0, y0), (x0 + 3, y0 - 22 - 3 * (k % 2)), (x0 + 9, y0 - 18)], "#5e4129", 2.2)
    a.line([P(-0.48, 0.08, 18), P(0.43, -0.28, 12)], "#3b2a1d", 2)
    a.line([P(0.05, -0.1, 6), P(0.35, -0.6, 30)], "#5e4129", 3)  # (the snapped mast)
    a.line([P(0.35, -0.6, 30), P(0.3, -0.55, 36)], "#5e4129", 2)
    for (x, y) in [(-26, 6), (22, 2), (-6, 10)]:
        a.line([(x - 6, y), (x + 6, y)], "#e8f2f8", 1, opacity=0.7)
    a.save("wreck")


def fish_rack():
    """Fish drying on a wooden rack by the shore (scenario 9)."""
    a = Art()
    a.shadow(26, 9, cy=2)
    l, r = P(-0.3, 0.08), P(0.3, -0.08)
    for (x, y) in (l, r):
        a.line([(x - 4, y), (x, y - 30), (x + 4, y)], WOOD, 2.2)
    a.line([(l[0], l[1] - 29), (r[0], r[1] - 29)], WOOD_D, 2.4)
    for k in range(1, 7):
        t = k / 7.0
        x, y = l[0] + (r[0] - l[0]) * t, l[1] - 29 + (r[1] - l[1]) * t
        a.line([(x, y), (x, y + 3)], "#c8b080", 0.8)
        a.poly([(x - 2, y + 3), (x + 2, y + 3), (x + 1.5, y + 14), (x, y + 17), (x - 1.5, y + 14)], "#9aa4a8" if k % 2 else "#7a8890", INK, 0.8)
    a.save("fish_rack")


def boat_upturned():
    """A rowboat lying upturned on the sand (scenario 9)."""
    a = Art()
    a.shadow(30, 9, cy=3)
    a.raw('<path d="M-30,2 Q-26,-14 0,-16 Q26,-14 30,2 Q0,8 -30,2 Z" fill="#6a4a30" stroke="%s" stroke-width="1.3"/>' % INK, [(-31, -17), (31, 9)])
    a.raw('<path d="M-30,2 Q0,8 30,2" fill="none" stroke="#3b2a1d" stroke-width="2.2"/>', [(-30, 2), (30, 8)])
    for k in (-14, 0, 14):
        a.line([(k, -15 + abs(k) * 0.08), (k * 1.1, 5 - abs(k) * 0.05)], "#4f3722", 1.1)
    a.line([(-32, -2), (-22, -18)], WOOD_L, 2)  # (an oar leaning on it)
    a.save("boat_upturned")


def mooring_post():
    """A mooring post on the quay with a coil of rope (scenario 9)."""
    a = Art()
    a.shadow(9, 4, cy=1)
    a.poly([(-4, 0), (4, 0), (4, -22), (-4, -22)], WOOD, INK, 1.1)
    a.poly([(0, 0), (4, 0), (4, -22), (0, -22)], WOOD_D, stroke=None)
    a.ellipse(0, -22, 4, 1.6, WOOD_L, INK, 0.9)
    for k in range(3):
        a.ellipse(0, -10 + k * 2.5, 6, 2, "none", "#c8b080", 1.4)
    a.ellipse(9, 1, 6, 2.6, "none", "#c8b080", 1.4)
    a.ellipse(9, 1, 3, 1.3, "none", "#c8b080", 1.2)
    a.save("mooring_post")


def driftwood():
    """Driftwood and seaweed washed up on the beach (scenario 9)."""
    a = Art()
    a.line([(-22, 4), (16, -6)], INK, 6)
    a.line([(-22, 4), (16, -6)], "#b8a88a", 4)
    a.line([(-4, -1), (4, -10)], INK, 3.4)
    a.line([(-4, -1), (4, -10)], "#b8a88a", 2)
    a.line([(-10, 8), (12, 4)], INK, 4)
    a.line([(-10, 8), (12, 4)], "#a8987a", 2.4)
    for (x, y) in [(-16, 9), (8, 9), (20, -2)]:
        a.raw('<path d="M%s,%s q3,-4 6,0 q3,-4 6,0" fill="none" stroke="#3e5a2a" stroke-width="1.6"/>' % (fmt(x - 6), fmt(y)), [(x - 6, y - 4), (x + 6, y)])
    a.save("driftwood")


def gull():
    """A gull in flight, wings up (scenario 9's harbour: they circle the beacon)."""
    a = Art()
    a.raw('<path d="M-12,-2 Q-6,-8 0,0 Q6,-8 12,-2" fill="none" stroke="%s" stroke-width="3.2" stroke-linecap="round"/>' % INK, [(-13, -9), (13, 2)])
    a.raw('<path d="M-12,-2 Q-6,-8 0,0 Q6,-8 12,-2" fill="none" stroke="#f2f2ee" stroke-width="1.8" stroke-linecap="round"/>', [(-13, -9), (13, 2)])
    a.ellipse(0, 0, 2.6, 1.6, "#f2f2ee", INK, 0.8)
    a.save("gull")


def relic_sword():
    """The First King's Hand lying on the ground (scenario 9: dropped): an
    ornate old sword, a gold hilt with a red stone, in a faint holy glow."""
    a = Art()
    _glow(a, 0, -4, 36, 18, "#ffe9a0", 0.55)
    a.line([(-24, 6), (14, -8)], INK, 4.4)
    a.line([(-24, 6), (14, -8)], "#d8dde4", 2.4)
    a.line([(-22, 5), (12, -7.5)], "#ffffff", 0.8, opacity=0.8)
    a.line([(12, -15), (18, -1)], INK, 4.6)  # the crossguard
    a.line([(12, -15), (18, -1)], GOLD, 2.8)
    a.line([(15, -8), (24, -11)], INK, 4)  # the grip
    a.line([(15, -8), (24, -11)], "#6a2a24", 2.2)
    a.ellipse(25.5, -11.5, 3.2, 3, GOLD, INK, 1)  # the pommel
    a.ellipse(15, -8, 2, 2, CRIMSON, INK, 0.8)
    a.save("relic_sword")


def city_house(name, ruin, seed, wall, roof, roof_front, storeys, timber=False, gable=False):
    """A town house on one tile of the capital (the city's blocked tiles): one
    to three storeys of plaster and timber, a steep roof; ruined, the roof
    gone and the walls broken, beams charred."""
    rng = random.Random(seed)
    a = Art()
    x0, x1, y0, y1 = -0.42, 0.42, -0.42, 0.42
    a.poly(diamond(0.9, 0.9), "#3a3733", stroke=None, opacity=0.45)
    h = 22 * storeys
    wl, wr = wall
    if ruin:
        # broken walls: a jagged top, a gap, charred beams sticking out
        tops = [h * rng.uniform(0.45, 0.95) for _ in range(5)]
        pts_l = [P(x0, y1, 0), P(x1, y1, 0)]
        for k in range(4, -1, -1):
            pts_l.append(P(x0 + (x1 - x0) * k / 4.0, y1, tops[k]))
        a.poly(pts_l, wl, INK, 1.3)
        tops_r = [h * rng.uniform(0.35, 0.9) for _ in range(5)]
        if gable:  # the side wall still stands up to its gable, one corner broken off
            tops = [t * 0.7 for t in tops]
            tops_r = [h * 0.95 + 22 * (1 - abs(k - 2) / 2.0) for k in range(5)]
            tops_r[4] = h * 0.55
        pts_r = [P(x1, y1, 0), P(x1, y0, 0)]
        for k in range(4, -1, -1):
            pts_r.append(P(x1, y1 + (y0 - y1) * k / 4.0, tops_r[k]))
        a.poly(pts_r, wr, INK, 1.3)
        for k in range(3):
            gx = x0 + 0.15 + 0.25 * k
            a.line([P(gx, y1, tops[k + 1] - 4), P(gx + 0.12, y1 + 0.2, tops[k + 1] + 10)], INK, 4)
            a.line([P(gx, y1, tops[k + 1] - 4), P(gx + 0.12, y1 + 0.2, tops[k + 1] + 10)], "#2a1e15", 2.4)
        for _ in range(6):
            x, y = P(rng.uniform(-0.3, 0.5), rng.uniform(0.35, 0.6))
            _block(a, rng, x, y, rng.uniform(3, 5.5))
        _opening(a, "side", x1, 0.05, -0.12, h * 0.15, h * 0.15 + 12, "#15120f")
        a.save(name)
        return
    a.box(x0, x1, y0, y1, 0, h, wl, wl, wr)
    for k in range(1, storeys):  # timber bands between the storeys
        a.line([P(x0, y1, 22 * k), P(x1, y1, 22 * k), P(x1, y0, 22 * k)], WOOD_D, 2)
    if timber:  # half-timbered: posts at the corners and between the windows, braces
        for k in range(storeys):
            z0, z1 = 22 * k, 22 * k + 22
            for gx in (x0 + 0.02, -0.13, 0.13, x1 - 0.02):
                a.line([P(gx, y1, z0), P(gx, y1, z1)], WOOD_D, 1.8)
            a.line([P(x0 + 0.02, y1, z0), P(-0.13, y1, z1)], WOOD_D, 1.5)
            a.line([P(x1 - 0.02, y1, z0), P(0.13, y1, z1)], WOOD_D, 1.5)
            for gy in (y1 - 0.02, 0.0, y0 + 0.02):
                a.line([P(x1, gy, z0), P(x1, gy, z1)], WOOD_D, 1.6)
        a.line([P(x0, y1, h), P(x1, y1, h), P(x1, y0, h)], WOOD_D, 2)
    for k in range(storeys):
        z = 22 * k + 8
        for gx in ((-0.28, 0.26) if k == 0 else (-0.28, -0.04, 0.2)):
            lit = rng.random() < 0.25
            _opening(a, "front", y1, gx, gx + 0.1, z, z + 10, GLOW if lit else "#1c1916")
        for gy in (0.24, -0.06):
            _opening(a, "side", x1, gy, gy - 0.1, z, z + 10, "#1c1916")
    _opening(a, "front", y1, -0.08, 0.06, 0, 15, "#2b1e14", sw=1)
    ridge = h + 26
    ym = 0.0
    a.poly([P(x0 - 0.05, y0 - 0.05, h - 2), P(x1 + 0.05, y0 - 0.05, h - 2), P(x1 + 0.05, ym, ridge), P(x0 - 0.05, ym, ridge)], roof, INK, 1.2)
    a.poly([P(x1, y0, h), P(x1, ym, ridge), P(x1, y1, h)], wr, INK, 1.2)
    a.poly([P(x0 - 0.05, ym, ridge), P(x1 + 0.05, ym, ridge), P(x1 + 0.05, y1 + 0.05, h - 2), P(x0 - 0.05, y1 + 0.05, h - 2)], roof_front, INK, 1.2)
    a.box(-0.3, -0.18, -0.12, 0.0, ridge - 14, ridge + 8, STONE_T, STONE_L, STONE_R, sw=1.1)  # chimney
    a.save(name)


def city_houses():
    city_house("house_0", False, 801, ("#b8ad98", "#958b78"), "#4a3c34", "#5a4a40", 2)
    city_house("house_1", False, 802, ("#a69a86", "#857a68"), "#3e4650", "#4c5662", 3)
    city_house("house_2", False, 803, ("#c2b49c", "#9c8f7a"), "#5a3228", "#6a3e30", 1)
    city_house("house_ruin_0", True, 804, ("#8e8578", "#6e665c"), None, None, 2)
    city_house("house_ruin_1", True, 805, ("#9a907f", "#776f63"), None, None, 3)
    city_house("house_3", False, 806, ("#cfc5ae", "#a99f8a"), "#3c4a3a", "#4a5a46", 2, timber=True)
    city_house("house_ruin_2", True, 807, ("#a89c86", "#83796a"), None, None, 2, gable=True)


def city_rubble():
    """Decor in the city: a small heap of broken setts and a charred beam (walkable)."""
    rng = random.Random(806)
    a = Art()
    a.line([P(-0.15, 0.05, 1), P(0.18, -0.05, 4)], INK, 4)
    a.line([P(-0.15, 0.05, 1), P(0.18, -0.05, 4)], "#2a1e15", 2.4)
    for _ in range(6):
        x, y = rand_in_diamond(rng, 0.35)
        _block(a, rng, x, y, rng.uniform(2.5, 4.5))
    a.save("city_rubble")


def throne_hall():
    """The throne hall of Veliron (scenario 11), a 3x3 landmark: a great dark
    hall of pale stone, a high gabled roof of slate, tall lancet windows lit
    cold blue from within, a tower with the crown's banner, broad steps up to
    an open gate."""
    k = 3.0
    a = Art()
    a.poly(diamond(k * 0.92), "#2e2b28", stroke=None, opacity=0.5)
    sl, sr, st = "#a8a49c", "#827e77", "#bcb8b0"
    x0, x1, y0, y1 = -1.15, 1.15, -1.15, 1.15
    H = 62
    a.box(x0, x1, y0, y1, 0, H, st, sl, sr, sw=1.6)
    for z in (20, 40):
        a.line([P(x0, y1, z), P(x1, y1, z), P(x1, y0, z)], "#5a5751", 1, opacity=0.6)
    # lancet windows lit cold from within
    for gx in (-0.95, -0.65, 0.5, 0.8):
        _opening(a, "front", y1, gx, gx + 0.14, 14, 38, "#9ac0ff", arch=10, sw=1.1)
    for gy in (0.75, 0.15, -0.45):
        _opening(a, "side", x1, gy, gy - 0.14, 14, 38, "#6a88b8", arch=10, sw=1.1)
    # the gate and its steps
    for s_ in range(3):
        a.box(-0.36 - 0.06 * s_, 0.36 + 0.06 * s_, y1, y1 + 0.1 + 0.1 * s_, 0, 6 - 2 * s_, "#9a968e", "#8a867f", "#6e6a64", sw=1.0)
    _opening(a, "front", y1, -0.2, 0.2, 6, 34, "#0e0d10", arch=14, sw=1.4)
    gx, gy = P(0.0, y1, 20)
    _glow(a, gx, gy, 10, 14, "#b8d0ff", 0.35)
    # the roof: a high slate gable along the hall
    ridge = H + 52
    a.poly([P(x0 - 0.06, y0 - 0.06, H - 3), P(x1 + 0.06, y0 - 0.06, H - 3), P(x1 + 0.06, 0, ridge), P(x0 - 0.06, 0, ridge)], "#2e3640", INK, 1.4)
    a.poly([P(x1, y0, H), P(x1, 0, ridge), P(x1, y1, H)], sr, INK, 1.4)
    a.poly([P(x0 - 0.06, 0, ridge), P(x1 + 0.06, 0, ridge), P(x1 + 0.06, y1 + 0.06, H - 3), P(x0 - 0.06, y1 + 0.06, H - 3)], "#3a4450", INK, 1.4)
    a.line([P(x0 - 0.06, 0, ridge), P(x1 + 0.06, 0, ridge)], "#1e242a", 2.6)
    # the tower at the back corner, with the crown's pale banner
    tx0, tx1, ty0, ty1 = -1.15, -0.55, -1.15, -0.55
    th = 150
    a.box(tx0, tx1, ty0, ty1, H, th, st, sl, sr, sw=1.5)
    a.poly([P(tx0 - 0.04, ty1 + 0.04, th), P(tx1 + 0.04, ty1 + 0.04, th), P(tx1 + 0.04, ty0 - 0.04, th), P((tx0 + tx1) / 2, (ty0 + ty1) / 2, th + 46)], "#2e3640", INK, 1.3)
    wx, wy = P(tx1, (ty0 + ty1) / 2, th - 30)
    a.poly([(wx - 3, wy + 2), (wx + 3, wy + 4), (wx + 3, wy - 12), (wx - 3, wy - 14)], "#9ac0ff", INK, 0.9)
    bx, by = P((tx0 + tx1) / 2, (ty0 + ty1) / 2, th + 46)
    a.line([(bx, by), (bx, by - 26)], INK, 2)
    a.poly([(bx, by - 26), (bx + 18, by - 23), (bx + 14, by - 17), (bx + 18, by - 12), (bx, by - 14)], "#d8dce8", INK, 1)
    a.raw('<path d="M%s,%s L%s,%s L%s,%s L%s,%s L%s,%s Z" fill="#9ab0d8"/>'
          % (fmt(bx + 4), fmt(by - 17), fmt(bx + 5), fmt(by - 22), fmt(bx + 7), fmt(by - 19), fmt(bx + 9), fmt(by - 22), fmt(bx + 10), fmt(by - 17)),
          [(bx + 3, by - 23), (bx + 11, by - 16)])
    a.save("throne_hall")


def portraits_1011():
    """The speakers of scenarios 10 and 11."""
    # Halvard, the Legion's marshal: an old soldier's square, weathered face,
    # cropped grey hair and beard, a scar across the cheek, pale eyes under
    # heavy brows, dark plate with a gold-trimmed collar.
    portrait_svg("portrait_halvard", f"""
  <path d="M2 66 Q2 44 18 40 L46 40 Q62 44 62 66Z" fill="#5e626c" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 44 L32 52 L50 44" fill="none" stroke="{GOLD}" stroke-width="2.4"/>
  <ellipse cx="12" cy="47" rx="10" ry="7" fill="#6e727c" stroke="{INK}" stroke-width="2"/>
  <ellipse cx="52" cy="47" rx="10" ry="7" fill="#5a5e68" stroke="{INK}" stroke-width="2"/>
  <rect x="26" y="34" width="12" height="9" fill="#c0bcb8" stroke="{INK}" stroke-width="1.8"/>
  <path d="M19 24 Q18 11 32 10 Q46 11 45 24 Q45 37 32 40 Q19 37 19 24Z" fill="#cac4be" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 21 Q18 8 32 7 Q46 8 45 21 Q41 13 32 13 Q23 13 19 21Z" fill="#8e8c8a" stroke="{INK}" stroke-width="2"/>
  <path d="M21 29 Q22 41 32 42 Q42 41 43 29 Q39 35 32 35 Q25 35 21 29Z" fill="#9a9896" stroke="{INK}" stroke-width="1.6"/>
  <path d="M23 21.5 L29.5 22.5 M34.5 22.5 L41 21.5" stroke="#6a6866" stroke-width="2.2" stroke-linecap="round"/>
  <ellipse cx="27" cy="25.5" rx="1.8" ry="1.2" fill="#dce6f2" stroke="#7a8a9a" stroke-width="0.7"/>
  <ellipse cx="37" cy="25.5" rx="1.8" ry="1.2" fill="#dce6f2" stroke="#7a8a9a" stroke-width="0.7"/>
  <path d="M39 27 L44 33" stroke="#a07a72" stroke-width="1.3"/>
  <path d="M28 33 L36 33" stroke="#6a5a56" stroke-width="1.5" stroke-linecap="round"/>""", bg="#22242a")
    # Fiona at the end: as in scenario 7, but pale, the curse in her veins,
    # her eyes gone black.
    portrait_svg("portrait_fiona_cursed", f"""
  <circle cx="32" cy="28" r="26" fill="#2a0e2e" opacity="0.5"/>
  <path d="M20 24 Q10 40 14 58 L23 52 Q19 40 22 30Z" fill="#8a4a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M44 24 Q54 40 50 58 L41 52 Q45 40 42 30Z" fill="#8a4a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#243a6a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M20 44 Q32 54 44 44" fill="none" stroke="#c8ccd8" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#cfc2ba" stroke="{INK}" stroke-width="1.8"/>
  <path d="M28 37 Q30 41 29 44 M35 36 Q34 40 36 44" fill="none" stroke="#4a1e4e" stroke-width="1.2"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#dcd0ca" stroke="{INK}" stroke-width="2.2"/>
  <path d="M21 30 Q24 27 23 33 M43 29 Q40 28 41 34 M30 36 Q32 33 34 36" fill="none" stroke="#4a1e4e" stroke-width="1.1"/>
  <path d="M19 27 Q15 8 32 7 Q49 8 45 27 Q44 16 36 14 Q30 18 21 17 Q20 22 19 27Z" fill="#8a4a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M20 15 Q32 10 44 15" fill="none" stroke="#d8dce8" stroke-width="2"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#5a2a1a" stroke-width="1.5" stroke-linecap="round"/>
  <ellipse cx="27" cy="26" rx="2.4" ry="1.8" fill="#050306"/><ellipse cx="37" cy="26" rx="2.4" ry="1.8" fill="#050306"/>
  <path d="M28.5 33.5 L35.5 33.5" stroke="#6a3a4a" stroke-width="1.4" stroke-linecap="round"/>""", bg="#140a16")


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


def thornling():
    """The druid's summon: a squat walking bramble of twisted vines, thorns all
    over, root-feet, two amber eyes and one small pink flower."""
    a = Art()
    a.shadow(12, 5, opacity=0.4)
    vine, vine_d, vine_l = "#3e5a2c", "#2a3e1e", "#5a7a3a"
    for (x0, x1) in [(-6, -9), (5, 8)]:  # root-feet
        a.line([(x0, -8), (x0 - 1, -3), (x1, 0)], INK, 3.6)
        a.line([(x0, -8), (x0 - 1, -3), (x1, 0)], "#6a4a28", 2)
    a.poly([(-11, -8), (-13, -20), (-8, -30), (0, -33), (8, -30), (13, -20), (11, -8), (0, -6)], vine, INK, 1.4)  # body
    a.poly([(0, -33), (8, -30), (13, -20), (11, -8), (0, -6)], vine_d, stroke=None, opacity=0.6)
    for pts in [[(-10, -12), (-4, -20), (-9, -27)], [(9, -11), (3, -19), (8, -26)], [(-5, -9), (1, -16), (-2, -28)]]:  # twisting vines
        a.line(pts, vine_l, 1.6)
    for (x, y, dx, dy) in [(-13, -20, -4, -1), (-11, -27, -3, -3), (13, -20, 4, -1), (11, -27, 3, -3), (-12, -12, -4, 1), (12, -12, 4, 1), (-3, -33, -1, -4), (4, -33, 1, -4)]:  # thorns
        a.poly([(x, y - 1.2), (x + dx, y + dy), (x, y + 1.2)], "#c8b890", INK, 0.6)
    for (x, y, r) in [(-15, -17, 3.8), (15, -18, 3.8)]:  # bramble fists
        a.ellipse(x, y, r, r * 0.9, vine_l if x < 0 else vine, INK, 1.2)
    a.ellipse(-3, -24, 1.6, 1.4, "#f0c040")  # eyes
    a.ellipse(3, -24, 1.6, 1.4, "#f0c040")
    for k in range(5):  # the flower
        ang = k / 5 * math.tau
        a.ellipse(6 + math.cos(ang) * 2.2, -31 + math.sin(ang) * 2.2, 1.6, 1.6, "#e88ab0", INK, 0.5)
    a.ellipse(6, -31, 1.2, 1.2, "#f8e060")
    a.save("unit_thornling")


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


def shield_bearer_branches():
    """The shield bearer's specialisations: warrior, berserker, halberdier."""
    steel, steel_d = "#9aa0a8", "#6a7078"

    def warrior(a, layer):
        if layer == "back":
            a.ellipse(-8, -20, 7, 8, WOOD, INK, 1.4)  # round shield on his back arm
            a.ellipse(-8, -20, 7, 8, "none", steel, 1.6)
            a.ellipse(-8, -20, 2.2, 2.4, steel, INK, 0.8)
        else:
            a.poly([(-7, -27), (7, -27), (6, -11), (-6, -11)], steel_d, INK, 1.1)  # mail
            for y in (-24, -20, -16):
                a.line([(-6, y), (6, y)], "#555b62", 0.7)
            a.poly([(-3.5, -27), (3.5, -27), (3, -9), (-3, -9)], CRIMSON, INK, 0.9)  # tabard
            a.line([(4, -21), (10, -27)], INK, 4)  # arm raised
            a.line([(10, -27), (14, -46)], INK, 3.6)  # sword
            a.line([(10, -27), (14, -46)], "#d8dde2", 2)
            a.line([(7.5, -27.5), (12.5, -26.5)], GOLD, 1.8)  # crossguard

    def warrior_helm(a):
        a.raw('<path d="M-7,-31 Q-7,-42 0,-42 Q7,-42 7,-31 Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (steel, INK), [(-8, -43), (8, -30)])
        a.line([(0, -42), (0, -31)], steel_d, 1.4)  # nose guard ridge
        a.raw('<path d="M-6,-39 Q-12,-42 -11,-48 Q-8,-43 -4,-41 Z" fill="#e8dcc0" stroke="%s" stroke-width="0.9"/>' % INK, [(-12, -49), (-4, -38)])
        a.raw('<path d="M6,-39 Q12,-42 11,-48 Q8,-43 4,-41 Z" fill="#e8dcc0" stroke="%s" stroke-width="0.9"/>' % INK, [(4, -49), (12, -38)])
    person("unit_warrior", (steel_d, "#555b62"), hat=warrior_helm, extra=warrior)

    def berserker(a, layer):
        if layer == "back":
            a.raw('<path d="M-4,-29 Q-12,-28 -11,-20 L-12,-12 L-10,-14 L-9,-11 L-7,-13 L-5,-11 Z" fill="#7a5a3a" stroke="%s" stroke-width="1"/>' % INK, [(-12, -30), (-4, -11)])  # shaggy fur cloak
            for (x, y) in ((-9, -24), (-8, -19), (-10, -16)):
                a.line([(x, y), (x + 1.5, y + 2)], "#a07a52", 1)
        else:
            a.poly([(-6, -27), (6, -27), (6, -14), (-6, -14)], "#d0a080", INK, 1)  # bare chest
            a.line([(-6, -18), (6, -18)], "#5a3a22", 2.4)  # belt
            a.line([(4, -21), (11, -24)], INK, 4.2)  # arm
            a.line([(4, -21), (11, -24)], "#d0a080", 2.6)
            a.line([(9, -6), (13, -44)], INK, 3.4)  # great axe
            a.line([(9, -6), (13, -44)], WOOD_L, 1.8)
            a.raw('<path d="M12,-44 Q22,-46 22,-36 Q16,-38 12,-36 Z" fill="#b8bec6" stroke="%s" stroke-width="1.1"/>' % INK, [(11, -47), (23, -35)])
            a.raw('<path d="M12,-44 Q4,-46 5,-38 Q9,-39 12,-37 Z" fill="#b8bec6" stroke="%s" stroke-width="1.1"/>' % INK, [(4, -47), (13, -36)])

    def wild_hair(a):
        # a mane over the top and back of the head, spiky, leaving the face free
        a.raw('<path d="M-7,-30 L-10,-33 L-8,-36 L-10,-40 L-6,-40 L-5,-44 L-1,-41 L1,-45 L3,-40 L7,-41 L5,-37 Q2,-39 -2,-37 Q-5,-35 -5,-30 Z" fill="#b8481e" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % INK, [(-11, -46), (8, -29)])
        # a full beard on the chin (he faces right)
        a.raw('<path d="M-2,-31 Q0,-28 6,-30 Q7,-27 5,-24 L3,-25 L2,-22 L0,-25 L-2,-23 Q-3,-27 -2,-31 Z" fill="#b8481e" stroke="%s" stroke-width="1" stroke-linejoin="round"/>' % INK, [(-3, -32), (8, -21)])
    person("unit_berserker", ("#6a4a2c", "#5a3c22"), hat=wild_hair, skin="#d0a080", extra=berserker)

    def halberdier(a, layer):
        if layer == "front":
            a.poly([(-6, -27), (6, -27), (5, -14), (-5, -14)], steel, INK, 1.1)  # breastplate
            a.line([(0, -26), (0, -15)], steel_d, 1)
            a.line([(4, -20), (9, -21)], INK, 4)  # arm
            a.line([(9, 0), (10, -54)], INK, 3.2)  # the long shaft
            a.line([(9, 0), (10, -54)], WOOD_L, 1.7)
            a.raw('<path d="M10,-50 Q19,-50 18,-41 Q14,-43 10,-42 Z" fill="#c8ced6" stroke="%s" stroke-width="1.1"/>' % INK, [(9, -51), (19, -40)])  # axe blade
            a.poly([(9, -47), (5, -49), (9, -45)], "#c8ced6", INK, 0.9)  # back hook
            a.poly([(9.2, -54), (10.2, -62), (11.2, -54)], "#c8ced6", INK, 1)  # spike

    def kettle_hat(a):
        a.raw('<path d="M-10,-34 L10,-34 L6,-37 Q6,-43 0,-43 Q-6,-43 -6,-37 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (steel, INK), [(-11, -44), (11, -33)])
    person("unit_halberdier", ("#3a4a6a", "#2c3a54"), hat=kettle_hat, extra=halberdier)


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


def acolytes():
    """The acolyte line: robed in cream and gold. The acolyte prays (hands folded, head bowed) and
    raises its arms to cast (unit_acolyte_cast). The game draws their glow behind them."""
    robe = ("#e4dccb", "#c8bea8")

    def hood(col):
        def f(a):  # a deep cowl, bowed forward
            a.raw('<path d="M-7,-29 Q-9,-43 1,-43 Q9,-42 8,-33 L5,-32 Q2,-38 -3,-36 Q-5,-33 -5,-28 Z" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (col, INK), [(-9, -44), (9, -28)])
        return f

    def praying(a, layer):
        if layer == "front":
            a.poly([(-2, -27), (2, -27), (1.5, -6), (-1.5, -6)], GOLD, INK, 0.7)  # stole
            a.line([(-3, -24), (4, -20)], INK, 4.2)  # arm to the folded hands
            a.line([(-3, -24), (4, -20)], robe[1], 2.6)
            a.poly([(4, -26), (7, -25), (7, -19), (4, -19)], "#d8b08c", INK, 1)  # hands together
    person("unit_acolyte", robe, hat=hood("#d4cab4"), robe=True, extra=praying)

    def casting(a, layer):
        if layer == "back":
            a.line([(-4, -26), (-10, -42)], INK, 4.2)  # the far arm, raised
            a.line([(-4, -26), (-10, -42)], robe[1], 2.6)
            a.ellipse(-10, -43.5, 2.2, 2.2, "#d8b08c", INK, 0.9)
        else:
            a.poly([(-2, -27), (2, -27), (1.5, -6), (-1.5, -6)], GOLD, INK, 0.7)
            a.line([(4, -26), (11, -42)], INK, 4.2)
            a.line([(4, -26), (11, -42)], robe[0], 2.6)
            a.ellipse(11, -43.5, 2.2, 2.2, "#d8b08c", INK, 0.9)
            a.ellipse(0, -48, 8, 5, "#fff2c0", opacity=0.45)
            a.ellipse(0, -48, 3, 2, "#fffbe6", opacity=0.9)

    def raised_hood(a):  # head up while casting
        a.raw('<path d="M-7,-30 Q-8,-43 0,-43 Q8,-43 7,-34 L4,-36 Q0,-40 -4,-36 Q-5,-33 -5,-28 Z" fill="#d4cab4" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-8, -44), (8, -28)])
    person("unit_acolyte_cast", robe, hat=raised_hood, robe=True, extra=casting)

    def inquisitor(a, layer):
        if layer == "back":
            a.poly([(-10, -12), (-4, -12), (-4, -28), (-10, -28)], "#2a1a1a", INK, 1)  # cloak
        else:
            a.poly([(-6, -27), (6, -27), (5, -12), (-5, -12)], "#8a8f96", INK, 1)  # breastplate
            a.line([(0, -25), (0, -14)], GOLD, 2.2)  # the holy cross on it
            a.line([(-3.5, -21.5), (3.5, -21.5)], GOLD, 2.2)
            a.line([(4, -20), (10, -22)], INK, 4)  # arm
            a.line([(10, -8), (12, -40)], INK, 3.4)  # warhammer
            a.line([(10, -8), (12, -40)], WOOD_L, 1.8)
            a.poly([(6, -44), (18, -42), (18, -36), (6, -38)], "#8a8f96", INK, 1.2)
            a.line([(12, -41), (12, -39)], GOLD, 1.2)

    def helm(a):
        a.raw('<path d="M-7,-31 Q-7,-42 0,-42 Q7,-42 7,-31 L7,-29 L-7,-29 Z" fill="#6a1a20" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -43), (8, -28)])
        a.line([(0, -42), (0, -46)], GOLD, 1.6)
        a.line([(-2, -44.5), (2, -44.5)], GOLD, 1.6)
    person("unit_inquisitor", ("#3a2224", "#2c1a1c"), hat=helm, extra=inquisitor)

    def priest(a, layer):
        if layer == "back":
            a.line([(-9, -2), (-9, -48)], INK, 3.4)  # crosier
            a.line([(-9, -2), (-9, -48)], GOLD_D, 1.8)
            a.ellipse(-9, -52, 9, 9, "#fff2c0", opacity=0.35)
            a.ellipse(-9, -52, 4.2, 4.2, GOLD, INK, 1.1)  # a sun disc
            for k in range(8):
                ang = k * math.pi / 4
                a.line([(-9 + math.cos(ang) * 5, -52 + math.sin(ang) * 5), (-9 + math.cos(ang) * 7.5, -52 + math.sin(ang) * 7.5)], GOLD, 1.1)
        else:
            a.poly([(-2.5, -27), (2.5, -27), (2, -3), (-2, -3)], GOLD, INK, 0.8)  # broad stole
            a.line([(-1, -14), (1, -14)], "#fffbe6", 1)
            a.line([(4, -22), (9, -18)], INK, 4)
            a.ellipse(9.5, -17.5, 2.2, 2.2, "#d8b08c", INK, 0.9)

    def mitre(a):
        a.raw('<path d="M-6,-36 L-5,-47 L0,-52 L5,-47 L6,-36 Z" fill="#f2ecdc" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % INK, [(-7, -53), (7, -35)])
        a.line([(0, -51), (0, -37)], GOLD, 1.6)
        a.line([(-6, -37.5), (6, -37.5)], GOLD, 1.6)
    person("unit_high_priest", ("#f0ead8", "#d4ccb6"), hat=mitre, robe=True, extra=priest)


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


def thief():
    """Lean, hooded figure in dark green with a dagger and a face mask."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-6, -24), (-11, -14)], INK, 3.6)  # back arm
            a.line([(-6, -24), (-11, -14)], "#233a20", 2.2)
        else:
            a.poly([(-4.5, -31), (6, -31), (5.5, -28), (-4, -28)], "#141a12", INK, 0.8)  # mask
            a.line([(4, -21), (11, -17)], INK, 3.6)  # dagger arm, low and forward
            a.line([(4, -21), (11, -17)], "#2e4a2a", 2.2)
            a.line([(10, -16.5), (12, -19.5)], INK, 2.2)  # guard
            a.poly([(11, -18.5), (13, -17), (20, -23), (19.5, -24)], "#c8ccd4", INK, 0.9)  # blade
            a.poly([(-8, -14), (-2, -14), (-3, -9), (-8, -10)], "#6a5230", INK, 0.9)  # belt pouch
    person("unit_thief", ("#2e4a2a", "#233a20"), hood="#1f3320", skin="#c8a080", extra=extra)


def gargoyle(frame):
    """Grey stone gargoyle with horns and bat wings, flying (no shadow: the
    game draws it on the ground). Two frames: wings up / wings down."""
    a = Art()
    stone, stone_d, stone_l = "#7c7f86", "#5d6068", "#a2a6ae"
    if frame == 0:  # wings up
        wing_l = [(-5, -26), (-24, -46), (-20, -38), (-28, -36), (-21, -30), (-26, -24), (-8, -20)]
        wing_r = [(5, -26), (24, -46), (20, -38), (28, -36), (21, -30), (26, -24), (8, -20)]
    else:  # wings down
        wing_l = [(-5, -24), (-26, -20), (-21, -16), (-27, -11), (-19, -10), (-21, -4), (-7, -16)]
        wing_r = [(5, -24), (26, -20), (21, -16), (27, -11), (19, -10), (21, -4), (7, -16)]
    a.poly(wing_l, stone_d, INK, 1.3)
    a.poly(wing_r, stone_d, INK, 1.3)
    a.line([wing_l[0], wing_l[1]], stone_l, 1.4)
    a.line([wing_r[0], wing_r[1]], stone_l, 1.4)
    # hunched body and tucked legs with claws
    a.poly([(-7, -12), (7, -12), (9, -26), (-9, -26)], stone, INK, 1.4)
    a.poly([(0, -12), (7, -12), (9, -26), (0, -26)], stone_d, stroke=None, opacity=0.6)
    a.line([(-4, -12), (-6, -6)], INK, 4.2)
    a.line([(4, -12), (6, -6)], INK, 4.2)
    a.line([(-4, -12), (-6, -6)], stone, 2.6)
    a.line([(4, -12), (6, -6)], stone, 2.6)
    a.line([(-8, -5), (-4, -6)], INK, 1.6)
    a.line([(4, -6), (8, -5)], INK, 1.6)
    a.poly([(1, -10), (-2, -3), (4, -1), (2, -3)], stone_d, INK, 1)  # tail
    # head: horns, heavy brow, glowing eyes, fangs
    a.poly([(-5, -34), (-9, -41), (-3, -36)], stone_l, INK, 1)
    a.poly([(5, -34), (9, -41), (3, -36)], stone_l, INK, 1)
    a.ellipse(0, -31, 6.5, 5.5, stone, INK, 1.3)
    a.line([(-5, -33), (5, -33)], INK, 1.6)
    a.ellipse(-2.3, -31.5, 1.3, 1, "#ffb02a")
    a.ellipse(2.3, -31.5, 1.3, 1, "#ffb02a")
    a.poly([(-2, -27.5), (-1, -25), (0, -27.5)], "#e8e4dc", INK, 0.5)
    a.poly([(0.5, -27.5), (1.5, -25), (2.5, -27.5)], "#e8e4dc", INK, 0.5)
    a.save("unit_gargoyle" if frame == 0 else "unit_gargoyle_flap", fixed=(-31, -50, 31, 3))


def vulture(frame):
    """A vulture in flight: dark brown plumage, broad wings with spread finger
    feathers, a white ruff, bald red head, hooked pale beak (the game draws
    the shadow). Two frames: wings up / wings down."""
    a = Art()
    dark, mid, light = "#3a2a20", "#5a4232", "#7a5a44"
    if frame == 0:  # wings up, wide
        l = [(-5, -26), (-16, -38), (-28, -42), (-31, -39), (-33, -35), (-30, -33), (-31, -29), (-26, -28), (-18, -26), (-8, -21)]
    else:  # wings down
        l = [(-5, -24), (-16, -20), (-27, -14), (-30, -10), (-31, -6), (-27, -6), (-26, -2), (-21, -5), (-14, -12), (-7, -18)]
    r = [(-x, y) for x, y in l]
    for pts in (l, r):
        a.poly(pts, dark, INK, 1.3)
        a.line([pts[0], pts[3]], mid, 1.8)  # the wing's leading edge
        for i in (4, 6):  # finger feathers
            a.line([pts[i - 1], pts[i]], light, 0.9)
    a.poly([(-6, -28), (6, -28), (4, -14), (0, -11), (-4, -14)], mid, INK, 1.3)  # body
    a.poly([(-3, -14), (3, -14), (0, -8)], dark, INK, 1)  # tail
    a.ellipse(0, -28, 5.5, 2.6, "#e8e0d0", INK, 0.9)  # white ruff
    a.ellipse(0, -32.5, 3.6, 3.3, "#c86a5a", INK, 1.1)  # bald head
    a.poly([(1.5, -32), (5.5, -31), (4, -28.5), (2, -30)], "#e0d4a8", INK, 0.8)  # hooked beak
    a.ellipse(-0.6, -33.4, 0.8, 0.8, "#1a0f0a")
    a.save("unit_vulture" if frame == 0 else "unit_vulture_flap", fixed=(-34, -50, 34, 3))


def vulture_landed():
    """A vulture on the ground, eating: hunched, wings half folded, bald red
    head down at its meal."""
    a = Art()
    dark, mid = "#3a2a20", "#5a4232"
    a.poly([(-13, -10), (-7, -24), (-2, -20), (-4, -8)], dark, INK, 1.3)  # wing, half folded
    a.poly([(13, -10), (7, -24), (2, -20), (4, -8)], dark, INK, 1.3)
    a.poly([(-7, -22), (6, -22), (8, -9), (0, -5), (-8, -9)], mid, INK, 1.4)  # body
    a.poly([(-3, -7), (3, -7), (0, -1)], dark, INK, 1)  # tail
    a.line([(-3, -6), (-4, 0)], INK, 1.6)  # legs
    a.line([(3, -6), (4, 0)], INK, 1.6)
    a.ellipse(5, -20, 4.5, 2.4, "#e8e0d0", INK, 0.9)  # ruff
    a.line([(6, -20), (10, -14)], "#c86a5a", 2.6)  # neck bent down
    a.ellipse(11, -12.5, 3.2, 2.8, "#c86a5a", INK, 1.1)  # bald head
    a.poly([(12.5, -11.5), (15.5, -9.5), (13.5, -8.5), (12, -10)], "#e0d4a8", INK, 0.8)  # beak
    a.ellipse(10.6, -13.4, 0.7, 0.7, "#1a0f0a")
    a.save("unit_vulture_landed", fixed=(-34, -50, 34, 3))


def corpse_vulture():
    a = Art()
    a.ellipse(0, 0, 18, 5.5, "#000", opacity=0.3)
    a.poly([(-17, -1), (-6, -5), (-2, 1), (-14, 4)], "#3a2a20", INK, 1.1)  # spread wing
    a.poly([(15, -1), (4, -5), (1, 1), (12, 4)], "#3a2a20", INK, 1.1)
    a.ellipse(0, -1, 6, 3.6, "#5a4232", INK, 1.1)  # body
    a.ellipse(7, -4, 3, 2.4, "#c86a5a", INK, 1)  # head
    a.poly([(9, -4), (12, -3), (9.5, -2.5)], "#e0d4a8", INK, 0.7)
    for x, y in ((-10, 6), (8, 6), (-3, 7)):  # loose feathers
        a.line([(x, y), (x + 3, y - 1)], "#5a4232", 1.2)
    a.save("corpse_vulture")


def necromancer():
    """Black robe and hood, pale face, a staff with a skull and a green glow."""
    def extra(a, layer):
        if layer == "back":
            a.line([(12, -2), (12, -46)], INK, 3.4)  # staff
            a.line([(12, -2), (12, -46)], "#3a2a1a", 1.8)
            a.ellipse(12, -49, 6.5, 6.5, "#6aff8a", opacity=0.3)  # glow
            a.ellipse(12, -49, 4, 3.6, "#e8e4d8", INK, 1)  # skull
            a.ellipse(10.6, -49.4, 1.1, 1.1, "#1a3a1a")
            a.ellipse(13.4, -49.4, 1.1, 1.1, "#1a3a1a")
            a.line([(10.8, -46.6), (13.2, -46.6)], INK, 0.8)
        else:
            a.poly([(-5, -24), (5, -24), (3, -20), (-3, -20)], "#2a4a2a", INK, 0.8)  # green collar
            a.line([(4, -21), (11, -30)], INK, 3.8)  # hand on the staff
            a.line([(4, -21), (11, -30)], "#15121a", 2.2)
            a.ellipse(11.5, -30.5, 1.8, 1.8, "#d8d0c8", INK, 0.8)
            a.ellipse(3, -33.5, 1, 1, "#6aff8a")  # green eye
    person("unit_necromancer", ("#1a161e", "#110e14"), hood="#15121a", robe=True, skin="#d8d0c8", extra=extra)


def corpse_thief():
    a = Art()
    a.ellipse(0, 0, 17, 5.5, "#000", opacity=0.3)
    a.ellipse(0, 1, 13, 4, "#3a1a14", opacity=0.5)
    a.poly([(-12, -2), (6, -6), (9, -1), (-10, 3)], "#2e4a2a", INK, 1.1)  # tunic
    a.ellipse(12, -3, 5.5, 4.5, "#1f3320", INK, 1.2)  # hooded head
    a.poly([(-2, 5), (-12, 8), (-11.5, 9), (-1.5, 6)], "#c8ccd4", INK, 0.8)  # dagger
    for x, y in ((-16, -2), (-18, 1), (-14, 3)):  # spilled coins
        a.ellipse(x, y, 2, 1.3, GOLD, INK, 0.7)
    a.save("corpse_thief")


def corpse_gargoyle():
    a = Art()
    a.ellipse(0, 0, 20, 6.5, "#000", opacity=0.3)
    stone, stone_d = "#7c7f86", "#5d6068"
    a.poly([(-10, -2), (4, -7), (10, -1), (-6, 4)], stone, INK, 1.2)  # body, cracked
    a.line([(-2, -4), (2, 1)], INK, 1)
    a.poly([(-18, -2), (-10, -6), (-8, 0), (-16, 4), (-13, 0)], stone_d, INK, 1.1)  # broken wing
    a.ellipse(13, -3, 5, 4, stone, INK, 1.2)  # head
    a.poly([(15, -6), (19, -10), (16, -4)], "#a2a6ae", INK, 0.8)  # horn
    for x, y, r in ((-4, 6, 2.2), (6, 5, 1.6), (18, 3, 1.8)):  # rubble
        a.ellipse(x, y, r, r * 0.7, stone_d, INK, 0.8)
    a.save("corpse_gargoyle")


def corpse_necromancer():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.poly([(-14, 0), (6, -5), (10, 2), (-10, 5)], "#1a161e", INK, 1.2)  # robe
    a.ellipse(12, -3, 5, 4.5, "#15121a", INK, 1.2)  # hood
    a.line([(-16, 7), (8, 9)], INK, 3)  # staff on the ground
    a.line([(-16, 7), (8, 9)], "#3a2a1a", 1.6)
    a.ellipse(-18, 6, 3.4, 3, "#e8e4d8", INK, 0.9)  # skull
    a.ellipse(-18, 6, 5, 4.5, "#6aff8a", opacity=0.18)
    a.save("corpse_necromancer")


def vampire():
    """Pale, black-haired, a high-collared black cape lined in red, red eyes."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-11, -30), (11, -30), (14, -2), (-14, -2)], "#7a1420", INK, 1.4)  # cape, red inside
            a.poly([(-11, -30), (-3, -30), (-6, -2), (-14, -2)], "#15111a", INK, 1.2)  # black outside
            a.poly([(11, -30), (3, -30), (6, -2), (14, -2)], "#15111a", INK, 1.2)
            a.poly([(-11, -27), (-9, -42), (-4, -30)], "#15111a", INK, 1)  # high collar, behind the head
            a.poly([(11, -27), (9, -42), (4, -30)], "#15111a", INK, 1)
        else:
            a.raw('<path d="M-6,-37 Q0,-45 6,-37 L3,-38 L0,-35 L-3,-38 Z" fill="#15111a" stroke="%s" stroke-width="1"/>' % INK, [(-7, -45), (7, -35)])  # hair, widow's peak
            a.ellipse(1.5, -33.5, 1.2, 1, "#ff3030")
            a.ellipse(4.5, -33.5, 1.0, 0.9, "#ff3030")
            a.poly([(2, -29.5), (2.6, -28), (3.2, -29.5)], "#ffffff", INK, 0.5)  # fang
            a.line([(4, -21), (11, -18)], INK, 3.6)  # clawed hand forward
            a.line([(4, -21), (11, -18)], "#2a2030", 2.2)
            a.ellipse(12, -17.5, 1.8, 1.8, "#e8e0e4", INK, 0.8)
    person("unit_vampire", ("#2a2030", "#1e1724"), skin="#e8e0e4", extra=extra)


def vampire_bat(frame):
    """The vampire as a big bat: black body, wide wings with a dark red skin
    between the fingers, pointed ears, red eyes. Flies (the game draws the
    shadow). Not grey stone like the gargoyle, and no horns."""
    a = Art()
    body, wing, skin = "#1b1620", "#2a2030", "#6a1a2a"
    if frame == 0:  # wings up, spread
        l = [(-4, -26), (-14, -40), (-22, -44), (-30, -36), (-24, -32), (-26, -24), (-18, -26), (-14, -20), (-6, -22)]
    else:  # wings down
        l = [(-4, -24), (-14, -16), (-24, -12), (-30, -4), (-22, -6), (-18, 0), (-14, -8), (-8, -6), (-5, -18)]
    r = [(-x, y) for x, y in l]
    for pts in (l, r):
        a.poly(pts, skin, INK, 1.3)
        a.line([pts[0], pts[2]], wing, 2.4)  # wing bones
        a.line([pts[1], pts[4]], wing, 1.6)
        a.line([pts[1], pts[6]], wing, 1.6)
    a.ellipse(0, -22, 6, 8, body, INK, 1.4)  # body
    a.ellipse(0, -31, 5, 4.5, body, INK, 1.3)  # head
    a.poly([(-4, -33), (-6, -40), (-1.5, -34.5)], body, INK, 1)  # ears
    a.poly([(4, -33), (6, -40), (1.5, -34.5)], body, INK, 1)
    a.ellipse(-1.8, -31.5, 1.2, 1, "#ff3030")
    a.ellipse(1.8, -31.5, 1.2, 1, "#ff3030")
    a.poly([(-1.2, -28.5), (-0.6, -27), (0, -28.5)], "#ffffff", INK, 0.4)
    a.poly([(0, -28.5), (0.6, -27), (1.2, -28.5)], "#ffffff", INK, 0.4)
    a.line([(-2, -14), (-3, -11)], INK, 1.4)  # feet
    a.line([(2, -14), (3, -11)], INK, 1.4)
    a.save("unit_vampire_bat" if frame == 0 else "unit_vampire_bat_flap", fixed=(-31, -50, 31, 3))


def corpse_vampire():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.poly([(-16, -2), (8, -7), (12, 2), (-12, 6)], "#7a1420", INK, 1.2)  # spread cape
    a.poly([(-12, -1), (6, -4), (9, 1), (-9, 4)], "#2a2030", INK, 1)
    a.ellipse(12, -3, 5, 4.5, "#e8e0e4", INK, 1.2)
    a.line([(9, -6), (15, -6)], "#15111a", 2.2)  # hair
    a.ellipse(-18, 5, 4, 2.5, "#4a1018", opacity=0.6)  # dark stain
    a.save("corpse_vampire")


def slimes():
    """Slimes, 3 sizes (level 3 biggest) x 5 pastel colours: unit_slime<level>_<colour>.
    unit_slime<level> is the green one (the library's and the debug menu's picture)."""
    colours = {  # body, darker underside, outline-side shade
        "red": ("#f6a8a4", "#e2827e"),
        "blue": ("#a9c9f2", "#7fa6d8"),
        "yellow": ("#f7e59a", "#dcc46c"),
        "green": ("#b6e8a8", "#88c97a"),
        "pink": ("#f6b9e2", "#dc92c4"),
    }
    for level, r in ((1, 8.5), (2, 12.5), (3, 18.0)):
        h = r * 1.05
        sw = 1.1 if level == 1 else 1.3
        for name, (body, under) in colours.items():
            a = Art()
            a.shadow(r * 1.1, r * 0.4, opacity=0.3)
            d = ("M%s,0 C%s,%s %s,%s 0,%s C%s,%s %s,%s %s,0 Q0,%s %s,0 Z"
                 % (fmt(-r), fmt(-r), fmt(-h * 0.85), fmt(-r * 0.6), fmt(-h * 1.3), fmt(-h * 1.3),
                    fmt(r * 0.6), fmt(-h * 1.3), fmt(r), fmt(-h * 0.85), fmt(r), fmt(r * 0.22), fmt(-r)))
            a.raw('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (d, body, INK, sw),
                  [(-r, -h * 1.3), (r, r * 0.12)])
            a.ellipse(0, -h * 0.18, r * 0.78, h * 0.2, under, opacity=0.7)
            a.ellipse(-r * 0.42, -h * 0.92, r * 0.24, h * 0.14, "#ffffff", opacity=0.75)
            a.ellipse(-r * 0.62, -h * 0.6, r * 0.08, h * 0.08, "#ffffff", opacity=0.6)
            for ex in (r * 0.12, r * 0.52):
                a.ellipse(ex, -h * 0.62, r * 0.12, h * 0.15, INK)
                a.ellipse(ex - r * 0.03, -h * 0.67, r * 0.04, h * 0.05, "#ffffff")
            a.line([(r * 0.2, -h * 0.36), (r * 0.32, -h * 0.3), (r * 0.44, -h * 0.36)], INK, 0.9 if level == 1 else 1.1)
            a.save("unit_slime%d_%s" % (level, name))
            if name == "green":
                a.save("unit_slime%d" % level)


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


# ---------------------------------------------------------------- spiders (docs/enemies-design.md §15b)

def _spider_leg(a, hip, knee, foot, color, sw):
    a.line([hip, knee, foot], INK, sw + 1.6)
    a.line([hip, knee, foot], color, sw)


def spider_mother():
    """A huge dark spider, side view, facing right: a bloated abdomen with a red
    hourglass and a cluster of pale eggs underneath, eight jointed legs, red eyes."""
    a = Art()
    a.shadow(26, 8, opacity=0.45)
    chitin, chitin_l, far = "#2e2433", "#4b3c55", "#1f1824"
    # far-side legs (darker, behind the body)
    for hx, kx, kz, fx in ((2, -20, -30, -34), (5, -8, -33, -18), (9, 16, -33, 14), (12, 28, -29, 36)):
        _spider_leg(a, (hx, -16), (kx, kz), (fx, -2), far, 1.6)
    # abdomen: bloated, with a lighter back and a red hourglass
    a.ellipse(-11, -21, 16, 13, chitin, INK, 1.5)
    a.ellipse(-13, -26, 10, 5.5, chitin_l, opacity=0.7)
    a.poly([(-15, -28), (-9, -28), (-12, -23.5)], "#b3302a", INK, 0.8)
    a.poly([(-15, -19), (-9, -19), (-12, -23.5)], "#b3302a", INK, 0.8)
    for sx in (-22, -18, -4, -1):  # bristles
        a.line([(sx, -31 + abs(sx + 11) * 0.35), (sx - 1.5, -35 + abs(sx + 11) * 0.35)], INK, 1.0)
    # pale eggs clinging under the abdomen
    for ex, ey in ((-18, -9), (-13, -8), (-8, -9), (-15.5, -11.5), (-10.5, -11.5)):
        a.ellipse(ex, ey, 2.8, 2.4, "#e7dfc6", INK, 0.8)
    # cephalothorax and head
    a.ellipse(8, -17, 9.5, 7.5, chitin, INK, 1.4)
    a.ellipse(7, -20.5, 6, 3, chitin_l, opacity=0.6)
    a.ellipse(16, -15, 5, 4.5, chitin, INK, 1.2)
    # fangs
    a.poly([(18, -12), (21, -11), (19, -6)], "#d8cfb8", INK, 0.8)
    a.poly([(15.5, -11.5), (18, -11), (16.5, -6.5)], "#d8cfb8", INK, 0.8)
    # a cluster of red eyes
    for ex, ey, r in ((17.5, -17.5, 1.5), (19.5, -16, 1.2), (15.5, -18.5, 1.1), (18, -19.8, 0.9), (20.5, -18.3, 0.8)):
        a.ellipse(ex, ey, r, r, "#ff3a2a")
    a.ellipse(17.2, -17.9, 0.5, 0.5, "#ffd0c0")
    # near-side legs
    for hx, kx, kz, fx in ((3, -22, -32, -37), (6, -6, -35, -21), (10, 19, -35, 18), (13, 31, -30, 40)):
        _spider_leg(a, (hx, -14), (kx, kz), (fx, 0), chitin, 2.0)
        a.ellipse(kx, kz, 1.4, 1.4, chitin_l, INK, 0.8)  # knee joint
    a.save("unit_spider_mother")


def corpse_spider_mother():
    """On its back, legs curled up."""
    a = Art()
    a.ellipse(0, 0, 24, 7, "#000", opacity=0.3)
    a.ellipse(2, 2, 20, 5, "#1e2a14", opacity=0.45)  # dark ichor
    chitin = "#2e2433"
    for hx, kx, ky, fx, fy in ((-6, -14, -16, -8, -18), (-1, -6, -20, 0, -21), (5, 6, -20, 11, -18), (10, 16, -15, 19, -10)):
        _spider_leg(a, (hx, -6), (kx, ky), (fx, fy), chitin, 1.8)
    a.ellipse(-8, -4, 14, 7.5, chitin, INK, 1.4)
    a.ellipse(-8, -6, 8, 3, "#5a4a62", opacity=0.6)  # pale belly
    a.ellipse(10, -3, 7.5, 5.5, chitin, INK, 1.2)
    for ex in (-12, -7):  # crushed eggs
        a.ellipse(ex, 3, 2.6, 1.6, "#cfc6aa", INK, 0.7)
    a.save("corpse_spider_mother")


def _wrathwood_body(a, grip=False):
    """The trunk of a wrathwood, facing right: root legs, a bark body with a
    face, branch arms (raised, or plunged into the ground for a root grip) and
    an oak crown."""
    bark, bark_d, bark_l = "#5e4129", "#43301e", "#7a5738"
    moss = "#4d6b37"
    leaf = ("#203a22", "#1b331d", "#26442a", "#2e5232")
    # root legs, spread wide
    for x0, x1, x2 in ((-6, -11, -17), (6, 10, 16)):
        a.line([(x0, -18), (x1, -6), (x2, -1)], INK, 8.5)
        a.line([(x0, -18), (x1, -6), (x2, -1)], bark_d, 6)
        a.line([(x2, -1), (x2 + (-5 if x2 < 0 else 5), 1)], INK, 3.4)
        a.line([(x2, -1), (x2 + (-5 if x2 < 0 else 5), 1)], bark_d, 1.8)
    # the far arm (behind the body)
    if grip:
        a.line([(-8, -48), (-15, -30), (-14, -8), (-18, 0)], INK, 7)
        a.line([(-8, -48), (-15, -30), (-14, -8), (-18, 0)], bark_d, 4.6)
    else:
        a.line([(-8, -50), (-19, -60), (-24, -74)], INK, 7)
        a.line([(-8, -50), (-19, -60), (-24, -74)], bark_d, 4.6)
        for tx, ty in ((-30, -78), (-24, -82), (-19, -79)):
            a.line([(-24, -74), (tx, ty)], INK, 2.6)
            a.line([(-24, -74), (tx, ty)], bark_d, 1.2)
    # the trunk: wider at the roots, bark grooves, moss
    a.poly([(-11, -16), (11, -16), (9, -56), (-9, -58)], bark, INK, 1.5)
    a.poly([(1, -16), (11, -16), (9, -56), (1, -57)], bark_d, stroke=None, opacity=0.6)
    for gx, top, bot in ((-6, -54, -20), (-1.5, -56, -24), (5, -53, -19)):
        a.line([(gx, bot), (gx + 1.2, (top + bot) / 2), (gx - 0.6, top)], "#2c1f13", 1.1)
    a.ellipse(-6, -22, 4.5, 2.4, moss, opacity=0.85)
    a.ellipse(7, -46, 3, 1.8, moss, opacity=0.75)
    # the face: a heavy brow, glowing amber eyes, a hollow mouth
    a.line([(-1, -46), (9, -45)], INK, 2.6)
    a.line([(-1, -46), (9, -45)], bark_l, 1.2)
    for ex in (1.5, 7):
        a.ellipse(ex, -42.5, 1.9, 1.5, "#1a120a")
        a.ellipse(ex, -42.5, 1.1, 0.9, "#ffb340")
    a.ellipse(4.5, -35, 3, 2.2 if not grip else 3, "#1a120a", INK, 0.9)
    # the crown: oak clumps on its head
    for cx, cy, r, c in ((-12, -64, 13, leaf[0]), (10, -64, 12, leaf[1]), (-1, -76, 16, leaf[2]), (-6, -82, 8, leaf[3])):
        a.ellipse(cx, cy - (2 if grip else 0), r, r * 0.85, c, INK, 1.3)
    a.ellipse(-4, -80, 3.5, 2.6, "#3d6a42", opacity=0.8)
    # the near arm
    if grip:
        a.line([(9, -50), (20, -34), (19, -10), (23, 0)], INK, 7.5)
        a.line([(9, -50), (20, -34), (19, -10), (23, 0)], bark, 5)
    else:
        a.line([(8, -48), (19, -50), (27, -40)], INK, 7.5)
        a.line([(8, -48), (19, -50), (27, -40)], bark, 5)
        for tx, ty in ((33, -42), (31, -35), (26, -33)):
            a.line([(27, -40), (tx, ty)], INK, 2.8)
            a.line([(27, -40), (tx, ty)], bark, 1.3)
        a.ellipse(20, -51, 3, 2, leaf[2], INK, 0.8)  # a twig of leaves on the arm


def wrathwood():
    """A tree woken up under the axe (side view, facing right; the game flips it),
    and its root grip: arms plunged into the ground, roots spreading round it."""
    a = Art()
    a.shadow(26, 9, opacity=0.45)
    _wrathwood_body(a)
    a.save("unit_wrathwood")
    g = Art()
    g.shadow(26, 9, opacity=0.45)
    for ang in (0.3, 1.4, 2.3, 3.5, 4.6, 5.6):  # roots spreading on the ground
        x, y = math.cos(ang) * 30, math.sin(ang) * 12
        g.line([(0, 0), (x * 0.5, y * 0.5 + 1), (x, y)], INK, 3.6)
        g.line([(0, 0), (x * 0.5, y * 0.5 + 1), (x, y)], "#6b4a2c", 2)
    _wrathwood_body(g, grip=True)
    g.pts = a.pts[:] + g.pts  # (one canvas, so the two line up)
    g.save("unit_wrathwood_grip")


def corpse_wrathwood():
    """A felled wrathwood: a log of living wood with its crown spilled out."""
    a = Art()
    a.ellipse(0, 1, 30, 8, "#000", opacity=0.3)
    for cx, cy, r, c in ((22, -6, 9, "#1b331d"), (28, -1, 7, "#203a22"), (17, 1, 6, "#26442a")):
        a.ellipse(cx, cy, r, r * 0.7, c, INK, 1.1)
    a.poly([(-24, -9), (14, -12), (16, -1), (-22, 3)], "#5e4129", INK, 1.4)
    a.poly([(-23, -3), (15, -6), (16, -1), (-22, 3)], "#43301e", stroke=None, opacity=0.7)
    for gx in (-15, -6, 3, 10):
        a.line([(gx, -10), (gx + 2, -3)], "#2c1f13", 1.0)
    a.ellipse(-23, -3, 3.5, 6, "#c9a878", INK, 1.2)  # the cut end, with its rings
    a.ellipse(-23, -3, 2, 3.6, "#a8865a", opacity=0.8)
    a.ellipse(-23, -3, 0.8, 1.4, "#7a5738")
    a.ellipse(-2, -7, 1.3, 1.0, "#1a120a")  # its eyes, gone dark
    a.ellipse(4, -7.5, 1.3, 1.0, "#1a120a")
    a.line([(-8, 2), (-14, 7)], INK, 3)  # a broken branch
    a.line([(-8, 2), (-14, 7)], "#43301e", 1.6)
    a.ellipse(-10, -10, 3.5, 1.6, "#4d6b37", opacity=0.85)
    a.save("corpse_wrathwood")


def spiderling():
    """A small brown spider, side view, facing right (the game flips it)."""
    a = Art()
    a.shadow(10, 3, opacity=0.35)
    body, body_l, far = "#5a4232", "#7c6048", "#3e2e22"
    for hx, kx, kz, fx in ((-1, -8, -10, -12), (1, -3, -11, -6), (3, 7, -11, 7), (4, 11, -9, 13)):
        _spider_leg(a, (hx, -5), (kx, kz), (fx, -1), far, 0.7)
    a.ellipse(-4, -7, 6.5, 5.2, body, INK, 1.1)
    a.ellipse(-5, -8.5, 3, 1.6, body_l, opacity=0.7)
    a.ellipse(-4, -6.8, 1.0, 1.4, "#c9a24a", opacity=0.85)  # a little gold spot
    a.ellipse(3, -5, 3.4, 2.8, body, INK, 1.0)
    a.ellipse(4.8, -5.6, 0.8, 0.8, "#ff3a2a")
    a.ellipse(3.6, -6.2, 0.6, 0.6, "#ff3a2a")
    for hx, kx, kz, fx in ((-1, -9, -11, -13), (1, -4, -12, -7), (3, 8, -12, 8), (4, 12, -10, 15)):
        _spider_leg(a, (hx, -4), (kx, kz), (fx, 0), body, 0.8)
    a.save("unit_spiderling")


def spider_eggs():
    """One spider egg (pale, veined, glistening) and the broken shell it leaves."""
    shell, shell_d, vein = "#e9e1c8", "#c9bf9f", "#9fb08a"
    a = Art()
    a.shadow(6.5, 2.4, opacity=0.35)
    a.ellipse(0, -6.5, 5.2, 6.5, shell, INK, 1.1)
    a.ellipse(1.5, -4.5, 3.2, 3.6, shell_d, opacity=0.55)
    a.raw('<path d="M-2,-11 Q-3.5,-7 -1.5,-3" fill="none" stroke="%s" stroke-width="0.8"/>' % vein, [(-4, -11), (-1, -3)])
    a.raw('<path d="M2,-10 Q3.5,-7 2,-4.5" fill="none" stroke="%s" stroke-width="0.7"/>' % vein, [(1, -10), (4, -4)])
    a.ellipse(-2, -9.5, 1.4, 1.0, "#ffffff", opacity=0.8)
    a.save("unit_spider_egg")
    b = Art()
    b.shadow(6.5, 2.4, opacity=0.3)
    # the lower half, a jagged rim, and the dark inside
    b.poly([(-5.2, -5.5), (-3.5, -7.5), (-2, -5.8), (0, -8.2), (1.8, -6), (3.6, -7.8), (5.2, -5.5),
            (4.6, -2.2), (2.5, -0.4), (-2.5, -0.4), (-4.6, -2.2)], shell, INK, 1.1)
    b.ellipse(0, -5.6, 4.0, 1.4, "#4a4030", opacity=0.75)
    b.ellipse(1.5, -2.6, 2.6, 1.6, shell_d, opacity=0.55)
    # a few fragments beside it
    b.poly([(-9, -1), (-7, -3), (-6, -0.5)], shell, INK, 0.8)
    b.poly([(7, -0.5), (9.5, -2), (9.8, 0.3)], shell, INK, 0.8)
    b.poly([(5.5, 1.5), (7, 0.8), (7.2, 2.2)], shell_d, INK, 0.6)
    b.save("unit_spider_egg_shell")


# ---------------------------------------------------------------- water monsters (docs/aquatic-design.md)

def _waterline(a, rx, ry, cy=0.0):
    """Where a monster comes out of the water: a dark ring and a light rim."""
    a.ellipse(0, cy, rx, ry, "#1d3a52", opacity=0.55)
    a.ellipse(0, cy, rx, ry, "none", "#cfe6f5", 1.4, opacity=0.8)
    a.ellipse(0, cy, rx * 0.7, ry * 0.65, "none", "#9cc6e2", 1.0, opacity=0.6)


def crab():
    """A big red-orange crab, side-on, claws raised, eyes on stalks."""
    a = Art()
    a.shadow(14, 4.5, opacity=0.4)
    shell, shell_d, shell_l = "#c2512e", "#8e3418", "#e07a4e"
    for x0, x1 in ((-10, -15), (-6, -10), (6, 10), (10, 15)):  # legs
        a.line([(x0, -6), (x1, -3), (x1 + (1 if x1 > 0 else -1), 0)], INK, 2.8)
        a.line([(x0, -6), (x1, -3), (x1 + (1 if x1 > 0 else -1), 0)], shell_d, 1.4)
    a.ellipse(0, -9, 13, 6.5, shell, INK, 1.4)  # shell
    a.ellipse(-2, -11, 8, 3, shell_l, opacity=0.7)
    a.ellipse(4, -6, 9, 2.4, shell_d, opacity=0.5)
    for sx in (-1, 1):  # claws
        a.line([(sx * 10, -11), (sx * 15, -18)], INK, 3.4)
        a.line([(sx * 10, -11), (sx * 15, -18)], shell_d, 2)
        a.raw('<path d="M%s,-18 Q%s,-28 %s,-26 L%s,-21 Q%s,-23 %s,-19 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>'
              % (fmt(sx * 13), fmt(sx * 16), fmt(sx * 22), fmt(sx * 18), fmt(sx * 20), fmt(sx * 17), shell, INK), [(-23, -29), (23, -17)])
    for ex in (-3, 3):  # eye stalks
        a.line([(ex, -14), (ex, -19)], INK, 2)
        a.ellipse(ex, -20, 1.8, 1.8, "#15110d")
        a.ellipse(ex - 0.5, -20.5, 0.6, 0.6, "#ffffff")
    a.save("unit_crab")


def corpse_crab():
    a = Art()
    a.ellipse(0, 0, 16, 5, "#000", opacity=0.3)
    a.ellipse(0, -3, 12, 5.5, "#8e3418", INK, 1.3)  # on its back
    a.ellipse(0, -4, 8, 3, "#e8b090", opacity=0.6)
    for x0, x1, y1 in ((-8, -13, -10), (-4, -6, -12), (4, 6, -12), (8, 13, -10)):
        a.line([(x0, -5), (x1, y1)], INK, 2.4)
        a.line([(x0, -5), (x1, y1)], "#c2512e", 1.2)
    a.poly([(12, -2), (20, -6), (19, 0)], "#c2512e", INK, 1)  # a claw lying apart
    a.save("corpse_crab")


def leviathan():
    """A sea serpent up out of the water: two coils and a crested head, dark
    teal scales, pale belly, glowing yellow eyes."""
    a = Art()
    _waterline(a, 34, 11)
    scale, scale_d, belly = "#1f5b5c", "#123c3e", "#9ec9a8"
    for cx, w, h in ((-22, 9, 10), (-6, 10, 13)):  # coils behind the neck
        a.raw('<path d="M%s,2 Q%s,%s %s,2 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (fmt(cx - w), fmt(cx), fmt(-h * 2), fmt(cx + w), scale, INK),
              [(cx - w, -h * 2), (cx + w, 2)])
        a.raw('<path d="M%s,1 Q%s,%s %s,1" fill="none" stroke="%s" stroke-width="2"/>' % (fmt(cx - w * 0.6), fmt(cx), fmt(-h * 1.5), fmt(cx + w * 0.6), scale_d),
              [(cx - w, -h * 2), (cx + w, 2)])
    # neck rising to the head
    a.raw('<path d="M6,3 Q4,-30 16,-52 L28,-48 Q20,-28 22,3 Z" fill="%s" stroke="%s" stroke-width="1.5" stroke-linejoin="round"/>' % (scale, INK), [(4, -53), (28, 3)])
    a.raw('<path d="M18,2 Q16,-26 25,-46" fill="none" stroke="%s" stroke-width="3"/>' % belly, [(16, -47), (26, 3)])
    for y in (-10, -22, -34):  # scale rows
        a.line([(8, y), (19, y - 3)], scale_d, 1.2)
    # crest
    a.poly([(12, -46), (6, -62), (16, -54), (14, -68), (22, -56), (24, -66), (27, -52)], "#7a2a3a", INK, 1.2)
    # head
    a.raw('<path d="M14,-56 Q22,-64 34,-58 L44,-52 Q40,-46 30,-46 Q20,-44 14,-50 Z" fill="%s" stroke="%s" stroke-width="1.5" stroke-linejoin="round"/>' % (scale, INK), [(14, -65), (44, -44)])
    a.line([(32, -49), (43, -51)], INK, 1.2)  # jaw
    a.poly([(34, -49), (35, -46), (36, -49)], "#ffffff", INK, 0.5)  # fangs
    a.poly([(39, -50), (40, -47.5), (41, -50)], "#ffffff", INK, 0.5)
    a.ellipse(28, -56, 2.4, 1.8, "#f2e04a", INK, 0.8)
    a.ellipse(28.5, -56, 0.8, 1.4, INK)
    a.ellipse(28, -56, 5, 4, "#f2e04a", opacity=0.25)
    for x, y in ((-30, -2), (32, 0), (-14, 4)):  # foam
        a.ellipse(x, y, 3, 1.2, "#e8f4fb", opacity=0.8)
    a.save("unit_leviathan")


def corpse_leviathan():
    a = Art()
    a.ellipse(0, 0, 30, 9, "#1d3a52", opacity=0.45)
    a.raw('<path d="M-26,0 Q-14,-10 -2,-2 Q10,6 22,-4 L26,-1 Q12,10 -2,3 Q-14,-4 -24,4 Z" fill="#1f5b5c" stroke="%s" stroke-width="1.3"/>' % INK, [(-27, -10), (27, 8)])
    a.raw('<path d="M-22,1 Q-12,-6 -2,0 Q10,6 22,-2" fill="none" stroke="#9ec9a8" stroke-width="1.6"/>', [(-22, -6), (22, 6)])
    a.ellipse(26, -3, 6, 3.5, "#1f5b5c", INK, 1.2)
    a.line([(24, -5), (28, -2)], INK, 1)
    a.line([(28, -5), (24, -2)], INK, 1)
    a.save("corpse_leviathan")


def siren():
    """A siren rising from the water on a scaled tail: long sea-green hair,
    pale skin, a shell on her breast, arms spread as she sings."""
    a = Art()
    _waterline(a, 14, 5)
    tail, tail_d, hair = "#2f7f7a", "#1f5a57", "#3fae96"
    a.raw('<path d="M-8,2 Q-10,-14 -5,-24 L6,-24 Q10,-12 7,2 Z" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (tail, INK), [(-10, -25), (10, 2)])
    for y in (-4, -10, -16):
        a.raw('<path d="M-6,%s Q-3,%s 0,%s Q3,%s 6,%s" fill="none" stroke="%s" stroke-width="1"/>' % (fmt(y), fmt(y - 2), fmt(y), fmt(y - 2), fmt(y), tail_d), [(-6, y - 2), (6, y)])
    a.poly([(-14, 3), (-8, -2), (-6, 3)], tail_d, INK, 1)  # fin tips in the water
    a.raw('<path d="M-7,-30 Q-12,-18 -9,-10 L-5,-12 Q-7,-20 -4,-28 Z" fill="%s" stroke="%s" stroke-width="1"/>' % (hair, INK), [(-12, -31), (-4, -10)])
    a.poly([(-6, -24), (6, -24), (5, -31), (-5, -31)], "#e8d8cc", INK, 1.2)  # body
    a.ellipse(0, -27, 2.5, 2, "#e8b8c8", INK, 0.8)  # shell
    a.line([(-5, -29), (-13, -36)], INK, 3.4)  # arms spread
    a.line([(-5, -29), (-13, -36)], "#e8d8cc", 2)
    a.line([(5, -29), (13, -36)], INK, 3.4)
    a.line([(5, -29), (13, -36)], "#e8d8cc", 2)
    a.ellipse(0, -36, 5.5, 5.5, "#e8d8cc", INK, 1.3)  # head
    a.raw('<path d="M-6,-37 Q-6,-44 0,-44 Q6,-44 6,-37 Q3,-41 0,-41 Q-3,-41 -6,-37 Z" fill="%s" stroke="%s" stroke-width="1"/>' % (hair, INK), [(-7, -45), (7, -36)])
    a.ellipse(2.5, -36.5, 0.9, 0.9, INK)
    a.ellipse(3, -33.5, 1.2, 0.8, "#7a2a3a")  # singing mouth
    a.save("unit_siren")


def corpse_siren():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.raw('<path d="M-16,2 Q-6,-4 4,0 L4,4 Q-6,2 -14,6 Z" fill="#2f7f7a" stroke="%s" stroke-width="1.2"/>' % INK, [(-17, -4), (5, 7)])
    a.poly([(-18, 1), (-14, 4), (-19, 7)], "#1f5a57", INK, 1)
    a.poly([(3, -3), (12, -4), (12, 2), (3, 3)], "#e8d8cc", INK, 1.1)
    a.ellipse(15, -2, 4.5, 4, "#e8d8cc", INK, 1.2)
    a.line([(13, -5), (20, 1)], "#3fae96", 3)  # hair
    a.save("corpse_siren")


def octopus():
    """The gigantic octopus: a huge purple-red mantle out of the water, big
    eyes, and stubs of its arms curling on the surface (the arms that reach
    are drawn by the game)."""
    a = Art()
    _waterline(a, 46, 15)
    skin, skin_d, skin_l, spot = "#8a3a5a", "#5e2238", "#b05a7a", "#d89ab0"
    for sx, h in ((-1, 1), (1, 1), (-1, 0), (1, 0)):  # arm stubs curling on the water
        x0 = sx * (16 if h else 28)
        a.raw('<path d="M%s,0 Q%s,%s %s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>'
              % (fmt(x0), fmt(x0 + sx * 12), fmt(4 - h * 2), fmt(x0 + sx * 18), fmt(-4), fmt(x0 + sx * 22), fmt(-12), fmt(x0 + sx * 16), fmt(-14), INK), [(x0 - 25, -16), (x0 + 25, 6)])
        a.raw('<path d="M%s,0 Q%s,%s %s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="4.5" stroke-linecap="round"/>'
              % (fmt(x0), fmt(x0 + sx * 12), fmt(4 - h * 2), fmt(x0 + sx * 18), fmt(-4), fmt(x0 + sx * 22), fmt(-12), fmt(x0 + sx * 16), fmt(-14), skin), [(x0 - 25, -16), (x0 + 25, 6)])
    # the mantle
    a.raw('<path d="M-24,2 Q-30,-40 -10,-62 Q0,-70 10,-62 Q30,-40 24,2 Z" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (skin, INK), [(-30, -70), (30, 2)])
    a.raw('<path d="M6,-62 Q24,-42 20,0 L24,2 Q30,-40 10,-62 Z" fill="%s"/>' % skin_d, [(6, -62), (30, 2)])
    a.raw('<path d="M-16,-50 Q-8,-62 0,-62" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.7"/>' % skin_l, [(-17, -63), (1, -49)])
    for x, y, r in ((-12, -30, 2.5), (-4, -46, 2), (8, -40, 2.2), (14, -22, 1.8), (-16, -14, 2), (2, -56, 1.6)):
        a.ellipse(x, y, r, r * 0.8, spot, opacity=0.7)
    for ex in (-10, 10):  # eyes
        a.ellipse(ex, -12, 6, 5, "#f0d878", INK, 1.2)
        a.ellipse(ex, -12, 4.2, 1.6, INK)
        a.ellipse(ex - 1.5, -13.5, 1, 0.8, "#ffffff")
    a.save("unit_octopus")


def corpse_octopus():
    a = Art()
    a.ellipse(0, 0, 36, 11, "#1d3a52", opacity=0.45)
    for sx in (-1, 1):
        for k in (0, 1):
            x0 = sx * (8 + k * 8)
            a.raw('<path d="M%s,0 Q%s,%s %s,%s" fill="none" stroke="#5e2238" stroke-width="5" stroke-linecap="round"/>' % (fmt(x0), fmt(x0 + sx * 14), fmt(6 - k * 10), fmt(x0 + sx * 24), fmt(2 - k * 6)), [(x0 - 26, -10), (x0 + 26, 8)])
    a.ellipse(0, -4, 18, 9, "#8a3a5a", INK, 1.4)
    a.line([(-9, -6), (-5, -3)], INK, 1.2)
    a.line([(-5, -6), (-9, -3)], INK, 1.2)
    a.line([(5, -6), (9, -3)], INK, 1.2)
    a.line([(9, -6), (5, -3)], INK, 1.2)
    a.save("corpse_octopus")


def octopus_arm():
    """The tip of an octopus's arm where it holds its catch (the arm itself is
    drawn by the game): a curl with pale suckers."""
    a = Art()
    a.raw('<path d="M-6,-4 Q-10,-18 0,-22 Q10,-24 9,-14 Q8,-8 2,-10 Q-2,-12 1,-16" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>' % INK, [(-11, -25), (11, -2)])
    a.raw('<path d="M-6,-4 Q-10,-18 0,-22 Q10,-24 9,-14 Q8,-8 2,-10 Q-2,-12 1,-16" fill="none" stroke="#8a3a5a" stroke-width="4.5" stroke-linecap="round"/>', [(-11, -25), (11, -2)])
    for x, y in ((-7, -10), (-6, -16), (-2, -20), (4, -21)):
        a.ellipse(x, y, 1.1, 1.1, "#e0b8c8")
    a.save("unit_octopus_arm")


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


def title_icons():
    """The title screen's menu icons."""
    # Singleplayer: one person, profile-picture style in a round frame.
    icon_svg("icon_singleplayer", f'''
  <circle cx="32" cy="32" r="27" fill="#3a4a5a" stroke="{INK}" stroke-width="3.5"/>
  <path d="M13 51 Q14 36 32 36 Q50 36 51 51 Q42 59 32 59 Q22 59 13 51Z" fill="#566a3a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <circle cx="32" cy="23" r="10" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>''')
    # Multiplayer: a group of three.
    icon_svg("icon_multiplayer", f'''
  <circle cx="15" cy="22" r="7" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M3 48 Q3 31 15 31 Q27 31 27 48Z" fill="#7a6048" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="49" cy="22" r="7" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M37 48 Q37 31 49 31 Q61 31 61 48Z" fill="#7a2a1f" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="24" r="9" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M16 56 Q16 35 32 35 Q48 35 48 56Z" fill="#566a3a" stroke="{INK}" stroke-width="3.5"/>''')
    # Tutorial: a scholar's cap with a gold tassel.
    icon_svg("icon_tutorial", f'''
  <path d="M16 30 L16 44 Q32 54 48 44 L48 30Z" fill="#2a2a34" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M2 24 L32 11 L62 24 L32 37Z" fill="#3a3a48" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 24 L52 30 L52 46" fill="none" stroke="{GOLD}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="52" cy="49" r="4" fill="{GOLD}" stroke="{INK}" stroke-width="2"/>
  <circle cx="32" cy="24" r="3" fill="{GOLD}" stroke="{INK}" stroke-width="1.5"/>''')
    # Map editor: a folded parchment map with a road, a river and a quill over it.
    icon_svg("icon_map_editor", f'''
  <path d="M4 14 L22 8 L42 14 L60 8 L60 50 L42 56 L22 50 L4 56Z" fill="#e8d6a8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M22 8 L22 50 M42 14 L42 56" fill="none" stroke="#b89a60" stroke-width="2.5"/>
  <path d="M8 44 Q18 34 26 38 Q34 42 40 30" fill="none" stroke="#3f7fbf" stroke-width="4" stroke-linecap="round"/>
  <path d="M10 22 L18 26 L30 22 L38 28" fill="none" stroke="#a0704a" stroke-width="3" stroke-linecap="round" stroke-dasharray="4 3"/>
  <path d="M50 2 L62 14 L34 46 L26 50 L30 42Z" fill="#f4f0e6" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>
  <path d="M30 42 L34 46" fill="none" stroke="{INK}" stroke-width="3"/>
  <path d="M52 8 L38 24" fill="none" stroke="#b8b0a0" stroke-width="2"/>''')
    # Next scenario (a won scenario's main button): a rounded play arrow on a
    # crimson seal with a gold rim.
    icon_svg("icon_next", f'''
  <circle cx="32" cy="32" r="28" fill="{CRIMSON}" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="32" r="23" fill="none" stroke="{GOLD}" stroke-width="2.5"/>
  <path d="M26 20 L46 32 L26 44Z" fill="#5a1a14" stroke="#5a1a14" stroke-width="7" stroke-linejoin="round" transform="translate(1.5 2)"/>
  <path d="M26 20 L46 32 L26 44Z" fill="#efe3c8" stroke="#efe3c8" stroke-width="7" stroke-linejoin="round"/>''')
    # Exit: an open door with an arrow leading out.
    icon_svg("icon_exit", f'''
  <path d="M8 6 L36 6 L36 58 L8 58Z" fill="#4a3a2a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M8 6 L28 12 L28 62 L8 58Z" fill="#8a5a32" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <circle cx="23" cy="36" r="2.5" fill="{GOLD}" stroke="{INK}" stroke-width="1.5"/>
  <path d="M34 32 L54 32 M46 23 L56 32 L46 41" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M34 32 L54 32 M46 23 L56 32 L46 41" fill="none" stroke="#e05a4a" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>''')


def icons():
    # XP: three sparkling green orbs.
    # XP: a light-blue star with a sparkle.
    icon_svg("icon_xp", f"""
  <path d="M32 5 L39.5 23 L59 24.5 L44 37 L48.8 56 L32 45.5 L15.2 56 L20 37 L5 24.5 L24.5 23 Z" fill="#7fd0ff" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 13 L37 25 L50 26 L40 34.5" fill="none" stroke="#e4f6ff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M55 5 L56.5 9.5 L61 11 L56.5 12.5 L55 17 L53.5 12.5 L49 11 L53.5 9.5Z" fill="#ffffff" stroke="{INK}" stroke-width="1.2"/>""")
    # The hero's level-up: three green chevrons rising, and a soft glow behind them.
    icon_svg("levelup_chevrons", f"""
  <path d="M10 58 L32 42 L54 58 L54 48 L32 32 L10 48 Z" fill="#3f9a3a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M10 42 L32 26 L54 42 L54 32 L32 16 L10 32 Z" fill="#5cc24a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M14 22 L32 8 L50 22 L50 15 L32 2 L14 15 Z" fill="#9aee6e" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>""")
    icon_svg("levelup_glow", """
  <defs><radialGradient id="g"><stop offset="0" stop-color="#eaffb0" stop-opacity="0.95"/><stop offset="0.45" stop-color="#8cf06a" stop-opacity="0.45"/><stop offset="1" stop-color="#4ac04a" stop-opacity="0"/></radialGradient></defs>
  <circle cx="32" cy="32" r="32" fill="url(#g)"/>""")

    # Hero modes (the icon row in her panel).
    icon_svg("mode_defend", f"""
  <path d="M32 5 L54 12 L54 30 C54 44 44 54 32 59 C20 54 10 44 10 30 L10 12 Z" fill="#6a7fa0" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 11 L48 16 L48 30 C48 41 41 49 32 53 Z" fill="#8ea3c4"/>
  <path d="M32 5 L32 59 M10 28 L54 28" stroke="{GOLD}" stroke-width="4"/>
  <path d="M32 5 L54 12 L54 30 C54 44 44 54 32 59 C20 54 10 44 10 30 L10 12 Z" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>""")
    icon_svg("mode_build", f"""
  <g transform="rotate(-45 32 32)">
    <path d="M25 4 L39 4 L39 44 L25 44 Z" fill="#c9ced6" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>
    <path d="M25 8 L21 10 L25 13 L21 16 L25 19 L21 22 L25 25 L21 28 L25 31 L21 34 L25 37 L21 40 L25 43" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
    <rect x="23" y="44" width="18" height="15" rx="4" fill="{WOOD_L}" stroke="{INK}" stroke-width="3"/>
    <rect x="28" y="48" width="8" height="7" rx="2" fill="{WOOD_D}"/>
  </g>
  <g transform="rotate(45 32 32) translate(32 32) scale(0.86) translate(-32 -32)">
    <rect x="28" y="16" width="8" height="46" rx="3" fill="#b08a58" stroke="{INK}" stroke-width="3.5"/>
    <rect x="12" y="4" width="40" height="15" rx="3" fill="#8a929c" stroke="{INK}" stroke-width="4"/>
    <rect x="15" y="7" width="16" height="4" rx="2" fill="#b8c0ca"/>
  </g>""")
    icon_svg("mode_explore", f"""
  <circle cx="32" cy="32" r="25" fill="#3a78c8" stroke="{INK}" stroke-width="3.5"/>
  <path d="M18 16 Q26 12 30 18 Q34 24 27 28 Q22 32 24 38 Q26 44 20 46 Q12 40 11 30 Q12 20 18 16Z" fill="#5fae4a" stroke="{INK}" stroke-width="2"/>
  <path d="M38 12 Q48 14 53 24 Q55 34 50 42 Q44 46 40 40 Q37 34 42 30 Q46 26 40 22 Q35 18 38 12Z" fill="#5fae4a" stroke="{INK}" stroke-width="2"/>
  <path d="M34 48 Q40 46 44 50 Q40 55 34 55Z" fill="#5fae4a" stroke="{INK}" stroke-width="2"/>
  <path d="M15 22 Q18 15 26 12" fill="none" stroke="#a8d4ff" stroke-width="3" stroke-linecap="round"/>
  <circle cx="32" cy="32" r="25" fill="none" stroke="{INK}" stroke-width="3.5"/>""")
    icon_svg("mode_gather", f"""
  <path d="M8 26 L46 26 L40 44 L14 44 Z" fill="{WOOD_L}" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M46 26 L60 18" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>
  <path d="M18 44 L16 54 M38 44 L40 54" stroke="{INK}" stroke-width="3"/>
  <circle cx="20" cy="52" r="7" fill="{WOOD_D}" stroke="{INK}" stroke-width="3"/>
  <path d="M14 22 L30 14" stroke="#ece4cf" stroke-width="5" stroke-linecap="round"/>
  <path d="M14 22 L30 14" stroke="{INK}" stroke-width="1" opacity="0.4"/>
  <circle cx="36" cy="17" r="7" fill="#ece4cf" stroke="{INK}" stroke-width="2.5"/>
  <circle cx="34" cy="16" r="1.8" fill="{INK}"/>
  <circle cx="39" cy="16" r="1.8" fill="{INK}"/>""")
    icon_svg("mode_train", f"""
  <path d="M32 30 L32 60" stroke="{WOOD_D}" stroke-width="5" stroke-linecap="round"/>
  <path d="M8 30 L56 30" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M8 30 L56 30" stroke="{WOOD_L}" stroke-width="4" stroke-linecap="round"/>
  <path d="M20 28 L44 28 L42 50 L22 50 Z" fill="#d8b860" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M24 36 L40 36 M23 43 L41 43" stroke="#a08030" stroke-width="2.5"/>
  <circle cx="32" cy="16" r="10" fill="#d8b860" stroke="{INK}" stroke-width="3.5"/>
  <path d="M27 13 L31 17 M31 13 L27 17 M33 13 L37 17 M37 13 L33 17" stroke="{INK}" stroke-width="1.8"/>
  <path d="M40 38 L54 46" stroke="#b0b4bc" stroke-width="3" stroke-linecap="round"/>""")
    icon_svg("mode_rest", f"""
  <path d="M6 44 L16 44 L6 56 L16 56" fill="none" stroke="{INK}" stroke-width="7" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M6 44 L16 44 L6 56 L16 56" fill="none" stroke="#ffffff" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M22 26 L36 26 L22 42 L36 42" fill="none" stroke="{INK}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M22 26 L36 26 L22 42 L36 42" fill="none" stroke="#ffffff" stroke-width="4.5" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M40 6 L58 6 L40 26 L58 26" fill="none" stroke="{INK}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M40 6 L58 6 L40 26 L58 26" fill="none" stroke="#ffffff" stroke-width="5.5" stroke-linejoin="round" stroke-linecap="round"/>""")
    icon_svg("mode_support", f"""
  <path d="M1 50 L16 26 L32 36 L16 61 Z" fill="#6a7fa0" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M63 50 L48 26 L32 36 L48 61 Z" fill="#a0503a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <ellipse cx="32" cy="30" rx="18" ry="12" fill="#e8a878" stroke="{INK}" stroke-width="3.5"/>
  <path d="M24 20 L24 28 M30 19 L30 28 M36 19 L36 28 M42 21 L42 28" stroke="{INK}" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M16 32 Q24 40 34 36" fill="none" stroke="{INK}" stroke-width="2.5" stroke-linecap="round"/>""")
    # HP: a plain bold red heart with a highlight.
    icon_svg("icon_hp", f"""
  <path d="M32 56 C20 46 6 36 6 22 C6 13 13 7 21 7 C26 7 30 10 32 14 C34 10 38 7 43 7 C51 7 58 13 58 22 C58 36 44 46 32 56Z" fill="#d8342c" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 50 C24 43 14 35 13 25" fill="none" stroke="#a82420" stroke-width="3" stroke-linecap="round"/>
  <path d="M14 20 Q15 13 22 13" fill="none" stroke="#ff9a8a" stroke-width="4" stroke-linecap="round"/>""")
    # Army HP: two red hearts, one behind the other (the statistics' "Army HP %";
    # the hero's HP is the single heart).
    icon_svg("icon_hp_army", f"""
  <g transform="translate(24 2) scale(0.62)">
    <path d="M32 56 C20 46 6 36 6 22 C6 13 13 7 21 7 C26 7 30 10 32 14 C34 10 38 7 43 7 C51 7 58 13 58 22 C58 36 44 46 32 56Z" fill="#9c2420" stroke="{INK}" stroke-width="5.5" stroke-linejoin="round"/>
  </g>
  <g transform="translate(1 17) scale(0.72)">
    <path d="M32 56 C20 46 6 36 6 22 C6 13 13 7 21 7 C26 7 30 10 32 14 C34 10 38 7 43 7 C51 7 58 13 58 22 C58 36 44 46 32 56Z" fill="#d8342c" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
    <path d="M14 20 Q15 13 22 13" fill="none" stroke="#ff9a8a" stroke-width="5" stroke-linecap="round"/>
  </g>""")
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
    icon_svg("icon_check", f'''
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="#7fd36b" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>''')
    # Yes / no on coloured buttons (Build, Cancel, Ready): light strokes with an
    # ink outline, both spanning 12..52 so either icon sits the same in its button.
    # (Instead of the ✓ / ✕ characters, which mobile browsers' fonts lack.)
    icon_svg("icon_yes", f'''
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="#efe3c8" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_no", f'''
  <path d="M14 14 L50 50 M50 14 L14 50" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round"/>
  <path d="M14 14 L50 50 M50 14 L14 50" fill="none" stroke="#efe3c8" stroke-width="7" stroke-linecap="round"/>''')
    icon_svg("icon_book", f'''
  <path d="M4 19 L4 54 C14 51 24 51 32 57 C40 51 50 51 60 54 L60 19 Z" fill="#7a2a1f" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 18 C24 11 14 11 7 14 L7 49 C15 46 24 47 32 53 Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 18 C40 11 50 11 57 14 L57 49 C49 46 40 47 32 53 Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M12 22 C17 20 22 20 27 23 M12 30 C17 28 22 28 27 31 M12 38 C17 36 22 36 27 39 M37 23 C42 20 47 20 52 22 M37 31 C42 28 47 28 52 30 M37 39 C42 36 47 36 52 38" fill="none" stroke="#a8997c" stroke-width="2.2" stroke-linecap="round"/>''')
    # Statistics: four bars of a bar chart on a base line.
    icon_svg("icon_stats", f'''
  <path d="M6 56 L58 56" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <rect x="8" y="36" width="10" height="18" rx="1.5" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>
  <rect x="21" y="22" width="10" height="32" rx="1.5" fill="{GOLD}" stroke="{INK}" stroke-width="3.5"/>
  <rect x="34" y="30" width="10" height="24" rx="1.5" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>
  <rect x="47" y="10" width="10" height="44" rx="1.5" fill="{CRIMSON}" stroke="{INK}" stroke-width="3.5"/>''')
    # Map (the tactical map, M): a folded parchment map with a dotted route and a red cross.
    icon_svg("icon_map", f'''
  <path d="M6 14 L22 8 L42 14 L58 8 L58 50 L42 56 L22 50 L6 56Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M22 8 L22 50 M42 14 L42 56" stroke="#a8997c" stroke-width="2.5"/>
  <path d="M12 44 Q20 30 30 34 Q40 38 46 24" fill="none" stroke="{CRIMSON}" stroke-width="3" stroke-dasharray="3 4" stroke-linecap="round"/>
  <path d="M44 18 L52 26 M52 18 L44 26" stroke="{CRIMSON}" stroke-width="4" stroke-linecap="round"/>''')
    # Range rings (the tactical map's toggle): a tower's dot in two rings.
    icon_svg("icon_range", f'''
  <ellipse cx="32" cy="34" rx="28" ry="20" fill="none" stroke="{INK}" stroke-width="6"/>
  <ellipse cx="32" cy="34" rx="28" ry="20" fill="none" stroke="{GOLD}" stroke-width="3"/>
  <ellipse cx="32" cy="34" rx="15" ry="10.5" fill="none" stroke="{INK}" stroke-width="5"/>
  <ellipse cx="32" cy="34" rx="15" ry="10.5" fill="none" stroke="#efe3c8" stroke-width="2.5"/>
  <rect x="27" y="14" width="10" height="20" fill="#8c7b62" stroke="{INK}" stroke-width="3"/>
  <path d="M25 14 L39 14 L39 9 L35 9 L35 12 L32 12 L32 9 L29 9 L29 12 L25 12Z" fill="#8c7b62" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>''')
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
    # Undo / redo (the map editor): the usual curved arrows, back to the left / on to the right.
    for name, flip in (("icon_undo", False), ("icon_redo", True)):
        tr = ' transform="translate(64 0) scale(-1 1)"' if flip else ''
        icon_svg(name, f'''
  <g{tr}>
  <path d="M20 24 H38 A14 14 0 0 1 38 52 H24" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M6 24 L22 10 L22 38 Z" fill="{INK}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
  <path d="M20 24 H38 A14 14 0 0 1 38 52 H24" fill="none" stroke="#efe3c8" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M6 24 L22 10 L22 38 Z" fill="#efe3c8" stroke="#efe3c8" stroke-width="1.5" stroke-linejoin="round"/>
  </g>''')


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
    # boulder_1: a low, split slab with a smaller stone behind it and lichen
    rng = random.Random(511)
    a = Art()
    a.shadow(28, 10, cy=2)
    _rock(a, rng, 12, -4, 11, 15, n=6)
    _rock(a, rng, -10, 4, 13, 10, n=6)
    _rock(a, rng, 7, 6, 10, 9, n=5)
    for x, y, r in [(-14, -4, 3.2), (-6, -3, 2.2), (12, -14, 2.6)]:
        a.ellipse(x, y, r, r * 0.55, "#a8a35a", opacity=0.75)
    a.line([(-2, -4), (0, 9)], INK, 1.2)  # the split
    a.save("boulder_1")


def well_dry():
    """A dried-up well (scenario 5's fort): a ring of stones, the shaft dark
    and dry, a weathered frame with a little roof and a frayed rope. Decor only."""
    rng = random.Random(530)
    a = Art()
    rx, ry, h = 17, 8.5, 13
    a.shadow(24, 10, cy=3)
    stone, stone_d, stone_l = "#78726a", "#5c574f", "#928c82"
    # The drum: its front half from the rim down to the ground.
    n = 16
    front = [(math.cos(math.pi * i / n) * rx, math.sin(math.pi * i / n) * ry) for i in range(n + 1)]
    body = [(x, y - h) for (x, y) in front] + [(x, y) for (x, y) in reversed(front)]
    a.poly(body, stone, INK, 1.4)
    for k, yy in enumerate([-h * 0.66, -h * 0.33]):  # stone courses and joints
        a.line([(x, y + yy) for (x, y) in front[1:-1]], stone_d, 1.0, opacity=0.8)
        for i in range(1 + k, n, 3):
            x, y = front[i]
            a.line([(x, y + yy), (x, y + yy + h * 0.33)], stone_d, 0.9, opacity=0.7)
    # The rim and the dry shaft.
    a.ellipse(0, -h, rx, ry, stone_l, INK, 1.4)
    a.ellipse(0, -h + 0.5, rx * 0.72, ry * 0.66, "#241c15", INK, 1.0)
    a.ellipse(1.5, -h + 2.2, rx * 0.42, ry * 0.3, "#5a4630", opacity=0.55)
    a.line([(-3, -h + 2), (0, -h + 3), (2, -h + 1.8), (5, -h + 3)], "#3a2c1e", 0.8)
    for _ in range(5):  # chipped stones on the rim
        ang = rng.uniform(0, math.pi * 2)
        a.ellipse(math.cos(ang) * rx * 0.86, -h + math.sin(ang) * ry * 0.86, 2.4, 1.3, stone_d, opacity=0.8)
    # The frame: two posts, a beam, a small gabled roof with a missing shingle.
    wood, wood_d = "#7a5a3a", "#5a4028"
    for x in (-rx * 0.82, rx * 0.82):
        a.line([(x, -h + 2), (x, -h - 30)], INK, 5.2)
        a.line([(x, -h + 2), (x, -h - 30)], wood, 3.0)
    a.line([(-rx * 0.82 - 2, -h - 27), (rx * 0.82 + 2, -h - 27)], INK, 4.6)
    a.line([(-rx * 0.82 - 2, -h - 27), (rx * 0.82 + 2, -h - 27)], wood_d, 2.6)
    a.poly([(-rx - 3, -h - 29), (0, -h - 40), (rx + 3, -h - 29), (rx - 1, -h - 27), (0, -h - 36), (-rx + 1, -h - 27)], "#6a4a2e", INK, 1.3)
    a.line([(4, -h - 34.5), (8, -h - 32)], "#2a1e14", 1.6)
    # The rope, frayed short of the water that isn't there.
    a.line([(0.5, -h - 27), (0.5, -h - 11)], "#b89a6a", 1.4)
    a.line([(0.5, -h - 11), (-1.2, -h - 8.5)], "#b89a6a", 0.9)
    a.line([(0.5, -h - 11), (2.2, -h - 8.8)], "#b89a6a", 0.9)
    a.save("well_dry")


# ---------------------------------------------------------------- the campaign map (title screen)

MAP_INK = "#4a3220"
MAP_LAYOUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "campaign_map.json")


def _hash01(i, j, seed):
    h = (i * 374761393 + j * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def _vnoise(x, y, seed):
    """Smooth value noise in -1..1 (cells of size 1)."""
    i, j = math.floor(x), math.floor(y)
    fx, fy = x - i, y - j
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = _hash01(i, j, seed)
    b = _hash01(i + 1, j, seed)
    c = _hash01(i, j + 1, seed)
    d = _hash01(i + 1, j + 1, seed)
    return (a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy) * 2 - 1


def _fbm(x, y, seed, octaves=4):
    v, amp, f, tot = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        v += _vnoise(x * f, y * f, seed + o * 31) * amp
        tot += amp
        amp *= 0.5
        f *= 2.0
    return v / tot


def chaikin(pts, n=3):
    """Corner-cutting smoothing, the ends kept (Campaign.smooth does the same)."""
    for _ in range(n):
        out = [pts[0]]
        for k in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[k], pts[k + 1]
            out.append((x0 * 0.75 + x1 * 0.25, y0 * 0.75 + y1 * 0.25))
            out.append((x0 * 0.25 + x1 * 0.75, y0 * 0.25 + y1 * 0.75))
        out.append(pts[-1])
        pts = out
    return pts


def _meander(pts, rng, amp=10.0, depth=4):
    """A river through `pts`: midpoints pushed sideways, again and again."""
    for _ in range(depth):
        out = [pts[0]]
        for k in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[k], pts[k + 1]
            dx, dy = x1 - x0, y1 - y0
            ln = math.hypot(dx, dy) or 1.0
            off = rng.uniform(-amp, amp) * min(1.0, ln / 60.0)
            out.append(((x0 + x1) / 2 - dy / ln * off, (y0 + y1) / 2 + dx / ln * off))
            out.append((x1, y1))
        pts = out
        amp *= 0.55
    return chaikin(pts, 2)


def _dashed(a, pts, color, w, dash, gap, opacity=None):
    """A dashed line along `pts` (SVG dashes are drawn as single strokes)."""
    seg, left, on, cur = [], dash, True, [pts[0]]
    for k in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        ln = math.hypot(x1 - x0, y1 - y0)
        t = 0.0
        while ln - t > left:
            t += left
            p = (x0 + (x1 - x0) * t / ln, y0 + (y1 - y0) * t / ln)
            if on:
                cur.append(p)
                seg.append(cur)
            cur = [p]
            on = not on
            left = dash if on else gap
        left -= ln - t
        if on:
            cur.append((x1, y1))
    if on and len(cur) > 1:
        seg.append(cur)
    for sg in seg:
        a.line(sg, color, w, opacity=opacity)


def _dist_to(pt, line):
    best = 1e9
    for k in range(len(line) - 1):
        (x0, y0), (x1, y1) = line[k], line[k + 1]
        dx, dy = x1 - x0, y1 - y0
        l2 = dx * dx + dy * dy or 1.0
        t = max(0.0, min(1.0, ((pt[0] - x0) * dx + (pt[1] - y0) * dy) / l2))
        best = min(best, math.hypot(pt[0] - x0 - dx * t, pt[1] - y0 - dy * t))
    return best


def _blob(cx, cy, rx, ry, seed, rough=0.22, n=48):
    pts = []
    for k in range(n):
        ang = 2 * math.pi * k / n
        r = 1.0 + rough * _fbm(math.cos(ang) * 1.6 + 7, math.sin(ang) * 1.6 + 3, seed, 3)
        pts.append((cx + math.cos(ang) * rx * r, cy + math.sin(ang) * ry * r))
    return pts


def _fmap_peak(a, x, y, s, rng):
    """A mountain in the old maps' way: a jagged cone, the lit side pale, the
    shaded side hatched."""
    h = s * rng.uniform(1.1, 1.6)
    lx, rx = x - s * rng.uniform(0.9, 1.1), x + s * rng.uniform(0.9, 1.1)
    top = (x + rng.uniform(-s * 0.15, s * 0.15), y - h)
    mid_l = (x - s * 0.45, y - h * 0.5 + rng.uniform(-2, 2))
    a.poly([(lx, y), mid_l, top, (x + s * 0.5, y - h * 0.45), (rx, y)], "#e2cfa3", MAP_INK, 1.2)
    a.poly([top, (x + s * 0.5, y - h * 0.45), (rx, y), (x + s * 0.1, y)], "#bfa37a", stroke=None)
    for k in range(4):
        t = 0.25 + k * 0.17
        px, py = top[0] + (rx - top[0]) * t, top[1] + (y - top[1]) * t
        a.line([(px, py), (px - s * 0.28, py + s * 0.18)], MAP_INK, 0.7, opacity=0.6)
    a.line([(lx, y), mid_l, top, (x + s * 0.5, y - h * 0.45), (rx, y)], MAP_INK, 1.2)


def _fmap_hill(a, x, y, s):
    a.line([(x - s, y), (x - s * 0.5, y - s * 0.55), (x, y - s * 0.7), (x + s * 0.5, y - s * 0.55), (x + s, y)], MAP_INK, 1.0)
    a.line([(x + s * 0.2, y - s * 0.45), (x + s * 0.45, y - s * 0.15)], MAP_INK, 0.7, opacity=0.6)


def _fmap_tree(a, x, y, s, kind):
    if kind == "pine":
        a.poly([(x - s * 0.55, y), (x, y - s * 1.7), (x + s * 0.55, y)], "#6f7a4c", MAP_INK, 0.9)
        a.line([(x, y - s * 1.6), (x + s * 0.4, y - s * 0.1)], "#55603a", 0.8)
    elif kind == "dead":
        a.line([(x, y), (x, y - s * 1.3)], MAP_INK, 0.9)
        a.line([(x, y - s * 0.8), (x - s * 0.5, y - s * 1.3)], MAP_INK, 0.8)
        a.line([(x, y - s * 1.0), (x + s * 0.45, y - s * 1.45)], MAP_INK, 0.8)
    else:
        a.line([(x, y), (x, y - s * 0.6)], MAP_INK, 0.9)
        a.ellipse(x, y - s * 1.0, s * 0.72, s * 0.62, "#8e9a62", MAP_INK, 0.9)
        a.ellipse(x + s * 0.2, y - s * 0.95, s * 0.35, s * 0.3, "#76824f", opacity=0.8)


def _fmap_hamlet(a, x, y, rng):
    for k in range(rng.randint(2, 3)):
        hx, hy = x + rng.uniform(-6, 6), y + rng.uniform(-3, 3)
        a.poly([(hx - 3, hy), (hx - 3, hy - 3), (hx, hy - 6), (hx + 3, hy - 3), (hx + 3, hy)], "#e8d6aa", MAP_INK, 0.8)
        a.poly([(hx - 3.6, hy - 2.6), (hx, hy - 6.4), (hx + 3.6, hy - 2.6)], "#a0522d", MAP_INK, 0.7)


def _fmap_fields(a, x, y, rng):
    ang = rng.uniform(0, math.pi)
    ca, sa = math.cos(ang), math.sin(ang)
    for k in range(-3, 4):
        off = k * 2.6
        p0 = (x - ca * 9 - sa * off, y - sa * 9 + ca * off)
        p1 = (x + ca * 9 - sa * off, y + sa * 9 + ca * off)
        a.line([p0, p1], "#9a8556", 0.6, opacity=0.7)


def campaign_map():
    """The campaign map (docs/story-design.md §4a, docs/ui-design.md): an old
    fantasy map of Veliron and its neighbours. Its layout (the places, the
    roads) comes from data/campaign_map.json; names are laid over it in the
    game, so there is no writing here."""
    import json
    with open(MAP_LAYOUT) as f:
        lay = json.load(f)
    W, H = lay["size"]
    rng = random.Random(4242)
    a = Art()
    places = {k: tuple(v["at"]) for k, v in lay["places"].items()}
    towns = {k: tuple(v) for k, v in lay.get("towns", {}).items()}
    nodes = dict(places)
    nodes.update(towns)
    nodes.update({k: tuple(v) for k, v in lay["junctions"].items()})
    roads = [chaikin([nodes[r["a"]]] + [tuple(p) for p in r["via"]] + [nodes[r["b"]]]) for r in lay["roads"]]

    def clear(pt, room=30.0, road_room=8.0):
        """Nothing drawn here: near a place or on a road."""
        if any(math.hypot(pt[0] - p[0], pt[1] - p[1]) < room for p in list(places.values()) + list(towns.values())):
            return False
        return all(_dist_to(pt, r) > road_room for r in roads)

    # --- the sheet ---
    a.raw('<defs><radialGradient id="vig" cx="50%" cy="50%" r="72%"><stop offset="55%" stop-color="#3a2410" stop-opacity="0"/>'
          '<stop offset="100%" stop-color="#3a2410" stop-opacity="0.6"/></radialGradient></defs>', [(0, 0), (W, H)])
    a.poly([(0, 0), (W, 0), (W, H), (0, H)], "#e4d3a8", stroke=None)
    for _ in range(60):
        a.ellipse(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(30, 150), rng.uniform(20, 90), rng.choice(["#d2bd8e", "#ecdfbb", "#cbb488"]), opacity=0.16)

    # --- the sea in the west, the coast ---
    def coast_x(y):
        x = 116 + 70 * _fbm(y / 170.0, 2.5, 11) + 20 * _fbm(y / 40.0, 9.1, 12) + 6 * _fbm(y / 9.0, 4.2, 13)
        for (cy, w, dx) in [(150, 34, -42), (240, 26, 30), (520, 40, 46), (610, 22, -34), (700, 30, 24)]:  # headlands and bays
            x += dx * math.exp(-((y - cy) / w) ** 2)
        g = math.exp(-((y - places["guild_town"][1]) / 30.0) ** 2)
        return x * (1 - g) + (places["guild_town"][0] - 18) * g
    coast = [(coast_x(y), y) for y in range(-4, H + 8, 4)]
    a.poly([(-4, -4)] + coast + [(-4, H + 8)], "#b4c4b2", stroke=None)
    for k, (off, op) in enumerate([(7, 0.5), (14, 0.32), (23, 0.2), (34, 0.12)]):
        a.line([(x - off, y) for (x, y) in coast], MAP_INK, 0.8, opacity=op)
    a.line(coast, MAP_INK, 2.0)
    for (ix, iy, r) in [(52, 130, 13), (78, 470, 9), (40, 560, 16), (95, 610, 6)]:
        isl = _blob(ix, iy, r, r * 0.7, int(ix + iy))
        for off, op in [(1.6, 0.4), (2.4, 0.2)]:
            a.line([(ix + (x - ix) * off, iy + (y - iy) * off) for (x, y) in isl] + [(ix + (isl[0][0] - ix) * off, iy + (isl[0][1] - iy) * off)], MAP_INK, 0.7, opacity=op)
        a.poly(isl, "#e4d3a8", MAP_INK, 1.4)
    for _ in range(30):
        x, y = rng.uniform(8, 80), rng.uniform(20, H - 20)
        if all(math.hypot(x - ix, y - iy) > r * 2 for (ix, iy, r) in [(52, 130, 13), (78, 470, 9), (40, 560, 16), (95, 610, 6)]):
            a.line([(x, y), (x + 4, y - 2.5), (x + 8, y), (x + 12, y - 2.5)], MAP_INK, 0.8, opacity=0.5)
    # A ship, and a sea serpent.
    sx, sy = 66, 268
    a.poly([(sx - 14, sy), (sx + 14, sy), (sx + 9, sy + 6), (sx - 10, sy + 6)], "#8a6040", MAP_INK, 1.1)
    a.line([(sx, sy), (sx, sy - 26)], MAP_INK, 1.2)
    a.poly([(sx + 1, sy - 24), (sx + 13, sy - 12), (sx + 1, sy - 4)], "#efe3c2", MAP_INK, 1.0)
    a.poly([(sx - 1, sy - 22), (sx - 11, sy - 8), (sx - 1, sy - 5)], "#efe3c2", MAP_INK, 1.0)
    a.line([(sx - 18, sy + 9), (sx - 8, sy + 7), (sx + 4, sy + 9), (sx + 18, sy + 7)], MAP_INK, 0.7, opacity=0.6)
    sx, sy = 52, 400
    for k, (hx, hw) in enumerate([(0, 9), (17, 8), (32, 6)]):
        a.poly([(sx + hx - hw, sy), (sx + hx - hw * 0.8, sy - hw), (sx + hx, sy - hw * 1.3), (sx + hx + hw * 0.8, sy - hw), (sx + hx + hw, sy)], "#6f8a6a", MAP_INK, 1.0)
    a.poly([(sx - 13, sy), (sx - 16, sy - 13), (sx - 23, sy - 17), (sx - 26, sy - 13), (sx - 18, sy - 10), (sx - 9, sy)], "#6f8a6a", MAP_INK, 1.0)
    a.ellipse(sx - 21, sy - 14.5, 1.0, 1.0, MAP_INK)
    a.line([(sx + 36, sy), (sx + 44, sy - 6), (sx + 46, sy - 2)], MAP_INK, 1.4)
    a.line([(sx - 30, sy + 3), (sx + 50, sy + 3)], MAP_INK, 0.7, opacity=0.5)

    def land(pt):
        return pt[0] > coast_x(pt[1]) + 6

    # --- the wilderness beyond the Wardline ---
    def wall_y(x):
        return 74 + 7 * _fbm(x / 80.0, 1.3, 21)
    wall = [(x, wall_y(x)) for x in range(int(coast_x(70)), W + 6, 6)]
    a.poly([(coast_x(0), -4), (W + 4, -4)] + list(reversed(wall)), "#bfa77a", stroke=None, opacity=0.55)
    wild = []
    for _ in range(900):
        x, y = rng.uniform(coast_x(30) + 8, W - 2), rng.uniform(10, 66)
        if y < wall_y(x) - 7 and _fbm(x / 60.0, y / 60.0, 22) > -0.15:
            wild.append((x, y, "dead" if rng.random() < 0.55 else "pine"))
    for (x, y, kind) in sorted(wild, key=lambda q: q[1]):
        _fmap_tree(a, x, y, 5.5, kind)
    for _ in range(26):
        x, y = rng.uniform(coast_x(30) + 10, W - 6), rng.uniform(14, 60)
        if y < wall_y(x) - 8:
            _rock_glyph = [(x - 4, y), (x - 2, y - 4), (x + 2, y - 5), (x + 5, y)]
            a.poly(_rock_glyph, "#b8a27a", MAP_INK, 0.8)

    # --- the neighbours' borders (washed over at the end) ---
    def east_x(y):
        return 985 + 14 * _fbm(y / 70.0, 4.4, 31)

    def south_y(x):
        return 668 + 10 * _fbm(x / 70.0, 8.8, 32)

    def split_y(x):
        return 335 + 9 * _fbm(x / 50.0, 2.2, 33)

    def veliron(pt):
        return land(pt) and pt[0] < east_x(pt[1]) and pt[1] < south_y(pt[0]) and pt[1] > wall_y(pt[0])

    # --- the great lake, the rivers ---
    ab = places["abbey"]
    lake = _blob(ab[0], ab[1] - 2, 98, 46, 41, 0.18, 64)
    rivers = [
        _meander([(806, 214), (760, 262), (712, 352), (640, 404), (570, 478), (508, 560), (474, 578)], random.Random(51), 26, 5),
        _meander([(338, 596), (282, 604), (220, 626), (170, 640), (coast_x(650) - 2, 650)], random.Random(52), 20, 5),
        _meander([(338, 96), (318, 168), (262, 236), (206, 300), (places["guild_town"][0] - 8, places["guild_town"][1] - 4)], random.Random(53), 22, 5),
        _meander([(1040, 260), (1030, 360), (1010, 450), (1000, 560), (990, 700)], random.Random(54), 22, 5),
    ]
    for k, rv in enumerate(rivers):
        a.line(rv, MAP_INK, 4.6 if k < 3 else 3.6)
        a.line(rv, "#a9c0bb", 3.0 if k < 3 else 2.2)
    for off, op in [(1.08, 0.45), (1.17, 0.25), (1.28, 0.12)]:
        a.line([(ab[0] + (x - ab[0]) * off, ab[1] + (y - ab[1]) * off) for (x, y) in lake + [lake[0]]], MAP_INK, 0.8, opacity=op)
    a.poly(lake, "#b4c4b2", MAP_INK, 1.8)
    a.poly(_blob(ab[0], ab[1] + 3, 22, 12, 42, 0.15), "#e4d3a8", MAP_INK, 1.2)

    def wet(pt):
        if math.hypot((pt[0] - ab[0]) / 112, (pt[1] - ab[1]) / 58) < 1.0:
            return True
        return any(_dist_to(pt, rv) < 7 for rv in rivers)

    # --- mountains and hills ---
    peaks = []

    def ridge(pts, n, size, spread, seed):
        r = random.Random(seed)
        line = chaikin(pts, 2)
        lens = [math.dist(line[k], line[k + 1]) for k in range(len(line) - 1)]
        total = sum(lens)
        for _ in range(n):
            t = r.uniform(0, total)
            k = 0
            while t > lens[k]:
                t -= lens[k]
                k += 1
            (x0, y0), (x1, y1) = line[k], line[k + 1]
            px, py = x0 + (x1 - x0) * t / lens[k], y0 + (y1 - y0) * t / lens[k]
            d = r.gauss(0, spread)
            pt = (px + d * 0.4, py + d)
            if clear(pt, 32, 10) and land(pt) and not wet(pt) and pt[1] > wall_y(pt[0]) + 12:
                peaks.append((pt[0], pt[1], r.uniform(size * 0.75, size * 1.25)))
    ridge([(610, 112), (690, 138), (770, 158), (812, 168)], 34, 15, 9, 61)
    ridge([(846, 168), (900, 180), (960, 214), (1040, 236), (1120, 214), (1190, 190)], 50, 14, 10, 62)
    ridge([(850, 220), (880, 280), (905, 330)], 16, 12, 7, 63)
    ridge([(1020, 120), (1090, 140), (1180, 128)], 22, 12, 8, 64)
    ridge([(210, 520), (260, 560), (300, 600)], 12, 10, 7, 65)
    ridge([(560, 712), (720, 726), (880, 716), (1040, 728), (1180, 712)], 40, 13, 8, 66)
    for (x, y, sz) in sorted(peaks, key=lambda q: q[1]):
        _fmap_peak(a, x, y, sz, rng)
    for _ in range(70):
        pk = rng.choice(peaks)
        pt = (pk[0] + rng.uniform(-40, 40), pk[1] + rng.uniform(16, 40))
        if clear(pt, 30, 9) and land(pt) and not wet(pt):
            _fmap_hill(a, pt[0], pt[1], rng.uniform(6, 9))
    for _ in range(320):
        pt = (rng.uniform(140, W - 10), rng.uniform(90, H - 10))
        if clear(pt, 30, 7) and land(pt) and not wet(pt) and pt[1] > wall_y(pt[0]) + 8 and not any(math.hypot(pt[0] - q[0], pt[1] - q[1]) < q[2] * 1.6 for q in peaks):
            x, y = pt
            a.line([(x - 2.5, y), (x - 3.5, y - 3)], "#8a7a50", 0.7, opacity=0.6)
            a.line([(x, y), (x, y - 3.6)], "#8a7a50", 0.7, opacity=0.6)
            a.line([(x + 2.5, y), (x + 3.5, y - 3)], "#8a7a50", 0.7, opacity=0.6)

    # --- forests: dense clumps ---
    trees = []

    def forest(cx, cy, rx, ry, seed, kind, spacing=8.5):
        r = random.Random(seed)
        y = cy - ry
        while y < cy + ry:
            x = cx - rx
            while x < cx + rx:
                px, py = x + r.uniform(-3, 3), y + r.uniform(-2, 2)
                d = math.hypot((px - cx) / rx, (py - cy) / ry)
                edge = 0.75 + 0.3 * _fbm(px / 40.0, py / 40.0, seed)
                if d < edge and clear((px, py), 28, 7) and land((px, py)) and not wet((px, py)) and py > wall_y(px) + 8:
                    if not any(math.hypot(px - q[0], py - q[1]) < q[2] * 1.4 for q in peaks):
                        trees.append((px, py, kind if kind != "mixed" else ("pine" if r.random() < 0.35 else "oak")))
                x += spacing
            y += spacing * 0.8
    forest(868, 456, 100, 78, 71, "mixed")
    forest(250, 178, 78, 52, 72, "pine")
    forest(318, 512, 58, 40, 73, "oak")
    forest(700, 600, 64, 34, 74, "oak")
    forest(1090, 480, 86, 110, 75, "mixed")
    forest(1110, 600, 60, 40, 76, "oak")
    forest(590, 210, 40, 28, 77, "oak")
    for (x, y, kind) in sorted(trees, key=lambda q: q[1]):
        _fmap_tree(a, x, y, 5.2, kind)

    # --- roads, hamlets and fields along them ---
    for r in roads:
        a.line(r, "#f0e4c4", 3.4, opacity=0.8)
        _dashed(a, r, "#7a5638", 1.5, 5, 3.5)
    for r in roads:
        for k in range(len(r) // 9, len(r) - 1, max(1, len(r) // 2)):
            px, py = r[k]
            ox, oy = px + rng.choice([-1, 1]) * rng.uniform(12, 18), py + rng.uniform(-10, 10)
            if clear((ox, oy), 34, 6) and veliron((ox, oy)) and not wet((ox, oy)):
                _fmap_hamlet(a, ox, oy, rng)
                for _ in range(2):
                    fx, fy = ox + rng.uniform(-22, 22), oy + rng.uniform(6, 16)
                    if clear((fx, fy), 30, 6) and veliron((fx, fy)) and not wet((fx, fy)):
                        _fmap_fields(a, fx, fy, rng)
    for (hx, hy) in [(1080, 380), (1130, 290), (1060, 690), (860, 700), (380, 700), (1150, 560)]:
        _fmap_hamlet(a, hx, hy, rng)
    for (tx, ty) in towns.values():  # unnamed towns: a walled ring of houses
        a.ellipse(tx, ty + 2, 17, 10, "#d8c294", MAP_INK, 1.4)
        for k in range(7):
            ang = math.pi * 2 * k / 7 + 0.3
            hx, hy = tx + math.cos(ang) * 9, ty + 2 + math.sin(ang) * 5
            a.poly([(hx - 3, hy), (hx - 3, hy - 3), (hx, hy - 6), (hx + 3, hy - 3), (hx + 3, hy)], "#e8d6aa", MAP_INK, 0.8)
            a.poly([(hx - 3.6, hy - 2.6), (hx, hy - 6.4), (hx + 3.6, hy - 2.6)], "#a0522d", MAP_INK, 0.7)
        a.poly([(tx - 3, ty + 1), (tx - 3, ty - 9), (tx, ty - 13), (tx + 3, ty - 9), (tx + 3, ty + 1)], "#e8d6aa", MAP_INK, 0.9)
        for (wx, wy) in [(-17, 2), (17, 2), (0, -8), (0, 12)]:
            a.poly([(tx + wx - 2.5, ty + wy + 1), (tx + wx - 2.5, ty + wy - 5), (tx + wx + 2.5, ty + wy - 5), (tx + wx + 2.5, ty + wy + 1)], "#d8c294", MAP_INK, 0.8)

    # --- the Wardline: a wall with towers along the border ---
    a.line(wall + [], MAP_INK, 3.2)
    a.line(wall, "#cdb68a", 1.6)
    for k in range(0, len(wall), 3):
        x, y = wall[k]
        if x < east_x(y):
            a.line([(x, y - 1), (x, y - 3.5)], MAP_INK, 1.0)
    for k in range(4, len(wall), 11):
        x, y = wall[k]
        if x < east_x(y) - 4:
            a.poly([(x - 4, y + 2), (x - 4, y - 9), (x - 5.5, y - 9), (x - 5.5, y - 13), (x - 2, y - 13), (x - 2, y - 11), (x + 2, y - 11),
                    (x + 2, y - 13), (x + 5.5, y - 13), (x + 5.5, y - 9), (x + 4, y - 9), (x + 4, y + 2)], "#d8c294", MAP_INK, 1.0)

    # --- the neighbours: washed over, behind hand-drawn borders ---
    east = [(east_x(y), y) for y in range(int(wall_y(990)), int(south_y(990)) + 1, 5)]
    south = [(x, south_y(x)) for x in range(int(coast_x(670)), W + 6, 5)]
    split = [(x, split_y(x)) for x in range(int(east_x(335)), W + 6, 5)]
    a.poly(east + [(W + 4, south_y(W)), (W + 4, wall_y(W))], "#8a6a40", stroke=None, opacity=0.2)
    a.poly(south + [(W + 4, H + 4), (coast_x(H), H + 4)], "#8a6a40", stroke=None, opacity=0.2)
    for line in (east, south, split):
        _dashed(a, line, "#7a2e1e", 1.8, 10, 4, opacity=0.75)
        _dashed(a, line[1:], "#7a2e1e", 1.8, 1.5, 12.5, opacity=0.75)

    # --- a compass rose ---
    cx, cy = 60, 690
    a.ellipse(cx, cy, 30, 30, "#efe3c2", MAP_INK, 1.2, opacity=0.9)
    a.ellipse(cx, cy, 24, 24, "none", MAP_INK, 0.7)
    for k in range(16):
        ang = math.radians(k * 22.5)
        ln = 34 if k % 4 == 0 else (22 if k % 2 == 0 else 14)
        tip = (cx + math.sin(ang) * ln, cy - math.cos(ang) * ln)
        for sgn, col in [(1, MAP_INK if k % 4 == 0 else "#7a2e1e"), (-1, "#efe3c2")]:
            side = (cx + math.sin(ang + sgn * 0.5) * 4.5, cy - math.cos(ang + sgn * 0.5) * 4.5)
            a.poly([(cx, cy), side, tip], col, MAP_INK, 0.6)
    a.line([(cx - 3, cy - 44), (cx - 3, cy - 52), (cx + 3, cy - 44), (cx + 3, cy - 52)], MAP_INK, 1.4)

    # --- age: specks, two folds, the darkened edges ---
    for _ in range(260):
        a.ellipse(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.4, 1.4), rng.uniform(0.4, 1.2), "#6a4a2a", opacity=rng.uniform(0.15, 0.35))
    for (p0, p1) in [((W / 2, 0), (W / 2, H)), ((0, H / 2), (W, H / 2))]:
        a.line([p0, p1], "#8a6a40", 1.6, opacity=0.18)
        a.line([(p0[0] + 1.6, p0[1] + 1.6), (p1[0] + 1.6, p1[1] + 1.6)], "#fff6dc", 1.2, opacity=0.25)
    a.raw('<rect x="0" y="0" width="%d" height="%d" fill="url(#vig)"/>' % (W, H), [(0, 0), (W, H)])
    a.save("campaign_map", fixed=(0, 0, W, H))


def _pin_base(a):
    a.ellipse(0, 1.5, 22, 22, "#000", opacity=0.3)
    a.ellipse(0, 0, 21, 21, "#efe2bf", MAP_INK, 2.2)
    a.ellipse(0, 0, 17.5, 17.5, "none", MAP_INK, 0.8)


def campaign_pins():
    """The places on the campaign map: a parchment disc with an inked symbol each."""
    a = Art(); _pin_base(a)  # the outpost: a walled village
    a.poly([(-12, 8), (-12, -2), (12, -2), (12, 8)], "#cdb68a", MAP_INK, 1.4)
    for x in (-12, -4, 4):
        a.poly([(x, -2), (x, -5), (x + 3, -5), (x + 3, -2)], "#cdb68a", MAP_INK, 1.0)
    a.poly([(-6, -2), (0, -12), (6, -2)], "#a0522d", MAP_INK, 1.4)
    a.poly([(-2, 8), (-2, 3), (2, 3), (2, 8)], MAP_INK, stroke=None)
    a.save("pin_outpost")
    a = Art(); _pin_base(a)  # the guild town: an anchor
    a.ellipse(0, -11, 3, 3, "none", MAP_INK, 1.8)
    a.line([(0, -8), (0, 11)], MAP_INK, 2.4)
    a.line([(-7, -4), (7, -4)], MAP_INK, 2.2)
    a.line([(-10, 3), (-8, 9), (0, 12), (8, 9), (10, 3)], MAP_INK, 2.2)
    a.save("pin_guild")
    a = Art(); _pin_base(a)  # the old fort: a tower between peaks
    a.poly([(-15, 10), (-8, -4), (-2, 10)], "#b39a6c", MAP_INK, 1.2)
    a.poly([(2, 10), (9, -6), (15, 10)], "#b39a6c", MAP_INK, 1.2)
    a.poly([(-4, 10), (-4, -6), (-6, -6), (-6, -11), (-2, -11), (-2, -8), (2, -8), (2, -11), (6, -11), (6, -6), (4, -6), (4, 10)], "#cdb68a", MAP_INK, 1.3)
    a.save("pin_fort")
    a = Art(); _pin_base(a)  # the battlefield: crossed swords
    for sgn in (-1, 1):
        a.line([(-11 * sgn, 11), (10 * sgn, -11)], MAP_INK, 2.6)
        a.line([(-11 * sgn, 11), (10 * sgn, -11)], "#d8d0c0", 1.0)
        a.line([(-9 * sgn, 4), (-3 * sgn, 10)], MAP_INK, 2.4)
    a.save("pin_battlefield")
    a = Art(); _pin_base(a)  # the refuge: a grove
    for (x, s) in [(-7, 8), (7, 8), (0, 10)]:
        a.line([(x, 12), (x, 3)], MAP_INK, 1.6)
        a.ellipse(x, -2 if s == 10 else 1, s, s * 0.85, "#7d8a5a", MAP_INK, 1.3)
    a.save("pin_grove")
    a = Art(); _pin_base(a)  # the capital and the court: a crown
    a.poly([(-12, 8), (-13, -8), (-6, -1), (0, -12), (6, -1), (13, -8), (12, 8)], "#c9a24a", MAP_INK, 1.5)
    for x in (-13, 0, 13):
        a.ellipse(x, -10 if x else -14, 2, 2, "#c94a3a", MAP_INK, 0.8)
    a.line([(-12, 4), (12, 4)], MAP_INK, 1.0)
    a.save("pin_palace")
    a = Art(); _pin_base(a)  # the abbey: a chapel on water
    a.line([(-15, 11), (-10, 9), (-5, 11), (0, 9), (5, 11), (10, 9), (15, 11)], "#5f7f7a", 1.6)
    a.poly([(-8, 7), (-8, -3), (0, -9), (8, -3), (8, 7)], "#cdb68a", MAP_INK, 1.4)
    a.line([(0, -9), (0, -17)], MAP_INK, 1.6)
    a.line([(-3, -14), (3, -14)], MAP_INK, 1.6)
    a.poly([(-2, 7), (-2, 1), (2, 1), (2, 7)], MAP_INK, stroke=None)
    a.save("pin_abbey")
    # A completed place: a red wax seal with a check.
    rng = random.Random(77)
    a = Art()
    rim = []
    for i in range(18):
        ang = math.pi * 2 * i / 18
        r = 13 + rng.uniform(-1.5, 1.5)
        rim.append((math.cos(ang) * r, math.sin(ang) * r))
    a.poly(rim, "#9a2a22", MAP_INK, 1.2)
    a.ellipse(0, 0, 9, 9, "#b33a2e", "#7a1e18", 1.0)
    a.line([(-5, 0), (-1.5, 4), (5.5, -4.5)], "#f0d8b0", 2.4)
    a.save("map_seal")


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


def chapel(awake=False):
    """Ruined chapel (the acolyte's unlock site): a small stone nave with a broken roof, an open
    bell-cote over the gable, ivy and rubble. Awake: light falls through the roof, the window
    glows and motes drift up."""
    rng = random.Random(680)
    a = Art()
    a.shadow(46, 20, cy=4)
    sl, sr, st = "#7a756c", "#56524b", "#8e897f"
    w, l, H, R = 0.32, 0.5, 34, 22   # half width, half length (tiles), wall and roof height (px)

    def p(gx, gy, z=0.0):
        return P(gx, gy, z)
    # walls: the gable end (front-left, gy = +l) and the long side (front-right, gx = +w)
    a.poly([p(-w, l), p(w, l), p(w, l, H), p(0, l, H + R), p(-w, l, H)], sl, INK, 1.3)
    a.poly([p(w, l), p(w, -l), p(w, -l, H), p(w, l, H)], sr, INK, 1.3)
    for z in (9, 18, 27):  # stone courses
        a.line([p(-w, l, z), p(w, l, z), p(w, -l, z)], "#3e3b37", 0.8, opacity=0.7)
    # broken roof: the near slope survives at both ends, a hole with bare rafters between
    rl, rr = "#4a3a30", "#3a2c24"
    a.poly([p(w + 0.04, l + 0.04, H - 2), p(w + 0.04, 0.12, H - 2), p(0, 0.2, H + R), p(0, l + 0.04, H + R)], rl, INK, 1.2)
    a.poly([p(w + 0.04, -0.3, H - 2), p(w + 0.04, -l - 0.04, H - 2), p(0, -l - 0.04, H + R), p(0, -0.22, H + R)], rr, INK, 1.2)
    a.poly([p(w, 0.12, H), p(w, -0.3, H), p(0, -0.22, H + R), p(0, 0.2, H + R)], "#16120f", INK, 1.0)
    for gy in (0.02, -0.14):
        a.line([p(w, gy, H), p(0, gy, H + R)], WOOD_D, 2.4)
    for gy in (0.36, -0.42):
        a.line([p(w, gy, H + 1), p(0, gy, H + R - 1)], "#2a201a", 0.8, opacity=0.8)
    if awake:
        _glow(a, *p(0.12, -0.05, H + 8), 30, 26, "#ffe9a0", 0.6)
        x0, y0 = p(0.15, -0.05, H + R + 70)
        x1, y1 = p(0.15, -0.05, 4)
        a.poly([(x0 - 10, y0), (x0 + 10, y0), (x1 + 16, y1), (x1 - 16, y1)], "#fff2c0", stroke=None, opacity=0.28)
        a.poly([(x0 - 4, y0), (x0 + 4, y0), (x1 + 7, y1), (x1 - 7, y1)], "#fffbe6", stroke=None, opacity=0.4)
    # door in the gable end, arched window in the side
    dx, dy = p(0, l)
    a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#141110" stroke="%s" stroke-width="1.2"/>'
          % (fmt(dx - 6), fmt(dy - 1), fmt(dx - 6), fmt(dy - 15), fmt(dx), fmt(dy - 23), fmt(dx + 6), fmt(dy - 15 + 3), fmt(dx + 6), fmt(dy + 2), INK),
          [(dx - 7, dy - 23), (dx + 7, dy + 2)])
    wx, wy = p(w, 0.22, 14)
    if awake:
        _glow(a, wx, wy - 6, 16, 18, "#ffd970", 0.7)
    a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="%s" stroke="%s" stroke-width="1.1"/>'
          % (fmt(wx - 3), fmt(wy + 1), fmt(wx - 3), fmt(wy - 9), fmt(wx), fmt(wy - 15), fmt(wx + 3), fmt(wy - 11), fmt(wx + 3), fmt(wy - 1),
             "#ffe39a" if awake else "#141110", INK), [(wx - 4, wy - 15), (wx + 4, wy + 2)])
    # bell-cote on the gable's peak: two posts, a little roof, the bell
    bx, by = p(0, l, H + R)
    a.poly([(bx - 6, by + 1), (bx - 4, by + 1), (bx - 4, by - 16), (bx - 6, by - 16)], st, INK, 1)
    a.poly([(bx + 4, by + 1), (bx + 6, by + 1), (bx + 6, by - 16), (bx + 4, by - 16)], sr, INK, 1)
    a.poly([(bx - 8, by - 16), (bx, by - 23), (bx + 8, by - 16)], rl, INK, 1.1)
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s" stroke="%s" stroke-width="0.9"/>'
          % (fmt(bx - 3.5), fmt(by - 5), fmt(bx - 3), fmt(by - 14), fmt(bx), fmt(by - 14), fmt(bx + 3), fmt(by - 14), fmt(bx + 3.5), fmt(by - 5),
             GOLD if awake else GOLD_D, INK), [(bx - 4, by - 15), (bx + 4, by - 4)])
    # a cross over the cote
    a.line([(bx, by - 23), (bx, by - 31)], INK, 2.4)
    a.line([(bx - 3, by - 28), (bx + 3, by - 28)], INK, 2.4)
    a.line([(bx, by - 23), (bx, by - 31)], GOLD if awake else "#8a857c", 1.2)
    a.line([(bx - 3, by - 28), (bx + 3, by - 28)], GOLD if awake else "#8a857c", 1.2)
    # ivy on the walls
    for _ in range(22):
        if rng.random() < 0.5:
            gx, gy = rng.uniform(-w, w), l
        else:
            gx, gy = w, rng.uniform(-l, l)
        x, y = p(gx, gy, rng.uniform(2, 24))
        a.ellipse(x, y, rng.uniform(2, 3.4), rng.uniform(1.4, 2.2), rng.choice(["#2e4a26", "#3a5a2c", "#28401f"]), opacity=0.95)
    # rubble: fallen roof stones and a slate or two
    for (gx, gy, rr) in [(0.62, 0.1, 4.5), (0.55, -0.42, 3.5), (-0.28, 0.78, 4)]:
        x, y = p(gx, gy)
        _rock(a, rng, x, y, rr, None, sl, sr, st, sw=1.0, n=5)
    x, y = p(0.6, 0.45)
    a.poly([(x - 5, y), (x + 3, y - 3), (x + 6, y + 1), (x - 2, y + 3)], rl, INK, 0.8)
    if awake:
        for (x, y) in [(-12, -96), (10, -112), (20, -84), (-2, -126)]:
            a.ellipse(x, y, 4, 4, "#ffe9a0", opacity=0.35)
            a.ellipse(x, y, 1.4, 1.4, "#fffbe6")
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
    well_dry()
    campaign_map()
    campaign_pins()
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
    _save_pair(chapel(), chapel(True), "chapel_ruin", "chapel_awake")
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


# ---------------------------------------------------------------- wolves and riders (docs/enemies-design.md §15e)

WOLF_FUR, WOLF_FUR_D, WOLF_FUR_L = "#5e5954", "#45413d", "#7a756e"


def _wolf_body(a):
    """A grey wolf, side view, facing right, paws at y=0, its back at about y=-22."""
    a.shadow(22, 5, opacity=0.38)
    for hip, foot in (((-12, -11), (-15, 0)), ((11, -11), (13, 0))):  # far legs
        a.line([hip, foot], INK, 4.6)
        a.line([hip, foot], WOLF_FUR_D, 2.8)
    a.raw('<path d="M-17,-17 Q-26,-16 -30,-8 Q-25,-12 -18,-12Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (WOLF_FUR, INK), [(-31, -18), (-16, -7)])  # tail
    a.ellipse(-1, -15, 18, 7.5, WOLF_FUR, INK, 1.3)  # body
    a.ellipse(1, -11.5, 12, 3, WOLF_FUR_L, opacity=0.55)  # lighter belly
    for x in (-10, -5, 0):  # hackles
        a.line([(x, -21.5), (x - 2, -24)], WOLF_FUR_D, 1.3)
    for hip, foot in (((-8, -11), (-10, 0)), ((14, -11), (16, 0))):  # near legs
        a.line([hip, foot], INK, 4.8)
        a.line([hip, foot], WOLF_FUR, 3.0)
        a.ellipse(foot[0] + 1, foot[1] - 0.5, 2.6, 1.3, WOLF_FUR_D, INK, 0.8)
    a.poly([(10, -19), (15, -26), (20, -24), (17, -15)], WOLF_FUR, INK, 1.2)  # neck
    a.ellipse(19, -24, 6, 5, WOLF_FUR, INK, 1.2)  # head
    a.poly([(22, -27), (31, -22.5), (30, -20), (22, -20)], WOLF_FUR_L, INK, 1.1)  # snout
    a.ellipse(30.5, -21.7, 1.2, 1.0, INK)  # nose
    a.line([(24, -20.5), (29.5, -20.2)], INK, 0.9)  # jaw
    a.poly([(23, -19.6), (24, -18), (25, -19.6)], "#e8e0c8", INK, 0.5)  # fang
    a.poly([(15, -28), (16.5, -34), (19.5, -29)], WOLF_FUR_D, INK, 1.0)  # ears
    a.poly([(18, -28.5), (20.5, -33.5), (22, -28)], WOLF_FUR, INK, 1.0)
    a.ellipse(21.5, -25, 1.3, 1.0, "#f0c040")  # eye


def wolf():
    a = Art()
    _wolf_body(a)
    a.save("unit_wolf")


def corpse_wolf():
    a = Art()
    a.ellipse(0, 0, 22, 6, "#000", opacity=0.3)
    a.ellipse(0, 1, 16, 4, "#3a1a14", opacity=0.5)  # dark stain
    a.raw('<path d="M-16,-2 Q-24,0 -26,4 Q-20,3 -15,2Z" fill="%s" stroke="%s" stroke-width="1.1"/>' % (WOLF_FUR, INK), [(-27, -3), (-14, 5)])  # tail
    a.ellipse(-2, -2, 15, 5, WOLF_FUR, INK, 1.2)  # body on its side
    a.ellipse(-2, -0.5, 10, 2.2, WOLF_FUR_L, opacity=0.5)
    for x0, x1 in ((-8, -12), (-3, -6), (6, 9), (10, 14)):  # legs stretched out
        a.line([(x0, 1), (x1, 6)], INK, 3.4)
        a.line([(x0, 1), (x1, 6)], WOLF_FUR_D, 2.0)
    a.ellipse(15, -2, 5.5, 4, WOLF_FUR, INK, 1.1)  # head
    a.poly([(18, -3.5), (25, -1), (18, 1)], WOLF_FUR_L, INK, 1.0)  # snout
    a.poly([(12, -5), (13, -10), (16, -5.5)], WOLF_FUR_D, INK, 0.9)  # ear
    a.line([(15, -3), (17, -1)], INK, 1.0)  # closed eye
    a.save("corpse_wolf")


def _horse_body(a, coat, coat_d, mane, cloth=None, trim=None):
    """A horse, side view, facing right, hooves at y=0, the saddle at about
    y=-40. `cloth`: a long caparison over it (the Legion's), `trim` its hem."""
    a.shadow(30, 6, opacity=0.4)
    for hip, knee, foot in (((-17, -24), (-19, -12), (-18, 0)), ((14, -24), (17, -12), (16, 0))):  # far legs
        a.line([hip, knee, foot], INK, 5.4)
        a.line([hip, knee, foot], coat_d, 3.6)
    a.raw('<path d="M-23,-36 Q-33,-32 -34,-16 Q-29,-24 -24,-29Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (mane, INK), [(-35, -37), (-22, -15)])  # tail
    a.ellipse(-2, -32, 24, 10, coat, INK, 1.4)  # barrel
    for hip, knee, foot in (((-13, -24), (-14, -12), (-12, 0)), ((18, -24), (20, -12), (21, 0))):  # near legs
        a.line([hip, knee, foot], INK, 5.6)
        a.line([hip, knee, foot], coat, 3.8)
        a.poly([(foot[0] - 2.5, -2.5), (foot[0] + 3, -2.5), (foot[0] + 3.5, 0.5), (foot[0] - 2.8, 0.5)], "#2a211a", INK, 0.8)  # hoof
    a.poly([(14, -36), (22, -52), (29, -50), (24, -32)], coat, INK, 1.3)  # neck
    a.poly([(23, -55), (37, -46), (36, -41), (30, -40), (22, -48)], coat, INK, 1.3)  # head
    a.ellipse(35.5, -43.5, 1.1, 0.9, INK)  # nostril
    a.ellipse(27.5, -50, 1.3, 1.1, "#1a1410")  # eye
    a.poly([(23, -55), (24.5, -60), (26.5, -54)], coat_d, INK, 0.9)  # ear
    a.raw('<path d="M23,-55 Q16,-48 13,-37 Q18,-44 22,-49Z" fill="%s" stroke="%s" stroke-width="1"/>' % (mane, INK), [(12, -56), (24, -36)])  # mane
    if cloth:
        a.raw('<path d="M-22,-40 Q-3,-45 16,-40 L18,-22 Q-3,-17 -24,-22Z" fill="%s" stroke="%s" stroke-width="1.3"/>' % (cloth, INK), [(-25, -46), (19, -16)])
        if trim:
            a.raw('<path d="M18,-22 Q-3,-17 -24,-22" fill="none" stroke="%s" stroke-width="1.8"/>' % trim, [(-25, -23), (19, -17)])
        a.line([(26, -50), (30, -40)], "#3a2a1c", 1.4)  # bridle
    a.poly([(-9, -42), (8, -42), (6, -37), (-7, -37)], "#3a2a1c", INK, 1.1)  # saddle


LEGION_HORSE = ("#4a4a50", "#38383e", "#2a2a2e")


def horse():
    """The Legion's mount without its rider (a run-off horse, an undead horse)."""
    a = Art()
    _horse_body(a, *LEGION_HORSE, cloth="#6a6e7a")
    a.save("unit_horse")


def corpse_horse():
    coat, coat_d, mane = LEGION_HORSE
    a = Art()
    a.ellipse(0, 0, 32, 8, "#000", opacity=0.3)
    a.ellipse(-2, 1, 24, 5, "#3a1a14", opacity=0.5)
    a.raw('<path d="M-24,-2 Q-32,0 -36,6 Q-29,4 -23,2Z" fill="%s" stroke="%s" stroke-width="1.1"/>' % (mane, INK), [(-37, -3), (-22, 7)])  # tail
    a.ellipse(-4, -4, 22, 7.5, coat, INK, 1.3)  # barrel on its side
    a.raw('<path d="M-18,-8 Q-4,-12 10,-8 L11,0 Q-4,3 -19,0Z" fill="#6a6e7a" stroke="%s" stroke-width="1.1"/>' % INK, [(-20, -13), (12, 3)])  # torn caparison
    for x0, x1 in ((-14, -18), (-8, -11), (6, 10), (12, 17)):  # legs stretched out
        a.line([(x0, 2), (x1, 9)], INK, 4.2)
        a.line([(x0, 2), (x1, 9)], coat_d, 2.6)
    a.poly([(14, -6), (30, -4), (31, 1), (15, 2)], coat, INK, 1.2)  # neck and head, lying
    a.poly([(14, -6), (24, -7), (22, -5)], mane, INK, 0.8)
    a.line([(26, -3), (28, -1)], INK, 1.0)  # closed eye
    a.save("corpse_horse")


def _seat(a, rider, seat_y, hip_y, leg, boot=INK):
    """Puts the saved sprite `rider` (feet at its own (0, 0)) on a mount: cut
    off below `hip_y` (its own coordinates), its hips at `seat_y`, and a leg
    hanging down the mount's flank (`leg`: the near leg's colour)."""
    with open(os.path.join(ART, rider + ".svg")) as f:
        svg = f.read()
    body = svg[svg.index(">", svg.index("<svg")) + 1:svg.rindex("</svg>")].strip()
    lines = [l for l in body.split("\n") if l.strip()]
    if lines and 'fill="#000"' in lines[0]:  # (its own shadow: the mount has one)
        lines = lines[1:]
    m = manifest[rider]
    dy = seat_y - hip_y
    cid = "seat_" + rider
    inner = "\n  ".join(l.strip() for l in lines)
    a.raw('<clipPath id="%s"><rect x="-80" y="-120" width="160" height="%s"/></clipPath><g transform="translate(0,%s)"><g clip-path="url(#%s)">%s</g></g>'
          % (cid, fmt(120 + hip_y), fmt(dy), cid, inner),
          [(-m["ax"], -m["ay"] + dy), (-m["ax"] + m["w"], hip_y + dy)])
    a.line([(0, seat_y - 1), (3, seat_y + 9)], INK, 5)  # the near leg down the flank
    a.line([(0, seat_y - 1), (3, seat_y + 9)], leg, 3)
    a.ellipse(4, seat_y + 10, 3.2, 1.6, boot, INK, 0.8)


def goblin_raider():
    a = Art()
    _wolf_body(a)
    a.poly([(-7, -23), (5, -23), (4, -19.5), (-6, -19.5)], "#5a3a22", INK, 0.9)  # a crude saddle
    _seat(a, "unit_goblin", -19, -8, "#4a6029", "#2a211a")
    a.save("unit_goblin_raider")


def mounted(rider, name, cloth, trim=None, coat=LEGION_HORSE, leg="#3a3128"):
    """`rider` (a saved Legion sprite) on a horse: `name`."""
    a = Art()
    _horse_body(a, *coat, cloth=cloth, trim=trim)
    _seat(a, rider, -40, -11, leg)
    a.save(name)


def riders():
    goblin_raider()
    mounted("unit_legion_footman", "unit_legion_cavalry", "#6a6e7a")
    mounted("unit_legion_captain", "unit_legion_captain_mounted", "#3a3a42", "#b8bcc4")
    mounted("unit_legion_captain_lysa", "unit_legion_captain_lysa_mounted", CRIMSON_D, GOLD_D)
    mounted("unit_legion_marshal", "unit_legion_marshal_mounted", "#5e626c", GOLD)
    mounted("unit_legion_king", "unit_legion_king_mounted", "#c4c8d2", GOLD, coat=("#d8d4cc", "#b4b0a8", "#e8e4dc"), leg="#a4a8b2")


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
    for i in range(4):
        mountain(i)
    tree_pine(0)
    tree_pine(1)
    tree_spruce()
    for i in range(3):
        tree_oak(i)
    tree_dead(0)
    tree_dead(1)
    hut()
    hut(ruin=True)
    for lvl in (1, 2, 3):
        wall(lvl)
        gate(lvl)
    wall_ruin()
    gate_ruin()
    wall_tower_ruin()
    rubble()
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
    village_pieces_materials()
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
    slimes()
    spider_mother()
    corpse_spider_mother()
    spiderling()
    spider_eggs()
    wrathwood()
    corpse_wrathwood()
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
    shield_bearer_branches()
    crossbowman()
    swiftbowman()
    fire_summoner()
    fire_elemental()
    mages()
    acolytes()
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
    thief()
    gargoyle(0)
    gargoyle(1)
    necromancer()
    corpse_thief()
    corpse_gargoyle()
    corpse_necromancer()
    vampire()
    vampire_bat(0)
    vampire_bat(1)
    corpse_vampire()
    vulture(0)
    vulture(1)
    vulture_landed()
    corpse_vulture()
    crab()
    corpse_crab()
    leviathan()
    corpse_leviathan()
    siren()
    corpse_siren()
    octopus()
    corpse_octopus()
    octopus_arm()
    spell_bolt()
    spell_glow()
    arrow()
    sack()
    biome_art()
    icons()
    title_icons()
    flags()
    app_icon()
    tent_small()
    stall(1)
    stall(3)
    merchant()
    barracks_ruin()
    warehouse()
    guild_house()
    guild_master()
    legion_footman()
    legion_captain("unit_legion_captain", "#b8bcc4")
    legion_captain("unit_legion_captain_lysa", CRIMSON, hair="#6a2a20")
    portraits()
    portraits_away()
    corpse_fallen("corpse_fallen", "#2f4a7a", "#243a62")
    corpse_fallen("corpse_fallen_2", CRIMSON, CRIMSON_D)
    graveyard()
    grave_mound()
    grave_cross()
    grove()
    druid()
    thornling()
    priest_person()
    eldest_priest_person()
    princess()
    campaign_houses()
    portraits_67()
    legion_archer()
    legion_guard()
    legion_banner()
    legion_champion()
    herald()
    legion_camp()
    legion_camp(True)
    abbey()
    abbey(True)
    church()
    pier()
    boat()
    boat(sail=True)
    harbour_crates()
    net_rack()
    relic_sword()
    ferry_bell()
    beacon()
    wreck()
    fish_rack()
    boat_upturned()
    mooring_post()
    driftwood()
    gull()
    portraits_89()
    legion_marshal()
    legion_king()
    for i in range(3):
        tile_cobble(i)
    city_houses()
    city_rubble()
    throne_hall()
    portraits_1011()
    campaign_icon()
    wolf()
    corpse_wolf()
    horse()
    corpse_horse()
    riders()  # (after the riders' own sprites: it seats them)
    write_manifest()
    print("generated %d sprites" % len(manifest))


if __name__ == "__main__":
    main()
