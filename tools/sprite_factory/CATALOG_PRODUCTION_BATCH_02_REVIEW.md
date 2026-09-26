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
response or battle quality. At this initial technical stage, all 81 candidates
were `runtime_approved=false`.
Next, review the normal forms visually and in real battles, route visible
failures to the queue, then produce and qualify shiny variants for the accepted
normal forms. Only pairs passing those gates should enter the individual-bundle
approval and distribution workflow.

## Local Pokédex and summary-card preview

The 81 normal candidates are staged in the local debug preview manifest at
`/home/adinho/Documents/3d_models/PokeAether/catalog-production-02-review/catalog.json`.
From the development frontend, run
`python tools/sprite_factory/launch_catalog_batch_02_review.py` to open the
game with that manifest. Set Battle presentation to 3D, then inspect a species
in the Pokédex or summary card. The summary play menu includes both physical
attacks. This preview uses exact SCN hashes from the batch-02 results and
rejects shiny, blocked, duplicate or changed scenes. The reviewed battle
registry, launcher packs and release bundles are unchanged.

Focused UI checks admitted all 81 identities, rejected their shiny variants
and held species, and loaded Pupitar, Dialga and Zoroark in both screens with
eight clips and no Godot errors. The older batch-01 preview check also passes
for its four remaining unapproved normal candidates.

## Normal-form visual and motion follow-up

The user reviewed the single-page static gallery and reported that all 81
visible models look good. This is recorded with the exact result/gallery hashes
in [the static review record](catalog_production_batch_02_static_review.json).
It advances these candidates to motion and battle qualification; it does not
approve them for runtime or release.

The existing standalone-SCN motion review now samples the optional second
physical attack when a model has one. All 81 candidates produced **24 images
each**, 0%, 50% and 100% of eight native clips: **1,944 captures** in total.
Every row has an empty error list; no clip was missing and no invalid posed
bounds were reported. The nine midpoint contact sheets were scanned for
obvious body-part loss or species swaps; none was confirmed at that resolution.
The full one-page motion gallery is retained at
`.tmp/catalog-production-02-motion-2026-09-26/index.html`. Still captures
cannot establish smooth transitions, battle scale or floor clearance.

The [shiny material pre-screen](catalog_production_batch_02_shiny_prescreen.json)
finds 69 albedo-only candidates and 12 material holds among the 81 normal
exports. Those 12 change additional eye, emissive, layer-mask or material
settings and must not be silently recoloured. All 69 candidates were exported
with exact normal/shiny geometry and animation parity, then converted to
self-contained SCNs with zero conversion holds. The motion review captured all
eight native actions at three times per shiny: 1,656 images and zero pose or
missing-clip errors. The paired idle contact sheets are retained at
`.tmp/catalog-production-02-shiny-motion-2026-09-26/pairs.html`. These are
technical and local visual evidence. The user reviewed the paired gallery and
reported that all 69 look good. They then continued to battle qualification;
the shinies had no runtime approval at this stage.

The [local battle stress record](catalog_production_batch_02_pair_stress.json)
covers all 69 normal/shiny scene pairs in three real battle UI passes: classic,
stadium and classic again. All 207 pair loads and faint replacements passed.
The six frames over 50 ms occurred while the first pair loaded behind the
screen cover. The temporary test registry was restored byte for byte. This
supports candidate qualification, not release approval.

## Battle grounding follow-up

The raw flat-floor battle pass measured all 81 normal candidates at 60 Hz.
Fourteen native sleep poses warranted a separate visual check after readability
scaling. In [that check](catalog_production_batch_02_sleep_review.json), the
user found only Kyogre's fin visibly sinking through the floor. The other 13
proceed to corrected grounding and battle validation. A floor-clearance fix for
Kyogre eliminated the penetration but made its faint-like sleep pose float
unnaturally, according to the user's second review. Kyogre stays in the review
queue and outside this approval round. The remaining 67 are
checked separately with the existing per-action placement baker at 120 Hz.
The combined pass leaves 79 technically sound normal models: 69 with visually
reviewed shinies and successful three-round battle stress, plus 10 whose shiny
materials remain in the queue. Only Dialga overlaps the classic HUD proxy in
its sleep pose. The 79-model battle image page is retained at
`.tmp/catalog-production-02-battle-gallery-2026-09-26/index.html`. The
[per-species qualification record](catalog_production_batch_02_battle_qualification.json)
pins the evidence and keeps battle visual review pending. No candidate is
approved for release by these diagnostics alone.

The user subsequently reviewed that 79-model battle page and reported that
all look good. The [visual review record](catalog_production_batch_02_battle_visual_review.json)
pins the exact page and species list. Kyogre and Dialga remain held.

## Local approval and individual bundles

The 69 complete normal/shiny pairs are now pinned in the matching local game
and launcher reviewed registries by
[the approval record](catalog_production_batch_02_approval.json). The other 31
requested species are outside this approval: 19 source holds, 10 shiny-material
holds, Kyogre and Dialga. No upload, release index activation or deployment has
occurred.

The 69 unreleased individual bundles contain 138 exact SCNs and total
1,668,550,493 bytes (1,591.25 MiB). Archive hashes, index hash, and the
three-round local battle stress are pinned in
[the bundle preflight](catalog_production_batch_02_bundle_preflight.json).
The launcher installed all bundles, loaded all 138 scenes, then passed no-op
and restart checks. A final battle test against those installed scenes and the
approved registry passed 69 pairs in Classic, Stadium and Classic, with no
uncovered frame hitch over 100 ms. See
[the installed validation record](catalog_production_batch_02_approved_install_validation.json).

## Review-queue follow-up

The first focused review of the 12 near-ready models found two narrow source
differences that can be inspected without changing mesh or animation data.
Shroomish's rare table adds a zero-intensity point light. Bronzong's
single-layer Standard rare table omits an explicit one-UV setting. Both shiny
exports passed exact geometry/animation parity, standalone SCN conversion and
24 sampled motion captures without errors. The user approved both normal/shiny
four-pose comparisons. Each pair then passed three rounds of real battle UI
stress. Their individual local bundles passed installation, combined four-scene
loading, no-op and restart checks. Both are approved locally by the pinned
[follow-up record](catalog_production_batch_02_review_queue_approval.json),
bringing this batch to **71 approved pairs**. The two new bundles total
51,464,759 bytes. Neither was uploaded or activated in a release index.
After local admission, both installed pairs also passed three more real battle
rounds against the reviewed registry, with two pair loads and faint replacements
per round.

Buizel and Numel also reference rare eyelid colour maps, but their normal
eyelid images are absent from the prepared Blender sources. The export worker
correctly refuses to claim an exact replacement, so both remain held. Glalie,
Luvdisc, Luxray, Toxicroak and Froslass differ in eye material floats;
Krookodile changes an eye layer mask. Those six require specific material
review. Kyogre and Dialga retain their battle holds, and the 19 source holds
are unchanged. The remaining review queue is **29 models**.
