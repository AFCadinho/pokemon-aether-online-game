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

Define per-asset scale/orientation/ground or flight metadata; remove hardcoded
species scales. Calibrate across relevant animation poses, not just idle. Verify
feet/tails, surfaces, both sides and camera angles without lighting changes.

## Phase 3 — animation mapping

Explicit clip mappings and fallbacks for idle, physical/special attack, damage,
sleep and faint. Preserve source timing; extract shared audio/event timing
separately from 2D versus 3D visual drivers. Test cancellation and playback speed.

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
