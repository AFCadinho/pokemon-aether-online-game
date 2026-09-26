# Route 3 battle arena

Trainer battles on `kanto_route_3` use the `route_3` 3D arena. Wild land
encounters use the generic grassfield. The grass background and platform remain
the 2D presentation. Route 3 has no mapped water battle area, so water
encounters use the generic sea arena. Explicit review choices and PvP keep
their existing priority.

## Pixel-map composition

The visual source is the 100 × 50-tile
`generated/tiled_visuals/route_3/route_3.visual.tscn` map. Its stepped mountain
corridor is compressed into the battle camera's view, with a clear flat area
for the combatants:

- brown layered cliff faces and three six-unit stair flights between terraces;
- a cream and blue Pokémon Center with a stepped red roof and Poké Ball emblem;
- Mt. Moon's dark arched entrance in a rocky bluff behind the center;
- connecting sandy paths, a mountain sign, and short wooden/white fence runs;
- dense conifer groups, separate tall-grass plots, low shrubs, white/blue flowers
  and scattered stones along the path edges.

The composition surrounds the full camera orbit. Two additional terraced shelves
on the south, east and west meet the northern foothills. A southern switchback
path and stairs, asymmetric conifer groves, rocky plateaus and distant boulders
replace the former empty rear horizon. The ground extends to 64 units in each
direction; tall trees stay at least 23.5 units from the center to clear the camera
at maximum zoom. The Pokémon Center's barrel roof is capped at both ends.

`arena.gd` owns the terrain and planting. `landmarks.gd` builds original mesh
landmarks from the pixel-map silhouettes. Trees, rocks, shrubs and flowers use
assets already included in the installed forest pack and its preloader. No new
download or native module is required. Both render passes use the same terrain
mesh and batched grass. Cliff faces sit in front of the underlying terrain ramps
and their caps meet the plateaus; stair openings preserve the connecting paths.

## Focused checks and visual review

`tests/route_3_arena_check.gd` verifies resolver priority, both pooled render
passes, landmarks, the flat combat footprint, all three stair landings, cliff
coverage and cleanup. It also checks camera clearance at both pitch and zoom
limits every 15 degrees, and raised terrain around the whole outer backdrop.
Set `POKEAETHER_FOREST_MANIFEST` to exercise the actual geometry.

`tests/route_3_arena_preview.gd` captures the fixed battle camera at noon and an
overview. Set `POKEAETHER_STAGE_OUTPUT` to the output directory. Pass
`-- --pokemon` with `SUMMARY_MODEL_CATALOG` pointing to an installed approved
catalog to capture Dragonite/Roaring Moon using the real paired material pipeline
at 12:00 and 23:00. The preview asserts the selected arena and fails on a
preparation timeout. Run all Godot commands through the assigned slot's
`ops/worktrees/slot-env`.

Add `--orbit` alongside `--pokemon` to capture eight yaw angles at both noon and
night, plus all eight angles at each pitch limit with maximum zoom (32 orbit
images). These use the presenter's actual user-camera offsets and paired render
pipeline, including its material response pass.

Visual review covers all eight directions, the diagonal terrace joins, camera
pitch/zoom limits and daytime/nighttime scenery. This offline presentation check does not
exercise a live backend battle or certify a release.
