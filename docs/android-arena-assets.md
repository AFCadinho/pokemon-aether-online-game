# Android arena asset prototype

## Status (2026-10-07)

This is a local diagnostic candidate, not an Android 3D release. It follows
[the native 3D pilot](android-3d-pilot.md). No R2 upload, release index,
production setting or ordinary Android/browser 2D policy changes.

The purchased TemperateForest source was available in slot-c, despite the
external model drive being disconnected. Pokémon assets were not edited.

## Measured delivery sizes

All sizes below are decimal MB; archives contain the PCK and schema-1 manifest.

| Variant | Installed PCK | Download ZIP |
| --- | ---: | ---: |
| Existing complete forest export | 71.34 MB | 71.34 MB (stored ZIP) |
| Desktop art only | 50.15 MB | 13.82 MB (DEFLATE) |
| Android art only, ETC2/EAC | 50.15 MB | 13.52 MB (DEFLATE) |

The art-only export uses the same dependency roots as `ForestArtPack.prepare()`.
It excludes unused world/terrain data and native vendor code. Original art
files were SHA-256 checked before and after export and did not change. All 42
retained desktop CTEX payloads are byte-for-byte identical to the old pack.
DEFLATE extraction was also verified to reproduce the exact PCK hash.
These two savings are lossless: about 29.7% less installed pack storage and
80.6% less download for the desktop candidate. A compressed ZIP does not
reduce the unpacked PCK's storage or GPU memory.

Android has 41 ETC2/EAC texture payloads and the unchanged lossless ground
normal texture. All 42 keep 1024 × 1024 resolution and the original mip count.
Changing VRAM encoding is lossy; this candidate does **not** satisfy an exact
pixel-equivalence requirement.

Pack SHA-256:

- Desktop: `0de83e846a56b53685fc9e657027a47ea643da332bb85b4ebcf124aa8e5112cd`
- Android: `0cd0051c1bf0491aaad75a0dfd8962ae9e7d60036b3920e47b4aff6ed766da1c`

## Native comparison

Separate fresh processes of debug package `com.pokeaether.androidarenapilot`
loaded each pack through the production art loader and built the real generic
grassfield. Fixed camera, noon lighting, disabled wind, one 960 × 540 viewport
with 4× MSAA. No Pokémon, accounts, battle network or production asset service.
The local fixture server binds to loopback and uses a temporary adb reverse;
its PCK bytes are checked against generated size and SHA-256 pins.

Android 13 / API 33 x86_64, Godot 4.6.2 Compatibility/GLES 3.1,
headless emulator graphics backend `lavapipe` (ANGLE/llvmpipe):

| Observation | Desktop art | Android art |
| --- | ---: | ---: |
| Loader + real arena + screenshot | Passed | Passed |
| Loaded art root resources | 40 | 40 |
| Script/engine errors | 0 | 0 |
| Unsupported-format conversion warnings | 41 | 0 |
| Sampled peak process PSS | 448.6 MiB | 447.9 MiB |
| Sampled peak process RSS | 542.4 MiB | 541.6 MiB |
| Godot static memory after drawing | 261.0 MiB | 261.0 MiB |
| Godot reported render memory | 171.7 MiB | 171.7 MiB |

**No meaningful native process-memory saving was demonstrated.** These PSS/RSS
samples include the diagnostic game's autoloads, not just arena textures. Do
not add static, render, RSS and PSS values together. The software emulator
cannot establish physical ARM64 GPU residency or phone frame rate.

Equal Godot render counters are not evidence that the two GPU uploads consume
identical physical VRAM: the GLES texture accounting uses the original image
format when initializing texture bytes, even when upload converts an unsupported
format. See Godot's [`texture_2d_initialize` and upload conversion](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/storage/texture_storage.cpp).
The absence of conversion warnings establishes format compatibility in this
runtime, not a quantified phone memory budget.

## Image findings

All 42 CTEX images decoded successfully. Base-level albedo/cutout comparisons
(30 images, excluding normal maps) measured a minimum visible-RGB PSNR of
34.61 dB and maximum alpha RMSE of 3.28/255. Normal X/Y channel RMSE was at
most 1.94/255. These are measurements, not acceptance thresholds; mipmap
pixels were not individually compared.

The two native captures measured RGB PSNR 28.84 dB and exact opaque output
alpha. They are visibly similar in overall composition, but not pixel identical.
Both retain the unusually bright/neon grass seen in the earlier pilot. Thus
ETC2 alone does not fix the colour/tone problem. No visual approval is implied.
A host desktop rendering probe did not finish and was terminated; no host
render result or desktop/mobile lighting parity is claimed from it.

Evidence retained in the assigned slot:

- `.tmp/android-arena-assets-v2/report.json` — full source/pack hashes, sizes,
  dependency lists and texture metadata.
- `.tmp/android-arena-assets-v2/image-comparison.json` — decoded image metrics.
- `.tmp/android-arena-native-v1/{desktop-art,android-etc2-art}/` — report,
  per-process logs, sampled memory and unmodified native screenshots.
- `.tmp/android-arena-apk-v1/` — separate emulator-only debug APK and export logs.

## Reproduction

Run from the workspace control-plane, with slot-c assigned to this task. Use
absolute source, reference and output paths; replace example paths as needed.
The exporter restores temporary source metadata and never transfers `.godot`
caches between projects.

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_android_arena_assets.py \
  --source /absolute/path/to/isolated/TemperateForestPack-main \
  --reference /absolute/path/to/existing/forest.pck \
  --output /absolute/path/to/slot-c/frontend/.tmp/android-arena-assets-v2

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-arenas --platform android --architecture x86_64 \
  --sdk /home/adinho/Android/Sdk \
  --output /absolute/path/to/slot-c/frontend/.tmp/android-arena-apk-v1

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_android_arena_assets.py \
  --assets /absolute/path/to/slot-c/frontend/.tmp/android-arena-assets-v2 \
  --apk /absolute/path/to/slot-c/frontend/.tmp/android-arena-apk-v1/android-arena-pilot.apk \
  --output /absolute/path/to/slot-c/frontend/.tmp/android-arena-native-v1
```

The runner requires the existing dedicated `PokeAether_Android13` emulator on
port 5580. It only installs/stops its own debuggable package, serves locally,
removes its adb reverse and stops its diagnostic on completion. The normal game
package is never reset. No display-size override was used in this comparison.

For CPU texture metrics, write each candidate's `textures` report list to
`texture-list.json`, then run `arena_texture_probe.gd` with absolute pack,
list and decoded-directory arguments in a fresh headless slot process. Run
`compare_arena_asset_images.py --assets ... --native ...` afterward (Pillow).

Focused validation: both `forest_art_pack_check.gd` candidate runs, GDScript
parse checks, Python compilation, exact source/desktop CTEX/ZIP hash checks,
42-texture decode checks and both native arena runs passed. No full release
certification was requested or performed. One stale generated-runner UID
warning appeared in both APK runs and resolved via its correct text path;
it did not prevent loading. No native Terrain3D module was loaded.

## Next step

Keep the measured lossless pruning/transport improvements as release candidates.
Before Android 3D enablement, isolate the Compatibility shader/lighting colour
issue, then qualify ETC2/EAC on a physical ARM64 GPU (image quality, actual
memory, sustained battles and effects). Also measure terrain/grass geometry
and dual-render-pass cost; a smaller download alone is insufficient. Extending
this prototype to Pokémon packs should use their approved runtime resources,
with independent material, alpha and animation checks; it was not part of this
arena-only experiment.

The subsequent [lighting investigation](android-arena-lighting.md) reproduced
the neon forest on desktop Compatibility and obtained matching desktop/native
Android colours with Mobile/Vulkan while retaining shadows. The emulator needed
an isolated frame-pacing workaround. Phone memory/performance qualification is
still outstanding.
