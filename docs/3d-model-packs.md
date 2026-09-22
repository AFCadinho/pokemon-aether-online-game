# Local reviewed 3D model packs

This desktop-only packaging boundary installs the fourteen phase-5D reviewed
normal/shiny models without references to the source worktree, `.tmp`, Blender,
Godot import caches or review sidecars. It does not install arbitrary 3D art,
alter saved game settings, download content, publish a release or extend launcher Mods.
Launcher content packs currently support different asset types; do not import
this archive through the launcher's Mods panel.

## Install through the launcher

1. Open **3D Models** (Dutch: **3D-modellen**) in the launcher sidebar.
2. Choose **Import model ZIP…** and select the reviewed ZIP. Installation and
   hash checks run in a worker; the panel remains responsive. Existing packs
   are never overwritten, and failed imports do not change the selection.
3. Pick the installed fourteen-variant pack and press **Use selected models**.
4. Start/restart the game from that launcher. Enable **3D (experimental)** in
   the game's Settings if you have not already done so.

This flow requires no Python or manual catalog picker. Importing alone does not
enable a pack. **Game settings (no launcher override)** restores the game's
saved local-catalog choice, not necessarily 2.5D mode. Changes take effect at the
next game launch, never halfway through a running battle.

Packs live in the launcher's `user://model-packs/<catalog-sha256>`; **Open model
folder** opens this persistent location outside the game update directory.
`selection.json` is atomically replaced only after the selected scenes pass
hash checks. The launcher passes `POKEAETHER_MODEL_CATALOG` to its child game
and restores its own environment afterward, including process-launch failures.
The game uses this as a session-only override; it does not save it over your
manual path or force 3D presentation. Choosing a local catalog in game Settings
takes priority for that session. Browser builds ignore the launcher override.
Missing/incompatible launcher selections produce no override; the existing
game catalog/fallback remains available. Modified model bytes are rejected on
selection and again by the real presenter's integrity checks.

## Build and install

Run from the frontend repository (Python standard library only):

```sh
python3 tools/sprite_factory/model_pack.py build /path/to/admitted-catalog.json /path/to/reviewed-models.zip
python3 tools/sprite_factory/model_pack.py install /path/to/reviewed-models.zip /path/to/model-packs/reviewed-v1
python3 tools/sprite_factory/model_pack.py verify /path/to/model-packs/reviewed-v1
```

The build input is the explicit normal/shiny array produced by
`phase5_runtime_admission.py --catalog-only`. Both build and installation check
every scene against the game's checked-in registry. No source or installed file
is overwritten. Use a **new directory** for each version; select its catalog
after verification. The old directory and Settings selection remain untouched,
so rollback is simply selecting the previous catalog again (while that version
is still supported by the client).

In game Settings, enable **3D (experimental)** and choose the installed
`catalog.json` using **Choose local 3D model catalog…**. No Python or source
models are needed to load an already installed pack. You may move the entire
installed directory, then reselect its catalog. Moving only `catalog.json`
without its `models` subdirectory will not work. Missing models retain the
existing 2.5D fallback. Legacy absolute-path catalogs remain supported.

The CLI remains available for development. Neither installer downloads or
publishes a pack. Keep the archive and installed folder outside a checkout's
temporary directories. Do not copy caches, credentials or user settings.

## Portable format and checks

The ZIP contains only `catalog.json` and `models/<approved-sha256>.scn` files.
The manifest has `schema: 1`, `kind: pokeaether-reviewed-model-pack`,
`godot: 4.6`, the reviewed qualification hash, and explicit species/variant,
runtime hash/schema, relative path and byte count for each entry. It contains
no source paths or user state. Shared placement, grounding, timing, motion and
HUD bounds stay in the client registry, never in a pack-controlled override.

Godot 4.6 compatibility is deliberately explicit; a different engine minor or
qualification needs a reviewed/rebuilt package, not an assumed binary-SCN
compatibility promise. The installer verifies bytes without executing scenes;
the client repeats its asynchronous pre-import and post-load integrity checks.
The fourteen approved files have no external resource dependencies.

Builds use deterministic member ordering, metadata and stored ZIP entries
(the scene resources are already compressed). Installation accepts stored or
deflated entries, rejects duplicates, undeclared files, links, encryption,
unknown variants/hashes and any path other than the canonical approved name.
Limits are 1 MiB manifest, 128 MiB per scene, 512 MiB total, and no more models
than the current registry. Hash verification uses bounded streaming reads.
Files are extracted only into a private staging directory and published after
verification. On a handled failure staging is removed; a process killed during
installation may leave a hidden staging directory, never a selected catalog.
An existing destination is refused rather than updated or deleted.

The native launcher additionally checks local headers against central-directory
headers before ZIPReader allocates buffers. ZIP64, multipart, encryption and
data descriptors are not accepted by this first launcher format; the supplied
deterministic builder does not use them. Only the declared approved models are
written. The launcher has its own checked-in manifest validator/approval snapshot
because its standalone export cannot access files outside its project root,
while browser game exports exclude `launcher/**`. The
`test_launcher_model_registry.py` checks require exact equality with the game
copies (apart from the preload path); update both when approval data changes.

## Local handoff artifact

Retained in assigned slot-c, outside its frontend and `.tmp`:

- `artifacts/phase5-reviewed-models-v1.zip`: **135,610,772 bytes**.
  SHA-256: `9122a6a6ec238c6709d02647b9bffaf3333307c81d3f1649c88cb270afefc2fe`.
- `model-packs/phase5-reviewed-v1/catalog.json`: installed fourteen-model pack.
  Catalog SHA-256: `5078fd43b7695ccad5d738e4ba1bdeffa90eeae163c5e424217555f4b976f160`.

These are generated local assets, not checked-in or published game content.
Abra, Onix and Gastly are still held; this package adds no new approvals.

## Focused verification

`test_model_pack.py` covers reproducibility, relocation after source removal,
no-overwrite behavior, corrupt bytes, unsafe paths, duplicate members/identities,
links, extra scripts, incompatible metadata and invalid sizes. Run it alongside
`test_phase5_runtime_admission` from `tools/sprite_factory`.

`tests/reviewed_model_admission_check.gd` also accepts the installed manifest and
checks real scene hashes, absent external dependencies and runtime rejection of
unsafe/invalid metadata. The production-mode `phase5_battle_stress_check.gd`
accepts the same installed catalog, exercising the regular presenter without
candidate admission/motion/bounds overrides. Run Godot via the assigned slot's
`slot-env`, with explicit logs and isolated userdata; do not change the normal
client's personal settings for tests.

Local results: **77 Python tests passed**; portable and legacy admission checks
passed. The installed pack's final three-battle stress run passed the existing
5C guards: 36 mixed-team switches, 21 duplicate/faint checks, 21 variant
swap/faint/eviction/reload checks and three recorded replays. P95 frame times
were **17.32 / 17.36 / 17.35 ms**, load callbacks at most **2.10 ms**, and
final-two-round static growth **49,640 bytes**. Covered entry still reached
**521.24 ms** and replay construction **94.32 ms** whole-frame time. Packaging
does not promise instant loading or eliminate startup stalls.

The first run completed the functional matrix but missed the performance guard
(first-round p95 **22.81 ms**) and emitted an ObjectDB leak warning at shutdown.
The verbose repeat had no script errors or leak warning and passed the guards.
The warning's cause is unconfirmed; it is not claimed fixed. Both runs and their
hashes are retained in [3d-model-pack-validation.json](3d-model-pack-validation.json).
Other existing asset-UID fallback and verbose RGB8 conversion warnings remain.

After merging the concurrent immersive Escape/Settings change into the task,
the rendered `battle_screen_host_check.tscn` also passed with the installed
pack (`phase5-pack-host.log`). The original two-model cache regression passed
separately (`phase5-pack-legacy-cache.log`). Neither log contains script errors.

Launcher integration checks: `launcher/tests/model_packs_check.gd` installs the
real 129-MiB archive in isolated test storage, exercises the worker-backed Dutch
panel and persistent selection, validates environment forwarding/restoration
using a process stub, and rejects corrupt payloads, traversal, extra scripts,
incompatible metadata, links, oversized/mismatched headers and truncated ZIPs.
It confirms failed actions preserve selection and remove their own staging.
Its installed scene is deliberately corrupted at the end to test revalidation;
that test directory is not the user handoff pack. The visual review is
`.tmp/launcher-model-test-05/model-packs-panel.png` (720×450).

`tests/launcher_model_selection_check.gd` checks session-only precedence,
manual overrides and a real rendered shiny-Pikachu/Dragonite pair loaded from
the forwarded catalog. Final logs: `launcher-model-test-05.log` and
`launcher-model-game-rendered.log`. 79 related Python checks pass, including
snapshot parity. The launcher localization regression also passes; its deliberate
invalid-executable rollback fixture logs `STG-001 staged_install_failed`, which
is an expected negative test, not a model-install failure. No launcher export,
publication, full release certification or production mutation was performed.

### Actual launcher-to-game process regression (Linux)

`launcher/tests/model_process_check.gd` exercises the panel's import/select
signals and the launcher's unmodified `_create_game_process` function. A small
executable fixture (deliberately named with spaces) starts the real Godot game
project with `tests/launcher_model_process_child.gd`. The launcher receives a
real process ID, forwards the selected catalog and locale, and restores its own
environment. It checks the child's result and log after the process exits.
This is not a stubbed process, but also not an exported shipping executable.
Launcher startup/update networking is intentionally not run.

Run through `ops/worktrees/slot-env SLOT -- env ... timeout 260s godot`, using
the slot's launcher project, an explicit slot-local log and
`--script res://tests/model_process_check.gd`. Required environment:

- `POKEAETHER_E2E_DATA_HOME` and `XDG_DATA_HOME`: the same **fresh**, absolute
  slot-local test data directory (not ordinary slot/player userdata).
- `XDG_CONFIG_HOME` / `XDG_CACHE_HOME`: fresh sibling test directories.
- `POKEAETHER_E2E_OUTPUT`: fresh absolute evidence directory.
- `POKEAETHER_E2E_GAME_ROOT`: the slot's frontend project directory.
- `POKEAETHER_MODEL_PACK_ZIP`: the reviewed ZIP artifact.
- `POKEAETHER_E2E_PHASE`: first `install`, then a separate invocation with
  `restart`, retaining the same isolated directories.

The first child runs the existing three-battle lifecycle matrix. The second
starts with an empty model cache and tests empty Team Preview followed by a
shiny Pikachu/Snorlax pair, without assigning a manual catalog. Both check that
the launcher does not force 3D or modify saved game settings. No accounts,
live PvP, production, or normal user profiles are used.

Local result: both process runs pass (`.tmp/model-process-01`), with unchanged
saved game settings and the same selected catalog after restart. The first
child completes 36 mixed switches, 21 duplicate/faint checks, 21 variant
checks and three recorded event replays across three battles. Existing 5C
performance guards pass (p95 17.70 / 17.26 / 17.27 ms), but covered entry has
a **1.43-second** frame: no instant-loading claim. Existing UID fallbacks remain;
no script errors or shutdown leak warning occurred. 21 focused Python checks
also pass. See [process evidence](launcher-model-process-validation.json).

### Standalone exported runtime check

The official 4.6.2 Linux debug template disables command-line project/script
overrides (see [Godot's startup handling](https://github.com/godotengine/godot/blob/4.6/main/main.cpp)).
Do not run the preceding `--script` command against that binary: it starts the
ordinary main scene instead. An initial attempt did this and briefly ran the
launcher's public update check; it was stopped without login or applying updates.

For offline export testing, temporarily set each **task-slot** project's
`application/run/main_scene` to its own
`res://tests/model_export_bootstrap.tscn`, export its PCK with the existing
Linux preset, then restore both original main scenes immediately. No other
project settings or export filters are replaced for this test. Assemble each
PCK beside the official `linux_debug.x86_64` template with matching basenames
(`launcher.x86_64`/`launcher.pck`, `game.x86_64`/`game.pck`). These bootstraps
attach the existing offline checks to the running SceneTree after autoloads;
neither is wired into normal application startup.

Use the same isolated environment described above, plus
`POKEAETHER_E2E_GAME_BINARY` (absolute exported game executable) and
`POKEAETHER_E2E_ENTRY` (absolute path to the test shell fixture). Start the
exported launcher directly, without `--path`, `--main-pack` or `--script`.
Run `install` then `restart` in separate processes. Both sides verify they
are using the standalone runtime, and the parent rejects child log errors.

The initial offline export reproduced two release-only failures: the game
referenced a store under the excluded standalone `launcher/` project, and
desktop filters removed HOME icon dependencies of `sprite_box.tscn` and
`team_preview_layer.tscn`. The game-local parity-tested content store and
narrowed desktop sprite exclusions fix these dependencies. Windows/macOS
filter coverage is static only; executable testing here is Linux only.

After those fixes, the exported install/start and separate launcher/game restart
both pass. The first game completes all three battles and existing 5C performance
guards; the second loads empty Team Preview and shiny Pikachu/Snorlax from a
cold model cache. Saved game settings remain unchanged. No script/resource
errors or leak warnings occur in the final runtime logs. P95 is
17.42 / 17.38 / 17.33 ms, but covered entry still reaches **1.66 seconds**.
The content-pack regression, web sprite contract and 23 Python checks pass.
See [export evidence](launcher-model-export-validation.json) for hashes,
measurements, failure history and scope. Test-only main-scene overrides are
restored; these artifacts are not intended for players or publication.
