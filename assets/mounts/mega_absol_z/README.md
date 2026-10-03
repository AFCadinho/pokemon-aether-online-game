# Mega Absol Z mount

`source.png` contains the four walking phases in down/left/right/up rows.
`idle_source.png` contains one standing pose per direction, in a 64×256 sheet.
The standing side poses retain the frame-zero torso and rider anchors while
planting the paws below the body. Front and rear idle retain walk frame zero.

Run `python3 tools/build_absol_mounts.py` from the frontend root to build both
Absol mounts. Walking output is 512×512; idle output is 128×512. Both use
128×128 frames and exact nearest-neighbor 2× scaling.

The optional `idleSpriteSheet`, `idleForegroundSheet` and `idleRiderMaskSheet`
catalog fields select the one-column idle layers. Without these fields,
mounts continue to use walk frame zero when standing. Rider offsets for
standing remain frame zero; walking keeps the four existing offsets.

Focused checks: `mega_absol_z_mount_check.gd`,
`mount_unimported_assets_check.gd`, and `mount_switch_rider_check.gd`.
