# Full v13 lossless compression audit

This follows the [20-pair experiment](v13-lossless-compression-probe.md).
The authorized scope is an offline measurement of all 1,200 approved v13 model
pairs at the existing 256 KiB block size with Zstandard level 19. R2 and the
production catalogs are unchanged.

## Measured result

All **1,200 model pairs become smaller**. Complete archive size falls from
**8,688,776,408 to 7,659,148,338 bytes**, saving **1,029,628,070 bytes (11.85%)**.
In decimal units this is **8.69 GB → 7.66 GB**, an additional **1.03 GB** beyond
the existing compression and normal/shiny sharing. This measures the actual
whole collection, not an extrapolation from the earlier sample. It is a proposed
model-archive footprint; the live R2 storage has not changed in this task.

| Current pack type | Pairs | Original bytes | Candidate bytes | Saved |
| --- | ---: | ---: | ---: | ---: |
| Geometry-sharing PCK | 1,031 | 7,737,212,420 | 6,791,848,708 | 12.22% |
| Texture-sharing PCK | 114 | 811,086,316 | 740,600,588 | 8.69% |
| Retained ZIP | 55 | 140,477,672 | 126,699,042 | 9.81% |
| **Total** | **1,200** | **8,688,776,408** | **7,659,148,338** | **11.85%** |

Hydreigon changes from 15,088,172 to 13,263,692 bytes; base Tyranitar changes
from 13,694,860 to 11,968,108 bytes. Repaired Mega Hawlucha changes from
6,084,432 to 5,570,160 bytes. Both normal and shiny remain available in each pair.

Every one of the **29,671 native resource members** passes exact decoded-byte
comparison, including independent decoding after the candidate archive is
persisted. Their total decoded content is **47,208,075,238 bytes**. No candidate
needs to be discarded for failing to save space. The full measurement completed
in 3,450.60 seconds with libzstd 1.5.7 and four workers.

## Method and source coverage

Sources are the exact approved v13 archives, checked by complete size and SHA-256
before processing. They include 1,031 geometry-sharing PCKs (7,737,212,420 bytes),
114 texture-sharing PCKs (811,086,316 bytes), and the remaining 55 ZIPs
(140,477,672 bytes). Mega Hawlucha uses the repaired current v5 geometry pack
`0fe6d6b6abf759160220b4653bcaf3b4ea87ca37caf9062dcb2917868858b761`,
not the superseded pack in the original geometry experiment.

All native resources are recompressed without reimporting, resaving, quantizing,
resizing or dropping model content. After writing each candidate, the tool
independently reopens the complete archive, verifies its hashes and membership,
decodes every native member and compares its bytes with the original. It also
rejects metadata changes beyond compressed-byte sizes and hashes. Only complete
archives strictly smaller than their originals are selected for the proposed
total; the others retain their current approved source.

The run uses four bounded workers. Each completed pair has a resumable
checkpoint; resumption verifies the persisted candidate again and refuses
changed source, tool or codec bindings. The source archives are read in place.
No credentials, caches, installations or machine configuration are copied.

## Engine checks and scope

**All 1,200 isolated processes pass** with zero captured engine/script errors.
All **2,400 appearances load and instantiate** successfully. All **1,145 PCKs**
pass both the current production physical validator and the checked mount and
dependency validation. The remaining 55 ZIP pairs also load both appearances.
The runtime is Godot 4.6.2 on Linux.

Eleven focused Python tests pass. They cover compression roundtrips, archive
structure, source pinning, source selection, ZIP metadata, persisted output,
resumption without recompression, corrupt candidate rejection, changed decoded
evidence/configuration rejection and altered asset metadata rejection. Actual
Castform PCK and Metapod ZIP smoke checks also pass before the collection run.

Each candidate is loaded in a fresh Godot process on Linux. For PCKs, the test
uses the production physical validator and checked mount/dependency route.
Both appearances are loaded with the resource cache bypassed and instantiated.
The fresh process isolates the candidate from previously mounted source packs.
ZIP scenes are extracted as local test inputs and their runtime hashes are
checked before loading.

These full-collection checks cover native decoding, admission and instantiation.
They do not repeat the earlier 20-pair semantic/animation sampling, and are not
GPU rendering, FPS, cold-filesystem performance or Windows/macOS/Android tests.
The full decoded-byte equality proof covers the stored geometry, pixel data,
animations, metadata, identifiers and dependency paths without approximation.

## Reproduction

Run in the assigned slot from the workspace control directory:

```sh
ops/worktrees/slot-env slot-d -- python3 .worktrees/slot-d/frontend/tools/audit_v13_compression.py measure \
  --output .worktrees/slot-d/frontend/.tmp/v13-full-compression-v1 \
  --geometry-report .worktrees/slot-b/frontend/.tmp/shared-geometry-collection/full-v2/report.json \
  --texture-sources .worktrees/slot-b/frontend/.tmp/shared-model-readiness/full-v4/input.json \
  --zip-backup /home/adinho/Documents/PokeAetherBackups/r2-v11-20261012 \
  --replacement-pack .worktrees/slot-c/frontend/.tmp/repaired-model-attachments/shared-packs/geometry/v5-0fe6d6b6abf759160220b4653bcaf3b4ea87ca37caf9062dcb2917868858b761.pck \
  --workers 4

ops/worktrees/slot-env slot-d -- python3 .worktrees/slot-d/frontend/tools/audit_v13_compression.py admit \
  --output .worktrees/slot-d/frontend/.tmp/v13-full-compression-v1 --workers 2
```

Both commands resume their completed checks when their pinned inputs match.
Use a fresh output for changed tools, source metadata or codec versions.
Focused Python checks in the frontend slot:

```sh
python3 -m unittest discover -s tools -p 'test_*v13_compression.py' -v
```

## Rollout boundary

These are experimental files, with original virtual resource namespaces retained
so every decoded byte remains identical. The game deliberately rejects mounting
a second physical pack under a namespace already owned by another hash
(`model_pair_pack.gd`, `mount_checked`). A future rollout must therefore verify
upgrade/restart behavior and old-cache handling, and use fresh immutable payload
keys, approved index hashes and coordinated game/launcher bindings. Replacing
objects underneath the existing v13 pins is not an activation path.

## Evidence and recommendation

The [condensed receipt](../release/v13_full_compression_audit.json) records all
1,200 source/candidate pins, selected sizes, cohort totals, decoded evidence and
engine coverage. It SHA-256 pins the complete measurement, input binding, engine
binding and engine reports. The full per-member evidence, candidate files and
engine logs remain under `.tmp/v13-full-compression-v1/` in slot-d. Candidate
archive hashes were checked again when producing the condensed receipt.

Measurement implementation: `2acf3ed8a`. Production mount-path checks:
`c55823757`. The receipt also binds the actual source file hashes, compressor
version and engine version. The complete measurement takes 57.51 minutes on
this Linux machine; timing is diagnostic and can vary with other workspace work.

Proceed next with packaging and qualifying this 256 KiB / level 19 collection
for a new immutable release. The 1.03 GB whole-collection saving and exact stored
content are now established. Before activating it, test old-to-new installation,
restart/cache behavior and coordinated game/launcher index acceptance so the
previous pinned-manifest update issue cannot recur. Publication and R2 cleanup
remain separate authorized actions. This audit changes no runtime behavior and
therefore requires no player-facing changelog entry.
