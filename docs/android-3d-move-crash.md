# Android native crash when a move is presented

The 2026-10-13 phone report from build
`edaf9480d3f7d46369abb3e21d770fe18e8c7156-38426600297-1` identifies
`CRASH_NATIVE`, status 11, on SM-S938B / Adreno 830 / Compatibility / Godot
4.6.2. The user observes the crash for every selected move. There is no native
stack trace and no physical device connected locally; the cause is unconfirmed.

One shared move path calls `_effect_bounds` for source and destination anchors.
Older reviewed profiles without idle bounds previously baked their live skeleton
pose to obtain an AABB. In Godot 4.6.2 that operation reads surface arrays, and
Compatibility retrieves the vertex, attribute, skin and index buffers through
GPU readback (`glMapBufferRange`). This is unnecessary for a placement estimate.
Sources: [pose baker](https://github.com/godotengine/godot/blob/4.6.2-stable/scene/3d/mesh_instance_3d.cpp),
[surface readback](https://github.com/godotengine/godot/blob/4.6.2-stable/drivers/gles3/storage/mesh_storage.cpp),
[buffer readback](https://github.com/godotengine/godot/blob/4.6.2-stable/drivers/gles3/storage/utilities.cpp).

Android now keeps the reviewed idle envelope where available and otherwise uses
stored mesh AABBs, transformed into actor space once and cached in model units.
Live scale and position still apply on every sample. This avoids runtime pose
baking on Android while retaining models, textures, skeletal animation and VFX.
The fallback envelope can differ from the idle pose; older models' effect/HUD
anchors and contact clearance need visual assessment on the phone.

The crash service persists an allowlisted move phase before model/effect native
operations. It reports only fixed code labels, never Pokémon, move names, actor
IDs, battle IDs or payloads. These phases identify the last CPU operation, not a
GPU stack trace; a delayed render-thread failure may occur after a phase finishes.
`move_complete` marks the end of that presentation boundary, not the whole turn.

Focused checks (run through `ops/worktrees/slot-env slot-a -- godot`):

- `--headless --path .worktrees/slot-a/frontend --script res://tests/android_3d_move_bounds_check.gd`
  checks a skinned fixture that cannot be baked, hidden mesh exclusion, transforms,
  cached bounds with live scale, and reviewed envelope precedence.
- `--headless --path .worktrees/slot-a/frontend res://tests/android_3d_move_execution_check.tscn`
  checks 24 native effects across four slots with Android tags and no reviewed
  bounds, including impact recovery, miss/cancellation, Substitute, optional audio
  and target replacement.
- `client_crash_reporting_check.gd` checks marker persistence and rejection of
  free-form values at both storage and report generation.
- `battle_move_presentation_routes_check.tscn` and
  `battle_move_effects_3d_check.tscn` retain desktop routing/effect coverage.

These local fixtures do not reproduce or certify the Adreno driver. The next
phone build must complete several turns with physical, special and status moves,
then a switch and another battle. If it still crashes, collect the new full report
with its move phase and, if ADB is available, the native crash backtrace. Do not
claim the reported crash resolved until the phone passes.

Local results: all five focused checks above passed on Godot 4.6.2. The execution
fixture also passed with a real Compatibility/OpenGL render on AMD Radeon/Mesa.
The move fixtures emitted the slot cache's existing shared-model verification
warning during startup; there were no move script/engine errors. No Android APK,
release certification, promotion or publication was performed for this task.
