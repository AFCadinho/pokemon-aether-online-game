# Android model depth prepass

## Problem and fix (2026-10-21)

Golem and Alakazam had overlapping facial and body surfaces on Android while
rendering correctly on desktop. Reproduced with the same v16 PCKs in an isolated
Godot 4.6.2 debug APK on SM-S938B / Adreno 830, OpenGL ES 3.2, driver
V@0800.64.8. The installed ordinary client was 0.3.116; it was not replaced.

The source materials use `TRANSPARENCY_ALPHA_DEPTH_PRE_PASS`. Godot's GLES3
configuration disables the depth prepass for matching GPU vendor names, including
Adreno. Its opaque color pass skips these transparent surfaces; without the
prepass their own overlapping triangles have no opaque depth to test against.
This exposes the mouth interior through the snout and hides eyes behind other
surfaces. CPU skinning and a shorter camera depth range did not fix it.

`project.godot` now enables the depth prepass explicitly on Android and clears
its vendor exclusion **only on Android**. Source materials, alpha, vertex colors,
animations and model packs are unchanged. Forcing opaque materials was rejected:
it fixed Golem but broke Alakazam's authored alpha masking.

Engine references (pinned 4.6.2):

- [GLES3 vendor exclusion](https://github.com/godotengine/godot/blob/4.6.2-stable/drivers/gles3/storage/config.cpp)
- [GLES3 depth and transparent passes](https://github.com/godotengine/godot/blob/4.6.2-stable/drivers/gles3/rasterizer_scene_gles3.cpp)

## Focused verification

- Physical phone: Golem and Alakazam, normal/shiny, `idle`, `special_attack`,
  `sleep` sampled at 50%: all 12 captures visually inspected after the fix.
- The APK logged the effective Android settings: prepass `true`, vendor exclusion
  empty. Tested the actual `.android` overrides, not just base desktop settings.
- Each fixed pose sampled 90 frame intervals at the phone's native viewport:
  p50 8.246–8.332 ms, p95 8.718–9.439 ms. This is a small isolated model smoke,
  **not** a full battle benchmark or a measurement of the incremental pass cost.
- `tests/android_quality_performance_check.gd` passed in slot-a.
- `git diff --check` passed.

Local retained evidence is in `.tmp/android-face-probe/`: `app/main.gd`,
`app/project.godot`, `face-probe.apk`, `verified-phone.log`, individual captures,
`contact.png`, and SHA-256 checks in `evidence.json`. The isolated package is
`com.pokeaether.faceprobe.slot_a`; it uses no game account or network service.
The final probe loads the original model packs from its own `user://`, renders
three poses of both appearances, and logs the effective settings and frame times.

Original v16 pack SHA-256:

- Golem: `79e45e2895e08a8374ceb61aeaa71093bda8c3921af8c9bc9a44802b0ae17604`
- Alakazam: `43a5ce10098e266c299cc9e1fa428b2096c959df327aecaa738fee4211fa864c`

## Remaining scope

The extra depth pass applies to Android scenes generally, so lower-end GPU and
full-arena performance still need release/device qualification. Other GPU families
were not physically tested. A new ordinary Android client build is needed to ship
the settings; reinstalling model packs alone cannot apply them.
