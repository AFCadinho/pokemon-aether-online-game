# First SCVI-first review batch

This is a local, intentionally limited **review batch**, not a production
catalog. The explicit 15 species and approximate in-game target heights are in
`review_batch_01.json`. The identities are inspected as `pmNNNN_00_00` only
after checking the local model and animation directories **and visually checking
the source icon**. An initial `pm0959` guess was visibly not Tinkaton and was
quarantined before rendering; Gardevoir `pm0282` replaced that candidate.
Species/form identity,
eyes, shaders, action semantics, cameras, platform position, size, shiny colour,
and loop transitions still require human in-game approval.

The `scvi_batch.py` source adapter imports raw Scarlet/Violet model, rig,
textures, official rare materials, and selected `.tranm` action **candidates**.
It is deliberately separate from the generic Sprite Factory. It pins the
ChicoEevee importer at commit `b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04`,
preloads its local shader, supplies dependencies locally, disables Blender
auto-execution, and runs Flatpak without network and with the raw roots read-only.
Its generated `.blend` files pack textures. Every raw file used for import is
hashed in `import.json`. Unknown/missing sources block rather than falling
through to an unverified collection. The adapter does **not** execute embedded
scripts from a source file.

The first composition pass renders **full-resolution 512×512 RGBA idle at native
60 FPS** for front and back. It does not downsample. Full action manifests are
prepared separately; they are only rendered after intake and camera/face/scale
checks. This avoids spending hours on six extra actions with an obviously bad
camera or shader. A successful import or technical QC never means approval.

## Local commands

Run from the assigned frontend worktree. Supply absolute local paths; the
source roots and pinned importer must already exist. Keep output in the
assigned slot's `.tmp`, not under `assets/`.

```sh
python tools/sprite_factory/scvi_batch.py inventory --model-root "$model_root" \
  --motion-root "$motion_root" --importer "$importer" \
  --python-deps "$deps" --output "$output"
python tools/sprite_factory/scvi_batch.py run-intake --idle-only \
  --model-root "$model_root" --motion-root "$motion_root" \
  --importer "$importer" --python-deps "$deps" --output "$output"
python tools/sprite_factory/scvi_batch.py run-probes --idle-only \
  --accept-unused-nodes --model-root "$model_root" --motion-root "$motion_root" \
  --importer "$importer" --python-deps "$deps" --output "$output"
python tools/sprite_factory/scvi_batch.py run-builds --idle-only \
  --accept-unused-nodes \
  --model-root "$model_root" --motion-root "$motion_root" \
  --importer "$importer" --python-deps "$deps" --output "$output"
python tools/sprite_factory/scvi_batch.py preview-catalog \
  --model-root "$model_root" --motion-root "$motion_root" \
  --importer "$importer" --python-deps "$deps" --output "$output"
POKEAETHER_RENDERED_PREVIEW_CATALOG="$output/preview-batch.json" \
  ../../../ops/worktrees/slot-env slot-a -- godot --path .
```

`run-intake` resumes a verified existing import and records per-species
failure/warning state. Existing changed/partial results are never silently
overwritten. `run-builds` independently verifies existing completed builds and
only includes zero-error, `needs_review` results in a preview-only catalog.
`preview-catalog` combines available normal/shiny and idle/full review builds,
preferring full builds, and writes `review-index.html` for quick inspection.
`--accept-unused-nodes` is an explicit acknowledgement of factory warnings
for disconnected empty image nodes only; any other warning still blocks.
`run-probes` creates a separate, non-catalogued front/back one-frame triage
index before spending time on full 60-FPS animations. An already complete idle
build can be reused there without altering it. Examine
`$output/probes/normal/index.html` for facial/camera faults. A probe is never
enough to approve a Pokémon or validate its motion.
The full action pass uses the same commands without `--idle-only`, and shiny
uses `--variant shiny` only when official `_rare.trmtr` plus rare albedo are
present. Neither command approves, pushes, deploys or switches a default.

The initial action mappings are filename-ranked **candidates**, not evidence
of the correct artistic motion. Within an action type, `200xx` candidates
are preferred where available; the exact selection and alternatives are in `intake.json`. The
`battlewait01_loop` name takes priority over `defaultwait01_loop` even when
its numeric prefix ranks lower. Where only `defaultwait01_loop` exists, it is
still merely a candidate. A short alternate-defaultwait probe for Pikachu
also showed closed eyes and was quarantined. Pikachu, Psyduck and Arcanine
currently have explicit visual-review warnings for closed eyes; technical QC
alone did not identify those poses. Do not mark them approved without a facial
import/material fix and a new in-game review.

The
source adapter measures the entire selected motion in both camera views for
technical framing, while the in-game scale is derived separately from the
explicit per-species target height and idle silhouette. These are draft
settings. They must be adjusted in the per-species manifest if preview shows
bad relative size, ground pivot, floating position, camera or clipping.
Known-good POC choices for Meowth, Dragonite and Roaring Moon are explicit
batch-data overrides: Meowth's persistent idle eyelids are neutralized, its
sleep candidate is left unmapped, and its camera/light/scale/platform settings
match the prior reviewed local preview. The other two retain their accepted
camera/presentation/lighting references. No renderer species checks were added.

This batch remains subject to the separate IP/distribution assessment for
official source data and derived images. Local review does not grant a right
to publish them.

## First local execution (2026-09-19)

- 15 named species were matched to local `pm` identities by source icon, then
  normal and official `_rare` shiny sources were imported/inspected. All 30
  one-frame front/back probes completed with zero technical QC errors.
- 12 normal and 3 shiny variants were fully rendered for **idle only** at
  512×512/60 FPS. They produced 2,554 master PNG frames (front and back),
  approximately 470 MiB of canonical masters and 185 MiB of lossless runtime
  data. The entire local working output, including raw duplicates, imports,
  probes and recoverable quarantines, is approximately 2.1 GiB.
- The preview catalog has 15 `needs_review` entries: normal Charizard,
  Pikachu, Psyduck, Meowth, Arcanine, Gengar, Scyther, Eevee, Articuno,
  Dragonite, Lucario and Roaring Moon; shiny Eevee, Dragonite and Roaring Moon.
  Gyarados, Mewtwo and Gardevoir remain probe-only. No production/default
  catalog entry was changed.
- A focused Godot headless test loaded front/back 60-FPS idle and an official
  shiny variant through the preview resolver, and confirmed that missing
  actions/variants still use fallback.
- Human review blocked automatic full-action rendering: Pikachu, Psyduck,
  Arcanine and Gengar have persistent closed-eye poses despite zero QC errors;
  Gyarados facial presentation needs comparison to the earlier correction;
  Gardevoir's front camera is too side-on; Mewtwo's front pose hides the face.
  A second `defaultwait` candidate did not open Pikachu's eyes, and simply
  neutralizing Arcanine eyelid bones did not help. These are source/facial or
  camera issues, not reasons to lower resolution/FPS. The attempted candidate
  imports and an early failed render were moved to the temporary quarantine,
  not deleted.
- Exact action semantics, attack/faint timing, platform placement and
  animation loop quality have **not** yet passed human review. The full action
  manifests are candidates only; run the full-action pass on chosen species
  after reviewing the idle batch in-game and correcting any facial/camera
  problems. This is deliberately not a bulk-production success claim.
