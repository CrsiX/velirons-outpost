#!/usr/bin/env python3
"""Title-screen backdrop candidates for Veliron's Outpost.

Every design is a 2560 x 1920 SVG, larger than any screen it covers: a
landscape screen sees the full width and about 1440 px of the height, a
portrait one about 1080 px of the width and the full height. So the view can
drift slowly over the picture, either way. The subject (the outpost) sits in
the middle, inside both views.

    python3 tools/title_designs.py <out_dir>          # all designs
    python3 tools/title_designs.py <out_dir> 3 7      # just these
"""

import math
import os
import random
import sys

W, H = 2560, 1920
CX = W / 2
INK = "#15110d"
CRIMSON = "#8c1c2b"


class Svg:
    """One picture: defs and body, with unique ids for gradients."""

    def __init__(self):
        self.defs = []
        self.body = []
        self._n = 0

    def uid(self, p="g"):
        self._n += 1
        return "%s%d" % (p, self._n)

    def add(self, s):
        self.body.append(s)

    def linear(self, stops, x2=0, y2=1, x1=0, y1=0):
        gid = self.uid("lg")
        st = "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (o, c, a) for o, c, a in _stops(stops))
        self.defs.append('<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>' % (gid, x1, y1, x2, y2, st))
        return "url(#%s)" % gid

    def radial(self, stops, cx=0.5, cy=0.5, r=0.5):
        gid = self.uid("rg")
        st = "".join('<stop offset="%s" stop-color="%s" stop-opacity="%s"/>' % (o, c, a) for o, c, a in _stops(stops))
        self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s">%s</radialGradient>' % (gid, cx, cy, r, st))
        return "url(#%s)" % gid

    def blur(self, sd):
        fid = self.uid("bl")
        self.defs.append('<filter id="%s" x="-50%%" y="-50%%" width="200%%" height="200%%"><feGaussianBlur stdDeviation="%s"/></filter>' % (fid, sd))
        return "url(#%s)" % fid

    def svg(self):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n<defs>\n%s\n</defs>\n%s\n</svg>\n'
                % (W, H, W, H, "\n".join(self.defs), "\n".join(self.body)))


def _stops(stops):
    out = []
    for s in stops:
        if len(s) == 2:
            out.append((s[0], s[1], 1))
        else:
            out.append(s)
    return out


def f(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def pts(p):
    return " ".join("%s,%s" % (f(x), f(y)) for x, y in p)


# ------------------------------------------------------------------ noise

def noise(seed, octaves=5, base=6, persistence=0.5):
    """A smooth 1D noise over 0..W: returns a function x -> 0..1."""
    rng = random.Random(seed)
    layers = []
    amp, total = 1.0, 0.0
    for k in range(octaves):
        n = base * (2 ** k) + 2
        layers.append((amp, [rng.random() for _ in range(n + 1)], n))
        total += amp
        amp *= persistence

    def at(x):
        t = x / W
        v = 0.0
        for a, vals, n in layers:
            u = t * n
            i = int(math.floor(u)) % n
            fr = u - math.floor(u)
            fr = (1 - math.cos(fr * math.pi)) / 2
            v += a * (vals[i] * (1 - fr) + vals[i + 1] * fr)
        return v / total
    return at


def ridge_line(seed, base, amp, sharp=False, octaves=5, freq=4, step=12, x0=-40, x1=W + 40):
    n = noise(seed, octaves, freq)
    out = []
    x = x0
    while x <= x1:
        v = n(x)
        if sharp:
            v = 1 - abs(2 * v - 1)
            v = v ** 1.6
        out.append((x, base - amp * v))
        x += step
    return out


def ridge(s, line, fill, bottom=H + 10):
    p = [(line[0][0], bottom)] + line + [(line[-1][0], bottom)]
    s.add('<polygon points="%s" fill="%s"/>' % (pts(p), fill))


def snowcaps(s, line, thr, color, seed, op=0.9):
    """Snow on every stretch of `line` above y = thr."""
    rng = random.Random(seed)
    run = []
    for (x, y) in line + [(line[-1][0] + 1, thr + 1)]:
        if y < thr:
            run.append((x, y))
        elif run:
            if len(run) > 2:
                bottom = [(x2, min(thr + rng.uniform(-10, 40), y2 + 120)) for x2, y2 in reversed(run)]
                s.add('<polygon points="%s" fill="%s" opacity="%s"/>' % (pts(run + bottom), color, op))
            run = []


def mountain_light(s, line, color, op, seed, side=1):
    """Lit faces: from each peak, a lighter wedge down one side."""
    for i in range(1, len(line) - 1):
        x, y = line[i]
        if y < line[i - 1][1] and y <= line[i + 1][1]:
            j = i
            while 0 < j < len(line) - 1 and line[j + side][1] > line[j][1]:
                j += side
            if abs(j - i) < 3:
                continue
            xe, ye = line[j]
            mid = [line[k] for k in (range(i, j + 1) if side > 0 else range(j, i + 1))]
            if side > 0:
                poly = mid + [(xe, ye + 80), (x + (xe - x) * 0.25, ye + 200)]
            else:
                poly = mid + [(x - (x - xe) * 0.25, ye + 200), (xe, ye + 80)]
            s.add('<polygon points="%s" fill="%s" opacity="%s"/>' % (pts(poly), color, op))


# ------------------------------------------------------------------ sky bits

def sky(s, stops):
    s.add('<rect width="%d" height="%d" fill="%s"/>' % (W, H, s.linear(stops)))


def stars(s, seed, n, ymax, color="#fff8e0", rmax=2.4, twinkle=0.08):
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.uniform(0, W), rng.uniform(0, ymax) ** 1.0
        y = ymax * (rng.random() ** 1.4)
        r = rng.uniform(0.6, rmax)
        s.add('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="%s"/>' % (f(x), f(y), f(r), color, f(rng.uniform(0.25, 0.95))))
        if rng.random() < twinkle:
            L = r * 6
            s.add('<path d="M%s,%s h%s M%s,%s v%s" stroke="%s" stroke-width="1.2" opacity="0.6"/>' % (f(x - L), f(y), f(2 * L), f(x), f(y - L), f(2 * L), color))


def glow(s, x, y, r, color, op=0.6, ry=None):
    g = s.radial([(0, color, op), (0.45, color, op * 0.35), (1, color, 0)])
    s.add('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>' % (f(x), f(y), f(r), f(ry or r), g))


def moon(s, x, y, r, color="#f3e8c4", shade="#d9cb9c", halo="#f3e8c4", halo_r=4.5, halo_op=0.35, craters=True):
    glow(s, x, y, r * halo_r, halo, halo_op)
    glow(s, x, y, r * 1.8, halo, halo_op * 1.2)
    s.add('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (f(x), f(y), f(r), color))
    if craters:
        rng = random.Random(int(x + y))
        for _ in range(6):
            a, d = rng.uniform(0, 6.28), rng.uniform(0, r * 0.7)
            s.add('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="0.55"/>' % (f(x + math.cos(a) * d), f(y + math.sin(a) * d), f(rng.uniform(r * 0.06, r * 0.18)), shade))


def clouds(s, seed, n, y0, y1, color, op=0.5, scale=1.0, x0=-200, x1=W + 200, blur=None):
    rng = random.Random(seed)
    flt = (' filter="%s"' % s.blur(blur)) if blur else ""
    for _ in range(n):
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        w = rng.uniform(260, 620) * scale
        parts = []
        for k in range(rng.randint(4, 7)):
            px = cx + rng.uniform(-w / 2, w / 2)
            rx = rng.uniform(w * 0.18, w * 0.32)
            parts.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s"/>' % (f(px), f(cy - rng.uniform(0, rx * 0.4)), f(rx), f(rx * rng.uniform(0.45, 0.7))))
        s.add('<g fill="%s" opacity="%s"%s>%s</g>' % (color, f(op), flt, "".join(parts)))


def mist(s, y, h, color, op):
    g = s.linear([(0, color, 0), (0.5, color, op), (1, color, 0)])
    s.add('<rect x="0" y="%s" width="%d" height="%s" fill="%s"/>' % (f(y - h / 2), W, f(h), g))


def vignette(s, op=0.7, color="#000"):
    g = s.radial([(0.55, color, 0), (1, color, op)], cx=0.5, cy=0.5, r=0.72)
    s.add('<rect width="%d" height="%d" fill="%s"/>' % (W, H, g))


def birds(s, seed, n, x0, x1, y0, y1, color, size=14):
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        k = size * rng.uniform(0.6, 1.3)
        s.add('<path d="M%s,%s q%s,%s %s,%s q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"/>'
              % (f(x - k), f(y), f(k * 0.5), f(-k * 0.6), f(k), f(k * 0.3), f(k * 0.5), f(-k * 0.9), f(k), f(-k * 0.3), color, f(k * 0.22)))


# ------------------------------------------------------------------ trees

def pine(s, x, base, h, color, light=None):
    w = h * 0.34
    tiers = 5
    d = []
    for k in range(tiers):
        t = k / tiers
        yb = base - h * 0.12 - h * 0.8 * t
        ww = w * (1 - t * 0.75)
        top = yb - h * 0.3
        d.append("M%s,%s L%s,%s L%s,%s L%s,%s Z" % (f(x - ww), f(yb), f(x - ww * 0.15), f(yb - h * 0.04), f(x), f(top), f(x + ww), f(yb)))
    s.add('<path d="%s" fill="%s"/>' % (" ".join(d), color))
    s.add('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (f(x - h * 0.025), f(base - h * 0.14), f(h * 0.05), f(h * 0.14), color))
    if light:
        # a lit edge on the left side of every tier
        for k in range(tiers):
            t = k / tiers
            yb = base - h * 0.12 - h * 0.8 * t
            ww = w * (1 - t * 0.75)
            top = yb - h * 0.3
            s.add('<path d="M%s,%s L%s,%s L%s,%s Z" fill="%s" opacity="0.35"/>' % (f(x - ww), f(yb), f(x), f(top), f(x - ww * 0.55), f(yb - h * 0.02), light))


def forest(s, seed, n, x0, x1, base, hmin, hmax, color, light=None, gap=None, jitter=30):
    rng = random.Random(seed)
    trees = []
    for _ in range(n):
        x = rng.uniform(x0, x1)
        if gap and gap[0] < x < gap[1]:
            continue
        trees.append((x, base + rng.uniform(-jitter, jitter), rng.uniform(hmin, hmax)))
    for x, b, h in sorted(trees, key=lambda t: t[1]):
        pine(s, x, b, h, color, light)


def round_tree(s, x, base, h, leaf, leaf_d, trunk, rng, light=None):
    s.add('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (f(x - h * 0.04), f(base - h * 0.45), f(h * 0.08), f(h * 0.45), trunk))
    r = h * 0.32
    cy = base - h * 0.62
    blobs = [(x + rng.uniform(-r * 0.6, r * 0.6), cy + rng.uniform(-r * 0.5, r * 0.4), r * rng.uniform(0.55, 0.85)) for _ in range(5)]
    for bx, by, br in blobs:
        s.add('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (f(bx), f(by + br * 0.15), f(br), leaf_d))
    for bx, by, br in blobs:
        s.add('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (f(bx - br * 0.08), f(by), f(br * 0.88), leaf))
    if light:
        for bx, by, br in blobs[:3]:
            s.add('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="0.45"/>' % (f(bx - br * 0.3), f(by - br * 0.3), f(br * 0.4), light))


def grove(s, seed, n, x0, x1, base, hmin, hmax, leaves, trunk, light=None, gap=None, jitter=30):
    rng = random.Random(seed)
    trees = []
    for _ in range(n):
        x = rng.uniform(x0, x1)
        if gap and gap[0] < x < gap[1]:
            continue
        trees.append((x, base + rng.uniform(-jitter, jitter), rng.uniform(hmin, hmax), rng.choice(leaves)))
    for x, b, h, (lf, ld) in sorted(trees, key=lambda t: t[1]):
        round_tree(s, x, b, h, lf, ld, trunk, rng, light)


def dead_tree(s, x, base, h, color, rng, sw=None):
    sw = sw or h * 0.05

    def branch(x0, y0, ang, length, width, depth):
        x1, y1 = x0 + math.cos(ang) * length, y0 + math.sin(ang) * length
        s.add('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % (f(x0), f(y0), f(x1), f(y1), color, f(width)))
        if depth > 0:
            for da in (-rng.uniform(0.3, 0.7), rng.uniform(0.3, 0.7)):
                branch(x1, y1, ang + da, length * rng.uniform(0.55, 0.75), width * 0.62, depth - 1)
    branch(x, base, -math.pi / 2 + rng.uniform(-0.1, 0.1), h * 0.42, sw, 4)


# ------------------------------------------------------------------ the outpost

def castle(s, x, y, sc, pal, lit=True, flags=True, wglow=None):
    """The walled outpost, base centre at (x, y), about 640 * sc wide.
    pal: light, dark (shaded faces), roof, roof_dark, window, line (outlines)."""
    L, D, R, RD, WIN = pal["light"], pal["dark"], pal["roof"], pal["roof_dark"], pal["window"]
    line = pal.get("line")
    st = (' stroke="%s" stroke-width="%s" stroke-linejoin="round"' % (line, f(3 / max(sc, 0.2)))) if line else ""
    g = []

    def block(x0, x1, y0, y1, shade=0.3):
        g.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"%s/>' % (f(x0), f(y0), f(x1 - x0), f(y1 - y0), L, st))
        sx = x1 - (x1 - x0) * shade
        g.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (f(sx), f(y0), f(x1 - sx), f(y1 - y0), D))

    def crenels(x0, x1, y0, size=22):
        k = x0
        while k + size <= x1 + 0.1:
            g.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"%s/>' % (f(k), f(y0 - size * 0.9), f(size * 0.62), f(size * 0.9), L, st))
            k += size

    def roof(cx, w, y0, h):
        g.append('<polygon points="%s" fill="%s"%s/>' % (pts([(cx - w / 2 - 10, y0), (cx, y0 - h), (cx + w / 2 + 10, y0)]), R, st))
        g.append('<polygon points="%s" fill="%s"/>' % (pts([(cx, y0 - h), (cx + w / 2 + 10, y0), (cx + w * 0.12, y0)]), RD))

    def flag(px, py, h=90, flip=1):
        g.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="4"/>' % (f(px), f(py), f(px), f(py - h), line or D))
        g.append('<path d="M%s,%s q%s,%s %s,%s l%s,%s q%s,%s %s,%s Z" fill="%s"/>' % (
            f(px), f(py - h), f(30 * flip), f(-10), f(70 * flip), f(6), f(-14 * flip), f(18), f(14 * flip), f(14), f(-56 * flip), f(4), pal.get("flag", CRIMSON)))

    win = []

    def window(cx, cy, w=14, h=22):
        win.append((cx, cy))
        g.append('<path d="M%s,%s v%s a%s,%s 0 0 1 %s,0 v%s Z" fill="%s"/>' % (f(cx - w / 2), f(cy + h / 2), f(-h + w / 2), f(w / 2), f(w / 2), f(w), f(h - w / 2), WIN if lit else D))

    # huts' roofs behind the wall
    for hx, hy, hw in [(-150, -150, 90), (-40, -160, 80), (60, -150, 100), (170, -145, 80)]:
        g.append('<polygon points="%s" fill="%s"%s/>' % (pts([(hx - hw / 2, hy), (hx, hy - hw * 0.55), (hx + hw / 2, hy)]), pal.get("hut", RD), st))
    # keep
    block(-80, 80, -380, -140)
    crenels(-80, 80, -380)
    for wy in (-320, -250):
        for wx in (-40, 30):
            window(wx, wy)
    # tall tower on the keep
    block(-34, 34, -520, -380, 0.35)
    roof(0, 68, -520, 120)
    window(0, -460, 12, 20)
    if flags:
        flag(0, -640, 70)
    # curtain wall
    block(-270, 270, -170, 0, 0.12)
    crenels(-270, 270, -170)
    # gate
    g.append('<path d="M-38,0 v-70 a38,38 0 0 1 76,0 v70 Z" fill="%s"/>' % pal.get("gate", "#0b0806"))
    if lit:
        g.append('<path d="M-30,0 v-66 a30,30 0 0 1 60,0 v66 Z" fill="%s" opacity="0.35"/>' % WIN)
    # corner towers
    for tx, fl in ((-300, -1), (300, 1)):
        block(tx - 48, tx + 48, -330, 10, 0.32)
        roof(tx, 96, -330, 150)
        window(tx - 4, -270)
        window(tx - 4, -170)
        window(tx - 4, -80)
        if flags:
            flag(tx, -480, 70, fl)
    # wall windows
    for wx in (-200, -130, 120, 200):
        window(wx, -95, 12, 18)
    out = '<g transform="translate(%s,%s) scale(%s)">' % (f(x), f(y), f(sc))
    if lit and wglow:
        for cx, cy in win:
            gg = s.radial([(0, wglow, 0.55), (1, wglow, 0)])
            out += '<circle cx="%s" cy="%s" r="46" fill="%s"/>' % (f(cx), f(cy), gg)
    s.add(out + "".join(g) + "</g>")


def hill(s, x, y, w, h, fill, top=None):
    """A mound under the outpost: base (x - w/2 .. x + w/2, y + h), top at y."""
    s.add('<path d="M%s,%s C%s,%s %s,%s %s,%s C%s,%s %s,%s %s,%s Z" fill="%s"/>' % (
        f(x - w / 2), f(y + h), f(x - w * 0.32), f(y + h * 0.15), f(x - w * 0.2), f(y), f(x), f(y),
        f(x + w * 0.2), f(y), f(x + w * 0.32), f(y + h * 0.15), f(x + w / 2), f(y + h), fill))
    if top:
        # a soft light on the hilltop, from above
        glow(s, x, y + h * 0.12, w * 0.32, top, 0.18, h * 0.16)
    if False:
        s.add('<path d="M%s,%s C%s,%s %s,%s %s,%s C%s,%s %s,%s %s,%s" fill="none" stroke="%s" stroke-width="10" opacity="0.5"/>' % (
            f(x - w * 0.42), f(y + h * 0.55), f(x - w * 0.3), f(y + h * 0.12), f(x - w * 0.2), f(y), f(x), f(y),
            f(x + w * 0.2), f(y), f(x + w * 0.3), f(y + h * 0.12), f(x + w * 0.42), f(y + h * 0.55), top))


def road(s, p, width, color, op=1.0):
    d = "M%s,%s " % (f(p[0][0]), f(p[0][1]))
    for i in range(1, len(p) - 1, 2):
        d += "Q%s,%s %s,%s " % (f(p[i][0]), f(p[i][1]), f(p[i + 1][0]), f(p[i + 1][1]))
    s.add('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" opacity="%s"/>' % (d, color, f(width), f(op)))


def fireflies(s, seed, n, x0, x1, y0, y1, color):
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(2, 4.5)
        glow(s, x, y, r * 6, color, 0.5)
        s.add('<circle cx="%s" cy="%s" r="%s" fill="#fffbe0"/>' % (f(x), f(y), f(r * 0.6)))


# ------------------------------------------------------------------ monsters (silhouettes)

def goblin_sil(s, x, y, h, color, torch=None):
    k = h / 100.0
    s.add('<g transform="translate(%s,%s) scale(%s)" fill="%s">'
          '<path d="M-14,0 L-10,-38 L-18,-40 L-14,-70 Q0,-80 14,-70 L18,-40 L10,-38 L14,0 L4,0 L0,-30 L-4,0 Z"/>'
          '<circle cx="0" cy="-84" r="14"/><path d="M-12,-88 L-34,-96 L-12,-80 Z M12,-88 L34,-96 L12,-80 Z"/>'
          '<path d="M16,-62 L34,-100" stroke="%s" stroke-width="6"/></g>' % (f(x), f(y), f(k), color, color))
    if torch:
        glow(s, x + 34 * k, y - 104 * k, 70 * k, torch, 0.7)
        s.add('<circle cx="%s" cy="%s" r="%s" fill="#ffe08a"/>' % (f(x + 34 * k), f(y - 104 * k), f(6 * k)))
    s.add('<circle cx="%s" cy="%s" r="%s" fill="#ff3b2a"/><circle cx="%s" cy="%s" r="%s" fill="#ff3b2a"/>' % (
        f(x - 5 * k), f(y - 86 * k), f(2.5 * k), f(x + 5 * k), f(y - 86 * k), f(2.5 * k)))


def ork_sil(s, x, y, h, color):
    k = h / 100.0
    s.add('<g transform="translate(%s,%s) scale(%s)" fill="%s">'
          '<path d="M-26,0 L-22,-40 L-34,-44 L-30,-76 Q0,-92 30,-76 L34,-44 L22,-40 L26,0 L8,0 L0,-30 L-8,0 Z"/>'
          '<circle cx="0" cy="-90" r="17"/><path d="M-30,-60 L-56,-20 L-48,-16 L-24,-52 Z"/>'
          '<path d="M30,-66 L48,-118 L60,-112 L40,-62 Z"/></g>' % (f(x), f(y), f(k), color))
    s.add('<circle cx="%s" cy="%s" r="%s" fill="#ff5a2a"/><circle cx="%s" cy="%s" r="%s" fill="#ff5a2a"/>' % (
        f(x - 6 * k), f(y - 92 * k), f(3 * k), f(x + 6 * k), f(y - 92 * k), f(3 * k)))


def slime_sil(s, x, y, r, color, eye="#ffffff"):
    s.add('<path d="M%s,%s C%s,%s %s,%s %s,%s C%s,%s %s,%s %s,%s Q%s,%s %s,%s Z" fill="%s"/>' % (
        f(x - r), f(y), f(x - r), f(y - r * 0.9), f(x - r * 0.6), f(y - r * 1.35), f(x), f(y - r * 1.35),
        f(x + r * 0.6), f(y - r * 1.35), f(x + r), f(y - r * 0.9), f(x + r), f(y), f(x), f(y + r * 0.2), f(x - r), f(y), color))
    for ex in (x - r * 0.2, x + r * 0.25):
        s.add('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (f(ex), f(y - r * 0.7), f(r * 0.1), eye))


# ================================================================== the designs

def d01_moonrise():
    """Moonrise: a big moon right behind the outpost, blue ridges, mist and fireflies."""
    s = Svg()
    sky(s, [(0, "#060b1c"), (0.45, "#14244a"), (0.75, "#2e4a74"), (1, "#3b5878")])
    stars(s, 1, 420, 1000)
    moon(s, CX + 40, 690, 210, halo_r=4.0, halo_op=0.3)
    m1 = ridge_line(11, 1080, 380, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#3c5a86"), (1, "#1d2f52")]))
    mountain_light(s, m1, "#7d9cc8", 0.25, 1, side=-1)
    snowcaps(s, m1, 820, "#c8d8f0", 2, 0.75)
    mist(s, 1080, 260, "#9ab4d8", 0.35)
    m2 = ridge_line(12, 1220, 220, freq=4)
    ridge(s, m2, s.linear([(0, "#20365a"), (1, "#122039")]))
    mist(s, 1220, 200, "#8aa4c8", 0.3)
    hill(s, CX, 1130, 1500, 500, "#0f1b2e", "#3d5a80")
    castle(s, CX, 1190, 0.95, {"light": "#24344c", "dark": "#162234", "roof": "#3a2032", "roof_dark": "#2a1624", "window": "#ffcf7a", "hut": "#1e1a24", "flag": "#b02a3c"}, wglow="#ffb44a")
    forest(s, 13, 70, -60, W + 60, 1420, 150, 260, "#0c1626", gap=(CX - 520, CX + 520))
    mist(s, 1450, 220, "#7d98bf", 0.25)
    forest(s, 14, 40, -100, W + 100, 1700, 300, 480, "#070d18", gap=(CX - 700, CX + 700), jitter=60)
    ridge(s, ridge_line(15, 1820, 90, freq=3), "#05090f")
    fireflies(s, 16, 40, 200, W - 200, 1350, 1800, "#ffe58a")
    vignette(s, 0.65, "#02040a")
    return s


def d02_golden_hour():
    """Golden hour: a warm sunset behind the hills, the outpost glowing, birds going home."""
    s = Svg()
    sky(s, [(0, "#2a2a5c"), (0.3, "#7a4a78"), (0.52, "#e0806a"), (0.66, "#f7b56a"), (0.75, "#ffd890"), (1, "#ffe2a8")])
    glow(s, CX + 520, 1030, 900, "#ffd27a", 0.55)
    s.add('<circle cx="%s" cy="1030" r="150" fill="#fff0c0"/>' % f(CX + 520))
    clouds(s, 21, 14, 280, 760, "#f6a37a", 0.55, 1.2)
    clouds(s, 22, 10, 200, 600, "#c06a80", 0.45, 1.4)
    m1 = ridge_line(23, 1150, 320, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#b86a72"), (1, "#8a4f66")]))
    m2 = ridge_line(24, 1260, 180, freq=4)
    ridge(s, m2, s.linear([(0, "#7a4660"), (1, "#5a3550")]))
    mist(s, 1250, 200, "#ffc89a", 0.35)
    hill(s, CX - 60, 1180, 1600, 480, "#4a3a3a", "#ffb070")
    castle(s, CX - 60, 1240, 0.95, {"light": "#8a6458", "dark": "#5a4048", "roof": "#a8343a", "roof_dark": "#7a2430", "window": "#ffe6a0", "hut": "#6a3a34", "line": "#3a2228", "flag": "#c0303c"}, wglow="#ffd080")
    grove(s, 25, 50, -60, W + 60, 1460, 160, 260, [("#6a4a3a", "#4a3430"), ("#7a5a3a", "#55402e")], "#3a2a24", light="#ffb070", gap=(CX - 640, CX + 520))
    ridge(s, ridge_line(26, 1560, 120, freq=3), s.linear([(0, "#4a3438"), (1, "#2a1e24")]))
    grove(s, 27, 24, -100, W + 100, 1800, 300, 460, [("#3a2a2a", "#2a1e20")], "#20161a", gap=(CX - 800, CX + 700), jitter=50)
    birds(s, 28, 14, CX + 100, CX + 900, 600, 900, "#4a2a3a", 18)
    vignette(s, 0.45, "#2a1020")
    return s


def d03_horde():
    """The horde comes: a red night, torches snaking up the road, monsters on the ridge in front."""
    s = Svg()
    sky(s, [(0, "#12060a"), (0.45, "#3a0e14"), (0.72, "#8a2a1a"), (1, "#c8502a")])
    moon(s, CX - 620, 520, 120, color="#ffb08a", shade="#e08060", halo="#ff6a4a", halo_r=5, halo_op=0.3)
    clouds(s, 31, 12, 300, 800, "#5a1a1e", 0.6, 1.4)
    m1 = ridge_line(32, 1120, 300, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#4a1418"), (1, "#2a0a0e")]))
    glow(s, CX, 1150, 1400, "#ff7a3a", 0.25, 300)
    m2 = ridge_line(33, 1240, 160, freq=4)
    ridge(s, m2, "#1e080c")
    hill(s, CX + 160, 1150, 1400, 520, "#14070a", "#ff6a3a")
    castle(s, CX + 160, 1210, 0.9, {"light": "#2a1418", "dark": "#1a0a0e", "roof": "#3a1014", "roof_dark": "#28080c", "window": "#ffd070", "hut": "#22100f", "flag": "#d0303a"}, wglow="#ffa040")
    # the road and the torches marching on it
    path = [(-100, 1900), (300, 1700), (700, 1560), (1000, 1480), (1300, 1420), (1380, 1330), (CX + 160, 1230)]
    road(s, path, 60, "#2a1010")
    rng = random.Random(34)
    for t in range(46):
        u = t / 46.0
        i = min(int(u * (len(path) - 1)), len(path) - 2)
        fr = u * (len(path) - 1) - i
        x = path[i][0] * (1 - fr) + path[i + 1][0] * fr + rng.uniform(-24, 24)
        y = path[i][1] * (1 - fr) + path[i + 1][1] * fr + rng.uniform(-14, 14)
        if y < 1300:
            break
        glow(s, x, y - 20, 34, "#ffa040", 0.8)
        s.add('<circle cx="%s" cy="%s" r="4" fill="#ffe8a0"/>' % (f(x), f(y - 20)))
    ridge(s, ridge_line(35, 1620, 110, freq=3), "#0c0406")
    # the foreground ridge with monster silhouettes
    fg = ridge_line(36, 1800, 120, freq=2)
    ridge(s, fg, "#050203")
    glow(s, 520, 1700, 520, "#ff5a2a", 0.35, 200)
    glow(s, 2250, 1700, 520, "#ff5a2a", 0.35, 200)
    for x, kind, h in [(300, "g", 260), (520, "o", 380), (720, "g", 240), (1960, "g", 270), (2180, "o", 400), (2360, "s", 120), (2480, "g", 250)]:
        y = min(p[1] for p in fg if abs(p[0] - x) < 14) + 10
        if kind == "g":
            goblin_sil(s, x, y, h, "#050203", torch="#ff9a3a")
        elif kind == "o":
            ork_sil(s, x, y, h, "#050203")
        else:
            slime_sil(s, x, y, h, "#050203", eye="#ff6a4a")
    vignette(s, 0.7, "#0a0204")
    return s


def d04_misty_dawn():
    """Misty dawn: pastel pink and lilac, the outpost on a crag above a sea of fog."""
    s = Svg()
    sky(s, [(0, "#8aa0d0"), (0.4, "#c8b4d8"), (0.62, "#f4c4c4"), (0.8, "#ffe0c8"), (1, "#fff0dc")])
    glow(s, CX - 500, 1000, 800, "#fff2d0", 0.6)
    clouds(s, 41, 12, 250, 700, "#ffffff", 0.35, 1.3, blur=12)
    m1 = ridge_line(42, 1050, 330, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#a898c4"), (1, "#c8b4d0")]))
    mist(s, 1060, 300, "#fff2ea", 0.7)
    m2 = ridge_line(43, 1180, 200, sharp=True, freq=5)
    ridge(s, m2, s.linear([(0, "#8a7aa8"), (1, "#b8a8c8")]))
    mist(s, 1200, 260, "#fff0ea", 0.75)
    # the crag
    s.add('<path d="M%s,1900 L%s,1260 L%s,1150 L%s,1120 L%s,1140 L%s,1240 L%s,1900 Z" fill="%s"/>' % (
        f(CX - 520), f(CX - 400), f(CX - 300), f(CX), f(CX + 320), f(CX + 420), f(CX + 560), s.linear([(0, "#6a5a7e"), (1, "#3e3452")])))
    s.add('<path d="M%s,1150 L%s,1120 L%s,1140 L%s,1240 L%s,1500 Z" fill="#8a7aa0" opacity="0.5"/>' % (f(CX - 300), f(CX), f(CX + 320), f(CX + 420), f(CX + 200)))
    castle(s, CX, 1150, 0.9, {"light": "#e8d8e0", "dark": "#b8a4bc", "roof": "#6a7ab8", "roof_dark": "#4e5a94", "window": "#ffd890", "hut": "#a48aa8", "line": "#5a4a6a", "flag": "#d04a5a"}, wglow="#ffd080")
    forest(s, 44, 60, -60, W + 60, 1460, 120, 220, "#7a6a96", gap=(CX - 600, CX + 600))
    mist(s, 1450, 300, "#fff4f0", 0.8)
    forest(s, 45, 50, -60, W + 60, 1680, 200, 340, "#5a4a78", gap=(CX - 640, CX + 640))
    mist(s, 1700, 260, "#fff4f0", 0.6)
    forest(s, 46, 18, -100, W + 100, 1940, 380, 560, "#3a2e54", gap=(CX - 860, CX + 860), jitter=40)
    birds(s, 47, 8, CX - 900, CX - 300, 700, 950, "#6a5a7e", 16)
    vignette(s, 0.25, "#4a3a5a")
    return s


def d05_winter_aurora():
    """Winter aurora: green and teal lights over snowy peaks, warm windows in the cold."""
    s = Svg()
    sky(s, [(0, "#030812"), (0.5, "#0a1c30"), (1, "#1a3a50")])
    stars(s, 51, 380, 1100, "#e8fff8")
    # aurora curtains
    for k, (y, amp, col, op) in enumerate([(380, 120, "#4affb0", 0.35), (480, 160, "#3ad8d0", 0.28), (300, 90, "#a0ff8a", 0.22)]):
        n = noise(52 + k, 4, 3)
        top = [(x, y + amp * (n(x) - 0.5) * 2) for x in range(-40, W + 60, 20)]
        g = s.linear([(0, col, 0), (0.25, col, op), (1, col, 0)])
        poly = top + [(x, yy + 420) for x, yy in reversed(top)]
        aur_blur = s.blur(6)
        s.add('<polygon points="%s" fill="%s" filter="%s"/>' % (pts(poly), g, s.blur(14)))
        for x, yy in top[::3]:
            s.add('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="10" opacity="%s" filter="%s"/>' % (f(x), f(yy), f(x), f(yy + 260), col, f(op * 0.18), aur_blur))
    m1 = ridge_line(53, 1100, 400, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#6a8aa4"), (1, "#2a4258")]))
    snowcaps(s, m1, 1000, "#e8f4ff", 54, 0.95)
    mountain_light(s, m1, "#bfe8e0", 0.3, 4, side=-1)
    mist(s, 1120, 220, "#a8c8d8", 0.3)
    m2 = ridge_line(55, 1250, 200, freq=4)
    ridge(s, m2, s.linear([(0, "#d0e4f0"), (1, "#8aa8c0")]))
    hill(s, CX, 1170, 1500, 500, "#c4d8e8", "#ffffff")
    castle(s, CX, 1230, 0.92, {"light": "#4a5a6e", "dark": "#2e3a4c", "roof": "#e8f2fa", "roof_dark": "#b8cadc", "window": "#ffc860", "hut": "#d8e6f2", "line": "#1e2836", "flag": "#c0303c"}, wglow="#ffa840")
    forest(s, 56, 60, -60, W + 60, 1450, 150, 260, "#1e3446", light="#e8f4ff", gap=(CX - 560, CX + 560))
    ridge(s, ridge_line(57, 1600, 80, freq=3), s.linear([(0, "#e8f2fa"), (1, "#a8c0d4")]))
    forest(s, 58, 30, -100, W + 100, 1880, 320, 520, "#12222e", light="#d8eaf8", gap=(CX - 780, CX + 780), jitter=40)
    rng = random.Random(59)
    for _ in range(320):
        s.add('<circle cx="%s" cy="%s" r="%s" fill="#ffffff" opacity="%s"/>' % (f(rng.uniform(0, W)), f(rng.uniform(0, H)), f(rng.uniform(1.5, 4.5)), f(rng.uniform(0.3, 0.8))))
    vignette(s, 0.6, "#020610")
    return s


def d06_autumn_valley():
    """Autumn valley: a bright day, red and orange woods, a river winding up to the outpost."""
    s = Svg()
    sky(s, [(0, "#4a8ad0"), (0.5, "#8ac0e8"), (1, "#d8ecf4")])
    clouds(s, 61, 14, 220, 720, "#ffffff", 0.85, 1.3)
    clouds(s, 62, 8, 240, 700, "#dde8f4", 0.6, 1.0)
    m1 = ridge_line(63, 1050, 300, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#8aa4c4"), (1, "#a8bcd0")]))
    snowcaps(s, m1, 860, "#ffffff", 64, 0.9)
    m2 = ridge_line(65, 1180, 200, freq=4)
    ridge(s, m2, s.linear([(0, "#7a9a6a"), (1, "#5a7a50")]))
    hill(s, CX + 80, 1120, 1500, 560, "#6a8a46", "#a8c870")
    # the river
    s.add('<path d="M%s,1250 C%s,1350 %s,1400 %s,1500 C%s,1600 %s,1700 %s,1940 L%s,1940 C%s,1700 %s,1620 %s,1520 C%s,1420 %s,1360 %s,1250 Z" fill="%s"/>' % (
        f(CX - 200), f(CX - 300), f(CX - 620), f(CX - 560), f(CX - 480), f(CX - 900), f(CX - 1000),
        f(CX - 560), f(CX - 600), f(CX - 300), f(CX - 380), f(CX - 460), f(CX - 160), f(CX - 160), s.linear([(0, "#a8d4f0"), (1, "#4a8ac0")])))
    castle(s, CX + 80, 1180, 0.92, {"light": "#d8c8a8", "dark": "#a89478", "roof": "#b03a30", "roof_dark": "#842a24", "window": "#3a3028", "hut": "#9a5a3a", "line": "#4a3a2a", "flag": "#c0303c"}, lit=False)
    leaves = [("#e0702a", "#b04a20"), ("#f0a030", "#c07020"), ("#c8402a", "#902a1e"), ("#e8c040", "#b89020")]
    grove(s, 66, 70, -60, W + 60, 1420, 140, 220, leaves, "#5a3a24", light="#fff0b0", gap=(CX - 600, CX + 640))
    ridge(s, ridge_line(67, 1620, 100, freq=3), s.linear([(0, "#8aa848"), (1, "#5a7a34")]))
    grove(s, 68, 26, -100, W + 100, 1860, 300, 460, leaves, "#4a2e1c", light="#fff0b0", gap=(CX - 820, CX + 760), jitter=40)
    birds(s, 69, 10, CX - 900, CX - 200, 500, 800, "#3a4a5a", 16)
    return s


def d07_iso_island():
    """The diorama: a floating chunk of land in the game's own iso style, the outpost on top."""
    s = Svg()
    sky(s, [(0, "#0e1424"), (0.6, "#1c2a40"), (1, "#24364a")])
    stars(s, 71, 300, H)
    glow(s, CX, 1000, 1100, "#5a8ab0", 0.25)
    TW, TH = 120, 60  # half a tile, as in the game (but bigger)
    cx, cy = CX, 980

    def iso(gx, gy):
        return (cx + (gx - gy) * TW, cy + (gx + gy) * TH)
    n = 5
    rng = random.Random(72)
    # cliffs (the two front faces), stepped earth layers
    left = [iso(-n, n), iso(n, n)]
    right = [iso(n, n), iso(n, -n)]
    depth = 520
    for (a, b), col, col2 in ((left, "#6a4a32", "#4a3222"), (right, "#553a28", "#3a281c")):
        jag = []
        steps = 14
        for i in range(steps + 1):
            t = i / steps
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t
            jag.append((x, y + depth * (0.55 + 0.45 * math.sin(t * math.pi)) + rng.uniform(-40, 40)))
        s.add('<polygon points="%s" fill="%s"/>' % (pts([a, b] + list(reversed(jag))), s.linear([(0, col), (1, col2)])))
        for k in range(1, 4):
            yy = 70 * k
            s.add('<polyline points="%s" fill="none" stroke="#2a1c14" stroke-width="5" opacity="0.4"/>' % pts([(a[0], a[1] + yy), (b[0], b[1] + yy)]))
    # grass top
    top = [iso(-n, -n), iso(n, -n), iso(n, n), iso(-n, n)]
    s.add('<polygon points="%s" fill="#6a9a48"/>' % pts(top))
    s.add('<polyline points="%s" fill="none" stroke="#a8d070" stroke-width="10"/>' % pts([top[3], top[2], top[1]]))
    for i in range(-n, n):
        for j in range(-n, n):
            if (i + j) % 2 == 0:
                q = [iso(i, j), iso(i + 1, j), iso(i + 1, j + 1), iso(i, j + 1)]
                s.add('<polygon points="%s" fill="#7aaa52" opacity="0.6"/>' % pts(q))
    # a road to the gate and a stream falling off the edge
    road(s, [iso(-n, 1.5), iso(-3, 1.2), iso(-1.5, 0.6)], 46, "#c8a870")
    s.add('<polygon points="%s" fill="#6ab0e0"/>' % pts([iso(2.6, n), iso(3.2, n), (iso(3.2, n)[0], iso(3.2, n)[1] + 600), (iso(2.6, n)[0], iso(2.6, n)[1] + 600)]))
    s.add('<polygon points="%s" fill="#5aa0d8"/>' % pts([iso(2.4, 1), iso(3.4, 1), iso(3.2, n), iso(2.6, n)]))
    glow(s, iso(2.9, n)[0], iso(2.9, n)[1] + 620, 120, "#a8e0ff", 0.4)
    castle(s, cx, cy + 20, 0.85, {"light": "#d8c8a8", "dark": "#a08a6a", "roof": "#b03a30", "roof_dark": "#842a24", "window": "#ffd070", "hut": "#9a5a3a", "line": INK, "flag": CRIMSON}, wglow="#ffb040")
    for gx, gy in [(-4, -3), (-3.5, -4), (-4.3, 3), (3.8, -3.6), (4.2, -1.8), (-2.8, 3.8), (4, 2.6), (1.2, 4.2), (-4.4, 0.4)]:
        x, y = iso(gx, gy)
        pine(s, x, y + 10, rng.uniform(170, 230), "#2e5a34", light="#8ac070")
    for gx, gy in [(-3, 2.6), (3, 3.6), (-1.6, 3.6)]:
        x, y = iso(gx, gy)
        s.add('<ellipse cx="%s" cy="%s" rx="40" ry="24" fill="#8a8a84" stroke="%s" stroke-width="3"/>' % (f(x), f(y), INK))
    # little floating rocks
    for x, y, r in [(CX - 900, 1300, 50), (CX + 980, 760, 36), (CX + 850, 1500, 60), (CX - 1050, 700, 30)]:
        s.add('<polygon points="%s" fill="#5a4030"/>' % pts([(x - r, y), (x + r, y), (x + r * 0.3, y + r * 1.6), (x - r * 0.4, y + r * 1.2)]))
        s.add('<polygon points="%s" fill="#6a9a48"/>' % pts([(x - r, y), (x, y - r * 0.5), (x + r, y), (x, y + r * 0.5)]))
    clouds(s, 73, 8, 1500, 1800, "#3a4a64", 0.6, 1.4)
    vignette(s, 0.6, "#05080e")
    return s


def d08_storm():
    """Storm: slate clouds, a bolt of lightning, rain, the outpost lit by the flash."""
    s = Svg()
    sky(s, [(0, "#0e1218"), (0.5, "#2a323e"), (1, "#4a5260")])
    clouds(s, 81, 20, 100, 900, "#1a2028", 0.85, 1.6)
    clouds(s, 82, 14, 300, 800, "#3a4452", 0.6, 1.2)
    glow(s, CX + 520, 700, 900, "#c8d8ff", 0.35)
    bolt = [(CX + 560, 120), (CX + 500, 400), (CX + 600, 460), (CX + 480, 780), (CX + 560, 820), (CX + 430, 1120)]
    s.add('<polyline points="%s" fill="none" stroke="#c8dcff" stroke-width="26" opacity="0.4" filter="%s"/>' % (pts(bolt), s.blur(8)))
    s.add('<polyline points="%s" fill="none" stroke="#ffffff" stroke-width="7" stroke-linejoin="bevel"/>' % pts(bolt))
    s.add('<polyline points="%s" fill="none" stroke="#ffffff" stroke-width="3"/>' % pts([(CX + 600, 460), (CX + 700, 560), (CX + 690, 680)]))
    m1 = ridge_line(83, 1100, 300, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#3a4250"), (1, "#22282f")]))
    m2 = ridge_line(84, 1230, 170, freq=4)
    ridge(s, m2, "#1a1f26")
    hill(s, CX, 1160, 1500, 500, "#14181d", "#a8b8d8")
    castle(s, CX, 1220, 0.95, {"light": "#4a5466", "dark": "#262c36", "roof": "#5a2a34", "roof_dark": "#3a1a22", "window": "#ffc860", "hut": "#2a2a30", "line": "#0e1014", "flag": "#b02a3a"}, wglow="#ffa840")
    forest(s, 85, 60, -60, W + 60, 1440, 150, 260, "#101418", gap=(CX - 540, CX + 540))
    forest(s, 86, 30, -100, W + 100, 1880, 320, 500, "#080a0d", gap=(CX - 760, CX + 760), jitter=40)
    rng = random.Random(87)
    for _ in range(700):
        x, y = rng.uniform(-200, W), rng.uniform(-50, H)
        L = rng.uniform(40, 90)
        s.add('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#b8c8dc" stroke-width="2" opacity="%s"/>' % (f(x), f(y), f(x + L * 0.3), f(y + L), f(rng.uniform(0.15, 0.4))))
    vignette(s, 0.7, "#05070a")
    return s


def d09_sea_cliff():
    """Sea cliff: the outpost high above the sea, the moon's path on the water."""
    s = Svg()
    sky(s, [(0, "#0a1020"), (0.45, "#1e2a50"), (0.7, "#4a4a78"), (0.8, "#7a6088")])
    stars(s, 91, 320, 900)
    mx = CX - 520
    moon(s, mx, 640, 130, halo_r=4.5, halo_op=0.3)
    clouds(s, 92, 8, 500, 900, "#3a3a64", 0.55, 1.2)
    horizon = 1180
    s.add('<rect x="0" y="%d" width="%d" height="%d" fill="%s"/>' % (horizon, W, H - horizon, s.linear([(0, "#3a3a64"), (0.3, "#1e2444"), (1, "#0a0e1e")])))
    rng = random.Random(93)
    for k in range(70):
        y = horizon + 10 + (k ** 1.5) * 1.6
        w = 30 + k * 7
        x = mx + rng.uniform(-w * 0.5, w * 0.5)
        s.add('<rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="#f3e8c4" opacity="%s"/>' % (f(x - w / 2), f(y), f(w * rng.uniform(0.5, 1)), f(3 + k * 0.08), f(max(0.08, 0.7 - k * 0.008))))
    for _ in range(160):
        x, y = rng.uniform(0, W), rng.uniform(horizon + 20, H)
        s.add('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#5a6a9a" stroke-width="2" opacity="0.35"/>' % (f(x), f(y), f(x + rng.uniform(20, 60)), f(y)))
    # the cliff
    s.add('<path d="M%s,1940 L%s,1500 L%s,1240 L%s,1120 L%s,1100 L%s,1110 L%s,1300 L%s,1520 L%s,1940 Z" fill="%s"/>' % (
        f(CX - 700), f(CX - 600), f(CX - 480), f(CX - 380), f(CX - 100), f(CX + 600), f(W + 40), f(W + 40), f(W + 40), s.linear([(0, "#2a2840"), (1, "#121220")])))
    s.add('<path d="M%s,1240 L%s,1120 L%s,1100 L%s,1180 L%s,1500 Z" fill="#4a4870" opacity="0.6"/>' % (f(CX - 480), f(CX - 380), f(CX - 100), f(CX - 300), f(CX - 560)))
    for x in range(int(CX - 640), int(CX - 360), 40):
        s.add('<path d="M%s,1900 q30,-30 60,0" fill="none" stroke="#c8d0f0" stroke-width="4" opacity="0.4"/>' % f(x))
    castle(s, CX + 80, 1120, 0.9, {"light": "#3a3a58", "dark": "#24243a", "roof": "#4a2a4a", "roof_dark": "#321a34", "window": "#ffd080", "hut": "#2a2440", "line": "#121220", "flag": "#c0303c"}, wglow="#ffb050")
    # lighthouse fire on the right tower
    glow(s, CX + 80 + 300 * 0.9, 1120 - 470 * 0.9, 220, "#ffd080", 0.5)
    forest(s, 94, 22, CX + 600, W + 60, 1300, 140, 240, "#0e0e1a", jitter=40)
    vignette(s, 0.6, "#03040a")
    return s


def d10_arcane():
    """Arcane night: violet skies, a ringed moon, floating crystals and a rune circle."""
    s = Svg()
    sky(s, [(0, "#0c0420"), (0.45, "#2a0e4a"), (0.75, "#5a1e6a"), (1, "#8a3a7a")])
    stars(s, 101, 420, 1200, "#ffe8ff")
    mx, my = CX + 480, 520
    glow(s, mx, my, 700, "#d08aff", 0.3)
    s.add('<ellipse cx="%s" cy="%s" rx="420" ry="70" fill="none" stroke="#e8c0ff" stroke-width="16" opacity="0.45" transform="rotate(-14 %s %s)"/>' % (f(mx), f(my), f(mx), f(my)))
    s.add('<circle cx="%s" cy="%s" r="200" fill="%s"/>' % (f(mx), f(my), s.radial([(0, "#ffe0ff"), (0.7, "#d0a0f0"), (1, "#a070d0")], cx=0.4, cy=0.4, r=0.7)))
    s.add('<path d="M%s,%s a420,70 0 0 0 840,0" fill="none" stroke="#f0d0ff" stroke-width="16" opacity="0.7" transform="rotate(-14 %s %s)"/>' % (f(mx - 420), f(my), f(mx), f(my)))
    m1 = ridge_line(102, 1120, 340, sharp=True, freq=3)
    ridge(s, m1, s.linear([(0, "#4a2a6a"), (1, "#2a1440")]))
    mist(s, 1120, 260, "#d08aff", 0.25)
    m2 = ridge_line(103, 1240, 180, freq=4)
    ridge(s, m2, "#1e0c30")
    hill(s, CX, 1170, 1500, 500, "#180a26", "#e8a0ff")
    # rune circle in front of the gate
    rc_y = 1330
    s.add('<ellipse cx="%s" cy="%s" rx="420" ry="110" fill="none" stroke="#c080ff" stroke-width="8" opacity="0.8" filter="%s"/>' % (f(CX), rc_y, s.blur(4)))
    s.add('<ellipse cx="%s" cy="%s" rx="340" ry="86" fill="none" stroke="#e8c0ff" stroke-width="4" opacity="0.8"/>' % (f(CX), rc_y))
    rng = random.Random(104)
    for k in range(16):
        a = k / 16 * math.tau
        x, y = CX + math.cos(a) * 380, rc_y + math.sin(a) * 98
        s.add('<path d="M%s,%s l8,-14 l8,14 m-8,-14 v22" fill="none" stroke="#f0d8ff" stroke-width="3" opacity="0.8"/>' % (f(x - 8), f(y + 4)))
    glow(s, CX, rc_y, 500, "#b070ff", 0.25, 130)
    castle(s, CX, 1230, 0.92, {"light": "#3a2450", "dark": "#24143a", "roof": "#6a2a7a", "roof_dark": "#4a1a5a", "window": "#a8f0ff", "hut": "#2a1838", "line": "#120820", "flag": "#d040a0"}, wglow="#80e0ff")
    # floating crystals
    for x, y, h, col in [(CX - 820, 760, 160, "#80e0ff"), (CX - 600, 1000, 90, "#e090ff"), (CX + 760, 1040, 120, "#80e0ff"), (CX - 1000, 1120, 70, "#ffa0e0"), (CX + 1050, 820, 80, "#e090ff")]:
        glow(s, x, y, h * 1.4, col, 0.45)
        s.add('<polygon points="%s" fill="%s" stroke="#ffffff" stroke-width="3" stroke-linejoin="round"/>' % (pts([(x, y - h), (x + h * 0.32, y - h * 0.2), (x, y + h * 0.5), (x - h * 0.32, y - h * 0.2)]), col))
        s.add('<polygon points="%s" fill="#ffffff" opacity="0.45"/>' % pts([(x, y - h), (x - h * 0.32, y - h * 0.2), (x - h * 0.05, y - h * 0.1)]))
    forest(s, 105, 60, -60, W + 60, 1460, 150, 260, "#12081e", gap=(CX - 560, CX + 560))
    forest(s, 106, 30, -100, W + 100, 1880, 320, 500, "#08040e", gap=(CX - 760, CX + 760), jitter=40)
    fireflies(s, 107, 50, 100, W - 100, 1100, 1800, "#c0f0ff")
    vignette(s, 0.6, "#05020a")
    return s


def d11_poster():
    """Heraldic poster: flat shapes and few colours, a big sun disc, banners down both sides."""
    s = Svg()
    s.add('<rect width="%d" height="%d" fill="#efe0c0"/>' % (W, H))
    # sun rays
    for k in range(24):
        a0, a1 = k / 24 * math.tau, (k + 0.5) / 24 * math.tau
        r = 2400
        s.add('<polygon points="%s" fill="#e8d0a4"/>' % pts([(CX, 900), (CX + math.cos(a0) * r, 900 + math.sin(a0) * r), (CX + math.cos(a1) * r, 900 + math.sin(a1) * r)]))
    s.add('<circle cx="%s" cy="900" r="420" fill="#e8a040"/>' % f(CX))
    s.add('<circle cx="%s" cy="900" r="380" fill="none" stroke="#efe0c0" stroke-width="10"/>' % f(CX))
    for i, (base, amp, col) in enumerate([(1180, 260, "#b8a070"), (1300, 200, "#8a8a58"), (1440, 160, "#5a6a40"), (1620, 120, "#3a4a30")]):
        line = ridge_line(111 + i, base, amp, sharp=(i == 0), freq=3, octaves=2, step=40)
        ridge(s, line, col)
        if i == 1:
            s.add('<path d="M%s,1300 L%s,980 L%s,1300 Z" fill="#8a8a58"/>' % (f(CX - 380), f(CX), f(CX + 380)))
            castle(s, CX, 1040, 0.85, {"light": "#3a2a24", "dark": "#3a2a24", "roof": "#8c1c2b", "roof_dark": "#8c1c2b", "window": "#e8a040", "hut": "#5a2a24", "flag": "#8c1c2b"})
    # pines as flat triangles
    rng = random.Random(115)
    for _ in range(40):
        x = rng.uniform(-40, W + 40)
        if CX - 520 < x < CX + 520:
            continue
        h = rng.uniform(140, 260)
        b = 1560 + rng.uniform(-40, 60)
        s.add('<polygon points="%s" fill="#2a3a24"/>' % pts([(x - h * 0.22, b), (x, b - h), (x + h * 0.22, b)]))
    # banners
    for bx in (220, W - 220):
        s.add('<rect x="%s" y="0" width="16" height="1500" fill="#3a2a24"/>' % f(bx - 8))
        s.add('<path d="M%s,120 h260 v900 l-130,-110 l-130,110 Z" fill="#8c1c2b"/>' % f(bx - 130))
        s.add('<path d="M%s,150 h220 v830 l-110,-90 l-110,90 Z" fill="none" stroke="#e8a040" stroke-width="8"/>' % f(bx - 110))
        s.add('<circle cx="%s" cy="480" r="80" fill="#e8a040"/><path d="M%s,440 l40,70 h-80 Z" fill="#8c1c2b"/>' % (f(bx), f(bx)))
    s.add('<rect width="%d" height="%d" fill="none" stroke="#3a2a24" stroke-width="40"/>' % (W, H))
    return s


def d12_haunted_marsh():
    """Haunted marsh: green fog, dead trees, will-o'-wisps, a graveyard, the outpost far off."""
    s = Svg()
    sky(s, [(0, "#060c0a"), (0.5, "#14281e"), (0.8, "#2a4a34"), (1, "#3a5a40")])
    stars(s, 121, 200, 700, "#d8ffe0")
    moon(s, CX + 700, 480, 110, color="#e0f0c8", shade="#b8d0a0", halo="#c8ffb0", halo_op=0.25)
    m1 = ridge_line(122, 1080, 260, freq=3)
    ridge(s, m1, s.linear([(0, "#1e3a2a"), (1, "#14281e")]))
    mist(s, 1080, 260, "#8ad8a0", 0.3)
    hill(s, CX + 120, 1080, 1100, 400, "#10201a", "#8ad8a0")
    castle(s, CX + 120, 1120, 0.7, {"light": "#22342a", "dark": "#142018", "roof": "#2a3a2a", "roof_dark": "#1a281c", "window": "#d8ff9a", "hut": "#1a2a1e", "flag": "#6a2a3a"}, wglow="#b8ff7a")
    mist(s, 1200, 300, "#9ae8b0", 0.4)
    # marsh water
    s.add('<rect x="0" y="1260" width="%d" height="680" fill="%s"/>' % (W, s.linear([(0, "#1a3a2a"), (1, "#081410")])))
    rng = random.Random(123)
    for _ in range(26):
        x, y = rng.uniform(0, W), rng.uniform(1300, 1850)
        w = rng.uniform(200, 520)
        s.add('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#2a4a34" opacity="0.8"/>' % (f(x), f(y), f(w), f(w * 0.12)))
    for _ in range(14):
        dead_tree(s, rng.choice([rng.uniform(-50, CX - 500), rng.uniform(CX + 600, W + 50)]), rng.uniform(1300, 1500), rng.uniform(300, 520), "#0a1410", rng)
    # graveyard
    for k in range(9):
        x = CX - 900 + k * 120 + rng.uniform(-30, 30)
        y = 1560 + rng.uniform(-30, 30)
        if k % 3 == 0:
            s.add('<path d="M%s,%s v-110 M%s,%s h70" stroke="#0e1a14" stroke-width="18" stroke-linecap="square"/>' % (f(x), f(y), f(x - 35), f(y - 80)))
        else:
            s.add('<path d="M%s,%s v-70 a40,40 0 0 1 80,0 v70 Z" fill="#14241c" transform="rotate(%s %s %s)"/>' % (f(x - 40), f(y), f(rng.uniform(-10, 10)), f(x), f(y)))
    mist(s, 1560, 320, "#8ad8a0", 0.35)
    for x, y in [(CX - 600, 1380), (CX + 760, 1460), (CX - 1000, 1250), (CX + 300, 1600), (CX + 1080, 1300), (CX - 300, 1500)]:
        glow(s, x, y, 90, "#b8ffa0", 0.7)
        s.add('<circle cx="%s" cy="%s" r="9" fill="#f0ffe0"/>' % (f(x), f(y)))
    ridge(s, ridge_line(124, 1860, 100, freq=3), "#040806")
    vignette(s, 0.75, "#010302")
    return s


DESIGNS = [d01_moonrise, d02_golden_hour, d03_horde, d04_misty_dawn, d05_winter_aurora, d06_autumn_valley,
           d07_iso_island, d08_storm, d09_sea_cliff, d10_arcane, d11_poster, d12_haunted_marsh]


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    pick = [int(a) for a in sys.argv[2:]] or range(1, len(DESIGNS) + 1)
    os.makedirs(out, exist_ok=True)
    for i in pick:
        fn = DESIGNS[i - 1]
        with open(os.path.join(out, "title_%02d.svg" % i), "w") as fh:
            fh.write(fn().svg())
        print("title_%02d  %s" % (i, fn.__doc__.split(":")[0]))


if __name__ == "__main__":
    main()
