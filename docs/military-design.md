# Veliron's Outpost: military expansion (design)

Status: **built** (decisions in §12 confirmed). Tested by tests/military_bot.gd. Piercing (crossbowman) waits for shielded enemies.
Scope: unit levels to 10, unit HP and downing, barracks, a tech tree of specialisations,
and the Spatial Archmage. Every number lives in `scripts/core/config.gd`.

## 1. Summary

- **Levels:** every military unit goes up to **level 10** (`MAX_UNIT_LEVEL`).
- **HP:** every unit has **HP** and can be **downed**. After a revive cooldown it
  comes back: in its barracks if it was stationed there, otherwise in the reserve.
  While reviving, nothing can be done with it.
- **Barracks** (2×2 building, levels 1-3): 1 to 3 unit slots, shown as benches
  with the units sitting on them. When an enemy comes within the barracks' range,
  every unit stationed there goes out and fights. When no enemy is in range,
  they come back.
- **Roles** (`role` in `MILITARY`):
  - *Ranged* units (archers, the acolyte, the attacking mages) can go on towers
    or in barracks. Out in the field they use their own range, which is shorter
    than any tower's.
  - *Melee* units (the shield bearer, the Inquisitor) go only in barracks.
  - *Summoner* (summoner, fire summoner): summons elementals, no attack of its own.
  - *Healer* (healing mage): heals allies, no damage.
  - *Support* (High Priest): a damage aura, see docs/acolyte-design.md.
- **Tech tree:** from level 3 of a base unit, an upgrade can also turn it into
  **level 1 of a specialised unit**:
  - archer → crossbowman / swiftbowman;
  - summoner → fire summoner;
  - apprentice → fire / ice / healing / spatial mage;
  - acolyte → inquisitor / high priest (holy damage; see docs/acolyte-design.md).
- **Specialisations are never weaker** than their base unit at the same level (§3).
- **Spatial Archmage:** at level 10 a spatial mage can become one. The unit
  leaves the army and becomes a **civilian**. It's meant as a key piece of the
  game's future ending.

## 2. Tech tree

```
Recruitable (Army tab)        Specialisations (upgrade from level ≥ 3 → level 1)

Archer ─────────────┬──────►  Crossbowman      (slow, heavy bolts; later: pierces shields)
  (ranged)          └──────►  Swiftbowman      (very fast, light arrows)

Shield Bearer                 (no specialisations yet)
  (melee, barracks only)

Summoner ───────────────────► Fire Summoner    (fire elementals instead of earth)
  (summoner)

Apprentice ─────────┬──────►  Fire Mage        (fireball, splash damage)
  (ranged)          ├──────►  Ice Mage         (slows the target)
                    ├──────►  Healing Mage     (heals allies around it, no damage)
                    └──────►  Spatial Mage     (throws the target back)
                                   │ level ≥ ARCHMAGE_LEVEL (10)
                                   ▼
                              Spatial Archmage (becomes a CIVILIAN)

Acolyte ────────────┬──────►  Inquisitor       (holy melee, barracks only)
  (ranged, holy)    └──────►  High Priest      (support: damage aura)
```

- **Upgrade choice.** A base unit at level *n* ≥ `BRANCH_MIN_LEVEL` (3) is offered:
  - the next level of its own kind (*n*+1), paid in gold;
  - level 1 of each specialisation it branches into, for that specialisation's
    `branch_cost`.

  Example: archer level 5 → archer 6, crossbowman 1, or swiftbowman 1.
- Specialised units level up to 10 like any unit; they have no further branches,
  except the spatial mage.
- Only the five base units (`MILITARY_ORDER`: archer, shield bearer, summoner,
  apprentice, acolyte) can be recruited; specialisations come only from upgrades.
  The summoner, the apprentice and the acolyte have to be unlocked first
  (`LOCKED`, docs/world-design.md §9.4).

## 3. Unit roster

Levels 1 → 10. Per-level values follow a curve (§8). DPS = damage ÷ cooldown.

**The specialisation rule.** At every level, a specialisation is at least as
strong as its base unit at the same level, in its base stats:
- HP, always;
- DPS, for units that attack (roles ranged and melee). The damage per hit may be
  lower (the swiftbowman's is);
- for summoners: `max_summons`, `summon_hp` and `summon_damage` at least as high,
  `interval` no longer;
- the healing mage and the High Priest have no real attack: only their HP is matched.

tests/military_bot.gd checks this for every specialisation and level.

| Unit | Role / posts | HP (L1 → L10) | Own range* | Damage (L1 → L10) | Cooldown s | DPS | Notes |
|---|---|---|---|---|---|---|---|
| **Archer** | ranged · tower, barracks | 30 → 90 | 2.6 | 7 → 40 | 1.0 → 0.45 | 7 → 89 | levels 1-4 pinned (damage 7/11/16/24, cooldown 1.0/0.85/0.72/0.6), then linear |
| **Crossbowman** | ranged · tower, barracks | 34 → 100 | 3.2 | 50 → 170 | 2.25 → 1.7 | 22 → 100 | L1 DPS = archer L3 (22); `pierce` flag reserved (no shielded enemies yet) |
| **Swiftbowman** | ranged · tower, barracks | 30 → 90 | 2.6 | 7.5 → 17 | 0.30 → 0.18 | 25 → 94 | ≥ 2× the archer's fire rate, small hits; fancier art, multi-string bow |
| **Shield Bearer** | melee · barracks only | 55 → 180 | melee (0.8) | 3 → 12 | 1.2 → 0.9 | 2.5 → 13 | ork-like HP, very low damage: holds enemies up |
| **Summoner** | summoner · tower, barracks | 18 → 50 | - | (summons) | - | - | fragile, no attack of its own (summon table below) |
| **Fire Summoner** | summoner · tower, barracks | 18 → 50 | - | (summons) | - | - | fire elementals |
| **Apprentice** | ranged · tower, barracks | 20 → 60 | 2.8 | 7 → 38 | 1.0 → 0.55 | 7 → 69 | whirling dark-blue orb, plain damage |
| **Fire Mage** | ranged · tower, barracks | 20 → 60 | 2.8 | 10 → 38 | 0.95 → 0.55 | 10.5 → 69 | fireball explodes: splash within 1.2 → 1.8 tiles (`splash`), 60 % of the damage (`splash_share`) |
| **Ice Mage** | ranged · tower, barracks | 20 → 60 | 2.8 | 16 → 44 | 0.95 → 0.55 | 17 → 80 | hit enemy slowed to 70 % → 40 % speed for 2 → 3.5 s |
| **Healing Mage** | healer · tower, barracks | 20 → 60 | heal radius 2.5 → 3.5 | no damage | 3.0 → 1.4 | - | heals 6 → 30 HP to every ally in reach |
| **Spatial Mage** | ranged · tower, barracks | 20 → 60 | 2.8 | 9 → 38 | 0.95 → 0.55 | 9.5 → 69 | hit enemy is thrown back 1.5 → 4 road tiles, away from the village; the same enemy only once per 4 s (`push_immunity`) |
| **Acolyte** | ranged · tower, barracks | 30 → 90 | 1.6 | 6.5 → 36 | 1.0 → 0.48 | 6.5 → 75 | holy beam (docs/acolyte-design.md) |
| **Inquisitor** | melee · barracks only | 45 → 140 | melee (0.8) | 9 → 57 | 1.1 → 0.75 | 8.2 → 76 | holy melee, hunts witches and the unholy |
| **High Priest** | support · tower, barracks | 30 → 90 | aura 2.6 | counter-strike 3 → 10 | 1.4 → 1.0 | - | aura +2 % → +20 % damage to allies |
| **Spatial Archmage** | civilian | - | - | - | - | - | from spatial mage ≥ `ARCHMAGE_LEVEL`; lives in a hut; role in the ending TBD |

Damage categories (`ATTACKS` "category"): arrows and bolts are *projectile*,
orbs, fireballs (and splash), frost and warp are *magical*, the acolyte line is
*holy*, the shield bearer's strike is *melee*.

\* **Own range** is used out in the field (barracks sorties). It never grows
with upgrades and is always smaller than the smallest tower range
(`TOWER_RANGE["tower"]` = 3.6; a check in the tests enforces this). On a tower,
a unit uses the tower's range: `TOWER_RANGE` (watchtower 3.6, wall tower 4.8)
plus the tower level's `range_bonus` (+0.8 at level 2, +1.6 at level 3,
`TOWER_LEVELS`), +10 % with the Hawk-eye relic.

**Summoners** (`interval` s between summons while enemies are in reach, `max_summons` alive at once):

| Unit | Interval s (L1 → L10) | Max summons | Summon HP stat | Summon damage stat |
|---|---|---|---|---|
| Summoner | 6.0 → 2.5 (pinned 6.0/5.0/4.2/3.5 for L1-4) | 2 → 8 (pinned 2/3/4/5) | 20 → 90 (pinned 20/26/34/44) | 4 → 18 (pinned 4/5/6.5/8.5) |
| Fire Summoner | 3.9 → 2.5 | 4 → 8 | 34 → 90 | 6.5 → 18 |

**Summons** (`SUMMONS`; `hp` and `damage` multiply the summoner's `summon_hp` and
`summon_damage` at the moment of summoning; `speed` in tiles/s; shared values in
`SUMMON`: a blow every 1.0 s, reach 0.8, sight 3.5, leash 4.0 tiles from its tower):

| Summon | HP | Speed | Damage | Special |
|---|---|---|---|---|
| Earth elemental | 1.0× summon HP (20 → 90) | 1.1 | 1.0× summon damage (4 → 18), melee | at level 1 as strong as a Normal goblin (20 HP, 4 damage); difficulty scales goblins, not elementals |
| Fire elemental | 0.5× (17 → 45) | 1.8 | 2.5× (16 → 45), magical | burns itself: loses 25 % of the damage it deals, as HP (`self_damage`); hovers and flickers, a flyer |

Existing elementals keep their stats when the summoner levels up. They crumble
when their summoner leaves them: withdrawn, downed, specialised, or back on its
bench after a sortie.

**Healing** (`Combat.heal_around`) reaches:
- military units in the field (sorties, walking), of any village;
- every village's hero.

It doesn't reach summons or villagers (villagers have HP, `CIVILIAN_HP`, but heal
only at home). On a tower, a healing mage heals as far as the tower reaches
(so tower upgrades widen it); elsewhere within its own `radius`.

## 4. HP, downing and revival

- Every military unit has `hp` / `max_hp`, taken from its level. Upgrading or
  specialising refills HP to the new kind's maximum.
- **Where units can be hurt:**
  - out of the tower, i.e. in the field (barracks sorties) and while walking
    (to or from a post, or to another village): melee enemies stop to fight
    them, and witches' spells hurt them;
  - on a tower: safe (witches only bewitch them).
- **At 0 HP a unit is downed:**
  - it vanishes with a small animation and leaves no corpse;
  - a **revive timer** starts (`UNIT_REVIVE_TIME`, 30 s at L1 → 45 s at L10,
    linear; the Phoenix feather relic makes it 20 % shorter);
  - *stationed in barracks:* it revives on its bench there;
  - *anything else* (walking, travelling, on the way back): it revives in the
    **reserve**, where its card shows a dimmed portrait and a countdown. It can't
    be stationed, upgraded, sent or trained until it revives;
  - a unit on its way to another village that is downed revives in the
    reserve of the village that sent it (it never arrived).
- **Healing:** a unit heals `UNIT_REGEN` HP per second (1 HP/s) while it sits on
  a barracks bench or rests unused in the reserve. Healing mages heal too.

## 5. Barracks

- **Building:** 2×2, placed outside the walls like other buildings. Cost: 20
  building material + 30 gold, build time 16 s. Built by builders.
- **Levels** (`BARRACKS_LEVELS`), upgraded like towers with building material
  and a builder's time:

| Level | Slots (benches) | Activation range | Upgrade cost |
|---|---|---|---|
| 1 | 1 | 4.0 tiles | - |
| 2 | 2 | 5.0 tiles | 60 material, 10 s |
| 3 | 3 | 6.0 tiles | 90 material, 14 s |

- **Art** (`barracks`, `barracks_2`, `barracks_3`): like the training grounds
  (yard, small hut, fence) but without the weapons lying around. It has benches
  (one per level), a table with bread, cheese and mugs, a barrel, and a straw
  puppet with arrows stuck in it. Stationed units are drawn sitting on the
  benches.
- **Stationing:**
  - Units are stationed by drag & drop or by tapping, as with towers. A drop
    fills the first free bench.
  - The barracks panel lists each bench separately: its unit, level, HP and
    state, with Upgrade and Withdraw buttons per unit.
  - A stationed unit can be selected and dragged from its bench, like a unit on
    a tower.
- **Sorties:**
  1. When an enemy comes within the activation range, every unit on a bench that
     isn't downed goes out. Monster-camp guards count too: barracks fight them
     without an order (only the hero needs one). Barracks with only melee units
     don't turn out for flyers.
  2. *Melee* units run to the nearest enemy and fight in close combat. They
     can't go for flyers; they only counter-strike them.
  3. *Ranged* units walk until the nearest enemy is within their own range, then
     stand and shoot. Healing mages and High Priests stay among their comrades.
     Summoners stay just outside the barracks and summon there; enemies can
     attack them, and they have no attack of their own.
  4. They re-target (nearest first) and never chase beyond the activation
     range + `SORTIE_LEASH` (2 tiles).
  5. When no enemy has been in reach for 1 s, they walk back to their benches.
- **Farm defence:** with no enemy in range, barracks also turn out for rats on
  one of their village's farms within `BARRACKS_FARM_RANGE_FACTOR` (2) × their
  range. Units out for a farm stay within `FARM_DEFENSE_LEASH` (4 tiles) of it,
  and drop it as soon as an enemy comes within the barracks' own range.
- Units out on a sortie watch their surroundings, like villagers.

## 6. Units, posts and roles

| Post | Holds | Units there… |
|---|---|---|
| Tower (wall tower, watchtower) | 1 unit: ranged, summoner, healer or support | act from the tower with the tower's range; can't be hurt |
| Training grounds | 1 unit, any kind | train with the hero (up to L10); don't fight |
| Barracks | 1-3 units, any kind | sit on benches; go out on sorties; can be hurt |

- Summoners and fire summoners can serve on towers or in barracks.
- Healing mages work from towers (around the tower) and from barracks (they go
  out with the others when enemies come near).
- Shield bearers and Inquisitors are barracks-only.
- Towers, like barracks, fight monster-camp guards in range without an order.
- A witch's spell bewitches a tower's unit: no shooting, summoning or healing
  for a while (a High Priest's aura keeps working).

## 7. Upgrading and the Spatial Archmage

- **Upgrade dialog.** *Upgrade* opens a small dialog with one button per option,
  whether from the reserve or from a unit's panel on its post. Each button shows
  the cost and the option's name, level and main stats (`MilitaryUnit.option_text`),
  e.g. "Archer 6: 63 HP 29 damage every 0.55 s range 2.6" or
  "Crossbowman 1: 34 HP 50 damage every 2.25 s range 3.2".
- Every upgrade resets the unit's training XP and refills its HP. Specialising
  keeps the unit where it is, unless its new kind can't serve on its post (an
  Inquisitor on a tower): then it walks back into the reserve.
- **Training grounds:** the hero can train a unit to its next level, up to 10,
  within its own kind only. Specialising always costs gold.
- **Spatial Archmage** (spatial mage at level ≥ `ARCHMAGE_LEVEL`, 10):
  - The option reads **"Spatial Archmage: leaves the army and becomes a
    civilian"** and asks for confirmation, e.g. "This spatial mage will leave
    your army for good and move into a hut as a civilian. Continue?".
  - It needs a **free hut** and costs 600 gold (`ARCHMAGE_COST`).
  - The unit is removed from the army, from its post and from the reserve. A
    Spatial Archmage civilian moves into the free hut.
  - It can't be recruited (`"recruit": false` in `CIVILIANS`), so the Village
    tab doesn't list it. Its library entry says "Only a level 10 spatial mage
    can become one".
  - For now it is decoration: it strolls around the village walls, eats, and
    counts as a villager. Its role in the ending comes later.

## 8. Config layout (`config.gd`)

Everything stays in the config, readable by a person:

```gdscript
const MAX_UNIT_LEVEL := 10
const BRANCH_MIN_LEVEL := 3          # from this level a base unit can specialise
const ARCHMAGE_LEVEL := 10           # spatial mage -> Spatial Archmage from this level
const ARCHMAGE_COST := {"gold": 600}
const UNIT_REVIVE_TIME := [30.0, 45.0]   # seconds at level 1 / level 10 (in between: linear)
const UNIT_REGEN := 1.0              # HP per second on a barracks bench or unused in the reserve
const UNIT_MELEE_RANGE := 0.8
const SORTIE_LEASH := 2.0
const BARRACKS_LEVELS := [ {slots, range, cost, work_time}, ... ]

const MILITARY := {
    "archer": {
        "name": "Archer", "role": "ranged", "posts": ["tower", "barracks"], "recruit": true,
        "cost": {"gold": 40}, "speed": 1.8, "attack": "arrow", "range": 2.6,
        "stats": {"hp": [30.0, 90.0], "damage": [7.0, 40.0], "cooldown": [1.0, 0.45]},
        "pinned": {"damage": [7.0, 11.0, 16.0, 24.0], "cooldown": [1.0, 0.85, 0.72, 0.6]},
        "upgrade_cost": [45, 300], "upgrade_cost_pinned": [45, 80, 130],
        "train_xp": [30, 400], "train_xp_pinned": [30, 60, 100],
        "branches": ["crossbowman", "swiftbowman"],
    },
    "fire_mage": {
        "name": "Fire Mage", "role": "ranged", "recruit": false,
        "branch_of": "apprentice", "branch_cost": {"gold": 120},
        "attack": "fireball", "range": 2.8,
        "stats": {"hp": [20.0, 60.0], "damage": [10.0, 38.0], "cooldown": [0.95, 0.55], "splash": [1.2, 1.8]},
        ...
    },
    ...
}
const ATTACKS := {  # what a shot looks like, its damage category, fixed effect values
    "arrow":    {"projectile": "arrow", "arc": true, "category": "projectile", ...},
    "fireball": {"projectile": "fireball", "splash_share": 0.6, "explode": true, "category": "magical", ...},
    "warp":     {"projectile": "warp_orb", "push_immunity": 4.0, "category": "magical", ...},
    ...
}
const SUMMONS := {"earth": {"hp": 1.0, "damage": 1.0, "speed": 1.1, ...}, "fire": {"hp": 0.5, "damage": 2.5, "speed": 1.8, "self_damage": 0.25, ...}}
const SUMMON := {"attack_cooldown": 1.0, "attack_range": 0.8, "sight": 3.5, "leash": 4.0}
```

- `"stats"`: key → [level 1, level 10]. Everything that grows with the level is
  a stat of the unit, also the effects: `splash`, `slow`, `slow_time`, `heal`,
  `radius`, `push`, `aura`, and the summoners' `interval`, `max_summons`,
  `summon_hp`, `summon_damage`.
- `"pinned"`: key → the exact values of the first levels (the archer's damage and
  cooldown, the summoner's four summon stats, levels 1-4); the curve continues
  from the last pinned value. `"upgrade_cost_pinned"` / `"train_xp_pinned"` do the
  same for the gold and hero XP of the first level-ups.
- `"curve"` (optional, default 1.0 = linear) is an exponent on the curve; no unit
  sets it, so every curve is linear.
- `Config.unit_stat(kind, key, level)` reads a stat; `unit_upgrade_cost` (gold,
  rounded to 5) and `unit_train_xp` read the others.
- A test checks that every unit's own `range` is below the smallest tower range.

## 9. Art

| Sprite | Look |
|---|---|
| `barracks`, `_2`, `_3` | 2×2 yard, hut, fence; 1/2/3 benches; table with bread and mugs; barrel; straw puppet with arrows |
| `unit_shield_bearer` | smaller person behind a large tower shield (planks, iron rim, crest) |
| `unit_crossbowman` | leather armour, heavy crossbow |
| `unit_swiftbowman` | fancier archer: green-and-gold, feathered cap, a bow with several strings |
| `unit_fire_summoner` | summoner in red and orange, glowing hands |
| `unit_fire_elemental` | small hovering flame, animated (flicker and bob), no feet |
| `unit_apprentice` | young mage, dark grey robe, staff in one hand, thick tome in the other; no hat, no beard |
| `unit_fire_mage` / `unit_ice_mage` / `unit_healing_mage` / `unit_spatial_mage` | apprentice silhouette in red / light blue / green / violet, each with its own staff top |
| `unit_spatial_archmage` | civilian: robed, violet and gold, floating rune halo |
| effects | crossbow bolt; dark-blue whirling orb; sparkling fireball + explosion burst; frost orb + a blue "slowed" tint on the target; healing ring pulse + green "+HP"; violet warp orb + blink at the target |
| icons | revive countdown on reserve cards; bench markers |

The acolyte line's art is in docs/acolyte-design.md.

## 10. Code

- **`MilitaryPost` has slots.** It holds `slots` with a capacity: tower 1,
  training grounds 1, barracks by level. Commands, replication, drag & drop and
  panels work per unit.
- **Behaviours by role** (`MilitaryUnit.BEHAVIORS`, scripts/units/military/):
  - `RangedBehavior` handles every projectile or effect type through `ATTACKS`;
  - `HealerBehavior`, `SupportBehavior`;
  - `SummonerBehavior`, parametrised by summon type (`SUMMONS`);
  - melee units use the plain `MilitaryBehavior` (their fighting is in `Soldier`);
  - `Combat` plays attacks and their effects (splash, slow, push, heal, holy auras).

  The same behaviours work from a tower (tower range) and in the field (own range).
- **Field units.** `Soldier` is the unit's body outside, with HP, a combat
  behaviour, and membership of the "melee_defenders" and "field_units" groups.
  Sorties, walking, downing and reviving live there and in `Army`.
- **`MilitaryUnit`** has `hp`, `revive_left`, `kind` changes on specialising, and a
  `role()` helper.
- **Elementals:** `EarthElemental` (scripts/units/earth_elemental.gd) is both kinds,
  configured by `SUMMONS`.
- **Co-op:**
  - the replicator sends barracks slots, unit HP and revive timers, field units,
    and the projectile effects;
  - commands `upgrade_unit` (with a chosen option) and `station_unit` (with a
    slot);
  - healing covers other villages' units and heroes.
- **Tests** (tests/military_bot.gd):
  - config sanity: ranges below the tower range, curves, the tech tree is
    consistent, specialisations never weaker than their base unit;
  - barracks: slots, benches, sorties, returning;
  - downing and reviving in both places;
  - every attack type: splash, slow, heal, push;
  - branching and the archmage conversion.

## 11. Values at a glance

- Barracks: 20 material + 30 gold. Levels 1/2/3 with 1/2/3 slots and 4/5/6 tiles of range.
- Revive 30-45 s, scaling with level. Regeneration 1 HP/s on benches and in the reserve.
- Branching from level 3. The branch costs 150 gold (crossbowman, swiftbowman,
  fire summoner, inquisitor, high priest) and 120 gold for each mage.
- Spatial Archmage from spatial mage level 10, for 600 gold and a free hut.

## 12. Decisions (confirmed)

| # | Question | Decision |
|---|---|---|
| D1 | Per-level stats | **Curve** between level 1 and level 10 (linear; an optional exponent per unit, unused); the archer's and summoner's levels 1-4 are pinned |
| D2 | Hurt while walking? | **Yes**: enemies stop to fight walking units, which keep walking; downing while travelling is possible |
| D3 | Units on towers | **Can't be hurt** (witches still bewitch them) |
| D4 | Healing on their own | **On barracks benches and unused in the reserve**, both at `UNIT_REGEN` (1 HP/s); anywhere else only by healing mages |
| D5 | Revive time | **Scales with level**: 30 s at L1 → 45 s at L10 |
| D6 | Summoners in barracks | **Yes.** They step outside and summon there; enemies can attack both the summons and the summoner, which can go down. Summoners have little HP and no attack of their own |
| D7 | Healing mage | Works from **towers and barracks** (from barracks when the barracks turn out for nearby enemies). Heals field units of any village and all heroes; not summons, not villagers |
| D8 | Training into a specialisation | **No**, training only raises levels |
| D9 | Spatial Archmage | Needs a **free hut** and **600 gold**, and asks for **confirmation** |
| D10 | Own ranges | Archer 2.6, swiftbowman 2.6, crossbowman 3.2, mages 2.8, acolyte 1.6, High Priest's aura 2.6 (all below 3.6) |
| D11 | Barracks | As in §5 |
| D12 | Sortie rules | As in §5 |
| D13 | Spatial push | Back along the road 1.5 → 4 tiles; the same enemy at most once per 4 s |
| D14 | Crossbow piercing | Flag only, for now |
| D15 | Recruitable units | Archer, shield bearer, summoner, apprentice, acolyte; the summoner, the apprentice and the acolyte have to be unlocked first at their unlock sites (docs/world-design.md §9.4) |
| D16 | Upgrade costs | Gentle curve: gold for level 10 about **300** (per unit, in config) |
| D17 | Hero training XP | Rising to about 400 XP for level 10 (per unit, × difficulty) |
| D18 | Specialisations vs base unit | **Never weaker** at the same level: HP, DPS for attackers, summon stats and interval for summoners; only HP for the healing mage and the High Priest (§3) |
