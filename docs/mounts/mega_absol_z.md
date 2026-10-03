# Mega Absol and Mega Absol Z mounts

Both mounts use the approved compact follower-based designs: white wing-like
fur for Mega Absol, navy fur and magenta feathers for Mega Absol Z. The original
Absol follower and the approved four-direction concepts were imagegen references.
`assets/mounts/{mega_absol,mega_absol_z}/source.png` preserves the approved logical
pixels. This replaces the previous taller Mega Absol Z design without changing
its mount ID or unlock item, so existing ownership and loadout selections remain.

`tools/build_absol_mounts.py` exports 512×512 mount, foreground and rider-mask
atlases with 128×128 frames. The older `build_mega_absol_z_mount.py` command remains
a compatibility entry point. Rows are down, left, right, up; columns are four
walking phases at 5 fps. Source pixels retain their exact colors and 2× scale.
The full rig moves upward one logical pixel from the approved seated preview,
aligning paws to the ordinary player ground line. Player frames remain 64×64.

Directional masks put the head in front of the rider when facing south, conceal
the far leg in side views, and place the rear rump ahead of overlapping feet.
Foreground and mask share precisely the same silhouette pixels in every frame.
Near-side legs remain visible. Rider poses remain static while mount and masks
advance together. Both genders use the existing body, clothes, hair and headgear.
The mounts use normal land movement, collision and world depth, without hovering.

Each variant has a dedicated 64×64 icon and item text in en, nl, pt_BR and zh_CN.
The PNG fallback loader also handles assets not yet imported by an open editor.

## Availability

| Mount ID | Permanent unlock item |
| --- | --- |
| `mega_absol` | `mega-absol-mount` |
| `mega_absol_z` | `mega-absol-z-mount` |

The untradeable items can be granted through the existing admin/reward flow.
Each unlocks only its corresponding mount; the player still needs a regional
Mount License. No shop source or automatic account grant is added.

## Verification and preview

`tests/mega_absol_z_mount_check.gd` now covers both variants: ownership, icons,
localization, exact artwork, ground alignment, layer consistency, both player
models and local/remote animation synchronization. The unimported-assets check
also covers both variants. Existing mount-selection, mount-switch, world-depth
and localization checks cover their shared integration paths.

`tools/mega_absol_z_mount_demo.tscn` supports both variants with the actual avatar
renderer. WASD/arrows move and turn, G changes player model, M switches mount,
and Space toggles animation. Run Godot through the assigned slot environment.
