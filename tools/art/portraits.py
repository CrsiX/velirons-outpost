"""The cutscenes' dialogue portraits: `portrait_<id>`, one per speaker (Scenario.speakers).

Drawn by faces.py in the unit cards' style: the person (CAST) is built from the same parts, and
who it is shows in the clothes and what they carry, as docs/story-design.md section 2 describes
them. No jewellery and no make-up. Two story marks stay: the crown's thralls have pale, empty eyes
("bound"), and the cursed Fiona black ones ("void") and dark veins. Rhodri's crown is the crown of
the story, not an ornament."""

import glob
import os
import re

from .core import CRIMSON, GOLD, GOLD_D, INK, ROOT, WOOD_L
from .faces import (LINE, STEEL, STEEL_D, STEEL_L, body, card, darker, glow, hair_back, hand, head,
                    hood, neck, person, pole, sparkles)

BOUND_SKIN = "#cfd2d4"  # the pallor of the crown's thralls

CAST = {
    "brenna": dict(sex="f", age="adult", skin=1, face="oval", hair=("ponytail", "dark"), eyes=("almond", "grey"), nose="straight", expr="firm"),
    "einar": dict(sex="m", age="old", skin=2, face="square", hair=("short", "grey"), eyes=("almond", "blue"), nose="broad", expr="kind", beard=("full", "grey")),
    "pell": dict(sex="m", age="adult", skin=3, face="round", hair=("short", "brown"), eyes=("round", "hazel"), nose="button", expr="grin", beard=("trim", "brown")),
    "wenna": dict(sex="f", age="old", skin=0, face="long", hair=("bun", "grey"), eyes=("narrow", "grey"), nose="hooked", expr="neutral_raised"),
    "sigmund": dict(sex="m", age="old", skin=3, face="square", hair=("bald", "white"), eyes=("narrow", "brown"), nose="broad", expr="firm", beard=("full", "white")),
    "lysa": dict(sex="f", age="adult", skin=BOUND_SKIN, face="heart", hair=("braid", "auburn"), eyes=("almond", "bound"), nose="straight", expr="neutral"),
    "rival": dict(sex="m", age="adult", skin=1, face="oval", hair=("short", "black"), eyes=("narrow", "dark"), nose="straight", expr="smirk", beard=("trim", "black")),
    "anselm": dict(sex="m", age="old", skin=2, face="round", hair=("bald", "grey"), eyes=("almond", "brown"), nose="broad", expr="kind"),
    "fiona": dict(sex="f", age="young", skin=0, face="heart", hair=("long", "copper"), eyes=("almond", "blue"), nose="small", expr="neutral"),
    "elder": dict(sex="m", age="old", skin=4, face="long", hair=("bald", "white"), eyes=("almond", "green"), nose="hooked", expr="kind", beard=("long", "white")),
    "mage": dict(sex="m", age="adult", skin=5, face="square", hair=("crop", "black"), eyes=("almond", "brown"), nose="broad", expr="calm", beard=("trim", "grey")),
    "lothar": dict(sex="m", age="adult", skin=0, face="long", hair=("short", "grey"), eyes=("narrow", "grey"), nose="straight", expr="calm", beard=("trim", "white")),
    "rurik": dict(sex="m", age="adult", skin=BOUND_SKIN, face="square", hair=("crop", "dark"), eyes=("narrow", "bound"), nose="broad", expr="firm"),
    "rhodri": dict(sex="m", age="young", skin="#e2e5ea", face="long", hair=("long", "black"), eyes=("almond", "bound"), nose="straight", expr="smirk"),
    "church_priest": dict(sex="m", age="young", skin=4, face="long", hair=("crop", "brown"), eyes=("round", "brown"), nose="straight", expr="nervous"),
    "eldest_priest": dict(sex="f", age="old", skin=1, face="oval", hair=("bald", "white"), eyes=("narrow", "grey"), nose="hooked", expr="frown"),
    "halvard": dict(sex="m", age="old", skin=2, face="square", hair=("crop", "grey"), eyes=("narrow", "grey"), nose="broad", expr="angry", beard=("trim", "grey")),
    "fiona_cursed": dict(sex="f", age="young", skin="#d8ccca", face="heart", hair=("long", "auburn"), eyes=("almond", "void"), nose="small", expr="neutral"),
}


def _who(name, dy=0):
    return person(CAST[name], dy)


DRAWN = set()


def _portrait(name, top, bottom, art, light="#ffffff", light_op=0.12):
    DRAWN.add(name)
    card("portrait_" + name, top, bottom, art, light, light_op)


def _path(d, fill, w=LINE, extra=""):
    return f'\n    <path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{w}" stroke-linejoin="round"{extra}/>'


def _cloak(col):
    """A cloak or mantle behind the shoulders, wider than the body."""
    return _path("M2 66 Q2 42 18 38 L46 38 Q62 42 62 66Z", col)


def _pauldrons(left, right):
    return (f'\n    <ellipse cx="11" cy="48" rx="10" ry="7" fill="{left}" stroke="{INK}" stroke-width="{LINE}"/>'
            f'\n    <ellipse cx="53" cy="48" rx="10" ry="7" fill="{right}" stroke="{INK}" stroke-width="{LINE}"/>'
            f'\n    <path d="M5 46 Q11 42 17 46" stroke="{STEEL_L}" stroke-width="1.2" opacity="0.6"/>')


def _cross(x, y, col, h=10.0):
    """A cross on the chest, hanging from a cord."""
    return (f'\n    <path d="M{x - 6} 44 Q{x} {y - 1} {x + 6} 44" stroke="#3a2a1a" stroke-width="0.9"/>'
            + pole(f"M{x} {y} L{x} {y + h} M{x - h * 0.35:.1f} {y + h * 0.32:.1f} L{x + h * 0.35:.1f} {y + h * 0.32:.1f}", col, 1.6))


def _helm(col, plume):
    """An open-faced helm with cheek guards, a nasal bar and a plume."""
    return (_path("M18 25 Q17 6 32 5 Q47 6 46 25 L43 25 L43 18 Q32 15 21 18 L21 25Z", col)
            + _path("M30.8 17 L33.2 17 L33 27 L31 27Z", darker(col, 0.85), 1.2)
            + f'\n    <path d="M23 12 Q27 8 32 7.6" stroke="{STEEL_L}" stroke-width="1.4" stroke-linecap="round" opacity="0.8"/>'
            + _path("M38 7 Q50 1 59 13 Q51 9 43 11Z", plume, 1.6))


def homecoming():
    """Scenarios 1 to 3: Brenna, her father and Pell."""
    # Brenna Hale: a royal knight come home; dark hair tied back, a worn blue-steel cuirass,
    # the crimson cloak of the royal knights.
    p = _who("brenna")
    _portrait("brenna", "#2c3644", "#0e1218", _cloak(CRIMSON) + hair_back(p) + neck(p) + body("#6a7a8e", p)
              + _path("M20 47 Q32 52 44 47 L43 66 L21 66Z", "#7a8a9e")
              + f'\n    <path d="M32 50 L32 66" stroke="#4a5666" stroke-width="1.4"/>'
              + _pauldrons("#8a96a6", "#6a7686") + head(p))

    # Einar: Brenna's father, the village's lumberjack; a grey beard, a green cap, a red check
    # shirt, the axe over his shoulder.
    p = _who("einar")
    _portrait("einar", "#2c3428", "#0e120c", pole("M48 66 L58 8", WOOD_L, 2.6)
              + _path("M54 6 L65 3 L65 17 L56 14Z", STEEL, 1.6)
              + neck(p) + body("#7a3a2a", p)
              + f'\n    <path d="M12 53 L52 53 M10 60 L54 60 M23 46 L21 66 M41 46 L43 66" stroke="#5a2a1e" stroke-width="1.5"/>'
              + head(p)
              + _path("M18 19 Q19 5 32 5 Q45 5 46 19Z", "#3a4a2a")
              + pole("M16.5 19 L47.5 19", "#2a3a1e", 1.6)
              + hand(51.2, 50, p))

    # Pell Dunmore: a travelling merchant; a wide-brimmed hat, a brown coat with a gold-trimmed
    # collar, a short beard, a lantern's warm light.
    p = _who("pell")
    _portrait("pell", "#33291f", "#120e0a", glow(54, 52, 16, "#ffd27a", 0.45) + neck(p) + body("#5a4630", p)
              + f'\n    <path d="M22 45 L32 57 L42 45" stroke="{GOLD}" stroke-width="2.2"/>'
              + f'\n    <circle cx="32" cy="61" r="1.3" fill="{GOLD_D}"/>'
              + head(p)
              + _path("M7 19 Q32 11 57 19 Q44 22.5 32 22.5 Q20 22.5 7 19Z", "#3a2e22")
              + _path("M20 18 Q21 4 32 4 Q43 4 44 18Z", "#4a3a2a")
              + f'\n    <path d="M20.6 15 L43.4 15" stroke="{CRIMSON}" stroke-width="2.4"/>'
              + f'\n    <path d="M54 44 L54 47" stroke="{INK}" stroke-width="1.2"/>'
              + _path("M50 47 L58 47 L57 60 L51 60Z", "#ffe08a", 1.6)
              + f'\n    <path d="M50 47 L58 47 L57 60 L51 60Z M54 47 L54 60" stroke="{GOLD_D}" stroke-width="1"/>'
              + hand(54, 43, p), light="#ffd27a", light_op=0.1)


def away():
    """Scenarios 4 and 5: Wenna, the rival guild's envoy, Sigmund and Lysa."""
    # Wenna: the Silver Thread Guild's master; grey hair in a bun, a dark-blue coat, the guild's
    # silver thread stitched along the lapels, a sharp look.
    p = _who("wenna")
    _portrait("wenna", "#262f3c", "#0c0f14", hair_back(p) + neck(p) + body("#2f3e5a", p)
              + _path("M21 44 L27 58 L32 50 L37 58 L43 44 Q32 49 21 44Z", "#24304a", 1.4)
              + f'\n    <path d="M22.4 46 L27.4 56 M41.6 46 L36.6 56" stroke="#c8ccd8" stroke-width="0.9" stroke-dasharray="1.2 0.8"/>'
              + head(p), light="#c8ccd8", light_op=0.1)

    # A rival guild's envoy: a fur collar over a plum coat, a trimmed black beard and a smile that
    # does not reach the eyes.
    p = _who("rival")
    _portrait("rival", "#2e2230", "#0e0a10", neck(p) + body("#4a2a3a", p)
              + _path("M9 52 Q19 40 32 46 Q45 40 55 52 Q50 57 44 53 Q38 57 32 53 Q26 57 20 53 Q14 57 9 52Z", "#8a7458", 1.5)
              + head(p))

    # Sigmund: the old veteran at Brenna's fort; bald, a white beard, a patch over one eye, worn
    # mail under a brown jerkin.
    p = _who("sigmund")
    _portrait("sigmund", "#2e2a26", "#100e0c", neck(p) + body("#7a7e86", p)
              + '\n    <defs><clipPath id="mail"><path d="M3 66 Q4 48 21 44 Q32 49 43 44 Q60 48 61 66Z"/></clipPath></defs>\n    <g clip-path="url(#mail)">'
              + "".join(f'\n    <path d="M{x} {y} q1.5 1.6 3 0" stroke="#4e545a" stroke-width="0.9"/>'
                        for y in (49, 53, 57, 61, 65) for x in range(0 + (y // 4 % 2) * 2, 64, 4))
              + '\n    </g>'
              + _path("M18 66 L21 46 Q32 50 43 46 L46 66Z", "#5a4630")
              + head(p)
              + f'\n    <path d="M19.5 19 L45 28.5" stroke="{INK}" stroke-width="1.4"/>'
              + f'\n    <ellipse cx="37" cy="25.8" rx="3.8" ry="3.2" fill="#2a221c" stroke="{INK}" stroke-width="1.2"/>')

    # Lysa: Brenna's old captain, bound to Rhodri; pale, the pale empty eyes, a captain's helm
    # with a crimson plume, a dark-red braid.
    p = _who("lysa")
    _portrait("lysa", "#22242a", "#0a0b0e", _cloak("#2a2a30") + neck(p) + body("#5a4448", p)
              + f'\n    <path d="M18 51 Q32 55 46 51" stroke="{GOLD_D}" stroke-width="1.8"/>'
              + hair_back(p) + head(p) + _helm("#8a8e96", CRIMSON), light="#b8d0ff", light_op=0.12)


def exile():
    """Scenarios 6 and 7: Anselm, Fiona, Elder Oren and Idris."""
    # Anselm: the battlefield village's old priest; a grey fringe round a bald crown, a black
    # cassock with a white collar, a gold cross, tired kind eyes.
    p = _who("anselm")
    _portrait("anselm", "#2a2824", "#0e0d0c", neck(p) + body("#26242a", p, robe=True)
              + _path("M27.5 44 L32 48.6 L36.5 44Z", "#f0ece0", 1.3)
              + _cross(32, 51, GOLD) + head(p), light="#fff2c0", light_op=0.1)

    # Fiona Aldmoor: the old king's daughter in exile; long red-gold hair, a deep-blue gown with a
    # silver collar, a level, measuring look.
    p = _who("fiona")
    _portrait("fiona", "#1e2638", "#0a0c14", hair_back(p) + neck(p) + body("#243a6a", p)
              + f'\n    <path d="M21 45 Q32 54 43 45" stroke="#c8ccd8" stroke-width="2.2"/>'
              + head(p), light="#9ab8f0", light_op=0.12)

    # Elder Oren: the druids' elder; a long white beard, a hood of undyed wool over a moss robe.
    p = _who("elder")
    back, rim = hood("#6a5a40", p)
    _portrait("elder", "#22301e", "#0a100a", back + neck(p) + body("#3e5a2c", p, robe=True)
              + head(p, hair=False, ears=False) + rim, light="#8ae08a", light_op=0.1)

    # Idris, a court mage: a dark face, a short beard gone silver, a deep violet hood stitched
    # with silver stars.
    p = _who("mage")
    back, rim = hood("#2c2048", p)
    _portrait("mage", "#221c30", "#0b0912", back + neck(p) + body("#3a2a5a", p, robe=True)
              + f'\n    <path d="M21 45 Q32 51 43 45 L38 52 L32 49 L26 52Z" fill="#b08ae0" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'
              + head(p, hair=False, ears=False) + rim
              + sparkles([(19.5, 12), (44.5, 12), (15.5, 34), (48.5, 36)], "#d8dce8", 0.55), light="#b08ae0", light_op=0.1)


def court():
    """Scenarios 8 to 11: Lothar, Rurik, Rhodri, the priests, Halvard and the cursed Fiona."""
    # Lothar: the Pale Court's herald; a long pale face, a neat silver beard, a feathered cap, a
    # pale tabard with the court's gold crown; courteous and cold.
    p = _who("lothar")
    _portrait("lothar", "#2a2836", "#0c0b12", neck(p) + body("#5a5470", p)
              + _path("M19 46 Q32 50 45 46 L44 66 L20 66Z", "#d8d6de")
              + _path("M27 59 L27 54 L29.5 56 L32 52 L34.5 56 L37 54 L37 59Z", GOLD, 1.2)
              + head(p)
              + _path("M16 18 Q18 5 32 5 Q46 5 48 18 Q32 14.5 16 18Z", "#5a5470")
              + _path("M40 9 Q52 0 61 7 Q53 8 46 14Z", "#eceae4", 1.5)
              + f'\n    <path d="M43 10 Q51 4 58 6" stroke="#b8b6b0" stroke-width="0.8"/>', light="#d8d4e4", light_op=0.1)

    # Rurik: the court's champion, bound; pale, the empty eyes, a pale steel helm with a white
    # plume, broad pauldrons.
    p = _who("rurik")
    _portrait("rurik", "#22242a", "#0a0b0e", neck(p) + body("#b8bcc4", p)
              + f'\n    <path d="M32 48 L32 66" stroke="#8a8e96" stroke-width="1.4"/>'
              + _pauldrons("#c8ccd4", "#a8acb4") + head(p) + _helm("#b8bcc4", "#eceef2"), light="#b8d0ff", light_op=0.14)

    # Rhodri Aldmoor: the king, paler than anyone; long dark hair, a high collar, a thin smile and
    # the old king's crown reworked, glowing cold.
    p = _who("rhodri")
    _portrait("rhodri", "#1e1c2a", "#08070c", glow(32, 10, 22, "#b8d0ff", 0.4) + hair_back(p) + neck(p) + body("#1e1a2a", p)
              + _path("M17 45 L22 35 L32 47 L42 35 L47 45 Q32 50 17 45Z", "#3a3450")
              + head(p)
              + _path("M19 15 L21 3 L26 9.6 L32 1 L38 9.6 L43 3 L45 15 Q32 12.6 19 15Z", "#c8d8f0")
              + f'\n    <path d="M20 13 Q32 10.6 44 13" stroke="#eaf4ff" stroke-width="1" opacity="0.8"/>', light="#b8d0ff", light_op=0.16)

    # A priest of the church, a survivor in the capital: young and thin, a brown habit with its
    # hood down, a wooden cross on a cord.
    p = _who("church_priest")
    _portrait("church_priest", "#2a241c", "#0e0c09", neck(p) + body("#6a5238", p, robe=True)
              + _path("M13 47 Q32 39 51 47 Q44 51 32 51 Q20 51 13 47Z", "#5a4430", 1.5)
              + _cross(32, 52, WOOD_L) + head(p))

    # The eldest priest of the drowned shore: a deeply lined face, a white wimple under a
    # dark-blue veil, wary eyes, a gold cross.
    p = _who("eldest_priest")
    back, rim = hood("#26324a", p)
    _portrait("eldest_priest", "#1e2432", "#0a0c12", back + body("#26324a", p, robe=True)
              + _path("M18.4 38 Q17.6 15 32 14.4 Q46.4 15 45.6 38 Q40 45.5 32 45.5 Q24 45.5 18.4 38Z", "#f0ece2")
              + _cross(32, 51, GOLD) + head(p, hair=False, ears=False) + rim
              + f'\n    <path d="M19.4 27 Q20 17.6 32 17 Q44 17.6 44.6 27" stroke="#f0ece2" stroke-width="1.6"/>', light="#fff2c0", light_op=0.08)

    # Halvard: the Dread Legion's marshal; an old soldier's square, weathered face, cropped grey
    # hair and beard under heavy brows, dark plate with a gold-trimmed collar.
    p = _who("halvard")
    _portrait("halvard", "#22242a", "#0a0b0e", neck(p) + body("#5e626c", p)
              + f'\n    <path d="M17 45 L32 53 L47 45" stroke="{GOLD}" stroke-width="2.2"/>'
              + _pauldrons("#6e727c", STEEL_D) + head(p))

    # Fiona at the end: as in scenario 7, but pale, the curse dark in her veins, her eyes black.
    p = _who("fiona_cursed")
    vein = darker("#6a1e6e", 0.8)
    _portrait("fiona_cursed", "#1c0c20", "#060208", glow(32, 30, 30, "#6a1e6e", 0.6) + hair_back(p) + neck(p) + body("#243a6a", p)
              + f'\n    <path d="M21 45 Q32 54 43 45" stroke="#c8ccd8" stroke-width="2.2"/>'
              + f'\n    <path d="M29.6 36 Q31 40 30 46 M34.4 36 Q33.4 41 35 46" stroke="{vein}" stroke-width="0.9"/>'
              + head(p)
              + f'\n    <path d="M24 35 Q25.4 31.6 24.4 28.6 M24.9 31.8 Q26.6 31 27.2 29.4 M40 35 Q38.6 31.6 39.6 28.6 M39.1 31.8 Q37.4 31 36.8 29.4" stroke="{vein}" stroke-width="0.7"/>',
              light="#b890c8", light_op=0.1)


def portraits():
    """Every speaker's portrait; the names are the `portrait_<id>` the scenarios' speakers use."""
    homecoming()
    away()
    exile()
    court()
    used = set()
    for path in glob.glob(os.path.join(ROOT, "scripts", "scenarios", "*.gd")):
        with open(path) as f:
            used.update(re.findall(r'"portrait_([a-z_]+)"', f.read()))
    missing = sorted(used - DRAWN)
    if missing:
        raise SystemExit("portraits: no portrait drawn for %s (tools/art/portraits.py)" % ", ".join(missing))
