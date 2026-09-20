# 384 px resolution-tier benchmark

## Decision

Do not replace the production-ready 512 px masters or the current trimmed WebP
Q95 package with either tested 384 px candidate.

The global 384 px reduction is technically healthy at 60 FPS and improves
decode cost and decoded texture capacity, but it does not solve distribution.
Across Dragonite, Roaring Moon, Jigglypuff and Diglett it retains 81.5% of the
current disk size at Q95 and 66.2% at Q90. Applied to the current 39.1 GiB
full-catalog projection, that remains approximately 31.9 GiB or 25.9 GiB.
Both are above the acceptable desktop target.

Resolution loss also dominates the visible error: changing the 384 px encode
from Q95 to Q90 saves another 15.3% of the 512 baseline, while mean PSNR in the
actual UI contexts changes by only 0.15–0.26 dB. Therefore spending more WebP
quality at 384 px cannot recover the detail discarded by downsampling, and
lowering WebP quality alone cannot create the required factor-five reduction.

Keep 512 px/60 FPS as the reviewed source contract. A future delivery system
may still use a lower tier as a deliberately reviewed fallback, but it must not
be mistaken for the catalog-storage solution. Selective delivery, caching and
action-level acquisition remain necessary even if a lower tier is accepted.

## Scope and method

- Four normal variants: Dragonite, Roaring Moon, Jigglypuff and Diglett.
- Front and back views; all seven actions; 6,560 source frames in total.
- Source remains the approved lossless 512×512, native-60-FPS catalog.
- Candidates resize with Lanczos to 384×384, trim each action to its scaled
  union bounds with three pixels of safety, and encode static atlas pages as
  WebP Q95 or Q90 with exact alpha.
- Quality sampling covers six evenly spaced frames per view/action: 336 samples
  per candidate and context.
- Visible RGB is measured on dark, light and purple backgrounds after scaling
  to the current battle, Summary, Summary 2× zoom, Pokédex and Pokédex 2× zoom
  presentation sizes.
- Godot 4.6.2 decodes, uploads and plays the generated atlases through the
  existing headless runtime harness. The production loader and catalogs are not
  changed; that loader intentionally requires 512 px manifests.

The PSNR reference is the approved lossless 512 master rendered at the same
final display size. The earlier Q95 packaging benchmark measured roughly
50.4–50.6 dB against that source. These measurements therefore include both
the intentional resolution loss and WebP error.

## Storage

| Candidate | Four-species bytes | Versus 512 Q95 | Projected full catalog |
|---|---:|---:|---:|
| 512 Q95 current | 106,991,522 | 100.0% | 39.1 GiB |
| 384 Q95 | 87,182,746 | 81.5% | 31.9 GiB |
| 384 Q90 | 70,865,494 | 66.2% | 25.9 GiB |

Every tested candidate retained alpha exactly after resizing. The unexpectedly
small disk reduction relative to the 43.75% pixel-count reduction confirms that
animated edge/alpha detail and texture entropy remain important contributors.

### By action, both views and all four species

| Action | 512 Q95 MiB | 384 Q95 MiB | 384 Q90 MiB |
|---|---:|---:|---:|
| damage | 5.29 | 4.30 | 3.49 |
| faint loop | 12.13 | 10.00 | 8.07 |
| faint start | 17.29 | 14.28 | 11.61 |
| idle | 12.28 | 9.99 | 8.10 |
| physical attack | 15.17 | 12.34 | 10.10 |
| sleep | 20.81 | 16.55 | 13.41 |
| special attack | 19.07 | 15.68 | 12.80 |

No action is an outlier that makes 384 px sufficient. Q95 retains 79.5–82.6%
per aggregated action and Q90 retains 64.4–67.2%.

## Quality at actual presentation sizes

| Context | 384 Q95 mean / minimum dB | 384 Q90 mean / minimum dB |
|---|---:|---:|
| battle | 37.59 / 29.35 | 37.44 / 29.28 |
| Summary | 38.58 / 30.02 | 38.42 / 29.95 |
| Summary 2× zoom | 36.11 / 29.18 | 35.95 / 29.11 |
| Pokédex | 41.78 / 32.75 | 41.52 / 32.67 |
| Pokédex 2× zoom | 38.87 / 30.60 | 38.63 / 30.53 |

The worst automated sample is Roaring Moon's back-facing sleep action. The
generated Summary 2× comparison sheet is part of the disposable benchmark
output and must still receive human motion review before any lower tier is
accepted. Static inspection shows the candidates are close at normal UI scale,
but the numbers and zoom view make clear that they are not equivalent to the
current source-quality contract.

## Desktop runtime

The second, warm-filesystem pass below loads each view/action independently.
"Action start" is the total WebP decode time for that action's atlas pages; it
is deliberately stricter than decoding only the first page.

| Candidate | Decode all actions | Median / p95 action start | Decoded atlas capacity | Max observed RSS delta | 60-FPS playback |
|---|---:|---:|---:|---:|---:|
| 512 Q95 | 7.86 s | 134.4 / 237.9 ms | 2.40 GiB | 79.1 MiB | 0 frames >20 ms |
| 384 Q95 | 5.27 s | 89.7 / 156.6 ms | 1.36 GiB | 45.6 MiB | 0 frames >20 ms |
| 384 Q90 | 4.35 s | 73.8 / 130.1 ms | 1.36 GiB | 21.1 MiB | 0 frames >20 ms |

The decoded-capacity figure is the sum of all tested atlas allocations, not a
recommended resident-cache size. Upload medians were below 0.11 ms per action
group in all three candidates. The 384 tier has a real runtime advantage, but
full-action start latency is still too high for synchronous UI loading; the
existing async page streaming and bounded caches remain required.

Godot supports these WebP pages on desktop, Android and web through the same
image path, so there is no new codec portability risk. This run only measures
the current Linux desktop. Android device and exported-web memory/latency must
be measured before a tier is shipped; desktop success is not a platform
certification.

## Reproduction

From an assigned frontend worktree:

```sh
python tools/sprite_factory/resolution_tier_benchmark.py \
  PACKAGED_512_Q95_CATALOG LOSSLESS_APPROVED_CATALOG OUTPUT_DIRECTORY

ops/worktrees/slot-env SLOT -- env \
  POKEAETHER_DISTRIBUTION_RUNTIME_CONFIG=OUTPUT_DIRECTORY/runtime-config.json \
  godot --headless --path FRONTEND_WORKTREE \
  --script res://tools/sprite_factory/distribution_runtime_benchmark.gd
```

The Python run writes `report.json`, candidate atlases,
`summary-zoom-comparison.png` and `runtime-config.json`. The Godot run writes
`godot-runtime.json`. Output is disposable evidence outside the repository and
cannot activate a catalog.
