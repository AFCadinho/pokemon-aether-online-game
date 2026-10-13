# Physical Android 3D performance measurements

## Android touch camera and bounded move preparation

The user confirmed that trial `0.3.109-3d-perf.8` clears foreground grass and
keeps the world-to-battle fade, but reported that entry still feels slow with
installed assets. Its numeric logs recorded preparing windows of 2.106 s for
the first entry and 0.849 s for the repeat. The repeated sample had 130 ms of
presenter model validation, 80 ms of render warmup, 2 ms of actor construction
and negligible arena construction. `forest_load_ms` is a historical session
value, not a second forest load. These are preparation windows, not complete
network-plus-entry timings.

The downloader now hands its fresh full shared-pack inspection to the
presenter. Qualified runtime identity, bytes, namespace, manifest, physical
path and pack hash must match. Local catalogs cannot supply this receipt.
Cold imports retain their full after-load verification; RAM reuse still uses
the bounded hash/pack/timing cache key. Importing waits for the current pair
handoff instead of starting a duplicate inspection concurrently. No session
stat-based verification cache or larger RAM cache is introduced.
Previously rendered Android resources in the same pooled viewport need one
stable render sample instead of two, followed by restoration of summon
visibility. Installed, verified Android assets use a 0.12 s fade with at least
six blend steps; desktop and download/fallback entry retain the existing fade.
The explicit USB probe records downloader/entry duration and numeric host
ready/fade/total timings to distinguish network waiting from local work.
The native real-pack handoff check covers normal/shiny appearances, mismatched
receipts, cold after-load inspection and warm RAM reuse. Held-download camera
entry and fullscreen fade/handoff/cancellation checks remain focused guards.

USB trial `0.3.109-3d-perf.9` (code 39, source `f677962de`) passed signed
ARM64 Mobile export checks and was installed on the SM-S938B without clearing
game data. It retains v14 models and disabled move warmup. Four physical entries
recorded 3195/1924/2067/1979 ms from host mount through completed fade. Repeat
preparation took 576–632 ms, including 536–560 ms of downloader checking;
presenter validation was zero with two fresh pair handoffs. The repeat fades
took 158–168 ms. The user still found entry slow, so reducing fade alone was
insufficient. Time outside these preparation/fade phases is not yet attributed
to network or scene setup.

Installed-model checks now hash the complete pinned index, but expand only the
assets needed by the encounter. The local v14 pin reuses its already owned
compiled trusted cohort rather than reparsing the large JSON on every entry.
No disk verification receipt is kept across encounters. A desktop v14 probe
measured approximately 393 ms per complete-index read before these changes
versus 9 ms for two requested assets afterwards; this is not a phone timing.
The host probe also records the wait for authoritative combatants/setup before
presenter preparation, to isolate the remaining delay.

World-entry preparation now preserves an explicitly supplied overworld
snapshot instead of replacing it with the lobby's dark loading backdrop.
Android still waits for the real model camera fit, then uses the same layered
fullscreen fade. Entries without a world snapshot retain their loading screen.
The held-download check verifies snapshot retention and, under native Mobile
rendering, the actual green world-image pixels during response/model waits.

Move shots prepare a static arena-bound index under the entry cover. The
clearance helper protects the first three metres (at most 60%) of the sightline
above grass batches, with a 0.4-unit wind margin, and raises the camera above
upright props along the focus ray. Flat ground and hidden geometry are excluded.
Clear shots keep their authored pose; a lift beyond twelve units uses the
prepared overview. Clearance blends out with native shot recovery and changes
neither FOV, materials, visibility, geometry, shadow casting nor move timing.
This is shared by Android and desktop cinematic shots. Bounding boxes are
conservative, so gaps within an object can cause more clearance than necessary.
Native Mobile checks verified real MultiMesh bounds, preserved focus, visible
arena objects and overview fallback; normal/Draco shot regressions passed on
both camera policies.
Bounds use Godot's documented
[VisualInstance3D bounding boxes](https://docs.godotengine.org/en/4.6/classes/class_visualinstance3d.html#class-visualinstance3d-method-get-aabb).
The 35 Z-move choreography regressions also passed.

USB trial `0.3.109-3d-perf.8` (code 38, source `55273e8c0`) passed signed
ARM64 Mobile export checks and was installed without clearing game data. It
retains v14 models, the close-up camera and move shots, with warmup disabled.
The user confirmed the physical overworld fade and grass-shot appearance on
the grassfield; the remaining feedback concerns entry latency with local assets.

Android move shots use the independent `android_3d_move_camera` preference,
enabled when an older profile has no value for it. Previously, all move shots
required `battle_3d_camera_motion`, which defaults off and whose control was
desktop-only. The experimental Android Graphics page now exposes a localized
move-shot switch with persistent opt-out. The idle-camera preference and
desktop behavior are unchanged. Existing charge/release/impact shots reuse
their native effect clock and return to the Android close-up and manual orbit.
Offline Android checks cover Draco Meteor plus eleven catalog moves, singles
and doubles, hit/miss/immune, pause, recovery, cancellation, substitutes and
disabled shots. The settings check covers older profiles and saved opt-out.
The GPU isolation fixture explicitly disables both camera preferences so
rendering comparisons retain their fixed view.

USB trial `0.3.109-3d-perf.7` (code 37, source `e93dcdd19`) passed the signed
ARM64 Mobile demand-export checks and was installed over the existing game.
It retains the published v14 model pin and leaves move warmup disabled. Android
Draco Meteor, Android catalog choreography, settings persistence, desktop
Draco Meteor and desktop catalog choreography checks passed. The user confirmed
physical shots work, then reported foreground grass obstructing charge shots
and a dark world-to-battle preparation interval. The snapshot preservation and
general cinematic clearance changes above address those follow-ups.

Android first fits an overview, then applies the requested zoom to that
transform. A conservative unposed mesh envelope must not undo pinch zoom:
the first physical camera trial still looked too distant even at its limit.
The new default distance factor is 0.60 (0.80 for doubles); limits are
0.30–1.60 before the doubles factor. A near-plane guard keeps slot centres
in front of the camera. Close views may crop large Pokémon; zooming out
restores a complete overview. Reset restores the nearer Android default.
The HUD remains fixed. Desktop framing and 0.72–1.45 limits remain unchanged.
One finger rotates an idle camera; two fingers pinch to zoom. Buttons, chat,
the loading cover and attacks in any singles/doubles slot block gestures.
Touch cancellation, focus loss, a third finger and lifting one pinch finger
end the gesture without rotating the remaining finger. Emulated mouse events
do not rotate a second time; an ordinary mouse wheel still zooms.

Android keeps pending 3D entries covered until the actual models and their
camera fit are prepared. The pooled arena still prepares underneath, but its
empty-field camera is never revealed before the final close-up. Downloads can
show the existing delayed progress message; cached preparation stays quiet.
Send-out visibility, cancellation, fallback and Team Preview retain their
existing readiness paths. The held-download entry check verifies that the
first visible camera transform remains unchanged throughout the reveal.

Before entry is marked prepared, explicitly opted-in local Android Mobile
USB trials (`--move-warmup`) sample
a maximum of eight hidden move effects on the real battle world. Currently
available own moves take priority, followed by the measured common physical,
flame and electric effects. Five charge/flight/impact samples instantiate lazy
geometry and materials, without playing actor animations, sounds or camera
shots. Preparation checks a 1,500 ms budget between samples (an individual
driver compilation may exceed it). Hidden resources remain alive until the
presenter is released, so this trades a small bounded allocation and entry
work for a chance to avoid first-use stalls; it does not prove every move is
warm or reduce overall memory use. Cancellation releases retained effects.
This follows Godot's
[pipeline instancing guidance](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html#pipeline-precompilation-instancing).

The 2026-10-13 comparison used one unchanged diagnostic APK, native
2340 × 1080 / 4x MSAA, v14 Charizard/Dragonite and sorted grass during moves.
Each of the control / warmed / control runs completed with usable reports,
unchanged foreground/PID, no engine errors and zero frames over 100 ms.

| Run | First move max frame | Repeated move max frame | Peak sampled PSS |
| --- | ---: | ---: | ---: |
| Control 1 | 97.80 ms | 38.26 ms | 2,087 MiB |
| Warmed | 47.53 ms | 41.76 ms | 2,134 MiB |
| Control 2 | 42.05 ms | 42.59 ms | 2,081 MiB |

Preparing the three representative effects took 446 ms, with 10 surface
pipeline compilations and no draw compilations. First-use moves still added
14 surface / 2 draw compilations in all three runs. The warmed run therefore
does not show a repeatable advantage over the subsequent control; cache and
thermal effects remain confounded. Battery temperature rose from 28.2°C to
35.5°C across the series, thermal status 0 → 2. Peak PSS differs between
sessions, so the table is not an exact allocation measurement. Warmup remains
disabled by default rather than adding entry work and retained resources to
every Android battle. Raw evidence stays in `.tmp/android-touch-warm/moves-*`.

Local full-game trial `0.3.109-3d-perf.4` (code 34, runtime source `e3ea09ab8`)
predates this opt-in gate and includes the warmup prototype. It uses the
published v14 collection, preserved game userdata, and passed signed ARM64
Mobile demand-export checks. The user confirmed pinch input works but that
the first camera change was still too distant. Trial `0.3.109-3d-perf.5`
(code 35, source `3944dde3b`) applies the post-fit close-up and disables move
warmup. The user confirmed that the Pokémon are now much better framed, then
reported a zoom change between the empty opening field and loaded Pokémon.
The covered entry policy addresses that follow-up. No publication or release
certification took place.

Trial `0.3.109-3d-perf.6` (code 36, source `2442c2a5e`) passed signed ARM64
Mobile export checks and was installed by USB without clearing game data.
The user confirmed that the opening camera is immediately correct and a move
still works. Numeric camera logging showed zoom 0.60, FOV 48 and two slots.
One previously observed Godot `can_process` condition (`node.cpp:902`) remains
in the log; this run did not reproduce the native move crash. Offline Android
covered-entry, desktop early-arena and fullscreen fade/handoff/cancellation
checks passed. This remains evidence from one physical device.

`run_android_gpu_benchmark.py --warm-moves` records the hidden common-effect
preparation before the first move phase; a bounded/incomplete preparation
invalidates that comparison. The diagnostic and explicit local USB
`--model-revision v14` flag pin the already published collection, independently
of the qualified v15 collection on development. Normal releases still select
v15. No model assets are published by either tool.
New diagnostics use a slot-specific package such as
`com.pokeaether.androidgpuqa.slot_a`, because isolated worktrees can own
different debug signing keys. Existing diagnostic packages/data are retained;
the collector verifies the exact current-slot package and its debug flag.

## Automatic GPU isolation on one physical phone

The `android-gpu` export suite creates the separate debug package
`com.pokeaether.androidgpuqa`, using production Mobile rendering, the pinned
v14 model catalog and the Android forest pack. It requires ARM64 and ordinary
Android frame pacing. It neither updates nor clears the installed game.
Use a fresh output directory beneath the assigned frontend's `.tmp`:

```sh
POKEAETHER_TEMPORARY_SLOT_D=1 ops/worktrees/slot-env slot-d -- python3 \
  .worktrees/slot-d/frontend/tools/export_battle_entry_web_qa.py \
  --suite android-gpu --platform android --android-renderer mobile \
  --sdk /home/adinho/Android/Sdk \
  --output .worktrees/slot-d/frontend/.tmp/android-gpu/export
POKEAETHER_TEMPORARY_SLOT_D=1 ops/worktrees/slot-env slot-d -- python3 \
  .worktrees/slot-d/frontend/tools/run_android_gpu_benchmark.py \
  --serial RFCY10TYKDH \
  --apk .worktrees/slot-d/frontend/.tmp/android-gpu/export/android-gpu-benchmark.apk \
  --output .worktrees/slot-d/frontend/.tmp/android-gpu/run-1
```

Keep the phone unlocked and the diagnostic foreground. The fixed scene uses
Charizard and Dragonite, noon lighting, frozen idle poses/wind and a stationary
camera. Each variant restores original controls, warms for three seconds and
samples for 15 seconds by default. Disabling grass, disabling light shadows,
2x MSAA and no MSAA are **diagnostic variations**, not game quality changes.
Baselines surround each variation; a second round reverses their order.
Two concluding phases repeat physical, Flamethrower and Thunderbolt effects.
The fixture supports only one/two rounds and 10/15/20-second phases.

Device-side process-frame intervals avoid the finite SurfaceFlinger history
loss observed during USB move captures. These report **engine FPS**, not
actual presented FPS. Per-viewport GPU/CPU timestamps, native raster, draw
calls, pipeline counters and a frame image accompany each phase. Zero GPU
timestamps invalidate the comparison. The host records sampled PSS/RSS,
battery temperature, thermal status, PID and foreground health. Critical
thermal status, process loss, stale run IDs, missing phases, engine errors,
short sampling and failed raster/MSAA restoration invalidate the run.

Compare a variation with both adjacent baseline medians and inspect baseline
drift and the corresponding health samples. Reversed rounds reduce ordering
bias; they cannot eliminate thermal or driver scheduling effects. The separate
app isolates the renderer and does not reproduce full-game HUD/network costs,
full-session memory, every model/move or other Android GPUs. Render timestamp
instrumentation may add overhead. Images are captured outside timing phases.
Benchmark asset and shader caches remain owned by this diagnostic package.

`--candidate grass_early_cutout` and `--candidate grass_front_to_back` run
shorter baseline/candidate/baseline rounds. They respectively test early alpha
rejection with explicit noise gradients and ordering visible grass instances
from near to far. The latter preserves hidden instances, per-instance colours
and custom data; the former retains all original material uniforms.
The early-cutout helper remains diagnostic-only. The measured instance-order
optimization is enabled for experimental Android Mobile forest battles, once
per prepared arena under the battle cover, using the first actual actor camera
framing. Standard Android, Compatibility, desktop and diagnostic baselines
retain their original order. The diagnostic controls deliberately override the
production optimization to compare original and sorted buffers.
Run `tests/android_gpu_fixture_check.gd` with the **native Mobile renderer**
through `slot-env` (without `--headless`). The dummy renderer cannot validate
actual MultiMesh instance attributes. Python report checks run with
`python3 -m unittest tests.test_android_gpu_benchmark`.

## SM-S938B GPU isolation, 2026-10-13

Diagnostic APK from `d081db636`, 2340 × 1080, Mobile, pinned v14 Charizard /
Dragonite and production Android forest pool. Both 15-second rounds completed,
with restored controls, valid GPU timestamps, no idle blocking-pipeline growth,
unchanged PID/foreground and no engine errors. Adjacent baseline medians:

| Variation | Main GPU reduction, round 1 | Round 2 |
| --- | ---: | ---: |
| No grass | 82.2% | 86.3% |
| No light shadows | 28.6% | 21.6% |
| 2x MSAA | -1.4% | 4.7% |
| No MSAA | 10.1% | 10.1% |

The authored main grass graph contains 95,757 instances in 256 batches. Main
GPU p50 was initially 27.07 ms, later about 35–36 ms. Without grass it stayed
near 4.94 ms in both rounds. Baseline drift reached 13.6% around the first
2x-MSAA phase, so that first comparison is confounded. The second MSAA round
had negligible adjacent baseline drift. Removing grass is isolation evidence,
not an acceptable appearance-preserving optimization.

The complete run took about 379 seconds of sampled foreground operation;
battery temperature rose from 27.9°C to 36.9°C, final thermal status was 2,
and sampled peak PSS was 2,251.33 MiB. Engine FPS initially measured 34.9 and
fell to about 27 on later idle baselines. These are renderer-only engine
intervals, not measured full-game presented FPS or memory savings.

First move execution had two frames above 100 ms (max 180.03 ms); the repeat
had none (max 57.76 ms). Both phases completed without a native crash, but
pipeline counters grew in both. Repeating this small move sequence does not
prove every move shader is warm or every battle is smooth.

The early-cutout candidate from `61e740f43` completed both rounds and moves
without engine errors. It measured +4.2% / -9.7% main GPU reduction, with
16.2% / 13.1% baseline drift. It has no repeatable demonstrated benefit and
is not enabled in the game. Its image differences were small (about 0.03%
of pixels), similar to baseline frame variation; this is not an all-model
visual certification. Local raw reports and images remain in the assigned
slot's `.tmp/android-gpu/run-6` and `cutout-1`, not tracked in Git.

The near-to-far candidate (`ee437a894`, diagnostic caller from `3b3d80f1b`)
completed both rounds at native raster and 4x MSAA with no engine errors or
idle pipeline growth. Main GPU p50 fell from adjacent baseline averages
29.71 / 35.18 ms to 17.55 / 21.65 ms: **41.0% / 38.4% less GPU time**.
Candidate engine FPS measured 52.8 / 43.0, versus neighboring baselines
33.5–30.8 / 27.2–27.3. The second pair had essentially zero baseline drift.
Full-scene image differences were 0.055% / 0.054% of pixels (mean absolute
RGB error ~0.004 on a 0–255 scale), versus baseline variation 0.024% / 0.021%.
Reordering cutout cards can change which card wins at equal-depth overlaps;
this is not a claim of bit-identical pixels. All original visible/hidden
transforms, colours and custom data remain present; the native resource check
asserts those contracts. Raw evidence is in `.tmp/android-gpu/order-1`.

The production change sorts only main-pass forest grass and retains its
original material/shader, shadows, density, mesh and textures. The response
pass remains the earlier shadows-only implementation. The preparation copies
instance attributes before reordering, adds buffers rather than saving memory,
and does not sort each battle frame. Other arenas, camera orbits, GPUs and
low-memory devices need separate measurements. The first order diagnostic's
move phases restored baseline buffers; the concluding optimized move check
must be evaluated separately.

The concluding 10-second-phase check in `.tmp/android-gpu/optimized-moves`
kept sorted buffers active for both move sequences. It completed without
engine errors or process/foreground changes. Its idle candidate reduced main
GPU p50 by 38.3% with negligible baseline drift. First/repeat move execution
had 1 / 0 frames above 100 ms (max 126.76 / 38.77 ms). Blocking pipeline
counters still grew in both; shader prewarming remains a separate opportunity.
The shorter phase duration and different thermal state prevent a direct
full-session stutter-rate comparison with the original 15-second move phases.

Signed full-game local USB build `0.3.109-3d-perf.3`, code 33, comes from
`267155510`, retains the existing asset/compatibility build ID and release
certificate, uses ARM64 Mobile and enables numeric performance diagnostics.
The Android demand-export checks passed. This local build has not been
published or certified as a release; full-game player testing complements
the separate renderer workload.

The user played moves in this full-game build and confirmed that it looks
good. Its safe numeric log confirms the production ordering hook prepared
all 256 batches / 95,757 instances once in 197 ms under the battle cover.
A subsequent active sample reports main GPU p50 19.14 ms / p95 20.09 ms and
response GPU p50 0.681 ms / p95 0.735 ms. This is supporting integration
evidence, not a controlled before/after full-game FPS comparison or an
explicit user confirmation of smoother play. Only allowlisted numeric
diagnostics were retained in `.tmp/android-gpu/production-perf3-safe-numeric.log`.

Use `tools/measure_android_battle.py` through the assigned `slot-env` with an
explicit physical serial, bounded duration, phase label and fresh slot-local
`.tmp` output directory. It measures the installed full game without changing
the APK or sending game input. The user operates battles.

```sh
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/measure_android_battle.py \
  --serial RFCY10TYKDH --seconds 60 --label idle \
  --output .worktrees/slot-a/frontend/.tmp/android-phone-performance/idle-1
```

The collector selects only the game's SurfaceView (including Samsung's
`RequestedLayerState` wrapper), polls SurfaceFlinger's finite latency history,
deduplicates actual presentation timestamps and reports p50/p95/p99/max display
intervals. Column order is desired present / actual present / frame ready:
[AOSP FrameTracker](https://android.googlesource.com/platform/frameworks/native/+/8c9cd3c537f7d4781862e2d95b32247fa5bb3d66/services/surfaceflinger/FrameTracker.cpp).
Zero and pending fence timestamps are excluded. A lost history invalidates
coverage and starts a new segment, rather than fabricating a long frame from
missing data. Threshold counts allow 0.1 ms rounding around 60/30 FPS budgets.

Five-second health samples include process PSS/RSS, battery temperature and
status, Android thermal status, unchanged PID and foreground state. They are
sampled observations, not continuous lifecycle monitoring. `usable` requires
complete collection, no detected coverage gaps or empty polls, enough frames,
no health errors and a finished health thread. It is measurement validity,
not a performance/thermal/visual approval. A still-running sampler is unusable.
The tool does not collect logcat, screenshots, account data or game payloads.

Presentation intervals alone cannot distinguish script, driver, GPU and frame
pacing costs. Build a local signed USB APK with `--experimental-3d
--performance-probe` to enable `ANDROID_3D_PERFORMANCE` and `ANDROID_3D_TIMING`
numeric records. Each viewport explicitly enables render timing; values are
render CPU/GPU costs in milliseconds, not device RAM or presented frame times.
Zero GPU timestamps may mean unavailable measurement, not free rendering.
Godot process time can include waiting and is not pure script utilization.
See [Godot RenderingServer timing](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu).

The probe uses fixed phase labels and numeric preparation keys. It excludes
model import dictionaries and all identities. Records are split into short
lines because the first physical trial exposed Godot Android stdout truncation
at approximately 1,000 payload characters. Initial `.perf.1` timing records
are partial evidence; they must not be parsed as complete JSON records.
Render timing may introduce overhead: label probe and ordinary runs separately.

## First SM-S938B baseline, 2026-10-13

Installed `0.3.109-3d-usb.2` (code 30), Godot 4.6.2, Mobile/Vulkan, Adreno 830,
physical screen 2340 × 1080 in landscape. A user-confirmed idle 3D battle
completed a 60-second capture with 684 intervals and zero history/empty gaps:
11.37 observed FPS, p50 91.54 ms, p95 108.19 ms, p99 116.52 ms, max 124.84 ms.
Sampled peak PSS was 2,530.75 MiB. Battery temperature increased from 35.6°C
to 36.9°C and thermal status from 2 to 3 while USB powered at full battery.
These are loaded-session conditions, not a cold sustained-performance score.

The unchanged-appearance `.perf.1` probe (code 31) reports both battle passes
at 2339 × 1081, 4x MSAA, about 1,570 total draw calls and ~826 MiB Godot render
allocations (~694 MiB texture allocations). Late idle samples show main GPU
time around 31–36 ms and response GPU time around 32–37 ms, with each render
CPU time below 1 ms. A second complete 60-second idle capture reports 12.36
observed FPS, p50 83.23 ms, p95 99.88 ms, p99 108.20 ms, max 116.52 ms.
Different battles, caches and thermal states make this a second baseline,
not evidence of an optimization speedup.

## First optimization and physical results

The response pass provides actor irradiance, yet previously drew the complete
arena colour again. Experimental Android 3D now changes only its independently
instantiated scenery: ordinary casters become shadows-only, non-casters use
zero geometry layers, and double-sided casters retain their original mode.
Children of non-casters remain visible so their shadows cannot be lost.
The main arena, authored meshes/textures, model materials, actors, native
resolution and 4x MSAA are retained. Desktop and ordinary Android are unchanged.
The local `--full-response-scene` control permits repeat comparisons.

Signed `0.3.109-3d-perf.2` (code 32, source `876cfa2e6`) retained the game's
data directory and passed a user-confirmed idle battle capture: 1,667 intervals,
27.76 observed FPS, p50 33.29 ms, p95 49.94 ms, p99 49.94 ms, max 58.26 ms,
zero intervals above 100 ms, zero history/empty gaps. Early active records show
response GPU p50 0.744 ms / p95 0.790 ms and main GPU p50 28.543 ms /
p95 29.132 ms. Both viewports remain 2339 × 1081 / 4x MSAA. Draw calls are
about 1,377. Short probe JSON records parse completely, with no truncated lines.

This is a large reduction of response-pass cost, not an exact whole-game
speedup factor: battle contents, cache and initial thermal state vary between
the three captures. Peak sampled PSS remains 2,562.39 MiB; no memory reduction
is demonstrated. Battery temperature rose 34.9°C → 38.6°C and Android thermal
status 1 → 3 during the optimized idle capture. Subsequent active records
include substantially longer main-pass GPU times. The root cause of each slow
frame is not established by these snapshots; heat and effect workloads need
separate controlled follow-up. Sustained 30/60 FPS is not established.

The user then played several turns. A 90-second mixed capture retained the
same PID and foreground app, but lost finite frame history twice. Its `usable`
result is false, so its aggregate FPS is excluded from performance claims.
The installed test app remains code 32; no official publication or release
certification took place. Player confirmation of full visual parity was not
received; "played" confirms the test action, not every requested visual check.

Focused geometry checks retain nested casters and double-sided casting without
mutating the main arena or its shared meshes. The native desktop Mobile/Vulkan
synthetic actor test compares 1,257 lit actor-core irradiance pixels with zero
differences, rejecting blank/constant images. It excludes scenery boundaries
and does not certify complete Pokémon images, mobile driver parity or all
shadows. Bounds, 24-move/four-slot execution and material-response checks pass;
19 focused Python asset/release/measurement tests pass. The execution fixture
retains its existing slot-cache model verification warning.

Retest idle, moves, switches and repeat battle entry on the same phone. Review
actor lighting and edges around occluding scenery: multisample boundary pixels
may differ when scenery no longer fills the response colour target. Keep
before/after timing, thermal and process memory separate; Godot memory counters
must not be added to Android PSS/RSS. No result here qualifies other devices,
all model/effect combinations or a release. Evidence stays in the assigned
slot's `.tmp/android-phone-performance` directory.
