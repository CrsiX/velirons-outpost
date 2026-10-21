# Veliron's Outpost: the hero (design)

Status: **built; describes the current code**. Tested by tests/sim_bot.gd (modes, XP, levels,
training, downing), tests/world_bot.gd (Explore claims and loot) and tests/coop_bot.gd (Support).
Scope: the hero: who she is, her panel, her modes, healing, XP, levels, being downed, and where
the code lives. Every number lives in `scripts/core/config.gd` (`HERO`, `HERO_LEVELS`,
`HERO_MAX_LEVEL`, `HERO_XP_PER_ACTION`, `UNIT_REVEAL`, `TRAIN_XP_DIFFICULTY`). See
docs/military-design.md for units and training grounds, docs/world-design.md §9 for the special
objects she claims and loots.

## 1. Summary

- **Half villager, half soldier**, with a sword. One per village; she starts in its centre.
- **Her post** (`Hero.home()`) is the village centre (in Support mode the supported village's). A campaign scenario can give her another
  one (`Hero.home_override`: scenario 7, her tent outside the walls until she is let in): everything this page says about "the centre"
  (standing guard, the leash, resting, healing, reviving) is then about her tent.
- **No hut, no upkeep:** she eats nothing, doesn't count as a villager or towards the hut cap,
  and isn't in the villager list.
- **The player picks her mode**; she carries it out on her own. Seven modes: Defend (default),
  Build, Explore, Gather, Train, Rest, Support (co-op only). An order to attack a monster camp
  overrides the mode until the camp is cleared.
- **XP** comes from fighting, building, exploring, looting and gathering. She spends it on her
  own levels, or passes it to a unit at the training grounds.
- **Downed** at 0 HP: she loses her unspent XP (never her levels) and comes back when the wave is
  over, or, downed between waves, when the next one begins.

## 2. Base stats (`HERO`)

| Key | Value | Meaning |
|---|---|---|
| `hp` | 60 | HP at level 1 (the level curve starts here) |
| `speed` | 1.8 | tiles per second |
| `damage` | 8 | sword damage at level 1 (the level curve starts here) |
| `attack_cooldown` | 0.9 s | between sword blows |
| `attack_range` | 0.8 tiles | close combat |
| `sight` | 4 tiles | surveillance around her while outside; also how far she notices enemies in a fight |
| `alert_radius` | 6 tiles | Defend: enemies this close to the village's walls draw her out |
| `leash` | 14 tiles | Defend: she never goes for enemies farther than this from the centre |
| `build_efficiency` | 0.5 | Build: half a builder's speed |
| `explore_reveal` | 1.8 tiles | Explore: her reveal radius (an explorer's is 2.6) |
| `gather_capacity` | 2 | Gather: corpses per trip (a gatherer carries 6) |
| `train_rate` | 10 XP/s | Train: XP passed on per second |
| `train_pause` | 4 real s | Train: pause after each level-up the unit gets |
| `rest_regen` | 3 HP/s | healing while idle in the centre |
| `rest_delay` | 3 s | idle time before the healing starts |

## 3. The top-bar button and the panel

- **Top-bar button:** the hero icon and her XP ("XP 120"). Her health bar runs along its bottom:
  green from 50 %, yellow from 20 %, red below, empty while downed. While she is downed the button
  is tinted red. Tapping it opens the panel.
- **The panel**, from top to bottom:
  - a title with her current mode's icon and word ("Hero: defending");
  - level, HP and XP;
  - one icon button per mode, the current one framed. Support only shows with more than one
    village. In Support mode a second button under the modes names the village she helps; tap it
    to cycle to the next one;
  - *Level up to N (cost XP)*, or *Highest level*. It is disabled without enough XP, and for a
    village you aren't playing;
  - "Now: ..." (her status: what she is doing right now) and a one-line hint for the mode;
  - Train only: the unit being trained, "XP so far / XP needed", the XP she has left, a progress
    bar, and the pause countdown after a level-up;
  - *Go to hero* (or the H key) moves the camera to her; while she is downed, to where she fell.
- **Mode icons:** a shield (Defend), a crossed hammer and saw (Build), a globe (Explore), a
  wheelbarrow with bones (Gather), a straw training dummy (Train), "Zzz" (Rest), a handshake
  (Support).

## 4. Modes

Changing the mode drops whatever she was doing: the old mode's job, any training, any fight.
Explore drops loot she is carrying (§4.3). The new mode starts at once, wherever she is, with no
rest first:
- **While she flees** (Build / Explore / Gather): she stops running and takes up the new mode out
  there; Defend fights the enemy she ran from if it is in her sight, else she walks back to the
  centre and takes on what comes her way (even beyond `leash`, §4.1). Only a switch to another of these three modes while an
  enemy is still close keeps her running (`Hero._stop_evading`). A camp order stops the running too.
- **Her sword's cooldown** (`attack_cooldown`) runs in every mode, also while she flees, and no mode
  change resets it, so switching modes back and forth never gives her an extra blow.
- **Build / Explore / Gather out in the field** with nothing to do yet: she walks back to the centre
  and starts work as soon as there is some (`Hero._job_idle`).

### 4.1 Defend (default)

- She waits in the village centre.
- **Choosing an enemy** (rethought every 0.3 s): only ground enemies within `leash` (14) of the
  centre count, and only those that are either
  - inside the walls, or within `alert_radius` (6) of the village's walls (any piece of its
    5×5; docs/siege-design.md §6), or
  - within her `sight` (4) of her while she is outside.
- Beyond the leash herself (another mode took her out there), enemies within her sight count
  wherever they are, so she fights her way back.
- Of those, enemies inside the walls come first; then the nearest wins, measured in whole
  tiles. Between equals, the one with the most max HP wins.
- **Last priority: rats on farms.** With nothing else to fight, she goes for rats sitting on her
  village's farms, however far out (no leash), the nearest first.
- **Flyers** (gargoyles, vampire bats) are never chosen: her sword can't reach them. When one
  hits her and her blow is ready, she strikes back once (`counter_strike`).
- With no target she walks back to the centre on a real path (she never teleports), and keeps
  looking for enemies on the way.
- She doesn't flee in this mode. Enemies fight back, and a witch's spells hurt her.

### 4.2 Build

- Like a builder (the shared `BuildJob`) at `build_efficiency` (half speed): next construction
  site, upgrade or tear-down, then home.
- She runs home from enemies like a villager.

### 4.3 Explore (`HeroExploreJob`, docs/world-design.md §9.1)

She runs from enemies like a villager. Every 0.5 s she picks the best task: the highest priority
first, then the nearest. It must be something her village has found, anywhere on the map, that
she can walk to.

1. **Claims:** awakened unit-unlock sites (stone circle, mage's tower, ruined chapel) and
   unclaimed ruined watchtowers.
   - She visits for the site's `visit_time`, or `RUIN_CLAIM_TIME` for a ruin.
   - A site unlocks its unit for every village. A ruin becomes her village's, to be restored by
     a builder.
2. **Unguarded treasures** (none of a camp's monsters alive), first come, first served.
   - She loots for the treasure's loot time, earns `loot` XP (10) and carries the loot home. It
     is paid when she gets there; a shrine's blessing gives her XP.
   - Dropped loot (a sack, see below) counts as a treasure too: she picks it up the same way, but
     earns no `loot` XP for it.
   - Every other village gets an Info message.
   - **Dropping:** if she is downed on the way, or her mode changes, the loot is left on her tile
     as *dropped loot*. The hero or a gatherer can pick it up later. An order to attack a camp
     keeps it (§4.5).
   - Fleeing from enemies doesn't drop it: running home is where she was going anyway. She is paid
     once safe.
3. **Exploring** unknown land, like an explorer (the shared `ExploreJob`), with the smaller
   `explore_reveal` (1.8). Fog it uncovers pays `explore` XP (§6).
- A task that is no longer wanted is dropped: the treasure got looted or guarded, the unit got
  unlocked, the ruin got claimed.

### 4.4 Gather

- Like a gatherer (the shared `GatherJob`), with `gather_capacity` 2 corpses per trip. She only
  goes for safe corpses on explored land, and picks up dropped loot first.
- She earns `corpse` XP (4) the moment she picks a corpse up. Back home each corpse pays
  `gold_on_collect` and `food_on_collect`.
- She runs home from enemies like a villager.

### 4.5 Attack a camp (an order, not a mode)

- Given from a monster camp's panel (*Attack with the hero*, command `attack_camp`). The camp
  must be found by her village and still attackable, and she must not be downed.
- It overrides whatever mode she is in. She fights the camp's monsters, nearest first, until none
  is left. Hurt monsters don't heal.
- She doesn't flee meanwhile.
- Only the hero needs this order: towers and barracks fight a camp's guards on their own once
  they are in range.
- In Explore mode the current task is dropped, but loot she carries is kept.
- When the camp is cleared (or gone) she goes back to her mode. If she was carrying loot, she heads
  home with it first.
- A mode button is a new order: picking any mode (her current one too) cancels the camp order at
  once ("The hero gives up on the ..."), and she does what that mode says (Rest: home, and she heals).
- She gives the order up by herself when she can't get at any of its monsters (no way to them)
  for `HERO.camp_give_up` (3 s), and goes back to her mode; she never stands stuck on it.

### 4.6 Train

- **Needs** training grounds of her village with a unit stationed there that isn't at max level
  ("ready"). She picks the nearest such grounds.
- **Without such grounds** she defends instead (status: "defending (no unit ready at training
  grounds)"). She drops any fight the moment a unit becomes ready.
- **At the grounds** she walks to their work tile and passes on `train_rate` (10) XP per second,
  sparring (a little sway). Each XP goes into the unit's training progress, never past what its
  next level needs.
- **XP needed** for the unit's next level: `MILITARY[kind].train_xp` (level 1 → 10 curve) ×
  `TRAIN_XP_DIFFICULTY` (Easy 0.8, Normal 1.0, Hard 1.5).
- When the progress reaches it, the unit **levels up for free** (no gold) and the log says so.
- **The pause:** after each level-up, if she still has XP, she stops for `train_pause` (4 s) of
  real time, whatever the game speed. The log and her panel say so, so the player can switch her
  mode and keep the rest of her XP.
- With no XP left she just stands there ("no XP left to pass on").
- A gold upgrade of the unit resets its training progress. Training never specialises a unit.

### 4.7 Rest

- She walks back to the village centre and stays there, in Rest mode until the player changes
  it. She fights nobody and flees from nobody, and heals as she idles there (§5). The panel's
  hint: "Walks back to the village centre and rests there, fighting nobody, healing as she
  idles." Her status reads "resting (HP recovering)" or "resting (full HP)".
- **Snoring:** while she rests in the centre, a "z" rises from her head every 0.8 s, fading away.
  Every third one is a bigger "Z". Co-op clients show it too.

### 4.8 Support (co-op only)

- Only with more than one village (command `hero_mode` refuses it otherwise). Picking it
  without a target sends her to the nearest other village; the second panel button (command
  `hero_support`) changes which.
- She walks there and **defends it exactly as in Defend mode**, relative to its centre and its
  gates (`base()`), including rats on *its* farms.
- She heals idling in its centre and keeps earning XP.
- The village she helps can't give her orders.
- **Downed** there, she revives in her own village's centre after the wave and walks back.

## 5. Healing

- **Resting idle** in the centre of the village she guards (her own, or the one she supports), in
  any mode, heals her.
  - "Idle" means at home, not fleeing, no target, and within 0.2 tiles of the centre.
  - After `rest_delay` (3 s) of that she gets `rest_regen` (3 HP/s) up to her max HP.
  - This also runs during a camp order, but she is rarely idle in the centre then.
  - The *Hearth stone* relic adds +1 HP/s (`RELICS.hearth.hero_rest`).
- **Healing mages** heal her (every village's hero), in their tower's range or their own radius.
- Nothing else heals her. She doesn't use the villagers' home healing.

## 6. XP (`HERO_XP_PER_ACTION`)

| Action | XP | When |
|---|---|---|
| `hit` | 2 | every sword blow that lands (counter-strikes too) |
| `kill` | +10 | extra, for the blow that kills (on top of its `hit`) |
| `build_second` | 1 | each second of construction work (Build mode) |
| `explore` | 1 | each reveal that uncovers fog (see below); each claim (unlock site, ruin) |
| `corpse` | 4 | each corpse **picked up** (Gather mode), not when it is paid at home |
| `loot` | 10 | each treasure looted in Explore mode, when the looting is done; not for picking up dropped loot again |

- **Uncovering fog outside Explore mode:** like every unit outside, she explores the fog within
  `UNIT_REVEAL` (1.8 tiles) around her. Each such reveal that uncovers something gives
  `explore` XP (`FogLayer._unit_reveal`).
- **In Explore mode** two reveals run side by side, both 1.8 tiles: the fog layer's own unit
  reveal, which pays no XP in this mode, and the Explore job's reveal (every 0.15 s while it is
  exploring unknown land), which pays `explore` XP whenever it uncovers something. So only the
  exploring part of the mode pays for fog; walking to a claim or a treasure, and carrying loot
  home, uncovers fog without XP. A claim itself pays `explore` once.
- **Shrines:** looting a shrine can pay 80-120 XP (×the tier scale) when she gets home.
- **Debug:** *+1000 XP* in the Debug dialog (command `_debug` "xp").
- Training earns nothing. No other unit ever gains XP.

## 7. Levels (`HERO_LEVELS`, `HERO_MAX_LEVEL` = 20)

- She spends her own XP in her panel (*Level up*, command `hero_level_up`), one level at a time.
- **HP and damage** grow linearly from level 1 to level 20 (`Config.hero_stat`). On a level-up she
  gains the max HP difference at once.
- **The XP cost** of each step grows linearly from 50 (1 → 2) to 400 (19 → 20)
  (`Config.hero_level_cost`). All 19 steps together cost 4275 XP.
- **The effect:** three glowing green chevrons rise over her head, she lights up for a moment, and
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

- Inside a High Priest's aura her sword deals +`aura` damage (+2 % to +20 %; the strongest aura
  counts): `Combat.holy_bonus(game, grid_pos)` in `Hero._strike`. See docs/acolyte-design.md §6.
- While she is blessed, a tiny still halo shows over her head (`UnitFx.add_halo`).
- Her sword stays *melee* damage.

## 9. Downed and revival

- **At 0 HP** she is downed:
  - the log says who struck her down and how much XP was lost (Important), and "Hero down!"
    floats up;
  - all her unspent XP is gone; her level stays;
  - she drops any camp order and her mode's work. Loot she carries is left on the spot;
  - she leaves no corpse and vanishes.
- **Revival:** when the current wave is finished (`Waves.wave_finished`), or when the next one
  begins (`Waves.wave_started`: downed between waves, say at a camp, she doesn't sit out a whole
  wave), she is back in her own village's centre with full HP, in the same mode. Her panel says
  which ("revives when the wave is over" / "... when the next wave begins"). The log says so (Info) and "The hero returns!"
  floats up.
- Commands that need her (attacking a camp) are refused while she is down.

## 10. The tutorial

- The guided tutorial sets her to **Rest** at the start, so she snores in the centre until the
  "Your hero" step asks the player to send her exploring.
- Later steps have her level up and mention passing her XP on at the training grounds. The
  tutorial tops her XP up to the next level's cost if she has less. See docs/tutorial-design.md.

## 11. Code

- `scripts/units/hero.gd` (`class_name Hero extends Civilian`):
  - the modes (`Mode`, `MODE_NAMES` / `MODE_WORDS` / `MODE_ICONS`), `set_mode`, and
    `effective_mode` (Train falls back to Defend);
  - `base()` (the village she guards);
  - Defend: `_defend`, `_pick_enemy`, `_fight`, `_chase`, `_return_home`;
  - the sword: `_strike` (holy bonus, XP), `counter_strike`;
  - healing: `_regen`;
  - levels: `level_up`, `play_level_up_fx`;
  - camps: `attack_camp`, `_attack_camp`, `_end_camp`;
  - Train: `_train`;
  - Rest: `_snore`;
  - downing: `take_damage`, `_downed`, `revive`;
  - `status()` for the panel and the villager-style status line.
  - She reuses `Civilian`'s fleeing (`wants_to_evade` only in Build / Explore / Gather and never
    during a camp order; `_stop_evading` ends it on a new order) and its path following.
- `scripts/units/jobs/`: `BuildJob`, `GatherJob` and `ExploreJob`, shared with the villagers and
  built with her weaker numbers. `HeroExploreJob` (extends `ExploreJob`) adds claims, looting,
  carrying, paying and dropping.
- `scripts/systems/commands.gd`: `hero_mode`, `hero_level_up`, `hero_support`, `attack_camp`, and
  `_debug` "xp". Every order goes through these, so co-op clients can give them.
- `scripts/ui/hud.gd`: `_build_hero_panel`, `_refresh_hero`, the top-bar button with its health
  bar, `HERO_MODE_HINTS`.
- `scripts/world/fog_layer.gd`: `_unit_reveal` (exploring XP outside Explore mode).
- `HeroExploreJob._finish`: claim XP and `loot` XP.
- `scripts/core/config.gd`: `HERO`, `HERO_MAX_LEVEL`, `HERO_LEVELS`, `hero_stat`,
  `hero_level_cost`, `HERO_XP_PER_ACTION`, `UNIT_REVEAL`, `TRAIN_XP_DIFFICULTY`, `RELICS.hearth`.
