# Returning to the screened 100-model cohort

**Later result:** all 61 technical pairs are now battle-qualified and approved
with individual local bundles. The first 55 are in the v3 release index; the
last six placement recoveries are local and await a later content index. See
[the battle approval record](SCREENED_100_BATTLE_APPROVAL.md) and
[the placement recovery](SCREENED_100_PLACEMENT_RECOVERY.md).

The earlier 100-model experiment yielded 79 sampled-clip visual passes. Four
already had separate approved normal/shiny models, leaving 75 normal-form
models in the local screened catalog. This task resumed production from those
75 exact, hash-bound normals without changing the converter or admitting any
new model to the game release.

## Production result (26 September 2026)

- 63 of 75 screened normals had an official rare material table with only
  inspected base-colour substitutions and passed the initial shiny preflight.
- Three batches requested all 63. **61 shiny GLBs** passed exact geometry and
  animation parity with their normal GLBs; **61 standalone shiny SCNs** were
  built and reloaded. They contain 488 native mapped clips in total.
- Godot Forward+ rendered seven actions at three sampled times for every new
  shiny SCN: **1,281 captures, zero pose or rendering errors**. The matching
  current normal SCNs passed the same 1,281-capture check.
- Garchomp, Volcarona and Hydreigon are among the 61 technical pairs.
- **14 models remain held**. The initial 12 are Cloyster, Ditto, Dragonair,
  Flapple, Forretress, Gengar, Growlithe, Hypno, Jolteon, Magikarp, Meowth and
  Rayquaza. Eevee's selected source lacks an embedded normal texture for a
  second form. Murkrow's official rare texture has different dimensions;
  a separate retry confirmed that hold. These are kept in the review queue.

The machine-readable status and exact normal/shiny scene and GLB hashes are in
[`screened_100_shiny_production_results.json`](screened_100_shiny_production_results.json).
The 75-model preflight and three batch manifests are alongside it. The new
exports, SCNs and render captures are retained in slot-b's
`.tmp/screened-100-shiny-batch-*`, `.tmp/screened-100-shiny-runtime-*`,
`.tmp/screened-100-shiny-motion-*` and `.tmp/screened-100-normal-motion-61`.
Those ignored artifacts remain machine-local; do not remove the retained slot
or source folders while this review is open.

The normal/shiny comparison gallery is
`/home/adinho/Documents/3d_models/PokeAether/screened-100-paired-review-v1/index.html`.
Its manifest pins 366 selected comparison images and the scene hashes. It is a
local visual handoff, not a portable model pack or player catalog.

## Admission boundary and next batches

At this production handoff, all 61 remained **technical candidates**. Their colour/material appearance still
needs human review, followed by battle placement, grounding, HUD, cache and
normal/shiny switching qualification in manageable groups. A species that fails
those checks goes to the review queue without blocking the rest. Only after
that decision should its hashes move to the reviewed registry and its own
bundle be prepared. None of these 61 was added to the release-approved set,
R2, or the base game build by this production run.

The other 21 members of the original 100-model cohort were outside this
75-normal screened catalog because of visual or source holds. Charmander is
one of those visual holds: its coarse tail flame is still an open review case.
