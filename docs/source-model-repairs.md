# Five source-model repairs

Task: `pokemon-source-model-repairs`, 2026-10-11. Evidence and checksums:
[`catalog_source_model_repairs_results.json`](../tools/sprite_factory/catalog_source_model_repairs_results.json).
Local scenes, bundles, captures and detailed reports remain in
`.tmp/source-model-repairs` in the retained task worktree.

## Result and scope

| Pokémon | Repair | Integration |
| --- | --- | --- |
| Cramorant | Hide the parked fish and Pikachu meshes in the base form. | Exact-revision runtime correction for normal/shiny; repaired local SCNs and bundle. |
| Deoxys | Retain the animated tentacle arms; hide the duplicate humanoid arms and transient sphere. | Exact-revision runtime correction for normal/shiny; repaired local SCNs and bundle. |
| Minior | Retain the meteor shell and inner body; hide detached shell pieces and the exposed-core face overlays. | Exact-revision runtime correction for normal/shiny; repaired local SCNs and bundle. |
| Togedemaru | Retain the complete normal body; hide the tucked duplicate body and two extra spike sets. | Exact-revision runtime correction for normal/shiny; repaired local SCNs and bundle. |
| Mega Hawlucha | Replace mistaken Furfrou source `pm0701_11_00` with `pm0761_51_00`; rebuild normal/shiny from their native material tables and motion bank. | Local candidate pair, bundle and freshly measured placement profiles. Active catalogs and published/shared bundles have **not** been replaced. |

The four Blender sources contain no usable mesh visibility curves. These are
explicitly **reviewed reconstructions of the base form**, not recovered original
visibility keys. All seven exported clips of each appearance were inspected at
three times and from a side view. No geometry, skin, material or pre-existing
animation key is edited by the runtime helper. Alternate-form transitions are
outside this repair. Togedemaru's exported names do not describe their geometry:
`EffGcloud01` is the complete normal body; selecting `BodyNormalSkin` by its name
would select an extra spike set instead.

The same helper is already used by the 3D battle loader and Pokédex/summary
preview. It checks exact source/container hashes and applies visibility to a
private animation library, preserving shared normal/shiny resources. These four
corrections work with the existing admitted models; they do not require new
asset downloads. The local baked SCNs provide portable repaired derivatives for
a later asset release, without modifying the original source archives.

Mega Hawlucha's developer number is 761 while its Pokédex number is 701. The
source-table rows and normal/shiny icon hashes are pinned in
[`catalog_mega_hawlucha_source_audit.json`](../tools/sprite_factory/catalog_mega_hawlucha_source_audit.json).
Old publication receipts are retained under `previous_source_publication` in the
intake; their approvals do not transfer to the replacement. The corrected source
has no distinct sleep animation: its own faint-loop serves as the rest/sleep
pose. Seven source clips and both appearances were inspected. Native pose/timing
and reverse-order checks passed. New placement was measured at 60 Hz and checked
independently at 120 Hz, with minimum floor clearance about 0.025 world units.
All 48 captures across two battle cameras and both sides were in view and clear
of the HUD proxy. This is not full arena/UI/platform or production certification.

## Focused checks

- `tests/reviewed_source_visibility_check.gd`: eight repaired appearances plus
  both Roaring Moon regression appearances, each loaded twice. Checks exact hash
  guards, idempotence, unchanged original keys/bone poses, mesh/skin sharing,
  private animation libraries, RESET and invalid-mesh rollback.
- `tests/battle_visibility_tracks_check.gd`: switching, seek boundaries, RESET,
  reload, isolated instances and invalid binding rejection.
- `tests/shared_model_catalog_binding_check.gd`: 2,168 appearance bindings and
  16 correction bindings, including concurrent lookup and forged-hash rejection.
- `tests/shared_geometry_catalog_check.gd`: 2,062 appearance bindings and 14
  correction bindings, with the normal default still disabled.
- Twelve Python tests in `test_catalog_mega_source_mapping.py`.
- Eight baked SCNs reloaded with the intended visibility in every clip.
- Mega Hawlucha native timing/pose and battle placement checks described above.
- Five local bundle archives: all ten scene sizes and SHA-256 hashes checked.

Run Godot through `ops/worktrees/slot-env SLOT -- godot ...`. The real-source
visibility test takes `VISIBILITY_SOURCE_FIXTURE`, a JSON object with `entries`
containing `identity`, `source_path`, `source_sha256`, `candidate_path` and
`candidate_sha256`. This task used the same original path for both loads; it did
not claim an additional physical repacked-container comparison. Shared-container
identity translation is covered by the catalog checks.

To reproduce the four portable repairs, run
`tools/sprite_factory/bake_reviewed_visibility_repairs.gd` with
`MODEL_REPAIR_CATALOG` pointing to the original native catalog and
`MODEL_REPAIR_OUTPUT` pointing to a **new** absolute output directory. It verifies
source hashes, writes only new SCNs, reloads them, and emits `catalog.json` with
`runtime_approved=false` and `published=false`. For Mega Hawlucha, use the audited
intake with `catalog_mega_3d_production.py`; the retained build uses the original
ZA source archive and pinned importer. Existing candidate/battle/bundle tools
produce the local replacement and its placement fixture.

## Remaining work

- Admit the corrected Mega Hawlucha pair together with its new placement and
  update the active normal/shiny shared packs and release bundle selection.
  Publishing requires explicit authorization under the workspace AGENTS.md.
- Recalibrate and review anatomical attack attachment points for these five
  repaired models. This task does not turn the earlier five attachment holds
  into approved emission points.
- Preserve the original source materials and missing native behaviors as noted;
  this work does not reconstruct alternate forms or invent missing sleep clips.
