# Route 3 battle arena

Automatic wild and trainer battles on `kanto_route_3` use the `route_3` 3D
arena. Explicit environment choices and PvP keep their existing priority. The
grass background and platform remain the 2D fallback. Route 3 has no mapped
water battle area, so generic water encounters retain the sea arena.

The source is the 100 × 50-tile `generated/tiled_visuals/route_3` map: an
east-west road from Pewter City toward Mt. Moon, with trees, rock ridges,
breakable rocks and tall grass. The arena adapts those features into a winding
road beside a flat combat clearing, with raised rocky borders, conifers, short
fence runs and roadside flowers. It uses the installed forest art pack and the
shared mesh terrain, batched grass, lighting and camera. The two render passes
share one terrain mesh; no new art assets or Terrain3D dependency are needed.

Focused check: `tests/route_3_arena_check.gd` verifies selection priority,
both pooled render passes, landmarks, spawn ground height, raised north ridge
and cleanup. Run it in a slot with `POKEAETHER_FOREST_MANIFEST` pointing to the
installed forest manifest to exercise the geometry.
`tests/route_3_arena_preview.gd` captures the battle camera and an overview
when `POKEAETHER_STAGE_OUTPUT` names an output directory.
