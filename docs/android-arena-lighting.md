# Android arena lighting investigation

## Result (2026-10-07)

The bright forest from the [asset prototype](android-arena-assets.md) is
reproducible with the **same desktop art pack on Linux Compatibility**. It is
not caused by ETC2 conversion. The desktop Forward+ reference and the Mobile
Vulkan renderer produce very similar colours with the original assets, camera,
noon lighting, all four light energies and shadows intact.

A separate native Android 13 x86_64 debug APK successfully rendered the ETC2
pack with Vulkan/Mobile, with no script or engine errors and no silent GLES
fallback. The successful result was collected from the dedicated emulator with
host graphics (AMD RADV RENOIR), not a physical Android GPU. Ordinary game,
Android build configuration and its production 2D policy have not changed.

## Controlled evidence

The original 960 × 540 arena diagnostic was extended with explicit renderer,
lighting mode, light state, adapter and frame-pacing fields. It uses one fresh
process for each comparison, fixed camera and noon lighting, 4× MSAA and no wind.
The Linux probe temporarily removes game autoloads from **its assigned slot**;
this enabled the formerly stalled host comparison. The original slot project
bytes are restored afterward, and caches are not transferred.

| Comparison against desktop Forward+ | RGB RMSE / 255 | RGB PSNR |
| --- | ---: | ---: |
| Linux Compatibility, original desktop pack | 50.24 | 14.11 dB |
| Linux Mobile, ETC2 candidate | 4.79 | 34.53 dB |
| Native Android Mobile, ETC2 candidate | 4.78 | 34.54 dB |

These measurements cover this screenshot, not all battle environments or an
acceptance threshold. Texture encoding, renderer shading and rasterization can
still produce small differences. No claim of pixel-identical ETC2 encoding.

Compatibility probes with HDR 2D enabled, only the sun enabled, grass specular
disabled and unshaded grass were also run. They did not provide equivalent
shaded terrain with all shadows. Disabling shadows improved grass but retained
incorrect ground response; that option was **not** applied to game lighting.

Godot's GLES shader converts albedo to linear and applies sRGB output conversion
in both its base and additive light passes; shadowed directional lights use the
additive path. This explains the over-bright shadowed foliage relative to the
Forward+/Mobile reference. The explicit linear ground tint is also processed
differently by the Compatibility shader pipeline. Sources:
[`scene.glsl`](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/shaders/scene.glsl),
[`rasterizer_scene_gles3.cpp`](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/rasterizer_scene_gles3.cpp).
The diagnosis combines those engine paths with the controlled render probes;
it is not a claim that one project setting can make both renderers identical.

## Emulator startup fix

The first native Vulkan attempts, with both software and host graphics, failed
before running the arena script with `QueuePresentKHR failed with error: 5`.
This matches Godot [issue 121035](https://github.com/godotengine/godot/issues/121035).
The workaround is exposed only for the separate **x86_64 arena debug export**:
`--emulator-frame-pacing-off` temporarily sets
`display/window/frame_pacing/android/enable_frame_pacing=false` in that APK.

This is not a phone frame-pacing recommendation. Godot's
[ProjectSettings documentation](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-display-window-frame-pacing-android-enable-frame-pacing)
recommends frame pacing for stable Android presentation. Physical qualification
must use the normal setting. The diagnostic explicitly reports the effective
setting and now rejects native errors even if they happened before its script
logger was registered.

The runner uses Android SDK `aapt2` to verify the exact debug package identity
and debuggable flag. The old `aapt` could not parse the Vulkan feature attributes
in the Godot-generated manifest; the identity/reset restriction was retained.

## Native memory and limits

Successful native Mobile run:

- Actual backend: Vulkan 1.3 / Mobile, AMD RADV RENOIR through the emulator.
- 40 art roots loaded; captured real grassfield with four original lights.
- No script/engine errors or unsupported-format conversion warnings.
- Sampled peak process PSS: **551.5 MiB**; RSS: **639.4 MiB**.
- Godot static memory after drawing: **270.5 MiB**.
- Godot reported render memory: **429.1 MiB**; texture memory: **398.0 MiB**.

This does **not** demonstrate a RAM saving. It is a larger observed budget than
the earlier GLES diagnostic. Different graphics backends/drivers and counters
prevent treating these as physical-phone VRAM comparisons. Do not add these
memory metrics together or present emulator frame times as phone benchmarks.
A host Mobile run also fell back from unsupported ETC2 formats to RGBA on the
AMD GPU, so its texture residency is not a mobile compressed-texture budget.

The current finding is a viable renderer for image quality, not production
Android 3D readiness. Next measure the scene/texture budget with Pokémon and
both rendering passes, followed by physical ARM64 image, memory, sustained
frame-rate and effect timing checks. No mesh reduction or texture downscaling
has been introduced.

## Reproduction

Run through the assigned slot environment from the workspace control-plane.
Use absolute paths for the task-owned assets/output.

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_arena_render_probe.py \
  --manifest /absolute/path/to/slot-c/frontend/.tmp/android-arena-assets-v2/desktop-art/forest.json \
  --output /absolute/path/to/slot-c/frontend/.tmp/android-arena-lighting/host-forward \
  --renderer forward_plus

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-arenas --platform android --architecture x86_64 \
  --android-renderer mobile --emulator-frame-pacing-off \
  --sdk /home/adinho/Android/Sdk \
  --output /absolute/path/to/slot-c/frontend/.tmp/android-arena-lighting/apk-mobile-emulator

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_android_arena_assets.py \
  --assets /absolute/path/to/slot-c/frontend/.tmp/android-arena-assets-v2 \
  --apk /absolute/path/to/slot-c/frontend/.tmp/android-arena-lighting/apk-mobile-emulator/android-arena-pilot.apk \
  --output /absolute/path/to/slot-c/frontend/.tmp/android-arena-lighting/native-mobile-emulator \
  --variant android-etc2-art --expect-renderer mobile
```

`run_arena_render_probe.py` also accepts `mobile` and `gl_compatibility`, plus
explicit investigation modes. Its 90-second observer deadline terminates only
its own probe and restores the project, including on interruption.
`run_android_arena_assets.py` compares both packs by default; `--variant`
selects one and `--expect-renderer` fails if startup silently falls back.

Evidence is retained in `.tmp/android-arena-lighting/`: host/native screenshots,
JSON reports, sampler logs, decoded image metrics, unsuccessful Vulkan sampler/collector logs and
separate debug export artifacts. The emulator was closed afterward; no display
size override or production app reset was used.

Focused checks: Python compilation, diagnostic parse/export, native GLES
baseline/HDR/sun probes, host Forward+/Compatibility/Mobile isolation probes,
`outdoor_lighting_check.gd`, and the native Vulkan/Mobile run with the emulator
workaround passed. Failed Vulkan runs with default frame pacing are retained
and not counted as successes. No release certification or deployment.

The subsequent [full battle presentation budget](android-battle-budget.md)
records both arena passes, approved Pokémon, Mega preparation and arena reuse,
and explains the emulator's inflated texture accounting.
