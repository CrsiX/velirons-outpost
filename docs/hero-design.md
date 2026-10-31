# Veliron's Outpost: the hero (design)

Status: **built; describes the current code**. Tested by tests/sim_bot.gd (modes, XP, levels,
training, downing), tests/world_bot.gd (Explore claims and loot) and tests/coop_bot.gd (Support).
Scope: why the hero works the way she does: her panel, her modes, healing, XP, levels, being
downed. Every number lives in `scripts/core/config.gd` (`HERO`, `HERO_LEVELS`,
`HERO_MAX_LEVEL`, `HERO_XP_PER_ACTION`, `UNIT_REVEAL`, `TRAIN_XP_DIFFICULTY`); the behaviour is in
`scripts/units/hero.gd`. See docs/military-design.md for units and training grounds,
docs/world-design.md §9 for the special objects she claims and loots.

## 1. Summary

- **Half villager, half soldier**, with a sword. One per village; she starts in its centre.
- **Her post** (`Hero.home()`) is the village centre (in Support mode the supported village's).
  A campaign scenario can give her another (`Hero.home_override`, scenario 7: her tent outside
  the walls until she is let in); everything below about "the centre" (standing guard, the leash,
  resting, healing, reviving) is then about her tent.
- **No hut, no upkeep:** she eats nothing, doesn't count as a villager or towards the hut cap,
  and isn't in the villager list. She is the player's one flexible agent, not a population
  unit, so losing her never starves or shrinks the village.
- **The player picks her mode**; she carries it out on her own. Seven modes: Defend (default),
  Build, Explore, Gather, Train, Rest, Support (co-op only). An order to attack a monster camp
  overrides the mode until the camp is cleared.
- **XP** comes from fighting, building, exploring, looting and gathering. She spends it on her
  own levels, or passes it to a unit at the training grounds: the one decision that makes her
  XP a real trade-off.
- **Downed** at 0 HP: she loses her unspent XP (never her levels) and comes back when the wave is
  over, or, downed between waves, when the next one begins.

## 2. Base stats (`HERO`)

`Config.HERO` holds her base stats and the tunables of each mode (speed, sword, sight, alert
radius, leash, build efficiency, reveal radius, gather capacity, training rate and pause, rest
regeneration). The design points behind them:

- Her HP and damage at level 1 are the start of the level curves (§7).
- In the villager jobs she is deliberately a little worse than the specialist (half a builder's
  speed, a smaller reveal radius than an explorer, a smaller load than a gatherer). She can fill
  a gap, but never replaces the villagers.
- `leash` bounds how far Defend chases, so she can't be lured across the map; `alert_radius`
  makes her react to the walls, not just the gates.

## 3. The top-bar button and the panel

- **Top-bar button:** the hero icon and her XP. A health bar runs along its bottom (green, yellow,
  red by share; empty while downed), and it is tinted red while she is downed, so her state is
  readable without opening anything.
- **The panel**, top to bottom: a title with her mode's icon and word; level, HP and XP; one icon
  button per mode, the current one framed (Support only with more than one village; in Support a
  second button names the village she helps and cycles); *Level up* (disabled without XP, and for
  a village you aren't playing); "Now: ..." (what she is doing right now) with a one-line hint for
  the mode; for Train, the unit, its progress and her leftover XP and the pause countdown; *Go to
  hero* (the H key), which goes to where she fell while she is downed.
- **Mode icons** (`Hero.MODE_ICONS`) are wordless on purpose: shield, crossed hammer and saw,
  globe, wheelbarrow with bones, straw dummy, "Zzz", handshake.

## 4. Modes

Changing the mode drops whatever she was doing: the old job, any training, any fight. Explore drops
loot she is carrying (§4.3). The new mode starts at once, wherever she is, with no rest first, so a
mode button is always an immediate command:

- **While she flees** (Build / Explore / Gather) she stops running and takes up the new mode
  out there. Defend fights the enemy she ran from if it is in sight, else she walks back and takes
  on what comes her way (even beyond the leash). Only a switch to another of the three villager
  modes with an enemy still close keeps her running (`Hero._stop_evading`). A camp order stops the
  running too.
- **Her sword's cooldown** runs in every mode, also while she flees, and no mode change resets it:
  switching modes back and forth must never give an extra blow (an exploit that would otherwise
  be the best way to fight).
- **Build / Explore / Gather out in the field** with nothing to do yet: she walks back to the centre
  and starts work as soon as there is some (`Hero._job_idle`).

### 4.1 Defend (default)

- She waits in the village centre. The choice of enemy is rethought often (`Hero._pick_enemy`).
- **Who counts:** ground enemies within the leash of the centre that are inside the walls, near
  the wall ring (docs/siege-design.md §6) or within her sight while she is outside. Beyond the
  leash herself (another mode took her out there) enemies in sight count wherever they are, so
  she fights her way back instead of standing helpless.
- **Priority:** inside the walls first (a breach is the worst case), then the nearest, and
  between equals the one with the most max HP (the biggest threat).
- **Last priority: rats on farms.** With nothing else to fight she goes for rats on her village's
  farms, however far out, because nobody else would and they eat the food the village lives on.
- **Flyers** are never chosen: her sword can't reach them. When one hits her and her blow is
  ready she strikes back once (`counter_strike`), so she isn't a punching bag but is no anti-air.
- With no target she walks back on a real path (never teleports) and keeps looking on the way.
- She doesn't flee in this mode: Defend is the mode where she is meant to be in danger.

### 4.2 Build

- Like a builder (the shared `BuildJob`) at reduced efficiency: next site, upgrade or tear-down,
  then home. She runs from enemies like a villager. Her value is as a second builder when the
  village is short of one.

### 4.3 Explore (`HeroExploreJob`, docs/world-design.md §9.1)

She runs from enemies like a villager. She re-picks her task often: highest priority first, then
the nearest, from what her village has found and she can walk to. The ordering is about what only
she can do and what is most valuable first:

1. **Claims:** awakened unit-unlock sites and unclaimed ruined watchtowers. A site unlocks its unit
   for every village; a ruin becomes her village's, to be restored by a builder. These come first
   because they unlock whole parts of the game.
2. **Unguarded treasures,** first come, first served, so co-op villages race for them. She carries
   the loot home and is paid there (a shrine's blessing gives XP); other villages get an Info
   message.
   - Dropped loot counts as a treasure too, without paying XP again (no farming a drop).
   - **Dropping:** downed on the way, or a changed mode, leaves it on her tile for the hero or a
     gatherer to pick up. A camp order keeps it. Fleeing doesn't drop it: running home is where
     she was going anyway.
3. **Exploring** unknown land like an explorer (the shared `ExploreJob`), with a smaller reveal
   radius.
- **Sites she fled from** (`HeroExploreJob._blocked_sites`): she sets a site aside together with
  the enemies she fled from and goes for another; with every site set aside she explores near
  them (fog near them counts extra, `Config.EXPLORE`) so she stays close, and looks again from
  time to time. Once none of those enemies is alive near the site it is wanted again. This keeps
  her from either suiciding at a site or abandoning it forever.
- A task that is no longer wanted (looted, guarded, unlocked, claimed) is dropped.

### 4.4 Gather

- Like a gatherer (the shared `GatherJob`) with a smaller load. She only goes for safe corpses on
  explored land and picks up dropped loot first. XP is paid when a corpse is picked up, while the
  gold and food are paid at home as for any gatherer. She runs from enemies like a villager.

### 4.5 Attack a camp (an order, not a mode)

- Given from a monster camp's panel (*Attack with the hero*, command `attack_camp`); the camp must
  be found by her village and attackable, and she must not be downed. It is an order, not a mode,
  because it is a one-off goal with an end: she goes back to her mode afterwards.
- It overrides whatever mode she is in. She fights the camp's monsters, nearest first, and
  doesn't flee meanwhile. Hurt monsters don't heal, so retreating is not punished (the player can
  wear a camp down in steps; towers and barracks do it on their own once in range, so only the
  hero needs the order).
- Explore's task is dropped but carried loot is kept; once the camp is cleared she heads home with
  it first.
- A mode button is a new order: any mode (her current one too) cancels the camp order at once.
  The player is never trapped in an order.
- She gives the order up by herself when she can't get at any monster for a short time
  (`HERO.camp_give_up`), so she never stands stuck on it.

### 4.6 Train

- **Needs** training grounds of her village with a unit stationed there that isn't at max level.
  **Without** she defends instead and drops any fight the moment a unit becomes ready, so
  selecting Train never leaves her idle and defenceless.
- **At the grounds** she walks to their work tile and passes on XP at a steady rate, never past
  what the unit's next level needs. XP needed is the kind's `MILITARY[kind].train_xp` curve,
  scaled by difficulty (`TRAIN_XP_DIFFICULTY`).
- When the progress is full the unit **levels up for free** (no gold).
- **The pause:** after each level-up, if she still has XP, she stops for `HERO.train_pause` in
  **real** time, whatever the game speed, so the player has time to switch her mode and keep the
  rest of her XP. Without it the XP would drain into the next level whether the player wanted it
  or not.
- **Gold and XP mix 1:1:** the share of the next level's XP the unit already has comes off that
  level's gold price (`TRAIN_GOLD_DISCOUNT`; `MilitaryUnit.upgrade_cost`), so partial training is
  never wasted. Specialising costs its full price (training can't pay for a branch choice). A
  gold upgrade resets the unit's training progress. Training never specialises a unit.

### 4.7 Rest

- She walks back to the village centre and stays, fighting nobody and fleeing from nobody, healing
  as she idles (§5), until the player changes the mode. It is the "keep her safe" button.
- **Snoring:** a rising "z" (every third bigger) shows she is resting, a cheap readable cue
  (co-op clients show it too).

### 4.8 Support (co-op only)

- Only with more than one village. Picking it without a target sends her to the nearest other
  village; the second panel button (`hero_support`) changes which.
- She walks there and **defends it exactly as in Defend mode**, relative to its centre and walls
  (`base()`), including rats on its farms. She heals idling in its centre and keeps earning XP.
- The village she helps can't give her orders, so help can't be turned into a hijack.
- **Downed** there, she revives in her own village after the wave and walks back.

## 5. Healing

- **Resting idle** at the centre of the village she guards, in any mode, heals her: idle means at
  home, not fleeing, no target, near the centre; after a short delay she regenerates up to max
  HP. The delay stops her healing in the middle of a fight she merely paused. Relics can add to
  it (`RELICS.hearth.hero_rest`).
- **Healing mages** heal her (every village's hero), by their tower's range or their own radius.
- Nothing else heals her; she doesn't use the villagers' home healing, so the village centre is
  the place that matters.

## 6. XP (`HERO_XP_PER_ACTION`)

XP comes from every kind of work she does (a sword hit, with a bonus for the killing blow;
seconds of building; reveals of fog; claims; corpses picked up; treasures looted), so every
mode makes her stronger and Explore, Gather and Build are not a sacrifice. The weights are in
`HERO_XP_PER_ACTION`.

- **Uncovering fog, always:** whenever she uncovers new tiles she earns `explore` XP, in every
  mode and whatever she is doing. Like every unit outside she explores the fog around her
  (`UNIT_REVEAL`, `FogLayer._unit_reveal`); in Explore her job reveals as well. A tile is new only
  once, so nothing is paid twice.
- Corpse XP is paid on pick-up, not at home; loot XP when the looting is done and not for
  picking up dropped loot again.
- **Shrines:** looting a shrine pays a bigger XP lump when she gets home.
- Training earns nothing. No other unit ever gains XP.
- Debug builds: *+1000 XP* in the Debug dialog (command `_debug` "xp").

## 7. Levels (`HERO_LEVELS`, `HERO_MAX_LEVEL`)

- She spends her own XP in her panel (*Level up*, command `hero_level_up`), one level at a time:
  the player decides when, and whether to keep XP for the training grounds instead.
- **HP and damage** grow linearly across the levels (`Config.hero_stat`), and a level-up adds the
  max HP difference at once. **The XP cost** per step also grows linearly
  (`Config.hero_level_cost`). Linear, not exponential, so a late level is always within reach and
  the choice between levels and training stays alive. The per-level table is derived from these
  curves; read it off the functions rather than keeping a copy.
- **The effect:** glowing green chevrons rise over her head, the log and a floating "Level N!" say
  so; co-op clients play it too.

## 8. The High Priest's blessing

- Inside a High Priest's aura her sword deals extra damage (the strongest aura counts):
  `Combat.holy_bonus(game, grid_pos)` in `Hero._strike`. See docs/acolyte-design.md §6. A tiny
  still halo shows over her while blessed. Her sword stays *melee* damage, so the bonus never
  turns it into holy damage.

## 9. Downed and revival

- **At 0 HP** she is downed: the log says who struck her down and how much XP was lost
  (Important); all unspent XP is gone, her levels stay (the penalty stings without erasing long
  progress); she drops any camp order and her mode's work, loot she carries is left on the spot;
  she leaves no corpse.
- **Revival:** when the wave is finished, or when the next begins (so one downed between waves,
  say at a camp, doesn't sit out a whole wave), she is back in her own village's centre at full
  HP, in the same mode. The panel says which. Campaign scenarios can turn revival off
  (`hero_revives`: away from home downed is a defeat).
- Commands that need her (attacking a camp) are refused while she is down.

## 10. The tutorial

- The guided tutorial sets her to **Rest** at the start, so she snores in the centre until the
  "Your hero" step asks the player to send her exploring. Later steps have her level up and
  mention passing XP on at the grounds; the tutorial tops her XP up to the next level's cost if
  she has less. See docs/tutorial-design.md.

## 11. Code

- `scripts/units/hero.gd` (`class_name Hero extends Civilian`): modes (`Mode`, `MODE_*`,
  `set_mode`, `effective_mode`: Train falls back to Defend), `base()`, Defend (`_defend`,
  `_pick_enemy`), the sword (`_strike`, `counter_strike`), `_regen`, `level_up`, camps
  (`attack_camp`), `_train`, `_snore`, downing (`take_damage`, `_downed`, `revive`), `status()`.
  She reuses `Civilian`'s fleeing (`wants_to_evade` only in Build / Explore / Gather and never
  during a camp order) and path following.
- `scripts/units/jobs/`: `BuildJob`, `GatherJob`, `ExploreJob`, shared with the villagers and
  built with her weaker numbers; `HeroExploreJob` adds claims, looting, carrying, paying and
  dropping.
- `scripts/systems/commands.gd`: `hero_mode`, `hero_level_up`, `hero_support`, `attack_camp`,
  `_debug`. Every order goes through these, so co-op clients can give them.
- `scripts/ui/hud.gd`: the hero panel and top-bar button, `HERO_MODE_HINTS`.
- `scripts/world/fog_layer.gd`: `_unit_reveal`.
