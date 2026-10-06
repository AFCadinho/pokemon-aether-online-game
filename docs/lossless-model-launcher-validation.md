# Lossless native bundles: launcher and battle validation

Local research task `lossless-model-launcher-validation`, assigned to slot-b,
2026-10-06. This follows the
[native compression research](lossless-native-model-compression-research.md).
No release, R2 object, published index, player setting or normal checkout is
changed. Research tools and evidence alone are integrated into development.

## Actual bundle sizes

Eleven already approved normal/shiny pairs from the initial sample are packaged
as local fixtures using their unchanged manifests, recalculated native-file
hashes/sizes and incremented immutable bundle versions. Original source archives
are read in place. Their hashes are checked against the pinned current v10 index
before and after generation. Every re-encoded native stream must equal the
original decoded stream exactly.

| Eleven complete bundle ZIPs | Bytes | Purpose |
| --- | ---: | --- |
| Approved original archives | 365,356,392 | Current runtime baseline |
| Native 256 KiB / Zstd level 9 | 241,229,040 | Smaller blocks |
| Native 1 MiB / Zstd level 9 | 236,976,214 | Largest tested saving |

These are measured complete ZIP sizes, including manifests and directory
metadata, unlike the earlier native-file-only totals. They are not a measured
size for the full catalog. No custom decompression layer is needed: these are
ordinary supported native SCNs inside the existing bundle ZIP layout.

## Launcher qualification scope

The local HTTP server provides Range requests. The test uses the unmodified
launcher `ResumableDownloadService`, `ReleaseAssetBundles`, `AssetBundleIndex`
and transactional `AssetBundleStore`, including index jobs, checksum-verified
downloads, manifest checks, immutable objects and installed-state generations.
It operates entirely in a fresh task-local store.

Current published pins reject the unpublished subset first. Separate tiny
projects then compile the same tracked launcher code against generated
future-release pins and matching model approval metadata. This simulates a future
certified release; it is not evidence that these fixtures are already approved
by the current production client. The policy, hash checks and installer are not
overridden, nor are preloaded JSON resources mutated at runtime.

The completed HTTP run installs all 11 original bundles, updates all 11 to each
smaller configuration and rolls all 11 back to the original approved archives.
Every phase verifies all 22 installed file hashes. A new store instance recovers
the same active generation and plans zero downloads after each phase. Catalog
snapshots reference the immutable installed objects in place.

The following failures leave the active generation unchanged:

- Cancel a deliberately paced HTTP transfer after receiving part of its body.
- A corrupted HTTP payload fails the actual downloader's checksum checks,
  including its clean checksum retry.
- An outer-checksum-valid archive with wrong manifest identity fails installation.
- A truncated archive fails before activation.
- An existing immutable version with a different checksum is rejected.

The original and update installation times are retained, but they are not a
fair speed comparison: the first store is empty; later phases validate an
already populated store. This is localhost, with warm filesystem caches and
other workspace tasks. No Internet-throughput or full-collection install-time
claim follows from those numbers. Historical immutable objects remain for
rollback during the fixture, so its total directory usage exceeds its active
model footprint.

## Real battle qualification

The existing `battle_3d_regional_stress_check.gd` and its inherited real-battle
tests run on the launcher's installed catalog. They use all 11 pairs, both
normal/shiny arrangements, attack/faint/replacement behavior, model-cache limits,
actor/viewport teardown and calibrated placement. Each configuration runs three
rounds: classic, stadium, classic, at 1280×720. Each prepared pair is observed for
120 frames in each arrangement. The existing aggregate and prepared p95 frame
limits remain **20 ms**. No reduced resolution, shorter observation, changed
shader quality or relaxed threshold is introduced.

The assigned slot's source registry is temporarily replaced with generated
future-release model hashes before each new game process starts. Its original
bytes are restored in `finally`; concurrent unexpected edits are preserved and
cause failure. Two focused tests cover exact restoration and that protection.
Other checkouts and player configuration are not modified. Frame gate results,
registry restoration receipts and original logs are retained under
`.tmp/lossless-launcher-v1/`.

All three configurations complete all rounds and gates. Prepared observations:

| Configuration | Classic p95 (5,280 frames) | Stadium p95 (2,640 frames) |
| --- | ---: | ---: |
| Original | 17.335 ms | 17.337 ms |
| 256 KiB / level 9 | 17.654 ms | 19.276 ms |
| 1 MiB / level 9 | 17.206 ms | 17.183 ms |

All nine aggregate round p95 values also remain below 20 ms. No draw forcing
was needed. All three registry restoration receipts match the same original
source SHA-256. The final 1 MiB run records a Linux child-process peak RSS of
2,199,150,592 bytes; the first two runs did not collect this measurement, so it
cannot establish a relative RAM saving or a catalog-wide memory budget.

For the wider qualification, prefer 256 KiB / level 9 first: **33.97%** smaller
complete ZIPs in this sample, with a smaller per-reader block than 1 MiB. The
larger configuration saves **35.14%**, another 4,252,826 bytes across these 11
pairs. This is a candidate selection for further qualification, not release
approval. Nine focused Python checks pass; Python compilation, UID sidecars and
whitespace checks also pass. Condensed report hashes and results are in
`tools/sprite_factory/native_bundle_validation_results.json`.

These are Linux/Godot 4.6.2 functional and frame-gate observations. They are not
cross-platform certification, filesystem-cold startup measurements, or complete
RSS/VRAM qualification. Other task previews may run during these observations;
passing the absolute gate does not establish a comparative speed improvement.
Existing battle scene texture UID warnings fall back to their text paths; no
unrelated scene or texture metadata is edited by this task.

## Additional rollout constraint: pose hash ledgers

The audit identifies six appearances whose client-side behavior is bound to
specific encoded-file hashes:

- Gliscor normal/shiny: `gliscor_flight.json`.
- Mega Garchomp normal/shiny: `mega_garchomp_standing.json`.
- Charmander normal/shiny: `charmander_breath.json`.

The current approved files match all six bindings. Reframing their identical
native streams at both block sizes changes the file SHA-256, so the existing
bindings match neither new representation. Updating only the central model
catalog would silently skip these pose/animation corrections. A later native
rollout must explicitly qualify and bind the new encoded hashes while retaining
compatibility with the old files where required. Changed raw rigs must never
inherit these corrections automatically. This task does not activate these six
new hashes or weaken the revision guards.

The transfer-only restoration approach avoids this issue because installed
files retain their original hashes; that alternative still lacks an actual
launcher decoder/fallback integration and is not qualified by this direct-native
bundle test.

## Remaining release work

Before a full native-container rollout, finish the strict renderer-reference
investigation, certify the entire chosen catalog and memory budget, regenerate
all affected hash bindings/qualification receipts, build the complete immutable
bundle/index set and check real platform update/rollback behavior. A same-size
catalog revision also needs explicit release-adapter pin handling; counting
asset IDs alone does not distinguish successive revisions with the same set.
Windows/macOS builds and publication are outside this local research task.

## Reproduction

```sh
python3 tools/sprite_factory/native_bundle_validation_fixture.py \
  --input /ABSOLUTE/PATH/TO/native-v1/report.json \
  --output .tmp/FRESH-FIXTURE
```

Through `ops/worktrees/slot-env slot-b --`, run:

```sh
python3 launcher/tests/run_native_compression_install_check.py \
  .tmp/FRESH-FIXTURE/fixture.json .tmp/FRESH-HTTP-RUN
python3 tools/sprite_factory/run_native_bundle_battle_validation.py \
  .tmp/FRESH-FIXTURE/fixture.json .tmp/FRESH-HTTP-RUN/installed \
  .tmp/FRESH-BATTLE-RUN --phase native-256k
```

Run the battle command sequentially for `original`, `native-256k` and `native-1m`
with separate fresh outputs. Keep games/editors closed for measurements. The
launcher runner creates isolated import caches and source-only links; it never
copies cache directories or userdata.
