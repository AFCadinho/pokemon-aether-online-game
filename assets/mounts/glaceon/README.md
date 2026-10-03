# Glaceon mount

Approved v10 follower design, using the original `assets/followers/GLACEON.png`
at 1×. The 224×224 runtime frames provide transparent padding only; neither
Glaceon nor the player's original 64×64 riding pose is resized. All four
directions and phases retain their source pixels. The side seat follows the
source's two-pixel bob. The rider sits four pixels lower than the v10 preview
to meet the back, retaining the same horizontal position and ear contour. The far upper ear remains behind the rider, while the
near head, ear and flap use a matching foreground and rider mask.

Rebuild with `python tools/build_glaceon_mount.py` (Pillow required).
`icon.png` uses the unpadded front cell for the Bag and mount selector.

Grant `glaceon-mount` through the existing administration reward controls,
then select Glaceon in the land mount slot. Ownership and the regional Mount
License are required. Ordinary land movement and collision rules apply.

Focused checks: `tests/glaceon_mount_check.gd` and backend
`account-service/tests/test_glaceon_mount.py`.
