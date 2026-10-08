# Optional experimental 3D on Android

## Player behavior

An Android build with the custom feature `android_3d_experimental` offers the
existing login-screen 2D/3D choice. Neither button is preselected. The Android
copy recommends 2D and explicitly warns that 3D may run slowly or crash.
`android_visual_choice_version` records consent independently of the desktop
rollout flag. Choice survives restart and can be changed in Settings; Android
offers only 2D and 3D. Browser, standard Android and desktop behavior stay as
before. Android retains its existing Compatibility renderer and immersive UI.

Only choosing 3D downloads the optional Android battlefield art. This happens
during session preparation or when changing to 3D in Settings. SHA-256 and exact
length checks cover both the downloaded ZIP and its extracted PCK before use.
The installed PCK is reused, and the ZIP is removed after successful install.
The same existing approved v11 model index supplies normal/shiny models and
anticipated battle forms on demand. Team prefetch avoids downloading every
encounter in a map. There is no separate launcher on Android.

The experiment renders the 3D layer at at most 960 × 540, retaining aspect
ratio and leaving the UI at its normal resolution. This is a rendering limit,
not a reduction of mesh or source texture detail. If a foreground 3D session
ends unexpectedly, the next launch saves 2D and tells the player they can retry
3D in Settings. Ordinary Android background termination is not treated as a
crash. Existing local crash reports include device/renderer/experiment details;
the player can copy a report to staff. No automatic telemetry was added.

## Publication prerequisites

Release 0.3.102 enables the experiment in the signed Android build (version code 19). Both existing and new Android players receive the choice once; choosing 2D is recommended.

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
v11 model index also passes its exact hash check; existing v11 models do not
need republishing. The candidate build repeats this public verification:

```sh
python3 tools/verify_android_3d_assets.py --public
```

The Android candidate workflow has an `experimental_3d` dispatch input,
defaulting to false. Setting it to true requires the public preflight to pass
and stamps the custom feature. A subsequent standard build explicitly removes
that feature. Use a new valid version code/name for the candidate; the existing
workflow's default version values are not a proposed release version. The
workflow produces a signed APK and review manifest under the existing Android
release procedure. Publishing remains a separate, authorized release action.

## Validation and limits

Focused checks cover platform gates, save/reload, separate first-run consent,
browser exclusion, crash recovery, all four localized dialog layouts, exact
cached ZIP/PCK install and rejection of a changed PCK hash. Existing login,
Settings, crash reporting, arena contracts and Mega-form prefetch are retained.
Python release checks confirm explicit feature stamping/removal and unchanged
Compatibility renderer. Local archive verification passes.

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
