"""Units: villagers, the hero, military units and mages, the caravan and trade carts,
projectiles, the scenarios' people and the Legion's units."""

import math
import os
import re

from .core import (
    Art, CRIMSON, fmt, GLOW, _glow, GOLD, GOLD_D, INK, person, ROOT, shade, WOOD, WOOD_D, WOOD_L,
)


def builder():
    def extra(a, layer):
        if layer == "front":
            # hammer
            a.line([(6, -18), (13, -30)], INK, 3.6)
            a.line([(6, -18), (13, -30)], WOOD_L, 2)
            a.poly([(9, -33), (17, -29), (15, -26), (8, -30)], "#8a8a8a")
            a.line([(4, -20), (8, -20)], INK, 4)
            # apron
            a.poly([(-5, -12), (5, -12), (4, -23), (-4, -23)], "#7a5a38", INK, 1)

    def hat(a):
        a.raw('<path d="M-7,-35 Q-6,-42 0,-42 Q7,-42 7,-35 Z" fill="#5c5448" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -43), (8, -34)])
        a.line([(-8, -35), (9, -35)], INK, 2)
    person("unit_builder", ("#7a6048", "#5f4a37"), hat=hat, extra=extra)


def farmer():
    def extra(a, layer):
        if layer == "front":
            a.line([(8, -4), (12, -38)], INK, 3)
            a.line([(8, -4), (12, -38)], WOOD_L, 1.6)
            a.line([(9, -38), (15, -38)], INK, 1.8)
            for x in (9, 12, 15):
                a.line([(x, -38), (x, -44)], "#8a8a8a", 1.4)
            a.line([(4, -20), (9, -22)], INK, 4)

    def hat(a):
        a.ellipse(0, -38, 11, 3.2, "#b8a060", INK, 1.2)
        a.raw('<path d="M-5,-38 Q-4,-45 0,-45 Q4,-45 5,-38 Z" fill="#c9b070" stroke="%s" stroke-width="1.2"/>' % INK, [(-6, -46), (6, -37)])
    person("unit_farmer", ("#566a3a", "#43532d"), hat=hat, extra=extra)


def explorer():
    def extra(a, layer):
        if layer == "back":
            a.poly([(-10, -14), (-5, -14), (-5, -26), (-10, -26)], "#5a4630")  # pack
        else:
            a.line([(5, -20), (10, -18)], INK, 4)
            a.line([(10, -18), (10, -12)], INK, 1.2)
            a.poly([(7, -12), (13, -12), (12, -5), (8, -5)], "#3a3128")
            a.ellipse(10, -8.5, 2.2, 2.6, GLOW)
            a.ellipse(10, -8.5, 6, 6, GLOW, opacity=0.25)
    person("unit_explorer", ("#3a4a44", "#2c3934"), hood="#34453f", extra=extra)


def archmage():
    def extra(a, layer):
        if layer == "front":
            a.line([(10, 0), (10, -44)], INK, 3.4)
            a.line([(10, 0), (10, -44)], "#3a2c22", 1.8)
            a.ellipse(10, -47, 4.2, 4.2, "#b88cff", INK, 1.2)
            a.ellipse(10, -47, 9, 9, "#9a6cff", opacity=0.3)
            a.raw('<path d="M-3,-30 Q0,-18 3,-30 Z" fill="#cfcfcf" stroke="%s" stroke-width="1"/>' % INK, [(-4, -31), (4, -18)])

    def hat(a):
        a.raw('<path d="M-9,-36 L9,-36 L2,-40 L-3,-58 L-4,-40 Z" fill="#2e2442" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-10, -59), (10, -35)])
        a.ellipse(-3, -58, 1.6, 1.6, GOLD)
    person("unit_archmage", ("#3a2d55", "#2a2040"), hat=hat, robe=True, extra=extra)


def archer():
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -16), (-5, -16), (-3, -30), (-7, -30)], WOOD, INK, 1)
            a.line([(-6, -30), (-7, -35)], INK, 1.2)
        else:
            a.poly([(-7, -24), (7, -18), (7, -15), (-7, -21)], CRIMSON, INK, 0.8)  # sash
            a.line([(4, -21), (11, -22)], INK, 4)
            a.raw('<path d="M9,-38 Q19,-22 9,-6" fill="none" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % INK, [(8, -39), (18, -5)])
            a.raw('<path d="M9,-38 Q19,-22 9,-6" fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round"/>' % "#8a5a30", [(8, -39), (18, -5)])
            a.line([(9, -38), (9, -6)], "#d8d0b8", 0.8)
    person("unit_archer", ("#33472f", "#263623"), hood="#2c3f29", extra=extra)


def gatherer():
    """Hunter-like villager without a bow: feathered cap, leather jerkin, knife, big sack."""
    def extra(a, layer):
        if layer == "back":
            a.raw('<path d="M-15,-12 Q-17,-30 -8,-30 L-4,-28 Q-2,-14 -6,-10 Z" fill="#8a7248" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % INK, [(-18, -31), (-2, -10)])
            a.line([(-12, -29), (-6, -27)], "#5a4a30", 1.4)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a5236", INK, 1)  # leather jerkin
            a.line([(-6, -24), (4, -14)], "#3a2c1c", 2)  # strap
            a.line([(5, -19), (10, -15)], INK, 4)
            a.line([(10, -15), (15, -13)], "#c9ccd4", 2.2)  # skinning knife
            a.line([(9, -15.5), (11, -14.5)], "#3a2c1c", 3)

    def hat(a):
        a.raw('<path d="M-7,-35 Q-5,-43 1,-42 Q8,-41 8,-35 Z" fill="#4a5a36" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -44), (9, -34)])
        a.line([(-8, -35), (10, -35)], INK, 1.8)
        a.raw('<path d="M5,-39 Q13,-48 18,-50 Q13,-43 7,-37 Z" fill="#b8402e" stroke="%s" stroke-width="1"/>' % INK, [(4, -51), (19, -36)])
    person("unit_gatherer", ("#56643a", "#434f2d"), hat=hat, extra=extra)


def forester():
    """Woodcutter with a big axe over the shoulder."""
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#7a3a2a", INK, 1)  # red check shirt
            for yy in (-16, -21):
                a.line([(-5.5, yy), (5.5, yy)], "#5a2a1e", 1.2)
            a.line([(-2, -26), (-2, -12), (2, -26), (2, -12)], "#5a2a1e", 1.0)
            a.line([(4, -20), (8, -24)], INK, 4)  # arm
            a.line([(3, -8), (13, -38)], INK, 3.6)  # axe haft
            a.line([(3, -8), (13, -38)], WOOD_L, 2)
            a.poly([(10, -40), (19, -41), (20, -32), (12, -34)], "#9a9a9a", INK, 1.2)  # axe head
            a.line([(19, -41), (20, -32)], "#d8d8d8", 1.2)

    def hat(a):
        a.raw('<path d="M-7,-34 Q-7,-43 0,-43 Q7,-43 7,-34 Z" fill="#3a4a2a" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -44), (8, -33)])
        a.line([(-7.5, -34.5), (7.5, -34.5)], INK, 2)
        a.raw('<path d="M-6,-30 Q0,-24 6,-30 Q4,-26 0,-25 Q-4,-26 -6,-30Z" fill="#6a4a2a"/>', [(-6, -31), (6, -24)])  # beard
    person("unit_forester", ("#4a3a2a", "#3a2c1e"), hat=hat, extra=extra)


def trader():
    """The trader: a green travelling coat, a satchel and a ledger."""
    def extra(a, layer):
        if layer == "front":
            a.poly([(-7, -12), (7, -12), (6, -27), (-6, -27)], "#3e5a3a", INK, 1)  # coat
            a.line([(-5, -26), (6, -13)], "#6a4a2c", 1.6)  # satchel strap
            a.poly([(3, -16), (9, -16), (9, -10), (3, -10)], "#6a4a2c", INK, 1)  # satchel
            a.line([(-5, -22), (-10, -17)], INK, 3.6)  # arm with the ledger
            a.poly([(-14, -20), (-8, -21), (-8, -14), (-14, -13)], "#e8dcc0", INK, 1)
            a.line([(-12.5, -18), (-9.5, -18.5)], "#6a5a40", 0.8)

    def hat(a):
        a.raw('<path d="M-8,-37 Q0,-41 8,-37 Q4,-35.5 0,-35.5 Q-4,-35.5 -8,-37Z" fill="#5a4630" stroke="%s" stroke-width="1.2"/>' % INK, [(-9, -42), (9, -34)])
        a.raw('<path d="M-5,-37 Q-4,-44 0,-44 Q4,-44 5,-37Z" fill="#6a5238" stroke="%s" stroke-width="1.2"/>' % INK, [(-6, -45), (6, -36)])
        a.line([(-4.5, -38.5), (4.5, -38.5)], GOLD, 1.4)
    person("unit_trader", ("#3e5a3a", "#2e4630"), hat=hat, extra=extra)


def trade_cart(name, cloth):
    """A trade caravan (docs/market-design.md §5): an open four-wheeled cart
    piled with crates and sacks, a pennant in its owner's colour (`cloth`),
    pulled by a mule (faces right). Not the covered help wagon (`caravan`)."""
    a = Art()
    a.ellipse(0, 1, 28, 7, "#000", opacity=0.35)
    a.poly([(-26, -11), (4, -11), (6, -19), (-24, -19)], WOOD_L, INK, 1.3)  # open bed
    a.poly([(-26, -11), (4, -11), (4, -8), (-26, -8)], WOOD_D, INK, 1.1)
    for (x, y, w, h, col) in [(-22, -19, 9, 9, "#b08a58"), (-13, -19, 8, 11, "#9a7448")]:  # crates
        a.poly([(x, y), (x + w, y), (x + w, y - h), (x, y - h)], col, INK, 1)
        a.line([(x, y - h / 2), (x + w, y - h / 2)], WOOD_D, 0.8)
    a.ellipse(-1, -24, 6, 5, "#c9a86a", INK, 1.0)  # sacks
    a.ellipse(-16, -33, 5, 4, "#d4b478", INK, 1.0)
    for wx in (-20, -2):  # wheels
        a.ellipse(wx, -5, 6, 6, WOOD_D, INK, 1.3)
        a.ellipse(wx, -5, 1.8, 1.8, "#3a2a1a")
    a.line([(-24, -19), (-25, -44)], WOOD_D, 1.8)  # pennant pole
    a.poly([(-25, -44), (-11, -41), (-25, -36)], cloth, INK, 0.9)
    a.line([(5, -13), (13, -11)], WOOD_D, 2.2)  # shafts
    mule, mule_d = "#6e6258", "#4e443c"
    for x in (14, 18, 25, 29):
        a.line([(x, -12), (x + (1 if x % 2 else -1), 0)], INK, 3)
        a.line([(x, -12), (x + (1 if x % 2 else -1), 0)], mule_d, 1.7)
    a.ellipse(21.5, -15.5, 9.5, 5.5, mule, INK, 1.3)
    a.poly([(28, -18), (31, -27), (35, -28), (37, -24), (32, -17)], mule, INK, 1.2)
    a.poly([(31, -27), (30, -34), (33, -28)], mule, INK, 0.9)  # long ears
    a.poly([(34, -28), (33, -35), (36, -28)], mule, INK, 0.9)
    a.ellipse(35, -25.5, 0.9, 0.9, "#111")
    a.poly([(17, -20), (26, -20), (26, -16), (17, -16)], cloth, INK, 0.8, opacity=0.9)  # blanket
    a.save(name)


def trade_carts():
    """The merchants' neutral cart, and one in each village's colour."""
    trade_cart("unit_trade_cart", "#8a7a5a")
    for i, col in enumerate(village_colors()):
        trade_cart("unit_trade_cart_c%d" % i, col)


def merchant():
    """Pell: a wide-brimmed hat, a long brown coat, a lantern."""
    def extra(a, layer):
        if layer == "front":
            a.poly([(-7, -12), (7, -12), (6, -27), (-6, -27)], "#5a4630", INK, 1)  # coat
            a.line([(-1, -26), (-3, -12)], GOLD, 1.2)
            a.line([(5, -21), (10, -16)], INK, 3.6)  # arm
            a.line([(10, -16), (10, -12)], INK, 1)
            a.poly([(8, -12), (12, -12), (11.5, -5), (8.5, -5)], GOLD, INK, 1)  # lantern
            a.ellipse(10, -8.5, 1.5, 2, "#fff4c0")

    def hat(a):
        a.raw('<path d="M-11,-36 Q0,-40 11,-36 Q6,-34 0,-34 Q-6,-34 -11,-36Z" fill="#3a2e22" stroke="%s" stroke-width="1.2"/>' % INK, [(-12, -41), (12, -33)])
        a.raw('<path d="M-6,-36 Q-5,-44 0,-44 Q5,-44 6,-36Z" fill="#4a3a2a" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -45), (7, -35)])
        a.line([(-5.5, -37.5), (5.5, -37.5)], CRIMSON, 1.6)
        a.raw('<path d="M-4,-29 Q0,-25 4,-29 Q3,-27 0,-26.5 Q-3,-27 -4,-29Z" fill="#6a4a30"/>', [(-4, -30), (4, -26)])  # beard
    person("unit_merchant", ("#5a4630", "#46361f"), hat=hat, extra=extra)


def guild_master():
    """Wenna: a long dark-blue robe, a gold chain of office, the guild's ledger."""
    def extra(a, layer):
        if layer == "front":
            a.line([(-4, -26), (0, -20), (4, -26)], GOLD, 1.4)  # chain
            a.ellipse(0, -20, 1.6, 1.6, GOLD, INK, 0.6)
            a.poly([(3, -20), (11, -21), (11, -13), (3, -12)], "#6a2a24", INK, 1)  # ledger
            a.line([(4, -16.5), (10, -17)], "#e8dcc0", 0.8)

    def hat(a):
        a.raw('<path d="M-6,-34 Q-7,-42 0,-41 Q6,-42 6,-35 Q4,-39 0,-39 Q-4,-39 -6,-34Z" fill="#8a8478" stroke="%s" stroke-width="1.1"/>' % INK, [(-7, -43), (7, -33)])
        a.ellipse(-4, -40, 3, 2.6, "#8a8478", INK, 1)  # the bun
    person("unit_guildmaster", ("#2f3e5a", "#243048"), hat=hat, skin="#d8b08c", robe=True, extra=extra)


def druid():
    """A druid: a moss-green robe, a hood with a wreath of leaves, a crooked staff."""
    def extra(a, layer):
        if layer == "back":
            a.line([(9, 0), (11, -44)], INK, 3.2)
            a.line([(9, 0), (11, -44)], WOOD, 1.8)
            a.ellipse(11, -45, 3.4, 3, "#5aa04a", INK, 0.9)
        else:
            a.line([(-5, -24), (5, -24)], "#8a6a3a", 1.6)  # rope belt
            a.line([(4, -20), (9, -28)], INK, 4)
            a.line([(4, -20), (9, -28)], "#3e5a2c", 2.6)

    def hat(a):
        for (dx, dy) in [(-6, -38), (-3, -42), (1, -43), (5, -41), (7, -37)]:
            a.ellipse(dx, dy, 2.4, 1.6, "#6aa84a", INK, 0.7)
    person("unit_druid", ("#3e5a2c", "#2e4620"), hood="#4a3a24", hat=hat, robe=True, extra=extra)


def priest_person():
    """Anselm: a black cassock, a white collar, a grey fringe round a bald head,
    a spade from the graves."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-9, 2), (-6, -30)], INK, 2.8)
            a.line([(-9, 2), (-6, -30)], WOOD_L, 1.4)
            a.poly([(-11, 2), (-6, 2), (-6.5, 7), (-10.5, 7)], "#9a9a9a", INK, 0.8)
        else:
            a.poly([(-4, -27), (4, -27), (3, -24), (-3, -24)], "#f0ece0", INK, 0.7)
            a.line([(0, -22), (0, -15)], GOLD, 1.2)
            a.line([(-2, -19.5), (2, -19.5)], GOLD, 1.2)

    def hat(a):
        a.raw('<path d="M-6,-31 Q-7,-37 -4,-37 M6,-32 Q7,-37 4,-37" fill="none" stroke="#b8b4ac" stroke-width="2.6"/>', [(-8, -38), (8, -30)])
    person("unit_priest", ("#26242a", "#1a181e"), hat=hat, skin="#d4a888", robe=True, extra=extra)


def eldest_priest_person():
    """Scenario 9's eldest priest, as in her portrait: a dark-blue habit and veil
    over a white wimple, a gold cross on her chest."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-6, -38), (-10, -18), (-3, -24)], "#26324a", INK, 0.9)  # the veil down her back
        else:
            a.poly([(-5, -29), (5, -29), (4, -24.5), (-4, -24.5)], "#f0ece2", INK, 0.7)  # wimple at the chin
            a.line([(0, -22), (0, -14)], GOLD, 1.4)
            a.line([(-2.5, -19.5), (2.5, -19.5)], GOLD, 1.4)

    def hat(a):
        a.raw('<path d="M-5.5,-36.5 Q0,-39 5.5,-36.5" fill="none" stroke="#f0ece2" stroke-width="2.4"/>', [(-6, -40), (6, -35)])
    person("unit_eldest_priest", ("#26324a", "#1c2638"), hood="#26324a", hat=hat, skin="#d6ae8e", robe=True, extra=extra)


def princess():
    """Fiona: a deep-blue gown with a silver hem, red-gold hair under a thin circlet."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-6, -36), (-10, -14), (-4, -24)], "#b0582a", INK, 0.9)  # hair down her back
        else:
            a.line([(-8, -6), (8, -6)], "#c8ccd8", 1.4)
            a.line([(-5, -26), (5, -26)], "#c8ccd8", 1.2)

    def hat(a):
        a.raw('<path d="M-6,-33 Q-7,-41 0,-41 Q7,-41 6,-33 Q5,-38 0,-38 Q-5,-38 -6,-33Z" fill="#b0582a" stroke="%s" stroke-width="1.1"/>' % INK, [(-7, -42), (7, -32)])
        a.line([(-5.5, -37.5), (5.5, -37.5)], "#d8dce8", 1.4)
        a.ellipse(0, -38, 1.2, 1.2, "#7ab0ff")
    person("unit_princess", ("#243a6a", "#1a2c52"), hat=hat, skin="#e0bc9c", robe=True, extra=extra)


def legion_footman():
    """A soldier of the Dread Legion: pale skin, a grey-steel helm, a faded
    tabard that was crimson once, a spear and a round shield; stiff."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-7, -6), (-2, -52)], INK, 3.4)  # spear, upright
            a.line([(-7, -6), (-2, -52)], "#6a5a48", 1.8)
            a.poly([(-3.5, -52), (-2, -60), (-0.5, -52)], "#b8bcc4", INK, 0.8)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a4e50", INK, 1)  # faded tabard
            a.line([(0, -26), (0, -12)], "#5a4446", 1)
            a.ellipse(7, -18, 6, 7, "#5a5e66", INK, 1.2)  # shield
            a.ellipse(7, -18, 2, 2.3, "#8a8e96", INK, 0.8)

    def hat(a):
        a.raw('<path d="M-6.5,-31 Q-7,-41 0,-41 Q7,-41 6.5,-31 L4,-31 L4,-34 L-4,-34 L-4,-31Z" fill="#7a7e86" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -42), (7, -30)])
        a.line([(-1, -34), (-1, -29)], "#5a5e66", 1.4)  # nose guard
        a.ellipse(3, -33, 1.1, 0.8, "#d8e0f0")  # empty, pale eye
    person("unit_legion_footman", ("#4a4c54", "#3a3c44"), hat=hat, skin="#c4c6c8", extra=extra)


def legion_captain(name, plume, hair=None):
    """A Legion captain: the footman's pallor, a plumed helm, a long dark cloak
    and a sword held high. Lysa's own has a crimson plume and a dark-red
    braid; Torben's (the generic one) a pale grey plume."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-7, -27), (-12, -2), (0, -4), (6, -27)], "#2a2a30", INK, 1.2)  # cloak
            if hair:
                a.raw('<path d="M-5,-33 Q-11,-28 -9,-19 Q-8,-24 -4,-29Z" fill="%s" stroke="%s" stroke-width="1"/>' % (hair, INK), [(-11, -34), (-3, -18)])
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#5a4448", INK, 1)
            a.line([(-5, -24), (5, -24)], GOLD_D, 1.4)  # a captain's sash
            a.line([(4, -22), (10, -30)], INK, 3.6)  # sword arm, raised
            a.line([(9, -29), (12, -32)], INK, 2.4)
            a.poly([(11, -33), (13, -31), (21, -46), (20, -47)], "#c8ccd4", INK, 0.9)

    def hat(a):
        a.raw('<path d="M-6.5,-31 Q-7,-41 0,-41 Q7,-41 6.5,-31 L4,-31 L4,-34 L-4,-34 L-4,-31Z" fill="#8a8e96" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -42), (7, -30)])
        a.line([(-1, -34), (-1, -29)], "#5a5e66", 1.4)
        a.raw('<path d="M0,-41 Q-4,-50 -12,-49 Q-6,-46 -4,-41Z" fill="%s" stroke="%s" stroke-width="1"/>' % (plume, INK), [(-13, -51), (1, -40)])
        a.ellipse(3, -33, 1.1, 0.8, "#d8e0f0")
    person(name, ("#3a3a42", "#2c2c34"), hat=hat, skin="#c4c6c8", extra=extra)


LEGION_HELM = '<path d="M-6.5,-31 Q-7,-41 0,-41 Q7,-41 6.5,-31 L4,-31 L4,-34 L-4,-34 L-4,-31Z" fill="%s" stroke="%s" stroke-width="1.2"/>'


def _legion_hat(steel="#7a7e86", plume=None):
    def hat(a):
        a.raw(LEGION_HELM % (steel, INK), [(-7, -42), (7, -30)])
        a.line([(-1, -34), (-1, -29)], "#5a5e66", 1.4)  # nose guard
        if plume:
            a.raw('<path d="M0,-41 Q-4,-50 -12,-49 Q-6,-46 -4,-41Z" fill="%s" stroke="%s" stroke-width="1"/>' % (plume, INK), [(-13, -51), (1, -40)])
        a.ellipse(3, -33, 1.1, 0.8, "#d8e0f0")  # empty, pale eye
    return hat


def legion_archer():
    """A Legion archer: the footman's pallor and helm, a quiver on the back,
    a longbow held out in front, the faded tabard."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -14), (-4, -15), (-2, -34), (-7, -34)], "#5a4630", INK, 1)  # quiver
            for x in (-6.5, -4.5):
                a.line([(x, -34), (x - 1, -40)], "#c8c0a8", 1.2)
                a.poly([(x - 2.2, -40), (x + 0.2, -40), (x - 1, -43)], "#b8bcc4", INK, 0.5)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a4e50", INK, 1)  # faded tabard
            a.line([(0, -26), (0, -12)], "#5a4446", 1)
            a.line([(4, -22), (10, -21)], INK, 3.4)  # bow arm
            a.raw('<path d="M10,-40 Q17,-22 10,-4" fill="none" stroke="%s" stroke-width="3.2"/>' % INK, [(9, -41), (17, -3)])
            a.raw('<path d="M10,-40 Q17,-22 10,-4" fill="none" stroke="%s" stroke-width="1.8"/>' % "#6a5038", [(9, -41), (17, -3)])
            a.line([(10, -40), (10, -4)], "#d8d4c8", 0.7)  # string
    person("unit_legion_archer", ("#4a4c54", "#3a3c44"), hat=_legion_hat(), skin="#c4c6c8", extra=extra)


def legion_guard():
    """A Legion guardsman: a tall rectangular tower shield in front, the grey
    helm, a short spear over it."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-4, -4), (4, -50)], INK, 3.2)  # spear
            a.line([(-4, -4), (4, -50)], "#6a5a48", 1.6)
            a.poly([(2.6, -50), (4.4, -57), (6, -49.6)], "#b8bcc4", INK, 0.8)
        else:
            a.poly([(-1, -3), (12, -6), (12, -36), (-1, -33)], "#5a5e66", INK, 1.4)  # tower shield
            a.poly([(1, -6), (10, -8), (10, -33), (1, -31)], "#6a6e76", stroke=None)
            a.line([(5.5, -8), (5.5, -32)], "#8a8e96", 1.4)
            a.line([(1, -20), (10, -21)], "#8a8e96", 1.4)
            a.ellipse(5.5, -20.5, 2.2, 2.4, "#9a9ea6", INK, 0.8)
            a.line([(-1, -3), (12, -6), (12, -36), (-1, -33), (-1, -3)], INK, 1.4)
    person("unit_legion_guard", ("#44464e", "#34363e"), hat=_legion_hat("#8a8e96"), skin="#c4c6c8", extra=extra)


def legion_banner():
    """A Legion banner-bearer: a tall pole with a long pale banner, the crown's
    sigil faded on it; a short spear-point on top."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-6, -4), (-6, -66)], INK, 3.4)  # the banner pole
            a.line([(-6, -4), (-6, -66)], WOOD_D, 1.8)
            a.poly([(-7.4, -66), (-6, -72), (-4.6, -66)], "#b8bcc4", INK, 0.7)
            a.line([(-12, -62), (6, -62)], WOOD_D, 1.8)  # crossbar
            a.poly([(-11, -62), (5, -62), (5, -36), (-3, -40), (-11, -36)], "#d4d6dc", INK, 1.2)  # the pale banner
            a.poly([(-11, -62), (-3, -62), (-3, -40), (-11, -36)], "#c0c3ca", stroke=None)
            a.poly([(-7, -54), (-5, -57), (-3, -54), (-1, -57), (1, -54), (1, -50), (-7, -50)], "#8a8e9a", INK, 0.6)  # a faded crown
            a.line([(-11, -62), (5, -62)], INK, 1.2)
        else:
            a.poly([(-6, -12), (6, -12), (5, -26), (-5, -26)], "#6a4e50", INK, 1)
            a.line([(-4, -22), (-7, -26)], INK, 3.4)  # arm on the pole
    person("unit_legion_banner", ("#4a4c54", "#3a3c44"), hat=_legion_hat(), skin="#c4c6c8", extra=extra)


def legion_champion():
    """The court's champion (Rurik): pale plate with broad pauldrons, a white
    plume, a greatsword over the shoulder, a pale cloak."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-8, -27), (-14, -1), (2, -3), (7, -27)], "#c8ccd4", INK, 1.2)  # pale cloak
            a.line([(10, -14), (-10, -56)], INK, 5)  # greatsword over the shoulder
            a.line([(10, -14), (-10, -56)], "#d8dce4", 3)
            a.line([(5, -21), (11, -24)], INK, 3)  # cross-guard
            a.line([(5, -21), (11, -24)], GOLD_D, 1.6)
        else:
            a.poly([(-7, -11), (7, -11), (6, -27), (-6, -27)], "#b8bcc4", INK, 1.2)  # breastplate
            a.poly([(0, -11), (7, -11), (6, -27), (0, -27)], "#9a9ea6", stroke=None)
            a.line([(-6, -19), (6, -19)], "#7a7e86", 1)
            a.ellipse(-7, -26, 4.4, 3.2, "#c8ccd4", INK, 1.1)  # pauldrons
            a.ellipse(7, -26, 4.4, 3.2, "#a8acb4", INK, 1.1)
            a.line([(7, -24), (10, -16)], INK, 4)  # arm to the hilt
    person("unit_legion_champion", ("#9a9ea6", "#7a7e86"), hat=_legion_hat("#b8bcc4", "#eceef2"), skin="#c4c6c8", extra=extra)


def herald():
    """Lothar, the court's herald: a pale tabard over a long coat, a feathered
    cap, a white flag on a staff."""
    def extra(a, layer):
        if layer == "back":
            a.line([(8, -2), (8, -58)], INK, 3)
            a.line([(8, -2), (8, -58)], "#d8d0bc", 1.6)
            a.raw('<path d="M8,-58 Q16,-60 22,-56 Q18,-50 24,-44 Q16,-46 8,-42 Z" fill="#f2f0ea" stroke="%s" stroke-width="1"/>' % INK, [(7, -61), (25, -41)])
        else:
            a.poly([(-6, -10), (6, -10), (5, -27), (-5, -27)], "#d8d6de", INK, 1)  # pale tabard
            a.poly([(-3, -21), (0, -24), (3, -21), (0, -18)], GOLD_D, INK, 0.6)
            a.line([(4, -22), (8, -26)], INK, 3.4)  # hand on the staff

    def hat(a):
        a.raw('<path d="M-7,-35 Q-6,-42 1,-42 Q8,-41 8,-35 Z" fill="#5a5470" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -43), (9, -34)])
        a.raw('<path d="M-4,-41 Q-12,-50 -16,-46 Q-10,-45 -6,-39 Z" fill="#eceae4" stroke="%s" stroke-width="0.9"/>' % INK, [(-17, -51), (-3, -38)])
    person("unit_herald", ("#4a4660", "#3a3650"), hat=hat, skin="#d8ccc4", robe=True, extra=extra)


def legion_marshal():
    """The Legion's marshal (Halvard): dark steel plate under a pale mantle with
    a gold-trimmed collar, a red-white plume, a marshal's baton raised and a
    long sword at his side."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -28), (-15, 0), (4, -2), (8, -28)], "#d4d2dc", INK, 1.2)  # pale mantle
            a.poly([(-15, 0), (-9, -28), (-6, -28), (-10, 0)], "#b8b6c2", stroke=None)
            a.line([(-6, -12), (-12, 2)], INK, 3.4)  # sword at the hip
            a.line([(-6, -12), (-12, 2)], "#c8ccd4", 1.8)
        else:
            a.poly([(-7, -11), (7, -11), (6, -27), (-6, -27)], "#5e626c", INK, 1.2)  # dark breastplate
            a.poly([(0, -11), (7, -11), (6, -27), (0, -27)], "#4a4e58", stroke=None)
            a.line([(-6, -24), (0, -20), (6, -24)], GOLD, 1.4)  # gold trim
            a.ellipse(-7, -26, 4.2, 3.0, "#6e727c", INK, 1.1)
            a.ellipse(7, -26, 4.2, 3.0, "#5a5e68", INK, 1.1)
            a.line([(7, -24), (12, -34)], INK, 4)  # arm up, the baton
            a.line([(11, -32), (15, -42)], INK, 3.6)
            a.line([(11, -32), (15, -42)], GOLD, 2)
            a.ellipse(15, -42, 1.6, 1.6, GOLD, INK, 0.8)
    person("unit_legion_marshal", ("#5e626c", "#4a4e58"), hat=_legion_hat("#6e727c", "#e8e4ea"), skin="#c6c6ca", extra=extra)


def legion_king():
    """Rhodri on the field: a long dark royal coat over pale plate, the
    reworked crown glowing cold on his head, a heavy sword, a halo of cold light."""
    def extra(a, layer):
        if layer == "back":
            _glow(a, 0, -34, 14, 12, "#b8d0ff", 0.35)
            a.poly([(-10, -28), (-17, 0), (6, -1), (9, -28)], "#2a2236", INK, 1.2)  # royal coat
            a.poly([(-17, 0), (-10, -28), (-7, -28), (-12, 0)], "#3a3050", stroke=None)
            a.line([(-16, -1), (5, -2)], "#c8d0e0", 1.4)  # ermine hem
            a.line([(11, -12), (-8, -58)], INK, 5.5)  # the sword
            a.line([(11, -12), (-8, -58)], "#dce4f0", 3.2)
            a.line([(4, -19), (12, -22)], INK, 3)
            a.line([(4, -19), (12, -22)], GOLD, 1.6)
        else:
            a.poly([(-7, -11), (7, -11), (6, -27), (-6, -27)], "#c4c8d2", INK, 1.2)  # pale plate
            a.poly([(0, -11), (7, -11), (6, -27), (0, -27)], "#a4a8b2", stroke=None)
            a.poly([(-4, -27), (0, -22), (4, -27)], "#2a2236", INK, 0.8)
            a.line([(7, -24), (10, -15)], INK, 4)

    def crown(a):
        a.raw('<path d="M-7,-37 L-7,-44 L-3.5,-40 L0,-46 L3.5,-40 L7,-44 L7,-37 Z" fill="#c8d8f0" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -47), (8, -36)])
        a.ellipse(0, -40, 1.3, 1.3, "#eaf4ff", INK, 0.6)
        a.raw('<path d="M-6,-31 Q-7,-38 0,-39 Q7,-38 6,-31 Q5,-35 0,-35 Q-5,-35 -6,-31 Z" fill="#2a2430"/>', [(-7, -40), (7, -30)])
    person("unit_legion_king", ("#c4c8d2", "#a4a8b2"), hat=crown, skin="#e0e4ec", extra=extra)


def summoner():
    """Mage without a staff: pointy hat, dark robe, a glowing purple orb held in the hand."""
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -26), (6, -26), (4, -22), (-4, -22)], "#5a3a7a", INK, 0.8)  # violet collar
            a.line([(4, -22), (11, -24)], INK, 4.2)  # arm held out
            a.line([(4, -22), (11, -24)], "#243a44", 2.6)
            a.ellipse(13, -27, 9, 9, "#9a6cff", opacity=0.3)
            a.ellipse(13, -27, 4.2, 4.2, "#a87cff", INK, 1.2)
            a.ellipse(12, -28.2, 1.4, 1.4, "#e8dcff")

    def hat(a):
        a.raw('<path d="M-9,-36 L9,-36 L3,-40 L-1,-57 L-4,-40 Z" fill="#3a2a55" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-10, -58), (10, -35)])
        a.line([(-6, -38.5), (6, -38.5)], "#9a6cff", 1.6)
    person("unit_summoner", ("#243a44", "#1a2c34"), hat=hat, robe=True, extra=extra)


def earth_elemental():
    """Small walking boulder with glowing cracks."""
    a = Art()
    a.shadow(12, 5, opacity=0.4)
    rock, rock_d, rock_l = "#7a6e5e", "#5a5044", "#948672"
    glow = "#e8a040"
    a.box(-0.07, -0.02, -0.03, 0.02, 0, 8, rock_l, rock, rock_d, sw=1)  # legs
    a.box(0.02, 0.07, -0.03, 0.02, 0, 8, rock_l, rock, rock_d, sw=1)
    a.poly([(-10, -8), (-12, -20), (-6, -28), (6, -29), (12, -20), (10, -8)], rock, INK, 1.4)  # body
    a.poly([(0, -29), (6, -29), (12, -20), (10, -8), (0, -8)], rock_d, stroke=None, opacity=0.6)
    a.line([(-6, -12), (-2, -18), (-5, -23)], glow, 1.6)  # glowing cracks
    a.line([(4, -11), (2, -17), (6, -21)], glow, 1.4)
    for (x, y, r) in [(-15, -18, 4.5), (-17, -11, 3.5), (15, -19, 4.5), (17, -12, 3.8)]:  # boulder fists
        a.ellipse(x, y, r, r * 0.9, rock_l if x < 0 else rock, INK, 1.2)
    a.ellipse(0, -33, 6, 5, rock_l, INK, 1.3)  # head
    a.ellipse(-2, -33.5, 1.2, 1, glow)
    a.ellipse(2.5, -33.5, 1.2, 1, glow)
    a.poly([(-3, -38), (-1, -42), (1, -38)], "#6a9a4a", INK, 0.8)  # moss tuft
    a.save("unit_earth_elemental")


def thornling():
    """The druid's summon: a squat walking bramble of twisted vines, thorns all
    over, root-feet, two amber eyes and one small pink flower."""
    a = Art()
    a.shadow(12, 5, opacity=0.4)
    vine, vine_d, vine_l = "#3e5a2c", "#2a3e1e", "#5a7a3a"
    for (x0, x1) in [(-6, -9), (5, 8)]:  # root-feet
        a.line([(x0, -8), (x0 - 1, -3), (x1, 0)], INK, 3.6)
        a.line([(x0, -8), (x0 - 1, -3), (x1, 0)], "#6a4a28", 2)
    a.poly([(-11, -8), (-13, -20), (-8, -30), (0, -33), (8, -30), (13, -20), (11, -8), (0, -6)], vine, INK, 1.4)  # body
    a.poly([(0, -33), (8, -30), (13, -20), (11, -8), (0, -6)], vine_d, stroke=None, opacity=0.6)
    for pts in [[(-10, -12), (-4, -20), (-9, -27)], [(9, -11), (3, -19), (8, -26)], [(-5, -9), (1, -16), (-2, -28)]]:  # twisting vines
        a.line(pts, vine_l, 1.6)
    for (x, y, dx, dy) in [(-13, -20, -4, -1), (-11, -27, -3, -3), (13, -20, 4, -1), (11, -27, 3, -3), (-12, -12, -4, 1), (12, -12, 4, 1), (-3, -33, -1, -4), (4, -33, 1, -4)]:  # thorns
        a.poly([(x, y - 1.2), (x + dx, y + dy), (x, y + 1.2)], "#c8b890", INK, 0.6)
    for (x, y, r) in [(-15, -17, 3.8), (15, -18, 3.8)]:  # bramble fists
        a.ellipse(x, y, r, r * 0.9, vine_l if x < 0 else vine, INK, 1.2)
    a.ellipse(-3, -24, 1.6, 1.4, "#f0c040")  # eyes
    a.ellipse(3, -24, 1.6, 1.4, "#f0c040")
    for k in range(5):  # the flower
        ang = k / 5 * math.tau
        a.ellipse(6 + math.cos(ang) * 2.2, -31 + math.sin(ang) * 2.2, 1.6, 1.6, "#e88ab0", INK, 0.5)
    a.ellipse(6, -31, 1.2, 1.2, "#f8e060")
    a.save("unit_thornling")


def caravan(name, cover):
    """A co-op help caravan (docs/multiplayer-design.md §7.1): a two-wheeled cart under an
    arched canvas cover in the sender's colour (`cover`), pulled by a brown horse (faces
    right). Covered, so it can't be mistaken for an open trade cart, which can be attacked."""
    a = Art()
    a.ellipse(0, 1, 26, 7, "#000", opacity=0.35)
    wood, wood_d = WOOD, WOOD_D
    # cart bed
    a.poly([(-24, -12), (2, -12), (4, -20), (-22, -20)], wood, INK, 1.3)
    a.poly([(-24, -12), (2, -12), (2, -9), (-24, -9)], wood_d, INK, 1.1)
    # the cover: an arch over the bed, its lower hem shaded, hoops showing through
    arch = [(-23 + 26 * t, -20 - 17 * math.sin(math.pi * t)) for t in (i / 12 for i in range(13))]
    a.poly(arch, cover, INK, 1.3)
    a.poly([(-22, -20), (2, -20), (1.2, -23), (-21.2, -23)], shade(cover, 0.78), None, 0)
    for x in (-17, -10, -3):
        h = 17 * math.sin(math.pi * (x + 23) / 26)
        a.line([(x, -20), (x, -20 - h)], shade(cover, 0.68), 1.1)
    a.ellipse(-12, -6, 6.5, 6.5, wood_d, INK, 1.4)  # wheel
    a.ellipse(-12, -6, 2, 2, "#3a2a1a")
    for d in ((-4.5, 0), (4.5, 0), (0, -4.5), (0, 4.5)):
        a.line([(-12, -6), (-12 + d[0], -6 + d[1])], INK, 0.9)
    a.line([(3, -14), (12, -12)], wood_d, 2.2)  # shafts
    # horse
    horse, horse_d = "#7a5234", "#5a3a22"
    for x in (13, 17, 25, 29):  # legs
        a.line([(x, -12), (x + (1 if x % 2 else -1), 0)], INK, 3.2)
        a.line([(x, -12), (x + (1 if x % 2 else -1), 0)], horse_d, 1.8)
    a.ellipse(21, -16, 10, 6, horse, INK, 1.3)  # body
    a.poly([(28, -19), (32, -29), (36, -30), (38, -26), (33, -18)], horse, INK, 1.2)  # neck + head
    a.poly([(34, -30), (40, -27), (39, -24), (35, -25)], horse, INK, 1.0)
    a.poly([(29, -21), (31, -30), (33, -30), (31, -20)], "#2a1a10")  # mane
    a.ellipse(36, -28, 0.9, 0.9, "#111")
    a.line([(11, -17), (6, -10)], "#2a1a10", 2)  # tail
    a.poly([(16, -21), (26, -21), (26, -17), (16, -17)], CRIMSON, INK, 0.8, opacity=0.9)  # harness blanket
    a.save(name)


def caravans():
    """The neutral help wagon (scenes, icons) and one in each village's colour."""
    caravan("unit_caravan", "#d8ccae")
    for i, col in enumerate(village_colors()):
        caravan("unit_caravan_c%d" % i, col)


def shield_bearer():
    """Smaller soldier almost hidden behind a big tower shield (planks, iron rim, crest)."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-8, -24), (-12, -32)], INK, 3)  # spear shaft behind
            a.line([(-8, -24), (-12, -32)], WOOD_L, 1.6)
        else:
            a.poly([(1, -2), (15, -4), (15, -36), (1, -38)], "#6a4a2c", INK, 1.6)  # the shield
            for x in (5.5, 10.5):
                a.line([(x, -2.6), (x, -37.2)], "#4a3220", 1)
            a.poly([(1, -2), (15, -4), (15, -36), (1, -38)], "none", "#9aa0a8", 1.8)  # iron rim
            a.ellipse(8, -20, 3.4, 4.2, "#9aa0a8", INK, 1)  # boss
            a.poly([(5, -30), (8, -34), (11, -30), (8, -26)], CRIMSON, INK, 0.8)  # crest

    def hat(a):
        a.raw('<path d="M-6.5,-33 Q-6,-41 0,-41 Q6,-41 6.5,-33 Z" fill="#8a9098" stroke="%s" stroke-width="1.2"/>' % INK, [(-7, -42), (7, -32)])
    person("unit_shield_bearer", ("#5a4a3a", "#463a2c"), hat=hat, extra=extra)


def shield_bearer_branches():
    """The shield bearer's specialisations: warrior, berserker, halberdier."""
    steel, steel_d = "#9aa0a8", "#6a7078"

    def warrior(a, layer):
        if layer == "back":
            a.ellipse(-8, -20, 7, 8, WOOD, INK, 1.4)  # round shield on his back arm
            a.ellipse(-8, -20, 7, 8, "none", steel, 1.6)
            a.ellipse(-8, -20, 2.2, 2.4, steel, INK, 0.8)
        else:
            a.poly([(-7, -27), (7, -27), (6, -11), (-6, -11)], steel_d, INK, 1.1)  # mail
            for y in (-24, -20, -16):
                a.line([(-6, y), (6, y)], "#555b62", 0.7)
            a.poly([(-3.5, -27), (3.5, -27), (3, -9), (-3, -9)], CRIMSON, INK, 0.9)  # tabard
            a.line([(4, -21), (10, -27)], INK, 4)  # arm raised
            a.line([(10, -27), (14, -46)], INK, 3.6)  # sword
            a.line([(10, -27), (14, -46)], "#d8dde2", 2)
            a.line([(7.5, -27.5), (12.5, -26.5)], GOLD, 1.8)  # crossguard

    def warrior_helm(a):
        a.raw('<path d="M-7,-31 Q-7,-42 0,-42 Q7,-42 7,-31 Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (steel, INK), [(-8, -43), (8, -30)])
        a.line([(0, -42), (0, -31)], steel_d, 1.4)  # nose guard ridge
        a.raw('<path d="M-6,-39 Q-12,-42 -11,-48 Q-8,-43 -4,-41 Z" fill="#e8dcc0" stroke="%s" stroke-width="0.9"/>' % INK, [(-12, -49), (-4, -38)])
        a.raw('<path d="M6,-39 Q12,-42 11,-48 Q8,-43 4,-41 Z" fill="#e8dcc0" stroke="%s" stroke-width="0.9"/>' % INK, [(4, -49), (12, -38)])
    person("unit_warrior", (steel_d, "#555b62"), hat=warrior_helm, extra=warrior)

    def berserker(a, layer):
        if layer == "back":
            a.raw('<path d="M-4,-29 Q-12,-28 -11,-20 L-12,-12 L-10,-14 L-9,-11 L-7,-13 L-5,-11 Z" fill="#7a5a3a" stroke="%s" stroke-width="1"/>' % INK, [(-12, -30), (-4, -11)])  # shaggy fur cloak
            for (x, y) in ((-9, -24), (-8, -19), (-10, -16)):
                a.line([(x, y), (x + 1.5, y + 2)], "#a07a52", 1)
        else:
            a.poly([(-6, -27), (6, -27), (6, -14), (-6, -14)], "#d0a080", INK, 1)  # bare chest
            a.line([(-6, -18), (6, -18)], "#5a3a22", 2.4)  # belt
            a.line([(4, -21), (11, -24)], INK, 4.2)  # arm
            a.line([(4, -21), (11, -24)], "#d0a080", 2.6)
            a.line([(9, -6), (13, -44)], INK, 3.4)  # great axe
            a.line([(9, -6), (13, -44)], WOOD_L, 1.8)
            a.raw('<path d="M12,-44 Q22,-46 22,-36 Q16,-38 12,-36 Z" fill="#b8bec6" stroke="%s" stroke-width="1.1"/>' % INK, [(11, -47), (23, -35)])
            a.raw('<path d="M12,-44 Q4,-46 5,-38 Q9,-39 12,-37 Z" fill="#b8bec6" stroke="%s" stroke-width="1.1"/>' % INK, [(4, -47), (13, -36)])

    def wild_hair(a):
        # a mane over the top and back of the head, spiky, leaving the face free
        a.raw('<path d="M-7,-30 L-10,-33 L-8,-36 L-10,-40 L-6,-40 L-5,-44 L-1,-41 L1,-45 L3,-40 L7,-41 L5,-37 Q2,-39 -2,-37 Q-5,-35 -5,-30 Z" fill="#b8481e" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % INK, [(-11, -46), (8, -29)])
        # a full beard on the chin (he faces right)
        a.raw('<path d="M-2,-31 Q0,-28 6,-30 Q7,-27 5,-24 L3,-25 L2,-22 L0,-25 L-2,-23 Q-3,-27 -2,-31 Z" fill="#b8481e" stroke="%s" stroke-width="1" stroke-linejoin="round"/>' % INK, [(-3, -32), (8, -21)])
    person("unit_berserker", ("#6a4a2c", "#5a3c22"), hat=wild_hair, skin="#d0a080", extra=berserker)

    def halberdier(a, layer):
        if layer == "front":
            a.poly([(-6, -27), (6, -27), (5, -14), (-5, -14)], steel, INK, 1.1)  # breastplate
            a.line([(0, -26), (0, -15)], steel_d, 1)
            a.line([(4, -20), (9, -21)], INK, 4)  # arm
            a.line([(9, 0), (10, -54)], INK, 3.2)  # the long shaft
            a.line([(9, 0), (10, -54)], WOOD_L, 1.7)
            a.raw('<path d="M10,-50 Q19,-50 18,-41 Q14,-43 10,-42 Z" fill="#c8ced6" stroke="%s" stroke-width="1.1"/>' % INK, [(9, -51), (19, -40)])  # axe blade
            a.poly([(9, -47), (5, -49), (9, -45)], "#c8ced6", INK, 0.9)  # back hook
            a.poly([(9.2, -54), (10.2, -62), (11.2, -54)], "#c8ced6", INK, 1)  # spike

    def kettle_hat(a):
        a.raw('<path d="M-10,-34 L10,-34 L6,-37 Q6,-43 0,-43 Q-6,-43 -6,-37 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (steel, INK), [(-11, -44), (11, -33)])
    person("unit_halberdier", ("#3a4a6a", "#2c3a54"), hat=kettle_hat, extra=halberdier)


def crossbowman():
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -26), (6, -26), (6, -16), (-6, -16)], "#6a5236", INK, 0.8)  # leather jerkin
            a.line([(0, -20), (16, -22)], INK, 4)  # stock
            a.line([(0, -20), (16, -22)], WOOD, 2.2)
            a.raw('<path d="M13,-31 Q18,-22 13,-13" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % INK, [(12, -32), (18, -12)])
            a.raw('<path d="M13,-31 Q18,-22 13,-13" fill="none" stroke="#7a7a80" stroke-width="1.6" stroke-linecap="round"/>', [(12, -32), (18, -12)])
            a.line([(13, -31), (9, -22), (13, -13)], "#d8d0b8", 0.7)
            a.line([(9, -21), (19, -22.5)], "#b08a58", 1.2)  # bolt

    def hat(a):
        a.raw('<path d="M-8,-35 Q0,-44 8,-35 Z" fill="#5a4630" stroke="%s" stroke-width="1.2"/>' % INK, [(-9, -45), (9, -34)])
        a.line([(-9, -35), (9, -35)], INK, 1.6)
    person("unit_crossbowman", ("#4a3e2e", "#3a3022"), hat=hat, extra=extra)


def swiftbowman():
    """Fancier archer: green and gold, feathered cap, a bow with several strings."""
    def extra(a, layer):
        if layer == "back":
            a.poly([(-9, -16), (-5, -16), (-3, -31), (-7, -31)], "#6a4a2a", INK, 1)
            for x in (-7.5, -6, -4.5):
                a.line([(x, -31), (x - 1, -36)], "#e8d890", 1)
        else:
            a.poly([(-7, -24), (7, -18), (7, -15), (-7, -21)], GOLD, INK, 0.8)  # golden sash
            a.line([(4, -21), (11, -22)], INK, 4)
            a.raw('<path d="M9,-40 Q21,-22 9,-4" fill="none" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % INK, [(8, -41), (20, -3)])
            a.raw('<path d="M9,-40 Q21,-22 9,-4" fill="none" stroke="#c8a050" stroke-width="1.8" stroke-linecap="round"/>', [(8, -41), (20, -3)])
            for dx in (0.0, 1.6, 3.2):  # three strings
                a.line([(9 + dx * 0.3, -40), (9 - dx, -22), (9 + dx * 0.3, -4)], "#f0ecd8", 0.6)

    def hat(a):
        a.raw('<path d="M-7,-35 Q0,-43 7,-35 L6,-33 L-6,-33 Z" fill="#2f6a3a" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -44), (8, -32)])
        a.raw('<path d="M3,-40 Q10,-50 14,-47 Q9,-43 5,-38 Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (GOLD, INK), [(2, -51), (15, -37)])
    person("unit_swiftbowman", ("#2f5a36", "#244a2a"), extra=extra, hat=hat)


def fire_summoner():
    def extra(a, layer):
        if layer == "front":
            a.poly([(-6, -26), (6, -26), (4, -22), (-4, -22)], "#c8501e", INK, 0.8)
            a.line([(4, -22), (11, -24)], INK, 4.2)
            a.line([(4, -22), (11, -24)], "#5a2418", 2.6)
            a.ellipse(13, -27, 9, 9, "#ff8a30", opacity=0.35)
            a.raw('<path d="M13,-35 Q18,-28 15,-24 Q13,-21 11,-24 Q8,-28 13,-35 Z" fill="#ffb040" stroke="%s" stroke-width="1"/>' % INK, [(8, -36), (18, -21)])
            a.ellipse(13, -26, 1.6, 1.6, "#fff0b0")

    def hat(a):
        a.raw('<path d="M-9,-36 L9,-36 L3,-40 L-1,-57 L-4,-40 Z" fill="#6a2418" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-10, -58), (10, -35)])
        a.line([(-6, -38.5), (6, -38.5)], "#ff8a30", 1.6)
    person("unit_fire_summoner", ("#5a2418", "#461a12"), hat=hat, robe=True, extra=extra)


def fire_elemental():
    """A small living flame, hovering (no feet): the game bobs and flickers it."""
    a = Art()
    a.shadow(8, 3.5, opacity=0.3)
    a.raw('<path d="M0,-40 Q9,-30 10,-20 Q11,-8 0,-6 Q-11,-8 -10,-20 Q-9,-28 -4,-33 Q-3,-26 0,-26 Q1,-33 0,-40 Z" fill="#ff7a20" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-11, -41), (11, -5)])
    a.raw('<path d="M0,-31 Q6,-24 6,-17 Q6,-10 0,-10 Q-6,-10 -6,-17 Q-5,-22 -2,-25 Q-1,-20 1,-21 Q2,-26 0,-31 Z" fill="#ffc040"/>', [(-7, -32), (7, -9)])
    a.ellipse(0, -14, 3.2, 3.6, "#fff4c0")
    a.ellipse(-2.5, -19, 1.2, 1.4, INK)
    a.ellipse(2.5, -19, 1.2, 1.4, INK)
    a.save("unit_fire_elemental")


def mage(name, robe, trim, staff_top, glow, tome, hood=None):
    """Apprentice-style mage: staff in one hand, a thick tome in the other; no hat, no beard."""
    def extra(a, layer):
        if layer == "back":
            a.line([(-9, -2), (-9, -44)], INK, 3.4)  # staff
            a.line([(-9, -2), (-9, -44)], "#4a3a2c", 1.8)
            a.ellipse(-9, -46, 8, 8, glow, opacity=0.3)
            staff_top(a)
        else:
            a.poly([(-6, -27), (6, -27), (4, -22), (-4, -22)], trim, INK, 0.8)  # collar
            a.line([(4, -21), (9, -19)], INK, 4)  # arm with the tome
            a.poly([(7, -24), (15, -22), (15, -13), (7, -15)], tome, INK, 1.2)
            a.line([(8, -22), (14, -20.5)], "#e8e0c8", 1)
            a.line([(8, -18), (14, -16.5)], "#e8e0c8", 1)

    def hair(a):
        a.raw('<path d="M-6,-34 Q-6,-40 0,-40 Q6,-40 6,-34 Q3,-37 0,-37 Q-3,-37 -6,-34 Z" fill="#3a2a1e" stroke="%s" stroke-width="1"/>' % INK, [(-7, -41), (7, -33)])
    person(name, robe, hood=hood, hat=None if hood else hair, robe=True, extra=extra)


def mages():
    def orb(col, core):
        def f(a):
            a.ellipse(-9, -46, 3.8, 3.8, col, INK, 1.2)
            a.ellipse(-10, -47, 1.3, 1.3, core)
        return f

    def flame(a):
        a.raw('<path d="M-9,-54 Q-5,-48 -6,-45 Q-8,-42 -9,-44 Q-12,-47 -9,-54 Z" fill="#ffb040" stroke="%s" stroke-width="1"/>' % INK, [(-13, -55), (-5, -41)])

    def crystal(a):
        a.poly([(-9, -54), (-6, -47), (-9, -42), (-12, -47)], "#bfe8ff", INK, 1)
        a.line([(-9, -54), (-9, -42)], "#ffffff", 0.6)

    def leaf(a):
        a.raw('<path d="M-9,-53 Q-3,-48 -9,-42 Q-15,-48 -9,-53 Z" fill="#7ad06a" stroke="%s" stroke-width="1"/>' % INK, [(-15, -54), (-3, -41)])
        a.line([(-9, -52), (-9, -43)], "#3a7a30", 0.7)

    def ring(a):
        a.ellipse(-9, -47, 4.6, 4.6, "none", "#c89cff", 1.6)
        a.ellipse(-9, -47, 1.8, 1.8, "#e8d8ff", INK, 0.8)

    mage("unit_apprentice", ("#4a4a50", "#38383e"), "#6a6a74", orb("#3a5ab0", "#b8c8ff"), "#3a5ab0", "#5a3a2a")
    mage("unit_fire_mage", ("#7a2a20", "#5e1e18"), "#d8602a", flame, "#ff8a30", "#4a1a12")
    mage("unit_ice_mage", ("#5a8ab0", "#467090"), "#cfeaff", crystal, "#a8dcff", "#2a4a6a")
    mage("unit_healing_mage", ("#3a7a44", "#2c6034"), "#bfe8a0", leaf, "#8ae08a", "#e8e0c8")
    mage("unit_spatial_mage", ("#4a3070", "#3a2458"), "#b08ae0", ring, "#b08ae0", "#2a1a40")


def acolytes():
    """The acolyte line: robed in cream and gold. The acolyte prays (hands folded, head bowed) and
    raises its arms to cast (unit_acolyte_cast). The game draws their glow behind them."""
    robe = ("#e4dccb", "#c8bea8")

    def hood(col):
        def f(a):  # a deep cowl, bowed forward
            a.raw('<path d="M-7,-29 Q-9,-43 1,-43 Q9,-42 8,-33 L5,-32 Q2,-38 -3,-36 Q-5,-33 -5,-28 Z" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (col, INK), [(-9, -44), (9, -28)])
        return f

    def praying(a, layer):
        if layer == "front":
            a.poly([(-2, -27), (2, -27), (1.5, -6), (-1.5, -6)], GOLD, INK, 0.7)  # stole
            a.line([(-3, -24), (4, -20)], INK, 4.2)  # arm to the folded hands
            a.line([(-3, -24), (4, -20)], robe[1], 2.6)
            a.poly([(4, -26), (7, -25), (7, -19), (4, -19)], "#d8b08c", INK, 1)  # hands together
    person("unit_acolyte", robe, hat=hood("#d4cab4"), robe=True, extra=praying)

    def casting(a, layer):
        if layer == "back":
            a.line([(-4, -26), (-10, -42)], INK, 4.2)  # the far arm, raised
            a.line([(-4, -26), (-10, -42)], robe[1], 2.6)
            a.ellipse(-10, -43.5, 2.2, 2.2, "#d8b08c", INK, 0.9)
        else:
            a.poly([(-2, -27), (2, -27), (1.5, -6), (-1.5, -6)], GOLD, INK, 0.7)
            a.line([(4, -26), (11, -42)], INK, 4.2)
            a.line([(4, -26), (11, -42)], robe[0], 2.6)
            a.ellipse(11, -43.5, 2.2, 2.2, "#d8b08c", INK, 0.9)
            a.ellipse(0, -48, 8, 5, "#fff2c0", opacity=0.45)
            a.ellipse(0, -48, 3, 2, "#fffbe6", opacity=0.9)

    def raised_hood(a):  # head up while casting
        a.raw('<path d="M-7,-30 Q-8,-43 0,-43 Q8,-43 7,-34 L4,-36 Q0,-40 -4,-36 Q-5,-33 -5,-28 Z" fill="#d4cab4" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-8, -44), (8, -28)])
    person("unit_acolyte_cast", robe, hat=raised_hood, robe=True, extra=casting)

    def inquisitor(a, layer):
        if layer == "back":
            a.poly([(-10, -12), (-4, -12), (-4, -28), (-10, -28)], "#2a1a1a", INK, 1)  # cloak
        else:
            a.poly([(-6, -27), (6, -27), (5, -12), (-5, -12)], "#8a8f96", INK, 1)  # breastplate
            a.line([(0, -25), (0, -14)], GOLD, 2.2)  # the holy cross on it
            a.line([(-3.5, -21.5), (3.5, -21.5)], GOLD, 2.2)
            a.line([(4, -20), (10, -22)], INK, 4)  # arm
            a.line([(10, -8), (12, -40)], INK, 3.4)  # warhammer
            a.line([(10, -8), (12, -40)], WOOD_L, 1.8)
            a.poly([(6, -44), (18, -42), (18, -36), (6, -38)], "#8a8f96", INK, 1.2)
            a.line([(12, -41), (12, -39)], GOLD, 1.2)

    def helm(a):
        a.raw('<path d="M-7,-31 Q-7,-42 0,-42 Q7,-42 7,-31 L7,-29 L-7,-29 Z" fill="#6a1a20" stroke="%s" stroke-width="1.2"/>' % INK, [(-8, -43), (8, -28)])
        a.line([(0, -42), (0, -46)], GOLD, 1.6)
        a.line([(-2, -44.5), (2, -44.5)], GOLD, 1.6)
    person("unit_inquisitor", ("#3a2224", "#2c1a1c"), hat=helm, extra=inquisitor)

    def priest(a, layer):
        if layer == "back":
            a.line([(-9, -2), (-9, -48)], INK, 3.4)  # crosier
            a.line([(-9, -2), (-9, -48)], GOLD_D, 1.8)
            a.ellipse(-9, -52, 9, 9, "#fff2c0", opacity=0.35)
            a.ellipse(-9, -52, 4.2, 4.2, GOLD, INK, 1.1)  # a sun disc
            for k in range(8):
                ang = k * math.pi / 4
                a.line([(-9 + math.cos(ang) * 5, -52 + math.sin(ang) * 5), (-9 + math.cos(ang) * 7.5, -52 + math.sin(ang) * 7.5)], GOLD, 1.1)
        else:
            a.poly([(-2.5, -27), (2.5, -27), (2, -3), (-2, -3)], GOLD, INK, 0.8)  # broad stole
            a.line([(-1, -14), (1, -14)], "#fffbe6", 1)
            a.line([(4, -22), (9, -18)], INK, 4)
            a.ellipse(9.5, -17.5, 2.2, 2.2, "#d8b08c", INK, 0.9)

    def mitre(a):
        a.raw('<path d="M-6,-36 L-5,-47 L0,-52 L5,-47 L6,-36 Z" fill="#f2ecdc" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % INK, [(-7, -53), (7, -35)])
        a.line([(0, -51), (0, -37)], GOLD, 1.6)
        a.line([(-6, -37.5), (6, -37.5)], GOLD, 1.6)
    person("unit_high_priest", ("#f0ead8", "#d4ccb6"), hat=mitre, robe=True, extra=priest)


def spatial_archmage():
    """Civilian: robed in violet and gold, a rune halo floating above the head."""
    def extra(a, layer):
        if layer == "back":
            a.ellipse(0, -48, 13, 4.5, "none", "#c89cff", 1.6)
            for k in range(6):
                ang = k * math.pi / 3
                a.ellipse(math.cos(ang) * 13, -48 + math.sin(ang) * 4.5, 1.5, 1.5, GOLD)
        else:
            a.poly([(-7, -26), (7, -26), (5, -12), (-5, -12)], "none", GOLD, 1.2)
            a.line([(10, 0), (10, -46)], INK, 3.4)
            a.line([(10, 0), (10, -46)], "#2a1a40", 1.8)
            a.ellipse(10, -49, 5, 5, "#b08ae0", INK, 1.2)
            a.ellipse(10, -49, 10, 10, "#b08ae0", opacity=0.3)

    def hood(a):
        a.raw('<path d="M-7,-30 Q-8,-43 0,-43 Q8,-43 7,-34 L4,-36 Q0,-40 -4,-36 Q-5,-33 -5,-28 Z" fill="#3a2458" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-8, -44), (8, -28)])
        a.line([(-6, -37), (6, -39)], GOLD, 1.2)
    person("unit_spatial_archmage", ("#4a3070", "#3a2458"), hat=hood, robe=True, extra=extra)


def projectiles():
    a = Art()  # light arrow with pale fletching
    a.line([(-12, 0), (10, 0)], INK, 2)
    a.line([(-12, 0), (10, 0)], "#d8c090", 1)
    a.poly([(9, -2), (14, 0), (9, 2)], "#c8c8c8", INK, 0.8)
    a.poly([(-15, -2.5), (-10, 0), (-15, 2.5), (-12, 0)], "#e8e0a0", INK, 0.6)
    a.save("swift_arrow")
    a = Art()  # short heavy crossbow bolt
    a.line([(-8, 0), (8, 0)], INK, 3.4)
    a.line([(-8, 0), (8, 0)], "#8a6a40", 2)
    a.poly([(7, -3), (13, 0), (7, 3)], "#7a7a80", INK, 1)
    a.poly([(-10, -2.5), (-6, 0), (-10, 2.5)], "#5a5a5a", INK, 0.6)
    a.save("crossbow_bolt")

    def orb(name, outer, mid, core, swirl):
        o = Art()
        gid = name.replace("_", "")
        o.raw('<defs><radialGradient id="%s"><stop offset="0" stop-color="%s"/><stop offset="0.45" stop-color="%s"/><stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient></defs>' % (gid, core, mid, outer), [(0, 0)])
        o.ellipse(0, 0, 14, 14, "url(#%s)" % gid)
        for k in range(3):
            ang = k * 2.094
            x0, y0 = math.cos(ang) * 3, math.sin(ang) * 3
            x1, y1 = math.cos(ang + 1.6) * 10, math.sin(ang + 1.6) * 10
            o.raw('<path d="M%s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % (fmt(x0), fmt(y0), fmt(math.cos(ang + 0.8) * 9), fmt(math.sin(ang + 0.8) * 9), fmt(x1), fmt(y1), swirl), [(-11, -11), (11, 11)])
        return o

    orb("arcane_orb", "#1a2a80", "#3a5ad0", "#d0dcff", "#8aa8ff").save("arcane_orb")
    fb = orb("fireball", "#c83010", "#ff8020", "#fff0a0", "#ffe070")
    for (x, y) in [(-9, -7), (8, -9), (10, 5), (-7, 9), (1, -12)]:  # sparkles
        fb.ellipse(x, y, 1.4, 1.4, "#fff4c0")
    fb.save("fireball")
    fr = orb("frost_orb", "#5aa8e0", "#a8dcff", "#ffffff", "#e0f4ff")
    fr.poly([(0, -8), (2, 0), (0, 8), (-2, 0)], "#ffffff", None)
    fr.save("frost_orb")
    orb("warp_orb", "#5a2a90", "#a878e8", "#f0e0ff", "#d8c0ff").save("warp_orb")


def village_colors():
    """Config.VILLAGE_COLORS, read from config.gd (the one place they are set)."""
    with open(os.path.join(ROOT, "scripts", "core", "config.gd")) as f:
        for line in f:
            if line.startswith("const VILLAGE_COLORS"):
                return ["#" + c for c in re.findall(r'Color\("([0-9a-fA-F]{6})"\)', line)]
    raise SystemExit("gen_art: Config.VILLAGE_COLORS not found in config.gd")


def hero():
    """Hero: steel helmet with a plume, blue-steel armour, a cape, raised sword.
    unit_hero has a crimson cape and plume; in a game of several villages each
    hero wears her village's colour instead (unit_hero_c<i>, i an index into
    Config.VILLAGE_COLORS): the plume in the colour itself, the cape a darker
    shade of it so it reads as cloth among the dark art."""
    hero_art("unit_hero", CRIMSON, CRIMSON)
    for i, col in enumerate(village_colors()):
        hero_art("unit_hero_c%d" % i, shade(col, 0.68), col)


def hero_art(name, cape, plume):
    def extra(a, layer):
        if layer == "back":
            a.poly([(-8, -27), (-4, -27), (-3, -4), (-11, -6)], cape, INK, 1.1)  # cape
        else:
            a.poly([(-6, -14), (6, -14), (5, -26), (-5, -26)], "#6a7a8e", INK, 1)  # breastplate
            a.line([(0, -26), (0, -15)], "#4a5666", 1.2)
            a.poly([(-7, -26), (-3, -27), (-3, -23), (-8, -23)], "#8a96a6", INK, 1)  # pauldron
            a.line([(4, -22), (10, -27)], INK, 4)  # sword arm
            a.line([(4, -22), (10, -27)], "#6a7a8e", 2.4)
            a.line([(8, -29), (13, -25)], INK, 2.4)  # guard
            a.line([(8, -29), (13, -25)], GOLD, 1.2)
            a.poly([(10, -28), (11.5, -26.5), (20, -44), (18.5, -45)], "#d0d4dc", INK, 1)  # blade
            a.line([(11, -27.5), (19, -44)], "#ffffff", 0.6)

    def hat(a):
        a.raw('<path d="M-6.5,-32 Q-7,-41 0,-41 Q7,-41 6.5,-32 L4,-31 L4,-34 L-4,-34 L-4,-31 Z" fill="#9aa4b2" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % INK, [(-8, -42), (8, -30)])
        a.raw('<path d="M-1,-41 Q-2,-50 6,-50 Q2,-46 3,-41 Z" fill="%s" stroke="%s" stroke-width="1"/>' % (plume, INK), [(-2, -51), (7, -40)])  # plume
        a.line([(0, -40), (0, -34)], "#6a7482", 1.2)
    person(name, ("#3a4656", "#2c3644"), hat=hat, extra=extra)


# ----------------------------------------------------------------------- miner

def miner():
    """Miner with a pickaxe over the shoulder and a lamp on his leather cap."""
    def extra(a, layer):
        if layer == "back":
            a.line([(8, -14), (-8, -38)], INK, 3.6)  # haft over the shoulder
            a.line([(8, -14), (-8, -38)], WOOD_L, 2)
            a.raw('<path d="M-17,-31 Q-12,-40 -8,-39 Q-3,-41 2,-46 Q-3,-38 -7,-36 Q-12,-35 -17,-31 Z" fill="#8a8a8a" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % INK,
                  [(-18, -47), (3, -30)])
        else:
            for (x, y) in [(-4, -19), (3, -14), (-2, -24)]:  # dust on the clothes
                a.ellipse(x, y, 1.8, 1.2, "#8a8274", opacity=0.6)
            a.line([(-6, -25), (4, -13)], "#3a2c1c", 1.8)  # strap
            a.line([(4, -21), (8, -16)], INK, 4)  # arm holding the haft
            a.ellipse(8, -15, 1.8, 1.8, "#d8b08c", INK, 0.8)

    def hat(a):
        a.raw('<path d="M-7,-34 Q-7,-43 0,-43 Q7,-43 7,-34 Z" fill="#5a4030" stroke="%s" stroke-width="1.3"/>' % INK, [(-8, -44), (8, -33)])
        a.line([(-7.5, -34.5), (9, -34.5)], INK, 2)
        a.ellipse(6.5, -39, 7, 7, GLOW, opacity=0.25)
        a.poly([(4.5, -41.5), (8.5, -41.5), (8.5, -37), (4.5, -37)], "#6a6a6a", INK, 0.9)
        a.ellipse(7.2, -39.2, 1.6, 1.8, GLOW)
        a.ellipse(-2, -30, 2, 1, "#8a8274", opacity=0.6)  # sooty cheek
    person("unit_miner", ("#6a6254", "#524b40"), hat=hat, extra=extra)
