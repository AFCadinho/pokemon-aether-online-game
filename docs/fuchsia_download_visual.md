# Fuchsia City visual import

The current visual comes from
`/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/towns/Fuchsia City.tmx`
(72 × 50 tiles). Source artwork and TMX files remain unchanged.

Reimport in an assigned slot with the standard visual importer:

```sh
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- '/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/towns/Fuchsia City.tmx' fuchsia_city
```

This source already uses the runtime layer names: Ground, GroundDetail,
Objects, GateObjects, Doors, ObjectsTop and GateObjectsTop. Preserve the gate
layers’ 16-pixel horizontal offsets and explicit depth properties. Its shared
outside, route-flower and fountain tilesets supply tile animations.

The previous Downloads export used Spanish layer names and static scenery.
`tools/import_fuchsia_download_visual.gd` remains available specifically for
that older export; it is unnecessary for the current artist source.

The existing gameplay scene, collision, NPCs, signs, exits, nightlights and house
connections are separate from the generated visual. Preserve the corrected
Door74 leaf bounds (704, 280, 32, 36), which include the full tall-house door.

Validation: source CSV/atlas audit, all seven imported layer cell counts,
compact-atlas validation, actual city scene loading, Godot visual review and
shared door controller checks. Visual import does not certify gameplay
collision or server-authorized travel.
