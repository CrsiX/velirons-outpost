---
paths:
  - "scripts/systems/village.gd"
  - "scripts/systems/economy.gd"
  - "scripts/systems/population.gd"
  - "scripts/systems/construction.gd"
  - "scripts/systems/commands.gd"
  - "scripts/units/civilian.gd"
  - "scripts/units/hero.gd"
  - "scripts/units/jobs/**"
  - "scripts/buildings/**"
  - "tests/sim_bot.*"
  - "tests/rat_bot.*"
---

# Village, civilians, hero, buildings

Design reasoning: `docs/village-design.md`, `docs/hero-design.md`, `docs/siege-design.md`.

- **Every player action is a checked command** (`Commands`, plain arguments), so it works for co-op clients too. New actions need a command, not a direct call from the UI. Debug actions are commands as well and are refused on release builds.
- **Economy.** Anything that adds or spends passes a source / purpose (statistics count through `Economy.earned` / `spent`). All prices and rates are in `Config`.
- **Buildings.** A finished building may be devastated: use `working()` for "does its job". Building HP never heals by itself; repair is a command costing material. Tear-down, cancel and repair refund rules are in `Building` (`cancel_refund`, tear-down refund); keep new building kinds going through them.
- **Build queue** (`Construction.claim`, `Config.BUILD_QUEUE`): builders and the hero in Build mode pick the best job by bucket, then started jobs, then nearest, with age as the tiebreaker. New job kinds need a bucket.
- **Civilians.** Roles that work at a building (`works_at` in `CIVILIANS`) are assigned automatically. Everyone flees home from enemies outside the walls; explorers and the hero exploring flee away instead (`FLEE`). Inside the walls is safe until `Siege.breached`.
- **Hero** (`HERO` in Config): modes Defend, Build, Explore, Gather, Train, Rest, Support (co-op); an ordered camp attack overrides any mode. Mode changes take effect at once and never reset her sword's cooldown. She levels only by spending her own XP; no other unit gains XP. Downed: loses XP, never levels, revives when the wave is over (scenarios may disable that).
- **Unit-unlock sites, ruined watchtowers, treasures, monster camps/lairs, mines** are map objects (`scripts/world/objects/`), hidden in the fog until found; the hero's Explore mode handles them in a fixed priority.
- **Hunger and starvation** are driven by `Population.starving`; military units suffer a penalty, villagers starve in a fixed interval, named ones last.
- **Defeat:** no civilians or no intact huts. In co-op a village falls and may stand again; the game is lost when all have fallen.
- Villagers living in huts: a hut caps the population; raids kill only the villager whose hut burns.
