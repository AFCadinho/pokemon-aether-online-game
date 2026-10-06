# Giratina Origin, Ho-Oh, Yveltal, Miraidon and Reshiram

These five normal land mounts use the approved V3 asset package. Administrators
can grant the permanent items below through existing inventory reward tooling.
Owning an item unlocks its entry in the Land mount selector; the regional Mount
License remains required. No box, shiny variant or Gift Store listing is added.

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
Miraidon's compact V2 posture is preserved; the other source poses are unchanged.

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
