# Mega Garchomp mount

The approved V7 design uses 192×192 frames in 768×768 transparent atlases.
Rows are down, left, right, up; columns are four walking phases at 5 fps.
The original V7 mount, foreground, rider mask and seat definition are retained
under `assets/mounts/mega_garchomp/source/`, with SHA-256 provenance.

`tools/build_mega_garchomp_mount.gd` shifts the entire rig upward two physical
pixels to match the normal avatar ground line. The upper body, 2× pixel scale
and relative rider placement are unchanged.
`tools/mega_garchomp_walk_rig.gd` now articulates the existing leg pixels into
clear alternating contact and passing poses. Side views reverse the leading
foot and lift the recovering foot; front/rear views alternate planted and lifted
paws. The farther side leg is shaded slightly darker for depth. Phase zero
retains the original standing pose. Foreground and mask are rebuilt from the
same leg pixels, with the approved head and seat region locked. Player frames
remain 64×64.
The complete front and side heads and the traced rear dorsal fin retain the
approved occlusion. Foreground and mask use the same pixels and synchronize
with the actual local and remote avatar animations, including idle and swaps.

## Availability

Mount ID: `mega_garchomp`. Permanent item: `mega-garchomp-mount`.
The untradeable item can be granted by the existing admin/reward flow.
Ownership and the current region's Mount License are both required.
No shop listing, price or automatic account grant is added.
The Bag and mount selector use the dedicated 64×64 icon.
Item text is provided in en, nl, pt_BR and zh_CN.

## Try-out and verification

Run `tools/mega_garchomp_mount_demo.tscn` through the assigned slot environment
to move the actual avatar renderer with WASD/arrows. G changes player model;
Space toggles animation. This isolated scene requires no account or server.

`tests/mega_garchomp_mount_check.gd` verifies unlocks, icon and localization,
approved upper-body pixels and seat offsets, distinct leg poses, masks, ground
alignment, both player models, and local/remote animation synchronization.
A timed playback check also lets all four frames advance naturally during
repeated movement updates and checks the live foreground and rider masks.
Shared mount switching, world depth,
selection UI and unimported-asset checks cover the new catalog entry.
Backend tests cover granting, ownership, regional licensing and public catalog
availability. These are focused checks, not release certification.
