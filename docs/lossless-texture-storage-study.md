# Lossless texture storage study of the prepared v15 collection

The baseline is the prepared v15 collection: 1,420 pairs / 2,840 appearances,
8,795,326,138 download bytes. It is not a claim that v15 has been activated on
R2. External texture members alone occupy 6,677,897,476 bytes. Reaching less than
7,000,000,000 bytes requires another 1,795,326,139-byte saving, or approximately
26.9% of those texture bytes if textures alone supply the entire reduction.

This investigation changes no client loader, compiled catalog, model approval,
platform manifest, R2 object or installed player data. Candidate packs are
private experiments and their `production_approved` flag remains false.

## Sample and measurement

Twenty PCK pairs are selected deterministically (seed 20261014): 16 schema-2
geometry-sharing packs and four schema-1 texture-sharing packs. Fixed controls
include Hydreigon, Tyranitar, Quaquaval, Alcremie Caramel Swirl, Masterpiece
Sinistcha, Rapid Strike Urshifu and Landorus Therian. Remaining controls cover
size quartiles in both cohorts. This is a deliberately varied diagnostic sample,
not a statistically unbiased whole-catalog estimate. The 55 ZIP pairs are
excluded, including their embedded textures.

All source archives are read in place and checked against their v15 SHA-256 and
size. Godot's existing physical pack inspector and checked mount verify the
bounded archive and flat dependency graph. All external textures are inspected,
not just visible albedo maps or the largest image in each model.

For each texture, existing stored mip levels are sliced at their actual byte
offsets. No mipmaps are generated or regenerated. PNG and lossless WebP decode
back to the exact original width, height, pixel format and pixel bytes at every
level. Invisible RGB and near-opaque alpha also count. Non-8-bit or compressed
source formats and non-native texture size overrides are held unchanged.

Candidate textures use Godot's existing `PortableCompressedTexture2D` native
container. The PNG body includes Godot's four-byte `PNG ` prefix. Each image
level is independently encoded; the header preserves the original pixel format
and mip count. Resource names, locality, metadata and dimensions must match.
Textures are saved, reopened and compared before packaging.

Every candidate native resource uses the same outer RSCC framing as the
baseline: Zstandard level 19 / 256 KiB. Its decoded native stream is checked
byte-for-byte against the newly derived native resource. Complete PCKs are
written and independently reopened, with member SHA-256/MD5/bounds and manifest
checks. All non-texture native members, including both scenes, geometry, skins
and animations, remain exactly equal to their original compressed bytes.

Three complete candidate sets compare PNG, Godot WebP and per-texture selection
among both codecs and the original. The whole original archive remains selected
if the complete candidate is larger. Savings include native serialization,
manifest and archive table/alignment costs.

Source and candidate use the same virtual paths and different immutable bundle
versions, but only in separate fresh processes. Cold verification loads both
appearances using the actual Compatibility renderer. The full stored scene graph
must match under a fingerprint normalizing only texture storage class; every
texture's decoded data, size, name, locality and metadata remains in that key.
Every stored animation, including RESET, is sampled at 0%, 50% and 99.9% and
compared against its original node/bone/blendshape poses.

## Measured first codec comparison

All 20 pairs pass their cold checks, covering 382 external texture resources,
1,262 stored image levels and 1,014 sampled animation states.

| Complete sample archives | Bytes | Saving |
| --- | ---: | ---: |
| Original v15 packs | 163,388,228 | — |
| PNG candidates | 176,239,108 | -12,850,880 |
| Godot WebP candidates, retaining rejected originals | 136,264,772 | 27,123,456 |
| Best per texture, retaining original where smaller | 136,250,276 | 27,137,952 / 16.61% |

The original texture members account for 120,962,190 sample bytes. The saving is
approximately 22.4% of those texture bytes. It is not a measured reduction of the
complete 8.80 GB collection. PNG alone increases this sample's storage.

## Near-opaque alpha finding and strict encoder

Forty-five Godot WebP texture candidates fail the exact decoded-byte check and
are excluded from that codec's replacement set. The focused Alcremie diagnostic
finds a concrete cause: one 512×512 texture contains 262,100 pixels with alpha
255 and 44 with alpha 254. Godot's WebP path converts it to RGB; decoding back to
RGBA changes those 44 alpha bytes to 255 while RGB remains unchanged. Pillow
independently decodes both files and reproduces the exact source and changed
SHA-256 values. No tolerance is accepted.

This behavior follows the interaction of Godot's
[alpha detection threshold](https://github.com/godotengine/godot/blob/4.6/core/io/image.cpp)
and [WebP source-format selection](https://github.com/godotengine/godot/blob/4.6/modules/webp/webp_common.cpp).
It is not evidence that the mathematical lossless WebP format requires losing
alpha precision.

The additional strict encoder reads each preserved native PNG mip, decodes it
independently with Pillow and checks the original byte hash. It encodes WebP with
`lossless=True`, `exact=True`, method 6 and quality/effort 100, explicitly retaining
RGBA when needed. A second independent decode must reproduce every source byte.
Godot then loads the encoded mip chain, checks it against the original texture,
saves/reopens the native resource, and cold-loads the complete candidate pack.
The best set includes the prior PNG/WebP/original choice so it cannot force a
larger or inexact texture. The Alcremie strict pilot reduces its complete pack
from 5,607,072 to 4,259,968 bytes (24.02%) while retaining all exact source data.

The complete strict follow-up passes all 20 pairs. Selecting the smallest exact
native texture from the original, PNG, Godot WebP and strict WebP reduces their
complete archives from **163,388,228 to 133,220,836 bytes**: **30,167,392 bytes /
18.46%**. It saves another 3,029,440 bytes compared with the guarded Godot codec
selection. All 382 texture states and both appearances of every pair match their
originals after a fresh checked pack mount, including 1,014 sampled animation
states. All 1,262 measured stored image levels retain their exact source bytes.

This corresponds to approximately 24.9% of the sample's original texture-member
bytes. Textures alone would need about 26.9% saving across the complete collection
to reach less than 7 GB. The sample therefore supports a worthwhile full-catalog
measurement and possible combination with additional sharing, but establishes
neither a complete-collection percentage nor a guaranteed sub-7-GB release.

## Verification and rollout limits

The focused native test covers all six uncompressed 8-bit image formats,
deliberately authored mip chains and colour under zero alpha. It rejects changed
pixels and regenerated mips, and holds a non-native size override. Python checks
cover sample coverage, missing controls, corrupt complete packs, alpha 254,
invisible RGB, authored mip hashes and mismatched mip dimensions.

The runtime is Linux Godot 4.6.2 with real Compatibility graphics and Dummy audio.
Two bounded native workers resume independently rehashed checkpoints under one
temporary project lock. Initial parse/container failures and interrupted runs
are retained and grant no qualification. Signal handling restores the tracked
project file for a terminated serial run; the successful run restores it exactly
after both workers finish. No caches/configuration/user data are copied.

Exact texture bytes and unchanged other native streams support lossless storage,
but this is not a production-format qualification or a full battle/preview GPU
frame comparison. A rollout needs fresh namespaces and rewritten scene hashes:
unchanged scene hashes cannot distinguish old and new packs in the current
compiled lookup. Portable texture buffer retention, deep/local duplication,
normal/shiny ownership, cache eviction, peak memory/load time, actual presenters,
installation/restart/rollback and platform behavior also require qualification.
The experiment does not promise reduced RAM/VRAM; decoded textures retain their
original dimensions and image data.

A focused duplication diagnostic finds an actual additional loader requirement:
by default, all 20 portable textures in the strict Alcremie pilot load their
pixels correctly but discard their compressed buffer. Deep-copying the texture
then fails (0/20 exact duplicates, with captured native errors). In a separate
fresh process, enabling `PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)`
before loading retains all 20 buffers and gives 20/20 exact duplicate images with
no captured errors. The failed default diagnostic grants no lifecycle approval.
This establishes a possible remedy, not a production loader change or a memory
qualification; retained CPU buffers and full scene/actor lifetimes need testing.

Before promising less than 7 GB, measure the complete texture catalog. Different
models have different texture proportions and compression gains. Cross-form
sharing and the remaining geometry-sharing holds may add savings, but their
overlap with the new texture encoding must be measured rather than adding old
member-byte indicators to this sample's saving.

## Reproduction

Use an assigned slot and run Python through `ops/worktrees/slot-env`. Source
paths point to retained v15 archives; output paths must be fresh.

```sh
python3 tools/study_lossless_texture_storage.py \
  --sources /absolute/retained/v15/sources.json \
  --output .tmp/lossless-texture-storage-full
python3 tools/resume_lossless_texture_storage.py \
  --output .tmp/lossless-texture-storage-full
python3 tools/study_strict_webp_texture_storage.py \
  --baseline .tmp/lossless-texture-storage-full \
  --output .tmp/strict-webp-texture-full
python3 tools/resume_strict_webp_texture_storage.py \
  --baseline .tmp/lossless-texture-storage-full \
  --output .tmp/strict-webp-texture-full
python3 -m unittest discover -s tools -p 'test_*texture_storage.py'
```

Successful primary measurements are retained in slot-c's
`.tmp/lossless-texture-storage-full-v2/`. Native unit evidence and independent
alpha diagnostics are in `.tmp/lossless-texture-storage-v1/`. The strict pilot
is in `.tmp/strict-webp-texture-pilot-v1/`. Full checkpoints include complete
private candidate packs, all per-mip hashes, source/candidate cold reports and
logs; none of those packs are committed or uploaded.

The successful strict full run is in `.tmp/strict-webp-texture-full-v1/`. Its
resumer uses explicit native-script dispatch for each job, so two workers do not
race the serial encoder's script-selection state. The compact committed receipt
`release/lossless_texture_storage_study_v15.json` pins both final reports, source
and implementation inputs, every candidate hash, native receipts, unit evidence,
independent alpha diagnostic and the failed/successful duplication diagnostics.
Six focused Python checks and the six-format native mip/hidden-colour test pass.
