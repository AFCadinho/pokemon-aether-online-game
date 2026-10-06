# Single-battle camera

Single battles in full 3D start from a three-quarter view, rotated 35 degrees
from each arena's former home toward the player's side. This follows the user's
stadium reference. Camera height, target, distance and field of view are retained.

The home is calculated around the arena's own target, including translated water
arenas. Fresh and pooled arena initialization use the same home as ongoing camera
updates. Manual orbit, pitch and zoom remain relative offsets; reset returns to
the new home. Optional idle drift still operates around this framing. Doubles and
co-op retain their existing home/focus behavior. The 2.5D camera stays orthographic.

Validation:

- `singles_camera_check.gd`: all 28 arena definitions at 1280×720, 1920×1080 and
  2200×900; room for model/HUD anchors, orbit/reset, camera height/distance, doubles
  and hybrid preservation.
- `hybrid_platform_framing_check.gd`: existing resize, platform and doubles checks.
- `singles_camera_preview.gd -- --moves --smoke-camera`: actual Stadium, Forest,
  Cave and Sea renders with Dragonite/Pikachu, including orbit and reset. Forest
  uses the existing installed art manifest; the harness rejects arena fallback.

Interactive preview: `tests/singles_camera_preview.gd -- --moves` through the
assigned slot. All 194 moves are available under the [approved current
catalog](current-move-approval.md); individual refinements can follow gameplay.
