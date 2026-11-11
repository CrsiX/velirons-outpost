"""Props: map decor (reeds, boulders, the dry well, cactus, charred stumps, lava rocks,
the volcano), the scenarios' decor (Brenna's tent, the fallen, graves, city rubble)
and the harbour's (pier, boats, crates, nets, the ferry bell, the beacon, the wreck,
...)."""

import math
import random

from .core import (
    Art, _block, BONE, BONE_D, CRIMSON, CRIMSON_D, DIRT, DIRT_LIGHT, fmt, _glow, GOLD, GOLD_D, INK,
    P, rand_in_diamond, _rock, STONE_R, STONE_T, WOOD, WOOD_D, WOOD_L,
)


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
