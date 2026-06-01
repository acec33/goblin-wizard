# Goblin-Wizard — project memory

Top-down melee **brawler** built in **Godot 4.6** (GL Compatibility renderer) on macOS.
You fight off endless hordes of dagger-wielding goblins.

## Vision / roadmap
- Core loop: move around an arena, melee-swing at goblins, survive escalating waves.
- **Planned: add a castle** (defend it / base to protect — design TBD with the user).
- Art is made by the user in **Pixellab AI** (pixel art). Art is produced incrementally;
  the game is scaffolded with placeholder visuals so it runs before art exists.

## Current state (scaffold)
- `Scenes/main.tscn` — main scene (set as run/main_scene). Root `Main` runs `Scripts/main.gd`.
- `Scripts/main.gd` — game manager: spawns waves, tracks Kills/Wave, HUD (built in code),
  draws the dark grid arena, game-over + "press any key to restart".
- `Scripts/player.gd` (`Scenes/player.tscn`) — the **blue ninja**. WASD/arrows to move;
  left-mouse / Space / J to punch in the direction the player is **facing** (NOT toward the mouse).
  8-direction walk + idle via an `AnimatedSprite2D`. Facing only updates while a movement key is
  held; idle preserves the last facing. Punch picks `punch_left`/`punch_right` by which side
  of his body the facing vector is on (facing.x < 0 = left). Has health + hit flash; Camera2D follows.
  Idle/walk/punch state machine keyed off `DIR_NAMES` (8-way, derived from velocity/aim angle).
  Punch damage lands on the animation's LAST frame (`frame_changed`) and applies knockback to
  goblins (`goblin.take_damage(amount, knockback_vec)`; goblin decays it via `knockback_decay`).
  Landed punches also trigger **hit-stop** (`Engine.time_scale=0` via an ignore-time-scale timer)
  and **camera shake** (trauma on the child Camera2D). Tunables under the `Game feel` export group.
- `Scripts/goblin.gd` (`Scenes/goblin.tscn`) — `AnimatedSprite2D` goblin with a run/slash/idle
  state machine in 8 directions (faces the player). Chases, then slashes in range; the stab lands
  on the slash's LAST frame. Takes knockback (`knockback_decay`). Has health, dies, reports kills.
  In group `"goblins"`; player in group `"player"`.
  **Random variants:** many directions have multiple run/slash art versions, named
  `run_<dir>_<n>` / `slash_<dir>_<n>`. `_build_variant_map()` groups them by direction and
  `_play_group()` picks one at random per entry (not per frame, so no flicker).

## Conventions
- **Build with NODES/SCENES, not code (the user edits in the Godot editor).** Prefer creating
  visuals, UI, layout and configuration as nodes in `.tscn` files with `@export` vars, NOT built
  in GDScript. Place instances in scenes (e.g. Player & HUD live in `main.tscn`) rather than
  spawning them from code. Runtime *logic* (wave spawning, AI, state machines, hit detection) stays
  in scripts, but expose tunables as `@export`. When something must be code, explain why.
- Folders are **capitalized**: `Scenes/`, `Scripts/`, `Assets/` (art goes in Assets/).
- Placeholder art = `res://icon.svg` on a `Sprite2D`, tinted via `modulate` (player=blue,
  goblin=green), scaled down.
- **Swapping in real art** = select the `Sprite2D` in the entity's `.tscn`, drop the Pixellab
  sprite into its `Texture` slot, and reset `Modulate` to white. No code changes needed.
- Tunable gameplay values are `@export` vars at the top of each script (speed, damage, health,
  wave size, spawn radius, etc.).

## Art pipeline (Pixellab → Godot)
- Pixellab exports per character into `Assets/<name>/` with `walk/`, `Idle/`, `punch/` subfolders
  of PNG frames (236×236). **The on-disk folder layout is the source of truth — `metadata.json`
  describes the original export and may not match how the user reorganized files.**
- Blue ninja (236px frames) has: walk = all 8 dirs (6 frames), idle = animated *south* + a still
  per other dir, punch = left & right only.
- Goblin (80px frames) has: run (8 dirs, 2 variants each, *north-west has 3*), slash attack
  (8 dirs, 1-3 variants each), idle stills (8 dirs from `running/rotations`).
- Many frames → a `SpriteFrames` resource is GENERATED, not hand-written. One generator per
  character (their on-disk layouts differ):
  `tools/gen_spriteframes.py` → `Assets/blue-ninja/blue_ninja_frames.tres`
  `tools/gen_goblin_spriteframes.py` → `Assets/Goblin/goblin_frames.tres`
  Multi-variant anims are named `<state>_<dir>_<n>`; single ones `<state>_<dir>`. Re-run after
  adding/changing frames.
- After adding/altering art, assets must be imported before runtime `load()` works:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --import`.
- Quick headless smoke test (catches script/scene errors without a window):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 60`.

## Tooling notes
- User is newer to dev tooling/terminal/CLI — explain concepts in plain language, avoid jargon.
- The `claude` CLI is NOT installed in their terminal; they interact with Claude another way.
  So MCP setup via `claude mcp add` won't work — use a project `.mcp.json` file instead.
- **Pixellab MCP (pending setup):** HTTP transport, url `https://api.pixellab.ai/mcp`,
  header `Authorization: Bearer <key>`. Docs: https://api.pixellab.ai/mcp/docs
  (User shared a key in chat once — recommend regenerating it before committing anywhere.)
