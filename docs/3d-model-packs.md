# Local reviewed 3D model packs

This desktop-only packaging boundary installs the fourteen phase-5D reviewed
normal/shiny models without references to the source worktree, `.tmp`, Blender,
Godot import caches or review sidecars. It does not install arbitrary 3D art,
alter Settings, download content, publish a release or extend launcher Mods.
Launcher content packs currently support different asset types; do not import
this archive through the launcher's Mods panel.

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

This is a local developer installer, not yet a one-click player/launcher
download flow. Keep the archive and installed folder outside a checkout's
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
