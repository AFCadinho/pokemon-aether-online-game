# Lossless catalog preparation

Local task `lossless-model-catalog-preparation`, slot-a, 2026-10-06. This follows
the [launcher and battle sample qualification](lossless-model-launcher-validation.md).
It prepares a complete, unpublished candidate from current approved v10 inputs.
It does not replace either checked-in model registry, release index, launcher
pin, on-demand selection, player installation or published R2 object.

## Animation compatibility

Six encoded-file hashes guard client-side animation corrections: normal/shiny
Gliscor, Mega Garchomp and Charmander. Lossless reframing changes those hashes
even though the entire decoded resource stream remains byte-identical.

`lossless_model_revisions.json` records only the six measured 256 KiB / Zstd 9
encoded hashes, each bound to its original reviewed digest and decoded-stream
digest. Each animation helper first checks its existing original digest, then
the exact qualified alternate digest for that same identity and original.
An unknown identity, modified original rig, arbitrary future hash, and the
unqualified 1 MiB encoding remain rejected. Mega Garchomp Z is unaffected.
This does not grant model-catalog admission: `Reviewed.resolve` still rejects
the unpublished encoded revisions until a separately certified catalog is
integrated.

The real Forward+ check loads the six original and re-encoded native rigs,
applies their corresponding client animation libraries, and compares every
non-RESET action at fractions 0, 0.5 and 0.999. Both actor signatures and posed
mesh envelopes must match exactly. A second actor remains on idle while the
first changes pose; mutating an animation in one actor must not alter the other.
All six pass: **138 paired pose samples**, with no engine errors. This is a
skeleton/envelope check, not a pixel-image or full-catalog performance claim.

The pre-existing Gliscor and Mega Garchomp checks pass unchanged. The Charmander
test fixture now names the real reviewed `PRSFX- Ember.wav` sound instead of
the nonexistent old `Ember.wav` name. Its single cue, native launch marker and
seam thresholds are preserved and checked; no sound or move implementation
was changed to make that test pass.

## Preparing the whole collection

`prepare_native_compressed_catalog.py` reads original archives in place and
checks archive size/hash, manifest identity/version, appearance size/hash and
current model approval. For each RSCC file it preserves the complete decoded
byte stream while re-encoding to **256 KiB blocks / Zstd level 9**. It decodes
the new container and compares all raw bytes before packaging.

Uncompressed RSRC scenes remain unchanged; an individual container that would
not shrink also retains its original bytes. All auxiliary ZIP members are
preserved. Changed bundles receive the next immutable version and a new
content-addressed object key. Original archives are checked again after
preparation and kept in place. A complete draft index is written only after
every pair succeeds; per-pair receipts survive an incomplete run for diagnosis.

The draft model metadata retains original approved digests for a future
compatibility/rollback qualification, but is a standalone `.tmp` artifact.
Neither it nor the draft index is loaded by the current game or launcher.
The rollback index is semantically identical to v10 and points at the retained
original archives. No custom decoder or reconstructed original installation is
required for this selected format.

Artifacts are retained under `.tmp/lossless-catalog-v1/` in slot-a. The
`archives.json` map now locates all **1,200 approved source ZIPs**, including the
62 missing from the earlier map. The complete measured totals and receipt
digests are recorded in `native_catalog_preparation_results.json` after the run.

## Complete measured collection

| Complete collection | Approved original | Unpublished candidate |
| --- | ---: | ---: |
| Download ZIP bytes | 19,863,374,075 | 12,857,317,549 |
| Active native scene bytes | 19,862,546,766 | 12,856,054,300 |

All **1,200 pairs / 2,400 appearances** were verified. **1,198 pairs** receive
new compressed bundles; Mega Dragonite and Toucannon retain both uncompressed
RSRC scenes and their existing archives. No bundle grows. The measured download
saving is **7,006,056,526 bytes (35.27%)**, approximately **19.86 GB → 12.86 GB**.
This excludes the base game, arenas, temporary installation files and retained
old object generations. It is an active-collection size, not proof that an
existing installation immediately frees seven gigabytes.

All six corrected appearances in the full draft match their qualified encoded
and decoded-stream hashes. Original model hashes are retained in the standalone
candidate metadata for future rollback compatibility. The rollback JSON is a
normalized semantic snapshot, not byte-identical to the pinned v10 index. An
actual rollback under existing pins must use the retained original
`release/approved_3d_bundles_v10_index.json` bytes and descriptor.

The 64 MiB encoded-file cache budget newly permits normal and shiny together
for Floragato, Grimmsnarl and Maushold. Their unchanged decoded streams total
155,659,222, 164,113,660 and 290,412,286 bytes respectively; these are serialized
stream sizes, not measured RAM/VRAM usage. No individual scene crosses the
per-entry admission threshold. Marshadow is the largest decoded stream at
266,166,693 bytes. These measured cases focus the remaining memory qualification.

## Focused checks and reproduction

```sh
python3 -m unittest discover -s tools/sprite_factory -p 'test_native*probe.py'
python3 tools/sprite_factory/prepare_lossless_pose_fixture.py \
  --archives .tmp/lossless-catalog-v1/archives.json \
  --output .tmp/lossless-catalog-v1/NEW-POSE-FIXTURE
python3 tools/sprite_factory/prepare_native_compressed_catalog.py \
  --archives .tmp/lossless-catalog-v1/archives.json \
  --output .tmp/lossless-catalog-v1/NEW-FRESH-OUTPUT
```

Run Godot through `game/ops/worktrees/slot-env slot-a -- ...`. Existing checks:
`gliscor_flight_check.gd`, `mega_garchomp_standing_check.gd`, and
`charmander_breath_check.gd`. The new `lossless_model_pose_check.gd` requires
a real renderer, `NATIVE_POSE_FIXTURE` pointing to the verified six source/native
fixtures, and a fresh `STORAGE_COMPONENT_REPORT` output path. Do not run this
mesh-envelope check with the headless dummy renderer: it cannot register the
skinned mesh for baking. The initial rejected headless run is retained.

Twelve focused Python tests cover container integrity, unchanged RSRC handling,
transfer restoration, registry restoration, pair/auxiliary-file preservation,
rejection of unapproved or corrupt source revisions, and non-growing containers.

## Remaining release qualification

These candidates are **not production-approved**. The previously retained
strict pixel-image discrepancy also occurs with repeated original-source
captures; that investigation remains open, without relaxing pixel equality or
altering geometry/materials. Prior sample lifecycle/FPS checks do not close it.

A complete candidate needs full launcher/on-demand release-pin qualification,
including coexistence with v10 when both releases have the same required asset
IDs; hash-based correction checks; targeted runtime/memory measurements for
cache-admission changes; and supported desktop-platform loading checks.
The native file cache currently uses encoded size as an admission limit, so
smaller files do not imply a smaller decoded/GPU memory budget. Existing
immutable generations also retain old bytes for rollback; active model size is
not the same as total disk usage with all old versions retained.

Publishing, R2 upload and release promotion require separate authorization.
