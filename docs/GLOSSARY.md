# Glossary

Game terms as used in code, docs and tests. One line each, no numbers (the code has them: usually `scripts/core/config.gd`). Longer reasoning is in the doc named at the end of a line.

## Village and economy
- **Outpost / village**: the walled block of huts, walls, gates, wall towers and the town hall a player runs. `village-design.md`
- **Village centre**: the path crossing in the middle of the village; enemies head for it, "nearest" in targeting means nearest to it, and the hero stands there when idle. Never a building. `village-design.md`
- **Standing / fallen**: a village stands while it has a villager and a town hall that hasn't fallen; otherwise it has fallen (single player: defeat; co-op: it can stand again). `village-design.md`
- **Hut**: houses exactly one villager; intact huts cap the population. A burned hut is a ruin and can be rebuilt.
- **Wall tower / watchtower**: towers hold one military unit. Wall towers are part of the village walls; watchtowers are built outside.
- **Post**: a slot a military unit can be stationed in (tower, training grounds). **Bench**: a barracks' slot. **Reserve**: where bought or withdrawn units wait at home.
- **Sortie**: a barracks' units turning out to fight when enemies come in range.
- **Downed**: at 0 HP a unit or the hero is out until it revives (in the reserve, on its bench, or in the village centre).
- **Devastated**: a building at 0 HP. It does nothing and shows its ruin; repair brings it back. "Does its job" is `working()`. `siege-design.md`
- **Build queue**: how builders (and the hero in Build mode) choose the next job. `village-design.md`
- **Builder crew**: the builders (and the hero) working one site together; their work adds up, and a builder joins only if that saves more than its walk. `village-design.md`
- **Tear down**: a builder dismantles a building outside the walls for a partial refund.
- **Gatherer / forester / farmer / builder / explorer / miner / trader**: civilian roles. **Merchant** (Pell), **guild master, resident**: named campaign villagers who can't be recruited; Pell is the campaign's trader.
- **Marketplace**: the trading building; buying works from its stock, selling needs a trader. Pell's stall is the campaign's marketplace. `market-design.md`
- **Trader**: the villager who works a marketplace and sells the goods put up for sale. `market-design.md`
- **Town hall**: every village's one building in its back quarter, placed by the map; the hero's home and (designed) the armoury, the relics and research; level 2 adds a tower post, (designed) level 3 a bench. `village-design.md`
- **Last stand**: the countdown after a town hall is devastated; it must be fully repaired before it runs out or the village falls. `village-design.md`
- **Salvage**: the cargo of a robbed or destroyed trade caravan; a gatherer or the hero carries it back to the marketplace. `market-design.md`
- **Order book**: co-op trade; a purchase is filled from other players' goods for sale before the merchants at the map edge. `market-design.md`
- **Caravan**: a cart. In co-op it carries help between villages; in the campaign a scripted guild cart; help caravans wear the sender's colour; a **trade caravan** carries a marketplace's goods to a buyer or the map edge, or brings stock in. `market-design.md`
- **Starvation / hunger**: villagers die one by one while food is out; military units slow down and take more damage.

## Combat
- **Damage category**: melee, projectile, magical, fire, holy, poison or pure; enemies resist or are weak to categories. `enemies-design.md`
- **Poison**: a damage category dealt as a decaying dose over time; buildings, the undead and aberrations are immune. `enemies-design.md` §4
- **Enemy family**: The Horde, Beasts, Undead, Aquatic, Humans, Aberrations; a description of what may come, never a number. `enemies-design.md` §5
- **Defence class**: stone defence, wood defence or civilian; how a building takes each damage category. `siege-design.md` §2b
- **Specialisation (branch)**: a base unit turns into a specialised kind from a minimum level and starts again at level 1. `military-design.md`
- **Summon / elemental**: units a summoner creates (earth, fire, thornlings); they crumble with their summoner.
- **Better targeting / manual targeting**: two exclusive advancements; one rule per unit kind for every tower, or a targeting switch per tower. `advancements-design.md`
- **Drill**: advancements that make a unit's level-ups (never a specialisation) cheaper in gold and in training XP. `advancements-design.md`
- **Aura**: a High Priest's buff, strongest counts, no stacking. **War cry**: the Warrior's haste shout.
- **Holy / unholy**: the acolyte line's damage; skeletons, necromancers, vampires and anything raised or undead count as unholy. `acolyte-design.md`
- **Raised**: an enemy a necromancer brings back; it drains away and is undead.
- **Held wall / lurking / leftovers**: no ground enemy burns a hut while the walls stand; enemies that can't break in roam outside (lurk) until a breach, or leave. `enemies-design.md` §9
- **Siege field**: the cost field enemies near a village follow to its cheapest way in. **Breached**: an enemy is inside. **Slip**: rats and thieves get through gates unharmed after a delay. `siege-design.md`
- **Mount / rider / charge / circling**: mounted enemies' rules (hits land on the mount first; they circle the village instead of breaking barriers until a breach). `enemies-design.md`
- **Dive**: water monsters going under on deep water, untargetable. `aquatic-design.md`
- **Wave**: a batch of enemies; the next one comes a fixed time after the last enemy is gone. **Wild** enemies (camp guards, wrathwood) count for no wave.
- **Wrathwood**: a tree that wakes up when a forester chops it. **Vulture**: carrion birds drawn by corpses left lying. **Fallen**: the campaign's corpses on the battlefield. `enemies-design.md`
- **Ghost**: a spirit hunting one villager, immune to melee and projectiles. **Faded / solid**: unseen and untouchable, or targetable; **revealed**: made solid by a light stone or a High Priest's aura. **Lurk**: waiting faded while its target hides at home. `enemies-design.md`

## World
- **Fog of war**: unexplored (black), explored (darkened), under surveillance (clear). Enemies are only visible when watched.
- **Map object**: treasure, monster camp, unit-unlock site, ruined watchtower, mine, monster lair; hidden until found. `world-objects-design.md`
- **Item**: a single thing a village holds, sells or trades: equipment or a relic (some are both). `items-design.md`
- **Relic**: an item with a village-wide or map-wide effect, either while owned or while worn; a second copy adds nothing. `items-design.md`
- **Deed**: something done in the current game (kills by one unit kind, map explored, a volcano found) that an advancement may need. `advancements-design.md`
- **Advancement**: a lasting upgrade researched at the town hall during one game; one village's unless it says it is for all players. Some are exclusive choices that can't be undone. `advancements-design.md`
- **Lair**: wakes late and adds a spawn point; the hero can clear it.
- **Spawn / water spawn**: where enemies enter at the map edge or from deep water.
- **Slice**: a co-op village's part of the map. **Ownerless village**: a village on a map file nobody plays; it is ruins.
- **Map type / zone**: Temperate, Highlands, Coast, Desert, Volcanic or Random; zones are meadow, woods, heath, steppe, swamp, ash land, city.
- **Baked map**: a map saved beforehand for the title backdrop.

## Hero
- **Hero modes**: Defend, Build, Explore, Gather, Train, Rest, Support (co-op). **Attack a camp** is an order that overrides the mode. `hero-design.md`
- **Training grounds**: where the hero in Train mode passes her XP to a stationed unit.
- **Equipment / slot**: what the hero wears in her four slots: weapon (how she attacks), armour (how she takes hits), accessory (the catch-all slot), movement (how she moves). The default items are the plain hero. `items-design.md`
- **Armoury**: the town hall's store of items not worn.

## Campaign
- **Scenario**: one campaign level, one file; it has a baseline, waves, cards, objectives, cutscenes. `scenarios-design.md`
- **Card / hint**: the scenario's teaching text top left; a hint may point at something.
- **Journal**: a found page that pauses the game.
- **Prebuilt**: buildings and units a scenario starts with.
- **Brenna**: the hero. **Pell**: the merchant. **Fiona, Lothar, Rhodri, Anselm, Sigmund, Wenna, Lysa, Torben, Halvard, Rurik**: named characters. `story-design.md`
- **Wardline**: the ruined border towers along the north. **Dread Legion**: the campaign's human-led undead army. **Silver Thread Guild**: Pell's neutral merchant guild.
- **Stall, warehouse, graveyard, church, grove**: campaign-only buildings.
- **Trust locks** (scenario 7), **hero lives out** (tent outside the walls), **barred**: scenario rules that limit the player or the hero.

## Tools and tests
- **Bot**: a headless test scene under `tests/`. **Balancing bot**: plays whole games to measure balance. `balance-bot-design.md`
- **Backdrop**: the live game behind the title menu.
- **Library**: in-game reference pages built from `Config`.
- **Tactical map**: the overview map opened with M.
- **Co-op / host / client**: LAN multiplayer; the host simulates, clients send commands. `multiplayer-design.md`
- **Autosave**: written after every wave; saves only happen between waves. `save-design.md`
