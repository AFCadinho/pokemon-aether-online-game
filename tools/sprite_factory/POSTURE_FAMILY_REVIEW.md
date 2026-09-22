# Source posture families — 2026-09-22

## Outcome

Garchomp's alternate bank-0 clips form a coherent standing battle set. The
current bank-2 attack/damage/faint set belongs to its horizontal pose; this is
not a residual-state problem. Five controls support selecting the bank of the
chosen idle, rather than the current per-category 2/0/1 priority.

This remains a **source-level diagnostic**, not a shipped mapping correction.
No approved model, source file, runtime catalog or production selector changed.

## Experiment

`review_posture_families.py` opens the existing six source BLEND files in memory,
imports each available alternative TRAnm action, resets pose through the existing
`select_action`, and evaluates corresponding world-space mesh vertices at the
start, midpoint and exact end. It never saves a BLEND or exports a model.
Input BLEND and raw motion SHA-256 values are checked again after evaluation.

The report retains each clip name, bank, selection, frame range, measured
displacement and input hashes: `posture_family_results.json`.

All displacements below are maximum corresponding-vertex distances divided by
idle height, **not whole-model displacement**. Faint end is expected to differ
from idle; its continuity is tested against faint-loop start instead.

| Garchomp boundary | Current bank 2 | Alternative bank 0 |
|---|---:|---:|
| Idle → physical attack | 1.21142 | 0.0000031 |
| Physical attack → idle | 1.21142 | 0.0000049 |
| Damage end → idle | 1.21142 | 0.0000052 |
| Idle → faint-start | 1.21142 | 0.0000545 |
| Faint-start end → faint-loop | 0.0000104 | 0.0000273 |

Both banks internally join faint-start to faint-loop correctly. The mismatch is
with the chosen standing idle, not an intrinsically broken bank-2 animation.
Bank-0 damage begins with recoil (0.28088 height), so exact idle equality at the
start would incorrectly reject this valid reaction pose.

The candidate Garchomp set is:

- `00001_battlewait01_loop` (unchanged)
- `00400_attack01` (instead of `20400`)
- `00450_rangeattack01` (unchanged)
- `00500_damage01` (instead of `20500`)
- `00281_sleep01_loop` (unchanged)
- `00520_down01_start` / `00521_down01_loop` (instead of `20520/20521`)

Important timing distinction: bank-0 faint-start spans frames 0–100, whereas the
current bank-2 clip spans 0–80. Preserve native clip data; a later runtime test
must explicitly check the existing action-timing contract, not reuse an old
duration blindly. Attack and damage alternative ranges match their current
counterparts (0–130 and 0–40 respectively).

## Generic cross-check

| Pokémon | Chosen idle bank | Advisory result |
|---|---:|---|
| Garchomp | 0 | Four action mappings change to bank 0 |
| Azumarill | 0 | Existing seven mappings unchanged |
| Flareon | 0 | Existing seven mappings unchanged |
| Gardevoir | 0 | Existing seven mappings unchanged |
| Forretress | 2 | Existing seven mappings unchanged |
| Gyarados | 1 | Existing seven mappings unchanged |

All six have one same-bank candidate for every non-idle category. The advisory
selector emits null for a missing/ambiguous category, rather than silently
borrowing another bank. Garchomp's bank-2 default-idle agrees with the horizontal
attack pose; Azumarill and Flareon's bank-1 alternatives end in their distinct
bank-1 posture, not the chosen bank-0 idle. This gives negative as well as
positive evidence for coherent selection in this sample.

Do not generalize numeric banks to universal land/water/flight meanings. Also,
the same bank alone does not prove matching posture: Garchomp's bank-0 default
idle differs from its battle-idle. The actual boundary measurements remain
necessary; this is not a universal approval rule.

## Scope and next implementation step

The review covers skeletal geometry; it does not certify TRACM material/UV/
visibility companions or the complete Godot battle path. In particular,
Azumarill's source entry metric differs from the prior exported-runtime metric;
do not treat these different evaluation paths as pixel-equivalent.

Next: introduce same-idle-bank selection with explicit ambiguous/missing-bank
holds, regenerate a **separate** Garchomp candidate through the existing full
pipeline (including companion channels), then repeat summary and battle action
sequences and timing checks before replacing its approved catalog entry. Keep
the five unchanged controls as regression evidence. No individual pose offsets,
animation edits, universal crossfade or species-name exception is needed by the
current evidence.

## Reproduction

Run Blender 5.2 with `--background --factory-startup --disable-autoexec
--python-exit-code 1 --python ABSOLUTE_PATH/review_posture_families.py --
ABSOLUTE_EXPORT_JOB_DIRECTORY ABSOLUTE_NEW_OUTPUT_JSON`.
The six retained jobs are in slot-b's
`.tmp/catalog-100-identity-rerun-01/export`. The worker reads importer/dependency
locations from the retained source jobs. No network is required.

Validation: two successful six-model source runs; final run includes faint joins.
14 existing `test_batch_hardening` / `test_scvi_batch` tests pass. This is
research tooling only; no player-facing fix is claimed.
