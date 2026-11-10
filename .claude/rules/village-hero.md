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
- **Build queue** (`Construction.claim`, `Config.BUILD_QUEUE`): builders and the hero in Build mode pick the best job by bucket, then started jobs, then nearest, with age as the tiebreaker. New job kinds need a bucket. Several builders may work one site, its builder crew (`Building.builder_crew`, never a single "builder" field); a site with builders is joined only if `Construction.worth_joining`, except the last stand's repair.
- **Civilians.** Roles that work at a building (`works_at` in `CIVILIANS`) are assigned automatically. Everyone flees home from enemies outside the walls; explorers and the hero exploring flee away instead (`FLEE`). Inside the walls is safe until `Siege.breached`.
- **Hero** (`HERO` in Config): modes Defend, Build, Explore, Gather, Train, Rest, Support (co-op); an ordered camp attack overrides any mode. Mode changes take effect at once and never reset her sword's cooldown. She levels only by spending her own XP; no other unit gains XP. Downed: loses XP, never levels, revives when the wave is over (scenarios may disable that).
- **Hero equipment** (`docs/items-design.md`; `Config.ITEMS`, `Armoury` per village): four slots, an empty slot is its default (today's hero). Effects are modifiers read through `Hero.eq` / `eq_flag` / `eq_resist` / `eq_block`, multiplied across slots; what she can fight and how far she reaches goes through `weapon_category`, `can_hit`, `reach_to`, `reaches_flyers`, never `Config.HERO` directly. `Unit.immovable` (heavy boots) and `drown_proof` (feather boots) are the hooks for anything that moves, holds or drowns units; feather boots walk `Pathing.free_path`. Swaps are commands, only per `Hero.swap_error` (inside the hall counts as at her post). An item's cooldown or per-wave charge is saved (the hero's `"eqt"` in `SaveGame`), unlike other cooldowns. Off where `Game.items_enabled` is false.
- **Where items come from** (`ItemDrops`, `Config.ITEM_SOURCES`; items-design §5): every source picks through `ItemDrops.random_item` (the scenario's `item_pool`); carriers through `ItemDrops.give` / `can_carry` (its glint is `fx` "glint") and drop through `drop_carried`; whatever brings a reward home pays it through `Treasure.pay`, and looters skip a reward the village can't take (`ItemDrops.room_for`). Random carriers in a scenario only with `Scenario.item_carriers`. The market's equipment offer is `Market.item_offer`.
- **Relics** (`Relics`, `Config.RELICS`; items-design §7): village-wide ones (`"reach": "village"`) read through `Village.relic_bonus`, map-wide ones through `Relics.map_bonus` (each kind once; standing villages only). A relic works just by the village having it and is never worn; equipment works only while worn and is never a relic. An effect that needs the hero to wear something is equipment, not a relic. Relic sources pick through `Relics.pool`, a relic comes home through `Relics.bring_home` (it needs room in the armoury: `Armoury.count` holds items and `Village.relics` together). A new relic effect is a key in its `RELICS` entry read through those, never a check of a relic's id in game code; a new relic needs its icon (art rules) and a check in items_bot.
- **Hero evasion.** `wants_to_evade` is true only in Build, Explore and Gather, and never during an ordered camp attack: in Defend, Train and Rest she fights or stays instead of running. Keep a new mode's evasion decision going through it.
- **Unit-unlock sites, ruined watchtowers, treasures, monster camps/lairs, mines** are map objects (`scripts/world/objects/`), hidden in the fog until found; the hero's Explore mode handles them in a fixed priority.
- **Hunger and starvation** are driven by `Population.starving`; military units suffer a penalty, villagers starve in a fixed interval, named ones last.
- **Defeat:** no civilians, or the town hall has fallen (its last stand ran out: `Village.last_stand`, `hall_lost`). In co-op a village falls and may stand again; the game is lost when all have fallen.
- **The 7×7 village** (`Config.VILLAGE_LAYOUT`, `MapData.standard_pieces`): the town hall (`TownHall`, a `Tower` with a post from level 2 and from level 3 its bench, `HallBench`: a one-bench barracks with no tiles of its own, which the hall carries in saves and snapshots; walkable like a hut) is a village piece from the map; the centre is the free middle of the path cross, which is never built on (`MapData.is_village_path`). Inside, raiders flip a coin between a hut and the hall or a building inside (`Enemy._raid_tick`).
- **Advancements** (`Research`, one per village; `Config.ADVANCEMENTS`): researched at the town hall, read where they apply through `Village` helpers (`adv_bonus`, `max_piece_level`, `walk_bonus`, `targeting`, `kill_gold`, `crit`, `recruit_cost`). A new bonus is a key in `ADVANCEMENTS` read through those, never a check of an advancement's id in game code. Off in scenarios unless `Scenario.advancements`.
- **Marketplace** (`Market`, `Config.MARKET`; `docs/market-design.md`): one per village by a road, a `Farm` to the rats (its `stored` is the merchants' food). The trader (`Trader`, `"max": 1`) packs the for-sale pile into `TradeCaravan`s, which are in the `villagers` group for enemies (`is_exposed`, `take_damage`; not `Civilian`s, so code walking that group must not cast blindly, and hunters skip them), turn back from visible enemies and drop salvage (a dropped-loot sack with `"salvage"`) that only `GatherJob` carries back. Off in the tutorial, the backdrop and scenarios unless `Scenario.market` (`Game.market_enabled`). Money moved back (taking goods back, refunded orders) goes through `Economy.refund`, never `add`.
- Villagers living in huts: a hut caps the population; raids kill only the villager whose hut burns.
