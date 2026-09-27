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

The visual, battle and shiny follow-up is recorded below. Approval remains a
separate step for qualified models; held cases can be addressed independently.

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
Battle placement and real battle loading were completed in the follow-up below.

## Battle and exception follow-up

The original 65 normal candidates completed a full independent 120 Hz battle
placement pass. All stayed inside both battle cameras and clear of the HUD
proxy. The user visually accepted the 16 source sleep poses that triggered
floor-bound warnings. A diagnostic lift removed the numeric warnings but made
some poses visibly float, so the reviewed source poses remain the candidates.
The full pass found one additional brief floor dip in Mareanie's second
physical attack. A targeted profile correction now clears it at 120 Hz.
Tynamo's first readability cap left it at 25 pixels in the far camera; a
separate 10.5× diagnostic reaches 65 pixels, stays in view and clears the HUD
and non-sleep floor tests at 120 Hz. The user accepted its new battle size in
a side-by-side comparison and accepted all 65 original battle views in the
single-page gallery. These are review profiles, not runtime
admission. The battle reviewer now records the display size actually used by
screen-space measurements after the display has resized.

Fifteen of the 35 original source holds were recovered through three bounded
source rules: constant auxiliary-effect UV tracks in the selected idle clip
(Delphox, Salandit, Salazzle), uniquely owned catalog-form visibility targets
(Deerling, Flabébé, Floette, Florges, Sawsbuck, Vivillon), and an explicit
diagnostic cross-bank sleep selector (Braviary, Eelektross, Noibat, Noivern,
Rufflet, Talonflame). The user accepted all 15 source models and the eight
cross-bank sleep poses visually. All 15 converted into standalone Godot scenes
and passed 360 sampled pose captures without errors.

The first 12 shiny material holds yielded nine additional candidates after
explicit source-table review; the recovered 15 normal models yielded another
13 shiny candidates. All 22 converted into standalone scenes, passed 528
sampled pose captures without errors, and were visually accepted by the user
in normal/shiny pairs. The five remaining shiny holds are Braviary,
Crabominable, Eelektrik, Eelektross and Skrelp. They need material or embedded
texture evidence before export.

Across the 100-species cohort, this leaves 80 locally exported normal models
and 75 locally exported normal/shiny pairs. Those counts describe technical
candidates only.

The 15 recovered normals were measured in both battle cameras. Readability
scaling corrected six small models. Vivillon, Noibat and Noivern needed a
90-degree battle yaw to show their silhouettes; Braviary needed a 0.75 scale
to clear the HUD proxy during its special attack. The user visually accepted
all 15 corrected battle views, including Delphox and Florges in sleep. Their
independent 120 Hz pass is complete: the smallest non-sleep clearance is
0.0129 m, all idle views are at least 65 pixels high, and no shot crosses the
camera or HUD proxy. Delphox, Flabébé and Florges still have a below-floor
sleep bound, but their source-height battle views were visually accepted.
For Delphox and Braviary, the geometric flauwval lift made the model visibly
float. Their explicit source-height faint profiles reproduce the accepted raw
battle screenshots byte for byte in a separate 120 Hz run, with no HUD or
camera conflict; their geometry bounds remain below the floor by design.
All 75 complete normal/shiny pairs also passed three real battle-presenter
rounds each, in groups of at most ten. The test covered asynchronous loading,
both battle arenas, normal/shiny replacement, attack interruption, faint and
re-entry. Each round loaded every pair and completed every faint replacement.
Across the 24 rounds, frame-time p95 was 17.173–17.515 ms; all 48 measured
stalls over 50 ms occurred while the battle cover was visible. Cache and scene
release assertions passed, and the temporary registry was restored byte for
byte after each group. This is local battle-stress evidence, not runtime or
release approval. No batch-03 model has been approved, bundled or uploaded.

Twenty source holds remain: eight transparent/refraction materials, eight
dynamic visibility clocks (including the newly exposed Fletchling and
Fletchinder cases), two unowned visibility targets (Palossand and Sandygast),
Meloetta's identity mismatch and Mimikyu's cross-form selector. These remain
in a separate review queue; none is silently admitted. Batch 04 has not
started. The exact recovery sets, feedback and local artifact hashes are in
`tools/sprite_factory/catalog_production_batch_03_exception_review.json`.
