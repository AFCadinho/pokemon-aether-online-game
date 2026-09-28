# Remaining base-species 3D intake — 2026-09-28

This intake attempted every base species outside the existing catalog and Batch
04. It does **not** add runtime entries, approve visual quality, create shiny
variants, build bundles, or publish content. The locally generated diagnostics
are under `frontend/.tmp/catalog-remaining-*` in slot-a.

## Exact scope

- The backend has 1,025 National Dex base identities. Eleven are represented
  only by form-named files; `catalog_remaining_intake.py` pins their default
  choices rather than dropping them from the count.
- The current catalog and Batch 04 cover 479 base species plus Mega Dragonite.
  This includes Batch 04's 200 still-unapproved candidate bundles.
- **546 base species remain.** Biochao Gen 1–8 archives contain a default-form
  `.blend` candidate for 525; 21 have no matching base source in those archives.

The 21 without a Biochao base source are Unown, Darmanitan Standard,
Wishiwashi, Silvally, Obstagoon, Cursola, Dipplin, Poltchageist, Sinistcha,
Okidogi, Munkidori, Fezandipiti, Ogerpon, Archaludon, Hydrapple, Gouging Fire,
Raging Bolt, Iron Boulder, Iron Crown, Terapagos and Pecharunt. A numeric `pm`
directory in the SCVI/ZA dumps is not accepted as species identity: their
resource IDs can differ from National Dex numbers. The pinned SCVI catalog has
no default-form identity entry for these 21.

## Technical run

`catalog_remaining_intake.py` mapped archive members using the Gen 6–8 developer
number CSVs, then inspected all 525 candidates in isolated Blender sessions with
embedded scripts disabled. **484 sources opened; 41 were held** because the
default rig cannot be isolated with unambiguous texture evidence or the scene
contains unsupported multi-rig content.

The old action matcher expected a filename extension. Later Biochao `.blend`
files use extensionless native action names. The matcher now accepts either form
with exact token boundaries; 271 initially empty action reports were rechecked.
The final source reports offer **300 possible normal exports** using the six
actions required by the current battle runtime. A native faint loop is included
when unambiguous; otherwise the battle controller keeps the last faint pose.
Second physical attacks are included only when the source action is unique and
belongs to the selected animation bank.

The normal export pass produced **297 GLBs**. Three remained blocked:

- Bulbasaur: its existing hash-bound visibility repair covers seven actions but
  not the newly selected second physical attack; that combination needs review.
- Liepard: the source has missing texture dependencies.
- Stakataka: its chosen sleep action is empty.

The other 225 Biochao candidates consist of 41 source holds and 184 incomplete
or ambiguous native action sets. The status files retain one reason per species.
The 297 GLBs are direct-material diagnostics; material parity and shiny assets
are not established. A previous Bulbasaur seven-action export is preserved as a
separate local diagnostic and is not counted among the 297.

Standalone Godot conversion used `catalog_remaining_normal_runtime.py` in the
assigned slot. **All 297 GLBs became independent SCNs with zero conversion
errors.** The per-species result is in
`.tmp/catalog-remaining-normal-runtime/status.json`. Exact source, GLB and SCN
hashes, actions and hold reasons are pinned in
`catalog_remaining_normal_candidates.json` (297 technical candidates, 228 review
holds, 21 missing sources). These scenes still need
normal/shiny production, material and visibility review, scale/grounding,
rendered motion checks, battle review and individual bundle qualification.

## Bulk shiny continuation — 2026-09-28

The complete 546-species remainder was sent through a conservative local shiny
material pass. Biochao source hashes, the existing normal GLB hashes, official
normal/rare material tables, and embedded normal pixels are checked before a
rare texture is used. The eight plain-albedo cases were exported by
`catalog_remaining_shiny_glb.py`. The audited review route in
`catalog_remaining_shiny_review.py` attempted the other material-backed cases
and retained explicit warnings when the older Biochao shader lacks an input
for an official rare parameter. Exact geometry and native animation parity is
required for every exported shiny GLB.

**156 normal/shiny pairs now have standalone Godot scenes**: eight simple
substitutions and 148 audited source exports. All 148 new shiny scenes
converted without Godot errors; the earlier eight also converted without
errors. Seventy-five of the 156 pairs have one or more unrepresented rare
shader parameters and need particular attention to eyes, glow, and material
colour. All 156 pairs remain technical candidates, not visually or battle
approved. The pinned per-species status, hashes, source limitations, and
remaining holds are in [catalog_remaining_shiny_results.json](catalog_remaining_shiny_results.json).

The remaining 390 consist of **141 shiny-material holds**, **228 prior source
or native-action holds**, and **21 missing base sources**. Of the 141 material
holds, 121 have no corresponding official normal/rare material tables in the
available SCVI dump. The other 20 failed explicit rare-settings, source-pixel,
or distinct-variant checks. These holds do not change any approved catalog.

Normal and shiny scenes were rendered at six poses each, 1,872 captures with
zero render errors. The local one-page visual overview is
`.tmp/catalog-remaining-156-review-2026-09-28/index.html` in slot-a. It uses
auto-fit framing; battle size, grounding, and placement still need separate
qualification. The GLBs, SCNs, captures, and run logs remain ignored local
artifacts in the assigned slot. No registry, bundle, R2 index, release, or
game default was changed.

## Eye-material follow-up — 2026-09-28

The first 156-pair visual review exposed a shared Biochao-to-glTF issue:
the direct export renders the official four-channel eye layer mask as RGB,
or falls back to white, instead of mixing the official layer colours. The
review-only `catalog_remaining_eye_bake.py` packs the normal or rare table's
eye colours into a new GLB texture, leaving geometry and native animations
untouched. It also clears a full-white emission factor on 23 body materials
where the official table contains no body emission. The batch wrapper
`catalog_remaining_eye_batch.py` checks the pinned input GLB hashes and
writes a per-species output receipt.

The repair matched 154 pairs. Nosepass and Milcery have no matching eye
material, so their original GLBs were retained. All 154 repaired normal/shiny
GLBs passed geometry and motion parity. All 312 resulting variant scenes
converted in Godot. Eye renders are captured from idle and sleep using the
`POKEAETHER_CATALOG_REVIEW_EYES_ONLY=1` profile of
`catalog_motion_review.gd`; their local before/after page is generated by
`catalog_remaining_eye_review_page.py`. A second pass corrected a distinct
albedo-alpha error on 12 pairs; all 24 updated variants preserved geometry
and motion and converted and captured without errors. The 624 cohort
idle/sleep captures also reported zero render errors. The latest local page is
`.tmp/catalog-remaining-eye-review-v5-2026-09-28/index.html` in slot-a.
These are still review candidates:
eye appearance, battle scale, grounding, and the other poses need qualification
before catalog or release approval.

### Full eye audit after visual feedback

The follow-up checks both variants of **all 156 pairs** against the pinned
official normal/rare eye materials: 312 GLBs and 634 eye-material bindings.
`catalog_remaining_eye_audit.py` records each eye mesh binding, texture alpha,
raw mask emission, roughness, and source highlight setting. Its local receipt is
`.tmp/catalog-remaining-eye-audit-v4-2026-09-28.json`. The final candidate
receipt is `.tmp/catalog-remaining-eye-repair-v4-2026-09-28/status.json`:
153 pairs have review-only material corrections, Nosepass and Milcery have no
matching Eye material and remain unchanged, and Ninetales deliberately uses its
original eyes because the material bake looked worse in the visual comparison.

The final audit found no missing eye mesh, unintended eye alpha, or raw mask
emission in the 153 repaired pairs. It still records 360 Eye-material bindings
across 87 species whose official highlight setting cannot be verified in the
Godot import; the attempted GLB clearcoat extension was ignored by that
importer. Ninetales alone retains four raw-mask/roughness warnings in its two
original GLBs, despite the visually preferred result. A clean technical audit
does **not** prove good-looking eyes: Blastoise, Entei, Furret, and Mudkip are
user-reported eye holds, including Blastoise whose material audit is clean.

The initial visual holds included Magmar body colours, Yanma's apparent missing
wing, Elekid's electricity colour, and Torracat's neon body. The colour cases
received the later review-only repair described below; Yanma still needs a
side-view check. Chinchou and Lanturn
previously had wrong pink/green body colours; the review-only pass restores
their official normal/rare body albedo, and both variants converted and rendered
in Godot. Ninetales, Chinchou and Lanturn appear together in
`.tmp/catalog-remaining-eye-v4-probe/contact.png`. Poliwag's apparently absent
tail was confirmed present from the side. The combined 156-pair comparison is
`.tmp/catalog-remaining-eye-review-v6-2026-09-28/index.html`. None of these
technical or visual reviews changes the approved catalog or releases the 156.

## Body-colour audit after full-eye review

The 156-pair eye page still exposed major colour failures, especially among
later National Dex entries. A binding scan found 96 body-material bindings per
normal/shiny set across **37 species** where the glTF base colour used a
normal, metal, region or layer-mask image instead of the source albedo.
`catalog_remaining_body_repair.py` checks the eye-review GLB hashes, restores
the official normal/rare `BaseColorMap`, and bakes non-neutral source layer
tints for 27 bindings per variant. It removes raw mask emission from corrected
materials and, for Magmar, Jirachi and Golett, the remaining raw mask
emission on their bodies. This is review-only reconstruction, not complete
SCVI shader parity. White source tints preserve albedo instead of replacing
it; this matters on Magmar's belly. Alpha remains the source albedo alpha.

The local receipt is `.tmp/catalog-remaining-body-repair-v6-2026-09-28/status.json`:
37 pairs repaired for review, 119 unchanged, zero technical holds. Across all
156 pairs, the original GLB binary prefix, meshes, skeleton, animation and
node data are unchanged. The 18-variant targeted layer trial imported and
rendered in Godot with zero errors. Earlier 40-variant and 34-variant body
trials also imported and rendered with zero errors. The before/after page is
`.tmp/catalog-remaining-body-review-v2-2026-09-28/index.html`.

Self-review of the Godot renders found clear improvements for Litten,
Torracat, Magmar, Elekid, Jirachi, Chimchar, Monferno, Magmortar and Golett.
The 119 unchanged normal/shiny idle pairs were also scanned in ten contact
sheets under `.tmp/catalog-remaining-unchanged-audit-2026-09-28`; this did
not reveal another obvious neon or missing-body case at thumbnail size.
Brionne and Duraludon match their pinned normal/rare source colours, although
the studio lighting makes Duraludon's shiny difference subtle. Shiny Kommo-o's
yellow/pink colour matches the official rare albedo. These observations do
not approve the 156 pairs. The following are explicit visual holds:

- Blastoise: the eye remains too small/dark. A neutral sclera trial is retained
  separately in `.tmp/blastoise-sclera-eye-2026-09-28`; it is not selected in
  v6 because the eye still reads poorly in the camera.
- Primarina: a large spiky, cyan effect silhouette obscures the seal body.
- Incineroar: the raw mask emission still makes the belt pink/yellow; its
  six-layer source shader needs a dedicated reconstruction.
- Solosis and Reuniclus: their green transparent outer bodies are too dark;
  Reuniclus's shell is barely visible against the review background.
- Zekrom: the missing wing/back and tail sections received the subsequent
  source-opacity correction below; the corrected candidate still needs battle
  qualification.
- Dewpider: eye and bubble appearance are doubtful in the current render.
- Entei, Furret and Mudkip: user-reported eye appearance needs a closer
  battle-camera check; a clean material binding alone cannot clear them.
- Yanma: the reported apparent missing wing still needs a side-view motion
  check.

None of these GLBs updates the approved catalog, bundles or R2.

### Jirachi eyes and Zekrom back follow-up

`catalog_remaining_source_exceptions.py` is now called by the body-repair
batch for these two species, so regenerating the page retains the corrections.
The latest two-pair receipt is `.tmp/jirachi-zekrom-review/final/status.json`;
it supersedes only Jirachi and Zekrom in body v6. The browser comparison is
`.tmp/jirachi-zekrom-review/index.html`.

Jirachi's Biochao eye node group explicitly connects `eye_msk.Color` to
`Mask`, with a white mask colour. The generic eye bake omitted that final
highlight mix and used brighter TRMTR layer 2/3 colours than the original
Blender material. The focused repair restores the pinned source highlight,
the authored darker layer 2/3 values and roughness 0.5. It preserves the
official normal/rare layer 1 difference. Source blend and highlight hashes
are documented in the repair module; the highlight hash and material profile
are guarded. The read-only node inspection is retained locally in
`.tmp/jirachi-zekrom-review/{nodes,group}.json`.

Zekrom's source declares five body materials `Opaque`, but the GLB retained
albedo alpha on three of them, cutting holes through wings/back and turbine
sections. Only those five source-opaque materials are forced opaque; the
explicit `body_b_03` transparent effect and eye materials remain unchanged.
The invalid alpha multiplier on `body_b_01` is normalized to 1.

Both normal/shiny pairs were imported and rendered in Godot: 24 captures of
idle, both physical attacks, special attack, sleep and faint, with zero
reported errors. Visual inspection shows the eye highlights, solid wings/back
and connected tail shell; sleep still hides Jirachi's eyes. The final scripted
GLBs are byte-identical to the rendered trial. Nodes, meshes, skeletons,
animations and the original binary prefix are unchanged. This is source
appearance review evidence, not battle or release approval.

The user subsequently approved both corrected normal/shiny pairs with
"beide zien er goed uit". This appearance approval is recorded against the
four exact GLB/SCN hashes in
`catalog_remaining_jirachi_zekrom_appearance_review.json`. Jirachi's eyes and
Zekrom's wing/back/tail appearance are no longer open visual issues for those
versions. Their review placement was scale 1 with automatic camera framing;
battle scale, floor clearance through motion, both battle cameras and bundle
qualification remain outstanding.

### Jirachi and Zekrom battle calibration (2026-09-28)

The approved appearance hashes now also have completed candidate battle checks
in `catalog_remaining_jirachi_zekrom_battle_qualification.json`. Exact runtime
profiles are retained in `catalog_remaining_jirachi_zekrom_battle_profiles.json`;
these are candidate evidence, not additions to the production registry.

- Jirachi's scale increased from 1 to 2.3716752825: minimum idle screen height
  increased from 27.83 to 65.47 pixels in the measured 1920×1008 viewport.
  Zekrom keeps scale 1 (minimum idle height 290.20 pixels).
- Existing motion placement was baked from 60 Hz source bounds and independently
  checked at 120 Hz for eight clips in each normal/shiny scene. Minimum clearance
  across all samples is 0.025 world units. Native faint endpoints match.
- All 64 captures (four variants × two cameras × two sides × four actions) are
  fully in view, with no HUD-proxy overlaps. Assistant visual inspection found
  no new obvious clipping or missing corrected parts. Gallery:
  `.tmp/jirachi-zekrom-battle/index.html`, served at
  `http://127.0.0.1:8765/.tmp/jirachi-zekrom-battle/index.html`.
- The existing production-presenter stress test passed classic/stadium/classic,
  with both species normal/shiny and swapped, actual HUD checks, faint lifecycle,
  replacement, resource cleanup and cache checks. Candidate registry entries
  were injected only in memory in the isolated slot process. No production
  catalog was changed. p95 frames: 17.547 / 17.942 / 17.478 ms; maximum threaded
  dispatch/collect 2.33 ms; retained source cache 17,708,862 bytes; no uncovered
  stalls over 50 ms; last-round static growth 44,364 bytes.

The runtime log contains pre-existing scene-resource UID fallback warnings;
all resources resolve by path, with no script/load errors. This check does not
certify bundle installation, downloading or a release. Individual bundle
qualification and catalog integration remain; the other intake review holds
listed above are unaffected.

Local replay inputs, scripts, screenshots and reports are retained under
`.tmp/jirachi-zekrom-battle/` and pinned in the qualification receipt. Run
`calibrate.py` after the raw `phase5_battle_review.gd` pass, then repeat that
Godot script with `POKEAETHER_PHASE5_CANDIDATES` pointing to
`motion-candidates.json` and `POKEAETHER_PHASE5_BATTLE_OUTPUT` to `corrected`.
The phase-five review root is this folder and the runtime report is
`runtime.json`. Run `prepare_runtime_check.py`, then execute `runtime_check.gd`
with `POKEAETHER_BATCH01_RUNTIME_CATALOG` pointing to `runtime-catalog.json`,
`POKEAETHER_BATCH01_STRESS_OUTPUT` to `runtime-stress.json` and
`POKEAETHER_BATCH01_STRESS_NAMES=jirachi,zekrom`. All Godot invocations must go
through `ops/worktrees/slot-env slot-a`. `make_page.py` regenerates the gallery;
`write_receipt.py` validates hashes, placement, camera and performance gates
before regenerating the candidate receipts.

### Jirachi and Zekrom local bundle admission (2026-09-28)

The user approved the battle gallery with "zien er goed uit". The exact four
appearance hashes and preceding battle qualification hash are pinned in
`catalog_remaining_jirachi_zekrom_approval.json`.

Both species now have individual version-1 normal/shiny bundles, 37,109,245 bytes
combined (35.39 MiB), retained under `.tmp/jirachi-zekrom-bundles/bundles/`.
The two-entry asset index, archive hashes, object keys and installation evidence
are retained in `catalog_remaining_jirachi_zekrom_bundle_qualification.json`.
The launcher's transactional store installed each bundle, loaded all four SCNs,
and passed no-op planning and restart checks. A subsequent three-round production
presenter check used the installed catalog and the actual checked-in registry,
without candidate injection: classic/stadium/classic, both normal/shiny sides,
HUD separation, faint/replacement, cleanup and performance gates all passed.
Frame p95 was 17.352 / 17.349 / 17.100 ms. Resource UID fallback warnings remain
as in the earlier test; there were no script/load errors.

The game and launcher reviewed registries now include these four hashes and two
shared species profiles. Normal/shiny timing, bounds and placement were asserted
identical before sharing the profiles. Existing catalog entries are unchanged.
The prior appearance/battle receipts remain historical evidence; this bundle
receipt supersedes their pending bundle/catalog steps. The other intake review
holds remain open.

Reproduce with `tools/sprite_factory/package_jirachi_zekrom.py package`, run the
retained `install_check.gd` through slot-env with the launcher project, then run
`admit`. Run `tests/catalog_batch_01_candidate_stress_check.gd` against
`.tmp/jirachi-zekrom-bundles/installed/installed-catalog.json` with names
`jirachi,zekrom`, write `installed-stress.json` / `installed-stress.log`, and run
`finalize`. Packaging refuses an existing output; admission refuses already
registered identities. These phases are for replay from the pre-admission
revision, preserving the existing receipts and artifacts.

No public index or R2 objects have been changed. Release certification and
publication remain separate; the bundle receipt deliberately keeps
`release_approved=false` and `published=false`.

### Ten remaining visual holds — source reconstruction (2026-09-28)

The ten explicit remaining visual holds now have a single candidate gallery:
`.tmp/remaining-visual-holds/index.html`, served at
`http://127.0.0.1:8765/.tmp/remaining-visual-holds/index.html`.
The selected outputs are `final-stage.json`, `final-runtime-v3/report.json` and
`final-captures-v3/review.json` in that directory; earlier trial folders are
superseded. `catalog_remaining_visual_holds_review.json` pins the 20 exact
GLB/SCN hashes and evidence. These remain review candidates, not catalog entries.

- Blastoise, Furret, Entei and Mudkip: restore original Biochao eye albedo/mask
  pixels rather than newer SCVI atlas layouts. Their old eye albedos are fully
  white. Restore source-authored white highlights for Furret, Entei and Mudkip;
  keep the official normal/rare layer-colour differences. Dewpider's four eye
  materials also use their original source atlas. Blastoise retains its native
  narrow eye geometry; no eye mesh has been enlarged.
- Yanma: all four thin wing meshes existed, but their material was single-sided.
  Double-sided rendering restores the missing views. Ten additional side-view
  captures cover five idle moments for both variants.
- Primarina: the export displayed both loose and tied hair meshes. The reviewed
  proposal hides `hair_b` using the existing native visibility-track pack in all
  eight clips and RESET, preserving the animated ponytail. This is explicitly an
  artistic candidate, not a claim to decode missing original visibility data.
- Incineroar: reconstruct the four layer-mask colours plus the fifth mask layer
  and their authored emission, restoring the orange/yellow belt in both variants.
- Solosis, Reuniclus and Dewpider: reconstruct linear source layer colours and
  emission with original alpha, instead of multiplying sRGB colours into albedo.
  Independent RGBA mask channels are resized separately; ordinary premultiplied
  resizing erased red-channel data under zero alpha in an intermediate trial.
- Entei also had raw mask emission on its smoke and metal. The smoke now uses
  the original white/red-mask atlas with authored colours, and the metal uses
  the official low constant emission. The spurious red smoke is gone.

`catalog_remaining_visual_holds.py` reproduces these candidates from hash-pinned
inputs in `catalog_remaining_visual_holds_inputs.json`. Run it with `--work`
pointing to the retained work directory, `--materials` to the external SCVI
material dump and `--output` to a new directory. It refuses changed input files
and an existing output. Its 20 GLBs and all timing/visibility metadata reproduced
byte-for-byte. Meshes, skinning, skeletons, animation arrays and original binary
prefixes remain unchanged; Primarina's extra visibility is applied only during
standalone scene conversion.

All 20 scenes converted without errors. The 120 normal/shiny pose captures and
10 Yanma side captures rendered without errors. Assistant review inspected all
120 poses and compared Dewpider with the local source icon; no new obvious
artifacts were found at review scale. User approval, battle size/grounding,
bundle qualification and publication are still pending. Jirachi and Zekrom are
already locally admitted as documented above and are outside this ten-pair set.

## Reproduce or resume

Run the three scripts from the assigned frontend slot, passing its paired
backend, the Biochao archive directory and an output directory under `.tmp`:

1. `catalog_remaining_intake.py --frontend ... --backend ... --archives ... --output ... --probe`
2. `catalog_remaining_normal_export.py --inventory ... --probe-status ... --output ...`
3. `catalog_remaining_normal_runtime.py --export-status ... --frontend ... --slot-env ... --output ...`

All three write per-species receipts and resumable status files. They never
update `reviewed_model_catalog.json` or the launcher content index.
