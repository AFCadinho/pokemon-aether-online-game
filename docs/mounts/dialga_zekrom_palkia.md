# Dialga, Zekrom and Palkia

| Land mount | Permanent grant item |
| --- | --- |
| Dialga | `dialga-mount` |
| Zekrom | `zekrom-mount` |
| Shiny Zekrom | `shiny-zekrom-mount` |
| Palkia | `palkia-mount` |

These mounts can be granted through existing administration/reward
tooling. Ownership unlocks the corresponding Land selector entry; the current
region's Mount License remains required. Dialga and Palkia remain grant-only.
Zekrom has a Land Gift Store box for 750 Aether Gems or eligible Gift Voucher
credits. It grants a normal or shiny Zekrom using the shared 50/60/70/80 pity
rules; the short description shows the mount and 50% base chance.
Suicune is deferred.

Artwork builds on the approved Dialga V4 and Zekrom/Palkia V3 previews:
native source scale, 192x192 padded cells, four walking phases, and a
single idle frame per direction. Both player models use the existing ride pose.
Source sheets and reproducible design specifications are checked in.

Dialga's front head is lowered 24 source pixels with its full crest/horns
preserved. Its relocated head alpha is explicitly included in the foreground;
the side head remains complete and now sits 12 source pixels farther forward
to keep the long crest clear of the rider’s face. Palkia's side rider sits above
the shoulder
armor, with the rear tail in front only below the torso. Zekrom keeps the rider
between the wings and uses six pixels of visual hover. Dialga and Palkia do not
hover. Their complete mount/rider artwork is 16 pixels lower than the first
integration, matching the normal walking/Cobalion/Glaceon ground line. The
`groundOffsetY` design value shifts mount, foreground, mask and seat together.
World/depth anchors and actor collision positions remain unchanged.

Validate with `python tools/build_land_mount_collection.py --check`.
Run `land_mount_collection_check.gd`, `mount_management_ui_check.gd`,
`mount_world_depth_check.gd` and `mount_switch_rider_check.gd` through slot-env.
Account-service `tests.test_land_mount_collection` covers actual catalog grants,
ownership checks and regional-license enforcement for all three new items.

Render the actual game rig with `tools/preview_land_mount_collection.gd` and
`-- --mounts=dialga,zekrom,palkia --output=/absolute/output/folder`.

Shiny Zekrom uses the matching shiny follower palette (green-tinted dark body
and green highlights), with identical source alpha, rider offsets and masks.
Render it with `--mounts=zekrom --shiny`.
