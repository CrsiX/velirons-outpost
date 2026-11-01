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

- **Every enemy kind is one documented entry in `Config.ENEMIES`**; `WAVE_MIX` says who joins from which wave and in what share. Don't put kind stats in scripts. A new kind needs its library entry, its family (`ENEMY_FAMILIES`: a description only, never a number), its holy/poison/damage factors, its art, and a check in enemy_bot.
- **Read every enemy number through `Enemy.stat()`** (`Config.enemy_stat`), never straight from the kind's entry: that is where difficulty scaling and a boss's `power` apply.
- **Difficulty scales strength and loot** (`DIFFICULTY_SCALED`), never cooldowns or ranges. Summoned elementals are not scaled by difficulty.
- **Damage categories.** Resists live in the kind's `resist` (read through `Enemy.damage_factor`); "unholy" kinds and anything raised or undead take extra holy damage and no poison. Keep these in Config so the library's Damage tab stays right. Every enemy blow on one of ours goes through `Enemy.blow` (a poisoner's blow is a `Poison` dose); every blow on a building passes its category (defence classes, `Config.DEFENSE_CLASSES`).
- **What counts for a wave.** Camp guards and wild enemies (wrathwood) don't. Vultures, spider eggs, raised and added-to-wave enemies do. When counting a wave's enemies in tests or code, filter camp guards.
- **Siege.** Ground enemies near a village follow the village's siege field to the cheapest way in and break barriers on the way; kinds that can't siege, flyers, rats and thieves have their own rules (`"entry"`, `"siege"` in the kind's entry). Mounted enemies never break barriers; they ride in through a breach.
- **A held wall loses no hut to ground enemies.** Kinds with `siege` 0 lurk outside until a breach (`Enemy.lurker`, `Config.LURK`) and leave with the wave's other leftovers; nothing on foot gets through intact walls, and an enemy whose road ends short of the village never "reaches the gate" for free. Keep new ways in (and new raised or spawned enemies inside the walls) to that rule.
- **Raids.** An enemy that gets in burns the nearest intact hut, except the kinds whose entry names another outcome (`"raid"`).
- **Water monsters** only join waves where water lets them reach the village (`Aqua.eligibility`); they dive on deep water and some leave again when only they remain (rules in `AQUA`).
- **Faded enemies and immunities.** A faded ghost is untargetable and takes no damage (`Enemy.faded`, `targetable()`), and a unit only targets an enemy its damage category can hurt (`MilitaryUnit.can_face`, `Enemy.hurt_by`). New targeting code (towers, sorties, elementals, the hero, splash) must go through these; villager fear goes through `Enemy.scary()`, and `Siege` skips faded enemies.
- **Holy auras and necromancers.** A High Priest's aura makes a necromancer's cast take longer (when it or the corpse is inside the aura): it slows, never shuts the spell off (`Combat.necro_slow`, `NecromancerBehavior`). Any change to either must keep that link.
- **Raised enemies** (necromancer) are undead, drain away, pay reduced gold and leave no corpse; keep any new "raisable" kind consistent with that.
- Campaign-only enemies (Dread Legion kinds, Legion cavalry, named captains) are used through the scenario's wave queue entries; some are released when they fall and leave no corpse.
- **Co-op replication.** An enemy's dive state and its `fx` (the siren's song ring, the leviathan's water column, the octopus's arms) travel in the enemy's replicated state, and arms are enemies themselves, so they reach clients automatically. A new behaviour visual must go through `fx` or clients won't see it.
- Wolves, riders, mounts: a mounted kind has `"mount"`, `"mount_hp"` and `"rider"`; hits land on the mount until it falls.
- First appearance of a kind per game is logged where the code does so; keep new special kinds consistent.
