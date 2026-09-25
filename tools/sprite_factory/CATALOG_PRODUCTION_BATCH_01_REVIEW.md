# Catalog production batch 01: static review handoff (2026-09-25)

This is a **static screening pass**, not visual approval, battle qualification,
catalog admission, or release approval. Keep the 18 entries in
`catalog_production_batch_01_results.json` at `visual_review: pending` and
`runtime_approved: false` until moving animation and battle gates are complete.
The seven source/export holds remain in the separate blocked queue.

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

## Next gate

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

**Next gate:** prepare the exact standalone SCNs with the measured placement and
motion profiles in an isolated runtime candidate catalog. Run the actual
presenter through mixed-team switching, duplicate actors, faint/replacement,
cache eviction/reload and battle replay, plus material/HUD review and
performance guards. Record confirmed model-specific defects as holds and
advance the unaffected models. Normal/shiny pairing and individual bundle
packaging remain later release gates. The seven technical holds do not block
the next production batch.
