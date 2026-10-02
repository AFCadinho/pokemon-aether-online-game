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
`catalog_legendary_riders_crowned_checkpoint.json`. Appearance, battle and
runtime admission remain false pending their respective gates.

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
