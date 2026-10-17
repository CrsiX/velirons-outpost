# Veliron's Outpost: co-op multiplayer design

Status: built (§11), open questions resolved (§13) · Scope: LAN co-op, 1–8 players · Engine: Godot 4.7

## 1. Summary

Up to 8 players defend their **own villages on one shared map**. Every player
has their own economy, villagers, buildings, army and hero, exactly as in
single player. The co-op part is **helping each other**: sending resources by
caravan, sending military units, and sending the hero to defend another village.

- There is one wave for the whole game. Every village gets its own share, plus
  a shared extra.
- The game is lost only when **the last village has fallen**. Waves never slow
  down, so a fallen village puts more pressure on the others.
- One player **hosts**. The host generates the map, runs the simulation, and
  controls game speed and pause.
- Players find each other by **LAN discovery**. Internet play and browser
  clients are out of scope for now, but the transport is kept replaceable so a
  web version can be added later (§8.2).
- It is a co-op game: players are expected to be nice to each other, so there
  are no anti-griefing rules (votes, cooldowns, kicks).

Single player stays a 1-player game on the same code path: no network, no tax,
map 75×75, the rules unchanged.

## 2. Goals and non-goals

**Goals**
- Co-op for 2–8 players on the same LAN: Linux, Android, and desktop builds
  in general.
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

The title screen has a **Multiplayer** button. The multiplayer screen has:

| Element | Behaviour |
|---|---|
| **Village name** field | Required before hosting or joining. 2–20 characters, trimmed, letters, digits, spaces, `'` and `-`. Remembered between sessions (user settings). |
| **Village colour** | A row of colour swatches (`VILLAGE_COLORS`, 8 colours). Required, and remembered like the name. It can be changed in the lobby too. |
| **Host game** | Starts a lobby on this device. |
| **Games on your network** | List filled by LAN discovery (§8.2): game name (the host's village), players `3/8`, difficulty. Tap to join. A full game, or one of another version (marked "other version"), can't be picked. |
| **Join by address** | Fallback text field (IP[:port]) for networks that filter broadcasts. |
| **Back** | Returns to the title screen. |

### 3.2 Lobby

- Two panes (stacked in portrait): the players on the left; your name and
  colour, the game's settings and Ready / Start / Leave on the right.
- Shows every player's village name in their chosen colour, with "host",
  "ready" or "not ready". Each player can still change their name and colour
  here (*Use this name and colour*) until they tick *Ready*.
- **Names and colours must be unique** within a game:
  - The host rejects a duplicate name (case-insensitive): "The village name
    'X' is taken"; the player edits the name and retries.
  - Colours already taken are shown greyed out (and can't be picked) in every
    player's swatch row. A player joining with a taken colour gets the first
    free one and a message: "That colour was taken: you got another one".
- There is no banner or emblem: a village is identified by its **name and
  colour**. These are used for the name label over the village (§6) and
  everywhere the UI names a village.
- Only the host changes the **difficulty**, the **map type** and the
  **seed** (empty: random); everyone sees the map type. Only the host sees
  **Start**, enabled when every other player is ready (the host alone can
  start too).
- **A map file** (docs/map-editor-design.md §8): after Random the host's Map
  button offers *Custom...* (the map picker). Everyone gets a copy of the map
  in the lobby, sees its name and village count and a preview with each
  player's name by their village. Every player has a village of it (a
  *Village n* button in their row; the host's cycle it, taking someone's
  swaps the two; new players get the first free one). The map's villages
  cap the players ("The game is full"; LAN discovery shows that maximum).
  Villages nobody plays stand as ownerless ruins: huts ruined for good, no
  owner, no waves from their spawns, enemies never go there.
- **A saved co-op game** (docs/save-design.md §6): *Saved game...*
  next to the host's Map button picks one of the host's co-op saves. The lobby
  then needs exactly as many players as it has villages (no more can join;
  Start waits for the rest), every player gets one of its villages (a
  *Village* button showing the saved village's name in its colour; the host
  assigns them, as with a map file), and each village takes its new
  player's name and keeps its colour. Difficulty and map come from the save.
- A player can leave. Nobody can be removed.
- Joining is refused with a reason: "Different game version (host 2, you 1)"
  (the protocol numbers), "The game is full" (8 players), "The game has
  already started".

### 3.3 Start

1. The host fixes the seed (the typed one, or a random one) and the map type
   ("Random" picks one from the seed), assigns the villages in join order
   (the host's is village 0), generates the map for the player count (§5) and
   builds its own level. With a map file it takes that map instead, made for
   the players' villages (`MapData.for_game`: player i plays village i).
2. The host then sends every connected client the **game setup** (seed, map
   type, difficulty, every village's name, colour and player, which village
   is theirs) and the **map** (§5.6).
3. Each client builds its world from what it received and reports *loaded*.
   From then on the host sends it snapshots, the first one complete. The
   host's clock doesn't wait for anyone (the first wave is
   `FIRST_WAVE_DELAY`, 90 s, away). ENet's peer timeout is generous (15-60 s)
   so nobody drops while a level is being built.

## 4. Game rules in multiplayer

### 4.1 Villages

- Every village has the single-player start: 5×5 walled village, huts, the
  starting farm and worker camp with their farmer and forester, a builder, an
  explorer, a hero, and the starting resources.
- **Village state:**
  - *Standing*: at least one villager and at least one intact hut (the
    single-player defeat rule, applied per village).
  - *Fallen* otherwise. "X has fallen" is logged at Important for everyone.
- **Fallen villages:**
  - Their wave share keeps coming (§4.2), and enemies bound for a fallen
    village turn to the standing village nearest to where they are.
  - The player keeps playing: the hero still revives at the end of each wave in
    the player's own village centre, with no extra resources.
  - The player can rebuild with whatever is left, e.g. the hero in Build mode
    rebuilds a hut, then a villager is recruited. With one villager and one
    intact hut the village is **standing again** ("X stands again", Info), and
    enemies come for it again.
- **The game is lost** when every village has fallen at the same moment. All
  players then see the defeat screen with the waves held out, *Main menu*
  and *Statistics*: the statistics screen, one column per village (the host
  sends everyone the final numbers; docs/statistics-design.md).

### 4.2 Waves

There is **one wave counter** for the whole game.

- **Calling:** any player can call the next wave early, without a vote or
  cooldown.
  - The early-call gold bonus goes to **every player's village**, fallen ones
    included.
  - Every player's event log says who called it, at Info level: "Rivermoor
    called wave 6 early: +40 gold".
  - Otherwise the next wave starts `WAVE_BUFFER` seconds after the last enemy
    of the current one is gone, as in single player.
- **Composition:** each village gets its single-player wave for wave *n*
  (`Config.wave_composition(n)`, plus rat packs; difficulty applies as in
  single player), plus a shared **extra**:
  - `extra = round(wave_size(n) × WAVE_EXTRA_PER_PLAYER × P)` enemies
    (`WAVE_EXTRA_PER_PLAYER` 0.25), where P is the number of villages. No
    extra in single player.
  - Examples: 4 players → 4 + 1 = **5×** a single-player wave; 2 players → 2.5×;
    8 players → 10×.
  - Each extra enemy's kind is picked at random from the wave's composition
    (no rat packs). They spawn at random edge spawns of the whole map and head
    for the standing village nearest to their spawn point.
- **Spawning:**
  - A village's own share spawns at its own edge spawns (its *home spawns*,
    §5.3; up to `wave_spawn_points(n)` of them) and at the awake lairs in its
    slice (docs/world-design.md §9.6), and walks to that village.
  - Shares of fallen villages still spawn, but head for the standing village
    nearest to the spawn point.
  - The shares are interleaved, so every village's share arrives at the same
    time.
- **Warning lights:** per village, as in single player, visible to that
  village's player only.
- **Scaling is per village:** HP growth per wave and difficulty multipliers
  are unchanged. The total grows only through the number of shares.

### 4.3 Economy, buildings and units

Everything is per village:
- gold, food and materials
- population and huts, starvation
- construction queue and builders
- army and reserve, the hero
- corpses brought home
- event log

A player can only build on land they have explored, as in single player.
Land between villages is shared: nothing stops two players from building near
each other. Buildings are never shared.

## 5. Map

The map generator is described in docs/world-design.md; this section sums up
what matters for co-op.

### 5.1 Size

The side length grows by 25 tiles for every 2 players beyond the second
(`Config.map_size`):

```
size(P) = 75 + 25 × (ceil(P / 2) − 1)        1 ≤ P ≤ 8
```

| Players | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Size | 75×75 | 75×75 | 100×100 | 100×100 | 125×125 | 125×125 | 150×150 | 150×150 |

The player cap is `MAX_PLAYERS = 8` (Config). The formula keeps working past
8 if the cap is raised.

### 5.2 Slices and village placement

- The map is cut into one **equal-area slice** per player around the map
  centre, with a random rotation (`gen_slices.gd`). Every slice reaches the
  map edge and touches the middle.
- Each village goes on the best tile within `VILLAGE_CENTER_RADIUS` (12) of
  its slice's centre (`gen_villages.gd`):
  - at least 14 tiles from any other village;
  - at least `VILLAGE_BORDER_GAP` (8) tiles from its slice's border;
  - its centre at least `VILLAGE_MAP_MARGIN` (9) tiles from the map edge;
  - no water, mountains or lava within 5 tiles of its walls, 10 tiles from
    the sea, 20 from a volcano.

  If nothing fits, these rules are loosened step by step
  (docs/world-design.md §3.2).

### 5.3 Home spawns

- Every village gets 2–3 edge spawns (`COOP_SPAWNS`) spread along its slice's
  stretch of land edge (at least 8 tiles apart), each with a road from the
  gate facing it (`gen_roads.gd`). Its own wave share spawns there.
- Every road tile on the map edge is a home spawn of the village whose slice
  it lies in.

### 5.4 Roads and connections

- **Ring road:** a road runs round every village just outside its walls and
  joins its four gates. Enemies still stop at a gate (nothing walks through a
  village), but enemies whose target fell can walk on round it to the next
  village.
- **Village links** (`gen_roads.gd`):
  - 2 players: one link.
  - 3 players: a triangle.
  - 4–8 players: a ring, the villages ordered by their angle around the map
    centre; with 5 or more, 1–2 extra links (chords) to the village opposite
    in the ring.
  - Every village needs at least `VILLAGE_MIN_LINKS` (2) links, 1 with 2
    players. A link longer than `ROAD_DETOUR_MAX` (2.5) × the straight
    distance is tried through a mountain pass, else dropped; a village left
    short is linked to its next-nearest villages. If that fails, the map is
    made again from another seed.
- **Winding roads:** each road is found by A* over a cost map by zone, with
  low-frequency noise added, so paths meander instead of running straight
  (docs/world-design.md §5.2). Roads never pass through a village's walls.
- Each road leaves by the gate facing where it goes, an unused gate
  preferred. Every village needs at least 2 approaches (gates with a road
  leading away).
- Enemies only walk on roads, as in single player. Rerouted enemies (§4.1)
  use the village-to-village and ring roads, which is what makes a fallen
  village dangerous for its neighbours.

### 5.5 Per-village features

Everything the generator does around a village is done once per village:
- the clearing ring;
- the guaranteed 3×3 farm plot with its walkway;
- fair land: no steppe, swamp or ash land within 8 tiles, at least 25 %
  meadow and 25 % trees within 12;
- trees within reach of the worker camp (a grove is planted if not);
- the starting farm and worker camp (`START_BUILDINGS`), placed by the game
  near its own trees.

Mountains follow noise ridges anywhere on the map (not within 8 tiles of a
slice centre); roads go around them or through a pass. Lakes, river sources
and volcanoes keep away from the slice centres too.

### 5.6 Generation and transfer

- **Only the host generates.** It sends clients the finished map, not a seed:
  `MapData.to_bytes`, a compressed copy of the terrain, zones, props, decor,
  crossings, beaches, volcanoes, slices, the villages (walls, gates, home
  spawns, farm plot), the links, the special objects, map type and seed.
- It is sent once, reliably, with the game setup. The buildings, units and
  everything else come with the snapshots.
- Clients never run the generator, so there are no cross-platform randomness
  or float-determinism problems.

## 6. Visibility

Fog of war is **per player**. The host enforces it: clients only receive what
their player may see (§8.4), so there is nothing hidden on the client to cheat with.

| What | Who sees it |
|---|---|
| Own village and everything own units / buildings watch | Owner (the single-player rules: huts 4, gates and buildings 3, units, manned towers, light stones) |
| Land between villages | Fog: unexplored until explored by the player's own explorer, hero, soldiers or caravans |
| Other villages' **5×5 shape** (walls, gates, towers, hut lots) | Everyone, from the start, as *explored* terrain only |
| Other villages' **inner 3×3 tiles** (the huts) | Everyone, **live**: intact / ruined / being rebuilt. No units, no fog lifting beyond that. This is the **only** live public information about another village |
| Other villages' **name** | Everyone, always: a label floating over the village centre in the colour its player chose in the lobby, readable at every zoom level (none over one's own village). It turns grey with "(fallen)" while the village has fallen |
| Other players' units and caravans | Only where the viewer has surveillance |
| Enemies | Only under the viewer's own surveillance |

- Own units watch for their owner wherever they are. A hero supporting
  another village gives his owner vision there.
- The receiving village also sees him, through its own surveillance.
- Other villages' buildings show once explored, as they looked when last
  watched: whether a tower is manned, upgraded or bewitched is **not**
  public.

## 7. Sending help

The tax for anything sent to another village depends on the number of
villages (`Config.help_tax`):

```
tax(P) = min(0.10 × (P − 1), 0.50)      →  1 player 0 %, 2 → 10 %, 3 → 20 %, … 6+ → 50 %
```

The tax applies to **resources only**. Units and heroes arrive whole.

### 7.1 Resources: caravans

- **Dialog:** "Send resources" button in the Village tab.
  - Three steppers (gold, food, material): −50, −10, +10, +50 and *All*. They
    can't exceed what the player has.
  - A **receiving village** toggle ("To: Rivermoor (tap to change)"): tap to
    cycle through the other villages, "(fallen)" after a fallen one. Fallen
    villages can be picked; they may need it most.
  - A live line: "Tax 20 %: Rivermoor receives 80 gold, 40 food".
  - **Send caravan**, disabled when everything is 0; **Close**.
- **On Send:**
  - The amounts leave the sender's stock immediately.
  - A **caravan** spawns at the sender's village centre: a cart pulled by a
    horse (`unit_caravan`: horse, two-wheeled cart, sacks and planks).
  - It walks the civilian path network to the receiver's village centre at
    `CARAVAN_SPEED` (1.4 tiles/s).
- **On arrival** at the receiver's centre, the taxed amounts go to the
  receiver. Info log entries for both players: "Caravan from Eastwatch
  arrived: …" for the receiver, "Your caravan reached Rivermoor: …" for the
  sender.
- **While travelling:**
  - The caravan is owned by the sender: it watches for the sender.
  - **Enemies can't attack it**: it isn't a target for any enemy and nothing
    stops it. It never flees.
  - It can't be stopped, recalled or redirected.
- **If the receiver falls meanwhile,** the caravan still delivers.
- **If no path exists** at the moment of sending, Send is refused with "No
  road to that village".

### 7.2 Military units

- **Only reserve units** can be sent: not stationed, not walking.
- **Army tab:** a **Send…** button next to *Upgrade selected*, for the
  selected reserve card. It opens a small dialog with the receiving-village
  toggle and *Send*.
- **Journey:**
  - The unit leaves the sender's reserve and walks, as a soldier, from the
    sender's village centre to the receiver's.
  - It is still the sender's unit on the way: it watches for the sender and
    is listed as on its way.
  - **It can't be recalled** once it has started walking. Neither sender nor
    receiver can give it orders until it arrives ("It's on its way to another
    village").
- **On entering the receiving village** (its 5×5 square):
  - Ownership moves to the receiver, and it appears in the receiver's reserve.
    From then on it is **the receiver's unit in every respect**: station, drag
    & drop, upgrade with their gold, withdraw, send on again, train at their
    grounds.
  - Its level and training XP are kept.
- `MilitaryUnit.original_owner` records the village that recruited it. It is
  **never shown in the UI**.
- Logs:
  - sender (debug): "send archer 5 to Rivermoor";
  - receiver (info): "Archer arrived from Eastwatch".

### 7.3 Hero: Send support

- **Hero mode "Support"** (after Rest, only with 2 or more villages). The
  hero panel then shows a **second toggle** below the mode buttons:
  "Support: Rivermoor (tap to change)", cycling through the other villages.
  It is only visible in Support mode. Switching to Support first picks the
  nearest standing village.
- **Behaviour:**
  1. He walks from wherever he is to the selected village's centre. On the way
     he behaves like Defend mode on the move: he re-targets threats near him.
  2. There he runs **Defend** relative to that village: its gates for the alert
     radius, its centre for the leash and for coming back.
  3. Idling at that centre he heals (passive resting), and every hit earns XP
     as usual.
- **Changing the target village** sends him on to the new one.
- **Any other mode** makes him walk home first. Build, Explore, Gather and Train
  always work for his own village.
- **When downed,** he revives at the end of the wave **in his own village
  centre**, still in Support mode with the same target, and walks back there.
- **The receiver can't interact with him in any way:**
  - no selection panel, no mode changes, no orders, no drag & drop;
  - tapping him does nothing.

  He is simply a friendly figure. His owner always controls him.

## 8. Networking

### 8.1 Model

- **Host-authoritative.**
  - The host runs the only simulation: world, all villages, waves, pathing.
  - Clients send **commands** and draw **snapshots**. They don't simulate
    (`Game.is_client`).
- **Transport:** `ENetMultiplayerPeer` (UDP) on the LAN. Everything is a
  reliable RPC on the `Net` autoload: lobby, setup and map, commands,
  snapshots, statistics.
- Single player uses the same command path, applied locally without a network.

### 8.2 LAN discovery

- **Host** (`LanDiscovery`): broadcasts an announcement over UDP to
  `255.255.255.255` and `127.0.0.1` (a game on the same machine), port
  47110, once per second (real time; `PacketPeerUDP`,
  `set_broadcast_enabled(true)`).
  - JSON payload: `{game: "velirons-outpost", proto, name, players, max, difficulty, port}`.
  - Stops when the game starts.
- **Clients** on the multiplayer screen listen on 47110 and list every host
  heard in the last 3 s, keyed by address and port.
- **Game port:** 47111 (ENet; `Net.GAME_PORT`). Tests pick their own with
  `--port=N` (discovery on N − 1).
- **Android** needs the INTERNET permission. Some Wi-Fi networks drop
  broadcasts, hence the "join by address" fallback.
- **Later expansion, the web:** browsers can't do UDP or broadcasts. A web
  version needs a server: a WebSocket relay or dedicated host, or WebRTC with
  a signaling server. To keep that possible without touching game code:
  - All networking goes through Godot's `MultiplayerPeer` interface; ENet is
    only created in `Net.host` / `Net.join`. `WebSocketMultiplayerPeer` /
    `WebRTCMultiplayerPeer` slot in later.
  - Discovery is its own node (`LanDiscovery`) with a small interface
    (`games()`, `games_changed`); a lobby-server finder can offer the same.
  - Messages are plain dictionaries / packed arrays, with no ENet-specific
    features.
  - The host logic doesn't depend on running in a player's app, so it can
    later run as a headless dedicated server.

### 8.3 Commands (client → host)

Every player action is a command (`Commands`, `Game.command`): a type plus
plain arguments (entities by id). The host checks **ownership and validity**
exactly as in single player, then applies it for the sender's village; a
refusal comes back to the client as a toast.

| Commands | What |
|---|---|
| `place_building`, `cancel_site`, `tear_down`, `stop_tear_down`, `rebuild_hut`, `rebuild_all_huts`, `upgrade_tower` | building |
| `recruit_villager`, `retire_villager`, `assign_worker`, `unassign_worker` | villagers |
| `recruit_unit`, `upgrade_unit`, `station_unit`, `withdraw_unit`, `move_unit`, `swap_units`, `promote_archmage` | the army |
| `buy_materials` | trade |
| `hero_mode`, `hero_level_up`, `hero_support` | the hero |
| `send_caravan`, `send_unit` | help |
| `call_wave` | waves |
| `set_speed` | speed / pause (host only: "The host sets the speed") |
| `attack_camp`, `restore_ruin`, `assign_miner`, `unassign_miner` | map objects |
| `debug` | the Debug page (debug builds only: `OS.is_debug_build()` on the host) |

UI-only actions don't go to the host: selection, camera, dock, log level,
panels. The debug log entries for them stay local.

### 8.4 Snapshots (host → each client)

- **10 per second** (real time, `Replicator.SEND_INTERVAL`), one per client,
  with only the changes since the last one (spawns, updates, removals). Each
  contains, for that player only:
  - own economy, starvation and army;
  - entities: their own always; other villages' units, enemies, corpses and
    caravans only under that player's surveillance, with position, HP and
    state;
  - buildings of others once explored, with live state only while watched
    (the huts of the inner 3×3 always);
  - newly explored tiles (everything on the first snapshot) and the warning
    lights;
  - map objects' states, global unlocks, relics, dropped loot;
  - public data: every village standing / fallen, wave number and
    countdown, enemies left, whether a wave can be called, game speed and
    pause, game over;
  - their event-log lines, toasts, and the floating texts, shots and effects
    they can see.
- Clients don't simulate: units glide to their new positions.
- **Ids:** every entity gets a host-assigned network id. The per-kind labels
  from the event log ("archer 5") stay the readable names.

### 8.5 Speed, pause, settings

- **Speed and pause:** only the host. On clients the speed button shows the
  current speed and is disabled (its tooltip is the usual one).
- **Host settings dialog:** pauses the game for everyone. While the host has
  paused (settings or speed 0), every player's game turns grey below the top
  bar; clients see a "Paused by the host" banner.
- **Client settings dialog:**
  - opens **without pausing and without the grey backdrop**, with a note
    "The game keeps running.";
  - *Back to title* becomes **Leave game**: the village stays in the game,
    untended.

### 8.6 Connections

- **No late joining:** the player list is fixed at *Start*. A running game
  stops announcing itself on the LAN and refuses new players ("The game has
  already started").
- **Client drops or leaves:** the village keeps existing and simulating
  ("X left the game", Info). Enemies still come. The same player can
  **rejoin** while the game runs, by joining with the same village name, and
  gets the village back ("X is back"): the host sends the setup and map
  again, then a full snapshot. This is not a new player joining, so it isn't
  late joining.
- **Host leaves or drops:** the game ends for everyone ("The host left the
  game"). No host migration.
- **Latency:** LAN is assumed below 50 ms. Commands feel instant enough
  without prediction.

## 9. UI changes (overview)

| Where | Change |
|---|---|
| Title | *Multiplayer* button |
| Multiplayer screen, Lobby | §3.1, §3.2: village name, colour swatches, game list, ready / start. Both have landscape and portrait layouts |
| Top bar | On clients the speed button is disabled |
| Village tab | *Send resources* entry and dialog (§7.1) |
| Army tab | *Send…* next to *Upgrade selected* (§7.2) |
| Hero panel | Mode *Support*, plus the support-target toggle in that mode |
| World | Name labels over other villages |
| Settings | Clients: no pause, *Leave game* (§8.5) |
| Event log | Info entries: wave called early by X, caravan / unit arrived, X left / is back, X stands again. "X has fallen" is **Important** for everyone |
| Defeat screen | Waves held out, *Main menu*, *Statistics* (per-village columns) |

## 10. Architecture

1. **Command layer.** One `Commands` node (`scripts/systems/commands.gd`):
   - `Game.command` applies a command locally in single player and on the
     host, or sends it to the host from a client (`Net.send_command`).
   - All UI goes through it instead of calling the systems directly.
2. **Village object.** One `Village` per player (`scripts/systems/village.gd`):
   - `id`, `village_name`, `color`, centre, gates, home spawns, standing /
     fallen, relics;
   - its own economy, population, construction, army, hero and event log.
   - `World`, `Waves`, corpses, statistics and pathing stay global.
     Buildings and units have a `village`.
3. **Pathing:**
   - enemy flow fields over the roads: one to the nearest gate of any
     village, and one **per village** to its own gates;
   - reroute to another field when the target falls;
   - the civilian graph is shared, so caravans, soldiers and heroes walk
     between villages.
4. **Map generator:** multi-village layout (§5; docs/world-design.md).
   - `MapData.villages[]`: centre, rect, gates, home spawns, farm plot,
     slice; `village_links`.
5. **Fog:**
   - one fog state per village in `FogLayer`, on the host;
   - each client only draws its own;
   - public hut tiles are sent with the building states.
6. **Networking** (`scripts/net/`):
   - `Net` (`net.gd`, autoload): host / client, lobby, setup and map
     transfer, commands up, snapshots down. It only sees a `MultiplayerPeer`
     outside `host` / `join` (§8.2).
   - `LanDiscovery`: UDP announce and listen.
   - `Replicator`: per-client snapshots with interest management.
   - Clients run a **presentation world**: the same scenes and art, driven by
     snapshots, with simulation scripts inactive.
7. **Config:**
   - `MAX_PLAYERS = 8`
   - `map_size(P)`
   - `help_tax(P)`
   - `WAVE_EXTRA_PER_PLAYER = 0.25`
   - `CARAVAN_SPEED`
   - `VILLAGE_NAMES`, `VILLAGE_COLORS`: 8 swatches, distinct in both light
     and grey-ish map areas and for colour-blind players
   - `COOP_SPAWNS`, `VILLAGE_MIN_LINKS`, `VILLAGE_MAP_MARGIN` and the rest of
     the generator's numbers (docs/world-design.md §11)
   - the ports are in `Net` (`GAME_PORT` 47111, `DISCOVERY_PORT` 47110).

## 11. Milestones

Each milestone is playable and testable on its own.

1. ✅ **Command layer** in single player (`scripts/systems/commands.gd`, `Game.command`).
2. ✅ **Village object and per-village systems** (`scripts/systems/village.gd`).
3. ✅ **Multi-village map generator and a test mode with several villages in
   one game** (`MapGenerator.generate(seed, P, type)`, `Game.test_villages`,
   tests only; `tests/coop_bot.gd`). Tests start P villages in one game,
   played as village 0. This covers the rules: waves per village, reroute on
   fall, standing again. Several players only play through LAN.
4. ✅ **Help:** caravans, sending units, hero support (`send_caravan` / `send_unit` / `hero_support` commands, `scripts/units/caravan.gd`, Hero `Mode.SUPPORT`).
5. ✅ **Networking** (`scripts/net/`: `net.gd` autoload "Net", `lan_discovery.gd`, `replicator.gd`; `tests/net_bot.gd` + `tests/run_net_test.sh`): discovery, lobby, map transfer, commands, snapshots,
   per-player fog.
6. ✅ **Polish:** client settings behaviour, rejoining, the statistics at game
   over, portrait layouts of the new screens. Not done yet: a balance pass
   with simulations (2 / 4 / 8 players).

## 12. Testing

- **`tests/coop_bot.gd`** (headless, several villages in one game):
  - the map generator for P = 1…8: size, villages, links, edge spawns;
  - tax and map-size formulas;
  - villages with their own walls, villagers, hero, farm and camp;
  - every enemy's road ends at a gate of the village it was sent against; a
    raid burns a hut of that village only;
  - a fallen village: its enemies and its wave share turn to a standing
    village; its hero revives at home; "standing again" after a rebuild; the
    game lost only when the last village falls;
  - caravan delivery and tax; a sent unit joining the other village's
    reserve;
  - Support mode walking, defending, healing remotely, reviving at home.
- **`tests/net_bot.gd`** (two processes on localhost, `tests/run_net_test.sh`):
  discovery, lobby, ready / start, a latecomer refused, the map received
  identical to the host's (type, seed, terrain, zones, objects), each
  village's own fog with the other's walls known, public huts, commands
  (recruiting, attacking a camp, a caravan), object states and unlocks
  reaching the client, host-only speed and pause (grey below the top bar,
  the banner), *Leave game*.
- **Balance simulations** for 2, 4 and 8 bot villages (not built yet): how
  often does one early fall cascade into a total loss?

## 13. Decisions (formerly open questions)

| # | Question | Decision |
|---|---|---|
| 1 | Calling waves early | Every player can call early, with no vote or cooldown. **Every player gets the gold bonus.** Every player's log says who called. It's a co-op game; players are expected to be nice to each other (§4.2). |
| 2 | Can enemies attack caravans? | **No.** Caravans can't be attacked or stopped (§7.1). |
| 3 | Recalling units in transit | **No.** Once a unit starts walking to another village it can't be recalled (§7.2). |
| 4 | Receiver control over a supporting hero | **None.** The receiver can't interact with the hero at all (§7.3). |
| 5 | Public information about other villages | **Only the inner 3×3 huts**, plus the name label. Tower state is not public (§6). |
| 6 | Late joining | **No late joining.** Only rejoining one's own village after a drop (§8.6). |
| 7 | Village identity | **Name and colour**, both chosen by the player on the multiplayer screen / lobby, from a fixed set of colours, unique per game. **No banner** (§3.1, §3.2). |
| 8 | Web version | **LAN play now.** Keep the design open for a web version later: transport behind `MultiplayerPeer`, discovery in its own node with a small interface, host logic able to run headless (§8.2). |
