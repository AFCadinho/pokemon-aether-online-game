# Four-model control: render-layer synchronization

> Follow-up: `SCVI_RUNTIME_VISUAL_REVIEW.md` records the completed standardized
> screening of all 88 unchanged technically converted SCNs through this fix.

## Conclusion

Dragonite, Jigglypuff, Ditto and Eevee were loaded from the **unchanged, hash-bound
SCNs** used by the fixed-100 cohort. Two independent presentation faults explain
the repeated-contour symptom in the control experiment:

1. The old disposable viewer called `Response._pair()`, which intentionally
   disables the irradiance copy's AnimationPlayer. It then reset that copy's
   skeleton and tried to independently sample its disabled player, without using
   the runtime `_sync()` path. All **48 legacy A/B pose samples** had different
   bone poses between layers. Runtime synchronization gave **0/48** mismatches.
   Repeated eyes/mouths/body contours return with the legacy path and disappear
   in settled runtime captures, with identical model files, camera and lighting.
2. The real response helper created the irradiance viewport as a **sibling** of
   the main viewport. During motion the main pass sampled older irradiance even
   with matching CPU bone poses. A Jigglypuff layer probe showed **25/25 byte-equal
   first/settled irradiance images**, while the main image changed after waiting
   without moving the model. This isolates render ordering from model export,
   skeleton mapping and the endpoint textures for this symptom.

The generic fix puts the light viewport **under the main viewport**, retaining
its independent 3D world. It renders before the main pass. The pooled forest
path also adopts this hierarchy, keeping both viewports owned by the world
session. No model/material textures, lighting values, source data, animations,
converter rules or catalog approvals were changed. No reexport is necessary.

## Controlled runtime test

The probe uses `experimental_battle_3d.gd`'s world construction and the actual
`material_response.gd` process/pre-draw lifecycle. Its stage subclass only forces
the classic arena. The battle host, networking, loading gates and gameplay
presenter are not run; this is a renderer diagnostic, not a full live battle.

Both renderer backends were tested on Godot 4.6.2:

- Forward+ / Vulkan, NVIDIA RTX 3070 Laptop GPU (normal desktop render method).
- Compatibility / OpenGL, AMD Radeon integrated graphics (old review method).

For each backend, four actions at 0/50/100% were compared through runtime versus
legacy synchronization. Then five native clips (idle, special attack, sleep,
faint start, faint loop) were advanced deterministically at 30 Hz: **1,218 frames
per backend**. Five checkpoints per clip compare the first rendered image with
four-frame-settled output at the *same frozen pose*: 100 checkpoints per backend.

| Measurement | Forward+ before | Forward+ after | Compatibility before | Compatibility after |
| --- | ---: | ---: | ---: | ---: |
| Checkpoints with channel difference > 0.05 | 94/100 | 0/100 | 95/100 | 0/100 |
| First/settled frames exactly pixel-equal after fix | — | 100/100 | — | 100/100 |
| Bone mismatches during runtime motion | 0 | 0 | 0 | 0 |

Legacy negative controls still show mismatches after the viewport-order fix:
ordering does not repair an incorrectly posed light copy. Future review must use
the real response lifecycle, not the old independently sampled copy.

Twenty Forward+ MP4 clips and four temporal contact sheets were generated from
the post-fix sequence. A/B stills and five temporal samples per clip were visually
inspected. The contour issue is absent in those post-fix samples. Capturing video
and inspecting sampled frames is **not a claim that every intermediate video
frame was manually reviewed**.

## Scope and remaining work

The old 15/63/10 static screening split cannot estimate model quality. It remains
historical evidence, not a set of model rejection decisions. Neither those
models nor the four controls are automatically production-approved by this fix.

The camera and normalization rule were held constant within each A/B comparison.
They are diagnostic, not production placement calibration. Ditto's extended
attack exceeds the fixed camera's top edge; future full review needs motion-aware
framing. These captures also do not prove shiny variants, arbitrary cameras,
multi-actor overlap, every arena or full trainer/PvP transitions. The forest
ownership path is covered by synthetic lease/release regression tests, not a
fresh Terrain3D visual run.

Next: re-render/review the same 88 unchanged SCNs consistently through the fixed
runtime path, using complete framing and the same documented lighting. Reassess
the remaining smoke/fire/accessory groups from those images. Do not carry their
old labels forward as confirmed source faults, upscale the cohort or add
species-specific corrections first.

## Reproduction and evidence

`control_render_probe.gd` loads the four entries and verifies their original
runtime hashes before and after each run. It requires the retained slot's local
SCNs referenced by `catalog_100_visual_triage_results.json`; it never installs or
approves them. Supply an **absent output directory**. Example from workspace root:

```sh
ops/worktrees/slot-env slot-b -- env \
  CONTROL_REVIEW_EXPECT_CURRENT_FRAME=1 \
  CONTROL_REVIEW_OUTPUT=/absolute/path/to/new-control-run \
  godot --path .worktrees/slot-b/frontend --rendering-method forward_plus \
  --script res://tools/sprite_factory/control_render_probe.gd
```

Optional `CONTROL_REVIEW_SPECIES=jigglypuff` narrows the four-case probe. The
legacy branch is deliberately a negative control, not the path to reuse for
catalog screenshots. `CONTROL_REVIEW_PARENT_ORDER` was an in-memory experimental
override used before the runtime fix; normal post-fix runs do not need it.

Compact run summaries and hashes are in `control_render_review_results.json`.
Full local runs are under `frontend/.tmp/` in slot-b:

- `control-render-forward-01`, `control-render-02`: pre-fix backend comparisons.
- `control-light-order-01`: separate main/irradiance readback probe.
- `control-light-parent-01`: isolated parenting intervention, Jigglypuff.
- `control-render-fixed-forward-01`, `control-render-fixed-gl-01`: post-fix four-model runs.

Focused tests: material validation/neutral-lighting checks; material pack
round-trip/negative checks; new normal-cleanup and two pooled-lease ordering
regression; probe parse check; both post-fix rendered runs and their evidence
hash/pixel-equality validation. No full paired gate, promotion or deployment.
