# Native idle pilot

Arcanine, Shiny Arcanine and Lapras have four authored idle cels. Arcanine's
head, ears, body, paws and rider stay still. Its tail uses the two original
follower drawings from walk columns 0 and 2 in all four directions. Those
columns have equal body height; walking bob and steps are excluded. The same
anatomical selection is applied to its foreground and rider mask. Lapras
bobs one pixel either side of its original resting pose; its lowest two water
contact rows stay fixed. There is no scaling, rotation or interpolation.

Rebuild with `python3 tools/build_mount_idle_pilot.py`; `--check` verifies the
output pixels, original first pose, stationary contact rows and catalog seats.
The original walk sheets and one-column resting sources are not overwritten.

Catalog fields: `idleFrameCount` (1–4; default 1), `idleAnimationSpeed`, relative
`idleFrameDurations`, `idleRiderOffsets` and matching `idleSpriteSheet`,
`idleForegroundSheet`, `idleRiderMaskSheet` atlases. The mount owns the animation
clock. Its rider masks, clothing and foreground follow the same frame locally
and remotely. Nameplates reserve the full envelope and do not bob. Collision,
Look and interaction origins never move. Other mounts retain their old idles.

Fishing keeps its existing static mount pose and separate cast/rod timing.
The Gift Store's Animation Off control still freezes the preview at frame zero.
Run `tests/mount_idle_pilot_check.gd` through `ops/worktrees/slot-env` for the
playback, state-transition, rider-layer and anchor checks.
