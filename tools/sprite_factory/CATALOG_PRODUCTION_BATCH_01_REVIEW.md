# Catalog production batch 01: staged qualification (2026-09-25)

The batch has 18 normal SCNs that passed the offline battle, HUD and replay
screens. Fourteen now also have hash-bound shiny GLBs/SCNs and passed paired
runtime screening. Ampharos, Slowbro, Pineco and Larvitar shiny are in a
material review queue; the original seven source/export holds remain separate.
No batch model has player-facing battle admission, release approval or a bundle.
The original static review evidence below remains part of the qualification.

## Evidence checked

- All 18 retained standalone SCNs still match their pinned SHA-256 hashes in
  `catalog_production_batch_01_results.json`.
- All 90 GLB-export images and 90 standalone-SCN images exist for the five
  sampled views per model: idle front/back, special attack front, sleep front,
  and faint-start front. The five source contact sheets were compared with the
  corresponding runtime sheets. Body parts, basic colours, and the sampled
  action silhouettes remain recognizable for every candidate. No obvious
  missing body or wholesale material swap was found in those static samples.
- The rendered Godot 4.6.2 Forward+ `local_model_review_check.gd` passed for
  all 18 models, both local preview controls, their seven native clips, and
  preview-only admission/fallback. The rendered log contains no `ERROR:` or
  `SCRIPT ERROR`. A headless invocation emits mesh-bake errors because the
  headless renderer does not register the skeleton skin; it must not be used as
  this visual check's pass result.
- The source/export `faint_start` still image and the standalone preview
  `faint_start` still image do not necessarily sample the same animation time.
  Several preview images show an upright start while source/export images show
  the down pose. Do not classify this as a model defect or as a matching-pose
  pass from these stills alone; inspect the full clip and its end transition.

Local evidence: `.tmp/catalog-production-01-review/source/index.html`,
`.tmp/catalog-production-01-review/export/index.html`,
`.tmp/catalog-production-01-images/`, and
`.tmp/catalog-production-01-review-2026-09-25/local-review-rendered.log` in
the retained slot-b frontend. The user-local review catalog still resolves all
18 pinned SCNs. These paths are not portable release artifacts.

## Per-model screening result

Each `Continue` means **continue to moving visual review**, not admit into
battles. The points below direct that review; they are not diagnosed blockers.

| Model | Static screening | Next visual focus |
| --- | --- | --- |
| Charmeleon | Continue | Tail flame through attacks, sleep and faint end. |
| Persian | Continue | Whiskers and tail during moving attacks and faint. |
| Slowbro | Continue | Shellder attachment and material response during motion. |
| Igglybuff | Continue | Face and small limbs in moving poses. |
| Mareep | Continue | Wool surface and tail tip during motion. |
| Flaaffy | Continue | Wool/body separation and tail tip. |
| Ampharos | Continue | Thin neck and tail clearance. |
| Skiploom | Continue | Floating height, flower and leaves through all clips. |
| Slowking | Continue | Crown, collar and tail through motion. |
| Pineco | Continue, inspect face | Eyes are mostly covered in both source and runtime idle fronts; confirm this is source intent in motion. |
| Dunsparce | Continue | Low body, wings and tail relative to the battle floor. |
| Teddiursa | Continue | Face and tiny paws at battle-camera distance. |
| Ursaring | Continue | Mane and claws during attacks and faint. |
| Houndour | Continue | Skull plates and back ribs during motion. |
| Houndoom | Continue | Tall tail and horns in battle framing and HUD clearance. |
| Phanpy | Continue | Trunk and ears through attack and faint. |
| Stantler | Continue | Antlers in battle framing and HUD clearance. |
| Larvitar | Continue | Back spikes and body clearance through movement. |

### In-game preview feedback (2026-09-25)

Ursaring, Houndour and Houndoom look somewhat soft in the small Pokédex
preview. Their baked body albedo textures are 1024 × 1024 pixels; the Pokédex
3D viewport is displayed at 190 × 138 pixels. The existing zoom button did not
affect that 3D viewport, so it now changes the 3D camera field of view too.
The observation stays open for inspection at zoom and in battle; it is not yet
evidence of a defective source texture or a release hold.

## Qualification stages

### Three-timepoint native-clip screen (2026-09-25)

`catalog_motion_review.gd` rendered 0%, 50% and 100% of all seven native clips
for each hash-matching standalone SCN: **378 captures**, with no missing clips,
invalid posed bounds, script errors or renderer errors. `faint_loop` was sampled
after seeking `faint_start` to its endpoint, matching the summary preview's
transition contract. All 18 contact sheets were inspected. At this sampling
resolution, body parts remain present and recognizable, source-like action
silhouettes are retained, and the down endpoint persists into `faint_loop`.
No new model-specific visual blocker was confirmed. Pineco's partly obscured
idle eyes remain a source-model readability question for the battle camera.

The evidence is retained in slot-b
`.tmp/catalog-production-01-motion-2026-09-25/`: `review.json`, 378 PNGs, and
one contact sheet per species. The rendered invocation and complete output are
in `.tmp/catalog-production-01-review-2026-09-25/motion-review.log`.
Reproduce with a **new** output directory and the retained standalone report:

```sh
ops/worktrees/slot-env SLOT -- env \
  POKEAETHER_CATALOG_MOTION_REPORT=/absolute/path/to/report.json \
  POKEAETHER_CATALOG_MOTION_OUTPUT=/new/absolute/output-directory \
  godot --path .worktrees/SLOT/frontend \
  --script res://tools/sprite_factory/catalog_motion_review.gd
```

This is sampled visual evidence, not continuous video or a battle-view test.

### Battle-camera and floor preflight (2026-09-25)

The existing `phase5_battle_review.gd` was run unchanged against the 18 GLB
candidates, seven blocked rows and a hash-checked Dragonite comparison control.
This is the **GLB review stage**, not the standalone-SCN presenter. The rendered
Forward+ run completed without script/renderer errors. It measured 13,764
60 Hz candidate poses and captured 288 candidate views (classic/stadium,
both sides, four representative actions). All 288 views fit the viewport and
none intersects the existing HUD proxy.

The raw scale and idle-only lift need normal batch calibration:

| Finding | Candidates |
| --- | --- |
| Minimum idle height below the established 60 px readability floor | Igglybuff, Mareep, Pineco, Dunsparce, Teddiursa, Houndour, Phanpy, Larvitar |
| At least one native clip below the flat floor after idle-only lift (more than 0.001 units) | Persian, Mareep, Ampharos, Skiploom, Slowking, Ursaring, Houndoom, Stantler |
| Neither of those raw-scale findings | Charmeleon, Slowbro, Flaaffy |

These are **calibration queues, not source/export failures**. Mareep is in both
queues. The lowest raw idle height is 26.30 px (Igglybuff), and the lowest
sampled clearance is -0.102 units (Skiploom). Representative battle views
confirm the tiny Igglybuff presentation and show the long Houndoom tail and
Stantler antlers inside frame. A flat floor and proxy HUD cannot certify arena
geometry, real HUD, full presenter lifecycle or performance.

Retained slot-b evidence:

- `.tmp/catalog-production-01-battle-input-2026-09-25/catalog.json`, SHA-256
  `ad12f72ae941b7cf92a7fe8111d90cc222ccda143c3b16542322d700eec4118e`;
- `.tmp/catalog-production-01-battle-review-2026-09-25/battle-review.json`,
  SHA-256 `1ff7f59fa43902be3222aaf65665ad6b83df78d0c29e9e4f1b39e829b354afe8`,
  plus its PNGs;
- `.tmp/catalog-production-01-review-2026-09-25/battle-review.log`.

### Calibrated offline placement (2026-09-25)

The existing generic phase-5 rules were applied without changing the converter,
model sources, phase-5 code or production registry. The shared readability rule
`min(4, max(1, 66 / minimum_idle_height))` scaled ten candidates (eight were
below 60 px; Flaaffy and Skiploom received small margins below 66 px). The
second 60 Hz battle review put **all 18 above 60 px**, in view and clear of the
posed-bounds HUD proxy. Grounded sleep intent was confirmed from source poses
for Mareep, Slowking, Ursaring and Stantler; Skiploom and Pineco retain their
native floating rest. The existing motion baker produced profiles for all 18,
with no faint endpoint mismatch or per-model bake hold.

The final rendered review repeated the four-view camera check and independently
sampled **27,350 poses at 120 Hz**. Every corrected clip stays above the flat
floor (minimum **0.0051 units**); all 18 idle presentations remain at least
**65.6 px** tall; all **288** representative candidate battle views are in
frame without HUD-proxy overlap. Its log contains no `ERROR:` or `SCRIPT ERROR`.
The per-model results and exact GLB/SCN hashes are pinned in
[`catalog_production_batch_01_placement_preflight.json`](catalog_production_batch_01_placement_preflight.json).
It labels the 18 **ready for SCN runtime qualification**, not approved.

Retained slot-b inputs/results: `.tmp/catalog-production-01-battle-input-2026-09-25/`
(`readability.json`, `motion-candidates.json`),
`.tmp/catalog-production-01-battle-scaled-2026-09-25/`,
`.tmp/catalog-production-01-battle-corrected-2026-09-25/`, and their logs in
`.tmp/catalog-production-01-review-2026-09-25/`. The existing phase-5 candidate
closer has a fixed ten-model cohort, so its eligibility labels were not reused
for batch 01. The candidate profile remains a local review artifact; no game
catalog, pack, saved setting, production release or server was changed.

### Normal-SCN battle runtime screen (2026-09-25)

An isolated local catalog admitted the 18 exact standalone SCNs through the
production battle presenter. The screened registry was changed only for the
duration of this local test and restored byte-for-byte afterwards; the
checked-in registry and game admission remain unchanged. Each SCN matched both
the batch result and placement-preflight SHA-256. The classic-arena battle
scene loaded every normal model with its measured scale, ground lift and motion
profile. The run exercised both battle sides, normal and duplicate opponents,
physical/special/damage/sleep actions, faint loop, same-species replacement,
and repeated switching through the bounded two-entry cache. All 18 passed;
the rendered log contains no `ERROR:` or `SCRIPT ERROR`.

All 18 idle battle captures were inspected. The models remain recognizable at
battle distance, without an obvious missing body part or material swap. The
Ursaring, Houndour and Houndoom fur concern from the 190 × 138 Pokédex preview
does not show a clear texture fault in these 1280 × 720 classic-arena images.
Pineco's partly hidden face remains a visual readability note. This screen
does not certify moving battle video, real HUD clearance, battle replay, other
arenas, performance, shiny forms, or portable bundles. The exact normal-SCN
outcomes and hashes are in
[`catalog_production_batch_01_runtime_qualification.json`](catalog_production_batch_01_runtime_qualification.json).
The local `res://.tmp/catalog-production-01-runtime-qualification.json`, log,
and 18 battle PNGs retain the run evidence.

### Immersive HUD and recorded replay (2026-09-25)

Using the same isolated, hash-checked 18-SCN catalog and the real battle UI,
all 18 normal forms were displayed on both sides in 18 adjacent pairs. Their
projected model envelopes stayed clear of the corresponding live Immersive HUD
panels. Three full-screen classic-arena captures, including Ursaring/Houndour
and Houndour/Houndoom, were visually inspected and confirm that the HUD is
actually present and unobscured. A recorded six-frame battle fixture then
played Charmeleon attacking Houndour, damage, Persian switching in and
fainting, Slowbro replacing it, and the end frame. All five transitions after
the initial frame reached the expected actor identities and lifecycle states.
The rendered run completed without `ERROR:` or `SCRIPT ERROR`.

The [HUD/replay qualification report](catalog_production_batch_01_hud_replay_qualification.json)
pins this evidence. The temporary screened registry was restored byte-for-byte;
none of these candidates gained player-facing battle admission. Replay used
four species, while the HUD check covered all 18 on each side. Other arenas,
Classic-layout HUD, shiny forms and release packaging still require their own
checks. **Next production step:** make the shiny counterparts, qualify their
material/animation and normal–shiny pairing, then package individually.
Keep confirmed model-specific defects in the review queue without stopping
the other candidates. The seven technical holds do not block the next batch.

### Official shiny variants and paired runtime screen (2026-09-25)

The 18 normal exports were compared with their official `_rare.trmtr` material
tables. Four changed more than the inspected base-colour texture binding and
were held without export: Ampharos also changes a normal map; Slowbro and
Pineco change eye-material settings; Larvitar changes an eye layer mask.
The other 14 had unchanged inspected material settings and only official
`BaseColorMap` replacements. Their embedded normal images were verified
pixel-for-pixel against the official source PNGs before remapping to the rare
PNG. Blender's retained `.001` image copies are now handled by verifying every
matching copy; a mismatch still stops export.

All 14 shiny GLBs passed exact geometry, skin and animation parity against
their normal GLBs. Fourteen standalone shiny SCNs were created and reloaded
with distinct SHA-256 hashes. The rendered three-timepoint review produced
**294 captures** (14 × seven clips × three times) without invalid poses or
script/renderer errors. All 14 idle captures were inspected; the official
colour changes and anatomy remain recognizable. In the real battle presenter,
all 14 normal/shiny pairs retained separate resources and actors, switched in
both directions, played shiny actions and faint/replacement, stayed clear of
the Immersive HUD and reloaded after bounded-cache eviction. Four pair images
were inspected. A held Ampharos shiny fell back to 2.5D. The temporary local
screened registry was restored byte-for-byte after the test.

The exact per-model hashes and hold reasons are recorded in
[`catalog_production_batch_01_shiny_qualification.json`](catalog_production_batch_01_shiny_qualification.json).
The local source exports, SCNs, motion images, paired battle images and logs
remain under `.tmp/catalog-production-01-shiny-*`. This is candidate
qualification, not release certification: continuous motion review, other
arenas, performance and portable per-Pokémon bundles remain open. The four
material holds stay in their queue while the 14 pairs advance.

### Local bundle and performance preflight (2026-09-25)

Fourteen **unreleased candidate bundles** now contain the exact normal/shiny
SCN pairs pinned in the shiny qualification report. The builder rechecks all
28 scene hashes and the four retained evidence hashes before producing one
versioned bundle per species. The bundles total **370,321,935 bytes
(353.17 MiB)**; the content index and each archive have SHA-256 pins in
[`catalog_production_batch_01_bundle_preflight.json`](catalog_production_batch_01_bundle_preflight.json)
and the local `candidate-receipt.json`. No bundle is in the base game build or
the currently approved seven-species launcher release.

The real launcher asset store installed all 14 archives. Godot loaded all 28
installed scenes, then confirmed a no-op plan and restart stability. A separate
rendered, no-image-readback test used the real battle screen and Immersive HUD
over three battles (Classic, Stadium, Classic). Each round covered all 14 pairs,
native shiny special attacks, faint/replacement, normal/shiny switching, HUD
clearance and bounded caching. The clean repeat had 95th-percentile frame times
of **17.198, 17.193 and 17.739 ms**; maximum threaded-load callbacks were
**1.852, 1.666 and 2.601 ms**. No uncovered hitch exceeded 100 ms; the final
two rounds grew static memory by 97,992 bytes. The screened registry was
restored byte-for-byte after the test.

Retained local artifacts: `.tmp/catalog-production-01-candidate-bundles-2026-09-25/`,
`.tmp/catalog-production-01-candidate-install-2026-09-25/`, and
`.tmp/catalog-production-01-candidate-stress-2026-09-25-02.{json,log}`.
Rebuild from the retained paired catalog with
`python3 tools/package_catalog_batch_01_candidates.py CATALOG NEW_OUTPUT_DIR`.
Run the local stress screen with
`python3 tools/sprite_factory/run_catalog_batch_01_candidate_stress.py CATALOG REPORT LOG`.

**Release approval remains open.** The sampled motion and battle images do not
replace a full moving visual review and final per-species decision. The
launcher release adapter intentionally continues to allow only the original
seven approved species. Ampharos, Slowbro, Pineco and Larvitar shiny stay in
the material review queue and do not delay these 14 candidate bundles.
