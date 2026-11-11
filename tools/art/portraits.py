"""The cutscenes' dialogue portraits: portrait_svg and the portraits* functions."""

import os

from .core import ART, CRIMSON, GLOW, GOLD, GOLD_D, INK, WOOD_L


def portrait_svg(name, body, bg="#2a3240"):
    """A dialogue portrait (cutscenes): a bust in a round-cornered frame, 64x64 units."""
    with open(os.path.join(ART, name + ".svg"), "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 64 64">\n'
                '  <clipPath id="c"><rect x="3" y="3" width="58" height="58" rx="6"/></clipPath>\n'
                '  <rect x="1.5" y="1.5" width="61" height="61" rx="7" fill="%s" stroke="%s" stroke-width="3"/>\n'
                '  <g clip-path="url(#c)">%s\n  </g>\n'
                '  <rect x="3" y="3" width="58" height="58" rx="6" fill="none" stroke="%s" stroke-width="1.6"/>\n'
                '</svg>\n' % (bg, INK, body, GOLD_D))


def portraits():
    """The speakers of the scenarios' cutscenes (docs/story-design.md section 2)."""
    # Brenna Hale: a royal knight come home; dark hair tied back, a scar, a worn
    # blue-steel cuirass with a crimson cloak.
    portrait_svg("portrait_brenna", f'''
  <path d="M6 66 Q6 46 20 42 L44 42 Q58 46 58 66Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 66 Q14 48 24 45 L40 45 Q50 48 50 66Z" fill="#6a7a8e" stroke="{INK}" stroke-width="2.2"/>
  <path d="M32 46 L32 66" stroke="#4a5666" stroke-width="1.6"/>
  <path d="M16 50 Q12 44 20 42 L24 46 Z" fill="#8a96a6" stroke="{INK}" stroke-width="1.6"/>
  <path d="M48 50 Q52 44 44 42 L40 46 Z" fill="#8a96a6" stroke="{INK}" stroke-width="1.6"/>
  <rect x="27" y="35" width="10" height="9" fill="#c9a07c" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 24 Q19 10 32 9 Q45 10 44 24 Q44 36 32 39 Q20 36 20 24Z" fill="#d6ad86" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 25 Q16 8 32 6 Q48 7 45 24 Q44 15 36 13 Q28 15 21 14 Q20 19 19 25Z" fill="#3a2a20" stroke="{INK}" stroke-width="2"/>
  <path d="M44 16 Q52 22 49 34 Q47 28 44 26Z" fill="#3a2a20" stroke="{INK}" stroke-width="1.8"/>
  <circle cx="49" cy="25" r="1.6" fill="{CRIMSON}"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#2a1e16" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.5" fill="{INK}"/><circle cx="37" cy="26" r="1.5" fill="{INK}"/>
  <path d="M31.5 27 L30.5 31 L33 31" fill="none" stroke="#9a7458" stroke-width="1.2"/>
  <path d="M28.5 34 Q32 35.4 35.5 34" fill="none" stroke="#7a4a3a" stroke-width="1.4" stroke-linecap="round"/>
  <path d="M39 20 L42 29" stroke="#b07a6a" stroke-width="1.1"/>''', bg="#28323e")
    # Einar: Brenna's father, the village's lumberjack; grey beard, green cap,
    # red check shirt, the axe haft over his shoulder.
    portrait_svg("portrait_einar", f'''
  <path d="M50 66 L60 8" stroke="{INK}" stroke-width="5"/>
  <path d="M50 66 L60 8" stroke="{WOOD_L}" stroke-width="3"/>
  <path d="M54 8 L66 6 L66 18 L57 16Z" fill="#9a9a9a" stroke="{INK}" stroke-width="1.8"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#7a3a2a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 50 L50 50 M12 57 L52 57 M24 44 L22 66 M40 44 L42 66" stroke="#5a2a1e" stroke-width="1.6"/>
  <rect x="27" y="35" width="10" height="9" fill="#c99a78" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 24 Q19 11 32 10 Q45 11 44 24 Q44 35 32 38 Q20 35 20 24Z" fill="#d0a07c" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 26 Q21 44 32 46 Q43 44 44 26 Q40 32 32 32 Q24 32 20 26Z" fill="#b8b2a6" stroke="{INK}" stroke-width="2"/>
  <path d="M27 31 Q32 29 37 31" fill="none" stroke="#8a847a" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M17 18 Q18 5 32 5 Q46 5 47 18Z" fill="#3a4a2a" stroke="{INK}" stroke-width="2.2"/>
  <path d="M15 18 L49 18" stroke="{INK}" stroke-width="3"/>
  <path d="M24 22 L29 23 M35 23 L40 22" stroke="#9a948a" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="27" cy="25.5" r="1.4" fill="{INK}"/><circle cx="37" cy="25.5" r="1.4" fill="{INK}"/>
  <path d="M24 28 Q27 29 29 28 M35 28 Q37 29 40 28" fill="none" stroke="#a87858" stroke-width="0.9"/>''', bg="#2c3428")
    # Pell Dunmore: a travelling merchant; a wide-brimmed hat, a brown coat with
    # a gold-trimmed collar, a short beard and a lantern's warm light.
    portrait_svg("portrait_pell", f'''
  <circle cx="54" cy="44" r="16" fill="{GLOW}" opacity="0.25"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#5a4630" stroke="{INK}" stroke-width="2.4"/>
  <path d="M22 43 L32 56 L42 43" fill="none" stroke="{GOLD}" stroke-width="2.4"/>
  <path d="M32 56 L32 66" stroke="#3a2c1e" stroke-width="1.6"/>
  <circle cx="32" cy="60" r="1.4" fill="{GOLD}"/>
  <rect x="27" y="35" width="10" height="9" fill="#c99a78" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#cfa07c" stroke="{INK}" stroke-width="2.2"/>
  <path d="M22 29 Q24 39 32 40 Q40 39 42 29 Q38 34 32 34 Q26 34 22 29Z" fill="#6a4a30" stroke="{INK}" stroke-width="1.6"/>
  <path d="M27 31.5 Q32 30 37 31.5" fill="none" stroke="#4a3220" stroke-width="2" stroke-linecap="round"/>
  <path d="M8 18 Q32 10 56 18 Q44 21 32 21 Q20 21 8 18Z" fill="#3a2e22" stroke="{INK}" stroke-width="2"/>
  <path d="M20 17 Q21 4 32 4 Q43 4 44 17Z" fill="#4a3a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M20.5 14 L43.5 14" stroke="{CRIMSON}" stroke-width="2.4"/>
  <circle cx="27" cy="25.5" r="1.4" fill="{INK}"/><circle cx="37" cy="25.5" r="1.4" fill="{INK}"/>
  <path d="M24 22.5 L29 22 M35 22 L40 22.5" stroke="#3a2a1a" stroke-width="1.5" stroke-linecap="round"/>
  <path d="M50 46 L58 46 L57 58 L51 58Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.6" opacity="0.95"/>
  <circle cx="54" cy="52" r="2.6" fill="#fff4c0"/>''', bg="#33291f")


def portraits_away():
    """The speakers of scenarios 4 and 5 (docs/story-design.md section 2)."""
    # Wenna: the Silver Thread Guild's master; grey hair in a bun, a dark-blue coat,
    # a gold chain of office, a sharp look over half-moon spectacles.
    portrait_svg("portrait_wenna", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#2f3e5a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M20 46 Q32 58 44 46" fill="none" stroke="{GOLD}" stroke-width="2.4"/>
  <circle cx="32" cy="55" r="3" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>
  <rect x="27" y="35" width="10" height="9" fill="#d0a684" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#d8ae8a" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 26 Q16 9 32 8 Q48 9 45 26 Q44 16 32 15 Q22 16 19 26Z" fill="#9a958c" stroke="{INK}" stroke-width="2"/>
  <circle cx="32" cy="7" r="6" fill="#9a958c" stroke="{INK}" stroke-width="2"/>
  <path d="M23 26 Q27 24 30 26 M34 26 Q37 24 41 26" fill="none" stroke="#8a6a40" stroke-width="1.6"/>
  <path d="M23 27 L30 27 M34 27 L41 27" stroke="{GOLD_D}" stroke-width="1"/>
  <circle cx="27" cy="25.5" r="1.3" fill="{INK}"/><circle cx="37" cy="25.5" r="1.3" fill="{INK}"/>
  <path d="M28.5 33.5 Q32 33 35.5 33.5" fill="none" stroke="#7a4a3a" stroke-width="1.4" stroke-linecap="round"/>""", bg="#262f3c")
    # Sigmund: the old veteran at Brenna's fort; bald, a white beard, a patch
    # over one eye, worn mail under a brown jerkin.
    portrait_svg("portrait_sigmund", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#7a7e86" stroke="{INK}" stroke-width="2.4"/>
  <path d="M12 52 L52 52 M10 58 L54 58 M14 47 L50 47" stroke="#5a5e66" stroke-width="1.4" stroke-dasharray="2 2"/>
  <path d="M20 66 L22 46 L42 46 L44 66Z" fill="#5a4630" stroke="{INK}" stroke-width="2"/>
  <rect x="27" y="35" width="10" height="9" fill="#c49474" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 23 Q19 9 32 9 Q45 9 44 23 Q44 35 32 38 Q20 35 20 23Z" fill="#cc9c78" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 25 Q20 45 32 48 Q44 45 44 25 Q40 32 32 32 Q24 32 20 25Z" fill="#e8e4dc" stroke="{INK}" stroke-width="2"/>
  <path d="M26 31 Q32 29 38 31" fill="none" stroke="#c8c4bc" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M19 19 L45 27" stroke="{INK}" stroke-width="1.8"/>
  <ellipse cx="37" cy="24.5" rx="4" ry="3.4" fill="#2a221c" stroke="{INK}" stroke-width="1.4"/>
  <circle cx="27" cy="25" r="1.4" fill="{INK}"/>
  <path d="M24 21.5 L29 21" stroke="#e8e4dc" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M23 14 Q26 12 29 14" fill="none" stroke="#b0805e" stroke-width="1"/>""", bg="#2e2a26")
    # Lysa: Brenna's old captain, bound to Rhodri; a pale face, empty pale
    # eyes, a captain's helm with a crimson plume, a dark-red braid.
    portrait_svg("portrait_lysa", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#2a2a30" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 66 Q14 48 24 45 L40 45 Q50 48 50 66Z" fill="#5a4448" stroke="{INK}" stroke-width="2.2"/>
  <path d="M18 50 L46 50" stroke="{GOLD_D}" stroke-width="2"/>
  <path d="M18 30 Q10 40 14 56 Q18 46 21 36Z" fill="#6a2a20" stroke="{INK}" stroke-width="1.8"/>
  <rect x="27" y="35" width="10" height="9" fill="#bcc0c4" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#c8cccf" stroke="{INK}" stroke-width="2.2"/>
  <path d="M18 24 Q17 6 32 5 Q47 6 46 24 L42 24 L42 18 Q32 15 22 18 L22 24Z" fill="#8a8e96" stroke="{INK}" stroke-width="2.2"/>
  <path d="M31 18 L31 27 L33 27 L33 18Z" fill="#6a6e76" stroke="{INK}" stroke-width="1.2"/>
  <path d="M38 7 Q50 2 58 14 Q52 10 44 12Z" fill="{CRIMSON}" stroke="{INK}" stroke-width="1.8"/>
  <ellipse cx="27" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <ellipse cx="37" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <path d="M28.5 33.5 L35.5 33.5" stroke="#7a7e86" stroke-width="1.4" stroke-linecap="round"/>""", bg="#22242a")
    # A rival guild's master: a fur collar, a heavy gold ring, a trimmed beard
    # and a smile that doesn't reach the eyes.
    portrait_svg("portrait_rival", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#4a2a3a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 50 Q20 40 32 46 Q44 40 54 50 Q50 56 44 52 Q38 56 32 52 Q26 56 20 52 Q14 56 10 50Z" fill="#8a7458" stroke="{INK}" stroke-width="1.8"/>
  <rect x="27" y="35" width="10" height="9" fill="#d0a080" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#d8a882" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 22 Q17 7 32 7 Q47 7 45 22 Q42 13 32 13 Q22 13 19 22Z" fill="#1e1a18" stroke="{INK}" stroke-width="2"/>
  <path d="M26 33 Q32 41 38 33 Q35 38 32 38 Q29 38 26 33Z" fill="#1e1a18" stroke="{INK}" stroke-width="1.4"/>
  <path d="M26 31 Q32 33.5 38 31" fill="none" stroke="#6a3a2a" stroke-width="1.6" stroke-linecap="round"/>
  <path d="M24 23 L29 24 M35 24 L40 23" stroke="#1e1a18" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.4" fill="{INK}"/><circle cx="37" cy="26" r="1.4" fill="{INK}"/>
  <circle cx="50" cy="60" r="3.2" fill="{GOLD}" stroke="{INK}" stroke-width="1.4"/>""", bg="#2e2230")


def portraits_67():
    """The speakers of scenarios 6 and 7 (docs/story-design.md section 2)."""
    # Anselm: the battlefield's old priest; a grey fringe round a bald crown,
    # a black cassock, a white collar, tired kind eyes, dust on his cheek.
    portrait_svg("portrait_anselm", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#26242a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M26 43 L32 48 L38 43" fill="#f0ece0" stroke="{INK}" stroke-width="1.6"/>
  <path d="M32 50 L32 62 M27 55 L37 55" stroke="{GOLD}" stroke-width="2"/>
  <rect x="27" y="35" width="10" height="9" fill="#c89c7c" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 11 32 10 Q45 11 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#d4a888" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 27 Q16 16 22 14 Q20 20 21 27Z M45 27 Q48 16 42 14 Q44 20 43 27Z" fill="#b8b4ac" stroke="{INK}" stroke-width="1.6"/>
  <path d="M24 23 Q27 21.5 29 23 M35 23 Q37 21.5 40 23" fill="none" stroke="#9a948a" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.3" fill="{INK}"/><circle cx="37" cy="26" r="1.3" fill="{INK}"/>
  <path d="M24 28.5 Q27 30 29 28.5 M35 28.5 Q37 30 40 28.5" fill="none" stroke="#a87858" stroke-width="0.9"/>
  <path d="M28.5 34 Q32 35 35.5 34" fill="none" stroke="#7a4a3a" stroke-width="1.4" stroke-linecap="round"/>
  <ellipse cx="40" cy="31" rx="2.6" ry="1.4" fill="#8a7a62" opacity="0.6"/>""", bg="#2a2824")
    # Fiona: the old king's daughter; red-gold hair, a thin silver circlet, a
    # deep-blue gown with a silver collar, a level, measuring look.
    portrait_svg("portrait_fiona", f"""
  <path d="M20 24 Q10 40 14 58 L23 52 Q19 40 22 30Z" fill="#b0582a" stroke="{INK}" stroke-width="2"/>
  <path d="M44 24 Q54 40 50 58 L41 52 Q45 40 42 30Z" fill="#b0582a" stroke="{INK}" stroke-width="2"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#243a6a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M20 44 Q32 54 44 44" fill="none" stroke="#c8ccd8" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#dcb898" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#e4c0a0" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 27 Q15 8 32 7 Q49 8 45 27 Q44 16 36 14 Q30 18 21 17 Q20 22 19 27Z" fill="#b0582a" stroke="{INK}" stroke-width="2"/>
  <path d="M20 15 Q32 10 44 15" fill="none" stroke="#d8dce8" stroke-width="2"/>
  <circle cx="32" cy="12" r="1.8" fill="#7ab0ff" stroke="{INK}" stroke-width="0.8"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#7a3a1a" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.4" fill="#2a3a5a"/><circle cx="37" cy="26" r="1.4" fill="#2a3a5a"/>
  <path d="M28.5 33.5 L35.5 33.5" stroke="#9a5a4a" stroke-width="1.4" stroke-linecap="round"/>""", bg="#1e2638")
    # The druids' elder: a long white beard, a wreath of oak leaves, a hood of
    # undyed wool over a moss-green robe.
    portrait_svg("portrait_elder", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#3e5a2c" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 40 Q8 8 32 4 Q56 8 54 40 L46 40 Q46 16 32 14 Q18 16 18 40Z" fill="#6a5a40" stroke="{INK}" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#c49474" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#cc9c78" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 27 Q18 56 32 62 Q46 56 44 27 Q40 34 32 34 Q24 34 20 27Z" fill="#ece8e0" stroke="{INK}" stroke-width="2"/>
  <path d="M26 32 Q32 30 38 32" fill="none" stroke="#c8c4bc" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M19 17 Q32 11 45 17" fill="none" stroke="#4a7a32" stroke-width="3.2"/>
  <ellipse cx="22" cy="16" rx="3" ry="2" fill="#6aa84a" stroke="{INK}" stroke-width="0.9"/>
  <ellipse cx="32" cy="12.5" rx="3" ry="2" fill="#6aa84a" stroke="{INK}" stroke-width="0.9"/>
  <ellipse cx="42" cy="16" rx="3" ry="2" fill="#6aa84a" stroke="{INK}" stroke-width="0.9"/>
  <path d="M24 22.5 L29 22 M35 22 L40 22.5" stroke="#e8e4dc" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="27" cy="25.5" r="1.4" fill="{INK}"/><circle cx="37" cy="25.5" r="1.4" fill="{INK}"/>""", bg="#22301e")
    # Idris, a court mage: a dark face, a silver-shot short beard, a deep
    # violet hood with silver stars.
    portrait_svg("portrait_mage", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#3a2a5a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 42 Q8 8 32 5 Q56 8 54 42 L46 42 Q46 16 32 15 Q18 16 18 42Z" fill="#2c2048" stroke="{INK}" stroke-width="2.2"/>
  <circle cx="14" cy="30" r="1" fill="#d8dce8"/><circle cx="50" cy="24" r="1" fill="#d8dce8"/><circle cx="20" cy="12" r="0.9" fill="#d8dce8"/>
  <rect x="27" y="35" width="10" height="9" fill="#7a5038" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#8a5c40" stroke="{INK}" stroke-width="2.2"/>
  <path d="M22 30 Q24 41 32 42 Q40 41 42 30 Q38 35 32 35 Q26 35 22 30Z" fill="#4a4448" stroke="{INK}" stroke-width="1.6"/>
  <path d="M27 38 L29 40 M35 38 L33 40" stroke="#b8b4b0" stroke-width="1"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#1e1a18" stroke-width="1.6" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.4" fill="{INK}"/><circle cx="37" cy="26" r="1.4" fill="{INK}"/>
  <path d="M28.5 32.5 Q32 33.4 35.5 32.5" fill="none" stroke="#4a2a1e" stroke-width="1.4" stroke-linecap="round"/>""", bg="#221c30")


def portraits_89():
    """The speakers of scenarios 8 and 9 (docs/story-design.md section 2)."""
    # Lothar, the court's herald: a long pale face, a neat silver beard, a
    # feathered cap, a pale tabard with a gold crown; courteous, cold.
    portrait_svg("portrait_lothar", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#d8d6de" stroke="{INK}" stroke-width="2.4"/>
  <path d="M27 52 L30 48 L32 51 L34 48 L37 52 L37 56 L27 56Z" fill="{GOLD}" stroke="{INK}" stroke-width="1.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#d8ccc4" stroke="{INK}" stroke-width="1.8"/>
  <path d="M21 24 Q20 11 32 10 Q44 11 43 24 Q43 37 32 40 Q21 37 21 24Z" fill="#e2d6ce" stroke="{INK}" stroke-width="2.2"/>
  <path d="M24 31 Q25 42 32 43 Q39 42 40 31 Q37 36 32 36 Q27 36 24 31Z" fill="#c8c8cc" stroke="{INK}" stroke-width="1.6"/>
  <path d="M15 17 Q18 5 32 5 Q46 5 48 17Z" fill="#5a5470" stroke="{INK}" stroke-width="2"/>
  <path d="M40 9 Q52 0 60 8 Q52 8 46 14Z" fill="#eceae4" stroke="{INK}" stroke-width="1.6"/>
  <path d="M24 22.5 L29 22 M35 22 L40 22.5" stroke="#9a9894" stroke-width="1.5" stroke-linecap="round"/>
  <circle cx="27" cy="25.5" r="1.3" fill="{INK}"/><circle cx="37" cy="25.5" r="1.3" fill="{INK}"/>
  <path d="M28.5 33 Q32 34 35.5 33" fill="none" stroke="#8a6a6a" stroke-width="1.3" stroke-linecap="round"/>""", bg="#2a2836")
    # Rurik, the court's champion: a pale square face, a scar over the brow,
    # empty pale eyes, a white plume over a pale steel helm, broad pauldrons.
    portrait_svg("portrait_rurik", f"""
  <path d="M2 66 Q2 44 18 40 L46 40 Q62 44 62 66Z" fill="#b8bcc4" stroke="{INK}" stroke-width="2.4"/>
  <ellipse cx="12" cy="46" rx="10" ry="7" fill="#c8ccd4" stroke="{INK}" stroke-width="2"/>
  <ellipse cx="52" cy="46" rx="10" ry="7" fill="#a8acb4" stroke="{INK}" stroke-width="2"/>
  <rect x="26" y="34" width="12" height="9" fill="#bcc0c4" stroke="{INK}" stroke-width="1.8"/>
  <path d="M19 24 Q18 12 32 11 Q46 12 45 24 Q45 37 32 40 Q19 37 19 24Z" fill="#c8cccf" stroke="{INK}" stroke-width="2.2"/>
  <path d="M17 24 Q16 5 32 4 Q48 5 47 24 L43 24 L43 17 Q32 14 21 17 L21 24Z" fill="#b8bcc4" stroke="{INK}" stroke-width="2.2"/>
  <path d="M31 17 L31 27 L33 27 L33 17Z" fill="#8a8e96" stroke="{INK}" stroke-width="1.2"/>
  <path d="M36 6 Q48 -2 60 10 Q50 6 42 10Z" fill="#eceef2" stroke="{INK}" stroke-width="1.8"/>
  <ellipse cx="27" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <ellipse cx="37" cy="25.5" rx="2" ry="1.4" fill="#e4ecf8" stroke="#8a9aaa" stroke-width="0.8"/>
  <path d="M38 19 L42 27" stroke="#9a8a8a" stroke-width="1.2"/>
  <path d="M27.5 33.5 L36.5 33.5" stroke="#7a7e86" stroke-width="1.6" stroke-linecap="round"/>""", bg="#22242a")
    # Rhodri: the king, paler than anyone, the old king's crown reworked and
    # glowing cold over dark hair, a high collar, a thin smile.
    portrait_svg("portrait_rhodri", f"""
  <circle cx="32" cy="10" r="20" fill="#b8d0ff" opacity="0.18"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#1e1a2a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M18 44 L24 36 L32 46 L40 36 L46 44" fill="#3a3450" stroke="{INK}" stroke-width="1.8"/>
  <rect x="27" y="35" width="10" height="9" fill="#d4d8e0" stroke="{INK}" stroke-width="1.8"/>
  <path d="M20 25 Q19 13 32 12 Q45 13 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#e0e4ec" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 27 Q16 12 32 11 Q48 12 45 27 Q44 19 39 17 Q32 18 25 17 Q20 20 19 27Z" fill="#2a2430" stroke="{INK}" stroke-width="2"/>
  <path d="M19 15 L21 4 L26 10 L32 2 L38 10 L43 4 L45 15Z" fill="#c8d8f0" stroke="{INK}" stroke-width="1.8"/>
  <circle cx="32" cy="10" r="2" fill="#eaf4ff" stroke="{INK}" stroke-width="0.8"/>
  <circle cx="24" cy="12" r="1.2" fill="#9ac0ff"/><circle cx="40" cy="12" r="1.2" fill="#9ac0ff"/>
  <path d="M24 22.5 L29 23 M35 23 L40 22.5" stroke="#3a3440" stroke-width="1.5" stroke-linecap="round"/>
  <ellipse cx="27" cy="25.8" rx="1.7" ry="1.2" fill="#b8d0ff" stroke="{INK}" stroke-width="0.6"/>
  <ellipse cx="37" cy="25.8" rx="1.7" ry="1.2" fill="#b8d0ff" stroke="{INK}" stroke-width="0.6"/>
  <path d="M28 33 Q32 35 37 32.5" fill="none" stroke="#8a7a8a" stroke-width="1.3" stroke-linecap="round"/>""", bg="#16141e")
    # A priest of the church, a survivor in the capital: a young, thin face, a
    # brown habit with its hood down, a wooden cross on a cord.
    portrait_svg("portrait_church_priest", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#6a5238" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 46 Q32 38 50 46 Q44 50 32 50 Q20 50 14 46Z" fill="#5a4430" stroke="{INK}" stroke-width="1.6"/>
  <path d="M28 44 L32 52 L36 44" fill="none" stroke="#3a2a1a" stroke-width="1"/>
  <path d="M32 52 L32 61 M28.5 55 L35.5 55" stroke="{WOOD_L}" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="8" fill="#d0a684" stroke="{INK}" stroke-width="1.8"/>
  <path d="M21 25 Q20 12 32 11 Q44 12 43 25 Q43 36 32 39 Q21 36 21 25Z" fill="#dab08e" stroke="{INK}" stroke-width="2.2"/>
  <path d="M20 22 Q19 9 32 8 Q45 9 44 22 Q40 14 32 14 Q24 14 20 22Z" fill="#5a3e28" stroke="{INK}" stroke-width="2"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#4a3220" stroke-width="1.4" stroke-linecap="round"/>
  <circle cx="27" cy="26" r="1.3" fill="{INK}"/><circle cx="37" cy="26" r="1.3" fill="{INK}"/>
  <path d="M29 33.5 Q32 34.5 35 33.5" fill="none" stroke="#8a5a4a" stroke-width="1.3" stroke-linecap="round"/>""", bg="#2a241c")
    # The eldest priest of the drowned shore: a deeply lined
    # face, a white wimple under a dark-blue veil, wary eyes.
    portrait_svg("portrait_eldest_priest", f"""
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#26324a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M10 44 Q8 6 32 4 Q56 6 54 44 L46 44 Q46 16 32 15 Q18 16 18 44Z" fill="#26324a" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 40 Q18 16 32 15 Q46 16 45 40 Q40 44 32 44 Q24 44 19 40Z" fill="#f0ece2" stroke="{INK}" stroke-width="1.8"/>
  <path d="M22 26 Q21 15 32 15 Q43 15 42 26 Q42 36 32 38 Q22 36 22 26Z" fill="#d6ae8e" stroke="{INK}" stroke-width="2"/>
  <path d="M25 30 Q27 31 29 30 M35 30 Q37 31 39 30 M27 35 Q32 36.5 37 35" fill="none" stroke="#a87858" stroke-width="0.9"/>
  <path d="M25 24 L29.5 24.5 M34.5 24.5 L39 24" stroke="#8a7a6a" stroke-width="1.4" stroke-linecap="round"/>
  <circle cx="27.5" cy="27" r="1.3" fill="{INK}"/><circle cx="36.5" cy="27" r="1.3" fill="{INK}"/>
  <path d="M29 33 L35 33" stroke="#8a5a4a" stroke-width="1.3" stroke-linecap="round"/>
  <path d="M32 50 L32 60 M28 54 L36 54" stroke="{GOLD}" stroke-width="2"/>""", bg="#1e2432")


def portraits_1011():
    """The speakers of scenarios 10 and 11."""
    # Halvard, the Legion's marshal: an old soldier's square, weathered face,
    # cropped grey hair and beard, a scar across the cheek, pale eyes under
    # heavy brows, dark plate with a gold-trimmed collar.
    portrait_svg("portrait_halvard", f"""
  <path d="M2 66 Q2 44 18 40 L46 40 Q62 44 62 66Z" fill="#5e626c" stroke="{INK}" stroke-width="2.4"/>
  <path d="M14 44 L32 52 L50 44" fill="none" stroke="{GOLD}" stroke-width="2.4"/>
  <ellipse cx="12" cy="47" rx="10" ry="7" fill="#6e727c" stroke="{INK}" stroke-width="2"/>
  <ellipse cx="52" cy="47" rx="10" ry="7" fill="#5a5e68" stroke="{INK}" stroke-width="2"/>
  <rect x="26" y="34" width="12" height="9" fill="#c0bcb8" stroke="{INK}" stroke-width="1.8"/>
  <path d="M19 24 Q18 11 32 10 Q46 11 45 24 Q45 37 32 40 Q19 37 19 24Z" fill="#cac4be" stroke="{INK}" stroke-width="2.2"/>
  <path d="M19 21 Q18 8 32 7 Q46 8 45 21 Q41 13 32 13 Q23 13 19 21Z" fill="#8e8c8a" stroke="{INK}" stroke-width="2"/>
  <path d="M21 29 Q22 41 32 42 Q42 41 43 29 Q39 35 32 35 Q25 35 21 29Z" fill="#9a9896" stroke="{INK}" stroke-width="1.6"/>
  <path d="M23 21.5 L29.5 22.5 M34.5 22.5 L41 21.5" stroke="#6a6866" stroke-width="2.2" stroke-linecap="round"/>
  <ellipse cx="27" cy="25.5" rx="1.8" ry="1.2" fill="#dce6f2" stroke="#7a8a9a" stroke-width="0.7"/>
  <ellipse cx="37" cy="25.5" rx="1.8" ry="1.2" fill="#dce6f2" stroke="#7a8a9a" stroke-width="0.7"/>
  <path d="M39 27 L44 33" stroke="#a07a72" stroke-width="1.3"/>
  <path d="M28 33 L36 33" stroke="#6a5a56" stroke-width="1.5" stroke-linecap="round"/>""", bg="#22242a")
    # Fiona at the end: as in scenario 7, but pale, the curse in her veins,
    # her eyes gone black.
    portrait_svg("portrait_fiona_cursed", f"""
  <circle cx="32" cy="28" r="26" fill="#2a0e2e" opacity="0.5"/>
  <path d="M20 24 Q10 40 14 58 L23 52 Q19 40 22 30Z" fill="#8a4a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M44 24 Q54 40 50 58 L41 52 Q45 40 42 30Z" fill="#8a4a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M6 66 Q6 46 20 43 L44 43 Q58 46 58 66Z" fill="#243a6a" stroke="{INK}" stroke-width="2.4"/>
  <path d="M20 44 Q32 54 44 44" fill="none" stroke="#c8ccd8" stroke-width="2.2"/>
  <rect x="27" y="35" width="10" height="9" fill="#cfc2ba" stroke="{INK}" stroke-width="1.8"/>
  <path d="M28 37 Q30 41 29 44 M35 36 Q34 40 36 44" fill="none" stroke="#4a1e4e" stroke-width="1.2"/>
  <path d="M20 25 Q19 12 32 11 Q45 12 44 25 Q44 36 32 39 Q20 36 20 25Z" fill="#dcd0ca" stroke="{INK}" stroke-width="2.2"/>
  <path d="M21 30 Q24 27 23 33 M43 29 Q40 28 41 34 M30 36 Q32 33 34 36" fill="none" stroke="#4a1e4e" stroke-width="1.1"/>
  <path d="M19 27 Q15 8 32 7 Q49 8 45 27 Q44 16 36 14 Q30 18 21 17 Q20 22 19 27Z" fill="#8a4a2a" stroke="{INK}" stroke-width="2"/>
  <path d="M20 15 Q32 10 44 15" fill="none" stroke="#d8dce8" stroke-width="2"/>
  <path d="M24 23 L29 22.5 M35 22.5 L40 23" stroke="#5a2a1a" stroke-width="1.5" stroke-linecap="round"/>
  <ellipse cx="27" cy="26" rx="2.4" ry="1.8" fill="#050306"/><ellipse cx="37" cy="26" rx="2.4" ry="1.8" fill="#050306"/>
  <path d="M28.5 33.5 L35.5 33.5" stroke="#6a3a4a" stroke-width="1.4" stroke-linecap="round"/>""", bg="#140a16")
