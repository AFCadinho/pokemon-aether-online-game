# Shared-model catalog: local bindings and renderer qualification

The local test catalog contains the 1,084 shared pairs selected by the
[complete storage audit](shared-model-catalog-audit.md), plus the exact original
116 v11 entries. It is explicitly a prototype and is not a published release.
The existing 16-pair pilot has its own unchanged opt-in and index.

`POKEAETHER_SHARED_MODEL_CATALOG_TEST=1` enables the new bindings in a debug
build. The game and launcher carry identical catalog metadata and binding code.
The full metadata is loaded lazily only for this option. Without it, none of
these new candidate hashes can inherit reviewed model profiles. The lookup is
indexed by identity and scene hash, initialized under mutexes for the worker
and main-thread callers, and returns independent dictionary copies.

## Recorded Linux result

The complete `full-v3` run on Godot 4.6.2 / Mobile Vulkan / NVIDIA GeForce RTX
3070 Laptop GPU tested all 1,084 selected pairs (2,168 appearances) in about
84.9 minutes. The [compact evidence receipt](../tools/shared_model_qualification_results.json)
pins the tested source commit, inputs, retained batch reports and additional
source controls. The retained run is under the assigned slot's
`.tmp/shared-model-qualification/full-v3`.

- 24,784 candidate frames, with 74,352 original/repeat/candidate PNGs.
- 24,542 frames match the first original; 223 more match the repeat original.
- 19 frames on six appearances require additional review. Exact unchanged-source
  witnesses explain Armarouge, both Regieleki appearances and Alolan Sandslash.
- Shiny Greninja has five unresolved frames with one to four differing pixels.
  Normal Inkay has two differing pixels in its front idle frame, with a
  maximum channel difference of one. Both complete pairs retain v11; no pixel error is tolerated or rounded away.
- All 2,168 actual battle setups and 8,672 Pokédex/summary previews pass their
  animation, pose, placement, routing, camera and cache checks.

There are 2,166 appearances with exact source witnesses, but only 1,082 complete
pairs qualify. The isolated passing counterparts of Greninja and Inkay do not
make their packs eligible. The retained qualified index therefore contains
1,082 shared pairs and 118 original v11 entries, preserving the two extra
fallbacks as well as the 116 existing storage-audit exclusions.

| Bytes | Original v11 collection | Qualified selection | Saved |
| --- | ---: | ---: | ---: |
| Download | 12,857,317,549 | 9,838,055,989 | 3,019,261,560 (23.48%) |
| Installed | 12,856,911,949 | 9,844,999,677 | 3,011,912,272 (23.43%) |

These are measured container/install totals, not RAM or VRAM estimates. The
qualified index is a local draft, with `production_approved: false`; it has not
been published or activated for players. The full debug test catalog retains
all candidates, including held candidates, for reproducible diagnostics.

## Existing behavior retained

All 2,168 candidate appearances resolve to their own approved source profiles.
The focused binding check compares the complete profiles, including placement,
grounding, motion, action timing, attack-family routing and original conservative
cache cost. Only the grounding/motion hash changes to the candidate revision.
Local catalog fields cannot supply or alter this inheritance.

The exact source mapping also reaches the client animation corrections for
Gliscor, Mega Garchomp and Charmander, and the authored visibility correction
for Roaring Moon. Both normal and shiny are checked: eight correction bindings
in total. An unknown identity, unknown hash, altered source mapping or inactive
debug option cannot grant those corrections to a candidate.

The existing two-entry / 64 MiB cache admission policy stays in effect. Its
cost is an admission bound based on source files and dependencies, not a
measurement of decoded RAM or VRAM.

## Renderer and actor method

`qualify_shared_model_catalog.py` reads the retained approved ZIPs and audited
PCKs in place, verifies their hashes and lengths, and derives native source
scenes inside the assigned slot. No previous checkout's caches or configuration
are transferred. Each batch owns its runtime directories, inputs, logs, images
and receipts. The checked-in scripts/data and exact Godot version are frozen
for a run. Completed batches can be resumed only with those same inputs and
intact original source/candidate evidence.

The actual Mobile Vulkan renderer captures 512 × 512 images with MSAA4, neutral
lighting and the production material response. Source-derived camera framing is
reused exactly. Every appearance has front/back captures of idle, physical and
special attack, sleep and faint; existing second physical/special attacks add
their own views. Legacy models without `faint_loop` use the end of the existing
`faint_start`, as the presenter does. Effects have the same sampled time: the
probe sets the shader's existing `review_time` uniform, including older
materials without effect metadata and materials reached through `next_pass`.

The source, an independently loaded repeat source and the candidate are all
captured. Corrected animation libraries and skeletal poses must agree exactly.
PNG pixels are decoded and checked against their recorded hashes. A candidate
frame passes the primary comparison only if all pixels equal one of its two
unchanged controls. There is no threshold for a small number of pixels, channel
error, percentage similarity or resized image comparison.

A separate real presenter process loads both revisions through their actual
threaded loaders and integrity checks. For every pair it exercises two battles
and eight previews: source and candidate, normal and shiny, Pokédex and summary.
Every available animation is sampled at 0, 0.5 and 0.999 of its duration.
Animation libraries, skeleton poses, battle placement/motion/routing, preview
scale and summary camera framing must agree. Normal/shiny swaps, one actor
leaving and the cache bounds are also checked. The candidate must actually be
the checked shared pack revision; a fallback to the source cannot pass.

Engine/script errors abort a batch. Interrupted attempts and their logs remain
separate. Successful receipts are not synthesized from an assertion's empty
return value. Batches use separate processes; this is catalog coverage, not a
long-session mount-memory qualification.

## Reference variability

The initial full attempt stopped after 168 completed pairs when Centiskorch
exposed a fixture omission: its older fire shader has `review_time` but lacks
the newer metadata marker used by the earlier 16-pair probe. Its unchanged
source controls were therefore captured at different fire-loop times. The
corrected probe inspects the actual shader uniform; a targeted check passes
normal and shiny Centiskorch, Ponyta and Rapidash exactly. That attempt and its
pre-fix script remain under `full-v1`. A second attempt stopped after 216 pairs
when review found a misplaced lookup mutex. The lock now belongs to the lookup
function; a four-thread cold-lookup test covers all 2,168 bindings and checks
that returned copies cannot alter trusted data. The final run started fresh
under `full-v3`; neither earlier attempt counts toward its evidence.

The primary verdict always remains in the evidence, including held frames.
`check_shared_model_reference_variation.py` can diagnose a hold with exactly
16 more captures of its unchanged, hash-verified source. It never rerenders or
replaces the held candidate. The same camera, animation library, skeletal
poses, corrections and frame hashes are independently checked.

For example, the first full run found a one-pixel difference in Armarouge's
front second physical attack. Nine of 16 additional unchanged-source captures
reproduced that exact candidate image. The two distinct pixel hashes therefore
already occur without changing the model. This is evidence of reference render
variability, not permission to accept an approximate image. A held frame that
cannot be reproduced exactly stays unresolved.

## Focused checks and reproduction

Run from `game` in the assigned frontend slot:

```sh
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend \
  --script res://tests/shared_model_catalog_binding_check.gd
python3 .worktrees/SLOT/frontend/tests/shared_model_catalog_metadata_check.py
python3 .worktrees/SLOT/frontend/tests/shared_model_qualification_comparator_check.py
ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tools/qualify_shared_model_catalog.py \
  --audit /absolute/retained/shared-model-catalog/full-v2 \
  --source-report /absolute/retained/lossless-catalog-v1/prepared/report.json \
  --output /absolute/assigned/frontend/.tmp/FRESH-QUALIFICATION \
  --batch-size 12 --workers 2
```

`--species` is an explicitly marked subset. The default is every selected pair.
`--resume` verifies completed sources, packs and rendered images; it does not
permit a changed proof recipe. The full run retains each batch's `input.json`,
all original/repeat/candidate PNGs, renderer receipt, actor receipt and logs.
`shared_model_qualification_evidence_check.py --run PATH` independently reads
all retained PNGs, hashes the physical packs and source scenes, reconciles the
complete selected identity set and counts the actual battle/preview results.

Run the reference diagnostic alongside the qualification, then collect only
after both processes finish:

```sh
ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tools/check_shared_model_reference_variation.py \
  --run /absolute/assigned/frontend/.tmp/FRESH-QUALIFICATION \
  --output /absolute/assigned/frontend/.tmp/FRESH-QUALIFICATION/reference-variation --follow
ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tools/collect_shared_model_qualification.py \
  --run /absolute/assigned/frontend/.tmp/FRESH-QUALIFICATION
python3 .worktrees/SLOT/frontend/tests/shared_model_qualification_evidence_check.py
```

The collector physically verifies the retained evidence before creating
`tools/shared_model_qualification_results.json`; it refuses to overwrite an
existing receipt. Commit the implementation before collection: the collector
checks every frozen input against that commit's Git blobs and records it as
`qualified_source_commit`. The default evidence check validates those historical
blobs, so unrelated later changes do not invalidate the provenance of a past
run. It does not certify changed runtime code automatically.

That compact record pins the full input set and each batch's
source fixture, render report and actor receipt, plus any additional unchanged
source captures. Raw primary verdicts remain intact. `qualified_pairs` requires
both appearances to pass the primary comparison or have an exact unchanged
source witness for every held frame.

Collection also writes a retained `qualified-index.json`. A pair is shared
only when both normal and shiny qualify; otherwise its complete original v11
entry is preserved exactly as JSON data. The receipt's `selection` records
the exact shared asset IDs, additional original pairs, and recalculated download
and installed totals. The full debug test catalog deliberately keeps all 1,084
storage candidates for reproducibility; it is not an activation approval for a
candidate with an unresolved render hold.

The metadata check also rejects changed source/candidate bindings, a reduced
cache charge, a changed legacy fallback and a duplicate pair. The comparator
check rejects a one-channel change in one pixel, forged PNG hashes, missing
frames, an invented pose and changed skeletal evidence. The earlier 16-pair
physical installer check remains a regression check for the original pilot.

## Remaining activation work

This renderer run used bounded per-pair runtime catalogs. The subsequent
[collection readiness work](shared-model-final-readiness.md) adds a separate
qualified debug option containing 1,082 shared pairs and 118 exact v11 originals.
Its compact index is 236,908 bytes, within the existing 1 MiB descriptor limit;
installed metadata also retains the existing 8 MiB limits. See that record for
complete installation, update, repair and long-session evidence. Neither debug
option activates a launcher release.

Native Windows/macOS installation, update, repair and cleanup, and physical
Android runtime checks remain: only the Linux host was available for the
follow-up. Local Linux checks do not certify those platforms, total memory,
FPS or every possible frame. Full paired certification, publication and release
promotion retain their separate authorization requirements.
