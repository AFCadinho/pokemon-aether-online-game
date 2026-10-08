# Android grass quality investigation (2026-10-08)

Follow-up: the [matte outdoor colour prototype](android-outdoor-colour-prototype.md)
now demonstrates calmer Android grass/ground with actual shadows retained.
It is an offline diagnostic and is not enabled in the ordinary game.

## Finding

A player screenshot shows soft Pokémon and very high-contrast, speckled grass.
The first player device/GPU and original capture resolution are not confirmed.
A second screenshot, confirmed by the user as their Pixel 6 Android emulator,
shows the same extreme noon grass contrast and distant speckles. Read-only
package/startup checks on the connected emulator report game 0.3.103
(version code 20) and OpenGL ES 3.1 / Compatibility via AMD host graphics. The
960 × 540 Android render cap explains upscaling softness but is not a complete
explanation for the environment appearance.

An isolated host render reproduces the extreme grass/ground contrast using
the exact published Android forest PCK, the production arena builder, the
Compatibility renderer, the normal four lights, fixed noon, no wind, 4× MSAA
and a 960 × 540 viewport. Forward+ renders the same pack, geometry, camera and
resolution with much calmer grass and ground colours. No model or art changes
are needed to reproduce this difference. This corroborates the earlier
[lighting investigation](android-arena-lighting.md).

## Controlled probes

Published PCK SHA-256:
`0cd0051c1bf0491aaad75a0dfd8962ae9e7d60036b3920e47b4aff6ed766da1c`.

| Compatibility probe | Observation | RGB RMSE / 255 against Forward+ |
| --- | --- | ---: |
| Original material and lights | Very bright grass, dark ground and harsh distant speckles | 50.07 |
| Remove ground tint's explicit linear conversion | Ground becomes bright; grass still wrong | 49.97 |
| Same tint probe and disable all directional shadows | Much closer grass/ground tone, calmer distant grass | 6.82 |
| Replace grass cutoff with derivative-smoothed blended alpha | Some near edges softer; bright grass remains and distant terrain develops transparency artifacts | Not an accepted fix |

These are image diagnostics, not acceptance thresholds or performance results.
The combined tint/shadow probe loses real directional shadows. It is deliberately
**not applied to the game**. The alpha blending probe is also rejected. In
temporary probes, vertex lighting and the grass `shadows_disabled` render mode
did not resolve the image. Increasing resolution alone cannot correct this
lighting difference.

The engine's [GLES scene shader](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/shaders/scene.glsl)
converts and adds shadowed directional-light passes separately. The source
grass uses a hard alpha cutoff, whereas the ground explicitly converts its
tint to linear. The observations and these engine paths implicate Compatibility
lighting/colour handling plus cutout aliasing. They do not establish one exact
driver fault on the player's unidentified Android device.

## Scope and next work

No production shader, arena lighting, resolution, downloaded asset or client
setting changes in this investigation. The diagnostic runs have zero script or
engine errors. Host Compatibility used AMD Renoir; Forward+ used an RTX 3070.
Both convert unsupported ETC2 texture formats to RGBA on the host. These runs
cannot qualify physical phone performance or prove the player's exact image.

The corrective work should compare a Compatibility-specific outdoor lighting
path that keeps useful shadows against Vulkan/Mobile on supported devices.
Then check noon/night, close/distant grass, camera movement, Pokémon shadows
and effects on Android. Preserve the current low-end resolution budget until
image and device measurements justify changing it. A blanket resolution
increase or disabling every shadow is not an adequate default correction.

## Reproduction

Run in the assigned slot with its own existing art pack. Do not copy caches,
userdata, assets or evidence between worktrees. Each probe restores the slot's
project configuration on completion.

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_arena_render_probe.py \
  --manifest /absolute/slot-c/frontend/.tmp/android-arena-assets-v2/android-etc2-art/forest.json \
  --output /absolute/slot-c/frontend/.tmp/grass-quality/baseline-gl \
  --renderer gl_compatibility
```

Repeat with `--renderer forward_plus` for the reference. The additional
Compatibility-only modes `--lighting-mode ground-srgb` and
`--lighting-mode ground-srgb-no-shadows` isolate the colour/shadow path.
`--lighting-mode smooth-grass` isolates cutoff smoothing via transparency.
All overrides exist only in the isolated test, not the production arena.

Evidence remains in slot-c's `.tmp/grass-quality/`: baseline and candidate
captures, per-process logs and reports, and `metrics.json`. The original
player screenshot is not committed. No publication or device reset took place.
