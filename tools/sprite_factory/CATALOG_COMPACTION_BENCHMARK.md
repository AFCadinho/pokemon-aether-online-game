# 24-entry catalog compaction benchmark

Date: 2026-09-20. No production format, runtime default, resolution, frame rate,
or approved asset was changed by this benchmark.

## Decision

The present 24-entry trimmed WebP Q95 catalog averages 20.66 MiB per normal
variant and 19.43 MiB per shiny variant. At 1,000 normal plus 1,000 shiny
variants that projects to 39.1 GiB of atlas pages, or roughly 40 GiB including
preview frames and metadata. That is not an acceptable full-catalog target.

None of the tested drop-in representations delivers a substantial reduction
while retaining the approved appearance and working in stock Godot 4.6 on
desktop, Android, and web. Keep trimmed WebP Q95 as the reviewed baseline; do
not switch production format on this evidence.

The source-assisted shiny and dual-plane follow-ups are now complete. Neither
meets the storage, quality, and three-platform contract. A material-ID/LUT shiny
keeps 61-65% of the current normal+shiny pair and loses 4-5 dB versus Q95. The
closest dual-plane quality match keeps 50.3% (1.99x reduction), projects the
full catalog to about 19.7 GiB, and requires codecs absent from stock Godot.
The more aggressive candidate keeps 39.2% (2.55x), projects about 15.3 GiB,
and visibly misses the current quality metric. Park custom codec work. Under
the fixed 512x512/native-60-FPS/current-quality contract, representation alone
has not made an install-all catalog acceptable; the next product decision is a
delivery/residency design or an explicit relaxation of that contract.

## Baseline and action contribution

The four normal benchmark species contain 6,560 frames and 102.04 MiB of
trimmed Q95 pages. Every packaged frame is unique. The lossless source contains
only 19 duplicates across action/view boundaries (0.29%), so shared exact-frame
references cannot materially reduce the catalog.

| Action | Q95 MiB | Share | Frames | Seconds | Fully transparent pixels | Per-frame tight raw saving |
|---|---:|---:|---:|---:|---:|---:|
| Idle | 12.28 | 12.0% | 748 | 12.5 | 53.8% | 17.3% |
| Physical attack | 15.17 | 14.9% | 928 | 15.5 | 69.0% | 42.7% |
| Special attack | 19.07 | 18.7% | 1,172 | 19.5 | 62.3% | 33.3% |
| Damage | 5.29 | 5.2% | 328 | 5.5 | 61.1% | 31.9% |
| Sleep | 20.81 | 20.4% | 1,488 | 24.8 | 46.0% | 10.0% |
| Faint start | 17.29 | 16.9% | 1,048 | 17.5 | 63.1% | 34.5% |
| Faint loop | 12.13 | 11.9% | 848 | 14.1 | 51.4% | 13.2% |

No action contains an exact shorter cycle, duplicate endpoint, or consecutive
identical hold. Only 152 of 6,504 adjacent pairs reach 45 dB against each other
(2.3%). Shortening loops or turning frames into holds would therefore change
motion rather than losslessly removing redundancy.

Action-union trimming still leaves substantial transparent area. Per-frame
tight bounds reduce raw RGBA area by 27.8% overall, but individually encoded
tight Q95 frames are **9.2% larger** than the current atlases. They decode in
100-268 ms per representative action. This route is useful for a future
sliding-window VRAM cache (roughly 140-454 KiB for one tight RGBA frame), not for
disk compaction.

The current four-species upper bound remains 2.40 GiB decoded RGBA when every
action is resident. Existing lazy Godot loading measured 145 ms median and
293 ms worst action load; resident playback held native 60 FPS with no measured
frame over 20 ms.

## Representation results

Ratios below are weighted over front idle plus the largest front action for
each benchmark species. Quality is measured directly against lossless source
frames on a dark composite; alpha is checked independently.

| Candidate | Size vs Q95 | Quality/alpha | Decode and seek | Verdict |
|---|---:|---|---|---|
| Current static-atlas Q95 | 1.000 | Approved; exact alpha | Godot: 145 ms median action load | Baseline |
| Animated WebP Q95 | 0.927 | Essentially the same Q95 result; exact alpha | Python median full decode 134 ms; median seek 64 ms | 7.3% is not worth a custom decoder |
| Animated lossless WebP | 2.520 | Exact | Median full decode 109 ms | Reject: much larger |
| Keyframe + zlib RGBA delta | 4.342 | Exact to approved Q95 | Median seek 13 ms | Reject: much larger |
| Tight per-frame Q95 | 1.092 | Q95-class; exact alpha | Median full decode 160 ms | Reject for disk; retain as VRAM idea |
| VP9 alpha CRF 4 | 0.594 | Alpha changed by up to 24; minimum PSNR 35.08 dB | Desktop-process median start 49 ms, seek 102 ms | Reject: quality/platform contract fails |
| VP9 alpha CRF 10 | 0.338 | Alpha changed by up to 34; minimum PSNR 34.87 dB | Median start 49 ms, seek 85 ms | Reject: visible-quality risk and unsupported in Godot core |
| Static WebP Q90 | 0.773 | Exact alpha; minimum PSNR 36.64 dB | Same Godot path | Too small a win; needs human review and still projects too large |
| Static WebP Q85 | 0.652 | Exact alpha; minimum PSNR 36.07 dB | Same Godot path | Quality reduction; not equivalent to approved baseline |

VP9 CRF 4 is the only temporal result near the approved quality range, but its
gain varies from 1.09× to 3.69× by species/action and it damages alpha. CRF 10
is smaller but introduces a larger quality change. A lossless VP9 check on
Dragonite idle was 1.74× larger than Q95 and still differed by one alpha level
after color conversion. These are research references, not viable packages.

WebP encoder method 6 was stopped after more than 20 minutes for only eight
representative actions and produced no completed report. Method 4 encoded the
equivalent quality sweep in 14 seconds. Even a modest method-6 size improvement
would not solve the projected catalog size and is not a scalable production
trade.

## Normal/shiny sharing

Only Dragonite has both normal and shiny data among the four requested species;
Roaring Moon, Jigglypuff, and Diglett have no shiny entry in this catalog.
Dragonite normal is 23.74 MiB and shiny is 22.41 MiB.

Across 1,658 paired frames, no alpha plane is byte-identical because the two
variants were rendered independently. The mean absolute alpha difference is
only 0.00257/255, but the maximum is 11, so blindly sharing alpha is not exact.
A hypothetical shared compressed alpha plane saves about 7.16 MiB, around
15.5% of the normal+shiny pair—not enough by itself.

Generic residual coding is worse: the lossless normal-to-shiny RGBA residual is
110.43 MiB versus the 22.41 MiB shiny. A Q95 residual test on Dragonite idle is
1.78× the shiny idle data and reconstructs at only about 22 dB. Reject generic
pixel residuals.

A renderer-produced material-ID pass was tested on Dragonite idle and special
attack. The importer confirmed identical rig, geometry, actions and cameras;
only `body_a` and `body_b` use different official rare albedos. A flat Blender
pass emitted stable IDs for body A, body B and both eyes in about 23 seconds for
254 frames. An L8 mask plus per-material 32^3 RGB LUT reduced the incremental
shiny payload to 19.8-28.8% of a full shiny action. However, normal plus the
reconstructed shiny still retained 61.0-65.3% of the two complete variants.
Minimum composite PSNR was 45.57-46.00 dB versus 50.43-50.60 dB for current
Q95, with visible colour fringes at material/coverage boundaries. The reference
CPU implementation also took about 27 ms per frame; a shader would solve speed,
not the quality or total-catalog result. Reject this as the catalog default.

## Dual-plane temporal follow-up

The four requested species were tested again on front idle plus their largest
front action. RGB was encoded temporally while alpha remained byte-exact in a
separate plane. All candidates preserve the existing trimmed frame coordinates,
512x512 logical canvas and native 60 FPS.

| RGB + exact alpha candidate | Size vs Q95 | Reduction | Minimum PSNR | Projected 39.1 GiB catalog | Verdict |
|---|---:|---:|---:|---:|---|
| AV1 4:4:4 CRF4 + FFV1 gray | 0.503 | 1.99x | 48.31 dB | 19.7 GiB | Closest quality; still much too large and nonportable |
| AV1 4:4:4 CRF8 + FFV1 gray | 0.392 | 2.55x | 45.86 dB | 15.3 GiB | Smaller, but below current quality and nonportable |
| AV1 4:4:4 CRF8 + animated lossless WebP alpha | 0.416 | 2.41x | 45.86 dB | 16.3 GiB | Faster alpha decode, same quality/platform failure |
| AV1 4:4:4 CRF8 + zlib delta alpha | 0.410 | 2.44x | 45.86 dB | 16.0 GiB | Exact, but median alpha decode/seek is 703/94 ms |
| AV1 4:2:0 CRF4 + PNG alpha | 0.484 | 2.07x | 35.16 dB | 18.9 GiB | Portable chroma profile destroys edge/colour quality |

The exact alpha plane is not a small afterthought: with AV1 4:4:4 CRF8 it was
58% of the combined PNG-alpha package. Temporal alpha improved the total by
only a few percentage points. FFV1 was the smallest exact alpha reference;
animated lossless WebP was substantially faster to decode and seek. Lossless
VP9 gray was not byte-exact after pixel-format conversion and was rejected.

Local FFmpeg process timings are not embedded-runtime claims. AV1 4:4:4 CRF4
had median RGB full-decode/start/seek times of roughly 127/52/56 ms; FFV1 alpha
added medians of 78/51/57 ms. Resident playback was not the blocker—the format
and platform contract was.

## Platform feasibility

- Static PNG/WebP remains the only tested path that stock Godot 4.6 decodes on
  desktop, Android, and web. It remains RGBA in VRAM.
- Godot 4.6 core video playback supports Ogg Theora. Theora exposes only Y, Cb,
  and Cr planes, not alpha; Godot also documents that browsers do not support
  its Theora output. It cannot replace transparent sprites.
- Godot removed WebM from core in 4.0. VP9 alpha therefore needs a custom
  decoder. Android lists VP9/WebM decoding, but that does not establish the
  WebM auxiliary alpha-plane contract used here.
- WebCodecs defines alpha-capable raw frames but lets implementations support
  arbitrary codec combinations and requires querying the exact profile and
  constraints. It is not a uniform Godot/web codec guarantee.
- Android documents AV1 decode from Android 10 and mandatory AV1 codecs only
  from Android 14. That does not guarantee the 4:4:4 profile required by the
  quality result on every device. The broadly usable 4:2:0 result failed visual
  quality in this sample.
- A libwebp/libvpx GDExtension is possible on native platforms. Default Godot
  web templates do not include GDExtension support; custom dynamically linked
  templates are required. Animated WebP's 7.3% result does not justify that
  cost. VP9 would still need exact-alpha and quality work first.
- Basis/ASTC/ETC2 remain rejected from the earlier benchmark because transparent
  2D quality regressed; Godot itself warns that VRAM-compression artifacts are
  more noticeable in 2D and that many Android devices do not support compressed
  transparent textures well.

Primary references:

- Godot 4.6 video support: https://docs.godotengine.org/en/4.6/tutorials/animation/playing_videos.html
- Godot 4.6 `Image` decoders: https://docs.godotengine.org/en/4.6/classes/class_image.html
- Godot portable texture behavior: https://docs.godotengine.org/en/stable/classes/class_portablecompressedtexture2d.html
- Godot web GDExtension templates: https://docs.godotengine.org/en/stable/engine_details/development/compiling/compiling_for_web.html
- Android media formats: https://developer.android.com/media/platform/supported-formats
- WebCodecs alpha contract: https://www.w3.org/TR/webcodecs/
- WebM auxiliary alpha design: https://wiki.webmproject.org/alpha-channel
- Theora pixel planes: https://theora.org/doc/libtheora-1.2/codec_8h.html

## Reproduction and raw evidence

Run the four commands documented in `README.md`. Local raw results are under:

```text
.worktrees/slot-a/.tmp/catalog-compaction-benchmark-02/report.json
.worktrees/slot-a/.tmp/catalog-compaction-benchmark-02/tight-frame-report.json
.worktrees/slot-a/.tmp/catalog-compaction-benchmark-02/webp-quality-report.json
.worktrees/slot-a/.tmp/video-alpha-benchmark-01/report.json
.worktrees/slot-a/.tmp/variant-material-benchmark-02/report.json
.worktrees/slot-a/.tmp/dual-plane-video-benchmark-01/report.json
.worktrees/slot-a/.tmp/dual-plane-video-benchmark-av1-crf4/report.json
.worktrees/slot-a/.tmp/alpha-plane-benchmark-01/report.json
```

All codec timings are local Linux desktop measurements. Python in-memory and
FFmpeg subprocess timings are useful for relative investigation but are not a
substitute for an embedded Godot decoder on Android or web.
