# Toucannon, Arcanine and Aerodactyl

Three normal land mounts use the approved V2 designs at native source scale,
with the existing riding pose for both player models. Four movement frames and
one idle frame are provided per direction, with cropped inventory icons.

| Mount | Permanent grant item |
| --- | --- |
| Toucannon | `toucannon-mount` |
| Arcanine | `arcanine-mount` |
| Aerodactyl | `aerodactyl-mount` |

The existing administration/reward tooling grants these non-consumable,
nontradeable items. Ownership unlocks the Land selector entry; the regional
Mount License remains required. This addition includes no shiny variants,
boxes or Gift Store products.

Toucannon and Aerodactyl hover eight pixels with a two-pixel visual bob.
Arcanine uses the normal grounded foot line by shifting the entire rig 16 pixels,
including the rider, mount, foreground and mask. Actor/world depth is unchanged.

Aerodactyl retains its original anatomy. The front head mask, farther-back side
seat and near-wing overlap match V2; rearward horns stay behind the rider.
Arcanine's complete rear tail renders in front of the rider throughout the walk.
Toucannon's V2 layers and seats are unchanged from the initial reviewed design.

Each source.png and design.json is checked in. Rebuild/verify with
`python tools/build_land_mount_collection.py [--check]`.
Render using `tools/preview_land_mount_collection.gd` with
`-- --mounts=toucannon,arcanine,aerodactyl --output=/absolute/path`.
Run Godot through the assigned slot's `ops/worktrees/slot-env`.

Relevant checks: land_mount_collection_check, mount_world_depth_check,
mount_nameplate_check, mount_management_ui_check and mount_switch_rider_check.
