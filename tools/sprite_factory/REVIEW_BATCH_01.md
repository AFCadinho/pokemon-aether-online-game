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

### First in-game tuning feedback

The first development battle review found Dragonite and Roaring Moon visually
good. Articuno was too small; its data override now uses front/back runtime
render scales `2.15`/`2.35` instead of the automatically proposed
`2.70543`/`2.96432`. Eevee floated above both platforms and read too dark; its
front/back offsets now move it down by 35/32 pixels, and its data-defined key,
fill, rim and world lighting are moderately brighter. Normal Eevee, shiny Eevee
and normal Articuno were rebuilt at the unchanged 512×512/native-60-FPS
baseline and passed technical QC. The previous builds remain recoverably
quarantined for comparison. These variants remain `needs_review` until the
corrected in-game presentation is accepted.

The next battle review found Lucario, Charizard and Pikachu too high. Charizard
was also too small, and all three appeared closed-eyed. The SCVI channel files
showed normal visibility and eye UV offsets; the skeletal sources instead use
partial facial actions which inherit an existing pose in-game. Blender had
been evaluating omitted eyelid tracks from the closed bind pose. The adapter
can now make that inherited state explicit from a reviewed facial donor action
and records every injected eyelid bone in `import.json`. Lucario, Charizard and
Pikachu use `defaultidle01` as their open-eye donor, while the battle idle and
its native 60 FPS timing remain unchanged. Their vertical presentation offsets
were lowered, and Charizard's runtime scale was increased. Full idle masters
for both views were rebuilt at 512×512/native 60 FPS with zero QC errors or
warnings. They remain `needs_review`.

The following platform review lowered both views of Eevee, Lucario, Charizard,
Pikachu and Articuno again. Grounded Pokémon now use the visible platform as
their baseline. Charizard and Articuno retain a deliberate airborne gap, but
no longer hover as far above it. This is a data-only runtime presentation
adjustment: master pixels, lighting, scale, resolution and native 60 FPS remain
unchanged. All five still require in-game review.

The battle client applies one shared `1.30` display multiplier to every asset
loaded through the rendered-sprite resolver. Species/form scale ratios and
front/back manifest differences remain intact, while the whole rendered cast
has more visual weight relative to the HUD. Scaling uses the existing
per-view anchor, so reviewed ground and hover positions remain the pivot. This
review-only route does not resize legacy, Showdown, HOME or content-pack
fallbacks. The single-battle HP panels are correspondingly narrower and
shorter, with reduced padding and a thinner HP bar, while retaining the
existing text sizes needed for names and levels.

Runtime action metadata now carries the alpha-derived visible bounds already
measured during factory QC. Summary and Pokédex previews use those bounds to
fit the actual Pokémon instead of the transparent 512×512 canvas. Older local
review builds without this optional metadata derive and cache the idle bounds
once while loading. The Pokédex list remains icon-only, while a selected
rendered Pokémon warms its opposite view after first display so front/back
review does not repeatedly decode lossless atlases. The shared rendered-view
cache is LRU-bounded to eight views, preventing long Pokédex sessions from
retaining an unbounded number of full-quality atlases.

For local development review, a machine-local ignored file at
`.pokeaether/rendered-preview-catalog` may contain the absolute path of the
preview catalog. Debug builds use it when the explicit
`POKEAETHER_RENDERED_PREVIEW_CATALOG` environment variable is not set, so
`godot .` remains sufficient on a configured checkout. Release builds and
machines without that file retain the approved-catalog/fallback behavior.
