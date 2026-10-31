---
name: ui-screenshots
description: Take real screenshots of the UI (title, editor, lobby, game, scenarios, ...) on the sandbox's X display with tools/ui_shots.tscn. Use to look at UI changes.
---

# UI screenshots

Needs the sandbox off (the user allowed it for this) and an X display (look in `/tmp/.X11-unix` for `:0` or `:1`). Windows show on that display while it runs.

`DISPLAY=:1 gd --path . --display-driver x11 --rendering-driver opengl3 res://tools/ui_shots.tscn -- --out=<dir> [--only=<name>] [--max] [--cutout=l,t,r,b]`

- `--only` picks one set: the names are the cases listed in `tools/ui_shots.gd` (title, editor, lobby, game, swap, saves, siege, scenario, campaign, ... map).
- `--max` maximises the window for landscape pictures; `--cutout` fakes a phone's camera cutout.
- Use the `gd` wrapper from the run-bots skill. Read the PNGs with the Read tool.
