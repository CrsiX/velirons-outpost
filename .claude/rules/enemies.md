---
paths:
  - "scripts/units/enemy.gd"
  - "scripts/units/enemies/**"
  - "scripts/systems/waves.gd"
  - "scripts/systems/siege.gd"
  - "scripts/systems/aqua.gd"
  - "scripts/systems/wrathwoods.gd"
  - "scripts/systems/corpses.gd"
  - "tests/enemy_bot.*"
  - "tests/siege_bot.*"
  - "tests/aqua_bot.*"
---

# Enemies, waves, sieges

Design reasoning: `docs/enemies-design.md`, `docs/siege-design.md`, `docs/aquatic-design.md`.

- **Every enemy kind is one documented entry in `Config.ENEMIES`**; `WAVE_MIX` says who joins from which wave and in what share. Don't put kind stats in scripts. A new kind needs its library entry, its holy/damage factors, its art, and a check in enemy_bot.
- **Difficulty scales strength and loot** (`DIFFICULTY_SCALED`), never cooldowns or ranges. Summoned elementals are not scaled by difficulty.
- **Damage categories.** Resists live in the kind's `resist`; "unholy" kinds and anything raised or undead take extra holy damage. Keep these in Config so the library's Damage tab stays right.
- **What counts for a wave.** Camp guards and wild enemies (wrathwood) don't. Vultures, spider eggs, raised and added-to-wave enemies do. When counting a wave's enemies in tests or code, filter camp guards.
- **Siege.** Ground enemies near a village follow the village's siege field to the cheapest way in and break barriers on the way; kinds that can't siege, flyers, rats and thieves have their own rules (`"entry"`, `"siege"` in the kind's entry). Mounted enemies never break barriers; they ride in through a breach.
- **Raids.** An enemy that gets in burns the nearest intact hut, except the kinds whose entry names another outcome (`"raid"`).
- **Water monsters** only join waves where water lets them reach the village (`Aqua.eligibility`); they dive on deep water and some leave again when only they remain (rules in `AQUA`).
- **Raised enemies** (necromancer) are undead, drain away, pay reduced gold and leave no corpse; keep any new "raisable" kind consistent with that.
- Campaign-only enemies (Dread Legion kinds, Legion cavalry, named captains) are used through the scenario's wave queue entries; some are released when they fall and leave no corpse.
- Wolves, riders, mounts: a mounted kind has `"mount"`, `"mount_hp"` and `"rider"`; hits land on the mount until it falls.
- First appearance of a kind per game is logged where the code does so; keep new special kinds consistent.
