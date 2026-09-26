# Catalog production batch 03

On 27 September 2026, the next 100-species cohort was screened against the
SCVI source and motion dump. Identity checks passed for 98 species. Source
review and diagnostic GLB export produced 65 candidates for the next visual
and battle qualification stages. None are approved for runtime use yet.

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
locally under `.tmp/catalog-production-03-review-2026-09-27/` in slot-a. The
next production stage is to check the 65 exports in Godot, review normal and
shiny appearance, test battle placement and animations, and approve only the
qualified pairs. Held cases can be addressed independently.
