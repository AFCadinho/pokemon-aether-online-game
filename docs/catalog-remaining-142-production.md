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

## Six further pairs completed locally

The user approved the battle page (“Zien er goed uit”). Six individual
versioned bundles contain twelve standalone scenes and 96 native clips,
totaling 90,777,697 bytes (86.57 MiB). Fresh transactional install, no-op update
and restart checks passed. The unchanged real-battle stress check passed all
three classic/stadium/classic rounds, with p95 frame times of 11.368, 10.705 and
10.475 ms (20 ms maximum). No competing Godot processes were interrupted; an
existing game and editor were running during this successful performance gate.
The final admitted-registry check matched all twelve scenes and measured
profiles, and rejected unapproved hashes. Game and launcher registries agree.
`catalog_remaining_142_six_bundle_qualification.json` binds all evidence.

Local totals are now **897 ordinary species plus Mega Dragonite** (898 profiles,
1,796 normal/shiny records), with **128 ordinary species remaining**: four
material-repair candidates, 109 source/action holds and fifteen DLC motion
holds. The task’s 274-species intake now has 146 approved individual bundles.
These six and the preceding eight are local bundle-ready; none of those
fourteen has been uploaded to R2 or included in a new release.

## Four material holds: source diagnosis and Paras proposal

The four remaining material cases were inspected against their pinned Blend
graphs and local HOME images. Paras's embedded albedo itself has pale skin and
pink mushrooms. `catalog_remaining_paras_normal_review.py` proposes an authored
normal palette, preserving yellow spots, neutral facial details, alpha and all
geometry/skin/animation accessors. This is a reference-based colour adaptation,
not a recovered official normal texture. The existing thin glass-eye-cover
approximation still requires visual acceptance. Normal review is pending; shiny,
battle qualification and bundles are not complete.

Ponyta/Rapidash emission-only, core-only and unlit/mask-copy trials were rejected
during self-review: dark outlines and polygonal fire shells remain. Their
sources include opaque procedural fire layers and generated-coordinate shading;
simple brightness adjustment is insufficient. Centiskorch's source-ramp colour
trial retained excessive flame layers and was also rejected. These three remain
material holds, and none of the trials was admitted to the game. Artifacts and
source graph dumps are retained under `material-four-probe-v1` and the species'
trial directories in `.tmp/remaining-142-production`.

The full Paras temporal renderer produced 18 images but reported the legacy
source's absent `faint_loop`. Its six native clips remain unchanged; the separate
quick appearance profile checks only the available presentation poses. This
does not qualify battle behaviour or silently add a missing native animation.

`catalog_remaining_142_material_repairs_review.json` pins the proposal and review
evidence. Counts remain **897 ordinary species plus Mega Dragonite**, with
**128 remaining** (one normal appearance review, three material holds, 109
source/action holds and fifteen DLC motion holds).

[Paras normal comparison](http://127.0.0.1:8782/paras-normal-review-v7/index.html)

The user subsequently approved Paras normal (“paras goed”). Its shiny proposal
keeps the embedded pink mushroom strip byte-for-byte and adapts only the orange
skin towards the local shiny HOME reference. The committed shiny recipe
reproduces the captured GLB byte-for-byte. Both standalone scene hashes, unchanged
geometry/skin/animation and alpha checks pass. Ten quick presentation captures
have no errors; shiny visual acceptance and battle qualification remain pending.
The rejected broad RGB-anchor shiny trial is not used: it introduced pink edges
into facial/body detail. `catalog_remaining_142_paras_shiny_candidates.json`
pins the narrow skin-only proposal and the user's normal approval.

[Paras normal/shiny comparison](http://127.0.0.1:8782/paras-pair-review-v1/index.html)

The user approved shiny (“shiny goed”). Paras's battle candidate uses a uniform
2.1260462187 root scale, raising its minimum idle height from 31.98 to 67.34 px.
The shared normal/shiny placement has a 48.966 mm lift. The unchanged battle
reviewer measured all six native clips per variant at 60 Hz, then independently
checked corrected floor clearance at 120 Hz: minimum 25 mm (15 mm gate).
All 32 camera/side/pose shots are in view and clear the bounds-based HUD proxy.
The native grounded sleep uses a constant resting offset; attacks and faint use
measured conservative clearance offsets. No animation track or source pose was
replaced. The source has no independent `faint_loop` or second physical clip;
these checks cover the six clips actually present, without inventing extras.
`catalog_remaining_142_paras_battle_candidates.json` binds scenes, profiles,
measurements and images. User battle review, installed bundle/performance checks
and admission remain pending. Approved totals have not increased.

[Paras battle comparison](http://127.0.0.1:8782/battle-paras-review-v1/index.html)

## Paras battle approval and bundle installation

The user approved Paras normal/shiny in battle (“battle goed”). The individual
bundle contains two standalone scenes and twelve native clips, totaling
1,440,744 bytes. The unchanged transactional installation gate passed fresh
installation, no-op update and restart. `catalog_remaining_142_paras_battle_qualification.json`
pins the exact scenes, shared calibration and 32 approved camera captures.

The first installed real-battle stress run completed all three rounds with no
functional errors, but p95 frame times were 58.599, 26.278 and 26.074 ms, exceeding
the unchanged 20 ms admission gate. A separate Godot game and editor were running
and another task was bootstrapping assets. The failed timing measurement is
preserved as `approved-paras/installed-stress.{json,log}.first-run`; admission
awaits an uncontended measurement. No gate or runtime code was relaxed. Catalog
counts remain 897 ordinary species plus Mega Dragonite, with 128 remaining.

## Paras completed locally

After the user closed the competing Godot game, an initial rerun still exceeded
the 20 ms p95 limit in its first two rounds (40.004 / 21.642 / 17.045 ms). That
measurement is preserved as `installed-stress.{json,log}.game-closed-run`. A
subsequent unchanged run with the warmed shader cache passed all three rounds:
7.275 / 6.962 / 6.976 ms. The first-load measurements remain documented; this
successful timing result does not certify cold shader startup. All observed
long loading stalls were behind the battle cover. The tests and 20 ms gate
were not changed.

Paras's exact installed scenes and measured profiles now pass the admitted
registry check. Normal and shiny use the source's six native clips each; faint
holds the final `faint_start` pose through the existing supported fallback.
Game and launcher registries are identical. The frozen qualification is
`catalog_remaining_142_paras_bundle_qualification.json`; the bundle is 1,440,744
bytes and has not been published.

Local totals: **898 ordinary species plus Mega Dragonite** (899 profiles,
1,798 normal/shiny records), with **127 ordinary species remaining**: Ponyta,
Rapidash and Centiskorch material holds, 109 source/action holds and 15 DLC
motion holds. The 274-species task now has 147 approved individual bundles.
Fifteen bundles (the previous eight and six, plus Paras) await R2 publication.

## Fire source-mesh diagnosis: three cases remain held

The dedicated source-mesh worker preserves the real Generated coordinates,
UV layers and vertex attributes that the previous plane baker could not
represent. Floating-point emission buffers prevent values near 2.0 from being
clipped to 1.0 before PNG encoding. Explicit core opacity graphs can be
evaluated on an outer mesh's own UV domain; stretching a core bake directly
is rejected because the domains differ (outer V spans up to eight tiles).
Pinned source Blend files were checked unchanged after every bake.

Ponyta and Rapidash candidate scenes retain all original geometry, skin and
six native clips each. Standalone conversion and five-pose quick presentation
checks pass for both. Nevertheless, self-review rejects the static unlit and
authored warm-ramp candidates: oversized, flat fire layers remain. Disabling
outer layers is also insufficient. Centiskorch's eight fire materials were
baked over source meshes for diagnosis, but no new scene is proposed.

`catalog_remaining_142_fire_mesh_diagnosis.json` binds the source, recipes,
meshes, receipts and captures. None of these trials changes the approved
registries or counts. Next work must inspect native UV/attribute animation
and fire-layer visibility and reconstruct moving materials; further static
palette trials should not be treated as a production solution.

## Moving fire prototypes (normal appearance review pending)

Ponyta, Rapidash and Centiskorch now have isolated standalone preview scenes
with a periodic fire shader. Real source noise drives movement. Centiskorch
retains the recovered source coverage. Ponyta and Rapidash use an authored UV
cutout and warm palette on their oversized source fire cards; this is an
approximation, not exact native material recovery. Outer masks are disabled.
Their source Blender references are included alongside the new renders.

The mesh bake previously selected a mesh merely listing the material, even
when none of its faces used it. Centiskorch's shared material slots therefore
produced empty fire maps. Selection now requires actual material-bearing faces.
BakeUV is the render target, and named source UV nodes follow the SourceUV
rename. Fresh real-mesh bakes produce nonempty alpha for all eight Centiskorch
fire materials; source blend hashes remain unchanged.

All three preview packs preserve the exact meshes, skin binds, skeleton rests,
and animation keys through a fresh binary reload. Fifteen five-pose captures
render without errors. With the skeleton frozen, all three fire sweeps show
visible pixel changes and identical start/end pixels over the two-second loop.
Four sampled phases establish this limited evidence, not continuous smoothness.
The preview page explicitly labels its animation as four snapshots.

`catalog_remaining_142_fire_preview.json` pins the scenes, inputs, captures,
source bakes, shader and loop evidence. User appearance review is pending,
particularly for Rapidash's large fire layers. Shiny, gameplay shader whitelist,
battle placement, installed bundles and performance are not qualified. The
experimental shader is confined to the diagnostic tools; catalog counts remain
898 ordinary species plus Mega Dragonite, with 127 ordinary species remaining.

[Three moving fire previews](http://127.0.0.1:8782/fire-live-preview-v1/review-v7/index.html)

### Fire appearance feedback and fuller horse flames

The user accepted Centiskorch's normal fire appearance but found Ponyta too
sparse and Rapidash's flames too short. That feedback and the exact accepted
Centiskorch scene/shader hashes are frozen in
`catalog_remaining_142_fire_appearance_review.json`.

The v8 horse proposal extends the procedural tongue height and enables Ponyta's
outer flame layers with the pinned source opacity and 0.8 layer opacity. The
cutout now uses the normalized UV domain for multi-tile outer cards. Fresh
standalone reload parity, all fifteen pose captures, visible fire motion and
sampled loop-boundary equality pass again. Centiskorch's ten sampled pose/fire
images remain pixel-identical to the accepted v7 scene. Only Ponyta/Rapidash
normal fire review is pending here; all three still need shiny and production
runtime/battle qualification. Approved catalog counts are unchanged.

[Fuller Ponyta and longer Rapidash flames](http://127.0.0.1:8782/fire-live-preview-v1/review-v8/index.html)

### Rapidash tail-only revision

The user's next feedback specifically concerned Rapidash's tail. Source mesh
positions and skin weights identify FireCoreB/FireMaskB as the TailB chain
(with FireMaskB also influenced by Hips). Only those two material bindings
change in v9: FireCoreB uses 0.95 + 0.1*density tongue height and FireMaskB is
enabled with source coverage at 0.8 opacity. The mane bindings are unchanged.

Both normal side-camera comparisons cover five real native poses and render
without errors. The revised tail is shown from the side in the v9 page. All
three fresh standalone reloads, fifteen ordinary pose captures and three fire
loop checks pass. Ponyta and Centiskorch's ten pose/fire images each are
pixel-identical to v8. Ponyta/Rapidash visual acceptance is still pending;
Centiskorch's accepted normal fire scope is retained. No catalog admission,
bundle creation or release occurred in this diagnostic step.

[Rapidash tail before/after, plus all three previews](http://127.0.0.1:8782/fire-live-preview-v1/review-v9/index.html)
