# Mega 3D catalog production

Updated 2026-10-02. The final section records local admission of 71 additional
Mega pairs. This task does not upload, activate a release, or publish models.

## Catalog coverage

The Pokédex lists **97 Mega form variants across 87 base Pokémon**. Mega
Dragonite was the only approved normal/shiny Mega bundle at intake. With this
local admission there are now 72 qualified Mega pairs, with 25 source holds.

The connected `LegendsZAPkmnModelDumpWithDLC.rar` contains matching model
resources for **72 variants**. Mega Dragonite is already approved, so the
production run produced **71 additional normal/shiny candidate pairs**. This
includes Mega Hawlucha (`pm0701_11_00`), which was initially missed because its
model uses an alternate resource code. The remaining **25 variants across 21
Pokémon** still lack a safely confirmed Mega source mapping:

- Chesnaught, Delphox, Greninja, Pyroar, Floette, Meowstic (male and female),
  Malamar, Barbaracle, Dragalge, Zygarde, Crabominable, Golisopod,
  Drampa, Magearna (both forms), Zeraora, Falinks, Scovillain, Glimmora,
  Tatsugiri (all three forms), and Baxcalibur, and Diancie.

The local Scarlet/Violet dump and the attached Biochao packs were checked for
matching Mega resource identities; that intake did not fill the 25-form gap.
This is a mapping hold, not proof that every missing model is absent from the
archive. Alternate resource codes and rejected source identities need further
investigation before those forms can go through production.

## Candidate run

The initial 72 forms each have normal and shiny GLBs and standalone Godot
scenes: **144 scenes total**. All passed the import/export and scene reload
steps. One is now held: the purported Mega Diancie source and its icon actually show
a fox with fire/stick meshes. Its generated artifacts are preserved for diagnosis,
but it is excluded from the 71-pair review.

No runtime or appearance approval has been recorded, and no Mega bundle,
catalog entry, or R2 object has been created for these candidates.

The review page is at:

`http://127.0.0.1:8795/mega-native-rest-v1/review-v5/index.html`

It displays normal and shiny side by side and lets the reviewer inspect idle,
attacks, sleep, damage, and faint poses. It is framed for appearance review;
final battle size and floor placement still require the battle review.

The first review revealed incorrect layer ordering and eye occlusion. Source
table comparison found 432 native opaque materials exported as `BLEND` in each
variant. The corrected candidates restore 435 opaque materials and one authored
alpha-cutout material per variant, preserving the two genuinely transparent or
additive materials. This changes material opacity only; mesh, skinning, UV and
animation accessors are checked against the original candidate exports. The
review includes an eye close-up control for inspecting remaining face issues.
All 144 corrected Godot scenes reload. A separate check traversed 1,412 material
bindings and confirmed the native opaque/cutout settings with zero mismatches.

Known review points from source diagnostics:

- 70 reviewable forms use their own Mega down-loop as a review-only rest pose because their banks
  lack a sleep loop. The prior base-form retarget distorted several Mega bodies
  and applied incompatible visibility; it has been removed. Mega Hawlucha has
  its own native sleep loop. The fallback is explicitly labelled on the page
  and still needs visual acceptance as a rest pose.
- 11 forms have dynamic source mesh-visibility tracks. Those tracks are
  attached to the Godot scenes and require visual inspection.
- Only 11 forms have a second physical attack selected from the source.
- 48 forms have an inherited eyelid diagnostic on at least one selected pose.
- Source material-animation tracks are not replayed in the generated GLBs.
  Static normal/shiny material tables are applied; the review page labels this
  limitation. Any form whose animated material layers matter needs follow-up.

These are candidates, not a claim that all 71 are ready to release. Review the
appearance first, resolve visible issues, then run battle-size/pose qualification
and make individual bundles only for accepted forms. The 25 source holds stay
on 2.5D until matching Mega sources are available.

The exact form-to-source map, source identity evidence, and source archive
SHA-256 are recorded in
[`catalog_mega_3d_source_intake.json`](catalog_mega_3d_source_intake.json).

## Appearance review accepted

On 2026-10-02 the user accepted the appearance of all 71 review pairs, with
Mega Steelix size left uncertain because the overview camera was distant.
The hash-pinned acceptance is in `catalog_mega_appearance_checkpoint.json`.
This is appearance acceptance only: battle and runtime approval remain false.

A focused native Godot idle check shows Mega Steelix is not undersized: scale
1.0 clips above the classic camera, whereas the review proposal 0.7 fits all
four camera/side views for normal and shiny. The user has accepted the 0.7 scale; full-pose calibration remains pending. The overview now frames visible posed
geometry rather than the unanimated mesh bounds.

## Steelix surface follow-up

The user accepted the proposed 0.7 size but reported incomplete-looking detail.
Steelix appearance was held again; the other 70 appearance acceptances
remained pinned. All seven source meshes are present. A separate review-only
recovery restores the source-masked metallic values for body_a/body_b/body_c
and the body_d crystal layer light. Geometry, UV, rig and animation signatures
are unchanged; both new standalone scenes convert and reload.

Neutral reflection lighting is identical before/after in the new diagnostic.
This is a static PBR approximation, not native view-dependent refraction parity.
The new models and accepted detail review are pinned in
`catalog_mega_steelix_surface_checkpoint.json`. The user then accepted normal and shiny with “deze zijn goed”. All 71
normal/shiny appearance pairs are accepted; full-pose battle qualification
remains outstanding. The combined, source-pinned follow-up input is
`.tmp/mega-native-rest-v1/appearance-approved-status.json`, which selects the
corrected Steelix GLBs and SCNs rather than its superseded first export.

## Joint Mega battle review prepared

The 71 accepted appearance pairs (142 variants) are staged with hash-pinned
GLBs, native scenes and source animation durations. A complete native 60 Hz
baseline supplied 115,582 source-clock samples. Proposed placement preserves
source geometry and motion, with a uniform readable scale and per-action
floor correction. No faint-start/faint-loop endpoint holds were found.

All 142 variants have visual captures in both runtime camera presets and both
battle sides. The joint review is at
`http://127.0.0.1:8795/mega-battle-71-v1/review-v1/index.html`.
Mega Steelix retains its accepted 0.7 scale, but its special attack overlaps
the classic-camera HUD proxy by about 7 pixels. This is explicitly marked on
the page and remains a technical hold; no qualification threshold was relaxed.
The other captured poses fit their cameras without HUD-proxy conflicts.

The independent full-clock 120 Hz native animation validation is still running.
The visual capture report deliberately has no 120 Hz clearance evidence and
cannot qualify any variant. The checker rejects incomplete native reports and
holds all 142 capture-only variants. User battle approval, full runtime/UI and
performance checks, bundles and catalog admission remain pending. The 25 source
holds are unchanged. This checkpoint does not authorize publication or R2 upload.

## Battle acceptance and final native clearance

The user accepted all 71 battle pairs, then also accepted the focused Steelix
and Gyarados placement follow-up. Steelix's final proposed scale is 0.65; its
special attack no longer overlaps the classic HUD proxy. Gyarados's second
physical attack and Pidgeot's physical attack have small constant root-clearance
corrections after actual 120 Hz subframe failures. The Pidgeot comparison in all
four views shows the same accepted pose with a 9.45 mm root addition. Source
geometry, materials and animation channels remain unchanged.

All 142 final variants pass the native gate with complete 120 Hz action clocks,
finite sample arrays, source duration parity and valid captured framing. Original
failed measurements and filtered native reruns remain available per variant;
`catalog_mega_battle_final_evidence.py` accepts only measurements made with the
exact final per-form profile. Native evidence and user acceptance are pinned in
`catalog_mega_battle_checkpoint.json`.

71 independently versioned local Mega bundles total about 802.04 MiB. The
transactional launcher check installs all 71 into one content store, including
several Mega forms of the same species, and verifies all 142 scene hashes,
no-op planning and restart. The older species-only review harness assumed one
asset per species; its failed attempt is retained and the new Mega check tests
actual multi-form coexistence without changing the store or relaxing integrity.
The on-demand game check verifies all 71 pairs before reveal, exact normal/shiny
identities, final motion and timing, and no new fetch when swapping variants.
The download service now recognizes Mega X/Y/Z as distinct form assets.

The three-round actual battle performance gate is still running, with the
existing 20 ms steady/full-round p95, 64 MiB source-retention, uncovered-stall,
threaded dispatch and memory-growth limits. Catalog admission remains pending
until that complete gate passes; preparation alone grants no runtime approval.

## Local catalog admission completed

All 71 additional normal/shiny pairs have passed the unchanged three-round
performance and memory/load gates. Classic/stadium/classic full-round p95 was
17.241 / 18.233 / 17.164 ms; prepared steady p95 was 17.168 / 18.192 ms. Maximum
threaded dispatch/collect spans were 3.078 / 3.121 / 2.616 ms. Final-round static
memory growth was 811,684 bytes, below the existing 1 MiB gate. All 71 pairs
passed actual HUD checks and faint replacement in each arena round.

`catalog_mega_71_bundle_qualification.json` records exact scene/bundle hashes,
installed catalogs, native evidence, runtime tests and performance observations.
The game and launcher registries now contain all 142 new appearances with 71
shared normal/shiny profiles. A further runtime pass checks the actual admitted
registry without injecting fixture approval, loads every pair before reveal,
checks exact final motion/timing and confirms no variant-swap download.

The inherited registries had identical keys/hashes but different float spelling
from commit 99c22a443 (maximum numeric difference 1.17e-10). Admission rejects any
non-numeric difference or delta above 1e-9, preserves the game's values and tab
format, and mirrors the result to the launcher. Both files are now byte-identical.

The 71 individual bundle archives remain outside the base build. Their local
index is tracked in `release/approved_3d_mega_71_index.json`. Publication and
release content-index activation are separate steps requiring authorization.
The 25 source-mapping holds remain; this does not claim all 97 Megas are ready.

## Compatibility with the updated battle HUD

The task incorporated the newer development battle layout before integration.
A focused actual-registry replay passed all 71 pairs and faint replacements in
three classic/stadium/classic rounds. Full-round p95 was 16.852 / 16.876 /
16.834 ms; final static memory growth was 373,124 bytes. The existing limits
were unchanged. This supplements the longer prepared-steady performance run;
it does not replace that measurement. The qualification receipt pins the replay
and the updated battle layout sources.

## R2 publication completed

On 2026-10-02, all 71 approved Mega bundles (142 appearances, 840,998,387
bytes) and their immutable content index were published to R2. Fresh public
GET SHA-256 and HEAD size checks passed for all 72 objects. Publication evidence
is in `release/approved_3d_mega_71_r2_upload.json`; the intake rows bind that
receipt and now record publication. The qualification receipt remains the
historical local admission evidence.

The active desktop manifest was unchanged. These bundles are staged for a
future release; this publication does not activate them for current clients.
The 25 unresolved source mappings remain outside this published cohort.
