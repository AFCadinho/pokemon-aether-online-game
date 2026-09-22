> Historical comparison: this prototype has now been adopted for automatic Route 22
> battles, and generic grassfield also uses mesh terrain. Current structure and
> review commands are described in [the arena index](../scripts/battle/arenas/README.md).
> Reproduce the original A/B measurements at commit `0bc5fd6e8`.

# Route 22 without Terrain3D: comparison prototype

This is the requested decision prototype, not a replacement of automatic battle
routing yet. Both land and surf/fishing views can be built without registering
or loading Terrain3D. The existing gameplay arena and its session pool remain
available as the comparison baseline.

## Implementation and visual scope

`route_22_mesh_arena.gd` reuses the existing Route 22 landmark/prop placement
methods. The fir/spruce scenes, textured rocks, flowers, three-face grass mesh,
wind shaders, groundA albedo/normal textures, water shader, stairs, fences,
lighting, camera and battle origins are shared with the approved version.
The pond floor is still 0.22 units below its water surface.

The new ground is an ordinary indexed ArrayMesh: 11,616 vertices and 22,800
triangles for a bounded 120 × 95-unit arena. It is assembled once per variant
per process, then shared across the two rendering passes. This prototype builds
the mesh from compact shape instructions; it does not ship a baked mesh file.
The terrain material retains the source ground tint, detail textures and UV
scale. Vertex weights blend the dirt path and pond floor.

Grass uses the original mesh/material in 56 spatial MultiMesh batches with
seeded placements. The two passes share the batch resources. Grass placement
and scale distribution are newly authored; individual blades do not reproduce
the Terrain3D instance map. Paths, the fighter clearing, pond and paving are
excluded. The distant imported terrain beyond the authored arena is omitted.
The retained composition is close in the fixed battle views, not pixel-identical.

`forest_art_pack.gd` mounts the existing art pack and registers its resource IDs
and wind uniforms. It never reads the native extension descriptor or loads the
original forest world/terrain resources. The review asserts that Terrain3D is
absent before and after both passes are built, including all art dependencies.
The existing loader can still supply the Terrain3D baseline in a separate run.

This prototype still uses the existing ~71.3 MB forest.pck on disk. It adds no
copied textures or models, but does not yet prove a smaller exported download.
A release art-only pack and platform exports would be separate packaging work.

## Reproduce

From the game workspace, with the assigned slot and installed licensed pack:

```sh
ops/worktrees/slot-env slot-a -- env \
  POKEAETHER_FOREST_MANIFEST=/home/adinho/Documents/3d_models/forest-runtime/forest.json \
  POKEAETHER_STAGE_OUTPUT=/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-a/.tmp/route-22-arena/mesh-review \
  godot --path .worktrees/slot-a/frontend \
  --log-file /home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-a/.tmp/route-22-arena/mesh-review.log \
  --script res://tests/route_22_mesh_review.gd
```

Append `-- --water` for the pond. Append `-- --terrain` for the current baseline,
or `-- --terrain --water` for its pond. Each comparison must start a new Godot
process. Add `--interactive` to the arguments after `--` to leave the review
window open. The default captures PNGs and JSON measurements, checks cleanup,
then exits. Waterline markers are test geometry, not Pokémon models; their
separate screenshot is captured after the performance measurements.

## Validation and limits

The focused review checks both rendering passes, landmark presence, flat fighter
areas, surface/contact heights, grass exclusions, shared mesh/batch resources,
absence of Terrain3D in the prototype, and viewport teardown. The screenshots
cover land and water from the current battle cameras at 1152 × 648, 4× MSAA,
with identical lighting and the same main/material-response pass arrangement.

Timing starts before loading the pack and stops after eight frames without new
pipeline compilation. Build-pass timings isolate synchronous scene assembly;
first-pass assembly also includes loading the mesh variant's individual assets.
Render-memory measurements are taken after a further one-second settling period.
These are Godot's whole-process render-memory monitor values, not isolated arena
allocations, system RAM, peak memory, download size or measurements of a live
battle. The test uses no server or Pokémon models.

All runs use fresh processes with existing OS/driver/shader caches, on Linux,
Godot 4.6.2 and an RTX 3070 Laptop GPU. Baseline and prototype order alternates
between repetitions. Cold installation, slower hardware, gameplay preparation
and model/shader costs need separate measurements before a rollout.

## Measured results (2026-09-22)

Three fresh-process runs per backend and viewpoint. Values below are medians;
raw samples are in [route-22-mesh-measurements.json](route-22-mesh-measurements.json).

| View/backend | Ready | Synchronous build, both passes | Settled render memory |
| --- | ---: | ---: | ---: |
| terrain-land | 4.877 s | 2.497 s | 557.4 MB |
| mesh-land | 2.175 s | 0.424 s | 279.0 MB |
| terrain-water | 4.765 s | 2.398 s | 557.4 MB |
| mesh-water | 2.132 s | 0.417 s | 279.0 MB |

The prototype's ready time is about 55% lower and reported render memory about
50% lower in this bounded comparison. That gain combines removing Terrain3D,
omitting distant world terrain, and sharing the small mesh/grass resources;
it is not a measurement of the native-library loading cost alone.

An initial mesh run before shader warmup took 3.323 s. It is excluded from the
three-run table but demonstrates why these cached measurements must not be
presented as clean-install guarantees. Both variants passed all twelve review
runs. Visual review confirmed the retained landmarks and style, plus submerged
waterline markers; actual Pokémon placement/animation still needs gameplay
review if this prototype is selected for integration.

Recommendation: this is a viable basis for compact per-route arenas. The next
implementation step would connect the art-only loader to map prefetch and the
battle presenter/session pool, then test real model admission, lighting,
land/water transitions, fallback and release. No gameplay loading contract was
changed as part of this comparison prototype.
