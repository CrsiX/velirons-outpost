"""Icons: the UI's (icon_svg, icons, title_icons, campaign_icon, flags, app_icon), the
advancements' (ADV_ICONS), the items' (ITEM_ICONS) and the relics' (RELIC_ICONS)."""

import math
import os
import re

from .core import (
    ART, CRIMSON, CRIMSON_D, fmt, GLOW, GOLD, GOLD_D, INK, ROOT, STONE_D, STONE_L, STONE_R, STONE_T,
    WOOD, WOOD_D, WOOD_L,
)


def campaign_icon():
    """The title screen's Campaign button: a crimson banner on a pole with a gold tower."""
    icon_svg("icon_campaign", f'''
  <path d="M14 4 L14 62" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M14 4 L14 62" stroke="{WOOD_L}" stroke-width="3" stroke-linecap="round"/>
  <circle cx="14" cy="5" r="4" fill="{GOLD}" stroke="{INK}" stroke-width="2"/>
  <path d="M16 10 L56 10 L56 44 L36 36 L16 44Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M28 32 L28 20 L31 20 L31 23 L34 23 L34 20 L38 20 L38 23 L41 23 L41 20 L44 20 L44 32Z" fill="{GOLD}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M34.5 32 L34.5 28 Q36 26 37.5 28 L37.5 32Z" fill="{INK}"/>''')


def icon_svg(name, body):
    with open(os.path.join(ART, name + ".svg"), "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 64 64">\n%s\n</svg>\n' % body)


def title_icons():
    """The title screen's menu icons."""
    # Singleplayer: one person, profile-picture style in a round frame.
    icon_svg("icon_singleplayer", f'''
  <circle cx="32" cy="32" r="27" fill="#3a4a5a" stroke="{INK}" stroke-width="3.5"/>
  <path d="M13 51 Q14 36 32 36 Q50 36 51 51 Q42 59 32 59 Q22 59 13 51Z" fill="#566a3a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <circle cx="32" cy="23" r="10" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>''')
    # Multiplayer: a group of three.
    icon_svg("icon_multiplayer", f'''
  <circle cx="15" cy="22" r="7" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M3 48 Q3 31 15 31 Q27 31 27 48Z" fill="#7a6048" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="49" cy="22" r="7" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M37 48 Q37 31 49 31 Q61 31 61 48Z" fill="#7a2a1f" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="24" r="9" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M16 56 Q16 35 32 35 Q48 35 48 56Z" fill="#566a3a" stroke="{INK}" stroke-width="3.5"/>''')
    # Tutorial: a scholar's cap with a gold tassel.
    icon_svg("icon_tutorial", f'''
  <path d="M16 30 L16 44 Q32 54 48 44 L48 30Z" fill="#2a2a34" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M2 24 L32 11 L62 24 L32 37Z" fill="#3a3a48" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 24 L52 30 L52 46" fill="none" stroke="{GOLD}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="52" cy="49" r="4" fill="{GOLD}" stroke="{INK}" stroke-width="2"/>
  <circle cx="32" cy="24" r="3" fill="{GOLD}" stroke="{INK}" stroke-width="1.5"/>''')
    # Map editor: a folded parchment map with a road, a river and a quill over it.
    icon_svg("icon_map_editor", f'''
  <path d="M4 14 L22 8 L42 14 L60 8 L60 50 L42 56 L22 50 L4 56Z" fill="#e8d6a8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M22 8 L22 50 M42 14 L42 56" fill="none" stroke="#b89a60" stroke-width="2.5"/>
  <path d="M8 44 Q18 34 26 38 Q34 42 40 30" fill="none" stroke="#3f7fbf" stroke-width="4" stroke-linecap="round"/>
  <path d="M10 22 L18 26 L30 22 L38 28" fill="none" stroke="#a0704a" stroke-width="3" stroke-linecap="round" stroke-dasharray="4 3"/>
  <path d="M50 2 L62 14 L34 46 L26 50 L30 42Z" fill="#f4f0e6" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>
  <path d="M30 42 L34 46" fill="none" stroke="{INK}" stroke-width="3"/>
  <path d="M52 8 L38 24" fill="none" stroke="#b8b0a0" stroke-width="2"/>''')
    # Next scenario (a won scenario's main button): a rounded play arrow on a
    # crimson seal with a gold rim.
    icon_svg("icon_next", f'''
  <circle cx="32" cy="32" r="28" fill="{CRIMSON}" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="32" r="23" fill="none" stroke="{GOLD}" stroke-width="2.5"/>
  <path d="M26 20 L46 32 L26 44Z" fill="#5a1a14" stroke="#5a1a14" stroke-width="7" stroke-linejoin="round" transform="translate(1.5 2)"/>
  <path d="M26 20 L46 32 L26 44Z" fill="#efe3c8" stroke="#efe3c8" stroke-width="7" stroke-linejoin="round"/>''')
    # Exit: an open door with an arrow leading out.
    icon_svg("icon_exit", f'''
  <path d="M8 6 L36 6 L36 58 L8 58Z" fill="#4a3a2a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M8 6 L28 12 L28 62 L8 58Z" fill="#8a5a32" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <circle cx="23" cy="36" r="2.5" fill="{GOLD}" stroke="{INK}" stroke-width="1.5"/>
  <path d="M34 32 L54 32 M46 23 L56 32 L46 41" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M34 32 L54 32 M46 23 L56 32 L46 41" fill="none" stroke="#e05a4a" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>''')


def icons():
    # XP: three sparkling green orbs.
    # XP: a light-blue star with a sparkle.
    icon_svg("icon_xp", f"""
  <path d="M32 5 L39.5 23 L59 24.5 L44 37 L48.8 56 L32 45.5 L15.2 56 L20 37 L5 24.5 L24.5 23 Z" fill="#7fd0ff" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 13 L37 25 L50 26 L40 34.5" fill="none" stroke="#e4f6ff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M55 5 L56.5 9.5 L61 11 L56.5 12.5 L55 17 L53.5 12.5 L49 11 L53.5 9.5Z" fill="#ffffff" stroke="{INK}" stroke-width="1.2"/>""")
    # The hero's level-up: three green chevrons rising, and a soft glow behind them.
    icon_svg("levelup_chevrons", f"""
  <path d="M10 58 L32 42 L54 58 L54 48 L32 32 L10 48 Z" fill="#3f9a3a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M10 42 L32 26 L54 42 L54 32 L32 16 L10 32 Z" fill="#5cc24a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M14 22 L32 8 L50 22 L50 15 L32 2 L14 15 Z" fill="#9aee6e" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>""")
    icon_svg("levelup_glow", """
  <defs><radialGradient id="g"><stop offset="0" stop-color="#eaffb0" stop-opacity="0.95"/><stop offset="0.45" stop-color="#8cf06a" stop-opacity="0.45"/><stop offset="1" stop-color="#4ac04a" stop-opacity="0"/></radialGradient></defs>
  <circle cx="32" cy="32" r="32" fill="url(#g)"/>""")

    # Hero modes (the icon row in her panel).
    icon_svg("mode_defend", f"""
  <path d="M32 5 L54 12 L54 30 C54 44 44 54 32 59 C20 54 10 44 10 30 L10 12 Z" fill="#6a7fa0" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 11 L48 16 L48 30 C48 41 41 49 32 53 Z" fill="#8ea3c4"/>
  <path d="M32 5 L32 59 M10 28 L54 28" stroke="{GOLD}" stroke-width="4"/>
  <path d="M32 5 L54 12 L54 30 C54 44 44 54 32 59 C20 54 10 44 10 30 L10 12 Z" fill="none" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>""")
    icon_svg("mode_build", f"""
  <g transform="rotate(-45 32 32)">
    <path d="M25 4 L39 4 L39 44 L25 44 Z" fill="#c9ced6" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>
    <path d="M25 8 L21 10 L25 13 L21 16 L25 19 L21 22 L25 25 L21 28 L25 31 L21 34 L25 37 L21 40 L25 43" fill="none" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
    <rect x="23" y="44" width="18" height="15" rx="4" fill="{WOOD_L}" stroke="{INK}" stroke-width="3"/>
    <rect x="28" y="48" width="8" height="7" rx="2" fill="{WOOD_D}"/>
  </g>
  <g transform="rotate(45 32 32) translate(32 32) scale(0.86) translate(-32 -32)">
    <rect x="28" y="16" width="8" height="46" rx="3" fill="#b08a58" stroke="{INK}" stroke-width="3.5"/>
    <rect x="12" y="4" width="40" height="15" rx="3" fill="#8a929c" stroke="{INK}" stroke-width="4"/>
    <rect x="15" y="7" width="16" height="4" rx="2" fill="#b8c0ca"/>
  </g>""")
    icon_svg("mode_explore", f"""
  <circle cx="32" cy="32" r="25" fill="#3a78c8" stroke="{INK}" stroke-width="3.5"/>
  <path d="M18 16 Q26 12 30 18 Q34 24 27 28 Q22 32 24 38 Q26 44 20 46 Q12 40 11 30 Q12 20 18 16Z" fill="#5fae4a" stroke="{INK}" stroke-width="2"/>
  <path d="M38 12 Q48 14 53 24 Q55 34 50 42 Q44 46 40 40 Q37 34 42 30 Q46 26 40 22 Q35 18 38 12Z" fill="#5fae4a" stroke="{INK}" stroke-width="2"/>
  <path d="M34 48 Q40 46 44 50 Q40 55 34 55Z" fill="#5fae4a" stroke="{INK}" stroke-width="2"/>
  <path d="M15 22 Q18 15 26 12" fill="none" stroke="#a8d4ff" stroke-width="3" stroke-linecap="round"/>
  <circle cx="32" cy="32" r="25" fill="none" stroke="{INK}" stroke-width="3.5"/>""")
    icon_svg("mode_gather", f"""
  <path d="M8 26 L46 26 L40 44 L14 44 Z" fill="{WOOD_L}" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M46 26 L60 18" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>
  <path d="M18 44 L16 54 M38 44 L40 54" stroke="{INK}" stroke-width="3"/>
  <circle cx="20" cy="52" r="7" fill="{WOOD_D}" stroke="{INK}" stroke-width="3"/>
  <path d="M14 22 L30 14" stroke="#ece4cf" stroke-width="5" stroke-linecap="round"/>
  <path d="M14 22 L30 14" stroke="{INK}" stroke-width="1" opacity="0.4"/>
  <circle cx="36" cy="17" r="7" fill="#ece4cf" stroke="{INK}" stroke-width="2.5"/>
  <circle cx="34" cy="16" r="1.8" fill="{INK}"/>
  <circle cx="39" cy="16" r="1.8" fill="{INK}"/>""")
    icon_svg("mode_train", f"""
  <path d="M32 30 L32 60" stroke="{WOOD_D}" stroke-width="5" stroke-linecap="round"/>
  <path d="M8 30 L56 30" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M8 30 L56 30" stroke="{WOOD_L}" stroke-width="4" stroke-linecap="round"/>
  <path d="M20 28 L44 28 L42 50 L22 50 Z" fill="#d8b860" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M24 36 L40 36 M23 43 L41 43" stroke="#a08030" stroke-width="2.5"/>
  <circle cx="32" cy="16" r="10" fill="#d8b860" stroke="{INK}" stroke-width="3.5"/>
  <path d="M27 13 L31 17 M31 13 L27 17 M33 13 L37 17 M37 13 L33 17" stroke="{INK}" stroke-width="1.8"/>
  <path d="M40 38 L54 46" stroke="#b0b4bc" stroke-width="3" stroke-linecap="round"/>""")
    icon_svg("mode_rest", f"""
  <path d="M6 44 L16 44 L6 56 L16 56" fill="none" stroke="{INK}" stroke-width="7" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M6 44 L16 44 L6 56 L16 56" fill="none" stroke="#ffffff" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M22 26 L36 26 L22 42 L36 42" fill="none" stroke="{INK}" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M22 26 L36 26 L22 42 L36 42" fill="none" stroke="#ffffff" stroke-width="4.5" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M40 6 L58 6 L40 26 L58 26" fill="none" stroke="{INK}" stroke-width="9" stroke-linejoin="round" stroke-linecap="round"/>
  <path d="M40 6 L58 6 L40 26 L58 26" fill="none" stroke="#ffffff" stroke-width="5.5" stroke-linejoin="round" stroke-linecap="round"/>""")
    icon_svg("mode_support", f"""
  <path d="M1 50 L16 26 L32 36 L16 61 Z" fill="#6a7fa0" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M63 50 L48 26 L32 36 L48 61 Z" fill="#a0503a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <ellipse cx="32" cy="30" rx="18" ry="12" fill="#e8a878" stroke="{INK}" stroke-width="3.5"/>
  <path d="M24 20 L24 28 M30 19 L30 28 M36 19 L36 28 M42 21 L42 28" stroke="{INK}" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M16 32 Q24 40 34 36" fill="none" stroke="{INK}" stroke-width="2.5" stroke-linecap="round"/>""")
    # HP: a plain bold red heart with a highlight.
    icon_svg("icon_hp", f"""
  <path d="M32 56 C20 46 6 36 6 22 C6 13 13 7 21 7 C26 7 30 10 32 14 C34 10 38 7 43 7 C51 7 58 13 58 22 C58 36 44 46 32 56Z" fill="#d8342c" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 50 C24 43 14 35 13 25" fill="none" stroke="#a82420" stroke-width="3" stroke-linecap="round"/>
  <path d="M14 20 Q15 13 22 13" fill="none" stroke="#ff9a8a" stroke-width="4" stroke-linecap="round"/>""")
    # Army HP: two red hearts, one behind the other (the statistics' "Army HP %";
    # the hero's HP is the single heart).
    icon_svg("icon_hp_army", f"""
  <g transform="translate(24 2) scale(0.62)">
    <path d="M32 56 C20 46 6 36 6 22 C6 13 13 7 21 7 C26 7 30 10 32 14 C34 10 38 7 43 7 C51 7 58 13 58 22 C58 36 44 46 32 56Z" fill="#9c2420" stroke="{INK}" stroke-width="5.5" stroke-linejoin="round"/>
  </g>
  <g transform="translate(1 17) scale(0.72)">
    <path d="M32 56 C20 46 6 36 6 22 C6 13 13 7 21 7 C26 7 30 10 32 14 C34 10 38 7 43 7 C51 7 58 13 58 22 C58 36 44 46 32 56Z" fill="#d8342c" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
    <path d="M14 20 Q15 13 22 13" fill="none" stroke="#ff9a8a" stroke-width="5" stroke-linecap="round"/>
  </g>""")
    icon_svg("icon_gold", f'''
  <circle cx="32" cy="35" r="24" fill="{GOLD_D}" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="31" r="24" fill="{GOLD}" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="32" cy="31" r="16" fill="none" stroke="{GOLD_D}" stroke-width="3"/>
  <path d="M32 19 L36 29 L46 31 L36 33 L32 43 L28 33 L18 31 L28 29Z" fill="{GOLD_D}"/>
  <path d="M17 21 Q22 12 32 11" fill="none" stroke="#f3dc93" stroke-width="3.5" stroke-linecap="round"/>''')
    icon_svg("icon_food", f'''
  <path d="M8 40 Q6 22 24 18 Q32 12 42 16 Q58 20 56 38 Q56 50 32 50 Q10 50 8 40Z" fill="#b07a3a" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M10 38 Q30 44 54 36" fill="none" stroke="#8a5a26" stroke-width="3"/>
  <path d="M20 24 L26 34 M31 20 L36 31 M42 21 L46 31" stroke="#e0b070" stroke-width="3.5" stroke-linecap="round"/>''')
    icon_svg("icon_materials", f'''
  <rect x="6" y="28" width="38" height="14" rx="7" fill="{WOOD}" stroke="{INK}" stroke-width="3.5"/>
  <ellipse cx="41" cy="35" rx="5" ry="7" fill="#b08a58" stroke="{INK}" stroke-width="3"/>
  <circle cx="41" cy="35" r="2" fill="{WOOD_D}"/>
  <rect x="10" y="16" width="34" height="13" rx="6.5" fill="{WOOD_L}" stroke="{INK}" stroke-width="3.5"/>
  <ellipse cx="41" cy="22.5" rx="5" ry="6.5" fill="#c49a64" stroke="{INK}" stroke-width="3"/>
  <path d="M34 58 L30 44 L42 38 L58 42 L60 56Z" fill="{STONE_L}" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M42 38 L46 50 L60 56 M46 50 L34 58" fill="none" stroke="{STONE_D}" stroke-width="2.5"/>''')
    icon_svg("icon_population", f'''
  <circle cx="22" cy="20" r="8" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M8 50 Q8 30 22 30 Q36 30 36 50Z" fill="#7a6048" stroke="{INK}" stroke-width="3.5"/>
  <circle cx="42" cy="22" r="8" fill="#d8b08c" stroke="{INK}" stroke-width="3.5"/>
  <path d="M28 54 Q28 32 42 32 Q56 32 56 54Z" fill="#566a3a" stroke="{INK}" stroke-width="3.5"/>''')
    icon_svg("icon_village", f'''
  <path d="M8 32 L32 12 L56 32Z" fill="#5b4a2e" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <rect x="14" y="32" width="36" height="22" fill="#8c7b62" stroke="{INK}" stroke-width="3.5"/>
  <rect x="27" y="38" width="10" height="16" fill="#2b1e14"/>
  <rect x="40" y="37" width="6" height="6" fill="{GLOW}"/>''')
    icon_svg("icon_army", f'''
  <path d="M18 8 Q48 32 18 56" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M18 8 Q48 32 18 56" fill="none" stroke="#8a5a30" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M18 8 L18 56" stroke="#d8d0b8" stroke-width="2"/>
  <path d="M8 32 L50 32" stroke="{INK}" stroke-width="4"/>
  <path d="M48 26 L58 32 L48 38Z" fill="#9a9a9a" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M6 27 L12 32 L6 37" fill="{CRIMSON}" stroke="{INK}" stroke-width="2"/>''')
    icon_svg("icon_enemies", f'''
  <path d="M10 8 L40 38 L46 32 L16 2Z" fill="#9a9a9a" stroke="{INK}" stroke-width="3" stroke-linejoin="round" transform="translate(2 8)"/>
  <path d="M54 8 L24 38 L18 32 L48 2Z" fill="#8a8a8a" stroke="{INK}" stroke-width="3" stroke-linejoin="round" transform="translate(-2 8)"/>
  <path d="M14 42 L24 52 M50 42 L40 52" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M14 42 L24 52 M50 42 L40 52" stroke="{WOOD_L}" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M10 46 L20 36 M54 46 L44 36" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>
  <circle cx="32" cy="46" r="7" fill="{CRIMSON}" stroke="{INK}" stroke-width="3"/>''')
    icon_svg("icon_fullscreen", f'''
  <path d="M8 24 L8 8 L24 8 M40 8 L56 8 L56 24 M56 40 L56 56 L40 56 M24 56 L8 56 L8 40" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M8 24 L8 8 L24 8 M40 8 L56 8 L56 24 M56 40 L56 56 L40 56 M24 56 L8 56 L8 40" fill="none" stroke="#efe3c8" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_pause", f'''
  <rect x="15" y="12" width="12" height="40" rx="3" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>
  <rect x="37" y="12" width="12" height="40" rx="3" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>''')
    icon_svg("icon_play", f'''
  <path d="M18 12 L50 32 L18 52Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''')
    icon_svg("icon_check", f'''
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="#7fd36b" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>''')
    # Yes / no on coloured buttons (Build, Cancel, Ready): light strokes with an
    # ink outline, both spanning 12..52 so either icon sits the same in its button.
    # (Instead of the ✓ / ✕ characters, which mobile browsers' fonts lack.)
    icon_svg("icon_yes", f'''
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 34 L26 48 L52 16" fill="none" stroke="#efe3c8" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_no", f'''
  <path d="M14 14 L50 50 M50 14 L14 50" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round"/>
  <path d="M14 14 L50 50 M50 14 L14 50" fill="none" stroke="#efe3c8" stroke-width="7" stroke-linecap="round"/>''')
    icon_svg("icon_book", f'''
  <path d="M4 19 L4 54 C14 51 24 51 32 57 C40 51 50 51 60 54 L60 19 Z" fill="#7a2a1f" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 18 C24 11 14 11 7 14 L7 49 C15 46 24 47 32 53 Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 18 C40 11 50 11 57 14 L57 49 C49 46 40 47 32 53 Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M12 22 C17 20 22 20 27 23 M12 30 C17 28 22 28 27 31 M12 38 C17 36 22 36 27 39 M37 23 C42 20 47 20 52 22 M37 31 C42 28 47 28 52 30 M37 39 C42 36 47 36 52 38" fill="none" stroke="#a8997c" stroke-width="2.2" stroke-linecap="round"/>''')
    # Statistics: four bars of a bar chart on a base line.
    icon_svg("icon_stats", f'''
  <path d="M6 56 L58 56" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <rect x="8" y="36" width="10" height="18" rx="1.5" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>
  <rect x="21" y="22" width="10" height="32" rx="1.5" fill="{GOLD}" stroke="{INK}" stroke-width="3.5"/>
  <rect x="34" y="30" width="10" height="24" rx="1.5" fill="#efe3c8" stroke="{INK}" stroke-width="3.5"/>
  <rect x="47" y="10" width="10" height="44" rx="1.5" fill="{CRIMSON}" stroke="{INK}" stroke-width="3.5"/>''')
    # Map (the tactical map, M): a folded parchment map with a dotted route and a red cross.
    icon_svg("icon_map", f'''
  <path d="M6 14 L22 8 L42 14 L58 8 L58 50 L42 56 L22 50 L6 56Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M22 8 L22 50 M42 14 L42 56" stroke="#a8997c" stroke-width="2.5"/>
  <path d="M12 44 Q20 30 30 34 Q40 38 46 24" fill="none" stroke="{CRIMSON}" stroke-width="3" stroke-dasharray="3 4" stroke-linecap="round"/>
  <path d="M44 18 L52 26 M52 18 L44 26" stroke="{CRIMSON}" stroke-width="4" stroke-linecap="round"/>''')
    # Range rings (the tactical map's toggle): a tower's dot in two rings.
    icon_svg("icon_range", f'''
  <ellipse cx="32" cy="34" rx="28" ry="20" fill="none" stroke="{INK}" stroke-width="6"/>
  <ellipse cx="32" cy="34" rx="28" ry="20" fill="none" stroke="{GOLD}" stroke-width="3"/>
  <ellipse cx="32" cy="34" rx="15" ry="10.5" fill="none" stroke="{INK}" stroke-width="5"/>
  <ellipse cx="32" cy="34" rx="15" ry="10.5" fill="none" stroke="#efe3c8" stroke-width="2.5"/>
  <rect x="27" y="14" width="10" height="20" fill="#8c7b62" stroke="{INK}" stroke-width="3"/>
  <path d="M25 14 L39 14 L39 9 L35 9 L35 12 L32 12 L32 9 L29 9 L29 12 L25 12Z" fill="#8c7b62" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>''')
    icon_svg("icon_fast", f'''
  <path d="M6 14 L32 32 L6 50Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M32 14 L58 32 L32 50Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''')
    icon_svg("icon_hero", f'''
  <path d="M10 54 L44 20 M54 54 L20 20" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>
  <path d="M10 54 L44 20 M54 54 L20 20" stroke="#d0d4dc" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M16 30 Q15 10 32 10 Q49 10 48 30 L42 32 L42 26 L22 26 L22 32 Z" fill="#9aa4b2" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M30 10 Q28 -2 44 2 Q36 6 36 10 Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="2.5"/>
  <path d="M32 11 L32 25" stroke="#6a7482" stroke-width="2.5"/>
  <path d="M12 50 L20 42 M52 50 L44 42" stroke="{GOLD}" stroke-width="4" stroke-linecap="round"/>''')
    icon_svg("icon_fastest", f'''
  <path d="M2 16 L20 32 L2 48Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M22 16 L40 32 L22 48Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>
  <path d="M42 16 L60 32 L42 48Z" fill="#efe3c8" stroke="{INK}" stroke-width="3.5" stroke-linejoin="round"/>''')
    icon_svg("icon_collapse", f'''
  <path d="M24 12 L44 32 L24 52" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_expand", f'''
  <path d="M40 12 L20 32 L40 52" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')
    # Settings: a gear with 6 teeth.
    teeth = 6
    pts = []
    for i in range(teeth * 4):
        ang = math.pi * 2 * i / (teeth * 4) - math.pi / 2
        r = 27 if i % 4 in (1, 2) else 19
        pts.append((32 + r * math.cos(ang), 32 + r * math.sin(ang)))
    gear = "M" + " L".join("%.1f %.1f" % p for p in pts) + " Z"
    icon_svg("icon_settings", f'''
  <path d="{gear} M32 23 A9 9 0 1 0 32.01 23 Z" fill="#c9ccd4" fill-rule="evenodd" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>
  <circle cx="32" cy="32" r="9" fill="none" stroke="#8a8f99" stroke-width="2"/>''')
    icon_svg("icon_sheet_up", f'''
  <path d="M12 40 L32 20 L52 40" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')
    icon_svg("icon_sheet_down", f'''
  <path d="M12 24 L32 44 L52 24" fill="none" stroke="#efe3c8" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>''')
    # Undo / redo (the map editor): the usual curved arrows, back to the left / on to the right.
    for name, flip in (("icon_undo", False), ("icon_redo", True)):
        tr = ' transform="translate(64 0) scale(-1 1)"' if flip else ''
        icon_svg(name, f'''
  <g{tr}>
  <path d="M20 24 H38 A14 14 0 0 1 38 52 H24" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M6 24 L22 10 L22 38 Z" fill="{INK}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>
  <path d="M20 24 H38 A14 14 0 0 1 38 52 H24" fill="none" stroke="#efe3c8" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M6 24 L22 10 L22 38 Z" fill="#efe3c8" stroke="#efe3c8" stroke-width="1.5" stroke-linejoin="round"/>
  </g>''')


def flags():
    """Language flags for the settings dialog (landscape 60x30 viewBox)."""
    with open(os.path.join(ART, "flag_gb.svg"), "w") as f:
        f.write('''<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60" viewBox="0 0 60 30">
<clipPath id="s"><path d="M0,0 v30 h60 v-30 z"/></clipPath>
<clipPath id="t"><path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z"/></clipPath>
<g clip-path="url(#s)">
<path d="M0,0 v30 h60 v-30 z" fill="#012169"/>
<path d="M0,0 L60,30 M60,0 L0,30" stroke="#fff" stroke-width="6"/>
<path d="M0,0 L60,30 M60,0 L0,30" clip-path="url(#t)" stroke="#C8102E" stroke-width="4"/>
<path d="M30,0 v30 M0,15 h60" stroke="#fff" stroke-width="10"/>
<path d="M30,0 v30 M0,15 h60" stroke="#C8102E" stroke-width="6"/>
</g>
<rect x="0.5" y="0.5" width="59" height="29" fill="none" stroke="#15110d" stroke-width="1"/>
</svg>
''')


def app_icon():
    with open(os.path.join(ROOT, "icon.svg"), "w") as f:
        f.write(f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1c2430"/><stop offset="1" stop-color="#3a4a3a"/></linearGradient></defs>
  <rect x="8" y="8" width="240" height="240" rx="44" fill="url(#sky)" stroke="{INK}" stroke-width="8"/>
  <circle cx="186" cy="64" r="22" fill="#e8dcb0" opacity="0.9"/>
  <path d="M12 200 L40 150 L62 190 L86 140 L110 200Z M150 200 L178 146 L200 186 L222 150 L244 200Z" fill="#1a2c20"/>
  <path d="M12 204 Q128 180 244 204 L244 210 Q244 244 204 244 L52 244 Q12 244 12 210Z" fill="#314a24"/>
  <path d="M92 96 L164 96 L158 214 L98 214Z" fill="{STONE_L}" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>
  <path d="M128 96 L164 96 L158 214 L128 214Z" fill="{STONE_R}"/>
  <path d="M84 84 L172 84 L172 100 L84 100Z" fill="{STONE_T}" stroke="{INK}" stroke-width="6"/>
  <path d="M84 66 h18 v18 h-18z M119 66 h18 v18 h-18z M154 66 h18 v18 h-18z" fill="{STONE_T}" stroke="{INK}" stroke-width="6"/>
  <path d="M116 214 L116 180 Q128 166 140 180 L140 214Z" fill="#2b1e14" stroke="{INK}" stroke-width="5"/>
  <rect x="121" y="124" width="14" height="22" rx="7" fill="{GLOW}" stroke="{INK}" stroke-width="4"/>
  <path d="M128 66 L128 26" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M131 28 L170 36 L158 46 L170 56 L131 62Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>
  <circle cx="146" cy="45" r="5" fill="{GOLD}"/>
</svg>
''')


# ------------------------------------------------------------- advancement icons

# The advancements' icons (Config.ADVANCEMENTS; "adv_<id>"): one badge for all, a dark
# disc with an iron ring (tier 1) or a gold one (tier 2), and the advancement's sign in it.
ADV_RING = {1: "#9aa0a8", 2: "#e0b84a"}


def _adv_badge(tier, symbol):
    return f'''
  <circle cx="32" cy="32" r="29.5" fill="#2a2420" stroke="{INK}" stroke-width="3"/>
  <circle cx="32" cy="32" r="26" fill="none" stroke="{ADV_RING[tier]}" stroke-width="3"/>
  <circle cx="32" cy="32" r="23.5" fill="#3a3028"/>
{symbol}'''


def _numeral(text, y=55):
    """A small Roman numeral (I and V strokes, no font) on a ribbon at the badge's foot."""
    widths = {"I": 2.0, "V": 6.0}
    gap = 2.5
    total = sum(widths[c] for c in text) + gap * (len(text) - 1)
    w = total + 10
    out = f'''
  <path d="M{32 - w / 2} {y - 7} L{32 + w / 2} {y - 7} L{32 + w / 2 + 3} {y - 2.5} L{32 + w / 2} {y + 2} L{32 - w / 2} {y + 2} L{32 - w / 2 - 3} {y - 2.5}Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>'''
    x = 32 - total / 2
    for c in text:
        if c == "I":
            out += f'''
  <path d="M{x + 1} {y - 5} L{x + 1} {y}" stroke="{GOLD}" stroke-width="2" stroke-linecap="round"/>'''
        else:
            out += f'''
  <path d="M{x} {y - 5} L{x + 3} {y} L{x + 6} {y - 5}" fill="none" stroke="{GOLD}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>'''
        x += widths[c] + gap
    return out


def _battlement(fill_top, fill_face):
    return f'''
  <path d="M14 46 L14 24 L19 24 L19 29 L24 29 L24 24 L29 24 L29 29 L35 29 L35 24 L40 24 L40 29 L45 29 L45 24 L50 24 L50 46Z" fill="{fill_face}" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M14 34 L50 34 M14 40 L50 40 M24 29 L24 34 M35 29 L35 34 M20 34 L20 40 M32 34 L32 40 M44 34 L44 40 M26 40 L26 46 M38 40 L38 46" stroke="{STONE_D}" stroke-width="1.6"/>
  <path d="M28 46 L28 39 Q32 35 36 39 L36 46Z" fill="#1a1612" stroke="{INK}" stroke-width="1.8"/>
  <path d="M14 24 L19 24 M24 24 L29 24 M35 24 L40 24 M45 24 L50 24" stroke="{fill_top}" stroke-width="2"/>'''


def _target(inner="#d8342c"):
    return f'''
  <circle cx="32" cy="32" r="16" fill="#efe3c8" stroke="{INK}" stroke-width="2.5"/>
  <circle cx="32" cy="32" r="10.5" fill="{inner}" stroke="{INK}" stroke-width="2"/>
  <circle cx="32" cy="32" r="5" fill="#efe3c8" stroke="{INK}" stroke-width="1.6"/>'''


def _chevrons(n):
    out = ""
    for k in range(n):
        y = 40 - k * 9
        out += f'''
  <path d="M18 {y + 8} L32 {y - 2} L46 {y + 8} L46 {y + 2} L32 {y - 8} L18 {y + 2}Z" fill="#5cc24a" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>'''
    return out


def _price_tag(x, y):
    return f'''
  <g transform="translate({x} {y}) rotate(-25)">
    <path d="M-9 -6 L5 -6 L11 0 L5 6 L-9 6Z" fill="{GOLD}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
    <circle cx="5" cy="0" r="1.6" fill="{INK}"/>
    <path d="M-6 0 L1 0" stroke="#8a5a26" stroke-width="2.2" stroke-linecap="round"/>
  </g>'''


def _cart(x=0, y=0):
    """A small open trade cart (crates on a wooden bed, one wheel) for the market's advancements."""
    return f'''
  <g transform="translate({x} {y})">
    <rect x="14" y="22" width="10" height="9" fill="#b08a58" stroke="{INK}" stroke-width="2"/>
    <rect x="25" y="20" width="9" height="11" fill="#c8a46a" stroke="{INK}" stroke-width="2"/>
    <path d="M10 31 L42 31 L40 37 L12 37Z" fill="{WOOD_L}" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
    <path d="M42 33 L50 30" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>
    <circle cx="24" cy="40" r="6" fill="#6a4a2a" stroke="{INK}" stroke-width="2.2"/>
    <path d="M24 34 L24 46 M18 40 L30 40" stroke="#b08a58" stroke-width="1.5"/>
  </g>'''


def _plus(x, y):
    return f'''
  <path d="M{x - 6} {y} L{x + 6} {y} M{x} {y - 6} L{x} {y + 6}" stroke="{INK}" stroke-width="5.5" stroke-linecap="round"/>
  <path d="M{x - 6} {y} L{x + 6} {y} M{x} {y - 6} L{x} {y + 6}" stroke="#5cc24a" stroke-width="3" stroke-linecap="round"/>'''

ADV_ICONS = {
    "fortifications_4": (1, _battlement(STONE_T, STONE_L) + _numeral("IV")),
    "fortifications_5": (2, _battlement(GOLD, "#8f8a80") + f'''
  <path d="M14 24 L19 24 M24 24 L29 24 M35 24 L40 24 M45 24 L50 24" stroke="{GOLD}" stroke-width="2.5"/>''' + _numeral("V")),
    "better_targeting": (1, _target() + f'''
  <path d="M50 14 L35 29" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M50 14 L35 29" stroke="{WOOD_L}" stroke-width="2.6" stroke-linecap="round"/>
  <path d="M47 11 L54 11 L53 18 M44 14 L51 14 L50 21" fill="none" stroke="#e8e0cc" stroke-width="2" stroke-linecap="round"/>
  <path d="M38 23 L33 31 L41 26Z" fill="#9a9a9a" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>'''),
    "manual_targeting": (1, _target("#3f7fbf") + f'''
  <circle cx="44" cy="44" r="9" fill="#8a929c" stroke="{INK}" stroke-width="2.5"/>
  <path d="M44 44 L44 36.5" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>
  <path d="M37 47 L40 46 M44 51.5 L44 49 M51 47 L48 46" stroke="{INK}" stroke-width="1.6"/>'''),
    "faster_attacks": (1, f'''
  <path d="M14 44 L44 20" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M14 44 L44 20" stroke="{WOOD_L}" stroke-width="3" stroke-linecap="round"/>
  <path d="M40 16 L52 13 L49 25Z" fill="#c9ced6" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M12 40 L8 46 L16 47 M17 44 L13 50 L21 51" fill="none" stroke="#e8e0cc" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M16 22 L28 22 M12 29 L24 29 M24 50 L38 50" stroke="#ffd27a" stroke-width="2.6" stroke-linecap="round"/>'''),
    "quick_feet": (1, f'''
  <path d="M22 16 L34 16 L34 36 L46 42 Q50 44 49 49 L20 49 L20 40Z" fill="#7a5a38" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M20 44 L49 44" stroke="#5a3e26" stroke-width="2"/>
  <path d="M34 20 Q46 12 54 16 Q48 18 52 22 Q44 22 47 26 Q40 26 34 30Z" fill="#efe3c8" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M8 30 L16 30 M6 37 L16 37 M10 44 L16 44" stroke="#ffd27a" stroke-width="2.4" stroke-linecap="round"/>'''),
    "drill_1": (1, _chevrons(1) + _numeral("I")),
    "drill_2": (2, _chevrons(2) + _numeral("II")),
    "skilled_looting": (1, f'''
  <path d="M22 26 Q14 34 16 44 Q18 52 32 52 Q46 52 48 44 Q50 34 42 26Z" fill="#b89a60" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M22 26 Q32 21 42 26" fill="none" stroke="#6a5230" stroke-width="2.4"/>
  <path d="M24 26 L26 20 L38 20 L40 26" fill="#8a6c34" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="32" cy="16" r="6" fill="{GOLD}" stroke="{INK}" stroke-width="2"/>
  <circle cx="24" cy="13" r="4.5" fill="{GOLD}" stroke="{INK}" stroke-width="1.8"/>
  <circle cx="41" cy="12" r="4.5" fill="{GOLD}" stroke="{INK}" stroke-width="1.8"/>
  <path d="M28 40 L36 40 M32 36 L32 44" stroke="{GOLD_D}" stroke-width="2.6" stroke-linecap="round"/>'''),
    "shared_vision": (1, f'''
  <path d="M8 32 Q32 10 56 32 Q32 54 8 32Z" fill="#efe3c8" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <circle cx="32" cy="32" r="9" fill="#3f7fbf" stroke="{INK}" stroke-width="2.2"/>
  <circle cx="32" cy="32" r="4" fill="{INK}"/>
  <circle cx="29" cy="29" r="1.8" fill="#ffffff"/>
  <path d="M12 47 Q20 40 28 47 M36 47 Q44 40 52 47" fill="none" stroke="#5fbf5a" stroke-width="2.6" stroke-linecap="round"/>'''),
    "vital_points": (1, f'''
  <path d="M40 14 L48 6 L50 8 L42 16Z" fill="{WOOD_L}" stroke="{INK}" stroke-width="2"/>
  <path d="M38 12 L46 20" stroke="{INK}" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M42 16 L20 38 L17 44 L23 41 L45 19Z" fill="#c9ced6" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M21 41 L18 38 L12 40 L10 34 L16 32 L14 26 L20 28 L22 22 L26 28 L32 26 L28 32" fill="#d8342c" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round" transform="translate(-4 10)"/>
  <circle cx="14" cy="42" r="3.5" fill="#ffd27a"/>'''),
    "more_damage": (2, f'''
  <path d="M16 46 L42 20 L48 14 L50 16 L44 22 L18 48Z" fill="#c9ced6" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M48 46 L22 20 L16 14 L14 16 L20 22 L46 48Z" fill="#b8bec8" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M12 42 L22 52 M52 42 L42 52" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M12 42 L22 52 M52 42 L42 52" stroke="{GOLD}" stroke-width="2.6" stroke-linecap="round"/>
  <path d="M32 8 L35 15 L42 16 L36 20 L38 27 L32 23 L26 27 L28 20 L22 16 L29 15Z" fill="#ffd27a" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>'''),
    "master_builders": (2, f'''
  <g transform="rotate(-40 32 34)">
    <rect x="29" y="22" width="6" height="30" rx="2" fill="#b08a58" stroke="{INK}" stroke-width="2.5"/>
    <rect x="18" y="14" width="28" height="11" rx="2.5" fill="#8a929c" stroke="{INK}" stroke-width="2.8"/>
    <rect x="20" y="16" width="11" height="3" rx="1.5" fill="#b8c0ca"/>
  </g>
  <path d="M46 8 L48 13 L53 13 L49 16 L51 21 L46 18 L41 21 L43 16 L39 13 L44 13Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.5" stroke-linejoin="round"/>'''),
    "cheaper_repairs": (2, f'''
  <path d="M12 46 L12 36 L30 36 L30 46Z M30 46 L30 36 L50 36 L50 46Z M20 36 L20 26 L40 26 L40 36Z" fill="{STONE_L}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M20 41 L22 41 M40 41 L42 41" stroke="{STONE_D}" stroke-width="2"/>''' + _price_tag(44, 18)),
    "cheaper_specialising": (2, f'''
  <path d="M18 46 L32 34 L46 46 L46 40 L32 28 L18 40Z" fill="#5cc24a" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M32 10 L35 18 L43 19 L37 24 L39 32 L32 28 L25 32 L27 24 L21 19 L29 18Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>''' + _price_tag(46, 18)),
    "cheaper_recruits": (2, f'''
  <path d="M18 40 Q18 18 32 18 Q46 18 46 40Z" fill="#8a929c" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M14 40 L50 40 L48 45 L16 45Z" fill="#6a727c" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M32 18 L32 40" stroke="#5a626c" stroke-width="2.4"/>
  <path d="M24 28 L28 28 L28 34 M36 28 L40 28" stroke="{INK}" stroke-width="2"/>''' + _price_tag(46, 18)),
    "caravan_rights": (1, f'''
  <path d="M30 10 L46 10 Q49 10 49 13 L49 20 L30 20 Q33 15 30 10Z" fill="#efe3c8" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <circle cx="44" cy="20" r="3.5" fill="#c83a30" stroke="{INK}" stroke-width="1.5"/>''' + _cart(0, 4) + _plus(48, 40)),
    "extra_caravan": (2, '\n  <g transform="translate(5 6) scale(0.82)">' + _cart(-2, -8) + _cart(8, 8) + "\n  </g>" + _plus(47, 17)),
    "guild_partners": (2, f'''
  <circle cx="26" cy="30" r="12" fill="{GOLD}" stroke="{INK}" stroke-width="2.6"/>
  <circle cx="26" cy="30" r="7.5" fill="none" stroke="#8a5a26" stroke-width="1.8"/>
  <path d="M12 44 Q22 38 30 44 Q38 50 50 42" fill="none" stroke="#d8dde4" stroke-width="3" stroke-linecap="round"/>
  <path d="M44 14 L44 30 M38 24 L44 31 L50 24" fill="none" stroke="{INK}" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M44 14 L44 30 M38 24 L44 31 L50 24" fill="none" stroke="#5cc24a" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'''),
}


def advancement_icons():
    for adv_id, (tier, symbol) in ADV_ICONS.items():
        icon_svg("adv_" + adv_id, _adv_badge(tier, symbol))


# ------------------------------------------------------------------ item icons

# The hero's equipment icons ("item_<id>"): one badge for all, a dark disc like the
# advancements' with a ring coloured by the item's slot, and the item drawn large in it.
ITEM_RING = {"weapon": "#d2463c", "armour": "#c8873e", "accessory": "#a77ae0", "movement": "#5cbf5a"}
STEEL, STEEL_D, STEEL_L = "#b4bcc6", "#7a838e", "#e8edf2"
LEATHER, LEATHER_D, LEATHER_L = "#8a5a32", "#5e3c20", "#b07a48"


def _item_badge(slot, symbol):
    return f'''
  <circle cx="32" cy="32" r="29.5" fill="#2a2420" stroke="{INK}" stroke-width="3"/>
  <circle cx="32" cy="32" r="26" fill="none" stroke="{ITEM_RING[slot]}" stroke-width="3"/>
  <circle cx="32" cy="32" r="23.5" fill="#3a3028"/>
{symbol}'''


def _sword(blade=STEEL, edge=STEEL_L, guard=GOLD, grip=WOOD, pommel=GOLD, behind="", angle=45):
    """A longsword drawn upright and turned by `angle` about the badge's centre
    (45: tip to the upper right). `behind` is drawn in the same turned frame first."""
    return f'''
  <g transform="rotate({angle} 32 32)">{behind}
    <path d="M28.2 40 L28.2 14 L32 6 L35.8 14 L35.8 40Z" fill="{blade}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
    <path d="M32 11 L32 37" stroke="{edge}" stroke-width="1.8" stroke-linecap="round"/>
    <rect x="29.4" y="43" width="5.2" height="9" rx="1.5" fill="{grip}" stroke="{INK}" stroke-width="2.3"/>
    <path d="M30 46 L34 47.5 M30 49 L34 50.5" stroke="{INK}" stroke-width="1"/>
    <rect x="20" y="39" width="24" height="5" rx="2.5" fill="{guard}" stroke="{INK}" stroke-width="2.4"/>
    <circle cx="32" cy="55" r="3.6" fill="{pommel}" stroke="{INK}" stroke-width="2.2"/>
  </g>'''


def _drop(x, y, r, fill, hi="#ffffff"):
    """A teardrop hanging from (x, y)."""
    return f'''
  <path d="M{x} {y} Q{x + r * 1.1} {y + r * 1.6} {x + r} {y + r * 2.3} A{r} {r} 0 0 1 {x - r} {y + r * 2.3} Q{x - r * 1.1} {y + r * 1.6} {x} {y}Z" fill="{fill}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>
  <circle cx="{x - r * 0.35}" cy="{y + r * 2.1}" r="{r * 0.3}" fill="{hi}" opacity="0.8"/>'''


def _heart(cx, cy, s, fill="#d8342c"):
    return f'''
  <path d="M{cx} {cy + s * 0.9} L{cx - s * 0.95} {cy - s * 0.05} A{s * 0.5} {s * 0.5} 0 0 1 {cx} {cy - s * 0.65} A{s * 0.5} {s * 0.5} 0 0 1 {cx + s * 0.95} {cy - s * 0.05}Z" fill="{fill}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <circle cx="{cx - s * 0.5}" cy="{cy - s * 0.3}" r="{s * 0.16}" fill="#ffd0c8"/>'''


def _sparkle(x, y, r, fill="#ffffff", sw=1.2):
    k = r * 0.3
    return f'''
  <path d="M{x} {y - r} L{x + k} {y - k} L{x + r} {y} L{x + k} {y + k} L{x} {y + r} L{x - k} {y + k} L{x - r} {y} L{x - k} {y - k}Z" fill="{fill}" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round"/>'''


def _hatchet(tx, ty, rot, flip=False, s=1.0):
    """A small throwing hatchet, haft upright at (tx, ty), turned by rot."""
    sc = f" scale({-s} {s})" if flip else f" scale({s})"
    return f'''
  <g transform="translate({tx} {ty}) rotate({rot}){sc}">
    <path d="M-2 -15 L2 -15 L2.4 15 Q0 17.5 -2.4 15Z" fill="{WOOD_L}" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
    <path d="M-2.3 9 L2.3 9 M-2.3 12 L2.3 12" stroke="{INK}" stroke-width="1.2"/>
    <path d="M-3 -16 L5 -18 Q13 -20 15 -15 Q16 -8 14 -2 Q11 -5 5 -6 L-3 -7Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
    <path d="M13 -16 Q14.2 -9 12.6 -4" fill="none" stroke="{STEEL_L}" stroke-width="1.8" stroke-linecap="round"/>
  </g>'''


def _rays(cx, cy, r0, r1, n, color, sw=2.4, phase=0.0):
    out = ""
    for k in range(n):
        ang = phase + k * 2 * math.pi / n
        c, s = math.cos(ang), math.sin(ang)
        out += " M%s %s L%s %s" % (fmt(cx + c * r0), fmt(cy + s * r0), fmt(cx + c * r1), fmt(cy + s * r1))
    return f'''
  <path d="{out.strip()}" stroke="{color}" stroke-width="{sw}" stroke-linecap="round"/>'''


def _item_glow(gid, color, r=22, cx=32, cy=32, op=0.85):
    return f'''
  <defs><radialGradient id="{gid}"><stop offset="0" stop-color="{color}" stop-opacity="{op}"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient></defs>
  <circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{gid})"/>'''


def _torso(fill):
    """A short-sleeved body garment, front view (jerkin, mail shirt)."""
    return f'''
  <path d="M25 12 Q32 20 39 12 L46 15 L52 26 L46 31 L45 50 Q32 55 19 50 L18 31 L12 26 L18 15Z" fill="{fill}" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>'''


def _boot(fill, dark, light, sole="#3a2a1c", cuff=None, toe=52):
    """A boot side on, toe to the right: shaft x 18-36, sole at y 51."""
    c = cuff or dark
    return f'''
  <path d="M19 15 L36 15 L36 34 Q38 38 {toe - 8} 40 Q{toe} 42 {toe} 47 L{toe} 50 L18 50 L18 42 Q20 30 19 15Z" fill="{fill}" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M17 49 L{toe + 1} 49 L{toe + 1} 53 Q{toe} 54.5 {toe - 2} 54.5 L17 54.5Z" fill="{sole}" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M17 54.5 L17 49 L26 49 L26 54.5" fill="{sole}" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M17.5 12 L37.5 12 L37 20 L18.5 20Z" fill="{c}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M22 24 L22 44" stroke="{light}" stroke-width="2.4" stroke-linecap="round" opacity="0.7"/>'''


def _chain(points, color=GOLD):
    d = "M" + " L".join("%s %s" % (fmt(x), fmt(y)) for x, y in points)
    return f'''
  <path d="{d}" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="{d}" fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="2.6 1.6"/>'''


def _necklace_chain(x0=17, x1=47, ytop=10, ybot=30):
    """A chain hanging in a U from both top corners down to a pendant at (32, ybot)."""
    pts = []
    for k in range(13):
        t = k / 12.0
        x = x0 + (x1 - x0) * t
        y = ytop + (ybot - ytop) * (1 - (2 * t - 1) ** 2)
        pts.append((x, y))
    return _chain(pts)


def _net_body():
    """A weighted throwing net hanging square, sagging a little, with knots and lead weights."""
    def pt(u, v):
        return (15 + 34 * u + (u - 0.5) * 5 * math.sin(math.pi * v),
                11 + 33 * v + 3.5 * math.sin(math.pi * u) * (0.4 + 0.6 * v))

    n = 4
    rope = ""
    knots = ""
    for i in range(n + 1):
        col = [pt(i / n, k / 12.0) for k in range(13)]
        row = [pt(k / 12.0, i / n) for k in range(13)]
        for line in (col, row):
            rope += " M" + " L".join("%s %s" % (fmt(x), fmt(y)) for x, y in line)
        for j in range(n + 1):
            x, y = pt(i / n, j / n)
            knots += f'''
  <circle cx="{fmt(x)}" cy="{fmt(y)}" r="1.7" fill="#9a7a44" stroke="{INK}" stroke-width="0.8"/>'''
    out = f'''
  <path d="{rope.strip()}" fill="none" stroke="{INK}" stroke-width="3.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="{rope.strip()}" fill="none" stroke="#d8b878" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>{knots}'''
    for i in range(0, n + 1):
        if i == 2:
            continue
        x, y = pt(i / n, 1.0)
        out += f'''
  <path d="M{fmt(x)} {fmt(y)} L{fmt(x)} {fmt(y + 3)}" stroke="{INK}" stroke-width="1.6"/>
  <circle cx="{fmt(x)}" cy="{fmt(y + 5)}" r="3.8" fill="#5a5e66" stroke="{INK}" stroke-width="2"/>
  <circle cx="{fmt(x - 1.2)}" cy="{fmt(y + 3.8)}" r="1.1" fill="#a0a6ae"/>'''
    return out


def _bearskin():
    """A bear's pelt worn as a cloak: the head a hood with bared fangs, the
    forelegs knotted across the chest, a ragged fur hem."""
    fur, fur_d, fur_l = "#7a5434", "#4e3420", "#a07a52"
    hem = "L17 54 L20 50 L23 55 L26 51 L29 56 L32 52 L35 56 L38 51 L41 55 L44 50 L47 54 L49 49"
    tufts = "".join(f'''
  <path d="M{x} {y} q1.5 3 0 6" fill="none" stroke="{fur_l}" stroke-width="1.5" stroke-linecap="round"/>''' for x, y in [(17, 32), (22, 41), (42, 41), (47, 32), (27, 45), (37, 45), (19, 24), (45, 24)])
    return f'''
  <path d="M21 18 Q10 24 10 36 Q10 44 15 49 {hem} Q54 44 54 36 Q54 24 43 18Z" fill="{fur}" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>{tufts}
  <path d="M19 23 Q16 30 22 35 Q27 38 32 37 L33 33 Q26 32 23 27Z" fill="{fur_d}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M45 23 Q48 30 42 35 Q37 38 32 37 L31 33 Q38 32 41 27Z" fill="{fur_d}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <circle cx="32" cy="35.5" r="3.4" fill="{GOLD}" stroke="{INK}" stroke-width="1.8"/>
  <path d="M27 37 l-1.2 3 M29.5 38 l-0.4 3.2 M37 37 l1.2 3 M34.5 38 l0.4 3.2" stroke="#f4ecd8" stroke-width="1.7" stroke-linecap="round"/>
  <circle cx="20" cy="9.5" r="4.4" fill="{fur}" stroke="{INK}" stroke-width="2.2"/>
  <circle cx="44" cy="9.5" r="4.4" fill="{fur}" stroke="{INK}" stroke-width="2.2"/>
  <circle cx="20" cy="9.5" r="2" fill="#b08a64"/><circle cx="44" cy="9.5" r="2" fill="#b08a64"/>
  <path d="M15 21 Q14 7 32 6 Q50 7 49 21 Q46 27 39 27 L25 27 Q18 27 15 21Z" fill="{fur}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M25 17 Q25 11 32 11 Q39 11 39 17 L38 25 L26 25Z" fill="#b08a64" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M29.3 12.6 L34.7 12.6 L32 15.8Z" fill="{INK}" stroke="{INK}" stroke-width="1.2" stroke-linejoin="round"/>
  <path d="M21.5 15 L27 17.5 M42.5 15 L37 17.5" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>
  <path d="M22.2 14.9 L26.3 16.7 M41.8 14.9 L37.7 16.7" stroke="#f0a030" stroke-width="1.1" stroke-linecap="round"/>
  <path d="M26 24.5 L38 24.5" stroke="{INK}" stroke-width="2"/>
  <path d="M27.4 24.5 L28.7 29.5 L30 24.5 M34 24.5 L35.3 29.5 L36.6 24.5" fill="#f4ecd8" stroke="{INK}" stroke-width="1.2" stroke-linejoin="round"/>
  <path d="M18.5 13 Q21 9 26.5 9" fill="none" stroke="{fur_l}" stroke-width="1.6" stroke-linecap="round"/>'''


ITEM_ICONS = {
    # ---- weapons
    "longsword": ("weapon", _sword()),
    "flame_sword": ("weapon", _item_glow("fg", "#ff8a2a", 24) + _sword(blade="#ffd890", edge="#fff6d8", guard="#c83a1a", pommel="#c83a1a", behind=f'''
    <path d="M23 42 Q14 34 21 27 Q16 19 24 15 Q23 7 29 4 Q29 9 32 1 Q35 9 35 4 Q41 7 40 15 Q48 19 43 27 Q50 34 41 42Z" fill="#e8582a" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
    <path d="M26 40 Q20 34 25 29 Q22 22 27 19 Q27 12 32 7 Q37 12 37 19 Q42 22 39 29 Q44 34 38 40Z" fill="#ffc040"/>''')),
    "poison_sword": ("weapon", _sword(blade="#b8d8a8", edge="#e8f8d8", guard="#4a6a2a", pommel="#4a6a2a", behind=f'''
    <path d="M35.8 14 Q39.5 18 37 22 Q40 27 37.2 31 Q39.5 35 36 39 L35.8 14Z" fill="#6ad03a" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>''') + f'''
  <path d="M28.2 40 L28.2 14 L32 6 L35.8 14 L35.8 40Z" transform="rotate(45 32 32)" fill="#7ae04a" opacity="0.45"/>''' + _drop(41.5, 27, 2.6, "#6ad03a", "#e0ffc0") + _drop(34.5, 34, 3.2, "#6ad03a", "#e0ffc0") + _drop(44, 39, 2.2, "#4ab02a", "#e0ffc0")),
    "cleaver": ("weapon", f'''
  <g transform="rotate(-28 32 32)">
    <rect x="40" y="22" width="16" height="7" rx="2.5" fill="{WOOD_L}" stroke="{INK}" stroke-width="2.5"/>
    <circle cx="46" cy="25.5" r="1.3" fill="{STEEL_L}" stroke="{INK}" stroke-width="0.8"/>
    <circle cx="51" cy="25.5" r="1.3" fill="{STEEL_L}" stroke="{INK}" stroke-width="0.8"/>
    <path d="M10 17 L42 17 L42 40 Q26 44 10 41Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
    <path d="M11 37.5 Q26 40.5 41 37" fill="none" stroke="{STEEL_L}" stroke-width="2.2" stroke-linecap="round"/>
    <path d="M10 17 L42 17 L42 21 L10 21Z" fill="{STEEL_D}" opacity="0.6"/>
    <circle cx="16" cy="23" r="2.6" fill="#3a3028" stroke="{INK}" stroke-width="1.8"/>
    <path d="M18 41.5 Q19 46 21 44 M30 42.6 Q30.5 48 33 44" fill="none" stroke="#c82030" stroke-width="2.4" stroke-linecap="round"/>
  </g>''' + _heart(45, 45, 9)),
    "mace": ("weapon", f'''
  <path d="M15 51 L34 30" stroke="{INK}" stroke-width="7.5" stroke-linecap="round"/>
  <path d="M15 51 L34 30" stroke="{WOOD_L}" stroke-width="4" stroke-linecap="round"/>
  <path d="M17 45 L21 49 M20 42 L24 46 M23 39 L27 43" stroke="{INK}" stroke-width="1.6"/>
  <circle cx="13.5" cy="52.5" r="3.4" fill="{STEEL}" stroke="{INK}" stroke-width="2"/>''' + "".join(f'''
  <path d="M{fmt(38 + math.cos(a) * 7)} {fmt(26 + math.sin(a) * 7)} L{fmt(38 + math.cos(a + 0.42) * 15.5)} {fmt(26 + math.sin(a + 0.42) * 15.5)} L{fmt(38 + math.cos(a + 0.8) * 7)} {fmt(26 + math.sin(a + 0.8) * 7)}Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>''' for a in [k * math.pi / 4 for k in range(8)]) + f'''
  <circle cx="38" cy="26" r="8.5" fill="{STEEL}" stroke="{INK}" stroke-width="2.6"/>
  <circle cx="35.5" cy="23.5" r="3" fill="{STEEL_L}"/>
  <path d="M51 40 Q55 44 54 50 M46 45 Q50 49 48 54" fill="none" stroke="#ffd27a" stroke-width="2.4" stroke-linecap="round"/>'''),
    "lance": ("weapon", f'''
  <path d="M13 51 L44 21" stroke="{INK}" stroke-width="6.5" stroke-linecap="round"/>
  <path d="M13 51 L44 21" stroke="{WOOD_L}" stroke-width="3.4" stroke-linecap="round"/>
  <path d="M17 44 L21 48 M15 46.5 L19 50.5" stroke="{CRIMSON_D}" stroke-width="2"/>
  <path d="M38 27 L31 13 L24 18 L28 22 L18 22 L33 32Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M33 16 L36 23" stroke="#c8434f" stroke-width="2" stroke-linecap="round"/>
  <path d="M41 23 Q43 15 53 10 Q50 19 42 24Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M44 20 L50 13.5" stroke="{STEEL_L}" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M38 22 L43 27" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M38 22 L43 27" stroke="{GOLD}" stroke-width="2.5" stroke-linecap="round"/>'''),
    "great_axe": ("weapon", f'''
  <path d="M11 30 A21 21 0 0 1 46 15" fill="none" stroke="#e8f0ff" stroke-width="3" stroke-linecap="round" opacity="0.55"/>
  <path d="M53 34 A21 21 0 0 1 18 49" fill="none" stroke="#e8f0ff" stroke-width="3" stroke-linecap="round" opacity="0.55"/>
  <path d="M46 15 L41 11 M46 15 L40 18 M18 49 L23 53 M18 49 L24 46" stroke="#e8f0ff" stroke-width="3" stroke-linecap="round" opacity="0.55"/>
  <g transform="rotate(28 32 32)">
    <rect x="29.5" y="10" width="5" height="46" rx="2" fill="{WOOD_L}" stroke="{INK}" stroke-width="2.4"/>
    <path d="M29.5 46 L34.5 46 M29.5 49.5 L34.5 49.5" stroke="{INK}" stroke-width="1.3"/>
    <path d="M34 15 L43 10 Q53 22 43 35 L34 30Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
    <path d="M30 15 L21 10 Q11 22 21 35 L30 30Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
    <path d="M44.5 13 Q50 22 44.5 32 M19.5 13 Q14 22 19.5 32" fill="none" stroke="{STEEL_L}" stroke-width="1.8" stroke-linecap="round"/>
    <rect x="28.5" y="14" width="7" height="17" rx="1.5" fill="{STEEL_D}" stroke="{INK}" stroke-width="2.2"/>
    <path d="M32 6 L35 10 L32 13 L29 10Z" fill="{STEEL}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>
  </g>'''),
    "blessed_blade": ("weapon", _item_glow("bg", "#fff0a0", 23) + _rays(32, 32, 11, 22, 12, "#ffe070", 2.4, 0.26) + _sword(blade="#fff4cc", edge="#ffffff", guard=GOLD, pommel=GOLD) + _sparkle(16, 18, 4.5, "#fff6c0") + _sparkle(48, 46, 3.5, "#fff6c0")),
    # ---- campaign items (Config.ITEMS "campaign"): the First King's Hand, upright,
    # ornate, glowing like a coal under ash
    "first_kings_hand": ("weapon", _item_glow("kh", "#ff8a3a", 24, op=0.6) + _sword(blade="#dfe3ea", edge="#ffffff", guard=GOLD, grip="#7a1c1c", pommel=GOLD, angle=0, behind=f'''
    <path d="M20 41.5 L16 36 L22 39Z M44 41.5 L48 36 L42 39Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>''') + f'''
  <path d="M30.6 26 L32 21 L33.4 26 L32 31Z" fill="#f4d68a" stroke="{GOLD_D}" stroke-width="0.8"/>
  <circle cx="32" cy="41.5" r="2.4" fill="#c8202a" stroke="{INK}" stroke-width="1.2"/>''' + _sparkle(17, 16, 4, "#ffe0b0") + _sparkle(47, 22, 3, "#ffe0b0")),
    "throwing_axes": ("weapon", f'''
  <path d="M8 22 L16 22 M6 30 L14 30 M9 38 L15 38" stroke="#e8e0cc" stroke-width="2.4" stroke-linecap="round" opacity="0.75"/>''' + _hatchet(27, 35, -38) + _hatchet(39, 35, 38, flip=True)),
    # ---- armour
    "leather_armour": ("armour", _torso(LEATHER) + f'''
  <path d="M25 12 Q32 20 39 12 L37 11 Q32 16 27 11Z" fill="{LEATHER_D}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M32 19 L32 44" stroke="{LEATHER_D}" stroke-width="2.2"/>
  <path d="M29 22 L35 25 M35 22 L29 25 M29 28 L35 31 M35 28 L29 31 M29 34 L35 37 M35 34 L29 37" stroke="#e8d0a0" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M19.5 41 Q32 45 44.5 41 L44.7 46 Q32 50 19.3 46Z" fill="{LEATHER_D}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <rect x="29" y="41.5" width="6" height="6" rx="1" fill="none" stroke="{GOLD}" stroke-width="1.8"/>
  <path d="M21 24 Q22 34 21 40 M43 24 Q42 34 43 40" fill="none" stroke="{LEATHER_L}" stroke-width="1.8" stroke-dasharray="2 2"/>
  <path d="M14 26 L18 22 M50 26 L46 22" stroke="{LEATHER_D}" stroke-width="1.6"/>'''),
    "full_plate": ("armour", f'''
  <path d="M22 14 Q32 22 42 14 L46 18 L44 28 Q46 40 43 49 Q32 54 21 49 Q18 40 20 28 L18 18Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M32 19 L32 47 L43 49 Q46 40 44 28 L46 18 L42 14 Q37 18 32 19Z" fill="{STEEL_D}" opacity="0.55"/>
  <path d="M32 20 L32 47" stroke="{INK}" stroke-width="1.8"/>
  <path d="M24 22 Q23 30 25 38" fill="none" stroke="{STEEL_L}" stroke-width="2.6" stroke-linecap="round"/>
  <path d="M21 41 Q32 45 43 41 M21.5 45.5 Q32 49.5 42.5 45.5" fill="none" stroke="{INK}" stroke-width="1.8"/>
  <path d="M8 26 Q8 14 20 13 L24 17 Q16 20 15 30Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M56 26 Q56 14 44 13 L40 17 Q48 20 49 30Z" fill="{STEEL_D}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M11 22 Q13 17 19 16" fill="none" stroke="{STEEL_L}" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="24.5" cy="19.5" r="1.3" fill="{INK}"/><circle cx="39.5" cy="19.5" r="1.3" fill="{INK}"/>
  <path d="M22 14 Q32 22 42 14" fill="none" stroke="{GOLD}" stroke-width="2"/>'''),
    "bearskin": ("armour", _bearskin()),
    "buckler": ("armour", f'''
  <circle cx="32" cy="32" r="19" fill="{STEEL_D}" stroke="{INK}" stroke-width="2.8"/>
  <circle cx="32" cy="32" r="15" fill="{LEATHER}" stroke="{INK}" stroke-width="2"/>
  <path d="M22 21 L42 43 M42 21 L22 43" stroke="{LEATHER_D}" stroke-width="2"/>
  <path d="M17.5 30 A15 15 0 0 1 29 17.3" fill="none" stroke="{STEEL_L}" stroke-width="2" stroke-linecap="round" transform="translate(-2.4 -2.4)"/>''' + "".join(f'''
  <circle cx="{fmt(32 + math.cos(a) * 17)}" cy="{fmt(32 + math.sin(a) * 17)}" r="1.3" fill="{STEEL_L}" stroke="{INK}" stroke-width="0.8"/>''' for a in [k * math.pi / 4 + 0.39 for k in range(8)]) + f'''
  <circle cx="32" cy="32" r="7" fill="{STEEL}" stroke="{INK}" stroke-width="2.4"/>
  <circle cx="30" cy="30" r="2.4" fill="{STEEL_L}"/>'''),
    "magical_shield": ("armour", _item_glow("mg", "#b48aff", 25) + f'''
  <path d="M15 13 L49 13 L49 30 Q49 46 32 55 Q15 46 15 30Z" fill="#c8ccd8" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M19 17 L45 17 L45 30 Q45 43 32 50.5 Q19 43 19 30Z" fill="#33285e" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M32 22 L32 46 M32 32 L24 24 M32 32 L40 24 M26 41 L32 36 L38 41" fill="none" stroke="#b48aff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" opacity="0.5"/>
  <path d="M32 22 L32 46 M32 32 L24 24 M32 32 L40 24 M26 41 L32 36 L38 41" fill="none" stroke="#efe6ff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>''' + _sparkle(12, 18, 3.5, "#e0d0ff") + _sparkle(52, 44, 3, "#e0d0ff") + _sparkle(50, 9, 2.6, "#e0d0ff", 1)),
    "thorn_mail": ("armour", f'''
  <defs><pattern id="mail" width="4" height="3.5" patternUnits="userSpaceOnUse"><rect width="4" height="3.5" fill="#8a929c"/><path d="M0 3 Q2 0 4 3" fill="none" stroke="#4a5058" stroke-width="0.9"/></pattern></defs>''' + "".join(f'''
  <path d="M{x0} {y0} L{x1} {y1} L{x2} {y2}Z" fill="#d8d0b8" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>''' for (x0, y0, x1, y1, x2, y2) in [
        (14, 23, 6, 22, 12, 28), (17, 16, 11, 11, 20, 14), (47, 16, 53, 11, 44, 14), (50, 23, 58, 22, 52, 28),
        (19, 36, 11, 38, 19, 41), (45, 36, 53, 38, 45, 41), (25, 51, 22, 58, 29, 52), (39, 51, 42, 58, 35, 52)]) + _torso("url(#mail)") + f'''
  <path d="M25 12 Q32 20 39 12" fill="none" stroke="{STEEL_L}" stroke-width="1.8"/>
  <path d="M19 30 Q30 24 36 34 Q41 42 45 38" fill="none" stroke="{INK}" stroke-width="4.6" stroke-linecap="round"/>
  <path d="M19 30 Q30 24 36 34 Q41 42 45 38" fill="none" stroke="#4a6a2a" stroke-width="2.6" stroke-linecap="round"/>''' + "".join(f'''
  <path d="M{x - 2} {y} L{x + dx} {y + dy} L{x + 2} {y + 0.5}Z" fill="#c8c0a0" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>''' for (x, y, dx, dy) in [(24, 27, -1, -6), (30, 27, 2, -6), (34, 31, 6, -4), (37, 38, -4, 5), (41, 40, 1, -5), (27, 28, -2, 5)])),
    # ---- accessories
    "soldiers_helmet": ("accessory", f'''
  <path d="M14 38 Q14 12 32 11 Q50 12 50 38Z" fill="#8a929c" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M32 11 Q44 12 48 30 L50 38 L32 38Z" fill="#5a626c" opacity="0.45"/>
  <path d="M20 30 Q20 17 30 15" fill="none" stroke="#c8d0d8" stroke-width="2.8" stroke-linecap="round"/>
  <path d="M32 11 L32 38" stroke="#5a626c" stroke-width="2.2"/>
  <path d="M10 38 L54 38 L52 44 L12 44Z" fill="#6a727c" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M29 38 L35 38 L35 53 Q32 56 29 53Z" fill="#7a828c" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <circle cx="17" cy="41" r="1.4" fill="{INK}"/><circle cx="25" cy="41" r="1.4" fill="{INK}"/><circle cx="39" cy="41" r="1.4" fill="{INK}"/><circle cx="47" cy="41" r="1.4" fill="{INK}"/>'''),
    "net": ("accessory", _net_body()),
    "rose_necklace": ("accessory", _necklace_chain(14, 50, 12, 32) + f'''
  <path d="M26 44 Q18 44 16 50 Q24 52 28 46Z M38 44 Q46 44 48 50 Q40 52 36 46Z" fill="#4a8a3a" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M19 49 L26 46 M45 49 L38 46" stroke="#2a5a20" stroke-width="1.2"/>
  <circle cx="32" cy="41" r="10.5" fill="#c82838" stroke="{INK}" stroke-width="2.6"/>
  <path d="M32 41 m-2 0 a2.4 2.4 0 1 1 4 1.6 a5 5 0 0 1 -8 -3 a6.5 6.5 0 0 1 11 -3.5 M25 45 Q28 50 35 49 Q40 47 41 42" fill="none" stroke="#7a1420" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M26 36 Q28 33 31 32.5" fill="none" stroke="#f07888" stroke-width="2" stroke-linecap="round"/>
  <circle cx="32" cy="30" r="2.2" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>'''),
    "ring_of_might": ("accessory", _rays(32, 22, 13, 19, 7, "#ff9a3a", 2.4, -2.9) + f'''
  <ellipse cx="32" cy="41" rx="15" ry="10.5" fill="none" stroke="{INK}" stroke-width="9"/>
  <ellipse cx="32" cy="41" rx="15" ry="10.5" fill="none" stroke="{GOLD}" stroke-width="5"/>
  <path d="M20 46 Q32 54 44 46" fill="none" stroke="{GOLD_D}" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M21 36 Q24 32.5 28 31.6" fill="none" stroke="#ffe8a0" stroke-width="2" stroke-linecap="round"/>
  <path d="M23 31 L41 31 L38 25 L26 25Z" fill="{GOLD}" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M32 12 L40 18 L37 27 L27 27 L24 18Z" fill="#d8242c" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M24 18 L32 20 L40 18 M32 20 L32 12 M27 27 L32 20 L37 27" fill="none" stroke="#8a0a14" stroke-width="1.2" stroke-linejoin="round"/>
  <path d="M28 15.5 L31 13.5" stroke="#ffb0b0" stroke-width="2" stroke-linecap="round"/>'''),
    "lantern": ("accessory", _item_glow("lg", "#ffc84a", 24, 32, 36) + f'''
  <path d="M25 15 Q25 6 32 6 Q39 6 39 15" fill="none" stroke="{INK}" stroke-width="4.2" stroke-linecap="round"/>
  <path d="M25 15 Q25 6 32 6 Q39 6 39 15" fill="none" stroke="#6a727c" stroke-width="2" stroke-linecap="round"/>
  <path d="M21 20 L32 13 L43 20Z" fill="#4a4e56" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <rect x="21" y="19" width="22" height="4" rx="1" fill="#5a5e66" stroke="{INK}" stroke-width="2"/>
  <path d="M22.5 23 L41.5 23 L40 46 L24 46Z" fill="#ffe7a0" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M32 27 Q37 33 35 38 Q34 42 32 42 Q29 42 29 38 Q28 34 32 27Z" fill="#ff9a2a" stroke="#c85a10" stroke-width="1.2"/>
  <path d="M32 33 Q34 36 33 39 Q32 40.5 31 39 Q30 37 32 33Z" fill="#fff6d0"/>
  <path d="M27.5 23 L28.5 46 M36.5 23 L35.5 46" stroke="#4a4e56" stroke-width="2.2"/>
  <rect x="20" y="45" width="24" height="5" rx="1.5" fill="#5a5e66" stroke="{INK}" stroke-width="2.2"/>
  <path d="M25 26 L25.5 40" stroke="#ffffff" stroke-width="1.6" stroke-linecap="round" opacity="0.8"/>'''),
    "gatherers_satchel": ("accessory", f'''
  <path d="M18 30 Q16 10 32 10 Q48 10 46 30" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>
  <path d="M18 30 Q16 10 32 10 Q48 10 46 30" fill="none" stroke="{LEATHER_D}" stroke-width="3.2" stroke-linecap="round"/>
  <path d="M38 26 Q42 14 50 15 Q46 18 46 22 M42 21 Q38 15 40 10" fill="none" stroke="{INK}" stroke-width="3.6" stroke-linecap="round"/>
  <path d="M38 26 Q42 14 50 15 Q46 18 46 22 M42 21 Q38 15 40 10" fill="none" stroke="#5cb84a" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M13 27 L51 27 L50 48 Q49 53 44 53 L20 53 Q15 53 14 48Z" fill="{LEATHER}" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M16 46 L16 32 M48 46 L48 32" stroke="{LEATHER_L}" stroke-width="1.6" stroke-dasharray="2 2"/>
  <path d="M12 27 L52 27 L51 37 Q32 44 13 37Z" fill="{LEATHER_L}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M15 30 Q32 35 49 30" fill="none" stroke="{LEATHER_D}" stroke-width="1.4" stroke-dasharray="2 2"/>
  <path d="M29.5 38 L29.5 47 L34.5 47 L34.5 38" fill="{LEATHER_D}" stroke="{INK}" stroke-width="2"/>
  <rect x="28" y="38" width="8" height="7" rx="1" fill="none" stroke="{GOLD}" stroke-width="2"/>'''),
    "builders_gloves": ("accessory", f'''
  <g transform="translate(46 18) rotate(30)">
    <rect x="-2" y="2" width="4" height="27" rx="1.5" fill="{WOOD_L}" stroke="{INK}" stroke-width="2.2"/>
    <rect x="-8" y="-4" width="16" height="7.5" rx="1.8" fill="#8a929c" stroke="{INK}" stroke-width="2.4"/>
    <rect x="-6.5" y="-2.8" width="6" height="2" rx="1" fill="#c8d0d8"/>
  </g>
  <path d="M18 46 L17 30 Q14 28 11 24 Q10 20 13 20 Q17 21 20 26 L20 16 Q20 13 23 13 Q26 13 26 16 L26 13 Q26 10 29 10 Q32 10 32 13 L32 15 Q32 12 35 12 Q38 12 38 15 L38 19 Q38 16 41 16 Q44 16 44 19 L44 34 Q44 42 40 46Z" fill="#d0a060" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M26 16 L26 27 M32 15 L32 27 M38 19 L38 28" stroke="#8a6030" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M21 32 Q30 36 41 31" fill="none" stroke="#8a6030" stroke-width="1.6" stroke-dasharray="2 2"/>
  <path d="M16 44 L42 44 L43 54 L15 54Z" fill="#8a5a32" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M17 49 L42 49" stroke="#b07a48" stroke-width="1.6"/>'''),
    "scholars_tome": ("accessory", f'''
  <path d="M14 18 L42 12 L52 18 L24 24Z" fill="#efe3c8" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
  <path d="M24 24 L52 18 L52 44 L24 51Z" fill="#efe3c8" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M27 27 L49 22 M27 31 L49 26 M27 35 L49 30 M27 39 L49 34 M27 43 L49 38" stroke="#c8b890" stroke-width="1.2"/>
  <path d="M12 18 L24 24 L24 54 L12 48Z" fill="#6a2a3a" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M12 18 L40 12 L42 15 L14 21Z" fill="#7a3444" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M24 51 L52 44 L52 47 L24 54Z" fill="#7a3444" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M14 25 L22 29 M14 43 L22 47" stroke="{GOLD}" stroke-width="2" stroke-linecap="round"/>
  <path d="M40 46 L40 58 L43 55 L46 58 L46 45" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M38 22 L40.5 28 L47 28.5 L42 32.5 L43.6 39 L38 35.5 L32.4 39 L34 32.5 L29 28.5 L35.5 28Z" fill="#7fd0ff" stroke="{INK}" stroke-width="2" stroke-linejoin="round" transform="translate(-0.5 -1) skewY(-12) translate(0 8)"/>'''),
    # ---- movement
    "soldiers_boots": ("movement", _boot(LEATHER, LEATHER_D, LEATHER_L) + f'''
  <path d="M36 32 L36 38" stroke="{INK}" stroke-width="1.4"/>
  <rect x="17.8" y="27" width="18.6" height="4" fill="{LEATHER_D}" stroke="{INK}" stroke-width="1.6"/>
  <rect x="25" y="26" width="5" height="6" rx="1" fill="none" stroke="{GOLD}" stroke-width="1.6"/>'''),
    "swift_boots": ("movement", f'''
  <path d="M8 26 L15 26 M7 34 L15 34 M9 42 L15 42" stroke="#ffd27a" stroke-width="2.6" stroke-linecap="round"/>''' + _boot("#c08a4a", "#8a5a2a", "#e0b070") + f'''
  <path d="M35 26 Q45 16 54 18 Q49 21 53 24.5 Q46 25 50 28.5 Q43 29 36 33Z" fill="#f4f0e6" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M38 28 Q45 23 52 22" fill="none" stroke="#b8b0a0" stroke-width="1.3"/>'''),
    "feather_boots": ("movement", f'''
  <path d="M24 20 Q14 16 15 8 Q22 9 27 18Z" fill="#f4f0e6" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M38 20 Q48 15 48 7 Q41 8 35 18Z" fill="#f4f0e6" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M29 20 Q26 10 31 5 Q36 10 33 20Z" fill="#cfe4f0" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M25 19 L17 10 M31 19 L31 8 M37 19 L46 9" stroke="#9a9488" stroke-width="1.2"/>
  <g transform="translate(32 40) scale(0.82) translate(-32 -40)">''' + _boot("#d8ccb0", "#a8987a", "#f4ecda", sole="#7a6a50") + f'''
  </g>
  <path d="M20 55 Q25 52.5 30 55 Q35 57.5 40 55 Q42.5 53.8 45 55" fill="none" stroke="#9ad8ff" stroke-width="2.2" stroke-linecap="round" opacity="0.9"/>'''),
    "heavy_boots": ("movement", _boot(STEEL, STEEL_D, STEEL_L, sole="#3a3e44", cuff=STEEL_D, toe=54) + f'''
  <path d="M36 34 Q38 38 46 40 M38 39 L38 49 M44 40.5 L44 49 M50 43 L50 49" fill="none" stroke="{INK}" stroke-width="1.8"/>
  <path d="M19 26 L36 26 M19 33 L36 33 M18.5 41 L36 41" stroke="{INK}" stroke-width="1.8"/>
  <circle cx="33" cy="23" r="1.3" fill="{INK}"/><circle cx="33" cy="30" r="1.3" fill="{INK}"/><circle cx="33" cy="37" r="1.3" fill="{INK}"/>
  <path d="M40 44 Q46 43 50 46" fill="none" stroke="{STEEL_L}" stroke-width="1.8" stroke-linecap="round"/>'''),
    "pathfinders_boots": ("movement", f'''
  <path d="M14 46 Q10 38 14 32 Q18 26 14 18" fill="none" stroke="#e8d6a8" stroke-width="2.8" stroke-linecap="round" stroke-dasharray="0.5 5"/>
  <g transform="translate(5 3) scale(0.9)">''' + _boot("#6a5a3a", "#4a3e26", "#8a7a54") + f'''
  </g>
  <circle cx="45" cy="21" r="9.5" fill="{GOLD}" stroke="{INK}" stroke-width="2.4"/>
  <circle cx="45" cy="21" r="6.8" fill="#efe3c8" stroke="{INK}" stroke-width="1.4"/>
  <path d="M45 15 L47.2 21 L45 21Z" fill="#d8342c"/>
  <path d="M45 27 L42.8 21 L45 21Z" fill="#5a626c"/>
  <path d="M45 15 L47.2 21 L45 27 L42.8 21Z" fill="none" stroke="{INK}" stroke-width="1.2" stroke-linejoin="round"/>
  <circle cx="45" cy="21" r="1.1" fill="{INK}"/>
  <path d="M45 10 L45 11.5" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/>'''),
}


def item_icons():
    for item_id, (slot, symbol) in ITEM_ICONS.items():
        icon_svg("item_" + item_id, _item_badge(slot, symbol))


# ------------------------------------------------------------------ relic icons

# The relics' icons ("relic_<id>", Config.relic_icon): the items' badge with a
# gold rim of two rings and four studs, so a relic reads as one at a glance.
def _relic_badge(symbol):
    studs = "".join(f'''
  <circle cx="{fmt(32 + math.cos(a) * 27.7)}" cy="{fmt(32 + math.sin(a) * 27.7)}" r="2.6" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>''' for a in [k * math.pi / 2 - math.pi / 4 for k in range(4)])
    return f'''
  <circle cx="32" cy="32" r="30" fill="#2a2420" stroke="{INK}" stroke-width="3"/>
  <circle cx="32" cy="32" r="27.6" fill="none" stroke="{GOLD_D}" stroke-width="4"/>
  <circle cx="32" cy="32" r="27.6" fill="none" stroke="{GOLD}" stroke-width="2"/>
  <circle cx="32" cy="32" r="24.4" fill="#3a3028" stroke="{GOLD_D}" stroke-width="1"/>{studs}
{symbol}'''


def _hawk_head():
    """A hawk's head in profile, looking right: hooked gold beak, a fierce amber eye."""
    br, br_d, cream = "#8a5a2e", "#5e3a1c", "#efe3c8"
    return f'''
  <path d="M14 52 Q12 36 18 26 Q24 14 36 13 Q45 13 49 20 L53 22 Q57 25 55 31 Q54 35 50 34 L47 33 Q44 38 38 40 Q36 48 40 54 Q27 57 14 52Z" fill="{br}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M38 40 Q36 48 40 54 Q30 56 22 54 Q26 46 30 41 Q34 40 38 40Z" fill="{cream}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M24 48 l3 -2 M28 51 l3 -2 M32 46 l3 -1.5" stroke="{br_d}" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M18 34 Q22 30 28 31 M17 41 Q22 37 28 38 M21 24 Q26 21 31 22" fill="none" stroke="{br_d}" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M47 19.5 Q55 19 58 26 Q59 32 55 36 Q55 31 52 29 L47 30Z" fill="{GOLD}" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M47 30 L52 29 Q55 31 55 36" fill="none" stroke="{GOLD_D}" stroke-width="1.4"/>
  <path d="M33 20 Q40 16 47 21" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>
  <circle cx="40" cy="24.5" r="4.6" fill="#f0a020" stroke="{INK}" stroke-width="2"/>
  <circle cx="40.8" cy="24.5" r="2.2" fill="{INK}"/>
  <circle cx="39.2" cy="23" r="1" fill="#fff6d8"/>'''


def _phoenix_feather():
    """A long feather in fire colours, its vane flaring into flames, with embers."""
    return _item_glow("pf", "#ff7a2a", 25) + f'''
  <defs><linearGradient id="pfv" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#c8241a"/><stop offset="0.55" stop-color="#ff7a1a"/><stop offset="1" stop-color="#ffd860"/></linearGradient></defs>
  <g transform="rotate(38 32 32)">
    <path d="M32 6 Q42 12 43 24 Q47 26 44 31 Q47 35 43 39 Q44 45 37 49 L32 54 L27 49 Q20 45 21 39 Q17 35 20 31 Q17 26 21 24 Q22 12 32 6Z" fill="url(#pfv)" stroke="{INK}" stroke-width="2.4" stroke-linejoin="round"/>
    <path d="M32 9 Q38 16 38 26 Q36 34 32 40 Q28 34 26 26 Q26 16 32 9Z" fill="#ffe08a" opacity="0.75"/>
    <path d="M32 8 L32 60" stroke="{INK}" stroke-width="3.4" stroke-linecap="round"/>
    <path d="M32 9 L32 59" stroke="#fff0c0" stroke-width="1.5" stroke-linecap="round"/>
    <path d="M32 20 L40 15 M32 28 L42 24 M32 36 L41 34 M32 20 L24 15 M32 28 L22 24 M32 36 L23 34" stroke="#a81c14" stroke-width="1.2" stroke-linecap="round"/>
  </g>''' + _sparkle(14, 18, 3.6, "#ffd860") + _sparkle(50, 48, 3, "#ffb040") + _sparkle(48, 13, 2.4, "#fff0c0")


def _hearth_stone():
    """A round river stone with a carved hearth rune, glowing with embers from within."""
    return _item_glow("hs", "#ff8a30", 26, 32, 32, 0.8) + f'''
  <g transform="translate(0 5)">
  <path d="M20 22 Q16 14 22 9 Q22 14 25 14 Q24 6 31 2 Q30 9 34 10 Q36 5 40 6 Q38 11 42 13 Q46 10 46 14 Q48 19 44 22Z" fill="#e8582a" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M24 21 Q22 16 26 13 Q27 16 29 16 Q29 10 33 7 Q33 12 36 13 Q38 11 39 13 Q41 17 40 21Z" fill="#ffc040"/>
  </g>
  <path d="M12 38 Q10 24 22 18 Q32 13 43 17 Q55 22 54 36 Q53 49 40 52 Q26 55 17 49 Q12 45 12 38Z" fill="#6e6a64" stroke="{INK}" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M17 47 Q26 53 40 51 Q52 48 53 38 Q48 46 38 47 Q26 48 17 47Z" fill="#4a4743" opacity="0.8"/>
  <path d="M16 31 Q19 22 29 19" fill="none" stroke="#9a958d" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M24 44 L32 26 L40 44 M27 37 L37 37 M32 26 L32 22" fill="none" stroke="#3a1c0c" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M24 44 L32 26 L40 44 M27 37 L37 37 M32 26 L32 22" fill="none" stroke="#ffb040" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="32" cy="40.5" r="2.4" fill="#fff0b0" stroke="#e86a1a" stroke-width="1"/>''' + _sparkle(48, 14, 2.6, "#ffc060") + _sparkle(17, 15, 2, "#ffc060")


def _harvest_idol():
    """A corn dolly: a plump little figure of plaited straw, crowned with
    wheat ears, a red ribbon at its waist."""
    straw, straw_d, straw_l = "#e4bc54", "#a87c26", "#f8e49a"
    ears = "".join(f'''
  <g transform="rotate({a} 32 20)">
    <path d="M32 18 L32 8" stroke="{straw_d}" stroke-width="1.8"/>
    <path d="M32 1.5 Q36.5 5.5 32 12 Q27.5 5.5 32 1.5Z" fill="{straw}" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M32 4.5 L32 10.5 M30 6 L32 8 L34 6" fill="none" stroke="{straw_d}" stroke-width="1"/>
  </g>''' for a in (-44, -16, 16, 44))
    return _item_glow("hi", "#ffe080", 24, 32, 36, 0.5) + ears + f'''
  <path d="M27 27 Q18 29 13 37 Q15 40 18 39 Q22 34 27 33Z" fill="{straw}" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M37 27 Q46 29 51 37 Q49 40 46 39 Q42 34 37 33Z" fill="{straw}" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M15 37 l-1.5 3 M17 38.5 l-0.5 3 M49 37 l1.5 3 M47 38.5 l0.5 3" stroke="{straw_d}" stroke-width="1.3" stroke-linecap="round"/>
  <path d="M26 26 Q32 24 38 26 L39 38 Q48 46 49 55 L15 55 Q16 46 25 38Z" fill="{straw}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M28 41 L23 54 M31 41 L29 54 M33 41 L35 54 M36 41 L41 54" stroke="{straw_d}" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M28 28 L36 34 M36 28 L28 34" stroke="{straw_d}" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M22 47 Q32 44 42 47" fill="none" stroke="{straw_l}" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M25 36 Q32 38.5 39 36 L39.5 40 Q32 42.5 24.5 40Z" fill="#c8302a" stroke="{INK}" stroke-width="1.7" stroke-linejoin="round"/>
  <path d="M32 40.5 L28.5 47.5 M32 40.5 L35.5 47.5" stroke="{INK}" stroke-width="3.6" stroke-linecap="round"/>
  <path d="M32 40.5 L28.5 47.5 M32 40.5 L35.5 47.5" stroke="#c8302a" stroke-width="2" stroke-linecap="round"/>
  <circle cx="32" cy="19.5" r="7.2" fill="{straw}" stroke="{INK}" stroke-width="2.5"/>
  <path d="M27 17.5 Q32 15.5 37 17.5 M26.5 21.5 Q32 19.5 37.5 21.5" fill="none" stroke="{straw_d}" stroke-width="1.3"/>
  <path d="M27.5 14.5 Q30 12.5 33 12.8" fill="none" stroke="{straw_l}" stroke-width="1.5" stroke-linecap="round"/>'''


def _woodcutters_axe():
    """A broad felling axe, its head marked with a carved tree, a chip flying."""
    return f'''
  <g transform="rotate(-30 32 32)">
    <rect x="29.5" y="10" width="5" height="46" rx="2.3" fill="{WOOD_L}" stroke="{INK}" stroke-width="2.4"/>
    <path d="M31 16 L31 52" stroke="{WOOD}" stroke-width="1.2"/>
    <path d="M30 13 L18 9 Q9 18 11 30 L30 26Z" fill="{STEEL}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
    <path d="M17.5 11 Q11 19 12.5 28" fill="none" stroke="{STEEL_L}" stroke-width="2" stroke-linecap="round"/>
    <path d="M21 23 L21 15 M21 15 L18 19 M21 15 L24 19 M21 18.5 L18.5 22 M21 18.5 L23.5 22" stroke="#3a6a2a" stroke-width="1.6" stroke-linecap="round"/>
    <rect x="28" y="11" width="8" height="16" rx="1.5" fill="{STEEL_D}" stroke="{INK}" stroke-width="2.2"/>
    <rect x="28.5" y="44" width="7" height="4" rx="1" fill="{GOLD}" stroke="{INK}" stroke-width="1.6"/>
  </g>
  <path d="M44 16 L50 13 L52 18 L46 20Z" fill="#e0b878" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round"/>
  <path d="M47 24 L51 23 L51.5 26.5Z" fill="#e0b878" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>'''


def _masons_seal():
    """A red wax seal pressed with a wall of bricks and a trowel, ribbon tails below."""
    return f'''
  <path d="M25 40 L19 56 L24 53 L27 57 L31 43Z" fill="#3a5a8a" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M39 40 L45 56 L40 53 L37 57 L33 43Z" fill="#3a5a8a" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M32 9 Q38 10 41 12 Q47 12 49 17 Q54 20 53 26 Q56 31 53 36 Q54 42 48 44 Q46 49 40 49 Q36 53 32 51 Q28 53 24 49 Q18 49 16 44 Q10 42 11 36 Q8 31 11 26 Q10 20 15 17 Q17 12 23 12 Q26 10 32 9Z" fill="#b8282a" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <circle cx="32" cy="30" r="15" fill="#9a1c20" stroke="#6a1014" stroke-width="1.6"/>
  <path d="M20 35 L44 35 M20 29 L44 29 M23 23 L41 23 M26 23 L26 29 M32 23 L32 29 M38 23 L38 29 M23 29 L23 35 M29 29 L29 35 M35 29 L35 35 M41 29 L41 35" stroke="#e86a5a" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M30 41 L34 37 L42 39 L38 43Z" fill="#e86a5a" stroke="#6a1014" stroke-width="1"/>
  <path d="M18 18 Q22 14 27 13" fill="none" stroke="#e8605a" stroke-width="1.8" stroke-linecap="round"/>'''


def _tithe_box():
    """A small iron-bound strongbox with a coin slot, gold coins on and before it."""
    return f'''
  <path d="M12 30 L52 30 L50 52 L14 52Z" fill="{WOOD}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M11 22 Q32 14 53 22 L53 31 L11 31Z" fill="{WOOD_L}" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M20 19 L20 52 M44 19 L44 52" stroke="{STEEL_D}" stroke-width="4"/>
  <path d="M20 19 L20 52 M44 19 L44 52" stroke="{INK}" stroke-width="0.8" stroke-dasharray="0.5 5"/>
  <rect x="26" y="20.5" width="12" height="3" rx="1.4" fill="{INK}"/>
  <rect x="28" y="36" width="8" height="9" rx="1.5" fill="{GOLD}" stroke="{INK}" stroke-width="1.8"/>
  <circle cx="32" cy="39.5" r="1.4" fill="{INK}"/><path d="M32 40 L32 43" stroke="{INK}" stroke-width="1.4"/>
  <ellipse cx="32" cy="14" rx="5" ry="5" fill="{GOLD}" stroke="{INK}" stroke-width="2"/>
  <path d="M32 11.5 L32 16.5" stroke="{GOLD_D}" stroke-width="1.6"/>
  <ellipse cx="51" cy="53" rx="6" ry="3" fill="{GOLD}" stroke="{INK}" stroke-width="1.8"/>
  <ellipse cx="49" cy="49.5" rx="6" ry="3" fill="#e0be60" stroke="{INK}" stroke-width="1.8"/>''' + _sparkle(17, 14, 2.6, "#fff0b0")


def _kings_banner():
    """An old war banner on a pole: deep blue, swallow-tailed, a gold crown on it."""
    return f'''
  <path d="M18 8 L18 58" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
  <path d="M18 8 L18 58" stroke="{WOOD_L}" stroke-width="2.6" stroke-linecap="round"/>
  <circle cx="18" cy="7" r="3.4" fill="{GOLD}" stroke="{INK}" stroke-width="1.8"/>
  <path d="M19 12 Q32 9 50 13 Q47 22 51 30 Q46 33 49 40 L40 34 L33 42 Q31 36 19 38Z" fill="#2a4a8a" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M21 15 Q32 12 46 15" fill="none" stroke="#5a7ac0" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M26 30 L25 20 L29.5 24 L33 18 L36.5 24 L41 20 L40 30Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.9" stroke-linejoin="round"/>
  <circle cx="33" cy="26.5" r="1.4" fill="#c8302a"/>
  <path d="M41 34 L42 37 M30 39 L30.5 41" stroke="{INK}" stroke-width="1.3"/>'''


def _cartographers_chart():
    """A parchment map half unrolled: a dotted route to a red cross, a compass star."""
    return f'''
  <path d="M10 18 Q20 14 32 18 Q44 22 54 18 L54 46 Q44 50 32 46 Q20 42 10 46Z" fill="#e8d6a8" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M10 18 L10 46 Q6 44 6 32 Q6 20 10 18Z" fill="#c8b07a" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M54 18 Q58 20 58 32 Q58 44 54 46" fill="#c8b07a" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M15 26 Q20 22 24 27 Q27 31 23 34 Q18 35 15 31Z" fill="#9ab872" stroke="#5a7a3a" stroke-width="1.2"/>
  <path d="M38 37 Q42 33 47 36 L47 42 Q42 43 38 41Z" fill="#7aa8c8" stroke="#3a6a8a" stroke-width="1.2"/>
  <path d="M18 40 Q24 36 28 38 Q33 40 35 33 Q37 27 43 27" fill="none" stroke="#8a3a2a" stroke-width="1.8" stroke-linecap="round" stroke-dasharray="2 2.6"/>
  <path d="M44 24 L49 29 M49 24 L44 29" stroke="#c8302a" stroke-width="2.6" stroke-linecap="round"/>
  <path d="M32 21 L33 24 L36 25 L33 26 L32 29 L31 26 L28 25 L31 24Z" fill="{GOLD}" stroke="{INK}" stroke-width="1"/>'''


def _toll_charter():
    """A sealed charter: a scroll tied with a cord, a red seal and a gold coin."""
    return f'''
  <path d="M16 12 L44 12 Q48 12 48 16 L48 50 L20 50 Q16 50 16 46Z" fill="#efe0b8" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>
  <path d="M12 12 Q12 7 16 7 L44 7 Q48 7 48 12 Q48 16 44 16 L16 16 Q12 16 12 12Z" fill="#d8c08a" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M22 23 L42 23 M22 28 L42 28 M22 33 L38 33 M22 38 L34 38" stroke="#8a7a5a" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M36 44 Q34 52 30 58 M38 44 Q41 52 44 57" fill="none" stroke="#c8302a" stroke-width="2.2" stroke-linecap="round"/>
  <circle cx="37" cy="44" r="6.5" fill="#b8282a" stroke="{INK}" stroke-width="2.2"/>
  <path d="M34 44 L40 44 M37 41 L37 47" stroke="#e86a5a" stroke-width="1.4"/>
  <circle cx="17" cy="47" r="7" fill="{GOLD}" stroke="{INK}" stroke-width="2.2"/>
  <circle cx="17" cy="47" r="4.5" fill="none" stroke="{GOLD_D}" stroke-width="1.3"/>
  <path d="M17 44.5 L17 49.5" stroke="{GOLD_D}" stroke-width="1.6"/>'''


def _grave_salt():
    """A small clay jar heaped with white salt crystals, a few spilled before it."""
    return f'''
  <path d="M20 30 Q16 42 20 52 Q32 57 44 52 Q48 42 44 30Z" fill="#8a5a3a" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M22 36 Q32 39 42 36" fill="none" stroke="#5e3a22" stroke-width="1.6"/>
  <path d="M28 41 L28 49 M24.5 44 L31.5 44" stroke="#e8e2d6" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M22 50 Q32 54 42 50" fill="none" stroke="#a87250" stroke-width="1.4"/>
  <rect x="17" y="26" width="30" height="6" rx="3" fill="#a06a44" stroke="{INK}" stroke-width="2.3"/>
  <path d="M19 26 L23 18 L26 22 L29 13 L33 20 L36 15 L39 21 L42 17 L45 26Z" fill="#f4f2ec" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M29 15.5 L30.5 20 M36 17 L37 21" stroke="#c8d0d8" stroke-width="1.2"/>
  <path d="M48 50 L51 47 L53 50 L50 53Z M52 54 L54.5 52 L56 54.5 L53.5 56.5Z M10 51 L12.5 49 L14 51.5 L11.5 53.5Z" fill="#f4f2ec" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>''' + _sparkle(48, 18, 2.4, "#ffffff")


def _sun_disc():
    """A golden disc with a sun's face, its rays round it, glowing."""
    return _item_glow("sd", "#ffd860", 27) + _rays(32, 32, 16, 25, 12, INK, 5.4) + _rays(32, 32, 16, 25, 12, "#ffc838", 3) + _rays(32, 32, 15, 21, 12, INK, 3.6, math.pi / 12) + _rays(32, 32, 15, 21, 12, "#ffe890", 1.8, math.pi / 12) + f'''
  <circle cx="32" cy="32" r="14" fill="{GOLD}" stroke="{INK}" stroke-width="2.6"/>
  <circle cx="32" cy="32" r="11" fill="#e8c860" stroke="{GOLD_D}" stroke-width="1.2"/>
  <path d="M26 29 Q27.5 27.5 29 29 M35 29 Q36.5 27.5 38 29" fill="none" stroke="{INK}" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M32 30 L31 34 L33 34" fill="none" stroke="{GOLD_D}" stroke-width="1.3" stroke-linejoin="round"/>
  <path d="M28 37 Q32 40 36 37" fill="none" stroke="{INK}" stroke-width="1.8" stroke-linecap="round"/>'''


def _olive_leaf(x, y, dx, dy):
    return f'''
  <path d="M{x} {y} Q{x + dx * 0.5 - 2} {y + dy * 0.5 - 2} {x + dx} {y + dy} Q{x + dx * 0.5 + 2} {y + dy * 0.5 + 2} {x} {y}Z" fill="#7a9a4a" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>'''


def _peace_ribbon():
    """A white ribbon tied in a bow round an olive sprig."""
    leaves = "".join(_olive_leaf(*a) for a in [(22, 40, -7, 2), (25, 37, -3, -7), (40, 24, 7, -2), (37, 22, 4, -7), (44, 18, 6, -5), (18, 44, -6, 6)])
    return f'''
  <path d="M14 50 Q30 36 50 12" fill="none" stroke="#5a4a2a" stroke-width="2.4" stroke-linecap="round"/>''' + leaves + f'''
  <circle cx="47" cy="15" r="2.6" fill="#4a5a2a" stroke="{INK}" stroke-width="1.2"/>
  <path d="M30 33 Q20 22 14 26 Q12 34 22 37 Q27 37 30 33Z" fill="#f4f0e6" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M34 31 Q44 22 50 27 Q51 35 42 37 Q37 37 34 31Z" fill="#f4f0e6" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="M30 34 Q26 44 20 54 L25 52 L27 56 Q31 46 33 36Z" fill="#f4f0e6" stroke="{INK}" stroke-width="2.1" stroke-linejoin="round"/>
  <path d="M34 34 Q40 44 46 52 L41 51 L40 55 Q35 46 32 37Z" fill="#e4ded0" stroke="{INK}" stroke-width="2.1" stroke-linejoin="round"/>
  <path d="M18 29 Q22 30 26 33 M46 29 Q42 31 38 33" fill="none" stroke="#c8c0b0" stroke-width="1.4"/>
  <ellipse cx="32" cy="33" rx="4" ry="4.4" fill="#f4f0e6" stroke="{INK}" stroke-width="2.2"/>'''


def _stormglass():
    """A teardrop glass with a storm inside: dark cloud, a lightning bolt, waves at its foot."""
    return f'''
  <path d="M32 6 Q36 6 36 10 L36 14 Q50 22 50 36 Q50 52 32 54 Q14 52 14 36 Q14 22 28 14 L28 10 Q28 6 32 6Z" fill="#a8d8f0" fill-opacity="0.35" stroke="{INK}" stroke-width="2.6" stroke-linejoin="round"/>
  <path d="M16.5 42 Q20 39 24 42 Q28 45 32 42 Q36 39 40 42 Q44 45 47.5 42 Q46 51 32 52 Q18 51 16.5 42Z" fill="#2a6a9a" stroke="{INK}" stroke-width="1.6"/>
  <path d="M20 44.5 Q24 42 28 44.5 M36 44.5 Q40 42 44 44.5" fill="none" stroke="#9ad0f0" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M19 30 Q19 23 26 23 Q28 18 34 19 Q40 18 42 23 Q47 24 46 30 Q46 33 42 33 L23 33 Q19 33 19 30Z" fill="#4a4e5e" stroke="{INK}" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M33 33 L29 40 L33 39 L30 47 L37 37 L33 38 L36 33Z" fill="#ffe060" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>
  <path d="M22 22 Q24 17 29 16" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" opacity="0.8"/>
  <rect x="27" y="4" width="10" height="5" rx="1.5" fill="{GOLD}" stroke="{INK}" stroke-width="1.8"/>'''


RELIC_ICONS = {
    "hawkeye": _hawk_head(),
    "phoenix": _phoenix_feather(),
    "hearth": _hearth_stone(),
    "harvest": _harvest_idol(),
    "woodcutters_axe": _woodcutters_axe(),
    "masons_seal": _masons_seal(),
    "tithe_box": _tithe_box(),
    "kings_banner": _kings_banner(),
    "cartographers_chart": _cartographers_chart(),
    "toll_charter": _toll_charter(),
    "grave_salt": _grave_salt(),
    "sun_disc": _sun_disc(),
    "peace_ribbon": _peace_ribbon(),
    "stormglass": _stormglass(),
}


def relic_icons():
    """One per Config.RELICS key; the generator stops if one is missing."""
    with open(os.path.join(ROOT, "scripts", "core", "config.gd")) as f:
        cfg = f.read()
    block = cfg[cfg.index("const RELICS := {"):]
    block = block[:block.index("\n}")]
    keys = re.findall(r'^\t"([a-z_]+)":', block, re.M)
    missing = [k for k in keys if k not in RELIC_ICONS]
    if missing:
        raise SystemExit("relic icons missing for: %s" % ", ".join(missing))
    for relic_id, symbol in RELIC_ICONS.items():
        icon_svg("relic_" + relic_id, _relic_badge(symbol))
