# Veliron's Outpost: military expansion (design)

Status: **built** (decisions in §12 confirmed). Tested by tests/military_bot.gd. Piercing (crossbowman) waits for shielded enemies.
Scope: why units, levels, HP and downing, barracks, the tech tree of specialisations and the
Spatial Archmage work as they do. Every number (stats, costs, ranges, timers, curves) lives in
`scripts/core/config.gd` (`MILITARY`, `ATTACKS`, `SUMMONS`, `SUMMON`, `BARRACKS_LEVELS`,
`UNIT_REVIVE_TIME`, `UNIT_REGEN`, `SORTIE_LEASH`, `ARCHMAGE_*`, `TOWER_RANGE`,
`TOWER_LEVELS`) and is not repeated here; the docs/library page reads it from there.

## 1. Summary

- **Levels:** every military unit goes up to `MAX_UNIT_LEVEL`.
- **HP:** every unit has HP and can be **downed**. After a revive cooldown it comes back: in its
  barracks if it was stationed there, otherwise in the reserve. While reviving, nothing can be
  done with it, so downing has a real cost without deleting the unit.
- **Barracks** (2×2, three levels): benches with the units sitting on them. When an enemy comes
  within the barracks' range, every unit stationed there goes out and fights; when none is
  left, they come back. They give the army a mobile, riskier alternative to the safe tower.
- **Roles** (`role` in `MILITARY`):
  - *Ranged* (archers, the acolyte, the attacking mages): towers or barracks. Out in the field
    they use their own range, shorter than any tower's.
  - *Melee* (the shield bearer and its Warrior, Berserker, Halberdier; the Inquisitor): barracks
    only.
  - *Summoner* (summoner, fire summoner, druid): summons, no attack of its own.
  - *Healer* (healing mage): heals allies, no damage.
  - *Support* (High Priest): a damage aura, see docs/acolyte-design.md.
- **Tech tree:** from level `BRANCH_MIN_LEVEL` of a base unit, an upgrade can also turn it into
  **level 1 of a specialised unit** (the full tree is §2).
- **Specialising never costs strength at the branch point:** a specialisation's level 1 is at
  least as strong as its base unit's level 3 (§3).
- **Spatial Archmage:** at max level a spatial mage can become one. The unit leaves the army and
  becomes a **civilian**; meant as a key piece of the game's future ending.

## 2. Tech tree

```
Recruitable (Army tab)        Specialisations (upgrade from level >= BRANCH_MIN_LEVEL -> level 1)

Archer ─────────────┬──────►  Crossbowman      (slow, heavy bolts; later: pierces shields)
  (ranged)          └──────►  Swiftbowman      (very fast, light arrows)

Shield Bearer ──────┬──────►  Warrior          (tank; war cry: allies near him attack faster)
  (melee,           ├──────►  Berserker        (attacks faster the more HP he lost; lifesteal when low)
   barracks only)   └──────►  Halberdier       (long polearm: reaches flyers)

Summoner ───────────┬──────►  Fire Summoner    (fire elementals instead of earth)
  (summoner)        └──────►  Druid            (thornlings: slow, tough; every blow roots)

Apprentice ─────────┬──────►  Fire Mage        (fireball, splash damage)
  (ranged)          ├──────►  Ice Mage         (slows the target)
                    ├──────►  Healing Mage     (heals allies around it, no damage)
                    └──────►  Spatial Mage     (throws the target back)
                                   │ level >= ARCHMAGE_LEVEL
                                   ▼
                              Spatial Archmage (becomes a CIVILIAN)

Acolyte ────────────┬──────►  Inquisitor       (holy melee, barracks only)
  (ranged, holy)    └──────►  High Priest      (support: damage aura)
```

- **Upgrade choice.** A base unit at or above the branch level is offered the next level of its
  own kind (paid in gold) and level 1 of each specialisation it branches into, for that
  specialisation's `branch_cost`. Example: archer 5 → archer 6, crossbowman 1 or swiftbowman 1.
  The branch is a real choice: it resets the level but opens a different role.
- Specialised units level up like any unit and have no further branches, except the spatial
  mage.
- Only the five base units (`MILITARY_ORDER`) can be recruited; specialisations come only from
  upgrades. The summoner, apprentice and acolyte must be unlocked first (`LOCKED`,
  docs/world-objects-design.md §9.4).

## 3. Unit roster

Per-level values follow a curve between level 1 and the top level (§8); the roster's actual
stats are in `Config.MILITARY` (the library shows them). Each unit's role in the design:

- **Archer:** the all-round tower unit; the baseline others are measured against.
- **Crossbowman:** slow, heavy bolts and more range, the "big hit" archer. `pierce` is a reserved
  flag until there are shielded enemies. **Swiftbowman:** at least twice the archer's fire rate
  with small hits: good against many weak targets, lighter on any one.
- **Shield Bearer:** a barracks wall: lots of HP, very low damage, holds enemies up. **Warrior**
  (§3a): the most HP, a force multiplier. **Berserker** (§3a): the high-risk, high-damage melee.
  **Halberdier** (§3a): the answer to flyers and riders.
- **Summoner:** fragile and with no attack, its output is its summons. **Fire Summoner:** faster
  summoning, flimsier, hard-hitting exploding summons. **Druid** (§3b): control.
- **Apprentice:** a plain ranged mage. **Fire Mage:** splash (a share of the damage in a radius).
  **Ice Mage:** slows. **Healing Mage:** no damage, heals. **Spatial Mage:** throws the enemy back
  along its road, away from the village, the same enemy only once per immunity window
  (`push_immunity`) so it can't be pinned in place.
- **Acolyte line:** docs/acolyte-design.md.
- **Spatial Archmage:** a civilian (from spatial mage at max level; lives in a hut; role in the
  ending TBD).

**The specialisation rule.** Upgrading a level 3 base unit into level 1 of a specialisation never
lowers its HP or DPS: every specialisation's level 1 is at least as strong as its base unit's
level 3. Otherwise a branch would punish the player for choosing; they are told they gain a role.
Branching from a higher level may lose stats; that is the player's choice. Per-hit damage may be
lower (the swiftbowman's is).

**The higher ceiling.** Level 10 of a specialisation is stronger than level 10 of its base unit:
more HP, and more DPS if it attacks; a summoner more summon output (summons × summon damage × the
summon kind's damage factor). This is the reward for committing.

In between, a specialisation may fall a little short of the base unit of the same level.
"Strength" means HP, plus DPS for units that attack (roles ranged and melee); for summoners also
`max_summons`, `summon_hp`, `summon_damage` (at least as high) and `interval` (no longer) at level
1. The healing mage and the High Priest have no real attack: only their HP counts.
tests/military_bot.gd checks both rules for every specialisation (`_spec_rule_breaks`).

Damage categories (`ATTACKS` "category"): arrows and bolts are *projectile*, orbs, frost and warp
are *magical*, fireballs (and their splash) and fire elementals' blows are *fire* (a category of
its own: docs/enemies-design.md §4), the acolyte line is *holy*, the shield bearer's line strikes
*melee*. The library's Damage tab is built from this data.

**Own range.** Used out in the field (barracks sorties). It never grows with upgrades and is
always smaller than the smallest tower range (a test enforces this), so a tower is always the
safer and farther-reaching post and a sortie is a trade of safety for presence. On a tower, a unit
uses the tower's range (`TOWER_RANGE` plus the level's `range_bonus`, and the Hawk-eye relic).

**Summoners.** `interval` is the time between summons while enemies are in reach, `max_summons`
the cap alive at once; both are level stats.

**Summons** (`SUMMONS`; `hp` and `damage` are factors on the summoner's `summon_hp` and
`summon_damage` at the moment of summoning; shared values in `SUMMON`):

- **Earth elemental:** a level 1 one is exactly as strong as a Normal goblin (difficulty scales
  goblins, not elementals), so the summoner's early power is easy to reason about.
- **Fire elemental:** a flyer with less HP, more speed and much more damage (fire). It burns itself
  with its own blows (`self_damage`) and **explodes when killed** (`explode`: its blow's damage to
  every enemy in `explode_radius`, flyers too, not divers), also when burnt up, not when dismissed
  (its summoner withdrawn, downed or specialised) nor drowned (`EarthElemental._explode`). The
  explosion is meant to make killing a fire elemental a cost to the enemy, a rough match for a
  fire mage's hit.
- **Thornling:** slow, tough, less damage; every blow roots (§3b).
- Summons heal while idle (`regen`, after `regen_delay` without a blow or a hurt), so they are
  used again between waves without upkeep; a fire elemental burns itself only with its blows, so
  it heals idle too.

Existing elementals keep their stats when the summoner levels up (only newly summoned ones are
stronger). They crumble when their summoner leaves them: withdrawn, downed, specialised, or back
on its bench after a sortie.

**Healing** (`Combat.heal_around`) reaches military units in the field (sorties, walking) of any
village and every village's hero. It doesn't reach summons (they regenerate themselves) or
villagers (who heal only at home). On a tower, a healing mage heals as far as the tower reaches,
so tower upgrades widen it; elsewhere within its own radius.

### 3b. The druid

The summoner's plant branch (no unlock of its own; priced like the fire summoner). It summons
**thornlings** (`SUMMONS.thorn`, `EarthElemental` with `summon` "thorn"): slow, tough, hitting
lightly. **Every blow roots** the enemy it hits (`Enemy.root`) for the druid's `root` stat at the
moment of summoning: a rooted enemy can't walk (`Enemy._walk_factor` is 0) but fights, casts and
shoots on; tendrils curl round its feet (`Enemy._draw_roots`, not on co-op clients). A root
doesn't stack or refresh, and when it wears off the enemy can't be rooted again for
`root_immunity`, so even a perfect druid holds an enemy only part of the time: control, not a
lock. Flyers can't be rooted (thornlings can't reach them anyway). The druid is best against what
slips past: rats running for farms, thieves fleeing with gold, slimes.

Scenario 7's grove druids are druids that take no orders (`MilitaryUnit.bound`, set by the
scenario's prebuilt units: no moving, withdrawing, swapping, upgrading or sending); only druids
serve in a grove (docs/scenarios-7-9-design.md).

### 3a. The shield bearer's specialisations

All three branch from the shield bearer at the usual level, are barracks-only, and share the
branch price. Their level 1 is above the shield bearer's level 3 (the rule in §3).

**Warrior: war cry** (`cry`, `cry_time`, `cry_interval`, `cry_radius`)
- A force multiplier rather than a damage dealer. Only out on a sortie (never on the bench or while
  walking): as soon as he is out, and then at an interval while he stays out, he shouts.
- The cry reaches every ally within the radius of him, of any village: units out on a sortie,
  units on towers (by the tower's tile), summons, heroes, and himself.
- Each one is **hasted** for a few seconds: all its timers run `1 + cry` times as fast, so every
  interval is divided by it. That is attacks (ranged, melee, holy), summoning, healing, the High
  Priest's counter-strike, the hero's sword and the elementals' blows. Moving speed doesn't
  change.
- **Strict refresh, no stacking** (`Combat.war_cry`): a unit holds one haste. A cry at least as
  strong as the one it has refills it (the stronger value, the later end); a weaker cry counts
  only once the stronger one has run out. So two warriors shouting in turns keep it up, but never
  above one cry; stacking would make several warriors an exploit.
- Looks: a red-orange shout ring (burst "war_cry"); a small double chevron over every hasted unit
  (`UnitFx`, host and single player).

**Berserker: rage and lifesteal** (`rage`, `lifesteal`, `lifesteal_below`)
- **Rage:** his strike interval shrinks with the share of HP missing, so the more hurt he is,
  the faster he strikes (at low HP at level 10 several times as fast). It stacks with a war cry.
- **Lifesteal:** while his HP is below `lifesteal_below` he gets back a share of the HP his blows
  really take, never above his max. The share is a steeper curve (`"curves": {"lifesteal": 1.5}`)
  so it matters mostly late.
- The design is deliberately high-ceiling and high-risk: at full HP he matches the archer's DPS,
  and his payoff comes from fighting on the edge. His figure turns redder as he loses HP, so the
  player reads the risk.

**Halberdier: reaches flyers, the bane of riders** (`hits_flyers`, `range`, `vs_mounted`, `breaks_charge`)
- Goes for gargoyles and vampire bats like any other enemy, with no bonus; barracks with a
  halberdier turn out for flyers. It is the melee answer to flyers.
- Reach longer than the usual melee reach (`range`).
- Against mounted enemies (docs/enemies-design.md §15e) its blows do extra to the mount, never to
  the rider once on foot (`Combat.hit`). It breaks charges (`breaks_charge`): a rider's charge on
  it gives no bonus, and each of its blows on a mounted enemy halts the mount briefly
  (`MOUNTED.halt_time`) and spends its charge. Spear against cavalry.

## 4. HP, downing and revival

- Every military unit has `hp` / `max_hp`, taken from its level. Upgrading or specialising refills
  HP to the new kind's maximum.
- **Where units can be hurt:** out of the tower, i.e. in the field (barracks sorties) and while
  walking (to or from a post, or to another village): melee enemies stop to fight them, and
  witches' spells hurt them. On a tower they are safe (witches only bewitch them). That is the
  price and the reward of each post.
- **At 0 HP a unit is downed:** it vanishes with a small animation and leaves no corpse, and a
  **revive timer** starts (`UNIT_REVIVE_TIME`, growing with level, so a high-level unit is a
  bigger loss; the Phoenix feather relic shortens it).
  - *Stationed in barracks:* it revives on its bench there, with a clock over it; a High Priest's
    aura over the barracks makes the timer run faster (docs/acolyte-design.md §6).
  - *Anything else* (walking, travelling, on the way back): it revives in the **reserve**, where
    its card shows a dimmed portrait and a countdown. It can't be stationed, upgraded, sent or
    trained until it revives.
  - A unit on its way to another village that is downed revives in the reserve of the village
    that sent it (it never arrived).
- **Healing:** a unit heals `UNIT_REGEN` while it sits on a barracks bench or rests unused in the
  reserve. Healing mages heal too.
- **Food:** every unit eats (`MILITARY_UPKEEP`), and while its village's food is at 0 it is
  hungry: slower and more damage taken. See docs/village-design.md §2a.

## 5. Barracks

- **Building:** 2×2, placed outside the walls like other buildings, built by builders (material
  and gold; `BUILDINGS`).
- **Levels** (`BARRACKS_LEVELS`: slots, activation range, upgrade cost): upgraded like towers with
  building material and a builder's time. Higher levels add a bench and range.
- **Art** (`barracks`, `barracks_2`, `barracks_3`): like the training grounds (yard, small hut,
  fence) but without the weapons lying around: benches (one per level), a table with food and
  drink, and a straw puppet with arrows stuck in it. Stationed units are drawn sitting on the
  benches.
- **Stationing:** by drag & drop or by tapping, as with towers; a drop fills the first free bench.
  The panel lists each bench separately (unit, level, HP, state, Upgrade and Withdraw per unit),
  and a stationed unit can be selected and dragged from its bench like a unit on a tower.
- **Sorties:**
  1. When an enemy comes within the activation range, every unit on a bench that isn't downed goes
     out. Monster-camp guards count too: barracks fight them without an order (only the hero
     needs one). Barracks whose units can't reach flyers (only melee units, no halberdier) don't
     turn out for flyers.
  2. *Melee* units run to the nearest enemy and fight in close combat. They can't go for flyers
     (except the halberdier); they only counter-strike them. A warrior shouts his war cry (§3a).
  3. *Ranged* units walk until the nearest enemy is within their own range, then stand and shoot.
     Healing mages and High Priests stay among their comrades. Summoners stay just outside the
     barracks and summon there; enemies can attack them, and they have no attack of their own.
  4. They re-target (nearest first) and never chase beyond the activation range +
     `SORTIE_LEASH`.
  5. When no enemy has been in reach for a moment, they walk back to their benches.
  6. They step down from their bench to the yard's way out (`Soldier.Mode.LEAVE`,
     `Barracks.bench_point`) and, back at the barracks, up onto it again (`SEAT`), so nobody pops
     in or out of sight. Stepping down counts as out on the sortie (`Soldier.out_fighting`: auras,
     war cries, counter-strikes); walking back does not.
- A unit on its bench with less than full HP shows its HP bar until it has healed.
- **Farm defence:** with no enemy in range, barracks also turn out for rats on one of their
  village's farms within `BARRACKS_FARM_RANGE_FACTOR` × their range, because rats otherwise only
  face the hero. Units out for a farm stay within `FARM_DEFENSE_LEASH` of it and drop it as soon
  as an enemy comes within the barracks' own range.
- Units out on a sortie watch their surroundings, like villagers.

## 6. Units, posts and roles

| Post | Holds | Units there... |
|---|---|---|
| Tower (wall tower, watchtower) | 1 unit: ranged, summoner, healer or support | act from the tower with the tower's range; can't be hurt |
| Training grounds | 1 unit, any kind | train with the hero (up to max level); don't fight |
| Barracks | several units, any kind | sit on benches; go out on sorties; can be hurt |

- Summoners (all three kinds) can serve on towers or in barracks. A druids' **grove** (`Grove`,
  campaign only: a `Barracks` with post kind "grove") takes only druids; scenario 7's take no
  orders (`MilitaryUnit.bound`, §3b).
- Healing mages work from towers (around the tower) and from barracks (they go out with the others
  when enemies come near).
- Shield bearers, warriors, berserkers, halberdiers and Inquisitors are barracks-only.
- Towers, like barracks, fight monster-camp guards in range without an order.
- A witch's spell bewitches a tower's unit: no shooting, summoning or healing for a while (a High
  Priest's aura keeps working).

## 7. Upgrading and the Spatial Archmage

- **Upgrade dialog.** *Upgrade* opens a small dialog with one button per option, from the reserve
  or from a unit's panel on its post. Each button shows the cost and the option's name, level and
  main stats (`MilitaryUnit.option_text`), so the player compares before paying.
- A level-up's gold price is lowered by the training progress towards it, 1:1
  (`TRAIN_GOLD_DISCOUNT`, docs/hero-design.md §4.6); a specialisation's price never is.
- Every upgrade resets the unit's training XP and refills its HP. Specialising keeps the unit where
  it is, unless its new kind can't serve on its post (an Inquisitor on a tower): then it walks
  back into the reserve. A unit specialised while out changes its look, glow and walking speed at
  once (`Soldier.refresh_kind`; co-op clients too).
- **Training grounds:** the hero can train a unit to its next level within its own kind only.
  Specialising always costs gold: training can't make a branch decision for the player.
- **Spatial Archmage** (spatial mage at `ARCHMAGE_LEVEL`):
  - The option says the unit "leaves the army and becomes a civilian" and asks for confirmation,
    because it is irreversible.
  - It needs a **free hut** and costs `ARCHMAGE_COST`. The unit is removed from the army, post and
    reserve, and an archmage civilian moves into the hut.
  - It can't be recruited (`"recruit": false` in `CIVILIANS`), so the Village tab doesn't list it;
    its library entry says only a max-level spatial mage can become one.
  - For now it is decoration: it strolls around the village walls, eats, and counts as a villager.
    Its role in the ending comes later.

## 8. Config layout (`config.gd`)

Everything stays in the config, readable by a person. The shape (not the values):

- `MILITARY[kind]` holds name, role, posts, recruit flag, cost, speed, attack, range,
  `"stats"`, `"upgrade_cost"`, `"train_xp"`, `"branches"` / `"branch_of"` and `"branch_cost"`.
- `ATTACKS` holds what a shot looks like, its damage category and fixed effect values; `SUMMONS`
  and `SUMMON` hold the summon kinds and their shared values.
- `"stats"`: key → [level 1, top level]. Everything that grows with the level is a stat of the
  unit, also the effects (`splash`, `slow`, `slow_time`, `heal`, `radius`, `push`, `aura`, and the
  summoners' `interval`, `max_summons`, `summon_hp`, `summon_damage`).
- Every level follows the curve between those two values: no level is fixed by hand (one rule for
  every unit keeps balance reviewable). `"upgrade_cost"` / `"train_xp"` follow the same curve.
- `"curve"` (optional, default linear) is an exponent on all of a unit's stats; `"curves"` sets it
  per stat (the berserker's lifesteal); a stat not named uses `"curve"`.
- Melee extras: `"hits_flyers"`, `"range"` for a reach other than `UNIT_MELEE_RANGE`,
  `"cry_interval"` / `"cry_radius"` (warrior), `"lifesteal_below"` (berserker); the growing parts
  are stats.
- `Config.unit_stat(kind, key, level)` reads a stat; `unit_upgrade_cost` and `unit_train_xp` the
  others.

## 9. Art

Art is generated by `tools/gen_art.py` (never hand-edited); the look of each unit lives there.
The design intent: each specialisation reads as its role at a glance and shares the base unit's
silhouette where it is a branch (the mages are the apprentice in a different colour with their
own staff top; the shield bearer's line gets progressively more armour or wildness). Effects
(war cry ring and chevrons, bolts, orbs, fireballs, frost, healing pulse, warp) are bursts and
projectiles from `ATTACKS`. Revive countdowns and bench markers are UI icons. The acolyte line's
art is in docs/acolyte-design.md.

## 10. Code

- **`MilitaryPost` has slots** with a capacity (tower, training grounds, barracks by level).
  Commands, replication, drag & drop and panels work per unit.
- **Behaviours by role** (`MilitaryUnit.BEHAVIORS`, scripts/units/military/): `RangedBehavior`
  handles every projectile or effect type through `ATTACKS`; `HealerBehavior`,
  `SupportBehavior`; `SummonerBehavior`, parametrised by summon type (`SUMMONS`); melee units use
  the plain `MilitaryBehavior` (their fighting is in `Soldier`). `Combat` plays attacks and their
  effects (splash, slow, push, heal, holy auras, the war cry's haste, the berserker's lifesteal);
  `Combat.haste(holder)` is the factor every attack, summon and heal timer runs at, and
  `MilitaryUnit.rate()` adds the berserker's rage. The same behaviours work from a tower (tower
  range) and in the field (own range).
- **Field units.** `Soldier` is the unit's body outside, with HP, a combat behaviour, and
  membership of the "melee_defenders" and "field_units" groups. Sorties, walking, downing and
  reviving live there and in `Army`.
- **`MilitaryUnit`** has `hp`, `revive_left`, `kind` changes on specialising, and a `role()`
  helper. **Elementals:** `EarthElemental` is every summon kind, configured by `SUMMONS`.
- **Co-op:** the replicator sends barracks slots, unit HP and revive timers, field units and
  projectile effects; commands `upgrade_unit` (with a chosen option) and `station_unit` (with a
  slot); healing covers other villages' units and heroes.
- **Tests** (tests/military_bot.gd): config sanity (ranges below the tower range, curves, the tech
  tree consistent, specialisations never weaker than their base unit), barracks (slots, benches,
  sorties, returning), downing and reviving in both places, every attack type, branching and the
  archmage conversion.

## 12. Decisions (confirmed)

| # | Question | Decision |
|---|---|---|
| D1 | Per-level stats | **Curve** between level 1 and the top level for every unit (linear; an exponent per unit or per stat is possible); no hand-set levels |
| D2 | Hurt while walking? | **Yes**: enemies stop to fight walking units, which keep walking; downing while travelling is possible |
| D3 | Units on towers | **Can't be hurt** (witches still bewitch them) |
| D4 | Healing on their own | **On barracks benches and unused in the reserve**, both at `UNIT_REGEN`; anywhere else only by healing mages |
| D5 | Revive time | **Scales with level** (`UNIT_REVIVE_TIME`) |
| D6 | Summoners in barracks | **Yes.** They step outside and summon there; enemies can attack both the summons and the summoner, which can go down. Summoners have little HP and no attack of their own |
| D7 | Healing mage | Works from **towers and barracks** (from barracks when the barracks turn out for nearby enemies). Heals field units of any village and all heroes; not summons, not villagers |
| D8 | Training into a specialisation | **No**, training only raises levels |
| D9 | Spatial Archmage | Needs a **free hut** and gold (`ARCHMAGE_COST`), and asks for **confirmation** |
| D10 | Own ranges | All below the smallest tower range, so towers always outreach sorties |
| D11 | Barracks | As in §5 |
| D12 | Sortie rules | As in §5 |
| D13 | Spatial push | Back along the road, growing with level; the same enemy at most once per `push_immunity` |
| D14 | Crossbow piercing | Flag only, for now |
| D15 | Recruitable units | Archer, shield bearer, summoner, apprentice, acolyte; the summoner, the apprentice and the acolyte have to be unlocked first at their unlock sites (docs/world-objects-design.md §9.4) |
| D16 | Upgrade costs | Gentle curve (per unit, in config) |
| D17 | Hero training XP | Rising with level (per unit, × difficulty) |
| D18 | Specialisations vs base unit | Level 1 **never weaker than the base unit's level 3** (HP, DPS, summons); level 10 **stronger than the base unit's level 10**; in between it may fall a little short (§3) |
| D19 | Shield bearer branches | Warrior, Berserker, Halberdier; like every branch, barracks only (§3a) |
| D20 | War cry | Attack speed (every interval, also casting, summoning, healing) up for a short time, repeated on a sortie, short radius, also tower units; strict refresh, no stacking |
| D21 | Berserker | Rage and lifesteal below half HP; the high ceiling is wanted |
| D22 | Halberdier | Reaches flyers, no bonus there; longer reach; extra to mounts and breaks charges (the riders, docs/enemies-design.md §15e) |
| D23 | DPS of the damage dealers | Berserker (at full HP) and halberdier match the archer's top-level DPS |
