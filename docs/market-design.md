# Veliron's Outpost: marketplace, trader and trade (design)

Status: **built**, except folding Pell's stall into the marketplace (§2): the stall is still its
own campaign building (`Stall`, `Config.STALL_LEVELS`). The code: `Market` (`Config.MARKET`,
`Config.BUILDINGS.market`), `Trader` (`Config.CIVILIANS.trader`), `TradeCaravan`, salvage as a
dropped-loot sack (`GatherJob`), `ThiefBehavior`; the market's advancements in
`Config.ADVANCEMENTS` (docs/advancements-design.md); tested by `market_bot`. Numbers live in
`scripts/core/config.gd`, never here.
Scope: the marketplace building, the trader villager, buying and selling, trade caravans,
salvage, the co-op order book, and the market's item and relic offers and sales. Items
themselves (equipment, relics) are in docs/items-design.md; the town hall in
docs/village-design.md; advancements in docs/advancements-design.md.

**The guild** is the outside trade partner: the Silver Thread Guild (docs/story-design.md §6).
It owns the market's buying stock, sends the caravans that refill it and buys what a village
sells at the map edge, at its own fixed price minus the **guild tax**. Not to be confused with
the *merchant*, Pell.

## 1. Why a market

- **Surpluses go nowhere without it.** A village with plenty of food and too little gold has
  no outlet; the only other trade is the material counter's emergency buy (`MATERIALS_TRADE`),
  a deliberately poor rate in one direction. A market turns a surplus into what the village
  lacks, and gives co-op players a reason to trade instead of only gifting.
- **Gold must stay hard to get.** Gold pays for the army; if food or material turn into gold
  freely the gold economy (kills, corpses, mines, treasures) stops mattering. So selling has
  hard limits (§4) and risk (§5).
- **The road matters.** The market stands on a road and its goods travel the roads, the same
  roads the waves come down. Trade becomes a timing decision between waves.

## 2. The marketplace building

- **One per village**, 3×3, buildable from wave 1, with a noticeable cost (`Config.BUILDINGS`,
  kind `market`). One per village keeps its upgrades meaningful and means one trader at most.
- **Placement:** it must touch a road tile. It is **not** forced outside the walls: in a
  hand-made map, or a later generator, a road may run inside. In practice it stands outside,
  exposed to raids and sieges; that exposure is part of the price.
- **Rats go for it like a farm** (its stock is food they can eat), as they go for Pell's stall:
  deliberately, so barracks and the hero must guard it as they guard a farm.
- **Levels** (three, like Pell's stall: peddler, stall, guild market), upgraded like towers
  with material and a builder's time. Each level raises the building's HP, the stock it holds,
  and how many caravans it can have in transit at once; each level lowers the guild tax (§4).
- **Pell's stall is the campaign form of the same building** (planned, not built: the stall
  is still separate). One building kind, two dresses:
  in a scenario Pell is the fixed trader and the scenario sets the level. This replaces the
  separate `Stall` mechanics so there is one trading system with one set of rules. The
  campaign rules (Pell must not die, losing the stall loses scenario 2) stay in the scenarios.

## 3. The trader

- **A civilian role**, recruited with food like the others, one per village (one market).
  The name is *trader*; Pell (the glossary's *merchant*) is the campaign's trader.
- **Recruitable from wave 1, even before a market stands.** Without a market the trader idles,
  like a farmer without a farm.
- **His job is selling** (§4, §8): without a trader the market only sells *to* you. He works
  at the market, flees enemies like any villager, and lives in a hut.
- **Stationed time** counts while he tends the market and **pauses** (never resets) while he is
  away, e.g. fleeing; it unlocks relic offers (§8).

## 4. Buying and selling

Gold is the only currency: goods are sold for gold and bought with gold, never swapped for
each other.

### 4.1 Buying

- The market has a **buying stock** of food and material. It belongs to the guild, not to
  the player: the player pays gold when buying from it.
- Buying works **with or without a trader**, at a fixed rate per good (`Config`).
- The stock is refilled by **the guild's caravans** from the map edge (§5). An empty stock
  means waiting for the next caravan: that wait is the limit on buying.
- The material counter's emergency trade stays, unchanged and always available: worse than
  the market, but it needs no building, and it is the way out of a last stand without material.

### 4.2 Selling goods

- The player **puts goods up for sale** ("500 food"): they leave the village stock at once and
  go into the market's **for-sale pile** (capped by the level's stock).
- The **trader packs loads** from the pile at a rate. A full load leaves as an **outgoing
  caravan** once its route is clear (§5), towards a buyer (another player, §7) or the map edge.
- **Gold is paid on arrival**, minus the guild tax at the edge. Gold never appears before the
  goods have really arrived.
- **No trader, no selling.** The for-sale pile waits.

### 4.3 What limits selling

- **The guild tax**: a flat share of every sale to the guild (`Config`, lower with each market
  level; the Toll charter relic and the Guild partners advancement cut it further, adding up,
  never below none). It is the only deduction; there is none between players.
- **The trader's packing rate** and the **caravans in transit at once** (by level, plus the
  Caravan rights and One more caravan advancements) cap throughput: the real brake.
- **Rejected: changing prices.** Prices that fall with every sale (and rise with every buy)
  were considered and dropped: two brakes on one problem are hard to explain and to balance,
  and the stock, the trader's rate and the caravan slots already limit both directions more
  clearly. Prices stay what the player sees: a fixed rate per good. Don't add price drift
  without revisiting this.

## 5. Trade caravans

The glossary's *caravan* also means the co-op help cart. A **trade caravan** is a second kind
with its own rules; the two must never be confused.

| | Help caravan (co-op gifts) | Trade caravan |
|---|---|---|
| Can be attacked | No (punishing the helper would be wrong) | Yes |
| Look | covered wagon in the **sender's colour** | open cart with crates and sacks in the owner's colour; the guild's carts in a neutral colour |
| Route | village to village | market to buyer or map edge, or map edge to market |

- **A load** is what one caravan carries: goods the trader packs from the pile, up to a cap,
  leaving when full or when the pile is empty; or **one item** (§8), never mixed with goods,
  packed in a short time of its own.
- **Departure:** a trade caravan (outgoing *and* the guild's) sets off only when no enemy its
  village can see is near its route (camp guards don't count: they keep to their camps). The
  player can't choose the route: the nearest edge by road (single player, or when no player
  buys), or the buyer's village (§7).
- **Head-on is intended.** The roads lead to the spawns, so a caravan to the edge meets the
  next wave if the player trades late. Trade between waves.
- **On the way** it is a civilian to enemies: attacked when in reach, not hunted. Ghosts never
  haunt it and wolves don't hunt it (they hunt living villagers). It never flees, but **turns
  back** to the market when a visible enemy blocks the road ahead (a guild caravan turns back
  to the edge and comes again later); its load waits at the market for the next try. Back home
  it tops up the load being packed to one full load and the rest goes back on the for-sale
  pile, so no caravan carries more than a load; an item goes back where it waits (§8).
- **Home to a market that is gone** (torn down while the cart was out): nothing is lost. An
  order's gold goes back to the buyer, goods go back into the village stock, an item into the
  armoury (or a sack by the town hall when the armoury is full).
- **Delivered anyway:** an order reaches the buyer even if their market is devastated or gone,
  or their village has fallen: they paid.
- **Thieves rob it:** a thief with a trade caravan in reach goes for it instead of a gate,
  takes the whole cargo and runs for the edge; the empty caravan goes home unharmed. A buyer
  whose order is lost (robbed or destroyed) gets the gold back. Killed on the way, the thief
  leaves the cargo as salvage (§6), as its corpse holds stolen gold.
- **Destroyed,** it leaves its cargo as salvage.

## 6. Salvage

- **Salvage** is the cargo of a destroyed or robbed trade caravan. It lies on the map and
  doesn't rot until the next wave is over (unlike corpses). Only the village whose market it
  belongs to fetches it; the hero exploring leaves it alone (it isn't treasure).
- **It is never free to take.** A gatherer, or the hero in Gather mode, carries it **to the
  market**, not into the village stock:
  - **outgoing** cargo (the player's goods) goes back into the for-sale pile, no fee;
  - an **item** goes back on sale where it was (§8);
  - **the guild's** cargo goes back into the buying stock, and the player gets a small
    **finder's fee** in gold (`Config`), far below the goods' value.
- **The hero earns XP** for salvage she brings back (`HERO_XP_PER_ACTION.salvage`).
- **Why not free:** if the guild's cargo dropped as free loot, players would steer enemies onto
  its caravans for free goods. The departure rule (§5) and a fee far below the value keep that
  from paying.

## 7. Co-op: the order book

- **One shared order book.** When a player buys at their market, the purchase is filled from
  **other players' for-sale piles first**: the seller's trader packs it, a trade caravan walks
  village to village, and the seller is paid on arrival. The buyer pays when buying (the gold
  is held until the caravan arrives). Only a seller with a trader counts: without one nothing
  leaves. Only if no player sells that good does it come from the guild's buying stock.
- **Zero tax between players.** No gold is created when one player buys from another, so there
  is nothing to brake; the costs are the trader's rate and the walk. This is what makes co-op
  trade clearly better than the guild, and it is the trader's co-op job. Sales to the guild
  keep the guild tax; gifts keep the help tax (`Config.help_tax`).
- **Routes between villages tend to be safer** than roads to the edge (they don't end at a
  spawn), but the caravan is still a trade caravan and can be attacked.
- **Fixed prices for goods**, no haggling. **Items** (equipment and relics) have an **asking
  price** the seller sets (§8); the first player to accept gets it. No bidding: an asking price
  is the smallest thing that is flexible, and auctions need timers and a UI for a rare event.
- **Demands:** a player can post a demand ("wants to buy 100 food", the market's *Ask for*
  action). For now it is only an **Info line in every player's event log**: no reservation, no
  toast. This may change (a toast or a board) once it has been played.
- **Without a market** a player can still send gifts by help caravan.

## 8. The market's item and relic offers, and selling items

- **Equipment offers:** a small **rotating, randomly generated** offer of items, rolled when
  the market is finished and again by each guild caravan that arrives. Buying needs no trader,
  only room in the armoury, and every item costs the same (there is no rarity,
  docs/items-design.md §5). Not a catalogue: a full shop would make every game end with the
  same best kit. Only where items are on (`Game.items_enabled`).
- **Relic offers:** every time a trader has been stationed long enough (`MARKET`
  "relic_after"; the time pauses while he is away) he brings **one relic offer**: a random
  relic (`Relics.pool`, one the village doesn't have where it can), at a gold price, bought the
  same way as equipment. **It is there only for that window:** when his next stretch is up,
  a relic not bought is gone and a new one takes its place; one bought leaves the offer empty
  until then. Why: a relic is a chance to take or let pass, not a shelf to come back to, and
  the next one may be a better fit. A new equipment offer never brings a relic: the relic is
  the trader's, so a market without a trader never offers one, and keeping a trader at work
  is what earns it. The panel says how much of his time is left. A duplicate may be bought
  (the offer says so), but its effect counts once.

### 8.1 Selling an item

- **What:** any item in the armoury (equipment not worn: take it off first) and any relic,
  sold from the market panel, only while a trader works there. It leaves the armoury at once:
  a relic's effect stops the moment it goes (unless a duplicate stays), and comes back if it
  is taken back or returns home.
- **One Sell action, never two.** The panel always shows **what the guild pays**: a share of
  the item's buying price (`MARKET` "item_sell", the same for equipment and relics) minus the
  guild tax. A share, not a flat value per item, so a cheaper item would fetch less.
  - **Single player** (or co-op where no other village has a finished market): no price to
    set. The guild buys it at once; the trader packs it and a caravan takes it to the edge,
    where the gold is paid on arrival like any sale.
  - **Co-op:** the seller sets an **asking price** (prefilled with the guild's price; 0 or
    more, never negative: 0 is how an item is given away). It shows in every other player's
    market panel (seller, item, price; a relic the viewer already has is marked as a
    duplicate, still buyable) and as an Info line in their event logs.
    - **Asking at or below the guild's price:** a short countdown (`MARKET` "edge_delay")
      gives the other players a chance. Nobody takes it: the guild buys it at **its own**
      price, never the asking price. The panel says "sells to the guild in Xs unless a player
      buys it".
    - **Asking above the guild's price:** it waits for a player as long as it takes; the
      seller can take it back until someone buys it.
    - While the trader is away (fleeing, downed, none recruited) the item is hidden from the
      others and its countdown pauses.
- **A player buying it** needs a finished market and room in the armoury, not a trader; the
  room is **reserved** on buying, so two items on the road can't count on one free slot. The
  gold is taken at once and held; the seller gets it when the item arrives, the buyer gets it
  back if it is lost.
- **It travels as a load of its own** (§5): one crate, one caravan slot, after a short packing
  time (`MARKET` "item_pack_time"). Robbed or destroyed, it lies as an item sack, salvage of
  the seller's market (§6), and a buyer has the gold back; brought back, it is on sale again at
  its asking price. A cart that turns back keeps it sold as it was (to its buyer or the guild)
  and takes it out again.
- **Relics trade like any item**, and their effect moves with them.

## 9. Scope and other modes

- **Campaign:** off unless a scenario switches it on (`Scenario.market`; Pell's stall is the
  campaign's market, docs/scenarios-design.md). The market's advancements are there exactly
  where a marketplace can be built (`Game.market_enabled`).
- **Tutorial, title backdrop:** off.
- **Save:** the market's stock and for-sale pile, items on sale and their countdowns, armoury
  slots reserved by orders, the trader's stationed time (`"st"`), caravans in transit
  (position, cargo or item, owner, direction) and salvage on the map all have
  `SaveGame.capture` / restore lines (docs/save-design.md).
- **Commands:** buying, putting up for sale, taking back from the pile, buying an offered
  item, selling an item, taking an item back and buying another player's item are
  `Commands`, so co-op clients work; the host simulates caravans and the order book.
- **Statistics:** trades, guild tax paid, salvage recovered and items sold are counted within
  one game and shown in the statistics' Trade section.
- **Library:** a page for the marketplace and the trader, built from `Config`.
- **Tests:** `market_bot` (buying, selling through the trader, caravan departure rule,
  turning back, robbery and salvage, a destroyed guild caravan, restocking, the save, order
  book in a two-village game, selling items to the guild and to another player, a cart home to
  a torn-down market); `advancement_bot` (the market's advancements). The balancing bot learns
  to sell surpluses later (docs/balance-bot-design.md).

## 10. Open for later

- Demand posts as a toast or a board instead of a log line (§7).
- A filling Sell button instead of the countdown text (§8.1).
- What market levels 2 and 3 cost and how much each raises stock and caravans: `Config`, by a
  balance sweep.
