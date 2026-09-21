# 3D model pipeline: phased implementation

## Baseline

Keep neutral lighting, the approved generic material response, existing model
resolution and source animation tracks unchanged. No species-specific lighting
adjustments. Keep sprite rendering available and independent. Audio/timing
should ultimately share one timeline; this audit does not claim that extraction
is already implemented.

## Phase 1 — import standardization

### Audit and preflight completed

The current path is source catalog/manifest → explicit Blender export job → PBR
GLB/report → offline Godot `.scn` conversion → separate grounding sidecar →
background runtime loading. Existing tools are reused, not replaced wholesale.

Evidence at the start of Phase 1A (converter gaps addressed in 1B below):

- `prepare_battle_3d_probe.py` selects from the study's species catalog, pins
  reviewed source metadata, and creates an explicit export job.
- `battle_3d_export_probe.py` checks source hashes, rejects linked libraries and
  unsupported animation layouts, translates materials, and checks exported
  action names. Material parity still requires visual review.
- `prepare_battle_3d_runtime.gd` preserves native tracks but silently skips all
  species except Dragonite/Roaring Moon. It uses assertions for errors and
  writes into an existing output directory. Generalize this in Phase 1B.
- Hash provenance is ambiguous: the export report's `source_sha256` identifies
  the Blender source, but runtime preparation overwrites it with the GLB hash.
  Phase 1B must preserve separate source/GLB/runtime hashes in a versioned
  contract, with migration compatibility for the current report.
- `experimental_battle_3d.gd` has a two-species allowlist and hardcoded 1.0/0.65
  scales. Expanding import does NOT automatically authorize runtime support.
- `export_arena_grounding.gd` asserts exactly two results and extends a review
  harness. Generalizing calibration belongs in Phase 2.
- Runtime catalog loading queues every supported catalog model. It is not yet
  a demand-driven large-catalog cache (Phase 4).

New read-only metadata/file preflight:

```sh
python3 tools/sprite_factory/validate_battle_3d_report.py /absolute/path/report.json
python3 -m unittest discover -s tools/sprite_factory -p test_validate_battle_3d_report.py
```

Checks include report shape, canonical/unique species IDs, absolute existing
GLB paths, GLB header/version/length, hash syntax, required action metadata,
positive finite timing and explicit loop flags. It is species-agnostic and
reports all detected errors. It does not import scenes, inspect embedded texture
references, verify Blender source hashes, or certify visual quality. A valid
preflight alone does not qualify a model for the game.

### Phase 1B — converter implemented

The offline converter now accepts all validated species IDs. It runs the Python
preflight before creating output, reports per-model failures instead of assertions
or silent skips, and requires a new absolute `POKEAETHER_3D_RUNTIME_OUTPUT` directory.
Godot checks mesh surfaces, StandardMaterial3D compatibility, one AnimationPlayer,
and non-empty clips. Reloaded scenes must retain scene structure, mesh counts,
clip lengths/loops and track paths/types/key counts. This is structural validation,
not a pixel-parity certificate or exhaustive shader/texture validation.

`source_sha256` preserves the exporter-provided Blender hash; `glb_sha256` and
`runtime_sha256` identify subsequent stages. `provenance_schema: 1` and converter
version 2 describe the extra metadata; `runtime_schema: 1` stays compatible with
the existing reader. The material-response embedding step refreshes the runtime
hash when it produces a new scene. Older catalogs remain readable unchanged.

All entries must succeed before a pending report is renamed to `report.json`.
Failed runs retain diagnostic JSON and any completed scenes in the new directory,
but publish no catalog. Do not select these diagnostic directories. Re-run into
a new directory; the converter never overwrites an earlier run.

The approved pair has been rebuilt separately, without selecting the output.
The GLB-to-scene output still needs material-response embedding, grounding and
visual review before it can replace the approved in-game artifacts. The runtime
allowlist and lighting are unchanged. An integration fixture renames existing
art only to prove the converter has no species filter; it does not add a Pokémon.

Run focused integration checks through slot-env with `POKEAETHER_3D_STAGE_REPORT`
set to an existing GLB report:
`python3 tools/sprite_factory/test_prepare_battle_3d_runtime.py`.

## Phase 2 — placement

### Phase 2A — runtime metadata checkpoint

New converter output includes `placement: {scale, yaw_degrees}`. Runtime
placement and summon scaling consume these fields rather than species branches.
The two legacy asset defaults are isolated in `model_placement.gd` solely for
backward compatibility. No currently selected artifact has been rewritten.

Grounding sidecars still use schema 1. Each entry binds `sha256`, `scale`, `lift`
and optionally `yaw_degrees` (legacy default zero). Hash, scale and yaw must all
match before lift is accepted; stale calibration retains the existing fallback
behavior. Invalid authored placement is rejected. This checkpoint does not
recalibrate the approved pair or expand the runtime model allowlist.

### Phase 2B — pose-sweep measurement completed; action placement review remains

`tools/sprite_factory/measure_model_grounding.gd` is a model-independent offline
measurement pass. It reads a prepared runtime catalog, samples every declared
clip at 60 Hz after rendered skin transforms update, and reports minimum world Y
and time per clip. It proposes a nonnegative resting lift from idle only, keeping
existing authored flight height, then verifies idle at half-frame offsets.
It records hashes/scale/yaw and writes three candidate idle views per model.
It refuses headless execution and an existing report target. It never writes a
runtime grounding sidecar or changes the selected catalog.

Through slot-env, set `POKEAETHER_3D_STAGE_REPORT` to the prepared runtime report
(not the source GLB report), and `POKEAETHER_GROUNDING_REVIEW_OUTPUT` to a new
absolute JSON filename in an existing review directory. Run:
`godot --path FRONTEND --script res://tools/sprite_factory/measure_model_grounding.gd`.
Screenshots are geometry/placement reviews with neutral lighting, not a complete
material-response render or visual-quality acceptance test.

Measured the approved pair and independently rebuilt pair: seven clips per model.
Candidate idle lifts reproduce the existing approved sidecar within 0.000001:
Dragonite 0.019324 and Roaring Moon 1.472313 (world units). Half-frame minimum
clearance is 0.025011 / 0.025489, respectively. Candidate idle front/side/rear
views were generated; front Dragonite and side Roaring Moon were visually checked.
The analytic animated-box test checks world scale/yaw, a known minimum, the idle
lift and exclusion of attack motion from resting lift.

The report also finds below-floor poses with idle-only placement: Dragonite's
faint minimum is about -0.371, physical attack -0.060 and sleep -0.077; Roaring
Moon damage -0.044 and physical attack -0.032. Roaring Moon sleep has a very
different root-height regime. These are measurements, not automatic corrections.
Next: inspect the implicated poses and define generic per-action/root-motion
placement semantics before adopting corrections. A single larger global lift
would make other poses float. Fainting may intentionally settle onto the ground;
this requires action-aware treatment. The approved idle calibration remains active.

Local evidence: slot-c `.tmp/grounding-phase2b-01.json` (rebuilt scenes),
`.tmp/grounding-phase2b-02.json` (approved scenes) and adjacent PNGs.
Focused rendered check: `tests/model_grounding_measurement_check.gd`.

### Phase 2C — problem-pose review and correction policy

`review_grounding_poses.gd` reproduces each negative-clearance pose and sleep,
checks its minimum against the sweep (0.002 world-unit tolerance), and captures
current versus diagnostic constant-per-clip placement at 0/90/180 degrees.
The approved pair reproduced all eight selected poses with no errors; 48 images
were produced in slot-c `.tmp/pose-review-phase2-01`, with a machine-readable
`review.json`. Side comparisons of Dragonite physical attack/faint and Roaring
Moon damage/sleep were inspected. These images isolate placement, not final
material-response quality or transition smoothness.

Conclusions and next implementation contract:

- Idle: retain approved placement exactly.
- Attack/damage: preserve authored flight/motion; propose a nonnegative,
  time-dependent floor-clearance correction only where posed geometry requires
  it. A constant whole-clip offset is diagnostic only. Do not lower airborne
  attacks onto the ground. Blend/transition behavior requires motion testing.
- Sleep: require explicit per-clip ground/flight intent in asset metadata,
  with independent resting calibration. Roaring Moon's inspected sleep pose is
  lying down; reusing idle flight lift leaves it suspended about 1.44 units too
  high relative to a ground-resting interpretation. Do not infer all sleep
  clips are grounded merely from the action name.
- Faint: define continuity between faint_start and faint_loop, retaining authored
  descent. Dragonite's problematic foot is visible after diagnostic lifting,
  but this does not certify a natural landing. Treat as its own transition,
  not a damage clip or instant global height replacement.

No corrective offsets were enabled in the game. Next checkpoint is baking
reviewable per-action clearance curves and explicit resting intent, followed by
animated before/after tests (including sleep entry/wake and faint transitions).
Keep shared sound/timing and neutral lighting unchanged.

To reproduce through slot-env, set `POKEAETHER_3D_STAGE_REPORT` to the prepared
catalog, `POKEAETHER_GROUNDING_REVIEW_INPUT` to its measurement JSON and
`POKEAETHER_POSE_REVIEW_OUTPUT` to a NEW absolute directory, then run
`godot --path FRONTEND --script res://tools/sprite_factory/review_grounding_poses.gd`.

Define per-asset scale/orientation/ground or flight metadata; remove hardcoded
species scales. Calibrate across relevant animation poses, not just idle. Verify
feet/tails, surfaces, both sides and camera angles without lighting changes.

### Phase 2D — runtime action clearance and resting intent

Implemented in `model_motion_placement.gd`, with baked profiles in
`reviewed_motion_placement.json`. Profiles bind to the exact runtime SHA-256,
calibrated idle lift, scale, yaw and clip durations. Mismatches safely retain
existing placement. No runtime geometry readbacks are introduced.

Physical/special attacks and damage use nonnegative, 60 Hz clearance envelopes;
the animation player's own clock selects the offset, including playback speed.
Idle remains unchanged. Explicit `grounded_rest` sleep intent is approved for
these two reviewed lying poses. Downward changes ease to the resting height;
upward corrections cannot lag below floor clearance. No clip timing, sound,
lighting, source model or 2D/2.5D animation changes are made.

Rebuild only from a successful rendered measurement containing
`minimum_y_samples`, using `tools/sprite_factory/bake_motion_placement.py REPORT
NEW_OUTPUT --grounded-sleep dragonite roaring-moon`. The baker refuses overwrite;
review and independently test the resulting profiles before replacing tracked
data. The sleep list is explicit, not inferred for newly imported species.

Evidence: slot-c `.tmp/grounding-motion-01.json`, `motion-render.log` and
`motion-presentation.log`. Independent half-frame rendering checks all eight
affected clips (minimum clearance 0.02980 world units). Focused helper and baker
tests cover interpolation, provenance rejection, invalid samples and settling.
The real client presentation test passes three battle/switch cycles.

Per user request, 3D faint now retains the actor: `faint_start` transitions to a
looping `faint_loop` until replacement/teardown. An older catalog without that
clip holds the final faint-start pose. Idle/status updates cannot wake a fainted
actor; explicit replacement, including the same species, resets the lifecycle.
Faint **placement/landing** is not recalibrated in this checkpoint and still
needs moving visual review. Shared audio extraction remains future work.

### Phase 2 completion — reviewed pair

Phase 2 is complete for the exact reviewed Dragonite/Roaring Moon runtime
assets. The same hash/scale/yaw checks apply to the added faint profiles.
`faint_start` now receives conservative floor clearance; its last 0.2 seconds
approach the fixed `faint_loop` correction. The root stays steady throughout
the loop, including wrap. The source's drooping/flying faint poses are retained:
this is not a newly authored belly-on-ground animation.

Final evidence (slot-c `.tmp`):

- `motion-final-seams.log`: all 12 corrected clips pass independent half-frame
  skinning checks (minimum clearance >= 0.02980 units). Whole-mesh faint joins
  differ by <= 0.000038 units. Chronological idle/sleep/wake/attack/faint/repeated
  loop sweeps pass at 30 Hz, both 1x and 4x playback with runtime settling.
- `motion-final-review-03/` and `motion-final-review-04/`: visual pose sheets, both models, eight sequences,
  five moments each from front, side and raised rear cameras. Inspected feet,
  tail clearance, sleeping rest and faint join/loop. Dragonite sleeps seated;
  Roaring Moon uses its flattened resting pose. Wake restores native idle
  directly; a new authored wake-up clip or crossfade is phase-3 animation work,
  not required for calibrated placement.
- `motion-final-client.log`: real battle presentation regression, including
  persistent faint, cancellation, same-species replacement, replay, material
  synchronization and repeated teardown. This is not a performance certificate;
  concurrent diagnostic GPU readbacks can inflate recorded frame times.

The visual-sheet tool is `tools/sprite_factory/review_motion_sequence.gd` and
requires the reviewed catalog plus a NEW `POKEAETHER_POSE_REVIEW_OUTPUT` folder.
Earlier review attempts 01/02 contained capture-format/crop errors and are not
acceptance evidence. No lighting, sound, clip duration, 2D/2.5D behavior or
runtime species allowlist changes are included. Other assets must get their
own measurements and visual review; phase 5 still owns broader model acceptance.

## Phase 3 — animation mapping

### Phase 3A — shared contracts implemented

`animations/model_action_map.gd` now owns native clip selection, native duration
and speed metadata, forced faint-loop repetition and the explicit physical ↔
special fallback. Other missing actions keep the current pose; unknown actions
never select arbitrary clips. The existing realtime presenter uses this map.
No asset-name alias schema or new source clips are introduced.

`animations/battle_sound_timeline.gd` extracts source/custom audio cues without
textures, nodes or audio playback. `take_frame` preserves legacy duplicate keys,
custom defaults/order, source-event disabling, volume and pitch. The existing
2D/2.5D MoveAnimationPlayer now uses it. `compile` exposes one traversal's source
duration and cue timestamps, respecting start/end frames and FPS; timestamps
are unscaled, for a future playback-speed-aware driver.

Focused checks: `tests/battle_animation_contract_check.tscn` verifies selection,
invalid metadata, cue dedup/reset, cropped frame ranges and actual legacy-player
parity for Outrage, Dragon Dance, Roost, stat up/down and health up (nine cues).
The routing fixture still confirms no sprite-catalog/VFX access in 3D, correct
miss callbacks and cancellation. Three real-client 3D battle cycles pass.
Evidence: slot-c `.tmp/phase3-parity.log`, `phase3-routes.log`, `phase3-client.log`.

**At the phase-3A checkpoint**, 3D did not yet play this shared audio timeline.
Phase 3B below connects an audio-only driver with generation-scoped cancellation,
speed/pause handling, single event ownership (no duplicate audio), sound-only
resource preparation and tests for differing native clip/source durations.
Preserve the native model clip timing rather than silently stretching it to a
sprite sheet. No shared clock or 3D sound playback is claimed by phase 3A.

Explicit clip mappings and fallbacks for idle, physical/special attack, damage,
sleep and faint. Preserve source timing; extract shared audio/event timing
separately from 2D versus 3D visual drivers. Test cancellation and playback speed.

### Phase 3B — audio-only realtime driver connected

`battle_audio_catalog.gd` compiles shared catalog source/custom cues into cached
audio-only plans (including effect aliases and configured speed). It reads JSON
metadata only; no sprite sheets, backgrounds or foreground resources are loaded.
`battle_audio_player.gd` owns each timeline and its AudioStreamPlayers. It
dispatches frame-zero/overdue cues once, handles speed changes and zero-speed
pause/resume, and keeps source pitch/volume independent of replay speed.

The router prepares only audio streams through its existing threaded cache.
First-use preparation precedes cue dispatch, is generation-checked, and has a
1.5-second ceiling; unavailable sounds remain optional and do not block battle
progress. Cancel invalidates pending preparation, stops active streams, clears
ownership and releases waiters. Presenter fallback/teardown also invalidates the
audio lifetime. Global scene pause uses inherited Node processing.

3D moves start the audio timeline alongside native motion. The beat waits for
**both**, not one after the other. Its length is the maximum of remaining native
motion and source audio duration: source cue timestamps are identical, but total
3D move duration need not equal 2D when the native clip is longer. Native clips
are neither stretched nor truncated. Miss callbacks follow completion and stay
suppressed on cancellation. Effects (including stat and healing catalogs) use
audio only until native visuals are added. Unknown entries remain silent.

Focused evidence under slot-c `.tmp`: `phase3b-audio-final.log` (clock, pitch,
pause/cancel and unequal lifetimes), `phase3b-cold.log` (real first-use streams,
no visual loader calls, routing/cancellation), `phase3b-contract.log` (legacy cue
parity), and `phase3b-client-ready.log` (three client battle cycles). Audio mixer
teardown is allowed to drain before isolated tests quit. No source animation,
2D/2.5D driver timing or damage authority was changed. Broader first-use/cache
performance remains phase 4; bespoke 3D move VFX remain separate work.

## Phase 4 — loading and memory

### Phase 4A — bounded prepared-resource reuse

An in-process LRU retains at most two self-contained PackedScenes, admitted
within a 64 MiB serialized-source budget. This is **not** a decoded RAM/VRAM
ceiling. It holds no actors, battle nodes, viewports or UI. Normal battle teardown
can reuse the resources; a running presenter leaving 3D clears the cache.
Eviction releases only the cache's reference, not resources owned by active actors.

Each catalog read hashes the actual scene bytes once for both placement checks
and cache identity. Identity includes path and canonical animation timing metadata
because native animation lengths/loop flags are configured at runtime. Scenes
with external dependencies are not admitted. A cold threaded load rechecks the
hash before publication to reject files changed during loading.

The real prepared pair cache test measured 475 ms cold versus 118 ms on each of
two repeated resource preparations (headless, excluding arena, shader warmup and
rendering). Repeated imports were zero; fresh catalog/hash validation still cost
about 117 ms. Retained serialized source size stayed at 37,713,540 bytes.
`tests/battle_model_cache_check.gd` covers identity, LRU/admission limits, resource
ownership and three actual pair loads. The presentation check also asserts warm
reuse between presenters and cache release on mode exit.

Focused evidence: slot-c `.tmp/phase4-cache.log`, `phase4-client-final.log`
(three rendered battle cycles, final action p95 17.3 ms; post-cleanup static
memory 387,769,568 → 387,799,524 → 387,806,496 bytes), and
`phase4-progress.log` (progress watchdog still rejects a true stall). First-load
frame spikes up to about 1.4 s remain; no whole-battle latency gate is claimed.

This checkpoint still loads the entire approved two-model catalog. Demand loading,
larger-catalog policy and first-use CPU/GPU/shader performance remain below; it
does not promise instant first battles or eliminate arena reconstruction.

### Phase 4B — demand loading and acceptance (approved pair)

Catalog indexing now reads metadata only. Model hashing, calibration, motion
validation and scene requests happen only for the eligible active pair. Empty
Team Preview requires no model import/hash work; unsupported pairs request no
new scenes. Duplicate species share one resource but instantiate separate actors.
Requests not yet started are removed when demand changes; a running threaded
request is collected safely. Cancelled preparation drains without publishing.
Failed imports or a file changing during import are rejected once per catalog,
not retried every frame.

Each presenter retains only currently needed packed resources after resolving
its actors. The shared two-entry/64 MiB **serialized-source** admission policy
remains; active actors and an in-flight import can hold additional resources.
This is not a whole-process RAM/VRAM cap. Battle-local validated entries form a
snapshot: switching back neither rehashes nor changes the model version halfway
through battle. A new battle/catalog reload validates source bytes again.

Existing lead/switch release routes already await preparation. The await now
rechecks pending work and resolved actor identities before allowing release, and
retiring actors cannot handle actions for a newly selected species. Hidden
summon models stay hidden. No networking, battle authority, sound timing,
native tracks, art quality, or supported-species allowlist was changed.

Preparation diagnostics separate catalog indexing, model validation, threaded
scene loading, arena construction, actor construction and render warmup.
Blocking pipeline deltas are ordered canvas/mesh/surface/draw; background
specialization is deliberately not a readiness blocker. The existing opaque-cover
warmup requires five drawn frames with stable pipeline counts/viewport/actors
and reuses the same viewport after reveal. Wall-clock warmup is not GPU time.

Focused acceptance (`tests/battle_model_demand_check.gd`, slot-c
`.tmp/phase4-demand-final.log`, Godot 4.6.2 Forward+, RTX 3070 Laptop):

- Three stadium lifecycles, each starting with empty Team Preview, then a
  supported single lead, the pair, and three round trips between duplicate
  Roaring Moon actors and Dragonite/Roaring Moon. Hidden summon, recall,
  resource reuse, unused-resource pruning and weak-reference cleanup asserted.
- Empty previews: zero imports/validation; index below 1 ms. First observed
  preview approximately 270 ms versus approximately 170 ms repeats. These are
  observed timings, not budgets or a cleared-driver-cache benchmark.
- Repeated switches perform no new scene import or hash validation. The warmed
  pair reports zero new blocking pipelines during its final readiness sample.
- Separate engine viewport measurements after warmup: main-pass GPU maxima
  around 2.7–3.3 ms, response-pass GPU maxima around 1.4–1.6 ms. CPU timings are
  reported independently. Viewport measurements exclude other UI/world work;
  do not sum their maxima into a total-frame claim.
- Video memory stayed at 775,901,376 bytes at the same checkpoint. Post-teardown
  static memory was 160,768,542 → 160,802,526 → 160,812,334 bytes with the shared
  model cache deliberately retained (well below the 1 MiB growth guard).
- Cancellation and simulated stale validation reject without cache publication;
  original assets were not modified. The bounded-cache test and progress
  watchdog remain separate regression checks.
- `phase4-final-client-02.log`: three full battle-presentation cycles including
  forest, native actions/faint, substitute fallback and mode-exit cleanup pass.
  Final action p95 was 17.3 ms; first-load frame spikes still reached 1.44 s.
  Post-cleanup static memory was 387,818,136 → 387,849,772 → 387,857,832 bytes.

Phase 4's loading/cache/measurement baseline is complete for the approved pair.
First arena construction and first-use validation still take time; this is not
an instant-first-battle promise or low-end hardware certification. Driver/Godot
caches were not deleted or copied. Phase 5 must repeat resource/performance
acceptance for representative new models before increasing the allowlist or
changing cache capacity. A large-catalog preload strategy is not enabled.

## Phase 5 — representative acceptance

### Phase 5A — explicit ten-case source inventory

The agreed cohort is committed in `tools/sprite_factory/phase5_review_batch.json`:
Pikachu, Arcanine, Lucario, Snorlax, Onix, Articuno, Abra and Gastly, plus the
unchanged Dragonite/Roaring Moon controls. Model IDs are source IDs, not Pokédex
numbers (Roaring Moon uses pm1089). No 2D camera/light/scale overrides are inherited.

Read-only local inventory evidence: slot-c `.tmp/phase5-inventory-02/inventory.json`.

| Candidate | Source result | Required action candidates | Shiny source |
| --- | --- | --- | --- |
| Pikachu | SCVI | 7/7 | material files present |
| Arcanine | SCVI | 7/7 | material files present |
| Lucario | SCVI | 7/7 | material files present |
| Snorlax | SCVI model; motions absent from current dump; Gen1 Blend candidate | unverified | SCVI material files present |
| Onix | Gen1 Blend candidate; no current SCVI model/motions | unverified | unverified |
| Articuno | SCVI | 7/7 | material files present |
| Abra | Gen1 Blend candidate; no current SCVI model/motions | unverified | unverified |
| Gastly | SCVI | 7/7 | material files present |
| Dragonite (control) | SCVI | 7/7 | material files present |
| Roaring Moon (control) | SCVI | 7/7 | material files present |

Presence is not visual or animation-semantic approval. The report records exact
motion candidates, alternatives, material-channel companions and archive member
identities. Archive listing does not verify Blender contents, textures, rig or
clips. No source extraction, substitutions, rendering, runtime model registration,
variant approval or modifications to approved controls occurred in 5A.

Reproduce with `phase5_inventory.py --model-root MODEL_DUMP --motion-root
ROMFS/pokemon/data --legacy-archive Gen1.zip --output NEW_DIRECTORY`.
Output must be new. Unit checks cover the explicit cohort/source ID and ensure
archive membership cannot grant animation/shiny/visual approval.

Next, 5B must inspect both source routes and create the cheap review catalog for
all available candidates before refining any individual model. Missing motions
stay explicit blockers, never invented mappings. Compare idle and representative
poses, eyes/materials, facing/scale, grounded versus intentional floating, long
bodies/wings, battle camera and HUD framing. Fix generic failures across the
whole cohort first; only anatomical exceptions belong in manifest data.

5C then covers approved normal/shiny variants where available, mixed teams of
six, duplicates, faint/replacement, repeated switches, real cache eviction/reload
and multiple battles. 5D enables only separately approved models/variants.

### Phase 5B — first breadth-first source review

`phase5_source_review.py` imports the seven available SCVI candidates with the
existing pinned importer and renders five representative samples each: idle
front/back, special-attack midpoint, sleep midpoint and faint-start endpoint.
Two Blender subprocesses run at most; per-entry failures do not erase other
results. It extracts only each explicitly inventoried legacy member into new
review output, checks ZIP CRC before creating a Blend file, and never rewrites
source archives. Blender opens sources with scripts disabled and read-only file
access, no network, and does not save modified sources. Fresh output is required;
`--prepared-from` validates and reuses this tool's earlier imports read-only.

Evidence: slot-c `.tmp/phase5-source-review-02/index.html`, `catalog.json`,
`contact-1.png`, `contact-2.png`, per-species `review.json` and 35 pose images.
The initial `-01` attempt retained import artifacts and failed review diagnostics;
the corrected `-02` render reuses those imports without copying them.
`phase5_review_gallery.py` can regenerate the static gallery. No new model is
enabled in the game. This is a **source-material Blender review**, not the
Godot material conversion, battle framing/HUD or full motion-grounding gate.
The known controls are freshly imported diagnostic references, not replacements
for their approved runtime resources.

All cases use the same neutral lights, view directions and native coordinates.
Cameras auto-fit a common per-model bound across the sampled poses; this does
not establish relative battle scale. XYZ extents and per-pose minimum heights
are recorded, without moving floating models onto an assumed floor. These five
samples do not prove full-cycle contact or mapping correctness.

Observed issues before any per-model polish:

- Pikachu's idle visibly has closed eyes while the sampled attack opens them.
  Import diagnostics also flag inherited idle eyelid tracks for Arcanine,
  Lucario, Articuno and the raw Roaring Moon import. Solve inheritance through
  the common import contract; do not introduce arbitrary species eye rotations.
- Gastly renders as an opaque dark sphere with no readable face/gas silhouette.
  Its source import contains body, eye and smoke meshes. Transparency/shader
  interpretation needs investigation; the image alone does not establish which
  material node is responsible. No smoke deletion or species workaround applied.
- Every imported case reports unapplied TRACM material channels. Material and
  facial animation parity therefore remains unapproved even when a static pose
  looks reasonable. No conversion was silently certified.
- Abra, Onix and Snorlax are explicit blocked rows. Python ZIP reading fails
  with bad local headers; `unzip -t` confirms bad offsets for the exact three
  members, and `7z t` reports unexpected archive end. Listing the central
  directory in 5A was not evidence of extractability. An intact archive or
  alternate explicit sources are required. Snorlax's SCVI model/material source
  remains available, but its motions are missing from the current motion dump.

The source review tools have focused failure/isolation/gallery tests. Generic
material/eye corrections, the three missing source reviews, Godot review scenes,
shiny review, and phase 5C/5D remain outstanding. No player-facing change is made
by this tooling checkpoint.

Require import, placement, animation and repeated-battle checks plus human visual
approval before expanding the runtime allowlist. Phase 5B–5D are not complete.

Each checkpoint uses focused tests and local development integration only.
No new model support, deployment or full-batch certification is implied.

### Phase 5B — recovered Gen1 sources

The replacement Biochao archive, now at
`/home/adinho/Documents/3d_models/Biochao/Gen1.zip`, passes ZIP integrity checks.
The inventory/review tools accept either exact root-level `pmNNNN_00.blend`
members or the earlier `Gen1/` layout, reject ambiguous layouts, and compare
inventoried CRC and size before extraction. No source archive is rewritten.

Evidence: slot-c `.tmp/phase5-inventory-03/inventory.json` and
`.tmp/phase5-source-review-04/index.html`, its two contact sheets and per-species
reports. All ten cases now produce source review reports: 48 pose images total.
The earlier `-03` run retains diagnostics from the coarse action-name matcher.
The final `-04` run uses token-delimited primary action names, preventing
`attack01` from selecting `rangeattack01` and `down01` from selecting `jumpdown01`.
Sleep uses the loop rather than arbitrarily choosing among start/loop/end clips.
Ambiguous or absent matches remain explicit; this is not a runtime mapping change.

- Abra: 16 actions, one rig, packed texture, readable sampled front/back,
  special attack and faint endpoint. Idle retains its floating source height.
  No identified physical attack, sleep or faint-loop clip; one hashed action
  still needs motion review before concluding that those behaviors are absent.
- Onix: 23 actions, one rig and five packed textures. Sampled long-body poses
  remain visible with the auto-fit review camera; this does not certify battle
  camera/HUD fit. No identified sleep/faint-loop clip; four hashed actions need
  review. Sampled bounds extend slightly below source zero (faint about -0.091).
- Snorlax: 48 actions, one rig, four packed textures, all seven primary action
  categories identified, including true faint start/loop. Five sample poses
  render successfully. The sampled sleep minimum is about -0.102 source units;
  floor/contact handling still needs the animation-placement gate. An unused
  empty texture node is reported, not a missing active texture.

Embedded text blocks remain disabled. No missing external textures or linked
libraries were reported for these three. Facing/shape/materials were visually
inspected in the neutral source renders, not certified for Godot. No source
geometry, floor offsets or species overrides were changed. Existing Gastly
material and SCVI eyelid/TRACM issues remain, as do shiny, full-motion and battle
reviews. The source-file blocker is resolved; phase 5B and 5C/5D are not complete.

### Phase 5B — deterministic skeletal pose evaluation

Evidence in `.tmp/phase5-source-review-05/` supersedes the closed-eye conclusions
from the earlier sample sheets. Blender retains values from the previous action
when the next action omits a bone/channel. The saved imports ended on faint
loops; assigning idle alone therefore leaked closed eyelids into Pikachu's idle.
The Biochao Snorlax also retained an open mouth from previously evaluated clips.
Resetting all pose bones to rest before selecting each clip fixes both visible
cases without species overrides, donor motions or changes to source files.
Explicit sleep/faint tracks still evaluate normally; this is not an eyes-open
override. Omitted source tracks alone are not proof of closed bind-pose eyes.

`blender_action_state.select_action` now supplies that deterministic setup for
the source-review pose/bounds passes and fresh SCVI import bound measurements
and configured donor sampling. Existing prepared imports, 2D sprite renders,
GLB exports and approved runtime artifacts are not rewritten. Cached older
import reports still contain their old bound measurements; do not treat them
as regenerated evidence. New reports identify the rest-before-clip policy.

Focused Blender regression `check_blender_action_state.py` reproduces the stale
unkeyed-track bug, verifies that reset removes it and preserves explicitly keyed
motion, and evaluates the ten-model cohort in reverse order after poisoning the
pose. All 195 start/mid/end samples have zero matrix difference against the
forward pass. This proves order independence of sampled skeletal transforms,
not material animation parity or full-cycle grounding. The 48 rendered poses
were visually checked in the two new contact sheets. A fresh Pikachu source
import in `.tmp/phase5-rest-import-01/` also passes with the corrected bound pass.

Gastly remains held, not cosmetically patched. Its raw TRMTR declares `body`
as `Standard/Opaque`, eyes as `EyeClearCoat` + `Eye/BlendPreMultiAlpha`, and
`smoke` as `NonDirectional/Opaque`. The pinned importer uses a common shader
group; merely forcing alpha blend is not justified by this source metadata.
The rendered shell still hides the readable face/smoke silhouette. Shader and
TRACM interpretation need a separate causal correction; no smoke mesh has been
deleted or hidden. Abra/Onix hashed clips, Godot conversion review, shiny and
phase 5C/5D remain outstanding. No runtime allowlist or battle UI changes.

### Phase 5B — layered material causal probes (not a finished Gastly shader)

The raw Gastly TRMTR specifies `NonDirectional`, five material layers, two UVs,
`EnableDisplacementMap=True`, texture `pm0092_00_00_smoke_msk` and height about
0.3. The pinned importer reads these values but does not wire displacement.
Its generic shader only uses albedo alpha for surface opacity; the layer-mask
alpha contributes to colour, not smoke transparency.

An isolated, scripts-disabled inspection of the Biochao Gen1 Gastly reference
shows a surface/transparent mix driven by layer-mask alpha (surface at 0,
transparent at 1), plus animated procedural geometry nodes. That authored
reference is evidence for a useful opacity hypothesis, not proof of exact
SCVI displacement semantics. No reference scripts were executed or materials
copied into game assets. Diagnostic extraction remains at slot-c
`.tmp/gastly-shader-tT1Li6/`.

`scvi_material_probe.py` reads the relevant TRMTR metadata and offers an
explicit opt-in probe for this shader signature, not a species-name override.
`phase5_source_review.py --layer-mask-probe` adds the mask-alpha transparent
mix in memory, retaining the original shader nodes and all meshes. With
`--displacement-probe` it additionally tests a static UV2 normal displacement
using the original texture and height, with an explicitly unverified 0.5
midlevel. Texture SHA checks, dedicated two-UV mesh checks and duplicate-apply
rejection guard the probe. No Blend saves, source rewrites, runtime enables or
automatic visual approvals occur. Ordinary review without flags is unchanged.

Evidence against `.tmp/phase5-source-review-05/`:

- `.tmp/phase5-material-probe-01/`: opacity-only, face becomes visible through
  the remaining spherical shell.
- `.tmp/phase5-material-probe-02/`: opacity + displacement hypothesis, shell
  develops a non-round outline but remains too dark/static for approval.
- Both runs render all ten models / 48 samples. Only Gastly's five images
  differ; the other 43 images are pixel-identical to the baseline.
- Focused tests cover signature rejection, malformed input and explicit probe
  gallery labelling. `check_scvi_material_probe.py` runs inside Blender for
  both actual Gastly jobs and verifies preserved native vertices, polygons,
  visibility and original nodes, unchanged unrelated materials, correct mask
  socket wiring, duplicate rejection and unchanged source hashes.

The gallery labels these as experimental, not native source shading. This
checkpoint establishes a causal opacity correction and a displacement probe,
not the final shader. NonDirectional lighting, animated UV/TRACM interpretation,
verified displacement behaviour and Godot representation remain unresolved.
Do not promote this probe to the runtime converter based on these stills.

### Phase 5B — auxiliary material-loop probe

The battle-idle TRACM animates eyes, not smoke. The separate SCVI file
`pm0092_00_00_28201_loop01_loop.tracm` supplies smoke `UVScaleOffset` and
`UVScaleOffset3`: 121 frames at 60 fps, with matching endpoint keys for a
two-second texture cycle. The narrow `scvi_uv_probe.py` reader follows the
[TRACM schema](https://github.com/pkZukan/PokeDocs/blob/master/SV/Flatbuffers/animation/tracm.fbs).
It accepts only reviewed constant/affine channels and rejects unsupported
interpolation metadata, ambiguous tracks and incomplete endpoints.

`--ambient-material-probe` requires the previous displacement probe and adds
an explicitly experimental unlit source-colour shader. The UV1 mask / UV2
displacement association remains a hypothesis, not established game parity.
The source UVs remain unchanged: displacement uses a third local UV layer.
No source files are saved and nothing is enabled in the runtime converter.

Evidence in slot-c `.tmp/phase5-material-probe-03/`:

- All ten models render; the 43 non-Gastly stills are pixel-identical to
  `.tmp/phase5-source-review-05/`.
- Twelve distinct Gastly frames isolate material motion with the skeleton
  frozen. The gallery includes a looping WebP preview.
- Blender checks pass for movement, wrap/repeat evaluation, native UV and
  geometry preservation, unrelated materials and unchanged source hashes.
- 27 focused Python tests cover the decoder, probe guards, animated gallery
  labelling and existing source-review/import tooling.

Visual review still rejects Gastly: the moving shell obscures the face and
does not yet establish the intended smoke appearance. This is reproducible
diagnostic evidence, not a finished shader. Next resolve mask/UV/displacement
semantics before Godot conversion and battle certification. Phase 5B remains
open; the runtime allowlist is unchanged.

### Phase 5B — smoke occlusion isolation

`review_smoke_ablation.py` compares the four combinations of culling on/off
and displacement on/off. All use the same source, loop samples, lighting and
camera bounds (fitted once from the baseline). Each variant starts by reopening
the source; no mesh is removed or hidden. Reports retain the actual pose bounds
separately from the fixed diagnostic camera bounds. The ordinary review path
still fits its camera as before.

Evidence in slot-c `.tmp/phase5-smoke-ablation-02/`: 68 images, consisting of
five poses and twelve material-loop samples per variant. Culling changes pixels,
but is not a sufficient visual correction. Disabling displacement also leaves
the face obscured by the shell. Neither hypothesis is promoted to the converter.
All seventeen culling-on/displacement-on images match the previous material-loop
probe exactly: culling was already active there. It is not a missing switch.

An untouched, scripts-disabled Biochao Gastly reference is rendered separately
in `.tmp/phase5-smoke-reference-01/` (five matching named poses). It too shows
smoke obscuring the face in this review setup. Its framing is independently
auto-fitted, so this is a qualitative source comparison, not a pixel-parity
test. The authored reference therefore cannot serve as an automatically
approved replacement or proof of the desired final appearance.

`check_scvi_material_probe.py --ablation` verifies all four intervention states,
unchanged native geometry/visibility and unrelated materials, in addition to
the loop and source-hash checks. The 27 focused Python tests remain passing.
No runtime models or source Blend files are changed. Gastly remains held:
further shader work needs a trusted visual target and verification of opacity,
UV and displacement semantics. Continue the other cohort reviews independently
rather than treating this unresolved material as permission to guess a fix.

### Phase 5B — nine-model Godot conversion review

`phase5_godot_review.py` consumes the complete hash-pinned source-review catalog,
holds Gastly explicitly, and exports the other nine into a new disposable
directory. It rejects changed sources, duplicate/incomplete cohorts and material
probe inputs. Export failures stay per-entry blockers, and return a failing
exit status without erasing successful cases. No source Blend is saved.

`phase5_godot_export_worker.py` exports only identified canonical clips at the
source frame rate, with bone resets during glTF sampling. Missing actions are
never invented: Abra lacks identified physical attack/sleep/faint-loop; Onix
lacks identified sleep/faint-loop. Each GLB has its own hash and limitations.

The generated Godot project has no game autoloads or runtime registry. Run the
standalone `phase5_godot_review.gd` through `ops/worktrees/slot-env slot-c --`,
with `POKEAETHER_PHASE5_REVIEW` pointing to that project. It verifies GLB hashes,
imports scenes, checks durations, samples start/middle/end geometry, and checks
midpoint skeletal poses again in reverse clip order. Before each clip it stops
playback and resets skeleton poses, avoiding unkeyed eye/mouth pose inheritance.
Screenshots preserve native coordinates, using an auto-fit camera; they do not
certify battle scale, floor contact, floating height, HUD or battle-camera fit.

Evidence in slot-c:

- `.tmp/phase5-godot-review-01/`: direct-export baseline. All nine load, but the
  SCVI complex shader graphs translate incorrectly (purple/normal-map-like
  surface colours). Baseline pose switching also exposes stale eye/mouth state.
- `.tmp/phase5-godot-review-02/`: optional `--scvi-pbr-probe` reuses the existing
  albedo/normal/roughness bake for all six matching SCVI importer graphs. Three
  Biochao models retain direct translation. Mixed supported/unsupported graphs
  fail instead of silently applying partial material conversion.
- Godot 4.6.2 Compatibility on AMD Radeon Graphics: nine models, 58 clips,
  174 geometry samples and 58 reverse-order midpoint checks, zero reported
  import/timing/geometry/order errors. Every clip changes skeletal pose between
  the sampled start and midpoint. Forty-three pose PNGs and `index.html` support
  visual review. All nine idle front views were inspected: recognisable colours
  return, Pikachu has open idle eyes, and Snorlax no longer inherits an open mouth.
- 31 focused Python tests pass; Godot script check and rendered batch pass.
  The existing export-probe module is now import-safe so its bake can be reused;
  its standalone CLI remains available.

This is still diagnostic conversion, not material parity: the SCVI bake samples
idle colour and does not port animated material channels, source alpha/emission
or stylised lighting. Controls are fresh comparison exports, not replacements
for approved Dragonite/Roaring Moon assets. Normal variants only; no runtime
allowlist, placement calibration or production assets changed. Next review
battle placement/framing and unresolved mappings before phase 5C stress tests.

Reproduce export with `python3 tools/sprite_factory/phase5_godot_review.py
SOURCE_REVIEW/catalog.json NEW_OUTPUT --scvi-pbr-probe`; then run Godot with
`--path NEW_OUTPUT --script ABSOLUTE_PATH/phase5_godot_review.gd` via slot-env.
Build the HTML with the same Python command plus `--gallery-only` after Godot
has written `godot-review.json` (omit `--scvi-pbr-probe` for the direct baseline).

### Phase 5B — battle-scale, floor and camera measurements

`arena_framing.gd` now owns the existing spawn positions, two camera presets
and 48-degree FOV. The runtime arena catalog delegates to it without changing
values. The standalone `phase5_battle_review.gd` loads that same small contract
and `model_placement.gd` in the autoload-free diagnostic project; no arena
assets, game sessions or production services are loaded. The arena contract
test checks all previous positions, targets and FOV explicitly.

Evidence: slot-c `.tmp/phase5-battle-review-03/battle-review.json`, `summary.json`
and `index.html`. The first `-01` run has equivalent measurements but lacks the
final completion/provenance fields. The `-02` repeat stalled waiting for a
normal render-frame signal and was terminated without deleting its evidence.
The diagnostic now explicitly draws frames after processing pose updates,
rather than waiting indefinitely when ordinary window draws pause. Its engine
log is explicitly slot-local. Reports are marked unapproved and partial
runs remain incomplete. Source catalog, framing script, placement script and
GLBs are hash-identified. `phase5_battle_summary.py` refuses partial runs and
inconsistent sample counts/clearance, and never writes runtime calibration.

All 58 available clips across nine models were sampled at 60 Hz (8,184 pose
samples including clip endpoints). Candidate lift is derived only from the
lowest idle geometry, with 0.025 clearance, never by moving floating models
down. Scale remains the current defaults: 1.0, or 0.65 for the Roaring Moon
control. There are no species-specific new scale or offset overrides.

There are 136 representative screenshots: both sides, both shared camera
presets, idle/attack/sleep/faint where available, against a Dragonite control.
The stage is a flat floor, not the real forest/cave/sea/stadium geometry. Cyan
labels and conservative projected bounds approximate the current fixed-height
HP anchor; this does not certify the actual HUD, its collision resolution,
camera orbit or terrain/ceiling occlusion.

Findings at 1152×648:

- Sampled shots stay inside the viewport, but Pikachu is only about 22–32 px
  tall. Its current HUD proxy sits 114–146 px above its bounds. Native scale
  alone therefore does not establish readable battle presentation.
- Onix overlaps the fixed-height HUD proxy in all four idle and all four
  attack views. Roaring Moon also overlaps it slightly in two classic idle
  views. Use model-derived presentation bounds rather than one three-unit
  height for every species; do not solve this with arbitrary HUD offsets.
- Abra retains its native floating motion: candidate lift 0, lowest idle
  geometry about 0.065 above the floor. Articuno's full idle loop needs a
  candidate lift about 0.531, which the earlier three-pose sample missed.
- An idle-only lift is insufficient during other clips for every case. For
  example Snorlax sleep still reaches about -0.095; Onix faint about -0.108;
  Articuno damage about -0.450. Reuse and validate the existing per-clip motion
  clearance pipeline before runtime acceptance, with sleep intent reviewed
  explicitly. The fresh control exports have no approved runtime motion
  profiles applied, so their penetrations are not a regression claim about
  currently approved in-game assets.

Focused arena-contract and placement tests pass, as do 36 relevant Python
tests and the rendered measurement run. Phase 5B remains open: next address
model-derived HUD bounds and readable small-model scale, then bake/review
motion clearance. Gastly, missing Abra/Onix mappings, shiny and 5C remain held.

Run via slot-env in the generated Godot project with `--script
ABSOLUTE_PATH/phase5_battle_review.gd`, `POKEAETHER_PHASE5_REVIEW` pointing to the
conversion output, `POKEAETHER_PHASE5_FRONTEND` to the task frontend and
`POKEAETHER_PHASE5_BATTLE_OUTPUT` to a new directory. Then run
`python3 tools/sprite_factory/phase5_battle_summary.py NEW_DIRECTORY`.

### Phase 5B — closing review and 5C handoff

5B is the breadth-first **review gate**, not runtime certification. The closing
pass applies review-only presentation candidates and records an explicit
eligible/held decision for every member of the ten-model cohort. A held model
is not silently substituted or approved. Runtime enablement remains phase 5D.

`phase5_candidates.py` provides three reproducible stages:

1. `prepare BASELINE_REPORT NEW_READABILITY_JSON`: derives one minimum-size
   rule from all four idle views (both sides of both shared cameras). Models
   below 66 pixels receive a proportional multiplier, capped at 4; larger
   models keep their previous scale. This is a readability floor, not a rule
   making all species equally tall. The closing gate requires at least 60 px
   after perspective is measured again at 1152×648.
2. Run `phase5_battle_review.gd` with the same inputs as above and
   `POKEAETHER_PHASE5_CANDIDATES=NEW_READABILITY_JSON`. It records every raw
   60 Hz minimum and uses posed geometry for the HUD proxy instead of the
   fixed three-unit anchor. Then `bake SCALED_REPORT NEW_CANDIDATES_JSON
   --candidates NEW_READABILITY_JSON` reuses `bake_motion_placement.py`.
   Pikachu, Arcanine, Lucario, Snorlax and Dragonite have explicitly reviewed
   grounded sleep intent; flying models retain native sleep elevation. Idle
   floating height is never lowered automatically. A faint endpoint mismatch
   becomes a per-model blocker instead of being hidden by an offset.
3. Run the Godot review again with `NEW_CANDIDATES_JSON`. It verifies model,
   scale, yaw, lift and clip duration against the **actual runtime motion
   resolver**, and evaluates its interpolated offsets at 120 Hz, including
   the half-frames absent from the bake input. `close CORRECTED_REPORT
   NEW_DECISIONS_JSON --candidates NEW_CANDIDATES_JSON` checks provenance,
   complete cohort/view/sample coverage, clearance, readability and HUD-proxy
   overlap. Missing data cannot become an eligible decision.

All Python subcommands take positional `stage report output`; outputs are
exclusive-create. Render directories must also be new. Candidate files and
reports remain `runtime_approved: false`. Sources, action tracks, playback
duration, sounds, approved control assets and runtime allowlists are unchanged.
The motion helper now uses a relative sibling preload so exactly the same
resolver can run in the autoload-free review project; its behavior is unchanged.

This resolves the **review candidates**, not the game HUD: posed vertex baking
is intentionally an offline measurement, never a proposed per-frame gameplay
operation. 5C must bring approved candidate profiles and cached presentation
bounds into its isolated battle harness and test the real HUD, lifecycle and
cache paths before anything can be enabled. No full UI, camera-orbit, arena
geometry, material parity or shiny certification is implied by this flat-floor
normal-variant review. Animated material channels still need their own visual
acceptance; the SCVI PBR export remains an explicitly limited conversion.

#### Recorded closing result

The retained evidence is slot-c `.tmp/phase5-battle-review-04` (resized baseline),
`.tmp/phase5-readability-01.json`, `.tmp/phase5-candidates-01.json`, and
`.tmp/phase5-battle-review-05` (corrected report, decisions, summary, HTML and
136 PNGs). [phase5b-review-decisions.json](phase5b-review-decisions.json) preserves
the closing decisions, model hashes, candidate/report provenance and metrics
in the repository; it is not a runtime manifest.

- All 58 available clips on nine models pass the independent 120 Hz check:
  **16,278 poses, no measured floor penetration**. The lowest clearance is
  about 0.02225. All 136 representative views fit the viewport and avoid their
  own HUD proxy; all four idle views have a 12 px HUD gap.
- Pikachu's candidate scale is 2.97717, Lucario's 1.11771 and Abra's 1.66548.
  Their smallest measured idle heights are 65.59, 65.79 and 65.64 px. Other
  scales are unchanged. These are reproducible outputs of the shared rule,
  not new hard-coded species offsets. Abra keeps lift zero and native float.
- Representative corrected images were visually inspected across the cohort,
  including the resized small models, sleeping quadruped/large models, long
  Onix, flying Articuno and faint/sleep control poses. This supplements the
  earlier source/eyes/material/order review; it does not certify every frame
  aesthetically or remove the documented material limitations.
- **Eligible for normal-variant 5C:** Pikachu, Arcanine, Lucario, Snorlax,
  Articuno, Dragonite and Roaring Moon. The last two are comparison exports;
  their existing approved runtime assets are untouched.
- **Held:** Gastly (layered smoke obscures the face; shader semantics unresolved),
  Abra (physical attack, sleep and faint loop unidentified), Onix (sleep and
  faint loop unidentified). Their blockers remain required follow-ups before
  they can join certification; no invented action aliases or hidden meshes.
- 48 focused Python tests pass, as do `model_placement_check.gd`,
  `model_motion_placement_check.gd`, `battle_arena_contract_check.gd`, both
  rendered review runs, UID-sidecar checks and `git diff --check`.

**5B is closed with explicit holds.** Next is 5C: integrate the eligible review
candidates into the isolated battle test path, then exercise mixed teams of
six, duplicates, repeated switches, faint-to-replacement, cache eviction and
reload, successive battles and available shiny variants. Held models do not
block testing the eligible group, but must not be counted as certified. No
complete development gate, runtime rollout, promotion or deployment is part
of this 5B closure.

### Phase 5C — normal-cohort runtime and replay stress baseline

The first 5C block brings the seven eligible normal candidates into the actual
immersive battle scene. This is **not yet complete 5C or permission for 5D**:
normal/shiny variant certification and frame-stall acceptance remain open.

`phase5_runtime_prepare.gd` requires the exact committed 5B decisions and
hash-matching source catalog, corrected measurements and motion candidates.
It reuses the existing SCN converter, preserving native tracks and verifying
the saved/reloaded scene signature and self-contained dependencies. Only the
seven eligible entries are published into a new external review directory.
Grounding/motion profiles are rebound to the verified SCN hashes. Cached
per-action envelopes are converted to local space once; no skinned vertex
baking is performed during the battle test.

The production presenter has three narrow virtual override points for species
support, catalog admission and motion profiles. Defaults retain exactly the
existing two-species normal-only allowlist and shipped motion data. The
test-only `phase5_candidate_stage.gd` overrides these from the 5B decisions,
projects cached envelope corners for the real HUD, and is never selected by
Settings or instantiated by normal battle code. No new models are released.

`phase5_battle_stress_check.gd` mounts the real battle screen/UI and swaps only
the presenter. It exercises:

- Three successive battles (Classic, stadium, Classic), with two mixed teams
  of six including duplicates and 36 switch iterations.
- All seven species as independent actors on both sides: 21 duplicate checks,
  21 faint-loop/same-species replacement checks, plus stale faint cancellation.
- Actual two-entry shared LRU eviction followed by disk reload, actor resource
  independence, warm reuse, bounded presenter resources and weak-reference
  teardown checks. Cache capacity remains two entries / 64 MiB source bytes.
- The actual immersive HP HUD using candidate bounds, with settling and
  overlap assertions for both combatants and screenshots of both arena types.
- Three recorded event sequences through `setup_battle_replay` and
  `play_replay_frame`: move/damage, Pikachu slot 0 → Pikachu slot 5, faint loop,
  Arcanine replacement, and battle end. Pokemon keys, health and presenter
  lifecycle are asserted. No live server or player/session data is used.
- Safe pair fallback for unreviewed shiny models. This is **not** shiny art or
  normal/shiny cache-key certification; the source inventory finds rare albedo
  for the eligible cohort, but reviewed shiny GLBs are still needed.

The replay exposed a real typed-array error in `immersive_portraits.gd` when
appearance state is empty. Initializing the typed array separately fixes both
fallback-art rebuilding and clearing; a focused regression covers both cases.

Retained slot-c evidence: `.tmp/phase5-runtime-01` (prepared scenes/catalog),
`.tmp/phase5-stress-01` (direct lifecycle baseline), `-02` (replay exposed the
portrait error), `-03` (corrected replay), `-04` (frame metrics), and `-05`
(final context-labelled frame metrics). The final log has no script errors.
[phase5c-normal-stress.json](phase5c-normal-stress.json) retains the final report.
Godot 4.6.2 Forward+ ran on the RTX 3070 Laptop GPU; no driver/cache purge was
performed. Existing scene UID fallback warnings remain, using valid paths.

Final measured normal-core results:

- All lifecycle, real-HUD, eviction and replay assertions pass.
- Frame p95: 17.38 / 17.37 / 17.41 ms; maxima: **549.61 / 185.27 / 144.59 ms**.
  Peaks are labelled in the report, principally initial pair loading, with a
  96 ms first replay-frame peak. Screenshot readback is excluded. These are
  whole-client intervals, not proof of a model-import-only or GPU-only cause.
  Actor construction totals are only 15–17 ms per round; stadium construction
  totals about 111 ms. Further causal profiling is required before acceptance.
- Shared retained source bytes: 19,143,466 after each direct stress sequence.
  After-teardown static memory grows only 7,404 bytes between the final two
  rounds, passing the 1 MiB guard. This is not a total RAM/VRAM budget claim.
- The existing approved-pair cache regression passes (cold then two warm
  cycles), as do motion placement and the two focused empty-appearance checks.
  The 48 relevant Python checks pass. The legacy full trainer-staging script
  has an already-existing source-text assertion expecting the old VS portrait
  call spelling; both the old test and changed call predate this task. Its
  unrelated failure was not suppressed or used as a passing result. Run the
  new regression alone with `POKEAETHER_TEST_IMMERSIVE_EMPTY_ONLY=1`.

Reproduction, always through `ops/worktrees/slot-env slot-c --`:

1. Run Godot headless with `--script res://tools/sprite_factory/phase5_runtime_prepare.gd`;
   set `POKEAETHER_PHASE5_REVIEW` to the 5B GLB directory,
   `POKEAETHER_PHASE5_MEASURED` to its closing battle-review JSON,
   `POKEAETHER_PHASE5_CANDIDATES` to its candidate JSON, and
   `POKEAETHER_PHASE5_RUNTIME_OUTPUT` to a new directory.
2. Run rendered Godot with `--script res://tests/phase5_battle_stress_check.gd`;
   set `POKEAETHER_PHASE5_RUNTIME_REPORT` to the prepared `report.json` and
   `POKEAETHER_PHASE5_STRESS_OUTPUT` to a new directory. Use an explicit slot-local
   `--log-file` and a 240-second process timeout. Check exit status, the
   completion marker/report **and** absence of `SCRIPT ERROR` / `ERROR:` in
   the log; Godot can otherwise continue after an assertion or callback error.

Next 5C work is to isolate the first-use/replay frame peaks, review and prepare
available shiny variants, and then test normal/shiny identity and cache
separation. Gastly/Abra/Onix remain held at 5B. No full paired certification,
allowlist expansion, promotion, push or deployment was performed.

Compatibility follow-up: development advanced with immersive HUD changes.
It was merged into the task (only the changelog required conflict resolution,
preserving both sets of entries), and the full focused normal stress/replay
run was repeated as `.tmp/phase5-stress-06`. All functional assertions and
the memory guard pass again, with no script errors. Frame p95 is
17.34 / 17.33 / 16.94 ms and maxima are 554.26 / 188.93 / 148.06 ms; the same
performance caveat remains. Final-two-round retained static growth is 4,180
bytes. The archived JSON above remains the instrumented `-05` baseline.

### Phase 5C — variant qualification and asynchronous integrity checks

The closing matrix extends the eligible cohort to **seven normal/shiny pairs**.
The six SCVI shiny sources are imported using the same pinned importer and
official rare materials, then exported through the same limited PBR path.
Snorlax retains its reviewed Biochao rig and animations: its embedded normal
albedo is compared pixel-for-pixel with the official normal image before the
official rare albedo is bound. Normal/rare material metadata must otherwise
match. Source Blend files are never saved or recoloured.

`phase5_variant_parity.py` requires exact equality of scene transforms, meshes,
skin data and every geometry/animation accessor payload. Material/image changes
alone may differ. All seven pairs pass, allowing the existing measured bounds,
placement and motion corrections to transfer with a new runtime-file hash.
`phase5_variant_runtime.gd` creates separate, self-contained candidate scenes;
the production allowlist still admits only its original normal controls.
The candidate presenter uses a separate resource identity for shiny without
changing the gameplay species or sharing an actor/AnimationPlayer.

The extended stress matrix checks both normal→shiny and shiny→normal swaps,
independent simultaneous actors, shiny faint→replacement, invalidated faint
callbacks, actual eviction of both variants followed by reload, and three
successive battles. It retains the normal mixed teams, real immersive HUD,
recorded move/damage/duplicate-slot/faint/replacement/end sequence and bounded
two-entry/64-MiB-source LRU checks. This is offline client qualification, not
live-network/PvP authority certification or a release of the candidate art.

Load profiling identified synchronous integrity reads on the main thread:
initial demand validation and the post-threaded-load hash check. Both now run
in a WorkerThreadPool job that accesses only files, never scene/UI objects.
The main thread polls, joins only completed tasks and publishes resources only
after the second hash matches. Cancellation detaches a drain; no cancelled job
can publish into its old presenter/cache. Preparation readiness includes the
preflight job, not just the ResourceLoader request. File limits, hash checks,
motion/placement validation, cache size and native animation timings remain.
`model_validation_ms` now measures worker elapsed time, not a main-thread block.

The actual screen-host preparation fence is retained in the stress adapter
(`ExperimentalBattle3D` node name). Covered arena/UI construction is recorded
separately from gameplay. Replay setup and first-event playback also have
separate frame boundaries: the old harness labelled their combined cost as a
first-move hitch. Screenshot runs remain visual evidence, not final performance
evidence; GPU readback can perturb a later frame even after PNG writing stops.
Use `POKEAETHER_PHASE5_CAPTURE=0` for the independent performance run.

`phase5c_acceptance.py` checks a complete seven-pair matrix, clean runtime log,
35 shiny review poses, exact geometry/motion proofs, memory retention and the
runtime catalog hash. Its explicit local regression guards are p95 ≤20 ms,
main-thread model dispatch/collection ≤one 60-Hz frame, and no uncovered
gameplay interval >100 ms. Covered entry and replay construction remain in the
report, rather than being represented as smooth gameplay. These guards do not
promise hitch-free rendering, instant startup or a decoded RAM/VRAM ceiling.

Retained source/visual evidence in slot-c:

- `.tmp/phase5-shiny-01`: seven source exports, exact texture provenance,
  Godot review with no pose errors, and 35 images. Front views were visually
  inspected for colour, face/eyes and intact anatomy. Geometry and motion use
  the stronger exact-data comparison rather than another approximate fit.
- `.tmp/phase5-variant-runtime-02`: fourteen candidate scenes/catalog entries,
  calibration and all seven parity proofs. Normal scenes are referenced in
  place; no caches or unrelated ignored assets were copied.
- `.tmp/phase5-stress-07`: diagnostic spans, recorded while source export was
  also running; not an isolated performance baseline.
- `.tmp/phase5-stress-08` and `-09`: normal/shiny lifecycle and replay-context
  diagnosis. `-10` adds explicit normal+shiny eviction/reload and screenshots;
  it retains a large uncovered outlier and is not the no-readback acceptance run.

Reproduce after preparing the normal 5C catalog: run `phase5_shiny_review.py`
with `--normal` and a new `--output`, then its `--legacy-model` Snorlax step.
Render `phase5_godot_review.gd` against that output. Run
`phase5_variant_runtime.gd` with the normal report, shiny review directory and
new runtime output. Run the stress script against the combined report, with
capture disabled for performance. All Godot commands use the assigned slot
wrapper, explicit slot-local log paths and bounded process timeouts.

The headless demand test is unsuitable for stadium shader assertions (dummy
renderer errors); the rendered demand test is the relevant regression, including
empty preview, warm reuse, cancellation during hashing/loading and stale-hash
rejection. Do not treat an OK marker accompanied by script errors as a pass.

**5C is closed for these seven normal/shiny pairs**, with the original three
5B holds unchanged. [phase5c-qualification.json](phase5c-qualification.json)
is the closing decision and retains hashes of the complete evidence. Raw stress
reports deliberately do not self-approve the phase; the separate acceptance
step combines lifecycle, variant review and performance evidence.

Final no-readback run: `.tmp/phase5-stress-11`, Godot 4.6.2 Forward+ on the
RTX 3070 Laptop GPU, without purging driver caches:

- Three battles; 36 mixed-team switches; 21 normal duplicate/faint checks;
  21 normal/shiny swap/faint/eviction/reload sequences; three recorded replays.
- Frame p95 **17.38 / 17.33 / 17.42 ms**. Main-thread load dispatch/collection
  maxima **1.97 / 1.93 / 2.16 ms**, down from repeated tens-of-ms synchronous
  integrity work. This is a callback measurement, not total load latency.
- Total frame maxima **450.06 / 135.75 / 97.97 ms**, all during covered entry.
  One uncovered Arcanine loading interval still reaches **98.15 ms**; first
  replay construction takes 78.28 ms (94.63 ms whole frame). These residuals
  are retained explicitly: this is not a claim that all startup/UI/GPU hitches
  are solved. The prior screenshot run's 824.69 ms outlier is not erased or
  used as performance acceptance evidence; readback-free qualification is
  intentionally a separate run.
- Final-two-battle static growth **85,076 bytes**, under the 1 MiB guard.
  Shared retained source bytes remain **19,143,466**; cache limits unchanged.
- The final rendered log has no script errors. All seven shiny diagnostic
  reviews have no pose errors; exact normal/shiny geometry/motion parity passes.

Focused regression evidence also includes the real approved-pair cache test,
rendered demand/cancellation/stale-hash tests, and 56 Python checks covering
review, parity, source intake and fail-closed qualification. Candidate assets
remain outside normal Settings/runtime admission. Next is **5D**, separately
selecting and enabling qualified models; Abra, Onix and Gastly remain disabled.
No full paired verification, main promotion, push or deployment was performed.

The rendered approved-pair immersive presentation regression also passes all
three cycles (`phase5-async-presentation.log`, final action p95 17.40 ms),
including material response and mode-exit cleanup. Motion placement passes,
and the preparation watchdog rejects the deliberate stall after 304 ms
(`phase5-final-motion.log`, `phase5-async-progress.log`). Existing UID fallback
warnings remain; none of these final logs contain script errors.

### Phase 5D — qualified models in the regular presenter

The regular desktop 3D presenter now admits the seven qualified **normal/shiny
pairs**: Pikachu, Arcanine, Lucario, Snorlax, Articuno, Dragonite and Roaring Moon.
Abra and Onix remain held for animation mapping; Gastly remains held for its
material/shader requirements. Unreviewed forms, doubles, substitutes and the
existing unsupported field presentations retain their 2.5D fallback.

`reviewed_model_catalog.json` is checked-in approval data: exact runtime hashes,
deduplicated placement/grounding, motion corrections, action timing and visual
bounds. The presenter validates the actual bytes asynchronously before scene
import. External catalogs cannot override these profiles or forge validation
and cache state. Duplicate identities fail closed. Normal and shiny identities
have distinct resources; HP/HUD placement uses the reviewed pose bounds.
The original two-normal-model catalog remains supported for compatibility.
No sound, native animation timing, cache budget or personal Settings change is
part of this admission.

Generate the registry or a selectable catalog using
`tools/sprite_factory/phase5_runtime_admission.py QUALIFIED_REPORT` (add
`--catalog-only` for the catalog). The tool requires the exact catalog pinned
by `phase5c-qualification.json`, verifies scene/grounding/motion hash agreement
and equal normal/shiny profiles, and prints JSON without copying assets.

Local review setup: in Settings choose **3D (experimental)** and use
**Choose local 3D model catalog…** to select slot-c's
`.tmp/phase5d-model-catalog.json`. This points to the existing scenes under
`.tmp/phase5-runtime-01` and `.tmp/phase5-variant-runtime-02`; retain those
directories. It is an explicitly selected local catalog, not bundled game art,
an automatic download, a release, or a change to another user's settings.
Packaging/installation of model assets is still a separate next step.

The stress harness's `POKEAETHER_PHASE5_PRODUCTION=1` mode delegates admission,
identity, motion and bounds to the real presenter, without candidate overrides.
Final no-readback run `.tmp/phase5d-stress-02` passes the same 5C lifecycle and
performance guards: three battles, 36 mixed-team switches, 21 normal duplicate/
faint checks, 21 variant swap/faint/eviction/reload checks and three replays.
P95 frame times are **17.91 / 17.31 / 17.31 ms**; main-thread load callbacks peak
at **2.44 / 2.03 / 1.82 ms**. Final-two-round static growth is **51,500 bytes**.
Covered entry still reaches **500.62 ms**, and replay construction has a
**98.53 ms** whole-frame interval. This is not an instant-start or hitch-free
guarantee, nor live PvP network certification. See
[phase5d-runtime-admission.json](phase5d-runtime-admission.json) for evidence
hashes and measurements. Prior 5C evidence remains unchanged and historical.

Focused regressions: 62 Python tests pass, including the new admission-builder
tests. `reviewed_model_admission_check.gd` verifies all fourteen identities and
rejects held/forms, duplicates, missing files, wrong hashes and forged cache
state. The original-pair real cache test, rendered demand/cancellation test and
three-cycle immersive presentation test also pass (`phase5d-cache.log`,
`phase5d-demand.log`, `phase5d-presentation.log`). All final logs have no script
errors; the existing asset UID path-fallback warnings remain. Development
integration does not certify the full release batch or authorize deployment.

### After 5D — portable local model packaging

The seven normal/shiny pairs now have a reproducible ZIP pack and a staged,
hash-verified local installer. The game reads its portable catalog relative to
the selected file, but takes approval, motion and placement exclusively from
the checked-in registry. The installed scenes no longer reference the temporary
review/export directories. Legacy catalogs remain compatible.

See [3d-model-packs.md](3d-model-packs.md) for build/install commands, limits,
engine compatibility, local artifact hashes and Settings selection. This step
does not add downloads, publication or launcher Mods integration. Those are
separate distribution work; no new species or variant is approved here.
