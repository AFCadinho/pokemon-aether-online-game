# Repaired models and attack origins

Task `pokemon-repaired-model-attachments`, 2026-10-11. Detailed evidence:
[review report](repaired-model-attack-points.json).

| Form | Reviewed origin and routing |
| --- | --- |
| Cramorant | Beak midpoint for mouth effects and Fury Attack; separate outer bird wings for hand contacts. Hidden Pikachu anatomy is excluded. |
| Deoxys | Visible paired tentacle tips and pointed feet; mouthless beams/projectiles originate at the projected chest jewel. |
| Minior | Meteor-body center for beams and body effects. Hidden core-face overlays and detached fragments supply no attack points. |
| Togedemaru | Native mouth, palm and foot sockets; body center fitted inside the sphere. Hyper Beam uses its forward-facing physical clip, Volt Switch its electric body. |
| Mega Hawlucha | Correct `pm0761_51_00` anatomy: beak, palms/leading wing edges, toes and chest. Hyper Beam ends before the native special-attack flip. |

Normal and shiny share each form's attachment profile. There are 23 configured
parts, including 20 new bindings, resolving the 29 previously missing routes.
Marker poses were inspected per form. Sixteen representative moves were viewed
in both appearances and from two views. The runtime check samples all configured
points at 21 times per native action: ten appearances, 3,150 points, zero errors.
Five trainer/wild comparisons have identical capture metadata except battle kind
and byte-identical rendered sheets.

Review covers sampled origins and native animation routing. Existing oversized
beam/impact decorations, exact target-contact spacing and continuous clearance
through every animation frame are not certified. Minior remains the meteor form;
this does not reconstruct form transitions. Mega Hawlucha still uses its own
faint-loop for sleep because the source has no distinct sleep clip.

## Mega Hawlucha delivery

The new pair passed transactional launcher installation, normal/shiny switching,
on-demand battle loading, native timing/120 Hz clearance and three real HUD
battle rounds (classic, stadium, classic). Both appearances use one placement
profile. Rebuilt texture-sharing and geometry-sharing packs passed physical
payload, skeleton, material and animation equivalence checks in fresh processes.

- ZIP version 3 replaces the incorrect version 2 pair in the immutable v12 index.
- Shared texture version 4 and shared geometry version 5 replace that pair in
  the existing opt-in collections. Their default remains disabled.
- Four historical wrong-source scene hashes remain recognizable for historical
  archive validation, but runtime resolution rejects them. They cannot inherit
  the corrected bird's placement or attachment points.
- The other 1,199 ordinary bundle descriptors are unchanged.
- The [publication receipt](../../release/approved_3d_bundles_v12_r2_receipt.json)
  verifies public GET hashes and HEAD sizes for the new files. Existing bundle
  publication proofs are inherited from the pinned v11 receipt. All live update
  manifests remained unchanged; no client build was activated or deployed.
- Updated clients prefer the published v12 index even with a v11 launcher pin,
  so an already installed wrong-source pair is replaced when automatic model
  downloads are enabled. Manually selected catalogs must use the repaired
  revision. The proof is
  preloaded as a resource so exported clients include it.

Shared-collection audit and Linux readiness records remain frozen at their
tested commits. `release/hawlucha_source_repair_shared_binding.json` reconciles
the current catalogs against that baseline: exactly one descriptor changes,
with separate source qualification and publication proof. Metadata checks reject
any unrecorded changes before examining historical cohort evidence. This does
not claim a new full-cohort/platform certification.

Reproduction tools are `tools/admit_hawlucha_source_repair.py` and
`tools/publish_hawlucha_source_repair.py`. Both validate by default; `--apply`
is explicit. Retained source and review work is under `.tmp/source-model-repairs`
and `.tmp/repaired-model-attachments` in slot-c. Read credentials in place only.

## Focused checks and remaining catalog work

Passed: launcher pair installation; battle pair/swap test; three-round HUD stress;
native attachment binding; repaired-source inspection; `move_attachments_3d_check`;
`hawlucha_source_repair_check`; shared texture and geometry catalog binding;
historical v11 metadata validation; shared catalog/geometry metadata reconciliation;
eight publication guard tests; twelve source-mapping tests; full learnset routing audit.

The current 1,200-form audit has 30,646 supported routes and 8,333 configured
bone-bound routes. New learnset entries outside the original 295-form cohort
introduced two outstanding cases: Hisuian Avalugg/Rock Smash and Alolan
Raichu/Double Kick. They are recorded in the regenerated
[backlog](attack-attachment-family-backlog.json); none of the five repaired forms
has a missing anatomical route.
