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
<http://127.0.0.1:8786/>. Images are rendered at 1024 pixels with camera fitting
based on projected per-pose bounds, instead of the full 3D AABB diagonal.
This affects the review camera only. Ogerpon starts in its maskless comparison
view; other poses and its masked view remain selectable. All 12 diagnostic
variants (the five pairs plus two maskless views) passed the same pose/timing
checks, and all 86 page/manifest/image requests returned HTTP 200.
