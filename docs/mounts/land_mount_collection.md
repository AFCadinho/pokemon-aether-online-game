# Giratina Origin, Ho-Oh, Yveltal, Miraidon and Reshiram

These five land mounts have normal and shiny variants. Administrators
can grant the permanent items below through existing inventory reward tooling.
Owning an item unlocks its entry in the Land mount selector; the regional Mount
License remains required. The Gift Store lists their boxes under Mounts → Land.
Giratina Origin and Yveltal cost 1,000 Aether Gems; Ho-Oh, Miraidon and Reshiram
cost 750. Eligible Gift Voucher purchases use the same numeric costs.

Each box gives one normal or shiny mount, using the shared 50% base chance and
existing pity rules. Shiny items prefix the normal item ID with `shiny-`; their
mount IDs append `_shiny`. Shiny source sheets use the project’s follower shiny
colors, with exactly matching alpha. The builder shares each normal design to
retain all seating, head corrections, animation and occlusion masks.

| Mount ID | Grant item |
| --- | --- |
| `giratina_origin` | `giratina-origin-mount` |
| `ho_oh` | `ho-oh-mount` |
| `yveltal` | `yveltal-mount` |
| `miraidon` | `miraidon-mount` |
| `reshiram` | `reshiram-mount` |

Each mount has native-scale art in 192x192 cells, four direction rows and four
walking phases. A separate one-column idle sheet uses phase zero. Foreground and
rider-mask alpha match exactly; per-frame seats follow the source animation.
A ten-pixel hover affects only the visual rig, leaving actor/world depth on the
existing tile. The dedicated icons remove the large transparent atlas padding.

The source sheets come from the project's local Gen 9 follower asset pack;
`assets/mounts/<id>/source.png` preserves those originals. `design.json` records
the reviewed seat positions, anatomical foreground polygons and frame shifts.
Miraidon's compact posture uses anatomical head/neck cutouts rather than moving
a full-width strip, preserving the original limb pixels. Its front seat clears
the crest. Miraidon and Yveltal rear tails render ahead of the rider's lower
body; their head and wings retain their existing depth.

Rebuild with `python tools/build_land_mount_collection.py`, or use `--check`
to compare pixels and catalog offsets without writes (Pillow required).

Focused Godot checks, run through the assigned slot's `slot-env`:

- `tests/land_mount_collection_check.gd`: grants, localization, icons, animation
  layers and idle masks.
- `tests/mount_management_ui_check.gd`: mount selection and ownership.
- `tests/mount_world_depth_check.gd`: world anchor and visual layer ordering.
- `tests/mount_switch_rider_check.gd`: all land-mount transitions, both player
  models, local/remote riders, four directions, idle and every walking frame.

Render the actual game rig with `tools/preview_land_mount_collection.gd` and
`-- --output=/absolute/output/folder` using the compatibility renderer. It
captures each mount in all four directions with both default player models.

Use `--shiny` with the preview script to render the five shiny variants.
