# Viridian City water animation proof

Open `res://tools/viridian_water_preview.tscn` in Godot and use **F6**.
Tab switches between the pond and the entire city; Escape closes the preview.
This is a separate visual preview, not a replacement for the playable city.

For an offline preview without game autoloads, from the game workspace:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend --rendering-method gl_compatibility --script res://tools/preview_viridian_water.gd
```

The editable artist map is:
`/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/towns/animation_tests/viridian_water/Viridian City - Animated Water.tmx`

It uses a separate copy of the original atlas, with 16 frames of 160 ms for
10 logical water tiles (66 map cells). Grass, banks and rocks remain static.
The map layout and logical tile IDs remain the same as the original city.
Only three existing water palette colors are sampled for the moving ripples.
The original TMX, TSX and PNG are hash-checked in the artist-side manifest.

Reimport with the existing importer and explicit **viridian_water_test** ID;
using **viridian_city** would overwrite the live city's generated visuals:

```sh
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- '/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/towns/animation_tests/viridian_water/Viridian City - Animated Water.tmx' viridian_water_test
```

The importer now preserves TMX/TSX animation frame sequences through its atlas
compaction. The native TileSet animation runs without a water shader or per-cell
runtime script. No collisions, warps, server maps or world connections are added
by this visual proof. Existing gameplay data stays in the hand-authored scenes.

Verified with Godot 4.6.2: 9,917 occupied cells, 66 animated cells and all 644
unique tile/frame images match the input pixels after saved-scene reload.
Two live captures differ only inside the pond. Focused regression checks:
`tmx_animation_check.gd`, `tmx_atlas_compactor_check.gd`, and
`tmx_visual_importer_check.gd`.
