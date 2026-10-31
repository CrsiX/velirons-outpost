---
paths:
  - "scripts/ui/**"
  - "scripts/core/screen_layout.gd"
  - "scripts/core/settings.gd"
  - "scripts/tutorial/**"
  - "tests/hud_bot.*"
  - "tests/build_bot.*"
  - "tests/title_bot.*"
  - "tests/library_bot.*"
  - "tests/stats_bot.*"
  - "tests/tutorial_bot.*"
---

# UI, HUD, controls

Design reasoning: `docs/ui-design.md`, `docs/tutorial-design.md`, `docs/statistics-design.md`. Screenshots: ui-screenshots skill.

- **Hotkeys.** The single list is code: `Hud.KEYS_HELP` (shown by F1) must stay in step with every new key; hero-mode keys are `Hud.HERO_MODE_KEYS`; keys that close the tactical map first are `Hud.MAP_CLOSING_KEYS`. Don't copy the table into docs.
- **Esc and popups.** Esc closes the newest open popup like its Close / Cancel (never its OK). Every popup registers with `Hud.register_popup`; with none open, Esc pauses and opens settings. The library and statistics close themselves.
- **Pausing screens.** Settings, library and statistics pause the game in single player (greyscale behind them), go back to the earlier speed when closed, and never pause in networked co-op.
- **Stretch and layout.** `canvas_items`, aspect expand; `Layout` switches content scale for portrait and, on desktop, scales the UI by `Config.UI_SCALE` and the user's *UI size* setting. The map does not shrink with it: cameras zoom by `Layout.world_scale` (`CameraController.set_view_zoom`, clamp with `zoom_limits()`). A SubViewport shown in the UI must be sized by the final transform's scale or it is blurry (see `TitleBackdrop._fit`).
- **Portrait and landscape** switch automatically; the UI keeps the same physical size. In portrait the dock becomes a bottom sheet. HUD code mixing screen positions with its own uses `Hud.to_ui`; on phones the HUD keeps clear of cutouts (`Layout.insets`) while the map fills the screen (`Layout.inset` / `Layout.bleed`).
- **Touch vs mouse.** A mouse hovers a placement preview and a click builds; a finger shows the preview with Build / Cancel under it. Never pan or drag by `relative` (see gdscript-gotchas). Check/cross use icons, not characters (mobile browsers lack them).
- **Picking** is by the art's pixels, front-most first, tap again for what is behind (`Config.PICK`, `docs/ui-design.md` §7).
- **Costs and popups** follow resources while open (`Hud._refresh_dialogs`). Costs show with icons.
- **The library is built from Config** (every kind has an entry; library_bot checks). New kinds and categories need entries.
- **Statistics** count on the host through hooks and the Economy signals; nothing counts before `Stats.start`, after game over, or in the backdrop. Co-op clients ask the host.
- **Title backdrop** is a real game played in slow motion on baked maps; no input, raids, fog or defeat there. New game-wide rules must respect it.
- **Debug builds** (`OS.is_debug_build()`, so the bots too, never a release export) add *Debug...* to the settings. Debug actions are commands. Release hosts refuse them.
- **Tutorial** is a guided game on a fixed map with waves that wait; steps end when done, nothing is blocked. Keep a new step in the design doc's order.
- **F2** saves a screenshot; **F3** steps the log level. The log keeps everything regardless of the level shown.
- **Game log file, co-op.** `Game.log_all` writes a message once for every village: `GameLog.begin_all` mutes the villages' own copies while it runs. Keep that when adding log calls that address all villages.
