# Android 3D rendering pilot

The separate debug app `com.pokeaether.android3dpilot` uses the production 3D
renderer, approved v11 model downloader, reviewed model registry, placements,
animation clips and material response. The custom `android_3d_pilot` feature is
accepted only by Android debug builds. Ordinary Android and browser exports keep
their existing platform policy and first-use settings behavior.

The scripted cohort is Pikachu, Bulbasaur, Charmander, Dragonite, Garchomp,
Roaring Moon, Wailord, Weezing, Charizard and Mega Charizard X, normal and shiny.
Public anticipated Mega forms are also prepared by the existing dependency
resolver. Sources/dumps and external model drives are unnecessary: files come
from the published hash-pinned release through the actual downloader.

Twenty stadium observations cover idle, physical attack, sleep and return to
idle. A Mega X preparation/replacement checks that its model is already on disk.
A native Flamethrower effect and the actual licensed grassfield pack are also
exercised. Models, texture resolution, mesh data and animations are unchanged.
This diagnostic measures rendering and model delivery; battle networking and
the complete phone battle UI require subsequent integration tests.
Each pose is observed for 1.5/1.0/0.5 seconds respectively, followed by a 0.1
second return-to-idle observation, with at least three
process frames. These observations establish functionality, not a performance
qualification or a sustained animation benchmark.

## Reproduce locally

Start the existing dedicated emulator following `android-emulator.md`, then:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py --suite android-3d --platform android --architecture x86_64 --sdk /home/adinho/Android/Sdk --output .worktrees/slot-c/frontend/.tmp/android-3d-pilot-final
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_android_3d_pilot.py --fresh --apk .worktrees/slot-c/frontend/.tmp/android-3d-pilot-final/android-3d-pilot.apk --output .worktrees/slot-c/frontend/.tmp/android-3d-pilot-final/native-checks
```

The exporter restores project/presets/editor settings in `finally`. It disables
crash-report prompts, music-pack checks and app-update checks for this diagnostic,
and selects the existing v11 descriptor without changing its hashes or approval.
The APK has a distinct `VERSION-3d-pilot.1` version name and debug package.

The runner checks that APK's package, debug flag and x86_64 libraries and the
fixed AVD identity before installing. `--fresh` clears only this disposable test
app; the regular game, launcher and their downloaded assets are untouched.
The second process keeps downloaded files and must perform zero completed
asset downloads. Cached forest files are verified against the pinned archive.
If emulator graphics are unstable, verify persistence independently, without
resetting app files or repeating rendering:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_android_3d_pilot.py --cache-only --runs 1 --apk .worktrees/slot-c/frontend/.tmp/android-3d-pilot-final/android-3d-pilot.apk --output .worktrees/slot-c/frontend/.tmp/android-3d-pilot-final/cache-checks
```

This verifies all 20 model hashes through the actual downloader and the cached
forest archive/extracted files. It is distinct from a second rendering pass.
The private marker is removed after successful collection; normal full runs
also clear it before starting. The exporter parses the generated pilot before
building its APK.

Reports include engine errors,
normal/shiny identities and SHA checks, frame intervals, preparation phases,
engine memory counters, completed network downloads, and sampled Android
PSS/RSS. PNGs and logs belong only to this diagnostic. Use `--attach` to collect
an already running pilot. The completed app retains model/shiny/arena/camera
controls for visual inspection.

## Emulator graphics workaround

On this Linux host, the Android Emulator host-GPU backend crashed repeatedly,
including without an emulator window. The native core identifies SIGSEGV in
the emulator's gfxstream RenderThread (`TextureResize`, `ColorBufferGl::create`),
not in the Godot app. A software backend avoids that host-driver path:

```sh
ANDROID_AVD_HOME=/home/adinho/.local/share/pokeaether/android-emulator/avd /home/adinho/Android/Sdk/emulator/emulator -avd PokeAether_Android13 -port 5580 -gpu swangle -no-window -no-snapshot -no-boot-anim -no-audio
/home/adinho/Android/Sdk/platform-tools/adb -s emulator-5580 shell wm size 540x960
```

The temporary display override yields a 960×540 landscape target. Restore it
after the test with `adb -s emulator-5580 shell wm size reset`. No models,
textures or AVD userdata are copied. Google documents software graphics as a
workaround for [host graphics problems](https://developer.android.com/studio/run/emulator-acceleration).

## Interpretation

The Android 13 x86_64 AVD has 3 GiB RAM. Its normal framebuffer is 2400×1080;
the software fallback is explicitly measured at the lower target above.
Its GPU translator, driver and CPU differ from an ARM64 phone. Memory counters
are component measurements and must not be added together. Emulator FPS does
not certify phone FPS, battery consumption or thermal behavior.

Remaining qualification includes physical ARM64 devices, mobile GPU texture
support for the shared art pack, visual parity of eyes/colours under the selected
renderer, phone memory pressure, sustained sessions, and full battle entry/UI.
The existing APK exporter can prepare ARM64 debug pilots for those checks.
Godot distinguishes desktop and mobile GPU texture formats in its
[texture import documentation](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_images.html).
Successful texture rendering through an emulator is insufficient to qualify
the existing arena packs on every phone GPU. Lossless archive compression
also does not by itself establish lower runtime RAM or GPU use.

## Recorded pilot: 2026-10-07

The isolated cold-install run passed all 21 observations, every reviewed
normal/shiny hash and pose-state assertion, preloaded Mega X replacement,
and exact cached-cohort reuse. There were no script or engine errors.
The output is retained in the task worktree at
`.tmp/android-3d-pilot-poses/native-checks/`, including 22 PNGs per full run.
This is functional feasibility evidence for the existing assets, not approval
to enable Android 3D in the game.

A second full rendering pass completed the 20 model/pose observations, then
lost emulator communication during the final arena stage. Emulator logs report
invalid color buffers, context-restoration failures and a hanging QEMU CPU
thread. It did not write its completion report and is **not a successful full
warm rendering run**. Host RAM/swap pressure was also high; the exact cause of
this later emulator failure has not been isolated.

After rebooting the same AVD with lavapipe, a separate native cache-only process
verified all 20 model hashes and persisted forest files in 3.405 seconds, with
zero completed downloads, zero downloaded bytes and no engine/script errors.
Its report explicitly sets `cache_only: true`; it makes no rendering claim.
The output is retained at `.tmp/android-3d-pilot-cache-v2/native-checks/`.
The temporary display override was restored and the test emulator closed.

The initial host-GPU runs failed in the emulator driver. The completed fallback
used Android 13 x86_64, GLES Compatibility via ANGLE/SwiftShader, 3 GiB AVD RAM
and an actual 960×540 render target. The cold run took 925 seconds, including
downloads, pose observations, preparation and PNG readback. These software-GPU
timings are unsuitable as estimates of phone loading times or FPS.

Cold-run measurements:

| Measurement | Value |
| --- | ---: |
| Verified downloads, including index/forest and anticipated Mega bundles | 16 / 295,204,047 bytes |
| Installed model files reported by the downloader | 223,861,225 bytes |
| Peak Android process PSS | 592.8 MiB |
| Peak Android process RSS | 681.2 MiB |
| Peak Godot static-memory counter | 301.7 MiB |
| Peak Godot render-memory counter | 491.1 MiB |
| Retained model-resource cache entries at completion | 2 |

These counters overlap or cover different allocations; do not sum them to
estimate a phone's RAM requirement. The complete logged-in game/UI is absent
from this harness, while software-emulator GPU allocations are also different
from a physical phone's driver.

### Issues identified

- The forest pack logs unsupported DXT1/DXT5 formats and converts them to
  RGBA8. This is a concrete arena-texture memory risk, even though loading
  succeeds. Phone-ready arena texture formats need separate investigation;
  transcoding is not automatically lossless.
- The captured forest is unusually bright. Colour/tone parity requires a
  controlled comparison, followed by physical-device review.
- The actual Flamethrower effect is instantiated without errors, but its
  captured frame does not show a visible flame. Its visual timing is not
  qualified by this very slow software run.
- The 21 observations do not cover all model identities, full battle networking,
  UI, sustained sessions or real ARM64 GPU/driver performance.

Next work should isolate arena/texture memory and rendering configuration,
keeping model meshes, textures and animations intact. Lossless download
compression alone will not resolve the Android runtime budget.

Focused checks passed: `android_3d_platform_check.gd`,
`cached_3d_battle_ready_check.gd`, `on_demand_3d_version_pruning_check.gd`, pilot
parse/export checks, Python compilation, the full native cold run and the native
cache-only restart run. Ordinary Android/browser policy is unchanged. The
cached-ready fixture overrides startup cleanup because its catalog and lock
are test-owned; no assertions or performance limits were weakened.

The subsequent [Android arena asset prototype](android-arena-assets.md) measures
art-only pruning and DEFLATE delivery, verifies an ETC2/EAC export and compares
both candidates in the native emulator. It does not yet establish phone memory
savings or qualify the unusually bright forest lighting.
