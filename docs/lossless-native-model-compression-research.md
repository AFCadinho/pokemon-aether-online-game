# Lossless native-model compression research — 2026-10-06

The current v10 collection contains 1,200 bundles / 2,400 appearances. Its
pinned download total is 19,863,374,075 bytes and the installed model snapshot
is 19,863,404,982 bytes. This renewed investigation was explicitly requested
by the user after the measured catalog reached 19.86 GB. The user authorized
a temporary fourth paired task slot because the three permanent slots were
occupied. Original control-plane scripts and their assignments were unchanged.

## Finding

A native-container experiment reduces 22 approved scenes (11 normal/shiny
pairs) from **365,781,164 to 236,964,483 bytes: 35.2169%**. It changes only
Zstandard framing/block sizes. Every decompressed native resource stream is
byte-identical, including all stored pixels/mips, resource IDs, materials,
geometry, bindings, bone data, animation keys/timing and response metadata.
No component assembly, texture conversion, resolution reduction, mesh
simplification, animation reduction, shader modification or production loader
change is part of this experiment.

The source scenes use Godot's native RSCC format with 4 KiB blocks. The engine
reads each file's block size from its header; the probe re-encodes the unchanged
stream into larger native blocks. See Godot 4.6
[FileAccessCompressed](https://github.com/godotengine/godot/blob/4.6/core/io/file_access_compressed.cpp)
and [Zstandard compression](https://github.com/godotengine/godot/blob/4.6/core/io/compression.cpp).
The offline compressor is libzstd 1.5.7. The runtime is Godot 4.6.2.

| Block size | Zstd level | Scene bytes | Saving |
| --- | ---: | ---: | ---: |
| Original 4 KiB resources | Original | 365,781,164 | — |
| 64 KiB | 3 | 278,052,369 | 23.9840% |
| 64 KiB | 9 | 254,562,150 | 30.4059% |
| 256 KiB | 3 | 264,498,556 | 27.6894% |
| 256 KiB | 9 | 241,217,309 | 34.0542% |
| 1 MiB | 3 | 261,396,720 | 28.5374% |
| 1 MiB | 9 | 236,964,483 | 35.2169% |

These are actual native SCN bytes, excluding ZIP manifest/central-directory
metadata. They support both transfer and installed-storage savings if the
re-encoded native files are adopted. They are **not a whole-catalog budget**:
the sample is intentionally varied, not a random weighted catalog sample.
A simple extrapolation to 19.86 GB is not a measured release size.

The sample includes Arcanine Hisui, Samurott Hisui, Darmanitan Galar Zen,
Goodra Hisui, Zorua Hisui, Dragonite, Roaring Moon, Cloyster, Grimmsnarl,
Floragato and Mega Steelix, normal and shiny. Each original archive and SCN
hash was checked against the published v10 index before the experiment and the
source archive hash was rechecked after it. Sources were read in place.

## Validation and remaining hold

- All 22 scenes × six configurations retain their complete decompressed stream
  exactly: 132 byte-exact roundtrips, covering 986,453,030 original raw bytes.
- Godot independently loads all 22 selected 1 MiB/level-9 scenes. Complete
  stored-resource semantic fingerprints and instantiated actor data match
  the originals. The headless load/instantiate/free check completes with zero
  captured engine errors.
- Three Python checks cover roundtrips, exact block-size multiples (including
  Godot's trailing empty block), malformed/truncated/unbounded headers and
  changed compressed payloads. All pass.
- The existing strict Forward+ renderer comparison was retained: same 512×512
  viewport, MSAA4, camera and neutral lights. No pixel tolerance, hidden mesh,
  changed near plane, material priority or reduced shader quality was used.
- A mixed Zorua/Dragonite run stops after 78 comparisons at Dragonite's response
  `faint_start:0.999`: one pixel at (265,308), maximum RGBA difference
  (16,9,2,0). The original-only control reproduces **the exact same two image
  hashes**, identity, pose and response mode. An independent 42-pose A/A/A′
  diagnostic also reproduces a one-pixel difference between two originals.
  Thus this difference is not evidence of changed model data from compression.
- A separate Samurott/Roaring Moon run stops after 49 comparisons at Roaring
  Moon `damage:0.0`. Its separate original-only control reproduces the exact
  same failed comparison and both image hashes after the same 49 comparisons.
  This is current evidence, consistent with the retained overlap investigation.

The complete rendered comparison is **held**, and no replacement model catalog
is production approved. The older component-sharing prototype remains closed.
This native-container research avoids its private-material ownership design,
but strict render repeatability must still be addressed before claiming a
complete visual gate. All failed/diagnostic runs and original sources remain.

## Loading and runtime limits

A sequential headless load diagnostic on a warm OS filesystem measured median
load calls of 83.714 ms for originals and 45.1125 ms for candidates. This is
**not a latency/performance qualification**: source always loaded first, other
workspace tasks were active, and no filesystem-cold, real-battle, cache-eviction,
FPS, peak-RAM, VRAM or cross-platform benchmark is inferred from those values.
The original 4 KiB vs 1 MiB native reader buffer sizes also need accounting in
that later qualification. Full client importing was stopped after it proved
unnecessary for this standalone experiment; its incomplete cache was retained.
The tiny renderer project has its own cache and references unchanged tracked
scripts/shaders in place, with the project's rendering settings preserved.

As an additional transfer-only fallback, all 22 candidates were decoded and
re-encoded with the original 4 KiB/level-3 settings using libzstd 1.5.7. Every
restored SCN has **the exact original SHA-256 and bytes**. That could reduce
transfer while retaining the existing approved runtime files, but would retain
the original installed footprint and require a version-bound installer and
failure fallback. It is not an implemented or qualified distribution format.

## Recommendation and next gate

Prioritize this native-container approach over a new shared-resource loader.
First make the original-vs-original image reference repeatable (the same
failures already occur on untouched files). Then qualify repeated loading,
normal/shiny switching, eviction and real battle latency/memory, followed by a
wider catalog size audit. Compare 256 KiB/level 9 against 1 MiB/level 9: the
former saves 34.05% with a smaller per-reader buffer, while the latter saves
35.22% in this sample. Choose from measured runtime results.

A later rollout needs new native/ZIP hashes, immutable bundle versions, updated
qualification/index receipts and matching game/launcher pins, installation,
update/rollback and cross-platform checks. No runtime registry, published bundle,
R2 index, active manifest, player setting or client version changed here.

## Follow-up validation — 2026-10-06

The follow-up uses the standard assigned `slot-a`, task
`lossless-model-compression-validation`, starting from local development. The
previous slot-d native fixtures are read in place. Fresh reports, the independent
renderer project and reconstructed installation fixtures are retained under
`slot-a/frontend/.tmp/lossless-validation-v1/`. No cache or userdata was copied.

### Wider size sample

A reproducible uniform sample without replacement selects 32 bundles from the
1,138 current-v10 archives available locally, using Python Random seed 20261006
over sorted asset IDs. Both appearances are included. The other 62 catalog
archives are outside this sample's population; this is not a complete 1,200
bundle inventory measurement. Selection IDs and missing IDs are retained in
`random-sample.json` and the condensed validation results.

| Native files in the 32-bundle sample | Bytes | Saving |
| --- | ---: | ---: |
| Existing approved files | 667,838,550 | — |
| 256 KiB / level 9, retaining unsupported files | 439,592,433 | 34.1768% |
| 1 MiB / level 9, retaining unsupported files | 431,966,501 | 35.3187% |

All 62 RSCC appearances × two configurations preserve their complete raw native
streams exactly (124 roundtrips). Toucannon normal and shiny are uncompressed
RSRC files: both remain unchanged and count in every total. The first sample run
stopped on their unsupported header; `--measure-only` now explicitly reports
verified RSRC files as unmodified. Unexpected/damaged RSCC data still fails.
No conversion of RSRC files was attempted. The original source ZIP hashes are
rechecked after measurement.

These totals measure native files, not newly packaged/published downloads.
Existing ZIPs in this sample total 667,435,744 bytes; 62 scene entries use ZIP
STORE and two use DEFLATE. New ZIPs, manifests, receipts and hashes still need
building and checking before a release download total can be stated. The similar
35% result supports further work; it is not proof that the whole 19.86 GB catalog
will shrink by exactly that percentage.

### Native load, pose independence and eviction

The actual Forward+ renderer loads all 22 initial-sample candidates and originals
independently with CACHE_MODE_IGNORE_DEEP. Three rounds alternate which format
loads first. Each format also instantiates a second actor from its cached scene.
Every stored animation except RESET is exercised at 0, 0.5 and 0.999 of its length.
The second actor stays in idle; its pose signature must remain unchanged.
Original/candidate transforms, bone poses, visibility and blend shapes must match
at every sampled pose. After actors and the two-entry cache are released, weak
references to every scene must become null. The retention diagnostic is explicitly
prohibited during this eviction check.

The completed run has 66 paired lifecycle checks, 1,494 exact pose-state
comparisons, 132 uncached load/instantiate calls and 132 cache hits. All succeed
with zero captured engine errors. Memory snapshots and load timings are retained,
but concurrent slot-c rendering makes this a functional loader/lifetime test,
**not** a certified latency, RSS/VRAM, FPS or real-battle benchmark. GPU allocator
retention is not ruled out by a released PackedScene weak reference.

The initial headless attempt is retained as a failed experiment: it requested
animation aliases absent from some original scenes and forced skeleton updates
on detached actors through the dummy renderer. The corrected fixture attaches
actors to a stage and iterates the actual animation lists, already checked equal
by the stored-resource fingerprints. No model, renderer setting or acceptance
tolerance was changed. Error reporting now marks reports incomplete and exits 2
on any captured engine/script error. An intentional incompatible
retention/eviction invocation verifies that failure behavior.

### Render reference is still held

An additional diagnostic leases each independently loaded native PackedScene by
its exact file path. Original and candidate paths never share a scene. Holding
the original resource graph makes the first Dragonite A/A pair exact across 42
pose/mode comparisons, but a third capture of **that same original file and
leased graph** still differs by one pixel at response faint_start:0.999. The
separate candidate run also has a one-pixel difference at that pose. This is
diagnostic completion, not a passed strict visual gate.

Thus simply retaining original mesh/material resources is insufficient to make
the reference sequence repeatable. Per-capture response materials, worlds and
renderer allocation/order remain investigation candidates. Godot's Forward+
[render-list sort keys](https://github.com/godotengine/godot/blob/4.6/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.h)
include geometry, material and shader IDs; combined with the documented
overlapping surfaces, this provides a plausible mechanism, not a demonstrated
root cause. The prior original-only exact-hash failures remain authoritative
evidence that compression is not required to reproduce the image differences.
No pixel tolerance, hidden geometry, altered camera or replacement reference
image was accepted.

### Transfer-only restoration fixture

`native_transfer_restore_probe.py` reconstructs the existing approved file from
the smaller transfer payload with the exact recorded libzstd version, original
4 KiB framing and level 3. Payload hash/size, decoded stream hash/size and restored
approved file hash/size must all match before replacement. The staged file is
flushed, fsynced and checked again before a same-directory atomic rename.

All 22 candidate files were installed then replaced a second time in a fresh
offline fixture: 44 successful restorations, all with exactly the existing
approved SCN bytes/SHA-256. The fixture measures a median 316.86 ms per
reconstruction/write and maximum 863.54 ms on this machine; concurrency, Python
whole-file buffers and compression overhead preclude a player latency claim.
Seven focused Python tests cover native framing/integrity, unchanged RSRC
accounting, restoration, mismatched codec/version/hash/size, damaged transfers
and a failed atomic commit. Failed restoration preserves the previous file and
removes its pending file.

This is an offline fixture, **not a deployed launcher installer**. It requires
integration with trusted manifests, a shipped/pinned codec, native platform
support, progress/cancellation, disk/RAM budgeting, crash recovery and fallback
to the approved original download. SHA-256 equality proves the installed runtime
file is unchanged for this sample. It can reduce transfer size without needing
a new runtime representation, but it does **not** reduce installed storage.

### Next implementation decision

Both samples justify proceeding with lossless compression. For reducing download
size first, qualify the transfer-only path in the actual launcher with original
download fallback and platform tests. For reducing device storage as well, keep
the native-container rollout held until the strict reference is repeatable and
actual battle/platform/installation checks pass. Compare 256 KiB with 1 MiB in
those checks: the larger blocks save only another 7,625,932 bytes in this sample.
No production catalog or client configuration is changed by these research tools.

Follow-up commands (run Godot through the assigned slot wrapper):

```sh
python3 -m unittest discover -s tools/sprite_factory -p 'test_native*probe.py'
python3 tools/sprite_factory/native_transfer_restore_probe.py \
  --input /ABSOLUTE/PATH/TO/native-v1/report.json \
  --output .tmp/FRESH-RESTORATION-FIXTURE
```

For the native lifetime run set `NATIVE_COMPRESSION_LIFECYCLE=1`,
`NATIVE_COMPRESSION_OUTPUT` to the existing native fixture directory and
`STORAGE_COMPONENT_REPORT` to a fresh task-local JSON path. Use the fresh
renderer project and a real renderer (not headless) with
`ops/worktrees/slot-env slot-a -- env ... godot --path ... --script
res://tools/sprite_factory/native_resource_compression_check.gd`.
`NATIVE_REFERENCE_LEASE=1` is diagnostic only and incompatible with lifecycle
qualification. The condensed results are in
`tools/sprite_factory/native_resource_validation_results.json`.

## Reproduction and evidence

Tracked tools:

- `tools/sprite_factory/native_resource_compression_probe.py`: offline framed
  compression with exact original index/archive/appearance hash checks.
- `native_resource_probe_project.py`: fresh task-local renderer project with
  source-only links and independent caches.
- `native_resource_compression_check.gd`: independent Godot semantics/native
  loader checks, strict visual comparisons and unchanged-original controls.
- `test_native_resource_compression_probe.py`: malformed/container tests.
- `native_resource_compression_results.json`: condensed evidence and hashes.

Local inputs, candidate native files, baseline installations, complete reports
and failed captures are retained under the temporary task frontend's
`.tmp/lossless-storage-v1/`. `archives.json` maps current v10 archive basenames
to existing source paths; it contains no credentials. `selected.json` pins the
11 exact asset IDs. The compression report includes every candidate SHA-256,
raw stream hash, source hash and six measured configurations.

```sh
python3 tools/sprite_factory/native_resource_compression_probe.py \
  --index release/approved_3d_bundles_v10_index.json \
  --archives .tmp/lossless-storage-v1/archives.json \
  --output .tmp/lossless-storage-v1/FRESH-OUTPUT \
  --identities pokemon_3d:dragonite:base pokemon_3d:roaring-moon:base
python3 tools/sprite_factory/native_resource_probe_project.py \
  .tmp/lossless-storage-v1/FRESH-RENDER-PROJECT
python3 -m unittest discover -s tools/sprite_factory \
  -p test_native_resource_compression_probe.py
```

Use the explicitly authorized temporary slot's mirrored `slot-env` wrapper with
`POKEAETHER_WORKSPACE_ROOT` set to the actual workspace. Set
`NATIVE_COMPRESSION_OUTPUT` to the fresh output directory and
`STORAGE_COMPONENT_REPORT` to a fresh report path. Headless runs check all
entries. Visual runs use `NATIVE_COMPRESSION_VISUAL=1` and optional comma-separated
`NATIVE_COMPRESSION_IDENTITIES`. The exact same visual sequence with
`NATIVE_ORIGINAL_ONLY=1` is the unchanged-source A/A control.
`NATIVE_COMPRESSION_DIAGNOSTIC=1` runs the independent Dragonite A/A/A′ control
in both rendering paths. Visual mismatch runs correctly exit 2.
