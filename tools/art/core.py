"""The shared toolkit of the art generator: paths, the palette and constants, P (grid to
screen), the Art canvas and its save(), the global `manifest` and the FORT hook,
write_manifest(), and every helper more than one art module uses."""

import math
import os
import re



ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
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
# While a level-4/5 wall, gate or tower is drawn: what fort_marks adds before it is saved.
FORT = {"hook": None}


def P(gx, gy, z=0.0):
    """Grid offset (tiles) + height (px) -> screen offset from anchor."""
    return ((gx - gy) * TW, (gx + gy) * TH - z)


def fmt(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


# Banner cloth (docs/village-design.md §12): drawn crimson in the sprite; its grey companion
# `<name>_flag` has the main face white and the folds this share of it, so the game's tint gives
# the village colour and a darker shade of it (the share the co-op hero's cape uses).
CLOTH_FOLD = 0.68
_CLOTH_GREY = {CRIMSON: "#ffffff", CRIMSON_D: "#%02x%02x%02x" % ((round(255 * CLOTH_FOLD),) * 3)}


class Art:
    def __init__(self):
        self.els = []
        self.pts = []
        self.cloth_at = []  # indices into els of the banner cloth

    def cloth(self, pts, dark=False, stroke=INK, sw=1.2):
        """Banner cloth: crimson (`dark`: its fold), with a grey copy in the `_flag` companion
        the game tints with the village colour. The only way to draw cloth on a village piece."""
        self.cloth_at.append(len(self.els))
        self.poly(pts, CRIMSON_D if dark else CRIMSON, stroke, sw)

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
        if FORT["hook"] is not None and "_front" not in name:
            FORT["hook"](self)  # (levels 4 and 5 of walls, gates and towers: fort_marks)
        if fixed:
            minx, miny, maxx, maxy = fixed
        else:
            xs = [p[0] for p in self.pts]
            ys = [p[1] for p in self.pts]
            minx, miny, maxx, maxy = min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad
        w, h = maxx - minx, maxy - miny
        head = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">\n  '
                % (math.ceil(w * 2), math.ceil(h * 2), fmt(minx), fmt(miny), fmt(math.ceil(w * 2) / 2), fmt(math.ceil(h * 2) / 2)))
        svg = head + "\n  ".join(self.els) + "\n</svg>\n"
        with open(os.path.join(ART, name + ".svg"), "w") as f:
            f.write(svg)
        entry = {"ax": -minx, "ay": -miny, "w": math.ceil(w * 2) / 2, "h": math.ceil(h * 2) / 2}
        if extra:
            entry.update(extra)
        if self.cloth_at:
            body = self._flag_body((minx, miny, math.ceil(w * 2) / 2, math.ceil(h * 2) / 2))
            with open(os.path.join(ART, name + "_flag.svg"), "w") as f:
                f.write(head + body + "\n</svg>\n")
            entry["flag"] = True
        manifest[name] = entry

    def _flag_body(self, view):
        """The companion's content: the cloth in grey, masked so that whatever was drawn after
        a piece of cloth over it (a merlon, the fort marks) still hides it. A raw element (a
        gradient glow) is left out of the mask: the cloth shows through it."""
        first = self.cloth_at[0]
        grey, mask, later = [], [], False
        for i in range(first, len(self.els)):
            el = self.els[i]
            if i in self.cloth_at:
                fill = re.search(r' fill="([^"]*)"', el).group(1)
                grey.append(el.replace(' fill="%s"' % fill, ' fill="%s"' % _CLOTH_GREY[fill], 1))
                mask.append(_recolour(el, "#fff"))
            elif not el.startswith("<defs") and "url(#" not in el:
                mask.append(_recolour(el, "#000"))
                later = True
        if not later:
            return "\n  ".join(grey)
        x, y, w, h = view
        return ('<defs><mask id="cloth" maskUnits="userSpaceOnUse" x="%s" y="%s" width="%s" height="%s">\n    %s\n  </mask></defs>\n'
                '  <g mask="url(#cloth)">\n    %s\n  </g>' % (fmt(x), fmt(y), fmt(w), fmt(h), "\n    ".join(mask), "\n    ".join(grey)))


def _recolour(el, colour):
    """An element with every fill and stroke (but none) in one colour: a mask's black or white."""
    return re.sub(r' (fill|stroke)="(?!none)[^"]*"', lambda m: ' %s="%s"' % (m.group(1), colour), el)


def diamond(scale_x=1.0, scale_y=None, cx=0, cy=0):
    sy = scale_y if scale_y is not None else scale_x
    return [(cx, cy - TH * sy), (cx + TW * scale_x, cy), (cx, cy + TH * sy), (cx - TW * scale_x, cy)]


def rand_in_diamond(rng, s=0.8):
    while True:
        gx, gy = rng.uniform(-0.5, 0.5) * s, rng.uniform(-0.5, 0.5) * s
        return P(gx, gy)


def _block(a, rng, x, y, w):
    a.poly([(x - w, y), (x - w * 0.4, y - w * 0.7), (x + w * 0.6, y - w * 0.6), (x + w, y)], rng.choice([STONE_L, STONE_R, "#6b665e"]), INK, 1)
ROPE, ROPE_D = "#bda574", "#7d6a45"
IRON, IRON_L = "#3a3632", "#8a8a8a"
BRASS = "#b8913a"


def _merlon_spots(s, front, k=0.13):
    """The merlon corners round a square top of half-size s (as merlons())."""
    if front:
        return [(-s, s - k), (0 - k / 2, s - k), (s - k, s - k), (s - k, 0 - k / 2), (s - k, -s)]
    return [(-s, -s), (0 - k / 2, -s), (s - k, -s), (-s, 0 - k / 2)]


def _ring(r, z, t0, t1, n=12):
    """Points round a circle of radius r (tiles) at height z, angles t0..t1 (degrees)."""
    return [P(r * math.cos(math.radians(t0 + (t1 - t0) * k / n)), r * math.sin(math.radians(t0 + (t1 - t0) * k / n)), z) for k in range(n + 1)]


def hanging_banner(a, face, u0, u1, z_top, z_bot, emblem=GOLD):
    """Swallow-tailed banner (cloth, Art.cloth) on a visible face ('left' = gy+, 'right' = gx+),
    with an emblem disc (gold, or the material's metal) that is never tinted."""
    def at(u, z):
        return P(u, face[1], z) if face[0] == "left" else P(face[1], -u, z)
    um = (u0 + u1) / 2
    a.cloth([at(u0, z_top), at(u1, z_top), at(u1, z_bot), at(um, z_bot + 6), at(u0, z_bot)])
    x, y = at(um, (z_top + z_bot) / 2 + 2)
    a.ellipse(x, y, 2.6, 2.6, emblem, INK, 0.8)


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


BONE, BONE_D = "#d8d0bc", "#a89f88"


def shade(hex_color, f):
    """`hex_color` with each channel scaled by `f` (below 1 darkens)."""
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(c * f))) for c in (r, g, b))


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


def _bone(a, x0, y0, x1, y1, w=1.8):
    a.line([(x0, y0), (x1, y1)], INK, w + 1.6)
    a.line([(x0, y0), (x1, y1)], BONE, w)
    for (x, y) in ((x0, y0), (x1, y1)):
        a.ellipse(x, y, w * 0.8, w * 0.65, BONE, INK, 0.7)


def check_flags():
    """Stops the generator when a banner companion (Art.cloth) doesn't line up with its sprite;
    removes a companion whose sprite no longer has cloth."""
    def view(name):
        with open(os.path.join(ART, name + ".svg")) as f:
            return re.search(r'<svg [^>]*>', f.read()).group(0)
    for name, e in manifest.items():
        if e.get("flag") and view(name + "_flag") != view(name):
            raise SystemExit("banner companion %s_flag doesn't match its sprite's size and anchor" % name)
    for fn in os.listdir(ART):
        if fn.endswith("_flag.svg") and not manifest.get(fn[:-len("_flag.svg")], {}).get("flag"):
            for stale in (fn, fn + ".import"):
                if os.path.exists(os.path.join(ART, stale)):
                    os.remove(os.path.join(ART, stale))
            print("removed stale banner companion %s" % fn)


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
