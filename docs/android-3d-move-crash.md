# Android native crash when a move is presented

The 2026-10-13 phone report from build
`edaf9480d3f7d46369abb3e21d770fe18e8c7156-38426600297-1` identifies
`CRASH_NATIVE`, status 11, on SM-S938B / Adreno 830 / Compatibility / Godot
4.6.2. The user observes the crash for every selected move. At the initial
investigation no native stack or physical device was available; the phone
follow-up below establishes the failing native path and a tested workaround.

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

## Physical phone follow-up, 2026-10-13

ADB access to the SM-S938B supplied the original native crash buffer. Official
Godot 4.6.2 ARM64 template-release symbols match the library's Build ID
`a1dc416352711900`. PC `0x201c14c` resolves to
`ShaderGLES3::_compile_specialization`, `shader_gles3.cpp:424`, at
`glLinkProgram`. The preceding driver frames are in Qualcomm's `libllvm-qgl.so`
and `libGLESv2_adreno.so`. This is a driver crash during shader linking, not a
pose-baking stack.

The signed full-game USB candidate `ddfebe45d-3d-usb-20261013-1`
(`0.3.109-3d-usb.1`, code 29) retained app ID 10377 and the game's data directory.
Its new report recorded `move_wait`, and the move crashed at the same native PCs.
Avoiding pose baking alone does not resolve the reported phone crash.

A separate offline ARM64 debug app, `com.pokeaether.androidmoveprobe`, passed all
24 base move effects at creation, launch and impact on this phone's actual
Compatibility renderer. It uses synthetic BoxMesh actors and a directional
light, without real battle models or the production arena. It does not prove
the complete battle rendering combinations safe.

Reproduce that scoped probe with `tools/export_battle_entry_web_qa.py --suite
android-moves --platform android`, explicit ARM64 SDK/JDK paths and a slot-local
output directory. Run it through `slot-env`. Before each draw, the probe closes
`user://android-move-shader-marker.json`; its synthetic move/phase values and the
final `android-move-shader-results.json` are readable using `adb shell run-as`
for this separate debug package. The probe APK has no internet permission.
The ordinary game and its downloaded/user data are not reset.

The signed full-game candidate `2a30adf78-3d-usb-20261013-2`
(`0.3.109-3d-usb.2`, code 30) uses Mobile/Vulkan. Its startup log confirms
Vulkan 1.3.284 / Forward Mobile / Qualcomm Adreno 830. The user repeated the
3D battle test and confirmed that moves no longer crash. The app process
remained alive, with no new fatal signals in the Android crash buffer after
the test. The same signing identity, app ID and data directory were retained.

`android_release.prepare(..., experimental_3d=True)` now selects Mobile/Vulkan;
ordinary Android exports select Compatibility. The USB helper follows that
default and retains an explicit Compatibility override for comparison. No
official release, publication, promotion or complete release certification
was performed. This is a successful SM-S938B battle smoke test, not certification
of other Android GPUs or all battle/model/effect combinations. Full visual
parity, switches and subsequent battles still need broader assessment.

The existing startup `can_process` / `!is_inside_tree()` warning also appears
with Vulkan. It did not accompany a fatal signal in the successful test and
remains a separate issue; it is not evidence for the shader-link crash cause.
