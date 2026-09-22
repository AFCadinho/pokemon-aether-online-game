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
- one shared Godot `TileSet` is rebuilt and saved beside the imported scene
- generated atlas chunks are stored with portable lossless compression for desktop and Web exports
- only regions referenced by tile layers (including hidden layers) are packed into compact atlases
- tile pixels, transforms, alternative TileData and layer settings are preserved without resizing

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
- used TMX/TSX tile animations and multi-cell atlas tiles (explicitly rejected rather than silently stripped)

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
Generated `.texture.res` chunks are losslessly compressed automatically. The
repository check `tests/generated_map_texture_storage_check.gd` rejects output
that bypasses this storage contract.

Compaction is automatic in both editor and CLI imports. Atlases use 2px borders,
4px separation and dimensions capped at 4096px; large sources are split. The
importer saves external compact textures and removes only its own superseded
chunks after saving the scene. Other outputs in the same directory are preserved.
Unsupported used animations are rejected before generating textures, preserving
the previous output. This is not a fully transactional filesystem operation.

`tests/generated_map_atlas_layout_check.gd` checks the compact layout in CI.
The 35 existing visuals have an explicit scene-and-TileSet hash baseline pending
separate migration. New or edited outputs must meet the compact contract; do not
refresh that baseline to bypass a failed import check.
