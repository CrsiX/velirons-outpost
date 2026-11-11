#!/usr/bin/env python3
"""Generates all SVG art for Veliron's Outpost plus scripts/core/art_manifest.gd.

Everything is authored in 1x world units (an iso tile is 128x64) relative to an
anchor point (the tile centre on the ground for objects, the feet for units).
SVGs are written at 2x pixel size for crisp high-DPI rendering; the game draws
them at 0.5 scale. Run:  python3 tools/gen_art.py

The art itself is in tools/art/, by kind; this is the entry point.
"""
import os

from art.core import ART, CRIMSON, CRIMSON_D, MANIFEST, manifest, write_manifest
from art.buildings import (
    abbey, barracks, barracks_ruin, campaign_houses, church, city_houses, farm_field, farm_shed,
    graveyard, grove, guild_house, legion_camp, light_halo, light_stone, market, rubble, site,
    stall, throne_hall, town_halls, training_grounds, warehouse, warning_light, worker_camp,
)
from art.enemies import (
    corpse_crab, corpse_gargoyle, corpse_goblin, corpse_horse, corpse_leviathan, corpse_necromancer,
    corpse_octopus, corpse_orc, corpse_siren, corpse_skeleton, corpse_snake, corpse_spider_mother,
    corpse_thief, corpse_vampire, corpse_vulture, corpse_witch, corpse_wolf, corpse_wrathwood, crab,
    gargoyle, ghost, goblin, horse, leviathan, necromancer, octopus, octopus_arm, orc, rat, riders,
    siren, skeleton, slimes, snake, SNAKE_FRAMES, snake_slither, spell_bolt, spell_glow,
    spider_eggs, spider_mother, spiderling, thief, vampire, vampire_bat, vulture, vulture_landed,
    witch, wolf, wrathwood,
)
from art.icons import (
    advancement_icons, app_icon, campaign_icon, flags, icons, item_icons, relic_icons, title_icons,
)
from art.misc import arrow, biome_art, net_pin, sack, salvage, throwing_axe
from art.portraits import portraits, portraits_1011, portraits_67, portraits_89, portraits_away
from art.props import (
    beacon, boat, boat_upturned, city_rubble, corpse_fallen, driftwood, ferry_bell, fish_rack,
    grave_cross, grave_mound, gull, harbour_crates, mooring_post, net_rack, pier, relic_sword,
    tent_small, wreck,
)
from art.terrain import (
    mountain, tile_cobble, tile_desert, tile_forest, tile_grass, tile_road, tile_rock,
    tile_village_path,
)
from art.trees import tree_dead, tree_oak, tree_pine, tree_spruce
from art.units import (
    acolytes, archer, archmage, builder, caravan, crossbowman, druid, earth_elemental,
    eldest_priest_person, explorer, farmer, fire_elemental, fire_summoner, forester, gatherer,
    guild_master, herald, hero, legion_archer, legion_banner, legion_captain, legion_champion,
    legion_footman, legion_guard, legion_king, legion_marshal, mages, merchant, priest_person,
    princess, projectiles, shield_bearer, shield_bearer_branches, spatial_archmage, summoner,
    swiftbowman, thornling, trade_carts, trader,
)
from art.village import village_pieces_materials
from art.village.levels import fortifications
from art.village.stone import (
    gate, gate_ruin, hut, wall, wall_ruin, wall_tower, wall_tower_ruin, watchtower,
)


def main():
    os.makedirs(ART, exist_ok=True)
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    for i in range(3):
        tile_grass(i)
    tile_forest()
    tile_road()
    tile_desert(0)
    tile_desert(1)
    tile_rock()
    for i in range(4):
        mountain(i)
    tree_pine(0)
    tree_pine(1)
    tree_spruce()
    for i in range(3):
        tree_oak(i)
    tree_dead(0)
    tree_dead(1)
    hut()
    hut(ruin=True)
    for lvl in (1, 2, 3):
        wall(lvl)
        gate(lvl)
    wall_ruin()
    gate_ruin()
    wall_tower_ruin()
    rubble()
    # Tower levels 1-3 share one canvas so sprites line up when a tower levels up.
    for lvl in (1, 2, 3):
        suffix = "" if lvl == 1 else "_%d" % lvl
        wt = wall_tower(level=lvl)
        wt.pts = wall_tower(level=3).pts[:]
        wt.save("wall_tower" + suffix, extra={"platform": 78})
        wtf = wall_tower(front=True, level=lvl)
        wtf.pts = wt.pts[:]  # identical canvas so both layers line up
        wtf.save("wall_tower_front" + suffix)
        w = watchtower(level=lvl)
        w.pts = watchtower(level=3).pts[:]
        w.save("watchtower" + suffix, extra={"platform": 66})
        wf = watchtower(front=True, level=lvl)
        wf.pts = w.pts[:]
        wf.save("watchtower_front" + suffix)
    village_pieces_materials()
    fortifications()
    advancement_icons()
    item_icons()
    relic_icons()
    town_halls()
    tile_village_path()
    site()
    farm_field("field")
    farm_field("site")
    farm_shed()
    builder()
    farmer()
    explorer()
    archmage()
    archer()
    goblin()
    rat()
    slimes()
    spider_mother()
    corpse_spider_mother()
    spiderling()
    spider_eggs()
    wrathwood()
    corpse_wrathwood()
    gatherer()
    forester()
    worker_camp()
    ls = light_stone()
    ls.save("light_stone")
    lg = light_stone(glow_only=True)
    lg.pts = ls.pts[:]
    lg.save("light_stone_glow")
    light_halo()
    warning_light()
    corpse_goblin()
    hero()
    caravan()
    shield_bearer()
    shield_bearer_branches()
    crossbowman()
    swiftbowman()
    fire_summoner()
    fire_elemental()
    mages()
    acolytes()
    spatial_archmage()
    projectiles()
    for lv in (1, 2, 3):
        barracks(lv)
    training_grounds()
    skeleton()
    corpse_skeleton()
    summoner()
    earth_elemental()
    orc()
    witch()
    corpse_orc()
    corpse_witch()
    thief()
    gargoyle(0)
    gargoyle(1)
    necromancer()
    corpse_thief()
    corpse_gargoyle()
    corpse_necromancer()
    vampire()
    vampire_bat(0)
    vampire_bat(1)
    corpse_vampire()
    vulture(0)
    vulture(1)
    vulture_landed()
    corpse_vulture()
    ghost()
    crab()
    corpse_crab()
    leviathan()
    corpse_leviathan()
    siren()
    corpse_siren()
    octopus()
    corpse_octopus()
    octopus_arm()
    spell_bolt()
    spell_glow()
    arrow()
    throwing_axe()
    net_pin()
    sack()
    biome_art()
    icons()
    title_icons()
    flags()
    app_icon()
    tent_small()
    stall(1)
    stall(3)
    merchant()
    for lv in (1, 2, 3):
        market(lv)
    trader()
    trade_carts()
    salvage()
    barracks_ruin()
    warehouse()
    guild_house()
    guild_master()
    legion_footman()
    legion_captain("unit_legion_captain", "#b8bcc4")
    legion_captain("unit_legion_captain_lysa", CRIMSON, hair="#6a2a20")
    portraits()
    portraits_away()
    corpse_fallen("corpse_fallen", "#2f4a7a", "#243a62")
    corpse_fallen("corpse_fallen_2", CRIMSON, CRIMSON_D)
    graveyard()
    grave_mound()
    grave_cross()
    grove()
    druid()
    thornling()
    priest_person()
    eldest_priest_person()
    princess()
    campaign_houses()
    portraits_67()
    legion_archer()
    legion_guard()
    legion_banner()
    legion_champion()
    herald()
    legion_camp()
    legion_camp(True)
    abbey()
    abbey(True)
    church()
    pier()
    boat()
    boat(sail=True)
    harbour_crates()
    net_rack()
    relic_sword()
    ferry_bell()
    beacon()
    wreck()
    fish_rack()
    boat_upturned()
    mooring_post()
    driftwood()
    gull()
    portraits_89()
    legion_marshal()
    legion_king()
    for i in range(3):
        tile_cobble(i)
    city_houses()
    city_rubble()
    throne_hall()
    portraits_1011()
    campaign_icon()
    wolf()
    corpse_wolf()
    snake()
    for i in range(SNAKE_FRAMES):
        snake_slither(i)
    corpse_snake()
    horse()
    corpse_horse()
    riders()  # (after the riders' own sprites: it seats them)
    write_manifest()
    print("generated %d sprites" % len(manifest))


if __name__ == "__main__":
    main()
