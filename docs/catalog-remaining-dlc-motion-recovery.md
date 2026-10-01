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
