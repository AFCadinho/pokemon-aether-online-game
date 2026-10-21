# Kanto door rollout

The shared `MapDoors` controller uses `resources/world/map_doors.json` for
reviewed leaf bounds, source layers, access locks and return markers. This
rollout adds 60 configurations in 20 maps; the four existing Viridian/Pewter
pilot doors remain in place (64 door visuals across 21 maps in total).

House and wooden shop/lab leaves swing inward; glass shop/Center leaves slide;
gym leaves split left/right. The inactive buildings in Saffron, Cinnabar,
Fuchsia and Celadon remain closed until an actual entrance is wired up.
The catalog never creates exits or changes server authorization/collision.
Existing access locks still gate animation; transitions with server-side access
checks continue to own their authorization.

Both ordinary and authorized named-spawn placement in `world.gd` call the
controller's arrival hook. Only configured interior-return markers prime the
matching door; new-game InitialSpawn is excluded. Celadon's department store
returns via the east door, so its west leaf has no arrival marker.

## Audit scope

All 114 gameplay scenes referencing generated Tiled visuals were inventoried.
The exterior candidates and Celadon roof room were visually reviewed. Route 19,
added during integration, was re-inventoried and has no closed door cells. Open
museum/school arches, route gates, cave mouths, stairways, interior exits and
SS Anne passages have no closed leaf to animate. Guild interior doors/elevator
retain their separate state/transition behavior. The guild building's exterior
entrance does use the shared visual controller.

Pallet and Pewter's old per-tile DoorAnimator nodes were retired so they cannot
erase source tiles or compete with the new controller. Existing generated map
resources and artwork are untouched. JSON is explicitly included in every
export preset; no builds or exports were run for this task.

## Map coverage

| Map | New doors | With entrance |
| --- | ---: | ---: |
| kanto_route_10.tscn | 2 | 2 |
| kanto_route_12.tscn | 1 | 1 |
| kanto_route_16_east.tscn | 1 | 1 |
| kanto_route_3.tscn | 1 | 1 |
| kanto_route_5.tscn | 2 | 2 |
| kanto_route_6.tscn | 1 | 1 |
| kanto_route_7.tscn | 1 | 1 |
| kanto_route_8.tscn | 1 | 1 |
| kanto_route_2.tscn | 1 | 1 |
| kanto_route_25.tscn | 1 | 1 |
| celadon_city.tscn | 8 | 7 |
| cerulean_city.tscn | 6 | 6 |
| cinnabar_island.tscn | 5 | 1 |
| fuchsia_city.tscn | 4 | 1 |
| lavender_town.tscn | 6 | 6 |
| pallet_town.tscn | 3 | 3 |
| pewter_city.tscn | 3 | 3 |
| saffron_city.tscn | 5 | 0 |
| vermilion_city.tscn | 7 | 7 |
| celadon_condominiums_roof.tscn | 1 | 1 |

## Geometry and depth

Bounds are native map pixels; they include shaded rows belonging to the leaf,
but exclude the fixed frame. Source layers follow map layer order: some routes
store buildings in Objects rather than StructuresBottom. Door depth clears
its source layers. The Daycare's top six leaf rows live in ObjectsTop, so its
explicit depth is 1441, below the approaching/returning player's feet and above
the building's depth group. Cerulean's Center, gym and two houses have a 16-pixel
art offset relative to the otherwise shared building design.

The gym mask follows the curved lintel and sill; ordinary double doors use the
same opposed-leaf renderer with a rectangular opening. New door pixels are
projected from the map textures at runtime, without new PNG assets.

## Verification

- `world_door_rollout_check.gd`: every entry's sources, lock/exit/return marker,
  unavailable-building behavior, approach sound, remote-player holding and
  silent/idempotent arrival.
- `world_door_rollout_render_check.gd`: native closed/half/open images for every
  entry, exact closed artwork, unchanged frame pixels and fully cleared opening.
  Captures are written to slot-local `user://world-door-review`.
- Existing pilot, transition-fade, door-reachability and guild door-sync checks
  are run as regression checks.

Run checks through slot-env; the render check needs a real display. These are
focused checks, not full development certification. Live server round trips,
two real clients and live browser playback still need manual playtesting.


## Pallet exit geometry regression

`door_entrance_reachability_check.gd` pins Rival's House's trigger center to
(1136, 384) and Oak's Lab's to (1296, 800), both 32×32. Their visible door/step
points remain (1136, 400) and (1296, 816). The tests check the real player's
detection rectangle during approach, the former early-overlap regression,
actual Godot body-overlap entry dispatch, completed-step detection inside the
interiors, and each interior's matching return marker. At the two exterior
thresholds the feet lie on the trigger's excluded bottom edge; the player body
still overlaps it. These are local geometry/dispatch tests; backend loading
is stubbed.
`tools/audit_pallet_door_geometry.gd` reports actual global centers for all
three Pallet building entrances without confusing parent and child offsets.
