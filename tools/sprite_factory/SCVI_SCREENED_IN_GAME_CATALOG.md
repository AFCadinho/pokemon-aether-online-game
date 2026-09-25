# Local screened 3D test catalog

## What is available

`build_screened_test_catalog.py` builds a direct local catalog from the fixed
100-model visual-screening evidence. It includes **75 new normal-form species**:
the 79 `visual_pass` rows minus Arcanine, Articuno, Dragonite and Lucario, which
already use their separate reviewed normal/shiny models. It contains no shiny
candidate, held model, generated 2D art, copied scene, source-model edit or
launcher package.

The checked-in `screened_model_catalog.json` binds each candidate to its exact
SCN SHA-256, placement and seven native action timings. The presenter ignores
placement/timing supplied by a selected local catalog and retrieves them from
that checked-in screened registry. A changed model fails before import. The
14 additional normal/shiny pairs from batch 01 have since moved to the reviewed
registry; see [their playable review record](CATALOG_BATCH_01_PLAYABLE_REVIEW.md).
The screened registry again contains only the original 75 normal candidates.
The older portable reviewed-model pack still contains the original seven pairs.

These original 75 candidates intentionally have no arena-grounding,
motion-clearance, shiny or live-PvP qualification. The presenter therefore
retains its safe classic 3D floor fallback whenever one is active instead of
claiming calibrated forest/stadium grounding. If either active Pokémon is shiny,
an unsupported form, a double battle or uses Substitute, the normal pair
fallback remains 2.5D. A candidate's normal form can still be inspected in a
real single battle. The approved batch-01 pairs have their own calibrated profiles and
qualified shiny forms in the reviewed registry.

## Current local artifact

The generated, machine-local catalog is:

`/home/adinho/Documents/3d_models/PokeAether/screened-catalog-v1/catalog.json`

It has SHA-256
`e3f7f36ff5b8ad51a586afca2e6043251ab43e590f5bf1a3b767b4f295214733`.
Its entries point at retained task-slot review scenes; it is deliberately only a
local test artifact, not a portable archive. Do not move it to another machine,
delete the task slot, or distribute it as a model pack. Rebuild it from the
checked-in script and its reviewed evidence if those source scenes change.

To use it, enable **3D (experimental)** in game Settings and choose this JSON
under **Choose local 3D model catalog…**. The client applies the selection to a
new battle. Existing reviewed model-pack selection and 2D/2.5D preference are
not overwritten.

## Deliberate retention

No existing 3D source, reviewed model pack, generated 2D/2.5D asset or old
catalog was removed. The test catalog is only 24 KiB but references roughly
886 MiB of retained reviewed SCNs. Keeping them is required for this reversible
in-game test and preserves a known-good rollback path. Removal should be a
separate, explicit cleanup after a portable screened/approved pack exists and
the in-game review is complete.

## Focused validation

- Python builder tests cover only visual-pass inclusion, hash binding, missing
  scenes, stale registry data and no-overwrite output.
- `screened_model_catalog_check.gd` loads the original 75 entries through the real local
  catalog validator and imports unrelated Charizard and Eevee candidate scenes
  through the regular background integrity/import path.
- Existing 43 SCVI and 16 portable model-pack tests still pass.

This is a testing-admission boundary, not a visual approval, release or
replacement of the official 3D model catalog.
