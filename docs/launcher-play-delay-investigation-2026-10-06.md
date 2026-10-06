# Production Play startup delay — 2026-10-06

## Confirmed cause

Play performs a synchronous full integrity check of the installed 3D bundle
collection before creating the game process. On this machine that lookup takes
6.7–8.6 seconds. During that time the launcher cannot redraw and provides no
visible starting status.

Call chain:

`launch_game()` → `_create_game_process()` → `_selected_model_catalog()` →
`release_asset_bundles.catalog_path()` → `store.catalog_path()` →
`active_generation()` → `_validate_generation()` → `_validate_object()` →
`FileAccess.get_sha256()` for every installed appearance.

`_create_game_process_with_mods()` is called only after this completes.
The launcher logs `Starting game.` before the expensive catalog lookup, which
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
collection in place, performs three full lookups, and does not change it. Godot
userdata, configuration, caches and logs remain isolated by `slot-env`.

## Recommended follow-up

Move catalog verification to a worker, show a starting status and disable Play
before beginning, then spawn the game on the main thread when verification
completes. This preserves the checks while removing the frozen UI, although it
does not remove the verification wait. Reducing the wait requires a separate
decision about when to verify the collection (for example preparation before
Play); any reuse of a verified result must handle files changed since the check
and preserve the current corrupt-generation fallback. Do not simply bypass the
checks or substitute an unchecked active pointer.

Only this report and the read-only timing script were added. Launcher/game
behavior, installed data, and production were not changed.
