---
paths:
  - "project.godot"
  - "export_presets.cfg"
  - ".github/**"
  - "tools/export.sh"
  - "tools/stamp_version.sh"
  - "scripts/core/build_info.gd"
---

# Web build, exports, CI

- **Never modify anything in `exports/`** (build outputs). Reading the Godot export templates in `~/.local/share/godot/export_templates` is fine.
- **The web build is a PWA** (manifest, icons, offline cache through Godot's service worker). Godot pastes the project name unescaped into the worker's JS string, so `project.godot` has `config/name.web` with a **curly** apostrophe: a straight one breaks the worker. Godot's page registers the worker only when threads are missing, so the Web preset's `html/head_include` registers it. Cross-origin isolation headers are off because the build has no threads. The game asks for persistent storage at start.
- **Build stamp.** `BuildInfo` reads a gitignored `scripts/core/build_stamp.gd` written by `tools/stamp_version.sh`; `tools/export.sh "<preset>" <out> [--debug]` stamps, exports and deletes the stamp again. The editor binary never has one, so the bots can't pick up a stale stamp (tests set `BuildInfo.test_stamp`). The game never runs git. The commit gets a `-dirty` suffix when tracked files have changes (`git diff HEAD`); untracked files don't count. The title screen shows only the part of version and commit that is known, nothing when neither is. CI stamps before importing and checks out with full history (`fetch-depth: 0`) so the tags exist.
- **CI** (`.github/workflows`): every push runs lint, the mapgen job and one job per bot; any failure blocks the Pages deploy. `balance.yml` is manual. CI fetches Godot from the pinned version in the workflows; the sandbox uses the copy in `bin/`.
- Exports need the Godot export templates; Android also needs the SDK and a keystore. Presets are in `export_presets.cfg`.
- Release exports behave differently from the editor binary in a few ways (see the BOM note in gdscript-gotchas); check a release export when file reading differs.
- The game log file is not written on the web.
