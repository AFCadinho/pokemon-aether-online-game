# Urshifu Rapid Strike 3D model

The selected v13 collection contains `urshifu` and `urshifu@shiny`, but no
`urshifu-rapid-strike` identity. The battle API supplies `Urshifu-Rapid-Strike`;
the presenter's exact-form support check therefore falls back to 2D. This task
prepares the missing normal/shiny pair for the next model release. The active
v13 index and existing Single Strike bindings are unchanged.

## Native source and animation correction

`tools/sprite_factory/catalog_urshifu_source_intake.json` pins the extracted SCVI
resource catalog and 48 model/material/motion files. The resource table explicitly
maps National Dex 892, form 1 to **`pm0983_12_00`**; form 0 uses `pm0983_11_00`.
Internal model IDs are not National Dex numbers. Both palettes use their own
native material tables and the pinned SCVI importer
`b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04`.

The pair retains idle, two physical attacks, special attack, damage, sleep,
faint-start and faint-loop animations. Source pose channels, animated eye UVs
and dynamic mesh visibility are retained. Assistant inspection covers the normal
and shiny appearance, Rapid Strike stance, attacks, sleep and fainting poses.

The first transition test exposed a native animation playback issue: replaying
`physical_attack_2` could retain the previous teeth mesh. The source switches
between default/clenched teeth at 0, 0.05 and 1.25 seconds. A candidate-only
converter changes visibility tracks from discrete events to continuous nearest
state sampling. Every source key, timing, mesh, material and other animation
track is preserved. No shared runtime code or existing model is changed.

`catalog_urshifu_source_contract.gd` independently verifies that this visibility
sampling mode is the only semantic change from the original native conversion.
The transition test checks 64 clip switches per appearance, both idle/sleep
blends, and **14,784 reverse-clock visibility states at 120 Hz** against the
original source keys. No pose or visibility tolerance is relaxed.

## Compact delivery and verification

`release/approved_3d_urshifu_index.json` holds one shared-texture PCK, including
normal and shiny, of **12,215,440 bytes**. The two self-contained native scenes
total 21,290,978 bytes. Resource compression uses Zstd level 19 and 256 KiB blocks;
decoded bytes are checked for exact equality. Eye-material animations remain in
their own scenes. Texture sharing preserves the native resource semantics.

The qualification receipt is `tools/sprite_factory/catalog_urshifu_qualification.json`.
Its evidence stays in the retained task worktree under `.tmp/urshifu-models-v1/`.
Checks cover native conversion/reload, source preservation, animation transitions,
60 Hz placement measurements, independent 120 Hz floor clearance, both camera
layouts, shared-pack installation/lifetime, 24 pixel-exact source/shared frames, 56 battle screenshots,
and the actual on-demand presenter in classic and stadium. The presenter check
includes normal/shiny Team Preview, active battle loading, cached appearance
swaps, an unknown-form rejection and a wrong-hash rejection.

The diagnostic wrappers join the autoload cache-maintenance worker before
replacing process-local catalog bindings, avoiding a test-fixture race. The
actual consumer continues to use its normal background installation checks.

These are Linux Godot 4.6.2 checks, not cross-platform or full release
certification. Initial `runtime`, `appearance` and `battle/baseline` artifacts
are retained as diagnostics. The admitted sources are `runtime-v2` and
`appearance-v2`; placement uses `battle/baseline-v2` and `battle/final`.

## Reproduce and hand off

Use an assigned frontend slot and `ops/worktrees/slot-env`; never synchronize
caches, configuration or user data. Native sources stay on the source drive.

1. Run `catalog_urshifu_models.py export`, `material`, then `stage`. The importer
   and dependencies must be available in the slot. A user Flatpak installation
   needs `FLATPAK_USER_DIR=/home/adinho/.local/share/flatpak`.
2. Convert the stage with the generic native converter into `runtime`, then
   `catalog_urshifu_runtime.gd` into `runtime-v2`. Run the source contract and
   transition scripts against those pinned reports.
3. Review appearance with `catalog_urshifu_appearance_review.gd`. Measure battle
   placement with the existing Mega sampler, calibrate with `expected_pairs=1`
   and hover zero, then use `catalog_urshifu_battle_review.gd` for final checks.
4. Run the texture-sharing probe into the diagnostic project's own
   `.tmp/texture-pairs-v2`. `catalog_urshifu_delivery.py packs` builds the PCK;
   `prepare` builds the registry fixture and original-scene ZIP control. Validate
   the shared pack independently with `shared_model_catalog_probe.gd`.
5. Render with `catalog_urshifu_pair_render.gd` in the full slot project using
   `--rendering-method mobile`, then run the delivery tool's
   `pixels` phase. Run `tests/battle_3d_urshifu_check.gd` with the absolute
   `POKEAETHER_FORM_BUNDLE_WORK` directory, first normally and then with
   `POKEAETHER_URSHIFU_SHARED=1`. Candidate bindings are process-local.
6. `admit` updates both registry snapshots and the candidate index only after
   evidence matches. Repeat the presenter test with `POKEAETHER_URSHIFU_ADMITTED=1`
   and finalize the receipt. Run focused Python identity and registry parity tests.

For the next model release, include this pair alongside the three Therian pairs
and the 1,200 existing pairs: **1,204 pairs / 2,408 appearances**. The immutable
candidate is under `shared/packs/<object_key basename>` in the retained artifact
directory. Upload/verify it and coordinate the game/launcher index pins before
activation. Upload, release activation and old-object cleanup are separate
operations; none is performed by this local admission.
