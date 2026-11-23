"""The upgrade dialog's unit cards: `unit_card_<kind>`, one square bust per Config.MILITARY key.

The people are drawn by faces.py, in the style the cutscene portraits share. Each card's person
(CAST) is built from parts; the kind shows in the clothes and the gear, in the colours of its map
sprite (tools/art/units.py). No jewellery and no make-up: faces are bare."""

import math
import os
import re

from .core import CRIMSON, GOLD, GOLD_D, INK, ROOT, WOOD, WOOD_L
from .faces import (LINE, STEEL, STEEL_D, STEEL_L, bow, card, darker, glow, hair_back, hand, head,
                    hood, neck, person, pole, quiver, skin_of, sparkles, staff, tome, body)

DRAWN = set()

# Who is on each card: a person as faces.py describes it.
CAST = {
    "archer": dict(sex="f", age="young", skin=1, face="heart", hair=("center", "auburn"), eyes=("almond", "green"), nose="small", expr="firm"),
    "crossbowman": dict(sex="m", age="old", skin=2, face="square", hair=("short", "grey"), eyes=("narrow", "grey"), nose="broad", expr="frown", beard=("stubble_moustache", "grey")),
    "swiftbowman": dict(sex="m", age="young", skin=5, face="oval", hair=("curly", "black"), eyes=("round", "dark"), nose="broad", expr="grin"),
    "shield_bearer": dict(sex="f", age="adult", skin=3, face="square", hair=("ponytail", "black"), eyes=("almond", "brown"), nose="straight", expr="firm"),
    "warrior": dict(sex="m", age="adult", skin=1, face="square", hair=("short", "blond"), eyes=("almond", "blue"), nose="straight", expr="firm", beard=("full", "blond")),
    "berserker": dict(sex="f", age="young", skin=0, face="heart", hair=("wild", "red"), eyes=("round", "green"), nose="button", expr="grin_fierce", freckles=True),
    "halberdier": dict(sex="m", age="adult", skin=3, face="long", hair=("short", "black"), eyes=("narrow", "dark"), nose="straight", expr="neutral"),
    "summoner": dict(sex="m", age="old", skin=1, face="long", hair=("bald", "white"), eyes=("almond", "grey"), nose="hooked", expr="kind", beard=("long", "white")),
    "fire_summoner": dict(sex="f", age="adult", skin=6, face="oval", hair=("long", "black"), eyes=("almond", "amber"), nose="straight", expr="smirk"),
    "apprentice": dict(sex="f", age="young", skin=1, face="round", hair=("bob", "brown"), eyes=("round", "blue"), nose="button", expr="nervous", freckles=True),
    "fire_mage": dict(sex="m", age="adult", skin=4, face="square", hair=("crop", "black"), eyes=("almond", "brown"), nose="broad", expr="angry", beard=("goatee", "black")),
    "ice_mage": dict(sex="f", age="old", skin=0, face="long", hair=("bun", "white"), eyes=("almond", "grey"), nose="straight", expr="calm"),
    "healing_mage": dict(sex="f", age="adult", skin=5, face="round", hair=("afro", "dark"), eyes=("round", "brown"), nose="broad", expr="smile"),
    "spatial_mage": dict(sex="m", age="young", skin=0, face="long", hair=("long", "black"), eyes=("almond", "grey"), nose="straight", expr="neutral_raised", beard=("stubble", "black")),
    "acolyte": dict(sex="m", age="young", skin=2, face="oval", hair=("crop", "brown"), eyes=("almond", "brown"), nose="small", expr="serene"),
    "inquisitor": dict(sex="f", age="adult", skin=2, face="oval", hair=("long", "dark"), eyes=("narrow", "hazel"), nose="straight", expr="angry"),
    "high_priest": dict(sex="m", age="old", skin=5, face="oval", hair=("bald", "white"), eyes=("almond", "brown"), nose="broad", expr="kind", beard=("trim", "white")),
    "druid": dict(sex="f", age="old", skin=3, face="long", hair=("long", "grey"), eyes=("almond", "green"), nose="hooked", expr="smile"),
}


def _who(kind, dy=0):
    return person(CAST[kind], dy)


def _card(kind, top, bottom, art, light="#ffffff", light_op=0.12):
    DRAWN.add(kind)
    card("unit_card_" + kind, top, bottom, art, light, light_op)


# --- the cards --------------------------------------------------------------------------


def archers():
    # The archer: a green hood and tunic, a crimson sash, a quiver and a plain longbow.
    p = _who("archer")
    back, rim = hood("#2c3f29", p)
    _card("archer", "#2c3b2a", "#121a12", quiver("#d8d0b8") + neck(p) + body("#33472f", p)
          + f'\n    <path d="M18 44 L24 44 L50 66 L41 66Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.4"/>'
          + back + head(p, ears=False) + rim + bow("#8a5a30", p))

    # The crossbowman: a leather jerkin and a brimmed hat, the crossbow across the chest.
    p = _who("crossbowman")
    d = (38 / math.hypot(38, 18), -18 / math.hypot(38, 18))
    n = (-d[1], d[0])
    c = (47.0, 43.5)
    e1, e2 = (c[0] + n[0] * 12, c[1] + n[1] * 12), (c[0] - n[0] * 12, c[1] - n[1] * 12)
    ctrl, nock = (c[0] + d[0] * 7, c[1] + d[1] * 7), (c[0] - d[0] * 4, c[1] - d[1] * 4)
    tip = (c[0] + d[0] * 11, c[1] + d[1] * 11)

    def q(v):
        return "%.1f %.1f" % v
    _card("crossbowman", "#3b2f22", "#16110c", neck(p) + body("#4a3e2e", p)
          + f'\n    <path d="M16 46 Q32 50 48 46 L47 66 L17 66Z" fill="#6a5236" stroke="{INK}" stroke-width="{LINE}"/>'
          + head(p)
          + f'\n    <path d="M9 19 Q32 13 55 19 Q44 22 32 22 Q20 22 9 19Z" fill="#3e3020" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M20 18 Q20 4 32 4 Q44 4 44 18Z" fill="#5a4630" stroke="{INK}" stroke-width="{LINE}"/>'
          + pole(f"M10 62 L{q(nock)}", WOOD_L, 3.4)
          + f'\n    <path d="M{q(e1)} L{q(nock)} L{q(e2)}" stroke="#e8e0c8" stroke-width="0.9"/>'
          + f'\n    <path d="M{q(e1)} Q{q(ctrl)} {q(e2)}" stroke="{INK}" stroke-width="3.6" stroke-linecap="round"/>'
          + f'\n    <path d="M{q(e1)} Q{q(ctrl)} {q(e2)}" stroke="#8a8e96" stroke-width="2" stroke-linecap="round"/>'
          + f'\n    <path d="M{q(nock)} L{q(tip)}" stroke="#b08a58" stroke-width="1.4"/>'
          + hand(22, 56.5, p) + hand(38, 49, p))

    # The swiftbowman: green and gold, a feathered cap, a golden bow with three strings.
    p = _who("swiftbowman")
    _card("swiftbowman", "#2a4430", "#0f1a12", quiver("#e8d890") + neck(p) + body("#2f5a36", p)
          + f'\n    <path d="M18 44 L24 44 L50 66 L41 66Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>'
          + head(p)
          + f'\n    <path d="M17 19 Q19 5 33 5 Q47 5 48 18 Q40 14 32 14 Q24 14 17 19Z" fill="#2f6a3a" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M38 11 Q46 -3 60 -2 Q52 4 41 14Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.3"/>'
          + f'\n    <path d="M40 12 Q49 2 57 0" stroke="{GOLD_D}" stroke-width="0.8"/>'
          + bow("#c8a050", p, strings=3))


def shield_line():
    # The shield bearer: a steel cap, a spear in hand, a tower shield hiding most of the body.
    p = _who("shield_bearer")
    shield = (f'\n    <path d="M24 40 L60 36 L61 66 L25 66Z" fill="#6a4a2c" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
              f'\n    <path d="M36 39 L36.5 66 M48 37.6 L48.6 66" stroke="#4a3220" stroke-width="1.6"/>'
              f'\n    <path d="M25.6 41 L59 37.2 L60 66 L26 66Z" stroke="{STEEL}" stroke-width="2.2" stroke-linejoin="round"/>'
              f'\n    <ellipse cx="42.5" cy="55" rx="5" ry="5.4" fill="{STEEL}" stroke="{INK}" stroke-width="1.6"/>'
              f'\n    <path d="M42.5 40.5 L46 44.5 L42.5 48.5 L39 44.5Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.2"/>')
    _card("shield_bearer", "#3a3026", "#15110c", hair_back(p) + neck(p) + body("#5a4a3a", p) + head(p)
          + f'\n    <path d="M19 22 Q19 7 32 7 Q45 7 45 22Z" fill="#8a9098" stroke="{INK}" stroke-width="{LINE}"/>'
          + pole("M17.5 22 L46.5 22", STEEL_D, 1.6)
          + f'\n    <path d="M24 13 Q28 9.5 33 9.5" stroke="{STEEL_L}" stroke-width="1.4" stroke-linecap="round"/>'
          + pole("M9 66 L15 6", WOOD_L, 1.8)
          + f'\n    <path d="M15.4 0 L18 8 L15 11 L12.6 7.6Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.3"/>'
          + hand(11.2, 46, p) + shield)

    # The warrior: a horned helm, mail and a crimson tabard, a round shield on the arm, the sword up.
    p = _who("warrior")
    _card("warrior", "#2e3442", "#11141a", neck(p) + body(STEEL_D, p)
          + "".join(f'\n    <path d="M{8 + k * 3} {50 + (k % 2) * 4} q1.5 1.6 3 0" stroke="#4e545a" stroke-width="0.9"/>' for k in range(16))
          + f'\n    <path d="M25 46 L39 46 L37 66 L27 66Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.6"/>'
          + head(p)
          + f'\n    <path d="M19 21 Q18.5 6 32 6 Q45.5 6 45 21 Z" fill="{STEEL}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M30.4 19.6 L33.6 19.6 L33.2 28.4 L30.8 28.4Z" fill="{STEEL}" stroke="{INK}" stroke-width="1.3"/>'
          + pole("M18 21 L46 21", STEEL_D, 1.6)
          + f'\n    <path d="M22 13 Q26 8.6 30 8.4" stroke="{STEEL_L}" stroke-width="1.4" stroke-linecap="round"/>'
          + f'\n    <path d="M20 15 Q8 13 7 1 Q13 9 21 10Z" fill="#e8dcc0" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <path d="M44 15 Q56 13 57 1 Q51 9 43 10Z" fill="#e8dcc0" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <circle cx="12" cy="53" r="12.5" fill="{WOOD}" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <circle cx="12" cy="53" r="11" stroke="{STEEL}" stroke-width="2"/>'
          + f'\n    <circle cx="12" cy="53" r="3.4" fill="{STEEL}" stroke="{INK}" stroke-width="1.2"/>'
          + f'\n    <path d="M51 48 L54 8 L57 3 L59 9 L56 48Z" fill="#d8dde2" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M55.6 10 L53.6 46" stroke="#ffffff" stroke-width="0.9" opacity="0.7"/>'
          + pole("M47 48.5 L60 49.5", GOLD, 2.2)
          + hand(53, 54, p))

    # The berserker: a fur-trimmed leather vest, bare arms, a wild red mane, a great axe.
    p = _who("berserker")
    _card("berserker", "#42201a", "#140a08", hair_back(p) + neck(p)
          + f'\n    <path d="M6 66 Q7 48 21 44 Q32 49 43 44 Q57 48 58 66Z" fill="{skin_of(p)}" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M14 66 Q15 50 23 46 Q32 51 41 46 Q49 50 50 66Z" fill="#5a3c22" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M14 50 L18 46 L21 49 L24 45 L26 49 L29 46 L32 50 L35 46 L38 49 L40 45 L43 49 L46 46 L50 50 L47 53 L32 54 L17 53Z" fill="#7a5a3a" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'
          + head(p)
          + pole("M42 66 L57 10", WOOD_L, 2.4)
          + f'\n    <path d="M56 13 Q66 8 66 26 Q60 20 53 22Z" fill="#b8bec6" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <path d="M57 11 Q49 2 42 9 Q48 13 55 18Z" fill="#b8bec6" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + hand(48, 46, p), light="#ff6a30", light_op=0.16)

    # The halberdier: a blue coat with a steel breastplate, a wide kettle hat, the halberd.
    p = _who("halberdier")
    _card("halberdier", "#28324c", "#0d111b", neck(p) + body("#3a4a6a", p)
          + f'\n    <path d="M18 47 Q32 51 46 47 L45 66 L19 66Z" fill="{STEEL}" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M32 50 L32 66" stroke="{STEEL_D}" stroke-width="1.4"/>'
          + head(p)
          + f'\n    <path d="M8 21 L56 21 L46 15 Q46 3 32 3 Q18 3 18 15Z" fill="{STEEL}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M18.5 15 L45.5 15" stroke="{STEEL_D}" stroke-width="1.4"/>'
          + f'\n    <path d="M23 10 Q27 5.6 32 5.4" stroke="{STEEL_L}" stroke-width="1.4" stroke-linecap="round"/>'
          + pole("M53 66 L54 6", WOOD_L, 2.2)
          + f'\n    <path d="M54 10 Q66 9 66 26 Q61 22 54 22Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <path d="M54 12 L46 9 L54 16Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>'
          + f'\n    <path d="M52.6 7 L54 -2 L55.4 7Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>'
          + hand(53.5, 44, p))


def summoners():
    def summoner(kind, top, bottom, robe, hat, band, held, glow_col, light):
        p = _who(kind, dy=3)
        return _card(kind, top, bottom, hair_back(p) + neck(p) + body(robe, p, robe=True)
                     + f'\n    <path d="M21 45 Q32 51 43 45 L40 50 Q32 54 24 50Z" fill="{band}" stroke="{INK}" stroke-width="1.4"/>'
                     + head(p)
                     + f'\n    <path d="M6 23 Q32 15 58 23 Q46 26 32 26 Q18 26 6 23Z" fill="{hat}" stroke="{INK}" stroke-width="{LINE}"/>'
                     + f'\n    <path d="M19 22 Q22 12 28 8 Q31 -2 40 -4 Q35 4 37 10 Q43 16 45 22 Q32 19 19 22Z" fill="{hat}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
                     + f'\n    <path d="M19.6 20 Q32 16.5 44.4 20" stroke="{band}" stroke-width="2.2"/>'
                     + glow(51, 46, 15, glow_col, 0.7) + held + hand(51, 55.5, p), light=light, light_op=0.1)

    orb = (f'\n    <circle cx="51" cy="46" r="6.4" fill="#a87cff" stroke="{INK}" stroke-width="{LINE}"/>'
           f'\n    <circle cx="51" cy="46" r="3.6" fill="#c8a8ff"/><circle cx="49" cy="44" r="1.6" fill="#f0e8ff"/>'
           + sparkles([(42, 36), (58, 38)], "#d8c4ff", 0.9))
    summoner("summoner", "#2a2642", "#0d0c18", "#243a44", "#3a2a55", "#9a6cff", orb, "#9a6cff", "#9a6cff")
    flame = (f'\n    <path d="M51 32 Q60 41 57 48 Q55 53 51 53 Q46 53 45 48 Q44 43 48 39 Q48 44 51 44 Q53 38 51 32Z" fill="#ff8a30" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
             f'\n    <path d="M51 40 Q56 45 54 49 Q53 51 51 51 Q48 51 48 48 Q48 45 50 44 Q51 43 51 40Z" fill="#ffc040"/>'
             + sparkles([(43, 33), (59, 36)], "#ffc060", 0.8))
    summoner("fire_summoner", "#44201a", "#140806", "#5a2418", "#6a2418", "#ff8a30", flame, "#ff8a30", "#ff8a30")

    # The druid: a brown hood, a moss robe and a crooked staff that sprouts.
    p = _who("druid")
    back, rim = hood("#4a3a24", p)
    top = (pole("M13 14 Q8 9 11 4", WOOD, 2)
           + f'\n    <ellipse cx="12" cy="11" rx="4" ry="3.4" fill="#5aa04a" stroke="{INK}" stroke-width="1.4"/>'
           + f'\n    <path d="M15 8 Q21 4 22 9 Q18 11 15 8Z" fill="#7ad06a" stroke="{INK}" stroke-width="1"/>')
    _card("druid", "#22341f", "#0a120a", back + hair_back(p) + neck(p) + body("#3e5a2c", p, robe=True)
          + head(p, ears=False) + rim + staff(top, "#8ae08a", p, wood=WOOD, x0=9, x1=13)
          + "".join(f'\n    <path d="M{x} {y} q3 -2 5 1 q-3 2 -5 -1Z" fill="#7ad06a" stroke="{INK}" stroke-width="0.7" transform="rotate({r} {x} {y})"/>'
                    for (x, y, r) in ((52, 30, 20), (56, 44, -30), (48, 58, 40))), light="#8ae08a", light_op=0.1)


def mages():
    def mage(kind, top, bottom, robe, trim, staff_top, glow_col, book, extra="", light="#ffffff"):
        p = _who(kind)
        _card(kind, top, bottom, hair_back(p) + neck(p) + body(robe, p, robe=True)
              + f'\n    <path d="M21 45 Q32 51 43 45 L38 52 L32 49 L26 52Z" fill="{trim}" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'
              + head(p) + staff(staff_top, glow_col, p) + tome(book, p) + extra, light=light, light_op=0.12)

    orb = (f'\n    <circle cx="12" cy="11" r="5.4" fill="#3a5ab0" stroke="{INK}" stroke-width="{LINE}"/>'
           f'\n    <circle cx="10.5" cy="9.5" r="1.8" fill="#b8c8ff"/>'
           f'\n    <path d="M7 15 Q12 19 17 15" stroke="{INK}" stroke-width="2.4"/>')
    mage("apprentice", "#30343e", "#101218", "#4a4a50", "#6a6a74", orb, "#5a7ae0", "#5a3a2a", light="#8aa0ff")
    flame = (f'\n    <path d="M12 0 Q19 8 17 13 Q15 17 12 17 Q8 17 7 13 Q6 8 10 5 Q10 9 12 10 Q13 5 12 0Z" fill="#ff8a30" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
             f'\n    <path d="M12 8 Q15 11 14.5 14 Q13.6 15.6 12 15.6 Q9.6 15.6 9.6 13.6 Q9.6 11.6 11 10.6Z" fill="#ffc040"/>'
             f'\n    <path d="M7 16 Q12 20 17 16" stroke="{INK}" stroke-width="2.4"/>')
    mage("fire_mage", "#44201a", "#140806", "#7a2a20", "#d8602a", flame, "#ff8a30", "#4a1a12",
         sparkles([(26, 3), (56, 22)], "#ffb060", 0.8), light="#ff8a30")
    crystal = (f'\n    <path d="M12 1 L17 10 L12 18 L7 10Z" fill="#bfe8ff" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
               f'\n    <path d="M12 1 L12 18 M7 10 L17 10" stroke="#ffffff" stroke-width="0.8" opacity="0.8"/>')
    mage("ice_mage", "#24384a", "#0a1018", "#5a8ab0", "#cfeaff", crystal, "#a8dcff", "#2a4a6a",
         sparkles([(52, 24), (58, 12)], "#e8f6ff", 0.9), light="#a8dcff")
    leaf = (f'\n    <path d="M12 0 Q22 8 12 18 Q2 8 12 0Z" fill="#7ad06a" stroke="{INK}" stroke-width="1.6"/>'
            f'\n    <path d="M12 2 L12 16 M12 8 L15.5 5.5 M12 12 L8.5 9.5" stroke="#3a7a30" stroke-width="0.9"/>')
    mage("healing_mage", "#24402a", "#0a140c", "#3a7a44", "#bfe8a0", leaf, "#8ae08a", "#e8e0c8",
         f'\n    <path d="M53 22 l0 8 M49 26 l8 0" stroke="#b8f0a8" stroke-width="2.2" stroke-linecap="round"/>', light="#8ae08a")
    ring = (f'\n    <circle cx="12" cy="10" r="6" stroke="{INK}" stroke-width="3.6"/>'
            f'\n    <circle cx="12" cy="10" r="6" stroke="#c89cff" stroke-width="2"/>'
            f'\n    <circle cx="12" cy="10" r="2.4" fill="#e8d8ff" stroke="{INK}" stroke-width="1.2"/>')
    mage("spatial_mage", "#30244a", "#0e0a18", "#4a3070", "#b08ae0", ring, "#b08ae0", "#2a1a40",
         f'\n    <path d="M50 20 Q58 18 58 25 Q58 30 52 29 Q48 28 50 25 Q52 23 54 25" stroke="#c89cff" stroke-width="1.4" stroke-linecap="round"/>', light="#b08ae0")


def holy_line():
    robe = "#e4dccb"
    # The acolyte: a deep cream cowl, eyes closed, hands folded in prayer, a gold stole.
    p = _who("acolyte", dy=2)
    back, rim = hood("#d4cab4", p)
    _card("acolyte", "#3c3426", "#141008", glow(32, 26, 26, "#fff2c0", 0.5) + neck(p) + body(robe, p, robe=True)
          + f'\n    <path d="M29 47 L35 47 L34.4 66 L29.6 66Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.2"/>'
          + back + head(p, hair=False, ears=False) + rim
          + f'\n    <path d="M27 66 L29 55 Q30 50 32 46 Q34 50 35 55 L37 66Z" fill="{darker(robe, 0.86)}" stroke="{INK}" stroke-width="1.6"/>'
          + f'\n    <path d="M29 58 Q29.5 49 32 45 Q34.5 49 35 58 Q32 60 29 58Z" fill="{skin_of(p)}" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>'
          + f'\n    <path d="M32 46.5 L32 58.5" stroke="{darker(skin_of(p), 0.7)}" stroke-width="0.9"/>'
          + sparkles([(14, 14), (51, 10), (54, 30)], "#fff6d0", 0.9), light="#fff2c0", light_op=0.15)

    # The inquisitor: a crimson helm crowned with a gold cross, a steel breastplate bearing it,
    # a dark cloak and the warhammer.
    p = _who("inquisitor")
    _card("inquisitor", "#301418", "#0e0608",
          f'\n    <path d="M2 66 Q2 42 18 38 L46 38 Q62 42 62 66Z" fill="#2a1a1a" stroke="{INK}" stroke-width="{LINE}"/>'
          + hair_back(p) + neck(p) + body("#3a2224", p)
          + f'\n    <path d="M18 47 Q32 51 46 47 L45 66 L19 66Z" fill="#8a8f96" stroke="{INK}" stroke-width="{LINE}"/>'
          + pole("M32 51 L32 63 M26 55.5 L38 55.5", GOLD, 2.4)
          + head(p)
          + f'\n    <path d="M18.5 30 Q17 6 32 6 Q47 6 45.5 30 L42 30 Q42 19 32 19 Q22 19 22 30Z" fill="#6a1a20" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M22 19 Q32 15.5 42 19" stroke="{GOLD_D}" stroke-width="1.6"/>'
          + pole("M32 6 L32 -2 M28.5 1.5 L35.5 1.5", GOLD, 2.2)
          + pole("M53 66 L55 18", WOOD_L, 2.4)
          + f'\n    <path d="M45 10 L64 11 L64 22 L45 21Z" fill="#8a8f96" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M54.5 13 L54.5 19 M52 16 L57 16" stroke="{GOLD}" stroke-width="1.4"/>'
          + hand(53.8, 44, p), light=CRIMSON, light_op=0.2)

    # The high priest: a tall white mitre with gold, a broad gold stole and a sun crosier.
    p = _who("high_priest", dy=4)
    rays = "".join(
        f'\n    <path d="M{12 + math.cos(k * math.pi / 4) * 6.4:.1f} {11 + math.sin(k * math.pi / 4) * 6.4:.1f} '
        f'L{12 + math.cos(k * math.pi / 4) * 9.6:.1f} {11 + math.sin(k * math.pi / 4) * 9.6:.1f}" stroke="{GOLD}" stroke-width="1.6" stroke-linecap="round"/>'
        for k in range(8))
    sun = rays + f'\n    <circle cx="12" cy="11" r="5" fill="{GOLD}" stroke="{INK}" stroke-width="1.6"/><circle cx="11" cy="10" r="1.8" fill="#fff6d0"/>'
    _card("high_priest", "#3c3624", "#13110a", neck(p) + body("#f0ead8", p, robe=True)
          + f'\n    <path d="M22 45 L28 47 L30 66 L22 66Z M36 47 L42 45 L42 66 L34 66Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'
          + head(p)
          + f'\n    <path d="M20 18 L21 2 L32 -6 L43 2 L44 18 Q32 15 20 18Z" fill="#f2ecdc" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M20.6 15.5 Q32 12.5 43.4 15.5" stroke="{GOLD}" stroke-width="2.4"/>'
          + f'\n    <path d="M32 -4 L32 14 M27.5 4.5 L36.5 4.5" stroke="{GOLD}" stroke-width="2"/>'
          + staff(sun, "#fff2c0", p, wood=GOLD_D), light="#fff2c0", light_op=0.18)


CARDS = (archers, shield_line, summoners, mages, holy_line)


def unit_cards():
    """One card per Config.MILITARY key; stops the generator if a kind has no card."""
    for draw in CARDS:
        draw()
    with open(os.path.join(ROOT, "scripts", "core", "config.gd")) as f:
        cfg = f.read()
    block = cfg[cfg.index("const MILITARY := {"):]
    block = block[:block.index("\n}")]
    missing = [k for k in re.findall(r'^\t"([a-z_]+)":', block, re.M) if k not in DRAWN]
    if missing:
        raise SystemExit("unit_cards: no card drawn for %s (tools/art/unit_cards.py)" % ", ".join(missing))
