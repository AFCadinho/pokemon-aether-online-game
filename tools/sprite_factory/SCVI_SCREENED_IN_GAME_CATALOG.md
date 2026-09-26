# Local screened 3D test catalog

**Current status:** 61 of the original 75 normal models now have approved
normal/shiny pairs; 14 remain normal-only screened candidates. The original
75-entry local catalog still loads each model under its current reviewed or
screened status. See [the screened-100 battle approval](SCREENED_100_BATTLE_APPROVAL.md).

## What is available

`build_screened_test_catalog.py` builds a direct local catalog from the fixed
100-model visual-screening evidence. It includes **75 new normal-form species**:
the 79 `visual_pass` rows minus Arcanine, Articuno, Dragonite and Lucario, which
already use their separate reviewed normal/shiny models. It contains no shiny
candidate, held model, generated 2D art, copied scene, source-model edit or
launcher package.

The checked-in screened and reviewed registries bind each entry to its exact
SCN SHA-256 and native action timings. The presenter ignores placement/timing
supplied by a selected local catalog. A changed model fails before import. The
14 additional normal/shiny pairs from batch 01 moved to the reviewed registry;
see [their playable review record](CATALOG_BATCH_01_PLAYABLE_REVIEW.md). The
screened-100 approval later moved 55 more, and placement recovery moved six,
leaving 14 normal-only screened entries.
The older portable reviewed-model pack still contains the original seven pairs.

The remaining 14 screened candidates have no arena-grounding, motion-clearance
or shiny qualification. The presenter retains its safe classic 3D floor
fallback whenever one is active. A shiny screened form, unsupported form,
double battle or Substitute falls back to 2.5D. The reviewed pairs have
calibrated profiles and qualified shiny forms.

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
  catalog validator and imports Charizard and Corviknight screened scenes
  through the regular background integrity/import path.
- Existing 43 SCVI and 16 portable model-pack tests still pass.

The remaining screened entries are a local review boundary. The 61 approved
pairs have their own individual bundles; publishing the six newest bundles is
separate.
