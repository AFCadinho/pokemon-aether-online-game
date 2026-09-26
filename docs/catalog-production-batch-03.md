# Catalog production batch 03

On 27 September 2026, the next 100-species cohort was screened against the
SCVI source and motion dump. Identity checks passed for 98 species. Source
review and diagnostic GLB export produced 65 candidates. All 65 converted to
self-contained Godot scenes with 520 native clips, including a second physical
attack for every model. The standalone motion review captured eight actions at
three times per model: 1,560 images, with zero missing-clip or pose errors.
None are approved for runtime use yet.

The 35 held cases are recorded by species and reason in
`tools/sprite_factory/catalog_production_batch_03_intake_result.json`:

| Hold reason | Count |
| --- | ---: |
| Ambiguous visibility variant or unsupported visibility clock | 14 |
| Unsupported transparent/refraction material | 8 |
| Ambiguous idle motion bank | 8 |
| Ambiguous auxiliary effect loop | 3 |
| Source identity mismatch | 1 |
| Cross-form motion selector | 1 |

The disposable source review gallery and diagnostic exports are retained
locally under `.tmp/catalog-production-03-review-2026-09-27/` in slot-a.
Standalone scenes are in `.tmp/catalog-production-03-runtime-2026-09-27/`;
the single-page motion gallery is
`.tmp/catalog-production-03-motion-2026-09-27/index.html`. The runtime report
SHA-256 is `d140fdebc716b678eaa5048f7b92e62605c3ef3480f617f9b26a936f6ffd8038`;
the motion review JSON SHA-256 is
`c865ec794c4813dabb88f600283ea8e3f60cff039789109642c4f3c5ae198b2a`.

The next stage is human visual review, battle placement and animation checks,
then normal/shiny pairing and approval only for qualified models. Held cases
can be addressed independently.
