# Aether Clash lobby fountain water

Both fountains pour from the visible mouth outlet below the statue's head.
A broad central waterfall and two parabolic side jets land in the basin, with
dense foam, rising droplets and expanding ripples. The 24 frames last 80 ms each
(1.92 s); highlights travel downward at two source pixels per frame. Sixteen
overlay tiles are placed twice, immediately above the statue's ObjectsTop render
plane (`pao_z_index = 2052`) so the water is visible at its actual outlet.
Every segment of the sampled parabolas is rasterized before shading; their
opaque bodies remain continuous while the highlight pixels flow downward.

The artist source is
`/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/aether_clash/Lobby.tmx`.
Its `animation_assets/fountain_water/build.py` rebuilds the TSX, PNG, dedicated
layer and enlarged GIF preview. Original layers, map connections and object
metadata are unchanged. A backup of the original source and Godot resources is
recorded in `source_manifest.json`.

This directory contains the exact exported TSX/PNG and an overlay-only TMX with
the same placements. `tools/lobby_fountain_rollout.gd -- --apply` imports that
authored layer using `TmxVisualImporter`, stages and validates it, and compacts it
into the canonical lobby visual while preserving all existing layers, TileData,
cell transforms and non-fountain timelines. No gameplay scene is modified.
Reapplying verifies the existing result without rewriting resources.

Verification:

- Native Tiled renders with the overlay hidden match the original map exactly.
- Changed pixels at the beginning and midpoint are confined to both fountains;
  the rendered water layer repeats after one complete cycle. Tiled's rasterizer
  retains the previous frame at the exact boundary, so the loop sample is 1921 ms.
- Two source-generator reruns reproduce byte-identical TMX/TSX/PNG/GIF files.
- `lobby_fountain_animation_check.gd` checks a continuous three-pixel stream
  core along all three jets on both fountains in every frame, including tile
  boundaries. It also checks 768 native frame samples, timing,
  placement, mouth origin, downward motion on both fountains and exact original artwork/
  geometry/TileData after excluding only the new overlay.
- `migrated_visuals_check.gd`, `map_animation_rollout_check.gd`,
  `generated_map_atlas_layout_check.gd`, `water_animation_recovery_check.gd`
  and `tmx_animation_check.gd` pass.
- The OpenGL Godot viewer captures show motion on both fountains; successive
  paused captures are identical.

The measured decoded lobby atlas budget increases from 4,773,888 to 7,133,184
bytes. Rendering uses the normal native TileSet animation, without extra runtime
scripts, particles or processing nodes.
