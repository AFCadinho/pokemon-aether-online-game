# Route 22 battle arena

Route 22's land encounters and trainer battles (including Gary's first rival
battle) resolve to `route_22` in automatic 3D presentation. Surf, fishing and
standing-on-water wild encounters on this map resolve to `route_22_water`. PvP
and explicit environment/manual arena overrides retain their precedence. The
existing grass/water images remain the respective 2D fallback presentations.

## Visual source and shared art

The source is the actual `kanto_route_22.visual.tscn` tilemap, especially Gary's
position `(1488, 464)` in the overworld scene: a higher meadow, northern rock
terraces with stairs, evergreen rows, the western paved League approach, white
fences, purple/white flowers, and the eastern waterbank. The composition is adapted to the existing
battle camera and clear fighter positions, rather than reproducing the entire
map at overworld scale. This is a single arena for the route's land battles.

The arena subclasses the existing forest builder. It uses the same trusted
mounted Temperate Forest pack, Terrain3D floor, grass, fir/spruce scenes, textured
rocks, flower scenes, wind shaders, and neutral battle lighting/skylight. The
rock tint is warmed for the brown Route 22 cliffs. Stairs, curbs and fences use
the same procedural material helper as the other existing arenas. No new image,
model, or copy of the purchased pack is added to the client repository.
The eastern pond uses the sea arena’s palette and animated crossing ripples,
adapted to its shoreline. In land battles its recessed basin keeps the fighting
area dry. In water battles the pond bottom rises to 0.025 units below the surface;
the camera and fighter origins move to the same eastern pond at `(11, 0, -4.5)`.
Trees and flowers stay outside the water, with both camera corridors kept open.

Terrain height/control changes and scenery transforms are runtime-only. Source
resources are not saved. Authored background objects are hidden; generated
Terrain3D containers remain visible. A six-unit clearing retains the original
forest's battle presentation. Both fighter spawns are flat at `surface_height`. The water variant uses the
shared framing origin for camera movement and actor placement, with the same
relative combat spacing. Terrain and landmarks remain in their original positions.

## Preparation and ownership

`uses_forest_assets()` covers forest and both Route 22 variants, including asynchronous pack
loading and map-entry preparation. The session-owned forest environment pool is
keyed by arena ID and holds only one main/response pair. Switching variants
retires the previous idle pair; an active borrower cannot be displaced. The
presenter never borrows a pair for a different arena. Standalone/replay rendering
builds the same Route 22 geometry in both material passes.

The generic sea arena also puts its unchanged, calibrated sandbank below a
0.025-unit water layer, using translucent shallows and opaque deep water instead
of a dry beach ring. No Pokémon-specific placement offsets are introduced.

The existing desktop forest-pack dependency and Pokémon model admission,
grounding and 2D fallback rules remain in effect. This change does not add models
for Gary's party or certify their presentation. No live/server rival battle or
production deployment is performed by the offline tests.

## Focused review

Run from the workspace with a trusted installed forest manifest:

```sh
ops/worktrees/slot-env slot-a -- env \
  POKEAETHER_FOREST_MANIFEST=/home/adinho/Documents/3d_models/forest-runtime/forest.json \
  POKEAETHER_STAGE_OUTPUT=/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-a/.tmp/route-22-arena \
  godot --path .worktrees/slot-a/frontend --script res://tests/route_22_arena_preview.gd -- --capture
```

Omit `--capture` to leave the arena window open. `--forest` renders the existing
forest as a style reference; use a different output directory for comparison.
Use `--water` for the Route 22 surf/fishing viewpoint, saved as
`route-22-water-battle.png`. The preview uses the client camera and light rig, with no placeholder Pokémon.

Focused checks:

- `tests/battle_environment_resolver_check.gd`: existing environment priorities.
- `tests/battle_arena_contract_check.gd`: arena IDs, camera/spawn contract.
- `tests/forest_map_preparation_check.tscn`: map-entry loading cover/input ownership.
- `tests/route_22_arena_check.gd`: Route 22 resolution, water/PvP/override isolation,
  shared 2D resources; with `POKEAETHER_FOREST_MANIFEST`, also both real terrain
  passes, ground heights, repeated presenter leases, standalone rendering,
  calibration fallback, variant switches, terrain isolation and viewport cleanup;
  water variant ground contact, pond-relative camera motion and both render passes.
- `tests/shallow_water_arena_check.gd`: generic surf/fishing selection, fully
  submerged sandbank, preserved ground calibration, both render passes and cleanup.

GPU screenshots and logs are kept in the task slot's `.tmp/route-22-arena`.
The existing Terrain3D interpolation deprecation and legacy scene UID warnings
are unrelated to this arena. Full development certification and release-platform
packaging are separate from this local feature review.
