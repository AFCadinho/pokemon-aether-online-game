# Additional lossless compression of the active v13 collection

On 12 October 2026 the user authorized a 20-pair compression experiment after
the v11 retirement. It ran in the existing slot-d after that slot became free.
This is an offline study; it changes no production asset, catalog or R2 object.

## Measured result

The selected v13 archives total **201,852,282 bytes**. The current complete v13
collection is 8,688,776,408 bytes. This deliberately varied sample is not a
random estimate of that full collection.

| Native block / Zstd level | Complete sample archives | Saving against current sample |
| --- | ---: | ---: |
| 256 KiB / 9, codec control | 201,852,142 B | 140 B |
| 256 KiB / 15 | 179,502,249 B | 11.07% |
| **256 KiB / 19** | **176,860,740 B** | **24,991,542 B / 12.38%** |
| 1 MiB / 9 | 199,263,656 B | 1.28% |
| 1 MiB / 15 | 193,303,111 B | 4.24% |
| 1 MiB / 19 | 171,489,778 B | 30,362,504 B / 15.04% |

Every one of the 20 pairs becomes smaller at 256 KiB / level 19. The sample
includes 17 geometry-sharing PCKs, two texture-only PCKs and one retained ZIP.
Their respective sizes change from 156,850,184 to 137,579,880 bytes, from
13,155,212 to 11,992,972 bytes, and from 31,846,886 to 27,287,888 bytes.
Hydreigon changes from 15,088,172 to 13,263,692 bytes at that setting.

The codec-control PCKs have their original complete sizes. The 140-byte control
difference is solely compact JSON formatting in the retained Marshadow ZIP;
it is included transparently in the complete archive totals. Source ZIP storage
methods are preserved. Candidates retain all resource members and decoded bytes.

## Exactness and engine checks

The compressor is libzstd 1.5.7; runtime validation uses Godot 4.6.2 on Linux.
The 506 native members undergo **3,036 exact decoded-byte comparisons** across
the six configurations. Original archives are size/SHA-256 checked before and
after measurement. The native streams retain all geometry, pixels, mipmaps,
animations, metadata, resource IDs and dependency paths exactly.

The original packs and the smallest complete sample at each block size are
checked in **60 separate Godot processes**, one process per pair/configuration.
Each configuration covers all 40 appearances. There are **360 uncached resource
load/instantiate calls**, exact stored-resource semantic comparisons and
**1,956 candidate/reference animation-state comparisons**. All succeed with
zero captured engine/script errors. Animation samples include every stored clip
at 0%, 50% and 99.9%, including RESET. Separate processes prevent the shared
virtual paths from resolving a candidate through baseline cached resources.

Seven focused Python tests pass: six-configuration roundtrips including an exact
block multiple, physical PCK rewriting, damaged/truncated pack rejection,
namespace/manifest/offset rejection, source-pin rejection, ZIP byte-binding
updates, and deterministic selection across all three formats. A Godot syntax
check and native PCK writer smoke check also pass. An initial smoke invocation
used a relative job path; Godot's project working directory made it unavailable.
The corrected absolute-path smoke passed; the full run always uses absolute paths.

## Loading and memory observations

| Configuration | Median load + instantiate | P95 | Maximum process peak RSS |
| --- | ---: | ---: | ---: |
| Current packs | 35.36 ms | 126.99 ms | 379,568,128 B |
| 256 KiB / 19 | 40.22 ms | 128.81 ms | 379,510,784 B |
| 1 MiB / 19 | 42.10 ms | 137.70 ms | 379,842,560 B |

The recommended candidate adds approximately 4.86 ms to the median in this
diagnostic; the larger blocks add approximately 6.74 ms. Maximum peak RSS is
similar. These are headless, warm-filesystem measurements with three uncached
loads per appearance, randomized process order and possible concurrent workspace
activity. RSS includes validation and semantic/motion checks. This is not a
rendered-battle, GPU/VRAM, FPS, filesystem-cold or cross-platform benchmark.

## Recommendation and rollout boundary

Measure the complete catalog at **256 KiB / level 19** next. It preserves the
current native block contract and captures most of the measured extra saving.
The production PCK validator accepts all 19 selected PCKs at this setting.
The 1 MiB candidate saves another 5,370,962 sample bytes but the production
validator deliberately rejects its block size. The native engine can load it;
admitting it would require a separately versioned game/launcher validator change.

No complete-catalog saving is inferred from these 20 pairs. No GPU comparisons,
Windows/macOS runtime tests or physical Android tests were run in this study.
The candidate PCKs intentionally retain source namespaces to preserve every
decoded byte and are loaded only in isolated processes. A rollout still requires
reviewed namespace/update behavior, fresh immutable payload and index hashes,
compiled game/launcher bindings, actual installer/consumer checks and an
authorized release. The current v13 pins cannot simply be overwritten in place.

## Selection and reproduction

Three geometry-sharing cases are fixed: Hydreigon and Tyranitar from the user's
production observations, and Quaquaval as the largest current PCK. Another 14
are sampled deterministically from size quartiles (4/3/3/4, seed 20261012).
Grimer and Lickilicky represent the texture-only cohort at its size quartiles;
Marshadow is the largest retained ZIP. The exact selection and all pack pins
are in [the condensed evidence](../release/v13_compression_probe.json).

Source implementation commit: `e8580e80e`. Complete local measurements,
per-member decoded hashes, candidate archives, engine job logs and independent
engine reports are retained under `.tmp/v13-compression-v1/` in slot-d. The
condensed evidence pins the full measurement, engine and selection reports by
SHA-256. Existing source archives were read in place; no source cache, userdata,
credentials or machine configuration was copied.

From the workspace, using an assigned slot and a fresh output directory:

```sh
ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tools/probe_v13_compression.py measure \
  --output .worktrees/SLOT/frontend/.tmp/FRESH-v13-compression-probe \
  --geometry-report .worktrees/slot-b/frontend/.tmp/shared-geometry-collection/full-v2/report.json \
  --texture-sources .worktrees/slot-b/frontend/.tmp/shared-model-readiness/full-v4/input.json \
  --zip-backup /home/adinho/Documents/PokeAetherBackups/r2-v11-20261012

ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tools/probe_v13_compression.py qualify \
  --output .worktrees/SLOT/frontend/.tmp/FRESH-v13-compression-probe
```

Focused Python checks run in the assigned frontend worktree:

```sh
python3 -m unittest discover -s tools -p test_probe_v13_compression.py -v
```
