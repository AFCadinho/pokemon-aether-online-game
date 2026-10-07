# Android texture residency isolation

## Result — 2026-10-07

The extra texture allocation in the previous
[full battle budget](android-battle-budget.md) is reproducible in a controlled
texture-only Android probe. **84 texture cases passed**: all 42 imported forest
textures in each of the two existing candidate packs. Each case uploads its
original encoded bytes and a CPU-decoded RGBA8 control, reads all mip levels
back byte-for-byte, and releases the texture to its accounting baseline.
No script/engine errors occurred in the successful native run.

| Allocation sums for the 42 textures | Native BC/S3TC pack | ETC2/EAC pack | RGBA8 control |
| --- | ---: | ---: | ---: |
| Android emulator, local Vulkan device | **52.008 MiB** | **270.743 MiB** | **224.038 MiB** |
| Host NVIDIA Vulkan device | **52.090 MiB** | 41 compressed formats unsupported | **224.068 MiB** |

These are sums of **per-texture driver allocation deltas**, not a concurrently
resident full battle or total process RAM. The native comparison used one
unchanged Android debug APK, one fixed emulator/GPU mode, fresh processes per
pack, the same dimensions and mip counts, and exact pre-existing PCK hashes.
The host row has slightly different driver alignment. The host ETC2 control
was tested successfully after bypassing the engine's unsupported-format GPU
fallback; it reports unsupported compressed formats rather than pretending
that RGBA allocations are native ETC2.

The emulator allocation difference is **218.735 MiB**. Its ETC2/EAC path retains
an additional expanded image allocation: individual RGB blocks require about
6.00 MiB instead of their 0.67 MiB encoded payload, and RGBA/normal blocks about
6.67 MiB instead of 1.33 MiB. The RGBA control itself is about 5.33 MiB. This
matches gfxstream's emulated compressed mipmaps plus expanded-image memory
requirements, rather than a 271 MiB source-art payload. Source:
[AOSP Vulkan emulator implementation](https://android.googlesource.com/device/generic/vulkan-cereal/+/6e4e9924b0e89ac84e56f781221ada679a12dbc3/stream-servers/vulkan/VkDecoderGlobalState.cpp).

This controlled allocation comparison supports the previous emulation
explanation. The emulator's advertised `textureCompressionETC2=true` therefore
cannot establish native compressed residency. We did not inspect its private
host images or measure an ARM64 phone. BC/S3TC is a **native-format control for
this computer/emulator**, not the proposed Android production format.

## Scope and quality

- Original art sources, both PCKs, Pokémon models and production settings are
  unchanged. No download, installed-storage or phone-memory reduction is being
  published by this measurement.
- Every imported texture remains 1024 × 1024 with 11 levels, including the
  original full mip chain. No resizing, new encoding or mip generation.
- All uploaded encoded bytes and RGBA-control bytes return exactly, including
  every mip level. Byte readback validates transport/storage; it does **not**
  prove equivalent sampled shader pixels or visible effect timing.
- The two packs use different existing lossy encodings. Their decoded colours
  are not pixel-identical. The prior [asset comparison](android-arena-assets.md)
  records those differences; this experiment does not label ETC2 lossless.
- Procedural noise and gradients are excluded from this imported-texture
  experiment. The earlier dependency inventory includes those resources.
- The successful microprobe's sampled guest PSS peaks were 518.2 MiB for BC and
  517.1 MiB for ETC2. These similar values are **not** the GPU allocation sums;
  host graphics allocations and the emulator process are separate. Do not add
  them to render counters or extrapolate a phone's process budget.

Conclusion: do not lower model/texture detail based on the previous ~272 MiB
emulator texture delta. Hardware-compressed texture residency remains a viable
Android strategy; actual phone memory and frame pacing still need measurement.
See [Android texture guidance](https://developer.android.com/games/optimize/textures).

The next locally available optimization investigation is identifying duplicate
model textures and unused dependencies, with exact content checks. Any sharing
or removal should preserve normal/shiny materials, the two-pass shader response
and resource lifecycle. It is not yet a demonstrated saving.

## Probe and safeguards

`android_texture_residency_check.gd` uses a separate **local RenderingDevice**.
Allocations are measured against that device before and after creating one
texture; its counters isolate the test from autoloads and the main window.
`get_memory_usage(MEMORY_TEXTURES)` reports Vulkan allocator accounting:
[Godot RenderingDevice](https://docs.godotengine.org/en/4.6/classes/class_renderingdevice.html).
The probe uses sampling/update/readback usage flags and no 3D shader or arena
geometry, so these results qualify allocation and byte preservation only.

A narrow CPU-only CTEX v1 reader avoids creating an initial main-device GPU
texture. The first host ETC2 attempt through `CompressedTexture2D.get_image()`
failed when the unsupported format was converted by the GPU loader. That run
is retained and not counted as a pass. The replacement reader follows the
[Godot CTEX layout](https://github.com/godotengine/godot/blob/4.6-stable/scene/resources/compressed_texture.cpp),
accepts only these audited 1024-square/full-mip v1 files, and is compared against
Godot's **independent headless loader**. All 84 payloads match format, dimensions,
mips and every image byte. It is diagnostic tooling, not a new runtime loader.

The first native export omitted that helper because ordinary presets exclude
`tools/`. The corrected exporter includes its tracked source as a temporary
adapter under the owned diagnostic scripts directory. The failed native run
is retained. The collector now fails immediately on native script/engine errors,
including failures before its test reporter can run, and preserves the log.

The separate `com.pokeaether.androidarenapilot` debug package and x86_64 APK
are checked before installation. The fixed `PokeAether_Android13` AVD uses port
5580 and software graphics (`llvmpipe`) without a visible window. Packs and CTEX
payloads are hash-pinned from the owned loopback fixture; no production app,
cloud write, cache reset or userdata transfer. GPU-format capabilities are
retained in the output. The existing emulator-only frame-pacing and shader-cache
workaround is applied to this transient export; phone defaults are unchanged.
The emulator was closed after collection.

## Reproduce

Run from the workspace control-plane with an assigned slot:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-textures --platform android --architecture x86_64 \
  --android-renderer mobile --emulator-frame-pacing-off \
  --sdk /home/adinho/Android/Sdk --output /absolute/slot-c/frontend/.tmp/texture-probe/apk

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_android_arena_assets.py \
  --texture-residency --expect-renderer mobile \
  --assets /absolute/slot-c/frontend/.tmp/android-arena-assets-v2 \
  --apk /absolute/slot-c/frontend/.tmp/texture-probe/apk/android-arena-pilot.apk \
  --output /absolute/slot-c/frontend/.tmp/texture-probe/native

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_arena_render_probe.py \
  --texture-residency --renderer mobile \
  --manifest /absolute/slot-c/frontend/.tmp/android-arena-assets-v2/desktop-art/forest.json \
  --output /absolute/slot-c/frontend/.tmp/texture-probe/host
```

Use `--variant` to select one native pack, or change the host candidate path to
`android-etc2-art`. Headless CPU reference check for each candidate:

```sh
ops/worktrees/slot-env slot-c -- godot --headless --path .worktrees/slot-c/frontend \
  --script res://tests/texture_ctex_reader_check.gd -- \
  /absolute/slot-c/frontend/.tmp/android-arena-assets-v2/desktop-art/forest.pck \
  /absolute/slot-c/frontend/.tmp/android-arena-assets-v2/desktop-art/texture-list.json
```

Evidence: `.tmp/android-texture-residency/native-v2/` (both successful 42-case
reports, logs, memory samples and Vulkan capabilities); `host-desktop/` and
`host-etc2-v2/` (successful host controls). `host-etc2/` and `native-v1/` are the
unsuccessful attempts described above. Both candidate PCK SHA-256 values were
rechecked after all probes and remain identical to the original export report.
Focused checks: the two native comparisons, host native/unsupported-format
controls, both 42-file CPU reader reference checks, diagnostic parse/export,
Python compilation, rejection of unsupported renderer/ARM64 emulator workaround
and mutually exclusive suite flags. No release certification or deployment.
