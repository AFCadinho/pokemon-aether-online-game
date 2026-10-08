# Android outdoor colour integration

The approved [offline colour experiment](android-outdoor-colour-prototype.md) is
now installed by `OutdoorLighting` in ordinary experimental Android GLES
battles, including both retained environment passes. Desktop and Vulkan
renderers keep their existing materials.

## Scope and lifecycle

- The four imported matte vegetation shaders are matched by exact source
  SHA-256; the two game-owned matte terrain shaders are matched against their
  current source. Unknown programs, custom lighting, water, specular/metallic
  props, next-pass materials and Pokémon are not converted. Future imported
  shader changes need a new review before adding their hash.
- Materials and shaders are duplicated once per arena, preserving the original
  textures, alpha cutouts, wind, AO and mesh data. Multiple instances share the
  arena copy; the main and response passes own separate copies. This also covers
  mesh-wide material overrides and vegetation MultiMeshes.
- The existing shadowed sun and three unshadowed fill lights are required. No
  shadows, textures, geometry, draw passes or raster dimensions are removed.
- The controller updates colour uniforms at most once per game-clock second.
  Identical lighting sends no updates. Reacquiring a suspended pool refreshes
  the lighting from the current clock. Light directions are transformed per
  vertex rather than per pixel; the controlled host capture was pixel-identical. The material overrides remain owned by
  the arena instances until their normal teardown.

The hidden irradiance pass retains scenery geometry, depth, alpha cutouts and
shadow casting, but the reviewed matte scenery is unshaded there: visible
Pokémon pixels sample Pokémon irradiance, not the backdrop colour. This avoids
computing the same outdoor colour twice. Both pooled and non-pooled response
worlds mark this pass before their arena enters the tree.

The user additionally reported overly bright Pokémon. For lit StandardMaterial
actors in Android GLES outdoor battles, the presenter applies a local RGB
albedo gain of 0.82 before the authored response adapter runs. Alpha, textures,
emission and material metadata are retained; unlit and custom effect shaders
are untouched. Desktop, Vulkan, Pokédex and source asset files are unchanged.
This is a presentation adjustment, not a mathematical equivalence claim for
all PBR models. The user thinks the comparison looks better but requested an
in-game review before judging the final appearance.

The fix addresses the excessive brightness and dark terrain from separately
encoded shadow lighting. At the time of that colour trial, the Android 960×540 raster limit still
applied. The subsequent [native-quality change](android-native-3d-quality.md)
removes that limit. Grass-card edge aliasing is a separate consideration.

## Focused checks

`compatibility_outdoor_colour_check.gd` checks platform eligibility, shared-art
isolation, unknown material rejection, clock changes, paired passes and cleanup.
`outdoor_lighting_check.gd` checks the existing clock and continuous light cycle.
The arena render probe exercises installation through the actual controller
(`runtime-colour`) and verifies the reviewed 21 material copies / 299 surfaces.

The native full battle diagnostic additionally covers normal/shiny Pokémon,
evening/night lighting, attack and sleep, Mega preparation, a move effect,
Wailord, release and reacquisition of the retained environment. Its GLES mode
requires the exact Compatibility renderer; existing Mobile diagnostic checks
remain available without accepting silent fallback.

The `--outdoor-colour-baseline` export option is restricted to this separate
GLES debug diagnostic. It temporarily disables the candidate only inside the
exported QA APK and restores the source afterward, allowing a controlled
comparison without changing ordinary exports. No shared cache is cleared.

## Evidence

All 15 native phases completed without script/engine errors for the baseline
and three candidates. The final candidate covers both actual arena passes and
all eight required captures, including evening and night. Source PCK remains
`0cd0051c1bf0491aaad75a0dfd8962ae9e7d60036b3920e47b4aff6ed766da1c`.

On the fixed Android 13 x86_64 emulator / AMD host GLES translator, the median
of warm battle-phase median frame times was:

| Case | Frame time | Peak sampled PSS |
| --- | ---: | ---: |
| Unchanged baseline | 17.82 ms | 500.3 MiB |
| Initial correction in both scenery passes | 22.83 ms | 510.5 MiB |
| Vertex-direction optimization and actor gain | 21.35 ms | 526.3 MiB |
| Final candidate, hidden-pass optimization | 18.22 ms | 506.2 MiB |

The final warm aggregate is about 2.2% slower than baseline in this emulator;
individual phases vary, and first normal-battle median was 19.75 vs 17.53 ms.
These are observations, not new or weakened acceptance thresholds. Shader
compilation, device drivers and thermal limits still require real-phone
assessment. No physical-device or 60 FPS guarantee is made.

The final grass and empty-ground crop pixels match the previous candidate
exactly; the hidden-pass optimization preserves the visible terrain colour.

Portable results: `tools/sprite_factory/android_outdoor_colour_runtime_results.json`.
Generated logs, APKs, captures and metrics stay in the assigned slot at
`.tmp/outdoor-colour-runtime/`. No new R2 packs are required. These results do
not authorize publishing a release.

## Full game review app

`tools/export_android_colour_candidate.py` exports the actual login, world and
battle screens into the separate debuggable package
`com.pokeaether.androidcolourcandidate`. It does not install or publish it.
The normal app, its cached models, sessions and preferences are not copied or
changed. The user must log in and select 3D in the private preview; its own
on-demand downloads then follow the ordinary game path. Only its APK updater
is disabled to prevent a production update from replacing this local preview.
Explicit existing published asset and compatible client build IDs are reused;
no candidate assets are published and the server version gate is not weakened.
Temporary project, preset, editor and generated cry-index edits are restored.
