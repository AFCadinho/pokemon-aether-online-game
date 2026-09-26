# Route 3 battle arena

Automatic wild and trainer battles on `kanto_route_3` use the `route_3` 3D
arena. Explicit environment choices and PvP keep their existing priority. The
grass background and platform remain the 2D fallback. Route 3 has no mapped
water battle area, so generic water encounters retain the sea arena.

## Pixel-map composition

The visual source is the 100 × 50-tile
`generated/tiled_visuals/route_3/route_3.visual.tscn` map. Its stepped mountain
corridor is compressed into the battle camera's view, with a clear flat area
for the combatants:

- brown layered cliff faces and two six-unit stair flights between terraces;
- a cream and blue Pokémon Center with a stepped red roof and Poké Ball emblem;
- Mt. Moon's dark arched entrance in a rocky bluff behind the center;
- connecting sandy paths, a mountain sign, and short wooden/white fence runs;
- dense conifer groups, separate tall-grass plots, low shrubs, white/blue flowers
  and scattered stones along the path edges.

`arena.gd` owns the terrain and planting. `landmarks.gd` builds original mesh
landmarks from the pixel-map silhouettes. Trees, rocks, shrubs and flowers use
assets already included in the installed forest pack and its preloader. No new
download or native module is required. Both render passes use the same terrain
mesh and batched grass. Cliff faces sit in front of the underlying terrain ramps
and their caps meet the plateaus; stair openings preserve the connecting paths.

## Focused checks and visual review

`tests/route_3_arena_check.gd` verifies resolver priority, both pooled render
passes, landmarks, the flat combat footprint, stair landings, cliff coverage and
cleanup. Set `POKEAETHER_FOREST_MANIFEST` to exercise the actual geometry.

`tests/route_3_arena_preview.gd` captures the fixed battle camera at noon and an
overview. Set `POKEAETHER_STAGE_OUTPUT` to the output directory. Pass
`-- --pokemon` with `SUMMARY_MODEL_CATALOG` pointing to an installed approved
catalog to capture Dragonite/Roaring Moon using the real paired material pipeline
at 12:00 and 23:00. The preview asserts the selected arena and fails on a
preparation timeout. Run all Godot commands through the assigned slot's
`ops/worktrees/slot-env`.

Visual review covers both landmarks in the battle framing and unobstructed
combatants in daytime and nighttime. This offline presentation check does not
exercise a live backend battle or certify a release.
