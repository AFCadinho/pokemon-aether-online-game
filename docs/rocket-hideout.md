# Rocket Hideout

Four gameplay scenes in `scenes/overworld/kanto/towns/celadon_city/` use the
artist's `Rocket Hideout B1F.tmx` through `Rocket Hideout B4F.tmx`. The matching
visuals live in `generated/tiled_visuals/rocket_hideout_b{1,2,3,4}f/` and remain
separate from editable collision and transitions. All floors use indoor lighting,
no weather, and the `kanto_rocket_hideout` access group. They are included in the
extended browser module, both world-access catalogs and Celadon City's map entry.

The Game Corner's two stair tiles at (24–25,5) enter B1F at (16,6), facing right.
B1F returns to (23,5) in the Game Corner, facing left. The city's existing Game
Corner doorway stays connected.

## Stairs and separated wings

The current stair art has moved since the Tiled connection metadata was written.
Gameplay triggers use the visible current treads/openings; reciprocal arrivals
sit beside them and outside every trigger footprint.

| Map | Stair trigger tiles | Return landing |
| --- | --- | --- |
| B1F → Game Corner | (13–14,6) | (16,6), right |
| B1F → B2F north | (23–24,5) | (22,5), left |
| B1F → B2F south | (20–21,38) | (19,38), left |
| B2F → B1F north | (32–33,7) | (31,7), left |
| B2F → B1F south | (27–28,19) | (26,19), left |
| B2F → B3F | (24–25,6) | (23,6), left |
| B3F → B2F | (21–22,6) | (20,6), left |
| B3F → B4F | (15–16,23) | (14,23), left |
| B4F → B3F | (17–18,23) | (16,23), left |

B1F's southern workroom remains separate from its upper offices and is reached
through B2F's southern staircase. B4F's western offices are reached by stairs;
its eastern offices and southern workspace are reached by lift. Collision keeps
both separations intact. Furniture, low maze partitions and statue bases are
solid. The overhead wings of the gold statues on B4F remain passable underneath,
preserving the corridor to the executive room.

## Lift

Face the existing metal doors and interact to choose between the other served
floors: **B1F, B2F and B4F**. The English/Dutch menu supports confirmation and
cancellation and releases its interaction lock before travel. It invokes regular
server-authorized `MapExit` transitions, including destination access checks.
Lift exits have no automatic collision trigger, so arriving never reopens the
menu or starts another journey.

| Map | Door interaction tile | Arrival, facing down |
| --- | --- | --- |
| B1F | (30,33), three tiles wide | (30,35) |
| B2F | (31,22), three tiles wide | (31,24) |
| B4F | (27,33), three tiles wide | (27,34) |

The B2F/B3F arrows and stop pads are walkable visuals for this scene-connection
pass. Automatic sliding, story progression, trainers and item rewards are
separate gameplay work.

## Visuals and verification

The visual importer does not currently apply Tiled `tintcolor`. These gameplay
scenes explicitly preserve Ground `#d1edc0` and GroundDetail `#daeaff` through
child-property overrides; preserve those overrides when reimporting the visuals.
Objects retain their original colours.

`tests/rocket_hideout_check.gd` checks all public floor components, separate
wings, reachable stairs/lift controls, safe reciprocal arrivals, floor/wall tints,
statue collision, atlas layout and browser/server registration.
`tests/rocket_hideout_lift_check.gd` exercises the real floor menu, cancellation,
selection and input-lock cleanup. Account-service tests cover all sixteen
transition directions and a denied lift journey to a closed destination.
Canonical Godot resource compositions were visually reviewed; a live player
walkthrough has not been performed.


## Exterior masks

B1F through B4F each use the shared black `FloorVisibilityMask`, drawn at
absolute z-index 4096. Each mask surrounds the full imported visual canvas:
B1F 1184 × 1408, B2F 1184 × 960, B3F 864 × 1120 and B4F 1056 × 1248 pixels.
The fixed floor region does not follow the player or constrain the camera.
Collision, room visibility within each canvas, stairs and lift behavior are
independent of the exterior masks.

All four scenes were rendered in Godot against a contrasting background and
visually reviewed; every outer margin renders fully black. The existing
`tests/floor_visibility_mask_camera_check.gd` passes. No live walkthrough was
performed for this visual-only change.
