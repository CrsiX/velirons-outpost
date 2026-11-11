"""Village pieces in ice."""

import math
import random

from ..core import (
    Art, diamond, GLOW, GOLD, hanging_banner, INK, IRON, IRON_L, _merlon_spots, _opening, P, _ring,
)


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
