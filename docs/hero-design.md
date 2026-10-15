# Veliron's Outpost: the hero (design)

Status: **built; describes the current code**. Tested by tests/sim_bot.gd (modes, XP, levels,
training, downing), tests/world_bot.gd (Explore claims and loot) and tests/coop_bot.gd (Support).
Scope: the hero: who he is, his panel, his modes, healing, XP, levels, being downed, and where
the code lives. Every number lives in `scripts/core/config.gd` (`HERO`, `HERO_LEVELS`,
`HERO_MAX_LEVEL`, `HERO_XP_PER_ACTION`, `UNIT_REVEAL`, `TRAIN_XP_DIFFICULTY`). See
docs/military-design.md for units and training grounds, docs/world-design.md §9 for the special
objects he claims and loots.

## 1. Summary

- **Half villager, half soldier**, with a sword. One per village; he starts in its centre.
- **No hut, no upkeep:** he eats nothing, doesn't count as a villager or towards the hut cap,
  and isn't in the villager list.
- **The player picks his mode**; he carries it out on his own. Seven modes: Defend (default),
  Build, Explore, Gather, Train, Rest, Support (co-op only). An order to attack a monster camp
  overrides the mode until the camp is cleared.
- **XP** comes from fighting, building, exploring, looting and gathering. He spends it on his
  own levels, or passes it to a unit at the training grounds.
- **Downed** at 0 HP: he loses his unspent XP (never his levels) and comes back when the wave is
  over, or, downed between waves, when the next one begins.

## 2. Base stats (`HERO`)

| Key | Value | Meaning |
|---|---|---|
| `hp` | 60 | HP at level 1 (the level curve starts here) |
| `speed` | 1.8 | tiles per second |
| `damage` | 8 | sword damage at level 1 (the level curve starts here) |
| `attack_cooldown` | 0.9 s | between sword blows |
| `attack_range` | 0.8 tiles | close combat |
| `sight` | 4 tiles | surveillance around him while outside; also how far he notices enemies in a fight |
| `alert_radius` | 6 tiles | Defend: enemies this close to a gate draw him out |
| `leash` | 14 tiles | Defend: he never goes for enemies farther than this from the centre |
| `build_efficiency` | 0.5 | Build: half a builder's speed |
| `explore_reveal` | 1.8 tiles | Explore: his reveal radius (an explorer's is 2.6) |
| `gather_capacity` | 2 | Gather: corpses per trip (a gatherer carries 6) |
| `train_rate` | 10 XP/s | Train: XP passed on per second |
| `train_pause` | 4 real s | Train: pause after each level-up the unit gets |
| `rest_regen` | 3 HP/s | healing while idle in the centre |
| `rest_delay` | 3 s | idle time before the healing starts |

## 3. The top-bar button and the panel

- **Top-bar button:** the hero icon and his XP ("XP 120"). His health bar runs along its bottom:
  green from 50 %, yellow from 20 %, red below, empty while downed. While he is downed the button
  is tinted red. Tapping it opens the panel.
- **The panel**, from top to bottom:
  - a title with his current mode's icon and word ("Hero: defending");
  - level, HP and XP;
  - one icon button per mode, the current one framed. Support only shows with more than one
    village. In Support mode a second button under the modes names the village he helps; tap it
    to cycle to the next one;
  - *Level up to N (cost XP)*, or *Highest level*. It is disabled without enough XP, and for a
    village you aren't playing;
  - "Now: ..." (his status: what he is doing right now) and a one-line hint for the mode;
  - Train only: the unit being trained, "XP so far / XP needed", the XP he has left, a progress
    bar, and the pause countdown after a level-up;
  - *Go to hero* (or the H key) moves the camera to him; while he is downed, to where he fell.
- **Mode icons:** a shield (Defend), a crossed hammer and saw (Build), a globe (Explore), a
  wheelbarrow with bones (Gather), a straw training dummy (Train), "Zzz" (Rest), a handshake
  (Support).

## 4. Modes

Changing the mode drops whatever he was doing: the old mode's job, any training, any fight.
Explore drops loot he is carrying (§4.3).

### 4.1 Defend (default)

- He waits in the village centre.
- **Choosing an enemy** (rethought every 0.3 s): only ground enemies within `leash` (14) of the
  centre count, and only those that are either
  - within `alert_radius` (6) of one of the village's gates, or
  - within his `sight` (4) of him while he is outside.
- Of those, the nearest wins, measured in whole tiles. Between equals, the one with the most max
  HP wins.
- **Last priority: rats on farms.** With nothing else to fight, he goes for rats sitting on his
  village's farms, however far out (no leash), the nearest first.
- **Flyers** (gargoyles, vampire bats) are never chosen: his sword can't reach them. When one
  hits him and his blow is ready, he strikes back once (`counter_strike`).
- With no target he walks back to the centre on a real path (he never teleports), and keeps
  looking for enemies on the way.
- He doesn't flee in this mode. Enemies fight back, and a witch's spells hurt him.

### 4.2 Build

- Like a builder (the shared `BuildJob`) at `build_efficiency` (half speed): next construction
  site, upgrade or tear-down, then home.
- He runs home from enemies like a villager.

### 4.3 Explore (`HeroExploreJob`, docs/world-design.md §9.1)

He runs from enemies like a villager. Every 0.5 s he picks the best task: the highest priority
first, then the nearest. It must be something his village has found, anywhere on the map, that
he can walk to.

1. **Claims:** awakened unit-unlock sites (stone circle, mage's tower, ruined chapel) and
   unclaimed ruined watchtowers.
   - He visits for the site's `visit_time`, or `RUIN_CLAIM_TIME` for a ruin.
   - A site unlocks its unit for every village. A ruin becomes his village's, to be restored by
     a builder.
2. **Unguarded treasures** (none of a camp's monsters alive), first come, first served.
   - He loots for the treasure's loot time, earns `loot` XP (10) and carries the loot home. It
     is paid when he gets there; a shrine's blessing gives him XP.
   - Dropped loot (a sack, see below) counts as a treasure too: he picks it up the same way, but
     earns no `loot` XP for it.
   - Every other village gets an Info message.
   - **Dropping:** if he is downed on the way, or his mode changes, the loot is left on his tile
     as *dropped loot*. The hero or a gatherer can pick it up later. An order to attack a camp
     keeps it (§4.5).
   - Fleeing from enemies doesn't drop it: running home is where he was going anyway. He is paid
     once safe.
3. **Exploring** unknown land, like an explorer (the shared `ExploreJob`), with the smaller
   `explore_reveal` (1.8). Fog it uncovers pays `explore` XP (§6).
- A task that is no longer wanted is dropped: the treasure got looted or guarded, the unit got
  unlocked, the ruin got claimed.

### 4.4 Gather

- Like a gatherer (the shared `GatherJob`), with `gather_capacity` 2 corpses per trip. He only
  goes for safe corpses on explored land, and picks up dropped loot first.
- He earns `corpse` XP (4) the moment he picks a corpse up. Back home each corpse pays
  `gold_on_collect` and `food_on_collect`.
- He runs home from enemies like a villager.

### 4.5 Attack a camp (an order, not a mode)

- Given from a monster camp's panel (*Attack with the hero*, command `attack_camp`). The camp
  must be found by his village and still attackable, and he must not be downed.
- It overrides whatever mode he is in. He fights the camp's monsters, nearest first, until none
  is left. Hurt monsters don't heal.
- He doesn't flee meanwhile.
- Only the hero needs this order: towers and barracks fight a camp's guards on their own once
  they are in range.
- In Explore mode the current task is dropped, but loot he carries is kept.
- When the camp is cleared (or gone) he goes back to his mode. If he was carrying loot, he heads
  home with it first.

### 4.6 Train

- **Needs** training grounds of his village with a unit stationed there that isn't at max level
  ("ready"). He picks the nearest such grounds.
- **Without such grounds** he defends instead (status: "defending (no unit ready at training
  grounds)"). He drops any fight the moment a unit becomes ready.
- **At the grounds** he walks to their work tile and passes on `train_rate` (10) XP per second,
  sparring (a little sway). Each XP goes into the unit's training progress, never past what its
  next level needs.
- **XP needed** for the unit's next level: `MILITARY[kind].train_xp` (level 1 → 10 curve) ×
  `TRAIN_XP_DIFFICULTY` (Easy 0.8, Normal 1.0, Hard 1.5).
- When the progress reaches it, the unit **levels up for free** (no gold) and the log says so.
- **The pause:** after each level-up, if he still has XP, he stops for `train_pause` (4 s) of
  real time, whatever the game speed. The log and his panel say so, so the player can switch his
  mode and keep the rest of his XP.
- With no XP left he just stands there ("no XP left to pass on").
- A gold upgrade of the unit resets its training progress. Training never specialises a unit.

### 4.7 Rest

- He walks back to the village centre and stays there, in Rest mode until the player changes
  it. He fights nobody and flees from nobody, and heals as he idles there (§5). The panel's
  hint: "Walks back to the village centre and rests there, fighting nobody, healing as he
  idles." His status reads "resting (HP recovering)" or "resting (full HP)".
- **Snoring:** while he rests in the centre, a "z" rises from his head every 0.8 s, fading away.
  Every third one is a bigger "Z". Co-op clients show it too.

### 4.8 Support (co-op only)

- Only with more than one village (command `hero_mode` refuses it otherwise). Picking it
  without a target sends him to the nearest other village; the second panel button (command
  `hero_support`) changes which.
- He walks there and **defends it exactly as in Defend mode**, relative to its centre and its
  gates (`base()`), including rats on *its* farms.
- He heals idling in its centre and keeps earning XP.
- The village he helps can't give him orders.
- **Downed** there, he revives in his own village's centre after the wave and walks back.

## 5. Healing

- **Resting idle** in the centre of the village he guards (his own, or the one he supports), in
  any mode, heals him.
  - "Idle" means at home, not fleeing, no target, and within 0.2 tiles of the centre.
  - After `rest_delay` (3 s) of that he gets `rest_regen` (3 HP/s) up to his max HP.
  - This also runs during a camp order, but he is rarely idle in the centre then.
  - The *Hearth stone* relic adds +1 HP/s (`RELICS.hearth.hero_rest`).
- **Healing mages** heal him (every village's hero), in their tower's range or their own radius.
- Nothing else heals him. He doesn't use the villagers' home healing.

## 6. XP (`HERO_XP_PER_ACTION`)

| Action | XP | When |
|---|---|---|
| `hit` | 2 | every sword blow that lands (counter-strikes too) |
| `kill` | +10 | extra, for the blow that kills (on top of its `hit`) |
| `build_second` | 1 | each second of construction work (Build mode) |
| `explore` | 1 | each reveal that uncovers fog (see below); each claim (unlock site, ruin) |
| `corpse` | 4 | each corpse **picked up** (Gather mode), not when it is paid at home |
| `loot` | 10 | each treasure looted in Explore mode, when the looting is done; not for picking up dropped loot again |

- **Uncovering fog outside Explore mode:** like every unit outside, he explores the fog within
  `UNIT_REVEAL` (1.8 tiles) around him. Each such reveal that uncovers something gives
  `explore` XP (`FogLayer._unit_reveal`).
- **In Explore mode** two reveals run side by side, both 1.8 tiles: the fog layer's own unit
  reveal, which pays no XP in this mode, and the Explore job's reveal (every 0.15 s while it is
  exploring unknown land), which pays `explore` XP whenever it uncovers something. So only the
  exploring part of the mode pays for fog; walking to a claim or a treasure, and carrying loot
  home, uncovers fog without XP. A claim itself pays `explore` once.
- **Shrines:** looting a shrine can pay 80-120 XP (×the tier scale) when he gets home.
- **Debug:** *+1000 XP* in the Debug dialog (command `_debug` "xp").
- Training earns nothing. No other unit ever gains XP.

## 7. Levels (`HERO_LEVELS`, `HERO_MAX_LEVEL` = 20)

- He spends his own XP in his panel (*Level up*, command `hero_level_up`), one level at a time.
- **HP and damage** grow linearly from level 1 to level 20 (`Config.hero_stat`). On a level-up he
  gains the max HP difference at once.
- **The XP cost** of each step grows linearly from 50 (1 → 2) to 400 (19 → 20)
  (`Config.hero_level_cost`). All 19 steps together cost 4275 XP.
- **The effect:** three glowing green chevrons rise over his head, he lights up for a moment, and
  the log and a floating "Level N!" say so. Co-op clients play it too.

| Level | HP | Damage | XP to the next |
|---|---|---|---|
| 1 | 60 | 8.0 | 50 |
| 2 | 74 | 10.9 | 69 |
| 3 | 87 | 13.9 | 89 |
| 4 | 101 | 16.8 | 108 |
| 5 | 115 | 19.8 | 128 |
| 6 | 128 | 22.7 | 147 |
| 7 | 142 | 25.7 | 167 |
| 8 | 156 | 28.6 | 186 |
| 9 | 169 | 31.6 | 206 |
| 10 | 183 | 34.5 | 225 |
| 11 | 197 | 37.5 | 244 |
| 12 | 211 | 40.4 | 264 |
| 13 | 224 | 43.4 | 283 |
| 14 | 238 | 46.3 | 303 |
| 15 | 252 | 49.3 | 322 |
| 16 | 265 | 52.2 | 342 |
| 17 | 279 | 55.2 | 361 |
| 18 | 293 | 58.1 | 381 |
| 19 | 306 | 61.1 | 400 |
| 20 | 320 | 64.0 | (top) |

## 8. The High Priest's blessing

- Inside a High Priest's aura his sword deals +`aura` damage (+2 % to +20 %; the strongest aura
  counts): `Combat.holy_bonus(game, grid_pos)` in `Hero._strike`. See docs/acolyte-design.md §6.
- While he is blessed, a tiny still halo shows over his head (`UnitFx.add_halo`).
- His sword stays *melee* damage.

## 9. Downed and revival

- **At 0 HP** he is downed:
  - the log says who struck him down and how much XP was lost (Important), and "Hero down!"
    floats up;
  - all his unspent XP is gone; his level stays;
  - he drops any camp order and his mode's work. Loot he carries is left on the spot;
  - he leaves no corpse and vanishes.
- **Revival:** when the current wave is finished (`Waves.wave_finished`), or when the next one
  begins (`Waves.wave_started`: downed between waves, say at a camp, he doesn't sit out a whole
  wave), he is back in his own village's centre with full HP, in the same mode. His panel says
  which ("revives when the wave is over" / "... when the next wave begins"). The log says so (Info) and "The hero returns!"
  floats up.
- Commands that need him (attacking a camp) are refused while he is down.

## 10. The tutorial

- The guided tutorial sets him to **Rest** at the start, so he snores in the centre until the
  "Your hero" step asks the player to send him exploring.
- Later steps have him level up and mention passing his XP on at the training grounds. The
  tutorial tops his XP up to the next level's cost if he has less. See docs/tutorial-design.md.

## 11. Code

- `scripts/units/hero.gd` (`class_name Hero extends Civilian`):
  - the modes (`Mode`, `MODE_NAMES` / `MODE_WORDS` / `MODE_ICONS`), `set_mode`, and
    `effective_mode` (Train falls back to Defend);
  - `base()` (the village he guards);
  - Defend: `_defend`, `_pick_enemy`, `_fight`, `_chase`, `_return_home`;
  - the sword: `_strike` (holy bonus, XP), `counter_strike`;
  - healing: `_regen`;
  - levels: `level_up`, `play_level_up_fx`;
  - camps: `attack_camp`, `_attack_camp`, `_end_camp`;
  - Train: `_train`;
  - Rest: `_snore`;
  - downing: `take_damage`, `_downed`, `revive`;
  - `status()` for the panel and the villager-style status line.
  - He reuses `Civilian`'s fleeing (`wants_to_evade` only in Build / Explore / Gather and never
    during a camp order) and its path following.
- `scripts/units/jobs/`: `BuildJob`, `GatherJob` and `ExploreJob`, shared with the villagers and
  built with his weaker numbers. `HeroExploreJob` (extends `ExploreJob`) adds claims, looting,
  carrying, paying and dropping.
- `scripts/systems/commands.gd`: `hero_mode`, `hero_level_up`, `hero_support`, `attack_camp`, and
  `_debug` "xp". Every order goes through these, so co-op clients can give them.
- `scripts/ui/hud.gd`: `_build_hero_panel`, `_refresh_hero`, the top-bar button with its health
  bar, `HERO_MODE_HINTS`.
- `scripts/world/fog_layer.gd`: `_unit_reveal` (exploring XP outside Explore mode).
- `HeroExploreJob._finish`: claim XP and `loot` XP.
- `scripts/core/config.gd`: `HERO`, `HERO_MAX_LEVEL`, `HERO_LEVELS`, `hero_stat`,
  `hero_level_cost`, `HERO_XP_PER_ACTION`, `UNIT_REVEAL`, `TRAIN_XP_DIFFICULTY`, `RELICS.hearth`.
