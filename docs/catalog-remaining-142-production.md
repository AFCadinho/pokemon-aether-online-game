# Remaining 142 — source and normal-candidate recovery

The 1 October intake matches the active registry: 883 ordinary species plus
Mega Dragonite are ready and 142 ordinary species remain. The mounted external
source drive is available. 127 remaining species have pinned Biochao archive
members; 15 DLC model identities still have no native motion directory in the
currently mounted SV Every File dump or matching paths in the ZA archive.
The initial status split was 10 material holds, 117 source/action holds and 15
DLC motion holds. No conclusion is drawn about other external sources.

## First recovery checkpoint

12 normal candidates exported and converted to standalone SCNs; pose captures
have no technical errors. Geometry/skin/animation accessors remain identical
through material edits. 8 received user appearance approval (“Alle acht goed”): Arctovish, Lillipup,
Mr. Rime, Palpitoad, Seismitoad, Poipole, Noctowl and Trumbeak.

[Local appearance review](http://127.0.0.1:8782/appearance-8-v1/index.html)

Noctowl and Trumbeak use their own pinned bank 2 battle clips plus their unique
authored sleep clip from the same source rig. Both retain the second native
physical attack and faint loop. This explicit mapping does not relax the
generic conservative animation selector. Lillipup's former shader-copy hold
was resolved by the previously fixed ordered socket-name/type check.

Explicit review-only native material baking now supports constant base colours,
separate authored emission with preserved HDR peak strength, white transparent
shader branches, and source-derived raw UV domains. It replaces the old
texture-only transform with a full shader bake; it does not apply that transform
a second time. Implicit image coordinates explicitly read SourceUV when
baking into a separate destination UV layer. Alpha blending follows evaluated
native alpha. Standard calls still reject active emission; a real default
regression reproduced Trumbeak's previous GLB bytes and held Noctowl for
emission. 4 existing UV-domain tests and Python compilation passed.

## Remaining visual attention in these 12

- Paras: source glass eye cover is opaque under Compatibility. The review
  candidate uses thin-cover opacity from the source IOR normal-incidence
  reflectance; refraction and angle-dependent Fresnel are not reproduced.
  Pupils are visible, but normal palette still resembles shiny and requires
  correction. This candidate is excluded from the user page.
- Centiskorch: baked transparency/emission is preserved, but multiple fire
  variants remain visible. Vertex-dependent source fire selection requires
  reconstruction; it is excluded from the user page.
- Ponyta and Rapidash: fire brightness/colour/shape need closer reference
  comparison; both are excluded from the initial page.

The first eight have source-pinned authored shiny candidates with unchanged
geometry/skin/animation and alpha, captured in standalone Godot scenes. Their
shiny appearance approval was received (“Alle acht goed”); the other four still need repair and
shiny reconstruction. All 12 need final battle placement/qualification.
Current admission and published counts remain unchanged.

## Evidence and replay

`catalog_remaining_142_intake.json` pins the 127 available archive members.
`catalog_remaining_142_action_pilot.json` pins the two source probes/mappings.
`catalog_remaining_142_checkpoint.json` binds standalone scenes, captures,
review images, source checks and the default-worker regression. Artifacts stay
in slot-a under `.tmp/remaining-142-production`. Prototype failures and
superseded scenes remain preserved. No source Blend is saved or changed.

```sh
python3 tools/sprite_factory/catalog_remaining_explicit_actions.py \
  --mapping tools/sprite_factory/catalog_remaining_142_action_pilot.json \
  --output .tmp/remaining-142-production/action-pilot-rerun
python3 tools/sprite_factory/catalog_remaining_native_emission.py \
  --intake .tmp/remaining-142-production/emission-intake-v1.json \
  --output .tmp/remaining-142-production/native-materials-rerun
```

The glass review additionally uses the explicitly named BodyA01 source glass
material in `transparent-intake-v2.json`; the worker verifies its shader type
and unlinked colour/IOR/roughness before allowing the approximate clear cover.
Candidates do not modify the game/launcher registry or create approved bundles.

## Eight-pair follow-up

`catalog_remaining_142_shiny_candidates.json` records explicit per-material RGB
anchors, pinned local normal/shiny HOME references, exact source/output GLBs,
standalone scene hashes and rendered review images. These are authored review
candidates, not claimed to be official rare-table exports. The shared palette
worker is unchanged. Emissive textures remain unchanged; native glow is retained.

[Eight-pair shiny review](http://127.0.0.1:8782/appearance-eight-pairs-v2/index.html)

The preliminary battle pass exposed centimetre source units in Arctovish and
Poipole; their candidate scale is now 0.01. Lillipup's readability multiplier
is 1.925 from a 34.3-pixel distant view. Other five species retain native scale.
The sized pass completed. Poipole still needs a readability increase;
Seismitoad, Noctowl and Trumbeak need native per-clip floor clearance.
All eight motion profiles use the existing baker and pass independent 120 Hz
samples, for normal and shiny scenes. All 256 camera shots remain in view
without HUD-proxy overlap; minimum floor clearance is above 1.5 cm. These are
technical candidates; user battle review and stress/qualification are pending.
The first unsized report is preserved, with its exact original catalog restored as `catalog-unsized.json`.

Model checkpoint commit `941fb1849` is not yet integrated: merge-task stopped
on unrelated Vermilion Fan Club edits in the normal frontend checkout. They
remain untouched by this task.

## Six further native action recoveries

Lugia, Ho-Oh, Vibrava, Flygon, Swanna and Mandibuzz have exactly one complete
numeric battle bank (bank 2), one native sleep loop and a single default source
rig. Every selected action shares the exact rig/form identity prefix.
`catalog_remaining_142_action_batch02.json` pins their mappings and probes.
All six preserve eight authored clips, including the second physical attack.
Native colour/material recovery preserves their geometry and animation accessors.
All six converted into standalone SCNs and rendered six review poses without
technical errors. They still need user appearance, shiny and battle approval.
`catalog_remaining_142_batch02_checkpoint.json` pins scenes and review images.

[Six normal appearances](http://127.0.0.1:8782/appearance-six-v1/index.html)

There are now 18 technically converted normal candidates among the 142:
eight have approved normal/shiny appearances, six await normal appearance
review and four retain visual repair holds. None have been newly admitted.

`catalog_remaining_142_battle_candidates.json` binds the 16 normal/shiny
standalone scenes, placement/motion candidates and exact measurement reports.
[Eight-pair battle review](http://127.0.0.1:8782/battle-eight-review-v1/index.html)
