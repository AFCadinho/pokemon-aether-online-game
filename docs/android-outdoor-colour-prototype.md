# Outdoor colour prototype with retained Android shadows

## Result (2026-10-08)

The [grass investigation](android-grass-quality.md) now has a working offline
Compatibility prototype. It substantially reduces neon grass and dark ground
contrast while retaining the original shadowed directional sun. It passed
native Android 13 x86_64 emulator image checks for noon, night and a side camera
at sunset, plus a controlled caster-shadow comparison. It is **not enabled in
the ordinary game** and is not a physical-phone or battle-performance approval.

The prototype modifies only matte arena surfaces. Pokémon materials, specular
or metallic props, water, textures, meshes, density, camera FOV, light energy,
light direction, shadow-map settings and the 960 × 540 / 4× MSAA budget remain
outside the correction. The standard grey calibration blocks are unmodified;
their remaining Compatibility brightness difference is visible in the images.

The user reviewed the standalone noon/night comparison on 2026-10-08 and
answered **“Ja, duidelijk beter”**. This approves the prototype's appearance;
it does not substitute for full battle or physical-device performance checks.

## Cause and correction

Godot documents that Compatibility renders shadowed light contributions in
sRGB space, which can drastically change their appearance compared with
unshadowed lights. See [the 4.6 light/shadow documentation](https://docs.godotengine.org/en/4.6/tutorials/3d/lights_and_shadows.html#shadow-mapping)
and [the GLES scene shader](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/shaders/scene.glsl).
This explains the observed difference without attributing it to texture size.

For the tested matte Lambert surfaces, the prototype reconstructs ambient and
unshadowed fill lighting. The shadowed sun then contributes the difference
between the correctly encoded total and the already encoded base:

```text
base = ambient + unshadowed fills
sun = sun lighting × actual engine shadow attenuation
sun output contribution = encode(base + sun) − encode(base)
```

The custom light processor feeds that difference through the inverse encoding
before Godot applies its own conversion. This avoids adding two independently
encoded bright contributions. It continues to use the engine's real
`ATTENUATION`, not painted circles or an unshadowed replacement sun. The ground
prototype also removes the explicit tint-to-linear conversion on Compatibility.

Copies are assigned as instance overrides, preserving original packed/shared
materials. Identical source materials and shaders are reused within the probe:
21 copied materials cover 299 surfaces in this forest. The 103 remaining
surfaces are skipped. The diagnostic rejects other renderers, multiple
shadowed lights and layouts without the expected sun/three-fill arrangement.
This is an intentionally narrow prototype, not a general material converter.

## Evidence

- Original published arena PCK SHA-256:
  `0cd0051c1bf0491aaad75a0dfd8962ae9e7d60036b3920e47b4aff6ed766da1c`.
- Separate debug package: `com.pokeaether.androidarenapilot`.
- APK SHA-256:
  `7840c00fcbd949f44b3c6a94aa907aa3b0b912608f5205b023e327e1481a88b9`.
- Actual renderer: OpenGL ES 3.1 / Compatibility, Android Emulator OpenGL ES
  Translator on AMD Renoir host graphics. Frame pacing remains enabled.
- Six native captures passed: original noon/night; corrected noon/night;
  corrected sunset/side camera; corrected noon with only caster shadows off.
- All accepted native cases have zero script/engine errors and the exact PCK
  hash. The existing generated-runner UID fallback warning remains a warning.
- In a fixed bare-ground region, enabling the calibration object's shadow
  lowers mean RGB by 15.97, 20.40 and 9.27 on a 0–255 scale. The sun remains
  shadow-enabled in both captures. This confirms actual receiver darkening.

Image differences against the same-camera Forward+ reference at noon:

| Region (pixels in the 960 × 540 image) | Original native RGB RMSE / 255 | Prototype native RGB RMSE / 255 |
| --- | ---: | ---: |
| Full image | 49.80 | 14.73 |
| Distant grass: `(20,30)`–`(750,170)` | 48.01 | 12.60 |
| Bare ground: `(465,350)`–`(650,480)` | 57.31 | 2.92 |

These are diagnostic measurements, not visual acceptance thresholds or
pixel-equivalence claims. Foliage edges can still alias at this resolution;
uncorrected props and calibration blocks still differ from Forward+.

Evidence stays in slot-c's `.tmp/arena-shadow-colour/`, including a standalone
`index.html` comparison, original captures/reports, shadow-toggle measurements,
APK and full failed-attempt logs. The portable receipt is
[`android_outdoor_colour_probe_results.json`](../tools/sprite_factory/android_outdoor_colour_probe_results.json).

## Failures and limits

An initial fixture parse error and material-teardown errors were repaired;
the host runner now also rejects errors logged after the script's report.
Repeated installation of the identical 225 MB debug APK hit emulator storage
limits. The runner now reuses only an exact installed-APK SHA-256 match after
checking the expected debug package and architecture; a version match is not
enough. Data/files belonging to other apps are not removed.

The headless test emulator exited with code 139 during one PCK download,
before arena construction. That failed attempt is not counted as a rendering
pass. The same side-camera case passed after restarting the dedicated emulator
with a visible window. The ordinary Pixel 6 emulator/game was not restarted or
changed. Only the owned Android 13 diagnostic device was used for these runs.

The study does not establish sustained FPS, thermal behaviour, memory savings,
both production render passes, changing weather, continuous clock/wind updates,
or all map-specific outdoor materials. The extra shader arithmetic could have
a performance cost. Before runtime adoption, add the guarded correction to the
Android arena lifecycle, refresh uniforms with lighting changes, and check
complete battles/effects, pool reuse/teardown and device performance. Preserve
the low-end render budget until measurements justify increasing it.

## Reproduction

Host probe, through the assigned slot:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_arena_render_probe.py \
  --manifest /absolute/slot-c/frontend/.tmp/android-arena-assets-v2/android-etc2-art/forest.json \
  --output /absolute/slot-c/frontend/.tmp/arena-shadow-colour/noon-shadow \
  --renderer gl_compatibility --lighting-mode shadow-colour --shadow-casters
```

Use `--hour 21` for night, `--hour 19 --camera-view side` for sunset/side view,
or `--no-caster-shadows` for the controlled shadow comparison. Forward+
references use `--renderer forward_plus` with the default `baseline` mode.

Export the separate `android-arenas` x86_64 diagnostic as documented in
[the lighting investigation](android-arena-lighting.md). The exporter includes
the offline correction fixture. `run_android_arena_assets.py` accepts the same
hour/camera/caster controls and `--lighting-mode shadow-colour` with
`--expect-renderer gl_compatibility`, restricted to the dedicated Android 13 AVD.
Each native run cleans only its own debug reports and loopback forwarding.
