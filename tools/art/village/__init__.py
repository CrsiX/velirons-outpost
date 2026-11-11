"""The village pieces: walls, gates, wall towers, their ruins and the hut, one module per
material (stone, wood, sandstone, basalt, limestone, granite, ice), and levels 4 and 5
in levels.py.

A village's huts share its material: stone keeps the timber cabin (hut()),
sandstone a flat-roofed sandstone house with blue doors and tiles, basalt a dark,
solid house of black blocks under a slate roof, wood a canvas tent."""

from .basalt import (
    bas_gate, bas_gate_ruin, bas_hut, bas_wall, bas_wall_ruin, bas_wall_tower, bas_wall_tower_ruin,
)
from .granite import (
    gran_gate, gran_gate_ruin, gran_hut, gran_wall, gran_wall_ruin, gran_wall_tower,
    gran_wall_tower_ruin,
)
from .ice import (
    ice_gate, ice_gate_ruin, ice_hut, ice_wall, ice_wall_ruin, ice_wall_tower, ice_wall_tower_ruin,
)
from .limestone import (
    lime_gate, lime_gate_ruin, lime_hut, lime_wall, lime_wall_ruin, lime_wall_tower,
    lime_wall_tower_ruin,
)
from .sandstone import (
    sand_gate, sand_gate_ruin, sand_hut, sand_wall, sand_wall_ruin, sand_wall_tower,
    sand_wall_tower_ruin,
)
from .wood import (
    WOOD_DECK, wood_gate, wood_gate_ruin, wood_hut, wood_wall, wood_wall_ruin, wood_wall_tower,
    wood_wall_tower_ruin,
)


def village_pieces_materials():
    """The walls, gates and wall towers in wood, sandstone, basalt, limestone,
    granite and ice (stone's are wall(), gate(), wall_tower()); each tower's levels and
    front layer on one canvas."""
    for lvl in (1, 2, 3):
        wood_wall(lvl)
        wood_gate(lvl)
        sand_wall(lvl)
        sand_gate(lvl)
        bas_wall(lvl)
        bas_gate(lvl)
        lime_wall(lvl)
        lime_gate(lvl)
        gran_wall(lvl)
        gran_gate(lvl)
        ice_wall(lvl)
        ice_gate(lvl)
    wood_wall_ruin()
    wood_gate_ruin()
    wood_wall_tower_ruin()
    for ruin in (False, True):
        sand_hut(ruin)
        bas_hut(ruin)
        wood_hut(ruin)
        lime_hut(ruin)
        gran_hut(ruin)
        ice_hut(ruin)
    sand_wall_ruin()
    sand_gate_ruin()
    sand_wall_tower_ruin()
    bas_wall_ruin()
    bas_gate_ruin()
    bas_wall_tower_ruin()
    lime_wall_ruin()
    lime_gate_ruin()
    lime_wall_tower_ruin()
    gran_wall_ruin()
    gran_gate_ruin()
    gran_wall_tower_ruin()
    ice_wall_ruin()
    ice_gate_ruin()
    ice_wall_tower_ruin()
    for prefix, fn, deck in [("wood_", wood_wall_tower, WOOD_DECK), ("sandstone_", sand_wall_tower, 76), ("basalt_", bas_wall_tower, 76),
                             ("limestone_", lime_wall_tower, 76), ("granite_", gran_wall_tower, 76), ("ice_", ice_wall_tower, 76)]:
        for lvl in (1, 2, 3):
            suffix = "" if lvl == 1 else "_%d" % lvl
            wt = fn(level=lvl)
            wt.pts = fn(level=3).pts[:]
            wt.save(prefix + "wall_tower" + suffix, extra={"platform": deck + 2})
            wtf = fn(front=True, level=lvl)
            wtf.pts = wt.pts[:]
            wtf.save(prefix + "wall_tower_front" + suffix)
