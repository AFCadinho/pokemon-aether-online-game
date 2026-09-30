# Remaining animation recovery (2026-09-30)

This is a diagnostic recovery checkpoint, not catalogue admission or release.
The reviewed catalogue remains 710 base species plus Mega Dragonite; 315 of
1025 base species remain unapproved. Alternative forms are outside this count.

## Re-probe results

170 previous `missing_or_ambiguous_native_actions` holds were re-probed against
the connected Biochao archives using the current action parser:

- 41 complete native action sets exported and converted into standalone scenes.
- 114 still have missing native actions.
- 15 still have competing action sets.

The selector first narrows to the proven source rig, then prefers battle idle
over default idle within the same rig and numeric bank. It never combines
competing banks. Resuming an export requires unchanged source, action mapping,
and exported bytes.

Of the 129 remaining animation holds, file-presence screening found 50 with
coherent native motion candidates in the ZA archive. These are **not** yet
identity-validated or imported. The inspected SCVI motion folder did not offer
complete replacement sets for these 129.

## Appearance preparation

41 normal scenes and 23 shiny scenes are prepared for appearance review:

- 19 pairs reconstructed from matching SCVI normal/rare material tables.
- 4 pairs reconstructed from ZA material tables: Buneary, Lopunny, Mime Jr,
  Drampa.
- 18 normals reconstructed from their own Biochao shader graphs. Shiny sources
  remain unresolved for these 18. This includes Roselia: its ZA reconstruction
  was withheld after an incorrect forehead marking was found.

Native shader cloning preserves authored group instance inputs. Base colour
and alpha are baked from the connected Principled shader graph. Spurious mask
emission is removed only when its native emission output is proven zero by baking its connected graph; nonzero
emission cases remain held. A Principled/emission mix is supported only when
that emission bake is zero. Geometry and animation
accessors must remain identical. This does not infer shiny colours.

The review page requires captures matching the exact standalone scene hashes,
rejects rendering errors or incomplete poses, and marks missing shiny variants
and missing second physical attacks explicitly. Diagnostic captures do not
certify battle scale, grounding or eye state (including closed eyes at sleep).

## Reproduce

Run from the assigned frontend slot, with the external source drive mounted:

```sh
python3 tools/sprite_factory/catalog_animation_recovery.py \
  --frontend "$PWD" --backend ../backend \
  --archives /home/adinho/Documents/3d_models/Biochao \
  --output .tmp/remaining-animation-recovery-new --workers 2 --export
```

Material reconstruction and standalone conversion use the existing material
probe and runtime tools. `catalog_animation_native_colour.py` takes pinned
candidate/source hashes and a new output directory. Never overwrite the source
archives or reuse captures from a different scene hash.

Local checkpoint artifacts live under `.tmp/remaining-animation-recovery` in
slot-a. The portable receipt in `tools/sprite_factory/` records the exact source,
GLB and scene hashes. No reviewed catalogue, release index or R2 content was
changed. Next: appearance review, repair outstanding shiny materials, then
battle qualification and individual bundles for accepted pairs.

## Appearance feedback: Sandslash and Toucannon

Both normal/shiny pairs received appearance approval on 2026-09-30
("Ja die 2 zien er goed uit"). Battle qualification is still pending.
Sandslash's black pupil channel has a
maximum decoded mask value of 29/255. The diagnostic correction increases only
that authored black-pupil channel to full coverage (gain 255/29), preserving the
other eye layers, body materials, geometry and animations. This is a visual
calibration candidate, not a claim that the original game shader uses this gain.
Both normal and shiny use the same correction and retain exact geometry parity.

Toucannon's flattened material reconstruction did not preserve the connected
native colour graph. A later source-number audit confirmed that the original
SCVI tables were already bound to pm0809; the defect was not a wrong-number
binding. Native normals retain the approved appearance. Its shiny now uses the
same native shader graph with official rare BaseColorMap substitutions and
colour inputs. Overrides verify both material-table hashes, exact parameter
values, unique graph bindings, and the normal image pixels before substitution.
Nonzero native emission still remains held. Untranslated rare response fields
remain diagnostic limitations, not implicit approval.

Sandslash now also composites the authored achromatic pm0028 eye_msk clearcoat
highlight, which was missing from the first black-pupil correction. The helper
rejects coloured masks or full-white masks before touching a model. Normal and
shiny remain exact geometry/motion matches. All four corrected models have six
captured action poses without render errors. The portable receipt binds the
user approval to all four exact reviewed scene hashes. This does not approve
the other recovery candidates or activate either pair in the catalogue.

A provisional ZA import used pm0733 and own visual inspection identified it as
a different species. It was rejected before being shown on the review page.
No ZA model is used for this Toucannon pair. Source numbers must come from the
proven rig/developer mapping, never the National Pokédex number alone.

## Battle check for the two appearance-approved pairs

The initial 60 Hz measurements had matching normal/shiny bounds and idle
readability above 80 pixels in both camera presets. Sandslash passed the
independent corrected 120 Hz clearance measurement. Toucannon failed it:
linear interpolation of its compensating wing hierarchy (parent scale 0.001,
child scale about 1000) creates transient oversized wings between otherwise
valid sampled poses. Do not accept the original battle report for Toucannon.

`patch_reviewed_track_interpolation.gd` creates a new hash-bound scene with
nearest interpolation for explicitly selected wing-b hierarchy tracks only.
Both variants preserve every animation key and timestamp, clip duration and
loop mode, and all unrelated interpolation modes. Materials are untouched.
The changed scene hashes require their own battle review; original appearance
approval remains attached to the previously reviewed hashes. These are still
candidates, with no catalogue admission, bundles or publication claimed.

Both derived Toucannon variants now pass independent 120 Hz validation
(minimum clearance 0.01787 m), while Sandslash reaches 0.02494 m. All four
scenes have 16 in-view captures without HUD proxy overlap. Three production
presenter lifecycle rounds passed for both species and variants. The portable
`catalog_animation_recovery_pair_battle.json` records those scene hashes and
the explicit interpolation recipe. Human battle approval remains pending.

## Approved individual bundles

The user approved the final battle page ("akkoord"). Sandslash and Toucannon
now have two local individual bundles (58,248,533 bytes total), each with
normal and shiny. Transactional launcher installation, no-op update, restart
and three battle lifecycle rounds on installed scenes passed. Their four
exact scene hashes and shared per-species placement profiles were admitted
to both game and launcher registries. The earlier recovery inventory is a
historical snapshot; the total is now 712 approved base species plus Mega
Dragonite, leaving 313 base species. Of this 41-normal recovery cohort, 39
normals and 21 prepared shiny variants remain candidates.

Bundle evidence is in `catalog_animation_recovery_pair_bundle_qualification.json`.
Artifacts remain under `.tmp/remaining-animation-recovery/repaired-pair-battle/bundles`
in slot-a. These bundles have not been uploaded or released.

## Remaining 39 pairs — review checkpoint

All 39 now have standalone normal and shiny scenes. Twenty-one shiny variants
use the prepared source variants; eighteen use explicit, alpha-preserving
local HOME-reference palette recipes, not official rare material tables.
Normal/shiny GLB geometry and animations match. Exact standalone SCN mesh,
skin, bone and animation parity was also checked, excluding materials.

The user approved 38 pairs on `remaining-39-v2`, reporting duplicate poses
only for Chatot. Its native addition-base action scales both folded-wing
accessories to zero, but isolated action selection resets the unkeyed bones
to unit scale. A source-SHA/action-bound repair excludes these two meshes
only for the eight selected battle clips. Normal and shiny were rebuilt with
their reviewed materials; `chatot-wings-v1` awaits appearance approval.

Tangrowth and Lickilicky use flattened native bone hierarchies to retain
their source limb/tongue proportions. Those corrected pairs are included in
the user's 38-pair approval. Independent 120 Hz clearance checks pass for
all 39 final normal scenes. Mantyke required 0.03 m extra clearance in its
first physical attack after a half-frame dip was detected and rechecked.

All 78 final scenes have 16 actual camera captures each (1,248 total), within
view and clear of the HUD proxy. Shiny clearance reuses
the independent normal measurements only after exact SCN geometry/animation
parity; it is not presented as independent shiny sampling. Human battle
approval, production presenter qualification and individual bundle admission
remain pending. The approved total remains 712 base species plus Mega
Dragonite. No upload or release is part of this checkpoint.

Portable scene hashes and approval boundaries are recorded in
`tools/sprite_factory/catalog_animation_recovery_39_checkpoint.json`.
Working evidence is under `.tmp/remaining-animation-recovery/remaining-39`.

## Remaining 39 pairs — approved individual bundles

The user approved corrected Chatot ("ziet er goed uit.") and all 39 pairs on
the final battle page ("Allemaal goed"). All 78 exact scenes are now admitted
to identical game and launcher registries, with one shared reviewed placement
and animation profile per species. `catalog_animation_recovery_39_checkpoint.json`
records both approval boundaries, the pinned camera evidence and palette
provenance; its earlier 712-species count describes the pre-admission baseline.

There are 39 new individual bundles, 279,850,346 bytes total (266.89 MiB).
Transactional installation, no-op planning and restart checks passed for
all 78 scenes. Installed scenes passed three production presenter lifecycle
rounds in classic/stadium/classic cameras, 39 pairs and faint replacements per
round. The production registry resolves every installed scene to the reviewed
timing, placement, bounds and motion, and rejects an unapproved digest.

The approved total is now **751 base species plus Mega Dragonite**: 752
profiles and 1,504 normal/shiny records, leaving 274 of the 1,025 base species.
Bundle qualification is recorded in
`tools/sprite_factory/catalog_animation_recovery_39_bundle_qualification.json`.
Archives are under
`.tmp/remaining-animation-recovery/remaining-39/final-battle/bundles` in slot-a.
These bundles have not been uploaded to R2 or included in a release.

## R2 publication of the 39-pair cohort

The user authorized upload of these 39 bundles. All archives and their own
immutable index have now passed public GET SHA-256 and HEAD size verification.
`release/approved_3d_recovery_39_r2_upload.json` records the public object keys
and binds publication to the exact bundle qualification and reviewed catalog.
`release/approved_3d_recovery_39_index.json` contains these 39 species only.
The active public launcher/game manifest was checked before and after upload
and is unchanged. Desktop activation remains a separate release step.
