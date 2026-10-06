# Latios and Latias

Normal land mounts using the approved V2 designs at native source scale.
Both player models use the existing ride pose, with four moving frames and
one idle frame per direction. Cropped icons appear in inventory and selection.

`latios-mount` unlocks `latios`; `latias-mount` unlocks `latias`. These permanent,
nontradeable, non-consumable items are grantable through existing administration
and reward tooling. Ownership and the current regional Mount License are still
required. This addition contains no shiny variants or Gift Store products.

Both mounts hover eight pixels with a two-pixel visual bob. The original source
anatomy and all visible pixels remain intact. V2 moves the front rider higher
by eight source pixels for Latios and six for Latias to expose the torso.
Side seats move two pixels higher and farther back; narrower near-wing masks
preserve the torso and seated legs. Rear views match V1. The whole rig retains
the existing actor/world-depth origin and mount-aware nameplate positioning.

Source sheets and design.json are checked in alongside the generated layers.
Rebuild/verify using `python tools/build_land_mount_collection.py [--check]`.
Render with `tools/preview_land_mount_collection.gd` and
`-- --mounts=latios,latias --output=/absolute/path` (add `--adinho` for that outfit).

Focused checks: land_mount_collection_check, mount_world_depth_check,
mount_nameplate_check, mount_management_ui_check and mount_switch_rider_check.
