---
paths:
  - "scripts/net/**"
  - "scripts/systems/save_game.gd"
  - "scripts/ui/save_list.gd"
  - "scripts/ui/multiplayer_menu.gd"
  - "tests/net_bot.*"
  - "tests/save_bot.*"
  - "tests/coop_bot.*"
  - "tests/run_net_test.sh"
---

# Multiplayer and saving

Design reasoning: `docs/multiplayer-design.md`, `docs/save-design.md`.

- **Host simulates; clients send commands and receive snapshots** of what their village sees (plus every village's huts and name). Anything a client needs to see goes through the replicator; anything a client does goes through a command.
- **Only the host sets speed and pauses.** A client's dialogs don't pause the game.
- **Durable state.** A field that must survive a load needs a line in `SaveGame.capture` and its `_restore_*`. save_bot's round trip (save, load, save again: same body) catches most misses. **Changing the body's layout means bumping `SaveGame.FORMAT`**: old saves are refused, not migrated.
- **Saving only happens between waves.** Nothing of a running wave is ever stored: a game left mid-wave resumes from the end of the wave before. After a load, whatever anything was doing restarts: whoever is out in the field asks once what to do (`Civilian.resume_work`); units on a sortie are back on their bench.
- Scenarios can't be saved. Co-op saves load only in the lobby (the host assigns each player a saved village).
- Co-op map rules: each village has its own slice, spawns and fog; a village falls and can stand again; help is sent by caravan (resources) or walking units, with a tax.
- Net tests: `tests/run_net_test.sh <path to gd>` runs generated, custom-map and resumed-save variants.
