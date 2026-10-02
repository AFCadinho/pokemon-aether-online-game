# Mega 3D catalog production

Updated 2026-10-02. **96 of 97 Mega catalog form pairs are locally qualified.**
The latest 24 individual bundles are published to R2; the desktop manifest is
not activated. The earlier 71 were also published. Female Mega Meowstic remains a source
identity hold. Historical milestones below retain their original scope.

## Catalog coverage

The Pokédex lists **97 Mega form variants across 87 base Pokémon**. Mega
Dragonite was the only approved normal/shiny Mega bundle at intake. With this
initial local admission there were 72 qualified Mega pairs. At that point 25 source
mappings were held. The source audit at the end of this document has since
identified candidates for 24 entries; one gender-specific mapping is still
unconfirmed. The final section records production and qualification of the 24
confirmed candidates, bringing the current qualified total to 96.

The connected `LegendsZAPkmnModelDumpWithDLC.rar` contains matching model
resources for **72 variants**. Mega Dragonite is already approved, so the
production run produced **71 additional normal/shiny candidate pairs**. This
includes Mega Hawlucha (`pm0701_11_00`), which was initially missed because its
model uses an alternate resource code. The original production intake left
**25 variants across 21 Pokémon** without a safely confirmed Mega source map:

- Chesnaught, Delphox, Greninja, Pyroar, Floette, Meowstic (male and female),
  Malamar, Barbaracle, Dragalge, Zygarde, Crabominable, Golisopod,
  Drampa, Magearna (both forms), Zeraora, Falinks, Scovillain, Glimmora,
  Tatsugiri (all three forms), and Baxcalibur, and Diancie.

The local Scarlet/Violet dump and the attached Biochao packs did not fill the
gap under the expected Pokédex resource IDs. This is a mapping hold, not proof
that the models are absent from the archive. A later scan found alternate
developer numbers; see the source audit below.

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

## Audit of the remaining 25 Mega sources

The 2026-10-02 audit found candidate ZA source resources for 24 of the 25
remaining form entries. These resources use developer numbers rather than
Pokédex numbers. The Gen 6–8 developer-number tables and visual comparison of
normal-form and Mega source icons identify the alternate codes. A complete
model-resource scan found 22 unique Mega resources for these entries.

| Form entries | ZA source resource |
| --- | --- |
| Chesnaught, Delphox, Greninja, Pyroar, Floette | `pm0722_51_00`, `pm0719_51_00`, `pm0725_51_00`, `pm0705_51_00`, `pm0714_51_00` respectively |
| Meowstic male and female | `pm0734_51_00` (male icon matches; female mapping needs its own gender check) |
| Malamar, Barbaracle, Dragalge, Zygarde, Diancie | `pm0727_51_00`, `pm0748_51_00`, `pm0710_51_00`, `pm0770_51_00`, `pm0772_51_00` respectively |
| Crabominable, Golisopod, Drampa | `pm0860_51_00`, `pm0867_51_00`, `pm0856_51_00` respectively |
| Magearna, Magearna Original | `pm0882_51_00`, `pm0882_52_00` respectively |
| Zeraora, Falinks | `pm0888_51_00`, `pm0923_51_00` respectively |
| Scovillain, Glimmora, Tatsugiri (Curly, Droopy, Stretchy), Baxcalibur | `pm1043_51_00`, `pm1071_51_00`, `pm1056_51_00` (three icon variants), `pm1055_51_00` respectively |

Each of the 22 unique resources contains a model, meshes, rig, normal and shiny
material tables, and the selected idle, attack, special attack, damage and
faint clips. The audit found no native sleep clip or second physical attack in
these sources; the existing Mega rest-pose fallback can be considered during
production. Meowstic female still needs a gender-specific match, and Tatsugiri
needs a runtime check that all three shared-resource variants select the right
geometry and materials.

This source-mapping audit preceded the production step below. Its per-form
identity evidence remains in `catalog_mega_25_source_audit.json`.


## Remaining Mega production: 24 pairs visually accepted

The assigned `slot-c` task produced 24 normal/shiny pairs: 48 standalone SCNs,
336 native clips, and zero native pose/timing errors. The source adapter now
separates audited developer numbers from catalog Pokédex numbers and rejects
changed identity icons, incorrect species/form matches and unconfirmed gender
mappings. Existing approved Mega entries were not rebuilt or replaced.

Zygarde's duplicate exported energy/head surface was resolved with a strict
native material binding. Magearna Original references 17 textures from the
same Pokémon's other Mega source; staging and hashes are recorded. Greninja's
small water palette needs a reviewed static blue surface translation.

The user accepted 23 appearances on the combined native review page and then
accepted revised Diancie separately. Diancie's authored crystal facet images
were missing from the initial plain-colour conversion. The corrected static
PBR translation restores them, and a two-sided thin material restores the
white veil triangles that disappeared when facing away from the camera.
Geometry, UV accessors, skins and animation data remain unchanged. Both fixed
variants pass native pose/timing checks. Native camera-dependent crystal
Fresnel/parallax is still a static approximation, explicitly reviewed.

`catalog_mega_24_candidate_production.json` binds approvals to exact model,
scene and review evidence hashes. Battle placement checks are underway; no
battle, performance, bundle-install or runtime admission is claimed yet.
The existing default 71-pair battle gates now also accept an explicit cohort
size while still requiring unique, complete approved normal/shiny pairs and
the unchanged 60/120 Hz, floor, camera and HUD checks.

All sources lack a second physical attack and native sleep clip; the approved
sleep proposal uses each Mega's own rest loop. Tatsugiri's three catalog form
IDs share the source containing all three fish, rather than fabricated separate
geometry or colours. Female Mega Meowstic remains outside this cohort because
its gender-specific source identity is still unconfirmed. The qualified total
therefore remains 72 Mega pairs until these 24 complete battle and runtime
qualification. No publication or release activation was performed here.


## Remaining 24 Mega pairs: local admission completed

The user accepted all 24 normal/shiny pairs in battle. Complete independent
120 Hz evidence passes for all 48 exact final scenes. Barbaracle's physical
attack has a 32.48 mm upward root correction and Zeraora's has an 11.44 mm
correction; source geometry, materials, scale and animation channels are
unchanged. The acceptance check allows only bounded, uniform upward clearance
changes, and rejects changed scale, timing, idle poses or arbitrary offsets.

24 individual bundles total **297,575,175 bytes (283.79 MiB)**. Transactional
launcher installation verifies all 48 scene hashes, multi-form coexistence,
no-op planning and restart. The on-demand game check loads every pair before
reveal, preserves exact shiny identity and final timing/motion, and requests no
extra download when switching variants. A final run against the actual admitted
registry passes all 24 pairs without injecting fixture approval.

The real battle interface exposed a Mega Greninja HUD conflict missed by the
pose-based proxy: the whole idle animation envelope reaches the sprite HUD's
62-pixel top margin. The HUD now uses available space above the 3D envelope,
keeping the model's accepted scale and pose. Actual checks of all 24 pairs in
both arenas have no own-model, cross-model or HP-panel overlaps. Focused HUD
checks also preserve the existing 2D behavior. A side-placement experiment was
superseded after image inspection and is not the admitted implementation.

The final unchanged three-round performance gates pass: classic/stadium/classic
full-round p95 **16.850 / 19.891 / 16.846 ms**, prepared steady p95
**16.845 / 19.856 ms**, and final static memory growth **190,684 bytes**. The
20 ms p95, 64 MiB source-retention, covered-stall, threaded dispatch and 1 MiB
memory-growth limits were retained. An earlier stadium measurement exceeded
the gate at 21.111 ms; it is preserved as a failed attempt, not qualifying
proof. A short diagnostic control and the complete final rerun are retained,
with per-Pokémon prepared-frame observations for attribution.

`catalog_mega_24_bundle_qualification.json` binds the native, installed, runtime,
HUD and performance evidence. Game and launcher registries are byte-identical,
with 1,139 shared profiles and 2,278 normal/shiny appearances. The local index
is `release/approved_3d_mega_24_index.json`. The appearance/battle checkpoint
retains its historical pre-performance flags; the qualification receipt and
candidate-production record are the authority for completed runtime admission.

This task has not uploaded these 24 bundles, activated a release content index,
certified platforms or published a release. The qualification scope is local
AMD Compatibility. Native sleep and second physical attacks are absent in this
cohort; approved own-Mega rest loops and the selected native attack are used.
Static material approximations and the three Tatsugiri IDs sharing the authored
three-fish source remain the visually accepted limitations. **Only female Mega
Meowstic remains unqualified**, because its separate source identity is not
confirmed; this is a count of Mega form entries, not base Pokédex species.


## Remaining 24 Mega pairs: R2 publication completed

All 24 approved individual bundles and the immutable Mega 24 content index are
published. Public GET SHA-256 and HEAD size checks passed for all 25 objects.
The 24 archives total 297,575,175 bytes. The active desktop manifest remained
unchanged, so publication alone does not make these pairs available to clients.
The receipt is `release/approved_3d_mega_24_r2_upload.json`; the catalog intake
rows bind that receipt. Release content-index activation and desktop release
certification are still separate tasks.
