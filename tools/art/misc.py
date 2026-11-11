"""Small bits (arrow, throwing axe, net pin, sack), the treasures, salvage, and
biome_art(), which draws the sprites added for the biomes."""

import math
import random

from .core import (
    _arc, Art, BONE, _bone, BONE_D, CRIMSON, diamond, DIRT, DIRT_DARK, DIRT_LIGHT, fmt, GLOW, _glow,
    GOLD, INK, P, rand_in_diamond, _rock, _save_pair, _tuft, WOOD, WOOD_D, WOOD_L,
)
from .campaign_map import campaign_map, campaign_pins
from .enemies import lair_cave, lair_crypt, lair_pit, lair_ruin, lair_tree
from .props import (
    boulder, cactus, lava_rock, reeds, stump_charred, volcano, volcano_smoke, well_dry,
)
from .sites import camp, chapel, mage_tower, mine, stone_circle, watchtower_ruin
from .terrain import (
    bridge, tile_ash, tile_foam, tile_ford, tile_forest_oak, tile_grass_dark, tile_heath, tile_lava,
    tile_meadow, tile_road_pass, tile_sand, tile_shallow, tile_swamp, tile_water,
)
from .units import miner


def salvage():
    """A lost trade caravan's cargo on the ground: a broken crate, spilled sacks."""
    a = Art()
    a.shadow(14, 5, opacity=0.3)
    a.poly([(-12, -1), (-2, -3), (-1, -12), (-11, -10)], "#b08a58", INK, 1.1)
    a.line([(-12, -5), (-1, -7)], WOOD_D, 0.9)
    a.line([(-9, -10), (-4, -1)], WOOD_D, 1.2)  # a broken slat
    a.ellipse(5, -4, 6, 4.5, "#c9a86a", INK, 1.0)
    a.ellipse(10, -2, 4, 3.2, "#b8955a", INK, 0.9)
    a.ellipse(2, -10, 4, 3, "#d4b478", INK, 0.9)
    a.save("salvage")


# ---------------------------------------------------------------- small bits

def arrow():
    a = Art()
    a.line([(-12, 0), (10, 0)], INK, 2.4)
    a.line([(-12, 0), (10, 0)], "#b08a58", 1.2)
    a.poly([(9, -2.5), (15, 0), (9, 2.5)], "#9a9a9a", INK, 1)
    a.poly([(-15, -2.5), (-10, 0), (-15, 2.5), (-12, 0)], CRIMSON, INK, 0.8)
    a.save("arrow")


def throwing_axe():
    """The hero's thrown hatchet (item throwing_axes), haft along x; it whirls in flight."""
    a = Art()
    a.line([(-8, 0), (7, 0)], INK, 3.2)
    a.line([(-8, 0), (7, 0)], WOOD_L, 1.8)
    a.line([(-6.5, -1), (-6.5, 1)], INK, 0.8)
    a.poly([(3.5, 1.9), (8, 1.9), (8.5, -2.5), (11, -7), (1.5, -7.5), (4, -2.5)], "#b4bcc6", INK, 1.1)
    a.line([(2.6, -6.4), (10, -6.1)], "#e8edf2", 0.9)
    a.save("throwing_axe")


def net_pin():
    """A net thrown over an enemy (item net): a rope mesh draped over a body, centred
    about (0, -14), lead weights on its hem. Drawn translucent over the unit."""
    def pt(u, v):
        x = -15 * math.cos(math.pi * u) * (0.5 + 0.5 * v)
        y = -29 + 27 * v + 3.5 * (1 - math.sin(math.pi * u)) * (1 - v) + 2.5 * math.sin(math.pi * u) * v
        return x, y

    n = 5
    rope = ""
    knots = ""
    for i in range(n + 1):
        for line in ([pt(i / n, k / 10.0) for k in range(11)], [pt(k / 12.0, i / n) for k in range(13)]):
            rope += " M" + " L".join("%s %s" % (fmt(x), fmt(y)) for x, y in line)
        for j in range(n + 1):
            x, y = pt(i / n, j / n)
            knots += '<circle cx="%s" cy="%s" r="0.9" fill="#8a6a3a"/>' % (fmt(x), fmt(y))
    outline = [pt(k / 12.0, 0) for k in range(13)] + [pt(1, k / 10.0) for k in range(11)] + \
              [pt(1 - k / 12.0, 1) for k in range(13)] + [pt(0, 1 - k / 10.0) for k in range(11)]
    d = " L".join("%s %s" % (fmt(x), fmt(y)) for x, y in outline)
    weights = ""
    for i in (0, 2, 3, 5):
        x, y = pt(i / n, 1)
        weights += ('<circle cx="%s" cy="%s" r="2" fill="#5a5e66" stroke="%s" stroke-width="0.8"/>'
                    % (fmt(x), fmt(y + 1.5), INK))
    a = Art()
    a.raw('<g opacity="0.88"><path d="M%s Z" fill="#c8a870" opacity="0.16"/>'
          '<path d="%s" fill="none" stroke="%s" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" opacity="0.7"/>'
          '<path d="%s" fill="none" stroke="#d8b878" stroke-width="0.9" stroke-linecap="round" stroke-linejoin="round"/>%s%s</g>'
          % (d, rope.strip(), INK, rope.strip(), knots, weights), [(-15.5, -30), (15.5, 3.5)])
    a.save("net_pin")


def sack():
    a = Art()
    a.raw('<path d="M-6,0 Q-8,-8 -3,-10 L-4,-13 L4,-13 L3,-10 Q8,-8 6,0 Z" fill="#b89a60" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % INK, [(-8, -14), (8, 0)])
    a.line([(-3.5, -10.5), (3.5, -10.5)], "#6a5230", 1.4)
    a.save("sack")


# ------------------------------------------------------------------ treasures

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
