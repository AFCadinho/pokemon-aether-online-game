# Pallet atlas — block 3 verification status

Status: focused block-3 acceptance of the Pallet prototype is complete. Native
render/pixel regressions, browser residency, real map cycles and matched
audit-off battle timing checks pass. This is not full release certification,
an exported desktop gameplay test on all platforms, or automatic authorization
to roll the prototype out through the importer. Block 4 is the next work block.

## Native rendered check

`tests/pallet_compact_render_check.gd` creates two independent 1600 × 1280
SubViewports with the original and compact generated visuals. It uses a real
X11/OpenGL compatibility renderer, waits for completed draws, and compares the
entire returned pixel buffers. It rejects blank/solid output and refuses a
headless display driver. Result: both nonblank images are pixel-identical.
The saved compact image was also visually inspected.

Run from slot-C frontend on a working display:

```sh
/home/adinho/Desktop/pokemonaetheronline/game/ops/worktrees/slot-env slot-c -- \
  godot --path . --rendering-method gl_compatibility --position 2500,1400 \
  --resolution 64x64 --script tests/pallet_compact_render_check.gd
```

The comparison covers actual atlas sampling, transform rendering, layer order
and tile padding at 1× over the whole generated visual. It is native rendering
evidence, not an exported desktop login/gameplay run, door movement test or a
browser GPU/latency measurement. Source-property/door-piece regressions from
block 2 remain relevant; rendered gameplay/movement checks are still required.

Ignored artifacts in this slot: `builds/pallet-native-render/original.png` and
`compact.png`. The environment reported an NVIDIA GL initialization fallback
before successfully rendering through the AMD OpenGL device; that warning does
not invalidate the nonblank pixel-buffer comparison. Existing editor launcher
and Unown case-UID warnings remain visible.

The older `pallet_town_visual_integrity_check.gd` also passes, but explicitly
loads the retained original visual. Do not mistake that check for validation of
the new candidate; the compact pixel/property and native render checks load both.

## Clean browser candidate export

Candidate source: `92bebb9e783f10a8156604e1a866aaed5f901db8`, dirty=false,
Godot 4.6.2. PCK SHA-256:
`c43306f34ffa1128fc4808e612d47ecef5d24612cede293552fbc8364eab02de`.
Initial files total approximately 261.766 MiB before HTTP compression.
Read-only PCK inventory confirms all seven compact portable Pallet textures are
present. The thirteen retained original Pallet textures are also still packed.
This is residency optimization, not evidence of a smaller initial download.

Candidate served from the task's existing loopback preview on port 8062; the
user's normal 8061 preview was not rebuilt or replaced. No backend interruption,
authentication, production access or full paired verification occurred in this
preparation step.

## Original acceptance checklist

- Approved disposable local runtime for real login, Pallet movement/doors,
  map transitions and three resolved battle/teardown cycles.
- Audit-on check: old unused Pallet atlases must not remain cached solely due
  to candidate references; compact resources must be loaded and memory stable.
- Separate audit-off, comparable control/candidate latency evidence; do not
  use extra texture inspection during timing comparisons.
- Confirm collision/depth behavior and distinguish native render comparison
  from full desktop gameplay evidence.
- Restore the normal Compose stack/database after each runtime; inspect health.
- Record exact builds/results and decide whether block 4 is justified.

## Disposable browser runtime — 2026-09-15

The approved local runtime was executed with the existing clean candidate PCK
above, Chromium/SwiftShader at 1440 × 900, fixed Grass fixture and real HTTP/WS
traffic (no mocks). The diagnostic driver at `235d83a44` also whitelists the
seven embedded PortableCompressedTexture2D subresource paths from the fixed
compact visual. The standalone saved texture files are not the scene's live
references: ResourceSaver embedded the textures in the prototype visual. The
native regression now confirms these paths are visible to cached-only probes.
No extra resource loads or GPU readbacks are used by this browser diagnostic.

The retained `builds/web-real-battle-memory/pallet-compact-world-audit-report.json`
confirms three successful real dev/wild starts, four resolved choices, three
teardowns and zero JavaScript page errors. At initial world idle and after each
battle it sees exactly seven compact Pallet textures (1,843,200 base-RGBA bytes,
1.7578125 MiB); none of the thirteen original Pallet atlas paths is cached.
Initial engine texture counter: 257,170,756 bytes (245.2571 MiB). All three
post-battle idle counters: 270,817,666 bytes (258.2719 MiB), with 854 resources,
zero orphan nodes and no pending sprite-cache work. Thus the warmed counter is
stable across these three cycles, not unchanged relative to cold world idle.
These are engine counters and bounded texture estimates, not physical GPU/RAM
measurements. Do not infer a precise causal counter saving from older builds.
The audit-enabled timings are explicitly **not comparable latency evidence**.

The complete driver still reports `success=false`: the house transition did not
complete. First the test walked into trees. An adjusted continuous-input route
overshot the door column by one tile because presence updates lag input. A
separate map-only run (`70770c51a` driver) used four Up/seven Right discrete steps
and visually reached the correct door column, but continued Up still did not
activate a transition within 20 seconds. Only `kanto_pallet_town` was reported
as active; no transition-enter HTTP request appeared. Area-access requests
returned HTTP 200, which alone does not establish `allowed=true`. Root cause
is not established; neither blame the atlas nor claim the doorway works.
No gameplay source or collision data was changed to bypass this failed check.

Retained reports in this slot:

- `pallet-compact-initial-audit-report.json`: first route failure; standalone
  paths missed the embedded compact resources (not zero texture residency).
- `pallet-compact-world-audit-report.json`: proven seven-texture residency and
  three battle cycles; door-column overshoot, overall success=false.
- `pallet-compact-map-only-report.json`: discrete correct-column attempt,
  zero battles by design, doorway timeout and overall success=false.

Each of the three wrapper invocations ended with `restored=1 test_exit=1`:
the test failure was preserved while the normal stack was restored. Final
inspection confirmed the normal `pokemon-aether-backend` Compose project,
Postgres persistent volume at `/var/lib/postgresql/data`, 12 running services,
healthy defined container checks and HTTP 200 on gateway/account health. The
account health payload still reports the local unconfigured transactional-email
worker as degraded; this is not complete stack certification. Known fixture
mail timeouts and gated peripheral HTTP 403s also remain outside this test.

### Doorway correction and successful candidate run

The off-tree native geometry probe `tools/audit_pallet_door_geometry.gd`
established that the old exit centre (656, 496) was on blocked tile (20, 15).
The walkable doorway (20, 16), centre (656, 528), did not overlap that exit's
32 × 32 rectangle with the real player's 32 × 30.5 detection rectangle at
offset (0, -0.75): they only touched an edge. The probe explicitly reproduces
that no-overlap regression. The house exit was moved one tile down to (656,
528), keeping the hint's world position unchanged. No collision, atlas,
authorization or spawn data was modified. The native check now verifies a
walkable overlapping entrance and its connected body-entered signal. This
scene correction applies to both browser and desktop.

Clean candidate export `845c334b9cf2dbef4bf2729bbcd863a3e9f1cf01`, dirty=false;
PCK SHA-256 `300959c546177721795a23b29c1b75f54f05f4252a20b1fbe58a812f59cb568e`.
`pallet-compact-door-fixed-timing-report.json` records success=true,
textureAudit=false, worldTextureAudit=false, timingComparable=true, three
dev/wild starts, four resolved choices, three teardowns and zero page errors.
Real presence maps: Pallet → Player's House → Pallet. Both transition-enter
HTTP requests returned 200. Screenshots were reviewed for the house and return.
Texture counter after all three battles and after returning to Pallet is
270,817,666 bytes, with 854 resources and zero orphan nodes. The intervening
house snapshot uses 312,298,262 bytes; returning releases its additional
texture footprint. The atlas pixel/property/door-piece regression also passes.

Candidate start-request → actions-ready durations: cold 11,785 ms, warm
3,566 / 3,535 ms in this software-WebGL run. These are raw observed timings,
not an accepted performance result. Historical runs are not a matched current
control; do not claim faster battles, non-regression or an SLA from them.
The remaining check requires an otherwise identical old-atlas build under
the same runtime/hardware conditions, with audits disabled on both sides.

At this point block 4 remained held until the paired comparison was reviewed. The doorway
correction and diagnostic follow-ups are ready for local development integration
after the successful focused checks. No production, promotion or full paired
gate was run.

## Matched atlas comparison — accepted

Two fresh disposable-stack/browser runs were performed, restoring the normal
stack between and after them. Both use Grass fixture, Chromium 153.0.8010.36,
SwiftShader at 1440 × 900, Godot 4.6.2, identical commands and diagnostics,
and backend commit `90b554e34916e6899b466467b24633bac8b6a4f6`.
Both texture audits and map-only mode are disabled. The corrected house
entrance remains unchanged. The only source difference between the two clean
exports is the main Pallet scene's original/compact visual reference.

| Build | Source commit | PCK SHA-256 |
| --- | --- | --- |
| Original control | `514d1464ef3deea8244558ba810790b1b3f294e5` | `0cad7f9dd5cb49ca5469da5cc935bea739b10c7356d0e6d39a34b00a6b81ec3b` |
| Compact candidate | `53fdf8d3c9a49168f9946d83765e048cdbef1950` | `b545cf3f7a3a961f3cec0eff0f34b439de68b895d367f1bc83bc12c962e9ca60` |

The driver records commit/export metadata, browser version, command digest,
fixture digest and a tracked-tree digest normalized for that **one** visual
reference. `tools/compare_pallet_battle_runs.cjs` rejects a mismatched tree,
backend, driver, fixture, browser, engine, commands, scenario or viewport;
also failed/audited/map-only runs, invalid cycle ordering, page errors,
missing map cycles and unstable post-idle texture counters. Four focused
synthetic test groups exercise successful comparison and those rejection gates.
The normalized tracked-tree SHA-256 is identical on both sides:
`4aeb3af5550f2d1125d382cf1c07898eb5c1f9ea4a39c915cf3969ef31bae2f7`.

Before either run, the provisional review boundary was recorded: investigate
a slowdown exceeding both 10% and 500 ms cold / 100 ms warm. This is a
practical focused regression threshold, not a statistical confidence interval.

| Start-request → actions-ready | Original (ms) | Compact (ms) | Delta (ms) |
| --- | ---: | ---: | ---: |
| Cold | 11,811 | 11,537 | -274 |
| Warm 1 | 3,540 | 3,465 | -75 |
| Warm 2 | 3,539 | 3,455 | -84 |

Result: no observed material slowdown; all three candidate durations are lower
in this pair. This is one fixed scenario with three starts per variant on a
software renderer. Do not promise these absolute times on players' hardware,
infer statistical speed improvement or advertise an all-battle/platform SLA.
The substantially different older Grass/effect measurements are not controls
for this pair and are not used to pass the candidate.

Each run completed three starts, four resolved choices, three teardowns,
zero page errors and real Pallet → Player's House → Pallet transitions.
Both transition-enter requests succeeded. Post-battle idle and return counters
are stable within each variant: original 410,372,490 bytes (391.3617 MiB),
compact 270,817,666 bytes (258.2719 MiB). Paired engine texture-counter difference
is 139,554,824 bytes (133.0899 MiB). Initial idle difference is the same.
This is **not** physical process RAM/GPU memory or download-size reduction.
The separate atlas base-RGBA estimate remains 48.4375 → 1.7578125 MiB;
do not equate it with the runtime counter, which also includes engine-owned
texture allocations. Retained original assets remain packed until pipeline
rollout is designed; this prototype deliberately does not delete fixtures.

Raw reports retained inside this slot (not Git):

- `builds/web-real-battle-memory/pallet-matched-original-timing-report.json`
- `builds/web-real-battle-memory/pallet-matched-compact-timing-report.json`

Reproduce read-only comparison from the frontend slot:

```sh
node tools/compare_pallet_battle_runs.cjs \
  builds/web-real-battle-memory/pallet-matched-original-timing-report.json \
  builds/web-real-battle-memory/pallet-matched-compact-timing-report.json
node --test tests/compare_pallet_battle_runs_check.cjs
```

The temporary original-reference control commit is retained as evidence and
followed by an explicit compact-reference restoration commit. Final gameplay
source matches the already approved compact candidate; the normal development
preview on 8061 was not rebuilt or replaced. Both wrappers ended with
`restored=1 test_exit=0`. Final inspection confirmed 12 normal services running,
healthy defined container checks and the original normal Compose project with
its persistent Postgres volume. The unrelated local email-worker/peripheral
limitations recorded above are not full-stack certification failures or passed
features of this atlas test. Proceed to block 4 as a separate bounded task:
make compaction part of map import with importer/CI regression coverage, then
consider other maps. Native pixel sampling, source properties and browser
movement/depth behavior have evidence; exported Windows/Linux/macOS gameplay
and full release certification remain outside this focused acceptance.
