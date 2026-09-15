# Block 5: first existing-map migration

## Result and scope

The Player's House and Pokemon Laboratory generated visuals now use the shared
compact atlas contract on their existing canonical paths. Browser and desktop
load the same resources. Hand-authored gameplay scenes, collision, NPCs, warps,
story code, battle assets and preloads are unchanged. Backend source and the local
Compose stack were not changed or interrupted. No release/export was published.

The initial attempt to reimport the artist TMX failed because both sources refer
to a missing adjacent `Indoors Tileset.tsx`. No canonical output was changed by
that failed temporary import. Rather than guess paths or edit artist files, this
migration compacts the current approved generated visuals. Source reimport remains
blocked until that artist dependency is restored. Gary's house is outside this
batch; its source was not found during the initial inventory.

## Equivalence and memory estimate

`tools/migrate_pallet_interiors.gd --check` compacts into a fresh, automatically
cleaned slot-local test directory. It compares a SHA-256 artwork/layout/TileData
fingerprint with the existing visual and validates the saved external references.
Both comparisons must pass before `--migrate` writes either canonical output.
Saving is not a fully atomic two-map filesystem transaction; tracked history
preserves the old assets for recovery.

| Visual | Cells | Used tiles | Layers | Old base RGBA bytes | New base RGBA bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Player's House | 968 | 139 | 4 | 23,822,336 | 811,008 |
| Pokemon Laboratory | 1,067 | 137 | 4 | 23,822,336 | 774,144 |

Together the atlas estimates decline by 46,059,520 bytes (43.93 MiB). This counts
all unique texture paths in each visual's TileSet, including unused old sources.
It is not an observed change in total browser/process RAM, GPU allocation or
battle-start latency. Only five used sources remain per visual.

The native `--render-check` also passed before migration, using X11/OpenGL
Compatibility on AMD Radeon Graphics. Full-map viewport images are nonblank and
byte-identical: 640x1280 for the house and 768x1088 for the lab. There is no resizing
or logged-in gameplay in this comparison.

The original fingerprints are retained in
`tests/fixtures/tiled/pallet_interiors_fingerprints.json`, not duplicate full
textures. `pallet_interiors_compact_check.gd` verifies those fingerprints and
compact budgets on the migrated canonical output and is registered in project
checks and the texture CI workflow.

The 12 old generated atlas files were removed only after checking that no paths
remained referenced. They are recoverable from Git. Their combined file size was
615,120 bytes; the ten new compact texture files total 22,044 bytes. The 593,076
byte texture-file saving is separate from the much larger decoded RGBA estimate.

## Additional safety correction

Compaction removes the dense `tiled_source_signature` metadata: it cannot safely
authorize reuse of a TileSet whose cell-to-atlas mapping changed. The original
TileSet is not mutated. This is covered by the compactor regression fixture.

The explicit scene-and-TileSet legacy baseline now has 33 exceptions. These two
visuals pass the new compact check instead of receiving updated legacy hashes.

## Focused tests

All eleven focused Godot scripts exited successfully:

- `pallet_interiors_compact_check.gd`
- `tmx_atlas_compactor_check.gd`
- `tmx_visual_importer_check.gd`
- `generated_map_texture_storage_check.gd` (329 textures)
- `generated_map_atlas_layout_check.gd` (2 compact, 33 unchanged legacy)
- `players_house_visual_depth_check.gd`
- `players_house_story_intro_check.gd`
- `oaks_lab_gary_sequence_check.gd`
- `starter_choice_dialog_check.gd`
- `player_map_layer_cache_check.gd`
- `web_map_texture_limits_check.gd`

The slot editor generated the three new script UID sidecars. Some existing scene
checks emitted invalid-UID warnings and successfully used their text paths;
unrelated scene resources were not rewritten. The editor also reported the
existing shiny Unown filename case/UID duplication. These warnings are not new
atlas migration failures.

No new browser end-to-end session or matched battle benchmark has been run for
this batch. That remains separate from the structural/story fixtures and native
render comparison. No full paired development verification, promotion, push or
production operation was performed. Keep further existing-map migration bounded
and validate artwork/gameplay bindings rather than bulk regenerating.
