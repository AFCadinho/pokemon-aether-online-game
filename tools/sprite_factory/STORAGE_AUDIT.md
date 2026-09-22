# Realtime 3D storage audit — 2026-09-22

**Historical evidence, not an active optimization plan.** The resulting
component-sharing experiment is closed as **promising but not production-safe**.
Keep the existing standalone model format. Further sharing, deduplication and
codec research is deferred until catalog size becomes a practical problem;
see [CATALOG_PRODUCTION_STATUS.md](CATALOG_PRODUCTION_STATUS.md).

## Decision

The current 11.82 MiB average is **not demonstrated to be a lower bound**.
Textures dominate, and a lossless, deduplicated component budget is about
7.28 MiB/model. This justifies one bounded packaging prototype, not a promise
that a playable release will be 6–8 MiB/model. No playable optimized catalog
was produced, and nothing in the pipeline, renderer, installed catalogs or
approvals was changed. In particular, do not lower texture resolution or
remove material-response endpoints on this evidence.

Prioritize exact sharing inside each model and between its normal/shiny forms.
Do not build elaborate cross-species deduplication: measured identical texture
payloads between different species contribute only about 4.5 KiB compressed
after within-model deduplication.

## Scope and integrity

All 75 existing normal-form screened scenes were loaded and their SHA-256
checked before and after inspection. Catalog SHA-256:
`e3f7f36ff5b8ad51a586afca2e6043251ab43e590f5bf1a3b767b4f295214733`.
The source model hashes are in `storage_audit_results.json`.
No mesh conversion, resampling or animation regeneration was performed.

Six existing normal/shiny pairs provide separate variant evidence: Articuno,
Dragonite, Lucario, Pikachu, Roaring Moon and Snorlax. These are older reviewed
control packages, not shiny versions of all 75 screened entries. The earlier
launcher-test installation's normal Arcanine file failed its manifest hash and
was excluded; its orphan shiny is not used to estimate a pair. This is not a
failure in the 75-model screened catalog. The invalid input was not repaired.

## Actual file and container measurements

| Existing 75 normal models | MiB |
| --- | ---: |
| Original SCN files | 886.378 |
| Mean per model | 11.818 |
| Same scenes re-saved with Godot FLAG_COMPRESS | 886.409 |
| PCK containing all original model files | 886.384 |
| Additional Zstandard compression of each original SCN | 872.412 |

All originals have the `RSCC` compressed-resource header. Merely repacking or
re-saving does not materially shrink them; the additional Zstandard layer
saves 1.58%. PCK measurement uses Godot 4.6.2 PCKPacker with default options.
It is the model payload container, not a complete application export, CDN
transfer, encrypted launcher archive or compression-level sweep. Resaves are
temporary audit outputs, not replacements. Model sizes range 3.26–26.05 MiB.

## What occupies the data

Compressed SCN bytes cannot be additively assigned to individual resources:
compression context, metadata and resource references affect the result. The
table deliberately gives **independent lossless component storage proxies**,
not claimed percentages of the 886 MiB file total.

Textures are measured as their stored Image byte payload (including existing
mipmaps), then independently compressed using Godot's Zstandard compressor.
Distinct in-memory texture resources are counted once per scene. Meshes are
serialized from copies without material references; animation and Skin
resources use standalone compressed Godot serialization. Skeleton hierarchy
and rest poses are measured separately as serialized Variant data.

| Component, across 75 models | Independent compressed proxy, MiB |
| --- | ---: |
| Base/albedo textures | 90.456 |
| Normal textures | 131.010 |
| Roughness textures | 72.646 |
| Material-response endpoint 0 | 140.519 |
| Material-response endpoint 1 | 134.016 |
| Other textures | 0.125 |
| Meshes, excluding materials | 8.764 |
| Animations | 41.240 |
| Skin bindings | 0.211 |

Skeleton hierarchy/rest data adds about 0.416 MiB **uncompressed serialized**.
Textures account for about 92% of this independently encoded component budget,
not necessarily 92% of the original compressed files. The two response endpoints
alone are almost half of the texture budget. They preserve lighting-dependent
source colors and cannot simply be deleted. Base textures are still used by
the separate standard-material preview paths, so they are not universally dead.

### Exact duplicate textures

Equality includes dimensions, format, mipmap presence and SHA-256 of all pixel
bytes. This does not merge merely similar images or images with different mips.

- Independent compressed texture sum: **568.77 MiB**.
- Exact duplicate content inside individual models: **73.14 MiB** of that sum.
- Additional duplicates between species: **0.0044 MiB**.
- Globally unique texture budget: **495.63 MiB**.
- Unique textures + mesh/animation/binding proxies + skeleton serialization:
  **546.26 MiB**, or **7.28 MiB/model**.

This last number excludes a newly designed manifest, material references,
alignment, loader format and package overhead. It mixes explicitly identified
lossless encodings and is a sizing target for a prototype, **not achieved
download size or an exact predicted saving**. Six MiB average is not supported
by this measurement alone. Generic per-resource identity sharing needs runtime
ownership and rendering tests before shipping.

## Shiny: sharing exists in content, not current packaging

The six controls total **71.42 MiB normal + 69.98 MiB shiny** as currently
installed independent SCNs. Shiny therefore adds almost another full catalog
for this sample.

The standalone mesh resources match byte-for-byte across each pair. Resource
IDs make raw animation/Skin files differ, so a second comparison inspects
stored content without resource identity fields. All six skeleton hierarchies
and rest poses, all six sets of skin bindings and **42/42 animation clips**
match, including track paths, keys, lengths and looping data. Comparison uses
Variant semantic equality; independently serialized NodePaths are not used
as a semantic equality test. Results and source hashes are in
`storage_variant_results.json`.

| Pair | Current extra shiny SCN, MiB | New unique shiny texture payload, independently Zstd-compressed, MiB |
| --- | ---: | ---: |
| Articuno | 7.48 | 1.29 |
| Dragonite | 11.70 | 3.69 |
| Lucario | 11.22 | 1.89 |
| Pikachu | 11.84 | 2.87 |
| Roaring Moon | 23.32 | 6.47 |
| Snorlax | 4.43 | 0.73 |

The right column is only the incremental unique image payload relative to that
pair's normal form, **not a complete shiny package**. A shared model plus variant
materials has a sound basis here. This does not prove all future forms/skins
share topology or skeletons; that must remain an explicit compatibility gate.

## RAM and VRAM are separate

The 75 scenes contain **2,734.23 MiB of logical Image pixel payload**, including
duplicates and existing mipmaps: 19.12–74.37 MiB/model, mean 36.46 MiB. Identical
content deduplication lowers the catalog-wide payload to 2,309.85 MiB.

These are **not process RSS or measured GPU allocations**. GPU formats can
expand RGB data, caches can retain source and upload copies, and geometry,
animation objects, shader state, arena resources, MSAA and the two lighting
viewports add memory. Conversely, an actual battle should not hold all 75
models. This audit does not claim a runtime RAM/VRAM saving or compare a full
3D battle against legacy pixel sprites. Packaging compression alone does not
reduce decoded pixel payload. A subsequent prototype needs cold/warm load and
actual residency measurements with equal teams, camera, arena and renderer.

## Recommended bounded next step

Use a small existing sample (including Dragonite/Roaring Moon normal+shiny and
Cloyster), not a new batch of species. Build an alternate **lossless** package
with exact shared texture resources and common model/animation data for proven
compatible variants. Compare rendered poses, animation timing, eye/material
behavior, cold load, repeat battles, eviction, download bytes, RAM and VRAM.
Keep the original catalog as rollback and preserve hash validation. Approve the
new format only after this experiment; then consider larger production batches.

## Reproduction and tests

`storage_audit.gd`, through the assigned slot environment, takes absolute
`STORAGE_AUDIT_CATALOG`, optional `STORAGE_AUDIT_SHINY_CATALOG` and a fresh
`STORAGE_AUDIT_OUTPUT`. The run used OpenGL Compatibility with Godot 4.6.2.
`storage_variant_audit.gd` takes the shiny catalog and `STORAGE_VARIANT_OUTPUT`.
`summarize_storage_audit.py REPORT OUTPUT` produces the checked-in condensed
report. Raw local evidence is `.tmp/storage-audit-02/`; partial run 01 is not
the final evidence. PCK and temporary component/resave files stay local.

Checks: 75/75 primary input hashes preserved; 13 valid control files inspected;
six semantic normal/shiny pair comparisons passed; Python tests cover disjoint
within/between-model duplicate buckets and incremental shiny texture counting.
The semantic comparator also checks that changing animation length is detected
while changing a resource label is ignored. No full integration gate, release,
production access or player-visible change occurred.
