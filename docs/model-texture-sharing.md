# Model texture sharing proof

## Result — 2026-10-07

There is a further opportunity to share **identical** model textures without
resizing, changing colours, removing details or re-encoding images. This task
is an offline proof, not a new runtime cache or approved asset release.

The audit covers **54 approved appearances / 27 normal/shiny pairs** available
in the owned slot: the three Galar birds and 24 Mega pairs. Each source SHA is
bound to the release registry, and each entire decompressed resource stream
matches the v11 lossless binding. The cohort is biased towards these forms;
it is not a survey of all 2,400 appearances.

| Measurement | Result | Meaning |
| --- | ---: | --- |
| Distinct texture objects in the 54 files | 634 | Repeated references to one object count once |
| CPU image payload, including all existing mips | 867.10 MiB | Not total process RAM or GPU allocation |
| Strict duplicates within individual files | 7.50 MiB | Four appearances have matching texture names/properties |
| Strict duplicates when each normal/shiny pair is considered together | 249.65 MiB / 28.79% | Includes within-file duplicates; potential image payload saving, not installed-file savings |
| Four source scenes with the existing v11 codec | 30,266,003 bytes | Identical Zstd level 9 / 262,144-byte blocks |
| Same four scenes after texture sharing | 29,076,419 bytes | **1,189,584 bytes / 3.93%** less installed scene data |

The current full v11 collection contains approximately **11.97 GiB** of native
scene files, before bundle manifests, arenas, game files and temporary update
space. The 28.79% figure must not be applied to that collection size: it is a
decoded image-payload opportunity in this particular cohort.

## Concrete candidates and quality checks

The four candidates are Zapdos Galar and Moltres Galar, normal and shiny.
They share only duplicate **ImageTexture** objects whose full image bytes,
format, dimensions, all mips, resource name, metadata and stored properties
match. Textures marked `resource_local_to_scene` are excluded. Different
normal/shiny colours, eye textures or material parameters cannot share a key.

- Every candidate has the same semantic scene fingerprint before rewriting,
  after rewriting, and after saving/reloading. This includes node values,
  material properties, nested response endpoints, geometry, animation tracks,
  signal connections and metadata. Paths/editor subresource labels are excluded;
  PackedScene's internal variant-table indices are checked through SceneState
  values because Godot can rebuild those indices.
- **40 source/candidate image comparisons are byte-exact** at 512 × 512 with
  MSAA 4, both views, idle, physical attack, special attack, sleep and faint.
  Both normal and shiny are included. Native host renderer: Godot 4.6.2 Mobile
  Vulkan on NVIDIA RTX 3070 Laptop.
- Each source was also loaded and rendered a second time. Six repeat-source
  frames differed by one pixel, demonstrating tiny renderer variability even
  without rewriting. The successful candidate comparison had zero differing
  pixels. An earlier candidate run had the same one-pixel scale of variation;
  it was retained and is not counted as an exact pass.
- Host `RENDER_TEXTURE_MEM_USED` falls by **2,799,616 bytes (2.67 MiB)** for each
  Zapdos variant and **1,147,904 bytes (1.09 MiB)** for each Moltres variant.
  These are per-process texture counters after settling, not physical phone
  RAM, total VRAM, a concurrent allocation sum or an FPS result.
- The actual Galar sources use response schema 0; no irradiance actor clone is
  expected. The fixture separately verifies that nested schema-1 endpoint
  references and animation tracks survive sharing and save/reload. A real
  schema-1 two-pass actor still needs a rendered comparison before adoption.
- The packed scene weak reference clears after every presentation release.
  The diagnostic pool's ownership test also releases its texture. Existing
  two-entry / 64 MiB source-budget LRU and production lifecycle are unchanged.

The storage comparison also re-saves an unchanged control before rewriting:
30,266,309 bytes with the identical v11 codec, only 306 bytes above the original
four-file total. This separates sharing from ordinary serialization differences
and avoids crediting different compression settings for the saving. All
normalized containers decompress exactly. Candidates have new resource bytes
and hashes; they do **not** satisfy the existing v11 raw-stream receipts.

## Boundaries and next step

No approved models, index, production settings, downloads or caches were
replaced. No R2 upload, release, deployment or Android application change was
performed. Android/browser remain on their current supported presentation
policy. The external source drive and a physical Android phone were unavailable.

Most strict duplicate bytes are shared **between** normal/shiny files, rather
than inside one file. The current self-contained files cannot share an embedded
GPU texture across separate loads. `CACHE_MODE_IGNORE` deliberately isolates
their subresources; changing it to reuse does not perform content deduplication
between different paths. See [Godot ResourceLoader](https://docs.godotengine.org/en/4.6/classes/class_resourceloader.html).

Recommended next proof: a small bundle with shared texture resources for both
appearances, including a common base species and a schema-1 response actor.
Measure the actual compressed/install size and loading time, preserve the
approved geometry/poses and every image byte, verify fixed-pose rendering and
bounded ownership, then exercise the native Android debug loader. External
dependencies also affect hash validation, installation paths and LRU admission;
they require an explicit model/bundle contract rather than a global strong
texture pool. Do not introduce per-encounter GPU image readback/hashing.

This result justifies that next experiment. It does not yet justify a bulk
rewrite or new model index.

## Tooling and evidence

- `model_texture_audit.gd`: offline resource graph inventory, semantic digest
  and conservative reference sharing. Requires CPU images under dummy rendering.
- `model_texture_sharing_probe.gd`: source hash/dependency checks, offline
  control/candidate generation and exact semantic save/reload comparison.
- `summarize_model_texture_sharing.py`: verifies all v11 decoded bindings,
  independent pair totals and storage controls using the existing codec.
- `model_texture_render_probe.gd`: production presenter/material helper,
  fixed-pose captures, repeat-source control and release checks.
- `model_texture_sharing_check.gd`: distinct object accounting; colour, alpha,
  dimensions, mips, name, metadata/local ownership rejection; nested endpoints,
  animation save/reload and diagnostic owner release.
- `model_texture_sharing_results.json`: tracked measurement receipt, source
  fingerprints and evidence SHA-256 pins. Explicitly prototype-only.

Successful evidence is retained under `.tmp/model-texture-sharing/`:
`probe-v7/report.json` (54-file audit), `four-v1/` (four candidate/control files),
`v11-proof/` (codec controls and normalized candidates), and `render-v5/`
(all 40 exact comparisons, 40 repeat-source controls and texture counters).
Earlier attempts are retained, including the diagnostic parse/settings/schema
assumption fixes and the initial unstable binary NodePath fingerprint. The
fingerprint now hashes NodePath's semantic representation.

Run through the assigned slot; inputs and fresh outputs belong to its `.tmp`:

```sh
ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_model_texture_sharing_probe.py \
  --mode audit --input .worktrees/slot-c/frontend/.tmp/model-texture-sharing/input.json \
  --output .worktrees/slot-c/frontend/.tmp/model-texture-sharing/new-audit

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/summarize_model_texture_sharing.py \
  --audit .worktrees/slot-c/frontend/.tmp/model-texture-sharing/new-audit/report.json \
  --candidates .worktrees/slot-c/frontend/.tmp/model-texture-sharing/four-v1/report.json \
  --output .worktrees/slot-c/frontend/.tmp/model-texture-sharing/new-normalized

ops/worktrees/slot-env slot-c -- python3 .worktrees/slot-c/frontend/tools/run_model_texture_sharing_probe.py \
  --mode render --input .worktrees/slot-c/frontend/.tmp/model-texture-sharing/new-normalized/render-input.json \
  --output .worktrees/slot-c/frontend/.tmp/model-texture-sharing/new-render

ops/worktrees/slot-env slot-c -- godot --headless --path .worktrees/slot-c/frontend \
  --script res://tests/model_texture_sharing_check.gd
```

The wrapper temporarily removes autoload/plugin startup only in its assigned
slot project and restores the original bytes on completion/interruption. It
rejects unowned input/output paths, existing output/logs and engine/script
errors. ResourceSaver's binary Zstd compression is documented in
[Godot ResourceSaver](https://docs.godotengine.org/en/4.6/classes/class_resourcesaver.html).
No full release certification was run.
