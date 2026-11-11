"""The map's special sites: the camp, the unlock sites (stone circle, mage tower, chapel),
the ruined watchtower and the miner's mine."""

import math
import random

from .core import (
    Art, BONE, _bone, diamond, fmt, GLOW, _glow, GOLD, GOLD_D, INK, P, rand_in_diamond, _rock,
    STONE_L, STONE_R, STONE_T, _tuft, WOOD, WOOD_D, WOOD_L,
)


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
