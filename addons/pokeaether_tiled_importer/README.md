# PokeAether Tiled Visual Importer

Tiled owns visual map layout only. Godot owns gameplay.

The active PokeAether TMX pipeline imports regular finite orthogonal TMX files as generated visual scenes. It does not require PokeAether gameplay schema, map IDs, collision layers, spawns, warps, NPCs, interactables, encounters, or region metadata.

Visual import scope:

- parse TMX through the generic importer parser
- resolve external TSX tilesets and tileset images
- import tile layers as `TileMapLayer` nodes
- preserve tile layer order
- preserve tile layer visibility, opacity, and offsets
- support visual render hints through tile layer properties
- support CSV tile data
- preserve Tiled flip flags through Godot alternative tiles
- automatically compact used tile regions without resizing or quality loss
- ignore object layers and gameplay properties
- write generated files only under `res://generated/tiled_visuals/<visual_id>/`

Generated visual files:

- `<visual_id>.visual.tscn`
- `<visual_id>.visual.tileset.tres`
- `assets/*.texture.res` atlas chunks using portable lossless compression

These files are safe to delete/regenerate. Do not put gameplay nodes in generated visual scenes.
The generated-map texture check runs in CI and release workflows so a future
map import cannot silently add raw multi-MiB texture resources to either the
desktop or browser client.
The additional atlas-layout CI check rejects oversized canvases, unused atlas
sources/tiles, missing cell alternatives and non-lossless compact output. Existing
visuals are immutable hash-baselined migration exceptions; new or edited imports
must pass. Used TMX/TSX animations are explicitly rejected before replacing output
until an animation-aware compaction path exists.

Visual render hints:

- `pao_render_layer=overlay` renders a Tiled tile layer above Y-sorted characters.
- `pao_z_index=<number>` sets an explicit Godot `z_index` for that visual layer.

Use these only for visuals such as tree tops, roof tops, and foreground overlays. Gameplay still belongs in Godot.

Gameplay stays in hand-authored Godot scenes/resources:

- collision/blocking
- warps
- spawns
- NPCs
- interactables
- encounters
- map IDs and region data

CLI usage:

```bash
godot --headless --path . --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- \
  /path/to/artist_map.tmx
```

The importer derives `visual_id` from the TMX filename. You can override it:

```bash
godot --headless --path . --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- \
  /path/to/Pallet\ Town.tmx pallet_town
```

Legacy schema code still exists in `importer/pokeaether_tmx_importer.gd` for old fixtures, but it is not the artist-map pipeline.
