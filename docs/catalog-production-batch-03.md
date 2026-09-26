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

## Visual and shiny follow-up

The user reviewed all 65 normal models on the single-page motion gallery and
reported “Allemaal goed.” The exact cohort and gallery hash are recorded in
`tools/sprite_factory/catalog_production_batch_03_static_review.json`.

Official rare materials yielded 53 albedo-only shiny candidates; 12 are held
for settings or texture-channel differences in
`tools/sprite_factory/catalog_production_batch_03_shiny_prescreen.json`. All
53 eligible shinies passed exact normal/shiny geometry and animation parity,
converted to self-contained scenes, and produced 1,272 sampled pose images
without errors. The user reviewed the 53 side-by-side pairs and reported
“Allemaal goed.” The evidence is pinned in
`tools/sprite_factory/catalog_production_batch_03_shiny_visual_review.json`.
Battle placement and real battle loading remain pending for this cohort.
