# Same-idle-bank candidate — 2026-09-22

## Implemented selection

New SCVI intake retains the existing idle preference, then selects non-idle
actions only from that idle's numeric bank. Missing or multiple matches produce
explicit `motion_bank_hold` warnings and import is blocked. A deliberate override
may disambiguate within the bank, but crossing banks raises an error. Companion
TRACM paths are resolved only after selection. There is no species-name exception.
Old inventory files and approved catalogs are not automatically rewritten.

The six measured source fixtures produce the advisory sets from the previous
review: only Garchomp changes; Azumarill, Flareon, Gardevoir, Forretress and
Gyarados keep their existing choices. Bank membership is a selection constraint,
not a substitute for visual/pose validation.

## Separate candidate built

Identity-gated fresh import → source review → existing PBR/visibility/effect-aware
GLB exporter → existing self-contained SCN converter completed successfully.
No prepared source was reused after changing action mapping.

Local artifacts in slot-b/frontend:

- `.tmp/garchomp-bank-inventory.json/inventory.json`
- `.tmp/garchomp-bank-candidate/source/` (fresh imported source and review)
- `.tmp/garchomp-bank-candidate/export/garchomp/` (GLB and export evidence)
- `.tmp/garchomp-bank-stage.json` (converter input, generated from native durations)
- `.tmp/garchomp-bank-runtime/report.json` and `garchomp.scn`
- `.tmp/garchomp-bank-runtime/transitions.png` (idle, damage start/middle/end)

The transition sheet was visually inspected: the standing posture remains
coherent, with recoil and recovery rather than horizontal flight.
Hashes/timing/results are retained in `garchomp_bank_candidate_results.json`.

## Focused runtime evidence

`tests/garchomp_bank_candidate_check.gd` uses the real summary reset/playback code
and the real battle `start_action`, `_action`, `play_action`, faint-loop guard and
actor cleanup. It injects the candidate only inside the test; no registry bypass
was added to the client. The stage's automatic loading/render loop is disabled,
so this is **not** a full arena/network/cache certification.

- 21 summary history comparisons: seven prior clips × three cycles.
- 15 nonterminal battle history comparisons: five prior clips × three cycles.
- Candidate damage end differs from idle by only 0.00013821 idle heights.
- Attack and faint-start begin within 0.002 idle heights of standing idle.
- Native faint-start duration is 100/60 seconds, not the previous 80/60 seconds.
- `play_action` reaches faint-loop; actor stays visible; damage cannot replace
  the completed faint-loop.
- Three fresh actor instances recover the reference damage pose after cleanup.

### Explicit remaining edge case

The initial stress probe forcibly interrupted faint-start at 73% with damage on
the same actor. That produced a 0.0800134-height vertex discrepancy. Summary
scrubbing handles this; battle playback does not reset that interrupted terminal
pose. This result is **not erased or counted as a pass**. The normal lifecycle
finishes faint, stays in faint-loop, then replaces the actor; those paths pass.
If future battle cancellation/revival features need faint interruption on the
same instance, they require a separate reset-contract fix and regression test.

The test intentionally separates arbitrary summary scrubbing from supported
battle transitions; it does not claim every possible battle interruption is safe.

## Tests / unchanged production

`python3 -m unittest test_motion_bank_selection test_scvi_batch
test_batch_hardening test_scvi_identity test_prepare_battle_3d_runtime`:
34 tests, 33 passed, one environment-dependent test skipped.
Candidate Godot Forward+ check passed, including replacement checks.

Existing approved Garchomp SCN remains unchanged with SHA-256
`ed744834e77386e45a805f66095e5353c831ab6dfa9dac707ebc0b67366110a8`.
No local preview/production catalog, approval registry, battle asset, animation
speed, source file, or material tuning was replaced. The candidate remains
unapproved and inactive. No component-sharing research was resumed.

To repeat the focused test from the workspace root:

```sh
ops/worktrees/slot-env slot-b -- env \
  CANDIDATE_REPORT=/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-b/frontend/.tmp/garchomp-bank-runtime/report.json \
  godot --path .worktrees/slot-b/frontend --rendering-method forward_plus \
  --script res://tests/garchomp_bank_candidate_check.gd
```

Next handoff is explicit candidate visual/in-arena review before changing the
catalog hash/entry. Do not silently turn these focused tests into production
approval.
