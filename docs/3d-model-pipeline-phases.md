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

Demand-driven preparation/cache, bounded eviction, first-use shader measurements,
and repeated switch tests. Preserve arena-only Team Preview and fallback behavior.
Measure CPU/GPU first-use separately from disk loading; no quality reduction by
default.

## Phase 5 — representative acceptance

Keep Dragonite and Roaring Moon as visual controls. Add reviewed assets covering
grounded biped, quadruped, small and large bodies. Select actual available models
at that checkpoint. Require import, placement, animation and repeated-battle
checks plus human visual approval before expanding the runtime allowlist.

Each checkpoint uses focused tests and local development integration only.
No new model support, deployment or full-batch certification is implied.
