# Rendered sprite distribution-format benchmark

## Decision

Do not switch the production format yet.

The benchmark has one promising review candidate: action-union trimming plus
WebP quality 95. It reduces the four-species sample from 551.59 MiB to 102.04
MiB (5.41x), keeps alpha byte-exact, reduces decoded texture capacity by 2.69x,
and had no post-warm-up 60 FPS spikes in the native Godot playback probe.
It is still technically lossy. The sampled composite PSNR is about 48.56 dB,
with isolated RGB deltas up to 103, so a human must review 1:1 moving sprites
before it can be accepted.

The strict lossless winner is action-union trimming plus lossless WebP. It
reduces disk size to 292.95 MiB (1.88x) and decoded texture capacity to 2.40 GiB
(2.69x). This is safe, but misses the desired 5-10x distribution reduction.

Godot Basis Universal/UASTC is not a good default for these 2D alpha sprites.
The trimmed payload reaches only 2.06x disk reduction, introduces larger alpha
and color errors than WebP Q95, and its level-4 sample takes roughly 78x longer
to encode than level 0. It does reduce estimated VRAM to 615.06 MiB for all four
complete species, but that benefit does not compensate for its disk result and
visible-quality risk.

## Scope and method

The sample is Diglett, Jigglypuff, Dragonite, and Roaring Moon, normal variant,
using every existing front/back action: idle, physical attack, special attack,
damage, sleep, faint start, and faint loop. This is 6,560 frames in 858 current
PNG atlas pages. Source timing remains native 60 FPS and the logical frame size
remains 512x512.

The structural candidate stores the common alpha union of each action, plus a
four-pixel safety border, and retains an offset for reconstructing the original
512x512 frame. It does not resample visible pixels. Exact frame deduplication was
also measured, but found only 3-6 duplicates per species and is not useful.

WebP was encoded with libwebp 1.6 through Pillow 12.3, method 4. Lossless uses
quality 100; the visually-lossless candidate uses quality 95 and lossless alpha.
Godot 4.6.2 created portable Basis/UASTC, BPTC, ASTC, and ETC2 resources. Native
runtime measurements used Forward+ Vulkan on an NVIDIA RTX 3070 Laptop GPU.

## Disk and decoded texture capacity

| Candidate | Four-species disk | Reduction | Complete decoded/GPU capacity | Quality |
|---|---:|---:|---:|---|
| Current PNG atlas | 551.59 MiB | 1.00x | 6.44 GiB RGBA8 | Exact |
| Trimmed PNG | 388.47 MiB | 1.42x | 2.40 GiB RGBA8 | Exact composite |
| Lossless WebP | 328.93 MiB | 1.68x | 6.44 GiB RGBA8 | Exact composite |
| Trimmed lossless WebP | 292.95 MiB | 1.88x | 2.40 GiB RGBA8 | Exact composite |
| WebP Q95 | 106.59 MiB | 5.17x | 6.44 GiB RGBA8 | Lossy RGB, exact alpha |
| Trimmed WebP Q95 | 102.04 MiB | 5.41x | 2.40 GiB RGBA8 | Lossy RGB, exact alpha |
| Trimmed Basis UASTC L0 | 268.27 MiB | 2.06x | 615.06 MiB block-compressed | Lossy RGB/alpha |

WebP disk compression does not reduce GPU memory by itself. Trimming reduces
the physical atlas dimensions; Basis additionally uses a GPU block-compressed
format. The capacity figures represent all actions of all four species resident
at once. The current loader is lazy per action, but cached actions remain resident
for the process lifetime, so this is a real long-session upper-bound concern.

### Per-species disk size

| Species | PNG | Lossless WebP | Trim + lossless WebP | WebP Q95 | Trim + WebP Q95 | Trim + Basis |
|---|---:|---:|---:|---:|---:|---:|
| Diglett | 130.52 | 66.74 | 65.55 | 25.80 | 25.31 | 89.78 |
| Jigglypuff | 133.68 | 77.39 | 68.79 | 20.28 | 19.66 | 60.82 |
| Dragonite | 128.49 | 81.41 | 67.34 | 25.40 | 23.74 | 52.21 |
| Roaring Moon | 158.89 | 103.39 | 91.27 | 35.10 | 33.33 | 65.46 |

Values are MiB. `report-formats.json` contains the front/back per-action
breakdown for every candidate.

## Quality

Lossless WebP and both lossless trimmed candidates reproduce the composited
source exactly on dark, light, and colored backgrounds; alpha max delta is zero.
WebP Q95 also keeps alpha exact. Its aggregated sampled PSNR is 48.58 dB without
trimming and 48.56 dB with trimming. The maximum composite-channel deltas are
100 and 103 respectively, confined to individual pixels; this is why technical
metrics cannot replace human approval.

The four-page GPU-format sample produced these ranges:

| GPU profile | Composite PSNR | Alpha max delta | Sample encode time | Assessment |
|---|---:|---:|---:|---|
| Basis UASTC level 0 | 40.28-41.24 dB | 153 | 0.31 s | Reject as quality default |
| Basis UASTC level 4 | 42.40-43.26 dB | 134 | 24.47 s | Better, still lossy and too slow |
| BPTC | 42.90-43.31 dB | 69 | 0.43 s | Desktop-only reference, not exact |
| ASTC | 24.80-27.48 dB | 254 | 1.49 s | Reject |
| ETC2 | 37.80-37.96 dB | 29 | 0.05 s | Reject as quality default |

The local visual sheets are `visual-comparison.png` and
`visual-comparison-gpu.png` in the benchmark output directory. They show the
same sampled frames against dark, light, and colored backgrounds. They are
comparison aids, not approval evidence.

## Native loading and 60 FPS playback

Each format ran in its own Godot process. The first pass and immediate second
pass load all 56 species/view/action groups sequentially. Linux OS cache state
was not forcibly cleared, so “first pass” is process-cold, not guaranteed
physical-disk-cold. File reads total only 0.29-0.86 seconds across all 858 pages;
decode and texture upload take 6.34-13.30 seconds for the image candidates, so
the storage cache is not the main hitch source.

| Candidate | First-pass total | Median action | Worst action | Second pass | Peak process RSS |
|---|---:|---:|---:|---:|---:|
| PNG | 14.15 s | 254 ms | 559 ms | 22.50 s | 517 MiB |
| Trimmed PNG | 6.87 s | 120 ms | 234 ms | 6.33 s | 486 MiB |
| Lossless WebP | 13.54 s | 240 ms | 591 ms | 19.00 s | 532 MiB |
| WebP Q95 | 14.28 s | 253 ms | 658 ms | 20.26 s | 527 MiB |
| Trimmed lossless WebP | 7.97 s | 132 ms | 266 ms | 7.31 s | 490 MiB |
| Trimmed WebP Q95 | 8.45 s | 145 ms | 293 ms | 7.96 s | 486 MiB |
| Trimmed Basis UASTC | 7.29 s | 112 ms | 230 ms | 6.87 s | 467 MiB |

The slower second pass for full-size PNG/WebP is consistent with deferred GPU
resource destruction/pressure, not disk I/O. This reinforces that a warm file
cache alone does not solve the current first-action hitch.

After all pages for Dragonite's physical attack were resident, every candidate
completed a 60-frame warm-up and 360 measured frame switches. All candidates
had a median near 16.66 ms, p99 between 16.69 and 17.00 ms, and zero frames over
20 ms. Format choice therefore affects loading and residency, not steady-state
60 FPS playback once textures are uploaded.

## Platform feasibility

| Platform | PNG/WebP | Basis/GPU formats | Practical conclusion |
|---|---|---|---|
| Desktop | Native probe passed | Portable Basis transcoded to BPTC on this GPU | All load; trimmed WebP is the safer quality path |
| Web | Godot supports PNG/WebP decoding; current web presets request desktop VRAM compression only | Portable Basis can transcode, but direct KTX2 becomes an `Image` instead of preserving a compressed runtime texture in Godot 4.6 | WebP is straightforward; direct KTX2 is not a viable delivery primitive yet |
| Android | PNG/WebP are broadly viable but remain RGBA8 in VRAM | Portable Basis can target ASTC/ETC2; alpha compression quality is device/format-sensitive | Packaging is feasible, but no Android preset/device was available for device timing; ASTC/ETC2 quality samples are not acceptable as the sprite default |

Godot documents that lossless/lossy WebP remains uncompressed on the GPU, while
only VRAM-compressed/Basis modes reduce GPU memory. It also warns that VRAM
compression can show noticeable 2D artifacts. Those documented tradeoffs match
the measurements here.

## Review decision (2026-09-20)

The in-game human review accepted **trimmed WebP Q95** as the representation to
feed into later pack/delivery work. Battle playback showed no visible
regression. A moving block pattern initially seen in Summary was reproduced
with the original PNG catalog too and was traced to nearest sampling of the
completed preview SubViewport at fractional window scales. After that separate
composition bug was corrected, the pattern disappeared without changing the
Q95 assets.

This accepts a distribution input format, not a runtime default or delivery
architecture. The source masters remain 512x512 RGBA at native 60 FPS, human
artistic approval remains required, and the current fallback/default selection
is unchanged.

## Reproduction

```sh
python tools/sprite_factory/distribution_benchmark.py \
  --catalog "$CATALOG" --output "$OUTPUT" --workers 8

POKEAETHER_DISTRIBUTION_BENCHMARK_CONFIG="$OUTPUT/godot-encode-config.json" \
  "$WORKSPACE/ops/worktrees/slot-env" "$SLOT" -- \
  godot --headless --path . \
  --script res://tools/sprite_factory/distribution_texture_benchmark.gd

python tools/sprite_factory/distribution_benchmark.py \
  --catalog "$CATALOG" --output "$OUTPUT" --finalize-godot
```

Run each generated `godot-runtime-config-CANDIDATE.json` in a separate process
with `distribution_runtime_benchmark.gd`, then use `--merge-runtime`. Generated
formats, decoded samples, visual sheets, and JSON reports remain local benchmark
artifacts and are not runtime assets.

## References

- [Godot `CompressedTexture2D`](https://docs.godotengine.org/en/stable/classes/class_compressedtexture2d.html)
  documents disk, loading, and VRAM behavior for lossless, lossy, VRAM, and
  Basis modes.
- [Godot `PortableCompressedTexture2D`](https://docs.godotengine.org/en/stable/classes/class_portablecompressedtexture2d.html)
  documents the cross-platform Basis/BPTC/ASTC/ETC2 resource path used here.
- [Godot `ResourceImporterTexture`](https://docs.godotengine.org/en/stable/classes/class_resourceimportertexture.html)
  documents the quality tradeoffs and UASTC/RDO controls.
- [Godot KTX2 support proposal](https://github.com/godotengine/godot-proposals/issues/13660)
  records the current 4.6 limitation where standalone KTX2 loading becomes an
  `Image` instead of remaining a compressed runtime texture.
