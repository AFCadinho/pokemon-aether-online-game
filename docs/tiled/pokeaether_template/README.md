# PokeAether Tiled Template

This directory contains the canonical Tiled starting point for imported PokeAether maps.

## Files

- `pokeaether_overworld_template.tsx`: external TSX tileset used by the template and example.
- `pokeaether_map_template.tmx`: blank 8x8 map with required PokeAether properties, standard tile layers, and all `PA_*` object layers.
- `pokeaether_minimal_example.tmx`: small complete example with collision, tall grass, spawn, warp, NPC placeholder, interactable sign, item placeholder, encounter region, and trigger.

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
- `PA_Interactables`
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
9. For signs or other map objects with behavior, paint the visual tile on a visual layer and place a matching point object on `PA_Interactables`.
10. Keep ids unique within each object layer, for example unique `spawn_id`, `warp_id`, `npc_id`, and `interactable_id`.
11. Run the importer/check workflow before handing the map to engineering.

## Interactables

Use `PA_Interactables` for map-owned objects that can be talked to, read, inspected, or otherwise activated. Common examples are road signs, trainer tips signs, bookshelves, statues, computers, switches, and hidden map objects.

Point object properties:

- `interactable_id`: unique stable id within `PA_Interactables`, for example `route_1_sign_viridian`.
- `interactable_kind`: behavior category, for example `road_sign`.
- `display_name`: optional dialogue speaker/title, for example `Sign` or `Trainer Tips`.
- `dialogue`: optional inline text. Use `\n` between dialogue lines.
- `dialogue_id`: optional content id for externally managed dialogue.
- `blocks_movement`: optional bool, defaults to `true`.
- `requires_facing`: optional bool, defaults to `true`.
- `blocked_tile_offset_x` / `blocked_tile_offset_y`: optional tile offset from the object point when the blocked tile is not the object's own tile.
