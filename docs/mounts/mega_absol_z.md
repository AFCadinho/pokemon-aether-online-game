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

Directional masks preserve the complete base mount underneath its foreground.
Front and rear views protect the rider head/helmet from raised horns and feathers.
In left/right views, the complete authored 64×64 rider frame stays in front of
mount anatomy: body, seated hips, clothing and shoes are all retained. The clear
region follows each phase's rider offset. There is no fixed opening in mount
coordinates that could move away from the hips or cut off the boots.

Both player models retain their original ride sprites. The foreground may cover
the lower rider only in front/rear views. In side views, exposed feathers remain
visible around the complete rider, while overlapping feathers sit behind the
player. Foreground and mask always share the same alpha silhouette.

The seated source pose remains static, while the complete rider moves with
small directional per-frame offsets following the walking cycle. Offsets are
matched in the catalog, foreground/mask export and animation sync, including the
last-to-first transition. The mounts use ordinary land collision and world depth.

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
localization, exact artwork, ground alignment, layer consistency, pixel-for-pixel
retention of both side rider poses (body/top/trousers/shoes in idle and walking), both player
models and local/remote animation synchronization. The unimported-assets check
also covers both variants. Existing mount-selection, mount-switch, world-depth
and localization checks cover their shared integration paths.

`tools/mega_absol_z_mount_demo.tscn` supports both variants with the actual avatar
renderer. WASD/arrows move and turn, G changes player model, M switches mount,
and Space toggles animation. Run Godot through the assigned slot environment.
