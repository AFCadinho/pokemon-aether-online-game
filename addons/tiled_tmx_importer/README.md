# Tiled TMX Importer Proof of Concept

This addon imports generic Tiled TMX maps into Godot 4 scenes.

Scope:

- visible Tiled tile layers become `TileMapLayer` nodes
- Tiled object layers become placeholder `Node2D` trees under `ObjectLayers`
- object names, object metadata, and custom properties are preserved as Godot metadata
- external TSX tilesets are parsed
- CSV layer data and base64 layer data are supported, including zlib/gzip-compressed base64 data
- one shared Godot `TileSet` is saved beside the imported scene and reused when its source signature has not changed

Out of scope for this proof of concept:

- PokeAether warps
- NPC spawning
- encounters
- collision semantics
- backend integration
- infinite/chunked Tiled maps
- compressed CSV layer data
- non-orthogonal maps

## Editor Usage

1. Enable `Tiled TMX Importer` in `Project > Project Settings > Plugins`.
2. Use `Project > Tools > Import Tiled TMX...`.
3. Enter a TMX source path and a `res://` output scene path.
4. Click `Import`.

## CLI Usage

```bash
godot --headless --path . --script res://addons/tiled_tmx_importer/import_tmx_cli.gd -- \
  /path/to/desert.tmx \
  res://imported/tiled/desert/desert.tscn
```

The importer will also save `res://imported/tiled/desert/desert.tileset.tres`.
