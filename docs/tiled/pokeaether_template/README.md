# PokeAether Tiled Template

This directory contains the canonical Tiled starting point for imported PokeAether maps.

## Files

- `pokeaether_overworld_template.tsx`: external TSX tileset used by the template and example.
- `pokeaether_map_template.tmx`: blank 8x8 map with required PokeAether properties, standard tile layers, and all `PA_*` object layers.
- `pokeaether_minimal_example.tmx`: small complete example with collision, tall grass, spawn, warp, NPC placeholder, item placeholder, encounter region, and trigger.

## Layer Order

Use these tile layers in this order unless a map needs additional visual-only layers:

1. `Ground`
2. `GroundDetail`
3. `Path`
4. `Water`
5. `Objects`
6. `Overhead`
7. `Collision`
8. `TallGrass`
9. `LedgeDown`
10. `LedgeUp`
11. `LedgeLeft`
12. `LedgeRight`
13. `RouteGates`

Use these object layers exactly:

- `PA_Spawns`
- `PA_Warps`
- `PA_NPCs`
- `PA_Items`
- `PA_EncounterRegions`
- `PA_Triggers`

## Artist Workflow

1. Copy `pokeaether_map_template.tmx` and keep it next to any TSX files it references.
2. Change the map properties: `map_id`, `map_display_name`, `region_id`, `region_name`, and optional metadata.
3. Keep maps orthogonal, finite, and 32x32 px per tile.
4. Paint visible art on visual layers only.
5. Paint passability markers on `Collision`; keep that layer hidden in Tiled if preferred.
6. Paint grass markers on `TallGrass` where encounter checks should later be possible.
7. Add gameplay placeholders on the `PA_*` object layers, not on visual tile layers.
8. Keep all gameplay objects aligned to the 32 px grid.
9. Keep ids unique within each object layer, for example unique `spawn_id`, `warp_id`, and `npc_id`.
10. Run the importer/check workflow before handing the map to engineering.
