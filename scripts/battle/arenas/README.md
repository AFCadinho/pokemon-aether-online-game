# 3D battle arenas

This directory separates reusable terrain arenas from overworld-map-specific
arenas. `arena_catalog.gd` is the entry point: `DEFINITIONS` records each arena's
scope, terrain, lighting profile, optional map ID and builder path. Stable IDs
preserve existing settings and environment resources.

| Scope | Terrain/map | Stable ID | Lighting | Builder |
| --- | --- | --- | --- | --- |
| Map-specific | S.S. Anne, all four floors | `ss_anne` | Outdoor | `maps/ss_anne/arena.gd` |
| Generic | Grassfield | `forest` | Outdoor | `generic/grassfield_arena.gd` |
| Generic | Cave | `cave` | Enclosed | `generic/cave_arena.gd` |
| Generic | Water / surf / fishing | `sea` | Outdoor | `generic/water_arena.gd` |
| Generic | Stadium / PvP | `stadium` | Enclosed | `generic/stadium_arena.gd` |
| Map-specific | Route 1, land | `route_1` | Outdoor | `maps/route_1/arena.gd` |
| Map-specific | Route 1, water | `route_1_water` | Outdoor | `maps/route_1/arena.gd` with `water_battle` |
| Map-specific | Route 22, land | `route_22` | Outdoor | `maps/route_22/arena.gd` |
| Map-specific | Route 22, water | `route_22_water` | Outdoor | `maps/route_22/arena.gd` with `water_battle` |
| Map-specific | Route 3, land | `route_3` | Outdoor | `maps/route_3/arena.gd` |
| Map-specific | Route 2, land/water | `route_2`, `route_2_water` | Outdoor | `maps/route_2/arena.gd` |
| Map-specific | Route 4, land/water | `route_4`, `route_4_water` | Outdoor | `maps/route_4/arena.gd` |
| Map-specific | Cerulean City, land/water | `cerulean_city`, `cerulean_city_water` | Outdoor | `maps/cerulean_city/arena.gd` |
| Map-specific | Route 24, land/water | `route_24`, `route_24_water` | Outdoor | `maps/route_24/arena.gd` |
| Map-specific | Route 25, land/water | `route_25`, `route_25_water` | Outdoor | `maps/route_25/arena.gd` |

`classic` is the presenter's fallback surface, not a separately authored map.
The maps above have their own arenas. 2D environment resources and
encounter selection live in `resources/battle/environments` and
`battle_environment_resolver.gd`; manual overrides and PvP retain precedence.

## Folders

- `generic/`: reusable terrain builders and their shaders. Grassfield's compact
  `grassfield_layout.gd` stores the approved sampled hills and prop/flower
  placements; it contains no model or texture data.
- `maps/<map>/`: one overworld map's composition, landmarks and local shaders.
  Land/water variants may share a builder and art with different battle origins.
- `shared/`: mesh generation, grass batching, art loading, geometry helpers,
  camera/spawn framing, outdoor day/night lighting and the session-owned
  environment pool.

`shared/wooded_route.gd` adds normalized tree/flower placement, camera clearance
and capped terrace meshes for Route 1 and Route 22, without sharing map layouts.

The mesh grassland base is shared infrastructure, not the generic grassfield
layout. Route 22 does not inherit another map's layout. Additional map builders
should extend the shared base and supply their own shape, clearing, paths and
props, then register their ID in the catalog and environment resolver.

## Loading and ownership

Grassfield and both Route 22 variants use ordinary ArrayMesh/MultiMesh resources.
No runtime arena loads Terrain3D or the original imported forest world. The
installed forest art manifest needs `schema: 1` and `pack`; an old `extension`
field is accepted but ignored. The licensed art pack is still required.

The existing `prepare_forest`/`forest_ready` API and saved `forest` selection are
compatibility names for the shared art loader. Art requests run sequentially in
the background because the scenes share dependencies. Progress still reaches
the map-loading and battle-preparation UI. Missing art retains the existing
fallback behavior. Pure cave, water, stadium and S.S. Anne builds need no forest pack.

The environment pool retains one arena's main/material-response pair. Switching
arenas retires the idle pair; it cannot evict a borrowed arena. Mesh/grass caches
hold weak references, sharing resources between passes without retaining every
visited map. The shared source art remains reusable. Actor state is never cached.

## Focused checks

- `ss_anne_arena_check.gd`: all four floor/NPC routes, overrides, both scenery passes, ground contact and full camera orbit.
- `ss_anne_arena_preview.gd`: battle and overview captures; set `POKEAETHER_STAGE_OUTPUT` to the output directory.

- `forest_art_pack_check.gd`: descriptor-free manifest, invalid input, progress,
  cached reuse and absence of the native module.
- `battle_arena_contract_check.gd`: stable IDs, scope classification and paths.
- `route_22_arena_check.gd`: actual presenter/pool leases, both render passes,
  generic/map/water switches, ground contact, camera origin, fallback and cleanup.
- `route_22_mesh_review.gd`: current runtime captures; default Route 22 land,
  `--water` for its pond, `--forest` for generic grassfield, `--interactive` to
  keep the preview open. Run in a slot with the installed art manifest.
- `route_1_arena_check.gd` and `route_1_arena_preview.gd`: Route 1 routing,
  landmarks, terrace/pond geometry, pooled rendering and fixed-camera review.
- `route_3_arena_check.gd`: Route 3 routing, ridge and clearing geometry,
  both pooled render passes and cleanup.
- `routes_1_22_orbit_check.gd` and `routes_1_22_orbit_preview.gd`: full camera
  orbit clearance and real Pokémon renders for both routes' land/water variants,
  including day/night and the pitch/zoom limits.

Historical Terrain3D comparison results are in `docs/route-22-mesh-review.md`.
The old A/B implementation is available in commit `0bc5fd6e8`; current reviews
exercise the active mesh builders through the catalog.

Route 2/4 composition, new prop provenance and focused review commands are in
[their arena guide](../../../docs/routes-2-4-battle-arenas.md). Shared shoreline
and small-prop placement live in `shared/waterside_route.gd`; original mesh
landmarks live in `shared/route_landmarks.gd`.

See [Cerulean region arenas](../../../../docs/cerulean-region-battle-arenas.md) for the city, bridge and coastal layouts.
