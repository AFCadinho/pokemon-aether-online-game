# Damage transition review — 2026-09-22

## Result

Garchomp's standing battle-idle is paired with a horizontal/flying damage pose.
This is reproducible after the summary preview's existing reset, and independent
of the preceding animation. The six-model sample does **not** reproduce residual
geometry state through the summary playback path. No model, mapper, material,
animation timing, runtime code or approval registry was changed in this review.

## Method and evidence

`review_damage_transitions.gd` loads the actual SummaryModelPreview and its
hash-gated local catalog. Garchomp, Azumarill, Flareon, Gardevoir, Forretress and
Gyarados cover different body plans. Playback is manually clocked. For each:

- Reference damage poses at 0%, 25%, 50%, 99.9% of clip duration.
- Repeat each after all seven clips sampled at 73%, for three cycles.
- Compare corresponding world-space skinned vertices: 84 comparisons/model,
  504 total. All maximum history deltas are exactly zero.
- Return to idle(0) after each prior-clip group: all 126 returns match reference.
- Require damage(0) and damage(50%) to differ, guarding against a stale/no-op
  measurement. Wait for renderer synchronization before baking skinned geometry.
- Fixed-camera six-frame contact sheet: idle, four damage samples, idle.
  All six sheets were visually inspected.

Aggregated metrics and runtime hashes: `damage_transition_results.json`.
Full per-sequence results and PNGs are retained locally in
`.tmp/damage-transition-review-02/` in slot-b/frontend.
The initial run `-01` measured skinning before renderer synchronization; its
all-zero transition metrics are invalid and superseded by `-02`.

Maximum vertex displacement divided by idle height (not actor translation):

| Model | Idle → damage start | Damage end → idle |
|---|---:|---:|
| Garchomp | 1.1921 | 1.2114 |
| Azumarill | 0.1832 | 0.00076 |
| Flareon | 0.2013 | 0.00026 |
| Gardevoir | 0.2753 | 0.00013 |
| Forretress | 0.3840 | 0.00018 |
| Gyarados | 0.4378 | 0.00058 |

For the five controls, the initial difference is visibly recoil; their final
poses return close to idle. An entry delta alone must not become a rejection
threshold. Gyarados' downward recoil is not evidence of a grounding bug in a
floorless preview. These measurements do not certify actual arena grounding.

## Mapping evidence

Retained source job:
`../.tmp/catalog-100-identity-rerun-01/export/garchomp/job.json`.

- idle: `pm0445_00_00_00001_battlewait01_loop`
- damage: `pm0445_00_00_20500_damage01`
- damage alternative: `pm0445_00_00_00500_damage01`
- physical attack: `20400_attack01`, alternative `00400_attack01`
- faint start/loop: `20520/20521`, alternatives `00520/00521`
- special attack: `00450_rangeattack01`

`scvi_batch.py:source_entry` selects action categories independently. It prefers
the battlewait suffix for idle, then prefix order 2, 0, 1 within each category.
This explains the mixed source family in the selected Garchomp set. The observed
standing/flying mismatch is established; a universal meaning of every numeric
prefix is **not** established. The alternative damage clip has not been imported
or validated here, so it is a candidate, not a proven fix.

## Recommended next step

Review source action sets as coherent posture families, starting with Garchomp's
existing 0/2 alternatives. Confirm compatible idle/damage/attack/faint pairs
before changing generic selection. Do not add a Garchomp offset or universal
crossfade to conceal a wrong family. Keep the six-model sequence review as a
focused regression; report posture mismatches separately from history failures.

## Limits

This diagnoses standalone approved normal models in the **summary** path. It
does not certify the independent battle `_action` path, continuous idle-phase
transitions, every frame, materials/visibility, reload cycles or shiny variants.
No component-sharing work was resumed. No visual/player-facing fix is claimed.

Run from workspace root with a fresh absolute output directory:

```sh
ops/worktrees/slot-env slot-b -- env \
  SUMMARY_MODEL_CATALOG=/home/adinho/Documents/3d_models/PokeAether/screened-catalog-v1/catalog.json \
  DAMAGE_REVIEW_OUTPUT=/absolute/new/output-directory \
  godot --path .worktrees/slot-b/frontend --rendering-method forward_plus \
  --script res://tools/sprite_factory/review_damage_transitions.gd
```
