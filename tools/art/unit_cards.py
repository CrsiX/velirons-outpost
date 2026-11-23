"""The upgrade dialog's unit cards: `unit_card_<kind>`, one square bust per Config.MILITARY key.

Every card is drawn the same way: a bust of one person on a dark backdrop tinted by the kind, at
the same scale and framing, with the same line weights, eyes and shading. The person (CAST) is
built from parts: sex, age, skin, face shape, hair, eyes, nose, expression and, for men, facial
hair. The kind shows in the clothes and the gear, in the colours of its map sprite
(tools/art/units.py). No jewellery and no make-up: faces are bare."""

import math
import os
import re

from .core import ART, CRIMSON, GOLD, GOLD_D, INK, ROOT, WOOD, WOOD_L

UNIT_CARD_SIZE = 256
DRAWN = set()
STEEL, STEEL_D, STEEL_L = "#9aa0a8", "#6a7078", "#c8ced6"
SCLERA = "#f4eee6"
LINE = 1.8  # the outline of every shape

# Skin tones, pale to deep.
SKIN = ["#f2d4b8", "#e6ba98", "#d6a47a", "#c08a5a", "#9a6640", "#74492a", "#5a3820"]
HAIR = {
    "black": "#1e1a18", "dark": "#3a2618", "brown": "#5e3c22", "auburn": "#8a3e1e",
    "red": "#c04a1e", "blond": "#d8b060", "grey": "#9a9894", "white": "#e8e4dc",
}
IRIS = {
    "brown": "#6a4020", "dark": "#3a2414", "blue": "#4a7ab8", "green": "#4a8a3a",
    "grey": "#7a8a96", "hazel": "#8a6a30", "amber": "#c08020",
}

# Who is on each card. sex: m/f; age: young/adult/old; skin: index into SKIN; face: FACES;
# hair: (style, colour); eyes: (shape, iris); nose: NOSES; expr: EXPRESSIONS; beard (men):
# (style, colour); freckles: True.
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

FACES = {
    "oval": "M20 24 Q19 10 32 10 Q45 10 44 24 Q44 33 32 39 Q20 33 20 24Z",
    "round": "M19.5 24 Q19 10 32 10 Q45 10 44.5 24 Q44.5 35 32 38.6 Q19.5 35 19.5 24Z",
    "square": "M20 23 Q20 10 32 10 Q44 10 44 23 L43.6 31 Q41.6 38 32 39 Q22.4 38 20.4 31Z",
    "long": "M21 23 Q20.5 8.5 32 8.5 Q43.5 8.5 43 23 Q43 34 32 40 Q21 34 21 23Z",
    "heart": "M19.5 22 Q19.5 10 32 10 Q44.5 10 44.5 22 Q43 31 32 39 Q21 31 19.5 22Z",
}
NOSES = {
    "small": "M32 27.5 L31 30.6 Q32 31.4 33.2 30.8",
    "button": "M30.8 30.2 Q32 31.6 33.2 30.2",
    "straight": "M32.4 25.8 L31 30.8 Q32 31.6 33.4 31",
    "broad": "M30.2 29.6 Q29.2 31.4 30.8 31.6 Q32 32.4 33.2 31.6 Q34.8 31.4 33.8 29.6",
    "hooked": "M32 25.6 Q34 28.4 32.8 30.6 L31 31.2 Q32 31.8 33.2 31.2",
}
# expression: (brows, eye openness or "closed", mouth)
EXPRESSIONS = {
    "neutral": ("neutral", 1.0, "neutral"),
    "neutral_raised": ("raised_one", 1.0, "neutral"),
    "calm": ("neutral", 0.85, "soft"),
    "smile": ("raised", 0.9, "smile"),
    "kind": ("raised", 0.7, "smile"),
    "grin": ("raised", 0.9, "grin"),
    "grin_fierce": ("angry", 1.1, "grin"),
    "firm": ("low", 0.8, "firm"),
    "frown": ("angry", 0.75, "frown"),
    "angry": ("angry", 0.75, "firm"),
    "shout": ("angry", 1.0, "shout"),
    "smirk": ("raised_one", 0.85, "smirk"),
    "serene": ("neutral", "closed", "soft"),
    "nervous": ("worried", 1.2, "wobbly"),
}
EYE_H = {"almond": 2.3, "round": 2.8, "narrow": 1.7}


def _darker(col, k=0.78):
    r, g, b = (int(col[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(c * k))) for c in (r, g, b))


def _card(kind, top, bottom, body, light="#ffffff", light_op=0.12):
    """Writes unit_card_<kind>.svg: backdrop gradient, a soft light behind the head, the bust."""
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{UNIT_CARD_SIZE}" height="{UNIT_CARD_SIZE}" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
    <radialGradient id="lt" cx="0.5" cy="0.38" r="0.45"><stop offset="0" stop-color="{light}" stop-opacity="{light_op}"/><stop offset="1" stop-color="{light}" stop-opacity="0"/></radialGradient>
    <clipPath id="c"><rect x="2" y="2" width="60" height="60" rx="6"/></clipPath>
  </defs>
  <rect x="2" y="2" width="60" height="60" rx="6" fill="url(#bg)"/>
  <g clip-path="url(#c)">
    <rect x="2" y="2" width="60" height="60" fill="url(#lt)"/>{body}
  </g>
  <rect x="1.5" y="1.5" width="61" height="61" rx="6.5" fill="none" stroke="{INK}" stroke-width="2"/>
</svg>
'''
    # ThorVG can drop a stroked line that keeps the default fill: every stroke-only path says so.
    svg = re.sub(r'<path (?![^>]*fill=)', '<path fill="none" ', svg)
    svg = re.sub(r'<circle (?![^>]*fill=)', '<circle fill="none" ', svg)
    DRAWN.add(kind)
    with open(os.path.join(ART, "unit_card_%s.svg" % kind), "w") as f:
        f.write(svg)


def _glow(x, y, r, col, op=0.55):
    gid = "g%d_%d" % (round(x), round(y))
    return (f'\n    <defs><radialGradient id="{gid}"><stop offset="0" stop-color="{col}" stop-opacity="{op}"/>'
            f'<stop offset="1" stop-color="{col}" stop-opacity="0"/></radialGradient></defs>'
            f'\n    <circle cx="{x}" cy="{y}" r="{r}" fill="url(#{gid})"/>')


def _sparkles(pts, col, r=1.0):
    s = ""
    for (x, y) in pts:
        s += (f'\n    <path d="M{x} {y - r * 2.2} L{x + r * 0.6} {y - r * 0.6} L{x + r * 2.2} {y} L{x + r * 0.6} {y + r * 0.6} '
              f'L{x} {y + r * 2.2} L{x - r * 0.6} {y + r * 0.6} L{x - r * 2.2} {y} L{x - r * 0.6} {y - r * 0.6}Z" fill="{col}"/>')
    return s


# --- the person ------------------------------------------------------------------------

def _g(p, inner):
    """Moves a part of the person down by p["dy"] (under a tall hat)."""
    dy = p.get("dy", 0)
    return f'\n    <g transform="translate(0 {dy})">{inner}\n    </g>' if dy else inner


def _skin(p):
    return SKIN[p["skin"]]


def hair_back(p):
    """The hair behind the head and shoulders: long hair, a bun, a ponytail, an afro, a mane."""
    style, name = p["hair"]
    col = HAIR[name]
    d = _darker(col, 0.8)
    if style in ("long", "bob"):
        ln = 40 if style == "bob" else 50 if p["sex"] == "f" else 46
        s = (f'\n    <path d="M18.5 24 Q15 7 32 6 Q49 7 45.5 24 Q47 36 48.5 {ln} Q44 {ln + 3} 40 {ln - 2} L39 36 L25 36 L24 {ln - 2} Q20 {ln + 3} 15.5 {ln} Q17 36 18.5 24Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
             f'\n    <path d="M19 32 Q18.5 {ln - 6} 17.5 {ln - 1} M45 32 Q45.5 {ln - 6} 46.5 {ln - 1}" stroke="{d}" stroke-width="1"/>')
    elif style == "bun":
        s = f'\n    <circle cx="32" cy="6.5" r="5.5" fill="{col}" stroke="{INK}" stroke-width="{LINE}"/><path d="M28.5 5 Q32 3 35.5 5" stroke="{d}" stroke-width="0.9"/>'
    elif style == "ponytail":
        s = f'\n    <path d="M40 12 Q51 13 49.5 26 Q48.5 36 51.5 45 Q46.5 47 44.5 41 Q43 31 43.5 22Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
    elif style == "afro":
        bumps = "".join(f'\n    <circle cx="{32 + math.cos(a) * 14.5:.1f}" cy="{18 + math.sin(a) * 13:.1f}" r="4" fill="{col}" stroke="{INK}" stroke-width="{LINE}"/>'
                        for a in (math.pi * (0.9 + k * 0.15) for k in range(9)))
        s = bumps + f'\n    <ellipse cx="32" cy="18" rx="15" ry="13.5" fill="{col}"/>'
    elif style == "wild":
        s = (f'\n    <path d="M17 34 L11 30 L15 25 L9 19 L16 17 L12 9 L20 10 L20 2 L27 7 L32 0 L37 7 L44 2 L44 10 L52 9 L48 17 L55 19 L49 25 L53 30 L47 34 L50 42 L44 39 L42 44 Q32 40 22 44 L20 39 L14 42Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
             f'\n    <path d="M15 21 L20 22 M49 21 L44 22 M17 33 L21 31 M47 33 L43 31" stroke="{d}" stroke-width="1"/>')
    else:
        s = ""
    return _g(p, s)


def neck(p):
    sk = _skin(p)
    w = 8 if p["sex"] == "f" else 10
    return _g(p, f'\n    <rect x="{32 - w / 2}" y="33" width="{w}" height="14" fill="{_darker(sk, 0.86)}" stroke="{INK}" stroke-width="{LINE}"/>')


def _eyes(p):
    shape, iris = p["eyes"]
    _brows, open_, _mouth = EXPRESSIONS[p["expr"]]
    line = _darker(_skin(p), 0.55)
    cy = 25.6
    s = ""
    for side, cx in ((-1, 27.0), (1, 37.0)):
        out = cx + side * 2.9
        inn = cx - side * 2.9
        if open_ == "closed":
            s += f'\n    <path d="M{out} {cy} Q{cx} {cy + 1.8} {inn} {cy}" stroke="{INK}" stroke-width="1.3" stroke-linecap="round"/>'
        else:
            h = EYE_H[shape] * open_
            r = min(1.45, h * 0.62)
            s += (f'\n    <path d="M{out} {cy} Q{cx} {cy - h:.2f} {inn} {cy} Q{cx} {cy + h * 0.75:.2f} {out} {cy}Z" fill="{SCLERA}"/>'
                  f'\n    <circle cx="{cx}" cy="{cy - 0.1:.2f}" r="{r:.2f}" fill="{IRIS[iris]}"/>'
                  f'\n    <circle cx="{cx}" cy="{cy - 0.1:.2f}" r="{r * 0.5:.2f}" fill="{INK}"/>'
                  f'\n    <circle cx="{cx + 0.5}" cy="{cy - 0.6:.2f}" r="0.42" fill="#ffffff"/>'
                  f'\n    <path d="M{out + side * 0.2} {cy + 0.1} Q{cx} {cy - h - 0.3:.2f} {inn - side * 0.1} {cy}" stroke="{INK}" stroke-width="1.25" stroke-linecap="round"/>')
        if p["age"] == "old":
            s += (f'\n    <path d="M{cx - 2} {cy + 2.3} Q{cx} {cy + 3.3} {cx + 2} {cy + 2.3}" stroke="{line}" stroke-width="0.7"/>'
                  f'\n    <path d="M{out + side * 0.8} {cy - 0.6} l{side * 1.5} -0.7 M{out + side * 0.8} {cy + 0.6} l{side * 1.5} 0.8" stroke="{line}" stroke-width="0.7" stroke-linecap="round"/>')
    return s


def _brows(p):
    kind, _open, _mouth = EXPRESSIONS[p["expr"]]
    name = p["beard"][1] if p.get("beard") and p["hair"][0] == "bald" else p["hair"][1]
    col = _darker(HAIR[name], 0.75)
    w = 1.9 if p["sex"] == "m" else 1.4
    if p["age"] == "old" and p["sex"] == "m":
        w = 2.2
    by = 21.8
    s = ""
    for side, cx in ((-1, 27.0), (1, 37.0)):
        out, inn = cx + side * 3.1, cx - side * 2.9
        if kind == "angry":
            oy, iy, c = by - 0.8, by + 1.8, by - 0.2
        elif kind == "worried":
            oy, iy, c = by + 0.6, by - 1.4, by - 1.4
        elif kind == "raised" or (kind == "raised_one" and side == 1):
            oy, iy, c = by - 0.4, by - 0.6, by - 2.2
        elif kind == "low":
            oy, iy, c = by + 0.2, by + 0.8, by - 0.2
        else:
            oy, iy, c = by + 0.3, by, by - 1.2
        s += f'\n    <path d="M{out:.1f} {oy:.1f} Q{cx} {c:.1f} {inn:.1f} {iy:.1f}" stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>'
    return s


def _mouth(p):
    _b, _o, kind = EXPRESSIONS[p["expr"]]
    sk = _skin(p)
    lip = _darker(sk, 0.5)
    my = 34.4
    under = ""
    if kind == "smile":
        return f'\n    <path d="M28.4 {my - 0.8} Q32 {my + 2.2} 35.6 {my - 0.8}" stroke="{lip}" stroke-width="1.3" stroke-linecap="round"/>' + under
    if kind == "soft":
        return f'\n    <path d="M29.2 {my - 0.2} Q32 {my + 1} 34.8 {my - 0.2}" stroke="{lip}" stroke-width="1.2" stroke-linecap="round"/>' + under
    if kind == "grin":
        return (f'\n    <path d="M27.8 {my - 1.2} Q32 {my - 0.4} 36.2 {my - 1.2} Q35 {my + 2.2} 32 {my + 2.2} Q29 {my + 2.2} 27.8 {my - 1.2}Z" fill="#4a1e18" stroke="{INK}" stroke-width="1.1" stroke-linejoin="round"/>'
                f'\n    <path d="M28.6 {my - 0.9} Q32 {my - 0.2} 35.4 {my - 0.9} L35 {my + 0.4} Q32 {my + 0.9} 29 {my + 0.4}Z" fill="#f4eee6"/>')
    if kind == "shout":
        return (f'\n    <path d="M28.6 {my - 1.4} Q32 {my - 2.2} 35.4 {my - 1.4} Q35.6 {my + 3.6} 32 {my + 3.8} Q28.4 {my + 3.6} 28.6 {my - 1.4}Z" fill="#4a1e18" stroke="{INK}" stroke-width="1.1" stroke-linejoin="round"/>'
                f'\n    <path d="M29.2 {my - 1.2} Q32 {my - 1.8} 34.8 {my - 1.2} L34.6 {my - 0.2} Q32 {my + 0.2} 29.4 {my - 0.2}Z" fill="#f4eee6"/>'
                f'\n    <ellipse cx="32" cy="{my + 2.4}" rx="2" ry="0.9" fill="#a04a40"/>')
    if kind == "frown":
        return f'\n    <path d="M29 {my + 0.8} Q32 {my - 0.8} 35 {my + 0.8}" stroke="{lip}" stroke-width="1.3" stroke-linecap="round"/>' + under
    if kind == "firm":
        return f'\n    <path d="M29 {my} L35 {my}" stroke="{lip}" stroke-width="1.4" stroke-linecap="round"/>' + under
    if kind == "smirk":
        return f'\n    <path d="M29 {my + 0.2} Q32 {my + 0.8} 35.4 {my - 1}" stroke="{lip}" stroke-width="1.3" stroke-linecap="round"/>' + under
    if kind == "wobbly":
        return f'\n    <path d="M29.4 {my} Q30.6 {my + 0.8} 32 {my} Q33.4 {my - 0.6} 34.6 {my + 0.2}" stroke="{lip}" stroke-width="1.2" stroke-linecap="round"/>' + under
    return f'\n    <path d="M29.2 {my} Q32 {my + 0.5} 34.8 {my}" stroke="{lip}" stroke-width="1.3" stroke-linecap="round"/>' + under


def _beard(p):
    """(beard below the mouth, moustache above it)."""
    style, name = p["beard"]
    col = HAIR[name]
    d = _darker(col, 0.8)
    stroke = f'stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"'
    mous = f'\n    <path d="M27 32.8 Q29.5 30.8 32 31.9 Q34.5 30.8 37 32.8 Q35 33.9 32 33.2 Q29 33.9 27 32.8Z" fill="{col}" stroke="{INK}" stroke-width="1.1"/>'
    if style == "full":
        return (f'\n    <path d="M20 25 Q19.5 44 32 47 Q44.5 44 44 25 Q42 31 38.5 33 Q35 31.6 32 32 Q29 31.6 25.5 33 Q22 31 20 25Z" fill="{col}" {stroke}/>'
                f'\n    <path d="M27 40 Q29 43 31 44 M37 40 Q35 43 33 44" stroke="{d}" stroke-width="0.9"/>', mous)
    if style == "long":
        return (f'\n    <path d="M20.5 25 Q19.5 48 32 57 Q44.5 48 43.5 25 Q42 31 38.5 33 Q35 31.6 32 32 Q29 31.6 25.5 33 Q22.5 31 20.5 25Z" fill="{col}" {stroke}/>'
                f'\n    <path d="M28 42 Q29.6 48 31 52 M36 42 Q34.4 48 33 52 M32 40 L32 50" stroke="{d}" stroke-width="0.9"/>', mous)
    if style == "trim":
        return (f'\n    <path d="M20.6 27 Q21.4 39.6 32 41.4 Q42.6 39.6 43.4 27 Q42 32.4 38.4 33.8 Q35 32 32 32.4 Q29 32 25.6 33.8 Q22 32.4 20.6 27Z" fill="{col}" {stroke}/>', mous)
    if style == "goatee":
        return (f'\n    <path d="M28.4 35.8 Q32 37.2 35.6 35.8 Q35.2 40.6 32 41.6 Q28.8 40.6 28.4 35.8Z" fill="{col}" {stroke}/>', mous)
    if style == "stubble":
        return (f'\n    <path d="M20.8 27 Q21.4 37.6 32 39.4 Q42.6 37.6 43.2 27 Q40 33.4 32 33.8 Q24 33.4 20.8 27Z" fill="{col}" opacity="0.25"/>', "")
    if style == "stubble_moustache":
        return (f'\n    <path d="M20.8 27 Q21.4 37.6 32 39.4 Q42.6 37.6 43.2 27 Q40 33.4 32 33.8 Q24 33.4 20.8 27Z" fill="{col}" opacity="0.3"/>', mous)
    return ("", "")


HAIR_FRONT = {
    "short": "M19.6 24 Q17 8 32 7.5 Q47 8 44.4 24 Q43.4 15.4 38.6 13.6 Q32 16 25.2 13.6 Q20.8 15.4 19.6 24Z",
    "crop": "M20 20 Q20 9.5 32 9 Q44 9.5 44 20 Q41 13.2 32 12.6 Q23 13.2 20 20Z",
    "center": "M20 25 Q18 8 32 8 Q46 8 44 25 Q43 16 34 13.4 Q32 15.2 30 13.4 Q21 16 20 25Z",
    "long": "M20 25 Q18 8 32 8 Q46 8 44 25 Q43 16 34 13.4 Q32 15.2 30 13.4 Q21 16 20 25Z",
    "bob": "M19.5 26 Q17 8 31 8 Q46 8 44.5 26 Q43.6 17 38 15 Q33 17.6 27 14.6 Q21 16.6 19.5 26Z",
    "messy": "M19.5 24 Q17 9 26 8 L27 4.6 L30 7.6 L33 3.6 L35 7.6 L39 4.6 L40 8.8 Q47 11 44.5 24 Q43 16 39 15 L37 18 L35 14.4 L31 17.4 L29 14 L25 17 Q21 16 19.5 24Z",
    "curly": "M19.5 23 Q17 19 19 16 Q18 11 23 10 Q24 6 29 7 Q32 4 36 7 Q41 6 42 10 Q47 12 45 17 Q47 20 44.5 23 Q43 17 39 16 Q35 18 32 16 Q28 18 25 16 Q21 17 19.5 23Z",
    "ponytail": "M20 22 Q19 9 32 8.5 Q45 9 44 22 Q42 14 32 13 Q22 14 20 22Z",
    "bun": "M20 22 Q19 9 32 8.5 Q45 9 44 22 Q42 14 32 13 Q22 14 20 22Z",
    "afro": "M19.5 24 Q18.5 13 24 11 Q32 8.4 40 11 Q45.5 13 44.5 24 Q43 15.6 32 14.6 Q21 15.6 19.5 24Z",
    "wild": "M19 27 L15 22 L19 20 L15 14 L21 14 L19 7 L25 11 L27 4 L31 9 L34 3 L36 9 L41 5 L41 12 L47 10 L44 16 L49 19 L45 22 L45 27 Q44 18 38 16 Q32 19 26 16 Q20 18 19 27Z",
}


def _hair_front(p):
    style, name = p["hair"]
    col = HAIR[name]
    st = f'fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"'
    if style == "bald":
        if p["age"] != "old":
            return ""
        return (f'\n    <path d="M19.4 20 Q18.6 25 20.4 29 L21.4 22Z M44.6 20 Q45.4 25 43.6 29 L42.6 22Z" {st}/>'
                f'\n    <path d="M25 13 Q29 11 33 11.4" stroke="#ffffff" stroke-width="1.2" opacity="0.35" stroke-linecap="round"/>')
    return (f'\n    <path d="{HAIR_FRONT[style]}" {st}/>'
            f'\n    <path d="M25 11.4 Q29 9.6 34 9.8" stroke="{_darker(col, 1.25)}" stroke-width="1.1" opacity="0.6" stroke-linecap="round"/>')


def head(p, hair=True, ears=True):
    """Ears (not under a hood), face, the features, wrinkles, freckles, facial hair and (`hair`)
    the hair in front. The shadow on the far cheek is clipped to the face."""
    sk = _skin(p)
    sh = _darker(sk, 0.84)
    line = _darker(sk, 0.6)
    face = FACES[p["face"]]
    s = ""
    if ears:
        s += (f'\n    <ellipse cx="19.8" cy="26" rx="2.4" ry="3.4" fill="{sk}" stroke="{INK}" stroke-width="{LINE}"/>'
              f'\n    <ellipse cx="44.2" cy="26" rx="2.4" ry="3.4" fill="{sh}" stroke="{INK}" stroke-width="{LINE}"/>')
    s += (f'\n    <defs><clipPath id="face"><path d="{face}"/></clipPath></defs>'
          f'\n    <path d="{face}" fill="{sk}"/>'
          f'\n    <path d="M38.6 8 Q46 14 46 24 Q46 34 35.6 41 Q41.4 30 38.6 8Z" fill="{sh}" clip-path="url(#face)"/>'
          f'\n    <path d="{face}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>')
    s += _eyes(p) + _brows(p)
    s += f'\n    <path d="{NOSES[p["nose"]]}" stroke="{line}" stroke-width="1.15" stroke-linecap="round" stroke-linejoin="round"/>'
    if p["age"] == "old":
        s += (f'\n    <path d="M26.5 16.4 Q32 15.2 37.5 16.4 M27.5 18.4 Q32 17.6 36.5 18.4" stroke="{line}" stroke-width="0.7" opacity="0.8"/>'
              f'\n    <path d="M28.8 30 Q27.4 32.6 28.4 35 M35.2 30 Q36.6 32.6 35.6 35" stroke="{line}" stroke-width="0.8" opacity="0.8"/>')
    if p.get("freckles"):
        for (x, y) in ((24.4, 29.4), (26.2, 30.2), (25, 31.2), (39.6, 29.4), (37.8, 30.2), (39, 31.2), (30.4, 29), (33.6, 29)):
            s += f'\n    <circle cx="{x}" cy="{y}" r="0.45" fill="{_darker(sk, 0.68)}"/>'
    beard, mous = _beard(p) if p.get("beard") else ("", "")
    s += beard + _mouth(p) + mous
    if hair:
        s += _hair_front(p)
    return _g(p, s)


def person(kind, dy=0):
    p = dict(CAST[kind])
    p["dy"] = dy
    return p


# --- clothes and gear ----------------------------------------------------------------------

def _body(col, p, robe=False):
    """The upper body in its clothes, the neck opening at the top; women's shoulders are narrower."""
    dark = _darker(col, 0.78)
    left, right = (6, 58) if p["sex"] == "f" else (3, 61)
    s = (f'\n    <path d="M{left} 66 Q{left + 1} 48 21 44 Q32 49 43 44 Q{right - 1} 48 {right} 66Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
         f'\n    <path d="M43 44 Q{right - 1} 48 {right} 66 L50 66 Q50.4 52 43 44Z" fill="{dark}"/>')
    if robe:
        s += f'\n    <path d="M25 48 L30 66 M39 48 L34 66" stroke="{dark}" stroke-width="1.4"/>'
    return s


def _hand(x, y, p, r=3.4):
    return f'\n    <ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 0.85:.2f}" fill="{_skin(p)}" stroke="{INK}" stroke-width="{LINE}"/>'


def _line(d, col, w):
    """A pole, shaft or haft: an ink line with its colour inside."""
    return (f'\n    <path d="{d}" stroke="{INK}" stroke-width="{w + 1.8}" stroke-linecap="round"/>'
            f'\n    <path d="{d}" stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>')


def _hood(col, p):
    """Back of a hood (before the head) and its rim (after the face)."""
    back = f'\n    <path d="M15.5 32 Q12 5 32 4 Q52 5 48.5 32 Q48 44 42 46 L22 46 Q16 44 15.5 32Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}"/>'
    rim = (f'\n    <path d="M17.2 30 Q14.4 5.6 32 5 Q49.6 5.6 46.8 30 Q44 17 32 16.2 Q20 17 17.2 30Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
           f'\n    <path d="M20.4 24 Q22.4 17.4 32 16.8 Q41.6 17.4 43.6 24" stroke="{_darker(col, 0.7)}" stroke-width="1.2"/>')
    return _g(p, back), _g(p, rim)


def _bow(col, p, strings=1):
    s = (f'\n    <path d="M49 12 Q64 42 49 72" stroke="{INK}" stroke-width="4.6" stroke-linecap="round"/>'
         f'\n    <path d="M49 12 Q64 42 49 72" stroke="{col}" stroke-width="2.6" stroke-linecap="round"/>')
    for k in range(strings):
        dx = k * 1.6
        s += f'\n    <path d="M{49 + dx * 0.3:.1f} 12 L{49 - dx:.1f} 42 L{49 + dx * 0.3:.1f} 72" stroke="#f0ecd8" stroke-width="0.8"/>'
    return s + _hand(56.5, 44, p)


def _quiver(fletch):
    s = (f'\n    <path d="M6 30 L13 26 L22 48 L15 52Z" fill="{WOOD}" stroke="{INK}" stroke-width="{LINE}"/>'
         f'\n    <path d="M7.5 32 L13.5 28.6" stroke="{GOLD_D}" stroke-width="1.4"/>')
    for (x, y) in ((6, 18), (9.5, 16.5), (13, 17.5)):
        s += (f'\n    <path d="M{x + 2} {y + 12} L{x} {y}" stroke="{INK}" stroke-width="2.2"/>'
              f'\n    <path d="M{x - 1.6} {y + 3.5} L{x} {y} L{x + 1.4} {y + 3.8} L{x + 0.6} {y + 7} L{x - 0.6} {y + 6.6}Z" fill="{fletch}" stroke="{INK}" stroke-width="0.9"/>')
    return s


def _staff(top_svg, glow_col, p, wood="#4a3a2c", x0=10.0, x1=12.0):
    """A staff held in front of the left shoulder, its head at the top, the hand on it."""
    hx = x0 + (x1 - x0) * 16 / 52
    return _glow(x1, 12, 12, glow_col) + _line(f"M{x0} 66 L{x1} 14", wood, 2.2) + top_svg + _hand(hx + 0.2, 50, p)


def _tome(col, p):
    return (f'\n    <path d="M38 48 L56 46 L57 60 L39 63Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
            f'\n    <path d="M39 62 L57 59.5 L57 61 L39.5 64Z" fill="#e8e0c8" stroke="{INK}" stroke-width="1"/>'
            f'\n    <path d="M44 51 L51 50 M44 54 L51 53" stroke="{GOLD}" stroke-width="1.1"/>'
            + _hand(41, 61, p))


# --- the cards --------------------------------------------------------------------------

def archers():
    # The archer: a green hood and tunic, a crimson sash, a quiver and a plain longbow.
    p = person("archer")
    back, rim = _hood("#2c3f29", p)
    _card("archer", "#2c3b2a", "#121a12", _quiver("#d8d0b8") + neck(p) + _body("#33472f", p)
          + f'\n    <path d="M18 44 L24 44 L50 66 L41 66Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.4"/>'
          + back + head(p, ears=False) + rim + _bow("#8a5a30", p))

    # The crossbowman: a leather jerkin and a brimmed hat, the crossbow across the chest.
    p = person("crossbowman")
    d = (38 / math.hypot(38, 18), -18 / math.hypot(38, 18))
    n = (-d[1], d[0])
    c = (47.0, 43.5)
    e1, e2 = (c[0] + n[0] * 12, c[1] + n[1] * 12), (c[0] - n[0] * 12, c[1] - n[1] * 12)
    ctrl, nock = (c[0] + d[0] * 7, c[1] + d[1] * 7), (c[0] - d[0] * 4, c[1] - d[1] * 4)
    tip = (c[0] + d[0] * 11, c[1] + d[1] * 11)

    def q(v):
        return "%.1f %.1f" % v
    _card("crossbowman", "#3b2f22", "#16110c", neck(p) + _body("#4a3e2e", p)
          + f'\n    <path d="M16 46 Q32 50 48 46 L47 66 L17 66Z" fill="#6a5236" stroke="{INK}" stroke-width="{LINE}"/>'
          + head(p)
          + f'\n    <path d="M9 19 Q32 13 55 19 Q44 22 32 22 Q20 22 9 19Z" fill="#3e3020" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M20 18 Q20 4 32 4 Q44 4 44 18Z" fill="#5a4630" stroke="{INK}" stroke-width="{LINE}"/>'
          + _line(f"M10 62 L{q(nock)}", WOOD_L, 3.4)
          + f'\n    <path d="M{q(e1)} L{q(nock)} L{q(e2)}" stroke="#e8e0c8" stroke-width="0.9"/>'
          + f'\n    <path d="M{q(e1)} Q{q(ctrl)} {q(e2)}" stroke="{INK}" stroke-width="3.6" stroke-linecap="round"/>'
          + f'\n    <path d="M{q(e1)} Q{q(ctrl)} {q(e2)}" stroke="#8a8e96" stroke-width="2" stroke-linecap="round"/>'
          + f'\n    <path d="M{q(nock)} L{q(tip)}" stroke="#b08a58" stroke-width="1.4"/>'
          + _hand(22, 56.5, p) + _hand(38, 49, p))

    # The swiftbowman: green and gold, a feathered cap, a golden bow with three strings.
    p = person("swiftbowman")
    _card("swiftbowman", "#2a4430", "#0f1a12", _quiver("#e8d890") + neck(p) + _body("#2f5a36", p)
          + f'\n    <path d="M18 44 L24 44 L50 66 L41 66Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>'
          + head(p)
          + f'\n    <path d="M17 19 Q19 5 33 5 Q47 5 48 18 Q40 14 32 14 Q24 14 17 19Z" fill="#2f6a3a" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M38 11 Q46 -3 60 -2 Q52 4 41 14Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.3"/>'
          + f'\n    <path d="M40 12 Q49 2 57 0" stroke="{GOLD_D}" stroke-width="0.8"/>'
          + _bow("#c8a050", p, strings=3))


def shield_line():
    # The shield bearer: a steel cap, a spear in hand, a tower shield hiding most of the body.
    p = person("shield_bearer")
    shield = (f'\n    <path d="M24 40 L60 36 L61 66 L25 66Z" fill="#6a4a2c" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
              f'\n    <path d="M36 39 L36.5 66 M48 37.6 L48.6 66" stroke="#4a3220" stroke-width="1.6"/>'
              f'\n    <path d="M25.6 41 L59 37.2 L60 66 L26 66Z" stroke="{STEEL}" stroke-width="2.2" stroke-linejoin="round"/>'
              f'\n    <ellipse cx="42.5" cy="55" rx="5" ry="5.4" fill="{STEEL}" stroke="{INK}" stroke-width="1.6"/>'
              f'\n    <path d="M42.5 40.5 L46 44.5 L42.5 48.5 L39 44.5Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.2"/>')
    _card("shield_bearer", "#3a3026", "#15110c", hair_back(p) + neck(p) + _body("#5a4a3a", p) + head(p)
          + f'\n    <path d="M19 22 Q19 7 32 7 Q45 7 45 22Z" fill="#8a9098" stroke="{INK}" stroke-width="{LINE}"/>'
          + _line("M17.5 22 L46.5 22", STEEL_D, 1.6)
          + f'\n    <path d="M24 13 Q28 9.5 33 9.5" stroke="{STEEL_L}" stroke-width="1.4" stroke-linecap="round"/>'
          + _line("M9 66 L15 6", WOOD_L, 1.8)
          + f'\n    <path d="M15.4 0 L18 8 L15 11 L12.6 7.6Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.3"/>'
          + _hand(11.2, 46, p) + shield)

    # The warrior: a horned helm, mail and a crimson tabard, a round shield on the arm, the sword up.
    p = person("warrior")
    _card("warrior", "#2e3442", "#11141a", neck(p) + _body(STEEL_D, p)
          + "".join(f'\n    <path d="M{8 + k * 3} {50 + (k % 2) * 4} q1.5 1.6 3 0" stroke="#4e545a" stroke-width="0.9"/>' for k in range(16))
          + f'\n    <path d="M25 46 L39 46 L37 66 L27 66Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.6"/>'
          + head(p)
          + f'\n    <path d="M19 21 Q18.5 6 32 6 Q45.5 6 45 21 Z" fill="{STEEL}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M30.4 19.6 L33.6 19.6 L33.2 28.4 L30.8 28.4Z" fill="{STEEL}" stroke="{INK}" stroke-width="1.3"/>'
          + _line("M18 21 L46 21", STEEL_D, 1.6)
          + f'\n    <path d="M22 13 Q26 8.6 30 8.4" stroke="{STEEL_L}" stroke-width="1.4" stroke-linecap="round"/>'
          + f'\n    <path d="M20 15 Q8 13 7 1 Q13 9 21 10Z" fill="#e8dcc0" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <path d="M44 15 Q56 13 57 1 Q51 9 43 10Z" fill="#e8dcc0" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <circle cx="12" cy="53" r="12.5" fill="{WOOD}" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <circle cx="12" cy="53" r="11" stroke="{STEEL}" stroke-width="2"/>'
          + f'\n    <circle cx="12" cy="53" r="3.4" fill="{STEEL}" stroke="{INK}" stroke-width="1.2"/>'
          + f'\n    <path d="M51 48 L54 8 L57 3 L59 9 L56 48Z" fill="#d8dde2" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M55.6 10 L53.6 46" stroke="#ffffff" stroke-width="0.9" opacity="0.7"/>'
          + _line("M47 48.5 L60 49.5", GOLD, 2.2)
          + _hand(53, 54, p))

    # The berserker: a fur-trimmed leather vest, bare arms, a wild red mane, a great axe.
    p = person("berserker")
    _card("berserker", "#42201a", "#140a08", hair_back(p) + neck(p)
          + f'\n    <path d="M6 66 Q7 48 21 44 Q32 49 43 44 Q57 48 58 66Z" fill="{_skin(p)}" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M14 66 Q15 50 23 46 Q32 51 41 46 Q49 50 50 66Z" fill="#5a3c22" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M14 50 L18 46 L21 49 L24 45 L26 49 L29 46 L32 50 L35 46 L38 49 L40 45 L43 49 L46 46 L50 50 L47 53 L32 54 L17 53Z" fill="#7a5a3a" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'
          + head(p)
          + _line("M42 66 L57 10", WOOD_L, 2.4)
          + f'\n    <path d="M56 13 Q66 8 66 26 Q60 20 53 22Z" fill="#b8bec6" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <path d="M57 11 Q49 2 42 9 Q48 13 55 18Z" fill="#b8bec6" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + _hand(48, 46, p), light="#ff6a30", light_op=0.16)

    # The halberdier: a blue coat with a steel breastplate, a wide kettle hat, the halberd.
    p = person("halberdier")
    _card("halberdier", "#28324c", "#0d111b", neck(p) + _body("#3a4a6a", p)
          + f'\n    <path d="M18 47 Q32 51 46 47 L45 66 L19 66Z" fill="{STEEL}" stroke="{INK}" stroke-width="{LINE}"/>'
          + f'\n    <path d="M32 50 L32 66" stroke="{STEEL_D}" stroke-width="1.4"/>'
          + head(p)
          + f'\n    <path d="M8 21 L56 21 L46 15 Q46 3 32 3 Q18 3 18 15Z" fill="{STEEL}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M18.5 15 L45.5 15" stroke="{STEEL_D}" stroke-width="1.4"/>'
          + f'\n    <path d="M23 10 Q27 5.6 32 5.4" stroke="{STEEL_L}" stroke-width="1.4" stroke-linecap="round"/>'
          + _line("M53 66 L54 6", WOOD_L, 2.2)
          + f'\n    <path d="M54 10 Q66 9 66 26 Q61 22 54 22Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
          + f'\n    <path d="M54 12 L46 9 L54 16Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>'
          + f'\n    <path d="M52.6 7 L54 -2 L55.4 7Z" fill="{STEEL_L}" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>'
          + _hand(53.5, 44, p))


def summoners():
    def summoner(kind, top, bottom, robe, hat, band, held, glow_col, light):
        p = person(kind, dy=3)
        return _card(kind, top, bottom, hair_back(p) + neck(p) + _body(robe, p, robe=True)
                     + f'\n    <path d="M21 45 Q32 51 43 45 L40 50 Q32 54 24 50Z" fill="{band}" stroke="{INK}" stroke-width="1.4"/>'
                     + head(p)
                     + f'\n    <path d="M6 23 Q32 15 58 23 Q46 26 32 26 Q18 26 6 23Z" fill="{hat}" stroke="{INK}" stroke-width="{LINE}"/>'
                     + f'\n    <path d="M19 22 Q22 12 28 8 Q31 -2 40 -4 Q35 4 37 10 Q43 16 45 22 Q32 19 19 22Z" fill="{hat}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
                     + f'\n    <path d="M19.6 20 Q32 16.5 44.4 20" stroke="{band}" stroke-width="2.2"/>'
                     + _glow(51, 46, 15, glow_col, 0.7) + held + _hand(51, 55.5, p), light=light, light_op=0.1)

    orb = (f'\n    <circle cx="51" cy="46" r="6.4" fill="#a87cff" stroke="{INK}" stroke-width="{LINE}"/>'
           f'\n    <circle cx="51" cy="46" r="3.6" fill="#c8a8ff"/><circle cx="49" cy="44" r="1.6" fill="#f0e8ff"/>'
           + _sparkles([(42, 36), (58, 38)], "#d8c4ff", 0.9))
    summoner("summoner", "#2a2642", "#0d0c18", "#243a44", "#3a2a55", "#9a6cff", orb, "#9a6cff", "#9a6cff")
    flame = (f'\n    <path d="M51 32 Q60 41 57 48 Q55 53 51 53 Q46 53 45 48 Q44 43 48 39 Q48 44 51 44 Q53 38 51 32Z" fill="#ff8a30" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
             f'\n    <path d="M51 40 Q56 45 54 49 Q53 51 51 51 Q48 51 48 48 Q48 45 50 44 Q51 43 51 40Z" fill="#ffc040"/>'
             + _sparkles([(43, 33), (59, 36)], "#ffc060", 0.8))
    summoner("fire_summoner", "#44201a", "#140806", "#5a2418", "#6a2418", "#ff8a30", flame, "#ff8a30", "#ff8a30")

    # The druid: a brown hood, a moss robe and a crooked staff that sprouts.
    p = person("druid")
    back, rim = _hood("#4a3a24", p)
    top = (_line("M13 14 Q8 9 11 4", WOOD, 2)
           + f'\n    <ellipse cx="12" cy="11" rx="4" ry="3.4" fill="#5aa04a" stroke="{INK}" stroke-width="1.4"/>'
           + f'\n    <path d="M15 8 Q21 4 22 9 Q18 11 15 8Z" fill="#7ad06a" stroke="{INK}" stroke-width="1"/>')
    _card("druid", "#22341f", "#0a120a", back + hair_back(p) + neck(p) + _body("#3e5a2c", p, robe=True)
          + head(p, ears=False) + rim + _staff(top, "#8ae08a", p, wood=WOOD, x0=9, x1=13)
          + "".join(f'\n    <path d="M{x} {y} q3 -2 5 1 q-3 2 -5 -1Z" fill="#7ad06a" stroke="{INK}" stroke-width="0.7" transform="rotate({r} {x} {y})"/>'
                    for (x, y, r) in ((52, 30, 20), (56, 44, -30), (48, 58, 40))), light="#8ae08a", light_op=0.1)


def mages():
    def mage(kind, top, bottom, robe, trim, staff_top, glow_col, tome, extra="", light="#ffffff"):
        p = person(kind)
        _card(kind, top, bottom, hair_back(p) + neck(p) + _body(robe, p, robe=True)
              + f'\n    <path d="M21 45 Q32 51 43 45 L38 52 L32 49 L26 52Z" fill="{trim}" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'
              + head(p) + _staff(staff_top, glow_col, p) + _tome(tome, p) + extra, light=light, light_op=0.12)

    orb = (f'\n    <circle cx="12" cy="11" r="5.4" fill="#3a5ab0" stroke="{INK}" stroke-width="{LINE}"/>'
           f'\n    <circle cx="10.5" cy="9.5" r="1.8" fill="#b8c8ff"/>'
           f'\n    <path d="M7 15 Q12 19 17 15" stroke="{INK}" stroke-width="2.4"/>')
    mage("apprentice", "#30343e", "#101218", "#4a4a50", "#6a6a74", orb, "#5a7ae0", "#5a3a2a", light="#8aa0ff")
    flame = (f'\n    <path d="M12 0 Q19 8 17 13 Q15 17 12 17 Q8 17 7 13 Q6 8 10 5 Q10 9 12 10 Q13 5 12 0Z" fill="#ff8a30" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
             f'\n    <path d="M12 8 Q15 11 14.5 14 Q13.6 15.6 12 15.6 Q9.6 15.6 9.6 13.6 Q9.6 11.6 11 10.6Z" fill="#ffc040"/>'
             f'\n    <path d="M7 16 Q12 20 17 16" stroke="{INK}" stroke-width="2.4"/>')
    mage("fire_mage", "#44201a", "#140806", "#7a2a20", "#d8602a", flame, "#ff8a30", "#4a1a12",
         _sparkles([(26, 3), (56, 22)], "#ffb060", 0.8), light="#ff8a30")
    crystal = (f'\n    <path d="M12 1 L17 10 L12 18 L7 10Z" fill="#bfe8ff" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'
               f'\n    <path d="M12 1 L12 18 M7 10 L17 10" stroke="#ffffff" stroke-width="0.8" opacity="0.8"/>')
    mage("ice_mage", "#24384a", "#0a1018", "#5a8ab0", "#cfeaff", crystal, "#a8dcff", "#2a4a6a",
         _sparkles([(52, 24), (58, 12)], "#e8f6ff", 0.9), light="#a8dcff")
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
    p = person("acolyte", dy=2)
    back, rim = _hood("#d4cab4", p)
    _card("acolyte", "#3c3426", "#141008", _glow(32, 26, 26, "#fff2c0", 0.5) + neck(p) + _body(robe, p, robe=True)
          + f'\n    <path d="M29 47 L35 47 L34.4 66 L29.6 66Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.2"/>'
          + back + head(p, hair=False, ears=False) + rim
          + f'\n    <path d="M27 66 L29 55 Q30 50 32 46 Q34 50 35 55 L37 66Z" fill="{_darker(robe, 0.86)}" stroke="{INK}" stroke-width="1.6"/>'
          + f'\n    <path d="M29 58 Q29.5 49 32 45 Q34.5 49 35 58 Q32 60 29 58Z" fill="{_skin(p)}" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>'
          + f'\n    <path d="M32 46.5 L32 58.5" stroke="{_darker(_skin(p), 0.7)}" stroke-width="0.9"/>'
          + _sparkles([(14, 14), (51, 10), (54, 30)], "#fff6d0", 0.9), light="#fff2c0", light_op=0.15)

    # The inquisitor: a crimson helm crowned with a gold cross, a steel breastplate bearing it,
    # a dark cloak and the warhammer.
    p = person("inquisitor")
    _card("inquisitor", "#301418", "#0e0608",
          f'\n    <path d="M2 66 Q2 42 18 38 L46 38 Q62 42 62 66Z" fill="#2a1a1a" stroke="{INK}" stroke-width="{LINE}"/>'
          + hair_back(p) + neck(p) + _body("#3a2224", p)
          + f'\n    <path d="M18 47 Q32 51 46 47 L45 66 L19 66Z" fill="#8a8f96" stroke="{INK}" stroke-width="{LINE}"/>'
          + _line("M32 51 L32 63 M26 55.5 L38 55.5", GOLD, 2.4)
          + head(p)
          + f'\n    <path d="M18.5 30 Q17 6 32 6 Q47 6 45.5 30 L42 30 Q42 19 32 19 Q22 19 22 30Z" fill="#6a1a20" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M22 19 Q32 15.5 42 19" stroke="{GOLD_D}" stroke-width="1.6"/>'
          + _line("M32 6 L32 -2 M28.5 1.5 L35.5 1.5", GOLD, 2.2)
          + _line("M53 66 L55 18", WOOD_L, 2.4)
          + f'\n    <path d="M45 10 L64 11 L64 22 L45 21Z" fill="#8a8f96" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M54.5 13 L54.5 19 M52 16 L57 16" stroke="{GOLD}" stroke-width="1.4"/>'
          + _hand(53.8, 44, p), light=CRIMSON, light_op=0.2)

    # The high priest: a tall white mitre with gold, a broad gold stole and a sun crosier.
    p = person("high_priest", dy=4)
    rays = "".join(
        f'\n    <path d="M{12 + math.cos(k * math.pi / 4) * 6.4:.1f} {11 + math.sin(k * math.pi / 4) * 6.4:.1f} '
        f'L{12 + math.cos(k * math.pi / 4) * 9.6:.1f} {11 + math.sin(k * math.pi / 4) * 9.6:.1f}" stroke="{GOLD}" stroke-width="1.6" stroke-linecap="round"/>'
        for k in range(8))
    sun = rays + f'\n    <circle cx="12" cy="11" r="5" fill="{GOLD}" stroke="{INK}" stroke-width="1.6"/><circle cx="11" cy="10" r="1.8" fill="#fff6d0"/>'
    _card("high_priest", "#3c3624", "#13110a", neck(p) + _body("#f0ead8", p, robe=True)
          + f'\n    <path d="M22 45 L28 47 L30 66 L22 66Z M36 47 L42 45 L42 66 L34 66Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'
          + head(p)
          + f'\n    <path d="M20 18 L21 2 L32 -6 L43 2 L44 18 Q32 15 20 18Z" fill="#f2ecdc" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
          + f'\n    <path d="M20.6 15.5 Q32 12.5 43.4 15.5" stroke="{GOLD}" stroke-width="2.4"/>'
          + f'\n    <path d="M32 -4 L32 14 M27.5 4.5 L36.5 4.5" stroke="{GOLD}" stroke-width="2"/>'
          + _staff(sun, "#fff2c0", p, wood=GOLD_D), light="#fff2c0", light_op=0.18)


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
