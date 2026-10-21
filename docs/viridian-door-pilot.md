# Viridian Pokémon Center door pilot

Only `PokemonCenterSlidingDoor` in Viridian City's gameplay scene opts in.
`sliding_map_door.gd` slides the existing single glass leaf to the right, clipped
inside its opening. It does not fade or move the frame, sidelights or threshold.
No new atlas art, Tiled edits or importer changes are involved.

The source is the current generated Viridian `StructureBottom` and `Doors`
layers, in that order. The panel is the opaque 40 × 44 px rectangle at
(1116, 1416); it crosses columns 34–36 and rows 44–45. The central door tiles
are (35,44) and (35,45). These bounds deliberately exclude the fixed frame.
This pilot uses untransformed, static source tiles; review the bounds and native
render check if the building art changes. The source tiles remain intact.

The 0.18-second animation begins while a local player approaches the front tile
and stays open for local or replicated players at the doorway/front tile. It
closes after a 0.15-second clearance delay. Target prediction is used only for
an actively moving local player, so a stale target cannot keep the door open.
The existing Center access lock must be unlocked. No collision, MapExit,
server authorization, input locks or network messages are changed. Clients
render from their existing player-presence data; this is not a replicated door
state. Other doors retain their current behavior.

## Verification

Run through the assigned `ops/worktrees/slot-env`:

- `tests/viridian_sliding_door_check.gd`: real city geometry and player exit
  detection; simulated approach, entry, interrupted approach, two players,
  disconnect, stale target, locked access and return spawn.
- `tests/viridian_sliding_door_render_check.gd`: real-display rendering after
  world depth normalization; exact closed/restored pixels, intermediate
  opening states, and no changes outside the panel. Review PNGs go to
  `user://viridian-door-review` inside the assigned slot.
- `tests/door_entrance_reachability_check.gd`: existing entrance regression.

The checks isolate services rather than logging in. A live two-client session
and a server-authorized round trip remain manual acceptance checks. In local
`development`, approach the Viridian Pokémon Center, pause in front, walk away,
enter, and return. Check the same with a second player staying in front. A live
session is needed to assess network latency and the transition fade together.
