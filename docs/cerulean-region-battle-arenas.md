# Cerulean City, Route 24 and Route 25 battle arenas

## Location and appearance

Six environment profiles cover land and water encounters in
`kanto_cerulean_city`, `kanto_route_24` and `kanto_route_25`. Each map owns its
terrain and layout under `scripts/battle/arenas/maps/<map>/arena.gd`. They were
composed from the actual generated pixel-map scenes in
`generated/tiled_visuals/cerulean_city`, `route_24` and `route_25`.

- **Cerulean City:** a riverside park, paved promenades, blue-roofed homes,
  Pokémon Center and golden-roofed Gym, the southern Nugget Bridge approach,
  the cave entrance across the river, and mountain terraces surrounding town.
- **Route 24:** the northern Nugget Bridge landing, the broad golden crossing,
  riverbanks, tall grass plots, mountain stairs, conifer corridors and layered
  brown mountain shelves. The bridge shares its architecture with the city;
  the arena shows the opposite approach. Beyond the southern bridge landing,
  Cerulean's blue-roofed riverfront houses, paved promenade, Pokémon Center and
  Gym remain visible through an opening in the trees. Stairs connect the
  riverfront to the upper city terrace.
- **Route 25:** Bill's green-roofed Sea Cottage below the mountain wall, garden
  pond and fences, winding woodland paths, a sandy southeastern shore and an
  open ocean with offshore rocks. The sea extends to the horizon, independently
  of the small garden pond. Open sea is an intentional part of the panorama.

The scenes are battle-scale interpretations, not exact overworld traversal maps.
Tall scenery stays outside both camera orbits. The land combat areas remain flat
and clear. Water origins are `(-24, 0, -34)`, `(32, 0, 43)` and `(30, 0, 25)`.
Each water floor remains 0.22 units beneath the surface, using the existing actor
surface-height contract. Camera limits, models and combat logic are unchanged.

## Shared assets and lifecycle

`shared/cerulean_region.gd` adds common mountain peaks, dressing and path helpers
to `waterside_route.gd`; every map still defines its own topography and shoreline.
`shared/cerulean_landmarks.gd` extends the original landmark kit with Nugget
Bridge, complete cottage facades, the Gym, park benches and river lamps. These
are authored mesh geometry and materials, requiring no new external downloads.
Existing forest art and the bundled CC0 nature details are reused.

The catalog, profile resources, resolver and framing register the six stable
IDs (`cerulean_city`, `route_24`, `route_25`, each with a `_water` variant).
Wild and trainer encounters use the land layout; wild surf/fishing/water contexts
use the corresponding water layout. Explicit environments, manual arena choices,
and PvP retain precedence. Other maps and interiors retain their existing rules.
Grass/water 2D backgrounds remain the fallback when 3D presentation is unavailable.

Terrain and grass retain the shared weak caches and two-pass environment pool.
No additional native addon, backend dependency or asset-bundle change is needed.

## Focused verification

Run Godot through `ops/worktrees/slot-env SLOT -- ...` in the assigned slot:

- `tests/cerulean_region_arena_check.gd`: resolution, overrides, map isolation,
  profile fallbacks, both render passes, required landmarks, flat fighter
  surfaces, water depths, stair landings and repeated arena-switch cleanup.
  Geometry checks use `POKEAETHER_FOREST_MANIFEST`; otherwise resolution runs.
- `tests/battle_environment_resolver_check.gd` and
  `tests/battle_arena_contract_check.gd`: existing environment and camera contract.
- `tests/routes_1_22_orbit_check.gd -- cerulean_city cerulean_city_water route_24 route_24_water route_25 route_25_water`:
  yaw in five-degree steps, both zoom limits and three pitch values, terrain
  sightlines, tree/landmark clearance and horizon coverage (including open sea).
- `tests/routes_1_22_orbit_preview.gd` with the same arguments: real paired
  Dragonite/Roaring Moon renders in eight directions, day/night and low/high
  camera pitch at maximum zoom. Set `SUMMARY_MODEL_CATALOG`,
  `POKEAETHER_FOREST_MANIFEST` and `POKEAETHER_STAGE_OUTPUT`.

These are offline checks. Live backend battles, full release certification and
production deployment are outside this scenery task.
