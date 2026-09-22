# Garchomp candidate: real arena review

2026-09-22 — candidate passes this focused offline arena review, with a minor
ground-contact note. No catalog activation or production approval was performed.

`tests/garchomp_arena_review.gd` uses the real asynchronous integrity loader,
model cache, Forest/Stadium arena builders, lighting/material-response renderer,
action completion/reset, faint lifecycle and species replacement. Unlike the
previous isolated action test, the presenter's normal `_process` remains active.
The only admission exception is inside the test subclass: the exact recorded
candidate hash replaces Garchomp in the in-memory catalog. No client registry,
catalog file or settings file is modified. Azumarill is the unchanged control.

## Completed

- Forest and Stadium both loaded as real 3D arenas, not classic fallback.
- Two cycles per arena: physical attack, special attack, damage, faint,
  switch to Azumarill, then back to a fresh Garchomp actor.
- Each nonterminal action returned to idle automatically.
- Faint completed into a visible faint-loop in all four cycles.
- All four replacements created a new actor and returned to idle.
- Both stage viewports were released after teardown.
- 22 pose captures and world-space vertical bounds were recorded.
- Nine representative captures were visually inspected (listed in results).
  No wrong flight pose or disappearing faint actor was observed.

Native scale, orientation and zero lift remain unchanged. Sampled vertices extend
about 0.003 world units below the surface in idle, and 0.011 during faint. In a
metre-based interpretation those are approximately 3 and 11 mm. This is a small
remaining ground-contact deviation, not perfect arena calibration; no per-model
offset or motion modification was introduced to conceal it.

## Evidence and limits

Numerical evidence and reviewed captures: `garchomp_arena_review_results.json`.
PNG files and raw results remain in slot-b/frontend
`.tmp/garchomp-arena-review-02/`. Runtime candidate remains in
`.tmp/garchomp-bank-runtime/`, pinned by the previous candidate results.

The first harness attempt queued the old catalog entry before test injection;
the hash assertion rejected it. The final harness clears that pending queue and
requeues the pinned candidate before normal loading. The failed `-01` output is
not used as successful evidence.

This is an offline presenter/arena integration review, not a networked PvP
session, full HUD/input test, all-arena certification, pixel-exact material
comparison or exhaustive frame-by-frame grounding analysis. The previously
recorded forced faint-start interruption edge case remains unchanged.

## Reproduce

From workspace root, with a new absolute output directory:

```sh
ops/worktrees/slot-env slot-b -- env \
 SUMMARY_MODEL_CATALOG=/home/adinho/Documents/3d_models/PokeAether/screened-catalog-v1/catalog.json \
 CANDIDATE_REPORT=/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-b/frontend/.tmp/garchomp-bank-runtime/report.json \
 CANDIDATE_ARENA_OUTPUT=/absolute/new/review-directory \
 POKEAETHER_FOREST_MANIFEST=/home/adinho/Documents/3d_models/forest-runtime/forest.json \
 godot --path .worktrees/slot-b/frontend --rendering-method forward_plus \
 --script res://tests/garchomp_arena_review.gd
```

The next useful handoff is a scoped local catalog replacement, retaining the old
model for rollback and updating the matching timing/hash metadata. More generic
animation research is not required before that local review step.
