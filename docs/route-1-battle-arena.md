# Route 1 battle arena

Route 1 trainer and grass encounters resolve to the map-specific `route_1` 3D
arena. Explicit environment overrides and PvP retain their existing priority.
Surf, fishing and player-on-water encounter contexts resolve to `route_1_water`:
the camera and fighters move into the northern pond of this same environment.
Both variants share the terrain, props and a pond floor 0.18 units below the
water surface. This presentation mapping does not enable overworld encounters.

The visual source is `generated/tiled_visuals/route_1/route_1.visual.tscn`, a
55 × 75-tile north/south forest route. Its recurring features are adapted into
one readable battle composition:

- a grassy combat clearing beside a winding sandy route;
- wooded upper and lower terraces with warm brown rock faces;
- two stair passages and short white fence sections;
- dense fir/spruce borders and tall grass around the open combat space;
- small pink/white flower groups;
- the northern elevated pond, visible beyond the upper ledge.

The arena uses the shared mesh-grassland base and installed forest art pack. Its
terrain shape, paths, prop placement and pond are map-specific under
`scripts/battle/arenas/maps/route_1/`. It does not load Terrain3D, copy model or
texture assets, or cache battle actors. The ordinary terrain mesh and batched
grass can be shared between the main and material-response render passes.

The default battle camera keeps both fighter positions on a flat green clearing.
The route bends along its right edge toward the visible northern stairs, while
the pond and second path branch sit in the background. The wider review image
also exposes the southern terrace and stairs that are outside the normal battle
framing.

The full camera orbit now has layered forest borders and wooded banks. Broad
fir/spruce crowns surround both the central clearing and the northern pond;
their centers stay outside a 24-unit radius around both battle origins. Sandy
paths bend into the forest beyond the terraces instead of running into an empty
horizon. Separate tall-grass plots, short-grass lanes, shrubs, pink flower beds
and more substantial white fences echo the actual pixel map. The ground extends
80 units each way to support the offset pond viewpoint.

Continuous capped terrace meshes replace the old row of isolated boulders.
`shared/wooded_route.gd` supplies normalized art placement and ledge geometry
for Route 1 and Route 22; each route owns its layout, heights and planting.

The sandy path passes through clear openings at both terrace crossings. The
northern staircase rises three units and the southern staircase rises 2.3 units
from the lower terrace. Each six-unit flight has terrain-supported steps and
landings that meet the adjacent plateau; neither staircase ends in mid-air.

Focused validation:

- `tests/route_1_arena_check.gd`: resolver priority, profile, mesh heights,
  landmarks, pond basin, both pooled render passes, actor ground contact,
  cleanup and absence of Terrain3D;
- `tests/route_1_arena_preview.gd`: fixed-camera and overview PNG captures using
  the same catalog builder and lighting as the client;
- `tests/battle_arena_contract_check.gd`: stable arena ID, map scope and builder
  path.
- `tests/routes_1_22_orbit_check.gd`: land/water camera clearance every five
  degrees at the pitch/zoom limits, landmark visibility and surrounding forest.
- `tests/routes_1_22_orbit_preview.gd`: real Dragonite/Roaring Moon paired renders
  for all four Route 1/22 land/water arenas, with eight yaw angles in daytime,
  nighttime and both pitch limits at maximum zoom. Set
  `POKEAETHER_FOREST_MANIFEST`, `SUMMARY_MODEL_CATALOG` and
  `POKEAETHER_STAGE_OUTPUT`; optional user arguments select arena IDs.
  Each eight-image contact sheet runs left to right, top then bottom, from
  0 to 315 degrees. Run through the assigned slot's `slot-env`.

This is an offline presentation review; live backend battles and release
certification are separate checks.
