# Remaining catalogue: one final review

## Checkpoint — 2026-10-01

All **127 remaining ordinary species** were inventoried and attempted in one
continuous task. Baseline remains **898 ordinary species plus Mega Dragonite**:
899 approved profiles / 1,798 normal/shiny records. This task has **not** admitted
models, changed those counts, produced release bundles, uploaded, or published.

- **112 normal/shiny review pairs**: 109 legacy/ZA pairs plus Ponyta, Rapidash and
  Centiskorch. Their final 224 standalone SCNs and current images are hash-pinned.
- **15 DLC species held**: models/rigs exist, but mounted sources lack usable
  native motions. Own-rig prototypes failed internal pose/visibility review.
  Their identities are pinned in `catalog_remaining_final_dlc_intake.json`;
  earlier Dipplin/Poltchageist/Sinistcha/Hydrapple source swaps were corrected.
- **No visual approvals inferred**. One user review is the next step.

[One final appearance/battle page](http://127.0.0.1:8783/final-review-v1/).
Select **Alle Pokémon tonen**, inspect both variants, switch all five poses and
**In battle**, both cameras and sides. Clicking an image enlarges it. The page
has local notes, colour references and a separate list of the 15 holds.

## Fixes and scope

Restored native diffuse/detail and eye textures; isolated shiny transfers from
eye textures; used registered local HOME references and explicit skin/material
palettes for ambiguous shiny colours. These remain visual proposals, not a
claim that every shiny colour was directly recovered from an official dump.
Corrected Liepard to its own rig and Zygarde to its 50% source. Native action
selection now excludes UV/material actions and other form rigs. For 13 models,
missing motions were added on their own rig; native attacks remain intact where
available. Rest/idle aliases and baked eyelids are explicit: some sources still
lack a genuine closed-eye sleep animation. Review sleep/faint visually.

Fixed scene pose-order leakage while preserving existing native animation
curves and clocks. Fixed Stakataka/Dottler unit scale and small-model
readability; reran floor checks after lifts/action offsets. Fire scene pose
transitions were fixed too. Fire shaders remain diagnostic proposals and are
**not yet whitelisted for gameplay packaging**; approval alone must be followed
by that runtime integration before those three can be released.

The diagnostic options are opt-in. A default Rattata export remained byte
identical (SHA-256 `b1d24939d6d87219da927a684809968dad0c02e377e74a1974785f729d69ffb3`).
No default runtime validator thresholds were weakened.

## Evidence

`tools/sprite_factory/catalog_remaining_final_checkpoint.json` pins all 127
outcomes, final scene/GLB hashes, appearances and technical reports.
`catalog_remaining_final_jobs.json` preserves native mappings and late recipes.
Generated scenes/images/logs stay outside Git under
`.tmp/remaining-final-batch-v1/` in the retained slot-a frontend worktree.

- 30 focused Python tests passed (proposal invariants, source intake, native UV
  recovery, palette variants); Python compilation and Git whitespace checks.
- All 224 final scene pose-order checks passed; 112 pairs have exactly equal
  geometry, skins, transforms and animation curves, excluding only explicit
  material texture-state tracks.
- All 112 normal models measured in battle at 60 Hz and checked for corrected
  floor clearance at 120 Hz: no remaining clearance/camera failures. Each has
  16 actual battle images (two cameras, two sides, four poses).
- All 112 shiny variants independently rendered into 16 battle images each.
  Their geometric 60/120 Hz measurements are reused **only after exact scene
  pair parity**, with both current scene hashes checked; they are not reported
  as independently resampled shiny measurements.
- Every review image references the current scene hash. 4,798 local images
  resolve, including colour references; HTML and 82 sampled images returned
  HTTP 200. Browser automation is unavailable in this session, so no claim of
  an observed browser rendering is made.

These checks cover catalogue preparation, not a full FPS/release certification
or live arena collision test. Failed experiments/reports are retained and are
excluded from the final page. Do not use the failed DLC bind poses,
vertex-palette diagnostics, intermediate Kabuto/Nuzleaf colours, or the first
incomplete fire battle report.

## Resume and approval

If needed, restart the local server from the retained slot frontend:

```sh
python3 -m http.server 8783 --bind 127.0.0.1 --directory .tmp/remaining-final-batch-v1
```

After the user's final visual review, admit only accepted pairs with their
exact pinned SCN hashes, carry battle motion profiles over using the SCN hashes,
finish the fire runtime integration, then build individual bundles. R2 upload,
release certification and publishing are separate authorized tasks. The 15
held DLC species need usable native motion assets or a separately developed
and reviewed pose/visibility solution; do not mark them ready just to empty a
queue.
