# Batch 04: source recovery, 2026-09-27

## Scope and status

Recover the 25 initial intake holds and Spiritomb, then review normal/shiny and
qualify battle presentation before approval. This task does not activate game
entries, approve bundles, upload content, or start batch 05.

**24 normal/shiny candidate pairs are exported:** 23 of the initial 25 holds,
plus Spiritomb. Eight native clips per variant include both physical attacks.
Visual review and battle placement remain pending. Two source cases remain open;
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
Next: record the user's visual review of these exact pairs, measure and calibrate
battle scale/grounding/cameras, then obtain battle review. The other batch-04
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
`eyes-review-v2.html`, with enlarged images. Starly still needs explicit acceptance.

The rendered two-instance check passes 76 seek/reset/isolation assertions.
The initial check freed instances before rendering any frame and emitted
material-is-null errors; allowing render frames before teardown removes those
errors. Battle qualification remains pending. No runtime entries are approved or activated.
