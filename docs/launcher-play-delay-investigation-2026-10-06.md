# Production Play startup delay — 2026-10-06

## Confirmed cause

Before the cleanup, Play performed a synchronous full integrity check of the installed 3D bundle
collection before creating the game process. On this machine that lookup takes
6.7–8.6 seconds. During that time the launcher cannot redraw and provides no
visible starting status.

Call chain:

`launch_game()` → `_create_game_process()` → `_selected_model_catalog()` →
`release_asset_bundles.catalog_path()` → `store.catalog_path()` →
`active_generation()` → `_validate_generation()` → `_validate_object()` →
`FileAccess.get_sha256()` for every installed appearance.

`_create_game_process_with_mods()` was called only after this completed.
The launcher logged `Starting game.` before the expensive catalog lookup, which
can misleadingly suggest that game startup has already begun. The current
launch path neither downloads files nor waits for a server request.

## Evidence

- The public Linux manifest and the local installation both identify game and
  launcher 0.3.99, build
  `4e82134be390fec3fedffa00008bfef5495ccb8f-37451209374-1`.
- The launch and bundle-store source files at the production commit
  `4e82134be390fec3fedffa00008bfef5495ccb8f` have no differences from local
  development `9063607a76bbe80a39bd7beeb6fb0dc35c2bc21b`.
- The active local collection contains 83 bundles / 166 model appearance files,
  totaling 2,102,903,877 bytes (2.10 GB / 1.96 GiB).
- A separate Python SHA-256 read of those files took 8.677 seconds and verified
  all 166 expected digests.
- Godot 4.6.2's actual `BundleStore.catalog_path()` took 8,606.037 ms,
  6,714.915 ms, and 6,701.428 ms in three consecutive calls. Each returned a
  valid catalog. This includes generation metadata and model checksum checks.
- With an absent store, the same Godot function took 0.076 ms, 0.045 ms, and
  0.042 ms, returning no catalog.

The first sample is not a controlled cold-cache benchmark: earlier inspection
had already read the model files. Storage cache and other system activity affect
the precise duration. This measures the pre-spawn catalog lookup, not the total
time from click to first rendered game frame. Additional game/driver startup
time remains unmeasured. Other operating systems and collections may differ.

## Reproduce

From the game workspace, with slot-a assigned to this task:

```sh
ops/worktrees/slot-env slot-a -- godot --headless \
  --path .worktrees/slot-a/frontend/launcher \
  --script res://tests/profile_play_catalog.gd -- \
  '/absolute/path/to/installed/asset-bundles-v1'
```

The diagnostic requires an explicit absolute directory. It reads the existing
collection in place, performs three launch lookups, and does not change it. Godot
userdata, configuration, caches and logs remain isolated by `slot-env`.
The script in investigation commit `bd9413e72` measures the original full lookup;
the current script measures the cleaned-up launch lookup.

## On-demand architecture

Follow-up inspection confirms that production already downloads models on
demand into `user://on-demand-3d-v1`. Battles and previews call `ensure_models()`;
its installed-model path verifies only the requested identities against the
pinned index and checks their size and SHA-256. It can reuse the launcher
catalog, and missing or invalid requested models enter the downloader path.
The startup sweep covers the separate launcher bundle collection, not the
game's entire on-demand cache. Optional full-collection downloads still exist,
so retaining access to those files remains useful; hashing every model at Play
is redundant with the per-use checks in the normal on-demand flow.

## Implemented cleanup

The Play path now calls `catalog_path_for_launch()`. It validates the generation
metadata hash, bundle manifest metadata and catalog consistency, and falls back
to the previous generation if the current metadata is invalid. It never reads
or hashes model contents. Full model verification remains in `catalog_path()`,
state planning and install/activation flows. The game still receives the model
catalog and release-pinned index and verifies requested models before reuse.
Missing or corrupt individual models do not prevent the catalog handoff.

The final code's lookup on the same installed 83-bundle collection took
19.847 ms, 9.282 ms and 9.326 ms, versus the original 8,606.037 ms,
6,714.915 ms and 6,701.428 ms. These measurements cover the catalog handoff,
not game or graphics-driver startup.

Validation completed through `ops/worktrees/slot-env slot-a`:

- `launcher/tests/asset_bundle_store_check.gd`: Play invokes no model scan,
  passes the correct catalog/index and restores the parent environment; missing
  and same-size-corrupt model files do not block handoff; metadata tampering,
  malformed catalogs and damaged active pointers recover the previous generation.
  Full store, atomic batch, streaming, corruption, rollback and disk-full checks
  also pass.
- `launcher/tests/forest_launch_environment_check.gd`: forest path forwarding
  and parent environment restoration still pass.
- `tests/on_demand_launcher_catalog_check.gd`: the actual game cache-check path
  reuses a valid model from a launcher catalog even if an unrelated file is
  missing. Corrupt, missing or obsolete requested models reach the replacement
  planner. This fixture substitutes the download step; it performs no network
  downloads.
- `launcher/tests/profile_play_catalog.gd`: three read-only timings of the
  existing local collection, with a valid catalog returned in every sample.

Only the frontend repository changed. The implementation remains on the assigned
slot-a task branch for integration; production and installed player data were
not modified. A launcher release is required for players to receive the fix.
