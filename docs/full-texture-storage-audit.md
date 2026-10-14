# Full v15 texture storage audit

This is an offline storage study. It does not approve publication, change the
runtime catalog, or modify R2 objects. The full catalog contains 1,420 model
pairs; 1,365 PCK pairs have external native textures and 55 ZIP pairs remain
byte-identical. The pinned v15 baseline is 8,795,326,138 bytes.

## Measured result

| Metric | Bytes / count |
| --- | ---: |
| Pinned v15 complete collection | 8,795,326,138 bytes |
| Selected complete prototype collection, including unchanged ZIPs | 7,005,725,658 bytes |
| Additional measured saving | 1,789,600,480 bytes (20.3472%) |
| Difference above 7,000,000,000 bytes | 5,725,658 bytes |
| Native PCK pairs independently verified | 1,365 |
| ZIP pairs retained unchanged | 55 (126,699,042 bytes) |
| External textures cold-verified and deep-duplicated exactly | 24,024 |
| Eligible authored image levels independently decoded exactly | 66,941 |
| Held original textures | 26 |

The codec route alone is **just above 7 decimal GB**. The independent physical
summary additionally found **211,031,971 bytes** of remaining duplicate texture
payload across **511** exact decoded-state groups belonging to different pairs.
Subtracting all of that would give 6,794,693,687 bytes before any unbuilt shared
archive overhead and scene/catalog rebinding. This is a remaining opportunity
indicator, not an approved or measured shared-pool release. Only 5,725,659 bytes
of net further saving are needed to cross strictly below 7 decimal GB.

The recommended next proof is a small shared-texture prototype across selected
forms, with actual complete package sizes and ownership/cache checks. The
full texture candidates also still require the runtime qualification below.
R2 objects, admission pins and deployed game/launcher code were not changed.

The compact tracked receipt is
`release/full_texture_storage_audit_v15.json`; it binds the full private report,
configuration, resumption drivers, all source/candidate and native proof hashes,
and the independently validated remaining duplicate analysis.

Focused validation: 15 Python tests passed; the older retained-fixture corruption
test was skipped because its fixture is not in this slot. Source pins were
checked for every real archive in the complete audit. Native unit checks passed
for all six 8-bit image formats, authored mips, hidden RGB, metadata and deep
duplication. The isolated-project control matched the earlier cold texture
states, engine version, renderer and device exactly.

## Method

Every source archive is checked against the approved v15 SHA-256 and size.
Godot 4.6.2 with the actual Linux GL Compatibility renderer loads every external
texture. The source PNG candidate preserves each existing mip independently;
no resizing, quantization or mip generation occurs. Pillow/libwebp 1.6.0 then
encodes strict lossless WebP with `exact=True`, method 6 and quality 100.
Independent PNG and WebP decoding must reproduce every source pixel byte,
including alpha and RGB hidden beneath transparent pixels.

The choices are original ImageTexture, native lossless PNG and strict native
lossless WebP. Their complete native resources use the same existing Zstd
level 19 / 256 KiB block framing. The smallest exact resource wins for each
texture. Unsupported precision, compression or size overrides retain the
original. The ordinary Godot WebP encoder is omitted from this full audit
because its near-opaque alpha detection can change pixels; the earlier
20-pair study documents and rejects those changes.

The strict WebP buffer replaces only the checked native PackedByteArray in
Godot's existing Portable PNG resource. The writer rejects other binary
versions, import metadata, unsupported flags, additional internal/external
resources, changed image shape and malformed buffers. It preserves the main
resource offset, every other native byte and native array padding. Cold Godot
loading remains mandatory. Six actual native image formats with authored mips
and metadata also passed the direct-buffer and deep-duplication checks.

Each complete candidate PCK is written, independently unpacked and checked.
Every non-texture native member remains byte-identical. A separate fresh Godot
process physically inspects and mounts the candidate, then checks all decoded
texture states against the source and checks deep duplication of every texture.
This full texture-only audit does not repeat full scene and animation tests;
the earlier 20-pair study covered those and the unchanged bytes are verified
for every complete candidate here.

The 55 unmodified ZIP archives are also rehashed. Totals use actual complete
persisted PCK sizes, including alignment, tables and manifests. A pack is
retained entirely if its candidate is larger. Cross-form duplicate estimates
are not added to these savings because they overlap texture storage.

## Runtime qualification still required

Cold verification enables
`PortableCompressedTexture2D.set_keep_all_compressed_buffers(true)` before
loading textures. This solves the previously observed compressed-buffer and
deep-duplication issue in this probe. Production loader/presenter/cache tests,
compressed-buffer RAM measurements, eviction/reload tests and platform checks
remain separate work. GPU dimensions and decoded precision stay unchanged;
this study makes no GPU-memory saving claim.

Prototypes intentionally retain their original namespace for isolated
source/candidate comparisons. Production requires newly bound namespaces,
scene hashes and a coordinated game/launcher asset revision; these private
packs must not be uploaded as direct replacements.

## Reproduction

Run only in an assigned frontend task slot, through its `slot-env`. Retained
source archives are read in place. Generated packs, resources and evidence stay
in the task slot's `.tmp` directory. The runner excludes `.tmp` from Godot's
project scan and temporarily disables autoloads/editor plugins under the
existing diagnostic-project lock, restoring `project.godot` on completion.

```sh
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/audit_full_texture_storage.py \
  --sources .worktrees/slot-c/frontend/.tmp/model-release-v15/sources.json \
  --output .worktrees/slot-b/frontend/.tmp/full-texture-audit-v2 --workers 6
```

A resumed run validates frozen code/source-map/library/settings bindings,
original archive hashes, candidate hashes and native evidence hashes. Failed
or interrupted attempts are retained but never count as successful checkpoints.

## Remaining cross-form sharing

After the full run, `tools/summarize_full_texture_audit.py` rehashes and
independently unpacks every original and candidate archive. It checks the
actual texture sizes, unchanged non-texture bytes, source/cold state hashes
and complete collection coverage. It then groups byte-exact decoded texture
states across different model pairs. This is the duplicate payload remaining
after the new codec choices, rather than the earlier v14 duplicate estimate.

The resulting duplicate-byte indicator is not an implemented shared-pool
release saving. Shared archive overhead, scene/catalog rebinding and runtime
ownership/cache qualification still need a built and tested prototype. The
optimistic subtraction is labeled separately and never added to the actual
measured pack savings.

Native binary format reference: [Godot 4.6 resource_format_binary.cpp](https://github.com/godotengine/godot/blob/4.6/core/io/resource_format_binary.cpp).

The completed run can also use the dedicated frozen-input resumer:

```sh
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/resume_full_texture_audit.py \
  --output .worktrees/slot-b/frontend/.tmp/full-texture-audit-v2
```

It validates and retains successful checkpoints from the original six-worker
run, then uses eight workers and a bounded in-memory cache of content-identical
PNG mip buffers. Cache hits must match the current native source pixel hashes
and mip dimensions. Only encoding is cached; original-pack verification,
metadata preservation and fresh-process cold verification run for every pair.
The report separately binds the resumer hash, actual worker count and hit count;
the original configuration continues to bind the unchanged encoder inputs.

The final isolated resumer uses a handwritten minimal probe project, with only
the seven required GDScript source files linked from the task slot. It does
not copy the game configuration, caches, logs or assets. This avoids stale UID
references and project scans traversing archived earlier experiments. The
report binds this driver's hash, all linked scripts and the generated project
configuration. A known cold candidate passed with exactly the same texture
states, Godot version, renderer and device as the earlier full-project control.

```sh
ops/worktrees/slot-env slot-b -- python3 .worktrees/slot-b/frontend/tools/resume_isolated_texture_audit.py \
  --output .worktrees/slot-b/frontend/.tmp/full-texture-audit-v2
```
