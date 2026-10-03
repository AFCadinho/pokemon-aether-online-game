# Rayquaza land mount

Rayquaza uses the reviewed v2 art from the local mount asset workspace: a 512×512
atlas with four directions and four movement phases. Mount frames are 128×128;
the player and every outfit layer remain at their existing 64×64 resolution.
The creature floats visually but uses the existing land-mount movement rules.

The rendered mount, foreground and rider hover together 16 pixels above their
normal position, with a two-pixel bob over 2.4 seconds, including at rest. A
stationary ground shadow makes the height visible. Movement frames play at four
frames per second. Collision, tile movement, route restrictions and regional
licenses retain their existing rules; hovering leaves no sand footprints.

## Manual availability

Grant one `rayquaza-mount` inventory item through the existing admin item reward
or system-mail workflow. Its reward payload is:

```json
{"type": "item", "itemId": "rayquaza-mount", "quantity": 1}
```

The entitlement is permanent, nonconsumable, nonholdable and untradeable. It has
no direct shop listing, price or quest reward. Players can also obtain it from
the Rayquaza Mount Box (750 Aether Gems in the Aether Gift Store); see the
Shiny Tracker Mounts tab for odds and opening history. Once owned, Rayquaza appears in the land
mount selector. Riding still requires the usual regional Mount License, just
like Cyclizar. Other players receive the selected mount through existing world
presence messages.

## Larger mount masks

MountService validates mask dimensions against the catalog's mount `frameSize`.
The player texture keeps its original dimensions. Since both sprites are
centered, a player pixel maps into a mount-mask cell as:

```
mount_pixel = player_pixel + rider_offset + (mount_size - player_size) / 2
```

Rayquaza therefore adds `(32, 32)` pixels when looking up its 128×128 mask cell.
Pixels outside the mask retain their original appearance. The foreground
extraction already follows the mount's texture dimensions. Cyclizar and Lapras
have no additional center displacement and retain their existing rendering.

## Focused checks

- `tests/rayquaza_mount_check.gd`: larger mask origin and atlas stride, preserved
  player dimensions/alpha, actual male/female body masks, local/remote rendering
  sizes and mount-frame synchronization.
- `tests/mount_management_ui_check.gd`: ownership-gated selection and ride action.
- Existing Cyclizar, Surf rendering, mount performance and avatar lifecycle checks.
- Backend `tests.test_rayquaza_mount`: actual admin reward grant, ownership and
  regional license requirements.
- Pokemon Data public catalog: searchable mount with no invented shop source.

Development integration does not distribute the new assets or item to an
already deployed client/server. Both repositories need their normal release
before the mount is available there.
