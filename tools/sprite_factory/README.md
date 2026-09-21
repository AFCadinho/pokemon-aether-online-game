# Pokémon sprite factory V1

New SCVI imports require [catalog-backed identity evidence](SCVI_IDENTITY.md).
Use `scvi_identity.py` before source review; model resource numbers are not
National Dex numbers. `identity_batch_review.py` reruns a fixed gated cohort.

The four-species compact-sprite versus runtime-3D prototype, GPU measurements
and moving comparison tool are documented in
[BATTLE_REPRESENTATION_STUDY.md](BATTLE_REPRESENTATION_STUDY.md).

The current-quality idle-only Pokédex inventory, full-catalog size projections
and local decode measurements are in [POKEDEX_IDLE_BUDGET.md](POKEDEX_IDLE_BUDGET.md).
Reproduce with `python3 tools/sprite_factory/pokedex_idle_budget.py PACKAGED_CATALOG OUTPUT_DIRECTORY`.

Local offline toolchain for human-reviewed 512×512 RGBA battle sprites.
The established Gen 1–8 baseline is 24 FPS; a source with native 60 FPS may
explicitly select 60 in its manifest without reducing source motion quality.
Python 3 with Pillow and Blender CLI are required. Reference manifests pin Blender
5.2.0 LTS and the exact input SHA-256. Default Blender command is
`flatpak run org.blender.Blender`; override `--blender` for another installation.
The pipeline never downloads sources, saves a blend, changes production assets,
or publishes remotely. Keep outputs outside the repository's asset directories.

## Commands

Run from the frontend worktree. `$output` below is an explicitly chosen temporary
absolute directory, and `$source` is a local read-only source path.

```sh
python tools/sprite_factory/factory.py inspect --source "$source" --output "$output/inspection.json"
python tools/sprite_factory/factory.py build --manifest tools/sprite_factory/manifests/dragonite.json --source "$source" --output "$output"
python tools/sprite_factory/factory.py verify "$build"
python tools/sprite_factory/factory.py catalog "$build" --preview --output "$output/preview.json"
POKEAETHER_RENDERED_PREVIEW_CATALOG="$output/preview.json" godot --path .
```

Inspect first. New sources need a reviewed manifest with their exact hash, rig,
action names/slots, frame selection, explicit cameras and presentation settings.
`build` repeats inspection and validates the source before rendering. Suspicious
unacknowledged findings stop the build. Linked libraries, missing connected
textures/materials and unpinned external textures block rendering. An unfamiliar
species/form is never inferred from a filename. Action-name matching only proposes
candidates in the report. Embedded text blocks and drivers require specific
manifest acknowledgement; auto-execution remains disabled.

Blender is launched with `--factory-startup --disable-autoexec` and a trusted
external script. This disables embedded Python execution, but is not an OS security
sandbox against Blender parser vulnerabilities. Inspect untrusted collections in
an appropriately isolated Blender installation. No source scripts are imported.

## Build layout

```text
output/
  inspection/<source-sha256>.json
  <canonical-species-or-form>/<normal-or-shiny>/<build-id>/
    provenance.json       # source/config/code/Blender/Pillow identity
    inspection.json       # objects, armatures, NLA, actions, materials, images
    factory.py            # archived implementation used for this build
    blender_worker.py
    render.job.json / render.job.log / render.json
    state.json
    raw-renders/<front|back>/<action>/0000.png  # original Blender PNGs
    masters/<front|back>/<action>/0000.png
    qc.json               # per-frame hashes, alpha bounds, geometry checks
    previews/index.html
    previews/<view>-contact.png / overview.png
    previews/<view>-<action>.webp
    runtime/manifest.json
    runtime/<view>/<action>-00.png
    approval.json         # only after explicit human review
```

Each invocation uses a content-addressed build directory. Existing builds are
never overwritten or silently resumed. For an independent rebuild, choose a new
output root. An interrupted build remains available for diagnosis. There is no
automatic cleanup of reference masters.

Canonical masters retain PNG pixel data and colour-profile chunks verbatim.
Blender's Date/RenderTime/File stamps and EXIF metadata are removed without
decoding or recompressing the image. This makes master file hashes stable when
render pixels match. Raw Blender outputs remain in `raw-renders`.

`finalize BUILD --output NEW_ROOT` can apply the current postprocessing to an
existing verified factory render. It requires the exact same archived Blender
worker, verifies all old master/atlas hashes and pixels, creates a new build ID
and fresh review gate, and writes new canonical masters. It never changes the
input build. `raw-source.json` records the original render location/hashes; this
build references those preserved originals rather than duplicating them again.
If the Blender worker changes, a fresh `.blend` build is required.

## Manifest contract

`manifests/dragonite.json` and `manifests/rattata.json` are executable examples.
`species` is the exact canonical client ID, including form if applicable; it is
not a Dex number. Gender variants can have separate canonical IDs when the
client supplies them. There is no implicit base-form substitution.

- `source`: filename, SHA-256, collection/version note, Blender version, exact
  accepted inspection warnings and explanation; external image hashes by name.
  The CLI supplies the machine-specific source path.
- `rig`: exact armature object. Each action may supply `slot` if ambiguous.
- `cameras`: independent front/back positions, target and fixed orthographic
  scale. All frames of all actions are checked against those cameras. The
  reference cameras preserve the human-reviewed POC framing.
- `presentation`: independent in-game scale, 512px anchor, 3D ground point,
  view-specific offsets and readability/maximum-height review bounds. Bounds
  produce warnings; they never cause automatic enlargement or downscaling.
  Current SpriteBox scaling is `2 × 0.85 / render_scale`; anchors and offsets
  use the existing SpriteBox contract. Ground point is recorded for future
  camera tooling; V1 uses the explicitly reviewed anchor/offset.
- `actions`: idle, physical_attack, special_attack, damage, sleep, faint_start,
  faint_loop. `null` means deliberately unavailable. Exact action name, explicit
  ordered source frames, source timeline FPS, loop, playback multiplier, review
  status. Frames may be fractional to sample a source timeline at 24 FPS. No
  action is selected solely because its name matches a heuristic. Optional
  `neutral_bones` names explicitly restore selected pose bones to their rest
  transforms after each source frame is evaluated. Use only for a documented
  source-layer problem, such as an idle with permanently closed eyelids; it
  does not synthesize blinking or repair facial/material animation.
- `variants`: normal/shiny share geometry, rig, cameras, actions and timing;
  explicit material replacements are supported. Missing shiny sources are
  `available:false`. No automatic recolouring. Additional variant names are
  possible in the offline schema, but the current runtime selects normal/shiny.
- `render`: pinned 512px and explicit 24 or 60 FPS, Standard/Medium High Contrast and explicit area
  lights. The source hash pins retained world/shader/Eevee source settings;
  camera/lights are replaced, and rig NLA is muted. Add explicit overrides only
  after review if a future source needs different settings.
- `review`: configured mapping is required before rendering. It never confers
  approval on the resulting images.

The source scene FPS and selected action interpretation are both recorded.
Dragonite is 24 FPS. Rattata's source scene says 25 FPS; its 24 FPS interpretation
is intentional because it reproduces the accepted POC. A faster in-game idle
(Dragonite 1.3×) changes cadence, not the rendered frame quality.

## Quality checks and review

Inspection inventories objects/material assignments, packed/external images,
actions/ranges/slots, object NLA, source FPS, evaluated bounds, embedded texts,
drivers on objects/materials/node trees/shape keys and variant-name candidates.
Disconnected active material outputs and empty/missing image nodes are flagged.
The shader dependency check handles inactive emission branches, but is not a
general-purpose shader correctness proof.

Post-render checks cover exact dimensions/mode/frame count, empty alpha, clipping
at image edges, safe margins, full evaluated mesh bounds outside the camera at
every selected frame, tiny bounds, sudden bounds jumps, duplicate loop endpoints,
static actions, unique pixel hashes, action duration, playback duration, union
bounds and alpha-weighted luminance. A nearly black/white entire render and an
unoverridden, persistent eyelid rotation in idle produce advisory warnings;
these signals cannot decide whether a dark-colored species or facial expression
is artistically correct. Source/action/range/version errors stop rendering. QC errors prevent
approval; warnings require explicit acknowledgement. Checks do not trim or drop
frames. Duplicate information is diagnostic only.

Lossless WebP previews preserve source timing with alternating 41/42ms durations.
Contact sheets are thumbnails for review; they are not runtime assets. Masters
and atlas cells remain 512px. PNG packaging copies exact RGBA, including RGB
under transparent alpha. `verify` checks hashes AND every extracted atlas frame
against its master, so an encoding or packing mistake cannot silently pass.

Human review must check eyes/face, material appearance, whether actions represent
their mapped semantics, loop seams, faint transitions, platform grounding,
relative species size, battle tempo and effects. Inspect front/back and action
previews, then play an actual local battle. Technical success leaves the build
at `needs_review`. Local preview is deliberately separate from approval.

Only after a human has reviewed that exact build:

```sh
python tools/sprite_factory/factory.py review "$build" --status approved --reviewer "NAME" --note "REVIEW EVIDENCE" --accept-warnings
python tools/sprite_factory/factory.py catalog "$build" --output "$output/approved.json"
POKEAETHER_RENDERED_CATALOG="$output/approved.json" godot --path .
```

Omit `--accept-warnings` when none exist. `--actions front/idle,back/idle` can approve
only selected view/actions. Unreviewed/rejected actions stay unavailable in the
approved path. `--status rejected` records rejection. Catalog creation verifies
the build and approval fingerprint. Editing runtime metadata invalidates its
approval; source/config/code changes produce a different build ID. Catalog paths
are local absolute paths in V1. There is no R2, launcher, web delivery or production
publication command; catalog creation is the local publication boundary.

## Runtime and fallback

`scripts/battle/battle_ui/rendered_sprite_assets.gd` uses exact species/form +
normal/shiny + view keys. The generic resolver sits before the existing asset
resolver in SpriteBox. Without a catalog it has no effect. Missing/unapproved
idle, unknown form/shiny/view, bad hashes or corrupt pages return null, allowing
the existing animated/Showdown/HOME fallback chain to run normally.

Only idle loads initially. Other actions load transactionally when requested;
all pages must pass validation before adding an animation. A missing/rejected
attack or damage uses the existing sprite tween and move/status VFX on the
available idle. Legacy assets generally have no separate attack/sleep clips;
this is a fallback to their existing behavior, not a fabricated action. Missing
sleep returns to idle while retaining status VFX. A missing faint_start uses the
existing faint tween. An available faint_start goes to faint_loop, or holds its
last frame when the loop is missing. No recovery action is inferred. Faint-loop
does not block the turn: scene/roster clearing still removes the Pokémon, and a
future recall sequence can own that removal. No recall feature is implemented.

The existing POC flags/helpers remain for regression comparison; generic assets
take precedence and require no per-species code. Cached actions currently remain
resident for the process lifetime. PNG decoding is synchronous on first use and
can hitch. These are known V1 optimization follow-ups, not reasons to reduce
quality. Desktop local review is validated here; Android/web packaging and
memory budgets need separate work before distribution. The four-species
distribution-format measurements, tooling, visual comparisons, and accepted
trimmed-WebP-Q95 distribution input are documented in
[DISTRIBUTION_FORMAT_BENCHMARK.md](DISTRIBUTION_FORMAT_BENCHMARK.md); that
benchmark does not change the runtime default.

After human approval, package any schema-1 preview or approved catalog into the
accepted distribution input without changing its review mode or activating it:

```sh
python tools/sprite_factory/package_catalog.py INPUT_CATALOG OUTPUT_DIRECTORY --workers 8
```

The command requires 512x512/native-60-FPS manifests, verifies every source
hash, trims each action to its padded union bounds, encodes WebP Q95 with exact
alpha, records visible RGB PSNR, and writes a new catalog plus
`quality-report.json`. Pages below 40 dB are identified by entry, view, action
and page for human review; this warning does not make an artistic decision.
The command refuses to overwrite an existing output and never mutates source
builds.
An approved package also receives a lightweight `preview-catalog.json` alias,
so local debug review can reuse the exact same files without duplicating the
packaged assets.

The catalog compaction benchmark is deliberately separate from packaging and
cannot activate a candidate:

```sh
python tools/sprite_factory/catalog_compaction_benchmark.py \
  PACKAGED_CATALOG LOSSLESS_SOURCE_CATALOG OUTPUT_DIRECTORY
python tools/sprite_factory/video_alpha_benchmark.py \
  PACKAGED_CATALOG LOSSLESS_SOURCE_CATALOG VIDEO_OUTPUT_DIRECTORY
python tools/sprite_factory/tight_frame_benchmark.py \
  PACKAGED_CATALOG LOSSLESS_SOURCE_CATALOG OUTPUT_REPORT
python tools/sprite_factory/webp_quality_benchmark.py \
  PACKAGED_CATALOG LOSSLESS_SOURCE_CATALOG OUTPUT_REPORT
python tools/sprite_factory/dual_plane_video_benchmark.py \
  PACKAGED_CATALOG LOSSLESS_SOURCE_CATALOG VIDEO_OUTPUT_DIRECTORY
python tools/sprite_factory/alpha_plane_benchmark.py \
  PACKAGED_CATALOG LOSSLESS_SOURCE_CATALOG \
  VIDEO_OUTPUT_DIRECTORY/report.json ALPHA_OUTPUT_DIRECTORY
python tools/sprite_factory/resolution_tier_benchmark.py \
  PACKAGED_CATALOG LOSSLESS_SOURCE_CATALOG RESOLUTION_OUTPUT_DIRECTORY
```

These tools retain 512×512 logical framing and native 60 FPS. They measure
temporal redundancy, transparent area, source quality, normal/shiny overlap,
decode/seek cost and representative alternative encodings. The optional
`variant_material_probe_blender.py` plus `variant_material_benchmark.py` pair
also measures renderer-produced normal/shiny material IDs and colour LUTs; it
must be launched against a reviewed source with Blender's auto-execution
disabled. All outputs are benchmark evidence only; human visual approval and
platform runtime support remain separate gates.
The controlled 384 px/Q95/Q90 experiment, including measurements at the actual
battle, Summary and Pokédex display sizes, is documented in
[RESOLUTION_TIER_BENCHMARK.md](RESOLUTION_TIER_BENCHMARK.md). It preserves the
512 px masters and does not produce a runtime-compatible catalog.
The action-routing checks exercise the single-battle SpriteBox path used by the
POCs. Other battle modes still need their own visual/action validation before
general release; they are not certified by these two species tests.

## Regression evidence

```sh
python -m unittest discover -s tools/sprite_factory -p 'test_*.py' -v
python tools/sprite_factory/compare.py "$build" "$old_poc/master/dragonite" --poc --output "$output/poc-comparison.json"
python tools/sprite_factory/compare.py "$build" "$independent_build" --output "$output/rebuild-comparison.json"
```

The Godot check `tests/check_rendered_sprite_assets.gd` uses a preview catalog
containing both references. Run it through the assigned slot environment. It
tests lazy actions, missing shiny/forms, partial rejection, corruption, idle
fallback for sleep, attack routing, nonblocking faint hold and preview isolation.

Build identity records config/source/implementation/Blender build/Pillow. Exact
pixel reproduction is checked on this machine; GPU drivers/hardware and Blender
changes can alter rendering. Do not promise cross-GPU bit identity. Preserve the
evidence and re-review outputs when the environment changes.

The local Gen 1 body-shape validation used Articuno, Machamp, Abra, Onix, and
Parasect where the originally proposed sources were unavailable. Its manifests,
render evidence, caveats, and local review instructions are in
[SHAPE_VALIDATION.md](SHAPE_VALIDATION.md). These remain `needs_review`; no bulk
conversion or production approval follows from the technical checks.
