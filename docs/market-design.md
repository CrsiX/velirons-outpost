# Veliron's Outpost: marketplace, trader and trade (design)

Status: **built**, except what needs items (§8: equipment and relic offers, selling items,
the trader's stationed time) and folding Pell's stall into the marketplace (§2): the stall
is still its own campaign building (`Stall`, `Config.STALL_LEVELS`). The code: `Market`
(`Config.MARKET`, `Config.BUILDINGS.market`), `Trader` (`Config.CIVILIANS.trader`),
`TradeCaravan`, salvage as a dropped-loot sack (`GatherJob`), `ThiefBehavior`; tested by
`market_bot`. Numbers live in `scripts/core/config.gd`, never here.
Scope: the marketplace building, the trader villager, buying and selling, trade caravans,
salvage, the co-op order book, and the market's item and relic offers. Items themselves
(equipment, relics) are in docs/items-design.md; the town hall in docs/village-design.md;
advancements in docs/advancements-design.md. Build order: town hall and village layout →
marketplace → items → advancements; the market sells items only once items exist.

## 1. Why a market

- **Surpluses go nowhere today.** A village with plenty of food and too little gold has no
  outlet; the only trade is the material counter's emergency buy (`MATERIALS_TRADE`), a
  deliberately poor rate in one direction. A market turns a surplus into what the village
  lacks, and gives co-op players a reason to trade instead of only gifting.
- **Gold must stay hard to get.** Gold pays for the army; if food or material turn into gold
  freely the gold economy (kills, corpses, mines, treasures) stops mattering. So selling has
  hard limits (§4) and risk (§5).
- **The road matters.** The market stands on a road and its goods travel the roads, the same
  roads the waves come down. Trade becomes a timing decision between waves.

## 2. The marketplace building

- **One per village**, 3×3, buildable from wave 1, with a noticeable cost (`Config.BUILDINGS`,
  proposed kind `market`). One per village keeps its upgrades meaningful and means one trader
  at most.
- **Placement:** it must touch a road tile. It is **not** forced outside the walls: in a
  hand-made map, or a later generator, a road may run inside. In practice it stands outside,
  exposed to raids and sieges; that exposure is part of the price.
- **Rats go for it like a farm** (its stock is food they can eat), as they go for Pell's stall
  today: deliberately, so barracks and the hero must guard it as they guard a farm.
- **Levels** (three, like Pell's stall: peddler, stall, guild market), upgraded like towers
  with material and a builder's time. Each level raises the building's HP, the stock it holds,
  and how many caravans it can have in transit at once; each level lowers the tax (§4).
- **Pell's stall is the campaign form of the same building** (planned, not built: the stall
  is still separate). One building kind, two dresses:
  in a scenario Pell is the fixed trader and the scenario sets the level. This replaces the
  separate `Stall` mechanics so there is one trading system with one set of rules. The
  campaign rules (Pell must not die, losing the stall loses scenario 2) stay in the scenarios.

## 3. The trader

- **A new civilian role**, recruited with food like the others, one per village (one market).
  The name is *trader*; Pell (the glossary's *merchant*) is the campaign's trader.
- **Recruitable from wave 1, even before a market stands.** Without a market the trader idles,
  like a farmer without a farm.
- **His job is selling** (§4): without a trader the market only sells *to* you. He works at the
  market, flees enemies like any villager, and lives in a hut.
- **Stationed time** counts while he tends the market and **pauses** (never resets) while he is
  away, e.g. fleeing; it unlocks relic offers (§8).

## 4. Buying and selling

Gold is the only currency: goods are sold for gold and bought with gold, never swapped for
each other.

### 4.1 Buying

- The market has a **buying stock** of food and material. It belongs to the travelling
  merchants, not to the player: the player pays gold when buying from it.
- Buying works **with or without a trader**, at a fixed rate per good (`Config`, per level).
- The stock is refilled by **incoming caravans** from the map edge (§5). An empty stock means
  waiting for the next caravan: that wait is the limit on buying.
- The material counter's emergency trade stays, unchanged and always available: worse than
  the market, but it needs no building, and it is the way out of a last stand without material.

### 4.2 Selling

- The player **puts goods up for sale** ("500 food"): they leave the village stock at once and
  go into the market's **for-sale pile** (capped by the level's stock).
- The **trader packs loads** from the pile at a rate. A full load leaves as an **outgoing
  caravan** once its route is clear (§5), towards a buyer (another player, §7) or the map edge.
- **Gold is paid on arrival**, minus the tax. Gold never appears before the goods have really
  arrived.
- **No trader, no selling.** The for-sale pile waits.

### 4.3 What limits selling

- **A flat tax** on sales at the map edge (`Config`, lower with each market level). It is the
  only deduction.
- **The trader's packing rate** and the **caravans in transit at once** (by level) cap
  throughput: the real brake.
- **Rejected: changing prices.** Prices that fall with every sale (and rise with every buy)
  were considered and dropped: two brakes on one problem are hard to explain and to balance,
  and the stock, the trader's rate and the caravan slots already limit both directions more
  clearly. Prices stay what the player sees: a fixed rate per good. Don't add price drift
  without revisiting this.

## 5. Trade caravans

The glossary's *caravan* already means the co-op help cart. A **trade caravan** is a second
kind with its own rules; the two must never be confused.

| | Help caravan (co-op gifts) | Trade caravan |
|---|---|---|
| Can be attacked | No (as now: punishing the helper would be wrong) | Yes |
| Look | covered wagon in the **sender's colour** | open cart with crates and sacks in the owner's colour; incoming merchants' carts in a neutral colour |
| Route | village to village | market to buyer or map edge, or map edge to market |

- **Departure:** a trade caravan (outgoing *and* incoming) sets off only when no enemy its
  village can see is near its route (camp guards don't count: they keep to their camps). The player can't choose the route: the nearest
  edge by road (single player, or when no player buys), or the buyer's village (§7).
- **Head-on is intended.** The roads lead to the spawns, so a caravan to the edge meets the
  next wave if the player trades late. Trade between waves.
- **On the way** it is a civilian to enemies: attacked when in reach, not hunted. Ghosts never
  haunt it and wolves don't hunt it (they hunt living villagers). It never flees, but **turns
  back** to the market when a visible enemy blocks the road ahead (a merchants' caravan turns
  back to the edge and comes again later); its load waits at the market for the next try. Back home it tops up the load being packed
  to one full load and the rest goes back on the for-sale pile, so no caravan carries more than a load.
- **Thieves rob it:** a thief with a trade caravan in reach goes for it instead of a gate,
  takes the whole cargo and runs for the edge; the empty caravan goes home unharmed. A buyer
  whose order is lost (robbed or destroyed) gets the gold back. Killed on
  the way, the thief leaves the cargo as salvage (§6), as its corpse holds stolen gold today.
- **Destroyed,** it leaves its cargo as salvage.

## 6. Salvage

- **Salvage** is the cargo of a destroyed or robbed trade caravan. It lies on the map and
  doesn't rot until the next wave is over (unlike corpses). Only the village whose market it
  belongs to fetches it; the hero exploring leaves it alone (it isn't treasure).
- **It is never free to take.** A gatherer, or the hero in Gather mode, carries it **to the
  market**, not into the village stock:
  - **outgoing** cargo (the player's goods) goes back into the for-sale pile, no fee;
  - **incoming** cargo (the merchants' goods) goes back into the buying stock, and the player
    gets a small **finder's fee** in gold (`Config`), far below the goods' value.
- **The hero earns XP** for salvage she brings back (`HERO_XP_PER_ACTION.salvage`).
- **Why not free:** if incoming cargo dropped as free loot, players would steer enemies onto
  merchant caravans for free goods. The departure rule (§5) and a fee far below the value keep
  that from paying.

## 7. Co-op: the order book

- **One shared order book.** When a player buys at their market, the purchase is filled from
  **other players' for-sale piles first**: the seller's trader packs it, a trade caravan walks
  village to village, and the seller is paid on arrival. The buyer pays when buying (the gold
  travels with the caravan). Only a seller with a trader counts: without one nothing leaves. Only if no player sells that good does
  it come from the merchants' buying stock.
- **Zero tax between players.** No gold is created when one player buys from another, so there
  is nothing to brake; the costs are the trader's rate and the walk. This is what makes co-op
  trade clearly better than the map edge, and it is the trader's co-op job ("improves the rate
  with other villages"). Sales at the edge keep the market's tax; gifts keep the help tax
  (`Config.help_tax`).
- **Routes between villages tend to be safer** than roads to the edge (they don't end at a
  spawn), but the caravan is still a trade caravan and can be attacked.
- **Fixed prices for goods**, no haggling. **Items** (equipment and relics) are different: the
  seller sets an **asking price**, the first player to accept gets it, and it travels by trade
  caravan. No bidding: an asking price is the smallest thing that is flexible, and auctions need
  timers and a UI for a rare event.
- **Demands:** a player can post a demand ("wants to buy 100 food", the market's *Ask for*
  action). For now it is only an **Info line in every player's event log**: no reservation, no toast. This may change (a toast
  or a board) once it has been played.
- **Without a market** a player can still send gifts by help caravan, as today.

## 8. The market's item and relic offers

- **Equipment offers:** a small **rotating, randomly generated** offer of items, changed by each
  incoming caravan. Buying needs no trader. Not a catalogue: a full shop would make every game
  end with the same best kit.
- **Selling items** (from the town hall's armoury) needs a trader present: at the asking price
  to another player (§7), or at the edge for a fixed value per item (`Config`).
- **Relic offers:** a trader stationed long enough (`Config`; the time pauses while he is away)
  makes **one relic offer**: a random relic, at a gold price. Relics are items (docs/items-design.md):
  a duplicate may be bought or sold, but its effect counts once.
- **Relics trade in co-op** like any item, and their effect moves with them.

## 9. Scope and other modes

- **Campaign:** off unless a scenario switches it on (Pell's stall is the campaign's market;
  docs/scenarios-design.md).
- **Tutorial, title backdrop:** off.
- **Save:** the market's stock and for-sale pile, the trader's stationed time, caravans in
  transit (position, cargo, owner, direction) and salvage on the map all need
  `SaveGame.capture` / restore lines and a `SaveGame.FORMAT` bump (docs/save-design.md).
- **Commands:** buying, putting up for sale, taking back from the pile, selling an item and
  accepting an item's asking price are `Commands`, so co-op clients work; the host simulates
  caravans and the order book.
- **Statistics:** trades, tax paid and salvage recovered can be counted within one game.
- **Library:** a page for the marketplace and the trader, built from `Config`.
- **Tests:** `market_bot` (buying, selling through the trader, caravan departure rule,
  turning back, robbery and salvage, a destroyed merchants' caravan, restocking, the save,
  order book in a two-village game). The balancing bot learns to sell
  surpluses later (docs/balance-bot-design.md).

## 10. Open for later

- Demand posts as a toast or a board instead of a log line (§7).
- What market levels 2 and 3 cost and how much each raises stock and caravans: `Config`, by a
  balance sweep.
