# Android native 3D battle quality

Experimental Android 3D now keeps the physical pixel dimensions calculated by
the battle presenter, including the window/UI transform. The former 960×540
maximum is removed. A wide 2400×1080 phone previously rendered 960×432 before
upscaling; it now renders 2400×1080. Smaller screens stay at their own size.
The two-pass Pokémon response still uses the same resolution as the main pass,
with existing MSAA 4x, textures, geometry, lighting and effects retained.

Outdoor environment preparation on Android uses `Window.size`, not the
logical UI-design visible rect. This prepares both retained arena passes at
physical window resolution before the battle. The presenter still follows
its actual physical battlefield bounds if the screen/layout changes.

The platform opt-in remains unchanged: Android 3D is experimental and browser
remains 2D. No asset package, source model or R2 publication changes are needed.
Debug Android builds print `ANDROID_3D_RENDER_SIZE` only when the actual main
raster changes, for safe verification in a normal game battle.

## Checks

- `android_3d_platform_check.gd`: native landscape/portrait/small dimensions,
  valid minimum texture size, unchanged opt-in and pool release behavior.
- `battle_3d_raster_size_check.gd`: actual presenter/window and parent transforms
  across 720p, 1080p and 1440p output, with logical UI size retained.
- Full native GLES diagnostic: 15 phases each at 960×432 and 2400×1080 on AMD,
  plus 2400×1080 on NVIDIA. Both arena passes, normal/shiny, evening/night,
  attack/sleep, Mega, move effect, large Pokémon, release/reuse completed with
  zero engine/script errors and all eight expected captures.
- The observer verifies the exact requested main and response raster, not just
  a successful exit or a bigger PNG. Existing default 960×540 benchmark remains
  available; custom sizes are restricted to the bounded debug GLES diagnostic.

## Measured cost

One fixed Android 13 x86_64 AVD, Godot 4.6.2 GLES Compatibility, same pinned
forest PCK and installed model cache. No competing game was running. The
NVIDIA run changes host GPU, so it is not a controlled speedup ratio.

| Host GPU / raster | Median of battle-phase median frame times | Peak reported render memory |
| --- | ---: | ---: |
| AMD integrated / 960×432 | 18.28 ms | 430.3 MiB |
| AMD integrated / 2400×1080 | 61.60 ms | 623.4 MiB |
| RTX 3070 / 2400×1080 | 16.66 ms | See portable receipt |

On AMD the large/reused battle phases reached about 91 ms per median frame.
On NVIDIA all battle-phase medians were 16.65–16.69 ms in these short samples.
Native pixels are visibly sharper but use 6.25× the pixels of the old wide
phone raster. The user explicitly prioritizes quality over downscaling. These
results do not certify real-phone RAM, thermal behavior or sustained 60 FPS.
Older Android devices can remain on the existing 2D presentation.

Evidence: `tools/sprite_factory/android_native_quality_results.json`; slot-owned
logs/APK/captures at `.tmp/android-native-quality/`. The full-game ARM64 review
app uses the separate `com.pokeaether.androidcolourcandidate` package, preserving
that preview's own saved login/preferences without touching the normal app.
No production release has been performed. The private full-game build uses
its normal Gradle/native bridge, including safe Android exit reasons. An initial
built-in-template review APK omitted that bridge and logged two Java class
errors on its next launch; that export path was corrected and the APK rebuilt.
This was a test-build packaging problem, not a native-resolution shader failure.
