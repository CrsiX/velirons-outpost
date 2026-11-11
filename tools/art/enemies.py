"""Enemies and their corpses: goblins, orcs, skeletons, witches, thieves, gargoyles,
vultures, ghosts, necromancers, vampires, slimes, rats, spiders, wrathwoods, water
monsters, wolves, the snake, horses and riders, and the monster lairs."""

import math
import os
import random

from .core import (
    _arc, ART, Art, BONE, _bone, CRIMSON_D, fmt, _glow, GOLD, GOLD_D, INK, manifest, person, _rock,
    WOOD_D,
)


def skeleton():
    a = Art()
    a.shadow(11, 4.5, opacity=0.4)
    # legs
    for x0, x1 in ((-3, -4), (3, 4)):
        a.line([(x0, -1), (x1, -12)], INK, 3.6)
        a.line([(x0, -1), (x1, -12)], BONE, 2)
        a.ellipse(x0 + (-1 if x0 < 0 else 1), -1, 3, 1.5, BONE, INK, 1)
    # pelvis + tattered loincloth
    a.poly([(-6, -13), (6, -13), (4, -9), (-4, -9)], "#4a3a44", INK, 1)
    a.poly([(-5, -9), (-2, -9), (-4, -5)], "#4a3a44", INK, 0.8)
    a.poly([(1, -9), (5, -9), (3, -4)], "#4a3a44", INK, 0.8)
    # spine + ribs
    a.line([(0, -13), (0, -27)], INK, 3.4)
    a.line([(0, -13), (0, -27)], BONE, 1.8)
    for k, y in enumerate((-24, -21, -18)):
        w = 6 - k
        a.raw('<path d="M%d,%d Q0,%d %d,%d" fill="none" stroke="%s" stroke-width="3.2" stroke-linecap="round"/>' % (-w, y + 2, y - 1, w, y + 2, INK), [(-w, y - 1), (w, y + 2)])
        a.raw('<path d="M%d,%d Q0,%d %d,%d" fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % (-w, y + 2, y - 1, w, y + 2, BONE), [(-w, y - 1), (w, y + 2)])
    # bony arms reaching forward, empty-handed
    for pts in ([(3, -25), (8, -19), (12, -21)], [(-3, -25), (-6, -18), (-5, -13)]):
        a.line(pts, INK, 3.4)
        a.line(pts, BONE, 1.8)
    for fx in (12.5, 14):
        a.line([(12, -21), (fx, -23)], BONE, 1.2)
    # skull with glowing sockets
    a.ellipse(0, -32, 6.5, 6, BONE, INK, 1.3)
    a.poly([(-3.5, -28), (3.5, -28), (3, -25), (-3, -25)], BONE, INK, 1)
    a.line([(-1.5, -26.5), (-1.5, -25)], INK, 0.8)
    a.line([(1.5, -26.5), (1.5, -25)], INK, 0.8)
    a.ellipse(-2.2, -32.5, 1.8, 2, "#1a1612")
    a.ellipse(2.5, -32.5, 1.8, 2, "#1a1612")
    a.ellipse(-2.2, -32.5, 0.9, 0.9, "#9fe8ff")
    a.ellipse(2.5, -32.5, 0.9, 0.9, "#9fe8ff")
    a.save("unit_skeleton")


def orc():
    """Big, hunched brute with pointy ears, tusks, an iron pauldron and a sword."""
    a = Art()
    a.shadow(14, 5.5, opacity=0.45)
    skin, skin_d = "#6b7a52", "#55623f"
    for x0, x1 in ((-5, -6), (5, 6)):  # thick legs
        a.line([(x0, -1), (x1, -12)], INK, 7)
        a.line([(x0, -1.5), (x1, -12)], "#4a3a2a", 4.6)
        a.ellipse(x0 + (-1 if x0 < 0 else 1), -1, 4.5, 2, "#2a211a", INK, 1)
    a.poly([(-11, -11), (10, -11), (12, -30), (-10, -32)], "#5a4432", INK, 1.4)  # leather armour
    a.poly([(0, -11), (10, -11), (12, -30), (0, -31)], "#4a3828", stroke=None)
    a.line([(-10, -16), (10, -16)], "#2a1e14", 2.2)
    a.poly([(-13, -34), (-3, -34), (-2, -26), (-13, -26)], "#7d7a74", INK, 1.2)  # iron pauldron
    a.ellipse(-8, -30, 1.2, 1.2, "#b0aca4")
    # sword arm and a broad straight sword
    a.line([(8, -26), (14, -18)], INK, 5.5)
    a.line([(8, -26), (14, -18)], skin, 3.4)
    a.line([(12, -16), (17, -20)], INK, 3)  # guard
    a.poly([(14.5, -20), (17, -18), (25, -42), (23, -44)], "#b8b8b8", INK, 1.2)  # blade
    a.line([(15.5, -20), (23.5, -42)], "#e0e0e0", 0.8)
    # head: heavy jaw, tusks, pointy ears, small red eyes
    a.poly([(-16, -40), (-7, -38), (-8, -34)], skin, INK, 1.2)
    a.poly([(15, -41), (7, -38), (8, -34)], skin, INK, 1.2)
    a.poly([(-8, -46), (8, -46), (9, -35), (5, -30), (-5, -30), (-9, -35)], skin, INK, 1.4)
    a.poly([(0, -46), (8, -46), (9, -35), (5, -30), (0, -30)], skin_d, stroke=None, opacity=0.7)
    a.line([(-6, -41), (-1, -40)], INK, 2)  # brow
    a.line([(6, -41), (1, -40)], INK, 2)
    a.ellipse(-3.5, -38.5, 1.3, 1.1, "#e03020")
    a.ellipse(3.5, -38.5, 1.3, 1.1, "#e03020")
    a.poly([(-4, -32), (-3, -36), (-2, -32)], "#efe8d0", INK, 0.7)  # tusks
    a.poly([(2, -32), (3, -36), (4, -32)], "#efe8d0", INK, 0.7)
    a.save("unit_orc")


def witch():
    """Human-like witch: pale face, long dark hair, black dress, wide-brimmed pointy black hat."""
    def extra(a, layer):
        if layer == "back":
            a.raw('<path d="M-7,-34 Q-10,-24 -8,-16 L-4,-18 Q-5,-26 -4,-33 Z" fill="#241c20" stroke="%s" stroke-width="1"/>' % INK, [(-10, -35), (-3, -16)])  # hair
        else:
            a.poly([(-5, -24), (5, -24), (3, -20), (-3, -20)], "#5a2a4a", INK, 0.8)  # collar
            a.line([(4, -21), (11, -26)], INK, 3.8)  # arm raised, casting
            a.line([(4, -21), (11, -26)], "#1c1820", 2.2)
            a.ellipse(13, -28, 5, 5, "#ff6ad5", opacity=0.35)
            a.ellipse(13, -28, 2, 2, "#ffb0ec")

    def hat(a):
        a.ellipse(0, -37.5, 12, 3.2, "#15121a", INK, 1.2)  # wide brim
        a.raw('<path d="M-6,-38 L6,-38 L2,-44 L6,-58 L-3,-45 Z" fill="#1c1822" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-7, -59), (7, -37)])
        a.line([(-5.5, -39.5), (5.5, -39.5)], "#7a3a6a", 1.6)  # band
    person("unit_witch", ("#1c1820", "#141118"), hat=hat, robe=True, skin="#e8d8c8", extra=extra)


def corpse_orc():
    a = Art()
    a.ellipse(0, 0, 22, 7, "#000", opacity=0.3)
    a.ellipse(0, 1, 18, 5, "#3a1a14", opacity=0.5)
    a.poly([(-15, -3), (8, -8), (12, -1), (-12, 5)], "#5a4432", INK, 1.2)
    a.line([(-15, 0), (-24, 3)], INK, 6)
    a.line([(-15, 0), (-24, 3)], "#4a3a2a", 4)
    a.ellipse(15, -4, 7.5, 6, "#6b7a52", INK, 1.3)
    a.poly([(19, -8), (27, -12), (21, -3)], "#6b7a52", INK, 1)
    a.line([(12.5, -6), (15, -3)], INK, 1.3)
    a.line([(15, -6), (12.5, -3)], INK, 1.3)
    a.poly([(-4, 7), (-20, 11), (-19, 13), (-3, 9)], "#b8b8b8", INK, 1)  # dropped sword
    a.save("corpse_orc")


def corpse_witch():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.poly([(-14, 0), (6, -5), (10, 2), (-10, 5)], "#1c1820", INK, 1.2)  # dress
    a.ellipse(12, -3, 5, 4.5, "#e8d8c8", INK, 1.2)
    a.line([(12, -3), (16, 2)], "#241c20", 3)  # hair
    a.ellipse(-4, -9, 9, 2.5, "#15121a", INK, 1)  # hat on the ground
    a.poly([(-8, -9), (0, -9), (-3, -20)], "#1c1822", INK, 1)
    a.ellipse(-16, 5, 3, 3, "#ff6ad5", opacity=0.3)  # fading magic
    a.save("corpse_witch")


def spell_bolt():
    """Whirling, glowing pink ball."""
    a = Art()
    a.raw('<defs><radialGradient id="sb"><stop offset="0" stop-color="#ffe0f6"/><stop offset="0.45" stop-color="#ff6ad5"/><stop offset="1" stop-color="#ff6ad5" stop-opacity="0"/></radialGradient></defs>', [(0, 0)])
    a.ellipse(0, 0, 14, 14, "url(#sb)")
    for k in range(3):
        ang = k * 2.094
        x0, y0 = math.cos(ang) * 3, math.sin(ang) * 3
        x1, y1 = math.cos(ang + 1.6) * 10, math.sin(ang + 1.6) * 10
        a.raw('<path d="M%s,%s Q%s,%s %s,%s" fill="none" stroke="#ffd0f0" stroke-width="1.6" stroke-linecap="round"/>' % (fmt(x0), fmt(y0), fmt(math.cos(ang + 0.8) * 9), fmt(math.sin(ang + 0.8) * 9), fmt(x1), fmt(y1)), [(-11, -11), (11, 11)])
    a.save("spell_bolt")


def spell_glow():
    """Soft pink halo around a bewitched unit's head."""
    a = Art()
    a.raw('<defs><radialGradient id="sg"><stop offset="0" stop-color="#ff6ad5" stop-opacity="0.7"/><stop offset="1" stop-color="#ff6ad5" stop-opacity="0"/></radialGradient></defs>', [(0, 0)])
    a.ellipse(0, 0, 14, 12, "url(#sg)")
    for (x, y) in [(-8, -6), (7, -8), (9, 3), (-9, 4)]:
        a.ellipse(x, y, 1.3, 1.3, "#ffd0f0")
    a.save("spell_glow")


def corpse_skeleton():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    for (x0, y0, x1, y1) in [(-14, 2, -4, -2), (-2, 4, 9, 1), (4, -4, 14, -1), (-10, -3, -1, -6)]:
        a.line([(x0, y0), (x1, y1)], INK, 3.4)
        a.line([(x0, y0), (x1, y1)], BONE, 1.8)
        for (x, y) in ((x0, y0), (x1, y1)):
            a.ellipse(x, y, 1.6, 1.3, BONE, INK, 0.8)
    a.ellipse(12, -5, 5.5, 5, BONE, INK, 1.2)  # skull
    a.ellipse(10.5, -5.5, 1.4, 1.5, "#1a1612")
    a.ellipse(13.5, -5.5, 1.4, 1.5, "#1a1612")
    a.save("corpse_skeleton")


def corpse_goblin():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.ellipse(0, 1, 14, 4, "#3a1a14", opacity=0.55)  # dark stain
    a.poly([(-12, -2), (6, -6), (9, -1), (-10, 3)], "#4a3a2a")  # tunic, lying down
    a.line([(-12, 0), (-19, 2)], INK, 4.5)
    a.line([(-12, 0), (-19, 2)], "#4a6029", 2.6)
    a.ellipse(12, -3, 6, 5, "#56702f", INK, 1.2)  # head
    a.poly([(15, -6), (22, -9), (17, -3)], "#56702f")  # ear
    a.line([(10, -4.5), (12, -2.5)], INK, 1.2)
    a.line([(12, -4.5), (10, -2.5)], INK, 1.2)
    a.line([(-2, 4), (-12, 8)], INK, 2.8)
    a.line([(-2, 4), (-12, 8)], "#43301e", 1.4)
    a.poly([(-12, 5), (-18, 8), (-15, 11), (-10, 8)], "#6d6a64")  # dropped cleaver
    a.save("corpse_goblin")


def goblin():
    a = Art()
    a.shadow(11, 4.5, opacity=0.4)
    skin, skin_d = "#5f7a36", "#4a6029"
    a.line([(-3, -1), (-4, -9)], INK, 5)
    a.line([(3, -1), (4, -9)], INK, 5)
    a.line([(-3, -1.5), (-4, -9)], skin_d, 3)
    a.line([(3, -1.5), (4, -9)], skin_d, 3)
    a.poly([(-8, -8), (7, -8), (8, -22), (-5, -24)], "#4a3a2a")
    a.line([(-8, -12), (7, -12)], "#2a1e14", 1.6)
    # cleaver
    a.line([(5, -14), (12, -24)], INK, 3.4)
    a.line([(5, -14), (12, -24)], WOOD_D, 1.8)
    a.poly([(10, -30), (17, -26), (13, -20), (9, -24)], "#7d7a74")
    a.poly([(10, -30), (17, -26), (16, -25)], "#8c2a1c", stroke=None, opacity=0.8)
    # head with ears
    a.poly([(-14, -28), (-5, -27), (-6, -23)], skin)
    a.poly([(12, -30), (4, -28), (5, -24)], skin)
    a.ellipse(0, -27, 7.5, 6.5, skin, INK, 1.3)
    a.ellipse(-2, -28, 1.6, 1.3, "#ff3b2a")
    a.ellipse(3.5, -28, 1.6, 1.3, "#ff3b2a")
    a.line([(-2, -23.5), (4, -23.5)], INK, 1.2)
    a.poly([(-0.5, -23.5), (0.5, -21), (1.5, -23.5)], "#e8e0c8", INK, 0.6)
    a.raw('<path d="M-7,-30 Q-4,-38 2,-37 Q7,-36 7,-30 Q0,-33 -7,-30Z" fill="#3b3b3b" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -39), (8, -29)])
    a.save("unit_goblin")


def thief():
    """Lean, hooded figure in dark green with a dagger and a face mask."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-6, -24), (-11, -14)], INK, 3.6)  # back arm
            a.line([(-6, -24), (-11, -14)], "#233a20", 2.2)
        else:
            a.poly([(-4.5, -31), (6, -31), (5.5, -28), (-4, -28)], "#141a12", INK, 0.8)  # mask
            a.line([(4, -21), (11, -17)], INK, 3.6)  # dagger arm, low and forward
            a.line([(4, -21), (11, -17)], "#2e4a2a", 2.2)
            a.line([(10, -16.5), (12, -19.5)], INK, 2.2)  # guard
            a.poly([(11, -18.5), (13, -17), (20, -23), (19.5, -24)], "#c8ccd4", INK, 0.9)  # blade
            a.poly([(-8, -14), (-2, -14), (-3, -9), (-8, -10)], "#6a5230", INK, 0.9)  # belt pouch
    person("unit_thief", ("#2e4a2a", "#233a20"), hood="#1f3320", skin="#c8a080", extra=extra)


def gargoyle(frame):
    """Grey stone gargoyle with horns and bat wings, flying (no shadow: the
    game draws it on the ground). Two frames: wings up / wings down."""
    a = Art()
    stone, stone_d, stone_l = "#7c7f86", "#5d6068", "#a2a6ae"
    if frame == 0:  # wings up
        wing_l = [(-5, -26), (-24, -46), (-20, -38), (-28, -36), (-21, -30), (-26, -24), (-8, -20)]
        wing_r = [(5, -26), (24, -46), (20, -38), (28, -36), (21, -30), (26, -24), (8, -20)]
    else:  # wings down
        wing_l = [(-5, -24), (-26, -20), (-21, -16), (-27, -11), (-19, -10), (-21, -4), (-7, -16)]
        wing_r = [(5, -24), (26, -20), (21, -16), (27, -11), (19, -10), (21, -4), (7, -16)]
    a.poly(wing_l, stone_d, INK, 1.3)
    a.poly(wing_r, stone_d, INK, 1.3)
    a.line([wing_l[0], wing_l[1]], stone_l, 1.4)
    a.line([wing_r[0], wing_r[1]], stone_l, 1.4)
    # hunched body and tucked legs with claws
    a.poly([(-7, -12), (7, -12), (9, -26), (-9, -26)], stone, INK, 1.4)
    a.poly([(0, -12), (7, -12), (9, -26), (0, -26)], stone_d, stroke=None, opacity=0.6)
    a.line([(-4, -12), (-6, -6)], INK, 4.2)
    a.line([(4, -12), (6, -6)], INK, 4.2)
    a.line([(-4, -12), (-6, -6)], stone, 2.6)
    a.line([(4, -12), (6, -6)], stone, 2.6)
    a.line([(-8, -5), (-4, -6)], INK, 1.6)
    a.line([(4, -6), (8, -5)], INK, 1.6)
    a.poly([(1, -10), (-2, -3), (4, -1), (2, -3)], stone_d, INK, 1)  # tail
    # head: horns, heavy brow, glowing eyes, fangs
    a.poly([(-5, -34), (-9, -41), (-3, -36)], stone_l, INK, 1)
    a.poly([(5, -34), (9, -41), (3, -36)], stone_l, INK, 1)
    a.ellipse(0, -31, 6.5, 5.5, stone, INK, 1.3)
    a.line([(-5, -33), (5, -33)], INK, 1.6)
    a.ellipse(-2.3, -31.5, 1.3, 1, "#ffb02a")
    a.ellipse(2.3, -31.5, 1.3, 1, "#ffb02a")
    a.poly([(-2, -27.5), (-1, -25), (0, -27.5)], "#e8e4dc", INK, 0.5)
    a.poly([(0.5, -27.5), (1.5, -25), (2.5, -27.5)], "#e8e4dc", INK, 0.5)
    a.save("unit_gargoyle" if frame == 0 else "unit_gargoyle_flap", fixed=(-31, -50, 31, 3))


def vulture(frame):
    """A vulture in flight: dark brown plumage, broad wings with spread finger
    feathers, a white ruff, bald red head, hooked pale beak (the game draws
    the shadow). Two frames: wings up / wings down."""
    a = Art()
    dark, mid, light = "#3a2a20", "#5a4232", "#7a5a44"
    if frame == 0:  # wings up, wide
        l = [(-5, -26), (-16, -38), (-28, -42), (-31, -39), (-33, -35), (-30, -33), (-31, -29), (-26, -28), (-18, -26), (-8, -21)]
    else:  # wings down
        l = [(-5, -24), (-16, -20), (-27, -14), (-30, -10), (-31, -6), (-27, -6), (-26, -2), (-21, -5), (-14, -12), (-7, -18)]
    r = [(-x, y) for x, y in l]
    for pts in (l, r):
        a.poly(pts, dark, INK, 1.3)
        a.line([pts[0], pts[3]], mid, 1.8)  # the wing's leading edge
        for i in (4, 6):  # finger feathers
            a.line([pts[i - 1], pts[i]], light, 0.9)
    a.poly([(-6, -28), (6, -28), (4, -14), (0, -11), (-4, -14)], mid, INK, 1.3)  # body
    a.poly([(-3, -14), (3, -14), (0, -8)], dark, INK, 1)  # tail
    a.ellipse(0, -28, 5.5, 2.6, "#e8e0d0", INK, 0.9)  # white ruff
    a.ellipse(0, -32.5, 3.6, 3.3, "#c86a5a", INK, 1.1)  # bald head
    a.poly([(1.5, -32), (5.5, -31), (4, -28.5), (2, -30)], "#e0d4a8", INK, 0.8)  # hooked beak
    a.ellipse(-0.6, -33.4, 0.8, 0.8, "#1a0f0a")
    a.save("unit_vulture" if frame == 0 else "unit_vulture_flap", fixed=(-34, -50, 34, 3))


def ghost():
    """A restless spirit: a pale blue-white shroud trailing into wisps instead of
    legs, long hanging arms, a hollow hooded face with two cold eyes. No ground
    shadow: it hovers (the game bobs it over a shadow of its own, and draws it
    faded unless something lights it)."""
    a = Art()
    pale, mid, deep = "#dfe9f2", "#b4c6d8", "#7f95ae"
    # the trailing wisps below the shroud
    a.poly([(-8, -14), (-10, -6), (-6, -9), (-4, -2), (-1, -8), (2, -1), (5, -9), (9, -5), (8, -14)], mid, INK, 1.1)
    # the shroud
    a.poly([(-9, -14), (-7, -30), (-3, -36), (3, -36), (7, -30), (9, -14)], pale, INK, 1.3)
    a.poly([(-9, -14), (-7, -30), (-4, -33), (-5, -14)], mid, stroke=None, opacity=0.7)
    # long hanging arms with ragged sleeves
    a.poly([(-8, -29), (-15, -22), (-17, -12), (-14, -15), (-12, -9), (-10, -16), (-7, -22)], mid, INK, 1.1)
    a.poly([(8, -29), (15, -22), (17, -12), (14, -15), (12, -9), (10, -16), (7, -22)], mid, INK, 1.1)
    # the hood and its hollow face
    a.poly([(-7, -30), (-5, -40), (0, -43), (5, -40), (7, -30), (0, -33)], pale, INK, 1.3)
    a.ellipse(0, -35, 4.6, 5.4, deep, INK, 1.0)
    a.ellipse(-1.9, -35.5, 1.3, 1.9, "#bff4ff")
    a.ellipse(1.9, -35.5, 1.3, 1.9, "#bff4ff")
    a.ellipse(0, -31.3, 1.4, 2.0, "#2a3a4c")
    a.save("unit_ghost")


def vulture_landed():
    """A vulture on the ground, eating: hunched, wings half folded, bald red
    head down at its meal."""
    a = Art()
    dark, mid = "#3a2a20", "#5a4232"
    a.poly([(-13, -10), (-7, -24), (-2, -20), (-4, -8)], dark, INK, 1.3)  # wing, half folded
    a.poly([(13, -10), (7, -24), (2, -20), (4, -8)], dark, INK, 1.3)
    a.poly([(-7, -22), (6, -22), (8, -9), (0, -5), (-8, -9)], mid, INK, 1.4)  # body
    a.poly([(-3, -7), (3, -7), (0, -1)], dark, INK, 1)  # tail
    a.line([(-3, -6), (-4, 0)], INK, 1.6)  # legs
    a.line([(3, -6), (4, 0)], INK, 1.6)
    a.ellipse(5, -20, 4.5, 2.4, "#e8e0d0", INK, 0.9)  # ruff
    a.line([(6, -20), (10, -14)], "#c86a5a", 2.6)  # neck bent down
    a.ellipse(11, -12.5, 3.2, 2.8, "#c86a5a", INK, 1.1)  # bald head
    a.poly([(12.5, -11.5), (15.5, -9.5), (13.5, -8.5), (12, -10)], "#e0d4a8", INK, 0.8)  # beak
    a.ellipse(10.6, -13.4, 0.7, 0.7, "#1a0f0a")
    a.save("unit_vulture_landed", fixed=(-34, -50, 34, 3))


def corpse_vulture():
    a = Art()
    a.ellipse(0, 0, 18, 5.5, "#000", opacity=0.3)
    a.poly([(-17, -1), (-6, -5), (-2, 1), (-14, 4)], "#3a2a20", INK, 1.1)  # spread wing
    a.poly([(15, -1), (4, -5), (1, 1), (12, 4)], "#3a2a20", INK, 1.1)
    a.ellipse(0, -1, 6, 3.6, "#5a4232", INK, 1.1)  # body
    a.ellipse(7, -4, 3, 2.4, "#c86a5a", INK, 1)  # head
    a.poly([(9, -4), (12, -3), (9.5, -2.5)], "#e0d4a8", INK, 0.7)
    for x, y in ((-10, 6), (8, 6), (-3, 7)):  # loose feathers
        a.line([(x, y), (x + 3, y - 1)], "#5a4232", 1.2)
    a.save("corpse_vulture")


def necromancer():
    """Black robe and hood, pale face, a staff with a skull and a green glow."""
    def extra(a, layer):
        if layer == "back":
            a.line([(12, -2), (12, -46)], INK, 3.4)  # staff
            a.line([(12, -2), (12, -46)], "#3a2a1a", 1.8)
            a.ellipse(12, -49, 6.5, 6.5, "#6aff8a", opacity=0.3)  # glow
            a.ellipse(12, -49, 4, 3.6, "#e8e4d8", INK, 1)  # skull
            a.ellipse(10.6, -49.4, 1.1, 1.1, "#1a3a1a")
            a.ellipse(13.4, -49.4, 1.1, 1.1, "#1a3a1a")
            a.line([(10.8, -46.6), (13.2, -46.6)], INK, 0.8)
        else:
            a.poly([(-5, -24), (5, -24), (3, -20), (-3, -20)], "#2a4a2a", INK, 0.8)  # green collar
            a.line([(4, -21), (11, -30)], INK, 3.8)  # hand on the staff
            a.line([(4, -21), (11, -30)], "#15121a", 2.2)
            a.ellipse(11.5, -30.5, 1.8, 1.8, "#d8d0c8", INK, 0.8)
            a.ellipse(3, -33.5, 1, 1, "#6aff8a")  # green eye
    person("unit_necromancer", ("#1a161e", "#110e14"), hood="#15121a", robe=True, skin="#d8d0c8", extra=extra)


def corpse_thief():
    a = Art()
    a.ellipse(0, 0, 17, 5.5, "#000", opacity=0.3)
    a.ellipse(0, 1, 13, 4, "#3a1a14", opacity=0.5)
    a.poly([(-12, -2), (6, -6), (9, -1), (-10, 3)], "#2e4a2a", INK, 1.1)  # tunic
    a.ellipse(12, -3, 5.5, 4.5, "#1f3320", INK, 1.2)  # hooded head
    a.poly([(-2, 5), (-12, 8), (-11.5, 9), (-1.5, 6)], "#c8ccd4", INK, 0.8)  # dagger
    for x, y in ((-16, -2), (-18, 1), (-14, 3)):  # spilled coins
        a.ellipse(x, y, 2, 1.3, GOLD, INK, 0.7)
    a.save("corpse_thief")


def corpse_gargoyle():
    a = Art()
    a.ellipse(0, 0, 20, 6.5, "#000", opacity=0.3)
    stone, stone_d = "#7c7f86", "#5d6068"
    a.poly([(-10, -2), (4, -7), (10, -1), (-6, 4)], stone, INK, 1.2)  # body, cracked
    a.line([(-2, -4), (2, 1)], INK, 1)
    a.poly([(-18, -2), (-10, -6), (-8, 0), (-16, 4), (-13, 0)], stone_d, INK, 1.1)  # broken wing
    a.ellipse(13, -3, 5, 4, stone, INK, 1.2)  # head
    a.poly([(15, -6), (19, -10), (16, -4)], "#a2a6ae", INK, 0.8)  # horn
    for x, y, r in ((-4, 6, 2.2), (6, 5, 1.6), (18, 3, 1.8)):  # rubble
        a.ellipse(x, y, r, r * 0.7, stone_d, INK, 0.8)
    a.save("corpse_gargoyle")


def corpse_necromancer():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.poly([(-14, 0), (6, -5), (10, 2), (-10, 5)], "#1a161e", INK, 1.2)  # robe
    a.ellipse(12, -3, 5, 4.5, "#15121a", INK, 1.2)  # hood
    a.line([(-16, 7), (8, 9)], INK, 3)  # staff on the ground
    a.line([(-16, 7), (8, 9)], "#3a2a1a", 1.6)
    a.ellipse(-18, 6, 3.4, 3, "#e8e4d8", INK, 0.9)  # skull
    a.ellipse(-18, 6, 5, 4.5, "#6aff8a", opacity=0.18)
    a.save("corpse_necromancer")


def vampire():
    """Pale, black-haired, a high-collared black cape lined in red, red eyes."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-11, -30), (11, -30), (14, -2), (-14, -2)], "#7a1420", INK, 1.4)  # cape, red inside
            a.poly([(-11, -30), (-3, -30), (-6, -2), (-14, -2)], "#15111a", INK, 1.2)  # black outside
            a.poly([(11, -30), (3, -30), (6, -2), (14, -2)], "#15111a", INK, 1.2)
            a.poly([(-11, -27), (-9, -42), (-4, -30)], "#15111a", INK, 1)  # high collar, behind the head
            a.poly([(11, -27), (9, -42), (4, -30)], "#15111a", INK, 1)
        else:
            a.raw('<path d="M-6,-37 Q0,-45 6,-37 L3,-38 L0,-35 L-3,-38 Z" fill="#15111a" stroke="%s" stroke-width="1"/>' % INK, [(-7, -45), (7, -35)])  # hair, widow's peak
            a.ellipse(1.5, -33.5, 1.2, 1, "#ff3030")
            a.ellipse(4.5, -33.5, 1.0, 0.9, "#ff3030")
            a.poly([(2, -29.5), (2.6, -28), (3.2, -29.5)], "#ffffff", INK, 0.5)  # fang
            a.line([(4, -21), (11, -18)], INK, 3.6)  # clawed hand forward
            a.line([(4, -21), (11, -18)], "#2a2030", 2.2)
            a.ellipse(12, -17.5, 1.8, 1.8, "#e8e0e4", INK, 0.8)
    person("unit_vampire", ("#2a2030", "#1e1724"), skin="#e8e0e4", extra=extra)


def vampire_bat(frame):
    """The vampire as a big bat: black body, wide wings with a dark red skin
    between the fingers, pointed ears, red eyes. Flies (the game draws the
    shadow). Not grey stone like the gargoyle, and no horns."""
    a = Art()
    body, wing, skin = "#1b1620", "#2a2030", "#6a1a2a"
    if frame == 0:  # wings up, spread
        l = [(-4, -26), (-14, -40), (-22, -44), (-30, -36), (-24, -32), (-26, -24), (-18, -26), (-14, -20), (-6, -22)]
    else:  # wings down
        l = [(-4, -24), (-14, -16), (-24, -12), (-30, -4), (-22, -6), (-18, 0), (-14, -8), (-8, -6), (-5, -18)]
    r = [(-x, y) for x, y in l]
    for pts in (l, r):
        a.poly(pts, skin, INK, 1.3)
        a.line([pts[0], pts[2]], wing, 2.4)  # wing bones
        a.line([pts[1], pts[4]], wing, 1.6)
        a.line([pts[1], pts[6]], wing, 1.6)
    a.ellipse(0, -22, 6, 8, body, INK, 1.4)  # body
    a.ellipse(0, -31, 5, 4.5, body, INK, 1.3)  # head
    a.poly([(-4, -33), (-6, -40), (-1.5, -34.5)], body, INK, 1)  # ears
    a.poly([(4, -33), (6, -40), (1.5, -34.5)], body, INK, 1)
    a.ellipse(-1.8, -31.5, 1.2, 1, "#ff3030")
    a.ellipse(1.8, -31.5, 1.2, 1, "#ff3030")
    a.poly([(-1.2, -28.5), (-0.6, -27), (0, -28.5)], "#ffffff", INK, 0.4)
    a.poly([(0, -28.5), (0.6, -27), (1.2, -28.5)], "#ffffff", INK, 0.4)
    a.line([(-2, -14), (-3, -11)], INK, 1.4)  # feet
    a.line([(2, -14), (3, -11)], INK, 1.4)
    a.save("unit_vampire_bat" if frame == 0 else "unit_vampire_bat_flap", fixed=(-31, -50, 31, 3))


def corpse_vampire():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.poly([(-16, -2), (8, -7), (12, 2), (-12, 6)], "#7a1420", INK, 1.2)  # spread cape
    a.poly([(-12, -1), (6, -4), (9, 1), (-9, 4)], "#2a2030", INK, 1)
    a.ellipse(12, -3, 5, 4.5, "#e8e0e4", INK, 1.2)
    a.line([(9, -6), (15, -6)], "#15111a", 2.2)  # hair
    a.ellipse(-18, 5, 4, 2.5, "#4a1018", opacity=0.6)  # dark stain
    a.save("corpse_vampire")


def slimes():
    """Slimes, 3 sizes (level 3 biggest) x 5 pastel colours: unit_slime<level>_<colour>.
    unit_slime<level> is the green one (the library's and the debug menu's picture)."""
    colours = {  # body, darker underside, outline-side shade
        "red": ("#f6a8a4", "#e2827e"),
        "blue": ("#a9c9f2", "#7fa6d8"),
        "yellow": ("#f7e59a", "#dcc46c"),
        "green": ("#b6e8a8", "#88c97a"),
        "pink": ("#f6b9e2", "#dc92c4"),
    }
    for level, r in ((1, 8.5), (2, 12.5), (3, 18.0)):
        h = r * 1.05
        sw = 1.1 if level == 1 else 1.3
        for name, (body, under) in colours.items():
            a = Art()
            a.shadow(r * 1.1, r * 0.4, opacity=0.3)
            d = ("M%s,0 C%s,%s %s,%s 0,%s C%s,%s %s,%s %s,0 Q0,%s %s,0 Z"
                 % (fmt(-r), fmt(-r), fmt(-h * 0.85), fmt(-r * 0.6), fmt(-h * 1.3), fmt(-h * 1.3),
                    fmt(r * 0.6), fmt(-h * 1.3), fmt(r), fmt(-h * 0.85), fmt(r), fmt(r * 0.22), fmt(-r)))
            a.raw('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (d, body, INK, sw),
                  [(-r, -h * 1.3), (r, r * 0.12)])
            a.ellipse(0, -h * 0.18, r * 0.78, h * 0.2, under, opacity=0.7)
            a.ellipse(-r * 0.42, -h * 0.92, r * 0.24, h * 0.14, "#ffffff", opacity=0.75)
            a.ellipse(-r * 0.62, -h * 0.6, r * 0.08, h * 0.08, "#ffffff", opacity=0.6)
            for ex in (r * 0.12, r * 0.52):
                a.ellipse(ex, -h * 0.62, r * 0.12, h * 0.15, INK)
                a.ellipse(ex - r * 0.03, -h * 0.67, r * 0.04, h * 0.05, "#ffffff")
            a.line([(r * 0.2, -h * 0.36), (r * 0.32, -h * 0.3), (r * 0.44, -h * 0.36)], INK, 0.9 if level == 1 else 1.1)
            a.save("unit_slime%d_%s" % (level, name))
            if name == "green":
                a.save("unit_slime%d" % level)


def rat():
    """A small grey-brown rat, side view, facing right (the game flips it)."""
    a = Art()
    a.shadow(9, 3, opacity=0.35)
    fur, fur_d, pink = "#6e6258", "#4e443c", "#c98a8a"
    # tail
    a.raw('<path d="M-7,-4 Q-15,-3 -17,-9 Q-18,-13 -14,-14" fill="none" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>' % INK, [(-18, -15), (-6, -2)])
    a.raw('<path d="M-7,-4 Q-15,-3 -17,-9 Q-18,-13 -14,-14" fill="none" stroke="%s" stroke-width="1.3" stroke-linecap="round"/>' % pink, [(-18, -15), (-6, -2)])
    # feet
    for x in (-4, 4):
        a.line([(x, -3), (x + 1, 0)], INK, 2.6)
        a.line([(x, -3), (x + 1, 0)], pink, 1.2)
    # body and head
    a.ellipse(-1, -7, 8.5, 5.2, fur, INK, 1.3)
    a.ellipse(-2, -9, 5, 2.2, "#857a70", opacity=0.6)
    a.poly([(5, -11), (13, -7), (11, -4), (4, -4)], fur, INK, 1.2)
    a.ellipse(4.5, -11, 2.6, 2.4, fur_d, INK, 1.1)  # ear
    a.ellipse(4.6, -11, 1.3, 1.2, pink)
    a.ellipse(9, -8.2, 1.1, 1.0, "#ff3b2a")  # eye
    a.ellipse(13, -6.4, 1.2, 1.0, "#e0a0a0", INK, 0.7)  # nose
    a.line([(12, -6), (16, -7.5)], "#d8d0c8", 0.6)
    a.line([(12, -5.5), (16, -4.5)], "#d8d0c8", 0.6)
    a.save("unit_rat")


# ---------------------------------------------------------------- spiders (docs/enemies-design.md §10.9)

def _spider_leg(a, hip, knee, foot, color, sw):
    a.line([hip, knee, foot], INK, sw + 1.6)
    a.line([hip, knee, foot], color, sw)


def spider_mother():
    """A huge dark spider, side view, facing right: a bloated abdomen with a red
    hourglass and a cluster of pale eggs underneath, eight jointed legs, red eyes."""
    a = Art()
    a.shadow(26, 8, opacity=0.45)
    chitin, chitin_l, far = "#2e2433", "#4b3c55", "#1f1824"
    # far-side legs (darker, behind the body)
    for hx, kx, kz, fx in ((2, -20, -30, -34), (5, -8, -33, -18), (9, 16, -33, 14), (12, 28, -29, 36)):
        _spider_leg(a, (hx, -16), (kx, kz), (fx, -2), far, 1.6)
    # abdomen: bloated, with a lighter back and a red hourglass
    a.ellipse(-11, -21, 16, 13, chitin, INK, 1.5)
    a.ellipse(-13, -26, 10, 5.5, chitin_l, opacity=0.7)
    a.poly([(-15, -28), (-9, -28), (-12, -23.5)], "#b3302a", INK, 0.8)
    a.poly([(-15, -19), (-9, -19), (-12, -23.5)], "#b3302a", INK, 0.8)
    for sx in (-22, -18, -4, -1):  # bristles
        a.line([(sx, -31 + abs(sx + 11) * 0.35), (sx - 1.5, -35 + abs(sx + 11) * 0.35)], INK, 1.0)
    # pale eggs clinging under the abdomen
    for ex, ey in ((-18, -9), (-13, -8), (-8, -9), (-15.5, -11.5), (-10.5, -11.5)):
        a.ellipse(ex, ey, 2.8, 2.4, "#e7dfc6", INK, 0.8)
    # cephalothorax and head
    a.ellipse(8, -17, 9.5, 7.5, chitin, INK, 1.4)
    a.ellipse(7, -20.5, 6, 3, chitin_l, opacity=0.6)
    a.ellipse(16, -15, 5, 4.5, chitin, INK, 1.2)
    # fangs
    a.poly([(18, -12), (21, -11), (19, -6)], "#d8cfb8", INK, 0.8)
    a.poly([(15.5, -11.5), (18, -11), (16.5, -6.5)], "#d8cfb8", INK, 0.8)
    # a cluster of red eyes
    for ex, ey, r in ((17.5, -17.5, 1.5), (19.5, -16, 1.2), (15.5, -18.5, 1.1), (18, -19.8, 0.9), (20.5, -18.3, 0.8)):
        a.ellipse(ex, ey, r, r, "#ff3a2a")
    a.ellipse(17.2, -17.9, 0.5, 0.5, "#ffd0c0")
    # near-side legs
    for hx, kx, kz, fx in ((3, -22, -32, -37), (6, -6, -35, -21), (10, 19, -35, 18), (13, 31, -30, 40)):
        _spider_leg(a, (hx, -14), (kx, kz), (fx, 0), chitin, 2.0)
        a.ellipse(kx, kz, 1.4, 1.4, chitin_l, INK, 0.8)  # knee joint
    a.save("unit_spider_mother")


def corpse_spider_mother():
    """On its back, legs curled up."""
    a = Art()
    a.ellipse(0, 0, 24, 7, "#000", opacity=0.3)
    a.ellipse(2, 2, 20, 5, "#1e2a14", opacity=0.45)  # dark ichor
    chitin = "#2e2433"
    for hx, kx, ky, fx, fy in ((-6, -14, -16, -8, -18), (-1, -6, -20, 0, -21), (5, 6, -20, 11, -18), (10, 16, -15, 19, -10)):
        _spider_leg(a, (hx, -6), (kx, ky), (fx, fy), chitin, 1.8)
    a.ellipse(-8, -4, 14, 7.5, chitin, INK, 1.4)
    a.ellipse(-8, -6, 8, 3, "#5a4a62", opacity=0.6)  # pale belly
    a.ellipse(10, -3, 7.5, 5.5, chitin, INK, 1.2)
    for ex in (-12, -7):  # crushed eggs
        a.ellipse(ex, 3, 2.6, 1.6, "#cfc6aa", INK, 0.7)
    a.save("corpse_spider_mother")


def _wrathwood_body(a, grip=False):
    """The trunk of a wrathwood, facing right: root legs, a bark body with a
    face, branch arms (raised, or plunged into the ground for a root grip) and
    an oak crown."""
    bark, bark_d, bark_l = "#5e4129", "#43301e", "#7a5738"
    moss = "#4d6b37"
    leaf = ("#203a22", "#1b331d", "#26442a", "#2e5232")
    # root legs, spread wide
    for x0, x1, x2 in ((-6, -11, -17), (6, 10, 16)):
        a.line([(x0, -18), (x1, -6), (x2, -1)], INK, 8.5)
        a.line([(x0, -18), (x1, -6), (x2, -1)], bark_d, 6)
        a.line([(x2, -1), (x2 + (-5 if x2 < 0 else 5), 1)], INK, 3.4)
        a.line([(x2, -1), (x2 + (-5 if x2 < 0 else 5), 1)], bark_d, 1.8)
    # the far arm (behind the body)
    if grip:
        a.line([(-8, -48), (-15, -30), (-14, -8), (-18, 0)], INK, 7)
        a.line([(-8, -48), (-15, -30), (-14, -8), (-18, 0)], bark_d, 4.6)
    else:
        a.line([(-8, -50), (-19, -60), (-24, -74)], INK, 7)
        a.line([(-8, -50), (-19, -60), (-24, -74)], bark_d, 4.6)
        for tx, ty in ((-30, -78), (-24, -82), (-19, -79)):
            a.line([(-24, -74), (tx, ty)], INK, 2.6)
            a.line([(-24, -74), (tx, ty)], bark_d, 1.2)
    # the trunk: wider at the roots, bark grooves, moss
    a.poly([(-11, -16), (11, -16), (9, -56), (-9, -58)], bark, INK, 1.5)
    a.poly([(1, -16), (11, -16), (9, -56), (1, -57)], bark_d, stroke=None, opacity=0.6)
    for gx, top, bot in ((-6, -54, -20), (-1.5, -56, -24), (5, -53, -19)):
        a.line([(gx, bot), (gx + 1.2, (top + bot) / 2), (gx - 0.6, top)], "#2c1f13", 1.1)
    a.ellipse(-6, -22, 4.5, 2.4, moss, opacity=0.85)
    a.ellipse(7, -46, 3, 1.8, moss, opacity=0.75)
    # the face: a heavy brow, glowing amber eyes, a hollow mouth
    a.line([(-1, -46), (9, -45)], INK, 2.6)
    a.line([(-1, -46), (9, -45)], bark_l, 1.2)
    for ex in (1.5, 7):
        a.ellipse(ex, -42.5, 1.9, 1.5, "#1a120a")
        a.ellipse(ex, -42.5, 1.1, 0.9, "#ffb340")
    a.ellipse(4.5, -35, 3, 2.2 if not grip else 3, "#1a120a", INK, 0.9)
    # the crown: oak clumps on its head
    for cx, cy, r, c in ((-12, -64, 13, leaf[0]), (10, -64, 12, leaf[1]), (-1, -76, 16, leaf[2]), (-6, -82, 8, leaf[3])):
        a.ellipse(cx, cy - (2 if grip else 0), r, r * 0.85, c, INK, 1.3)
    a.ellipse(-4, -80, 3.5, 2.6, "#3d6a42", opacity=0.8)
    # the near arm
    if grip:
        a.line([(9, -50), (20, -34), (19, -10), (23, 0)], INK, 7.5)
        a.line([(9, -50), (20, -34), (19, -10), (23, 0)], bark, 5)
    else:
        a.line([(8, -48), (19, -50), (27, -40)], INK, 7.5)
        a.line([(8, -48), (19, -50), (27, -40)], bark, 5)
        for tx, ty in ((33, -42), (31, -35), (26, -33)):
            a.line([(27, -40), (tx, ty)], INK, 2.8)
            a.line([(27, -40), (tx, ty)], bark, 1.3)
        a.ellipse(20, -51, 3, 2, leaf[2], INK, 0.8)  # a twig of leaves on the arm


def wrathwood():
    """A tree woken up under the axe (side view, facing right; the game flips it),
    and its root grip: arms plunged into the ground, roots spreading round it."""
    a = Art()
    a.shadow(26, 9, opacity=0.45)
    _wrathwood_body(a)
    a.save("unit_wrathwood")
    g = Art()
    g.shadow(26, 9, opacity=0.45)
    for ang in (0.3, 1.4, 2.3, 3.5, 4.6, 5.6):  # roots spreading on the ground
        x, y = math.cos(ang) * 30, math.sin(ang) * 12
        g.line([(0, 0), (x * 0.5, y * 0.5 + 1), (x, y)], INK, 3.6)
        g.line([(0, 0), (x * 0.5, y * 0.5 + 1), (x, y)], "#6b4a2c", 2)
    _wrathwood_body(g, grip=True)
    g.pts = a.pts[:] + g.pts  # (one canvas, so the two line up)
    g.save("unit_wrathwood_grip")


def corpse_wrathwood():
    """A felled wrathwood: a log of living wood with its crown spilled out."""
    a = Art()
    a.ellipse(0, 1, 30, 8, "#000", opacity=0.3)
    for cx, cy, r, c in ((22, -6, 9, "#1b331d"), (28, -1, 7, "#203a22"), (17, 1, 6, "#26442a")):
        a.ellipse(cx, cy, r, r * 0.7, c, INK, 1.1)
    a.poly([(-24, -9), (14, -12), (16, -1), (-22, 3)], "#5e4129", INK, 1.4)
    a.poly([(-23, -3), (15, -6), (16, -1), (-22, 3)], "#43301e", stroke=None, opacity=0.7)
    for gx in (-15, -6, 3, 10):
        a.line([(gx, -10), (gx + 2, -3)], "#2c1f13", 1.0)
    a.ellipse(-23, -3, 3.5, 6, "#c9a878", INK, 1.2)  # the cut end, with its rings
    a.ellipse(-23, -3, 2, 3.6, "#a8865a", opacity=0.8)
    a.ellipse(-23, -3, 0.8, 1.4, "#7a5738")
    a.ellipse(-2, -7, 1.3, 1.0, "#1a120a")  # its eyes, gone dark
    a.ellipse(4, -7.5, 1.3, 1.0, "#1a120a")
    a.line([(-8, 2), (-14, 7)], INK, 3)  # a broken branch
    a.line([(-8, 2), (-14, 7)], "#43301e", 1.6)
    a.ellipse(-10, -10, 3.5, 1.6, "#4d6b37", opacity=0.85)
    a.save("corpse_wrathwood")


def spiderling():
    """A small brown spider, side view, facing right (the game flips it)."""
    a = Art()
    a.shadow(10, 3, opacity=0.35)
    body, body_l, far = "#5a4232", "#7c6048", "#3e2e22"
    for hx, kx, kz, fx in ((-1, -8, -10, -12), (1, -3, -11, -6), (3, 7, -11, 7), (4, 11, -9, 13)):
        _spider_leg(a, (hx, -5), (kx, kz), (fx, -1), far, 0.7)
    a.ellipse(-4, -7, 6.5, 5.2, body, INK, 1.1)
    a.ellipse(-5, -8.5, 3, 1.6, body_l, opacity=0.7)
    a.ellipse(-4, -6.8, 1.0, 1.4, "#c9a24a", opacity=0.85)  # a little gold spot
    a.ellipse(3, -5, 3.4, 2.8, body, INK, 1.0)
    a.ellipse(4.8, -5.6, 0.8, 0.8, "#ff3a2a")
    a.ellipse(3.6, -6.2, 0.6, 0.6, "#ff3a2a")
    for hx, kx, kz, fx in ((-1, -9, -11, -13), (1, -4, -12, -7), (3, 8, -12, 8), (4, 12, -10, 15)):
        _spider_leg(a, (hx, -4), (kx, kz), (fx, 0), body, 0.8)
    a.save("unit_spiderling")


def spider_eggs():
    """One spider egg (pale, veined, glistening) and the broken shell it leaves."""
    shell, shell_d, vein = "#e9e1c8", "#c9bf9f", "#9fb08a"
    a = Art()
    a.shadow(6.5, 2.4, opacity=0.35)
    a.ellipse(0, -6.5, 5.2, 6.5, shell, INK, 1.1)
    a.ellipse(1.5, -4.5, 3.2, 3.6, shell_d, opacity=0.55)
    a.raw('<path d="M-2,-11 Q-3.5,-7 -1.5,-3" fill="none" stroke="%s" stroke-width="0.8"/>' % vein, [(-4, -11), (-1, -3)])
    a.raw('<path d="M2,-10 Q3.5,-7 2,-4.5" fill="none" stroke="%s" stroke-width="0.7"/>' % vein, [(1, -10), (4, -4)])
    a.ellipse(-2, -9.5, 1.4, 1.0, "#ffffff", opacity=0.8)
    a.save("unit_spider_egg")
    b = Art()
    b.shadow(6.5, 2.4, opacity=0.3)
    # the lower half, a jagged rim, and the dark inside
    b.poly([(-5.2, -5.5), (-3.5, -7.5), (-2, -5.8), (0, -8.2), (1.8, -6), (3.6, -7.8), (5.2, -5.5),
            (4.6, -2.2), (2.5, -0.4), (-2.5, -0.4), (-4.6, -2.2)], shell, INK, 1.1)
    b.ellipse(0, -5.6, 4.0, 1.4, "#4a4030", opacity=0.75)
    b.ellipse(1.5, -2.6, 2.6, 1.6, shell_d, opacity=0.55)
    # a few fragments beside it
    b.poly([(-9, -1), (-7, -3), (-6, -0.5)], shell, INK, 0.8)
    b.poly([(7, -0.5), (9.5, -2), (9.8, 0.3)], shell, INK, 0.8)
    b.poly([(5.5, 1.5), (7, 0.8), (7.2, 2.2)], shell_d, INK, 0.6)
    b.save("unit_spider_egg_shell")


# ---------------------------------------------------------------- water monsters (docs/aquatic-design.md)

def _waterline(a, rx, ry, cy=0.0):
    """Where a monster comes out of the water: a dark ring and a light rim."""
    a.ellipse(0, cy, rx, ry, "#1d3a52", opacity=0.55)
    a.ellipse(0, cy, rx, ry, "none", "#cfe6f5", 1.4, opacity=0.8)
    a.ellipse(0, cy, rx * 0.7, ry * 0.65, "none", "#9cc6e2", 1.0, opacity=0.6)


def crab():
    """A big red-orange crab, side-on, claws raised, eyes on stalks."""
    a = Art()
    a.shadow(14, 4.5, opacity=0.4)
    shell, shell_d, shell_l = "#c2512e", "#8e3418", "#e07a4e"
    for x0, x1 in ((-10, -15), (-6, -10), (6, 10), (10, 15)):  # legs
        a.line([(x0, -6), (x1, -3), (x1 + (1 if x1 > 0 else -1), 0)], INK, 2.8)
        a.line([(x0, -6), (x1, -3), (x1 + (1 if x1 > 0 else -1), 0)], shell_d, 1.4)
    a.ellipse(0, -9, 13, 6.5, shell, INK, 1.4)  # shell
    a.ellipse(-2, -11, 8, 3, shell_l, opacity=0.7)
    a.ellipse(4, -6, 9, 2.4, shell_d, opacity=0.5)
    for sx in (-1, 1):  # claws
        a.line([(sx * 10, -11), (sx * 15, -18)], INK, 3.4)
        a.line([(sx * 10, -11), (sx * 15, -18)], shell_d, 2)
        a.raw('<path d="M%s,-18 Q%s,-28 %s,-26 L%s,-21 Q%s,-23 %s,-19 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>'
              % (fmt(sx * 13), fmt(sx * 16), fmt(sx * 22), fmt(sx * 18), fmt(sx * 20), fmt(sx * 17), shell, INK), [(-23, -29), (23, -17)])
    for ex in (-3, 3):  # eye stalks
        a.line([(ex, -14), (ex, -19)], INK, 2)
        a.ellipse(ex, -20, 1.8, 1.8, "#15110d")
        a.ellipse(ex - 0.5, -20.5, 0.6, 0.6, "#ffffff")
    a.save("unit_crab")


def corpse_crab():
    a = Art()
    a.ellipse(0, 0, 16, 5, "#000", opacity=0.3)
    a.ellipse(0, -3, 12, 5.5, "#8e3418", INK, 1.3)  # on its back
    a.ellipse(0, -4, 8, 3, "#e8b090", opacity=0.6)
    for x0, x1, y1 in ((-8, -13, -10), (-4, -6, -12), (4, 6, -12), (8, 13, -10)):
        a.line([(x0, -5), (x1, y1)], INK, 2.4)
        a.line([(x0, -5), (x1, y1)], "#c2512e", 1.2)
    a.poly([(12, -2), (20, -6), (19, 0)], "#c2512e", INK, 1)  # a claw lying apart
    a.save("corpse_crab")


def leviathan():
    """A sea serpent up out of the water: two coils and a crested head, dark
    teal scales, pale belly, glowing yellow eyes."""
    a = Art()
    _waterline(a, 34, 11)
    scale, scale_d, belly = "#1f5b5c", "#123c3e", "#9ec9a8"
    for cx, w, h in ((-22, 9, 10), (-6, 10, 13)):  # coils behind the neck
        a.raw('<path d="M%s,2 Q%s,%s %s,2 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (fmt(cx - w), fmt(cx), fmt(-h * 2), fmt(cx + w), scale, INK),
              [(cx - w, -h * 2), (cx + w, 2)])
        a.raw('<path d="M%s,1 Q%s,%s %s,1" fill="none" stroke="%s" stroke-width="2"/>' % (fmt(cx - w * 0.6), fmt(cx), fmt(-h * 1.5), fmt(cx + w * 0.6), scale_d),
              [(cx - w, -h * 2), (cx + w, 2)])
    # neck rising to the head
    a.raw('<path d="M6,3 Q4,-30 16,-52 L28,-48 Q20,-28 22,3 Z" fill="%s" stroke="%s" stroke-width="1.5" stroke-linejoin="round"/>' % (scale, INK), [(4, -53), (28, 3)])
    a.raw('<path d="M18,2 Q16,-26 25,-46" fill="none" stroke="%s" stroke-width="3"/>' % belly, [(16, -47), (26, 3)])
    for y in (-10, -22, -34):  # scale rows
        a.line([(8, y), (19, y - 3)], scale_d, 1.2)
    # crest
    a.poly([(12, -46), (6, -62), (16, -54), (14, -68), (22, -56), (24, -66), (27, -52)], "#7a2a3a", INK, 1.2)
    # head
    a.raw('<path d="M14,-56 Q22,-64 34,-58 L44,-52 Q40,-46 30,-46 Q20,-44 14,-50 Z" fill="%s" stroke="%s" stroke-width="1.5" stroke-linejoin="round"/>' % (scale, INK), [(14, -65), (44, -44)])
    a.line([(32, -49), (43, -51)], INK, 1.2)  # jaw
    a.poly([(34, -49), (35, -46), (36, -49)], "#ffffff", INK, 0.5)  # fangs
    a.poly([(39, -50), (40, -47.5), (41, -50)], "#ffffff", INK, 0.5)
    a.ellipse(28, -56, 2.4, 1.8, "#f2e04a", INK, 0.8)
    a.ellipse(28.5, -56, 0.8, 1.4, INK)
    a.ellipse(28, -56, 5, 4, "#f2e04a", opacity=0.25)
    for x, y in ((-30, -2), (32, 0), (-14, 4)):  # foam
        a.ellipse(x, y, 3, 1.2, "#e8f4fb", opacity=0.8)
    a.save("unit_leviathan")


def corpse_leviathan():
    a = Art()
    a.ellipse(0, 0, 30, 9, "#1d3a52", opacity=0.45)
    a.raw('<path d="M-26,0 Q-14,-10 -2,-2 Q10,6 22,-4 L26,-1 Q12,10 -2,3 Q-14,-4 -24,4 Z" fill="#1f5b5c" stroke="%s" stroke-width="1.3"/>' % INK, [(-27, -10), (27, 8)])
    a.raw('<path d="M-22,1 Q-12,-6 -2,0 Q10,6 22,-2" fill="none" stroke="#9ec9a8" stroke-width="1.6"/>', [(-22, -6), (22, 6)])
    a.ellipse(26, -3, 6, 3.5, "#1f5b5c", INK, 1.2)
    a.line([(24, -5), (28, -2)], INK, 1)
    a.line([(28, -5), (24, -2)], INK, 1)
    a.save("corpse_leviathan")


def siren():
    """A siren rising from the water on a scaled tail: long sea-green hair,
    pale skin, a shell on her breast, arms spread as she sings."""
    a = Art()
    _waterline(a, 14, 5)
    tail, tail_d, hair = "#2f7f7a", "#1f5a57", "#3fae96"
    a.raw('<path d="M-8,2 Q-10,-14 -5,-24 L6,-24 Q10,-12 7,2 Z" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (tail, INK), [(-10, -25), (10, 2)])
    for y in (-4, -10, -16):
        a.raw('<path d="M-6,%s Q-3,%s 0,%s Q3,%s 6,%s" fill="none" stroke="%s" stroke-width="1"/>' % (fmt(y), fmt(y - 2), fmt(y), fmt(y - 2), fmt(y), tail_d), [(-6, y - 2), (6, y)])
    a.poly([(-14, 3), (-8, -2), (-6, 3)], tail_d, INK, 1)  # fin tips in the water
    a.raw('<path d="M-7,-30 Q-12,-18 -9,-10 L-5,-12 Q-7,-20 -4,-28 Z" fill="%s" stroke="%s" stroke-width="1"/>' % (hair, INK), [(-12, -31), (-4, -10)])
    a.poly([(-6, -24), (6, -24), (5, -31), (-5, -31)], "#e8d8cc", INK, 1.2)  # body
    a.ellipse(0, -27, 2.5, 2, "#e8b8c8", INK, 0.8)  # shell
    a.line([(-5, -29), (-13, -36)], INK, 3.4)  # arms spread
    a.line([(-5, -29), (-13, -36)], "#e8d8cc", 2)
    a.line([(5, -29), (13, -36)], INK, 3.4)
    a.line([(5, -29), (13, -36)], "#e8d8cc", 2)
    a.ellipse(0, -36, 5.5, 5.5, "#e8d8cc", INK, 1.3)  # head
    a.raw('<path d="M-6,-37 Q-6,-44 0,-44 Q6,-44 6,-37 Q3,-41 0,-41 Q-3,-41 -6,-37 Z" fill="%s" stroke="%s" stroke-width="1"/>' % (hair, INK), [(-7, -45), (7, -36)])
    a.ellipse(2.5, -36.5, 0.9, 0.9, INK)
    a.ellipse(3, -33.5, 1.2, 0.8, "#7a2a3a")  # singing mouth
    a.save("unit_siren")


def corpse_siren():
    a = Art()
    a.ellipse(0, 0, 18, 6, "#000", opacity=0.3)
    a.raw('<path d="M-16,2 Q-6,-4 4,0 L4,4 Q-6,2 -14,6 Z" fill="#2f7f7a" stroke="%s" stroke-width="1.2"/>' % INK, [(-17, -4), (5, 7)])
    a.poly([(-18, 1), (-14, 4), (-19, 7)], "#1f5a57", INK, 1)
    a.poly([(3, -3), (12, -4), (12, 2), (3, 3)], "#e8d8cc", INK, 1.1)
    a.ellipse(15, -2, 4.5, 4, "#e8d8cc", INK, 1.2)
    a.line([(13, -5), (20, 1)], "#3fae96", 3)  # hair
    a.save("corpse_siren")


def octopus():
    """The gigantic octopus: a huge purple-red mantle out of the water, big
    eyes, and stubs of its arms curling on the surface (the arms that reach
    are drawn by the game)."""
    a = Art()
    _waterline(a, 46, 15)
    skin, skin_d, skin_l, spot = "#8a3a5a", "#5e2238", "#b05a7a", "#d89ab0"
    for sx, h in ((-1, 1), (1, 1), (-1, 0), (1, 0)):  # arm stubs curling on the water
        x0 = sx * (16 if h else 28)
        a.raw('<path d="M%s,0 Q%s,%s %s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>'
              % (fmt(x0), fmt(x0 + sx * 12), fmt(4 - h * 2), fmt(x0 + sx * 18), fmt(-4), fmt(x0 + sx * 22), fmt(-12), fmt(x0 + sx * 16), fmt(-14), INK), [(x0 - 25, -16), (x0 + 25, 6)])
        a.raw('<path d="M%s,0 Q%s,%s %s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="4.5" stroke-linecap="round"/>'
              % (fmt(x0), fmt(x0 + sx * 12), fmt(4 - h * 2), fmt(x0 + sx * 18), fmt(-4), fmt(x0 + sx * 22), fmt(-12), fmt(x0 + sx * 16), fmt(-14), skin), [(x0 - 25, -16), (x0 + 25, 6)])
    # the mantle
    a.raw('<path d="M-24,2 Q-30,-40 -10,-62 Q0,-70 10,-62 Q30,-40 24,2 Z" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (skin, INK), [(-30, -70), (30, 2)])
    a.raw('<path d="M6,-62 Q24,-42 20,0 L24,2 Q30,-40 10,-62 Z" fill="%s"/>' % skin_d, [(6, -62), (30, 2)])
    a.raw('<path d="M-16,-50 Q-8,-62 0,-62" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round" opacity="0.7"/>' % skin_l, [(-17, -63), (1, -49)])
    for x, y, r in ((-12, -30, 2.5), (-4, -46, 2), (8, -40, 2.2), (14, -22, 1.8), (-16, -14, 2), (2, -56, 1.6)):
        a.ellipse(x, y, r, r * 0.8, spot, opacity=0.7)
    for ex in (-10, 10):  # eyes
        a.ellipse(ex, -12, 6, 5, "#f0d878", INK, 1.2)
        a.ellipse(ex, -12, 4.2, 1.6, INK)
        a.ellipse(ex - 1.5, -13.5, 1, 0.8, "#ffffff")
    a.save("unit_octopus")


def corpse_octopus():
    a = Art()
    a.ellipse(0, 0, 36, 11, "#1d3a52", opacity=0.45)
    for sx in (-1, 1):
        for k in (0, 1):
            x0 = sx * (8 + k * 8)
            a.raw('<path d="M%s,0 Q%s,%s %s,%s" fill="none" stroke="#5e2238" stroke-width="5" stroke-linecap="round"/>' % (fmt(x0), fmt(x0 + sx * 14), fmt(6 - k * 10), fmt(x0 + sx * 24), fmt(2 - k * 6)), [(x0 - 26, -10), (x0 + 26, 8)])
    a.ellipse(0, -4, 18, 9, "#8a3a5a", INK, 1.4)
    a.line([(-9, -6), (-5, -3)], INK, 1.2)
    a.line([(-5, -6), (-9, -3)], INK, 1.2)
    a.line([(5, -6), (9, -3)], INK, 1.2)
    a.line([(9, -6), (5, -3)], INK, 1.2)
    a.save("corpse_octopus")


def octopus_arm():
    """The tip of an octopus's arm where it holds its catch (the arm itself is
    drawn by the game): a curl with pale suckers."""
    a = Art()
    a.raw('<path d="M-6,-4 Q-10,-18 0,-22 Q10,-24 9,-14 Q8,-8 2,-10 Q-2,-12 1,-16" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>' % INK, [(-11, -25), (11, -2)])
    a.raw('<path d="M-6,-4 Q-10,-18 0,-22 Q10,-24 9,-14 Q8,-8 2,-10 Q-2,-12 1,-16" fill="none" stroke="#8a3a5a" stroke-width="4.5" stroke-linecap="round"/>', [(-11, -25), (11, -2)])
    for x, y in ((-7, -10), (-6, -16), (-2, -20), (4, -21)):
        a.ellipse(x, y, 1.1, 1.1, "#e0b8c8")
    a.save("unit_octopus_arm")


# ---------------------------------------------------------------- monster lairs

def lair_cave(big=False):
    rng = random.Random(700 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()

    def S(x, y):
        return (x * k, y * k)
    a.ellipse(0, 6 * k, 64 * k, 26 * k, "#000", opacity=0.25)
    left, front, right = S(-62, 6), S(4, 32), S(62, 4)
    ridge = [S(-44, -28), S(-22, -50), S(6, -58), S(30, -44), S(46, -24)]
    a.poly([left] + ridge + [right, front], "#57534c")
    a.poly([left] + ridge[:3] + [S(10, -20), front], "#77726a", stroke=None)
    a.poly([ridge[2], ridge[3], S(20, -30), S(10, -20)], "#8b877f", stroke=None, opacity=0.6)
    a.line([left] + ridge + [right], INK, 1.6)
    a.line([left, front, right], INK, 1.2)
    for _ in range(int(3 * k)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(-30, 0) * k
        a.line([(x, y), (x + rng.uniform(-14, 14) * k, y + rng.uniform(5, 10) * k)], "#403d38", 1.4)
    for _ in range(int(4 * k)):
        x, y = rng.uniform(-40, 10) * k, rng.uniform(-40, -8) * k
        a.ellipse(x, y, rng.uniform(3, 6) * k, rng.uniform(1.5, 2.5) * k, "#4a6034", opacity=0.7)
    # the mouth
    mx, my, mw, mh = -8 * k, 16 * k, 24 * k, 36 * k
    mouth = [(mx - mw, my)] + [(mx - mw * math.cos(t), my - mh * math.sin(t) * (0.9 + 0.1 * math.sin(3 * t))) for t in [j * math.pi / 10 for j in range(1, 10)]] + [(mx + mw, my + 3 * k)]
    a.poly(mouth + [(mx, my + 6 * k)], "#0c0908", INK, 1.6)
    a.poly([(mx - mw * 0.7, my - mh * 0.3), (mx - mw * 0.4, my - mh * 0.75), (mx + mw * 0.3, my - mh * 0.8), (mx + mw * 0.6, my - mh * 0.4)], "#1c1714", stroke=None, opacity=0.8)
    for (dx, dy) in [(-5, -14), (3, -15)]:  # eyes in the dark
        a.ellipse(mx + dx * k, my + dy * k, 1.4, 1.0, "#d83a2a", opacity=0.9)
    # claw marks on the right face
    for j in range(3):
        x0, y0 = (26 + 5 * j) * k, -30 * k
        a.line([(x0, y0), (x0 + 6 * k, y0 + 14 * k)], "#2a2622", 1.6 + 0.4 * k)
        a.line([(x0 + 1, y0 + 1), (x0 + 6 * k + 1, y0 + 14 * k + 1)], "#8b877f", 0.8, opacity=0.6)
    # bones in front
    for _ in range(int(4 * k + 1)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(22, 34) * k
        ang = rng.uniform(-0.5, 0.5)
        _bone(a, x - 5 * math.cos(ang), y - 2 * math.sin(ang), x + 5 * math.cos(ang), y + 2 * math.sin(ang))
    x, y = 20 * k, 24 * k
    a.ellipse(x, y, 4.5, 4, BONE, INK, 1.1)
    a.ellipse(x - 1.4, y - 0.5, 1, 1.1, "#1a1612")
    a.ellipse(x + 1.6, y - 0.5, 1, 1.1, "#1a1612")
    a.save("lair_cave_big" if big else "lair_cave")


def lair_tree():
    rng = random.Random(710)
    a = Art()
    a.ellipse(0, 4, 120, 50, "#000", opacity=0.3)
    bark, bark_l, bark_d = "#3a3028", "#4c4036", "#241e19"
    # canopy behind
    for (x, y, r, c) in [(-70, -150, 30, "#1c2619"), (60, -160, 32, "#1a2417"), (-20, -190, 34, "#1f2a1c"), (30, -196, 26, "#1c2619")]:
        a.ellipse(x, y, r, r * 0.75, c, INK, 1.3)
    # branches
    for pts in [[(-14, -120), (-44, -140), (-80, -150), (-104, -170)], [(10, -124), (40, -146), (66, -158), (94, -150)],
                [(0, -130), (-6, -172), (-20, -200)], [(4, -128), (22, -176), (34, -206)], [(-40, -140), (-50, -176)]]:
        a.line(pts, INK, 9)
        a.line(pts, bark, 6.4)
    # roots
    for pts in [[(-30, -12), (-60, 4), (-96, 18), (-116, 16)], [(28, -12), (58, 2), (96, 12), (112, 8)],
                [(-18, -4), (-36, 24), (-52, 44)], [(16, -2), (30, 26), (40, 46)], [(-4, 0), (-6, 30), (2, 52)]]:
        a.line(pts, INK, 12)
        a.line(pts, bark_l, 8.6)
        a.line([(x + 1.5, y + 1.5) for (x, y) in pts], bark_d, 2.4, opacity=0.7)
    # trunk
    trunk = [(-46, -4), (-36, -40), (-26, -80), (-22, -120), (-14, -136), (12, -138), (22, -118), (26, -80), (38, -40), (50, -2), (0, 8)]
    a.poly(trunk, bark_d, INK, 1.6)
    a.poly(trunk[:6] + [(0, -110), (-4, -40), (0, 8)], bark, stroke=None)
    a.line(trunk + [trunk[0]], INK, 1.6)
    for pts in [[(-30, -20), (-22, -70), (-18, -110)], [(18, -30), (14, -80), (10, -120)], [(-8, -60), (-10, -100)]]:
        a.line(pts, bark_d, 1.6)
    # the hollow
    a.raw('<path d="M-22,6 Q-26,-30 -8,-52 Q2,-60 12,-50 Q28,-28 22,8 Q0,14 -22,6 Z" fill="#080605" stroke="%s" stroke-width="1.6"/>' % INK, [(-26, -60), (28, 14)])
    for (x, y) in [(-5, -30), (5, -30)]:
        a.ellipse(x, y, 1.8, 1.2, "#d8c040", opacity=0.9)
    # moss, ivy, hanging vines
    for _ in range(30):
        x, y = rng.uniform(-40, 30), rng.uniform(-130, -4)
        if -24 < x < 24 and y > -54:
            continue
        a.ellipse(x, y, rng.uniform(2, 4), rng.uniform(1.4, 2.6), rng.choice(["#2e4a26", "#3a5a2c", "#28401f"]), opacity=0.95)
    for (x, y, l) in [(-80, -140, 30), (-60, -146, 22), (50, -150, 28), (80, -152, 20), (-24, -180, 24)]:
        a.line([(x, y), (x + 2, y + l * 0.5), (x - 1, y + l)], "#3a4a26", 1.4, opacity=0.9)
    for (x, y, r) in [(-66, -148, 12), (68, -164, 14), (-10, -196, 14)]:
        a.ellipse(x, y, r, r * 0.6, "#2a3a22", opacity=0.9)
    a.save("lair_tree")


def lair_ruin(big=False):
    rng = random.Random(720 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()
    sl, sr, st = "#6a675f", "#4e4b46", "#7a766e"
    moss = "#4a6030"
    # the flooded pool
    pool = [(math.cos(t) * 52 * k * rng.uniform(0.9, 1.05), math.sin(t) * 24 * k * rng.uniform(0.9, 1.05) + 2 * k) for t in [j * math.pi / 8 for j in range(16)]]
    a.poly([(x * 1.08, y * 1.1) for (x, y) in pool], "#2e3a24", stroke=None, opacity=0.8)
    a.poly(pool, "#1d3636", "#26301e", 1.4)
    a.ellipse(-8 * k, 0, 30 * k, 11 * k, "#244442", opacity=0.7)

    def column(x, y, r, h, top_jag=True):
        ry = r * 0.5
        a.poly([(x - r, y), (x - r, y - h), (x - r * 0.3, y - h - 3), (x + r * 0.4, y - h + 2), (x + r, y - h - 1), (x + r, y)], sr, INK, 1.2)
        a.poly([(x - r, y), (x - r, y - h), (x - r * 0.3, y - h - 3), (x, y - h - 1), (x, y + ry)], sl, stroke=None)
        a.ellipse(x, y - h, r * 0.8, ry * 0.6, moss, opacity=0.85)
        a.ellipse(x, y, r + 2.5, ry + 1.2, "#1d3636", "#4a6a66", 0.9, opacity=0.9)  # water line ripple
    # a broken wall with an arch at the back
    wx, wy = -14 * k, -8 * k
    ww, wh = 26 * k, 34 * k
    a.poly([(wx - ww, wy), (wx - ww, wy - wh * 0.8), (wx - ww * 0.5, wy - wh), (wx, wy - wh * 0.85), (wx + ww * 0.4, wy - wh * 0.9), (wx + ww, wy - wh * 0.5), (wx + ww, wy)], sl, INK, 1.3)
    a.raw('<path d="M%s,%s L%s,%s Q%s,%s %s,%s L%s,%s Z" fill="#141a18" stroke="%s" stroke-width="1.2"/>'
          % (fmt(wx - ww * 0.45), fmt(wy), fmt(wx - ww * 0.45), fmt(wy - wh * 0.45), fmt(wx), fmt(wy - wh * 0.85), fmt(wx + ww * 0.45), fmt(wy - wh * 0.45), fmt(wx + ww * 0.45), fmt(wy), INK),
          [(wx - ww, wy - wh), (wx + ww, wy)])
    for j in range(1, 4):
        a.line([(wx - ww, wy - wh * 0.2 * j), (wx - ww * 0.5, wy - wh * 0.2 * j)], "#4e4b46", 0.9)
        a.line([(wx + ww * 0.5, wy - wh * 0.2 * j), (wx + ww, wy - wh * 0.2 * j)], "#4e4b46", 0.9)
    for _ in range(int(8 * k)):
        a.ellipse(wx + rng.uniform(-ww, ww), wy - rng.uniform(0.2, 0.9) * wh, rng.uniform(2, 4), rng.uniform(1.4, 2.5), rng.choice(["#2e4a26", "#3a5a2c"]), opacity=0.95)
    a.line([(wx - ww, wy), (wx + ww, wy)], "#6a8a84", 1.0, opacity=0.7)
    cols = [(24, -6, 7, 26), (-34, 8, 6, 14), (12, 14, 6.5, 8)]
    if big:
        cols += [(40, 4, 6, 18), (-10, 18, 5, 5)]
    for (x, y, r, h) in sorted(cols, key=lambda c: c[1]):
        column(x * k, y * k, r * (1.3 if big else 1), h * k)
    # lily pads and a toppled drum
    for _ in range(int(3 * k)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(-6, 16) * k
        a.ellipse(x, y, 4, 2, "#3e5a2a", INK, 0.6)
    for _ in range(int(4 * k)):
        x, y = rng.uniform(-44, 44) * k, rng.uniform(-10, 18) * k
        a.line([(x - 4, y), (x + 4, y)], "#6a8a84", 0.9, opacity=0.5)
    a.save("lair_ruin_big" if big else "lair_ruin")


def lair_pit(big=False):
    rng = random.Random(730 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()
    rx, ry = 40 * k, 19 * k
    a.ellipse(0, 2, rx * 1.4, ry * 1.5, "#2a2420", opacity=0.6)
    rocks = []
    n = int(10 * k)
    for j in range(n):
        t = j * 2 * math.pi / n + rng.uniform(-0.1, 0.1)
        rocks.append((math.cos(t) * rx * 1.05, math.sin(t) * ry * 1.05, rng.uniform(6, 10) * (k ** 0.6)))
    back = [r for r in rocks if r[1] < 0]
    front = [r for r in rocks if r[1] >= 0]
    for (x, y, r) in sorted(back, key=lambda r: r[1]):
        _rock(a, rng, x, y, r, r * 0.8, "#4c4742", "#302c29", "#5c5650", sw=1.1, n=5)
    a.ellipse(0, 0, rx, ry, "#140e0a", INK, 1.4)
    _glow(a, 0, 2, rx * 0.9, ry * 0.9, "#e05a1a", 0.8)
    a.ellipse(0, 3, rx * 0.35, ry * 0.3, "#f08a24", opacity=0.7)
    a.ellipse(0, 3, rx * 0.15, ry * 0.13, "#ffd060", opacity=0.8)
    for (x, y, r) in sorted(front, key=lambda r: r[1]):
        _rock(a, rng, x, y, r, r * 0.8, "#4c4742", "#302c29", "#5c5650", sw=1.1, n=5)
    # glowing cracks in the ground around
    for j in range(int(5 * k)):
        t = rng.uniform(0.15, math.pi - 0.15)  # front half only, on the ground
        x0, y0 = math.cos(t) * rx * 1.15, math.sin(t) * ry * 1.15
        pts = [(x0, y0), (x0 * 1.12 + rng.uniform(-3, 3), y0 * 1.12 + rng.uniform(-1.5, 1.5)), (x0 * 1.25, y0 * 1.25)]
        a.line(pts, "#b8360c", 3.2, opacity=0.6)
        a.line(pts, "#f08a24", 1.2)
    # smoke
    for (x, y, r, op) in [(-4, -18, 10, 0.45), (6, -38, 14, 0.35), (-6, -62, 17, 0.25)]:
        a.ellipse(x * k, y * k, r * k, r * k * 0.8, "#6a6660", opacity=op)
    a.save("lair_pit_big" if big else "lair_pit")


def lair_crypt(big=False):
    rng = random.Random(740 + (1 if big else 0))
    k = 2.0 if big else 1.0
    a = Art()
    sand, sand_l, sand_d = "#b3a06c", "#c6b27c", "#9a8658"
    a.ellipse(0, 6 * k, 64 * k, 26 * k, "#bba671", opacity=0.5)
    # the dune
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s" stroke="%s" stroke-width="1.3"/>'
          % (fmt(-62 * k), fmt(8 * k), fmt(-40 * k), fmt(-44 * k), fmt(6 * k), fmt(-40 * k), fmt(52 * k), fmt(-36 * k), fmt(62 * k), fmt(6 * k),
             fmt(0), fmt(40 * k), fmt(-62 * k), fmt(8 * k), sand_d, INK), [(-62 * k, -44 * k), (62 * k, 30 * k)])
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s"/>'
          % (fmt(-60 * k), fmt(8 * k), fmt(-40 * k), fmt(-42 * k), fmt(6 * k), fmt(-39 * k), fmt(-6 * k), fmt(-10 * k), fmt(2 * k), fmt(26 * k),
             fmt(-30 * k), fmt(22 * k), fmt(-60 * k), fmt(8 * k), sand), [(-60 * k, -42 * k), (6 * k, 26 * k)])
    for _ in range(int(3 * k)):
        x, y = rng.uniform(-40, 40) * k, rng.uniform(-24, 10) * k
        _arc(a, x, y, rng.uniform(14, 22) * k ** 0.7, 4, sand_l, 1.2, 0.7)
    # the crypt entrance on the front of the dune
    cx, cy = -6 * k, 14 * k
    pw, ph = 26 * k, 30 * k
    sl, sr, st = "#8a847a", "#6a655d", "#9c968a"
    a.poly([(cx - pw * 0.7, cy), (cx - pw * 0.7, cy - ph), (cx + pw * 0.7, cy - ph), (cx + pw * 0.7, cy)], "#0b0908", INK, 1.2)
    for x in (cx - pw, cx + pw * 0.7):  # pillars
        a.poly([(x, cy + 2 * k), (x, cy - ph), (x + pw * 0.3, cy - ph), (x + pw * 0.3, cy + 2 * k)], sl if x < cx else sr, INK, 1.2)
        a.line([(x + pw * 0.15, cy - ph + 4), (x + pw * 0.15, cy - 2)], "#5a554e", 0.9)
    a.poly([(cx - pw * 1.12, cy - ph), (cx - pw * 1.05, cy - ph - 9 * k), (cx + pw * 1.05, cy - ph - 9 * k), (cx + pw * 1.12, cy - ph)], st, INK, 1.3)  # lintel
    x, y = cx, cy - ph - 4.5 * k
    a.ellipse(x, y, 3.8 * k, 3.2 * k, "#c8c0a8", INK, 0.9)  # carved skull
    a.ellipse(x - 1.3 * k, y - 0.4 * k, 0.9 * k, 1 * k, INK)
    a.ellipse(x + 1.3 * k, y - 0.4 * k, 0.9 * k, 1 * k, INK)
    for (dx, sgn) in [(-2.2, -1), (2.2, 1)]:  # carved wings
        a.line([(x + dx * 2 * k, y), (x + sgn * 16 * k, y - 1.5 * k), (x + sgn * 12 * k, y + 1.5 * k)], "#6a655d", 1.0)
    # sand drifting over the bottom of the doorway
    a.raw('<path d="M%s,%s Q%s,%s %s,%s Q%s,%s %s,%s Z" fill="%s" stroke="%s" stroke-width="1.1"/>'
          % (fmt(cx - pw * 1.3), fmt(cy + 6 * k), fmt(cx - pw * 0.4), fmt(cy - 12 * k), fmt(cx + pw * 0.2), fmt(cy + 2 * k),
             fmt(cx + pw * 1.0), fmt(cy - 2 * k), fmt(cx + pw * 1.4), fmt(cy + 8 * k), sand, INK), [(cx - pw * 1.3, cy - 12 * k), (cx + pw * 1.4, cy + 8 * k)])
    # a stone block and a bone sticking out of the sand
    for (x, y) in [(30 * k, -8 * k), (-40 * k, 6 * k)][: (2 if big else 1)]:
        a.poly([(x - 6, y), (x - 6, y - 7), (x + 5, y - 9), (x + 7, y - 2), (x + 3, y + 2)], sl, INK, 1.0)
    _bone(a, 26 * k, 20 * k, 34 * k, 16 * k)
    a.save("lair_crypt_big" if big else "lair_crypt")


# ---------------------------------------------------------------- wolves and riders (docs/enemies-design.md §10.12)

WOLF_FUR, WOLF_FUR_D, WOLF_FUR_L = "#5e5954", "#45413d", "#7a756e"


def _wolf_body(a):
    """A grey wolf, side view, facing right, paws at y=0, its back at about y=-22."""
    a.shadow(22, 5, opacity=0.38)
    for hip, foot in (((-12, -11), (-15, 0)), ((11, -11), (13, 0))):  # far legs
        a.line([hip, foot], INK, 4.6)
        a.line([hip, foot], WOLF_FUR_D, 2.8)
    a.raw('<path d="M-17,-17 Q-26,-16 -30,-8 Q-25,-12 -18,-12Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (WOLF_FUR, INK), [(-31, -18), (-16, -7)])  # tail
    a.ellipse(-1, -15, 18, 7.5, WOLF_FUR, INK, 1.3)  # body
    a.ellipse(1, -11.5, 12, 3, WOLF_FUR_L, opacity=0.55)  # lighter belly
    for x in (-10, -5, 0):  # hackles
        a.line([(x, -21.5), (x - 2, -24)], WOLF_FUR_D, 1.3)
    for hip, foot in (((-8, -11), (-10, 0)), ((14, -11), (16, 0))):  # near legs
        a.line([hip, foot], INK, 4.8)
        a.line([hip, foot], WOLF_FUR, 3.0)
        a.ellipse(foot[0] + 1, foot[1] - 0.5, 2.6, 1.3, WOLF_FUR_D, INK, 0.8)
    a.poly([(10, -19), (15, -26), (20, -24), (17, -15)], WOLF_FUR, INK, 1.2)  # neck
    a.ellipse(19, -24, 6, 5, WOLF_FUR, INK, 1.2)  # head
    a.poly([(22, -27), (31, -22.5), (30, -20), (22, -20)], WOLF_FUR_L, INK, 1.1)  # snout
    a.ellipse(30.5, -21.7, 1.2, 1.0, INK)  # nose
    a.line([(24, -20.5), (29.5, -20.2)], INK, 0.9)  # jaw
    a.poly([(23, -19.6), (24, -18), (25, -19.6)], "#e8e0c8", INK, 0.5)  # fang
    a.poly([(15, -28), (16.5, -34), (19.5, -29)], WOLF_FUR_D, INK, 1.0)  # ears
    a.poly([(18, -28.5), (20.5, -33.5), (22, -28)], WOLF_FUR, INK, 1.0)
    a.ellipse(21.5, -25, 1.3, 1.0, "#f0c040")  # eye


def wolf():
    a = Art()
    _wolf_body(a)
    a.save("unit_wolf")


def corpse_wolf():
    a = Art()
    a.ellipse(0, 0, 22, 6, "#000", opacity=0.3)
    a.ellipse(0, 1, 16, 4, "#3a1a14", opacity=0.5)  # dark stain
    a.raw('<path d="M-16,-2 Q-24,0 -26,4 Q-20,3 -15,2Z" fill="%s" stroke="%s" stroke-width="1.1"/>' % (WOLF_FUR, INK), [(-27, -3), (-14, 5)])  # tail
    a.ellipse(-2, -2, 15, 5, WOLF_FUR, INK, 1.2)  # body on its side
    a.ellipse(-2, -0.5, 10, 2.2, WOLF_FUR_L, opacity=0.5)
    for x0, x1 in ((-8, -12), (-3, -6), (6, 9), (10, 14)):  # legs stretched out
        a.line([(x0, 1), (x1, 6)], INK, 3.4)
        a.line([(x0, 1), (x1, 6)], WOLF_FUR_D, 2.0)
    a.ellipse(15, -2, 5.5, 4, WOLF_FUR, INK, 1.1)  # head
    a.poly([(18, -3.5), (25, -1), (18, 1)], WOLF_FUR_L, INK, 1.0)  # snout
    a.poly([(12, -5), (13, -10), (16, -5.5)], WOLF_FUR_D, INK, 0.9)  # ear
    a.line([(15, -3), (17, -1)], INK, 1.0)  # closed eye
    a.save("corpse_wolf")


# ---------------------------------------------------------------- snake (docs/enemies-design.md §10.14)

SNAKE, SNAKE_D, SNAKE_L, SNAKE_BELLY, SNAKE_MARK = "#6f7d3c", "#4a5527", "#8e9c55", "#cfc58e", "#33391b"
SNAKE_FRAMES = 6  # the slither cycle (Config.ENEMIES.snake "slither")
SNAKE_LEN = 46.0  # body length, tail to snout, in pixels


def _snake_width(s):
    """Body thickness at s (0 tail .. 1 head): a thin tail, thickest a little
    behind the middle, a narrower neck and a broader head."""
    if s < 0.55:
        return 1.2 + 4.6 * math.sin(s / 0.55 * math.pi / 2)
    if s < 0.9:
        return 5.8 - 2.2 * (s - 0.55) / 0.35
    return 3.6 + 1.6 * math.sin((s - 0.9) / 0.1 * math.pi / 2)


def _snake_tube(a, pts, widths, markings=True):
    """A tube along `pts` (screen points, tail first) with `widths`: outline,
    body, a lighter back, and dark saddle marks."""
    n = len(pts)
    for i in range(n - 1):  # the outline under everything
        a.line([pts[i], pts[i + 1]], INK, widths[i] + 2.2)
    for i in range(n - 1):
        a.line([pts[i], pts[i + 1]], SNAKE, widths[i])
    for i in range(n - 1):  # the belly shows a little at the lower edge
        off = widths[i] * 0.28
        a.line([(pts[i][0], pts[i][1] + off), (pts[i + 1][0], pts[i + 1][1] + off)], SNAKE_BELLY, widths[i] * 0.3, opacity=0.8)
    for i in range(n - 1):  # light along the back
        off = widths[i] * 0.22
        a.line([(pts[i][0], pts[i][1] - off), (pts[i + 1][0], pts[i + 1][1] - off)], SNAKE_L, widths[i] * 0.28, opacity=0.75)
    if markings:
        for i in range(3, n - 4, 3):
            w = widths[i]
            a.ellipse(pts[i][0], pts[i][1] - w * 0.05, w * 0.42, w * 0.3, SNAKE_MARK, opacity=0.85)


def _snake_head(a, x, y, angle, tongue):
    """The head with its neck end at (x, y), pointing along `angle` (radians,
    screen): a rounded spade, wide at the jaws and narrowing to the snout, a
    yellow eye, and the forked tongue when `tongue`."""
    c, s = math.cos(angle), math.sin(angle)

    def at(u, v):  # u along the head, v across it
        return (x + u * c - v * s, y + u * s + v * c)
    if tongue:
        tip = at(11.5, 0.3)
        a.line([at(7.5, 0.3), tip], "#c0303a", 0.9)
        a.line([tip, at(13.5, -1.2)], "#c0303a", 0.7)
        a.line([tip, at(13.5, 1.8)], "#c0303a", 0.7)
    outline = []
    for k in range(13):  # round from the throat over the snout and back
        t = -math.pi / 2 + math.pi * k / 12
        u = 2.0 + 6.0 * math.cos(t)
        v = 3.4 * math.sin(t) * (1.0 - 0.3 * max(0.0, math.cos(t)))
        outline.append(at(u, v))
    outline.append(at(-1.0, 2.6))
    outline.append(at(-1.0, -2.6))
    a.poly(outline, SNAKE, INK, 1.1)
    a.poly([at(0, -2.2), at(4.5, -2.4), at(7.4, -0.7), at(1, -0.3)], SNAKE_L, stroke=None, opacity=0.55)
    a.line([at(1.0, 1.4), at(7.2, 0.6)], SNAKE_D, 0.7)  # the mouth
    a.ellipse(*at(3.6, -1.5), 1.25, 1.05, "#f2d040", INK, 0.5)
    a.ellipse(*at(3.9, -1.5), 0.35, 0.8, INK)
    a.ellipse(*at(7.2, -0.6), 0.35, 0.35, INK)  # nostril


def snake_slither(frame):
    """One frame of the slither: the body lies on the ground along an S-curve
    (projected onto the iso ground: the sideways sway is halved on screen),
    and the wave runs back along the body while the head goes almost straight
    on; each frame shifts it by 1/SNAKE_FRAMES of a wavelength. Facing right."""
    a = Art()
    a.shadow(25, 4.5, cx=-2, cy=1, opacity=0.3)
    phase = 2 * math.pi * frame / SNAKE_FRAMES
    wavelength = 0.62  # of the body length
    pts, widths = [], []
    n = 28
    for i in range(n + 1):
        s = i / n
        env = 0.35 + 0.65 * math.sin(min(s / 0.75, 1.0) * math.pi) if s < 0.75 else 0.35 * (1 - (s - 0.75) / 0.25) + 0.08
        lateral = 7.5 * env * math.sin(2 * math.pi * s / wavelength + phase)
        x = -SNAKE_LEN / 2 + SNAKE_LEN * s - 4
        lift = -2.5 * max(0.0, (s - 0.85) / 0.15)  # the neck lifts the head a little
        pts.append((x, -3 + lateral * 0.5 + lift))
        widths.append(_snake_width(s))
    _snake_tube(a, pts[:-2], widths[:-2])
    hx, hy = pts[-1]
    px, py = pts[-4]
    _snake_head(a, hx, hy, math.atan2(hy - py, hx - px) * 0.5, frame in (1, 4))
    a.save("unit_snake_slither_%d" % frame, fixed=(-34, -16, 34, 8))


def snake():
    """The base image: coiled, its head raised over the coils, ready to strike.
    At rest, striking, and in the library."""
    a = Art()
    a.shadow(15, 6, cy=1, opacity=0.35)
    turns = 1.7

    def at(t):  # a spiral from the outer coil (the tail end) inwards and up
        ang = math.pi * 0.15 + t * 2 * math.pi * turns
        r = 13.0 - 7.0 * t
        return (r * math.cos(ang), -3.5 + r * math.sin(ang) * 0.5 - 7.5 * t), math.sin(ang) > 0.0

    m = 60
    pts, front, widths = [], [], []
    for i in range(m + 1):
        t = i / m
        p, f = at(t)
        pts.append(p)
        front.append(f)
        widths.append(1.4 + 4.4 * math.sin(min(t / 0.4, 1.0) * math.pi / 2))
    # Runs of the coil: the far halves first, then the near ones, outer before
    # inner (the inner coils lie on top), each as one tube so it has no seams.
    runs = []
    start = 0
    for i in range(1, m + 1):
        if front[i] != front[start] or i == m:
            runs.append((front[start], start, i))
            start = i
    for is_front in (False, True):
        for f, i0, i1 in runs:
            if f == is_front:
                _snake_tube(a, pts[i0:i1 + 1], widths[i0:i1 + 1], markings=is_front)
    # the neck rises out of the middle in a gentle S, the head forward
    neck = [pts[-1], (-2.5, -15.0), (-2.0, -19.5), (1.0, -23.0), (5.0, -24.2)]
    _snake_tube(a, neck, [5.0, 4.5, 4.0, 3.7, 3.6], markings=False)
    _snake_head(a, 5.5, -24.3, -0.06, True)
    a.save("unit_snake", fixed=(-20, -32, 22, 6))


def corpse_snake():
    a = Art()
    a.ellipse(0, 0, 24, 5, "#000", opacity=0.28)
    a.ellipse(1, 1, 16, 3.5, "#2a2a14", opacity=0.45)  # dark stain
    pts, widths = [], []
    n = 22
    for i in range(n + 1):
        s = i / n
        pts.append((-22 + 42 * s, 1 + 3.2 * math.sin(s * math.pi * 1.3) * 0.5))
        widths.append(_snake_width(s) * 0.9)
    _snake_tube(a, pts[:-2], widths[:-2])
    hx, hy = pts[-1]
    a.poly([(hx - 3, hy - 3.2), (hx + 6, hy - 1), (hx + 6, hy + 1.2), (hx - 3, hy + 3.2)], SNAKE_D, INK, 1.0)  # the head on its side
    a.line([(hx + 0.5, hy - 1.6), (hx + 2.5, hy - 0.4)], INK, 0.8)  # a closed eye
    a.save("corpse_snake")


def _horse_body(a, coat, coat_d, mane, cloth=None, trim=None):
    """A horse, side view, facing right, hooves at y=0, the saddle at about
    y=-40. `cloth`: a long caparison over it (the Legion's), `trim` its hem."""
    a.shadow(30, 6, opacity=0.4)
    for hip, knee, foot in (((-17, -24), (-19, -12), (-18, 0)), ((14, -24), (17, -12), (16, 0))):  # far legs
        a.line([hip, knee, foot], INK, 5.4)
        a.line([hip, knee, foot], coat_d, 3.6)
    a.raw('<path d="M-23,-36 Q-33,-32 -34,-16 Q-29,-24 -24,-29Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (mane, INK), [(-35, -37), (-22, -15)])  # tail
    a.ellipse(-2, -32, 24, 10, coat, INK, 1.4)  # barrel
    for hip, knee, foot in (((-13, -24), (-14, -12), (-12, 0)), ((18, -24), (20, -12), (21, 0))):  # near legs
        a.line([hip, knee, foot], INK, 5.6)
        a.line([hip, knee, foot], coat, 3.8)
        a.poly([(foot[0] - 2.5, -2.5), (foot[0] + 3, -2.5), (foot[0] + 3.5, 0.5), (foot[0] - 2.8, 0.5)], "#2a211a", INK, 0.8)  # hoof
    a.poly([(14, -36), (22, -52), (29, -50), (24, -32)], coat, INK, 1.3)  # neck
    a.poly([(23, -55), (37, -46), (36, -41), (30, -40), (22, -48)], coat, INK, 1.3)  # head
    a.ellipse(35.5, -43.5, 1.1, 0.9, INK)  # nostril
    a.ellipse(27.5, -50, 1.3, 1.1, "#1a1410")  # eye
    a.poly([(23, -55), (24.5, -60), (26.5, -54)], coat_d, INK, 0.9)  # ear
    a.raw('<path d="M23,-55 Q16,-48 13,-37 Q18,-44 22,-49Z" fill="%s" stroke="%s" stroke-width="1"/>' % (mane, INK), [(12, -56), (24, -36)])  # mane
    if cloth:
        a.raw('<path d="M-22,-40 Q-3,-45 16,-40 L18,-22 Q-3,-17 -24,-22Z" fill="%s" stroke="%s" stroke-width="1.3"/>' % (cloth, INK), [(-25, -46), (19, -16)])
        if trim:
            a.raw('<path d="M18,-22 Q-3,-17 -24,-22" fill="none" stroke="%s" stroke-width="1.8"/>' % trim, [(-25, -23), (19, -17)])
        a.line([(26, -50), (30, -40)], "#3a2a1c", 1.4)  # bridle
    a.poly([(-9, -42), (8, -42), (6, -37), (-7, -37)], "#3a2a1c", INK, 1.1)  # saddle


LEGION_HORSE = ("#4a4a50", "#38383e", "#2a2a2e")


def horse():
    """The Legion's mount without its rider (a run-off horse, an undead horse)."""
    a = Art()
    _horse_body(a, *LEGION_HORSE, cloth="#6a6e7a")
    a.save("unit_horse")


def corpse_horse():
    coat, coat_d, mane = LEGION_HORSE
    a = Art()
    a.ellipse(0, 0, 32, 8, "#000", opacity=0.3)
    a.ellipse(-2, 1, 24, 5, "#3a1a14", opacity=0.5)
    a.raw('<path d="M-24,-2 Q-32,0 -36,6 Q-29,4 -23,2Z" fill="%s" stroke="%s" stroke-width="1.1"/>' % (mane, INK), [(-37, -3), (-22, 7)])  # tail
    a.ellipse(-4, -4, 22, 7.5, coat, INK, 1.3)  # barrel on its side
    a.raw('<path d="M-18,-8 Q-4,-12 10,-8 L11,0 Q-4,3 -19,0Z" fill="#6a6e7a" stroke="%s" stroke-width="1.1"/>' % INK, [(-20, -13), (12, 3)])  # torn caparison
    for x0, x1 in ((-14, -18), (-8, -11), (6, 10), (12, 17)):  # legs stretched out
        a.line([(x0, 2), (x1, 9)], INK, 4.2)
        a.line([(x0, 2), (x1, 9)], coat_d, 2.6)
    a.poly([(14, -6), (30, -4), (31, 1), (15, 2)], coat, INK, 1.2)  # neck and head, lying
    a.poly([(14, -6), (24, -7), (22, -5)], mane, INK, 0.8)
    a.line([(26, -3), (28, -1)], INK, 1.0)  # closed eye
    a.save("corpse_horse")


def _seat(a, rider, seat_y, hip_y, leg, boot=INK):
    """Puts the saved sprite `rider` (feet at its own (0, 0)) on a mount: cut
    off below `hip_y` (its own coordinates), its hips at `seat_y`, and a leg
    hanging down the mount's flank (`leg`: the near leg's colour)."""
    with open(os.path.join(ART, rider + ".svg")) as f:
        svg = f.read()
    body = svg[svg.index(">", svg.index("<svg")) + 1:svg.rindex("</svg>")].strip()
    lines = [l for l in body.split("\n") if l.strip()]
    if lines and 'fill="#000"' in lines[0]:  # (its own shadow: the mount has one)
        lines = lines[1:]
    m = manifest[rider]
    dy = seat_y - hip_y
    cid = "seat_" + rider
    inner = "\n  ".join(l.strip() for l in lines)
    a.raw('<clipPath id="%s"><rect x="-80" y="-120" width="160" height="%s"/></clipPath><g transform="translate(0,%s)"><g clip-path="url(#%s)">%s</g></g>'
          % (cid, fmt(120 + hip_y), fmt(dy), cid, inner),
          [(-m["ax"], -m["ay"] + dy), (-m["ax"] + m["w"], hip_y + dy)])
    a.line([(0, seat_y - 1), (3, seat_y + 9)], INK, 5)  # the near leg down the flank
    a.line([(0, seat_y - 1), (3, seat_y + 9)], leg, 3)
    a.ellipse(4, seat_y + 10, 3.2, 1.6, boot, INK, 0.8)


def goblin_raider():
    a = Art()
    _wolf_body(a)
    a.poly([(-7, -23), (5, -23), (4, -19.5), (-6, -19.5)], "#5a3a22", INK, 0.9)  # a crude saddle
    _seat(a, "unit_goblin", -19, -8, "#4a6029", "#2a211a")
    a.save("unit_goblin_raider")


def mounted(rider, name, cloth, trim=None, coat=LEGION_HORSE, leg="#3a3128"):
    """`rider` (a saved Legion sprite) on a horse: `name`."""
    a = Art()
    _horse_body(a, *coat, cloth=cloth, trim=trim)
    _seat(a, rider, -40, -11, leg)
    a.save(name)


def riders():
    goblin_raider()
    mounted("unit_legion_footman", "unit_legion_cavalry", "#6a6e7a")
    mounted("unit_legion_captain", "unit_legion_captain_mounted", "#3a3a42", "#b8bcc4")
    mounted("unit_legion_captain_lysa", "unit_legion_captain_lysa_mounted", CRIMSON_D, GOLD_D)
    mounted("unit_legion_marshal", "unit_legion_marshal_mounted", "#5e626c", GOLD)
    mounted("unit_legion_king", "unit_legion_king_mounted", "#c4c8d2", GOLD, coat=("#d8d4cc", "#b4b0a8", "#e8e4dc"), leg="#a4a8b2")
