# Toucannon, Arcanine and Aerodactyl

Three land mounts use the approved V2 designs at native source scale,
with the existing riding pose for both player models. Four movement frames and
one idle frame are provided per direction, with cropped inventory icons.

| Mount | Permanent grant item |
| --- | --- |
| Toucannon | `toucannon-mount` |
| Arcanine | `arcanine-mount` |
| Aerodactyl | `aerodactyl-mount` |

The existing administration/reward tooling grants these non-consumable,
nontradeable items. Ownership unlocks the Land selector entry; the regional
Mount License remains required. All three mounts also have shiny
variants. Their boxes are in Gift Store → Mounts → Land for 500 Aether Gems each (or 500 eligible Gift Voucher credits).
Each grants the normal or shiny mount using the existing 50/60/70/80 chance and
reset rules.

Toucannon and Aerodactyl hover eight pixels with a two-pixel visual bob.
Arcanine uses the normal grounded foot line by shifting the entire rig 16 pixels,
including the rider, mount, foreground and mask. Actor/world depth is unchanged.

Aerodactyl retains its original anatomy. The front head mask, farther-back side
seat and near-wing overlap match V2; rearward horns stay behind the rider.
Arcanine's complete rear tail renders in front of the rider throughout the walk.
Toucannon's front rider is two native pixels farther right to align the authored
sprite centers. Both front wing roots cover the hands when raised. Other
directions and the original Pokémon artwork are unchanged.

Each source.png and design.json is checked in. Rebuild/verify with
`python tools/build_land_mount_collection.py [--check]`.
Render using `tools/preview_land_mount_collection.gd` with
`-- --mounts=toucannon,arcanine,aerodactyl --output=/absolute/path`.
Run Godot through the assigned slot's `ops/worktrees/slot-env`.

Relevant checks: land_mount_collection_check, mount_world_depth_check,
mount_nameplate_check, mount_management_ui_check and mount_switch_rider_check.

All three shiny variants use the matching native shiny follower palettes,
with exactly the normal silhouette, masks and rider offsets. Their items are
`shiny-arcanine-mount` and `shiny-aerodactyl-mount`; boxes are
`arcanine-mount-box` and `aerodactyl-mount-box`.

Toucannon uses `shiny-toucannon-mount` and `toucannon-mount-box`. Its box
also costs 500 Aether Gems (or 500 eligible Gift Voucher credits). The shiny
shares the corrected front seat and hand overlap with the normal mount.

The raw shiny Toucannon follower places phases 0 and 1 four pixels higher in
every direction. Its checked-in source.png normalizes only those frames down
four pixels, preserving every colored pixel and matching the normal alpha
exactly. follower_shiny_original.png and source_alignment.json retain the
original sheet and the per-frame translations. No scaling or repainting is used.
