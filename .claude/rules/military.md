---
paths:
  - "scripts/units/military_unit.gd"
  - "scripts/units/military/**"
  - "scripts/units/soldier.gd"
  - "scripts/units/earth_elemental.gd"
  - "scripts/buildings/barracks.gd"
  - "scripts/buildings/grove.gd"
  - "scripts/buildings/training_grounds.gd"
  - "scripts/buildings/tower.gd"
  - "tests/military_bot.*"
---

# Military units

Design reasoning: `docs/military-design.md`, `docs/acolyte-design.md`, `docs/hero-design.md`.

- **New player units: ask the user how each one is unlocked before building it.**
- **All numbers come from `Config`** (`MILITARY` curves, `SUMMONS`, `ATTACKS`, upkeep). Every unit runs on its curves only; no hand-set levels.
- **Specialisation rule.** Branching from a level-`BRANCH_MIN_LEVEL` base unit into a level-1 specialisation must never lower HP or DPS (summoners: summons): a specialisation's level 1 is at least as strong as its base unit at the branch level, and its top level is stronger than the base unit's top level (a higher ceiling). In between it may fall a little short. Branching from a higher level may lose stats: that is the player's choice. `military_bot`'s `_spec_rule_breaks` checks both.
- **Damage data stays in Config.** The library's Damage tab (`Library._damage`) is built from it: who deals each category (`ATTACKS`, `SUMMONS` / `HERO` "category", enemies' "attack_category") and who resists it (`resist`). Don't hard-code damage facts in unit scripts. A new category needs a `DAMAGE_INFO` entry (library_bot checks). Every hit is exactly one category.
- Units on towers can't be hurt; outside (walking, barracks sorties) they can. Units leaving a post walk, and only reappear in the reserve once home.
- Summons crumble when their summoner is withdrawn, downed, specialised or back on its bench.
- Buffs and auras follow the "strongest counts, no stacking" principle where the docs say so; keep new ones consistent (`Combat` helpers).
- Military units eat wherever they are; `Scenario.army_upkeep` scales it. The hero and summons never eat.
- Co-op: a sent unit joins the other village's army and can't be recalled.
