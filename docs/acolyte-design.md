# Veliron's Outpost: the acolyte line (design)

Status: **built** (decisions in §9 confirmed with the user). Tested by tests/military_bot.gd.
Scope: a recruitable unit, the **Acolyte**, with holy damage, two specialisations (the
**Inquisitor** and the **High Priest**), unlocked at a site, the **Ruined chapel**.
Numbers live in `scripts/core/config.gd` (`MILITARY.acolyte`, `.inquisitor`, `.high_priest`,
`ATTACKS`, `UNLOCK_SITES.chapel`, `ENEMIES.*.resist`), never here. General unit rules (levels,
HP, downing, barracks, specialising): docs/military-design.md.

## 1. Summary

- **Acolyte:** a ranged unit for towers and barracks, a thin golden beam from above that lands
  instantly as **holy** damage. It is meant as the answer to the undead (skeleton, necromancer,
  vampire) that other damage handles badly, not as a better archer: HP like the archer's,
  damage a little lower, and a much shorter field range, so on a sortie it must stand close to
  what it fights. On a tower it uses the tower's range like everyone.
- **Look:** robed, hands folded in prayer, with a soft pulsing light behind it everywhere it is
  shown; it raises its arms and the light flares when it casts. The look is what tells the
  player "this one is holy" at a glance.
- **Unlock:** the **Ruined chapel**, an unlock site like the stone circle and the mage's tower,
  so the acolyte is a find on the map, not a purchase.
- **Specialisations** from level 3:
  - **Inquisitor:** holy melee that hunts witches first, then the unholy. Barracks or training
    grounds only, never towers (a melee unit on a tower would have nothing to do).
  - **High Priest:** support. An aura makes everyone around it hit harder, slows necromancers'
    raising and speeds up reviving on benches. A weak counter-strike is all the melee it has.

## 2. Tech tree

```
Acolyte ────────────┬──────►  Inquisitor   (holy melee, hunts witches and the unholy; barracks only)
  (ranged, holy)    └──────►  High Priest  (aura: allies deal more damage; necromancers raise slower)
```

## 3. Holy damage factors (`resist` "holy" in `ENEMIES`)

The factors are data on each enemy, not here. The reasoning:

- The unholy (skeleton, necromancer, vampire) take more holy damage, the necromancer and
  vampire most: they are the enemies the line exists for. The goblin-like kinds (goblin, orc,
  thief, gargoyle) take a little less, so an acolyte is not simply the best unit against a
  plain wave. Animals and the rest are neutral.
- Anything a necromancer raises takes an extra multiplier on top of its kind's (`raised_holy`):
  holy power undoes what the necromancer did.
- **Unholy:** the flag `"unholy": true` marks the kinds the Inquisitor hunts. Everything a
  necromancer raises counts as unholy too. The Inquisitor's targeting uses the flag, so a
  future undead kind only needs it set.

## 4. Acolyte

- **Stats** are the archer's shape with damage a little lower, so level 3 acolyte vs archer is a
  trade: holy damage and the aura-friendly line vs raw DPS.
- **The beam** (`ATTACKS.holy_beam`: no projectile, a `"burst"`): the hit lands at once, the
  effect only dresses it (golden beam from high above, flash on the ground). It is replicated
  like every burst.
- **Light and prayer:** the spec's `"glow"` puts the light behind the figure wherever it is
  shown (tower, field, bench, training grounds); `"cast_art"` is the raised-arms frame shown
  for a moment at each attack.

## 5. Inquisitor

- **Attack:** "smite", a melee strike with holy damage and a flash of holy light on the target.
  Level 1 is at least as strong as a level 3 acolyte, level 10 above the acolyte's: the
  specialisation rules, docs/military-design.md §3.
- **Fighting:** on a barracks sortie it fights like the shield bearer: closes in and strikes.
  Like every ground melee unit it can't go for flyers; it only counter-strikes them.
- **Choosing a target (`"hunt"` in its spec):** each enemy within the barracks' reach gets an
  **effective distance**: real distance minus a bonus; the lowest wins. Witches get the biggest
  bonus (they hurt from afar and are frail: kill them first), the unholy a smaller one, all
  others none. Each bonus applies only within a cap, beyond which the enemy counts like any
  other, so the Inquisitor doesn't run across the field after a far-off witch.
  Example of the effect: a witch somewhat farther away beats a nearer goblin; a witch beyond
  the cap counts at its real distance, like a goblin.
- **Leaving a fight:** it breaks off its current fight (any target, also a prioritised one)
  only when another enemy is at least `hunt_switch` better in effective distance. That stops
  it flip-flopping between two enemies.
- **Posts:** no towers. An acolyte that turns into an Inquisitor on a tower (or on its way to
  one) leaves it and walks back into the reserve (`Army.upgrade` withdraws it instead of
  refusing the upgrade). In barracks or on the training grounds it stays.

## 6. High Priest

- **Role:** `"support"`, no attack of its own. When an enemy hits it in melee and its blow is
  ready, it strikes back once. Only its HP counts for the specialisation rules.
- **The aura** (`aura`: a fraction of damage added):
  - **Applies to every blow:** the hero's sword and elementals' blows take it too, not only units' attacks (`Combat.attack`).
  - **Where it works:** on a tower always, as far as the tower reaches (so tower upgrades widen
    it); in barracks within its own range, from the yard's middle while it sits on its bench
    and from where it stands on a sortie; not on the training grounds and not while walking.
    A witch's spell doesn't stop it (bewitching only stops attacks and summons).
  - **Who gets it:** every allied unit of any village: soldiers in the field, tower units (their
    attacks), the hero and summons. Barracks and a priest's tower are where the player puts
    their damage dealers, so the aura rewards clustering around it.
  - **No stacking:** each unit takes the strongest aura it stands in. It changes neither range
    nor heals, only damage dealt.
  - **The halo:** a buffed unit shows a tiny, still holy circle over its head so the player can
    see who is covered.
  - **Reviving** (`revive`, `Combat.revive_rate`): units downed on a bench of a barracks within
    an aura (the nearest point of its yard in reach) return faster; the strongest counts, any
    village's barracks. They come back as always, on their bench with full HP. A downed sitter's
    clock is golden with a pale rim while an aura speeds it up.
  - **Necromancers:** raising takes longer (`necro_slow`) when the necromancer or the corpse is
    inside an aura. The spell still works: it slows, never shuts the necromancer off.
  - **Invisible enemies** (none yet): `Combat.in_holy_aura(game, grid_pos)` is the hook; enemies
    inside an aura will be revealed once they exist.

## 7. Ruined chapel (unlock site)

- **Config:** `UNLOCK_SITES.chapel` (wave, distance, visit time, what it unlocks);
  `LOCKED.acolyte = "chapel"`. It sits farther out than the other sites and awakens later,
  because the acolyte is a late counter to late enemies.
- **Look** (art `chapel_ruin` / `chapel_awake`): a small stone chapel with a broken roof, a bell
  in a little open bell-cote, ivy and rubble. Awake, a shaft of golden light falls through the
  broken roof and motes drift up.
- Everything else works as for the other sites: rumour, found message, Explore mode goes there
  first, unlocked for every village, a library entry under Places.

## 9. Decisions (confirmed)

1. Unlock site: the Ruined chapel, far out and late.
2. Animation and look: prayer posture, glow, beam from above, raised arms when casting.
3. Holy factors by kind (§3).
4. Inquisitor: bonuses for witches and the unholy with caps, and a switch margin.
5. High Priest: the aura works in barracks too, on the bench and on a sortie; it boosts summons
   too; units downed on a bench in it revive faster (no stacking).
6. The Inquisitor may stand on the training grounds.
7. Every military unit can go in barracks (already the case).
