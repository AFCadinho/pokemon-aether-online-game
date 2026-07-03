# Tiled TMX Visual Importer

This addon imports generic Tiled TMX maps into Godot 4 visual scenes.

Scope:

- Tiled tile layers become `TileMapLayer` nodes
- tile layer order is preserved
- tile layer visibility, opacity, and offsets are preserved
- tile layer property `pao_render_layer=overlay` renders that visual layer above Y-sorted characters
- tile layer property `pao_z_index=<number>` sets an explicit Godot `z_index`
- external TSX tilesets are parsed
- CSV layer data is supported
- Tiled flip flags are preserved through Godot alternative tiles
- Tiled object layers and gameplay properties are ignored
- one shared Godot `TileSet` is saved beside the imported scene and reused when its source signature has not changed

Out of scope:

- PokeAether warps
- NPC spawning
- encounters
- collision semantics
- backend integration
- Tiled object layers/properties
- infinite/chunked Tiled maps
- compressed CSV layer data
- non-orthogonal maps

## Editor Usage

1. Enable `Tiled TMX Importer` in `Project > Project Settings > Plugins`.
2. Use `Project > Tools > Import Tiled TMX...`.
3. Enter a TMX source path and a `res://` output visual scene path.
4. Click `Import`.

## CLI Usage

```bash
godot --headless --path . --script res://addons/tiled_tmx_importer/import_tmx_cli.gd -- \
  /path/to/desert.tmx \
  res://generated/tiled_visuals/desert/desert.visual.tscn
```

The importer will also save `res://generated/tiled_visuals/desert/desert.visual.tileset.tres`.
