# Desktop battle arena integration

Forest, cave, sea (sandbar) and stadium now connect to ExperimentalBattle3D.
In Settings, choose **3D — experimental desktop**, then **3D arena — development
override (next battle)**. Classic test stage remains the default. The choice is
captured at world creation; it does not replace an arena mid-action. Automatic
map/PvP selection, fullscreen UI and attack cameras are deliberately not added.
Only the existing supported local Dragonite/Roaring Moon catalog is supported.

## Local setup on this workstation

Keep the existing prepared report selected:
`../.worktrees/slot-c/.tmp/battle-stage-pbr-01/glb/report.json` relative to frontend.
Its `.runtime.json.grounding.json` companion has been generated locally. Ground
metadata is accepted only for matching model SHA-256 and presentation scale.
Missing/stale metadata keeps the classic floor with a visible explanation; it
does not guess new species offsets or sweep all animation frames during battle.

For Forest, use **Choose trusted local forest pack manifest…** and select:
`../.worktrees/slot-c/.tmp/forest-runtime/forest.json` relative to frontend.
Then start a new battle. Native extension/pack mounts last for the client process;
restart before selecting a different forest pack. Never open untrusted packs or
native extension manifests. No settings or userdata were copied between checkouts.

The purchased FancifulCrow art and Terrain3D binaries remain in the isolated local
project, not in Git. The generated 69 MiB pack contains exported forest resources,
terrain regions and the Terrain3D license. Its local extension descriptor points
to the purchased project's Linux x86_64 library. Windows/macOS release packaging,
installer distribution and other hardware remain separate work; this is not a
cross-platform production delivery system. Keep the purchased project available.

## Shared ownership

`scripts/battle/arenas/arena_catalog.gd` provides validated IDs, spawn positions,
camera framing and builders. Builders own only environment geometry; the existing
presenter owns combatants, actions, send-out/recall, transition cancellation and
viewports. Both the display and material-response passes build their own arena.
The material pass disables SSR/glow. Neutral Pokémon lights stay unchanged;
High shadow filtering matches approved previews. The forest builder shares its
clearing, background path and grass retention code with the original review.

The runtime-only `addons/terrain_3d/utils/terrain_3d_objects.gd` placeholder
intentionally replaces an editor placement helper, not Terrain3D itself. Export
excludes the vendor editor utility scripts/remaps; all terrain rendering and
instancing still uses the native extension. Runtime-loaded UID mappings never
overwrite existing client IDs; the PCK mount also refuses resource replacement.

## Rebuild local forest / grounding

From the game workspace, using only the isolated purchased project:

```sh
python .worktrees/slot-c/frontend/tools/sprite_factory/prepare_forest_runtime.py .worktrees/slot-c/.tmp/fancifulcrow-review-01/TemperateForestPack-main .worktrees/slot-c/.tmp/forest-runtime
python .worktrees/slot-c/frontend/tools/sprite_factory/prepare_cave_review.py .worktrees/slot-c/.tmp/cave-review-01
ops/worktrees/slot-env slot-c -- env POKEAETHER_FOREST_SMOKE=1 POKEAETHER_3D_STAGE_REPORT="$PWD/.worktrees/slot-c/.tmp/battle-stage-pbr-01/glb/report.json" godot --path .worktrees/slot-c/.tmp/cave-review-01 --script res://tools/sprite_factory/export_arena_grounding.gd
```

Forest preparation writes a generated scene, UID manifest and a named export
preset in the isolated project; original asset resources are not resaved. It uses
Godot's normal resource export, not cache synchronization. The pack is local only.

## Verification and remaining limits

`tests/battle_arena_integration_check.gd` exercises every available arena twice,
send-out, recall, physical/special attacks, damage, faint and replacement. Both
viewports must be freed after every cycle. `POKEAETHER_TEST_ARENAS` can select a
comma-separated slice. Forest requires `POKEAETHER_FOREST_MANIFEST`.
The existing `battle_3d_presentation_check.gd` also supports
`POKEAETHER_TEST_ARENA=forest` for the full battle/replay/host regression.

The first forest asset load is threaded; its PackedScene remains cached for
subsequent battles. Native scene instantiation, terrain edits and shaders still
run on the rendering/main thread. Cold-start hitch elimination is not certified.
The native Terrain3D build currently emits a physics-interpolation deprecation
warning on Godot 4.6.2; legacy UI resource UID warnings also remain unrelated.
No full development certification, backend changes, deployment or release.

Local evidence (slot-c/.tmp): `arena-integration-final.log` passes two cycles for
all four arenas; `arena-forest-lifecycle-final.log` passes the real battle/replay
flow three times and retains less than 1 MiB between the final two cycles.
The forest run still measured a roughly 1.35 s longest load frame even after
threaded resource loading; scene/terrain assembly remains a performance follow-up.
Normal action p95 was about 17.3 ms on RTX 3070 Laptop. Do not treat these numbers
as production performance approval. `arena-contract.log`, `arena-material-final.log`
and `stadium-shared-final.log` pass; the nine cave/sea/stadium preparation tests pass.
