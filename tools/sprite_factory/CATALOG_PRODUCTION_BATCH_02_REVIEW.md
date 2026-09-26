# Catalog production batch 02 — technical handoff

Date: 2026-09-26. Pipeline base: local `development`
`3c7d0aef9f6b09513a5bce9e49f3265c5285124c`. No pipeline algorithm or
quality gate was changed.

The [manifest](catalog_production_batch_02.json) selects the next 100 canonical
normal-form species in National Dex order from the pinned SCVI resource catalog,
after excluding the earlier observation and production cohorts. Resource IDs
come from the catalog identity gate, not from Dex-number arithmetic. The cohort
runs from Pupitar to Zoroark.

| Gate | Count |
| --- | ---: |
| Requested | 100 |
| Verified identity and source | 98 |
| GLB exports and standalone Godot scenes | 81 |
| Native animation clips | 648 |
| Models with second physical attack | 81 |
| Godot pose/timing errors among converted models | 0 |
| Standalone preview images | 405 |
| Held for separate investigation | 19 |

The 19 safe holds are grouped by the existing gate's reason:

- Ambiguous or incomplete idle source (9): Wingull, Pelipper, Swablu, Altaria,
  Salamence, Starly, Staravia, Honchkrow, Giratina.
- Identity/source selector (2): Slakoth, Arceus.
- Visibility or source shape mapping (5): Azurill, Sableye, Shellos,
  Gastrodon, Weavile.
- Unsupported material profile (2): Torkoal, Cresselia.
- Ambiguous auxiliary effect loop (1): Rotom.

Per-species resource IDs, GLB and SCN hashes, clip names, exact hold reasons,
and report hashes are in
[catalog_production_batch_02_results.json](catalog_production_batch_02_results.json).
All 81 scenes were reloaded as self-contained resources; the converter asserted
zero external dependencies. The Godot review checked all exported native clips
for timing, finite geometry and independence from the previous pose. The review
command returns exit 1 because the 19 holds remain in its cohort report; its
81 exported rows have empty error lists. Focused identity and Godot-review unit
checks: 19 passed.

Local task-slot review artifacts:

- `.tmp/catalog-production-02-review/source/index.html` — source renders.
- `.tmp/catalog-production-02-review/export/index.html` — GLB/Godot diagnostic.
- `.tmp/catalog-production-02-images/index.html` — 81 standalone SCN renders,
  five poses each; `contact-1.jpg` through `contact-3.jpg` give an idle overview.
- `.tmp/catalog-production-02-runtime/report.json` — self-contained scene paths,
  hashes and native clip metadata.

The static contact sheets were scanned for obvious identity/geometry failures;
they do not establish facial animation, shading, scale, grounding, material
response or battle quality. The 81 candidates remain `runtime_approved=false`.
Next, review the normal forms visually and in real battles, route visible
failures to the queue, then produce and qualify shiny variants for the accepted
normal forms. Only pairs passing those gates should enter the individual-bundle
approval and distribution workflow.
