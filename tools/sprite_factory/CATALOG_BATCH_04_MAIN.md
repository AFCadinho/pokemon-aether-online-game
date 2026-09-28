# Batch 04: qualification of the other 200 candidates

## Current status — 2026-09-28, local admission complete

All 200 normal/shiny pairs are locally approved in the game and launcher reviewed
registries. `catalog_production_batch_04_main_approval.json` pins the exact
400 scenes and 200 individual bundles. The corrected bundle index contains 178
version-1 and 22 version-2 bundles, totaling 5.40 GiB. No R2 upload, release
certification, publication or deployment was performed.

The first candidate assembly accidentally selected older scenes for 21 models.
The user spotted Typhlosion's white flames in the proposed final gallery. The
reconciliation restored all 21 exact accepted normal battle scenes and seven
corresponding shiny scenes; Floragato retained its separately requalified later
fix. The user accepted the corrected 147-pair normal/shiny page with “Allemaal
goed”. `candidate-reconciliation-v2.json` and the version-2 candidate manifest
retain the exact hashes. The original candidate bundles and rejected gallery
remain as evidence, not release inputs.

All 200 final pairs passed three real battle rounds in 25 groups: Classic,
Stadium, Classic. A single 819 ms uncovered Perrserker loading stall occurred
while the shared-store install test saturated the machine. Group 10 was rerun
after installation stopped; all three rounds passed with no uncovered stall.
Each of the 200 individual bundles then passed launcher archive validation,
normal/shiny scene load and hash checks, no-op update and store restart.
`catalog_batch_04_main_admission_check.gd` passed against the installed
400-scene catalog. Thirteen earlier normal-only screened entries were removed
when their reviewed pairs were admitted; only Murkrow remains screened.

The shared-store full-catalog replay was stopped because its repeated
whole-store validation becomes expensive as more bundles accumulate. Its
transactional partial results remain local; they are not counted as a
completed 200-bundle check. Full release verification remains for a future
certification request.

## Earlier qualification status — 2026-09-28

The user accepted the complete final overview with “ja dit is nu allemaal goed”.
All reported findings in that overview are closed: 18 normal/shiny appearance
pairs and 15 current normal battle scenes. Together with previous accepted battle
galleries, exactly **200 unique normal battle scenes** are now accepted. Their
scene and GLB files were re-hashed against the accepted evidence.

`catalog_production_batch_04_main_review.json` is the durable review inventory.
It records scoped appearance acceptances and exact normal battle selections; it
is **not** a release admission. Earlier exception-only appearance feedback retains
its original scope. Final pair assembly must reconcile those records with the
chosen shiny scenes, followed by real battle runtime qualification and individual
bundle install/load/update checks. No new reported visual defect is currently open.

Focused verification: 75 Python tests passed; Godot material-effect save/reload,
visibility animation/isolation and visible-bounds checks passed. A full release
certification was not requested or run. The historical log below preserves earlier
intermediate states and failed candidates; this section is the current status.

## Scope

The user requested completion of the 200 remaining candidates on 2026-09-27.
Subtract the 24 identities in `catalog_production_batch_04_recovery_approval.json`
and Walking Wake / Iron Leaves in `catalog_production_batch_04_sketchfab_approval.json`
from `catalog_production_batch_04.json`. Preserve starter-line priority and then
National Dex order. There are exactly 200 unique identities in this task.

The earlier idle/eye galleries were accepted; that is not full animation,
shiny, battle, bundle, or release approval. The 26 completed recovery cases are
outside this task. No batch 05, production access, publication, or new automatic
artistic approval is authorized by this local qualification run.

## Local continuation

Task slot: `slot-a`, task `batch04-main-qualification`.
Artifacts: `frontend/.tmp/batch04-main/` within that slot.

- `batch.json`, `inventory.json`: exact 200-case selection and renewed source identity proofs.
- `normal/export/catalog.json`: first full eight-action export pass, including safe holds.
- `shiny/catalog.json`: official rare-material exports and geometry/motion parity, including safe holds.
- `normal-retry-*/catalog.json`: explicit source recovery passes; failed retries do not approve anything.
- `groups/*/normal-runtime/`, `shiny-runtime/`: self-contained Godot scenes.
- `groups/*/normal-motion/`, `shiny-motion/`: three rendered samples for each native action.
- `runtime-status.json`, `battle-status.json`: per-group progress, never approval receipts.
- `groups/*/battle/`: baseline 60 Hz measurements, provisional readability/resting placement,
  independent corrected 120 Hz measurements, both cameras and both sides.

All artifacts remain review candidates. Full visual review and battle acceptance
must bind the exact generated scenes. Technical conversion alone must not be
reported as a cleared review queue. Candidate scale/resting adjustments must be
shown to the user before admission.

## Source exceptions under review

The normal source-static flame path is an explicit per-material diagnostic:
native displacement height, both finite native UV transforms, hash-verified motion bank,
and no UV tracks for that material in any bank file. It invents no scrolling.
Embedded lower-detail meshes may only be held hidden with an explicit diagnostic
when their exact source-bound LOD names have a covered full-detail counterpart.
Ordinary missing visibility tracks still fail.

Rare-material recovery distinguishes applied importer inputs from unrepresented
source parameters. Low-eye colour uses the pinned importer's `LowEye_color`
input. Roughness and emission overrides verify the embedded normal value before
substitution. Unrepresented layered roughness/metallicity, clearcoat, iridescence
and extra colour layers remain documented visual-review limitations; they are
not claims of source shader parity. Unknown inputs, changed alpha components,
unbound sockets and non-finite values remain held.

## First full normal/shiny visual feedback

The 73-pair snapshot is `.tmp/batch04-main/review-01/`, with exact scene and
capture hashes in its receipt. The user reported white flames on Typhlosion,
sparse smoke on Gastly, and a dot-sized Floragato. This is recorded as an
exception review, not blanket release approval.

- Floragato's hidden native yoyo mesh occupied an approximately 85-unit bounding
  box in idle. The review and battle measurement renderer now excludes invisible
  meshes (including hidden ancestors), and includes them again when native
  visibility enables them. The model is not artificially enlarged to compensate.
- Source-static flames already have their native UV transform in the colour-domain
  bake. A separate static shader samples that bake at original mesh UVs; native
  mask/displacement transforms remain intact. Existing animated shaders are unchanged.
- Gastly's `outward_rim_smoke_v1` is an **authored reconstruction**, explicitly
  selected on its identity-bound intake. It uses outward displacement and soft
  view-dependent opacity around the face, retaining source textures, height and
  loop. It is not recovered original-game shader parity and is not automatically
  enabled for other smoke models. Opaque and displacement-only experiments were
  not selected.

The three-pair comparison and hashed receipt are under
`visual-fixes/comparison/`. The user answered **“ja beter”**. The accepted visual
proposal is now being repacked through the normal exporter; exact final scenes
and battle placement still require qualification. `recovery-groups/fixes-04/`
and `fixes-battle-status.json` contain that continuation. No admission manifest,
bundle or production index is updated by the visual feedback alone.

Numel and Buizel have exactly duplicated native eye tracks. Deduplication is
restricted to byte-equivalent parsed tracks after the same clock checks;
conflicting duplicates remain errors. Upper-only eyelids are restored only
when source material declarations identify them. `BaseColorLayer8` maps to
`LowEye_color` only on eye materials, matching the pinned importer; body-layer8
remains an explicitly unrepresented rare parameter.

Focused checks: visibility variants/export (26), completion effects (8), shiny
recovery (10), eye binding/motion (5); Godot `batch_material_effect_check.gd`
and `review_visible_bounds_check.gd`. Rendered normal/shiny scenes retain
zero pose errors, which does not imply visual or battle approval.

## Second appearance review: Paradox exceptions

The 93-pair snapshot is `review-03/` (Wiglett excluded for a separate faint-pose
recovery). The user reported missing/closed eyes and missing colours on Iron
Treads, Iron Hands, Iron Jugulis and Iron Moth. This feedback is **not** approval
of the four or blanket approval of the other 89.

The opt-in `source_emission_diagnostic` recovery preserves the imported emission
colour/layer graph in an emissive PBR bake. Native interior parallax and lighting
remain approximations. Hash-bound Unlit eye opacity/iris masks use native UV and
scalar timelines (atlas frame, intensity, iris weight), on the same AnimationPlayer
clock as the skeleton. Unknown profiles, source changes, conflicting duplicates,
invalid atlas frames or mismatched clocks are held.

The source importer omitted the constant BaseColor alpha on transparent lenses.
For these explicitly opted-in exports the source table's alpha is carried in the
transparency manifest (0.1 for Treads/Hands/Moth). This prevents the lens from
covering the LED geometry. Depth-test bypass experiments were diagnostic only
and are not used. Jugulis additionally binds the verified Standard `eye_b` UV
material for its side heads and permits the source's repeating UV coordinates.

Continuation artifacts: `normal-retry-8/`, `shiny-retry-8/`,
`recovery-groups/paradox-08/`. These remain visual/battle candidates; no admission
manifest or bundle has changed. Earlier `paradox-06` renders still have obscured
eyes and must not be presented as the corrected result.

`paradox-review-08/index.html` is open for the user's four-pair review, with
before/after switching and normal/shiny scenes. Its receipt binds all eight new
SCNs and 192 captures. All 64 clips exported; motion review reports zero errors.
The user's visual answer is still pending. Focused LED source/clock/duplicate
checks (1) and eye regressions (5) pass. The bounds fast path also matched the
original vertex calculation on 48 actual animated samples across Floragato,
Gastly, Iron Hands and Iron Jugulis (maximum endpoint error 9.54e-7 units).


The user subsequently rejected the mainly white shiny appearance of Iron Hands,
Iron Jugulis and Iron Treads. The source rare albedo substitutions were present,
but the PBR export had omitted the connected native Metallic input. The explicit
emissive export now also bakes that scalar input into glTF's metallic/roughness
texture, retaining the existing roughness map. This is source material recovery,
not an invented shiny recolour. `normal-retry-9`, `shiny-retry-9` and
`recovery-groups/paradox-09` replace the previous appearance candidate; review
is still required. Layered roughness/metallicity unsupported by the pinned source
importer remain a documented limitation.

The corrected silver-material comparison `paradox-review-09/index.html` is open
for review against `paradox-review-08`. All eight exact runtime hashes and 192
captures are bound in the receipt; 64 clips rendered with zero reported motion
errors. The three reported shiny models now export nonzero native metallic maps
in glTF's blue ORM channel (Hands' body is 191/255, not an assumed 1.0). The review
renderer and lights were not changed. User visual acceptance remains pending.


The user accepted the shiny silver correction for Iron Hands, Iron Jugulis and
Iron Treads with “Alle drie goed”. `paradox-review-09/user-feedback.json` binds
that narrow acceptance to the three exact shiny SCN hashes and the review
receipt. It does not approve other models, all normal appearances, battle
placement, or publication. The new four-model battle calibration is running via
`run_paradox_9_battle.py`, status `paradox-09-battle-status.json`.

## Battle exceptions repaired while the main queue continues

User requested concurrent remediation/monitoring, rather than waiting for the
whole battle queue. `normal-retry-10` / `shiny-retry-10` reexport Floragato and
Sinistea with Blender's explicit `export_hierarchy_flatten_bones` option. Native
clips are retained. This prevents nonuniform inherited bone scale from producing
unrepresentable hierarchical glTF transforms. At 60 Hz, Floragato's attack-2
minimum changed from -26.805 to -0.0124 units; Sinistea's large attack excursions
also disappeared. No huge compensating root lift is used to hide bad geometry.

`recovery-groups/placement-10-battle/battle/` combines those exact scenes with
the existing accepted Gastly smoke candidate. Sinistea's readability multiplier
is 6.53296, targeting approximately 68 pixels in the furthest camera (previously
41 pixels at the capped 4x setting). Gastly explicitly gets a constant sleeping
clearance profile; idle/attack hovering intent is retained. The independent 120 Hz
pass has no floor, readability, camera or HUD-proxy findings for all three.
`attention-review-10/` binds the candidate settings, runtime hashes and captures.
Its extra poses are render-only reuse of the completed, hash-bound measurements,
not another certification run. User visual acceptance is pending.

The Paradox battle sweep completed concurrently. Hands, Moth and Jugulis had no
reported measurement issues. Treads' first physical attack crossed the floor
between 60 Hz samples. A targeted 240 Hz diagnostic reproduced a -0.09035 raw
minimum. The flattened export in `normal-retry-11` / `shiny-retry-11` removes that
interpolation excursion (raw minimum -0.01343 at the same 522 samples). Its fresh
full battle sweep is running; do not approve the old Treads scene on that basis.
The main 200-case battle worker remains running independently.

The fresh Treads-11 battle sweep is now complete with no floor, readability,
camera or HUD-proxy findings. Its 28 embedded textures per variant are byte-for-
byte identical to retry-9, preserving the reviewed shiny/metal correction.
The three attention candidates also passed their 120 Hz sweep: minimum
clearance Sinistea 0.01545, Floragato 0.02205, Gastly 0.03000 units; Sinistea is
66.9 pixels high in the smallest idle view. Native source actions, loops and
clocks for Floragato/Sinistea are unchanged (JSON precision tolerance 1e-10 s).
The six `test_bake_motion_placement.py` tests pass. Extra Sinistea attack extrema
were rendered separately in `extra-critical-poses` and inspected; its extended
tea-body whip is source animation, not the earlier export deformation.

The user has been asked to review `attention-review-10` for the three main
corrections; answer remains pending. Paradox battle visual acceptance also
remains pending. This is still an ongoing local task with deliberately
uncommitted pipeline/review changes, not an integrated or released batch.

The user answered “vergelijking ziet er goed uit” for `attention-review-10`.
`attention-review-10/user-feedback.json` records acceptance of the exact Gastly,
Floragato and Sinistea scene hashes and candidate placement digest. Those three
visual corrections are no longer pending; this does not publish bundles.

`paradox-battle-review-11` is now open for the four Paradox battle/appearance
reviews, selecting the corrected Treads-11 scene and the other Paradox-09 scenes.
The receipt binds each variant and each model's placement separately. Pending
user response. Meanwhile `run_sleep_12.py` applies explicit constant sleeping
clearance to Dreepy, Drakloak, Magikarp, Luvdisc, Kyogre and Rayquaza. It reuses
hash-verified existing measurements to form the candidates, preserves their
other motion rules, and runs a fresh 60/120 Hz verification. These remain review
candidates. In particular Rayquaza's separate attack issue is not claimed fixed
by the sleeping correction.

The user answered “Alle vier goed” for `paradox-battle-review-11`. The feedback
receipt binds normal/shiny hashes and placement for Hands, Treads, Jugulis and
Moth. Their appearance and displayed battle poses are accepted; no upload or
release is performed.

The next focused recovery `normal-retry-13` / `shiny-retry-13` tests flattened
native bone export for Morgrem's faint transition, Grimmsnarl's attack-2,
Dragapult's attack-2 and Rayquaza's attack-2. Runtime renders and a fresh battle
pass are queued by `finish_attacks_13.py` and `run_attacks_13_battle.py`. Rayquaza
also receives sleeping clearance there: if the new scene succeeds it supersedes
the older Rayquaza scene used in sleep-12. Do not request review of a superseded
Rayquaza scene or transfer scene-bound acceptance implicitly.

## Main sweep completion

The main battle worker has finished all 21 groups (137 original-pass models).
Its historical reports contain 30 models with findings; these must be reconciled
with later repairs rather than counted as 30 current failures. This does not
mean all 200 candidates are fully qualified: recovered source groups and source/
shiny holds remain separate.

Sleep-12 completed: Dreepy, Drakloak, Magikarp, Luvdisc and Kyogre have no reported
battle issues. Attacks-13 completed: Grimmsnarl, Dragapult and the replacement
Rayquaza likewise have no reported issues. `recovery-battle-review-13` is open
for those eight, with scene/placement/capture hashes; response pending. It uses
Rayquaza from attacks-13, never the superseded sleep-12 scene.

Morgrem retained a small faint-start floor crossing after flattening. A targeted
240 Hz raw measurement feeds a conservative local envelope into that clip's
existing 60 Hz correction table (`repair_morgrem_14.py`). All other clips and
both faint-start endpoints are unchanged. New 60/120 Hz battle verification and
an independent 480 Hz faint-only check are running. This candidate is not yet
visually approved. No live game catalog, release index or bucket is changed.

## Latest battle recovery review

The user accepted all eight normal battle corrections in
`recovery-battle-review-13` (“ja ze zijn goed”). Its feedback receipt pins the
exact scenes and placement. This does not approve unshown shiny variants.

Morgrem-14 now passes the fresh battle check and a separate 480 Hz faint-start
check (642 samples, minimum clearance approximately 0.03). Visual review is
pending and will include the formerly problematic mid-faint time.

Attacks-15 re-exports eleven native models with flattened bone hierarchy; all
normal exports and ten shiny exports passed. Espathra's official rare material
changes LayerMaskScale4 from 0.75 to 1.0; support now verifies and applies that
scalar through the existing strict native-input checks. Espathra shiny-18 has
exported and rendered, using the exact attacks-15 normal scene as its reference.
Its appearance remains pending review.

Sleep-16 (Arrokuda, Enamorus, Tadbulb, Flittle, Flutter Mane, Chi-Yu) and size-17
(Wiglett, Tatsugiri) completed their battle checks without reported issues.
Wiglett uses the repaired flattened faint animation; Tatsugiri uses an explicit
readability candidate. These candidates and attacks-15 await visual review.
No live catalog, bundle index or bucket has changed.

## Remaining original-sweep findings (continued)

Attacks-15 completed: eight of eleven models have no findings; Klawf faint-loop,
Espathra attack-2 and Koraidon attack-2 needed further work. Espathra-22 and
Koraidon-23 use local correction envelopes from independently sampled 240 Hz
clearance. Clip endpoints and all other clips stay unchanged. Fresh battle
verification reports no issues for either correction.

Klawf's native imported faint-loop has opposing quaternion signs in the waist
channel. At frame 1 the interpolated quaternion norm was approximately 0.00225;
frame 60 also approached zero. The corresponding GLB interpolation folded the
model below ground. Retry-24 applies explicit quaternion hemisphere continuity
to this clip only: 13 waist keys change sign, preserving their rotations and
times. Both variants exported; runtime/battle verification and visual review
remain pending. The source Blend is untouched. Three focused mathematical
regression tests pass. This is opt-in, not a global animation rewrite.

Eyes-19 rebuilt Pineco, Magearna, Drednaw, Numel and Buizel shiny scenes with
the repaired eye-manifest binding. All five runtime exports and motion renders
completed. Visual qualification is pending. Finizen/Palafin retry-21 remains
held: required official eyelid textures were never embedded in their source
Blend. Those sources require restoration before shiny qualification.

Focused shiny/LED/eye/motion-placement tests: 22 passed. The first invocation
from the repository root lacked the factory import path; rerunning from the
factory directory passed. No task commit or local integration yet.

Klawf-24 passed the complete fresh battle verification with no findings. The
uncorrected faint-loop minimum improved from -0.43169 (dense old scene) to
-0.00363 (new baseline). Native checks at the formerly degenerate frames now
show unit-length quaternions. Normal/shiny motion renders completed.

The final review selection for these 20 original-sweep repairs is
`recovery-battle-review-25`: Morgrem-14, sleep-16 (six), size-17 (two),
attacks-15 (eight unchanged successful rows), Espathra-22, Koraidon-23 and
Klawf-24. Its linked `recovery-appearance-25` contains the 14 re-exported
normal/shiny pairs; Espathra uses shiny-18, Klawf uses both retry-24 variants.
The earlier draft appearance-20 was never submitted for approval. All 20
selected battle candidates now have no reported technical issues. Visual
review of this selection remains pending. Other source/shiny holds and
recovered-group qualification still remain within the 200-model task.

The user accepted recovery-battle-review-25 and its linked recovery-appearance-25
(“Zien er goed uit”). Both feedback files bind the exact receipt, twenty normal
battle corrections and fourteen displayed normal/shiny pairs. These visual
reviews are no longer pending. This does not publish bundles or qualify any
unshown remaining models.

## Remaining qualification after review-25 acceptance

Dolphin recovery-26 re-imported Finizen and Palafin with official eyelid
restoration and source UV motion, preserving their existing dynamic visibility
and transparency options. Both normal/shiny exports and runtime motion renders
succeeded. Eye-appearance-29 presents these two pairs plus the five successful
eyes-19 pairs (Pineco, Magearna, Drednaw, Numel, Buizel). User review pending.

Clean-battle-review-30 presents the 107 original-sweep models without technical
findings and without any already-accepted battle corrections. Its receipt pins
scenes, placements and all sixteen camera/side/pose captures per model. It
checks full-report completion, 120 Hz clearance, camera/HUD framing and idle
readability. This is pending visual battle review, not a repeat of the earlier
appearance review.

Recovery-27 has two sequential lanes, eight groups totalling 39 models: 37
previous recovered scenes without a matching battle pass, plus the newly
restored Finizen/Palafin. Scripts run_recovery_27_0.py and _1.py write independent
status files. Results must be checked before approval.

Six normal exports lacked completed runtime qualification: Azurill, Crocalor,
Fuecoco, Hatterene, Iron Bundle and Venomoth. Remaining-28 stopped immediately
at Azurill's unresolved runtime visibility target; nothing was approved.
Remaining-31 now isolates each of the six so that a failed binding cannot block
other conversions; its runtime statuses and separate logs retain each hold.
The 12 earlier normal/source holds also remain open. No publishing, commits or
local integration have occurred yet for this ongoing task.

The user accepted clean-battle-review-30 (107 normal battle models) and
eye-appearance-29 (seven normal/shiny pairs), answering “Zien er goed uit”.
Each feedback file binds the displayed receipt. These visual reviews are no
longer pending; other recovery checks and source/shiny holds remain open.

## Follow-up corrections after review-30/29 acceptance

Recovery-27 first ten completed: Carkol attack-2, Coalossal attack-1, Cresselia
sleep and Finizen sleep require clearance correction. Attacks-32 re-exports
Carkol and Coalossal with the native hierarchy flattened, preserving their
existing dynamic visibility opt-in. Sleep-33 changes only the two sleeping
clearance profiles and runs fresh battle verification.

Azurill's runtime failure was a name-validation mismatch: source *_shape_lodN
becomes imported *_lodN. Visibility packing now accepts this exact alternate
spelling only with the explicit source_lod_diagnostic flag, an existing base
mesh and a single permanently-hidden key. Normal target validation is unchanged.
The focused Godot visibility test passed, including missing opt-in, wrong source,
missing base, visible LOD and no-partial-mutation cases. Azurill-34 normal/shiny
runtime conversion and motion renders passed; battle qualification is queued
with attacks-32 in run_recovery_35_battle.py, after sleep-33 completes.

Carkol-39 passed fresh battle verification after a local 240 Hz clearance
envelope for attack-2; the maximum added height is 0.0834846. Coalossal from
attacks-32 is technically clear. Sleep-33 (Cresselia, Finizen) passed. Azurill-34
passed its fresh battle check. Visual review of these corrections is pending.

Recovery-27 next findings: Palafin/Rotom sleep, Rolycoly damage, Polteageist special
attack. Sleep-42 is checking their sleeping clearance; attacks-41 re-exports the
two attack cases with flattened hierarchy. The first attacks-41 driver used an
absent Polteageist retry-1 job and exited; Rolycoly's finished export was retained.
Polteageist retry-43 uses its actual retry-3 job. join_normal_41.py records both
outputs, then existing shiny/runtime workers continue. No old source or evidence
was overwritten.

Falinks shiny-36/37 exposed an omitted secondary EyeClearCoat normal-map channel.
The pinned importer does not bind NormalMap1. Shiny-38 explicitly records its
unused rare difference, validating official owners and hashes and rejecting any
unexpected embedded binding; it does not claim source normal-map parity. Export,
geometry/motion parity, SCN conversion and pose renders passed. Visual review is
pending. The normal scene remains the already-reviewed one.

A binding audit of 182 successful shiny candidates found one represented shared
texture conflict: Veluza body_b_00 must retain the normal texture while other
owners use the rare texture. Global replacement previously changed both. The
default preparation now rejects such conflicts. An explicit material-scoped
review mode validates all official owners and direct imported image bindings
before assigning only the named materials. Veluza shiny-40 passed export and
geometry/motion parity and rendered. Embedded colour-image comparison proves
only body_b_00 changed and now matches the normal source; every other material's
colour image is unchanged. Artifacts: shared-texture-binding-audit.json and
veluza-material-binding-check.json. Eleven focused shiny tests pass, including
shared-owner rejection and explicit material binding. Visual review pending.

## Recovery battle review-44

All 39 recovery-27 battle passes finished. After superseding the historical
findings with sleep-33/42, attacks-32/41 and Carkol-39, four remain open: Rolycoly
damage (minimum -0.00117), Toedscool faint-start, Urshifu physical attacks and
Veluza attack-2. Attacks-45 uses each exact current source job for Urshifu,
Veluza and Toedscool with flattened hierarchy, followed by shiny/runtime/battle
workers. Veluza retains explicit material-scoped rare binding. Rolycoly-46 uses
a dense 240 Hz measurement for a local damage correction; its battle check is
queued. These are not approved by the next gallery.

Recovery-battle-review-44 includes 35 cleared recovery-27 species, plus Azurill
and Typhlosion (37 total). It selects only verified scene/placement pairs and
presents four battle poses in both camera presets/sides, with additional links
for the corrected Carkol, Coalossal and Polteageist attacks.

Recovery-appearance-44 contains ten normal/shiny pairs: Azurill, Carkol,
Coalossal, Rolycoly, Polteageist, Hatterene, Crocalor, Fuecoco, Venomoth and
Falinks. Its scene-bound appearance review is separate from battle clearance.
Rolycoly's placement and the remaining-31 battle passes are still pending;
Falinks secondary eye normal maps remain an explicit importer limitation.
Both galleries are pending user review. Remaining-31 battle verification is
now running after recovery-27 lane zero finished. No commit, integration,
publishing or upload has occurred.

The user accepted recovery-battle-review-44 (37 normal battle scenes and
linked corrected attacks) and recovery-appearance-44 (ten normal/shiny pairs),
answering “Zien er goed uit”. Both feedback files bind the displayed receipts.
This does not approve unshown battle corrections or publish any bundles.


## Recovery review-52/53

The user accepted recovery-appearance-53: Urshifu, Toedscool and Veluza normal
and shiny, eight poses with three sampled moments. The exact receipt is pinned
in user-feedback.json. Veluza uses the material-scoped rare binding from retry45.

Rolycoly-46, Urshifu/Toedscool-45 and Veluza-49 passed corrected battle checks.
Remaining-31 Hatterene, Crocalor, Fuecoco and Venomoth also passed. Iron Bundle
initially crossed the floor in special_attack; iron-bundle-51 applies a native
240 Hz envelope to that clip only, preserving endpoint offsets. Maximum added
height is 0.1402733; the fresh full battle check passes. Its shiny remains held.

Recovery-battle-review-52 presents those nine normal scenes, eight sampled poses,
both camera presets and sides. Receipts pin runtime, GLB, placements, measurements
and images. It is pending user review. Previously approved battle scenes total
179; acceptance of these nine would bring normal battle acceptance to 188.

Charcadet retry50 restored source-default UV evidence and dynamic visibility.
Normal/shiny export, runtime rendering and battle checks passed. Its flame
appearance remains unapproved: an initial visual inspection questioned the
blue/pink tip; the native body_04 source DOES contain an HDR blue layer alongside
HDR red/orange layers, so colour alone is not proof of an incorrect reconstruction.
Compare the source material and baked colour before changing it. Unshown
recovery-appearance-52 includes Charcadet; it is NOT approved. Review-53 excludes
it. There are now 189 technically exported normal models, with Charcadet still
visually held and 11 other original source holds. No release admission, upload,
commit or integration has occurred in this continuation.


The user accepted recovery-battle-review-52 with “zien er goed uit”. Its nine
normal battle scenes are pinned in user-feedback.json, bringing accepted normal
battle candidates for this 200-model cohort to 188. This is not approval of their
remaining held shiny variants or release admission.

Charcadet appearance/battle-54 now present the exact retry50 scenes for review,
eight sampled poses, with source-default effect evidence retained. Native
body_04 BaseColorLayer3 is [0, 0.26, 4, 1]; blue is explicitly source-authored.
The earlier visual concern is not established as a colour bug. Both galleries
remain pending user review. Barraskewda's shiny source was also re-inspected:
it adds white PointLight0_Color with intensity 1 (not zero), so the existing
zero-light exception must not be used to admit it. No material guard was relaxed.


## Combined remaining recovery (user requested one complete round)

The user requested all outstanding cases together; do not request separate
Charcadet approval. Eleven normal source holds now export: grimer, muk, sableye,
torkoal, eternatus, basculegion, armarouge, ceruledge, rabsca, greavard, miraidon.
Exact successful selection: retry56 except grimer/armarouge/ceruledge retry57
and eternatus retry58. Remaining-60-0/1 and remaining-61-2/3 contain SCNs and
24 motion captures each, with zero pose/timing errors. Battle pass is active.

New review-only lit displacement preserves baked albedo, normal, roughness,
metallic and emission instead of replacing Standard surfaces with unlit colour.
For mixed-UV meshes, explicit diagnostic fallback duplicates the sole available
UV onto the missing displacement UV only; affected mesh names are recorded.
Native loop endpoint resets are explicit sampled-loop diagnostics. Greavard's
animated displacement UV has zero displacement height and no animated colour UV,
so its static colour/effect output is invariant. Rabsca's two bounded Fresnel
endpoints are retained as authored even when descending; the existing average
alpha approximation remains labelled. None of these is original-shader parity.

Visibility review now supports explicit selected-source-mesh membership: every
selected native mesh must exist in the export; absent animation targets are
recorded separately with sibling ownership evidence. Eternatus' entirely
untracked body_c_03_mesh has an explicitly authored visible default (not claimed
as a decoded native visibility key).

Shiny retry59 restores sixteen candidates, superseded by retry62 for Magikarp.
All sixteen passed exact GLB geometry/motion parity and SCN conversion; zero
holds in remaining-shiny-63. Native rare import is an explicit separate route,
requiring rare table hash in identity/import evidence and byte equality with
ROMFS; normal texture substitutions cannot be mixed into it. Magikarp uses its
actual rare Standard/metallic material without introducing a new eye-UV mode.
Native point-light and parallax fidelity remain importer limitations, not parity.

A full recursive coverage audit found one additional historical shiny hold:
Wo-Chien. Normal exports cover all 200; successful shiny exports currently cover
199. Retry64 reproduces its missing lower-eyelid binding; native rare retry65
is running. Include it in the combined gallery, which should cover 18 species
including Charcadet. Do not mark all pairs ready before this and visual/battle
review finish. No release/upload, commit or integration in this continuation.

Focused checks: 53 identity/visibility/effect-completion Python checks passed;
Godot batch_material_effect_check passed including lit material save/reload,
metallic/roughness/emission preservation, and no external scene dependencies.


Wo-Chien native rare retry65 passed export and exact geometry/motion parity;
remaining-shiny-66 converted and rendered without holds. Full recursive export
coverage is now 200 normal and 200 shiny species. This is export coverage, not
release qualification. Combined appearance-68 contains 18 pairs (11 recovered
source cases, six historical shiny holds, Charcadet). The previous Charcadet-only
question is superseded by this combined review.

Normal battle checks cleared Grimer, Muk, Sableye, Torkoal, Armarouge, Ceruledge,
Greavard and Miraidon. Rabsca sleep-70 passed after a constant grounded sleep
correction. Basculegion sleep and Eternatus readability are in placement-71.
Placement-69 was abandoned after the reviewer correctly rejected a scaled lift
that differed from its independently recomputed baseline; no approval attaches
to its partial outputs. Placement-71 rebakes the scaled measurements instead.
Tests now total 66 focused Python checks plus the lit-effect Godot check.
All review material and code remain local and deliberately uncommitted pending
completion of this combined review. No integration, upload or publication.


Placement-71 completed: Eternatus readability and all tested camera/HUD/floor
checks passed; Basculegion sleep passed. Sleep-70 Rabsca also passed. Combined
remaining-review-68 is ready with 18 appearance pairs and 12 normal battle scenes,
each with eight sampled poses; battle shows both cameras and sides (32 images
per species). Its receipt pins both subordinate gallery receipts. This is the
single pending user review for the entire remaining cohort. All eleven recovered
normal models have completed Godot pose/timing and battle checks; all seventeen
previously held shiny models have completed exact geometry/motion parity and
Godot pose rendering. Charcadet joins the same pending review. The combined
report excludes the superseded failing measurements. Whitespace check passes.


The combined-68 browser page was opened but no user review question was sent.
Own inspection found Eternatus still visually undersized despite passing the
60-pixel bound threshold. It is superseded for battle by eternatus-72, targeting
140 pixels in the far idle view and rebaking placement from measured source
geometry. Combined-73 will retain the same 18 appearance pairs and 12 battle
species, replacing only Eternatus' placement/captures. Do not transfer a reply
to an earlier Charcadet question or assume combined-68 has been accepted.


Eternatus-72 passed floor, camera, HUD and readability checks. Actual idle bounds
are 134–229 pixels across the four views. Combined remaining-review-73 is now
ready and opened, pending ONE user response covering its 18 normal/shiny pairs
and 12 normal battle scenes. All current selected technical checks are clear.
The user still needs to judge visual quality, including lit-displacement UV
approximations, source-alpha shells and native-importer material limitations.
No commit/integration or release admission has been performed.

## Remaining-review-73 correction request

The user reported future Paradox eyes and dark shiny Iron Bundle, then odd Muk
and Grimer surfaces. `remaining-review-73/user-feedback.json` records these as
changes requested, **not acceptance**. The previous "all selected checks clear"
statement did not constitute visual acceptance.

- `normal-retry-74`: rebuilt Grimer, Muk, Iron Bundle, Iron Thorns, Iron Valiant.
  The three Paradox normals now opt into source emission/animated eyes, like the
  already accepted earlier Paradox cases. No invented eye colors or geometry.
- Grimer/Muk had clear cracks at independently displaced mesh boundaries.
  Their explicit `stable_surface_review_materials=["body"]` retains the skeletal
  animations and lit surface, but omits auxiliary vertex ripples. The effect
  receipt retains the original source displacement height and labels this
  authored approximation. Original source files remain untouched.
- `shiny-retry-74`: re-exported Grimer/Muk with the same surface treatment; the
  three existing native-rare Paradox GLBs are reused with newly verified exact
  geometry/motion parity to the new normal GLBs.
- `recovery-groups/corrections-74`: five normal/shiny SCNs and 24 captures each.
  All ten scenes converted; no shiny holds or motion-review errors.
- Neutral studio reflections are an explicit review-renderer option, recorded
  in each report. The old flat dark environment made highly metallic shiny
  Iron Bundle look black. This lighting change does not repaint the shiny or
  change any production arena. Production battle lighting is checked separately.
- `normal-eyes-75` and `shiny-eyes-75` use a lower camera for the three Paradox
  pairs. Iron Thorns has naturally narrow eyes partly occluded by its brow.
- `remaining-appearance-76` has the updated 18 pairs; `eyes-detail-76` provides
  enlarged lower-camera views. Original galleries/captures are retained.
- Fresh battle measurements and pose captures for all five are running. The
  combined pending battle review becomes 15 models (the previous 12 plus the
  three materially changed Paradox normals). Their older visual acceptances do
  not approve these new scenes. Thus 185 normal battle cases retain acceptance,
  with 15 pending current-scene review.

Focused checks: four Python tests (material profiles, LED evidence, source UV
defaults); actual Grimer/Muk source tests confirm original heights without the
flag, explicit zero-height review with original-height provenance, and rejection
of unknown material names. `git diff --check` passed. This task remains deliberately
uncommitted pending final visual qualification; no integration/publication yet.

### Current review-76 ready

All five corrected scenes now pass floor/camera/HUD/readability checks. Initial
recalibration of Iron Bundle in corrections-74 reintroduced the previously
fixed special-attack clearance defect. This was a placement-profile regression,
not a geometry change. `iron-bundle-77` proves exact GLB geometry/motion parity
with its previously accepted source, carries the unchanged approved
iron-bundle-51 placement profile onto the new material GLB, and freshly passes
120 Hz clearance plus camera/HUD checks. Its new eight-pose captures supersede
corrections-74's Iron Bundle battle evidence. The failed measurement is retained.

`remaining-review-76` pins the updated 18 appearance pairs, 15 current battle
scenes and three enlarged Paradox eye pairs. Its receipt remains **pending**.
No acceptance, bundle admission, commit, merge, upload or release is claimed.

## Armarouge / Ceruledge color query (78)

The user questioned shiny colors, including body/flames. review-76 feedback is
recorded as changes requested, not blanket acceptance. Compared normal/rare
source tables, the rendered normal/shiny pairs, and the actual exported eye
emission images. Primary body palettes remain shared: Armarouge red/yellow,
Ceruledge blue/purple. The rare tables change eye iris layers to blue and red
respectively, plus a few emissive/effect layers. Exported shiny eye images carry
those colors. No swapped body albedo or incorrect rare-table binding was found
in this check. Color intensity/native shader approximation remains a visual
review consideration; source-table provenance alone is not visual approval.

`color-investigation-78/source-differences.json` retains the table comparison.
`color-review-78` enlarges the existing two pairs without changing their scene
hashes or repainting their palettes, and pins the audit hash. No new model
export, automatic approval, commit or integration was made for this query.

### Color review 78 accepted

The user answered “Lijkt nu goed te zijn” after the enlarged Armarouge/Ceruledge
comparison. Their normal/shiny color appearance, including the body/flame concern,
is accepted against the unchanged scene hashes in color-review-78. The feedback
and review-76 color-findings resolution are recorded. This does not imply
acceptance of the other models or the separate 15-model battle gallery. The
combined final review remains pending; no commit/integration/publication.
