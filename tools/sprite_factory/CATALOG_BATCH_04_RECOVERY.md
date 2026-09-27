# Batch 04: source recovery, 2026-09-27

**Current status:** the last two source holds, Walking Wake and Iron Leaves,
have since passed local normal/shiny, battle, bundle and launcher review. The
26-case batch-04 recovery review queue is empty. This does **not** complete
the other 200 batch-04 candidates: their full normal/shiny and battle
qualification is tracked separately in `CATALOG_BATCH_04_MAIN.md`.
See the final qualification section below. No new content has been published.

## Scope and status

Recover the 25 initial intake holds and Spiritomb, then review normal/shiny and
qualify battle presentation before approval. This task does not activate game
entries, approve bundles, upload content, or start batch 05.

**24 normal/shiny candidate pairs are exported:** 23 of the initial 25 holds,
plus Spiritomb. Eight native clips per variant include both physical attacks.
The user accepted all 24 normal/shiny pairs after the eye corrections. Battle placement remains pending. Two source cases remain open;
the review queue is not empty.

The manifest retains starter priority and then National Dex order. Basculin and
Pyroar now use the actual backend identifiers `basculin-red-striped` and
`pyroar-male`, selecting their default form/gender explicitly.

## Recoveries

- Flying idle cases use the same species' official bank-0 sleep clip, via the
  existing explicit cross-bank diagnostic. Available bank-2 facial baselines are
  preserved. Transition and floor clearance still require battle review.
- Giratina uses the complete bank-0 set, instead of an incomplete flying set.
- Slakoth excludes exactly two unused foreign battlewait references. All selected
  motions must still belong to the local Slakoth catalog.
- Arceus and Squawkabilly opt into a checked frame-zero normal material selector.
  Form 0 / gender 0, material inheritance and visibility are checked; alternate
  form selection remains held. Arceus verifies 20 colours and Squawkabilly one.
- Rellor uses a separate local stage with structural files restored from the
  matching original ROMFS. Original sources are unchanged. The local repair
  receipt records old/new hashes; PNG visual parity is not inferred from this.
- Rookidee, Corvisquire and Spiritomb preserve source dynamic visibility through
  the existing diagnostic path. Wattrel/Kilowattrel restore both source eyelid
  bindings before normal import and shiny substitution.
- Spiritomb's previous screen-space refraction approximation hid its facial
  geometry. The explicit `source_refraction_alpha_diagnostic` now selects alpha
  mixing with the source-derived average Fresnel alpha. The purple shell remains;
  true native refraction and view-dependent Fresnel are not reproduced. Other
  transparent candidates retain their existing behavior.
- Shiny conversion reads Float4 colour parameters, verifies the embedded normal
  shader inputs and applies source rare values to mapped inputs. This also enables
  colour-only Arceus. EmissionIntensity maps to the pinned importer's
  EmissionStrength socket; official MetallicMap substitutions are supported.
  Unknown changes remain held. Starly/Pelipper/Pyroar have recorded colour fields
  not represented by this importer; Giratina has an unrepresented eye metallic
  highlight scalar. These are explicit visual-review limitations, not shader parity.

## Two source holds: Walking Wake and Iron Leaves

The newer model dump contains the expected species geometry, but it does not
match the older animation ROMFS. Restoring that ROMFS initially yielded scenes
that passed structural checks but **show Raichu-shaped test models**, not the
requested Pokémon. Those exports are rejected and excluded from the valid gallery.
Both placeholder main mesh buffers have SHA-256:

`bd14f5beaa4b6d1547b37c171def01f80f2500447a39f3ac06dc0ead661b0cdd`

A narrow resource-and-content rejection prevents reusing these bytes under
`pm1084_00_00` or `pm1091_00_00`. It does not blanket-block future genuine assets.
The supplied Biochao archives end at Gen 8; no matching modern motions were found
in the supplied model/ZA archives. The user does not know of a newer local source.
A compatible newer model + animation source is still needed.

Source discovery found a [Gen IX Tabletop Simulator collection](https://steamcommunity.com/sharedfiles/filedetails/?id=3428100851)
whose creator describes animated Paradox models. This is a lead, not a verified
SCVI source replacement; no assets from that collection were admitted or downloaded.
The [Biochao storefront](https://biochao.gumroad.com/) did not establish an available
Gen 9 package during this check.

## Local evidence and continuation

Artifacts live in `.tmp/batch04-recovery/` in slot-a:

- `valid-normal-stage.json` / `valid-shiny-stage.json`: selected exports only.
- `valid-normal-runtime/report.json` / `valid-shiny-runtime/report.json`: standalone
  SCNs with export metadata, hashes and eight clips each.
- `valid-normal-motion/review.json` / `valid-shiny-motion/review.json`: three sampled
  times for every clip. These check finite poses; they are not 60/120 Hz floor tests.
- `index.html`: one local review page with 24 normal/shiny pairs, eight action
  choices and three sample times. The page does not claim continuous playback.
- `source-holds.json`: the two rejected placeholder exports for audit only.
- `romfs-models/repair-receipt.json`: staged structural-source restoration.

`catalog_production_batch_04_recovery.json` pins valid GLBs, standalone scenes,
review reports and capture digests. `runtime_approved` stays false throughout.
The updated 24-pair visual review is accepted. Next: finish calibration and
independent battle scale/grounding/camera measurements, then obtain battle review. The other batch-04
candidates still need their remaining shiny and battle qualification. No new
batch begins while the two source holds remain unresolved.

## Verification

101 focused Python checks passed across SCVI identity/intake/materials, shiny
production, visibility, variant parity, export review and effect UV samples.
The optional Python runtime test was skipped because its environment fixture was
not supplied; actual Godot standalone conversion and rendered motion review were
run separately: 48 standalone scenes, 384 native clips and 1,152 sampled poses
with zero pose errors. No complete development certification was requested or run.

No player-facing runtime behavior changes in this task, so no game changelog entry.

## Eye review follow-up

The user rejected Starly, Wattrel and Kilowattrel eye presentation. Starly now
removes only the unreferenced constant-white fallback mask. The two Wattrel forms
bake the unobscured eye and embed their source eyelid textures and native animated
UV properties in standalone scenes. Eye materials are local to each scene instance.
The optional material-response replacement is omitted for these diagnostic exports
because it would replace the animated materials; they retain the existing PBR path.

The first animated pass inverted vertical offsets twice and closed the eyes in
flying idle. The latest pass uses native top-origin offsets after glTF import.
`eye-motion-{normal,shiny}-runtime-uv2/report.json` and matching
`eye-motion-{normal,shiny}-captures-uv2/review.json` pin the corrected candidates.
All 144 rendered sample poses completed without reported pose errors. Open idle
and closed sleep were visually inspected; the user accepted Wattrel and Kilowattrel normal/shiny idle and sleep on
`eyes-review-v2.html`, with enlarged images. The user subsequently accepted the updated full 24-pair gallery, including Starly.

The rendered two-instance check passes 76 seek/reset/isolation assertions.
The initial check freed instances before rendering any frame and emitted
material-is-null errors; allowing render frames before teardown removes those
errors. Battle qualification remains pending. No runtime entries are approved or activated.

## Battle follow-up

The 24 current normal scenes are pinned in `.tmp/batch04-recovery/battle-input/`,
replacing the three original eye candidates with the UV2 standalone scenes.
The 60 Hz sweep and two-camera/two-side screenshots are complete. Small models
received a candidate readability scale; native motion clearance was baked with the
existing helper and independently checked at 120 Hz. Land/bird sleep poses use
explicit grounded-rest candidates; Basculin retains its native floating intent.
All placement candidates require visual battle review before runtime approval.

The completed placement pass is pinned in `catalog_production_batch_04_recovery_battle.json`: all 24 candidates pass 120 Hz clearance, readability, both-camera framing and HUD-proxy checks. Giratina uses the separate 0.85-scale recheck. The local `battle-review.html` presents 384 images. The user accepted all 24 battle presentations. Three real battle rounds per group passed loading, action, faint replacement, framing, performance and memory checks. Twenty-four individual local bundles (48 appearances, 653.51 MiB) passed archive, launcher install, scene load, no-op and restart checks. `catalog_production_batch_04_recovery_approval.json` pins the local content approval. No release was published or activated.

Walking Wake and Iron Leaves remain source holds and are not counted among the 24 approvals. Their review queue remains open before batch 05.

## Follow-up source lead for the two holds

The public Sketchfab model metadata (checked 2026-09-27) lists downloadable,
animated Pokémon HOME models for [Walking Wake](https://sketchfab.com/3d-models/mobile-pokemon-home-1009-walking-wake-a40571bef9954259923b01584cebf2e2)
(six animations, uploader `goblin_king`) and [Iron Leaves](https://sketchfab.com/3d-models/mobile-pokemon-home-1010-iron-leaves-aa9345df4fc149c18ff063c7b5f91551)
(seven animations, uploader `Forsaken AR Official`), both marked CC BY. The public
API download endpoint returns HTTP 401 without a Sketchfab login. The user
subsequently supplied the two original-format ZIPs for local inspection.

## Downloaded Pokémon HOME sources: local diagnostic

The original archives are in `/home/adinho/Documents/3d_models/SketchFab/`.
Neither was modified. Walking Wake ZIP SHA-256:
`52c0b85518c2e67689c674eafb35ae1709fdc77d94d5c51cfe62c0dbaacdc0de`;
Iron Leaves ZIP SHA-256:
`6bc9c47b28137c4545e426e7d717d645577dd0093617142445fc5b87cbf07e6f`.
The Sketchfab pages above identify the respective uploaders as `goblin_king`
and `Forsaken AR Official` and mark each download CC BY. Any distributed
derivative needs the corresponding creator attribution and source link recorded
with the bundle.

Both nested archives contain a genuine animated FBX and normal/rare textures.
Blender 5.2 imported 168 Walking Wake bones and 53 Iron Leaves bones. Walking
Wake has native idle, physical attack, special attack and roar, plus eye/mouth
tracks. Iron Leaves has the same body actions, eye/mouth tracks and an extra
loop that does not produce a distinct body pose in Godot. Separate damage,
sleep, faint and second physical-attack motions are absent from these FBXs.
`sketchfab_home_recovery.py` keeps those source clips and makes five explicitly
authored *diagnostic* actions from the same rigs. The output is not claimed as
native source animation. Shiny PNG substitution is explicit.

The four preliminary GLBs and rendered reviews are under
`.tmp/batch04-recovery/sketchfab-authored-glb-v4/` and
`.tmp/batch04-recovery/sketchfab-authored-review-v4.html`. The user accepted
both normal/shiny pairs in native idle/attack and the provisional sleep/faint
gallery. All four GLBs converted to standalone Godot scenes with the eight
required battle actions. The 60 Hz normal-model grounding sweep completed
without pose errors; Walking Wake's authored faint intersects the resting
plane during its transition, so its existing motion-placement correction is
required and had to pass independent battle review before approval. At this
diagnostic stage, the two holds still required 120 Hz clearance, both battle
cameras, runtime loading and bundle validation.

## Final qualification of Walking Wake and Iron Leaves

The user accepted the normal and shiny source appearance, the authored
sleep/faint poses, and the battle placement in both camera presets. Walking
Wake uses battle scale 1.4 and Iron Leaves scale 2.0. The 60 Hz grounding
measurements completed with no errors. Independent 120 Hz sampling found one
short Walking Wake physical-attack floor dip that the ordinary 60 Hz envelope
missed; an explicit six-sample local correction around that motion removed it.
The final minimum clearance is 0.0298 m for Walking Wake and 0.0197 m for Iron
Leaves. All 32 battle screenshots remained in view with no HUD proxy overlap.

The four standalone scenes contain all eight required battle actions. Two
individual local bundles hold normal and shiny for each species, together
9,559,685 bytes. Their archive and scene hashes passed independent extraction
checks. The actual launcher asset store installed both bundles, loaded all four
scenes, and passed no-op update and restart checks. Three real battle rounds
(classic, stadium, classic) loaded normal against shiny, played actions and
replaced fainted actors successfully. Their 95th percentile frame times were
17.427, 17.318 and 17.315 ms respectively. The tracked
`catalog_production_batch_04_sketchfab_approval.json` pins the source, model,
scene, bundle and review hashes.

These two are **locally content-approved**, clearing the 26-case recovery queue.
The other 200 candidates still need their independent qualification.
The approved candidate bundles are not merged into a released content index or
uploaded. Before distribution, add the Sketchfab uploader/source attribution
to the game's linked credits page, then run the explicitly authorized release
certification/publishing flow.
