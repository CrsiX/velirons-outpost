---
name: rebake-title-maps
description: Rebake the title backdrop's maps after changing the map generator or the backdrop scenes' map type or seed. title_bot fails while they are stale.
---

# Rebake the title maps

The backdrop's maps are baked into `data/title_maps/` (`BakedMap`). After changing the map generator or a backdrop scene's map type / seed:

`gd --headless --path . res://tools/bake_title_maps.tscn`

Tools that need autoloads must run as a scene, not with `-s`. Then run title_bot (run-bots skill) to confirm the maps are up to date, and commit the changed files in `data/title_maps/`.
