# Town Map location previews

Every Kanto Town Map location has its own illustration in the detail sidebar.
The card switches with map-marker clicks, connected-location buttons, opening
at the player's current location, and localization refreshes.

`TownMapPreviewCatalog` resolves the stable presentation IDs from
`data/region_maps/kanto_layout.json`. It shares 16 exact illustrations with
`SignPortraitCatalog` and supplies 31 new images under
`assets/sprites/sign_previews/`. Buildings do not stand in for cities: Pewter
City and Vermilion City have new city views, and routes have their own images
rather than borrowing a nearby cave or building.

Textures load when a location is selected. Existing sign illustrations reuse
the sign catalog's cache. The new illustrations use imported textures where
available and a raw-image fallback for local use before import. Unknown IDs
return no texture and the card hides instead of retaining an unrelated image.

The framed picture fills the sidebar width and preserves its aspect ratio.
The title, location kind, description, interiors, and connected-route controls
remain available in the scrolling detail panel.

## New artwork

The new artwork was generated with built-in `image_gen.imagegen`, following
the user's choice to create an individual illustration for each missing
location. All generation prompts and any targeted revision prompts are
recorded in `town-map-preview-generation.json`.

The original generated PNGs are retained without rewriting their pixels.
The new texture import settings limit runtime previews to 512 pixels and use
high-quality lossy compression. This keeps the new gallery small in exports
while retaining the original artwork for later reuse by signs.

## Focused check

```sh
ops/worktrees/slot-env SLOT -- godot --headless \
  --path .worktrees/SLOT/frontend --script res://tests/town_map_ui_check.gd
```

Besides the map alignment checks, this checks complete preview coverage,
unique pictures, sharing of existing sign art, lazy loading, picture changes,
current-position preservation, and localization refreshes.
