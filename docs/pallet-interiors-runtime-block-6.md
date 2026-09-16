# Block 6: matched Pallet indoor runtime acceptance

## Accepted result — 2026-09-15

The Player's House and Pokemon Laboratory compact atlases pass a real browser
runtime comparison against their original generated visuals. Each variant ran
three dev/wild battle starts, four resolved choices and three ordered teardowns,
then Pallet → Player's House → Pallet → Oak's Lab → Pallet. Both reports have
success=true, sourceUnchanged=true, runtimeLost=false and zero page errors.
Post-battle texture counters plateau across all three cycles; all compared idle
and map snapshots have zero orphan nodes. Screenshots were reviewed for indoor
visibility and return to Pallet. Block 5 retains the native pixel-equivalence
evidence; this runtime is not a fresh-account storyline playthrough.

## Matched evidence

Chromium 153.0.8010.36, software WebGL/SwiftShader, 1440×900, Godot
4.6.2.stable.official.71f334935, one fixed Grass fixture, real HTTP/WS and no
texture audits during timing. Backend source remained
`90b554e34916e6899b466467b24633bac8b6a4f6`.

| Variant | Clean export commit | PCK SHA-256 |
| --- | --- | --- |
| Compact | `c6316ec03c2ce2149f24c96c2e38651fbc66e0ce` | `c3fc2cb384165b70d2c57fc0d7b7966befaf7adcff446d50c14a650d369f3668` |
| Original | `2a56623a3648f6e80f06ac15c2d1ede1edb75742` | `b14a574ac733a9aaecbc56b4dcbcbde6ab31cf0d4ed0d9ea81fe541fc480aeaa` |

The current driver/checker commit during both runs was `fa70747d9` (control
adds only the two original generated directories). The earlier compact receipt
is accepted because subsequent changes touch only export-excluded test/tool
files, not gameplay. Matching normalized tracked-tree SHA-256:
`c7e5444bb3362c5024cb3a774868111d06b3da400457e685915d293e1b70f7e5`.
Normalization excludes only the two exact generated indoor directories and the
existing explicit Pallet visual-reference normalization. The comparator also
requires identical driver, fixture, command, backend and browser fingerprints.
The full tracked index and clean status are checked again at run completion.

Ignored slot-local evidence remains under
`builds/web-real-battle-memory/interiors_compact_matched/` and
`interiors_original_matched/`. Raw reports/builds are not committed or copied
between checkouts. Reproduce the read-only analysis with:

```sh
node tools/compare_pallet_battle_runs.cjs \
  builds/web-real-battle-memory/interiors_original_matched/report.json \
  builds/web-real-battle-memory/interiors_compact_matched/report.json
```

## Battle timings and texture counters

Start-request → actions-ready, measured by engine timestamps:

| Cycle | Original ms | Compact ms | Delta ms |
| --- | ---: | ---: | ---: |
| Cold | 12,463 | 12,533 | +70 |
| Warm 1 | 3,734 | 3,678 | -56 |
| Warm 2 | 3,749 | 3,697 | -52 |

All deltas stay below the preselected review boundary: max(10%, 500 ms) cold,
max(10%, 100 ms) warm. No material slowdown was observed in this bounded pair.
These are three samples per variant in one software-rendered scenario, not an
SLA, statistical proof, all-device result or evidence of universally faster
battles. Battle assets and preloads were not changed.

| Matching snapshot | Original texture-counter bytes | Compact bytes | Saving bytes |
| --- | ---: | ---: | ---: |
| House entered | 312,298,262 | 246,708,394 | 65,589,868 |
| Pallet returned | 270,817,666 | 270,817,666 | 0 |
| Lab entered | 304,711,066 | 239,028,670 | 65,682,396 |
| Lab returned | 270,954,146 | 270,954,146 | 0 |

The indoor engine texture-counter reduction is approximately 62.55/62.64 MiB.
It is not physical GPU allocation or total browser/process RAM, nor the base
RGBA/file-size estimate from block 5. Map epochs differ as the camera moves;
require plateau at the unchanged post-battle position, not equal counters on
different maps. Compare corresponding epochs between variants. The equal
Pallet return counters show no additional original-indoor texture footprint at
those samples; they are not a comprehensive leak proof.

## Adjacent doorway correction and runtime safety

The lab exit rectangle was centred on blocked tile (40,24), world (1296,784).
The reachable front tile (40,25), world (1296,816), did not overlap that trigger
with the real player detection rectangle. Its shape was moved one tile down,
keeping the existing hint position unchanged. Both variants include this same
fix, so its effects are not attributed to atlas compaction. The correction applies
to browser and desktop, without changing collision tiles, NPCs or story logic.
The off-tree geometry check verifies reachable overlapping house/lab entrances.
The route tracer uses collision-grid BFS; the browser successfully walks the
resulting route and activates both real transitions.

An earlier exploratory run was invalidated when the disposable backend was
replaced externally by the normal project mid-test. No timing conclusion uses
that run. The driver now attests slot-C project labels and database tmpfs before
actions and samples and every second, closing the browser if attestation fails.
Missing preview and incorrect exploratory routes likewise did not count as
accepted evidence. The corrected map-only run passed separately before timing.

Each accepted run held the runtime lock throughout, used a disposable database,
and ended with `WEB_MEMORY_RUNTIME restored=1 test_exit=0`. The normal stack was
restored between and after runs: 12 services running, defined health checks
healthy, normal Postgres project and original persistent volume unchanged.
Health reachability is not full certification; the existing local unconfigured
transactional-email worker remains outside this gameplay acceptance.

Compact resources were restored in `368ac14e4cca957922ea39946d4d6894ccc4f12a`.
The final clean compact export from that commit totals about 260.9 MiB before
HTTP compression (control 261.8 MiB); PCK SHA-256:
`01a479adec71feca6bf303aa9b7f74494dcd3058812fd817471233b2546eb2b3`.
Slot preview 8062 serves the compact build again. Normal preview 8061 was not
rebuilt or replaced.

## Focused checks

Seven Node tests pass in `compare_pallet_battle_runs_check.cjs` and
`disposable_runtime_guard_check.cjs`, covering matching provenance, required
cycles/epochs, unstable idle residency, review boundaries and runtime rejection.
The following Godot checks also exit successfully on restored compact assets:

- `tools/audit_pallet_door_geometry.gd`
- `tools/trace_pallet_interior_test_path.gd`
- `tests/pallet_interiors_compact_check.gd`
- `tests/generated_map_atlas_layout_check.gd` (2 compact, 33 unchanged legacy)
- `tests/generated_map_texture_storage_check.gd` (329 textures)
- `tests/oaks_lab_gary_sequence_check.gd`
- `tests/players_house_story_intro_check.gd`

The tracked UID-sidecar check passes. Existing invalid-UID text-path fallbacks
remain. The house story fixture logs unauthenticated trainer-progress warnings
and an ObjectDB-at-exit warning despite passing assertions; these are not a
claim of warning-free native execution. The real browser's compared idle
snapshots have zero orphan nodes. No unrelated resource/cache rewrites were made.

## Remaining scope

The missing adjacent artist `Indoors Tileset.tsx` still blocks fresh source
reimport. Further migration of the 33 explicit legacy visuals is a separate,
bounded batch requiring equivalence checks. No all-platform exported desktop
playthrough, fresh-account story E2E, complete paired gate, promotion, push,
release or production operation is claimed by this block.
