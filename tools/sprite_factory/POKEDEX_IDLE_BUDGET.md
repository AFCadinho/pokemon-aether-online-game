# Local Pokédex idle budget — 2026-09-20

The current approved 512×512/native-60-FPS/Q95 idle animations are substantially
smaller than the complete battle catalog. Front + back idle occupies 12.85% of
the 24-entry atlas bytes. No reduced-resolution export is needed to establish
this saving: exclude the six other actions from the initial Pokédex download.

## Measured inventory

All manifests, idle atlas pages and still previews were SHA-256 verified.
Atlas dimensions and frame totals were checked against each manifest.

| Existing sample | Entries | Idle atlas bytes | Including still previews | Mean front + back per entry |
|---|---:|---:|---:|---:|
| Normal | 22 | 62,220,924 | 63,015,664 | 2.73 MiB |
| Shiny | 2 | 4,239,468 | 4,298,812 | 2.05 MiB |

Normal entries range from 1.60 MiB (Umbreon) to 5.17 MiB (Scizor), including
the two still previews. The four earlier benchmark species are not the whole
sample; this inventory uses every currently packaged entry.

## Full-catalog estimates

| Species count | Normal front/back | Normal + shiny, separate sample means | Normal + shiny, equal-size assumption |
|---|---:|---:|---:|
| 151 | 0.40 GiB | 0.71 GiB | 0.81 GiB |
| 500 | 1.33 GiB | 2.33 GiB | 2.67 GiB |
| 1,000 | 2.67 GiB | 4.67 GiB | 5.34 GiB |

These are projections for hypothetical species counts, not an inventory of
the final game's forms. They include existing still previews but exclude
future package metadata, icons, text, download/update overhead and filesystem
allocation. Their contribution must be counted when building an actual pack.

Only Dragonite and Eevee have shiny samples. Their shiny idle atlases are
93.4% and 90.5% of their corresponding normal atlases. The lower shiny mean
largely reflects species selection, so 4.67 GiB is an optimistic extrapolation.
Use approximately **5.3 GiB for initial desktop planning**, with additional
headroom as more species/forms are measured. This is not a statistical bound.

## Local loading and memory

Godot 4.6.2 headless on this Linux desktop, second filesystem-warm pass:

| Work, per species variant and view | Median WebP decode | p95 | Maximum |
|---|---:|---:|---:|
| Entire idle | 89.43 ms | 161.13 ms | 165.07 ms |
| First page, normally eight frames | 7.29 ms | 12.04 ms | 12.38 ms |

There are 48 view samples. Median file reads were 0.63 ms for an entire idle
and 0.05 ms for a first page. The first-page run follows the full-idle run,
so it is intentionally warm, not a cold-start result. Hash validation,
per-frame extraction, mip generation, actual preview callbacks and UI frame
timing are not measured by this generic atlas harness.

Headless uploads and frame scheduling do **not** validate GPU upload costs,
visible 60-FPS playback, Android, browser export or whole-game smoothness.
Native 60-FPS source timing is preserved; this task does not certify playback.

The existing portrait loader extracts trimmed cells and generates mipmaps per
frame. Derived RGBA+mip capacity is a median 33.49 MiB per view and a maximum
65.15 MiB. Front/back pairs range from 34.20 to 124.58 MiB. These are texture
payload estimates, not measured VRAM or total RAM: temporary decoded atlases,
allocator overhead and cache behavior add costs.

Installing all idle files on disk is feasible independently of loading them
into memory. Do not decode the complete Pokédex at startup. To make entries
immediately animate, preload the selected entry and likely next entries;
retain a bounded cache of decoded front/back previews. The required startup
prefetch and cache policy must be validated in the real UI before promising
instant opening under all conditions.

## Delivery implication

For desktop, an installed idle-only Pokédex package is a credible option at
roughly 5.3 GiB for 1,000 normal + 1,000 shiny variants. Whether that install
budget is acceptable is still a product decision. It is far below the previous
39.1 GiB all-action estimate, but it is not a tiny initial download, especially
for mobile or web.

Use the same installed idle assets for Pokédex, Summary and battle idle.
Battle packages can contain only the additional actions, avoiding duplicate
idle downloads/storage. Shiny inclusion can be decided separately, but this
report includes it because complete local coverage was the requested budget.

This task changes measurement tooling/documentation only. It neither packages
nor activates delivery, changes the game, removes review buttons, nor changes
sprite quality. Next implementation evidence should be a local idle-only pack
and an actual Pokédex navigation/preload test using it.

## Reproduce

From an assigned frontend slot:

```sh
python3 tools/sprite_factory/pokedex_idle_budget.py PACKAGED_CATALOG OUTPUT_DIRECTORY
```

From the workspace root, with explicit absolute output and frontend paths:

```sh
ops/worktrees/slot-env SLOT -- env POKEAETHER_DISTRIBUTION_RUNTIME_CONFIG=OUTPUT_DIRECTORY/runtime-config.json godot --headless --path FRONTEND_WORKTREE --script res://tools/sprite_factory/distribution_runtime_benchmark.gd
```

The inventory writes `report.json` and `runtime-config.json`; the Godot harness
writes `godot-runtime.json`. Existing output directories are refused. Source
files are referenced read-only; there is no asset copying or catalog activation.
This run's inventory is in `.worktrees/slot-c/.tmp/pokedex-idle-budget-02/`;
identical input page timing is in
`.worktrees/slot-c/.tmp/pokedex-idle-budget-01/godot-runtime.json`.
