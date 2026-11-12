# Veliron's Outpost: items, equipment and relics (design)

Status: **the equipment is built** (§2-4, §6: `Config.ITEMS`, `ITEM_SLOTS`, `ITEM_DEFAULTS`,
`ARMOURY`; `Hero` equipment section, `Armoury`, the `equip` / `unequip` commands, the hero
panel's slots and the armoury dialog, a library page per slot, `items_bot`), and so is **where
equipment comes from** (§5: `ItemDrops`, `Config.ITEM_SOURCES`; the market's equipment offer,
`MARKET` "item_offer"), and so are **relics** (§7: `Config.RELICS`, `Relics`; village-wide and
map-wide relics in `Village.relics` and the armoury's Relics tab; the market's relic offer,
brought by its trader, `MARKET` "relic_after"; the library's Relics page; the tactical map's
rumours), and so is **selling them** at the market, to the guild or another player
(docs/market-design.md §8.1). Numbers live in
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

- An **item** is one single thing a village has: equipment or a relic, **never both**.
- **Effects are modifiers, never flat stats:** a share of damage, a damage category, a chance,
  a flag ("reaches flyers"). The hero's damage grows from level 1 to `HERO_MAX_LEVEL`; a flat
  "+10 damage" would be huge at level 1 and nothing at level 20.
- **Equipment works only while the hero wears it; a relic works just by the village having it,
  and is never worn.** A ring works on her finger; a banner works by being in the town hall.
  One rule the player can read off the kind of item, never off the single item. An effect
  that needs the hero to wear something is equipment; a static effect for a village or the
  whole map is a relic. A relic may still touch the hero (the Hearth stone), as long as it
  works by being had, not worn.
- **Duplicates are allowed, the effect counts once.** Two of the same relic give its effect
  once; the second is only worth selling. **Bonuses from different sources all count** (a
  "more gold per kill" relic and the matching advancement both count). Equipment modifiers are
  factors and multiply: across slots and with every other source (the war cry, a High Priest's
  blessing, critical hits), which the code already applies as factors.
- **Map-wide relics** affect every village or every enemy on the map. Had by several villages,
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

- The town hall's store of equipment not worn and of the village's relics,
  capped at a number of both together (`ARMOURY`, `Armoury.count`). Taken-off items go there;
  nothing is lost by swapping. The armoury dialog has a Relics tab next to the four slots: what
  the village holds, a duplicate with its count. Why relics take room: a relic is a thing the
  village keeps like any item, and a full armoury is a reason to sell one or leave one
  lying; uncapped, duplicates would pile up for free.
- Items leave it by being worn, sold (docs/market-design.md §8) or traded to another player.
- A devastated town hall closes the armoury (no swaps), but its relics **keep working**:
  losing every relic to one raid would be too harsh.

## 5. Where items come from

Built (`ItemDrops`, `Config.ITEM_SOURCES`; relics: `Relics`, §7). Every
non-default piece of equipment can come from every equipment source, all equally likely: there is no rarity, and a
rarity would push every game towards the same few rare "best" items.

- **The market's rotating offer** (docs/market-design.md §8), with a relic offer (§7).
- **Treasures and lairs**, as relics come today. The generator puts an item into some tier-2
  and tier-3 treasures that hold gold (never a shrine; a relic wins first), with a cap per
  village slice, so co-op slices stay fair. Those rolls use their own seeded numbers, so the
  rest of a seed's map stays as it was. A cleared lair's sack sometimes holds an item, after
  its relic chance. `RELIC_MAX` stays a limit on the generator only; a later generator may
  rework relics as treasures. Where items are off (the tutorial, the backdrop, a scenario
  without them), a treasure holding an item pays gold instead, so a map file can always hold
  one. Map files name the item (`"equipment"`, format 7), and the editor offers it.
- **Carriers:** some enemies carry an item: camp monsters (a chance for one per camp), lair
  guardians (a chance each time a lair wakes), and rarely one enemy of a late wave. Never
  ordinary early wave enemies, or gatherers drown in swords. Never water-only, flying, boss
  or named enemies either: what they drop would land out of reach or steal a scripted
  moment. A carrier is marked with a **glint** (drawn, not new art; its `fx`, so co-op
  clients see it too), so the player can decide "go get that".
- **Dropped items are a sack, not a corpse:** corpses rot, sink and get raised, and an item
  must not vanish with them. The sack lands on the nearest free tile, open ground before
  forest (none within the drop radius: the item is lost), and **stays until picked up**. It
  glints like a carrier (`ItemDrops.draw_glint`): a small sack is easily hidden behind the
  trees of the tile in front of it in the isometric view, and the glint stands above them. An item is rare, so losing it to a
  timer would feel bad.
- **Bringing it home:** a gatherer, the hero gathering or the hero exploring brings it to the
  town hall's armoury. They leave it lying while the armoury is full. If it fills up while
  the item is on the way, the item goes into a sack by the town hall, never lost.
- **Unnamed until home:** a treasure, a sack or a carrier only says "an item". The market's
  offer is the exception: there one buys a known thing.
- **Campaign:** items are set per scenario (offers, drops and carriers scripted in
  `scenario_<n>.gd`); **nothing carries over** between scenarios by design. The hooks:
  `Scenario.item_pool` (the items random sources may give) and `Scenario.item_carriers`
  (random carriers at all; off by default, so a scenario only has what it scripts: a wave
  entry's `"item"` in `Waves.add_to_wave`, `ItemDrops.give` / `drop`, a map treasure's
  `"equipment"`). Equipment is introduced around scenario 4
  (docs/scenarios-design.md); no scenario uses it yet.
- **Campaign items** (`Config.ITEMS` `"campaign"`, `Config.campaign_item`): story items only a
  scenario gives, today the First King's Hand (rescued in scenario 9). Scenario 9 gives it as
  its abbey's `"item"` reward; scenarios 10 and 11 hand it over in their setup as if it came
  from 9 (`Scenario.campaign_items`), since nothing carries over. A village keeps them in
  `Village.items`, never in the armoury, so they can't be worn, sold or traded; no random source,
  market offer, map file, the editor or the debug page gives one, and the library doesn't list
  them (`Config.ordinary_item` is the one check). Why: a story relic bought in a skirmish would
  cheapen it, and the Hand isn't Brenna's to wield (only House Aldmoor's). Why an `ITEMS`
  entry at all: one name, text and icon for it, where a bare string was before.

## 6. Equipment list

All of them are built. Every share,
chance and duration is a `Config.ITEMS` value. How the open points were settled:

- **Buckler, magical shield:** "a share of hits" is a chance per hit to block it whole.
- **Great axe:** her reach stays the sword's, with no reach from the shore at a monster on deep
  water (`AQUA.melee_reach`, which every other blade gets): such a monster is no target unless it
  is within that reach, and no one in the circle either. In practice the great axe doesn't fight
  water monsters out on deep water (feather boots let her walk out to them). Why: one rule for
  the whole weapon (everything she hits is within the circle, her target always among them),
  and a trade-off the player can read.
- **Mace:** the enemy behind is the nearest one close to the spot a tile beyond the target, on
  the line from her through it.
- **Throwing axes:** projectile damage; like every ranged attack they reach flyers; no blade,
  so no critical hits (every other weapon crits).
- **Flame sword:** reaches a siren in water the way a fire elemental's blow does.
- **Net:** on its cooldown she throws it at her current target in range; the target neither
  moves nor attacks (`Enemy.net`). Bosses are kinds marked `pin_proof` in `ENEMIES`, plus
  every named enemy and every water-only kind.
- **Rose necklace:** a share less poison, not immunity. **Cleaver:** heals a
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
| Great axe | hits every enemy in a full circle around her, less damage per target; she still picks where to stand, but never one target. (A circle, not an arc: she has no facing direction in the simulation.) No reach from the shore: see below. |
| Blessed blade | holy damage |
| Throwing axes | a short ranged attack |

### Armour

| Item | Effect |
|---|---|
| Leather armour *(default)* | no effect |
| Full plate | slower, takes less damage |
| Bearskin | faster, deals more damage, takes more damage |
| Buckler | blocks a share of melee and projectile hits |
| Magical shield | negates a share of magical hits |
| Thorn mail | reflects a share of melee damage |

### Accessory

| Item | Effect |
|---|---|
| Soldier's helmet *(default)* | no effect |
| Net | thrown on its own on a cooldown: pins an enemy in place and stops it attacking for a few seconds. Never on water-only enemies or bosses. (The first idea, dragging the enemy along behind her, was dropped: it needs new path-following for enemies.) |
| Rose necklace | resists poison |
| Ring of might | more damage (a share) |
| Lantern | reveals ghosts near her |
| Gatherer's satchel | carries more when gathering |
| Builder's gloves | builds faster |
| Scholar's tome | more XP |

### Movement

| Item | Effect |
|---|---|
| Soldier's boots *(default)* | no effect |
| Swift boots | faster walking |
| Feather boots | free movement: she crosses forest, deep water and walls (no gate needed), and swamp and shallow water don't slow her. In return her attacks are slower and flyers deal her a multiple of their damage. An octopus can still grab her and pull her into deep water, but deep water doesn't kill her while she wears them. Needs a path grid of her own. |
| Heavy steel boots | slower; nothing moves or holds her: immune to the siren's song (pull and slow), the octopus grapple, roots (a wrathwood's roots grow on her and fall off at once), the net and any future pin (`Unit.forced`). Terrain (swamp, shallow water) still slows her. |
| Pathfinder's boots | explores a wider area |

Dropped: **the horse** (mounted hero). It would have needed the enemy-only mounted rules
(`Config.MOUNTED`) on the player's side and a mount that dies for good.

## 7. Relics

Built: `Config.RELICS` and `Relics` (the pool, who has what, the bonuses, bringing one home).
Relics are special, individual goods with a static village-wide or map-wide effect that works
just by a village having one; **a relic is never worn, and no equipment is a relic** (§2).
They are not unique on the map; a duplicate counts once. Every number is in `Config.RELICS`;
here only what each does. Kept in `Village.relics`, with room in the armoury (§4); a devastated
hall closes the armoury, but its relics keep working.

- **Village-wide** (`"reach": "village"`): works for the village that has it, read through
  `Village.relic_bonus` (`Relics.bonus`), each kind once.
- **Map-wide** (`"map"`): works for everyone while any village that hasn't fallen has one,
  once however many have it (`Relics.map_bonus`). Why only standing villages: a fallen village
  can use nothing, and its relics shouldn't outlive it.

Why never worn: a relic that is also an accessory blurs the one rule the player reads off a
kind of item, and an effect on the hero's own body is what equipment is for.

**Village-wide:**

| Relic | Effect |
|---|---|
| Hawk-eye relic | towers (and the town hall's post) reach farther |
| Phoenix feather | downed units come back sooner |
| Hearth stone | the hero heals faster resting at home (the centre and the hall) |
| Harvest idol | farms yield more food |
| Woodcutter's axe | foresters chop faster (not carry more) |
| Mason's seal | cheaper repairs (adds to the Cheaper repairs advancement) |
| Tithe box | more gold per kill (adds to Skilled looting) |
| Old kings' banner | units in a tower attack faster (only while stationed there) |
| Cartographer's chart | places the village hasn't found show as a "?" on the tactical map, never what they are (`TacticalMap.is_rumour`: not sacks or landmarks) |
| Toll charter | lower market tax |
| Grave salt | corpses rot later where this village is the nearest (a corpse belongs to no village, so the nearest one decides) |

**Map-wide:**

| Relic | Effect |
|---|---|
| Sun disc | the undead (unholy kinds, raised and undead enemies) take more holy damage (`Enemy.damage_factor`) |
| Peace ribbon | the help tax is lower for everyone (`Relics.help_tax`); co-op only (`"coop"`): it never comes in a one-village game |
| Stormglass | a siren's and an octopus's dive when hurt is shorter (`Relics.dive_time`). Crabs riding under deep water aren't affected: that is how they move, not a dive to escape |

**Where they come from:** generated relic treasures (`RELIC_MAX` per map), a cleared lair's
loot (one the village doesn't have yet where it can) and the market's relic offer (its trader
brings a new one every stretch of his time there, the old one gone, bought or not;
docs/market-design.md §8). All pick
from `Relics.pool`: every relic, without the co-op ones in a one-village game. A map's relic
the game can't use is swapped for a village-wide one on
setup (`Relics.usable`), so a map file may name any relic. Bringing one home goes through
`Relics.bring_home`; a full armoury leaves it lying (looters skip it, `ItemDrops.room_for`) or,
once home, in a sack by the town hall, as with items. A dropped relic's sack glints and says
only "a relic".

**Dropped:** a "Wardline bell" (longer wave countdown): a countdown is shared in co-op, so a
village-wide effect can't work.

**Cursed relics (an idea, not for now):** strong for the owner with a downside, often for
everyone (e.g. a Crown of thorns: more damage for its owner, more HP for enemies everywhere),
the kind of thing one wants to sell on.

## 8. Scope and other modes

- **Campaign:** off unless a scenario switches it on (§5, `Scenario.items`) and has a town hall
  (`Scenario.town_hall`, docs/village-design.md §3c: no hall, no armoury); off in the
  tutorial and the title backdrop (`Game.items_enabled`). Relics don't need items: a map's
  relic treasure or a lair still gives one where items are off. No scenario names a relic.
  Campaign items (§5) need neither: they never go through the armoury.
- **Co-op:** items and relics are sold between players at an asking price
  (docs/market-design.md §8.1); each hero has her own slots and each village its armoury.
- **Save:** the hero's slots and the armoury are saved (built), and so are the items' own
  timers (the net's cooldown): unlike an AI's cooldowns
  they outlast a wave (a camp fight between waves), so every future item with a cooldown or a
  per-wave charge gets its line in the hero's `"eqt"`. A camp or lair guard's item is saved
  with the guard. Dropped items are sacks, so they are part of the map. The market's offer
  is saved too, its relic offer and the trader's time since he brought it as well (`"ro"`,
  `"st"`). A wave's carriers are not: nothing of a
  running wave is saved. A village's relics are saved as a list, duplicates kept.
- **Commands:** equip and unequip are `Commands`, and so are selling an item, taking it back and
  buying another player's (docs/market-design.md §9).
- **Library:** a page per slot (Weapons, Armour, Accessories, Movement) and a Relics page
  (village-wide, map-wide), built from `Config`; the Places page has one Relics entry pointing
  there.
- **Icons:** every item has one (`Config.item_icon`: a dark badge ringed in its slot's colour)
  and every relic too (`Config.relic_icon`: the same badge with a gold rim and studs, so a relic
  reads as one), drawn by `tools/art/icons.py` (`ITEM_ICONS`, `RELIC_ICONS`). A text shows one with `{item:<id>}` /
  `{relic:<id>}` (`Hud.icon_bbcode`; `Relics.token` picks the right one): the market's offers and
  the floating text of what came home.
- **Tests:** `items_bot` (defaults leave the hero unchanged, each effect, swap rules, carriers
  and their sacks, gathering home, a full armoury, the market's offer, every relic's effect,
  duplicates and map-wide relics counting once, relics in the armoury, the relic offer, the
  save). The balancing bot's `equipment` policy equips the hero (docs/balance-bot-design.md §3).
