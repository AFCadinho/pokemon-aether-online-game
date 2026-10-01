# Remaining 142 — source and normal-candidate recovery

The opening 1 October intake recorded 883 ordinary species plus
Mega Dragonite ready and 142 ordinary species remaining. The mounted external
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
shiny reconstruction. At that checkpoint all 12 still needed final battle placement/qualification.
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

The initial integration attempt for checkpoint `941fb1849` stopped on
unrelated Vermilion Fan Club edits in the normal frontend checkout. They
were left untouched. After the user confirmed a clean checkout, the model
work was merged into local development; the changelog conflict was resolved
by preserving both model and map entries.

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

At the six-model recovery checkpoint there were 18 technically converted
normal candidates among the 142: eight had approved normal/shiny appearances,
six awaited normal appearance review and four retained visual repair holds.
The subsequent admission of the first eight is recorded below.

`catalog_remaining_142_battle_candidates.json` binds the 16 normal/shiny
standalone scenes, placement/motion candidates and exact measurement reports.
[Eight-pair battle review](http://127.0.0.1:8782/battle-eight-review-v1/index.html)

## Eight pairs completed locally

The user approved the exact eight-pair battle page (“de 8 zien er goed uit.”).
All eight have individual versioned bundles, totaling 35,193,781 bytes
(33.56 MiB), in `.tmp/remaining-142-production/approved-eight/bundles`.
The unchanged transactional installer passed fresh install, no-op and restart
checks for all eight bundles and 16 standalone scenes. The unchanged real-battle
stress gate passed all three classic/stadium/classic rounds on installed scenes.
The eight are admitted to identical game/launcher reviewed registries.
`catalog_remaining_142_eight_bundle_qualification.json` binds these checks.

The local approved total is now **891 ordinary species plus Mega Dragonite**
(892 profiles; 1,784 normal/shiny records), with **134 ordinary species remaining**.
The published R2 index still contains 884 profiles; these eight have not been
uploaded or activated in a release. The six further appearance reviews remain
pending, alongside four material repairs, 109 source/action holds and 15 DLC holds.

## Six normal appearance review and eye repair

The user approved Ho-Oh, Vibrava, Flygon and Mandibuzz, but could not clearly
judge Lugia’s pupil or Swanna’s open eye. Close-ups confirmed pale missing
eye colours. Both were rebuilt from their official SCVI Eye-layer tables,
without body, geometry, skin or animation changes (exact parity passed).
Two new standalone SCNs and 20 close-up renders passed. A matching-camera
before/after page shows four idle moments and sleep. The two corrected eyes
remain pending user review; all six still require shiny and battle qualification.
`catalog_remaining_142_batch02_eye_repair.json` pins the official inputs and
parity; the batch checkpoint records four approved normal appearances.

[Eye close-ups](http://127.0.0.1:8782/eyes-lugia-swanna-v1/index.html)

## Six normals approved; shiny review prepared

The user approved the corrected Lugia and Swanna eyes (“ja, ze zijn goed”).
All six normal appearances are now approved. Official normal/rare tables and
source-matching image pixels supplied six shiny variants. Vibrava and Flygon
require the measured two authored image bindings to be replaced together; each
binding still passes exact normal-pixel validation. Ho-Oh’s five unrepresented
iridescence/emission colours remain an explicit visual-review limitation.
All six shiny GLBs passed exact geometry/skin/eight-clip parity; six standalone
shiny SCNs and 72 pair captures passed without technical errors. Cropped review
images enlarge the models for inspection. Shiny and battle approval remain
pending; catalog counts and runtime admission are unchanged.

[Six normal/shiny pairs](http://127.0.0.1:8782/appearance-six-pairs-v1/index.html)

## Six normal/shiny appearances approved

The user approved all six pairs (“Diezien er goed uit”). Shiny appearance
approval is recorded against the exact page and scene hashes. Battle
qualification is in progress. The initial raw camera measurements required
Lugia and Ho-Oh root scales of 0.50 and 0.45; Vibrava requires a 1.100563134
readability factor. Uniform root scaling preserves native animation curves.
Derived floor profiles are independently remeasured at 120 Hz on the exact
normal and shiny standalone scenes before a battle review is shown.

The twelve exact scenes passed the full 120 Hz clearance and 192 camera-shot
checks. Lugia’s second physical attack needed an additional 16.8 mm visual-root
offset; a focused independent check confirmed 30.1 mm clearance for both
variants. Original full reports remain unchanged and pinned. Derived final
reports combine that focused proof with unchanged camera-pose profiles and
other clip proofs. Every variant stays at least 24.9 mm above the flat floor,
remains in view, clears the bounds-based HUD proxy and exceeds 60 px idle height.
The review renderer uses white ambient fill to make shaded body details visible.
`catalog_remaining_142_batch02_battle_candidates.json` records profiles and all
proof hashes. User battle approval, installed stress and individual bundles
are still pending; approved catalog counts remain unchanged.

[Six pairs in battle](http://127.0.0.1:8782/battle-six-review-v1/index.html)
