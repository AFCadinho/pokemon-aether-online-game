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
