# Physical Android 3D performance measurements

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
