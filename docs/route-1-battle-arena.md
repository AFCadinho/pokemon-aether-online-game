# Route 1 battle arena

Route 1 trainer and grass encounters resolve to the map-specific `route_1` 3D
arena. Explicit environment overrides and PvP retain their existing priority.
The current overworld implements grass encounters only, so hypothetical surf or
fishing contexts continue to use the generic water arena.

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

The fixed battle camera keeps both fighter positions on a flat green clearing.
The route bends along its right edge toward the visible northern stairs, while
the pond and second path branch sit in the background. The wider review image
also exposes the southern terrace and stairs that are outside the normal battle
framing.

Focused validation:

- `tests/route_1_arena_check.gd`: resolver priority, profile, mesh heights,
  landmarks, pond basin, both pooled render passes, actor ground contact,
  cleanup and absence of Terrain3D;
- `tests/route_1_arena_preview.gd`: fixed-camera and overview PNG captures using
  the same catalog builder and lighting as the client;
- `tests/battle_arena_contract_check.gd`: stable arena ID, map scope and builder
  path.
