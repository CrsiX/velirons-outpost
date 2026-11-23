"""People drawn as square busts, one style for all: the upgrade dialog's unit cards
(unit_cards.py) and the cutscenes' portraits (portraits.py).

A person is a dict of parts: sex (m/f), age (young/adult/old), skin (an index into SKIN, or a
colour for the bound and the cursed), face (FACES), hair ((style, colour); style "bald" for none),
eyes ((shape, iris); iris "bound" for the pale empty eyes of the crown's thralls, "void" for black
ones), nose (NOSES), expr (EXPRESSIONS), and optionally beard ((style, colour)) and freckles.
`head()` draws it at one scale and framing with the same line weights, eyes and shading; the
callers add clothes and gear around it and write it with `card()`. No jewellery and no make-up."""

import math
import os
import re

from .core import ART, GOLD, GOLD_D, INK, WOOD

STEEL, STEEL_D, STEEL_L = "#9aa0a8", "#6a7078", "#c8ced6"
SCLERA = "#f4eee6"
LINE = 1.8  # the outline of every shape

# Skin tones, pale to deep.
SKIN = ["#f2d4b8", "#e6ba98", "#d6a47a", "#c08a5a", "#9a6640", "#74492a", "#5a3820"]
HAIR = {
    "black": "#1e1a18", "dark": "#3a2618", "brown": "#5e3c22", "auburn": "#8a3e1e",
    "red": "#c04a1e", "copper": "#b0582a", "blond": "#d8b060", "grey": "#9a9894", "white": "#e8e4dc",
}
IRIS = {
    "brown": "#6a4020", "dark": "#3a2414", "blue": "#4a7ab8", "green": "#4a8a3a",
    "grey": "#7a8a96", "hazel": "#8a6a30", "amber": "#c08020",
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


def darker(col, k=0.78):
    r, g, b = (int(col[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(c * k))) for c in (r, g, b))


CARD_SIZE = 256  # pixels; the art is drawn on 64x64 units


def card(name, top, bottom, art, light="#ffffff", light_op=0.12):
    """Writes art/<name>.svg: a backdrop gradient, a soft light behind the head, the bust `art`
    clipped to a round-cornered square, an ink frame."""
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{CARD_SIZE}" height="{CARD_SIZE}" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
    <radialGradient id="lt" cx="0.5" cy="0.38" r="0.45"><stop offset="0" stop-color="{light}" stop-opacity="{light_op}"/><stop offset="1" stop-color="{light}" stop-opacity="0"/></radialGradient>
    <clipPath id="c"><rect x="2" y="2" width="60" height="60" rx="6"/></clipPath>
  </defs>
  <rect x="2" y="2" width="60" height="60" rx="6" fill="url(#bg)"/>
  <g clip-path="url(#c)">
    <rect x="2" y="2" width="60" height="60" fill="url(#lt)"/>{art}
  </g>
  <rect x="1.5" y="1.5" width="61" height="61" rx="6.5" fill="none" stroke="{INK}" stroke-width="2"/>
</svg>
'''
    # ThorVG can drop a stroked line that keeps the default fill: every stroke-only path says so.
    svg = re.sub(r'<path (?![^>]*fill=)', '<path fill="none" ', svg)
    svg = re.sub(r'<circle (?![^>]*fill=)', '<circle fill="none" ', svg)
    with open(os.path.join(ART, name + ".svg"), "w") as fh:
        fh.write(svg)


def glow(x, y, r, col, op=0.55):
    gid = "g%d_%d" % (round(x), round(y))
    return (f'\n    <defs><radialGradient id="{gid}"><stop offset="0" stop-color="{col}" stop-opacity="{op}"/>'
            f'<stop offset="1" stop-color="{col}" stop-opacity="0"/></radialGradient></defs>'
            f'\n    <circle cx="{x}" cy="{y}" r="{r}" fill="url(#{gid})"/>')


def sparkles(pts, col, r=1.0):
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


def skin_of(p):
    return p["skin"] if isinstance(p["skin"], str) else SKIN[p["skin"]]


def hair_back(p):
    """The hair behind the head and shoulders: long hair, a bun, a ponytail, an afro, a mane."""
    style, name = p["hair"]
    col = HAIR[name]
    d = darker(col, 0.8)
    if style in ("long", "bob"):
        ln = 40 if style == "bob" else 50 if p["sex"] == "f" else 46
        s = (f'\n    <path d="M18.5 24 Q15 7 32 6 Q49 7 45.5 24 Q47 36 48.5 {ln} Q44 {ln + 3} 40 {ln - 2} L39 36 L25 36 L24 {ln - 2} Q20 {ln + 3} 15.5 {ln} Q17 36 18.5 24Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
             f'\n    <path d="M19 32 Q18.5 {ln - 6} 17.5 {ln - 1} M45 32 Q45.5 {ln - 6} 46.5 {ln - 1}" stroke="{d}" stroke-width="1"/>')
    elif style == "braid":
        s = (f'\n    <path d="M19 24 Q14 30 15.5 38 Q13.5 44 16 50 Q14.5 54 17 58 L20 57 Q18.5 53 20 50 Q18 44 20 38 Q19 31 22 27Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
             f'\n    <path d="M15.6 38 L19.8 39 M16 44 L19.4 45 M16.2 50 L19.8 50.6" stroke="{d}" stroke-width="1"/>')
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
    sk = skin_of(p)
    w = 8 if p["sex"] == "f" else 10
    return _g(p, f'\n    <rect x="{32 - w / 2}" y="33" width="{w}" height="14" fill="{darker(sk, 0.86)}" stroke="{INK}" stroke-width="{LINE}"/>')


def _eyes(p):
    shape, iris = p["eyes"]
    _brows, open_, _mouth = EXPRESSIONS[p["expr"]]
    line = darker(skin_of(p), 0.55)
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
            white = SCLERA
            inner = (f'\n    <circle cx="{cx}" cy="{cy - 0.1:.2f}" r="{r:.2f}" fill="{IRIS.get(iris, "#000")}"/>'
                     f'\n    <circle cx="{cx}" cy="{cy - 0.1:.2f}" r="{r * 0.5:.2f}" fill="{INK}"/>'
                     f'\n    <circle cx="{cx + 0.5}" cy="{cy - 0.6:.2f}" r="0.42" fill="#ffffff"/>')
            if iris == "bound":  # the crown's thralls: a pale iris, no pupil
                white, inner = "#dce6f2", f'\n    <circle cx="{cx}" cy="{cy - 0.1:.2f}" r="{r:.2f}" fill="#9ab8f0" opacity="0.7"/>'
            elif iris == "void":  # the curse: the whole eye black
                white, inner = "#050306", f'\n    <circle cx="{cx + 0.6}" cy="{cy - 0.5:.2f}" r="0.45" fill="#b070c0"/>'
            s += (f'\n    <path d="M{out} {cy} Q{cx} {cy - h:.2f} {inn} {cy} Q{cx} {cy + h * 0.75:.2f} {out} {cy}Z" fill="{white}"/>' + inner
                  + f'\n    <path d="M{out + side * 0.2} {cy + 0.1} Q{cx} {cy - h - 0.3:.2f} {inn - side * 0.1} {cy}" stroke="{INK}" stroke-width="1.25" stroke-linecap="round"/>')
        if p["age"] == "old":
            s += (f'\n    <path d="M{cx - 2} {cy + 2.3} Q{cx} {cy + 3.3} {cx + 2} {cy + 2.3}" stroke="{line}" stroke-width="0.7"/>'
                  f'\n    <path d="M{out + side * 0.8} {cy - 0.6} l{side * 1.5} -0.7 M{out + side * 0.8} {cy + 0.6} l{side * 1.5} 0.8" stroke="{line}" stroke-width="0.7" stroke-linecap="round"/>')
    return s


def _brows(p):
    kind, _open, _mouth = EXPRESSIONS[p["expr"]]
    name = p["beard"][1] if p.get("beard") and p["hair"][0] == "bald" else p["hair"][1]
    col = darker(HAIR[name], 0.75)
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
    sk = skin_of(p)
    lip = darker(sk, 0.5)
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
    d = darker(col, 0.8)
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
    "braid": "M20 22 Q19 9 32 8.5 Q45 9 44 22 Q42 14 32 13 Q22 14 20 22Z",
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
            f'\n    <path d="M25 11.4 Q29 9.6 34 9.8" stroke="{darker(col, 1.25)}" stroke-width="1.1" opacity="0.6" stroke-linecap="round"/>')


def head(p, hair=True, ears=True):
    """Ears (not under a hood), face, the features, wrinkles, freckles, facial hair and (`hair`)
    the hair in front. The shadow on the far cheek is clipped to the face."""
    sk = skin_of(p)
    sh = darker(sk, 0.84)
    line = darker(sk, 0.6)
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
            s += f'\n    <circle cx="{x}" cy="{y}" r="0.45" fill="{darker(sk, 0.68)}"/>'
    beard, mous = _beard(p) if p.get("beard") else ("", "")
    s += beard + _mouth(p) + mous
    if hair:
        s += _hair_front(p)
    return _g(p, s)


def person(entry, dy=0):
    """A CAST entry ready to draw; dy moves the head down (under a tall hat)."""
    p = dict(entry)
    p["dy"] = dy
    return p


# --- clothes and gear ----------------------------------------------------------------------

def body(col, p, robe=False):
    """The upper body in its clothes, the neck opening at the top; women's shoulders are narrower."""
    dark = darker(col, 0.78)
    left, right = (6, 58) if p["sex"] == "f" else (3, 61)
    s = (f'\n    <path d="M{left} 66 Q{left + 1} 48 21 44 Q32 49 43 44 Q{right - 1} 48 {right} 66Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
         f'\n    <path d="M43 44 Q{right - 1} 48 {right} 66 L50 66 Q50.4 52 43 44Z" fill="{dark}"/>')
    if robe:
        s += f'\n    <path d="M25 48 L30 66 M39 48 L34 66" stroke="{dark}" stroke-width="1.4"/>'
    return s


def hand(x, y, p, r=3.4):
    return f'\n    <ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * 0.85:.2f}" fill="{skin_of(p)}" stroke="{INK}" stroke-width="{LINE}"/>'


def pole(d, col, w):
    """A pole, shaft or haft: an ink line with its colour inside."""
    return (f'\n    <path d="{d}" stroke="{INK}" stroke-width="{w + 1.8}" stroke-linecap="round"/>'
            f'\n    <path d="{d}" stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>')


def hood(col, p):
    """Back of a hood (before the head) and its rim (after the face)."""
    back = f'\n    <path d="M15.5 32 Q12 5 32 4 Q52 5 48.5 32 Q48 44 42 46 L22 46 Q16 44 15.5 32Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}"/>'
    rim = (f'\n    <path d="M17.2 30 Q14.4 5.6 32 5 Q49.6 5.6 46.8 30 Q44 17 32 16.2 Q20 17 17.2 30Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
           f'\n    <path d="M20.4 24 Q22.4 17.4 32 16.8 Q41.6 17.4 43.6 24" stroke="{darker(col, 0.7)}" stroke-width="1.2"/>')
    return _g(p, back), _g(p, rim)


def bow(col, p, strings=1):
    s = (f'\n    <path d="M49 12 Q64 42 49 72" stroke="{INK}" stroke-width="4.6" stroke-linecap="round"/>'
         f'\n    <path d="M49 12 Q64 42 49 72" stroke="{col}" stroke-width="2.6" stroke-linecap="round"/>')
    for k in range(strings):
        dx = k * 1.6
        s += f'\n    <path d="M{49 + dx * 0.3:.1f} 12 L{49 - dx:.1f} 42 L{49 + dx * 0.3:.1f} 72" stroke="#f0ecd8" stroke-width="0.8"/>'
    return s + hand(56.5, 44, p)


def quiver(fletch):
    s = (f'\n    <path d="M6 30 L13 26 L22 48 L15 52Z" fill="{WOOD}" stroke="{INK}" stroke-width="{LINE}"/>'
         f'\n    <path d="M7.5 32 L13.5 28.6" stroke="{GOLD_D}" stroke-width="1.4"/>')
    for (x, y) in ((6, 18), (9.5, 16.5), (13, 17.5)):
        s += (f'\n    <path d="M{x + 2} {y + 12} L{x} {y}" stroke="{INK}" stroke-width="2.2"/>'
              f'\n    <path d="M{x - 1.6} {y + 3.5} L{x} {y} L{x + 1.4} {y + 3.8} L{x + 0.6} {y + 7} L{x - 0.6} {y + 6.6}Z" fill="{fletch}" stroke="{INK}" stroke-width="0.9"/>')
    return s


def staff(top_svg, glow_col, p, wood="#4a3a2c", x0=10.0, x1=12.0):
    """A staff held in front of the left shoulder, its head at the top, the hand on it."""
    hx = x0 + (x1 - x0) * 16 / 52
    return glow(x1, 12, 12, glow_col) + pole(f"M{x0} 66 L{x1} 14", wood, 2.2) + top_svg + hand(hx + 0.2, 50, p)


def tome(col, p):
    return (f'\n    <path d="M38 48 L56 46 L57 60 L39 63Z" fill="{col}" stroke="{INK}" stroke-width="{LINE}" stroke-linejoin="round"/>'
            f'\n    <path d="M39 62 L57 59.5 L57 61 L39.5 64Z" fill="#e8e0c8" stroke="{INK}" stroke-width="1"/>'
            f'\n    <path d="M44 51 L51 50 M44 54 L51 53" stroke="{GOLD}" stroke-width="1.1"/>'
            + hand(41, 61, p))
