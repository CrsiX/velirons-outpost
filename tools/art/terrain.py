"""Ground tiles (the first ones and the biomes' newer ones), mountains, the village
path tile, the capital's cobbles and the bridges."""

import math
import random

from .core import (
    _arc, Art, diamond, DIRT, DIRT_DARK, DIRT_LIGHT, fmt, FOREST_FLOOR, _glow, GRASS, GRASS_DARK,
    GRASS_LIGHT, INK, P, rand_in_diamond, _tuft, WOOD, WOOD_D, WOOD_L,
)


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


def tile_village_path():
    """The path cross inside the village's walls: trodden earth with flagstones."""
    rng = random.Random(61)
    a = Art()
    a.poly(diamond(1.12), DIRT, stroke=None, opacity=0.4)
    a.poly(diamond(1.0), DIRT_LIGHT, stroke=None)
    for _ in range(9):
        x, y = rand_in_diamond(rng, 0.7)
        w, hh = rng.uniform(8, 13), rng.uniform(4, 6)
        a.poly([(x - w, y), (x - w * 0.3, y - hh), (x + w * 0.8, y - hh * 0.8), (x + w, y + 1), (x + w * 0.2, y + hh * 0.7), (x - w * 0.7, y + hh * 0.6)],
               rng.choice(["#8d877c", "#7f796f", "#958f83"]), "#4b4438", 1.0)
    a.save("tile_village_path", pad=0, fixed=(-72, -36, 72, 36))
