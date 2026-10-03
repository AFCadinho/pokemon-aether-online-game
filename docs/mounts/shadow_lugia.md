# Shadow Lugia mount

The approved v5 sprite sheet is extracted from the Shadow Lugia pixel artwork
provided by the user. Its original colors and pixel shapes are preserved with
nearest-neighbor 2× scaling. This is the XD appearance of Shadow Lugia.

`assets/mounts/shadow_lugia/{mount,rider_mask}.png` contain 512×512 atlases with
128×128 frames. Rows are down, left, right, up; columns repeat two wing poses
as A–B–A–B at four frames per second. Player frames remain 64×64.

The down-facing mask exposes the actual upper head contour at logical rows
29–33, including its dark top edge. The silver tail fork, connecting shaft,
and curved strip left of the head remain behind the rider. The foreground
rectangle starts at physical row 68 and draws the lower head in front. Side
masks hide the far leg. Keep these masks and rider offsets together when
editing the asset; a broad head rectangle would expose the tail again.

The existing local and remote hover system moves the mount and rider together
16 pixels above the ground with amplitude 2 and period 2.4 seconds. The ground
shadow, collision positions, regional Mount License checks and land routes use
the existing rules. This mount does not unlock Surf or crossing obstacles.

## Availability

The permanent, untradeable item `shadow-lugia-mount` unlocks mount ID
`shadow_lugia`. It has no shop price or quest source. Administrators can grant
it through the existing item reward flow, for example:

```json
{"type":"item","itemId":"shadow-lugia-mount","quantity":1}
```

This registration does not grant an item to any account. Players who own it
can select Shadow Lugia in the land mount manager and ride with the usual
regional Mount License. Item names and descriptions cover en, nl, pt_BR and
zh_CN; its Bag icon comes from the mount's down-facing sprite.

The focused `tests/shadow_lugia_mount_check.gd` check verifies the wing loop,
precise head/tail mask, male/female riders, and local/remote hover rendering.
Backend checks exercise the actual catalog item through the reward engine and
ownership/license validation.
