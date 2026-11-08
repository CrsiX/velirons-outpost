# Veliron's Outpost: items, equipment and relics (design)

Status: **the equipment is built** (§2-4, §6: `Config.ITEMS`, `ITEM_SLOTS`, `ITEM_DEFAULTS`,
`ARMOURY`; `Hero` equipment section, `Armoury`, the `equip` / `unequip` commands, the hero
panel's slots and the armoury dialog, a library page per slot, `items_bot`). **Not built yet:**
where items come from (§5; for now only the debug page's *Give item...*), relics as items (§7:
the four relics of today, `Config.RELICS`, still work as before and are not in the armoury),
selling and trading items (docs/market-design.md §8). Numbers live in
`scripts/core/config.gd`, never here.
Scope: items (equipment and relics), the hero's slots, the armoury, where items come from,
the item list. Buying and selling items is in docs/market-design.md; the town hall (home of the
armoury) in docs/village-design.md; the hero in docs/hero-design.md.

## 1. Why

- **The hero only grows by XP today.** Levels make her stronger but never *different*. Items
  change *how* she fights (fire instead of melee, reach for flyers, a circle of blows) and give
  the player choices that depend on the map and the waves.
- **Relics today are a dead end.** Four kinds, at most `RELIC_MAX` per map, a bonus that simply
  happens. As items they become things a village holds, can lose interest in, sell or trade.

## 2. Items

- An **item** is one single thing a village holds: equipment, a relic, or both (a worn relic).
- **Effects are modifiers, never flat stats:** a share of damage, a damage category, a chance,
  a flag ("reaches flyers"). The hero's damage grows from level 1 to `HERO_MAX_LEVEL`; a flat
  "+10 damage" would be huge at level 1 and nothing at level 20.
- **Each item works either while owned or while worn, never both.** A ring works on her
  finger; a banner works by being in the town hall. One rule the player can read off the item.
- **Duplicates are allowed, the effect counts once.** Two of the same relic give its effect
  once; the second is only worth selling. **Bonuses from different sources all count** (a
  "more gold per kill" relic and the matching advancement both count). Equipment modifiers are
  factors and multiply: across slots and with every other source (the war cry, a High Priest's
  blessing, critical hits), which the code already applies as factors.
- **Map-wide relics** affect every village or every enemy on the map. Owned by several players,
  they still apply once.

## 3. The hero's slots

Four slots, each with a default item. **The default items are exactly today's hero**, so
nothing changes in balance until something is equipped.

| Slot | Meaning | Default |
|---|---|---|
| Weapon | how she attacks | longsword (melee) |
| Armour | how she takes hits | leather armour (no effect) |
| Accessory | the catch-all slot: anything that fits nowhere else | soldier's helmet (no effect) |
| Movement | how she moves | soldier's boots (no effect) |

- **Slots, not a bag:** a bag of "any X items" invites stacking (three flame swords) and makes
  a weapon compete with boots.
- **Effects across slots multiply** where they overlap (full plate's slowness and swift boots
  roughly cancel): trade-offs across slots are the point.
- **The defaults are not items.** An empty slot *is* its default; taking an item off sends it
  to the armoury and shows the default again. Defaults are never in the armoury, can't be given
  or sold, and don't count towards its cap.
- **Swapping** is a command (`equip`, `unequip`), only while she is idle at her post in her own
  village (`Hero.swap_error`: in any mode, standing at her post or resting inside the hall; not
  downed, fleeing, fighting or on a camp order) and the hall is not devastated. The hero panel
  shows the four slots; tapping one opens the armoury for that slot. No swapping mid-fight:
  lance for the flyers, then back to the axe, would be micromanagement.
- **A full armoury** refuses taking an item off (and new items); a straight swap always works,
  since the item put on frees its place.
- **Being downed** loses unspent XP as today, never items.
- **Hero only.** Soldiers already grow by levels and specialisations.

## 4. The armoury

- The town hall's store of items not worn (and, once relics are items, of owned relics),
  capped at a number of items (`ARMOURY`). Taken-off items go there; nothing is lost by
  swapping.
- Items leave it by being worn, sold (docs/market-design.md §8) or traded to another player.
- A devastated town hall closes the armoury (no swaps), but owned relics **keep working**:
  losing every relic to one raid would be too harsh.

## 5. Where items come from

- **The market's rotating offer** and **relic offers** (docs/market-design.md §8).
- **Treasures and lairs**, as relics come today. `RELIC_MAX` stays a limit on the generator
  only; a later generator may rework relics as treasures.
- **Carriers:** some enemies carry an item and drop it on their corpse: camp monsters (a chance
  for one per camp), lair guardians, and rarely an enemy in a late wave. Never ordinary early
  wave enemies, or gatherers drown in swords. A carrier is marked with a **glint**, not new
  art, so the player can decide "go get that". A gatherer (or the hero gathering) brings the
  item to the town hall's armoury.
- **Campaign:** items are set per scenario (offers, drops and carriers scripted in
  `scenario_<n>.gd`); **nothing carries over** between scenarios by design. A scenario can
  script a carry-over itself, as scenarios 9 to 11 will do with the rescued sword. Equipment is
  introduced around scenario 4 (docs/scenarios-design.md).

## 6. Equipment list

Marked *(proposed)*: suggested in the design session; all of them are built. Every share,
chance and duration is a `Config.ITEMS` value. How the open points were settled:

- **Buckler, magical shield:** "a share of hits" is a chance per hit to block it whole.
- **Mace:** the enemy behind is the nearest one close to the spot a tile beyond the target, on
  the line from her through it.
- **Throwing axes:** projectile damage; like every ranged attack they reach flyers; no blade,
  so no critical hits (every other weapon crits).
- **Flame sword:** reaches a siren in water the way a fire elemental's blow does.
- **Net:** on its cooldown she throws it at her current target in range; the target neither
  moves nor attacks (`Enemy.net`). Bosses are kinds marked `pin_proof` in `ENEMIES`, plus
  every named enemy and every water-only kind.
- **Phoenix pendant:** the killing blow leaves her at a share of her max HP; ready again when
  each wave starts. **Rose necklace:** a share less poison, not immunity. **Cleaver:** heals a
  share of the damage actually dealt. **Thorn mail:** reflects a share of a melee hit as pure
  damage.

### Weapon

| Item | Effect |
|---|---|
| Longsword *(default)* | today's hero: melee |
| Flame sword | fire instead of melee |
| Poison-coated sword | melee, plus a poison dose of a share of the hit (the undead, aberrations and buildings ignore the dose, as for any poison) |
| Cleaver | heals her a share of the damage dealt |
| Mace | also hits the enemy behind the target for a share of the damage |
| Lance | longer reach, and she can hit flyers, as the halberdier can |
| Great axe | hits every enemy in a full circle around her, less damage per target; she still picks where to stand, but never one target. (A circle, not an arc: she has no facing direction in the simulation.) |
| Blessed blade *(proposed)* | holy damage |
| Throwing axes *(proposed)* | a short ranged attack |

### Armour

| Item | Effect |
|---|---|
| Leather armour *(default)* | no effect |
| Full plate | slower, takes less damage |
| Bearskin | faster, deals more damage, takes more damage |
| Buckler | blocks a share of melee and projectile hits |
| Magical shield | negates a share of magical hits |
| Thorn mail *(proposed)* | reflects a share of melee damage |

### Accessory

| Item | Effect |
|---|---|
| Soldier's helmet *(default)* | no effect |
| Net | thrown on its own on a cooldown: pins an enemy in place and stops it attacking for a few seconds. Never on water-only enemies or bosses. (The first idea, dragging the enemy along behind her, was dropped: it needs new path-following for enemies.) |
| Rose necklace | resists poison |
| Ring of might | more damage (a share) |
| Lantern *(proposed)* | reveals ghosts near her |
| Gatherer's satchel *(proposed)* | carries more when gathering |
| Builder's gloves *(proposed)* | builds faster |
| Scholar's tome *(proposed)* | more XP |
| Phoenix pendant *(proposed, worn relic)* | once per wave she survives a killing blow |
| Seer's eye *(proposed, worn relic)* | more sight |

### Movement

| Item | Effect |
|---|---|
| Soldier's boots *(default)* | no effect |
| Swift boots | faster walking |
| Feather boots | free movement: she crosses forest, deep water and walls (no gate needed), and swamp and shallow water don't slow her. In return her attacks are slower and flyers deal her a multiple of their damage. An octopus can still grab her and pull her into deep water, but deep water doesn't kill her while she wears them. Needs a path grid of her own. |
| Heavy steel boots | slower; nothing moves or holds her: immune to the siren's song (pull and slow), the octopus grapple, roots, the net and any future pin (`Unit.forced`). Terrain (swamp, shallow water) still slows her. |
| Pathfinder's boots *(proposed)* | explores a wider area |

Dropped: **the horse** (mounted hero). It would have needed the enemy-only mounted rules
(`Config.MOUNTED`) on the player's side and a mount that dies for good.

## 7. Relics

Relics become items: special, individual goods with a village-wide or map-wide effect. They
are not unique on the map; a duplicate's effect counts once. The four existing relics
(Hawk-eye, Phoenix feather, Hearth stone, Harvest idol) keep their effects as owned relics.

**Owned (village-wide), proposed:**

| Relic | Effect |
|---|---|
| Woodcutter's axe | foresters chop faster (not carry more) |
| Mason's seal | cheaper repairs |
| Tithe box | more gold per kill |
| Old kings' banner | tower units attack faster |
| Cartographer's chart | map objects show as rumours on the tactical map |
| Toll charter | lower market tax |
| Grave salt | corpses rot slower |

**Map-wide, proposed:**

| Relic | Effect |
|---|---|
| Sun disc | the undead everywhere take more holy damage |
| Peace ribbon | the help tax is halved for everyone |
| Stormglass | water monsters dive less |

**Worn:** the Phoenix pendant and Seer's eye (accessories, §6).

**Dropped:** a "Wardline bell" (longer wave countdown): a countdown is shared in co-op, so a
village-wide effect can't work.

**Cursed relics (an idea, not for now):** strong for the owner with a downside, often for
everyone (e.g. a Crown of thorns: more damage for its owner, more HP for enemies everywhere),
the kind of thing one wants to sell on.

## 8. Scope and other modes

- **Campaign:** off unless a scenario switches it on (§5, `Scenario.items`); off in the
  tutorial and the title backdrop (`Game.items_enabled`).
- **Co-op:** items and relics are sold between players at an asking price
  (docs/market-design.md §7); each hero has her own slots and each village its armoury.
- **Save:** the hero's slots and the armoury are saved (built). Owned relics, carriers' items
  and dropped items will need `SaveGame.capture` / restore lines and a `SaveGame.FORMAT` bump.
- **Commands:** equip and unequip are `Commands` (built); sell will be one.
- **Library:** a page per slot (built: Weapons, Armour, Accessories, Movement) and later one for
  relics, built from `Config`.
- **Tests:** `items_bot` (built: defaults leave the hero unchanged, each effect, swap rules,
  the save; later carriers and drops). The balancing bot learns to equip items later.
