# Screened 100: six battle placement recoveries

The six previously held normal/shiny pairs had complete source and rendered
models. Their 60 Hz placement samples intersected the battle HUD proxy;
Dondozo also left the camera frame. A smaller scale for each species resolved
those measurements without changing model geometry or animation timing.

| Species | Battle scale | Smallest idle height at 1152×648 |
| --- | ---: | ---: |
| Charizard | 0.85 | 98.7 px |
| Corviknight | 0.65 | 104.6 px |
| Dondozo | 0.40 | 98.4 px |
| Gyarados | 0.80 | 112.8 px |
| Haunter | 0.90 | 95.1 px |
| Mewtwo | 0.90 | 92.3 px |

All 96 sampled views (four actions, two sides, Classic and Stadium) now fit the
camera without model/HUD intersection. Each clip was resampled at 60 Hz and
given a new grounded sleep and motion-clearance profile. Independent 120 Hz
half-frame checks kept every model at least 0.024 m above the flat floor.
The rendered idle and faint views were inspected after scaling.
The offline resolver check now uses the pinned lift value, matching the game;
Mewtwo exposed a last-bit difference when the lift was freshly remeasured.

The real battle presenter passed three rounds (Classic, Stadium, Classic)
with all six normal/shiny pairs, faint/replacement, cache eviction and reload.
The highest frame p95 was 17.382 ms; the largest load dispatch was 2.393 ms;
there were no uncovered stalls over 100 ms. Scene hashes and the exact
machine-local report hashes are pinned in
[`screened_100_placement_recovery.json`](screened_100_placement_recovery.json).

The game and launcher reviewed registries now contain 82 approved pairs.
Fourteen source/material cases remain normal-only in the screened registry.
Six independent local bundles (normal and shiny per species) total 156,357,668
bytes at
`/home/adinho/Documents/3d_models/PokeAether/screened-100-placement-recovered-bundles-v1`.
Their pinned index and archive hashes are in
`release/approved_3d_placement_recovery_v1.json`. They are prepared locally;
the v3 R2 index and desktop manifest still contain the prior 76 species.

All 12 scenes were also extracted from those six archives and loaded through
the real battle presenter for another three Classic/Stadium/Classic rounds.
The largest frame p95 was 17.396 ms, with no uncovered stall over 100 ms.
The packaged battle report hash is pinned in the local release receipt.

The diagnostic uses a flat floor and HUD proxy. The battle presenter stress
exercises the actual client loading and animation behavior, but cannot cover
every possible camera angle or interpolated pose. Each species has its own
bundle for a targeted later correction.
