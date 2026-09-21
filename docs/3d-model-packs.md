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
