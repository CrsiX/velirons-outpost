"""Buildings that aren't village pieces: rubble, farm, worker camp, light stone,
barracks, training grounds, the market and stall, the town hall (HALL_BENCH), the
Legion camp, the abbey, the church, the throne hall, the capital's houses and the
scenarios' other houses."""

import math
import random

from .core import (
    _arc, Art, _block, BRASS, CRIMSON, CRIMSON_D, diamond, DIRT, DIRT_DARK, DIRT_LIGHT, fmt, GLOW,
    _glow, GOLD, GOLD_D, hanging_banner, INK, IRON, _opening, P, rand_in_diamond, shade, STONE_D,
    STONE_L, STONE_R, STONE_T, TH, WOOD, WOOD_D, WOOD_L,
)
from .village.basalt import BAS_D, BAS_L, BAS_R, BAS_T, LAVA, LAVA_GLOW
from .village.granite import GRAN_D, GRAN_L, GRAN_R, GRAN_T, SLATE_L, SLATE_R, TARTAN
from .village.ice import (
    COLD_FIRE, FROST, ICE_D, ICE_DEEP, ICE_L, ICE_R, ICE_T, SNOW, SNOW_L, SNOW_R,
)
from .village.limestone import LICHEN, LIME_J, LIME_L, LIME_R, LIME_T, PLANK_D, SHINGLE, SHINGLE_D
from .village.sandstone import DOOR_BLUE_D, SAND_D, SAND_L, SAND_R, SAND_T, TILE_BLUE, TILE_BLUE_D
from .village.wood import HIDE, HIDE_D, LOG, LOG_D, LOG_L


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


def _market_house(a, x0, x1, y0, y1, h, ridge, wall, wall_r, roof, roof_l, stone=False):
    """A gabled trading house along x for the marketplace (ridge along x)."""
    if stone:
        a.box(x0, x1, y0, y1, 0, h, STONE_T, STONE_L, STONE_R)
        for k in range(1, 4):  # stone courses
            a.line([P(x0, y1, h * k / 4), P(x1, y1, h * k / 4)], STONE_D, 0.8)
    else:
        a.box(x0, x1, y0, y1, 0, 10, STONE_T, STONE_L, STONE_R)
        a.box(x0, x1, y0, y1, 10, h, wall, wall, wall_r)
        for t in (0.0, 0.33, 0.66, 1.0):
            gx = x0 + (x1 - x0) * t
            a.line([P(gx, y1, 10), P(gx, y1, h)], "#3b2a1d", 1.8)
    ym = (y0 + y1) / 2
    ey, ex = 0.07, 0.04
    slope = (ridge - h) / (y1 - ym)
    eave = h - slope * ey
    xa, xb = x0 - ex, x1 + ex
    a.poly([P(xa, y0 - ey, eave), P(xb, y0 - ey, eave), P(xb, ym, ridge), P(xa, ym, ridge)], roof)
    a.poly([P(x1, y0, h), P(x1, ym, ridge), P(x1, y1, h)], wall_r if not stone else STONE_R)
    a.poly([P(xa, ym, ridge), P(xb, ym, ridge), P(xb, y1 + ey, eave), P(xa, y1 + ey, eave)], roof_l)
    for t in (0.33, 0.66):
        yy = ym + (y1 + ey - ym) * t
        a.line([P(xa, yy, ridge - (ridge - eave) * t), P(xb, yy, ridge - (ridge - eave) * t)], shade(roof, 0.8), 1.1)
    a.line([P(xa, ym, ridge), P(xb, ym, ridge)], "#3b2a1d", 2.2)


def _market_goods(a, spots):
    """Crates, barrels and sacks at grid offsets."""
    for i, (gx, gy) in enumerate(spots):
        x, y = P(gx, gy, 0)
        if i % 3 == 0:
            a.box(gx - 0.09, gx + 0.09, gy - 0.09, gy + 0.09, 0, 9, "#b08a58", WOOD, WOOD_D, sw=1)
        elif i % 3 == 1:
            a.poly([(x - 5, y), (x + 5, y), (x + 6, y - 12), (x - 6, y - 12)], WOOD, INK, 1)
            a.line([(x - 5.5, y - 4), (x + 5.5, y - 4)], "#6a6a6a", 1.1)
            a.ellipse(x, y - 12, 6, 2.2, WOOD_D, INK, 0.8)
        else:
            a.ellipse(x - 2, y - 4, 5, 4.2, "#c9a86a", INK, 0.9)
            a.ellipse(x + 4, y - 3, 4.2, 3.6, "#b8955a", INK, 0.9)


def _market_banner(a, gx, gy, h, col):
    px, py = P(gx, gy, 0)
    a.line([(px, py), (px, py - h)], WOOD_D, 2.4)
    a.poly([(px, py - h), (px + 16, py - h + 4), (px + 16, py - h + 18), (px + 8, py - h + 14), (px, py - h + 18)], col, INK, 1)
    a.line([(px + 5, py - h + 7), (px + 11, py - h + 9)], GOLD, 1.2)


def _market_cart(a, gx, gy):
    """A two-wheeled handcart parked in the yard, piled with sacks (faces left)."""
    x, y = P(gx, gy, 0)
    a.line([(x + 14, y - 8), (x + 32, y - 2)], WOOD_D, 2.4)  # handles on the ground
    a.line([(x + 12, y - 12), (x + 31, y - 5)], WOOD_D, 2.0)
    a.poly([(x - 18, y - 12), (x + 14, y - 20), (x + 14, y - 12), (x - 18, y - 4)], WOOD_L, INK, 1.2)  # bed
    a.poly([(x - 18, y - 12), (x + 14, y - 20), (x + 12, y - 27), (x - 20, y - 19)], WOOD, INK, 1.2)  # side board
    a.ellipse(x - 8, y - 26, 7, 5.5, "#c9a86a", INK, 1)
    a.ellipse(x + 3, y - 29, 6.5, 5, "#b8955a", INK, 1)
    a.ellipse(x - 3, y - 34, 5.5, 4.2, "#d4b478", INK, 1)
    a.ellipse(x - 2, y - 5, 8, 8, WOOD_D, INK, 1.3)  # wheel
    a.ellipse(x - 2, y - 5, 2.2, 2.2, "#3a2a1a")
    for d in ((-6, 0), (6, 0), (0, -6), (0, 6)):
        a.line([(x - 2, y - 5), (x - 2 + d[0], y - 5 + d[1])], INK, 0.9)


def _market_well(a, gx, gy):
    """A small stone well with a wooden winch roof."""
    x, y = P(gx, gy, 0)
    a.ellipse(x, y - 2, 13, 6.5, STONE_D, INK, 1.2)
    a.poly([(x - 13, y - 2), (x - 13, y - 12), (x + 13, y - 12), (x + 13, y - 2)], STONE_L, None)
    a.line([(x - 13, y - 2), (x - 13, y - 12)], INK, 1.2)
    a.line([(x + 13, y - 2), (x + 13, y - 12)], INK, 1.2)
    a.raw('<path d="M%s,%s A13,6.5 0 0 0 %s,%s" fill="none" stroke="%s" stroke-width="1.2"/>' % (fmt(x - 13), fmt(y - 2), fmt(x + 13), fmt(y - 2), INK), [(x - 13, y - 2), (x + 13, y + 5)])
    a.ellipse(x, y - 12, 13, 6.5, STONE_T, INK, 1.2)
    a.ellipse(x, y - 12, 9, 4.2, "#1e2a30", INK, 0.8)
    for sx in (-10, 10):
        a.line([(x + sx, y - 12), (x + sx, y - 32)], WOOD_D, 2.2)
    a.poly([(x - 15, y - 30), (x + 15, y - 30), (x + 10, y - 39), (x - 10, y - 39)], "#6e4a30", INK, 1.1)
    a.line([(x, y - 30), (x, y - 18)], "#c8b080", 1)
    a.poly([(x - 3, y - 18), (x + 3, y - 18), (x + 2.5, y - 13), (x - 2.5, y - 13)], WOOD, INK, 0.8)


def _market_paving(a, s, seed):
    """Cobbles over the square's packed earth, thinning towards its edges."""
    rng = random.Random(seed)
    for _ in range(70):
        gx, gy = rng.uniform(-s + 0.1, s - 0.1), rng.uniform(-s + 0.1, s - 0.1)
        if rng.random() < max(abs(gx), abs(gy)) / s - 0.2:
            continue
        x, y = P(gx, gy, 0)
        w = rng.uniform(4.5, 7.5)
        col = rng.choice(["#8b877f", "#7d7970", "#958f84", "#6f6b63"])
        a.ellipse(x, y, w, w * 0.5, col, "#4f4a42", 0.6, opacity=0.85)


def _market_produce(a, gx, gy, kind):
    """A basket of apples, a crate of cabbages or a rolled rug at grid offset."""
    x, y = P(gx, gy, 0)
    if kind == "apples":
        a.poly([(x - 7, y - 1), (x + 7, y - 1), (x + 8, y - 8), (x - 8, y - 8)], "#a07a48", INK, 1)
        for dx, dy in ((-4, -9), (0, -10), (4, -9), (-2, -12), (2, -12)):
            a.ellipse(x + dx, y + dy, 2.3, 2.3, "#b0302a", INK, 0.6)
    elif kind == "greens":
        a.box(gx - 0.08, gx + 0.08, gy - 0.08, gy + 0.08, 0, 7, "#b08a58", WOOD, WOOD_D, sw=1)
        for dx in (-4, 0, 4):
            a.ellipse(x + dx, y - 9, 3, 2.4, "#6a9a3a", INK, 0.6)
    else:  # a rolled rug and a bolt of cloth
        a.poly([(x - 12, y - 2), (x + 10, y - 8), (x + 12, y - 4), (x - 10, y + 2)], "#7a3a5a", INK, 1)
        a.ellipse(x + 11, y - 6, 2.4, 3.2, "#5a2a42", INK, 0.8)
        a.line([(x - 8, y - 1), (x + 8, y - 5.5)], GOLD, 0.9)


def _market_lantern(a, gx, gy, h):
    x, y = P(gx, gy, 0)
    a.line([(x, y), (x, y - h)], WOOD_D, 2)
    a.line([(x, y - h), (x + 6, y - h - 2)], WOOD_D, 1.6)
    a.poly([(x + 4, y - h), (x + 9, y - h - 1), (x + 9, y - h + 7), (x + 4, y - h + 8)], GOLD, INK, 0.9)
    a.ellipse(x + 6.5, y - h + 3.5, 1.6, 2, "#fff4c0")


def market(level):
    """The marketplace (3x3, docs/market-design.md): a cobbled square with a
    well, striped booths full of goods, lanterns, a merchant's handcart and
    crates and barrels; level 2 adds a timber trading house at the back and a
    third booth; level 3 (guild market) a stone hall with arches, the guild's
    banners and sign, and a fourth booth."""
    a = Art()
    s = 1.48
    a.shadow(130, 62, cy=8, opacity=0.25)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], DIRT_LIGHT, INK, 1.0, opacity=0.92)
    _market_paving(a, s, 77 + level)
    for (gx0, gy0, gx1, gy1) in [(-s, s, s, s), (s, -s, s, s)]:  # a low kerb along the front edges
        a.line([P(gx0, gy0, 0), P(gx1, gy1, 0)], STONE_D, 2.6)
        a.line([P(gx0, gy0, 2), P(gx1, gy1, 2)], STONE_T, 1.2)
    if level >= 3:
        _market_house(a, -1.35, 0.55, -1.35, -0.55, 40, 74, None, None, "#2e3a44", "#3e4c58", stone=True)
        for t in (0.2, 0.5, 0.8):  # arches
            gx = -1.35 + 1.9 * t
            a.poly([P(gx - 0.14, -0.55, 0), P(gx + 0.14, -0.55, 0), P(gx + 0.14, -0.55, 18), P(gx, -0.55, 25), P(gx - 0.14, -0.55, 18)], "#22180f", INK, 1)
        sx, sy = P(0.55, -0.95, 30)  # the guild's scales on the gable
        a.poly([(sx - 2, sy - 10), (sx + 12, sy - 15), (sx + 12, sy - 1), (sx - 2, sy + 4)], "#2f4a6a", INK, 1)
        a.line([(sx + 5, sy - 10), (sx + 5, sy - 1)], GOLD, 1.4)
        a.line([(sx + 1, sy - 6), (sx + 9, sy - 9)], GOLD, 1.4)
        _market_banner(a, 0.8, -1.25, 70, "#2f4a6a")
        _market_banner(a, -1.3, 0.2, 60, CRIMSON)
    elif level >= 2:
        _market_house(a, -1.3, 0.3, -1.35, -0.65, 30, 58, "#8c7b62", "#6c5e4a", "#5a3a26", "#6e4a30")
        a.poly([P(-0.65, -0.65, 0), P(-0.35, -0.65, 0), P(-0.35, -0.65, 20), P(-0.65, -0.65, 20)], "#22180f", INK, 1)
        bx, by = P(-0.1, -0.65, 26)  # a hanging sign
        a.line([(bx, by), (bx + 10, by - 3)], WOOD_D, 1.6)
        a.poly([(bx + 4, by - 1), (bx + 12, by - 3), (bx + 12, by + 5), (bx + 4, by + 7)], GOLD_D, INK, 0.9)
        _market_banner(a, 0.75, -1.2, 58, CRIMSON)
        _market_cart(a, 0.95, -0.85)
    else:
        _market_cart(a, -0.75, -0.95)
        _market_banner(a, 0.9, -1.1, 52, CRIMSON)
        a.box(-0.05, 0.25, -1.25, -1.0, 0, 10, "#b08a58", WOOD, WOOD_D, sw=1)  # a stack of crates at the back
        a.box(0.0, 0.2, -1.2, -1.05, 10, 19, "#c09a68", "#8a6440", WOOD_D, sw=1)
    _market_well(a, -1.0, 0.95)
    _market_goods(a, [(1.15, 0.2), (1.25, 0.45), (1.0, 0.55), (-1.25, 0.25), (-0.95, 1.3), (0.2, 1.2)])
    _market_produce(a, 0.85, 0.15, "apples")
    _market_produce(a, -0.25, 0.85, "greens")
    _market_produce(a, 0.45, 0.4, "rug")
    _awning_stall(a, 0.35, -0.2, 0.4, 0.22, [CRIMSON, "#e8dcc0"])
    _awning_stall(a, -0.55, 0.3, 0.32, 0.2, ["#2f5a7a", "#e8dcc0"])
    if level >= 2:
        _awning_stall(a, 0.55, 0.85, 0.3, 0.18, ["#5a7a2f", "#e8dcc0"])
    if level >= 3:
        _awning_stall(a, 1.0, -0.85, 0.28, 0.18, [GOLD_D, "#e8dcc0"])
    _market_lantern(a, 1.35, 1.35, 40)
    _market_lantern(a, -1.35, 1.35, 40)
    a.save("market" if level == 1 else "market_%d" % level)


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


# ------------------------------------------------------------ the town hall

# Per material (Config.PIECE_MATERIALS): wall faces (top, lit left, shaded right),
# joints, roof (lit front slope, shaded hip, ridge/eave trim), window light,
# door, accent (banners, trim).
HALL_PALETTES = {
    "stone": {"t": STONE_T, "l": STONE_L, "r": STONE_R, "j": STONE_D, "roof": "#3e4c58", "roof_r": "#2e3a44", "trim": WOOD_D,
              "glow": GLOW, "door": "#3b2a1d", "accent": CRIMSON, "accent_d": CRIMSON_D, "metal": GOLD},
    "sandstone": {"t": SAND_T, "l": SAND_L, "r": SAND_R, "j": SAND_D, "roof": "#b5603f", "roof_r": "#8e4630", "trim": "#6e4a2a",
                  "glow": GLOW, "door": DOOR_BLUE_D, "accent": TILE_BLUE, "accent_d": TILE_BLUE_D, "metal": BRASS},
    "basalt": {"t": BAS_T, "l": BAS_L, "r": BAS_R, "j": BAS_D, "roof": "#2a2630", "roof_r": "#1d1a22", "trim": "#121016",
               "glow": LAVA_GLOW, "door": "#141218", "accent": "#a8361e", "accent_d": "#701f12", "metal": LAVA},
    "limestone": {"t": LIME_T, "l": LIME_L, "r": LIME_R, "j": LIME_J, "roof": SHINGLE, "roof_r": SHINGLE_D, "trim": PLANK_D,
                  "glow": GLOW, "door": "#2c4a5a", "accent": "#2f6a7a", "accent_d": "#1f4a56", "metal": LICHEN},
    "granite": {"t": GRAN_T, "l": GRAN_L, "r": GRAN_R, "j": GRAN_D, "roof": SLATE_L, "roof_r": SLATE_R, "trim": "#2a2522",
                "glow": GLOW, "door": "#3b2a1d", "accent": TARTAN, "accent_d": "#1f3d27", "metal": GOLD},
    "ice": {"t": ICE_T, "l": ICE_L, "r": ICE_R, "j": ICE_D, "roof": SNOW_L, "roof_r": SNOW_R, "trim": FROST,
            "glow": COLD_FIRE, "door": ICE_DEEP, "accent": FROST, "accent_d": "#1f4466", "metal": "#dff4ff"},
    "wood": {"t": LOG_L, "l": LOG, "r": LOG_D, "j": "#2e1f12", "roof": HIDE, "roof_r": HIDE_D, "trim": "#2e1f12",
             "glow": GLOW, "door": "#22180f", "accent": CRIMSON, "accent_d": CRIMSON_D, "metal": GOLD},
}
HALL_BODY = (-0.86, 0.7, -0.8, 0.5)  # x0, x1, y0, y1 of the main block (grid, from the 2x2's middle)
HALL_H = 52  # its wall height
HALL_RIDGE = 108  # the hip roof's ridge
HALL_DECK = {2: 110, 3: 112}  # the tower post's platform height by level: a podium just over the ridge
HALL_BENCH = (0.86, 0.3)  # level 3's bench (grid, from the 2x2's middle), along the side wall on the front tile: HallBench.BENCH_SPOT seats its unit there
HALL_TOWER_BACK = 0.12  # the podium stands this far back (both grid axes) from the 2x2's middle: drawn centred, a little behind
HALL_PODIUM = 0.17  # the podium's half width


def _hall_face(face, at, u0, u1, z0, z1):
    """A rectangle on a visible face: 'left' (gy = at, u along gx) or 'right' (gx = at, u along gy)."""
    if face == "left":
        return [P(u0, at, z0), P(u1, at, z0), P(u1, at, z1), P(u0, at, z1)]
    return [P(at, u0, z0), P(at, u1, z0), P(at, u1, z1), P(at, u0, z1)]


def _hall_courses(a, pal, face, at, u0, u1, z0, z1, wood=False, step=11):
    """Brick courses (or log seams) across a face, joints staggered."""
    def pt(u, z):
        return P(u, at, z) if face == "left" else P(at, u, z)
    z = z0 + step
    row = 0
    while z < z1 - 3:
        a.line([pt(u0, z), pt(u1, z)], pal["j"], 1.0 if not wood else 1.4, opacity=0.8)
        row += 1
        z += step
    if wood:
        return
    z = z0
    row = 0
    while z < z1 - 3:
        u = u0 + (0.11 if row % 2 else 0.2)
        while u < u1 - 0.05:
            a.line([pt(u, z), pt(u, min(z + step, z1))], pal["j"], 0.9, opacity=0.7)
            u += 0.22
        z += step
        row += 1


def _hall_window(a, pal, face, at, u, z, w=0.07, h=13, arch=True):
    """A lit window with a sill, a mullion and (arch) a rounded head."""
    def pt(uu, zz):
        return P(uu, at, zz) if face == "left" else P(at, uu, zz)
    pts = [pt(u - w, z), pt(u + w, z), pt(u + w, z + h)]
    if arch:
        for k in range(1, 6):
            ang = math.pi * k / 6
            pts.append(pt(u + w * math.cos(ang), z + h + 4 * math.sin(ang)))
    pts.append(pt(u - w, z + h))
    a.poly(pts, pal["glow"], INK, 1.2)
    a.line([pt(u, z), pt(u, z + h + (3 if arch else 0))], pal["trim"], 1.3)
    a.line([pt(u - w, z + h * 0.5), pt(u + w, z + h * 0.5)], pal["trim"], 1.0)
    a.line([pt(u - w - 0.02, z - 1), pt(u + w + 0.02, z - 1)], pal["j"], 2.2)  # sill


def _hall_roof_z(gy, y0, y1, ym, h, ridge):
    """Height of the hip roof's long slopes at grid row gy."""
    half = (y1 - y0) / 2
    return ridge - (ridge - h) * abs(gy - ym) / half


def town_hall(material, level=1, front=False):
    """The town hall (docs/village-design.md §3a): a long hall of the village's
    material with a hip roof, arched lit windows, a gabled porch with a large
    front door on its left face, a clock in the porch's gable. Level 2 adds
    a podium on the ridge (the tower post; `front`: its front merlons,
    drawn over the unit), level 3 banners, gilding and a brazier."""
    pal = HALL_PALETTES[material]
    wood = material == "wood"
    a = Art()
    x0, x1, y0, y1 = HALL_BODY
    h, ridge = HALL_H, HALL_RIDGE
    ym = (y0 + y1) / 2
    d = 0.42  # the hips' run: the ridge runs from x0 + d to x1 - d
    deck = HALL_DECK.get(level, 0)
    ts = HALL_PODIUM
    if front:
        a._track(_hall_extent())
        if level >= 2:
            _hall_merlons(a, pal, ts + 0.03, deck, True, level)
        return a
    s = 0.98
    a.shadow(110, 52, cy=8)
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#5a4a36", INK, 1.0, opacity=0.6)  # the yard's trodden ground
    # Footing and walls.
    a.box(x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, 0, 7, pal["t"], pal["j"], pal["j"])
    a.box(x0, x1, y0, y1, 7, h, pal["t"], pal["l"], pal["r"])
    _hall_courses(a, pal, "left", y1, x0, x1, 7, h, wood)
    _hall_courses(a, pal, "right", x1, y0, y1, 7, h, wood)
    a.poly(_hall_face("left", y1, x0, x1, 7, h), "none")
    a.poly(_hall_face("right", x1, y0, y1, 7, h), "none")
    # Windows: two rows on the long face (the porch in the middle), two on the end.
    for u in (-0.56, -0.36, 0.3, 0.46):
        _hall_window(a, pal, "left", y1, u, 15)
    for u in (-0.55, -0.15, 0.25):
        _hall_window(a, pal, "right", x1, u, 15)
    for u in (-0.55, -0.15, 0.25):  # an upper row, smaller
        _hall_window(a, pal, "right", x1, u, 36, w=0.05, h=8, arch=False)
    for u in (-0.56, -0.36, 0.3, 0.46):
        _hall_window(a, pal, "left", y1, u, 36, w=0.05, h=8, arch=False)
    # Corner quoins (stone) or posts (wood) and a string course under the eaves.
    for (face, at, u) in [("left", y1, x0), ("left", y1, x1), ("right", x1, y0)]:
        for z in range(7, h - 4, 9):
            a.poly(_hall_face(face, at, u - 0.035, u + 0.035, z, z + 5), pal["t"] if not wood else pal["j"], INK, 0.8)
    a.line([P(x0, y1, h - 2), P(x1, y1, h - 2), P(x1, y0, h - 2)], pal["trim"], 3)
    # The roof: front slope and right hip (the back one is hidden), the podium on its ridge.
    ey = 0.08
    ra, rb = x0 + d, x1 - d
    eave = h - (ridge - h) * ey / ((y1 - y0) / 2)
    front_slope = [P(ra, ym, ridge), P(rb, ym, ridge), P(x1 + ey, y1 + ey, eave), P(x0 - ey, y1 + ey, eave)]
    hip = [P(rb, ym, ridge), P(x1 + ey, y0 - ey, eave), P(x1 + ey, y1 + ey, eave)]
    a.poly(front_slope, pal["roof"])
    a.poly(hip, pal["roof_r"])
    for t in (0.25, 0.5, 0.75):  # shingle / slate courses
        za = ridge - (ridge - eave) * t
        ya = ym + (y1 + ey - ym) * t
        xa = ra + (x0 - ey - ra) * t
        xb = rb + (x1 + ey - rb) * t
        a.line([P(xa, ya, za), P(xb, ya, za)], pal["roof_r"], 1.3)
        a.line([P(xb, ym + (y0 - ey - ym) * t, za), P(xb, ya, za)], INK, 1.0, opacity=0.35)
    if material == "ice":  # snow drifts along the eaves
        a.line([P(x0 - ey, y1 + ey, eave + 2), P(x1 + ey, y1 + ey, eave + 2), P(x1 + ey, y0 - ey, eave + 2)], SNOW, 4)
    a.line([P(ra, ym, ridge), P(rb, ym, ridge)], pal["trim"], 3)  # ridge
    a.line([P(rb, ym, ridge), P(x1 + ey, y1 + ey, eave)], pal["trim"], 2.2)  # hip edge
    a.line([P(x0 - ey, y1 + ey, eave), P(x1 + ey, y1 + ey, eave), P(x1 + ey, y0 - ey, eave)], INK, 1.6)
    if level < 2:  # a chimney at the back
        a.box(0.38, 0.5, -0.5, -0.38, ridge - 26, ridge + 8, pal["t"], pal["l"], pal["r"])
    else:
        _hall_podium(a, pal, ts, deck, level, lambda gy: _hall_roof_z(gy, y0 - ey, y1 + ey, ym, eave, ridge))
    # The porch: a gabled bay on the long face, its ridge across the hall, the big door in it.
    _hall_porch(a, pal, wood, level, h)
    if level >= 3:  # the bench by the door (HallBench), with a shield hung on the post at its end
        bx, by = HALL_BENCH
        for gy in (by - 0.12, by + 0.12):  # legs
            a.box(bx - 0.04, bx + 0.04, gy - 0.015, gy + 0.015, 0, 6, WOOD_D, WOOD_D, WOOD_D, sw=1.0)
        a.box(bx - 0.05, bx + 0.05, by - 0.15, by + 0.15, 6, 9, WOOD_L, WOOD, WOOD_D)
        a.box(bx - 0.015, bx + 0.015, by + 0.17, by + 0.2, 0, 26, WOOD, WOOD, WOOD_D, sw=1.0)  # a post at its front end
        x, y = P(bx, by + 0.2, 18)
        a.ellipse(x - 3, y, 5.5, 7, pal["accent"], INK, 1.1)
        a.ellipse(x - 3, y, 1.8, 2.2, pal["metal"])
    if level >= 3:  # banners at the corners of the long face
        for u in (-0.76, 0.62):
            hanging_banner(a, ("left", y1), u - 0.07, u + 0.07, h - 6, h - 30, pal["accent"], pal["metal"])
    elif level == 2:
        hanging_banner(a, ("right", x1), 0.02, 0.16, h - 6, h - 28, pal["accent"], pal["metal"])
    return a


def _hall_extent():
    """Every town hall picture of a material shares one canvas (the level-3 podium's)."""
    s = 0.98
    return [P(-s, -s, 0), P(s, -s, 0), P(s, s, 0), P(-s, s, 0), P(-0.3, -0.3, HALL_DECK[3] + 50), P(0.3, 0.3, HALL_DECK[3] + 50),
            (-112, 34), (112, 34)]


def _hall_porch(a, pal, wood, level, h):
    _, _, _, y1 = HALL_BODY
    px0, px1, py1 = -0.2, 0.2, y1 + 0.3
    ph, pr = h - 4, h + 22
    a.box(px0, px1, y1 - 0.1, py1, 0, ph, pal["t"], pal["l"], pal["r"])
    _hall_courses(a, pal, "left", py1, px0, px1, 0, ph, wood)
    _hall_courses(a, pal, "right", px1, y1, py1, 0, ph, wood)
    a.poly(_hall_face("left", py1, px0, px1, 0, ph), "none")
    # the gable over it, facing out (ridge along gy)
    pm = (px0 + px1) / 2
    gable = [P(px0 - 0.03, py1, ph), P(pm, py1, pr), P(px1 + 0.03, py1, ph)]
    a.poly(gable, pal["l"])
    a.poly([P(px1 + 0.04, py1 + 0.04, ph - 1), P(pm, py1 + 0.04, pr + 1), P(pm, y1 - 0.12, pr + 1), P(px1 + 0.04, y1 - 0.12, ph - 1)], pal["roof_r"])
    a.line([P(px0 - 0.04, py1 + 0.04, ph - 1), P(pm, py1 + 0.04, pr + 1), P(px1 + 0.04, py1 + 0.04, ph - 1)], pal["trim"], 3)
    cx, cy = P(pm, py1, ph + 11)  # the hall's clock in the gable: what tells it from other halls
    a.ellipse(cx, cy, 7, 7.5, pal["metal"], INK, 1.2)
    a.ellipse(cx, cy, 5, 5.5, "#efe6cf", INK, 0.8)
    for k in range(12):
        ang = math.pi * 2 * k / 12
        a.line([(cx + math.cos(ang) * 4.0, cy + math.sin(ang) * 4.4), (cx + math.cos(ang) * 4.8, cy + math.sin(ang) * 5.3)], INK, 0.7)
    a.line([(cx, cy), (cx, cy - 4.0)], INK, 1.1)
    a.line([(cx, cy), (cx + 2.6, cy + 1.2)], INK, 1.1)
    # the large front door: double leaves under a round arch, iron bands
    dw, dh = 0.13, 26
    pts = [P(pm - dw, py1, 0), P(pm + dw, py1, 0), P(pm + dw, py1, dh)]
    for k in range(1, 8):
        ang = math.pi * k / 8
        pts.append(P(pm + dw * math.cos(ang), py1, dh + 6 * math.sin(ang)))
    pts.append(P(pm - dw, py1, dh))
    a.poly(pts, pal["door"], INK, 1.4)
    a.line([P(pm, py1, 0), P(pm, py1, dh + 6)], INK, 1.2)
    for z in (7, 19):
        a.line([P(pm - dw, py1, z), P(pm + dw, py1, z)], IRON, 1.6)
    for u in (pm - 0.03, pm + 0.03):
        x, y = P(u, py1, 13)
        a.ellipse(x, y, 1.3, 1.3, pal["metal"])
    # steps
    a.box(pm - dw - 0.05, pm + dw + 0.05, py1, py1 + 0.08, 0, 3, pal["t"], pal["j"], pal["j"])
    if level >= 3:  # gilded arch
        a.line(pts[2:-1], pal["metal"], 1.6)


def _hall_podium(a, pal, ts, deck, level, roof_z):
    """The tower post: a low square podium built into the roof's ridge, its
    platform at `deck` with a parapet. It stands HALL_TOWER_BACK tiles back
    along the view axis from the 2x2's middle, so it is drawn centred but a
    little in the background; the game's post is the middle itself
    (TownHall.act_center). `roof_z(gy)`: the roof's height under it."""
    c = -HALL_TOWER_BACK
    lo, hi = c - ts, c + ts
    _, _, y0, y1 = HALL_BODY
    ym = (y0 + y1) / 2
    zf = roof_z(hi)
    # its two faces in front, their feet on the roof (the right one over the ridge)
    left = [P(lo, hi, roof_z(hi)), P(hi, hi, zf), P(hi, hi, deck), P(lo, hi, deck)]
    right = [P(hi, lo, roof_z(lo)), P(hi, ym, roof_z(ym)), P(hi, hi, zf), P(hi, hi, deck), P(hi, lo, deck)]
    a.poly(left, pal["l"], INK, 1.4)
    a.poly(right, pal["r"], INK, 1.4)
    for z in range(int(zf) + 9, deck - 2, 9):  # courses
        a.line([P(lo, hi, z), P(hi, hi, z)], pal["j"], 1.0, opacity=0.8)
    # the platform's slab, a little wider, and its parapet
    a.box(lo - 0.04, hi + 0.04, lo - 0.04, hi + 0.04, deck, deck + 4, pal["t"], pal["l"], pal["r"])
    _hall_merlons(a, pal, ts + 0.03, deck, False, level)
    # a pole with the village's pennon at the back
    bx, by = P(lo + 0.05, lo + 0.05, deck + 4)
    a.line([(bx, by), (bx, by - 36)], INK, 3)
    a.poly([(bx, by - 36), (bx + 18, by - 32), (bx + 12, by - 28), (bx + 18, by - 24), (bx, by - 22)], pal["accent"])
    if level >= 3:  # a gilded rim and a brazier at the back
        a.line([P(lo - 0.04, hi + 0.04, deck + 4), P(hi + 0.04, hi + 0.04, deck + 4), P(hi + 0.04, lo - 0.04, deck + 4)], pal["metal"], 2)
        bx, by = P(c + 0.12, c - 0.12, deck + 4)
        a.ellipse(bx, by - 14, 14, 10, pal["glow"], opacity=0.35)
        a.poly([(bx - 5, by - 5), (bx + 5, by - 5), (bx + 3, by), (bx - 3, by)], IRON, INK, 1)
        a.poly([(bx - 3.5, by - 5), (bx, by - 15), (bx + 3.5, by - 5)], pal["glow"], "#b8401e", 1)


def _hall_merlons(a, pal, s, z, front, level):
    k = 0.12
    c = -HALL_TOWER_BACK
    spots_back = [(-s, -s), (-k / 2, -s), (s - k, -s), (-s, -k / 2)]
    spots_front = [(-s, s - k), (-k / 2, s - k), (s - k, s - k), (s - k, -k / 2), (s - k, -s)]
    for gx, gy in (spots_front if front else spots_back):
        gx, gy = gx + c, gy + c
        a.box(gx, gx + k, gy, gy + k, z + 4, z + 10, pal["t"], pal["l"], pal["r"])
        if front and level >= 3:
            a.line([P(gx, gy + k, z + 10), P(gx + k, gy + k, z + 10), P(gx + k, gy, z + 10)], pal["metal"], 1.4)


def town_hall_ruin(material):
    """A devastated town hall: the walls broken down to jagged stubs, the roof
    fallen in (charred beams, rubble), the porch's arch still standing."""
    pal = HALL_PALETTES[material]
    rng = random.Random(5200 + len(material))
    a = Art()
    x0, x1, y0, y1 = HALL_BODY
    s = 0.98
    a.poly([P(-s, -s), P(s, -s), P(s, s), P(-s, s)], "#2d2a26", INK, 1.0, opacity=0.55)
    a.box(x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.04, 0, 6, pal["t"], pal["j"], pal["j"])
    # the back walls, broken
    for (u0, u1, hh) in [(x0, -0.4, 30), (-0.4, 0.1, 14), (0.1, x1, 24)]:
        a.box(u0, u1, y0, y0 + 0.1, 6, hh, pal["t"], pal["l"], pal["r"])
    for (u0, u1, hh) in [(y0 + 0.1, -0.2, 26), (-0.2, y1, 10)]:
        a.box(x0, x0 + 0.1, u0, u1, 6, hh, pal["t"], pal["l"], pal["r"])
    # charred beams fallen across the floor
    for (ga, gb, za, zb) in [((-0.7, -0.6), (0.3, 0.2), 28, 6), ((-0.2, -0.7), (0.5, 0.3), 22, 8), ((-0.6, 0.2), (0.2, -0.4), 8, 18)]:
        p0, p1 = P(ga[0], ga[1], za), P(gb[0], gb[1], zb)
        a.line([p0, p1], INK, 6)
        a.line([p0, p1], "#2a1e15", 4)
        a.ellipse(p1[0], p1[1], 2.6, 1.8, "#c04a1e", opacity=0.8)
    for _ in range(18):
        gx, gy = rng.uniform(x0 + 0.1, x1 - 0.1), rng.uniform(y0 + 0.1, y1)
        x, y = P(gx, gy, 6)
        w = rng.uniform(3, 7)
        a.poly([(x - w, y), (x - w * 0.4, y - w * 0.7), (x + w * 0.6, y - w * 0.6), (x + w, y)], rng.choice([pal["t"], pal["l"], pal["r"]]), INK, 1)
    # the front walls, low stubs, and the porch arch still standing
    for (u0, u1, hh) in [(x0, -0.5, 18), (-0.5, -0.22, 8), (0.22, 0.45, 12), (0.45, x1, 6)]:
        a.box(u0, u1, y1 - 0.1, y1, 6, hh, pal["t"], pal["l"], pal["r"])
    a.box(x1 - 0.1, x1, y0 + 0.1, -0.1, 6, 20, pal["t"], pal["l"], pal["r"])
    a.box(x1 - 0.1, x1, -0.1, y1 - 0.1, 6, 9, pal["t"], pal["l"], pal["r"])
    py1 = y1 + 0.3
    for u in (-0.2, 0.13):
        a.box(u, u + 0.07, y1, py1, 0, 30, pal["t"], pal["l"], pal["r"])
    a.poly([P(-0.2, py1, 30), P(0.2, py1, 30), P(0.2, py1, 36), P(-0.2, py1, 36)], pal["l"], INK, 1.2)
    for _ in range(3):
        x, y = P(rng.uniform(-0.5, 0.4), rng.uniform(-0.5, 0.2), 30)
        a.ellipse(x, y - 10, 7, 10, "#8a8580", opacity=0.25)  # smoke
    return a


def town_halls():
    """Every material's town hall, its three levels on one canvas (so the
    picture doesn't jump on an upgrade), the tower post's front merlons, and
    the ruin."""
    for mat in HALL_PALETTES:
        prefix = Config_piece_prefix(mat)
        for lvl in (1, 2, 3):
            name = prefix + ("town_hall" if lvl == 1 else "town_hall_%d" % lvl)
            th = town_hall(mat, lvl)
            th._track(_hall_extent())
            extra = {"roof": HALL_RIDGE if lvl == 1 else HALL_DECK[lvl] + 30}
            if lvl >= 2:
                # (the unit stands on the deck, which is HALL_TOWER_BACK back: that much higher on screen)
                extra["platform"] = HALL_DECK[lvl] + 6 + 2 * HALL_TOWER_BACK * TH
            th.save(name, extra=extra)
            if lvl >= 2:
                fr = town_hall(mat, lvl, front=True)
                fr.pts = th.pts[:]
                fr.save(prefix + "town_hall_front_%d" % lvl)
        ru = town_hall_ruin(mat)
        ru._track(_hall_extent())
        ru.save(prefix + "town_hall_ruin")


def Config_piece_prefix(mat):
    """Config.PIECE_MATERIALS[mat]["art"]: stone has no prefix."""
    return "" if mat == "stone" else {"basalt": "basalt_", "sandstone": "sandstone_", "limestone": "limestone_",
                                       "granite": "granite_", "ice": "ice_", "wood": "wood_"}[mat]
