# Lossless model rollout validation

Follow-up: [streamed launcher collection integration](lossless-launcher-collection-integration.md)
connects staging/final activation to the actual Downloads UI and opted-in update
queue, including HTTP pause/restart/resume and zero-download rollback. Supported
desktop-platform runtime qualification remains open.

Follow-up: [renderer lifetime/reference validation](lossless-material-reference-validation.md)
corrects the Archen interpretation: immediate fixture teardown triggered the
error; a full 2,400-scene lifecycle now passes without model changes. The
historical reports below remain failed and unchanged. Warm image repeatability
remains a separate hold.

Local task `lossless-model-rollout-validation`, slot-a, 2026-10-06. This follows
the [complete catalog preparation](lossless-model-catalog-preparation.md).
No published pins, approved model hashes, R2 objects or player installations
are changed. Candidate admission is generated inside isolated test projects.

## Revision selection

The launcher previously checked every matching required-ID set independently.
Two successive revisions containing the same Pokémon would have to match both
index hashes. The adapter now accepts exactly one complete compiled
revision/hash/size/object-key tuple with the correct ID set. Mixed tuples and
unknown pinned revisions are rejected. Direct bundle acceptance identifies its
known revision, rather than choosing by count. Historical small v1/v2 sets
remain supported. The existing published v10 check passes unchanged.

The fixture compiles the original and candidate into two separate known pin
slots with the same 1,200 IDs. On-demand selection already uses complete file
size and SHA-256; its actual service is exercised against both pins and cached
catalogs. The human-readable draft is 1,064,994 bytes, exceeding the existing
1 MiB limit. The fixture uses compact JSON of exactly the same parsed data.
The preparation tool now also emits compact indexes. No limit is increased.

## Whole-collection transaction

The store now offers `install_archives` and the adapter `accept_bundles`.
One explicit transaction verifies every ZIP, safe directory, manifest and
extracted file, then activates only the completed validated generation.
Original objects remain available for rollback. A later failed member leaves
the active generation unchanged; verified new immutable objects may remain
unreferenced and are reusable on retry.

Single-bundle installation uses the same preparation path and public result
contract. Dependencies and immutable versions are still checked. Existing
corruption, previous-pointer recovery, restart, removal and GC tests pass.
New batch cases check successful-prefix isolation, failure/retry and restart.

**Scope:** the collection API is exercised by local qualification. The launcher
download UI still installs each completed ZIP separately. Integrating a
streaming collection transaction with pause/resume, disk-space requirements
and recovery remains separate work. These measurements do not establish
Internet throughput or current download UI speed.

## Stable cache admission

Candidate model approval records the original `cache_source_bytes`. Only
checked-in approval provides this cost. The presenter charges the larger of
the current real file size and the approved cost, and strips forged internal
cache fields from local catalogs. Older metadata keeps file-size accounting.
The 64 MiB and two-entry limits are unchanged.

The fixture binds candidates to original costs from verified receipts. The real
renderer/LRU check records original/native costs for comparison. Floragato, Grimmsnarl and
Maushold retain their former cache admission behavior. Compression does not
increase their permitted cached residency merely by shrinking their files.
Stream size and cache cost are not measured RAM/VRAM.

## Qualification scope and evidence

Retain `.tmp/lossless-rollout-v1/` in slot-a, including failed setup runs.
Source archives and prepared ZIPs are read in place. Test installations are
new outputs; no cache, builds, credentials or userdata are copied. Tiny projects
own caches and generated approval. The real battle runner temporarily writes
only the assigned slot's approval and checks its exact restoration in `finally`.

The full check verifies both pinned indexes, installs nine original controls,
rejects a partly successful failed batch, installs the entire candidate,
reconstructs state, plans no repeat downloads, checks on-demand reuse/repair,
attempts every native instance, and restores nine control pairs in a separate
rollback check if engine qualification stops early.
It does not perform complete original installation or full-catalog rollback.
The full run completed installation/restart/on-demand checks but reported null
material handles when instantiating Archen, normal and shiny. The same failure
occurs in Forward+, using the production `CACHE_MODE_IGNORE`, and in a fresh
original-only Archen probe. It is an existing material issue, not a successful
full-runtime qualification. These failed checks remain red; no errors, materials
or image thresholds are suppressed or changed. The separate deserialization
phase independently hashes and loads all 2,400 scenes, verifies they contain
nodes and no external dependencies, and deliberately does not instantiate them.
Its success is not an override of the failed instantiation gate.
`--resume-installed` can reuse that verified test installation: it independently
rechecks the complete active catalog and both pinned indexes before continuing.
The prior failed report is retained and its installation measurement is explicitly
attributed to the first attempt; recovery is not counted as a new installation.

Controls: Floragato, Grimmsnarl, Maushold, Marshadow, Gliscor, Charmander,
Mega Garchomp, Dragonite and Roaring Moon. Real battles use three rounds
(classic/stadium/classic), both variant arrangements, 1280×720 and unchanged
120-frame intervals and 20 ms p95 gates. Linux RSS and engine static/texture/
buffer counters are recorded; these do not measure all GPU-driver allocations.

Final measured evidence: `native_catalog_rollout_results.json`. Strict image
reference and supported desktop-platform loading/update/rollback qualification
remain open. Publication requires separate authorization.

## Measured Linux result

- All 1,200 candidate pairs / 2,400 appearances installed and verified. The
  installation API took 333.388 seconds in the retained first full attempt.
  This excludes network transfer and is not current download-UI throughput.
- Restart and no-op planning, failed-prefix isolation and on-demand pin selection,
  cached reuse and corruption repair passed. All 2,400 scenes independently
  deserialize correctly; the separate full-instantiation check remains failed.
- Nine original and nine candidate pairs each passed three real battle rounds.
  Original round p95: 17.652 / 19.402 / 17.197 ms; candidate:
  17.199 / 17.197 / 17.211 ms. All prepared classic/stadium observations pass
  20 ms, with 4,320 / 2,160 frames respectively per run.
- All 54 cache-cost/residency observations match exactly. Neither the cache
  entry limit nor the byte budget is increased.
- Sampled peak RSS: 3,066,822,656 / 2,895,908,864 bytes (original/candidate).
  Engine static peaks: 660,426,969 / 620,473,225 bytes; texture peaks:
  1,348,889,088 / 1,300,811,776; buffer peaks: 82,660,660 / 82,867,104.
  These are component peaks, not additive memory totals. One sequential Linux
  comparison shows no RSS increase; it does not prove universal memory savings
  or a speed improvement. Cold/warm renderer and driver behavior vary.
- The checked-in approval registry is restored byte-for-byte after both runs.
- A separate rollback transaction restores all nine original control pairs
  (18 exact files), preserving the other 1,191 installed candidate pairs. This
  is not a full-catalog rollback certification.

The next rollout work is the existing material/strict-image hold investigation,
supported desktop qualification, and integrating the collection API into the
streaming download UI. Re-encoding all models has already completed and need
not be repeated unless a source changes. Publishing the prepared hashes or ZIPs
requires an independently approved release step.

The paired memory measurements were taken on task commit `4bbaa372d` before
merging newer development camera/Close Combat work. Those unrelated changes
merge without touching the cache admission paths. The combined development
batch is not certified by these measurements; its release gate remains separate.
