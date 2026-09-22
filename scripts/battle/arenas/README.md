# 3D battle arenas

This directory separates reusable terrain arenas from overworld-map-specific
arenas. `arena_catalog.gd` is the entry point: `DEFINITIONS` records each arena's
scope, terrain, optional map ID and builder path. Stable IDs preserve existing
settings and environment resources.

| Scope | Terrain/map | Stable ID | Builder |
| --- | --- | --- | --- |
| Generic | Grassfield | `forest` | `generic/grassfield_arena.gd` |
| Generic | Cave | `cave` | `generic/cave_arena.gd` |
| Generic | Water / surf / fishing | `sea` | `generic/water_arena.gd` |
| Generic | Stadium / PvP | `stadium` | `generic/stadium_arena.gd` |
| Map-specific | Route 22, land | `route_22` | `maps/route_22/arena.gd` |
| Map-specific | Route 22, water | `route_22_water` | `maps/route_22/arena.gd` with `water_battle` |

`classic` is the presenter's fallback surface, not a separately authored map.
Only Route 22 currently has a map-specific arena. 2D environment resources and
encounter selection live in `resources/battle/environments` and
`battle_environment_resolver.gd`; manual overrides and PvP retain precedence.

## Folders

- `generic/`: reusable terrain builders and their shaders. Grassfield's compact
  `grassfield_layout.gd` stores the approved sampled hills and prop/flower
  placements; it contains no model or texture data.
- `maps/<map>/`: one overworld map's composition, landmarks and local shaders.
  Land/water variants may share a builder and art with different battle origins.
- `shared/`: mesh generation, grass batching, art loading, geometry helpers,
  camera/spawn framing and the session-owned environment pool.

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
fallback behavior. Pure cave, water and stadium builds need no forest pack.

The environment pool retains one arena's main/material-response pair. Switching
arenas retires the idle pair; it cannot evict a borrowed arena. Mesh/grass caches
hold weak references, sharing resources between passes without retaining every
visited map. The shared source art remains reusable. Actor state is never cached.

## Focused checks

- `forest_art_pack_check.gd`: descriptor-free manifest, invalid input, progress,
  cached reuse and absence of the native module.
- `battle_arena_contract_check.gd`: stable IDs, scope classification and paths.
- `route_22_arena_check.gd`: actual presenter/pool leases, both render passes,
  generic/map/water switches, ground contact, camera origin, fallback and cleanup.
- `route_22_mesh_review.gd`: current runtime captures; default Route 22 land,
  `--water` for its pond, `--forest` for generic grassfield, `--interactive` to
  keep the preview open. Run in a slot with the installed art manifest.

Historical Terrain3D comparison results are in `docs/route-22-mesh-review.md`.
The old A/B implementation is available in commit `0bc5fd6e8`; current reviews
exercise the active mesh builders through the catalog.
