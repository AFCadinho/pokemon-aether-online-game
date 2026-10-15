# Android quality soak

## Protocol

The isolated `android-quality` diagnostic supports `--mode soak`. It retains
one prepared production forest/presenter and the same two reviewed v16 actors
for forty measured 30-second windows (at least 1,200 seconds). The default is
Ultra at a 60 FPS cap, stationary camera, noon and frozen wind/animation playback.
There is one 30-second warm-up after preparation, then no arena/model reloads
between windows. This measures sustained behavior of this renderer workload;
it does not cover full gameplay, attacks, overworld, UI interaction or repeated
loading/release cycles. The retained model cache includes transformation art.

The APK/package, real native bridge, pinned art and USB-only fixture transport
are the same isolation boundary as the [short phone smoke](android-quality-phone-smoke.md).
There is no game account, authenticated server ingestion or production telemetry
activation. The normal game and its data/settings are not involved.

The player does not need to interact. Keep the unlocked diagnostic foregrounded
and the phone connected. Android pause/resume during the measured workload
invalidates the run. Critical thermal status (4 or above) stops the test; a
lower thermal status is evidence to report, not an automatic pass/fail target.
The host records charging state, battery sensor temperature, PSS, foreground
and thermal status about every ten seconds. These readings can perturb timing.
Native PSS/thermal samples are also taken at window boundaries, and render
counters are sampled once per second during each window.

Frame/GPU arrays are bounded to one window and reduced to p50/p95/max. Native
queries, sorting, report writes, USB uploads and the two captures occur between
windows and are excluded from frame statistics. The renderer remains active
through those boundaries; report both measured time and total wall time.
This instrumentation does not emulate the ordinary authenticated collector’s
five-second native-sampling cadence. Native PSS includes CPU/driver/debug/cache
allocations; do not add it to engine render memory or call it a memory leak
without further evidence.

The host accepts completion only with forty complete windows, the expected
profile/raster/MSAA, the same live stage instance throughout, no repeated
preparation, fresh run identity and all forty actual telemetry uploads. Actual
HOME/resume and opt-out checks run after the twenty-minute observation.
Unexpected interruptions, restarts, incomplete duration or engine/check errors
produce an unusable report. A wall-clock timeout bounds the run to 30 minutes.

## Running

Build the native suite with the existing exporter and a compatible JDK 17 as
described in the short phone smoke. Use a fresh output directory for each run:

```sh
ops/worktrees/slot-env slot-a -- python3 .worktrees/slot-a/frontend/tools/run_android_quality_benchmark.py \
  --serial SERIAL --mode soak --soak-preset ultra \
  --apk .worktrees/slot-a/frontend/.tmp/android-quality-phone/soak-export-NEW/android-quality-benchmark.apk \
  --output .worktrees/slot-a/frontend/.tmp/android-quality-phone/soak-run-NEW
```

Artifacts include the actual per-window telemetry, detailed timings, host health
samples, build/APK provenance, validation errors and start/end arena plus native
settings captures. The runner stops only its own diagnostic app and removes its
owned ADB reverse after completion. It retains the separate app/cache.

## S25 Ultra result — 2026-10-15

The full run completed with forty valid windows, **1,200.38 measured seconds**
and **1,204.43 seconds** from first sample start to final sample end. One stage
instance (`467111253349`) and both pooled forest passes were retained throughout;
no models/arena were re-prepared. The 4.05 seconds between measurement windows
were instrumentation/upload/capture work while the renderer stayed active.

Device: Samsung S25 Ultra / SM-S938B, Adreno 830, Android API 37, Mobile/Vulkan,
ARM64 debug build `android-quality-d869ec4ab1e3`, game version 0.3.110. Ultra
used **2340×1080 and 4× MSAA on both passes**, authored shadows and a 60 FPS cap.
Power saving was off. USB remained connected; Android reported AC power with
a **full 100% battery (status 5)** throughout, rather than active charging.
Host battery sensor temperature went from 26.6 °C at startup to 38.3 °C at the
last saved sample. This is battery sensor temperature, not GPU/CPU die temperature.

| Measured minutes | Weighted FPS | Window frame p95 range, ms | Main GPU window p50 range, ms | PSS range, MiB | Peak native thermal |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0–5 | 59.10 | 17.00–17.80 | 12.40–15.28 | 2208.10–2216.26 | 1 |
| 5–10 | 51.24 | 17.23–33.47 | 15.27–20.00 | 2216.06–2216.14 | 2 |
| 10–15 | 45.56 | 33.43–33.47 | 20.01–20.04 | 2207.94–2216.14 | 2 |
| 15–20 | 45.17 | 33.43–33.48 | 20.03–20.04 | 2208.02–2208.35 | 2 |

FPS is frame-count weighted over each five-minute block, using the actual
production summaries’ frame counts and durations. The p95/p50 columns are
ranges of individual 30-second window statistics, not pooled percentiles or
averages of percentiles. These are engine-loop intervals and Godot GPU
measurements, not display presentation timestamps.

The first window averaged **60.05 FPS**, frame p95 **17.03 ms** and main GPU
p50 **12.40 ms**. The last averaged **45.27 FPS**, frame p95 **33.47 ms** and
main GPU p50 **20.03 ms**. The final five minutes averaged **45.17 FPS**.
The entire observation averaged **50.27 FPS** over 60,339 intervals. Six intervals
exceeded 50 ms, none exceeded 100 ms, and the maximum was 78.58 ms. There were
11,797 intervals above the 25 ms budget tolerance.

Android thermal status rose from 0 to 1 (light), then 2 (moderate); both native
samples and 122 host health samples peaked at 2. Performance declined while
the scene/profile remained fixed and reported thermal state rose. This is
consistent with heat-related performance limiting, but no frequency trace or
controlled cooling/power comparison establishes the exact cause. **Ultra did
not sustain 60 FPS in this workload under these conditions.** This run does
not establish that High or another preset would sustain it. The subsequent
[High comparison](android-quality-high-soak.md) measured that profile directly.

Native PSS started at 2,208.10 MiB and ended at 2,208.35 MiB, with a peak of
2,216.26 MiB. Engine render allocation stayed at 729.63 MiB. There is no
progressive memory increase in this fixed retained scene. This does not rule
out leaks in map changes, repeated battle creation/release or full gameplay.

All forty actual USB-local telemetry reports uploaded, had unique report IDs,
and satisfied the exact backend `PerformanceReport`/`PerformanceBatch` schema
and count contracts in batches of eight in a network-disabled Python 3.13
container. No backend, game session, database or production ingestion was used.
The final real Android HOME/resume check succeeded (2 pause and 2 resume
notifications), and opt-out cleared pending data and stopped processing.
No engine/check errors were recorded. Start/end captures were visually inspected:
both actors, the same forest, framing and authored shadows remained present.

Eighteen focused Python quality/GPU harness tests passed, including rejection
of short, re-created or re-prepared soak results. The actual updated GDScript
parsed, exported with the real Java bridge and ran on the phone. No full paired
certification, promotion, deployment or production collection was performed.
The diagnostic process was stopped and its owned USB reverse removed afterwards.

Artifacts remain in this slot’s ignored `.tmp/android-quality-phone/`:
`soak-export-1/` holds the APK/build logs; `soak-run-1/` holds `report.json`,
`details.json`, `telemetry.json`, a derived `summary.json`, two arena PNGs and
two settings PNGs. The measured APK SHA-256 is
`0ec54fe7485912a26bd8630000682372987a895a417b64fea939e1ffd43c13ab`.
The host ran clean commit `448dc414b926a1a54f124191e71af917e5786363`;
the APK source was `d869ec4ab1e3`. Existing verified art in this isolated
app’s own cache was reused; there were no fixture GETs during this run.

A subsequent [High comparison](android-quality-high-soak.md) reused the exact
APK after cooldown and likewise did not sustain 60 FPS. Further work includes
lower render budgets, profiling and broader real/automated gameplay scenarios.
The user has no weaker phone; wider device validation needs other physical
testers or later authorized opt-in measurements. A device-name tier alone does
not establish sustained performance or justify an automatic preset recommendation.
