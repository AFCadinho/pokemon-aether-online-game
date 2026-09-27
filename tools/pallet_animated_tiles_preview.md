# Pallet Town native tile animation preview

Open `res://tools/pallet_animated_tiles_preview.tscn` and press F6.
For an offline preview without game autoloads, from the game workspace:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend --rendering-method gl_compatibility --script res://tools/preview_pallet_animated_tiles.gd
```

- Tab: overview / flower garden / pond.
- Space: animations on/off, changing only an in-memory duplicate of the TileSet.
- Escape: close.

This preview is a separate imported visual; the playable Pallet Town is unchanged.
The native Tiled source is:
`/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/towns/animation_tests/pallet_animated_tiles/Pallet Town - Animated Tiles.tmx`

The source map uses a separate TSX/PNG and preserves every placed tile ID and flip.
Water animates on 148 cells, canopy detail on 1,265 cells, flowers on 38 cells.
The 21 animated tile types use 624 appended frames. Leaves and flowers use 48
frames with short rest periods; the accepted water loop uses 16 frames. Tree
silhouettes, trunks, shadows, water banks and buildings stay fixed. Animation
frames are built from the existing artwork in the artist-side build script.

Reimport with the existing importer and explicit `pallet_animated_tiles_test` ID:

```sh
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- '/home/adinho/Documents/tiled_pokeaether/kanto/artist/exterior/towns/animation_tests/pallet_animated_tiles/Pallet Town - Animated Tiles.tmx' pallet_animated_tiles_test
```

Use this test ID to preserve the existing generated `pallet_town` visual.
No runtime wind shader is used. The imported TileMapLayers play the TSX frame
sequences directly. Static gameplay, collisions and connectivity are unchanged.

Verification (Godot 4.6.2): compact atlas layout passes; 4,376 occupied cells,
1,451 animated cells and all 928 distinct tile/frame images verified after
reload, including individual durations and four flipped map cells. Original
source files are hash-checked in the artist-side animation manifest. The
reviewer has not yet approved this combined visual style for wider rollout.
