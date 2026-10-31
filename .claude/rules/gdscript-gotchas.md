---
paths:
  - "**/*.gd"
---

# GDScript and engine gotchas (learned the hard way)

- **Warnings are errors.** A variable inferred from a Variant, a local shadowing a signal (such as `changed`), a coroutine called without `await`: give the type, rename, `await` in plain `if` branches. Lint does not see warnings-as-errors; a script that fails to parse only shows when you run a bot.
- **Freed objects.** Calling a lambda whose captured object was freed is an engine error even if it checks `is_instance_valid` first; so is `has()` on a typed array holding a freed object. Compare instance ids instead.
- **Deferred calls with a node.** `f.call_deferred(n)` fails ("Cannot convert argument 1 from Object to Object") if `n` is freed before the call runs and `f` types it `Node`: type that parameter `Variant` and check `is_instance_valid` inside.
- **Lambdas capture by value.** A lambda can't assign the caller's local variables: let it fill an Array or Dictionary the caller holds.
- **Typed arrays.** Assigning a filtered array to a typed array fails at runtime: `typed.assign(arr.filter(...))`.
- **Packed arrays inside containers.** `arr[i][k] = x` on a packed array held in an Array or Dictionary can copy the whole packed array. Fill a local one and store it once.
- **BOM in exported games.** A BOM in a string literal (`"﻿"` or the raw character) comes out empty in an export, so `begins_with` on it is always true. Test a code point (`MapJson.without_bom`), build one with `String.chr(0xFEFF)`. The bots run in the editor binary and do not see this: when file reading differs in a release build, check a release export with an autoload probe.
- **Game speed is `Engine.time_scale`.** Speed 0 pauses the tree instead and leaves `time_scale` as it was. Code that must run in real time (UI, `train_pause`, the title backdrop's clock and tweens) divides delta by `maxf(Engine.time_scale, 0.001)` or uses `set_ignore_time_scale(true)`. Anything that changes `time_scale` must reset it on exit.
- **A finished building may be devastated.** "Does its job" is `working()`, not `complete`. `level` lives on `Building`.
- **Monster-camp guards are enemies too** (`CampBehavior`): filter them out when counting a wave's enemies. Wild enemies (wrathwood, camp guards) count for no wave.
- **`game.gd` modes:** `tutorial_mode`, `scenario`, `backdrop`, `networked`; a game can also be `loaded` (`Game.restoring` while it is built). A new game-wide rule may need to respect all of them. A game ends through `Game.end_game`.
- **After adding a `class_name`**, run the import once (see the run-bots skill) or other scripts won't find it.
- **Tools that need autoloads** must run as a scene, not with `-s`.
- **Web input.** The web build turns every `pointermove` into a mouse-motion event, fingers too, and Firefox reports `relative` wrongly for touch: never pan or drag by `relative`, use position differences (see `camera_controller.gd`). Touch also arrives as ScreenTouch/ScreenDrag.
