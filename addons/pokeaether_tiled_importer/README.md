# PokeAether Tiled Importer Phase 2A

This addon layer imports a PokeAether-specific TMX schema on top of the generic Tiled importer.

Phase 2A scope:

- parse TMX through the generic importer parser
- validate PokeAether map properties and `PA_*` object layers
- generate typed map data resources
- generate a current-compatible runtime scene
- write generated files only under `res://generated/maps/<map_id>/`

Generated files:

- `<map_id>.runtime.tscn`
- `<map_id>.map_data.tres`
- `<map_id>.tileset.tres`

CLI usage:

```bash
godot --headless --path . --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- \
  /path/to/pokeaether_map.tmx
```

Required map properties:

- `pa_schema_version`
- `map_id`
- `map_display_name`
- `region_id`
- `region_name`

Recognized object layers:

- `PA_Spawns`
- `PA_Warps`
- `PA_NPCs`
- `PA_Items`
- `PA_EncounterRegions`
- `PA_Triggers`

Gameplay object coordinates must be aligned to the 32 px Tiled grid. Point objects are converted to Godot tile-center positions.
