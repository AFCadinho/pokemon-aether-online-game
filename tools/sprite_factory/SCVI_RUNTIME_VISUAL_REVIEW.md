# Fixed 100 — standardized runtime visual screening

## Outcome

The same **88 technically converted SCNs** were recaptured through the corrected
runtime material-response renderer and individually screened. No source, model,
material, animation, converter or approval was changed for this review.

| Fixed cohort disposition | Count |
| --- | ---: |
| `visual_pass` — sampled-clip screening only | 79 |
| `effect/accessory_issue` | 8 |
| `animation_issue` | 1 |
| Existing technical/source holds, unchanged | 12 |

This gives **79/100 screened-clean candidates**, or **79/88 (89.8%)** of the
technically converted group. It is not a measured fully automatic production-ready
yield: placement and live battle behavior were not reviewed here. All entries
remain `runtime_approved: false`; no catalog entries were published or approved.
The machine-readable ledger is `cohort_runtime_visual_review_results.json`.

The old repeated facial/body contours are no longer the dominant finding.
Those historical image counts must not be interpreted as model defects; see
`SCVI_CONTROL_RENDER_REVIEW.md` for the causal renderer experiment.

## Nine visual holds

| Species | Observed symptom; not a proven root cause |
| --- | --- |
| Gastly | Angular translucent smoke overlaps eyes, with black cutout-like regions. |
| Charmander | Tail flame appears as coarse flat yellow/red polygon strips. |
| Moltres | Wing/head/tail flames appear as coarse opaque polygon patches. |
| Spiritomb | Face absent on purple disc in front/back samples; purple geometry below sleeping/fainted stone. |
| Rillaboom | Both drumsticks remain suspended away from the hands during sleep. |
| Decidueye | Detached arrow persists beside/below the actor in idle, sleep and faint samples. |
| Magearna | Bouquet persists in idle, sleep and closed faint form. |
| Cinderace | Opaque black spiky ball/effect persists near feet in idle, sleep and faint samples. |
| Dugtrio | One front body/head becomes an extremely flattened elongated oval at faint-start end and in faint loop, also visible from behind. |

The first eight are effect/accessory holds. Dugtrio is an animation/pose hold;
source intent, mapping and deformation need comparison before calling it a
converter bug. No model-specific corrective manifests were authored.

The existing twelve holds remain Pikachu, Grimer, Muk, Typhlosion, Silvally,
Blacephalon, Marshadow, Stakataka, Alcremie, Hydrapple, Ceruledge and Terapagos.
Their previous source/technical classifications have not been superseded.

## Capture and audit

- Baseline renderer commit: `875b92a4e`; Godot 4.6.2 Forward+/Vulkan,
  NVIDIA RTX 3070 Laptop GPU.
- 88 unchanged SCNs; every SHA-256 matches the original fixed-cohort ledger
  before and after capture. This does not erase earlier pipeline history.
- Seven native clips per model: idle, physical attack, special attack, damage,
  sleep, faint start and faint loop: **616 clips, 20,528 motion frames** at 12 Hz.
  Idle, sleep and faint loop are captured for two cycles; other clips for one.
- Ten static front/back poses per model: **880 additional images**.
  All **21,408 raw PNGs** exist at 512×512. No empty images or foreground within
  one pixel of the border were detected by the background-difference check.
- **Zero CPU bone-pose mismatch frames** between main and irradiance skeletons.
  This broad run does not repeat the first/settled GPU ordering comparison;
  that is covered by the earlier four-control experiment on both backends.
- Each of the 88 contact sheets was visually inspected: four first-cycle samples
  per clip plus five back poses, **2,904 tiles**. Not every captured frame was
  manually reviewed, and second-cycle capture is not a manual loop certification.

The stage uses the real experimental battle world's material-response lifecycle,
with no arena floor to hide raw source poses. Camera framing uses the union of
nine sampled poses per clip and remains fixed for each model. Idle height is
normalized in memory only; source/export files are untouched. Contact-sheet tiles
crop and resize each frame for detail, so they are not root-trajectory evidence.

Native clips reset bone poses before isolated playback. This avoids stale eye
poses from a previously sampled clip but does not test live event transitions.
Two discarded pilot runs exposed floor occlusion and missing harness bone resets;
only `cohort-runtime-review-03` contributes to these results.

Not covered: relative battle scale, grounding/floating height, arena lighting,
arbitrary camera angles, team overlap, shiny variants, audio/event timing, cache
eviction, switching or live PvP. Absence of a material/placement classification
does not certify those systems. This is an AI visual screen, not human approval.

## Reproduction and evidence

From the workspace root, use a new absolute output directory:

```sh
ops/worktrees/slot-env slot-b -- env COHORT_REVIEW_OUTPUT=/absolute/new-review-directory godot --path .worktrees/slot-b/frontend --rendering-method forward_plus --script res://tools/sprite_factory/cohort_render_review.gd
```

Then, from the slot frontend:

```sh
python tools/sprite_factory/cohort_review_media.py /absolute/new-review-directory
```

The original ledger's runtime paths are relative to the paired slot root.
Existing evidence is under `frontend/.tmp/cohort-runtime-review-03` relative to
that root; raw images are local diagnostic artifacts, not committed game assets.
The new ledger records original SCN, per-model report and contact-sheet hashes.
`png_digest_sha256` hashes the ordered `filename sha256\n` records for static
images followed by each clip's frames in report order; it excludes contact sheets.
The ledger also binds the capture driver and aggregate capture report.

## Recommended next action

Keep the 79 screened-clean models as candidates, without silently approving them.
Investigate the shared effect/accessory visibility and material categories using
the eight named controls; separately compare Dugtrio's source faint pose. Apply
generic fixes only after identifying their cause. Recheck the affected controls
before another broad run. Do not upscale or require 100/100 to make progress.
