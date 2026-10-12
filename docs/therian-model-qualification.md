# Therian models for the next model release

Landorus-Therian, Thundurus-Therian and Tornadus-Therian have distinct normal and
shiny models prepared locally. Neither the selected v13 index nor public R2
objects are changed by this task. The missing forms were absent from the older
catalog too; they were not removed by compression.

## Source and identity

`tools/sprite_factory/catalog_therian_source_intake.json` pins the native SCVI
`pm0641_12_00`, `pm0642_12_00` and `pm0645_12_00` geometry, material tables,
textures, source icons and eight motion pairs each. Source icons and rendered
forms were inspected by the assistant. Normal and rare material tables provide
their own palettes; the source geometry, rig, visibility clocks and animated eye
UVs are preserved. The importer is pinned to
`b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04`.

Runtime identities are `landorus-therian`, `thundurus-therian` and
`tornadus-therian`, with `@shiny` for their shiny appearances. The bundle convention
uses the complete form slug as `species_id` and `base` as `form_id`. None may
resolve to its Incarnate model. The old missing-form regression now uses the
synthetic `Landorus-Unknown` identity.

## Delivery and local evidence

The three immutable PCK candidates in `release/approved_3d_therian_index.json`
total **28,395,980 bytes**. The six original native scenes total 58,343,722 bytes;
the shared delivery saves 29,947,742 bytes (51.33%). Each pair shares identical
textures. Separate scenes retain their animated eye-material tracks; this task
does not bypass the geometry-sharing guard for material-sensitive animations.
Native resource compression uses Zstd level 19 and 256 KiB blocks. Decoded
resource bytes are checked exactly before and after recompression.

Evidence is retained under the task worktree's `.tmp/therian-models-v1/` and
pinned in `tools/sprite_factory/catalog_therian_qualification.json`:

- Six native scenes, each with eight source animations and complete pose channels.
- All 64 clip-to-clip switches per scene plus both idle/sleep blend directions;
  skeletal, visibility and material-UV state checked.
- Full-clock 60 Hz placement measurements and independent 120 Hz floor checks.
  All 168 battle snapshots fit both camera layouts without overlapping the HUD
  proxy. Tornadus and Thundurus hover; Landorus remains grounded.
- Independent pack installation, manifest/hash validation, native semantic
  equality and shared-texture lifetime checks for all three pairs.
- Exact source/shared rendered image, animation and sampled pose comparisons.
- Real presenter loading of all six appearances in classic and stadium, including
  normal/shiny swaps without another download. Both original native ZIPs and the
  final shared PCKs are exercised through the on-demand delivery service.

These are local Linux Godot 4.6.2 checks. They do not certify other operating
systems or constitute release certification. The first placement run ended
before completion; its partial output is retained in `battle/final`. Only the
complete `battle/final-v2` report is admitted. Render diagnostics explicitly force
GPU frames when the desktop compositor stops drawing a covered window. Candidate
catalog storage is initialized before its process-local fixture is installed;
the retained successful render report is `shared/render-qualified/report.json`.

The Therian tests and game/launcher catalog snapshot parity pass. The broader
`test_launcher_model_registry.py` suite has one pre-existing failure:
`test_manifest_validator_matches_game` expects identical validator source,
although the game now contains shared-pack binding logic absent from the old
launcher validator. This same comparison fails at the unchanged task base
`df040d0c348d506fa0b29316946f1b9b0c8eb9ae`. Neither validator is modified here;
this remains an issue for the separate release verification.

## Reproduction and release handoff

Use an assigned frontend slot and `ops/worktrees/slot-env`. The native source
drive and the pinned importer/dependencies must be available. Never copy Godot
caches or user configuration from another worktree.

1. Run `catalog_therian_models.py export`, `material`, then `stage` through the
   slot environment. A user Flatpak installation may require
   `FLATPAK_USER_DIR=/home/adinho/.local/share/flatpak`.
2. Convert `stage.json` with `prepare_battle_3d_runtime.gd`. Use an isolated minimal
   project with source-only links to `tools`, `scripts`, `resources` and `data`.
3. Render `catalog_dlc_runtime_review.gd`, check native transitions with
   `catalog_galar_birds_transition_check.gd`, measure placement with
   `catalog_mega_battle_review.gd`, calibrate with `expected_pairs=3`, and verify
   hover/floor/cameras with `catalog_therian_battle_review.gd`. Preserve source
   hashes and all eight source clocks.
4. Run the pair texture probe into the diagnostic project's own `.tmp`, then
   `catalog_therian_delivery.py packs` and `prepare`. Validate the resulting
   PCKs with `shared_model_catalog_probe.gd`; render with
   `catalog_therian_pair_render.gd`, then `catalog_therian_delivery.py pixels` to
   compare all source/repeat/candidate pixels.
5. Run `tests/battle_3d_therian_check.gd` with
   `POKEAETHER_FORM_BUNDLE_WORK` pointing to the absolute artifact directory.
   Repeat with `POKEAETHER_THERIAN_SHARED=1`. Both run against process-local
   candidate bindings; production pins stay unchanged.
6. Admit only complete matching evidence with `catalog_therian_delivery.py admit`.
   Recheck with `POKEAETHER_THERIAN_ADMITTED=1`, and run the focused Python registry
   tests plus the field-preview regression. `catalog_therian_delivery.py finalize`
   pins the successful admitted-registry log and the preparation/test code.

The next explicitly authorized model release must combine these **three new
pairs** with the 1,200 existing pairs, retain their full pinned manifests for
shared-pack resolution, and update the game/launcher release pins together.
The prior 1,200-pair compression audit does not cover these new additions; they
have their own evidence here. Upload and verify the immutable objects before
activating that new index. The retained PCK paths are
`.tmp/therian-models-v1/shared/packs/<object_key basename>` in the task worktree.
No old remote objects need deleting to add these forms.
