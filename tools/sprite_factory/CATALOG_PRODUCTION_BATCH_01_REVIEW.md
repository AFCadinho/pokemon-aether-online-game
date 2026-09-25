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

Review all seven clips as moving models in the desktop debug client, including
the full faint-start to faint-loop transition. Record any confirmed material,
visibility, identity or action defect as a per-model hold. Send the remaining
models through measured battle scale/grounding, motion/HUD clearance, live
presenter lifecycle and performance checks. Only those that pass may be
considered for checked-in admission. Normal/shiny pairing and individual
bundle packaging are subsequent release gates. Start the next production batch
without waiting for the seven existing technical holds to be repaired.
