# Android full battle presentation budget

## Result — 2026-10-07

The separate Android 13 x86_64 debug pilot rendered the **production 3D battle
presenter** with the ETC2 forest candidate and approved v11 Pokémon resources.
All **13 accounting phases passed**, including normal/shiny, physical attack,
sleep, anticipated Mega X preparation/reveal, creation of a real Flamethrower
effect, Wailord, battle release and re-acquisition of the same arena pool.
The last native run had no script or engine errors and no GLES fallback.

This tests presentation, resource delivery reuse and lifecycle, **not** a full
network battle, login/HUD, Android touch interaction or physical-phone speed.
Production Android/browser remain 2D. No asset, model quality, gameplay renderer
or ordinary export setting was changed or published by this task.

## Controlled setup

- Existing dedicated diagnostic package `com.pokeaether.android3dpilot`, debug
  only; no production app reset and no cache/userdata transfers.
- Fixed `PokeAether_Android13` emulator on port 5580, software graphics without
  a visible emulator window. Native backend: Vulkan / Mobile; adapter reported
  `llvmpipe (LLVM 21.0.0, 256 bits)`.
- Both production arena passes at **960 × 540**, 4× MSAA, all four original
  lights and shadows intact; fixed noon and wind disabled for comparison.
- Same ETC2 candidate PCK from the previous arena work: **50,153,852 bytes**,
  SHA-256 `0cd0051c1bf0491aaad75a0dfd8962ae9e7d60036b3920e47b4aff6ed766da1c`.
- Models matched current reviewed identities and exact runtime hashes. Existing
  diagnostic model cache was reused; **zero completed model downloads** in
  the successful run. Installed diagnostic model collection: **223,861,225
  bytes**, which is a disk inventory, not transferred bytes in this run.
- Both arena worlds are built by the actual environment pool. The presenter
  borrows its main and irradiance passes; applicable actors have synchronized
  response copies. Bulbasaur, Mega Charizard X and Wailord use their authored
  StandardMaterial path; Dragonite and Charizard use material response.
  The test validates authored metadata instead of requiring nonexistent
  response copies for StandardMaterial-only models.

The earlier [emulator frame-pacing workaround](android-arena-lighting.md) is
still restricted to a transient x86_64 debug export. For this budget suite that
flag also disables **shader disk caching in the diagnostic APK**: changing the
AVD from host GPU to software exposed incompatible old shader cache headers.
Nothing is deleted or copied; normal game and physical-phone settings retain
frame pacing and shader caching. This run does not measure warm shader-disk
startup latency or qualify phone frame pacing.

## Accounting

MiB = 1,048,576 bytes. These are Godot counters at the end of each observation
window, not mutually exclusive RAM pools. **Do not add static, render, texture,
PSS and RSS together.** Render includes texture/buffer and other allocations.
Monitors can lag by up to a second; each phase observes at least five seconds
and ten frames before sampling. Source:
[Godot Performance](https://docs.godotengine.org/en/4.6/classes/class_performance.html).

| Phase | Static MiB | Render MiB | Texture MiB | Buffer MiB | Draw calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| Autoloads, no arena | 192.5 | 143.3 | 129.9 | 4.4 | 0 |
| Forest resources, no world | 199.5 | 416.1 | 402.0 | 5.1 | 0 |
| Main arena pass | 225.2 | 461.0 | 433.4 | 12.7 | 146 |
| Both arena passes | 227.6 | 499.6 | 468.7 | 14.3 | 292 |
| Both passes suspended | 227.6 | 499.6 | 468.7 | 14.3 | 0 |
| Bulbasaur / Dragonite | 242.6 | 613.7 | 576.3 | 18.0 | 359 |
| Shiny Bulbasaur / Dragonite | 242.8 | 613.7 | 576.3 | 18.0 | 359 |
| Sleep | 242.8 | 613.7 | 576.3 | 18.0 | 359 |
| Mega Charizard X / Dragonite | 253.3 | 626.1 | 588.1 | 18.7 | 365 |
| After effect | 256.4 | 626.1 | 588.1 | 18.7 | 365 |
| Wailord / Dragonite | 252.2 | 616.6 | 578.8 | 18.5 | 357 |
| Battle released | 239.9 | 531.3 | 494.3 | 17.7 | 1 |
| Same arena reused | 242.1 | 599.9 | 562.4 | 18.1 | 357 |

Sampled native process peak: **PSS 616.3 MiB**, **RSS 706.8 MiB**. The host
emulator process and its graphics allocations are separate from guest-process
PSS. The two-entry model resource cache remained bounded throughout; release
suspended both arena viewports and removed battle actors/response copies.
Re-acquisition used the same pool; the final capture shows the same Wailord and
Dragonite with terrain, lighting and shadows. This is two battle lifecycles,
not a long-session leak/thermal test.

This gives useful relative costs on this configuration: forest resource
loading adds ~272 MiB of **reported texture allocations**, the second arena
pass adds ~38.6 MiB of **render allocations**, and the initial pair/presenter
adds ~114 MiB above the prepared two-pass pool. Those deltas are not predictions
of a phone's actual memory requirement.

## Why emulator texture memory is inflated

A separate dependency traversal inspected all 40 retained art roots, including
scene subresources. It found **48 unique Texture2D resources**:

- 42 imported textures: 41 compressed ETC2/EAC payloads and the original
  lossless ground normal.
- One 1024 × 1024 procedural noise texture.
- Five small gradient textures.
- Readable Image payloads total **53.33 MiB** (the headless backend does not
  return gradient Image data). Dimensions and original mip counts are retained.

The emulator's `cmd gpu vkjson` advertises ETC2 and ASTC, which **does not prove
native compressed residency**. The AOSP gfxstream implementation exposes
emulated compression features, creates decompressed images and includes both
compressed mipmap allocations and expanded images in memory requirements.
See [AOSP Vulkan emulator implementation](https://android.googlesource.com/device/generic/vulkan-cereal/+/6e4e9924b0e89ac84e56f781221ada679a12dbc3/stream-servers/vulkan/VkDecoderGlobalState.cpp).

The observed ~272 MiB texture increase is consistent with that emulation path
and the roughly 53 MiB image payload inventory; it is **an inference from
source plus accounting**, not direct measurement of this emulator's internal
host images. We have not found a 272 MiB forest image payload in the art pack.
Do not reduce source resolution based only on this counter. Native phone GPUs
can sample hardware-compressed textures with lower residency; see
[Android texture guidance](https://developer.android.com/games/optimize/textures).
ETC2 encoding itself remains lossy, as documented in the original asset trial.
This task introduced no additional compression, mesh reduction or downscaling.

## Next work

1. Use the same fixed-resolution presentation workload on a physical Vulkan
   ARM64 phone with default frame pacing and shader caching. Measure native
   memory, sustained frame times, UI/input and visible effect timing. No phone
   is currently available; software-emulator frame times are not substitutes.
2. For further work available locally, compare native vs emulated texture
   formats in a controlled emulator probe before modifying assets. Keep the
   same image references and quantify encoding differences separately.
3. Then evaluate sharing identical model textures/resources and eliminating
   unused dependencies. Such changes need byte/pixel equivalence and both
   normal/shiny lifecycle checks. No proven lossless reduction of runtime model
   memory was made by this budget measurement.

The Flamethrower node was created through production code, but its captured
frame does **not** visibly show the flame. Slow software rendering can skip the
visible portion. Effect timing remains unqualified; the successful test is not
visual approval of every attack effect. Captures were inspected for normal,
shiny, large model and reused arena; no missing arena or 2D fallback appeared.

## Reproduce

From the workspace control-plane, in an assigned slot:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-battle-budget --platform android --architecture x86_64 \
  --android-renderer mobile --emulator-frame-pacing-off \
  --sdk /home/adinho/Android/Sdk --output /absolute/slot-c/frontend/.tmp/budget/apk

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_android_arena_assets.py \
  --battle-budget --variant android-etc2-art --expect-renderer mobile \
  --assets /absolute/slot-c/frontend/.tmp/android-arena-assets-v2 \
  --apk /absolute/slot-c/frontend/.tmp/budget/apk/android-3d-pilot.apk \
  --output /absolute/slot-c/frontend/.tmp/budget/native --timeout 900

ops/worktrees/slot-env slot-c -- godot --headless --path .worktrees/slot-c/frontend \
  --script res://tools/sprite_factory/arena_resource_budget.gd -- \
  /absolute/slot-c/frontend/.tmp/android-arena-assets-v2/android-etc2-art/forest.json \
  /absolute/slot-c/frontend/.tmp/budget/resource-budget.json
```

The runner pins the exact debug package, x86_64 libraries, owned output paths,
AVD identity, ETC2 fixture hash, Mobile renderer and the complete ordered phase
list. Startup errors and missing captures fail the result. It force-stops only
its diagnostic app and removes its loopback reverse in cleanup. It never clears
the model cache or weakens the original 21-case Android model pilot gate.

Evidence: `.tmp/android-battle-budget/native-v4/` (successful summary, memory
samples, logs, details and six captures), `arena-resource-budget.json`, and
`vulkan-capabilities.json`. Earlier failed runs are retained: v1/v2 had an
immediately-read unflushed test manifest; v2 also encountered stale shader
headers after the GPU switch. Explicit close and diagnostic-only cache bypass
fixed those. v3 exposed an incorrect test assumption about response copies on
StandardMaterial models; per-model metadata checks corrected it. None of those
runs count as passes. A host GPU emulator also crashed; the successful software
run does not claim that host GPU issue is fixed. The emulator was closed after
collection. No production access, release certification or deployment.
