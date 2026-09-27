# Catalog production direction — 2026-09-22

## Batch 03 — next 100 normal-form candidates (2026-09-27)

The [batch-03 manifest](catalog_production_batch_03.json) selects the next 100
canonical species in National Dex order, Gothita through Inteleon, excluding
all previous observation and production batches. Identity intake verified 98
source/identity pairs. Source review produced 65 diagnostic GLBs and held 35
cases with explicit reasons in the [intake result](catalog_production_batch_03_intake_result.json).
All 65 exports have standalone Godot scenes with 520 native clips, including a
second physical attack per model. Follow-up recovered another 15 normal models
and 22 shiny candidates. The 80 normal candidates and 75 complete
normal/shiny pairs passed local visual review and battle checks, including
three real battle-presenter rounds per pair. The 75 complete pairs now have
individual local bundles, passed launcher installation/load/no-op/restart
checks, and are admitted in the matching local game and launcher reviewed
registries. Twenty source and five shiny holds remain in the review queue.
No batch-03 bundle has been uploaded or activated in a release content index;
see [batch-03 follow-up](../../docs/catalog-production-batch-03.md).

## Release v6 preparation

The 71 approved batch-02 pairs are pinned in the staged
[v6 release](../../docs/approved-3d-bundle-release-v6.md). Its 154-bundle
content index retains the 83 v5 bundles and adds 71 new ones. The 29 held
batch-02 cases remain in their separate review queue and do not block the next
batch. R2 upload and public verification passed. Desktop release `0.3.86` now
selects v6 for Windows and Linux; the public manifests and downloads passed
size and SHA-256 checks.

## Batch 02 — 100 new normal-form candidates (2026-09-26)

The next 100 catalog entries have been processed in National Dex order after
excluding the previous observation and production cohorts. The existing pipeline
was not changed. Of 100 requests, 98 passed identity/source verification, 81
produced standalone Godot scenes, and 19 were safely held. The 81 scenes contain
648 native clips (including a second physical attack on every model), with zero
Godot pose/timing errors and zero external scene dependencies. Five static
preview images per scene (405 total) were captured.

The user accepted all 81 normal forms in the static overview and 79 in battle
images. Kyogre's corrected sleep pose floats unnaturally; Dialga's sleep pose
intersects the classic HUD proxy. These two stay in the review queue. The other
79 passed 120 Hz floor, framing and HUD checks. Sixty-nine shiny variants have
exact normal/shiny geometry and animation parity, error-free motion captures
and user visual approval. All 69 normal/shiny pairs passed local real-battle
stress, individual-bundle installation, scene loading, no-op update and restart
checks. They are now locally approved in the game and launcher registries, with
69 individual bundles totaling 1,591.25 MiB. Ten normal models still await
qualified shiny materials, and 19 source holds remain queued. No new bundle
was uploaded, activated in a release index, pushed or deployed. See
[batch 02 review](CATALOG_PRODUCTION_BATCH_02_REVIEW.md) and the pinned
[per-species results](catalog_production_batch_02_results.json).
At that first approval, the 12 unapproved normal models remained accessible in the desktop debug
Pokédex/summary preview through a hash-pinned manifest. The 69 approved pairs
require their bundles to be installed before they appear in battles.

### Review-queue follow-up

Shroomish and Bronzong have now passed a separate shiny source audit, exact
geometry/animation parity, 24-capture motion review, user normal/shiny visual
review, three real-battle passes, and individual-bundle install/load/no-op/restart
checks. Their exact pairs are approved in the local game and launcher registries;
two new unreleased bundles total 51,464,759 bytes. The current batch-02 total is
71 approved pairs. Eight shiny-material holds, Kyogre and Dialga battle holds,
and 19 source holds remain. The earlier 69-pair approval record remains a
historical snapshot; see the separate
[review-queue approval](catalog_production_batch_02_review_queue_approval.json).
No follow-up bundle has been uploaded or activated in a release index.
The approved registry also loaded both installed pairs in three real battle
passes (Classic, Stadium, Classic), with no uncovered error; local evidence is
`.tmp/catalog-production-02-review-queue-approved-installed-stress-2026-09-26.json`.

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
The [batch 01 static screening handoff](CATALOG_PRODUCTION_BATCH_01_REVIEW.md)
confirms retained SCN hashes and previews and records per-model moving-review
focus. It does not change any visual or runtime approval.

### Local preview admission (not battle approval)

The 18 pending candidates are now available to the local desktop **debug** client
in the Pokédex and summary card when Battle presentation is set to 3D. Restart
the client after updating development. The ordinary catalog and saved settings
are untouched. The existing summary play menu selects all seven native clips.
Previews say **Review candidate**; their tooltip explicitly states that they are
not approved for battles or distribution.

The supplementary manifest lives at
`/home/adinho/Documents/3d_models/PokeAether/catalog-production-01-review/catalog.json`.
It references the retained standalone scenes, without copying or editing them.
The preview-only resolver accepts only the pending identities and exact SCN
hashes pinned in `catalog_production_batch_01_results.json`. Unknown hashes,
wrong bytes, duplicate identities, blocked models and shiny forms are rejected.
Release/web/mobile clients cannot use this admission path. Reviewed/screened
models retain precedence. The battle registry and portable-pack registry have
not been expanded, so this does not enable these candidates in battles yet.

Review list: Charmeleon, Persian, Slowbro, Igglybuff, Mareep, Flaaffy, Ampharos,
Skiploom, Slowking, Pineco, Dunsparce, Teddiursa, Ursaring, Houndour, Houndoom,
Phanpy, Stantler and Larvitar.

Focused checks: all 18 models load independently in both preview components,
the seven-clip menu works, rejection/fallback checks pass, and the real summary
card test covers the existing play button, zoom, faint-to-damage reset, separate
cards and sprite fallback. Asset UID path-fallback warnings from existing UI
scenes are unrelated to the preview admission and remain unchanged.
