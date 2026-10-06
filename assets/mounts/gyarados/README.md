# Gyarados Surf mount — approved V4

Implements the owner-approved gyarados-surf-v4 design, without V5–V9 seating,
head reposing or separate head direction experiments. Native follower source,
192px working cells, anatomical foreground and opaque player mask, idle foam
and synchronized swimming wake. No baked sample rider: normal appearance layers
and the existing mounted player pose are used for local and remote players.

`design.json` records V4 seats, phases, selections and approved raw-pixel hashes.
`python3 tools/build_gyarados_surf_mount.py --check` verifies every approved atlas
and the runtime seats. Inventory icons use cropped dry native art. Interaction,
world collision and Look anchors are unchanged; native resting tail ends two
pixels below Lapras except from behind, where the resting edges coincide.

Admin inventory item: `gyarados-mount` (bound form is supported).
Surf access remains required. No shiny variant, box or Store product yet.
Fishing reuses the existing Surf fishing pose/offsets and anatomical foreground.
