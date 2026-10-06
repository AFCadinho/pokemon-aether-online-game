# Metagross and Salamence

These normal and shiny land mounts use the approved V2 artwork at native scale, with the
existing riding pose, four walking phases and one idle phase in each direction.
The inventory icons crop away atlas padding.

| Mount | Permanent grant item |
| --- | --- |
| Metagross | `metagross-mount` |
| Salamence | `salamence-mount` |
| Shiny Metagross | `shiny-metagross-mount` |
| Shiny Salamence | `shiny-salamence-mount` |

Owning an item unlocks the Land selector entry. Regional Mount License rules
still apply. These items can be granted through existing administration/reward
tooling. The Gift Store lists `metagross-mount-box` and `salamence-mount-box`
under Mounts → Land for 750 Aether Gems each, or 750 eligible Gift Voucher
credits. Each grants one normal or shiny mount using the existing 50% base
chance and shared pity rules. Descriptions show only the mount and base chance.

Shiny artwork comes from the matching shiny follower sheets and shares the
normal design, offsets and masks. Metagross is silver/gold; Salamence is green
with red wings.

Black & Gold Metagross is a separate grantable land mount:
`metagross-black-gold-mount` unlocks `metagross_black_gold`. It is not a Gift
Store product, has no box and cannot be obtained from the existing boxes.
The permanent item uses the same ownership and regional-license requirements.
Its approved charcoal/gold palette, source scale, rider positions and masks
are preserved. The builder shares Metagross's design; `palette.json` records
the exact source-color mapping. Render it with `--mounts=metagross_black_gold`
without `--shiny`.

Metagross's side seat is six source pixels higher and four pixels farther back
than the initial concept. Its fixed body shifts keep the rider steady when the
legs change pose. Salamence's near side wing renders ahead of the rider; the far
wing stays behind. Front and rear views preserve the approved initial poses.

Each `assets/mounts/<id>/design.json` records the source-space seats, frame shifts
and foreground polygons. Salamence adds `side_wing` to the ordinary head/near
polygons. The foreground alpha exactly matches the rider mask, including idle.
Hover heights are six pixels for Metagross and eight for Salamence; hover only
moves the visual rig and retains the existing actor/world-depth origin.

Rebuild with `python tools/build_land_mount_collection.py`, or validate with
`--check`. Focused checks: `land_mount_collection_check.gd`,
`mount_management_ui_check.gd`, `mount_world_depth_check.gd`, and
`mount_switch_rider_check.gd`, all through the assigned slot's `slot-env`.

Render both models and all poses with `tools/preview_land_mount_collection.gd`
using the compatibility renderer and arguments
`-- --mounts=metagross,salamence --output=/absolute/output/folder`.
Add `--shiny` to capture the shiny variants.
