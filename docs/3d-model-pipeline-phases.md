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
