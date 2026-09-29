# Remaining base-species source recovery (2026-09-29)

This is source discovery and normal-scene diagnosis, not visual, shiny, battle,
runtime or release approval. The historical `catalog_remaining_bulk_status.json`
remains a snapshot of its original intake; do not rewrite its evidence hashes.

## Six form-only Biochao sources

The original intake recognized only `pm####.blend` or `pm####_00.blend`.
`catalog_remaining_intake.py` now selects the following explicit archive members
after checking their developer-number table where one exists:

| National Dex | Species | ZIP | Exact member | Normal diagnostic |
| --- | --- | --- | --- | --- |
| 201 | Unown A | Gen2.zip | `pm0201_11.blend` | SCN converted; body colour review candidate |
| 555 | Darmanitan (standard) | Gen5.zip | `pm0555_11_12.blend` | SCN converted |
| 746 | Wishiwashi (solo) | Gen7.zip | `pm0820_11.blend` | SCN converted; field wait used for sleep review |
| 773 | Silvally (Normal type) | Gen7.zip | `pm0862_11.blend` | SCN converted |
| 862 | Obstagoon | Gen8.zip | `pm0928_00_31.blend` | SCN converted |
| 864 | Cursola | Gen8.zip | `pm0947_00_31.blend` | SCN converted; white material needs visual review |

The form-only source inventory changes the count from 300 located / 21 missing
to 306 located / 15 missing. This changes source discovery only. Unown uses
Legends: Arceus-style action names; the action matcher now recognizes its idle,
special attack and damage clips. Wishiwashi's source has no sleep clip or
eyelid rig; its exact archived source is pinned to a field-wait review pose.
Normal Godot conversion and quick pose capture found no structural errors for
the six scenes. Unown's generic shader bake produces a flat red body; a
source-hash-pinned opaque charcoal material candidate corrects that export
artifact without editing the archived blend. None of these six has a qualified
shiny scene. Keep them outside the approved catalog until normal/shiny visual
review, grounding and battle qualification finish.

Face follow-up: the first six normal renders were rejected for eye/face
appearance. Unown A's glTF export had selected the packed `eye_msk` as its
visible albedo, producing a giant black eye. The source-hash-pinned Unown
conversion now bakes the original Blender eye material's Base Color and binds
that texture in the GLB. Its new Godot idle render has a light eye and pupil.
This remains a visual-review candidate, not a shiny or battle approval.
The other five also have source-faithful **normal review candidates**. Their
Blender eye shader uses a mirrorTexture node group and out-of-range UVs that
the glTF exporter does not preserve. `catalog_remaining_eye_domain.py` pins
each source SHA-256, bakes the original Base Color over the source eye UV
domain, and remaps only the named eye primitives to that bake. Darmanitan,
Wishiwashi, Silvally, Obstagoon, and Cursola all converted to Godot SCNs and
rendered their native review poses without pose/timing errors. This fixes the
flat atlas colours in the diagnostic renders; their faces still need human
visual review. Wishiwashi's sleep fallback keeps its eyes open, because the
source has no native sleep clip or eyelid rig. Cursola's coral is still much
brighter in Godot than in the Blender source, so its body material needs a
separate decision. The Godot review renderer accepts an optional
`POKEAETHER_CATALOG_REVIEW_CAMERA_DIRECTION=x,y,z` for viewing such cases
from other angles.

The six normal poses can now be reviewed together with
`catalog_remaining_six_review.py`; it uses the corrected Unown render and the
Wishiwashi field-wait render. The page is a diagnostic and does not grant
approval. Cursola's mostly white coral and transparency still need a focused
visual decision.

Body-detail follow-up: a fresh source audit found that Wishiwashi, Silvally,
Obstagoon and Cursola mix their albedo with a `Colors` vertex attribute at
factor 0.5. Their archived meshes contain `Color` and `Color2`, but no
`Colors`; Blender therefore renders the albedo at half linear brightness.
The glTF exporter drops the mix and leaves the unscaled texture, washing out
body detail in Godot. `catalog_remaining_body_detail.py` restores the exact
0.5 material factor for those four source-hash-pinned models. Unown's earlier
flat charcoal diagnostic is replaced by a bake of its authored blue body
shader, retaining the source normal map. Darmanitan has a separate 0.7
contrast-calibration candidate; its source does not use the missing `Colors`
mix. All six export fresh and convert to standalone Godot scenes. The body
review is still pending, and no normal/shiny pair is catalog approved.

An external [Pokémon 3D API asset repository](https://github.com/Pokemon-3D-api/assets)
contains shiny GLBs for Unown (201), Silvally (773), and Obstagoon (862).
Inspection of their GLB headers found **zero animation clips** in all three.
They may help compare colours, but cannot replace the native animated source
or qualify a shiny runtime scene. The same repository has no shiny GLB for
Darmanitan (555), Wishiwashi (746), or Cursola (864). Its asset map was empty
when checked, so original upstream provenance for these three GLBs was not
established; do not include their bytes in production bundles on this evidence.

## Fifteen newer Scarlet/Violet models

The supplied `Pokémon SCVI Base + DLC Model Dump` contains models, normal
materials and rare materials for these IDs. The mapping is supported by the
dump's own large icon image and the resource directory, but needs a current
resource catalog before it can pass the existing SCVI identity gate.

| Species | Model resource |
| --- | --- |
| Dipplin | `pm1121_00_00` |
| Poltchageist | `pm1133_11_00`, `pm1133_12_00` |
| Sinistcha | `pm1134_11_00`, `pm1134_12_00` |
| Okidogi | `pm1123_00_00` |
| Munkidori | `pm1124_00_00` |
| Fezandipiti | `pm1125_00_00` |
| Ogerpon | `pm1120_11_00` through `pm1120_14_00` |
| Archaludon | `pm1132_00_00` |
| Hydrapple | `pm1122_00_00` |
| Gouging Fire | `pm1126_00_00` |
| Raging Bolt | `pm1127_00_00` |
| Iron Boulder | `pm1129_00_00` |
| Iron Crown | `pm1128_00_00` |
| Terapagos | `pm1130_11_00` through `pm1130_13_00` |
| Pecharunt | `pm1131_00_00` |

The model dump and its parent RAR have no matching `*.tranm` clips or
`poke_resource_table.trpmcatalog`. The separate supplied `SV Every File`
archive is older: it has no motion roots for these IDs. These 15 are therefore
located model sources, but cannot yet use the native-animation production gate.
Get an updated matching Scarlet/Violet motion and catalog extraction before
creating runtime candidates. Do not relabel an older species's actions.

Walking Wake (`pm1084_00_00`) and Iron Leaves (`pm1091_00_00`) have genuine
newer model bytes and rare material in the model dump, but their older ROMFS
motions belong to Raichu-shaped placeholders. Their approved Sketchfab-based
bundles remain the working sources until compatible native motions are found.
