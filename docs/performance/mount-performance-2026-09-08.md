# Mount movement and resource work — 2026-09-08

## Findings and changes

The local player's render-frame movement clamped elapsed time at each tile and
reset it for the next tile. Surplus frame time was lost. At the configured 65 ms
mount tile duration, this makes sustained speed depend on frame rate. For example,
50 FPS needs four frames per tile (80 ms), whereas 60 FPS needs four frames
(about 66.7 ms). This is a movement pacing defect, not evidence of a GPU FPS drop.

The movement helper now consumes the remaining time on the next allowed tile.
Every completed tile retains step events, exit checks, surface effects and
encounter checks; each next tile still goes through the existing movement checks.
A frame processes at most 100 ms and four completed steps, preventing unbounded
catch-up after a stall. Below 10 FPS, discarded hitch time intentionally reduces
movement speed. Configured movement durations are unchanged.

Rider offset reads no longer deep-copy the mount definition each render frame.
Public definition reads still return isolated dictionaries. Transformed rider
frames have a FIFO limit of 128 entries; eviction releases cache ownership without
invalidating frames still held by sprites. This is an entry limit, not a byte
budget, and active sprites can keep additional resources alive. Cold rider masking
visits the source image's nontransparent bounding rectangle, preserving mask
alignment and partial alpha.

## Focused validation

- `mount_performance_check.gd`: actual movement helper inherited by an isolated
  player fixture; 3-second walks at 30/40/50/60/120/144 FPS for 65/140/220 ms tile
  durations stay within one rounded pixel of the expected distance and emit the
  expected tile counts. Alternating 10/30 ms frames also retain elapsed time.
  Stubbed boundaries verify blocked next steps, exits and input locks stop leftover
  movement; a five-second hitch remains bounded. Resource checks cover cache
  reuse, eviction with live references, definition isolation, mask offset and alpha.
- `cyclizar_mount_check.gd`, `surf_mount_render_check.gd`,
  `surf_activity_presence_check.gd`, `horizontal_stair_elevation_check.gd`,
  `map_character_route_gate_check.gd`, `dialogue_input_lock_check.gd`: passed.
- Existing scene UID fallback warnings appeared during route/dialogue checks;
  Godot resolved the resources by path. No script errors in successful runs.

These are local headless checks, not an end-to-end Windows rendering benchmark or
production load test. Actual FPS gains have not been measured. After integration,
compare the same route in Cerulean on foot and mounted, including first login,
turns, walls, stairs, grass encounters, map exits and dismounting. Watch frame time
as well as FPS; ping alone cannot measure rendering or movement smoothness.
