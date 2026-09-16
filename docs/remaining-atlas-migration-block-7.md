# Block 7: remaining atlas migration completed

## Scope and result — 2026-09-16

All 33 remaining legacy generated visuals now use the shared lossless compact
atlas contract, on their existing canonical paths. Together with the two Pallet
interiors, the layout check finds 35 compact visuals and zero legacy exceptions.
The check rejects attempts to introduce new grandfathered exceptions. The
browser boundary, permissions, gameplay scenes, collision, NPCs, story logic,
battle assets and battle preloads are unchanged. Desktop loads the same visual
resources. No backend interruption or backend source change was needed.

Migration uses seven fixed, bounded batches in `tools/migrate_remaining_visuals.gd`:

| Batch | Visuals |
| --- | --- |
| 0 | Eight house/shop/center/school interiors |
| 1 | Two transition buildings, Pewter and Cerulean gyms |
| 2 | Seven routes |
| 3 | Viridian, Pewter, Cerulean, Viridian Forest |
| 4 | Three Mt. Moon floors |
| 5 | Lobby, waiting area, open field, duel, battle royale |
| 6 | Original Pallet directory and retained prototype directory |

For each batch, all temporary compact outputs must pass before any canonical
output changes. Complete artwork/cell/transform/layer-settings/TileData
fingerprints match the approved original visuals. Saved canonical outputs are
reloaded and checked again. Full-map native X11/OpenGL/nearest renders of all 33
visuals are nonblank and pixel-identical before/after compaction. The eight first
interiors were additionally rendered against original generated resources
temporarily restored from `47e5f6816`, then returned to their committed compact
versions. Exactly 64 verified temporary original texture copies were removed
afterwards; their object hashes matched Git before removal.

Migration is not an atomic multi-map filesystem transaction. Original assets
remain recoverable in Git; failed candidates should receive focused follow-ups,
not shared-history rewrites. Cleanup removes only exact owned superseded textures
after a tracked textual-reference audit. The seven unused standalone Pallet
prototype texture copies are explicitly included in this retirement list.

`tests/fixtures/tiled/migrated_visual_fingerprints.json` retains original matching
fingerprints plus post-migration budgets for exactly these 33 visuals.
`tests/migrated_visuals_check.gd` verifies the complete fixed scope, not an
arbitrary smaller manifest. This and the dependency-repair test are registered
in project checks and the texture CI workflow. No remote CI run is claimed.

## Storage and exports

Compared with `47e5f6816`, tracked generated portable texture files decline from
329 files / 23,265,926 bytes to 160 files / 775,280 bytes, saving 22,490,646 bytes
(21.45 MiB). This includes all generated visuals, not just initial browser
content. It excludes TileSet/scene metadata size savings. The summed base-RGBA
estimate for the 33 migrated visuals is now 41,591,808 bytes; maps are not loaded
all at once. Neither figure is total process RAM or measured GPU allocation.

Clean initial browser export: `c8ca626cb7a4be2290216c231822792e6e7921b6`,
Godot 4.6.2, dirty=false. Initial files total 258,129,898 bytes (246.2 MiB before
HTTP compression), versus about 260.9 MiB at block 6. PCK: 219,905,304 bytes,
SHA-256 `9acaa42cb5ba8f419a4296b21ce3e412806fe4fd2f81f729b815237469253844`.
Subsequent changes only add excluded tests/documentation, not gameplay assets.

Both optional modules were rebuilt and passed required/forbidden file markers
and their existing 32 MiB budgets:

| Module | Bytes | SHA-256 |
| --- | ---: | --- |
| Aether Clash maps | 5,066,484 | `61f9bdf676acb8b72d37264455de0970c24607035d4d3930e177b5cfe71173da` |
| Kanto through Misty | 8,764,876 | `cf8bc20ac11c81a498c27d60220b4c4b5fa18966af61fe03cc4378d45cd83ec3` |

`tests/exported_atlas_module_probe.gd` runs in an empty slot-local project and
mounts each actual exported pack. It loads 15 selected core visuals, 12 Misty
visuals and three Aether Clash visuals, validates saved cells/layers/used-tile
counts/budgets and lossless texture types/dimensions. All three probes pass;
missing dependencies cannot fall back to the source checkout. An initial core
probe wrongly requested the horizontal transition building, which the unchanged
browser preset explicitly excludes. The probe was corrected to actual core
scope; no extra outside-demo asset was added to the export.

## Artist TSX repair

The indoor TSX and its PNG already exist one directory above the two artist
Pallet TMX files. Those TMXs refer to an adjacent `Indoors Tileset.tsx` instead.
Artist files were not modified or copied into another checkout. Shared parser,
visual importer and both visual CLIs now accept an explicit missing-reference
mapping. Only missing references use it; valid existing dependencies are never
overridden, and image paths resolve relative to the selected TSX itself. There
is no ancestor search or guessed dependency replacement.

Both real artist TMXs successfully reimport into fresh temporary output using
that exact TSX. Their full fingerprints match the approved generated house/lab
visuals. The default raw artist references remain unchanged: use this explicit
mapping until they are corrected in Tiled. `docs/tiled/pallet-missing-tilesets.json`
is a portable placeholder example, not machine-specific runtime configuration.

CLI syntax:

```sh
godot --headless --path . --script \
  addons/tiled_tmx_importer/import_tmx_cli.gd -- \
  SOURCE.tmx OUTPUT.visual.tscn MISSING_TILESETS.json
```

The PokeAether visual CLI similarly accepts a third JSON-file argument after
source and visual ID. All slot Godot commands must run through `slot-env`.
Actual source validation can be repeated without canonical writes using
`tools/check_pallet_artist_reimport.gd -- ARTIST_PALLET_DIRECTORY EXPLICIT_TSX`.
Negative parser cases deliberately log missing-file errors while their tests
verify reporting; the repaired CLI fixture passes and cleans its own output.

## Focused verification and limits

Passing checks include the 33-map fingerprint check, all 35 atlas layouts, 160
texture storage files, shared importer/compactor, missing-dependency parser and
actual CLI repair, PokeAether importer, Pallet compact/door-piece regression,
the two earlier Pallet interiors, player map-layer cache, Cerulean gym visual,
Mt. Moon B1F mask, Route 4/Mt. Moon transition, Cerulean interior/exterior
connections, Aether Clash lobby/phase-2 maps and Misty tile/world initialization.
The nine related Node provenance/comparison/runtime-guard tests and four Python
module-pipeline tests also pass. Tracked script UID sidecars are complete.

Cached-only browser diagnostics understand both embedded old prototype textures
and the current external compact textures. The original Pallet directory is no
longer falsely labelled an old-atlas control after migration. The historical
prototype builder refuses current shared-contract atlases; restore historical
inputs deliberately if reproducing that old experiment.

Existing invalid-UID text-path fallbacks, unauthenticated trainer-fixture and
ObjectDB-at-exit warnings remain in some gameplay scene checks. Assertions pass;
this is not warning-free native execution or broad leak certification.

No new live matched battle benchmark, fresh-account story-through-Misty E2E,
browser GPU/process-RAM measurement or all-platform exported desktop playthrough
is claimed for these 33 maps. Block 6 battle timing evidence remains limited to
its own matched pair; unchanged preloads are not an all-map latency guarantee.
The normal 12-service local backend stayed running and healthy. No full paired
gate, promotion, push, release, publication or production operation was performed.
