# 3D on Android

## Player behavior

Regular Android builds offer the login-screen 2D/3D choice automatically.
Neither button is preselected. The Android copy recommends the lighter 2D option
and describes 3D as a regular option. `android_visual_choice_version` records the
choice independently of desktop. Saved choices survive restart and can be changed
in Settings; Android offers only 2D and 3D. Browser remains sprite-only.

The candidate workflow has no experimental dispatch input. Release preparation
and the checked-in Android export preset always include the existing runtime
capability feature. Its legacy internal name, `android_3d_experimental`, remains
for runtime/diagnostic compatibility; it no longer represents an opt-in build.
The old Python `experimental_3d` argument and CLI flag are accepted as no-ops.
Standard builds use Mobile/Vulkan, preserving the shipping 3D renderer and avoiding
the observed Adreno Compatibility shader-link crash during moves.

Only choosing 3D downloads the optional Android battlefield art. This happens
during session preparation or when changing to 3D in Settings. SHA-256 and exact
length checks cover both the downloaded ZIP and its extracted PCK before use.
The installed PCK is reused, and the ZIP is removed after successful install.
The current approved v16 model index supplies shared normal/shiny models and
anticipated battle forms on demand. Team prefetch avoids downloading every
encounter in a map. There is no separate launcher on Android.

Android preserves native-resolution presentation and full model and texture detail. If a foreground 3D session
ends unexpectedly, the next launch saves 2D and tells the player they can retry
3D in Settings. Ordinary Android background termination is not treated as a
crash. Existing local crash reports include device/renderer/experiment details;
the player can copy a report to staff. No automatic telemetry was added.

## Publication prerequisites and historical rollout

Release 0.3.109 restores the experiment in the signed Android build using the
same 1,420 approved normal/shiny pairs as desktop. Existing consent and saved
choices are preserved; players without Android consent receive the choice once.
Choosing 2D is recommended. The GitHub candidate must use a version code higher
than the current public Android release.

`data/android_3d_experiment.json` pins the immutable arena object. The already
generated source archive is retained in the assigned slot at:

```
.tmp/android-arena-assets-v2/android-etc2-art/battle-environment-android-etc2-art-0cd0051c1bf0.zip
```

- ZIP: 13,519,273 bytes, SHA-256
  `11a6e8b0eddd2df656adcd9ba74c658761bf80f0551eb9a5b9dc1665ac137403`.
- Installed PCK: 50,153,852 bytes, SHA-256
  `0cd0051c1bf0491aaad75a0dfd8962ae9e7d60036b3920e47b4aff6ed766da1c`.
- Object key:
  `optional-assets/battle-environments/android/battle-environment-android-etc2-art-0cd0051c1bf0/11a6e8b0eddd2df656adcd9ba74c658761bf80f0551eb9a5b9dc1665ac137403.zip`.
- ZIP members: `forest-runtime/forest.json`, `forest-runtime/forest.pck`.

The exact Android arena archive was published on 2026-10-07 and its public
archive and extracted PCK passed the pinned size and SHA-256 checks. The public
arena pin remains unchanged. Historical v11/v12 model indexes must not be used:
their old ZIP objects may have been retired. The candidate verifies the v14
index's exact hash, resolves its shared-pack references against the compiled
catalog, checks all 1,420 objects are available with the pinned sizes, and repeats
the arena archive and extracted PCK hash checks. Full v14 GET hashes were checked
by the model publication receipt. No duplicate Android model collection is
published. Run the public preflight with:

```sh
python3 tools/verify_android_3d_assets.py --public
```

The Android candidate workflow always runs the public asset preflight before
stamping its 3D-capable build. Use a new valid version code/name for the candidate;
the workflow's defaults are not a proposed release version. It produces a signed
APK and review manifest. Publishing remains a separate, authorized release action.

## Validation and limits

Focused checks cover platform gates, save/reload, separate first-run consent,
browser exclusion, crash recovery, all four localized dialog layouts, exact
cached ZIP/PCK install and rejection of a changed PCK hash. Existing login,
Settings, crash reporting, arena contracts and Mega-form prefetch are retained.
Python release checks confirm default capability stamping, idempotent legacy
argument handling and the Mobile renderer. Local archive verification passes.

The v14 follow-up verifies the actual Android feature guards select all 1,420
current pairs, without a production diagnostic override. The optional
`POKEAETHER_ANDROID_3D_DOWNLOAD_SMOKE=1` mode of
`tests/android_3d_model_release_check.gd` exercises the real downloader, full
pack admission, native scene/animation loading and cache reuse for both
appearances of Hydreigon, Tyranitar, Therian Landorus and Rapid Strike Urshifu.
Run this diagnostic with the Compatibility renderer, not the headless Dummy
renderer. The Linux diagnostic passes; it does not qualify physical Android
GPU performance. Ordinary project checks leave this network diagnostic disabled.

The separate ARM64 `android-visual-choice` diagnostic exports these choice
checks into its own package, `com.pokeaether.androidvisualchoiceqa`, without
production login or updater activity. It can be reproduced from the workspace:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-visual-choice --platform android --architecture arm64-v8a \
  --sdk /home/adinho/Android/Sdk --output /absolute/slot-c/frontend/.tmp/android-choice/apk
```

The exported ARM64 choice diagnostic passed on the Samsung SM-T500 / Android 12
using `gl_compatibility`. Both checks returned zero, including the actual mobile
screen-host path requesting a 3D arena without an initial 2D reveal. The captured
dialog was inspected: both screenshots, the experimental warning, storage
estimate and buttons are visible. No GDScript errors were recorded. Evidence
and hashes are in `tools/sprite_factory/android_visual_choice_results.json`;
the owned test app was force-stopped after collection. A stale generated
diagnostic-scene UID warning used its explicit resource path successfully.

This validates the choice workflow, not sustained 3D battles. The previous
[Tab A7 test](android-tab-a7-benchmark.md) validated model graphs but the complete
Vulkan/Mobile forest workload encountered device loss; a reduced diagnostic
was unplayably slow. This experiment preserves GL Compatibility, whose complete
battle performance and visual quality are not qualified by those Vulkan
results. The existing ETC2 arena encoding is lossy; this task does not introduce
another texture conversion. Do not promise good performance on all Android
devices or label the experimental mode production-qualified. Initial testing
should collect device/Android/GPU details and feedback for entry, switches,
Mega transformations, sleep, effects, repeated battles and switching back to 2D.
