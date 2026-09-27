# Standard tall-grass animation

The Route 1 trial was approved and is now the default for the existing regular grass and Viridian Forest grass. Both keep their own original artwork. Native animations use four phases assigned to groups of approximately 2×2 cells, with the approved 7.56-second cycle (3.36 seconds motion, 4.2 seconds rest). The bottom ten pixel rows and two outer columns stay fixed.

## Scope

- 16 current artist maps plus one older authoring map: 3,283 grass cells.
- 10 existing generated Godot maps: 2,047 grass cells.
- `tmx_visual_importer.gd` recognizes both exact sprite hashes automatically on future imports, including static tiles painted from an older Outside tileset.
- Shared Tiled sources: `kanto/artist/exterior/Tall Grass Wind.tsx` and `Tall Grass Wind - Forest.tsx`. Existing outside/cave PNGs and TSX files are unchanged.
- Reimporting current maps preserves coordinates, flags, TileData, and existing native water/tree/flower timelines. Newer authoring routes not yet integrated as game scenes inherit wind on import.

The canonical visual migration matches pixels instead of replacing current game layouts with potentially newer TMX geometry. It is recorded in `tall_grass_standard_report.json`. Static artwork/layout fingerprints are unchanged; `usedTiles` and decoded memory budgets account for phase variants. Added decoded atlas storage is 10.61 MiB across all ten visuals, not per map. Mobile/browser performance is not benchmarked.

Route 22 uses an old mixed tree/grass layer. Importer-marked phase variants share a grass-family tag; depth sorting still requires their complete occurrence set to equal the hidden encounter mask. This keeps the original strict mask check while allowing multiple animation phases.

## Preview

```sh
godot --path /home/adinho/Desktop/pokemonaetheronline/game/pokemon-aether-online --rendering-method gl_compatibility --script res://tools/preview_tall_grass.gd
```

The default now shows canonical Route 1. Space switches only tall grass, Tab changes the view. The isolated historical trial remains accessible with `-- route1_tall_grass_test`.

## Backup and authoring

Backup before this rollout:
`/home/adinho/Documents/tiled_pokeaether_backups/before_tall_grass_2026-09-27_091726/`

It contains authoring files plus their SHA-256 manifest and a separate `godot-before-tall-grass.tar` of generated visuals/fixtures. The earlier fully static map backup remains available too. Original atlas files were not edited; current maps reference the new shared grass atlases.

Authoring application/verification tools and report:
`/home/adinho/Documents/tiled_pokeaether/tools/standard_tall_grass.py`
`/home/adinho/Documents/tiled_pokeaether/tools/verify_standard_tall_grass.py`
`/home/adinho/Documents/tiled_pokeaether/tall_grass_rollout.json`

For Tiled editing, use the shared grass tilesets. Godot also distributes the phases automatically when grass is painted using the old sprite. New imports do not require running the migration script. `tools/standardize_tall_grass.gd --apply` is for existing generated static-grass visuals; already migrated maps are skipped. Keep a fresh backup before a later migration.

## Focused verification

- `tall_grass_wind_check.gd`: original fingerprints, all existing animation timelines, exact approved grass frames/timing/phases, and automatic import of a newly painted static grass fixture with a flipped cell.
- `tall_grass_character_depth_check.gd`: character overlap and Route 22's complete 253-cell legacy mask.
- `map_animation_rollout_check.gd`, `migrated_visuals_check.gd`: prior animation/appearance contracts retained.
- `tmx_atlas_compactor_check.gd`, `tmx_animation_check.gd`: generic compaction/import regression checks.
- `generated_map_atlas_layout_check.gd`, `generated_map_texture_storage_check.gd`: native compact/lossless resources.
- Authoring comparison: all non-grass cells, objects, flags and original PNG/TSX bytes unchanged.
- Viridian Forest viewed in Godot.
