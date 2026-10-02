# Calyrex riders and crowned wolves: four-form review checkpoint

Task `legendary-riders-crowned`, assigned frontend slot-b, 2026-10-02.
The source mapping is pinned in `catalog_legendary_forms_intake.json`:
Calyrex Ice/Shadow Rider (`pm0986_12_00` / `pm0986_13_00`), Zacian Crowned
(`pm0938_12_00`) and Zamazenta Crowned (`pm0939_12_00`). National Dex and
internal resource numbers differ. These are independent full source models;
rider/horse meshes are not assembled from unrelated approved base scenes.

## Production and provenance

`catalog_legendary_riders_crowned.py` reuses the existing native import/export,
material reconstruction, layered emission and variant-parity tools. The
pinned importer commit is `b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04`.
The existing importer/dependencies beneath slot-a `.tmp` are read-only inputs;
no caches, credentials or machine state are copied. All new candidates,
receipts, logs and capture projects stay beneath this assigned frontend's
`.tmp/legendary-riders-crowned-v1`. External source files remain untouched.

Four rigs import and export successfully, hierarchical and flat. Native clips
include idle, two physical attacks, special attack, damage, faint start and
faint loop. Both riders also have native sleep. The crowned wolves do not:
their proposed sleep freezes their own idle, closes their own eyelids using
their own faint endpoint and adds subtle root breathing. The existing native
faint loop is restored unchanged; no cross-rig sleep is borrowed. Assertions
preserve the source geometry, nodes, skins, native animation metadata and
original buffer prefix. Normal/shiny geometry and motion signatures match.
Matched official normal/rare tables provide layered albedo, eye colours and
emission. Native material animation side channels remain a review limitation.

## Visibility correction

The initial standalone captures passed structural checks but showed all
Zacian sword variants and a detached ice lance simultaneously. This was an
unapplied source visibility channel, not missing skeletal animation. The
initial `runtime-v1` and `appearance-captures-v1` remain as rejected evidence.

The current stage binds every exported mesh to each clip's exact native TRACM
visibility targets. Fixed states hide Zacian's six alternate sword effects,
Ice Rider's two lances and both horses' unshown tooth meshes. Zamazenta's
special attack has framed source keys: the alternative eye mesh is shown
between source frames 23 and 99; the ordinary eye mesh is shown otherwise.
The existing source decoder interprets explicit frame keys and LSB bitsets,
without guessing an independent clock. Source duration, looping and hash are
checked against each corresponding exported skeletal clip. Authored wolf
sleep inherits only the fixed, source-bound idle visibility states.

The existing runtime converter bakes these into the native AnimationPlayer;
there is no new runtime sidecar or registry change. Eight current standalone
SCNs in `runtime-v2` reload successfully. The exact scene visibility is checked
in reverse clip order, at endpoints and source key boundaries: 7,048 property
checks pass. Nine existing visibility-export unit tests also pass.

## Joint visual review

`appearance-captures-v3` contains 176 captures for the eight appearances, with
front/back, low face and angled side views. Godot 4.6.2 AMD Compatibility
reports zero timing, geometry, scene-reload or reverse-order skeletal pose
errors for all 64 clips. Missing inherited eyelid-channel warnings remain in
the original import reports; they are not automatically visual failures.

`review-v1` provides one normal/shiny review page for all four forms, with the
existing pose controls and extra camera choices. HTTP 200 checks passed for
the page and an image at `http://127.0.0.1:8792/`. Browser control is unavailable
in this session, so the link must be opened by the user. The exact source,
stage, runtime, capture, visibility and page hashes are saved in
`catalog_legendary_riders_crowned_checkpoint.json`. The user approved all four normal/shiny pairs on 2026-10-02
(“Alle vier goed”). Appearance approval is recorded against this exact
checkpoint; battle and runtime admission remain false pending their gates.

After appearance approval: stage the eight exact assets beside Dragonite,
measure native full-clip clearance, calibrate and verify at 120 Hz, then obtain
one joint battle visual review. Installed runtime identity/preloading,
performance qualification, four individual bundles and explicitly authorized
R2 publication follow. No current game/launcher registry, desktop manifest,
release activation or R2 content changes occur in this checkpoint.

## Reproduction

Run the driver phases `export`, `material`, `stage`, `visibility` in order.
Convert `stage-visibility-v2.json` using `prepare_battle_3d_runtime.gd` into a
new output directory. The isolated capture project uses
`catalog_dlc_runtime_review.gd`; its catalog additionally includes angled side
views of each front pose. Run `catalog_legendary_visibility_check.gd` with
`POKEAETHER_LEGENDARY_WORK` set to the cohort evidence root. Preserve all
completed captures and choose a new directory when repeating a review.

## Battle calibration in progress

The approved eight appearances are staged beside the pinned Dragonite control.
All eight use source scale 1.0; their silhouettes meet the existing readability
threshold without enlargement. Native 60 Hz clearance measurements yielded
matching normal/shiny profiles and no faint-start/loop endpoint holds.

The first independent 120 Hz validation exposed brief floor intersections in
both crowned wolves' second physical attack. `catalog_legendary_clearance_refine.py`
uses the exact fine measurements and their pinned previous profile to raise
both adjacent 60 Hz offset keys around each dip. Maximum extra corrections are
3.69 cm for Zacian and 8.70 cm for Zamazenta; Ice Rider also receives sub-mm
clearance refinements. Native geometry, skeletal clips and timing remain
unchanged. Paired variants share identical offset arrays. Sleep/loop profiles
remain constant and faint endpoint continuity is asserted. The original
measurement and unsuccessful first validation are retained. A new independent
validation must pass before the final battle page and admission.

The repeated `battle-validated-v2` report is complete: eight appearances,
64 full clips and 224 battle shots. Every 120 Hz clearance minimum is at least
2.4 cm (idle target 2.5 cm, action target 3 cm), and all measured silhouettes
clear the HUD proxy in both camera presets and both sides. The four-pair
`battle-review-v1` page has 449 pinned files; page and image HTTP 200 checks
passed at http://127.0.0.1:8793/. The user approved all four battle pairs on 2026-10-02 (“Alle vier goed”).
These flat-floor/HUD-proxy measurements do not replace the later installed
runtime, arena, performance and bundle qualification gates.

## Installed runtime and bundles

`catalog_legendary_riders_crowned_admission.py prepare` binds the exact approved
GLB/SCN hashes, calibrated timings, placement, visibility and shared normal/shiny
motion profiles into four separate bundles (eight standalone scenes), totalling
98.76 MiB. Transactional installation, no-op planning and restart checks pass.
`battle_3d_legendary_forms_check.gd` passes all four exact runtime identities,
normal/shiny swaps without new downloads, sleep, two physical attacks and
complete preloading before reveal. The new stress wrapper reuses the existing
real battle lifecycle/cache/loading/20 ms limits and prepared observation
period. Performance qualification and final registry admission are pending.
The failed installer invocation in the game project is retained separately;
the successful installer uses the launcher project containing bundle storage.

All three installed real-battle stress rounds pass the existing 20 ms p95 gate:
17.278 ms (classic), 17.198 ms (stadium), 17.126 ms (classic again). Prepared
steady-frame, load-span, covered-stall, cache budget, retained-object and memory
checks also pass. The fixture is admitted into identical game/launcher reviewed
registries and rechecked using actual admitted runtime identities. The final
restart test initially required exactly four downloads despite a valid cache;
its assertion now matches the existing Kyurem at-most-one-download-per-form
rule. Exact SHA/identity, preloading and no-swap-download checks are unchanged;
that failed log remains evidence. Final admitted runtime verification passes.

`catalog_legendary_riders_crowned_bundle_qualification.json` and
`release/approved_3d_legendary_riders_crowned_index.json` bind the four bundles.
Local qualification is complete. R2 publication, active release-index selection
and desktop release certification remain separate; no public content or active
release manifest has been changed by this task.
