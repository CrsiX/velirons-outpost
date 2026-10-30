# Veliron's Outpost: the acolyte line (design)

Status: **built** (decisions in §9 confirmed with the user). Tested by tests/military_bot.gd.
Scope: a recruitable unit, the **Acolyte**, with holy damage. It has two specialisations,
the **Inquisitor** and the **High Priest**, and is unlocked at a site, the **Ruined chapel**.
Every number lives in `scripts/core/config.gd`. See docs/military-design.md for the general unit
rules (levels, HP, downing, barracks, specialising).

## 1. Summary

- **Acolyte** (recruit, 50 gold): a ranged unit for towers and barracks.
  - **Attack:** a thin golden beam comes straight down from above onto the enemy. It hits
    instantly and does **holy** damage.
  - **HP and damage:** HP like the archer's, damage a little lower (DPS 6.5 → 75 against the
    archer's 7 → 89).
  - **Range:** much shorter in the field (1.6 tiles, the archer's is 2.6). On a tower it uses
    the tower's range like everyone.
- **Look:** robed, hands folded in prayer, head bowed. A soft, pulsing light glows behind it
  all the time. When it casts, it raises its arms (a second sprite frame) and the light flares.
- **Unlock:** the **Ruined chapel**, an unlock site like the stone circle and the mage's
  tower. It awakens at **wave 6**, 16-24 tiles from a village, and the hero visits it.
- **Holy damage:** every enemy kind has a holy factor (§3).
- **Specialisations** from level 3 (100 gold each):
  - **Inquisitor:** melee, holy cross and warhammer. Hunts witches first, then the unholy,
    then anything else. Barracks or training grounds only, never towers.
  - **High Priest:** support. An aura gives allies +2 % to +20 % damage, slows necromancers'
    raising, and later reveals invisible enemies. Weak melee counter-strike.

## 2. Tech tree

```
Acolyte ────────────┬──────►  Inquisitor   (holy melee, hunts witches and the unholy; barracks only)
  (ranged, holy)    └──────►  High Priest  (aura: allies deal more damage; necromancers raise slower)
```

## 3. Holy damage factors (`resist` "holy" in `ENEMIES`)

| Enemy | Holy factor |
|---|---|
| Goblin | ×0.75 |
| Skeleton | ×1.25 |
| Ork | ×0.75 |
| Slime (every size) | ×1.0 |
| Witch | ×1.0 |
| Rat | ×1.0 |
| Thief | ×0.75 |
| Gargoyle | ×0.75 |
| Necromancer | ×1.5 |
| Vampire (and its bat form) | ×1.5 |
| Raised by a necromancer | its kind's factor ×2.0 (`raised_holy`) |

- **Unholy:** the flag `"unholy": true` marks the skeleton, the necromancer and the
  vampire. Everything a necromancer raises counts as unholy too. The Inquisitor's targeting
  uses the flag, so a future undead kind only needs it set.

## 4. Acolyte

- **Config:** `role` "ranged", `posts` tower and barracks, `attack` "holy_beam", `range` 1.6.
- **Stats:**
  - HP 30 → 90, like the archer.
  - Damage 6.5 → 36 per hit, every 1.0 → 0.48 s. That's about 6.5 → 75 DPS, against the
    archer's 7 → 89.
- **The beam** (`ATTACKS.holy_beam`: no projectile, `"burst": "holy_beam"`):
  - The hit lands at once.
  - The effect draws a golden beam from high above down onto the target, with a flash on the
    ground. It is replicated like every burst.
- **Light and prayer:**
  - Its spec sets `"glow"`, which puts a soft pulsing light behind the figure wherever it is
    shown: on a tower, in the field, on a bench, on the training grounds.
  - Its spec also sets `"cast_art"`, a second sprite with raised arms. It is shown for a moment
    each time it attacks, from a tower and in the field.

## 5. Inquisitor

- **Config:** `role` "melee", `posts` barracks only (training grounds take anyone),
  `attack` "smite".
  - "smite" is a melee strike with holy damage. Every hit also shows a flash of holy light
    on the target (`"burst": "holy_flash"`).
- **Stats:** HP 45 → 140, damage 17 → 57, every 1.1 → 0.75 s: about 15.5 → 76 DPS. Level 1
  at least as strong as a level 3 acolyte (43 HP, 14.8 DPS), level 10 above the acolyte's
  (90 HP, 75 DPS): the specialisation rules, docs/military-design.md §3.
- **Fighting:** on a barracks sortie it fights like the shield bearer: closes in and strikes.
  Like every ground melee unit, it can't go for flyers; it only counter-strikes them.
- **Choosing a target (`"hunt"` in its spec):** each enemy within the barracks' reach gets an
  **effective distance**: its real distance minus a bonus. The lowest wins.
  - **Witches:** bonus 4 tiles, but only within 7 tiles of the Inquisitor.
  - **Unholy** (skeletons, necromancers, vampires, anything raised): bonus 2 tiles, but only
    within 5 tiles.
  - Beyond those caps a witch or an unholy enemy gets no bonus: it counts like any other enemy.
  - **Everything else:** no bonus.
  - So a witch 6 tiles away beats a goblin 2.5 tiles away (6 − 4 = 2 < 2.5). A skeleton 3 tiles
    away beats a goblin 1.5 tiles away (3 − 2 = 1 < 1.5). A witch 8 tiles away counts as 8 tiles, like a goblin.
- **Leaving a fight:** it breaks off its current fight (any target, also a prioritised one)
  only when another enemy is at least `hunt_switch` (1 tile) better in effective distance.
  That stops it flip-flopping between two enemies.
- **Posts:** no towers.
  - An acolyte that turns into an Inquisitor on a tower (or on its way to one) leaves it and
    walks back to the village into the reserve.
  - In barracks or on the training grounds it stays.

## 6. High Priest

- **Config:** `role` "support", `posts` tower and barracks, `attack` "strike" (melee),
  `range` 2.6 (the aura's radius in the field).
- **Stats:**
  - HP 44 → 95: level 1 at least a level 3 acolyte's 43, level 10 above its 90 (with no
    real attack, only its HP counts for the specialisation rules, docs/military-design.md §3).
  - Counter-strike: damage 3 → 10, every 1.4 → 1.0 s.
  - `aura`: 0.02 → 0.20 (+2 % → +20 % damage).
  - `revive`: 1.25 → 3.0 (how many times as fast units downed on a bench in the aura revive).
- **No attack of its own.** When an enemy hits it in melee and its blow is ready, it strikes
  back once.
- **The aura:**
  - **Where it works:**
    - On a tower, always, as far as the tower reaches (so tower upgrades widen it).
    - In barracks, within its own 2.6 tiles: from the yard's middle while it sits on its
      bench, from where it stands while out on a sortie.
    - On the training grounds and while walking it does nothing.
    - A witch's spell doesn't stop it (bewitching only stops attacks and summons).
  - **Who gets it:** every allied unit, of any village: soldiers in the field, units on towers
    (their attacks), the hero and summons (earth and fire elementals).
  - **The bonus:** +`aura` × damage on every hit they deal. The bonus doesn't stack: each unit
    takes the strongest aura it stands in. It doesn't change range, and heals aren't boosted.
  - **The halo:** a buffed unit shows a tiny, still holy circle over its head, as long as the
    buff lasts. On a tower it shows over the unit's figure.
  - **Reviving:** units downed on a barracks bench (docs/military-design.md) whose barracks
    is in an aura (the nearest point of its 2x2 yard within reach: its own barracks, and
    those right around it) count down to their return `revive` times as fast
    (`Combat.revive_rate`; the strongest aura counts, no stacking; any village's barracks).
    They come back as always: on their bench with full HP. A downed sitter shows a clock
    on its bench, golden with a pale rim while an aura speeds it up.
  - **Necromancers:** raising takes `necro_slow` (×2) as long when the necromancer or the
    corpse is inside an aura. The spell still works.
  - **Invisible enemies** (none yet): `Combat.in_holy_aura(game, grid_pos)` is the hook. Enemies
    inside an aura will be revealed once they exist.

## 7. Ruined chapel (unlock site)

- **Config:** `UNLOCK_SITES.chapel`: wave 6, distance 16-24, visit time 5 s, unlocks
  "acolyte". `LOCKED.acolyte = "chapel"`.
- **Look** (art `chapel_ruin` / `chapel_awake`): a small stone chapel with a broken roof, a
  bell in a little open bell-cote, ivy and rubble. Awake, a shaft of golden light falls
  through the broken roof, the arched window glows and motes drift up.
- Everything else works as for the other sites: rumour, found message, Explore mode goes there
  first, unlocked for every village, a library entry under Places.

## 8. Code

- `Config`: the three units, `holy_beam` / `smite` in `ATTACKS`, holy factors and `unholy`
  flags, the chapel, `LOCKED`, `MILITARY_ORDER` / `MILITARY_TREE`.
- `Combat`:
  - `attack` multiplies damage by `1 + holy_bonus(game, attacker position)` and plays the
    attack's `burst`.
  - `holy_bonus(game, grid_pos)`, `in_holy_aura(game, grid_pos)`, and the list of auras,
    cached per frame.
- The hero's sword and elementals' blows also take the bonus.
- `SupportBehavior` (`role` "support"): no tick work; panel lines.
- `Soldier`:
  - The Inquisitor's hunt targeting.
  - Support units keep with their comrades on a sortie, like healers.
  - The High Priest's melee counter-strike in `take_damage`.
- `NecromancerBehavior`: cast time ×`necro_slow` inside an aura.
- `Army.upgrade`: a unit that can't stay on its post as its new kind is withdrawn into the
  reserve, instead of the upgrade being refused.
- `UnitFx`: the acolyte's glow, the cast frame and the halo, attached to whatever sprite
  shows a unit.
- `Burst`: "holy_beam" and "holy_flash".
- Art: `unit_acolyte`, `unit_acolyte_cast`, `unit_inquisitor`, `unit_high_priest`,
  `chapel_ruin`, `chapel_awake`.

## 9. Decisions (confirmed)

1. Unlock site: the Ruined chapel; distance 16-24 is fine; wave 6.
2. Animation and look as proposed (prayer posture, glow, beam from above, raised arms when
   casting).
3. Holy factors as in §3.
4. Recruit cost 50 gold.
5. Inquisitor: bonus 4 tiles for witches, 2 for the unholy; caps raised slightly to 7 and 5
   tiles; switch margin 1 tile.
6. High Priest: the aura works in barracks too, on the bench and on a sortie; it boosts
   summons too; units downed on a bench in it revive x1.25 → x3 as fast (no stacking).
7. The Inquisitor may stand on the training grounds.
8. Every military unit can go in barracks (already the case).
