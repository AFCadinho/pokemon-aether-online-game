# Route 2 and Route 4 battle arenas

## Map identity

Trainer battles on `kanto_route_2` and `kanto_route_4` use the authored
`route_2` and `route_4` arenas. Wild land encounters use the generic grassfield;
wild surf, fishing and water-tile encounters use the generic sea. The route
water variants remain available for trainer contexts and visual review. The
existing grass/water backgrounds and platforms continue to represent their
resolved environments in 2D. This changes presentation, not encounters.

The layouts are based on the actual generated pixel-map scenes:

- Route 2: dense evergreen corridors, staggered grassy ledges, sandy paths,
  green-roofed forest gate, blue-roofed cottage, Diglett's Cave, small ponds,
  white fences and flower borders.
- Route 4: Mt. Moon's eastern cave mouth, layered brown rock terraces, mountain
  stairs, grass plots, conifer groves, a long river towards Cerulean and the
  timber footbridge across it.

Each route owns its builder in `scripts/battle/arenas/maps/route_2` or `route_4`.
Land and water variants share that route's composition. The central six-unit
clearing stays flat. Water origins are `(15, 0, -8)` and `(34, 0, -8)`; actors use
the arena surface metadata, with the calibrated floor 0.22 units under water.
Neither species-specific offsets nor camera limits were changed.

Scenery encloses both land and water camera orbits. Large trees stay outside
24 units of both origins; tall landmarks and ledges sit outside the orbit.
Route 4 extends further east to include the distant river crossing and bank.
Terrain and grass use ordinary ArrayMesh/MultiMesh, shared between the two
material passes. The existing single-pair pool owns their lifecycle.

## Assets and shared construction

Trees, grass, shrubs, flowers, ground textures and rocks reuse the installed
Temperate Forest art pack. New small props come from
[Kenney Nature Kit](https://kenney.nl/assets/nature-kit), CC0: a fallen log,
stump, red mushroom group and water lily. Four unmodified GLBs (about 46 KB
combined), their license and source note are bundled in
`assets/models/battle/nature_details`. Placement overrides remove metallic
response and harmonize the colors with the established scenery. No additional
runtime download or new native dependency is required for these props.

`shared/waterside_route.gd` supplies shoreline and detail placement on top of
`wooded_route.gd`. `shared/route_landmarks.gd` contains the original mesh kit
previously at `maps/route_3/landmarks.gd`, plus the cottage, forest gate and bridge.
Route 3 retains its compatibility path and unchanged landmark geometry.

## Focused checks

Run through the assigned slot's `ops/worktrees/slot-env`:

- `tests/routes_2_4_arena_check.gd`: routing, 2D fallbacks and override priorities;
  with `POKEAETHER_FOREST_MANIFEST`, both render passes, pond floors, fighter
  positions, stair landings, landmark presence, repeated pool switches and cleanup.
- `tests/battle_arena_contract_check.gd`: catalog/builders and camera/spawn contract.
- `tests/route_3_arena_check.gd`: regression for the shared landmark kit.
- `tests/routes_1_22_orbit_check.gd -- route_2 route_2_water route_4 route_4_water`:
  full yaw at five-degree intervals, pitch/zoom limits, tree/terrain clearance,
  sightlines to the battle and distant scenery coverage.
- `tests/routes_1_22_orbit_preview.gd -- route_2 route_2_water route_4 route_4_water`:
  paired Dragonite/Roaring Moon renders, eight yaw angles, noon/night and both
  pitch limits at maximum zoom. Set `POKEAETHER_FOREST_MANIFEST`,
  `SUMMARY_MODEL_CATALOG` and `POKEAETHER_STAGE_OUTPUT`.

These are offline checks. Live backend encounters, release certification and
production deployment are outside this presentation task.
