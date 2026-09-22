# Catalog production direction — 2026-09-22

## Active decision

Resume catalog production with the existing identity-gated SCVI pipeline and
standalone GLB/SCN model format. Do not wire component assembly into a game loader,
launcher, approval registry or distribution path. No production server operation
is implied by local asset production.

Component sharing is closed as **promising but not production-safe**. Preserve
`STORAGE_AUDIT.md`, `STORAGE_COMPONENT_PROTOTYPE.md`,
`STORAGE_SEQUENCE_INVESTIGATION.md`, their JSON results, `storage_components*`
and `storage_sequence_trace.gd`. These tracked files remain in Git history and
the working tree. The local artifact `.worktrees/slot-b/frontend/.tmp/storage-components-04`
and `.tmp/sequence-*.json` are retained in place; do not clean or recycle that
directory as part of production. No sources or existing catalogs are removed.

No further component-sharing, deduplication or codec experiments until catalog
size is an observed practical problem (for example measured installation,
download or disk-budget impact), rather than a theoretical extrapolation.
Reopening requires an explicit decision; historical documents listing possible
next experiments do not authorize continuing them.

## Resumed batch 01

`catalog_production_batch_01.json`: 25 normal-form species. Selection is the first
25 in National Dex order represented by a normal/form-0/gender-0 row in the local
SCVI metadata, excluding the previous 100-model, pilot-25 and phase-5 cohorts.
Resource IDs are resolved by the existing identity gate, never by Dex arithmetic.
This is a manageable production increment, not a new pipeline stress experiment.

Use existing import/source-review/export and standalone Godot preparation tools
without algorithm or quality changes. Verify identity, native animation mapping,
materials, placement and visibility. Keep identity, source, shader or visual
failures in the blocked queue; do not hold up the rest to perfect exceptions.
Technical conversion alone never grants visual approval or activates a model.
Existing approved catalogs remain untouched until normal review/admission gates
are satisfied.

Local outputs for this increment use `slot-b/frontend/.tmp/catalog-production-01-*`.

### First resumed run completed

- 25/25 identities and source bundles verified.
- 18 standalone SCNs built and reloaded, with zero external resource dependencies.
- 126 native mapped clips; zero Godot pose/timing errors for the 18 conversions.
- 90 standalone SCN preview images, plus source and GLB review galleries.
- No model approved, installed, activated, pushed or deployed. Visual review and
  real material-response/battle admission remain pending; the static technical
  previews are not a replacement for those gates.

Seven safe holds, with no converter changes or investigations:

- Venomoth: unsupported transparent/refraction material profile.
- Cyndaquil, Quilava: missing/ambiguous auxiliary effect loop.
- Sunkern, Sunflora, Girafarig, Sneasel: unsupported dynamic visibility clock.

The Godot cohort command exits 1 because those seven holds remain present;
every converted row has an empty pose/timing error list. This is not a 25/25
successful batch. The standalone conversion and standalone preview commands
both finish successfully for the 18 eligible exports.

Evidence: [catalog_production_batch_01_results.json](catalog_production_batch_01_results.json).
It records per-species hashes, holds, clip names, script/report hashes and the
unchanged pipeline base commit. Source gallery:
`.tmp/catalog-production-01-review/source/index.html`; GLB gallery:
`.tmp/catalog-production-01-review/export/index.html`; standalone images:
`.tmp/catalog-production-01-images/`; candidate scenes/report:
`.tmp/catalog-production-01-runtime/`. These are task-slot local outputs, not
a distributed or selected game catalog.

Focused checks: 13 identity tests and 6 Godot-review Python tests pass, followed
by the actual 18-model conversion/reload, seven-clip checks and image capture.
The optional environment-dependent runtime unit wrapper was skipped; the real
converter was exercised directly instead. No full development gate was run.

Next active work is visual review/admission of these 18 candidates using the
existing workflow, not storage research or perfection of the blocked seven.
