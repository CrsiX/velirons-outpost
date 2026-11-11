"""Trees: pines, the spruce, oaks and dead trees."""

import math
import random

from .core import Art, INK, WOOD, WOOD_D


# Pine greens, lowest tier to the top (lit, shaded): the pines use every other
# step, the spruce (tree_pine_2) all five.
PINE_GREENS = [("#1f3a28", "#162c1e"), ("#223e2c", "#183020"), ("#244330", "#193322"), ("#274833", "#1b3625"), ("#2a4c36", "#1d3827")]


def tree_pine(i):
    rng = random.Random(30 + i)
    s = 1.0 + 0.12 * i
    a = Art()
    a.shadow(28 * s, 13 * s)
    a.poly([(-3, 0), (3, 0), (3, -16), (-3, -16)], WOOD_D)
    tiers = [(-12, 30, -52), (-34, 25, -72), (-54, 18, -94)]
    for (base, hw, apex), (gl, gr) in zip(tiers, PINE_GREENS[::2]):
        base, hw, apex = base * s, hw * s, apex * s
        a.poly([(-hw, base), (0, apex), (hw, base), (0, base + 5)], gl)
        a.poly([(0, apex), (hw, base), (0, base + 5)], gr, stroke=None)
        a.line([(-hw, base), (0, apex), (hw, base)], INK, 1.4)
    a.line([(-6 * s, -58 * s), (-2 * s, -80 * s)], "#3a6448", 1.6, opacity=0.8)
    a.save("tree_pine_%d" % i)


def _bough(a, pts, w0, w1=None, bark=WOOD_D, light=WOOD):
    """A branch along `pts` tapering from width w0 to w1: ink outline, bark, a lit edge."""
    w1 = w1 if w1 is not None else w0 * 0.45
    left, right = [], []
    for k, (x, y) in enumerate(pts):
        nx_, ny_ = pts[min(k + 1, len(pts) - 1)]
        px, py = pts[max(k - 1, 0)]
        dx, dy = nx_ - px, ny_ - py
        ln = math.hypot(dx, dy) or 1.0
        w = (w0 + (w1 - w0) * k / (len(pts) - 1)) / 2.0
        left.append((x - dy / ln * w, y + dx / ln * w))
        right.append((x + dy / ln * w, y - dx / ln * w))
    a.poly(left + right[::-1], bark, INK, 1.3)
    a.line(left if left[0][0] < right[0][0] else right, light, max(0.9, w0 * 0.25), opacity=0.7)


# Oak greens, lower clumps to upper ones (lit, shaded), like the pines' tiers.
OAK_GREENS = [("#203a22", "#172c19"), ("#26442a", "#1b331e"), ("#2c4e30", "#203a24"), ("#335a36", "#264429")]


def _clump(a, cx, cy, r, tone, sheen=False):
    """One round leaf clump in the flat style: ink outline, the left half lit
    and the right half shaded (split down the middle like a pine tier)."""
    lit, shade = OAK_GREENS[tone]
    ry = r * 0.88
    a.ellipse(cx, cy, r, ry, shade, INK, 1.4)
    half = [(cx + math.cos(math.pi / 2 + math.pi * k / 16) * r, cy - math.sin(math.pi / 2 + math.pi * k / 16) * ry) for k in range(17)]
    a.poly(half, lit, stroke=None)
    a.ellipse(cx, cy, r, ry, "none", INK, 1.4)
    if sheen:
        a.line([(cx - r * 0.55, cy - ry * 0.1), (cx - r * 0.3, cy - ry * 0.6)], "#4a7a4c", 1.6, opacity=0.8)


def _oak_trunk(a, w0, w1, top, lean=0.0):
    """A plain tapering trunk, lit left half and shaded right half like the pines' trunks."""
    tx = lean
    a.poly([(-w0, 0), (w0, 0), (tx + w1, top), (tx - w1, top)], WOOD_D, INK, 1.4)
    a.poly([(-w0, 0), (0, 0), (tx, top), (tx - w1, top)], WOOD, stroke=None)
    a.line([(-w0, 0), (tx - w1, top)], INK, 1.4)
    a.line([(w0, 0), (tx + w1, top)], INK, 1.4)


def _limb(a, x0, y0, x1, y1, w, col=WOOD_D, tip=0.4):
    """A plain branch: a tapering outlined wedge."""
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    a.poly([(x0 + nx * w, y0 + ny * w), (x1 + nx * w * tip, y1 + ny * w * tip), (x1 - nx * w * tip, y1 - ny * w * tip), (x0 - nx * w, y0 - ny * w)], col, INK, 1.3)


def tree_oak(i):
    """Oaks in the flat style of the pines: a plain trunk with a couple of
    limbs, and a crown of round clumps, lower ones darker, the top lit.
    0 a broad old oak, 1 a younger, taller one, 2 a crooked one leaning,
    its crown lopsided."""
    a = Art()
    if i == 0:
        a.shadow(36, 16)
        _oak_trunk(a, 6, 4, -34)
        _limb(a, -1, -28, -16, -44, 3.2)
        _limb(a, 1, -30, 17, -46, 3.2)
        for cx, cy, r, tone in [(-22, -54, 17, 0), (22, -54, 17, 0), (0, -52, 16, 0), (-12, -72, 20, 1), (13, -73, 19, 1)]:
            _clump(a, cx, cy, r, tone)
        _clump(a, 0, -90, 16, 2, sheen=True)
        a.save("tree_oak")
    elif i == 1:
        a.shadow(26, 12)
        _oak_trunk(a, 4.5, 3, -40)
        _limb(a, 0, -36, -10, -50, 2.4)
        _limb(a, 0, -38, 10, -52, 2.4)
        for cx, cy, r, tone in [(-11, -60, 13, 0), (11, -61, 13, 0), (-7, -78, 14, 1), (8, -80, 14, 1)]:
            _clump(a, cx, cy, r, tone)
        _clump(a, 0, -98, 13, 2, sheen=True)
        a.save("tree_oak_1")
    else:
        a.shadow(34, 15, cx=4)
        _oak_trunk(a, 6, 4, -30, lean=8)
        _limb(a, 3, -20, -10, -36, 3)
        _limb(a, 8, -28, 24, -42, 3)
        _clump(a, -14, -44, 13, 0)
        for cx, cy, r, tone in [(6, -54, 16, 0), (27, -52, 13, 0), (16, -70, 18, 1), (-4, -66, 13, 1)]:
            _clump(a, cx, cy, r, tone)
        _clump(a, 8, -84, 12, 2, sheen=True)
        a.ellipse(1, -12, 2.4, 3.6, "#1a120b", INK, 1)  # a hollow in the trunk
        a.save("tree_oak_2")


def tree_spruce():
    """The third pine (tree_pine_2): a slim, dark spruce in the pines' greens whose five
    tiers droop at their tips."""
    a = Art()
    a.shadow(24, 11)
    a.poly([(-3, 0), (3, 0), (3, -14), (-3, -14)], WOOD_D)
    tiers = [(-10, 28, -40), (-28, 24, -58), (-46, 20, -76), (-64, 15, -94), (-82, 9, -110)]
    for (base, hw, apex), (gl, gr) in zip(tiers, PINE_GREENS):
        h = base - apex
        lt = [(0, apex), (-hw * 0.42, apex + h * 0.6), (-hw, base + 4), (-hw * 0.62, base - 1), (-hw * 0.3, base + 2), (0, base + 4)]
        rt = [(0, apex), (hw * 0.42, apex + h * 0.6), (hw, base + 4), (hw * 0.62, base - 1), (hw * 0.3, base + 2), (0, base + 4)]
        a.poly(lt, gl, stroke=None)
        a.poly(rt, gr, stroke=None)
        a.line(lt[1:][::-1] + rt[1:], INK, 1.0, opacity=0.6)
        a.line([lt[2], lt[1], (0, apex), rt[1], rt[2]], INK, 1.4)
    a.line([(-5, -60), (-2, -84)], "#3a6448", 1.4, opacity=0.7)
    a.save("tree_pine_2")


def tree_dead(i=0):
    """Dead trees: 0 a bare one with forked twigs, 1 a broken snag (a thick
    stump of a trunk snapped off jaggedly, peeled bark, a bracket fungus)."""
    if i == 1:
        a = Art()
        a.shadow(22, 9)
        bark, bark_l = "#4a4036", "#6b5f50"
        _bough(a, [(3, -26), (14, -34), (20, -46), (28, -50)], 4.2, 1.6, bark, bark_l)
        trunk = [(-11, 2), (-7, -4), (-6, -30), (-7, -40), (-3, -35), (-1, -48), (2, -38), (5, -43), (6, -28), (7, -4), (12, 2), (2, 0.5)]
        a.poly(trunk, bark, INK, 1.4)
        a.poly([(-11, 2), (-7, -4), (-6, -30), (-7, -40), (-3, -35), (-2, -12), (-4, 1)], bark_l, stroke=None, opacity=0.8)
        a.poly([(-1, -30), (3, -30), (2, -16), (-1, -18)], "#8a7d68", INK, 0.9)  # peeled bark
        a.line([(-4, -6), (-5, -26)], "#2f2720", 1.0, opacity=0.7)
        a.line([(4, -5), (3, -22)], "#2f2720", 1.0, opacity=0.7)
        a.poly([(5, -14), (12, -16), (12, -13), (5, -11)], "#a08a5c", INK, 1.0)  # bracket fungus
        a.poly([(5, -20), (10, -21), (10, -19), (5, -18)], "#a08a5c", INK, 0.9)
        a.save("tree_dead_1")
        return
    a = Art()
    a.shadow(20, 8)
    bark, bark_l = "#4a4036", "#5f5446"
    # limbs first (the trunk covers their roots), each a tapering wedge with a twig
    for x0, y0, x1, y1, w, tw in [(-1, -28, -15, -46, 3.0, (-19, -60)), (1, -34, 14, -50, 2.8, (23, -55)), (0, -40, 3, -64, 2.4, None), (-1, -36, -9, -52, 1.8, None)]:
        _limb(a, x0, y0, x1, y1, w, bark, 0.35)
        if tw:
            _limb(a, x1, y1, tw[0], tw[1], w * 0.4, bark, 0.3)
    trunk = [(-7, 1), (-4, -4), (-2, -46), (2, -46), (4, -4), (8, 1), (0, 0)]
    a.poly(trunk, bark, INK, 1.4)
    a.poly([(-7, 1), (-4, -4), (-2, -46), (0, -46), (0, 0)], bark_l, stroke=None)
    a.line([(-7, 1), (-4, -4), (-2, -46)], INK, 1.4)
    a.line([(1, -10), (0.5, -26)], "#352d25", 1.0, opacity=0.8)  # a crack in the bark
    a.save("tree_dead")
