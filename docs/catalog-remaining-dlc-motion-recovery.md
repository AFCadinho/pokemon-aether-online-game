# Remaining 15 DLC: motion recovery

## Intake checkpoint — 2026-10-01

All 15 held DLC species now have an external animated source and an own-SCVI-rig
motion proposal. **None is catalog approved yet.** The approved count remains
1,010 ordinary species plus Mega Dragonite. No new bundles or uploads were made
in this intake step.

The mounted SCVI model archive contains no `.tranm`/`.tracm` motions. The ZA
archive contains no pm1120–pm1134 models. The extracted `SV Every File` collection
ends at normal resource pm1114 and predates these DLC species.

[Zyphex Skybreaker's Gen IX models](https://steamcommunity.com/sharedfiles/filedetails/?id=3428100851)
provides public Tabletop Simulator bundles with the missing clips. The creator
asks for credit and a link when models are reused. Preserve this attribution in
any eventual distributed content. This source is a converted source, not a claim
that we found the original DLC motion dump.

The download URLs, bundle SHA-256 hashes, 118 clip objects (116 distinct names),
15 converted source hashes and pending qualifications are pinned in
`tools/sprite_factory/catalog_remaining_dlc_motion_intake.json`.

## Conversion and identity

`unity_motion_intake.py` reads sparse, dense and constant transform curves,
resolves path hashes, preserves clip endpoints, and rejects changed downloads,
unresolved bindings and inconsistent scalar banks. Non-transform bindings are
reported; they are not silently claimed to have been converted. UnityPy 1.25.3
was used in an isolated local environment.

`unity_motion_review_worker.py` keys the existing SCVI rig by source bone name,
with the inspected FBX unit convention and X reflection. It skips Unity's
100x model container, preserves quaternion continuity and pins both inputs.
Source native materials and geometry are retained for subsequent reconstruction.

The previous intake had **Sinistcha and Poltchageist reversed**. Inspecting the
actual geometry and external source corrected this: pm1134 is Sinistcha's
bowl/whisk; pm1133 is Poltchageist's tea container. Dipplin (pm1121) and Hydrapple
(pm1122) remain correct. Earlier `.tmp` proposal folder names are historical;
use the corrected identities and the new receipt, not those folder labels.

## Checks and remaining work

- Five focused parser checks pass: sparse cubic evaluation, infinite baseline,
  dense/constant offsets, non-transform binding offsets and endpoint handling,
  changed download rejection and malformed-stream rejection.
- All 15 pinned real bundles decode, with finite transform samples and preserved
  source end times; all 15 convert successfully into their own source rigs.
- Representative idle/attack/faint Blender images were generated internally.
  These are **not normal/shiny or gameplay qualification**. A Poltchageist unit
  container error from the first diagnostic was corrected in the second pass.

No genuine sleep clip was found in these bundles. Still required: reconstruct
normal/shiny materials and eyes, explicit reviewed sleep poses, standalone Godot
pose/timing checks, battle scale/grounding and one collective user review. Only
then produce individual bundles. Generated sources, images and logs stay under
`.tmp/remaining-dlc-15-v1/` in the retained slot-a worktree.

## Normal/shiny material checkpoint

The source recovery commit `a7dc50b8d` was merged into local `development` after
the user's SS Anne checkout cleanup. The assigned slot is retained for the
remaining model work.

All **15 normal/shiny GLB proposals (30 variants)** were reconstructed from their
matched SCVI normal/rare tables. Each pair has exactly equal geometry, skins,
transforms and animation data. A preliminary Godot GLTF diagnostic sampled the
available clips and checked reverse-order pose isolation: **30 models, zero
pose/timing errors**. Sleep and standalone battle qualification are still absent.
Hashes, clocks, material limitations and the Godot report hash are pinned in
`tools/sprite_factory/catalog_remaining_dlc_material_checkpoint.json`.

Terapagos's old `body_a_02 -> body_a` alias referred to the wrong material name.
The native table has an actual `body_a_02` entry. Its source Blender texture is
`default_mega_flow`, so the proposal explicitly uses that entry's official
albedo while leaving animated flow behavior unqualified. No validator/default
translation was changed.

Internal contact-sheet inspection identified follow-up work: layered emission
and robot eye readability, Hydrapple's hidden-accessory/camera bounds, and
Terapagos flow/transparency. The 30 proposals are not visual approvals. Complete
these details and explicit sleep proposals before the one collective user
review; the approved catalog count and R2 content are unchanged.

## User-requested appearance review

At the user's request, all 15 normal/shiny pairs are presented together at
<http://127.0.0.1:8784/>. The page covers idle, rear view, special attack and
faint. Search, a shared pose selector and full-size paired images are provided.
It explicitly excludes sleep and battle-size approval.

A new diagnostic capture fits each pose individually, preventing Hydrapple's
other-pose bounds from making the idle appearance too small to inspect. This
changes only review framing. All 30 variants again report zero pose/timing
errors. The page and all 240 thumbnail/full-size images returned HTTP 200;
`xdg-open` dispatched the review URL successfully. The hash-bound review
manifest and page SHA-256 are recorded in the material checkpoint. User
appearance approval is still pending.

## Body detail and shiny correction follow-up

The user's detail review found real omissions. All 15 body graphs were baked
from their prepared native SCVI sources at 1024 pixels, with normal/rare table,
texture and source Blend hash guards. The separately reconstructed Eye diffuse
was retained. Original geometry, skinning, animation and response-map bindings
were checked against all 30 input GLBs. Their 15 variant pairs still have exact
geometry/motion parity.

The SCVI importer leaves its inside-parallax input black. Its graph bake alone
therefore still omits Iron Crown/Boulder's source-authored coloured panels.
`catalog_dlc_layer_emission.py` restores those panels and active Eye emission
from the official RGBA layer masks and normal/rare emission colours/intensities.
It also restores explicitly opaque source classifications. This is a static
mask proposal; native parallax animation, animated flow and view-dependent
Fresnel are **not** claimed recovered. Reproduction produced identical SHA-256
for all 30 outputs. Material/hash guards were retained; no tests were loosened.

Pecharunt's alternate closed-shell mesh overlapped its open body, obscuring
both detail and the gold shiny body. The recovered source has nine enabled mesh
renderers, excluding the closed shell. The proposal excludes only that mesh
binding in both variants. Restoring the binding in a disposable parity check
recovers the exact original geometry/skin/motion signature; no vertices or
animation curves were changed. Native visibility animation remains a future
qualification step.

Ogerpon's Teal Mask covers its orange/green-yellow face difference. An additional
maskless comparison view excludes the mask mesh only for review; the primary
Teal Mask profile and species counts are unchanged.

The updated appearance page is <http://127.0.0.1:8785/>. Its 246 page/manifest
and image requests returned HTTP 200. Godot sampled 30 primary variants plus
the two maskless views with **zero pose/timing errors**. The user's follow-up
approved appearance for **10 pairs**: Dipplin, Sinistcha, Poltchageist, Okidogi,
Munkidori, Fezandipiti, Archaludon, Hydrapple, Terapagos and Pecharunt. **Ogerpon,
Gouging Fire, Raging Bolt, Iron Boulder and Iron Crown remain explicitly pending
appearance review.** These are appearance approvals only; sleep, standalone
battle qualification and bundles remain open. The approved runtime catalog and
R2 content have not changed.

The five pending pairs have a separate focused page at
<http://127.0.0.1:8786/>. Images are rendered at 1024 pixels with per-pose bounds used for camera
fitting.
This affects the review camera only. Ogerpon starts in its maskless comparison
view; other poses and its masked view remain selectable. All 12 diagnostic
variants (the five pairs plus two maskless views) passed the same pose/timing
checks, and all 86 page/manifest/image requests returned HTTP 200.

The user subsequently approved Ogerpon, Gouging Fire, Raging Bolt and Iron
Crown: **14 appearance-approved pairs, only Iron Boulder pending**. Its ordinary
review camera looked down onto the head, making the face difficult to inspect.
A camera-only follow-up at <http://127.0.0.1:8786/iron-boulder-face/> provides
low front, oblique front and head-bone-centred close-up views at 1024 pixels.
The camera uses projected bounds; the GLB and original idle pose are unchanged.
Both variants passed pose/timing checks and all 14 page/manifest/image requests
returned HTTP 200. Final qualification and runtime approval remain pending.

## Appearance review completed

The user also approved Iron Boulder after inspecting its lower-camera face
comparison. All **15 normal/shiny pairs are now appearance-approved**. No
appearance review cases remain in this intake. This records the existing
reviewed asset hashes; no model, animation, material or review image changed.

Next: create and validate explicit sleep poses, complete standalone SCN
conversion and battle qualification (including grounding, scale, native
effect limitations and loading), then build individual bundles. These models
are not yet runtime-approved or uploaded to R2.


## Standalone rest and battle proposals

The 15 appearance-approved pairs now have explicit authored rest clips. These
are not recovered native sleep animations. The rest baseline samples each
model's own idle at time zero, retains only its own faint-endpoint eyelid
transforms, and adds 0.6% root breathing. Idle midpoint was rejected after
Hydrapple's accessory transforms visibly stretched the proposed rest pose.
Models without usable eyelids retain their source rest eyes. Iron Boulder and
Iron Crown use their official base Eye colour with Eye emission disabled during
rest; their other glowing panels remain intact.

A STEP interpolation endpoint error in the proposal sampler was fixed in code.
Focused regressions cover exact STEP key boundaries, a shared clip clock for
tracks of different durations, and antipodal quaternion interpolation. No
validation threshold was relaxed. Archaludon's recovered native damage action
had Blender's `.001` suffix and was omitted by an earlier exact-name selection;
that real source action is now appended with source, node and export hash guards.

`catalog_dlc_sleep_proposals.py` retains the original mesh/skin/node data, native
animation metadata and binary prefix. All 30 outputs reproduce byte-for-byte;
15 normal/shiny pairs have exact geometry/skin/motion parity. Their standalone
SCN scenes reload without external dependencies. The rest material pack also
checks Eye emission across idle → sleep → idle after serialization. All 30
standalone diagnostic scenes passed timing, finite posed geometry and reverse
pose-order checks with zero errors.

Current immutable evidence is under `.tmp/remaining-dlc-15-v1/`:
`flat-motion-v1`, `flat-approved-v1`, `sleep-flat-v4`, `runtime-flat-v2`,
`flat-rest-parity-v4.json`, `sleep-flat-captures-v1`, and `battle-flat-v4`. Earlier superseded proposals
remain available for diagnosis. `catalog_dlc_runtime_review.gd` captures the
standalone rest/pose proof; `catalog_dlc_battle_review_page.py` assembles one
normal/shiny page only after all battle floor/camera checks pass.

The static native emission-layer reconstruction remains a documented material
limitation: animated parallax, view-dependent Fresnel and Terapagos flow are not
claimed reconstructed. Final sleep and battle presentation require the user's
collective review. Runtime catalog admission, performance/loading qualification,
individual bundles and R2 upload follow that approval.


### Half-frame interpolation repair

Independent 120 Hz sampling rejected the hierarchical proposals: Munkidori's
faint and special attack, Ogerpon's physical attack, and Poltchageist's idle and
physical attack had intervening geometry excursions. The 60 Hz key-adjacent
samples alone missed some of these. No large root lift was accepted as a fix.

All 15 exact prepared sources were re-exported with Blender's existing native
`export_hierarchy_flatten_bones` option. `catalog_dlc_flat_motion.py` transfers
that representation into both reviewed variants, checking identical vertices,
UVs, indices, weights, named joint assignments and material assignments. Original
reviewed materials and texture bytes are retained exactly, including Pecharunt's
already-reviewed closed-shell exclusion. Skeleton hierarchy, inverse bind
matrices and sampled transform curves deliberately change; source action
selection and timing remain pinned. Archaludon's real suffixed damage action is
included in this export.

Authored sleep eyelids are transferred relative to their original non-eyelid
ancestor so a faint head position cannot displace eyes in the idle body. Breathing
is applied to the common flattened rig parent; the standalone complete-pose
adapter restores its default scale on other actions. Focused tests include that
relative eyelid transfer. The final 30 rest GLBs reproduce byte-for-byte and all
15 geometry/motion variant pairs match. The new battle baseline uses a 4 cm idle
clearance margin; other offsets remain clearance corrections and are independently
checked against the unchanged 2.5 cm floor requirement.


### Final collective review ready

The final flattened/rest scenes passed all 30 independent battle sweeps: **216
clips**, no floor failures at 120 Hz, **480** pose/camera/side captures with no
out-of-camera or HUD-proxy overlaps. Minimum measured clearance is
**0.03474596 m**, above the unchanged 0.025 m requirement. These are geometric
and presentation checks, not a frame-rate or full battle-UI certification.

The collective page is <http://127.0.0.1:8787/>. It combines 15 normal/shiny
pairs, enlarged idle/rest views, four battle poses and both camera/side presets.
Its manifest pins 1081 page/image files; all 1082 page/manifest/image requests
returned HTTP 200, and `xdg-open` dispatched the URL. The user has been asked for
one final sleep/battle verdict. `catalog_remaining_dlc_battle_checkpoint.json`
and `catalog_remaining_dlc_battle_candidates.json` record the exact held scene
hashes, placement/motion proposals and evidence hashes. Appearance approvals
remain intact; sleep/battle approval is pending, and no runtime registry,
individual bundle, R2 index or release has been changed by this step.


### User battle approval and three shiny follow-ups

The user approved the 15 sleep/battle pairs, but could not see the shiny
variation of Poltchageist, Ogerpon, and subsequently Sinistcha. A low-angle
front/rear enlargement reproduced the concern. Ogerpon's existing Teal Mask
covers the orange → yellow-green face difference; the diagnostic hides that
one exact mask instance without changing the runtime asset.

Poltchageist's static graph-shadow bake crushed source dark-green pot paint to
near-black. Sinistcha's green bowl was present but also darkened. The bounded
`catalog_dlc_pot_colour.py` proposal restores official albedo RGB only in UV
pixels whose source normal/rare pair changes dark paint to green. Original
alpha, all other baked detail, emission/response maps, geometry, skinning and
animation accessors are retained. Exact geometry/motion signatures match all
four previous GLBs; the 60/120 Hz floor/camera measurements are reused explicitly
on that proof, not rerun or weakened. All four revised SCN scenes passed the
strict standalone converter and reloading check, with unchanged clip timings.

The three enlarged pairs are at <http://127.0.0.1:8787/shiny-colours/>; all 22
page/manifest/image requests returned HTTP 200 and the URL was dispatched with
`xdg-open`. User confirmation of this narrow follow-up remains pending. The
battle checkpoint pins the four revised scenes and the unchanged placement
curves with their new GLB hashes. No runtime admission or bundles yet.


### Final visual approval and bundle preparation — 2026-10-01

The user approved the three final shiny follow-ups: “ja die zijn goed”.
This completes visual approval of all 15 normal/shiny pairs, including their
authored rest, camera scale and battle poses. The checkpoint binds the exact
final scenes and the narrow source-pot-paint correction proof.

`prepare_dlc_15_admission.py` carries the measured grounding and motion curves
into SCN-hash-bound runtime profiles. Fully airborne clips receive explicit
zero-correction curves from their measured native clocks. The actual placement
and motion validators accept all 30 candidates. No geometry, pose, texture or
timing changes are made during admission preparation.

Fifteen individual v1 bundles total 350,523,768 bytes (334.29 MiB). Transactional
launcher installation loads all 30 scenes; no-op planning and restart pass.
Runtime admission and R2 upload are gated on the existing rendered battle
performance assertions. An initial pass with a second Godot editor running
failed frame/stall limits and is retained as `installed-stress-with-editor.*`;
it is not qualification evidence. The editor was then closed for a repeat.


### Installed runtime qualification completed

With the editor closed, the unchanged three-pass assertions passed for all 15
pairs and 45 faint replacements. p95 frame times were 12.729 / 19.367 / 12.301 ms
(classic / stadium / classic), below the existing 20 ms limit. No uncovered
stall exceeded 100 ms. Retained model source data was 14,334,491 bytes; static
memory grew 122,240 bytes between the second and third rounds, below 1 MiB.
The check uses local AMD Compatibility rendering, without cross-platform or
release certification. Existing asset UID warnings fall back to valid paths.

`admit_dlc_15.py` admits only exact installed scene hashes after approval,
transactional installation and performance proofs. Both game and launcher
registries now match: **1,025 ordinary species plus Mega Dragonite**, totalling
1,026 profiles and 2,052 normal/shiny records. A separate registry check resolves
all 30 installed scenes to the approved timing, placement and motion profiles,
and rejects incorrect hashes. The historical standalone checkpoint remains a
pre-admission snapshot; `catalog_remaining_dlc_bundle_qualification.json` is
the final runtime authority. All 15 are finished locally; no further human
review is pending for these exact scenes.

The recovered motion attribution remains Zyphex Skybreaker’s Gen IX models
(Workshop item 3428100851). Rest is authored rather than claimed native sleep;
static emission/flow approximations retain the reviewed limitations above.


### R2 publication completed

All 15 bundles and their immutable content index are now published on R2.
`release/approved_3d_dlc_15_r2_upload.json` records public GET SHA-256 and HEAD
size verification for all 16 objects, bound to the qualified runtime catalog.
The existing desktop manifest remained unchanged; this publication does not
activate a new game/launcher release. Final intake/material metadata points to
the runtime qualification and public upload receipt. The original evidence
checkpoints and local pre-publication receipt retain their historical scope.

No DLC model remains pending visual review or local qualification in this task.
Further alternate forms and Mega evolutions are separate catalog work.
