# Gift Store mount preview framing

`scripts/ui/mount_rider_preview.gd` reuses the world renderer for the mount,
seated rider, masks, foreground layers and hover. Preview framing is calculated
locally; it does not change the mount catalog, world scale or rider offsets.

The renderer measures nontransparent pixels of every visible sprite layer over
all four directions, idle poses and animation frames. It includes the full hover
range and ground shadow. That combined envelope is centered and uniformly scaled
to fit the viewport with 16 px horizontal and 12 px vertical padding. The limiting
dimension fills the available space; natural aspect ratios remain intact.

Framing is recalculated when the mount or trainer appearance changes. Turning or
pausing a mount uses the same envelope, so the preview does not zoom or shift as
frames change. The Store passes its viewport size to the renderer. Catalog
`storePreviewScale` and `storePreviewOffset` values are legacy fields and are no
longer used by the Store; new mounts need no per-mount preview adjustment.

Run `tests/store_mount_preview_fit_check.gd` through the slot environment to check
every Store mount with normal/shiny rewards and both trainer models. It checks
padding, centering, consistent viewport occupancy, stable framing and unchanged
catalog/appearance data, and writes a comparison PNG to slot-local userdata.
`tests/donator_store_mount_tabs_check.gd` covers Store controls and purchase UI.
