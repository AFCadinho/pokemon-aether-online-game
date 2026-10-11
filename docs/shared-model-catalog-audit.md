# Full-catalog shared-texture storage audit

This is an offline audit of all 1,200 normal/shiny pairs in the approved v11
catalog. It derives local candidates and an explicitly unapproved draft index.
The public catalog, runtime profile bindings and disabled 16-pair pilot remain
unchanged. The audit is not release certification or player activation.

## Measured result

Godot 4.6.2 on Linux, libzstd 1.5.7. The corrected complete run takes 2,566.18
seconds (42.77 minutes), with four independent batches and two compression
workers per batch. Every one of the 1,200 source archives and all 2,400 source
appearance/decoded-stream bindings match their approvals.

| Complete catalog | Current v11 | Selected hybrid | Saving |
| --- | ---: | ---: | ---: |
| Download | 12,857,317,549 B | 9,833,429,671 B | 3,023,887,878 B / 23.52% |
| Installed files | 12,856,911,949 B | 9,840,387,851 B | 3,016,524,098 B / 23.46% |

The selected catalog uses **1,084 shared PCK pairs**. **115 qualified pairs**
stay on v11 because sharing does not save both download and installed bytes.
**Marshadow** also stays on v11: its 179 unique texture files plus two scenes
exceed the validator's existing 127-payload-member limit. That limit is unchanged;
the audit does not treat its uninstalled generated pack as a qualified saving.
Its codec and serializer controls pass, but its shared pack is not admitted or
loaded. All 116 retained entries in the draft are exactly their original entries.

For the **1,199 physically qualified pairs**, the serializer controls total
12,734,041,288 B and the shared packs total 9,802,253,620 B: **23.02% less transfer
from sharing at the same exporter and codec**. This comparison includes the 115
qualified pairs that the final selection conservatively leaves on v11. It is a
matched-subset comparison, separate from the complete selected catalog above.
Generated-pack and installed-qualified-subset totals have different scopes;
neither replaces the full selected totals. The committed receipt explicitly
labels each scope.

There are **7,198 exact independently loaded native scene comparisons**:
2,400 codec controls, 2,400 serializer controls and 2,398 shared scenes. The
qualified shared packs demonstrate 8,835 texture objects shared across normal
and shiny. Shiny retains its texture count after normal leaves, and every
collected texture weak reference expires after both scenes release ownership.
The corrected run has no exporter/engine failure verdicts; Marshadow is a
controlled format-budget rejection.

The separate reconciliation checks every approved binding, every retained
qualified pack SHA-256/length, the complete draft, all totals and seven invalid
evidence/checkpoint cases. Additional focused checks confirm that image,
material and animation mutations change their signatures, that the two RSRC
pairs pass 12 fresh physical scene comparisons, and that an exporter assertion's
empty receipt cannot count as a successful pair.

## Measurement method

The approved ZIPs are read in place from the retained lossless preparation.
Every archive matches its approved size and SHA-256 before and after use. Both
native scenes match their approved appearance hashes and decoded-stream
bindings. The original archive manifest and both native scene lengths form the
installed baseline; ZIP lengths form the download baseline.
These are file-length totals, not filesystem allocation blocks, temporary update
headroom, retained old cache generations, RAM or VRAM estimates.

Each pair has three real standalone PCK measurements, with the same Zstandard
level 9 and 262,144-byte block size:

1. **Codec control:** already-compressed RSCC sources retain their complete
   decoded native streams without reexport or sharing. The four uncompressed
   RSRC sources first use the verified nonsharing serializer; their resource
   offsets cannot survive simply removing the RSRC magic and adding an RSCC
   wrapper. Those four controls include serialization and compression effects.
2. **Serializer control:** scenes saved by the same exporter before sharing.
   This separates exporter layout changes from sharing.
3. **Shared candidate:** two independent scenes and one copy of every strictly
   matching shareable `ImageTexture`. A texture's full storage metadata, name,
   locality flag, image format, dimensions, mipmaps and image bytes must agree.
   Matching pixels alone are insufficient. Meshes, skeletons, materials and
   animation libraries are not deduplicated by this experiment.

Godot's [binary resource writer](https://github.com/godotengine/godot/blob/4.6/core/io/resource_format_binary.cpp)
records resource positions in its internal offset table and writes the initial
RSRC magic only for uncompressed files. The two affected pairs are Mega
Dragonite and Toucannon. An initial audit attempt exposed the invalid direct
conversion in its codec control and was stopped. The corrected controls pass
12 independently loaded scene comparisons for those two pairs. That attempt's
logs, receipts and exact tool snapshot remain under `full-v1`; its results are
not included in the complete corrected run. Pure sharing comparisons use the
serializer control for every pair, including these four scenes.

The actual production-format validator inspects each physical PCK and mounts
only its checked namespace. A separate fresh headless process loads all three
versions from their packs and compares both complete native resource graphs to
the originals. It checks authored images, geometry, animation values, material
properties, shader code, scene nodes and connections. No live producer objects
or producer UID database can satisfy these loads. Godot's
[ordinary ignore cache mode](https://docs.godotengine.org/en/4.6/classes/class_resourceloader.html#class-resourceloader-enum-cachemode)
still reuses external dependencies, so producer and verifier have separate
minimal projects and caches.

The shared candidate is installed through the real pair installer. Its cost is
the physical PCK plus the actual installed JSON sidecar; scenes/textures are not
extracted into another copy. Texture object sharing, shiny ownership after normal
leaves and expiry of all collected texture weak references are checked. Zero
texture scenes are valid. Headless checks use CPU image data, not GPU readback.

A pair is selected only if all three physical controls qualify **and both its
download and installed costs decrease**. Other pairs retain their original v11
ZIP/native scene costs in the full-catalog selected totals. Source checksum or
binding errors abort the run; data-dependent exporter/validator failures are
recorded as requiring review and cannot be selected. Totals of measured shared
candidates alone must not stand in for the complete selected catalog when a
pair could not be measured.

## Reproduction and retained evidence

Run from `game` in an assigned frontend slot, through its isolated environment:

```sh
ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tools/audit_shared_model_catalog.py \
  --source-report /absolute/retained/v11/prepared/report.json \
  --output /absolute/assigned/frontend/.tmp/FRESH-CATALOG-AUDIT
```

The source report supplies existing approved archive locations. It is not a
cache seed. Only derived native assets and tracked diagnostic source code are
written into task-owned directories; caches, configuration and userdata from
other worktrees are never copied. Two independent batches are the default;
`--batch-workers 4` is the recorded corrected run's explicit choice after checking
available host memory. At most two stateless compression workers per batch bound
that run's compression workload. Each Godot role has
an explicit log file and separate task-owned project/runtime directories.

`--limit N` explicitly marks a subset run. `--resume` requires identical pinned
tools, source bindings, source report, Godot, codec and batching options. It
rechecks completed source archive and retained candidate checksums. Interrupted
attempt directories and logs remain; only the completed batch's explicitly
owned intermediate model payloads are removed after its verifier exits. Source
archives, retained candidates, receipts, logs, projects and caches are retained.

The complete local run is retained under
`.worktrees/slot-b/frontend/.tmp/shared-model-catalog/full-v2`. It contains
`configuration.json`, per-batch logs and receipts, `receipts.jsonl`, `report.json`,
qualified candidate packs and metadata, and `draft-index.json`. The draft uses
runtime contract 2 and preserves legacy entries wherever sharing is not selected.
Its prototype/unapproved markers do not authorize runtime admission or publication.

The committed receipt is
`tools/sprite_factory/shared_model_catalog_results.json`. Run the focused
independent reconciliation from the assigned slot:

```sh
ops/worktrees/slot-env SLOT -- python3 .worktrees/SLOT/frontend/tests/shared_model_catalog_audit_check.py \
  --audit /absolute/assigned/frontend/.tmp/shared-model-catalog/full-v2
```

It reconciles every pair with the approved source bindings, recomputes selection
and totals, hashes every retained qualified candidate, checks exact draft
fallbacks and rejects corrupt/duplicate resumed checkpoints and overstated
evidence. Omitting `--audit` checks the committed receipt without requiring the
retained multi-gigabyte packs.

## Remaining qualification

Complete native graph equality is evidence of preserved authored values; this
headless audit does not certify every rendered frame or every runtime actor.
GPU-dependent shader defaults and dynamic rendering still require the actual
renderer; dummy-renderer fingerprints alone cannot qualify those behaviors.
The prior [16-pair render checks](shared-model-pilot.md) cover that cohort only.
Every newly serialized candidate needs reviewed hash bindings before it can
inherit placement, motion, attack routing and the original conservative cache
admission cost. Gliscor, Mega Garchomp and Charmander additionally have existing
hash-bound animation corrections for both appearances that must remain active.

The subsequent [local catalog qualification](shared-model-catalog-qualification.md)
adds candidate bindings and the full-catalog renderer/actor workflow, including
unchanged-source diagnostics for pixel variability. Whole-catalog metadata
limits, larger distinct-pack mount budgets, native Windows/macOS
install/update/repair/cleanup and physical Android runtime qualification remain.
The [Linux session/recovery checks](shared-model-stress.md)
qualify the 16-pair pilot, not all new candidates. Full paired certification,
publication and release promotion retain their separate authorization requirements.
