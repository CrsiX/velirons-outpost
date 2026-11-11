"""The campaign map on the title screen and its pins, with their helpers (noise, chaikin,
...)."""

import math
import os
import random

from .core import Art


MAP_INK = "#4a3220"
MAP_LAYOUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "campaign_map.json")


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
