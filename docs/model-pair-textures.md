# Shared normal/shiny bundle prototype

## Result — 2026-10-07

The [individual texture proof](model-texture-sharing.md) now has a portable
pair-bundle follow-up. Three approved pairs use shared, byte-identical texture
resources inside a hash-pinned **PCK**. No resizing, image encoding changes,
geometry reduction, pose changes or material simplification.

| Pair | Baseline PCK | Shared PCK | Actual PCK saving | Android texture-counter reduction with both appearances loaded |
| --- | ---: | ---: | ---: | ---: |
| Dragonite | 14,805,612 bytes | 11,536,360 bytes | **22.08%** | **19.51 MiB** |
| Zapdos Galar | 13,767,020 bytes | 11,158,548 bytes | **18.95%** | **19.01 MiB** |
| Moltres Galar | 16,501,804 bytes | 13,893,652 bytes | **15.81%** | **12.99 MiB** |

Combined PCK size falls from **45,074,436 to 36,588,560 bytes**: 8,485,876 bytes
or **18.83%**. These are complete candidate/control packs including namespace
tables and manifests. Both use the existing v11 native Zstd codec: level 9,
262,144-byte blocks. Baseline scene bytes match their exact approved v11 hashes;
container differences are included rather than credited as a codec change.
These percentages are a three-pair result, not a whole-Pokédex estimate.

## Sources and quality

The external disk is available again. Dragonite came from the existing approved
v7 archive on it, SHA-256
`a777fdf3715c4d67cf85dfed8daec3aee327cb7ee68e8c14bcfd63c1cca23e5f`.
Both original scene hashes and decompressed bytes match the current v11 lossless
bindings. The experiment generated fresh v11-normalized input files in its own
slot. Galar sources were already retained there and their decoded bindings were
verified as well. No external source/dump was edited, re-converted or copied
between checkout caches.

All six appearances preserve their complete semantic resource values: every
texture format, dimension and mip byte, names/metadata, independent material
parameters, mesh buffers and animation tracks. The audited sharing key excludes
local-to-scene textures and merges only matching ImageTexture resources. The
canonical pool exists only during offline generation, separately for each pair.

**60 fixed-pose comparisons pass without a pixel tolerance**: 59 are byte-exact
against the first original capture. Dragonite's first idle capture differs at
98 pixels, maximum channel delta 7/255, but the candidate is byte-exact against
the independently reloaded original control. This control distinguishes render
startup variation from candidate data changes. Raw captures and the three-way
comparison are retained; this is not a claim that arbitrary repeated GPU frames
are universally identical.

Both views include idle, physical/special attack, sleep and faint for normal and
shiny. Dragonite uses the actual schema-1 main/irradiance presenter, with clone
pose synchronization checked. Galar actors use their authored schema 0. All
packed scenes leave the presentation on release. Host renderer: Godot 4.6.2
Mobile Vulkan, NVIDIA RTX 3070 Laptop. Each model's source and candidate are
rendered separately; this visual test is distinct from the simultaneous pair
texture allocation measurement below.

## Native Android loader proof

All **six baseline/shared cases** pass in the separate debug application
`com.pokeaether.androidmodelpairs`, Android 13 x86_64 emulator, software
llvmpipe/Mobile Vulkan:

- Download full pinned PCK from the owned loopback fixture; verify bytes/SHA
  before mounting. Install in a new diagnostic userdata location, independent
  of the generator's physical paths and existing production caches.
- Verify the manifest, every file hash/size and the complete dependency closure
  before threaded loading; all dependencies remain in the pack's own namespace.
- Load both appearances using the ordinary `CACHE_MODE_IGNORE` threaded loader.
  External resources reuse Godot's existing resource cache, so the pair shares
  **12 / 7 / 15 actual texture objects** respectively. Baselines share none.
- Compute every loaded appearance's semantic digest on the native runtime,
  including image readbacks of all existing mips. All six match the approved
  source values, and post-load hashes remain unchanged.
- Keep shiny valid after normal leaves, then leave the loading coroutine's scope
  and confirm **zero remaining texture weak references**. No permanent global
  texture pool was introduced. Scope matters: temporary Variant values inside
  the diagnostic coroutine can retain the last scene until that scope exits.

The native texture-counter reductions in the table are measured with both
variants alive, after counter settling. The normal-only saving is smaller;
this does not make every single encounter use 20 MiB less. The packs are installed
as one file each, so their `pack_bytes` are also their diagnostic disk footprint.

Cold-load measurements in this single software-emulator run ranged from
0.44–1.45 seconds in the baselines and 0.33–1.35 seconds in the shared cases.
Shiny follows normal in the same process and benefits from reuse; these are not
phone latency/FPS claims or a statistical benchmark. The APK has its own app
data, and the collector forces only that app to stop. It does not erase any
cache, models or user sessions. The owned emulator was closed after collection.

No native script/engine errors occurred. The exporter applies the existing
emulator-only frame-pacing/shader-cache workaround to this transient x86_64 debug
export; production and phone defaults are unchanged. Its generated-runner UID
fallback warning is recorded and does not change source model data.

## Why PCK rather than relative scene files

The first external-resource layout had absolute generator paths. A second
attempt used relative binary resource paths; Godot 4.6.2 resolved those paths
incorrectly instead of relative to the owning scene. Its binary loader code
uses the dependency path's directory in that branch:
[Godot binary resource loader](https://github.com/godotengine/godot/blob/4.6-stable/core/io/resource_format_binary.cpp).
Neither failed attempt is treated as a portable bundle.

The successful layout uses a closed, source/recipe-specific virtual namespace
inside each PCK. Paths are the same on desktop and Android regardless of where
the PCK is installed. The baseline and shared variants have separate namespaces;
pack mounting does not override existing resource files. Namespace identity and
all file hashes are part of the prototype fixture.

An engine-mounted pack remains registered: **zero texture references does not
mean zero pack-index/file-table memory**. Godot does not offer a general unmount
API here. A production design must account for mounting/index overhead and new
asset namespaces across updates, and avoid eagerly mounting the entire catalog.

## Status and adoption work

The [16-pair cohort follow-up](model-pair-cohort.md) broadens this result and
separates codec savings from sharing. The [installation design](model-pair-installation-design.md)
lists the launcher, on-demand, cache and update changes required for adoption.

This is locally integrated **research tooling and a debug loader**, not a new
production model contract. No reviewed registry, v11 index, optional asset
service, launcher installer, production scene cache or platform presentation
policy was changed. No upload, push, deployment or release occurred.

Next: broaden the cohort to common base species and heavier/effect/form models,
then design the production PCK installation/validation contract. Current v11
admission deliberately rejects externally dependent scenes from its prepared
LRU. Adoption needs the entire pack hash and namespace in the admission/update
identity, conservative accounting for shared dependency bytes, cache lifetime
checks, launcher/game installation support and new reviewed candidate bindings.
Do not weaken v11's exact decompressed-stream gate: shared resources change the
stream and require their own semantic/image/pose qualification.

The original physical phone limitation remains. The native loader and GPU
texture counters are qualified on this emulator, not ARM hardware or a complete
Android battle/HUD/network/touch experience. No requirement to reduce polygon or
texture quality has been established by this proof.

## Reproduce and evidence

New tooling: `model_pair_texture_probe.gd`, `package_model_pair_texture_probe.py`,
`pack_model_pair_probe.gd`, `model_pair_bundle_contract.gd`,
`model_pair_bundle_check.gd`, `model_pair_contract_check.gd` and
`run_android_model_pairs.py`. The existing exporter adds the strictly separate
`android-model-pairs` suite and copies tracked helper code into its temporary
adapter; it restores the slot's project, presets and editor settings.

Successful owned evidence under `.tmp/model-pair-textures/`:
`generate-v5/`, `packages-v2/`, `load-headless-v4/`, `render-v2/`, `apk-v1/` and
`native-v1/`. Earlier attempts and their errors are retained. The tracked
`model_pair_texture_results.json` pins the receipts, sources and pack hashes.
Final packaging in `packages-v3/` omits the obsolete loose-file ZIP experiment;
all six PCKs are byte-identical to the native-tested `packages-v2/` packs.

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_model_texture_sharing_probe.py \
  --mode pair --input .worktrees/slot-c/frontend/.tmp/model-pair-textures/input.json \
  --output .worktrees/slot-c/frontend/.tmp/model-pair-textures/new-generation

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/package_model_pair_texture_probe.py \
  --input .worktrees/slot-c/frontend/.tmp/model-pair-textures/new-generation/report.json \
  --output .worktrees/slot-c/frontend/.tmp/model-pair-textures/new-packages

ops/worktrees/slot-env slot-c -- godot --headless --path .worktrees/slot-c/frontend \
  --script res://tests/model_pair_bundle_check.gd -- /absolute/new-packages/fixture.json /absolute/new-load-report

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_model_texture_sharing_probe.py \
  --mode render --input .worktrees/slot-c/frontend/.tmp/model-pair-textures/new-packages/render-input.json \
  --output .worktrees/slot-c/frontend/.tmp/model-pair-textures/new-render

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-model-pairs --platform android --architecture x86_64 \
  --android-renderer mobile --emulator-frame-pacing-off --sdk /home/adinho/Android/Sdk \
  --output /absolute/slot-c/frontend/.tmp/new-apk

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_android_model_pairs.py \
  --assets /absolute/new-packages --apk /absolute/new-apk/android-model-pairs.apk \
  --output /absolute/new-native-report
```

The fixed owned AVD must be running on port 5580. The collector rejects other
devices/packages/architectures, uses a fresh run ID to reject stale results,
captures native errors and memory samples, and removes its loopback reverse in
cleanup. Focused negative contract checks reject traversal, duplicate/missing
files, corruption, altered manifests and dependencies outside the namespace.
No full release certification was run.
