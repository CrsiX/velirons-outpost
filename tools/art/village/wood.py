"""Village pieces in wood."""

import random

from ..core import Art, CRIMSON, CRIMSON_D, diamond, GLOW, INK, IRON, IRON_L, P, ROPE, ROPE_D


# Wood (Config.PIECE_MATERIALS): an improvised palisade for forward outposts:
# sharpened logs of uneven height, rope lashings, patched rails; level 2 a
# second rank behind with iron bands, level 3 a heavy stockade with hides over
# the top, stakes in front and a lantern. Walls run along gx like the stone ones.

LOG, LOG_L, LOG_D, LOG_CUT = "#6b4a2c", "#86603a", "#4a321d", "#c49a62"
HIDE, HIDE_D = "#9a7350", "#6e4f35"


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
