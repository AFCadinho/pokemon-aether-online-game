# Final 21 reconstructed forms: local qualification

This completes the reconstruction batch introduced in
[remaining-twenty-one-reconstruction.md](remaining-twenty-one-reconstruction.md).
The previous receipt remains an immutable preview checkpoint. The new receipt,
`tools/sprite_factory/final_twenty_one_qualification.json`, records the subsequent
local admission of 21 normal/shiny pairs and the remaining count for the original
229-form audit. This is not a new production release or an R2 publication.

## Changes

The batch contains the three weather Castforms, Eternamax, Ash-Greninja, both
Primals, three Necrozma forms, four Ogerpon Tera forms, Spiky-eared Pichu and six
Cosplay Pikachu forms. Each normal/shiny pair uses the existing shared package
contract. Earlier registry entries and profiles are preserved exactly.

Missing sleeping expressions use separate eye surfaces selected by discrete
visibility tracks. Native Pichu/Pikachu sleeping states remain intact. Castform
shiny textures were refined by surface role, including the connected facial
mask; Ultra Necrozma's shiny emission was corrected alongside its albedo.
Instance materials are private node overrides. Procedural costume primitives
are baked to identical triangle arrays to avoid material lifetime errors when
actors are replaced. Eternamax receives measured battle placement from a
source-scale seed rather than relying on its preview camera. Ultra Necrozma
also receives a suitable seed because its very small source units hit the
calibrator’s fourfold adjustment cap. Final idle camera measurements must reach
at least 60 pixels in height on every tested side and arena.

These remain authorized reconstructions: some palettes, effects, costume/ear
geometry and missing motions are newly authored. Original-game visual or
animation parity and transformations between forms are not claimed. Assistant
inspection of the final renders is recorded separately from the user's
reconstruction authorization; no additional human approval is fabricated.

## Evidence and limits

The batch contains 42 appearances, 312 animation clips and 21 shared packages
totalling 146,906,912 bytes (146.91 MB / 140.10 MiB). The retained inspection
runs contain 4,752 frames and 37,344 attachment samples. Battle evidence includes
1,080 measured camera views, 5,616 appearance/isolation samples in the actual UI,
and 456 pixel-exact package comparison frames.

The final receipt pins source scenes, code, shared packages, exact render
comparisons and battle reports. Qualification requires all 42 appearances,
required animation clips, finite poses, correct attachments, measured floor
clearance, camera/HUD separation, private appearance state and successful faint
replacement. Package render comparisons must be pixel-exact. The actual battle
UI exercises both arenas and normal/shiny, normal/normal and shiny/shiny pairs
on Linux Compatibility and Mobile renderers. A final runtime check loads each
pair against the admitted registry. Windows, macOS and physical Android remain
untested; Mobile here means the Linux Vulkan renderer.

Failed runs are retained separately. UI reports are keyed by fixture and test
code hashes. The test freezes both actor clocks before isolation comparisons
and follows real battle lifecycle transitions at animation endpoints. It still
compares material storage values and visibility exactly with the native scene.

Local artifacts remain in slot-c at `.tmp/finish-twenty-one-v1/`:

- `review-complete/index.html`: all 42 appearances, poses and inspection movies.
- `review-complete/composition.json`: hashes and origins of the two immutable
  render runs, including the final four Castform replacements.
- `battle/`, `delivery/`, `ui/`: placement, pair packaging and real battle checks.
- `visual-assessment.json`: assistant inspection and exact scene identities.

Movies sample a turntable and 12 positions per clip; they are not real-time
playback recordings. Runtime scenes and packs are retained local artifacts,
not files checked into Git. The approved local index is
`release/approved_3d_final_twenty_one_index.json`. Publishing it requires a
separate model-release operation.

## Reproduction

Use an assigned slot with the pinned previous reconstruction artifacts and
source archives. Run host Python and Godot via `ops/worktrees/slot-env SLOT`.
`final_twenty_one.py` provides `setup`, `prepare`, `battle`, `delivery` and `ui`.
The pipeline tool waits for each battle measurement before delivery/UI checks.
The review composer preserves both input render runs; it never rewrites the
previous preview receipt. Admission fails closed until every item qualifies.

Run `final_twenty_one_admission.py admit`, then `finalize` to test the admitted
registry and seal its receipt. Run the focused new qualification tests and the previous reconstruction,
fourteen-form, Zygarde and remaining-form admission regressions. Full release certification,
promotion, builds and publication remain separate operations.
