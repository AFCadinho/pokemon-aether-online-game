# Mega Absol Z mount

The approved v2 design uses a lean dark blue body, an angular blue horn, long
chest fur and swept magenta feathers. The artwork was generated with imagegen
from the user's second character reference, then approved by the user.
`assets/mounts/mega_absol_z/source.png` preserves the approved logical pixels.

`tools/build_mega_absol_z_mount.py` exports 640×640 mount, foreground and rider
mask atlases with 160×160 frames. Rows are down, left, right, up, and the four
columns form a walking loop at 5 fps. Player frames remain 64×64. All creature
pixels retain their approved colors and exact 2× scale.

The padded frame aligns the paws with Cyclizar's ordinary world foot line.
Compared with the original design preview, the complete mount/rider rig is
translated upward 26 physical pixels; relative seating and creature size do
not change. Front/rear foreground hides the appropriate lower rider pixels;
side masks hide the far leg. Keep masks, foreground and offsets together.
This grounded mount uses ordinary land movement, collision and world depth.

The dedicated 64×64 icon tightly frames the front-facing creature. Names and
descriptions are included for en, nl, pt_BR and zh_CN.

## Availability

Mount ID: `mega_absol_z`. Permanent, untradeable unlock item:
`mega-absol-z-mount`. The catalog supports existing admin/system-mail grants:

```json
{"type":"item","itemId":"mega-absol-z-mount","quantity":1}
```

The player must own the item and have the current region's Mount License.
This addition does not grant items to accounts or add a shop/quest source.

## Validation and preview

`tests/mega_absol_z_mount_check.gd` checks source-pixel preservation, foot
alignment, ownership, icon loading, masks and local/remote avatars of both
genders across all directions and frames. Existing mount-switch, world-depth,
mount-manager and item-localization checks cover the integration. Backend
tests exercise granting the real catalog item and ownership/license denial.

`tools/mega_absol_z_mount_demo.tscn` is an offline scene using the actual avatar
renderer. WASD/arrows move and turn, G changes gender, Space toggles animation.
Run Godot through the assigned slot's `ops/worktrees/slot-env` as usual.
