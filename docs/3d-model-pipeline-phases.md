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

Evidence and remaining gaps:

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

### Phase 1B — next implementation checkpoint

Generalize the offline converter, integrate preflight, replace assertions and
silent skips with per-model failures, preserve distinct provenance hashes, and
publish complete output only after successful validation. Validate actual meshes,
material support and AnimationPlayer clips in Godot. Rebuild the approved pair
into a NEW output directory and compare before switching any configured catalog.
Do not overwrite the currently selected approved artifacts.

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
