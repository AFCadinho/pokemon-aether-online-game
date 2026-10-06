# Caterpie and Magikarp

Approved V2 designs, packed at native scale with the existing male/female mount
poses: Caterpie is a land mount and Magikarp is a Surf mount. Four animation
phases and one stable idle frame per direction share the same foreground/mask
layers. Cropped icons avoid shrinking the full padded atlas into inventory.

`caterpie-mount` unlocks `caterpie` through administration/reward tooling and
requires the current region's Mount License. `magikarp-mount` unlocks `magikarp`
in the Surf selector; normal Surf access remains required. Unowned saved Surf
selections fall back to Lapras. Both inventory items are permanent,
non-consumable and nontradeable. These normal variants have no Store listings.

## Approved pose and world alignment

Caterpie keeps the approved V2 rear head extension and lowered rear rider.
Its front/side source artwork is untouched. `follower_original.png` retains the
native source and the builder reproduces the rear pose without resampling.
Magikarp uses its complete original follower sheet. The small size is intended.

Every V2 layer and rider origin moves as one unit during game packing:
- Caterpie: +16 pixels vertically, reaching the same ground foot line as
  Cobalion/Arcanine (world Y +16 with the standard Look Y -16).
- Magikarp: +8 pixels vertically, reaching Lapras's idle waterline (world Y +12).

These adjustments do not change relative rider anatomy, scale, world actor
position, NPC interaction origin or depth sorting. Native animation retains
its small bob. The actor remains the existing world-depth anchor.

Magikarp fishing uses mount-specific pose offsets and its anatomical foreground,
matching local/remote rider rendering. The nearby fin/head can overlap legs;
the entire fish is not forced in front of the rider.

Rebuild or verify: `python3 tools/build_caterpie_magikarp_mounts.py [--check]`.
This checks the reviewed catalog offsets instead of silently changing them.
Render actual runtime layers using `tools/preview_meme_mounts.gd` with
`-- --output=/absolute/path` (optionally `--adinho`). The preview restores a
fixed 3× display zoom after Store auto-fit and shows the normal world tile.

Focused checks cover asset/mask parity, grounded/waterline placement, item
ownership, Surf switching/fishing, local/remote consistency, mount UI,
nameplates, map depth and existing land-mount rider switching.
