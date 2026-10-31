# Veliron's Outpost: co-op multiplayer design

Status: built (§11), open questions resolved (§13) · Scope: LAN co-op · Engine: Godot 4.7

All numbers (player cap, tax, sizes, intervals, ports, spawn counts) live in
`scripts/core/config.gd` and `scripts/net/`; this document gives the reasons.

## 1. Summary

Players defend their **own villages on one shared map**. Every player has their
own economy, villagers, buildings, army and hero, exactly as in single player.
The co-op part is **helping each other**: sending resources by caravan,
sending military units, and sending the hero to defend another village.

- There is one wave for the whole game. Every village gets its own share, plus
  a shared extra.
- The game is lost only when **the last village has fallen**. Waves never slow
  down, so a fallen village puts more pressure on the others.
- One player **hosts**: generates the map, runs the simulation, controls game
  speed and pause.
- Players find each other by **LAN discovery**. Internet play and browser
  clients are out of scope for now, but the transport is kept replaceable so a
  web version can be added later (§8.2).
- It is a co-op game: players are expected to be nice to each other, so there
  are no anti-griefing rules (votes, cooldowns, kicks).

Single player stays a 1-player game on the same code path: no network, no tax,
the rules unchanged.

## 2. Goals and non-goals

**Goals**
- Co-op on the same LAN: Linux, Android, and desktop builds in general.
- Every rule of the single-player game still holds inside each village.
- Help is meaningful but costs something: travel time, and a tax that grows
  with the player count.
- Players can't see each other's villages. Knowledge comes from exploration,
  plus a few public signals.

**Non-goals (for now)**
- Internet play, NAT traversal, relay servers, accounts, matchmaking.
- Browser clients. Browsers can't do LAN discovery or UDP; they come later
  through a server-based transport (§8.2). Nothing in this design may rule
  that out.
- Joining a running game (§8.6).
- PvP, trading between players, chat. Chat is a candidate for later.
- Host migration. (Saving and resuming a co-op game: docs/save-design.md.)

## 3. Player flow

### 3.1 Title → Multiplayer screen

The multiplayer screen asks for a **village name** and **colour** (both
required, remembered between sessions, colour changeable in the lobby), then
offers **Host game**, a list of **games on your network** (from LAN
discovery, §8.2), and **Join by address** as a fallback for networks that
filter broadcasts. A full game, or one of another version, can't be picked.
The accepted name characters and the colour palette are in the code
(`VILLAGE_COLORS`); the palette is chosen to stay distinct on light and grey
map areas and for colour-blind players.

### 3.2 Lobby

- Two panes (stacked in portrait): the players on the left; your name and
  colour, the game's settings and Ready / Start / Leave on the right.
- Every player's village is shown by name in its colour. Name and colour can
  be changed until *Ready* is ticked.
- **Names and colours must be unique.** The host rejects a duplicate name
  (case-insensitive) and the player retries. Taken colours are greyed out; a
  player joining with a taken colour gets the first free one and is told.
- There is no banner or emblem: a village is identified by **name and colour**,
  which is also what the name label over the village (§6) and every UI mention
  of a village uses. Colour is what lets players tell villages apart at a
  glance; a banner would add art and uniqueness rules for little gain.
- Only the host changes the difficulty, map type and seed; only the host
  starts, once everyone is ready (alone is fine too).
- **A map file** (docs/map-editor-design.md §8): after Random the host's Map
  button offers *Custom...*. Everyone gets a copy of the map in the lobby, so
  all see its name, village count and a preview with each player's name by
  their village. Every player is assigned a village (the host cycles them;
  taking someone's swaps the two). The map's villages cap the players. Villages
  nobody plays stand as ownerless ruins: no owner, no waves from their spawns,
  enemies never go there, so an unplayed village is neither a free target nor
  a free spawn.
- **A saved co-op game** (docs/save-design.md §6): *Saved game...* picks one
  of the host's co-op saves. The lobby then needs exactly as many players as
  the save has villages, the host assigns each player a saved village, and each
  village takes its new player's name and keeps its colour. Difficulty and map
  come from the save.
- A player can leave. Nobody can be removed (see the no-kick rule, §1).
- Joining is refused with a reason (different protocol version, game full,
  already started): a plain message beats a silent failure on a LAN where
  the player is usually sitting next to the host.

### 3.3 Start

1. The host fixes the seed and map type, assigns the villages in join order
   (the host's is village 0), generates the map for the player count (§5) and
   builds its own level. With a map file it takes that map, made for the
   players' villages (`MapData.for_game`).
2. The host sends every client the **game setup** (what it needs to build the
   world and know which village is theirs) and the **map** (§5.6).
3. Each client builds its world and reports *loaded*; from then on it gets
   snapshots, the first one complete. The host's clock doesn't wait for
   anyone: the first wave's delay is long enough, and the peer timeout is
   generous so nobody drops while a level is being built.

## 4. Game rules in multiplayer

### 4.1 Villages

- Every village has the single-player start (walled village, huts, starting
  farm and camp with their workers, builder, explorer, hero, resources).
- **Standing**: at least one villager and one intact hut (the single-player
  defeat rule, applied per village). **Fallen** otherwise, logged at Important
  for everyone.
- **Fallen villages:**
  - Their wave share keeps coming (§4.2), and enemies bound for a fallen
    village turn to the standing village nearest to where they are. This is
    the point of the mode: a fall costs the others.
  - The player keeps playing: the hero still revives at the end of each wave
    in the player's own village centre, with no extra resources, and the
    player can rebuild with what is left (the hero in Build mode rebuilds a
    hut, a villager is recruited). With one villager and one intact hut the
    village **stands again** and enemies come for it again. Not eliminating
    a player keeps them in the game and gives a comeback path.
- **The game is lost** when every village has fallen at the same moment. All
  players see the defeat screen, with the statistics as one column per village
  (the host sends everyone the final numbers; docs/statistics-design.md).

### 4.2 Waves

There is **one wave counter** for the whole game.

- **Calling:** any player can call the next wave early, without a vote or
  cooldown. The early-call gold bonus goes to **every** village, fallen ones
  included, and every log says who called it. Otherwise the next wave starts
  after the same buffer as in single player.
- **Composition:** each village gets its single-player wave for wave *n*
  (difficulty applies as in single player), plus a shared **extra** that
  scales with the wave's size and the number of villages
  (`WAVE_EXTRA_PER_PLAYER`; none in single player). The extra is what makes
  more players mean more pressure than one wave per village: it pays for the
  help the players can give each other. Each extra enemy's kind is picked at
  random from the wave's composition (no rat packs); they spawn at random
  edge spawns of the whole map and head for the standing village nearest to
  their spawn.
- **Spawning:** a village's own share spawns at its own edge spawns (§5.3) and
  at the awake lairs in its slice (docs/world-objects-design.md §9.6), and walks to
  that village. Shares of fallen villages still spawn but turn to the nearest
  standing village. The shares are interleaved so every village's share
  arrives at the same time.
- **Warning lights:** per village, as in single player, visible to that
  village's player only.
- **Scaling is per village:** HP growth per wave and difficulty multipliers
  are unchanged. The total grows only through the number of shares.

### 4.3 Economy, buildings and units

Everything is per village: resources, population and huts, starvation,
construction queue and builders, army and reserve, the hero, corpses brought
home, event log.

A player can only build on land they have explored, as in single player. Land
between villages is shared: nothing stops two players from building near each
other. Buildings are never shared.

## 5. Map

The map generator is described in docs/world-design.md; this section sums up
what matters for co-op. The generator's numbers are in `config.gd`.

### 5.1 Size

The map grows with the player count (`Config.map_size`) so every village keeps
roughly the single-player amount of room; the cap is `MAX_PLAYERS`, and the
formula keeps working past it if the cap is raised.

### 5.2 Slices and village placement

- The map is cut into one **equal-area slice** per player around the map
  centre, with a random rotation (`gen_slices.gd`). Every slice reaches the
  map edge and touches the middle, so every village has its own stretch of
  edge for its wave share and a fair share of land.
- Each village goes on the best tile near its slice's centre
  (`gen_villages.gd`), keeping distance from other villages, from its slice's
  border and from the map edge, and clear of water, mountains and lava. If
  nothing fits, the rules are loosened step by step
  (docs/world-design.md §3.2).

### 5.3 Home spawns

- Every village gets a few edge spawns spread along its slice's stretch of
  land edge, each with a road from the gate facing it (`gen_roads.gd`). Its own
  wave share spawns there.
- Every road tile on the map edge is a home spawn of the village whose slice
  it lies in.

### 5.4 Roads and connections

- **Ring road:** a road runs round every village just outside its walls and
  joins its four gates. Enemies still stop at a gate (nothing walks through a
  village), but enemies whose target fell can walk on round it to the next
  village.
- **Village links** (`gen_roads.gd`): two players get one link, three a
  triangle, more a ring ordered by angle around the map centre, with a few
  chords across for five or more. Every village needs a minimum number of
  links (`VILLAGE_MIN_LINKS`) so a village that falls has neighbours that
  feel it and help can walk between villages. A link much longer than the
  straight distance (`ROAD_DETOUR_MAX`) is tried through a mountain pass, else
  dropped; a village left short is linked to its next-nearest villages; if that
  fails, the map is made again from another seed.
- **Winding roads:** each road is found by A* over a cost map by zone, with
  low-frequency noise, so paths meander instead of running straight
  (docs/world-roads-design.md §5.2). Roads never pass through a village's walls.
- Each road leaves by the gate facing where it goes, an unused gate preferred.
  Every village needs at least 2 approaches.
- Enemies only walk on roads, as in single player. Rerouted enemies (§4.1) use
  the village-to-village and ring roads, which is what makes a fallen village
  dangerous for its neighbours.

### 5.5 Per-village features

Everything the generator does around a village is done once per village: the
clearing ring, fair land (no steppe, swamp or ash nearby, enough meadow and
trees), trees within reach of the worker camp (a grove is planted if not), and
the starting farm and camp (`START_BUILDINGS`), placed by the game on the
finished map, each only where it fits.

Mountains, lakes, river sources and volcanoes keep away from the slice
centres, so no village starts walled in.

### 5.6 Generation and transfer

- **Only the host generates.** It sends clients the finished map
  (`MapData.to_bytes`), not a seed.
- It is sent once, reliably, with the game setup. Buildings, units and
  everything else come with the snapshots.
- Clients never run the generator, so there are no cross-platform randomness
  or float-determinism problems. This is the reason for sending the map
  instead of the seed.

## 6. Visibility

Fog of war is **per player**. The host enforces it: clients only receive what
their player may see (§8.4), so there is nothing hidden on the client to cheat
with.

| What | Who sees it |
|---|---|
| Own village and everything own units / buildings watch | Owner (the single-player surveillance rules) |
| Land between villages | Fog: unexplored until explored by the player's own explorer, hero, soldiers or caravans |
| Other villages' walls, gates, towers and hut lots | Everyone, from the start, as *explored* terrain only |
| Other villages' inner huts | Everyone, **live**: intact / ruined / being rebuilt. No units, no fog lifting beyond that. This is the **only** live public information about another village |
| Other villages' **name** | Everyone, always: a label over the village centre in its colour, readable at every zoom (none over one's own village). Grey with "(fallen)" while the village has fallen |
| Other players' units and caravans | Only where the viewer has surveillance |
| Enemies | Only under the viewer's own surveillance |

- Own units watch for their owner wherever they are. A hero supporting another
  village gives her owner vision there; the receiving village also sees her
  through its own surveillance.
- Other villages' buildings show once explored, as they looked when last
  watched: whether a tower is manned, upgraded or bewitched is **not** public.
  The hut state is public because it is the one thing a helper needs: who is
  about to fall.

## 7. Sending help

The tax for anything sent to another village depends on the number of
villages (`Config.help_tax`: none alone, growing per extra player up to a
cap). It makes help costly enough that it isn't free to dump everything on
the neighbour with the best defence, and bigger games make it dearer because
the extra enemies already pay for the help. It applies to **resources only**;
units and heroes arrive whole.

### 7.1 Resources: caravans

- **Dialog:** a "Send resources" button in the Village tab: amounts of gold,
  food and material (capped by what the player has), a receiving-village
  toggle (fallen villages can be picked; they may need it most), and a live
  line showing the tax and what the receiver gets.
- **On Send** the amounts leave the sender's stock immediately and a
  **caravan** (a horse-drawn cart) spawns at the sender's village centre and
  walks the civilian path network to the receiver's centre at `CARAVAN_SPEED`.
  Paying at once keeps the books simple (nothing in transit can be spent
  twice); the walk is the cost of distance.
- **On arrival** the taxed amounts go to the receiver, and both players get an
  Info log entry.
- **While travelling:** the caravan is owned by the sender and watches for
  them. **Enemies can't attack it** and it never flees: a lost cart would
  punish exactly the player who is trying to help. It can't be stopped,
  recalled or redirected.
- **If the receiver falls meanwhile,** the caravan still delivers.
- **If no path exists** at the moment of sending, Send is refused.

### 7.2 Military units

- **Only reserve units** can be sent: not stationed, not walking.
- **Army tab:** a **Send…** button next to *Upgrade selected* opens a small
  dialog with the receiving-village toggle.
- **Journey:** the unit leaves the sender's reserve and walks, as a soldier,
  to the receiver's village. It is still the sender's unit on the way: it
  watches for the sender and is listed as on its way. **It can't be recalled**
  once walking, and neither player can give it orders until it arrives, which
  avoids ownership races and tug-of-war over a unit in transit.
- **On entering the receiving village** ownership moves to the receiver and it
  appears in their reserve. From then on it is **the receiver's unit in every
  respect** (station, drag & drop, upgrade with their gold, withdraw, send on
  again, train). Its level and training XP are kept.
- `MilitaryUnit.original_owner` records who recruited it. It is **never shown
  in the UI**: gifts are not bookkeeping.

### 7.3 Hero: Send support

- **Hero mode "Support"** (after Rest, only with 2 or more villages). The hero
  panel then shows a **second toggle** for the target village, cycling through
  the other villages, visible only in Support mode. Switching to Support first
  picks the nearest standing village.
- **Behaviour:** she walks to the target village's centre, re-targeting
  threats near her on the way as in Defend; there she runs **Defend** relative
  to that village (its gates for the alert radius, its centre for the leash and
  for coming back). Idling at that centre she heals, and every hit earns XP as
  usual.
- **Changing the target village** sends her on to the new one. **Any other
  mode** makes her walk home first: Build, Explore, Gather and Train always
  work for her own village.
- **When downed,** she revives at the end of the wave **in her own village
  centre**, still in Support mode with the same target, and walks back.
- **The receiver can't interact with her in any way** (no panel, no orders, no
  drag & drop). She is a friendly figure and her owner always controls her:
  two players commanding one hero would be the fastest way to a quarrel.

## 8. Networking

### 8.1 Model

- **Host-authoritative.** The host runs the only simulation (world, all
  villages, waves, pathing). Clients send **commands** and draw **snapshots**;
  they don't simulate (`Game.is_client`). One simulation means no desyncs, and
  a client can't cheat by what it holds, because it only holds what it may see.
- **Transport:** `ENetMultiplayerPeer` (UDP) on the LAN. Everything is a
  reliable RPC on the `Net` autoload. Reliable-only keeps the protocol
  simple; LAN latency and snapshot sizes make it cheap enough.
- Single player uses the same command path, applied locally without a network,
  so there is one code path for rules.

### 8.2 LAN discovery

- **Host** (`LanDiscovery`) broadcasts a small announcement over UDP at a
  regular interval (also to localhost, for a game on the same machine) until
  the game starts. **Clients** on the multiplayer screen listen and list the
  hosts heard recently. The payload carries a game id, the protocol version
  (so incompatible games are marked), the host's name, player count and cap,
  difficulty and the game port. Ports are in `Net` (`GAME_PORT`,
  `DISCOVERY_PORT`); tests pass their own with `--port=N`.
- **Android** needs the INTERNET permission. Some Wi-Fi networks drop
  broadcasts, hence "join by address".
- **Later expansion, the web:** browsers can't do UDP or broadcasts. A web
  version needs a server (a WebSocket relay or dedicated host, or WebRTC with a
  signaling server). To keep that possible without touching game code:
  - All networking goes through Godot's `MultiplayerPeer` interface; ENet is
    only created in `Net.host` / `Net.join`.
  - Discovery is its own node with a small interface (`games()`,
    `games_changed`); a lobby-server finder can offer the same.
  - Messages are plain dictionaries / packed arrays, with no ENet-specific
    features.
  - The host logic doesn't depend on running in a player's app, so it can
    later run as a headless dedicated server.

### 8.3 Commands (client → host)

Every player action is a command (`Commands`, `Game.command`): a type plus
plain arguments (entities by id). The host checks **ownership and validity**
exactly as in single player, then applies it for the sender's village; a
refusal comes back as a toast. The full list is the command table in
`scripts/systems/commands.gd`. A few are special: `set_speed` is host only,
`debug` works only on a debug-build host. UI-only actions (selection, camera,
dock, log level, panels) never go to the host.

### 8.4 Snapshots (host → each client)

- The host sends each client, at a fixed real-time rate
  (`Replicator.SEND_INTERVAL`), only the changes since the last snapshot
  (spawns, updates, removals), and only for that player: the exact fields are
  in `scripts/net/replicator.gd`. The rule behind it is **interest
  management** matching §6:
  - own economy, starvation and army, and own entities, always;
  - other villages' units, enemies, corpses and caravans only under that
    player's surveillance;
  - others' buildings once explored, live state only while watched (the public
    huts always);
  - newly explored tiles, map objects' states, global unlocks, trees felled
    (shared, as the map is shared), public game state (villages standing /
    fallen, wave and countdown, speed, pause, game over), and that player's own
    log lines, toasts and effects.
- Clients don't simulate: units glide to their new positions.
- **Ids:** every entity gets a host-assigned network id. The per-kind labels
  from the event log ("archer 5") stay the readable names.

### 8.5 Speed, pause, settings

- **Speed and pause:** only the host; on clients the speed button shows the
  speed and is disabled.
- **Host settings dialog** pauses the game for everyone; every player's game
  turns grey below the top bar and clients see a "Paused by the host" banner.
- **Client settings dialog** opens **without pausing**, with a note that the
  game keeps running (a client cannot stop the shared simulation); *Back to
  title* becomes **Leave game**: the village stays in the game, untended.

### 8.6 Connections

- **No late joining:** the player list is fixed at *Start*. A running game
  stops announcing itself and refuses new players.
- **Client drops or leaves:** the village keeps existing and simulating,
  enemies still come. The same player can **rejoin** by joining with the same
  village name and gets the village back: the host sends the setup and map
  again, then a full snapshot. This is not a new player, so it isn't late
  joining.
- **Host leaves or drops:** the game ends for everyone. No host migration.
- **Latency:** LAN is assumed fast enough that commands feel instant without
  prediction.

## 9. UI changes (overview)

| Where | Change |
|---|---|
| Title | *Multiplayer* button |
| Multiplayer screen, Lobby | §3.1, §3.2. Both have landscape and portrait layouts |
| Top bar | On clients the speed button is disabled |
| Village tab | *Send resources* entry and dialog (§7.1) |
| Army tab | *Send…* next to *Upgrade selected* (§7.2) |
| Hero panel | Mode *Support*, plus the support-target toggle in that mode |
| World | Name labels over other villages |
| Settings | Clients: no pause, *Leave game* (§8.5) |
| Event log | Info entries for co-op events; "X has fallen" is **Important** for everyone |
| Defeat screen | Waves held out, *Main menu*, *Statistics* (per-village columns) |

## 10. Architecture

1. **Command layer.** One `Commands` node (`scripts/systems/commands.gd`):
   `Game.command` applies a command locally in single player and on the host,
   or sends it to the host from a client (`Net.send_command`). All UI goes
   through it instead of calling the systems directly.
2. **Village object.** One `Village` per player (`scripts/systems/village.gd`):
   identity, centre, gates, home spawns, standing / fallen, relics, and its
   own economy, population, construction, army, hero and event log. `World`,
   `Waves`, corpses, statistics and pathing stay global; buildings and units
   have a `village`.
3. **Pathing:** enemy flow fields over the roads, one to the nearest gate of
   any village and one **per village** to its own gates; enemies reroute to
   another field when their target falls. The civilian graph is shared, so
   caravans, soldiers and heroes walk between villages.
4. **Map generator:** multi-village layout (§5; docs/world-design.md); the
   villages and their links are part of `MapData`.
5. **Fog:** one fog state per village in `FogLayer`, on the host; each client
   only draws its own. Public hut tiles are sent with the building states;
   buildings out of sight carry only their look.
6. **Networking** (`scripts/net/`): `Net` (autoload: host / client, lobby,
   setup and map transfer, commands up, snapshots down; it only sees a
   `MultiplayerPeer` outside `host` / `join`, §8.2), `LanDiscovery`,
   `Replicator` (per-client snapshots with interest management). Clients run a
   **presentation world**: the same scenes and art, driven by snapshots, with
   simulation scripts inactive.
7. **Config:** the co-op tunables (`MAX_PLAYERS`, `map_size`, `help_tax`,
   `WAVE_EXTRA_PER_PLAYER`, `CARAVAN_SPEED`, `VILLAGE_NAMES`,
   `VILLAGE_COLORS`, and the generator's numbers)
   are in `config.gd`; the ports are in `Net`.

## 11. Milestones

Each milestone was playable and testable on its own.

1. ✅ **Command layer** in single player.
2. ✅ **Village object and per-village systems.**
3. ✅ **Multi-village map generator and a test mode with several villages in
   one game** (`Game.test_villages`, tests only; `tests/coop_bot.gd`). Tests
   start several villages in one game, played as village 0, which covers the
   rules (waves per village, reroute on fall, standing again) without a
   network. Several players only play through LAN.
4. ✅ **Help:** caravans, sending units, hero support.
5. ✅ **Networking** (`scripts/net/`; `tests/net_bot.gd` +
   `tests/run_net_test.sh`): discovery, lobby, map transfer, commands,
   snapshots, per-player fog.
6. ✅ **Polish:** client settings behaviour, rejoining, the statistics at game
   over, portrait layouts. Not done yet: a balance pass with simulations
   (2 / 4 / 8 players).

## 12. Testing

- **`tests/coop_bot.gd`** (headless, several villages in one game): the
  generator for every player count, the tax and size formulas, per-village
  start, enemies' roads ending at the right village, fall / reroute / standing
  again / game lost only when the last falls, caravan delivery and tax, a sent
  unit joining the other reserve, Support mode.
- **`tests/net_bot.gd`** (two processes on localhost, `tests/run_net_test.sh`):
  discovery, lobby, ready / start, a latecomer refused, the map received
  identical to the host's, per-village fog with others' walls known, public
  huts, commands, object states and unlocks reaching the client, host-only
  speed and pause, *Leave game*.
- **Balance simulations** for 2, 4 and 8 bot villages (not built yet): how
  often does one early fall cascade into a total loss?

## 13. Decisions (formerly open questions)

| # | Question | Decision |
|---|---|---|
| 1 | Calling waves early | Every player can call early, with no vote or cooldown. **Every player gets the gold bonus.** Every player's log says who called. It's a co-op game; players are expected to be nice to each other (§4.2). |
| 2 | Can enemies attack caravans? | **No.** Caravans can't be attacked or stopped (§7.1). |
| 3 | Recalling units in transit | **No.** Once a unit starts walking to another village it can't be recalled (§7.2). |
| 4 | Receiver control over a supporting hero | **None.** The receiver can't interact with the hero at all (§7.3). |
| 5 | Public information about other villages | **Only the inner huts**, plus the name label. Tower state is not public (§6). |
| 6 | Late joining | **No late joining.** Only rejoining one's own village after a drop (§8.6). |
| 7 | Village identity | **Name and colour**, both chosen by the player on the multiplayer screen / lobby, from a fixed set of colours, unique per game. **No banner** (§3.1, §3.2). |
| 8 | Web version | **LAN play now.** Keep the design open for a web version later: transport behind `MultiplayerPeer`, discovery in its own node with a small interface, host logic able to run headless (§8.2). |
