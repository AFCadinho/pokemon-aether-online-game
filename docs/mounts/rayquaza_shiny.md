# Shiny Rayquaza mount

The approved shiny asset is a palette variant of the existing Rayquaza mount.
Nine body colors become black/charcoal and cool gray highlights; red accents,
gold markings and teeth retain their original colors. The 512x512 sprite sheet
has the same sixteen 128x128 frames and exact alpha as normal Rayquaza. Its
rider mask is byte-identical. Player frames remain 64x64.

Mount ID `rayquaza_shiny` uses the existing land mount renderer, foreground
region, rider offsets, four-frame-per-second movement animation and hover
settings. Local and remote riders share the existing seated pose, ground
shadow and collision rules. It has the same speed and access rules as normal
Rayquaza. Owning one variant does not unlock the other.

The permanent, untradeable item `shiny-rayquaza-mount` unlocks this variant.
Administrators can grant it through the existing item reward flow:

```json
{"type":"item","itemId":"shiny-rayquaza-mount","quantity":1}
```

After receiving it, players can select Shiny Rayquaza in the land mount manager.
The usual regional Mount License remains required. The Bag icon uses the shiny
mount sprite. Item names and descriptions cover en, nl, pt_BR and zh_CN.
It can now be obtained by opening a Rayquaza Mount Box, sold for 500 Aether Gems
(€5.00 incl. VAT) in the Aether Gift Store. The Shiny Tracker Mounts tab shows
the current 50–80% shiny chance, owned boxes and recent outcomes. A shiny or
opening another mount box resets the chance. Duplicates are possible.
The entitlement itself has no direct shop or quest listing.

`tests/rayquaza_mount_check.gd` covers both variants, including male/female
riders, local/remote hover, matching masks and silhouettes, and distinct texture
caches. `tests/mount_management_ui_check.gd` checks independent ownership and
selection. Backend tests exercise the actual catalog item through admin rewards,
regional licenses and separate entitlements.

Approved source asset hashes:

- `mount.png`: `39f147fa16ef1071bacb46a38107152c95e3b09c8659168cde1e260c17f96fea`
- `rider_mask.png`: `d3ee2e4df0cffe3f3c55ab586efd18a22e5d55fec7fb71a82ad9c9fa8f1a51a1`
