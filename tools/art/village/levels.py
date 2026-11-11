"""Walls, gates, wall towers and watchtowers at levels 4 and 5: fort_marks, _fort_levels,
fortifications()."""

from ..core import FORT, INK, IRON_L, P
from ..buildings import HALL_PALETTES
from .basalt import bas_gate, bas_wall, bas_wall_tower
from .granite import gran_gate, gran_wall, gran_wall_tower
from .ice import ice_gate, ice_wall, ice_wall_tower
from .limestone import lime_gate, lime_wall, lime_wall_tower
from .sandstone import sand_gate, sand_wall, sand_wall_tower
from .stone import gate, wall, wall_tower, watchtower
from .wood import WOOD_DECK, wood_gate, wood_wall, wood_wall_tower


# Per piece kind and material: the front face (gy), the height its marks go up
# to, and the half width of a tower (the Fortifications advancements,
# docs/advancements-design.md; Config.TOWER_LEVELS, PIECE_LEVELS).
FORT_GEOMETRY = {
    "wall": {"stone": (0.14, 34), "wood": (0.06, 36), "sandstone": (0.14, 32), "basalt": (0.14, 34),
             "limestone": (0.13, 32), "granite": (0.15, 28), "ice": (0.15, 28)},
    "gate": {"stone": (0.16, 46), "wood": (0.06, 36), "sandstone": (0.16, 42), "basalt": (0.16, 44),
             "limestone": (0.16, 42), "granite": (0.16, 40), "ice": (0.16, 40)},
    "wall_tower": {"stone": (0.36, 74), "wood": (0.32, 60), "sandstone": (0.36, 74), "basalt": (0.36, 74),
                   "limestone": (0.36, 74), "granite": (0.36, 74), "ice": (0.36, 74)},
    "watchtower": {"stone": (0.3, 16)},
}


def _studs(a, pts, metal):
    for x, y in pts:
        a.ellipse(x, y, 1.4, 1.4, metal, INK, 0.5)


def _crest(a, x, y, pal, big=1.0):
    a.ellipse(x, y, 6.5 * big, 7.5 * big, pal["metal"], INK, 1.1)
    a.ellipse(x, y, 4.2 * big, 5 * big, pal["accent"], INK, 0.8)
    a.ellipse(x, y - 1.2 * big, 1.6 * big, 1.6 * big, pal["metal"])


def fort_marks(a, kind, mat, level):
    """What levels 4 and 5 add to a wall, gate, wall tower or watchtower in its
    material's colours: level 4 a reinforced footing, iron-studded; level 5 also
    gilded crests and gilded studs at the corners."""
    pal = HALL_PALETTES[mat]
    if kind in ("wall", "gate"):
        y1, h = FORT_GEOMETRY[kind][mat]
        spans = [(-0.5, 0.5)] if kind == "wall" else [(-0.5, -0.22), (0.22, 0.5)]
        for u0, u1 in spans:  # the footing before the front face
            a.box(u0, u1, y1, y1 + 0.06, 0, 8, pal["t"], pal["j"], pal["j"], sw=1.1)
            n = max(2, int((u1 - u0) / 0.12))
            _studs(a, [P(u0 + (u1 - u0) * (k + 0.5) / n, y1 + 0.06, 4) for k in range(n)], IRON_L)
        if level >= 5:
            if kind == "wall":
                for u in (-0.3, 0.3):
                    x, y = P(u, y1, h * 0.55)
                    _crest(a, x, y, pal)
            else:
                x, y = P(0.0, y1, h * 0.78)
                _crest(a, x, y, pal, 1.2)
            for u, _ in spans:
                _studs(a, [P(u + 0.03, y1 + 0.06, 8)], pal["metal"])
    else:
        s, h = FORT_GEOMETRY[kind][mat]
        r = s + 0.05
        # the footing round its base: only its two faces in front (a top would cover the tower)
        a.poly([P(-r, r, 0), P(r, r, 0), P(r, r, 10), P(-r, r, 10)], pal["l"], INK, 1.1)
        a.poly([P(r, r, 0), P(r, -r, 0), P(r, -r, 10), P(r, r, 10)], pal["r"], INK, 1.1)
        a.line([P(-r, r, 10), P(r, r, 10), P(r, -r, 10)], pal["t"], 2.2)
        a.line([P(-r, r, 4), P(r, r, 4), P(r, -r, 4)], pal["j"], 1.2)
        _studs(a, [P(u, r, 5) for u in (-r * 0.6, 0.0, r * 0.6)] + [P(r, u, 5) for u in (-r * 0.6, 0.0, r * 0.6)], IRON_L)
        if level >= 5:
            x, y = P(s * 0.55, s, min(h * 0.4, h - 10) if kind == "wall_tower" else h * 0.55)
            _crest(a, x, y, pal)
            _studs(a, [P(-r, r, 10), P(r, r, 10), P(r, -r, 10)], pal["metal"])


def _fort_levels(kind, mat, fn):
    """Levels 4 and 5 of `fn` (a wall or gate function, which saves itself)."""
    for lvl in (4, 5):
        FORT["hook"] = lambda a, l=lvl: fort_marks(a, kind, mat, l)
        fn(lvl)
    FORT["hook"] = None


def fortifications():
    """Walls, gates, wall towers and watchtowers at levels 4 and 5 (the
    Fortifications advancements), every material."""
    walls = {"stone": (wall, gate), "wood": (wood_wall, wood_gate), "sandstone": (sand_wall, sand_gate),
             "basalt": (bas_wall, bas_gate), "limestone": (lime_wall, lime_gate), "granite": (gran_wall, gran_gate),
             "ice": (ice_wall, ice_gate)}
    for mat, (w, g) in walls.items():
        _fort_levels("wall", mat, w)
        _fort_levels("gate", mat, g)
    towers = [("", wall_tower, 78), ("wood_", wood_wall_tower, WOOD_DECK + 2), ("sandstone_", sand_wall_tower, 78),
              ("basalt_", bas_wall_tower, 78), ("limestone_", lime_wall_tower, 78), ("granite_", gran_wall_tower, 78),
              ("ice_", ice_wall_tower, 78)]
    for prefix, fn, deck in towers:
        mat = prefix.rstrip("_") or "stone"
        for lvl in (4, 5):
            FORT["hook"] = lambda a, l=lvl, m=mat: fort_marks(a, "wall_tower", m, l)
            wt = fn(level=lvl)
            wt.pts = fn(level=3).pts[:]
            wt.save(prefix + "wall_tower_%d" % lvl, extra={"platform": deck})
            FORT["hook"] = None
            wtf = fn(front=True, level=lvl)
            wtf.pts = wt.pts[:]
            wtf.save(prefix + "wall_tower_front_%d" % lvl)
    for lvl in (4, 5):
        FORT["hook"] = lambda a, l=lvl: fort_marks(a, "watchtower", "stone", l)
        w = watchtower(level=lvl)
        w.pts = watchtower(level=3).pts[:]
        w.save("watchtower_%d" % lvl, extra={"platform": 66})
        FORT["hook"] = None
        wf = watchtower(front=True, level=lvl)
        wf.pts = w.pts[:]
        wf.save("watchtower_front_%d" % lvl)
